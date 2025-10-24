# Mail Server Factory: Comprehensive Codebase Analysis

## Executive Summary

Mail Server Factory is a sophisticated Kotlin-based automation framework that deploys complete mail server stacks across multiple Linux distributions. The system uses a multi-layered architecture combining host OS detection, remote OS detection, JSON-based configuration definitions, and OS-specific installation recipes to achieve platform-agnostic mail server deployment.

---

## 1. OS DETECTION AND SUPPORT

### 1.1 Host Operating System Detection

**Location**: `/home/milosvasic/Projects/Mail-Server-Factory/Application/src/os/`

The application uses **OS-specific source sets** to detect and configure the HOST machine (where the Java application is running):

```
Application/src/os/
├── default/kotlin/net/milosvasic/factory/mail/application/OSInit.kt (Linux/Windows)
└── macos/kotlin/net/milosvasic/factory/mail/application/OSInit.kt (macOS)
```

**Host OS Detection Code** (`OperatingSystem.kt`):
```kotlin
// File: Core/Framework/src/main/kotlin/net/milosvasic/factory/platform/OperatingSystem.kt
companion object {
    fun getHostOperatingSystem(): OperatingSystem {
        val platform = when {
            isMacOS() -> Platform.MAC_OS
            isLinux() -> Platform.LINUX
            isWindows() -> Platform.WINDOWS
            else -> Platform.UNKNOWN
        }
        return OperatingSystem(
            name = "Host",
            platform = platform,
            architecture = Architecture.UNKNOWN,
            hostname = "Unknown"
        )
    }

    private fun isMacOS() = getOS().contains("mac")
    private fun isLinux() = getOS().contains("mac")  // NOTE: Bug - all check "mac"
    private fun isWindows() = getOS().contains("mac")
    private fun getOS(): String = System.getProperty("os.name").lowercase()
}
```

**macOS-Specific Initialization** (`Application/src/os/macos/kotlin/OSInit.kt`):
```kotlin
override fun run() {
    log.v("Starting: ${BuildInfo.versionName}, ${BuildInfo.version}")
    val hostOS = OperatingSystem.getHostOperatingSystem()
    val iconResourceName = "assets/Logo.png"
    val iconResource = hostOS::class.java.classLoader.getResourceAsStream(iconResourceName)
    val icon = ImageIO.read(iconResource)
    if (hostOS.getPlatform() == Platform.MAC_OS) {
        System.setProperty("apple.awt.application.name", BuildInfo.printName())
        val app = Application.getApplication()
        app.dockIconImage = icon
    }
}
```

**Default/Linux Initialization** (`Application/src/os/default/kotlin/OSInit.kt`):
```kotlin
override fun run() {
    log.v("Starting: ${BuildInfo.versionName}, ${BuildInfo.version}")
    // Minimal initialization for Linux/Windows
}
```

### 1.2 Remote/Destination Operating System Detection

**Location**: `/home/milosvasic/Projects/Mail-Server-Factory/Core/Framework/src/main/kotlin/net/milosvasic/factory/platform/`

The REMOTE OS (target server) is detected via SSH commands and parsed into an `OperatingSystem` object:

**Remote OS Information Handler** (`HostInfoDataHandler.kt`):
```kotlin
open class HostInfoDataHandler(private val os: OperatingSystem) : DataHandler<OperationResult> {
    override fun onData(data: OperationResult?) {
        data?.let {
            os.parseAndSetSystemInfo(it.data)  // Parse remote command output
            if (os.getPlatform() == Platform.UNKNOWN) {
                log.w("Host operating system is unknown")
            } else {
                log.i("Host operating system: ${os.getName()}")
            }
            if (os.getArchitecture() == Architecture.UNKNOWN) {
                log.w("Host system architecture is unknown")
            } else {
                val arch = os.getArchitecture().arch.uppercase()
                log.i("Host system architecture: $arch")
            }
        }
    }
}
```

