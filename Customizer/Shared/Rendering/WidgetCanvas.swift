import SwiftUI
import WidgetKit

/// The content of a home-screen widget design (background is supplied separately as the container background).
struct WidgetCanvas: View {
    let design: WidgetDesign
    let theme: Theme
    let family: WidgetFamily
    let battery: BatteryInfo
    let date: Date

    private var isSmall: Bool { family == .systemSmall }
    private var isLarge: Bool { family == .systemLarge || family == .systemExtraLarge }

    var body: some View {
        Group {
            switch design.layout {
            case .clock: clock
            case .battery: batteryLayout
            case .statusStrip: statusStrip
            case .photo: photo
            case .date: calendar
            case .quote: quote
            case .countdown: countdown
            case .launcher: launcher
            case .notifications: notifications
            case .combo: combo
            }
        }
        .foregroundStyle(theme.text.color)
    }

    // MARK: Layouts

    private var clock: some View {
        VStack(alignment: .leading) {
            Spacer(minLength: 0)
            ClockGraphic(theme: theme, date: date, size: isSmall ? 46 : 64)
            if !design.title.isEmpty {
                Text(design.title).font(theme.font(size: 13)).foregroundStyle(theme.secondaryText.color)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var batteryLayout: some View {
        Group {
            if isSmall {
                VStack(spacing: 6) {
                    BatteryGraphic(theme: theme, battery: battery, size: 74)
                    lowOrChargingCaption
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(spacing: 18) {
                    BatteryGraphic(theme: theme, battery: battery, size: isLarge ? 120 : 84)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(design.title.isEmpty ? "Battery" : design.title).font(theme.font(size: 15))
                            .foregroundStyle(theme.secondaryText.color)
                        Text("\(Int((battery.level * 100).rounded()))%").font(theme.font(size: 40, weightOverride: 8)).monospacedDigit()
                        lowOrChargingCaption
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    @ViewBuilder private var lowOrChargingCaption: some View {
        if battery.charging {
            Label("Charging", systemImage: "bolt.fill").font(theme.font(size: 12)).foregroundStyle(theme.battery.chargingColor.color)
        } else if battery.level <= theme.battery.lowThreshold {
            Text(theme.battery.lowMessage).font(theme.font(size: 12)).foregroundStyle(theme.battery.lowColor.color)
        }
    }

    private var statusStrip: some View {
        VStack(spacing: 10) {
            HStack {
                Text(date, format: .dateTime.hour().minute())
                    .font(theme.font(size: isSmall ? 15 : 17, weightOverride: 7))
                    .monospacedDigit()
                Spacer()
                Capsule().fill(Color.black)
                    .overlay(Image(systemName: design.symbol).font(.system(size: 10, weight: .bold)).foregroundStyle(theme.island.tint.color))
                    .frame(width: isSmall ? 46 : 70, height: 20)
                Spacer()
                BatteryGraphic(theme: theme, battery: battery, size: isSmall ? 26 : 32, style: .classic, showLabel: !isSmall)
            }
            if !isSmall {
                HStack {
                    Text(design.title.isEmpty ? date.formatted(.dateTime.weekday(.wide).day().month()) : design.title)
                        .font(theme.font(size: 22, weightOverride: 7))
                    Spacer()
                }
                if !design.subtitle.isEmpty {
                    HStack { Text(design.subtitle).font(theme.font(size: 13)).foregroundStyle(theme.secondaryText.color); Spacer() }
                }
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder private var photo: some View {
        let id = design.photoIDs.isEmpty ? nil : design.photoIDs[Int(date.timeIntervalSince1970 / 3600) % design.photoIDs.count]
        ZStack(alignment: .bottomLeading) {
            if let img = SharedStore.thumbnail(id, maxSide: isLarge ? 900 : 600) {
                Image(uiImage: img).resizable().scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity).clipped()
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "photo.badge.plus").font(.title)
                    Text("Add photos in Aura").font(.caption2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .foregroundStyle(theme.secondaryText.color)
            }
            if !design.title.isEmpty {
                Text(design.title)
                    .font(theme.font(size: 15, weightOverride: 7))
                    .foregroundStyle(.white)
                    .shadow(radius: 4)
                    .padding(12)
            }
        }
    }

    private var calendar: some View {
        let cal = Calendar.current
        return HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                Text(date.formatted(.dateTime.weekday(.wide)).uppercased())
                    .font(theme.font(size: 12, weightOverride: 7)).foregroundStyle(theme.accent.color).tracking(1)
                Text("\(cal.component(.day, from: date))").font(theme.font(size: isSmall ? 54 : 64, weightOverride: 3))
                Text(date.formatted(.dateTime.month(.wide).year())).font(theme.font(size: 13)).foregroundStyle(theme.secondaryText.color)
                Spacer(minLength: 0)
            }
            if !isSmall { MonthGrid(theme: theme, date: date) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var quote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "quote.opening").font(.system(size: 16, weight: .bold)).foregroundStyle(theme.accent.color)
            Text(design.title.isEmpty ? "Your words here" : design.title)
                .font(theme.font(size: isSmall ? 17 : 22))
                .minimumScaleFactor(0.5)
            if !design.subtitle.isEmpty {
                Text(design.subtitle).font(theme.font(size: 12)).foregroundStyle(theme.secondaryText.color)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var countdown: some View {
        let days = max(0, Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: date),
                                                          to: Calendar.current.startOfDay(for: design.countdownDate)).day ?? 0)
        return VStack(alignment: .leading, spacing: 2) {
            Image(systemName: design.symbol).font(.system(size: 18, weight: .semibold)).foregroundStyle(theme.accent.color)
            Spacer(minLength: 0)
            Text("\(days)").font(theme.font(size: isSmall ? 48 : 60, weightOverride: 8)).monospacedDigit()
            Text(days == 1 ? "day to go" : "days to go").font(theme.font(size: 12)).foregroundStyle(theme.secondaryText.color)
            Text(design.title.isEmpty ? design.countdownDate.formatted(date: .abbreviated, time: .omitted) : design.title)
                .font(theme.font(size: 14, weightOverride: 6)).lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var launcher: some View {
        let count = isSmall ? 4 : (isLarge ? 12 : 8)
        let columns = isSmall ? 2 : 4
        let links = Array(design.links.prefix(count))
        return VStack(alignment: .leading, spacing: 8) {
            if isLarge && !design.title.isEmpty { Text(design.title).font(theme.font(size: 15)) }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: columns), spacing: 10) {
                ForEach(links) { link in
                    Link(destination: LaunchURL.wrap(link.url)) {
                        VStack(spacing: 4) {
                            IconTile(spec: theme.icon, symbol: link.symbol, image: SharedStore.thumbnail(link.imageID, maxSide: 180), size: isSmall ? 46 : 50)
                            if !isSmall {
                                Text(link.title).font(theme.font(size: 10, weightOverride: 5)).lineLimit(1)
                            }
                        }
                    }
                }
            }
            if links.isEmpty {
                Text("Add apps to this launcher in Aura").font(.caption).foregroundStyle(theme.secondaryText.color)
            }
            Spacer(minLength: 0)
        }
    }

    private var notifications: some View {
        let items = Array(design.notifications.prefix(isSmall ? 1 : (isLarge ? 4 : 2)))
        return VStack(spacing: 8) {
            ForEach(items) { n in
                HStack(alignment: .top, spacing: 10) {
                    IconTile(spec: theme.icon, symbol: n.symbol, size: 30)
                    VStack(alignment: .leading, spacing: 1) {
                        HStack {
                            Text(n.app.uppercased()).font(theme.font(size: 10, weightOverride: 6)).foregroundStyle(theme.secondaryText.color)
                            Spacer()
                            Text(n.time).font(theme.font(size: 10)).foregroundStyle(theme.secondaryText.color)
                        }
                        Text(n.title).font(theme.font(size: 13, weightOverride: 7)).lineLimit(1)
                        Text(n.body).font(theme.font(size: 12, weightOverride: 4)).lineLimit(isSmall ? 3 : 2)
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.08 + theme.glass * 0.2)))
            }
            Spacer(minLength: 0)
        }
    }

    private var combo: some View {
        Group {
            if isSmall {
                VStack(alignment: .leading) {
                    ClockGraphic(theme: theme, date: date, size: 36, showDate: false)
                    Spacer(minLength: 0)
                    BatteryGraphic(theme: theme, battery: battery, size: 30, style: .bar)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            } else {
                HStack {
                    ClockGraphic(theme: theme, date: date, size: 52)
                    Spacer()
                    BatteryGraphic(theme: theme, battery: battery, size: 72)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

struct MonthGrid: View {
    let theme: Theme
    let date: Date

    var body: some View {
        let cal = Calendar.current
        let range = cal.range(of: .day, in: .month, for: date) ?? 1..<31
        let first = cal.date(from: cal.dateComponents([.year, .month], from: date)) ?? date
        let offset = (cal.component(.weekday, from: first) - cal.firstWeekday + 7) % 7
        let today = cal.component(.day, from: date)
        let cells: [Int?] = Array(repeating: nil, count: offset) + range.map { Optional($0) }
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 3) {
            ForEach(Array(cal.veryShortWeekdaySymbols.enumerated()), id: \.offset) { _, s in
                Text(s).font(.system(size: 8, weight: .bold)).foregroundStyle(theme.secondaryText.color)
            }
            ForEach(Array(cells.enumerated()), id: \.offset) { _, d in
                Text(d.map(String.init) ?? "")
                    .font(.system(size: 9, weight: d == today ? .heavy : .medium, design: .rounded))
                    .foregroundStyle(d == today ? theme.background.color.color : theme.text.color)
                    .frame(width: 15, height: 15)
                    .background(Circle().fill(d == today ? theme.accent.color : .clear))
            }
        }
    }
}

/// Widget taps go through Aura's own URL scheme, which then opens the target app.
enum LaunchURL {
    static func wrap(_ target: String) -> URL {
        if target.hasPrefix("aura://") { return URL(string: target) ?? URL(string: "aura://")! }
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let encoded = target.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
        return URL(string: "aura://launch?u=\(encoded)") ?? URL(string: "aura://")!
    }

    static func unwrap(_ url: URL) -> URL? {
        guard url.scheme == "aura", url.host == "launch",
              let u = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "u" })?.value else { return nil }
        return URL(string: u)
    }
}
