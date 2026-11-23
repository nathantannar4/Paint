//
// Copyright (c) Nathan Tannar
//

import SwiftUI
import CoreGraphics
import simd
#if canImport(QuartzCore) && !os(watchOS)
import QuartzCore
#endif

/// The color space colors are interpolated in, like the CSS `<color-interpolation-method>`.
///
/// Encodes as its case name, such as `"oklab"`.
@frozen
public enum ColorInterpolationSpace: String, Hashable, Sendable, Codable, CaseIterable, CustomStringConvertible {

    /// Oklab, the default. Midpoints stay as light and colorful as the ends, without
    /// shifting hue.
    case oklab

    /// OKLCH, which interpolates hue around the color wheel. Midpoints between
    /// distant hues stay saturated, passing through the hues in between.
    case oklch

    /// CIE Lab, like CSS `lab`. Similar to ``oklab``, but blues drift towards purple.
    case lab

    /// CIE LCh, like CSS `lch`, also known as HCL. Similar to ``oklch``, but blues
    /// drift towards purple.
    case lch

    /// Gamma encoded sRGB, as SwiftUI and CSS gradients do by default. Midpoints
    /// between distant hues are dark and gray.
    case sRGB

    /// Linear light sRGB, which mixes like light. Midpoints are lighter than in sRGB.
    case linearSRGB

    /// HSL, like CSS `hsl`, which interpolates hue around the color wheel. Unlike
    /// ``oklch``, lightness isn't perceptual, so midpoints can be much lighter or
    /// darker than the ends.
    case hsl

    /// HWB, like CSS `hwb`, which interpolates hue around the color wheel, with
    /// whiteness and blackness.
    case hwb

    /// Whether the space has a hue, so ``HueInterpolation`` applies.
    public var isPolar: Bool {
        switch self {
        case .oklch, .lch, .hsl, .hwb: true
        case .oklab, .lab, .sRGB, .linearSRGB: false
        }
    }

    /// The raw value, such as `"oklch"`.
    public var description: String {
        rawValue
    }
}

/// The direction hues are interpolated around the color wheel in polar spaces, such
/// as ``ColorInterpolationSpace/oklch``, like the CSS `<hue-interpolation-method>`.
///
/// Encodes as its case name, such as `"shorter"`.
@frozen
public enum HueInterpolation: String, Hashable, Sendable, Codable, CaseIterable, CustomStringConvertible {
    /// The shorter way around, at most 180°. The default.
    case shorter
    /// The longer way around, at least 180°.
    case longer
    /// Always increasing the hue angle.
    case increasing
    /// Always decreasing the hue angle.
    case decreasing

    /// The signed change in degrees from one hue to another, going this way around.
    public func delta(from start: Double, to end: Double) -> Double {
        var delta = end - start
        switch self {
        case .shorter:
            if delta > 180 { delta -= 360 } else if delta < -180 { delta += 360 }
        case .longer:
            if delta > 0, delta < 180 { delta -= 360 } else if delta > -180, delta <= 0 { delta += 360 }
        case .increasing:
            if delta < 0 { delta += 360 }
        case .decreasing:
            if delta > 0 { delta -= 360 }
        }
        return delta
    }

    /// The raw value, such as `"shorter"`.
    public var description: String {
        rawValue
    }
}

extension ColorConvertible {

