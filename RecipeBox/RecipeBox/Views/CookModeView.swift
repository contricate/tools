import SwiftUI

private struct RunningTimer: Identifiable, Equatable {
    let id = UUID()
    let label: String
    let end: Date
}

struct CookModeView: View {
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe
    let factor: Double

    @State private var page = 0
    @State private var timers: [RunningTimer] = []
    @State private var gathered: Set<Int> = []

    private var lastPage: Int { recipe.steps.count + 1 }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ProgressView(value: Double(page), total: Double(lastPage))
                    .tint(Color.accentColor)
                    .padding(.horizontal)
                    .padding(.top, 4)

                TabView(selection: $page) {
                    ingredientsPage.tag(0)
                    ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                        stepPage(index: index, text: step).tag(index + 1)
                    }
                    donePage.tag(lastPage)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: page)

                if !timers.isEmpty { timerBar }
                navButtons
            }
            .navigationTitle(recipe.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.title3) }
                        .foregroundStyle(.secondary)
                }
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: page)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            NotificationHelper.shared.requestPermission()
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    // MARK: Pages

    private var ingredientsPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Gather your ingredients")
                    .font(.title.bold())
                Text("Tap each one as you set it out.")
                    .foregroundStyle(.secondary)
                ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { index, item in
                    Button {
                        if gathered.contains(index) { gathered.remove(index) } else { gathered.insert(index) }
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: gathered.contains(index) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(gathered.contains(index) ? Color.accentColor : .secondary)
                            Text(IngredientScaler.scale(item, by: factor))
                                .font(.title3)
                                .strikethrough(gathered.contains(index))
                                .foregroundStyle(gathered.contains(index) ? .secondary : .primary)
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.selection, trigger: gathered.contains(index))
                }
            }
            .padding(24)
        }
    }

    private func stepPage(index: Int, text: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("STEP \(index + 1) OF \(recipe.steps.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.accentColor)
                    .tracking(1.2)
                Text(text)
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                let found = TimerDetector.find(in: text)
                if !found.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(found, id: \.self) { f in
                            Button {
                                startTimer(f, step: index + 1)
                            } label: {
                                Label("Start \(f.label) timer", systemImage: "timer")
                                    .font(.headline)
                                    .padding(.horizontal, 16).padding(.vertical, 12)
                                    .background(Color.accentColor.opacity(0.15), in: Capsule())
                            }
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var donePage: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "party.popper.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color.accentColor)
                .symbolEffect(.bounce, value: page == lastPage)
            Text("All done!").font(.largeTitle.bold())
            Text("Enjoy your \(recipe.title).")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                recipe.timesCooked += 1
                recipe.lastCooked = Date()
                dismiss()
            } label: {
                Label("I Made This!", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .frame(maxWidth: 280)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top)
            Spacer()
        }
        .padding()
    }

    // MARK: Controls

    private var timerBar: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(timers) { t in
                        let remaining = max(0, Int(t.end.timeIntervalSince(context.date).rounded(.up)))
                        HStack(spacing: 8) {
                            Image(systemName: remaining == 0 ? "bell.fill" : "timer")
                            VStack(alignment: .leading, spacing: 0) {
                                Text(remaining == 0 ? "Done!" : TimerDetector.format(seconds: remaining))
                                    .font(.headline.monospacedDigit())
                                Text(t.label).font(.caption2).lineLimit(1)
                            }
                            Button {
                                NotificationHelper.shared.cancel(id: t.id.uuidString)
                                timers.removeAll { $0.id == t.id }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(remaining == 0 ? Color.red.opacity(0.85) : Color.accentColor.opacity(0.9),
                                    in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
    }

    private var navButtons: some View {
        HStack(spacing: 12) {
            Button {
                page = max(0, page - 1)
            } label: {
                Label("Back", systemImage: "chevron.left")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(page == 0)

            Button {
                page = min(lastPage, page + 1)
            } label: {
                Label(page == 0 ? "Start" : "Next", systemImage: "chevron.right")
                    .labelStyle(TrailingIconLabelStyle())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(page == lastPage)
        }
        .controlSize(.large)
        .padding()
    }

    private func startTimer(_ f: TimerDetector.Found, step: Int) {
        let t = RunningTimer(label: "Step \(step): \(f.label)", end: Date().addingTimeInterval(TimeInterval(f.seconds)))
        timers.append(t)
        NotificationHelper.shared.schedule(id: t.id.uuidString,
                                           title: "⏰ Timer done",
                                           body: "\(recipe.title) — \(t.label)",
                                           after: f.seconds)
    }
}

struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.title
            configuration.icon
        }
    }
}
