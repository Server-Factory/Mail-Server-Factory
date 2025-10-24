#!/bin/bash

#
# Master Test Runner for ISO Manager
#
# Runs all test suites (unit, integration, e2e, automation) and generates comprehensive report
#

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
RESULTS_DIR="${SCRIPT_DIR}/results"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
REPORT_FILE="${RESULTS_DIR}/test_report_${TIMESTAMP}.md"
JSON_REPORT="${RESULTS_DIR}/test_report_${TIMESTAMP}.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Test results
declare -A TEST_RESULTS
declare -A TEST_TIMES
declare -A TEST_DETAILS

# Create results directory
mkdir -p "${RESULTS_DIR}"

print_header() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_section() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

run_test_suite() {
    local test_name="$1"
    local test_script="$2"

    print_section "Running ${test_name}"

    if [[ ! -f "${test_script}" ]]; then
        echo -e "${RED}✗ Test script not found: ${test_script}${NC}"
        TEST_RESULTS["${test_name}"]="FAILED"
        TEST_DETAILS["${test_name}"]="Script not found"
        return 1
    fi

    # Make script executable
    chmod +x "${test_script}"

    local log_file="${RESULTS_DIR}/${test_name}_${TIMESTAMP}.log"
    local start_time=$(date +%s)

    # Run test and capture output
    if bash "${test_script}" > "${log_file}" 2>&1; then
        local exit_code=0
    else
        local exit_code=$?
    fi

    local end_time=$(date +%s)
    local elapsed=$((end_time - start_time))

    TEST_TIMES["${test_name}"]=${elapsed}

    # Parse results from output
    local passed=$(grep -c "✓ PASS" "${log_file}" 2>/dev/null || true)
    local failed=$(grep -c "✗ FAIL" "${log_file}" 2>/dev/null || true)
    local skipped=$(grep -c "⊘ SKIP" "${log_file}" 2>/dev/null || true)

    # Ensure numeric values
    passed=${passed:-0}
    failed=${failed:-0}
    skipped=${skipped:-0}

    local total=$((passed + failed + skipped))

    TEST_DETAILS["${test_name}"]="Total: ${total}, Passed: ${passed}, Failed: ${failed}, Skipped: ${skipped}"

    # Display summary
    echo -e "  Total tests:   ${total}"
    echo -e "  ${GREEN}Passed:        ${passed}${NC}"
    echo -e "  ${RED}Failed:        ${failed}${NC}"
    echo -e "  ${YELLOW}Skipped:       ${skipped}${NC}"
    echo -e "  Time:          ${elapsed}s"

    if [[ ${exit_code} -eq 0 ]] && [[ ${failed} -eq 0 ]]; then
        TEST_RESULTS["${test_name}"]="PASSED"
        echo -e "  ${GREEN}Status:        ✓ PASSED${NC}"
        return 0
    else
        TEST_RESULTS["${test_name}"]="FAILED"
        echo -e "  ${RED}Status:        ✗ FAILED${NC}"
        return 1
    fi
}

