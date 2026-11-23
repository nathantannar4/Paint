//
// Copyright (c) Nathan Tannar
//

import Foundation

/// A level of visual prominence, like `UIColor.Prominence` and SwiftUI's
/// hierarchical shape styles, for content such as secondary labels.
///
/// Encodes as its case name, such as `"secondary"`.
@frozen
public enum ColorProminence: String, Hashable, Sendable, Codable, CaseIterable, CustomStringConvertible {
    /// Fully opaque, for primary content.
    case primary
    /// An opacity of `0.6`, for secondary content.
    case secondary
    /// An opacity of `0.3`, for tertiary content.
    case tertiary
    /// An opacity of `0.18`, for quaternary content.
    case quaternary

    /// The opacity of the level: `1`, `0.6`, `0.3` and `0.18`, matching the
    /// opacity of the system label colors.
    public var opacity: Double {
        switch self {
        case .primary: 1
        case .secondary: 0.6
        case .tertiary: 0.3
        case .quaternary: 0.18
        }
    }

    /// The raw value, such as `"secondary"`.
    public var description: String {
        rawValue
    }
}

extension ColorConvertible {

    /// Returns the color at a level of prominence, by multiplying its alpha by the
    /// ``ColorProminence/opacity`` of the level, like `UIColor.withProminence(_:)`.
    ///
    /// Translucency adapts to any background, but overlapping content shows
    /// through. Use ``withProminence(_:against:)`` for an opaque color on a known
    /// background.
    public func withProminence(_ prominence: ColorProminence) -> RGBAColor {
        var rgba = toRGBAColor()
        rgba.alpha *= prominence.opacity
        return rgba
    }

    /// Returns an opaque color at a level of prominence on `background`, by mixing
    /// the color towards the background in Oklab.
    ///
    /// The color is mixed by `1 - opacity` of the level, so it lowers contrast evenly
    /// without letting overlapping content show through. Since Oklab mixing is
    /// perceptual, the result is not identical to the translucent color composited
    /// over the background. The background is treated as opaque, and the alpha of
    /// the color is kept.
    public func withProminence<
        Background: ColorConvertible
    >(
        _ prominence: ColorProminence,
        against background: Background
    ) -> OKLCHColor {
        let oklch = toOKLCHColor()
        var background = background.toOKLCHColor()
        background.alpha = oklch.alpha
        return oklch.mixed(with: background, by: 1 - prominence.opacity)
    }
}
