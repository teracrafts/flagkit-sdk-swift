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
    .package(url: "https://github.com/teracrafts/flagkit-sdk-swift.git", from: "1.0.0")
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

## Security

The SDK includes built-in security features that can be enabled through configuration options, including PII detection, request signing, bootstrap signature verification, cache encryption, evaluation jitter for timing attack protection, and error sanitization.

## Thread Safety

All FlagKit types are designed for concurrent access using Swift's actor isolation. The `FlagKitClient` is an actor, ensuring thread-safe operations across all:

- Flag cache access
- Event queue operations
- Context management
- Polling state

## License

MIT License - see [LICENSE](LICENSE) for details.
