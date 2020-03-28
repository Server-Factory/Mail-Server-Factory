package net.milosvasic.factory.mail.component

import net.milosvasic.factory.mail.common.Installation
import net.milosvasic.factory.mail.common.Notifying
import net.milosvasic.factory.mail.common.Subscription
import net.milosvasic.factory.mail.operation.OperationResult
import net.milosvasic.factory.mail.operation.OperationResultListener

class Installer(private val installations: List<Installation>) : SystemComponent() {

    private val subscribers = mutableSetOf<OperationResultListener>()

    override fun install() {

        installations.forEach {
            it.install()
        }
    }

    override fun uninstall() {

        installations.forEach {
            it.uninstall()
        }
    }

    override fun subscribe(what: OperationResultListener) {
        subscribers.add(what)
    }

    override fun unsubscribe(what: OperationResultListener) {
        subscribers.remove(what)
    }

    override fun notify(data: OperationResult) {
        val iterator = subscribers.iterator()
        while (iterator.hasNext()) {
            val listener = iterator.next()
            listener.onOperationPerformed(data)
        }
    }
}