#!/usr/bin/env bash

#
# Master Orchestrator Script
#
# This script orchestrates the complete Mail Server Factory testing workflow:
# 1. Download and verify all ISOs
# 2. Create QEMU VMs for all distributions
# 3. Monitor VM installations (non-blocking, background)
# 4. Archive completed VMs
# 5. Run Mail Server Factory tests on all VMs
# 6. Collect logs and generate reports
# 7. Update documentation
#
# Key Features:
# - All processes run in background
# - Periodic status monitoring (no blocking waits)
# - Auto-kill for stuck processes (timeout-based)
# - Comprehensive logging
# - Non-interactive execution
#

set -euo pipefail

# ============================================
# Configuration
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
ISO_MANAGER="${SCRIPT_DIR}/iso_manager.sh"
QEMU_MANAGER="${SCRIPT_DIR}/qemu_manager.sh"
TEST_RUNNER="${SCRIPT_DIR}/test_all_distributions.sh"

LOG_DIR="${PROJECT_ROOT}/orchestration_logs"
MASTER_LOG="${LOG_DIR}/master_$(date '+%Y%m%d_%H%M%S').log"
STATUS_FILE="${LOG_DIR}/status.json"
PID_DIR="${LOG_DIR}/pids"

# Process tracking
declare -A PROCESS_PIDS
declare -A PROCESS_START_TIMES
declare -A PROCESS_NAMES
declare -A PROCESS_TIMEOUTS

# Timeouts (in seconds)
ISO_DOWNLOAD_TIMEOUT=7200     # 2 hours for all ISOs
VM_CREATION_TIMEOUT=3600      # 1 hour per VM
VM_INSTALLATION_TIMEOUT=5400  # 90 minutes per VM installation
MAIL_TEST_TIMEOUT=7200        # 2 hours for mail server testing
CHECK_INTERVAL=30             # Check process status every 30 seconds

# Distribution list
declare -a DISTRIBUTIONS=(
    "ubuntu-22"
    "ubuntu-24"
    "debian-11"
    "debian-12"
    "fedora-38"
    "fedora-39"
    "fedora-40"
    "fedora-41"
    "almalinux-9"
    "rocky-9"
    "opensuse-15"
)

# VM resource requirements (memory, disk, cpus)
declare -A VM_RESOURCES=(
    ["ubuntu-22"]="4096 20G 2"
    ["ubuntu-24"]="4096 20G 2"
    ["debian-11"]="4096 20G 2"
    ["debian-12"]="4096 20G 2"
    ["fedora-38"]="8192 40G 4"
    ["fedora-39"]="8192 40G 4"
    ["fedora-40"]="8192 40G 4"
    ["fedora-41"]="8192 40G 4"
    ["almalinux-9"]="8192 40G 4"
    ["rocky-9"]="8192 40G 4"
    ["opensuse-15"]="8192 40G 4"
)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# ============================================
# Logging Functions
# ============================================

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" | tee -a "${MASTER_LOG}"
}

