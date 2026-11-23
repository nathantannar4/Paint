//
// Copyright (c) Nathan Tannar
//

import CoreGraphics
import simd

/// An RGB color space with a known conversion to sRGB, so its components convert
/// to an ``RGBAColor`` at `Double` precision, without ColorSync. See
/// ``RGBAColor/init(red:green:blue:alpha:colorSpace:)``.
///
/// Each case includes its extended range variant, such as extended sRGB, since they
/// share the conversion, mirrored for negative components. The exception is linear
/// BT.2020, whose standard range Core Graphics color space requires iOS 15 and
/// macOS 12, so its extended variant is ``extendedLinearRec2020``.
///
/// Encodes as its case name, such as `"displayP3"`.
@frozen
public enum ColorSpace: String, Hashable, Sendable, Codable, CustomStringConvertible, CaseIterable {

    /// Gamma encoded sRGB, and extended sRGB, the color space of ``RGBAColor``.
    case sRGB

    /// Linear light sRGB, and extended linear sRGB.
    case linearSRGB

    /// Display P3, and extended Display P3, which share the sRGB transfer function.
    case displayP3

    /// Linear light Display P3, and extended linear Display P3.
    case linearDisplayP3

    /// ITU-R BT.2020, and extended BT.2020, with Core Graphics' transfer function:
    /// the BT.1886 display transfer function, a pure 2.4 gamma.
    ///
    /// CSS `color(rec2020 ...)` uses the BT.2020 camera transfer function instead, so
    /// the same components are lighter in CSS: `0.5` is about `0.26` in linear light,
    /// rather than `0.19`.
    case rec2020

    /// Linear light ITU-R BT.2020.
    ///
    /// Its Core Graphics color space, `CGColorSpace.linearITUR_2020`, requires iOS 15
    /// and macOS 12, so earlier ``toCGColorSpace()`` returns the extended variant, and
    /// before iOS 14 and macOS 11 it's left out of ``allCases``. See
    /// ``extendedLinearRec2020``.
    @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
    case linearRec2020

    /// Extended linear light ITU-R BT.2020, which shares the conversion of
    /// ``linearRec2020``, mirrored for negative components. Available on every OS
    /// version.
    case extendedLinearRec2020

