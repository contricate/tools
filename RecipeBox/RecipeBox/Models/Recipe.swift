import Foundation
import SwiftData

@Model
final class Recipe {
    var title: String = ""
    var summary: String = ""
    var category: String = "Dinner"
    var servings: Int = 4
    var prepMinutes: Int = 0
    var cookMinutes: Int = 0
    var ingredients: [String] = []
    var steps: [String] = []
    var notes: String = ""
    var sourceURL: String = ""
    var isFavorite: Bool = false
    var rating: Int = 0
    @Attribute(.externalStorage) var photoData: Data?
    var createdAt: Date = Date()
    var lastCooked: Date?
    var timesCooked: Int = 0

    init(title: String,
         summary: String = "",
         category: String = "Dinner",
         servings: Int = 4,
         prepMinutes: Int = 0,
         cookMinutes: Int = 0,
         ingredients: [String] = [],
         steps: [String] = [],
         notes: String = "") {
        self.title = title
        self.summary = summary
        self.category = category
        self.servings = servings
        self.prepMinutes = prepMinutes
        self.cookMinutes = cookMinutes
        self.ingredients = ingredients
        self.steps = steps
        self.notes = notes
        self.createdAt = Date()
    }

    var totalMinutes: Int { prepMinutes + cookMinutes }

    var shareText: String {
        var text = "\(title)\n"
        if !summary.isEmpty { text += "\(summary)\n" }
        text += "\nServes \(servings)"
        if totalMinutes > 0 { text += " · \(Recipe.format(minutes: totalMinutes))" }
        text += "\n\nIngredients:\n"
        text += ingredients.map { "• \($0)" }.joined(separator: "\n")
        text += "\n\nSteps:\n"
        text += steps.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        if !notes.isEmpty { text += "\n\nNotes:\n\(notes)" }
        return text
    }

    static func format(minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) min" }
        let h = minutes / 60, m = minutes % 60
        return m == 0 ? "\(h) hr" : "\(h) hr \(m) min"
    }

    static let categories = ["Breakfast", "Lunch", "Dinner", "Appetizer", "Side", "Dessert", "Baking", "Drink", "Snack", "Other"]

    static func icon(for category: String) -> String {
        switch category {
        case "Breakfast": return "sun.horizon"
        case "Lunch": return "takeoutbag.and.cup.and.straw"
        case "Dinner": return "fork.knife"
        case "Appetizer": return "leaf"
        case "Side": return "carrot"
        case "Dessert": return "birthday.cake"
        case "Baking": return "oven"
        case "Drink": return "cup.and.saucer"
        case "Snack": return "popcorn"
        default: return "book"
        }
    }
}

@Model
final class ShoppingItem {
    var name: String = ""
    var isChecked: Bool = false
    var fromRecipe: String = ""
    var createdAt: Date = Date()

    init(name: String, fromRecipe: String = "") {
        self.name = name
        self.fromRecipe = fromRecipe
        self.createdAt = Date()
    }
}

enum SampleRecipes {
    static func insert(into context: ModelContext) {
        let pancakes = Recipe(
            title: "Fluffy Pancakes",
            summary: "Classic weekend breakfast pancakes.",
            category: "Breakfast", servings: 4, prepMinutes: 10, cookMinutes: 15,
            ingredients: ["1 1/2 cups all-purpose flour", "3 1/2 tsp baking powder", "1 tbsp sugar", "1/4 tsp salt", "1 1/4 cups milk", "1 egg", "3 tbsp melted butter"],
            steps: ["Whisk flour, baking powder, sugar and salt in a bowl.", "Make a well in the center and pour in milk, egg and melted butter; mix until just combined.", "Heat a lightly oiled pan over medium-high heat.", "Pour 1/4 cup batter per pancake and cook until bubbles form, then flip and brown the other side."],
            notes: "Don't overmix — a few lumps are fine.")
        let pasta = Recipe(
            title: "Garlic Butter Pasta",
            summary: "Quick weeknight pasta with garlic, butter and parmesan.",
            category: "Dinner", servings: 2, prepMinutes: 5, cookMinutes: 15,
            ingredients: ["8 oz spaghetti", "4 tbsp butter", "4 cloves garlic, minced", "1/2 cup grated parmesan", "Salt and pepper", "Fresh parsley, chopped"],
            steps: ["Cook spaghetti in salted water until al dente. Reserve 1/2 cup pasta water.", "Melt butter in a pan and cook garlic for 1 minute until fragrant.", "Toss in pasta, parmesan and a splash of pasta water.", "Season with salt and pepper and top with parsley."])
        let cookies = Recipe(
            title: "Chocolate Chip Cookies",
            summary: "Chewy in the middle, crisp on the edges.",
            category: "Baking", servings: 24, prepMinutes: 15, cookMinutes: 11,
            ingredients: ["2 1/4 cups flour", "1 tsp baking soda", "1 tsp salt", "1 cup butter, softened", "3/4 cup sugar", "3/4 cup brown sugar", "2 eggs", "2 tsp vanilla", "2 cups chocolate chips"],
            steps: ["Preheat oven to 375°F (190°C).", "Mix flour, baking soda and salt.", "Beat butter and sugars until creamy, then beat in eggs and vanilla.", "Gradually mix in the flour mixture, then stir in chocolate chips.", "Drop spoonfuls onto a baking sheet and bake 9–11 minutes."])
        cookies.isFavorite = true
        for r in [pancakes, pasta, cookies] { context.insert(r) }
    }
}
