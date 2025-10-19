# Mail Server Factory - Orchestration Guide

This guide explains how to run the complete automated testing workflow for all supported Linux distributions.

## Overview

The orchestration system automates:
1. ISO downloads and verification
2. QEMU VM creation
3. OS installation (non-interactive)
4. VM archiving
5. Mail Server Factory testing
6. Report generation
7. Documentation updates

**All processes run in the background** with periodic status monitoring to prevent hangs.

## Quick Start

### Option 1: Run Complete Workflow

```bash
# Start complete workflow in background
nohup ./scripts/master_orchestrator.sh all > orchestration.log 2>&1 &

# Monitor progress
./scripts/process_monitor.sh watch
```

### Option 2: Run Individual Phases

```bash
# Phase 1: Download ISOs
./scripts/master_orchestrator.sh download-isos

# Phase 2: Verify ISOs
./scripts/master_orchestrator.sh verify-isos

# Phase 3: Create VMs
./scripts/master_orchestrator.sh create-vms

# Phase 4: Monitor installations
./scripts/master_orchestrator.sh monitor-vms

# Phase 5: Archive VMs
./scripts/master_orchestrator.sh archive-vms

# Phase 6: Run tests
./scripts/master_orchestrator.sh test

# Phase 7: Generate reports
./scripts/master_orchestrator.sh report
```

## Monitoring

### Real-time Status Dashboard

```bash
# Auto-refreshing dashboard (updates every 30 seconds)
./scripts/process_monitor.sh watch
```

### One-time Status Checks

```bash
# Show all running processes
./scripts/process_monitor.sh status

# Show VM status
./scripts/process_monitor.sh vms

# Show downloaded ISOs
./scripts/process_monitor.sh isos

# Show test results
./scripts/process_monitor.sh tests

# Show everything
./scripts/process_monitor.sh all

# Show process logs
./scripts/process_monitor.sh logs
```

### Manual Log Inspection

```bash
# Master orchestration log
tail -f orchestration_logs/master_*.log

# ISO download log
tail -f orchestration_logs/iso_download.log

# VM creation logs
tail -f orchestration_logs/vm_create_*.log

# Test execution log
tail -f orchestration_logs/mail_tests.log

# Individual VM serial console
tail -f vms/ubuntu-22/serial.log
```

## Process Management

### Kill Stuck Process

If a process hangs or gets stuck:

```bash
# Kill specific process
./scripts/process_monitor.sh kill iso_download
./scripts/process_monitor.sh kill vm_create_ubuntu-22
./scripts/process_monitor.sh kill mail_tests

# Find all running processes
ps aux | grep master_orchestrator

# Force kill orchestrator
pkill -9 -f master_orchestrator
```

### Restart Failed Phase

```bash
# If ISO download failed, retry
./scripts/master_orchestrator.sh download-isos

# If specific VM failed, recreate it
./scripts/qemu_manager.sh delete ubuntu-22
./scripts/qemu_manager.sh create ubuntu-22 4096 20G 2
```

## Resource Requirements

### Minimum System Requirements

- **Disk Space**: 100GB free (for ISOs and VMs)
- **RAM**: 16GB (8GB allocated to VMs, 8GB for host)
- **CPU**: 4+ cores with hardware virtualization (Intel VT-x / AMD-V)
- **Network**: Broadband connection (for ISO downloads)

### Resource Allocation Per Distribution

| Distribution | Memory | Disk | CPUs | Install Time |
|--------------|--------|------|------|--------------|
| Ubuntu 22/24 | 4GB | 20GB | 2 | 10-15 min |
| Debian 11/12 | 4GB | 20GB | 2 | 15-20 min |
| Fedora 38-41 | 8GB | 40GB | 4 | 25-35 min |
| RHEL 9 | 8GB | 40GB | 4 | 30-40 min |
| AlmaLinux 9 | 8GB | 40GB | 4 | 25-35 min |
| Rocky Linux 9 | 8GB | 40GB | 4 | 25-35 min |
| openSUSE 15.6 | 8GB | 40GB | 4 | 30-45 min |

### Expected Disk Usage

```
isos/                  ~50GB (all distribution ISOs)
vms/                   ~200GB (all VM disks)
vms/archive/           ~200GB (archived VMs)
test_results/          ~100MB (logs and reports)
orchestration_logs/    ~500MB (orchestration logs)
```

## Timeline

