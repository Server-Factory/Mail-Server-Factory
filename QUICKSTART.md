# Mail Server Factory - Quick Start Guide

Get started with Mail Server Factory in under 10 minutes!

## Prerequisites

- Linux host with 100+ GB free disk space
- 8+ GB RAM (32+ GB recommended for parallel testing)
- Docker installed
- QEMU/KVM installed
- Internet connection for ISO downloads

## Installation

### 1. Install Dependencies

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install -y qemu-system-x86 qemu-utils docker.io wget curl python3
```

**Fedora/RHEL/AlmaLinux/Rocky:**
```bash
sudo dnf install -y qemu-kvm qemu-img docker wget curl python3
```

**openSUSE:**
```bash
sudo zypper install -y qemu-x86 qemu-tools docker wget curl python3
```

### 2. Clone Repository

```bash
git clone --recurse-submodules https://github.com/Server-Factory/Mail-Server-Factory.git
cd Mail-Server-Factory
```

### 3. Build Project

```bash
./gradlew assemble
```

## Quick Test (Single Distribution)

### Step 1: Download Ubuntu 22.04 ISO

```bash
# This is already in progress if you ran the automated download
# Or download manually:
./scripts/iso_manager.sh download

# Check progress:
./scripts/check_download_status.sh status
```

### Step 2: Create VM

```bash
# Create Ubuntu 22.04 VM with default settings (4GB RAM, 20GB disk)
./scripts/qemu_manager.sh create ubuntu-22

# Or with custom resources (8GB RAM, 40GB disk, 4 CPUs):
./scripts/qemu_manager.sh create ubuntu-22 8192 40G 4
```

### Step 3: Start VM

```bash
./scripts/qemu_manager.sh start ubuntu-22
```

**Installation will take 10-15 minutes.** Check status:
```bash
./scripts/qemu_manager.sh list
```

### Step 4: Access VM

After installation completes:
```bash
ssh -p 2222 root@localhost
# Password: root (change in production!)
```

### Step 5: Configure VM

Inside the VM:
```bash
# Install Docker
apt update
apt install -y docker.io

# Enable Docker
systemctl enable --now docker

# Verify Docker is running
docker ps

# Exit VM
exit
```

### Step 6: Configure SSH Access

On your host machine:
```bash
# Generate SSH key if you don't have one
ssh-keygen -t rsa -b 4096 -f ~/.ssh/mail_factory_key

# Copy key to VM
ssh-copy-id -p 2222 -i ~/.ssh/mail_factory_key.pub root@localhost
```

### Step 7: Configure Mail Server Factory

Create Docker credentials file:
```bash
# Create the Docker credentials file
cat > Examples/Includes/_Docker.json <<EOF
{
  "docker": {
    "credentials": {
      "username": "your-dockerhub-username",
      "password": "your-dockerhub-password"
    }
  }
}
EOF
```

Update the hostname in configuration:
```bash
# If testing on localhost, update the hostname
# Edit Examples/Ubuntu_22.json and set SERVER.HOSTNAME to the VM's IP
# or configure /etc/hosts:
echo "127.0.0.1 ubuntu22.local" | sudo tee -a /etc/hosts
```

### Step 8: Run Mail Server Factory

```bash
# Using the wrapper script
./mail_factory Examples/Ubuntu_22.json

# Or directly with Java
java -jar Application/build/libs/Application.jar Examples/Ubuntu_22.json
```

### Step 9: Verify Installation

```bash
# SSH into the VM
ssh -p 2222 root@localhost

# Check Docker containers
docker ps

# You should see containers for:
# - Postfix (SMTP)
# - Dovecot (IMAP/POP3)
# - PostgreSQL (Database)
# - Rspamd (Spam filter)
# - Redis (Cache)
# - ClamAV (Antivirus)

# Check logs
docker logs <container-name>
```

## Full Multi-Distribution Testing

### Monitor Downloads

```bash
# Check download status
./scripts/check_download_status.sh status

# Watch downloads in real-time
./scripts/check_download_status.sh monitor

# View recent activity
./scripts/check_download_status.sh log
```

### Create All VMs

```bash
# Create VMs for all distributions (sequential)
for dist in ubuntu-22 ubuntu-24 debian-11 debian-12 \
            fedora-38 fedora-39 fedora-40 fedora-41 \
            almalinux-9 rocky-9 opensuse-15; do
    ./scripts/qemu_manager.sh create ${dist}
    echo "Created VM: ${dist}"
