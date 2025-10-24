# Mail Server Factory: Quick Architecture Reference

## How OS Detection Works

### Host OS (Where Java Runs)
```
System.getProperty("os.name").lowercase()
  ↓
isMacOS() / isLinux() / isWindows() checks
  ↓
OSInit.run() - Execute OS-specific initialization
  ├─ macOS: Set dock icon, app name
  └─ Linux/Windows: Minimal init
```

### Remote OS (Target Server)
```
SSH connection to remote server
  ↓
Execute system info command
  ↓
HostInfoDataHandler receives output
  ↓
OperatingSystem.parseAndSetSystemInfo() parses:
  ├─ "Operating System:" → detect platform (CentOS, Ubuntu, etc.)
  └─ "Architecture:" → detect arch (x86_64, ARM64, etc.)
  ↓
SSH.operatingSystem updated with results
  ↓
Used throughout deployment for platform-specific behavior
```

## How Installation Steps Are Selected

```
Deployment starts
  ↓
Get remote platform from SSH.operatingSystem.getPlatform()
  ↓ (example: Platform.UBUNTU)
FilesystemDefinitionProvider loads definitions
  ├─ Searches for Definition.json files
  ├─ Includes all platform variants
  └─ Example: Centos/Docker.json, Ubuntu/Docker.json, Fedora/Docker.json
  ↓
SoftwareConfiguration.obtain(path, "Ubuntu") called
  ↓
FilesystemDefinitionProvider filters by platform name
  ├─ Loads Ubuntu/Docker.json ← SELECTED
  └─ Ignores Centos/Docker.json, Fedora/Docker.json
  ↓
Installation steps extracted from Ubuntu/Docker.json
  ├─ type: "command" → CommandInstallationStep
  ├─ type: "packages" → PackageManagerInstallationStep
  ├─ type: "reboot" → RebootStep
  └─ etc.
  ↓
Installer.getEnvironmentName() = platform.platformName (e.g., "Ubuntu")
  ↓
PackageManager selected based on platform
  ├─ "CentOS" / "Fedora" / "RHEL" → Yum
  └─ "Ubuntu" / "Debian" → Apt
  ↓
Each step executed with correct package manager
  ├─ yum install -y package (RPM systems)
  └─ apt-get install -y package (Debian systems)
```

## Configuration File Flow

```
Examples/Centos_8.json
  ├─ "includes": ["Includes/Common.json"]
  ↓
Includes/Common.json
  ├─ "includes": ["Uses.json", "Proxy.json", "Server.json", ...]
  ↓
These files combined and merged
  ├─ "uses" field specifies: ["main:software:docker:1.0.0", ...]
  ├─ Variables combined: SERVER.HOSTNAME, DOCKER.*, etc.
  └─ Database config, account definitions, etc.
  ↓
Definitions loaded based on detected platform
  ├─ Definitions/main/software/docker/1.0.0/Definition.json
  ├─ Includes: Centos/Docker.json, Ubuntu/Docker.json, Fedora/Docker.json
  ↓
Definition filtered by detected platform (e.g., "Ubuntu")
  └─ Loads: Ubuntu/Docker.json
  ↓
Installation steps extracted from recipe
  └─ Variables substituted: {{DOCKER.HOME}}, {{SERVER.HOSTNAME}}, etc.
```

## Installation Recipe Structure

```json
{
  "software": [
    {
      "name": "Docker",
      "version": "19.03",
      "installationSteps": {
        "CentOS": [
          { "type": "packages", "value": "tar, bzip2" },
          { "type": "skipCondition", "value": "docker --version" },
          { "type": "packageGroup", "value": "Development Tools" },
          { "type": "command", "value": "yum-config-manager ..." },
          { "type": "packages", "value": "docker-ce, containerd.io" },
          { "type": "reboot", "value": "480" }
        ],
        "Ubuntu": [
          { "type": "command", "value": "apt-get update" },
          { "type": "packages", "value": "docker-ce, docker-ce-cli" },
          { "type": "reboot", "value": "480" }
        ]
      }
    }
  ]
}
```

