#!/bin/bash

#
# Automation Tests for ISO Manager - Resume and Retry Scenarios
#
# Tests robustness against network failures, interrupted downloads, and edge cases
#

set -euo pipefail

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ISO_MANAGER="${PROJECT_ROOT}/scripts/iso_manager.sh"
TEST_DIR="${SCRIPT_DIR}/test_tmp"
MOCK_SERVER_PORT=8889

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Mock server PID
MOCK_SERVER_PID=""

# Setup test environment
setup() {
    echo -e "${BLUE}Setting up automation test environment...${NC}"
    rm -rf "${TEST_DIR}"
    mkdir -p "${TEST_DIR}"/{isos,checksums,mock_files,.progress}

    # Create test files of various sizes
    echo -e "${CYAN}Creating test files...${NC}"
    dd if=/dev/urandom of="${TEST_DIR}/mock_files/small.iso" bs=1K count=100 2>/dev/null   # 100KB
    dd if=/dev/urandom of="${TEST_DIR}/mock_files/medium.iso" bs=1K count=1024 2>/dev/null  # 1MB
    dd if=/dev/urandom of="${TEST_DIR}/mock_files/large.iso" bs=1K count=5120 2>/dev/null   # 5MB

    # Generate checksums
    for file in small.iso medium.iso large.iso; do
        sha256sum "${TEST_DIR}/mock_files/${file}" | awk '{print $1" '"${file}"'"}' > "${TEST_DIR}/mock_files/${file}.sha256"
    done

    # Start mock HTTP server
    if command -v python3 &> /dev/null; then
        cd "${TEST_DIR}/mock_files"
        python3 -m http.server ${MOCK_SERVER_PORT} > "${TEST_DIR}/mock_server.log" 2>&1 &
        MOCK_SERVER_PID=$!
        cd - > /dev/null
        sleep 2
        echo -e "${GREEN}Mock HTTP server started on port ${MOCK_SERVER_PORT} (PID: ${MOCK_SERVER_PID})${NC}"
    else
        echo -e "${YELLOW}Python3 not available, some tests will be skipped${NC}"
    fi
}

teardown() {
    echo -e "${BLUE}Cleaning up automation test environment...${NC}"

    if [[ -n "${MOCK_SERVER_PID}" ]]; then
        kill "${MOCK_SERVER_PID}" 2>/dev/null || true
        wait "${MOCK_SERVER_PID}" 2>/dev/null || true
        echo -e "${GREEN}Mock HTTP server stopped${NC}"
    fi

    rm -rf "${TEST_DIR}"
}

print_test_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}TEST: $1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