### Complete Workflow Duration

**Total estimated time: 6-12 hours**

| Phase | Duration | Notes |
|-------|----------|-------|
| ISO Download | 1-3 hours | Depends on internet speed |
| ISO Verification | 5-10 minutes | Checksums validation |
| VM Creation | 5-10 minutes | Disk image creation |
| OS Installation | 3-6 hours | All VMs install in parallel |
| VM Archiving | 30-60 minutes | Compress VM images |
| Mail Server Tests | 2-4 hours | Sequential testing per VM |
| Report Generation | 5 minutes | Compile test results |

### Per-Distribution Timeline

- **Fast installs** (Ubuntu, Debian): 15-20 minutes
- **Medium installs** (Fedora, AlmaLinux, Rocky): 30-40 minutes
- **Slow installs** (RHEL, openSUSE): 40-60 minutes

## Troubleshooting

### Process Stuck/Hanging

**Symptoms**: Process shows "Running" for longer than expected timeout

**Resolution**:
```bash
# Check which process is stuck
./scripts/process_monitor.sh status

# Kill the stuck process
./scripts/process_monitor.sh kill <process_name>

# Check logs for errors
cat orchestration_logs/<process_name>.log

# Restart the specific phase
./scripts/master_orchestrator.sh <phase-name>
```

### ISO Download Failures

**Symptoms**: ISO download process fails or times out

**Resolution**:
```bash
# Check download status
./scripts/iso_manager.sh list

# Retry download for specific ISO
./scripts/iso_manager.sh download

# Download single ISO manually
cd isos
wget <iso-url>
sha256sum -c <checksum-file>
```

### VM Creation Failures

**Symptoms**: VM fails to create or start

**Resolution**:
```bash
# Check QEMU installation
which qemu-system-x86_64
qemu-system-x86_64 --version

# Check hardware virtualization
egrep -c '(vmx|svm)' /proc/cpuinfo  # Should be > 0

# Delete and recreate VM
./scripts/qemu_manager.sh delete <distro>
./scripts/qemu_manager.sh create <distro> <memory> <disk> <cpus>

# Check VM logs
cat vms/<distro>/creation.log
cat vms/logs/<distro>_*.log
```

### VM Installation Hangs

**Symptoms**: VM stuck during OS installation

**Resolution**:
```bash
# Check serial console output
tail -100 vms/<distro>/serial.log

# Check if VM is consuming CPU
top | grep qemu

# Check preseed/kickstart configuration
cat preseeds/<distro>-*.cfg

# Restart VM installation
./scripts/qemu_manager.sh stop <distro>
./scripts/qemu_manager.sh delete <distro>
./scripts/qemu_manager.sh create <distro> <memory> <disk> <cpus>
```

### Mail Server Test Failures

**Symptoms**: Mail Server Factory tests fail on specific distribution

**Resolution**:
```bash
# Check test logs
cat test_results/<distro>_*.log

# SSH into VM to debug
ssh mailtest@<distro>.local  # Password: WhiteSnake8587

# Check Docker on VM
ssh mailtest@<distro>.local "docker ps -a"

# Manually run Mail Server Factory on VM
./mail_factory Examples/<Distribution>.json
```

### Disk Space Issues

**Symptoms**: Process fails with "No space left on device"

**Resolution**:
```bash
# Check disk usage
df -h .
du -sh isos/ vms/ vms/archive/

# Clean up old archives
rm -rf vms/archive/*

# Delete old test results
rm -rf test_results/*

# Delete ISOs after VMs are created
rm -rf isos/*.iso
```

## Safety Features

### Automatic Timeout Protection

Each process has a maximum execution time:

- **ISO Download**: 2 hours
- **VM Creation**: 1 hour per VM
- **VM Installation**: 90 minutes per VM
- **Mail Server Tests**: 2 hours total

If a process exceeds its timeout, it is automatically killed.

### Process Monitoring

The orchestrator checks process status every 30 seconds:
- Verifies process is running
- Checks elapsed time vs. timeout
- Kills process if timeout exceeded
- Logs all activities

### Graceful Shutdown

The orchestrator handles signals properly:
```bash
# Send SIGTERM for graceful shutdown
kill -TERM <orchestrator-pid>

# Wait 10 seconds, then force kill if needed
kill -KILL <orchestrator-pid>
```

### Cleanup on Exit