    /// Every color space with a Core Graphics color space on this OS version: all of
    /// them, apart from ``linearRec2020`` before iOS 14 and macOS 11.
    public static var allCases: [ColorSpace] {
        if #available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *) {
            return [.sRGB, .linearSRGB, .displayP3, .linearDisplayP3, .rec2020, .linearRec2020, .extendedLinearRec2020]
        }
        return [.sRGB, .linearSRGB, .displayP3, .linearDisplayP3, .rec2020, .extendedLinearRec2020]
    }

    /// Whether components are linear light, rather than gamma encoded.
    public var isLinear: Bool {
        switch self {
        case .linearSRGB, .linearDisplayP3, .linearRec2020, .extendedLinearRec2020: true
        case .sRGB, .displayP3, .rec2020: false
        }
    }

    /// The color space of a Core Graphics color space, or `nil` if it has no known
    /// conversion, such as Adobe RGB, or isn't RGB.
    @inlinable
    public init?(_ colorSpace: CGColorSpace) {
        guard let name = colorSpace.name else { return nil }
        self.init(name)
    }

    /// The color space of a Core Graphics color space name, such as
    /// `CGColorSpace.displayP3`, or `nil` if it has no known conversion.
    @inlinable
    public init?(_ name: CFString) {
        switch name {
        case CGColorSpace.sRGB, CGColorSpace.extendedSRGB:
            self = .sRGB
        case CGColorSpace.linearSRGB, CGColorSpace.extendedLinearSRGB:
            self = .linearSRGB
        case CGColorSpace.displayP3:
            self = .displayP3
        case CGColorSpace.extendedLinearDisplayP3:
            self = .linearDisplayP3
        case CGColorSpace.itur_2020:
            self = .rec2020
        case CGColorSpace.extendedLinearITUR_2020:
            self = .extendedLinearRec2020
        default:
            // These names are newer than the minimum deployment target. Earlier, no
            // color space can have them
            if #available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *) {
                if name == CGColorSpace.extendedDisplayP3 {
                    self = .displayP3
                    return
                }
                if name == CGColorSpace.extendedITUR_2020 {
                    self = .rec2020
                    return
                }
            }
            if #available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *) {
                if name == CGColorSpace.linearDisplayP3 {
                    self = .linearDisplayP3
                    return
                }
                if name == CGColorSpace.linearITUR_2020 {
                    self = .linearRec2020
                    return
                }
            }
            return nil
        }
    }

    /// The color space name
    public var description: String {
        switch self {
        case .sRGB: "sRGB"
        case .linearSRGB: "Linear sRGB"
        case .displayP3: "Display P3"
        case .linearDisplayP3: "Linear Display P3"
        case .rec2020: "Rec. 2020"
        case .linearRec2020: "Linear Rec. 2020"
        case .extendedLinearRec2020: "Extended Linear Rec. 2020"
        }
    }

    /// The gamma encoded color space with the same primaries, such as ``sRGB`` for
    /// ``linearSRGB``.
    ///
    /// 8-bit components are better spent gamma encoded, which spreads them evenly by
    /// perceived lightness, rather than crowding them into highlights.
    public func toGammaEncodedColorSpace() -> ColorSpace {
        switch self {
        case .sRGB, .linearSRGB: .sRGB
        case .displayP3, .linearDisplayP3: .displayP3
        case .rec2020, .linearRec2020, .extendedLinearRec2020: .rec2020
        }
    }

    /// The color gamut of the color space's primaries, such as ``ColorGamut/sRGB``
    /// for ``linearSRGB``.
    public func toColorGamut() -> ColorGamut {
        switch self {
        case .sRGB, .linearSRGB: .sRGB
        case .displayP3, .linearDisplayP3: .displayP3
        case .rec2020, .linearRec2020, .extendedLinearRec2020: .rec2020
        }
    }

    /// The Core Graphics color space: the standard range one, apart from
    /// ``extendedLinearRec2020``.
    ///
    /// Before iOS 15 and macOS 12, ``linearDisplayP3`` and ``linearRec2020`` return
    /// the extended linear color space, since the standard range one doesn't exist
    /// yet. It has the same conversion.
    public func toCGColorSpace() -> CGColorSpace {
        let name: CFString
        switch self {
        case .sRGB: name = CGColorSpace.sRGB
        case .linearSRGB: name = CGColorSpace.linearSRGB
        case .displayP3: name = CGColorSpace.displayP3
        case .linearDisplayP3:
            if #available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *) {
                name = CGColorSpace.linearDisplayP3
            } else {
                name = CGColorSpace.extendedLinearDisplayP3
            }
        case .rec2020: name = CGColorSpace.itur_2020
        case .linearRec2020:
            if #available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *) {
                name = CGColorSpace.linearITUR_2020
            } else {
                name = CGColorSpace.extendedLinearITUR_2020
            }
        case .extendedLinearRec2020: name = CGColorSpace.extendedLinearITUR_2020
        }
        // Every name is a standard Core Graphics color space
        return CGColorSpace(name: name)!
    }
}

extension RGBAColor {

    /// The linear light red, green and blue components, see ``linearize(_:)``.
    ///
    /// Extended sRGB components outside `0...1` are kept, mirrored around `0`.
    public func toLinearComponents() -> SIMD3<Double> {
        SIMD3(RGBAColor.linearize(red), RGBAColor.linearize(green), RGBAColor.linearize(blue))
    }

    /// The red, green and blue components of this color in a color space, at
    /// `Double` precision. This is the inverse of
    /// ``RGBAColor/init(red:green:blue:alpha:colorSpace:)``.
    ///
    /// Colors outside the color space's gamut keep their extended components,
    /// which fall outside `0...1` and are mirrored around `0` for negative values.
    /// Alpha isn't included. Use ``alpha`` for it.
    ///
    /// ```swift
    /// let red = RGBAColor(red: 1, green: 0, blue: 0)
    /// let p3 = red.toComponents(in: .displayP3)
    /// // p3 is about (0.917, 0.200, 0.139), inside Display P3
    /// ```
    public func toComponents(in colorSpace: ColorSpace) -> SIMD3<Double> {
        switch colorSpace {
        case .sRGB:
            return components
        case .linearSRGB:
            return toLinearComponents()
        case .displayP3:
            let p3 = ColorSpaceMatrix.linearSRGBToLinearDisplayP3 * toLinearComponents()
            return SIMD3(RGBAColor.delinearize(p3.x), RGBAColor.delinearize(p3.y), RGBAColor.delinearize(p3.z))
        case .linearDisplayP3:
            return ColorSpaceMatrix.linearSRGBToLinearDisplayP3 * toLinearComponents()
        case .rec2020:
            // Core Graphics' BT.2020 color spaces are display referred
            let linear = ColorSpaceMatrix.linearSRGBToLinearRec2020 * toLinearComponents()
            return SIMD3(BT1886Transfer.delinearize(linear.x), BT1886Transfer.delinearize(linear.y), BT1886Transfer.delinearize(linear.z))
        case .linearRec2020, .extendedLinearRec2020:
            return ColorSpaceMatrix.linearSRGBToLinearRec2020 * toLinearComponents()
        }
    }

