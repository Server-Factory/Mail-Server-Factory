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

### Automated Script for Full Testing
```bash
#!/bin/bash
# Complete testing automation script

# Ensure prerequisites
echo "Checking prerequisites..."
if ! command -v qemu-system-x86_64 &> /dev/null; then
    echo "QEMU not installed. Please install: sudo apt install qemu-system-x86 qemu-utils"
    exit 1
fi

if ! command -v docker &> /dev/null; then
    echo "Docker not installed"
    exit 1
fi

# Download ISOs
echo "Downloading ISOs..."
./scripts/iso_manager.sh download

# Create and test each distribution
distributions=("ubuntu-22" "ubuntu-24" "debian-11" "debian-12" "fedora-41" "almalinux-9" "rocky-9")

for dist in "${distributions[@]}"; do
    echo "Testing distribution: $dist"
    
    # Create VM
    echo "Creating VM for $dist..."
    ./scripts/qemu_manager.sh create "$dist"
    
    # Start VM
    echo "Starting VM for $dist..."
    ./scripts/qemu_manager.sh start "$dist"
    
    # Wait for installation (adjust timing based on distribution)
    case "$dist" in
        "ubuntu-"*) sleep 600 ;;  # 10 minutes for Ubuntu
        "debian-"*) sleep 900 ;;  # 15 minutes for Debian
        "fedora-"*) sleep 1800 ;; # 30 minutes for Fedora
        *) sleep 1200 ;;          # 20 minutes for others
    esac
    
    # Run Mail Server Factory test
    dist_for_config=$(echo "$dist" | sed 's/ubuntu-22/Ubuntu_22/' | sed 's/ubuntu-24/Ubuntu_24/' | sed 's/debian-11/Debian_11/' | sed 's/debian-12/Debian_12/' | sed 's/fedora-41/Fedora_Server_41/' | sed 's/almalinux-9/AlmaLinux_9/' | sed 's/rocky-9/Rocky_9/')
    ./scripts/test_all_distributions.sh single "$dist_for_config"
    
    # Stop VM
    ./scripts/qemu_manager.sh stop "$dist"
done

# Generate final report
./scripts/test_all_distributions.sh report
echo "Testing complete! See test_results/ for detailed reports."
```

## Success Criteria

A successful test run includes:
1. All ISOs downloaded and verified
2. All VMs created and booted successfully
3. All OS installations completed without errors
4. Docker installed and running in each VM
5. Mail Server Factory executed successfully with configuration files
6. All mail server components operational
7. Final test report generated with all distributions passing

## Next Steps

1. Execute the complete test suite on a system with adequate resources
2. Document any issues found during testing
3. Update the compatibility matrix with actual test results
4. Update the website with the latest compatibility information
5. Document any necessary configuration adjustments needed for specific distributions