**OS Information Parsing** (`OperatingSystem.kt` - `parseAndSetSystemInfo()` method):
```kotlin
fun parseAndSetSystemInfo(data: String) {
    val osLineString = "Operating System:"
    val archLineString = "Architecture:"
    val lines = data.split("\n")
    
    lines.forEach { line ->
        if (line.contains(osLineString)) {
            name = line.replace(osLineString, "").trim()
            
            // Platform detection from remote output
            when {
                name.lowercase().contains(Platform.CENTOS.platformName.lowercase()) -> {
                    platform = if (name.lowercase().contains("linux 8")) {
                        Platform.CENTOS
                    } else {
                        Platform.CENTOS_7
                    }
                }
                name.lowercase().contains(Platform.FEDORA.platformName.lowercase()) -> {
                    platform = when {
                        name.lowercase().contains("30") -> Platform.FEDORA_30
                        name.lowercase().contains("31") -> Platform.FEDORA_31
                        name.lowercase().contains("32") -> Platform.FEDORA_32
                        name.lowercase().contains("33") -> Platform.FEDORA_33
                        else -> Platform.FEDORA
                    }
                }
                name.lowercase().contains(Platform.UBUNTU.platformName.lowercase()) -> {
                    platform = Platform.UBUNTU
                }
                name.lowercase().contains(Platform.DEBIAN.platformName.lowercase()) -> {
                    platform = Platform.DEBIAN
                }
            }
        }
        if (line.contains(archLineString)) {
            val arch = line.replace(archLineString, "")
                .replace("-", "").replace("_", "").trim().lowercase()
            
            architecture = when {
                arch.startsWith("x8664") -> Architecture.X86_64
                arch.startsWith(Architecture.ARMHF.arch) -> Architecture.ARMHF
                arch.startsWith(Architecture.ARM64.arch) -> Architecture.ARM64
                arch.startsWith(Architecture.PPC64EL.arch) -> Architecture.PPC64EL
                arch.startsWith(Architecture.S390X.arch) -> Architecture.S390X
                else -> Architecture.UNKNOWN
            }
        }
    }
}
```

**SSH Connection and Remote OS Storage** (`SSH.kt`):
```kotlin
open class SSH(private val remote: Remote) : Connection, Notifying<OperationResult> {
    private var operatingSystem = OperatingSystem()
    
    override fun getRemoteOS(): OperatingSystem {
        return operatingSystem
    }
}
```

### 1.3 Supported Platforms

**File**: `Core/Framework/src/main/kotlin/net/milosvasic/factory/platform/Platform.kt`

```kotlin
enum class Platform(val platformName: String, private val fallback: List<Platform> = listOf()) {
    // Base distributions
    DOCKER("Docker"),
    CENTOS("CentOS"),
    CENTOS_7("CentOS_7", fallback = listOf(CENTOS)),
    UBUNTU("Ubuntu"),
    UBUNTU_SERVER("Ubuntu_Server", fallback = listOf(UBUNTU)),
    DEBIAN("Debian"),
    FEDORA("Fedora", fallback = listOf(CENTOS)),
    
    // Versioned Fedora
    FEDORA_30("Fedora_30", fallback = listOf(FEDORA, CENTOS)),
    FEDORA_31("Fedora_31", fallback = listOf(FEDORA, CENTOS)),
    FEDORA_32("Fedora_32", fallback = listOf(FEDORA, FEDORA_31, CENTOS)),
    FEDORA_33("Fedora_33", fallback = listOf(FEDORA, FEDORA_32, FEDORA_31, CENTOS)),
    FEDORA_SERVER("Fedora_Server", fallback = listOf(FEDORA, CENTOS)),
    FEDORA_SERVER_30("Fedora_Server_30", fallback = listOf(FEDORA_30, FEDORA_SERVER, FEDORA, CENTOS)),
    FEDORA_SERVER_31("Fedora_Server_31", fallback = listOf(FEDORA_SERVER_30, FEDORA_SERVER, FEDORA, CENTOS)),
    FEDORA_SERVER_32("Fedora_Server_32", fallback = listOf(FEDORA_SERVER_31, FEDORA_SERVER_30, FEDORA_SERVER, FEDORA, CENTOS)),
    FEDORA_SERVER_33("Fedora_Server_33", fallback = listOf(FEDORA_SERVER_32, FEDORA_SERVER_31, FEDORA_SERVER_30, FEDORA_SERVER, FEDORA, CENTOS)),
    
    // Other distributions
    REDHAT("RedHat"),
    LINUX("Linux"),
    MAC_OS("macOS"),
    WINDOWS("Windows"),
    UNKNOWN("Unknown");
    
    fun getFallback(): List<Platform> {
        val items = mutableListOf<Platform>()
        items.addAll(fallback)
        items.add(DOCKER)
        return items
    }
}
```

### 1.4 Supported Architectures

**File**: `Core/Framework/src/main/kotlin/net/milosvasic/factory/platform/Architecture.kt`

```kotlin
enum class Architecture(val arch: String) {
    UNKNOWN("unknown"),
    X86_64("amd64"),
    ARMHF("armhf"),
    ARM64("arm64"),
    PPC64EL("ppc64el"),
    S390X("s390x")
}
```

---

## 2. INSTALLATION ARCHITECTURE

### 2.1 Installation Recipe System

**Location**: `/home/milosvasic/Projects/Mail-Server-Factory/Core/Framework/src/main/kotlin/net/milosvasic/factory/component/installer/`

Installation is recipe-based, where JSON definitions specify steps to execute:

#### Installation Step Types:

**Base Abstract Class** (`InstallationStep.kt`):
```kotlin
abstract class InstallationStep<T> : SelfExecutionParametrized<T>
```

