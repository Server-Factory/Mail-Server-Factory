# Distribution Support Summary

Mail Server Factory supports **12 modern Linux server distributions** with comprehensive automation and testing.

## Quick Reference

| Distribution | Version | Configuration | Documentation |
|--------------|---------|---------------|---------------|
| Ubuntu Server | 22.04 LTS | `Examples/Ubuntu_22.json` | [QEMU Setup](docs/QEMU_SETUP.md) |
| Ubuntu Server | 24.04 LTS | `Examples/Ubuntu_24.json` | [QEMU Setup](docs/QEMU_SETUP.md) |
| Debian | 11 | `Examples/Debian_11.json` | [QEMU Setup](docs/QEMU_SETUP.md) |
| Debian | 12 | `Examples/Debian_12.json` | [QEMU Setup](docs/QEMU_SETUP.md) |
| RHEL | 9 | `Examples/RHEL_9.json` | [QEMU Setup](docs/QEMU_SETUP.md) |
| AlmaLinux | 9.5 | `Examples/AlmaLinux_9.json` | [QEMU Setup](docs/QEMU_SETUP.md) |
| Rocky Linux | 9.5 | `Examples/Rocky_9.json` | [QEMU Setup](docs/QEMU_SETUP.md) |
| Fedora Server | 38 | `Examples/Fedora_Server_38.json` | [QEMU Setup](docs/QEMU_SETUP.md) |
| Fedora Server | 39 | `Examples/Fedora_Server_39.json` | [QEMU Setup](docs/QEMU_SETUP.md) |
| Fedora Server | 40 | `Examples/Fedora_Server_40.json` | [QEMU Setup](docs/QEMU_SETUP.md) |
| Fedora Server | 41 | `Examples/Fedora_Server_41.json` | [QEMU Setup](docs/QEMU_SETUP.md) |
| openSUSE Leap | 15.6 | `Examples/openSUSE_Leap_15.json` | [QEMU Setup](docs/QEMU_SETUP.md) |

## Automation Scripts

### 1. ISO Manager (`scripts/iso_manager.sh`)
Download and verify ISOs for all distributions.

```bash
./scripts/iso_manager.sh list      # List all distributions
./scripts/iso_manager.sh download  # Download all ISOs
./scripts/iso_manager.sh verify    # Verify checksums
```

### 2. QEMU Manager (`scripts/qemu_manager.sh`)
Create and manage QEMU virtual machines.

```bash
./scripts/qemu_manager.sh create ubuntu-22  # Create VM
./scripts/qemu_manager.sh start ubuntu-22   # Start VM
./scripts/qemu_manager.sh list              # List VMs
./scripts/qemu_manager.sh stop ubuntu-22    # Stop VM
```

### 3. Distribution Tester (`scripts/test_all_distributions.sh`)
Run comprehensive installation tests.

```bash
./scripts/test_all_distributions.sh all          # Test all distributions
./scripts/test_all_distributions.sh single Ubuntu_22  # Test one
./scripts/test_all_distributions.sh report       # Generate report
```

## Documentation

- **[QEMU Setup Guide](docs/QEMU_SETUP.md)** - Complete QEMU VM setup instructions
- **[Distribution Testing](docs/DISTRIBUTION_TESTING.md)** - Comprehensive testing documentation
- **[Deployment Summary](docs/DEPLOYMENT_SUMMARY.md)** - Executive summary of all features
- **[Main README](README.md)** - Project overview and getting started

## Quick Start

```bash
# 1. Download ISOs
./scripts/iso_manager.sh download

# 2. Create a VM
./scripts/qemu_manager.sh create ubuntu-22

# 3. Start the VM
./scripts/qemu_manager.sh start ubuntu-22

# 4. Access VM (after installation completes)
ssh -p 2222 root@localhost

# 5. Run tests
./scripts/test_all_distributions.sh single Ubuntu_22
```

## Status

✅ **All 12 distributions fully configured and validated**
- Configuration files validated (JSON syntax)
- ISO download automation ready
- QEMU VM automation ready
- Testing automation ready
- Comprehensive documentation created
- Website updated with distribution matrix

## Support

- GitHub: https://github.com/Server-Factory/Mail-Server-Factory
- Issues: https://github.com/Server-Factory/Mail-Server-Factory/issues
- Documentation: https://server-factory.github.io/Mail-Server-Factory/
