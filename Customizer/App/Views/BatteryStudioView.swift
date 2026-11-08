import SwiftUI

struct BatteryStudioView: View {
    @Environment(AppModel.self) private var model
    @State private var simulate = false
    @State private var simLevel = 0.15
    @State private var simCharging = false

    private var shownBattery: BatteryInfo {
        simulate ? BatteryInfo(level: simLevel, charging: simCharging, full: simLevel >= 0.999, isEstimate: true) : model.battery
    }

    var body: some View {
        ThemeScaffold(title: "Battery & Charging", previewHeight: 200) { theme in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(BatteryStyle.allCases) { style in
                        VStack(spacing: 8) {
                            BatteryGraphic(theme: theme, battery: shownBattery, size: 64, style: style)
                                .frame(width: 140, height: 120)
                                .background(ThemeBackground(spec: theme.background, photoMaxSide: 400))
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 22).stroke(style == theme.battery.style ? theme.accent.color : .clear, lineWidth: 2.5))
                            Text(style.label).font(.caption.weight(.semibold))
                        }
                    }
                }
                .padding(.vertical, 6)
            }
        } content: { $t in
            Section {
                HStack {
                    Image(systemName: model.battery.charging ? "bolt.fill" : "battery.75percent").foregroundStyle(.green)
                    Text(model.battery.isEstimate ? "Battery level unavailable (simulator)" : "Now: \(Int(model.battery.level * 100))%\(model.battery.charging ? " · Charging" : "")")
                }
                Toggle("Simulate Levels", isOn: $simulate.animation())
                if simulate {
                    SliderRow(title: "Level", value: $simLevel)
                    Toggle("Charging", isOn: $simCharging)
                }
            } header: { Text("Live") }
            Section("Style") {
                Picker("Style", selection: $t.battery.style) {
                    ForEach(BatteryStyle.allCases) { Text($0.label).tag($0) }
                }
                Toggle("Show Percentage", isOn: $t.battery.showPercent)
            }
            Section("Level Colours") {
                ColorRow(title: "Normal", value: $t.battery.normalColor)
                ColorRow(title: "Low", value: $t.battery.lowColor)
                ColorRow(title: "Charging", value: $t.battery.chargingColor)
                ColorRow(title: "Full", value: $t.battery.fullColor)
                SliderRow(title: "Low Below", value: $t.battery.lowThreshold, range: 0.05...0.5)
                TextField("Low battery message", text: $t.battery.lowMessage)
            }
            Section("Emoji Style") {
                TextField("Full", text: $t.battery.emojiFull)
                TextField("Low", text: $t.battery.emojiLow)
                TextField("Charging", text: $t.battery.emojiCharging)
            }
            Section {
                Picker("Animation", selection: $t.charging.style) {
                    ForEach(ChargingStyle.allCases) { Text($0.label).tag($0) }
                }
                TextField("Message", text: $t.charging.message)
                Toggle("Show Percentage", isOn: $t.charging.showPercent)
                if t.charging.style == .photo {
                    PhotoField(title: "Background Photo", imageID: $t.charging.photoID, maxSide: 2600)
                }
                Button { model.apply(t); model.showCharging = true } label: { Label("Preview Charging Screen", systemImage: "play.fill") }
            } header: {
                Text("Charging Screen")
            } footer: {
                Text("Make it appear automatically: Shortcuts → Automation → New → Charger → Is Connected → Run Immediately → add “Open Aura Charging Screen” (or “Show Aura Charging Island” to use the Dynamic Island without opening the app).")
            }
            Section {
                Label("Home Screen: Edit → Add Widget → Aura → “Aura Battery” (small or medium).", systemImage: "square.grid.2x2")
                Label("Lock Screen: long-press → Customize → Lock Screen → add “Aura Battery” (round, rectangular or above the clock).", systemImage: "lock")
                Label("Widgets refresh on iOS's schedule (about every 15 minutes, sooner when you open Aura).", systemImage: "clock.arrow.circlepath")
            } header: { Text("Battery Widgets") }
            Section {
                LimitNote(text: "Battery health (maximum capacity, cycle count) isn't available to apps — Apple keeps it private. You can see it in Settings → Battery → Battery Health & Charging.")
            }
        }
    }
}

/// Full-screen animated charging display, opened manually or by a Shortcuts automation.
struct ChargingScreen: View {
    @Environment(\.dismiss) private var dismiss
    let theme: Theme
    @State private var battery = BatteryInfo.current()
    @State private var appear = false

