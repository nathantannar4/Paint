//
// Copyright (c) Nathan Tannar
//

import SwiftUI
import Paint

/// Tonal scales, harmonies, data scales, generated colors, sorting and names.
struct PalettesDemo: View {

    @State private var seed = RGBAColor(red: 0.23, green: 0.51, blue: 0.96)
    @State private var gamut = ColorGamut.displayP3
    @State private var tone = 50.0
    @State private var count = 6.0
    @State private var name = "Ada Lovelace"
    @State private var randomColors: [OKLCHColor] = (0..<12).map { _ in OKLCHColor.random() }
    @State private var threshold = 0.05
    @State private var hueShift = 0.0
    @State private var scaleValue = 42.0
    @State private var divergingHigh = RGBAColor(red: 0.92, green: 0.35, blue: 0.05)
    @State private var sortOrder = SortOrder.stepped
    @State private var sortColors: [OKLCHColor] = (0..<32).map { _ in OKLCHColor.random(lightness: 0.3...0.9, chroma: 0...0.2) }

    enum SortOrder: String, CaseIterable {
        case hue, lightness, chroma, stepped

        var order: ColorSortOrder {
            switch self {
            case .hue: .hue
            case .lightness: .lightness
            case .chroma: .chroma
            case .stepped: .stepped
            }
        }
    }

