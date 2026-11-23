//
// Copyright (c) Nathan Tannar
//

import Foundation
import simd

/// The CSS syntax a color is written in by ``ColorConvertible/toCSSColor(_:)``.
///
/// Encodes as its case name, such as `"oklch"`.
@frozen
public enum CSSColorFormat: String, Hashable, Sendable, Codable, CaseIterable, CustomStringConvertible {
    /// `#FF8000FF`, always `#RRGGBBAA`. sRGB only.
    case hex
    /// `rgb(255 128 0)`. sRGB only.
    case rgb
    /// `hsl(30.118 100% 50%)`. sRGB only.
    case hsl
    /// `hwb(30.118 0% 0%)`. sRGB only.
    case hwb
    /// `lab(67.817 45.488 74.841)`.
    case lab
    /// `lch(67.817 87.58 58.709)`.
    case lch
    /// `oklab(0.7319 0.1119 0.1484)`.
    case oklab
    /// `oklch(0.7319 0.1858 52.985)`.
    case oklch
    /// `color(display-p3 0.9361 0.529 0.1987)`. Display P3 only.
    case displayP3

    /// The raw value, such as `"oklch"`.
    public var description: String {
        rawValue
    }
}

/// A color written as a CSS color string, such as `"rebeccapurple"` or
/// `"oklch(0.7 0.15 250)"`.
///
/// A `CSSColor` keeps its string exactly as written, so it can be written back
/// unchanged. See ``init(decoding:)`` for the supported syntax.
///
/// Colors decoded with ``init(decoding:)``, decoded with `Codable`, or written with
/// ``ColorConvertible/toCSSColor(_:)`` keep the color the string decodes to, so
/// ``toRGBAColor()`` doesn't parse the string again. Colors created with
/// ``init(rawValue:)`` or a string literal aren't checked, and parse the string on
/// each conversion, so prefer ``init(decoding:)`` for strings that aren't known to
/// be valid, and for colors converted often. Invalid strings are opaque black.
///
/// ```swift
/// let accent = CSSColor(decoding: "oklch(0.7 0.15 250)")
/// let named: CSSColor = "rebeccapurple"
/// let written = HEXColor("#FF8000").toCSSColor(.hsl) // "hsl(30.118 100% 50%)"
/// ```
///
/// Equality compares the strings, so `"red"` and `"#FF0000"` aren't equal, but a
/// decoded `"red"` and a `"red"` literal are. Compare ``toRGBAColor()``, or use
/// ``ColorConvertible/isApproximatelyEqual(to:tolerance:alphaTolerance:)``, to
/// compare the colors.
///
/// Encodes as its string, and fails to decode strings that aren't CSS colors.
@frozen
public struct CSSColor: Hashable, Sendable, RawRepresentable, ExpressibleByStringLiteral, Codable, CustomStringConvertible, LosslessStringConvertible, ColorConvertible {

    /// The string, and the color it decodes to when that's known.
    ///
    /// Equality and hashing come from `RawRepresentable`, so they compare only the
    /// string: the color is a cache, and is always the color the string decodes to.
    @usableFromInline
    enum Storage: Hashable, Sendable {
        case css(String)
        case rgba(String, RGBAColor)

        var css: String {
            switch self {
            case .css(let string):
                return string
            case .rgba(let string, _):
                return string
            }
        }
    }

    @usableFromInline
    var storage: Storage

    /// Decodes a CSS color string, or returns `nil` if the string isn't a supported
    /// CSS color.
    ///
    /// Supports the CSS Color 4 syntax:
    /// - HEX colors: `#RGB`, `#RGBA`, `#RRGGBB` and `#RRGGBBAA`.
    /// - The 148 named colors, such as `rebeccapurple`, and `transparent`.
    /// - `rgb()`, `rgba()`, `hsl()`, `hsla()` and `hwb()`, with commas or spaces.
    /// - `lab()`, `lch()`, `oklab()` and `oklch()`.
    /// - `color()` in `srgb`, `srgb-linear`, `display-p3`, `rec2020`, `xyz`,
    ///   `xyz-d65` and `xyz-d50`.
    ///
    /// Numbers can be percentages, hues can have `deg`, `rad`, `grad` or `turn` units,
    /// and `none` is `0`. Parsing is case insensitive and ignores leading and trailing
    /// whitespace, but the string is kept exactly as given. Colors outside sRGB are
    /// kept as extended sRGB. System colors such as `canvas` and `currentcolor` depend
    /// on the document, so they aren't supported.
    public init?(decoding string: String) {
        guard let color = CSSColorParser.decode(string) else { return nil }
        self.storage = .rgba(string, color)
    }

    /// Creates a color from a CSS color string without checking it.
    ///
    /// The string is decoded each time the color is converted, and strings that
    /// aren't CSS colors are opaque `black`. Use ``init(decoding:)`` to detect
    /// invalid strings, and to decode the string once.
    @inlinable
    public init(rawValue: String) {
        self.storage = .css(rawValue)
    }

    /// Creates a color from a CSS color string literal, see ``init(rawValue:)``.
    ///
    /// Like ``HEXColor``, strings that aren't CSS colors are opaque `black`.
    @inlinable
    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    /// Creates a color from a CSS string, or returns `nil` if the string is invalid,
    /// so that ``description`` round trips, as `LosslessStringConvertible` requires.
    ///
    /// Accepts every format of ``init(decoding:)``. A string literal argument, as in
    /// `CSSColor("#FF8000")`, is a literal instead, which is opaque black when invalid.
    @inlinable
    public init?(_ description: String) {
        self.init(decoding: description)
    }

