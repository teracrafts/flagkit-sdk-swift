import Foundation
import CryptoKit

// MARK: - Logger Protocol

/// Logger protocol for SDK logging.
public protocol Logger: Sendable {
    func debug(_ message: String, data: [String: Any]?)
    func info(_ message: String, data: [String: Any]?)
    func warn(_ message: String, data: [String: Any]?)
    func error(_ message: String, data: [String: Any]?)
}

public extension Logger {
    func debug(_ message: String) { debug(message, data: nil) }
    func info(_ message: String) { info(message, data: nil) }
    func warn(_ message: String) { warn(message, data: nil) }
    func error(_ message: String) { error(message, data: nil) }
}

// MARK: - Security Error

/// Security-related errors for FlagKit SDK.
public enum SecurityError: Error, Sendable, LocalizedError {
    /// Local port cannot be used in production environment.
    case localPortInProduction
    /// PII detected without privateAttributes (strict mode).
    case piiDetectedStrictMode(fields: [String])
    /// Encryption failed.
    case encryptionFailed(String)
    /// Decryption failed.
    case decryptionFailed(String)
    /// Key derivation failed.
    case keyDerivationFailed
    /// Bootstrap verification failed.
    case bootstrapVerificationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .localPortInProduction:
            return "[SECURITY_ERROR] Local port cannot be used in production environment (APP_ENV=production)"
        case .piiDetectedStrictMode(let fields):
            return "[SECURITY_ERROR] PII detected in strict mode without privateAttributes: \(fields.joined(separator: ", "))"
        case .encryptionFailed(let reason):
            return "[SECURITY_ERROR] Encryption failed: \(reason)"
        case .decryptionFailed(let reason):
            return "[SECURITY_ERROR] Decryption failed: \(reason)"
        case .keyDerivationFailed:
            return "[SECURITY_ERROR] Key derivation failed"
        case .bootstrapVerificationFailed(let reason):
            return "[SECURITY_ERROR] Bootstrap verification failed: \(reason)"
        }
    }
}

// MARK: - Security Configuration

/// Security configuration options for the FlagKit SDK.
public struct SecurityConfig: Sendable {
    /// Warn about potential PII in context/events. Default: true in debug builds.
    public let warnOnPotentialPII: Bool

    /// Warn when server keys are used in client-like environments. Default: true.
    public let warnOnServerKeyInClient: Bool

    /// Custom PII patterns to detect (in addition to built-in patterns).
    public let additionalPIIPatterns: [String]

    /// Strict PII mode: throws SecurityError instead of warning when PII is detected without privateAttributes.
    public let strictPIIMode: Bool

    /// Creates a new security configuration.
    /// - Parameters:
    ///   - warnOnPotentialPII: Warn about potential PII in context/events.
    ///   - warnOnServerKeyInClient: Warn when server keys are used in client-like environments.
    ///   - additionalPIIPatterns: Custom PII patterns to detect.
    ///   - strictPIIMode: Throws SecurityError instead of warning when PII is detected.
    public init(
        warnOnPotentialPII: Bool? = nil,
        warnOnServerKeyInClient: Bool = true,
        additionalPIIPatterns: [String] = [],
        strictPIIMode: Bool = false
    ) {
        #if DEBUG
        self.warnOnPotentialPII = warnOnPotentialPII ?? true
        #else
        self.warnOnPotentialPII = warnOnPotentialPII ?? false
        #endif
        self.warnOnServerKeyInClient = warnOnServerKeyInClient
        self.additionalPIIPatterns = additionalPIIPatterns
        self.strictPIIMode = strictPIIMode
    }

    /// Default security configuration.
    public static let `default` = SecurityConfig()
}

// MARK: - PII Detection

/// Common PII field patterns (case-insensitive).
private let piiPatterns: [String] = [
    "email",
    "phone",
    "telephone",
    "mobile",
    "ssn",
    "social_security",
    "socialSecurity",
    "credit_card",
    "creditCard",
    "card_number",
    "cardNumber",
    "cvv",
    "password",
    "passwd",
    "secret",
    "token",
    "api_key",
    "apiKey",
    "private_key",
    "privateKey",
    "access_token",
    "accessToken",
    "refresh_token",
    "refreshToken",
    "auth_token",
    "authToken",
    "address",
    "street",
    "zip_code",
    "zipCode",
    "postal_code",
    "postalCode",
    "date_of_birth",
    "dateOfBirth",
    "dob",
    "birth_date",
    "birthDate",
    "passport",
    "driver_license",
    "driverLicense",
    "national_id",
    "nationalId",
    "bank_account",
    "bankAccount",
    "routing_number",
    "routingNumber",
    "iban",
    "swift"
]

