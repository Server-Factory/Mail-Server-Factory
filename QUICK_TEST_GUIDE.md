# Quick Test Guide - Mail Server Factory

## TL;DR - Run All Tests

```bash
# Full comprehensive test suite (9-19 hours)
./run_all_tests
```

## Individual Test Commands

### 1. Unit Tests Only (2-5 minutes)
```bash
./gradlew test
```

View results:
```bash
firefox Core/Framework/build/reports/tests/test/index.html
firefox Factory/build/reports/tests/test/index.html
```

### 2. Coverage Report (3-7 minutes)
```bash
./gradlew test jacocoTestReport
firefox Core/Framework/build/reports/jacoco/test/html/index.html
```

### 3. Launcher Tests Only (30-60 seconds)
```bash
./tests/launcher/test_launcher.sh
```

### 4. Download ISOs Only (30-120 minutes)
```bash
./scripts/iso_manager.sh download
./scripts/iso_manager.sh verify
```

### 5. Create Single VM (5 minutes)
```bash
./scripts/qemu_manager.sh create ubuntu-22 4096 20G 2
./scripts/qemu_manager.sh start ubuntu-22
```

### 6. Deploy to Single VM (10-30 minutes)
```bash
# Prerequisites: VM must be running, SSH accessible, Docker installed
./mail_factory Examples/Ubuntu_22.json
```

### 7. Test Distribution Configs Only (5 minutes)
```bash
./scripts/test_all_distributions.sh all
```

## Test Phases at a Glance

| Phase | Command | Time | Output |
|-------|---------|------|--------|
| **Unit Tests** | `./gradlew test` | 2-5 min | `build/reports/tests/` |
| **Launcher Tests** | `./tests/launcher/test_launcher.sh` | 30-60 sec | Terminal |
| **ISOs** | `./scripts/iso_manager.sh download` | 30-120 min | `isos/` |
| **VMs** | `./scripts/qemu_manager.sh create ...` | 5-10 min | `vms/` |
| **OS Install** | Auto during VM start | 15-60 min each | `vms/logs/` |
| **Deploy** | `./mail_factory Examples/X.json` | 10-30 min each | `test_results/` |
| **Verify** | SSH + docker ps checks | 1-2 min each | Terminal |

## Quick Commands

### Check Test Status
```bash
# Unit test results
./gradlew test --dry-run

# Launcher tests
./tests/launcher/test_launcher.sh | grep "Tests passed"

# VM status
./scripts/qemu_manager.sh list

# ISO status
./scripts/iso_manager.sh list
```

### View Reports
```bash
# Latest HTML report
firefox test_results/test_report_*.html

# Latest Markdown report
cat test_results/test_report_*.md

# Latest execution log
tail -f test_results/run_all_tests_*.log
```

### Clean Up
```bash
# Remove test results
rm -rf test_results/*

# Remove VMs
rm -rf vms/*/

# Remove ISOs
rm -rf isos/*.iso

# Clean build artifacts
./gradlew clean
```

## Pre-flight Checklist

Before running `./run_all_tests`:

- [ ] **Java 17+** installed (`java -version`)
- [ ] **Docker** running (`docker ps`)
- [ ] **QEMU** installed (`qemu-system-x86_64 --version`)
- [ ] **120GB+** disk space (`df -h`)
- [ ] **16GB+** RAM (`free -g`)
- [ ] **Docker credentials** configured (`Examples/Includes/_Docker.json`)
- [ ] **Hardware virtualization** enabled in BIOS
- [ ] **Network** connection stable (for ISOs)
- [ ] **Time** available (9-19 hours)

## Troubleshooting Quick Fixes

### Test failed?
```bash
# Check logs
tail -100 test_results/run_all_tests_*.log

# Rerun with debug
./run_all_tests --debug
```

### VM not starting?
```bash
# Check QEMU process
./scripts/qemu_manager.sh status ubuntu-22

# View serial output
tail -f vms/logs/ubuntu-22.log

# Restart VM
./scripts/qemu_manager.sh stop ubuntu-22
./scripts/qemu_manager.sh start ubuntu-22
```

### Deployment failed?
```bash
# SSH into VM manually
ssh -p 2222 root@localhost

# Check Docker
docker ps -a
docker logs postmaster_db

# Check disk space
df -h

# Retry deployment
./mail_factory Examples/Ubuntu_22.json
```

### Out of disk space?
```bash
# Clean archives
rm -rf vms/archives/*.gz

# Clean old ISOs
rm -rf isos/*.iso.tmp

# Clean Gradle cache
./gradlew clean

# Clean Docker
docker system prune -a
```

## Success Indicators

**Unit Tests**: ✅ BUILD SUCCESSFUL + All tests passed
**Launcher Tests**: ✅ All tests passed!
**ISOs**: ✅ All ISOs verified successfully
**VMs**: ✅ All VMs created
**OS Install**: ✅ All OS installations completed
**Deploy**: ✅ All deployments completed
**Verify**: ✅ All components verified

**Overall**: ✅ ALL TESTS PASSED - 100% SUCCESS!

## Time-Saving Tips

1. **Pre-download ISOs overnight**:
   ```bash
   nohup ./scripts/iso_manager.sh download > iso_download.log 2>&1 &
   ```

2. **Run in screen/tmux**:
   ```bash
   screen -S tests
   ./run_all_tests
   # Ctrl+A, D to detach
   ```

3. **Test subset of distributions**:
   Edit `run_all_tests`, comment out distributions:
   ```bash
   declare -a DISTRIBUTIONS=(
       "ubuntu-22:Ubuntu_22:Debian:4096:20G:2"
       # "ubuntu-24:Ubuntu_24:Debian:4096:20G:2"  # Disabled
       # ...
   )
   ```

4. **Skip phases you already tested**:
   Comment out phases in `main()` function:
   ```bash
   # run_unit_tests
   # run_launcher_tests
   # download_and_verify_isos  # Already done
   create_all_vms
   # ...
   ```

## Emergency Stop

```bash
# Kill all test processes
pkill -f run_all_tests

# Stop all VMs
for vm in vms/*/qemu.pid; do
    kill $(cat $vm) 2>/dev/null
done

# Or use qemu_manager
./scripts/qemu_manager.sh stop ubuntu-22
./scripts/qemu_manager.sh stop ubuntu-24
# etc...
```

## Next Steps After Tests Pass

1. **Review HTML report** for detailed statistics
2. **Archive successful VM images** for future use
3. **Update compatibility matrix** in README
4. **Generate test badge** for repository
5. **Schedule regular testing** (weekly/monthly)

## Resources

- **Full Documentation**: `docs/RUN_ALL_TESTS.md`
- **Testing Overview**: `TESTING.md`
- **Project README**: `README.md`
- **CLAUDE.md**: Project instructions for Claude Code

## Questions?

- Check existing issues: https://github.com/anthropics/claude-code/issues
- Review detailed logs in `test_results/`
- Enable debug mode: `./run_all_tests --debug`

---

**Quick Reference**: Keep this guide handy for fast test execution!
