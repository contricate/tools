import SwiftUI

enum Presets {
    private static func id(_ n: Int) -> UUID { UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", n))! }
    private static func c(_ hex: String) -> RGBA { RGBA(hex: hex) ?? .white }

    static var all: [Theme] { [minimalist, amoled, gaming, neon, cleanIOS, personalPhoto, sunset, pastel, ocean, forest] }

    static var minimalist: Theme {
        var t = Theme(id: id(1), name: "Minimalist", mood: "Calm")
        t.background = BackgroundSpec(kind: .solid, color: c("#F2F0EB"))
        t.text = c("#1C1C1E"); t.secondaryText = RGBA(r: 0.11, g: 0.11, b: 0.12, a: 0.55); t.accent = c("#1C1C1E")
        t.type = TypeSpec(design: .standard, weight: 3, tracking: 0.5)
        t.cornerRadius = 26
        t.battery = BatterySpec(style: .bar, normalColor: c("#1C1C1E"), lowColor: c("#D64545"), chargingColor: c("#3A7D44"), fullColor: c("#1C1C1E"))
        t.clock = ClockSpec(style: .minimal)
        t.icon = IconSpec(shape: .circle, useGradient: false, background: c("#FFFFFF"), background2: c("#FFFFFF"), glyph: c("#1C1C1E"), glyphScale: 0.42, showBorder: true)
        t.island = IslandSpec(leading: .clock, trailing: .battery, minimal: .battery, symbol: "circle.fill", tint: c("#FFFFFF"))
        t.charging = ChargingSpec(style: .minimal)
        t.wallpaper = WallpaperSpec(decoration: .none, decorationColor: c("#1C1C1E"))
        t.isPreset = true
        return t
    }

    static var amoled: Theme {
        var t = Theme(id: id(2), name: "Dark AMOLED", mood: "Focused")
        t.background = BackgroundSpec(kind: .solid, color: .black)
        t.text = .white; t.secondaryText = RGBA(r: 1, g: 1, b: 1, a: 0.5); t.accent = c("#FFFFFF")
        t.type = TypeSpec(design: .standard, weight: 5)
        t.borderWidth = 1; t.borderColor = RGBA(r: 1, g: 1, b: 1, a: 0.12)
        t.battery = BatterySpec(style: .ring, normalColor: c("#FFFFFF"), lowColor: c("#FF453A"), chargingColor: c("#30D158"), fullColor: c("#FFFFFF"))
        t.clock = ClockSpec(style: .stacked)
        t.icon = IconSpec(shape: .squircle, useGradient: false, background: c("#000000"), background2: c("#000000"), glyph: c("#FFFFFF"), glyphScale: 0.46, showBorder: true)
        t.island = IslandSpec(leading: .symbol, trailing: .battery, minimal: .battery, symbol: "moon.stars.fill", tint: c("#FFFFFF"))
        t.charging = ChargingSpec(style: .ring)
        t.wallpaper = WallpaperSpec(decoration: .islandHalo, decorationColor: c("#FFFFFF"), decorationGlow: 0.35, decorationWidth: 1.5)
        t.isPreset = true
        return t
    }

    static var gaming: Theme {
        var t = Theme(id: id(3), name: "Gaming", mood: "Hype")
        t.background = BackgroundSpec(kind: .gradient, gradientKind: .angular, colors: [c("#0B0F1A"), c("#1B0B3A"), c("#00131F"), c("#0B0F1A")], angle: 0, grain: 0.15)
        t.text = c("#E8F7FF"); t.secondaryText = c("#7FD8FF"); t.accent = c("#FF2E88")
        t.type = TypeSpec(design: .mono, weight: 8, tracking: 1)
        t.cornerRadius = 10; t.borderWidth = 1.5; t.borderColor = c("#FF2E88")
        t.battery = BatterySpec(style: .segments, normalColor: c("#00F0FF"), lowColor: c("#FF2E88"), chargingColor: c("#B4FF39"), fullColor: c("#00F0FF"))
        t.clock = ClockSpec(style: .digital, use24h: true)
        t.icon = IconSpec(shape: .hexagon, useGradient: true, background: c("#14112A"), background2: c("#2A0F4A"), glyph: c("#00F0FF"), glyphScale: 0.5, showBorder: true)
        t.island = IslandSpec(leading: .symbol, trailing: .battery, minimal: .symbol, text: "GG", symbol: "gamecontroller.fill", expandedTitle: "Player 1", expandedSubtitle: "Ready", tint: c("#FF2E88"))
        t.charging = ChargingSpec(style: .orbit, message: "Powering up")
        t.wallpaper = WallpaperSpec(decoration: .islandWings, decorationColor: c("#FF2E88"), decorationGlow: 0.9, decorationWidth: 3)
        t.isPreset = true
        return t
    }

    static var neon: Theme {
        var t = Theme(id: id(4), name: "Neon", mood: "Night")
        t.background = BackgroundSpec(kind: .gradient, gradientKind: .mesh, colors: [c("#120024"), c("#3A0CA3"), c("#7209B7"), c("#0A0014")], angle: 160)
        t.text = .white; t.secondaryText = c("#F72585"); t.accent = c("#4CC9F0")
        t.type = TypeSpec(design: .rounded, weight: 7)
        t.glass = 0.25; t.borderWidth = 1; t.borderColor = c("#4CC9F0")
        t.battery = BatterySpec(style: .liquid, normalColor: c("#4CC9F0"), lowColor: c("#F72585"), chargingColor: c("#B5FF6E"), fullColor: c("#4CC9F0"))
        t.clock = ClockSpec(style: .stacked)
        t.icon = IconSpec(shape: .squircle, useGradient: true, background: c("#1A0533"), background2: c("#3A0CA3"), glyph: c("#4CC9F0"), glyphScale: 0.5, glass: false, showBorder: true)
        t.island = IslandSpec(leading: .emoji, trailing: .battery, minimal: .emoji, emoji: "💜", symbol: "bolt.fill", tint: c("#F72585"))
        t.charging = ChargingSpec(style: .neon)
        t.wallpaper = WallpaperSpec(decoration: .islandHalo, decorationColor: c("#F72585"), decorationGlow: 1, decorationWidth: 3)
        t.isPreset = true
        return t
    }

    static var cleanIOS: Theme {
        var t = Theme(id: id(5), name: "Clean iOS", mood: "Classic")
        t.background = BackgroundSpec(kind: .gradient, gradientKind: .linear, colors: [c("#5AC8FA"), c("#007AFF"), c("#5856D6")], angle: 160)
        t.text = .white; t.secondaryText = RGBA(r: 1, g: 1, b: 1, a: 0.75); t.accent = c("#FFFFFF")
        t.type = TypeSpec(design: .standard, weight: 6)
        t.glass = 0.35
        t.battery = BatterySpec(style: .classic, normalColor: c("#34C759"), lowColor: c("#FF3B30"), chargingColor: c("#34C759"), fullColor: c("#34C759"))
        t.clock = ClockSpec(style: .digital)
        t.icon = IconSpec(shape: .squircle, useGradient: true, background: c("#FFFFFF"), background2: c("#E5E5EA"), glyph: c("#007AFF"), glyphScale: 0.5)
        t.island = IslandSpec(leading: .clock, trailing: .battery, minimal: .battery, symbol: "apple.logo", tint: c("#FFFFFF"))
        t.charging = ChargingSpec(style: .ring)
        t.wallpaper = WallpaperSpec(decoration: .none)
        t.isPreset = true
        return t
    }

    static var personalPhoto: Theme {
        var t = Theme(id: id(6), name: "Personal Photo", mood: "Memories")
        t.background = BackgroundSpec(kind: .gradient, gradientKind: .radial, colors: [c("#FFB199"), c("#FF0844")], angle: 0, blur: 0, dim: 0.2)
        t.text = .white; t.secondaryText = RGBA(r: 1, g: 1, b: 1, a: 0.8); t.accent = c("#FFFFFF")
        t.type = TypeSpec(design: .serif, weight: 6)
        t.glass = 0.4
        t.battery = BatterySpec(style: .pill, normalColor: c("#FFFFFF"), lowColor: c("#FFD60A"), chargingColor: c("#FFFFFF"), fullColor: c("#FFFFFF"))
        t.clock = ClockSpec(style: .words)
        t.icon = IconSpec(shape: .rounded, useGradient: false, background: RGBA(r: 1, g: 1, b: 1, a: 0.85), background2: .white, glyph: c("#FF0844"), glyphScale: 0.48, glass: true)
        t.island = IslandSpec(leading: .image, trailing: .battery, minimal: .image, symbol: "heart.fill", tint: c("#FF8FA3"))
        t.charging = ChargingSpec(style: .photo)
        t.wallpaper = WallpaperSpec(decoration: .topFrame, decorationColor: c("#FFFFFF"), decorationGlow: 0.3, decorationWidth: 2, overlayText: "")
        t.isPreset = true
        return t
    }

    static var sunset: Theme {
        var t = Theme(id: id(7), name: "Sunset", mood: "Warm")
        t.background = BackgroundSpec(kind: .gradient, gradientKind: .linear, colors: [c("#FF5E62"), c("#FF9966"), c("#FFD194")], angle: 180)
        t.text = .white; t.secondaryText = RGBA(r: 1, g: 1, b: 1, a: 0.8); t.accent = c("#FFF3E0")
        t.type = TypeSpec(design: .rounded, weight: 7)
        t.glass = 0.3
        t.battery = BatterySpec(style: .liquid, normalColor: c("#FFFFFF"), lowColor: c("#7A0019"), chargingColor: c("#FFF176"), fullColor: c("#FFFFFF"))
        t.clock = ClockSpec(style: .stacked)
        t.icon = IconSpec(shape: .squircle, useGradient: true, background: c("#FF7E5F"), background2: c("#FEB47B"), glyph: .white, glyphScale: 0.5)
        t.island = IslandSpec(leading: .emoji, trailing: .clock, minimal: .emoji, emoji: "🌅", tint: c("#FFB074"))
        t.charging = ChargingSpec(style: .liquid)
        t.wallpaper = WallpaperSpec(decoration: .statusBand, decorationColor: c("#FFFFFF"), decorationGlow: 0.4)
        t.isPreset = true
        return t
    }

    static var pastel: Theme {
        var t = Theme(id: id(8), name: "Pastel", mood: "Soft")
        t.background = BackgroundSpec(kind: .gradient, gradientKind: .mesh, colors: [c("#FDE2E4"), c("#E2ECE9"), c("#CDDAFD"), c("#FFF1E6")], angle: 120)
        t.text = c("#4A4E69"); t.secondaryText = c("#9A8C98"); t.accent = c("#B8C0FF")
        t.type = TypeSpec(design: .rounded, weight: 6)
        t.glass = 0.5; t.cornerRadius = 30
        t.battery = BatterySpec(style: .pill, normalColor: c("#B8C0FF"), lowColor: c("#FFADAD"), chargingColor: c("#CAFFBF"), fullColor: c("#9BF6FF"))
        t.clock = ClockSpec(style: .digital)
        t.icon = IconSpec(shape: .circle, useGradient: true, background: c("#FFFFFF"), background2: c("#E2ECE9"), glyph: c("#9A8C98"), glyphScale: 0.46)
        t.island = IslandSpec(leading: .emoji, trailing: .battery, minimal: .emoji, emoji: "🌸", tint: c("#FFC8DD"))
        t.charging = ChargingSpec(style: .liquid)
        t.wallpaper = WallpaperSpec(decoration: .islandHalo, decorationColor: c("#FFC8DD"), decorationGlow: 0.8, decorationWidth: 4)
        t.isPreset = true
        return t
    }

    static var ocean: Theme {
        var t = Theme(id: id(9), name: "Deep Ocean", mood: "Chill")
        t.background = BackgroundSpec(kind: .gradient, gradientKind: .linear, colors: [c("#0F2027"), c("#203A43"), c("#2C5364")], angle: 170)
        t.text = c("#E0FBFC"); t.secondaryText = c("#98C1D9"); t.accent = c("#3DDCFF")
        t.type = TypeSpec(design: .standard, weight: 5)
        t.glass = 0.2
        t.battery = BatterySpec(style: .liquid, normalColor: c("#3DDCFF"), lowColor: c("#FF6B6B"), chargingColor: c("#7CFFCB"), fullColor: c("#3DDCFF"))
        t.clock = ClockSpec(style: .analog)
        t.icon = IconSpec(shape: .squircle, useGradient: true, background: c("#14313C"), background2: c("#2C5364"), glyph: c("#E0FBFC"), glyphScale: 0.48, glass: true)
        t.island = IslandSpec(leading: .symbol, trailing: .battery, minimal: .symbol, symbol: "water.waves", tint: c("#3DDCFF"))
        t.charging = ChargingSpec(style: .liquid)
        t.wallpaper = WallpaperSpec(decoration: .islandHalo, decorationColor: c("#3DDCFF"), decorationGlow: 0.6, decorationWidth: 2)
        t.isPreset = true
        return t
    }

    static var forest: Theme {
        var t = Theme(id: id(10), name: "Forest", mood: "Grounded")
        t.background = BackgroundSpec(kind: .gradient, gradientKind: .radial, colors: [c("#2D6A4F"), c("#081C15")], angle: 0, grain: 0.2)
        t.text = c("#D8F3DC"); t.secondaryText = c("#95D5B2"); t.accent = c("#B7E4C7")
        t.type = TypeSpec(design: .serif, weight: 5)
        t.battery = BatterySpec(style: .ring, normalColor: c("#95D5B2"), lowColor: c("#E76F51"), chargingColor: c("#E9C46A"), fullColor: c("#B7E4C7"))
        t.clock = ClockSpec(style: .words)
        t.icon = IconSpec(shape: .rounded, useGradient: true, background: c("#1B4332"), background2: c("#2D6A4F"), glyph: c("#D8F3DC"), glyphScale: 0.48)
        t.island = IslandSpec(leading: .emoji, trailing: .battery, minimal: .emoji, emoji: "🌿", tint: c("#95D5B2"))
        t.charging = ChargingSpec(style: .ring)
        t.wallpaper = WallpaperSpec(decoration: .topFrame, decorationColor: c("#95D5B2"), decorationGlow: 0.3, decorationWidth: 1.5)
        t.isPreset = true
        return t
    }

    static func starterWidgets(themes: [Theme]) -> [WidgetDesign] {
        [
            WidgetDesign(name: "Big Battery", layout: .battery),
            WidgetDesign(name: "Time & Power", layout: .combo),
            WidgetDesign(name: "Status Strip", layout: .statusStrip),
            WidgetDesign(name: "Today", layout: .date),
            WidgetDesign(name: "Daily Note", layout: .quote, title: "Make it yours.", subtitle: "— Aura"),
            WidgetDesign(name: "Favourite Apps", layout: .launcher, links: [
                LaunchLink(title: "Camera", url: "aura://open?app=camera", symbol: "camera.fill"),
                LaunchLink(title: "Music", url: "music://", symbol: "music.note"),
                LaunchLink(title: "Maps", url: "maps://", symbol: "map.fill"),
                LaunchLink(title: "Notes", url: "mobilenotes://", symbol: "note.text")
            ]),
            WidgetDesign(name: "Inbox Vibes", layout: .notifications, notifications: [
                FakeNotification(app: "Aura", title: "Looking good ✨", body: "Your theme is applied.", symbol: "sparkles"),
                FakeNotification(app: "Reminder", title: "Drink water", body: "Stay hydrated today.", symbol: "drop.fill", time: "9:41")
            ])
        ]
    }
}

/// Popular apps with their public URL schemes, used to auto-match icon packs and build launchers.
/// A scheme opens the app if it's installed; Apple doesn't guarantee third-party schemes.
struct CatalogApp: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let scheme: String
    let symbol: String
    let aliases: [String]
}

