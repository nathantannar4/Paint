//
// Copyright (c) Nathan Tannar
//

import Foundation
import simd

extension ColorConvertible {

    /// How much brighter than SDR white the color is, as a linear multiplier: `1`
    /// for standard dynamic range (SDR) colors, and more for high dynamic range (HDR)
    /// colors.
    ///
    /// This is the largest linear light component of the color in Rec. 2020, the
    /// largest gamut ``ColorGamut`` supports, so wide gamut colors, such as Display P3
    /// colors with sRGB components above `1`, aren't mistaken for HDR. For example,
    /// sRGB `(2, 2, 2)` has a headroom of about `4.95`.
    ///
    /// Platform colors created from an HDR color, such as `UIColor`, `NSColor`,
    /// `CGColor` and SwiftUI `Color`, are tagged with this headroom where supported,
    /// so the system can tone map them for the display. Non-finite colors are `1`.
    public var contentHeadroom: Double {
        let linear = ColorSpaceMatrix.linearSRGBToLinearRec2020 * toRGBAColor().toLinearComponents()
        let peak = linear.max()
        // Floating point error in white and Rec. 2020 primaries isn't HDR
        guard peak.isFinite, peak > 1 + 1e-4 else { return 1 }
        return peak
    }

    /// Whether the color is brighter than SDR white, so its ``contentHeadroom`` is
    /// more than `1`.
    public var isHDR: Bool {
        contentHeadroom > 1
    }

    /// Converts the color to the SDR color that ``contentHeadroom`` brightens into
    /// it: the color with its linear light components divided by its headroom.
    ///
    /// Use this as a fallback where HDR isn't supported. Hue and chromaticity are
    /// kept, so wide gamut colors can have sRGB components above `1`. The
    /// `standardDynamicRange` of `UIColor` divides by the same headroom, matching this,
    /// while the one of `NSColor` then clamps to sRGB. SDR colors are returned unchanged.
    public func toStandardDynamicRange() -> RGBAColor {
        let rgba = toRGBAColor()
        let headroom = rgba.contentHeadroom
        guard headroom > 1 else { return rgba }
        return RGBAColor(linear: rgba.toLinearComponents() / headroom, alpha: rgba.alpha)
    }
}

extension Double {

    /// The headroom as a `Float`, rounded up so that it's never below the peak of
    /// the color, which would clip the color's SDR fallback.
    var headroomFloat: Float {
        let headroom = Float(self)
        return Double(headroom) < self ? headroom.nextUp : headroom
    }
}
