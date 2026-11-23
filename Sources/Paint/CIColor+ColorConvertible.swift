//
// Copyright (c) Nathan Tannar
//

#if canImport(CoreImage)
import CoreImage

extension ColorConvertible {

    /// Converts the color to a `CIColor` in the extended sRGB color space.
    ///
    /// Components outside `0...1` are preserved.
    public func toCIColor() -> CIColor {
        CIColor(self)
    }
}

extension CIColor {

    /// Creates a `CIColor` in the extended sRGB color space from any ``ColorConvertible`` color.
    ///
    /// Components outside `0...1` are preserved.
    public convenience init<C: ColorConvertible>(_ color: C) {
        self.init(cgColor: color.toCGColor())
    }

    /// Converts the color to gamma encoded sRGB components.
    ///
    /// Colors already in sRGB or extended sRGB are read directly. Other color spaces,
    /// including the linear color spaces Core Image often works in, are converted.
    ///
    /// Returns `nil` if the color can't be converted to sRGB.
    public func toRGBAColor() -> RGBAColor? {
        if let name = colorSpace.name,
           name == CGColorSpace.sRGB || name == CGColorSpace.extendedSRGB,
           numberOfComponents == 4
        {
            return RGBAColor(red: Double(red), green: Double(green), blue: Double(blue), alpha: Double(alpha))
        }
        return CGColor(colorSpace: colorSpace, components: components)?.toRGBAColor()
    }
}
#endif
