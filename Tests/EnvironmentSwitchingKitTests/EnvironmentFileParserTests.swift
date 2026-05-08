//
//  EnvironmentFileParserTests.swift
//  EnvironmentSwitchingKitTests
//

import XCTest
@testable import EnvironmentSwitchingKit

final class EnvironmentFileParserTests: XCTestCase {

    private var parser: JSONEnvironmentFileParser!
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        parser = JSONEnvironmentFileParser()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("EnvironmentSwitchingKitTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
        parser = nil
        tempDirectory = nil
        try super.tearDownWithError()
    }

    // MARK: - Helpers

    private func writeFile(name: String, contents: String) throws -> URL {
        let url = tempDirectory.appendingPathComponent(name)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - Happy path

    func test_parse_validJSON_returnsLoadedEnvironment() throws {
        let url = try writeFile(name: "valid.example", contents: """
        {
          "name": "Staging",
          "fields": [
            { "key": "baseURL", "value": "https://staging.example.com" },
            { "key": "version", "value": "v1" }
          ]
        }
        """)

        let env = try parser.parse(url: url)

        XCTAssertEqual(env.name, "Staging")
        XCTAssertEqual(env.fields.count, 2)
        XCTAssertEqual(env.value(forKey: "baseURL"), "https://staging.example.com")
        XCTAssertEqual(env.value(forKey: "version"), "v1")
        XCTAssertFalse(env.isBuiltIn)
        // ID is freshly generated — non-zero UUID.
        XCTAssertNotEqual(env.id, UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
    }

    func test_parse_trimsWhitespaceFromName() throws {
        let url = try writeFile(name: "spaced.example", contents: """
        {
          "name": "   Staging   ",
          "fields": [{ "key": "baseURL", "value": "https://x.com" }]
        }
        """)

        let env = try parser.parse(url: url)

        XCTAssertEqual(env.name, "Staging")
    }

    // MARK: - Error paths

    func test_parse_emptyName_throwsFileError() throws {
        let url = try writeFile(name: "empty-name.example", contents: """
        {
          "name": "",
          "fields": [{ "key": "baseURL", "value": "https://x.com" }]
        }
        """)

        XCTAssertThrowsError(try parser.parse(url: url)) { error in
            XCTAssertTrue(error is EnvironmentFileError)
        }
    }

    func test_parse_whitespaceOnlyName_throwsFileError() throws {
        let url = try writeFile(name: "ws-name.example", contents: """
        {
          "name": "   ",
          "fields": [{ "key": "baseURL", "value": "https://x.com" }]
        }
        """)

        XCTAssertThrowsError(try parser.parse(url: url))
    }

    func test_parse_emptyFields_throwsFileError() throws {
        let url = try writeFile(name: "no-fields.example", contents: """
        { "name": "Staging", "fields": [] }
        """)

        XCTAssertThrowsError(try parser.parse(url: url))
    }

    func test_parse_malformedJSON_throwsFileError() throws {
        let url = try writeFile(name: "broken.example", contents: "{ not json at all")

        XCTAssertThrowsError(try parser.parse(url: url))
    }
}
