# OS Specifics Analysis - All 25 Distributions

**Date**: 2025-10-24
**Purpose**: Comprehensive analysis of OS-specific requirements for extending installation recipes

---

## Executive Summary

**Current State**:
- 13 distribution families supported for ISO downloads
- Only 3 families have installation recipes (CentOS, Fedora, Ubuntu)
- **Gap**: 10 distribution families lack installation definitions

**Required Extensions**:
- Add installation recipes for 10 OS families
- Support both Server and Desktop equivalents
- Ensure firewall, Docker, and mail server compatibility

---

## Distribution Matrix

### Current Support Status

| Distribution Family | ISO Support | Installation Recipe | Desktop Equivalent | Status |
|--------------------|-----------|--------------------|-------------------|---------|
| Ubuntu | ✅ Yes | ✅ Yes | Ubuntu Desktop | ✅ Complete |
| CentOS | ✅ Yes | ✅ Yes | N/A (Server only) | ✅ Complete |
| Fedora | ✅ Yes | ✅ Yes | Fedora Workstation | ✅ Complete |
| Debian | ✅ Yes | ❌ No | Debian Desktop | ⚠️ Needs recipe |
| AlmaLinux | ✅ Yes | ❌ No | N/A (Server only) | ⚠️ Needs recipe |
| Rocky | ✅ Yes | ❌ No | N/A (Server only) | ⚠️ Needs recipe |
| openSUSE | ✅ Yes | ❌ No | openSUSE Leap Desktop | ⚠️ Needs recipe |
| ALT Linux | ✅ Yes | ❌ No | ALT Workstation | ⚠️ Needs recipe |
| Astra Linux | ✅ Yes | ❌ No | Astra Linux Desktop | ⚠️ Needs recipe |
| ROSA Linux | ✅ Yes | ❌ No | ROSA Desktop Fresh | ⚠️ Needs recipe |
| openEuler | ✅ Yes | ❌ No | N/A (Server only) | ⚠️ Needs recipe |
| openKylin | ✅ Yes | ❌ No | openKylin Desktop | ⚠️ Needs recipe |
| Deepin | ✅ Yes | ❌ No | Deepin Desktop | ⚠️ Needs recipe |

---

## OS Family Details

### 1. Ubuntu Family (Debian-based)

#### Server Variants
- **Ubuntu Server** 25.10, 24.04 LTS, 22.04 LTS

#### Desktop Equivalent
- **Ubuntu Desktop** (same versions)
- **Package Manager**: apt-get, dpkg
- **Init System**: systemd
- **Firewall**: ufw (Uncomplicated Firewall)

**Installation Differences**:
- Desktop: Pre-installed GUI, more packages
- Server: Minimal install, no GUI by default
- Both use identical package management

**Current Recipe**: `/Definitions/main/software/docker/1.0.0/Ubuntu/Docker.json`

---

### 2. Debian Family

#### Server Variants
- **Debian** 11 (Bullseye), 12 (Bookworm)

#### Desktop Equivalent
- **Debian Desktop** (with GNOME, KDE, Xfce, or LXDE)

**OS Specifics**:
- **Package Manager**: apt-get, dpkg (identical to Ubuntu)
- **Init System**: systemd
- **Firewall**: ufw or iptables
- **Docker**: From docker.com repository (official Docker Engine)
- **Python**: python3 (Debian 11+)

**Key Differences from Ubuntu**:
- More conservative package versions
- Different default package selections
- Requires GPG key for Docker repo: `https://download.docker.com/linux/debian/gpg`

**Installation Recipe Needed**: ✅ **Can reuse Ubuntu recipe with minor modifications**

---

### 3. CentOS Family (RHEL-based)

#### Server Variants
- **CentOS Stream** 9
- **CentOS** 7, 8

**OS Specifics**:
- **Package Manager**: yum (CentOS 7), dnf (CentOS 8+)
- **Init System**: systemd
- **Firewall**: firewalld (default), iptables-services (alternative)
- **Docker**: docker-ce from docker.com
- **SELinux**: Enforcing by default (must disable for compatibility)

**Current Recipe**: `/Definitions/main/software/docker/1.0.0/Centos/Docker.json`

**Key Operations**:
```bash
# Disable SELinux
setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config

# Install Docker
yum install -y yum-utils device-mapper-persistent-data lvm2
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum install -y docker-ce docker-ce-cli containerd.io

# Enable iptables
yum install -y iptables iptables-services
systemctl enable iptables
systemctl start iptables
```