    var body: some View {
        ZStack {
            background
            TimelineView(.animation) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                animation(t)
            }
            VStack(spacing: 10) {
                Spacer()
                if theme.charging.showPercent {
                    Text("\(Int((battery.level * 100).rounded()))%")
                        .font(theme.font(size: 76, weightOverride: 8))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                Label(battery.charging || battery.isEstimate ? theme.charging.message : "Not charging", systemImage: "bolt.fill")
                    .font(theme.font(size: 18))
                    .foregroundStyle(theme.battery.chargingColor.color)
                Text("Tap to close").font(.caption).foregroundStyle(.white.opacity(0.4)).padding(.top, 30)
            }
            .foregroundStyle(theme.text.color)
            .padding(.bottom, 60)
            .opacity(appear ? 1 : 0)
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .contentShape(Rectangle())
        .onTapGesture { dismiss() }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            withAnimation(.easeOut(duration: 0.8)) { appear = true }
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.batteryLevelDidChangeNotification)) { _ in
            withAnimation { battery = BatteryInfo.current() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.batteryStateDidChangeNotification)) { _ in
            battery = BatteryInfo.current()
            if !battery.charging && !battery.full && !battery.isEstimate {
                // Unplugged: close shortly after.
                Task { try? await Task.sleep(for: .seconds(1.5)); dismiss() }
            }
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Charging, \(Int(battery.level * 100)) percent. Tap to close.")
    }

    @ViewBuilder private var background: some View {
        if theme.charging.style == .photo, let img = SharedStore.image(theme.charging.photoID) {
            Image(uiImage: img).resizable().scaledToFill().ignoresSafeArea()
                .overlay(Color.black.opacity(0.35))
        } else {
            Color.black.ignoresSafeArea()
        }
    }

    @ViewBuilder
    private func animation(_ t: TimeInterval) -> some View {
        let color = theme.battery.chargingColor.color
        let accent = theme.accent.color
        switch theme.charging.style {
        case .liquid, .photo:
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    WaveShape(phase: t * 2.2, amplitude: 14)
                        .fill(LinearGradient(colors: [color.opacity(0.5), accent.opacity(0.35)], startPoint: .top, endPoint: .bottom))
                        .frame(height: geo.size.height * max(0.08, battery.level))
                    WaveShape(phase: t * 1.6 + 1.5, amplitude: 18)
                        .fill(LinearGradient(colors: [color.opacity(0.8), color.opacity(0.5)], startPoint: .top, endPoint: .bottom))
                        .frame(height: geo.size.height * max(0.06, battery.level) - 10)
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .opacity(theme.charging.style == .photo ? 0.55 : 1)
        case .ring:
            ZStack {
                Circle().stroke(color.opacity(0.15), lineWidth: 18)
                Circle().trim(from: 0, to: battery.level)
                    .stroke(AngularGradient(colors: [color, accent, color], center: .center, angle: .degrees(t * 60)),
                            style: StrokeStyle(lineWidth: 18, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: color.opacity(0.8), radius: 20)
            }
            .frame(width: 260, height: 260)
            .offset(y: -120)
        case .neon:
            ZStack {
                ForEach(0..<4, id: \.self) { i in
                    let p = (t * 0.6 + Double(i) * 0.25).truncatingRemainder(dividingBy: 1)
                    Circle().stroke(i % 2 == 0 ? color : accent, lineWidth: 3)
                        .frame(width: 120 + 300 * p, height: 120 + 300 * p)
                        .opacity(1 - p)
                        .shadow(color: color, radius: 12)
                }
                Image(systemName: "bolt.fill").font(.system(size: 64, weight: .black)).foregroundStyle(color)
                    .shadow(color: color, radius: 20 + 10 * sin(t * 4))
            }
            .offset(y: -120)
        case .orbit:
            ZStack {
                ForEach(0..<12, id: \.self) { i in
                    let a = t * 1.4 + Double(i) * .pi / 6
                    Circle().fill(i % 3 == 0 ? accent : color)
                        .frame(width: 10, height: 10)
                        .offset(x: cos(a) * 120, y: sin(a) * 120)
                        .shadow(color: color, radius: 6)
                }
                BatteryGraphic(theme: theme, battery: battery, size: 110, style: .ring, showLabel: false)
            }
            .offset(y: -120)
        case .minimal:
            Capsule().fill(color)
                .frame(width: 220 * battery.level + 8, height: 6)
                .shadow(color: color, radius: 8 + 6 * sin(t * 2))
                .offset(y: -40)
        }
    }
}
