import Foundation
import LauncherCore

public final class DefinitionStore {
    public let url: URL
    public init(url: URL? = nil) {
        self.url = url ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Safari Profile Launcher/definitions.json")
    }
    public func load() throws -> [LauncherDefinition] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let result = try JSONDecoder().decode([LauncherDefinition].self, from: Data(contentsOf: url))
        for definition in result { try definition.validate() }
        guard Set(result.map(\.id)).count == result.count else { throw LauncherError("Duplicate launcher identities in \(url.path). Restore your definitions backup.") }
        return result
    }
    public func save(_ definitions: [LauncherDefinition]) throws {
        for definition in definitions { try definition.validate() }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(definitions).write(to: url, options: .atomic)
    }
}