---

### 4. Fedora Family

#### Server Variants
- **Fedora Server** 38, 39, 40, 41

#### Desktop Equivalent
- **Fedora Workstation** (same versions)

**OS Specifics**:
- **Package Manager**: dnf
- **Init System**: systemd
- **Firewall**: firewalld
- **Docker**: docker-ce from docker.com
- **Cgroup**: v2 (requires kernel parameter for compatibility)
- **SELinux**: Enforcing by default

**Current Recipe**: `/Definitions/main/software/docker/1.0.0/Fedora/Docker.json`

**Special Requirements**:
```bash
# Cgroup v1 compatibility (for older Docker)
grubby --update-kernel=ALL --args="systemd.unified_cgroup_hierarchy=0"

# SELinux disable
setenforce 0
```

---

### 5. AlmaLinux / Rocky Linux (RHEL Clones)

#### Server Variants
- **AlmaLinux** 9
- **Rocky Linux** 9

**OS Specifics**:
- **Package Manager**: dnf (RHEL 9 based)
- **Init System**: systemd
- **Firewall**: firewalld
- **Docker**: docker-ce from docker.com
- **SELinux**: Enforcing by default
- **100% RHEL binary compatible**

**Installation Recipe Needed**: ✅ **Can reuse CentOS Stream 9 recipe**

**Key Compatibility**:
- AlmaLinux and Rocky are 1:1 RHEL 9 clones
- Same package names, repositories, and commands
- Only differ in branding and support model

---

### 6. openSUSE Family

#### Server Variants
- **openSUSE Leap** 15.5, 15.6

#### Desktop Equivalent
- **openSUSE Leap Desktop** (same version with KDE Plasma or GNOME)

**OS Specifics**:
- **Package Manager**: zypper, rpm
- **Init System**: systemd
- **Firewall**: firewalld (default), SuSEfirewall2 (legacy)
- **Docker**: docker from official SUSE repositories
- **AppArmor**: Enabled by default (alternative to SELinux)

**Installation Recipe Needed**: ⚠️ **Requires NEW recipe**

**Key Commands**:
```bash
# Add Docker repository
zypper addrepo https://download.docker.com/linux/sles/docker-ce.repo

# Install Docker
zypper install -y docker-ce docker-ce-cli containerd.io

# Enable Docker
systemctl enable docker
systemctl start docker

# Firewall (firewalld)
firewall-cmd --permanent --zone=public --add-service=http
firewall-cmd --reload
```

---

### 7. ALT Linux (Russian)

#### Server Variants
- **ALT Linux p10 Server**
- **ALT Linux p10**

#### Desktop Equivalent
- **ALT Workstation** p10

**OS Specifics**:
- **Package Manager**: apt-rpm (RPM packages with APT interface)
- **Init System**: systemd
- **Firewall**: iptables, firewalld
- **Docker**: Available in ALT repositories or from docker.com
- **Architecture**: RPM-based (like Fedora) but uses APT commands

**Installation Recipe Needed**: ⚠️ **Requires NEW recipe (hybrid APT/RPM)**

**Key Commands**:
```bash
# Update package cache (APT syntax)
apt-get update

# Install Docker (from ALT repos)
apt-get install -y docker-ce

# Or from Docker.com
apt-get install -y apt-transport-https ca-certificates curl
curl -fsSL https://download.docker.com/linux/alt/gpg | apt-key add -
apt-get install -y docker-ce docker-ce-cli containerd.io

# Enable Docker
systemctl enable docker
systemctl start docker
```

**Special Notes**:
- Uses APT command syntax but manages RPM packages
- FSTEC certified for Russian government use
- May require special repository configuration

---

### 8. Astra Linux (Russian)

#### Server Variants
- **Astra Linux CE** (Common Edition) 2.12

#### Desktop Equivalent
- **Astra Linux Desktop** 2.12

**OS Specifics**:
- **Package Manager**: apt-get, dpkg (Debian-based)
- **Init System**: systemd
- **Firewall**: ufw, iptables
- **Docker**: From Astra repositories or docker.com
- **Base**: Debian 10 (Buster) derived
- **Security**: Enhanced security features, KCMF certified

**Installation Recipe Needed**: ✅ **Can adapt Debian recipe**

