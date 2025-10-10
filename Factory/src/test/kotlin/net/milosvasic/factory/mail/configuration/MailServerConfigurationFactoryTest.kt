package net.milosvasic.factory.mail.configuration

import net.milosvasic.factory.mail.account.MailAccount
import net.milosvasic.factory.remote.Remote
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.DisplayName
import java.util.concurrent.LinkedBlockingQueue

@DisplayName("MailServerConfigurationFactory Tests")
class MailServerConfigurationFactoryTest {

    private lateinit var factory: MailServerConfigurationFactory

    private fun createTestRemote(): Remote {
        return Remote("localhost", "127.0.0.1", 22, "testuser")
    }

    @BeforeEach
    fun setUp() {
        factory = MailServerConfigurationFactory()
    }

    @Test
    @DisplayName("getType returns correct Type for MailServerConfiguration")
    fun testGetType() {
        // When
        val type = factory.getType()

        // Then
        assertNotNull(type)
        assertTrue(type.typeName.contains("MailServerConfiguration"))
    }

    @Test
    @DisplayName("onInstantiated initializes null accounts to empty queue")
    fun testOnInstantiatedWithNullAccounts() {
        // Given
        val remote = createTestRemote()
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

        // When
        factory.onInstantiated(config)

        // Then
        assertNotNull(config.accounts)
        assertTrue(config.accounts!!.isEmpty())
    }

    @Test
    @DisplayName("onInstantiated does not replace existing accounts")
    fun testOnInstantiatedWithExistingAccounts() {
        // Given
        val remote = createTestRemote()
        val accounts = LinkedBlockingQueue<MailAccount>()
        accounts.add(MailAccount("test@example.com", "StrongPass123!@#", "email", null))

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

        // When
        factory.onInstantiated(config)

        // Then
        assertNotNull(config.accounts)
        assertEquals(1, config.accounts!!.size)
    }

    @Test
    @DisplayName("validateConfiguration returns true for valid accounts")
    fun testValidateConfigurationWithValidAccounts() {
        // Given
        val remote = createTestRemote()
        val accounts = LinkedBlockingQueue<MailAccount>()
        accounts.add(MailAccount("user1@example.com", "StrongPass123!@#", "email", null))
        accounts.add(MailAccount("user2@example.com", "StrongPass456$%^", "postmaster", null))

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

        // When
        val result = factory.validateConfiguration(config)

        // Then
        assertTrue(result)
    }

    @Test
    @DisplayName("validateConfiguration returns false for invalid email")
    fun testValidateConfigurationWithInvalidEmail() {
        // Given
        val remote = createTestRemote()
        val accounts = LinkedBlockingQueue<MailAccount>()
        accounts.add(MailAccount("invalid-email", "StrongPass123!@#", "email", null))

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

        // When
        val result = factory.validateConfiguration(config)

        // Then
        assertFalse(result)
    }

    @Test
    @DisplayName("validateConfiguration returns false for weak password")
    fun testValidateConfigurationWithWeakPassword() {
        // Given
        val remote = createTestRemote()
        val accounts = LinkedBlockingQueue<MailAccount>()
        accounts.add(MailAccount("user@example.com", "weak", "email", null))

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

        // When
        val result = factory.validateConfiguration(config)

        // Then
        assertFalse(result)
    }

    @Test
    @DisplayName("validateConfiguration returns true for null accounts")
    fun testValidateConfigurationWithNullAccounts() {
        // Given
        val remote = createTestRemote()
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

        // When
        val result = factory.validateConfiguration(config)

        // Then
        assertTrue(result)
    }

    @Test
    @DisplayName("validateConfiguration returns true for empty accounts")
    fun testValidateConfigurationWithEmptyAccounts() {
        // Given
        val remote = createTestRemote()
        val accounts = LinkedBlockingQueue<MailAccount>()

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

        // When
        val result = factory.validateConfiguration(config)

        // Then
        assertTrue(result)
    }
}
