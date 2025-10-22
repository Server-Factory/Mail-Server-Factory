# Mail Server Factory - Development Guidelines

## Build & Test Commands
- **Build project**: `./gradlew assemble`
- **Run all tests**: `./gradlew test` (requires Docker)
- **Run comprehensive tests**: `./gradlew allTests` (includes SonarQube)
- **Test single class**: `./gradlew test --tests "ClassName"`
- **Test single method**: `./gradlew test --tests "ClassName.methodName"`
- **Test specific module**: `./gradlew :ModuleName:test`
- **Generate coverage**: `./gradlew test jacocoTestReport`
- **Quality analysis**: `./sonar-analysis.sh`
- **Run application**: `./mail_factory Examples/Distribution.json`
- **Test ISO downloads**: `scripts/iso_manager.sh download`
- **Verify ISOs**: `scripts/iso_manager.sh verify`

## Code Style Guidelines
- **Language**: Kotlin 2.0.21 targeting Java 17
- **Naming**: PascalCase classes, camelCase methods/properties
- **Imports**: One per line, alphabetically organized
- **Formatting**: 4-space indentation, blank lines between methods
- **Null safety**: Use `?`, `let`, Elvis operator (`?:`)
- **Error handling**: `@Throws` annotations for exceptions
- **Testing**: JUnit 5 with `@DisplayName`, Given/When/Then structure
- **Types**: Explicit types preferred, avoid `var` when possible

## Quality Standards
- **SonarQube Quality Gate**: Must pass 100% (no issues allowed)
- **Test Coverage**: Minimum 80% overall coverage required
- **Code Smells**: Zero tolerance - all must be fixed
- **Security Vulnerabilities**: Zero tolerance - all must be fixed
- **Bugs**: Zero tolerance - all must be fixed

## ISO Download Improvements
- **Retry Logic**: Automatic retry with exponential backoff (5 retries max)
- **Timeouts**: Configurable timeouts (30s-600s) with proper error handling
- **Tool Support**: Compatible with both `wget` and `curl`
- **Progress Tracking**: Detailed logging with timestamps and status
- **Error Handling**: Graceful degradation with user-friendly messages

## Website Features
- **Multi-language Support**: 29 languages with automatic detection
- **Responsive Design**: Mobile-first approach with logo-based color scheme
- **Language Selector**: Country flags with native language names
- **RTL Support**: Arabic, Persian, Hebrew right-to-left text direction

## Important Notes
- **Docker required** for running tests
- **Git submodules** must be initialized: `git submodule update --init --recursive`
- **Configuration variables** use `${CONTEXT.SUBCONTEXT.KEY}` syntax
- **Mail accounts** require valid email format and MEDIUM password strength
- **Always run tests** before committing: `./gradlew test`
- **ISO downloads** continue with available files if some downloads fail

## Module Structure
- `Application` - Main executable JAR
- `Factory` - Mail server implementation
- `Core/Framework` - Generic server factory framework
- `Logger` - Logging framework