**Key Commands**:
```bash
# Install prerequisites
apt-get update
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

# Add Docker GPG key
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository (Debian-compatible)
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian buster stable" > /etc/apt/sources.list.d/docker.list

# Install Docker
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io
```

**Special Notes**:
- Derived from Debian, nearly 100% compatible
- May have additional security policies to configure
- Firewall configuration identical to Debian/Ubuntu

---

### 9. ROSA Linux (Russian)

#### Server Variants
- **ROSA Server** 12.4

#### Desktop Equivalent
- **ROSA Desktop Fresh** 12.4

**OS Specifics**:
- **Package Manager**: dnf, rpm (RHEL-based)
- **Init System**: systemd
- **Firewall**: firewalld
- **Docker**: From docker.com or ROSA repositories
- **Base**: RHEL/Fedora derived

**Installation Recipe Needed**: ✅ **Can reuse Fedora/CentOS recipe**

**Key Commands**:
```bash
# Add Docker repository
dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo

# Install Docker
dnf install -y docker-ce docker-ce-cli containerd.io

# Enable Docker
systemctl enable docker
systemctl start docker

# Firewall
firewall-cmd --permanent --add-service=http
firewall-cmd --reload
```

---

### 10. openEuler (Chinese)

#### Server Variants
- **openEuler** 24.03 LTS
- **openEuler** 22.03 LTS SP4

**OS Specifics**:
- **Package Manager**: dnf, rpm (RPM-based)
- **Init System**: systemd
- **Firewall**: firewalld
- **Docker**: From openEuler repositories (iSula) or docker.com
- **Base**: Independent (Huawei-developed)
- **Architecture**: Enterprise server focus

**Installation Recipe Needed**: ✅ **Can adapt Fedora/RHEL recipe**

**Key Commands**:
```bash
# Update system
dnf update -y

# Install Docker dependencies
dnf install -y yum-utils device-mapper-persistent-data lvm2

# Add Docker repository
dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# Install Docker
dnf install -y docker-ce docker-ce-cli containerd.io

# Or use native iSula container engine
dnf install -y iSulad

# Enable Docker
systemctl enable docker
systemctl start docker
```

**Special Notes**:
- Offers iSula as native container runtime (lightweight alternative to Docker)
- Compatible with Docker for standard deployments
- May require additional repository configuration

---

### 11. openKylin (Chinese)

#### Server Variants
- **openKylin** 2.0

#### Desktop Equivalent
- **openKylin Desktop** 2.0 (default variant)

**OS Specifics**:
- **Package Manager**: apt-get, dpkg (Ubuntu-based)
- **Init System**: systemd
- **Firewall**: ufw
- **Docker**: From docker.com or openKylin repositories
- **Base**: Ubuntu 22.04 derived
- **Language**: Chinese localization focus

**Installation Recipe Needed**: ✅ **Can reuse Ubuntu recipe**

**Key Commands**:
```bash
# Update system
apt-get update

# Install Docker prerequisites
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

# Add Docker GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list

# Install Docker
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io
```

---

### 12. Deepin (Chinese)

#### Server Variants
- **Deepin** 23 (can be used as server)

#### Desktop Equivalent
- **Deepin Desktop** 23 (primary variant)

**OS Specifics**:
- **Package Manager**: apt-get, dpkg (Debian-based)
- **Init System**: systemd
- **Firewall**: ufw, iptables
- **Docker**: From docker.com
- **Base**: Debian 11/12 derived
- **Desktop**: Deepin Desktop Environment (DDE)

**Installation Recipe Needed**: ✅ **Can adapt Debian recipe**

**Key Commands**:
```bash
# Update system
apt-get update

# Install Docker
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io
```

---

## Package Manager Mapping

| Package Manager | Distributions | Install Command | Update Command | Remove Command |
|----------------|---------------|----------------|----------------|----------------|
| **apt-get** | Ubuntu, Debian, Astra, openKylin, Deepin | `apt-get install -y` | `apt-get update` | `apt-get remove -y` |
| **yum** | CentOS 7 | `yum install -y` | `yum update -y` | `yum remove -y` |
| **dnf** | CentOS 8+, Fedora, AlmaLinux, Rocky, ROSA, openEuler | `dnf install -y` | `dnf update -y` | `dnf remove -y` |
| **zypper** | openSUSE | `zypper install -y` | `zypper refresh` | `zypper remove -y` |
| **apt-rpm** | ALT Linux | `apt-get install -y` | `apt-get update` | `apt-get remove -y` |

