//
// Copyright (c) Nathan Tannar
//

import SwiftUI
import CoreGraphics

extension ColorGradient {

    /// Renders the gradient as a linear gradient into an 8-bit image, with dithering
    /// that hides banding.
    ///
    /// With 8 bits per component, a subtle gradient, such as dark gray to slightly
    /// lighter gray across a screen, only has a few distinct values, which show as
    /// visible bands, especially on OLED displays. Dithering adds a tiny amount of
    /// noise, less than one 8-bit step, before rounding each pixel, so neighboring
    /// pixels round differently and the eye averages them into a smooth gradient.
    ///
    /// `startPoint` and `endPoint` are in unit coordinates of the image, like a SwiftUI
    /// `UnitPoint`, where `(0, 0)` is the top leading corner. Colors are interpolated
    /// as ``color(at:)`` interpolates them, then converted to `colorSpace`, such as
    /// ``ColorSpace/displayP3`` for wide gamut colors, and clipped to its gamut. The
    /// noise is the same for the same size, so rendering is reproducible.
    ///
    /// ```swift
    /// let image = gradient.toCGImage(width: 390, height: 844)
    /// Image(decorative: image!, scale: 3).resizable()
    /// ```
    ///
    /// Returns `nil` when the size isn't positive or the image can't be created.
    public func toCGImage(
        width: Int,
        height: Int,
        startPoint: CGPoint = CGPoint(x: 0.5, y: 0),
        endPoint: CGPoint = CGPoint(x: 0.5, y: 1),
        colorSpace: ColorSpace = .displayP3,
        dithered: Bool = true
    ) -> CGImage? {
        guard width > 0, height > 0, width <= 16384, height <= 16384 else { return nil }

        // Sample the gradient once per step of a lookup table, in the output color space
        let samples = 2048
        let table: [SIMD4<Double>] = (0..<samples).map { index in
            let color = self.color(at: Double(index) / Double(samples - 1))
            let components = color.toComponents(in: colorSpace)
            let alpha = color.alpha.clamped(to: 0...1)
            return SIMD4(
                components.x.clamped(to: 0...1) * alpha,
                components.y.clamped(to: 0...1) * alpha,
                components.z.clamped(to: 0...1) * alpha,
                alpha
            )
        }

        let start = SIMD2(Double(startPoint.x), Double(startPoint.y))
        let direction = SIMD2(Double(endPoint.x), Double(endPoint.y)) - start
        let lengthSquared = direction.x * direction.x + direction.y * direction.y

        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            let py = (Double(y) + 0.5) / Double(height)
            for x in 0..<width {
                let px = (Double(x) + 0.5) / Double(width)
                var location = 0.0
                if lengthSquared > 0 {
                    let offset = SIMD2(px, py) - start
                    location = ((offset.x * direction.x + offset.y * direction.y) / lengthSquared).clamped(to: 0...1)
                }
                let position = location * Double(samples - 1)
                let lower = min(Int(position), samples - 2)
                let fraction = position - Double(lower)
                let value = table[lower] + (table[lower + 1] - table[lower]) * fraction

                let index = (y * width + x) * 4
                func quantize(_ component: Double, channel: UInt64) -> UInt8 {
                    var scaled = component * 255
                    // Opaque and transparent pixels stay so
                    if dithered, channel != 3 || (component > 0 && component < 1) {
                        scaled += Dither.triangular(x: x, y: y, channel: channel)
                    }
                    return UInt8(scaled.rounded().clamped(to: 0...255))
                }
                let alpha = quantize(value.w, channel: 3)
                // Premultiplied components can't exceed alpha
                bytes[index] = min(quantize(value.x, channel: 0), alpha)
                bytes[index + 1] = min(quantize(value.y, channel: 1), alpha)
                bytes[index + 2] = min(quantize(value.z, channel: 2), alpha)
                bytes[index + 3] = alpha
            }
        }
        return Dither.image(bytes: bytes, width: width, height: height, colorSpace: colorSpace.toCGColorSpace(), alphaInfo: .premultipliedLast)
    }
}