done
```

### Run Comprehensive Tests

```bash
# Test all distributions
./scripts/test_all_distributions.sh all

# Or test individually
./scripts/test_all_distributions.sh single Ubuntu_22

# View results
cat test_results/test_results_*.md
```

## Common Tasks

### List All VMs

```bash
./scripts/qemu_manager.sh list
```

### Stop a VM

```bash
./scripts/qemu_manager.sh stop ubuntu-22
```

### Restart a VM

```bash
./scripts/qemu_manager.sh stop ubuntu-22
./scripts/qemu_manager.sh start ubuntu-22
```

### Clean Up

```bash
# Stop all VMs
for dist in ubuntu-22 ubuntu-24 debian-11 debian-12; do
    ./scripts/qemu_manager.sh stop ${dist}
done

# Remove VM
rm -rf vms/ubuntu-22/

# Remove all VMs
rm -rf vms/*/
```

## Troubleshooting

### Downloads Are Slow

```bash
# Downloads happen in the background
# Check progress periodically:
./scripts/check_download_status.sh status

# Or watch live:
./scripts/check_download_status.sh monitor
```

### VM Won't Start

```bash
# Check if KVM is loaded
lsmod | grep kvm

# Load KVM module
sudo modprobe kvm-intel  # Intel CPUs
sudo modprobe kvm-amd    # AMD CPUs

# Check VM log
cat vms/ubuntu-22/*.log
```

### Cannot Connect to VM

```bash
# Ensure VM is running
./scripts/qemu_manager.sh list

# Check if port 2222 is in use
ss -tlnp | grep 2222

# Try connecting with password
ssh -p 2222 -o PreferredAuthentications=password root@localhost
```

### Docker Not Running in VM

```bash
# SSH into VM
ssh -p 2222 root@localhost

# Check Docker status
systemctl status docker

# Start Docker
systemctl start docker

# Enable on boot
systemctl enable docker
```

### Mail Server Factory Fails

```bash
# Check configuration file syntax
python3 -m json.tool Examples/Ubuntu_22.json

# Verify Docker credentials exist
cat Examples/Includes/_Docker.json

# Check if VM is accessible
ssh -p 2222 root@localhost "docker ps"

# Review application logs
tail -f logs/mail_factory_*.log
```

## Next Steps

1. **Read Documentation**
   - [QEMU Setup Guide](docs/QEMU_SETUP.md)
   - [Distribution Testing](docs/DISTRIBUTION_TESTING.md)
   - [Main README](README.md)

2. **Test More Distributions**
   - Follow the same process for other distributions
   - See [Distribution Support](DISTRIBUTION_SUPPORT.md)

3. **Production Deployment**
   - Use real servers instead of VMs
   - Configure proper DNS
   - Set up SSL certificates
   - Enable firewall rules
   - Configure backup strategy

4. **Contribute**
   - Report issues on GitHub
   - Submit pull requests
   - Improve documentation
   - Share your configurations

## Support

- **GitHub**: https://github.com/Server-Factory/Mail-Server-Factory
- **Issues**: https://github.com/Server-Factory/Mail-Server-Factory/issues
- **Documentation**: https://server-factory.github.io/Mail-Server-Factory/

## Quick Reference

### All Scripts

```bash
# ISO Management
./scripts/iso_manager.sh list
./scripts/iso_manager.sh download
./scripts/iso_manager.sh verify

# Download Status
./scripts/check_download_status.sh status
./scripts/check_download_status.sh monitor

# VM Management
./scripts/qemu_manager.sh create <vm-name> [memory] [disk] [cpus]
./scripts/qemu_manager.sh start <vm-name>
./scripts/qemu_manager.sh stop <vm-name>
./scripts/qemu_manager.sh list

# Testing
./scripts/test_all_distributions.sh all
./scripts/test_all_distributions.sh single <Distribution_Name>
./scripts/test_all_distributions.sh list

# Mail Server Factory
./mail_factory <config-file.json>
```

### Available VMs

- ubuntu-22, ubuntu-24
- debian-11, debian-12
- rhel-9, almalinux-9, rocky-9
- fedora-38, fedora-39, fedora-40, fedora-41
- opensuse-15

### Configuration Files

All in `Examples/` directory:
- Ubuntu_22.json, Ubuntu_24.json
- Debian_11.json, Debian_12.json
- RHEL_9.json, AlmaLinux_9.json, Rocky_9.json
- Fedora_Server_38.json through Fedora_Server_41.json
- openSUSE_Leap_15.json

---

**Happy Mail Server Deploying! 🚀**
