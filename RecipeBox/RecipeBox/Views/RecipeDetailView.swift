import SwiftUI
import SwiftData
import PhotosUI

struct RecipeDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(ToastCenter.self) private var toasts
    @Bindable var recipe: Recipe

    @AppStorage(SettingsKey.measurementSystem) private var defaultSystem = MeasurementSystem.original.rawValue
    @State private var system: MeasurementSystem = .original
    @State private var servings = 0
    @State private var checkedIngredients: Set<Int> = []
    @State private var completedSteps: Set<Int> = []
    @State private var showingEdit = false
    @State private var showingDeleteConfirm = false
    @State private var showingCookMode = false
    @State private var showingPlan = false
    @State private var showingGroceries = false
    @State private var showingCollections = false
    @State private var showingAssistant = false
    @State private var showingConverter = false
    @State private var showingCustomServings = false
    @State private var customServingsText = ""
    @State private var shareItem: ShareItem?
    @State private var newNote = ""
    @State private var newNoteKind = "note"
    @State private var photoItem: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var cookedBounce = 0

    private var factor: Double {
        guard recipe.servings > 0, servings > 0 else { return 1 }
        return Double(servings) / Double(recipe.servings)
    }

    private func displayIngredient(_ line: String) -> String {
        UnitConverter.convert(IngredientScaler.scale(line, by: factor), to: system)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero
                VStack(alignment: .leading, spacing: 24) {
                    titleBlock
                    if !recipe.importWarnings.isEmpty { importNotes }
                    infoBar
                    if !recipe.steps.isEmpty { cookButton }
                    if !recipe.ingredients.isEmpty { ingredientsSection }
                    if !recipe.steps.isEmpty { stepsSection }
                    if !recipe.ingredients.isEmpty {
                        NutritionSummaryView(ingredients: recipe.ingredients, servings: max(1, recipe.servings))
                    }
                    if !recipe.notes.isEmpty {
                        section("Recipe Notes") {
                            Text(recipe.notes)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .card()
                        }
                    }
                    journalSection
                    photosSection
                    sourceSection
                    cookedSection
                }
                .padding()
            }
        }
        .background(Color(.systemGroupedBackground))
        .ignoresSafeArea(edges: recipe.photoData == nil ? [] : .top)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .sheet(isPresented: $showingEdit) { RecipeEditView(recipe: recipe).sheetStyle() }
        .sheet(isPresented: $showingPlan) { PlanRecipeSheet(recipe: recipe) { toasts.show($0) }.sheetStyle() }
        .sheet(isPresented: $showingGroceries) {
            GrocerySelectSheet(title: recipe.title, lines: recipe.ingredients.map(displayIngredient)).sheetStyle()
        }
        .sheet(isPresented: $showingCollections) { CollectionPickerSheet(recipe: recipe).sheetStyle() }
        .sheet(isPresented: $showingAssistant) { NavigationStack { AssistantView(recipe: recipe, embedded: true) }.sheetStyle() }
        .sheet(isPresented: $showingConverter) { ConverterView().sheetStyle() }
        .sheet(item: $shareItem) { item in ActivityView(items: item.items).ignoresSafeArea() }
        .fullScreenCover(isPresented: $showingCookMode) { CookModeView(recipe: recipe, factor: factor).sheetStyle() }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker { image in
                if let d = ImageUtil.downscaledJPEG(image) { addPhoto(d) }
            }
            .ignoresSafeArea()
        }
        .confirmationDialog("Delete “\(recipe.title)”?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("Delete Recipe", role: .destructive, action: deleteRecipe)
        }
        .alert("Servings", isPresented: $showingCustomServings) {
            TextField("Number of servings", text: $customServingsText).keyboardType(.numberPad)
            Button("Set") { if let n = Int(customServingsText), n > 0, n <= 500 { servings = n } }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear {
            if servings == 0 { servings = recipe.servings }
            system = MeasurementSystem(rawValue: defaultSystem) ?? .original
            recipe.lastViewed = Date()
        }
        .onChange(of: recipe.servings) { _, new in servings = new }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let d = try? await item.loadTransferable(type: Data.self), let j = ImageUtil.downscaledJPEG(d) { addPhoto(j) }
                photoItem = nil
            }
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                recipe.isFavorite.toggle()
            } label: {
                Image(systemName: recipe.isFavorite ? "heart.fill" : "heart")
                    .foregroundStyle(.pink)
                    .symbolEffect(.bounce, value: recipe.isFavorite)
            }
            .accessibilityLabel(recipe.isFavorite ? "Remove from favorites" : "Add to favorites")
            .sensoryFeedback(.impact, trigger: recipe.isFavorite)
            Button { showingAssistant = true } label: { Image(systemName: "sparkles") }
                .accessibilityLabel("Ask the cooking assistant")
            Menu {
                Section {
                    Button("Edit Recipe", systemImage: "pencil") { showingEdit = true }
                    Button("Add to Meal Plan", systemImage: "calendar.badge.plus") { showingPlan = true }
                    Button("Add to Groceries", systemImage: "cart.badge.plus") { showingGroceries = true }
                    Button("Add to Collection", systemImage: "folder.badge.plus") { showingCollections = true }
                }
                Section("Share & Export") {
                    ShareLink(item: recipe.shareText) { Label("Share as Text", systemImage: "text.quote") }
                    Button("Copy Recipe", systemImage: "doc.on.doc") {
                        UIPasteboard.general.string = recipe.shareText
                        toasts.show("Recipe copied")
                    }
                    Button("Export PDF", systemImage: "doc.richtext") { sharePDF() }
                    Button("Print", systemImage: "printer") { CookbookPDF.print([recipe], title: recipe.title) }
                    Button("Share Recipe File", systemImage: "square.and.arrow.up.on.square") { shareFile() }
                }
                Button("Duplicate", systemImage: "plus.square.on.square") { duplicate() }
                Button("Delete", systemImage: "trash", role: .destructive) { showingDeleteConfirm = true }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    // MARK: Header

    @ViewBuilder private var hero: some View {
        if let data = recipe.photoData, let image = UIImage(data: data) {
            Color.clear
                .frame(height: 330)
                .overlay { Image(uiImage: image).resizable().scaledToFill() }
                .clipped()
                .overlay(alignment: .bottom) {
                    LinearGradient(colors: [.clear, Color(.systemGroupedBackground)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 80)
                }
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label(recipe.category.uppercased(), systemImage: Recipe.icon(for: recipe.category))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.accentColor)
                if !recipe.cuisine.isEmpty {
                    Text("· \(recipe.cuisine.uppercased())").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                }
                if !recipe.difficulty.isEmpty {
                    Text("· \(recipe.difficulty.uppercased())").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                }
            }
            Text(recipe.title)
                .font(.system(.largeTitle, design: .serif).bold())
            if !recipe.summary.isEmpty {
                Text(recipe.summary).foregroundStyle(.secondary)
            }
            HStack {
                StarRating(rating: $recipe.rating, size: 22, editable: true)
                Spacer()
                if recipe.sourceKind != "manual" {
                    Badge(text: recipe.sourceLabel, icon: recipe.sourceIcon, color: recipe.sourceKind == "ai" ? .purple : .accentColor)
                }
            }
            if !recipe.tags.isEmpty || !(recipe.collections ?? []).isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(recipe.tags, id: \.self) { TagChip(text: $0) }
                    ForEach(recipe.collections ?? []) { c in
                        Label(c.name, systemImage: c.icon)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Color.accentColor.opacity(0.12), in: Capsule())
                    }
                }
            }
        }
    }

    private var importNotes: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(recipe.importWarnings, id: \.self) { Text("• \($0)").font(.subheadline) }
                Text("Ingredients marked (estimated) and steps marked [Estimated] were inferred, not stated in the source.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.top, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label("Import notes (\(recipe.importWarnings.count))", systemImage: "exclamationmark.triangle")
                .font(.subheadline.weight(.semibold)).foregroundStyle(.orange)
        }
        .padding()
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: DS.corner, style: .continuous))
    }

    private var infoBar: some View {
        HStack(spacing: 0) {
            info("timer", "Prep", recipe.prepMinutes > 0 ? Recipe.format(minutes: recipe.prepMinutes) : "—")
            Divider().frame(height: 34)
            info("flame", "Cook", recipe.cookMinutes > 0 ? Recipe.format(minutes: recipe.cookMinutes) : "—")
            Divider().frame(height: 34)
            info("clock", "Total", recipe.totalMinutes > 0 ? Recipe.format(minutes: recipe.totalMinutes) : "—")
            if !recipe.temperature.isEmpty {
                Divider().frame(height: 34)
                info("thermometer.medium", "Temp", UnitConverter.convertTemperatures(in: recipe.temperature, to: system))
            }
        }
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: DS.corner, style: .continuous))
    }

    private func info(_ icon: String, _ label: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon).foregroundStyle(Color.accentColor)
            Text(value).font(.subheadline.weight(.semibold)).multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.8)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var cookButton: some View {
        Button { showingCookMode = true } label: {
            HStack {
                Image(systemName: "frying.pan.fill")
                VStack(alignment: .leading, spacing: 0) {
                    Text(CookProgress.load(recipe.uid) == nil ? "Start Cooking" : "Resume Cooking").font(.headline)
                    Text("Step-by-step with timers").font(.caption).opacity(0.85)
                }
                Spacer()
                Text("\(recipe.steps.count) steps").font(.subheadline).opacity(0.85)
                Image(systemName: "chevron.right")
            }
            .padding()
            .foregroundStyle(.white)
            .background(Color.accentColor.gradient, in: RoundedRectangle(cornerRadius: DS.corner, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: Ingredients & steps

    private var ingredientsSection: some View {
        section("Ingredients") {
            VStack(spacing: 12) {
                HStack {
                    Text("Servings").font(.subheadline.weight(.medium))
                    Spacer()
                    HStack(spacing: 14) {
                        Button { servings = max(1, servings - 1) } label: { Image(systemName: "minus.circle.fill") }
                            .disabled(servings <= 1)
                            .accessibilityLabel("Fewer servings")
                        Button { customServingsText = "\(servings)"; showingCustomServings = true } label: {
                            Text("\(servings)")
                                .font(.headline.monospacedDigit())
                                .frame(minWidth: 32)
                                .contentTransition(.numericText())
                        }
                        .accessibilityLabel("\(servings) servings, tap to enter a number")
                        Button { servings = min(500, servings + 1) } label: { Image(systemName: "plus.circle.fill") }
                            .accessibilityLabel("More servings")
                    }
                    .font(.title2)
                    .animation(.snappy, value: servings)
                    .sensoryFeedback(.selection, trigger: servings)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach([0.5, 2, 3], id: \.self) { m in
                            Button("×\(m == 0.5 ? "½" : String(Int(m)))") { servings = max(1, Int((Double(recipe.servings) * m).rounded())) }
                                .buttonStyle(.bordered).controlSize(.small)
                        }
                        if servings != recipe.servings {
                            Button("Reset") { servings = recipe.servings }.buttonStyle(.bordered).controlSize(.small)
                        }
                    }
                }
                Picker("Units", selection: $system) {
                    ForEach(MeasurementSystem.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            .padding(12)
            .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: DS.smallCorner, style: .continuous))

            if servings != recipe.servings {
                Text("Amounts scaled from \(recipe.servings) to \(servings) servings").font(.caption).foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { index, item in
                    Button {
                        if checkedIngredients.contains(index) { checkedIngredients.remove(index) } else { checkedIngredients.insert(index) }
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: checkedIngredients.contains(index) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(checkedIngredients.contains(index) ? Color.accentColor : .secondary)
                            Text(displayIngredient(item))
                                .strikethrough(checkedIngredients.contains(index))
                                .foregroundStyle(checkedIngredients.contains(index) ? .secondary : .primary)
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .card()

            HStack {
                Button { showingGroceries = true } label: {
                    Label("Add to Groceries", systemImage: "cart.badge.plus")
                }
                Button { showingConverter = true } label: {
                    Label("Converter", systemImage: "scalemass")
                }
            }
            .buttonStyle(.bordered)
            .font(.subheadline.weight(.semibold))
        }
    }

    private var stepsSection: some View {
        section("Instructions") {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                    Button {
                        if completedSteps.contains(index) { completedSteps.remove(index) } else { completedSteps.insert(index) }
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            ZStack {
                                Circle().fill(completedSteps.contains(index) ? Color.secondary.opacity(0.3) : Color.accentColor)
                                if completedSteps.contains(index) {
                                    Image(systemName: "checkmark").font(.caption.bold())
                                } else {
                                    Text("\(index + 1)").font(.subheadline.bold())
                                }
                            }
                            .frame(width: 28, height: 28)
                            .foregroundStyle(.white)
                            Text(UnitConverter.convertTemperatures(in: step, to: system))
                                .foregroundStyle(completedSteps.contains(index) ? .secondary : .primary)
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .card()
        }
    }

    // MARK: Personal notes & photos

    private var journalSection: some View {
        section("My Notes") {
            VStack(alignment: .leading, spacing: 12) {
                let notes = (recipe.cookNotes ?? []).sorted { $0.date > $1.date }
                if notes.isEmpty {
                    Text("Write down changes you made or what to try next time — e.g. “Needs more garlic”.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                ForEach(notes) { note in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: note.kind == "change" ? "arrow.triangle.2.circlepath" : "note.text")
                            .foregroundStyle(note.kind == "change" ? .orange : Color.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(note.text)
                            Text("\(note.kind == "change" ? "Modification" : "Note") · \(note.date.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            withAnimation { context.delete(note) }
                        } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary) }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Delete note")
                    }
                }
                Divider()
                Picker("Type", selection: $newNoteKind) {
                    Text("Note").tag("note")
                    Text("Change I made").tag("change")
                }
                .pickerStyle(.segmented)
                HStack {
                    TextField(newNoteKind == "change" ? "e.g. Used half the sugar" : "e.g. Cook 5 minutes longer next time",
                              text: $newNote, axis: .vertical)
                    Button {
                        let t = newNote.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !t.isEmpty else { return }
                        let n = CookNote(text: t, kind: newNoteKind)
                        n.recipe = recipe
                        context.insert(n)
                        newNote = ""
                    } label: { Image(systemName: "arrow.up.circle.fill").font(.title2) }
                    .disabled(newNote.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityLabel("Add note")
                }
            }
            .card()
        }
    }

    private var photosSection: some View {
        section("My Photos") {
            let photos = (recipe.cookPhotos ?? []).sorted { $0.date > $1.date }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        VStack(spacing: 6) {
                            Image(systemName: "photo.badge.plus").font(.title2)
                            Text("Add").font(.caption.bold())
                        }
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 96, height: 96)
                        .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: DS.smallCorner))
                    }
                    .accessibilityLabel("Add a photo of your dish")
                    ForEach(photos) { p in
                        if let d = p.data, let ui = UIImage(data: d) {
                            Image(uiImage: ui).resizable().scaledToFill()
                                .frame(width: 96, height: 96)
                                .clipShape(RoundedRectangle(cornerRadius: DS.smallCorner, style: .continuous))
                                .contextMenu {
                                    Button("Use as Recipe Photo", systemImage: "photo") { recipe.photoData = d }
                                    Button("Delete Photo", systemImage: "trash", role: .destructive) { context.delete(p) }
                                }
                        }
                    }
                }
            }
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button { showingCamera = true } label: { Label("Take a Photo", systemImage: "camera") }
                    .font(.subheadline)
            }
        }
    }

    @ViewBuilder private var sourceSection: some View {
        if let url = URL(string: recipe.sourceURL), !recipe.sourceURL.isEmpty, url.scheme != nil {
            section("Source") {
                Link(destination: url) {
                    HStack {
                        Image(systemName: (VideoPlatform(rawValue: recipe.sourcePlatform) ?? VideoPlatform.detect(url)).icon)
                        Text(recipe.sourcePlatform.isEmpty ? (url.host ?? recipe.sourceURL) : "\(recipe.sourcePlatform) · \(url.host ?? "")")
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                    }
                    .card(padding: 12)
                }
            }
        }
    }

    private var cookedSection: some View {
        VStack(spacing: 8) {
            Button {
                recipe.timesCooked += 1
                recipe.lastCooked = Date()
                cookedBounce += 1
                toasts.show("Nice! Marked as cooked 🍽️")
            } label: {
                Label("I Made This!", systemImage: "checkmark.seal.fill")
                    .symbolEffect(.bounce, value: cookedBounce)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .sensoryFeedback(.success, trigger: cookedBounce)
            if recipe.timesCooked > 0 {
                Text("Made \(recipe.timesCooked) time\(recipe.timesCooked == 1 ? "" : "s")" +
                     (recipe.lastCooked.map { " · last on \($0.formatted(date: .abbreviated, time: .omitted))" } ?? ""))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.top, 8)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title2.bold())
            content()
        }
    }

    // MARK: Actions

    private func addPhoto(_ d: Data) {
        let p = CookPhoto(data: d)
        p.recipe = recipe
        context.insert(p)
        toasts.show("Photo added")
    }

    private func deleteRecipe() {
        let backup = RecipeBackup(recipe)
        let title = recipe.title
        CookProgress.clear(recipe.uid)
        context.delete(recipe)
        dismiss()
        toasts.show("Deleted “\(title)”", style: .info, actionTitle: "Undo") {
            context.insert(backup.makeRecipe())
        }
    }

    private func duplicate() {
        let copy = RecipeBackup(recipe).makeRecipe()
        copy.title = recipe.title + " (Copy)"
        copy.createdAt = Date()
        copy.timesCooked = 0
        copy.lastCooked = nil
        copy.uid = UUID().uuidString
        context.insert(copy)
        toasts.show("Duplicated")
    }

    private func sharePDF() {
        let data = CookbookPDF.render([recipe], title: recipe.title)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(RecipeShare.safeName(recipe.title) + ".pdf")
        try? data.write(to: url)
        shareItem = ShareItem(items: [url])
    }

    private func shareFile() {
        guard let url = RecipeShare.fileURL(for: [recipe], name: recipe.title) else { return }
        shareItem = ShareItem(items: [url])
    }
}

