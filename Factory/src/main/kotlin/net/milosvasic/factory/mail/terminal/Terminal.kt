package net.milosvasic.factory.mail.terminal

import net.milosvasic.factory.mail.EMPTY
import net.milosvasic.factory.mail.common.Executor
import net.milosvasic.factory.mail.common.Notifying
import net.milosvasic.factory.mail.common.busy.Busy
import net.milosvasic.factory.mail.common.busy.BusyException
import net.milosvasic.factory.mail.common.busy.BusyWorker
import net.milosvasic.factory.mail.execution.TaskExecutor
import net.milosvasic.factory.mail.log
import net.milosvasic.factory.mail.operation.OperationResult
import net.milosvasic.factory.mail.operation.OperationResultListener
import net.milosvasic.factory.mail.operation.command.CommandConfiguration
import java.io.BufferedReader
import java.io.InputStreamReader
import java.util.concurrent.ConcurrentLinkedQueue

class Terminal :
        Executor<TerminalCommand>,
        Notifying<OperationResult> {

    private val busy = Busy()
    private val runtime = Runtime.getRuntime()
    private val executor = TaskExecutor.instantiate(1)
    private val subscribers = ConcurrentLinkedQueue<OperationResultListener>()

    @Synchronized
    @Throws(BusyException::class, IllegalArgumentException::class)
    override fun execute(what: TerminalCommand) {
        if (what.command == String.EMPTY) {
            throw IllegalArgumentException("Empty terminal command")
        }
        BusyWorker.busy(busy)
        val action = Runnable {
            try {
                var logCommand = false
                what.configuration[CommandConfiguration.LOG_COMMAND]?.let {
                    logCommand = it
                }
                if (logCommand) {
                    log.d(">>> ${what.command}")
                }

                val process = runtime.exec(what.command)
                val stdIn = BufferedReader(InputStreamReader(process.inputStream))
                val stdErr = BufferedReader(InputStreamReader(process.errorStream))

                var obtainOutput = false
                what.configuration[CommandConfiguration.OBTAIN_RESULT]?.let {
                    obtainOutput = it
                }

                var logCommandResult = false
                what.configuration[CommandConfiguration.LOG_COMMAND_RESULT]?.let {
                    logCommandResult = it
                }

                val inData = readToLog(stdIn, obtainOutput, logCommandResult)
                val errData = readToLog(stdErr, obtainOutput, logCommandResult)
                val noExitValue = -1
                var exitValue = noExitValue
                while (exitValue == noExitValue) {
                    try {
                        exitValue = process.exitValue()
                    } catch (e: IllegalThreadStateException) {
                        if (logCommandResult) {
                            log.w(e)
                        }
                    }
                }
                val success = exitValue == 0
                val result = OperationResult(what, success, inData + errData)
                BusyWorker.free(busy)
                notify(result)
            } catch (e: Exception) {

                log.e(e)
                BusyWorker.free(busy)
                val result = OperationResult(what, false, String.EMPTY, e)
                notify(result)
            }
        }
        executor.execute(action)
    }

    override fun subscribe(what: OperationResultListener) {
        subscribers.add(what)
    }

    override fun unsubscribe(what: OperationResultListener) {
        subscribers.remove(what)
    }

    @Synchronized
    override fun notify(data: OperationResult) {
        val iterator = subscribers.iterator()
        while (iterator.hasNext()) {
            val listener = iterator.next()
            listener.onOperationPerformed(data)
        }
    }

    private fun readToLog(
            reader: BufferedReader,
            obtainOutput: Boolean = false,
            logCommandResult: Boolean = false

    ): String {
        val builder = StringBuilder()
        var s = reader.readLine()
        while (s != null) {
            if (logCommandResult) {
                log.v("<<< $s")
            }
            if (obtainOutput) {
                builder.append(s).append("\n")
            }
            s = reader.readLine()
        }
        return builder.toString().trim()
    }
}