#!/usr/bin/env bash

# ISO Manager - Download, Verify, and Manage Linux Server ISOs
# This script handles downloading and validating ISOs for all supported distributions
# with enterprise-grade resilience features

set -euo pipefail

# ============================================
# Configuration
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
ISO_DIR="${PROJECT_ROOT}/isos"
CHECKSUM_DIR="${ISO_DIR}/checksums"
LOG_FILE="${ISO_DIR}/iso_manager.log"
PROGRESS_DIR="${ISO_DIR}/.progress"

# Download configuration
DEFAULT_MAX_RETRIES=5
DEFAULT_TIMEOUT=600
DEFAULT_RETRY_DELAY=30
STALL_TIMEOUT=60  # Seconds without progress before considering download stalled
PROGRESS_CHECK_INTERVAL=10  # Check progress every N seconds
MIN_DOWNLOAD_SPEED=10240  # Minimum acceptable speed in bytes/second (10 KB/s)
CONNECTION_TEST_TIMEOUT=10  # Timeout for connection health checks

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ============================================
# Logging Functions
# ============================================

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" | tee -a "${LOG_FILE}"
}

log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }
log_success() { log "SUCCESS" "$@"; }
log_debug() { log "DEBUG" "$@"; }

print_header() {
    echo ""
    echo -e "${BLUE}================================================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}================================================================${NC}"
    echo ""
}

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ $1${NC}"; }
print_progress() { echo -e "${CYAN}⟳ $1${NC}"; }

# ============================================
# ISO Definitions
# ============================================

# Format: "NAME|VERSION|URL|CHECKSUM_URL|CHECKSUM_TYPE"
declare -a ISO_DEFINITIONS=(
    # Ubuntu
    "ubuntu-20.04|20.04.6|https://releases.ubuntu.com/20.04.6/ubuntu-20.04.6-live-server-amd64.iso|https://releases.ubuntu.com/20.04.6/SHA256SUMS|sha256"
    "ubuntu-22.04|22.04.5|https://releases.ubuntu.com/22.04.5/ubuntu-22.04.5-live-server-amd64.iso|https://releases.ubuntu.com/22.04.5/SHA256SUMS|sha256"
    "ubuntu-24.04|24.04.3|https://releases.ubuntu.com/24.04.3/ubuntu-24.04.3-live-server-amd64.iso|https://releases.ubuntu.com/24.04.3/SHA256SUMS|sha256"

    # Debian
    "debian-11|11.11.0|https://cdimage.debian.org/cdimage/archive/11.11.0/amd64/iso-cd/debian-11.11.0-amd64-netinst.iso|https://cdimage.debian.org/cdimage/archive/11.11.0/amd64/iso-cd/SHA256SUMS|sha256"
    "debian-12|12.12.0|https://cdimage.debian.org/cdimage/archive/12.12.0/amd64/iso-cd/debian-12.12.0-amd64-netinst.iso|https://cdimage.debian.org/cdimage/archive/12.12.0/amd64/iso-cd/SHA256SUMS|sha256"

    # Fedora Server
    "fedora-server-38|38|https://archives.fedoraproject.org/pub/archive/fedora/linux/releases/38/Server/x86_64/iso/Fedora-Server-dvd-x86_64-38-1.6.iso|https://archives.fedoraproject.org/pub/archive/fedora/linux/releases/38/Server/x86_64/iso/Fedora-Server-38-1.6-x86_64-CHECKSUM|sha256"
    "fedora-server-39|39|https://archives.fedoraproject.org/pub/archive/fedora/linux/releases/39/Server/x86_64/iso/Fedora-Server-dvd-x86_64-39-1.5.iso|https://archives.fedoraproject.org/pub/archive/fedora/linux/releases/39/Server/x86_64/iso/Fedora-Server-39-1.5-x86_64-CHECKSUM|sha256"
    "fedora-server-40|40|https://download.fedoraproject.org/pub/fedora/linux/releases/40/Server/x86_64/iso/Fedora-Server-dvd-x86_64-40-1.14.iso|https://download.fedoraproject.org/pub/fedora/linux/releases/40/Server/x86_64/iso/Fedora-Server-40-1.14-x86_64-CHECKSUM|sha256"
    "fedora-server-41|41|https://download.fedoraproject.org/pub/fedora/linux/releases/41/Server/x86_64/iso/Fedora-Server-dvd-x86_64-41-1.4.iso|https://download.fedoraproject.org/pub/fedora/linux/releases/41/Server/x86_64/iso/Fedora-Server-41-1.4-x86_64-CHECKSUM|sha256"

    # AlmaLinux
    "almalinux-9|9-latest|https://repo.almalinux.org/almalinux/9/isos/x86_64/AlmaLinux-9-latest-x86_64-dvd.iso|https://repo.almalinux.org/almalinux/9/isos/x86_64/CHECKSUM|sha256"

    # Rocky Linux
    "rocky-9|9-latest|https://download.rockylinux.org/pub/rocky/9/isos/x86_64/Rocky-9-latest-x86_64-dvd.iso|https://download.rockylinux.org/pub/rocky/9/isos/x86_64/CHECKSUM|sha256"

    # openSUSE Leap
    "opensuse-leap-15|15.6|https://download.opensuse.org/distribution/leap/15.6/iso/openSUSE-Leap-15.6-DVD-x86_64-Media.iso|https://download.opensuse.org/distribution/leap/15.6/iso/openSUSE-Leap-15.6-DVD-x86_64-Media.iso.sha256|sha256"
)

