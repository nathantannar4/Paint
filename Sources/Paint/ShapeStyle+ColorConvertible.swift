//
// Copyright (c) Nathan Tannar
//

import SwiftUI

/// A `ShapeStyle` for a ``ColorConvertible`` color.
///
/// Custom shape styles resolve with `resolve(in:)`, which requires iOS 17 and
/// macOS 14. Earlier, use ``ColorConvertible/toColor()``.
@frozen
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public struct ColorStyle<
    Light: ColorConvertible,
    Dark: ColorConvertible,
    LightHighContrast: ColorConvertible,
    DarkHighContrast: ColorConvertible
>: ShapeStyle {

    /// The color the style draws for the light appearance
    public var light: Light

    /// The color the style draws for the dark appearance
    public var dark: Dark

    /// The color the style draws for the high contrast light appearance
    public var lightHighContrast: LightHighContrast

    /// The color the style draws for the high contrast dark appearance
    public var darkHighContrast: DarkHighContrast

    /// Creates a style that draws a color.
    @inlinable
    public init(color: Light) where Dark == Light, LightHighContrast == Light, DarkHighContrast == Dark {
        self.init(light: color, dark: color)
    }

    /// Creates a style that draws a color.
    @inlinable
    public init(light: Light, dark: Dark) where LightHighContrast == Light, DarkHighContrast == Dark {
        self.init(light: light, dark: dark, lightHighContrast: light, darkHighContrast: dark)
    }

    /// Creates a style that draws a color.
    @inlinable
    public init(light: Light, dark: Dark, lightHighContrast: LightHighContrast, darkHighContrast: DarkHighContrast) {
        self.light = light
        self.dark = dark
        self.lightHighContrast = lightHighContrast
        self.darkHighContrast = darkHighContrast
    }

    public func resolve(in environment: EnvironmentValues) -> Color {
        switch (environment.colorScheme, environment.colorSchemeContrast) {
        case (.dark, .standard):
            return dark.toColor()
        case (.dark, .increased):
            return darkHighContrast.toColor()
        case (.light, .increased):
            return lightHighContrast.toColor()
        default:
            return light.toColor()
        }
    }
}

/// A `ShapeStyle` that resolves a SwiftUI `Color` in the environment, then
/// transforms its components.
///
/// System and adaptive colors, such as `.blue` and `.primary`, have different
/// components for each environment, so they can't be transformed once. This style
/// resolves ``color`` in the environment it's used in, including the color scheme,
/// contrast and tint, then applies ``transform`` to the resolved gamma encoded sRGB
/// components.
///
/// Create one with ``SwiftUICore/Color/transformed(_:)``.
@frozen
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public struct TransformedColorStyle<C: ColorConvertible>: ShapeStyle {

    /// The color to resolve, then transform.
    public var color: Color

    /// The transform applied to the resolved components of ``color``.
    public var transform: @Sendable (RGBAColor) -> C

    /// Creates a style that resolves a color in the environment, then transforms its
    /// components.
    @inlinable
    public init(
        color: Color,
        transform: @escaping @Sendable (RGBAColor) -> C
    ) {
        self.color = color
        self.transform = transform
    }

    public func resolve(in environment: EnvironmentValues) -> Color {
        transform(color.toRGBAColor(in: environment)).toColor()
    }
}

/// A `ShapeStyle` that resolves two SwiftUI colors in the same environment, then
/// transforms their components into one color.
///
/// Use this to transform a color relative to another adaptive color, such as a
/// background, so that both match the environment. See ``TransformedColorStyle``.
///
/// Create one with ``SwiftUICore/Color/transformed(with:_:)``.
@frozen
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public struct TransformedColorsStyle<C: ColorConvertible>: ShapeStyle {

    /// The color to resolve, then transform.
    public var color: Color

    /// The color resolved alongside ``color``, passed as the second argument of ``transform``.
    public var other: Color

    /// The transform applied to the resolved components of ``color`` and ``other``.
    public var transform: @Sendable (RGBAColor, RGBAColor) -> C

    /// Creates a style that resolves two colors in the same environment, then
    /// transforms their components into one color.
    @inlinable
    public init(
        color: Color,
        other: Color,
        transform: @escaping @Sendable (RGBAColor, RGBAColor) -> C
    ) {
        self.color = color
        self.other = other
        self.transform = transform
    }

    public func resolve(in environment: EnvironmentValues) -> Color {
        transform(color.toRGBAColor(in: environment), other.toRGBAColor(in: environment)).toColor()
    }
}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension Color {

    /// Returns a style that transforms the components of this color each time it's
    /// resolved.
    ///
    /// System and adaptive colors, such as `.blue` and `.primary`, have different
    /// components for each environment, so they can't be transformed once. The style
    /// resolves this color in the environment it's used in, including the color
    /// scheme, contrast and tint, then applies `transform` to the resolved gamma
    /// encoded sRGB components:
    ///
    /// ```swift
    /// Text("Pressed")
    ///     .foregroundStyle(Color.accentColor.transformed { $0.darkened(by: 0.1) })
    /// ```
    ///
    /// To transform a color outside of a view, resolve it with
    /// `resolve(in:)` or ``toRGBAColor(in:)`` instead.
    public func transformed<C: ColorConvertible>(
        _ transform: @escaping @Sendable (RGBAColor) -> C
    ) -> TransformedColorStyle<C> {
        TransformedColorStyle(color: self, transform: transform)
    }

    /// Returns a style that transforms the components of this color and `other`,
    /// both resolved in the same environment, each time it's resolved.
    ///
    /// Use this to transform a color relative to another adaptive color, such as a
    /// background, so that both match the environment:
    ///
    /// ```swift
    /// Text("Warning")
    ///     .foregroundStyle(Color.orange.transformed(with: Color(uiColor: .systemBackground)) {
    ///         $0.contrast(.apca).adjusted(toMinimum: 60, against: $1)
    ///     })
    /// ```
    ///
    /// See ``transformed(_:)``.
    public func transformed<C: ColorConvertible>(
        with other: Color,
        _ transform: @escaping @Sendable (RGBAColor, RGBAColor) -> C
    ) -> TransformedColorsStyle<C> {
        TransformedColorsStyle(color: self, other: other, transform: transform)
    }
}
