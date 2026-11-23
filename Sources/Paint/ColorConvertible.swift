//
// Copyright (c) Nathan Tannar
//

import Foundation
import simd

/// A color that can be converted to every color model: ``HEXColor``, ``RGBAColor``,
/// ``HSBAColor``, ``HSLAColor``, ``HWBColor``, ``CMYKColor``, ``OKLCHColor``,
/// ``OKLabColor``, ``XYZColor``, ``CIELabColor``, ``CIELCHColor`` and ``CSSColor``.
///
/// Conversions go through gamma encoded sRGB (``RGBAColor``), apart from a few
/// direct paths such as ``HSBAColor`` to ``HSLAColor``. Floating point models
/// keep values outside `0...1` (extended sRGB, i.e. colors outside the sRGB
/// gamut). ``HEXColor`` and ``CMYKColor`` are the exceptions: they're limited to sRGB.
///
/// SwiftUI `Color`, `CIColor`, `UIColor` and `NSColor` can be created from any
/// `ColorConvertible`, and `CGColor` with `toCGColor()`. Each converts back
/// with `toRGBAColor()`.
public protocol ColorConvertible: Sendable {

    /// Converts the color to gamma encoded sRGB components.
    func toRGBAColor() -> RGBAColor

    /// Converts the color to a packed 8-bit per channel ``HEXColor``.
    ///
    /// Channels are rounded to the nearest 8-bit value. Colors outside sRGB are gamut
    /// mapped, keeping their lightness and hue.
    func toHEXColor() -> HEXColor

    /// Converts the color to hue, saturation and brightness components.
    func toHSBAColor() -> HSBAColor

    /// Converts the color to hue, saturation and lightness components.
    func toHSLAColor() -> HSLAColor

    /// Converts the color to hue, whiteness and blackness components.
    func toHWBColor() -> HWBColor

    /// Converts the color to naive cyan, magenta, yellow and black components.
    func toCMYKColor() -> CMYKColor

    /// Converts the color to OKLCH: Oklab lightness, chroma and hue.
    func toOKLCHColor() -> OKLCHColor

    /// Converts the color to Cartesian Oklab coordinates.
    func toOKLabColor() -> OKLabColor

    /// Converts the color to CIE XYZ with a D65 white point.
    func toXYZColor() -> XYZColor

    /// Converts the color to CIE Lab with a D50 white point.
    func toCIELabColor() -> CIELabColor

    /// Converts the color to CIE LCh with a D50 white point.
    func toCIELCHColor() -> CIELCHColor

    /// Converts the color to a ``CSSColor``, written as `rgb()` when it's in sRGB, and
    /// as `oklch()` otherwise, so colors outside sRGB aren't clipped.
    ///
    /// Use ``toCSSColor(_:)`` to choose the format.
    func toCSSColor() -> CSSColor

    /// Converts the color to a ``ColorTransform`` that multiplies each component by the
    /// components of the color.
    ///
    /// Equivalent to `colorMultiply(_:)` and ``ColorTransform/init(color:in:)``.
    func toColorTransform() -> ColorTransform

    /// Fits the color in a gamut by reducing its OKLCH chroma, keeping its lightness
    /// and hue, as in CSS Color 4 gamut mapping.
    ///
    /// Colors already in the gamut are returned unchanged.
    func toColorGamut(_ gamut: ColorGamut) -> Self

    /// Returns the color with its alpha multiplied by `opacity`, like SwiftUI's
    /// `Color.opacity(_:)`.
    ///
    /// The resulting alpha is clamped to `0...1`, so an `opacity` above `1` makes the
    /// color more opaque: an alpha of `0.5` with an `opacity` of `2` becomes `1`.
    func opacity(_ opacity: Double) -> Self
}

extension ColorConvertible {

    public func toHEXColor() -> HEXColor {
        HEXColor(toRGBAColor())
    }

    public func toHSBAColor() -> HSBAColor {
        HSBAColor(toRGBAColor())
    }

    public func toHSLAColor() -> HSLAColor {
        HSLAColor(toRGBAColor())
    }

    public func toHWBColor() -> HWBColor {
        HWBColor(toHSBAColor())
    }

    public func toCMYKColor() -> CMYKColor {
        CMYKColor(toRGBAColor())
    }

    public func toOKLCHColor() -> OKLCHColor {
        OKLCHColor(toRGBAColor())
    }

    public func toOKLabColor() -> OKLabColor {
        OKLabColor(toOKLCHColor())
    }

    public func toXYZColor() -> XYZColor {
        XYZColor(toRGBAColor())
    }

    public func toCIELabColor() -> CIELabColor {
        CIELabColor(toXYZColor())
    }

    public func toCIELCHColor() -> CIELCHColor {
        CIELCHColor(toCIELabColor())
    }

    public func toCSSColor() -> CSSColor {
        CSSColor(self)
    }

    public func toColorTransform() -> ColorTransform {
        let rgba = toRGBAColor()
        let red = Float(rgba.red)
        let green = Float(rgba.green)
        let blue = Float(rgba.blue)
        let alpha = Float(rgba.alpha)
        return ColorTransform(r1: red, g2: green, b3: blue, a4: alpha)
    }
}

// MARK: - ColorTransform

extension ColorConvertible {

    /// Transforms the color with a ``ColorTransform``, matching the `colorMatrix(_:)` view modifier.
    ///
    /// The matrix is applied to the gamma encoded sRGB components, the same components
    /// `colorMatrix(_:)` transforms. Results outside `0...1` are preserved, as extended sRGB.
    public func applying(_ matrix: ColorTransform) -> RGBAColor {
        let rgba = toRGBAColor()
        // Computed in `Double`, so the color keeps its precision
        let columns = matrix.transform.columns
        let result = SIMD4<Double>(columns.0) * rgba.red
            + SIMD4<Double>(columns.1) * rgba.green
            + SIMD4<Double>(columns.2) * rgba.blue
            + SIMD4<Double>(columns.3) * rgba.alpha
            + SIMD4<Double>(matrix.offset)
        return RGBAColor(red: result.x, green: result.y, blue: result.z, alpha: result.w)
    }
}
