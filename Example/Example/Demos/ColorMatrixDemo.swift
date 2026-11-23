//
// Copyright (c) Nathan Tannar
//

import SwiftUI
import Paint

/// Color matrix filters, applied to views and to colors.
struct ColorMatrixDemo: View {

    @Environment(\.self) private var environment
    @State private var image = SampleImage.greatWave
    @State private var saturation = 1.0
    @State private var hueRotation = 0.0
    @State private var brightness = 1.0
    @State private var contrast = 1.0
    @State private var grayscale = 0.0
    @State private var sepia = 0.0
    @State private var inversion = 0.0
    @State private var opacity = 1.0
    @State private var useTint = false
    @State private var tint = RGBAColor(red: 1, green: 0.6, blue: 0.2)
    @State private var strength = 1.0

    /// The filters concatenated with `*`, which applies the right matrix first.
    private var transform: ColorTransform {
        var transform = ColorTransform.opacity(opacity)
            * .inversion(inversion)
            * .sepia(sepia)
            * .grayscale(grayscale)
            * .contrast(contrast)
            * .brightness(brightness)
            * .hueRotation(.degrees(hueRotation))
            * .saturation(saturation)
        if useTint {
            transform = .tint(tint) * transform
        }
        return transform
    }

    /// Interpolated from the identity with `VectorArithmetic`, to fade the effect in.
    private var blended: ColorTransform {
        var difference = transform - .identity
        difference.scale(by: strength)
        return .identity + difference
    }

    var body: some View {
        DemoPage("Color Matrices") {
            DemoSection(
                "Image",
                caption: "ColorTransform filters match the CSS filter functions. toSwiftUI() converts to SwiftUI's color matrix, for the _colorMatrix(_:) modifier."
            ) {
                SampleImagePicker(selection: $image)
                HStack(alignment: .top, spacing: 8) {
                    SampleImageView(image: image)
                    SampleImageView(image: image)
                        ._colorMatrix(blended.toSwiftUI())
                }
                .frame(maxHeight: 320)
            }

            DemoSection("Filters") {
                LabeledSlider(".saturation", value: $saturation, in: 0...3)
                LabeledSlider(".hueRotation", value: $hueRotation, in: 0...360, digits: 0)
                LabeledSlider(".brightness", value: $brightness, in: 0...2)
                LabeledSlider(".contrast", value: $contrast, in: 0...2)
                LabeledSlider(".grayscale", value: $grayscale, in: 0...1)
                LabeledSlider(".sepia", value: $sepia, in: 0...1)
                LabeledSlider(".inversion", value: $inversion, in: 0...1)
                LabeledSlider(".opacity", value: $opacity, in: 0...1)
                Toggle(".tint", isOn: $useTint)
                if useTint {
                    ColorField("Tint", color: $tint)
                }
                Button("Reset") {
                    saturation = 1; hueRotation = 0; brightness = 1; contrast = 1
                    grayscale = 0; sepia = 0; inversion = 0; opacity = 1; useTint = false; strength = 1
                }
                .buttonStyle(.bordered)
            }

            DemoSection(
                "Strength",
                caption: "ColorTransform conforms to VectorArithmetic and Animatable, so it can be interpolated: identity + (transform − identity) × strength."
            ) {
                LabeledSlider("Strength", value: $strength, in: 0...1)
            }

            DemoSection(
                "Multiplying by a Color",
                caption: "toColorTransform() is a matrix that multiplies each component by a color, like colorMultiply(_:). Since it's a ColorTransform, it can be concatenated with other filters, or applied to colors. Color.toColorTransform(in:) resolves system colors, such as .accentColor, for the environment first. In each pair, the left is Paint and the right is colorMultiply(_:), so they should match."
            ) {
                ColorField("Color", color: $tint)
                HStack(alignment: .top, spacing: 8) {
                    multiplySample("toColorTransform()") {
                        SampleImageView(image: image)
                            ._colorMatrix(tint.toColorTransform().toSwiftUI())
                    }
                    multiplySample("colorMultiply(_:)") {
                        SampleImageView(image: image)
                            .colorMultiply(Color(tint))
                    }
                    multiplySample(".accentColor.toColorTransform(in:)") {
                        SampleImageView(image: image)
                            ._colorMatrix(Color.accentColor.toColorTransform(in: environment).toSwiftUI())
                    }
                    multiplySample("colorMultiply(.accentColor)") {
                        SampleImageView(image: image)
                            .colorMultiply(.accentColor)
                    }
                }
            }

            DemoSection("Applied to Colors", caption: "applying(_:) transforms a color with the same matrix.") {
                let colors = OKLCHColor.categorical(count: 8)
                SwatchRow(colors: colors)
                SwatchRow(colors: colors.map { $0.applying(blended) })
            }

            DemoSection("Matrix") {
                let m = blended
                Grid(alignment: .trailing, horizontalSpacing: 12, verticalSpacing: 4) {
                    matrixRow("R", m.r1, m.r2, m.r3, m.r4, m.r5)
                    matrixRow("G", m.g1, m.g2, m.g3, m.g4, m.g5)
                    matrixRow("B", m.b1, m.b2, m.b3, m.b4, m.b5)
                    matrixRow("A", m.a1, m.a2, m.a3, m.a4, m.a5)
                }
                .font(.callout.monospacedDigit())
            }
        }
    }

    private func multiplySample<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 4) {
            content()
                .frame(maxHeight: 140)
            Text(title)
                .font(.caption2.monospaced())
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func matrixRow(_ name: String, _ values: Float...) -> some View {
        GridRow {
            Text(name).foregroundStyle(.secondary)
            ForEach(values.indices, id: \.self) { index in
                Text(format(Double(values[index]), 3))
            }
        }
    }
}

#Preview {
    NavigationStack { ColorMatrixDemo() }
}