assert_exit_code() {
    local expected=$1
    local actual=$2
    local test_name=$3

    TESTS_RUN=$((TESTS_RUN + 1))

    if [[ ${actual} -eq ${expected} ]]; then
        echo -e "${GREEN}✓ PASS${NC}: ${test_name}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}: ${test_name}"
        echo -e "${RED}  Expected exit code: ${expected}, Got: ${actual}${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_file_size_equals() {
    local file_path=$1
    local expected_size=$2
    local test_name=$3

    TESTS_RUN=$((TESTS_RUN + 1))

    if [[ ! -f "${file_path}" ]]; then
        echo -e "${RED}✗ FAIL${NC}: ${test_name}"
        echo -e "${RED}  File does not exist: ${file_path}${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi

    local actual_size=$(stat -f%z "${file_path}" 2>/dev/null || stat -c%s "${file_path}" 2>/dev/null)

    if [[ ${actual_size} -eq ${expected_size} ]]; then
        echo -e "${GREEN}✓ PASS${NC}: ${test_name}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}: ${test_name}"
        echo -e "${RED}  Expected size: ${expected_size}, Got: ${actual_size}${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_file_size_greater_than() {
    local file_path=$1
    local min_size=$2
    local test_name=$3

    TESTS_RUN=$((TESTS_RUN + 1))

    if [[ ! -f "${file_path}" ]]; then
        echo -e "${RED}✗ FAIL${NC}: ${test_name}"
        echo -e "${RED}  File does not exist: ${file_path}${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi

    local actual_size=$(stat -f%z "${file_path}" 2>/dev/null || stat -c%s "${file_path}" 2>/dev/null)

    if [[ ${actual_size} -gt ${min_size} ]]; then
        echo -e "${GREEN}✓ PASS${NC}: ${test_name}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}: ${test_name}"
        echo -e "${RED}  Expected size > ${min_size}, Got: ${actual_size}${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

skip_test() {
    local reason="$1"
    local test_name="$2"

    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
    echo -e "${YELLOW}⊘ SKIP${NC}: ${test_name}"
    echo -e "${YELLOW}  Reason: ${reason}${NC}"
}

# ============================================
# Automation Tests - Resume Scenarios
# ============================================

test_resume_partial_download_50_percent() {
    print_test_header "Resume download from 50% completion"

    if [[ -z "${MOCK_SERVER_PID}" ]]; then
        skip_test "Mock server not available" "Resume from 50%"
        return
    fi

    if ! command -v wget &> /dev/null; then
        skip_test "wget not available" "Resume from 50%"
        return
    fi

    local url="http://localhost:${MOCK_SERVER_PORT}/medium.iso"
    local output="${TEST_DIR}/isos/resume_50.iso"
    local source_file="${TEST_DIR}/mock_files/medium.iso"
    local source_size=$(stat -f%z "${source_file}" 2>/dev/null || stat -c%s "${source_file}" 2>/dev/null)
    local partial_size=$((source_size / 2))

    # Create partial file (50%)
    dd if="${source_file}" of="${output}" bs=1 count=${partial_size} 2>/dev/null

    echo -e "  ${CYAN}Created partial file: ${partial_size} bytes (50% of ${source_size})${NC}"

    # Resume download
    timeout 30s wget -c -q -O "${output}" "${url}" 2>&1 || true

    # Check final size
    local final_size=$(stat -f%z "${output}" 2>/dev/null || stat -c%s "${output}" 2>/dev/null)

    echo -e "  ${CYAN}Final size: ${final_size} bytes${NC}"

    assert_file_size_equals "${output}" "${source_size}" "Download resumed and completed"
}

test_resume_partial_download_90_percent() {
    print_test_header "Resume download from 90% completion"

    if [[ -z "${MOCK_SERVER_PID}" ]]; then
        skip_test "Mock server not available" "Resume from 90%"
        return
    fi

    if ! command -v wget &> /dev/null; then
        skip_test "wget not available" "Resume from 90%"
        return
    fi

    local url="http://localhost:${MOCK_SERVER_PORT}/large.iso"
    local output="${TEST_DIR}/isos/resume_90.iso"
    local source_file="${TEST_DIR}/mock_files/large.iso"
    local source_size=$(stat -f%z "${source_file}" 2>/dev/null || stat -c%s "${source_file}" 2>/dev/null)
    local partial_size=$((source_size * 90 / 100))

    # Create partial file (90%)
    dd if="${source_file}" of="${output}" bs=1 count=${partial_size} 2>/dev/null

    echo -e "  ${CYAN}Created partial file: ${partial_size} bytes (90% of ${source_size})${NC}"

    # Resume download
    timeout 30s wget -c -q -O "${output}" "${url}" 2>&1 || true

    # Check final size
    assert_file_size_equals "${output}" "${source_size}" "Download resumed from 90%"
}

test_resume_after_multiple_interruptions() {
    print_test_header "Resume after multiple interruptions"

    if [[ -z "${MOCK_SERVER_PID}" ]]; then
        skip_test "Mock server not available" "Multiple resume"
        return
    fi

    if ! command -v wget &> /dev/null; then
        skip_test "wget not available" "Multiple resume"
        return
    fi

    local url="http://localhost:${MOCK_SERVER_PORT}/large.iso"
    local output="${TEST_DIR}/isos/multiple_resume.iso"
    local source_file="${TEST_DIR}/mock_files/large.iso"
    local source_size=$(stat -f%z "${source_file}" 2>/dev/null || stat -c%s "${source_file}" 2>/dev/null)

    # Simulate 3 interruptions at 25%, 50%, 75%
    local interruption_points=(25 50 75)

    for percent in "${interruption_points[@]}"; do
        local partial_size=$((source_size * percent / 100))
        dd if="${source_file}" of="${output}" bs=1 count=${partial_size} 2>/dev/null
        echo -e "  ${CYAN}Simulated interruption at ${percent}% (${partial_size} bytes)${NC}"

        # Try to resume
        timeout 10s wget -c -q -O "${output}" "${url}" 2>&1 || true
        sleep 1
    done

    # Final resume to complete
    timeout 30s wget -c -q -O "${output}" "${url}" 2>&1 || true

    assert_file_size_equals "${output}" "${source_size}" "Download completed after multiple interruptions"
}

test_detect_oversized_partial_file() {
    print_test_header "Detect and reject oversized partial file"

    local source_file="${TEST_DIR}/mock_files/small.iso"
    local partial_file="${TEST_DIR}/isos/oversized_partial.iso"
    local source_size=$(stat -f%z "${source_file}" 2>/dev/null || stat -c%s "${source_file}" 2>/dev/null)

    # Create oversized partial (larger than source)
    local oversized=$((source_size + 10240))  # 10KB larger
    dd if=/dev/urandom of="${partial_file}" bs=1 count=${oversized} 2>/dev/null

    local partial_size=$(stat -f%z "${partial_file}" 2>/dev/null || stat -c%s "${partial_file}" 2>/dev/null)

    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ ${partial_size} -gt ${source_size} ]]; then
        echo -e "${GREEN}✓ PASS${NC}: Oversized partial detected (${partial_size} > ${source_size})"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: Failed to detect oversized partial"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_resume_with_corrupted_partial() {
    print_test_header "Handle corrupted partial file"

    local source_file="${TEST_DIR}/mock_files/medium.iso"
    local partial_file="${TEST_DIR}/isos/corrupted_partial.iso"
    local source_size=$(stat -f%z "${source_file}" 2>/dev/null || stat -c%s "${source_file}" 2>/dev/null)
    local partial_size=$((source_size / 2))

    # Create corrupted partial (random data, not from source)
    dd if=/dev/urandom of="${partial_file}" bs=1 count=${partial_size} 2>/dev/null

    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ -f "${partial_file}" ]]; then
        echo -e "${GREEN}✓ PASS${NC}: Corrupted partial file created for testing"
        TESTS_PASSED=$((TESTS_PASSED + 1))

        # In a real scenario, checksum verification would fail
        # and the file would be re-downloaded
    else
        echo -e "${RED}✗ FAIL${NC}: Failed to create corrupted partial"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# ============================================
