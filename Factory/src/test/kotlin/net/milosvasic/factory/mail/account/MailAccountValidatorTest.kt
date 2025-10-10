package net.milosvasic.factory.mail.account

import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.DisplayName

@DisplayName("MailAccountValidator Tests")
class MailAccountValidatorTest {

    private lateinit var validator: MailAccountValidator

    @BeforeEach
    fun setUp() {
        validator = MailAccountValidator()
    }

    @Test
    @DisplayName("validate with valid email and strong password returns true")
    fun testValidateWithValidEmailAndStrongPassword() {
        // Given
        val account = MailAccount(
            "testuser@example.com",
            "StrongPass123!@#", // Strong password
            "email",
            null
        )

        // When & Then
        assertTrue(validator.validate(account))
    }

    @Test
    @DisplayName("validate with valid email and aliases returns true")
    fun testValidateWithValidEmailAndAliases() {
        // Given
        val aliases = mutableListOf("alias1@example.com", "alias2@example.com")
        val account = MailAccount(
            "testuser@example.com",
            "StrongPass123!@#",
            "email",
            aliases
        )

        // When & Then
        assertTrue(validator.validate(account))
    }

    @Test
    @DisplayName("validate with invalid email format throws IllegalArgumentException")
    fun testValidateWithInvalidEmail() {
        // Given
        val account = MailAccount(
            "invalid-email",
            "StrongPass123!@#",
            "email",
            null
        )

        // When & Then
        assertThrows(IllegalArgumentException::class.java) {
            validator.validate(account)
        }
    }

    @Test
    @DisplayName("validate with weak password throws IllegalArgumentException")
    fun testValidateWithWeakPassword() {
        // Given
        val account = MailAccount(
            "testuser@example.com",
            "weak", // Weak password
            "email",
            null
        )

        // When & Then
        val exception = assertThrows(IllegalArgumentException::class.java) {
            validator.validate(account)
        }
        assertTrue(exception.message!!.contains("credentials"))
        assertTrue(exception.message!!.contains("too weak"))
    }

    @Test
    @DisplayName("validate with invalid alias throws IllegalArgumentException")
    fun testValidateWithInvalidAlias() {
        // Given
        val aliases = mutableListOf("invalid-alias")
        val account = MailAccount(
            "testuser@example.com",
            "StrongPass123!@#",
            "email",
            aliases
        )

        // When & Then
        assertThrows(IllegalArgumentException::class.java) {
            validator.validate(account)
        }
    }

    @Test
    @DisplayName("validate with valid postmaster account")
    fun testValidateWithPostmasterAccount() {
        // Given
        val account = MailAccount(
            "postmaster@example.com",
            "StrongPass123!@#",
            "postmaster",
            null
        )

        // When & Then
        assertTrue(validator.validate(account))
    }

    @Test
    @DisplayName("validate with no arguments throws ArrayIndexOutOfBoundsException")
    fun testValidateWithNoArguments() {
        // When & Then - The validator accesses what[0] before checking, so it throws ArrayIndexOutOfBoundsException
        assertThrows(ArrayIndexOutOfBoundsException::class.java) {
            validator.validate()
        }
    }
}
