#!/bin/bash

# Mail Server Factory - Mail Server Testing Framework
# Comprehensive automated tests for mail server functionality
#
# Usage: ./test_framework.sh [OPTIONS] [TEST_TYPE]
#
# Options:
#   --all           Run all test suites
#   --smtp          Run SMTP tests only
#   --imap          Run IMAP tests only
#   --pop3          Run POP3 tests only
#   --operations    Run mail operations tests
#   --performance   Run performance tests
#   --distro DISTRO Test specific distribution
#   --verbose       Show detailed test output
#   --debug         Enable debug mode
#   --stop-on-error Stop on first test failure
#   --report        Generate HTML report
#   --help          Show this help message

set -u

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/test_config.sh"
RESULTS_DIR="${SCRIPT_DIR}/results"
TEST_DATA_DIR="${SCRIPT_DIR}/test_data"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Configuration variables (loaded from test_config.sh)
MAIL_SERVER=""
MAIL_DOMAIN=""
TEST_USER=""
TEST_PASSWORD=""
SMTP_TIMEOUT=30
IMAP_TIMEOUT=30
POP3_TIMEOUT=30
USE_SSL=false
SSL_CERT_PATH=""

# Options
VERBOSE=0
DEBUG=0
STOP_ON_ERROR=0
GENERATE_REPORT=0
TARGET_DISTRO=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}✓${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1" >&2
}

log_error() {
    echo -e "${RED}✗${NC} $1" >&2
}

log_debug() {
    if [ $DEBUG -eq 1 ]; then
        echo -e "${PURPLE}🐛${NC} $1" >&2
    fi
}

# Test assertion functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"

    TESTS_RUN=$((TESTS_RUN + 1))

    if [ "$expected" = "$actual" ]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓ PASS${NC}: $test_name"
        [ $VERBOSE -eq 1 ] && echo "  Expected: '$expected', Got: '$actual'"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗ FAIL${NC}: $test_name"
        echo "  Expected: '$expected'"
        echo "  Got: '$actual'"
        [ $STOP_ON_ERROR -eq 1 ] && exit 1
        return 1
    fi
}

assert_exit_code() {
    local expected=$1
    local actual=$2
    local test_name="$3"

    TESTS_RUN=$((TESTS_RUN + 1))

    if [ "$expected" -eq "$actual" ]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓ PASS${NC}: $test_name"
        [ $VERBOSE -eq 1 ] && echo "  Exit code: $actual"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗ FAIL${NC}: $test_name"
        echo "  Expected exit code: $expected"
        echo "  Got exit code: $actual"
        [ $STOP_ON_ERROR -eq 1 ] && exit 1
        return 1
    fi
}

