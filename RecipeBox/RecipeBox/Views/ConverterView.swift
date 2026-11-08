import SwiftUI

/// Kitchen measurement converter: weight, volume, temperature, and cups ↔ grams for common ingredients.
struct ConverterView: View {
    @Environment(\.dismiss) private var dismiss
    enum Mode: String, CaseIterable, Identifiable { case weight = "Weight", volume = "Volume", temperature = "Temp", ingredient = "Cups ↔ g"; var id: String { rawValue } }

    @State private var mode: Mode = .weight
    @State private var input = "1"
    @State private var fromUnit: CookUnit = .cup
    @State private var tempIsF = true
    @State private var ingredient = "flour"

    private var value: Double { Double(input.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private let weightUnits: [CookUnit] = [.g, .kg, .oz, .lb]
    private let volumeUnits: [CookUnit] = [.ml, .l, .tsp, .tbsp, .cup, .floz, .pint, .quart]
    private var ingredientChoices: [String] {
        NutritionEstimator.foods.filter { $0.gPerCup != nil }.compactMap { $0.keys.first }.sorted()
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Type", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .onChange(of: mode) { _, m in
                    fromUnit = m == .weight ? .g : .cup
                }

                Section("Amount") {
                    HStack {
                        TextField("Amount", text: $input)
                            .keyboardType(.decimalPad)
                            .font(.title2.bold().monospacedDigit())
                        switch mode {
                        case .weight:
                            unitPicker(weightUnits)
                        case .volume:
                            unitPicker(volumeUnits)
                        case .temperature:
                            Picker("", selection: $tempIsF) { Text("°F").tag(true); Text("°C").tag(false) }
                                .pickerStyle(.segmented).frame(width: 110)
                        case .ingredient:
                            unitPicker([.cup, .tbsp, .tsp, .g, .oz])
                        }
                    }
                    if mode == .ingredient {
                        Picker("Ingredient", selection: $ingredient) {
                            ForEach(ingredientChoices, id: \.self) { Text($0.capitalized).tag($0) }
                        }
                    }
                }

                Section("Equals") { results }

                Section {
                    quickRef("1 cup", "240 ml · 16 tbsp")
                    quickRef("1 tbsp", "3 tsp · 15 ml")
                    quickRef("1 oz", "28 g")
                    quickRef("1 lb", "454 g · 16 oz")
                    quickRef("350°F / 175°C", "Moderate oven (gas 4)")
                    quickRef("400°F / 200°C", "Hot oven (gas 6)")
                } header: {
                    Text("Quick Reference")
                } footer: {
                    Text("Cup ↔ gram conversions depend on the ingredient and how it's packed; values are typical averages.")
                }
            }
            .navigationTitle("Converter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.large])
    }

    private func unitPicker(_ units: [CookUnit]) -> some View {
        Picker("", selection: $fromUnit) {
            ForEach(units, id: \.self) { Text($0.symbol(plural: false)).tag($0) }
        }
        .pickerStyle(.menu)
        .onAppear { if !units.contains(fromUnit) { fromUnit = units[0] } }
    }

    @ViewBuilder private var results: some View {
        switch mode {
        case .weight:
            let g = value * fromUnit.factor
            ForEach(weightUnits.filter { $0 != fromUnit }, id: \.self) { u in
                resultRow(UnitConverter.format(g / u.factor, unit: u), u.symbol(plural: true))
            }
        case .volume:
            let ml = value * fromUnit.factor
            ForEach(volumeUnits.filter { $0 != fromUnit }, id: \.self) { u in
                resultRow(UnitConverter.format(ml / u.factor, unit: u), u.symbol(plural: ml / u.factor > 1))
            }
        case .temperature:
            let out = tempIsF ? UnitConverter.fToC(value) : UnitConverter.cToF(value)
            resultRow(String(Int(out.rounded())), tempIsF ? "°C" : "°F")
            if tempIsF, let mark = gasMark(fahrenheit: value) { resultRow(mark, "gas mark") }
        case .ingredient:
            if let food = NutritionEstimator.food(for: ingredient), let cupG = food.gPerCup {
                if fromUnit.dimension == .volume {
                    let grams = value * fromUnit.factor / CookUnit.cup.factor * cupG
                    resultRow(UnitConverter.format(grams, unit: .g), "g")
                    resultRow(UnitConverter.format(grams / CookUnit.oz.factor, unit: .oz), "oz")
                } else {
                    let cups = value * fromUnit.factor / cupG
                    resultRow(IngredientScaler.format(cups), cups > 1 ? "cups" : "cup")
                    resultRow(IngredientScaler.format(cups * 16), "tbsp")
                }
            }
        }
    }

    private func resultRow(_ v: String, _ unit: String) -> some View {
        HStack {
            Text(v).font(.title3.bold().monospacedDigit())
            Text(unit).foregroundStyle(.secondary)
            Spacer()
        }
        .textSelection(.enabled)
    }

    private func quickRef(_ a: String, _ b: String) -> some View {
        HStack { Text(a).bold(); Spacer(); Text(b).foregroundStyle(.secondary) }.font(.subheadline)
    }

    private func gasMark(fahrenheit f: Double) -> String? {
        let marks: [(Double, String)] = [(275, "1"), (300, "2"), (325, "3"), (350, "4"), (375, "5"), (400, "6"), (425, "7"), (450, "8"), (475, "9")]
        guard f >= 260 && f <= 490 else { return nil }
        return marks.min { abs($0.0 - f) < abs($1.0 - f) }?.1
    }
}
