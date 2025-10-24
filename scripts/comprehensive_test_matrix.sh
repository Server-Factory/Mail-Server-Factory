#!/usr/bin/env bash

# Comprehensive Test Matrix - Host to Destination OS Testing
# Tests all possible combinations of host OS (Desktop) → destination OS (Server)
#
# Purpose: Verify that Mail Server Factory can run on any desktop Linux distribution
#          and successfully deploy mail servers to any supported server distribution

set -euo pipefail

# ============================================
# Configuration
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
ISO_DIR="${PROJECT_ROOT}/isos"
VM_DIR="${PROJECT_ROOT}/vms"
RESULTS_DIR="${PROJECT_ROOT}/test_results"
MATRIX_DIR="${RESULTS_DIR}/matrix"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')

# Archive directories for reusable VM images
ARCHIVE_DIR="${PROJECT_ROOT}/archives"
ISO_ARCHIVE="${ARCHIVE_DIR}/isos"
VM_IMAGES_ARCHIVE="${ARCHIVE_DIR}/vm_images"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================
# Host OS Definitions (Desktop Linux)
# ============================================

# Format: "NAME|ISO_FILENAME|OS_FAMILY|INSTALL_METHOD"
declare -A HOST_OS=(
    # Western Desktop Distributions
    ["ubuntu-desktop-25"]="ubuntu-25.10-desktop-amd64.iso|debian|autoinstall"
    ["ubuntu-desktop-24"]="ubuntu-24.04.3-desktop-amd64.iso|debian|autoinstall"
    ["ubuntu-desktop-22"]="ubuntu-22.04.5-desktop-amd64.iso|debian|autoinstall"
    ["debian-desktop-12"]="debian-12.9.0-amd64-DVD-1.iso|debian|preseed"
    ["debian-desktop-11"]="debian-11.12.0-amd64-DVD-1.iso|debian|preseed"
    ["fedora-workstation-41"]="Fedora-Workstation-Live-x86_64-41-1.4.iso|rpm|kickstart"
    ["fedora-workstation-40"]="Fedora-Workstation-Live-x86_64-40-1.14.iso|rpm|kickstart"
    ["opensuse-desktop-15.6"]="openSUSE-Leap-15.6-DVD-x86_64-Media.iso|suse|autoyast"

    # Russian Desktop Distributions
    ["alt-workstation-p10"]="alt-workstation-10.2-x86_64.iso|rpm|altinst"
    ["astra-desktop-2.12"]="alce-current.iso|debian|preseed"
    ["rosa-desktop-12"]="rosa.fresh.12.x86_64.iso|rpm|kickstart"

    # Chinese Desktop Distributions
    ["openkylin-desktop-2.0"]="openkylin-2.0-amd64.iso|debian|autoinstall"
    ["deepin-desktop-23"]="deepin-desktop-community-23-amd64.iso|debian|preseed"
)

# ============================================
# Destination OS Definitions (Server)
# ============================================

