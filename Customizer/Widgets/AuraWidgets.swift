import WidgetKit
import SwiftUI
import AppIntents

@main
struct AuraWidgetsBundle: WidgetBundle {
    var body: some Widget {
        DesignWidget()
        BatteryWidget()
        ClockWidget()
        LockNoteWidget()
        ThemeSwitcherWidget()
        AuraIslandLiveActivity()
        ApplyThemeControl()
        NextThemeControl()
        StartIslandControl()
        ChargingScreenControl()
    }
}

// MARK: - Shared timeline

struct AuraEntry: TimelineEntry {
    let date: Date
    let library: DesignLibrary
    let design: WidgetDesign?
    let theme: Theme
    let battery: BatteryInfo
}

/// Minute-by-minute entries for an hour so clocks stay current; battery is re-read on each reload.
func minuteEntries(library: DesignLibrary, design: WidgetDesign?, theme: Theme) -> Timeline<AuraEntry> {
    FontRegistry.registerAll()
    let battery = BatteryInfo.current()
    let start = Calendar.current.date(bySetting: .second, value: 0, of: .now) ?? .now
    let entries = (0..<60).map { i in
        AuraEntry(date: start.addingTimeInterval(Double(i) * 60), library: library, design: design, theme: theme, battery: battery)
    }
    // Battery widgets refresh sooner so the level doesn't lag too far behind (iOS still budgets refreshes).
    return Timeline(entries: entries, policy: .after(start.addingTimeInterval(15 * 60)))
}

// MARK: - Design widget (any layout, any home-screen size)

struct DesignProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> AuraEntry {
        let lib = DesignLibrary(themes: Presets.all, widgets: Presets.starterWidgets(themes: Presets.all), activeThemeID: Presets.all[3].id)
        return AuraEntry(date: .now, library: lib, design: lib.widgets[1], theme: Presets.all[3], battery: .preview)
    }

    func snapshot(for configuration: SelectDesignIntent, in context: Context) async -> AuraEntry {
        resolve(configuration).entries.first ?? placeholder(in: context)
    }

    func timeline(for configuration: SelectDesignIntent, in context: Context) async -> Timeline<AuraEntry> {
        resolve(configuration)
    }

    private func resolve(_ c: SelectDesignIntent) -> Timeline<AuraEntry> {
        let lib = SharedStore.load()
        let design = c.design.flatMap { e in lib.widgets.first { $0.id.uuidString == e.id } } ?? lib.widgets.first
        let theme = design.map { lib.resolvedTheme(for: $0) } ?? lib.currentTheme
        return minuteEntries(library: lib, design: design, theme: theme)
    }
}

struct DesignWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "aura.design", intent: SelectDesignIntent.self, provider: DesignProvider()) { entry in
            DesignWidgetView(entry: entry)
        }
        .configurationDisplayName("Aura Design")
        .description("Shows any widget you designed in Aura. Long-press → Edit Widget to choose a design.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

struct DesignWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AuraEntry

    var body: some View {
        Group {
            if let design = entry.design {
                WidgetCanvas(design: design, theme: entry.theme, family: family, battery: entry.battery, date: entry.date)
                    .padding(design.layout == .photo ? 0 : 16)
            } else {
                Text("Create a widget design in Aura").font(.caption).padding()
            }
        }
        .widgetURL(URL(string: "aura://widget/\(entry.design?.id.uuidString ?? "")"))
        .containerBackground(for: .widget) {
            ThemeBackground(spec: entry.theme.background, photoMaxSide: 900)
        }
    }
}

// MARK: - Theme-based providers (battery, clock)

struct ThemeProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> AuraEntry {
        AuraEntry(date: .now, library: DesignLibrary(themes: Presets.all), design: nil, theme: Presets.all[1], battery: .preview)
    }
    func snapshot(for configuration: SelectThemeIntent, in context: Context) async -> AuraEntry {
        resolve(configuration).entries.first ?? placeholder(in: context)
    }
    func timeline(for configuration: SelectThemeIntent, in context: Context) async -> Timeline<AuraEntry> {
        resolve(configuration)
    }
    private func resolve(_ c: SelectThemeIntent) -> Timeline<AuraEntry> {
        let lib = SharedStore.load()
        let theme = c.theme.flatMap { e in lib.themes.first { $0.id.uuidString == e.id } } ?? lib.currentTheme
        return minuteEntries(library: lib, design: nil, theme: theme)
    }
}

struct BatteryWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "aura.battery", intent: SelectThemeIntent.self, provider: ThemeProvider()) { entry in
            BatteryWidgetView(entry: entry)
        }
        .configurationDisplayName("Aura Battery")
        .description("Your battery in your theme's style — Home Screen, Lock Screen and StandBy.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct BatteryWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AuraEntry

    private var pct: Int { Int((entry.battery.level * 100).rounded()) }

    var body: some View {
        content
            .widgetURL(URL(string: "aura://battery"))
            .containerBackground(for: .widget) {
                if family.isAccessory { AccessoryWidgetBackground().opacity(family == .accessoryCircular ? 1 : 0) }
                else { ThemeBackground(spec: entry.theme.background, photoMaxSide: 700) }
            }
    }

    @ViewBuilder private var content: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: entry.battery.level) {
                Image(systemName: entry.battery.charging ? "bolt.fill" : "battery.100")
            } currentValueLabel: {
                Text("\(pct)")
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .widgetAccentable()
        case .accessoryRectangular:
            HStack(spacing: 8) {
                Gauge(value: entry.battery.level) { EmptyView() }
                    .gaugeStyle(.accessoryCircularCapacity)
                    .widgetAccentable()
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(pct)%").font(.system(.title3, design: .rounded).weight(.bold))
                    Text(entry.battery.charging ? "Charging" : (entry.battery.level <= entry.theme.battery.lowThreshold ? entry.theme.battery.lowMessage : "Battery"))
                        .font(.caption)
                }
                Spacer(minLength: 0)
            }
        case .accessoryInline:
            Label("\(pct)%\(entry.battery.charging ? " · Charging" : "")", systemImage: entry.battery.charging ? "bolt.fill" : "battery.75percent")
        case .systemMedium:
            WidgetCanvas(design: WidgetDesign(name: "", layout: .battery), theme: entry.theme, family: family, battery: entry.battery, date: entry.date)
        default:
            VStack(spacing: 6) {
                BatteryGraphic(theme: entry.theme, battery: entry.battery, size: 76)
                if entry.battery.charging {
                    Label("Charging", systemImage: "bolt.fill").font(entry.theme.font(size: 11))
                        .foregroundStyle(entry.theme.battery.chargingColor.color)
                }
            }
        }
    }
}

