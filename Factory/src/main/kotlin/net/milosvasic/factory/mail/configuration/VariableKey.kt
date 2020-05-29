package net.milosvasic.factory.mail.configuration

enum class VariableKey(val key: String) {

    HOME("HOME"),
    HOSTNAME("HOSTNAME"),
    SERVER_HOME("SERVER_HOME"),
    DOCKER_HOME("DOCKER_HOME"),
    REBOOT_ALLOWED("REBOOT_ALLOWED"),
    DOCKER_COMPOSE_PATH("DOCKER_COMPOSE_PATH"),
    DB_PORT("DB_PORT"),
    DB_PASSWORD("DB_PASSWORD")
}