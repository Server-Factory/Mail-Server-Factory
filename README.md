![](Logo.png)

# Mail Server Factory

Version information:

- [Current version](./version.txt)
- [Current version code](./version_code.txt)
- [Releases](https://github.com/milos85vasic/Mail-Server-Factory/releases).

# About the project

Mail Server Factory project has been developed so end user can easily setup and run its own mail server.
End user writes the configuration as simple JSON that is then interpreted and understood by the
Mail Server Factory application. Mail Server Factory base on JSOn configuration performs
installations and initializations on the target operating system.

Mail server stack that is instantiated on the target operating system runs on [Docker](https://www.docker.com/).
Each stack component is loosely coupled which creates a solid base for scalability.

# Compatibility

Mail Server Factory supports the following target operating systems:

- CentOS Server 7 and 8
- Fedora Server versions: 30 to 33
- Fedora Workstation versions: 30 to 33
- Ubuntu Desktop 20

Note: Many other operating systems will be supported in upcoming releases.

# Specifications

Installed mail server will be delivered with the following technology stack:

- [Docker](https://www.docker.com/) for running all stack services containers
- [PostgreSQL](https://www.postgresql.org/) for the main database
- [Dovecot](https://www.dovecot.org/) and [Postfix](http://www.postfix.org/) as the main mail services
- [Rspamd](https://www.rspamd.com/) for the anti-spam service
- [Redis](https://redis.io/) as in-memory database for [Rspamd](https://www.rspamd.com/) service
- [ClamAV](https://www.clamav.net/) for the anti-virus service.

Note: Mail server will use self-signed certificates for encrypting the communication. For this purpose proper CA will be
configured on the server.

# Web setup

```bash

```

# Hot to use

In this section it will be explained how to use Mail Server Factory in order to 
configure and run your own mail server.

# Cloning the project

The following command clones the project and initializes all Git submodules:

```bash
mkdir Factory && cd Factory
git clone git@github.com:milos85vasic/Mail-Server-Factory.git .
git submodule init && git submodule update
```

## Building the project

To build the project cd into the directory where you have cloned the code and execute:

```bash
gradle wrapper
./gradlew assemble
```

Note: To be able to execute [Gradle](https://gradle.org/) commands, [Gradle](https://gradle.org/) must be installed on
your system.

## Running tests

To execute project tests cd into the directory where you have cloned the code and execute:

```bash
./gradlew test
```

Note: In order to be able to pass tests [Docker](https://www.docker.com/) must be installed on your system.

## Git submodules

Complete list of Git submodules used by project can be found [here](./.gitmodules).

# System requirements

Tbd.

## Project development system requirements

Tbd.

## Mail Server Factory system requirements

Tbd.