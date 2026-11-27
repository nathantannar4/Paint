//
// Copyright (c) Nathan Tannar
//

import Foundation

/// Maps numbers in a domain to colors, for data visualization such as heat maps,
/// choropleths and progress indicators.
///
/// - A sequential scale, from ``sequential(_:domain:in:)``, goes from light to dark
///   in one hue, for values that go from low to high.
/// - A diverging scale, from ``diverging(from:to:domain:midpoint:in:)``, goes from
///   one hue through a light neutral to another, for values above and below a
///   meaningful midpoint, such as a change from zero.
///
/// Both change evenly in OKLCH lightness, so equal steps in value look like equal
/// steps in color, and stay ordered when seen in grayscale or with a color vision
/// deficiency.
///
/// ```swift
/// let heat = ColorScale.sequential(HEXColor("#E4572E"), domain: 0...100)
/// let color = heat(42)
/// let legend = heat.colors(count: 5)
/// ```
@frozen
public struct ColorScale: Hashable, Sendable, Codable {

    /// The gradient values are mapped onto, from its start at ``domain``'s lower bound
    /// to its end at the upper bound.
    public var gradient: ColorGradient

    /// The range of values the scale maps. Values outside it are clamped.
    public var domain: ClosedRange<Double>

    /// The value mapped to the middle of the gradient. `nil` maps values linearly,
    /// so the middle of the gradient is the middle of the domain.
    ///
    /// Set this for diverging scales whose neutral value isn't the middle of the
    /// domain, such as `0` in `-20...100`.
    public var midpoint: Double?

    /// Creates a scale that maps a domain onto a gradient.
    @inlinable
    public init(
        gradient: ColorGradient,
        domain: ClosedRange<Double> = 0...1,
        midpoint: Double? = nil
    ) {
        self.gradient = gradient
        self.domain = domain
        self.midpoint = midpoint
    }

    /// Creates a scale that maps a domain onto colors, evenly spaced and
    /// interpolated in `space`.
    @inlinable
    public init<C: ColorConvertible>(
        colors: [C],
        domain: ClosedRange<Double> = 0...1,
        midpoint: Double? = nil,
        in space: ColorInterpolationSpace = .oklab
    ) {
        self.init(gradient: ColorGradient(colors: colors, in: space), domain: domain, midpoint: midpoint)
    }

    /// A sequential scale in the hue of a color, from a very light tint at the lower
    /// bound of `domain` to a dark shade at the upper bound.
    ///
    /// The colors are the `50` to `900` steps of a ``TonalScale``, so they keep the
    /// hue of the color, and are most colorful in the middle. Interpolated in
    /// Oklab and fitted to `gamut`.
    public static func sequential<C: ColorConvertible>(
        _ color: C,
        domain: ClosedRange<Double> = 0...1,
        in gamut: ColorGamut = .displayP3
    ) -> ColorScale {
        let scale = TonalScale(seed: color, in: gamut)
        return ColorScale(
            colors: [50, 200, 400, 600, 800, 900].map { scale[$0] },
            domain: domain,
            in: .oklab
        )
    }

    /// A diverging scale from the hue of `low`, through a light neutral at
    /// `midpoint`, to the hue of `high`.
    ///
    /// Both ends have the same lightness, so neither side looks more important, and
    /// lightness rises evenly to the neutral middle. For a scale that's readable with
    /// a color vision deficiency, pick hues that differ in blue-yellow, such as blue
    /// and orange, rather than red and green. See
    /// ``Swift/Sequence/minimumDistance(simulating:severity:)``.
    ///
    /// `midpoint` defaults to the middle of `domain`. Interpolated in Oklab and fitted
    /// to `gamut`.
    public static func diverging<Low: ColorConvertible, High: ColorConvertible>(
        from low: Low,
        to high: High,
        domain: ClosedRange<Double> = -1...1,
        midpoint: Double? = nil,
        in gamut: ColorGamut = .displayP3
    ) -> ColorScale {
        let low = TonalScale(seed: low, in: gamut)
        let high = TonalScale(seed: high, in: gamut)
        // A neutral between the two hues, with almost no chroma
        let neutral = low[50].mixed(with: high[50], by: 0.5)
        var middle = neutral
        middle.chroma = min(neutral.chroma, 0.01)
        let colors: [OKLCHColor] = [low[800], low[600], low[300], middle.toColorGamut(gamut), high[300], high[600], high[800]]
        return ColorScale(colors: colors, domain: domain, midpoint: midpoint, in: .oklab)
    }

