//
// Copyright (c) Nathan Tannar
//

import Foundation

/// A color in CIE Lab (CIELAB) with a D50 white point, matching CSS `lab()`.
///
/// - `lightness`: `0` (black) to `100` (white).
/// - `a`: the green (negative) to red (positive) axis, about `-125...125`.
/// - `b`: the blue (negative) to yellow (positive) axis, about `-125...125`.
///
/// Prefer ``OKLabColor`` for generating colors, since CIE Lab shifts hue as chroma
/// changes, especially for blues. CIE Lab is used for interoperability and for
/// ``CIELabColor/deltaE2000(_:_:)``.
@frozen
public struct CIELabColor: Hashable, Sendable, BitwiseCopyable, Codable, CustomStringConvertible, ColorConvertible {

    /// Lightness, from `0` (black) to `100` (white).
    public var lightness: Double
    /// The green (negative) to red (positive) axis, about `-125...125`.
    public var a: Double
    /// The blue (negative) to yellow (positive) axis, about `-125...125`.
    public var b: Double
    /// Opacity, from `0` (transparent) to `1` (opaque).
    public var alpha: Double

    /// Creates a color from CIE Lab components with a D50 white point.
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
        self.init(XYZColor(rgba))
    }

    /// Converts a color from CIE XYZ, adapting it from D65 to D50.
    @inlinable
    public init(_ xyz: XYZColor) {
        let d50 = xyz.toD50()
        let fx = Self.f(d50.x / Self.white.x)
        let fy = Self.f(d50.y / Self.white.y)
        let fz = Self.f(d50.z / Self.white.z)
        self.init(
            lightness: 116 * fy - 16,
            a: 500 * (fx - fy),
            b: 200 * (fy - fz),
            alpha: xyz.alpha
        )
    }

    /// Converts a color from CIE LCh, the cylindrical form of CIE Lab.
    @inlinable
    public init(_ lch: CIELCHColor) {
        let radians = lch.hue.radians
        self.init(
            lightness: lch.lightness,
            a: lch.chroma * cos(radians),
            b: lch.chroma * sin(radians),
            alpha: lch.alpha
        )
    }

    /// The components like `"lab(51.82 12.2 -75.32)"`, with alpha written only when
    /// translucent.
    public var description: String {
        ColorStringFormatter.describe("lab", [ColorStringFormatter.format(lightness, digits: 2), ColorStringFormatter.format(a, digits: 2), ColorStringFormatter.format(b, digits: 2)], alpha: alpha)
    }

    public func toXYZColor() -> XYZColor {
        let fy = (lightness + 16) / 116
        let fx = fy + a / 500
        let fz = fy - b / 200
        let x = Self.inverseF(fx) * Self.white.x
        let y = (lightness > Self.kappa * Self.epsilon ? fy * fy * fy : lightness / Self.kappa) * Self.white.y
        let z = Self.inverseF(fz) * Self.white.z
        return XYZColor(d50: x, y: y, z: z, alpha: alpha)
    }

    public func toRGBAColor() -> RGBAColor {
        toXYZColor().toRGBAColor()
    }

    public func toCIELabColor() -> CIELabColor {
        self
    }

    /// Converts to CIE LCh directly, without a round trip through sRGB.
    public func toCIELCHColor() -> CIELCHColor {
        CIELCHColor(self)
    }

    /// The D50 white point used by CSS.
    public static let white = (x: 0.3457 / 0.3585, y: 1.0, z: (1.0 - 0.3457 - 0.3585) / 0.3585)
    public static let epsilon = 216.0 / 24389.0
    public static let kappa = 24389.0 / 27.0

    public static func f(_ t: Double) -> Double {
        t > epsilon ? cbrt(t) : (kappa * t + 16) / 116
    }

    public static func inverseF(_ t: Double) -> Double {
        let cube = t * t * t
        return cube > epsilon ? cube : (116 * t - 16) / kappa
    }
}

/// A color in CIE LCh, the cylindrical form of ``CIELabColor``, matching CSS `lch()`.
///
/// - `lightness`: `0` (black) to `100` (white).
/// - `chroma`: colorfulness, `0` for grays, up to about `150`.
/// - `hue`: hue angle.
@frozen
public struct CIELCHColor: Hashable, Sendable, BitwiseCopyable, Codable, CustomStringConvertible, ColorConvertible {

    /// Lightness, from `0` (black) to `100` (white).
    public var lightness: Double
    /// Colorfulness, `0` for grays, up to about `150`.
    public var chroma: Double
    /// The hue angle.
    public var hue: ColorHue
    /// Opacity, from `0` (transparent) to `1` (opaque).
    public var alpha: Double

    /// Creates a color from CIE LCh components with a D50 white point.
    @inlinable
    public init(
        lightness: Double,
        chroma: Double,
        hue: ColorHue,
        alpha: Double = 1
    ) {
        self.lightness = lightness
        self.chroma = chroma
        self.hue = hue
        self.alpha = alpha
    }

    /// Converts a color from gamma encoded sRGB components.
    @inlinable
    public init(_ rgba: RGBAColor) {
        self.init(CIELabColor(rgba))
    }

    /// Converts from CIE Lab. Colors with a chroma below `1e-4` have a hue of `0`.
    @inlinable
    public init(_ lab: CIELabColor) {
        let chroma = (lab.a * lab.a + lab.b * lab.b).squareRoot()
        self.init(
            lightness: lab.lightness,
            chroma: chroma < 1e-4 ? 0 : chroma,
            hue: chroma < 1e-4 ? 0 : .radians(atan2(lab.b, lab.a)),
            alpha: lab.alpha
        )
    }

    /// The components like `"lch(51.82 76.31 279.2)"`, with the hue in degrees, and
    /// alpha written only when translucent.
    public var description: String {
        ColorStringFormatter.describe("lch", [ColorStringFormatter.format(lightness, digits: 2), ColorStringFormatter.format(chroma, digits: 2), ColorStringFormatter.degrees(hue)], alpha: alpha)
    }

    public func toRGBAColor() -> RGBAColor {
        CIELabColor(self).toRGBAColor()
    }

    /// Converts to CIE Lab directly, without a round trip through sRGB.
    public func toCIELabColor() -> CIELabColor {
        CIELabColor(self)
    }

    public func toXYZColor() -> XYZColor {
        CIELabColor(self).toXYZColor()
    }

    public func toCIELCHColor() -> CIELCHColor {
        self
    }
}
