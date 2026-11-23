//
// Copyright (c) Nathan Tannar
//

import SwiftUI
import Paint

/// Perceptual adjustments in OKLCH, mixing and prominence.
struct AdjustmentsDemo: View {

    @State private var color = RGBAColor(red: 0.2, green: 0.5, blue: 0.95)
    @State private var mixColor = RGBAColor(red: 1, green: 0.8, blue: 0.2)
    @State private var background = RGBAColor(red: 1, green: 1, blue: 1)
    @State private var amount = 0.1
    @State private var rotation = 60.0
    @State private var fraction = 0.5
    @State private var gamut = ColorGamut.displayP3

    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 8)]

    var body: some View {
        DemoPage("Adjustments") {
            DemoSection(
                "Color",
                caption: "Adjustments are made in OKLCH, so lightening keeps the hue and how colorful the color looks. Results are fitted to the gamut."
            ) {
                ColorField("Color", color: $color)
                Picker("Gamut", selection: $gamut) {
                    ForEach(ColorGamut.all, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                LabeledSlider("Amount", value: $amount, in: 0...0.3)
                LabeledSlider("Hue rotation", value: $rotation, in: 0...360, digits: 0)
            }

            DemoSection("Lightness, Chroma and Hue") {
                LazyVGrid(columns: columns, spacing: 8) {
                    Swatch(color, label: "Original", height: 64)
                    Swatch(color.lightened(by: amount, in: gamut), label: "lightened(by:)", height: 64)
                    Swatch(color.darkened(by: amount, in: gamut), label: "darkened(by:)", height: 64)
                    Swatch(color.saturated(by: amount / 2, in: gamut), label: "saturated(by:)", height: 64)
                    Swatch(color.desaturated(by: amount / 2, in: gamut), label: "desaturated(by:)", height: 64)
                    Swatch(color.hueRotated(by: .degrees(rotation), in: gamut), label: "hueRotated(by:)", height: 64)
                    Swatch(color.complement(in: gamut), label: "complement()", height: 64)
                    Swatch(color.grayscale(), label: "grayscale()", height: 64)
                    Swatch(color.inverted(), label: "inverted()", height: 64)
                }
            }

            DemoSection(
                "Mixing",
                caption: "mixed(with:by:) mixes in OKLCH. interpolated(to:by:in:) mixes in any ColorInterpolationSpace."
            ) {
                ColorField("Mix with", color: $mixColor)
                LabeledSlider("Fraction", value: $fraction, in: 0...1)
                LazyVGrid(columns: columns, spacing: 8) {
                    Swatch(color.mixed(with: mixColor, by: fraction), label: "mixed(with:by:)", height: 64)
                    ForEach(ColorInterpolationSpace.allCases, id: \.self) { space in
                        Swatch(color.interpolated(to: mixColor, by: fraction, in: space), label: "in .\(space.rawValue)", height: 64)
                    }
                }
            }

            DemoSection(
                "Prominence",
                caption: "withProminence(_:) lowers alpha like UIColor. withProminence(_:against:) mixes towards an opaque background instead. disabled(against:) dims a control's color."
            ) {
                ColorField("Background", color: $background)
                VStack(spacing: 8) {
                    HStack(spacing: 4) {
                        ForEach(ColorProminence.allCases, id: \.self) { prominence in
                            Swatch(color.withProminence(prominence).composited(over: background), label: prominence.rawValue)
                        }
                    }
                    HStack(spacing: 4) {
                        ForEach(ColorProminence.allCases, id: \.self) { prominence in
                            Swatch(color.withProminence(prominence, against: background), label: "against:")
                        }
                    }
                }
                .padding(8)
                .background(Color(background), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                HStack(spacing: 12) {
                    Text("Enabled")
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Color(color), in: Capsule())
                        .foregroundStyle(color.contrast(.apca).isDark ? .white : .black)
                    Text("disabled(against:)")
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Color(color.disabled(against: background)), in: Capsule())
                        .foregroundStyle(color.disabled(against: background).contrast(.apca).isDark ? .white : .black)
                }
                .font(.callout.weight(.semibold))
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(Color(background), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
}

#Preview {
    NavigationStack { AdjustmentsDemo() }
}
