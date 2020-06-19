package net.milosvasic.factory.mail.operation.command

import net.milosvasic.factory.mail.operation.Operation

open class Command(private val toExecute: String) : Operation() {

    override fun toString(): String {
        return "${this::class.simpleName}(toExecute='$toExecute')"
    }
}