    /// Transforms this color into a color space, at `Double` precision, returning
    /// a color whose red, green and blue are the components in that color space,
    /// see ``toComponents(in:)``. Alpha is kept as it is.
    ///
    /// The result is no longer sRGB: other APIs read its components as sRGB, so
    /// pass it to code that expects the color space, such as a `CGColor` in
    /// ``ColorSpace/toCGColorSpace()``. To convert it back to sRGB, use
    /// ``RGBAColor/init(red:green:blue:alpha:colorSpace:)``.
    ///
    /// ```swift
    /// let red = RGBAColor(red: 1, green: 0, blue: 0)
    /// let p3 = red.toColorSpace(.displayP3)
    /// // p3.red is about 0.917, p3.green 0.200, p3.blue 0.139
    /// let sRGB = RGBAColor(red: p3.red, green: p3.green, blue: p3.blue, alpha: p3.alpha, colorSpace: .displayP3)
    /// // sRGB is red again
    /// ```
    public func toColorSpace(_ colorSpace: ColorSpace) -> RGBAColor {
        RGBAColor(components: toComponents(in: colorSpace), alpha: alpha)
    }

    /// Converts components in a color space to gamma encoded extended sRGB, at
    /// `Double` precision.
    ///
    /// Colors outside sRGB, such as saturated Display P3 colors, are kept, with
    /// components outside `0...1`. Alpha is kept as it is.
    ///
    /// ```swift
    /// let red = RGBAColor(red: 1, green: 0, blue: 0, colorSpace: .displayP3)
    /// // red.red is about 1.093, outside sRGB
    /// ```
    public init(
        red: Double,
        green: Double,
        blue: Double,
        alpha: Double = 1,
        colorSpace: ColorSpace
    ) {
        let values = SIMD3(red, green, blue)
        switch colorSpace {
        case .sRGB:
            self.init(red: red, green: green, blue: blue, alpha: alpha)
        case .linearSRGB:
            self.init(linear: values, alpha: alpha)
        case .displayP3:
            let linear = SIMD3(
                RGBAColor.linearize(red),
                RGBAColor.linearize(green),
                RGBAColor.linearize(blue)
            )
            self.init(linear: ColorSpaceMatrix.linearDisplayP3ToLinearSRGB * linear, alpha: alpha)
        case .linearDisplayP3:
            self.init(linear: ColorSpaceMatrix.linearDisplayP3ToLinearSRGB * values, alpha: alpha)
        case .rec2020:
            // Core Graphics' BT.2020 color spaces are display referred
            let linear = SIMD3(BT1886Transfer.linearize(red), BT1886Transfer.linearize(green), BT1886Transfer.linearize(blue))
            self.init(linear: ColorSpaceMatrix.linearRec2020ToLinearSRGB * linear, alpha: alpha)
        case .linearRec2020, .extendedLinearRec2020:
            self.init(linear: ColorSpaceMatrix.linearRec2020ToLinearSRGB * values, alpha: alpha)
        }
    }

    /// Creates a color from linear light red, green and blue components, see
    /// ``delinearize(_:)``.
    public init(linear: SIMD3<Double>, alpha: Double = 1) {
        self.init(
            red: RGBAColor.delinearize(linear.x),
            green: RGBAColor.delinearize(linear.y),
            blue: RGBAColor.delinearize(linear.z),
            alpha: alpha
        )
    }
}

/// Linear light conversion matrices between color spaces, at `Double` precision.
enum ColorSpaceMatrix {

    static let linearSRGBToXYZD65 = simd_double3x3(rows: [
        [0.41239079926595934, 0.357584339383878, 0.1804807884018343],
        [0.21263900587151027, 0.715168678767756, 0.07219231536073371],
        [0.01933081871559182, 0.11919477979462598, 0.9505321522496607],
    ])

    static let xyzD65ToLinearSRGB = simd_double3x3(rows: [
        [3.2409699419045226, -1.537383177570094, -0.4986107602930034],
        [-0.9692436362808796, 1.8759675015077202, 0.04155505740717559],
        [0.05563007969699366, -0.20397695888897652, 1.0569715142428786],
    ])

    /// Bradford chromatic adaptation from D65 to D50.
    static let d65ToD50 = simd_double3x3(rows: [
        [1.0479298208405488, 0.022946793341019088, -0.05019222954313557],
        [0.029627815688159344, 0.990434484573249, -0.01707382502938514],
        [-0.009243058152591178, 0.015055144896577895, 0.7518742899580008],
    ])

