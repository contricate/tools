import SwiftUI
import SwiftData

struct RecipeDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var recipe: Recipe

    @State private var servings = 0
    @State private var checkedIngredients: Set<Int> = []
    @State private var completedSteps: Set<Int> = []
    @State private var showingEdit = false
    @State private var showingDeleteConfirm = false
    @State private var showingCookMode = false
    @State private var showingPlan = false
    @State private var toast: String?
    @State private var cookedBounce = 0

    private var factor: Double {
        guard recipe.servings > 0, servings > 0 else { return 1 }
        return Double(servings) / Double(recipe.servings)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero
                VStack(alignment: .leading, spacing: 22) {
                    titleBlock
                    infoBar
                    if !recipe.steps.isEmpty { cookButton }
                    if !recipe.ingredients.isEmpty { ingredientsSection }
                    if !recipe.steps.isEmpty { stepsSection }
                    if !recipe.notes.isEmpty {
                        section("Notes", icon: "note.text") {
                            Text(recipe.notes)
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    if let url = URL(string: recipe.sourceURL), !recipe.sourceURL.isEmpty, url.scheme != nil {
                        section("Source", icon: "link") {
                            Link(destination: url) {
                                Text(url.host ?? recipe.sourceURL).lineLimit(1)
                            }
                        }
                    }
                    cookedSection
                }
                .padding()
            }
        }
        .ignoresSafeArea(edges: recipe.photoData == nil ? [] : .top)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    recipe.isFavorite.toggle()
                } label: {
                    Image(systemName: recipe.isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(.pink)
                        .symbolEffect(.bounce, value: recipe.isFavorite)
                }
                .sensoryFeedback(.impact, trigger: recipe.isFavorite)
                Menu {
                    Button("Edit Recipe", systemImage: "pencil") { showingEdit = true }
                    Button("Add to Meal Plan", systemImage: "calendar.badge.plus") { showingPlan = true }
                    Button("Add to Shopping List", systemImage: "cart.badge.plus") { addToShoppingList() }
                    ShareLink(item: recipe.shareText) { Label("Share Recipe", systemImage: "square.and.arrow.up") }
                    Button("Duplicate", systemImage: "plus.square.on.square") { duplicate() }
                    Divider()
                    Button("Delete", systemImage: "trash", role: .destructive) { showingDeleteConfirm = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            RecipeEditView(recipe: recipe)
        }
        .sheet(isPresented: $showingPlan) {
            PlanRecipeSheet(recipe: recipe) { toast = $0 }
        }
        .fullScreenCover(isPresented: $showingCookMode) {
            CookModeView(recipe: recipe, factor: factor)
        }
        .confirmationDialog("Delete this recipe?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                context.delete(recipe)
                dismiss()
            }
        }
        .onAppear { if servings == 0 { servings = recipe.servings } }
        .onChange(of: recipe.servings) { _, new in servings = new }
        .toast($toast)
    }

    // MARK: Sections

    @ViewBuilder
    private var hero: some View {
        if let data = recipe.photoData, let image = UIImage(data: data) {
            Color.clear
                .frame(height: 320)
                .overlay {
                    Image(uiImage: image).resizable().scaledToFill()
                }
                .clipped()
                .overlay(alignment: .bottom) {
                    LinearGradient(colors: [.clear, Color(.systemBackground)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 70)
                }
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(recipe.category.uppercased(), systemImage: Recipe.icon(for: recipe.category))
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.accentColor)
            Text(recipe.title)
                .font(.system(.largeTitle, design: .serif).bold())
            if !recipe.summary.isEmpty {
                Text(recipe.summary)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            StarRating(rating: $recipe.rating, size: 22, editable: true)
                .padding(.top, 2)
        }
    }

    private var infoBar: some View {
        HStack(spacing: 0) {
            info("timer", "Prep", recipe.prepMinutes > 0 ? Recipe.format(minutes: recipe.prepMinutes) : "—")
            Divider().frame(height: 34)
            info("flame", "Cook", recipe.cookMinutes > 0 ? Recipe.format(minutes: recipe.cookMinutes) : "—")
            Divider().frame(height: 34)
            info("clock", "Total", recipe.totalMinutes > 0 ? Recipe.format(minutes: recipe.totalMinutes) : "—")
        }
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func info(_ icon: String, _ label: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon).foregroundStyle(Color.accentColor)
            Text(value).font(.subheadline.weight(.semibold))
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var cookButton: some View {
        Button {
            showingCookMode = true
        } label: {
            HStack {
                Image(systemName: "frying.pan.fill")
                Text("Start Cooking").font(.headline)
                Spacer()
                Text("\(recipe.steps.count) steps").font(.subheadline).opacity(0.85)
                Image(systemName: "chevron.right")
            }
            .padding()
            .foregroundStyle(.white)
            .background(
                LinearGradient(colors: [Color.accentColor, Color.accentColor.opacity(0.75)],
                               startPoint: .leading, endPoint: .trailing),
                in: RoundedRectangle(cornerRadius: 14)
            )
        }
        .buttonStyle(.plain)
    }

    private var ingredientsSection: some View {
        section("Ingredients", icon: "basket") {
            HStack {
                Text("Servings").font(.subheadline.weight(.medium))
                Spacer()
                HStack(spacing: 14) {
                    Button { servings = max(1, servings - 1) } label: { Image(systemName: "minus.circle.fill") }
                        .disabled(servings <= 1)
                    Text("\(servings)")
                        .font(.headline.monospacedDigit())
                        .frame(minWidth: 28)
                        .contentTransition(.numericText())
                    Button { servings = min(200, servings + 1) } label: { Image(systemName: "plus.circle.fill") }
                }
                .font(.title2)
                .animation(.snappy, value: servings)
                .sensoryFeedback(.selection, trigger: servings)
            }
            .padding(12)
            .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))

            if servings != recipe.servings {
                Text("Amounts scaled from \(recipe.servings) servings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { index, item in
                Button {
                    toggle(index, in: &checkedIngredients)
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: checkedIngredients.contains(index) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(checkedIngredients.contains(index) ? Color.accentColor : .secondary)
                        Text(IngredientScaler.scale(item, by: factor))
                            .strikethrough(checkedIngredients.contains(index))
                            .foregroundStyle(checkedIngredients.contains(index) ? .secondary : .primary)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Button {
                addToShoppingList()
            } label: {
                Label("Add to Shopping List", systemImage: "cart.badge.plus")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .padding(.top, 4)
        }
    }

    private var stepsSection: some View {
        section("Steps", icon: "list.number") {
            ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                Button {
                    toggle(index, in: &completedSteps)
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle().fill(completedSteps.contains(index) ? Color.secondary.opacity(0.3) : Color.accentColor)
                            if completedSteps.contains(index) {
                                Image(systemName: "checkmark").font(.caption.bold())
                            } else {
                                Text("\(index + 1)").font(.subheadline.bold())
                            }
                        }
                        .frame(width: 28, height: 28)
                        .foregroundStyle(.white)
                        Text(step)
                            .foregroundStyle(completedSteps.contains(index) ? .secondary : .primary)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var cookedSection: some View {
        VStack(spacing: 8) {
            Button {
                recipe.timesCooked += 1
                recipe.lastCooked = Date()
                cookedBounce += 1
                toast = "Nice! Marked as cooked 🍽️"
            } label: {
                Label("I Made This!", systemImage: "checkmark.seal.fill")
                    .symbolEffect(.bounce, value: cookedBounce)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .sensoryFeedback(.success, trigger: cookedBounce)
            if recipe.timesCooked > 0 {
                Text("Cooked \(recipe.timesCooked) time\(recipe.timesCooked == 1 ? "" : "s")" +
                     (recipe.lastCooked.map { " · last on \($0.formatted(date: .abbreviated, time: .omitted))" } ?? ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 8)
    }

    private func section<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.title2.bold())
                .labelStyle(.titleOnly)
            content()
        }
    }

    // MARK: Actions

    private func toggle(_ i: Int, in set: inout Set<Int>) {
        if set.contains(i) { set.remove(i) } else { set.insert(i) }
    }

    private func addToShoppingList() {
        let lines = recipe.ingredients.map { IngredientScaler.scale($0, by: factor) }
        let n = ShoppingItem.add(lines, from: recipe.title, in: context)
        toast = n == 0 ? "Already on your shopping list" : "Added \(n) item\(n == 1 ? "" : "s") to Shopping 🛒"
    }

    private func duplicate() {
        let copy = RecipeBackup(recipe).makeRecipe()
        copy.title = recipe.title + " (Copy)"
        copy.createdAt = Date()
        copy.timesCooked = 0
        copy.lastCooked = nil
        context.insert(copy)
        toast = "Duplicated"
    }
}
