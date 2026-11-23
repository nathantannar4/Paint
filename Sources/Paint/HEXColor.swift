//
// Copyright (c) Nathan Tannar
//

import Foundation

/// An 8-bit per channel sRGB color packed into a `0xRRGGBBAA` integer.
///
/// Can be created from a string literal in any of the formats accepted by
/// ``init(decoding:)``:
///
/// ```swift
/// let orange: HEXColor = "#FF8000"
/// ```
///
/// Encodes to a `"RRGGBB"` string when opaque, and `"RRGGBBAA"` otherwise. Decodes any
/// format accepted by ``init(decoding:)``.
///
/// Its ``description`` round trips exactly through ``init(_:)-(String)``, as
/// `LosslessStringConvertible` requires.
@frozen
public struct HEXColor: Hashable, Sendable, BitwiseCopyable, RawRepresentable, ExpressibleByIntegerLiteral, ExpressibleByStringLiteral, Codable, LosslessStringConvertible, ColorConvertible {

    /// The color packed as a `0xRRGGBBAA` integer.
    public var rawValue: UInt32

    /// The 8-bit red channel. Setting it keeps the other channels.
    @inlinable
    public var red: UInt8 {
        get { value(offset: 24) }
        set { setValue(newValue, offset: 24) }
    }

    /// The 8-bit green channel. Setting it keeps the other channels.
    @inlinable
    public var green: UInt8 {
        get { value(offset: 16) }
        set { setValue(newValue, offset: 16) }
    }

    /// The 8-bit blue channel. Setting it keeps the other channels.
    @inlinable
    public var blue: UInt8 {
        get { value(offset: 8) }
        set { setValue(newValue, offset: 8) }
    }

    /// The 8-bit alpha channel. Setting it keeps the other channels.
    @inlinable
    public var alpha: UInt8 {
        get { value(offset: 0) }
        set { setValue(newValue, offset: 0) }
    }

    /// Creates a color from a packed `0xRRGGBBAA` integer.
    @inlinable
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    /// Creates a color from gamma encoded sRGB components in `0...1`.
    ///
    /// Each component is clamped to `0...1` and rounded to the nearest 8-bit value.
    /// `NaN` components become `0`.
    @inlinable
    public init(
        red: Double,
        green: Double,
        blue: Double,
        alpha: Double = 1
    ) {
        func quantize(_ component: Double) -> UInt32 {
            let value = (component * 255).rounded()
            guard value > 0 else { return 0 } // Also catches NaN
            return value >= 255 ? 255 : UInt32(value)
        }
        let red = quantize(red)
        let green = quantize(green)
        let blue = quantize(blue)
        let alpha = quantize(alpha)
        self.rawValue = (red << 24) | (green << 16) | (blue << 8) | alpha
    }

    /// Creates a color from gamma encoded sRGB components, rounded to the nearest 8-bit value.
    ///
    /// Colors outside sRGB, such as Display P3 colors, are gamut mapped by reducing
    /// their OKLCH chroma, which keeps their lightness and hue. Clamping each channel
    /// instead would shift the hue.
    @inlinable
    public init(_ rgba: RGBAColor) {
        let rgba = rgba.toColorGamut(.sRGB)
        self.init(
            red: rgba.red,
            green: rgba.green,
            blue: rgba.blue,
            alpha: rgba.alpha
        )
    }

    /// Creates a color by decoding a HEX string, falling back to opaque black
    /// (`#000000FF`) if the string is invalid.
    ///
    /// Use ``init(decoding:)`` to detect invalid strings.
    @inlinable
    public init(rawValue: String) {
        self = HEXColor(decoding: rawValue) ?? HEXColor(0x000000FF)
    }

    /// Creates a color by decoding a HEX string, or returns `nil` if the string is invalid.
    ///
    /// Supported formats, with an optional leading `#`, are `RGB`, `RGBA`, `RRGGBB`
    /// and `RRGGBBAA`. Digits are case insensitive and leading or trailing whitespace
    /// is ignored. Formats without alpha are opaque.
    @inlinable
    public init?(decoding string: String) {
        self.init(decoding: string.utf8)
    }

