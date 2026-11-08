import SwiftUI
import SwiftData

struct CreateRecipeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(ToastCenter.self) private var toasts
    @Environment(AppRouter.self) private var router
    @AppStorage(SettingsKey.defaultServings) private var defaultServings = 4

    @State private var prompt = ""
    @State private var servings = 4
    @State private var generating = false
    @State private var errorText: String?
    @State private var draft: RecipeDraft?
    @FocusState private var focused: Bool

    private let examples = ["Creamy garlic chicken pasta", "A cheap dinner for four", "High-protein breakfast",
                            "Something with chicken, potatoes and cheese", "A no-bake dessert", "30-minute vegetarian curry",
                            "Meal-prep lunches for the week", "Dinner without an oven"]

    var body: some View {
        NavigationStack {
            Group {
                if draft != nil {
                    RecipePreviewView(draft: Binding(get: { draft ?? RecipeDraft() }, set: { draft = $0 }),
                                      acceptTitle: "Save Recipe", rejectTitle: "Discard",
                                      onAccept: save, onReject: { draft = nil })
                } else {
                    form
                }
            }
            .navigationTitle(draft == nil ? "Create a Recipe" : "Your AI Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                if draft != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button { draft = nil; generate() } label: { Label("Regenerate", systemImage: "arrow.clockwise") }
                    }
                }
            }
            .onAppear { servings = defaultServings }
            .animation(.snappy, value: draft == nil)
        }
        .interactiveDismissDisabled(draft != nil)
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("What do you want to cook?").font(.title2.bold())
                    Text("Describe a dish, ingredients you have, or constraints like time, budget or diet.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                TextField("e.g. A creamy garlic chicken pasta ready in 30 minutes", text: $prompt, axis: .vertical)
                    .lineLimit(3...8)
                    .focused($focused)
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: DS.smallCorner))
                FlowLayout(spacing: 6) {
                    ForEach(examples, id: \.self) { e in
                        Button { prompt = e } label: { TagChip(text: e) }.buttonStyle(.plain)
                    }
                }
                Stepper("Servings: \(servings)", value: $servings, in: 1...24)
                    .card(padding: 12)
                if let errorText {
                    Label(errorText, systemImage: "exclamationmark.triangle").foregroundStyle(.red).font(.subheadline)
                }
                if !ClaudeClient.isConfigured {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Needs a Claude API key").font(.headline)
                        Text("Recipe creation uses Claude. Add your API key in Settings → AI Assistant.")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Button("Open Settings") { router.showSettings = true }
                    }
                    .card()
                }
                Button(action: generate) {
                    HStack {
                        if generating { ProgressView().tint(.white) }
                        Text(generating ? "Creating your recipe…" : "Create Recipe").font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(prompt.trimmingCharacters(in: .whitespaces).isEmpty || generating || !ClaudeClient.isConfigured)
                if generating {
                    VStack(spacing: 12) {
                        SkeletonCard(height: 60)
                        SkeletonCard(height: 160)
                    }
                }
                Label("Generated recipes are labelled “AI-generated” everywhere in the app, so you can tell them apart from recipes taken from a source.",
                      systemImage: "sparkles")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    private func generate() {
        focused = false
        errorText = nil
        generating = true
        Task {
            do {
                let drafts = try await RecipeGenerator.generate(prompt: prompt, servings: servings)
                if let d = drafts.first { draft = d } else { errorText = "No recipe was returned. Try rephrasing." }
            } catch {
                errorText = error.localizedDescription
            }
            generating = false
        }
    }

    private func save(_ d: RecipeDraft) {
        let r = d.makeRecipe()
        context.insert(r)
        dismiss()
        toasts.show("Saved “\(r.title)”", actionTitle: "Open") { router.open(r) }
    }
}

/// AI suggestions with filters that TheMealDB doesn't support (time, difficulty, diet, calories).
struct AIIdeasSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(ToastCenter.self) private var toasts
    @Environment(AppRouter.self) private var router
    @State private var maxTime = 45
    @State private var difficulty = "Any"
    @State private var diet = "None"
    @State private var calories = 0
    @State private var meal = "Dinner"
    @State private var cuisine = ""
    @State private var ideas: [RecipeDraft] = []
    @State private var selected: Int?
    @State private var loading = false
    @State private var errorText: String?

    private let diets = ["None", "Vegetarian", "Vegan", "Gluten-free", "Dairy-free", "High-protein", "Low-carb"]

    var body: some View {
        NavigationStack {
            Group {
                if let i = selected, i < ideas.count {
                    RecipePreviewView(draft: $ideas[i], acceptTitle: "Save", rejectTitle: "Back",
                                      onAccept: save, onReject: { selected = nil })
                } else {
                    list
                }
            }
            .navigationTitle("AI Recipe Ideas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }

    private var list: some View {
        Form {
            Section("Filters") {
                Picker("Meal", selection: $meal) { ForEach(Recipe.defaultCategories, id: \.self) { Text($0) } }
                Stepper("Ready in ≤ \(maxTime) min", value: $maxTime, in: 10...180, step: 5)
                Picker("Difficulty", selection: $difficulty) { ForEach(["Any"] + Recipe.difficulties, id: \.self) { Text($0) } }
                Picker("Diet", selection: $diet) { ForEach(diets, id: \.self) { Text($0) } }
                Stepper(calories == 0 ? "Calories: any" : "≤ \(calories) kcal per serving", value: $calories, in: 0...1500, step: 50)
                TextField("Cuisine (optional)", text: $cuisine)
            }
            Section {
                Button {
                    generate()
                } label: {
                    HStack { if loading { ProgressView() }; Text(loading ? "Thinking…" : "Suggest 3 Recipes") }
                }
                .disabled(loading || !ClaudeClient.isConfigured)
                if !ClaudeClient.isConfigured {
                    Text("Add a Claude API key in Settings to use AI ideas.").font(.caption).foregroundStyle(.secondary)
                }
                if let errorText { Text(errorText).foregroundStyle(.red).font(.caption) }
            } footer: {
                Text("These are AI-generated suggestions, not recipes from a source. Calorie targets are aimed for by the AI and then checked with the app's own estimate.")
            }
            if !ideas.isEmpty {
                Section("Suggestions") {
                    ForEach(Array(ideas.enumerated()), id: \.offset) { i, d in
                        Button { selected = i } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(d.title).font(.headline).foregroundStyle(.primary)
                                    Spacer()
                                    Badge(text: "AI", icon: "sparkles", color: .purple)
                                }
                                Text(d.summary).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                HStack(spacing: 10) {
                                    if d.prepMinutes + d.cookMinutes > 0 { Label(Recipe.format(minutes: d.prepMinutes + d.cookMinutes), systemImage: "clock") }
                                    if !d.difficulty.isEmpty { Label(d.difficulty, systemImage: "chart.bar") }
                                    let est = NutritionEstimator.estimate(d.ingredients.map(\.text))
                                    if est.isReliable {
                                        Label("≈\(Int(est.total.kcal / Double(max(1, d.servings)))) kcal", systemImage: "flame")
                                    }
                                }
                                .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private func generate() {
        loading = true
        errorText = nil
        var parts = ["\(meal) recipes ready in \(maxTime) minutes or less (prep + cook)."]
        if difficulty != "Any" { parts.append("Difficulty: \(difficulty).") }
        if diet != "None" { parts.append("Diet: \(diet).") }
        if calories > 0 { parts.append("About \(calories) kcal or less per serving.") }
        if !cuisine.isEmpty { parts.append("Cuisine: \(cuisine).") }
        Task {
            do {
                ideas = try await RecipeGenerator.generate(prompt: parts.joined(separator: " "),
                                                           servings: UserDefaults.standard.integer(forKey: SettingsKey.defaultServings),
                                                           count: 3)
                if ideas.isEmpty { errorText = "No ideas returned. Try different filters." }
            } catch { errorText = error.localizedDescription }
            loading = false
        }
    }

    private func save(_ d: RecipeDraft) {
        let r = d.makeRecipe()
        context.insert(r)
        selected = nil
        toasts.show("Saved “\(r.title)”", actionTitle: "Open") { dismiss(); router.open(r) }
    }
}