    var body: some View {
        DemoPage("Palettes") {
            DemoSection("Seed") {
                ColorField("Seed", color: $seed)
                Picker("Gamut", selection: $gamut) {
                    ForEach(ColorGamut.all, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            DemoSection(
                "Tonal Scale",
                caption: "TonalScale generates the 50 to 950 steps of Tailwind CSS. Lightness is even across hues, so the same step of any hue has similar contrast. The seed's nearest step is outlined. hueShift turns light steps warmer and dark steps cooler, as painters shade."
            ) {
                let scale = TonalScale(seed: seed, hueShift: .degrees(hueShift), in: gamut)
                LabeledSlider("hueShift (°)", value: $hueShift, in: 0...30, digits: 0)
                HStack(spacing: 2) {
                    ForEach(TonalScale.steps, id: \.self) { step in
                        Swatch(scale[step], label: "\(step)", height: 64)
                            .overlay {
                                if step == scale.seedStep {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(Color.primary, lineWidth: 2)
                                }
                            }
                    }
                }
                LabeledSlider("color(tone:)", value: $tone, in: 0...100, digits: 0)
                Swatch(scale.color(tone: tone), label: "Tone \(Int(tone))", detail: "keeps the seed's chroma")
            }

            DemoSection("Harmonies", caption: "harmony(_:) rotates the hue in OKLCH, keeping lightness and chroma.") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(ColorHarmony.allCases, id: \.self) { harmony in
                        Text(String(title: harmony))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        SwatchRow(colors: seed.harmony(harmony, in: gamut), height: 36)
                    }
                }
            }

            DemoSection(
                "Data Scales",
                caption: "ColorScale maps numbers to colors, for heat maps and legends. sequential(_:domain:) goes from light to dark in the seed's hue. diverging(from:to:domain:midpoint:) goes through a light neutral at the midpoint, here 0 in -20...100. Lightness changes evenly, so the order stays clear in grayscale."
            ) {
                let sequential = ColorScale.sequential(seed, domain: 0...100, in: gamut)
                let diverging = ColorScale.diverging(from: seed, to: divergingHigh, domain: -20...100, midpoint: 0, in: gamut)
                LabeledSlider("Value", value: $scaleValue, in: -20...100, digits: 0)
                HStack(spacing: 4) {
                    Swatch(sequential(scaleValue), label: "sequential", detail: "\(Int(scaleValue))")
                    Swatch(diverging(scaleValue), label: "diverging", detail: "\(Int(scaleValue))")
                }
                Text("colors(count:)").font(.caption).foregroundStyle(.secondary)
                SwatchRow(colors: sequential.colors(count: 7), height: 32)
                ColorField("Diverging high", color: $divergingHigh)
                LinearGradient(gradient: diverging.gradient.toGradient(), startPoint: .leading, endPoint: .trailing)
                    .frame(height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                SwatchRow(colors: diverging.colors(count: 7), height: 32)
            }

            DemoSection(
                "Categorical",
                caption: "OKLCHColor.categorical(count:) spaces hues by the golden angle at equal lightness and chroma, so any number of colors stay distinct, as for chart series."
            ) {
                Stepper("Count: \(Int(count))", value: $count, in: 2...16)
                SwatchRow(colors: OKLCHColor.categorical(count: Int(count), in: gamut), height: 40)
            }

            DemoSection(
                "From a String",
                caption: "OKLCHColor(hashing:) is the same color for the same string on every device and launch, as for avatars."
            ) {
                TextField("Name", text: $name)
                    .textFieldStyle(.roundedBorder)
                HStack(spacing: 12) {
                    ForEach([name, "Grace Hopper", "Alan Turing", "Katherine Johnson"], id: \.self) { name in
                        let color = OKLCHColor(hashing: name)
                        VStack {
                            Text(initials(name))
                                .font(.headline)
                                .frame(width: 52, height: 52)
                                .background(Color(color), in: Circle())
                                .foregroundStyle(color.contrast(.apca).isDark ? .white : .black)
                            Text(name)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }

            DemoSection(
                "Random",
                caption: "OKLCHColor.random() within lightness and chroma ranges, then removingNearDuplicates(threshold:) drops colors within an Oklab distance of an earlier one, and nearest(to:) finds the closest to the seed."
            ) {
                Button("Shuffle") {
                    randomColors = (0..<12).map { _ in OKLCHColor.random() }
                }
                .buttonStyle(.bordered)
                SwatchRow(colors: randomColors, height: 36)
                LabeledSlider("Threshold", value: $threshold, in: 0...0.2)
                SwatchRow(colors: randomColors.removingNearDuplicates(threshold: threshold), height: 36)
                if let nearest = randomColors.nearest(to: seed) {
                    HStack(spacing: 4) {
                        Swatch(seed, label: "Seed")
                        Swatch(nearest, label: "nearest(to:)")
                    }
                }
            }

            DemoSection(
                "Sorting",
                caption: "sorted(by:) orders colors perceptually, in OKLCH. .stepped groups hues into slices and alternates light to dark and dark to light between them, which reads as smooth runs of color in a swatch grid. Grays come last."
            ) {
                HStack {
                    Picker("Order", selection: $sortOrder) {
                        ForEach(SortOrder.allCases, id: \.self) { Text(".\($0.rawValue)").tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Button("Shuffle") {
                        sortColors = (0..<32).map { _ in OKLCHColor.random(lightness: 0.3...0.9, chroma: 0...0.2) }
                    }
                    .buttonStyle(.bordered)
                }
                let sorted = sortColors.sorted(by: sortOrder.order)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 8), spacing: 2) {
                    ForEach(sorted.indices, id: \.self) { index in
                        Rectangle()
                            .fill(Color(sorted[index]))
                            .frame(height: 32)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            DemoSection(
                "Names",
                caption: "toDescriptiveName() describes a color in plain English, for VoiceOver labels and color pickers, and color.formatted(.name) writes it as a ColorFormatStyle. toNearestCSSNamedColor() finds the closest CSS name."
            ) {
                let colors = [seed.toOKLCHColor()] + randomColors.prefix(5)
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                    ForEach(colors.indices, id: \.self) { index in
                        let color = colors[index]
                        GridRow {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color(color))
                                .frame(width: 44, height: 28)
                            Text(color.formatted(.name))
                            Text(color.toNearestCSSNamedColor().rawValue)
                                .font(.callout.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    private func initials(_ name: String) -> String {
        name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined()
    }
}

#Preview {
    NavigationStack { PalettesDemo() }
}
