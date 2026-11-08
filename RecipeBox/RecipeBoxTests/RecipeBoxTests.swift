import XCTest
@testable import RecipeBox

final class ScalingAndUnitsTests: XCTestCase {
    func testScaleMixedFraction() {
        XCTAssertEqual(IngredientScaler.scale("1 1/2 cups flour", by: 2), "3 cups flour")
        XCTAssertEqual(IngredientScaler.scale("½ tsp salt", by: 2), "1 tsp salt")
        XCTAssertEqual(IngredientScaler.scale("2-3 cloves garlic", by: 2), "4–6 cloves garlic")
        XCTAssertEqual(IngredientScaler.scale("Salt to taste", by: 3), "Salt to taste")
    }

    func testParseUnits() {
        let p = IngredientParser.parse("200g chicken breast, diced")
        XCTAssertEqual(p.amount, 200)
        XCTAssertEqual(p.unit, .g)
        XCTAssertEqual(p.name, "chicken breast, diced")

        let q = IngredientParser.parse("2 tbsp olive oil")
        XCTAssertEqual(q.unit, .tbsp)
        XCTAssertEqual(IngredientParser.parse("1 T sugar").unit, .tbsp)
        XCTAssertEqual(IngredientParser.parse("1 t sugar").unit, .tsp)
        XCTAssertEqual(IngredientParser.parse("3 cloves garlic").countWord, "cloves")
        XCTAssertEqual(IngredientParser.parse("8 fl oz cream").unit, .floz)
    }

    func testMetricImperialConversion() {
        XCTAssertEqual(UnitConverter.convert("1 lb ground beef", to: .metric), "455 g ground beef")
        XCTAssertEqual(UnitConverter.convert("500 g pasta", to: .imperial), "1.1 lb pasta".replacingOccurrences(of: "1.1", with: "1⅛"))
        XCTAssertEqual(UnitConverter.convert("2 tbsp butter", to: .metric), "2 tbsp butter", "Spoons are left alone")
        XCTAssertEqual(UnitConverter.convert("200 g sugar", to: .metric), "200 g sugar")
        XCTAssertEqual(UnitConverter.convert("1 cup milk", to: .metric), "240 ml milk")
    }

    func testTemperatureConversion() {
        XCTAssertEqual(UnitConverter.convertTemperatures(in: "Bake at 350°F for 20 min", to: .metric), "Bake at 175°C for 20 min")
        XCTAssertEqual(UnitConverter.convertTemperatures(in: "Heat oven to 200°C", to: .imperial), "Heat oven to 390°F")
        XCTAssertEqual(UnitConverter.convertTemperatures(in: "Heat oven to 200°C", to: .metric), "Heat oven to 200°C")
    }

    func testTimerDetection() {
        let found = TimerDetector.find(in: "Simmer for 15-20 minutes, then rest 5 min.")
        XCTAssertEqual(found.map(\.seconds), [1200, 300])
        XCTAssertEqual(TimerDetector.find(in: "Roast 1 hour").first?.seconds, 3600)
    }
}

final class GroceryTests: XCTestCase {
    func testCombineSameUnit() {
        let a = IngredientParser.parse("200 g chicken")
        let b = IngredientParser.parse("300 g chicken")
        let c = GroceryMath.combine(a, b)
        XCTAssertEqual(c?.amount, 500)
        XCTAssertEqual(GroceryMath.describe(c!), "500 g chicken")
    }

    func testCombineCompatibleUnits() {
        let c = GroceryMath.combine(IngredientParser.parse("1 kg potatoes"), IngredientParser.parse("500 g potato"))
        XCTAssertNotNil(c)
        XCTAssertEqual(c!.amount!, 1.5, accuracy: 0.001)
        XCTAssertEqual(c?.unit, .kg)
    }

    func testDoesNotCombineIncompatible() {
        XCTAssertNil(GroceryMath.combine(IngredientParser.parse("2 chicken breasts"), IngredientParser.parse("300 g chicken breast")))
        XCTAssertNil(GroceryMath.combine(IngredientParser.parse("1 cup milk"), IngredientParser.parse("200 g milk")))
        XCTAssertNil(GroceryMath.combine(IngredientParser.parse("1 cup rice"), IngredientParser.parse("1 cup rice vinegar")))
    }

    func testCountsCombine() {
        let c = GroceryMath.combine(IngredientParser.parse("2 eggs"), IngredientParser.parse("3 eggs"))
        XCTAssertEqual(c?.amount, 5)
    }

    func testAisles() {
        XCTAssertEqual(GroceryAisle.classify("2 cups milk"), "Dairy & Eggs")
        XCTAssertEqual(GroceryAisle.classify("1 lb chicken thighs"), "Meat & Seafood")
        XCTAssertEqual(GroceryAisle.classify("paper towels"), "Household")
    }
}