When orchestrator exits (normal or error):
- All child processes are killed
- PID files are removed
- Logs are finalized
- Temporary files are cleaned

## Directory Structure

```
Mail-Server-Factory/
├── scripts/
│   ├── master_orchestrator.sh      # Main orchestration script
│   ├── process_monitor.sh          # Status monitoring
│   ├── iso_manager.sh              # ISO download/verify
│   ├── qemu_manager.sh             # VM lifecycle
│   └── test_all_distributions.sh   # Testing script
├── preseeds/                       # Auto-install configs
├── isos/                           # Downloaded ISOs
├── vms/                            # VM images
│   ├── <distro>/                   # Per-VM directory
│   │   ├── disk.qcow2              # VM disk
│   │   ├── vm.pid                  # QEMU PID
│   │   └── serial.log              # Console output
│   ├── archive/                    # Archived VMs
│   └── logs/                       # VM creation logs
├── orchestration_logs/             # Orchestration logs
│   ├── master_*.log                # Master log
│   ├── pids/                       # Process PIDs
│   └── status.json                 # Status file
└── test_results/                   # Test reports
    ├── test_results_*.md           # Markdown reports
    └── test_results_*.json         # JSON reports
```

## Best Practices

### Before Starting

1. **Check disk space**: `df -h .` (ensure 100GB+ free)
2. **Check internet**: `ping -c 5 google.com`
3. **Check hardware virtualization**: `egrep -c '(vmx|svm)' /proc/cpuinfo`
4. **Check QEMU**: `qemu-system-x86_64 --version`
5. **Check Docker**: `docker --version`

### During Execution

1. **Monitor regularly**: Use watch mode or check every 30-60 minutes
2. **Review logs**: Check for errors or warnings
3. **Watch resources**: Monitor CPU, memory, disk usage
4. **Be patient**: Full workflow takes 6-12 hours

### After Completion

1. **Review test results**: Check `test_results/` directory
2. **Archive VMs**: VMs are in `vms/archive/` for reuse
3. **Clean up**: Delete ISOs if disk space is limited
4. **Update documentation**: Review and update README/TESTING.md

## Support

If issues persist:

1. **Check logs**: Review all logs in `orchestration_logs/`
2. **Check VM logs**: Review `vms/<distro>/serial.log`
3. **Manual testing**: Try manual VM creation and testing
4. **Report issues**: Document errors with logs for troubleshooting

## Examples

### Example 1: Run Everything in Background

```bash
# Start orchestration
nohup ./scripts/master_orchestrator.sh all > orch.log 2>&1 &
echo $! > orchestrator.pid

# Check status periodically
watch -n 60 './scripts/process_monitor.sh all'

# Or monitor specific things
./scripts/process_monitor.sh vms
./scripts/process_monitor.sh status
./scripts/process_monitor.sh isos

# If needed, kill orchestrator
kill $(cat orchestrator.pid)
```

### Example 2: Phased Execution

```bash
# Day 1: Download ISOs
./scripts/master_orchestrator.sh download-isos

# Day 2: Create VMs and install
./scripts/master_orchestrator.sh create-vms
./scripts/master_orchestrator.sh monitor-vms

# Day 3: Archive and test
./scripts/master_orchestrator.sh archive-vms
./scripts/master_orchestrator.sh test

# Day 4: Generate reports
./scripts/master_orchestrator.sh report
```

### Example 3: Single Distribution Testing

```bash
# Test just Ubuntu 22.04
./scripts/iso_manager.sh download  # Gets all ISOs
./scripts/qemu_manager.sh create ubuntu-22 4096 20G 2
# Wait for installation...
./scripts/test_all_distributions.sh single Ubuntu_22
```

## Success Criteria

The orchestration is successful when:

✅ All 12 ISOs downloaded and verified
✅ All 12 VMs created successfully
✅ All OS installations completed (login prompt visible)
✅ All VMs archived to `vms/archive/`
✅ All Mail Server Factory tests passed
✅ Test reports generated in `test_results/`
✅ No processes stuck or hanging
✅ All logs show "SUCCESS" for critical operations

## Next Steps

After successful orchestration:

1. Review test reports in `test_results/`
2. Update `TESTING.md` with latest results
3. Update `README.md` with distribution compatibility
4. Update website with test results
5. Create GitHub release with tested VMs
6. Document any distribution-specific issues
7. Plan for continuous testing integration
