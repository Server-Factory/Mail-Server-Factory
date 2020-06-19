package net.milosvasic.factory.mail.execution.flow.implementation

import net.milosvasic.factory.mail.common.Registration
import net.milosvasic.factory.mail.common.busy.BusyException
import net.milosvasic.factory.mail.common.obtain.Obtain
import net.milosvasic.factory.mail.execution.flow.FlowBuilder
import net.milosvasic.factory.mail.execution.flow.FlowPerformBuilder
import net.milosvasic.factory.mail.execution.flow.callback.FlowCallback
import net.milosvasic.factory.mail.execution.flow.processing.FlowProcessingCallback
import net.milosvasic.factory.mail.execution.flow.processing.ProcessingRecipe
import net.milosvasic.factory.mail.log

class RegistrationFlow<T> : FlowPerformBuilder<Registration<T>, T, String>() {

    @Throws(BusyException::class)
    override fun width(subject: Registration<T>): RegistrationFlow<T> {
        super.width(subject)
        return this
    }

    @Throws(BusyException::class)
    override fun perform(what: T): RegistrationFlow<T> {
        super.perform(what)
        return this
    }

    @Throws(BusyException::class)
    override fun perform(what: Obtain<T>): RegistrationFlow<T> {
        super.perform(what)
        return this
    }

    @Throws(BusyException::class)
    override fun onFinish(callback: FlowCallback): RegistrationFlow<T> {
        super.onFinish(callback)
        return this
    }

    @Throws(BusyException::class)
    override fun connect(flow: FlowBuilder<*, *, *>): RegistrationFlow<T> {
        super.connect(flow)
        return this
    }

    @Throws(IllegalArgumentException::class)
    override fun getProcessingRecipe(subject: Registration<T>, operation: T): ProcessingRecipe {

        return object : ProcessingRecipe {

            override fun process(callback: FlowProcessingCallback) {
                try {
                    subject.register(operation)
                    callback.onFinish(true)
                } catch (e: Exception) {

                    log.e(e)
                    callback.onFinish(false)
                }
            }
        }
    }
}