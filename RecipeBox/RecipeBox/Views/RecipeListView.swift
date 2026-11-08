import SwiftUI
import SwiftData

enum RecipeSort: String, CaseIterable, Identifiable {
    case newest = "Newest"
    case oldest = "Oldest"
    case title = "A–Z"
    case rating = "Top Rated"
    case quickest = "Quickest"
    case mostCooked = "Most Cooked"
    case recentlyViewed = "Recently Viewed"
    var id: String { rawValue }
}

struct RecipeListView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router
    @Environment(ToastCenter.self) private var toasts
    @Query(sort: \Recipe.createdAt, order: .reverse) private var recipes: [Recipe]
    @Query(sort: \RecipeCollection.name) private var collections: [RecipeCollection]

    @AppStorage(SettingsKey.gridLayout) private var gridLayout = true
    @AppStorage(SettingsKey.compactLayout) private var compact = false
    @AppStorage(SettingsKey.defaultSort) private var defaultSort = RecipeSort.newest.rawValue
    @AppStorage(SettingsKey.recentSearches) private var recentSearchesRaw = ""
    @State private var searchText = ""
    @State private var selectedCategory: String? = nil
    @State private var selectedTag: String? = nil
    @State private var favoritesOnly = false
    @State private var sort: RecipeSort = .newest
    @State private var showingNew = false
    @State private var surpriseSpin = 0
    @State private var didApplyDefaultSort = false

    private var recentSearches: [String] { recentSearchesRaw.split(separator: "\n").map(String.init) }

    private var filtered: [Recipe] {
        var list = recipes
        if favoritesOnly { list = list.filter { $0.isFavorite } }
        if let cat = selectedCategory { list = list.filter { $0.category == cat } }
        if let tag = selectedTag { list = list.filter { $0.tags.contains(tag) } }
        let q = searchText.trimmingCharacters(in: .whitespaces)
        if !q.isEmpty {
            list = list.filter { r in
                r.title.localizedCaseInsensitiveContains(q)
                || r.summary.localizedCaseInsensitiveContains(q)
                || r.category.localizedCaseInsensitiveContains(q)
                || r.cuisine.localizedCaseInsensitiveContains(q)
                || r.tags.contains { $0.localizedCaseInsensitiveContains(q) }
                || r.ingredients.contains { $0.localizedCaseInsensitiveContains(q) }
            }
        }
        switch sort {
        case .newest: break
        case .oldest: list.reverse()
        case .title: list.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .rating: list.sort { $0.rating > $1.rating }
        case .quickest: list.sort { ($0.totalMinutes == 0 ? Int.max : $0.totalMinutes) < ($1.totalMinutes == 0 ? Int.max : $1.totalMinutes) }
        case .mostCooked: list.sort { $0.timesCooked > $1.timesCooked }
        case .recentlyViewed: list.sort { ($0.lastViewed ?? .distantPast) > ($1.lastViewed ?? .distantPast) }
        }
        return list
    }

    private var usedCategories: [String] {
        let used = Set(recipes.map(\.category))
        return Recipe.categories.filter { used.contains($0) } + used.filter { !Recipe.categories.contains($0) }.sorted()
    }

    private var usedTags: [String] {
        Array(Set(recipes.flatMap(\.tags))).sorted()
    }

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.cookbookPath) {
            Group {
                if recipes.isEmpty {
                    emptyState
                } else if gridLayout {
                    gridView
                } else {
                    listView
                }
            }
            .navigationTitle("Cookbook")
            .navigationDestination(for: Recipe.self) { RecipeDetailView(recipe: $0) }
            .navigationDestination(for: RecipeCollection.self) { CollectionDetailView(collection: $0) }
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .collections: CollectionsView()
                default: EmptyView()
                }
            }
            .toolbar { toolbarContent }
            .sheet(isPresented: $showingNew) { RecipeEditView(recipe: nil).themed() }
            .onAppear {
                if !didApplyDefaultSort {
                    sort = RecipeSort(rawValue: defaultSort) ?? .newest
                    didApplyDefaultSort = true
                }
            }
            .onChange(of: defaultSort) { _, new in sort = RecipeSort(rawValue: new) ?? .newest }
        }
    }

    // MARK: Layouts

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Your Cookbook is Empty", systemImage: "book.closed")
        } description: {
            Text("Add your own recipes, import one from a video or website, or start with a few samples.")
        } actions: {
            Button { showingNew = true } label: { Label("Add Recipe", systemImage: "plus") }
                .buttonStyle(.borderedProminent)
            Button { router.startImport() } label: { Label("Import Recipe", systemImage: "square.and.arrow.down") }
                .buttonStyle(.bordered)
            Button("Load Sample Recipes") { SampleRecipes.insert(into: context) }
        }
    }

    private var gridView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                filterBars
                if filtered.isEmpty { noMatches.padding(.top, 40) }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: compact ? 110 : 160), spacing: compact ? 10 : 14)],
                          spacing: compact ? 10 : 14) {
                    ForEach(filtered) { recipe in
                        NavigationLink(value: recipe) {
                            RecipeCard(recipe: recipe, compact: compact)
                        }
                        .buttonStyle(.plain)
                        .contextMenu { contextActions(for: recipe) }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 80)
                .animation(.snappy, value: filtered.map(\.persistentModelID))
            }
        }
        .background(Color(.systemGroupedBackground))
        .searchable(text: $searchText, prompt: "Name, ingredient, tag…")
        .searchSuggestions { suggestions }
        .onSubmit(of: .search) { rememberSearch() }
    }

    private var listView: some View {
        List {
            filterBars
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            ForEach(filtered) { recipe in
                NavigationLink(value: recipe) {
                    RecipeRow(recipe: recipe, compact: compact)
                }
                .contextMenu { contextActions(for: recipe) }
                .swipeActions(edge: .leading) {
                    Button {
                        recipe.isFavorite.toggle()
                    } label: {
                        Label("Favorite", systemImage: recipe.isFavorite ? "heart.slash" : "heart")
                    }
                    .tint(.pink)
                }
            }
            .onDelete { offsets in
                let items = offsets.map { filtered[$0] }
                for r in items { delete(r) }
            }
            if filtered.isEmpty {
                noMatches.listRowBackground(Color.clear)
            }
        }
        .searchable(text: $searchText, prompt: "Name, ingredient, tag…")
        .searchSuggestions { suggestions }
        .onSubmit(of: .search) { rememberSearch() }
    }

    @ViewBuilder private var suggestions: some View {
        if searchText.isEmpty {
            ForEach(recentSearches.prefix(5), id: \.self) { s in
                Label(s, systemImage: "clock.arrow.circlepath").searchCompletion(s)
            }
            ForEach(usedTags.prefix(6), id: \.self) { t in
                Label(t, systemImage: "tag").searchCompletion(t)
            }
        } else {
            let lower = searchText.lowercased()
            ForEach(recipes.filter { $0.title.lowercased().hasPrefix(lower) }.prefix(5)) { r in
                Label(r.title, systemImage: "fork.knife").searchCompletion(r.title)
            }
        }
    }

    private func rememberSearch() {
        let q = searchText.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        var list = recentSearches.filter { $0.caseInsensitiveCompare(q) != .orderedSame }
        list.insert(q, at: 0)
        recentSearchesRaw = list.prefix(8).joined(separator: "\n")
    }

    private var noMatches: some View {
        VStack(spacing: 8) {
            Text("No matching recipes").foregroundStyle(.secondary)
            if selectedCategory != nil || selectedTag != nil || favoritesOnly {
                Button("Clear Filters") { clearFilters() }.font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func clearFilters() {
        withAnimation(.snappy) {
            selectedCategory = nil
            selectedTag = nil
            favoritesOnly = false
        }
    }

    @ViewBuilder
    private func contextActions(for recipe: Recipe) -> some View {
        Button(recipe.isFavorite ? "Unfavorite" : "Favorite", systemImage: recipe.isFavorite ? "heart.slash" : "heart") {
            recipe.isFavorite.toggle()
        }
        Button("Start Cooking", systemImage: "frying.pan") { router.cookRecipe = recipe }
            .disabled(recipe.steps.isEmpty)
        ShareLink(item: recipe.shareText) { Label("Share", systemImage: "square.and.arrow.up") }
        Button("Delete", systemImage: "trash", role: .destructive) { delete(recipe) }
    }

    private func delete(_ recipe: Recipe) {
        let backup = RecipeBackup(recipe)
        let title = recipe.title
        context.delete(recipe)
        toasts.show("Deleted “\(title)”", style: .info, actionTitle: "Undo") {
            context.insert(backup.makeRecipe())
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Menu {
                Picker("Sort By", selection: $sort) {
                    ForEach(RecipeSort.allCases) { Text($0.rawValue).tag($0) }
                }
                Toggle("Favorites Only", systemImage: "heart", isOn: $favoritesOnly)
                Picker("Layout", selection: $gridLayout) {
                    Label("Grid", systemImage: "square.grid.2x2").tag(true)
                    Label("List", systemImage: "list.bullet").tag(false)
                }
                Toggle("Compact", systemImage: "rectangle.compress.vertical", isOn: $compact)
                Divider()
                Button("Collections", systemImage: "folder") { router.cookbookPath.append(HomeRoute.collections) }
                Button("Settings", systemImage: "gearshape") { router.showSettings = true }
            } label: {
                Image(systemName: favoritesOnly || selectedTag != nil ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
            }
            .accessibilityLabel("Sort and filter")
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button { surprise() } label: {
                Image(systemName: "dice").symbolEffect(.bounce, value: surpriseSpin)
            }
            .disabled(recipes.isEmpty)
            .accessibilityLabel("Surprise me with a random recipe")
            Menu {
                Button("New Recipe", systemImage: "square.and.pencil") { showingNew = true }
                    .keyboardShortcut("n", modifiers: .command)
                Button("Import from Link", systemImage: "square.and.arrow.down") { router.startImport() }
                Button("Create with AI", systemImage: "wand.and.stars") { router.showCreate = true }
            } label: {
                Image(systemName: "plus.circle.fill").font(.title3)
            }
            .accessibilityLabel("Add recipe")
        }
    }

    private func surprise() {
        surpriseSpin += 1
        let pool = filtered.isEmpty ? recipes : filtered
        guard let pick = pool.randomElement() else { return }
        toasts.show("How about… \(pick.title)? 🎲", style: .info)
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            router.cookbookPath.append(pick)
        }
    }

    // MARK: Filters

    private var filterBars: some View {
        VStack(alignment: .leading, spacing: 2) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip("All", icon: "square.grid.2x2", isOn: selectedCategory == nil && !favoritesOnly && selectedTag == nil) { clearFilters() }
                    chip("Favorites", icon: "heart.fill", isOn: favoritesOnly) { favoritesOnly.toggle() }
                    ForEach(usedCategories, id: \.self) { cat in
                        chip(cat, icon: Recipe.icon(for: cat), isOn: selectedCategory == cat) {
                            selectedCategory = selectedCategory == cat ? nil : cat
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
            }
            if !usedTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        Image(systemName: "tag").font(.caption).foregroundStyle(.secondary)
                        ForEach(usedTags, id: \.self) { t in
                            Button { withAnimation(.snappy) { selectedTag = selectedTag == t ? nil : t } } label: {
                                TagChip(text: t, selected: selectedTag == t)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 4)
                }
            }
            if !collections.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(collections) { c in
                            NavigationLink(value: c) {
                                Label("\(c.name) · \(c.recipes?.count ?? 0)", systemImage: c.icon)
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 6)
                }
            }
        }
        .sensoryFeedback(.selection, trigger: selectedCategory)
    }

    private func chip(_ title: String, icon: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy) { action() }
        } label: {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isOn ? Color.accentColor : Color(.secondarySystemGroupedBackground), in: Capsule())
                .foregroundStyle(isOn ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

struct RecipeCard: View {
    let recipe: Recipe
    var compact = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.clear
                .aspectRatio(compact ? 0.9 : 0.8, contentMode: .fit)
                .overlay {
                    if let data = recipe.photoData, let image = UIImage(data: data) {
                        Image(uiImage: image).resizable().scaledToFill()
                    } else {
                        CategoryPlaceholder(category: recipe.category, iconSize: compact ? 30 : 44)
                    }
                }
                .clipped()

            LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.title)
                    .font(compact ? .caption.bold() : .headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if !compact {
                    HStack(spacing: 6) {
                        if recipe.totalMinutes > 0 {
                            Label(Recipe.format(minutes: recipe.totalMinutes), systemImage: "clock")
                        }
                        if recipe.rating > 0 {
                            Label("\(recipe.rating)", systemImage: "star.fill")
                        }
                    }
                    .font(.caption2.weight(.medium))
                    .opacity(0.9)
                }
            }
            .foregroundStyle(.white)
            .padding(compact ? 8 : 12)
        }
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 4) {
                if recipe.sourceKind == "ai" {
                    Image(systemName: "sparkles").font(.caption2).foregroundStyle(.white)
                        .padding(6).background(.purple, in: Circle())
                }
                if recipe.isFavorite {
                    Image(systemName: "heart.fill").font(.caption2).foregroundStyle(.white)
                        .padding(6).background(.pink, in: Circle())
                }
            }
            .padding(8)
        }
        .clipShape(RoundedRectangle(cornerRadius: compact ? 14 : 18, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
        .contentShape(RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(recipe.title)\(recipe.isFavorite ? ", favorite" : "")\(recipe.totalMinutes > 0 ? ", \(Recipe.format(minutes: recipe.totalMinutes))" : "")")
    }
}

struct RecipeRow: View {
    let recipe: Recipe
    var compact = false

    var body: some View {
        HStack(spacing: 12) {
            RecipeThumbnail(recipe: recipe, size: compact ? 44 : 60)
            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.title).font(compact ? .subheadline.weight(.semibold) : .headline).lineLimit(1)
                HStack(spacing: 8) {
                    Label(recipe.category, systemImage: Recipe.icon(for: recipe.category))
                    if recipe.totalMinutes > 0 {
                        Label(Recipe.format(minutes: recipe.totalMinutes), systemImage: "clock")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                if recipe.rating > 0 && !compact {
                    StarRating(rating: .constant(recipe.rating), size: 11)
                }
            }
            Spacer()
            if recipe.isFavorite {
                Image(systemName: "heart.fill").foregroundStyle(.pink)
            }
        }
        .padding(.vertical, 2)
    }
}
