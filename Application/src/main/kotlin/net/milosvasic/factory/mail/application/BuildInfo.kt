package net.milosvasic.factory.mail.application

import net.milosvasic.factory.application.BuildInformation

object BuildInfo : BuildInformation {

    override val version = "1.0.0 Alpha 2.3"
    override val versionCode = 11
    override val productName = "Mail-Server-Factory"
    override val versionName = "Mail Server Factory"

    override fun printName() = "$versionName $version"
}