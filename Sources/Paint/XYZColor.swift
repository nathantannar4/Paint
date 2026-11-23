//
// Copyright (c) Nathan Tannar
//

import Foundation
import simd

/// A color in the CIE 1931 XYZ color space with a D65 white point, matching CSS
/// `color(xyz-d65 ...)`.
///
/// `y` is the relative luminance, `1` for sRGB white. XYZ is the connection space
/// between RGB color spaces and CIE Lab.
@frozen
public struct XYZColor: Hashable, Sendable, BitwiseCopyable, Codable, CustomStringConvertible, ColorConvertible {

    /// The X tristimulus value.
    public var x: Double
    /// The Y tristimulus value: relative luminance, `1` for sRGB white.
    public var y: Double
    /// The Z tristimulus value.
    public var z: Double
    /// Opacity, from `0` (transparent) to `1` (opaque).
    public var alpha: Double

    /// Creates a color from CIE XYZ components with a D65 white point.
    @inlinable
    public init(
        x: Double,
        y: Double,
        z: Double,
        alpha: Double = 1
    ) {
        self.x = x
        self.y = y
        self.z = z
        self.alpha = alpha
    }

    /// Converts a color from gamma encoded sRGB components.
    public init(_ rgba: RGBAColor) {
        let xyz = ColorSpaceMatrix.linearSRGBToXYZD65 * rgba.toLinearComponents()
        self.init(x: xyz.x, y: xyz.y, z: xyz.z, alpha: rgba.alpha)
    }

    /// Creates a color from XYZ coordinates relative to a D50 white point, such as
    /// those of CSS `color(xyz-d50 ...)` and ICC profiles.
    public init(d50 x: Double, y: Double, z: Double, alpha: Double = 1) {
        let xyz = ColorSpaceMatrix.d50ToD65 * SIMD3(x, y, z)
        self.init(x: xyz.x, y: xyz.y, z: xyz.z, alpha: alpha)
    }

    /// The components like `"color(xyz-d65 0.2499 0.2111 0.9737)"`, the CSS notation
    /// for CIE XYZ with a D65 white point, with alpha written only when translucent.
    public var description: String {
        ColorStringFormatter.describe("color", ["xyz-d65", ColorStringFormatter.format(x, digits: 4), ColorStringFormatter.format(y, digits: 4), ColorStringFormatter.format(z, digits: 4)], alpha: alpha)
    }

    /// The coordinates adapted to a D50 white point with the Bradford transform.
    public func toD50() -> (x: Double, y: Double, z: Double) {
        let xyz = ColorSpaceMatrix.d65ToD50 * SIMD3(x, y, z)
        return (xyz.x, xyz.y, xyz.z)
    }

    /// The CIE 1931 xy chromaticity, or `nil` for black.
    public func toChromaticity() -> (x: Double, y: Double)? {
        let sum = x + y + z
        guard sum > 0 else { return nil }
        return (x / sum, y / sum)
    }

    public func toRGBAColor() -> RGBAColor {
        RGBAColor(linear: ColorSpaceMatrix.xyzD65ToLinearSRGB * SIMD3(x, y, z), alpha: alpha)
    }

    public func toXYZColor() -> XYZColor {
        self
    }
}
