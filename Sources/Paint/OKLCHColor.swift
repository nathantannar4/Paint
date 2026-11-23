//
// Copyright (c) Nathan Tannar
//

import Foundation

/// A color in OKLCH, the cylindrical form of the [Oklab](https://bottosson.github.io/posts/oklab/)
/// perceptual color space, matching CSS `oklch()`.
///
/// - `lightness`: perceived lightness, `0` (black) to `1` (white).
/// - `chroma`: colorfulness, `0` for grays. sRGB colors reach about `0.32`.
/// - `hue`: hue angle.
///
/// The Cartesian Oklab coordinates are available as ``a`` and ``b``.
@frozen
public struct OKLCHColor: Hashable, Sendable, BitwiseCopyable, Codable, CustomStringConvertible, ColorConvertible {

    /// Perceived lightness, from `0` (black) to `1` (white).
    public var lightness: Double
    /// Colorfulness, `0` for grays. sRGB colors reach about `0.32`.
    public var chroma: Double
    /// The hue angle.
    public var hue: ColorHue
    /// Opacity, from `0` (transparent) to `1` (opaque).
    public var alpha: Double

    /// The green-red axis of the Cartesian Oklab coordinates.
    public var a: Double {
        chroma * cos(hue.radians)
    }

    /// The blue-yellow axis of the Cartesian Oklab coordinates.
    public var b: Double {
        chroma * sin(hue.radians)
    }

    /// Creates a color from OKLCH components.
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

    /// Creates a color from Cartesian Oklab coordinates.
    ///
    /// Colors with a chroma below `1e-6` are treated as achromatic, with a chroma
    /// and hue of `0`, since their hue is floating point noise.
    @inlinable
    public init(
        lightness: Double,
        a: Double,
        b: Double,
        alpha: Double = 1
    ) {
        let chroma = (a * a + b * b).squareRoot()
        // Below this chroma the hue is floating point noise, e.g. sRGB white has a chroma near 4e-8.
        if chroma < 1e-6 {
            self.init(lightness: lightness, chroma: 0, hue: 0, alpha: alpha)
        } else {
            self.init(lightness: lightness, chroma: chroma, hue: .radians(atan2(b, a)), alpha: alpha)
        }
    }

    /// Converts a color from gamma encoded sRGB components.
    public init(_ rgba: RGBAColor) {
        let cartesian = CartesianCoordinates(LMS(LinearSRGB(rgba)))
        self.init(lightness: cartesian.lightness, a: cartesian.a, b: cartesian.b, alpha: rgba.alpha)
    }

    /// The components like `"oklch(0.6025 0.2178 257.45)"`, with the hue in degrees,
    /// and alpha written only when translucent.
    public var description: String {
        ColorStringFormatter.describe("oklch", [ColorStringFormatter.format(lightness, digits: 4), ColorStringFormatter.format(chroma, digits: 4), ColorStringFormatter.degrees(hue)], alpha: alpha)
    }

    public func toRGBAColor() -> RGBAColor {
        linearSRGB.toRGBAColor(alpha: alpha)
    }

    public func toOKLCHColor() -> OKLCHColor {
        self
    }

    // MARK: Conversion Pipeline

    // sRGB  <->  LinearSRGB  <->  LMS  <->  CartesianCoordinates (lightness, a, b)  <->  OKLCH

    /// The color in linear sRGB, computing the hue's sine and cosine once.
    var linearSRGB: LinearSRGB {
        LinearSRGB(LMS(CartesianCoordinates(lightness: lightness, chroma: chroma, direction: HueDirection(hue: hue))))
    }

    /// The unit vector of a hue angle.
    struct HueDirection {
        var cos: Double
        var sin: Double

        init(hue: ColorHue) {
            let radians = hue.radians
            self.cos = Foundation.cos(radians)
            self.sin = Foundation.sin(radians)
        }
    }

    /// Linear light sRGB components, before the sRGB transfer function.
    struct LinearSRGB {
        var red: Double
        var green: Double
        var blue: Double

        init(red: Double, green: Double, blue: Double) {
            self.red = red
            self.green = green
            self.blue = blue
        }

        init(_ rgba: RGBAColor) {
            self.init(
                red: RGBAColor.linearize(rgba.red),
                green: RGBAColor.linearize(rgba.green),
                blue: RGBAColor.linearize(rgba.blue)
            )
        }

        /// Converts linear LMS cone responses to linear sRGB.
        init(_ lms: LMS) {
            let l = lms.l * lms.l * lms.l
            let m = lms.m * lms.m * lms.m
            let s = lms.s * lms.s * lms.s
            self.init(
                red: 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
                green: -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
                blue: -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
            )
        }

        @usableFromInline
        func toRGBAColor(alpha: Double) -> RGBAColor {
            RGBAColor(
                red: RGBAColor.delinearize(red),
                green: RGBAColor.delinearize(green),
                blue: RGBAColor.delinearize(blue),
                alpha: alpha
            )
        }
    }

    /// Non-linear cone responses: the cube root of the LMS values, from which
    /// the Oklab coordinates are a linear transform.
    struct LMS {
        var l: Double
        var m: Double
        var s: Double

        /// Converts linear sRGB to non-linear LMS cone responses.
        init(_ linear: LinearSRGB) {
            self.l = cbrt(0.4122214708 * linear.red + 0.5363325363 * linear.green + 0.0514459929 * linear.blue)
            self.m = cbrt(0.2119034982 * linear.red + 0.6806995451 * linear.green + 0.1073969566 * linear.blue)
            self.s = cbrt(0.0883024619 * linear.red + 0.2817188376 * linear.green + 0.6299787005 * linear.blue)
        }

        /// Converts Cartesian Oklab coordinates to non-linear LMS cone responses.
        init(_ cartesian: CartesianCoordinates) {
            self.l = cartesian.lightness + 0.3963377774 * cartesian.a + 0.2158037573 * cartesian.b
            self.m = cartesian.lightness - 0.1055613458 * cartesian.a - 0.0638541728 * cartesian.b
            self.s = cartesian.lightness - 0.0894841775 * cartesian.a - 1.2914855480 * cartesian.b
        }
    }

    /// Cartesian Oklab coordinates.
    struct CartesianCoordinates {
        var lightness: Double
        var a: Double
        var b: Double

        /// Converts polar OKLCH coordinates to Cartesian.
        init(lightness: Double, chroma: Double, direction: HueDirection) {
            self.lightness = lightness
            self.a = chroma * direction.cos
            self.b = chroma * direction.sin
        }

        /// Converts non-linear LMS cone responses to Oklab.
        init(_ lms: LMS) {
            self.lightness = 0.2104542553 * lms.l + 0.7936177850 * lms.m - 0.0040720468 * lms.s
            self.a = 1.9779984951 * lms.l - 2.4285922050 * lms.m + 0.4505937099 * lms.s
            self.b = 0.0259040371 * lms.l + 0.7827717662 * lms.m - 0.8086757660 * lms.s
        }
    }
}
