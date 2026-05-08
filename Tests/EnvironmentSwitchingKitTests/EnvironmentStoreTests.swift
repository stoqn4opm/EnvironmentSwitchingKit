//
//  EnvironmentStoreTests.swift
//  EnvironmentSwitchingKitTests
//

import XCTest
@testable import EnvironmentSwitchingKit

final class EnvironmentStoreTests: XCTestCase {

    private var defaults: UserDefaults!
    private var builtIn: LoadedEnvironment!

    override func setUp() {
        super.setUp()
        defaults = MemoryUserDefaults.make()
        builtIn = LoadedEnvironment(
            id: UUID(),
            name: "Production",
            fields: [.init(key: "baseURL", value: "https://example.com")],
            isBuiltIn: true)
    }

    override func tearDown() {
        MemoryUserDefaults.tearDown(defaults)
        defaults = nil
        builtIn = nil
        super.tearDown()
    }

    private func makeStore() -> UserDefaultsEnvironmentStore {
        UserDefaultsEnvironmentStore(
            userDefaults: defaults,
            keyPrefix: "test.environments",
            builtIn: builtIn)
    }

    private func makeUserEnv(name: String = "Staging") -> LoadedEnvironment {
        LoadedEnvironment(
            id: UUID(),
            name: name,
            fields: [.init(key: "baseURL", value: "https://staging.example.com")],
            isBuiltIn: false)
    }

    // MARK: - add / remove / update

    func test_add_persistsAndShowsInLoaded() {
        let store = makeStore()
        let env = makeUserEnv()

        store.add(env)

        // A fresh store reading the same defaults must see the persisted env.
        let reloaded = makeStore()
        XCTAssertTrue(reloaded.loaded.contains { $0.id == env.id })
    }

    func test_add_withBuiltInFlag_isIgnored() {
        let store = makeStore()
        let bogus = LoadedEnvironment(
            id: UUID(),
            name: "FakeBuiltIn",
            fields: [.init(key: "baseURL", value: "https://hack.com")],
            isBuiltIn: true)

        store.add(bogus)

        // Reload to verify nothing was persisted (the in-memory store always
        // injects the legitimate built-in regardless).
        let reloaded = makeStore()
        XCTAssertFalse(reloaded.loaded.contains { $0.id == bogus.id })
    }

    func test_remove_byID_filtersFromLoaded() {
        let store = makeStore()
        let env = makeUserEnv()
        store.add(env)

        store.remove(id: env.id)

        let reloaded = makeStore()
        XCTAssertFalse(reloaded.loaded.contains { $0.id == env.id })
    }

    func test_remove_builtInID_isIgnored() {
        let store = makeStore()

        store.remove(id: builtIn.id)

        // Built-in is always re-injected at read time.
        XCTAssertTrue(store.loaded.contains { $0.id == builtIn.id })
    }

    func test_update_modifiesExistingByID() {
        let store = makeStore()
        let env = makeUserEnv(name: "Staging")
        store.add(env)

        var renamed = env
        renamed.name = "Staging-2"
        store.update(renamed)

        let reloaded = makeStore()
        XCTAssertEqual(reloaded.loaded.first(where: { $0.id == env.id })?.name, "Staging-2")
    }

    // MARK: - loaded

    func test_loaded_alwaysPrependsBuiltIn() {
        let store = makeStore()
        store.add(makeUserEnv(name: "A"))
        store.add(makeUserEnv(name: "B"))

        XCTAssertEqual(store.loaded.first?.id, builtIn.id)
    }

    // MARK: - selectedID

    func test_selectedID_defaultsToBuiltInID_whenNothingPersisted() {
        let store = makeStore()
        XCTAssertEqual(store.selectedID, builtIn.id)
    }

    func test_selectedID_writesAndRoundTripsAsUUID() {
        let store = makeStore()
        let id = UUID()

        store.selectedID = id

        let reloaded = makeStore()
        XCTAssertEqual(reloaded.selectedID, id)
    }

    // MARK: - Versioned Storage Envelope

    func test_versionedEnvelope_writesAndReadsBack() {
        let store = makeStore()
        let env = makeUserEnv()
        store.add(env)

        // The on-disk payload must be the v1 envelope, not a bare array.
        guard let data = defaults.data(forKey: "test.environments.list") else {
            XCTFail("List key not present")
            return
        }
        struct Probe: Decodable { let version: Int }
        let probe = try? JSONDecoder().decode(Probe.self, from: data)
        XCTAssertEqual(probe?.version, 1)

        // Round-trip read still works.
        let reloaded = makeStore()
        XCTAssertTrue(reloaded.loaded.contains { $0.id == env.id })
    }

    func test_versionedEnvelope_fallsBackToBareArrayDecode() throws {
        // Pre-seed legacy bare-array encoding to simulate data from before
        // the versioning envelope was introduced.
        let legacy = [makeUserEnv(name: "Legacy")]
        let legacyData = try JSONEncoder().encode(legacy)
        defaults.set(legacyData, forKey: "test.environments.list")

        let store = makeStore()
        XCTAssertTrue(store.loaded.contains { $0.name == "Legacy" })
    }
}
