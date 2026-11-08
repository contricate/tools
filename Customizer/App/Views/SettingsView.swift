import SwiftUI
import WidgetKit
import ActivityKit

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var currentIcon = UIApplication.shared.alternateIconName
    @State private var confirmReset = false

    private let icons: [(String?, String, String)] = [
        (nil, "Preview-AppIcon", "Aura"), ("AppIcon-Neon", "Preview-AppIcon-Neon", "Neon"),
        ("AppIcon-Mono", "Preview-AppIcon-Mono", "Mono"), ("AppIcon-Sunset", "Preview-AppIcon-Sunset", "Sunset"),
        ("AppIcon-Ocean", "Preview-AppIcon-Ocean", "Ocean")
    ]

    var body: some View {
        NavigationStack {
            List {
                Section("Aura's App Icon") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(icons, id: \.1) { name, preview, label in
                                Button {
                                    UIApplication.shared.setAlternateIconName(name) { err in
                                        Task { @MainActor in
                                            if let err { model.show(err.localizedDescription) } else { currentIcon = name }
                                        }
                                    }
                                } label: {
                                    VStack(spacing: 6) {
                                        Image(preview).resizable().frame(width: 60, height: 60)
                                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(currentIcon == name ? Color.accentColor : .clear, lineWidth: 3))
                                        Text(label).font(.caption2).foregroundStyle(.primary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
                Section {
                    NavigationLink { ImportExportView() } label: { Label("Import & Export", systemImage: "arrow.up.arrow.down.square") }
                    NavigationLink { GuidesView() } label: { Label("Help & Installation Guides", systemImage: "book") }
                    NavigationLink { CapabilitiesView() } label: { Label("What iOS Allows", systemImage: "checklist") }
                    NavigationLink { ControlsFocusView() } label: { Label("Controls, Focus & Automations", systemImage: "switch.2") }
                }
                Section {
                    status("App Group (widgets ↔ app)", SharedStore.hasAppGroup, SharedStore.activeGroupID ?? "Not available — widgets use built-in presets")
                    status("Live Activities", IslandController.authorizationEnabled, IslandController.authorizationEnabled ? "Enabled" : "Turn on in Settings → Aura")
                    status("Battery monitoring", !model.battery.isEstimate, model.battery.isEstimate ? "No reading (simulator?)" : "\(Int(model.battery.level * 100))%")
                    Button {
                        WidgetCenter.shared.reloadAllTimelines()
                        model.show("Widgets refreshed")
                    } label: { Label("Refresh All Widgets", systemImage: "arrow.clockwise") }
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    } label: { Label("Open Aura in iOS Settings", systemImage: "gear") }
                } header: { Text("Diagnostics") }
                Section("Fonts") {
                    let fonts = FontRegistry.importedFontNames()
                    if fonts.isEmpty { Text("Import fonts in Studio → Theme → Typography.").foregroundStyle(.secondary) }
                    ForEach(fonts, id: \.self) { Text($0).font(.custom($0, size: 17)) }
                }
                Section {
                    Button("Restore Missing Preset Themes") {
                        for p in Presets.all where !model.library.themes.contains(where: { $0.id == p.id }) {
                            model.library.themes.append(p)
                        }
                        model.save()
                        model.show("Presets restored")
                    }
                    Button("Reset Everything", role: .destructive) { confirmReset = true }
                }
                Section {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    LabeledContent("Designed for", value: "iPhone 16 · iOS 18+")
                }
            }
            .auraScreen()
            .navigationTitle("Settings")
            .confirmationDialog("Reset all themes, widgets and icon packs?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset", role: .destructive) {
                    try? FileManager.default.removeItem(at: SharedStore.libraryURL)
                    model.library = SharedStore.load()
                    model.save()
                    model.show("Reset to presets")
                }
            } message: { Text("Export a backup first if you want to keep your designs.") }
        }
    }

    private func status(_ title: String, _ ok: Bool, _ detail: String) -> some View {
        HStack(alignment: .top) {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill").foregroundStyle(ok ? .green : .orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct ImportExportView: View {
    @Environment(AppModel.self) private var model
    @State private var exporting = false
    @State private var importing = false
    @State private var file = AuraFile(data: Data())
    @State private var selectedThemes: Set<UUID> = []

    var body: some View {
        List {
            Section {
                Button {
                    if let d = AuraBundle.make(themes: model.library.themes.filter { !$0.isPreset }, widgets: model.library.widgets, packs: model.library.iconPacks) {
                        file = AuraFile(data: d)
                        exporting = true
                    }
                } label: { Label("Export All My Designs", systemImage: "square.and.arrow.up") }
                Button { importing = true } label: { Label("Import .aura File", systemImage: "square.and.arrow.down") }
            } footer: {
                Text("Exports your own themes, widget designs, icon packs and their images as one file you can keep in Files/iCloud Drive or send to a friend.")
            }
            Section("Share a Single Theme") {
                ForEach(model.library.themes) { t in
                    Button {
                        if let d = AuraBundle.make(themes: [t], widgets: [], packs: []) {
                            file = AuraFile(data: d)
                            exporting = true
                        }
                    } label: {
                        HStack {
                            Circle().fill(t.accent.color).frame(width: 12)
                            Text(t.name).foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "square.and.arrow.up").foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .auraScreen()
        .navigationTitle("Import & Export")
        .fileExporter(isPresented: $exporting, document: file, contentType: .json, defaultFilename: "Aura Designs.aura") { result in
            if case .success = result { model.show("Exported") }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: AuraFile.readableContentTypes) { result in
            guard case .success(let url) = result else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                var lib = model.library
                let summary = try AuraBundle.merge(data, into: &lib)
                model.library = lib
                model.save()
                model.show(summary)
            } catch {
                model.show("That isn't an Aura design file")
            }
        }
    }
}
