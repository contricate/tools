import SwiftUI
import SwiftData
import PhotosUI

private struct Line: Identifiable, Hashable {
    let id = UUID()
    var text: String
}

struct RecipeEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let recipe: Recipe?

    @State private var title = ""
    @State private var summary = ""
    @State private var category = "Dinner"
    @State private var servings = 4
    @State private var prepMinutes = 0
    @State private var cookMinutes = 0
    @State private var ingredients: [Line] = []
    @State private var steps: [Line] = []
    @State private var notes = ""
    @State private var sourceURL = ""
    @State private var photoData: Data?
    @State private var pickerItem: PhotosPickerItem?
    @State private var newIngredient = ""
    @State private var newStep = ""
    @State private var showingBulkIngredients = false
    @State private var bulkText = ""

    init(recipe: Recipe?) {
        self.recipe = recipe
        if let r = recipe {
            _title = State(initialValue: r.title)
            _summary = State(initialValue: r.summary)
            _category = State(initialValue: r.category)
            _servings = State(initialValue: r.servings)
            _prepMinutes = State(initialValue: r.prepMinutes)
            _cookMinutes = State(initialValue: r.cookMinutes)
            _ingredients = State(initialValue: r.ingredients.map { Line(text: $0) })
            _steps = State(initialValue: r.steps.map { Line(text: $0) })
            _notes = State(initialValue: r.notes)
            _sourceURL = State(initialValue: r.sourceURL)
            _photoData = State(initialValue: r.photoData)
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    photoPicker
                    TextField("Recipe name", text: $title)
                        .font(.headline)
                    TextField("Short description", text: $summary, axis: .vertical)
                        .lineLimit(1...3)
                }

                Section("Details") {
                    Picker("Category", selection: $category) {
                        ForEach(Recipe.categories, id: \.self) { Text($0).tag($0) }
                    }
                    Stepper("Serves \(servings)", value: $servings, in: 1...100)
                    Stepper("Prep: \(prepMinutes) min", value: $prepMinutes, in: 0...1440, step: 5)
                    Stepper("Cook: \(cookMinutes) min", value: $cookMinutes, in: 0...1440, step: 5)
                }

                Section {
                    ForEach($ingredients) { $line in
                        TextField("Ingredient", text: $line.text)
                    }
                    .onDelete { ingredients.remove(atOffsets: $0) }
                    .onMove { ingredients.move(fromOffsets: $0, toOffset: $1) }
                    HStack {
                        TextField("Add ingredient (e.g. 2 cups flour)", text: $newIngredient)
                            .onSubmit(addIngredient)
                        Button(action: addIngredient) {
                            Image(systemName: "plus.circle.fill")
                        }
                        .disabled(newIngredient.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    HStack {
                        Text("Ingredients")
                        Spacer()
                        Button("Paste List") { showingBulkIngredients = true }
                            .font(.caption)
                            .textCase(nil)
                    }
                }

                Section("Steps") {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, line in
                        HStack(alignment: .top) {
                            Text("\(index + 1).").foregroundStyle(.secondary)
                            TextField("Step", text: stepBinding(line.id), axis: .vertical)
                        }
                    }
                    .onDelete { steps.remove(atOffsets: $0) }
                    .onMove { steps.move(fromOffsets: $0, toOffset: $1) }
                    HStack(alignment: .top) {
                        TextField("Add a step", text: $newStep, axis: .vertical)
                        Button(action: addStep) {
                            Image(systemName: "plus.circle.fill")
                        }
                        .disabled(newStep.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                Section("Notes") {
                    TextField("Tips, substitutions, family history…", text: $notes, axis: .vertical)
                        .lineLimit(3...10)
                }

                Section("Source") {
                    TextField("Website link (optional)", text: $sourceURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle(recipe == nil ? "New Recipe" : "Edit Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).bold().disabled(!canSave)
                }
                ToolbarItem(placement: .bottomBar) {
                    EditButton()
                }
            }
            .onChange(of: pickerItem) { _, item in
                Task { await loadPhoto(item) }
            }
            .alert("Paste Ingredients", isPresented: $showingBulkIngredients) {
                TextField("One per line", text: $bulkText, axis: .vertical)
                Button("Add") {
                    let lines = bulkText
                        .split(whereSeparator: \.isNewline)
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                    ingredients.append(contentsOf: lines.map { Line(text: $0) })
                    bulkText = ""
                }
                Button("Cancel", role: .cancel) { bulkText = "" }
            } message: {
                Text("Paste a list with one ingredient per line.")
            }
        }
    }

    private var photoPicker: some View {
        PhotosPicker(selection: $pickerItem, matching: .images) {
            Group {
                if let data = photoData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 180)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "camera.fill").font(.title)
                        Text("Add Photo").font(.subheadline)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            if photoData != nil {
                Button("Remove Photo", systemImage: "trash", role: .destructive) {
                    photoData = nil
                    pickerItem = nil
                }
            }
        }
    }

    private func stepBinding(_ id: UUID) -> Binding<String> {
        Binding(
            get: { steps.first(where: { $0.id == id })?.text ?? "" },
            set: { value in
                if let i = steps.firstIndex(where: { $0.id == id }) { steps[i].text = value }
            }
        )
    }

    private func addIngredient() {
        let t = newIngredient.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        ingredients.append(Line(text: t))
        newIngredient = ""
    }

    private func addStep() {
        let t = newStep.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        steps.append(Line(text: t))
        newStep = ""
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        let maxSide: CGFloat = 1600
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let resized = UIGraphicsImageRenderer(size: size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        await MainActor.run {
            photoData = resized.jpegData(compressionQuality: 0.8)
        }
    }

    private func save() {
        addIngredient()
        addStep()
        let cleanIngredients = ingredients.map { $0.text.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let cleanSteps = steps.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let target = recipe ?? Recipe(title: "")
        target.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        target.summary = summary
        target.category = category
        target.servings = servings
        target.prepMinutes = prepMinutes
        target.cookMinutes = cookMinutes
        target.ingredients = cleanIngredients
        target.steps = cleanSteps
        target.notes = notes
        target.sourceURL = sourceURL.trimmingCharacters(in: .whitespaces)
        target.photoData = photoData
        if recipe == nil { context.insert(target) }
        dismiss()
    }
}
