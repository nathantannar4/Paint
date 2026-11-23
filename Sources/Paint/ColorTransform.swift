//
// Copyright (c) Nathan Tannar
//

import SwiftUI
import simd

/// A 4x5 matrix that transforms the red, green, blue and alpha components of rendered colors.
///
/// Each output component is the sum of the input components multiplied by the
/// corresponding factors, plus a constant offset. For example, the output red component is
/// `r1 * red + r2 * green + r3 * blue + r4 * alpha + r5`.
///
/// Components are gamma encoded sRGB, the same components the SwiftUI `_colorMatrix(_:)`
/// view modifier transforms.
///
/// The matrix is stored as a `simd_float4x4` ``transform`` and a `SIMD4<Float>`
/// ``offset``, so applying and concatenating matrices use SIMD instructions, and the
/// storage can be passed directly to Metal or Core Image. The named factors, such as
/// ``r1``, read and write the same storage.
///
/// Encodes every factor and offset by name, such as `{"r1": 1, "r2": 0, ...}`.
@frozen
public struct ColorTransform: Hashable, Sendable, BitwiseCopyable, Codable {

    /// The factors applied to the input components: `transform * rgba` is the output
    /// before the ``offset``.
    ///
    /// Like all simd matrices, it's indexed by column, then row, so `transform[1][0]`
    /// is the factor of the input green component in the output red component (``r2``).
    public var transform: simd_float4x4

    /// The constant offsets added to the output red, green, blue and alpha components.
    public var offset: SIMD4<Float>

    /// The identity matrix, which leaves colors unchanged.
    public static let identity = ColorTransform()

    /// Creates a color matrix from a transform and offset, see ``transform``.
    @inlinable
    public init(transform: simd_float4x4, offset: SIMD4<Float> = .zero) {
        self.transform = transform
        self.offset = offset
    }

    /// Creates a color matrix from its factors and offsets.
    ///
    /// Each value defaults to the identity matrix, so only the values that differ
    /// from the identity need to be passed.
    @inlinable
    public init(
        r1: Float = 1, r2: Float = 0, r3: Float = 0, r4: Float = 0, r5: Float = 0,
        g1: Float = 0, g2: Float = 1, g3: Float = 0, g4: Float = 0, g5: Float = 0,
        b1: Float = 0, b2: Float = 0, b3: Float = 1, b4: Float = 0, b5: Float = 0,
        a1: Float = 0, a2: Float = 0, a3: Float = 0, a4: Float = 1, a5: Float = 0
    ) {
        self.transform = simd_float4x4(columns: (
            SIMD4(r1, g1, b1, a1),
            SIMD4(r2, g2, b2, a2),
            SIMD4(r3, g3, b3, a3),
            SIMD4(r4, g4, b4, a4)
        ))
        self.offset = SIMD4(r5, g5, b5, a5)
    }

    // MARK: Factors

    /// The factor of the input red component in the output red component.
    public var r1: Float { get { transform[0][0] } set { transform[0][0] = newValue } }
    /// The factor of the input green component in the output red component.
    public var r2: Float { get { transform[1][0] } set { transform[1][0] = newValue } }
    /// The factor of the input blue component in the output red component.
    public var r3: Float { get { transform[2][0] } set { transform[2][0] = newValue } }
    /// The factor of the input alpha component in the output red component.
    public var r4: Float { get { transform[3][0] } set { transform[3][0] = newValue } }
    /// The constant offset added to the output red component.
    public var r5: Float { get { offset[0] } set { offset[0] = newValue } }

    /// The factor of the input red component in the output green component.
    public var g1: Float { get { transform[0][1] } set { transform[0][1] = newValue } }
    /// The factor of the input green component in the output green component.
    public var g2: Float { get { transform[1][1] } set { transform[1][1] = newValue } }
    /// The factor of the input blue component in the output green component.
    public var g3: Float { get { transform[2][1] } set { transform[2][1] = newValue } }
    /// The factor of the input alpha component in the output green component.
    public var g4: Float { get { transform[3][1] } set { transform[3][1] = newValue } }
    /// The constant offset added to the output green component.
    public var g5: Float { get { offset[1] } set { offset[1] = newValue } }

    /// The factor of the input red component in the output blue component.
    public var b1: Float { get { transform[0][2] } set { transform[0][2] = newValue } }
    /// The factor of the input green component in the output blue component.
    public var b2: Float { get { transform[1][2] } set { transform[1][2] = newValue } }
    /// The factor of the input blue component in the output blue component.
    public var b3: Float { get { transform[2][2] } set { transform[2][2] = newValue } }
    /// The factor of the input alpha component in the output blue component.
    public var b4: Float { get { transform[3][2] } set { transform[3][2] = newValue } }
    /// The constant offset added to the output blue component.
    public var b5: Float { get { offset[2] } set { offset[2] = newValue } }

