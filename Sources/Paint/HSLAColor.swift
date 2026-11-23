//
// Copyright (c) Nathan Tannar
//

import Foundation

/// A color as hue, saturation and lightness components of the sRGB color space.
///
/// Saturation, lightness and alpha are in `0...1` for sRGB colors. Colors outside
/// sRGB can have components outside `0...1`. Where lightness is outside `0...1`,
/// saturation stays positive and the hue is rotated by 180° instead, as in CSS Color 4.
@frozen
public struct HSLAColor: Hashable, Sendable, BitwiseCopyable, Codable, CustomStringConvertible, ColorConvertible {

    /// The hue angle.
    public var hue: ColorHue
    /// Saturation, from `0` (gray) to `1` (fully saturated).
    public var saturation: Double
    /// Lightness, from `0` (black) through `0.5` (the pure hue) to `1` (white).
    public var lightness: Double
    /// Opacity, from `0` (transparent) to `1` (opaque).
    public var alpha: Double

    /// Creates a color from hue, saturation and lightness components.
    @inlinable
    public init(
        hue: ColorHue,
        saturation: Double,
        lightness: Double,
        alpha: Double = 1
    ) {
        self.hue = hue
        self.saturation = saturation
        self.lightness = lightness
        self.alpha = alpha
    }

    /// Converts a color from gamma encoded sRGB components.
    @inlinable
    public init(_ rgba: RGBAColor) {
        self = rgba.toHSLAColor()
    }

    /// Converts from HSB directly, preserving the hue.
    @inlinable
    public init(_ hsba: HSBAColor) {
        self = hsba.toHSLAColor()
    }

    /// The components like `"hsl(211.32 100% 50%)"`, with the hue in degrees, and
    /// alpha written only when translucent.
    public var description: String {
        ColorStringFormatter.describe("hsl", [ColorStringFormatter.degrees(hue), ColorStringFormatter.percent(saturation), ColorStringFormatter.percent(lightness)], alpha: alpha)
    }

    public func toRGBAColor() -> RGBAColor {
        let chroma = (1 - abs(2 * lightness - 1)) * saturation
        let sector = hue.rawValue * 6
        let x = chroma * (1 - abs(sector.truncatingRemainder(dividingBy: 2) - 1))
        let match = lightness - chroma / 2

        let (red, green, blue): (Double, Double, Double) = switch Int(sector) % 6 {
        case 0: (chroma, x, 0)
        case 1: (x, chroma, 0)
        case 2: (0, chroma, x)
        case 3: (0, x, chroma)
        case 4: (x, 0, chroma)
        default: (chroma, 0, x)
        }
        return RGBAColor(red: red + match, green: green + match, blue: blue + match, alpha: alpha)
    }

    public func toHSLAColor() -> HSLAColor {
        self
    }

    public func toHSBAColor() -> HSBAColor {
        guard (0...1).contains(lightness) else {
            // Out of range lightness stores its saturation with the opposite hue
            return toRGBAColor().toHSBAColor()
        }
        let brightness = lightness + saturation * min(lightness, 1 - lightness)
        return HSBAColor(
            hue: hue,
            saturation: brightness <= 0 ? 0 : 2 * (1 - lightness / brightness),
            brightness: brightness,
            alpha: alpha
        )
    }
}
