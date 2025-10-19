#!/usr/bin/env bash

#
# Process Monitor - Check orchestration status without blocking
#
# This script provides non-blocking status checks for all running processes
#

set -euo pipefail

# ============================================
# Configuration
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
LOG_DIR="${PROJECT_ROOT}/orchestration_logs"
PID_DIR="${LOG_DIR}/pids"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================
# Functions
# ============================================

print_header() {
    echo ""
    echo -e "${BLUE}================================================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}================================================================${NC}"
    echo ""
}

check_process() {
    local pid_file="$1"
    local process_name=$(basename "$pid_file" .pid)

    if [ ! -f "$pid_file" ]; then
        return 1
    fi

    local pid=$(cat "$pid_file")

    if ps -p "$pid" > /dev/null 2>&1; then
        # Process is running
        local elapsed=$(ps -p "$pid" -o etimes= | tr -d ' ')
        local cpu=$(ps -p "$pid" -o %cpu= | tr -d ' ')
        local mem=$(ps -p "$pid" -o %mem= | tr -d ' ')

        echo -e "${GREEN}✓${NC} ${process_name} (PID: ${pid}) - Running"
        echo -e "  Elapsed: ${elapsed}s | CPU: ${cpu}% | Memory: ${mem}%"
        return 0
    else
        # Process finished
        echo -e "${YELLOW}●${NC} ${process_name} - Finished"
        return 2
    fi
}

show_log_tail() {
    local process_name="$1"
    local log_file="${LOG_DIR}/${process_name}.log"

    if [ -f "$log_file" ]; then
        echo -e "${CYAN}Last 5 lines of ${process_name} log:${NC}"
        tail -5 "$log_file" | sed 's/^/  /'
        echo ""
    fi
}

