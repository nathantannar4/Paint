//
// Copyright (c) Nathan Tannar
//

import Foundation

/// A color harmony: a set of hues at fixed angles around the color wheel.
///
/// Harmonies are generated in OKLCH, so the colors keep the lightness and chroma of
/// the base color and look equally light and colorful. OKLCH hue angles are
/// perceptual, so the complement of a color is the hue that looks opposite, which
/// differs from the HSL complement.
///
/// Encodes as its case name, such as `"triadic"`.
@frozen
public enum ColorHarmony: String, Hashable, Sendable, Codable, CaseIterable, CustomStringConvertible {

    /// The base color and the opposite hue: `0°` and `180°`.
    case complementary

    /// The base color and its neighbors: `-30°`, `0°` and `30°`.
    case analogous

    /// Three evenly spaced hues: `0°`, `120°` and `240°`.
    case triadic

    /// The base color and the two neighbors of its complement: `0°`, `150°` and `210°`.
    case splitComplementary

    /// Two complementary pairs forming a rectangle: `0°`, `60°`, `180°` and `240°`.
    case tetradic

    /// Four evenly spaced hues: `0°`, `90°`, `180°` and `270°`.
    case square

    /// The hue rotations from the base color, starting with the base color itself
    /// where the harmony includes it.
    public var hueRotations: [ColorHue] {
        let degrees: [Double] = switch self {
        case .complementary: [0, 180]
        case .analogous: [0, -30, 30]
        case .triadic: [0, 120, 240]
        case .splitComplementary: [0, 150, 210]
        case .tetradic: [0, 60, 180, 240]
        case .square: [0, 90, 180, 270]
        }
        return degrees.map { .degrees($0) }
    }

    /// The raw value, such as `"splitComplementary"`.
    public var description: String {
        rawValue
    }
}

extension ColorConvertible {

    /// The colors of a harmony, starting with this color.
    ///
    /// Each color keeps the lightness, chroma and alpha of this color, fitted to
    /// `gamut`. The first color is this color, also fitted.
    public func harmony(
        _ harmony: ColorHarmony,
        in gamut: ColorGamut = .displayP3
    ) -> [OKLCHColor] {
        let oklch = toOKLCHColor()
        return harmony.hueRotations.map { rotation in
            var color = oklch
            color.hue = oklch.hue + rotation
            return color.toColorGamut(gamut)
        }
    }

    /// The complementary color: the opposite OKLCH hue, with the same lightness and
    /// chroma, fitted to `gamut`.
    public func complement(in gamut: ColorGamut = .displayP3) -> OKLCHColor {
        hueRotated(by: .degrees(180), in: gamut)
    }
}
