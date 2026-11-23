//
// Copyright (c) Nathan Tannar
//

import Foundation

/// A color in the [Oklab](https://bottosson.github.io/posts/oklab/) perceptual color
/// space, matching CSS `oklab()`.
///
/// - `lightness`: perceived lightness, `0` (black) to `1` (white).
/// - `a`: the green (negative) to red (positive) axis.
/// - `b`: the blue (negative) to yellow (positive) axis.
///
/// Oklab is the Cartesian form of ``OKLCHColor``. Euclidean distances in Oklab
/// approximate how different two colors look, see ``ColorConvertible/distance(to:)``.
@frozen
public struct OKLabColor: Hashable, Sendable, BitwiseCopyable, Codable, CustomStringConvertible, ColorConvertible {

    /// Perceived lightness, from `0` (black) to `1` (white).
    public var lightness: Double
    /// The green (negative) to red (positive) axis.
    public var a: Double
    /// The blue (negative) to yellow (positive) axis.
    public var b: Double
    /// Opacity, from `0` (transparent) to `1` (opaque).
    public var alpha: Double

    /// The Oklab chroma, the distance from the gray axis.
    public var chroma: Double {
        (a * a + b * b).squareRoot()
    }

    /// Creates a color from Oklab components.
    @inlinable
    public init(
        lightness: Double,
        a: Double,
        b: Double,
        alpha: Double = 1
    ) {
        self.lightness = lightness
        self.a = a
        self.b = b
        self.alpha = alpha
    }

    /// Converts a color from gamma encoded sRGB components.
    @inlinable
    public init(_ rgba: RGBAColor) {
        self.init(OKLCHColor(rgba))
    }

    /// Converts a color from OKLCH, the cylindrical form of Oklab.
    @inlinable
    public init(_ oklch: OKLCHColor) {
        self.init(lightness: oklch.lightness, a: oklch.a, b: oklch.b, alpha: oklch.alpha)
    }

    /// The components like `"oklab(0.6025 -0.0473 -0.2126)"`, with alpha written
    /// only when translucent.
    public var description: String {
        ColorStringFormatter.describe("oklab", [ColorStringFormatter.format(lightness, digits: 4), ColorStringFormatter.format(a, digits: 4), ColorStringFormatter.format(b, digits: 4)], alpha: alpha)
    }

    public func toRGBAColor() -> RGBAColor {
        toOKLCHColor().toRGBAColor()
    }

    public func toOKLCHColor() -> OKLCHColor {
        OKLCHColor(lightness: lightness, a: a, b: b, alpha: alpha)
    }

    public func toOKLabColor() -> OKLabColor {
        self
    }
}
