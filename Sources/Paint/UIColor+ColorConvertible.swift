//
// Copyright (c) Nathan Tannar
//

#if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
import UIKit

extension ColorConvertible {

    /// Converts the color to a `UIColor` in the sRGB color space.
    ///
    /// Components outside `0...1` are preserved, as extended sRGB. HDR colors are
    /// tagged with their ``contentHeadroom`` on iOS 26 and later.
    public func toUIColor() -> UIColor {
        UIColor(self)
    }
}

extension UIColor {

    /// Creates a `UIColor` in the sRGB color space from any ``ColorConvertible`` color.
    ///
    /// Components outside `0...1` are preserved, as extended sRGB. On iOS 26 and
    /// later, HDR colors are tagged with their ``ColorConvertible/contentHeadroom``,
    /// which sets `linearExposure` and `standardDynamicRange`, so the system
    /// tone maps them for the display.
    ///
    /// On watchOS devices with 32-bit pointers, `CGFloat` is a `Float`, so components
    /// are stored at `Float` precision.
    public convenience init<C: ColorConvertible>(_ color: C) {
        let rgba = color.toRGBAColor()
        if #available(iOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *), rgba.isHDR {
            // Unlike `init(red:green:blue:alpha:linearExposure:)`, which computes the
            // components at `Float` precision, this keeps them exactly
            self.init(cgColor: rgba.toCGColor())
        } else {
            self.init(
                red: rgba.red,
                green: rgba.green,
                blue: rgba.blue,
                alpha: rgba.alpha
            )
        }
    }
}

extension UIColor {

    /// Creates a dynamic color with a color for each appearance.
    ///
    /// Pair it with ``ColorConvertible/adapted(from:to:in:)`` and
    /// ``ColorContrast/increased(against:by:in:)`` to derive the
    /// variants from one color:
    ///
    /// ```swift
    /// let accent = HEXColor("#0A84FF")
    /// let color = UIColor(
    ///     light: accent,
    ///     dark: accent.adapted(from: HEXColor("#FFFFFF"), to: HEXColor("#000000"))
    /// )
    /// ```
    ///
    /// Increased contrast variants default to the matching appearance. watchOS has
    /// no dynamic colors, so the dark color is used, matching its dark appearance.
    public convenience init<
        Light: ColorConvertible,
        Dark: ColorConvertible
    >(
        light: Light,
        dark: Dark
    ) {
        #if os(watchOS)
        self.init(dark)
        #else
        let light = light.toRGBAColor()
        let dark = dark.toRGBAColor()
        self.init { traitCollection in
            let isDark = traitCollection.userInterfaceStyle == .dark
            return isDark ? UIColor(dark) : UIColor(light)
        }
        #endif
    }

    /// Creates a dynamic color with a color for each appearance, and
    /// each appearance with increased contrast.
    ///
    /// Pair it with ``ColorConvertible/adapted(from:to:in:)`` and
    /// ``ColorContrast/increased(against:by:in:)`` to derive the
    /// variants from one color:
    ///
    /// ```swift
    /// let accent = HEXColor("#0A84FF")
    /// let color = UIColor(
    ///     light: accent,
    ///     dark: accent.adapted(from: HEXColor("#FFFFFF"), to: HEXColor("#000000"))
    /// )
    /// ```
    ///
    /// Increased contrast variants default to the matching appearance. watchOS has
    /// no dynamic colors, so the dark color is used, matching its dark appearance.
    @available(watchOS, unavailable)
    public convenience init<
        Light: ColorConvertible,
        Dark: ColorConvertible,
        LightHighContrast: ColorConvertible,
        DarkHighContrast: ColorConvertible
    >(
        light: Light,
        dark: Dark,
        lightHighContrast: LightHighContrast,
        darkHighContrast: DarkHighContrast
    ) {
        #if os(watchOS)
        self.init(dark)
        #else
        let light = light.toRGBAColor()
        let dark = dark.toRGBAColor()
        let lightHighContrast = lightHighContrast.toRGBAColor()
        let darkHighContrast = darkHighContrast.toRGBAColor()
        self.init { traitCollection in
            let isDark = traitCollection.userInterfaceStyle == .dark
            let isHighContrast = traitCollection.accessibilityContrast == .high
            switch (isDark, isHighContrast) {
            case (false, false): return UIColor(light)
            case (true, false): return UIColor(dark)
            case (false, true): return UIColor(lightHighContrast)
            case (true, true): return UIColor(darkHighContrast)
            }
        }
        #endif
    }