# ============================================
# SMB Helper Functions
# ============================================

# Check if smbclient is available
check_smbclient() {
    if ! command -v smbclient &> /dev/null; then
        log_warn "smbclient not found. SMB functionality disabled."
        return 1
    fi
    return 0
}

# Check if a file exists in SMB share
smb_file_exists() {
    local smb_path="$1"
    local filename="$2"

    if ! check_smbclient; then
        return 1
    fi

    # Parse SMB path: smb://server/share/path
    local smb_url=$(echo "${smb_path}" | sed 's|^smb://||')
    local server=$(echo "${smb_url}" | cut -d'/' -f1)
    local share_path=$(echo "${smb_url}" | cut -d'/' -f2-)

    # Use smbclient to list files and check if our file exists
    if echo "ls ${share_path}/${filename}" | smbclient "//${server}/${share_path%/*}" -c "ls ${share_path}/${filename}" 2>/dev/null | grep -q "${filename}"; then
        log_info "File ${filename} found in SMB share: ${smb_path}"
        return 0
    else
        log_info "File ${filename} not found in SMB share: ${smb_path}"
        return 1
    fi
}

# Copy file from SMB share
copy_from_smb() {
    local smb_path="$1"
    local filename="$2"
    local local_path="$3"

    if ! check_smbclient; then
        return 1
    fi

    # Parse SMB path
    local smb_url=$(echo "${smb_path}" | sed 's|^smb://||')
    local server=$(echo "${smb_url}" | cut -d'/' -f1)
    local share_path=$(echo "${smb_url}" | cut -d'/' -f2-)

    print_info "Copying ${filename} from SMB share..."
    log_info "Copying from SMB: //${server}/${share_path}/${filename} to ${local_path}"

    # Use smbclient to copy the file
    if echo "get ${share_path}/${filename} ${local_path}" | smbclient "//${server}/${share_path%/*}" -c "get ${share_path}/${filename} ${local_path}" 2>/dev/null; then
        if [ -f "${local_path}" ]; then
            print_success "Successfully copied ${filename} from SMB share"
            log_success "SMB copy completed: ${filename}"
            return 0
        else
            print_error "Failed to copy ${filename} from SMB share (file not found locally after copy)"
            log_error "SMB copy failed: ${filename} (local file missing)"
            return 1
        fi
    else
        print_error "Failed to copy ${filename} from SMB share"
        log_error "SMB copy failed: ${filename}"
        return 1
    fi
}

