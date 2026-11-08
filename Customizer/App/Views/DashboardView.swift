import SwiftUI
import ActivityKit

struct DashboardView: View {
    @Environment(AppModel.self) private var model
    @State private var islandRunning = IslandController.isRunning
    @State private var islandError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    hero
                    quickActions
                    if !SharedStore.hasAppGroup { appGroupWarning }
                    themesCarousel
                    setupChecklist
                    NavigationLink {
                        CapabilitiesView()
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "checklist").font(.title2).foregroundStyle(.cyan)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("What iOS lets you customise").font(.headline)
                                Text("Supported, workarounds, entitlements, and what needs a jailbreak").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        }
                        .glassCard()
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .padding(.bottom, 30)
            }
            .background(AuraBackdrop())
            .navigationTitle("Aura")
            .onAppear { islandRunning = IslandController.isRunning }
        }
    }

    private var hero: some View {
        let theme = model.activeTheme
        return HStack(alignment: .center, spacing: 18) {
            PhonePreview(theme: theme, battery: model.battery, height: 300)
            VStack(alignment: .leading, spacing: 10) {
                Text("ACTIVE THEME").font(.caption2.weight(.heavy)).tracking(1.5).foregroundStyle(.secondary)
                Text(theme.name).font(.system(size: 30, weight: .bold, design: .rounded))
                if !theme.mood.isEmpty { Pill(text: theme.mood, color: theme.accent.color) }
                if model.library.focusThemeID != nil {
                    Pill(text: "Set by Focus", icon: "moon.fill", color: .indigo)
                }
                Spacer().frame(height: 4)
                NavigationLink {
                    ThemeEditorView(themeID: theme.id)
                } label: {
                    Label("Edit Theme", systemImage: "slider.horizontal.3").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                Button {
                    model.tab = .library
                } label: {
                    Label("Switch", systemImage: "arrow.triangle.2.circlepath").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.top, 4)
    }

    private var quickActions: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            Button {
                Task {
                    do {
                        if islandRunning { await IslandController.endAll() } else { try await IslandController.start(theme: model.activeTheme) }
                        islandRunning = IslandController.isRunning
                        model.show(islandRunning ? "Island started — look at the top of your screen" : "Island stopped")
                    } catch {
                        model.show("Couldn't start: \(IslandController.authorizationEnabled ? error.localizedDescription : "Live Activities are off in Settings")")
                    }
                }
            } label: {
                quick(islandRunning ? "Stop Island" : "Start Island", islandRunning ? "Live now" : "Dynamic Island design",
                      "capsule.fill", [.purple, .indigo])
            }
            Button { model.showCharging = true } label: {
                quick("Charging Screen", "Full-screen animation", "bolt.fill", [.yellow, .orange])
            }
            Button {
                model.tab = .studio
                model.studioPath = NavigationPath([StudioRoute.wallpaper])
            } label: {
                quick("Wallpaper", "Export for iPhone 16", "photo.fill", [.pink, .red])
            }
            Button {
                model.tab = .studio
                model.studioPath = NavigationPath([StudioRoute.icons])
            } label: {
                quick("Icon Packs", "Generate or import", "app.badge.fill", [.cyan, .blue])
            }
        }
        .buttonStyle(.plain)
    }

    private func quick(_ title: String, _ subtitle: String, _ icon: String, _ colors: [Color]) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                Text(subtitle).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .glassCard(padding: 12, radius: 18)
    }

    private var appGroupWarning: some View {
        LimitNote(text: "Widgets can't see your designs: this install has no App Group. Install with AltStore/SideStore (which support App Groups) or a paid developer account — see Settings → Installation.",
                  icon: "exclamationmark.triangle.fill")
    }

    private var themesCarousel: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(title: "Your themes", subtitle: "Tap to apply")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(model.library.themes) { t in
                        Button { model.apply(t) } label: {
                            VStack(spacing: 8) {
                                PhonePreview(theme: t, battery: model.battery, height: 170, showIcons: true)
                                Text(t.name).font(.caption.weight(.semibold)).foregroundStyle(.white)
                            }
                            .padding(6)
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(t.id == model.library.activeThemeID ? t.accent.color : .clear, lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 6)
            }
            .scrollClipDisabled()
        }
    }

    private var setupChecklist: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(title: "Make it yours in 5 steps")
            VStack(spacing: 0) {
                step(1, "Pick or design a theme", "Studio → Theme", .studio)
                step(2, "Save its wallpaper", "Long-press Lock Screen → + → Photos", .wallpaper)
                step(3, "Add Aura widgets", "Long-press Home Screen → Edit → Add Widget → Aura", .widgets)
                step(4, "Theme your app icons", "Generate a pack, then install as icons", .icons)
                step(5, "Start the Dynamic Island", "Or automate it with Shortcuts", .island)
            }
            .glassCard(padding: 4)
        }
    }

    enum StepTarget { case studio, wallpaper, widgets, icons, island }

    private func step(_ n: Int, _ title: String, _ detail: String, _ target: StepTarget) -> some View {
        Button {
            model.tab = .studio
            switch target {
            case .studio: model.studioPath = NavigationPath([StudioRoute.themeEditor(model.activeTheme.id)])
            case .wallpaper: model.studioPath = NavigationPath([StudioRoute.wallpaper])
            case .widgets: model.studioPath = NavigationPath()
            case .icons: model.studioPath = NavigationPath([StudioRoute.icons])
            case .island: model.studioPath = NavigationPath([StudioRoute.island])
            }
        } label: {
            HStack(spacing: 14) {
                Text("\(n)").font(.headline).frame(width: 30, height: 30)
                    .background(Color.accentColor.opacity(0.25), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .padding(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
