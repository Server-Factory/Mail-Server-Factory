# ISO Manager Test Suite

Comprehensive testing infrastructure for the ISO Manager download system with enterprise-grade resilience features.

## Overview

This test suite validates the ISO Manager's ability to reliably download large ISO files over unreliable network connections with features like:

- ✅ **Resume Capability** - Continue interrupted downloads
- ✅ **Corruption Detection** - Verify partial and complete files
- ✅ **Stall Detection** - Abort hung downloads and retry
- ✅ **Connection Health** - Pre-download connectivity checks
- ✅ **Progress Monitoring** - Track download speed and progress
- ✅ **Exponential Backoff** - Smart retry delays with jitter
- ✅ **Checksum Verification** - SHA256/SHA512/MD5 validation

## Test Structure

```
tests/iso_manager/
├── run_all_tests.sh                  # Master test runner
├── test_iso_manager_unit.sh          # Unit tests (12 tests)
├── test_iso_manager_integration.sh   # Integration tests (8 tests)
├── test_iso_manager_e2e.sh           # End-to-end tests (11 tests)
├── test_iso_manager_automation.sh    # Automation tests (13 tests)
├── results/                          # Test reports and logs
│   ├── test_report_YYYYMMDD_HHMMSS.md
│   ├── test_report_YYYYMMDD_HHMMSS.json
│   └── *.log                         # Individual test logs
└── README.md                         # This file
```

## Test Categories

### 1. Unit Tests (`test_iso_manager_unit.sh`)

Tests individual functions in isolation with mocked dependencies.

**Coverage:**
- `create_directories()` - Directory structure initialization
- `get_remote_file_size()` - Remote file size detection
- `check_partial_file_validity()` - Partial file validation
  - No partial file
  - Oversized partial (corrupted)
  - Valid partial for resume
- `cleanup_corrupted_partial()` - Corrupted file cleanup and backup
- `extract_checksum()` - Checksum extraction from files
  - Ubuntu format (multiple ISOs)
  - Single file format
- `verify_checksum()` - Checksum verification
  - Successful verification
  - Failed verification
- `verify_connection_health()` - Connection health checks
  - Successful connection
  - Failed connection

**Run:**
```bash
./test_iso_manager_unit.sh
```

**Expected:** 12/12 tests pass (some may skip if network unavailable)

### 2. Integration Tests (`test_iso_manager_integration.sh`)

Tests complete workflows and interactions between components using a local mock HTTP server.

**Coverage:**
- Complete download and verification workflow
- Resume interrupted downloads (50%, 90%)
- Corrupted partial file detection and cleanup
- Retry on connection failure
- Checksum verification end-to-end
- Parallel downloads (concurrency test)
- Connection health checks with real URLs
- Progress monitoring during download

**Prerequisites:**
- `python3` (for mock HTTP server)
- `wget` or `curl`
- Network connectivity for some tests

**Run:**
```bash
./test_iso_manager_integration.sh
```

**Expected:** 8/8 tests pass (some may skip if prerequisites missing)

### 3. End-to-End Tests (`test_iso_manager_e2e.sh`)

Tests real-world scenarios with actual downloads from public mirrors.

**Coverage:**
- Download real checksum files from Ubuntu
- ISO Manager CLI commands (help, list, verify)
- Directory creation and initialization
- Connection health checks with real distribution URLs
- Checksum extraction from real files
- Remote file size detection
- Tool availability checks (wget, curl, sha256sum, etc.)

**Network Requirements:**
- Internet connectivity
- Access to Ubuntu/Debian/Fedora mirrors

**Run:**
```bash
./test_iso_manager_e2e.sh
```

**Expected:** 11/11 tests pass (network-dependent)

### 4. Automation Tests (`test_iso_manager_automation.sh`)

Tests resilience against network failures, interruptions, and edge cases.

**Coverage:**

**Resume Scenarios:**
- Resume from 50% completion
- Resume from 90% completion
- Multiple interruptions and resumes
- Oversized partial file detection
- Corrupted partial file handling

**Retry Scenarios:**
- Network timeout retries
- Exponential backoff with jitter
- DNS resolution failures
- Connection health check before retry

**Edge Cases:**
- Zero-byte files
- Very small files (1 byte)
- Concurrent downloads of same file
- Download speed monitoring

**Prerequisites:**
- `python3` (for mock HTTP server)
- `wget`
- `curl`

**Run:**
```bash
./test_iso_manager_automation.sh
```

**Expected:** 13/13 tests pass (some may skip if prerequisites missing)

## Running Tests

### Run All Tests

Execute the master test runner to run all test suites and generate comprehensive reports:

```bash
cd tests/iso_manager
./run_all_tests.sh
```

This will:
1. Run all 4 test suites sequentially
2. Collect results and timing data
3. Generate Markdown report
4. Generate JSON report
5. Display final summary

**Expected Total:** 44 tests (12 unit + 8 integration + 11 e2e + 13 automation)

### Run Individual Test Suites

```bash
# Unit tests only
./test_iso_manager_unit.sh

# Integration tests only
./test_iso_manager_integration.sh

# E2E tests only
./test_iso_manager_e2e.sh

# Automation tests only
./test_iso_manager_automation.sh
```

### Continuous Integration

For CI/CD pipelines:

```bash
# Run with exit code 0 only if all tests pass
./run_all_tests.sh && echo "SUCCESS" || echo "FAILURE"
```

## Test Reports