# ============================================
# Helper Functions
# ============================================

create_directories() {
    mkdir -p "${ISO_DIR}"
    mkdir -p "${CHECKSUM_DIR}"
    mkdir -p "${PROGRESS_DIR}"
    log_info "Created directories: ${ISO_DIR}, ${CHECKSUM_DIR}, ${PROGRESS_DIR}"
}

# Get remote file size using HEAD request
get_remote_file_size() {
    local url="$1"
    local size=""

    if command -v curl &> /dev/null; then
        size=$(curl -sI -L "${url}" 2>/dev/null | grep -i "content-length" | tail -1 | awk '{print $2}' | tr -d '\r')
    elif command -v wget &> /dev/null; then
        size=$(wget --spider -S "${url}" 2>&1 | grep -i "content-length" | tail -1 | awk '{print $2}')
    fi

    echo "${size}"
}

# Verify connection health before download
verify_connection_health() {
    local url="$1"
    local description="${2:-URL}"

    print_info "Testing connection to ${description}..."
    log_info "Connection health check: ${url}"

    local domain=$(echo "${url}" | sed -e 's|^[^/]*//||' -e 's|/.*$||')

    # Test DNS resolution
    if ! host "${domain}" &> /dev/null; then
        print_warning "DNS resolution failed for ${domain}"
        log_warn "DNS resolution failed: ${domain}"
        return 1
    fi

    # Test HTTP connectivity with short timeout
    if command -v curl &> /dev/null; then
        if ! curl -sI -L --connect-timeout ${CONNECTION_TEST_TIMEOUT} --max-time ${CONNECTION_TEST_TIMEOUT} "${url}" &> /dev/null; then
            print_warning "HTTP connectivity test failed for ${description}"
            log_warn "HTTP connectivity test failed: ${url}"
            return 1
        fi
    elif command -v wget &> /dev/null; then
        if ! timeout ${CONNECTION_TEST_TIMEOUT} wget --spider -q "${url}" &> /dev/null; then
            print_warning "HTTP connectivity test failed for ${description}"
            log_warn "HTTP connectivity test failed: ${url}"
            return 1
        fi
    else
        print_warning "No download tool available (wget/curl)"
        return 1
    fi

    print_success "Connection health check passed"
    log_success "Connection health check passed: ${url}"
    return 0
}

# Check if partial file is valid for resuming
check_partial_file_validity() {
    local file_path="$1"
    local remote_size="$2"

    if [ ! -f "${file_path}" ]; then
        return 0  # No partial file, nothing to validate
    fi

    local local_size=$(stat -f%z "${file_path}" 2>/dev/null || stat -c%s "${file_path}" 2>/dev/null || echo "0")

    log_debug "Partial file check: local=${local_size}, remote=${remote_size}"

    # If we can't determine remote size, allow resume
    if [ -z "${remote_size}" ] || [ "${remote_size}" = "0" ]; then
        print_info "Cannot determine remote file size, allowing resume"
        return 0
    fi

    # If partial file is larger than remote file, it's corrupted
    if [ "${local_size}" -gt "${remote_size}" ]; then
        print_warning "Partial file is larger than remote (local: ${local_size}, remote: ${remote_size})"
        log_warn "Corrupted partial file detected: ${file_path} (oversized)"
        return 1
    fi

    # If partial file is exactly the same size, verify it
    if [ "${local_size}" -eq "${remote_size}" ]; then
        print_info "Partial file is complete, will verify checksum"
        return 0
    fi

    print_info "Partial file is valid for resume (${local_size}/${remote_size} bytes)"
    log_info "Valid partial file: ${file_path} (${local_size}/${remote_size} bytes)"
    return 0
}

