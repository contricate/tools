import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct IconStudioView: View {
    @Environment(AppModel.self) private var model
    @State private var themeID: UUID?
    @State private var selectedApps: Set<String> = Set(AppCatalog.apps.prefix(24).map(\.name))
    @State private var generating = false
    @State private var importingFiles = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var showAppChooser = false

    private var theme: Theme { model.library.theme(themeID) ?? model.activeTheme }

    var body: some View {
        Form {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(AppCatalog.apps.filter { selectedApps.contains($0.name) }.prefix(14)) { app in
                            VStack(spacing: 4) {
                                IconTile(spec: theme.icon, symbol: app.symbol, size: 54)
                                Text(app.name).font(.caption2).lineLimit(1).frame(width: 60)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
                Picker("Style from Theme", selection: Binding(get: { themeID ?? model.activeTheme.id }, set: { themeID = $0 })) {
                    ForEach(model.library.themes) { Text($0.name).tag($0.id) }
                }
                Button { showAppChooser = true } label: {
                    HStack { Text("Apps"); Spacer(); Text("\(selectedApps.count) selected").foregroundStyle(.secondary) }
                }
                NavigationLink(value: StudioRoute.themeEditor(theme.id)) { Label("Edit icon style", systemImage: "slider.horizontal.3") }
                Button { Task { await generate() } } label: {
                    HStack {
                        if generating { ProgressView() }
                        Label(generating ? "Generating…" : "Generate Icon Pack", systemImage: "wand.and.stars")
                    }
                }
                .disabled(generating || selectedApps.isEmpty)
            } header: {
                Text("Generate")
            } footer: {
                Text("Creates matching icons for each app in your theme's colours, shape and glyph style.")
            }

            Section {
                Button { importingFiles = true } label: { Label("Import from Files (images or a folder)", systemImage: "folder.badge.plus") }
                PhotosPicker(selection: $photoItems, maxSelectionCount: 60, matching: .images) {
                    Label("Import from Photos", systemImage: "photo.stack")
                }
            } header: {
                Text("Import a Pack")
            } footer: {
                Text("Icons from Files are matched to apps automatically by file name (e.g. “instagram.png”, “Spotify_icon@3x.png”). Photos don't keep file names, so you'll assign those yourself.")
            }

            Section("My Icon Packs") {
                if model.library.iconPacks.isEmpty {
                    Text("No packs yet.").foregroundStyle(.secondary)
                }
                ForEach(model.library.iconPacks) { pack in
                    NavigationLink(value: StudioRoute.iconPack(pack.id)) {
                        HStack(spacing: 12) {
                            HStack(spacing: -10) {
                                ForEach(pack.icons.prefix(3)) { icon in
                                    if let img = SharedStore.thumbnail(icon.imageID, maxSide: 90) {
                                        Image(uiImage: img).resizable().frame(width: 34, height: 34).clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                            }
                            VStack(alignment: .leading) {
                                Text(pack.name).font(.headline)
                                Text("\(pack.icons.count) icons · \(pack.icons.filter { !$0.url.isEmpty }.count) linked to apps")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onDelete { idx in for i in idx { model.delete(pack: model.library.iconPacks[i]) } }
            }

            Section {
                LimitNote(text: "iOS doesn't let apps change other apps' icons. Aura gives you three real ways: (1) install a pack as Home Screen icons using a configuration profile, (2) use Shortcuts' “Add to Home Screen” with a custom image, or (3) put them in an Aura launcher widget. You can also change Aura's own icon in Settings.")
            }
        }
        .auraScreen()
        .navigationTitle("Icons")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAppChooser) { AppMultiPicker(selection: $selectedApps) }
        .fileImporter(isPresented: $importingFiles, allowedContentTypes: [.image, .folder], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { importFiles(urls) }
        }
        .onChange(of: photoItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                var pack = IconPack(name: "Imported Pack")
                for item in items {
                    if let d = try? await item.loadTransferable(type: Data.self), let id = SharedStore.saveImage(d, maxSide: 512, keepPNG: true) {
                        pack.icons.append(IconItem(appName: "Icon \(pack.icons.count + 1)", imageID: id))
                    }
                }
                photoItems = []
                model.upsert(pack)
                model.show("Imported \(pack.icons.count) icons — tap the pack to assign apps")
                model.studioPath.append(StudioRoute.iconPack(pack.id))
            }
        }
    }

    private func generate() async {
        generating = true
        defer { generating = false }
        var pack = IconPack(name: "\(theme.name) Icons", generatedFromThemeID: theme.id)
        for app in AppCatalog.apps where selectedApps.contains(app.name) {
            guard let png = Exporter.iconPNG(spec: theme.icon, symbol: app.symbol),
                  let id = SharedStore.saveImage(png, maxSide: 512, keepPNG: true) else { continue }
            pack.icons.append(IconItem(appName: app.name, imageID: id, url: app.scheme))
            await Task.yield()
        }
        model.upsert(pack)
        model.show("Generated \(pack.icons.count) icons")
        model.studioPath.append(StudioRoute.iconPack(pack.id))
    }

    private func importFiles(_ urls: [URL]) {
        var files: [URL] = []
        var scoped: [URL] = []
        for url in urls {
            if url.startAccessingSecurityScopedResource() { scoped.append(url) }
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                let items = (FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil)?.allObjects as? [URL]) ?? []
                files += items.filter { ["png", "jpg", "jpeg", "heic", "webp"].contains($0.pathExtension.lowercased()) }
            } else {
                files.append(url)
            }
        }
        defer { scoped.forEach { $0.stopAccessingSecurityScopedResource() } }
        var pack = IconPack(name: urls.first.map { $0.deletingPathExtension().lastPathComponent } ?? "Imported Pack")
        var matched = 0
        for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            guard let data = try? Data(contentsOf: file), let id = SharedStore.saveImage(data, maxSide: 512, keepPNG: true) else { continue }
            let base = file.deletingPathExtension().lastPathComponent
            if let app = AppCatalog.match(fileName: file.lastPathComponent) {
                matched += 1
                pack.icons.append(IconItem(appName: app.name, imageID: id, url: app.scheme))
            } else {
                pack.icons.append(IconItem(appName: base, imageID: id))
            }
        }
        // Matched apps first, alphabetically; then the rest.
        pack.icons.sort { a, b in
            if a.url.isEmpty != b.url.isEmpty { return !a.url.isEmpty }
            return a.appName.localizedCaseInsensitiveCompare(b.appName) == .orderedAscending
        }
        guard !pack.icons.isEmpty else { model.show("No images found"); return }
        model.upsert(pack)
        model.show("Imported \(pack.icons.count) icons · matched \(matched) automatically")
        model.studioPath.append(StudioRoute.iconPack(pack.id))
    }
}

struct AppMultiPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: Set<String>

    var body: some View {
        NavigationStack {
            List(AppCatalog.apps) { app in
                Button {
                    if selection.contains(app.name) { selection.remove(app.name) } else { selection.insert(app.name) }
                } label: {
                    HStack {
                        Image(systemName: app.symbol).frame(width: 30)
                        Text(app.name).foregroundStyle(.primary)
                        Spacer()
                        if selection.contains(app.name) { Image(systemName: "checkmark").foregroundStyle(Color.accentColor) }
                    }
                }
            }
            .navigationTitle("Apps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(selection.count == AppCatalog.apps.count ? "None" : "All") {
                        selection = selection.count == AppCatalog.apps.count ? [] : Set(AppCatalog.apps.map(\.name))
                    }
                }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .auraScreen()
        }
    }
}

