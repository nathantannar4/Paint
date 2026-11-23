//
// Copyright (c) Nathan Tannar
//

#if os(macOS)
import AppKit

extension ColorConvertible {

    /// Converts the color to an `NSColor` in the sRGB color space.
    ///
    /// Components outside `0...1` are preserved, as extended sRGB. HDR colors are
    /// tagged with their ``contentHeadroom`` on macOS 26 and later.
    public func toNSColor() -> NSColor {
        NSColor(self)
    }
}

extension NSColor {

    /// Creates an `NSColor` in the sRGB color space from any ``ColorConvertible`` color.
    ///
    /// Components outside `0...1` are preserved, as extended sRGB. On macOS 26 and
    /// later, HDR colors are tagged with their ``ColorConvertible/contentHeadroom``,
    /// which sets `linearExposure` and `standardDynamicRange`, so the system tone maps
    /// them for the display.
    public convenience init<C: ColorConvertible>(_ color: C) {
        let rgba = color.toRGBAColor()
        if #available(macOS 26.0, *), rgba.isHDR {
            // Unlike `init(red:green:blue:alpha:linearExposure:)`, which computes the
            // components at `Float` precision, this keeps them exactly. Any RGB
            // `CGColor` converts to an `NSColor`
            self.init(cgColor: rgba.toCGColor())!
        } else {
            self.init(red: rgba.red, green: rgba.green, blue: rgba.blue, alpha: rgba.alpha)
        }
    }
}

extension NSColor {

    /// Creates a dynamic color with a color for each appearance.
    ///
    /// Pair it with ``ColorConvertible/adapted(from:to:in:)`` and
    /// ``ColorContrast/increased(against:by:in:)`` to derive the
    /// variants from one color. Increased contrast variants default to the matching
    /// appearance.
    public convenience init<
        Light: ColorConvertible,
        Dark: ColorConvertible
    >(
        light: Light,
        dark: Dark
    ) {
        let light = light.toRGBAColor()
        let dark = dark.toRGBAColor()
        self.init(name: nil) { appearance in
            let match = appearance.bestMatch(from: [
                .aqua,
                .darkAqua
            ])
            switch match {
            case .darkAqua: return NSColor(dark)
            default: return NSColor(light)
            }
        }
    }

