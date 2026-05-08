//
//  LoadedEnvironment.swift
//  EnvironmentSwitchingKit
//
//  Persisted representation of one environment configuration. Brand-agnostic
//  — knows nothing about specific URL keys or built-in defaults. Brands
//  supply their own built-in seed at the store's init.
//

import Foundation

public struct LoadedEnvironment: Identifiable, Equatable {

    public let id: UUID
    public var name: String
    public var fields: [Field]
    public let isBuiltIn: Bool

    public struct Field: Hashable {
        public var key: String
        public var value: String

        public init(key: String, value: String) {
            self.key = key
            self.value = value
        }
    }

    public init(id: UUID, name: String, fields: [Field], isBuiltIn: Bool) {
        self.id = id
        self.name = name
        self.fields = fields
        self.isBuiltIn = isBuiltIn
    }
}

// MARK: - Field Lookup

extension LoadedEnvironment {

    public func value(forKey key: String) -> String? {
        fields.first { $0.key == key }?.value
    }
}

// MARK: - Duplicate Equality

extension LoadedEnvironment {

    /// Two environments are content-equal iff they hold the same set of
    /// `{key, value}` pairs. Name and id are ignored.
    public func contentEquals(_ other: LoadedEnvironment) -> Bool {
        Set(fields) == Set(other.fields)
    }
}

// MARK: - JSON Codable

extension LoadedEnvironment: Codable {

    enum CodingKeys: String, CodingKey {
        case id, name, fields, isBuiltIn
    }
}

extension LoadedEnvironment.Field: Codable { }
