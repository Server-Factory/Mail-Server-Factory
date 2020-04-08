package net.milosvasic.factory.mail.component.installer.step.condition

import net.milosvasic.factory.mail.component.installer.step.RemoteOperationInstallationStep
import net.milosvasic.factory.mail.operation.OperationResult
import net.milosvasic.factory.mail.remote.Connection
import net.milosvasic.factory.mail.remote.ssh.SSHCommand

class Condition(private val command: String) : RemoteOperationInstallationStep<Connection>() {

    override fun handleResult(result: OperationResult) {
        when (result.operation) {
            is SSHCommand -> {
                if (result.operation.command.endsWith(command)) {
                    finish(result.success, result.exception == null)
                }
            }
        }
    }

    @Synchronized
    @Throws(IllegalArgumentException::class, IllegalStateException::class)
    override fun execute(vararg params: Connection) {
        super.execute(*params)
        connection?.execute(command)
    }

    private fun finish(success: Boolean, result: Boolean) {
        val operation = ConditionOperation(result)
        finish(success, operation)
    }
}