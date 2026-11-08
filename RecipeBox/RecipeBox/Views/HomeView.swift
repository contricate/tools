import SwiftUI
import SwiftData

enum HomeRoute: Hashable {
    case discover, kitchen, importHistory, collections, favorites
}

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router
    @Query(sort: \Recipe.createdAt, order: .reverse) private var recipes: [Recipe]
    @Query(sort: \MealPlanEntry.date) private var plan: [MealPlanEntry]
    @Query private var groceries: [ShoppingItem]
    @State private var search = ""

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private var recentlyViewed: [Recipe] {
        recipes.filter { $0.lastViewed != nil }.sorted { $0.lastViewed! > $1.lastViewed! }.prefix(10).map { $0 }
    }
    private var favorites: [Recipe] { recipes.filter(\.isFavorite).prefix(10).map { $0 } }
    private var recentlyImported: [Recipe] {
        recipes.filter { $0.importedAt != nil }.sorted { $0.importedAt! > $1.importedAt! }.prefix(10).map { $0 }
    }
    private var todaysMeals: [MealPlanEntry] {
        plan.filter { Calendar.current.isDateInToday($0.date) && $0.recipe != nil }
            .sorted { (MealPlanEntry.meals.firstIndex(of: $0.meal) ?? 9) < (MealPlanEntry.meals.firstIndex(of: $1.meal) ?? 9) }
    }
    /// Favourites or well-rated recipes you haven't cooked in a while (based only on your own data).
    private var revisit: [Recipe] {
        let cutoff = Date().addingTimeInterval(-21 * 86400)
        return recipes.filter { ($0.isFavorite || $0.rating >= 4) && ($0.lastCooked ?? .distantPast) < cutoff }
            .prefix(8).map { $0 }
    }
    private var searchResults: [Recipe] {
        let q = search.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        return recipes.filter {
            $0.title.localizedCaseInsensitiveContains(q) || $0.tags.contains { $0.localizedCaseInsensitiveContains(q) }
            || $0.ingredients.contains { $0.localizedCaseInsensitiveContains(q) } || $0.category.localizedCaseInsensitiveContains(q)
        }
    }
    private var toBuy: Int { groceries.filter { !$0.isChecked }.count }
    private var savedProgress: [(Recipe, CookProgress)] {
        recipes.compactMap { r in CookProgress.load(r.uid).map { (r, $0) } }
    }

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.homePath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    header
                    searchField
                    if !search.isEmpty {
                        searchSection
                    } else {
                        quickActions
                        if !savedProgress.isEmpty { continueCooking }
                        todaySection
                        if recipes.isEmpty {
                            emptyCookbook
                        } else {
                            carousel("Recently Viewed", recentlyViewed)
                            carousel("Favorites", favorites, action: ("See All", { router.homePath.append(HomeRoute.favorites) }))
                            carousel("Recently Imported", recentlyImported, action: ("History", { router.homePath.append(HomeRoute.importHistory) }))
                            carousel("Worth Making Again", revisit, subtitle: "Favorites and top-rated recipes you haven't cooked in 3+ weeks")
                        }
                        groceryCard
                        toolsSection
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 90)
                .animation(.snappy, value: search.isEmpty)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { router.showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                    }
                    .accessibilityLabel("Settings")
                    .keyboardShortcut(",", modifiers: .command)
                }
            }
            .navigationDestination(for: Recipe.self) { RecipeDetailView(recipe: $0) }
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .discover: DiscoverView()
                case .kitchen: KitchenFinderView()
                case .importHistory: ImportHistoryView()
                case .collections: CollectionsView()
                case .favorites: RecipeGridPage(title: "Favorites", recipes: recipes.filter(\.isFavorite))
                }
            }
            .navigationDestination(for: RecipeCollection.self) { CollectionDetailView(collection: $0) }
            .onReceive(NotificationCenter.default.publisher(for: .demoOpenFirstRecipe)) { note in
                guard let first = recipes.sorted(by: { $0.title < $1.title }).first else { return }
                if (note.object as? String) == "cook" { router.cookRecipe = first } else { router.homePath.append(first) }
            }
        }
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Date().formatted(.dateTime.weekday(.wide).month().day()).uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            Text(greeting).font(.largeTitle.bold())
            Text(recipes.isEmpty ? "Let's build your cookbook." : "\(recipes.count) recipe\(recipes.count == 1 ? "" : "s") in your cookbook")
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search recipes, ingredients, tags", text: $search)
                .submitLabel(.search)
            if !search.isEmpty {
                Button { search = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: DS.smallCorner, style: .continuous))
    }

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "\(searchResults.count) result\(searchResults.count == 1 ? "" : "s")")
            if searchResults.isEmpty {
                ContentUnavailableView.search(text: search)
            }
            ForEach(searchResults) { r in
                NavigationLink(value: r) { RecipeRow(recipe: r).card(padding: 10) }
                    .buttonStyle(.plain)
            }
        }
    }

    private var quickActions: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            Button { router.startImport() } label: {
                ActionTile(title: "Import Recipe", subtitle: "TikTok, Instagram, YouTube, websites", icon: "square.and.arrow.down.fill")
            }
            .keyboardShortcut("i", modifiers: .command)
            Button { router.showCreate = true } label: {
                ActionTile(title: "Create with AI", subtitle: "Describe what you want to cook", icon: "wand.and.stars", color: .purple)
            }
            NavigationLink(value: HomeRoute.kitchen) {
                ActionTile(title: "What's in My Kitchen?", subtitle: "Find recipes you can make now", icon: "refrigerator.fill", color: .teal)
            }
            NavigationLink(value: HomeRoute.discover) {
                ActionTile(title: "Discover", subtitle: "Browse real recipes by cuisine", icon: "safari.fill", color: .blue)
            }
        }
        .buttonStyle(.plain)
    }

    private var continueCooking: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Continue Cooking")
            ForEach(savedProgress, id: \.0.uid) { recipe, progress in
                Button { router.cookRecipe = recipe } label: {
                    HStack(spacing: 12) {
                        RecipeThumbnail(recipe: recipe, size: 52)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(recipe.title).font(.headline)
                            ProgressView(value: Double(progress.page), total: Double(max(1, recipe.steps.count + 1)))
                            Text(progress.page == 0 ? "Gathering ingredients" : "Step \(min(progress.page, recipe.steps.count)) of \(recipe.steps.count)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Image(systemName: "play.circle.fill").font(.title).foregroundStyle(Color.accentColor)
                    }
                    .card(padding: 12)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Today's Plan", actionTitle: "Week", action: { router.tab = .plan })
            if todaysMeals.isEmpty {
                Button { router.tab = .plan } label: {
                    HStack {
                        Image(systemName: "calendar.badge.plus").font(.title2).foregroundStyle(Color.accentColor)
                        Text("Nothing planned today. Tap to plan your week.")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Spacer()
                    }
                    .card()
                }
                .buttonStyle(.plain)
            } else {
                ForEach(todaysMeals) { entry in
                    if let r = entry.recipe {
                        NavigationLink(value: r) {
                            HStack(spacing: 12) {
                                RecipeThumbnail(recipe: r, size: 52)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.meal.uppercased()).font(.caption2.bold()).foregroundStyle(Color.accentColor)
                                    Text(r.title).font(.headline)
                                    if r.totalMinutes > 0 {
                                        Text(Recipe.format(minutes: r.totalMinutes)).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Button { router.cookRecipe = r } label: {
                                    Label("Cook", systemImage: "frying.pan.fill").font(.caption.bold())
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(r.steps.isEmpty)
                            }
                            .card(padding: 12)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func carousel(_ title: String, _ items: [Recipe], subtitle: String? = nil,
                          action: (String, () -> Void)? = nil) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: title, subtitle: subtitle, actionTitle: action?.0, action: action?.1)
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(items) { r in
                            NavigationLink(value: r) {
                                RecipeCard(recipe: r).frame(width: 150)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .scrollClipDisabled()
            }
        }
    }

    private var emptyCookbook: some View {
        VStack(spacing: 14) {
            Image(systemName: "book.closed.fill").font(.system(size: 44)).foregroundStyle(Color.accentColor)
            Text("Your cookbook is empty").font(.headline)
            Text("Import a recipe from a video or website, create one with AI, or add your own.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            HStack {
                Button("Add Recipe") { router.tab = .cookbook }
                    .buttonStyle(.bordered)
                Button("Load Samples") { SampleRecipes.insert(into: context) }
                    .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity)
        .card(padding: 24)
    }

    private var groceryCard: some View {
        Button { router.tab = .groceries } label: {
            HStack(spacing: 14) {
                Image(systemName: "cart.fill")
                    .font(.title2).foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Color.green.gradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Grocery List").font(.headline)
                    Text(toBuy == 0 ? "All caught up" : "\(toBuy) item\(toBuy == 1 ? "" : "s") to buy")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .card()
        }
        .buttonStyle(.plain)
    }

    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Shortcuts")
            VStack(spacing: 0) {
                toolRow("Collections", icon: "folder.fill", color: .orange) { router.homePath.append(HomeRoute.collections) }
                Divider().padding(.leading, 52)
                toolRow("Ask the Cooking Assistant", icon: "sparkles", color: .purple) { router.tab = .assistant }
                Divider().padding(.leading, 52)
                toolRow("Measurement Converter", icon: "scalemass.fill", color: .indigo) { router.showConverter = true }
                Divider().padding(.leading, 52)
                toolRow("Import History", icon: "clock.arrow.circlepath", color: .gray) { router.homePath.append(HomeRoute.importHistory) }
            }
            .card(padding: 4)
        }
    }

    private func toolRow(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(color.gradient, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text(title).foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .padding(10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Simple grid of recipes with a title, used for "See All" pages.
struct RecipeGridPage: View {
    let title: String
    let recipes: [Recipe]

    var body: some View {
        ScrollView {
            if recipes.isEmpty {
                ContentUnavailableView("Nothing here yet", systemImage: "tray")
                    .padding(.top, 60)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 14)], spacing: 14) {
                ForEach(recipes) { r in
                    NavigationLink(value: r) { RecipeCard(recipe: r) }.buttonStyle(.plain)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(title)
    }
}

/// Saved Cook Mode progress so leaving mid-recipe doesn't lose your place.
struct CookProgress: Codable {
    var page: Int
    var gathered: [Int]
    var savedAt: Date

    private static func key(_ uid: String) -> String { "cookProgress.\(uid)" }

    static func load(_ uid: String) -> CookProgress? {
        guard !uid.isEmpty, let d = UserDefaults.standard.data(forKey: key(uid)),
              let p = try? JSONDecoder().decode(CookProgress.self, from: d) else { return nil }
        // Forget progress older than 2 days.
        return p.savedAt > Date().addingTimeInterval(-2 * 86400) ? p : nil
    }

    static func save(_ p: CookProgress, uid: String) {
        guard !uid.isEmpty, let d = try? JSONEncoder().encode(p) else { return }
        UserDefaults.standard.set(d, forKey: key(uid))
    }

    static func clear(_ uid: String) { UserDefaults.standard.removeObject(forKey: key(uid)) }
}
