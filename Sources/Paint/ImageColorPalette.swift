//
// Copyright (c) Nathan Tannar
//

import CoreGraphics
import Foundation
import ImageIO
#if canImport(Combine)
import Combine
#endif
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// The most prominent colors of an image: a background color, and three colors that
/// contrast with it, for content such as text drawn over or beside the image.
///
/// - ``background`` is the most common color. If that's almost black or white, a color
///   with a hue that's nearly as common is preferred, so the background has some character.
/// - ``primary``, ``secondary`` and ``detail`` are the most common colors on the other
///   side of light and dark from the background, with enough contrast to read on it. Each
///   is distinct from the ones before it, and grays are never distinct from each other.
///
/// Contrast is measured with ``APCAContrast``, and distinctness in Oklab, so both match
/// how different the colors look. Text colors that can't be found are white on dark
/// backgrounds and black on light ones.
///
/// Create one from an image with `toColorPalette(quality:)`, available on `CGImage`,
/// `UIImage` and `NSImage`:
///
/// ```swift
/// let palette = image.toColorPalette(quality: .low)
/// ```
///
/// The image can be scaled down first, see ``Quality``. Similar colors are grouped
/// and averaged, so noise and gradients don't split a color into many rarely used ones.
///
/// Colors are counted in the color space of the image, so wide gamut images, such as
/// Display P3 photos, keep their colors: they're stored as extended sRGB, with
/// components outside `0...1` for colors outside sRGB. Images that aren't RGB, such
/// as grayscale or CMYK images, are converted to sRGB.
@frozen
public struct ImageColorPalette: Hashable, Sendable, Codable {

    /// The size an image is scaled down to before its colors are counted.
    ///
    /// Smaller sizes are faster, and usually find the same colors, but can miss
    /// small details. Images are never scaled up, and are always at least one pixel
    /// on each side.
    ///
    /// A quality can be written as a number. Float literals are a ``scale(_:)`` and
    /// integer literals are a ``dimension(_:)``:
    ///
    /// ```swift
    /// image.toColorPalette(quality: 0.25) // .scale(0.25), 25% of the size
    /// image.toColorPalette(quality: 200)  // .dimension(200), at most 200 pixels
    /// ```
    ///
    /// Note that `1.0` is the full size, but `1` is a single pixel.
    ///
    /// Encodes as `{"scale": 0.25}` or `{"dimension": 200}`.
    @frozen
    public enum Quality: Hashable, Sendable, Codable, ExpressibleByFloatLiteral, ExpressibleByIntegerLiteral {
        /// Scaled by a fraction of the original size, in `0...1`, so `0.25` is 25%
        /// of the width and height.
        ///
        /// Fractions above `1`, and `NaN`, are the full size. Fractions of `0` or less
        /// are a single pixel.
        case scale(Double)

        /// Scaled so that the longest side is at most this many pixels, keeping the
        /// aspect ratio. Images that already fit are the full size.
        case dimension(Int)

        /// Creates a ``scale(_:)`` quality from a fraction of the original size.
        @inlinable
        public init(floatLiteral value: Double) {
            self = .scale(value.clamped(to: 0...1))
        }

        /// Creates a ``dimension(_:)`` quality from a maximum number of pixels on the
        /// longest side.
        @inlinable
        public init(integerLiteral value: Int) {
            self = .dimension(value)
        }

        /// Scaled to at most 50 pixels on the longest side.
        public static let low = Quality.dimension(50)

        /// Scaled to at most 100 pixels on the longest side.
        public static let medium = Quality.dimension(100)

        /// Scaled to at most 250 pixels on the longest side.
        public static let high = Quality.dimension(250)

        /// The full size of the image, so no detail is lost to scaling. Finds the
        /// smallest details, but reads every pixel.
        public static let lossless = Quality.scale(1)

