import SwiftUI
import PhotosUI

struct WidgetDesignerView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let designID: UUID
    @State private var draft: WidgetDesign?
    @State private var family: WidgetFamilyPreview = .systemSmall
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var confirmDelete = false
    @State private var addingApp = false

    var body: some View {
        VStack(spacing: 0) {
            if let d = draft {
                VStack(spacing: 10) {
                    Picker("Size", selection: $family) {
                        ForEach(WidgetFamilyPreview.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    WidgetPreview(design: d, theme: model.library.resolvedTheme(for: d), family: family, battery: model.battery)
                        .scaleEffect(family == .systemLarge ? 0.62 : 0.9)
                        .frame(height: family == .systemLarge ? 245 : 160)
                        .animation(.spring(duration: 0.35), value: family)
                }
                .padding()
                .background(.ultraThinMaterial.opacity(0.6))
                Form { editor(Binding(get: { draft ?? d }, set: { draft = $0 })) }
                    .auraScreen()
            }
        }
        .background(AuraBackdrop())
        .navigationTitle(draft?.name ?? "Widget")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if draft == nil { draft = model.library.widgets.first { $0.id == designID } } }
        .task(id: draft) {
            guard let d = draft, d != model.library.widgets.first(where: { $0.id == d.id }) else { return }
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            model.upsert(d)
        }
        .onChange(of: photoItems) { _, items in
            Task {
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self), let id = SharedStore.saveImage(data, maxSide: 1000) {
                        draft?.photoIDs.append(id)
                    }
                }
                photoItems = []
            }
        }
        .confirmationDialog("Delete this widget design?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let d = draft { model.delete(design: d) }
                dismiss()
            }
        } message: { Text("Widgets on your Home Screen using it will show your first design instead.") }
        .sheet(isPresented: $addingApp) {
            AppPickerSheet { app in
                draft?.links.append(LaunchLink(title: app.name, url: app.scheme, symbol: app.symbol))
            }
        }
    }

    @ViewBuilder
    private func editor(_ d: Binding<WidgetDesign>) -> some View {
        Section("Design") {
            TextField("Name", text: d.name)
            Picker("Layout", selection: d.layout) {
                ForEach(WidgetLayout.allCases) { Label($0.label, systemImage: $0.symbol).tag($0) }
            }
            Picker("Theme", selection: d.themeID) {
                Text("Follow Active Theme").tag(UUID?.none)
                ForEach(model.library.themes) { Text($0.name).tag(Optional($0.id)) }
            }
        }
        switch d.wrappedValue.layout {
        case .photo:
            Section {
                PhotosPicker(selection: $photoItems, maxSelectionCount: 12, matching: .images) {
                    Label("Add Photos", systemImage: "photo.badge.plus")
                }
                if !d.wrappedValue.photoIDs.isEmpty {
                    ScrollView(.horizontal) {
                        HStack {
                            ForEach(d.wrappedValue.photoIDs, id: \.self) { id in
                                if let img = SharedStore.thumbnail(id, maxSide: 160) {
                                    Image(uiImage: img).resizable().scaledToFill().frame(width: 60, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .overlay(alignment: .topTrailing) {
                                            Button { d.wrappedValue.photoIDs.removeAll { $0 == id } } label: {
                                                Image(systemName: "xmark.circle.fill").foregroundStyle(.white, .black)
                                            }
                                        }
                                }
                            }
                        }
                    }
                }
                TextField("Caption (optional)", text: d.title)
            } header: { Text("Photos") } footer: { Text("With several photos, the widget shows a different one every hour.") }
        case .quote, .statusStrip, .clock, .battery:
            Section("Text") {
                TextField(d.wrappedValue.layout == .quote ? "Quote" : "Title", text: d.title, axis: .vertical)
                TextField("Subtitle", text: d.subtitle)
                if d.wrappedValue.layout == .statusStrip { SymbolRow(title: "Island Glyph", symbol: d.symbol) }
            }
        case .countdown:
            Section("Countdown") {
                TextField("Event", text: d.title)
                DatePicker("Date", selection: d.countdownDate, displayedComponents: .date)
                SymbolRow(title: "Symbol", symbol: d.symbol)
            }
        case .launcher:
            Section {
                ForEach(d.links) { $link in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            IconTile(spec: model.library.resolvedTheme(for: d.wrappedValue).icon, symbol: link.symbol,
                                     image: SharedStore.thumbnail(link.imageID, maxSide: 120), size: 36)
                            TextField("Label", text: $link.title)
                        }
                        TextField("URL or app link", text: $link.url)
                            .font(.caption.monospaced())
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                        HStack {
                            SymbolRow(title: "Glyph", symbol: $link.symbol)
                        }
                        PhotoField(title: "Custom Icon Image", imageID: $link.imageID, maxSide: 300)
                    }
                }
                .onDelete { d.wrappedValue.links.remove(atOffsets: $0) }
                .onMove { d.wrappedValue.links.move(fromOffsets: $0, toOffset: $1) }
                Button { addingApp = true } label: { Label("Add App", systemImage: "plus.app") }
                Button { d.wrappedValue.links.append(LaunchLink(title: "Website", url: "https://", symbol: "globe")) } label: {
                    Label("Add Website or Custom Link", systemImage: "link")
                }
            } header: {
                Text("Apps (\(d.wrappedValue.links.count)) · Small 4 · Medium 8 · Large 12")
            } footer: {
                Text("Tapping an app briefly opens Aura, which then opens it — iOS widgets can only open their own app directly. Apps open via their public link schemes.")
            }
        case .notifications:
            Section {
                ForEach(d.notifications) { $n in
                    VStack(alignment: .leading) {
                        HStack { SymbolRow(title: "", symbol: $n.symbol).frame(width: 60); TextField("App", text: $n.app) }
                        TextField("Title", text: $n.title)
                        TextField("Message", text: $n.body)
                        TextField("Time", text: $n.time)
                    }
                }
                .onDelete { d.wrappedValue.notifications.remove(atOffsets: $0) }
                Button {
                    d.wrappedValue.notifications.append(FakeNotification(app: "Aura", title: "New message", body: "Write anything here."))
                } label: { Label("Add Banner", systemImage: "plus") }
            } header: { Text("Banners") } footer: { Text("Decorative notification-style banners. They don't show real notifications — iOS doesn't share those with apps.") }
        case .date, .combo:
            Section { Text("This layout uses the date, time and battery automatically.").foregroundStyle(.secondary) }
        }
        Section {
            Label("Long-press your Home Screen → Edit → Add Widget → Aura → “Aura Design”. Then long-press the widget → Edit Widget → choose “\(d.wrappedValue.name)”.",
                  systemImage: "plus.square.on.square")
                .font(.footnote)
        } header: { Text("Add to Home Screen") }
        Section {
            Button(role: .destructive) { confirmDelete = true } label: { Label("Delete Design", systemImage: "trash") }
        }
    }
}

struct AppPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onPick: (CatalogApp) -> Void
    @State private var search = ""

    var body: some View {
        NavigationStack {
            List(AppCatalog.apps.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }) { app in
                Button {
                    onPick(app)
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: app.symbol).frame(width: 30)
                        Text(app.name).foregroundStyle(.primary)
                        Spacer()
                        Text(app.scheme).font(.caption2.monospaced()).foregroundStyle(.secondary)
                    }
                }
            }
            .searchable(text: $search)
            .navigationTitle("Choose App")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .auraScreen()
        }
    }
}
