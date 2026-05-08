//
//  LoadedEnvironmentTests.swift
//  EnvironmentSwitchingKitTests
//

import XCTest
@testable import EnvironmentSwitchingKit

final class LoadedEnvironmentTests: XCTestCase {

    // MARK: - Helpers

    private func makeEnvironment(id: UUID = UUID(),
                                 name: String = "test",
                                 fields: [LoadedEnvironment.Field],
                                 isBuiltIn: Bool = false) -> LoadedEnvironment {
        LoadedEnvironment(id: id, name: name, fields: fields, isBuiltIn: isBuiltIn)
    }

    // MARK: - contentEquals

    func test_contentEquals_withIdenticalFieldsInDifferentOrder_returnsTrue() {
        let lhs = makeEnvironment(name: "A", fields: [
            .init(key: "baseURL", value: "https://example.com"),
            .init(key: "version", value: "v1")
        ])
        let rhs = makeEnvironment(name: "B", fields: [
            .init(key: "version", value: "v1"),
            .init(key: "baseURL", value: "https://example.com")
        ])
        XCTAssertTrue(lhs.contentEquals(rhs))
    }

    func test_contentEquals_withDifferentFields_returnsFalse() {
        let lhs = makeEnvironment(fields: [.init(key: "baseURL", value: "https://a.com")])
        let rhs = makeEnvironment(fields: [.init(key: "baseURL", value: "https://b.com")])
        XCTAssertFalse(lhs.contentEquals(rhs))
    }

    // MARK: - value(forKey:)

    func test_value_forKey_withExistingKey_returnsValue() {
        let environment = makeEnvironment(fields: [
            .init(key: "baseURL", value: "https://example.com")
        ])
        XCTAssertEqual(environment.value(forKey: "baseURL"), "https://example.com")
    }

    func test_value_forKey_withMissingKey_returnsNil() {
        let environment = makeEnvironment(fields: [
            .init(key: "baseURL", value: "https://example.com")
        ])
        XCTAssertNil(environment.value(forKey: "missing"))
    }
}
