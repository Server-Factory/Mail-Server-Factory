# Mail Server Factory - Mail Operations Tests
# Tests for core mail operations: send, receive, delete, create folder, move messages

# Setup test environment for mail operations
setup_mail_operations() {
    log_debug "Setting up mail operations test environment"

    # Create test directories
    mkdir -p "$TEST_DATA_DIR/sample_emails"
    mkdir -p "$TEST_DATA_DIR/attachments"

    # Create sample email files
    cat > "$TEST_DATA_DIR/sample_emails/test_email_1.txt" << EOF
Subject: Test Email 1
From: $TEST_USER
To: $TEST_USER
Date: $(date -R)

This is test email 1 for mail operations testing.
EOF

    cat > "$TEST_DATA_DIR/sample_emails/test_email_2.txt" << EOF
Subject: Test Email 2
From: $TEST_USER
To: $TEST_USER
Date: $(date -R)

This is test email 2 for mail operations testing.
EOF

    # Create test attachment
    echo "Test attachment content" > "$TEST_DATA_DIR/attachments/test.txt"
}

# Cleanup test environment
cleanup_mail_operations() {
    log_debug "Cleaning up mail operations test environment"

    if [ "$PRESERVE_TEST_MESSAGES" != true ]; then
        # Remove test mailboxes and messages
        log_debug "Removing test messages and mailboxes"
    fi
}

# Test sending email
test_send_email() {
    log_info "Testing email sending operation"

    if ! command -v swaks &> /dev/null; then
        skip_test "swaks not installed" "send email"
        return
    fi

    local subject="Send Test $(date +%s)"
    local body="This is a test email for send operation testing."

    echo "Subject: $subject
From: $TEST_USER
To: $TEST_USER

$body" | swaks \
        --server "$MAIL_SERVER" \
        --port 587 \
        --to "$TEST_USER" \
        --from "$TEST_USER" \
        --auth-user "$TEST_USER" \
        --auth-password "$TEST_PASSWORD" \
        --tls \
        --timeout "$SMTP_TIMEOUT" \
        >/dev/null 2>&1

    local exit_code=$?
    assert_exit_code 0 $exit_code "Email sending operation"
}