/// Checks if a field name potentially contains PII.
/// - Parameter fieldName: The field name to check.
/// - Returns: True if the field name matches a PII pattern.
public func isPotentialPIIField(_ fieldName: String) -> Bool {
    let lowerName = fieldName.lowercased()
    return piiPatterns.contains { pattern in
        lowerName.contains(pattern.lowercased())
    }
}

/// Checks if a field name potentially contains PII, including custom patterns.
/// - Parameters:
///   - fieldName: The field name to check.
///   - additionalPatterns: Additional patterns to check.
/// - Returns: True if the field name matches a PII pattern.
public func isPotentialPIIField(_ fieldName: String, additionalPatterns: [String]) -> Bool {
    if isPotentialPIIField(fieldName) {
        return true
    }

    let lowerName = fieldName.lowercased()
    return additionalPatterns.contains { pattern in
        lowerName.contains(pattern.lowercased())
    }
}

/// Detects potential PII in a dictionary and returns the field paths.
/// - Parameters:
///   - data: The dictionary to check.
///   - prefix: The prefix for nested field paths.
///   - additionalPatterns: Additional patterns to check.
/// - Returns: An array of field paths that potentially contain PII.
public func detectPotentialPII(
    in data: [String: Any],
    prefix: String = "",
    additionalPatterns: [String] = []
) -> [String] {
    var piiFields: [String] = []

    for (key, value) in data {
        let fullPath = prefix.isEmpty ? key : "\(prefix).\(key)"

        if isPotentialPIIField(key, additionalPatterns: additionalPatterns) {
            piiFields.append(fullPath)
        }

        // Recursively check nested dictionaries
        if let nestedDict = value as? [String: Any] {
            let nestedPII = detectPotentialPII(
                in: nestedDict,
                prefix: fullPath,
                additionalPatterns: additionalPatterns
            )
            piiFields.append(contentsOf: nestedPII)
        }
    }

    return piiFields
}

/// Data type for PII warning messages.
public enum PIIDataType: String {
    case context
    case event
}

/// Logs a warning if potential PII is detected in the data.
/// - Parameters:
///   - data: The data to check for PII.
///   - dataType: The type of data being checked (context or event).
///   - logger: The logger to use for warnings.
///   - additionalPatterns: Additional patterns to check.
public func warnIfPotentialPII(
    in data: [String: Any]?,
    dataType: PIIDataType,
    logger: Logger?,
    additionalPatterns: [String] = []
) {
    guard let data = data, let logger = logger else {
        return
    }

    let piiFields = detectPotentialPII(
        in: data,
        additionalPatterns: additionalPatterns
    )

    guard !piiFields.isEmpty else {
        return
    }

    let fieldsDescription = piiFields.joined(separator: ", ")
    let recommendation: String

    switch dataType {
    case .context:
        recommendation = "Consider adding these to privateAttributes."
    case .event:
        recommendation = "Consider removing sensitive data from events."
    }

    logger.warn(
        "[FlagKit Security] Potential PII detected in \(dataType.rawValue) data: \(fieldsDescription). \(recommendation)"
    )
}

// MARK: - API Key Validation

/// Checks if an API key is a server key.
/// - Parameter apiKey: The API key to check.
/// - Returns: True if the key starts with "srv_".
public func isServerKey(_ apiKey: String) -> Bool {
    apiKey.hasPrefix("srv_")
}

/// Checks if an API key is a client/SDK key.
/// - Parameter apiKey: The API key to check.
/// - Returns: True if the key starts with "sdk_" or "cli_".
public func isClientKey(_ apiKey: String) -> Bool {
    apiKey.hasPrefix("sdk_") || apiKey.hasPrefix("cli_")
}

/// Checks if the current environment is considered a "client" environment.
/// On iOS/tvOS/watchOS, this returns true. On macOS, it checks for app sandbox.
/// - Returns: True if running in a client-like environment.
public func isClientEnvironment() -> Bool {
    #if os(iOS) || os(tvOS) || os(watchOS)
    return true
    #elseif os(macOS)
    // Check if running in an App Sandbox (typical for Mac apps distributed via App Store)
    let homeDir = NSHomeDirectory()
    return homeDir.contains("/Library/Containers/")
    #else
    return false
    #endif
}

