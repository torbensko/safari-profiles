import XCTest
@testable import LauncherCore

final class DefinitionTests: XCTestCase {
    func testIdentitySurvivesEditsAndRoundTrip() throws {
        var d = LauncherDefinition(profileName: "Work", displayName: "Safari — Work", colorHex: "AA22FF")
        let id = d.bundleIdentifier
        d.profileName = "Other"; d.displayName = "Renamed"; d.colorHex = "00FF00"
        XCTAssertEqual(d.bundleIdentifier, id)
        XCTAssertEqual(try JSONDecoder().decode(LauncherDefinition.self, from: JSONEncoder().encode(d)), d)
    }
    func testExactMatchingAndUnicode() throws {
        let names = ["Work", "Workshop", "O’Brien's", "日本語 🦊", "New Window", "Work (2)", "A / B"]
        let titles = names.map { ProfileMenu.title(for: $0) }
        for (index, name) in names.enumerated() { XCTAssertEqual(try ProfileMenu.uniqueIndex(titles: titles, profile: name), index) }
        XCTAssertThrowsError(try ProfileMenu.uniqueIndex(titles: ["New Workshop Window", "New Window", "New Private Window"], profile: "Work"))
        XCTAssertThrowsError(try ProfileMenu.uniqueIndex(titles: ["New Work Window", "New Work Window"], profile: "Work"))
        XCTAssertFalse(ProfileMenu.matches("New work Window", profile: "Work"))
        XCTAssertFalse(ProfileMenu.matches("New Work Window ", profile: "Work"))
    }
    func testSafeFilenamesAndCollisions() throws {
        for name in ["../escape", "../../", "", "a:b/c\\d", "🦊" + String(repeating: "日", count: 120), String(repeating: "👩‍👩‍👧‍👦", count: 48)] {
            let d = LauncherDefinition(profileName: "X", displayName: name, colorHex: "012aBC")
            XCTAssertFalse(d.filename.contains("/")); XCTAssertFalse(d.filename.contains(":")); XCTAssertFalse(d.filename.hasPrefix("."))
            XCTAssertLessThan(d.filename.utf8.count, 256)
        }
        let a = LauncherDefinition(profileName: "Work", displayName: "A/B", colorHex: "000000")
        let b = LauncherDefinition(profileName: "Work", displayName: "A:B", colorHex: "000000")
        XCTAssertNotEqual(a.filename, b.filename); XCTAssertNotEqual(a.bundleIdentifier, b.bundleIdentifier)
    }
    func testValidation() throws {
        let good = LauncherDefinition(profileName: " Work ", displayName: "Safari", colorHex: "abC123")
        XCTAssertNoThrow(try good.validate())
        for profile in ["", "  ", "New\nWindow", String(repeating: "a", count: 121)] {
            var d = good; d.profileName = profile; XCTAssertThrowsError(try d.validate())
        }
        for color in ["#FF0000", "ffffff0", "GGGGGG", "123"] { var d = good; d.colorHex = color; XCTAssertThrowsError(try d.validate()) }
        var future = good; future.schemaVersion = 2; XCTAssertThrowsError(try future.validate())
    }
}
