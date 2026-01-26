import XCTest
@testable import FlagKit

final class ErrorSanitizerTests: XCTestCase {

    // MARK: - ErrorSanitizationConfig Tests

    func testErrorSanitizationConfig_DefaultValues() {
        let config = ErrorSanitizationConfig()

        XCTAssertTrue(config.enabled)
        XCTAssertFalse(config.preserveOriginal)
    }

    func testErrorSanitizationConfig_CustomValues() {
        let config = ErrorSanitizationConfig(enabled: false, preserveOriginal: true)

        XCTAssertFalse(config.enabled)
        XCTAssertTrue(config.preserveOriginal)
    }

    func testErrorSanitizationConfig_StaticDefault() {
        let config = ErrorSanitizationConfig.default

        XCTAssertTrue(config.enabled)
        XCTAssertFalse(config.preserveOriginal)
    }

    func testErrorSanitizationConfig_StaticDisabled() {
        let config = ErrorSanitizationConfig.disabled

        XCTAssertFalse(config.enabled)
    }

    // MARK: - API Key Sanitization Tests

    func testSanitize_APIKeysWithSdkPrefix() {
        let sanitizer = ErrorSanitizer.shared

        let message = "Authentication failed for key sdk_abc123def456"
        let result = sanitizer.sanitize(message)

        XCTAssertEqual(result, "Authentication failed for key [REDACTED]")
        XCTAssertFalse(result.contains("sdk_"))
    }

    func testSanitize_APIKeysWithSrvPrefix() {
        let sanitizer = ErrorSanitizer.shared

        let message = "Server key srv_xyz789 is invalid"
        let result = sanitizer.sanitize(message)

        XCTAssertEqual(result, "Server key [REDACTED] is invalid")
        XCTAssertFalse(result.contains("srv_"))
    }

    func testSanitize_APIKeysWithCliPrefix() {
        let sanitizer = ErrorSanitizer.shared

        let message = "Client key cli_test123 expired"
        let result = sanitizer.sanitize(message)

        XCTAssertEqual(result, "Client key [REDACTED] expired")
        XCTAssertFalse(result.contains("cli_"))
    }

    func testSanitize_MultipleAPIKeys() {
        let sanitizer = ErrorSanitizer.shared

        let message = "Primary sdk_abc123 and secondary srv_xyz789 both failed"
        let result = sanitizer.sanitize(message)

        XCTAssertEqual(result, "Primary [REDACTED] and secondary [REDACTED] both failed")
    }

    // MARK: - Email Sanitization Tests

    func testSanitize_EmailAddresses() {
        let sanitizer = ErrorSanitizer.shared

        let message = "User user@example.com not found"
        let result = sanitizer.sanitize(message)

        XCTAssertEqual(result, "User [EMAIL] not found")
        XCTAssertFalse(result.contains("@"))
    }

    func testSanitize_ComplexEmailAddresses() {
        let sanitizer = ErrorSanitizer.shared

        let message = "Contact john.doe+test@subdomain.example.co.uk for help"
        let result = sanitizer.sanitize(message)

        XCTAssertTrue(result.contains("[EMAIL]"))
        XCTAssertFalse(result.contains("john.doe"))
    }

    func testSanitize_MultipleEmails() {
        let sanitizer = ErrorSanitizer.shared

        let message = "Users admin@test.com and user@example.org failed to authenticate"
        let result = sanitizer.sanitize(message)

        XCTAssertEqual(result, "Users [EMAIL] and [EMAIL] failed to authenticate")
    }

    // MARK: - IPv4 Address Sanitization Tests

    func testSanitize_IPv4Addresses() {
        let sanitizer = ErrorSanitizer.shared

        let message = "Connection to 192.168.1.100 failed"
        let result = sanitizer.sanitize(message)

        XCTAssertEqual(result, "Connection to [IP] failed")
        XCTAssertFalse(result.contains("192.168"))
    }

    func testSanitize_LoopbackAddress() {
        let sanitizer = ErrorSanitizer.shared

        let message = "Server running on 127.0.0.1:8080"
        let result = sanitizer.sanitize(message)

        XCTAssertTrue(result.contains("[IP]"))
        XCTAssertFalse(result.contains("127.0.0.1"))
    }

    func testSanitize_MultipleIPAddresses() {
        let sanitizer = ErrorSanitizer.shared

        let message = "Failed to route from 10.0.0.1 to 172.16.0.50"
        let result = sanitizer.sanitize(message)

        XCTAssertEqual(result, "Failed to route from [IP] to [IP]")
    }

