import XCTest
import AppKit
import LauncherCore
@testable import MacSupport

final class ExportTests: XCTestCase {
    func testExportReplacementAndFailureSafety() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        // Use a genuine built Mach-O as a fixture; no Safari or permission interaction.
        let executable = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(".build/debug/ProfileLauncher")
        XCTAssertTrue(FileManager.default.fileExists(atPath: executable.path), "Build ProfileLauncher before running export integration tests")
        var definition = LauncherDefinition(profileName: "日本語 O’Brien", displayName: "A/B", colorHex: "EC4899")
        let exported = try BundleExporter.export(definition, executable: executable, directory: root)
        let collision = LauncherDefinition(profileName: "Other", displayName: "A:B", colorHex: "111111")
        let other = try BundleExporter.export(collision, executable: executable, directory: root)
        XCTAssertNotEqual(exported.path, other.path)
        XCTAssertEqual(Bundle(url: other)?.bundleIdentifier, collision.bundleIdentifier)
        let originalIcon = try Data(contentsOf: exported.appendingPathComponent("Contents/Resources/Compass-EC4899.icns"))
        XCTAssertEqual(Bundle(url: exported)?.bundleIdentifier, definition.bundleIdentifier)
        XCTAssertThrowsError(try BundleExporter.export(definition, executable: executable, directory: root))
        definition.colorHex = "22A06B"; definition.displayName = "Renamed"
        let replaced = try BundleExporter.export(definition, executable: executable, directory: root, overwrite: true)
        XCTAssertEqual(exported.resolvingSymlinksInPath().path, replaced.resolvingSymlinksInPath().path)
        let newIcon = try Data(contentsOf: replaced.appendingPathComponent("Contents/Resources/Compass-22A06B.icns"))
        XCTAssertNotEqual(originalIcon, newIcon)
        let decoded = try JSONDecoder().decode(LauncherDefinition.self, from: Data(contentsOf: replaced.appendingPathComponent("Contents/Resources/launcher.json")))
        XCTAssertEqual(decoded, definition)
        XCTAssertThrowsError(try BundleExporter.export(definition, executable: root.appendingPathComponent("missing"), directory: root, overwrite: true))
        XCTAssertEqual(try Data(contentsOf: replaced.appendingPathComponent("Contents/Resources/Compass-22A06B.icns")), newIcon)
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: root.path).contains(where: { $0.hasPrefix(".profile-export") }))
    }
    func testStoreRoundTripAndCorruptionIsNotOverwritten() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DefinitionStore(url: directory.appendingPathComponent("definitions.json"))
        XCTAssertEqual(try store.load(), [])
        let definition = LauncherDefinition(profileName: "Work", displayName: "Work", colorHex: "FFFFFF")
        try store.save([definition]); XCTAssertEqual(try store.load(), [definition])
        let bad = Data("corrupt".utf8); try bad.write(to: store.url)
        XCTAssertThrowsError(try store.load()); XCTAssertEqual(try Data(contentsOf: store.url), bad)
    }
}