# Cleanup corrupted partial file
cleanup_corrupted_partial() {
    local file_path="$1"
    local backup_path="${file_path}.corrupted.$(date +%s)"

    if [ -f "${file_path}" ]; then
        print_warning "Backing up corrupted partial to: ${backup_path}"
        log_warn "Moving corrupted partial: ${file_path} -> ${backup_path}"
        mv "${file_path}" "${backup_path}"
        return 0
    fi

    return 1
}

# Monitor download progress and detect stalls
monitor_download_progress() {
    local file_path="$1"
    local progress_file="$2"
    local stall_timeout="${3:-${STALL_TIMEOUT}}"
    local check_interval="${4:-${PROGRESS_CHECK_INTERVAL}}"

    local last_size=0
    local stall_count=0
    local max_stalls=$((stall_timeout / check_interval))

    while [ -f "${progress_file}" ]; do
        sleep "${check_interval}"

        if [ ! -f "${file_path}" ]; then
            continue
        fi

        local current_size=$(stat -f%z "${file_path}" 2>/dev/null || stat -c%s "${file_path}" 2>/dev/null || echo "0")

        if [ "${current_size}" -eq "${last_size}" ]; then
            stall_count=$((stall_count + 1))
            log_debug "Download stall detected: ${stall_count}/${max_stalls} (${current_size} bytes)"

            if [ "${stall_count}" -ge "${max_stalls}" ]; then
                print_error "Download stalled (no progress for ${stall_timeout}s)"
                log_error "Download stalled: ${file_path} (${current_size} bytes, ${stall_timeout}s timeout)"
                return 1
            fi
        else
            # Calculate download speed
            local bytes_diff=$((current_size - last_size))
            local speed=$((bytes_diff / check_interval))
            local speed_kb=$((speed / 1024))

            print_progress "Downloaded: ${current_size} bytes (${speed_kb} KB/s)"
            log_debug "Download progress: ${current_size} bytes, speed: ${speed_kb} KB/s"

            # Check for extremely slow downloads
            if [ "${speed}" -gt 0 ] && [ "${speed}" -lt "${MIN_DOWNLOAD_SPEED}" ]; then
                print_warning "Download speed is very slow (${speed_kb} KB/s)"
                log_warn "Slow download detected: ${speed_kb} KB/s (min: $((MIN_DOWNLOAD_SPEED / 1024)) KB/s)"
            fi

            stall_count=0
            last_size="${current_size}"
        fi
    done

    return 0
}

# Download file with progress monitoring and stall detection
download_with_progress_monitoring() {
    local url="$1"
    local output="$2"
    local timeout="$3"

    local progress_file="${PROGRESS_DIR}/$(basename "${output}").progress"
    local monitor_pid=""

    # Create progress marker file
    touch "${progress_file}"

    # Start progress monitoring in background
    monitor_download_progress "${output}" "${progress_file}" "${STALL_TIMEOUT}" "${PROGRESS_CHECK_INTERVAL}" &
    monitor_pid=$!

    local download_success=false
    local exit_code=0

    # Perform actual download
    if command -v wget &> /dev/null; then
        if timeout "${timeout}" wget -c --timeout="${timeout}" --tries=1 -O "${output}" "${url}" 2>&1 | tee -a "${LOG_FILE}"; then
            download_success=true
        else
            exit_code=${PIPESTATUS[0]}
        fi
    elif command -v curl &> /dev/null; then
        if timeout "${timeout}" curl -f -C - --connect-timeout "${timeout}" --max-time "${timeout}" -L -o "${output}" "${url}" 2>&1 | tee -a "${LOG_FILE}"; then
            download_success=true
        else
            exit_code=${PIPESTATUS[0]}
        fi
    else
        print_error "Neither wget nor curl found"
        exit_code=127
    fi

    # Stop progress monitoring
    rm -f "${progress_file}"
    if [ -n "${monitor_pid}" ] && kill -0 "${monitor_pid}" 2>/dev/null; then
        wait "${monitor_pid}" 2>/dev/null || true
    fi

    if [ "${download_success}" = "true" ]; then
        return 0
    else
        return "${exit_code}"
    fi
}