    /// Interpolates between the color and another, like CSS `color-mix()`.
    ///
    /// A `fraction` of `0` is this color and `1` is `other`. Alpha is premultiplied,
    /// so interpolating with a transparent color fades without shifting the color.
    /// In polar spaces, such as OKLCH, the hue of an achromatic color, such as white,
    /// is powerless: it takes the hue of the other color, so that it doesn't swing
    /// through unrelated hues.
    public func interpolated<
        Other: ColorConvertible
    >(
        to other: Other,
        by fraction: Double,
        in space: ColorInterpolationSpace = .oklab,
        hue: HueInterpolation = .shorter
    ) -> RGBAColor {
        func mix(_ lhs: Double, _ rhs: Double) -> Double {
            lhs + (rhs - lhs) * fraction
        }
        /// Interpolates premultiplied components and unpremultiplies them.
        func premultiplied(
            _ lhs: SIMD3<Double>, _ lhsAlpha: Double,
            _ rhs: SIMD3<Double>, _ rhsAlpha: Double
        ) -> (SIMD3<Double>, Double) {
            let alpha = mix(lhsAlpha, rhsAlpha)
            guard alpha != 0 else {
                return (lhs + (rhs - lhs) * fraction, 0)
            }
            let lhsP = lhs * lhsAlpha
            let rhsP = rhs * rhsAlpha
            return ((lhsP + (rhsP - lhsP) * fraction) / alpha, alpha)
        }
        /// Interpolates a hue and two premultiplied components. A powerless hue takes
        /// the other hue.
        func polar(
            _ lhs: (hue: Double, values: SIMD2<Double>, alpha: Double, isAchromatic: Bool),
            _ rhs: (hue: Double, values: SIMD2<Double>, alpha: Double, isAchromatic: Bool)
        ) -> (hue: ColorHue, values: SIMD2<Double>, alpha: Double) {
            var lhsHue = lhs.hue
            var rhsHue = rhs.hue
            if lhs.isAchromatic, !rhs.isAchromatic {
                lhsHue = rhsHue
            } else if rhs.isAchromatic, !lhs.isAchromatic {
                rhsHue = lhsHue
            }
            let (values, alpha) = premultiplied(
                SIMD3(lhs.values, 0), lhs.alpha,
                SIMD3(rhs.values, 0), rhs.alpha
            )
            let delta = hue.delta(from: lhsHue, to: rhsHue)
            return (.degrees(lhsHue + delta * fraction), SIMD2(values.x, values.y), alpha)
        }

        switch space {
        case .oklab:
            return mixed(with: other, by: fraction).toRGBAColor()

        case .lab:
            let lhs = toCIELabColor()
            let rhs = other.toCIELabColor()
            let (lab, alpha) = premultiplied(
                SIMD3(lhs.lightness, lhs.a, lhs.b), lhs.alpha,
                SIMD3(rhs.lightness, rhs.a, rhs.b), rhs.alpha
            )
            return CIELabColor(lightness: lab.x, a: lab.y, b: lab.z, alpha: alpha).toRGBAColor()

        case .sRGB, .linearSRGB:
            let lhs = toRGBAColor()
            let rhs = other.toRGBAColor()
            if space == .sRGB {
                let (components, alpha) = premultiplied(lhs.components, lhs.alpha, rhs.components, rhs.alpha)
                return RGBAColor(components: components, alpha: alpha)
            }
            let (linear, alpha) = premultiplied(lhs.toLinearComponents(), lhs.alpha, rhs.toLinearComponents(), rhs.alpha)
            return RGBAColor(linear: linear, alpha: alpha)

        case .oklch:
            let lhs = toOKLCHColor()
            let rhs = other.toOKLCHColor()
            // Converted grays have a chroma of about `1e-8`, not exactly `0`
            let result = polar(
                (lhs.hue.degrees, SIMD2(lhs.lightness, lhs.chroma), lhs.alpha, lhs.chroma < 1e-6),
                (rhs.hue.degrees, SIMD2(rhs.lightness, rhs.chroma), rhs.alpha, rhs.chroma < 1e-6)
            )
            return OKLCHColor(lightness: result.values.x, chroma: result.values.y, hue: result.hue, alpha: result.alpha).toRGBAColor()

        case .lch:
            let lhs = toCIELCHColor()
            let rhs = other.toCIELCHColor()
            // CIE LCh chroma is about 150 times larger than OKLCH chroma
            let result = polar(
                (lhs.hue.degrees, SIMD2(lhs.lightness, lhs.chroma), lhs.alpha, lhs.chroma < 1e-4),
                (rhs.hue.degrees, SIMD2(rhs.lightness, rhs.chroma), rhs.alpha, rhs.chroma < 1e-4)
            )
            return CIELCHColor(lightness: result.values.x, chroma: result.values.y, hue: result.hue, alpha: result.alpha).toRGBAColor()

        case .hsl:
            let lhs = toHSLAColor()
            let rhs = other.toHSLAColor()
            let result = polar(
                (lhs.hue.degrees, SIMD2(lhs.saturation, lhs.lightness), lhs.alpha, lhs.saturation < 1e-6),
                (rhs.hue.degrees, SIMD2(rhs.saturation, rhs.lightness), rhs.alpha, rhs.saturation < 1e-6)
            )
            return HSLAColor(hue: result.hue, saturation: result.values.x, lightness: result.values.y, alpha: result.alpha).toRGBAColor()

        case .hwb:
            let lhs = toHWBColor()
            let rhs = other.toHWBColor()
            let result = polar(
                (lhs.hue.degrees, SIMD2(lhs.whiteness, lhs.blackness), lhs.alpha, lhs.whiteness + lhs.blackness >= 1 - 1e-6),
                (rhs.hue.degrees, SIMD2(rhs.whiteness, rhs.blackness), rhs.alpha, rhs.whiteness + rhs.blackness >= 1 - 1e-6)
            )
            return HWBColor(hue: result.hue, whiteness: result.values.x, blackness: result.values.y, alpha: result.alpha).toRGBAColor()
        }
    }
}

