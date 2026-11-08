import SwiftUI
import UniformTypeIdentifiers

struct ThemeEditorView: View {
    @Environment(AppModel.self) private var model
    let themeID: UUID
    @State private var previewMode: WallpaperVariant = .home
    @State private var importingFont = false
    @State private var fontError: String?

    var body: some View {
        ThemeScaffold(title: "Theme", initialThemeID: themeID, previewHeight: 280) { theme in
            HStack(spacing: 16) {
                PhonePreview(theme: theme, battery: model.battery, height: 260, variant: previewMode)
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Preview", selection: $previewMode) {
                        ForEach(WallpaperVariant.allCases) { Text($0 == .home ? "Home" : "Lock").tag($0) }
                    }
                    .pickerStyle(.segmented)
                    BatteryGraphic(theme: theme, battery: model.battery, size: 54)
                    ClockGraphic(theme: theme, date: .now, size: 34, showDate: false)
                    IconTile(spec: theme.icon, symbol: "sparkles", size: 46)
                }
                .frame(maxWidth: .infinity)
            }
        } content: { $t in
            Section("Name") {
                TextField("Theme name", text: $t.name)
                TextField("Mood (e.g. Calm, Hype)", text: $t.mood)
            }
            BackgroundSection(spec: $t.background)
            Section("Colours") {
                ColorRow(title: "Accent", value: $t.accent)
                ColorRow(title: "Text", value: $t.text)
                ColorRow(title: "Secondary Text", value: $t.secondaryText)
            }
            Section {
                Picker("Font", selection: $t.type.design) {
                    ForEach(FontDesignChoice.allCases) { Text($0.label).tag($0) }
                }
                if t.type.design == .custom {
                    let names = FontRegistry.importedFontNames()
                    if names.isEmpty {
                        Text("No fonts imported yet.").foregroundStyle(.secondary)
                    } else {
                        Picker("Imported Font", selection: Binding(get: { t.type.customFontName ?? names[0] }, set: { t.type.customFontName = $0 })) {
                            ForEach(names, id: \.self) { Text($0).font(.custom($0, size: 16)).tag($0) }
                        }
                    }
                }
                Button { importingFont = true } label: { Label("Import Font (.ttf / .otf)", systemImage: "textformat") }
                Stepper("Weight: \(weightName(t.type.weight))", value: $t.type.weight, in: 1...9)
                SliderRow(title: "Letter Spacing", value: $t.type.tracking, range: -2...8, format: { String(format: "%.1f", $0) })
                if let fontError { Text(fontError).font(.caption).foregroundStyle(.red) }
            } header: {
                Text("Typography")
            } footer: {
                Text("Fonts apply inside Aura's widgets, island and wallpapers. iOS doesn't allow changing the system font or the Lock Screen clock beyond Apple's options.")
            }
            Section("Shape & Effects") {
                SliderRow(title: "Corner Radius", value: $t.cornerRadius, range: 0...40, format: { "\(Int($0))" })
                SliderRow(title: "Glass", value: $t.glass)
                SliderRow(title: "Border", value: $t.borderWidth, range: 0...4, format: { String(format: "%.1f", $0) })
                ColorRow(title: "Border Colour", value: $t.borderColor)
            }
            Section("Clock") {
                Picker("Style", selection: $t.clock.style) {
                    ForEach(ClockStyle.allCases) { Text($0.label).tag($0) }
                }
                Toggle("24-Hour", isOn: $t.clock.use24h)
                Toggle("Show Date", isOn: $t.clock.showDate)
            }
            IconStyleSection(spec: $t.icon)
            Section("Go further") {
                NavigationLink(value: StudioRoute.battery) { Label("Battery & Charging Styles", systemImage: "battery.100.bolt") }
                NavigationLink(value: StudioRoute.island) { Label("Dynamic Island", systemImage: "capsule.fill") }
                NavigationLink(value: StudioRoute.wallpaper) { Label("Wallpaper & Island Halo", systemImage: "photo") }
            }
            Section {
                Button {
                    let copy = model.duplicate(t)
                    model.show("Duplicated as “\(copy.name)”")
                } label: { Label("Duplicate Theme", systemImage: "plus.square.on.square") }
            }
        }
        .fileImporter(isPresented: $importingFont, allowedContentTypes: [.font, UTType(filenameExtension: "ttf") ?? .data, UTType(filenameExtension: "otf") ?? .data]) { result in
            if case .success(let url) = result {
                do {
                    let names = try FontRegistry.importFont(from: url)
                    fontError = nil
                    model.show("Imported \(names.first ?? "font")")
                } catch {
                    fontError = "That file isn't a usable font."
                }
            }
        }
    }

    private func weightName(_ w: Int) -> String {
        ["", "Ultralight", "Thin", "Light", "Regular", "Medium", "Semibold", "Bold", "Heavy", "Black"][max(1, min(9, w))]
    }
}

struct BackgroundSection: View {
    @Binding var spec: BackgroundSpec

    var body: some View {
        Section("Background") {
            Picker("Type", selection: $spec.kind) {
                ForEach(BackgroundSpec.Kind.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            switch spec.kind {
            case .solid:
                ColorRow(title: "Colour", value: $spec.color)
            case .gradient:
                Picker("Gradient", selection: $spec.gradientKind) {
                    ForEach(GradientKind.allCases) { Text($0.label).tag($0) }
                }
                ForEach(spec.colors.indices, id: \.self) { i in
                    HStack {
                        ColorRow(title: "Colour \(i + 1)", value: $spec.colors[i])
                        if spec.colors.count > 2 {
                            Button(role: .destructive) { spec.colors.remove(at: i) } label: { Image(systemName: "minus.circle.fill") }
                                .buttonStyle(.borderless)
                        }
                    }
                }
                if spec.colors.count < 5 {
                    Button { spec.colors.append(spec.colors.last ?? .white) } label: { Label("Add Colour", systemImage: "plus") }
                }
                SliderRow(title: "Angle", value: $spec.angle, range: 0...360, format: { "\(Int($0))°" })
            case .photo:
                PhotoField(title: "Choose Photo", imageID: $spec.photoID, maxSide: 2600)
                SliderRow(title: "Blur", value: $spec.blur, range: 0...30, format: { "\(Int($0))" })
                SliderRow(title: "Saturation", value: $spec.saturation, range: 0...2)
            }
            SliderRow(title: "Dim", value: $spec.dim, range: 0...0.8)
            SliderRow(title: "Film Grain", value: $spec.grain, range: 0...1)
        }
    }
}

struct IconStyleSection: View {
    @Binding var spec: IconSpec
    var body: some View {
        Section("Icon Style") {
            Picker("Shape", selection: $spec.shape) {
                ForEach(IconShape.allCases) { Text($0.label).tag($0) }
            }
            Toggle("Gradient", isOn: $spec.useGradient)
            ColorRow(title: "Background", value: $spec.background)
            if spec.useGradient { ColorRow(title: "Background 2", value: $spec.background2) }
            ColorRow(title: "Glyph", value: $spec.glyph)
            SliderRow(title: "Glyph Size", value: $spec.glyphScale, range: 0.25...0.8)
            Toggle("Glass Shine", isOn: $spec.glass)
            Toggle("Glow Border", isOn: $spec.showBorder)
        }
    }
}