enum AppCatalog {
    static let apps: [CatalogApp] = [
        CatalogApp(name: "Phone", scheme: "tel://", symbol: "phone.fill", aliases: ["call", "dialer"]),
        CatalogApp(name: "Messages", scheme: "sms://", symbol: "message.fill", aliases: ["imessage", "sms", "message"]),
        CatalogApp(name: "Mail", scheme: "message://", symbol: "envelope.fill", aliases: ["email", "gmail"]),
        CatalogApp(name: "Safari", scheme: "x-web-search://", symbol: "safari.fill", aliases: ["browser", "web"]),
        CatalogApp(name: "Music", scheme: "music://", symbol: "music.note", aliases: ["apple music", "itunes"]),
        CatalogApp(name: "Photos", scheme: "photos-redirect://", symbol: "photo.on.rectangle", aliases: ["gallery", "pictures"]),
        CatalogApp(name: "Camera", scheme: "aura://open?app=camera", symbol: "camera.fill", aliases: ["cam"]),
        CatalogApp(name: "Settings", scheme: "app-settings:", symbol: "gearshape.fill", aliases: ["preferences", "prefs"]),
        CatalogApp(name: "Maps", scheme: "maps://", symbol: "map.fill", aliases: ["apple maps"]),
        CatalogApp(name: "Calendar", scheme: "calshow://", symbol: "calendar", aliases: ["cal"]),
        CatalogApp(name: "Notes", scheme: "mobilenotes://", symbol: "note.text", aliases: ["note"]),
        CatalogApp(name: "Reminders", scheme: "x-apple-reminderkit://", symbol: "checklist", aliases: ["todo", "tasks"]),
        CatalogApp(name: "Weather", scheme: "weather://", symbol: "cloud.sun.fill", aliases: []),
        CatalogApp(name: "Clock", scheme: "clock-alarm://", symbol: "alarm.fill", aliases: ["alarm", "timer"]),
        CatalogApp(name: "App Store", scheme: "itms-apps://", symbol: "bag.fill", aliases: ["appstore", "store"]),
        CatalogApp(name: "FaceTime", scheme: "facetime://", symbol: "video.fill", aliases: []),
        CatalogApp(name: "Podcasts", scheme: "podcasts://", symbol: "mic.fill", aliases: ["podcast"]),
        CatalogApp(name: "Shortcuts", scheme: "shortcuts://", symbol: "square.stack.3d.up.fill", aliases: []),
        CatalogApp(name: "Files", scheme: "shareddocuments://", symbol: "folder.fill", aliases: ["documents"]),
        CatalogApp(name: "Wallet", scheme: "shoebox://", symbol: "wallet.pass.fill", aliases: ["apple pay"]),
        CatalogApp(name: "Find My", scheme: "findmy://", symbol: "location.fill", aliases: ["findmy"]),
        CatalogApp(name: "Health", scheme: "x-apple-health://", symbol: "heart.fill", aliases: []),
        CatalogApp(name: "Instagram", scheme: "instagram://", symbol: "camera.circle.fill", aliases: ["insta", "ig"]),
        CatalogApp(name: "TikTok", scheme: "snssdk1233://", symbol: "music.note.tv", aliases: ["tik tok"]),
        CatalogApp(name: "YouTube", scheme: "youtube://", symbol: "play.rectangle.fill", aliases: ["yt"]),
        CatalogApp(name: "WhatsApp", scheme: "whatsapp://", symbol: "phone.bubble.fill", aliases: ["whats app"]),
        CatalogApp(name: "Snapchat", scheme: "snapchat://", symbol: "bubble.left.fill", aliases: ["snap"]),
        CatalogApp(name: "X", scheme: "twitter://", symbol: "xmark", aliases: ["twitter"]),
        CatalogApp(name: "Facebook", scheme: "fb://", symbol: "f.square.fill", aliases: ["fb"]),
        CatalogApp(name: "Messenger", scheme: "fb-messenger://", symbol: "bubble.left.and.bubble.right.fill", aliases: []),
        CatalogApp(name: "Spotify", scheme: "spotify://", symbol: "waveform", aliases: []),
        CatalogApp(name: "Netflix", scheme: "nflx://", symbol: "tv.fill", aliases: []),
        CatalogApp(name: "Discord", scheme: "discord://", symbol: "gamecontroller.fill", aliases: []),
        CatalogApp(name: "Reddit", scheme: "reddit://", symbol: "bubble.left.and.text.bubble.right.fill", aliases: []),
        CatalogApp(name: "Pinterest", scheme: "pinterest://", symbol: "pin.fill", aliases: []),
        CatalogApp(name: "Telegram", scheme: "tg://", symbol: "paperplane.fill", aliases: []),
        CatalogApp(name: "Threads", scheme: "barcelona://", symbol: "at", aliases: []),
        CatalogApp(name: "Gmail", scheme: "googlegmail://", symbol: "envelope.open.fill", aliases: []),
        CatalogApp(name: "Google Maps", scheme: "comgooglemaps://", symbol: "map.circle.fill", aliases: ["gmaps"]),
        CatalogApp(name: "Chrome", scheme: "googlechrome://", symbol: "globe", aliases: ["google chrome"]),
        CatalogApp(name: "Uber", scheme: "uber://", symbol: "car.fill", aliases: []),
        CatalogApp(name: "Amazon", scheme: "com.amazon.mobile.shopping://", symbol: "cart.fill", aliases: []),
        CatalogApp(name: "Twitch", scheme: "twitch://", symbol: "play.tv.fill", aliases: []),
        CatalogApp(name: "Slack", scheme: "slack://", symbol: "number", aliases: []),
        CatalogApp(name: "Zoom", scheme: "zoomus://", symbol: "video.circle.fill", aliases: []),
        CatalogApp(name: "PayPal", scheme: "paypal://", symbol: "dollarsign.circle.fill", aliases: []),
        CatalogApp(name: "Duolingo", scheme: "duolingo://", symbol: "graduationcap.fill", aliases: []),
        CatalogApp(name: "ChatGPT", scheme: "chatgpt://", symbol: "bubble.left.circle.fill", aliases: []),
        CatalogApp(name: "Claude", scheme: "claude://", symbol: "sparkle", aliases: ["anthropic"])
    ]

    private static func normalize(_ s: String) -> String {
        s.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    /// Matches an icon file name like "instagram_icon@3x.png" to a known app.
    static func match(fileName: String) -> CatalogApp? {
        let base = (fileName as NSString).deletingPathExtension.lowercased()
            .replacingOccurrences(of: "@3x", with: "").replacingOccurrences(of: "@2x", with: "")
        let junk: Set<String> = ["icon", "icons", "logo", "app", "ios", "aesthetic", "png", "jpg", "new", "final", "copy"]
        let tokens = base.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
            .filter { !junk.contains($0) && Int($0) == nil }
        let key = normalize(tokens.joined())
        guard !key.isEmpty else { return nil }
        if let exact = apps.first(where: { normalize($0.name) == key || $0.aliases.map(normalize).contains(key) }) { return exact }
        // Longest app name contained in the file name (e.g. "spotifygreen" → Spotify).
        return apps.filter { normalize($0.name).count >= 3 && key.contains(normalize($0.name)) }
            .max { normalize($0.name).count < normalize($1.name).count }
    }
}
