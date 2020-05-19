package net.milosvasic.factory.mail.component.packaging

import net.milosvasic.factory.mail.EMPTY
import net.milosvasic.factory.mail.common.busy.LegacyBusyWorker
import net.milosvasic.factory.mail.common.initialization.Initialization
import net.milosvasic.factory.mail.component.packaging.item.Group
import net.milosvasic.factory.mail.component.packaging.item.InstallationItem
import net.milosvasic.factory.mail.component.packaging.item.Package
import net.milosvasic.factory.mail.component.packaging.item.Packages
import net.milosvasic.factory.mail.log
import net.milosvasic.factory.mail.operation.OperationResult
import net.milosvasic.factory.mail.remote.Connection
import net.milosvasic.factory.mail.terminal.Commands
import net.milosvasic.factory.mail.terminal.TerminalCommand

class PackageInstaller(entryPoint: Connection) :
        LegacyBusyWorker<PackageManager>(entryPoint),
        PackageManagement<PackageManager>,
        PackageManagerSupport,
        Initialization {

    private var item: PackageManager? = null
    private var manager: PackageManager? = null
    private val supportedPackageManagers = LinkedHashSet<PackageManager>()

    init {
        supportedPackageManagers.addAll(
                listOf(
                        Dnf(entryPoint),
                        Yum(entryPoint),
                        AptGet(entryPoint)
                )
        )
    }

    override fun handleResult(result: OperationResult) {
        when (result.operation) {
            is TerminalCommand -> {
                val cmd = result.operation.command
                if (command != String.EMPTY && cmd.endsWith(command)) {

                    try {
                        if (result.success) {
                            onSuccessResult()
                        } else {
                            onFailedResult()
                        }
                    } catch (e: IllegalStateException) {
                        onFailedResult(e)
                    } catch (e: IllegalArgumentException) {
                        onFailedResult(e)
                    }
                }
            }
            is PackageManagerOperation -> {
                notify(result)
            }
            else -> {

                log.e("Unexpected operation result: $result")
                try {
                    onFailedResult()
                } catch (e: IllegalStateException) {
                    onFailedResult(e)
                } catch (e: IllegalArgumentException) {
                    onFailedResult(e)
                }
            }
        }
    }

    @Synchronized
    @Throws(IllegalStateException::class, IllegalArgumentException::class)
    override fun initialize() {
        checkInitialized()
        busy()
        iterator = supportedPackageManagers.iterator()
        tryNext()
    }

    @Synchronized
    @Throws(IllegalStateException::class)
    override fun terminate() {
        checkNotInitialized()
        detach(manager)
        super.terminate()
    }

    @Throws(IllegalStateException::class, IllegalArgumentException::class)
    override fun onSuccessResult() {
        item?.let {
            manager = it
            attach(manager)
            log.i("${it.applicationBinaryName.capitalize()} package manager is initialized")
        }
        tryNext()
    }

    @Throws(IllegalStateException::class, IllegalArgumentException::class)
    override fun onFailedResult() {
        tryNext()
    }

    @Throws(IllegalStateException::class, IllegalArgumentException::class)
    override fun tryNext() {
        manager?.let {
            free(true)
            return
        }
        if (iterator == null) {
            free(false)
            return
        }
        iterator?.let {
            if (it.hasNext()) {
                item = it.next()
                item?.let { current ->
                    command = Commands.getApplicationInfo(current.applicationBinaryName)
                    entryPoint.execute(TerminalCommand(command))
                }
            } else {
                free(false)
            }
        }
    }

    @Throws(IllegalStateException::class, IllegalArgumentException::class)
    override fun install(vararg items: InstallationItem) {

        checkNotInitialized()
        manager?.install(*items.toList().toTypedArray())
    }

    @Throws(IllegalStateException::class, IllegalArgumentException::class)
    override fun install(packages: List<Package>) {
        checkNotInitialized()
        manager?.install(packages)
    }

    @Throws(IllegalStateException::class, IllegalArgumentException::class)
    override fun install(packages: Packages) {
        checkNotInitialized()
        manager?.install(packages)
    }

    @Throws(IllegalStateException::class, IllegalArgumentException::class)
    override fun uninstall(packages: List<Package>) {
        checkNotInitialized()
        manager?.uninstall(packages)
    }

    @Throws(IllegalStateException::class, IllegalArgumentException::class)
    override fun groupInstall(groups: List<Group>) {
        checkNotInitialized()
        manager?.groupInstall(groups)
    }

    @Throws(IllegalStateException::class, IllegalArgumentException::class)
    override fun groupUninstall(groups: List<Group>) {
        checkNotInitialized()
        manager?.groupUninstall(groups)
    }

    @Throws(IllegalStateException::class)
    override fun addSupportedPackageManager(packageManager: PackageManager) {
        checkInitialized()
        supportedPackageManagers.add(packageManager)
    }

    @Throws(IllegalStateException::class)
    override fun removeSupportedPackageManager(packageManager: PackageManager) {
        checkInitialized()
        supportedPackageManagers.remove(packageManager)
    }

    @Synchronized
    override fun notify(success: Boolean) {
        val operation = PackageInstallerInitializationOperation()
        val result = OperationResult(operation, success)
        notify(result)
    }

    @Synchronized
    override fun isInitialized(): Boolean {
        manager?.let {
            return true
        }
        return false
    }

    @Synchronized
    @Throws(IllegalStateException::class)
    override fun checkInitialized() {
        manager?.let {
            throw IllegalStateException("Package installer has been already initialized")
        }
    }

    @Synchronized
    @Throws(IllegalStateException::class)
    override fun checkNotInitialized() {
        if (manager == null) {
            throw IllegalStateException("Package installer has not been initialized")
        }
    }
}