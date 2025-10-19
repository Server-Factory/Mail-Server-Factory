#!/usr/bin/env bash

#
# Periodic Status Check - Runs every 5 minutes
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
MONITOR="${SCRIPT_DIR}/process_monitor.sh"

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

print_separator() {
    echo -e "${BLUE}================================================================${NC}"
}

while true; do
    print_separator
    echo -e "${CYAN}📊 Status Check at $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    print_separator
    echo ""

    # Running processes
    echo -e "${GREEN}🔄 Running Processes:${NC}"
    "${MONITOR}" status 2>&1 || echo "  No processes running"
    echo ""

    # ISOs
    iso_count=$(ls -1 "${PROJECT_ROOT}/isos"/*.iso 2>/dev/null | wc -l)
    echo -e "${GREEN}💿 ISOs Downloaded: ${iso_count} / 12${NC}"
    if [ $iso_count -gt 0 ]; then
        ls -lh "${PROJECT_ROOT}/isos"/*.iso 2>/dev/null | awk '{print "  - " $9 " (" $5 ")"}'
    fi
    echo ""

    # VMs
    vm_count=$(ls -1d "${PROJECT_ROOT}/vms"/*/ 2>/dev/null | grep -v archive | grep -v logs | wc -l)
    echo -e "${GREEN}🖥️  VMs Created: ${vm_count} / 12${NC}"
    if [ $vm_count -gt 0 ]; then
        ls -1d "${PROJECT_ROOT}/vms"/*/ 2>/dev/null | grep -v archive | grep -v logs | while read vm; do
            distro=$(basename "$vm")
            if [ -f "$vm/vm.pid" ]; then
                pid=$(cat "$vm/vm.pid")
                if ps -p "$pid" > /dev/null 2>&1; then
                    echo "  - ${distro}: Running (PID: ${pid})"
                else
                    echo "  - ${distro}: Stopped"
                fi
            else
                echo "  - ${distro}: Created (not started)"
            fi
        done
    fi
    echo ""

    # Test Results
    test_count=$(ls -1 "${PROJECT_ROOT}/test_results"/*.md 2>/dev/null | wc -l)
    if [ $test_count -gt 0 ]; then
        echo -e "${GREEN}📝 Test Reports: ${test_count}${NC}"
        ls -1 "${PROJECT_ROOT}/test_results"/*.md 2>/dev/null | while read report; do
            echo "  - $(basename "$report")"
        done
        echo ""
    fi

    # Recent log activity
    echo -e "${GREEN}📋 Recent Activity (last 3 lines):${NC}"
    tail -3 "${PROJECT_ROOT}/orchestration_logs"/master_*.log 2>/dev/null | sed 's/^/  /' || echo "  No logs yet"
    echo ""

    # Disk space
    disk_free=$(df -h "${PROJECT_ROOT}" | tail -1 | awk '{print $4}')
    echo -e "${GREEN}💾 Disk Space Free: ${disk_free}${NC}"
    echo ""

    print_separator
    echo -e "${YELLOW}⏰ Next check in 5 minutes (at $(date -d '+5 minutes' '+%H:%M:%S'))${NC}"
    print_separator
    echo ""

    # Sleep for 5 minutes (300 seconds)
    sleep 300
done