    /// Writes a color as a CSS color string in a format, see ``CSSColorFormat``.
    ///
    /// Numbers in the string are rounded, so ``toRGBAColor()`` is the color the
    /// string decodes to, which is close to `color` but not always exactly it. That
    /// keeps the color of equal strings the same, however they were created, and
    /// through encoding and decoding.
    public init<C: ColorConvertible>(_ color: C, format: CSSColorFormat) {
        let rgba = color.toRGBAColor()
        let string = CSSColorParser.encode(rgba, format: format)
        self.storage = .rgba(string, CSSColorParser.decode(string) ?? rgba)
    }

    /// Writes a color as a CSS color string: `rgb()` when it's in sRGB, and `oklch()`
    /// otherwise, so colors outside sRGB aren't clipped.
    @inlinable
    public init<C: ColorConvertible>(_ color: C) {
        let rgba = color.toRGBAColor()
        self.init(rgba, format: ColorGamut.sRGB.contains(rgba) ? .rgb : .oklch)
    }

    @inlinable
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let color = CSSColor(decoding: string) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "String '\(string)' is not a supported CSS color"
            )
        }
        self = color
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(storage.css)
    }

    /// The CSS color string, exactly as it was decoded or written.
    public var rawValue: String {
        storage.css
    }

    /// The CSS color format
    public var format: CSSColorFormat? {
        let string = storage.css.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if string.hasPrefix("#") {
            return .hex
        }
        let prefixes: [(String, CSSColorFormat)] = [
            ("rgb", .rgb),
            ("hsl", .hsl),
            ("hwb", .hwb),
            ("lab(", .lab),
            ("lch(", .lch),
            ("oklab(", .oklab),
            ("oklch(", .oklch),
        ]
        if let (_, format) = prefixes.first(where: { string.hasPrefix($0.0) }) {
            return format
        }
        if string.hasPrefix("color("),
           string.dropFirst(6).drop(while: \.isWhitespace).hasPrefix("display-p3")
        {
            return .displayP3
        }
        return nil
    }

    /// The CSS color string, ``rawValue``.
    public var description: String {
        storage.css
    }

    public func toRGBAColor() -> RGBAColor {
        switch storage {
        case .css(let string):
            return CSSColorParser.decode(string) ?? RGBAColor(red: 0, green: 0, blue: 0, alpha: 1)
        case .rgba(_, let color):
            return color
        }
    }

    public func toCSSColor() -> CSSColor {
        self
    }

    /// Fits the color in a gamut, see ``RGBAColor/toColorGamut(_:)``.
    ///
    /// Colors already in the gamut are returned unchanged, keeping their string.
    /// Fitted colors are written in a format that holds the gamut: `rgb()` for sRGB,
    /// `color(display-p3)` for Display P3 and `oklch()` for Rec. 2020.
    public func toColorGamut(_ gamut: ColorGamut) -> CSSColor {
        let rgba = toRGBAColor()
        guard !gamut.contains(rgba) else { return self }
        let format: CSSColorFormat = switch gamut {
        case .sRGB: .rgb
        case .displayP3: .displayP3
        case .rec2020: .oklch
        }
        return CSSColor(rgba.toColorGamut(gamut), format: format)
    }
}

extension ColorConvertible {

    /// Converts the color to a ``CSSColor`` written in a format, see ``CSSColorFormat``.
    ///
    /// Formats limited to sRGB, and ``CSSColorFormat/displayP3``, gamut map colors
    /// outside their gamut first, keeping lightness and hue.
    public func toCSSColor(_ format: CSSColorFormat) -> CSSColor {
        CSSColor(self, format: format)
    }
}

// MARK: - Parser

enum CSSColorParser {

    /// Decodes a CSS color string, or returns `nil` if it isn't a supported CSS color.
    ///
    /// Strings that are printable ASCII once trimmed, which every CSS color is in
    /// practice, are scanned as UTF-8 bytes without allocating. Other strings, such as
    /// those with non-ASCII whitespace, are decoded by ``decodeUnicode(_:)``, which
    /// trims and splits Unicode whitespace. Both decode the same strings to the same
    /// colors.
    static func decode(_ string: String) -> RGBAColor? {
        var string = string
        switch string.withUTF8({ decode($0) }) {
        case .color(let color):
            return color
        case .invalid:
            return nil
        case .unsupported:
            return decodeUnicode(string)
        }
    }