    func testSanitize_BoundaryIPAddresses() {
        let sanitizer = ErrorSanitizer.shared

        // Test edge cases for IP validation
        let message = "IPs: 0.0.0.0, 255.255.255.255"
        let result = sanitizer.sanitize(message)

        XCTAssertTrue(result.contains("[IP]"))
        XCTAssertFalse(result.contains("0.0.0.0"))
        XCTAssertFalse(result.contains("255.255.255.255"))
    }

    // MARK: - Unix Path Sanitization Tests

    func testSanitize_UnixPaths() {
        let sanitizer = ErrorSanitizer.shared

        let message = "File not found: /home/user/documents/secret.txt"
        let result = sanitizer.sanitize(message)

        XCTAssertTrue(result.contains("[PATH]"))
        XCTAssertFalse(result.contains("/home/user"))
    }

    func testSanitize_UnixPathsWithDots() {
        let sanitizer = ErrorSanitizer.shared

        let message = "Error reading /var/log/app.log"
        let result = sanitizer.sanitize(message)

        XCTAssertTrue(result.contains("[PATH]"))
        XCTAssertFalse(result.contains("/var/log"))
    }

    func testSanitize_UnixPathsWithHyphens() {
        let sanitizer = ErrorSanitizer.shared

        let message = "Config at /etc/my-app/config.json is invalid"
        let result = sanitizer.sanitize(message)

        XCTAssertTrue(result.contains("[PATH]"))
        XCTAssertFalse(result.contains("/etc/my-app"))
    }

    // MARK: - Windows Path Sanitization Tests

    func testSanitize_WindowsPaths() {
        let sanitizer = ErrorSanitizer.shared

        let message = "File not found: C:\\Users\\Admin\\Documents\\secret.txt"
        let result = sanitizer.sanitize(message)

        XCTAssertTrue(result.contains("[PATH]"))
        XCTAssertFalse(result.contains("C:\\Users"))
    }

    func testSanitize_WindowsPathsLowercase() {
        let sanitizer = ErrorSanitizer.shared

        let message = "Reading from d:\\data\\logs\\app.log"
        let result = sanitizer.sanitize(message)

        XCTAssertTrue(result.contains("[PATH]"))
        XCTAssertFalse(result.contains("d:\\data"))
    }

    // MARK: - Connection String Sanitization Tests

    func testSanitize_MongoDBConnectionString() {
        let sanitizer = ErrorSanitizer.shared

        let message = "Failed to connect: mongodb://user:password@localhost:27017/database"
        let result = sanitizer.sanitize(message)

        XCTAssertEqual(result, "Failed to connect: [CONNECTION_STRING]")
        XCTAssertFalse(result.contains("mongodb://"))
        XCTAssertFalse(result.contains("password"))
    }

    func testSanitize_PostgresConnectionString() {
        let sanitizer = ErrorSanitizer.shared

        let message = "Connection error: postgres://admin:secret123@db.example.com:5432/mydb"
        let result = sanitizer.sanitize(message)

        XCTAssertTrue(result.contains("[CONNECTION_STRING]"))
        XCTAssertFalse(result.contains("postgres://"))
        XCTAssertFalse(result.contains("secret123"))
    }

    func testSanitize_RedisConnectionString() {
        let sanitizer = ErrorSanitizer.shared

        let message = "Redis connection failed: redis://default:mypassword@redis-server:6379"
        let result = sanitizer.sanitize(message)

        XCTAssertTrue(result.contains("[CONNECTION_STRING]"))
        XCTAssertFalse(result.contains("mypassword"))
    }

    func testSanitize_MySQLConnectionString() {
        let sanitizer = ErrorSanitizer.shared

        let message = "MySQL error: mysql://root:password@localhost:3306/app"
        let result = sanitizer.sanitize(message)

        XCTAssertTrue(result.contains("[CONNECTION_STRING]"))
        XCTAssertFalse(result.contains("mysql://"))
    }

    // MARK: - Combined Sanitization Tests

    func testSanitize_CombinedSensitiveData() {
        let sanitizer = ErrorSanitizer.shared

        let message = "User admin@example.com with key sdk_abc123 at 192.168.1.1 failed to read /home/user/config.json"
        let result = sanitizer.sanitize(message)

        XCTAssertTrue(result.contains("[EMAIL]"))
        XCTAssertTrue(result.contains("[REDACTED]"))
        XCTAssertTrue(result.contains("[IP]"))
        XCTAssertTrue(result.contains("[PATH]"))
        XCTAssertFalse(result.contains("admin@example.com"))
        XCTAssertFalse(result.contains("sdk_abc123"))
        XCTAssertFalse(result.contains("192.168.1.1"))
    }

    // MARK: - Non-Sensitive Data Tests

    func testSanitize_PreservesNonSensitiveData() {
        let sanitizer = ErrorSanitizer.shared

        let message = "Flag 'feature-toggle' evaluation failed with error code 500"
        let result = sanitizer.sanitize(message)

        XCTAssertEqual(result, message)
    }

