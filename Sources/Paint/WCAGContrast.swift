//
// Copyright (c) Nathan Tannar
//

import Foundation

/// The contrast ratio of text on a background, from
/// [WCAG 2.x](https://www.w3.org/TR/WCAG21/#dfn-contrast-ratio).
///
/// The ``rawValue`` ranges from `1` (no contrast) to `21` (black on white), and
/// doesn't depend on which color is the text. WCAG 2 contrast is what most
/// accessibility audits and regulations check. ``APCAContrast`` matches perception
/// more closely, especially for dark colors.
///
/// ```swift
/// let ratio = text.contrast(.wcag).against(background)
/// if ratio.meets(.aa) { ... }
/// ```
///
/// Encodes as the ratio.
@frozen
public struct WCAGContrast: ContrastMetric, Hashable, Comparable, Sendable, BitwiseCopyable, Codable, RawRepresentable, CustomStringConvertible, ExpressibleByFloatLiteral, ExpressibleByIntegerLiteral {

    /// The contrast ratio, from `1` to `21`.
    public var rawValue: Double

    @inlinable
    public init(rawValue: Double) {
        self.rawValue = rawValue
    }

    @inlinable
    public init(floatLiteral value: Double) {
        self.init(rawValue: value)
    }

    @inlinable
    public init(integerLiteral value: Int) {
        self.init(rawValue: Double(value))
    }

    /// AA for normal text, `4.5:1` (success criterion 1.4.3).
    public static let aa: WCAGContrast = 4.5

    /// AA for large text, at least 18pt or 14pt bold, `3:1` (success criterion 1.4.3).
    public static let aaLarge: WCAGContrast = 3

    /// AAA for normal text, `7:1` (success criterion 1.4.6).
    public static let aaa: WCAGContrast = 7

    /// AAA for large text, `4.5:1` (success criterion 1.4.6).
    public static let aaaLarge: WCAGContrast = 4.5

    /// AA for user interface components and graphics, `3:1` (success criterion 1.4.11).
    public static let nonText: WCAGContrast = 3

    /// The contrast ratio of text on a background.
    ///
    /// Translucent text is blended over the background first, in gamma encoded sRGB
    /// as browsers do. The background is treated as opaque. Colors outside Display
    /// P3 are first gamut mapped to it.
    @inlinable
    public init<
        Text: ColorConvertible,
        Background: ColorConvertible
    >(
        text: Text,
        background: Background
    ) {
        let background = background.toRGBAColor().toColorGamut(.displayP3)
        let text = text.toRGBAColor().toColorGamut(.displayP3)
        let alpha = text.alpha.clamped(to: 0...1)
        let blended = background.components + (text.components - background.components) * alpha
        self.init(
            luminance: Self.relativeLuminance(red: blended.x, green: blended.y, blue: blended.z),
            Self.relativeLuminance(red: background.red, green: background.green, blue: background.blue)
        )
    }

    /// The contrast ratio between two relative luminances, in either order.
    @inlinable
    public init(luminance lhs: Double, _ rhs: Double) {
        let lighter = max(lhs, rhs)
        let darker = min(lhs, rhs)
        self.init(rawValue: (lighter + 0.05) / (darker + 0.05))
    }

    /// The contrast formatted like `"4.50:1"`.
    public var description: String {
        String(format: "%.2f:1", rawValue)
    }

    /// The WCAG 2 relative luminance of gamma encoded sRGB components, using the
    /// piecewise sRGB transfer function.
    ///
    /// Components outside `0...1` are extended sRGB. The result is never negative.
    public static func relativeLuminance(red: Double, green: Double, blue: Double) -> Double {
        let luminance = 0.2126 * RGBAColor.linearize(red)
            + 0.7152 * RGBAColor.linearize(green)
            + 0.0722 * RGBAColor.linearize(blue)
        return max(luminance, 0)
    }

    /// The WCAG 2 relative luminance of a color, `0` for black and `1` for white.
    ///
    /// Colors outside Display P3 are first gamut mapped to it. Alpha is ignored.
    public static func luminance(of color: RGBAColor) -> Double {
        let rgba = color.toColorGamut(.displayP3)
        return relativeLuminance(red: rgba.red, green: rgba.green, blue: rgba.blue)
    }

    /// Whether the ratio is at least a level.
    ///
    /// The ratio is compared without rounding, as WCAG requires, so `4.499:1`
    /// doesn't meet ``aa``.
    public func meets(_ level: WCAGContrast) -> Bool {
        rawValue >= level.rawValue
    }

    public static func < (lhs: WCAGContrast, rhs: WCAGContrast) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
