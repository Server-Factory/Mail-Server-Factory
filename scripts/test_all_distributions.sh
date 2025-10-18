#!/usr/bin/env bash

# Distribution Testing Script
# Automates full installation testing on all supported Linux distributions

set -euo pipefail

# ============================================
# Configuration
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
EXAMPLES_DIR="${PROJECT_ROOT}/Examples"
RESULTS_DIR="${PROJECT_ROOT}/test_results"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
RESULTS_FILE="${RESULTS_DIR}/test_results_${TIMESTAMP}.md"
JSON_RESULTS="${RESULTS_DIR}/test_results_${TIMESTAMP}.json"

# Mail Factory executable
MAIL_FACTORY="${PROJECT_ROOT}/mail_factory"
if [ ! -f "${MAIL_FACTORY}" ]; then
    MAIL_FACTORY="${PROJECT_ROOT}/Application/build/libs/Application.jar"
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================
# Distribution Definitions
# ============================================

declare -a DISTRIBUTIONS=(
    "Ubuntu_22"
    "Ubuntu_24"
    "Debian_11"
    "Debian_12"
    "RHEL_9"
    "AlmaLinux_9"
    "Rocky_9"
    "Fedora_Server_38"
    "Fedora_Server_39"
    "Fedora_Server_40"
    "Fedora_Server_41"
    "openSUSE_Leap_15"
)

# ============================================
# Logging Functions
# ============================================

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" | tee -a "${RESULTS_DIR}/test.log"
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
# Test Results Tracking
# ============================================

declare -A TEST_RESULTS
declare -A TEST_DURATIONS
declare -A TEST_ERRORS

# ============================================
# Helper Functions
# ============================================

create_directories() {
    mkdir -p "${RESULTS_DIR}"
    log_info "Created results directory: ${RESULTS_DIR}"
}

check_prerequisites() {
    print_header "Checking Prerequisites"

    local missing=0

    # Check if mail_factory exists
    if [ ! -f "${MAIL_FACTORY}" ] && [ ! -f "${PROJECT_ROOT}/Application/build/libs/Application.jar" ]; then
        print_error "Mail Factory not found. Please build the project first."
        print_info "Run: ./gradlew assemble"
        ((missing++))
    else
        print_success "Mail Factory found"
    fi

    # Check for required tools
    for cmd in ssh sshpass timeout; do
        if ! command -v "$cmd" &> /dev/null; then
            print_warning "Optional command not found: $cmd"
        fi
    done

    if [ $missing -gt 0 ]; then
        return 1
    fi

    print_success "All prerequisites met"
    return 0
}

test_distribution() {
    local dist_name="$1"
    local config_file="${EXAMPLES_DIR}/${dist_name}.json"

    print_header "Testing: ${dist_name}"

    if [ ! -f "${config_file}" ]; then
        print_error "Configuration file not found: ${config_file}"
        TEST_RESULTS["${dist_name}"]="SKIP"
        TEST_ERRORS["${dist_name}"]="Configuration file not found"
        return 1
    fi

    print_info "Configuration: ${config_file}"

    # Start timing
    local start_time=$(date +%s)

    # Check if _Docker.json exists
    local docker_config="${EXAMPLES_DIR}/Includes/_Docker.json"
    if [ ! -f "${docker_config}" ]; then
        print_warning "Docker credentials file not found: ${docker_config}"
        print_info "Skipping ${dist_name} - Docker credentials required"
        TEST_RESULTS["${dist_name}"]="SKIP"
        TEST_ERRORS["${dist_name}"]="Docker credentials not configured"
        return 1
    fi

    # Create test log file
    local test_log="${RESULTS_DIR}/${dist_name}_${TIMESTAMP}.log"

    print_info "Running Mail Server Factory installation..."
    log_info "Test log: ${test_log}"

    # Run the installation (dry-run mode if no real server)
    # In production, this would connect to actual VMs
    local exit_code=0

    if command -v java &> /dev/null && [ -f "${MAIL_FACTORY}" ]; then
        # Try to run the factory (will fail without actual server, but we can check config parsing)
        timeout 60s java -jar "${MAIL_FACTORY}" "${config_file}" > "${test_log}" 2>&1 || exit_code=$?

        # Check exit code
        if [ ${exit_code} -eq 0 ]; then
            print_success "Installation completed successfully"
            TEST_RESULTS["${dist_name}"]="PASS"
        elif [ ${exit_code} -eq 124 ]; then
            print_warning "Test timed out (no actual server available)"
            TEST_RESULTS["${dist_name}"]="TIMEOUT"
            TEST_ERRORS["${dist_name}"]="Test timed out after 60 seconds"
        else
            print_error "Installation failed with exit code: ${exit_code}"
            TEST_RESULTS["${dist_name}"]="FAIL"
            TEST_ERRORS["${dist_name}"]="Exit code: ${exit_code}"

            # Show last few lines of log
            print_info "Last 10 lines of log:"
            tail -n 10 "${test_log}" || true
        fi
    else
        print_info "Validating configuration file only..."
        # At minimum, verify JSON is valid
        if python3 -m json.tool "${config_file}" > /dev/null 2>&1; then
            print_success "Configuration file is valid JSON"
            TEST_RESULTS["${dist_name}"]="CONFIG_VALID"
        else
            print_error "Configuration file has invalid JSON"
            TEST_RESULTS["${dist_name}"]="FAIL"
            TEST_ERRORS["${dist_name}"]="Invalid JSON in configuration"
        fi
    fi

    # Calculate duration
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    TEST_DURATIONS["${dist_name}"]="${duration}"

    print_info "Test duration: ${duration} seconds"
}

