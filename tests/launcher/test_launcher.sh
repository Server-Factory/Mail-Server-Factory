#!/bin/bash

#
# Test Suite for Mail Server Factory Launcher
#
# This script tests all scenarios and edge cases for the mail_factory launcher
#

set -e

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LAUNCHER="${PROJECT_ROOT}/mail_factory"
TEST_DIR="${SCRIPT_DIR}/test_tmp"
MOCK_DIR="${SCRIPT_DIR}/mocks"

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

# Functions
setup() {
    echo -e "${BLUE}Setting up test environment...${NC}"
    rm -rf "${TEST_DIR}"
    mkdir -p "${TEST_DIR}/config"
    mkdir -p "${TEST_DIR}/jars"

    # Create mock configuration file
    cat > "${TEST_DIR}/config/test.json" <<EOF
{
    "test": "configuration"
}
EOF

    # Create mock JAR if it doesn't exist
    if [[ ! -f "${PROJECT_ROOT}/Application/build/libs/Application.jar" ]]; then
        echo -e "${YELLOW}Warning: Application JAR not found. Creating mock JAR for testing.${NC}"
        mkdir -p "${PROJECT_ROOT}/Application/build/libs"
        cp "${MOCK_DIR}/mock-application.jar" "${PROJECT_ROOT}/Application/build/libs/Application.jar" 2>/dev/null || \
            echo "Mock JAR" > "${PROJECT_ROOT}/Application/build/libs/Application.jar"
    fi
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
        echo -e "${RED}  Actual output: '${actual}'${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test cases

test_help_flag() {
    print_test_header "Help flag test"

    local output
    output=$("${LAUNCHER}" --help 2>&1)
    local exit_code=$?

    assert_exit_code 0 ${exit_code} "Help flag returns exit code 0"
    assert_output_contains "USAGE:" "${output}" "Help output contains USAGE"
    assert_output_contains "OPTIONS:" "${output}" "Help output contains OPTIONS"
    assert_output_contains "EXAMPLES:" "${output}" "Help output contains EXAMPLES"
}

test_version_flag() {
    print_test_header "Version flag test"

    local output
    output=$("${LAUNCHER}" --version 2>&1)
    local exit_code=$?

    assert_exit_code 0 ${exit_code} "Version flag returns exit code 0"
    assert_output_contains "Mail Server Factory Launcher" "${output}" "Version output contains launcher name"
    assert_output_contains "v" "${output}" "Version output contains version number"
}

test_no_arguments() {
    print_test_header "No arguments test"

    local output
    local exit_code
    output=$("${LAUNCHER}" 2>&1) || exit_code=$?
    exit_code=${exit_code:-0}

    assert_exit_code 4 ${exit_code} "No arguments returns exit code 4"
    assert_output_contains "No arguments provided" "${output}" "Error message for no arguments"
}

test_missing_config_file() {
    print_test_header "Missing configuration file test"

    local output
    local exit_code
    output=$("${LAUNCHER}" "${TEST_DIR}/nonexistent.json" 2>&1) || exit_code=$?
    exit_code=${exit_code:-0}

    assert_exit_code 5 ${exit_code} "Missing config file returns exit code 5"
    assert_output_contains "Configuration file not found" "${output}" "Error message for missing file"
}

test_dry_run() {
    print_test_header "Dry run test"

    local output
    output=$("${LAUNCHER}" --dry-run "${TEST_DIR}/config/test.json" 2>&1)
    local exit_code=$?

    assert_exit_code 0 ${exit_code} "Dry run returns exit code 0"
    assert_output_contains "Dry run mode" "${output}" "Dry run shows command"
    assert_output_contains "java" "${output}" "Command contains java"
    assert_output_contains ".jar" "${output}" "Command contains JAR"
    assert_output_contains "test.json" "${output}" "Command contains config file"
}

test_debug_flag() {
    print_test_header "Debug flag test"

    local output
    output=$("${LAUNCHER}" --debug --dry-run "${TEST_DIR}/config/test.json" 2>&1)
    local exit_code=$?

    assert_exit_code 0 ${exit_code} "Debug flag returns exit code 0"
    assert_output_contains "Debug mode enabled" "${output}" "Debug mode message"
    assert_output_contains "Java command:" "${output}" "Java command displayed"
    assert_output_contains "JAR path:" "${output}" "JAR path displayed"
}

test_explicit_jar() {
    print_test_header "Explicit JAR path test"

    # Create a mock JAR in test directory
    echo "mock jar" > "${TEST_DIR}/jars/custom.jar"

    local output
    output=$("${LAUNCHER}" --jar "${TEST_DIR}/jars/custom.jar" --dry-run "${TEST_DIR}/config/test.json" 2>&1)
    local exit_code=$?

    assert_exit_code 0 ${exit_code} "Explicit JAR path returns exit code 0"
    assert_output_contains "custom.jar" "${output}" "Command uses specified JAR"
}

test_invalid_jar() {
    print_test_header "Invalid JAR path test"

    local output
    local exit_code
    output=$("${LAUNCHER}" --jar "${TEST_DIR}/nonexistent.jar" "${TEST_DIR}/config/test.json" 2>&1) || exit_code=$?
    exit_code=${exit_code:-0}

    assert_exit_code 3 ${exit_code} "Invalid JAR returns exit code 3"
    assert_output_contains "JAR file not found" "${output}" "Error message for invalid JAR"
}

test_installation_home_arg() {
    print_test_header "Installation home argument test"

    local output
    output=$("${LAUNCHER}" --installation-home=/custom/path --dry-run "${TEST_DIR}/config/test.json" 2>&1)
    local exit_code=$?

    assert_exit_code 0 ${exit_code} "Installation home arg returns exit code 0"
    assert_output_contains "--installation-home=/custom/path" "${output}" "Command contains installation home"
}

test_java_opts_env() {
    print_test_header "JAVA_OPTS environment variable test"

    local output
    output=$(JAVA_OPTS="-Xmx2g -Xms512m" "${LAUNCHER}" --dry-run "${TEST_DIR}/config/test.json" 2>&1)
    local exit_code=$?

    assert_exit_code 0 ${exit_code} "JAVA_OPTS returns exit code 0"
    assert_output_contains "-Xmx2g" "${output}" "Command contains Xmx option"
    assert_output_contains "-Xms512m" "${output}" "Command contains Xms option"
}

test_multiple_args() {
    print_test_header "Multiple arguments test"

    local output
    output=$("${LAUNCHER}" --installation-home=/test --dry-run "${TEST_DIR}/config/test.json" 2>&1)
    local exit_code=$?

    assert_exit_code 0 ${exit_code} "Multiple args return exit code 0"
    assert_output_contains "--installation-home=/test" "${output}" "Command contains first arg"
    assert_output_contains "test.json" "${output}" "Command contains config file"
}

test_config_file_validation() {
    print_test_header "Configuration file validation test"

    # Create non-JSON file
    echo "not json" > "${TEST_DIR}/config/test.txt"

    local output
    output=$("${LAUNCHER}" --dry-run "${TEST_DIR}/config/test.txt" 2>&1)
    local exit_code=$?

    assert_exit_code 0 ${exit_code} "Non-JSON file accepted with warning"
    assert_output_contains "doesn't have .json extension" "${output}" "Warning for non-JSON file"
}

test_jar_search_locations() {
    print_test_header "JAR search locations test"

    # Temporarily move JAR to test search
    local jar_location="${PROJECT_ROOT}/Application/build/libs/Application.jar"
    local backup_location="${PROJECT_ROOT}/Application/build/libs/Application.jar.backup"

    if [[ -f "${jar_location}" ]]; then
        mv "${jar_location}" "${backup_location}"
    fi

    # Test with missing JAR
    local output
    local exit_code
    output=$("${LAUNCHER}" "${TEST_DIR}/config/test.json" 2>&1) || exit_code=$?
    exit_code=${exit_code:-0}

    # Restore JAR
    if [[ -f "${backup_location}" ]]; then
        mv "${backup_location}" "${jar_location}"
    fi

    assert_exit_code 3 ${exit_code} "Missing JAR returns exit code 3"
    assert_output_contains "JAR file not found" "${output}" "Error message for missing JAR"
    assert_output_contains "Searched locations:" "${output}" "Shows searched locations"
}

test_relative_config_path() {
    print_test_header "Relative configuration path test"

    cd "${TEST_DIR}/config"
    local output
    output=$("${LAUNCHER}" --dry-run test.json 2>&1)
    local exit_code=$?
    cd - > /dev/null

    assert_exit_code 0 ${exit_code} "Relative path returns exit code 0"
    assert_output_contains "test.json" "${output}" "Command contains config file"
}

test_absolute_config_path() {
    print_test_header "Absolute configuration path test"

    local output
    output=$("${LAUNCHER}" --dry-run "${TEST_DIR}/config/test.json" 2>&1)
    local exit_code=$?

    assert_exit_code 0 ${exit_code} "Absolute path returns exit code 0"
    assert_output_contains "test.json" "${output}" "Command contains config file"
}

# Main test execution
main() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Mail Server Factory Launcher Test Suite          ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "Launcher: ${LAUNCHER}"
    echo -e "Test Directory: ${TEST_DIR}"
    echo ""

    # Setup
    setup

    # Run all tests
    test_help_flag
    test_version_flag
    test_no_arguments
    test_missing_config_file
    test_dry_run
    test_debug_flag
    test_explicit_jar
    test_invalid_jar
    test_installation_home_arg
    test_java_opts_env
    test_multiple_args
    test_config_file_validation
    test_jar_search_locations
    test_relative_config_path
    test_absolute_config_path

    # Teardown
    teardown

    # Print summary
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Test Summary                                       ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
    echo -e "Total tests run:     ${TESTS_RUN}"
    echo -e "${GREEN}Tests passed:        ${TESTS_PASSED}${NC}"

    if [[ ${TESTS_FAILED} -gt 0 ]]; then
        echo -e "${RED}Tests failed:        ${TESTS_FAILED}${NC}"
        echo ""
        echo -e "${RED}❌ Some tests failed!${NC}"
        exit 1
    else
        echo -e "${RED}Tests failed:        ${TESTS_FAILED}${NC}"
        echo ""
        echo -e "${GREEN}✅ All tests passed!${NC}"
        exit 0
    fi
}

# Run main
main "$@"
