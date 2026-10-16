import AppKit
import LauncherCore
import MacSupport

final class LauncherDelegate: NSObject, NSApplicationDelegate {
    private var busy = false
    private var pending = 0
    func applicationDidFinishLaunching(_ notification: Notification) { launch() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if busy { pending += 1 } else { launch() }; return false
    }
    func launch() {
        guard !busy else { return }; busy = true
        Task { @MainActor in
            do {
                guard let url = Bundle.main.url(forResource: "launcher", withExtension: "json") else { throw LauncherError("The bundled launcher configuration is missing. Re-export this app from Profile Studio.") }
                let definition = try JSONDecoder().decode(LauncherDefinition.self, from: Data(contentsOf: url))
                try await SafariAutomation.open(definition)
                busy = false
                if pending > 0 { pending -= 1; launch() } else { NSApp.terminate(nil) }
            } catch {
                NSApp.setActivationPolicy(.regular); NSApp.activate(ignoringOtherApps: true)
                let alert = NSAlert(); alert.messageText = "Couldn’t open Safari profile"; alert.informativeText = error.localizedDescription
                alert.addButton(withTitle: "OK")
                if !SafariAutomation.hasPermission { alert.addButton(withTitle: "Open Permission Settings") }
                if alert.runModal() == .alertSecondButtonReturn { SafariAutomation.openPermissionSettings() }
                NSApp.terminate(nil)
            }
        }
    }
}
let app = NSApplication.shared
let delegate = LauncherDelegate(); app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