/// A gradient through colors at locations, interpolated in a chosen color space.
///
/// SwiftUI, Core Graphics and Core Animation gradients blend linearly between stops,
/// so the middle of a blue to yellow gradient is a dull gray, and each blends a
/// little differently. A `ColorGradient` interpolates perceptually, and approximates
/// the result with extra stops, see ``toRenderingStops(tolerance:)``, so it looks the
/// same in each of them:
///
/// ```swift
/// let gradient = ColorGradient(colors: [HEXColor("#0000FF"), HEXColor("#FFFF00")])
///
/// // SwiftUI
/// LinearGradient(gradient: gradient.toGradient(), startPoint: .leading, endPoint: .trailing)
///
/// // Core Animation
/// let layer = CAGradientLayer()
/// layer.setGradient(gradient)
///
/// // Core Graphics
/// context.drawLinearGradient(gradient.toCGGradient()!, start: start, end: end, options: [])
/// ```
@frozen
public struct ColorGradient: Hashable, Sendable, Codable {

    /// A color at a location in `0...1`.
    @frozen
    public struct Stop: Hashable, Sendable, BitwiseCopyable, Codable {
        /// The color of the stop.
        public var color: RGBAColor
        /// The location of the stop, nominally in `0...1`.
        public var location: Double

        /// Creates a stop with a color at a location.
        @inlinable
        public init<C: ColorConvertible>(color: C, location: Double) {
            self.color = color.toRGBAColor()
            self.location = location
        }
    }

    /// The default tolerance of ``toRenderingStops(tolerance:)``, as an Oklab distance: a
    /// tenth of the smallest difference most people notice.
    public static let defaultTolerance = 0.002

    /// The stops, sorted by location.
    public var stops: [Stop]

    /// The color space the stops are interpolated in.
    public var space: ColorInterpolationSpace

    /// The direction hues are interpolated in polar spaces, such as
    /// ``ColorInterpolationSpace/oklch``.
    public var hue: HueInterpolation

    /// The easing curve between each pair of stops. ``Curve/linear`` by default.
    public var curve: Curve

    /// Creates a gradient from stops, which are sorted by location.
    @inlinable
    public init(
        stops: [Stop],
        in space: ColorInterpolationSpace = .oklab,
        hue: HueInterpolation = .shorter,
        curve: Curve = .linear
    ) {
        self.stops = stops.enumerated()
            .sorted { $0.element.location != $1.element.location ? $0.element.location < $1.element.location : $0.offset < $1.offset }
            .map { $0.element }
        self.space = space
        self.hue = hue
        self.curve = curve
    }

