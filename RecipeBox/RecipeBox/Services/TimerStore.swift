import SwiftUI

/// Cooking timers shared across the whole app, so they keep running when you leave Cook Mode.
@Observable
final class TimerStore {
    struct CookTimer: Identifiable, Equatable {
        let id = UUID()
        let label: String
        let recipeTitle: String
        let total: Int
        let end: Date
        var remaining: Int { max(0, Int(end.timeIntervalSinceNow.rounded(.up))) }
        var isDone: Bool { Date() >= end }
    }

    var timers: [CookTimer] = []

    func start(label: String, recipeTitle: String, seconds: Int) {
        let t = CookTimer(label: label, recipeTitle: recipeTitle, total: seconds,
                          end: Date().addingTimeInterval(TimeInterval(seconds)))
        timers.append(t)
        if UserDefaults.standard.bool(forKey: SettingsKey.timerAlerts) {
            NotificationHelper.shared.requestPermission()
            NotificationHelper.shared.schedule(id: t.id.uuidString, title: "⏰ Timer done",
                                               body: "\(recipeTitle) — \(label)", after: seconds)
        }
    }

    func cancel(_ t: CookTimer) {
        NotificationHelper.shared.cancel(id: t.id.uuidString)
        timers.removeAll { $0.id == t.id }
    }

    func addMinute(_ t: CookTimer) {
        guard let i = timers.firstIndex(of: t) else { return }
        NotificationHelper.shared.cancel(id: t.id.uuidString)
        let base = max(Date(), t.end)
        let new = CookTimer(label: t.label, recipeTitle: t.recipeTitle, total: t.total + 60, end: base.addingTimeInterval(60))
        timers[i] = new
        if UserDefaults.standard.bool(forKey: SettingsKey.timerAlerts) {
            NotificationHelper.shared.schedule(id: new.id.uuidString, title: "⏰ Timer done",
                                               body: "\(new.recipeTitle) — \(new.label)",
                                               after: Int(new.end.timeIntervalSinceNow))
        }
    }
}

/// Row of running timers. Used in Cook Mode and floating over the rest of the app.
struct TimerStrip: View {
    @Environment(TimerStore.self) private var store

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { _ in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(store.timers) { t in
                        TimerChip(timer: t)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct TimerChip: View {
    @Environment(TimerStore.self) private var store
    let timer: TimerStore.CookTimer

    var body: some View {
        let done = timer.isDone
        HStack(spacing: 10) {
            ZStack {
                Circle().stroke(.white.opacity(0.3), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: timer.total > 0 ? CGFloat(timer.remaining) / CGFloat(timer.total) : 0)
                    .stroke(.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: done ? "bell.fill" : "timer").font(.caption2.bold())
                    .symbolEffect(.bounce, options: .repeating, isActive: done)
            }
            .frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 0) {
                Text(done ? "Done!" : TimerDetector.format(seconds: timer.remaining))
                    .font(.headline.monospacedDigit())
                Text(timer.label).font(.caption2).lineLimit(1).opacity(0.9)
            }
            Menu {
                Button("Add 1 Minute", systemImage: "plus") { store.addMinute(timer) }
                Button(done ? "Dismiss" : "Cancel Timer", systemImage: "xmark", role: .destructive) { store.cancel(timer) }
            } label: {
                Image(systemName: "ellipsis.circle.fill").font(.title3)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background((done ? Color.red : Color.accentColor).gradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .foregroundStyle(.white)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(timer.label), \(done ? "done" : "\(timer.remaining) seconds left")")
    }
}

struct FloatingTimers: View {
    var body: some View {
        TimerStrip()
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.horizontal, 12)
            .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
    }
}
