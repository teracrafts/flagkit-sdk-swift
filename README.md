# FlagKit Swift SDK

Official Swift SDK for [FlagKit](https://flagkit.dev) feature flag management.

## Requirements

- iOS 15.0+ / macOS 12.0+ / tvOS 15.0+ / watchOS 8.0+
- Swift 5.9+

## Installation

### Swift Package Manager

Add FlagKit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/teracrafts/flagkit-sdk.git", from: "1.0.0")
]
```

Or add it via Xcode: File > Add Packages > Enter the repository URL.

## Quick Start

```swift
import FlagKit

// Initialize the SDK
let client = try await FlagKit.initialize(apiKey: "sdk_your_api_key")

// Identify the current user
await FlagKit.identify(userId: "user-123", attributes: [
    "plan": .string("pro")
])

// Evaluate feature flags
let darkMode = await FlagKit.getBoolValue("dark-mode", default: false)
let theme = await FlagKit.getStringValue("theme", default: "light")
let maxItems = await FlagKit.getIntValue("max-items", default: 10)
let config = await FlagKit.getJsonValue("feature-config", default: [:])

// Track events
await FlagKit.track("button_clicked", data: ["button": "signup"])

// Shutdown when done
await FlagKit.shutdown()
```

## Features

- **Type-safe evaluation** - Boolean, string, number, and JSON flag types
- **Local caching** - Fast evaluations with configurable TTL and optional encryption
- **Background polling** - Automatic flag updates
- **Event tracking** - Analytics with batching and crash-resilient persistence
- **Resilient** - Circuit breaker, retry with exponential backoff, offline support
- **Thread-safe** - Actor-based concurrency with Swift's modern async/await
- **Security** - PII detection, request signing, bootstrap verification, timing attack protection

## Architecture

The SDK is organized into clean, modular components:

```
FlagKit/
├── FlagKit.swift           # Static methods and singleton access
├── FlagKitClient.swift     # Main client actor
├── FlagKitOptions.swift    # Configuration options
├── Core/                   # Core components
│   ├── FlagCache.swift     # In-memory cache with TTL
│   ├── ContextManager.swift
│   ├── PollingManager.swift
│   ├── EventQueue.swift    # Event batching
│   └── EventPersistence.swift # Crash-resilient persistence
├── HTTP/                   # HTTP client, circuit breaker, retry
│   ├── HTTPClient.swift
│   └── CircuitBreaker.swift
├── Error/                  # Error types and codes
│   ├── FlagKitError.swift
│   ├── ErrorCode.swift
│   └── ErrorSanitizer.swift
├── Types/                  # Type definitions
│   ├── EvaluationContext.swift
│   ├── EvaluationResult.swift
│   └── FlagState.swift
└── Utils/                  # Utilities
    └── Security.swift      # PII detection, HMAC signing
```

## Configuration Options

```swift
let options = FlagKitOptions.Builder(apiKey: "sdk_your_api_key")
    .pollingInterval(30)                            // Seconds between polls
    .cacheTTL(300)                                  // Cache time-to-live in seconds
    .cacheEnabled(true)                             // Enable/disable caching
    .eventsEnabled(true)                            // Enable/disable event tracking
    .eventBatchSize(10)                             // Events per batch
    .eventFlushInterval(30)                         // Seconds between flushes
    .timeout(10)                                    // Request timeout in seconds
    .retryAttempts(3)                               // Number of retry attempts
    .localPort(8200)                                // Use local dev server on port 8200
    .build()

let client = try await FlagKit.initialize(options: options)
```

## Local Development

For local development, use the `localPort` option to connect to a local FlagKit server:

```swift
let options = FlagKitOptions.Builder(apiKey: "sdk_your_api_key")
    .localPort(8200)  // Uses http://localhost:8200/api/v1
    .build()

let client = try await FlagKit.initialize(options: options)
```

## Using the Client Directly

```swift
let options = FlagKitOptions(apiKey: "sdk_your_api_key")
let client = FlagKitClient(options: options)

try await client.initialize()

// Wait for initialization
await client.waitForReady()

// Evaluate flags
let result = await client.evaluate(key: "my-feature", defaultValue: .bool(false))
print(result.value)
print(result.reason)
print(result.version)