**Key**: The "CentOS" and "Ubuntu" keys match platform names used in system

## SSH Connection Lifecycle

```
ConfigurationManager.connectionProvider.obtain()
  ↓
Check if connection exists for remote address
  ├─ Yes: Return cached connection
  └─ No: Continue
  ↓
Create SSH(remote) - with empty OperatingSystem()
  ↓
Add to connectionPool[key]
  ↓
During initialization, HostInfoDataHandler updates:
  └─ SSH.operatingSystem with detected platform/architecture
  ↓
Installer, PackageManager, etc. use:
  └─ connection.getRemoteOS().getPlatform()
```

## File Locations - Quick Reference

| Component | Location |
|-----------|----------|
| **OS Detection** | `Core/Framework/src/main/kotlin/net/milosvasic/factory/platform/OperatingSystem.kt` |
| **Platform Enum** | `Core/Framework/src/main/kotlin/net/milosvasic/factory/platform/Platform.kt` |
| **Architecture Enum** | `Core/Framework/src/main/kotlin/net/milosvasic/factory/platform/Architecture.kt` |
| **Remote OS Handler** | `Core/Framework/src/main/kotlin/net/milosvasic/factory/platform/HostInfoDataHandler.kt` |
| **Host Init (macOS)** | `Application/src/os/macos/kotlin/net/milosvasic/factory/mail/application/OSInit.kt` |
| **Host Init (Linux)** | `Application/src/os/default/kotlin/net/milosvasic/factory/mail/application/OSInit.kt` |
| **SSH Connection** | `Core/Framework/src/main/kotlin/net/milosvasic/factory/remote/ssh/SSH.kt` |
| **Installer** | `Core/Framework/src/main/kotlin/net/milosvasic/factory/component/installer/Installer.kt` |
| **Installation Step** | `Core/Framework/src/main/kotlin/net/milosvasic/factory/component/installer/step/InstallationStep.kt` |
| **PackageManager** | `Core/Framework/src/main/kotlin/net/milosvasic/factory/component/packaging/PackageManager.kt` |
| **Yum** | `Core/Framework/src/main/kotlin/net/milosvasic/factory/component/packaging/Yum.kt` |
| **Apt** | `Core/Framework/src/main/kotlin/net/milosvasic/factory/component/packaging/Apt.kt` |
| **Config Manager** | `Core/Framework/src/main/kotlin/net/milosvasic/factory/configuration/ConfigurationManager.kt` |
| **Software Config** | `Core/Framework/src/main/kotlin/net/milosvasic/factory/configuration/SoftwareConfiguration.kt` |
| **Definition Provider** | `Core/Framework/src/main/kotlin/net/milosvasic/factory/configuration/definition/provider/FilesystemDefinitionProvider.kt` |
| **Installation Flow** | `Core/Framework/src/main/kotlin/net/milosvasic/factory/execution/flow/implementation/InstallationFlow.kt` |
| **Server Factory** | `Core/Framework/src/main/kotlin/net/milosvasic/factory/application/server_factory/ServerFactory.kt` |
| **Mail Server Factory** | `Factory/src/main/kotlin/net/milosvasic/factory/mail/application/server_factory/MailServerFactory.kt` |
| **Mail Config Factory** | `Factory/src/main/kotlin/net/milosvasic/factory/mail/configuration/MailServerConfigurationFactory.kt` |
| **Mail Account** | `Factory/src/main/kotlin/net/milosvasic/factory/mail/account/MailAccount.kt` |
| **Application Entry** | `Application/src/main/kotlin/net/milosvasic/factory/mail/application/main.kt` |
| **Example Config** | `Examples/Centos_8.json` |
| **Definition Files** | `Definitions/main/software/*/1.0.0/{Platform}/` |

## Step-by-Step: From Config File to Deployment

1. **User runs**: `./mail_factory Examples/Centos_8.json`

2. **main.kt**:
   - Parse arguments
   - Initialize OSInit.run() (host OS init)
   - Load FileConfigurationRecipe(Centos_8.json)
   - Create MailServerFactory

