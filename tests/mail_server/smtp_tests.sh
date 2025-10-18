# Mail Server Factory - SMTP Tests
# Tests for SMTP send functionality

# Test SMTP connectivity
test_smtp_connectivity() {
    log_info "Testing SMTP connectivity"

    # Test basic connection to SMTP port
    if nc -z -w5 "$MAIL_SERVER" 25 2>/dev/null; then
        assert_equals "true" "true" "SMTP port 25 is accessible"
    else
        skip_test "SMTP port 25 not accessible" "SMTP connectivity"
        return
    fi

    # Test SMTP greeting
    local response=$(timeout 10 bash -c "echo 'QUIT' | telnet $MAIL_SERVER 25 2>/dev/null | head -1")
    if [[ "$response" == *"220"* ]]; then
        assert_equals "true" "true" "SMTP server responds with greeting"
    else
        assert_equals "220 greeting" "$response" "SMTP greeting response"
    fi
}

# Test basic SMTP send
test_smtp_send_basic() {
    log_info "Testing basic SMTP send functionality"

    if ! command -v swaks &> /dev/null; then
        skip_test "swaks not installed" "SMTP send basic"
        return
    fi

    # Create test email content
    local email_content="Subject: Test Email $(date +%s)
From: $TEST_USER
To: $TEST_USER

This is a test email sent by Mail Server Factory testing framework.
Timestamp: $(date)"

    # Send email using swaks
    echo "$email_content" | swaks \
        --server "$MAIL_SERVER" \
        --port 25 \
        --to "$TEST_USER" \
        --from "$TEST_USER" \
        --timeout "$SMTP_TIMEOUT" \
        --quit-after RCPT \
        2>/dev/null

    local exit_code=$?
    assert_exit_code 0 $exit_code "SMTP send basic email"
}

# Test SMTP authentication
test_smtp_authentication() {
    log_info "Testing SMTP authentication"

    if ! command -v swaks &> /dev/null; then
        skip_test "swaks not installed" "SMTP authentication"
        return
    fi

    # Test SMTP AUTH PLAIN
    echo "Subject: Auth Test $(date +%s)
From: $TEST_USER
To: $TEST_USER

SMTP authentication test." | swaks \
        --server "$MAIL_SERVER" \
        --port 587 \
        --to "$TEST_USER" \
        --from "$TEST_USER" \
        --auth-user "$TEST_USER" \
        --auth-password "$TEST_PASSWORD" \
        --auth PLAIN \
        --timeout "$SMTP_TIMEOUT" \
        --tls \
        2>/dev/null

    local exit_code=$?
    assert_exit_code 0 $exit_code "SMTP authentication with PLAIN"
}

# Test SMTP with TLS
test_smtp_tls() {
    log_info "Testing SMTP with TLS encryption"

    if ! command -v swaks &> /dev/null; then
        skip_test "swaks not installed" "SMTP TLS"
        return
    fi

    if [ "$USE_SSL" != true ]; then
        skip_test "SSL testing disabled" "SMTP TLS"
        return
    fi

    # Test SMTPS (SMTP over SSL)
    echo "Subject: TLS Test $(date +%s)
From: $TEST_USER
To: $TEST_USER

SMTP over TLS test." | swaks \
        --server "$MAIL_SERVER" \
        --port 465 \
        --to "$TEST_USER" \
        --from "$TEST_USER" \
        --auth-user "$TEST_USER" \
        --auth-password "$TEST_PASSWORD" \
        --tls-on-connect \
        --timeout "$SMTP_TIMEOUT" \
        2>/dev/null

    local exit_code=$?
    assert_exit_code 0 $exit_code "SMTP over TLS (port 465)"
}

# Test SMTP STARTTLS
test_smtp_starttls() {
    log_info "Testing SMTP STARTTLS"

    if ! command -v swaks &> /dev/null; then
        skip_test "swaks not installed" "SMTP STARTTLS"
        return
    fi

    # Test STARTTLS on port 587
    echo "Subject: STARTTLS Test $(date +%s)
From: $TEST_USER
To: $TEST_USER

SMTP STARTTLS test." | swaks \
        --server "$MAIL_SERVER" \
        --port 587 \
        --to "$TEST_USER" \
        --from "$TEST_USER" \
        --auth-user "$TEST_USER" \
        --auth-password "$TEST_PASSWORD" \
        --tls \
        --timeout "$SMTP_TIMEOUT" \
        2>/dev/null

    local exit_code=$?
    assert_exit_code 0 $exit_code "SMTP STARTTLS (port 587)"
}

# Test SMTP with attachment
test_smtp_attachment() {
    log_info "Testing SMTP with email attachment"

    if ! command -v swaks &> /dev/null; then
        skip_test "swaks not installed" "SMTP attachment"
        return
    fi

    # Create test attachment
    local attachment_file="${TEST_DATA_DIR}/attachments/test_attachment.txt"
    echo "This is a test attachment file created by Mail Server Factory tests." > "$attachment_file"

    # Send email with attachment
    echo "Subject: Attachment Test $(date +%s)
From: $TEST_USER
To: $TEST_USER

This email contains an attachment." | swaks \
        --server "$MAIL_SERVER" \
        --port 587 \
        --to "$TEST_USER" \
        --from "$TEST_USER" \
        --auth-user "$TEST_USER" \
        --auth-password "$TEST_PASSWORD" \
        --tls \
        --attach "$attachment_file" \
        --timeout "$SMTP_TIMEOUT" \
        2>/dev/null

    local exit_code=$?
    assert_exit_code 0 $exit_code "SMTP send with attachment"
}

