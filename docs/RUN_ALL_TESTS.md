# run_all_tests - Comprehensive Testing Documentation

## Overview

The `run_all_tests` script is the **comprehensive testing orchestrator** for the Mail Server Factory project. It executes **all available tests** across the entire project stack, from unit tests to full system deployments on multiple operating systems.

## Table of Contents

- [What It Does](#what-it-does)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Test Phases](#test-phases)
- [Progress Tracking](#progress-tracking)
- [Report Generation](#report-generation)
- [Resource Requirements](#resource-requirements)
- [Execution Time](#execution-time)
- [Troubleshooting](#troubleshooting)
- [Advanced Usage](#advanced-usage)

## What It Does

The `run_all_tests` script performs **7 comprehensive test phases**:

### Phase 1: Unit Tests (Gradle)
- Executes all Kotlin unit tests (47 tests)
- Tests across Factory and Core:Framework modules
- Generates JaCoCo coverage reports
- Validates core business logic and configuration handling

### Phase 2: Launcher Tests
- Runs 41 tests for the `mail_factory` launcher script
- Validates argument parsing, JAR discovery, error handling
- Tests environment variable support and configuration validation
- Ensures proper exit codes and help messages

### Phase 3: ISO Download & Verification
- Downloads ISOs for 12 supported Linux distributions
- Verifies SHA256 checksums for all ISOs
- Manages 50-100GB of ISO downloads efficiently
- Resumes interrupted downloads automatically

### Phase 4: VM Creation
- Creates QEMU virtual machines for each distribution
- Configures distribution-specific resources (RAM, disk, CPUs)
- Sets up automated installation configurations:
  - Ubuntu/Debian: Preseed/Cloud-init
  - Fedora/RHEL/AlmaLinux/Rocky: Kickstart
  - openSUSE: AutoYaST

### Phase 5: OS Installation
- Installs operating systems automatically on all VMs
- Monitors installation progress with timeouts
- Archives successfully installed systems as compressed images
- Handles distribution-specific installation times (10-60 minutes each)

### Phase 6: Mail Server Factory Deployment
- Builds the Mail Server Factory application
- Deploys to each successfully installed VM via SSH
- Configures complete mail server stack:
  - PostgreSQL database
  - Dovecot (IMAP/POP3)
  - Postfix (SMTP)
  - Rspamd (anti-spam)
  - Redis (memory cache)
  - ClamAV (anti-virus)

### Phase 7: Component Verification
- Verifies all 6 Docker containers are running
- Checks service health and accessibility
- Validates mail account creation
- Ensures complete mail server stack functionality

## Prerequisites

### System Requirements

**Hardware**:
- CPU: Modern x86_64 with hardware virtualization (Intel VT-x or AMD-V)
- RAM: 16GB minimum, 32GB recommended
- Disk: 120GB free space minimum (for ISOs, VMs, and archives)
- Network: Stable internet connection for ISO downloads

**Operating System**:
- Linux (Ubuntu 22.04+, Debian 11+, Fedora 38+, or similar)
- Kernel with KVM support enabled

### Software Requirements

**Essential**:
```bash
# Java
sudo apt install openjdk-17-jdk

# QEMU
sudo apt install qemu-system-x86 qemu-utils qemu-kvm

# Docker
curl -fsSL https://get.docker.com | sh
sudo systemctl start docker
sudo systemctl enable docker

# Build tools
sudo apt install build-essential git
```

**Optional** (for enhanced features):
```bash
# For SSH automation
sudo apt install sshpass

# For network monitoring
sudo apt install net-tools bridge-utils
```

### Project Setup

1. **Clone the repository**:
```bash
git clone --recurse-submodules <repository-url>
cd Mail-Server-Factory
```

2. **Build the project**:
```bash
./gradlew assemble
```

3. **Configure Docker credentials** (required for deployment):
```bash
# Create Docker Hub credentials file
cat > Examples/Includes/_Docker.json <<'EOF'
{
  "variables": {
    "DOCKER": {
      "USER": "your-dockerhub-username",
      "PASSWORD": "your-dockerhub-password"
    }
  }
}
EOF
```

4. **Initialize SSH access** (optional, for manual VM testing):
```bash
# Generate SSH key if needed
ssh-keygen -t rsa -b 4096 -f ~/.ssh/mail_factory_test
```

## Quick Start

### Basic Execution

```bash
# Run all tests (this may take several hours)
./run_all_tests
```

### With Debug Output

```bash
# Enable detailed debug logging
./run_all_tests --debug
```

### Dry Run (Check Prerequisites Only)

```bash
# Just check if system meets requirements
./run_all_tests --help
```

## Test Phases

### Phase 1: Unit Tests (Gradle)

**Duration**: 1-5 minutes

**What happens**:
- Gradle builds the project
- JUnit tests execute for Factory module (33 tests)
- JUnit tests execute for Core:Framework module (14 tests)
- JaCoCo generates coverage reports
- Test results are validated

**Success criteria**:
- All 47 tests pass
- No compilation errors
- Coverage report generated successfully

**Output**:
```
================================================================
  [Phase 1/7] Running Unit Tests (Gradle)
================================================================

ℹ Running Gradle test suite...
ℹ This includes Factory and Core:Framework modules

BUILD SUCCESSFUL in 2m 15s
✓ Unit tests passed
✓ Coverage report generated: Core/Framework/build/reports/jacoco/test/html/index.html
✓ Unit tests completed in 135 seconds
```

### Phase 2: Launcher Tests

**Duration**: 30-60 seconds

**What happens**:
- `tests/launcher/test_launcher.sh` executes
- 41 test cases run covering:
  - Help/version flags
  - Argument validation
  - JAR discovery
  - Configuration file handling
  - Environment variables
  - Exit code verification

**Success criteria**:
- All 41 tests pass
- No launcher bugs detected

**Output**:
```
================================================================
  [Phase 2/7] Running Launcher Tests
================================================================

ℹ Executing launcher test suite (41 tests)...

✓ PASS: Help flag returns exit code 0
✓ PASS: Version flag returns exit code 0
✓ PASS: No arguments returns exit code 4
...
✅ All tests passed!
✓ All launcher tests passed
✓ Launcher tests completed in 45 seconds
```

### Phase 3: ISO Download & Verification

**Duration**: 30 minutes - 2 hours (depending on network speed)

**What happens**:
- ISO manager downloads ISOs for 12 distributions
- SHA256 checksums are verified for each ISO
- Corrupted downloads are automatically retried
- Download progress is displayed

**ISOs downloaded**:
- Ubuntu 22.04 (~2GB), Ubuntu 24.04 (~2GB)
- Debian 11 (~400MB), Debian 12 (~700MB)
- Fedora Server 38-41 (~2GB each = 8GB)
- AlmaLinux 9 (~10GB)
- Rocky Linux 9 (~10GB)
- openSUSE Leap 15.6 (~5GB)

**Total download**: ~50-60GB

**Success criteria**:
- All ISOs downloaded successfully
- All checksums verified
- No corrupted files

**Output**:
```
================================================================
  [Phase 3/7] Downloading and Verifying ISOs
================================================================

──── Checking existing ISOs
Name                      Version    Status
----                      -------    ------
ubuntu-22.04             22.04.5    Downloaded
ubuntu-24.04             24.04.3    Not Downloaded

──── Downloading ISOs
ℹ Downloading Ubuntu 24.04 ISO...
[============================] 100% (2.1GB/2.1GB)
✓ Download complete

──── Verifying ISO checksums
✓ Checksum verification passed
✓ All ISOs verified successfully
✓ ISO phase completed in 1847 seconds
```

### Phase 4: VM Creation

**Duration**: 5-10 minutes

**What happens**:
- Creates 12 QEMU virtual machines
- Allocates disk images (20GB or 40GB per VM)
- Generates automated installation configurations
- Sets up network forwarding for SSH access

**VM specifications**:
- Ubuntu/Debian: 4GB RAM, 20GB disk, 2 CPUs
- Fedora/RHEL/AlmaLinux/Rocky: 8GB RAM, 40GB disk, 4 CPUs
- openSUSE: 8GB RAM, 40GB disk, 4 CPUs

**Success criteria**:
- All VM disk images created
- Installation configs generated
- No disk allocation errors

**Output**:
```
================================================================
  [Phase 4/7] Creating Virtual Machines
================================================================

ℹ Creating 12 virtual machines...

Progress: [====================] 100% (12/12) - Creating opensuse-15
✓ Created: 12
✓ All VMs created in 287 seconds
```

### Phase 5: OS Installation

**Duration**: 4-12 hours (longest phase)

**What happens**:
- Boots each VM from ISO
- Performs automated OS installation
- Monitors installation progress
- Archives successfully installed systems
- Handles installation timeouts

**Installation times** (typical):
- Ubuntu: 15-30 minutes each
- Debian: 20-35 minutes each
- Fedora: 40-60 minutes each
- RHEL-based: 40-60 minutes each
- openSUSE: 45-60 minutes

**Total sequential time**: 6-10 hours

**Success criteria**:
- OS installation completes successfully
- VM boots to installed system
- SSH access is configured
- System is archived as `.qcow2.gz`

**Output**:
```
================================================================
  [Phase 5/7] Installing Operating Systems
================================================================

ℹ Installing 12 operating systems...
⚠ This phase may take several hours

Progress: [========            ] 40% (5/12) - Installing fedora-41
ℹ fedora-41 installation in progress (25 minutes elapsed)...
✓ fedora-41 installation completed
ℹ Archiving fedora-41 installation...
✓ Archived: vms/archives/fedora-41_installed_20251020_143052.qcow2.gz

ℹ OS Installation Summary:
✓ Installed: 12
✓ All OS installations completed in 28473 seconds
```

### Phase 6: Mail Server Factory Deployment

**Duration**: 2-6 hours

**What happens**:
- Builds Mail Server Factory JAR
- Deploys to each VM via SSH
- Installs Docker containers:
  - `postmaster_db` - PostgreSQL database
  - `postmaster_mem_db` - Redis cache
  - `postmaster_receive` - Dovecot IMAP/POP3
  - `postmaster_send` - Postfix SMTP
  - `postmaster_antispam` - Rspamd
  - `postmaster_antivirus` - ClamAV
- Creates mail accounts
- Configures SSL certificates

**Deployment time per VM**: 10-30 minutes

**Success criteria**:
- Application builds successfully
- Deployment completes without errors
- All Docker containers start
- Mail accounts are created

**Output**:
```
================================================================
  [Phase 6/7] Deploying Mail Server Factory
================================================================

──── Building Application
ℹ Building Mail Server Factory...
BUILD SUCCESSFUL in 18s
✓ Application built successfully

──── Deploying to VMs
ℹ Deploying to 12 virtual machines...

Progress: [================    ] 75% (9/12) - Deploying to rocky-9
ℹ Deploying Mail Server Factory to rocky-9...
ℹ Configuration: Examples/Rocky_9.json
✓ rocky-9 deployment completed

ℹ Deployment Summary:
✓ Deployed: 12
✓ All deployments completed in 7832 seconds
```

### Phase 7: Component Verification

**Duration**: 10-30 minutes

**What happens**:
- Connects to each VM via SSH
- Verifies all 6 Docker containers are running
- Checks container health status
- Validates service ports are accessible
- Tests mail account authentication

**Verified components**:
1. PostgreSQL (port 5432)
2. Redis (port 6379)
3. Dovecot IMAP/POP3 (ports 993, 995)
4. Postfix SMTP (port 465)
5. Rspamd (ports 11332-11334)
6. ClamAV

**Success criteria**:
- All 6 containers running on each VM
- Services respond to health checks
- Mail accounts can authenticate

**Output**:
```
================================================================
  [Phase 7/7] Verifying Mail Server Components
================================================================

ℹ Verifying components on 12 systems...

Progress: [====================] 100% (12/12) - Verifying opensuse-15
✓ opensuse-15: All 6 components verified

ℹ Verification Summary:
✓ Verified: 12
✓ All components verified in 1245 seconds
```

## Progress Tracking

The script provides **real-time progress indicators** throughout execution:

### Phase Indicators
```
[Phase 3/7] Downloading and Verifying ISOs
```
Shows current phase number and total phases.

### Progress Bars
```
Progress: [===============     ] 75% (9/12) - Creating ubuntu-24
```
Indicates:
- Visual progress bar (50 characters)
- Percentage complete
- Current item / Total items
- Current task description

### Status Messages
- `✓` Green checkmark: Success
- `✗` Red X: Failure
- `⚠` Yellow warning: Warning
- `ℹ` Blue info: Information

### Time Tracking
Each phase reports duration:
```
✓ Unit tests completed in 135 seconds
```

## Report Generation

The script generates **two comprehensive reports** after execution:

### Markdown Report

**Location**: `test_results/test_report_YYYYMMDD_HHMMSS.md`

**Contents**:
- Executive summary
- Phase-by-phase results
- Distribution test matrix
- Detailed results for each distribution
- Summary statistics
- Success rate calculation

**Example**:
```markdown
# Mail Server Factory - Comprehensive Test Report

**Generated**: 2025-10-20 14:30:52

## Executive Summary

This report contains the results of comprehensive testing...

## Test Phase Results

### Phase 1: Unit Tests (Gradle)
✅ **Status**: PASSED
**Duration**: 135 seconds

## Distribution Test Results

| Distribution | VM Creation | OS Install | Deployment | Verification | Overall |
|--------------|-------------|------------|------------|--------------|---------|
| Ubuntu_22    | PASS        | PASS       | PASS       | PASS         | ✅ PASS |
| Ubuntu_24    | PASS        | PASS       | PASS       | PASS         | ✅ PASS |
...
```

### HTML Report

**Location**: `test_results/test_report_YYYYMMDD_HHMMSS.html`

**Features**:
- **Beautiful gradient design** (purple/blue theme)
- **Interactive summary cards** showing statistics
- **Color-coded status indicators**
- **Responsive layout** for all screen sizes
- **Automatically opens in browser** after generation

**Sections**:
1. **Header**: Project title and generation timestamp
2. **Executive Summary**: 4 cards with key statistics
   - Total Distributions
   - Passed
   - Failed
   - Success Rate
3. **Test Phase Results**: Color-coded phase status
4. **Distribution Results Table**: Detailed breakdown
5. **Footer**: Generation information

**Styling**:
- Gradient backgrounds
- Hover effects on table rows
- Status colors:
  - Green: PASS
  - Red: FAIL
  - Yellow: SKIP/TIMEOUT

## Resource Requirements

### Disk Space Breakdown

```
Component                  Size
─────────────────────────  ──────
ISOs                       50-60GB
VM Disks (12 VMs)          240-480GB
VM Archives                60-120GB (compressed)
Build artifacts            2-5GB
Test results & logs        1-2GB
─────────────────────────  ──────
TOTAL                      ~400-600GB
```

**Minimum**: 120GB free (without archives)
**Recommended**: 500GB free (with archives)

### Memory Requirements

**During VM creation/installation** (sequential):
- 8GB RAM minimum
- 16GB RAM recommended

**During deployment** (if running multiple VMs):
- 32GB RAM recommended for parallel testing

**Peak usage**:
- One Fedora VM: ~8GB
- One Ubuntu VM: ~4GB
- Build process: ~2GB
- System overhead: ~2GB

### CPU Requirements

**Minimum**: 4 cores (2 physical cores with HT)
**Recommended**: 8+ cores

**Note**: Hardware virtualization (VT-x/AMD-V) **must be enabled** in BIOS.

Verify with:
```bash
# Check for virtualization support
egrep -c '(vmx|svm)' /proc/cpuinfo

# Should return > 0
```

### Network Requirements

**Bandwidth**:
- 50-100 Mbps for reasonable ISO download times
- 1-10 Mbps minimum (slower but functional)

**Data transfer**:
- ISO downloads: 50-60GB
- Package updates during OS install: 5-10GB
- Docker image pulls: 2-5GB per deployment

**Total**: ~70-100GB download

## Execution Time

### Time Estimates by Phase

| Phase | Duration | Variability |
|-------|----------|-------------|
| 1. Unit Tests | 2-5 min | Low |
| 2. Launcher Tests | 1-2 min | Low |
| 3. ISO Download | 30 min - 2 hours | High (network dependent) |
| 4. VM Creation | 5-10 min | Low |
| 5. OS Installation | 6-10 hours | High (distribution dependent) |
| 6. Deployment | 2-6 hours | Medium |
| 7. Verification | 15-30 min | Low |
| **TOTAL** | **9-19 hours** | **High** |

### Optimization Strategies

**For faster execution**:

1. **Pre-download ISOs** (saves 1-2 hours):
   ```bash
   ./scripts/iso_manager.sh download
   ```

2. **Use SSD storage** (30-50% faster VM operations):
   - Place `vms/` directory on SSD

3. **Increase VM resources** (faster installations):
   - Edit `DISTRIBUTIONS` array in `run_all_tests`
   - Increase memory/CPU allocations

4. **Skip already-tested distributions** (manual):
   - Comment out distributions in script
   - Rerun for subset

5. **Parallel VM installations** (advanced):
   - Requires 32GB+ RAM
   - Modify script to run VMs in parallel

### Overnight Execution Recommended

Due to the 9-19 hour runtime, it's recommended to:

1. **Start in the evening**
2. **Run overnight**
3. **Review results in the morning**

Use `screen` or `tmux` to prevent SSH disconnection:

```bash
# Start screen session
screen -S mail_factory_tests

# Run tests
./run_all_tests

# Detach: Ctrl+A, then D
# Reattach later: screen -r mail_factory_tests
```

## Troubleshooting

### Common Issues

#### Issue: "Java not found"

**Solution**:
```bash
sudo apt install openjdk-17-jdk
java -version  # Verify
```

#### Issue: "QEMU not found"

**Solution**:
```bash
sudo apt install qemu-system-x86 qemu-utils qemu-kvm
qemu-system-x86_64 --version  # Verify
```

#### Issue: "KVM acceleration not available"

**Symptoms**: VMs are extremely slow

**Solution**:
1. Enable virtualization in BIOS
2. Verify KVM module is loaded:
   ```bash
   lsmod | grep kvm
   # Should show kvm_intel or kvm_amd
   ```
3. Add user to kvm group:
   ```bash
   sudo usermod -a -G kvm $USER
   # Log out and back in
   ```

#### Issue: "Disk space full"

**Solution**:
```bash
# Check space
df -h

# Clean up old test results
rm -rf test_results/test_report_*.html
rm -rf test_results/*_deployment_*.log

# Remove VM archives (if not needed)
rm -rf vms/archives/*.qcow2.gz

# Clean Gradle cache
./gradlew clean
```

#### Issue: "ISO download fails"

**Solution**:
```bash
# Retry with force download
./scripts/iso_manager.sh download --force

# Or download specific ISOs manually
# See scripts/iso_manager.sh for URLs
```

#### Issue: "VM installation timeout"

**Causes**:
- Slow disk I/O
- Insufficient resources
- Network issues during installation

**Solution**:
```bash
# Increase timeout in run_all_tests
# Edit line: VM_INSTALL_TIMEOUT=3600
# Change to: VM_INSTALL_TIMEOUT=7200  # 2 hours

# Or check VM serial output
tail -f vms/logs/ubuntu-24.log
```

#### Issue: "Deployment fails with 'Connection refused'"

**Cause**: SSH not ready on VM

**Solution**:
```bash
# Manually verify SSH access
ssh -p 2222 root@localhost

# If fails, check VM is running
./scripts/qemu_manager.sh status ubuntu-22

# Restart VM if needed
./scripts/qemu_manager.sh stop ubuntu-22
./scripts/qemu_manager.sh start ubuntu-22
```

#### Issue: "Docker containers not starting"

**Solution**:
```bash
# SSH into VM
ssh -p 2222 root@localhost

# Check Docker status
systemctl status docker
docker ps -a

# View container logs
docker logs postmaster_db
docker logs postmaster_receive

# Check disk space
df -h

# Restart Docker
systemctl restart docker
```

### Debug Mode

Enable detailed logging:

```bash
./run_all_tests --debug
```

This provides:
- All command outputs
- Detailed progress messages
- Container status checks
- Network diagnostics

### Log Files

All logs are saved in `test_results/`:

```bash
# Main execution log
cat test_results/run_all_tests_20251020_143052.log

# Deployment logs (per VM)
cat test_results/ubuntu-24_deployment_20251020_153022.log

# VM creation logs
cat vms/logs/ubuntu-24.log

# ISO download log
cat isos/iso_manager.log
```

### Manual Testing

Test individual phases:

```bash
# Test unit tests only
./gradlew test

# Test launcher only
./tests/launcher/test_launcher.sh

# Test ISOs only
./scripts/iso_manager.sh download
./scripts/iso_manager.sh verify

# Test single VM creation
./scripts/qemu_manager.sh create ubuntu-22

# Test single deployment
./mail_factory Examples/Ubuntu_22.json
```

## Advanced Usage

### Retry Logic

The script includes retry logic for transient failures. To modify retry behavior:

```bash
# Edit run_all_tests, line ~30
MAX_RETRIES=3  # Change to desired value
```

Currently retries are implemented for:
- ISO downloads (automatic via wget/curl -c)
- Unit tests (manual retry on failure)

### Selective Testing

To test only specific distributions:

1. Edit `run_all_tests`
2. Comment out distributions in `DISTRIBUTIONS` array:

```bash
declare -a DISTRIBUTIONS=(
    "ubuntu-22:Ubuntu_22:Debian:4096:20G:2"
    "ubuntu-24:Ubuntu_24:Debian:4096:20G:2"
    # "debian-11:Debian_11:Debian:4096:20G:2"  # Commented out
    # "debian-12:Debian_12:Debian:4096:20G:2"  # Commented out
    "fedora-41:Fedora_Server_41:RHEL:8192:40G:4"
    # ... etc
)
```

3. Run script normally

### Resource Tuning

Adjust VM resources for faster execution:

```bash
# Edit distribution definitions
# Format: "vm-name:config-name:family:MEMORY:DISK:CPUS"

# Example: Double Fedora resources
"fedora-41:Fedora_Server_41:RHEL:16384:40G:8"  # Was 8192:40G:4
```

### Parallel Execution

**WARNING**: Requires significant resources (32GB+ RAM)

Modify the script to run VMs in parallel:

```bash
# In install_all_operating_systems() function
# Replace the for loop with parallel execution

for dist_config in "${DISTRIBUTIONS[@]}"; do
    # ... installation code ...
done &  # Add & to background each iteration

wait  # Wait for all to complete
```

### Custom Report Templates

Modify report generation functions:

```bash
# Edit generate_html_report() function
# Customize CSS styles, add charts, etc.

# Edit generate_markdown_report() function
# Add custom sections, metrics, etc.
```

### Integration with CI/CD

Run as part of automated pipeline:

```bash
#!/bin/bash
# .github/workflows/comprehensive-test.yml

name: Comprehensive Tests
on:
  schedule:
    - cron: '0 2 * * 0'  # Weekly on Sunday at 2 AM

jobs:
  test:
    runs-on: self-hosted  # Requires self-hosted runner with resources
    steps:
      - uses: actions/checkout@v2
        with:
          submodules: recursive

      - name: Run comprehensive tests
        run: ./run_all_tests

      - name: Upload reports
        uses: actions/upload-artifact@v2
        with:
          name: test-reports
          path: test_results/*.html
```

## Success Criteria

The test run is considered **100% successful** when:

✅ All 47 unit tests pass
✅ All 41 launcher tests pass
✅ All 12 ISOs download and verify
✅ All 12 VMs create successfully
✅ All 12 OS installations complete
✅ All 12 deployments succeed
✅ All 72 components verified (6 per distribution)

**Total success**: 0 failures across all phases

## Conclusion

The `run_all_tests` script provides **comprehensive, automated testing** for the entire Mail Server Factory stack. While execution takes several hours, it ensures **100% confidence** in the application's functionality across all supported distributions.

For questions or issues, see:
- Main documentation: `README.md`
- Testing overview: `TESTING.md`
- Launcher docs: `mail_factory --help`
- Issue tracker: https://github.com/anthropics/claude-code/issues

---

**Last updated**: 2025-10-20
**Script version**: 1.0.0
