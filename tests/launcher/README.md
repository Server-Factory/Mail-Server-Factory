# Mail Server Factory Launcher Tests

This directory contains comprehensive tests for the `mail_factory` launcher script.

## Test Suite

The test suite (`test_launcher.sh`) validates all aspects of the launcher script including:

### Test Categories

1. **Help and Version Tests**
   - `--help` flag displays usage information
   - `--version` flag displays version information

2. **Argument Validation Tests**
   - No arguments provided (should fail)
   - Missing configuration file (should fail)
   - Invalid JAR path (should fail)

3. **Execution Mode Tests**
   - Dry run mode (`--dry-run`)
   - Debug mode (`--debug`)
   - Normal execution

4. **Configuration Tests**
   - Explicit JAR path (`--jar <path>`)
   - Installation home parameter
   - Multiple arguments forwarding
   - Relative configuration paths
   - Absolute configuration paths

5. **Environment Variable Tests**
   - `JAVA_OPTS` forwarding
   - `JAVA_HOME` detection
   - `MAIL_FACTORY_HOME` JAR location override

6. **File Validation Tests**
   - Configuration file existence
   - Configuration file extension validation
   - JAR file search in multiple locations

## Running the Tests

```bash
# Run all tests
./tests/launcher/test_launcher.sh

# Run with verbose output
bash -x ./tests/launcher/test_launcher.sh
```

## Test Output

The test suite provides colored output:
- 🟢 **Green** - Tests passed
- 🔴 **Red** - Tests failed
- 🟡 **Yellow** - Warnings
- 🔵 **Blue** - Informational messages

### Example Output

```
╔════════════════════════════════════════════════════╗
║  Mail Server Factory Launcher Test Suite          ║
╚════════════════════════════════════════════════════╝

========================================
TEST: Help flag test
========================================
✓ PASS: Help flag returns exit code 0
✓ PASS: Help output contains USAGE
✓ PASS: Help output contains OPTIONS
✓ PASS: Help output contains EXAMPLES

...

╔════════════════════════════════════════════════════╗
║  Test Summary                                       ║
╚════════════════════════════════════════════════════╝
Total tests run:     45
Tests passed:        45
Tests failed:        0

✅ All tests passed!
```

## Mock Services

The `mocks/` directory contains mock files used during testing:

- `mock-application.jar` - Mock JAR file for testing launcher functionality

## Test Environment

Tests are executed in an isolated temporary directory (`test_tmp/`) which is:
- Created at the start of each test run
- Cleaned up after tests complete
- Never committed to version control

## Exit Codes

The test script uses the following exit codes:
- `0` - All tests passed
- `1` - One or more tests failed

## Adding New Tests

To add a new test case:

1. Create a new test function following the naming convention `test_<name>()`
2. Use the assertion functions:
   - `assert_exit_code <expected> <actual> <test_name>`
   - `assert_output_contains <expected> <actual> <test_name>`
3. Add the test function call to the `main()` function
4. Update this README with the new test description

Example:

```bash
test_my_new_feature() {
    print_test_header "My new feature test"

    local output
    output=$("${LAUNCHER}" --my-flag test.json 2>&1)
    local exit_code=$?

    assert_exit_code 0 ${exit_code} "My feature returns exit code 0"
    assert_output_contains "expected text" "${output}" "Output contains expected text"
}
```

## Continuous Integration

These tests should be run:
- Before committing changes to the launcher script
- As part of the CI/CD pipeline
- After any changes to launcher dependencies

## Troubleshooting

### Tests fail with "Java not found"
Ensure Java 17+ is installed and in your PATH, or set `JAVA_HOME`.

### Tests fail with "JAR file not found"
Build the application first:
```bash
./gradlew :Application:install
```

### Tests fail on specific platforms
Some tests may behave differently on different platforms (Linux, macOS, etc.). Verify the test expectations match your platform's behavior.

## Coverage

The test suite aims for 100% code coverage of the launcher script, testing:
- All command-line flags
- All error conditions
- All success paths
- Edge cases and boundary conditions
- Environment variable handling
- File system interactions
