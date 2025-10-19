# Automated Installation Configurations

This directory contains automated installation configuration files for all supported Linux distributions. These files enable non-interactive, unattended installations in QEMU virtual machines.

## Configuration Files by Distribution

### Debian-based Distributions (Preseed)

- **Ubuntu 22.04**: `ubuntu-22-autoinstall.yaml` (cloud-init autoinstall format)
- **Ubuntu 24.04**: `ubuntu-24-autoinstall.yaml` (cloud-init autoinstall format)
- **Debian 11**: `debian-11-preseed.cfg` (Debian preseed format)
- **Debian 12**: `debian-12-preseed.cfg` (Debian preseed format)

### Red Hat-based Distributions (Kickstart)

- **RHEL 9**: `rhel-9-ks.cfg`
- **AlmaLinux 9**: `almalinux-9-ks.cfg`
- **Rocky Linux 9**: `rocky-9-ks.cfg`
- **Fedora Server 38**: `fedora-38-ks.cfg`
- **Fedora Server 39**: `fedora-39-ks.cfg`
- **Fedora Server 40**: `fedora-40-ks.cfg`
- **Fedora Server 41**: `fedora-41-ks.cfg`

### SUSE-based Distributions (AutoYaST)

- **openSUSE Leap 15.6**: `opensuse-15-autoyast.xml`

## Common Configuration

All automated installations configure:

### User Accounts
- **Root**: Password set to project standard (see secure notes)
- **mailtest**: Standard user for testing
  - Password: Standard test password
  - Sudo access: NOPASSWD for all commands
  - Groups: wheel/sudo, docker

### Network
- DHCP on primary interface
- Hostname: `<distro>-mail-server` (e.g., `ubuntu22-mail-server`)
- Domain: `local`

### Installed Packages
- Docker and Docker Compose
- OpenSSH Server
- Network tools (net-tools, curl, wget)
- Text editors (vim)

### Services
- SSH server enabled and started
- Docker service enabled and started
- Password authentication enabled for SSH
- Firewall disabled (for testing environment)

### SELinux (RHEL/Fedora/AlmaLinux/Rocky)
- Set to **disabled** mode (Mail Server Factory requirement)

### Storage
- Automatic partitioning with LVM
- Standard layout:
  - `/boot`: 500MB-1GB
  - `swap`: 2GB
  - `/`: Remaining space

## Usage

These configuration files are automatically applied by the `qemu_manager.sh` script during VM creation. The QEMU manager determines which configuration to use based on the distribution type.

### Manual Usage Examples

**Ubuntu (cloud-init):**
```bash
qemu-system-x86_64 \
  -cdrom ubuntu-24.04.3-live-server-amd64.iso \
  -drive file=user-data,format=raw \
  -drive file=meta-data,format=raw \
  ...
```

**Debian (preseed):**
```bash
qemu-system-x86_64 \
  -cdrom debian-12.9.0-amd64-netinst.iso \
  -kernel /install.amd/vmlinuz \
  -initrd /install.amd/initrd.gz \
  -append "auto=true url=http://10.0.2.2/preseed.cfg" \
  ...
```

**RHEL/Fedora (kickstart):**
```bash
qemu-system-x86_64 \
  -cdrom Fedora-Server-dvd-x86_64-41-1.4.iso \
  -append "inst.ks=http://10.0.2.2/fedora-41-ks.cfg" \
  ...
```

**openSUSE (AutoYaST):**
```bash
qemu-system-x86_64 \
  -cdrom openSUSE-Leap-15.6-DVD-x86_64-Media.iso \
  -append "autoyast=http://10.0.2.2/autoyast.xml" \
  ...
```

## Installation Times

Approximate installation times in QEMU (varies by system resources):

| Distribution | Estimated Time |
|--------------|----------------|
| Ubuntu 22/24 | 10-15 minutes |
| Debian 11/12 | 15-20 minutes |
| Fedora 38-41 | 25-35 minutes |
| RHEL 9 | 30-40 minutes |
| AlmaLinux 9 | 25-35 minutes |
| Rocky Linux 9 | 25-35 minutes |
| openSUSE Leap 15.6 | 30-45 minutes |

## Verification

After installation completes, verify:

```bash
# Check Docker is installed and running
docker --version
docker ps

# Check SSH access
ssh mailtest@<vm-hostname>.local

# Verify user is in docker group
groups mailtest | grep docker

# Verify sudo access
sudo -l
```

## Troubleshooting

### Installation Hangs
- Check VM serial console log: `vms/<distro>/serial.log`
- Verify ISO integrity with checksums
- Increase VM resources (memory, CPUs)

### Network Issues
- Ensure DHCP is working in VM network
- Check firewall rules on host
- Verify bridge/NAT configuration

### Configuration Not Applied
- Check preseed/kickstart syntax
- Verify configuration is accessible during install
- Review installer logs in VM

## Security Notes

**WARNING**: These configurations are designed for **testing environments only**.

- Default passwords are weak and publicly documented
- SSH password authentication is enabled
- Firewall is disabled
- SELinux is disabled
- Sudo requires no password

**DO NOT** use these configurations for production systems without:
- Changing all passwords to strong, unique values
- Enabling and configuring firewalls
- Re-enabling SELinux (if applicable)
- Configuring proper sudo policies
- Disabling password-based SSH (use keys only)

## Maintenance

When updating configurations:

1. Test changes in a single VM first
2. Verify installation completes successfully
3. Check all required packages are installed
4. Verify Docker and SSH are working
5. Update this README if adding new features

## References

- [Ubuntu Autoinstall](https://ubuntu.com/server/docs/install/autoinstall)
- [Debian Preseed](https://www.debian.org/releases/stable/amd64/apb.en.html)
- [Fedora Kickstart](https://docs.fedoraproject.org/en-US/fedora/latest/install-guide/advanced/Kickstart_Installations/)
- [RHEL Kickstart](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/performing_an_advanced_rhel_installation/index)
- [openSUSE AutoYaST](https://doc.opensuse.org/projects/autoyast/)
