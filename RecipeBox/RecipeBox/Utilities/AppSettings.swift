import SwiftUI

/// UserDefaults keys for every persisted preference. Views read them with @AppStorage.
enum SettingsKey {
    static let theme = "theme"
    static let accent = "accentChoice"
    static let gridLayout = "gridLayout"
    static let compactLayout = "compactLayout"
    static let defaultServings = "defaultServings"
    static let measurementSystem = "measurementSystem"
    static let defaultSort = "defaultSort"
    static let customCategories = "customCategories"
    static let cookKeepAwake = "cookKeepAwake"
    static let cookTextSize = "cookTextSize"
    static let cookShowStepIngredients = "cookShowStepIngredients"
    static let timerAlerts = "timerAlerts"
    static let haptics = "haptics"
    static let importUseAI = "importUseAI"
    static let importOCR = "importOCR"
    static let importFollowLinks = "importFollowLinks"
    static let importFetchCaptions = "importFetchCaptions"
    static let aiModel = "aiModel"
    static let recentSearches = "recentSearches"
    static let hasSeededDemo = "hasSeededDemo"
}

enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum AccentChoice: String, CaseIterable, Identifiable {
    case tangerine, tomato, berry, plum, ocean, mint, basil, cocoa
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var color: Color {
        switch self {
        case .tangerine: return Color(red: 0.90, green: 0.42, blue: 0.18)
        case .tomato: return Color(red: 0.86, green: 0.24, blue: 0.22)
        case .berry: return Color(red: 0.84, green: 0.22, blue: 0.47)
        case .plum: return Color(red: 0.52, green: 0.32, blue: 0.80)
        case .ocean: return Color(red: 0.16, green: 0.48, blue: 0.86)
        case .mint: return Color(red: 0.10, green: 0.62, blue: 0.58)
        case .basil: return Color(red: 0.28, green: 0.58, blue: 0.24)
        case .cocoa: return Color(red: 0.55, green: 0.36, blue: 0.24)
        }
    }
}

enum MeasurementSystem: String, CaseIterable, Identifiable {
    case original, metric, imperial
    var id: String { rawValue }
    var label: String {
        switch self {
        case .original: return "As Written"
        case .metric: return "Metric"
        case .imperial: return "US / Imperial"
        }
    }
}

enum CookTextSize: String, CaseIterable, Identifiable {
    case regular, large, huge
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var points: CGFloat {
        switch self {
        case .regular: return 22
        case .large: return 28
        case .huge: return 36
        }
    }
}

/// Applies the user's theme and accent colour. Attach to the root view and to every sheet's root.
struct ThemedModifier: ViewModifier {
    @AppStorage(SettingsKey.theme) private var theme = AppTheme.system.rawValue
    @AppStorage(SettingsKey.accent) private var accent = AccentChoice.tangerine.rawValue

    func body(content: Content) -> some View {
        let color = (AccentChoice(rawValue: accent) ?? .tangerine).color
        content
            .tint(color)
            .accentColor(color)
            .preferredColorScheme((AppTheme(rawValue: theme) ?? .system).colorScheme)
    }
}

extension View {
    func themed() -> some View { modifier(ThemedModifier()) }
    /// For sheets and full-screen covers: theme plus their own toast overlay (toasts would otherwise appear behind the sheet).
    func sheetStyle() -> some View { modifier(ThemedModifier()).toastHost() }
}

/// Default preference values, registered at launch so non-SwiftUI code sees the same defaults.
enum SettingsDefaults {
    static func register() {
        UserDefaults.standard.register(defaults: [
            SettingsKey.gridLayout: true,
            SettingsKey.compactLayout: false,
            SettingsKey.defaultServings: 4,
            SettingsKey.measurementSystem: MeasurementSystem.original.rawValue,
            SettingsKey.defaultSort: "Newest",
            SettingsKey.cookKeepAwake: true,
            SettingsKey.cookTextSize: CookTextSize.large.rawValue,
            SettingsKey.cookShowStepIngredients: true,
            SettingsKey.timerAlerts: true,
            SettingsKey.haptics: true,
            SettingsKey.importUseAI: true,
            SettingsKey.importOCR: true,
            SettingsKey.importFollowLinks: true,
            SettingsKey.importFetchCaptions: true,
            SettingsKey.aiModel: ClaudeModel.opus.rawValue
        ])
    }
}
