import SwiftUI
import SwiftData

private struct DayTarget: Identifiable {
    let date: Date
    var id: Date { date }
}

struct MealPlanView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \MealPlanEntry.date) private var entries: [MealPlanEntry]
    @State private var weekStart = Calendar.current.startOfWeek(for: Date())
    @State private var addingFor: DayTarget?
    @State private var toast: String?
    @State private var confirmClear = false

    private var days: [Date] {
        (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: weekStart) }
    }

    private var weekEntries: [MealPlanEntry] {
        guard let end = Calendar.current.date(byAdding: .day, value: 7, to: weekStart) else { return [] }
        return entries.filter { $0.date >= weekStart && $0.date < end && $0.recipe != nil }
    }

    private func entries(on day: Date) -> [MealPlanEntry] {
        weekEntries
            .filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
            .sorted { (MealPlanEntry.meals.firstIndex(of: $0.meal) ?? 9) < (MealPlanEntry.meals.firstIndex(of: $1.meal) ?? 9) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    weekSwitcher
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                ForEach(days, id: \.self) { day in
                    Section {
                        ForEach(entries(on: day)) { entry in
                            if let recipe = entry.recipe {
                                NavigationLink(value: recipe) {
                                    HStack(spacing: 12) {
                                        RecipeThumbnail(recipe: recipe, size: 44)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(entry.meal.uppercased())
                                                .font(.caption2.weight(.bold))
                                                .foregroundStyle(Color.accentColor)
                                            Text(recipe.title).font(.body.weight(.medium))
                                        }
                                    }
                                }
                            }
                        }
                        .onDelete { offsets in
                            let list = entries(on: day)
                            for i in offsets { context.delete(list[i]) }
                        }
                        Button {
                            addingFor = DayTarget(date: day)
                        } label: {
                            Label("Add a meal", systemImage: "plus")
                                .font(.subheadline)
                        }
                    } header: {
                        dayHeader(day)
                    }
                }
            }
            .navigationTitle("Meal Plan")
            .navigationDestination(for: Recipe.self) { RecipeDetailView(recipe: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Add Week to Shopping List", systemImage: "cart.badge.plus") { addWeekToShopping() }
                            .disabled(weekEntries.isEmpty)
                        Button("Clear This Week", systemImage: "trash", role: .destructive) { confirmClear = true }
                            .disabled(weekEntries.isEmpty)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(item: $addingFor) { target in
                PickRecipeSheet(date: target.date)
            }
            .confirmationDialog("Remove all meals planned this week?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Clear Week", role: .destructive) {
                    for e in weekEntries { context.delete(e) }
                }
            }
            .toast($toast)
        }
    }

    private var weekSwitcher: some View {
        HStack {
            Button { shiftWeek(-1) } label: { Image(systemName: "chevron.left.circle.fill").font(.title2) }
            Spacer()
            VStack(spacing: 2) {
                Text(weekTitle).font(.headline)
                Text("\(weekEntries.count) meal\(weekEntries.count == 1 ? "" : "s") planned")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .onTapGesture { weekStart = Calendar.current.startOfWeek(for: Date()) }
            Spacer()
            Button { shiftWeek(1) } label: { Image(systemName: "chevron.right.circle.fill").font(.title2) }
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
        .padding(.vertical, 8)
    }

    private var weekTitle: String {
        let cal = Calendar.current
        if cal.isDate(weekStart, equalTo: Date(), toGranularity: .weekOfYear) { return "This Week" }
        if let next = cal.date(byAdding: .weekOfYear, value: 1, to: Date()),
           cal.isDate(weekStart, equalTo: next, toGranularity: .weekOfYear) { return "Next Week" }
        if let last = cal.date(byAdding: .weekOfYear, value: -1, to: Date()),
           cal.isDate(weekStart, equalTo: last, toGranularity: .weekOfYear) { return "Last Week" }
        return "Week of " + weekStart.formatted(.dateTime.month(.abbreviated).day())
    }

    private func dayHeader(_ day: Date) -> some View {
        let isToday = Calendar.current.isDateInToday(day)
        return HStack {
            Text(day.formatted(.dateTime.weekday(.wide)))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(isToday ? Color.accentColor : .primary)
            Text(day.formatted(.dateTime.month(.abbreviated).day()))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if isToday {
                Text("TODAY")
                    .font(.caption2.weight(.heavy))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.accentColor, in: Capsule())
                    .foregroundStyle(.white)
            }
        }
        .textCase(nil)
    }

    private func shiftWeek(_ n: Int) {
        if let d = Calendar.current.date(byAdding: .weekOfYear, value: n, to: weekStart) {
            withAnimation { weekStart = d }
        }
    }

    private func addWeekToShopping() {
        var total = 0
        for e in weekEntries {
            if let r = e.recipe { total += ShoppingItem.add(r.ingredients, from: r.title, in: context) }
        }
        toast = total == 0 ? "Everything's already on your list" : "Added \(total) items to Shopping"
    }
}

/// Choose a recipe to cook on a given day.
struct PickRecipeSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Recipe.title) private var recipes: [Recipe]
    let date: Date
    @State private var meal = "Dinner"
    @State private var search = ""

    private var filtered: [Recipe] {
        search.isEmpty ? recipes : recipes.filter { $0.title.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Meal", selection: $meal) {
                        ForEach(MealPlanEntry.meals, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Choose a recipe") {
                    if recipes.isEmpty {
                        Text("Add some recipes first.").foregroundStyle(.secondary)
                    }
                    ForEach(filtered) { recipe in
                        Button {
                            context.insert(MealPlanEntry(date: date, meal: meal, recipe: recipe))
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                RecipeThumbnail(recipe: recipe, size: 44)
                                Text(recipe.title).foregroundStyle(.primary)
                                Spacer()
                                if recipe.isFavorite { Image(systemName: "heart.fill").foregroundStyle(.pink) }
                            }
                        }
                    }
                }
            }
            .searchable(text: $search)
            .navigationTitle(date.formatted(.dateTime.weekday(.wide).month().day()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Choose a day to cook a given recipe.
struct PlanRecipeSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe
    var onDone: (String) -> Void = { _ in }
    @State private var date = Date()
    @State private var meal = "Dinner"

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Day", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                Picker("Meal", selection: $meal) {
                    ForEach(MealPlanEntry.meals, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            .navigationTitle("Plan \(recipe.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        context.insert(MealPlanEntry(date: date, meal: meal, recipe: recipe))
                        onDone("Planned for \(date.formatted(.dateTime.weekday(.wide)))")
                        dismiss()
                    }
                    .bold()
                }
            }
        }
        .presentationDetents([.large])
    }
}
