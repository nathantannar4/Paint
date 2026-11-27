//
// Copyright (c) Nathan Tannar
//

import SwiftUI
import Paint

/// Simulating and daltonizing for color vision deficiencies.
struct VisionDemo: View {

    @State private var severity = 1.0
    @State private var deficiency = ColorVisionDeficiency.deuteranopia
    @State private var image = SampleImage.sunflowers
    @State private var daltonize = false
    @State private var threshold = 0.06

    /// The Okabe-Ito palette, designed to be distinguishable with color blindness.
    private static let okabeIto: [RGBAColor] = [
        HEXColor("#E69F00").toRGBAColor(),
        HEXColor("#56B4E9").toRGBAColor(),
        HEXColor("#009E73").toRGBAColor(),
        HEXColor("#0072B2").toRGBAColor(),
        HEXColor("#D55E00").toRGBAColor(),
        HEXColor("#CC79A7").toRGBAColor(),
    ]

    /// A chart palette with a red and green pair that's hard to tell apart.
    private let palette: [RGBAColor] = [
        HEXColor("#D62728").toRGBAColor(),
        HEXColor("#2CA02C").toRGBAColor(),
        HEXColor("#1F77B4").toRGBAColor(),
        HEXColor("#FF7F0E").toRGBAColor(),
        HEXColor("#9467BD").toRGBAColor(),
        HEXColor("#8C564B").toRGBAColor(),
    ]

    var body: some View {
        DemoPage("Color Vision") {
            DemoSection(
                "Simulation",
                caption: "simulating(_:severity:) shows how colors appear with a ColorVisionDeficiency. Severities below 1 are the anomalous trichromacies, such as deuteranomaly."
            ) {
                LabeledSlider("Severity", value: $severity, in: 0...1)
                Toggle("Daltonize first, with daltonized(for:severity:)", isOn: $daltonize)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Normal vision").font(.caption).foregroundStyle(.secondary)
                    SwatchRow(colors: palette)
                    ForEach(ColorVisionDeficiency.allCases, id: \.self) { deficiency in
                        Text(String(title: deficiency)).font(.caption).foregroundStyle(.secondary)
                        SwatchRow(colors: palette.map { color in
                            let source = daltonize ? color.daltonized(for: deficiency, severity: severity) : color
                            return source.simulating(deficiency, severity: severity)
                        })
                    }
                }
            }

            DemoSection(
                "Telling Colors Apart",
                caption: "The CIEDE2000 difference, deltaE2000(to:), between the red and green of the palette as each deficiency sees them. Below about 10, they're easily confused."
            ) {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                    GridRow {
                        Text("")
                        Text("Simulated").font(.caption).foregroundStyle(.secondary)
                        Text("Daltonized").font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(ColorVisionDeficiency.allCases, id: \.self) { deficiency in
                        let red = palette[0], green = palette[1]
                        let simulated = red.simulating(deficiency, severity: severity)
                            .deltaE2000(to: green.simulating(deficiency, severity: severity))
                        let daltonized = red.daltonized(for: deficiency, severity: severity).simulating(deficiency, severity: severity)
                            .deltaE2000(to: green.daltonized(for: deficiency, severity: severity).simulating(deficiency, severity: severity))
                        GridRow {
                            Text(String(title: deficiency))
                            Text(format(simulated, 1)).monospacedDigit()
                            Text(format(daltonized, 1)).monospacedDigit()
                        }
                    }
                }
            }

            DemoSection(
                "Checking a Palette",
                caption: "minimumDistance(simulating:) is the smallest Oklab difference between any two colors as a deficiency sees them, and isDistinguishable(threshold:for:) checks normal vision and the dichromacies at once. This palette fails with red-green deficiencies; the Okabe-Ito palette, designed for color blindness, passes."
            ) {
                LabeledSlider("Threshold", value: $threshold, in: 0.02...0.12)
                ForEach([("Chart palette", palette), ("Okabe-Ito", Self.okabeIto)], id: \.0) { name, colors in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(name).font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Badge(title: "isDistinguishable", passes: colors.isDistinguishable(threshold: threshold))
                        }
                        SwatchRow(colors: colors, height: 32)
                        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                            ValueRow("Normal", format(colors.minimumDistance()))
                            ForEach(ColorVisionDeficiency.allCases, id: \.self) { deficiency in
                                ValueRow(String(title: deficiency), format(colors.minimumDistance(simulating: deficiency, severity: severity)))
                            }
                        }
                    }
                }
            }

            DemoSection(
                "Previewing Views",
                caption: "ColorTransform.simulating(_:severity:) and .daltonizing(for:severity:) are color matrices, applied to any view with _colorMatrix(_:)."
            ) {
                Picker("Deficiency", selection: $deficiency) {
                    ForEach(ColorVisionDeficiency.allCases, id: \.self) { Text(String(title: $0)).tag($0) }
                }
                SampleImagePicker(selection: $image)
                let transform = daltonize
                    ? ColorTransform.simulating(deficiency, severity: severity) * .daltonizing(for: deficiency, severity: severity)
                    : ColorTransform.simulating(deficiency, severity: severity)
                HStack(alignment: .top, spacing: 8) {
                    VStack {
                        SampleImageView(image: image)
                        Text("Normal").font(.caption)
                    }
                    VStack {
                        SampleImageView(image: image)
                            ._colorMatrix(transform.toSwiftUI())
                        Text(String(title: deficiency)).font(.caption)
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack { VisionDemo() }
}
