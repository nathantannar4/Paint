//
// Copyright (c) Nathan Tannar
//

import Foundation

extension RGBAColor {

    @inlinable
    public func opacity(_ opacity: Double) -> RGBAColor {
        var color = self
        color.alpha = alpha.opacity(opacity)
        return color
    }
}

extension HSBAColor {

    @inlinable
    public func opacity(_ opacity: Double) -> HSBAColor {
        var color = self
        color.alpha = alpha.opacity(opacity)
        return color
    }
}

extension HSLAColor {

    @inlinable
    public func opacity(_ opacity: Double) -> HSLAColor {
        var color = self
        color.alpha = alpha.opacity(opacity)
        return color
    }
}

extension HWBColor {

    @inlinable
    public func opacity(_ opacity: Double) -> HWBColor {
        var color = self
        color.alpha = alpha.opacity(opacity)
        return color
    }
}

extension CMYKColor {

    @inlinable
    public func opacity(_ opacity: Double) -> CMYKColor {
        var color = self
        color.alpha = alpha.opacity(opacity)
        return color
    }
}

extension OKLCHColor {

    @inlinable
    public func opacity(_ opacity: Double) -> OKLCHColor {
        var color = self
        color.alpha = alpha.opacity(opacity)
        return color
    }
}

extension OKLabColor {

    @inlinable
    public func opacity(_ opacity: Double) -> OKLabColor {
        var color = self
        color.alpha = alpha.opacity(opacity)
        return color
    }
}

extension XYZColor {

    @inlinable
    public func opacity(_ opacity: Double) -> XYZColor {
        var color = self
        color.alpha = alpha.opacity(opacity)
        return color
    }
}

extension CIELabColor {

    @inlinable
    public func opacity(_ opacity: Double) -> CIELabColor {
        var color = self
        color.alpha = alpha.opacity(opacity)
        return color
    }
}

extension CIELCHColor {

    @inlinable
    public func opacity(_ opacity: Double) -> CIELCHColor {
        var color = self
        color.alpha = alpha.opacity(opacity)
        return color
    }
}

extension HEXColor {

    /// Returns the color with its alpha multiplied by `opacity`, clamped to `0...1`,
    /// and rounded to the nearest 8-bit value.
    @inlinable
    public func opacity(_ opacity: Double) -> HEXColor {
        var color = self
        let alpha = (Double(alpha) / 255).opacity(opacity) * 255
        color.alpha = alpha.isNaN ? 0 : UInt8(alpha.rounded())
        return color
    }
}

extension CSSColor {

    /// Returns the color with its alpha multiplied by `opacity`, clamped to `0...1`.
    ///
    /// The color is written again in the format of its string where it's one of the
    /// ``CSSColorFormat`` formats, such as `oklch()`, and as `rgb()` or `oklch()`
    /// otherwise, as named colors have no alpha. A color whose alpha doesn't change,
    /// such as with an `opacity` of `1`, is returned unchanged, keeping its string.
    public func opacity(_ opacity: Double) -> CSSColor {
        let original = toRGBAColor()
        let rgba = original.opacity(opacity)
        guard rgba.alpha != original.alpha else { return self }
        guard let format else {
            return CSSColor(rgba)
        }
        return CSSColor(rgba, format: format)
    }
}
