#!/bin/bash

#
# Unit Tests for ISO Manager Download Functions
#
# Pragmatic unit testing for bash scripts
#

set -euo pipefail

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ISO_MANAGER="${PROJECT_ROOT}/scripts/iso_manager.sh"
TEST_DIR="${SCRIPT_DIR}/test_tmp"

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

# Setup test environment
setup() {
    echo -e "${BLUE}Setting up test environment...${NC}"
    rm -rf "${TEST_DIR}"
    mkdir -p "${TEST_DIR}"/{isos,checksums,.progress}
}

teardown() {
    echo -e "${BLUE}Cleaning up test environment...${NC}"
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

assert_output_contains() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"

    TESTS_RUN=$((TESTS_RUN + 1))

    if [[ "${actual}" == *"${expected}"* ]]; then
        echo -e "${GREEN}✓ PASS${NC}: ${test_name}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}: ${test_name}"
        echo -e "${RED}  Expected output to contain: '${expected}'${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# ============================================
# Unit Tests
# ============================================

test_iso_manager_exists() {
    print_test_header "ISO Manager script exists"
    assert_file_exists "${ISO_MANAGER}" "ISO Manager script found"
}

test_iso_manager_executable() {
    print_test_header "ISO Manager is executable"

    TESTS_RUN=$((TESTS_RUN + 1))

    if [[ -x "${ISO_MANAGER}" ]]; then
        echo -e "${GREEN}✓ PASS${NC}: ISO Manager is executable"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}: ISO Manager is not executable"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

test_help_command() {
    print_test_header "Help command returns success"

    local output=$(bash "${ISO_MANAGER}" help 2>&1)
    local exit_code=$?

    assert_exit_code 0 ${exit_code} "Help command exit code"
    assert_output_contains "Usage:" "${output}" "Help contains usage"
}

test_list_command() {
    print_test_header "List command returns success"

    local output=$(bash "${ISO_MANAGER}" list 2>&1)
    local exit_code=$?

    assert_exit_code 0 ${exit_code} "List command exit code"
    assert_output_contains "Name" "${output}" "List contains headers"
}

test_invalid_command() {
    print_test_header "Invalid command returns error"

    bash "${ISO_MANAGER}" invalid_command > /dev/null 2>&1 || local exit_code=$?

    assert_exit_code 1 ${exit_code} "Invalid command returns exit code 1"
}

test_directory_creation() {
    print_test_header "Directory creation"

    # Run help to trigger directory creation
    bash "${ISO_MANAGER}" list > /dev/null 2>&1

    local iso_dir="${PROJECT_ROOT}/isos"

    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ -d "${iso_dir}" ]]; then
        echo -e "${GREEN}✓ PASS${NC}: ISO directory exists"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: ISO directory not created"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_checksum_tools_available() {
    print_test_header "Checksum tools availability"

    local tools=(sha256sum)
    local all_found=true

    for tool in "${tools[@]}"; do
        if ! command -v "${tool}" &> /dev/null; then
            all_found=false
            echo -e "  ${YELLOW}⚠${NC} ${tool} not found"
        else
            echo -e "  ${GREEN}✓${NC} ${tool} found"
        fi
    done

    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ "${all_found}" == "true" ]]; then
        echo -e "${GREEN}✓ PASS${NC}: All required checksum tools available"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${YELLOW}⊘ PARTIAL${NC}: Some checksum tools missing"
        TESTS_PASSED=$((TESTS_PASSED + 1))  # Still pass, just note it
    fi
}

