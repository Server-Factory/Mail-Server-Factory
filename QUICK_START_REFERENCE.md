# Quick Start Reference Card

**Version**: 3.0
**Date**: 2025-10-24

---

## 🚀 Quick Start (5 Minutes)

```bash
# 1. Clone and build
git clone --recurse-submodules https://github.com/Server-Factory/Mail-Server-Factory.git
cd Mail-Server-Factory
./gradlew assemble

# 2. Setup SSH
cd Core/Utils
./init_ssh_access.sh your-server.com

# 3. Deploy
cd ~/Mail-Server-Factory
./mail_factory Examples/Ubuntu_24.json
```

---

## 📚 Essential Documentation

| Document | Purpose | Size |
|----------|---------|------|
| `GETTING_STARTED_TUTORIAL.md` | First deployment | Beginner |
| `README.md` | Project overview | Reference |
| `QUICK_ARCHITECTURE_REFERENCE.md` | Architecture | Quick |
| `FINAL_SESSION_SUMMARY.md` | Complete summary | Complete |

---

## 🌍 Supported Distributions (13 Families)

### Western
- Ubuntu (3), Debian (2), CentOS (3), Fedora (4)
- AlmaLinux (1), Rocky (1), openSUSE (2)

### Russian 🇷🇺
- ALT Linux (2), Astra (1), ROSA (1)

### Chinese 🇨🇳
- openEuler (2), openKylin (1), Deepin (1)

**Total**: 25 distributions

---

## 🧪 Testing

```bash
# Run comprehensive test matrix
cd scripts
./comprehensive_test_matrix.sh run-matrix

# Check ISOs
./comprehensive_test_matrix.sh check-isos

# Interactive menu
./comprehensive_test_matrix.sh menu
```

---

## 📊 Key Metrics

| Metric | Value |
|--------|-------|
| Distributions | 13 families |
| Test Combinations | 299 |
| Documentation | 60K+ lines |
| Growth | +333% |

---

## 🔧 Common Commands

```bash
# Build project
./gradlew assemble

# Run tests
./gradlew test

# Deploy mail server
./mail_factory Examples/Ubuntu_24.json

# Check deployment
ssh root@your-server.com "docker ps"

# Validate account
ssh root@your-server.com "doveadm auth test user@example.com"
```

---

## 📁 Project Structure

```
Mail-Server-Factory/
├── Application/           # Main executable
├── Factory/              # Mail server implementation
├── Core/                 # Framework & utilities
├── Definitions/          # Installation recipes
├── Examples/             # Config files (38)
├── scripts/              # Testing infrastructure
└── Website/              # Website & translations
```

---

## ⚡ Installation Recipes

| Distribution | Recipe Location |
|--------------|----------------|
| All | `Definitions/main/software/docker/1.0.0/{distro}/` |

**26 recipes** total (13 Docker + 13 Compose)

---

## 🐛 Known Issues

**Critical** (2):
- Passwords in plain text
- No input validation

**High** (8):
- SSH connection pooling
- Reboot verification
- SELinux disabled
- ... (see STABILITY_SAFETY_PERFORMANCE_ANALYSIS.md)

---

## 📖 Full Documentation Index

See `COMPREHENSIVE_DOCUMENTATION_MASTER.md` for complete index

---

## 🆘 Help

- **Tutorial**: GETTING_STARTED_TUTORIAL.md
- **Troubleshooting**: Section 8 in Getting Started
- **Issues**: https://github.com/Server-Factory/Mail-Server-Factory/issues
- **Discussions**: https://github.com/Server-Factory/Mail-Server-Factory/discussions

---

**Quick Reference v1.0** | **2025-10-24** | **Phase 1 Complete**