**Concrete Implementation - PackageManager** (`PackageManagerInstallationStep.kt`):
```kotlin
class PackageManagerInstallationStep(private val toInstall: List<InstallationItem>) :
    InstallationStep<PackageInstaller>() {
    
    @Synchronized
    @Throws(IllegalStateException::class, IllegalArgumentException::class)
    override fun execute(vararg params: PackageInstaller) {
        Validator.Arguments.validateSingle(params)
        val installer = params[0]
        installer.install(*toInstall.toTypedArray())
    }
}
```

**Recipe Base Class** (`InstallationStepRecipe.kt`):
```kotlin
abstract class InstallationStepRecipe : ProcessingRecipe {
    protected var toolkit: Toolkit? = null
    protected var step: InstallationStep<*>? = null
    protected var callback: FlowProcessingCallback? = null
    
    @Throws(IllegalArgumentException::class)
    override fun process(callback: FlowProcessingCallback) {
        this.callback = callback
        val validator = InstallationStepRecipeValidator()
        if (!validator.validate(this)) {
            throw IllegalArgumentException("Invalid installation step recipe: $this")
        }
        if (toolkit?.connection == null) {
            throw IllegalArgumentException("Connection not provided")
        }
    }
}
```

### 2.2 Installation Step Types Available

**Directory**: `/home/milosvasic/Projects/Mail-Server-Factory/Core/Framework/src/main/kotlin/net/milosvasic/factory/component/installer/step/`

