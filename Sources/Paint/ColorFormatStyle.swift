//
// Copyright (c) Nathan Tannar
//

import Foundation

/// A Foundation format style that writes a color as a HEX or CSS color string, or a
/// descriptive name, and parses any HEX or CSS color string back.
///
/// ```swift
/// color.formatted(.hex)              // "FF8000"
/// color.formatted(.css(.hex))        // "#FF8000FF"
/// color.formatted(.css(.oklch))      // "oklch(0.7319 0.1858 52.985)"
/// color.formatted(.name)             // "orange"
/// ```
///
/// To parse a string without a style, use ``ColorParseStrategy``, or
/// ``CSSColor/init(decoding:)`` and ``HEXColor/init(decoding:)``.
///
/// Formatting matches ``ColorConvertible/toHEXColor()`` and
/// ``ColorConvertible/toCSSColor(_:)``: HEX colors are 8-bit sRGB, so colors outside
/// sRGB are gamut mapped, and CSS numbers are rounded to a few decimals. So parsing a
/// formatted color gives back the same HEX color, but only a close CSS color.
///
/// The ``Format/name`` format matches ``ColorConvertible/toDescriptiveName()``, which
/// describes a color in plain English, such as `"dark grayish blue"`. Names are for
/// display, such as VoiceOver labels, so they don't parse back into the color.
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
@frozen
public struct ColorFormatStyle: ParseableFormatStyle {

    /// How a color is written.
    @frozen
    public enum Format: Hashable, Sendable, Codable {
        /// A HEX color, `RRGGBB` when opaque and `RRGGBBAA` otherwise.
        case hex
        /// A CSS color function in a format, such as `#RRGGBBAA`, `rgb(255 128 0)` or `oklch(0.7319 0.1858 52.985)`.
        case css(CSSColorFormat)
        /// A short English description of the color, such as `"dark grayish blue"`,
        /// from ``ColorConvertible/toDescriptiveName()``. Names don't parse back.
        case name
    }

    /// How the color is written.
    public var format: Format

    /// Creates a style that writes colors in a notation.
    @inlinable
    public init(format: Format) {
        self.format = format
    }

    public func format(_ color: RGBAColor) -> String {
        switch format {
        case .hex:
            color.toHEXColor().toString()
        case .css(let format):
            color.toCSSColor(format).rawValue
        case .name:
            color.toDescriptiveName()
        }
    }

    /// Parses any HEX or CSS color string, whatever the notation.
    ///
    /// Descriptive names written by ``Format/name`` aren't parsed, though names that
    /// are also CSS named colors, such as `"orange"`, parse as that CSS color.
    public var parseStrategy: ColorParseStrategy {
        ColorParseStrategy()
    }
}

/// A Foundation parse strategy that reads any HEX or CSS color string.
///
/// Strings are decoded as CSS colors, with ``CSSColor/init(decoding:)``, and then as
/// HEX colors, with ``HEXColor/init(decoding:)``, so HEX colors without a leading
/// `#`, such as `FF8000`, which aren't valid CSS, are accepted too.
///
/// It's the parse strategy of ``ColorFormatStyle``. Throws a `CocoaError` with the
/// `.formatting` code for strings that aren't colors, like Foundation's strategies.
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
@frozen
public struct ColorParseStrategy: ParseStrategy {

    /// Creates a strategy that parses any HEX or CSS color string.
    @inlinable
    public init() {}

    public func parse(_ value: String) throws -> RGBAColor {
        if let color = CSSColor(decoding: value) {
            return color.toRGBAColor()
        }
        if let color = HEXColor(decoding: value) {
            return color.toRGBAColor()
        }
        throw CocoaError(.formatting, userInfo: [
            NSDebugDescriptionErrorKey: "\"\(value)\" isn't a HEX or CSS color",
        ])
    }
}

// MARK: - Static Members

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension FormatStyle where Self == ColorFormatStyle {

    /// Writes colors as HEX colors, `RRGGBB` when opaque and `RRGGBBAA` otherwise.
    public static var hex: ColorFormatStyle {
        ColorFormatStyle(format: .hex)
    }

    /// Writes colors as CSS colors in a format, such as `#RRGGBBAA`, `rgb(255 128 0)` or `oklch(0.7319 0.1858 52.985)`.
    public static func css(_ format: CSSColorFormat = .rgb) -> ColorFormatStyle {
        ColorFormatStyle(format: .css(format))
    }

    /// Writes colors as a short English description, such as `"dark grayish blue"`,
    /// with ``ColorConvertible/toDescriptiveName()``, for VoiceOver labels and color
    /// pickers. Names don't parse back into the color.
    public static var name: ColorFormatStyle {
        ColorFormatStyle(format: .name)
    }
}

// MARK: - Formatting

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension ColorConvertible {

    /// Formats the color with a style that formats ``RGBAColor``s, such as
    /// ``ColorFormatStyle``:
    ///
    /// ```swift
    /// HEXColor("#FF8000").formatted(.hex)        // "FF8000"
    /// HEXColor("#FF8000").formatted(.css(.hex))  // "#FF8000FF"
    /// HEXColor("#FF8000").formatted(.css(.hsl))  // "hsl(30.118 100% 50%)"
    /// HEXColor("#FF8000").formatted(.name)       // "orange"
    /// ```
    public func formatted<Style: FormatStyle>(_ style: Style) -> Style.FormatOutput where Style.FormatInput == RGBAColor {
        style.format(toRGBAColor())
    }
}
