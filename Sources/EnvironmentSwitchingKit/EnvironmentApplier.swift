//
//  EnvironmentApplier.swift
//  EnvironmentSwitchingKit
//
//  Persists the selected environment and runs a brand-supplied apply action
//  (typically: swap the live Environment + restart the app). The applier
//  itself never touches the brand's Environment type — that lives entirely
//  inside the injected closure.
//

import Foundation

public protocol EnvironmentApplier {
    @MainActor
    func apply(_ environment: LoadedEnvironment) async
}

// MARK: - Default Implementation

public final class DefaultEnvironmentApplier: EnvironmentApplier {

    private let store: EnvironmentStore
    private let applyAction: @MainActor (LoadedEnvironment) async -> Void

    public init(
        store: EnvironmentStore,
        applyAction: @escaping @MainActor (LoadedEnvironment) async -> Void) {
            self.store = store
            self.applyAction = applyAction
    }

    @MainActor
    public func apply(_ environment: LoadedEnvironment) async {
        store.selectedID = environment.id
        await applyAction(environment)
    }
}
