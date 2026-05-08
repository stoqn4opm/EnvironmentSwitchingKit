//
//  EnvironmentStore.swift
//  EnvironmentSwitchingKit
//
//  Persists the user-imported environments, the current selection, and the
//  shake-to-open unlock flag. The built-in entry is injected at read time
//  and never written to disk; brands supply it (and the UserDefaults key
//  prefix) at init.
//

import Foundation

public protocol EnvironmentStore: AnyObject {
    var loaded: [LoadedEnvironment] { get }
    var selectedID: UUID? { get set }
    var hasBeenSeen: Bool { get set }
    func add(_ environment: LoadedEnvironment)
    func remove(id: UUID)
    func update(_ environment: LoadedEnvironment)
}

// MARK: - UserDefaults Implementation

public final class UserDefaultsEnvironmentStore: EnvironmentStore {

    private struct Keys {
        let list: String
        let selectedID: String
        let hasBeenSeen: String

        init(prefix: String) {
            list = "\(prefix).list"
            selectedID = "\(prefix).selectedID"
            hasBeenSeen = "\(prefix).hasBeenSeen"
        }
    }

    private let userDefaults: UserDefaults
    private let keys: Keys
    private let builtIn: LoadedEnvironment

    public init(userDefaults: UserDefaults = .standard,
                keyPrefix: String,
                builtIn: LoadedEnvironment) {
        self.userDefaults = userDefaults
        self.keys = Keys(prefix: keyPrefix)
        self.builtIn = builtIn
    }

    public var loaded: [LoadedEnvironment] {
        [builtIn] + readUserImported()
    }

    public var selectedID: UUID? {
        get {
            guard let raw = userDefaults.string(forKey: keys.selectedID),
                  let parsed = UUID(uuidString: raw) else {
                return builtIn.id
            }
            return parsed
        }
        set {
            if let value = newValue {
                userDefaults.set(value.uuidString, forKey: keys.selectedID)
            } else {
                userDefaults.removeObject(forKey: keys.selectedID)
            }
        }
    }

    public var hasBeenSeen: Bool {
        get { userDefaults.bool(forKey: keys.hasBeenSeen) }
        set { userDefaults.set(newValue, forKey: keys.hasBeenSeen) }
    }

    public func add(_ environment: LoadedEnvironment) {
        guard !environment.isBuiltIn else { return }
        var list = readUserImported()
        list.append(environment)
        writeUserImported(list)
    }

    public func remove(id: UUID) {
        guard id != builtIn.id else { return }
        var list = readUserImported()
        list.removeAll { $0.id == id }
        writeUserImported(list)
    }

    public func update(_ environment: LoadedEnvironment) {
        guard !environment.isBuiltIn else { return }
        var list = readUserImported()
        guard let index = list.firstIndex(where: { $0.id == environment.id }) else { return }
        list[index] = environment
        writeUserImported(list)
    }

    // MARK: - Private

    private func readUserImported() -> [LoadedEnvironment] {
        guard let data = userDefaults.data(forKey: keys.list) else { return [] }
        let decoder = JSONDecoder()
        // Try the versioned envelope first; fall back to a bare array for any
        // pre-versioning persisted data so devs upgrading mid-branch don't
        // lose their imported environments.
        if let envelope = try? decoder.decode(StoredEnvironmentsV1.self, from: data) {
            return envelope.environments.filter { !$0.isBuiltIn }
        }
        if let bare = try? decoder.decode([LoadedEnvironment].self, from: data) {
            return bare.filter { !$0.isBuiltIn }
        }
        return []
    }

    private func writeUserImported(_ list: [LoadedEnvironment]) {
        let envelope = StoredEnvironmentsV1(environments: list)
        guard let data = try? JSONEncoder().encode(envelope) else { return }
        userDefaults.set(data, forKey: keys.list)
    }
}

// MARK: - Versioned Storage Envelope

private struct StoredEnvironmentsV1: Codable {
    var version: Int = 1
    var environments: [LoadedEnvironment]
}