    private enum CodingKeys: String, CodingKey {
        case stops
        case space
        case hue
        case curve
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            stops: container.decode([Stop].self, forKey: .stops),
            in: container.decode(ColorInterpolationSpace.self, forKey: .space),
            hue: container.decode(HueInterpolation.self, forKey: .hue),
            curve: container.decodeIfPresent(Curve.self, forKey: .curve) ?? .linear
        )
    }

    /// Creates a gradient through colors, evenly spaced from `0` to `1`.
    @inlinable
    public init<C: ColorConvertible>(
        colors: [C],
        in space: ColorInterpolationSpace = .oklab,
        hue: HueInterpolation = .shorter,
        curve: Curve = .linear
    ) {
        let last = max(colors.count - 1, 1)
        self.init(
            stops: colors.enumerated().map { Stop(color: $1, location: colors.count == 1 ? 0 : Double($0) / Double(last)) },
            in: space,
            hue: hue,
            curve: curve
        )
    }

    /// Creates a gradient from one color to another, eased by a curve.
    ///
    /// A linear gradient changes at a constant rate, then stops changing abruptly at
    /// each end, which the eye sees as a hard edge where it meets a solid color. An
    /// eased gradient, such as ``Curve/easeInOut``, starts and ends gently, so it
    /// blends into the colors around it:
    ///
    /// ```swift
    /// let shade = ColorGradient(from: HEXColor("#000000"), to: RGBAColor(red: 0, green: 0, blue: 0, alpha: 0), curve: .easeInOut)
    /// LinearGradient(gradient: shade.toGradient(), startPoint: .bottom, endPoint: .top)
    /// ```
    ///
    /// The curve is followed by every renderer, since ``toRenderingStops(tolerance:)``
    /// adds stops where it bends.
    @inlinable
    public init<From: ColorConvertible, To: ColorConvertible>(
        from start: From,
        to end: To,
        curve: Curve,
        in space: ColorInterpolationSpace = .oklab,
        hue: HueInterpolation = .shorter
    ) {
        self.init(
            stops: [Stop(color: start, location: 0), Stop(color: end, location: 1)],
            in: space,
            hue: hue,
            curve: curve
        )
    }

    /// The color at a location. Locations before the first stop or after the last are
    /// the color of that stop. An empty gradient is transparent black.
    public func color(at location: Double) -> RGBAColor {
        guard let first = stops.first, let last = stops.last else {
            return RGBAColor(red: 0, green: 0, blue: 0, alpha: 0)
        }
        if location.isNaN || location <= first.location {
            return first.color
        }
        if location >= last.location {
            return last.color
        }
        // The last stop at or before the location, so hard edges take the later stop
        let index = stops.lastIndex { $0.location <= location } ?? 0
        let start = stops[index]
        let end = stops[index + 1]
        let width = end.location - start.location
        guard width > 0 else { return end.color }
        if location == start.location {
            return start.color
        }
        return interpolate(start, end, by: (location - start.location) / width)
    }

    /// `count` colors evenly spaced from `0` to `1`, such as the steps of a scale.
    public func colors(count: Int) -> [RGBAColor] {
        guard count > 0 else { return [] }
        guard count > 1 else { return [color(at: 0)] }
        return (0..<count).map { color(at: Double($0) / Double(count - 1)) }
    }

    /// The gradient with its stops in reverse order, mirrored from `1` to `0`. The curve
    /// is mirrored too, so the gradient looks the same, flipped.
    public func reversed() -> ColorGradient {
        ColorGradient(
            stops: stops.reversed().map { Stop(color: $0.color, location: 1 - $0.location) },
            in: space,
            hue: hue,
            curve: curve.reversed()
        )
    }

    private func interpolate(_ start: Stop, _ end: Stop, by fraction: Double) -> RGBAColor {
        start.color.interpolated(to: end.color, by: curve.value(at: fraction), in: space, hue: hue)
    }

    // MARK: - Stops for renderers

    /// Stops that approximate the gradient for a renderer that blends linearly
    /// between stops, such as SwiftUI, Core Graphics and Core Animation.
    ///
    /// Renderers blend differently: Core Graphics blends gamma encoded sRGB without
    /// premultiplying alpha, SwiftUI premultiplies alpha and blends darker midpoints,
    /// and Core Animation blends lighter ones. So a two stop gradient from black to
    /// white looks different in each. Stops are added until the gradient is within
    /// `tolerance` however a renderer blends between neighboring stops, from linear
    /// light to a gamma of 3, with or without premultiplied alpha, so it looks the
    /// same in every renderer.
    ///
    /// Each segment is split in half where it's needed, so a subtle gradient needs
    /// few stops, and one that sweeps through many hues, such as
    /// ``HueInterpolation/longer`` in OKLCH, needs more. Each segment is split into at
    /// most 256 parts, so the darkest sliver of a gradient from black, where renderers
    /// disagree most, can exceed the tolerance.
    ///
    /// `tolerance` is an Oklab distance, see ``ColorConvertible/distance(to:)``,
    /// measured as a Display P3 display shows the colors, so differences between
    /// colors no display can show aren't counted, and with Oklab's toe-corrected
    /// lightness, so differences between colors almost too dark to see aren't
    /// overstated. The default ``defaultTolerance`` of
    /// `0.002` is a tenth of the smallest difference most people notice. Colors are
    /// kept as extended sRGB, so wide gamut colors aren't clipped.
    public func toRenderingStops(tolerance: Double = ColorGradient.defaultTolerance) -> [Stop] {
        guard stops.count > 1 else { return stops }
        let tolerance = tolerance.isNaN ? Self.defaultTolerance : max(tolerance, 1e-6)
        var result: [Stop] = []
        for (start, end) in zip(stops, stops.dropFirst()) {
            result.append(start)
            let width = end.location - start.location
            guard width > 0 else { continue }

            func color(at fraction: Double) -> RGBAColor {
                fraction <= 0 ? start.color : fraction >= 1 ? end.color : interpolate(start, end, by: fraction)
            }

            func subdivide(_ lower: (fraction: Double, color: RGBAColor), _ upper: (fraction: Double, color: RGBAColor), depth: Int) {
                guard depth < 8 else { return }
                // Sampled at three points, so S-shaped differences aren't missed
                let isWithinTolerance = [0.25, 0.5, 0.75].allSatisfy { sample in
                    let expected = Self.displayed(color(at: lower.fraction + (upper.fraction - lower.fraction) * sample))
                    return Self.renderers.allSatisfy { renderer in
                        let rendered = Self.rendered(from: lower.color, to: upper.color, by: sample, with: renderer)
                        return Self.renderingError(expected, Self.displayed(rendered)) <= tolerance
                    }
                }
                guard !isWithinTolerance else { return }
                let fraction = (lower.fraction + upper.fraction) / 2
                let middle = (fraction: fraction, color: color(at: fraction))
                subdivide(lower, middle, depth: depth + 1)
                result.append(Stop(color: middle.color, location: start.location + width * fraction))
                subdivide(middle, upper, depth: depth + 1)
            }

            subdivide((0, start.color), (1, end.color), depth: 0)
        }
        if let last = stops.last {
            result.append(last)
        }
        return result
    }

    /// Stops that approximate the gradient with `stopsPerSegment` stops between each
    /// pair of stops, evenly spaced, for a renderer that blends linearly between them.
    ///
    /// Prefer ``toRenderingStops(tolerance:)``, which adds stops only where they're
    /// needed.
    public func toRenderingStops(stopsPerSegment: Int) -> [Stop] {
        guard stops.count > 1 else { return stops }
        let segments = max(stopsPerSegment, 1)
        var result: [Stop] = []
        for (start, end) in zip(stops, stops.dropFirst()) {
            let steps = start.location == end.location ? 1 : segments
            for step in 0..<steps {
                let fraction = Double(step) / Double(steps)
                let location = start.location + (end.location - start.location) * fraction
                result.append(Stop(color: step == 0 ? start.color : interpolate(start, end, by: fraction), location: location))
            }
        }
        if let last = stops.last {
            result.append(last)
        }
        return result
    }

    /// How a renderer might blend between two stops.
    struct Renderer {
        /// The gamma of the components blended: `1` is linear light, `nil` is the
        /// sRGB transfer function.
        var gamma: Double?
        var isPremultiplied: Bool
    }

    /// The extremes of how renderers blend. Core Graphics blends gamma encoded sRGB,
    /// Core Animation about a gamma of 1.8 and SwiftUI about a gamma of 3.
    static let renderers: [Renderer] = [1, nil, 3].flatMap { gamma in
        [false, true].map { Renderer(gamma: gamma, isPremultiplied: $0) }
    }

    /// Blends two colors as a renderer does: linearly, in the renderer's encoding.
    static func rendered(from lhs: RGBAColor, to rhs: RGBAColor, by fraction: Double, with renderer: Renderer) -> RGBAColor {
        func encode(_ c: Double) -> Double {
            guard let gamma = renderer.gamma else { return c }
            let linear = RGBAColor.linearize(c)
            return linear < 0 ? -pow(-linear, 1 / gamma) : pow(linear, 1 / gamma)
        }
        func decode(_ c: Double) -> Double {
            guard let gamma = renderer.gamma else { return c }
            let linear = c < 0 ? -pow(-c, gamma) : pow(c, gamma)
            return RGBAColor.delinearize(linear)
        }
        let lhsComponents = SIMD3(encode(lhs.red), encode(lhs.green), encode(lhs.blue))
        let rhsComponents = SIMD3(encode(rhs.red), encode(rhs.green), encode(rhs.blue))
        let alpha = lhs.alpha + (rhs.alpha - lhs.alpha) * fraction
        var components: SIMD3<Double>
        if renderer.isPremultiplied, alpha > 0 {
            let lhsP = lhsComponents * lhs.alpha
            let rhsP = rhsComponents * rhs.alpha
            components = (lhsP + (rhsP - lhsP) * fraction) / alpha
        } else {
            components = lhsComponents + (rhsComponents - lhsComponents) * fraction
        }
        return RGBAColor(red: decode(components.x), green: decode(components.y), blue: decode(components.z), alpha: alpha)
    }

    /// The color as a Display P3 display shows it, clipped to the gamut.
    static func displayed(_ color: RGBAColor) -> RGBAColor {
        let p3 = ColorSpaceMatrix.linearSRGBToLinearDisplayP3 * color.toLinearComponents()
        let clipped = SIMD3(p3.x.clamped(to: 0...1), p3.y.clamped(to: 0...1), p3.z.clamped(to: 0...1))
        return RGBAColor(linear: ColorSpaceMatrix.linearDisplayP3ToLinearSRGB * clipped, alpha: color.alpha.clamped(to: 0...1))
    }

    /// The visible difference between two colors: the Oklab distance, weighted by how
    /// opaque they are, or the difference in alpha.
    ///
    /// Lightness uses Oklab's toe, as Okhsl does, which like CIE L* is linear near
    /// black, so differences between colors almost too dark to see aren't overstated.
    static func renderingError(_ expected: RGBAColor, _ rendered: RGBAColor) -> Double {
        func toe(_ lightness: Double) -> Double {
            let k1 = 0.206, k2 = 0.03, k3 = (1 + k1) / (1 + k2)
            let x = k3 * lightness - k1
            return (x + (x * x + 4 * k2 * k3 * lightness).squareRoot()) / 2
        }
        let lhs = expected.toOKLabColor()
        let rhs = rendered.toOKLabColor()
        let lightness = toe(max(lhs.lightness, 0)) - toe(max(rhs.lightness, 0))
        let a = lhs.a - rhs.a
        let b = lhs.b - rhs.b
        let distance = (lightness * lightness + a * a + b * b).squareRoot()
        let opacity = max(expected.alpha, rendered.alpha).clamped(to: 0...1)
        return max(distance * opacity, abs(expected.alpha - rendered.alpha))
    }

    // MARK: - SwiftUI

    /// A SwiftUI gradient that approximates this one, with the stops of
    /// ``toRenderingStops(tolerance:)``.
    public func toGradient(tolerance: Double = ColorGradient.defaultTolerance) -> Gradient {
        Self.gradient(toRenderingStops(tolerance: tolerance))
    }

    /// A SwiftUI gradient that approximates this one with `stopsPerSegment` stops
    /// between each pair of stops, see ``toRenderingStops(stopsPerSegment:)``.
    public func toGradient(stopsPerSegment: Int) -> Gradient {
        Self.gradient(toRenderingStops(stopsPerSegment: stopsPerSegment))
    }

    private static func gradient(_ stops: [Stop]) -> Gradient {
        Gradient(stops: stops.map { Gradient.Stop(color: $0.color.toColor(), location: CGFloat($0.location)) })
    }

    // MARK: - Core Graphics

    /// The colors and locations of ``toRenderingStops(tolerance:)``, for a `CAGradientLayer`
    /// or `CGGradient`.
    ///
    /// Colors are in the extended sRGB color space, so wide gamut colors aren't
    /// clipped, see ``ColorConvertible/toCGColor()``. See `CAGradientLayer.setGradient(_:tolerance:)`
    /// to set them on a layer.
    public func toCGColorsAndLocations(
        tolerance: Double = ColorGradient.defaultTolerance
    ) -> (colors: [CGColor], locations: [CGFloat]) {
        let stops = toRenderingStops(tolerance: tolerance)
        return (stops.map { $0.color.toCGColor() }, stops.map { CGFloat($0.location) })
    }

    /// A Core Graphics gradient that approximates this one, with the stops of
    /// ``toRenderingStops(tolerance:)``, in the extended sRGB color space.
    ///
    /// Returns `nil` for an empty gradient.
    public func toCGGradient(tolerance: Double = ColorGradient.defaultTolerance) -> CGGradient? {
        let (colors, locations) = toCGColorsAndLocations(tolerance: tolerance)
        guard !colors.isEmpty, let colorSpace = CGColorSpace(name: CGColorSpace.extendedSRGB) else {
            return nil
        }
        return CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: locations)
    }
}

