#!/usr/bin/env bash

# QEMU Manager - Create and Manage QEMU Virtual Machines for Testing
# This script automates VM creation, installation, and testing for all supported distributions

set -euo pipefail

# ============================================
# Configuration
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
ISO_DIR="${PROJECT_ROOT}/isos"
VM_DIR="${PROJECT_ROOT}/vms"
LOG_DIR="${VM_DIR}/logs"
PRESEED_DIR="${PROJECT_ROOT}/preseeds"

# Default VM Settings
DEFAULT_MEMORY="4096"
DEFAULT_DISK_SIZE="20G"
DEFAULT_CPUS="2"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================
# VM Definitions
# ============================================

# Format: "NAME|ISO_FILENAME|OS_TYPE|BOOT_PARAMS"
declare -A VM_DEFINITIONS=(
    ["ubuntu-22"]="ubuntu-22.04.5-live-server-amd64.iso|linux|autoinstall"
    ["ubuntu-24"]="ubuntu-24.04.3-live-server-amd64.iso|linux|autoinstall"
    ["debian-11"]="debian-11.12.0-amd64-netinst.iso|linux|preseed"
    ["debian-12"]="debian-12.9.0-amd64-netinst.iso|linux|preseed"
    ["fedora-38"]="Fedora-Server-dvd-x86_64-38-1.6.iso|linux|kickstart"
    ["fedora-39"]="Fedora-Server-dvd-x86_64-39-1.5.iso|linux|kickstart"
    ["fedora-40"]="Fedora-Server-dvd-x86_64-40-1.14.iso|linux|kickstart"
    ["fedora-41"]="Fedora-Server-dvd-x86_64-41-1.4.iso|linux|kickstart"
    ["almalinux-9"]="AlmaLinux-9.5-x86_64-dvd.iso|linux|kickstart"
    ["rocky-9"]="Rocky-9.5-x86_64-dvd.iso|linux|kickstart"
    ["opensuse-15"]="openSUSE-Leap-15.6-DVD-x86_64-Media.iso|linux|autoyast"
)

# ============================================
# Logging Functions
# ============================================

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}"
}

log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }
log_success() { log "SUCCESS" "$@"; }

print_header() {
    echo ""
    echo -e "${BLUE}================================================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}================================================================${NC}"
    echo ""
}

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ $1${NC}"; }

# ============================================
# Helper Functions
# ============================================

check_dependencies() {
    local missing=0

    for cmd in qemu-system-x86_64 qemu-img; do
        if ! command -v "$cmd" &> /dev/null; then
            print_error "Required command not found: $cmd"
            ((missing++))
        fi
    done

    if [ $missing -gt 0 ]; then
        print_error "Please install QEMU: sudo apt install qemu-system-x86 qemu-utils"
        return 1
    fi

    print_success "All dependencies found"
    return 0
}

create_directories() {
    mkdir -p "${VM_DIR}"
    mkdir -p "${LOG_DIR}"
    mkdir -p "${PRESEED_DIR}"
    log_info "Created directories: ${VM_DIR}, ${LOG_DIR}, ${PRESEED_DIR}"
}

create_disk() {
    local vm_name="$1"
    local disk_size="${2:-${DEFAULT_DISK_SIZE}}"
    local disk_path="${VM_DIR}/${vm_name}/${vm_name}.qcow2"

    if [ -f "${disk_path}" ]; then
        print_warning "Disk already exists: ${disk_path}"
        return 0
    fi

    mkdir -p "$(dirname "${disk_path}")"

    print_info "Creating virtual disk: ${disk_size}"
    qemu-img create -f qcow2 "${disk_path}" "${disk_size}" > /dev/null

    if [ $? -eq 0 ]; then
        print_success "Disk created: ${disk_path}"
        return 0
    else
        print_error "Failed to create disk"
        return 1
    fi
}

create_cloud_init() {
    local vm_name="$1"
    local vm_path="${VM_DIR}/${vm_name}"
    local meta_data="${vm_path}/meta-data"
    local user_data="${vm_path}/user-data"
    local network_config="${vm_path}/network-config"

    mkdir -p "${vm_path}"

    # Create meta-data
    cat > "${meta_data}" <<EOF
instance-id: ${vm_name}
local-hostname: ${vm_name}
EOF

    # Create user-data for autoinstall (Ubuntu)
    cat > "${user_data}" <<EOF
#cloud-config
autoinstall:
  version: 1
  identity:
    hostname: ${vm_name}
    password: '\$6\$rounds=4096\$saltsaltsal\$LUQCxBP8yl1wYKl/kzVcnFJMYJI2MJzJm.GRJcz2E6Nf8BH8sLh7KfXl7GZ3h/8JLQqWFQZ6rqZQ7qZ6rqZQ'
    username: root
  keyboard:
    layout: us
  locale: en_US.UTF-8
  network:
    network:
      version: 2
      ethernets:
        eth0:
          dhcp4: true
  ssh:
    install-server: true
    allow-pw: true
  storage:
    layout:
      name: direct
  late-commands:
    - echo 'root:root' | chpasswd
    - sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /target/etc/ssh/sshd_config
    - sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' /target/etc/ssh/sshd_config
EOF

    # Create network-config
    cat > "${network_config}" <<EOF
version: 2
ethernets:
  eth0:
    dhcp4: true
EOF

    print_success "Cloud-init configuration created"
}