struct ClockWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "aura.clock", intent: SelectThemeIntent.self, provider: ThemeProvider()) { entry in
            ClockWidgetView(entry: entry)
        }
        .configurationDisplayName("Aura Clock")
        .description("Clock styles for the Home Screen and Lock Screen.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

struct ClockWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AuraEntry

    /// Lock Screen widgets are tinted by the system, so draw in white.
    private var monoTheme: Theme {
        var t = entry.theme
        t.text = .white
        t.accent = .white
        return t
    }

    var body: some View {
        content
            .containerBackground(for: .widget) {
                if family.isAccessory { Color.clear } else { ThemeBackground(spec: entry.theme.background, photoMaxSide: 700) }
            }
    }

    @ViewBuilder private var content: some View {
        switch family {
        case .accessoryCircular:
            ClockGraphic(theme: monoTheme, date: entry.date, size: 50, style: .analog).widgetAccentable()
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 0) {
                Text(entry.date.formatted(.dateTime.weekday(.wide))).font(.caption.weight(.bold)).widgetAccentable()
                Text(ClockWords.phrase(for: entry.date)).font(.system(.headline, design: .rounded)).lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            ClockGraphic(theme: entry.theme, date: entry.date, size: family == .systemSmall ? 48 : 64)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

/// Custom text on the Lock Screen — the inline slot sits above the clock, at the very top of the Lock Screen.
struct LockNoteWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "aura.locknote", intent: SelectDesignIntent.self, provider: DesignProvider()) { entry in
            LockNoteView(entry: entry)
        }
        .configurationDisplayName("Aura Lock Text")
        .description("Your own text above the Lock Screen clock (inline) or as a note. Uses a design's title & subtitle.")
        .supportedFamilies([.accessoryInline, .accessoryRectangular])
    }
}

struct LockNoteView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AuraEntry

    var body: some View {
        let title = entry.design?.title.isEmpty == false ? entry.design!.title : "Make it yours"
        let subtitle = entry.design?.subtitle ?? ""
        Group {
            if family == .accessoryInline {
                Label(title, systemImage: entry.design?.symbol ?? "sparkles")
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    Label(title, systemImage: entry.design?.symbol ?? "sparkles").font(.headline).widgetAccentable()
                    if !subtitle.isEmpty { Text(subtitle).font(.caption).lineLimit(2) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }
}

// MARK: - Interactive theme switcher

struct ThemeSwitcherWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "aura.switcher", provider: SwitcherProvider()) { entry in
            ThemeSwitcherView(entry: entry)
        }
        .configurationDisplayName("Theme Switcher")
        .description("Tap to switch your active theme right from the Home Screen.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct SwitcherProvider: TimelineProvider {
    func placeholder(in context: Context) -> AuraEntry {
        AuraEntry(date: .now, library: DesignLibrary(themes: Presets.all, activeThemeID: Presets.all[0].id), design: nil, theme: Presets.all[0], battery: .preview)
    }
    func getSnapshot(in context: Context, completion: @escaping (AuraEntry) -> Void) {
        let lib = SharedStore.load()
        completion(AuraEntry(date: .now, library: lib, design: nil, theme: lib.currentTheme, battery: .preview))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<AuraEntry>) -> Void) {
        let lib = SharedStore.load()
        completion(Timeline(entries: [AuraEntry(date: .now, library: lib, design: nil, theme: lib.currentTheme, battery: .preview)], policy: .never))
    }
}

struct ThemeSwitcherView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AuraEntry

    var body: some View {
        let themes = Array(entry.library.themes.prefix(family == .systemSmall ? 4 : 8))
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.theme.name).font(entry.theme.font(size: 13, weightOverride: 7)).lineLimit(1)
                Spacer()
                Button(intent: NextThemeIntent()) { Image(systemName: "arrow.triangle.2.circlepath") }
                    .buttonStyle(.plain)
            }
            .foregroundStyle(entry.theme.text.color)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: family == .systemSmall ? 2 : 4), spacing: 8) {
                ForEach(themes) { t in
                    Button(intent: ApplyThemeIntent(theme: ThemeEntity(t))) {
                        ZStack {
                            ThemeBackground(spec: t.background, photoMaxSide: 200)
                            Circle().fill(t.accent.color).frame(width: 12, height: 12)
                        }
                        .frame(height: family == .systemSmall ? 46 : 42)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white, lineWidth: t.id == entry.theme.id ? 2.5 : 0))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .containerBackground(for: .widget) { ThemeBackground(spec: entry.theme.background, photoMaxSide: 600) }
    }
}

extension WidgetFamily {
    var isAccessory: Bool {
        self == .accessoryCircular || self == .accessoryRectangular || self == .accessoryInline
    }
}