// Clean up
await client.close()
```

## Evaluation Context

```swift
// Build a context
let context = EvaluationContext(
    userId: "user-123",
    attributes: [
        "email": .string("user@example.com"),
        "plan": .string("enterprise")
    ]
)

// Use with evaluation
let value = await client.getBoolValue("premium-feature", default: false, context: context)

// Private attributes (stripped before sending to server)
let contextWithPrivate = EvaluationContext(
    userId: "user-123",
    attributes: [
        "email": .string("user@example.com"),
        "_internal_id": .string("hidden")  // Underscore prefix = private
    ]
)
```

## Error Handling

```swift
do {
    let client = try await FlagKit.initialize(apiKey: "invalid_key")
} catch let error as FlagKitError {
    print("Error code: \(error.code.rawValue)")
    print("Message: \(error.message)")
    print("Recoverable: \(error.isRecoverable)")
}
```

## API Reference

### Static Methods (FlagKit)

| Method | Description |
|--------|-------------|
| `FlagKit.initialize(options:)` | Initialize the SDK |
| `FlagKit.initialize(apiKey:)` | Initialize with API key |
| `FlagKit.shutdown()` | Shutdown and release resources |
| `FlagKit.isInitialized` | Check if SDK is initialized |
| `FlagKit.identify(userId:attributes:)` | Set user context |
| `FlagKit.resetContext()` | Clear user context |
| `FlagKit.getBoolValue(_:default:)` | Get boolean flag |
| `FlagKit.getStringValue(_:default:)` | Get string flag |
| `FlagKit.getNumberValue(_:default:)` | Get number flag |
| `FlagKit.getIntValue(_:default:)` | Get integer flag |
| `FlagKit.getJsonValue(_:default:)` | Get JSON flag |
| `FlagKit.evaluate(_:defaultValue:)` | Get full evaluation result |
| `FlagKit.track(_:data:)` | Track analytics event |

### Client Methods (FlagKitClient)

| Method | Description |
|--------|-------------|
| `client.initialize()` | Initialize and fetch flags |
| `client.waitForReady()` | Wait for initialization |
| `client.ready` | Check if ready |
| `client.identify(userId:attributes:)` | Set user context |
| `client.resetContext()` | Clear user context |
| `client.getContext()` | Get current context |
| `client.evaluate(key:defaultValue:context:)` | Evaluate a flag |
| `client.getBoolValue(_:default:context:)` | Get boolean value |
| `client.getStringValue(_:default:context:)` | Get string value |
| `client.getNumberValue(_:default:context:)` | Get number value |
| `client.getIntValue(_:default:context:)` | Get integer value |
| `client.getJsonValue(_:default:context:)` | Get JSON value |
| `client.track(_:data:)` | Track an event |
| `client.close()` | Close and release resources |

## Security Features

### PII Detection

The SDK can detect and warn about potential PII (Personally Identifiable Information) in contexts and events:

```swift
// Enable strict PII mode - throws errors instead of warnings
let options = FlagKitOptions.Builder(apiKey: "sdk_...")
    .strictPIIMode(true)
    .build()

// Attributes containing PII will throw FlagKitError
do {
    await client.identify(userId: "user-123", attributes: [
        "email": .string("user@example.com")  // PII detected!
    ])
} catch let error as FlagKitError {
    print("PII error: \(error.message)")
}

// Use private attributes to mark fields as intentionally containing PII
let context = EvaluationContext(
    userId: "user-123",
    attributes: [
        "email": .string("user@example.com"),
        "_email": .bool(true)  // Underscore prefix marks as private
    ]
)
```

### Request Signing

POST requests to the FlagKit API are signed with HMAC-SHA256 for integrity:

```swift
// Enabled by default, can be disabled if needed
let options = FlagKitOptions.Builder(apiKey: "sdk_...")
    .enableRequestSigning(false)  // Disable signing
    .build()
```

### Bootstrap Signature Verification

Verify bootstrap data integrity using HMAC signatures:

```swift
// Create signed bootstrap data
let bootstrap = Security.createBootstrapSignature(
    flags: ["feature-a": true, "feature-b": "value"],
    apiKey: "sdk_your_api_key"
)