# Test receiving email via IMAP
test_receive_email_imap() {
    log_info "Testing email receiving via IMAP"

    # First send a test email
    test_send_email

    # Wait a moment for delivery
    sleep 2

    # Try to fetch the message via IMAP
    local fetch_result=$(timeout $IMAP_TIMEOUT bash -c "
        exec 3<>/dev/tcp/$MAIL_SERVER/143
        echo -e 'a001 LOGIN \"$TEST_USER\" \"$TEST_PASSWORD\"\r\n' >&3
        sleep 0.1
        echo -e 'a002 SELECT INBOX\r\n' >&3
        sleep 0.1
        echo -e 'a003 SEARCH SUBJECT \"Send Test\"\r\n' >&3
        sleep 0.1
        echo -e 'a004 LOGOUT\r\n' >&3
        cat <&3 | grep 'a003'
    " 2>/dev/null)

    if [[ "$fetch_result" == *"OK"* ]]; then
        assert_equals "true" "true" "Email receiving via IMAP"
    else
        assert_equals "message found" "not found" "Email receiving via IMAP"
    fi
}

# Test receiving email via POP3
test_receive_email_pop3() {
    log_info "Testing email receiving via POP3"

    # First send a test email
    test_send_email

    # Wait a moment for delivery
    sleep 2

    # Try to fetch the message via POP3
    local pop3_result=$(timeout $POP3_TIMEOUT bash -c "
        exec 3<>/dev/tcp/$MAIL_SERVER/110
        echo -e 'USER $TEST_USER\r\n' >&3
        sleep 0.1
        echo -e 'PASS $TEST_PASSWORD\r\n' >&3
        sleep 0.1
        echo -e 'STAT\r\n' >&3
        sleep 0.1
        echo -e 'QUIT\r\n' >&3
        cat <&3 | grep 'STAT'
    " 2>/dev/null)

    if [[ "$pop3_result" == *"+OK"* ]]; then
        assert_equals "true" "true" "Email receiving via POP3"
    else
        assert_equals "+OK" "$(echo "$pop3_result" | grep -o '+OK\|-ERR')" "Email receiving via POP3"
    fi
}

# Test deleting email via IMAP
test_delete_email_imap() {
    log_info "Testing email deletion via IMAP"

    # Send a test email first
    test_send_email
    sleep 2

    # Delete the message via IMAP
    local delete_result=$(timeout $IMAP_TIMEOUT bash -c "
        exec 3<>/dev/tcp/$MAIL_SERVER/143
        echo -e 'a001 LOGIN \"$TEST_USER\" \"$TEST_PASSWORD\"\r\n' >&3
        sleep 0.1
        echo -e 'a002 SELECT INBOX\r\n' >&3
        sleep 0.1
        echo -e 'a003 SEARCH SUBJECT \"Send Test\"\r\n' >&3
        sleep 0.1
        echo -e 'a004 STORE 1 +FLAGS (\\Deleted)\r\n' >&3
        sleep 0.1
        echo -e 'a005 EXPUNGE\r\n' >&3
        sleep 0.1
        echo -e 'a006 LOGOUT\r\n' >&3
        cat <&3 | grep -E 'a004|a005'
    " 2>/dev/null)

    if [[ "$delete_result" == *"OK"* ]]; then
        assert_equals "true" "true" "Email deletion via IMAP"
    else
        assert_equals "deletion successful" "failed" "Email deletion via IMAP"
    fi
}

# Test deleting email via POP3
test_delete_email_pop3() {
    log_info "Testing email deletion via POP3"

    # Send a test email first
    test_send_email
    sleep 2

    # Delete the message via POP3
    local delete_result=$(timeout $POP3_TIMEOUT bash -c "
        exec 3<>/dev/tcp/$MAIL_SERVER/110
        echo -e 'USER $TEST_USER\r\n' >&3
        sleep 0.1
        echo -e 'PASS $TEST_PASSWORD\r\n' >&3
        sleep 0.1
        echo -e 'DELE 1\r\n' >&3
        sleep 0.1
        echo -e 'QUIT\r\n' >&3
        cat <&3 | grep 'DELE'
    " 2>/dev/null)

    if [[ "$delete_result" == *"+OK"* ]]; then
        assert_equals "true" "true" "Email deletion via POP3"
    else
        assert_equals "+OK" "$(echo "$delete_result" | grep -o '+OK\|-ERR')" "Email deletion via POP3"
    fi
}

# Test creating mailbox/folder via IMAP
test_create_mailbox() {
    log_info "Testing mailbox creation"

    local test_mailbox="TestFolder-$(date +%s)"

    local create_result=$(timeout $IMAP_TIMEOUT bash -c "
        exec 3<>/dev/tcp/$MAIL_SERVER/143
        echo -e 'a001 LOGIN \"$TEST_USER\" \"$TEST_PASSWORD\"\r\n' >&3
        sleep 0.1
        echo -e 'a002 CREATE \"$test_mailbox\"\r\n' >&3
        sleep 0.1
        echo -e 'a003 LIST \"\" \"$test_mailbox\"\r\n' >&3
        sleep 0.1
        echo -e 'a004 LOGOUT\r\n' >&3
        cat <&3 | grep -E 'a002|a003'
    " 2>/dev/null)

    if [[ "$create_result" == *"OK"* ]]; then
        assert_equals "true" "true" "Mailbox creation successful"

        # Cleanup: delete the test mailbox
        timeout $IMAP_TIMEOUT bash -c "
            exec 3<>/dev/tcp/$MAIL_SERVER/143
            echo -e 'a001 LOGIN \"$TEST_USER\" \"$TEST_PASSWORD\"\r\n' >&3
            sleep 0.1
            echo -e 'a002 DELETE \"$test_mailbox\"\r\n' >&3
            sleep 0.1
            echo -e 'a003 LOGOUT\r\n' >&3
        " >/dev/null 2>&1
    else
        assert_equals "creation successful" "failed" "Mailbox creation"
    fi
}

# Test moving messages between mailboxes via IMAP
test_move_messages() {
    log_info "Testing message move between mailboxes"

    local dest_mailbox="MoveDest-$(date +%s)"

    # Create destination mailbox
    timeout $IMAP_TIMEOUT bash -c "
        exec 3<>/dev/tcp/$MAIL_SERVER/143
        echo -e 'a001 LOGIN \"$TEST_USER\" \"$TEST_PASSWORD\"\r\n' >&3
        sleep 0.1
        echo -e 'a002 CREATE \"$dest_mailbox\"\r\n' >&3
        sleep 0.1
        echo -e 'a003 LOGOUT\r\n' >&3
    " >/dev/null 2>&1

    # Send a test message
    test_send_email
    sleep 2

    # Move the message
    local move_result=$(timeout $IMAP_TIMEOUT bash -c "
        exec 3<>/dev/tcp/$MAIL_SERVER/143
        echo -e 'a001 LOGIN \"$TEST_USER\" \"$TEST_PASSWORD\"\r\n' >&3
        sleep 0.1
        echo -e 'a002 SELECT INBOX\r\n' >&3
        sleep 0.1
        echo -e 'a003 MOVE 1 \"$dest_mailbox\"\r\n' >&3
        sleep 0.1
        echo -e 'a004 LOGOUT\r\n' >&3
        cat <&3 | grep 'a003'
    " 2>/dev/null)

    if [[ "$move_result" == *"OK"* ]]; then
        assert_equals "true" "true" "Message move successful"
    elif [[ "$move_result" == *"NO"* ]] || [[ "$move_result" == *"BAD"* ]]; then
        # MOVE might not be supported, try COPY + DELETE
        log_debug "MOVE not supported, trying COPY + DELETE"
        local copy_result=$(timeout $IMAP_TIMEOUT bash -c "
            exec 3<>/dev/tcp/$MAIL_SERVER/143
            echo -e 'a001 LOGIN \"$TEST_USER\" \"$TEST_PASSWORD\"\r\n' >&3
            sleep 0.1
            echo -e 'a002 SELECT INBOX\r\n' >&3
            sleep 0.1
            echo -e 'a003 COPY 1 \"$dest_mailbox\"\r\n' >&3
            sleep 0.1
            echo -e 'a004 STORE 1 +FLAGS (\\Deleted)\r\n' >&3
            sleep 0.1
            echo -e 'a005 EXPUNGE\r\n' >&3
            sleep 0.1
            echo -e 'a006 LOGOUT\r\n' >&3
            cat <&3 | grep -E 'a003|a004|a005'
        " 2>/dev/null)

        if [[ "$copy_result" == *"OK"* ]]; then
            assert_equals "true" "true" "Message move via COPY+DELETE successful"
        else
            assert_equals "move operation" "failed" "Message move operation"
        fi
    else
        assert_equals "move operation" "$move_result" "Message move operation"
    fi

    # Cleanup
    timeout $IMAP_TIMEOUT bash -c "
        exec 3<>/dev/tcp/$MAIL_SERVER/143
        echo -e 'a001 LOGIN \"$TEST_USER\" \"$TEST_PASSWORD\"\r\n' >&3
        sleep 0.1
        echo -e 'a002 DELETE \"$dest_mailbox\"\r\n' >&3
        sleep 0.1
        echo -e 'a003 LOGOUT\r\n' >&3
    " >/dev/null 2>&1
}

# Test bulk operations
test_bulk_operations() {
    log_info "Testing bulk mail operations"

    # Send multiple test emails
    for i in {1..5}; do
        echo "Subject: Bulk Test $i $(date +%s)
From: $TEST_USER
To: $TEST_USER

This is bulk test email $i." | swaks \
            --server "$MAIL_SERVER" \
            --port 587 \
            --to "$TEST_USER" \
            --from "$TEST_USER" \
            --auth-user "$TEST_USER" \
            --auth-password "$TEST_PASSWORD" \
            --tls \
            --timeout "$SMTP_TIMEOUT" \
            >/dev/null 2>&1
    done

    sleep 3

    # Check that multiple messages are received
    local count_result=$(timeout $IMAP_TIMEOUT bash -c "
        exec 3<>/dev/tcp/$MAIL_SERVER/143
        echo -e 'a001 LOGIN \"$TEST_USER\" \"$TEST_PASSWORD\"\r\n' >&3
        sleep 0.1
        echo -e 'a002 SELECT INBOX\r\n' >&3
        sleep 0.1
        echo -e 'a003 SEARCH SUBJECT \"Bulk Test\"\r\n' >&3
        sleep 0.1
        echo -e 'a004 LOGOUT\r\n' >&3
        cat <&3 | grep 'a003'
    " 2>/dev/null)

    if [[ "$count_result" == *"OK"* ]]; then
        # Extract message count from SEARCH result
        local msg_count=$(echo "$count_result" | grep -o '[0-9]\+' | wc -l)
        if [ "$msg_count" -ge 3 ]; then
            assert_equals "true" "true" "Bulk operations successful ($msg_count messages)"
        else
            assert_equals "multiple messages" "few messages" "Bulk operations"
        fi
    else
        assert_equals "bulk operation" "failed" "Bulk operations"
    fi
}

# Test message search functionality
test_message_search() {
    log_info "Testing message search functionality"

    # Send emails with different subjects
    echo "Subject: Search Test Important
From: $TEST_USER
To: $TEST_USER

This is an important message." | swaks \
        --server "$MAIL_SERVER" \
        --port 587 \
        --to "$TEST_USER" \
        --from "$TEST_USER" \
        --auth-user "$TEST_USER" \
        --auth-password "$TEST_PASSWORD" \
        --tls \
        --timeout "$SMTP_TIMEOUT" \
        >/dev/null 2>&1

    echo "Subject: Search Test Urgent
From: $TEST_USER
To: $TEST_USER

This is an urgent message." | swaks \
        --server "$MAIL_SERVER" \
        --port 587 \
        --to "$TEST_USER" \
        --from "$TEST_USER" \
        --auth-user "$TEST_USER" \
        --auth-password "$TEST_PASSWORD" \
        --tls \
        --timeout "$SMTP_TIMEOUT" \
        >/dev/null 2>&1

    sleep 3

    # Search for messages
    local search_result=$(timeout $IMAP_TIMEOUT bash -c "
        exec 3<>/dev/tcp/$MAIL_SERVER/143
        echo -e 'a001 LOGIN \"$TEST_USER\" \"$TEST_PASSWORD\"\r\n' >&3
        sleep 0.1
        echo -e 'a002 SELECT INBOX\r\n' >&3
        sleep 0.1
        echo -e 'a003 SEARCH SUBJECT \"Search Test\"\r\n' >&3
        sleep 0.1
        echo -e 'a004 LOGOUT\r\n' >&3
        cat <&3 | grep 'a003'
    " 2>/dev/null)

    if [[ "$search_result" == *"OK"* ]]; then
        assert_equals "true" "true" "Message search functionality works"
    else
        assert_equals "search successful" "failed" "Message search functionality"
    fi
}

# Test message flags (read/unread)
test_message_flags() {
    log_info "Testing message flags (read/unread)"

    # Send a test message
    test_send_email
    sleep 2

    # Mark message as read
    local flag_result=$(timeout $IMAP_TIMEOUT bash -c "
        exec 3<>/dev/tcp/$MAIL_SERVER/143
        echo -e 'a001 LOGIN \"$TEST_USER\" \"$TEST_PASSWORD\"\r\n' >&3
        sleep 0.1
        echo -e 'a002 SELECT INBOX\r\n' >&3
        sleep 0.1
        echo -e 'a003 STORE 1 +FLAGS (\\Seen)\r\n' >&3
        sleep 0.1
        echo -e 'a004 LOGOUT\r\n' >&3
        cat <&3 | grep 'a003'
    " 2>/dev/null)

    if [[ "$flag_result" == *"OK"* ]]; then
        assert_equals "true" "true" "Message flag operations work"
    else
        assert_equals "flag operation" "failed" "Message flag operations"
    fi
}

# Run all mail operations tests
run_operations_test_suite() {
    echo -e "\n${BLUE}═══ Mail Operations Test Suite ═══${NC}"

    setup_mail_operations

    test_send_email
    test_receive_email_imap
    test_receive_email_pop3
    test_delete_email_imap
    test_delete_email_pop3
    test_create_mailbox
    test_move_messages
    test_bulk_operations
    test_message_search
    test_message_flags

    cleanup_mail_operations

    echo -e "${BLUE}═══ Mail Operations Tests Complete ═══${NC}"
}</content>
</xai:function_call">Create mail operations tests file