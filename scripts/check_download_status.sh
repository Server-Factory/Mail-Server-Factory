#!/usr/bin/env bash

# Check Download Status - Monitor ISO downloads and provide status updates

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
ISO_DIR="${PROJECT_ROOT}/isos"
LOG_FILE="${ISO_DIR}/download.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${BLUE}================================================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}================================================================${NC}"
    echo ""
}

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ $1${NC}"; }

# Expected ISOs with sizes
declare -A EXPECTED_ISOS=(
    ["ubuntu-22.04.5-live-server-amd64.iso"]="2.5G"
    ["ubuntu-24.04.3-live-server-amd64.iso"]="2.8G"
    ["debian-11.12.0-amd64-netinst.iso"]="400M"
    ["debian-12.9.0-amd64-netinst.iso"]="650M"
    ["Fedora-Server-dvd-x86_64-38-1.6.iso"]="2.5G"
    ["Fedora-Server-dvd-x86_64-39-1.5.iso"]="2.5G"
    ["Fedora-Server-dvd-x86_64-40-1.14.iso"]="2.8G"
    ["Fedora-Server-dvd-x86_64-41-1.4.iso"]="2.8G"
    ["AlmaLinux-9.5-x86_64-dvd.iso"]="10G"
    ["Rocky-9.5-x86_64-dvd.iso"]="10G"
    ["openSUSE-Leap-15.6-DVD-x86_64-Media.iso"]="4.7G"
)

check_download_process() {
    if pgrep -f "iso_manager.sh download" > /dev/null; then
        print_info "Download process is running"
        return 0
    else
        print_warning "Download process is not running"
        return 1
    fi
}

check_iso_status() {
    local total=${#EXPECTED_ISOS[@]}
    local downloaded=0
    local in_progress=0
    local missing=0

    print_header "ISO Download Status"

    printf "%-50s %-12s %-12s %-10s\n" "ISO File" "Expected" "Current" "Status"
    printf "%-50s %-12s %-12s %-10s\n" "--------" "--------" "-------" "------"

    for iso in "${!EXPECTED_ISOS[@]}"; do
        local iso_path="${ISO_DIR}/${iso}"
        local expected_size="${EXPECTED_ISOS[$iso]}"

        if [ -f "${iso_path}" ]; then
            local current_size=$(du -h "${iso_path}" | cut -f1)
            local size_bytes=$(stat -f%z "${iso_path}" 2>/dev/null || stat -c%s "${iso_path}" 2>/dev/null)

            # Simple size check - if file is > 50MB and appears complete
            if [[ "${current_size}" == *"G"* ]] || [[ "${size_bytes}" -gt 52428800 ]]; then
                printf "%-50s %-12s %-12s ${GREEN}%-10s${NC}\n" "${iso}" "${expected_size}" "${current_size}" "Complete"
                downloaded=$((downloaded + 1))
            else
                printf "%-50s %-12s %-12s ${YELLOW}%-10s${NC}\n" "${iso}" "${expected_size}" "${current_size}" "Downloading"
                in_progress=$((in_progress + 1))
            fi
        else
            printf "%-50s %-12s %-12s ${RED}%-10s${NC}\n" "${iso}" "${expected_size}" "N/A" "Missing"
            missing=$((missing + 1))
        fi
    done

    echo ""
    print_header "Summary"
    echo -e "Total ISOs:       ${total}"
    echo -e "${GREEN}Downloaded:       ${downloaded}${NC}"
    echo -e "${YELLOW}In Progress:      ${in_progress}${NC}"
    echo -e "${RED}Missing:          ${missing}${NC}"
    echo ""

    local percentage=$((downloaded * 100 / total))
    echo -e "Progress: ${percentage}% complete"
}

show_disk_usage() {
    print_header "Disk Usage"

    local iso_size=$(du -sh "${ISO_DIR}" | cut -f1)
    echo "ISO Directory: ${iso_size}"

    echo ""
    echo "Disk Space:"
    df -h "${ISO_DIR}" | tail -1
}

show_recent_activity() {
    print_header "Recent Download Activity"

    if [ -f "${LOG_FILE}" ]; then
        echo "Last 20 lines of download log:"
        echo ""
        tail -n 20 "${LOG_FILE}"
    else
        print_warning "No download log found"
    fi
}

monitor_live() {
    print_header "Live Download Monitor (Ctrl+C to exit)"
    echo ""

    if [ ! -f "${LOG_FILE}" ]; then
        print_warning "No download log found. Start downloads with:"
        echo "./scripts/iso_manager.sh download"
        exit 1
    fi

    tail -f "${LOG_FILE}"
}

show_help() {
    cat <<EOF
Check Download Status - Monitor ISO downloads

Usage: $(basename "$0") [COMMAND]

Commands:
    status      Show download status (default)
    disk        Show disk usage information
    log         Show recent download activity
    monitor     Monitor downloads in real-time
    help        Show this help message

Examples:
    $(basename "$0")              # Show status
    $(basename "$0") status       # Show status
    $(basename "$0") monitor      # Watch downloads live

EOF
}

main() {
    local command="${1:-status}"

    case "${command}" in
        status)
            check_download_process
            echo ""
            check_iso_status
            show_disk_usage
            ;;
        disk)
            show_disk_usage
            ;;
        log)
            show_recent_activity
            ;;
        monitor)
            monitor_live
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo "Unknown command: ${command}"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
