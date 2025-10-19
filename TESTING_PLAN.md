# Mail Server Factory - Complete Testing Plan

This document provides a comprehensive plan for testing Mail Server Factory on all supported OS distributions using QEMU virtual machines.

## Prerequisites

### System Requirements
- Modern Linux system with hardware virtualization support (Intel VT-x or AMD-V)
- At least 100GB free disk space (for ISOs and VM images)
- At least 16GB RAM (recommended for running multiple VMs)
- Internet connection for downloading ISOs

### Software Requirements
- QEMU: `sudo apt install qemu-system-x86 qemu-utils` (Ubuntu/Debian)
- Java 17+
- Docker
- Git

## Complete Testing Process

### Step 1: Download ISO Images
```bash
# Download all ISOs for supported distributions
./scripts/iso_manager.sh download

# Verify all ISOs
./scripts/iso_manager.sh verify

# List available ISOs
./scripts/iso_manager.sh list
```

### Step 2: Create and Configure VMs
```bash
# Create VMs for all supported distributions
for vm in ubuntu-22 ubuntu-24 debian-11 debian-12 fedora-41 almalinux-9 rocky-9; do
    ./scripts/qemu_manager.sh create ${vm}
done

# For openSUSE and other distributions requiring special handling:
# ./scripts/qemu_manager.sh create opensuse-15
```

### Step 3: Start VMs and Install OS
```bash
# Start VMs one by one (or in batches based on system resources)
./scripts/qemu_manager.sh start ubuntu-22

# Wait for installation to complete (typically 10-30 minutes per distribution)
# Monitor progress with: tail -f vms/logs/ubuntu-22.log

# Access VM after installation completes:
ssh -p 2222 root@localhost
```

### Step 4: Prepare VMs for Mail Server Factory Testing
For each VM, ensure the following:

1. Docker is installed and running:
```bash
# Ubuntu/Debian:
apt update && apt install -y docker.io
systemctl enable docker
systemctl start docker

# Fedora/RHEL/AlmaLinux/Rocky:
dnf install -y docker
systemctl enable docker
systemctl start docker

# openSUSE:
zypper install -y docker
systemctl enable docker
systemctl start docker
```

2. SSH key authentication is set up:
```bash
# On the host system, copy SSH key to VM
ssh-copy-id -p 2222 root@localhost
```

3. Network configuration for hostname resolution:
```bash
# Add VM hostname to /etc/hosts on host system
echo "127.0.0.1 ubuntu22.local" >> /etc/hosts
```

### Step 5: Run Mail Server Factory Tests
```bash
# Test individual distributions
./scripts/test_all_distributions.sh single Ubuntu_22

# Test all distributions
./scripts/test_all_distributions.sh all

# Generate test report
./scripts/test_all_distributions.sh report
```

## Automated Testing Workflow

### For Ubuntu 22.04:
```bash
# Create the VM
./scripts/qemu_manager.sh create ubuntu-22 4096 20G 2

# Start the VM
./scripts/qemu_manager.sh start ubuntu-22

# Wait for installation to complete (monitor logs: tail -f vms/logs/ubuntu-22.log)

# SSH into the VM to verify installation:
ssh -p 2222 root@localhost
# Check if Docker is available and install if not:
apt update && apt install -y docker.io
systemctl enable --now docker

# Run Mail Server Factory test:
./mail_factory Examples/Ubuntu_22.json
```

### For Debian 12:
```bash
# Create the VM
./scripts/qemu_manager.sh create debian-12 4096 20G 2

# Start the VM
./scripts/qemu_manager.sh start debian-12

# Wait for installation to complete

# SSH into the VM:
ssh -p 2222 root@localhost
# Install Docker:
apt update && apt install -y docker.io
systemctl enable --now docker

# Run Mail Server Factory test:
./mail_factory Examples/Debian_12.json
```

### For Fedora 41:
```bash
# Create the VM
./scripts/qemu_manager.sh create fedora-41 8192 40G 4

# Start the VM
./scripts/qemu_manager.sh start fedora-41

# Wait for installation to complete

# SSH into the VM:
ssh -p 2222 root@localhost
# Install Docker:
dnf install -y docker
systemctl enable --now docker

# Run Mail Server Factory test:
./mail_factory Examples/Fedora_Server_41.json
```

### For AlmaLinux 9:
```bash
# Create the VM
./scripts/qemu_manager.sh create almalinux-9 8192 40G 4

# Start the VM
./scripts/qemu_manager.sh start almalinux-9

# Wait for installation to complete

# SSH into the VM:
ssh -p 2222 root@localhost
# Install Docker:
dnf install -y docker
systemctl enable --now docker

# Run Mail Server Factory test:
./mail_factory Examples/AlmaLinux_9.json
```

### For Rocky Linux 9:
```bash
# Create the VM
./scripts/qemu_manager.sh create rocky-9 8192 40G 4

# Start the VM
./scripts/qemu_manager.sh start rocky-9

# Wait for installation to complete

# SSH into the VM:
ssh -p 2222 root@localhost
# Install Docker:
dnf install -y docker
systemctl enable --now docker

# Run Mail Server Factory test:
./mail_factory Examples/Rocky_9.json
```

## Test Results and Logging

### Log Files Location
- VM creation logs: `vms/logs/`
- ISO download logs: `isos/iso_manager.log`
- Test execution logs: `test_results/`

### Expected Results
- All 12 distributions should successfully install Mail Server Factory
- Docker containers should start correctly on each distribution
- All services (PostgreSQL, Dovecot, Postfix, Rspamd, Redis, ClamAV) should be operational
- End-to-end functionality should work across all distributions

### Error Handling and Troubleshooting
1. If a VM fails to boot:
   - Check `vms/logs/${vm_name}.log` for error details
   - Verify ISO integrity with `./scripts/iso_manager.sh verify`
   - Try recreating the VM: `rm -rf vms/${vm_name} && ./scripts/qemu_manager.sh create ${vm_name}`

2. If Mail Server Factory fails:
   - Check Docker availability in the VM
   - Verify SSH connectivity between host and VM
   - Review configuration files in `Examples/`

3. If tests timeout:
   - Ensure the target system has sufficient resources
   - Check if the VM is properly configured for SSH access
   - Verify Docker service is running in the VM

## Post-Testing Tasks

### Archive VM Images (Optional)
After successful testing, you can create snapshots of the VMs for future testing:
```bash
qemu-img snapshot -c post-test vms/ubuntu-22/ubuntu-22.qcow2
```

### Generate Test Reports
```bash
# Generate comprehensive test report
./scripts/test_all_distributions.sh report

# Find latest test results
ls -la test_results/
```

### Clean Up
```bash
# Stop all VMs when finished
for vm in $(find vms/ -name "qemu.pid" -exec dirname {} \; | xargs -I {} basename {}); do
    ./scripts/qemu_manager.sh stop ${vm}
done

# Remove VMs if no longer needed
rm -rf vms/
```

## Documentation Updates Required

After testing is complete, update the following documentation:
1. `README.md` - Add test results and compatibility matrix
2. `TESTING.md` - Update with latest procedures and findings
3. `docs/QEMU_SETUP.md` - Update with any new findings from testing
4. Update website with compatibility results

## Website Updates

The website should be updated with:
1. Updated compatibility matrix showing tested distributions
2. Success rate of installations across all distributions
3. Known issues and workarounds discovered during testing
4. Performance benchmarks if applicable