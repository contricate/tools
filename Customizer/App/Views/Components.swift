import SwiftUI
import PhotosUI

// MARK: - App chrome

/// Deep, softly lit background used behind every screen.
struct AuraBackdrop: View {
    var body: some View {
        ZStack {
            Color(red: 0.035, green: 0.035, blue: 0.055)
            RadialGradient(colors: [Color(red: 0.36, green: 0.22, blue: 0.8).opacity(0.35), .clear],
                           center: .topLeading, startRadius: 10, endRadius: 520)
            RadialGradient(colors: [Color(red: 0.0, green: 0.55, blue: 0.75).opacity(0.18), .clear],
                           center: .bottomTrailing, startRadius: 10, endRadius: 520)
        }
        .ignoresSafeArea()
    }
}

struct GlassCard: ViewModifier {
    var padding: CGFloat = 16
    var radius: CGFloat = 22
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color.white.opacity(0.055))
                    .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(LinearGradient(colors: [.white.opacity(0.16), .white.opacity(0.03)], startPoint: .top, endPoint: .bottom), lineWidth: 1))
            )
    }
}

extension View {
    func glassCard(padding: CGFloat = 16, radius: CGFloat = 22) -> some View { modifier(GlassCard(padding: padding, radius: radius)) }

    /// Standard screen chrome: backdrop + hidden list background.
    func auraScreen() -> some View {
        self.scrollContentBackground(.hidden).background(AuraBackdrop())
    }
}

struct SectionLabel: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased()).font(.caption.weight(.heavy)).tracking(1.4).foregroundStyle(.white.opacity(0.55))
            if let subtitle { Text(subtitle).font(.footnote).foregroundStyle(.white.opacity(0.45)) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct Pill: View {
    let text: String
    var icon: String? = nil
    var color: Color = .accentColor
    var body: some View {
        HStack(spacing: 4) {
            if let icon { Image(systemName: icon) }
            Text(text)
        }
        .font(.caption2.weight(.bold))
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(color.opacity(0.18), in: Capsule())
        .foregroundStyle(color)
    }
}

/// Explains an iOS limitation inline, honestly.
struct LimitNote: View {
    let text: String
    var icon = "info.circle"
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundStyle(.yellow.opacity(0.9))
            Text(text).font(.footnote).foregroundStyle(.white.opacity(0.7)).fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.yellow.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct ToolCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let colors: [Color]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: colors.first?.opacity(0.5) ?? .clear, radius: 10, y: 4)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline).foregroundStyle(.white)
                Text(subtitle).font(.caption).foregroundStyle(.white.opacity(0.55)).lineLimit(2).multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
        .glassCard(padding: 14)
    }
}

struct ToastOverlay: ViewModifier {
    @Binding var message: String?
    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let message {
                Text(message)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.15)))
                    .padding(.top, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: message) {
                        try? await Task.sleep(for: .seconds(2.4))
                        withAnimation { self.message = nil }
                    }
                    .sensoryFeedback(.success, trigger: message)
            }
        }
    }
}

// MARK: - Inputs

struct ColorRow: View {
    let title: String
    @Binding var value: RGBA
    var body: some View {
        ColorPicker(selection: Binding(get: { value.color }, set: { value = RGBA($0) }), supportsOpacity: true) {
            HStack {
                Text(title)
                Spacer()
                Text(value.hex).font(.caption.monospaced()).foregroundStyle(.secondary)
            }
        }
    }
}

struct SliderRow: View {
    let title: String
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...1
    var step: Double? = nil
    var format: (Double) -> String = { String(format: "%.0f%%", $0 * 100) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(format(value)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            if let step { Slider(value: $value, in: range, step: step) } else { Slider(value: $value, in: range) }
        }
    }
}

/// Picks a photo, stores it in shared storage and returns its id.
struct PhotoField: View {
    let title: String
    @Binding var imageID: String?
    var maxSide: CGFloat = 1600
    @State private var item: PhotosPickerItem?

