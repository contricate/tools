import SwiftUI
import SwiftData

struct RecipeDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var recipe: Recipe

    @State private var checkedIngredients: Set<Int> = []
    @State private var completedSteps: Set<Int> = []
    @State private var showingEdit = false
    @State private var showingDeleteConfirm = false
    @State private var keepAwake = false
    @State private var toast: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                infoBar
                if !recipe.ingredients.isEmpty { ingredientsSection }
                if !recipe.steps.isEmpty { stepsSection }
                if !recipe.notes.isEmpty {
                    section("Notes") {
                        Text(recipe.notes)
                    }
                }
                if let url = URL(string: recipe.sourceURL), !recipe.sourceURL.isEmpty, url.scheme != nil {
                    section("Source") {
                        Link(recipe.sourceURL, destination: url).lineLimit(1)
                    }
                }
                cookedSection
            }
            .padding()
        }
        .navigationTitle(recipe.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    recipe.isFavorite.toggle()
                } label: {
                    Image(systemName: recipe.isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(.pink)
                }
                Menu {
                    Button("Edit", systemImage: "pencil") { showingEdit = true }
                    Button("Add Ingredients to Shopping List", systemImage: "cart.badge.plus") { addToShoppingList() }
                    Toggle("Keep Screen On", systemImage: "sun.max", isOn: $keepAwake)
                    ShareLink(item: recipe.shareText) { Label("Share", systemImage: "square.and.arrow.up") }
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
        .confirmationDialog("Delete this recipe?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                context.delete(recipe)
                dismiss()
            }
        }
        .onChange(of: keepAwake) { _, on in
            UIApplication.shared.isIdleTimerDisabled = on
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let data = recipe.photoData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            Text(recipe.title).font(.largeTitle.bold())
            if !recipe.summary.isEmpty {
                Text(recipe.summary).foregroundStyle(.secondary)
            }
            StarRating(rating: $recipe.rating, size: 22, editable: true)
        }
    }

    private var infoBar: some View {
        HStack {
            info(Recipe.icon(for: recipe.category), recipe.category)
            Divider().frame(height: 30)
            info("person.2", "Serves \(recipe.servings)")
            if recipe.prepMinutes > 0 {
                Divider().frame(height: 30)
                info("timer", "Prep \(Recipe.format(minutes: recipe.prepMinutes))")
            }
            if recipe.cookMinutes > 0 {
                Divider().frame(height: 30)
                info("flame", "Cook \(Recipe.format(minutes: recipe.cookMinutes))")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func info(_ icon: String, _ text: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundStyle(Color.accentColor)
            Text(text).font(.caption).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var ingredientsSection: some View {
        section("Ingredients") {
            ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { index, item in
                Button {
                    toggle(index, in: &checkedIngredients)
                } label: {
                    HStack(alignment: .top) {
                        Image(systemName: checkedIngredients.contains(index) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(checkedIngredients.contains(index) ? Color.accentColor : .secondary)
                        Text(item)
                            .strikethrough(checkedIngredients.contains(index))
                            .foregroundStyle(checkedIngredients.contains(index) ? .secondary : .primary)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var stepsSection: some View {
        section("Steps") {
            ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                Button {
                    toggle(index, in: &completedSteps)
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.subheadline.bold())
                            .frame(width: 28, height: 28)
                            .background(completedSteps.contains(index) ? Color.secondary.opacity(0.3) : Color.accentColor, in: Circle())
                            .foregroundStyle(.white)
                        Text(step)
                            .foregroundStyle(completedSteps.contains(index) ? .secondary : .primary)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
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
                showToast("Nice! Marked as cooked 🍽️")
            } label: {
                Label("I Made This!", systemImage: "checkmark.seal")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            if recipe.timesCooked > 0 {
                Text("Cooked \(recipe.timesCooked) time\(recipe.timesCooked == 1 ? "" : "s")" +
                     (recipe.lastCooked.map { " · last on \($0.formatted(date: .abbreviated, time: .omitted))" } ?? ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 8)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.title2.bold())
            content()
        }
    }

    private func toggle(_ i: Int, in set: inout Set<Int>) {
        if set.contains(i) { set.remove(i) } else { set.insert(i) }
    }

    private func addToShoppingList() {
        for item in recipe.ingredients {
            context.insert(ShoppingItem(name: item, fromRecipe: recipe.title))
        }
        showToast("Added \(recipe.ingredients.count) items to Shopping")
    }

    private func showToast(_ message: String) {
        withAnimation { toast = message }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { toast = nil }
        }
    }
}