# Enhanced download function with all resilience features
download_file() {
    local url="$1"
    local output="$2"
    local description="${3:-file}"
    local max_retries=${4:-${DEFAULT_MAX_RETRIES}}
    local timeout=${5:-${DEFAULT_TIMEOUT}}
    local retry_delay=${6:-${DEFAULT_RETRY_DELAY}}

    print_info "Downloading ${description}..."
    log_info "Starting download: ${url}"
    log_info "Configuration: max_retries=${max_retries}, timeout=${timeout}s, retry_delay=${retry_delay}s"

    # Check for download tools
    if ! command -v wget &> /dev/null && ! command -v curl &> /dev/null; then
        print_error "Neither wget nor curl found. Please install one of them."
        log_error "No download tool available (wget/curl)"
        return 1
    fi

    local retry_count=0
    local success=false

    while [ ${retry_count} -lt ${max_retries} ] && [ "${success}" = "false" ]; do
        # Log retry attempt
        if [ ${retry_count} -gt 0 ]; then
            print_warning "Retry ${retry_count}/${max_retries} for ${description} (waiting ${retry_delay}s)..."
            log_warn "Retry attempt ${retry_count}/${max_retries} for ${description}"
            sleep ${retry_delay}
        fi

        # Verify connection health before download
        if ! verify_connection_health "${url}" "${description}"; then
            print_warning "Connection health check failed, retrying..."
            retry_count=$((retry_count + 1))
            retry_delay=$((retry_delay + RANDOM % 10))  # Add jitter
            continue
        fi

        # Get remote file size
        local remote_size=$(get_remote_file_size "${url}")
        if [ -n "${remote_size}" ] && [ "${remote_size}" != "0" ]; then
            log_info "Remote file size: ${remote_size} bytes"
        fi

        # Check partial file validity
        if [ -f "${output}" ]; then
            if ! check_partial_file_validity "${output}" "${remote_size}"; then
                cleanup_corrupted_partial "${output}"
            fi
        fi

        # Attempt download with progress monitoring
        if download_with_progress_monitoring "${url}" "${output}" "${timeout}"; then
            success=true
            print_success "Download completed successfully for ${description}"
            log_success "Download completed: ${url}"
        else
            local exit_code=$?
            if [ ${exit_code} -eq 124 ]; then
                print_warning "Download timeout for ${description} (${timeout}s)"
                log_warn "Download timeout: ${url}"
            else
                print_warning "Download failed for ${description} (exit code: ${exit_code})"
                log_warn "Download failed: ${url} (exit code: ${exit_code})"
            fi

            # Check if partial file is corrupted
            if [ -f "${output}" ]; then
                if ! check_partial_file_validity "${output}" "${remote_size}"; then
                    cleanup_corrupted_partial "${output}"
                fi
            fi

            retry_count=$((retry_count + 1))
        fi

        # Exponential backoff with jitter for subsequent retries
        if [ ${retry_count} -gt 0 ] && [ "${success}" = "false" ]; then
            retry_delay=$((retry_delay * 2))
            retry_delay=$((retry_delay + RANDOM % 10))  # Add jitter to prevent thundering herd
            if [ ${retry_delay} -gt 300 ]; then
                retry_delay=300
            fi
        fi
    done

    if [ "${success}" = "true" ]; then
        return 0
    else
        print_error "Failed to download ${description} after ${max_retries} attempts"
        log_error "Download failed after ${max_retries} attempts: ${url}"
        return 1
    fi
}