final class ImportTests: XCTestCase {
    func testPlatformDetection() {
        XCTAssertEqual(VideoPlatform.detect(URL(string: "https://www.tiktok.com/@chef/video/123")!), .tiktok)
        XCTAssertEqual(VideoPlatform.detect(URL(string: "https://vm.tiktok.com/ZM123/")!), .tiktok)
        XCTAssertEqual(VideoPlatform.detect(URL(string: "https://www.instagram.com/reel/abc/")!), .instagram)
        XCTAssertEqual(VideoPlatform.detect(URL(string: "https://youtube.com/shorts/xyz")!), .youtubeShorts)
        XCTAssertEqual(VideoPlatform.detect(URL(string: "https://youtu.be/xyz")!), .youtube)
        XCTAssertEqual(VideoPlatform.detect(URL(string: "https://fb.watch/abc")!), .facebook)
        XCTAssertEqual(VideoPlatform.detect(URL(string: "https://www.allrecipes.com/recipe/1")!), .website)
        XCTAssertEqual(VideoPlatform.detect(URL(string: "https://notyoutube.com/x")!), .website)
    }

    func testYouTubeIDs() {
        XCTAssertEqual(VideoPlatform.youtubeID(from: URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=3")!), "dQw4w9WgXcQ")
        XCTAssertEqual(VideoPlatform.youtubeID(from: URL(string: "https://youtu.be/dQw4w9WgXcQ?si=1")!), "dQw4w9WgXcQ")
        XCTAssertEqual(VideoPlatform.youtubeID(from: URL(string: "https://youtube.com/shorts/abc123")!), "abc123")
        XCTAssertEqual(VideoPlatform.normalize(URL(string: "https://youtu.be/abc")!),
                       VideoPlatform.normalize(URL(string: "https://www.youtube.com/watch?v=abc&feature=share")!))
    }

    func testCleanURLFromSharedText() {
        let u = VideoPlatform.cleanURL(from: "Look at this!! https://vm.tiktok.com/ZMabc/ so good")
        XCTAssertEqual(u?.host, "vm.tiktok.com")
        XCTAssertNil(VideoPlatform.cleanURL(from: "not a link"))
    }

    func testHeuristicParserWithHeaders() {
        let caption = """
        Easy garlic noodles 🍜 #dinner #easyrecipe
        Ingredients:
        - 200g noodles
        - 4 cloves garlic
        - 2 tbsp soy sauce
        - Green onions
        Method:
        1. Boil the noodles for 8 minutes.
        2. Fry garlic in butter, add soy sauce.
        3. Toss everything together.
        Serves 2
        """
        let out = HeuristicRecipeParser.parse(caption)
        XCTAssertEqual(out.ingredients.count, 4)
        XCTAssertEqual(out.steps.count, 3)
        XCTAssertEqual(out.steps.first, "Boil the noodles for 8 minutes.")
        XCTAssertEqual(out.servings, 2)
    }

    func testHeuristicParserInline() {
        let out = HeuristicRecipeParser.parse("Ingredients: 2 eggs, 1 cup milk, 1 cup flour")
        XCTAssertEqual(out.ingredients, ["2 eggs", "1 cup milk", "1 cup flour"])
    }

    func testHeuristicParserNothing() {
        let out = HeuristicRecipeParser.parse("This was so good!! Follow for more 🔥 #food #yum")
        XCTAssertTrue(out.ingredients.isEmpty)
        XCTAssertTrue(out.steps.isEmpty)
    }

    func testSocialCaptionExtraction() {
        let d = "1,234 likes, 56 comments - chef on May 1, 2024: \"Lemon pasta: 200g spaghetti, 1 lemon\"."
        XCTAssertEqual(MetaTags.captionFromSocialDescription(d), "Lemon pasta: 200g spaghetti, 1 lemon")
    }

    func testEmbeddedFullCaption() {
        let html = #"<script>{"itemStruct":{"desc":"Garlic noodles\nIngredients:\n- 200g noodles\n- 4 cloves garlic \u2764\ufe0f","author":"x"},"other":{"desc":"short"}}</script>"#
        let full = EmbeddedText.longest(EmbeddedText.strings(#""desc"\s*:\s*"# + EmbeddedText.jsonString, in: html))
        XCTAssertTrue(full.hasPrefix("Garlic noodles\nIngredients:"))
        XCTAssertTrue(full.contains("4 cloves garlic ❤️"))
        let parsed = HeuristicRecipeParser.parse(full)
        XCTAssertEqual(parsed.ingredients, ["200g noodles", "4 cloves garlic ❤️"])
    }

    func testInstagramEmbeddedCaption() {
        let html = #"{"edge_media_to_caption":{"edges":[{"node":{"created_at":"1","text":"Lemon pasta \"easy\"\nIngredients: 200g spaghetti, 1 lemon"}}]}}"#
        let pattern = #""edge_media_to_caption"\s*:\s*\{\s*"edges"\s*:\s*\[\s*\{\s*"node"\s*:\s*\{[^{}]*?"text"\s*:\s*"# + EmbeddedText.jsonString
        XCTAssertEqual(EmbeddedText.strings(pattern, in: html).first, "Lemon pasta \"easy\"\nIngredients: 200g spaghetti, 1 lemon")
    }

    func testTruncationDetection() {
        XCTAssertTrue(EmbeddedText.looksTruncated("Ingredients: 2 eggs, 1 cup…"))
        XCTAssertTrue(EmbeddedText.looksTruncated("Best pasta ever... more"))
        XCTAssertFalse(EmbeddedText.looksTruncated("Bake for 20 minutes."))
    }

    func testMetaTags() {
        let html = #"<meta property="og:title" content="Best Tacos &amp; More"><meta name="description" content='Tasty'>"#
        let m = MetaTags.parse(html)
        XCTAssertEqual(m["og:title"], "Best Tacos & More")
        XCTAssertEqual(m["description"], "Tasty")
    }

    func testJSONLDRecipeParsing() {
        let html = """
        <html><script type="application/ld+json">{"@context":"https://schema.org","@graph":[{"@type":"WebPage"},
        {"@type":["Recipe"],"name":"Pancakes","recipeYield":"4 servings","prepTime":"PT10M","cookTime":"PT1H5M",
        "recipeIngredient":["1 cup flour","1 egg"],
        "recipeInstructions":[{"@type":"HowToSection","itemListElement":[{"@type":"HowToStep","text":"Mix."},{"@type":"HowToStep","text":"Cook."}]}],
        "image":{"url":"https://example.com/p.jpg"}}]}</script></html>
        """
        let r = RecipeImporter.parse(html: html)
        XCTAssertEqual(r?.title, "Pancakes")
        XCTAssertEqual(r?.servings, 4)
        XCTAssertEqual(r?.prepMinutes, 10)
        XCTAssertEqual(r?.cookMinutes, 65)
        XCTAssertEqual(r?.steps, ["Mix.", "Cook."])
        XCTAssertEqual(r?.imageURL, "https://example.com/p.jpg")
    }

    func testExtractEmbeddedJSON() {
        let html = #"<script>var ytInitialPlayerResponse = {"videoDetails":{"title":"A {tricky} \"title\""}};var x=1;</script>"#
        let obj = VideoSourceFetcher.extractJSON(after: "ytInitialPlayerResponse = ", in: html)
        XCTAssertEqual((obj?["videoDetails"] as? [String: Any])?["title"] as? String, "A {tricky} \"title\"")
    }

    func testAIDraftMarksMissingAmounts() {
        let obj: [String: Any] = [
            "recipeFound": "partial", "title": "Tacos", "description": "", "category": "Dinner", "cuisine": "Mexican", "tags": [],
            "servings": 0, "servingsStatus": "unavailable", "prepMinutes": 0, "prepStatus": "unavailable",
            "cookMinutes": 15, "cookStatus": "confirmed", "totalMinutes": 0, "temperature": "", "temperatureStatus": "unavailable",
            "ingredients": [["quantity": "500 g", "item": "beef", "status": "confirmed", "source": "caption"],
                            ["quantity": "", "item": "cheese", "status": "confirmed", "source": "image 1"]],
            "steps": [["text": "Brown the beef.", "status": "confirmed", "source": "transcript"]],
            "tips": [], "warnings": ["Amount of cheese not given"], "finishedDishImageIndex": -1, "searchQuery": "beef tacos"
        ]
        let d = AIRecipeExtractor.draft(from: obj, images: [])
        XCTAssertEqual(d.ingredients.count, 2)
        XCTAssertEqual(d.ingredients[1].status, .unavailable)
        XCTAssertTrue(d.ingredients[1].text.contains("amount not given"))
        XCTAssertEqual(d.completeness, .partial)
        XCTAssertEqual(d.servingsStatus, .unavailable)
        let recipe = d.makeRecipe()
        XCTAssertEqual(recipe.cookMinutes, 15)
        XCTAssertTrue(recipe.importWarnings.contains("Amount of cheese not given"))
    }
}

final class NutritionTests: XCTestCase {
    func testEstimateWithAmounts() {
        let e = NutritionEstimator.estimate(["100 g chicken breast", "1 tbsp olive oil", "Salt and pepper to taste"])
        XCTAssertTrue(e.isReliable)
        XCTAssertEqual(e.total.kcal, 120 + 884 * 14.7868 / 240 * 216 / 100, accuracy: 15)
        XCTAssertEqual(e.total.protein, 22.5, accuracy: 1)
    }

    func testRefusesWithoutAmounts() {
        let e = NutritionEstimator.estimate(["chicken", "rice", "broccoli", "1 tbsp butter"])
        XCTAssertFalse(e.isReliable, "Most ingredients have no amount, so no numbers should be shown")
        XCTAssertEqual(e.noAmount.count, 3)
    }

    func testFoodMatchingPrefersSpecific() {
        XCTAssertEqual(NutritionEstimator.food(for: "chicken broth")?.keys.first, "chicken broth")
        XCTAssertEqual(NutritionEstimator.food(for: "brown sugar")?.keys.first, "brown sugar")
        XCTAssertEqual(NutritionEstimator.food(for: "eggs")?.keys.first, "egg")
    }
}