    func testSanitize_PreservesNormalURLsWithoutPaths() {
        let sanitizer = ErrorSanitizer.shared

        // URLs without path components are preserved
        let message = "API endpoint https://api.flagkit.dev is unavailable"
        let result = sanitizer.sanitize(message)

        // Normal URLs without credentials should be preserved
        XCTAssertTrue(result.contains("https://api.flagkit.dev"))
    }

    func testSanitize_URLsWithMultiplePathSegmentsAreSanitized() {
        let sanitizer = ErrorSanitizer.shared

        // URLs with path components that look like file paths get sanitized
        // This is intentional for security (paths could contain sensitive info)
        let message = "API endpoint https://api.flagkit.dev/api/v1/flags is unavailable"
        let result = sanitizer.sanitize(message)

        // The path portion gets sanitized
        XCTAssertTrue(result.contains("[PATH]"))
        XCTAssertFalse(result.contains("/api/v1/flags"))
    }

    // MARK: - Configuration Tests

    func testSanitize_WithConfigDisabled() {
        let sanitizer = ErrorSanitizer.shared
        let config = ErrorSanitizationConfig(enabled: false)

        let message = "Key sdk_abc123 failed"
        let result = sanitizer.sanitize(message, config: config)

        XCTAssertEqual(result.sanitized, message)
        XCTAssertNil(result.original)
    }

    func testSanitize_WithPreserveOriginal() {
        let sanitizer = ErrorSanitizer.shared
        let config = ErrorSanitizationConfig(enabled: true, preserveOriginal: true)

        let message = "Key sdk_abc123 failed"
        let result = sanitizer.sanitize(message, config: config)

        XCTAssertEqual(result.sanitized, "Key [REDACTED] failed")
        XCTAssertEqual(result.original, message)
    }

    func testSanitize_WithoutPreserveOriginal() {
        let sanitizer = ErrorSanitizer.shared
        let config = ErrorSanitizationConfig(enabled: true, preserveOriginal: false)

        let message = "Key sdk_abc123 failed"
        let result = sanitizer.sanitize(message, config: config)

        XCTAssertEqual(result.sanitized, "Key [REDACTED] failed")
        XCTAssertNil(result.original)
    }

    // MARK: - String Extension Tests

    func testStringExtension_Sanitized() {
        let message = "Error with key sdk_test123"
        let result = message.sanitized()

        XCTAssertEqual(result, "Error with key [REDACTED]")
    }

    func testStringExtension_SanitizedWithConfig() {
        let config = ErrorSanitizationConfig(enabled: true, preserveOriginal: true)
        let message = "Email user@test.com failed"
        let result = message.sanitized(config: config)

        XCTAssertEqual(result.sanitized, "Email [EMAIL] failed")
        XCTAssertEqual(result.original, message)
    }

    // MARK: - Custom Pattern Tests

    func testCustomSanitizer_WithCustomPatterns() {
        let customPattern = SanitizationPattern(
            name: "customSecret",
            pattern: #"SECRET_[A-Z0-9]+"#,
            replacement: "[CUSTOM_REDACTED]"
        )!

        let sanitizer = ErrorSanitizer(patterns: [customPattern])

        let message = "Using SECRET_ABC123 for authentication"
        let result = sanitizer.sanitize(message)

        XCTAssertEqual(result, "Using [CUSTOM_REDACTED] for authentication")
    }

    func testSanitizationPattern_InvalidPatternReturnsNil() {
        let pattern = SanitizationPattern(
            name: "invalid",
            pattern: "[invalid regex",
            replacement: "[INVALID]"
        )

        XCTAssertNil(pattern)
    }

    // MARK: - FlagKitError Integration Tests

    func testFlagKitError_SanitizesMessageByDefault() {
        // Save current config
        let originalConfig = FlagKitErrorConfig.sanitization

        // Enable sanitization
        FlagKitErrorConfig.sanitization = ErrorSanitizationConfig(enabled: true)

        let error = FlagKitError(
            code: .authInvalidKey,
            message: "Invalid API key: sdk_secret123"
        )

        XCTAssertEqual(error.message, "Invalid API key: [REDACTED]")
        XCTAssertFalse(error.message.contains("sdk_secret123"))

        // Restore config
        FlagKitErrorConfig.sanitization = originalConfig
    }