    /// Creates a color by decoding the UTF-8 bytes of a HEX string, as ``init(decoding:)`` does.
    @inlinable
    public init?<Bytes: BidirectionalCollection<UInt8>>(decoding bytes: Bytes) {
        var bytes = bytes[...]
        while let first = bytes.first, first.isWhitespaceOrNewline {
            bytes.removeFirst()
        }
        while let last = bytes.last, last.isWhitespaceOrNewline {
            bytes.removeLast()
        }
        if bytes.first == UInt8(ascii: "#") {
            bytes.removeFirst()
        }

        var parsed: UInt32 = 0
        var count = 0
        for byte in bytes {
            guard count < 8, let digit = byte.toHexDigitValue() else {
                return nil
            }
            parsed = (parsed << 4) | digit
            count += 1
        }

        switch count {
        case 3:
            // RGB (12-bit) -> RRGGBBAA
            let red = (parsed >> 8 & 0xF) * 17
            let green = (parsed >> 4 & 0xF) * 17
            let blue = (parsed & 0xF) * 17
            self.rawValue = (red << 24) | (green << 16) | (blue << 8) | 0xFF
        case 4:
            // RGBA (16-bit) -> RRGGBBAA
            let red = (parsed >> 12 & 0xF) * 17
            let green = (parsed >> 8 & 0xF) * 17
            let blue = (parsed >> 4 & 0xF) * 17
            let alpha = (parsed & 0xF) * 17
            self.rawValue = (red << 24) | (green << 16) | (blue << 8) | alpha
        case 6:
            // RRGGBB (24-bit) -> RRGGBBAA
            self.rawValue = (parsed << 8) | 0xFF
        case 8:
            // RRGGBBAA (32-bit)
            self.rawValue = parsed
        default:
            return nil
        }
    }

    /// Creates a color from a HEX string, or returns `nil` if the string is invalid,
    /// so that ``description`` round trips, as `LosslessStringConvertible` requires.
    ///
    /// Accepts every format of ``init(decoding:)``. A string literal argument, as in
    /// `HEXColor("#FF8000")`, is a literal instead, which is opaque black when invalid.
    @inlinable
    public init?(_ description: String) {
        self.init(decoding: description)
    }

    @inlinable
    public init(integerLiteral value: UInt32) {
        self.init(rawValue: value)
    }

    @inlinable
    public init(stringLiteral value: StringLiteralType) {
        self.init(rawValue: value)
    }

    @inlinable
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let color = HEXColor(decoding: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "String '\(rawValue)' is not a valid 3, 4, 6, or 8 character HEX color"
            )
        }
        self = color
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(toString(includePrefix: false))
    }

    /// The byte of ``rawValue`` at a bit offset.
    @inlinable
    func value(offset: UInt32) -> UInt8 {
        UInt8(truncatingIfNeeded: rawValue >> offset)
    }

    /// Replaces the byte of ``rawValue`` at a bit offset.
    @inlinable
    mutating func setValue(_ value: UInt8, offset: UInt32) {
        rawValue = (rawValue & ~(0xFF << offset)) | (UInt32(value) << offset)
    }

    /// The color as an uppercase `"RRGGBB"` string when opaque, and `"RRGGBBAA"`
    /// otherwise, without a leading `#`.
    public func toString(prefersOpaqueAlpha: Bool = false, includePrefix: Bool = false) -> String {
        ColorStringFormatter.hex(rawValue, prefersOpaqueAlpha: prefersOpaqueAlpha, includePrefix: includePrefix)
    }

    /// The color as an uppercase `"#RRGGBBAA"` string, including the alpha even when
    /// opaque.
    public var description: String {
        ColorStringFormatter.hex(rawValue, prefersOpaqueAlpha: true, includePrefix: true)
    }

    public func toRGBAColor() -> RGBAColor {
        RGBAColor(
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255,
            alpha: Double(alpha) / 255
        )
    }

    public func toHEXColor() -> HEXColor {
        self
    }
}
