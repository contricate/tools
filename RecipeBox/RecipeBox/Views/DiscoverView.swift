import SwiftUI
import SwiftData

struct DiscoverView: View {
    @State private var query = ""
    @State private var results: [MealDB.Meal] = []
    @State private var searching = false
    @State private var randomPicks: [MealDB.Meal] = []
    @State private var rows: [String: [MealDB.Meal]] = [:]
    @State private var areas: [String] = []
    @State private var selectedArea: String?
    @State private var selectedCategory: String?
    @State private var mainIngredient = ""
    @State private var filtered: [MealDB.Meal] = []
    @State private var loadingFilter = false
    @State private var preview: MealDB.Meal?
    @State private var loadError: String?
    @State private var showingAI = false

    private let featured = ["Dessert", "Breakfast", "Vegetarian", "Seafood", "Chicken", "Pasta"]
    private let titles = ["Dessert": "Popular Desserts", "Breakfast": "Breakfast Ideas", "Vegetarian": "Vegetarian",
                          "Seafood": "Seafood", "Chicken": "Chicken Dinners", "Pasta": "Pasta Night"]

    private var isFiltering: Bool { selectedArea != nil || selectedCategory != nil || !mainIngredient.isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                searchBar
                filters
                if let loadError {
                    Label(loadError, systemImage: "wifi.exclamationmark").font(.subheadline).foregroundStyle(.secondary)
                }
                if !query.isEmpty {
                    grid("Results for “\(query)”", results, loading: searching)
                } else if isFiltering {
                    grid(filterTitle, filtered, loading: loadingFilter)
                } else {
                    aiCard
                    row("Random Picks", randomPicks, subtitle: "Shuffled each visit")
                    ForEach(featured, id: \.self) { c in
                        row(titles[c] ?? c, rows[c] ?? [])
                    }
                }
                Text("Recipes provided by TheMealDB, a free community database. It doesn't include cooking times, difficulty or calories — those are shown only where actually known.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .padding()
            .padding(.bottom, 60)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Discover")
        .sheet(item: $preview) { meal in DiscoverMealSheet(meal: meal).themed() }
        .sheet(isPresented: $showingAI) { AIIdeasSheet().themed() }
        .task { await loadHome() }
        .refreshable { randomPicks = []; await loadHome() }
    }

    private var filterTitle: String {
        [selectedCategory, selectedArea, mainIngredient.isEmpty ? nil : "with \(mainIngredient)"].compactMap { $0 }.joined(separator: " · ")
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search recipes (e.g. lasagna)", text: $query)
                .submitLabel(.search)
                .onSubmit { Task { await search() } }
            if !query.isEmpty {
                Button { query = ""; results = [] } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: DS.smallCorner))
    }