create_kickstart() {
    local vm_name="$1"
    local kickstart_file="${PRESEED_DIR}/${vm_name}-ks.cfg"

    cat > "${kickstart_file}" <<'EOF'
# Kickstart file for automated installation
lang en_US.UTF-8
keyboard us
timezone UTC
rootpw --plaintext root
authconfig --enableshadow --passalgo=sha512
selinux --disabled
firewall --disabled
network --bootproto=dhcp --device=eth0 --onboot=yes --hostname=localhost.localdomain
bootloader --location=mbr --append="net.ifnames=0 biosdevname=0"
clearpart --all --initlabel
autopart --type=lvm
reboot

%packages
@core
@base
openssh-server
net-tools
%end

%post
systemctl enable sshd
sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
%end
EOF

    print_success "Kickstart configuration created: ${kickstart_file}"
    echo "${kickstart_file}"
}

create_preseed() {
    local vm_name="$1"
    local preseed_file="${PRESEED_DIR}/${vm_name}-preseed.cfg"

    cat > "${preseed_file}" <<'EOF'
# Debian preseed file for automated installation
d-i debian-installer/locale string en_US.UTF-8
d-i keyboard-configuration/xkb-keymap select us
d-i netcfg/choose_interface select auto
d-i netcfg/get_hostname string localhost
d-i netcfg/get_domain string localdomain
d-i mirror/country string manual
d-i mirror/http/hostname string deb.debian.org
d-i mirror/http/directory string /debian
d-i mirror/http/proxy string
d-i passwd/root-password password root
d-i passwd/root-password-again password root
d-i clock-setup/utc boolean true
d-i time/zone string UTC
d-i partman-auto/method string regular
d-i partman-auto/choose_recipe select atomic
d-i partman/confirm_write_new_label boolean true
d-i partman/choose_partition select finish
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true
tasksel tasksel/first multiselect standard, ssh-server
d-i pkgsel/include string openssh-server
d-i pkgsel/upgrade select full-upgrade
popularity-contest popularity-contest/participate boolean false
d-i grub-installer/only_debian boolean true
d-i grub-installer/bootdev string default
d-i finish-install/reboot_in_progress note
EOF

    print_success "Preseed configuration created: ${preseed_file}"
    echo "${preseed_file}"
}

start_vm() {
    local vm_name="$1"
    local iso_filename="${2}"
    local memory="${3:-${DEFAULT_MEMORY}}"
    local cpus="${4:-${DEFAULT_CPUS}}"
    local extra_params="${5:-}"

    local iso_path="${ISO_DIR}/${iso_filename}"
    local disk_path="${VM_DIR}/${vm_name}/${vm_name}.qcow2"
    local log_file="${LOG_DIR}/${vm_name}.log"

    if [ ! -f "${iso_path}" ]; then
        print_error "ISO not found: ${iso_path}"
        return 1
    fi

    if [ ! -f "${disk_path}" ]; then
        print_error "Disk not found: ${disk_path}"
        return 1
    fi

    print_info "Starting VM: ${vm_name}"
    log_info "Memory: ${memory}MB, CPUs: ${cpus}"

    # Build QEMU command
    local qemu_cmd=(
        qemu-system-x86_64
        -name "${vm_name}"
        -m "${memory}"
        -smp "${cpus}"
        -hda "${disk_path}"
        -cdrom "${iso_path}"
        -boot d
        -enable-kvm
        -cpu host
        -netdev user,id=net0,hostfwd=tcp::2222-:22
        -device virtio-net-pci,netdev=net0
        -display none
        -daemonize
        -pidfile "${VM_DIR}/${vm_name}/qemu.pid"
    )

    # Add extra parameters if provided
    if [ -n "${extra_params}" ]; then
        qemu_cmd+=( ${extra_params} )
    fi

    # Execute QEMU
    "${qemu_cmd[@]}" 2>&1 | tee "${log_file}"

    if [ $? -eq 0 ]; then
        print_success "VM started: ${vm_name}"
        print_info "SSH access (after installation): ssh -p 2222 root@localhost"
        print_info "Log file: ${log_file}"
        return 0
    else
        print_error "Failed to start VM"
        return 1
    fi
}