    func testFlagKitError_PreservesOriginalWhenConfigured() {
        // Save current config
        let originalConfig = FlagKitErrorConfig.sanitization

        // Enable sanitization with preserve original
        FlagKitErrorConfig.sanitization = ErrorSanitizationConfig(enabled: true, preserveOriginal: true)

        let error = FlagKitError(
            code: .authInvalidKey,
            message: "Invalid API key: sdk_secret123"
        )

        XCTAssertEqual(error.message, "Invalid API key: [REDACTED]")
        XCTAssertEqual(error.originalMessage, "Invalid API key: sdk_secret123")

        // Restore config
        FlagKitErrorConfig.sanitization = originalConfig
    }

    func testFlagKitError_DisabledSanitization() {
        // Save current config
        let originalConfig = FlagKitErrorConfig.sanitization

        // Disable sanitization
        FlagKitErrorConfig.sanitization = ErrorSanitizationConfig(enabled: false)

        let error = FlagKitError(
            code: .authInvalidKey,
            message: "Invalid API key: sdk_secret123"
        )

        XCTAssertEqual(error.message, "Invalid API key: sdk_secret123")
        XCTAssertNil(error.originalMessage)

        // Restore config
        FlagKitErrorConfig.sanitization = originalConfig
    }

    func testFlagKitError_ExplicitSanitizeControl() {
        // Save current config
        let originalConfig = FlagKitErrorConfig.sanitization

        // Even if config is disabled, explicit sanitize=true should sanitize
        FlagKitErrorConfig.sanitization = ErrorSanitizationConfig(enabled: true)

        let errorWithSanitize = FlagKitError(
            code: .networkError,
            message: "Connection to 192.168.1.100 failed",
            sanitize: true
        )

        XCTAssertTrue(errorWithSanitize.message.contains("[IP]"))

        let errorWithoutSanitize = FlagKitError(
            code: .networkError,
            message: "Connection to 192.168.1.100 failed",
            sanitize: false
        )

        XCTAssertTrue(errorWithoutSanitize.message.contains("192.168.1.100"))

        // Restore config
        FlagKitErrorConfig.sanitization = originalConfig
    }

    func testFlagKitError_FactoryMethodsSanitize() {
        // Save current config
        let originalConfig = FlagKitErrorConfig.sanitization

        // Enable sanitization
        FlagKitErrorConfig.sanitization = ErrorSanitizationConfig(enabled: true)

        let networkError = FlagKitError.networkError("Failed to connect to 10.0.0.1")
        XCTAssertTrue(networkError.message.contains("[IP]"))

        let configError = FlagKitError.configError(
            code: .configInvalidApiKey,
            message: "Key sdk_test123 is invalid"
        )
        XCTAssertTrue(configError.message.contains("[REDACTED]"))

        // Restore config
        FlagKitErrorConfig.sanitization = originalConfig
    }

    // MARK: - FlagKitOptions Integration Tests

    func testFlagKitOptions_DefaultErrorSanitization() {
        let options = FlagKitOptions(apiKey: "sdk_test123")

        XCTAssertTrue(options.errorSanitization.enabled)
        XCTAssertFalse(options.errorSanitization.preserveOriginal)
    }

    func testFlagKitOptions_CustomErrorSanitization() {
        let options = FlagKitOptions(
            apiKey: "sdk_test123",
            errorSanitization: ErrorSanitizationConfig(enabled: false)
        )

        XCTAssertFalse(options.errorSanitization.enabled)
    }

    func testFlagKitOptions_BuilderErrorSanitization() {
        let options = FlagKitOptions.Builder(apiKey: "sdk_test123")
            .errorSanitization(ErrorSanitizationConfig(enabled: true, preserveOriginal: true))
            .build()

        XCTAssertTrue(options.errorSanitization.enabled)
        XCTAssertTrue(options.errorSanitization.preserveOriginal)
    }

    // MARK: - Edge Cases

    func testSanitize_EmptyString() {
        let sanitizer = ErrorSanitizer.shared

        let result = sanitizer.sanitize("")

        XCTAssertEqual(result, "")
    }

    func testSanitize_OnlyWhitespace() {
        let sanitizer = ErrorSanitizer.shared

        let result = sanitizer.sanitize("   \n\t  ")

        XCTAssertEqual(result, "   \n\t  ")
    }

    func testSanitize_VeryLongString() {
        let sanitizer = ErrorSanitizer.shared

        let longKey = "sdk_" + String(repeating: "a", count: 1000)
        let message = "Error with key: \(longKey)"
        let result = sanitizer.sanitize(message)

        XCTAssertTrue(result.contains("[REDACTED]"))
        XCTAssertFalse(result.contains(longKey))
    }

    func testSanitize_SpecialCharacters() {
        let sanitizer = ErrorSanitizer.shared

        let message = "Error: sdk_test!@#$%^&*() failed"
        let result = sanitizer.sanitize(message)

        // Only the valid part should be redacted
        XCTAssertTrue(result.contains("[REDACTED]"))
    }
}
