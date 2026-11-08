import SwiftUI
import SwiftData

struct ImportRecipeView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    var onImported: (Recipe) -> Void

    @State private var link = ""
    @State private var loading = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://www.example.com/best-lasagna", text: $link)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.go)
                        .onSubmit(runImport)
                    PasteButton(payloadType: String.self) { strings in
                        if let s = strings.first { link = s.trimmingCharacters(in: .whitespacesAndNewlines) }
                    }
                } header: {
                    Text("Recipe web page")
                } footer: {
                    Text("Works with most recipe sites. In Safari, tap Share → Copy, then paste the link here. The title, photo, ingredients, steps and times are filled in for you.")
                }

                if let errorText {
                    Section {
                        Label(errorText, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button(action: runImport) {
                        HStack {
                            Spacer()
                            if loading {
                                ProgressView()
                                Text("Importing…").padding(.leading, 6)
                            } else {
                                Label("Import Recipe", systemImage: "square.and.arrow.down")
                                    .font(.headline)
                            }
                            Spacer()
                        }
                    }
                    .disabled(link.trimmingCharacters(in: .whitespaces).isEmpty || loading)
                }
            }
            .navigationTitle("Import from Web")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private func runImport() {
        guard !loading else { return }
        errorText = nil
        loading = true
        let input = link
        Task {
            do {
                let imported = try await RecipeImporter.fetch(input)
                let recipe = Recipe(title: imported.title, summary: imported.summary, category: imported.category,
                                    servings: imported.servings, prepMinutes: imported.prepMinutes,
                                    cookMinutes: imported.cookMinutes, ingredients: imported.ingredients,
                                    steps: imported.steps)
                recipe.sourceURL = imported.sourceURL
                recipe.photoData = imported.photoData
                await MainActor.run {
                    context.insert(recipe)
                    loading = false
                    dismiss()
                    onImported(recipe)
                }
            } catch {
                await MainActor.run {
                    errorText = error.localizedDescription
                    loading = false
                }
            }
        }
    }
}