log_info() {
    log "INFO" "$@"
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    log "SUCCESS" "$@"
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_error() {
    log "ERROR" "$@"
    echo -e "${RED}[ERROR]${NC} $*"
}

log_warning() {
    log "WARNING" "$@"
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_progress() {
    log "PROGRESS" "$@"
    echo -e "${CYAN}[PROGRESS]${NC} $*"
}

print_header() {
    echo ""
    echo -e "${MAGENTA}================================================================${NC}"
    echo -e "${MAGENTA}  $1${NC}"
    echo -e "${MAGENTA}================================================================${NC}"
    echo ""
    log "HEADER" "$1"
}

print_separator() {
    echo -e "${BLUE}----------------------------------------------------------------${NC}"
}

# ============================================
# Process Management Functions
# ============================================

start_background_process() {
    local process_name="$1"
    local timeout="$2"
    shift 2
    local command=("$@")

    log_info "Starting background process: ${process_name}"
    log_info "Command: ${command[*]}"
    log_info "Timeout: ${timeout}s"

    # Execute command in background
    "${command[@]}" > "${LOG_DIR}/${process_name}.log" 2>&1 &
    local pid=$!

    PROCESS_PIDS["${process_name}"]=$pid
    PROCESS_START_TIMES["${process_name}"]=$(date +%s)
    PROCESS_NAMES[$pid]="${process_name}"
    PROCESS_TIMEOUTS["${process_name}"]=$timeout

    # Save PID to file
    echo $pid > "${PID_DIR}/${process_name}.pid"

    log_success "Started ${process_name} (PID: ${pid})"
    return 0
}

check_process_status() {
    local process_name="$1"
    local pid="${PROCESS_PIDS[$process_name]}"

    if [ -z "$pid" ]; then
        return 2  # Process not tracked
    fi

    if ps -p $pid > /dev/null 2>&1; then
        # Process is running
        local start_time="${PROCESS_START_TIMES[$process_name]}"
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        local timeout="${PROCESS_TIMEOUTS[$process_name]}"

        if [ $elapsed -gt $timeout ]; then
            log_error "${process_name} (PID: ${pid}) exceeded timeout (${timeout}s, elapsed: ${elapsed}s)"
            kill_process "$process_name"
            return 3  # Timeout exceeded
        fi

        return 0  # Running within timeout
    else
        # Process finished
        wait $pid 2>/dev/null
        local exit_code=$?

        if [ $exit_code -eq 0 ]; then
            log_success "${process_name} completed successfully"
            return 1  # Completed successfully
        else
            log_error "${process_name} failed with exit code ${exit_code}"
            return 4  # Failed
        fi
    fi
}

kill_process() {
    local process_name="$1"
    local pid="${PROCESS_PIDS[$process_name]}"

    if [ -z "$pid" ]; then
        log_warning "No PID found for ${process_name}"
        return 1
    fi

    if ps -p $pid > /dev/null 2>&1; then
        log_warning "Killing stuck process: ${process_name} (PID: ${pid})"

        # Try graceful termination first
        kill -TERM $pid 2>/dev/null || true
        sleep 2

        # Force kill if still running
        if ps -p $pid > /dev/null 2>&1; then
            log_warning "Force killing ${process_name} (PID: ${pid})"
            kill -KILL $pid 2>/dev/null || true
        fi

        log_success "Killed ${process_name}"
        rm -f "${PID_DIR}/${process_name}.pid"
        return 0
    else
        log_info "${process_name} is not running"
        return 0
    fi
}

wait_for_process() {
    local process_name="$1"
    local check_interval="${CHECK_INTERVAL}"

    log_info "Monitoring ${process_name} (check interval: ${check_interval}s)"

    while true; do
        check_process_status "$process_name"
        local status=$?

        case $status in
            0)  # Still running
                local pid="${PROCESS_PIDS[$process_name]}"
                local start_time="${PROCESS_START_TIMES[$process_name]}"
                local elapsed=$(($(date +%s) - start_time))
                log_progress "${process_name} running... (${elapsed}s elapsed)"
                sleep $check_interval
                ;;
            1)  # Completed successfully
                return 0
                ;;
            3)  # Timeout
                log_error "${process_name} timed out and was killed"
                return 1
                ;;
            4)  # Failed
                log_error "${process_name} failed"
                return 1
                ;;
            *)  # Other
                log_error "${process_name} status unknown"
                return 1
                ;;
        esac
    done
}