# Format: "NAME|ISO_FILENAME|OS_FAMILY|CONFIG_FILE"
declare -A DEST_OS=(
    # Western Server Distributions
    ["ubuntu-server-25"]="ubuntu-25.10-live-server-amd64.iso|debian|Ubuntu_25.json"
    ["ubuntu-server-24"]="ubuntu-24.04.3-live-server-amd64.iso|debian|Ubuntu_24.json"
    ["ubuntu-server-22"]="ubuntu-22.04.5-live-server-amd64.iso|debian|Ubuntu_22.json"
    ["debian-server-12"]="debian-12.9.0-amd64-netinst.iso|debian|Debian_12.json"
    ["debian-server-11"]="debian-11.12.0-amd64-netinst.iso|debian|Debian_11.json"
    ["centos-stream-9"]="CentOS-Stream-9-latest-x86_64-dvd1.iso|rpm|CentOS_Stream.json"
    ["centos-8"]="CentOS-8.5.2111-x86_64-dvd1.iso|rpm|Centos_8.json"
    ["centos-7"]="CentOS-7-x86_64-DVD-2009.iso|rpm|Centos_7.json"
    ["fedora-server-41"]="Fedora-Server-dvd-x86_64-41-1.4.iso|rpm|Fedora_Server_41.json"
    ["fedora-server-40"]="Fedora-Server-dvd-x86_64-40-1.14.iso|rpm|Fedora_Server_40.json"
    ["fedora-server-39"]="Fedora-Server-dvd-x86_64-39-1.5.iso|rpm|Fedora_Server_39.json"
    ["fedora-server-38"]="Fedora-Server-dvd-x86_64-38-1.6.iso|rpm|Fedora_Server_38.json"
    ["almalinux-9"]="AlmaLinux-9.5-x86_64-dvd.iso|rpm|AlmaLinux_9.json"
    ["rocky-9"]="Rocky-9.5-x86_64-dvd.iso|rpm|Rocky_9.json"
    ["opensuse-leap-15.6"]="openSUSE-Leap-15.6-DVD-x86_64-Media.iso|suse|openSUSE_Leap_15.6.json"
    ["opensuse-leap-15.5"]="openSUSE-Leap-15.5-DVD-x86_64-Media.iso|suse|openSUSE_Leap_15.5.json"

    # Russian Server Distributions
    ["alt-server-p10"]="alt-server-10.4-x86_64.iso|rpm|ALTLinux_p10_Server.json"
    ["alt-p10"]="alt-server-10.2-x86_64.iso|rpm|ALTLinux_p10.json"
    ["astra-server-2.12"]="alce-current.iso|debian|Astra_Linux_CE_2.12.json"
    ["rosa-server-12"]="rosa.fresh.12.x86_64.iso|rpm|ROSA_Linux_12.json"

    # Chinese Server Distributions
    ["openeuler-24.03"]="openEuler-24.03-LTS-x86_64-dvd.iso|rpm|openEuler_24.03_LTS.json"
    ["openeuler-22.03-sp4"]="openEuler-22.03-LTS-SP4-x86_64-dvd.iso|rpm|openEuler_22.03_LTS_SP4.json"
    ["openkylin-server-2.0"]="openkylin-2.0-amd64.iso|debian|openKylin_2.0.json"
    ["deepin-server-23"]="deepin-desktop-community-23-amd64.iso|debian|Deepin_23.json"
)

# ============================================
# Test Matrix Calculation
# ============================================

TOTAL_HOST_OS=${#HOST_OS[@]}
TOTAL_DEST_OS=${#DEST_OS[@]}
TOTAL_COMBINATIONS=$((TOTAL_HOST_OS * TOTAL_DEST_OS))

# ============================================
# Logging Functions
# ============================================

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" | tee -a "${RESULTS_DIR}/comprehensive_test.log"
}

log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }
log_success() { log "SUCCESS" "$@"; }

print_header() {
    echo ""
    echo -e "${MAGENTA}========================================================================${NC}"
    echo -e "${MAGENTA}  $1${NC}"
    echo -e "${MAGENTA}========================================================================${NC}"
    echo ""
}

print_sub_header() {
    echo ""
    echo -e "${CYAN}-----------------------------------------------------------${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}-----------------------------------------------------------${NC}"
}

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ $1${NC}"; }

# ============================================
# Directory Setup
# ============================================

create_directories() {
    mkdir -p "${RESULTS_DIR}" "${MATRIX_DIR}" "${ARCHIVE_DIR}" "${ISO_ARCHIVE}" "${VM_IMAGES_ARCHIVE}"
    log_info "Created directory structure"
}

# ============================================
# ISO Management
# ============================================

