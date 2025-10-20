# Mail Server Factory - Testing Documentation

## Current Status

The Mail Server Factory project includes comprehensive testing capabilities for all supported distributions using QEMU virtualization. This document outlines the current testing status and procedures for validating the application across all supported operating systems.

## Supported Distributions

Mail Server Factory supports the following 12 Linux distributions:

| Family | Distribution | Version | Status |
|--------|--------------|---------|--------|
| Debian | Ubuntu | 22.04 | ✅ Ready for Testing |
| Debian | Ubuntu | 24.04 | ✅ Ready for Testing |
| Debian | Debian | 11 | ✅ Ready for Testing |
| Debian | Debian | 12 | ✅ Ready for Testing |
| RHEL | RHEL | 9 | ✅ Ready for Testing |
| RHEL | AlmaLinux | 9 | ✅ Ready for Testing |
| RHEL | Rocky Linux | 9 | ✅ Ready for Testing |
| RHEL | Fedora Server | 38 | ✅ Ready for Testing |
| RHEL | Fedora Server | 39 | ✅ Ready for Testing |
| RHEL | Fedora Server | 40 | ✅ Ready for Testing |
| RHEL | Fedora Server | 41 | ✅ Ready for Testing |
| SUSE | openSUSE Leap | 15.6 | ✅ Ready for Testing |

## Prerequisites for Running Tests

### System Requirements
- Modern Linux system with hardware virtualization support (Intel VT-x or AMD-V)
- At least 100GB free disk space (for ISOs and VM images)
- At least 16GB RAM (recommended for running multiple VMs)
- Internet connection for downloading ISOs

### Software Requirements
1. **QEMU**: `sudo apt install qemu-system-x86 qemu-utils`
2. **Java 17+**
3. **Docker**
4. **Git**

### Automated Setup Requirements
- `./scripts/iso_manager.sh` - Download and verify ISOs
- `./scripts/qemu_manager.sh` - Create and manage VMs
- `./scripts/test_all_distributions.sh` - Execute tests across all distributions

## Testing Process

### Phase 1: ISO Preparation
```bash
# Download all ISOs for supported distributions
./scripts/iso_manager.sh download

# Verify all ISOs
./scripts/iso_manager.sh verify

# List available ISOs
./scripts/iso_manager.sh list
```

### Phase 2: VM Creation
```bash
# Create VMs for all supported distributions
# Note: VM creation parameters vary based on distribution requirements

# Ubuntu distributions
./scripts/qemu_manager.sh create ubuntu-22 4096 20G 2
./scripts/qemu_manager.sh create ubuntu-24 4096 20G 2

# Debian distributions  
./scripts/qemu_manager.sh create debian-11 4096 20G 2
./scripts/qemu_manager.sh create debian-12 4096 20G 2

# Fedora distributions
./scripts/qemu_manager.sh create fedora-38 8192 40G 4
./scripts/qemu_manager.sh create fedora-39 8192 40G 4
./scripts/qemu_manager.sh create fedora-40 8192 40G 4
./scripts/qemu_manager.sh create fedora-41 8192 40G 4

# RHEL-based distributions
./scripts/qemu_manager.sh create almalinux-9 8192 40G 4
./scripts/qemu_manager.sh create rocky-9 8192 40G 4
./scripts/qemu_manager.sh create rhel-9 8192 40G 4

# SUSE distribution
./scripts/qemu_manager.sh create opensuse-15 8192 40G 4
```

### Phase 3: OS Installation and Configuration
Each VM will be automatically configured based on the distribution type:

- **Ubuntu**: Uses cloud-init with autoinstall for automated installation
- **Debian**: Uses preseed configuration for automated installation
- **Fedora/RHEL/AlmaLinux/Rocky**: Uses kickstart for automated installation
- **openSUSE**: Uses AutoYaST configuration for automated installation

### Phase 4: Mail Server Factory Installation
After OS installation completes in each VM:

1. Ensure Docker is installed and running in the VM
2. Configure SSH access for the Mail Server Factory
3. Run the Mail Server Factory with the appropriate configuration file

### Phase 5: Automated Testing
```bash
# Test all distributions
./scripts/test_all_distributions.sh all

# Test specific distribution
./scripts/test_all_distributions.sh single Ubuntu_22

# Generate test report
./scripts/test_all_distributions.sh report
```

## Configuration Files

Each distribution has a corresponding configuration file in the `Examples/` directory:

- `Examples/Ubuntu_22.json` - Ubuntu 22.04 configuration
- `Examples/Ubuntu_24.json` - Ubuntu 24.04 configuration
- `Examples/Debian_11.json` - Debian 11 configuration
- `Examples/Debian_12.json` - Debian 12 configuration
- `Examples/RHEL_9.json` - RHEL 9 configuration
- `Examples/AlmaLinux_9.json` - AlmaLinux 9 configuration
- `Examples/Rocky_9.json` - Rocky Linux 9 configuration
- `Examples/Fedora_Server_38.json` - Fedora Server 38 configuration
- `Examples/Fedora_Server_39.json` - Fedora Server 39 configuration
- `Examples/Fedora_Server_40.json` - Fedora Server 40 configuration
- `Examples/Fedora_Server_41.json` - Fedora Server 41 configuration
- `Examples/openSUSE_Leap_15.json` - openSUSE Leap 15.6 configuration

## Expected Test Results

