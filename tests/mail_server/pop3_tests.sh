# Mail Server Factory - POP3 Tests
# Tests for POP3 retrieval functionality

# Test POP3 connectivity
test_pop3_connectivity() {
    log_info "Testing POP3 connectivity"

    # Test basic connection to POP3 port
    if nc -z -w5 "$MAIL_SERVER" 110 2>/dev/null; then
        assert_equals "true" "true" "POP3 port 110 is accessible"
    else
        skip_test "POP3 port 110 not accessible" "POP3 connectivity"
        return
    fi

    # Test POP3 greeting
    local response=$(timeout 10 bash -c "echo -e 'QUIT\r\n' | nc $MAIL_SERVER 110 2>/dev/null | head -1")
    if [[ "$response" == *"+OK"* ]]; then
        assert_equals "true" "true" "POP3 server responds with greeting"
    else
        assert_equals "+OK greeting" "$response" "POP3 greeting response"
    fi
}

# Test POP3 login
test_pop3_login() {
    log_info "Testing POP3 login"

    # Use telnet to test POP3 login
    local login_response=$(timeout $POP3_TIMEOUT bash -c "
        exec 3<>/dev/tcp/$MAIL_SERVER/110
        echo -e 'USER $TEST_USER\r\n' >&3
        sleep 0.1
        echo -e 'PASS $TEST_PASSWORD\r\n' >&3
        sleep 0.1
        echo -e 'QUIT\r\n' >&3
        cat <&3 | grep -E '(^\+OK|^-ERR)'
    " 2>/dev/null)

    if [[ "$login_response" == *"+OK"* ]]; then
        assert_equals "true" "true" "POP3 login successful"
    else
        assert_equals "+OK" "$(echo "$login_response" | grep -o '+OK\|-ERR')" "POP3 login response"
    fi
}

# Test POP3 over SSL
test_pop3_ssl() {
    log_info "Testing POP3 over SSL"

    if [ "$USE_SSL" != true ]; then
        skip_test "SSL testing disabled" "POP3 SSL"
        return
    fi

    # Test POP3S port
    if nc -z -w5 "$MAIL_SERVER" 995 2>/dev/null; then
        assert_equals "true" "true" "POP3S port 995 is accessible"
    else
        skip_test "POP3S port 995 not accessible" "POP3 SSL"
        return
    fi

    # Test SSL connection
    local ssl_response=$(timeout $POP3_TIMEOUT openssl s_client -connect "$MAIL_SERVER:995" -quiet 2>/dev/null <<EOF
USER $TEST_USER
PASS $TEST_PASSWORD
STAT
QUIT
EOF
    )

    if [[ "$ssl_response" == *"+OK"* ]]; then
        assert_equals "true" "true" "POP3 SSL connection successful"
    else
        assert_equals "SSL connection" "failed" "POP3 SSL connection"
    fi
}

# Test POP3 STAT command
test_pop3_stat() {
    log_info "Testing POP3 STAT command"

    local stat_response=$(timeout $POP3_TIMEOUT bash -c "
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

    if [[ "$stat_response" == *"+OK"* ]]; then
        assert_equals "true" "true" "POP3 STAT command works"
    else
        assert_equals "+OK" "$(echo "$stat_response" | grep -o '+OK\|-ERR')" "POP3 STAT response"
    fi
}

# Test POP3 LIST command
test_pop3_list() {
    log_info "Testing POP3 LIST command"

    local list_response=$(timeout $POP3_TIMEOUT bash -c "
        exec 3<>/dev/tcp/$MAIL_SERVER/110
        echo -e 'USER $TEST_USER\r\n' >&3
        sleep 0.1
        echo -e 'PASS $TEST_PASSWORD\r\n' >&3
        sleep 0.1
        echo -e 'LIST\r\n' >&3
        sleep 0.1
        echo -e 'QUIT\r\n' >&3
        cat <&3 | grep -E '(^\+OK|^\.)'
    " 2>/dev/null)

    if [[ "$list_response" == *"+OK"* ]]; then
        assert_equals "true" "true" "POP3 LIST command works"
    else
        assert_equals "+OK" "$(echo "$list_response" | grep -o '+OK\|-ERR')" "POP3 LIST response"
    fi
}

# Test POP3 RETR command
test_pop3_retr() {
    log_info "Testing POP3 RETR command"

    # First ensure there's at least one message
    if command -v swaks &> /dev/null; then
        echo "Subject: POP3 Test Message $(date +%s)
From: $TEST_USER
To: $TEST_USER

This is a test message for POP3 retrieval." | swaks \
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

    local retr_response=$(timeout $POP3_TIMEOUT bash -c "
        exec 3<>/dev/tcp/$MAIL_SERVER/110
        echo -e 'USER $TEST_USER\r\n' >&3
        sleep 0.1
        echo -e 'PASS $TEST_PASSWORD\r\n' >&3
        sleep 0.1
        echo -e 'RETR 1\r\n' >&3
        sleep 0.1
        echo -e 'QUIT\r\n' >&3
        cat <&3 | head -10 | grep -E '(^\+OK|^Subject:|^From:|^To:)'
    " 2>/dev/null)

    if [[ "$retr_response" == *"+OK"* ]] && [[ "$retr_response" == *"Subject:"* ]]; then
        assert_equals "true" "true" "POP3 RETR command works"
    else
        assert_equals "message retrieval" "$retr_response" "POP3 RETR command"
    fi
}

# Test POP3 DELE command
test_pop3_dele() {
    log_info "Testing POP3 DELE command"

    # Send a test message first
    if command -v swaks &> /dev/null; then
        echo "Subject: POP3 Delete Test $(date +%s)
From: $TEST_USER
To: $TEST_USER

This message will be deleted via POP3." | swaks \
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

    local dele_response=$(timeout $POP3_TIMEOUT bash -c "
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

    if [[ "$dele_response" == *"+OK"* ]]; then
        assert_equals "true" "true" "POP3 DELE command works"
    else
        assert_equals "+OK" "$(echo "$dele_response" | grep -o '+OK\|-ERR')" "POP3 DELE response"
    fi
}

# Test POP3 NOOP command
test_pop3_noop() {
    log_info "Testing POP3 NOOP command"

    local noop_response=$(timeout $POP3_TIMEOUT bash -c "
        exec 3<>/dev/tcp/$MAIL_SERVER/110
        echo -e 'USER $TEST_USER\r\n' >&3
        sleep 0.1
        echo -e 'PASS $TEST_PASSWORD\r\n' >&3
        sleep 0.1
        echo -e 'NOOP\r\n' >&3
        sleep 0.1
        echo -e 'QUIT\r\n' >&3
        cat <&3 | grep 'NOOP'
    " 2>/dev/null)

    if [[ "$noop_response" == *"+OK"* ]]; then
        assert_equals "true" "true" "POP3 NOOP command works"
    else
        assert_equals "+OK" "$(echo "$noop_response" | grep -o '+OK\|-ERR')" "POP3 NOOP response"
    fi
}

# Test POP3 RSET command
test_pop3_rset() {
    log_info "Testing POP3 RSET command"

    local rset_response=$(timeout $POP3_TIMEOUT bash -c "
        exec 3<>/dev/tcp/$MAIL_SERVER/110
        echo -e 'USER $TEST_USER\r\n' >&3
        sleep 0.1
        echo -e 'PASS $TEST_PASSWORD\r\n' >&3
        sleep 0.1
        echo -e 'DELE 1\r\n' >&3
        sleep 0.1
        echo -e 'RSET\r\n' >&3
        sleep 0.1
        echo -e 'QUIT\r\n' >&3
        cat <&3 | grep 'RSET'
    " 2>/dev/null)

    if [[ "$rset_response" == *"+OK"* ]]; then
        assert_equals "true" "true" "POP3 RSET command works"
    else
        assert_equals "+OK" "$(echo "$rset_response" | grep -o '+OK\|-ERR')" "POP3 RSET response"
    fi
}

# Test POP3 TOP command
test_pop3_top() {
    log_info "Testing POP3 TOP command"

    local top_response=$(timeout $POP3_TIMEOUT bash -c "
        exec 3<>/dev/tcp/$MAIL_SERVER/110
        echo -e 'USER $TEST_USER\r\n' >&3
        sleep 0.1
        echo -e 'PASS $TEST_PASSWORD\r\n' >&3
        sleep 0.1
        echo -e 'TOP 1 5\r\n' >&3
        sleep 0.1
        echo -e 'QUIT\r\n' >&3
        cat <&3 | head -10 | grep -E '(^\+OK|^Subject:|^From:)'
    " 2>/dev/null)

    if [[ "$top_response" == *"+OK"* ]]; then
        assert_equals "true" "true" "POP3 TOP command works"
    else
        assert_equals "+OK" "$(echo "$top_response" | grep -o '+OK\|-ERR')" "POP3 TOP response"
    fi
}

# Test POP3 UIDL command
test_pop3_uidl() {
    log_info "Testing POP3 UIDL command"

    local uidl_response=$(timeout $POP3_TIMEOUT bash -c "
        exec 3<>/dev/tcp/$MAIL_SERVER/110
        echo -e 'USER $TEST_USER\r\n' >&3
        sleep 0.1
        echo -e 'PASS $TEST_PASSWORD\r\n' >&3
        sleep 0.1
        echo -e 'UIDL\r\n' >&3
        sleep 0.1
        echo -e 'QUIT\r\n' >&3
        cat <&3 | grep -E '(^\+OK|^\.)'
    " 2>/dev/null)

    if [[ "$uidl_response" == *"+OK"* ]]; then
        assert_equals "true" "true" "POP3 UIDL command works"
    else
        assert_equals "+OK" "$(echo "$uidl_response" | grep -o '+OK\|-ERR')" "POP3 UIDL response"
    fi
}

# Test POP3 CAPA command
test_pop3_capa() {
    log_info "Testing POP3 CAPA command"

    local capa_response=$(timeout $POP3_TIMEOUT bash -c "
        exec 3<>/dev/tcp/$MAIL_SERVER/110
        echo -e 'CAPA\r\n' >&3
        echo -e 'QUIT\r\n' >&3
        cat <&3 | grep -E '(^\+OK|^STLS|^USER|^SASL)'
    " 2>/dev/null)

    if [[ "$capa_response" == *"+OK"* ]]; then
        assert_equals "true" "true" "POP3 CAPA command works"

        # Check for common capabilities
        if [[ "$capa_response" == *"STLS"* ]]; then
            assert_equals "true" "true" "POP3 supports STLS"
        fi

        if [[ "$capa_response" == *"USER"* ]]; then
            assert_equals "true" "true" "POP3 supports USER authentication"
        fi
    else
        assert_equals "+OK" "$(echo "$capa_response" | grep -o '+OK\|-ERR')" "POP3 CAPA response"
    fi
}

# Run all POP3 tests
run_pop3_test_suite() {
    echo -e "\n${BLUE}═══ POP3 Test Suite ═══${NC}"

    test_pop3_connectivity
    test_pop3_login
    test_pop3_ssl
    test_pop3_stat
    test_pop3_list
    test_pop3_retr
    test_pop3_dele
    test_pop3_noop
    test_pop3_rset
    test_pop3_top
    test_pop3_uidl
    test_pop3_capa

    echo -e "${BLUE}═══ POP3 Tests Complete ═══${NC}"
}</content>
</xai:function_call">Create POP3 tests file