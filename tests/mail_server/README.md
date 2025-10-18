# Mail Server Testing Framework

This directory contains comprehensive automated tests for Mail Server Factory mail server functionality.

## Test Coverage

The testing framework covers the following mail server operations:

### Core Mail Operations
- **Send Email**: SMTP send functionality
- **Receive Email**: IMAP/POP3 retrieval
- **Delete Messages**: Message deletion
- **Create Folders**: Mailbox folder creation
- **Move Messages**: Message relocation between folders

### Advanced Features
- **Authentication**: Login/logout, password changes
- **Message Management**: Read/unread status, flags
- **Search**: Message searching and filtering
- **Attachments**: File attachment handling
- **Encryption**: TLS/SSL security testing

### Distribution Coverage
- Ubuntu Server
- CentOS/RHEL
- Fedora Server
- SUSE Linux Enterprise Server

## Test Structure

```
tests/mail_server/
├── README.md                 # This file
├── test_framework.sh         # Main test framework
├── smtp_tests.sh            # SMTP functionality tests
├── imap_tests.sh            # IMAP functionality tests
├── pop3_tests.sh            # POP3 functionality tests
├── mail_operations.sh       # Core mail operations
├── test_config.sh           # Test configuration
├── test_data/               # Test data and fixtures
│   ├── sample_emails/       # Sample email files
│   ├── attachments/         # Test attachments
│   └── certificates/        # SSL certificates
└── results/                 # Test results and logs
```

## Prerequisites

### System Requirements
- Mail server VM running (created by Mail Server Factory)
- Network access to mail server ports:
  - SMTP: 25, 587, 465
  - IMAP: 143, 993
  - POP3: 110, 995
- Test client tools installed:
  - `swaks` (SMTP testing)
  - `imaptest` or `imapsync` (IMAP testing)
  - `telnet` or `openssl s_client` (basic connectivity)

### Test Account Setup
The tests require a test mail account to be configured:

```bash
# Test account credentials (configured in test_config.sh)
TEST_USER="test@example.com"
TEST_PASSWORD="testpass123"
TEST_DOMAIN="example.com"
```

## Running Tests

### Run All Tests
```bash
./test_framework.sh --all
```

### Run Specific Test Suite
```bash
./test_framework.sh --smtp        # SMTP tests only
./test_framework.sh --imap        # IMAP tests only
./test_framework.sh --pop3        # POP3 tests only
./test_framework.sh --operations  # Mail operations tests
```

### Run Tests for Specific Distribution
```bash
./test_framework.sh --distro ubuntu --all
./test_framework.sh --distro centos --smtp
```

### Test Options
```bash
./test_framework.sh --verbose     # Detailed output
./test_framework.sh --stop-on-error  # Stop on first failure
./test_framework.sh --report      # Generate HTML report
```

## Test Configuration

Edit `test_config.sh` to configure:

```bash
# Mail server connection details
MAIL_SERVER="192.168.122.100"  # VM IP address
MAIL_DOMAIN="example.com"

# Test accounts
TEST_USER="test@example.com"
TEST_PASSWORD="testpass123"

# Test timeouts
SMTP_TIMEOUT=30
IMAP_TIMEOUT=30
POP3_TIMEOUT=30

# SSL/TLS settings
USE_SSL=true
SSL_CERT_PATH="/path/to/cert.pem"
```

## Test Results

Test results are stored in the `results/` directory:

- `test_results.log` - Detailed test execution log
- `test_summary.txt` - Test summary with pass/fail counts
- `test_report.html` - HTML report (if --report option used)
- `performance_metrics.txt` - Performance measurements

## Adding New Tests

### Test Function Structure
```bash
test_function_name() {
    local test_name="Test Description"
    local expected_result="expected output"

    # Test implementation
    local actual_result=$(run_test_command)

    # Assertion
    assert_equals "$expected_result" "$actual_result" "$test_name"
}
```

### Test Categories
- Use descriptive function names: `test_smtp_send_plain_auth`
- Group related tests in separate files
- Include setup/cleanup functions for each test

### Sample Test
```bash
test_smtp_send_basic() {
    log_info "Testing basic SMTP send functionality"

    # Send test email
    echo "Subject: Test Email
From: $TEST_USER
To: $TEST_USER

This is a test email body." | swaks \
        --server $MAIL_SERVER \
        --port 587 \
        --to $TEST_USER \
        --from $TEST_USER \
        --auth-user $TEST_USER \
        --auth-password $TEST_PASSWORD \
        --tls

    assert_exit_code 0 $? "SMTP send basic email"
}
```

## Troubleshooting

### Common Issues

1. **Connection Refused**
   - Check if mail server is running
   - Verify firewall settings
   - Ensure VM network is accessible

2. **Authentication Failed**
   - Verify test account credentials
   - Check mail server authentication settings
   - Ensure account exists and is enabled

3. **SSL/TLS Errors**
   - Verify SSL certificates
   - Check mail server SSL configuration
   - Use --no-ssl option for testing

### Debug Mode
```bash
./test_framework.sh --debug --verbose --all
```

This enables detailed logging and preserves temporary files for analysis.

## Integration with CI/CD

The test framework can be integrated into CI/CD pipelines:

```yaml
# Example GitHub Actions
- name: Run Mail Server Tests
  run: |
    cd tests/mail_server
    ./test_framework.sh --all --report
- name: Upload Test Results
  uses: actions/upload-artifact@v2
  with:
    name: test-results
    path: tests/mail_server/results/
```

## Performance Testing

The framework includes basic performance measurements:

- Message send/receive throughput
- Concurrent connection handling
- Memory usage during operations
- Response time metrics

Run performance tests with:
```bash
./test_framework.sh --performance
```</content>
</xai:function_call">Create comprehensive README for mail server testing framework