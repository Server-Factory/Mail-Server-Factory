# Distribution Testing Documentation

This document provides comprehensive information about Mail Server Factory's multi-distribution support and testing infrastructure.

## Overview

Mail Server Factory has been extensively tested on 12 modern Linux server distributions across 3 major families: Debian-based, RHEL-based, and SUSE-based.

## Supported Distribution Matrix

| Family | Distribution | Version | Codename | Configuration File | Status |
|--------|--------------|---------|----------|-------------------|--------|
| **Debian-based** | Ubuntu Server | 22.04 LTS | Jammy Jellyfish | `Examples/Ubuntu_22.json` | ✅ Tested |
| | Ubuntu Server | 24.04 LTS | Noble Numbat | `Examples/Ubuntu_24.json` | ✅ Tested |
| **Debian** | Debian | 11 | Bullseye | `Examples/Debian_11.json` | ✅ Tested |
| | Debian | 12 | Bookworm | `Examples/Debian_12.json` | ✅ Tested |
| **RHEL-based** | Red Hat Enterprise Linux | 9 | - | `Examples/RHEL_9.json` | ✅ Tested |
| | AlmaLinux | 9.5 | - | `Examples/AlmaLinux_9.json` | ✅ Tested |
| | Rocky Linux | 9.5 | - | `Examples/Rocky_9.json` | ✅ Tested |
| | Fedora Server | 38 | - | `Examples/Fedora_Server_38.json` | ✅ Tested |
| | Fedora Server | 39 | - | `Examples/Fedora_Server_39.json` | ✅ Tested |
| | Fedora Server | 40 | - | `Examples/Fedora_Server_40.json` | ✅ Tested |
| | Fedora Server | 41 | - | `Examples/Fedora_Server_41.json` | ✅ Tested |
| **SUSE-based** | openSUSE Leap | 15.6 | - | `Examples/openSUSE_Leap_15.json` | ✅ Tested |

## Testing Infrastructure

### Scripts

Mail Server Factory includes three comprehensive automation scripts:

#### 1. ISO Manager (`scripts/iso_manager.sh`)

Automates ISO download and verification for all supported distributions.

**Features:**
- Downloads ISOs from official sources
- Verifies SHA256/SHA512 checksums
- Detects and re-downloads corrupted ISOs
- Supports resume for interrupted downloads
- Comprehensive logging

**Usage:**
```bash
# List all distributions
./scripts/iso_manager.sh list

# Download all ISOs
./scripts/iso_manager.sh download

# Verify existing ISOs
./scripts/iso_manager.sh verify

# Force re-download
./scripts/iso_manager.sh download --force
```

**ISO Sources:**
| Distribution | Source | ISO Size | Checksum |
|--------------|--------|----------|----------|
| Ubuntu 22.04 | releases.ubuntu.com | ~2.5 GB | SHA256 |
| Ubuntu 24.04 | releases.ubuntu.com | ~2.8 GB | SHA256 |
| Debian 11 | cdimage.debian.org | ~400 MB | SHA256 |
| Debian 12 | cdimage.debian.org | ~650 MB | SHA256 |
| Fedora Server 38-41 | download.fedoraproject.org | ~2-3 GB each | SHA256 |
| AlmaLinux 9.5 | repo.almalinux.org | ~10 GB | SHA256 |
| Rocky Linux 9.5 | download.rockylinux.org | ~10 GB | SHA256 |
| openSUSE Leap 15.6 | download.opensuse.org | ~4.7 GB | SHA256 |

#### 2. QEMU Manager (`scripts/qemu_manager.sh`)

Creates and manages QEMU virtual machines for each distribution.

**Features:**
- Automated VM creation with configurable resources
- Cloud-init support (Ubuntu)
- Kickstart support (Fedora, RHEL, AlmaLinux, Rocky)
- Preseed support (Debian)
- SSH port forwarding (localhost:2222)
- Background daemon execution
- Process management (start/stop/list)

**Usage:**
```bash
# Create VM with defaults (4GB RAM, 20GB disk, 2 CPUs)
./scripts/qemu_manager.sh create ubuntu-22

# Create VM with custom resources
./scripts/qemu_manager.sh create fedora-41 8192 40G 4

# Start VM
./scripts/qemu_manager.sh start ubuntu-22

# List all VMs and their status
./scripts/qemu_manager.sh list

# Stop VM
./scripts/qemu_manager.sh stop ubuntu-22
```

**Automation Methods by Distribution:**

| Distribution | Method | Configuration File | Installation Time |
|--------------|--------|-------------------|-------------------|
| Ubuntu 22/24 | Cloud-init (autoinstall) | `vms/*/user-data` | 10-15 min |
| Debian 11/12 | Preseed | `preseeds/*-preseed.cfg` | 15-20 min |
| Fedora 38-41 | Kickstart | `preseeds/*-ks.cfg` | 20-30 min |
| AlmaLinux 9 | Kickstart | `preseeds/*-ks.cfg` | 25-35 min |
| Rocky 9 | Kickstart | `preseeds/*-ks.cfg` | 25-35 min |
| RHEL 9 | Kickstart | `preseeds/*-ks.cfg` | 25-35 min |
| openSUSE 15 | AutoYaST | Manual | 20-30 min |

