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
/// Painters shift hue as well as lightness: highlights warm towards yellow, and
/// shadows cool towards blue. Set ``hueShift`` to do the same, which makes a scale
/// look richer and less flat:
///
/// ```swift
/// let green = TonalScale(seed: HEXColor("#22C55E"), hueShift: .degrees(12))
/// ```
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

    /// How far the hue of the lightest and darkest steps turns, towards a warm yellow
    /// for the lightest and a cool blue for the darkest. `0` by default, so every
    /// step keeps the hue of the seed.
    ///
    /// The shift grows from nothing around step `550` to the full amount at `50` and
    /// `950`, and never turns past the warm or cool hue. Around `10` to `20` degrees
    /// is subtle. Only the steps are shifted, not ``color(tone:)``.
    public var hueShift: ColorHue

    /// The hue that light steps turn towards: a warm yellow.
    ///
    /// Hues turn the shorter way around the color wheel, so blues warm through cyan,
    /// and reds and purples through orange.
    public static let warmHue = ColorHue.degrees(95)

    /// The hue that dark steps turn towards: a cool blue.
    ///
    /// Hues turn the shorter way around the color wheel, so reds cool through
    /// purple, and yellows and greens through cyan.
    public static let coolHue = ColorHue.degrees(265)

    /// The standard steps: `50`, `100`, `200`, ... `900` and `950`.
    public static let steps = [50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 950]

    /// Creates a scale from a seed color, fitted to a gamut.
    @inlinable
    public init<C: ColorConvertible>(
        seed: C,
        hueShift: ColorHue = .zero,
        in gamut: ColorGamut = .displayP3
    ) {
        self.seed = seed.toOKLCHColor()
        self.gamut = gamut
        self.hueShift = hueShift
    }

    private enum CodingKeys: String, CodingKey {
        case seed
        case gamut
        case hueShift
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.seed = try container.decode(OKLCHColor.self, forKey: .seed)
        self.gamut = try container.decode(ColorGamut.self, forKey: .gamut)
        // Scales encoded before `hueShift` existed don't shift
        self.hueShift = try container.decodeIfPresent(ColorHue.self, forKey: .hueShift) ?? .zero
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(seed, forKey: .seed)
        try container.encode(gamut, forKey: .gamut)
        if hueShift != .zero {
            try container.encode(hueShift, forKey: .hueShift)
        }
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
            hue: hue(at: step),
            alpha: seed.alpha
        ).toColorGamut(gamut)
    }

    /// The hue at a step, turned towards ``warmHue`` or ``coolHue`` by ``hueShift``.
    private func hue(at step: Double) -> ColorHue {
        let shift = abs(hueShift.degrees.truncatingRemainder(dividingBy: 360))
        guard shift > 0 else { return seed.hue }
        let weight: Double
        let target: ColorHue
        if step < 550 {
            weight = min((550 - step) / 500, 1)
            target = Self.warmHue
        } else {
            weight = min((step - 550) / 400, 1)
            target = Self.coolHue
        }
        let delta = HueInterpolation.shorter.delta(from: seed.hue.degrees, to: target.degrees)
        let rotation = min(abs(delta), shift * weight)
        return seed.hue + .degrees(delta < 0 ? -rotation : rotation)
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