struct ShareItem: Identifiable {
    let id = UUID()
    let items: [Any]
}

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

enum RecipeShare {
    static func safeName(_ s: String) -> String {
        let cleaned = s.components(separatedBy: CharacterSet(charactersIn: "/\\?%*|\"<>:")).joined()
        return cleaned.isEmpty ? "Recipe" : String(cleaned.prefix(60))
    }

    /// Writes recipes to a Recipe Box JSON file that can be imported on another device.
    static func fileURL(for recipes: [Recipe], name: String) -> URL? {
        guard let data = Backup.export(recipes) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(safeName(name) + ".recipebox.json")
        try? data.write(to: url)
        return url
    }
}

/// Lets the user pick which ingredients go on the grocery list.
struct GrocerySelectSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(ToastCenter.self) private var toasts
    let title: String
    let lines: [String]
    @State private var selected: Set<Int> = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Array(lines.enumerated()), id: \.offset) { i, line in
                        Button {
                            if selected.contains(i) { selected.remove(i) } else { selected.insert(i) }
                        } label: {
                            HStack {
                                Image(systemName: selected.contains(i) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selected.contains(i) ? Color.accentColor : .secondary)
                                Text(line).foregroundStyle(.primary)
                                Spacer()
                                Text(GroceryAisle.classify(line)).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                } footer: {
                    Text("Matching items already on your list are combined when the units are compatible (e.g. 200 g + 300 g chicken = 500 g).")
                }
            }
            .navigationTitle("Add to Groceries")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarLeading) {
                    Button(selected.count == lines.count ? "None" : "All") {
                        selected = selected.count == lines.count ? [] : Set(lines.indices)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add \(selected.count)") {
                        let chosen = selected.sorted().map { lines[$0] }
                        let n = ShoppingItem.add(chosen, from: title, in: context)
                        toasts.show(n == 0 ? "Already on your list" : "Added to Groceries 🛒")
                        dismiss()
                    }
                    .bold()
                    .disabled(selected.isEmpty)
                }
            }
            .onAppear { selected = Set(lines.indices) }
        }
        .presentationDetents([.medium, .large])
    }
}