    /// The color as a CSS color string, such as `rgb(255 128 0)` or
    /// `oklch(0.7319 0.1858 52.985 / 0.5)`.
    ///
    /// Alpha is written only when the color is translucent. Formats limited to sRGB,
    /// and ``CSSColorFormat/displayP3``, gamut map colors outside their gamut first,
    /// keeping lightness and hue.
    static func encode<C: ColorConvertible>(_ color: C, format: CSSColorFormat = .rgb) -> String {
        let rgba = color.toRGBAColor()
        // Translucent only if the alpha differs from `1` once rounded for output
        let alpha = ColorStringFormatter.format(rgba.alpha.clamped(to: 0...1), digits: 3)
        func function(_ name: String, _ values: [String]) -> String {
            let body = values.joined(separator: " ")
            return alpha != "1" ? "\(name)(\(body) / \(alpha))" : "\(name)(\(body))"
        }
        let format3 = { (value: Double) in ColorStringFormatter.format(value, digits: 3) }
        let format4 = { (value: Double) in ColorStringFormatter.format(value, digits: 4) }
        let percent = { (value: Double) in ColorStringFormatter.format(value * 100, digits: 2) + "%" }
        switch format {
        case .hex:
            let hex = HEXColor(rgba)
            return hex.description
        case .rgb:
            let srgb = rgba.toColorGamut(.sRGB).clamped()
            return function("rgb", [srgb.red, srgb.green, srgb.blue].map { ColorStringFormatter.format($0 * 255, digits: 2) })
        case .hsl:
            let hsl = rgba.toColorGamut(.sRGB).clamped().toHSLAColor()
            return function("hsl", [format3(hsl.hue.degrees), percent(hsl.saturation), percent(hsl.lightness)])
        case .hwb:
            let hwb = rgba.toColorGamut(.sRGB).clamped().toHWBColor()
            return function("hwb", [format3(hwb.hue.degrees), percent(hwb.whiteness), percent(hwb.blackness)])
        case .lab:
            let lab = rgba.toCIELabColor()
            return function("lab", [format3(lab.lightness), format3(lab.a), format3(lab.b)])
        case .lch:
            let lch = rgba.toCIELCHColor()
            return function("lch", [format3(lch.lightness), format3(lch.chroma), format3(lch.hue.degrees)])
        case .oklab:
            let oklab = rgba.toOKLabColor()
            return function("oklab", [format4(oklab.lightness), format4(oklab.a), format4(oklab.b)])
        case .oklch:
            let oklch = rgba.toOKLCHColor()
            return function("oklch", [format4(oklch.lightness), format4(oklch.chroma), format3(oklch.hue.degrees)])
        case .displayP3:
            let linear = ColorSpaceMatrix.linearSRGBToLinearDisplayP3 * rgba.toColorGamut(.displayP3).toLinearComponents()
            let p3 = [linear.x, linear.y, linear.z].map { RGBAColor.delinearize($0).clamped(to: 0...1) }
            return function("color", ["display-p3"] + p3.map(format4))
        }
    }

    private enum Token {
        case number(Double)
        case percentage(Double)
        case angle(degrees: Double)
        case none
    }

    /// A CSS color function. Legacy aliases, such as `rgba()`, are the same function.
    private enum Function {
        case rgb, hsl, hwb, lab, lch, oklab, oklch, color
    }

    /// A predefined color space of `color()`.
    private enum PredefinedSpace {
        case srgb, srgbLinear, displayP3, rec2020, xyzD65, xyzD50
    }

    private enum DecodeResult {
        case color(RGBAColor)
        case invalid
        /// The string isn't printable ASCII, so it needs Unicode aware trimming.
        case unsupported
    }

    /// Decodes a CSS color from its UTF-8 bytes, matching ``decodeUnicode(_:)``.
    private static func decode(_ bytes: UnsafeBufferPointer<UInt8>) -> DecodeResult {
        // Trim whitespace and newlines, as `CharacterSet.whitespacesAndNewlines` does
        var lo = 0
        var hi = bytes.count
        while lo < hi, bytes[lo].isWhitespaceOrNewline { lo += 1 }
        while hi > lo, bytes[hi - 1].isWhitespaceOrNewline { hi -= 1 }
        guard lo < hi else { return .invalid }

        var isWord = true
        var open = -1
        for index in lo..<hi {
            let byte = bytes[index]
            // Anything other than printable ASCII, tabs and newlines, including a
            // `\r`, which is one character with a following `\n`, needs the Unicode path
            guard (0x20...0x7E).contains(byte) || byte == 0x09 || byte == 0x0A else {
                return .unsupported
            }
            if open < 0, byte == UInt8(ascii: "(") {
                open = index
            }
            if isWord, !byte.isLetter {
                isWord = false
            }
        }

        if bytes[lo] == UInt8(ascii: "#") {
            return HEXColor(decoding: bytes[lo..<hi])
                .map { .color($0.toRGBAColor()) } ?? .invalid
        }
        if isWord {
            return decodeNamedColor(bytes, lo, hi).map({ DecodeResult.color($0) }) ?? .invalid
        }
        guard open >= 0, bytes[hi - 1] == UInt8(ascii: ")") else { return .invalid }

        var nameLo = lo
        var nameHi = open
        trimSpaces(bytes, &nameLo, &nameHi)
        guard let function = decodeFunction(bytes, nameLo, nameHi) else { return .invalid }

        var bodyLo = open + 1
        var bodyHi = hi - 1

        // `color()` starts with a color space identifier
        var space: PredefinedSpace?
        if function == .color {
            while bodyLo < bodyHi, bytes[bodyLo].isSeparator { bodyLo += 1 }
            while bodyHi > bodyLo, bytes[bodyHi - 1].isSeparator { bodyHi -= 1 }
            var end = bodyLo
            while end < bodyHi, !bytes[end].isSeparator { end += 1 }
            guard end < bodyHi, let predefined = decodePredefinedSpace(bytes, bodyLo, end) else {
                return .invalid
            }
            space = predefined
            bodyLo = end
        }

        // Split off alpha after `/`, or a fourth comma separated value
        var slash = -1
        var hasCommas = false
        for index in bodyLo..<bodyHi {
            switch bytes[index] {
            case UInt8(ascii: "/"):
                guard slash < 0 else { return .invalid }
                slash = index
            case UInt8(ascii: ","):
                if slash < 0 { hasCommas = true }
            default:
                break
            }
        }
        if hasCommas, slash >= 0 { return .invalid }

        var partsLo = SIMD4<Int>()
        var partsHi = SIMD4<Int>()
        var count = 0
        let segmentHi = slash >= 0 ? slash : bodyHi
        var start = bodyLo
        while start < segmentHi {
            var end = start
            while end < segmentHi, !(hasCommas ? bytes[end] == UInt8(ascii: ",") : bytes[end].isSeparator) {
                end += 1
            }
            var partLo = start
            var partHi = end
            trimSpaces(bytes, &partLo, &partHi)
            if partLo < partHi {
                guard count < 4 else { return .invalid }
                if hasCommas {
                    for index in partLo..<partHi where bytes[index] == UInt8(ascii: " ") {
                        return .invalid
                    }
                }
                partsLo[count] = partLo
                partsHi[count] = partHi
                count += 1
            }
            start = end + 1
        }

        var alpha = 1.0
        var alphaLo = -1
        var alphaHi = -1
        if slash >= 0 {
            alphaLo = slash + 1
            alphaHi = bodyHi
            trimSpaces(bytes, &alphaLo, &alphaHi)
        } else if hasCommas, count == 4 {
            count = 3
            alphaLo = partsLo[3]
            alphaHi = partsHi[3]
        }
        guard
            count == 3,
            let first = decodeToken(bytes, partsLo[0], partsHi[0]),
            let second = decodeToken(bytes, partsLo[1], partsHi[1]),
            let third = decodeToken(bytes, partsLo[2], partsHi[2])
        else {
            return .invalid
        }
        if alphaLo >= 0 {
            guard let token = decodeToken(bytes, alphaLo, alphaHi), let value = alphaValue(token) else {
                return .invalid
            }
            alpha = value
        }
        return color(function, space: space, first, second, third, alpha: alpha.clamped(to: 0...1))
            .map({ DecodeResult.color($0) }) ?? .invalid
    }

