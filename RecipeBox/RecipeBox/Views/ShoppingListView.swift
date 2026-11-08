import SwiftUI
import SwiftData

struct ShoppingListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ShoppingItem.createdAt) private var items: [ShoppingItem]
    @State private var newItem = ""
    @FocusState private var fieldFocused: Bool

    private var unchecked: [ShoppingItem] { items.filter { !$0.isChecked } }
    private var checked: [ShoppingItem] { items.filter { $0.isChecked } }
    private var aisles: [String] {
        let used = Set(unchecked.map { GroceryAisle.classify($0.name) })
        return GroceryAisle.order.filter { used.contains($0) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: "plus.circle.fill").foregroundStyle(Color.accentColor)
                        TextField("Add item", text: $newItem)
                            .focused($fieldFocused)
                            .submitLabel(.done)
                            .onSubmit(add)
                    }
                }
                if items.isEmpty {
                    Section {
                        Text("Your shopping list is empty. Add items here, or open a recipe and choose “Add Ingredients to Shopping List”.")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                }
                ForEach(aisles, id: \.self) { aisle in
                    let list = unchecked.filter { GroceryAisle.classify($0.name) == aisle }
                    Section {
                        ForEach(list) { row($0) }
                            .onDelete { delete($0, from: list) }
                    } header: {
                        Label("\(aisle) (\(list.count))", systemImage: GroceryAisle.icon(aisle))
                    }
                }
                if !checked.isEmpty {
                    Section("In Cart (\(checked.count))") {
                        ForEach(checked) { row($0) }
                            .onDelete { delete($0, from: checked) }
                    }
                }
            }
            .navigationTitle("Shopping List")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Clear Checked Items", systemImage: "checkmark.circle") {
                            for item in checked { context.delete(item) }
                        }
                        .disabled(checked.isEmpty)
                        Button("Clear Everything", systemImage: "trash", role: .destructive) {
                            for item in items { context.delete(item) }
                        }
                        .disabled(items.isEmpty)
                        ShareLink(item: shareText) { Label("Share List", systemImage: "square.and.arrow.up") }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }

    private func row(_ item: ShoppingItem) -> some View {
        Button {
            withAnimation(.snappy) { item.isChecked.toggle() }
        } label: {
            HStack {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isChecked ? Color.accentColor : .secondary)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .strikethrough(item.isChecked)
                        .foregroundStyle(item.isChecked ? .secondary : .primary)
                    if !item.fromRecipe.isEmpty {
                        Text(item.fromRecipe).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: item.isChecked)
    }

    private var shareText: String {
        var text = "Shopping List"
        for aisle in aisles {
            text += "\n\n\(aisle.uppercased())\n"
            text += unchecked.filter { GroceryAisle.classify($0.name) == aisle }
                .map { "☐ \($0.name)" }.joined(separator: "\n")
        }
        return text
    }

    private func add() {
        let t = newItem.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        context.insert(ShoppingItem(name: t))
        newItem = ""
        fieldFocused = true
    }

    private func delete(_ offsets: IndexSet, from list: [ShoppingItem]) {
        for i in offsets { context.delete(list[i]) }
    }
}
