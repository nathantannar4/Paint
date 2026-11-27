//
// Copyright (c) Nathan Tannar
//

import Foundation

extension ColorConvertible {

    /// A short English description of the color, such as `"dark grayish blue"`,
    /// `"light pink"` or `"brown"`, for VoiceOver labels and color pickers.
    ///
    /// The name is built from the color's OKLCH components, measured relative to the
    /// most colorful color of its hue, so a light yellow and a dark blue are both
    /// described by how they compare to pure yellow and blue:
    ///
    /// - A lightness: `"very light"`, `"light"`, `"dark"` or `"very dark"`, or none.
    /// - A colorfulness: `"grayish"` or `"muted"` for subdued colors, `"vivid"` for
    ///   colors more colorful than sRGB can show, or none.
    /// - A hue: `"pink"`, `"red"`, `"orange"`, `"brown"`, `"yellow"`, `"olive"`,
    ///   `"green"`, `"cyan"`, `"blue"`, `"purple"` or `"magenta"`.
    ///
    /// Colors with almost no chroma are `"white"`, `"black"`, or a `"gray"` with a
    /// lightness. Alpha is ignored. For the closest CSS color name, use
    /// ``toNearestCSSNamedColor()``.
    public func toDescriptiveName() -> String {
        let oklch = toOKLCHColor()
        let lightness = oklch.lightness
        let chroma = max(oklch.chroma, 0)

        let cusp = ColorNameCusp.cusp(at: oklch.hue.degrees)
        // The most chroma sRGB can show at this lightness and hue, approximated by the
        // triangle from black through the cusp to white
        let maximumChroma = lightness >= cusp.lightness
            ? cusp.chroma * (1 - lightness) / (1 - cusp.lightness)
            : cusp.chroma * lightness / cusp.lightness
        let relativeChroma = maximumChroma > 1e-6 ? chroma / maximumChroma : 0

        if chroma < 0.015 || relativeChroma < 0.12 {
            switch lightness {
            case 0.97...: return "white"
            case 0.9..<0.97: return "very light gray"
            case 0.7..<0.9: return "light gray"
            case 0.45..<0.7: return "gray"
            case 0.27..<0.45: return "dark gray"
            case 0.15..<0.27: return "very dark gray"
            default: return "black"
            }
        }

        var lightnessWord: String?
        // How far towards white or black the color is from the cusp, from 0 to 1
        let towardsWhite = lightness >= cusp.lightness ? (lightness - cusp.lightness) / max(1 - cusp.lightness, 1e-6) : 0
        let towardsBlack = lightness < cusp.lightness ? (cusp.lightness - lightness) / max(cusp.lightness, 1e-6) : 0
        switch (towardsWhite, towardsBlack) {
        case (0.65..., _): lightnessWord = "very light"
        case (0.3..., _): lightnessWord = "light"
        case (_, 0.6...): lightnessWord = "very dark"
        case (_, 0.3...): lightnessWord = "dark"
        default: lightnessWord = nil
        }

        let chromaWord: String? = switch relativeChroma {
        case ..<0.35: "grayish"
        case ..<0.65: "muted"
        case 1.08...: "vivid"
        default: nil
        }

        let degrees = oklch.hue.degrees
        var hueName: String
        switch degrees {
        case 15..<42: hueName = "red"
        case 42..<75: hueName = "orange"
        case 75..<120: hueName = "yellow"
        case 120..<175: hueName = "green"
        case 175..<230: hueName = "cyan"
        case 230..<280: hueName = "blue"
        case 280..<320: hueName = "purple"
        case 320..<350: hueName = "magenta"
        default: hueName = "pink"
        }
        // Dark oranges and yellows look like different colors, not darker versions
        if towardsBlack >= 0.3 {
            if hueName == "orange" {
                hueName = "brown"
                lightnessWord = towardsBlack >= 0.6 ? "dark" : nil
            } else if hueName == "yellow" {
                hueName = "olive"
                lightnessWord = towardsBlack >= 0.6 ? "dark" : nil
            }
        }
        // Light and dark versions of pink read as pink and red
        if hueName == "pink", towardsBlack >= 0.3 {
            hueName = "red"
        }

        return [lightnessWord, chromaWord, hueName].compactMap { $0 }.joined(separator: " ")
    }

    /// The CSS named color closest to this color, such as `steelblue`, by
    /// ``distance(to:)``.
    ///
    /// Of the names for the same color, such as `gray` and `grey`, the one that
    /// ``CSSColor`` writes is used. `transparent` is never returned, and alpha is
    /// ignored.
    public func toNearestCSSNamedColor() -> CSSColor {
        let oklab = toOKLabColor()
        var best: (name: String, distance: Double)?
        for (name, color) in ColorNameCusp.namedColors {
            let distance = color.distance(to: oklab)
            if best == nil || distance < best!.distance || (distance == best!.distance && name < best!.name) {
                best = (name, distance)
            }
        }
        return CSSColor(rawValue: best?.name ?? "black")
    }
}

/// The most colorful sRGB color of each OKLCH hue, which color names are measured
/// relative to.
enum ColorNameCusp {

    /// The OKLCH lightness, chroma and hue in degrees of fully saturated sRGB colors,
    /// sorted by hue.
    static let table: [(hue: Double, lightness: Double, chroma: Double)] = {
        let samples = 1440
        return (0..<samples).map { index -> (hue: Double, lightness: Double, chroma: Double) in
            let oklch = HSBAColor(hue: .degrees(Double(index) * 360 / Double(samples)), saturation: 1, brightness: 1).toOKLCHColor()
            return (oklch.hue.degrees, oklch.lightness, oklch.chroma)
        }
        .sorted { $0.hue < $1.hue }
    }()

    /// The named colors of CSS, once per color, in Oklab.
    static let namedColors: [(name: String, color: OKLabColor)] = CSSColorParser.namesByColor
        .map { (name: $0.value, color: HEXColor(rawValue: $0.key).toOKLabColor()) }
        .sorted { $0.name < $1.name }

    /// The cusp at a hue in degrees, interpolated between the nearest samples.
    static func cusp(at hue: Double) -> (lightness: Double, chroma: Double) {
        let table = table
        let hue = hue.isNaN ? 0 : (hue.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        // The first sample at or above the hue, wrapping around
        var low = 0
        var high = table.count
        while low < high {
            let mid = (low + high) / 2
            if table[mid].hue < hue { low = mid + 1 } else { high = mid }
        }
        let upper = table[low % table.count]
        let lower = table[(low + table.count - 1) % table.count]
        var span = upper.hue - lower.hue
        if span <= 0 { span += 360 }
        var offset = hue - lower.hue
        if offset < 0 { offset += 360 }
        let fraction = span > 0 ? (offset / span).clamped(to: 0...1) : 0
        return (
            lower.lightness + (upper.lightness - lower.lightness) * fraction,
            lower.chroma + (upper.chroma - lower.chroma) * fraction
        )
    }
}