After running `./run_all_tests.sh`, reports are generated in `results/`:

### Markdown Report

Human-readable report with:
- Executive summary
- Per-suite results with status icons
- Summary statistics table
- Test coverage breakdown
- Links to detailed logs

**Example:** `results/test_report_20251024_153045.md`

### JSON Report

Machine-readable report for automation:

```json
{
  "timestamp": "2025-10-24T15:30:45Z",
  "system": "Linux",
  "hostname": "test-server",
  "test_suites": [
    {
      "name": "Unit Tests",
      "status": "PASSED",
      "duration_seconds": 12,
      "details": "Total: 12, Passed: 12, Failed: 0, Skipped: 0"
    }
  ],
  "summary": {
    "total_suites": 4,
    "passed_suites": 4,
    "failed_suites": 0
  }
}
```

**Example:** `results/test_report_20251024_153045.json`

### Individual Logs

Detailed output for each test suite:
- `Unit_Tests_20251024_153045.log`
- `Integration_Tests_20251024_153045.log`
- `E2E_Tests_20251024_153045.log`
- `Automation_Tests_20251024_153045.log`

## Prerequisites

### Required Tools

- `bash` 4.0+
- `stat` (file size checking)
- `host` (DNS resolution tests)

### Recommended Tools

- `wget` (primary download tool)
- `curl` (fallback download tool)
- `python3` (for mock HTTP server in integration/automation tests)
- `sha256sum` (checksum verification)
- `sha512sum` (alternative checksums)
- `md5sum` (legacy checksums)

### Network Requirements

- **Unit Tests:** No network required (mocked)
- **Integration Tests:** Local network only (mock server)
- **E2E Tests:** Internet connectivity required
- **Automation Tests:** Local network + Internet for some tests

## Expected Success Rate

| Test Suite | Expected Pass Rate | Notes |
|------------|-------------------|-------|
| Unit Tests | 100% | All tests should pass |
| Integration Tests | 95%+ | May skip if tools missing |
| E2E Tests | 90%+ | Network-dependent |
| Automation Tests | 95%+ | Requires python3 |
| **Overall** | **95%+** | **Goal: 100%** |

## Troubleshooting

### Tests Skipped Due to Missing Tools

```bash
# Install wget
sudo apt install wget  # Debian/Ubuntu
sudo yum install wget  # RHEL/CentOS

# Install curl
sudo apt install curl
sudo yum install curl

# Install python3
sudo apt install python3
sudo yum install python3
```

### Network-Dependent Tests Failing

- Check internet connectivity: `ping -c 3 releases.ubuntu.com`
- Verify DNS resolution: `host releases.ubuntu.com`
- Check firewall rules for outbound HTTP/HTTPS

### Mock Server Tests Failing

- Ensure port 8888/8889 is available: `netstat -ln | grep 8888`
- Check python3 availability: `python3 --version`
- Review mock server logs in `results/`

### Permission Issues

```bash
# Make all test scripts executable
chmod +x *.sh
```

## Development

### Adding New Tests

1. **Unit Test:**
   - Add test function to `test_iso_manager_unit.sh`
   - Follow naming: `test_function_name_scenario()`
   - Use assertions: `assert_exit_code`, `assert_file_exists`, `assert_output_contains`

2. **Integration Test:**
   - Add test function to `test_iso_manager_integration.sh`
   - Use mock HTTP server at `http://localhost:8888`
   - Test multi-component interactions

3. **E2E Test:**
   - Add test function to `test_iso_manager_e2e.sh`
   - Use real URLs (prefer stable mirrors)
   - Include skip logic for network failures

4. **Automation Test:**
   - Add test function to `test_iso_manager_automation.sh`
   - Focus on resilience scenarios
   - Simulate failures and recovery

### Test Naming Convention

```bash
test_<component>_<scenario>() {
    print_test_header "Human-readable description"
    # ... test logic ...
}
```

### Assertion Functions

```bash
assert_exit_code <expected> <actual> "description"
assert_file_exists <path> "description"
assert_file_not_exists <path> "description"
assert_output_contains "expected_string" "${output}" "description"
assert_file_size_equals <path> <size> "description"
assert_file_size_greater_than <path> <min_size> "description"
skip_test "reason" "description"
```

## Test Coverage Goals

- **Unit Tests:** 100% function coverage
- **Integration Tests:** All critical workflows
- **E2E Tests:** All public APIs and commands
- **Automation Tests:** All resilience features
- **Overall:** 95%+ code coverage with 100% pass rate

## Related Documentation

- [`../../scripts/iso_manager.sh`](../../scripts/iso_manager.sh) - ISO Manager implementation
- [`../../TESTING.md`](../../TESTING.md) - Project-wide testing documentation
- [`../../CLAUDE.md`](../../CLAUDE.md) - Development guide

## Changelog

### 2025-10-24
- ✅ Initial test suite implementation
- ✅ Unit tests (12 tests)
- ✅ Integration tests (8 tests)
- ✅ E2E tests (11 tests)
- ✅ Automation tests (13 tests)
- ✅ Master test runner
- ✅ Report generation (Markdown + JSON)
- ✅ Comprehensive documentation

## License

Same as Mail Server Factory project.

## Support

For issues or questions:
1. Check test logs in `results/`
2. Review troubleshooting section above
3. Verify prerequisites are installed
4. Check network connectivity for E2E tests
5. Open GitHub issue with test reports attached
