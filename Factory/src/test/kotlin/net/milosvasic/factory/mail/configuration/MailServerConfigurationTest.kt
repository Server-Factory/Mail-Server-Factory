package net.milosvasic.factory.mail.configuration

import net.milosvasic.factory.mail.account.MailAccount
import net.milosvasic.factory.remote.Remote
import net.milosvasic.factory.remote.ssh.SSH
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.DisplayName
import java.util.concurrent.LinkedBlockingQueue

@DisplayName("MailServerConfiguration Tests")
class MailServerConfigurationTest {

    private fun createTestRemote(): Remote {
        return Remote("localhost", "127.0.0.1", 22, "testuser")
    }

    @Test
    @DisplayName("Constructor creates MailServerConfiguration with accounts")
    fun testConstructorWithAccounts() {
        // Given
        val remote = createTestRemote()
        val accounts = LinkedBlockingQueue<MailAccount>()
        accounts.add(MailAccount("test@example.com", "pass123", "email", null))

        // When
        val config = MailServerConfiguration(
            remote = remote,
            uses = null,
            includes = null,
            software = null,
            containers = null,
            overrides = null,
            deployment = null,
            accounts = accounts
        )

        // Then
        assertNotNull(config)
        assertNotNull(config.accounts)
        assertEquals(1, config.accounts?.size)
    }

    @Test
    @DisplayName("Constructor creates MailServerConfiguration with null accounts")
    fun testConstructorWithNullAccounts() {
        // Given
        val remote = createTestRemote()

        // When
        val config = MailServerConfiguration(
            remote = remote,
            uses = null,
            includes = null,
            software = null,
            containers = null,
            overrides = null,
            deployment = null,
            accounts = null
        )

        // Then
        assertNotNull(config)
        assertNull(config.accounts)
    }

    @Test
    @DisplayName("merge adds accounts from another MailServerConfiguration")
    fun testMergeWithMailServerConfiguration() {
        // Given
        val remote = createTestRemote()

        val accounts1 = LinkedBlockingQueue<MailAccount>()
        accounts1.add(MailAccount("user1@example.com", "pass123", "email", null))

        val accounts2 = LinkedBlockingQueue<MailAccount>()
        accounts2.add(MailAccount("user2@example.com", "pass456", "email", null))

        val config1 = MailServerConfiguration(
            remote = remote,
            uses = null,
            includes = null,
            software = null,
            containers = null,
            overrides = null,
            deployment = null,
            accounts = accounts1
        )

        val config2 = MailServerConfiguration(
            remote = remote,
            uses = null,
            includes = null,
            software = null,
            containers = null,
            overrides = null,
            deployment = null,
            accounts = accounts2
        )

        // When
        config1.merge(config2)

        // Then
        assertNotNull(config1.accounts)
        assertEquals(2, config1.accounts?.size)
    }

    @Test
    @DisplayName("merge with null accounts in source configuration")
    fun testMergeWithNullSourceAccounts() {
        // Given
        val remote = createTestRemote()

        val accounts1 = LinkedBlockingQueue<MailAccount>()
        accounts1.add(MailAccount("user1@example.com", "pass123", "email", null))

        val config1 = MailServerConfiguration(
            remote = remote,
            uses = null,
            includes = null,
            software = null,
            containers = null,
            overrides = null,
            deployment = null,
            accounts = accounts1
        )

        val config2 = MailServerConfiguration(
            remote = remote,
            uses = null,
            includes = null,
            software = null,
            containers = null,
            overrides = null,
            deployment = null,
            accounts = null
        )

        // When
        config1.merge(config2)

        // Then
        assertNotNull(config1.accounts)
        assertEquals(1, config1.accounts?.size) // Should remain unchanged
    }

    @Test
    @DisplayName("Constructor with all parameters")
    fun testConstructorWithAllParameters() {
        // Given
        val remote = createTestRemote()
        val uses = LinkedBlockingQueue<String>()
        uses.add("use1")
        val includes = LinkedBlockingQueue<String>()
        includes.add("include1")
        val software = LinkedBlockingQueue<String>()
        software.add("software1")
        val containers = LinkedBlockingQueue<String>()
        containers.add("container1")
        val accounts = LinkedBlockingQueue<MailAccount>()
        accounts.add(MailAccount("test@example.com", "pass123", "email", null))

        // When
        val config = MailServerConfiguration(
            name = "TestConfig",
            remote = remote,
            uses = uses,
            includes = includes,
            software = software,
            containers = containers,
            overrides = null,
            enabled = true,
            deployment = null,
            accounts = accounts
        )

        // Then
        assertNotNull(config)
        assertEquals("TestConfig", config.name)
        assertNotNull(config.accounts)
        assertEquals(1, config.accounts?.size)
    }
}
