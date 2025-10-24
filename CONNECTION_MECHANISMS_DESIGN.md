# Connection Mechanisms - Comprehensive Design

**Mail Server Factory - Version 3.1.0**
**Date**: 2025-10-24
**Status**: Design Phase

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Connection Types (12)](#connection-types)
4. [Implementation Plan](#implementation-plan)
5. [JSON Configuration](#json-configuration)
6. [Testing Strategy](#testing-strategy)
7. [Examples](#examples)

---

## Overview

This document describes the design and implementation of **12 connection mechanisms** for Mail Server Factory, extending beyond the current SSH-only approach to support diverse deployment scenarios.

### Goals

- **Flexibility**: Support multiple connection types (SSH, WinRM, Docker, K8s, Cloud)
- **Extensibility**: Easy to add new connection types
- **Security**: Encrypted credentials, audit logging, validation
- **Compatibility**: Works with existing deployment flows
- **Testing**: Comprehensive test coverage (299 host→destination combinations)

### Current Status

**P1 Security Fixes**: 6/8 completed (75%)
- ✅ Connection Pool (Issue #1)
- ✅ Reboot Verification (Issue #2)
- ✅ SELinux Warnings (Issue #7)
- ✅ Docker Credentials (Issue #8)
- ✅ Certificate Validation (Issue #11)
- ✅ Audit Logging (Issue #20)
- ⏳ Firewall Configuration (Issue #10)
- ⏳ SSH Key Passphrases (Issue #19)

---

## Architecture

### Connection Interface Hierarchy

```
Connection (interface)
├── RemoteConnection (abstract)
│   ├── SSHConnection
│   │   ├── SSHKeyAgentConnection
│   │   ├── SSHCertificateConnection
│   │   └── SSHBastionConnection
│   ├── WinRMConnection
│   └── AnsibleConnection
├── ContainerConnection (abstract)
│   ├── DockerConnection
│   └── KubernetesConnection
├── CloudConnection (abstract)
│   ├── AWSSSMConnection
│   ├── AzureSerialConnection
│   └── GCPOSLoginConnection
└── LocalConnection
```

### Core Connection Interface

```kotlin
interface Connection : AutoCloseable {
    /**
     * Establishes connection to remote system.
     */
    fun connect(): ConnectionResult

    /**
     * Checks if connection is active.
     */
    fun isConnected(): Boolean

    /**
     * Executes a command on remote system.
     */
    fun execute(command: String, timeout: Int = 120): ExecutionResult

    /**
     * Uploads a file to remote system.
     */
    fun uploadFile(localPath: String, remotePath: String): TransferResult

    /**
     * Downloads a file from remote system.
     */
    fun downloadFile(remotePath: String, localPath: String): TransferResult

    /**
     * Disconnects from remote system.
     */
    fun disconnect()

    /**
     * Gets connection metadata (type, host, user, etc.).
     */
    fun getMetadata(): ConnectionMetadata

    /**
     * Gets connection health status.
     */
    fun getHealth(): ConnectionHealth
}
```

### Connection Result Types

```kotlin
sealed class ConnectionResult {
    data class Success(val message: String) : ConnectionResult()
    data class Failure(val error: String, val exception: Exception? = null) : ConnectionResult()
}

data class ExecutionResult(
    val success: Boolean,
    val output: String,
    val errorOutput: String = "",
    val exitCode: Int = 0
)

data class TransferResult(
    val success: Boolean,
    val bytesTransferred: Long = 0,
    val message: String = ""
)

data class ConnectionMetadata(
    val type: ConnectionType,
    val host: String,
    val port: Int,
    val username: String,
    val properties: Map<String, String> = emptyMap()
)

data class ConnectionHealth(
    val isHealthy: Boolean,
    val latencyMs: Long,
    val lastChecked: Instant,
    val message: String = ""
)
```

---

## Connection Types

### 1. SSH (Standard) ✅ **EXISTS - ENHANCE**

**Current Implementation**: `SSH.kt`

**Enhancements Needed**:
- Integration with ConnectionPool
- Encrypted credential support
- Input validation
- Audit logging
- Health monitoring

**Configuration**:
```json
{
  "connection": {
    "type": "ssh",
    "host": "mail.example.com",
    "port": 22,
    "username": "root",
    "password": "encrypted:salt:iv:ciphertext",
    "options": {
      "strictHostKeyChecking": "yes",
      "compression": "yes"
    }
  }
}
```

**Use Cases**:
- Standard Linux server deployment
- Traditional infrastructure
- Most common scenario

---

### 2. SSH with Key Agent

**Description**: SSH using SSH agent for key management

**Features**:
- No private key stored in config
- Agent forwarding support
- Multiple key support
- Secure key storage

**Configuration**:
```json
{
  "connection": {
    "type": "ssh_agent",
    "host": "mail.example.com",
    "port": 22,
    "username": "root",
    "agentSocket": "/run/user/1000/keyring/ssh",
    "options": {
      "forwardAgent": true
    }
  }
}
```

**Implementation**:
```kotlin
class SSHKeyAgentConnection(config: ConnectionConfig) : SSHConnection(config) {
    private var agentSocket: String

    override fun connect(): ConnectionResult {
        // Use SSH agent for authentication
        // No password or key file needed
    }
}
```

**Use Cases**:
- Development environments
- CI/CD pipelines
- Multi-hop connections

---

### 3. SSH with Certificate

**Description**: SSH using certificates instead of keys

**Features**:
- Certificate-based authentication
- Short-lived credentials
- Centralized certificate authority
- Enhanced security

**Configuration**:
```json
{
  "connection": {
    "type": "ssh_certificate",
    "host": "mail.example.com",
    "port": 22,
    "username": "root",
    "certificatePath": "/path/to/cert.pub",
    "keyPath": "/path/to/key",
    "caPublicKey": "/path/to/ca.pub"
  }
}
```

**Use Cases**:
- Enterprise environments
- HashiCorp Vault integration
- Temporary access grants

---

### 4. SSH with Bastion/Jump Host

**Description**: SSH through jump host (bastion)

**Features**:
- Multi-hop SSH
- Secure access to private networks
- Jump host chaining
- ProxyJump support

**Configuration**:
```json
{
  "connection": {
    "type": "ssh_bastion",
    "host": "mail-internal.local",
    "port": 22,
    "username": "root",
    "password": "encrypted:...",
    "bastion": {
      "host": "bastion.example.com",
      "port": 22,
      "username": "jumpuser",
      "password": "encrypted:..."
    }
  }
}
```

**Implementation**:
```kotlin
class SSHBastionConnection(config: ConnectionConfig) : SSHConnection(config) {
    private val bastionConfig: ConnectionConfig

    override fun connect(): ConnectionResult {
        // 1. Connect to bastion
        // 2. Open tunnel through bastion
        // 3. Connect to target through tunnel
    }
}
```

**Use Cases**:
- Private cloud deployments
- VPC/VNet environments
- DMZ architectures

---

### 5. WinRM (Windows Remote Management)

**Description**: WinRM for Windows server deployment

**Features**:
- Windows Server support
- PowerShell execution
- NTLM/Kerberos authentication
- HTTPS support

**Configuration**:
```json
{
  "connection": {
    "type": "winrm",
    "host": "mail-win.example.com",
    "port": 5986,
    "username": "Administrator",
    "password": "encrypted:...",
    "options": {
      "transport": "https",
      "authType": "basic",
      "verifySsl": true
    }
  }
}
```

**Implementation**:
```kotlin
class WinRMConnection(config: ConnectionConfig) : RemoteConnection(config) {
    override fun execute(command: String, timeout: Int): ExecutionResult {
        // Execute PowerShell command via WinRM
        // Handle Windows-specific paths and commands
    }
}
```

**Use Cases**:
- Windows Server mail deployments
- Exchange Server automation
- IIS configuration

---

### 6. Ansible

**Description**: Ansible playbook execution

**Features**:
- Inventory-based deployment
- Idempotent operations
- Variable substitution
- Playbook reuse

**Configuration**:
```json
{
  "connection": {
    "type": "ansible",
    "inventory": "/path/to/inventory.yml",
    "playbookPath": "/path/to/playbook.yml",
    "host": "mail.example.com",
    "variables": {
      "mail_domain": "example.com",
      "mail_admin": "admin@example.com"
    }
  }
}
```

**Implementation**:
```kotlin
class AnsibleConnection(config: ConnectionConfig) : RemoteConnection(config) {
    override fun execute(command: String, timeout: Int): ExecutionResult {
        // Convert command to Ansible task
        // Execute via ansible-playbook
        // Return results
    }
}
```

**Use Cases**:
- Infrastructure as Code
- Configuration management
- Existing Ansible infrastructure

---

### 7. Docker

**Description**: Direct Docker container execution

**Features**:
- Container-based deployment
- Docker daemon API
- Image management
- Network configuration

**Configuration**:
```json
{
  "connection": {
    "type": "docker",
    "host": "unix:///var/run/docker.sock",
    "containerName": "mailserver",
    "image": "mailserver:latest",
    "network": "mailnet",
    "volumes": [
      "/data/mail:/var/mail"
    ]
  }
}
```

**Implementation**:
```kotlin
class DockerConnection(config: ConnectionConfig) : ContainerConnection(config) {
    override fun execute(command: String, timeout: Int): ExecutionResult {
        // Execute command inside container
        // docker exec mailserver command
    }
}
```

**Use Cases**:
- Container deployments
- Development environments
- Microservices architectures

---

### 8. Kubernetes

**Description**: Kubernetes pod execution

**Features**:
- kubectl exec
- Pod selection
- Namespace support
- ConfigMap/Secret integration

**Configuration**:
```json
{
  "connection": {
    "type": "kubernetes",
    "kubeconfig": "/path/to/kubeconfig",
    "namespace": "mail",
    "podSelector": "app=mailserver",
    "container": "postfix"
  }
}
```

**Implementation**:
```kotlin
class KubernetesConnection(config: ConnectionConfig) : ContainerConnection(config) {
    override fun execute(command: String, timeout: Int): ExecutionResult {
        // kubectl exec -n namespace pod -c container -- command
    }
}
```

**Use Cases**:
- Kubernetes deployments
- Cloud-native applications
- Multi-cluster setups

---

### 9. AWS SSM (Systems Manager)

**Description**: AWS Systems Manager Session Manager

**Features**:
- No SSH keys needed
- IAM-based authentication
- Session logging
- Port forwarding

**Configuration**:
```json
{
  "connection": {
    "type": "aws_ssm",
    "instanceId": "i-1234567890abcdef0",
    "region": "us-east-1",
    "profile": "default",
    "sessionOptions": {
      "logToS3": true,
      "s3Bucket": "ssm-logs-bucket"
    }
  }
}
```

**Implementation**:
```kotlin
class AWSSSMConnection(config: ConnectionConfig) : CloudConnection(config) {
    override fun execute(command: String, timeout: Int): ExecutionResult {
        // aws ssm start-session --target instanceId
        // Send command via session
    }
}
```

**Use Cases**:
- AWS EC2 instances
- Private subnet instances
- Compliance requirements

---

### 10. Azure VM Serial Console

**Description**: Azure serial console access

**Features**:
- Direct VM access
- No network required
- Boot diagnostics
- Emergency access

**Configuration**:
```json
{
  "connection": {
    "type": "azure_serial",
    "subscriptionId": "...",
    "resourceGroup": "mail-rg",
    "vmName": "mailserver-vm",
    "credentials": {
      "tenantId": "...",
      "clientId": "...",
      "clientSecret": "encrypted:..."
    }
  }
}
```

**Use Cases**:
- Azure VMs
- Network troubleshooting
- Emergency access

---

### 11. GCP OS Login

**Description**: Google Cloud OS Login

**Features**:
- IAM-based SSH
- Temporary keys
- Centralized access control
- Audit logging

**Configuration**:
```json
{
  "connection": {
    "type": "gcp_os_login",
    "project": "my-project",
    "zone": "us-central1-a",
    "instance": "mailserver-instance",
    "serviceAccountKey": "/path/to/key.json"
  }
}
```

**Use Cases**:
- Google Cloud instances
- GKE nodes
- Enterprise GCP

---

### 12. Local

**Description**: Local machine execution (no remote connection)

**Features**:
- Direct command execution
- File operations
- Testing/development
- Local deployments

**Configuration**:
```json
{
  "connection": {
    "type": "local",
    "workingDirectory": "/opt/mailserver",
    "user": "mailuser"
  }
}
```

**Implementation**:
```kotlin
class LocalConnection(config: ConnectionConfig) : Connection {
    override fun execute(command: String, timeout: Int): ExecutionResult {
        // Execute locally using ProcessBuilder
        val process = ProcessBuilder(*command.split(" ").toTypedArray())
            .directory(File(workingDirectory))
            .start()
        // Capture output and return
    }
}
```

**Use Cases**:
- Development/testing
- Single-machine deployments
- CI/CD build agents

---

## Implementation Plan

### Phase 1: Core Infrastructure (Week 1)

**Tasks**:
1. ✅ Define Connection interface
2. ✅ Create base classes (RemoteConnection, ContainerConnection, CloudConnection)
3. Create ConnectionFactory for type selection
4. Implement ConnectionConfig parsing
5. Add validation for all connection types

**Deliverables**:
- Connection interface and base classes
- ConnectionFactory
- Configuration schema

### Phase 2: SSH Variants (Week 2)

**Tasks**:
1. Enhance existing SSHConnection
2. Implement SSHKeyAgentConnection
3. Implement SSHCertificateConnection
4. Implement SSHBastionConnection
5. Write unit tests (20 tests per type)

**Deliverables**:
- 4 SSH connection types
- 80 unit tests
- Examples for each

### Phase 3: Remote Connections (Week 3)

**Tasks**:
1. Implement WinRMConnection
2. Implement AnsibleConnection
3. Write unit tests (20 tests each)
4. Create integration tests

**Deliverables**:
- 2 remote connection types
- 40 unit tests
- 10 integration tests

### Phase 4: Container Connections (Week 4)

**Tasks**:
1. Implement DockerConnection
2. Implement KubernetesConnection
3. Write unit tests (20 tests each)
4. Create container-specific tests

**Deliverables**:
- 2 container connection types
- 40 unit tests
- Container examples

### Phase 5: Cloud Connections (Week 5)

**Tasks**:
1. Implement AWSSSMConnection
2. Implement AzureSerialConnection
3. Implement GCPOSLoginConnection
4. Write unit tests (20 tests each)

**Deliverables**:
- 3 cloud connection types
- 60 unit tests
- Cloud examples

### Phase 6: Local + Testing (Week 6)

**Tasks**:
1. Implement LocalConnection
2. Write comprehensive integration tests
3. Implement 299 combination tests (13 hosts × 23 destinations)
4. E2E tests with AI QA

**Deliverables**:
- LocalConnection
- 299 combination tests
- E2E test suite
- AI QA integration

### Phase 7: Documentation (Week 7)

**Tasks**:
1. Update all documentation
2. Update manuals and books
3. Update Website
4. Translate to all 29 languages

**Deliverables**:
- Complete documentation
- Updated Website
- All translations

---

## JSON Configuration

### Universal Connection Format

```json
{
  "server": {
    "connection": {
      "type": "ssh|ssh_agent|ssh_certificate|ssh_bastion|winrm|ansible|docker|kubernetes|aws_ssm|azure_serial|gcp_os_login|local",
      "host": "hostname or IP",
      "port": 22,
      "credentials": {
        "username": "user",
        "password": "encrypted:...",
        "keyPath": "/path/to/key",
        "certificatePath": "/path/to/cert"
      },
      "options": {
        "timeout": 300,
        "retries": 3,
        "healthCheck": true
      }
    }
  }
}
```

### Connection Type Detection

```kotlin
fun createConnection(config: ConnectionConfig): Connection {
    return when (config.type) {
        ConnectionType.SSH -> SSHConnection(config)
        ConnectionType.SSH_AGENT -> SSHKeyAgentConnection(config)
        ConnectionType.SSH_CERTIFICATE -> SSHCertificateConnection(config)
        ConnectionType.SSH_BASTION -> SSHBastionConnection(config)
        ConnectionType.WINRM -> WinRMConnection(config)
        ConnectionType.ANSIBLE -> AnsibleConnection(config)
        ConnectionType.DOCKER -> DockerConnection(config)
        ConnectionType.KUBERNETES -> KubernetesConnection(config)
        ConnectionType.AWS_SSM -> AWSSSMConnection(config)
        ConnectionType.AZURE_SERIAL -> AzureSerialConnection(config)
        ConnectionType.GCP_OS_LOGIN -> GCPOSLoginConnection(config)
        ConnectionType.LOCAL -> LocalConnection(config)
    }
}
```

---

## Testing Strategy

### Unit Tests: 240+ tests (20 per type × 12 types)

**Per Connection Type**:
- Connection establishment (success/failure)
- Command execution (simple/complex)
- File upload/download
- Health checking
- Error handling
- Timeout handling
- Credential validation
- Configuration parsing

### Integration Tests: 50+ tests

**Scenarios**:
- End-to-end deployment flows
- Multi-connection workflows
- Connection failover
- Connection pooling
- Error recovery

### Full Automation Tests: 299 combinations

**Matrix**:
- 13 host OS (desktop) × 23 destination OS (server)
- All connection types where applicable
- Complete mail server deployment
- Verification and validation

### E2E Tests with AI QA

**Features**:
- AI-assisted test case generation
- Intelligent failure analysis
- Performance optimization suggestions
- Security vulnerability detection

---

## Examples

### Example 1: Standard SSH

```json
{
  "connection": {
    "type": "ssh",
    "host": "mail.example.com",
    "port": 22,
    "credentials": {
      "username": "root",
      "password": "encrypted:ABC123==:DEF456==:GHI789=="
    }
  }
}
```

### Example 2: SSH with Bastion

```json
{
  "connection": {
    "type": "ssh_bastion",
    "host": "mail-internal.local",
    "port": 22,
    "credentials": {
      "username": "deploy",
      "keyPath": "/home/user/.ssh/id_rsa"
    },
    "bastion": {
      "host": "bastion.example.com",
      "port": 22,
      "credentials": {
        "username": "jump",
        "keyPath": "/home/user/.ssh/bastion_key"
      }
    }
  }
}
```

### Example 3: Docker

```json
{
  "connection": {
    "type": "docker",
    "host": "unix:///var/run/docker.sock",
    "container": "mailserver",
    "image": "mailserver:latest"
  }
}
```

### Example 4: Kubernetes

```json
{
  "connection": {
    "type": "kubernetes",
    "kubeconfig": "~/.kube/config",
    "namespace": "mail-prod",
    "podSelector": "app=postfix",
    "container": "postfix"
  }
}
```

### Example 5: AWS SSM

```json
{
  "connection": {
    "type": "aws_ssm",
    "instanceId": "i-1234567890abcdef0",
    "region": "us-east-1",
    "profile": "production"
  }
}
```

---

## Timeline

| Week | Phase | Tasks | Deliverables |
|------|-------|-------|--------------|
| 1 | Core Infrastructure | Interface, base classes, factory | Foundation |
| 2 | SSH Variants | 4 SSH types, tests, examples | SSH complete |
| 3 | Remote Connections | WinRM, Ansible, tests | Remote complete |
| 4 | Container Connections | Docker, K8s, tests | Containers complete |
| 5 | Cloud Connections | AWS, Azure, GCP, tests | Cloud complete |
| 6 | Local + Testing | Local, 299 tests, E2E | Testing complete |
| 7 | Documentation | Docs, Website, translations | All complete |

**Total**: 7 weeks

---

## Success Criteria

✅ **All 12 connection types implemented**
✅ **240+ unit tests (100% pass rate)**
✅ **50+ integration tests**
✅ **299 full automation tests**
✅ **E2E tests with AI QA**
✅ **Complete documentation**
✅ **Website updated (29 languages)**
✅ **Backward compatible**
✅ **Production-ready**

---

**Document Version**: 1.0
**Last Updated**: 2025-10-24
**Author**: Mail Server Factory Team
**Status**: Design Complete - Ready for Implementation

