import SwiftUI

// MARK: - Colour

/// A Codable colour (sRGB). Stored in designs and shared with widgets.
struct RGBA: Codable, Hashable {
    var r: Double, g: Double, b: Double, a: Double = 1

    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: a) }

    init(r: Double, g: Double, b: Double, a: Double = 1) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    init(_ color: Color) {
        let ui = UIColor(color)
        var rr: CGFloat = 0, gg: CGFloat = 0, bb: CGFloat = 0, aa: CGFloat = 0
        if !ui.getRed(&rr, green: &gg, blue: &bb, alpha: &aa) {
            var w: CGFloat = 0
            ui.getWhite(&w, alpha: &aa)
            rr = w; gg = w; bb = w
        }
        r = Double(max(0, min(1, rr))); g = Double(max(0, min(1, gg))); b = Double(max(0, min(1, bb))); a = Double(aa)
    }

    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8, let v = UInt64(s, radix: 16) else { return nil }
        if s.count == 6 {
            r = Double((v >> 16) & 0xFF) / 255; g = Double((v >> 8) & 0xFF) / 255; b = Double(v & 0xFF) / 255; a = 1
        } else {
            r = Double((v >> 24) & 0xFF) / 255; g = Double((v >> 16) & 0xFF) / 255
            b = Double((v >> 8) & 0xFF) / 255; a = Double(v & 0xFF) / 255
        }
    }

    var hex: String {
        String(format: "#%02X%02X%02X", Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
    }

    /// Perceived brightness 0…1, used to pick readable text colours.
    var luminance: Double { 0.2126 * r + 0.7152 * g + 0.0722 * b }

    static let white = RGBA(r: 1, g: 1, b: 1)
    static let black = RGBA(r: 0, g: 0, b: 0)
}

// MARK: - Building blocks

