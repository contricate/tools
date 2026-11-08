import SwiftUI

struct WallpaperStudioView: View {
    @Environment(AppModel.self) private var model
    @State private var variant: WallpaperVariant = .lock
    @State private var saving = false
    @State private var shareURL: ShareFile?

    var body: some View {
        ThemeScaffold(title: "Wallpaper", previewHeight: 300) { theme in
            HStack(spacing: 16) {
                PhonePreview(theme: theme, battery: model.battery, height: 290, showIcons: true, variant: variant)
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Variant", selection: $variant) {
                        ForEach(WallpaperVariant.allCases) { Text($0 == .lock ? "Lock" : "Home").tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Text("1179 × 2556 px").font(.caption.monospaced()).foregroundStyle(.secondary)
                    Text("Made for iPhone 16").font(.caption2).foregroundStyle(.secondary)
                    Button { Task { await save(theme) } } label: {
                        Label(saving ? "Saving…" : "Save Both to Photos", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(saving)
                    Button {
                        if let d = Exporter.wallpaperPNG(theme, variant: variant) {
                            shareURL = ShareFile(url: Exporter.tempFile(d, name: "\(theme.name) \(variant.label).png"))
                        }
                    } label: { Label("Share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }
                    .buttonStyle(.bordered)
                }
            }
        } content: { $t in
            BackgroundSection(spec: $t.background)
            Section {
                Picker("Decoration", selection: $t.wallpaper.decoration) {
                    ForEach(WallpaperDecoration.allCases) { Text($0.label).tag($0) }
                }
                if t.wallpaper.decoration != .none {
                    ColorRow(title: "Colour", value: $t.wallpaper.decorationColor)
                    SliderRow(title: "Glow", value: $t.wallpaper.decorationGlow)
                    SliderRow(title: "Thickness", value: $t.wallpaper.decorationWidth, range: 0.5...8, format: { String(format: "%.1f", $0) })
                    SliderRow(title: "Fine-tune Position", value: $t.wallpaper.islandOffsetY, range: -6...6, format: { String(format: "%+.1f pt", $0) })
                }
            } header: {
                Text("Top of Screen")
            } footer: {
                Text("Halos, wings and bands are drawn into the wallpaper around the Dynamic Island and status bar area, so the top of your screen looks customised — the real status bar stays Apple's.")
            }
            Section("Overlay Text") {
                TextField("Text on the wallpaper (optional)", text: $t.wallpaper.overlayText, axis: .vertical)
            }
            Section("Home Screen Version") {
                SliderRow(title: "Dim", value: $t.wallpaper.homeDim, range: 0...0.7)
                SliderRow(title: "Blur", value: $t.wallpaper.homeBlur, range: 0...30, format: { "\(Int($0))" })
            }
            Section {
                Label("Photos → open the wallpaper → Share → Use as Wallpaper. Or long-press the Lock Screen → + → Photos.", systemImage: "1.circle")
                Label("Automatic: in Shortcuts, make an automation (e.g. each morning or when a Focus turns on) with “Get Aura Wallpaper” → “Set Wallpaper”.", systemImage: "2.circle")
            } header: { Text("Apply") } footer: { Text("iOS doesn't let apps set your wallpaper directly; the Shortcuts route is Apple's supported way to automate it.") }
        }
        .sheet(item: $shareURL) { f in ShareSheet(items: [f.url]) }
    }

    private func save(_ t: Theme) async {
        saving = true
        defer { saving = false }
        guard let lock = Exporter.wallpaperPNG(t, variant: .lock), let home = Exporter.wallpaperPNG(t, variant: .home) else {
            model.show("Couldn't render the wallpaper")
            return
        }
        do {
            try await Exporter.saveToPhotos([lock, home])
            model.show("Saved Lock & Home wallpapers to Photos")
        } catch {
            model.show(error.localizedDescription)
        }
    }
}

struct ShareFile: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
