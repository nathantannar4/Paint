//
// Copyright (c) Nathan Tannar
//

import Foundation

/// A scale of lighter and darker shades of a seed color, like the `50` to `950`
/// steps of Tailwind CSS, generated in OKLCH.
///
/// Every step keeps the hue of the seed. Lightness falls evenly from near white at
/// `50` to near black at `950`, so the same step of different hues has about the
/// same lightness, and contrast. Chroma peaks around `500` to `600` and tapers
/// towards the light and dark ends, where saturated colors look garish or don't fit
/// the gamut. Each color is fitted to ``gamut``.
///
/// ```swift
/// let blue = TonalScale(seed: HEXColor("#3B82F6"))
/// let background = blue[50]
/// let text = blue[900]
/// ```
@frozen
public struct TonalScale: Hashable, Sendable, Codable {

    /// The color the scale is generated from. Its lightness doesn't affect the scale.
    public var seed: OKLCHColor

    /// The gamut every color of the scale is fitted to.
    public var gamut: ColorGamut

    /// The standard steps: `50`, `100`, `200`, ... `900` and `950`.
    public static let steps = [50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 950]

    /// Creates a scale from a seed color, fitted to a gamut.
    @inlinable
    public init<C: ColorConvertible>(
        seed: C,
        in gamut: ColorGamut = .displayP3
    ) {
        self.seed = seed.toOKLCHColor()
        self.gamut = gamut
    }

    /// The OKLCH lightness and the fraction of the seed's chroma at each anchor step.
    private static let anchors: [(step: Double, lightness: Double, chroma: Double)] = [
        (0, 1, 0),
        (50, 0.975, 0.12),
        (100, 0.94, 0.25),
        (200, 0.885, 0.45),
        (300, 0.81, 0.7),
        (400, 0.715, 0.9),
        (500, 0.625, 1),
        (600, 0.545, 1),
        (700, 0.475, 0.9),
        (800, 0.405, 0.75),
        (900, 0.345, 0.6),
        (950, 0.27, 0.45),
        (1000, 0, 0),
    ]

    /// The color at a step, from `0` (white) to `1000` (black).
    ///
    /// Steps between the standard ones, such as `150`, are interpolated. Steps outside
    /// `0...1000` are clamped.
    public subscript(step: Int) -> OKLCHColor {
        color(at: Double(step))
    }

    /// The color at a step, from `0` (white) to `1000` (black), see ``subscript(_:)``.
    public func color(at step: Double) -> OKLCHColor {
        let step = step.isNaN ? 500 : min(max(step, 0), 1000)
        let anchors = Self.anchors
        let upper = anchors.firstIndex { $0.step >= step } ?? anchors.count - 1
        let lower = max(upper - 1, 0)
        let width = anchors[upper].step - anchors[lower].step
        let fraction = width > 0 ? (step - anchors[lower].step) / width : 0
        let lightness = anchors[lower].lightness + (anchors[upper].lightness - anchors[lower].lightness) * fraction
        let chroma = anchors[lower].chroma + (anchors[upper].chroma - anchors[lower].chroma) * fraction
        return OKLCHColor(
            lightness: lightness,
            chroma: seed.chroma * chroma,
            hue: seed.hue,
            alpha: seed.alpha
        ).toColorGamut(gamut)
    }

    /// The color at a tone, from `0` (black) to `100` (white), like Material Design's
    /// tonal palettes.
    ///
    /// The tone is the OKLCH lightness times `100`. Unlike the steps, the chroma of the
    /// seed is kept, reduced only where it doesn't fit ``gamut``.
    public func color(tone: Double) -> OKLCHColor {
        OKLCHColor(
            lightness: tone / 100,
            chroma: seed.chroma,
            hue: seed.hue,
            alpha: seed.alpha
        ).toColorGamut(gamut)
    }

    /// The colors at the standard ``steps``, from lightest to darkest.
    public var colors: [OKLCHColor] {
        Self.steps.map { self[$0] }
    }

    /// The standard step whose lightness is closest to the seed's, such as `500` for a
    /// mid-tone seed. Use it to place the seed itself in the scale.
    public var seedStep: Int {
        Self.steps.min {
            abs(color(at: Double($0)).lightness - seed.lightness) < abs(color(at: Double($1)).lightness - seed.lightness)
        } ?? 500
    }
}
