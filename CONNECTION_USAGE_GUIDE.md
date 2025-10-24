# Connection Mechanisms - Usage Guide

**Mail Server Factory - Version 3.1.0**
**Date**: 2025-10-24

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Connection Types Overview](#connection-types-overview)
3. [Configuration Guide](#configuration-guide)
4. [Code Examples](#code-examples)
5. [Security Best Practices](#security-best-practices)
6. [Troubleshooting](#troubleshooting)
7. [Migration Guide](#migration-guide)

---

## Quick Start

### Basic Usage (Kotlin)

```kotlin
import net.milosvasic.factory.connection.*

// Create configuration
val config = ConnectionConfigBuilder()
    .type(ConnectionType.SSH)
    .host("mail.example.com")
    .port(22)
    .credentials(Credentials("mailserver", password = "encrypted:..."))
    .build()

// Create connection via factory
val connection = ConnectionFactory.createConnection(config)

// Connect
val result = connection.connect()
if (result.isSuccess()) {
    // Execute commands
    val execResult = connection.execute("apt-get update")

    // Upload files
    connection.uploadFile("/local/config.txt", "/remote/config.txt")

    // Download files
    connection.downloadFile("/remote/logs.txt", "/local/logs.txt")

    // Disconnect
    connection.disconnect()
}
```

### Quick Connection Methods

```kotlin
// SSH connection (convenience method)
val sshConnection = ConnectionFactory.createSSHConnection(
    host = "mail.example.com",
    port = 22,
    username = "mailserver",
    password = "encrypted:..."
)

// Local connection
val localConnection = ConnectionFactory.createLocalConnection(
    workingDirectory = "/opt/deployment"
)

// Docker connection
val dockerConnection = ConnectionFactory.createDockerConnection(
    containerName = "mail-server",
    dockerHost = "unix:///var/run/docker.sock"
)
```

---

## Connection Types Overview

| Type | Protocol | Use Case | Complexity |
|------|----------|----------|------------|
| **SSH** | SSH | Standard remote servers | ⭐ Easy |
| **SSH Agent** | SSH + Agent | Multi-hop, key management | ⭐⭐ Medium |
| **SSH Certificate** | SSH + Cert | Enterprise PKI | ⭐⭐⭐ Advanced |
| **SSH Bastion** | SSH + Jump | Private networks | ⭐⭐ Medium |
| **WinRM** | WinRM | Windows servers | ⭐⭐ Medium |
| **Ansible** | SSH + Ansible | Multi-server automation | ⭐⭐⭐ Advanced |
| **Docker** | Docker API | Container deployments | ⭐ Easy |
| **Kubernetes** | kubectl | Cloud-native apps | ⭐⭐⭐ Advanced |
| **AWS SSM** | AWS CLI | EC2 instances | ⭐⭐ Medium |
| **Azure Serial** | Azure CLI | Azure VMs | ⭐⭐ Medium |
| **GCP OS Login** | gcloud | GCE instances | ⭐⭐ Medium |
| **Local** | Process | Same machine | ⭐ Easy |

---

## Configuration Guide

### 1. SSH Connection (Standard)

**When to use**: Most common scenario - remote Linux servers

**Configuration**:
```kotlin
val config = ConnectionConfigBuilder()
    .type(ConnectionType.SSH)
    .host("mail.example.com")
    .port(22)
    .credentials(Credentials(
        username = "mailserver",
        password = "encrypted:AES256:IV:salt:pass"  // Or keyPath for SSH key
    ))
    .options(ConnectionOptions(
        timeout = 120,
        retries = 3,
        strictHostKeyChecking = true
    ))
    .build()
```

**Requirements**:
- SSH server running on target
- Network connectivity
- Valid credentials

---

### 2. SSH Agent

**When to use**: Multiple servers, centralized key management

**Configuration**:
```kotlin
val config = ConnectionConfigBuilder()
    .type(ConnectionType.SSH_AGENT)
    .host("mail.example.com")
    .port(22)
    .credentials(Credentials(
        username = "mailserver",
        agentSocket = System.getenv("SSH_AUTH_SOCK")  // Auto-detected
    ))
    .build()
```

**Setup**:
```bash
# Start SSH agent
eval $(ssh-agent -s)

# Add your key
ssh-add ~/.ssh/mailserver_key

# Verify
ssh-add -l
```

---

### 3. SSH Certificate

**When to use**: Enterprise environments with PKI

**Configuration**:
```kotlin
val config = ConnectionConfigBuilder()
    .type(ConnectionType.SSH_CERTIFICATE)
    .host("mail.example.com")
    .port(22)
    .credentials(Credentials(
        username = "mailserver",
        keyPath = "/path/to/private_key",
        certificatePath = "/path/to/certificate.pub"
    ))
    .build()
```

**Setup**:
```bash
# Generate CA key
ssh-keygen -t rsa -b 4096 -f ca_key

# Generate user key
ssh-keygen -t rsa -b 4096 -f user_key

# Sign certificate (valid for 52 weeks)
ssh-keygen -s ca_key -I mailserver_admin -n mailserver -V +52w user_key.pub

# On server: /etc/ssh/sshd_config
TrustedUserCAKeys /etc/ssh/ca_key.pub
```

---

### 4. SSH Bastion (Jump Host)

**When to use**: Private networks, DMZ, security-hardened environments

**Configuration**:
```kotlin
// Configure bastion host
val bastionConfig = ConnectionConfigBuilder()
    .type(ConnectionType.SSH)
    .host("bastion.example.com")
    .port(22)
    .credentials(Credentials("bastion-user", keyPath = "/path/to/bastion_key"))
    .build()

// Configure target with bastion
val config = ConnectionConfigBuilder()
    .type(ConnectionType.SSH_BASTION)
    .host("mail-internal.local")
    .port(22)
    .credentials(Credentials("mailserver", password = "encrypted:..."))
    .bastionConfig(bastionConfig)
    .build()
```

**Architecture**:
```
[Your Machine] → [Bastion Host] → [Internal Mail Server]
```

---

### 5. WinRM

**When to use**: Windows Server deployments

**Configuration**:
```kotlin
val config = ConnectionConfigBuilder()
    .type(ConnectionType.WINRM)
    .host("windows-mail.example.com")
    .port(5985)  // 5986 for HTTPS
    .credentials(Credentials("Administrator", password = "encrypted:..."))
    .options(ConnectionOptions(properties = mapOf(
        "useHttps" to "false",
        "authType" to "NTLM"
    )))
    .build()
```

**Windows Setup**:
```powershell
# Enable WinRM
winrm quickconfig

# Configure authentication
winrm set winrm/config/service/auth @{Basic="true"}

# Allow unencrypted (dev only!)
winrm set winrm/config/service @{AllowUnencrypted="true"}
```

---

### 6. Ansible

**When to use**: Multi-server deployments, infrastructure as code

**Configuration**:
```kotlin
val config = ConnectionConfigBuilder()
    .type(ConnectionType.ANSIBLE)
    .host("mail-servers")  // Inventory group
    .port(22)
    .credentials(Credentials("ansible", keyPath = "/path/to/ansible_key"))
    .options(ConnectionOptions(properties = mapOf(
        "inventoryPath" to "/etc/ansible/hosts",
        "playbookDir" to "/opt/ansible/playbooks",
        "extraVars" to "env=production mail_domain=example.com"
    )))
    .build()
```

**Execute Playbook**:
```kotlin
val connection = ConnectionFactory.createConnection(config) as AnsibleConnectionImpl
connection.connect()

val result = connection.executePlaybook(
    playbookPath = "/opt/ansible/playbooks/deploy-mail.yml",
    extraVars = mapOf("mail_domain" to "example.com")
)
```

---

### 7. Docker

**When to use**: Containerized deployments, local development

**Configuration**:
```kotlin
val config = ConnectionConfigBuilder()
    .type(ConnectionType.DOCKER)
    .host("unix:///var/run/docker.sock")
    .port(0)
    .containerConfig(ContainerConfig(
        containerType = ContainerType.DOCKER,
        containerName = "mail-server",
        dockerHost = "unix:///var/run/docker.sock"
    ))
    .build()
```

**Additional Operations**:
```kotlin
val dockerConnection = ConnectionFactory.createConnection(config) as DockerConnectionImpl
dockerConnection.connect()

// Check container status
val status = dockerConnection.getContainerStatus()

// Get logs
val logs = dockerConnection.getContainerLogs(tail = 100)

// Start/stop container
dockerConnection.startContainer()
dockerConnection.stopContainer()
```

---

### 8. Kubernetes

**When to use**: Cloud-native deployments, scalable architectures

**Configuration**:
```kotlin
val config = ConnectionConfigBuilder()
    .type(ConnectionType.KUBERNETES)
    .host("k8s-cluster.example.com")
    .port(443)
    .containerConfig(ContainerConfig(
        containerType = ContainerType.KUBERNETES,
        namespace = "mail-production",
        podSelector = "app=mail-server",
        containerInPod = "postfix",  // Optional
        kubeconfig = "/home/user/.kube/config"
    ))
    .build()
```

**Additional Operations**:
```kotlin
val k8sConnection = ConnectionFactory.createConnection(config) as KubernetesConnectionImpl
k8sConnection.connect()

// Get pod logs
val logs = k8sConnection.getPodLogs(tail = 100)
```

---

### 9. AWS SSM

**When to use**: EC2 instances without open SSH ports

**Configuration**:
```kotlin
val config = ConnectionConfigBuilder()
    .type(ConnectionType.AWS_SSM)
    .host("i-1234567890abcdef0")
    .port(0)
    .cloudConfig(CloudConfig(
        provider = CloudProvider.AWS,
        region = "us-east-1",
        instanceId = "i-1234567890abcdef0",
        profile = "mail-production"  // AWS CLI profile
    ))
    .build()
```

**AWS Requirements**:
- AWS CLI installed and configured
- SSM Agent running on EC2 instance
- IAM permissions for SSM
- Instance role with `AmazonSSMManagedInstanceCore`

---

### 10. Azure Serial Console

**When to use**: Emergency VM access, troubleshooting

**Configuration**:
```kotlin
val config = ConnectionConfigBuilder()
    .type(ConnectionType.AZURE_SERIAL)
    .host("mail-vm")
    .port(0)
    .cloudConfig(CloudConfig(
        provider = CloudProvider.AZURE,
        subscriptionId = "12345678-1234-1234-1234-123456789012",
        resourceGroup = "mail-production-rg",
        vmName = "mail-vm"
    ))
    .build()
```

**Azure Requirements**:
- Azure CLI installed
- Boot diagnostics enabled on VM
- Appropriate RBAC permissions

---

### 11. GCP OS Login

**When to use**: GCE instances with centralized IAM

**Configuration**:
```kotlin
val config = ConnectionConfigBuilder()
    .type(ConnectionType.GCP_OS_LOGIN)
    .host("mail-instance")
    .port(22)
    .cloudConfig(CloudConfig(
        provider = CloudProvider.GCP,
        project = "mail-production-project",
        zone = "us-central1-a",
        instanceId = "mail-instance"
    ))
    .build()
```

**GCP Requirements**:
- gcloud CLI installed and configured
- OS Login enabled on instance
- IAM permissions

---

### 12. Local

**When to use**: Local development, testing, same-machine deployments

**Configuration**:
```kotlin
val config = ConnectionConfigBuilder()
    .type(ConnectionType.LOCAL)
    .host("localhost")
    .port(0)
    .options(ConnectionOptions(properties = mapOf(
        "workingDirectory" to "/opt/deployment"
    )))
    .build()
```

---

## Code Examples

### Example 1: Complete Deployment Flow

```kotlin
fun deployMailServer(host: String) {
    // Create connection
    val config = ConnectionConfigBuilder()
        .type(ConnectionType.SSH)
        .host(host)
        .port(22)
        .credentials(Credentials("mailserver", keyPath = "/path/to/key"))
        .build()

    val connection = ConnectionFactory.createConnection(config)

    try {
        // Connect
        val connectResult = connection.connect()
        if (!connectResult.isSuccess()) {
            throw Exception("Connection failed: ${(connectResult as ConnectionResult.Failure).error}")
        }

        // Update system
        connection.execute("apt-get update")

        // Install Docker
        connection.execute("curl -fsSL https://get.docker.com | sh")

        // Upload configuration
        connection.uploadFile(
            "/local/docker-compose.yml",
            "/opt/mailserver/docker-compose.yml"
        )

        // Start services
        connection.execute("cd /opt/mailserver && docker-compose up -d")

        // Verify
        val health = connection.getHealth()
        println("Deployment complete. Health: ${health.isHealthy}")

    } finally {
        connection.disconnect()
    }
}
```

### Example 2: Multi-Server Deployment

```kotlin
fun deployToMultipleServers(servers: List<String>) {
    servers.forEach { server ->
        val connection = ConnectionFactory.createSSHConnection(
            host = server,
            port = 22,
            username = "mailserver",
            password = "encrypted:..."
        )

        connection.use {  // AutoCloseable
            it.connect()
            it.execute("docker pull mailserver/docker-mailserver:latest")
            it.execute("docker restart mail-server")
        }
    }
}
```

### Example 3: Error Handling

```kotlin
fun robustConnection(host: String) {
    val config = ConnectionConfigBuilder()
        .type(ConnectionType.SSH)
        .host(host)
        .port(22)
        .credentials(Credentials("mailserver", keyPath = "/path/to/key"))
        .options(ConnectionOptions(
            timeout = 60,
            retries = 3,
            retryDelay = 5000
        ))
        .build()

    val connection = ConnectionFactory.createConnection(config)

    try {
        val result = connection.connect()

        when (result) {
            is ConnectionResult.Success -> {
                println("Connected: ${result.message}")
                // Proceed with deployment
            }
            is ConnectionResult.Failure -> {
                println("Connection failed: ${result.error}")
                result.exception?.printStackTrace()
                return
            }
        }

        // Execute with error handling
        val execResult = connection.execute("some-command")
        if (!execResult.success) {
            println("Command failed: ${execResult.errorOutput}")
            println("Exit code: ${execResult.exitCode}")
        }

    } catch (e: Exception) {
        println("Unexpected error: ${e.message}")
    } finally {
        connection.disconnect()
    }
}
```

---

## Security Best Practices

### 1. Password Encryption

**Always encrypt passwords**:

```bash
# Use the password encryption tool
./mail_factory_encrypt --password "MySecurePassword123!"
```

**Output**:
```
encrypted:AES256:base64iv:base64salt:base64encrypted
```

**Use in configuration**:
```kotlin
Credentials("mailserver", password = "encrypted:AES256:...")
```

### 2. SSH Key Permissions

```bash
# Correct permissions
chmod 600 ~/.ssh/mailserver_key
chmod 644 ~/.ssh/mailserver_key.pub

# Wrong permissions will cause connection failures
```

### 3. StrictHostKeyChecking

**Enable for production**:
```kotlin
.options(ConnectionOptions(strictHostKeyChecking = true))
```

**Disable only for testing**:
```kotlin
.options(ConnectionOptions(strictHostKeyChecking = false))  // TESTING ONLY!
```

### 4. Connection Pooling

```kotlin
// Reuse connections efficiently
val connection = ConnectionFactory.createConnection(config)
connection.connect()

// Execute multiple commands on same connection
connection.execute("command1")
connection.execute("command2")
connection.execute("command3")

// Disconnect when done
connection.disconnect()
```

### 5. Audit Logging

All connections automatically log to audit logs:
- Connection attempts (success/failure)
- Command executions
- File transfers
- Disconnections

Logs location: `${INSTALLATION_HOME}/logs/audit.log`

---

## Troubleshooting

### Connection Failed

**Problem**: `Connection failed: Connection refused`

**Solutions**:
1. Verify SSH server is running: `systemctl status sshd`
2. Check firewall: `ufw status` or `firewall-cmd --list-all`
3. Verify correct port: Default is 22
4. Test manually: `ssh user@host -p 22`

### Authentication Failed

**Problem**: `Connection failed: Authentication failed`

**Solutions**:
1. Verify credentials are correct
2. Check SSH key permissions: `chmod 600 ~/.ssh/key`
3. Verify key is added to server: `cat ~/.ssh/authorized_keys`
4. Check SELinux: `getenforce` (should be Permissive or Disabled)

### Timeout

**Problem**: `Command timed out after 120 seconds`

**Solutions**:
1. Increase timeout: `.options(ConnectionOptions(timeout = 300))`
2. Check network connectivity
3. Verify command doesn't hang (test manually)

### Docker Connection Failed

**Problem**: `Docker is not accessible`

**Solutions**:
1. Verify Docker is running: `systemctl status docker`
2. Check socket permissions: `ls -la /var/run/docker.sock`
3. Add user to docker group: `usermod -aG docker $USER`

---

## Migration Guide

### From Direct SSH to Connection Framework

**Before**:
```kotlin
val ssh = SSH(Remote("host", 22, "user", "pass"))
ssh.connect()
ssh.execute("command")
ssh.disconnect()
```

**After**:
```kotlin
val config = ConnectionConfigBuilder()
    .type(ConnectionType.SSH)
    .host("host")
    .port(22)
    .credentials(Credentials("user", password = "pass"))
    .build()

val connection = ConnectionFactory.createConnection(config)
connection.connect()
connection.execute("command")
connection.disconnect()
```

### Benefits of Migration

1. **Unified Interface**: Same interface for all 12 connection types
2. **Validation**: Built-in configuration validation
3. **Security**: Automatic encryption and audit logging
4. **Flexibility**: Easy to switch between connection types
5. **Testing**: Mock-friendly design

---

**Document Version**: 1.0
**Last Updated**: 2025-10-24
**Author**: Mail Server Factory Team