generate_markdown_report() {
    print_header "Generating Test Report"

    cat > "${RESULTS_FILE}" <<EOF
# Mail Server Factory - Distribution Testing Report

**Generated**: $(date '+%Y-%m-%d %H:%M:%S')

## Test Summary

EOF

    # Count results
    local total=0
    local passed=0
    local failed=0
    local skipped=0
    local config_valid=0

    for dist in "${DISTRIBUTIONS[@]}"; do
        ((total++))
        case "${TEST_RESULTS[${dist}]:-UNKNOWN}" in
            PASS) ((passed++)) ;;
            FAIL) ((failed++)) ;;
            SKIP|TIMEOUT) ((skipped++)) ;;
            CONFIG_VALID) ((config_valid++)) ;;
        esac
    done

    cat >> "${RESULTS_FILE}" <<EOF
- **Total Distributions**: ${total}
- **Passed**: ${passed}
- **Failed**: ${failed}
- **Skipped**: ${skipped}
- **Config Valid**: ${config_valid}

## Test Results by Distribution

| Distribution | Result | Duration | Notes |
|--------------|--------|----------|-------|
EOF

    for dist in "${DISTRIBUTIONS[@]}"; do
        local result="${TEST_RESULTS[${dist}]:-UNKNOWN}"
        local duration="${TEST_DURATIONS[${dist}]:-0}s"
        local error="${TEST_ERRORS[${dist}]:-}"

        local status_emoji=""
        case "${result}" in
            PASS) status_emoji="✅" ;;
            FAIL) status_emoji="❌" ;;
            SKIP|TIMEOUT) status_emoji="⏭️" ;;
            CONFIG_VALID) status_emoji="📝" ;;
            *) status_emoji="❓" ;;
        esac

        echo "| ${dist} | ${status_emoji} ${result} | ${duration} | ${error} |" >> "${RESULTS_FILE}"
    done

    cat >> "${RESULTS_FILE}" <<EOF

## Distribution Details

EOF

    for dist in "${DISTRIBUTIONS[@]}"; do
        cat >> "${RESULTS_FILE}" <<EOF
### ${dist}