create_vm() {
    local vm_name="$1"
    local memory="${2:-${DEFAULT_MEMORY}}"
    local disk_size="${3:-${DEFAULT_DISK_SIZE}}"
    local cpus="${4:-${DEFAULT_CPUS}}"

    print_header "Creating VM: ${vm_name}"

    # Get VM definition
    if [ -z "${VM_DEFINITIONS[${vm_name}]+x}" ]; then
        print_error "Unknown VM: ${vm_name}"
        print_info "Available VMs: ${!VM_DEFINITIONS[@]}"
        return 1
    fi

    IFS='|' read -r iso_filename os_type boot_method <<< "${VM_DEFINITIONS[${vm_name}]}"

    # Create disk
    if ! create_disk "${vm_name}" "${disk_size}"; then
        return 1
    fi

    # Create automation config based on distribution
    case "${boot_method}" in
        autoinstall)
            create_cloud_init "${vm_name}"
            ;;
        kickstart)
            create_kickstart "${vm_name}"
            ;;
        preseed)
            create_preseed "${vm_name}"
            ;;
        autoyast)
            print_info "AutoYaST configuration would be created for openSUSE"
            ;;
    esac

    print_success "VM ${vm_name} created successfully"
    print_info "To start the VM: $0 start ${vm_name}"
}

stop_vm() {
    local vm_name="$1"
    local pid_file="${VM_DIR}/${vm_name}/qemu.pid"

    if [ ! -f "${pid_file}" ]; then
        print_warning "VM not running: ${vm_name}"
        return 0
    fi

    local pid=$(cat "${pid_file}")
    print_info "Stopping VM: ${vm_name} (PID: ${pid})"

    kill "${pid}" 2>/dev/null

    if [ $? -eq 0 ]; then
        rm -f "${pid_file}"
        print_success "VM stopped: ${vm_name}"
        return 0
    else
        print_error "Failed to stop VM (may not be running)"
        return 1
    fi
}

list_vms() {
    print_header "Available VMs"

    printf "%-20s %-40s %-15s %-10s\n" "Name" "ISO" "OS Type" "Status"
    printf "%-20s %-40s %-15s %-10s\n" "----" "---" "-------" "------"

    for vm_name in "${!VM_DEFINITIONS[@]}"; do
        IFS='|' read -r iso_filename os_type boot_method <<< "${VM_DEFINITIONS[${vm_name}]}"

        local status="Not Created"
        local disk_path="${VM_DIR}/${vm_name}/${vm_name}.qcow2"
        local pid_file="${VM_DIR}/${vm_name}/qemu.pid"

        if [ -f "${disk_path}" ]; then
            status="Created"
        fi

        if [ -f "${pid_file}" ]; then
            local pid=$(cat "${pid_file}")
            if kill -0 "${pid}" 2>/dev/null; then
                status="${GREEN}Running${NC}"
            else
                status="Stopped"
            fi
        fi

        printf "%-20s %-40s %-15s %-10b\n" "${vm_name}" "${iso_filename}" "${os_type}" "${status}"
    done
}

show_help() {
    cat <<EOF
QEMU Manager - Create and Manage Test VMs

Usage: $(basename "$0") COMMAND [OPTIONS]

Commands:
    create VM_NAME [MEMORY] [DISK_SIZE] [CPUS]
        Create a new VM with specified resources
        Example: $0 create ubuntu-22 4096 20G 2

    start VM_NAME [MEMORY] [CPUS]
        Start an existing VM
        Example: $0 start ubuntu-22

    stop VM_NAME
        Stop a running VM
        Example: $0 stop ubuntu-22

    list
        List all available VMs and their status

    help
        Show this help message

Available VMs:
$(for vm in "${!VM_DEFINITIONS[@]}"; do echo "    - ${vm}"; done | sort)

Default Settings:
    Memory:    ${DEFAULT_MEMORY}MB
    Disk Size: ${DEFAULT_DISK_SIZE}
    CPUs:      ${DEFAULT_CPUS}

Examples:
    # Create Ubuntu 22.04 VM with defaults
    $0 create ubuntu-22

    # Create Fedora 41 VM with 8GB RAM and 40GB disk
    $0 create fedora-41 8192 40G 4

    # Start Ubuntu 24.04 VM
    $0 start ubuntu-24

    # List all VMs
    $0 list

    # Stop a running VM
    $0 stop ubuntu-22

EOF
}

# ============================================
# Main Script
# ============================================

main() {
    if ! check_dependencies; then
        exit 1
    fi

    create_directories

    local command="${1:-help}"

    case "${command}" in
        create)
            if [ -z "${2:-}" ]; then
                print_error "VM name required"
                show_help
                exit 1
            fi
            create_vm "${2}" "${3:-${DEFAULT_MEMORY}}" "${4:-${DEFAULT_DISK_SIZE}}" "${5:-${DEFAULT_CPUS}}"
            ;;
        start)
            if [ -z "${2:-}" ]; then
                print_error "VM name required"
                exit 1
            fi

            local vm_name="$2"
            if [ -z "${VM_DEFINITIONS[${vm_name}]+x}" ]; then
                print_error "Unknown VM: ${vm_name}"
                exit 1
            fi

            IFS='|' read -r iso_filename os_type boot_method <<< "${VM_DEFINITIONS[${vm_name}]}"
            start_vm "${vm_name}" "${iso_filename}" "${3:-${DEFAULT_MEMORY}}" "${4:-${DEFAULT_CPUS}}"
            ;;
        stop)
            if [ -z "${2:-}" ]; then
                print_error "VM name required"
                exit 1
            fi
            stop_vm "${2}"
            ;;
        list)
            list_vms
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "Unknown command: ${command}"
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