enum GradientKind: String, Codable, CaseIterable, Identifiable {
    case linear, radial, angular, mesh
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

struct BackgroundSpec: Codable, Hashable {
    enum Kind: String, Codable, CaseIterable, Identifiable {
        case solid, gradient, photo
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
    }
    var kind: Kind = .gradient
    var color: RGBA = RGBA(r: 0.06, g: 0.06, b: 0.1)
    var gradientKind: GradientKind = .linear
    var colors: [RGBA] = [RGBA(r: 0.12, g: 0.08, b: 0.3), RGBA(r: 0.02, g: 0.02, b: 0.06)]
    var angle: Double = 135
    var photoID: String?
    var blur: Double = 0
    var dim: Double = 0
    var saturation: Double = 1
    var grain: Double = 0
}

enum FontDesignChoice: String, Codable, CaseIterable, Identifiable {
    case standard, rounded, serif, mono, custom
    var id: String { rawValue }
    var label: String {
        switch self {
        case .standard: return "SF Pro"
        case .rounded: return "Rounded"
        case .serif: return "New York"
        case .mono: return "Mono"
        case .custom: return "Imported"
        }
    }
}

struct TypeSpec: Codable, Hashable {
    var design: FontDesignChoice = .rounded
    var weight: Int = 6          // 1 = ultralight … 9 = black
    var customFontName: String?  // PostScript name of an imported font
    var tracking: Double = 0
}

enum BatteryStyle: String, Codable, CaseIterable, Identifiable {
    case ring, bar, pill, liquid, segments, classic, digits, emoji
    var id: String { rawValue }
    var label: String {
        switch self {
        case .ring: return "Ring"
        case .bar: return "Bar"
        case .pill: return "Pill"
        case .liquid: return "Liquid"
        case .segments: return "Segments"
        case .classic: return "Classic"
        case .digits: return "Big Digits"
        case .emoji: return "Emoji"
        }
    }
}

struct BatterySpec: Codable, Hashable {
    var style: BatteryStyle = .ring
    var showPercent = true
    var lowThreshold: Double = 0.2
    var normalColor: RGBA = RGBA(r: 0.2, g: 0.9, b: 0.6)
    var lowColor: RGBA = RGBA(r: 1, g: 0.25, b: 0.3)
    var chargingColor: RGBA = RGBA(r: 1, g: 0.85, b: 0.2)
    var fullColor: RGBA = RGBA(r: 0.35, g: 0.75, b: 1)
    var emojiFull = "🔋"
    var emojiLow = "🪫"
    var emojiCharging = "⚡️"
    var lowMessage = "Charge me"
}

enum ClockStyle: String, Codable, CaseIterable, Identifiable {
    case digital, stacked, analog, minimal, words
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

struct ClockSpec: Codable, Hashable {
    var style: ClockStyle = .digital
    var use24h = false
    var showDate = true
}

enum IconShape: String, Codable, CaseIterable, Identifiable {
    case squircle, circle, rounded, square, hexagon
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

struct IconSpec: Codable, Hashable {
    var shape: IconShape = .squircle
    var useGradient = true
    var background: RGBA = RGBA(r: 0.12, g: 0.1, b: 0.2)
    var background2: RGBA = RGBA(r: 0.3, g: 0.2, b: 0.55)
    var glyph: RGBA = .white
    var glyphScale: Double = 0.5
    var glass = false
    var showBorder = false
}

enum IslandSlot: String, Codable, CaseIterable, Identifiable {
    case none, clock, battery, emoji, text, symbol, image, timer
    var id: String { rawValue }
    var label: String {
        switch self {
        case .none: return "Empty"
        case .clock: return "Clock"
        case .battery: return "Battery"
        case .emoji: return "Emoji"
        case .text: return "Text"
        case .symbol: return "Symbol"
        case .image: return "Photo"
        case .timer: return "Elapsed"
        }
    }
}

struct IslandSpec: Codable, Hashable {
    var leading: IslandSlot = .symbol
    var trailing: IslandSlot = .battery
    var minimal: IslandSlot = .symbol
    var text = "Aura"
    var emoji = "✨"
    var symbol = "sparkles"
    var imageID: String?
    var expandedTitle = "Aura"
    var expandedSubtitle = "Have a great day"
    var tint: RGBA = RGBA(r: 0.65, g: 0.5, b: 1)
}

enum ChargingStyle: String, Codable, CaseIterable, Identifiable {
    case liquid, ring, neon, minimal, photo, orbit
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

struct ChargingSpec: Codable, Hashable {
    var style: ChargingStyle = .liquid
    var showPercent = true
    var message = "Charging"
    var photoID: String?
}

enum WallpaperDecoration: String, Codable, CaseIterable, Identifiable {
    case none, islandHalo, statusBand, topFrame, islandWings
    var id: String { rawValue }
    var label: String {
        switch self {
        case .none: return "None"
        case .islandHalo: return "Island Halo"
        case .statusBand: return "Status Band"
        case .topFrame: return "Top Frame"
        case .islandWings: return "Island Wings"
        }
    }
}

struct WallpaperSpec: Codable, Hashable {
    var decoration: WallpaperDecoration = .islandHalo
    var decorationColor: RGBA = RGBA(r: 0.65, g: 0.5, b: 1)
    var decorationGlow: Double = 0.7
    var decorationWidth: Double = 3
    var overlayText = ""
    var homeDim: Double = 0.15
    var homeBlur: Double = 0
    /// Fine-tunes halo position for the Dynamic Island (points).
    var islandOffsetY: Double = 0
}

// MARK: - Theme (a complete customisation profile)

struct Theme: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var mood = ""
    var createdAt = Date()
    var updatedAt = Date()
    var background = BackgroundSpec()
    var accent: RGBA = RGBA(r: 0.65, g: 0.5, b: 1)
    var text: RGBA = .white
    var secondaryText: RGBA = RGBA(r: 1, g: 1, b: 1, a: 0.65)
    var type = TypeSpec()
    var cornerRadius: Double = 22
    var glass: Double = 0.0
    var borderWidth: Double = 0
    var borderColor: RGBA = RGBA(r: 1, g: 1, b: 1, a: 0.25)
    var battery = BatterySpec()
    var clock = ClockSpec()
    var icon = IconSpec()
    var island = IslandSpec()
    var charging = ChargingSpec()
    var wallpaper = WallpaperSpec()
    var isPreset = false
}

// MARK: - Widgets

enum WidgetLayout: String, Codable, CaseIterable, Identifiable {
    case clock, battery, statusStrip, photo, date, quote, countdown, launcher, notifications, combo
    var id: String { rawValue }
    var label: String {
        switch self {
        case .clock: return "Clock"
        case .battery: return "Battery"
        case .statusStrip: return "Status Strip"
        case .photo: return "Photo"
        case .date: return "Calendar"
        case .quote: return "Text / Quote"
        case .countdown: return "Countdown"
        case .launcher: return "App Launcher"
        case .notifications: return "Notification Stack"
        case .combo: return "Clock + Battery"
        }
    }
    var symbol: String {
        switch self {
        case .clock: return "clock.fill"
        case .battery: return "battery.75percent"
        case .statusStrip: return "menubar.rectangle"
        case .photo: return "photo.fill"
        case .date: return "calendar"
        case .quote: return "quote.opening"
        case .countdown: return "hourglass"
        case .launcher: return "square.grid.2x2.fill"
        case .notifications: return "bell.badge.fill"
        case .combo: return "rectangle.split.2x1.fill"
        }
    }
}

struct LaunchLink: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String
    var url: String
    var symbol: String
    var imageID: String?
}

struct FakeNotification: Codable, Identifiable, Hashable {
    var id = UUID()
    var app: String
    var title: String
    var body: String
    var symbol: String = "bell.fill"
    var time = "now"
}

struct WidgetDesign: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var layout: WidgetLayout
    /// nil = follow the active theme.
    var themeID: UUID?
    var title = ""
    var subtitle = ""
    var photoIDs: [String] = []
    var countdownDate = Date().addingTimeInterval(86400 * 30)
    var links: [LaunchLink] = []
    var notifications: [FakeNotification] = []
    var symbol = "sparkles"
    var createdAt = Date()
}

// MARK: - Icons

struct IconItem: Codable, Identifiable, Hashable {
    var id = UUID()
    var appName: String
    var imageID: String
    /// URL scheme used when installing as a Web Clip (optional).
    var url: String = ""
}

struct IconPack: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var icons: [IconItem] = []
    var createdAt = Date()
    var generatedFromThemeID: UUID?
}

// MARK: - Library

struct DesignLibrary: Codable {
    var themes: [Theme] = []
    var widgets: [WidgetDesign] = []
    var iconPacks: [IconPack] = []
    var activeThemeID: UUID?
    /// Set by the Focus filter while a Focus is on.
    var focusThemeID: UUID?
    var version = 1

    var effectiveThemeID: UUID? { focusThemeID ?? activeThemeID }

    func theme(_ id: UUID?) -> Theme? {
        guard let id else { return nil }
        return themes.first { $0.id == id }
    }

    /// The theme widgets should use right now.
    var currentTheme: Theme {
        theme(effectiveThemeID) ?? themes.first ?? Presets.all[0]
    }

    func resolvedTheme(for design: WidgetDesign) -> Theme {
        theme(design.themeID) ?? currentTheme
    }
}
