package net.milosvasic.factory.mail.tools

import net.milosvasic.factory.security.Encryption
import net.milosvasic.factory.security.EncryptionException
import java.io.Console
import kotlin.system.exitProcess

/**
 * Command-line tool for encrypting passwords for use in Mail Server Factory configurations.
 *
 * This tool helps users encrypt sensitive passwords before storing them in JSON configuration files.
 *
 * Usage:
 * ```bash
 * # Interactive mode (prompts for master key and password)
 * java -jar Application.jar encrypt-password
 *
 * # With master key from environment
 * export MAIL_FACTORY_MASTER_KEY="your-strong-master-key"
 * java -jar Application.jar encrypt-password
 *
 * # Decrypt a password (for verification)
 * java -jar Application.jar decrypt-password "encrypted:salt:iv:ciphertext"
 * ```
 *
 * Output format: "encrypted:salt:iv:ciphertext"
 * This can be directly used in JSON configuration files.
 *
 * @author Mail Server Factory Team
 * @since 3.1.0
 */
object PasswordEncryptor {

    private const val ENV_MASTER_KEY = "MAIL_FACTORY_MASTER_KEY"
    private const val MIN_MASTER_KEY_LENGTH = 16

    /**
     * Main entry point for the password encryption tool.
     *
     * @param args Command-line arguments
     */
    @JvmStatic
    fun main(args: Array<String>) {
        if (args.isEmpty()) {
            showHelp()
            exitProcess(0)
        }

        when (args[0].lowercase()) {
            "encrypt", "encrypt-password" -> encryptPassword(args)
            "decrypt", "decrypt-password" -> decryptPassword(args)
            "help", "--help", "-h" -> showHelp()
            else -> {
                println("Unknown command: ${args[0]}")
                showHelp()
                exitProcess(1)
            }
        }
    }

    /**
     * Encrypts a password interactively or from command-line arguments.
     */
    private fun encryptPassword(args: Array<String>) {
        try {
            // Get master key
            val masterKey = getMasterKey(args)

            // Get password to encrypt
            val password = getPassword(args)

            // Encrypt
            val encrypted = Encryption.encrypt(password, masterKey)

            // Output result
            println()
            println("=".repeat(70))
            println("ENCRYPTED PASSWORD (use this in your JSON configuration)")
            println("=".repeat(70))
            println()
            println("encrypted:$encrypted")
            println()
            println("=".repeat(70))
            println()
            println("Example usage in JSON:")
            println("""
                {
                  "credentials": {
                    "password": "encrypted:$encrypted"
                  }
                }
            """.trimIndent())
            println()
            println("IMPORTANT: Keep your master key secure!")
            println("Set environment variable: export $ENV_MASTER_KEY='your-master-key'")
            println()

        } catch (e: EncryptionException) {
            System.err.println("Encryption failed: ${e.message}")
            exitProcess(1)
        } catch (e: Exception) {
            System.err.println("Error: ${e.message}")
            exitProcess(1)
        }
    }

    /**
     * Decrypts a password for verification.
     */
    private fun decryptPassword(args: Array<String>) {
        try {
            // Get master key
            val masterKey = getMasterKey(args)

            // Get encrypted password
            val encryptedPassword = if (args.size > 1) {
                args[1]
            } else {
                print("Enter encrypted password: ")
                readLine() ?: throw IllegalArgumentException("No encrypted password provided")
            }

            // Remove "encrypted:" prefix if present
            val encrypted = encryptedPassword.removePrefix("encrypted:")

            // Decrypt
            val decrypted = Encryption.decrypt(encrypted, masterKey)

            // Output result
            println()
            println("=".repeat(70))
            println("DECRYPTED PASSWORD")
            println("=".repeat(70))
            println()
            println(decrypted)
            println()
            println("=".repeat(70))
            println()

        } catch (e: Exception) {
            System.err.println("Decryption failed: ${e.message}")
            exitProcess(1)
        }
    }

