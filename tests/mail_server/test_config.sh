# Mail Server Factory - Test Configuration
# Configure mail server connection details and test parameters

# ==========================================
# Mail Server Connection Configuration
# ==========================================

# Mail server hostname/IP address
# This should be the IP address of your Mail Server Factory VM
MAIL_SERVER="192.168.122.100"

# Mail domain
MAIL_DOMAIN="example.com"

# ==========================================
# Test Account Configuration
# ==========================================

# Test user account credentials
# These should match the accounts created during mail server setup
TEST_USER="test@example.com"
TEST_PASSWORD="testpass123"

# Additional test accounts (for multi-user testing)
TEST_USER2="test2@example.com"
TEST_PASSWORD2="testpass456"

# ==========================================
# Protocol Timeouts (seconds)
# ==========================================

SMTP_TIMEOUT=30
IMAP_TIMEOUT=30
POP3_TIMEOUT=30

# ==========================================
# SSL/TLS Configuration
# ==========================================

# Enable SSL/TLS testing
USE_SSL=true

# Path to SSL certificate (for certificate validation tests)
SSL_CERT_PATH="${SCRIPT_DIR}/test_data/certificates/mailserver.crt"

# ==========================================
# Test Parameters
# ==========================================

# Number of test messages to send/receive
TEST_MESSAGE_COUNT=10

# Test attachment size (bytes)
TEST_ATTACHMENT_SIZE=1024

# Performance test parameters
PERF_CONCURRENT_CONNECTIONS=5
PERF_TEST_DURATION=60

# ==========================================
# Advanced Configuration
# ==========================================

# Enable debug logging for mail server protocols
DEBUG_PROTOCOL=false

# Preserve test messages after testing (don't clean up)
PRESERVE_TEST_MESSAGES=false

# Test data directories
SAMPLE_EMAILS_DIR="${SCRIPT_DIR}/test_data/sample_emails"
ATTACHMENTS_DIR="${SCRIPT_DIR}/test_data/attachments"
CERTIFICATES_DIR="${SCRIPT_DIR}/test_data/certificates"

# ==========================================
# Distribution-Specific Settings
# ==========================================

# Ubuntu-specific settings
UBUNTU_PACKAGE_MANAGER="apt"
UBUNTU_MAIL_SERVICE="postfix"

# CentOS/RHEL-specific settings
CENTOS_PACKAGE_MANAGER="yum"
CENTOS_MAIL_SERVICE="postfix"

# Fedora-specific settings
FEDORA_PACKAGE_MANAGER="dnf"
FEDORA_MAIL_SERVICE="postfix"

# SUSE-specific settings
SLES_PACKAGE_MANAGER="zypper"
SLES_MAIL_SERVICE="postfix"

# ==========================================
# Validation Settings
# ==========================================

# Expected mail server ports
EXPECTED_SMTP_PORT=25
EXPECTED_IMAP_PORT=143
EXPECTED_POP3_PORT=110

# SSL ports
EXPECTED_SMTPS_PORT=465
EXPECTED_IMAPS_PORT=993
EXPECTED_POP3S_PORT=995

# ==========================================
# Custom Test Hooks
# ==========================================

# Pre-test setup hook (bash function name)
# This function will be called before running tests
PRE_TEST_HOOK=""

# Post-test cleanup hook (bash function name)
# This function will be called after running tests
POST_TEST_HOOK=""

# ==========================================
# Environment Detection
# ==========================================

# Auto-detect mail server capabilities
AUTO_DETECT_CAPABILITIES=true

# Supported authentication methods to test
TEST_AUTH_METHODS=("PLAIN" "LOGIN" "CRAM-MD5")

# Supported encryption methods to test
TEST_ENCRYPTION_METHODS=("TLS" "SSL")

# ==========================================
# Reporting Configuration
# ==========================================

# Include performance metrics in reports
INCLUDE_PERFORMANCE_METRICS=true

# Include system resource usage in reports
INCLUDE_SYSTEM_METRICS=false

# Report output format (text, html, json)
REPORT_FORMAT="html"</content>
</xai:function_call">Create test configuration file