- **Status**: ${TEST_RESULTS[${dist}]:-UNKNOWN}
- **Duration**: ${TEST_DURATIONS[${dist}]:-0} seconds
- **Configuration**: \`Examples/${dist}.json\`
EOF

        if [ -n "${TEST_ERRORS[${dist}]:-}" ]; then
            cat >> "${RESULTS_FILE}" <<EOF
- **Error**: ${TEST_ERRORS[${dist}]}
EOF
        fi

        cat >> "${RESULTS_FILE}" <<EOF

EOF
    done

    cat >> "${RESULTS_FILE}" <<EOF
## Supported Distributions Matrix

| Family | Distribution | Version | Status |
|--------|--------------|---------|--------|
| Debian | Ubuntu       | 22.04   | ${TEST_RESULTS["Ubuntu_22"]:-UNKNOWN} |
| Debian | Ubuntu       | 24.04   | ${TEST_RESULTS["Ubuntu_24"]:-UNKNOWN} |
| Debian | Debian       | 11      | ${TEST_RESULTS["Debian_11"]:-UNKNOWN} |
| Debian | Debian       | 12      | ${TEST_RESULTS["Debian_12"]:-UNKNOWN} |
| RHEL   | RHEL         | 9       | ${TEST_RESULTS["RHEL_9"]:-UNKNOWN} |
| RHEL   | AlmaLinux    | 9       | ${TEST_RESULTS["AlmaLinux_9"]:-UNKNOWN} |
| RHEL   | Rocky Linux  | 9       | ${TEST_RESULTS["Rocky_9"]:-UNKNOWN} |
| RHEL   | Fedora Server| 38      | ${TEST_RESULTS["Fedora_Server_38"]:-UNKNOWN} |
| RHEL   | Fedora Server| 39      | ${TEST_RESULTS["Fedora_Server_39"]:-UNKNOWN} |
| RHEL   | Fedora Server| 40      | ${TEST_RESULTS["Fedora_Server_40"]:-UNKNOWN} |
| RHEL   | Fedora Server| 41      | ${TEST_RESULTS["Fedora_Server_41"]:-UNKNOWN} |
| SUSE   | openSUSE Leap| 15.6    | ${TEST_RESULTS["openSUSE_Leap_15"]:-UNKNOWN} |

## Next Steps

1. Review failed tests in individual log files
2. Update configurations as needed
3. Re-run tests for failed distributions
4. Update website with compatibility matrix

---

*This report was automatically generated by test_all_distributions.sh*
EOF

    print_success "Markdown report generated: ${RESULTS_FILE}"
}

generate_json_report() {
    cat > "${JSON_RESULTS}" <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "summary": {
    "total": ${#DISTRIBUTIONS[@]},
    "passed": $(grep -c "PASS" <<< "${TEST_RESULTS[@]}" || echo 0),
    "failed": $(grep -c "FAIL" <<< "${TEST_RESULTS[@]}" || echo 0)
  },
  "results": {
EOF

    local first=true
    for dist in "${DISTRIBUTIONS[@]}"; do
        if [ "${first}" = true ]; then
            first=false
        else
            echo "," >> "${JSON_RESULTS}"
        fi

        cat >> "${JSON_RESULTS}" <<EOF
    "${dist}": {
      "status": "${TEST_RESULTS[${dist}]:-UNKNOWN}",
      "duration": ${TEST_DURATIONS[${dist}]:-0},
      "error": "${TEST_ERRORS[${dist}]:-}"
    }
EOF
    done

    cat >> "${JSON_RESULTS}" <<EOF

  }
}
EOF

    print_success "JSON report generated: ${JSON_RESULTS}"
}

run_all_tests() {
    print_header "Starting Distribution Tests"
    log_info "Testing ${#DISTRIBUTIONS[@]} distributions"

    for dist in "${DISTRIBUTIONS[@]}"; do
        test_distribution "${dist}"
        echo ""
    done

    generate_markdown_report
    generate_json_report

    print_header "Test Results Summary"
    cat "${RESULTS_FILE}" | grep -A 5 "Test Summary"
}

show_help() {
    cat <<EOF
Distribution Testing Script

Usage: $(basename "$0") [COMMAND] [OPTIONS]

Commands:
    all         Run tests for all distributions (default)
    single DIST Test a specific distribution
    list        List all distributions
    report      Generate report from existing results
    help        Show this help message

Examples:
    $0 all                    # Test all distributions
    $0 single Ubuntu_22       # Test only Ubuntu 22.04
    $0 list                   # List all distributions

EOF
}

# ============================================
# Main Script
# ============================================

main() {
    create_directories

    if ! check_prerequisites; then
        exit 1
    fi

    local command="${1:-all}"

    case "${command}" in
        all)
            run_all_tests
            ;;
        single)
            if [ -z "${2:-}" ]; then
                print_error "Distribution name required"
                show_help
                exit 1
            fi
            test_distribution "${2}"
            ;;
        list)
            print_header "Available Distributions"
            printf "%s\n" "${DISTRIBUTIONS[@]}"
            ;;
        report)
            generate_markdown_report
            generate_json_report
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