    /// A named color, or `transparent`, from a string of ASCII letters.
    private static func decodeNamedColor(_ bytes: UnsafeBufferPointer<UInt8>, _ lo: Int, _ hi: Int) -> RGBAColor? {
        // The longest name, `lightgoldenrodyellow`, has 20 letters
        guard hi - lo <= 20 else { return nil }
        if matches(bytes, lo, hi, "transparent") {
            return RGBAColor(red: 0, green: 0, blue: 0, alpha: 0)
        }
        let letters = UnsafeBufferPointer(rebasing: bytes[lo..<hi])
        var name = String(decoding: letters, as: UTF8.self)
        if letters.contains(where: { $0.isUppercase }){
            name = name.lowercased()
        }
        return namedColors[name]?.toRGBAColor()
    }

    private static func decodeFunction(_ bytes: UnsafeBufferPointer<UInt8>, _ lo: Int, _ hi: Int) -> Function? {
        if matches(bytes, lo, hi, "rgb") || matches(bytes, lo, hi, "rgba") { return .rgb }
        if matches(bytes, lo, hi, "hsl") || matches(bytes, lo, hi, "hsla") { return .hsl }
        if matches(bytes, lo, hi, "hwb") { return .hwb }
        if matches(bytes, lo, hi, "lab") { return .lab }
        if matches(bytes, lo, hi, "lch") { return .lch }
        if matches(bytes, lo, hi, "oklab") { return .oklab }
        if matches(bytes, lo, hi, "oklch") { return .oklch }
        if matches(bytes, lo, hi, "color") { return .color }
        return nil
    }

    private static func decodePredefinedSpace(_ bytes: UnsafeBufferPointer<UInt8>, _ lo: Int, _ hi: Int) -> PredefinedSpace? {
        if matches(bytes, lo, hi, "srgb") { return .srgb }
        if matches(bytes, lo, hi, "srgb-linear") { return .srgbLinear }
        if matches(bytes, lo, hi, "display-p3") { return .displayP3 }
        if matches(bytes, lo, hi, "rec2020") { return .rec2020 }
        if matches(bytes, lo, hi, "xyz") || matches(bytes, lo, hi, "xyz-d65") { return .xyzD65 }
        if matches(bytes, lo, hi, "xyz-d50") { return .xyzD50 }
        return nil
    }

    private static func decodeToken(_ bytes: UnsafeBufferPointer<UInt8>, _ lo: Int, _ hi: Int) -> Token? {
        guard lo < hi else { return nil }
        if matches(bytes, lo, hi, "none") {
            return Token.none
        }
        if bytes[hi - 1] == UInt8(ascii: "%") {
            return decodeNumber(bytes, lo, hi - 1).map { .percentage($0) }
        }
        if hasSuffix(bytes, lo, hi, "deg") {
            return decodeNumber(bytes, lo, hi - 3).map { .angle(degrees: $0) }
        }
        if hasSuffix(bytes, lo, hi, "grad") {
            return decodeNumber(bytes, lo, hi - 4).map { .angle(degrees: $0 * 0.9) }
        }
        if hasSuffix(bytes, lo, hi, "rad") {
            return decodeNumber(bytes, lo, hi - 3).map { .angle(degrees: $0 * (180 / .pi)) }
        }
        if hasSuffix(bytes, lo, hi, "turn") {
            return decodeNumber(bytes, lo, hi - 4).map { .angle(degrees: $0 * 360) }
        }
        return decodeNumber(bytes, lo, hi).map { .number($0) }
    }

    /// Exact powers of ten, for Clinger's fast path.
    private static let powersOfTen: [Double] = [
        1e0, 1e1, 1e2, 1e3, 1e4, 1e5, 1e6, 1e7, 1e8, 1e9, 1e10, 1e11,
        1e12, 1e13, 1e14, 1e15, 1e16, 1e17, 1e18, 1e19, 1e20, 1e21, 1e22,
    ]