- **certificate/** - Certificate generation steps
- **condition/** - Conditional execution steps
- **database/** - Database initialization steps
- **deploy/** - Docker deployment steps
- **factory/** - Step factory implementations
- **port/** - Port configuration steps
- **reboot/** - System reboot steps
- **CommandInstallationStep.kt** - Direct command execution
- **PackageManagerInstallationStep.kt** - Package installation
- **RemoteOperationInstallationStep.kt** - SSH remote operations

### 2.3 OS-Specific Installation Step Selection

**Location**: `Core/Framework/src/main/kotlin/net/milosvasic/factory/configuration/SoftwareConfiguration.kt`

The system matches installation steps to detected OS:

```kotlin
@Synchronized
@Throws(IllegalArgumentException::class, IllegalStateException::class)
override fun obtain(vararg param: String): Map<String, List<InstallationStep<*>>> {
    val platformName = param[0]  // Remote OS platform name
    val factories = InstallationStepFactories
    val installationSteps = mutableMapOf<String, List<InstallationStep<*>>>()
    
    software?.forEach { softwareItem ->
        // Get installation steps for this platform
        val steps = it.getInstallationSteps(platformName)
        if (steps.platform != Platform.UNKNOWN) {
            val items = mutableListOf<InstallationStep<*>>()
            steps.items.forEach { definition ->
                // Create installation step from definition
                val step = factories.create(definition, installedItem)
                items.add(step)
            }
            installationSteps[softwareItem.name] = items
        }
    }
    return installationSteps
}
```

### 2.4 Installer Component

**Location**: `Core/Framework/src/main/kotlin/net/milosvasic/factory/component/installer/Installer.kt`

```kotlin
class Installer(entryPoint: Connection) : InstallerAbstract(entryPoint), PackageManagerSupport {
    
    private val installer = PackageInstaller(entryPoint)
    private val recipeRegistrar = InstallerRecipeRegistrar()
    
    override fun getEnvironmentName() = entryPoint.getRemoteOS().getPlatform().platformName
    
    override fun getToolkit() = Toolkit(entryPoint, installer)
}
```

**Key Pattern**: The installer's `getEnvironmentName()` returns the detected remote platform name, which is used to select OS-specific installation recipes.

---

## 3. CONFIGURATION SYSTEM

### 3.1 Configuration Hierarchy

```
Examples/Centos_8.json
    ↓
    └── includes: Includes/Common.json
        ↓
        ├── Uses.json              (software definitions to use)
        ├── Proxy.json             (proxy configuration)
        ├── Server.json            (server details)
        ├── Behavior.json          (behavior flags)
        ├── Database.json          (database settings)
        ├── Accounts.json          (mail accounts to create)
        └── _Docker.json           (Docker credentials)
```

**Example Configuration** (`Examples/Centos_8.json`):
```json
{
  "name": "Centos 8 configuration",
  "includes": [
    "Includes/Common.json"
  ],
  "variables": {
    "SERVER": {
      "HOSTNAME": "centos8.local"
    }
  },
  "remote": {
    "port": 22,
    "user": "root"
  }
}
```

### 3.2 Definition Structure

**Location**: `/home/milosvasic/Projects/Mail-Server-Factory/Definitions/main/`

Definition directory structure:
```
Definitions/main/
├── software/
│   ├── docker/1.0.0/
│   │   ├── Definition.json      (metadata + platform-specific includes)
│   │   ├── Centos/Docker.json   (CentOS installation recipe)
│   │   ├── Fedora/Docker.json   (Fedora installation recipe)
│   │   └── Ubuntu/Docker.json   (Ubuntu installation recipe)
│   └── postgres/1.0.0/
│       ├── Definition.json
│       ├── Centos/Postgres.json
│       ├── Ubuntu/Postgres.json
│       └── ...
└── docker/
    ├── dovecot/1.0.0/           (Docker container definitions)
    ├── postfix/1.0.0/
    └── ...
```

**Definition Metadata** (`Definitions/main/software/docker/1.0.0/Definition.json`):
```json
{
  "definition": {
    "group": "main",
    "type": "software",
    "version": "1.0.0",
    "name": "docker"
  },
  "variables": {
    "DOCKER": {
      "HOME": "{{SERVER.HOME}}/Docker",
      "COMPOSE_PATH": "/usr/local/bin",
      "COMPOSE_VERSION": "1.28.4"
    }
  },
  "includes": [
    "Centos/Docker.json",
    "Fedora/Docker.json",
    "Ubuntu/Docker.json",
    "Centos/Compose.json",
    "Fedora/Compose.json",
    "Ubuntu/Compose.json"
  ]
}
```

### 3.3 OS-Specific Definition Resolution

**Location**: `Core/Framework/src/main/kotlin/net/milosvasic/factory/configuration/definition/provider/FilesystemDefinitionProvider.kt`

```kotlin
class FilesystemDefinitionProvider(configuration: Configuration, operatingSystem: OperatingSystem) :
        DefinitionProvider(configuration, operatingSystem) {
    
    @Throws(IllegalStateException::class, IllegalArgumentException::class)
    override fun load(definition: Definition): MutableList<SoftwareConfiguration> {
        val definitionHome = definition.getHome()
        if (definitionHome.exists()) {
            val items = mutableListOf<String>()
            findDefinitions(definitionHome, items)
            
            items.forEach { item ->
                // KEY: Uses detected platform to select OS-specific config
                val platformName = operatingSystem.getPlatform().platformName
                val configurationPath = Configuration.getConfigurationFilePath(item)
                val obtainedConfiguration = SoftwareConfiguration.obtain(configurationPath, platformName)
                
                if (obtainedConfiguration.isEnabled()) {
                    val variables = obtainedConfiguration.variables
                    configuration.mergeVariables(variables)
                    configurations.add(obtainedConfiguration)
                    
                    // Recursively load dependencies
                    obtainedConfiguration.uses.forEach {
                        val childDefinition = Definition.fromString(it)
                        load(childDefinition)
                    }
                }
            }
        }
        return configurations
    }
}
```

### 3.4 Installation Recipe Structure

**Example - CentOS Docker Installation** (`Definitions/main/software/docker/1.0.0/Centos/Docker.json`):
```json
{
  "software": [
    {
      "name": "Docker",
      "version": "19.03",
      "installationSteps": {
        "CentOS": [
          {
            "type": "packages",
            "value": "tar, bzip2"
          },
          {
            "type": "skipCondition",
            "value": "docker --version"
          },
          {
            "type": "packageGroup",
            "value": "Development Tools"
          },
          {
            "type": "command",
            "value": "yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo"
          },
          {
            "type": "packages",
            "value": "docker-ce-3:19.03.14-3.*, docker-ce-cli-1:19.03.14-3.*, containerd.io"
          },
          {
            "type": "reboot",
            "value": "480"
          }
        ]
      }
    }
  ]
}
```

**Example - Ubuntu Docker Installation** (`Definitions/main/software/docker/1.0.0/Ubuntu/Docker.json`):
```json
{
  "software": [
    {
      "name": "Docker",
      "version": "19.03",
      "installationSteps": {
        "Ubuntu": [
          {
            "type": "command",
            "value": "export DEBIAN_FRONTEND=noninteractive; apt-get update && apt-get upgrade -q -y"
          },
          {
            "type": "packages",
            "value": "apt-transport-https, ca-certificates, curl, gnupg-agent, software-properties-common"
          },
          {
            "type": "command",
            "value": "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -"
          },
          {
            "type": "packages",
            "value": "docker-ce, docker-ce-cli, containerd.io"
          },
          {
            "type": "reboot",
            "value": "480"
          }
        ]
      }
    }
  ]
}
```

**Installation Step Type Mapping** - JSON `type` field maps to:
- `"packages"` → PackageManagerInstallationStep
- `"command"` → CommandInstallationStep
- `"skipCondition"` → Conditional execution
- `"packageGroup"` → Group package installation (yum groupinstall)
- `"reboot"` → RebootStep
- `"portCheck"` → Port verification
- `"database"` → Database initialization
- `"deploy"` → Docker deployment

### 3.5 Configuration Loading Flow

**Location**: `Core/Framework/src/main/kotlin/net/milosvasic/factory/configuration/ConfigurationManager.kt`

```kotlin
object ConfigurationManager : Initializer, BusyDelegation {
    private lateinit var definitionProvider: DefinitionProvider
    
    @Throws(IllegalArgumentException::class, IllegalStateException::class)
    override fun initialize() {
        checkInitialized()
        
        recipe?.let { rcp ->
            // 1. Parse JSON config file
            configuration = configurationFactory?.obtain(rcp)
            nullConfigurationCheck()
            
            configuration?.let {
                // 2. Initialize variables from system
                initializeSystemVariables(it)
                initializeBehaviorVariables(it)
                initializeServerVariables(it)
                
                // 3. Load definition dependencies using detected OS
                val callback = Runnable {
                    notifyInit()
                }
                initializeProxyVariables(it, callback)
            }
        }
    }
}
```

---

## 4. REMOTE EXECUTION ARCHITECTURE

### 4.1 SSH Connection Management

**Location**: `Core/Framework/src/main/kotlin/net/milosvasic/factory/remote/ssh/SSH.kt`

```kotlin
open class SSH(private val remote: Remote) :
        Connection,
        Notifying<OperationResult> {
    
    private val terminal = Terminal()
    private var operatingSystem = OperatingSystem()
    
    @Synchronized
    @Throws(BusyException::class, IllegalArgumentException::class)
    override fun execute(what: TerminalCommand) {
        val command = SSHCommand(remote, filterCommand(what), what.configuration)
        terminal.execute(command)
    }
    
    override fun getRemoteOS(): OperatingSystem {
        return operatingSystem
    }
}
```

**Connection Pool** - maintained in ConfigurationManager:
```kotlin
private val connectionPool = mutableMapOf<String, Connection>()

override fun obtain(): Connection {
    configuration?.let { config ->
        val key = config.remote.toString()
        connectionPool[key]?.let {
            return it
        }
        val connection = SSH(config.remote)
        connectionPool[key] = connection
        return connection
    }
}
```

### 4.2 Remote Command Execution

**Terminal Command Execution** (`Terminal.kt`):
- Commands wrapped in `SSHCommand` objects
- Executed via `execute(TerminalCommand)`
- Results captured and notified via `OperationResultListener`

**Remote OS Detection via SSH** - Commands executed to determine OS:

1. SSH connects to remote server
2. System information command executed (e.g., `lsb_release -a`, `cat /etc/os-release`)
3. Output parsed by `parseAndSetSystemInfo()`
4. Platform determined from output
5. Subsequent installation steps selected based on platform

### 4.3 OS-Specific Command Generation

**Package Manager Selection** (`Installer.kt`):
```kotlin
override fun getEnvironmentName() = entryPoint.getRemoteOS().getPlatform().platformName
```

**Package Manager Implementations**:

**Yum** (`Core/Framework/src/main/kotlin/net/milosvasic/factory/component/packaging/Yum.kt`):
```kotlin
open class Yum(entryPoint: Connection) : PackageManager(entryPoint) {
    override val applicationBinaryName: String
        get() = "yum"
}
```

**Apt** (`Core/Framework/src/main/kotlin/net/milosvasic/factory/component/packaging/Apt.kt`):
```kotlin
open class Apt(entryPoint: Connection) : PackageManager(entryPoint) {
    override val applicationBinaryName: String
        get() = "apt-get"
}
```

**Base PackageManager** (`PackageManager.kt`):
```kotlin
abstract class PackageManager(entryPoint: Connection) :
        BusyWorker<InstallationItem>(entryPoint),
        PackageManagement<InstallationItem> {
    
    abstract val applicationBinaryName: String
    
    open fun installCommand() = "$applicationBinaryName install -y"
    open fun uninstallCommand() = "$applicationBinaryName erase -y"
    open fun groupInstallCommand() = "$applicationBinaryName groupinstall -y"
    open fun groupUninstallCommand() = "$applicationBinaryName groupremove -y"
    
    @Synchronized
    @Throws(IllegalStateException::class, IllegalArgumentException::class)
    override fun install(vararg items: InstallationItem) {
        val clazz: KClass<*>? = getType(items)
        busy()
        operationType = if (clazz == Group::class) {
            PackageManagerOperationType.GROUP_INSTALL
        } else {
            PackageManagerOperationType.PACKAGE_INSTALL
        }
        val flow = CommandFlow().width(entryPoint)
        items.forEach {
            val command = getCommand(it)
            flow.perform(command)
        }
        flow.onFinish(flowCallback).run()
    }
}
```

---

## 5. DEPLOYMENT FLOW ORCHESTRATION

### 5.1 Execution Flow Architecture

**Location**: `Core/Framework/src/main/kotlin/net/milosvasic/factory/execution/flow/implementation/`

**Installation Flow** (`InstallationFlow.kt`):
```kotlin
class InstallationFlow(private val installer: InstallerAbstract, name: String)
    : FlowSimpleBuilder<SoftwareConfiguration, String>(name) {
    
    @Throws(IllegalArgumentException::class)
    override fun getProcessingRecipe(subject: SoftwareConfiguration): ProcessingRecipe {
        return object : ProcessingRecipe {
            override fun process(callback: FlowProcessingCallback) {
                try {
                    installer.setConfiguration(subject)
                    installer.subscribe(operationCallback)
                    installer.install()
                } catch (e: BusyException) {
                    installer.unsubscribe(operationCallback)
                    log.e(e)
                    callback.onFinish(false)
                }
            }
        }
    }
}
```

### 5.2 Server Factory Deployment

**Location**: `Core/Framework/src/main/kotlin/net/milosvasic/factory/application/server_factory/ServerFactory.kt`

The `ServerFactory` orchestrates the entire deployment:

```kotlin
abstract class ServerFactory(private val builder: ServerFactoryBuilder) : Application, BusyDelegation {
    protected lateinit var installer: Installer
    protected var configuration: Configuration? = null
    private val executor = TaskExecutor.instantiate(5)
    
    override fun run() {
        // 1. Initialize configuration
        ConfigurationManager.initialize()
        
        // 2. On success, deployment proceeds:
        // - InstallationFlow: Execute software installation steps
        // - DockerInitializationFlow: Set up Docker
        // - DockerDeploymentFlow: Deploy mail stack containers
        // - DatabaseFlow: Initialize PostgreSQL
        // - TerminationFlow: Create mail accounts
    }
}
```

### 5.3 Mail Server Factory Extension

**Location**: `Factory/src/main/kotlin/net/milosvasic/factory/mail/application/server_factory/MailServerFactory.kt`

```kotlin
class MailServerFactory(builder: ServerFactoryBuilder) : ServerFactory(builder) {
    
    override fun run() {
        configuration?.let {
            if (it is MailServerConfiguration) {
                // Log accounts to be created
                it.accounts?.forEach { account ->
                    val suffix = if (account.getAccountType() == AccountType.POSTMASTER) {
                        " ( * )"
                    } else {
                        ""
                    }
                    log.d("Mail account to be created: ${account.print()}$suffix")
                }
            }
        }
        super.run()
    }
    
    override fun getTerminationFlow(connection: Connection): FlowBuilder<*, *, *> {
        val mailFactory = MailFactory(connection)
        return mailFactory
                .getMailCreationFlow()
                .onFinish(TerminationCallback(this))
    }
    
    override fun getConfigurationFactory() = MailServerConfigurationFactory()
}
```

---

## 6. MAIL SERVER CONFIGURATION

### 6.1 Mail Account Management

**Location**: `Factory/src/main/kotlin/net/milosvasic/factory/mail/account/`

**MailAccount Class**:
```kotlin
// Extends Account from Core Framework
class MailAccount(
    name: String,
    type: AccountType,
    credentials: Credentials
) : Account(name, type, credentials) {
    // Mail-specific fields and methods
}
```

### 6.2 Mail Server Configuration Factory

**Location**: `Factory/src/main/kotlin/net/milosvasic/factory/mail/configuration/MailServerConfigurationFactory.kt`

```kotlin
class MailServerConfigurationFactory : ConfigurationFactory<MailServerConfiguration>() {
    
    override fun getType(): Type {
        return object : TypeToken<MailServerConfiguration>() {}.type
    }
    
    override fun onInstantiated(configuration: MailServerConfiguration) {
        if (configuration.accounts == null) {
            configuration.accounts = LinkedBlockingQueue()
        }
    }
    
    override fun validateConfiguration(configuration: MailServerConfiguration): Boolean {
        val validator = MailAccountValidator()
        configuration.accounts?.forEach { account ->
            try {
                if (!validator.validate(account)) {
                    log.e("Account is not valid: $account")
                    return false
                }
            } catch (e: IllegalArgumentException) {
                log.e(e)
                return false
            }
        }
        return true
    }
}
```

### 6.3 Mail-Specific Configuration Variables

**Location**: `Factory/src/main/kotlin/net/milosvasic/factory/mail/configuration/variable/`

Context and Key definitions for mail server configuration:
- `Context.ServiceMailReceive` - Dovecot service
- `Key.DbDirectory` - Database directory
- `Key.TableDomains` - Domains table
- `Key.TableUsers` - Users table
- `Key.TableAliases` - Email aliases table

---

## 7. COMPLETE DEPLOYMENT SEQUENCE

### 7.1 Entry Point

**File**: `Application/src/main/kotlin/net/milosvasic/factory/mail/application/main.kt`

```kotlin
fun main(args: Array<String>) {
    // 1. Parse arguments and set up logging
    args.forEach { arg ->
        if (arg.startsWith(Argument.INSTALLATION_HOME.get())) {
            builder.setInstallationHome(...)
        }
    }
    
    // 2. Initialize OS-specific features
    OSInit.run()
    
    // 3. Load configuration file
    val file = File(args[0])
    val recipe = FileConfigurationRecipe(file)
    builder.setRecipe(recipe)
    
    // 4. Create MailServerFactory
    val factory = MailServerFactory(builder)
    
    // 5. Run initialization flow
    InitializationFlow()
        .width(factory)
        .handler(handler)
        .onFinish(callback)
        .run()
    
    // 6. On success, run deployment
    factory.run()
}
```

### 7.2 Initialization Phase

1. **Configuration Loading**:
   - Parse JSON configuration file
   - Resolve includes and variables
   - Establish SSH connection to remote server

2. **Remote OS Detection**:
   - Execute system information command on remote
   - Parse output to determine OS platform
   - Store platform in SSH connection object

3. **Definition Loading**:
   - Load software definitions for detected OS
   - Resolve OS-specific installation recipes
   - Merge variables from definitions

### 7.3 Deployment Phase

1. **Installation Step Execution**:
   - Get installation steps for remote platform
   - Execute steps sequentially via SSH
   - Handle conditional skips and reboots

2. **Package Manager Operations**:
   - Select appropriate package manager (yum, apt, etc.)
   - Execute OS-specific package installation commands
   - Support package groups (yum groupinstall)

3. **Docker Stack Deployment**:
   - Initialize Docker network
   - Deploy container stack (Postfix, Dovecot, PostgreSQL, Rspamd, Redis, ClamAV)

4. **Mail Account Creation**:
   - Insert domains into PostgreSQL
   - Create user accounts with hashed passwords
   - Set up email aliases

---

## 8. KEY ARCHITECTURAL PATTERNS

### 8.1 Factory Inheritance Pattern

```
Configuration (Core)
    ↑
    └── MailServerConfiguration (Mail)

ConfigurationFactory (Core)
    ↑
    └── MailServerConfigurationFactory (Mail)

ServerFactory (Core)
    ↑
    └── MailServerFactory (Mail)
```

### 8.2 OS Detection Pattern

```
Host OS Detection
    ├── System.getProperty("os.name")
    ├── Platform enum matching
    └── OS-specific source sets (macos/, default/)

Remote OS Detection
    ├── SSH command execution
    ├── Output parsing (Operating System:, Architecture:)
    ├── Platform enum matching
    └── Storage in SSH.operatingSystem
```

### 8.3 Configuration Resolution Pattern

```
Examples/*.json
    ↓ (loaded)
Includes (Common.json)
    ↓ (processed)
Software Definitions (Uses.json)
    ↓ (resolved)
Definition.json (metadata)
    ├─ Centos/*.json
    ├─ Fedora/*.json
    └─ Ubuntu/*.json
    ↓ (platform matched)
Concrete Installation Recipe
```

### 8.4 Execution Flow Pattern

```
InitializationFlow
    ├── ConfigurationManager.initialize()
    ├── Remote OS Detection
    └── Definition Loading (platform-specific)
        ↓
ServerFactory.run()
    ├── InstallationFlow → Install Software
    ├── DockerFlow → Initialize Docker
    ├── DockerDeploymentFlow → Deploy Containers
    ├── DatabaseFlow → Initialize Database
    └── MailFactory → Create Mail Accounts
```

---

## 9. FILE LOCATIONS SUMMARY

### Core Platform Detection
- `/home/milosvasic/Projects/Mail-Server-Factory/Core/Framework/src/main/kotlin/net/milosvasic/factory/platform/OperatingSystem.kt`
- `/home/milosvasic/Projects/Mail-Server-Factory/Core/Framework/src/main/kotlin/net/milosvasic/factory/platform/Platform.kt`
- `/home/milosvasic/Projects/Mail-Server-Factory/Core/Framework/src/main/kotlin/net/milosvasic/factory/platform/Architecture.kt`
- `/home/milosvasic/Projects/Mail-Server-Factory/Core/Framework/src/main/kotlin/net/milosvasic/factory/platform/HostInfoDataHandler.kt`

### OS-Specific Application Code
- `/home/milosvasic/Projects/Mail-Server-Factory/Application/src/os/default/kotlin/net/milosvasic/factory/mail/application/OSInit.kt`
- `/home/milosvasic/Projects/Mail-Server-Factory/Application/src/os/macos/kotlin/net/milosvasic/factory/mail/application/OSInit.kt`

### Installation Architecture
- `/home/milosvasic/Projects/Mail-Server-Factory/Core/Framework/src/main/kotlin/net/milosvasic/factory/component/installer/Installer.kt`
- `/home/milosvasic/Projects/Mail-Server-Factory/Core/Framework/src/main/kotlin/net/milosvasic/factory/component/installer/recipe/InstallationStepRecipe.kt`
- `/home/milosvasic/Projects/Mail-Server-Factory/Core/Framework/src/main/kotlin/net/milosvasic/factory/component/installer/step/InstallationStep.kt`
- `/home/milosvasic/Projects/Mail-Server-Factory/Core/Framework/src/main/kotlin/net/milosvasic/factory/component/installer/step/PackageManagerInstallationStep.kt`

### Configuration System
- `/home/milosvasic/Projects/Mail-Server-Factory/Core/Framework/src/main/kotlin/net/milosvasic/factory/configuration/SoftwareConfiguration.kt`
- `/home/milosvasic/Projects/Mail-Server-Factory/Core/Framework/src/main/kotlin/net/milosvasic/factory/configuration/ConfigurationManager.kt`
- `/home/milosvasic/Projects/Mail-Server-Factory/Core/Framework/src/main/kotlin/net/milosvasic/factory/configuration/definition/provider/FilesystemDefinitionProvider.kt`

### Package Management
- `/home/milosvasic/Projects/Mail-Server-Factory/Core/Framework/src/main/kotlin/net/milosvasic/factory/component/packaging/PackageManager.kt`
- `/home/milosvasic/Projects/Mail-Server-Factory/Core/Framework/src/main/kotlin/net/milosvasic/factory/component/packaging/Yum.kt`
- `/home/milosvasic/Projects/Mail-Server-Factory/Core/Framework/src/main/kotlin/net/milosvasic/factory/component/packaging/Apt.kt`

### Remote Execution
- `/home/milosvasic/Projects/Mail-Server-Factory/Core/Framework/src/main/kotlin/net/milosvasic/factory/remote/ssh/SSH.kt`
- `/home/milosvasic/Projects/Mail-Server-Factory/Core/Framework/src/main/kotlin/net/milosvasic/factory/remote/Connection.kt`

### Mail Server Implementation
- `/home/milosvasic/Projects/Mail-Server-Factory/Factory/src/main/kotlin/net/milosvasic/factory/mail/application/server_factory/MailServerFactory.kt`
- `/home/milosvasic/Projects/Mail-Server-Factory/Factory/src/main/kotlin/net/milosvasic/factory/mail/configuration/MailServerConfigurationFactory.kt`
- `/home/milosvasic/Projects/Mail-Server-Factory/Factory/src/main/kotlin/net/milosvasic/factory/mail/account/MailAccount.kt`

### Definition Files
- `/home/milosvasic/Projects/Mail-Server-Factory/Definitions/main/software/docker/1.0.0/Definition.json`
- `/home/milosvasic/Projects/Mail-Server-Factory/Definitions/main/software/docker/1.0.0/Centos/Docker.json`
- `/home/milosvasic/Projects/Mail-Server-Factory/Definitions/main/software/docker/1.0.0/Ubuntu/Docker.json`

### Example Configurations
- `/home/milosvasic/Projects/Mail-Server-Factory/Examples/Centos_8.json`
- `/home/milosvasic/Projects/Mail-Server-Factory/Examples/Includes/Common.json`

---

## 10. KNOWN ISSUES AND OBSERVATIONS

1. **OS Detection Bug** in `OperatingSystem.kt`:
   - `isLinux()`, `isWindows()`, and `isMacOS()` all check for "mac"
   - Should be:
     - `isLinux()` → `getOS().contains("linux")`
     - `isWindows()` → `getOS().contains("win")`
     - `isMacOS()` → `getOS().contains("mac")`

2. **MailAccount Constructor Bug** (Fixed in CLAUDE.md):
   - Parameters passed to parent Account class in wrong order
   - Correct order: `Account(name, type, credentials)`

3. **Platform Fallback Chain**:
   - When exact platform match fails, system falls back to broader categories
   - E.g., Fedora 33 → Fedora → CentOS → DOCKER
   - Ensures installation recipes are always found

---

## CONCLUSION

The Mail Server Factory uses a sophisticated multi-layered architecture:

1. **Host OS Detection** determines application behavior locally (macOS dock icon, etc.)
2. **Remote OS Detection** via SSH identifies target server platform
3. **JSON Definition System** provides OS-specific installation recipes
4. **Configuration Resolution** matches detected OS to appropriate definitions
5. **Package Manager Abstraction** executes OS-specific commands (yum, apt, etc.)
6. **Flow Orchestration** sequences installation steps, Docker deployment, and mail account creation

This design enables single-source deployment configurations that automatically adapt to any supported Linux distribution without explicit per-OS branching logic in the application code.
