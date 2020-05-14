package net.milosvasic.factory.mail.test.implementation

import net.milosvasic.factory.mail.component.installer.step.deploy.Deploy
import net.milosvasic.factory.mail.remote.Remote
import net.milosvasic.factory.mail.terminal.Commands
import net.milosvasic.factory.mail.terminal.TerminalCommand

class StubDeploy(what: String, private val where: String) : Deploy(what, where) {

    override fun getScp(remote: Remote): String {
        return Commands.cp(localTar, where)
    }

    override fun getScpCommand() = Commands.cp

    override fun isRemote(operation: TerminalCommand) =
            operation.command.contains(StubSSH.stubCommandMarker)
}