extract_checksum() {
    local checksum_file="$1"
    local iso_filename="$2"
    local checksum_type="$3"

    # Try to find the checksum for the ISO file
    if [ -f "${checksum_file}" ]; then
        # Strip PGP signature if present
        local checksum_content
        if grep -q "BEGIN PGP SIGNED MESSAGE" "${checksum_file}"; then
            # Extract content between PGP headers (skip the first 3 lines after BEGIN and before END signature)
            checksum_content=$(sed -n '/BEGIN PGP SIGNED MESSAGE/,/BEGIN PGP SIGNATURE/p' "${checksum_file}" | \
                grep -v "BEGIN PGP" | grep -v "^Hash:" | grep -v "^$")
        else
            checksum_content=$(cat "${checksum_file}")
        fi

        # Different distributions have different checksum file formats
        # Try to find exact filename match first
        local checksum=$(echo "${checksum_content}" | grep "${iso_filename}" | awk '{print $1}' | head -1)

        # If no exact match, try to extract from SHA256 (filename) = checksum format
        if [ -z "${checksum}" ]; then
            checksum=$(echo "${checksum_content}" | grep "${iso_filename}" | sed -n 's/.*= \([a-f0-9]\{64\}\)/\1/p' | head -1)
        fi

        # If still no match, try alternate format (checksum might be at the beginning of line)
        if [ -z "${checksum}" ]; then
            checksum=$(echo "${checksum_content}" | grep "${iso_filename}" | grep -oP '^[a-f0-9]{64}' | head -1)
        fi

        echo "${checksum}"
    else
        echo ""
    fi
}

verify_checksum() {
    local iso_file="$1"
    local checksum_file="$2"
    local checksum_type="$3"
    local iso_filename=$(basename "${iso_file}")

    print_info "Verifying ${checksum_type} checksum for ${iso_filename}..."
    log_info "Checksum verification started: ${iso_file}"

    if [ ! -f "${iso_file}" ]; then
        print_error "ISO file not found: ${iso_file}"
        log_error "ISO file not found: ${iso_file}"
        return 1
    fi

    if [ ! -f "${checksum_file}" ]; then
        print_warning "Checksum file not found: ${checksum_file}"
        log_warn "Checksum file not found: ${checksum_file}"
        return 1
    fi

    local expected_checksum=$(extract_checksum "${checksum_file}" "${iso_filename}" "${checksum_type}")

    if [ -z "${expected_checksum}" ]; then
        print_warning "Could not extract checksum from file"
        log_warn "Failed to extract checksum from: ${checksum_file}"
        return 1
    fi

    log_info "Expected ${checksum_type}: ${expected_checksum}"

    local actual_checksum=""
    case "${checksum_type}" in
        sha256)
            actual_checksum=$(sha256sum "${iso_file}" | awk '{print $1}')
            ;;
        sha512)
            actual_checksum=$(sha512sum "${iso_file}" | awk '{print $1}')
            ;;
        md5)
            actual_checksum=$(md5sum "${iso_file}" | awk '{print $1}')
            ;;
        *)
            print_error "Unknown checksum type: ${checksum_type}"
            log_error "Unknown checksum type: ${checksum_type}"
            return 1
            ;;
    esac

    log_info "Actual ${checksum_type}: ${actual_checksum}"

    if [ "${expected_checksum}" = "${actual_checksum}" ]; then
        print_success "Checksum verification passed"
        log_success "Checksum verified for ${iso_filename}"
        return 0
    else
        print_error "Checksum verification failed!"
        log_error "Checksum mismatch for ${iso_filename}"
        log_error "Expected: ${expected_checksum}"
        log_error "Actual:   ${actual_checksum}"
        return 1
    fi
}

