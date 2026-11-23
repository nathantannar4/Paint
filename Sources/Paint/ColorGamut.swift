//
// Copyright (c) Nathan Tannar
//

import Foundation
import simd

/// The range of colors a display can show, used to fit generated colors so they
/// display as intended.
///
/// Encodes as its case name, such as `"displayP3"`.
@frozen
public enum ColorGamut: String, Hashable, Sendable, Codable, CustomStringConvertible {

    /// The sRGB gamut, which every display can show, and the gamut of ``HEXColor``.
    case sRGB

    /// The Display P3 gamut of most Apple displays, about 25% larger than sRGB.
    ///
    /// Displays that can't show it, such as many external monitors, clip it to sRGB.
    case displayP3

    /// The ITU-R BT.2020 gamut of HDR video, much larger than Display P3.
    ///
    /// No current display shows all of it, so colors in it but outside Display P3
    /// are clipped by the display.
    case rec2020

    /// Whether the color is inside the gamut. Alpha is ignored.
    public func contains<C: ColorConvertible>(_ color: C) -> Bool {
        contains(color.toRGBAColor())
    }

    /// Whether gamma encoded, extended sRGB components are inside the gamut.
    public func contains(_ rgba: RGBAColor) -> Bool {
        switch self {
        case .sRGB:
            let range = -1e-6...(1 + 1e-6)
            return range.contains(rgba.red) && range.contains(rgba.green) && range.contains(rgba.blue)
        case .displayP3:
            // Core Graphics converts Display P3 at `Float` precision, with slightly
            // different primaries, so its colors can be ~3e-5 outside this matrix's gamut.
            // 1e-4 in linear light is less than half an 8-bit step.
            let range = -1e-4...(1 + 1e-4)
            // Display P3 shares the sRGB transfer function and white point, so the
            // gamuts can be compared in linear light, where `0...1` maps onto `0...1`
            let red = RGBAColor.linearize(rgba.red)
            let green = RGBAColor.linearize(rgba.green)
            let blue = RGBAColor.linearize(rgba.blue)
            return range.contains(0.8224621 * red + 0.1775380 * green)
                && range.contains(0.0331941 * red + 0.9668058 * green)
                && range.contains(0.0170827 * red + 0.0723974 * green + 0.9105199 * blue)
        case .rec2020:
            let range = -1e-4...(1 + 1e-4)
            let linear = ColorSpaceMatrix.linearSRGBToLinearRec2020 * rgba.toLinearComponents()
            return range.contains(linear.x) && range.contains(linear.y) && range.contains(linear.z)
        }
    }

    /// The name of the gamut, such as `"Display P3"`, matching
    /// ``ColorSpace/description``.
    public var description: String {
        switch self {
        case .sRGB: "sRGB"
        case .displayP3: "Display P3"
        case .rec2020: "Rec. 2020"
        }
    }
}

// MARK: - Gamut mapping

extension ColorConvertible {

    /// Fits the color in a gamut through ``RGBAColor/toColorGamut(_:)``, returning it
    /// unchanged when it's already in the gamut, so components such as the hue of
    /// grays are kept.
    fileprivate func toColorGamut(
        _ gamut: ColorGamut,
        through makeColor: (RGBAColor) -> Self
    ) -> Self {
        let rgba = toRGBAColor()
        guard !gamut.contains(rgba) else { return self }
        return makeColor(rgba.toColorGamut(gamut))
    }
}

extension OKLCHColor {

    /// Fits the color in a gamut by reducing its chroma, keeping its lightness and
    /// hue, as in CSS Color 4 gamut mapping.
    ///
    /// Lightness is first clamped to `0...1`, since no chroma fits outside that
    /// range. Non-finite colors are returned unchanged.
    public func toColorGamut(_ gamut: ColorGamut) -> OKLCHColor {
        guard lightness.isFinite, chroma.isFinite else { return self }
        var result = self
        result.lightness = min(max(lightness, 0), 1)
        guard !gamut.contains(result.toRGBAColor()) else { return result }
        var low = 0.0
        var high = result.chroma
        // Each step halves the interval, so 24 steps reach well below 8-bit precision
        for _ in 0..<24 {
            result.chroma = (low + high) / 2
            if gamut.contains(result.toRGBAColor()) {
                low = result.chroma
            } else {
                high = result.chroma
            }
        }
        result.chroma = low
        return result
    }
}

extension RGBAColor {

    /// Fits the color in a gamut by reducing its OKLCH chroma, keeping its lightness
    /// and hue, as in CSS Color 4 gamut mapping.
    ///
    /// Colors already in the gamut, and non-finite colors, are returned unchanged.
    public func toColorGamut(_ gamut: ColorGamut) -> RGBAColor {
        guard red.isFinite, green.isFinite, blue.isFinite, !gamut.contains(self) else {
            return self
        }
        return OKLCHColor(self).toColorGamut(gamut).toRGBAColor()
    }
}

extension HSBAColor {
    public func toColorGamut(_ gamut: ColorGamut) -> HSBAColor {
        toColorGamut(gamut, through: HSBAColor.init)
    }
}

extension HSLAColor {
    public func toColorGamut(_ gamut: ColorGamut) -> HSLAColor {
        toColorGamut(gamut, through: HSLAColor.init)
    }
}

extension HWBColor {
    public func toColorGamut(_ gamut: ColorGamut) -> HWBColor {
        toColorGamut(gamut, through: HWBColor.init)
    }
}

extension OKLabColor {
    public func toColorGamut(_ gamut: ColorGamut) -> OKLabColor {
        toColorGamut(gamut, through: OKLabColor.init)
    }
}

extension XYZColor {
    public func toColorGamut(_ gamut: ColorGamut) -> XYZColor {
        toColorGamut(gamut, through: XYZColor.init)
    }
}

extension CIELabColor {
    public func toColorGamut(_ gamut: ColorGamut) -> CIELabColor {
        toColorGamut(gamut, through: CIELabColor.init)
    }
}

extension CIELCHColor {
    public func toColorGamut(_ gamut: ColorGamut) -> CIELCHColor {
        toColorGamut(gamut, through: CIELCHColor.init)
    }
}

extension HEXColor {

    /// Returns the color unchanged, since every ``HEXColor`` is in sRGB, the
    /// smallest gamut.
    public func toColorGamut(_ gamut: ColorGamut) -> HEXColor {
        self
    }
}

extension CMYKColor {

    /// Returns the color unchanged, since every ``CMYKColor`` is in sRGB, the
    /// smallest gamut.
    public func toColorGamut(_ gamut: ColorGamut) -> CMYKColor {
        self
    }
}
