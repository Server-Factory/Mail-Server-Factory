@file:JvmName("Launcher")

package net.milosvasic.factory.mail.application

import net.milosvasic.factory.*
import net.milosvasic.factory.application.Argument
import net.milosvasic.factory.application.DefaultInitializationHandler
import net.milosvasic.factory.application.server_factory.ServerFactoryBuilder
import net.milosvasic.factory.common.busy.BusyException
import net.milosvasic.factory.common.filesystem.FilePathBuilder
import net.milosvasic.factory.configuration.recipe.FileConfigurationRecipe
import net.milosvasic.factory.error.ERROR
import net.milosvasic.factory.execution.flow.callback.FlowCallback
import net.milosvasic.factory.execution.flow.implementation.initialization.InitializationFlow
import net.milosvasic.factory.mail.application.server_factory.MailServerFactory
import net.milosvasic.factory.validation.Validator
import net.milosvasic.factory.validation.parameters.ArgumentsExpectedException
import net.milosvasic.logger.ConsoleLogger
import net.milosvasic.logger.FilesystemLogger
import java.io.File
import java.io.IOException
import java.nio.file.InvalidPathException

fun main(args: Array<String>) {

    tag = BuildInfo.versionName
    val consoleLogger = ConsoleLogger()
    val builder = ServerFactoryBuilder()

    try {

        args.forEach { arg ->

            val argumentInstallationHome = Argument.INSTALLATION_HOME.get()
            if (arg.startsWith(argumentInstallationHome)) {

                val installationHome = arg.trim().replace(argumentInstallationHome, "")
                if (installationHome.isNotEmpty()) {

                    builder.setInstallationHome(installationHome)
                }

                try {

                    log.i("Installation location: ${builder.getInstallationLocation()}")
                } catch (e: SecurityException) {

                    log.e(e)
                }
            }
        }

        val installationLocation = builder.getInstallationLocation()

        val logsHomePath = FilePathBuilder()
            .addContext(installationLocation)
            .build()

        val logsHome = File(logsHomePath)

        val filesystemLogger = FilesystemLogger(logsHome)
        compositeLogger.addLoggers(consoleLogger, filesystemLogger)

        OSInit.run()

        Validator.Arguments.validateNotEmpty(*args)
        val file = File(args[0])

        val lofFilenameSuffix = file.name.replace(file.extension, "").replace(".", "") +
                "_" + System.currentTimeMillis()

        filesystemLogger.setFilenameSuffix(lofFilenameSuffix)

        log.i("Logs home directory: $logsHomePath")

        if (file.exists()) {

            val recipe = FileConfigurationRecipe(file)
            builder.setRecipe(recipe)

            val factory = MailServerFactory(builder)

            val callback = object : FlowCallback {
                override fun onFinish(success: Boolean) {

                    if (success) {
                        try {
                            log.i("Server factory initialized")
                            factory.run()
                        } catch (e: IllegalStateException) {
                            fail(e)
                        }
                    } else {

                        fail(ERROR.INITIALIZATION_FAILURE)
                    }
                }
            }

            val handler = DefaultInitializationHandler()

            InitializationFlow()
                .width(factory)
                .handler(handler)
                .onFinish(callback)
                .run()

        } else {

            val msg = "Configuration file does not exist: ${file.absolutePath}"
            val error = IllegalArgumentException(msg)
            fail(error)
        }
    } catch (e: ArgumentsExpectedException) {

        fail(e)
    } catch (e: BusyException) {

        fail(e)
    } catch (e: IllegalArgumentException) {

        fail(e)
    } catch (e: NullPointerException) {

        fail(e)
    } catch (e: SecurityException) {

        fail(e)
    } catch (e: IOException) {

        fail(e)
    } catch (e: InvalidPathException) {

        fail(e)
    }
}