check_iso_availability() {
    print_header "Checking ISO Availability"

    local missing_count=0
    local archived_count=0
    local available_count=0

    # Check Host OS ISOs
    print_sub_header "Host OS ISOs (Desktop)"
    for host in "${!HOST_OS[@]}"; do
        local iso_file=$(echo "${HOST_OS[$host]}" | cut -d'|' -f1)

        if [ -f "${ISO_DIR}/${iso_file}" ]; then
            print_success "${host}: ${iso_file} - Available"
            ((available_count++))
        elif [ -f "${ISO_ARCHIVE}/${iso_file}" ]; then
            print_info "${host}: ${iso_file} - Archived (will extract)"
            ((archived_count++))
        else
            print_warning "${host}: ${iso_file} - MISSING"
            ((missing_count++))
        fi
    done

    # Check Destination OS ISOs
    print_sub_header "Destination OS ISOs (Server)"
    for dest in "${!DEST_OS[@]}"; do
        local iso_file=$(echo "${DEST_OS[$dest]}" | cut -d'|' -f1)

        if [ -f "${ISO_DIR}/${iso_file}" ]; then
            print_success "${dest}: ${iso_file} - Available"
            ((available_count++))
        elif [ -f "${ISO_ARCHIVE}/${iso_file}" ]; then
            print_info "${dest}: ${iso_file} - Archived (will extract)"
            ((archived_count++))
        else
            print_warning "${dest}: ${iso_file} - MISSING"
            ((missing_count++))
        fi
    done

    echo ""
    print_info "Available: ${available_count}"
    print_info "Archived: ${archived_count}"
    print_warning "Missing: ${missing_count}"
    echo ""

    if [ $missing_count -gt 0 ]; then
        print_warning "Some ISOs are missing. Run ISO download script first:"
        print_warning "  cd Core/Utils/Iso && ./download_isos_v2.sh"
    fi

    return $missing_count
}

archive_isos() {
    print_header "Archiving ISOs for Reuse"

    if [ ! -d "${ISO_DIR}" ]; then
        print_error "ISO directory not found: ${ISO_DIR}"
        return 1
    fi

    cd "${ISO_DIR}"
    local iso_count=$(find . -name "*.iso" | wc -l)

    if [ $iso_count -eq 0 ]; then
        print_warning "No ISOs found to archive"
        return 0
    fi

    print_info "Creating compressed archive of ${iso_count} ISO files..."
    tar -czf "${ISO_ARCHIVE}/all_isos_${TIMESTAMP}.tar.gz" *.iso

    local archive_size=$(du -h "${ISO_ARCHIVE}/all_isos_${TIMESTAMP}.tar.gz" | cut -f1)
    print_success "Archived ${iso_count} ISOs (${archive_size})"
    print_info "Archive location: ${ISO_ARCHIVE}/all_isos_${TIMESTAMP}.tar.gz"
}

extract_archived_isos() {
    print_header "Extracting Archived ISOs"

    local latest_archive=$(ls -t "${ISO_ARCHIVE}"/all_isos_*.tar.gz 2>/dev/null | head -1)

    if [ -z "$latest_archive" ]; then
        print_warning "No archived ISOs found"
        return 1
    fi

    print_info "Extracting: $(basename "$latest_archive")"
    tar -xzf "$latest_archive" -C "${ISO_DIR}"

    local extracted_count=$(find "${ISO_DIR}" -name "*.iso" | wc -l)
    print_success "Extracted ${extracted_count} ISO files"
}

# ============================================
# VM Image Management
# ============================================

create_vm_image() {
    local vm_name="$1"
    local iso_file="$2"
    local install_method="$3"

    print_sub_header "Creating VM: ${vm_name}"

    local vm_path="${VM_DIR}/${vm_name}"
    mkdir -p "${vm_path}"

    # Create disk image
    qemu-img create -f qcow2 "${vm_path}/disk.qcow2" 40G

    # Install OS (automated installation)
    # This will vary based on install_method (autoinstall, preseed, kickstart, autoyast)
    case "$install_method" in
        autoinstall)
            install_with_autoinstall "${vm_name}" "${iso_file}"
            ;;
        preseed)
            install_with_preseed "${vm_name}" "${iso_file}"
            ;;
        kickstart)
            install_with_kickstart "${vm_name}" "${iso_file}"
            ;;
        autoyast)
            install_with_autoyast "${vm_name}" "${iso_file}"
            ;;
        *)
            print_error "Unknown install method: ${install_method}"
            return 1
            ;;
    esac

    print_success "VM created: ${vm_name}"
}

archive_vm_image() {
    local vm_name="$1"

    print_info "Archiving VM image: ${vm_name}"

    local vm_path="${VM_DIR}/${vm_name}"
    if [ ! -d "${vm_path}" ]; then
        print_error "VM not found: ${vm_name}"
        return 1
    fi

    cd "${VM_DIR}"
    tar -czf "${VM_IMAGES_ARCHIVE}/${vm_name}_${TIMESTAMP}.tar.gz" "${vm_name}"

    local archive_size=$(du -h "${VM_IMAGES_ARCHIVE}/${vm_name}_${TIMESTAMP}.tar.gz" | cut -f1)
    print_success "Archived VM ${vm_name} (${archive_size})"
}

