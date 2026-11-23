//
// Copyright (c) Nathan Tannar
//

import SwiftUI
import Paint

/// Every color model, conversions between them, gamuts and color difference.
struct ModelsDemo: View {

    @State private var color = RGBAColor(red: 0.95, green: 0.45, blue: 0.2)
    @State private var other = RGBAColor(red: 0.9, green: 0.5, blue: 0.25)
    @State private var colorSpace = ColorSpace.displayP3
    @State private var components = SIMD3<Double>(1, 0.4, 0)

    var body: some View {
        DemoPage("Color Models") {
            DemoSection(
                "Color",
                caption: "Every model conforms to ColorConvertible, so any color converts to any other. Pick a color, or a preset outside sRGB."
            ) {
                ColorField("Color", color: $color, supportsOpacity: true)
                Swatch(color, label: color.toCSSColor(.oklch).rawValue, height: 88)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        Button("sRGB Orange") { color = RGBAColor(red: 0.95, green: 0.45, blue: 0.2) }
                        Button("P3 Green") { color = CSSColor(decoding: "color(display-p3 0 1 0)")!.toRGBAColor() }
                        Button("Rec. 2020 Cyan") { color = CSSColor(decoding: "color(rec2020 0 1 1)")!.toRGBAColor() }
                    }
                    .buttonStyle(.bordered)
                }
            }