    var body: some View {
        HStack(spacing: 12) {
            if let img = SharedStore.thumbnail(imageID, maxSide: 160) {
                Image(uiImage: img).resizable().scaledToFill()
                    .frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 10))
            }
            PhotosPicker(selection: $item, matching: .images) {
                Label(imageID == nil ? title : "Change Photo", systemImage: "photo.badge.plus")
            }
            Spacer()
            if imageID != nil {
                Button(role: .destructive) { imageID = nil } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.borderless)
            }
        }
        .onChange(of: item) { _, newItem in
            guard let newItem else { return }
            Task {
                if let d = try? await newItem.loadTransferable(type: Data.self) {
                    imageID = SharedStore.saveImage(d, maxSide: maxSide)
                }
                item = nil
            }
        }
    }
}

enum SymbolLibrary {
    static let symbols = [
        "sparkles", "star.fill", "heart.fill", "bolt.fill", "flame.fill", "moon.stars.fill", "sun.max.fill", "cloud.fill",
        "leaf.fill", "drop.fill", "snowflake", "music.note", "headphones", "gamecontroller.fill", "camera.fill", "photo.fill",
        "message.fill", "phone.fill", "envelope.fill", "bell.fill", "calendar", "clock.fill", "alarm.fill", "timer",
        "map.fill", "location.fill", "car.fill", "airplane", "bicycle", "figure.run", "dumbbell.fill", "heart.text.square.fill",
        "cart.fill", "bag.fill", "creditcard.fill", "gift.fill", "house.fill", "gearshape.fill", "folder.fill", "doc.fill",
        "book.fill", "graduationcap.fill", "pencil", "paintbrush.fill", "paintpalette.fill", "scissors", "wand.and.stars",
        "globe", "safari.fill", "play.rectangle.fill", "tv.fill", "film.fill", "mic.fill", "waveform", "wifi",
        "antenna.radiowaves.left.and.right", "battery.100.bolt", "lock.fill", "key.fill", "shield.fill", "eye.fill",
        "person.fill", "person.2.fill", "pawprint.fill", "fork.knife", "cup.and.saucer.fill", "wineglass.fill",
        "birthday.cake.fill", "crown.fill", "diamond.fill", "suit.heart.fill", "atom", "brain.head.profile", "cpu",
        "terminal.fill", "chevron.left.forwardslash.chevron.right", "app.fill", "square.grid.2x2.fill", "circle.hexagongrid.fill",
        "capsule.fill", "hexagon.fill", "seal.fill", "rainbow", "tornado", "mountain.2.fill", "tree.fill", "ferry.fill"
    ]
}

struct SymbolPicker: View {
    @Binding var symbol: String
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 14) {
                    ForEach(SymbolLibrary.symbols.filter { search.isEmpty || $0.contains(search.lowercased()) }, id: \.self) { s in
                        Button {
                            symbol = s
                            dismiss()
                        } label: {
                            Image(systemName: s)
                                .font(.title3)
                                .frame(width: 48, height: 48)
                                .background(symbol == s ? Color.accentColor.opacity(0.35) : Color.white.opacity(0.06),
                                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(s)
                    }
                }
                .padding()
            }
            .searchable(text: $search)
            .navigationTitle("Symbol")
            .navigationBarTitleDisplayMode(.inline)
            .auraScreen()
        }
        .presentationDetents([.medium, .large])
    }
}

struct SymbolRow: View {
    let title: String
    @Binding var symbol: String
    @State private var picking = false
    var body: some View {
        Button { picking = true } label: {
            HStack {
                Text(title).foregroundStyle(.primary)
                Spacer()
                Image(systemName: symbol).font(.title3)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
        }
        .sheet(isPresented: $picking) { SymbolPicker(symbol: $symbol) }
    }
}

// MARK: - Phone preview

/// A scaled iPhone 16 mock-up showing a theme: wallpaper, Dynamic Island, a simulated status bar, icons and a widget.
/// The status bar here is a preview only — iOS doesn't let apps change the real one.
struct PhonePreview: View {
    let theme: Theme
    var battery: BatteryInfo = .preview
    var height: CGFloat = 420
    var showIcons = true
    var variant: WallpaperVariant = .home
    var expandedIsland = false

    private var scale: CGFloat { height / DeviceGeometry.screen.height }

