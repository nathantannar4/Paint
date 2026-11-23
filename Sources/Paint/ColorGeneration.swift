//
// Copyright (c) Nathan Tannar
//

import Foundation

extension RGBAColor {

    /// A color derived from a string, such as a user name or tag, that's always the
    /// same for the same string, on every device and launch.
    ///
    /// The hue comes from a stable hash of the string, and the lightness and chroma
    /// are fixed, so every color works with the same text color.
    @inlinable
    public init(
        hashing string: String
    ) {
        self = OKLCHColor(hashing: string).toRGBAColor()
    }

    /// A random color with red, green and blue in the given ranges.
    ///
    /// Pass a seeded generator for reproducible colors.
    public static func random<G: RandomNumberGenerator>(
        red: ClosedRange<Double> = 0...1,
        green: ClosedRange<Double> = 0...1,
        blue: ClosedRange<Double> = 0...1,
        using generator: inout G
    ) -> RGBAColor {
        RGBAColor(
            red: Double.random(in: red, using: &generator),
            green: Double.random(in: green, using: &generator),
            blue: Double.random(in: blue, using: &generator)
        )
    }

    /// A random color with red, green and blue in the given ranges.
    public static func random(
        red: ClosedRange<Double> = 0...1,
        green: ClosedRange<Double> = 0...1,
        blue: ClosedRange<Double> = 0...1
    ) -> RGBAColor {
        var generator = SystemRandomNumberGenerator()
        return random(red: red, green: green, blue: blue, using: &generator)
    }
}

extension OKLCHColor {

    /// Distinct colors for categories, such as the series of a chart.
    ///
    /// The colors share a lightness and chroma, so none stands out, and their hues are
    /// spaced by the golden angle from `startHue`, so any prefix of the colors is
    /// spread around the color wheel: adding a category doesn't change the colors of
    /// the others. Colors are fitted to `gamut`.
    ///
    /// Hues become hard to tell apart beyond about 8 to 10 categories. Beyond that,
    /// vary lightness too, or use another channel such as shape.
    public static func categorical(
        count: Int,
        lightness: Double = 0.7,
        chroma: Double = 0.15,
        startHue: ColorHue = .degrees(30),
        in gamut: ColorGamut = .displayP3
    ) -> [OKLCHColor] {
        guard count > 0 else { return [] }
        return (0..<count).map { index in
            OKLCHColor(
                lightness: lightness,
                chroma: chroma,
                hue: startHue + ColorHue(rawValue: ColorHue.goldenAngle.rawValue * Double(index))
            ).toColorGamut(gamut)
        }
    }

    /// A color derived from a string, such as a user name or tag, that's always the
    /// same for the same string, on every device and launch.
    ///
    /// The hue comes from a stable hash of the string, and the lightness and chroma
    /// are fixed, so every color works with the same text color: with the default
    /// lightness of `0.7`, black text has good contrast. Fitted to `gamut`.
    @inlinable
    public init(
        hashing string: String,
        lightness: Double = 0.7,
        chroma: Double = 0.12,
        alpha: Double = 1,
        in gamut: ColorGamut = .sRGB
    ) {
        // FNV-1a, since `Hasher` is randomly seeded per launch
        var hash: UInt64 = 0xCBF29CE484222325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001B3
        }
        // Mix the high bits down, since FNV-1a's low bits are weak for short strings
        hash ^= hash >> 33
        hash = hash &* 0xFF51AFD7ED558CCD
        hash ^= hash >> 33
        let hue = ColorHue(rawValue: Double(hash >> 11) * 0x1p-53)
        self = OKLCHColor(lightness: lightness, chroma: chroma, hue: hue, alpha: alpha).toColorGamut(gamut)
    }

    /// A random color with lightness, chroma and hue in the given ranges, fitted to `gamut`.
    ///
    /// Pass a seeded generator for reproducible colors. `hue` is in degrees.
    public static func random<G: RandomNumberGenerator>(
        lightness: ClosedRange<Double> = 0.5...0.8,
        chroma: ClosedRange<Double> = 0.08...0.2,
        hue: ClosedRange<Double> = 0...360,
        in gamut: ColorGamut = .displayP3,
        using generator: inout G
    ) -> OKLCHColor {
        OKLCHColor(
            lightness: Double.random(in: lightness, using: &generator),
            chroma: Double.random(in: chroma, using: &generator),
            hue: .degrees(Double.random(in: hue, using: &generator))
        ).toColorGamut(gamut)
    }

    /// A random color with lightness, chroma and hue in the given ranges, fitted to
    /// `gamut`. `hue` is in degrees.
    public static func random(
        lightness: ClosedRange<Double> = 0.5...0.8,
        chroma: ClosedRange<Double> = 0.08...0.2,
        hue: ClosedRange<Double> = 0...360,
        in gamut: ColorGamut = .displayP3
    ) -> OKLCHColor {
        var generator = SystemRandomNumberGenerator()
        return random(lightness: lightness, chroma: chroma, hue: hue, in: gamut, using: &generator)
    }
}