        private enum CodingKeys: String, CodingKey {
            case scale
            case dimension
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            switch (container.contains(.scale), container.contains(.dimension)) {
            case (true, false):
                self = .scale(try container.decode(Double.self, forKey: .scale))
            case (false, true):
                self = .dimension(try container.decode(Int.self, forKey: .dimension))
            default:
                throw DecodingError.dataCorrupted(DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected exactly one of 'scale' or 'dimension'"
                ))
            }
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .scale(let scale):
                try container.encode(scale, forKey: .scale)
            case .dimension(let dimension):
                try container.encode(dimension, forKey: .dimension)
            }
        }

        /// The size an image of `width` by `height` pixels is scaled down to.
        func scaledSize(width: Int, height: Int) -> (width: Int, height: Int) {
            let factor: Double
            switch self {
            case .scale(let scale):
                factor = scale.isNaN ? 1 : min(max(scale, 0), 1)
            case .dimension(let dimension):
                let longest = max(width, height)
                factor = longest > 0 ? min(Double(max(dimension, 1)) / Double(longest), 1) : 1
            }
            guard factor < 1 else { return (width, height) }
            return (
                max(1, Int((Double(width) * factor).rounded())),
                max(1, Int((Double(height) * factor).rounded()))
            )
        }
    }

    /// The most common color, suitable for a background behind the other colors.
    public var background: RGBAColor

    /// The most common color that contrasts with ``background``.
    public var primary: RGBAColor

    /// The next most common color that contrasts with ``background``, distinct from ``primary``.
    public var secondary: RGBAColor

    /// The next most common color that contrasts with ``background``, distinct from ``primary`` and ``secondary``.
    public var detail: RGBAColor

    /// Creates a palette from its colors.
    @inlinable
    public init(
        background: RGBAColor,
        primary: RGBAColor,
        secondary: RGBAColor,
        detail: RGBAColor
    ) {
        self.background = background
        self.primary = primary
        self.secondary = secondary
        self.detail = detail
    }

    /// Finds the prominent colors of an image.
    ///
    /// Pixels that are mostly transparent are ignored. Returns `nil` if the image is
    /// empty or entirely transparent.
    ///
    /// This reads every pixel of the scaled image. The default quality of
    /// ``Quality/lossless`` is the full size, so call it off the main thread for large
    /// images, or pass a lower quality such as ``Quality/low``.
    @inlinable
    public init?(_ image: CGImage, quality: Quality = .lossless) {
        self.init(candidates: ImageColorDecoder.candidates(in: image, quality: quality))
    }

    /// Creates a palette from the colors of an image, most common first.
    public init?(candidates: [ImageColorDecoder.Candidate]?) {
        guard let candidates, !candidates.isEmpty else { return nil }
        let background = Self.background(from: candidates)
        let textColors = Self.textColors(from: candidates, on: background)
        let fallback = background.color.contrast(.apca).isDark ? RGBAColor(red: 1, green: 1, blue: 1) : RGBAColor(red: 0, green: 0, blue: 0)
        func textColor(at index: Int) -> RGBAColor {
            index < textColors.count ? textColors[index].color : fallback
        }
        self.init(
            background: background.color,
            primary: textColor(at: 0),
            secondary: textColor(at: 1),
            detail: textColor(at: 2)
        )
    }
}

extension ImageColorPalette {

    private enum Constants {
        /// The background is chosen among colors used by more than this fraction of
        /// the counted pixels, so that it isn't a rarely used color.
        static let backgroundThreshold = 0.01

        /// A background with a hue, in place of an almost black or white one, must be
        /// used more than this often relative to it.
        static let preferredBackgroundRatio = 0.3

        /// Below this OKLCH chroma, a color that's also very light or dark is a plain background.
        static let plainBackgroundChroma = 0.04

        /// At or above this OKLCH lightness, a gray is almost white.
        static let whiteLightness = 0.93

        /// At or below this OKLCH lightness, a gray is almost black.
        static let blackLightness = 0.2

        /// The minimum ``APCAContrast`` of a text color on the background.
        static let minimumContrast: APCAContrast = 30

        /// The minimum Oklab distance between distinct text colors.
        static let minimumDistance = 0.1

        /// Below this OKLCH chroma, a text color is treated as gray.
        static let grayChroma = 0.03
    }

    /// The most common color, preferring one with a hue over almost black or white
    /// when it's nearly as common.
    fileprivate static func background(from candidates: [ImageColorDecoder.Candidate]) -> ImageColorDecoder.Candidate {
        let background = candidates[0]
        guard isPlain(background.color.toOKLCHColor()) else { return background }
        let total = candidates.reduce(0) { $0 + $1.count }
        let threshold = Double(total) * Constants.backgroundThreshold
        for candidate in candidates.dropFirst() {
            guard
                Double(candidate.count) > threshold,
                Double(candidate.count) / Double(background.count) > Constants.preferredBackgroundRatio
            else {
                break
            }
            if !isPlain(candidate.color.toOKLCHColor()) {
                return candidate
            }
        }
        return background
    }