list_all_processes() {
    print_header "Process Status Monitor"

    if [ ! -d "$PID_DIR" ]; then
        echo -e "${YELLOW}No processes tracked yet${NC}"
        return
    fi

    local running_count=0
    local finished_count=0

    shopt -s nullglob
    for pid_file in "$PID_DIR"/*.pid; do
        if [ -f "$pid_file" ]; then
            check_process "$pid_file"
            local status=$?

            if [ $status -eq 0 ]; then
                ((running_count++))
            elif [ $status -eq 2 ]; then
                ((finished_count++))
            fi

            if [ "$SHOW_LOGS" = "true" ]; then
                local process_name=$(basename "$pid_file" .pid)
                show_log_tail "$process_name"
            fi

            echo ""
        fi
    done

    print_header "Summary"
    echo -e "${GREEN}Running:${NC} ${running_count}"
    echo -e "${YELLOW}Finished:${NC} ${finished_count}"
    echo ""
}

show_vm_status() {
    print_header "VM Status"

    local vm_dir="${PROJECT_ROOT}/vms"

    shopt -s nullglob
    for distro_dir in "$vm_dir"/*; do
        if [ -d "$distro_dir" ] && [ "$(basename "$distro_dir")" != "archive" ] && [ "$(basename "$distro_dir")" != "logs" ]; then
            local distro=$(basename "$distro_dir")
            local disk="$distro_dir/disk.qcow2"
            local pid_file="$distro_dir/vm.pid"

            echo -e "${BLUE}${distro}:${NC}"

            if [ -f "$disk" ]; then
                local disk_size=$(du -h "$disk" | cut -f1)
                echo -e "  Disk: ${disk_size}"
            else
                echo -e "  ${YELLOW}No disk image${NC}"
            fi

            if [ -f "$pid_file" ]; then
                local vm_pid=$(cat "$pid_file")
                if ps -p "$vm_pid" > /dev/null 2>&1; then
                    echo -e "  Status: ${GREEN}Running${NC} (PID: ${vm_pid})"
                else
                    echo -e "  Status: ${YELLOW}Stopped${NC}"
                fi
            else
                echo -e "  Status: ${YELLOW}Not started${NC}"
            fi

            # Check serial log for installation progress
            local serial_log="$distro_dir/serial.log"
            if [ -f "$serial_log" ]; then
                local log_size=$(wc -l < "$serial_log")
                echo -e "  Serial log: ${log_size} lines"

                # Look for completion indicators
                if grep -q "login:" "$serial_log" 2>/dev/null; then
                    echo -e "  ${GREEN}Installation appears complete (login prompt found)${NC}"
                elif grep -q "Installing" "$serial_log" 2>/dev/null; then
                    echo -e "  ${CYAN}Installation in progress${NC}"
                fi
            fi

            echo ""
        fi
    done
}

show_iso_status() {
    print_header "ISO Status"

    local iso_dir="${PROJECT_ROOT}/isos"

    if [ ! -d "$iso_dir" ]; then
        echo -e "${YELLOW}ISO directory does not exist${NC}"
        return
    fi

    local iso_count=$(find "$iso_dir" -name "*.iso" 2>/dev/null | wc -l)
    local total_size=$(du -sh "$iso_dir" 2>/dev/null | cut -f1)

    echo -e "ISO Count: ${GREEN}${iso_count}${NC}"
    echo -e "Total Size: ${total_size}"
    echo ""

    find "$iso_dir" -name "*.iso" -exec ls -lh {} \; 2>/dev/null | awk '{print "  " $9 " - " $5}'
}

show_test_results() {
    print_header "Test Results"

    local results_dir="${PROJECT_ROOT}/test_results"

    if [ ! -d "$results_dir" ]; then
        echo -e "${YELLOW}No test results yet${NC}"
        return
    fi

    local result_count=$(find "$results_dir" -name "*.md" -o -name "*.json" 2>/dev/null | wc -l)

    echo -e "Test reports found: ${result_count}"
    echo ""

    find "$results_dir" -type f -name "test_results_*.md" -o -name "test_results_*.json" 2>/dev/null | \
        while read -r file; do
            echo -e "  ${CYAN}$(basename "$file")${NC}"
        done
}

watch_mode() {
    while true; do
        clear
        list_all_processes
        show_vm_status
        echo ""
        echo -e "${BLUE}Refreshing every 30 seconds... (Ctrl+C to exit)${NC}"
        sleep 30
    done
}

kill_stuck_process() {
    local process_name="$1"
    local pid_file="${PID_DIR}/${process_name}.pid"

    if [ ! -f "$pid_file" ]; then
        echo -e "${RED}Process PID file not found: ${process_name}${NC}"
        return 1
    fi

    local pid=$(cat "$pid_file")

    if ps -p "$pid" > /dev/null 2>&1; then
        echo -e "${YELLOW}Killing process ${process_name} (PID: ${pid})${NC}"

        kill -TERM "$pid" 2>/dev/null || true
        sleep 2

        if ps -p "$pid" > /dev/null 2>&1; then
            echo -e "${YELLOW}Force killing ${process_name}${NC}"
            kill -KILL "$pid" 2>/dev/null || true
        fi

        rm -f "$pid_file"
        echo -e "${GREEN}Process ${process_name} killed${NC}"
    else
        echo -e "${YELLOW}Process ${process_name} is not running${NC}"
        rm -f "$pid_file"
    fi
}

# ============================================
# Main
# ============================================

SHOW_LOGS=false

case "${1:-status}" in
    status)
        list_all_processes
        ;;
    vms)
        show_vm_status
        ;;
    isos)
        show_iso_status
        ;;
    tests)
        show_test_results
        ;;
    all)
        list_all_processes
        show_vm_status
        show_iso_status
        show_test_results
        ;;
    watch)
        watch_mode
        ;;
    logs)
        SHOW_LOGS=true
        list_all_processes
        ;;
    kill)
        if [ $# -lt 2 ]; then
            echo "Usage: $0 kill <process_name>"
            exit 1
        fi
        kill_stuck_process "$2"
        ;;
    *)
        echo "Usage: $0 {status|vms|isos|tests|all|watch|logs|kill <process>}"
        echo ""
        echo "Commands:"
        echo "  status  - Show running processes"
        echo "  vms     - Show VM status"
        echo "  isos    - Show downloaded ISOs"
        echo "  tests   - Show test results"
        echo "  all     - Show everything"
        echo "  watch   - Auto-refresh status every 30s"
        echo "  logs    - Show process logs"
        echo "  kill    - Kill a stuck process"
        exit 1
        ;;
esac
