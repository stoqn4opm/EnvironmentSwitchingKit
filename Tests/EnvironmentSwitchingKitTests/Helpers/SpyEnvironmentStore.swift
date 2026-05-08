//
//  SpyEnvironmentStore.swift
//  EnvironmentSwitchingKitTests
//
//  In-memory `EnvironmentStore` that records every mutation for assertion.
//  Use when the test cares about *what* was written, not *how* it was
//  persisted (those are covered by EnvironmentStoreTests).
//

import Foundation
@testable import EnvironmentSwitchingKit

final class SpyEnvironmentStore: EnvironmentStore {

    // MARK: - Configurable Initial State

    var loaded: [LoadedEnvironment]

    var selectedID: UUID? {
        didSet { selectedIDWrites.append(selectedID) }
    }

    var hasBeenSeen: Bool

    // MARK: - Recorded Calls

    private(set) var addedEnvironments: [LoadedEnvironment] = []
    private(set) var removedIDs: [UUID] = []
    private(set) var updatedEnvironments: [LoadedEnvironment] = []
    private(set) var selectedIDWrites: [UUID?] = []

    // MARK: - Init

    init(loaded: [LoadedEnvironment] = [],
         selectedID: UUID? = nil,
         hasBeenSeen: Bool = false) {
        self.loaded = loaded
        self.selectedID = selectedID
        self.hasBeenSeen = hasBeenSeen
    }

    // MARK: - EnvironmentStore

    func add(_ environment: LoadedEnvironment) {
        addedEnvironments.append(environment)
        loaded.append(environment)
    }

    func remove(id: UUID) {
        removedIDs.append(id)
        loaded.removeAll { $0.id == id }
    }

    func update(_ environment: LoadedEnvironment) {
        updatedEnvironments.append(environment)
        if let index = loaded.firstIndex(where: { $0.id == environment.id }) {
            loaded[index] = environment
        }
    }
}