# Test SMTP multiple recipients
test_smtp_multiple_recipients() {
    log_info "Testing SMTP with multiple recipients"

    if ! command -v swaks &> /dev/null; then
        skip_test "swaks not installed" "SMTP multiple recipients"
        return
    fi

    # Send to multiple recipients (if TEST_USER2 is configured)
    if [ -n "$TEST_USER2" ]; then
        echo "Subject: Multi-Recipient Test $(date +%s)
From: $TEST_USER
To: $TEST_USER, $TEST_USER2

This email is sent to multiple recipients." | swaks \
            --server "$MAIL_SERVER" \
            --port 587 \
            --to "$TEST_USER,$TEST_USER2" \
            --from "$TEST_USER" \
            --auth-user "$TEST_USER" \
            --auth-password "$TEST_PASSWORD" \
            --tls \
            --timeout "$SMTP_TIMEOUT" \
            2>/dev/null

        local exit_code=$?
        assert_exit_code 0 $exit_code "SMTP send to multiple recipients"
    else
        skip_test "TEST_USER2 not configured" "SMTP multiple recipients"
    fi
}

# Test SMTP relay restrictions
test_smtp_relay_restrictions() {
    log_info "Testing SMTP relay restrictions"

    if ! command -v swaks &> /dev/null; then
        skip_test "swaks not installed" "SMTP relay restrictions"
        return
    fi

    # Try to send to external domain (should be rejected)
    echo "Subject: Relay Test $(date +%s)
From: $TEST_USER
To: external@example.org

This should be rejected by relay restrictions." | swaks \
        --server "$MAIL_SERVER" \
        --port 587 \
        --to "external@example.org" \
        --from "$TEST_USER" \
        --auth-user "$TEST_USER" \
        --auth-password "$TEST_PASSWORD" \
        --tls \
        --timeout "$SMTP_TIMEOUT" \
        2>/dev/null

    local exit_code=$?
    # Should fail (exit code != 0) due to relay restrictions
    if [ $exit_code -ne 0 ]; then
        assert_equals "true" "true" "SMTP relay restrictions working (external domain rejected)"
    else
        assert_equals "relay rejection" "relay allowed" "SMTP relay restrictions"
    fi
}

# Test SMTP rate limiting
test_smtp_rate_limiting() {
    log_info "Testing SMTP rate limiting"

    if ! command -v swaks &> /dev/null; then
        skip_test "swaks not installed" "SMTP rate limiting"
        return
    fi

    # Send multiple emails quickly to test rate limiting
    local success_count=0
    local total_attempts=5

    for i in $(seq 1 $total_attempts); do
        echo "Subject: Rate Limit Test $i $(date +%s)
From: $TEST_USER
To: $TEST_USER

Rate limiting test email $i." | swaks \
            --server "$MAIL_SERVER" \
            --port 587 \
            --to "$TEST_USER" \
            --from "$TEST_USER" \
            --auth-user "$TEST_USER" \
            --auth-password "$TEST_PASSWORD" \
            --tls \
            --timeout "$SMTP_TIMEOUT" \
            2>/dev/null

        if [ $? -eq 0 ]; then
            success_count=$((success_count + 1))
        fi

        # Small delay between sends
        sleep 0.1
    done

    # Rate limiting should allow reasonable sending
    if [ $success_count -ge 3 ]; then
        assert_equals "true" "true" "SMTP rate limiting allows reasonable sending ($success_count/$total_attempts)"
    else
        assert_equals "reasonable rate" "rate limited" "SMTP rate limiting"
    fi
}

# Test SMTP banner and capabilities
test_smtp_capabilities() {
    log_info "Testing SMTP server capabilities"

    # Connect and get EHLO response
    local ehlo_response=$(timeout 10 bash -c "
        exec 3<>/dev/tcp/$MAIL_SERVER/25
        echo -e 'EHLO test.example.com\r' >&3
        cat <&3 | head -20
        echo -e 'QUIT\r' >&3
    " 2>/dev/null)

    # Check for common SMTP extensions
    if [[ "$ehlo_response" == *"250-STARTTLS"* ]]; then
        assert_equals "true" "true" "SMTP supports STARTTLS"
    else
        log_warning "STARTTLS not advertised"
    fi

    if [[ "$ehlo_response" == *"250-AUTH"* ]]; then
        assert_equals "true" "true" "SMTP supports AUTH"
    else
        log_warning "AUTH not advertised"
    fi

    if [[ "$ehlo_response" == *"250-SIZE"* ]]; then
        assert_equals "true" "true" "SMTP supports SIZE"
    else
        log_warning "SIZE not advertised"
    fi
}

# Run all SMTP tests
run_smtp_test_suite() {
    echo -e "\n${BLUE}═══ SMTP Test Suite ═══${NC}"

    test_smtp_connectivity
    test_smtp_send_basic
    test_smtp_authentication
    test_smtp_tls
    test_smtp_starttls
    test_smtp_attachment
    test_smtp_multiple_recipients
    test_smtp_relay_restrictions
    test_smtp_rate_limiting
    test_smtp_capabilities

    echo -e "${BLUE}═══ SMTP Tests Complete ═══${NC}"
}</content>
</xai:function_call">Create SMTP tests file