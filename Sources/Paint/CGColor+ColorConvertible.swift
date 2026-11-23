//
// Copyright (c) Nathan Tannar
//

import CoreGraphics
import simd

extension ColorConvertible {

    /// Converts the color to a `CGColor` in the extended sRGB color space.
    ///
    /// Components outside `0...1` are preserved. HDR colors are tagged with their
    /// ``contentHeadroom`` on iOS 26, macOS 26 and later, so the system tone maps them
    /// for the display.
    ///
    /// Unlike the other platform colors, `CGColor` has no initializer from a
    /// ``ColorConvertible`` color, since Core Foundation types can't be
    /// extended with initializers.
    public func toCGColor() -> CGColor {
        let rgba = toRGBAColor()
        let red = CGFloat(rgba.red)
        let green = CGFloat(rgba.green)
        let blue = CGFloat(rgba.blue)
        let alpha = CGFloat(rgba.alpha)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.extendedSRGB) else {
            return CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
        }
        #if XCODE_26
        if #available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *) {
            let headroom = rgba.contentHeadroom
            if headroom > 1, let cgColor = CGColor(
                headroom: headroom.headroomFloat,
                colorSpace: colorSpace,
                red: red,
                green: green,
                blue: blue,
                alpha: alpha
            ) {
                return cgColor
            }
        }
        #endif
        if let cgColor = CGColor(colorSpace: colorSpace, components: [red, green, blue, alpha]) {
            return cgColor
        }
        return CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }
}

extension CGColor {

    /// Converts the color to gamma encoded sRGB components.
    ///
    /// Colors in the sRGB, Display P3 and Rec. 2020 color spaces, in their linear
    /// and extended variants, are converted at `Double` precision with the CSS Color 4
    /// matrices, so they match ``ColorGamut``. These differ from ColorSync by less
    /// than `1e-3`, since Core Graphics uses slightly different primaries at `Float`
    /// precision. Other color spaces, such as HDR (PQ and HLG) or grayscale color
    /// spaces, are converted with ColorSync, which works at `Float` precision. Colors
    /// outside sRGB are kept as extended sRGB.
    ///
    /// HDR colors keep their brightness, as components above `1`, but not their
    /// content headroom tag, see ``ColorConvertible/contentHeadroom``.
    ///
    /// Returns `nil` if the color can't be converted to sRGB, such as a pattern color.
    public func toRGBAColor() -> RGBAColor? {
        if let rgba = toDirectRGBAColor() {
            return rgba
        }
        guard
            let colorSpace = CGColorSpace(name: CGColorSpace.extendedSRGB),
            let converted = converted(to: colorSpace, intent: .defaultIntent, options: nil),
            let components = converted.components,
            components.count >= 4
        else {
            return nil
        }
        return RGBAColor(
            red: Double(components[0]),
            green: Double(components[1]),
            blue: Double(components[2]),
            alpha: Double(components[3])
        )
    }

    /// Converts the color without ColorSync, at `Double` precision, if it's in an
    /// RGB color space with a known conversion to sRGB. Otherwise `nil`.
    func toDirectRGBAColor() -> RGBAColor? {
        guard
            let colorSpace = colorSpace.flatMap({ ColorSpace($0) }),
            let components,
            components.count == 4
        else {
            return nil
        }
        return RGBAColor(
            red: Double(components[0]),
            green: Double(components[1]),
            blue: Double(components[2]),
            alpha: Double(components[3]),
            colorSpace: colorSpace
        )
    }
}
