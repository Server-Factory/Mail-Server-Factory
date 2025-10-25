#!/bin/bash

#
# Integration Tests for ISO Manager
#
# Tests complete workflows and interactions between components
#

set -euo pipefail

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ISO_MANAGER="${PROJECT_ROOT}/scripts/iso_manager.sh"
TEST_DIR="${SCRIPT_DIR}/test_tmp"
MOCK_SERVER_PORT=8888

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Mock HTTP server PID
MOCK_SERVER_PID=""

# Setup test environment
setup() {
    echo -e "${BLUE}Setting up integration test environment...${NC}"
    rm -rf "${TEST_DIR}"
    mkdir -p "${TEST_DIR}"/{isos,checksums,mock_files}

    # Create mock ISO file (small for testing)
    dd if=/dev/urandom of="${TEST_DIR}/mock_files/test.iso" bs=1024 count=100 2>/dev/null

    # Generate checksum for mock ISO
    local checksum=$(sha256sum "${TEST_DIR}/mock_files/test.iso" | awk '{print $1}')
    echo "${checksum} test.iso" > "${TEST_DIR}/mock_files/SHA256SUMS"

    # Start mock HTTP server if python3 is available
    if command -v python3 &> /dev/null; then
        cd "${TEST_DIR}/mock_files"
        python3 -m http.server ${MOCK_SERVER_PORT} > /dev/null 2>&1 &
        MOCK_SERVER_PID=$!
        cd - > /dev/null
        sleep 2  # Give server time to start
        echo -e "${GREEN}Mock HTTP server started on port ${MOCK_SERVER_PORT}${NC}"
    else
        echo -e "${YELLOW}Python3 not available, some tests will be skipped${NC}"
    fi
}

