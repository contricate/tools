import SwiftUI

struct LockScreenStudioView: View {
    @Environment(AppModel.self) private var model
    @State private var noteText = "Make it yours"
    @State private var noteSubtitle = ""
    @State private var noteSymbol = "sparkles"

    /// Lock Screen presets: a theme + which Aura widgets to place.
    struct LockPreset: Identifiable {
        let id = UUID()
        let name: String
        let themeIndex: Int
        let widgets: [String]
        let note: String
    }

    private let presets: [LockPreset] = [
        LockPreset(name: "Battery Focus", themeIndex: 1, widgets: ["Above clock: Aura Battery (inline)", "Below clock: Aura Battery (round) + Aura Lock Text"], note: "Charge me"),
        LockPreset(name: "Words Clock", themeIndex: 9, widgets: ["Below clock: Aura Clock (rectangular, words)", "Above clock: Aura Lock Text"], note: "Breathe."),
        LockPreset(name: "Neon Night", themeIndex: 3, widgets: ["Below clock: Aura Battery (round) + Aura Clock (round)", "Start the Aura Island"], note: "After hours"),
        LockPreset(name: "Soft Pastel", themeIndex: 7, widgets: ["Above clock: Aura Lock Text", "Below clock: Aura Battery (rectangular)"], note: "Be kind today"),
        LockPreset(name: "Pure Minimal", themeIndex: 0, widgets: ["Above clock: Aura Lock Text only"], note: "Less, but better")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PhonePreview(theme: model.activeTheme, battery: model.battery, height: 380, variant: .lock)
                    .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(title: "Lock Text", subtitle: "Your words above the clock — the closest thing to a custom status bar on the Lock Screen")
                    TextField("Text", text: $noteText)
                        .padding(12).background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                    TextField("Second line (rectangular widget only)", text: $noteSubtitle)
                        .padding(12).background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                    SymbolRow(title: "Symbol", symbol: $noteSymbol)
                        .padding(12).background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                    Button { saveNote() } label: { Label("Save as Lock Text Design", systemImage: "checkmark").frame(maxWidth: .infinity) }
                        .buttonStyle(.borderedProminent)
                    Text("Then: long-press the Lock Screen → Customize → Lock Screen → tap the area above the clock → Aura Lock Text → long-press it to choose this design.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .glassCard()

                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(title: "Presets", subtitle: "Applies the theme, saves its wallpaper, and lists the widgets to add")
                    ForEach(presets) { p in presetRow(p) }
                }

                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(title: "Available Lock Screen widgets")
                    widgetRow("Aura Battery", "Round gauge, rectangular, or inline above the clock")
                    widgetRow("Aura Clock", "Analog face (round) or time in words (rectangular)")
                    widgetRow("Aura Lock Text", "Your own text above the clock or below it")
                    widgetRow("Aura Island", "Your design on the Lock Screen while the Live Activity runs")
                }
                .glassCard()

