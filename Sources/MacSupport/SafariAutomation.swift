import AppKit
import ApplicationServices
import LauncherCore
import Darwin

public enum SafariAutomation {
    public static var hasPermission: Bool { AXIsProcessTrusted() }
    public static func openPermissionSettings() {
        // Explicit user action only; never repeatedly request the system prompt on startup.
        AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    @MainActor public static func open(_ definition: LauncherDefinition) async throws {
        try definition.validate()
        guard hasPermission else { throw LauncherError("Allow ‘\(definition.displayName)’ in System Settings → Privacy & Security → Accessibility (called Device control and Data access on some macOS versions), then click the launcher again. Each exported launcher needs its own permission; granting Profile Studio access does not cover it.") }
        // Serialise across all exported apps without a daemon. A crash releases flock automatically.
        let lockURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Safari Profile Launcher/launch.lock")
        try FileManager.default.createDirectory(at: lockURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let fd = Darwin.open(lockURL.path, O_CREAT | O_RDWR | O_NOFOLLOW, 0o600)
        guard fd >= 0 else { throw LauncherError("Could not create the launcher coordination lock.") }
        defer { flock(fd, LOCK_UN); close(fd) }
        let lockDeadline = Date().addingTimeInterval(15)
        while flock(fd, LOCK_EX | LOCK_NB) != 0 {
            guard Date() < lockDeadline else { throw LauncherError("Another profile launcher is still working. Wait for it to finish, then click again.") }
            try await Task.sleep(nanoseconds: 150_000_000)
        }
        guard let safariURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Safari") else { throw LauncherError("Safari is not installed or registered on this Mac.") }
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Safari").first
        let app: NSRunningApplication
        if let running { app = running }
        else {
            let config = NSWorkspace.OpenConfiguration(); config.activates = false; config.createsNewApplicationInstance = false
            app = try await NSWorkspace.shared.openApplication(at: safariURL, configuration: config)
        }
        app.activate(options: [.activateIgnoringOtherApps])
        let ax = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(ax, 1)
        let deadline = Date().addingTimeInterval(12)
        var lastTitles: [String] = []
        var sawMenu = false
        while Date() < deadline {
            if let bar = attribute(ax, kAXMenuBarAttribute) {
                let menus = children(bar)
                if let file = menus.first(where: { string($0, kAXTitleAttribute) == "File" }) {
                    sawMenu = true
                    let commands = descendants(file, depth: 0)
                        .filter { string($0, kAXRoleAttribute) == kAXMenuItemRole && children($0).isEmpty }
                    lastTitles = commands.map { string($0, kAXTitleAttribute) }
                    let matches = commands.filter { ProfileMenu.matches(string($0, kAXTitleAttribute), profile: definition.profileName) }
                    if matches.count > 1 { _ = try ProfileMenu.uniqueIndex(titles: lastTitles, profile: definition.profileName) }
                    if let command = matches.first, bool(command, kAXEnabledAttribute) {
                        // Never retry after dispatch: cannotComplete can mean the action already happened.
                        let result = AXUIElementPerformAction(command, kAXPressAction as CFString)
                        guard result == .success else { throw LauncherError("Safari returned Accessibility error \(result.rawValue) after the window command was sent. It may have opened a window. Check Safari before clicking again; no retry was sent.") }
                        app.activate(options: [.activateIgnoringOtherApps]); return
                    }
                }
            }
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        if sawMenu, !lastTitles.isEmpty { _ = try ProfileMenu.uniqueIndex(titles: lastTitles, profile: definition.profileName)
            throw LauncherError("The profile command exists but is disabled. Dismiss any Safari dialog, then try again.")
        }
        throw LauncherError("Safari’s English File menu was unavailable after 12 seconds. Dismiss any Safari dialogs, check this launcher’s Accessibility permission, and try again. No window command was sent.")
    }
    private static func attribute(_ element: AXUIElement, _ name: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }
    private static func children(_ element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?; AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value)
        return value as? [AXUIElement] ?? []
    }
    private static func string(_ element: AXUIElement, _ name: String) -> String {
        var value: CFTypeRef?; AXUIElementCopyAttributeValue(element, name as CFString, &value)
        return value as? String ?? ""
    }
    private static func bool(_ element: AXUIElement, _ name: String) -> Bool {
        var value: CFTypeRef?; AXUIElementCopyAttributeValue(element, name as CFString, &value)
        return value as? Bool ?? false
    }
    private static func descendants(_ element: AXUIElement, depth: Int) -> [AXUIElement] {
        guard depth < 6 else { return [] }
        return children(element).flatMap { [$0] + descendants($0, depth: depth + 1) }
    }
}
