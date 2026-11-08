import SwiftUI
import SwiftData

enum RecipeSort: String, CaseIterable, Identifiable {
    case newest = "Newest"
    case title = "A–Z"
    case rating = "Top Rated"
    case quickest = "Quickest"
    case mostCooked = "Most Cooked"
    var id: String { rawValue }
}

struct RecipeListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Recipe.createdAt, order: .reverse) private var recipes: [Recipe]

    @AppStorage("gridLayout") private var gridLayout = true
    @State private var path: [Recipe] = []
    @State private var searchText = ""
    @State private var selectedCategory: String? = nil
    @State private var favoritesOnly = false
    @State private var sort: RecipeSort = .newest
    @State private var showingNew = false
    @State private var showingImport = false
    @State private var exporting = false
    @State private var importingBackup = false
    @State private var backupDoc = BackupDocument(data: Data())
    @State private var toast: String?
    @State private var surpriseSpin = 0

    private var filtered: [Recipe] {
        var list = recipes
        if favoritesOnly { list = list.filter { $0.isFavorite } }
        if let cat = selectedCategory { list = list.filter { $0.category == cat } }
        let q = searchText.trimmingCharacters(in: .whitespaces)
        if !q.isEmpty {
            list = list.filter { r in
                r.title.localizedCaseInsensitiveContains(q)
                || r.summary.localizedCaseInsensitiveContains(q)
                || r.category.localizedCaseInsensitiveContains(q)
                || r.ingredients.contains { $0.localizedCaseInsensitiveContains(q) }
            }
        }
        switch sort {
        case .newest: break
        case .title: list.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .rating: list.sort { $0.rating > $1.rating }
        case .quickest: list.sort { ($0.totalMinutes == 0 ? Int.max : $0.totalMinutes) < ($1.totalMinutes == 0 ? Int.max : $1.totalMinutes) }
        case .mostCooked: list.sort { $0.timesCooked > $1.timesCooked }
        }
        return list
    }

    private var usedCategories: [String] {
        let used = Set(recipes.map(\.category))
        return Recipe.categories.filter { used.contains($0) }
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if recipes.isEmpty {
                    emptyState
                } else if gridLayout {
                    gridView
                } else {
                    listView
                }
            }
            .navigationTitle("Recipes")
            .navigationDestination(for: Recipe.self) { RecipeDetailView(recipe: $0) }
            .toolbar { toolbarContent }
            .sheet(isPresented: $showingNew) { RecipeEditView(recipe: nil) }
            .sheet(isPresented: $showingImport) {
                ImportRecipeView { recipe in
                    toast = "Imported “\(recipe.title)”"
                    path.append(recipe)
                }
            }
            .fileExporter(isPresented: $exporting, document: backupDoc, contentType: .json,
                          defaultFilename: "RecipeBox-Backup-\(Date().formatted(.iso8601.year().month().day()))") { result in
                if case .success = result { toast = "Backup saved" }
            }
            .fileImporter(isPresented: $importingBackup, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    do {
                        let n = try Backup.restore(from: url, into: context, existing: recipes)
                        toast = n == 0 ? "No new recipes in that backup" : "Restored \(n) recipe\(n == 1 ? "" : "s")"
                    } catch {
                        toast = "That file isn't a Recipe Box backup"
                    }
                case .failure:
                    break
                }
            }
            .toast($toast)
        }
    }

    // MARK: Layouts

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Your Recipe Box is Empty", systemImage: "book.closed")
        } description: {
            Text("Add your own recipes, import one from any recipe website, or start with a few samples.")
        } actions: {
            Button { showingNew = true } label: { Label("Add Recipe", systemImage: "plus") }
                .buttonStyle(.borderedProminent)
            Button { showingImport = true } label: { Label("Import from Website", systemImage: "globe") }
                .buttonStyle(.bordered)
            Button("Load Sample Recipes") { SampleRecipes.insert(into: context) }
        }
    }

    private var gridView: some View {
        ScrollView {
            categoryBar
            if filtered.isEmpty { noMatches.padding(.top, 40) }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 14)], spacing: 14) {
                ForEach(filtered) { recipe in
                    NavigationLink(value: recipe) {
                        RecipeCard(recipe: recipe)
                    }
                    .buttonStyle(.plain)
                    .contextMenu { contextActions(for: recipe) }
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .searchable(text: $searchText, prompt: "Search recipes or ingredients")
    }

    private var listView: some View {
        List {
            categoryBar
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            ForEach(filtered) { recipe in
                NavigationLink(value: recipe) {
                    RecipeRow(recipe: recipe)
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
                let items = filtered
                for i in offsets { context.delete(items[i]) }
            }
            if filtered.isEmpty {
                noMatches.listRowBackground(Color.clear)
            }
        }
        .searchable(text: $searchText, prompt: "Search recipes or ingredients")
    }

    private var noMatches: some View {
        Text("No matching recipes")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func contextActions(for recipe: Recipe) -> some View {
        Button(recipe.isFavorite ? "Unfavorite" : "Favorite", systemImage: recipe.isFavorite ? "heart.slash" : "heart") {
            recipe.isFavorite.toggle()
        }
        ShareLink(item: recipe.shareText) { Label("Share", systemImage: "square.and.arrow.up") }
        Button("Delete", systemImage: "trash", role: .destructive) {
            context.delete(recipe)
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
                Divider()
                Button("Back Up All Recipes", systemImage: "arrow.up.doc") {
                    if let data = Backup.export(recipes) {
                        backupDoc = BackupDocument(data: data)
                        exporting = true
                    }
                }
                .disabled(recipes.isEmpty)
                Button("Restore from Backup", systemImage: "arrow.down.doc") { importingBackup = true }
            } label: {
                Image(systemName: favoritesOnly ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
            }
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                surprise()
            } label: {
                Image(systemName: "dice")
                    .symbolEffect(.bounce, value: surpriseSpin)
            }
            .disabled(recipes.isEmpty)
            Menu {
                Button("New Recipe", systemImage: "square.and.pencil") { showingNew = true }
                Button("Import from Website", systemImage: "globe") { showingImport = true }
            } label: {
                Image(systemName: "plus.circle.fill").font(.title3)
            }
        }
    }

    private func surprise() {
        surpriseSpin += 1
        let pool = filtered.isEmpty ? recipes : filtered
        guard let pick = pool.randomElement() else { return }
        toast = "How about… \(pick.title)? 🎲"
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            await MainActor.run { path.append(pick) }
        }
    }

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("All", icon: "square.grid.2x2", isOn: selectedCategory == nil && !favoritesOnly) {
                    selectedCategory = nil
                    favoritesOnly = false
                }
                chip("Favorites", icon: "heart.fill", isOn: favoritesOnly) { favoritesOnly.toggle() }
                ForEach(usedCategories, id: \.self) { cat in
                    chip(cat, icon: Recipe.icon(for: cat), isOn: selectedCategory == cat) {
                        selectedCategory = selectedCategory == cat ? nil : cat
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
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
                .background(isOn ? Color.accentColor : Color(.secondarySystemBackground), in: Capsule())
                .foregroundStyle(isOn ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }
}

struct RecipeCard: View {
    let recipe: Recipe

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.clear
                .aspectRatio(0.8, contentMode: .fit)
                .overlay {
                    if let data = recipe.photoData, let image = UIImage(data: data) {
                        Image(uiImage: image).resizable().scaledToFill()
                    } else {
                        CategoryPlaceholder(category: recipe.category, iconSize: 44)
                    }
                }
                .clipped()

            LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.title)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
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
            .foregroundStyle(.white)
            .padding(12)
        }
        .overlay(alignment: .topTrailing) {
            if recipe.isFavorite {
                Image(systemName: "heart.fill")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(7)
                    .background(.pink, in: Circle())
                    .padding(8)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
        .contentShape(RoundedRectangle(cornerRadius: 18))
    }
}

struct RecipeRow: View {
    let recipe: Recipe

    var body: some View {
        HStack(spacing: 12) {
            RecipeThumbnail(recipe: recipe, size: 60)
            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.title).font(.headline).lineLimit(1)
                HStack(spacing: 8) {
                    Label(recipe.category, systemImage: Recipe.icon(for: recipe.category))
                    if recipe.totalMinutes > 0 {
                        Label(Recipe.format(minutes: recipe.totalMinutes), systemImage: "clock")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                if recipe.rating > 0 {
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
