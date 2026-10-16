import Foundation

public struct LauncherDefinition: Codable, Identifiable, Equatable {
    public var id: UUID
    public var profileName: String
    public var displayName: String
    public var colorHex: String
    public var schemaVersion: Int = 1

    public init(id: UUID = UUID(), profileName: String, displayName: String, colorHex: String) {
        self.id = id; self.profileName = profileName; self.displayName = displayName; self.colorHex = colorHex
    }
    public var bundleIdentifier: String { "local.safari-profile-launcher.profile.\(id.uuidString.lowercased())" }
    // Identity suffix prevents collisions on case-insensitive filesystems and after sanitising.
    public var filename: String { "\(Self.safeName(displayName))—\(id.uuidString.lowercased()).app" }
    public static func safeName(_ name: String) -> String {
        let banned = CharacterSet.controlCharacters.union(CharacterSet(charactersIn: "/:\\"))
        let clean = name.unicodeScalars.map { banned.contains($0) ? "-" : String($0) }.joined()
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
        var bounded = ""
        for character in clean.prefix(48) {
            guard bounded.utf8.count + String(character).utf8.count <= 160 else { break }
            bounded.append(character)
        }
        return bounded.isEmpty ? "Safari Profile" : bounded
    }
    public func validate() throws {
        guard schemaVersion == 1 else { throw LauncherError("This launcher uses an unsupported configuration version. Re-export it with Profile Studio.") }
        for (label, value) in [("Safari profile name", profileName), ("Launcher name", displayName)] {
            guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  value.count <= 120, value.rangeOfCharacter(from: .controlCharacters) == nil else {
                throw LauncherError("\(label) must contain 1–120 characters and no control characters.")
            }
        }
        guard colorHex.count == 6, colorHex.allSatisfy({ $0.isASCII && $0.isHexDigit }) else {
            throw LauncherError("Choose a valid six-digit RGB icon colour.")
        }
    }
}
public struct LauncherError: LocalizedError {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}
public enum ProfileMenu {
    public static func title(for profile: String) -> String { "New \(profile) Window" }
    public static func matches(_ title: String, profile: String) -> Bool {
        title == self.title(for: profile)
    }
    public static func uniqueIndex(titles: [String], profile: String) throws -> Int {
        let matches = titles.indices.filter { self.matches(titles[$0], profile: profile) }
        guard matches.count == 1 else {
            throw LauncherError(matches.isEmpty
                ? "Safari has no exact ‘\(title(for: profile))’ command. Check the profile’s spelling in Safari Settings → Profiles. This version requires Safari’s English menus."
                : "Safari has multiple ‘\(title(for: profile))’ commands. Nothing was opened; give the profiles distinct names.")
        }
        return matches[0]
    }
}
