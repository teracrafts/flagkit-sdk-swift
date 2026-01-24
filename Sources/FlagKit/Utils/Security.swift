import Foundation

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

// MARK: - Security Configuration

/// Security configuration options for the FlagKit SDK.
public struct SecurityConfig: Sendable {
    /// Warn about potential PII in context/events. Default: true in debug builds.
    public let warnOnPotentialPII: Bool

    /// Warn when server keys are used in client-like environments. Default: true.
    public let warnOnServerKeyInClient: Bool

    /// Custom PII patterns to detect (in addition to built-in patterns).
    public let additionalPIIPatterns: [String]

    /// Creates a new security configuration.
    /// - Parameters:
    ///   - warnOnPotentialPII: Warn about potential PII in context/events.
    ///   - warnOnServerKeyInClient: Warn when server keys are used in client-like environments.
    ///   - additionalPIIPatterns: Custom PII patterns to detect.
    public init(
        warnOnPotentialPII: Bool? = nil,
        warnOnServerKeyInClient: Bool = true,
        additionalPIIPatterns: [String] = []
    ) {
        #if DEBUG
        self.warnOnPotentialPII = warnOnPotentialPII ?? true
        #else
        self.warnOnPotentialPII = warnOnPotentialPII ?? false
        #endif
        self.warnOnServerKeyInClient = warnOnServerKeyInClient
        self.additionalPIIPatterns = additionalPIIPatterns
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