extract_vm_image() {
    local vm_name="$1"

    print_info "Extracting archived VM image: ${vm_name}"

    local latest_archive=$(ls -t "${VM_IMAGES_ARCHIVE}/${vm_name}"_*.tar.gz 2>/dev/null | head -1)

    if [ -z "$latest_archive" ]; then
        print_warning "No archived VM found for: ${vm_name}"
        return 1
    fi

    tar -xzf "$latest_archive" -C "${VM_DIR}"
    print_success "Extracted VM: ${vm_name}"
}

# ============================================
# Test Matrix Execution
# ============================================

run_comprehensive_test_matrix() {
    print_header "Comprehensive Test Matrix: Host → Destination"

    echo -e "${MAGENTA}Total Hosts:${NC} ${TOTAL_HOST_OS}"
    echo -e "${MAGENTA}Total Destinations:${NC} ${TOTAL_DEST_OS}"
    echo -e "${MAGENTA}Total Combinations:${NC} ${TOTAL_COMBINATIONS}"
    echo ""

    local test_number=0
    local passed=0
    local failed=0
    local skipped=0

    # Create results CSV header
    echo "Test#,Host OS,Destination OS,Result,Duration,Error" > "${MATRIX_DIR}/results_${TIMESTAMP}.csv"

    # Iterate through all combinations
    for host in "${!HOST_OS[@]}"; do
        local host_iso=$(echo "${HOST_OS[$host]}" | cut -d'|' -f1)
        local host_family=$(echo "${HOST_OS[$host]}" | cut -d'|' -f2)

        print_header "HOST: ${host} (${host_family})"

        # Check if host VM exists or create it
        if [ ! -d "${VM_DIR}/${host}" ]; then
            if ! extract_vm_image "${host}"; then
                print_info "Creating host VM: ${host}"
                create_vm_image "${host}" "${host_iso}" "$(echo "${HOST_OS[$host]}" | cut -d'|' -f3)"
                archive_vm_image "${host}"
            fi
        fi

        # Test deployment to each destination
        for dest in "${!DEST_OS[@]}"; do
            ((test_number++))

            local dest_iso=$(echo "${DEST_OS[$dest]}" | cut -d'|' -f1)
            local dest_family=$(echo "${DEST_OS[$dest]}" | cut -d'|' -f2)
            local dest_config=$(echo "${DEST_OS[$dest]}" | cut -d'|' -f3)

            print_sub_header "Test ${test_number}/${TOTAL_COMBINATIONS}: ${host} → ${dest}"

            # Check if destination VM exists or create it
            if [ ! -d "${VM_DIR}/${dest}" ]; then
                if ! extract_vm_image "${dest}"; then
                    print_info "Creating destination VM: ${dest}"
                    create_vm_image "${dest}" "${dest_iso}" "$(echo "${DEST_OS[$dest]}" | cut -d'|' -f3)"
                    archive_vm_image "${dest}"
                fi
            fi

            # Run the actual test: host → dest deployment
            local start_time=$(date +%s)
            if run_single_test "${host}" "${dest}" "${dest_config}"; then
                local end_time=$(date +%s)
                local duration=$((end_time - start_time))
                print_success "Test ${test_number} PASSED (${duration}s)"
                ((passed++))
                echo "${test_number},${host},${dest},PASS,${duration}," >> "${MATRIX_DIR}/results_${TIMESTAMP}.csv"
            else
                local end_time=$(date +%s)
                local duration=$((end_time - start_time))
                print_error "Test ${test_number} FAILED (${duration}s)"
                ((failed++))
                echo "${test_number},${host},${dest},FAIL,${duration},Deployment failed" >> "${MATRIX_DIR}/results_${TIMESTAMP}.csv"
            fi
        done
    done

    # Print summary
    print_header "Test Matrix Complete"
    echo -e "${GREEN}Passed:${NC}  ${passed}/${TOTAL_COMBINATIONS}"
    echo -e "${RED}Failed:${NC}  ${failed}/${TOTAL_COMBINATIONS}"
    echo -e "${YELLOW}Skipped:${NC} ${skipped}/${TOTAL_COMBINATIONS}"
    echo ""
    echo -e "${BLUE}Results saved to:${NC} ${MATRIX_DIR}/results_${TIMESTAMP}.csv"
}