    /// Up to three of the most common colors that read on the background, each
    /// distinct from the ones before it.
    fileprivate static func textColors(from candidates: [ImageColorDecoder.Candidate], on background: ImageColorDecoder.Candidate) -> [ImageColorDecoder.Candidate] {
        // Text colors are on the other side of light and dark from the background
        let isDarkBackground = background.color.contrast(.apca).isDark
        var textColors: [(candidate: ImageColorDecoder.Candidate, oklch: OKLCHColor)] = []
        for candidate in candidates where textColors.count < 3 {
            guard
                candidate.color.contrast(.apca).isDark != isDarkBackground,
                candidate.color.contrast(.apca).against(background.color).meets(Constants.minimumContrast)
            else {
                continue
            }
            // Converted only for colors that read on the background
            let oklch = candidate.color.toOKLCHColor()
            guard textColors.allSatisfy({ isDistinct($0.oklch, oklch) }) else { continue }
            textColors.append((candidate, oklch))
        }
        return textColors.map(\.candidate)
    }

    /// Whether a color is almost black or white, so it makes a plain background.
    private static func isPlain(_ color: OKLCHColor) -> Bool {
        color.chroma < Constants.plainBackgroundChroma
            && (color.lightness >= Constants.whiteLightness || color.lightness <= Constants.blackLightness)
    }

    /// Whether two colors look different enough to use together. Two grays are
    /// never distinct, so the text colors aren't only shades of gray.
    private static func isDistinct(_ lhs: OKLCHColor, _ rhs: OKLCHColor) -> Bool {
        if lhs.chroma < Constants.grayChroma, rhs.chroma < Constants.grayChroma {
            return false
        }
        let lightness = lhs.lightness - rhs.lightness
        let a = lhs.a - rhs.a
        let b = lhs.b - rhs.b
        return (lightness * lightness + a * a + b * b).squareRoot() > Constants.minimumDistance
    }
}

extension CGImage {

    /// Finds the prominent colors of the image, see ``ImageColorPalette``.
    ///
    /// Returns `nil` if the image is empty or entirely transparent. The default
    /// quality reads every pixel, see ``ImageColorPalette/init(_:quality:)``.
    public func toColorPalette(quality: ImageColorPalette.Quality = .lossless) -> ImageColorPalette? {
        ImageColorPalette(self, quality: quality)
    }
}

#if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
extension UIImage {

    /// Finds the prominent colors of the image, see ``ImageColorPalette``.
    ///
    /// The image draws itself at the scaled size of its size in pixels, `size` times
    /// `scale`, so its tint, symbol configuration, rendering mode and orientation are
    /// applied, and vector images, such as symbol images, are only rendered at the size
    /// counted. Bitmap images are drawn with the primaries of their `CGImage`, like a
    /// `CGImage`, and other images, such as symbol images or images backed by a
    /// `CIImage`, in Display P3, so that wide gamut colors, such as system colors,
    /// aren't clipped. Returns `nil` if the image is empty or entirely transparent.
    public func toColorPalette(quality: ImageColorPalette.Quality = .lossless) -> ImageColorPalette? {
        ImageColorPalette(candidates: toColorPalettePixels(quality: quality).flatMap({ ImageColorDecoder.candidates(in: $0) }))
    }

    /// Draws the image into a bitmap at its scaled size, without rendering it first.
    func toColorPalettePixels(quality: ImageColorPalette.Quality) -> ImageColorDecoder.Pixels? {
        // The `CGImage` of a symbol image is its untinted glyph, so it's drawn by UIKit,
        // which applies the tint and symbol configuration. Its color space doesn't
        // describe the drawn colors either.
        let bitmap = isSymbolImage || renderingMode == .alwaysTemplate ? nil : cgImage
        // The bitmap's origin is at the bottom, so the image is drawn upside down,
        // which doesn't change its colors
        return ImageColorDecoder.pixels(
            width: Int((size.width * scale).rounded()),
            height: Int((size.height * scale).rounded()),
            quality: quality,
            preferring: bitmap.map(ImageColorDecoder.preferredColorSpace(for:)) ?? .displayP3
        ) { context, rect in
            UIGraphicsPushContext(context)
            defer { UIGraphicsPopContext() }
            draw(in: rect)
        }
    }
}
#endif

