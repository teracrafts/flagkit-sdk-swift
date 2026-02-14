import XCTest
import CryptoKit
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

// Test helper for Encodable dictionary wrapper
struct EncodableDictionary: Encodable, Sendable {
    let values: [String: String]

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        for (key, value) in values {
            try container.encode(value, forKey: CodingKeys(stringValue: key)!)
        }
    }

    struct CodingKeys: CodingKey {
        var stringValue: String
        var intValue: Int?

        init?(stringValue: String) { self.stringValue = stringValue; self.intValue = nil }
        init?(intValue: Int) { return nil }
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

    // MARK: - SecurityError Tests

    func testSecurityError_PIIDetectedStrictMode() {
        let error = SecurityError.piiDetectedStrictMode(fields: ["email", "phone"])
        XCTAssertTrue(error.errorDescription?.contains("email") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("phone") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("strict mode") ?? false)
    }

    func testSecurityError_EncryptionFailed() {
        let error = SecurityError.encryptionFailed("test reason")
        XCTAssertTrue(error.errorDescription?.contains("test reason") ?? false)
    }

    func testSecurityError_DecryptionFailed() {
        let error = SecurityError.decryptionFailed("test reason")
        XCTAssertTrue(error.errorDescription?.contains("test reason") ?? false)
    }

    func testSecurityError_KeyDerivationFailed() {
        let error = SecurityError.keyDerivationFailed
        XCTAssertTrue(error.errorDescription?.contains("Key derivation") ?? false)
    }

    // MARK: - HMAC-SHA256 Request Signing Tests

    func testGetKeyId_ReturnsFirst8Characters() {
        XCTAssertEqual(getKeyId("sdk_abc123def456"), "sdk_abc1")
        XCTAssertEqual(getKeyId("srv_xyz789"), "srv_xyz7")
    }

    func testGetKeyId_HandlesShortKeys() {
        XCTAssertEqual(getKeyId("sdk_"), "sdk_")
        XCTAssertEqual(getKeyId("ab"), "ab")
    }

    func testGenerateHMACSHA256_ProducesConsistentSignatures() {
        let message = "test message"
        let key = "secret-key"

        let sig1 = generateHMACSHA256(message: message, key: key)
        let sig2 = generateHMACSHA256(message: message, key: key)

        XCTAssertEqual(sig1, sig2)
        XCTAssertEqual(sig1.count, 64) // SHA256 = 64 hex chars
    }

    func testGenerateHMACSHA256_DifferentMessagesProduceDifferentSignatures() {
        let key = "secret-key"

        let sig1 = generateHMACSHA256(message: "message1", key: key)
        let sig2 = generateHMACSHA256(message: "message2", key: key)

        XCTAssertNotEqual(sig1, sig2)
    }

    func testGenerateHMACSHA256_DifferentKeysProduceDifferentSignatures() {
        let message = "test message"

        let sig1 = generateHMACSHA256(message: message, key: "key1")
        let sig2 = generateHMACSHA256(message: message, key: "key2")

        XCTAssertNotEqual(sig1, sig2)
    }

    func testCreateRequestSignature_CreatesValidSignature() {
        let body = "{\"test\":true}"
        let apiKey = "sdk_abc123def456"

        let result = createRequestSignature(body: body, apiKey: apiKey)

        XCTAssertEqual(result.signature.count, 64)
        XCTAssertGreaterThan(result.timestamp, 0)
        XCTAssertEqual(result.keyId, "sdk_abc1")
    }

    func testCreateRequestSignature_UsesProvidedTimestamp() {
        let body = "{\"test\":true}"
        let apiKey = "sdk_abc123"
        let timestamp: Int64 = 1700000000000

        let result = createRequestSignature(body: body, apiKey: apiKey, timestamp: timestamp)

        XCTAssertEqual(result.timestamp, timestamp)
    }

    func testSignPayload_CreatesValidSignedPayload() throws {
        let data: [String: Any] = ["event": "test", "value": 123]
        let apiKey = "sdk_abc123def456"

        let signed = try signPayload(data: data, apiKey: apiKey)

        XCTAssertEqual(signed.signature.count, 64)
        XCTAssertGreaterThan(signed.timestamp, 0)
        XCTAssertEqual(signed.keyId, "sdk_abc1")
    }

    func testSignPayload_UsesProvidedTimestamp() throws {
        let data: [String: Any] = ["test": true]
        let apiKey = "sdk_test"
        let timestamp: Int64 = 1700000000000

        let signed = try signPayload(data: data, apiKey: apiKey, timestamp: timestamp)

        XCTAssertEqual(signed.timestamp, timestamp)
    }

    func testVerifySignedPayload_VerifiesValidPayload() throws {
        let data: [String: Any] = ["event": "test", "value": 123]
        let apiKey = "sdk_abc123def456"

        let signed = try signPayload(data: data, apiKey: apiKey)
        let isValid = verifySignedPayload(signed, apiKey: apiKey)

        XCTAssertTrue(isValid)
    }

    func testVerifySignedPayload_RejectsWrongKey() throws {
        let data: [String: Any] = ["event": "test"]
        let apiKey = "sdk_abc123def456"

        let signed = try signPayload(data: data, apiKey: apiKey)
        let isValid = verifySignedPayload(signed, apiKey: "sdk_different_key")

        XCTAssertFalse(isValid)
    }

    func testVerifySignedPayload_RejectsExpiredPayload() throws {
        let data: [String: Any] = ["event": "test"]
        let apiKey = "sdk_abc123def456"
        let oldTimestamp = Int64(Date().timeIntervalSince1970 * 1000) - 600_000 // 10 min ago

        let signed = try signPayload(data: data, apiKey: apiKey, timestamp: oldTimestamp)
        let isValid = verifySignedPayload(signed, apiKey: apiKey, maxAgeMs: 300_000) // 5 min max

        XCTAssertFalse(isValid)
    }

    func testVerifySignedPayload_RejectsMismatchedKeyId() throws {
        let data: [String: Any] = ["event": "test"]
        let apiKey = "sdk_abc123def456"

        var signed = try signPayload(data: data, apiKey: apiKey)
        signed = SignedPayload(
            data: signed.data,
            signature: signed.signature,
            timestamp: signed.timestamp,
            keyId: "sdk_diff"
        )

        let isValid = verifySignedPayload(signed, apiKey: apiKey)

        XCTAssertFalse(isValid)
    }

    // MARK: - Strict PII Mode Tests

    func testCheckForPotentialPII_ReturnsPIIDetectionResult() {
        let data: [String: Any] = [
            "email": "user@example.com",
            "phone": "123-456-7890",
            "userId": "user-123"
        ]

        let result = checkForPotentialPII(in: data, dataType: .context)

        XCTAssertTrue(result.hasPII)
        XCTAssertTrue(result.fields.contains("email"))
        XCTAssertTrue(result.fields.contains("phone"))
        XCTAssertFalse(result.fields.contains("userId"))
        XCTAssertTrue(result.message.contains("Potential PII detected"))
    }

    func testCheckForPotentialPII_ReturnsEmptyForNoPII() {
        let data: [String: Any] = [
            "userId": "user-123",
            "plan": "premium"
        ]

        let result = checkForPotentialPII(in: data, dataType: .event)

        XCTAssertFalse(result.hasPII)
        XCTAssertTrue(result.fields.isEmpty)
        XCTAssertTrue(result.message.isEmpty)
    }

    func testCheckForPotentialPII_HandlesNilData() {
        let result = checkForPotentialPII(in: nil, dataType: .context)

        XCTAssertFalse(result.hasPII)
        XCTAssertTrue(result.fields.isEmpty)
    }

    func testValidatePII_ThrowsInStrictMode() {
        let data: [String: Any] = ["email": "test@example.com"]

        XCTAssertThrowsError(try validatePII(
            in: data,
            dataType: .context,
            strictMode: true
        )) { error in
            guard case SecurityError.piiDetectedStrictMode(let fields) = error else {
                XCTFail("Expected SecurityError.piiDetectedStrictMode")
                return
            }
            XCTAssertTrue(fields.contains("email"))
        }
    }

    func testValidatePII_WarnsInNonStrictMode() {
        let mockLogger = MockLogger()
        let data: [String: Any] = ["email": "test@example.com"]

        XCTAssertNoThrow(try validatePII(
            in: data,
            dataType: .context,
            strictMode: false,
            logger: mockLogger
        ))

        XCTAssertEqual(mockLogger.warnMessages.count, 1)
        XCTAssertTrue(mockLogger.warnMessages[0].contains("email"))
    }

    func testValidatePII_ExcludesPrivateAttributes() {
        let data: [String: Any] = ["email": "test@example.com", "phone": "123"]
        let privateAttributes: Set<String> = ["email"]

        XCTAssertThrowsError(try validatePII(
            in: data,
            dataType: .context,
            privateAttributes: privateAttributes,
            strictMode: true
        )) { error in
            guard case SecurityError.piiDetectedStrictMode(let fields) = error else {
                XCTFail("Expected SecurityError.piiDetectedStrictMode")
                return
            }
            XCTAssertFalse(fields.contains("email")) // email is private
            XCTAssertTrue(fields.contains("phone")) // phone is not private
        }
    }

    func testValidatePII_NoErrorWhenAllPIIIsPrivate() {
        let data: [String: Any] = ["email": "test@example.com"]
        let privateAttributes: Set<String> = ["email"]

        XCTAssertNoThrow(try validatePII(
            in: data,
            dataType: .context,
            privateAttributes: privateAttributes,
            strictMode: true
        ))
    }

    // MARK: - Production Environment Tests

    func testIsProductionEnvironment_ChecksAPPENV() {
        // Note: We can't easily test this without modifying environment variables
        // Just verify it doesn't crash and returns a boolean
        _ = isProductionEnvironment()
    }
    // MARK: - Cache Encryption Tests

    func testCacheEncryption_DeriveKey() throws {
        let key = try CacheEncryption.deriveKey(from: "sdk_test123")
        XCTAssertNotNil(key)
    }

    func testCacheEncryption_EncryptDecryptData() throws {
        let key = try CacheEncryption.deriveKey(from: "sdk_test123")
        let originalData = "Hello, World!".data(using: .utf8)!

        let encrypted = try CacheEncryption.encrypt(originalData, with: key)
        let decrypted = try CacheEncryption.decrypt(encrypted, with: key)

        XCTAssertEqual(decrypted, originalData)
        XCTAssertNotEqual(encrypted, originalData)
    }

    func testCacheEncryption_EncryptDecryptString() throws {
        let key = try CacheEncryption.deriveKey(from: "sdk_test123")
        let original = "Hello, World!"

        let encrypted = try CacheEncryption.encryptString(original, with: key)
        let decrypted = try CacheEncryption.decryptString(encrypted, with: key)

        XCTAssertEqual(decrypted, original)
        XCTAssertNotEqual(encrypted, original)
    }

    func testCacheEncryption_EncryptDecryptJSON() throws {
        struct TestData: Codable, Equatable {
            let name: String
            let value: Int
        }

        let key = try CacheEncryption.deriveKey(from: "sdk_test123")
        let original = TestData(name: "test", value: 42)

        let encrypted = try CacheEncryption.encryptJSON(original, with: key)
        let decrypted = try CacheEncryption.decryptJSON(encrypted, as: TestData.self, with: key)

        XCTAssertEqual(decrypted, original)
    }

    func testCacheEncryption_DifferentKeysProduceDifferentCiphertext() throws {
        let key1 = try CacheEncryption.deriveKey(from: "sdk_key1")
        let key2 = try CacheEncryption.deriveKey(from: "sdk_key2")
        let data = "sensitive data".data(using: .utf8)!

        let encrypted1 = try CacheEncryption.encrypt(data, with: key1)
        let encrypted2 = try CacheEncryption.encrypt(data, with: key2)

        // Different keys should produce different ciphertext (with high probability due to random nonce)
        XCTAssertNotEqual(encrypted1, encrypted2)
    }

    func testCacheEncryption_DecryptWithWrongKeyFails() throws {
        let key1 = try CacheEncryption.deriveKey(from: "sdk_key1")
        let key2 = try CacheEncryption.deriveKey(from: "sdk_key2")
        let data = "sensitive data".data(using: .utf8)!

        let encrypted = try CacheEncryption.encrypt(data, with: key1)

        XCTAssertThrowsError(try CacheEncryption.decrypt(encrypted, with: key2)) { error in
            XCTAssertTrue(error is SecurityError)
        }
    }

    func testCacheEncryption_InvalidBase64Fails() throws {
        let key = try CacheEncryption.deriveKey(from: "sdk_test123")

        XCTAssertThrowsError(try CacheEncryption.decryptString("not-valid-base64!!!", with: key)) { error in
            guard case SecurityError.decryptionFailed = error else {
                XCTFail("Expected SecurityError.decryptionFailed")
                return
            }
        }
    }

    // MARK: - EncryptedCache Tests

    func testEncryptedCache_SetAndGet() async throws {
        struct TestValue: Codable, Equatable {
            let id: String
            let enabled: Bool
        }

        let cache = try EncryptedCache(apiKey: "sdk_test123")
        let value = TestValue(id: "flag-1", enabled: true)

        try await cache.set("key1", value: value)
        let retrieved = await cache.get("key1", as: TestValue.self)

        XCTAssertEqual(retrieved, value)
    }

    func testEncryptedCache_SetAndGetString() async throws {
        let cache = try EncryptedCache(apiKey: "sdk_test123")

        try await cache.setString("key1", value: "hello world")
        let retrieved = await cache.getString("key1")

        XCTAssertEqual(retrieved, "hello world")
    }

    func testEncryptedCache_ReturnsNilForMissingKey() async throws {
        struct TestValue: Codable {
            let id: String
        }

        let cache = try EncryptedCache(apiKey: "sdk_test123")
        let retrieved = await cache.get("nonexistent", as: TestValue.self)

        XCTAssertNil(retrieved)
    }

    func testEncryptedCache_ExpiredEntryReturnsNil() async throws {
        struct TestValue: Codable, Equatable {
            let id: String
        }

        let cache = try EncryptedCache(apiKey: "sdk_test123", ttl: 0.001) // 1ms TTL
        let value = TestValue(id: "flag-1")

        try await cache.set("key1", value: value)

        // Wait for expiration
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms

        let retrieved = await cache.get("key1", as: TestValue.self)
        XCTAssertNil(retrieved)
    }

    func testEncryptedCache_GetStaleValueReturnsExpired() async throws {
        struct TestValue: Codable, Equatable {
            let id: String
        }

        let cache = try EncryptedCache(apiKey: "sdk_test123", ttl: 0.001)
        let value = TestValue(id: "flag-1")

        try await cache.set("key1", value: value)

        try await Task.sleep(nanoseconds: 10_000_000)

        let stale = await cache.getStaleValue("key1", as: TestValue.self)
        XCTAssertEqual(stale, value)
    }

    func testEncryptedCache_Has() async throws {
        struct TestValue: Codable {
            let id: String
        }

        let cache = try EncryptedCache(apiKey: "sdk_test123")

        let hasBeforeSet = await cache.has("key1")
        XCTAssertFalse(hasBeforeSet)

        try await cache.set("key1", value: TestValue(id: "1"))

        let hasAfterSet = await cache.has("key1")
        XCTAssertTrue(hasAfterSet)
    }

    func testEncryptedCache_Delete() async throws {
        struct TestValue: Codable {
            let id: String
        }

        let cache = try EncryptedCache(apiKey: "sdk_test123")

        try await cache.set("key1", value: TestValue(id: "1"))
        let hasBeforeDelete = await cache.has("key1")
        XCTAssertTrue(hasBeforeDelete)

        let deleted = await cache.delete("key1")
        XCTAssertTrue(deleted)

        let hasAfterDelete = await cache.has("key1")
        XCTAssertFalse(hasAfterDelete)
    }

    func testEncryptedCache_Clear() async throws {
        struct TestValue: Codable {
            let id: String
        }

        let cache = try EncryptedCache(apiKey: "sdk_test123")

        try await cache.set("key1", value: TestValue(id: "1"))
        try await cache.set("key2", value: TestValue(id: "2"))

        await cache.clear()

        let count = await cache.count
        XCTAssertEqual(count, 0)
    }

    func testEncryptedCache_GetStats() async throws {
        struct TestValue: Codable {
            let id: String
        }

        let cache = try EncryptedCache(apiKey: "sdk_test123", maxSize: 100)

        try await cache.set("key1", value: TestValue(id: "1"))
        try await cache.set("key2", value: TestValue(id: "2"))

        let stats = await cache.getStats()

        XCTAssertEqual(stats.size, 2)
        XCTAssertEqual(stats.validCount, 2)
        XCTAssertEqual(stats.staleCount, 0)
        XCTAssertEqual(stats.maxSize, 100)
    }

    // MARK: - SecurityConfig Strict PII Mode Tests

    func testSecurityConfig_StrictPIIMode() {
        let config = SecurityConfig(strictPIIMode: true)
        XCTAssertTrue(config.strictPIIMode)

        let defaultConfig = SecurityConfig()
        XCTAssertFalse(defaultConfig.strictPIIMode)
    }

    // MARK: - FlagKitOptions Security Features Tests

    func testFlagKitOptions_SecondaryApiKey() throws {
        let options = FlagKitOptions(
            apiKey: "sdk_primary123",
            secondaryApiKey: "sdk_secondary456"
        )

        XCTAssertEqual(options.apiKey, "sdk_primary123")
        XCTAssertEqual(options.secondaryApiKey, "sdk_secondary456")

        // Should validate successfully
        XCTAssertNoThrow(try options.validate())
    }

    func testFlagKitOptions_InvalidSecondaryApiKeyFails() {
        let options = FlagKitOptions(
            apiKey: "sdk_primary123",
            secondaryApiKey: "invalid_key"
        )

        XCTAssertThrowsError(try options.validate()) { error in
            guard let flagKitError = error as? FlagKitError else {
                XCTFail("Expected FlagKitError")
                return
            }
            XCTAssertEqual(flagKitError.code, .configInvalidApiKey)
        }
    }

    func testFlagKitOptions_StrictPIIMode() {
        let options = FlagKitOptions(
            apiKey: "sdk_test123",
            strictPIIMode: true
        )

        XCTAssertTrue(options.strictPIIMode)
    }

    func testFlagKitOptions_EnableRequestSigning() {
        let options = FlagKitOptions(
            apiKey: "sdk_test123",
            enableRequestSigning: true
        )

        XCTAssertTrue(options.enableRequestSigning)
    }

    func testFlagKitOptions_EnableCacheEncryption() {
        let options = FlagKitOptions(
            apiKey: "sdk_test123",
            enableCacheEncryption: true
        )

        XCTAssertTrue(options.enableCacheEncryption)
    }

    func testFlagKitOptions_Builder() {
        let options = FlagKitOptions.Builder(apiKey: "sdk_test123")
            .secondaryApiKey("sdk_secondary456")
            .strictPIIMode(true)
            .enableRequestSigning(true)
            .enableCacheEncryption(true)
            .build()

        XCTAssertEqual(options.apiKey, "sdk_test123")
        XCTAssertEqual(options.secondaryApiKey, "sdk_secondary456")
        XCTAssertTrue(options.strictPIIMode)
        XCTAssertTrue(options.enableRequestSigning)
        XCTAssertTrue(options.enableCacheEncryption)
    }
}