process_iso() {
    local name="$1"
    local version="$2"
    local iso_url="$3"
    local checksum_url="$4"
    local checksum_type="$5"

    local iso_filename=$(basename "${iso_url}")
    local iso_path="${ISO_DIR}/${iso_filename}"
    local checksum_filename="${name}.${checksum_type}"
    local checksum_path="${CHECKSUM_DIR}/${checksum_filename}"

    print_header "Processing: ${name} ${version}"

    # Download checksum file
    if [ ! -f "${checksum_path}" ] || [ "$FORCE_DOWNLOAD" = "true" ]; then
        download_file "${checksum_url}" "${checksum_path}" "checksum file" 3 120 15
        if [ $? -ne 0 ]; then
            print_error "Failed to download checksum file"
            log_error "Failed to download checksum file: ${checksum_url}"
            return 1
        fi
    else
        print_info "Checksum file already exists: ${checksum_filename}"
    fi

    # Check if ISO already exists
    if [ -f "${iso_path}" ] && [ "$FORCE_DOWNLOAD" != "true" ]; then
        print_info "ISO file already exists: ${iso_filename}"

        # Verify existing ISO
        if verify_checksum "${iso_path}" "${checksum_path}" "${checksum_type}"; then
            print_success "Existing ISO is valid"
            return 0
        else
            print_warning "Existing ISO is corrupted, re-downloading..."
            cleanup_corrupted_partial "${iso_path}"
        fi
    fi

    # Check for SMB cache if OS_IS_IMAGES_PATH is set
    if [ -n "${OS_IS_IMAGES_PATH:-}" ]; then
        print_info "Checking SMB cache for ${iso_filename}..."
        log_info "OS_IS_IMAGES_PATH set: ${OS_IS_IMAGES_PATH}"

        if smb_file_exists "${OS_IS_IMAGES_PATH}" "${iso_filename}"; then
            if copy_from_smb "${OS_IS_IMAGES_PATH}" "${iso_filename}" "${iso_path}"; then
                # Verify the copied ISO
                if verify_checksum "${iso_path}" "${checksum_path}" "${checksum_type}"; then
                    print_success "ISO copied from SMB cache and verified"
                    log_success "ISO successfully obtained from SMB cache: ${iso_filename}"
                    return 0
                else
                    print_warning "ISO from SMB cache failed verification, falling back to internet download"
                    log_warn "SMB ISO failed verification: ${iso_filename}"
                    cleanup_corrupted_partial "${iso_path}"
                fi
            else
                print_warning "Failed to copy from SMB cache, falling back to internet download"
                log_warn "SMB copy failed: ${iso_filename}"
            fi
        else
            print_info "ISO not found in SMB cache, proceeding with internet download"
            log_info "ISO not in SMB cache: ${iso_filename}"
        fi
    fi

    # Download ISO with enhanced resilience features
    download_file "${iso_url}" "${iso_path}" "${name} ISO" 5 600 30
    if [ $? -ne 0 ]; then
        print_error "Failed to download ISO"
        log_error "Failed to download ISO: ${iso_url}"
        return 1
    fi

    # Verify downloaded ISO
    if verify_checksum "${iso_path}" "${checksum_path}" "${checksum_type}"; then
        print_success "Download and verification complete for ${name}"
        log_success "ISO successfully downloaded and verified: ${iso_filename}"
        return 0
    else
        print_error "Downloaded ISO failed verification"
        log_error "Downloaded ISO failed verification: ${iso_filename}"
        cleanup_corrupted_partial "${iso_path}"
        return 1
    fi
}

# ============================================
# Main Functions
# ============================================

