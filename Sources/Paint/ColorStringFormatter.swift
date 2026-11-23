//
// Copyright (c) Nathan Tannar
//

import Foundation

enum ColorStringFormatter {

    /// Describes the components of a color as `name(c1 c2 c3)`, or
    /// `name(c1 c2 c3 / alpha)` when translucent, for the `description` of each
    /// color model.
    static func describe(_ name: String, _ components: [String], alpha: Double) -> String {
        "\(name)(\(components.joined(separator: " "))\(opacity(alpha)))"
    }

    /// Formats a color temperature in whole kelvin, like `"6504 K"`, or
    /// `"6504 K / 0.5"` when translucent.
    ///
    /// Whole kelvin, since estimates of the correlated color temperature aren't
    /// precise to a fraction of a kelvin. The symbol is the letter `K`, which Unicode
    /// recommends over the KELVIN SIGN, U+212A.
    static func temperature(_ kelvin: Double, alpha: Double) -> String {
        format(kelvin.rounded(), digits: 0) + " K" + opacity(alpha)
    }

    /// The alpha after the other values, `" / 0.5"`, or nothing when the alpha
    /// rounds to opaque, as in CSS.
    static func opacity(_ opacity: Double) -> String {
        let formatted = format(opacity, digits: 3)
        return formatted == "1" ? "" : " / \(formatted)"
    }

    /// Formats a fraction as a percentage, such as `0.478` as `47.8%`.
    static func percent(_ value: Double) -> String {
        format(value * 100, digits: 2) + "%"
    }

    /// Formats a hue in degrees, without a unit.
    static func degrees(_ hue: ColorHue) -> String {
        format(hue.degrees, digits: 2)
    }

    /// Formats a packed `0xRRGGBBAA` color as uppercase hex digits after `prefix`:
    /// `"RRGGBB"` when opaque, such as `0xFF8000FF` as `"FF8000"`, and `"RRGGBBAA"`
    /// otherwise, such as `0xFF800080` as `"FF800080"`.
    ///
    /// Set `prefersOpaqueAlpha` to always write all eight digits, such as
    /// `0xFF8000FF` as `"FF8000FF"`.
    static func hex(_ rgba: UInt32, prefersOpaqueAlpha: Bool = false, includePrefix: Bool) -> String {
        let digits = String(rgba, radix: 16, uppercase: true)
        let formatted = String(repeating: "0", count: max(0, 8 - digits.count)) + digits
        // Omit the alpha channel when it's fully opaque
        let isOpaque = rgba & 0xFF == 0xFF
        return (includePrefix ? "#" : "") + (isOpaque && !prefersOpaqueAlpha ? String(formatted.prefix(6)) : formatted)
    }

    /// Formats a number with at most `digits` decimals, without trailing zeros.
    static func format(_ value: Double, digits: Int) -> String {
        var string = String(format: "%.\(digits)f", value)
        if string.contains(".") {
            while string.hasSuffix("0") { string.removeLast() }
            if string.hasSuffix(".") { string.removeLast() }
        }
        return string == "-0" ? "0" : string
    }
}
