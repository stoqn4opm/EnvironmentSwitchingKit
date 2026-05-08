//
//  EnvironmentFileParser.swift
//  EnvironmentSwitchingKit
//
//  Parses an environment-config JSON file at a given URL into a
//  LoadedEnvironment. Format: `{ name: String, fields: [{ key, value }] }`.
//

import Foundation

public protocol EnvironmentFileParser {
    func parse(url: URL) throws -> LoadedEnvironment
}

// MARK: - Errors

public struct EnvironmentFileError: LocalizedError {
    public let errorDescription: String?
    public init(message: String) { self.errorDescription = message }
}

// MARK: - JSON Implementation

public final class JSONEnvironmentFileParser: EnvironmentFileParser {

    public init() {}

    public func parse(url: URL) throws -> LoadedEnvironment {
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw EnvironmentFileError(message: "Could not read environment file: \(error.localizedDescription)")
        }

        let payload: FilePayload
        do {
            payload = try JSONDecoder().decode(FilePayload.self, from: data)
        } catch {
            throw EnvironmentFileError(message: "Environment file is malformed: \(error.localizedDescription)")
        }

        let trimmedName = payload.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw EnvironmentFileError(message: "Environment file is missing a name.")
        }
        guard !payload.fields.isEmpty else {
            throw EnvironmentFileError(message: "Environment file has no fields.")
        }

        let fields = payload.fields.map {
            LoadedEnvironment.Field(key: $0.key, value: $0.value)
        }
        return LoadedEnvironment(
            id: UUID(),
            name: trimmedName,
            fields: fields,
            isBuiltIn: false)
    }

    // MARK: - File Format

    private struct FilePayload: Decodable {
        let name: String
        let fields: [FieldPayload]
    }

    private struct FieldPayload: Decodable {
        let key: String
        let value: String
    }
}
