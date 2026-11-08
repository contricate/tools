import SwiftUI

/// Shows an extracted/generated recipe for review. Nothing is saved until the user taps Accept.
struct RecipePreviewView: View {
    @Binding var draft: RecipeDraft
    var acceptTitle = "Accept Recipe"
    var rejectTitle = "Reject"
    var onAccept: (RecipeDraft) -> Void
    var onReject: () -> Void

    @State private var editing = false
    @State private var imageIndex = 0
    @State private var confirmReject = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !draft.images.isEmpty { gallery }
                VStack(alignment: .leading, spacing: 20) {
                    statusBanner
                    titleSection
                    infoGrid
                    if !draft.warnings.isEmpty { warningsSection }
                    ingredientsSection
                    stepsSection
                    if !draft.tips.isEmpty || editing { tipsSection }
                    if !draft.ingredients.isEmpty {
                        NutritionSummaryView(ingredients: draft.ingredients.map(\.text),
                                             servings: max(1, draft.servings), servingsKnown: draft.servings > 0)
                    }
                    if !draft.sourceDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { descriptionSection }
                    sourceSection
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 110)
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) { actionBar }
        .confirmationDialog("Discard this recipe?", isPresented: $confirmReject, titleVisibility: .visible) {
            Button("Discard", role: .destructive, action: onReject)
        } message: {
            Text("Nothing will be saved to your cookbook.")
        }
    }

    // MARK: Images

    private var gallery: some View {
        VStack(spacing: 8) {
            TabView(selection: $imageIndex) {
                ForEach(Array(draft.images.enumerated()), id: \.element.id) { i, img in
                    ZStack(alignment: .bottomLeading) {
                        if let ui = UIImage(data: img.data) {
                            Color.clear.overlay { Image(uiImage: ui).resizable().scaledToFill() }.clipped()
                        }
                        LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .center, endPoint: .bottom)
                        HStack {
                            Label(img.label, systemImage: imageIcon(img.kind))
                                .font(.caption.bold()).foregroundStyle(.white)
                            Spacer()
                            if draft.coverImageID == img.id {
                                Badge(text: "Cover", icon: "checkmark", color: .white)
                            } else {
                                Button("Use as Cover") { draft.coverImageID = img.id }
                                    .font(.caption.bold())
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.mini)
                            }
                        }
                        .padding(12)
                    }
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: draft.images.count > 1 ? .always : .never))
            .frame(height: 280)
            HStack {
                Text("Images come from the original post or page. ")
                + Text(draft.coverImageID == nil ? "No cover selected." : "")
                Spacer()
                if draft.coverImageID != nil {
                    Button("No Cover") { draft.coverImageID = nil }.font(.caption)
                }
            }
            .font(.caption2).foregroundStyle(.secondary)
            .padding(.horizontal)
        }
    }

    private func imageIcon(_ k: DraftImage.Kind) -> String {
        switch k {
        case .thumbnail: return "photo"
        case .frame: return "film"
        case .dish: return "fork.knife"
        case .sourcePhoto: return "globe"
        case .screenshot: return "camera.viewfinder"
        }
    }

    // MARK: Banners

    @ViewBuilder private var statusBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !draft.originNote.isEmpty {
                Label(draft.originNote, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
            }
            HStack(spacing: 8) {
                switch draft.completeness {
                case .complete: Badge(text: "Complete recipe found", icon: "checkmark.seal.fill", color: .green)
                case .partial: Badge(text: "Partial recipe — review highlighted items", icon: "exclamationmark.circle.fill", color: .orange)
                case .none: Badge(text: "No recipe found", icon: "xmark.circle", color: .red)
                }
                if draft.sourceKind == "ai" { Badge(text: "AI-generated", icon: "sparkles", color: .purple) }
            }
        }
        .padding(.top, draft.images.isEmpty ? 8 : 0)
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if editing {
                TextField("Recipe name", text: $draft.title, axis: .vertical)
                    .font(.title.bold())
                    .padding(10)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                TextField("Description", text: $draft.summary, axis: .vertical)
                    .padding(10)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                Picker("Category", selection: $draft.category) {
                    ForEach(Recipe.categories, id: \.self) { Text($0).tag($0) }
                }
            } else {
                Text(draft.title.isEmpty ? "Untitled Recipe" : draft.title)
                    .font(.system(.title, design: .serif).bold())
                if !draft.summary.isEmpty {
                    Text(draft.summary).foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    TagChip(text: draft.category)
                    if !draft.cuisine.isEmpty { TagChip(text: draft.cuisine) }
                    ForEach(draft.tags, id: \.self) { TagChip(text: $0) }
                }
            }
        }
    }

    private var infoGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            infoCell("Servings", icon: "person.2", value: draft.servings > 0 ? "\(draft.servings)" : "—", status: draft.servingsStatus) {
                Stepper("", value: $draft.servings, in: 0...100).labelsHidden()
            } onEdit: { draft.servingsStatus = draft.servings > 0 ? .confirmed : .unavailable }
            infoCell("Prep", icon: "timer", value: draft.prepMinutes > 0 ? Recipe.format(minutes: draft.prepMinutes) : "—", status: draft.prepStatus) {
                Stepper("", value: $draft.prepMinutes, in: 0...1440, step: 5).labelsHidden()
            } onEdit: { draft.prepStatus = draft.prepMinutes > 0 ? .confirmed : .unavailable }
            infoCell("Cook", icon: "flame", value: draft.cookMinutes > 0 ? Recipe.format(minutes: draft.cookMinutes) : "—", status: draft.cookStatus) {
                Stepper("", value: $draft.cookMinutes, in: 0...1440, step: 5).labelsHidden()
            } onEdit: { draft.cookStatus = draft.cookMinutes > 0 ? .confirmed : .unavailable }
            infoCell("Temperature", icon: "thermometer.medium", value: draft.temperature.isEmpty ? "—" : draft.temperature, status: draft.temperatureStatus) {
                TextField("e.g. 200°C", text: $draft.temperature).font(.caption)
            } onEdit: { draft.temperatureStatus = draft.temperature.isEmpty ? .unavailable : .confirmed }
        }
    }

    private func infoCell<E: View>(_ label: String, icon: String, value: String, status: FieldStatus,
                                   @ViewBuilder editor: () -> E, onEdit: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(label, systemImage: icon).font(.caption).foregroundStyle(.secondary)
                Spacer()
                statusDot(status)
            }
            if editing {
                HStack { Text(value).font(.subheadline.bold()); editor() }
                    .onDisappear(perform: onEdit)
            } else {
                Text(value).font(.headline)
                if status != .confirmed {
                    Text(status.label).font(.caption2).foregroundStyle(status == .estimated ? .orange : .secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 12)
    }

    private func statusDot(_ s: FieldStatus) -> some View {
        Circle()
            .fill(s == .confirmed ? Color.green : s == .estimated ? .orange : Color(.systemGray3))
            .frame(width: 8, height: 8)
            .accessibilityLabel(s.label)
    }

    private var warningsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Check before cooking", systemImage: "exclamationmark.triangle").font(.headline).foregroundStyle(.orange)
            ForEach(draft.warnings, id: \.self) { w in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                    Text(w).font(.subheadline)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: DS.corner, style: .continuous))
    }

    // MARK: Lists

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Ingredients").font(.title3.bold())
                Spacer()
                Text("\(draft.ingredients.count)").foregroundStyle(.secondary)
            }
            if draft.ingredients.isEmpty && !editing {
                Text("No ingredients were found.").foregroundStyle(.secondary)
            }
            ForEach($draft.ingredients) { $line in
                lineRow($line, numbered: nil) { draft.ingredients.removeAll { $0.id == line.id } }
            }
            if editing {
                Button { draft.ingredients.append(DraftLine(text: "", status: .confirmed)) } label: {
                    Label("Add Ingredient", systemImage: "plus.circle.fill")
                }
            }
        }
        .card()
    }

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Instructions").font(.title3.bold())
                Spacer()
                Text("\(draft.steps.count) steps").foregroundStyle(.secondary)
            }
            if draft.steps.isEmpty && !editing {
                Text("No instructions were found.").foregroundStyle(.secondary)
            }
            ForEach(Array(draft.steps.enumerated()), id: \.element.id) { i, line in
                lineRow(stepBinding(line.id), numbered: i + 1) { draft.steps.removeAll { $0.id == line.id } }
            }
            if editing {
                Button { draft.steps.append(DraftLine(text: "", status: .confirmed)) } label: {
                    Label("Add Step", systemImage: "plus.circle.fill")
                }
            }
        }
        .card()
    }

    private func stepBinding(_ id: UUID) -> Binding<DraftLine> {
        Binding(get: { draft.steps.first { $0.id == id } ?? DraftLine(text: "") },
                set: { v in if let i = draft.steps.firstIndex(where: { $0.id == id }) { draft.steps[i] = v } })
    }

    private func lineRow(_ line: Binding<DraftLine>, numbered: Int?, onDelete: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if let n = numbered {
                Text("\(n)").font(.caption.bold()).foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(Color.accentColor, in: Circle())
            } else {
                statusDot(line.wrappedValue.status).padding(.top, 6)
            }
            if editing {
                TextField(numbered == nil ? "Ingredient" : "Step", text: line.text, axis: .vertical)
                    .onChange(of: line.wrappedValue.text) { _, _ in
                        if line.wrappedValue.status != .confirmed { line.wrappedValue.status = .confirmed }
                    }
                Button(role: .destructive, action: onDelete) { Image(systemName: "minus.circle.fill").foregroundStyle(.red) }
                    .buttonStyle(.plain)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(line.wrappedValue.text)
                    if line.wrappedValue.status != .confirmed {
                        Text(line.wrappedValue.status == .estimated
                             ? "Estimated\(line.wrappedValue.note.isEmpty ? "" : " · \(line.wrappedValue.note)")"
                             : "Amount not found in source")
                            .font(.caption)
                            .foregroundStyle(line.wrappedValue.status == .estimated ? .orange : .secondary)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.vertical, 2)
        .background(line.wrappedValue.status == .confirmed || editing ? Color.clear : Color.orange.opacity(0.06))
    }

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tips & Notes").font(.title3.bold())
            if editing {
                TextField("Tips", text: Binding(get: { draft.tips.joined(separator: "\n") },
                                                set: { draft.tips = $0.components(separatedBy: "\n") }), axis: .vertical)
            } else {
                ForEach(draft.tips, id: \.self) { Text("• \($0)") }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    @State private var showDescription = false

    private var descriptionSection: some View {
        DisclosureGroup(isExpanded: $showDescription) {
            VStack(alignment: .leading, spacing: 8) {
                Text(draft.sourceDescription)
                    .font(.subheadline)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    UIPasteboard.general.string = draft.sourceDescription
                } label: { Label("Copy Description", systemImage: "doc.on.doc") }
                .font(.caption.bold())
            }
            .padding(.top, 8)
        } label: {
            Label("Video description", systemImage: "text.alignleft").font(.headline)
        }
        .card()
    }

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Source").font(.headline)
            if !draft.platform.isEmpty {
                Label(draft.platform + (draft.creator.isEmpty ? "" : " · \(draft.creator)"),
                      systemImage: (VideoPlatform(rawValue: draft.platform) ?? .website).icon)
            }
            if let u = URL(string: draft.sourceURL), !draft.sourceURL.isEmpty {
                Link(destination: u) { Text(draft.sourceURL).lineLimit(1).font(.caption) }
            }
            if !draft.evidence.isEmpty {
                Text("Analyzed: " + draft.evidence.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                legend(.green, "From source")
                legend(.orange, "Estimated")
                legend(Color(.systemGray3), "Not found")
            }
            .font(.caption2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func legend(_ c: Color, _ t: String) -> some View {
        HStack(spacing: 4) { Circle().fill(c).frame(width: 7, height: 7); Text(t).foregroundStyle(.secondary) }
    }

    // MARK: Action bar

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button(role: .destructive) { confirmReject = true } label: {
                Label(rejectTitle, systemImage: "xmark").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            Button {
                withAnimation(.snappy) {
                    if editing {
                        draft.ingredients.removeAll { $0.text.trimmingCharacters(in: .whitespaces).isEmpty }
                        draft.steps.removeAll { $0.text.trimmingCharacters(in: .whitespaces).isEmpty }
                    }
                    editing.toggle()
                }
            } label: {
                Label(editing ? "Done" : "Edit", systemImage: editing ? "checkmark" : "pencil").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            Button {
                draft.ingredients.removeAll { $0.text.trimmingCharacters(in: .whitespaces).isEmpty }
                draft.steps.removeAll { $0.text.trimmingCharacters(in: .whitespaces).isEmpty }
                onAccept(draft)
            } label: {
                Label(acceptTitle, systemImage: "checkmark.circle.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(draft.title.trimmingCharacters(in: .whitespaces).isEmpty && draft.ingredients.isEmpty)
        }
        .controlSize(.large)
        .labelStyle(.titleAndIcon)
        .font(.subheadline.weight(.semibold))
        .padding()
        .background(.bar)
    }
}