    /// Bradford chromatic adaptation from D50 to D65.
    static let d50ToD65 = simd_double3x3(rows: [
        [0.9554734527042182, -0.023098536874261423, 0.0632593086610217],
        [-0.028369706963208136, 1.0099954580058226, 0.021041398966943008],
        [0.012314001688319899, -0.020507696433477912, 1.3303659366080753],
    ])

    static let linearSRGBToLinearDisplayP3 = simd_double3x3(rows: [
        [0.8224619687143623, 0.17753803128563775, 0],
        [0.033194198850071, 0.966805801149929, 0],
        [0.017082630651362, 0.072397440874754, 0.910519928473884],
    ])

    static let linearDisplayP3ToLinearSRGB = simd_double3x3(rows: [
        [1.2249401762805598, -0.22494017628055996, 0],
        [-0.04205695470968816, 1.0420569547096882, 0],
        [-0.019637554590334432, -0.07863604555063188, 1.0982736001409663],
    ])

    static let linearSRGBToLinearRec2020 = simd_double3x3(rows: [
        [0.6274038959196011, 0.32928303837788354, 0.04331306570251536],
        [0.06909728935823208, 0.9195403951542099, 0.011362315487558214],
        [0.016391438875150247, 0.08801330787722575, 0.8955952532476239],
    ])

    static let linearRec2020ToLinearSRGB = simd_double3x3(rows: [
        [1.6604910021084345, -0.5876411387885495, -0.07284986331988474],
        [-0.12455047452159074, 1.1328998971259603, -0.008349422604369515],
        [-0.018150763354905303, -0.10057889800800739, 1.118729661362913],
    ])
}

// MARK: - BT.2020 transfer functions

// BT.2020 colors are encoded with one of two transfer functions, which aren't
// inverses of each other: the camera curve encodes scene light, and the display curve
// decodes the signal into displayed light. Together they make an end-to-end gamma of
// about 1.2, so the displayed image is slightly more contrasty than the scene, for dim
// viewing. The same components are lighter through the camera curve: `0.5` is about
// `0.26` in linear light, but `0.19` through the display curve.

/// The BT.2020 camera transfer function (OETF), the same piecewise curve as BT.709:
/// linear near black, then a `0.45` power.
///
/// CSS Color 4 defines `color(rec2020 ...)` with it, so it's used to parse CSS. For
/// Core Graphics' BT.2020 color spaces, see ``BT1886Transfer``.
public enum BT2020CameraTransfer {
    static let alpha = 1.09929682680944
    static let beta = 0.018053968510807

    /// Converts an encoded component to scene linear light, mirrored for negative
    /// components.
    public static func linearize(_ c: Double) -> Double {
        let magnitude = abs(c)
        let linear = magnitude < beta * 4.5 ? magnitude / 4.5 : pow((magnitude + alpha - 1) / alpha, 1 / 0.45)
        return c < 0 ? -linear : linear
    }
}

/// The BT.1886 display transfer function (EOTF) with a zero black level: a pure `2.4`
/// power.
///
/// Core Graphics' BT.2020 color spaces, such as `CGColorSpace.itur_2020`, use it, so
/// it's used for ``ColorSpace/rec2020``. For CSS `color(rec2020 ...)`, see
/// ``BT2020CameraTransfer``.
public enum BT1886Transfer {

    /// Converts an encoded component to displayed linear light, mirrored for negative
    /// components.
    public static func linearize(_ c: Double) -> Double {
        let linear = pow(abs(c), 2.4)
        return c < 0 ? -linear : linear
    }

    /// Converts displayed linear light to an encoded component, the inverse of
    /// ``linearize(_:)``, mirrored for negative components.
    public static func delinearize(_ c: Double) -> Double {
        let encoded = pow(abs(c), 1 / 2.4)
        return c < 0 ? -encoded : encoded
    }
}

extension RGBAColor {

    /// The gamma encoded components.
    @usableFromInline
    var components: SIMD3<Double> {
        SIMD3(red, green, blue)
    }

    @usableFromInline
    init(components: SIMD3<Double>, alpha: Double) {
        self.init(red: components.x, green: components.y, blue: components.z, alpha: alpha)
    }
}

extension ColorTransform {

    init(_ matrix: simd_double3x3) {
        let c = matrix.columns
        self.init(transform: simd_float4x4(columns: (
            SIMD4(SIMD3<Float>(c.0), 0),
            SIMD4(SIMD3<Float>(c.1), 0),
            SIMD4(SIMD3<Float>(c.2), 0),
            SIMD4(0, 0, 0, 1)
        )))
    }
}
