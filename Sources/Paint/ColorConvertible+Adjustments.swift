//
// Copyright (c) Nathan Tannar
//

import Foundation

extension ColorConvertible {

    /// Returns the color with its OKLCH lightness increased by `amount`, clamped to `0...1`.
    ///
    /// Unlike HSB brightness, OKLCH lightness changes how light the color looks without
    /// shifting its hue. The hue is kept, and chroma is reduced where very light or
    /// dark results of saturated colors don't fit in `gamut`.
    public func lightened(
        by amount: Double,
        in gamut: ColorGamut = .displayP3
    ) -> OKLCHColor {
        var oklch = toOKLCHColor()
        oklch.lightness = min(max(oklch.lightness + amount, 0), 1)
        return oklch.toColorGamut(gamut)
    }

    /// Returns the color with its OKLCH lightness decreased by `amount`, clamped to `0...1`.
    ///
    /// See ``lightened(by:in:)``.
    public func darkened(
        by amount: Double,
        in gamut: ColorGamut = .displayP3
    ) -> OKLCHColor {
        lightened(by: -amount, in: gamut)
    }

    /// Mixes the color with another in Oklab, like CSS `color-mix(in oklab, ...)`.
    ///
    /// An `amount` of `0` is this color and `1` is `other`. Mixing in Oklab keeps
    /// the midpoint as light and colorful as the ends, avoiding the dark, gray
    /// midpoints of mixing sRGB components. Alpha is premultiplied, so mixing with a
    /// transparent color fades without shifting the color.
    public func mixed<
        Other: ColorConvertible
    >(
        with other: Other,
        by amount: Double
    ) -> OKLCHColor {
        let lhs = toOKLCHColor()
        let rhs = other.toOKLCHColor()
        func mix(_ lhs: Double, _ rhs: Double) -> Double {
            lhs + (rhs - lhs) * amount
        }
        let alpha = mix(lhs.alpha, rhs.alpha)
        guard alpha != 0 else {
            return OKLCHColor(lightness: mix(lhs.lightness, rhs.lightness), a: mix(lhs.a, rhs.a), b: mix(lhs.b, rhs.b), alpha: 0)
        }
        func premultipliedMix(_ lhsValue: Double, _ rhsValue: Double) -> Double {
            mix(lhsValue * lhs.alpha, rhsValue * rhs.alpha) / alpha
        }
        return OKLCHColor(
            lightness: premultipliedMix(lhs.lightness, rhs.lightness),
            a: premultipliedMix(lhs.a, rhs.a),
            b: premultipliedMix(lhs.b, rhs.b),
            alpha: alpha
        )
    }

    /// The color of a disabled control on `background`: mostly desaturated, then
    /// mixed halfway towards the background in Oklab.
    ///
    /// Removing most of the chroma reads as inactive, while a hint of the hue keeps
    /// it related to the enabled color. Mixing towards the background lowers the
    /// contrast evenly, so the result works in light and dark appearances when
    /// given the matching background. Unlike lowering opacity, the result doesn't
    /// let overlapping content show through.
    ///
    /// The background is treated as opaque, and the alpha of the color is kept.
    public func disabled<
        Background: ColorConvertible
    >(
        against background: Background
    ) -> OKLCHColor {
        var oklch = toOKLCHColor()
        oklch.chroma *= 0.2
        var background = background.toOKLCHColor()
        background.alpha = oklch.alpha
        return oklch.mixed(with: background, by: 0.5)
    }

    // MARK: Chroma and Hue

    /// Returns the color with its OKLCH chroma increased by `amount`, fitted to `gamut`.
    ///
    /// Unlike HSL saturation, OKLCH chroma changes how colorful the color looks
    /// without changing how light it looks. sRGB colors have a chroma up to about
    /// `0.32`, so an `amount` of `0.05` is a clear change. Grays have no hue, so
    /// saturating them gives a red tint; saturate colors that have a hue.
    public func saturated(
        by amount: Double,
        in gamut: ColorGamut = .displayP3
    ) -> OKLCHColor {
        var oklch = toOKLCHColor()
        oklch.chroma = max(oklch.chroma + amount, 0)
        return oklch.toColorGamut(gamut)
    }

