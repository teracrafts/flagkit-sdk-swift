import XCTest
@testable import FlagKit

/// Mock logger for testing.
final class MockLogger: Logger, @unchecked Sendable {
    private let lock = NSLock()
    private var _debugMessages: [String] = []
    private var _infoMessages: [String] = []
    private var _warnMessages: [String] = []
    private var _errorMessages: [String] = []

    var debugMessages: [String] {
        lock.lock()
        defer { lock.unlock() }
        return _debugMessages
    }

    var infoMessages: [String] {
        lock.lock()
        defer { lock.unlock() }
        return _infoMessages
    }

    var warnMessages: [String] {
        lock.lock()
        defer { lock.unlock() }
        return _warnMessages
    }

    var errorMessages: [String] {
        lock.lock()
        defer { lock.unlock() }
        return _errorMessages
    }

    func debug(_ message: String, data: [String: Any]?) {
        lock.lock()
        _debugMessages.append(message)
        lock.unlock()
    }

    func info(_ message: String, data: [String: Any]?) {
        lock.lock()
        _infoMessages.append(message)
        lock.unlock()
    }

    func warn(_ message: String, data: [String: Any]?) {
        lock.lock()
        _warnMessages.append(message)
        lock.unlock()
    }

    func error(_ message: String, data: [String: Any]?) {
        lock.lock()
        _errorMessages.append(message)
        lock.unlock()
    }

    func reset() {
        lock.lock()
        _debugMessages.removeAll()
        _infoMessages.removeAll()
        _warnMessages.removeAll()
        _errorMessages.removeAll()
        lock.unlock()
    }
}

final class SecurityTests: XCTestCase {

    // MARK: - isPotentialPIIField Tests

    func testIsPotentialPIIField_DetectsEmailFields() {
        XCTAssertTrue(isPotentialPIIField("email"))
        XCTAssertTrue(isPotentialPIIField("userEmail"))
        XCTAssertTrue(isPotentialPIIField("EMAIL"))
        XCTAssertTrue(isPotentialPIIField("user_email"))
    }

    func testIsPotentialPIIField_DetectsPhoneFields() {
        XCTAssertTrue(isPotentialPIIField("phone"))
        XCTAssertTrue(isPotentialPIIField("phoneNumber"))
        XCTAssertTrue(isPotentialPIIField("mobile"))
        XCTAssertTrue(isPotentialPIIField("telephone"))
        XCTAssertTrue(isPotentialPIIField("PHONE_NUMBER"))
    }

    func testIsPotentialPIIField_DetectsSSNFields() {
        XCTAssertTrue(isPotentialPIIField("ssn"))
        XCTAssertTrue(isPotentialPIIField("socialSecurity"))
        XCTAssertTrue(isPotentialPIIField("social_security"))
        XCTAssertTrue(isPotentialPIIField("SSN"))
    }

    func testIsPotentialPIIField_DetectsCreditCardFields() {
        XCTAssertTrue(isPotentialPIIField("creditCard"))
        XCTAssertTrue(isPotentialPIIField("credit_card"))
        XCTAssertTrue(isPotentialPIIField("cardNumber"))
        XCTAssertTrue(isPotentialPIIField("cvv"))
        XCTAssertTrue(isPotentialPIIField("card_number"))
    }

    func testIsPotentialPIIField_DetectsAuthenticationFields() {
        XCTAssertTrue(isPotentialPIIField("password"))
        XCTAssertTrue(isPotentialPIIField("passwd"))
        XCTAssertTrue(isPotentialPIIField("secret"))
        XCTAssertTrue(isPotentialPIIField("apiKey"))
        XCTAssertTrue(isPotentialPIIField("api_key"))
        XCTAssertTrue(isPotentialPIIField("accessToken"))
        XCTAssertTrue(isPotentialPIIField("access_token"))
        XCTAssertTrue(isPotentialPIIField("refreshToken"))
        XCTAssertTrue(isPotentialPIIField("refresh_token"))
        XCTAssertTrue(isPotentialPIIField("authToken"))
        XCTAssertTrue(isPotentialPIIField("privateKey"))
        XCTAssertTrue(isPotentialPIIField("private_key"))
    }