/// Logs a warning if a server key is used in a client-like environment.
/// - Parameters:
///   - apiKey: The API key to check.
///   - logger: The logger to use for warnings.
public func warnIfServerKeyInClient(_ apiKey: String, logger: Logger?) {
    guard isClientEnvironment() && isServerKey(apiKey) else {
        return
    }

    let message = """
        [FlagKit Security] WARNING: Server keys (srv_) should not be used in client environments. \
        This exposes your server key in client-side code, which is a security risk. \
        Use SDK keys (sdk_) for client-side applications instead. \
        See: https://docs.flagkit.dev/sdk/security#api-keys
        """

    // Always print to console for visibility
    print(message)

    // Also log through the SDK logger if available
    logger?.warn(message)
}

// MARK: - String Extension

public extension String {
    /// Checks if this string (as a field name) potentially contains PII.
    var isPotentialPIIField: Bool {
        SecurityUtils.checkPotentialPII(self)
    }
}

/// Internal namespace for security utility functions.
/// This avoids naming conflicts with the FlagKit class.
internal enum SecurityUtils {
    static func checkPotentialPII(_ fieldName: String) -> Bool {
        let lowerName = fieldName.lowercased()
        return piiPatterns.contains { pattern in
            lowerName.contains(pattern.lowercased())
        }
    }
}

// MARK: - Strict PII Mode

/// PII detection result for strict mode validation.
public struct PIIDetectionResult: Sendable {
    /// Whether PII was detected.
    public let hasPII: Bool
    /// The fields that contain potential PII.
    public let fields: [String]
    /// A descriptive message about the detected PII.
    public let message: String

    public init(hasPII: Bool, fields: [String], message: String) {
        self.hasPII = hasPII
        self.fields = fields
        self.message = message
    }
}

/// Checks for potential PII in data and returns detailed result.
/// - Parameters:
///   - data: The data to check for PII.
///   - dataType: The type of data being checked (context or event).
///   - additionalPatterns: Additional patterns to check.
/// - Returns: A PIIDetectionResult with details about detected PII.
public func checkForPotentialPII(
    in data: [String: Any]?,
    dataType: PIIDataType,
    additionalPatterns: [String] = []
) -> PIIDetectionResult {
    guard let data = data else {
        return PIIDetectionResult(hasPII: false, fields: [], message: "")
    }

    let piiFields = detectPotentialPII(
        in: data,
        additionalPatterns: additionalPatterns
    )

    guard !piiFields.isEmpty else {
        return PIIDetectionResult(hasPII: false, fields: [], message: "")
    }

    let fieldsDescription = piiFields.joined(separator: ", ")
    let recommendation: String

    switch dataType {
    case .context:
        recommendation = "Consider adding these to privateAttributes."
    case .event:
        recommendation = "Consider removing sensitive data from events."
    }

    let message = "[FlagKit Security] Potential PII detected in \(dataType.rawValue) data: \(fieldsDescription). \(recommendation)"

    return PIIDetectionResult(hasPII: true, fields: piiFields, message: message)
}

/// Validates PII in data, optionally throwing in strict mode.
/// - Parameters:
///   - data: The data to check for PII.
///   - dataType: The type of data being checked.
///   - privateAttributes: Fields that are marked as private (excluded from PII check).
///   - strictMode: Whether to throw an error instead of warning.
///   - logger: Optional logger for warnings.
///   - additionalPatterns: Additional PII patterns to check.
/// - Throws: SecurityError.piiDetectedStrictMode if strict mode is enabled and PII is found.
public func validatePII(
    in data: [String: Any]?,
    dataType: PIIDataType,
    privateAttributes: Set<String> = [],
    strictMode: Bool = false,
    logger: Logger? = nil,
    additionalPatterns: [String] = []
) throws {
    guard let data = data else { return }

    // Filter out private attributes from the check
    let filteredData = data.filter { !privateAttributes.contains($0.key) }

    let result = checkForPotentialPII(
        in: filteredData,
        dataType: dataType,
        additionalPatterns: additionalPatterns
    )

    guard result.hasPII else { return }

    if strictMode {
        throw SecurityError.piiDetectedStrictMode(fields: result.fields)
    } else {
        logger?.warn(result.message)
    }
}