// MARK: - Curve

extension ColorGradient {

    /// An easing curve, which changes how quickly a gradient moves between its stops,
    /// like a SwiftUI `UnitCurve` or a CSS `cubic-bezier()` timing function.
    ///
    /// A curve maps progress between two stops, from `0` to `1`, to how far the color
    /// has moved from the first to the second. Every curve is a cubic Bézier from
    /// `(0, 0)` to `(1, 1)` with two control points, so it can be encoded.
    ///
    /// Encodes as its control points, such as `{"x1": 0.42, "y1": 0, "x2": 0.58, "y2": 1}`.
    @frozen
    public struct Curve: Hashable, Sendable, Codable {

        public var x1: Double
        public var y1: Double
        public var x2: Double
        public var y2: Double

        /// A constant rate, the default.
        public static let linear = Curve(x1: 0, y1: 0, x2: 1, y2: 1)

        /// Starts slowly, then speeds up, like CSS `ease-in`.
        public static let easeIn = Curve(x1: 0.42, y1: 0, x2: 1, y2: 1)

        /// Starts quickly, then slows down, like CSS `ease-out`.
        public static let easeOut = Curve(x1: 0, y1: 0, x2: 0.58, y2: 1)

        /// Starts and ends slowly, like CSS `ease-in-out`, so the gradient blends into
        /// the colors at each end.
        public static let easeInOut = Curve(x1: 0.42, y1: 0, x2: 0.58, y2: 1)