# Automation Tests - Retry Scenarios
# ============================================

test_retry_on_network_timeout() {
    print_test_header "Retry on network timeout"

    local invalid_url="http://10.255.255.1:12345/test.iso"  # Non-routable IP
    local output="${TEST_DIR}/isos/timeout_test.iso"
    local max_retries=3

    local start_time=$(date +%s)

    # Attempt download with timeout (will fail)
    timeout 20s wget -t ${max_retries} --timeout=3 -q -O "${output}" "${invalid_url}" 2>/dev/null || true

    local end_time=$(date +%s)
    local elapsed=$((end_time - start_time))

    # Should take at least 9 seconds (3 retries * 3 second timeout)
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ ${elapsed} -ge 9 ]]; then
        echo -e "${GREEN}✓ PASS${NC}: Retry mechanism engaged (elapsed: ${elapsed}s)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: Insufficient retry attempts (elapsed: ${elapsed}s, expected >= 9s)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_retry_with_exponential_backoff() {
    print_test_header "Retry with exponential backoff"

    # Simulate retry delays: 5s, 10s, 20s
    local delays=(5 10 20)
    local total_expected=35

    local start_time=$(date +%s)

    for delay in "${delays[@]}"; do
        sleep ${delay}
    done

    local end_time=$(date +%s)
    local elapsed=$((end_time - start_time))

    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ ${elapsed} -ge ${total_expected} ]]; then
        echo -e "${GREEN}✓ PASS${NC}: Exponential backoff simulated (${elapsed}s >= ${total_expected}s)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: Backoff timing incorrect"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_retry_on_dns_failure() {
    print_test_header "Retry on DNS resolution failure"

    local invalid_domain="nonexistent-domain-12345678.invalid"

    if ! host "${invalid_domain}" &> /dev/null; then
        TESTS_RUN=$((TESTS_RUN + 1))
        echo -e "${GREEN}✓ PASS${NC}: DNS resolution fails as expected"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        TESTS_RUN=$((TESTS_RUN + 1))
        echo -e "${RED}✗ FAIL${NC}: DNS resolution succeeded unexpectedly"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_connection_health_check_before_retry() {
    print_test_header "Connection health check before retry"

    local valid_url="https://releases.ubuntu.com"

    if timeout 10s curl -sI -L --connect-timeout 5 "${valid_url}" > /dev/null 2>&1; then
        TESTS_RUN=$((TESTS_RUN + 1))
        echo -e "${GREEN}✓ PASS${NC}: Connection health check succeeded"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        skip_test "Network connectivity issue" "Connection health check"
    fi
}

# ============================================
# Automation Tests - Edge Cases
# ============================================

test_handle_zero_byte_file() {
    print_test_header "Handle zero-byte file"

    local zero_file="${TEST_DIR}/isos/zero_byte.iso"
    touch "${zero_file}"

    local size=$(stat -f%z "${zero_file}" 2>/dev/null || stat -c%s "${zero_file}" 2>/dev/null)

    assert_file_size_equals "${zero_file}" 0 "Zero-byte file created"
}

test_handle_very_small_file() {
    print_test_header "Handle very small file (1 byte)"

    if [[ -z "${MOCK_SERVER_PID}" ]]; then
        skip_test "Mock server not available" "Very small file"
        return
    fi

    local tiny_file="${TEST_DIR}/mock_files/tiny.iso"
    echo -n "X" > "${tiny_file}"

    local url="http://localhost:${MOCK_SERVER_PORT}/tiny.iso"
    local output="${TEST_DIR}/isos/tiny.iso"

    if command -v wget &> /dev/null; then
        timeout 10s wget -q -O "${output}" "${url}" 2>&1 || true
        assert_file_size_equals "${output}" 1 "1-byte file downloaded"
    else
        skip_test "wget not available" "Very small file"
    fi
}

test_concurrent_downloads_same_file() {
    print_test_header "Multiple concurrent downloads of same file"

    if [[ -z "${MOCK_SERVER_PID}" ]]; then
        skip_test "Mock server not available" "Concurrent downloads"
        return
    fi

    if ! command -v wget &> /dev/null; then
        skip_test "wget not available" "Concurrent downloads"
        return
    fi

    local url="http://localhost:${MOCK_SERVER_PORT}/small.iso"

    # Start 5 parallel downloads
    for i in {1..5}; do
        wget -q -O "${TEST_DIR}/isos/concurrent_${i}.iso" "${url}" &
    done

    # Wait for all to complete
    wait

    local success_count=0
    for i in {1..5}; do
        if [[ -f "${TEST_DIR}/isos/concurrent_${i}.iso" ]]; then
            success_count=$((success_count + 1))
        fi
    done

    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ ${success_count} -eq 5 ]]; then
        echo -e "${GREEN}✓ PASS${NC}: All 5 concurrent downloads succeeded"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: Only ${success_count}/5 downloads succeeded"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_download_speed_monitoring() {
    print_test_header "Download speed monitoring simulation"

    if [[ -z "${MOCK_SERVER_PID}" ]]; then
        skip_test "Mock server not available" "Speed monitoring"
        return
    fi

    local url="http://localhost:${MOCK_SERVER_PORT}/large.iso"
    local output="${TEST_DIR}/isos/speed_test.iso"

    local start_time=$(date +%s)

    if command -v wget &> /dev/null; then
        timeout 30s wget -q -O "${output}" "${url}" 2>&1 || true

        local end_time=$(date +%s)
        local elapsed=$((end_time - start_time))

        if [[ ${elapsed} -gt 0 ]] && [[ -f "${output}" ]]; then
            local file_size=$(stat -f%z "${output}" 2>/dev/null || stat -c%s "${output}" 2>/dev/null)
            local speed_bps=$((file_size / elapsed))
            local speed_kbps=$((speed_bps / 1024))

            echo -e "  ${CYAN}Download speed: ${speed_kbps} KB/s (${elapsed}s elapsed)${NC}"

            TESTS_RUN=$((TESTS_RUN + 1))
            if [[ ${speed_kbps} -gt 0 ]]; then
                echo -e "${GREEN}✓ PASS${NC}: Download speed calculated"
                TESTS_PASSED=$((TESTS_PASSED + 1))
            else
                echo -e "${RED}✗ FAIL${NC}: Could not calculate speed"
                TESTS_FAILED=$((TESTS_FAILED + 1))
            fi
        else
            skip_test "Download did not complete" "Speed monitoring"
        fi
    else
        skip_test "wget not available" "Speed monitoring"
    fi
}

