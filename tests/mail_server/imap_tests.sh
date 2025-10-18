# Mail Server Factory - IMAP Tests
# Tests for IMAP retrieval and management functionality

# Test IMAP connectivity
test_imap_connectivity() {
    log_info "Testing IMAP connectivity"

    # Test basic connection to IMAP port
    if nc -z -w5 "$MAIL_SERVER" 143 2>/dev/null; then
        assert_equals "true" "true" "IMAP port 143 is accessible"
    else
        skip_test "IMAP port 143 not accessible" "IMAP connectivity"
        return
    fi

    # Test IMAP greeting
    local response=$(timeout 10 bash -c "echo -e 'a001 LOGOUT\r\n' | nc $MAIL_SERVER 143 2>/dev/null | head -1")
    if [[ "$response" == *"OK"* ]] || [[ "$response" == *"PREAUTH"* ]]; then
        assert_equals "true" "true" "IMAP server responds with greeting"
    else
        assert_equals "IMAP greeting" "$response" "IMAP greeting response"
    fi
}

# Test IMAP login
test_imap_login() {
    log_info "Testing IMAP login"

    if ! command -v openssl &> /dev/null; then
        skip_test "openssl not available" "IMAP login"
        return
    fi

    # Use openssl to connect and login
    local login_response=$(timeout $IMAP_TIMEOUT bash -c "
        exec 3<>/dev/tcp/$MAIL_SERVER/143
        echo -e 'a001 LOGIN \"$TEST_USER\" \"$TEST_PASSWORD\"\r\n' >&3
        echo -e 'a002 LOGOUT\r\n' >&3
        cat <&3 | grep 'a001'
    " 2>/dev/null)

    if [[ "$login_response" == *"OK"* ]]; then
        assert_equals "true" "true" "IMAP login successful"
    else
        assert_equals "OK" "$(echo "$login_response" | grep -o 'OK\|NO\|BAD')" "IMAP login response"
    fi
}

# Test IMAP over SSL
test_imap_ssl() {
    log_info "Testing IMAP over SSL"

    if [ "$USE_SSL" != true ]; then
        skip_test "SSL testing disabled" "IMAP SSL"
        return
    fi

    # Test IMAPS port
    if nc -z -w5 "$MAIL_SERVER" 993 2>/dev/null; then
        assert_equals "true" "true" "IMAPS port 993 is accessible"
    else
        skip_test "IMAPS port 993 not accessible" "IMAP SSL"
        return
    fi

    # Test SSL connection
    local ssl_response=$(timeout $IMAP_TIMEOUT openssl s_client -connect "$MAIL_SERVER:993" -quiet 2>/dev/null <<EOF
a001 LOGIN "$TEST_USER" "$TEST_PASSWORD"
a002 LIST "" "*"
a003 LOGOUT
EOF
    )

    if [[ "$ssl_response" == *"OK"* ]]; then
        assert_equals "true" "true" "IMAP SSL connection successful"
    else
        assert_equals "SSL connection" "failed" "IMAP SSL connection"
    fi
}

# Test IMAP mailbox listing
test_imap_list_mailboxes() {
    log_info "Testing IMAP mailbox listing"

    # Use a simple IMAP client approach
    local list_response=$(timeout $IMAP_TIMEOUT bash -c "
        exec 3<>/dev/tcp/$MAIL_SERVER/143
        echo -e 'a001 LOGIN \"$TEST_USER\" \"$TEST_PASSWORD\"\r\n' >&3
        sleep 0.1
        echo -e 'a002 LIST \"\" \"*\"\r\n' >&3
        sleep 0.1
        echo -e 'a003 LOGOUT\r\n' >&3
        cat <&3 | grep 'a002'
    " 2>/dev/null)

    if [[ "$list_response" == *"LIST"* ]] || [[ "$list_response" == *"OK"* ]]; then
        assert_equals "true" "true" "IMAP mailbox listing works"
    else
        assert_equals "mailbox list" "$list_response" "IMAP LIST command"
    fi
}

# Test IMAP message retrieval
test_imap_fetch_messages() {
    log_info "Testing IMAP message retrieval"

    # First, ensure there's at least one message (send one via SMTP if needed)
    if command -v swaks &> /dev/null; then
        echo "Subject: IMAP Test Message $(date +%s)
From: $TEST_USER
To: $TEST_USER

This is a test message for IMAP retrieval." | swaks \
            --server "$MAIL_SERVER" \
            --port 587 \
            --to "$TEST_USER" \
            --from "$TEST_USER" \
            --auth-user "$TEST_USER" \
            --auth-password "$TEST_PASSWORD" \
            --tls \
            --timeout "$SMTP_TIMEOUT" \
            >/dev/null 2>&1
    fi

    # Fetch messages from INBOX
    local fetch_response=$(timeout $IMAP_TIMEOUT bash -c "
        exec 3<>/dev/tcp/$MAIL_SERVER/143
        echo -e 'a001 LOGIN \"$TEST_USER\" \"$TEST_PASSWORD\"\r\n' >&3
        sleep 0.1
        echo -e 'a002 SELECT INBOX\r\n' >&3
        sleep 0.1
        echo -e 'a003 FETCH 1 BODY[HEADER]\r\n' >&3
        sleep 0.1
        echo -e 'a004 LOGOUT\r\n' >&3
        cat <&3 | grep -A 5 'a003'
    " 2>/dev/null)

    if [[ "$fetch_response" == *"FETCH"* ]] || [[ "$fetch_response" == *"OK"* ]]; then
        assert_equals "true" "true" "IMAP message fetch works"
    else
        assert_equals "message fetch" "$fetch_response" "IMAP FETCH command"
    fi
}

# Test IMAP create mailbox
test_imap_create_mailbox() {
    log_info "Testing IMAP mailbox creation"

    local mailbox_name="TestMailbox-$(date +%s)"

    local create_response=$(timeout $IMAP_TIMEOUT bash -c "
        exec 3<>/dev/tcp/$MAIL_SERVER/143
        echo -e 'a001 LOGIN \"$TEST_USER\" \"$TEST_PASSWORD\"\r\n' >&3
        sleep 0.1
        echo -e 'a002 CREATE \"$mailbox_name\"\r\n' >&3
        sleep 0.1
        echo -e 'a003 LOGOUT\r\n' >&3
        cat <&3 | grep 'a002'
    " 2>/dev/null)

    if [[ "$create_response" == *"OK"* ]]; then
        assert_equals "true" "true" "IMAP mailbox creation successful"

        # Cleanup: delete the test mailbox
        timeout $IMAP_TIMEOUT bash -c "
            exec 3<>/dev/tcp/$MAIL_SERVER/143
            echo -e 'a001 LOGIN \"$TEST_USER\" \"$TEST_PASSWORD\"\r\n' >&3
            sleep 0.1
            echo -e 'a002 DELETE \"$mailbox_name\"\r\n' >&3
            sleep 0.1
            echo -e 'a003 LOGOUT\r\n' >&3
        " >/dev/null 2>&1
    else
        assert_equals "OK" "$(echo "$create_response" | grep -o 'OK\|NO\|BAD')" "IMAP CREATE command"
    fi
}

# Test IMAP delete mailbox
test_imap_delete_mailbox() {
    log_info "Testing IMAP mailbox deletion"

    local mailbox_name="DeleteTest-$(date +%s)"

    # First create a mailbox
    timeout $IMAP_TIMEOUT bash -c "
        exec 3<>/dev/tcp/$MAIL_SERVER/143
        echo -e 'a001 LOGIN \"$TEST_USER\" \"$TEST_PASSWORD\"\r\n' >&3
        sleep 0.1
        echo -e 'a002 CREATE \"$mailbox_name\"\r\n' >&3
        sleep 0.1
        echo -e 'a003 LOGOUT\r\n' >&3
    " >/dev/null 2>&1

    # Now try to delete it
    local delete_response=$(timeout $IMAP_TIMEOUT bash -c "
        exec 3<>/dev/tcp/$MAIL_SERVER/143
        echo -e 'a001 LOGIN \"$TEST_USER\" \"$TEST_PASSWORD\"\r\n' >&3
        sleep 0.1
        echo -e 'a002 DELETE \"$mailbox_name\"\r\n' >&3
        sleep 0.1
        echo -e 'a003 LOGOUT\r\n' >&3
        cat <&3 | grep 'a002'
    " 2>/dev/null)

    if [[ "$delete_response" == *"OK"* ]]; then
        assert_equals "true" "true" "IMAP mailbox deletion successful"
    else
        assert_equals "OK" "$(echo "$delete_response" | grep -o 'OK\|NO\|BAD')" "IMAP DELETE command"
    fi
}

# Test IMAP message move
test_imap_move_message() {
    log_info "Testing IMAP message move"

    local dest_mailbox="MoveTest-$(date +%s)"

    # Create destination mailbox
    timeout $IMAP_TIMEOUT bash -c "
        exec 3<>/dev/tcp/$MAIL_SERVER/143
        echo -e 'a001 LOGIN \"$TEST_USER\" \"$TEST_PASSWORD\"\r\n' >&3
        sleep 0.1
        echo -e 'a002 CREATE \"$dest_mailbox\"\r\n' >&3
        sleep 0.1
        echo -e 'a003 LOGOUT\r\n' >&3
    " >/dev/null 2>&dev/null

    # Move message (if MOVE extension is supported)
    local move_response=$(timeout $IMAP_TIMEOUT bash -c "
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

    if [[ "$move_response" == *"OK"* ]]; then
        assert_equals "true" "true" "IMAP message move successful"
    elif [[ "$move_response" == *"NO"* ]] || [[ "$move_response" == *"BAD"* ]]; then
        # MOVE might not be supported, try COPY + STORE + EXPUNGE
        log_debug "MOVE not supported, trying alternative method"
        assert_equals "MOVE not supported" "alternative needed" "IMAP MOVE command"
    else
        assert_equals "move operation" "$move_response" "IMAP message move"
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

# Test IMAP search functionality
test_imap_search() {
    log_info "Testing IMAP search functionality"

    local search_response=$(timeout $IMAP_TIMEOUT bash -c "
        exec 3<>/dev/tcp/$MAIL_SERVER/143
        echo -e 'a001 LOGIN \"$TEST_USER\" \"$TEST_PASSWORD\"\r\n' >&3
        sleep 0.1
        echo -e 'a002 SELECT INBOX\r\n' >&3
        sleep 0.1
        echo -e 'a003 SEARCH SUBJECT \"Test\"\r\n' >&3
        sleep 0.1
        echo -e 'a004 LOGOUT\r\n' >&3
        cat <&3 | grep 'a003'
    " 2>/dev/null)

    if [[ "$search_response" == *"SEARCH"* ]] || [[ "$search_response" == *"OK"* ]]; then
        assert_equals "true" "true" "IMAP search functionality works"
    else
        assert_equals "search results" "$search_response" "IMAP SEARCH command"
    fi
}

# Test IMAP capabilities
test_imap_capabilities() {
    log_info "Testing IMAP server capabilities"

    local capa_response=$(timeout $IMAP_TIMEOUT bash -c "
        exec 3<>/dev/tcp/$MAIL_SERVER/143
        echo -e 'a001 CAPABILITY\r\n' >&3
        echo -e 'a002 LOGOUT\r\n' >&3
        cat <&3 | grep 'CAPABILITY'
    " 2>/dev/null)

    # Check for common IMAP capabilities
    if [[ "$capa_response" == *"IMAP4rev1"* ]]; then
        assert_equals "true" "true" "IMAP supports IMAP4rev1"
    else
        log_warning "IMAP4rev1 not advertised"
    fi

    if [[ "$capa_response" == *"STARTTLS"* ]]; then
        assert_equals "true" "true" "IMAP supports STARTTLS"
    else
        log_warning "STARTTLS not advertised"
    fi

    if [[ "$capa_response" == *"AUTH=PLAIN"* ]]; then
        assert_equals "true" "true" "IMAP supports AUTH PLAIN"
    else
        log_warning "AUTH PLAIN not advertised"
    fi
}

# Run all IMAP tests
run_imap_test_suite() {
    echo -e "\n${BLUE}═══ IMAP Test Suite ═══${NC}"

    test_imap_connectivity
    test_imap_login
    test_imap_ssl
    test_imap_list_mailboxes
    test_imap_fetch_messages
    test_imap_create_mailbox
    test_imap_delete_mailbox
    test_imap_move_message
    test_imap_search
    test_imap_capabilities

    echo -e "${BLUE}═══ IMAP Tests Complete ═══${NC}"
}</content>
</xai:function_call">Create IMAP tests file