        /// A curve with two control points, like `UnitCurve.bezier(startControlPoint:endControlPoint:)`.
        ///
        /// The `x` of each control point is clamped to `0...1`, so the curve moves
        /// forward. The `y` can be outside `0...1`, which overshoots the stops.
        public static func bezier(x1: Double, y1: Double, x2: Double, y2: Double) -> Curve {
            Curve(
                x1: x1.clamped(to: 0...1),
                y1: y1,
                x2: x2.clamped(to: 0...1),
                y2: y2
            )
        }

        /// How far the color has moved for a progress between two stops, both usually
        /// in `0...1`. Progress outside `0...1` is clamped.
        public func value(at progress: Double) -> Double {
            let x = progress.isNaN ? 0 : progress.clamped(to: 0...1)
            // A straight line, such as `linear`, is exact
            if x1 == y1, x2 == y2 {
                return x
            }
            return sample(y1, y2, at: parameter(forX: x))
        }

        /// The curve mirrored, so that easing in becomes easing out, for a reversed
        /// gradient. Mirroring twice gives the original curve.
        public func reversed() -> Curve {
            // Rounded to 12 decimal places, so `1 - (1 - 0.58)` is `0.58`, and mirrored
            // curves equal the presets, such as `easeIn.reversed() == easeOut`
            func mirror(_ value: Double) -> Double {
                ((1 - value) * 1e12).rounded() / 1e12
            }
            return Curve(x1: mirror(x2), y1: mirror(y2), x2: mirror(x1), y2: mirror(y1))
        }