// MARK: - Production Environment Check

/// Checks if the current environment is production based on APP_ENV environment variable.
/// - Returns: True if APP_ENV is "production".
public func isProductionEnvironment() -> Bool {
    ProcessInfo.processInfo.environment["APP_ENV"] == "production"
}

/// Validates that localPort is not used in production environment.
/// - Parameter localPort: The local port setting, if any.
/// - Throws: SecurityError.localPortInProduction if localPort is set in production.
public func validateLocalPortRestriction(localPort: Int?) throws {
    guard let _ = localPort else { return }

    if isProductionEnvironment() {
        throw SecurityError.localPortInProduction
    }
}

// MARK: - HMAC-SHA256 Request Signing

/// Gets the first 8 characters of an API key for identification.
/// This is safe to expose as it doesn't reveal the full key.
/// - Parameter apiKey: The API key.
/// - Returns: The key ID (first 8 characters).
public func getKeyId(_ apiKey: String) -> String {
    String(apiKey.prefix(8))
}

/// Generates an HMAC-SHA256 signature for a message.
/// - Parameters:
///   - message: The message to sign.
///   - key: The secret key.
/// - Returns: The hexadecimal signature string.
public func generateHMACSHA256(message: String, key: String) -> String {
    let keyData = Data(key.utf8)
    let messageData = Data(message.utf8)

    let symmetricKey = SymmetricKey(data: keyData)
    let signature = HMAC<SHA256>.authenticationCode(for: messageData, using: symmetricKey)

    return signature.map { String(format: "%02x", $0) }.joined()
}

/// Request signature result containing the signature and timestamp.
public struct RequestSignature: Sendable {
    /// The HMAC-SHA256 signature in hexadecimal format.
    public let signature: String
    /// The timestamp used in the signature.
    public let timestamp: Int64
    /// The key ID (first 8 chars of API key).
    public let keyId: String

    public init(signature: String, timestamp: Int64, keyId: String) {
        self.signature = signature
        self.timestamp = timestamp
        self.keyId = keyId
    }
}

/// Creates a request signature for POST request bodies.
/// - Parameters:
///   - body: The request body as a string (usually JSON).
///   - apiKey: The API key to use for signing.
///   - timestamp: Optional timestamp (defaults to current time in milliseconds).
/// - Returns: A RequestSignature containing the signature, timestamp, and key ID.
public func createRequestSignature(
    body: String,
    apiKey: String,
    timestamp: Int64? = nil
) -> RequestSignature {
    let ts = timestamp ?? Int64(Date().timeIntervalSince1970 * 1000)
    let message = "\(ts).\(body)"
    let signature = generateHMACSHA256(message: message, key: apiKey)

    return RequestSignature(
        signature: signature,
        timestamp: ts,
        keyId: getKeyId(apiKey)
    )
}

/// Signed payload structure for beacon requests.
public struct SignedPayload<T>: Sendable where T: Sendable {
    /// The data being signed.
    public let data: T
    /// The HMAC-SHA256 signature.
    public let signature: String
    /// The timestamp used in the signature.
    public let timestamp: Int64
    /// The key ID.
    public let keyId: String

    public init(data: T, signature: String, timestamp: Int64, keyId: String) {
        self.data = data
        self.signature = signature
        self.timestamp = timestamp
        self.keyId = keyId
    }
}

/// Signs a payload with HMAC-SHA256.
/// - Parameters:
///   - data: The data to sign.
///   - apiKey: The API key.
///   - timestamp: Optional timestamp.
/// - Returns: A SignedPayload containing the data and signature.
/// - Throws: If JSON serialization fails.
public func signPayload<T>(
    data: T,
    apiKey: String,
    timestamp: Int64? = nil
) throws -> SignedPayload<T> where T: Encodable & Sendable {
    let ts = timestamp ?? Int64(Date().timeIntervalSince1970 * 1000)
    let jsonData = try JSONEncoder().encode(data)
    guard let payload = String(data: jsonData, encoding: .utf8) else {
        throw SecurityError.encryptionFailed("Failed to encode payload as UTF-8")
    }

    let message = "\(ts).\(payload)"
    let signature = generateHMACSHA256(message: message, key: apiKey)

    return SignedPayload(
        data: data,
        signature: signature,
        timestamp: ts,
        keyId: getKeyId(apiKey)
    )
}