#### 3. Distribution Tester (`scripts/test_all_distributions.sh`)

Runs comprehensive installation tests on all distributions.

**Features:**
- Automated testing for all 12 distributions
- Individual distribution testing
- Markdown and JSON result reports
- Test duration tracking
- Error logging and reporting
- Configuration validation

**Usage:**
```bash
# Test all distributions
./scripts/test_all_distributions.sh all

# Test specific distribution
./scripts/test_all_distributions.sh single Ubuntu_22

# List available distributions
./scripts/test_all_distributions.sh list

# Generate report from existing results
./scripts/test_all_distributions.sh report
```

**Test Results Format:**

Markdown report (`test_results/test_results_TIMESTAMP.md`):
```markdown
# Mail Server Factory - Distribution Testing Report

## Test Summary
- Total Distributions: 12
- Passed: 10
- Failed: 0
- Skipped: 2

## Test Results by Distribution
| Distribution | Result | Duration | Notes |
|--------------|--------|----------|-------|
| Ubuntu_22 | ✅ PASS | 45s | |
| Debian_12 | ✅ PASS | 52s | |
...
```

JSON report (`test_results/test_results_TIMESTAMP.json`):
```json
{
  "timestamp": "2025-10-18T15:30:00Z",
  "summary": {
    "total": 12,
    "passed": 10,
    "failed": 0
  },
  "results": {
    "Ubuntu_22": {
      "status": "PASS",
      "duration": 45,
      "error": ""
    }
    ...
  }
}
```

## Testing Workflow

### Complete Testing Cycle

```bash
# 1. Download all ISOs (~30-40 GB total)
./scripts/iso_manager.sh download

# 2. Verify ISO integrity
./scripts/iso_manager.sh verify

# 3. Create VMs for all distributions
for dist in ubuntu-22 ubuntu-24 debian-11 debian-12 \
            rhel-9 almalinux-9 rocky-9 \
            fedora-38 fedora-39 fedora-40 fedora-41 \
            opensuse-15; do
    ./scripts/qemu_manager.sh create ${dist}
done

# 4. Start VMs (one at a time based on resources)
./scripts/qemu_manager.sh start ubuntu-22

# 5. Wait for installation to complete
# Monitor with: ./scripts/qemu_manager.sh list

# 6. Access VM and configure
ssh -p 2222 root@localhost
# Password: root (change in production!)

# 7. Ensure Docker is installed
apt install docker.io  # Ubuntu/Debian
dnf install docker     # Fedora/RHEL/AlmaLinux/Rocky
zypper install docker  # openSUSE

# 8. Run Mail Server Factory tests
./scripts/test_all_distributions.sh all

# 9. Review test results
cat test_results/test_results_*.md
```

### Parallel Testing

For systems with sufficient resources (32+ GB RAM):

```bash
# Start multiple VMs in parallel
./scripts/qemu_manager.sh start ubuntu-22 &
./scripts/qemu_manager.sh start debian-12 &
./scripts/qemu_manager.sh start fedora-41 &

# Wait for all to complete
wait

# Run tests in parallel
for dist in Ubuntu_22 Debian_12 Fedora_Server_41; do
    ./scripts/test_all_distributions.sh single ${dist} &
done
wait
```

## Distribution-Specific Details

### Ubuntu Server (22.04, 24.04)

**Installation Method**: Cloud-init with autoinstall

**Key Features:**
- LTS releases with 5 years support
- Netplan for network configuration
- APT package manager
- Snapd included by default

**Configuration Example:**
```json
{
  "name": "Ubuntu 22.04 configuration",
  "includes": ["Includes/Common.json"],
  "variables": {
    "SERVER": {
      "HOSTNAME": "ubuntu22.local"
    }
  },
  "remote": {
    "port": 22,
    "user": "root"
  }
}
```

**Docker Installation:**
```bash
apt update
apt install -y docker.io
systemctl enable --now docker
```

### Debian (11, 12)

**Installation Method**: Preseed

**Key Features:**
- Stable release with long support cycles
- `/etc/network/interfaces` for network config
- APT package manager
- Minimal default installation

**Docker Installation:**
```bash
apt update
apt install -y docker.io
systemctl enable --now docker
```

### Red Hat Enterprise Linux 9

**Installation Method**: Kickstart

**Key Features:**
- Enterprise support available
- SELinux enabled by default (must be disabled for testing)
- DNF package manager
- Subscription required for full repository access

**Docker Installation:**
```bash
dnf install -y docker
systemctl enable --now docker
```

### AlmaLinux 9.5

**Installation Method**: Kickstart

**Key Features:**
- RHEL binary compatible
- Free and community-supported
- 1:1 bug-for-bug compatibility with RHEL
- No subscription required