    /**
     * Gets the master encryption key from environment or prompts user.
     */
    private fun getMasterKey(args: Array<String>): String {
        // Check environment variable first
        val envKey = System.getenv(ENV_MASTER_KEY)
        if (!envKey.isNullOrEmpty()) {
            if (envKey.length < MIN_MASTER_KEY_LENGTH) {
                throw IllegalArgumentException(
                    "Master key from environment is too short (minimum $MIN_MASTER_KEY_LENGTH characters)"
                )
            }
            return envKey
        }

        // Check command-line argument
        val keyArgIndex = args.indexOfFirst { it == "--master-key" || it == "-k" }
        if (keyArgIndex != -1 && keyArgIndex + 1 < args.size) {
            val key = args[keyArgIndex + 1]
            if (key.length < MIN_MASTER_KEY_LENGTH) {
                throw IllegalArgumentException(
                    "Master key is too short (minimum $MIN_MASTER_KEY_LENGTH characters)"
                )
            }
            return key
        }

        // Prompt user
        val console = System.console()
        if (console == null) {
            throw IllegalStateException(
                "No console available for password input. Set $ENV_MASTER_KEY environment variable or use --master-key option."
            )
        }

        println()
        println("Master Encryption Key")
        println("=" .repeat(70))
        println("This key will be used to encrypt/decrypt passwords.")
        println("Use a strong, random key (minimum $MIN_MASTER_KEY_LENGTH characters).")
        println("You must remember this key or store it securely!")
        println("=" .repeat(70))
        println()

        val masterKey = String(console.readPassword("Enter master key: "))
        if (masterKey.length < MIN_MASTER_KEY_LENGTH) {
            throw IllegalArgumentException(
                "Master key is too short (minimum $MIN_MASTER_KEY_LENGTH characters)"
            )
        }

        val confirmKey = String(console.readPassword("Confirm master key: "))
        if (masterKey != confirmKey) {
            throw IllegalArgumentException("Master keys do not match")
        }

        return masterKey
    }

    /**
     * Gets the password to encrypt from command-line or prompts user.
     */
    private fun getPassword(args: Array<String>): String {
        // Check command-line argument
        val passwordArgIndex = args.indexOfFirst { it == "--password" || it == "-p" }
        if (passwordArgIndex != -1 && passwordArgIndex + 1 < args.size) {
            return args[passwordArgIndex + 1]
        }

        // Prompt user
        val console = System.console()
        if (console == null) {
            throw IllegalStateException(
                "No console available for password input. Use --password option."
            )
        }

        println()
        println("Password to Encrypt")
        println("=".repeat(70))
        println()

        val password = String(console.readPassword("Enter password to encrypt: "))
        if (password.isEmpty()) {
            throw IllegalArgumentException("Password cannot be empty")
        }

        val confirmPassword = String(console.readPassword("Confirm password: "))
        if (password != confirmPassword) {
            throw IllegalArgumentException("Passwords do not match")
        }

        return password
    }

    /**
     * Shows help information.
     */
    private fun showHelp() {
        println("""

            Password Encryption Tool for Mail Server Factory
            =================================================

            This tool encrypts passwords for use in JSON configuration files.

            USAGE:
                java -jar Application.jar encrypt-password [OPTIONS]
                java -jar Application.jar decrypt-password [OPTIONS] <encrypted-password>

            COMMANDS:
                encrypt-password    Encrypt a password
                decrypt-password    Decrypt a password (for verification)
                help               Show this help message

            OPTIONS:
                --master-key, -k <key>     Master encryption key
                --password, -p <password>  Password to encrypt (not recommended for security)
                --help, -h                 Show this help message

            EXAMPLES:
                # Interactive mode (recommended - prompts for all inputs)
                java -jar Application.jar encrypt-password

                # With master key from environment
                export MAIL_FACTORY_MASTER_KEY="your-strong-master-key"
                java -jar Application.jar encrypt-password

                # Decrypt a password
                export MAIL_FACTORY_MASTER_KEY="your-master-key"
                java -jar Application.jar decrypt-password "encrypted:salt:iv:ciphertext"

            ENVIRONMENT VARIABLES:
                MAIL_FACTORY_MASTER_KEY    Master encryption key (recommended method)

            SECURITY BEST PRACTICES:
                1. Use a strong, random master key (minimum 16 characters)
                2. Store master key in environment variable, not in code
                3. Never commit the master key to version control
                4. Use interactive mode to avoid password in shell history
                5. Keep encrypted passwords in configuration files
                6. Set MAIL_FACTORY_MASTER_KEY in production environment

            OUTPUT FORMAT:
                encrypted:salt:iv:ciphertext

                Use this directly in your JSON configuration:
                {
                  "credentials": {
                    "password": "encrypted:salt:iv:ciphertext"
                  }
                }

        """.trimIndent())
    }
}