#if os(macOS)
extension NSImage {

    /// Finds the prominent colors of the image, see ``ImageColorPalette``.
    ///
    /// Images with a single bitmap representation, such as decoded image files, are
    /// read like a `CGImage`. Other images, such as symbol, PDF or drawn images, draw
    /// themselves at the scaled size of their largest representation, in Display P3,
    /// so the best representation for that size is used. Returns `nil` if the image is
    /// empty or entirely transparent.
    public func toColorPalette(quality: ImageColorPalette.Quality = .lossless) -> ImageColorPalette? {
        ImageColorPalette(candidates: toColorPalettePixels(quality: quality).flatMap({ ImageColorDecoder.candidates(in: $0) }))
    }

    /// The `CGImage` of an image with a single bitmap representation, without
    /// rendering it. Vector representations, such as symbols, have no pixel size.
    var bitmapCGImage: CGImage? {
        guard
            representations.count == 1,
            let representation = representations.first,
            representation.pixelsWide > 0, representation.pixelsHigh > 0
        else {
            return nil
        }
        var rect = CGRect(origin: .zero, size: size)
        return cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }

    /// Draws the image into a bitmap at its scaled size, without rendering it first.
    ///
    /// `NSImage` isn't `Sendable`, so call this on the thread that owns the image.
    func toColorPalettePixels(quality: ImageColorPalette.Quality) -> ImageColorDecoder.Pixels? {
        if let bitmapCGImage {
            return ImageColorDecoder.pixels(in: bitmapCGImage, quality: quality)
        }
        // The largest representation in pixels, or the size in points for vector images
        let largest = representations
            .filter { $0.pixelsWide > 0 && $0.pixelsHigh > 0 }
            .max { $0.pixelsWide * $0.pixelsHigh < $1.pixelsWide * $1.pixelsHigh }
        return ImageColorDecoder.pixels(
            width: largest?.pixelsWide ?? Int(size.width.rounded()),
            height: largest?.pixelsHigh ?? Int(size.height.rounded()),
            quality: quality,
            preferring: .displayP3
        ) { context, rect in
            NSGraphicsContext.saveGraphicsState()
            defer { NSGraphicsContext.restoreGraphicsState() }
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
            draw(in: rect)
        }
    }
}
#endif

extension ImageColorPalette {

    /// Finds the prominent colors of the image at a file URL.
    ///
    /// The image is decoded at the size of `quality` where possible, so the full image
    /// is never loaded into memory: a 12 megapixel photo at ``Quality/low`` is decoded
    /// at 50 pixels. At ``Quality/lossless``, the default, the full image is decoded.
    ///
    /// Returns `nil` if the file can't be read or decoded, or if the image is empty or
    /// entirely transparent. This reads the file and its pixels on the calling thread;
    /// use the `async` overload to load it concurrently.
    @inlinable
    public init?(contentsOf url: URL, quality: Quality = .lossless) {
        self.init(candidates: ImageColorDecoder.candidates(contentsOf: url, quality: quality))
    }

    /// Finds the prominent colors of the image at a file URL, loading and reading it
    /// concurrently, off the main actor.
    ///
    /// See ``init(contentsOf:quality:)``. Returns `nil` if the task is cancelled before
    /// the image is read.
    @inlinable
    public init?(contentsOf url: URL, quality: Quality = .lossless) async {
        // Calls the synchronous path directly, since before Swift 6.2 the compiler
        // resolves `ImageColorPalette(contentsOf:quality:)` to this `async` overload
        guard let palette = await ImageColorDecoder.concurrent({
            ImageColorPalette(candidates: ImageColorDecoder.candidates(contentsOf: url, quality: quality))
        }) else {
            return nil
        }
        self = palette
    }

