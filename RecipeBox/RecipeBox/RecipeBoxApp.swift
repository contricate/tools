import SwiftUI
import SwiftData

@main
struct RecipeBoxApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Recipe.self, ShoppingItem.self])
    }
}

struct ContentView: View {
    var body: some View {
        TabView {
            RecipeListView()
                .tabItem { Label("Recipes", systemImage: "book.closed") }
            ShoppingListView()
                .tabItem { Label("Shopping", systemImage: "cart") }
        }
    }
}
