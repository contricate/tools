import SwiftUI

/// Shared spacing, shapes and small building blocks so every screen looks consistent.
enum DS {
    static let corner: CGFloat = 16
    static let smallCorner: CGFloat = 12
    static let pad: CGFloat = 16
}

struct CardBackground: ViewModifier {
    var padding: CGFloat = DS.pad
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: DS.corner, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
}

extension View {
    func card(padding: CGFloat = DS.pad) -> some View { modifier(CardBackground(padding: padding)) }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.title3.bold())
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.semibold))
            }
        }
    }
}

/// Small rounded label, e.g. "AI-generated" or "Estimated".
struct Badge: View {
    let text: String
    var icon: String? = nil
    var color: Color = .accentColor

    var body: some View {
        HStack(spacing: 4) {
            if let icon { Image(systemName: icon) }
            Text(text)
        }
        .font(.caption2.weight(.bold))
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(color.opacity(0.15), in: Capsule())
        .foregroundStyle(color)
    }
}

struct TagChip: View {
    let text: String
    var selected = false

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(selected ? Color.accentColor : Color(.tertiarySystemFill), in: Capsule())
            .foregroundStyle(selected ? Color.white : Color.primary)
    }
}

/// Big tappable tile used for quick actions on the dashboard.
struct ActionTile: View {
    let title: String
    let subtitle: String
    let icon: String
    var color: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(color.gradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .card(padding: 14)
    }
}

/// Wraps tags/chips onto multiple lines.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > width, x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
        return CGSize(width: width, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
    }
}

/// Shimmering placeholder used while content loads.
struct SkeletonCard: View {
    @State private var phase = false
    var height: CGFloat = 180

    var body: some View {
        RoundedRectangle(cornerRadius: DS.corner, style: .continuous)
            .fill(Color(.tertiarySystemFill))
            .frame(height: height)
            .opacity(phase ? 0.45 : 1)
            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: phase)
            .onAppear { phase = true }
    }
}

// MARK: - Global toast with optional Undo

@Observable
final class ToastCenter {
    enum Style { case success, info, error }

    struct Toast: Identifiable {
        let id = UUID()
        var message: String
        var style: Style
        var actionTitle: String?
        var action: (() -> Void)?
    }

    var current: Toast?

    func show(_ message: String, style: Style = .success, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        withAnimation(.spring(duration: 0.35)) {
            current = Toast(message: message, style: style, actionTitle: actionTitle, action: action)
        }
    }

    func dismiss(_ id: UUID) {
        guard current?.id == id else { return }
        withAnimation(.spring(duration: 0.35)) { current = nil }
    }
}

struct ToastHost: ViewModifier {
    @Environment(ToastCenter.self) private var center

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let toast = center.current {
                ToastBanner(message: toast.message, style: toast.style, actionTitle: toast.actionTitle) {
                    toast.action?()
                    center.dismiss(toast.id)
                }
                .padding(.top, 8)
                .padding(.horizontal)
                .transition(.move(edge: .top).combined(with: .opacity))
                .task(id: toast.id) {
                    try? await Task.sleep(for: .seconds(toast.actionTitle == nil ? 2.4 : 5))
                    center.dismiss(toast.id)
                }
                .zIndex(1)
            }
        }
    }
}

struct ToastBanner: View {
    let message: String
    var style: ToastCenter.Style = .success
    var actionTitle: String? = nil
    var action: () -> Void = {}

    private var icon: String {
        switch style {
        case .success: return "checkmark.circle.fill"
        case .info: return "info.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    private var color: Color {
        switch style {
        case .success: return .green
        case .info: return .accentColor
        case .error: return .red
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(color)
            Text(message).font(.subheadline.weight(.medium)).lineLimit(2)
            if let actionTitle {
                Spacer(minLength: 8)
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.bold))
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        .sensoryFeedback(style == .error ? .error : .success, trigger: message)
    }
}

extension View {
    func toastHost() -> some View { modifier(ToastHost()) }
}
