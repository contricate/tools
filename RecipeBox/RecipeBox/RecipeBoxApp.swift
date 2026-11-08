import SwiftUI
import SwiftData

@main
struct RecipeBoxApp: App {
    let container: ModelContainer
    let storeError: String?
    @State private var router = AppRouter()
    @State private var toasts = ToastCenter()
    @State private var timers = TimerStore()

    static let isDemo = ProcessInfo.processInfo.arguments.contains("-demo")

    static let schema = Schema([Recipe.self, ShoppingItem.self, MealPlanEntry.self, RecipeCollection.self,
                                CookNote.self, CookPhoto.self, ImportRecord.self, SavedMealPlan.self])

    init() {
        SettingsDefaults.register()
        NotificationHelper.shared.activate()
        let demo = Self.isDemo
        do {
            container = try ModelContainer(for: Self.schema,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: demo))
            storeError = nil
        } catch {
            // Never delete the user's data: open a temporary store and tell them.
            container = try! ModelContainer(for: Self.schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            storeError = "Your saved recipes couldn't be opened (\(error.localizedDescription)). Changes made now won't be saved."
        }
        let context = container.mainContext
        if demo { DemoData.seed(into: context) }
        DataMaintenance.run(context)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(storeError: storeError)
                .environment(router)
                .environment(toasts)
                .environment(timers)
                .themed()
                .onAppear { if Self.isDemo { DemoData.route(router) } }
        }
        .modelContainer(container)
    }
}

enum AppTab: Hashable {
    case home, cookbook, plan, groceries, assistant
}

/// App-wide navigation state, so any screen can open the importer, a recipe, another tab, etc.
@Observable
final class AppRouter {
    var tab: AppTab = .home
    var homePath = NavigationPath()
    var cookbookPath = NavigationPath()
    var showImport = false
    var importPrefill = ""
    var showCreate = false
    var showSettings = false
    var showConverter = false
    var cookRecipe: Recipe?

    func open(_ recipe: Recipe) {
        showSettings = false
        showImport = false
        showCreate = false
        switch tab {
        case .cookbook: cookbookPath.append(recipe)
        default:
            tab = .home
            homePath.append(recipe)
        }
    }

    func startImport(_ link: String = "") {
        importPrefill = link
        showImport = true
    }
}

struct ContentView: View {
    @Environment(AppRouter.self) private var router
    @Environment(TimerStore.self) private var timers
    let storeError: String?

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.tab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(AppTab.home)
            RecipeListView()
                .tabItem { Label("Cookbook", systemImage: "book.closed.fill") }
                .tag(AppTab.cookbook)
            MealPlanView()
                .tabItem { Label("Plan", systemImage: "calendar") }
                .tag(AppTab.plan)
            ShoppingListView()
                .tabItem { Label("Groceries", systemImage: "cart.fill") }
                .tag(AppTab.groceries)
            AssistantView()
                .tabItem { Label("Assistant", systemImage: "sparkles") }
                .tag(AppTab.assistant)
        }
        .toastHost()
        .overlay(alignment: .bottom) {
            if !timers.timers.isEmpty && router.cookRecipe == nil {
                FloatingTimers().padding(.bottom, 56)
            }
        }
        .safeAreaInset(edge: .top) {
            if let storeError {
                Text(storeError)
                    .font(.caption)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.15))
            }
        }
        .sheet(isPresented: $router.showImport) {
            UniversalImportView(initialLink: router.importPrefill).themed()
        }
        .sheet(isPresented: $router.showCreate) {
            CreateRecipeView().themed()
        }
        .sheet(isPresented: $router.showSettings) {
            SettingsView().themed()
        }
        .sheet(isPresented: $router.showConverter) {
            ConverterView().themed()
        }
        .fullScreenCover(item: $router.cookRecipe) { recipe in
            CookModeView(recipe: recipe, factor: 1).themed()
        }
    }
}

/// One-off fixes run at launch (e.g. giving older recipes a stable id).
enum DataMaintenance {
    static func run(_ context: ModelContext) {
        let recipes = (try? context.fetch(FetchDescriptor<Recipe>())) ?? []
        var seen = Set<String>()
        for r in recipes {
            if r.uid.isEmpty || seen.contains(r.uid) { r.uid = UUID().uuidString }
            seen.insert(r.uid)
        }
        try? context.save()
    }
}

/// In-memory sample data used only when launched with -demo (for automated screenshots).
enum DemoData {
    static func seed(into context: ModelContext) {
        SampleRecipes.insert(into: context)
        try? context.save()
        let recipes = (try? context.fetch(FetchDescriptor<Recipe>(sortBy: [SortDescriptor(\.title)]))) ?? []
        for (i, r) in recipes.enumerated() {
            r.lastViewed = Date().addingTimeInterval(Double(-i * 3600))
            if i % 2 == 0 {
                context.insert(MealPlanEntry(date: Date().addingTimeInterval(Double(i) * 86400), meal: "Dinner", recipe: r))
            }
        }
        if let first = recipes.first {
            first.sourceKind = "video"; first.sourcePlatform = "TikTok"; first.importedAt = Date()
        }
        _ = ShoppingItem.add(recipes.prefix(2).flatMap { $0.ingredients }, from: "Demo", in: context)
        let c = RecipeCollection(name: "Weeknight Wins", icon: "flame")
        context.insert(c)
        c.recipes = Array(recipes.prefix(2))
        try? context.save()
    }

    static func route(_ router: AppRouter) {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-screen"), i + 1 < args.count else { return }
        let screen = args[i + 1]
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            switch screen {
            case "cookbook": router.tab = .cookbook
            case "plan": router.tab = .plan
            case "groceries": router.tab = .groceries
            case "assistant": router.tab = .assistant
            case "settings": router.showSettings = true
            case "import": router.startImport("https://www.youtube.com/shorts/example")
            case "discover": router.homePath.append(HomeRoute.discover)
            case "kitchen": router.homePath.append(HomeRoute.kitchen)
            case "detail", "cook":
                NotificationCenter.default.post(name: .demoOpenFirstRecipe, object: screen)
            default: break
            }
        }
    }
}

extension Notification.Name {
    static let demoOpenFirstRecipe = Notification.Name("demoOpenFirstRecipe")
}