    /// The location in the gradient, from `0` to `1`, of a value.
    ///
    /// Values outside ``domain`` are clamped. With a ``midpoint``, values below it map
    /// linearly to `0...0.5` and values above it to `0.5...1`.
    public func location(of value: Double) -> Double {
        let lower = domain.lowerBound
        let upper = domain.upperBound
        guard !value.isNaN, upper > lower else { return 0.5 }
        let value = value.clamped(to: domain)
        guard let midpoint, midpoint > lower, midpoint < upper else {
            return (value - lower) / (upper - lower)
        }
        if value <= midpoint {
            return (value - lower) / (midpoint - lower) * 0.5
        }
        return 0.5 + (value - midpoint) / (upper - midpoint) * 0.5
    }

    /// The color of a value.
    public func color(for value: Double) -> RGBAColor {
        gradient.color(at: location(of: value))
    }

    /// The color of a value, see ``color(for:)``.
    public func callAsFunction(_ value: Double) -> RGBAColor {
        color(for: value)
    }

    /// `count` colors evenly spaced across the domain, such as the classes of a
    /// binned legend.
    public func colors(count: Int) -> [RGBAColor] {
        guard count > 0 else { return [] }
        guard count > 1 else { return [color(for: (domain.lowerBound + domain.upperBound) / 2)] }
        return (0..<count).map { index in
            let fraction = Double(index) / Double(count - 1)
            return color(for: domain.lowerBound + (domain.upperBound - domain.lowerBound) * fraction)
        }
    }
}

// MARK: - Distinguishability

extension Sequence where Element: ColorConvertible {

    /// The smallest perceptual difference between any two of the colors, as seen with
    /// a color vision deficiency, or with normal vision when `deficiency` is `nil`.
    ///
    /// Differences are ``ColorConvertible/distance(to:)`` in Oklab, after
    /// ``ColorConvertible/simulating(_:severity:)``. Returns `.infinity` for fewer
    /// than two colors. Alpha is ignored.
    public func minimumDistance(
        simulating deficiency: ColorVisionDeficiency? = nil,
        severity: Double = 1
    ) -> Double {
        let colors = map { color -> OKLabColor in
            guard let deficiency else { return color.toOKLabColor() }
            return color.simulating(deficiency, severity: severity).toOKLabColor()
        }
        var minimum = Double.infinity
        for i in colors.indices {
            for j in colors.indices where j > i {
                minimum = Swift.min(minimum, colors[i].distance(to: colors[j]))
            }
        }
        return minimum
    }

    /// Whether every pair of the colors can be told apart, with normal vision and
    /// with each of `deficiencies`, such as the colors of the series in a chart.
    ///
    /// Two colors can be told apart when their ``minimumDistance(simulating:severity:)``
    /// is at least `threshold`. The default of `0.06` is about three times the
    /// smallest difference most people notice, which keeps small marks, such as
    /// lines and points, distinct. The default deficiencies are the red-green and
    /// blue-yellow dichromacies, which are by far the most common.
    public func isDistinguishable(
        threshold: Double = 0.06,
        for deficiencies: [ColorVisionDeficiency] = [.protanopia, .deuteranopia, .tritanopia]
    ) -> Bool {
        let colors = Array(self)
        guard colors.minimumDistance() >= threshold else { return false }
        return deficiencies.allSatisfy { colors.minimumDistance(simulating: $0) >= threshold }
    }
}