    /// Returns the color with its OKLCH chroma decreased by `amount`, down to `0`.
    ///
    /// See ``saturated(by:in:)``.
    public func desaturated(
        by amount: Double,
        in gamut: ColorGamut = .displayP3
    ) -> OKLCHColor {
        saturated(by: -amount, in: gamut)
    }

    /// Returns the color with its OKLCH hue rotated, keeping its lightness and chroma
    /// and fitting it to `gamut`.
    public func hueRotated(
        by rotation: ColorHue,
        in gamut: ColorGamut = .displayP3
    ) -> OKLCHColor {
        var oklch = toOKLCHColor()
        oklch.hue = oklch.hue + rotation
        return oklch.toColorGamut(gamut)
    }

    /// Returns the gray with the same OKLCH lightness as the color, so it looks as
    /// light as the color. Alpha is kept.
    ///
    /// Unlike ``ColorTransform/grayscale(_:)``, which uses luminance, perceptual
    /// lightness keeps saturated blues from turning almost black.
    public func grayscale() -> OKLCHColor {
        var oklch = toOKLCHColor()
        oklch.chroma = 0
        oklch.hue = 0
        return oklch
    }

    /// Returns the color with its sRGB components inverted, like the CSS `invert()`
    /// filter. Alpha is kept.
    public func inverted() -> RGBAColor {
        let rgba = toRGBAColor()
        return RGBAColor(red: 1 - rgba.red, green: 1 - rgba.green, blue: 1 - rgba.blue, alpha: rgba.alpha)
    }

    /// Whether the color is almost white: an OKLCH lightness of at least `0.96` and
    /// chroma of at most `0.02`.
    ///
    /// This includes off-whites such as `#F5F5F5` and `#F2F2F7` and the faintest tints
    /// such as `#F0F8FF`, but not light grays such as `#EEEEEE` or visible tints such as
    /// cream (`#FFF8E1`). Lightness and chroma are perceptual, so the thresholds behave
    /// the same for every hue. Alpha is ignored.
    public var isNearWhite: Bool {
        let oklch = toOKLCHColor()
        return oklch.lightness >= 0.96 && oklch.chroma <= 0.02
    }

    // MARK: Appearance Variants

    /// Returns a version of the color for another background, such as a dark mode
    /// version of a light mode color, with the same APCA contrast it has on its
    /// original background.
    ///
    /// The hue and chroma are kept, as far as `gamut` allows, so the result is
    /// recognizably the same color. The lightness is chosen on the other side of
    /// `newBackground` from the original, so dark text on a light background becomes
    /// light text on a dark one:
    ///
    /// ```swift
    /// let dark = accent.adapted(from: HEXColor("#FFFFFF"), to: HEXColor("#1C1C1E"))
    /// ```
    ///
    /// If the contrast can't be reached, the result has as much as it can.
    public func adapted<
        From: ColorConvertible,
        To: ColorConvertible
    >(
        from background: From,
        to newBackground: To,
        in gamut: ColorGamut = .displayP3
    ) -> RGBAColor {
        let rgba = toRGBAColor()
        let target = rgba.contrast(.apca).against(background).magnitude
        let newBackground = newBackground.toRGBAColor()
        let oklch = rgba.toOKLCHColor()
        func candidate(lightness: Double) -> RGBAColor {
            var color = oklch
            color.lightness = lightness
            let rgba = color.toColorGamut(gamut).toRGBAColor()
            return gamut == .sRGB ? rgba.clamped() : rgba
        }
        func contrast(lightness: Double) -> Double {
            candidate(lightness: lightness).contrast(.apca).against(newBackground).magnitude
        }
        // Prefer the side that is lighter on dark backgrounds and darker on light ones,
        // matching the flip in polarity between appearances
        let backgroundLightness = newBackground.toOKLCHColor().lightness.clamped(to: 0...1)
        let limit: Double = newBackground.contrast(.apca).isDark ? 1 : 0
        guard contrast(lightness: limit) > target else {
            return candidate(lightness: limit)
        }
        // Contrast grows monotonically from the background lightness towards the limit
        var low = backgroundLightness
        var high = limit
        for _ in 0..<32 where abs(high - low) > 1e-6 {
            let mid = (low + high) / 2
            if contrast(lightness: mid) >= target {
                high = mid
            } else {
                low = mid
            }
        }
        var result = candidate(lightness: high)
        result.alpha = rgba.alpha
        return result
    }
}