/// Signs a dictionary payload with HMAC-SHA256.
/// - Parameters:
///   - data: The dictionary data to sign.
///   - apiKey: The API key.
///   - timestamp: Optional timestamp.
/// - Returns: A SignedPayload containing the data and signature.
/// - Throws: If JSON serialization fails.
public func signPayload(
    data: [String: Any],
    apiKey: String,
    timestamp: Int64? = nil
) throws -> SignedPayload<[String: Any]> {
    let ts = timestamp ?? Int64(Date().timeIntervalSince1970 * 1000)
    let jsonData = try JSONSerialization.data(withJSONObject: data, options: .sortedKeys)
    guard let payload = String(data: jsonData, encoding: .utf8) else {
        throw SecurityError.encryptionFailed("Failed to encode payload as UTF-8")
    }

    let message = "\(ts).\(payload)"
    let signature = generateHMACSHA256(message: message, key: apiKey)

    return SignedPayload(
        data: data,
        signature: signature,
        timestamp: ts,
        keyId: getKeyId(apiKey)
    )
}

/// Verifies a signed payload.
/// - Parameters:
///   - signedPayload: The signed payload to verify.
///   - apiKey: The API key.
///   - maxAgeMs: Maximum age of the signature in milliseconds (default: 5 minutes).
/// - Returns: True if the signature is valid.
public func verifySignedPayload<T>(
    _ signedPayload: SignedPayload<T>,
    apiKey: String,
    maxAgeMs: Int64 = 300_000
) -> Bool where T: Encodable & Sendable {
    // Check timestamp age
    let currentTime = Int64(Date().timeIntervalSince1970 * 1000)
    let age = currentTime - signedPayload.timestamp
    if age > maxAgeMs || age < 0 {
        return false
    }

    // Verify key ID matches
    if signedPayload.keyId != getKeyId(apiKey) {
        return false
    }

    // Verify signature
    guard let jsonData = try? JSONEncoder().encode(signedPayload.data),
          let payload = String(data: jsonData, encoding: .utf8) else {
        return false
    }

    let message = "\(signedPayload.timestamp).\(payload)"
    let expectedSignature = generateHMACSHA256(message: message, key: apiKey)

    return signedPayload.signature == expectedSignature
}

/// Verifies a signed dictionary payload.
/// - Parameters:
///   - signedPayload: The signed payload to verify.
///   - apiKey: The API key.
///   - maxAgeMs: Maximum age of the signature in milliseconds.
/// - Returns: True if the signature is valid.
public func verifySignedPayload(
    _ signedPayload: SignedPayload<[String: Any]>,
    apiKey: String,
    maxAgeMs: Int64 = 300_000
) -> Bool {
    // Check timestamp age
    let currentTime = Int64(Date().timeIntervalSince1970 * 1000)
    let age = currentTime - signedPayload.timestamp
    if age > maxAgeMs || age < 0 {
        return false
    }

    // Verify key ID matches
    if signedPayload.keyId != getKeyId(apiKey) {
        return false
    }

    // Verify signature
    guard let jsonData = try? JSONSerialization.data(withJSONObject: signedPayload.data, options: .sortedKeys),
          let payload = String(data: jsonData, encoding: .utf8) else {
        return false
    }

    let message = "\(signedPayload.timestamp).\(payload)"
    let expectedSignature = generateHMACSHA256(message: message, key: apiKey)

    return signedPayload.signature == expectedSignature
}

// MARK: - Cache Encryption (AES-GCM with PBKDF2)

/// Encryption utilities for secure cache storage.
public enum CacheEncryption {
    /// Default salt for PBKDF2 key derivation.
    public static let defaultSalt = "FlagKit-Cache-Encryption-Salt-v1"
    /// Default iteration count for PBKDF2.
    public static let defaultIterations = 100_000

