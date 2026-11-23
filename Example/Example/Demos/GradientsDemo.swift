//
// Copyright (c) Nathan Tannar
//

import SwiftUI
import Paint

/// Gradients interpolated in perceptual color spaces, drawn by SwiftUI, Core Animation
/// and Core Graphics.
struct GradientsDemo: View {

    @State private var start = RGBAColor(red: 0, green: 0.2, blue: 1)
    @State private var end = RGBAColor(red: 1, green: 0.9, blue: 0)
    @State private var addMiddle = false
    @State private var middle = RGBAColor(red: 1, green: 0.2, blue: 0.4)
    @State private var space = ColorInterpolationSpace.oklch
    @State private var hue = HueInterpolation.shorter
    @State private var tolerance = ColorGradient.defaultTolerance
    @State private var location = 0.5
    @State private var steps = 7.0
    @State private var stopsPerSegment = 4.0
    @State private var shadeImage = SampleImage.sunflowers

    private var colors: [RGBAColor] {
        addMiddle ? [start, middle, end] : [start, end]
    }

    var body: some View {
        DemoPage("Gradients") {
            DemoSection(
                "Stops",
                caption: "Blue to yellow passes through gray in sRGB. ColorGradient interpolates in Oklab by default, which stays vivid."
            ) {
                ColorField("Start", color: $start)
                Toggle("Middle stop", isOn: $addMiddle)
                if addMiddle {
                    ColorField("Middle", color: $middle)
                }
                ColorField("End", color: $end)
            }

            DemoSection(
                "Interpolation Spaces",
                caption: "The CSS interpolation spaces. HueInterpolation applies to the polar spaces: OKLCH, LCh (HCL), HSL and HWB. The count is the stops toGradient() adds."
            ) {
                Picker("Hue", selection: $hue) {
                    ForEach(HueInterpolation.allCases, id: \.self) { Text(String(title: $0)).tag($0) }
                }
                .pickerStyle(.segmented)
                VStack(alignment: .leading, spacing: 8) {
                    gradientRow("SwiftUI", detail: "\(colors.count)") {
                        LinearGradient(colors: colors.map { Color($0) }, startPoint: .leading, endPoint: .trailing)
                    }
                    ForEach(ColorInterpolationSpace.allCases, id: \.self) { space in
                        let gradient = ColorGradient(colors: colors, in: space, hue: hue)
                        gradientRow(".\(space.rawValue)", detail: "\(gradient.toRenderingStops().count)") {
                            LinearGradient(gradient: gradient.toGradient(), startPoint: .leading, endPoint: .trailing)
                        }
                    }
                }
            }

            DemoSection(
                "Renderers",
                caption: "Renderers blend differently between stops, so the same two stops look different in each. toRenderingStops(tolerance:) adds stops until the gradient looks the same however they blend. toGradient(), CAGradientLayer.setGradient(_:) and toCGGradient() all use them. toGradient(stopsPerSegment:) adds a fixed number of evenly spaced stops instead, which can take more stops for the same result."
            ) {
                Picker("Space", selection: $space) {
                    ForEach(ColorInterpolationSpace.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                LabeledSlider("Tolerance", value: $tolerance, in: 0.001...0.05, digits: 3)
                Stepper("Stops per segment: \(Int(stopsPerSegment))", value: $stopsPerSegment, in: 1...32)
                let gradient = ColorGradient(colors: colors, in: space, hue: hue)
                Text("\(gradient.toRenderingStops(tolerance: tolerance).count) stops")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 8) {
                    gradientRow("SwiftUI", detail: "2 stops") {
                        LinearGradient(colors: [Color(gradient.color(at: 0)), Color(gradient.color(at: 1))], startPoint: .leading, endPoint: .trailing)
                    }
                    gradientRow("toGradient()") {
                        LinearGradient(gradient: gradient.toGradient(tolerance: tolerance), startPoint: .leading, endPoint: .trailing)
                    }
                    gradientRow(
                        "stopsPerSegment:",
                        detail: "\(gradient.toRenderingStops(stopsPerSegment: Int(stopsPerSegment)).count) stops"
                    ) {
                        LinearGradient(gradient: gradient.toGradient(stopsPerSegment: Int(stopsPerSegment)), startPoint: .leading, endPoint: .trailing)
                    }
                    gradientRow("CAGradientLayer") {
                        GradientLayerView(gradient: gradient, tolerance: tolerance)
                    }
                    gradientRow("CGGradient") {
                        Canvas { context, size in
                            guard let cgGradient = gradient.toCGGradient(tolerance: tolerance) else { return }
                            context.withCGContext { cgContext in
                                cgContext.drawLinearGradient(
                                    cgGradient,
                                    start: .zero,
                                    end: CGPoint(x: size.width, y: 0),
                                    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
                                )
                            }
                        }
                    }
                }
            }

            DemoSection(
                "Curves",
                caption: "ColorGradient(from:to:curve:) eases between two colors. A linear gradient stops changing abruptly at each end, which looks like a hard edge against a solid color. An eased curve starts and ends gently. Curves are cubic Béziers, like UnitCurve and CSS cubic-bezier(), and toRenderingStops() adds stops where they bend."
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Self.curves, id: \.name) { curve in
                        let gradient = ColorGradient(from: start, to: end, curve: curve.curve, in: space, hue: hue)
                        gradientRow(curve.name, detail: "\(gradient.toRenderingStops().count) stops") {
                            LinearGradient(gradient: gradient.toGradient(), startPoint: .leading, endPoint: .trailing)
                        }
                    }
                }
                Text("A shade for text over an image, from black to transparent. The linear shade ends in a visible line; the eased one fades out.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                SampleImagePicker(selection: $shadeImage)
                HStack(spacing: 8) {
                    ForEach([("linear", ColorGradient.Curve.linear), (".easeInOut", .easeInOut)], id: \.0) { name, curve in
                        let shade = ColorGradient(
                            from: RGBAColor(red: 0, green: 0, blue: 0, alpha: 0.85),
                            to: RGBAColor(red: 0, green: 0, blue: 0, alpha: 0),
                            curve: curve
                        )
                        SampleImageView(image: shadeImage, contentMode: .fit)
                            .overlay {
                                LinearGradient(gradient: shade.toGradient(), startPoint: .bottom, endPoint: .top)
                            }
                            .overlay(alignment: .bottomLeading) {
                                Text(name)
                                    .font(.headline.monospaced())
                                    .foregroundStyle(.white)
                                    .padding(10)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .frame(maxWidth: .infinity)
                    }
                }
            }

            DemoSection("Sampling", caption: "color(at:) samples one location, and colors(count:) evenly spaced steps. reversed() mirrors the gradient.") {
                let gradient = ColorGradient(colors: colors, in: space, hue: hue)
                LabeledSlider("Location", value: $location, in: 0...1)
                Swatch(gradient.color(at: location), label: "color(at: \(format(location, 2)))")
                Stepper("Steps: \(Int(steps))", value: $steps, in: 2...16)
                SwatchRow(colors: gradient.colors(count: Int(steps)), height: 36)
                SwatchRow(colors: gradient.reversed().colors(count: Int(steps)), height: 36)
            }
        }
    }

    private static let curves: [(name: String, curve: ColorGradient.Curve)] = [
        ("linear", .linear),
        (".easeIn", .easeIn),
        (".easeOut", .easeOut),
        (".easeInOut", .easeInOut),
        (".bezier(0.7, 0, 0.3, 1)", .bezier(x1: 0.7, y1: 0, x2: 0.3, y2: 1)),
    ]

    private func gradientRow<Content: View>(
        _ title: String,
        detail: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.callout.monospaced())
                if let detail {
                    Text(detail)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 130, alignment: .leading)
            content()
                .frame(height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

// MARK: - CAGradientLayer

#if os(macOS)
/// Hosts a `CAGradientLayer` drawing a ``ColorGradient``.
struct GradientLayerView: NSViewRepresentable {
    var gradient: ColorGradient
    var tolerance: Double

    func makeNSView(context: Context) -> GradientLayerNSView {
        GradientLayerNSView()
    }

    func updateNSView(_ view: GradientLayerNSView, context: Context) {
        view.gradientLayer.setGradient(gradient, tolerance: tolerance)
    }
}

final class GradientLayerNSView: NSView {
    let gradientLayer = CAGradientLayer()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        layer?.addSublayer(gradientLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        gradientLayer.frame = bounds
    }
}
#else
/// Hosts a `CAGradientLayer` drawing a ``ColorGradient``.
struct GradientLayerView: UIViewRepresentable {
    var gradient: ColorGradient
    var tolerance: Double

    func makeUIView(context: Context) -> GradientLayerUIView {
        GradientLayerUIView()
    }

    func updateUIView(_ view: GradientLayerUIView, context: Context) {
        view.gradientLayer.setGradient(gradient, tolerance: tolerance)
    }
}

final class GradientLayerUIView: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }

    var gradientLayer: CAGradientLayer { layer as! CAGradientLayer }

    override init(frame: CGRect) {
        super.init(frame: frame)
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
#endif

#Preview {
    NavigationStack { GradientsDemo() }
}
