package net.milosvasic.factory.mail.configuration

data class Configuration(
    val name: String,
    val services: List<Service>
)