    /// A finite number, exactly as `Double(String)` parses it.
    ///
    /// Plain decimals with at most 15 significant digits and a small exponent, which
    /// is every number in a CSS color in practice, use Clinger's fast path: the digits
    /// and the power of ten are both exact, so one multiplication or division rounds
    /// correctly. Anything else, such as hex floats, falls back to `Double(String)`.
    private static func decodeNumber(_ bytes: UnsafeBufferPointer<UInt8>, _ lo: Int, _ hi: Int) -> Double? {
        var index = lo
        var isNegative = false
        if index < hi, bytes[index] == UInt8(ascii: "+") || bytes[index] == UInt8(ascii: "-") {
            isNegative = bytes[index] == UInt8(ascii: "-")
            index += 1
        }
        var mantissa: UInt64 = 0
        var significantDigits = 0
        var digits = 0
        var exponent = 0
        func append(_ byte: UInt8) {
            let digit = UInt64(byte &- UInt8(ascii: "0"))
            if mantissa != 0 || digit != 0 {
                significantDigits += 1
            }
            if significantDigits <= 15 {
                mantissa = mantissa * 10 + digit
            }
            digits += 1
        }
        while index < hi, bytes[index].isDigit {
            append(bytes[index])
            index += 1
        }
        if index < hi, bytes[index] == UInt8(ascii: ".") {
            index += 1
            while index < hi, bytes[index].isDigit {
                append(bytes[index])
                exponent -= 1
                index += 1
            }
        }
        if digits > 0, index < hi, bytes[index].lowercased() == UInt8(ascii: "e") {
            index += 1
            var isExponentNegative = false
            if index < hi, bytes[index] == UInt8(ascii: "+") || bytes[index] == UInt8(ascii: "-") {
                isExponentNegative = bytes[index] == UInt8(ascii: "-")
                index += 1
            }
            var value = 0
            var exponentDigits = 0
            while index < hi, bytes[index].isDigit, exponentDigits < 4 {
                value = value * 10 + Int(bytes[index] &- UInt8(ascii: "0"))
                exponentDigits += 1
                index += 1
            }
            if exponentDigits == 0 {
                index = -1
            }
            exponent += isExponentNegative ? -value : value
        }
        guard
            digits > 0,
            index == hi,
            significantDigits <= 15,
            exponent >= -22, exponent <= 22
        else {
            let string = String(decoding: UnsafeBufferPointer(rebasing: bytes[lo..<hi]), as: UTF8.self).lowercased()
            guard let number = Double(string), number.isFinite else { return nil }
            return number
        }
        let magnitude = Double(mantissa)
        let value = exponent >= 0 ? magnitude * powersOfTen[exponent] : magnitude / powersOfTen[-exponent]
        return isNegative ? -value : value
    }

    /// Whether the bytes, lowercased, are an ASCII literal.
    private static func matches(_ bytes: UnsafeBufferPointer<UInt8>, _ lo: Int, _ hi: Int, _ literal: StaticString) -> Bool {
        let count = literal.utf8CodeUnitCount
        guard hi - lo == count else { return false }
        let literal = literal.utf8Start
        for offset in 0..<count where bytes[lo + offset].lowercased() != literal[offset] {
            return false
        }
        return true
    }

    /// Whether the bytes, lowercased, end with an ASCII literal.
    private static func hasSuffix(_ bytes: UnsafeBufferPointer<UInt8>, _ lo: Int, _ hi: Int, _ literal: StaticString) -> Bool {
        hi - lo >= literal.utf8CodeUnitCount && matches(bytes, hi - literal.utf8CodeUnitCount, hi, literal)
    }

    /// Trims spaces and tabs, as `CharacterSet.whitespaces` does for ASCII.
    private static func trimSpaces(_ bytes: UnsafeBufferPointer<UInt8>, _ lo: inout Int, _ hi: inout Int) {
        while lo < hi, bytes[lo].isSpaceOrTab { lo += 1 }
        while hi > lo, bytes[hi - 1].isSpaceOrTab { hi -= 1 }
    }

    // MARK: Unicode Parser

    /// Decodes a CSS color string with Unicode aware trimming and splitting, for
    /// strings that aren't printable ASCII.
    private static func decodeUnicode(_ string: String) -> RGBAColor? {
        let string = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if string.hasPrefix("#") {
            return HEXColor(decoding: string)?.toRGBAColor()
        }
        if string == "transparent" {
            return RGBAColor(red: 0, green: 0, blue: 0, alpha: 0)
        }
        if let named = namedColors[string] {
            return named.toRGBAColor()
        }
        guard
            let open = string.firstIndex(of: "("),
            string.hasSuffix(")")
        else {
            return nil
        }
        let name = string[..<open].trimmingCharacters(in: .whitespaces)
        let function: Function
        switch name {
        case "rgb", "rgba": function = .rgb
        case "hsl", "hsla": function = .hsl
        case "hwb": function = .hwb
        case "lab": function = .lab
        case "lch": function = .lch
        case "oklab": function = .oklab
        case "oklch": function = .oklch
        case "color": function = .color
        default: return nil
        }
        var body = String(string[string.index(after: open)..<string.index(before: string.endIndex)])

        // `color()` starts with a color space identifier
        var space: PredefinedSpace?
        if function == .color {
            let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let end = trimmed.firstIndex(where: \.isWhitespace) else { return nil }
            switch trimmed[..<end] {
            case "srgb": space = .srgb
            case "srgb-linear": space = .srgbLinear
            case "display-p3": space = .displayP3
            case "rec2020": space = .rec2020
            case "xyz", "xyz-d65": space = .xyzD65
            case "xyz-d50": space = .xyzD50
            default: return nil
            }
            body = String(trimmed[end...])
        }

        // Split off alpha after `/`, or a fourth comma separated value
        let slashParts = body.split(separator: "/", omittingEmptySubsequences: false)
        guard slashParts.count <= 2 else { return nil }
        let hasCommas = slashParts[0].contains(",")
        if hasCommas, slashParts.count == 2 { return nil }
        let separators: (Character) -> Bool
        if hasCommas {
            separators = { $0 == "," }
        } else {
            separators = { $0 == " " || $0 == "\t" || $0 == "\n" }
        }
        var parts = slashParts[0].split(whereSeparator: separators)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if hasCommas, parts.contains(where: { $0.contains(" ") }) { return nil }
        var alphaPart: String?
        if slashParts.count == 2 {
            alphaPart = slashParts[1].trimmingCharacters(in: .whitespaces)
        } else if hasCommas, parts.count == 4 {
            alphaPart = parts.removeLast()
        }
        guard parts.count == 3 else { return nil }
        let tokens = parts.compactMap { decodeToken($0) }
        guard tokens.count == 3 else { return nil }

        var alpha = 1.0
        if let alphaPart {
            guard let alphaToken = decodeToken(alphaPart), let value = alphaValue(alphaToken) else { return nil }
            alpha = value
        }
        return color(function, space: space, tokens[0], tokens[1], tokens[2], alpha: alpha.clamped(to: 0...1))
    }