assert_not_empty() {
    local value="$1"
    local test_name="$2"

    TESTS_RUN=$((TESTS_RUN + 1))

    if [ -n "$value" ]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓ PASS${NC}: $test_name"
        [ $VERBOSE -eq 1 ] && echo "  Value: '$value'"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗ FAIL${NC}: $test_name"
        echo "  Value is empty"
        [ $STOP_ON_ERROR -eq 1 ] && exit 1
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local test_name="$3"

    TESTS_RUN=$((TESTS_RUN + 1))

    if [[ "$haystack" == *"$needle"* ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓ PASS${NC}: $test_name"
        [ $VERBOSE -eq 1 ] && echo "  Found '$needle' in output"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗ FAIL${NC}: $test_name"
        echo "  Expected to find: '$needle'"
        echo "  In: '$haystack'"
        [ $STOP_ON_ERROR -eq 1 ] && exit 1
        return 1
    fi
}

skip_test() {
    local reason="$1"
    local test_name="$2"

    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
    echo -e "${YELLOW}⊘ SKIP${NC}: $test_name"
    [ $VERBOSE -eq 1 ] && echo "  Reason: $reason"
}

# Load configuration
load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "Configuration file not found: $CONFIG_FILE"
        log_info "Please create $CONFIG_FILE with mail server test configuration"
        exit 1
    fi

    source "$CONFIG_FILE"
    log_debug "Loaded configuration from $CONFIG_FILE"
}

# Setup test environment
setup_test_environment() {
    log_info "Setting up test environment..."

    # Create results directory
    mkdir -p "$RESULTS_DIR"

    # Create test data directory
    mkdir -p "$TEST_DATA_DIR/sample_emails"
    mkdir -p "$TEST_DATA_DIR/attachments"
    mkdir -p "$TEST_DATA_DIR/certificates"

    # Check for required tools
    check_dependencies

    log_success "Test environment ready"
}

# Check required dependencies
check_dependencies() {
    local missing_deps=()

    # Check for mail testing tools
    if ! command -v swaks &> /dev/null; then
        missing_deps+=("swaks (SMTP testing)")
    fi

    if ! command -v telnet &> /dev/null && ! command -v nc &> /dev/null; then
        missing_deps+=("telnet or nc (connectivity testing)")
    fi

    if ! command -v openssl &> /dev/null; then
        missing_deps+=("openssl (SSL/TLS testing)")
    fi

    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_warning "Missing optional dependencies: ${missing_deps[*]}"
        log_warning "Some tests may be skipped. Install missing tools for full test coverage."
    fi
}

# Test connectivity to mail server
test_connectivity() {
    log_info "Testing mail server connectivity..."

    # Test SMTP port
    if nc -z -w5 "$MAIL_SERVER" 25 2>/dev/null; then
        log_success "SMTP port 25 accessible"
    else
        log_warning "SMTP port 25 not accessible"
    fi

    # Test IMAP port
    if nc -z -w5 "$MAIL_SERVER" 143 2>/dev/null; then
        log_success "IMAP port 143 accessible"
    else
        log_warning "IMAP port 143 not accessible"
    fi

    # Test POP3 port
    if nc -z -w5 "$MAIL_SERVER" 110 2>/dev/null; then
        log_success "POP3 port 110 accessible"
    else
        log_warning "POP3 port 110 not accessible"
    fi

    # Test secure ports if SSL enabled
    if [ "$USE_SSL" = true ]; then
        if nc -z -w5 "$MAIL_SERVER" 465 2>/dev/null; then
            log_success "SMTPS port 465 accessible"
        fi
        if nc -z -w5 "$MAIL_SERVER" 993 2>/dev/null; then
            log_success "IMAPS port 993 accessible"
        fi
        if nc -z -w5 "$MAIL_SERVER" 995 2>/dev/null; then
            log_success "POP3S port 995 accessible"
        fi
    fi
}

# Run SMTP tests
run_smtp_tests() {
    log_info "Running SMTP tests..."
    if [ -f "${SCRIPT_DIR}/smtp_tests.sh" ]; then
        source "${SCRIPT_DIR}/smtp_tests.sh"
        run_smtp_test_suite
    else
        log_warning "SMTP test file not found: smtp_tests.sh"
    fi
}

# Run IMAP tests
run_imap_tests() {
    log_info "Running IMAP tests..."
    if [ -f "${SCRIPT_DIR}/imap_tests.sh" ]; then
        source "${SCRIPT_DIR}/imap_tests.sh"
        run_imap_test_suite
    else
        log_warning "IMAP test file not found: imap_tests.sh"
    fi
}

# Run POP3 tests
run_pop3_tests() {
    log_info "Running POP3 tests..."
    if [ -f "${SCRIPT_DIR}/pop3_tests.sh" ]; then
        source "${SCRIPT_DIR}/pop3_tests.sh"
        run_pop3_test_suite
    else
        log_warning "POP3 test file not found: pop3_tests.sh"
    fi
}

# Run mail operations tests
run_operations_tests() {
    log_info "Running mail operations tests..."
    if [ -f "${SCRIPT_DIR}/mail_operations.sh" ]; then
        source "${SCRIPT_DIR}/mail_operations.sh"
        run_operations_test_suite
    else
        log_warning "Mail operations test file not found: mail_operations.sh"
    fi
}

# Run performance tests
run_performance_tests() {
    log_info "Running performance tests..."
    # TODO: Implement performance testing
    log_warning "Performance tests not yet implemented"
}

# Generate test report
generate_report() {
    if [ $GENERATE_REPORT -eq 1 ]; then
        log_info "Generating HTML test report..."

        local report_file="${RESULTS_DIR}/test_report.html"
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

        cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Mail Server Factory Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .header { background: #f0f0f0; padding: 20px; border-radius: 5px; }
        .summary { margin: 20px 0; }
        .passed { color: green; }
        .failed { color: red; }
        .skipped { color: orange; }
        .results { margin-top: 30px; }
        pre { background: #f5f5f5; padding: 10px; border-radius: 3px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Mail Server Factory Test Report</h1>
        <p>Generated: $timestamp</p>
        <p>Target Distribution: ${TARGET_DISTRO:-All}</p>
    </div>

    <div class="summary">
        <h2>Test Summary</h2>
        <p class="passed">Passed: $TESTS_PASSED</p>
        <p class="failed">Failed: $TESTS_FAILED</p>
        <p class="skipped">Skipped: $TESTS_SKIPPED</p>
        <p>Total: $TESTS_RUN</p>
    </div>

    <div class="results">
        <h2>Detailed Results</h2>
        <pre>
$(cat "${RESULTS_DIR}/test_results.log" 2>/dev/null || echo "No detailed results available")
        </pre>
    </div>
</body>
</html>
EOF

        log_success "HTML report generated: $report_file"
    fi
}

# Print test summary
print_summary() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Mail Server Factory Test Summary${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "Total tests run:     $TESTS_RUN"
    echo -e "${GREEN}Tests passed:        $TESTS_PASSED${NC}"
    echo -e "${RED}Tests failed:        $TESTS_FAILED${NC}"
    echo -e "${YELLOW}Tests skipped:       $TESTS_SKIPPED${NC}"

    if [ $TESTS_RUN -gt 0 ]; then
        local success_rate=$(( (TESTS_PASSED * 100) / TESTS_RUN ))
        echo -e "Success rate:        ${success_rate}%"
    fi

    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

    # Save summary to file
    {
        echo "Mail Server Factory Test Summary"
        echo "Generated: $(date)"
        echo "Target Distribution: ${TARGET_DISTRO:-All}"
        echo ""
        echo "Total tests run: $TESTS_RUN"
        echo "Tests passed: $TESTS_PASSED"
        echo "Tests failed: $TESTS_FAILED"
        echo "Tests skipped: $TESTS_SKIPPED"
        if [ $TESTS_RUN -gt 0 ]; then
            echo "Success rate: $(( (TESTS_PASSED * 100) / TESTS_RUN ))%"
        fi
    } > "${RESULTS_DIR}/test_summary.txt"
}

# Show usage information
usage() {
    cat << EOF
Mail Server Factory - Mail Server Testing Framework

Usage: $0 [OPTIONS] [TEST_TYPE]

Test Types:
    --all           Run all test suites
    --smtp          Run SMTP tests only
    --imap          Run IMAP tests only
    --pop3          Run POP3 tests only
    --operations    Run mail operations tests
    --performance   Run performance tests

Options:
    --distro DISTRO Test specific distribution (ubuntu, centos, fedora, sles, rhel)
    --verbose       Show detailed test output
    --debug         Enable debug mode with additional logging
    --stop-on-error Stop execution on first test failure
    --report        Generate HTML test report
    --help          Show this help message

Examples:
    $0 --all                           # Run all tests
    $0 --smtp --verbose               # Run SMTP tests with verbose output
    $0 --distro ubuntu --operations    # Test mail operations on Ubuntu
    $0 --all --report                 # Run all tests and generate report

Configuration:
    Edit test_config.sh to configure mail server connection details,
    test accounts, timeouts, and SSL settings.

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --all)
                TEST_TYPE="all"
                shift
                ;;
            --smtp)
                TEST_TYPE="smtp"
                shift
                ;;
            --imap)
                TEST_TYPE="imap"
                shift
                ;;
            --pop3)
                TEST_TYPE="pop3"
                shift
                ;;
            --operations)
                TEST_TYPE="operations"
                shift
                ;;
            --performance)
                TEST_TYPE="performance"
                shift
                ;;
            --distro)
                TARGET_DISTRO="$2"
                shift 2
                ;;
            --verbose)
                VERBOSE=1
                shift
                ;;
            --debug)
                DEBUG=1
                VERBOSE=1
                shift
                ;;
            --stop-on-error)
                STOP_ON_ERROR=1
                shift
                ;;
            --report)
                GENERATE_REPORT=1
                shift
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    # Default to all tests if no type specified
    TEST_TYPE="${TEST_TYPE:-all}"
}