struct IconPackView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let packID: UUID
    @State private var editing: IconItem?
    @State private var share: ShareFile?
    @State private var fullScreen = true
    @State private var confirmDelete = false
    @State private var busy = false

    private var pack: IconPack? { model.library.iconPacks.first { $0.id == packID } }

    var body: some View {
        if let pack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4), spacing: 18) {
                        ForEach(pack.icons) { icon in
                            Button { editing = icon } label: {
                                VStack(spacing: 5) {
                                    if let img = SharedStore.thumbnail(icon.imageID, maxSide: 200) {
                                        Image(uiImage: img).resizable().scaledToFit().frame(width: 62, height: 62)
                                    }
                                    Text(icon.appName).font(.caption2).foregroundStyle(.white).lineLimit(1)
                                    if icon.url.isEmpty { Text("no link").font(.system(size: 9)).foregroundStyle(.orange) }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .glassCard()

                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel(title: "Use these icons")
                        Toggle("Open apps full screen (no Safari bar)", isOn: $fullScreen)
                        Button { installProfile(pack) } label: {
                            Label("Install as Home Screen Icons", systemImage: "square.and.arrow.down.on.square").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(pack.icons.allSatisfy { $0.url.isEmpty })
                        Text("Creates a configuration profile with one icon per app that has a link. Save it to Files, open it, then Settings → Profile Downloaded → Install. iOS labels it “Not Verified” because it's made on your phone — that's expected. Remove it anytime in Settings → General → VPN & Device Management.")
                            .font(.caption).foregroundStyle(.secondary)
                        Button { Task { await saveAll(pack) } } label: {
                            Label(busy ? "Saving…" : "Save All to Photos (for Shortcuts)", systemImage: "photo.on.rectangle").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(busy)
                        Text("Shortcuts method: Shortcuts → + → “Open App” → choose the app → Share → Add to Home Screen → tap the icon → Choose Photo.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .glassCard()

                    LimitNote(text: "Profile icons open apps through their public link (URL scheme). Most popular apps support this; a few system apps (like Camera) can't be opened this way. The original app icons stay in your App Library — move them off your Home Screen to complete the look.")

                    Button(role: .destructive) { confirmDelete = true } label: { Label("Delete Pack", systemImage: "trash") }
                }
                .padding()
            }
            .background(AuraBackdrop())
            .navigationTitle(pack.name)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $editing) { icon in IconItemEditor(packID: packID, item: icon) }
            .sheet(item: $share) { f in ShareSheet(items: [f.url]) }
            .confirmationDialog("Delete “\(pack.name)”?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete Pack", role: .destructive) { model.delete(pack: pack); dismiss() }
            }
        } else {
            ContentUnavailableView("Pack not found", systemImage: "app.dashed")
        }
    }

    private func installProfile(_ pack: IconPack) {
        let clips = pack.icons.compactMap { icon -> WebClipProfile.Clip? in
            guard !icon.url.isEmpty, let data = try? Data(contentsOf: SharedStore.imageURL(icon.imageID)) else { return nil }
            return WebClipProfile.Clip(label: icon.appName, url: icon.url, iconPNG: data)
        }
        guard let data = WebClipProfile.build(name: pack.name, clips: clips, fullScreen: fullScreen) else {
            model.show("Couldn't create the profile")
            return
        }
        share = ShareFile(url: Exporter.tempFile(data, name: "\(pack.name).mobileconfig"))
    }

    private func saveAll(_ pack: IconPack) async {
        busy = true
        defer { busy = false }
        let datas = pack.icons.compactMap { try? Data(contentsOf: SharedStore.imageURL($0.imageID)) }
        do {
            try await Exporter.saveToPhotos(datas)
            model.show("Saved \(datas.count) icons to Photos")
        } catch {
            model.show(error.localizedDescription)
        }
    }
}

