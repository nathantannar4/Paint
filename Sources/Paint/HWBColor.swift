//
// Copyright (c) Nathan Tannar
//

import Foundation

/// A color as hue, whiteness and blackness components of the sRGB color space,
/// matching CSS `hwb()`.
///
/// Whiteness and blackness are the amounts of white and black mixed into the pure
/// hue, in `0...1`. When they add up to `1` or more, the color is a gray.
@frozen
public struct HWBColor: Hashable, Sendable, BitwiseCopyable, Codable, CustomStringConvertible, ColorConvertible {

    /// The hue angle.
    public var hue: ColorHue
    /// The amount of white mixed into the hue, in `0...1`.
    public var whiteness: Double
    /// The amount of black mixed into the hue, in `0...1`.
    public var blackness: Double
    /// Opacity, from `0` (transparent) to `1` (opaque).
    public var alpha: Double

    /// Creates a color from hue, whiteness and blackness components.
    @inlinable
    public init(
        hue: ColorHue,
        whiteness: Double,
        blackness: Double,
        alpha: Double = 1
    ) {
        self.hue = hue
        self.whiteness = whiteness
        self.blackness = blackness
        self.alpha = alpha
    }

    /// Converts a color from gamma encoded sRGB components.
    @inlinable
    public init(_ rgba: RGBAColor) {
        self.init(rgba.toHSBAColor())
    }

    /// Converts from HSB directly, preserving the hue.
    @inlinable
    public init(_ hsba: HSBAColor) {
        self.init(
            hue: hsba.hue,
            whiteness: (1 - hsba.saturation) * hsba.brightness,
            blackness: 1 - hsba.brightness,
            alpha: hsba.alpha
        )
    }

    public func toHSBAColor() -> HSBAColor {
        let sum = whiteness + blackness
        if sum >= 1 {
            let gray = sum > 0 ? whiteness / sum : 0
            return HSBAColor(hue: hue, saturation: 0, brightness: gray, alpha: alpha)
        }
        let brightness = 1 - blackness
        return HSBAColor(
            hue: hue,
            saturation: brightness <= 0 ? 0 : 1 - whiteness / brightness,
            brightness: brightness,
            alpha: alpha
        )
    }

    public func toRGBAColor() -> RGBAColor {
        toHSBAColor().toRGBAColor()
    }

    /// Converts to HSL through HSB, preserving the hue.
    public func toHSLAColor() -> HSLAColor {
        toHSBAColor().toHSLAColor()
    }

    public func toHWBColor() -> HWBColor {
        self
    }

    /// The components like `"hwb(211.32 0% 0%)"`, with the hue in degrees, and
    /// alpha written only when translucent.
    public var description: String {
        ColorStringFormatter.describe("hwb", [ColorStringFormatter.degrees(hue), ColorStringFormatter.percent(whiteness), ColorStringFormatter.percent(blackness)], alpha: alpha)
    }
}

/// A color as cyan, magenta, yellow and key (black) components, in `0...1`.
///
/// This is the naive conversion from sRGB, without an ICC profile, so it's suited
/// to design tools and interoperability, not to preparing colors for print.
@frozen
public struct CMYKColor: Hashable, Sendable, BitwiseCopyable, Codable, CustomStringConvertible, ColorConvertible {

    /// The amount of cyan ink, in `0...1`.
    public var cyan: Double
    /// The amount of magenta ink, in `0...1`.
    public var magenta: Double
    /// The amount of yellow ink, in `0...1`.
    public var yellow: Double
    /// The amount of black (key) ink, in `0...1`.
    public var black: Double
    /// Opacity, from `0` (transparent) to `1` (opaque).
    public var alpha: Double

    /// Creates a color from cyan, magenta, yellow and black components.
    @inlinable
    public init(
        cyan: Double,
        magenta: Double,
        yellow: Double,
        black: Double,
        alpha: Double = 1
    ) {
        self.cyan = cyan
        self.magenta = magenta
        self.yellow = yellow
        self.black = black
        self.alpha = alpha
    }

    /// Converts from sRGB, clamping colors outside sRGB.
    @inlinable
    public init(_ rgba: RGBAColor) {
        let rgba = rgba.toColorGamut(.sRGB)
        let red = rgba.red.clamped(to: 0...1)
        let green = rgba.green.clamped(to: 0...1)
        let blue = rgba.blue.clamped(to: 0...1)
        let black = 1 - max(red, green, blue)
        guard black < 1 else {
            self.init(cyan: 0, magenta: 0, yellow: 0, black: 1, alpha: rgba.alpha)
            return
        }
        self.init(
            cyan: (1 - red - black) / (1 - black),
            magenta: (1 - green - black) / (1 - black),
            yellow: (1 - blue - black) / (1 - black),
            black: black,
            alpha: rgba.alpha
        )
    }

    /// The components like `"device-cmyk(100% 52.2% 0% 0%)"`, the CSS notation for
    /// naive CMYK, with alpha written only when translucent.
    public var description: String {
        ColorStringFormatter.describe("device-cmyk", [ColorStringFormatter.percent(cyan), ColorStringFormatter.percent(magenta), ColorStringFormatter.percent(yellow), ColorStringFormatter.percent(black)], alpha: alpha)
    }

    public func toRGBAColor() -> RGBAColor {
        RGBAColor(
            red: (1 - cyan) * (1 - black),
            green: (1 - magenta) * (1 - black),
            blue: (1 - yellow) * (1 - black),
            alpha: alpha
        )
    }

    public func toCMYKColor() -> CMYKColor {
        self
    }
}