download_all() {
    local success_count=0
    local fail_count=0
    local total=${#ISO_DEFINITIONS[@]}

    print_header "Downloading and Verifying All ISOs"
    log_info "Starting batch download of ${total} distributions"

    for definition in "${ISO_DEFINITIONS[@]}"; do
        IFS='|' read -r name version url checksum_url checksum_type <<< "${definition}"

        if process_iso "${name}" "${version}" "${url}" "${checksum_url}" "${checksum_type}"; then
            success_count=$((success_count + 1))
        else
            fail_count=$((fail_count + 1))
        fi

        echo ""
    done

    print_header "Download Summary"
    echo -e "Total: ${total}"
    echo -e "${GREEN}Success: ${success_count}${NC}"
    echo -e "${RED}Failed: ${fail_count}${NC}"

    log_info "Download batch complete. Success: ${success_count}, Failed: ${fail_count}"

    # Return success only if all downloads succeeded
    if [ ${fail_count} -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

verify_all() {
    print_header "Verifying All Existing ISOs"

    local verified=0
    local failed=0

    for definition in "${ISO_DEFINITIONS[@]}"; do
        IFS='|' read -r name version url checksum_url checksum_type <<< "${definition}"

        local iso_filename=$(basename "${url}")
        local iso_path="${ISO_DIR}/${iso_filename}"
        local checksum_filename="${name}.${checksum_type}"
        local checksum_path="${CHECKSUM_DIR}/${checksum_filename}"

        if [ -f "${iso_path}" ]; then
            echo ""
            print_info "Checking: ${iso_filename}"

            if [ ! -f "${checksum_path}" ]; then
                print_warning "Checksum file missing, downloading..."
                download_file "${checksum_url}" "${checksum_path}" "checksum file" 3 120 15
            fi

            if verify_checksum "${iso_path}" "${checksum_path}" "${checksum_type}"; then
                verified=$((verified + 1))
            else
                failed=$((failed + 1))
            fi
        fi
    done

    echo ""
    print_header "Verification Summary"
    echo -e "${GREEN}Verified: ${verified}${NC}"
    echo -e "${RED}Failed: ${failed}${NC}"

    log_info "Verification complete. Verified: ${verified}, Failed: ${failed}"

    # Return success only if no verifications failed
    if [ ${failed} -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

list_isos() {
    print_header "Available ISO Definitions"

    printf "%-25s %-10s %-10s\n" "Name" "Version" "Status"
    printf "%-25s %-10s %-10s\n" "----" "-------" "------"

    for definition in "${ISO_DEFINITIONS[@]}"; do
        IFS='|' read -r name version url checksum_url checksum_type <<< "${definition}"

        local iso_filename=$(basename "${url}")
        local iso_path="${ISO_DIR}/${iso_filename}"

        local status="Not Downloaded"
        if [ -f "${iso_path}" ]; then
            status="${GREEN}Downloaded${NC}"
        fi

        printf "%-25s %-10s %-10b\n" "${name}" "${version}" "${status}"
    done
}

show_help() {
    cat <<EOF
ISO Manager - Download and Verify Linux Server ISOs

Usage: $(basename "$0") [COMMAND] [OPTIONS]

Commands:
    download    Download all ISOs and verify checksums
    verify      Verify checksums of existing ISOs
    list        List all available ISOs and their status
    help        Show this help message

Options:
    --force     Force re-download even if ISO exists

Features:
     ✓ Resume capability for interrupted downloads
     ✓ Automatic corruption detection and cleanup
     ✓ Connection health checks before download
     ✓ Download stall detection (auto-retry on hang)
     ✓ Progress monitoring with speed tracking
     ✓ Exponential backoff with jitter
     ✓ Checksum verification (SHA256/SHA512/MD5)
     ✓ Optional SMB cache support for local network ISOs

Examples:
    $(basename "$0") download              # Download all ISOs
    $(basename "$0") verify                # Verify existing ISOs
    $(basename "$0") download --force      # Force re-download all ISOs
    $(basename "$0") list                  # List available ISOs

Environment Variables:
     OS_IS_IMAGES_PATH        SMB path for cached ISOs (e.g., smb://server/share/isos)
     STALL_TIMEOUT            Seconds without progress before retry (default: 60)
     PROGRESS_CHECK_INTERVAL  Progress check frequency in seconds (default: 10)
     MIN_DOWNLOAD_SPEED       Minimum acceptable speed in bytes/sec (default: 10240)

EOF
}

# ============================================
# Main Script
# ============================================

main() {
    create_directories

    local command="${1:-help}"
    FORCE_DOWNLOAD="${2:-false}"

    if [ "${FORCE_DOWNLOAD}" = "--force" ]; then
        FORCE_DOWNLOAD="true"
    else
        FORCE_DOWNLOAD="false"
    fi

    case "${command}" in
        download)
            download_all
            ;;
        verify)
            verify_all
            ;;
        list)
            list_isos
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "Unknown command: ${command}"
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
