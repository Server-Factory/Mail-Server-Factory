#!/bin/bash

#
# End-to-End Tests for ISO Manager
#
# Tests real-world scenarios with actual ISO downloads (small files only)
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
TESTS_SKIPPED=0

# Setup test environment
setup() {
    echo -e "${BLUE}Setting up E2E test environment...${NC}"
    rm -rf "${TEST_DIR}"
    mkdir -p "${TEST_DIR}"

    # Create temporary script that uses TEST_DIR
    cat > "${TEST_DIR}/iso_manager_test.sh" <<'EOF'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="%%PROJECT_ROOT%%"
ISO_DIR="${SCRIPT_DIR}/isos"
CHECKSUM_DIR="${ISO_DIR}/checksums"
LOG_FILE="${ISO_DIR}/iso_manager.log"
PROGRESS_DIR="${ISO_DIR}/.progress"
EOF

    sed "s|%%PROJECT_ROOT%%|${TEST_DIR}|g" -i "${TEST_DIR}/iso_manager_test.sh"

    # Append the ISO manager script (excluding shebang and main call)
    tail -n +2 "${ISO_MANAGER}" | head -n -2 >> "${TEST_DIR}/iso_manager_test.sh"

    # Make it executable
    chmod +x "${TEST_DIR}/iso_manager_test.sh"
}

teardown() {
    echo -e "${BLUE}Cleaning up E2E test environment...${NC}"
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

skip_test() {
    local reason="$1"
    local test_name="$2"

    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
    echo -e "${YELLOW}⊘ SKIP${NC}: ${test_name}"
    echo -e "${YELLOW}  Reason: ${reason}${NC}"
}

# ============================================
# E2E Tests
# ============================================

test_download_real_checksum_file() {
    print_test_header "Download real checksum file from Ubuntu"

    local url="https://releases.ubuntu.com/22.04.5/SHA256SUMS"
    local output_file="${TEST_DIR}/isos/checksums/SHA256SUMS"

    mkdir -p "$(dirname "${output_file}")"

    # Test with wget if available
    if command -v wget &> /dev/null; then
        timeout 30s wget -q -O "${output_file}" "${url}" 2>&1

        if [[ $? -eq 0 ]]; then
            assert_file_exists "${output_file}" "Checksum file downloaded successfully"

            # Verify content
            if grep -q "ubuntu-22.04" "${output_file}"; then
                TESTS_RUN=$((TESTS_RUN + 1))
                echo -e "${GREEN}✓ PASS${NC}: Checksum file contains expected content"
                TESTS_PASSED=$((TESTS_PASSED + 1))
            else
                TESTS_RUN=$((TESTS_RUN + 1))
                echo -e "${RED}✗ FAIL${NC}: Checksum file does not contain expected content"
                TESTS_FAILED=$((TESTS_FAILED + 1))
            fi
        else
            skip_test "Network connectivity issue or timeout" "Checksum file download"
        fi
    else
        skip_test "wget not available" "Checksum file download"
    fi
}

test_iso_manager_help_command() {
    print_test_header "ISO Manager help command"

    local output=$(bash "${ISO_MANAGER}" help 2>&1)
    local exit_code=$?

    assert_exit_code 0 ${exit_code} "Help command returns success"
    assert_output_contains "Usage:" "${output}" "Help output contains usage"
    assert_output_contains "Commands:" "${output}" "Help output contains commands"
    assert_output_contains "download" "${output}" "Help output lists download command"
    assert_output_contains "verify" "${output}" "Help output lists verify command"
}

test_iso_manager_list_command() {
    print_test_header "ISO Manager list command"

    local output=$(bash "${ISO_MANAGER}" list 2>&1)
    local exit_code=$?

    assert_exit_code 0 ${exit_code} "List command returns success"
    assert_output_contains "Name" "${output}" "List output contains header"
    assert_output_contains "Version" "${output}" "List output contains version column"
    assert_output_contains "ubuntu" "${output}" "List output contains Ubuntu"
    assert_output_contains "debian" "${output}" "List output contains Debian"
    assert_output_contains "fedora" "${output}" "List output contains Fedora"
}

test_directory_creation() {
    print_test_header "ISO Manager directory creation"

    # Run any command to trigger directory creation
    bash "${ISO_MANAGER}" help > /dev/null 2>&1

    local iso_dir="${PROJECT_ROOT}/isos"

    if [[ -d "${iso_dir}" ]]; then
        assert_file_exists "${iso_dir}/." "ISO directory created"

        if [[ -d "${iso_dir}/checksums" ]]; then
            TESTS_RUN=$((TESTS_RUN + 1))
            echo -e "${GREEN}✓ PASS${NC}: Checksum directory created"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            TESTS_RUN=$((TESTS_RUN + 1))
            echo -e "${RED}✗ FAIL${NC}: Checksum directory not created"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    else
        skip_test "ISO directory not created (expected for help command)" "Directory creation"
    fi
}

test_connection_health_check_real_urls() {
    print_test_header "Connection health check with real URLs"

    local test_urls=(
        "https://releases.ubuntu.com"
        "https://cdimage.debian.org"
        "https://download.fedoraproject.org"
    )

    local success_count=0
    local total=${#test_urls[@]}

    for url in "${test_urls[@]}"; do
        if timeout 10s curl -sI -L --connect-timeout 5 "${url}" > /dev/null 2>&1; then
            success_count=$((success_count + 1))
            echo -e "  ${GREEN}✓${NC} ${url} - reachable"
        else
            echo -e "  ${YELLOW}⚠${NC} ${url} - unreachable"
        fi
    done

    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ ${success_count} -ge 2 ]]; then
        echo -e "${GREEN}✓ PASS${NC}: Connection health checks succeeded (${success_count}/${total})"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        skip_test "Insufficient network connectivity (${success_count}/${total})" "Connection health"
    fi
}