/// A texture of fine noise, like film grain, to overlay on flat colors and gradients.
///
/// A touch of grain makes flat fills look tactile rather than digital, and, like
/// dithering, hides banding in gradients drawn by the system. Overlay it at a low
/// opacity, tiled:
///
/// ```swift
/// let grain = GrainTexture(width: 128, height: 128)
/// background
///     .overlay(
///         grain.toImage()?
///             .resizable(resizingMode: .tile)
///             .blendMode(.overlay)
///             .opacity(0.08)
///     )
/// ```
///
/// The texture is centered on middle gray, so the `overlay` and `softLight` blend
/// modes leave the average color unchanged. The same `seed` always gives the same
/// texture. It wraps at its edges, so it tiles without seams.
@frozen
public struct GrainTexture: Hashable, Sendable, Codable {

    /// The width of the texture, in pixels.
    public var width: Int

    /// The height of the texture, in pixels.
    public var height: Int

    /// How strong the grain is, from `0`, a flat middle gray, to `1`, where the noise
    /// spans from black to white.
    public var intensity: Double

    /// Whether the grain is gray, or has independent noise in each component, like
    /// the color noise of film.
    public var isMonochrome: Bool

    /// The seed of the noise.
    public var seed: UInt64

    /// Creates a texture of noise.
    @inlinable
    public init(
        width: Int = 128,
        height: Int = 128,
        intensity: Double = 0.5,
        isMonochrome: Bool = true,
        seed: UInt64 = 0
    ) {
        self.width = width
        self.height = height
        self.intensity = intensity
        self.isMonochrome = isMonochrome
        self.seed = seed
    }

    /// The texture as an opaque sRGB image, or `nil` when the size isn't positive.
    public func toCGImage() -> CGImage? {
        guard width > 0, height > 0, width <= 16384, height <= 16384 else { return nil }
        let intensity = intensity.isNaN ? 0 : intensity.clamped(to: 0...1)
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4
                for channel in 0..<3 {
                    let noise = Dither.triangular(x: x, y: y, channel: isMonochrome ? 0 : UInt64(channel), seed: seed)
                    // Triangular noise is in -1...1, centered on middle gray
                    let value = 127.5 + noise * 127.5 * intensity
                    bytes[index + channel] = UInt8(value.rounded().clamped(to: 0...255))
                }
            }
        }
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        return Dither.image(bytes: bytes, width: width, height: height, colorSpace: colorSpace, alphaInfo: .noneSkipLast)
    }

    /// The texture as a SwiftUI image, or `nil` when the size isn't positive.
    ///
    /// `scale` is the number of pixels per point, so the default of `1` gives grain a
    /// point across, and the screen's scale gives grain a pixel across.
    public func toImage(scale: CGFloat = 1) -> Image? {
        toCGImage().map { Image(decorative: $0, scale: scale) }
    }
}

/// Deterministic noise for dithering and grain.
enum Dither {

    /// A hash of a pixel and channel, as a uniform value in `0..<1`.
    static func uniform(x: Int, y: Int, channel: UInt64, seed: UInt64, salt: UInt64) -> Double {
        var z = seed &+ UInt64(truncatingIfNeeded: x) &* 0x9E3779B97F4A7C15
        z ^= UInt64(truncatingIfNeeded: y) &* 0xC2B2AE3D27D4EB4F
        z ^= (channel &+ 1) &* 0x165667B19E3779F9
        z ^= salt &* 0xD6E8FEB86659FD93
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        z ^= z >> 31
        return Double(z >> 11) * 0x1p-53
    }

    /// Noise with a triangular distribution in `-1...1`, the standard for dithering,
    /// since it hides banding without the noise varying with the signal.
    static func triangular(x: Int, y: Int, channel: UInt64, seed: UInt64 = 0) -> Double {
        uniform(x: x, y: y, channel: channel, seed: seed, salt: 1) - uniform(x: x, y: y, channel: channel, seed: seed, salt: 2)
    }

    /// An 8-bit RGBA image from bytes.
    static func image(bytes: [UInt8], width: Int, height: Int, colorSpace: CGColorSpace, alphaInfo: CGImageAlphaInfo) -> CGImage? {
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: alphaInfo.rawValue | CGBitmapInfo.byteOrder32Big.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}
