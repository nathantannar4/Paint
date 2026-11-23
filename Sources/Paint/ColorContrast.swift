//
// Copyright (c) Nathan Tannar
//

import Foundation

/// A measure of the contrast between text and a background, such as ``APCAContrast``
/// or ``WCAGContrast``.
///
/// A metric is the contrast value itself, and defines how colors are measured for
/// it, so the ``ColorContrast`` of a color can offer the same API for each metric:
///
/// ```swift
/// color.contrast(.apca).luminance
/// color.contrast(.wcag).against(background).meets(.aa)
/// ```
public protocol ContrastMetric: Comparable, Sendable {

    /// The luminance of a color, as the metric measures it: `0` for black and `1`
    /// for white.
    static func luminance(of color: RGBAColor) -> Double

    /// The contrast of text on a background.
    init<Text: ColorConvertible, Background: ColorConvertible>(text: Text, background: Background)

    /// Whether the contrast is at least as strong as a minimum.
    func meets(_ minimum: Self) -> Bool
}

/// A contrast algorithm, ``apca`` or ``wcag``, which chooses the ``ContrastMetric``
/// of ``ColorConvertible/contrast(_:)``.
@frozen
public struct ContrastAlgorithm<Metric: ContrastMetric>: Hashable, Sendable {

    /// Creates the algorithm of a metric.
    @inlinable
    public init() {}
}

extension ContrastAlgorithm where Metric == APCAContrast {

    /// The Accessible Perceptual Contrast Algorithm, measured as ``APCAContrast``.
    /// It matches perception more closely than WCAG 2, especially for dark colors.
    public static var apca: Self { .init() }
}

extension ContrastAlgorithm where Metric == WCAGContrast {

    /// The WCAG 2 contrast ratio, measured as ``WCAGContrast``. It's what most
    /// accessibility audits and regulations check.
    public static var wcag: Self { .init() }
}

/// The contrast of a color, measured with a ``ContrastMetric``.
///
/// Create one with ``ColorConvertible/contrast(_:)``. The shared API works the same
/// for every metric, and metrics add their own, such as ``increased(against:by:in:)``
/// for APCA:
///
/// ```swift
/// let contrast = text.contrast(.apca)
/// contrast.luminance
/// contrast.against(background).meets(60)
/// let readable = contrast.adjusted(toMinimum: 60, against: background)
/// ```
@frozen
public struct ColorContrast<Metric: ContrastMetric>: Sendable {

    /// The color measured.
    public var color: RGBAColor

    /// Measures a color with a metric.
    @inlinable
    public init<C: ColorConvertible>(_ color: C, algorithm: ContrastAlgorithm<Metric>) {
        self.color = color.toRGBAColor()
    }

    /// The luminance of the color, as the metric measures it: `0` for black and `1`
    /// for white. Alpha is ignored.
    public var luminance: Double {
        Metric.luminance(of: color)
    }

    /// The contrast of the color as text on a background.
    public func against<Background: ColorConvertible>(_ background: Background) -> Metric {
        Metric(text: color, background: background)
    }

    /// Whether the color is dark, so that white text on it has more contrast than black
    /// text. Alpha is ignored.
    ///
    /// Metrics disagree on colors near the middle: WCAG 2 measures colors with a
    /// relative luminance below about `0.18` as dark, which includes mid tones that
    /// APCA measures as light.
    public var isDark: Bool {
        let white = Metric(text: RGBAColor(red: 1, green: 1, blue: 1), background: color)
        let black = Metric(text: RGBAColor(red: 0, green: 0, blue: 0), background: color)
        return white > black
    }

    /// Whether the color is light, so that black text on it has at least as much
    /// contrast as white text. The opposite of ``isDark``. Alpha is ignored.
    public var isLight: Bool {
        !isDark
    }

