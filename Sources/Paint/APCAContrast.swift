//
// Copyright (c) Nathan Tannar
//

import Foundation

/// The lightness contrast (Lc) of text on a background, from the
/// [Accessible Perceptual Contrast Algorithm](https://github.com/Myndex/apca-w3) (APCA-W3 0.0.98G-4g).
///
/// The ``rawValue`` is signed by polarity: positive for dark text on a light background,
/// negative for light text on a dark background. It ranges from about `106` (black on
/// white) to about `-108` (white on black), and is `0` when the contrast is too low to
/// measure. Use ``magnitude`` to compare contrast regardless of polarity, for example
/// against the APCA guidelines of `Lc 90` for small body text or `Lc 75` for body text.
///
/// Contrasts compare by ``magnitude``, so a greater contrast is easier to read:
///
/// ```swift
/// let black = HEXColor("#000000").contrast(.apca).against(background)
/// let white = HEXColor("#FFFFFF").contrast(.apca).against(background)
/// let text = black > white ? black : white
/// ```
///
/// Encodes as the signed lightness contrast (Lc).
@frozen
public struct APCAContrast: ContrastMetric, Hashable, Comparable, Sendable, BitwiseCopyable, Codable, RawRepresentable, CustomStringConvertible, ExpressibleByFloatLiteral, ExpressibleByIntegerLiteral {

    /// The signed lightness contrast (Lc).
    public var rawValue: Double

    /// Creates a contrast from a signed lightness contrast (Lc).
    @inlinable
    public init(rawValue: Double) {
        self.rawValue = rawValue
    }

    @inlinable
    public init(floatLiteral value: Double) {
        self.init(rawValue: value)
    }

    @inlinable
    public init(integerLiteral value: Int) {
        self.init(rawValue: Double(value))
    }

    /// The contrast of text on a background.
    ///
    /// Translucent text is blended over the background first. The background is
    /// treated as opaque. Wide gamut colors, such as Display P3 colors, are measured
    /// as they are. Colors outside Display P3, which no display can show, are first
    /// gamut mapped to it.
    @inlinable
    public init<
        Text: ColorConvertible,
        Background: ColorConvertible
    >(
        text: Text,
        background: Background
    ) {
        let background = background.toRGBAColor().toColorGamut(.displayP3)
        let text = text.toRGBAColor().toColorGamut(.displayP3)
        let alpha = min(max(text.alpha, 0), 1)
        // Blend in gamma encoded sRGB, matching APCA's `alphaBlend`
        let blended = RGBAColor(
            red: background.red + (text.red - background.red) * alpha,
            green: background.green + (text.green - background.green) * alpha,
            blue: background.blue + (text.blue - background.blue) * alpha
        )
        self.init(
            textLuminance: Self.luminance(red: blended.red, green: blended.green, blue: blended.blue),
            backgroundLuminance: Self.luminance(red: background.red, green: background.green, blue: background.blue)
        )
    }

    /// The contrast of text on a background, from their screen luminances (see ``luminance(red:green:blue:)``).
    @inlinable
    public init(
        textLuminance: Double,
        backgroundLuminance: Double
    ) {
        self.init(rawValue: Self.contrast(text: textLuminance, background: backgroundLuminance) * 100)
    }

    /// The strength of the contrast, regardless of polarity.
    public var magnitude: Double {
        abs(rawValue)
    }

    /// Whether the text is lighter than the background (reverse polarity).
    public var isLightOnDark: Bool {
        rawValue < 0
    }

    /// The contrast formatted like `"Lc 63.1"`.
    public var description: String {
        String(format: "Lc %.1f", rawValue)
    }

    /// Whether the contrast is at least as strong as a level, regardless of polarity.
    public func meets(_ level: APCAContrast) -> Bool {
        magnitude >= level.magnitude
    }

    /// Orders contrasts by ``magnitude``, breaking ties by ``rawValue`` so that
    /// the order is consistent with equality.
    public static func < (lhs: APCAContrast, rhs: APCAContrast) -> Bool {
        if lhs.magnitude != rhs.magnitude {
            return lhs.magnitude < rhs.magnitude
        }
        return lhs.rawValue < rhs.rawValue
    }

    /// The estimated screen luminance (Y) of gamma encoded sRGB components, as used by APCA.
    ///
    /// APCA uses a simple `2.4` exponent instead of the piecewise sRGB transfer function,
    /// so this differs slightly from the WCAG 2 relative luminance.
    ///
    /// Components outside `0...1` are extended sRGB, so negative components are
    /// mirrored rather than clamped. This measures wide gamut colors, such as Display
    /// P3 colors, within about 1% of APCA's own Display P3 luminance. The result is
    /// never negative, since no displayable color has a negative luminance.
    public static func luminance(red: Double, green: Double, blue: Double) -> Double {
        func linearize(_ component: Double) -> Double {
            let linear = pow(abs(component), Constants.exponent)
            return component < 0 ? -linear : linear
        }
        let luminance = Constants.redCoefficient * linearize(red)
            + Constants.greenCoefficient * linearize(green)
            + Constants.blueCoefficient * linearize(blue)
        // Also absorbs floating point error near black, e.g. components of -1e-8
        return max(luminance, 0)
    }

    /// The estimated screen luminance (Y) of a color, as used by APCA.
    ///
    /// This uses APCA's simple 2.4 exponent rather than the piecewise sRGB transfer
    /// function, so it differs slightly from the WCAG 2 relative luminance. Wide gamut
    /// colors are measured as they are, and colors outside Display P3 are first gamut
    /// mapped to it. Alpha is ignored.
    public static func luminance(of color: RGBAColor) -> Double {
        let rgba = color.toColorGamut(.displayP3)
        return luminance(red: rgba.red, green: rgba.green, blue: rgba.blue)
    }

    private enum Constants {
        static let exponent = 2.4
        static let redCoefficient = 0.2126729
        static let greenCoefficient = 0.7151522
        static let blueCoefficient = 0.0721750

        static let normalBackgroundExponent = 0.56
        static let normalTextExponent = 0.57
        static let reverseTextExponent = 0.62
        static let reverseBackgroundExponent = 0.65

        static let blackThreshold = 0.022
        static let blackClamp = 1.414
        static let scale = 1.14
        static let offset = 0.027
        static let minimumLuminanceDelta = 0.0005
        static let lowClip = 0.1
    }

    /// The APCA contrast in `-1.08...1.06`, before scaling to Lc.
    public static func contrast(text: Double, background: Double) -> Double {
        guard text.isFinite, background.isFinite,
              (0...1.1).contains(text), (0...1.1).contains(background)
        else {
            return 0
        }
        // Soft clamp near black, where screens flare
        func clampBlack(_ luminance: Double) -> Double {
            luminance > Constants.blackThreshold
                ? luminance
                : luminance + pow(Constants.blackThreshold - luminance, Constants.blackClamp)
        }
        let text = clampBlack(text)
        let background = clampBlack(background)
        guard abs(background - text) >= Constants.minimumLuminanceDelta else {
            return 0
        }

        if background > text {
            // Dark text on a light background
            let contrast = (pow(background, Constants.normalBackgroundExponent) - pow(text, Constants.normalTextExponent)) * Constants.scale
            return contrast < Constants.lowClip ? 0 : contrast - Constants.offset
        } else {
            // Light text on a dark background
            let contrast = (pow(background, Constants.reverseBackgroundExponent) - pow(text, Constants.reverseTextExponent)) * Constants.scale
            return contrast > -Constants.lowClip ? 0 : contrast + Constants.offset
        }
    }
}