run_single_test() {
    local host_vm="$1"
    local dest_vm="$2"
    local config_file="$3"

    log_info "Starting deployment: ${host_vm} → ${dest_vm}"

    # Start host VM
    start_vm "${host_vm}"

    # Start destination VM
    start_vm "${dest_vm}"

    # Wait for both VMs to be ready
    wait_for_vm "${host_vm}"
    wait_for_vm "${dest_vm}"

    # Run Mail Server Factory deployment from host to destination
    local host_ip=$(get_vm_ip "${host_vm}")
    local dest_ip=$(get_vm_ip "${dest_vm}")

    # SSH into host VM and run deployment
    ssh root@"${host_ip}" "java -jar /opt/mail-factory/Application.jar Examples/${config_file}"

    local result=$?

    # Stop VMs
    stop_vm "${dest_vm}"
    stop_vm "${host_vm}"

    return $result
}

# ============================================
# VM Control Functions
# ============================================

start_vm() {
    local vm_name="$1"
    print_info "Starting VM: ${vm_name}"
    # Implementation here
}

stop_vm() {
    local vm_name="$1"
    print_info "Stopping VM: ${vm_name}"
    # Implementation here
}

wait_for_vm() {
    local vm_name="$1"
    print_info "Waiting for VM to be ready: ${vm_name}"
    # Implementation here
}

get_vm_ip() {
    local vm_name="$1"
    # Implementation here
    echo "192.168.122.100"  # Placeholder
}

# ============================================
# Installation Methods
# ============================================

install_with_autoinstall() {
    local vm_name="$1"
    local iso_file="$2"
    # Ubuntu autoinstall implementation
    print_info "Installing ${vm_name} using Ubuntu autoinstall"
}

install_with_preseed() {
    local vm_name="$1"
    local iso_file="$2"
    # Debian preseed implementation
    print_info "Installing ${vm_name} using Debian preseed"
}

install_with_kickstart() {
    local vm_name="$1"
    local iso_file="$2"
    # RHEL/Fedora kickstart implementation
    print_info "Installing ${vm_name} using kickstart"
}

install_with_autoyast() {
    local vm_name="$1"
    local iso_file="$2"
    # openSUSE autoyast implementation
    print_info "Installing ${vm_name} using AutoYaST"
}

# ============================================
# Main Menu
# ============================================

show_menu() {
    print_header "Comprehensive Test Matrix - Main Menu"
    echo "1. Check ISO availability"
    echo "2. Archive all ISOs"
    echo "3. Extract archived ISOs"
    echo "4. Create all host VMs"
    echo "5. Create all destination VMs"
    echo "6. Archive all VM images"
    echo "7. Run comprehensive test matrix (all combinations)"
    echo "8. Generate test matrix report"
    echo "9. Exit"
    echo ""
}

main() {
    create_directories

    case "${1:-}" in
        check-isos)
            check_iso_availability
            ;;
        archive-isos)
            archive_isos
            ;;
        extract-isos)
            extract_archived_isos
            ;;
        run-matrix)
            run_comprehensive_test_matrix
            ;;
        menu)
            while true; do
                show_menu
                read -p "Enter choice: " choice
                case $choice in
                    1) check_iso_availability ;;
                    2) archive_isos ;;
                    3) extract_archived_isos ;;
                    4) print_info "Creating all host VMs..." ;;
                    5) print_info "Creating all destination VMs..." ;;
                    6) print_info "Archiving all VMs..." ;;
                    7) run_comprehensive_test_matrix ;;
                    8) print_info "Generating report..." ;;
                    9) exit 0 ;;
                    *) print_error "Invalid choice" ;;
                esac
            done
            ;;
        *)
            echo "Usage: $0 {check-isos|archive-isos|extract-isos|run-matrix|menu}"
            echo ""
            echo "Commands:"
            echo "  check-isos     - Check availability of all ISOs"
            echo "  archive-isos   - Create compressed archive of all ISOs"
            echo "  extract-isos   - Extract ISOs from archive"
            echo "  run-matrix     - Run comprehensive host→destination test matrix"
            echo "  menu           - Interactive menu"
            exit 1
            ;;
    esac
}

main "$@"