    /// Adjusts the lightness of the color as little as possible so that, as text on
    /// `background`, its contrast meets a minimum.
    ///
    /// The hue is kept, so the result is recognizably the same color. The lightness
    /// is searched in OKLCH, both lighter and darker, and the closer result is
    /// returned. If neither direction can meet the minimum, the result is the
    /// lightest or darkest version with the most contrast. The result is always in
    /// `gamut`, so the contrast is what the display shows, and chroma is reduced
    /// where the adjusted lightness can't fit it.
    ///
    /// Colors that already meet the minimum are returned unchanged.
    public func adjusted<Background: ColorConvertible>(
        toMinimum minimum: Metric,
        against background: Background,
        in gamut: ColorGamut = .displayP3
    ) -> RGBAColor {
        let background = background.toRGBAColor()
        return color.adjustedLightness(
            in: gamut,
            meets: { Metric(text: $0, background: background).meets(minimum) },
            prefers: { Metric(text: $0, background: background) >= Metric(text: $1, background: background) }
        )
    }
}

extension ColorContrast where Metric == APCAContrast {

    /// Returns the color with more contrast against `background`, for an increased
    /// contrast accessibility setting.
    ///
    /// The APCA contrast is increased by `amount` in Lc, by adjusting lightness as in
    /// ``adjusted(toMinimum:against:in:)``. Where that much contrast isn't possible,
    /// the result has as much as it can.
    public func increased<Background: ColorConvertible>(
        against background: Background,
        by amount: Double = 15,
        in gamut: ColorGamut = .displayP3
    ) -> RGBAColor {
        let target = against(background).magnitude + amount
        return adjusted(toMinimum: APCAContrast(rawValue: target), against: background, in: gamut)
    }
}

extension ColorConvertible {

    /// The contrast of the color, measured with an algorithm.
    ///
    /// ```swift
    /// color.contrast(.apca).isDark
    /// color.contrast(.wcag).against(background).meets(.aa)
    /// ```
    public func contrast<Metric: ContrastMetric>(_ algorithm: ContrastAlgorithm<Metric>) -> ColorContrast<Metric> {
        ColorContrast(self, algorithm: algorithm)
    }

    /// Adjusts the OKLCH lightness of the color as little as possible so that it
    /// `meets` a requirement that gets easier towards black or white, see
    /// ``ColorContrast/adjusted(toMinimum:against:in:)``.
    ///
    /// If neither black nor white meets it, returns whichever of the darkest or
    /// lightest version `prefers` (whether its first argument is better).
    func adjustedLightness(
        in gamut: ColorGamut,
        meets: (RGBAColor) -> Bool,
        prefers: (RGBAColor, RGBAColor) -> Bool
    ) -> RGBAColor {
        let original = toRGBAColor()
        if meets(original) {
            return original
        }

        let oklch = original.toOKLCHColor()
        func candidate(lightness: Double) -> RGBAColor {
            var color = oklch
            color.lightness = lightness
            let rgba = color.toColorGamut(gamut).toRGBAColor()
            // Remove floating point error at the edges of sRGB
            return gamut == .sRGB ? rgba.clamped() : rgba
        }

        /// The lightness closest to the original that meets the minimum, searching
        /// towards `limit`, or `nil` if `limit` itself doesn't meet it.
        func search(towards limit: Double) -> Double? {
            guard meets(candidate(lightness: limit)) else { return nil }
            // `failing` never meets the minimum, `passing` always does
            var failing = oklch.lightness
            var passing = limit
            for _ in 0..<32 where abs(passing - failing) > 1e-6 {
                let mid = (failing + passing) / 2
                if meets(candidate(lightness: mid)) {
                    passing = mid
                } else {
                    failing = mid
                }
            }
            return passing
        }

        switch (search(towards: 0), search(towards: 1)) {
        case let (darker?, lighter?):
            let lightness = abs(darker - oklch.lightness) <= abs(lighter - oklch.lightness) ? darker : lighter
            return candidate(lightness: lightness)
        case let (darker?, nil):
            return candidate(lightness: darker)
        case let (nil, lighter?):
            return candidate(lightness: lighter)
        case (nil, nil):
            let black = candidate(lightness: 0)
            let white = candidate(lightness: 1)
            return prefers(black, white) ? black : white
        }
    }
}
