import SwiftUI
import SwiftData

@main
struct RecipeBoxApp: App {
    init() {
        NotificationHelper.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Recipe.self, ShoppingItem.self, MealPlanEntry.self])
    }
}

struct ContentView: View {
    var body: some View {
        TabView {
            RecipeListView()
                .tabItem { Label("Recipes", systemImage: "book.closed") }
            MealPlanView()
                .tabItem { Label("Meal Plan", systemImage: "calendar") }
            ShoppingListView()
                .tabItem { Label("Shopping", systemImage: "cart") }
        }
    }
}
