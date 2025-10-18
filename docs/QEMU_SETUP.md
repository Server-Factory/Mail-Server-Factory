# QEMU Virtual Machine Setup Guide

This guide provides comprehensive instructions for setting up QEMU virtual machines to test Mail Server Factory on all supported Linux distributions.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [ISO Management](#iso-management)
- [VM Creation](#vm-creation)
- [Testing Workflow](#testing-workflow)
- [Distribution-Specific Notes](#distribution-specific-notes)
- [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Software

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install qemu-system-x86 qemu-utils wget curl

# Fedora/RHEL/AlmaLinux/Rocky
sudo dnf install qemu-kvm qemu-img wget

# openSUSE
sudo zypper install qemu-x86 qemu-tools wget
```

### Disk Space Requirements

- **ISO Storage**: ~30-40 GB for all distributions
- **VM Images**: ~20 GB per VM (minimum)
- **Recommended**: 100+ GB free space

### Memory Requirements

- **Minimum**: 4 GB RAM per VM
- **Recommended**: 8 GB RAM for host + 4 GB per concurrent VM

## Quick Start

### 1. Download and Verify ISOs

The project includes an automated ISO management script:

```bash
# List all supported distributions
./scripts/iso_manager.sh list

# Download all ISOs and verify checksums
./scripts/iso_manager.sh download

# Verify existing ISOs
./scripts/iso_manager.sh verify

# Force re-download (if ISOs are corrupted)
./scripts/iso_manager.sh download --force
```

**Supported Distributions:**

| Distribution | Version | ISO Size | Checksum Type |
|--------------|---------|----------|---------------|
| Ubuntu Server | 22.04.5 | ~2.5 GB | SHA256 |
| Ubuntu Server | 24.04.3 | ~2.8 GB | SHA256 |
| Debian | 11.12.0 | ~400 MB | SHA256 |
| Debian | 12.9.0 | ~650 MB | SHA256 |
| Fedora Server | 38-41 | ~2-3 GB each | SHA256 |
| AlmaLinux | 9.5 | ~10 GB | SHA256 |
| Rocky Linux | 9.5 | ~10 GB | SHA256 |
| openSUSE Leap | 15.6 | ~4.7 GB | SHA256 |

### 2. Create Virtual Machines

Use the QEMU manager script to create and manage VMs:

```bash
# List available VM templates
./scripts/qemu_manager.sh list

# Create a VM with default settings (4GB RAM, 20GB disk, 2 CPUs)
./scripts/qemu_manager.sh create ubuntu-22

# Create a VM with custom resources
./scripts/qemu_manager.sh create fedora-41 8192 40G 4

# Start a VM
./scripts/qemu_manager.sh start ubuntu-22

# Stop a VM
./scripts/qemu_manager.sh stop ubuntu-22
```

### 3. Access VMs via SSH

After installation completes, access VMs on the forwarded port:

```bash
# Default SSH access (port 2222 forwarded to VM port 22)
ssh -p 2222 root@localhost
# Default password: root (change this in production!)
```

### 4. Run Mail Server Factory Tests

```bash
# Test all distributions
./scripts/test_all_distributions.sh all

# Test a specific distribution
./scripts/test_all_distributions.sh single Ubuntu_22

# Generate test report
./scripts/test_all_distributions.sh report
```

## ISO Management

### ISO Download Script Features

The `iso_manager.sh` script provides:

- **Automated Downloads**: Downloads ISOs from official sources
- **Checksum Verification**: Validates SHA256/SHA512 checksums
- **Resume Support**: Continues interrupted downloads
- **Corruption Detection**: Detects and re-downloads corrupted ISOs
- **Logging**: Comprehensive logs in `isos/iso_manager.log`

### Manual ISO Verification

```bash
# Verify a specific ISO manually
sha256sum isos/ubuntu-22.04.5-live-server-amd64.iso

# Compare with checksum file
grep ubuntu-22.04.5 isos/checksums/ubuntu-22.04.sha256
```

### ISO Storage Structure

```
isos/
├── checksums/                  # Downloaded checksum files
│   ├── ubuntu-22.04.sha256
│   ├── debian-11.sha256
│   └── ...
├── ubuntu-22.04.5-live-server-amd64.iso
├── ubuntu-24.04.3-live-server-amd64.iso
├── debian-11.12.0-amd64-netinst.iso
├── debian-12.9.0-amd64-netinst.iso
├── Fedora-Server-dvd-x86_64-*.iso
├── AlmaLinux-9.5-x86_64-dvd.iso
├── Rocky-9.5-x86_64-dvd.iso
├── openSUSE-Leap-15.6-DVD-x86_64-Media.iso
├── download.log               # Download progress log
└── iso_manager.log            # ISO manager operations log
```

## VM Creation

### VM Manager Script Features

The `qemu_manager.sh` script provides:

- **Automated VM Creation**: Creates QCOW2 disk images
- **Cloud-Init Support**: Automated Ubuntu installation
- **Kickstart Support**: Automated RHEL/Fedora/AlmaLinux/Rocky installation
- **Preseed Support**: Automated Debian installation
- **Resource Management**: Configurable CPU, RAM, and disk
- **Background Execution**: VMs run as daemons
- **Port Forwarding**: SSH access on localhost:2222

### VM Configurations

#### Ubuntu (22.04, 24.04)

- **Installation Method**: Cloud-init / Autoinstall
- **Default Hostname**: Matches VM name
- **Root Password**: root (auto-configured)
- **SSH**: Enabled by default
- **Disk Layout**: LVM with automatic partitioning

```bash
./scripts/qemu_manager.sh create ubuntu-22
./scripts/qemu_manager.sh start ubuntu-22
```

#### Debian (11, 12)

- **Installation Method**: Preseed
- **Mirror**: deb.debian.org
- **Packages**: Standard + SSH server
- **Partitioning**: Automatic (atomic recipe)

```bash
./scripts/qemu_manager.sh create debian-12
./scripts/qemu_manager.sh start debian-12
```

#### Fedora Server (38, 39, 40, 41)

- **Installation Method**: Kickstart
- **SELinux**: Disabled (for testing)
- **Firewall**: Disabled (for testing)
- **Network**: DHCP with predictable interface names disabled

```bash
./scripts/qemu_manager.sh create fedora-41 8192 40G 4
./scripts/qemu_manager.sh start fedora-41
```

#### RHEL-based (AlmaLinux, Rocky Linux, RHEL 9)

- **Installation Method**: Kickstart
- **Repositories**: Official mirrors
- **Boot Options**: `net.ifnames=0 biosdevname=0`

```bash
./scripts/qemu_manager.sh create almalinux-9
./scripts/qemu_manager.sh start almalinux-9
```

#### openSUSE Leap 15

- **Installation Method**: AutoYaST (manual configuration required)
- **Note**: Requires additional AutoYaST profile configuration

```bash
./scripts/qemu_manager.sh create opensuse-15
# Manual installation required
```

### VM Directory Structure

```
vms/
├── ubuntu-22/
│   ├── ubuntu-22.qcow2        # Virtual disk
│   ├── qemu.pid               # Process ID (when running)
│   ├── meta-data              # Cloud-init metadata
│   ├── user-data              # Cloud-init user data
│   └── network-config         # Network configuration
├── fedora-41/
│   └── fedora-41.qcow2
├── almalinux-9/
│   └── almalinux-9.qcow2
└── logs/
    ├── ubuntu-22.log
    ├── fedora-41.log
    └── ...
```

## Testing Workflow

### Complete Testing Cycle

```bash
# 1. Download all ISOs
./scripts/iso_manager.sh download

# 2. Create VMs for all distributions
for vm in ubuntu-22 ubuntu-24 debian-11 debian-12 fedora-41 almalinux-9 rocky-9; do
    ./scripts/qemu_manager.sh create ${vm}
done

# 3. Start VMs (one at a time or in batches based on resources)
./scripts/qemu_manager.sh start ubuntu-22

# 4. Wait for installation to complete (15-30 minutes per VM)
# Monitor with: ./scripts/qemu_manager.sh list

# 5. Configure Mail Server Factory on each VM
ssh -p 2222 root@localhost  # Access the VM
# Ensure Docker is installed and SSH keys are configured

# 6. Run automated tests
./scripts/test_all_distributions.sh all

# 7. Review results
cat test_results/test_results_*.md
```

### Test Results

Test results are stored in `test_results/` with:

- **Markdown Report**: Human-readable summary
- **JSON Report**: Machine-parseable results
- **Individual Logs**: Per-distribution test logs

## Distribution-Specific Notes

### Ubuntu 22.04 / 24.04

- Uses `autoinstall` (cloud-init based)
- Installation typically completes in 10-15 minutes
- Network configuration uses Netplan
- Docker can be installed post-installation: `sudo apt install docker.io`

### Debian 11 / 12

- Uses preseed for automated installation
- Minimal installation via netinst ISO
- Network configured via `/etc/network/interfaces`
- Docker installation: `sudo apt install docker.io`

### Fedora Server 38-41

- Kickstart-based installation
- Installation completes in 20-30 minutes (large ISO)
- Uses NetworkManager for network configuration
- Docker installation: `sudo dnf install docker`

### AlmaLinux 9 / Rocky Linux 9

- Compatible with RHEL 9
- Large DVD ISOs (~10 GB)
- Installation takes 25-35 minutes
- Minimal installation recommended
- Docker installation: `sudo dnf install docker`

### openSUSE Leap 15.6

- AutoYaST configuration required
- Zypper package manager
- Docker installation: `sudo zypper install docker`

## Troubleshooting

### ISO Download Issues

**Problem**: Download fails or times out

```bash
# Check network connectivity
ping releases.ubuntu.com

# Resume interrupted download
./scripts/iso_manager.sh download

# Use alternative mirror (edit iso_manager.sh)
```

**Problem**: Checksum verification fails

```bash
# Re-download with force flag
./scripts/iso_manager.sh download --force

# Manually verify
sha256sum isos/ubuntu-22.04.5-live-server-amd64.iso
```

### VM Creation Issues

**Problem**: QEMU not found

```bash
# Install QEMU
sudo apt install qemu-system-x86 qemu-utils  # Ubuntu/Debian
sudo dnf install qemu-kvm qemu-img            # Fedora/RHEL
```

**Problem**: Insufficient disk space

```bash
# Check available space
df -h

# Clean old VMs
rm -rf vms/old-vm-name/
```

**Problem**: VM won't start

```bash
# Check if KVM is available
lsmod | grep kvm

# Enable KVM if needed
sudo modprobe kvm-intel  # Intel CPUs
sudo modprobe kvm-amd    # AMD CPUs

# Check VM log
cat vms/ubuntu-22/ubuntu-22.log
```

### SSH Access Issues

**Problem**: Cannot connect to VM

```bash
# Check if VM is running
./scripts/qemu_manager.sh list

# Check port forwarding
ss -tlnp | grep 2222

# Verify SSH is running in VM (via console)
# Or check VM logs
```

**Problem**: Permission denied (publickey)

```bash
# Use password authentication
ssh -p 2222 -o PreferredAuthentications=password root@localhost

# Or copy SSH key
ssh-copy-id -p 2222 root@localhost
```

### Testing Issues

**Problem**: Tests fail to connect to server

```bash
# Ensure VM hostname resolves
# Edit /etc/hosts on the testing machine
echo "127.0.0.1 ubuntu22.local" | sudo tee -a /etc/hosts

# Or update Examples/*.json with correct hostname
```

**Problem**: Docker not installed in VM

```bash
# SSH into VM and install Docker
ssh -p 2222 root@localhost

# Ubuntu/Debian
apt update && apt install -y docker.io

# Fedora/RHEL/AlmaLinux/Rocky
dnf install -y docker

# openSUSE
zypper install -y docker

# Start Docker
systemctl enable --now docker
```

## Advanced Configuration

### Custom Network Configuration

Edit QEMU network settings in `qemu_manager.sh`:

```bash
# Bridge networking instead of port forwarding
-netdev bridge,id=net0,br=br0
-device virtio-net-pci,netdev=net0

# Multiple port forwards
-netdev user,id=net0,hostfwd=tcp::2222-:22,hostfwd=tcp::8080-:80
```

### VM Snapshots

```bash
# Create a snapshot after installation
qemu-img snapshot -c post-install vms/ubuntu-22/ubuntu-22.qcow2

# List snapshots
qemu-img snapshot -l vms/ubuntu-22/ubuntu-22.qcow2

# Restore snapshot
qemu-img snapshot -a post-install vms/ubuntu-22/ubuntu-22.qcow2
```

### Automated Testing Pipeline

```bash
#!/bin/bash
# Full automation script

./scripts/iso_manager.sh download
for dist in ubuntu-22 ubuntu-24 debian-11 debian-12 fedora-41 almalinux-9 rocky-9; do
    ./scripts/qemu_manager.sh create ${dist}
    ./scripts/qemu_manager.sh start ${dist}

    # Wait for boot (customize per distribution)
    sleep 300

    # Run tests
    ./scripts/test_all_distributions.sh single $(echo ${dist} | tr '-' '_' | sed 's/_\([0-9]\)/\_\1/')

    # Stop VM
    ./scripts/qemu_manager.sh stop ${dist}
done
```

## References

- [QEMU Documentation](https://www.qemu.org/documentation/)
- [Cloud-init Documentation](https://cloudinit.readthedocs.io/)
- [Kickstart Documentation](https://pykickstart.readthedocs.io/)
- [Debian Preseed](https://wiki.debian.org/DebianInstaller/Preseed)
- [AutoYaST Guide](https://doc.opensuse.org/projects/autoyast/)

## Support

For issues or questions:

- GitHub Issues: [Mail-Server-Factory Issues](https://github.com/Server-Factory/Mail-Server-Factory/issues)
- Documentation: [Project README](../README.md)
- Testing Guide: [TESTING.md](../TESTING.md)