    private static func decodeToken(_ string: String) -> Token? {
        if string == "none" {
            return Token.none
        }
        if string.hasSuffix("%") {
            guard let number = Double(string.dropLast()), number.isFinite else { return nil }
            return .percentage(number)
        }
        let units: [(String, Double)] = [("deg", 1), ("grad", 0.9), ("rad", 180 / .pi), ("turn", 360)]
        for (unit, scale) in units where string.hasSuffix(unit) {
            guard let number = Double(string.dropLast(unit.count)), number.isFinite else { return nil }
            return .angle(degrees: number * scale)
        }
        guard let number = Double(string), number.isFinite else { return nil }
        return .number(number)
    }

    // MARK: Colors

    /// The alpha of a token: a number, a percentage, or `none` as `0`.
    private static func alphaValue(_ token: Token) -> Double? {
        switch token {
        case .number(let value): value
        case .percentage(let value): value / 100
        case .none: 0
        case .angle: nil
        }
    }

    /// The color of a function's three values, with alpha already clamped.
    private static func color(
        _ function: Function,
        space: PredefinedSpace?,
        _ first: Token,
        _ second: Token,
        _ third: Token,
        alpha: Double
    ) -> RGBAColor? {
        /// A number, a percentage of `percentScale`, or `none` as `0`.
        func value(_ token: Token, percentScale: Double) -> Double? {
            switch token {
            case .number(let value): value
            case .percentage(let value): value / 100 * percentScale
            case .none: 0
            case .angle: nil
            }
        }
        func hue(_ token: Token) -> ColorHue? {
            switch token {
            case .number(let value): .degrees(value)
            case .angle(let degrees): .degrees(degrees)
            case .none: 0
            case .percentage: nil
            }
        }

        switch function {
        case .rgb:
            guard
                let r = value(first, percentScale: 255),
                let g = value(second, percentScale: 255),
                let b = value(third, percentScale: 255)
            else { return nil }
            return RGBAColor(
                red: (r / 255).clamped(to: 0...1),
                green: (g / 255).clamped(to: 0...1),
                blue: (b / 255).clamped(to: 0...1),
                alpha: alpha
            )
        case .hsl:
            guard
                let h = hue(first),
                let s = value(second, percentScale: 100),
                let l = value(third, percentScale: 100)
            else { return nil }
            return HSLAColor(hue: h, saturation: (s / 100).clamped(to: 0...1), lightness: (l / 100).clamped(to: 0...1), alpha: alpha).toRGBAColor()
        case .hwb:
            guard
                let h = hue(first),
                let w = value(second, percentScale: 100),
                let b = value(third, percentScale: 100)
            else { return nil }
            return HWBColor(hue: h, whiteness: (w / 100).clamped(to: 0...1), blackness: (b / 100).clamped(to: 0...1), alpha: alpha).toRGBAColor()
        case .lab:
            guard
                let l = value(first, percentScale: 100),
                let a = value(second, percentScale: 125),
                let b = value(third, percentScale: 125)
            else { return nil }
            return CIELabColor(lightness: min(max(l, 0), 100), a: a, b: b, alpha: alpha).toRGBAColor()
        case .lch:
            guard
                let l = value(first, percentScale: 100),
                let c = value(second, percentScale: 150),
                let h = hue(third)
            else { return nil }
            return CIELCHColor(lightness: min(max(l, 0), 100), chroma: max(c, 0), hue: h, alpha: alpha).toRGBAColor()
        case .oklab:
            guard
                let l = value(first, percentScale: 1),
                let a = value(second, percentScale: 0.4),
                let b = value(third, percentScale: 0.4)
            else { return nil }
            return OKLabColor(lightness: l.clamped(to: 0...1), a: a, b: b, alpha: alpha).toRGBAColor()
        case .oklch:
            guard
                let l = value(first, percentScale: 1),
                let c = value(second, percentScale: 0.4),
                let h = hue(third)
            else { return nil }
            return OKLCHColor(lightness: l.clamped(to: 0...1), chroma: max(c, 0), hue: h, alpha: alpha).toRGBAColor()
        case .color:
            guard
                let space,
                let x = value(first, percentScale: 1),
                let y = value(second, percentScale: 1),
                let z = value(third, percentScale: 1)
            else { return nil }
            switch space {
            case .srgb:
                return RGBAColor(red: x, green: y, blue: z, alpha: alpha)
            case .srgbLinear:
                return RGBAColor(linear: SIMD3(x, y, z), alpha: alpha)
            case .displayP3:
                let linear = SIMD3(RGBAColor.linearize(x), RGBAColor.linearize(y), RGBAColor.linearize(z))
                return RGBAColor(linear: ColorSpaceMatrix.linearDisplayP3ToLinearSRGB * linear, alpha: alpha)
            case .rec2020:
                // CSS defines `rec2020` with the camera curve, unlike Core Graphics
                let linear = SIMD3(BT2020CameraTransfer.linearize(x), BT2020CameraTransfer.linearize(y), BT2020CameraTransfer.linearize(z))
                return RGBAColor(linear: ColorSpaceMatrix.linearRec2020ToLinearSRGB * linear, alpha: alpha)
            case .xyzD65:
                return XYZColor(x: x, y: y, z: z, alpha: alpha).toRGBAColor()
            case .xyzD50:
                return XYZColor(d50: x, y: y, z: z, alpha: alpha).toRGBAColor()
            }
        }
    }

