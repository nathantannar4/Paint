//
// Copyright (c) Nathan Tannar
//

import Foundation

/// A color as hue, saturation and brightness (HSV) components of the sRGB color space.
///
/// Saturation, brightness and alpha are in `0...1`.
@frozen
public struct HSBAColor: Hashable, Sendable, BitwiseCopyable, Codable, CustomStringConvertible, ColorConvertible {

    /// The hue angle.
    public var hue: ColorHue
    /// Saturation, from `0` (gray) to `1` (fully saturated).
    public var saturation: Double
    /// Brightness, from `0` (black) to `1` (the brightest version of the hue).
    public var brightness: Double
    /// Opacity, from `0` (transparent) to `1` (opaque).
    public var alpha: Double

    /// Creates a color from hue, saturation and brightness components.
    @inlinable
    public init(
        hue: ColorHue,
        saturation: Double,
        brightness: Double,
        alpha: Double = 1
    ) {
        self.hue = hue
        self.saturation = saturation
        self.brightness = brightness
        self.alpha = alpha
    }

    /// Converts a color from gamma encoded sRGB components.
    @inlinable
    public init(_ rgba: RGBAColor) {
        self = rgba.toHSBAColor()
    }

    /// Converts from HSL directly, preserving the hue.
    @inlinable
    public init(_ hsla: HSLAColor) {
        self = hsla.toHSBAColor()
    }

    /// The components like `"hsb(211.32 100% 100%)"`, with the hue in degrees, and
    /// alpha written only when translucent.
    public var description: String {
        ColorStringFormatter.describe("hsb", [ColorStringFormatter.degrees(hue), ColorStringFormatter.percent(saturation), ColorStringFormatter.percent(brightness)], alpha: alpha)
    }

    public func toRGBAColor() -> RGBAColor {
        guard saturation != 0 else {
            return RGBAColor(red: brightness, green: brightness, blue: brightness, alpha: alpha)
        }
        let sections = 6
        let sector = hue.rawValue * Double(sections)
        let i = Int(sector)
        let f = sector - Double(i)

        let p = brightness * (1 - saturation)
        let q = brightness * (1 - saturation * f)
        let t = brightness * (1 - saturation * (1 - f))

        let red, green, blue: Double
        switch i % sections {
        case 0:
            red = brightness
            green = t
            blue = p
        case 1:
            red = q
            green = brightness
            blue = p
        case 2:
            red = p
            green = brightness
            blue = t
        case 3:
            red = p
            green = q
            blue = brightness
        case 4:
            red = t
            green = p
            blue = brightness
        default:
            red = brightness
            green = p
            blue = q
        }
        return RGBAColor(
            red: red,
            green: green,
            blue: blue,
            alpha: alpha
        )
    }

    public func toHSBAColor() -> HSBAColor {
        self
    }

    public func toHSLAColor() -> HSLAColor {
        let lightness = brightness * (1 - saturation / 2)
        guard (0...1).contains(lightness) else {
            // Out of range lightness flips the hue, see `RGBAColor.toHSLAColor()`
            return toRGBAColor().toHSLAColor()
        }
        let denominator = min(lightness, 1 - lightness)
        return HSLAColor(
            hue: hue,
            saturation: denominator <= 0 ? 0 : (brightness - lightness) / denominator,
            lightness: lightness,
            alpha: alpha
        )
    }
}