    var body: some View {
        let w = DeviceGeometry.screen.width
        let h = DeviceGeometry.screen.height
        ZStack(alignment: .top) {
            WallpaperCanvas(theme: theme, variant: variant)
            statusBar
            island
            if showIcons && variant == .home { homeContent.padding(.top, 70) }
            if variant == .lock { lockContent }
        }
        .frame(width: w, height: h)
        .clipShape(RoundedRectangle(cornerRadius: DeviceGeometry.cornerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DeviceGeometry.cornerRadius, style: .continuous).stroke(Color.white.opacity(0.18), lineWidth: 6))
        .scaleEffect(scale)
        .frame(width: w * scale, height: h * scale)
        .shadow(color: theme.accent.color.opacity(0.35), radius: 30, y: 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Preview of \(theme.name)")
    }

    private var statusBar: some View {
        HStack {
            Text(Date.now, format: .dateTime.hour().minute())
                .font(.system(size: 17, weight: .semibold))
                .padding(.leading, 34)
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "cellularbars")
                Image(systemName: "wifi")
                BatteryGraphic(theme: theme, battery: battery, size: 30, style: .classic, showLabel: false)
                    .scaleEffect(0.85)
            }
            .font(.system(size: 15, weight: .semibold))
            .padding(.trailing, 26)
        }
        .foregroundStyle(theme.background.color.luminance > 0.6 && theme.background.kind == .solid ? Color.black : Color.white)
        .frame(height: 54)
        .padding(.top, 2)
    }

    private var island: some View {
        let r = DeviceGeometry.island
        let b = battery
        return HStack {
            IslandSlotView(slot: theme.island.leading, spec: theme.island, battery: b)
            Spacer()
            IslandSlotView(slot: theme.island.trailing, spec: theme.island, battery: b)
        }
        .padding(.horizontal, 12)
        .frame(width: expandedIsland ? r.width + 120 : r.width + 70, height: r.height)
        .background(Capsule().fill(.black))
        .padding(.top, r.minY)
    }

    private var homeContent: some View {
        VStack(spacing: 22) {
            WidgetCanvas(design: WidgetDesign(name: "", layout: .combo), theme: theme, family: .systemMedium, battery: battery, date: .now)
                .padding(16)
                .frame(width: 345, height: 160)
                .background(
                    ZStack {
                        ThemeBackground(spec: theme.background, photoMaxSide: 600)
                        Color.white.opacity(0.06 + theme.glass * 0.15)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                )
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(theme.borderColor.color, lineWidth: theme.borderWidth))
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(64), spacing: 22), count: 4), spacing: 20) {
                ForEach(AppCatalog.apps.prefix(12)) { app in
                    VStack(spacing: 5) {
                        IconTile(spec: theme.icon, symbol: app.symbol, size: 62)
                        Text(app.name).font(.system(size: 11)).foregroundStyle(.white).lineLimit(1)
                    }
                }
            }
            Spacer()
            HStack(spacing: 22) {
                ForEach(AppCatalog.apps.prefix(4)) { app in IconTile(spec: theme.icon, symbol: app.symbol, size: 62) }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 34, style: .continuous).fill(Color.white.opacity(0.18)))
            .padding(.bottom, 14)
        }
        .frame(height: DeviceGeometry.screen.height - 70)
    }

    private var lockContent: some View {
        VStack(spacing: 6) {
            Text(Date.now, format: .dateTime.weekday(.wide).day().month())
                .font(.system(size: 19, weight: .semibold))
            Text(Date.now, format: .dateTime.hour().minute())
                .font(.system(size: 92, weight: .bold, design: .rounded))
            HStack(spacing: 14) {
                Gauge(value: battery.level) { EmptyView() } currentValueLabel: { Text("\(Int(battery.level * 100))") }
                    .gaugeStyle(.accessoryCircularCapacity)
                    .tint(.white)
                VStack(alignment: .leading) {
                    Text("Make it yours").font(.headline)
                    Text("Aura Lock Text").font(.caption).opacity(0.7)
                }
            }
            .padding(.top, 6)
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(.top, 70)
    }
}
