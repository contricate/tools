import SwiftUI
import SwiftData

struct ImportHistoryView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ImportRecord.date, order: .reverse) private var records: [ImportRecord]
    @Query private var recipes: [Recipe]
    @State private var filter = "All"

    private var filtered: [ImportRecord] {
        switch filter {
        case "Saved": return records.filter { $0.outcome == "accepted" }
        case "Needs Attention": return records.filter { $0.outcome != "accepted" && ($0.status == "failed" || $0.status == "none" || $0.outcome == "rejected") }
        default: return records
        }
    }

    var body: some View {
        List {
            Section {
                Picker("Filter", selection: $filter) {
                    ForEach(["All", "Saved", "Needs Attention"], id: \.self) { Text($0) }
                }
                .pickerStyle(.segmented)
            }
            .listRowBackground(Color.clear)
            if filtered.isEmpty {
                ContentUnavailableView("No imports", systemImage: "clock.arrow.circlepath",
                                       description: Text("Links you import will appear here."))
                    .listRowBackground(Color.clear)
            }
            ForEach(filtered) { rec in
                VStack(alignment: .leading, spacing: 8) {
                    ImportRecordRow(record: rec)
                    if !rec.errorMessage.isEmpty && rec.outcome != "accepted" {
                        Text(rec.errorMessage).font(.caption).foregroundStyle(.secondary)
                    }
                    HStack {
                        if let r = recipes.first(where: { $0.uid == rec.recipeUID && !rec.recipeUID.isEmpty }) {
                            Button("Open Recipe") { router.open(r) }
                                .buttonStyle(.bordered)
                        } else {
                            Button("Retry Import") { router.startImport(rec.url) }
                                .buttonStyle(.borderedProminent)
                        }
                        if let u = URL(string: rec.url) {
                            Link(destination: u) { Label("Open Link", systemImage: "arrow.up.right.square") }
                                .buttonStyle(.bordered)
                        }
                    }
                    .font(.caption.bold())
                    .controlSize(.small)
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            .onDelete { idx in
                let items = filtered
                for i in idx { context.delete(items[i]) }
            }
        }
        .listStyle(.plain)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Import History")
    }
}