    /// Converts the color to gamma encoded sRGB components.
    ///
    /// Dynamic colors are resolved with `UITraitCollection.current`. Use
    /// `toRGBAColor(compatibleWith:)` to resolve for specific traits.
    /// watchOS has no dynamic colors.
    ///
    /// Display P3 and Rec. 2020 colors are converted at `Double` precision, see
    /// `CGColor.toRGBAColor()`. Note that `UIColor(displayP3Red:green:blue:alpha:)`
    /// itself converts to extended sRGB at `Float` precision, unlike a `UIColor`
    /// created from a Display P3 `CGColor`. HDR colors keep their brightness, as
    /// components above `1`.
    ///
    /// Returns `nil` if the color can't be converted to sRGB, such as a pattern color.
    public func toRGBAColor() -> RGBAColor? {
        // Read known RGB color spaces directly, at `Double` precision with the same
        // matrices as the rest of the library
        if let rgba = cgColor.toDirectRGBAColor() {
            return rgba
        }
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        // Returns extended sRGB components, at full precision
        if getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return RGBAColor(
                red: Double(red),
                green: Double(green),
                blue: Double(blue),
                alpha: Double(alpha)
            )
        }
        return cgColor.toRGBAColor()
    }

    #if !os(watchOS)
    /// Resolves the color for a trait collection and converts it to gamma encoded
    /// sRGB components.
    ///
    /// Unavailable on watchOS, which has no trait collections or dynamic colors.
    @available(watchOS, unavailable)
    public func toRGBAColor(compatibleWith traitCollection: UITraitCollection) -> RGBAColor? {
        resolvedColor(with: traitCollection).toRGBAColor()
    }
    #endif

    /// Converts the color to a ``ColorTransform`` that multiplies each component by the
    /// components of the color, see ``ColorConvertible/toColorTransform()``.
    ///
    /// Dynamic colors are resolved with `UITraitCollection.current`. Use
    /// `toColorTransform(compatibleWith:)` to resolve for specific traits.
    /// watchOS has no dynamic colors.
    ///
    /// Returns `nil` if the color can't be converted to sRGB, such as a pattern color.
    public func toColorTransform() -> ColorTransform? {
        toRGBAColor()?.toColorTransform()
    }

    #if !os(watchOS)
    /// Resolves the color for a trait collection and converts it to a ``ColorTransform``
    /// that multiplies each component by the components of the color.
    ///
    /// Unavailable on watchOS, which has no trait collections or dynamic colors.
    @available(watchOS, unavailable)
    public func toColorTransform(compatibleWith traitCollection: UITraitCollection) -> ColorTransform? {
        toRGBAColor(compatibleWith: traitCollection)?.toColorTransform()
    }
    #endif

    /// Returns a dynamic color that transforms the components of this color each
    /// time it's resolved.
    ///
    /// Dynamic colors, such as `.label` or a color from an asset catalog, have different
    /// components for each trait collection, so they can't be transformed once. The
    /// result resolves this color for the trait collection it's resolved with, then
    /// applies `transform` to the resolved gamma encoded sRGB components:
    ///
    /// ```swift
    /// let pressed = UIColor.tintColor.transformed { $0.darkened(by: 0.1) }
    /// let tinted = UIColor.label.transformed { $0.applying(.tint(HEXColor("#FF8000"))) }
    /// ```
    ///
    /// Colors that can't be converted to sRGB, such as pattern colors, resolve unchanged.
    /// On watchOS, which has no dynamic colors, the color is transformed immediately.
    public func transformed<C: ColorConvertible>(
        _ transform: @escaping @Sendable (RGBAColor) -> C
    ) -> UIColor {
        #if os(watchOS)
        guard let rgba = toRGBAColor() else { return self }
        return UIColor(transform(rgba))
        #else
        return UIColor { [self] traitCollection in
            let resolved = resolvedColor(with: traitCollection)
            guard let rgba = resolved.toRGBAColor() else { return resolved }
            return UIColor(transform(rgba))
        }
        #endif
    }

    /// Returns a dynamic color that transforms the components of this color and
    /// `other`, both resolved for the same trait collection, each time it's resolved.
    ///
    /// Use this to transform a color relative to another dynamic color, such as a
    /// background, so that both match the appearance:
    ///
    /// ```swift
    /// let readable = UIColor.systemOrange.transformed(with: .systemBackground) {
    ///     $0.contrast(.apca).adjusted(toMinimum: 60, against: $1)
    /// }
    /// ```
    ///
    /// See ``transformed(_:)``. If either color can't be converted to sRGB, this
    /// color resolves unchanged.
    public func transformed<C: ColorConvertible>(
        with other: UIColor,
        _ transform: @escaping @Sendable (RGBAColor, RGBAColor) -> C
    ) -> UIColor {
        #if os(watchOS)
        guard let rgba = toRGBAColor(), let otherRGBA = other.toRGBAColor() else { return self }
        return UIColor(transform(rgba, otherRGBA))
        #else
        return UIColor { [self] traitCollection in
            let resolved = resolvedColor(with: traitCollection)
            guard
                let rgba = resolved.toRGBAColor(),
                let otherRGBA = other.resolvedColor(with: traitCollection).toRGBAColor()
            else {
                return resolved
            }
            return UIColor(transform(rgba, otherRGBA))
        }
        #endif
    }
}
#endif