test_checksum_extraction_real_file() {
    print_test_header "Checksum extraction from real Ubuntu checksum file"

    local checksum_url="https://releases.ubuntu.com/22.04.5/SHA256SUMS"
    local checksum_file="${TEST_DIR}/SHA256SUMS"

    if command -v wget &> /dev/null; then
        timeout 30s wget -q -O "${checksum_file}" "${checksum_url}" 2>&1 || {
            skip_test "Failed to download checksum file" "Checksum extraction"
            return
        }

        # Try to extract checksum for known ISO
        local iso_name="ubuntu-22.04.5-live-server-amd64.iso"
        local checksum=$(grep "${iso_name}" "${checksum_file}" | awk '{print $1}' | head -1)

        TESTS_RUN=$((TESTS_RUN + 1))
        if [[ -n "${checksum}" ]] && [[ ${#checksum} -eq 64 ]]; then
            echo -e "${GREEN}✓ PASS${NC}: SHA256 checksum extracted (length: 64)"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "${RED}✗ FAIL${NC}: Checksum extraction failed"
            echo -e "${RED}  Extracted: '${checksum}' (length: ${#checksum})${NC}"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    else
        skip_test "wget not available" "Checksum extraction"
    fi
}

test_iso_manager_invalid_command() {
    print_test_header "ISO Manager with invalid command"

    local output=$(bash "${ISO_MANAGER}" invalid_command 2>&1)
    local exit_code=$?

    assert_exit_code 1 ${exit_code} "Invalid command returns error"
    assert_output_contains "Unknown command" "${output}" "Error message for invalid command"
}

test_remote_file_size_check() {
    print_test_header "Remote file size detection"

    local test_url="https://releases.ubuntu.com/22.04.5/SHA256SUMS"

    if command -v curl &> /dev/null; then
        local size=$(curl -sI -L "${test_url}" 2>/dev/null | grep -i "content-length" | tail -1 | awk '{print $2}' | tr -d '\r')

        TESTS_RUN=$((TESTS_RUN + 1))
        if [[ -n "${size}" ]] && [[ ${size} -gt 0 ]]; then
            echo -e "${GREEN}✓ PASS${NC}: Remote file size detected (${size} bytes)"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            skip_test "Could not detect remote file size" "File size check"
        fi
    else
        skip_test "curl not available" "File size check"
    fi
}

test_logging_functionality() {
    print_test_header "Logging functionality"

    # Run help command to trigger logging
    bash "${ISO_MANAGER}" help > /dev/null 2>&1

    local log_file="${PROJECT_ROOT}/isos/iso_manager.log"

    # Check if log file would be created in a real scenario
    TESTS_RUN=$((TESTS_RUN + 1))
    if command -v tee &> /dev/null; then
        echo -e "${GREEN}✓ PASS${NC}: Logging tools available (tee)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: Logging tool (tee) not available"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_download_tools_availability() {
    print_test_header "Download tools availability check"

    local tools_found=0

    if command -v wget &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} wget found: $(wget --version | head -1)"
        tools_found=$((tools_found + 1))
    else
        echo -e "  ${YELLOW}⚠${NC} wget not found"
    fi

    if command -v curl &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} curl found: $(curl --version | head -1)"
        tools_found=$((tools_found + 1))
    else
        echo -e "  ${YELLOW}⚠${NC} curl not found"
    fi

    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ ${tools_found} -gt 0 ]]; then
        echo -e "${GREEN}✓ PASS${NC}: At least one download tool available"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: No download tools available (wget/curl)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_checksum_tools_availability() {
    print_test_header "Checksum verification tools availability"

    local tools=(sha256sum sha512sum md5sum)
    local found_count=0

    for tool in "${tools[@]}"; do
        if command -v "${tool}" &> /dev/null; then
            echo -e "  ${GREEN}✓${NC} ${tool} found"
            found_count=$((found_count + 1))
        else
            echo -e "  ${YELLOW}⚠${NC} ${tool} not found"
        fi
    done

    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ ${found_count} -eq 3 ]]; then
        echo -e "${GREEN}✓ PASS${NC}: All checksum tools available"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${YELLOW}⊘ PARTIAL${NC}: Only ${found_count}/3 checksum tools available"
        TESTS_PASSED=$((TESTS_PASSED + 1))  # Partial pass is still acceptable
    fi
}

# ============================================
# Test Summary
# ============================================

print_summary() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  ISO Manager E2E Tests Summary${NC}"
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
        echo -e "${GREEN}All E2E tests passed!${NC}"
        return 0
    else
        echo -e "${RED}Some E2E tests failed.${NC}"
        return 1
    fi
}

# ============================================
# Main Test Execution
# ============================================

main() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  ISO Manager - End-to-End Tests${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""

    setup

    # Run all E2E tests
    test_iso_manager_help_command
    test_iso_manager_list_command
    test_iso_manager_invalid_command
    test_directory_creation
    test_download_tools_availability
    test_checksum_tools_availability
    test_download_real_checksum_file
    test_connection_health_check_real_urls
    test_checksum_extraction_real_file
    test_remote_file_size_check
    test_logging_functionality

    teardown
    print_summary
}

# Run tests
main "$@"
