import SwiftUI
import AppKit
import LauncherCore
import MacSupport

@MainActor final class StudioModel: ObservableObject {
    @Published var definitions: [LauncherDefinition] = []
    @Published var selection: UUID?
    @Published var draft = LauncherDefinition(profileName: "", displayName: "Safari — ", colorHex: "EC4899")
    @Published var message: String?
    @Published var loadFailed = false
    let store = DefinitionStore()
    init() {
        do { definitions = try store.load(); if let first = definitions.first { select(first.id) } }
        catch { loadFailed = true; message = "Could not load definitions. Your saved file has been left intact. \(error.localizedDescription)" }
    }
    func select(_ id: UUID?) {
        selection = id
        if let value = definitions.first(where: { $0.id == id }) { draft = value }
    }
    func add() { selection = nil; draft = LauncherDefinition(profileName: "", displayName: "Safari — ", colorHex: "EC4899") }
    @discardableResult func save() -> Bool {
        guard !loadFailed else { return false }
        do {
            try draft.validate()
            var updated = definitions
            if let i = updated.firstIndex(where: { $0.id == draft.id }) { updated[i] = draft } else { updated.append(draft) }
            try store.save(updated); definitions = updated; selection = draft.id; return true
        } catch { message = error.localizedDescription; return false }
    }
    func delete() {
        guard let selection, !loadFailed else { return }
        do {
            let updated = definitions.filter { $0.id != selection }
            try store.save(updated); definitions = updated; add()
        } catch { message = error.localizedDescription }
    }
    func export(all: Bool) {
        guard save() else { return }
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false
        panel.canCreateDirectories = true; panel.prompt = "Export here"
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        guard panel.runModal() == .OK, let directory = panel.url else { return }
        guard let binary = Bundle.main.url(forResource: "ProfileLauncher", withExtension: nil) else { message = "Launcher executable is missing. Rebuild Profile Studio using scripts/build.sh."; return }
        var exported: [URL] = []
        do {
            for item in (all ? definitions : [draft]) {
                var overwrite = false
                let destination = try BundleExporter.destination(for: item, in: directory)
                if FileManager.default.fileExists(atPath: destination.path) {
                    let alert = NSAlert(); alert.messageText = "Replace \(item.displayName)?"
                    alert.informativeText = "Update the launcher at \(destination.path). You may need to re-enable its Accessibility permission and re-pin its Dock icon after changing its colour."
                    alert.addButton(withTitle: "Replace"); alert.addButton(withTitle: "Skip")
                    guard alert.runModal() == .alertFirstButtonReturn else { continue }; overwrite = true
                }
                exported.append(try BundleExporter.export(item, executable: binary, directory: directory, overwrite: overwrite))
            }
            if !exported.isEmpty { NSWorkspace.shared.activateFileViewerSelecting(exported)
                message = "Exported \(exported.count) launcher(s). Drag the apps from Finder into the Dock. Open each once to set up its Accessibility permission."
            }
        } catch { message = "\(exported.count) launcher(s) exported before this error: \(error.localizedDescription)" }
    }
}

