import SwiftUI

struct StudioView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $model.studioPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    SectionLabel(title: "Design", subtitle: "Everything updates your live widgets and island")
                    grid([
                        (.themeEditor(model.activeTheme.id), "Theme", "Colours, fonts, glass, shapes", "paintpalette.fill", [Color.purple, .indigo]),
                        (.island, "Dynamic Island", "Live Activity designs", "capsule.fill", [.black, .purple]),
                        (.wallpaper, "Wallpaper", "Lock & Home, island halos", "photo.fill", [.pink, .orange]),
                        (.icons, "Icons", "Packs, import, install", "app.badge.fill", [.cyan, .blue]),
                        (.battery, "Battery & Charging", "Styles, low, charging screen", "battery.100.bolt", [.green, .teal]),
                        (.lockScreen, "Lock Screen", "Widgets & presets", "lock.fill", [.indigo, .blue])
                    ])
                    widgetsSection
                    SectionLabel(title: "More")
                    grid([
                        (.poster, "Contact Poster", "Themed poster images", "person.crop.rectangle.fill", [.orange, .red]),
                        (.controls, "Controls & Focus", "Control Center, Action button, Focus", "switch.2", [.gray, .blue]),
                        (.guides, "Guides", "Sounds, layouts, automations", "book.fill", [.teal, .green]),
                        (.capabilities, "What's Possible", "Honest iOS limits", "checklist", [.yellow, .orange])
                    ])
                }
                .padding()
                .padding(.bottom, 30)
            }
            .background(AuraBackdrop())
            .navigationTitle("Studio")
            .navigationDestination(for: StudioRoute.self) { route in
                switch route {
                case .themeEditor(let id): ThemeEditorView(themeID: id)
                case .widgetDesigner(let id): WidgetDesignerView(designID: id)
                case .island: IslandStudioView()
                case .wallpaper: WallpaperStudioView()
                case .icons: IconStudioView()
                case .iconPack(let id): IconPackView(packID: id)
                case .battery: BatteryStudioView()
                case .lockScreen: LockScreenStudioView()
                case .poster: PosterStudioView()
                case .controls: ControlsFocusView()
                case .charging: BatteryStudioView()
                case .capabilities: CapabilitiesView()
                case .guides: GuidesView()
                case .importExport: ImportExportView()
                }
            }
        }
    }

    private func grid(_ items: [(StudioRoute, String, String, String, [Color])]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                NavigationLink(value: item.0) {
                    ToolCard(title: item.1, subtitle: item.2, icon: item.3, colors: item.4)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var widgetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionLabel(title: "Widgets", subtitle: "Add with: long-press Home Screen → Edit → Add Widget → Aura")
                Menu {
                    ForEach(WidgetLayout.allCases) { layout in
                        Button { newWidget(layout) } label: { Label(layout.label, systemImage: layout.symbol) }
                    }
                } label: {
                    Image(systemName: "plus.circle.fill").font(.title2)
                }
                .accessibilityLabel("New widget design")
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(model.library.widgets) { d in
                        NavigationLink(value: StudioRoute.widgetDesigner(d.id)) {
                            VStack(alignment: .leading, spacing: 6) {
                                WidgetPreview(design: d, theme: model.library.resolvedTheme(for: d), family: .systemSmall, battery: model.battery)
                                    .frame(width: 140, height: 140)
                                Text(d.name).font(.caption.weight(.semibold)).foregroundStyle(.white).lineLimit(1)
                                Text(d.layout.label).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollClipDisabled()
        }
    }

    private func newWidget(_ layout: WidgetLayout) {
        var d = WidgetDesign(name: "My \(layout.label)", layout: layout)
        if layout == .launcher {
            d.links = AppCatalog.apps.prefix(4).map { LaunchLink(title: $0.name, url: $0.scheme, symbol: $0.symbol) }
        }
        if layout == .notifications {
            d.notifications = [FakeNotification(app: "Aura", title: "Hello ✨", body: "Edit me in Aura.", symbol: "sparkles")]
        }
        if layout == .quote { d.title = "Stay curious." }
        model.upsert(d)
        model.studioPath.append(StudioRoute.widgetDesigner(d.id))
    }
}

/// A widget rendered exactly as on the Home Screen (same view code as the widget extension).
struct WidgetPreview: View {
    let design: WidgetDesign
    let theme: Theme
    let family: WidgetFamilyPreview
    let battery: BatteryInfo

    var body: some View {
        WidgetCanvas(design: design, theme: theme, family: family.widgetFamily, battery: battery, date: .now)
            .padding(design.layout == .photo ? 0 : 16)
            .frame(width: family.size.width, height: family.size.height)
            .background(ThemeBackground(spec: theme.background, photoMaxSide: 800))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.08)))
    }
}

import WidgetKit
enum WidgetFamilyPreview: String, CaseIterable, Identifiable {
    case systemSmall, systemMedium, systemLarge
    var id: String { rawValue }
    var label: String { ["systemSmall": "Small", "systemMedium": "Medium", "systemLarge": "Large"][rawValue]! }
    /// iPhone 16 widget sizes in points.
    var size: CGSize {
        switch self {
        case .systemSmall: return CGSize(width: 170, height: 170)
        case .systemMedium: return CGSize(width: 364, height: 170)
        case .systemLarge: return CGSize(width: 364, height: 382)
        }
    }
    var widgetFamily: WidgetFamily {
        switch self {
        case .systemSmall: return .systemSmall
        case .systemMedium: return .systemMedium
        case .systemLarge: return .systemLarge
        }
    }
}
