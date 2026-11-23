//
// Copyright (c) Nathan Tannar
//

import Foundation

/// A color as gamma encoded sRGB components.
///
/// Components are nominally in `0...1`. Values outside that range are allowed and
/// represent colors outside the sRGB gamut (extended sRGB).
@frozen
public struct RGBAColor: Hashable, Sendable, BitwiseCopyable, Codable, CustomStringConvertible, ColorConvertible {

    /// The gamma encoded red component, nominally in `0...1`.
    public var red: Double
    /// The gamma encoded green component, nominally in `0...1`.
    public var green: Double
    /// The gamma encoded blue component, nominally in `0...1`.
    public var blue: Double
    /// Opacity, from `0` (transparent) to `1` (opaque).
    public var alpha: Double

    /// Creates a color from gamma encoded sRGB components.
    ///
    /// Components outside `0...1` are kept, as extended sRGB.
    @inlinable
    public init(
        red: Double,
        green: Double,
        blue: Double,
        alpha: Double = 1
    ) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// The components as percentages, like `"rgb(0% 47.8% 100%)"`, or
    /// `"rgb(0% 47.8% 100% / 0.5)"` when translucent.
    ///
    /// Percentages rather than `0...255`, since the components are fractions. Colors
    /// outside sRGB keep components outside `0%...100%`. For a CSS color, use
    /// ``toCSSColor(_:)``.
    public var description: String {
        ColorStringFormatter.describe("rgb", [ColorStringFormatter.percent(red), ColorStringFormatter.percent(green), ColorStringFormatter.percent(blue)], alpha: alpha)
    }

    /// Returns the color with every component clamped to `0...1`.
    public func clamped() -> RGBAColor {
        func clamp(_ value: Double) -> Double { min(max(value, 0), 1) }
        return RGBAColor(
            red: clamp(red),
            green: clamp(green),
            blue: clamp(blue),
            alpha: clamp(alpha)
        )
    }

    /// Converts a gamma encoded sRGB component to linear light.
    ///
    /// Negative values are mirrored, matching extended sRGB.
    public static func linearize(_ c: Double) -> Double {
        let magnitude = abs(c)
        let linear = magnitude <= 0.04045 ? magnitude / 12.92 : pow((magnitude + 0.055) / 1.055, 2.4)
        return c < 0 ? -linear : linear
    }

    /// Converts a linear light component to gamma encoded sRGB.
    ///
    /// Negative values are mirrored, matching extended sRGB.
    public static func delinearize(_ c: Double) -> Double {
        let magnitude = abs(c)
        let encoded = magnitude <= 0.0031308 ? 12.92 * magnitude : 1.055 * pow(magnitude, 1 / 2.4) - 0.055
        return c < 0 ? -encoded : encoded
    }

    public func toRGBAColor() -> RGBAColor {
        self
    }

    public func toHSBAColor() -> HSBAColor {
        let maxColor = max(red, green, blue)
        let minColor = min(red, green, blue)
        let delta = maxColor - minColor
        return HSBAColor(
            hue: .hue(red: red, green: green, blue: blue, max: maxColor, delta: delta),
            saturation: maxColor == 0 ? 0 : delta / maxColor,
            brightness: maxColor,
            alpha: alpha
        )
    }

    public func toHSLAColor() -> HSLAColor {
        let maxColor = max(red, green, blue)
        let minColor = min(red, green, blue)
        let delta = maxColor - minColor
        let lightness = (maxColor + minColor) / 2
        let denominator = 1 - abs(2 * lightness - 1)
        var hue = ColorHue.hue(red: red, green: green, blue: blue, max: maxColor, delta: delta)
        var saturation = delta == 0 || denominator == 0 ? 0 : delta / denominator
        // Lightness outside `0...1` gives a negative saturation, which CSS Color 4
        // represents as the opposite hue
        if saturation < 0 {
            saturation = -saturation
            hue = hue + .degrees(180)
        }
        return HSLAColor(
            hue: hue,
            saturation: saturation,
            lightness: lightness,
            alpha: alpha
        )
    }
}
