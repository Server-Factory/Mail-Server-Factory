# Getting Started with Mail Server Factory

**Version**: 3.0
**Last Updated**: 2025-10-24
**Difficulty**: Beginner
**Estimated Time**: 30-60 minutes

---

## Welcome!

This tutorial will guide you through your first Mail Server Factory deployment. By the end, you'll have a fully functional mail server running on your chosen Linux distribution.

---

## What You'll Learn

- ✅ System requirements and prerequisites
- ✅ Installing Mail Server Factory
- ✅ Choosing the right distribution
- ✅ Creating your first configuration
- ✅ Running your first deployment
- ✅ Verifying the installation
- ✅ Troubleshooting common issues

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Choosing Your Distribution](#choosing-your-distribution)
4. [Configuration](#configuration)
5. [First Deployment](#first-deployment)
6. [Verification](#verification)
7. [Next Steps](#next-steps)
8. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Host Machine (Where You Run Mail Server Factory)

**Operating System**:
- ✅ Any Linux distribution with Java 17+
- ✅ macOS with Java 17+
- ✅ Windows with Java 17+ (via WSL2)

**Software Required**:
- Java 17 or higher
- SSH client
- Git (for cloning repository)
- Text editor

**Desktop Linux Recommended** (for testing):
- Ubuntu Desktop 24.04 LTS
- Fedora Workstation 41
- Debian Desktop 12
- openSUSE Leap 15.6

### Remote Server (Where Mail Server Will Be Deployed)

**Operating System**: One of 13 supported distributions
- See [Choosing Your Distribution](#choosing-your-distribution) below

**Minimum Requirements**:
- 2 CPU cores
- 4 GB RAM (8 GB recommended)
- 40 GB disk space
- Network connectivity
- SSH access (port 22)

**Recommended**:
- 4 CPU cores
- 8 GB RAM
- 100 GB SSD
- Static IP or domain name
- Firewall configured

---

## Installation

### Step 1: Install Java

**Ubuntu/Debian**:
```bash
sudo apt update
sudo apt install openjdk-17-jdk
java -version
```

**Fedora**:
```bash
sudo dnf install java-17-openjdk
java -version
```

**macOS** (using Homebrew):
```bash
brew install openjdk@17
java -version
```

**Verify**:
```bash
java -version
# Should show: openjdk version "17.x.x"
```

### Step 2: Clone Repository

```bash
cd ~
git clone --recurse-submodules https://github.com/Server-Factory/Mail-Server-Factory.git
cd Mail-Server-Factory
```

**Important**: The `--recurse-submodules` flag is required to download all dependencies!

### Step 3: Build Application

```bash
./gradlew assemble
```

**Expected output**:
```
BUILD SUCCESSFUL in 30s
```

**Verify**:
```bash
ls -lh Application/build/libs/Application.jar
# Should show: Application.jar file (~50-100 MB)
```

### Step 4: Set Up SSH Access

**Generate SSH key** (if you don't have one):
```bash
cd Core/Utils
./init_ssh_access.sh your-remote-server.example.com
```

**This script will**:
1. Generate ed25519 SSH key (if needed)
2. Copy public key to remote server
3. Test SSH connection
4. Configure SSH agent

**Manual alternative**:
```bash
# Generate key
ssh-keygen -t ed25519 -f ~/.ssh/server_factory

# Copy to remote server
ssh-copy-id -i ~/.ssh/server_factory.pub root@your-server.com

# Test connection
ssh -i ~/.ssh/server_factory root@your-server.com echo "Connection successful!"
```

---

## Choosing Your Distribution

Mail Server Factory supports **13 distribution families** across 3 regions:

### Western Distributions (Recommended for Beginners)

| Distribution | Versions | Difficulty | Best For |
|--------------|----------|------------|----------|
| **Ubuntu Server** | 25.10, 24.04 LTS, 22.04 LTS | ⭐ Easy | Beginners, most tested |
| **Debian** | 11, 12 | ⭐⭐ Easy | Stability, long-term support |
| **CentOS Stream** | 9 | ⭐⭐ Medium | Enterprise, RHEL-like |
| **Fedora Server** | 38-41 | ⭐⭐ Medium | Latest features, cutting-edge |
| **AlmaLinux** | 9 | ⭐⭐ Medium | RHEL clone, free |
| **Rocky Linux** | 9 | ⭐⭐ Medium | RHEL clone, community |
| **openSUSE Leap** | 15.5, 15.6 | ⭐⭐⭐ Medium | Enterprise SUSE, YaST tools |

### Russian Distributions 🇷🇺

| Distribution | Versions | Difficulty | Best For |
|--------------|----------|------------|----------|
| **ALT Linux** | p10, p10-server | ⭐⭐⭐ Advanced | Russian market, FSTEC certified |
| **Astra Linux CE** | 2.12 | ⭐⭐⭐ Advanced | High security, government |
| **ROSA Linux** | 12.4 | ⭐⭐ Medium | Desktop + server, Russian support |

### Chinese Distributions 🇨🇳

| Distribution | Versions | Difficulty | Best For |
|--------------|----------|------------|----------|
| **openEuler** | 24.03 LTS, 22.03 LTS SP4 | ⭐⭐⭐ Advanced | Huawei ecosystem, enterprise |
| **openKylin** | 2.0 | ⭐⭐ Medium | Chinese market, Ubuntu-based |
| **Deepin** | 23 | ⭐⭐ Medium | Desktop-focused, easy to use |

### Recommendation for This Tutorial

**We recommend starting with Ubuntu Server 24.04 LTS**:
- Most tested and stable
- Largest community
- Best documentation
- Easiest troubleshooting

---

## Configuration

### Step 1: Choose Example Configuration

```bash
cd Examples
ls -1 *.json
```

**You'll see**:
```
Ubuntu_25.json
Ubuntu_24.json
Ubuntu_22.json
Debian_12.json
Debian_11.json
CentOS_Stream.json
Fedora_Server_41.json
AlmaLinux_9.json
Rocky_9.json
openSUSE_Leap_15.6.json
ALTLinux_p10.json
Astra_Linux_CE_2.12.json
ROSA_Linux_12.json
openEuler_24.03_LTS.json
openKylin_2.0.json
Deepin_23.json
... and more
```

**For this tutorial, we'll use Ubuntu 24.04**:
```bash
cp Ubuntu_24.json MyFirstServer.json
```

### Step 2: Edit Configuration

```bash
nano MyFirstServer.json
```

**You'll see**:
```json
{
  "name": "Ubuntu 24.04 configuration",
  "includes": [
    "Includes/Common.json"
  ],
  "variables": {
    "SERVER": {
      "HOSTNAME": "ubuntu-24-server.local"
    }
  },
  "remote": {
    "port": 22,
    "user": "root"
  }
}
```

**Change the hostname** to match your server:
```json
{
  "name": "My First Mail Server",
  "includes": [
    "Includes/Common.json"
  ],
  "variables": {
    "SERVER": {
      "HOSTNAME": "mail.yourdomain.com"
    }
  },
  "remote": {
    "port": 22,
    "user": "root"
  }
}
```

**Important**: Replace `mail.yourdomain.com` with your actual server's hostname or IP address!

### Step 3: Configure Mail Accounts

```bash
cd Includes
nano Accounts.json
```

**You'll see**:
```json
{
  "accounts": [
    {
      "name": "postmaster",
      "type": "POSTMASTER",
      "email": "postmaster@yourdomain.com",
      "password": "CHANGE_ME_STRONG_PASSWORD",
      "aliases": []
    }
  ]
}
```

**Update**:
```json
{
  "accounts": [
    {
      "name": "postmaster",
      "type": "POSTMASTER",
      "email": "postmaster@example.com",
      "password": "MySecurePassword123!",
      "aliases": ["admin@example.com"]
    },
    {
      "name": "john",
      "type": "USER",
      "email": "john@example.com",
      "password": "JohnsPassword456!",
      "aliases": ["j.doe@example.com"]
    }
  ]
}
```

**Important Notes**:
- Replace `example.com` with your actual domain
- Use strong passwords (min 8 characters, mixed case, numbers, symbols)
- Postmaster account is required
- Add as many users as needed

### Step 4: Configure Docker Credentials

**Create Docker credentials file**:
```bash
cp _Docker.json.example _Docker.json
nano _Docker.json
```

**Content**:
```json
{
  "variables": {
    "DOCKER": {
      "LOGIN": {
        "ACCOUNT": "your-dockerhub-username",
        "PASSWORD": "your-dockerhub-password"
      }
    }
  }
}
```

**Get Docker Hub credentials**:
1. Go to https://hub.docker.com/
2. Sign up for free account (if needed)
3. Use your username and password

**Security Note**: This file contains passwords. Never commit it to version control!

---

## First Deployment

### Step 1: Pre-Flight Check

**Verify connectivity**:
```bash
cd ~/Mail-Server-Factory
ssh root@mail.yourdomain.com "echo 'SSH connection successful!'"
```

**Expected**: `SSH connection successful!`

**Check disk space** on remote server:
```bash
ssh root@mail.yourdomain.com "df -h /"
```

**Expected**: At least 20 GB free

**Check memory**:
```bash
ssh root@mail.yourdomain.com "free -h"
```

**Expected**: At least 4 GB total

### Step 2: Run Deployment

```bash
./mail_factory Examples/MyFirstServer.json
```

**What happens**:
1. ✅ Configuration validation (1 minute)
2. ✅ SSH connection established
3. ✅ Remote OS detection
4. ✅ Software installation (Docker, PostgreSQL, Redis) (5-10 minutes)
5. ✅ Docker stack deployment (Postfix, Dovecot, Rspamd, ClamAV) (10-15 minutes)
6. ✅ Database initialization (2 minutes)
7. ✅ Mail account creation (1 minute)
8. ✅ System reboot (2 minutes)
9. ✅ Final verification (1 minute)

**Total time**: 20-30 minutes

**You'll see output like**:
```
================================================================
  Mail Server Factory v3.0
================================================================
ℹ Configuration: Examples/MyFirstServer.json
ℹ Remote host: mail.yourdomain.com
ℹ Remote OS: Ubuntu 24.04 LTS
================================================================

▶ Phase 1: Initialization
✓ SSH connection established
✓ Remote OS detected: Ubuntu 24.04
✓ Configuration validated
✓ All variables resolved

▶ Phase 2: Software Installation
✓ Installing Docker...
✓ Installing PostgreSQL...
✓ Installing Redis...
✓ All software installed successfully

▶ Phase 3: Docker Stack Deployment
✓ Deploying PostgreSQL container...
✓ Deploying Redis container...
✓ Deploying Postfix container...
✓ Deploying Dovecot container...
✓ Deploying Rspamd container...
✓ Deploying ClamAV container...
✓ All containers deployed successfully

▶ Phase 4: Database Initialization
✓ Creating databases...
✓ Creating tables...
✓ Database initialized successfully

▶ Phase 5: Mail Account Creation
✓ Creating postmaster@example.com...
✓ Creating john@example.com...
✓ All accounts created successfully

▶ Phase 6: System Reboot
ℹ Rebooting server...
ℹ Waiting for server to come back online...
✓ Server is back online

▶ Phase 7: Final Verification
✓ Docker daemon running
✓ All containers running
✓ Database accessible
✓ Mail services operational

================================================================
✓ Deployment completed successfully!
================================================================

Mail Server Details:
  SMTP (Submission): mail.yourdomain.com:465 (SSL/TLS)
  IMAP: mail.yourdomain.com:993 (SSL/TLS)
  POP3: mail.yourdomain.com:995 (SSL/TLS)

  Accounts:
    - postmaster@example.com
    - john@example.com

  Webmail: Configure your email client manually

Next Steps:
  1. Configure your email client
  2. Send test email
  3. Check spam filtering
  4. Set up DNS records (MX, SPF, DKIM, DMARC)

Documentation: https://mail-server-factory.example.com/docs
================================================================
```

### Step 3: Monitor Deployment

**In another terminal**, you can monitor progress:
```bash
# Watch system logs
ssh root@mail.yourdomain.com "tail -f /var/log/syslog"

# Watch Docker containers
ssh root@mail.yourdomain.com "watch docker ps"

# Monitor resource usage
ssh root@mail.yourdomain.com "htop"
```

---

## Verification

### Step 1: Check Docker Containers

```bash
ssh root@mail.yourdomain.com "docker ps"
```

**Expected output**:
```
CONTAINER ID   IMAGE                    STATUS      PORTS
abc123def456   postgres:15             Up 5 mins   5432/tcp, 0.0.0.0:35432->5432/tcp
bcd234eff567   redis:7                 Up 5 mins   6379/tcp, 0.0.0.0:36379->6379/tcp
cde345fgg678   mail-postfix:latest     Up 4 mins   0.0.0.0:465->465/tcp
def456ghh789   mail-dovecot:latest     Up 4 mins   0.0.0.0:993->993/tcp, 0.0.0.0:995->995/tcp
efg567hii890   mail-rspamd:latest      Up 4 mins   11332-11334/tcp
fgh678jjj901   mail-clamav:latest      Up 4 mins   10024/tcp
```

**All containers should show "Up X mins"**

### Step 2: Test Email Account Authentication

```bash
ssh root@mail.yourdomain.com "doveadm auth test postmaster@example.com"
```

**Enter password when prompted**

**Expected output**:
```
passdb: postmaster@example.com auth succeeded
extra fields:
  user=postmaster@example.com
```

### Step 3: Configure Email Client

**Thunderbird / Outlook / Apple Mail Settings**:

**IMAP (Incoming)**:
- Server: mail.yourdomain.com
- Port: 993
- Security: SSL/TLS
- Authentication: Normal password
- Username: postmaster@example.com
- Password: MySecurePassword123!

**SMTP (Outgoing)**:
- Server: mail.yourdomain.com
- Port: 465
- Security: SSL/TLS
- Authentication: Normal password
- Username: postmaster@example.com
- Password: MySecurePassword123!

### Step 4: Send Test Email

1. Open your email client
2. Compose new email
3. To: john@example.com
4. Subject: Test Email
5. Body: Hello from Mail Server Factory!
6. Send

### Step 5: Verify Delivery

1. Log in as john@example.com
2. Check inbox
3. You should see the test email

**Alternative: Check via command line**:
```bash
ssh root@mail.yourdomain.com "doveadm mailbox list -u john@example.com"
```

---

## Next Steps

### Recommended Actions

1. **Set Up DNS Records**
   - MX record: `mail.yourdomain.com`
   - SPF record: `v=spf1 mx ~all`
   - DKIM record: (generated during installation)
   - DMARC record: `v=DMARC1; p=quarantine`

2. **Configure Firewall**
   - Open ports: 25, 465, 993, 995
   - Close unused ports
   - Enable fail2ban

3. **SSL/TLS Certificates**
   - Get Let's Encrypt certificate
   - Configure auto-renewal
   - Update Postfix/Dovecot to use certificates

4. **Backup Strategy**
   - Set up automated backups
   - Test restore procedure
   - Document recovery process

5. **Monitoring**
   - Set up log monitoring
   - Configure alerts
   - Monitor disk space, memory, CPU

### Advanced Topics

- **Multi-domain Support**: Add more domains
- **Webmail**: Install Roundcube or Rainloop
- **Spam Filtering**: Fine-tune Rspamd rules
- **Virus Scanning**: Configure ClamAV signatures
- **Quota Management**: Set mailbox size limits
- **High Availability**: Set up mail server cluster

### Learning Resources

- **Official Documentation**: https://mail-server-factory.example.com/docs
- **Tutorial Series**: See COMPREHENSIVE_DOCUMENTATION_MASTER.md
- **Community Forum**: https://github.com/Server-Factory/Mail-Server-Factory/discussions
- **Issue Tracker**: https://github.com/Server-Factory/Mail-Server-Factory/issues

---

## Troubleshooting

### Issue: "SSH connection failed"

**Symptoms**: Cannot connect to remote server

**Solutions**:
1. Check server is online: `ping mail.yourdomain.com`
2. Check SSH port: `telnet mail.yourdomain.com 22`
3. Verify SSH key: `ssh -i ~/.ssh/server_factory root@mail.yourdomain.com`
4. Check firewall on server allows port 22

### Issue: "Docker installation failed"

**Symptoms**: Error during Docker installation phase

**Solutions**:
1. Check internet connectivity on remote server
2. Verify repository availability: `curl -I https://download.docker.com`
3. Check disk space: `df -h /`
4. Review installation logs: `less /var/log/mail_factory_install.log`

### Issue: "Container won't start"

**Symptoms**: Docker container shows "Exited" status

**Solutions**:
1. Check container logs: `docker logs <container-id>`
2. Check disk space: `df -h /var/lib/docker`
3. Check memory: `free -h`
4. Restart container: `docker restart <container-id>`

### Issue: "Cannot send/receive email"

**Symptoms**: Email client connection fails

**Solutions**:
1. Check containers running: `docker ps`
2. Check ports open: `telnet mail.yourdomain.com 465`
3. Check DNS resolution: `dig mail.yourdomain.com`
4. Verify account: `doveadm auth test user@example.com`
5. Check firewall rules: `iptables -L`

### Issue: "Deployment takes too long"

**Symptoms**: Deployment exceeds 30 minutes

**Solutions**:
1. Check network speed: `speedtest-cli` on server
2. Monitor resource usage: `htop`
3. Check Docker image download progress: `docker images`
4. Increase timeout in configuration (if needed)

### Getting Help

**If you're stuck**:

1. **Check Documentation**:
   - README.md
   - COMPREHENSIVE_DOCUMENTATION_MASTER.md
   - OS_SPECIFICS_ANALYSIS.md

2. **Search Issues**:
   - https://github.com/Server-Factory/Mail-Server-Factory/issues

3. **Ask Community**:
   - https://github.com/Server-Factory/Mail-Server-Factory/discussions

4. **File Bug Report**:
   - https://github.com/Server-Factory/Mail-Server-Factory/issues/new
   - Include: OS version, error messages, logs

---

## Summary

Congratulations! 🎉 You've completed your first Mail Server Factory deployment!

**What you accomplished**:
- ✅ Installed Mail Server Factory
- ✅ Configured your server
- ✅ Deployed complete mail stack
- ✅ Created mail accounts
- ✅ Sent test email
- ✅ Verified everything works

**Your mail server includes**:
- Postfix (SMTP)
- Dovecot (IMAP/POP3)
- PostgreSQL (Database)
- Redis (Cache)
- Rspamd (Anti-spam)
- ClamAV (Anti-virus)

**Next**: Explore advanced features and customize your mail server!

---

**Tutorial Version**: 1.0
**Last Updated**: 2025-10-24
**Difficulty**: Beginner
**Estimated Time**: 30-60 minutes
**Status**: ✅ Complete

---

**Need more help?** See:
- Installation Manual (coming soon)
- Docker Manual (coming soon)
- Testing Guide (TESTING.md)
- Architecture Reference (QUICK_ARCHITECTURE_REFERENCE.md)