struct IconItemEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let packID: UUID
    @State var item: IconItem
    @State private var choosing = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        if let img = SharedStore.thumbnail(item.imageID, maxSide: 300) {
                            Image(uiImage: img).resizable().scaledToFit().frame(width: 110, height: 110)
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
                Section("App") {
                    TextField("Label on Home Screen", text: $item.appName)
                    Button { choosing = true } label: { Label("Choose from App List", systemImage: "list.bullet") }
                    TextField("App link (URL scheme)", text: $item.url)
                        .font(.body.monospaced())
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                Section {
                    Button {
                        if let u = URL(string: item.url) {
                            UIApplication.shared.open(u) { ok in if !ok { model.show("That link didn't open an app") } }
                        }
                    } label: { Label("Test Link", systemImage: "arrow.up.forward.app") }
                    .disabled(item.url.isEmpty)
                }
                Section {
                    Button("Remove from Pack", role: .destructive) {
                        if var pack = model.library.iconPacks.first(where: { $0.id == packID }) {
                            pack.icons.removeAll { $0.id == item.id }
                            model.upsert(pack)
                        }
                        dismiss()
                    }
                }
            }
            .navigationTitle("Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if var pack = model.library.iconPacks.first(where: { $0.id == packID }),
                           let i = pack.icons.firstIndex(where: { $0.id == item.id }) {
                            pack.icons[i] = item
                            model.upsert(pack)
                        }
                        dismiss()
                    }
                    .bold()
                }
            }
            .sheet(isPresented: $choosing) {
                AppPickerSheet { app in
                    item.appName = app.name
                    item.url = app.scheme
                }
            }
            .auraScreen()
        }
        .presentationDetents([.medium, .large])
    }
}
