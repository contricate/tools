import SwiftUI
import WidgetKit

@main
struct AuraApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var phase

    init() {
        FontRegistry.registerAll()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(.dark)
                .tint(model.appAccent)
                .onOpenURL { model.handle(url: $0) }
                .onChange(of: phase) { _, p in if p == .active { model.becameActive() } }
                .onAppear { model.becameActive() }
        }
    }
}

enum AppTab: Hashable { case home, studio, library, designs, settings }

enum StudioRoute: Hashable {
    case themeEditor(UUID)
    case widgetDesigner(UUID)
    case island, wallpaper, icons, battery, lockScreen, poster, controls, charging, capabilities, guides, importExport, iconPack(UUID)
}

/// App-wide state: the design library (persisted in the shared App Group) plus navigation.
@MainActor
@Observable
final class AppModel {
    var library: DesignLibrary
    var tab: AppTab = .home
    var studioPath = NavigationPath()
    var showCharging = false
    var toast: String?
    var battery = BatteryInfo.current()

    init() {
        library = SharedStore.load()
        if !FileManager.default.fileExists(atPath: SharedStore.libraryURL.path) {
            SharedStore.save(library)
        }
        // Launch arguments used by CI to open specific screens for automated checks.
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-tab"), i + 1 < args.count {
            switch args[i + 1] {
            case "studio": tab = .studio
            case "library": tab = .library
            case "designs": tab = .designs
            case "settings": tab = .settings
            case "island": tab = .studio; studioPath = NavigationPath([StudioRoute.island])
            case "icons": tab = .studio; studioPath = NavigationPath([StudioRoute.icons])
            case "wallpaper": tab = .studio; studioPath = NavigationPath([StudioRoute.wallpaper])
            case "theme": tab = .studio; studioPath = NavigationPath([StudioRoute.themeEditor(library.currentTheme.id)])
            case "battery": tab = .studio; studioPath = NavigationPath([StudioRoute.battery])
            case "charging": showCharging = true
            default: break
            }
        }
        NotificationCenter.default.addObserver(forName: UIDevice.batteryLevelDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refreshBattery() }
        }
        NotificationCenter.default.addObserver(forName: UIDevice.batteryStateDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refreshBattery() }
        }
    }

    var appAccent: Color { Color(red: 0.62, green: 0.48, blue: 1) }

    var activeTheme: Theme { library.currentTheme }

    // MARK: Persistence

    func save(reloadWidgets: Bool = true) {
        SharedStore.save(library, reloadWidgets: reloadWidgets)
    }

    func upsert(_ theme: Theme) {
        var t = theme
        t.updatedAt = Date()
        if let i = library.themes.firstIndex(where: { $0.id == t.id }) { library.themes[i] = t } else { library.themes.append(t) }
        save()
        if t.id == library.effectiveThemeID { Task { await IslandController.update(theme: t) } }
    }

    func upsert(_ design: WidgetDesign) {
        if let i = library.widgets.firstIndex(where: { $0.id == design.id }) { library.widgets[i] = design } else { library.widgets.append(design) }
        save()
    }

    func upsert(_ pack: IconPack) {
        if let i = library.iconPacks.firstIndex(where: { $0.id == pack.id }) { library.iconPacks[i] = pack } else { library.iconPacks.append(pack) }
        save(reloadWidgets: false)
    }

    func apply(_ theme: Theme) {
        library.activeThemeID = theme.id
        save()
        Task { await IslandController.update(theme: theme) }
        show("Applied \(theme.name)")
    }

    func duplicate(_ theme: Theme) -> Theme {
        var copy = theme
        copy.id = UUID()
        copy.name = theme.name + " Copy"
        copy.isPreset = false
        copy.createdAt = Date()
        upsert(copy)
        return copy
    }

    func delete(theme: Theme) {
        library.themes.removeAll { $0.id == theme.id }
        if library.activeThemeID == theme.id { library.activeThemeID = library.themes.first?.id }
        if library.focusThemeID == theme.id { library.focusThemeID = nil }
        save()
    }

    func delete(design: WidgetDesign) {
        library.widgets.removeAll { $0.id == design.id }
        save()
    }

    func delete(pack: IconPack) {
        for icon in pack.icons { SharedStore.deleteImage(icon.imageID) }
        library.iconPacks.removeAll { $0.id == pack.id }
        save(reloadWidgets: false)
    }

    func show(_ message: String) {
        withAnimation(.spring(duration: 0.35)) { toast = message }
    }

    // MARK: Lifecycle

    func becameActive() {
        // Pick up changes made by widgets/Shortcuts/Focus while we were in the background.
        library = SharedStore.load()
        refreshBattery()
        let d = SharedStore.defaults
        if let route = d.string(forKey: "pending.route") {
            d.removeObject(forKey: "pending.route")
            open(route: route)
        }
        if d.bool(forKey: "pending.islandRefresh") {
            d.set(false, forKey: "pending.islandRefresh")
            Task { await IslandController.update(theme: activeTheme) }
        }
    }

    func refreshBattery() {
        battery = BatteryInfo.current()
        let device = UIDevice.current
        if device.batteryLevel >= 0 {
            SharedStore.storeBattery(level: device.batteryLevel, state: device.batteryState)
        }
        Task { await IslandController.update(theme: activeTheme) }
    }

    func open(route: String) {
        switch route {
        case "charging": showCharging = true
        case "island": tab = .studio; studioPath = NavigationPath([StudioRoute.island])
        case "wallpaper": tab = .studio; studioPath = NavigationPath([StudioRoute.wallpaper])
        default: tab = .studio
        }
    }

    func handle(url: URL) {
        if let target = LaunchURL.unwrap(url) {
            UIApplication.shared.open(target) { ok in
                if !ok { Task { @MainActor in self.show("That app isn't installed or doesn't support links") } }
            }
            return
        }
        guard url.scheme == "aura" else { return }
        switch url.host {
        case "battery": tab = .studio; studioPath = NavigationPath([StudioRoute.battery])
        case "island": open(route: "island")
        case "charging": showCharging = true
        case "open":
            if URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "app" })?.value == "camera" {
                show("iOS doesn't let apps open the Camera app directly — use the Lock Screen camera control.")
            }
        case "widget":
            if let id = UUID(uuidString: url.lastPathComponent), library.widgets.contains(where: { $0.id == id }) {
                tab = .studio
                studioPath = NavigationPath([StudioRoute.widgetDesigner(id)])
            }
        default: break
        }
    }
}