    func testIsPotentialPIIField_DetectsAddressFields() {
        XCTAssertTrue(isPotentialPIIField("address"))
        XCTAssertTrue(isPotentialPIIField("street"))
        XCTAssertTrue(isPotentialPIIField("zipCode"))
        XCTAssertTrue(isPotentialPIIField("zip_code"))
        XCTAssertTrue(isPotentialPIIField("postalCode"))
        XCTAssertTrue(isPotentialPIIField("postal_code"))
    }

    func testIsPotentialPIIField_DetectsBirthDateFields() {
        XCTAssertTrue(isPotentialPIIField("dateOfBirth"))
        XCTAssertTrue(isPotentialPIIField("date_of_birth"))
        XCTAssertTrue(isPotentialPIIField("dob"))
        XCTAssertTrue(isPotentialPIIField("birthDate"))
        XCTAssertTrue(isPotentialPIIField("birth_date"))
    }

    func testIsPotentialPIIField_DetectsIdentificationFields() {
        XCTAssertTrue(isPotentialPIIField("passport"))
        XCTAssertTrue(isPotentialPIIField("driverLicense"))
        XCTAssertTrue(isPotentialPIIField("driver_license"))
        XCTAssertTrue(isPotentialPIIField("nationalId"))
        XCTAssertTrue(isPotentialPIIField("national_id"))
    }

    func testIsPotentialPIIField_DetectsBankingFields() {
        XCTAssertTrue(isPotentialPIIField("bankAccount"))
        XCTAssertTrue(isPotentialPIIField("bank_account"))
        XCTAssertTrue(isPotentialPIIField("routingNumber"))
        XCTAssertTrue(isPotentialPIIField("routing_number"))
        XCTAssertTrue(isPotentialPIIField("iban"))
        XCTAssertTrue(isPotentialPIIField("swift"))
    }

    func testIsPotentialPIIField_DoesNotFlagSafeFields() {
        XCTAssertFalse(isPotentialPIIField("userId"))
        XCTAssertFalse(isPotentialPIIField("plan"))
        XCTAssertFalse(isPotentialPIIField("country"))
        XCTAssertFalse(isPotentialPIIField("featureEnabled"))
        XCTAssertFalse(isPotentialPIIField("tier"))
        XCTAssertFalse(isPotentialPIIField("role"))
        XCTAssertFalse(isPotentialPIIField("platform"))
    }

    func testIsPotentialPIIField_WithAdditionalPatterns() {
        // Default patterns should work
        XCTAssertTrue(isPotentialPIIField("email", additionalPatterns: []))

        // Custom pattern should be detected
        XCTAssertTrue(isPotentialPIIField("customField", additionalPatterns: ["custom"]))
        XCTAssertTrue(isPotentialPIIField("myCustomField", additionalPatterns: ["custom"]))

        // Non-matching field should not be flagged
        XCTAssertFalse(isPotentialPIIField("userId", additionalPatterns: ["custom"]))
    }

    // MARK: - detectPotentialPII Tests

    func testDetectPotentialPII_DetectsPIIInFlatObjects() {
        let data: [String: Any] = [
            "userId": "user-123",
            "email": "user@example.com",
            "plan": "premium"
        ]

        let piiFields = detectPotentialPII(in: data)

        XCTAssertTrue(piiFields.contains("email"))
        XCTAssertFalse(piiFields.contains("userId"))
        XCTAssertFalse(piiFields.contains("plan"))
    }

    func testDetectPotentialPII_DetectsPIIInNestedObjects() {
        let data: [String: Any] = [
            "user": [
                "email": "user@example.com",
                "phone": "123-456-7890"
            ] as [String: Any],
            "settings": [
                "darkMode": true
            ] as [String: Any]
        ]

        let piiFields = detectPotentialPII(in: data)

        XCTAssertTrue(piiFields.contains("user.email"))
        XCTAssertTrue(piiFields.contains("user.phone"))
        XCTAssertFalse(piiFields.contains("settings.darkMode"))
    }

    func testDetectPotentialPII_HandlesDeeplyNestedObjects() {
        let data: [String: Any] = [
            "profile": [
                "contact": [
                    "primaryEmail": "user@example.com"
                ] as [String: Any]
            ] as [String: Any]
        ]

        let piiFields = detectPotentialPII(in: data)

        XCTAssertTrue(piiFields.contains("profile.contact.primaryEmail"))
    }