                LimitNote(text: "iOS draws Lock Screen widgets in a single tint (white or your chosen colour), so photos and theme colours don't show inside them. The clock font and colour can only be changed with Apple's own options (long-press → Customize → tap the time).")
            }
            .padding()
        }
        .background(AuraBackdrop())
        .navigationTitle("Lock Screen")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func presetRow(_ p: LockPreset) -> some View {
        let theme = model.library.themes.indices.contains(p.themeIndex) ? model.library.themes[p.themeIndex] : model.activeTheme
        return HStack(spacing: 14) {
            PhonePreview(theme: theme, battery: model.battery, height: 120, variant: .lock)
            VStack(alignment: .leading, spacing: 6) {
                Text(p.name).font(.headline)
                ForEach(p.widgets, id: \.self) { Text("• \($0)").font(.caption).foregroundStyle(.secondary) }
                Button {
                    model.apply(theme)
                    noteText = p.note
                    saveNote()
                    Task {
                        if let lock = Exporter.wallpaperPNG(theme, variant: .lock) {
                            try? await Exporter.saveToPhotos([lock])
                            model.show("Theme applied & wallpaper saved to Photos")
                        }
                    }
                } label: { Label("Use Preset", systemImage: "sparkles") }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            Spacer(minLength: 0)
        }
        .glassCard(padding: 12)
    }

    private func widgetRow(_ name: String, _ detail: String) -> some View {
        HStack(alignment: .top) {
            Image(systemName: "lock.rectangle.stack").foregroundStyle(.cyan)
            VStack(alignment: .leading) {
                Text(name).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func saveNote() {
        if var d = model.library.widgets.first(where: { $0.name == "Lock Text" }) {
            d.title = noteText; d.subtitle = noteSubtitle; d.symbol = noteSymbol
            model.upsert(d)
        } else {
            model.upsert(WidgetDesign(name: "Lock Text", layout: .quote, title: noteText, subtitle: noteSubtitle, symbol: noteSymbol))
        }
        model.show("Lock Text saved")
    }
}

struct PosterStudioView: View {
    @Environment(AppModel.self) private var model
    @State private var name = "Your Name"
    @State private var photoID: String?
    @State private var themeID: UUID?

    private var theme: Theme { model.library.theme(themeID) ?? model.activeTheme }

    var body: some View {
        Form {
            Section {
                PosterCanvas(theme: theme, name: name, photoID: photoID)
                    .scaleEffect(0.42)
                    .frame(width: DeviceGeometry.screen.width * 0.42, height: DeviceGeometry.screen.height * 0.42)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }
            Section("Poster") {
                TextField("Name", text: $name)
                PhotoField(title: "Photo (optional)", imageID: $photoID, maxSide: 2600)
                Picker("Theme", selection: Binding(get: { themeID ?? model.activeTheme.id }, set: { themeID = $0 })) {
                    ForEach(model.library.themes) { Text($0.name).tag($0.id) }
                }
                Button {
                    Task {
                        guard let d = Exporter.posterPNG(theme, name: name, photoID: photoID) else { return }
                        do { try await Exporter.saveToPhotos([d]); model.show("Poster saved to Photos") }
                        catch { model.show(error.localizedDescription) }
                    }
                } label: { Label("Save to Photos", systemImage: "square.and.arrow.down") }
            }
            Section {
                Label("Contacts → your card (My Card) → Contact Photo & Poster → Edit → + → Photos → pick the saved poster.", systemImage: "person.crop.rectangle")
                Label("For someone else: open their contact → Edit → Add Photo → Photos.", systemImage: "person.2")
            } header: { Text("Apply") } footer: {
                Text("iOS doesn't let apps set Contact Posters directly, so Aura creates the image and you choose it in Contacts. Your own poster is what people see when you call them (on iOS 17+).")
            }
        }
        .auraScreen()
        .navigationTitle("Contact Poster")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ControlsFocusView: View {
    var body: some View {
        List {
            Section {
                row("Apply Theme", "paintpalette.fill", "Switches to a chosen theme (configure after adding).")
                row("Next Aura Theme", "arrow.triangle.2.circlepath", "Cycles through your themes.")
                row("Start Aura Island", "capsule.fill", "Shows your Dynamic Island design.")
                row("Aura Charging Screen", "bolt.batteryblock.fill", "Opens the full-screen charging animation.")
                Text("Add: open Control Center → long-press → Add a Control → Aura. The same controls can go on the Lock Screen (replacing the torch/camera buttons) or the Action button (Settings → Action Button → Controls).")
                    .font(.footnote).foregroundStyle(.secondary)
            } header: { Text("Control Center, Lock Screen & Action Button (iOS 18)") }
            Section {
                Text("1. Settings → Focus → choose a Focus (e.g. Sleep, Work).")
                Text("2. Scroll to Focus Filters → Add Filter → Aura.")
                Text("3. Pick a theme. While that Focus is on, all Aura widgets switch to it; when it ends they switch back.")
                Text("Tip: pair it with a Lock Screen and Home Screen page linked to the same Focus for a full mood switch.")
                    .foregroundStyle(.secondary)
            } header: { Text("Focus Themes") }
            .font(.subheadline)
            Section {
                row("Charging animation", "bolt.fill", "Automation → Charger → Is Connected → Run Immediately → “Open Aura Charging Screen” (or “Show Aura Charging Island”).")
                row("Daily wallpaper", "photo.fill", "Automation → Time of Day → “Next Aura Theme” → “Get Aura Wallpaper” → “Set Wallpaper”.")
                row("Keep the island on", "capsule.fill", "Automation → Time of Day (e.g. 7:00) → “Start Aura Island”. Live Activities last up to 8 hours.")
                row("Low battery look", "battery.25percent", "Automation → Battery Level → Falls Below 20% → “Apply Aura Theme” (a dark theme saves power on OLED).")
            } header: { Text("Shortcuts Automations") }
            Section {
                LimitNote(text: "Apps can add controls to Control Center but can't redesign Control Center itself, its colours or layout.")
            }
        }
        .auraScreen()
        .navigationTitle("Controls & Focus")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ title: String, _ icon: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).frame(width: 28).foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