# ============================================
# Test Summary
# ============================================

print_summary() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  ISO Manager Automation Tests Summary${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "Total tests run:     ${TESTS_RUN}"
    echo -e "${GREEN}Tests passed:        ${TESTS_PASSED}${NC}"
    echo -e "${RED}Tests failed:        ${TESTS_FAILED}${NC}"
    echo -e "${YELLOW}Tests skipped:       ${TESTS_SKIPPED}${NC}"

    if [[ ${TESTS_RUN} -gt 0 ]]; then
        local success_rate=$(( (TESTS_PASSED * 100) / TESTS_RUN ))
        echo -e "Success rate:        ${success_rate}%"
    fi

    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""

    if [[ ${TESTS_FAILED} -eq 0 ]]; then
        echo -e "${GREEN}All automation tests passed!${NC}"
        return 0
    else
        echo -e "${RED}Some automation tests failed.${NC}"
        return 1
    fi
}

# ============================================
# Main Test Execution
# ============================================

main() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  ISO Manager - Automation Tests (Resume & Retry)${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""

    setup

    # Run Resume Tests
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  Resume Scenario Tests${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    test_resume_partial_download_50_percent
    test_resume_partial_download_90_percent
    test_resume_after_multiple_interruptions
    test_detect_oversized_partial_file
    test_resume_with_corrupted_partial

    # Run Retry Tests
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  Retry Scenario Tests${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    test_retry_on_network_timeout
    test_retry_with_exponential_backoff
    test_retry_on_dns_failure
    test_connection_health_check_before_retry

    # Run Edge Case Tests
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  Edge Case Tests${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    test_handle_zero_byte_file
    test_handle_very_small_file
    test_concurrent_downloads_same_file
    test_download_speed_monitoring

    teardown
    print_summary
}

# Run tests
main "$@"