        /// A coordinate of the Bézier at a parameter, with end points `0` and `1`.
        private func sample(_ p1: Double, _ p2: Double, at t: Double) -> Double {
            let u = 1 - t
            return 3 * u * u * t * p1 + 3 * u * t * t * p2 + t * t * t
        }

        /// The derivative of a coordinate at a parameter.
        private func slope(_ p1: Double, _ p2: Double, at t: Double) -> Double {
            let u = 1 - t
            return 3 * u * u * p1 + 6 * u * t * (p2 - p1) + 3 * t * t * (1 - p2)
        }

        /// The parameter where the curve reaches `x`. Newton's method converges quickly
        /// for typical curves, and bisection handles the rest, since `x` only increases.
        private func parameter(forX x: Double) -> Double {
            var t = x
            for _ in 0..<8 {
                let error = sample(x1, x2, at: t) - x
                if abs(error) < 1e-12 { return t }
                let derivative = slope(x1, x2, at: t)
                guard abs(derivative) > 1e-9 else { break }
                t -= error / derivative
                guard (0...1).contains(t) else { break }
            }
            var low = 0.0
            var high = 1.0
            t = x
            for _ in 0..<64 {
                let value = sample(x1, x2, at: t)
                if abs(value - x) < 1e-12 { break }
                if value < x { low = t } else { high = t }
                t = (low + high) / 2
            }
            return t
        }
    }
}

#if canImport(QuartzCore) && !os(watchOS)
extension CAGradientLayer {

    /// Sets the `colors` and `locations` of the layer to draw a ``ColorGradient``,
    /// with the stops of ``ColorGradient/toRenderingStops(tolerance:)``.
    ///
    /// The type, start point and end point of the layer are unchanged. A gradient
    /// with one stop fills the layer with its color.
    public func setGradient(
        _ gradient: ColorGradient,
        tolerance: Double = ColorGradient.defaultTolerance
    ) {
        var (colors, locations) = gradient.toCGColorsAndLocations(tolerance: tolerance)
        // A layer needs two colors to draw
        if colors.count == 1 {
            colors = [colors[0], colors[0]]
            locations = [0, 1]
        }
        self.colors = colors
        self.locations = locations.map { NSNumber(value: Double($0)) }
    }
}
#endif