    func testDetectPotentialPII_ReturnsEmptyArrayForSafeData() {
        let data: [String: Any] = [
            "userId": "user-123",
            "plan": "premium",
            "features": ["dark-mode", "beta"]
        ]

        let piiFields = detectPotentialPII(in: data)

        XCTAssertTrue(piiFields.isEmpty)
    }

    func testDetectPotentialPII_WithPrefix() {
        let data: [String: Any] = [
            "email": "user@example.com"
        ]

        let piiFields = detectPotentialPII(in: data, prefix: "context")

        XCTAssertTrue(piiFields.contains("context.email"))
    }

    func testDetectPotentialPII_WithAdditionalPatterns() {
        let data: [String: Any] = [
            "customSecret": "sensitive-value",
            "userId": "user-123"
        ]

        let piiFields = detectPotentialPII(
            in: data,
            additionalPatterns: ["customSecret"]
        )

        XCTAssertTrue(piiFields.contains("customSecret"))
        XCTAssertFalse(piiFields.contains("userId"))
    }

    // MARK: - warnIfPotentialPII Tests

    func testWarnIfPotentialPII_LogsWarningWhenPIIDetected() {
        let mockLogger = MockLogger()
        let data: [String: Any] = [
            "email": "user@example.com",
            "phone": "123-456-7890"
        ]

        warnIfPotentialPII(in: data, dataType: .context, logger: mockLogger)

        XCTAssertEqual(mockLogger.warnMessages.count, 1)
        XCTAssertTrue(mockLogger.warnMessages[0].contains("Potential PII detected"))
        XCTAssertTrue(mockLogger.warnMessages[0].contains("email"))
    }

    func testWarnIfPotentialPII_DoesNotLogWhenNoPIIDetected() {
        let mockLogger = MockLogger()
        let data: [String: Any] = [
            "userId": "user-123",
            "plan": "premium"
        ]

        warnIfPotentialPII(in: data, dataType: .context, logger: mockLogger)

        XCTAssertTrue(mockLogger.warnMessages.isEmpty)
    }

    func testWarnIfPotentialPII_HandlesNilData() {
        let mockLogger = MockLogger()

        warnIfPotentialPII(in: nil, dataType: .event, logger: mockLogger)

        XCTAssertTrue(mockLogger.warnMessages.isEmpty)
    }

    func testWarnIfPotentialPII_HandlesNilLogger() {
        let data: [String: Any] = ["email": "test@example.com"]

        // Should not throw
        warnIfPotentialPII(in: data, dataType: .event, logger: nil)
    }

    func testWarnIfPotentialPII_ContextDataType() {
        let mockLogger = MockLogger()
        let data: [String: Any] = ["email": "user@example.com"]

        warnIfPotentialPII(in: data, dataType: .context, logger: mockLogger)

        XCTAssertEqual(mockLogger.warnMessages.count, 1)
        XCTAssertTrue(mockLogger.warnMessages[0].contains("context"))
        XCTAssertTrue(mockLogger.warnMessages[0].contains("privateAttributes"))
    }

    func testWarnIfPotentialPII_EventDataType() {
        let mockLogger = MockLogger()
        let data: [String: Any] = ["email": "user@example.com"]

        warnIfPotentialPII(in: data, dataType: .event, logger: mockLogger)

        XCTAssertEqual(mockLogger.warnMessages.count, 1)
        XCTAssertTrue(mockLogger.warnMessages[0].contains("event"))
        XCTAssertTrue(mockLogger.warnMessages[0].contains("removing sensitive data"))
    }

    // MARK: - isServerKey Tests

    func testIsServerKey_ReturnsTrueForServerKeys() {
        XCTAssertTrue(isServerKey("srv_abc123"))
        XCTAssertTrue(isServerKey("srv_"))
        XCTAssertTrue(isServerKey("srv_very_long_key_123"))
    }

    func testIsServerKey_ReturnsFalseForSDKKeys() {
        XCTAssertFalse(isServerKey("sdk_abc123"))
    }

    func testIsServerKey_ReturnsFalseForClientKeys() {
        XCTAssertFalse(isServerKey("cli_abc123"))
    }

    func testIsServerKey_ReturnsFalseForInvalidKeys() {
        XCTAssertFalse(isServerKey(""))
        XCTAssertFalse(isServerKey("invalid"))
        XCTAssertFalse(isServerKey("SRV_abc123")) // Case sensitive
    }

    // MARK: - isClientKey Tests

