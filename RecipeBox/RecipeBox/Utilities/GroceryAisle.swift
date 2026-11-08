import Foundation

enum GroceryAisle {
    static let order = ["Produce", "Meat & Seafood", "Dairy & Eggs", "Bakery", "Pantry", "Spices & Baking", "Frozen", "Drinks", "Household", "Other"]

    static func icon(_ aisle: String) -> String {
        switch aisle {
        case "Produce": return "carrot"
        case "Meat & Seafood": return "fish"
        case "Dairy & Eggs": return "drop"
        case "Bakery": return "birthday.cake"
        case "Pantry": return "cabinet"
        case "Spices & Baking": return "sparkles"
        case "Frozen": return "snowflake"
        case "Drinks": return "cup.and.saucer"
        case "Household": return "house"
        default: return "bag"
        }
    }

    private static let keywords: [(String, [String])] = [
        ("Spices & Baking", ["salt", "pepper", "paprika", "cumin", "cinnamon", "oregano", "thyme", "basil, dried", "chili powder", "nutmeg", "baking soda", "baking powder", "yeast", "vanilla", "cocoa", "chocolate chip", "sugar", "flour", "cornstarch", "spice", "seasoning", "bay leaf", "bay leaves", "garlic powder", "onion powder", "turmeric", "curry", "ginger, ground", "cloves, ground"]),
        ("Household", ["paper towel", "toilet paper", "foil", "plastic wrap", "cling film", "parchment", "baking paper", "detergent", "dish soap", "soap", "sponge", "trash bag", "bin bag", "napkin", "zip bag", "ziploc", "batteries", "cleaner"]),
        ("Frozen", ["frozen", "ice cream"]),
        ("Meat & Seafood", ["chicken", "beef", "pork", "bacon", "sausage", "turkey", "lamb", "ham", "steak", "ground meat", "salmon", "tuna", "shrimp", "fish", "cod", "tilapia", "prosciutto", "pepperoni", "chorizo"]),
        ("Dairy & Eggs", ["milk", "butter", "cheese", "parmesan", "mozzarella", "cheddar", "cream", "yogurt", "yoghurt", "egg", "sour cream", "ricotta", "feta"]),
        ("Bakery", ["bread", "bun", "tortilla", "bagel", "pita", "baguette", "croissant", "roll"]),
        ("Drinks", ["juice", "wine", "beer", "soda", "coffee", "tea", "water", "sparkling"]),
        ("Produce", ["apple", "banana", "lemon", "lime", "orange", "berry", "berries", "tomato", "potato", "onion", "garlic", "carrot", "celery", "lettuce", "spinach", "kale", "cucumber", "zucchini", "pepper", "avocado", "mushroom", "broccoli", "cauliflower", "cabbage", "parsley", "cilantro", "basil", "mint", "ginger", "scallion", "green onion", "shallot", "corn", "peas", "beans, green", "herb", "fruit", "grape", "mango", "pineapple", "peach", "pear", "jalapeño", "jalapeno", "squash", "leek", "asparagus", "eggplant", "radish", "beet"]),
        ("Pantry", ["rice", "pasta", "spaghetti", "noodle", "oil", "vinegar", "sauce", "broth", "stock", "can ", "canned", "beans", "lentil", "chickpea", "honey", "syrup", "peanut butter", "jam", "oats", "cereal", "nuts", "almond", "walnut", "pecan", "raisin", "mustard", "ketchup", "mayo", "soy", "tomato paste", "breadcrumb", "cracker", "chips", "quinoa", "couscous"])
    ]

    static func classify(_ name: String) -> String {
        let n = " " + name.lowercased() + " "
        for (aisle, words) in keywords where words.contains(where: { n.contains($0) }) {
            return aisle
        }
        return "Other"
    }
}
