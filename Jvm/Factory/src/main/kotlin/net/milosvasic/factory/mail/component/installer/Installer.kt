package net.milosvasic.factory.mail.component.installer

import net.milosvasic.factory.mail.common.busy.BusyWorker
import net.milosvasic.factory.mail.component.Initialization
import net.milosvasic.factory.mail.component.installer.step.CommandInstallationStep
import net.milosvasic.factory.mail.component.installer.step.InstallationStep
import net.milosvasic.factory.mail.component.installer.step.PackageManagerInstallationStep
import net.milosvasic.factory.mail.component.packaging.PackageInstaller
import net.milosvasic.factory.mail.component.packaging.PackageInstallerInitializationOperation
import net.milosvasic.factory.mail.component.packaging.PackageManagerOperation
import net.milosvasic.factory.mail.configuration.SoftwareConfiguration
import net.milosvasic.factory.mail.operation.Command
import net.milosvasic.factory.mail.operation.OperationResult
import net.milosvasic.factory.mail.operation.OperationResultListener
import net.milosvasic.factory.mail.remote.ssh.SSH
import net.milosvasic.factory.mail.terminal.Commands
import java.lang.IllegalArgumentException

class Installer(
    private val configuration: SoftwareConfiguration,
    entryPoint: SSH
) :
    BusyWorker<InstallationStep<*>>(entryPoint),
    Installation,
    Initialization {

    private var item: InstallationStep<*>? = null
    private val installer = PackageInstaller(entryPoint)

    private val listener = object : OperationResultListener {
        override fun onOperationPerformed(result: OperationResult) {

            when (result.operation) {
                is PackageInstallerInitializationOperation -> {

                    val installerInitializationOperation = InstallerInitializationOperation()
                    val operationResult = OperationResult(installerInitializationOperation, result.success)
                    notify(operationResult)
                }
            }
        }
    }

    @Synchronized
    @Throws(IllegalStateException::class)
    override fun initialize() {
        checkInitialized()
        busy()
        installer.subscribe(listener)
        installer.initialize()
    }

    @Synchronized
    @Throws(IllegalStateException::class)
    override fun terminate() {
        checkNotInitialized()
        installer.unsubscribe(listener)
        installer.terminate()
        super.terminate()
    }

    @Synchronized
    @Throws(IllegalStateException::class)
    override fun checkInitialized() {
        if (isInitialized()) {
            throw IllegalStateException("Installer has been already initialized")
        }
    }

    @Synchronized
    @Throws(IllegalStateException::class)
    override fun checkNotInitialized() {
        if (!isInitialized()) {
            throw IllegalStateException("Installer has not been initialized")
        }
    }

    @Synchronized
    override fun isInitialized() = installer.isInitialized()

    @Synchronized
    override fun install() {

        try {
            val steps = configuration.obtain(entryPoint.getRemoteOS().getType().osName)
            busy()
            iterator = steps.iterator()
            tryNext()
        } catch (e: IllegalArgumentException) {

            free(false)
        } catch (e: IllegalStateException) {

            free(false)
        }
    }

    @Synchronized
    @Throws(UnsupportedOperationException::class)
    override fun uninstall() {
        throw UnsupportedOperationException("Not implemented yet.")
    }

    override fun notify(data: OperationResult) {
        super.notify(data)
    }

    override fun busy() {
        super.busy()
    }

    override fun free() {
        super.free()
    }

    override fun free(success: Boolean) {
        super.free(success)
    }

    @Throws(IllegalStateException::class)
    override fun tryNext() {

        if (iterator == null) {
            free(false)
            return
        }
        iterator?.let {
            if (it.hasNext()) {
                item = it.next()
                item?.let { current ->

                    when (current) {
                        is CommandInstallationStep -> {
                            current.execute(entryPoint)
                        }
                        is PackageManagerInstallationStep -> {
                            current.execute(installer)
                        }
                        else -> {
                            throw IllegalStateException("Unsupported installation step: $current")
                        }
                    }
                }
            } else {
                free(false)
            }
        }
    }

    override fun onSuccessResult() {

        tryNext()
    }

    override fun onFailedResult() {

        free(false)
    }

    override fun handleResult(result: OperationResult) {

        when(result.operation) {
            is Command -> {

            }
            is PackageManagerOperation -> {

            }
        }
    }

    override fun notify(success: Boolean) {
        val operation = InstallerOperation()
        val result = OperationResult(operation, success)
        notify(result)
    }
}