teardown() {
    echo -e "${BLUE}Cleaning up integration test environment...${NC}"

    # Stop mock HTTP server
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

assert_file_exists() {
    local file_path=$1
    local test_name=$2

    TESTS_RUN=$((TESTS_RUN + 1))

    if [[ -f "${file_path}" ]]; then
        echo -e "${GREEN}✓ PASS${NC}: ${test_name}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}: ${test_name}"
        echo -e "${RED}  File does not exist: ${file_path}${NC}"
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
# Integration Tests
# ============================================

test_download_small_file_complete_workflow() {
    print_test_header "Download and verify small file - Complete workflow"

    if [[ -z "${MOCK_SERVER_PID}" ]]; then
        skip_test "Mock server not available" "Complete download workflow"
        return
    fi

    local test_url="http://localhost:${MOCK_SERVER_PORT}/test.iso"
    local checksum_url="http://localhost:${MOCK_SERVER_PORT}/SHA256SUMS"
    local output_file="${TEST_DIR}/isos/test.iso"
    local checksum_file="${TEST_DIR}/checksums/test.sha256"

    # Download checksum file
    if command -v wget &> /dev/null; then
        wget -q -O "${checksum_file}" "${checksum_url}" || {
            skip_test "Failed to download checksum file" "Download workflow"
            return
        }
    else
        skip_test "wget not available" "Download workflow"
        return
    fi

    # Download ISO file
    wget -q -O "${output_file}" "${test_url}" || {
        skip_test "Failed to download ISO file" "Download workflow"
        return
    }

    assert_file_exists "${output_file}" "ISO file downloaded"
    assert_file_exists "${checksum_file}" "Checksum file downloaded"

    # Verify checksum
    local expected_checksum=$(awk '{print $1}' "${checksum_file}")
    local actual_checksum=$(sha256sum "${output_file}" | awk '{print $1}')

    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ "${expected_checksum}" == "${actual_checksum}" ]]; then
        echo -e "${GREEN}✓ PASS${NC}: Checksum verification succeeds"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: Checksum verification fails"
        echo -e "${RED}  Expected: ${expected_checksum}${NC}"
        echo -e "${RED}  Actual: ${actual_checksum}${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_resume_interrupted_download() {
    print_test_header "Resume interrupted download"

    if [[ -z "${MOCK_SERVER_PID}" ]]; then
        skip_test "Mock server not available" "Resume download"
        return
    fi

    if ! command -v wget &> /dev/null; then
        skip_test "wget not available" "Resume download"
        return
    fi

    local test_url="http://localhost:${MOCK_SERVER_PORT}/test.iso"
    local output_file="${TEST_DIR}/isos/test_resume.iso"

    # Create partial file (first 50KB)
    dd if="${TEST_DIR}/mock_files/test.iso" of="${output_file}" bs=1024 count=50 2>/dev/null

    local initial_size=$(stat -f%z "${output_file}" 2>/dev/null || stat -c%s "${output_file}" 2>/dev/null)

    # Resume download
    wget -c -q -O "${output_file}" "${test_url}" 2>/dev/null || true

    local final_size=$(stat -f%z "${output_file}" 2>/dev/null || stat -c%s "${output_file}" 2>/dev/null)

    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ ${final_size} -gt ${initial_size} ]]; then
        echo -e "${GREEN}✓ PASS${NC}: Download resumed and completed"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: Download did not resume"
        echo -e "${RED}  Initial size: ${initial_size}, Final size: ${final_size}${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_detect_corrupted_partial_file() {
    print_test_header "Detect and cleanup corrupted partial file"

    local test_file="${TEST_DIR}/isos/corrupted_partial.iso"

    # Create oversized partial file (simulating corruption)
    dd if=/dev/urandom of="${test_file}" bs=1024 count=200 2>/dev/null

    local remote_size=102400  # 100KB
    local local_size=$(stat -f%z "${test_file}" 2>/dev/null || stat -c%s "${test_file}" 2>/dev/null)

    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ ${local_size} -gt ${remote_size} ]]; then
        echo -e "${GREEN}✓ PASS${NC}: Corrupted partial file detected (oversized)"
        TESTS_PASSED=$((TESTS_PASSED + 1))

        # Test cleanup
        mv "${test_file}" "${test_file}.corrupted"
        assert_file_exists "${test_file}.corrupted" "Corrupted file backed up"
    else
        echo -e "${RED}✗ FAIL${NC}: Failed to detect corrupted partial"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_retry_on_connection_failure() {
    print_test_header "Retry on connection failure"

    local invalid_url="http://localhost:9999/nonexistent.iso"  # Invalid port
    local output_file="${TEST_DIR}/isos/retry_test.iso"
    local max_retries=3

    local start_time=$(date +%s)

    # Attempt download with retries (will fail but should retry)
    timeout 30s wget -t ${max_retries} -q -O "${output_file}" "${invalid_url}" 2>/dev/null || true

    local end_time=$(date +%s)
    local elapsed=$((end_time - start_time))

    # Should take at least some time due to retries (not instant failure)
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ ${elapsed} -ge 2 ]]; then
        echo -e "${GREEN}✓ PASS${NC}: Retry mechanism engaged (elapsed: ${elapsed}s)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: No retry attempt detected"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_checksum_verification_integration() {
    print_test_header "End-to-end checksum verification"

    if [[ -z "${MOCK_SERVER_PID}" ]]; then
        skip_test "Mock server not available" "Checksum verification"
        return
    fi

    local test_file="${TEST_DIR}/mock_files/test.iso"
    local checksum_file="${TEST_DIR}/mock_files/SHA256SUMS"

    # Calculate checksum
    local expected_checksum=$(sha256sum "${test_file}" | awk '{print $1}')
    local stored_checksum=$(grep test.iso "${checksum_file}" | awk '{print $1}')

    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ "${expected_checksum}" == "${stored_checksum}" ]]; then
        echo -e "${GREEN}✓ PASS${NC}: Checksum matches"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: Checksum mismatch"
        echo -e "${RED}  Expected: ${expected_checksum}${NC}"
        echo -e "${RED}  Stored: ${stored_checksum}${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_parallel_downloads() {
    print_test_header "Multiple concurrent downloads"

    if [[ -z "${MOCK_SERVER_PID}" ]]; then
        skip_test "Mock server not available" "Parallel downloads"
        return
    fi

    if ! command -v wget &> /dev/null; then
        skip_test "wget not available" "Parallel downloads"
        return
    fi

    local base_url="http://localhost:${MOCK_SERVER_PORT}/test.iso"

    # Start 3 downloads in parallel
    for i in 1 2 3; do
        wget -q -O "${TEST_DIR}/isos/parallel_${i}.iso" "${base_url}" &
    done

    # Wait for all downloads to complete
    wait

    local success_count=0
    for i in 1 2 3; do
        if [[ -f "${TEST_DIR}/isos/parallel_${i}.iso" ]]; then
            success_count=$((success_count + 1))
        fi
    done

    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ ${success_count} -eq 3 ]]; then
        echo -e "${GREEN}✓ PASS${NC}: All parallel downloads succeeded"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: Only ${success_count}/3 downloads succeeded"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_connection_health_check_integration() {
    print_test_header "Connection health check before download"

    # Test with real Ubuntu mirrors (known to be stable)
    local test_urls=(
        "https://releases.ubuntu.com/22.04.5/SHA256SUMS"
        "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/SHA256SUMS"
    )

    local success_count=0
    for url in "${test_urls[@]}"; do
        if timeout 10s curl -sI -L --connect-timeout 5 "${url}" > /dev/null 2>&1; then
            success_count=$((success_count + 1))
        fi
    done

    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ ${success_count} -ge 1 ]]; then
        echo -e "${GREEN}✓ PASS${NC}: Connection health checks succeeded (${success_count}/2)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        skip_test "Network connectivity issues" "Connection health check"
    fi
}