generate_markdown_report() {
    print_section "Generating Markdown Report"

    cat > "${REPORT_FILE}" <<EOF
# ISO Manager Test Report

**Generated:** $(date '+%Y-%m-%d %H:%M:%S')
**System:** $(uname -a)
**Test Environment:** $(hostname)

---

## Executive Summary

This report contains the results of comprehensive testing for the ISO Manager download system.
The test suite validates resume capability, corruption detection, retry mechanisms, and end-to-end workflows.

## Test Suites

EOF

    local total_suites=0
    local passed_suites=0
    local failed_suites=0

    for test_name in "${!TEST_RESULTS[@]}"; do
        total_suites=$((total_suites + 1))
        local status="${TEST_RESULTS[$test_name]}"
        local time="${TEST_TIMES[$test_name]}"
        local details="${TEST_DETAILS[$test_name]}"

        if [[ "${status}" == "PASSED" ]]; then
            passed_suites=$((passed_suites + 1))
            local status_icon="✅"
        else
            failed_suites=$((failed_suites + 1))
            local status_icon="❌"
        fi

        cat >> "${REPORT_FILE}" <<EOF
### ${status_icon} ${test_name}

- **Status:** ${status}
- **Duration:** ${time}s
- **Details:** ${details}
- **Log:** ${test_name}_${TIMESTAMP}.log

EOF
    done

    cat >> "${REPORT_FILE}" <<EOF

---

## Summary Statistics

| Metric | Value |
|--------|-------|
| Total Test Suites | ${total_suites} |
| ✅ Passed | ${passed_suites} |
| ❌ Failed | ${failed_suites} |
| Success Rate | $(( passed_suites * 100 / total_suites ))% |

EOF

    if [[ ${failed_suites} -eq 0 ]]; then
        cat >> "${REPORT_FILE}" <<EOF

## Overall Result: ✅ SUCCESS

All test suites passed successfully!

EOF
    else
        cat >> "${REPORT_FILE}" <<EOF

## Overall Result: ❌ FAILURE

Some test suites failed. Please review the logs for details.

EOF
    fi

    cat >> "${REPORT_FILE}" <<EOF

---

## Test Coverage

The ISO Manager has been tested with the following scenarios:

### Unit Tests
- Directory creation and initialization
- Remote file size detection
- Partial file validation (oversized, valid, complete)
- Corrupted partial file cleanup
- Checksum extraction (multiple formats)
- Checksum verification (SHA256/SHA512/MD5)
- Connection health checks

### Integration Tests
- Complete download and verification workflow
- Resume interrupted downloads
- Corrupted partial file detection and handling
- Retry on connection failure
- Parallel downloads
- Progress monitoring

### End-to-End Tests
- Real checksum file downloads
- ISO Manager commands (help, list, verify)
- Directory structure creation
- Connection health with real URLs
- Download tools availability
- Checksum tools availability

### Automation Tests
- Resume from 50% completion
- Resume from 90% completion
- Multiple interruptions and resumes
- Oversized partial file detection
- Corrupted partial file handling
- Network timeout retries
- Exponential backoff
- DNS failure handling
- Zero-byte file handling
- Very small file handling
- Concurrent downloads
- Download speed monitoring

---

## Test Artifacts

All test logs and results are available in:
\`${RESULTS_DIR}\`

EOF

    echo -e "${GREEN}Markdown report generated: ${REPORT_FILE}${NC}"
}

generate_json_report() {
    print_section "Generating JSON Report"

    local timestamp_iso=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    cat > "${JSON_REPORT}" <<EOF
{
  "timestamp": "${timestamp_iso}",
  "system": "$(uname -s)",
  "hostname": "$(hostname)",
  "test_suites": [
EOF

    local first=true
    for test_name in "${!TEST_RESULTS[@]}"; do
        if [[ "${first}" == "false" ]]; then
            echo "," >> "${JSON_REPORT}"
        fi
        first=false

        local status="${TEST_RESULTS[$test_name]}"
        local time="${TEST_TIMES[$test_name]}"
        local details="${TEST_DETAILS[$test_name]}"

        cat >> "${JSON_REPORT}" <<EOF
    {
      "name": "${test_name}",
      "status": "${status}",
      "duration_seconds": ${time},
      "details": "${details}"
    }
EOF
    done

    cat >> "${JSON_REPORT}" <<EOF

  ],
  "summary": {
    "total_suites": $(echo "${!TEST_RESULTS[@]}" | wc -w),
    "passed_suites": $(echo "${TEST_RESULTS[@]}" | tr ' ' '\n' | grep -c "PASSED" || echo "0"),
    "failed_suites": $(echo "${TEST_RESULTS[@]}" | tr ' ' '\n' | grep -c "FAILED" || echo "0")
  }
}
EOF

    echo -e "${GREEN}JSON report generated: ${JSON_REPORT}${NC}"
}

print_final_summary() {
    local total=0
    local passed=0
    local failed=0

    for status in "${TEST_RESULTS[@]}"; do
        total=$((total + 1))
        if [[ "${status}" == "PASSED" ]]; then
            passed=$((passed + 1))
        else
            failed=$((failed + 1))
        fi
    done

    print_header "FINAL TEST SUMMARY"

    echo -e "Total Test Suites:    ${total}"
    echo -e "${GREEN}Passed:               ${passed}${NC}"
    echo -e "${RED}Failed:               ${failed}${NC}"

    if [[ ${total} -gt 0 ]]; then
        local success_rate=$(( passed * 100 / total ))
        echo -e "Success Rate:         ${success_rate}%"
    fi

    echo ""
    echo -e "Reports Generated:"
    echo -e "  - Markdown: ${REPORT_FILE}"
    echo -e "  - JSON:     ${JSON_REPORT}"
    echo -e "  - Logs:     ${RESULTS_DIR}/*_${TIMESTAMP}.log"

    echo ""

    if [[ ${failed} -eq 0 ]]; then
        echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}  ✅ ALL TESTS PASSED! (100% Success Rate)${NC}"
        echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
        return 0
    else
        echo -e "${RED}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "${RED}  ❌ SOME TESTS FAILED${NC}"
        echo -e "${RED}═══════════════════════════════════════════════════════════════${NC}"
        return 1
    fi
}

main() {
    print_header "ISO Manager - Comprehensive Test Suite"

    echo -e "Test Environment:"
    echo -e "  Project Root:  ${PROJECT_ROOT}"
    echo -e "  Script Dir:    ${SCRIPT_DIR}"
    echo -e "  Results Dir:   ${RESULTS_DIR}"
    echo -e "  Timestamp:     ${TIMESTAMP}"
    echo ""

    # Check prerequisites
    echo -e "${CYAN}Checking Prerequisites:${NC}"
    if command -v wget &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} wget available"
    else
        echo -e "  ${YELLOW}⚠${NC} wget not available (some tests may be skipped)"
    fi

    if command -v curl &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} curl available"
    else
        echo -e "  ${YELLOW}⚠${NC} curl not available (some tests may be skipped)"
    fi

    if command -v python3 &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} python3 available (mock server enabled)"
    else
        echo -e "  ${YELLOW}⚠${NC} python3 not available (mock server tests will be skipped)"
    fi

    echo ""

    # Run all test suites
    run_test_suite "Unit Tests" "${SCRIPT_DIR}/test_iso_manager_unit.sh"
    run_test_suite "Integration Tests" "${SCRIPT_DIR}/test_iso_manager_integration.sh"
    run_test_suite "E2E Tests" "${SCRIPT_DIR}/test_iso_manager_e2e.sh"
    run_test_suite "Automation Tests" "${SCRIPT_DIR}/test_iso_manager_automation.sh"

    # Generate reports
    generate_markdown_report
    generate_json_report

    # Print final summary
    print_final_summary
}

# Run main
main "$@"