# Main test execution
main() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Mail Server Factory - Mail Server Testing Framework${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""

    # Parse arguments
    parse_args "$@"

    # Load configuration
    load_config

    # Setup environment
    setup_test_environment

    # Test connectivity
    test_connectivity

    # Redirect output to log file if generating report
    if [ $GENERATE_REPORT -eq 1 ]; then
        exec > >(tee "${RESULTS_DIR}/test_results.log") 2>&1
    fi

    # Run selected tests
    case "$TEST_TYPE" in
        "all")
            run_smtp_tests
            run_imap_tests
            run_pop3_tests
            run_operations_tests
            ;;
        "smtp")
            run_smtp_tests
            ;;
        "imap")
            run_imap_tests
            ;;
        "pop3")
            run_pop3_tests
            ;;
        "operations")
            run_operations_tests
            ;;
        "performance")
            run_performance_tests
            ;;
        *)
            log_error "Invalid test type: $TEST_TYPE"
            exit 1
            ;;
    esac

    # Generate report if requested
    generate_report

    # Print summary
    print_summary

    # Exit with appropriate code
    if [ $TESTS_FAILED -gt 0 ]; then
        exit 1
    else
        exit 0
    fi
}

# Run main function
main "$@"</content>
</xai:function_call">Create main test framework script