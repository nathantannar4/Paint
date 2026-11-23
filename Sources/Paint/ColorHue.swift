//
// Copyright (c) Nathan Tannar
//

import Foundation

/// A hue angle, shared by ``HSBAColor``, ``HSLAColor`` and ``OKLCHColor``.
///
/// The hue is stored as a fraction of a full turn in `0..<1`, the same hue used by
/// `Color(hue:saturation:brightness:)`, `UIColor` and `NSColor`. Hues outside one
/// turn wrap around when stored, so `.degrees(390)` equals `.degrees(30)`, and
/// non-finite hues become `0`.
///
/// Number literals are fractions of a full turn, so `0.5` is `180°`.
///
/// Hues add and subtract around the color wheel, wrapping around, so adding a hue
/// rotates by it:
///
/// ```swift
/// let complement = color.hue + .degrees(180)
/// ```
///
/// Encodes as the fraction of a full turn.
@frozen
public struct ColorHue: Hashable, Sendable, BitwiseCopyable, Codable, RawRepresentable, ExpressibleByFloatLiteral, ExpressibleByIntegerLiteral, AdditiveArithmetic, CustomStringConvertible {

    /// The hue as a fraction of a full turn, always in `0..<1`.
    @usableFromInline
    var storage: Double

    /// The hue as a fraction of a full turn, always in `0..<1`.
    public var rawValue: Double {
        get { storage }
        set { storage = newValue.wrapped(period: 1) }
    }

    /// The hue in degrees, in `0..<360`. Setting a value outside that range wraps around.
    public var degrees: Double {
        get { storage * 360 }
        set { storage = newValue.wrapped(period: 360) / 360 }
    }

    /// The hue in radians, in `0..<2π`. Setting a value outside that range wraps around.
    public var radians: Double {
        get { storage * (2 * .pi) }
        set { degrees = newValue * (180 / .pi) }
    }

    /// Creates a hue from a fraction of a full turn. Values outside `0..<1` wrap around.
    @inlinable
    public init(rawValue: Double) {
        storage = rawValue.wrapped(period: 1)
    }

    /// Creates a hue from a fraction of a full turn, so `0.5` is `180°`.
    @inlinable
    public init(floatLiteral value: Double) {
        self.init(rawValue: value)
    }

    /// Creates a hue from a whole number of turns, which always wraps to `0`.
    ///
    /// Integer literals are turns like float literals, so `1` and `1.0` are the same hue.
    @inlinable
    public init(integerLiteral value: Int) {
        self.init(rawValue: Double(value))
    }

    /// Creates a hue from an angle in degrees, wrapped to `0..<360`.
    @inlinable
    public init(degrees: Double) {
        // Wrap before dividing, which is exact, so that equivalent hues are equal
        storage = degrees.wrapped(period: 360) / 360
    }

    /// Creates a hue from an angle in radians, wrapped to one turn.
    @inlinable
    public init(radians: Double) {
        self.init(degrees: radians * (180 / .pi))
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(rawValue: try container.decode(Double.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    /// The hue in degrees, like `"211.76°"`.
    public var description: String {
        ColorStringFormatter.degrees(self) + "°"
    }

    /// A hue from an angle in degrees, wrapped to `0..<360`.
    public static func degrees(_ degrees: Double) -> ColorHue {
        ColorHue(degrees: degrees)
    }

    /// A hue from an angle in radians, wrapped to one turn.
    public static func radians(_ radians: Double) -> ColorHue {
        ColorHue(radians: radians)
    }

    /// The golden angle, about `137.51°`, which spaces any number of hues nearly
    /// evenly around the color wheel when each is rotated from the last by it.
    public static let goldenAngle = ColorHue(degrees: 180 * (3 - 5.0.squareRoot()))

    /// The hue shared by the HSB and HSL models, from components whose largest value
    /// is `max` and whose range is `delta`. Achromatic colors have a hue of `0`.
    public static func hue(red: Double, green: Double, blue: Double, max: Double, delta: Double) -> ColorHue {
        guard delta > 0 else { return 0 }
        // The position around the color wheel in 60° sectors, `-1..<6`
        let sector: Double
        if max == red {
            sector = (green - blue) / delta
        } else if max == green {
            sector = (blue - red) / delta + 2
        } else {
            sector = (red - green) / delta + 4
        }
        return ColorHue(rawValue: sector.wrapped(period: 6) / 6)
    }

    /// Rotates `lhs` by `rhs`, wrapping around the color wheel.
    public static func + (lhs: ColorHue, rhs: ColorHue) -> ColorHue {
        ColorHue(rawValue: lhs.rawValue + rhs.rawValue)
    }

    /// Rotates `lhs` back by `rhs`, wrapping around the color wheel.
    public static func - (lhs: ColorHue, rhs: ColorHue) -> ColorHue {
        ColorHue(rawValue: lhs.rawValue - rhs.rawValue)
    }

    /// The opposite rotation, so that `hue + -hue` is `0`.
    public static prefix func - (hue: ColorHue) -> ColorHue {
        ColorHue(rawValue: -hue.rawValue)
    }
}

extension Double {

    /// Wraps a value to `0..<period`. Non-finite values become `0`.
    @usableFromInline
    func wrapped(period: Double) -> Double {
        guard isFinite else { return 0 }
        if period == 1, self >= 0, self < period {
            return self
        }
        var wrapped = truncatingRemainder(dividingBy: period)
        if wrapped < 0 {
            wrapped += period
        }
        // Tiny negative values round up to exactly one period
        return wrapped < period ? wrapped : 0
    }
}
