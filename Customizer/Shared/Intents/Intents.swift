import AppIntents
import WidgetKit
import ActivityKit
import UIKit

// MARK: - Widget configuration

struct SelectDesignIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Choose Design"
    static var description = IntentDescription("Pick which of your Aura widget designs to show.")
    @Parameter(title: "Design") var design: DesignEntity?
    init() {}
}

struct SelectThemeIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Choose Theme"
    static var description = IntentDescription("Leave empty to follow your active theme.")
    @Parameter(title: "Theme") var theme: ThemeEntity?
    init() {}
}

// MARK: - Theme actions (usable from widgets, Control Center, Shortcuts and the Action button)

struct ApplyThemeIntent: AppIntent {
    static var title: LocalizedStringResource = "Apply Aura Theme"
    static var description = IntentDescription("Makes a theme active. All widgets following the active theme update.")
    @Parameter(title: "Theme") var theme: ThemeEntity

    init() {}
    init(theme: ThemeEntity) { self.theme = theme }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        var lib = SharedStore.load()
        guard let id = UUID(uuidString: theme.id), lib.theme(id) != nil else {
            return .result(dialog: "That theme no longer exists.")
        }
        lib.activeThemeID = id
        SharedStore.save(lib)
        SharedStore.defaults.set(true, forKey: "pending.islandRefresh")
        return .result(dialog: "Applied \(theme.name).")
    }
}

struct NextThemeIntent: AppIntent {
    static var title: LocalizedStringResource = "Next Aura Theme"
    static var description = IntentDescription("Switches to your next theme.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        var lib = SharedStore.load()
        guard !lib.themes.isEmpty else { return .result(dialog: "No themes yet.") }
        let idx = lib.themes.firstIndex { $0.id == lib.activeThemeID } ?? -1
        let next = lib.themes[(idx + 1) % lib.themes.count]
        lib.activeThemeID = next.id
        SharedStore.save(lib)
        SharedStore.defaults.set(true, forKey: "pending.islandRefresh")
        return .result(dialog: "Theme: \(next.name)")
    }
}

/// Opens Aura at a specific screen. Used by Control Center controls and Shortcuts automations.
struct OpenAuraIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Aura Screen"
    static var openAppWhenRun = true

    enum Screen: String, AppEnum {
        case charging, studio, island, wallpaper
        static var typeDisplayRepresentation: TypeDisplayRepresentation = "Screen"
        static var caseDisplayRepresentations: [Screen: DisplayRepresentation] = [
            .charging: "Charging Screen", .studio: "Studio", .island: "Dynamic Island", .wallpaper: "Wallpaper"
        ]
    }

    @Parameter(title: "Screen", default: .charging) var screen: Screen

    init() {}
    init(screen: Screen) { self.screen = screen }

    func perform() async throws -> some IntentResult {
        SharedStore.defaults.set(screen.rawValue, forKey: "pending.route")
        return .result()
    }
}

// MARK: - Dynamic Island (Live Activity)

struct AuraIslandAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var spec: IslandSpec
        var batteryLevel: Double
        var charging: Bool
        /// "custom" or "charging"
        var mode: String
        var startedAt: Date
        var accent: RGBA
        var text: RGBA
        var background: RGBA
        var themeName: String
    }
    var name: String
}

enum IslandController {
    static func state(theme: Theme, mode: String = "custom", startedAt: Date = .now) -> AuraIslandAttributes.ContentState {
        let b = BatteryInfo.current()
        let bg = theme.background.kind == .solid ? theme.background.color : (theme.background.colors.last ?? theme.background.color)
        return .init(spec: theme.island, batteryLevel: b.level, charging: b.charging || b.full, mode: mode,
                     startedAt: startedAt, accent: theme.accent, text: theme.text, background: bg, themeName: theme.name)
    }

    static var isRunning: Bool { !Activity<AuraIslandAttributes>.activities.isEmpty }

    static var authorizationEnabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    @discardableResult
    static func start(theme: Theme, mode: String = "custom") async throws -> Bool {
        await endAll()
        let content = ActivityContent(state: state(theme: theme, mode: mode), staleDate: nil)
        _ = try Activity.request(attributes: AuraIslandAttributes(name: "Aura"), content: content, pushType: nil)
        return true
    }

    static func update(theme: Theme) async {
        for a in Activity<AuraIslandAttributes>.activities {
            let s = state(theme: theme, mode: a.content.state.mode, startedAt: a.content.state.startedAt)
            await a.update(ActivityContent(state: s, staleDate: nil))
        }
    }

    static func endAll() async {
        for a in Activity<AuraIslandAttributes>.activities {
            await a.end(nil, dismissalPolicy: .immediate)
        }
    }
}

struct StartIslandIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Start Aura Island"
    static var description = IntentDescription("Shows your themed design in the Dynamic Island and on the Lock Screen.")

    func perform() async throws -> some IntentResult {
        try await IslandController.start(theme: SharedStore.load().currentTheme)
        return .result()
    }
}

struct StopIslandIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stop Aura Island"

    func perform() async throws -> some IntentResult {
        await IslandController.endAll()
        return .result()
    }
}

struct ChargingIslandIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Show Charging Island"
    static var description = IntentDescription("Shows a themed charging display in the Dynamic Island. Use with a 'When charger is connected' automation.")

    func perform() async throws -> some IntentResult {
        try await IslandController.start(theme: SharedStore.load().currentTheme, mode: "charging")
        return .result()
    }
}

/// Applies the configured theme, or the next one if none was chosen.
struct ThemeControlAction: AppIntent {
    static var title: LocalizedStringResource = "Apply Configured Theme"
    static var isDiscoverable = false
    @Parameter(title: "Theme ID") var themeID: String

    init() {}
    init(themeID: String) { self.themeID = themeID }

    func perform() async throws -> some IntentResult {
        var lib = SharedStore.load()
        if let id = UUID(uuidString: themeID), lib.theme(id) != nil {
            lib.activeThemeID = id
        } else if !lib.themes.isEmpty {
            let idx = lib.themes.firstIndex { $0.id == lib.activeThemeID } ?? -1
            lib.activeThemeID = lib.themes[(idx + 1) % lib.themes.count].id
        }
        SharedStore.save(lib)
        SharedStore.defaults.set(true, forKey: "pending.islandRefresh")
        return .result()
    }
}
