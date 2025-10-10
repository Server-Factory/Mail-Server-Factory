package net.milosvasic.factory.mail.account

import net.milosvasic.factory.account.AccountType
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.DisplayName

@DisplayName("MailAccount Tests")
class MailAccountTest {

    @Test
    @DisplayName("Constructor creates MailAccount with valid parameters")
    fun testConstructor() {
        // Given
        val name = "testuser@example.com"
        val credentials = "password123"
        val type = "email"
        val aliases = mutableListOf("alias1@example.com", "alias2@example.com")

        // When
        val mailAccount = MailAccount(name, credentials, type, aliases)

        // Then
        assertNotNull(mailAccount)
        assertEquals(name, mailAccount.name)
        assertEquals(AccountType.EMAIL, mailAccount.getAccountType())
    }

    @Test
    @DisplayName("Constructor creates MailAccount with null aliases")
    fun testConstructorWithNullAliases() {
        // Given
        val name = "testuser@example.com"
        val credentials = "password123"
        val type = "email"

        // When
        val mailAccount = MailAccount(name, credentials, type, null)

        // Then
        assertNotNull(mailAccount)
        assertEquals(name, mailAccount.name)
        assertTrue(mailAccount.getAliases().isEmpty())
    }

    @Test
    @DisplayName("getAliases returns empty list when aliases is null")
    fun testGetAliasesWithNull() {
        // Given
        val mailAccount = MailAccount("test@example.com", "pass123", "email", null)

        // When
        val aliases = mailAccount.getAliases()

        // Then
        assertNotNull(aliases)
        assertTrue(aliases.isEmpty())
    }

    @Test
    @DisplayName("getAliases returns correct aliases list")
    fun testGetAliasesWithValues() {
        // Given
        val expectedAliases = mutableListOf("alias1@example.com", "alias2@example.com", "alias3@example.com")
        val mailAccount = MailAccount("test@example.com", "pass123", "email", expectedAliases)

        // When
        val aliases = mailAccount.getAliases()

        // Then
        assertNotNull(aliases)
        assertEquals(3, aliases.size)
        assertEquals(expectedAliases, aliases)
    }

    @Test
    @DisplayName("print method returns correct format without aliases")
    fun testPrintWithoutAliases() {
        // Given
        val name = "testuser@example.com"
        val password = "password123"
        val mailAccount = MailAccount(name, password, "email", null)

        // When
        val result = mailAccount.print()

        // Then
        assertTrue(result.contains(name))
        assertTrue(result.contains(password))
        assertFalse(result.contains("aliases"))
    }

    @Test
    @DisplayName("print method returns correct format with single alias")
    fun testPrintWithSingleAlias() {
        // Given
        val name = "testuser@example.com"
        val password = "password123"
        val aliases = mutableListOf("alias1@example.com")
        val mailAccount = MailAccount(name, password, "email", aliases)

        // When
        val result = mailAccount.print()

        // Then
        assertTrue(result.contains(name))
        assertTrue(result.contains(password))
        assertTrue(result.contains("aliases"))
        assertTrue(result.contains("alias1@example.com"))
    }

    @Test
    @DisplayName("print method returns correct format with multiple aliases")
    fun testPrintWithMultipleAliases() {
        // Given
        val name = "testuser@example.com"
        val password = "password123"
        val aliases = mutableListOf("alias1@example.com", "alias2@example.com", "alias3@example.com")
        val mailAccount = MailAccount(name, password, "email", aliases)

        // When
        val result = mailAccount.print()

        // Then
        assertTrue(result.contains(name))
        assertTrue(result.contains(password))
        assertTrue(result.contains("aliases"))
        assertTrue(result.contains("alias1@example.com"))
        assertTrue(result.contains("alias2@example.com"))
        assertTrue(result.contains("alias3@example.com"))
        assertTrue(result.contains("["))
        assertTrue(result.contains("]"))
    }

    @Test
    @DisplayName("getCredentials returns Password object")
    fun testGetCredentials() {
        // Given
        val password = "password123"
        val mailAccount = MailAccount("test@example.com", password, "email", null)

        // When
        val credentials = mailAccount.getCredentials()

        // Then
        assertNotNull(credentials)
        assertEquals(password, credentials.value)
    }

    @Test
    @DisplayName("toString returns correct format")
    fun testToString() {
        // Given
        val name = "testuser@example.com"
        val password = "password123"
        val type = "email"
        val aliases = mutableListOf("alias1@example.com")
        val mailAccount = MailAccount(name, password, type, aliases)

        // When
        val result = mailAccount.toString()

        // Then
        assertTrue(result.startsWith("MailAccount("))
        assertTrue(result.contains(name))
        assertTrue(result.contains("aliases="))
    }

    @Test
    @DisplayName("toString with null aliases")
    fun testToStringWithNullAliases() {
        // Given
        val name = "testuser@example.com"
        val mailAccount = MailAccount(name, "pass123", "email", null)

        // When
        val result = mailAccount.toString()

        // Then
        assertTrue(result.startsWith("MailAccount("))
        assertTrue(result.contains(name))
    }

    @Test
    @DisplayName("MailAccount with empty aliases list")
    fun testWithEmptyAliasesList() {
        // Given
        val emptyAliases = mutableListOf<String>()
        val mailAccount = MailAccount("test@example.com", "pass123", "email", emptyAliases)

        // When
        val aliases = mailAccount.getAliases()
        val printResult = mailAccount.print()

        // Then
        assertTrue(aliases.isEmpty())
        assertFalse(printResult.contains("aliases"))
    }

    @Test
    @DisplayName("MailAccount with postmaster account type")
    fun testPostmasterAccountType() {
        // Given
        val mailAccount = MailAccount("postmaster@example.com", "pass123", "postmaster", null)

        // When
        val accountType = mailAccount.getAccountType()

        // Then
        assertEquals(AccountType.POSTMASTER, accountType)
    }

    @Test
    @DisplayName("MailAccount with email account type")
    fun testEmailAccountType() {
        // Given
        val mailAccount = MailAccount("user@example.com", "pass123", "email", null)

        // When
        val accountType = mailAccount.getAccountType()

        // Then
        assertEquals(AccountType.EMAIL, accountType)
    }
}
