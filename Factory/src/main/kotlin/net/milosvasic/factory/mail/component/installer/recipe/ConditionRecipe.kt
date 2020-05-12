package net.milosvasic.factory.mail.component.installer.recipe

import net.milosvasic.factory.mail.component.installer.step.condition.Condition
import net.milosvasic.factory.mail.component.installer.step.condition.ConditionOperation
import net.milosvasic.factory.mail.execution.flow.processing.FlowProcessingCallback
import net.milosvasic.factory.mail.operation.OperationResult
import net.milosvasic.factory.mail.operation.OperationResultListener

class ConditionRecipe : InstallationStepRecipe() {

    private val operationCallback = object : OperationResultListener {
        override fun onOperationPerformed(result: OperationResult) {
            toolkit?.connection?.unsubscribe(this)
            when (result.operation) {
                is ConditionOperation -> {
                    if (result.success) {
                        if (result.operation.result) {
                            // tryNextSection()
                        } else {
                            // tryNext()
                        }
                    } else {
                        if (result.operation.result) {
                            // tryNext()
                        } else {
                            // free(false)
                        }
                    }
                    callback?.onFinish(result.success, getErrorMessage(result))
                    callback = null
                }
            }
        }
    }

    @Throws(IllegalStateException::class, IllegalArgumentException::class)
    override fun process(callback: FlowProcessingCallback) {
        super.process(callback)
        val validator = InstallationStepRecipeValidator()
        if (!validator.validate(this)) {
            throw IllegalArgumentException("Invalid installation step recipe: $this")
        }
        if (toolkit?.connection == null) {
            throw IllegalArgumentException("Connection not provided")
        }
        step?.let { s ->
            if (s !is Condition) {
                throw IllegalArgumentException("Unexpected installation step type: ${s::class.simpleName}")
            }
        }
        try {

            toolkit?.let { tools ->
                step?.let { s ->
                    val step = s as Condition
                    tools.connection?.let { conn ->
                        conn.subscribe(operationCallback)
                        step.execute(conn)
                    }
                }
            }
        } catch (e: IllegalStateException) {

            fail(e)
        } catch (e: IllegalArgumentException) {

            fail(e)
        }
    }
}