struct StudioView: View {
    @StateObject private var model = StudioModel()
    @State private var confirmDelete = false
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Your launchers").font(.headline).padding(.horizontal)
                List(selection: Binding(get: { model.selection }, set: { model.select($0) })) {
                    ForEach(model.definitions) { item in
                        HStack(spacing: 10) {
                            Image(nsImage: CompassIcon.image(hex: item.colorHex, size: 64)).resizable().frame(width: 34, height: 34)
                            VStack(alignment: .leading) { Text(item.displayName); Text(item.profileName).font(.caption).foregroundStyle(.secondary) }
                        }.padding(.vertical, 5).tag(item.id)
                    }
                }
                HStack { Button("Add launcher", systemImage: "plus", action: model.add)
                    Spacer(); Button { confirmDelete = true } label: { Image(systemName: "trash") }.disabled(model.selection == nil)
                }.padding(.horizontal)
            }.frame(width: 265).padding(.vertical)
            Divider()
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 20) {
                    Image(nsImage: CompassIcon.image(hex: model.draft.colorHex)).resizable().frame(width: 104, height: 104)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Safari, one profile away.").font(.title2.bold())
                        Text("Create coloured Dock buttons for just the profiles you use.").foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
                Form {
                    TextField("Safari profile", text: $model.draft.profileName)
                    TextField("Launcher name", text: $model.draft.displayName)
                    ColorPicker("Icon colour", selection: Binding(get: { Color(nsColor: CompassIcon.color(model.draft.colorHex)) }, set: { color in
                        if let c = NSColor(color).usingColorSpace(.sRGB) {
                            model.draft.colorHex = String(format: "%02X%02X%02X", Int((c.redComponent*255).rounded()), Int((c.greenComponent*255).rounded()), Int((c.blueComponent*255).rounded()))
                        }
                    }), supportsOpacity: false)
                }
                Text("Enter the exact profile name from Safari Settings → Profiles. Safari’s menus must be in English.").font(.caption).foregroundStyle(.secondary)
                HStack { Button("Save", action: { model.save() }).keyboardShortcut("s"); Spacer()
                    Button("Export all…", action: { model.export(all: true) })
                    Button("Export launcher…", action: { model.export(all: false) }).buttonStyle(.borderedProminent)
                }.disabled(model.loadFailed)
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Set up once, click whenever you need it.").font(.headline)
                    Text("1. Export to your Applications folder.\n2. Open each launcher and allow it in Privacy & Security → Accessibility.\n3. Drag the exported apps into your Dock.")
                    Text("Each click requests a new window in real Safari. These icons are launch buttons; Safari owns the windows and their running indicator. No helper stays running.").foregroundStyle(.secondary)
                    Text("After a colour change, export again. If the Dock shows the old colour, remove that Dock shortcut and drag the updated app back in. macOS may also need permission reapproval.").foregroundStyle(.secondary)
                }.font(.callout)
                Spacer(minLength: 0)
            }.padding(28).frame(minWidth: 480)
        }.frame(minWidth: 800, minHeight: 570)
        .alert("Safari Profile Studio", isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } })) { Button("OK") { model.message = nil } } message: { Text(model.message ?? "") }
        .confirmationDialog("Delete this definition? Exported apps will remain in place.", isPresented: $confirmDelete) { Button("Delete definition", role: .destructive, action: model.delete) }
    }
}

@main struct ProfileStudioApp: App {
    init() {
        if CommandLine.arguments.count == 4, CommandLine.arguments[1] == "--write-icon" {
            do {
                try CompassIcon.writeICNS(hex: CommandLine.arguments[2], to: URL(fileURLWithPath: CommandLine.arguments[3]))
                exit(0)
            } catch { fputs("\(error.localizedDescription)\n", stderr); exit(1) }
        }
        // Reproducible initial setup without UI scripting. Never overwrites an existing export.
        if CommandLine.arguments.count == 6, CommandLine.arguments[1] == "--create" {
            do {
                let args = CommandLine.arguments
                let store = DefinitionStore(); var definitions = try store.load()
                let definition = definitions.first(where: { $0.profileName == args[2] }) ?? LauncherDefinition(profileName: args[2], displayName: args[3], colorHex: args[4])
                guard let executable = Bundle.main.url(forResource: "ProfileLauncher", withExtension: nil) else { throw LauncherError("Run --create from the built app bundle.") }
                let url = try BundleExporter.export(definition, executable: executable, directory: URL(fileURLWithPath: args[5], isDirectory: true))
                if !definitions.contains(where: { $0.id == definition.id }) { definitions.append(definition); try store.save(definitions) }
                print(url.path); exit(0)
            } catch { fputs("\(error.localizedDescription)\n", stderr); exit(1) }
        }
    }
    var body: some Scene {
        WindowGroup("Safari Profile Studio") { StudioView() }
            .windowStyle(.titleBar)
            .commands { CommandGroup(replacing: .newItem) {} }
    }
}