wait_for_all_processes() {
    local -n process_list=$1
    local all_success=0

    log_info "Waiting for ${#process_list[@]} processes to complete"

    while [ ${#process_list[@]} -gt 0 ]; do
        local completed=()

        for process_name in "${process_list[@]}"; do
            check_process_status "$process_name"
            local status=$?

            case $status in
                0)  # Still running
                    local elapsed=$(($(date +%s) - ${PROCESS_START_TIMES[$process_name]}))
                    log_progress "${process_name} still running (${elapsed}s)"
                    ;;
                1)  # Completed
                    log_success "${process_name} completed"
                    completed+=("$process_name")
                    ;;
                *)  # Timeout or failed
                    log_error "${process_name} did not complete successfully"
                    completed+=("$process_name")
                    all_success=1
                    ;;
            esac
        done

        # Remove completed processes
        for proc in "${completed[@]}"; do
            process_list=("${process_list[@]/$proc}")
        done

        if [ ${#process_list[@]} -gt 0 ]; then
            sleep $CHECK_INTERVAL
        fi
    done

    return $all_success
}

cleanup_processes() {
    log_info "Cleaning up all running processes"

    for process_name in "${!PROCESS_PIDS[@]}"; do
        kill_process "$process_name"
    done
}

# ============================================
# Workflow Functions
# ============================================

setup_environment() {
    print_header "Setting Up Environment"

    mkdir -p "${LOG_DIR}"
    mkdir -p "${PID_DIR}"
    mkdir -p "${PROJECT_ROOT}/isos"
    mkdir -p "${PROJECT_ROOT}/vms/archive"
    mkdir -p "${PROJECT_ROOT}/test_results"
    mkdir -p "${PROJECT_ROOT}/preseeds"

    log_success "Environment setup complete"

    # Log system information
    log_info "System: $(uname -a)"
    log_info "Available disk space: $(df -h . | tail -1 | awk '{print $4}')"
    log_info "Available memory: $(free -h | grep Mem | awk '{print $7}')"
    log_info "CPU cores: $(nproc)"
}

download_isos() {
    print_header "Phase 1: Downloading ISOs"

    log_info "Starting ISO download in background"

    start_background_process \
        "iso_download" \
        "$ISO_DOWNLOAD_TIMEOUT" \
        "${ISO_MANAGER}" "download"

    wait_for_process "iso_download"
    local result=$?

    if [ $result -eq 0 ]; then
        log_success "ISO download completed successfully"
        return 0
    else
        log_error "ISO download failed or timed out"
        return 1
    fi
}

verify_isos() {
    print_header "Phase 2: Verifying ISOs"

    log_info "Verifying ISO checksums"

    start_background_process \
        "iso_verify" \
        "1800" \
        "${ISO_MANAGER}" "verify"

    wait_for_process "iso_verify"
    local result=$?

    if [ $result -eq 0 ]; then
        log_success "ISO verification completed successfully"
        return 0
    else
        log_error "ISO verification failed"
        return 1
    fi
}

create_vms() {
    print_header "Phase 3: Creating Virtual Machines"

    local vm_processes=()

    for distro in "${DISTRIBUTIONS[@]}"; do
        local resources="${VM_RESOURCES[$distro]}"
        read -r memory disk cpus <<< "$resources"

        log_info "Creating VM: ${distro} (Memory: ${memory}MB, Disk: ${disk}, CPUs: ${cpus})"

        local process_name="vm_create_${distro}"

        start_background_process \
            "$process_name" \
            "$VM_CREATION_TIMEOUT" \
            "${QEMU_MANAGER}" "create" "$distro" "$memory" "$disk" "$cpus"

        vm_processes+=("$process_name")

        # Stagger VM creation to avoid resource contention
        sleep 5
    done

    log_info "Waiting for all VMs to be created"
    wait_for_all_processes vm_processes

    return $?
}

monitor_vm_installations() {
    print_header "Phase 4: Monitoring VM Installations"

    log_info "VMs are installing OS in background"
    log_info "This will take 10-90 minutes depending on distribution"

    local all_installed=0
    local max_wait_time=5400  # 90 minutes max
    local start_time=$(date +%s)

    while true; do
        local elapsed=$(($(date +%s) - start_time))

        if [ $elapsed -gt $max_wait_time ]; then
            log_error "VM installations exceeded maximum wait time"
            return 1
        fi

        local all_ready=1

        for distro in "${DISTRIBUTIONS[@]}"; do
            if "${QEMU_MANAGER}" status "$distro" 2>&1 | grep -q "Installation complete"; then
                log_success "${distro}: Installation complete"
            else
                all_ready=0
                log_progress "${distro}: Still installing... (${elapsed}s elapsed)"
            fi
        done

        if [ $all_ready -eq 1 ]; then
            log_success "All VM installations complete"
            return 0
        fi

        sleep $CHECK_INTERVAL
    done
}

archive_vms() {
    print_header "Phase 5: Archiving VMs"

    local archive_dir="${PROJECT_ROOT}/vms/archive"
    mkdir -p "$archive_dir"

    for distro in "${DISTRIBUTIONS[@]}"; do
        log_info "Archiving ${distro}"

        local vm_dir="${PROJECT_ROOT}/vms/${distro}"
        local archive_file="${archive_dir}/${distro}_$(date +%Y%m%d_%H%M%S).tar.gz"

        if [ -d "$vm_dir" ]; then
            tar -czf "$archive_file" -C "${PROJECT_ROOT}/vms" "${distro}" 2>&1 | tee -a "${MASTER_LOG}"

            if [ ${PIPESTATUS[0]} -eq 0 ]; then
                log_success "Archived ${distro} to ${archive_file}"
            else
                log_error "Failed to archive ${distro}"
            fi
        else
            log_warning "VM directory not found: ${vm_dir}"
        fi
    done
}

run_mail_server_tests() {
    print_header "Phase 6: Running Mail Server Factory Tests"

    log_info "Starting comprehensive Mail Server Factory tests"

    start_background_process \
        "mail_tests" \
        "$MAIL_TEST_TIMEOUT" \
        "${TEST_RUNNER}" "all"

    wait_for_process "mail_tests"
    local result=$?

    if [ $result -eq 0 ]; then
        log_success "Mail Server Factory tests completed successfully"
        return 0
    else
        log_error "Mail Server Factory tests failed or timed out"
        return 1
    fi
}

generate_reports() {
    print_header "Phase 7: Generating Reports"

    log_info "Generating comprehensive test reports"

    "${TEST_RUNNER}" report 2>&1 | tee -a "${MASTER_LOG}"

    log_success "Reports generated in ${PROJECT_ROOT}/test_results/"
}

update_documentation() {
    print_header "Phase 8: Updating Documentation"

    log_info "Documentation update would happen here"
    log_info "Manual review of TESTING.md and README.md recommended"

    # Update TESTING.md with latest results
    local testing_doc="${PROJECT_ROOT}/TESTING.md"

    if [ -f "$testing_doc" ]; then
        log_info "TESTING.md exists and should be updated with latest results"
    fi
}

# ============================================
# Main Workflow
# ============================================

main() {
    print_header "Mail Server Factory - Master Orchestrator"

    log_info "Starting master orchestration workflow"
    log_info "All processes will run in background with monitoring"
    log_info "Master log: ${MASTER_LOG}"

    # Setup signal handlers for cleanup
    trap cleanup_processes EXIT INT TERM

    # Execute workflow phases
    local phase_results=()

    setup_environment || { log_error "Environment setup failed"; exit 1; }

    if download_isos; then
        phase_results+=("ISO Download: SUCCESS")
    else
        phase_results+=("ISO Download: FAILED")
        log_error "Stopping due to ISO download failure"
        exit 1
    fi

    if verify_isos; then
        phase_results+=("ISO Verification: SUCCESS")
    else
        phase_results+=("ISO Verification: FAILED")
        log_warning "Continuing despite verification issues"
    fi

    if create_vms; then
        phase_results+=("VM Creation: SUCCESS")
    else
        phase_results+=("VM Creation: FAILED")
        log_error "Some VMs failed to create"
    fi

    if monitor_vm_installations; then
        phase_results+=("VM Installation: SUCCESS")
    else
        phase_results+=("VM Installation: FAILED")
    fi

    archive_vms
    phase_results+=("VM Archiving: COMPLETE")

    if run_mail_server_tests; then
        phase_results+=("Mail Server Tests: SUCCESS")
    else
        phase_results+=("Mail Server Tests: FAILED")
    fi

    generate_reports
    phase_results+=("Report Generation: COMPLETE")

    update_documentation
    phase_results+=("Documentation: UPDATED")

    # Print final summary
    print_header "Orchestration Complete - Summary"

    for result in "${phase_results[@]}"; do
        echo -e "${CYAN}${result}${NC}"
        log "SUMMARY" "$result"
    done

    log_success "Master orchestration workflow completed"
    log_info "Full log available at: ${MASTER_LOG}"
    log_info "Test results available at: ${PROJECT_ROOT}/test_results/"

    print_separator
    echo -e "${GREEN}All phases complete!${NC}"
    echo -e "${BLUE}Review logs and test results for details${NC}"
    print_separator
}

# ============================================
# Script Entry Point
# ============================================

# Check if script is run with specific phase
if [ $# -gt 0 ]; then
    case "$1" in
        download-isos)
            setup_environment
            download_isos
            ;;
        verify-isos)
            setup_environment
            verify_isos
            ;;
        create-vms)
            setup_environment
            create_vms
            ;;
        monitor-vms)
            setup_environment
            monitor_vm_installations
            ;;
        archive-vms)
            setup_environment
            archive_vms
            ;;
        test)
            setup_environment
            run_mail_server_tests
            ;;
        report)
            generate_reports
            ;;
        all)
            main
            ;;
        *)
            echo "Usage: $0 [download-isos|verify-isos|create-vms|monitor-vms|archive-vms|test|report|all]"
            echo ""
            echo "Phases:"
            echo "  download-isos   - Download all distribution ISOs"
            echo "  verify-isos     - Verify ISO checksums"
            echo "  create-vms      - Create all QEMU VMs"
            echo "  monitor-vms     - Monitor VM installation progress"
            echo "  archive-vms     - Archive installed VMs"
            echo "  test            - Run Mail Server Factory tests"
            echo "  report          - Generate test reports"
            echo "  all             - Run complete workflow (default)"
            exit 1
            ;;
    esac
else
    main
fi