    // MARK: Named Colors

    static let namesByColor: [UInt32: String] = {
        var names: [UInt32: String] = [:]
        // Sorted so that the preferred of two names wins deterministically
        for (name, color) in namedColors.sorted(by: { $0.key < $1.key }) {
            let key = color.rawValue
            if let existing = names[key] {
                names[key] = preferredName(existing, name)
            } else {
                names[key] = name
            }
        }
        return names
    }()

    private static func preferredName(_ lhs: String, _ rhs: String) -> String {
        let preferred: Set<String> = ["aqua", "fuchsia"]
        if preferred.contains(lhs) { return lhs }
        if preferred.contains(rhs) { return rhs }
        // Prefer `gray` over `grey`
        if lhs.contains("grey") { return rhs }
        if rhs.contains("grey") { return lhs }
        return min(lhs, rhs)
    }

    static let namedColors: [String: HEXColor] = [
        "aliceblue": HEXColor(0xF0F8FFFF),
        "antiquewhite": HEXColor(0xFAEBD7FF),
        "aqua": HEXColor(0x00FFFFFF),
        "aquamarine": HEXColor(0x7FFFD4FF),
        "azure": HEXColor(0xF0FFFFFF),
        "beige": HEXColor(0xF5F5DCFF),
        "bisque": HEXColor(0xFFE4C4FF),
        "black": HEXColor(0x000000FF),
        "blanchedalmond": HEXColor(0xFFEBCDFF),
        "blue": HEXColor(0x0000FFFF),
        "blueviolet": HEXColor(0x8A2BE2FF),
        "brown": HEXColor(0xA52A2AFF),
        "burlywood": HEXColor(0xDEB887FF),
        "cadetblue": HEXColor(0x5F9EA0FF),
        "chartreuse": HEXColor(0x7FFF00FF),
        "chocolate": HEXColor(0xD2691EFF),
        "coral": HEXColor(0xFF7F50FF),
        "cornflowerblue": HEXColor(0x6495EDFF),
        "cornsilk": HEXColor(0xFFF8DCFF),
        "crimson": HEXColor(0xDC143CFF),
        "cyan": HEXColor(0x00FFFFFF),
        "darkblue": HEXColor(0x00008BFF),
        "darkcyan": HEXColor(0x008B8BFF),
        "darkgoldenrod": HEXColor(0xB8860BFF),
        "darkgray": HEXColor(0xA9A9A9FF),
        "darkgreen": HEXColor(0x006400FF),
        "darkgrey": HEXColor(0xA9A9A9FF),
        "darkkhaki": HEXColor(0xBDB76BFF),
        "darkmagenta": HEXColor(0x8B008BFF),
        "darkolivegreen": HEXColor(0x556B2FFF),
        "darkorange": HEXColor(0xFF8C00FF),
        "darkorchid": HEXColor(0x9932CCFF),
        "darkred": HEXColor(0x8B0000FF),
        "darksalmon": HEXColor(0xE9967AFF),
        "darkseagreen": HEXColor(0x8FBC8FFF),
        "darkslateblue": HEXColor(0x483D8BFF),
        "darkslategray": HEXColor(0x2F4F4FFF),
        "darkslategrey": HEXColor(0x2F4F4FFF),
        "darkturquoise": HEXColor(0x00CED1FF),
        "darkviolet": HEXColor(0x9400D3FF),
        "deeppink": HEXColor(0xFF1493FF),
        "deepskyblue": HEXColor(0x00BFFFFF),
        "dimgray": HEXColor(0x696969FF),
        "dimgrey": HEXColor(0x696969FF),
        "dodgerblue": HEXColor(0x1E90FFFF),
        "firebrick": HEXColor(0xB22222FF),
        "floralwhite": HEXColor(0xFFFAF0FF),
        "forestgreen": HEXColor(0x228B22FF),
        "fuchsia": HEXColor(0xFF00FFFF),
        "gainsboro": HEXColor(0xDCDCDCFF),
        "ghostwhite": HEXColor(0xF8F8FFFF),
        "gold": HEXColor(0xFFD700FF),
        "goldenrod": HEXColor(0xDAA520FF),
        "gray": HEXColor(0x808080FF),
        "green": HEXColor(0x008000FF),
        "greenyellow": HEXColor(0xADFF2FFF),
        "grey": HEXColor(0x808080FF),
        "honeydew": HEXColor(0xF0FFF0FF),
        "hotpink": HEXColor(0xFF69B4FF),
        "indianred": HEXColor(0xCD5C5CFF),
        "indigo": HEXColor(0x4B0082FF),
        "ivory": HEXColor(0xFFFFF0FF),
        "khaki": HEXColor(0xF0E68CFF),
        "lavender": HEXColor(0xE6E6FAFF),
        "lavenderblush": HEXColor(0xFFF0F5FF),
        "lawngreen": HEXColor(0x7CFC00FF),
        "lemonchiffon": HEXColor(0xFFFACDFF),
        "lightblue": HEXColor(0xADD8E6FF),
        "lightcoral": HEXColor(0xF08080FF),
        "lightcyan": HEXColor(0xE0FFFFFF),
        "lightgoldenrodyellow": HEXColor(0xFAFAD2FF),
        "lightgray": HEXColor(0xD3D3D3FF),
        "lightgreen": HEXColor(0x90EE90FF),
        "lightgrey": HEXColor(0xD3D3D3FF),
        "lightpink": HEXColor(0xFFB6C1FF),
        "lightsalmon": HEXColor(0xFFA07AFF),
        "lightseagreen": HEXColor(0x20B2AAFF),
        "lightskyblue": HEXColor(0x87CEFAFF),
        "lightslategray": HEXColor(0x778899FF),
        "lightslategrey": HEXColor(0x778899FF),
        "lightsteelblue": HEXColor(0xB0C4DEFF),
        "lightyellow": HEXColor(0xFFFFE0FF),
        "lime": HEXColor(0x00FF00FF),
        "limegreen": HEXColor(0x32CD32FF),
        "linen": HEXColor(0xFAF0E6FF),
        "magenta": HEXColor(0xFF00FFFF),
        "maroon": HEXColor(0x800000FF),
        "mediumaquamarine": HEXColor(0x66CDAAFF),
        "mediumblue": HEXColor(0x0000CDFF),
        "mediumorchid": HEXColor(0xBA55D3FF),
        "mediumpurple": HEXColor(0x9370DBFF),
        "mediumseagreen": HEXColor(0x3CB371FF),
        "mediumslateblue": HEXColor(0x7B68EEFF),
        "mediumspringgreen": HEXColor(0x00FA9AFF),
        "mediumturquoise": HEXColor(0x48D1CCFF),
        "mediumvioletred": HEXColor(0xC71585FF),
        "midnightblue": HEXColor(0x191970FF),
        "mintcream": HEXColor(0xF5FFFAFF),
        "mistyrose": HEXColor(0xFFE4E1FF),
        "moccasin": HEXColor(0xFFE4B5FF),
        "navajowhite": HEXColor(0xFFDEADFF),
        "navy": HEXColor(0x000080FF),
        "oldlace": HEXColor(0xFDF5E6FF),
        "olive": HEXColor(0x808000FF),
        "olivedrab": HEXColor(0x6B8E23FF),
        "orange": HEXColor(0xFFA500FF),
        "orangered": HEXColor(0xFF4500FF),
        "orchid": HEXColor(0xDA70D6FF),
        "palegoldenrod": HEXColor(0xEEE8AAFF),
        "palegreen": HEXColor(0x98FB98FF),
        "paleturquoise": HEXColor(0xAFEEEEFF),
        "palevioletred": HEXColor(0xDB7093FF),
        "papayawhip": HEXColor(0xFFEFD5FF),
        "peachpuff": HEXColor(0xFFDAB9FF),
        "peru": HEXColor(0xCD853FFF),
        "pink": HEXColor(0xFFC0CBFF),
        "plum": HEXColor(0xDDA0DDFF),
        "powderblue": HEXColor(0xB0E0E6FF),
        "purple": HEXColor(0x800080FF),
        "rebeccapurple": HEXColor(0x663399FF),
        "red": HEXColor(0xFF0000FF),
        "rosybrown": HEXColor(0xBC8F8FFF),
        "royalblue": HEXColor(0x4169E1FF),
        "saddlebrown": HEXColor(0x8B4513FF),
        "salmon": HEXColor(0xFA8072FF),
        "sandybrown": HEXColor(0xF4A460FF),
        "seagreen": HEXColor(0x2E8B57FF),
        "seashell": HEXColor(0xFFF5EEFF),
        "sienna": HEXColor(0xA0522DFF),
        "silver": HEXColor(0xC0C0C0FF),
        "skyblue": HEXColor(0x87CEEBFF),
        "slateblue": HEXColor(0x6A5ACDFF),
        "slategray": HEXColor(0x708090FF),
        "slategrey": HEXColor(0x708090FF),
        "snow": HEXColor(0xFFFAFAFF),
        "springgreen": HEXColor(0x00FF7FFF),
        "steelblue": HEXColor(0x4682B4FF),
        "tan": HEXColor(0xD2B48CFF),
        "teal": HEXColor(0x008080FF),
        "thistle": HEXColor(0xD8BFD8FF),
        "tomato": HEXColor(0xFF6347FF),
        "turquoise": HEXColor(0x40E0D0FF),
        "violet": HEXColor(0xEE82EEFF),
        "wheat": HEXColor(0xF5DEB3FF),
        "white": HEXColor(0xFFFFFFFF),
        "whitesmoke": HEXColor(0xF5F5F5FF),
        "yellow": HEXColor(0xFFFF00FF),
        "yellowgreen": HEXColor(0x9ACD32FF),
    ]
}
