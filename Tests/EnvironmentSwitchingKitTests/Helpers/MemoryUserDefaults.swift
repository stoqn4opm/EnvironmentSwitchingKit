//
//  MemoryUserDefaults.swift
//  EnvironmentSwitchingKitTests
//
//  Per-test-isolated UserDefaults instance backed by a unique suite name.
//  Each call to `make()` returns a fresh, empty UserDefaults that won't
//  pollute the standard defaults or bleed between tests. Call `tearDown` to
//  clear the suite at the end of a test.
//

import Foundation

enum MemoryUserDefaults {

    /// Returns a fresh `UserDefaults` instance whose suite is unique per call,
    /// guaranteed to start empty. Caller is responsible for invoking
    /// `tearDown(_:)` (typically in XCTestCase.tearDown) to reset its state.
    static func make() -> UserDefaults {
        let suite = "EnvironmentSwitchingKitTests.\(UUID().uuidString)"
        // Force-creating a UserDefaults with a brand-new suite name returns
        // an empty store; UserDefaults(suiteName:) only fails for the
        // reserved system suite, which we never collide with.
        guard let defaults = UserDefaults(suiteName: suite) else {
            preconditionFailure("Could not create UserDefaults suite \(suite)")
        }
        return defaults
    }

    static func tearDown(_ defaults: UserDefaults) {
        // Clear every key the tests may have written. Iterating
        // dictionaryRepresentation() avoids needing to know suite-specific
        // keys ahead of time.
        for key in defaults.dictionaryRepresentation().keys {
            defaults.removeObject(forKey: key)
        }
    }
}
