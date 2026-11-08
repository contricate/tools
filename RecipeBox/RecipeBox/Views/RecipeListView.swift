import SwiftUI
import SwiftData

enum RecipeSort: String, CaseIterable, Identifiable {
    case newest = "Newest"
    case title = "A–Z"
    case rating = "Rating"
    case quickest = "Quickest"
    case mostCooked = "Most Cooked"
    var id: String { rawValue }
}

struct RecipeListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Recipe.createdAt, order: .reverse) private var recipes: [Recipe]

    @State private var searchText = ""
    @State private var selectedCategory: String? = nil
    @State private var favoritesOnly = false
    @State private var sort: RecipeSort = .newest
    @State private var showingNew = false

    private var filtered: [Recipe] {
        var list = recipes
        if favoritesOnly { list = list.filter { $0.isFavorite } }
        if let cat = selectedCategory { list = list.filter { $0.category == cat } }
        let q = searchText.trimmingCharacters(in: .whitespaces)
        if !q.isEmpty {
            list = list.filter { r in
                r.title.localizedCaseInsensitiveContains(q)
                || r.summary.localizedCaseInsensitiveContains(q)
                || r.ingredients.contains { $0.localizedCaseInsensitiveContains(q) }
            }
        }
        switch sort {
        case .newest: break
        case .title: list.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .rating: list.sort { $0.rating > $1.rating }
        case .quickest: list.sort { $0.totalMinutes < $1.totalMinutes }
        case .mostCooked: list.sort { $0.timesCooked > $1.timesCooked }
        }
        return list
    }

    var body: some View {
        NavigationStack {
            Group {
                if recipes.isEmpty {
                    ContentUnavailableView {
                        Label("No Recipes Yet", systemImage: "book.closed")
                    } description: {
                        Text("Tap + to add your first recipe.")
                    } actions: {
                        Button("Add Recipe") { showingNew = true }
                            .buttonStyle(.borderedProminent)
                        Button("Load Sample Recipes") { SampleRecipes.insert(into: context) }
                    }
                } else {
                    List {
                        categoryBar
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                        ForEach(filtered) { recipe in
                            NavigationLink(value: recipe) {
                                RecipeRow(recipe: recipe)
                            }
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
                            Text("No matching recipes")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .listRowBackground(Color.clear)
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search recipes or ingredients")
                }
            }
            .navigationTitle("Recipes")
            .navigationDestination(for: Recipe.self) { RecipeDetailView(recipe: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Sort", selection: $sort) {
                            ForEach(RecipeSort.allCases) { Text($0.rawValue).tag($0) }
                        }
                        Toggle("Favorites Only", systemImage: "heart", isOn: $favoritesOnly)
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingNew = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingNew) {
                RecipeEditView(recipe: nil)
            }
        }
    }

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("All", isOn: selectedCategory == nil) { selectedCategory = nil }
                ForEach(Recipe.categories, id: \.self) { cat in
                    chip(cat, isOn: selectedCategory == cat) {
                        selectedCategory = selectedCategory == cat ? nil : cat
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
    }

    private func chip(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isOn ? Color.accentColor : Color(.secondarySystemBackground), in: Capsule())
                .foregroundStyle(isOn ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
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
                .labelStyle(.titleAndIcon)
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

struct RecipeThumbnail: View {
    let recipe: Recipe
    let size: CGFloat

    var body: some View {
        Group {
            if let data = recipe.photoData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    Color.accentColor.opacity(0.15)
                    Image(systemName: Recipe.icon(for: recipe.category))
                        .font(.system(size: size * 0.4))
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct StarRating: View {
    @Binding var rating: Int
    var size: CGFloat = 20
    var editable = false

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { i in
                Image(systemName: i <= rating ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(i <= rating ? Color.yellow : Color.secondary.opacity(0.5))
                    .onTapGesture {
                        guard editable else { return }
                        rating = (rating == i) ? 0 : i
                    }
            }
        }
    }
}