---

## Firewall Mapping

| Firewall | Distributions | Enable Service | Open Port | Reload |
|----------|---------------|----------------|-----------|--------|
| **ufw** | Ubuntu, Debian, Astra, openKylin, Deepin | `ufw enable` | `ufw allow 25/tcp` | `ufw reload` |
| **firewalld** | CentOS, Fedora, AlmaLinux, Rocky, ROSA, openEuler, openSUSE | `systemctl enable firewalld` | `firewall-cmd --add-port=25/tcp` | `firewall-cmd --reload` |
| **iptables** | CentOS 7, ALT Linux | `systemctl enable iptables` | `iptables -A INPUT -p tcp --dport 25 -j ACCEPT` | `service iptables save` |

---

## Docker Installation Patterns

### Pattern A: Debian-based (apt-get)
**Distributions**: Ubuntu, Debian, Astra, openKylin, Deepin

```bash
# Prerequisites
apt-get update
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

# Add Docker GPG key
curl -fsSL https://download.docker.com/linux/{distribution}/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add repository
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/{distribution} $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list

# Install
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
```

### Pattern B: RHEL-based (dnf/yum)
**Distributions**: CentOS 8+, Fedora, AlmaLinux, Rocky, ROSA, openEuler

```bash
# Prerequisites
dnf install -y yum-utils device-mapper-persistent-data lvm2

# Add repository
dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# Install
dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Enable
systemctl enable docker
systemctl start docker
```

### Pattern C: SUSE-based (zypper)
**Distributions**: openSUSE

```bash
# Add repository
zypper addrepo https://download.docker.com/linux/sles/docker-ce.repo

# Install
zypper install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Enable
systemctl enable docker
systemctl start docker
```

### Pattern D: ALT Linux (apt-rpm hybrid)
**Distributions**: ALT Linux

```bash
# Update
apt-get update

# Install prerequisites
apt-get install -y apt-transport-https ca-certificates curl

# Add Docker repository (if using docker.com)
curl -fsSL https://download.docker.com/linux/alt/gpg | apt-key add -

# Install
apt-get install -y docker-ce docker-ce-cli containerd.io

# Enable
systemctl enable docker
systemctl start docker
```

---

## Desktop vs Server Equivalents

### Desktop Equivalents Table

| Server Distribution | Desktop Equivalent | Differences | Installation Impact |
|--------------------|--------------------|-------------|-------------------|
| Ubuntu Server | Ubuntu Desktop | GUI, more packages | Same package manager, recipes work identically |
| Debian Server | Debian Desktop (GNOME/KDE) | GUI, desktop packages | Same package manager, recipes work identically |
| CentOS | N/A | N/A (Server only) | N/A |
| Fedora Server | Fedora Workstation | GUI, desktop focus | Same package manager, recipes work identically |
| AlmaLinux | N/A | N/A (Server only) | N/A |
| Rocky Linux | N/A | N/A (Server only) | N/A |
| openSUSE Leap | openSUSE Leap Desktop | GUI (KDE/GNOME) | Same package manager, recipes work identically |
| ALT Server | ALT Workstation | GUI, office apps | Same package manager, recipes work identically |
| Astra Server | Astra Desktop | GUI, enhanced security | Same package manager, recipes work identically |
| ROSA Server | ROSA Desktop Fresh | GUI, multimedia | Same package manager, recipes work identically |
| openEuler | N/A | N/A (Server focus) | N/A |
| openKylin | openKylin Desktop | Desktop is primary variant | Same package manager, recipes work identically |
| Deepin | Deepin Desktop | Desktop is primary variant (DDE) | Same package manager, recipes work identically |

### Key Insight: Server/Desktop Compatibility

**For remote installation, Desktop vs Server variants make NO difference**:
- Package manager is identical
- Installation commands are identical
- Services (Docker, PostgreSQL, Postfix) work the same way
- Only difference: Desktop has GUI and additional packages

**Implication**: A single recipe works for both Server and Desktop variants of the same distribution.

---

## Host OS Support Analysis

### Current Host OS Support (Where Application Runs)

The Kotlin application currently detects:
- **macOS**: Special initialization with dock icon
- **Linux**: Minimal initialization
- **Windows**: Minimal initialization

**Source**: `Application/src/os/{macos,default}/kotlin/net/milosvasic/factory/mail/application/OSInit.kt`

### Host OS Can Be Any Linux Distribution

