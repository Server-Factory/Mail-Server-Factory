#!/usr/bin/env bash

# ISO Manager - Download, Verify, and Manage Linux Server ISOs
# This script handles downloading and validating ISOs for all supported distributions

set -euo pipefail

# ============================================
# Configuration
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
ISO_DIR="${PROJECT_ROOT}/isos"
CHECKSUM_DIR="${ISO_DIR}/checksums"
LOG_FILE="${ISO_DIR}/iso_manager.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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
    "debian-11|11.12.0|https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-11.12.0-amd64-netinst.iso|https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/SHA256SUMS|sha256"
    "debian-12|12.9.0|https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-12.9.0-amd64-netinst.iso|https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/SHA256SUMS|sha256"

    # Fedora Server
    "fedora-server-38|38|https://download.fedoraproject.org/pub/fedora/linux/releases/38/Server/x86_64/iso/Fedora-Server-dvd-x86_64-38-1.6.iso|https://download.fedoraproject.org/pub/fedora/linux/releases/38/Server/x86_64/iso/Fedora-Server-38-1.6-x86_64-CHECKSUM|sha256"
    "fedora-server-39|39|https://download.fedoraproject.org/pub/fedora/linux/releases/39/Server/x86_64/iso/Fedora-Server-dvd-x86_64-39-1.5.iso|https://download.fedoraproject.org/pub/fedora/linux/releases/39/Server/x86_64/iso/Fedora-Server-39-1.5-x86_64-CHECKSUM|sha256"
    "fedora-server-40|40|https://download.fedoraproject.org/pub/fedora/linux/releases/40/Server/x86_64/iso/Fedora-Server-dvd-x86_64-40-1.14.iso|https://download.fedoraproject.org/pub/fedora/linux/releases/40/Server/x86_64/iso/Fedora-Server-40-1.14-x86_64-CHECKSUM|sha256"
    "fedora-server-41|41|https://download.fedoraproject.org/pub/fedora/linux/releases/41/Server/x86_64/iso/Fedora-Server-dvd-x86_64-41-1.4.iso|https://download.fedoraproject.org/pub/fedora/linux/releases/41/Server/x86_64/iso/Fedora-Server-41-1.4-x86_64-CHECKSUM|sha256"

    # AlmaLinux
    "almalinux-9|9.5|https://repo.almalinux.org/almalinux/9.5/isos/x86_64/AlmaLinux-9.5-x86_64-dvd.iso|https://repo.almalinux.org/almalinux/9.5/isos/x86_64/CHECKSUM|sha256"

    # Rocky Linux
    "rocky-9|9.5|https://download.rockylinux.org/pub/rocky/9.5/isos/x86_64/Rocky-9.5-x86_64-dvd.iso|https://download.rockylinux.org/pub/rocky/9.5/isos/x86_64/CHECKSUM|sha256"

    # openSUSE Leap
    "opensuse-leap-15|15.6|https://download.opensuse.org/distribution/leap/15.6/iso/openSUSE-Leap-15.6-DVD-x86_64-Media.iso|https://download.opensuse.org/distribution/leap/15.6/iso/openSUSE-Leap-15.6-DVD-x86_64-Media.iso.sha256|sha256"
)

# ============================================
# Helper Functions
# ============================================

create_directories() {
    mkdir -p "${ISO_DIR}"
    mkdir -p "${CHECKSUM_DIR}"
    log_info "Created directories: ${ISO_DIR}, ${CHECKSUM_DIR}"
}

download_file() {
    local url="$1"
    local output="$2"
    local description="${3:-file}"

    print_info "Downloading ${description}..."
    log_info "Downloading from: ${url}"

    if command -v wget &> /dev/null; then
        wget -c -O "${output}" "${url}" 2>&1 | tee -a "${LOG_FILE}"
    elif command -v curl &> /dev/null; then
        curl -C - -L -o "${output}" "${url}" 2>&1 | tee -a "${LOG_FILE}"
    else
        print_error "Neither wget nor curl found. Please install one of them."
        return 1
    fi

    return $?
}

extract_checksum() {
    local checksum_file="$1"
    local iso_filename="$2"
    local checksum_type="$3"

    # Try to find the checksum for the ISO file
    if [ -f "${checksum_file}" ]; then
        # Different distributions have different checksum file formats
        local checksum=$(grep "${iso_filename}" "${checksum_file}" | awk '{print $1}' | head -1)

        if [ -z "${checksum}" ]; then
            # Try alternate format (checksum might be the whole file for single ISO)
            checksum=$(head -1 "${checksum_file}" | awk '{print $1}')
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

    if [ ! -f "${iso_file}" ]; then
        print_error "ISO file not found: ${iso_file}"
        return 1
    fi

    if [ ! -f "${checksum_file}" ]; then
        print_warning "Checksum file not found: ${checksum_file}"
        return 1
    fi

    local expected_checksum=$(extract_checksum "${checksum_file}" "${iso_filename}" "${checksum_type}")

    if [ -z "${expected_checksum}" ]; then
        print_warning "Could not extract checksum from file"
        return 1
    fi

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
            return 1
            ;;
    esac

    if [ "${expected_checksum}" = "${actual_checksum}" ]; then
        print_success "Checksum verification passed"
        log_success "Checksum verified for ${iso_filename}"
        return 0
    else
        print_error "Checksum verification failed!"
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
        download_file "${checksum_url}" "${checksum_path}" "checksum file"
        if [ $? -ne 0 ]; then
            print_error "Failed to download checksum file"
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
            rm -f "${iso_path}"
        fi
    fi

    # Download ISO
    download_file "${iso_url}" "${iso_path}" "${name} ISO"
    if [ $? -ne 0 ]; then
        print_error "Failed to download ISO"
        return 1
    fi

    # Verify downloaded ISO
    if verify_checksum "${iso_path}" "${checksum_path}" "${checksum_type}"; then
        print_success "Download and verification complete for ${name}"
        return 0
    else
        print_error "Downloaded ISO failed verification"
        rm -f "${iso_path}"
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
            ((success_count++))
        else
            ((fail_count++))
        fi

        echo ""
    done

    print_header "Download Summary"
    echo -e "Total: ${total}"
    echo -e "${GREEN}Success: ${success_count}${NC}"
    echo -e "${RED}Failed: ${fail_count}${NC}"

    log_info "Download complete. Success: ${success_count}, Failed: ${fail_count}"
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
                download_file "${checksum_url}" "${checksum_path}" "checksum file"
            fi

            if verify_checksum "${iso_path}" "${checksum_path}" "${checksum_type}"; then
                ((verified++))
            else
                ((failed++))
            fi
        fi
    done

    echo ""
    print_header "Verification Summary"
    echo -e "${GREEN}Verified: ${verified}${NC}"
    echo -e "${RED}Failed: ${failed}${NC}"
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

Examples:
    $(basename "$0") download              # Download all ISOs
    $(basename "$0") verify                # Verify existing ISOs
    $(basename "$0") download --force      # Force re-download all ISOs
    $(basename "$0") list                  # List available ISOs

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