// Use signed bootstrap with verification
let options = FlagKitOptions.Builder(apiKey: "sdk_...")
    .bootstrap(bootstrap)
    .bootstrapVerification(BootstrapVerificationConfig(
        enabled: true,
        maxAge: 86_400_000,  // 24 hours in milliseconds
        onFailure: .error    // .warn (default), .error, or .ignore
    ))
    .build()
```

### Cache Encryption

Enable AES-256-GCM encryption for cached flag data:

```swift
let options = FlagKitOptions.Builder(apiKey: "sdk_...")
    .enableCacheEncryption(true)
    .build()
```

### Evaluation Jitter (Timing Attack Protection)

Add random delays to flag evaluations to prevent cache timing attacks:

```swift
let options = FlagKitOptions.Builder(apiKey: "sdk_...")
    .evaluationJitter(EvaluationJitterConfig(
        enabled: true,
        minMs: 5,
        maxMs: 15
    ))
    .build()
```

### Error Sanitization

Automatically redact sensitive information from error messages:

```swift
let options = FlagKitOptions.Builder(apiKey: "sdk_...")
    .errorSanitization(ErrorSanitizationConfig(
        enabled: true,
        preserveOriginal: false  // Set true for debugging
    ))
    .build()
// Errors will have paths, IPs, API keys, and emails redacted
```

## Event Persistence

Enable crash-resilient event persistence to prevent data loss:

```swift
let options = FlagKitOptions.Builder(apiKey: "sdk_...")
    .persistEvents(true)
    .eventStoragePath("/path/to/storage")  // Optional, defaults to app container
    .maxPersistedEvents(10000)             // Optional, default 10000
    .persistenceFlushInterval(1.0)         // Optional, default 1.0 seconds
    .build()
```

Events are written to disk before being sent, and automatically recovered on restart.

## Key Rotation

Support seamless API key rotation:

```swift
let options = FlagKitOptions.Builder(apiKey: "sdk_primary_key")
    .secondaryApiKey("sdk_secondary_key")
    .build()
// SDK will automatically failover to secondary key on 401 errors
```

## All Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `apiKey` | String | Required | API key for authentication |
| `secondaryApiKey` | String? | nil | Secondary key for rotation |
| `pollingInterval` | TimeInterval | 30 | Polling interval in seconds |
| `cacheTTL` | TimeInterval | 300 | Cache TTL in seconds |
| `maxCacheSize` | Int | 1000 | Maximum cache entries |
| `cacheEnabled` | Bool | true | Enable local caching |
| `enableCacheEncryption` | Bool | false | Enable AES-256-GCM encryption |
| `eventsEnabled` | Bool | true | Enable event tracking |
| `eventBatchSize` | Int | 10 | Events per batch |
| `eventFlushInterval` | TimeInterval | 30 | Seconds between flushes |
| `timeout` | TimeInterval | 10 | Request timeout in seconds |
| `retryAttempts` | Int | 3 | Number of retry attempts |
| `circuitBreakerThreshold` | Int | 5 | Failures before circuit opens |
| `circuitBreakerResetTimeout` | TimeInterval | 30 | Seconds before half-open |
| `bootstrap` | [String: Any]? | nil | Initial flag values |
| `bootstrapVerification` | Config | enabled | Bootstrap verification settings |
| `localPort` | Int? | nil | Local development port |
| `strictPIIMode` | Bool | false | Error on PII detection |
| `enableRequestSigning` | Bool | true | Enable request signing |
| `persistEvents` | Bool | false | Enable event persistence |
| `eventStoragePath` | String? | app dir | Event storage directory |
| `maxPersistedEvents` | Int | 10000 | Max persisted events |
| `persistenceFlushInterval` | TimeInterval | 1.0 | Persistence flush interval |
| `evaluationJitter` | Config | disabled | Timing attack protection |
| `errorSanitization` | Config | enabled | Sanitize error messages |

## Thread Safety

All FlagKit types are designed for concurrent access using Swift's actor isolation. The `FlagKitClient` is an actor, ensuring thread-safe operations across all:

- Flag cache access
- Event queue operations
- Context management
- Polling state

## License

MIT License - see [LICENSE](LICENSE) for details.
