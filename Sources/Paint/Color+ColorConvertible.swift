//
// Copyright (c) Nathan Tannar
//

import SwiftUI

extension ColorConvertible {

    /// Converts the color to a SwiftUI `Color` in the sRGB color space.
    ///
    /// Components outside `0...1` are preserved, as extended sRGB. HDR colors are
    /// tagged with their ``contentHeadroom`` on iOS 26, macOS 26 and later.
    /// SwiftUI stores the components at `Float` precision.
    public func toColor() -> Color {
        Color(self)
    }
}

extension Color {

    /// Creates a SwiftUI `Color` in the sRGB color space from any ``ColorConvertible`` color.
    ///
    /// Components outside `0...1` are preserved, as extended sRGB. On iOS 26, macOS 26
    /// and later, HDR colors are tagged with their ``ColorConvertible/contentHeadroom``,
    /// as a `Color.ResolvedHDR`, so the system tone maps them for the display.
    /// SwiftUI stores the components at `Float` precision.
    public init<C: ColorConvertible>(_ color: C) {
        let rgba = color.toRGBAColor()
        #if XCODE_26
        if #available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *), rgba.isHDR {
            let resolved = Color.Resolved(
                colorSpace: .sRGB,
                red: Float(rgba.red),
                green: Float(rgba.green),
                blue: Float(rgba.blue),
                opacity: Float(rgba.alpha)
            )
            self.init(Color.ResolvedHDR(resolved, headroom: rgba.contentHeadroom.headroomFloat))
            return
        }
        #endif
        self.init(
            .sRGB,
            red: rgba.red,
            green: rgba.green,
            blue: rgba.blue,
            opacity: rgba.alpha
        )
    }
}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension Color {

    /// Converts the color to gamma encoded sRGB components, without resolving it.
    ///
    /// Only colors backed by a `CGColor`, such as `Color(.sRGB, ...)` or `Color(cgColor:)`,
    /// can be converted this way. System and adaptive colors such as `.red` and `.primary`,
    /// and colors with SwiftUI modifiers such as `exposureAdjust(_:)`, return `nil`,
    /// since they depend on the environment. Use ``toRGBAColor(in:)``.
    public func toRGBAColor() -> RGBAColor? {
        guard let cgColor else { return nil }
        return cgColor.toRGBAColor()
    }

    /// Resolves the color in an environment and converts it to gamma encoded sRGB
    /// components.
    ///
    /// On iOS 26, macOS 26 and later, HDR colors keep their brightness, as components
    /// above `1`, including colors brightened with `exposureAdjust(_:)`, which
    /// `resolve(in:)` clips to SDR. Earlier, HDR colors are clipped to SDR.
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    public func toRGBAColor(in environment: EnvironmentValues) -> RGBAColor {
        #if XCODE_26
        if #available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *) {
            let resolved = resolveHDR(in: environment)
            return RGBAColor(
                red: Double(resolved.red),
                green: Double(resolved.green),
                blue: Double(resolved.blue),
                alpha: Double(resolved.opacity)
            )
        }
        #endif
        let resolved = resolve(in: environment)
        return RGBAColor(
            red: Double(resolved.red),
            green: Double(resolved.green),
            blue: Double(resolved.blue),
            alpha: Double(resolved.opacity)
        )
    }

    /// Resolves the color in an environment and converts it to a ``ColorTransform`` that
    /// multiplies each component by the components of the color.
    ///
    /// Equivalent to `colorMultiply(_:)` and ``ColorTransform/init(color:in:)``. Unlike
    /// ``toRGBAColor(in:)``, this is available before iOS 17.
    public func toColorTransform(in environment: EnvironmentValues) -> ColorTransform {
        ColorTransform(color: self, in: environment)
    }
}
