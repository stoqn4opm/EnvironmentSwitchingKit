//
//  EnvironmentApplierTests.swift
//  EnvironmentSwitchingKitTests
//

import XCTest
@testable import EnvironmentSwitchingKit

@MainActor
final class EnvironmentApplierTests: XCTestCase {

    private func makeEnvironment(id: UUID = UUID(), name: String = "Staging") -> LoadedEnvironment {
        LoadedEnvironment(
            id: id,
            name: name,
            fields: [.init(key: "baseURL", value: "https://staging.example.com")],
            isBuiltIn: false)
    }

    // MARK: - Order of operations

    func test_apply_setsSelectedIDOnStore_thenInvokesApplyAction() async {
        let store = SpyEnvironmentStore()
        let env = makeEnvironment()
        var observedSelectedIDAtCallTime: UUID?

        let applier = DefaultEnvironmentApplier(
            store: store,
            applyAction: { @MainActor _ in
                observedSelectedIDAtCallTime = store.selectedID
            })

        await applier.apply(env)

        // The store must already have the new selectedID by the time the
        // brand's applyAction fires — this is the contract that allows the
        // brand to e.g. tear down state without losing track of which env
        // it's switching to.
        XCTAssertEqual(observedSelectedIDAtCallTime, env.id)
    }

    // MARK: - Argument propagation

    func test_apply_passesEnvironmentToApplyAction() async {
        let store = SpyEnvironmentStore()
        let env = makeEnvironment()
        var receivedEnvironment: LoadedEnvironment?

        let applier = DefaultEnvironmentApplier(
            store: store,
            applyAction: { @MainActor environment in
                receivedEnvironment = environment
            })

        await applier.apply(env)

        XCTAssertEqual(receivedEnvironment?.id, env.id)
        XCTAssertEqual(receivedEnvironment?.name, env.name)
    }

    // MARK: - Selected ID is recorded exactly once

    func test_apply_recordsSelectedIDWriteExactlyOnce() async {
        let store = SpyEnvironmentStore()
        let env = makeEnvironment()
        let applier = DefaultEnvironmentApplier(store: store) { @MainActor _ in }

        await applier.apply(env)

        XCTAssertEqual(store.selectedIDWrites, [env.id])
    }
}