    func testIsClientKey_ReturnsTrueForSDKKeys() {
        XCTAssertTrue(isClientKey("sdk_abc123"))
        XCTAssertTrue(isClientKey("sdk_"))
    }

    func testIsClientKey_ReturnsTrueForCLIKeys() {
        XCTAssertTrue(isClientKey("cli_abc123"))
        XCTAssertTrue(isClientKey("cli_"))
    }

    func testIsClientKey_ReturnsFalseForServerKeys() {
        XCTAssertFalse(isClientKey("srv_abc123"))
    }

    func testIsClientKey_ReturnsFalseForInvalidKeys() {
        XCTAssertFalse(isClientKey(""))
        XCTAssertFalse(isClientKey("invalid"))
        XCTAssertFalse(isClientKey("SDK_abc123")) // Case sensitive
    }

    // MARK: - isClientEnvironment Tests

    func testIsClientEnvironment() {
        // This test's result depends on the platform
        #if os(iOS) || os(tvOS) || os(watchOS)
        XCTAssertTrue(isClientEnvironment())
        #elseif os(macOS)
        // On macOS, depends on whether running in sandbox
        // Just verify it returns a boolean without crashing
        _ = isClientEnvironment()
        #else
        XCTAssertFalse(isClientEnvironment())
        #endif
    }

    // MARK: - warnIfServerKeyInClient Tests

    func testWarnIfServerKeyInClient_WithClientKey() {
        let mockLogger = MockLogger()

        warnIfServerKeyInClient("sdk_abc123", logger: mockLogger)

        // Should not log a warning for client keys
        XCTAssertTrue(mockLogger.warnMessages.isEmpty)
    }

    func testWarnIfServerKeyInClient_WithNilLogger() {
        // Should not throw
        warnIfServerKeyInClient("srv_abc123", logger: nil)
    }

    // MARK: - SecurityConfig Tests

    func testSecurityConfig_DefaultValues() {
        let config = SecurityConfig()

        #if DEBUG
        XCTAssertTrue(config.warnOnPotentialPII)
        #else
        XCTAssertFalse(config.warnOnPotentialPII)
        #endif
        XCTAssertTrue(config.warnOnServerKeyInClient)
        XCTAssertTrue(config.additionalPIIPatterns.isEmpty)
    }

    func testSecurityConfig_CustomValues() {
        let config = SecurityConfig(
            warnOnPotentialPII: false,
            warnOnServerKeyInClient: false,
            additionalPIIPatterns: ["custom", "pattern"]
        )

        XCTAssertFalse(config.warnOnPotentialPII)
        XCTAssertFalse(config.warnOnServerKeyInClient)
        XCTAssertEqual(config.additionalPIIPatterns, ["custom", "pattern"])
    }

    func testSecurityConfig_StaticDefault() {
        let config = SecurityConfig.default

        XCTAssertTrue(config.warnOnServerKeyInClient)
        XCTAssertTrue(config.additionalPIIPatterns.isEmpty)
    }

    // MARK: - String Extension Tests

    func testStringExtension_IsPotentialPIIField() {
        XCTAssertTrue("email".isPotentialPIIField)
        XCTAssertTrue("userEmail".isPotentialPIIField)
        XCTAssertFalse("userId".isPotentialPIIField)
        XCTAssertFalse("plan".isPotentialPIIField)
    }

    // MARK: - Logger Protocol Tests

    func testMockLoggerProtocol() {
        let logger = MockLogger()

        logger.debug("debug message")
        logger.info("info message")
        logger.warn("warn message")
        logger.error("error message")

        XCTAssertEqual(logger.debugMessages.count, 1)
        XCTAssertEqual(logger.infoMessages.count, 1)
        XCTAssertEqual(logger.warnMessages.count, 1)
        XCTAssertEqual(logger.errorMessages.count, 1)

        XCTAssertEqual(logger.debugMessages[0], "debug message")
        XCTAssertEqual(logger.infoMessages[0], "info message")
        XCTAssertEqual(logger.warnMessages[0], "warn message")
        XCTAssertEqual(logger.errorMessages[0], "error message")
    }

    func testMockLoggerReset() {
        let logger = MockLogger()

        logger.warn("test")
        XCTAssertEqual(logger.warnMessages.count, 1)

        logger.reset()
        XCTAssertTrue(logger.warnMessages.isEmpty)
    }
}
