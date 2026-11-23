//
// Copyright (c) Nathan Tannar
//

import SwiftUI
import Paint

/// Tonal scales, harmonies and generated colors.
struct PalettesDemo: View {

    @State private var seed = RGBAColor(red: 0.23, green: 0.51, blue: 0.96)
    @State private var gamut = ColorGamut.displayP3
    @State private var tone = 50.0
    @State private var count = 6.0
    @State private var name = "Ada Lovelace"
    @State private var randomColors: [OKLCHColor] = (0..<12).map { _ in OKLCHColor.random() }
    @State private var threshold = 0.05

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
                caption: "TonalScale generates the 50 to 950 steps of Tailwind CSS. Lightness is even across hues, so the same step of any hue has similar contrast. The seed's nearest step is outlined."
            ) {
                let scale = TonalScale(seed: seed, in: gamut)
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
        }
    }

    private func initials(_ name: String) -> String {
        name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined()
    }
}

#Preview {
    NavigationStack { PalettesDemo() }
}
