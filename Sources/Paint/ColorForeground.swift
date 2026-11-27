//
// Copyright (c) Nathan Tannar
//

import Foundation

extension ColorContrast {

    /// Chooses a color for text on this color, used as a background, from candidates
    /// in order of preference.
    ///
    /// With a `minimum`, the first candidate whose contrast meets it is returned, so
    /// list the colors you'd most like to use first, such as a brand color before
    /// black and white:
    ///
    /// ```swift
    /// let text = background.contrast(.apca).preferredForeground(
    ///     among: [accent, .white, .black],
    ///     minimum: 60
    /// )
    /// ```
    ///
    /// Without a `minimum`, or when no candidate meets it, the candidate with the most
    /// contrast is returned, the first one on a tie. Returns `nil` only when
    /// `candidates` is empty. Alpha is ignored.
    public func preferredForeground<C: ColorConvertible>(
        among candidates: [C],
        minimum: Metric? = nil
    ) -> C? {
        let background = color
        let measured = candidates.map { (candidate: $0, contrast: Metric(text: $0, background: background)) }
        if let minimum, let first = measured.first(where: { $0.contrast.meets(minimum) }) {
            return first.candidate
        }
        var best: (candidate: C, contrast: Metric)?
        for element in measured where best == nil || best!.contrast < element.contrast {
            best = element
        }
        return best?.candidate
    }

    /// A color for text on this color, used as a background, that has the background's
    /// hue rather than being pure black or white.
    ///
    /// Tinted text looks like it belongs to its background, such as dark blue text on
    /// a light blue badge, where black text looks harsh. The text is on whichever side
    /// of the background, lighter or darker, has more contrast, keeps the hue of the
    /// background with a little of its chroma, and has its lightness adjusted as in
    /// ``adjusted(toMinimum:against:in:)`` until its contrast meets `minimum`. Where
    /// that much contrast isn't possible, the result has as much as it can.
    ///
    /// Grays give gray text. Alpha is ignored and the result is opaque.
    public func tintedForeground(
        minimum: Metric,
        in gamut: ColorGamut = .displayP3
    ) -> RGBAColor {
        let background = color.toOKLCHColor()
        var text = background
        text.alpha = 1
        // A hint of the background's chroma, so the text reads as a tint, not a color
        text.chroma = min(background.chroma * 0.6, 0.06)
        // Start near the far end on the side with more contrast, then move towards the
        // background as far as the minimum allows, so the text is as tinted as it can be
        text.lightness = isDark ? 0.99 : 0.12
        let start = text.toColorGamut(gamut).toRGBAColor()
        let backgroundRGBA = color
        guard Metric(text: start, background: backgroundRGBA).meets(minimum) else {
            return start.contrast(algorithm).adjusted(toMinimum: minimum, against: backgroundRGBA, in: gamut)
        }
        // Contrast falls monotonically from the start towards the background lightness
        var passing = text.lightness
        var failing = background.lightness.clamped(to: 0...1)
        func candidate(_ lightness: Double) -> RGBAColor {
            var color = text
            color.lightness = lightness
            return color.toColorGamut(gamut).toRGBAColor()
        }
        for _ in 0..<32 where abs(passing - failing) > 1e-6 {
            let mid = (passing + failing) / 2
            if Metric(text: candidate(mid), background: backgroundRGBA).meets(minimum) {
                passing = mid
            } else {
                failing = mid
            }
        }
        // Move a little further from the background, so the result doesn't sit on the
        // edge of the minimum, where rounding could make it fail
        let margin = (text.lightness - passing) * 0.25
        return candidate(passing + margin)
    }

    private var algorithm: ContrastAlgorithm<Metric> {
        ContrastAlgorithm()
    }
}
