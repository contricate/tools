import AppIntents
import SwiftUI
import UniformTypeIdentifiers

/// Focus filter: choose a theme per Focus (Settings → Focus → [Focus] → Add Filter → Aura).
struct AuraFocusFilter: SetFocusFilterIntent {
    static var title: LocalizedStringResource = "Set Aura Theme"
    static var description: IntentDescription? = IntentDescription("Use a different Aura theme while this Focus is on.")

    @Parameter(title: "Theme") var theme: ThemeEntity?

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "Aura", subtitle: "\(theme?.name ?? "No change")")
    }

    func perform() async throws -> some IntentResult {
        var lib = SharedStore.load()
        lib.focusThemeID = theme.flatMap { UUID(uuidString: $0.id) }
        SharedStore.save(lib)
        SharedStore.defaults.set(true, forKey: "pending.islandRefresh")
        return .result()
    }
}

/// Returns the active theme's wallpaper as an image — pair with Shortcuts' "Set Wallpaper" action.
struct GetWallpaperIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Aura Wallpaper"
    static var description = IntentDescription("Creates a wallpaper image from a theme. Add Shortcuts' “Set Wallpaper” after it to apply it automatically.")

    @Parameter(title: "Theme", description: "Leave empty to use the active theme") var theme: ThemeEntity?
    @Parameter(title: "Lock Screen version", default: true) var lockScreen: Bool

    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        let lib = SharedStore.load()
        let t = theme.flatMap { e in lib.themes.first { $0.id.uuidString == e.id } } ?? lib.currentTheme
        let data = await MainActor.run { Exporter.wallpaperPNG(t, variant: lockScreen ? .lock : .home) }
        guard let data else { throw ExportError.renderFailed }
        return .result(value: IntentFile(data: data, filename: "\(t.name) Wallpaper.png", type: .png))
    }
}

struct AuraShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartIslandIntent(), phrases: ["Start \(.applicationName) Island"], shortTitle: "Start Island", systemImageName: "capsule.fill")
        AppShortcut(intent: ChargingIslandIntent(), phrases: ["Show \(.applicationName) charging island"], shortTitle: "Charging Island", systemImageName: "bolt.fill")
        AppShortcut(intent: OpenAuraIntent(screen: .charging), phrases: ["Open \(.applicationName) charging screen"], shortTitle: "Charging Screen", systemImageName: "battery.100.bolt")
        AppShortcut(intent: NextThemeIntent(), phrases: ["Next \(.applicationName) theme"], shortTitle: "Next Theme", systemImageName: "paintpalette.fill")
        AppShortcut(intent: GetWallpaperIntent(), phrases: ["Get \(.applicationName) wallpaper"], shortTitle: "Get Wallpaper", systemImageName: "photo.fill")
    }
}