3. **InitializationFlow**:
   - Load JSON, parse variables
   - Create SSH connection to remote
   - HostInfoDataHandler detects remote OS
   - Save platform in SSH.operatingSystem

4. **ServerFactory.run()**:
   - Get detected platform: `connection.getRemoteOS().getPlatform()`
   - FilesystemDefinitionProvider loads definitions
   - Filter definitions by platform name

5. **SoftwareConfiguration.obtain()**:
   - For each software definition
   - Get installation steps for detected platform
   - Create InstallationStep objects

6. **InstallationFlow**:
   - For each InstallationStep
   - Installer.getEnvironmentName() returns platform
   - Select Yum or Apt based on platform
   - Execute steps sequentially

7. **Mail Account Creation**:
   - MailServerFactory.getTerminationFlow()
   - Create accounts in PostgreSQL
   - Set up aliases
   - Verify auth

## Common Queries

**Q: How does the system know to use yum vs apt?**
A: `Installer.getEnvironmentName()` returns the platform name from `connection.getRemoteOS().getPlatform().platformName`. The PackageManager subclass (Yum or Apt) is selected based on this.

**Q: What if a definition file for the detected platform doesn't exist?**
A: The Platform enum has a `getFallback()` chain. If Ubuntu-specific file not found, it falls back to more general ones (Linux → Docker).

**Q: How are variables substituted?**
A: `{{CONTEXT.KEY}}` syntax in JSON is replaced during configuration loading. Variable values come from merged configuration files and definitions.

**Q: Where is Docker deployment configured?**
A: In `Definitions/main.mail_server/docker/*/1.0.0/` directories. Separate from software installation definitions.

**Q: How does the system handle different CentOS versions?**
A: Platform enum has specific entries (CENTOS_7, CENTOS) with fallback chains. Version parsing in `parseAndSetSystemInfo()` checks version strings.

**Q: When is the remote OS information first obtained?**
A: During InitializationFlow, before any installation steps execute. HostInfoDataHandler updates SSH.operatingSystem.

---

## Architecture Diagrams

### OS Detection Flow
```
┌─────────────────────────────────────────┐
│ Application Start (main.kt)             │
├─────────────────────────────────────────┤
│ 1. Detect Host OS (OSInit.run())        │
│    └─ System.getProperty("os.name")     │
│                                         │
│ 2. Create SSH connection to remote     │
│                                         │
│ 3. Execute remote OS detection          │
│    └─ SSH → Remote Server               │
│       └─ Parse output (OS, Architecture)│
│       └─ Update SSH.operatingSystem     │
│                                         │
│ 4. Load definitions for detected OS    │
│    └─ Filter by platform name          │
│                                         │
│ 5. Execute installation steps          │
│    ├─ Select PackageManager (Yum/Apt)  │
│    └─ Execute commands                 │
└─────────────────────────────────────────┘
```

### Configuration Resolution Flow
```
Example/*.json
     ↓
Parse + Merge
     ↓
"uses": [software definitions]
     ↓
Load Definitions/main/software/*/1.0.0/
     ↓
Definition.json
     ├─ includes: [Centos/, Fedora/, Ubuntu/]
     ↓
Detected Platform: "Ubuntu"
     ↓
Load Only: Ubuntu/*.json
     ↓
Extract: installationSteps["Ubuntu"]
     ↓
Create Kotlin InstallationStep objects
     ↓
Execute sequentially
```

### Installation Step Selection
```
SoftwareConfiguration.software[i]
     ├─ name: "Docker"
     └─ installationSteps:
        ├─ "CentOS": [...]
        ├─ "Fedora": [...]
        └─ "Ubuntu": [...]
          ↑ Selected based on detected platform
          
Installer.getEnvironmentName()
     ↓
Connection.getRemoteOS().getPlatform().platformName
     ↓
Example: "Ubuntu"
     ↓
Get: installationSteps["Ubuntu"]
     ↓
Create InstallationStep objects
```