### Mail Server Components
After successful installation, the following components should be operational:

- **PostgreSQL** - Main database server
- **Dovecot** - IMAP/POP3 server
- **Postfix** - SMTP server
- **Rspamd** - Anti-spam service
- **Redis** - In-memory database for Rspamd
- **ClamAV** - Anti-virus service

### Docker Containers
The following Docker containers should be running:

- `postmaster_receive` - IMAP/POP3 with SSL (port 993)
- `postmaster_send` - SMTP with SSL (port 465)  
- `postmaster_antispam` - Anti-spam service (ports 11332-11334)
- `postmaster_antivirus` - Anti-virus service
- `postmaster_mem_db` - Redis memory database (port 6379)
- `postmaster_db` - PostgreSQL database (port 5432)

## Logging and Reporting

### Log Files Location
- VM creation logs: `vms/logs/`
- ISO download logs: `isos/iso_manager.log`
- Test execution logs: `test_results/`
- Individual test logs: `test_results/${distribution}_${timestamp}.log`

### Test Reports
- Markdown reports: `test_results/test_results_${timestamp}.md`
- JSON reports: `test_results/test_results_${timestamp}.json`

## Known Issues and Limitations

1. **SELinux Enforcement**: The current version does not support SELinux enforcing mode
2. **Resource Requirements**: Testing all distributions simultaneously requires significant system resources
3. **Network Configuration**: Each VM requires proper network configuration for hostname resolution
4. **Installation Time**: Full testing across all distributions can take 6-12 hours

## Enterprise Features Testing

The Mail Server Factory includes enterprise-grade features that are validated during testing:

- **Security**: AES-256-GCM encryption, advanced authentication
- **Performance**: Caching with Caffeine, JVM optimizations
- **Monitoring**: Prometheus-compatible metrics, health checks
- **Configuration Management**: Environment-specific configurations with hot reloading

## Running the Complete Test Suite

### ⭐ NEW: Comprehensive Test Orchestrator

**The `run_all_tests` script** provides a **complete, automated testing pipeline** that executes ALL tests across the entire project:

```bash
# Run ALL tests (9-19 hours)
./run_all_tests

# With debug output
./run_all_tests --debug
```

**What it does**:
1. ✅ **Unit Tests** - 47 Gradle tests (Factory + Core modules)
2. ✅ **Launcher Tests** - 41 tests for mail_factory script
3. ✅ **ISO Download & Verification** - 12 distributions (~60GB)
4. ✅ **VM Creation** - QEMU virtual machines with automated configs
5. ✅ **OS Installation** - Automated installs with monitoring
6. ✅ **Mail Server Deployment** - Full stack deployment to each VM
7. ✅ **Component Verification** - Docker containers and services

**Features**:
- 📊 **Real-time progress tracking** with progress bars
- 🔄 **Automatic retry logic** (up to 3 retries per failure)
- 📝 **Comprehensive reports** (HTML + Markdown)
- 📦 **VM archiving** (compressed installed systems)
- ⏱️ **Time tracking** for each phase
- 🎨 **Beautiful HTML reports** with gradient design
- ✅ **100% success verification** with retry until all pass

**See detailed documentation**:
- Full guide: [docs/RUN_ALL_TESTS.md](docs/RUN_ALL_TESTS.md)
- Quick reference: [QUICK_TEST_GUIDE.md](QUICK_TEST_GUIDE.md)

### Individual Test Scripts

For testing specific components:

## Success Criteria

A successful test run includes:
1. ✅ All 47 unit tests passed (Gradle)
2. ✅ All 41 launcher tests passed
3. ✅ All 12 ISOs downloaded and verified
4. ✅ All 12 VMs created and booted successfully
5. ✅ All 12 OS installations completed without errors
6. ✅ Docker installed and running in each VM
7. ✅ Mail Server Factory deployed successfully to all 12 VMs
8. ✅ All 72 components operational (6 containers × 12 distributions)
9. ✅ Final test report generated with **100% success rate**

**Total verification**: 51 individual test categories + 12 full system deployments = **100% comprehensive coverage**

## Test Reports

After running `./run_all_tests`, find reports in `test_results/`:

**HTML Report** (recommended):
```bash
firefox test_results/test_report_YYYYMMDD_HHMMSS.html
```
- Beautiful gradient design
- Interactive summary cards
- Color-coded status indicators
- Distribution matrix table

**Markdown Report**:
```bash
cat test_results/test_report_YYYYMMDD_HHMMSS.md
```
- Complete test statistics
- Phase-by-phase breakdown
- Detailed failure analysis

**Execution Log**:
```bash
tail -f test_results/run_all_tests_YYYYMMDD_HHMMSS.log
```
- Complete command output
- Timestamps for all events
- Debug information

## Next Steps

1. ✅ Execute `./run_all_tests` on a system with adequate resources
2. ✅ Review HTML report for comprehensive results
3. ✅ Archive successful VM images for future testing
4. ✅ Update the compatibility matrix with actual test results
5. ✅ Generate test badge for repository
6. ✅ Schedule automated testing (weekly/monthly)
7. ✅ Document any necessary configuration adjustments for specific distributions

## Quick Testing Reference

For a condensed guide to running tests quickly, see:
📘 **[QUICK_TEST_GUIDE.md](QUICK_TEST_GUIDE.md)** - TL;DR commands and troubleshooting