    /// The factor of the input red component in the output alpha component.
    public var a1: Float { get { transform[0][3] } set { transform[0][3] = newValue } }
    /// The factor of the input green component in the output alpha component.
    public var a2: Float { get { transform[1][3] } set { transform[1][3] = newValue } }
    /// The factor of the input blue component in the output alpha component.
    public var a3: Float { get { transform[2][3] } set { transform[2][3] = newValue } }
    /// The factor of the input alpha component in the output alpha component.
    public var a4: Float { get { transform[3][3] } set { transform[3][3] = newValue } }
    /// The constant offset added to the output alpha component.
    public var a5: Float { get { offset[3] } set { offset[3] = newValue } }

    // MARK: Concatenation

    /// Returns the concatenation of two color matrices, which applies `rhs` and then `lhs`.
    public static func * (lhs: Self, rhs: Self) -> Self {
        // lhs(rhs(x)) = L(Rx + o_r) + o_l = (LR)x + (L o_r + o_l)
        ColorTransform(
            transform: lhs.transform * rhs.transform,
            offset: lhs.transform * rhs.offset + lhs.offset
        )
    }

    /// Concatenates `rhs` onto `lhs`, so that `lhs` applies `rhs` and then the original `lhs`.
    public static func *= (lhs: inout Self, rhs: Self) {
        lhs = lhs * rhs
    }

    // MARK: Hashable

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.transform == rhs.transform && lhs.offset == rhs.offset
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(transform.columns.0)
        hasher.combine(transform.columns.1)
        hasher.combine(transform.columns.2)
        hasher.combine(transform.columns.3)
        hasher.combine(offset)
    }

    // MARK: Codable

    private enum CodingKeys: String, CodingKey {
        case r1, r2, r3, r4, r5
        case g1, g2, g3, g4, g5
        case b1, b2, b3, b4, b5
        case a1, a2, a3, a4, a5
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        func decode(_ key: CodingKeys) throws -> Float {
            try container.decode(Float.self, forKey: key)
        }
        self.init(
            transform: simd_float4x4(columns: (
                SIMD4(try decode(.r1), try decode(.g1), try decode(.b1), try decode(.a1)),
                SIMD4(try decode(.r2), try decode(.g2), try decode(.b2), try decode(.a2)),
                SIMD4(try decode(.r3), try decode(.g3), try decode(.b3), try decode(.a3)),
                SIMD4(try decode(.r4), try decode(.g4), try decode(.b4), try decode(.a4))
            )),
            offset: SIMD4(try decode(.r5), try decode(.g5), try decode(.b5), try decode(.a5))
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let (c0, c1, c2, c3) = transform.columns
        try container.encode(c0.x, forKey: .r1)
        try container.encode(c1.x, forKey: .r2)
        try container.encode(c2.x, forKey: .r3)
        try container.encode(c3.x, forKey: .r4)
        try container.encode(offset.x, forKey: .r5)
        try container.encode(c0.y, forKey: .g1)
        try container.encode(c1.y, forKey: .g2)
        try container.encode(c2.y, forKey: .g3)
        try container.encode(c3.y, forKey: .g4)
        try container.encode(offset.y, forKey: .g5)
        try container.encode(c0.z, forKey: .b1)
        try container.encode(c1.z, forKey: .b2)
        try container.encode(c2.z, forKey: .b3)
        try container.encode(c3.z, forKey: .b4)
        try container.encode(offset.z, forKey: .b5)
        try container.encode(c0.w, forKey: .a1)
        try container.encode(c1.w, forKey: .a2)
        try container.encode(c2.w, forKey: .a3)
        try container.encode(c3.w, forKey: .a4)
        try container.encode(offset.w, forKey: .a5)
    }
}

