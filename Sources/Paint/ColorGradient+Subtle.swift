//
// Copyright (c) Nathan Tannar
//

import Foundation

extension ColorGradient {

    /// A subtle gradient around one color, for fills such as buttons, cards and app
    /// icons, that look flat with a solid color.
    ///
    /// The gradient goes from a slightly lighter version of the color, warmed
    /// towards ``TonalScale/warmHue``, to a slightly darker version, cooled towards
    /// ``TonalScale/coolHue``, like light falling on it from above. The color itself
    /// is in the middle, so the fill reads as the same color:
    ///
    /// ```swift
    /// RoundedRectangle(cornerRadius: 12)
    ///     .fill(LinearGradient(
    ///         gradient: ColorGradient.subtle(accent).toGradient(),
    ///         startPoint: .top,
    ///         endPoint: .bottom
    ///     ))
    /// ```
    ///
    /// `lightness` is the change in OKLCH lightness at each end, and `hueShift` how
    /// far each end's hue turns, never past the warm or cool hue. The ends are fitted
    /// to `gamut`, and the gradient is interpolated in Oklab.
    public static func subtle<C: ColorConvertible>(
        _ color: C,
        lightness: Double = 0.05,
        hueShift: ColorHue = .degrees(8),
        in gamut: ColorGamut = .displayP3
    ) -> ColorGradient {
        let base = color.toOKLCHColor()
        func end(lightness change: Double, towards target: ColorHue) -> OKLCHColor {
            var color = base
            color.lightness = (base.lightness + change).clamped(to: 0...1)
            // Grays have no hue to turn
            if base.chroma > 1e-4 {
                let delta = HueInterpolation.shorter.delta(from: base.hue.degrees, to: target.degrees)
                let rotation = min(abs(delta), abs(hueShift.degrees))
                color.hue = base.hue + .degrees(delta < 0 ? -rotation : rotation)
            }
            return color.toColorGamut(gamut)
        }
        return ColorGradient(
            colors: [
                end(lightness: lightness, towards: TonalScale.warmHue),
                base.toColorGamut(gamut),
                end(lightness: -lightness, towards: TonalScale.coolHue),
            ],
            in: .oklab
        )
    }
}