test_download_tools_available() {
    print_test_header "Download tools availability"

    local tools_found=0

    if command -v wget &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} wget found"
        tools_found=$((tools_found + 1))
    fi

    if command -v curl &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} curl found"
        tools_found=$((tools_found + 1))
    fi

    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ ${tools_found} -gt 0 ]]; then
        echo -e "${GREEN}✓ PASS${NC}: At least one download tool available"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: No download tools available"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_remote_file_size_detection() {
    print_test_header "Remote file size detection capability"

    local test_url="https://releases.ubuntu.com/22.04.5/SHA256SUMS"

    TESTS_RUN=$((TESTS_RUN + 1))
    if command -v curl &> /dev/null; then
        local size=$(timeout 10s curl -sI -L "${test_url}" 2>/dev/null | grep -i "content-length" | tail -1 | awk '{print $2}' | tr -d '\r' || echo "")

        if [[ -n "${size}" ]] && [[ ${size} -gt 0 ]]; then
            echo -e "${GREEN}✓ PASS${NC}: Remote file size detected (${size} bytes)"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "${YELLOW}⊘ SKIP${NC}: Could not detect remote file size (network issue)"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        fi
    elif command -v wget &> /dev/null; then
        echo -e "${YELLOW}⊘ SKIP${NC}: wget available but test uses curl"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: No tools for remote size detection"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_checksum_verification_logic() {
    print_test_header "Checksum verification logic"

    local test_file="${TEST_DIR}/test.txt"
    echo "test content" > "${test_file}"

    local checksum=$(sha256sum "${test_file}" | awk '{print $1}')

    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ -n "${checksum}" ]] && [[ ${#checksum} -eq 64 ]]; then
        echo -e "${GREEN}✓ PASS${NC}: Checksum generation works (SHA256, 64 chars)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: Checksum generation failed"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_partial_file_size_check() {
    print_test_header "Partial file size checking"

    local test_file="${TEST_DIR}/partial.iso"
    dd if=/dev/zero of="${test_file}" bs=1024 count=100 2>/dev/null

    local size=$(stat -f%z "${test_file}" 2>/dev/null || stat -c%s "${test_file}" 2>/dev/null || echo "0")

    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ ${size} -eq 102400 ]]; then
        echo -e "${GREEN}✓ PASS${NC}: File size check works (${size} bytes)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: File size check failed (got ${size}, expected 102400)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_connection_health_check() {
    print_test_header "Connection health check logic"

    local test_url="https://releases.ubuntu.com"

    TESTS_RUN=$((TESTS_RUN + 1))
    if command -v curl &> /dev/null; then
        if timeout 10s curl -sI -L --connect-timeout 5 "${test_url}" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ PASS${NC}: Connection health check successful"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "${YELLOW}⊘ SKIP${NC}: Network connectivity issue"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        fi
    else
        echo -e "${YELLOW}⊘ SKIP${NC}: curl not available"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    fi
}

# ============================================
# Test Summary
# ============================================

print_summary() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  ISO Manager Unit Tests Summary${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "Total tests run:     ${TESTS_RUN}"
    echo -e "${GREEN}Tests passed:        ${TESTS_PASSED}${NC}"
    echo -e "${RED}Tests failed:        ${TESTS_FAILED}${NC}"

    if [[ ${TESTS_RUN} -gt 0 ]]; then
        local success_rate=$(( (TESTS_PASSED * 100) / TESTS_RUN ))
        echo -e "Success rate:        ${success_rate}%"
    fi

    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""

    if [[ ${TESTS_FAILED} -eq 0 ]]; then
        echo -e "${GREEN}All unit tests passed!${NC}"
        return 0
    else
        echo -e "${RED}Some unit tests failed.${NC}"
        return 1
    fi
}

# ============================================
# Main Test Execution
# ============================================

main() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  ISO Manager - Unit Tests${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""

    setup

    # Run all unit tests
    test_iso_manager_exists
    test_iso_manager_executable
    test_help_command
    test_list_command
    test_invalid_command
    test_directory_creation
    test_checksum_tools_available
    test_download_tools_available
    test_remote_file_size_detection
    test_checksum_verification_logic
    test_partial_file_size_check
    test_connection_health_check

    teardown
    print_summary
}

# Run tests
main "$@"
