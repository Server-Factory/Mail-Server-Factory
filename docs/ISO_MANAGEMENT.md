# ISO Management Documentation

## Overview

The Mail Server Factory includes an enhanced ISO management system that handles downloading, verifying, and managing Linux distribution ISO images. The system supports both internet downloads and optional local network caching via SMB shares.

## Features

- **Automated Downloads**: Downloads ISO images for all supported distributions
- **Checksum Verification**: Validates downloaded ISOs using SHA256/SHA512/MD5 checksums
- **Progress Monitoring**: Real-time download progress with stall detection
- **Resume Capability**: Resumes interrupted downloads automatically
- **SMB Cache Support**: Optional local network caching for faster access
- **Enterprise Resilience**: Connection health checks, exponential backoff, and retry mechanisms

## Supported Distributions

The system supports 25+ Linux distributions including:
- Ubuntu (20.04, 22.04, 24.04)
- Debian (11, 12)
- Fedora Server (38, 39, 40, 41)
- AlmaLinux (9)
- Rocky Linux (9)
- openSUSE Leap (15.6)
- And many more (see `scripts/iso_manager.sh` for complete list)

## Usage

### Basic Commands

```bash
# Download all ISOs
./scripts/iso_manager.sh download

# Verify existing ISOs
./scripts/iso_manager.sh verify

# List available ISOs
./scripts/iso_manager.sh list

# Show help
./scripts/iso_manager.sh help
```

### Force Re-download

```bash
./scripts/iso_manager.sh download --force
```

## SMB Cache Configuration

### Environment Variable

Set the `OS_IS_IMAGES_PATH` environment variable to enable SMB caching:

```bash
export OS_IS_IMAGES_PATH="smb://server/share/isos"
```

### How It Works

1. **Check SMB First**: When `OS_IS_IMAGES_PATH` is set, the system first checks if the required ISO exists in the SMB share
2. **Copy from SMB**: If found, the ISO is copied from the SMB share to the local cache
3. **Verify Copy**: The copied ISO is verified against checksums
4. **Fallback to Internet**: If not found in SMB or verification fails, the system falls back to downloading from the internet

### SMB Requirements

- **smbclient**: Must be installed on the system (`sudo apt install smbclient` or equivalent)
- **Network Access**: The system must have access to the SMB share
- **Authentication**: Uses existing SMB authentication (credentials may be required)

### Example Configuration

```bash
# Set SMB path
export OS_IS_IMAGES_PATH="smb://fileserver.company.com/distributions/isos"

# Run ISO download
./scripts/iso_manager.sh download

# The system will:
# 1. Check if ubuntu-22.04.5-live-server-amd64.iso exists in SMB share
# 2. If yes, copy it locally and verify checksum
# 3. If no, download from internet as usual
```

## Configuration Options

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `OS_IS_IMAGES_PATH` | SMB path for cached ISOs (e.g., `smb://server/share/isos`) | Not set |
| `STALL_TIMEOUT` | Seconds without progress before retry | 60 |
| `PROGRESS_CHECK_INTERVAL` | Progress check frequency in seconds | 10 |
| `MIN_DOWNLOAD_SPEED` | Minimum acceptable speed in bytes/sec | 10240 |

### Command Line Options

- `--force`: Force re-download even if ISO exists

## Security Considerations

- **Checksum Verification**: All ISOs are verified against official checksums
- **SMB Security**: Uses standard SMB protocols with existing authentication
- **No Secrets in Code**: Environment variables are used for configuration, not hardcoded credentials
- **Audit Logging**: All operations are logged to `isos/iso_manager.log`

## Troubleshooting

### Common Issues

1. **SMB Connection Failed**
   - Ensure `smbclient` is installed
   - Verify network connectivity to SMB server
   - Check SMB server permissions and authentication

2. **Download Stalled**
   - Check network connectivity
   - Verify disk space availability
   - Review logs in `isos/iso_manager.log`

3. **Checksum Verification Failed**
   - The ISO may be corrupted
   - Use `--force` to re-download
   - Check internet connectivity for checksum file download

### Logs

All operations are logged to `isos/iso_manager.log` with timestamps and detailed error messages.

## Testing

The system includes comprehensive unit and integration tests covering all features including SMB caching:

```bash
# Run unit tests (includes SMB functionality tests)
./tests/iso_manager/test_iso_manager_unit.sh

# Run integration tests (includes SMB fallback tests)
./tests/iso_manager/test_iso_manager_integration.sh

# Run all tests
./tests/iso_manager/run_all_tests.sh
```

### SMB-Specific Tests

The test suite includes specific tests for SMB functionality:

- **Environment Variable Handling**: Tests that SMB checks only occur when `OS_IS_IMAGES_PATH` is set
- **Graceful Degradation**: Verifies the system continues working when `smbclient` is not available
- **Path Parsing**: Validates correct parsing of SMB URLs (e.g., `smb://server/share/path`)
- **Fallback Logic**: Ensures fallback to internet download when SMB access fails

### Manual Testing

To manually test SMB functionality:

```bash
# Set SMB path (replace with your actual SMB share)
export OS_IS_IMAGES_PATH="smb://your-server/share/isos"

# Test with a specific ISO
./scripts/iso_manager.sh download  # Will check SMB first, then fallback

# Check logs for SMB activity
tail -f isos/iso_manager.log
```

## Performance

- **Concurrent Downloads**: Multiple ISOs can be downloaded simultaneously
- **Resume Support**: Interrupted downloads resume from where they left off
- **Speed Optimization**: Uses fastest available download tool (wget or curl)
- **Cache Benefits**: SMB caching reduces download time for repeated deployments

## Integration with QEMU

The ISO management system integrates seamlessly with the QEMU virtualization system:

```bash
# Download ISOs
./scripts/iso_manager.sh download

# Use with QEMU manager
./scripts/qemu_manager.sh create ubuntu-22.04
```

For more information on QEMU integration, see [QEMU_SETUP.md](QEMU_SETUP.md).