The **host machine** (where the Kotlin application runs) can be:
- Any Linux distribution with Java 17+
- macOS with Java 17+
- Windows with Java 17+

**Key Point**: Host OS detection is minimal. The critical OS detection is for the **remote/destination server**.

### Desktop Linux as Host

Any Desktop Linux distribution can serve as HOST for running the application:
- Ubuntu Desktop
- Fedora Workstation
- openSUSE Leap Desktop
- ALT Workstation
- Deepin Desktop
- etc.

**Requirements**:
- Java 17+ installed
- SSH client (`ssh` command)
- Network connectivity to target server

---

## Missing Installation Recipes Summary

### Must Create (High Priority)

| Distribution | Base | Can Reuse | Effort |
|--------------|------|-----------|--------|
| Debian | Debian | Ubuntu recipe (95% reuse) | Low |
| AlmaLinux | RHEL 9 | CentOS Stream recipe (100% reuse) | Minimal |
| Rocky Linux | RHEL 9 | CentOS Stream recipe (100% reuse) | Minimal |
| openSUSE | SUSE | New zypper-based recipe | Medium |

### Should Create (Medium Priority)

| Distribution | Base | Can Reuse | Effort |
|--------------|------|-----------|--------|
| Astra Linux | Debian | Debian recipe (90% reuse) | Low |
| openKylin | Ubuntu | Ubuntu recipe (95% reuse) | Low |
| Deepin | Debian | Debian recipe (90% reuse) | Low |
| ROSA Linux | RHEL | Fedora recipe (95% reuse) | Low |
| openEuler | Independent | Fedora/RHEL recipe (85% reuse) | Medium |

### Can Create (Lower Priority)

| Distribution | Base | Can Reuse | Effort |
|--------------|------|-----------|--------|
| ALT Linux | RPM/APT hybrid | New hybrid recipe | High |

---

## Recommendations

### 1. Immediate Actions (Phase 1)

Create installation recipes for RHEL clones (100% compatible):
- ✅ AlmaLinux 9 (reuse CentOS Stream recipe)
- ✅ Rocky Linux 9 (reuse CentOS Stream recipe)

Create Debian recipe (95% compatible with Ubuntu):
- ✅ Debian 11, 12

### 2. Short Term (Phase 2)

Create recipes for Debian derivatives:
- ✅ Astra Linux CE (Debian-based)
- ✅ openKylin (Ubuntu-based)
- ✅ Deepin (Debian-based)

Create recipe for Fedora derivatives:
- ✅ ROSA Linux (RHEL-based)
- ✅ openEuler (RPM-based)

### 3. Medium Term (Phase 3)

Create SUSE recipe:
- ✅ openSUSE Leap (zypper-based)

### 4. Long Term (Phase 4)

Create hybrid recipe:
- ✅ ALT Linux (apt-rpm hybrid)

---

## Testing Strategy

### Desktop from Host Testing

**Scenario**: Run Mail Server Factory from Desktop Linux to deploy on remote server

**Test Matrix**:

| Host OS (Desktop) | Remote OS (Server) | Expected Result |
|-------------------|-------------------|----------------|
| Ubuntu Desktop | Ubuntu Server | ✅ Should work |
| Ubuntu Desktop | CentOS | ✅ Should work |
| Fedora Workstation | Fedora Server | ✅ Should work |
| openSUSE Desktop | openSUSE Server | ✅ Should work |
| ALT Workstation | ALT Server | ✅ Should work |
| Deepin Desktop | Debian Server | ✅ Should work |

**Key Requirement**: Host must have Java 17+ and SSH client.

---

## Conclusion

**Summary**:
- **13 distribution families** supported for ISOs
- **Only 3** have installation recipes (CentOS, Fedora, Ubuntu)
- **10 families** need recipes
- **High reuse potential**: 7 out of 10 can reuse existing recipes with minor modifications
- **Desktop equivalents**: All Desktop variants can serve as HOST, recipes work for both Server and Desktop REMOTE targets

**Next Steps**:
1. Create AlmaLinux/Rocky recipes (symlink to CentOS Stream)
2. Create Debian recipe (adapt from Ubuntu)
3. Create openSUSE recipe (new zypper-based)
4. Create recipes for Chinese/Russian distributions
5. Update documentation and translations
6. Test all new recipes

---

**Document Version**: 1.0
**Date**: 2025-10-24
**Status**: ✅ Analysis Complete
