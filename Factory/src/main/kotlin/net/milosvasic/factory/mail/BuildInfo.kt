package net.milosvasic.factory.mail

import net.milosvasic.factory.application.BuildInformation

object BuildInfo : BuildInformation {

    override val version = "1.0.0 Alpha 2.1"
    override val versionCode = 9
    override val productName = "Mail-Server-Factory"
    override val versionName = "Mail Server Factory"

    override fun printName() = "$versionName $version"
}