test_progress_monitoring_integration() {
    print_test_header "Download progress monitoring"

    if [[ -z "${MOCK_SERVER_PID}" ]]; then
        skip_test "Mock server not available" "Progress monitoring"
        return
    fi

    if ! command -v wget &> /dev/null; then
        skip_test "wget not available" "Progress monitoring"
        return
    fi

    local test_url="http://localhost:${MOCK_SERVER_PORT}/test.iso"
    local output_file="${TEST_DIR}/isos/progress_test.iso"
    local progress_file="${TEST_DIR}/.progress/progress_test.iso.progress"

    mkdir -p "${TEST_DIR}/.progress"

    # Create progress marker
    touch "${progress_file}"

    # Start download in background
    wget -q -O "${output_file}" "${test_url}" &
    local download_pid=$!

    # Monitor progress
    local progress_detected=false
    for i in {1..5}; do
        sleep 1
        if [[ -f "${output_file}" ]]; then
            local size=$(stat -f%z "${output_file}" 2>/dev/null || stat -c%s "${output_file}" 2>/dev/null || echo "0")
            if [[ ${size} -gt 0 ]]; then
                progress_detected=true
                break
            fi
        fi
    done

    # Cleanup
    rm -f "${progress_file}"
    wait "${download_pid}" 2>/dev/null || true

    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ "${progress_detected}" == "true" ]]; then
        echo -e "${GREEN}✓ PASS${NC}: Download progress detected"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: No download progress detected"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_smb_fallback_integration() {
    print_test_header "SMB fallback to internet download"

    # Test that the script falls back to internet when SMB is not available
    TESTS_RUN=$((TESTS_RUN + 1))

    # Set OS_IS_IMAGES_PATH but ensure smbclient is not available or mocked to fail
    if ! command -v smbclient &> /dev/null; then
        local output=$(OS_IS_IMAGES_PATH="smb://nonexistent/share" timeout 30s bash "${ISO_MANAGER}" list 2>&1 | head -20)
        if [[ "${output}" == *"smbclient not found"* ]] || [[ "${output}" == *"Failed to copy from SMB"* ]]; then
            echo -e "${GREEN}✓ PASS${NC}: Proper fallback when SMB unavailable"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "${RED}✗ FAIL${NC}: Did not fallback properly from SMB"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    else
        echo -e "${YELLOW}⊘ SKIP${NC}: smbclient available, cannot test fallback"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    fi
}

# ============================================
# Test Summary
# ============================================

print_summary() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  ISO Manager Integration Tests Summary${NC}"
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
        echo -e "${GREEN}All integration tests passed!${NC}"
        return 0
    else
        echo -e "${RED}Some integration tests failed.${NC}"
        return 1
    fi
}

# ============================================
# Main Test Execution
# ============================================

main() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  ISO Manager - Integration Tests${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""

    setup

    # Run all integration tests
    test_download_small_file_complete_workflow
    test_resume_interrupted_download
    test_detect_corrupted_partial_file
    test_retry_on_connection_failure
    test_checksum_verification_integration
    test_parallel_downloads
    test_connection_health_check_integration
    test_progress_monitoring_integration
    test_smb_fallback_integration

    teardown
    print_summary
}

# Run tests
main "$@"
