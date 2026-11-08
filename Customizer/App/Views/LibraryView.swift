import SwiftUI

struct LibraryView: View {
    @Environment(AppModel.self) private var model
    @State private var previewing: Theme?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Complete looks — wallpaper, widgets, icons, battery, island and charging screen in one tap.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 22) {
                        ForEach(model.library.themes) { t in
                            Button { previewing = t } label: {
                                VStack(spacing: 10) {
                                    PhonePreview(theme: t, battery: model.battery, height: 300)
                                    HStack(spacing: 6) {
                                        Text(t.name).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                                        if t.id == model.library.activeThemeID {
                                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                        }
                                    }
                                    if !t.mood.isEmpty { Text(t.mood).font(.caption2).foregroundStyle(.secondary) }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
                .padding(.bottom, 30)
            }
            .background(AuraBackdrop())
            .navigationTitle("Themes")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        var t = Presets.amoled
                        t.id = UUID()
                        t.name = "My Theme"
                        t.isPreset = false
                        model.upsert(t)
                        previewing = t
                    } label: { Image(systemName: "plus") }
                    .accessibilityLabel("New theme")
                }
            }
            .sheet(item: $previewing) { t in ThemeDetailSheet(theme: t) }
        }
    }
}

struct ThemeDetailSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let theme: Theme
    @State private var variant: WallpaperVariant = .home

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Picker("", selection: $variant) {
                        ForEach(WallpaperVariant.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    PhonePreview(theme: theme, battery: model.battery, height: 470, variant: variant)
                    HStack(spacing: 16) {
                        BatteryGraphic(theme: theme, battery: model.battery, size: 54)
                        ClockGraphic(theme: theme, date: .now, size: 30, showDate: false)
                        IconTile(spec: theme.icon, symbol: "camera.fill", size: 50)
                    }
                    .padding()
                    .background(ThemeBackground(spec: theme.background, photoMaxSide: 600).clipShape(RoundedRectangle(cornerRadius: 22)))
                    VStack(spacing: 10) {
                        Button {
                            model.apply(theme)
                            dismiss()
                        } label: { Label("Apply Theme", systemImage: "sparkles").frame(maxWidth: .infinity) }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        HStack {
                            Button {
                                dismiss()
                                model.tab = .studio
                                model.studioPath = NavigationPath([StudioRoute.themeEditor(theme.id)])
                            } label: { Label("Edit", systemImage: "slider.horizontal.3").frame(maxWidth: .infinity) }
                            Button {
                                let copy = model.duplicate(theme)
                                dismiss()
                                model.tab = .studio
                                model.studioPath = NavigationPath([StudioRoute.themeEditor(copy.id)])
                            } label: { Label("Duplicate", systemImage: "plus.square.on.square").frame(maxWidth: .infinity) }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                    Text("After applying: save the wallpaper (Studio → Wallpaper), generate matching icons (Studio → Icons), and widgets following the active theme update automatically.")
                        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .padding()
            }
            .background(AuraBackdrop())
            .navigationTitle(theme.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }
}

struct MyDesignsView: View {
    @Environment(AppModel.self) private var model
    @State private var section = 0
    @State private var confirmDeleteTheme: Theme?

    var body: some View {
        NavigationStack {
            List {
                Picker("", selection: $section) {
                    Text("Themes").tag(0)
                    Text("Widgets").tag(1)
                    Text("Icon Packs").tag(2)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)

                switch section {
                case 0:
                    ForEach(model.library.themes) { t in
                        HStack(spacing: 14) {
                            PhonePreview(theme: t, battery: model.battery, height: 90)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(t.name).font(.headline)
                                Text("Edited \(t.updatedAt.formatted(.relative(presentation: .named)))").font(.caption).foregroundStyle(.secondary)
                                if t.id == model.library.activeThemeID { Pill(text: "Active", color: .green) }
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            model.tab = .studio
                            model.studioPath = NavigationPath([StudioRoute.themeEditor(t.id)])
                        }
                        .swipeActions {
                            Button(role: .destructive) { confirmDeleteTheme = t } label: { Label("Delete", systemImage: "trash") }
                            Button { _ = model.duplicate(t) } label: { Label("Duplicate", systemImage: "plus.square.on.square") }.tint(.indigo)
                        }
                        .swipeActions(edge: .leading) {
                            Button { model.apply(t) } label: { Label("Apply", systemImage: "sparkles") }.tint(.green)
                        }
                    }
                case 1:
                    ForEach(model.library.widgets) { d in
                        HStack(spacing: 14) {
                            WidgetPreview(design: d, theme: model.library.resolvedTheme(for: d), family: .systemSmall, battery: model.battery)
                                .scaleEffect(0.42).frame(width: 72, height: 72)
                            VStack(alignment: .leading) {
                                Text(d.name).font(.headline)
                                Text(d.layout.label).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            model.tab = .studio
                            model.studioPath = NavigationPath([StudioRoute.widgetDesigner(d.id)])
                        }
                        .swipeActions {
                            Button(role: .destructive) { model.delete(design: d) } label: { Label("Delete", systemImage: "trash") }
                            Button {
                                var copy = d
                                copy.id = UUID()
                                copy.name += " Copy"
                                model.upsert(copy)
                            } label: { Label("Duplicate", systemImage: "plus.square.on.square") }.tint(.indigo)
                        }
                    }
                default:
                    if model.library.iconPacks.isEmpty {
                        Text("Create packs in Studio → Icons.").foregroundStyle(.secondary)
                    }
                    ForEach(model.library.iconPacks) { p in
                        Button {
                            model.tab = .studio
                            model.studioPath = NavigationPath([StudioRoute.icons, StudioRoute.iconPack(p.id)])
                        } label: {
                            VStack(alignment: .leading) {
                                Text(p.name).font(.headline).foregroundStyle(.primary)
                                Text("\(p.icons.count) icons").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions { Button(role: .destructive) { model.delete(pack: p) } label: { Label("Delete", systemImage: "trash") } }
                    }
                }
            }
            .auraScreen()
            .navigationTitle("My Designs")
            .confirmationDialog("Delete “\(confirmDeleteTheme?.name ?? "")”?", isPresented: Binding(get: { confirmDeleteTheme != nil }, set: { if !$0 { confirmDeleteTheme = nil } }), titleVisibility: .visible) {
                Button("Delete Theme", role: .destructive) {
                    if let t = confirmDeleteTheme { model.delete(theme: t) }
                    confirmDeleteTheme = nil
                }
            }
        }
    }
}