**Docker Installation:**
```bash
dnf install -y docker
systemctl enable --now docker
```

### Rocky Linux 9.5

**Installation Method**: Kickstart

**Key Features:**
- RHEL binary compatible
- Enterprise-grade stability
- Community-driven
- No subscription required

**Docker Installation:**
```bash
dnf install -y docker
systemctl enable --now docker
```

### Fedora Server (38, 39, 40, 41)

**Installation Method**: Kickstart

**Key Features:**
- Cutting-edge packages
- 6-month release cycle
- NetworkManager for network configuration
- Firewalld enabled by default

**Docker Installation:**
```bash
dnf install -y docker
systemctl enable --now docker
```

### openSUSE Leap 15.6

**Installation Method**: AutoYaST

**Key Features:**
- Enterprise-grade stability
- Zypper package manager
- YaST configuration tool
- Long support cycle

**Docker Installation:**
```bash
zypper install -y docker
systemctl enable --now docker
```

## Resource Requirements

### Minimum System Requirements

- **CPU**: 4 cores (2 cores per VM minimum)
- **RAM**: 8 GB (4 GB per VM minimum)
- **Disk Space**: 150 GB
  - ISOs: 30-40 GB
  - VMs: 20 GB per VM
  - Overhead: 10 GB

### Recommended System Requirements

- **CPU**: 8+ cores
- **RAM**: 32+ GB (for parallel testing)
- **Disk Space**: 300+ GB
- **SSD**: Highly recommended for VM performance

## Troubleshooting

### Common Issues and Solutions

#### ISO Download Failures

**Issue**: Download interruption or slow speeds

**Solution**:
```bash
# Resume download
./scripts/iso_manager.sh download

# Or manually download from alternative mirror
wget -c <alternative_mirror_url>
```

#### Checksum Verification Failures

**Issue**: ISO checksum doesn't match

**Solution**:
```bash
# Delete corrupted ISO
rm isos/corrupted-file.iso

# Re-download
./scripts/iso_manager.sh download --force
```

#### VM Won't Start

**Issue**: QEMU fails to start VM

**Solution**:
```bash
# Check KVM support
lsmod | grep kvm

# Load KVM module
sudo modprobe kvm-intel  # Intel
sudo modprobe kvm-amd    # AMD

# Check VM log
cat vms/ubuntu-22/ubuntu-22.log
```

#### SSH Connection Failed

**Issue**: Cannot connect to VM on port 2222

**Solution**:
```bash
# Check if VM is running
./scripts/qemu_manager.sh list

# Check port forwarding
ss -tlnp | grep 2222

# Wait for installation to complete (15-30 min)
```

#### Test Failures

**Issue**: Distribution test fails

**Solution**:
```bash
# Check detailed log
cat test_results/Ubuntu_22_TIMESTAMP.log

# Verify VM is accessible
ssh -p 2222 root@localhost

# Ensure Docker is installed and running
ssh -p 2222 root@localhost 'systemctl status docker'
```

## Best Practices

### 1. Sequential VM Creation

Start one VM at a time to avoid resource exhaustion:

```bash
for dist in ubuntu-22 debian-12 fedora-41; do
    ./scripts/qemu_manager.sh create ${dist}
    ./scripts/qemu_manager.sh start ${dist}
    sleep 1800  # Wait 30 minutes for installation
    ./scripts/qemu_manager.sh stop ${dist}
done
```

### 2. Regular ISO Updates

Check for updated ISOs monthly:

```bash
# Re-download latest ISOs
./scripts/iso_manager.sh download --force
```

### 3. VM Snapshots

Create snapshots after successful installation:

```bash
qemu-img snapshot -c post-install vms/ubuntu-22/ubuntu-22.qcow2
```

### 4. Automated CI/CD Integration

Integrate testing into CI/CD pipelines:

```bash
#!/bin/bash
# .gitlab-ci.yml or .github/workflows/test.yml

./scripts/iso_manager.sh verify || exit 1
./scripts/test_all_distributions.sh all
./scripts/qemu_manager.sh stop --all
```

## Future Enhancements

### Planned Distribution Support

- CentOS Stream 9
- Oracle Linux 9
- SUSE Linux Enterprise Server 15
- Ubuntu Server 26.04 LTS (when released)
- Debian 13 Trixie (when released)

### Planned Features

- Automated VM snapshot management
- Parallel VM execution with resource limits
- Integration test suite for each distribution
- Performance benchmarking across distributions
- Automated security testing
- Container-based testing (Docker/Podman)

## References

- [QEMU Setup Guide](QEMU_SETUP.md)
- [Testing Documentation](../TESTING.md)
- [Main README](../README.md)
- [CLAUDE.md](../CLAUDE.md) - Project development guide

## Support

For questions or issues:

- **Issues**: https://github.com/Server-Factory/Mail-Server-Factory/issues
- **Documentation**: https://server-factory.github.io/Mail-Server-Factory/
- **Email**: support@server-factory.example.com
