//
// Copyright (c) Nathan Tannar
//

import Foundation

extension ColorConvertible {

    /// A shadow color for content on this color, used as a background: a darker,
    /// translucent version of it, rather than black.
    ///
    /// Shadows in the real world take on the color of the surface they fall on, so a
    /// black shadow on a colored background looks gray and dirty. This keeps the hue
    /// of the background, and a little more of its chroma than its darkened lightness
    /// would, so the shadow looks rich instead:
    ///
    /// ```swift
    /// Card()
    ///     .shadow(color: background.shadow().toColor(), radius: 12, y: 6)
    /// ```
    ///
    /// `opacity` is the alpha of the result. Shadows are hard to see on dark
    /// backgrounds; use ``elevated(level:in:)`` to show elevation there instead.
    public func shadow(
        opacity: Double = 0.25,
        in gamut: ColorGamut = .displayP3
    ) -> OKLCHColor {
        let background = toOKLCHColor()
        var shadow = background
        shadow.lightness = min(max(background.lightness, 0) * 0.3, 0.25)
        // Darkening a color in OKLCH keeps its chroma, which looks less saturated as it
        // gets darker; boost it a little to keep the shadow rich
        shadow.chroma = max(background.chroma, 0) * 1.25
        shadow.alpha = opacity.clamped(to: 0...1)
        return shadow.toColorGamut(gamut)
    }

    /// The color of a surface raised by an elevation `level`, when this is the color of
    /// the surface at rest.
    ///
    /// On dark backgrounds, shadows are hard to see, so raised surfaces are shown by
    /// being lighter instead, as in the dark appearances of iOS and Material Design.
    /// The surface is mixed with white in Oklab by about 5%, 8%, 11%, 12% and 14% for
    /// levels `1` to `5`. Levels are clamped to `0...5`, and level `0` is the surface
    /// unchanged.
    ///
    /// Light backgrounds are returned unchanged, since shadows show their elevation.
    /// Use ``elevated(level:tint:in:)`` to tint raised surfaces in both appearances.
    public func elevated(
        level: Int,
        in gamut: ColorGamut = .displayP3
    ) -> OKLCHColor {
        let surface = toOKLCHColor()
        guard surface.contrast(.apca).isDark else {
            return surface
        }
        return surface.mixed(with: OKLCHColor(lightness: 1, chroma: 0, hue: 0, alpha: surface.alpha), by: Self.elevationAmount(level)).toColorGamut(gamut)
    }

    /// The color of a surface raised by an elevation `level`, tinted towards a color
    /// such as an accent, like the tonal elevation of Material Design.
    ///
    /// The surface is mixed with `tint` in Oklab by about 5%, 8%, 11%, 12% and 14% for
    /// levels `1` to `5`, in both light and dark appearances, so raised surfaces take
    /// on a hint of the tint. Levels are clamped to `0...5`, and level `0` is the
    /// surface unchanged. The alpha of the surface is kept.
    public func elevated<Tint: ColorConvertible>(
        level: Int,
        tint: Tint,
        in gamut: ColorGamut = .displayP3
    ) -> OKLCHColor {
        let surface = toOKLCHColor()
        var tint = tint.toOKLCHColor()
        tint.alpha = surface.alpha
        return surface.mixed(with: tint, by: Self.elevationAmount(level)).toColorGamut(gamut)
    }

    /// How much a surface is mixed with white or a tint at an elevation level.
    static func elevationAmount(_ level: Int) -> Double {
        let amounts = [0, 0.05, 0.08, 0.11, 0.12, 0.14]
        return amounts[min(max(level, 0), amounts.count - 1)]
    }
}
