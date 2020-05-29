package net.milosvasic.factory.mail.component.installer.step.certificate

import net.milosvasic.factory.mail.component.installer.step.RemoteOperationInstallationStep
import net.milosvasic.factory.mail.configuration.Variable
import net.milosvasic.factory.mail.configuration.VariableContext
import net.milosvasic.factory.mail.configuration.VariableKey
import net.milosvasic.factory.mail.configuration.VariableNode
import net.milosvasic.factory.mail.execution.flow.implementation.CommandFlow
import net.milosvasic.factory.mail.remote.ssh.SSH

class Certificate(val name: String) : RemoteOperationInstallationStep<SSH>() {

    @Throws(IllegalArgumentException::class, IllegalStateException::class)
    override fun getFlow(): CommandFlow {

        connection?.let { conn ->

            val ctxServer = VariableContext.Server.context
            val ctxCertification = VariableContext.Certification.context
            val ctxSeparator = VariableNode.contextSeparator
            val keyHome = VariableKey.HOME.key
            val key = "$ctxServer$ctxSeparator$ctxCertification$ctxSeparator$keyHome"
            val path = Variable.parse(key)

            return CommandFlow()
                    .width(conn)
                    .perform(GeneratePrivateKeyCommand(path, name))
        }
        throw IllegalArgumentException("No proper connection provided")
    }

    override fun getOperation() = CertificateInitializationOperation()
}