// MARK: - SwiftUI

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension ColorTransform {

    /// Creates a color matrix from SwiftUI's color matrix.
    @inlinable
    public init(_ matrix: _ColorMatrix) {
        self.init(
            r1: matrix.m11, r2: matrix.m12, r3: matrix.m13, r4: matrix.m14, r5: matrix.m15,
            g1: matrix.m21, g2: matrix.m22, g3: matrix.m23, g4: matrix.m24, g5: matrix.m25,
            b1: matrix.m31, b2: matrix.m32, b3: matrix.m33, b4: matrix.m34, b5: matrix.m35,
            a1: matrix.m41, a2: matrix.m42, a3: matrix.m43, a4: matrix.m44, a5: matrix.m45
        )
    }

    /// Creates a color matrix that multiplies each component by the components of
    /// a SwiftUI color, resolved in an environment.
    ///
    /// Equivalent to `colorMultiply(_:)`. System and adaptive colors, such as `.blue`
    /// and `.primary`, resolve for the color scheme, contrast and tint of `environment`.
    @inlinable
    public init(color: Color, in environment: EnvironmentValues) {
        self.init(_ColorMatrix(color: color, in: environment))
    }

    /// Converts the color matrix to SwiftUI's color matrix.
    public func toSwiftUI() -> _ColorMatrix {
        var matrix = _ColorMatrix()
        (matrix.m11, matrix.m12, matrix.m13, matrix.m14, matrix.m15) = (r1, r2, r3, r4, r5)
        (matrix.m21, matrix.m22, matrix.m23, matrix.m24, matrix.m25) = (g1, g2, g3, g4, g5)
        (matrix.m31, matrix.m32, matrix.m33, matrix.m34, matrix.m35) = (b1, b2, b3, b4, b5)
        (matrix.m41, matrix.m42, matrix.m43, matrix.m44, matrix.m45) = (a1, a2, a3, a4, a5)
        return matrix
    }
}

// MARK: - VectorArithmetic

/// Color matrices add, subtract and scale component-wise, so they can be
/// interpolated and animated. For example, interpolating from ``identity`` to a
/// matrix fades its effect in.
///
/// `*` is matrix concatenation, not a component-wise product, so `ColorTransform` is not
/// `Numeric`: concatenation doesn't distribute over addition from the left, since
/// the offsets of the left matrix would be added twice.
extension ColorTransform: VectorArithmetic, Animatable {

    /// The matrix with every factor and offset `0`, which maps every color to
    /// transparent black.
    ///
    /// This is the additive identity, not the identity transform. See ``identity``.
    public static let zero = ColorTransform(transform: simd_float4x4(), offset: .zero)

    public static func + (lhs: Self, rhs: Self) -> Self {
        ColorTransform(transform: lhs.transform + rhs.transform, offset: lhs.offset + rhs.offset)
    }

    public static func - (lhs: Self, rhs: Self) -> Self {
        ColorTransform(transform: lhs.transform - rhs.transform, offset: lhs.offset - rhs.offset)
    }

    public static func += (lhs: inout Self, rhs: Self) {
        lhs = lhs + rhs
    }

    public static func -= (lhs: inout Self, rhs: Self) {
        lhs = lhs - rhs
    }

    /// Multiplies every factor and offset by `rhs`.
    public mutating func scale(by rhs: Double) {
        let rhs = Float(rhs)
        transform = rhs * transform
        offset *= rhs
    }

    /// The sum of the squares of every factor and offset.
    public var magnitudeSquared: Double {
        let columns = transform.columns
        let sum = simd_length_squared(columns.0)
            + simd_length_squared(columns.1)
            + simd_length_squared(columns.2)
            + simd_length_squared(columns.3)
            + simd_length_squared(offset)
        return Double(sum)
    }
}

extension ColorTransform {

    /// The luminance weights used by the W3C Filter Effects
    public enum W3CWeight {
        public static let red: Float = 0.213
        public static let green: Float = 0.715
        public static let blue: Float = 0.072
    }

    /// Creates a matrix whose red, green and blue outputs are the luminance of the
    /// input, scaled by `red`, `green` and `blue`, and whose alpha output is the
    /// input alpha scaled by `alpha`.
    @inlinable
    public init(
        luminanceRed red: Float,
        luminanceGreen green: Float,
        luminanceBlue blue: Float,
        alpha: Float
    ) {
        self.init(
            r1: red * W3CWeight.red, r2: red * W3CWeight.green, r3: red * W3CWeight.blue,
            g1: green * W3CWeight.red, g2: green * W3CWeight.green, g3: green * W3CWeight.blue,
            b1: blue * W3CWeight.red, b2: blue * W3CWeight.green, b3: blue * W3CWeight.blue,
            a4: alpha
        )
    }

    /// A matrix that saturates or desaturates colors, like the CSS `saturate()` filter.
    ///
    /// `1` leaves colors unchanged, `0` is grayscale, and values above `1` oversaturate.
    public static func saturation(_ amount: Double) -> ColorTransform {
        let s = Float(amount)
        let r = W3CWeight.red, g = W3CWeight.green, b = W3CWeight.blue
        return ColorTransform(
            r1: r + (1 - r) * s, r2: g - g * s, r3: b - b * s,
            g1: r - r * s, g2: g + (1 - g) * s, g3: b - b * s,
            b1: r - r * s, b2: g - g * s, b3: b + (1 - b) * s
        )
    }