    /// Derives an encryption key from an API key using PBKDF2.
    /// - Parameters:
    ///   - apiKey: The API key to derive from.
    ///   - salt: Optional custom salt (defaults to SDK-specific salt).
    ///   - iterations: Number of PBKDF2 iterations (default: 100,000).
    /// - Returns: A SymmetricKey suitable for AES-GCM encryption.
    /// - Throws: SecurityError.keyDerivationFailed if derivation fails.
    public static func deriveKey(
        from apiKey: String,
        salt: String? = nil,
        iterations: Int = defaultIterations
    ) throws -> SymmetricKey {
        let passwordData = Data(apiKey.utf8)
        let saltData = Data((salt ?? defaultSalt).utf8)

        // Use SHA256-based PBKDF2 to derive a 256-bit key
        var derivedKeyData = Data(count: 32) // 256 bits for AES-256
        let derivationStatus = derivedKeyData.withUnsafeMutableBytes { derivedKeyBytes in
            passwordData.withUnsafeBytes { passwordBytes in
                saltData.withUnsafeBytes { saltBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                        passwordData.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        saltData.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(iterations),
                        derivedKeyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        32
                    )
                }
            }
        }

        guard derivationStatus == kCCSuccess else {
            throw SecurityError.keyDerivationFailed
        }

        return SymmetricKey(data: derivedKeyData)
    }

    /// Encrypts data using AES-GCM.
    /// - Parameters:
    ///   - data: The data to encrypt.
    ///   - key: The symmetric key for encryption.
    /// - Returns: The encrypted data (nonce + ciphertext + tag).
    /// - Throws: SecurityError.encryptionFailed if encryption fails.
    public static func encrypt(_ data: Data, with key: SymmetricKey) throws -> Data {
        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            guard let combined = sealedBox.combined else {
                throw SecurityError.encryptionFailed("Failed to combine sealed box")
            }
            return combined
        } catch let error as SecurityError {
            throw error
        } catch {
            throw SecurityError.encryptionFailed(error.localizedDescription)
        }
    }

    /// Decrypts data using AES-GCM.
    /// - Parameters:
    ///   - data: The encrypted data (nonce + ciphertext + tag).
    ///   - key: The symmetric key for decryption.
    /// - Returns: The decrypted data.
    /// - Throws: SecurityError.decryptionFailed if decryption fails.
    public static func decrypt(_ data: Data, with key: SymmetricKey) throws -> Data {
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            throw SecurityError.decryptionFailed(error.localizedDescription)
        }
    }

    /// Encrypts a string using AES-GCM.
    /// - Parameters:
    ///   - string: The string to encrypt.
    ///   - key: The symmetric key for encryption.
    /// - Returns: The encrypted data as base64 string.
    /// - Throws: SecurityError.encryptionFailed if encryption fails.
    public static func encryptString(_ string: String, with key: SymmetricKey) throws -> String {
        let data = Data(string.utf8)
        let encrypted = try encrypt(data, with: key)
        return encrypted.base64EncodedString()
    }

    /// Decrypts a base64-encoded encrypted string.
    /// - Parameters:
    ///   - base64String: The base64-encoded encrypted data.
    ///   - key: The symmetric key for decryption.
    /// - Returns: The decrypted string.
    /// - Throws: SecurityError.decryptionFailed if decryption fails.
    public static func decryptString(_ base64String: String, with key: SymmetricKey) throws -> String {
        guard let data = Data(base64Encoded: base64String) else {
            throw SecurityError.decryptionFailed("Invalid base64 string")
        }
        let decrypted = try decrypt(data, with: key)
        guard let string = String(data: decrypted, encoding: .utf8) else {
            throw SecurityError.decryptionFailed("Invalid UTF-8 data")
        }
        return string
    }

    /// Encrypts JSON-serializable data.
    /// - Parameters:
    ///   - value: The value to encrypt (must be Encodable).
    ///   - key: The symmetric key for encryption.
    /// - Returns: The encrypted data as base64 string.
    /// - Throws: SecurityError if encryption fails.
    public static func encryptJSON<T: Encodable>(_ value: T, with key: SymmetricKey) throws -> String {
        let jsonData = try JSONEncoder().encode(value)
        let encrypted = try encrypt(jsonData, with: key)
        return encrypted.base64EncodedString()
    }

    /// Decrypts JSON data.
    /// - Parameters:
    ///   - base64String: The base64-encoded encrypted data.
    ///   - type: The type to decode to.
    ///   - key: The symmetric key for decryption.
    /// - Returns: The decrypted and decoded value.
    /// - Throws: SecurityError if decryption or decoding fails.
    public static func decryptJSON<T: Decodable>(_ base64String: String, as type: T.Type, with key: SymmetricKey) throws -> T {
        guard let data = Data(base64Encoded: base64String) else {
            throw SecurityError.decryptionFailed("Invalid base64 string")
        }
        let decrypted = try decrypt(data, with: key)
        return try JSONDecoder().decode(type, from: decrypted)
    }
}

