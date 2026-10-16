import AppKit
import LauncherCore

public enum BundleExporter {
    public static func existingDestination(for definition: LauncherDefinition, in directory: URL) throws -> URL? {
        let contents = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        let matches = contents.filter { url in
            guard url.pathExtension == "app", let data = try? Data(contentsOf: url.appendingPathComponent("Contents/Info.plist")),
                  let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { return false }
            return plist["CFBundleIdentifier"] as? String == definition.bundleIdentifier
        }
        guard matches.count <= 1 else { throw LauncherError("Multiple exports of this launcher exist in this folder. Choose a folder with only one copy to update.") }
        return matches.first
    }
    public static func destination(for definition: LauncherDefinition, in directory: URL) throws -> URL {
        if let existing = try existingDestination(for: definition, in: directory) { return existing }
        let clean = directory.appendingPathComponent(LauncherDefinition.safeName(definition.displayName) + ".app")
        return FileManager.default.fileExists(atPath: clean.path) ? directory.appendingPathComponent(definition.filename) : clean
    }
    @discardableResult public static func export(_ definition: LauncherDefinition, executable: URL, directory: URL, overwrite: Bool = false) throws -> URL {
        try definition.validate()
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        // Keep its path stable even when the display name changes, preserving Dock references.
        let destination = try self.destination(for: definition, in: directory)
        let exists = fm.fileExists(atPath: destination.path)
        guard !exists || overwrite else { throw LauncherError("An app already exists at \(destination.path). Confirm replacement in Profile Studio.") }
        let stageRoot = directory.appendingPathComponent(".profile-export-\(UUID().uuidString)")
        let stage = stageRoot.appendingPathComponent(destination.lastPathComponent)
        defer { try? fm.removeItem(at: stageRoot) }
        try fm.createDirectory(at: stage.appendingPathComponent("Contents/MacOS"), withIntermediateDirectories: true)
        let resources = stage.appendingPathComponent("Contents/Resources")
        try fm.createDirectory(at: resources, withIntermediateDirectories: true)
        let binary = stage.appendingPathComponent("Contents/MacOS/ProfileLauncher")
        try fm.copyItem(at: executable, to: binary)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: binary.path)
        try JSONEncoder().encode(definition).write(to: resources.appendingPathComponent("launcher.json"))
        // Content-specific icon name helps Launch Services notice colour edits.
        let iconName = "Compass-\(definition.colorHex.uppercased())"
        try CompassIcon.writeICNS(hex: definition.colorHex, to: resources.appendingPathComponent(iconName + ".icns"))
        let plist: [String: Any] = [
            "CFBundleIdentifier": definition.bundleIdentifier, "CFBundleName": definition.displayName,
            "CFBundleDisplayName": definition.displayName, "CFBundleExecutable": "ProfileLauncher",
            "CFBundlePackageType": "APPL", "CFBundleIconFile": iconName,
            "CFBundleVersion": String(Int(Date().timeIntervalSince1970)), "CFBundleShortVersionString": "1.0",
            "LSMinimumSystemVersion": "13.0", "NSHighResolutionCapable": true,
            "NSAccessibilityUsageDescription": "Open this Safari profile by choosing its New Window menu command."
        ]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            .write(to: stage.appendingPathComponent("Contents/Info.plist"))
        try run("/usr/bin/codesign", ["--force", "--sign", "-", stage.path])
        try run("/usr/bin/codesign", ["--verify", "--strict", stage.path])
        guard Bundle(url: stage)?.bundleIdentifier == definition.bundleIdentifier,
              let icon = NSImage(contentsOf: resources.appendingPathComponent(iconName + ".icns")), icon.isValid else {
            throw LauncherError("The staged launcher failed bundle/icon validation. The previous app was left intact.")
        }
        if exists {
            // Atomic replacement on the same volume. Never delete the destination first.
            _ = try fm.replaceItemAt(destination, withItemAt: stage)
        } else { try fm.moveItem(at: stage, to: destination) }
        NSWorkspace.shared.noteFileSystemChanged(destination.path)
        return destination
    }
    private static func run(_ executable: String, _ arguments: [String]) throws {
        let process = Process(); process.executableURL = URL(fileURLWithPath: executable); process.arguments = arguments
        let errors = Pipe(); process.standardError = errors
        try process.run()
        let data = errors.fileHandleForReading.readDataToEndOfFile(); process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw LauncherError("Signing failed: \(String(decoding: data, as: UTF8.self))")
        }
    }
}
