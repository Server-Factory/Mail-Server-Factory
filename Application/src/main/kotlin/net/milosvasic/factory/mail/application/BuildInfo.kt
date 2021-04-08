package net.milosvasic.factory.mail.application

import net.milosvasic.factory.application.BuildInformation

object BuildInfo : BuildInformation {

    override val version = "1.0.0 Alpha 2"
    override val versionCode = (100 * 1000) + 0
    override val productName = "Mail-Server-Factory"
    override val versionName = "Mail Server Factory Client"

    override fun printName() = "$versionName $version"
}