// Import CommonCrypto for PBKDF2
import CommonCrypto

// MARK: - Bootstrap Signature Verification

/// Canonicalizes an object for consistent signature generation.
/// Produces a deterministic string representation by sorting keys at all levels.
/// - Parameter obj: The dictionary to canonicalize.
/// - Returns: A canonical JSON string representation.
public func canonicalizeObject(_ obj: [String: Any]) -> String {
    do {
        let data = try JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys])
        return String(data: data, encoding: .utf8) ?? "{}"
    } catch {
        return "{}"
    }
}

/// Performs constant-time comparison of two strings to prevent timing attacks.
/// - Parameters:
///   - a: First string.
///   - b: Second string.
/// - Returns: True if strings are equal.
public func constantTimeCompare(_ a: String, _ b: String) -> Bool {
    let aBytes = Array(a.utf8)
    let bBytes = Array(b.utf8)

    // Always compare both strings fully to prevent timing attacks
    guard aBytes.count == bBytes.count else {
        // Still do a comparison to maintain constant time even on length mismatch
        var result: UInt8 = 1
        for i in 0..<max(aBytes.count, bBytes.count) {
            let aVal = i < aBytes.count ? aBytes[i] : 0
            let bVal = i < bBytes.count ? bBytes[i] : 0
            result |= aVal ^ bVal
        }
        return false
    }

    var result: UInt8 = 0
    for i in 0..<aBytes.count {
        result |= aBytes[i] ^ bBytes[i]
    }
    return result == 0
}

/// Verifies the signature of bootstrap data.
/// - Parameters:
///   - bootstrap: The bootstrap configuration containing flags and optional signature.
///   - apiKey: The API key used to generate the signature.
///   - config: The verification configuration.
/// - Returns: A verification result indicating success or failure.
public func verifyBootstrapSignature(
    bootstrap: BootstrapConfig,
    apiKey: String,
    config: BootstrapVerificationConfig
) -> BootstrapVerificationResult {
    // If verification is disabled, always succeed
    guard config.enabled else {
        return .success
    }

    // If no signature provided, verification fails
    guard let signature = bootstrap.signature else {
        return .failure("No signature provided for bootstrap verification")
    }

    // If timestamp is provided, check freshness
    if let timestamp = bootstrap.timestamp {
        let currentTime = Int64(Date().timeIntervalSince1970 * 1000)
        let age = currentTime - timestamp

        // Check if timestamp is in the future (allow 60 seconds of clock skew)
        if age < -60_000 {
            return .failure("Bootstrap timestamp is in the future")
        }

        // Check if bootstrap data is too old
        if age > config.maxAge {
            return .failure("Bootstrap data has expired (age: \(age)ms, maxAge: \(config.maxAge)ms)")
        }
    }

    // Canonicalize the flags object
    let canonicalFlags = canonicalizeObject(bootstrap.flags)

    // Build the message to verify: timestamp.flags (if timestamp present) or just flags
    let message: String
    if let timestamp = bootstrap.timestamp {
        message = "\(timestamp).\(canonicalFlags)"
    } else {
        message = canonicalFlags
    }

    // Generate expected signature
    let expectedSignature = generateHMACSHA256(message: message, key: apiKey)

    // Perform constant-time comparison
    guard constantTimeCompare(signature, expectedSignature) else {
        return .failure("Invalid bootstrap signature")
    }

    return .success
}

/// Creates a signed bootstrap configuration.
/// - Parameters:
///   - flags: The flag data to bootstrap.
///   - apiKey: The API key to use for signing.
///   - timestamp: Optional timestamp (defaults to current time).
/// - Returns: A signed BootstrapConfig.
public func createSignedBootstrap(
    flags: [String: Any],
    apiKey: String,
    timestamp: Int64? = nil
) -> BootstrapConfig {
    let ts = timestamp ?? Int64(Date().timeIntervalSince1970 * 1000)
    let canonicalFlags = canonicalizeObject(flags)
    let message = "\(ts).\(canonicalFlags)"
    let signature = generateHMACSHA256(message: message, key: apiKey)

    return BootstrapConfig(flags: flags, signature: signature, timestamp: ts)
}