    /// Creates a dynamic color with a color for each appearance, and
    /// each appearance with increased contrast.
    ///
    /// Pair it with ``ColorConvertible/adapted(from:to:in:)`` and
    /// ``ColorContrast/increased(against:by:in:)`` to derive the
    /// variants from one color. Increased contrast variants default to the matching
    /// appearance.
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
        let light = light.toRGBAColor()
        let dark = dark.toRGBAColor()
        let lightHighContrast = lightHighContrast.toRGBAColor()
        let darkHighContrast = darkHighContrast.toRGBAColor()
        self.init(name: nil) { appearance in
            let match = appearance.bestMatch(from: [
                .aqua,
                .darkAqua,
                .accessibilityHighContrastAqua,
                .accessibilityHighContrastDarkAqua,
            ])
            switch match {
            case .darkAqua: return NSColor(dark)
            case .accessibilityHighContrastAqua: return NSColor(lightHighContrast)
            case .accessibilityHighContrastDarkAqua: return NSColor(darkHighContrast)
            default: return NSColor(light)
            }
        }
    }

    /// Converts the color to gamma encoded sRGB components.
    ///
    /// Dynamic colors are resolved with `NSAppearance.current`. Use
    /// ``toRGBAColor(for:)`` to resolve for a specific appearance.
    ///
    /// Display P3 and Rec. 2020 colors are converted at `Double` precision, see
    /// `CGColor.toRGBAColor()`. HDR colors keep their brightness, as components
    /// above `1`.
    ///
    /// Returns `nil` if the color can't be converted to sRGB, such as a pattern color.
    public func toRGBAColor() -> RGBAColor? {
        // Resolves catalog and dynamic colors with the current appearance
        guard
            let color = type == .componentBased ? self : usingType(.componentBased),
            color.type == .componentBased // Pattern colors have no components
        else {
            return nil
        }
        // Read known RGB color spaces directly, at `Double` precision with the same
        // matrices as the rest of the library
        if let rgba = color.cgColor.toDirectRGBAColor() {
            return rgba
        }
        // Read sRGB directly, since conversion runs at `Float` precision
        let sRGB: NSColor?
        if color.colorSpace == .sRGB || color.colorSpace == .extendedSRGB {
            sRGB = color
        } else {
            sRGB = color.usingColorSpace(.extendedSRGB)
        }
        guard let sRGB else {
            return nil
        }
        return RGBAColor(
            red: Double(sRGB.redComponent),
            green: Double(sRGB.greenComponent),
            blue: Double(sRGB.blueComponent),
            alpha: Double(sRGB.alphaComponent)
        )
    }

    /// Resolves the color for an appearance and converts it to gamma encoded
    /// sRGB components.
    @available(macOS 11.0, *)
    public func toRGBAColor(for appearance: NSAppearance) -> RGBAColor? {
        var rgba: RGBAColor?
        appearance.performAsCurrentDrawingAppearance {
            rgba = toRGBAColor()
        }
        return rgba
    }

    /// Converts the color to a ``ColorTransform`` that multiplies each component by the
    /// components of the color, see ``ColorConvertible/toColorTransform()``.
    ///
    /// Dynamic colors are resolved with `NSAppearance.current`. Use
    /// ``toColorTransform(for:)`` to resolve for a specific appearance.
    ///
    /// Returns `nil` if the color can't be converted to sRGB, such as a pattern color.
    public func toColorTransform() -> ColorTransform? {
        toRGBAColor()?.toColorTransform()
    }

    /// Resolves the color for an appearance and converts it to a ``ColorTransform`` that
    /// multiplies each component by the components of the color.
    @available(macOS 11.0, *)
    public func toColorTransform(for appearance: NSAppearance) -> ColorTransform? {
        toRGBAColor(for: appearance)?.toColorTransform()
    }

    /// Returns a dynamic color that transforms the components of this color each
    /// time it's resolved.
    ///
    /// Dynamic colors, such as `.labelColor` or a color from an asset catalog, have
    /// different components for each appearance, so they can't be transformed once.
    /// The result resolves this color for the appearance it's resolved with, then
    /// applies `transform` to the resolved gamma encoded sRGB components:
    ///
    /// ```swift
    /// let pressed = NSColor.controlAccentColor.transformed { $0.darkened(by: 0.1) }
    /// let tinted = NSColor.labelColor.transformed { $0.applying(.tint(HEXColor("#FF8000"))) }
    /// ```
    ///
    /// Colors that can't be converted to sRGB, such as pattern colors, resolve unchanged.
    @available(macOS 11.0, *)
    public func transformed<C: ColorConvertible>(
        _ transform: @escaping @Sendable (RGBAColor) -> C
    ) -> NSColor {
        NSColor(name: nil) { [self] appearance in
            guard let rgba = toRGBAColor(for: appearance) else { return self }
            return NSColor(transform(rgba))
        }
    }

    /// Returns a dynamic color that transforms the components of this color and
    /// `other`, both resolved for the same appearance, each time it's resolved.
    ///
    /// Use this to transform a color relative to another dynamic color, such as a
    /// background, so that both match the appearance:
    ///
    /// ```swift
    /// let readable = NSColor.systemOrange.transformed(with: .windowBackgroundColor) {
    ///     $0.contrast(.apca).adjusted(toMinimum: 60, against: $1)
    /// }
    /// ```
    ///
    /// See ``transformed(_:)``. If either color can't be converted to sRGB, this
    /// color resolves unchanged.
    @available(macOS 11.0, *)
    public func transformed<C: ColorConvertible>(
        with other: NSColor,
        _ transform: @escaping @Sendable (RGBAColor, RGBAColor) -> C
    ) -> NSColor {
        NSColor(name: nil) { [self] appearance in
            guard
                let rgba = toRGBAColor(for: appearance),
                let otherRGBA = other.toRGBAColor(for: appearance)
            else {
                return self
            }
            return NSColor(transform(rgba, otherRGBA))
        }
    }
}
#endif