    private var filters: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Menu {
                        Button("Any") { selectedCategory = nil; Task { await applyFilters() } }
                        ForEach(MealDB.categories, id: \.self) { c in
                            Button(c) { selectedCategory = c; Task { await applyFilters() } }
                        }
                    } label: { filterChip("Meal: \(selectedCategory ?? "Any")", on: selectedCategory != nil) }
                    Menu {
                        Button("Any") { selectedArea = nil; Task { await applyFilters() } }
                        ForEach(areas, id: \.self) { a in
                            Button(a) { selectedArea = a; Task { await applyFilters() } }
                        }
                    } label: { filterChip("Cuisine: \(selectedArea ?? "Any")", on: selectedArea != nil) }
                    if isFiltering {
                        Button("Clear") {
                            selectedArea = nil; selectedCategory = nil; mainIngredient = ""; filtered = []
                        }
                        .font(.caption.bold())
                    }
                }
            }
            HStack {
                Image(systemName: "carrot").foregroundStyle(.secondary)
                TextField("Main ingredient (e.g. salmon)", text: $mainIngredient)
                    .onSubmit { Task { await applyFilters() } }
            }
            .font(.subheadline)
            .padding(10)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: DS.smallCorner))
        }
    }

    private func filterChip(_ text: String, on: Bool) -> some View {
        HStack(spacing: 4) { Text(text); Image(systemName: "chevron.down").font(.caption2) }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(on ? Color.accentColor : Color(.secondarySystemGroupedBackground), in: Capsule())
            .foregroundStyle(on ? .white : .primary)
    }

    private var aiCard: some View {
        Button { showingAI = true } label: {
            HStack(spacing: 14) {
                Image(systemName: "sparkles").font(.title2).foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Color.purple.gradient, in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Recipe Ideas").font(.headline)
                    Text("Filter by time, difficulty, diet and calories — suggestions are AI-generated, not from a source.")
                        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .card()
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func row(_ title: String, _ meals: [MealDB.Meal], subtitle: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: title, subtitle: subtitle)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    if meals.isEmpty {
                        ForEach(0..<3, id: \.self) { _ in SkeletonCard(height: 180).frame(width: 160) }
                    }
                    ForEach(meals.prefix(12)) { meal in
                        Button { preview = meal } label: { MealCard(meal: meal) }.buttonStyle(.plain)
                    }
                }
            }
            .scrollClipDisabled()
        }
    }

    @ViewBuilder
    private func grid(_ title: String, _ meals: [MealDB.Meal], loading: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: title, subtitle: loading ? nil : "\(meals.count) recipe\(meals.count == 1 ? "" : "s")")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 16) {
                if loading {
                    ForEach(0..<6, id: \.self) { _ in SkeletonCard(height: 180) }
                } else {
                    ForEach(meals) { meal in
                        Button { preview = meal } label: { MealCard(meal: meal) }.buttonStyle(.plain)
                    }
                }
            }
            if !loading && meals.isEmpty {
                Text("Nothing found. Try another search.").foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Loading

    private func loadHome() async {
        loadError = nil
        if areas.isEmpty { areas = (try? await MealDB.areas()) ?? [] }
        if randomPicks.isEmpty {
            var picks: [MealDB.Meal] = []
            await withTaskGroup(of: MealDB.Meal?.self) { group in
                for _ in 0..<8 { group.addTask { try? await MealDB.random() } }
                for await m in group { if let m, !picks.contains(where: { $0.id == m.id }) { picks.append(m) } }
            }
            randomPicks = picks
            if picks.isEmpty { loadError = "Couldn't reach TheMealDB. Check your connection and pull to refresh." }
        }
        for c in featured where rows[c] == nil {
            if let r = try? await MealDB.byCategory(c) { rows[c] = r.shuffled() }
        }
    }

    private func search() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        searching = true
        results = await MealDB.fuzzySearch(q)
        searching = false
    }

    /// TheMealDB filters one thing at a time, so results are intersected client-side.
    private func applyFilters() async {
        guard isFiltering else { filtered = []; return }
        loadingFilter = true
        var sets: [[MealDB.Meal]] = []
        if let c = selectedCategory, let r = try? await MealDB.byCategory(c) { sets.append(r) }
        if let a = selectedArea, let r = try? await MealDB.byArea(a) { sets.append(r) }
        let ing = mainIngredient.trimmingCharacters(in: .whitespaces)
        if !ing.isEmpty, let r = try? await MealDB.byIngredient(ing) { sets.append(r) }
        if var result = sets.first {
            for s in sets.dropFirst() {
                let ids = Set(s.map(\.id))
                result = result.filter { ids.contains($0.id) }
            }
            filtered = result
        } else {
            filtered = []
        }
        loadingFilter = false
    }
}

/// Loads a TheMealDB recipe and shows it in the standard preview with Save / Close.
struct DiscoverMealSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(ToastCenter.self) private var toasts
    @Environment(AppRouter.self) private var router
    @Query private var recipes: [Recipe]
    let meal: MealDB.Meal
    @State private var draft: RecipeDraft?

    var body: some View {
        NavigationStack {
            Group {
                if draft != nil {
                    RecipePreviewView(draft: Binding(get: { draft ?? RecipeDraft() }, set: { draft = $0 }),
                                      acceptTitle: "Save", rejectTitle: "Close",
                                      onAccept: save, onReject: { dismiss() })
                } else {
                    VStack(spacing: 16) {
                        SkeletonCard(height: 260)
                        SkeletonCard(height: 120)
                        SkeletonCard(height: 200)
                    }
                    .padding()
                    Spacer()
                }
            }
            .navigationTitle(meal.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
        .task { if draft == nil { draft = await MealDB.draft(from: meal) } }
    }

    private func save(_ d: RecipeDraft) {
        if let existing = recipes.first(where: { $0.sourceURL == d.sourceURL && !d.sourceURL.isEmpty }) {
            dismiss()
            toasts.show("Already in your cookbook", style: .info, actionTitle: "Open") { router.open(existing) }
            return
        }
        let r = d.makeRecipe()
        context.insert(r)
        dismiss()
        toasts.show("Saved “\(r.title)”", actionTitle: "Open") { router.open(r) }
    }
}