    #if canImport(Combine)
    /// A publisher that finds the prominent colors of the image at a file URL on a
    /// global queue each time it's subscribed to, see ``init(contentsOf:quality:)-9qsk8``.
    ///
    /// The palette is published on that queue, so use `receive(on:)` to update UI.
    public static func publisher(
        contentsOf url: URL,
        quality: Quality = .lossless
    ) -> AnyPublisher<ImageColorPalette?, Never> {
        ImageColorDecoder.publisher { ImageColorPalette(contentsOf: url, quality: quality) }
    }
    #endif
}

extension CGImage {

    /// Finds the prominent colors of the image concurrently, off the main actor, see
    /// ``ImageColorPalette``.
    ///
    /// Returns `nil` if the image is empty or entirely transparent, or if the task is
    /// cancelled before the image is read.
    public func toColorPalette(quality: ImageColorPalette.Quality = .lossless) async -> ImageColorPalette? {
        await ImageColorDecoder.concurrent { ImageColorPalette(self, quality: quality) }
    }

    #if canImport(Combine)
    /// A publisher that finds the prominent colors of the image on a global queue each
    /// time it's subscribed to, see ``ImageColorPalette``.
    ///
    /// The palette is published on that queue, so use `receive(on:)` to update UI.
    public func toColorPalettePublisher(quality: ImageColorPalette.Quality = .lossless) -> AnyPublisher<ImageColorPalette?, Never> {
        ImageColorDecoder.publisher { ImageColorPalette(self, quality: quality) }
    }
    #endif
}

#if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
extension UIImage {

    /// Finds the prominent colors of the image concurrently, off the main actor, see
    /// ``toColorPalette(quality:)``.
    ///
    /// Returns `nil` if the image is empty, entirely transparent or can't be rendered,
    /// or if the task is cancelled before the image is read.
    public func toColorPalette(quality: ImageColorPalette.Quality = .lossless) async -> ImageColorPalette? {
        await ImageColorDecoder.concurrent { self.toColorPalette(quality: quality) }
    }

    #if canImport(Combine)
    /// A publisher that finds the prominent colors of the image on a global queue each
    /// time it's subscribed to, see ``toColorPalette(quality:)-5zhz3``.
    ///
    /// The palette is published on that queue, so use `receive(on:)` to update UI.
    public func toColorPalettePublisher(quality: ImageColorPalette.Quality = .lossless) -> AnyPublisher<ImageColorPalette?, Never> {
        ImageColorDecoder.publisher { self.toColorPalette(quality: quality) }
    }
    #endif
}
#endif

#if os(macOS)
extension NSImage {

    /// Finds the prominent colors of the image concurrently, off the main actor, see
    /// ``toColorPalette(quality:)``.
    ///
    /// `NSImage` isn't `Sendable`. Images with a single bitmap representation are read
    /// entirely concurrently through their `CGImage`. Other images, such as symbol or
    /// PDF images, are drawn on the calling thread at the scaled size, which is quick,
    /// and their pixels are counted concurrently. Returns `nil` if the image is empty
    /// or entirely transparent, or if the task is cancelled before the image is read.
    public func toColorPalette(quality: ImageColorPalette.Quality = .lossless) async -> ImageColorPalette? {
        if let bitmapCGImage {
            return await bitmapCGImage.toColorPalette(quality: quality)
        }
        guard let pixels = toColorPalettePixels(quality: quality) else { return nil }
        return await ImageColorDecoder.concurrent {
            ImageColorPalette(candidates: ImageColorDecoder.candidates(in: pixels))
        }
    }

    #if canImport(Combine)
    /// A publisher that finds the prominent colors of the image on a global queue each
    /// time it's subscribed to, see ``toColorPalette(quality:)-44ecv``.
    ///
    /// `NSImage` isn't `Sendable`, so images without a single bitmap representation are
    /// drawn when the publisher is created, and counted on each subscription. The
    /// palette is published on that queue, so use `receive(on:)` to update UI.
    public func toColorPalettePublisher(quality: ImageColorPalette.Quality = .lossless) -> AnyPublisher<ImageColorPalette?, Never> {
        if let bitmapCGImage {
            return bitmapCGImage.toColorPalettePublisher(quality: quality)
        }
        guard let pixels = toColorPalettePixels(quality: quality) else {
            return Just(nil).eraseToAnyPublisher()
        }
        return ImageColorDecoder.publisher {
            ImageColorPalette(candidates: ImageColorDecoder.candidates(in: pixels))
        }
    }
    #endif
}
#endif

