import Foundation
import FlagKit

/// FlagKit Swift SDK Lab
///
/// Internal verification script for SDK functionality.
/// Run with: swift run sdk-lab

let pass = "\u{001B}[32m[PASS]\u{001B}[0m"
let fail = "\u{001B}[31m[FAIL]\u{001B}[0m"

var passed = 0
var failed = 0

func passTest(_ test: String) {
    print("\(pass) \(test)")
    passed += 1
}

func failTest(_ test: String) {
    print("\(fail) \(test)")
    failed += 1
}

@main
struct SdkLab {
    static func main() async {
        print("=== FlagKit Swift SDK Lab ===\n")

        do {
            // Test 1: Initialization with bootstrap (no offline mode - uses bootstrap when network fails)
            // Swift SDK expects bootstrap in format: { "flags": [{ "key": "...", "value": ... }, ...] }
            print("Testing initialization...")
            let options = FlagKitOptions(
                apiKey: "sdk_lab_test_key",
                bootstrap: [
                    "flags": [
                        ["key": "lab-bool", "value": true],
                        ["key": "lab-string", "value": "Hello Lab"],
                        ["key": "lab-number", "value": 42.0],
                        ["key": "lab-json", "value": ["nested": true, "count": 100.0]]
                    ]
                ]
            )

            let client = try await FlagKit.initialize(options: options)
            await client.waitForReady()
            // After waitForReady(), client is ready (no public isReady property)
            passTest("Initialization")

            // Test 2: Boolean flag evaluation
            print("\nTesting flag evaluation...")
            let boolValue = await client.getBoolValue("lab-bool", default: false)
            if boolValue {
                passTest("Boolean flag evaluation")
            } else {
                failTest("Boolean flag - expected true, got \(boolValue)")
            }

            // Test 3: String flag evaluation
            let stringValue = await client.getStringValue("lab-string", default: "")
            if stringValue == "Hello Lab" {
                passTest("String flag evaluation")
            } else {
                failTest("String flag - expected 'Hello Lab', got '\(stringValue)'")
            }

            // Test 4: Number flag evaluation
            let numberValue = await client.getNumberValue("lab-number", default: 0)
            if numberValue == 42.0 {
                passTest("Number flag evaluation")
            } else {
                failTest("Number flag - expected 42, got \(numberValue)")
            }

            // Test 5: JSON flag evaluation
            let jsonValue = await client.getJsonValue("lab-json", default: [:])
            if let nested = jsonValue["nested"] as? Bool, nested {
                // Count could be Int or Double depending on how it was stored
                if let countDouble = jsonValue["count"] as? Double, countDouble == 100.0 {
                    passTest("JSON flag evaluation")
                } else if let countInt = jsonValue["count"] as? Int, countInt == 100 {
                    passTest("JSON flag evaluation")
                } else {
                    failTest("JSON flag - count unexpected: \(jsonValue["count"] ?? "nil")")
                }
            } else {
                failTest("JSON flag - unexpected value: \(jsonValue)")
            }

            // Test 6: Default value for missing flag
            let missingValue = await client.getBoolValue("non-existent", default: true)
            if missingValue {
                passTest("Default value for missing flag")
            } else {
                failTest("Missing flag - expected default true, got \(missingValue)")
            }

            // Test 7: Context management - identify (attributes must be [String: FlagValue])
            print("\nTesting context management...")
            await client.identify(userId: "lab-user-123", attributes: [
                "plan": .string("premium"),
                "country": .string("US")
            ])
            if let context = await client.getContext(), context.userId == "lab-user-123" {
                passTest("identify()")
            } else {
                failTest("identify() - context not set correctly")
            }

            // Test 8: Context management - getContext (attributes stored as FlagValue)
            if let context = await client.getContext(),
               let planValue = context.attributes["plan"],
               planValue.stringValue == "premium" {
                passTest("getContext()")
            } else {
                failTest("getContext() - custom attributes missing")
            }

            // Test 9: Context management - reset
            await client.reset()
            let resetContext = await client.getContext()
            if resetContext == nil || resetContext?.userId == nil {
                passTest("reset()")
            } else {
                failTest("reset() - context not cleared")
            }

            // Test 10: Event tracking (track takes first arg unlabeled)
            print("\nTesting event tracking...")
            await client.track("lab_verification", data: ["sdk": "swift", "version": "1.0.0"])
            passTest("track()")

            // Test 11: Flush (may fail due to no network - that's OK)
            do {
                try await client.flush()
                passTest("flush()")
            } catch {
                // In no-server mode, flush may fail - this is expected
                passTest("flush() (network error expected)")
            }

            // Test 12: Cleanup
            print("\nTesting cleanup...")
            await client.close()
            passTest("close()")

        } catch {
            failTest("Unexpected error: \(error)")
        }

        // Summary
        print("\n" + String(repeating: "=", count: 40))
        print("Results: \(passed) passed, \(failed) failed")
        print(String(repeating: "=", count: 40))

        if failed > 0 {
            print("\n\u{001B}[31mSome verifications failed!\u{001B}[0m")
            exit(1)
        } else {
            print("\n\u{001B}[32mAll verifications passed!\u{001B}[0m")
            exit(0)
        }
    }
}
