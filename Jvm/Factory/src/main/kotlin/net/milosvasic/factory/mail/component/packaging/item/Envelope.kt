package net.milosvasic.factory.mail.component.packaging.item

class Envelope(private vararg val packages: String) {

    fun getValue(): String {
        var value = ""
        packages.forEach {
            value += "$it "
        }
        return value.trim()
    }
}