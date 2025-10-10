![](Logo.png)

# Mail Server Factory

Version information:

- [Current version](./version.txt)
- [Current version code](./version_code.txt)
- [Releases](https://github.com/Server-Factory/Mail-Server-Factory/releases).

# About the project

The purpose of the Mail Server Factory project is to provide a simple way for the end-user to easily set up and run its
mail server. The end-user writes the configuration as a simple JSON which is then interpreted and understood by the Mail
Server Factory. Mail Server Factory performs various installations and initializations based on this JSON on the target
operating system. Mail server stack that is deployed on the target operating system runs
on [Docker](https://www.docker.com/). Each stack component is loosely coupled which creates a solid base for further /
future scalability.

# System requirements

To be able to run Mail Server Factory the following system requirements must meet:

- Modern computer (or server) as a hardware
- [OpenJDK](https://openjdk.java.net/)
- [Gradle](https://gradle.org/) build system

# Compatibility

Mail Server Factory supports the following target operating systems:

- CentOS Server 7 and 8
- Fedora Server versions: 30 to 34
- Fedora Workstation versions: 30 to 34
- Ubuntu Desktop 20 and 21

*Note:* Many other operating systems will be supported in upcoming releases.

## SeLinux

The current version of Mail Server Factory does not support SELinux enforcing.

# Specifications

Installed mail server will be delivered with the following technology stack:

- [Docker](https://www.docker.com/) for running all stack services containers
- [PostgreSQL](https://www.postgresql.org/) for the main database
- [Dovecot](https://www.dovecot.org/) and [Postfix](http://www.postfix.org/) as the main mail services
- [Rspamd](https://www.rspamd.com/) for the anti-spam service
- [Redis](https://redis.io/) as in-memory database for [Rspamd](https://www.rspamd.com/) service
- [ClamAV](https://www.clamav.net/) for the anti-virus service.

*Note:* The mail server will use self-signed certificates for encrypting the communication. For this purpose proper CA
will be configured on the server.

# Web setup

Simply execute the following command:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Server-Factory/Utils/master/web_installer.sh)"
```

Mail Server Factory will be downloaded and installed.

# Hot to use

[Examples](./Examples) directory contains examples of JSON configuration(s) for Mail Server Factory deployment(s).
Detailed explanations for every configuration variable will be provided in upcoming releases.

To be able to try and run examples it is required to follow instructions
from [Includes Readme](./Examples/Includes/README.md) file.

To run Mail Server Factory simply execute the program and pass to it path to the configuration JSON file.
For Instance:

```bash
mail_factory Examples/Centos_8.json
```

or (if you are using Java .jar):

```bash
java -jar Application/build/libs/Application.jar Examples/Centos_8.json
```

The current version of Mail Server Factory performs SSH access to target hosts using keys. For enabling SSH access using
keys the [following bash script](Core/Utils/init_ssh_access.sh) can be used.

Example of `init_ssh_access.sh` script use:

```bash
sh Core/Utils/init_ssh_access.sh centos7.local
```

A detailed explanation of the script can be found [here](https://github.com/Server-Factory/Utils) under
"SSH login without password" section.

*Note:* We strongly recommend the clean installation of the server operating system to be used with Mail Server Factory so
there is no conflict of any kind with existing software or services.

## Launcher Script

The `mail_factory` launcher script is a comprehensive bash wrapper that simplifies running the Mail Server Factory application. It handles JAR location discovery, Java detection, argument forwarding, and provides robust error handling.

### Features

- **Automatic JAR Discovery**: Searches multiple standard locations for the Application JAR
- **Java Detection**: Automatically finds Java (via `JAVA_HOME` or `PATH`) and validates version
- **Environment Variable Support**: Honors `JAVA_OPTS`, `JAVA_HOME`, and `MAIL_FACTORY_HOME`
- **Parameter Forwarding**: All command-line arguments are properly forwarded to the application
- **Error Handling**: Clear error messages with specific exit codes for different failure scenarios
- **Debug Mode**: Optional verbose output for troubleshooting
- **Dry Run**: Preview the exact command that would be executed without running it

### Usage

Basic syntax:

```bash
mail_factory [options] <configuration-file>
```

### Command-Line Options

| Option | Description |
|--------|-------------|
| `-h, --help` | Show help message with usage information |
| `-v, --version` | Display launcher version information |
| `--debug` | Enable debug output showing Java detection, JAR location, and command details |
| `--dry-run` | Show the command that would be executed without actually running it |
| `--jar <path>` | Explicitly specify the JAR file location |
| `--installation-home=<path>` | Set custom installation home directory (forwarded to application) |

### Environment Variables

| Variable | Description |
|----------|-------------|
| `JAVA_HOME` | Java installation directory (e.g., `/usr/lib/jvm/java-17-openjdk`) |
| `JAVA_OPTS` | Additional JVM options (e.g., `-Xmx4g -Xms512m` for memory settings) |
| `MAIL_FACTORY_HOME` | Override the default JAR search location |

### Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Success |
| `1` | General error |
| `2` | Java not found or incompatible version |
| `3` | JAR file not found in any search location |
| `4` | Invalid arguments (no configuration file provided) |
| `5` | Configuration file not found |

### Examples

**Basic usage:**
```bash
mail_factory Examples/Centos_8.json
```

**With custom JVM memory settings:**
```bash
JAVA_OPTS="-Xmx4g -Xms512m" mail_factory Examples/Centos_8.json
```

**With custom installation home:**
```bash
mail_factory --installation-home=/custom/path Examples/Centos_8.json
```

**Preview command without execution:**
```bash
mail_factory --dry-run Examples/Centos_8.json
```

**Debug mode for troubleshooting:**
```bash
mail_factory --debug Examples/Centos_8.json
```

**Using explicit JAR location:**
```bash
mail_factory --jar /path/to/custom/Application.jar Examples/Centos_8.json
```

### JAR Search Locations

The launcher searches for `Application.jar` in the following locations (in order):

1. `${MAIL_FACTORY_HOME}/Application.jar`
2. `${SCRIPT_DIR}/Application/build/libs/Application.jar`
3. `${SCRIPT_DIR}/build/libs/Application.jar`
4. `${SCRIPT_DIR}/Release/Application.jar`
5. `${SCRIPT_DIR}/Application.jar`
6. `/usr/local/lib/mail-factory/Application.jar`
7. `/opt/mail-factory/Application.jar`

If the JAR is not found in any location, the launcher will display all searched paths and suggest building the application.

### Testing the Launcher

A comprehensive test suite is available at `tests/launcher/test_launcher.sh`:

```bash
# Run all launcher tests
./tests/launcher/test_launcher.sh
```

The test suite validates:
- Help and version flags
- Argument validation and error handling
- Dry run and debug modes
- Environment variable support
- JAR discovery and explicit JAR paths
- Configuration file validation
- Parameter forwarding

See [tests/launcher/README.md](tests/launcher/README.md) for detailed testing documentation.

## Using installed mail server

After the mail server is installed execute the following command on your server to see the list 
of running Docker containers:

```bash
docker ps -a
```

The list will contain the following services:

- postmaster_receive, ports: 3993/tcp, 0.0.0.0:3993->993/tcp
- postmaster_send, ports: 0.0.0.0:465->465/tcp
- postmaster_antispam, 11332-11333/tcp, 127.0.0.1:11334->11334/tcp
- postmaster_antivirus, no ports
- postmaster_mem_db, ports: 127.0.0.1:36379->6379/tcp
- postmaster_db, 127.0.0.1:35432->5432/tcp

Example configuration for one of the installed email accounts on the [Mozilla Thunderbird](https://www.thunderbird.net/en-US/) client:

![](Documentation/Thunderbird.png)

*Note:* Pay attention to custom port number.

Once configuration is filled in the form, you must accept TLS certificate:

![](Documentation/Thunderbird_Certificate.png)

## Mail Server Factory in action

Tbd. (YouTube video)

# Cloning the project

To be able to read project source code or contribute it is required to clone the Git repository. The following command
clones the project and initializes all Git submodules:

```bash
mkdir Factory && cd Factory
git clone --recurse-submodules git@github.com:Server-Factory/Mail-Server-Factory.git .
```

## Building the project

To build the project cd into the directory where you have cloned the code and execute:

```bash
./gradlew assemble
```

*Note:* The project uses Gradle 8.14.3 via the Gradle wrapper. Java 17 or higher is required.

## Running tests

To execute project tests cd into the directory where you have cloned the code and execute:

```bash
./gradlew test
```

*Note:* To be able to pass tests [Docker](https://www.docker.com/) must be installed on your system.

## Test Coverage

To generate test coverage reports:

```bash
./gradlew jacocoTestReport
```

Coverage reports are generated in HTML, XML, and CSV formats at:
- HTML: `Core/Framework/build/reports/jacoco/test/html/index.html`
- XML: `Core/Framework/build/reports/jacoco/test/jacocoTestReport.xml`
- CSV: `Core/Framework/build/reports/jacoco/test/jacocoTestReport.csv`

## Git submodules

A complete list of Git submodules used by the project can be found [here](./.gitmodules).