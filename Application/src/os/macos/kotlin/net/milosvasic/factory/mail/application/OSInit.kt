package net.milosvasic.factory.mail.application

import net.milosvasic.factory.log
import net.milosvasic.factory.platform.OperatingSystem
import net.milosvasic.factory.platform.Platform
import java.awt.Taskbar
import java.io.IOException
import javax.imageio.ImageIO

object OSInit : Runnable {

    @Throws(
            IllegalArgumentException::class,
            NullPointerException::class,
            SecurityException::class,
            IOException::class
    )
    override fun run() {

        log.v("Starting: ${BuildInfo.versionName}, ${BuildInfo.version}")
        val hostOS = OperatingSystem.getHostOperatingSystem()
        val iconResourceName = "assets/Logo.png"
        val iconResource = hostOS::class.java.classLoader.getResourceAsStream(iconResourceName)
        val icon = ImageIO.read(iconResource)
        if (hostOS.getPlatform() == Platform.MAC_OS) {

            System.setProperty("apple.awt.application.name", BuildInfo.printName())

            // Use Java 9+ Taskbar API instead of deprecated com.apple.eawt
            try {
                if (Taskbar.isTaskbarSupported()) {
                    val taskbar = Taskbar.getTaskbar()
                    if (taskbar.isSupported(Taskbar.Feature.ICON_IMAGE)) {
                        taskbar.iconImage = icon
                    }
                }
            } catch (e: Exception) {
                log.w("Could not set dock icon: ${e.message}")
            }
        }
    }
}