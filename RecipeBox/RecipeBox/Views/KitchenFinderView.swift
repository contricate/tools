import SwiftUI
import SwiftData

struct KitchenFinderView: View {
    @Environment(\.modelContext) private var context
    @Environment(ToastCenter.self) private var toasts
    @Query private var recipes: [Recipe]
    @AppStorage("kitchenIngredients") private var storedRaw = ""
    @AppStorage("kitchenAssumeBasics") private var assumeBasics = true
    @State private var input = ""
    @State private var ideas: [MealDB.Meal] = []
    @State private var loadingIdeas = false
    @State private var previewMeal: MealDB.Meal?

    static let basics = ["salt", "pepper", "black pepper", "oil", "olive oil", "vegetable oil", "water", "ice"]
    static let common = ["chicken", "rice", "garlic", "onion", "butter", "cheese", "eggs", "pasta", "tomatoes",
                         "potatoes", "milk", "flour", "beef", "lemon", "spinach", "bread", "carrots", "bacon"]

    private var have: [String] { storedRaw.split(separator: "\n").map(String.init) }

    struct Match: Identifiable {
        let recipe: Recipe
        let haveCount: Int
        let needCount: Int
        let missing: [String]
        var id: PersistentIdentifier { recipe.persistentModelID }
    }

    private func isBasic(_ key: String) -> Bool {
        Self.basics.contains { key == $0 || key.hasSuffix(" " + $0) && key.split(separator: " ").count <= 2 }
    }

    private var matches: [Match] {
        let mine = have.map { IngredientParser.singular($0.lowercased()) }
        guard !mine.isEmpty else { return [] }
        return recipes.compactMap { r in
            var haveCount = 0
            var missing: [String] = []
            var need = 0
            for line in r.ingredients {
                let key = IngredientParser.key(for: IngredientParser.parse(line).name)
                guard !key.isEmpty else { continue }
                if assumeBasics && isBasic(key) { continue }
                need += 1
                let words = Set(key.split(separator: " ").map(String.init))
                if mine.contains(where: { m in words.contains(m) || key.contains(m) }) { haveCount += 1 }
                else { missing.append(line) }
            }
            guard haveCount > 0 else { return nil }
            return Match(recipe: r, haveCount: haveCount, needCount: need, missing: missing)
        }
        .sorted { ($0.missing.count, -$0.haveCount) < ($1.missing.count, -$1.haveCount) }
    }

    var body: some View {
        let all = matches
        let ready = all.filter { $0.missing.isEmpty }
        let almost = all.filter { (1...2).contains($0.missing.count) }
        let more = all.filter { $0.missing.count > 2 }
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                inputCard
                if have.isEmpty {
                    ContentUnavailableView("What do you have?", systemImage: "refrigerator",
                                           description: Text("Add a few ingredients and you'll see which of your saved recipes you can make."))
                } else if recipes.isEmpty {
                    Text("Your cookbook is empty — add recipes to get matches.").foregroundStyle(.secondary)
                } else if all.isEmpty {
                    Text("None of your saved recipes use these ingredients yet.").foregroundStyle(.secondary)
                } else {
                    group("Ready to cook", subtitle: "You have everything", icon: "checkmark.seal.fill", color: .green, ready)
                    group("Almost there", subtitle: "Missing 1–2 ingredients", icon: "cart.badge.plus", color: .orange, almost)
                    group("Need a shopping trip", subtitle: "Missing 3 or more", icon: "bag", color: .secondary, more)
                }
                if !have.isEmpty { ideasSection }
            }
            .padding()
            .padding(.bottom, 60)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("What's in My Kitchen?")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $previewMeal) { meal in DiscoverMealSheet(meal: meal).themed() }
        .task(id: have.first) { await loadIdeas() }
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "plus.circle.fill").foregroundStyle(Color.accentColor)
                TextField("Add an ingredient you have", text: $input)
                    .onSubmit { add(input) }
                    .submitLabel(.done)
            }
            if !have.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(have, id: \.self) { item in
                        Button { remove(item) } label: {
                            HStack(spacing: 4) { Text(item); Image(systemName: "xmark").font(.caption2) }
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Color.accentColor, in: Capsule())
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove \(item)")
                    }
                }
            }
            Text("Quick add").font(.caption).foregroundStyle(.secondary)
            FlowLayout(spacing: 6) {
                ForEach(Self.common.filter { !have.contains($0) }, id: \.self) { c in
                    Button { add(c) } label: { TagChip(text: "+ \(c)") }.buttonStyle(.plain)
                }
            }
            Toggle("Assume I have salt, pepper, oil & water", isOn: $assumeBasics).font(.subheadline)
            if !have.isEmpty {
                Button("Clear All", role: .destructive) { storedRaw = "" }.font(.caption)
            }
        }
        .card()
    }

    @ViewBuilder
    private func group(_ title: String, subtitle: String, icon: String, color: Color, _ items: [Match]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: icon).foregroundStyle(color)
                    SectionHeader(title: "\(title) (\(items.count))", subtitle: subtitle)
                }
                ForEach(items) { m in matchCard(m) }
            }
        }
    }

    private func matchCard(_ m: Match) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            NavigationLink(value: m.recipe) {
                HStack(spacing: 12) {
                    RecipeThumbnail(recipe: m.recipe, size: 56)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(m.recipe.title).font(.headline).foregroundStyle(.primary)
                        Text("You have \(m.haveCount) of \(m.needCount) ingredients").font(.caption).foregroundStyle(.secondary)
                        ProgressView(value: Double(m.haveCount), total: Double(max(1, m.needCount)))
                            .tint(m.missing.isEmpty ? .green : .orange)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            if !m.missing.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Missing").font(.caption.bold()).foregroundStyle(.orange)
                    ForEach(m.missing.prefix(6), id: \.self) { Text("• \($0)").font(.caption) }
                    if m.missing.count > 6 { Text("+ \(m.missing.count - 6) more").font(.caption).foregroundStyle(.secondary) }
                }
                Button {
                    let n = ShoppingItem.add(m.missing, from: m.recipe.title, in: context)
                    toasts.show(n == 0 ? "Already on your list" : "Added \(n) missing item\(n == 1 ? "" : "s") to Groceries")
                } label: {
                    Label("Add missing to Groceries", systemImage: "cart.badge.plus").font(.caption.bold())
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .card(padding: 12)
    }

    private var ideasSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "More ideas with \(have.first ?? "")", subtitle: "Real recipes from TheMealDB")
            if loadingIdeas {
                ScrollView(.horizontal) { HStack { ForEach(0..<3, id: \.self) { _ in SkeletonCard(height: 190).frame(width: 160) } } }
            } else if ideas.isEmpty {
                Text("No TheMealDB recipes found for “\(have.first ?? "")”.").font(.caption).foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(ideas.prefix(12)) { meal in
                            Button { previewMeal = meal } label: { MealCard(meal: meal) }.buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func add(_ s: String) {
        let t = s.trimmingCharacters(in: .whitespaces).lowercased()
        guard !t.isEmpty, !have.contains(t) else { input = ""; return }
        storedRaw = (have + [t]).joined(separator: "\n")
        input = ""
    }

    private func remove(_ s: String) {
        storedRaw = have.filter { $0 != s }.joined(separator: "\n")
    }

    private func loadIdeas() async {
        guard let first = have.first else { ideas = []; return }
        loadingIdeas = true
        ideas = (try? await MealDB.byIngredient(IngredientParser.singular(first))) ?? []
        if ideas.isEmpty { ideas = (try? await MealDB.byIngredient(first)) ?? [] }
        loadingIdeas = false
    }
}