    /// A matrix that rotates hues, like the CSS `hue-rotate()` filter.
    ///
    /// This approximates a hue rotation in sRGB, so lightness and saturation shift
    /// for some hues. Use ``ColorConvertible/hueRotated(by:in:)`` to rotate a
    /// single color perceptually.
    public static func hueRotation(_ rotation: ColorHue) -> ColorTransform {
        let c = Float(cos(rotation.radians))
        let s = Float(sin(rotation.radians))
        return ColorTransform(
            r1: 0.213 + c * 0.787 - s * 0.213,
            r2: 0.715 - c * 0.715 - s * 0.715,
            r3: 0.072 - c * 0.072 + s * 0.928,
            g1: 0.213 - c * 0.213 + s * 0.143,
            g2: 0.715 + c * 0.285 + s * 0.140,
            g3: 0.072 - c * 0.072 - s * 0.283,
            b1: 0.213 - c * 0.213 - s * 0.787,
            b2: 0.715 - c * 0.715 + s * 0.715,
            b3: 0.072 + c * 0.928 + s * 0.072
        )
    }

    /// A matrix that converts colors to grayscale by luminance, like the CSS
    /// `grayscale()` filter. `1` is fully gray and `0` leaves colors unchanged.
    public static func grayscale(_ amount: Double = 1) -> ColorTransform {
        let k = Float(1 - amount.clamped(to: 0...1))
        return ColorTransform(
            r1: 0.2126 + 0.7874 * k, r2: 0.7152 - 0.7152 * k, r3: 0.0722 - 0.0722 * k,
            g1: 0.2126 - 0.2126 * k, g2: 0.7152 + 0.2848 * k, g3: 0.0722 - 0.0722 * k,
            b1: 0.2126 - 0.2126 * k, b2: 0.7152 - 0.7152 * k, b3: 0.0722 + 0.9278 * k
        )
    }

    /// A matrix that tones colors sepia, like the CSS `sepia()` filter. `1` is fully
    /// sepia and `0` leaves colors unchanged.
    public static func sepia(_ amount: Double = 1) -> ColorTransform {
        let k = Float(1 - amount.clamped(to: 0...1))
        return ColorTransform(
            r1: 0.393 + 0.607 * k, r2: 0.769 - 0.769 * k, r3: 0.189 - 0.189 * k,
            g1: 0.349 - 0.349 * k, g2: 0.686 + 0.314 * k, g3: 0.168 - 0.168 * k,
            b1: 0.272 - 0.272 * k, b2: 0.534 - 0.534 * k, b3: 0.131 + 0.869 * k
        )
    }

    /// A matrix that inverts colors, like the CSS `invert()` filter. `1` is fully
    /// inverted, `0.5` is gray and `0` leaves colors unchanged.
    public static func inversion(_ amount: Double = 1) -> ColorTransform {
        let a = Float(amount.clamped(to: 0...1))
        return ColorTransform(
            r1: 1 - 2 * a, r5: a,
            g2: 1 - 2 * a, g5: a,
            b3: 1 - 2 * a, b5: a
        )
    }

    /// A matrix that scales colors towards black, like the CSS `brightness()` filter.
    /// `1` leaves colors unchanged, `0` is black and values above `1` brighten.
    public static func brightness(_ amount: Double) -> ColorTransform {
        let a = Float(amount)
        return ColorTransform(r1: a, g2: a, b3: a)
    }

    /// A matrix that scales colors towards or away from middle gray, like the CSS
    /// `contrast()` filter. `1` leaves colors unchanged, `0` is gray and values above
    /// `1` increase contrast.
    public static func contrast(_ amount: Double) -> ColorTransform {
        let a = Float(amount)
        let offset = 0.5 - 0.5 * a
        return ColorTransform(
            r1: a, r5: offset,
            g2: a, g5: offset,
            b3: a, b5: offset
        )
    }

    /// A matrix that multiplies alpha, like the CSS `opacity()` filter.
    ///
    /// The amount is clamped to `0...1`.
    public static func opacity(_ amount: Double) -> ColorTransform {
        ColorTransform(a4: Float(amount.clamped(to: 0...1)))
    }

    /// A matrix that colorizes colors with a tint, mapping each color's luminance onto
    /// the tint, from black to the tint at full brightness.
    ///
    /// Tinting with white is grayscale. Alpha is multiplied by the alpha of the tint.
    public static func tint<C: ColorConvertible>(_ color: C) -> ColorTransform {
        let rgba = color.toRGBAColor()
        return ColorTransform(
            luminanceRed: Float(rgba.red),
            luminanceGreen: Float(rgba.green),
            luminanceBlue: Float(rgba.blue),
            alpha: Float(rgba.alpha)
        )
    }
}