            DemoSection("Conversions", caption: "toHEXColor(), toHSBAColor(), toOKLCHColor() and the other conversions.") {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                    let hsba = color.toHSBAColor()
                    let hsla = color.toHSLAColor()
                    let hwb = color.toHWBColor()
                    let cmyk = color.toCMYKColor()
                    let oklch = color.toOKLCHColor()
                    let oklab = color.toOKLabColor()
                    let lab = color.toCIELabColor()
                    let lch = color.toCIELCHColor()
                    let xyz = color.toXYZColor()
                    ValueRow("HEXColor", color.toHEXColor().toString(includePrefix: true))
                    ValueRow("RGBAColor", format(color.red, color.green, color.blue, color.alpha))
                    ValueRow("HSBAColor", format(hsba.hue.degrees, hsba.saturation, hsba.brightness))
                    ValueRow("HSLAColor", format(hsla.hue.degrees, hsla.saturation, hsla.lightness))
                    ValueRow("HWBColor", format(hwb.hue.degrees, hwb.whiteness, hwb.blackness))
                    ValueRow("CMYKColor", format(cmyk.cyan, cmyk.magenta, cmyk.yellow, cmyk.black))
                    ValueRow("OKLCHColor", format(oklch.lightness, oklch.chroma, oklch.hue.degrees))
                    ValueRow("OKLabColor", format(oklab.lightness, oklab.a, oklab.b))
                    ValueRow("CIELabColor", format(lab.lightness, lab.a, lab.b, digits: 2))
                    ValueRow("CIELCHColor", format(lch.lightness, lch.chroma, lch.hue.degrees, digits: 2))
                    ValueRow("XYZColor", format(xyz.x, xyz.y, xyz.z))
                }
            }

            DemoSection(
                "Gamut",
                caption: "ColorGamut.contains(_:) and toColorGamut(_:), which reduces OKLCH chroma to fit, keeping lightness and hue."
            ) {
                HStack(spacing: 8) {
                    ForEach(ColorGamut.all, id: \.self) { gamut in
                        VStack(spacing: 6) {
                            Swatch(color.toRGBAColor().toColorGamut(gamut), label: gamut.title)
                            Badge(title: gamut.contains(color) ? "Inside" : "Fitted", passes: gamut.contains(color))
                        }
                    }
                }
            }

            DemoSection("Analysis") {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                    ValueRow("contrast(.wcag).luminance", format(color.contrast(.wcag).luminance))
                    ValueRow("contrast(.apca).luminance", format(color.contrast(.apca).luminance))
                    ValueRow("isDark (APCA / WCAG)", "\(color.contrast(.apca).isDark) / \(color.contrast(.wcag).isDark)")
                    ValueRow("isNearWhite", "\(color.isNearWhite)")
                    ValueRow("toChromaticity()", color.toXYZColor().toChromaticity().map { format($0.x, $0.y, digits: 4) } ?? "—")
                    ValueRow("toCorrelatedColorTemperatureString()", color.toCorrelatedColorTemperatureString() ?? "—")
                    ValueRow("contentHeadroom", format(color.contentHeadroom))
                }
            }

            DemoSection(
                "Components in a Color Space",
                caption: "RGBAColor(red:green:blue:colorSpace:) converts components in a ColorSpace, such as Display P3 or linear sRGB, to extended sRGB at Double precision, without ColorSync."
            ) {
                Picker("Color space", selection: $colorSpace) {
                    ForEach(ColorSpace.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                LabeledSlider("Red", value: $components.x, in: 0...1)
                LabeledSlider("Green", value: $components.y, in: 0...1)
                LabeledSlider("Blue", value: $components.z, in: 0...1)
                let converted = RGBAColor(red: components.x, green: components.y, blue: components.z, colorSpace: colorSpace)
                HStack(spacing: 4) {
                    Swatch(converted, label: "In \(colorSpace.rawValue)", height: 72)
                    Swatch(converted.toColorGamut(.sRGB), label: "Fitted to sRGB", height: 72)
                }
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                    ValueRow("isLinear", "\(colorSpace.isLinear)")
                    ValueRow("toGammaEncodedColorSpace()", colorSpace.toGammaEncodedColorSpace().rawValue)
                    ValueRow("In sRGB", "\(ColorGamut.sRGB.contains(converted))")
                }
                Button("Use as the color above") { color = converted }
                    .buttonStyle(.bordered)
            }

            DemoSection(
                "Difference",
                caption: "distance(to:) is the Oklab distance, deltaE2000(to:) is CIEDE2000, and isApproximatelyEqual(to:) compares with a perceptual tolerance."
            ) {
                ColorField("Other", color: $other)
                HStack(spacing: 4) {
                    Swatch(color)
                    Swatch(other)
                }
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                    ValueRow("distance(to:)", format(color.distance(to: other), 4))
                    ValueRow("deltaE2000(to:)", format(color.deltaE2000(to: other), 2))
                    ValueRow("isApproximatelyEqual(to:)", "\(color.isApproximatelyEqual(to: other))")
                }
            }

            DemoSection(
                "Codable",
                caption: "Every model is Codable. HEXColor encodes as a \"RRGGBB\" string, CSSColor as its CSS string, and the others as their components. HEX colors are 8-bit sRGB, so colors outside sRGB don't round trip; toCSSColor() writes them as oklch() so they do."
            ) {
                let samples = [
                    encoded("HEXColor", color.toHEXColor()),
                    encoded("CSSColor(.hsl)", color.toCSSColor(.hsl)),
                    encoded("CSSColor", color.toCSSColor()),
                    encoded("RGBAColor", color),
                    encoded("OKLCHColor", color.toOKLCHColor()),
                ]
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(samples, id: \.name) { sample in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(sample.name)
                                    .font(.callout.weight(.medium))
                                Spacer()
                                Badge(title: sample.roundTrips ? "Round trips" : "Approximate", passes: sample.roundTrips)
                            }
                            Text(sample.json)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    /// A color encoded as JSON, and whether it decodes back to the same color.
    private func encoded<C: ColorConvertible & Codable>(
        _ name: String,
        _ value: C
    ) -> (name: String, json: String, roundTrips: Bool) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard
            let data = try? encoder.encode(value),
            let decoded = try? JSONDecoder().decode(C.self, from: data)
        else {
            return (name, "Failed to encode", false)
        }
        let json = String(decoding: data, as: UTF8.self)
        return (name, json, decoded.isApproximatelyEqual(to: color))
    }
}

#Preview {
    NavigationStack { ModelsDemo() }
}
