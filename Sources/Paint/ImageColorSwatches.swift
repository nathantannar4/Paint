//
// Copyright (c) Nathan Tannar
//

import CoreGraphics
import Foundation
#if canImport(Combine)
import Combine
#endif
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Named swatches of an image: vibrant and muted colors,
/// each in a light, normal and dark variant, plus the dominant color.
///
/// Where ``ImageColorPalette`` picks a background and readable text colors,
/// swatches describe the character of an image, for theming UI around it, such as
/// tinting a header with the vibrant color of artwork.
///
/// - Vibrant swatches are colorful, with an OKLCH chroma of at least `0.08`.
/// - Muted swatches have a hue but little color, with a chroma of `0.015` to `0.08`.
///
/// Each swatch is chosen by how close its lightness and chroma are to the target,
/// and how common it is. A color is used for at most one swatch, so swatches are
/// `nil` when the image has no suitable color, such as the vibrant swatches of a
/// grayscale photo.
///
/// Create one from an image with `toColorSwatches(quality:)`, available on
/// `CGImage`, `UIImage` and `NSImage`.
@frozen
public struct ImageColorSwatches: Hashable, Sendable, Codable {

    /// The most common color of the image.
    public var dominant: RGBAColor

    /// A colorful color of medium lightness.
    public var vibrant: RGBAColor?

    /// A colorful light color.
    public var lightVibrant: RGBAColor?

    /// A colorful dark color.
    public var darkVibrant: RGBAColor?

    /// A subdued color of medium lightness.
    public var muted: RGBAColor?

    /// A subdued light color.
    public var lightMuted: RGBAColor?

    /// A subdued dark color.
    public var darkMuted: RGBAColor?

    /// Creates swatches from their colors.
    @inlinable
    public init(
        dominant: RGBAColor,
        vibrant: RGBAColor?,
        lightVibrant: RGBAColor?,
        darkVibrant: RGBAColor?,
        muted: RGBAColor?,
        lightMuted: RGBAColor?,
        darkMuted: RGBAColor?
    ) {
        self.dominant = dominant
        self.vibrant = vibrant
        self.lightVibrant = lightVibrant
        self.darkVibrant = darkVibrant
        self.muted = muted
        self.lightMuted = lightMuted
        self.darkMuted = darkMuted
    }

    /// Finds the swatches of an image.
    ///
    /// Pixels that are mostly transparent are ignored. Returns `nil` if the image is
    /// empty or entirely transparent. Like ``ImageColorPalette/init(_:quality:)``,
    /// the default quality reads every pixel.
    @inlinable
    public init?(_ image: CGImage, quality: ImageColorPalette.Quality = .lossless) {
        self.init(candidates: ImageColorDecoder.candidates(in: image, quality: quality))
    }

    /// Creates swatches from the colors of an image, most common first.
    @usableFromInline
    init?(candidates: [ImageColorDecoder.Candidate]?) {
        guard let candidates, !candidates.isEmpty else { return nil }
        let total = candidates.reduce(0) { $0 + $1.count }
        let maxCount = Double(candidates[0].count)
        // Rare colors are noise, such as anti-aliased edges. Each swatch scans every
        // remaining color, so they're converted to OKLCH once.
        var available = candidates
            .filter { Double($0.count) >= Double(total) * Constants.minimumPopulation }
            .map { (candidate: $0, oklch: $0.color.toOKLCHColor()) }

        func pick(_ target: Target) -> RGBAColor? {
            var best: (index: Int, score: Double)?
            for (index, (candidate, oklch)) in available.enumerated() {
                guard
                    target.lightness.contains(oklch.lightness),
                    target.chroma.contains(oklch.chroma)
                else {
                    continue
                }
                let lightnessScore = 1 - abs(oklch.lightness - target.targetLightness) / 0.5
                let chromaScore = 1 - min(abs(oklch.chroma - target.targetChroma) / 0.2, 1)
                let populationScore = Double(candidate.count) / maxCount
                let score = lightnessScore * Constants.lightnessWeight
                    + chromaScore * Constants.chromaWeight
                    + populationScore * Constants.populationWeight
                if best == nil || score > best!.score {
                    best = (index, score)
                }
            }
            guard let best else { return nil }
            return available.remove(at: best.index).candidate.color
        }

        let vibrant = pick(.vibrant)
        let lightVibrant = pick(.lightVibrant)
        let darkVibrant = pick(.darkVibrant)
        let muted = pick(.muted)
        let lightMuted = pick(.lightMuted)
        let darkMuted = pick(.darkMuted)
        self.init(
            dominant: candidates[0].color,
            vibrant: vibrant,
            lightVibrant: lightVibrant,
            darkVibrant: darkVibrant,
            muted: muted,
            lightMuted: lightMuted,
            darkMuted: darkMuted
        )
    }

    private enum Constants {
        /// Colors used by less than this fraction of pixels are ignored.
        static let minimumPopulation = 0.001
        static let lightnessWeight = 6.0
        static let chromaWeight = 3.0
        static let populationWeight = 1.0
    }

    /// The OKLCH lightness and chroma a swatch accepts and aims for.
    private struct Target {
        var lightness: ClosedRange<Double>
        var targetLightness: Double
        var chroma: ClosedRange<Double>
        var targetChroma: Double

        static let vibrant = Target(lightness: 0.5...0.8, targetLightness: 0.65, chroma: 0.08...1, targetChroma: 0.25)
        static let lightVibrant = Target(lightness: 0.75...1, targetLightness: 0.86, chroma: 0.08...1, targetChroma: 0.2)
        static let darkVibrant = Target(lightness: 0.2...0.5, targetLightness: 0.4, chroma: 0.08...1, targetChroma: 0.2)
        static let muted = Target(lightness: 0.45...0.75, targetLightness: 0.6, chroma: 0.015...0.08, targetChroma: 0.045)
        static let lightMuted = Target(lightness: 0.75...1, targetLightness: 0.86, chroma: 0.015...0.08, targetChroma: 0.04)
        static let darkMuted = Target(lightness: 0.15...0.5, targetLightness: 0.35, chroma: 0.015...0.08, targetChroma: 0.04)
    }
}

extension CGImage {

    /// Finds the swatches of the image, see ``ImageColorSwatches``.
    ///
    /// Returns `nil` if the image is empty or entirely transparent.
    public func toColorSwatches(quality: ImageColorPalette.Quality = .lossless) -> ImageColorSwatches? {
        ImageColorSwatches(self, quality: quality)
    }
}

#if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
extension UIImage {

    /// Finds the swatches of the image, see ``ImageColorSwatches``.
    ///
    /// The image draws itself at the scaled size, see ``toColorPalette(quality:)-5zhz3``.
    /// Returns `nil` if the image is empty or entirely transparent.
    public func toColorSwatches(quality: ImageColorPalette.Quality = .lossless) -> ImageColorSwatches? {
        ImageColorSwatches(candidates: toColorPalettePixels(quality: quality).flatMap({ ImageColorDecoder.candidates(in: $0) }))
    }
}
#endif

#if os(macOS)
extension NSImage {

    /// Finds the swatches of the image, see ``ImageColorSwatches``.
    ///
    /// Images without a single bitmap representation draw themselves at the scaled
    /// size, see ``toColorPalette(quality:)-44ecv``. Returns `nil` if the image is empty or
    /// entirely transparent.
    public func toColorSwatches(quality: ImageColorPalette.Quality = .lossless) -> ImageColorSwatches? {
        ImageColorSwatches(candidates: toColorPalettePixels(quality: quality).flatMap({ ImageColorDecoder.candidates(in: $0) }))
    }
}
#endif

extension ImageColorSwatches {

    /// Finds the swatches of the image at a file URL.
    ///
    /// The image is decoded at the size of `quality` where possible, so the full image
    /// is never loaded into memory, see ``ImageColorPalette/init(contentsOf:quality:)-9qsk8``.
    ///
    /// Returns `nil` if the file can't be read or decoded, or if the image is empty or
    /// entirely transparent. This reads the file and its pixels on the calling thread;
    /// use the `async` overload to load it concurrently.
    @inlinable
    public init?(contentsOf url: URL, quality: ImageColorPalette.Quality = .lossless) {
        self.init(candidates: ImageColorDecoder.candidates(contentsOf: url, quality: quality))
    }

    /// Finds the swatches of the image at a file URL, loading and reading it
    /// concurrently, off the main actor.
    ///
    /// See ``init(contentsOf:quality:)``. Returns `nil` if the task is cancelled before
    /// the image is read.
    @inlinable
    public init?(contentsOf url: URL, quality: ImageColorPalette.Quality = .lossless) async {
        // Calls the synchronous path directly, since before Swift 6.2 the compiler
        // resolves `ImageColorSwatches(contentsOf:quality:)` to this `async` overload
        guard let swatches = await ImageColorDecoder.concurrent({
            ImageColorSwatches(candidates: ImageColorDecoder.candidates(contentsOf: url, quality: quality))
        }) else {
            return nil
        }
        self = swatches
    }

    #if canImport(Combine)
    /// A publisher that finds the swatches of the image at a file URL on a global queue
    /// each time it's subscribed to, see ``init(contentsOf:quality:)-726gw``.
    ///
    /// The swatches are published on that queue, so use `receive(on:)` to update UI.
    public static func publisher(
        contentsOf url: URL,
        quality: ImageColorPalette.Quality = .lossless
    ) -> AnyPublisher<ImageColorSwatches?, Never> {
        ImageColorDecoder.publisher { ImageColorSwatches(contentsOf: url, quality: quality) }
    }
    #endif
}

extension CGImage {

    /// Finds the swatches of the image concurrently, off the main actor, see
    /// ``ImageColorSwatches``.
    ///
    /// Returns `nil` if the image is empty or entirely transparent, or if the task is
    /// cancelled before the image is read.
    public func toColorSwatches(quality: ImageColorPalette.Quality = .lossless) async -> ImageColorSwatches? {
        await ImageColorDecoder.concurrent { ImageColorSwatches(self, quality: quality) }
    }

    #if canImport(Combine)
    /// A publisher that finds the swatches of the image on a global queue each time
    /// it's subscribed to, see ``ImageColorSwatches``.
    ///
    /// The swatches are published on that queue, so use `receive(on:)` to update UI.
    public func toColorSwatchesPublisher(quality: ImageColorPalette.Quality = .lossless) -> AnyPublisher<ImageColorSwatches?, Never> {
        ImageColorDecoder.publisher { ImageColorSwatches(self, quality: quality) }
    }
    #endif
}

#if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
extension UIImage {

    /// Finds the swatches of the image concurrently, off the main actor, see
    /// ``toColorSwatches(quality:)``.
    ///
    /// Returns `nil` if the image is empty, entirely transparent or can't be rendered,
    /// or if the task is cancelled before the image is read.
    public func toColorSwatches(quality: ImageColorPalette.Quality = .lossless) async -> ImageColorSwatches? {
        await ImageColorDecoder.concurrent { self.toColorSwatches(quality: quality) }
    }

    #if canImport(Combine)
    /// A publisher that finds the swatches of the image on a global queue each time
    /// it's subscribed to, see ``toColorSwatches(quality:)-4mvv0``.
    ///
    /// The swatches are published on that queue, so use `receive(on:)` to update UI.
    public func toColorSwatchesPublisher(quality: ImageColorPalette.Quality = .lossless) -> AnyPublisher<ImageColorSwatches?, Never> {
        ImageColorDecoder.publisher { self.toColorSwatches(quality: quality) }
    }
    #endif
}
#endif

#if os(macOS)
extension NSImage {

    /// Finds the swatches of the image concurrently, off the main actor, see
    /// ``toColorSwatches(quality:)``.
    ///
    /// `NSImage` isn't `Sendable`, so images without a single bitmap representation are
    /// drawn on the calling thread at the scaled size, and counted concurrently, see the `async`
    /// `toColorPalette(quality:)`.
    public func toColorSwatches(quality: ImageColorPalette.Quality = .lossless) async -> ImageColorSwatches? {
        if let bitmapCGImage {
            return await bitmapCGImage.toColorSwatches(quality: quality)
        }
        guard let pixels = toColorPalettePixels(quality: quality) else { return nil }
        return await ImageColorDecoder.concurrent {
            ImageColorSwatches(candidates: ImageColorDecoder.candidates(in: pixels))
        }
    }

    #if canImport(Combine)
    /// A publisher that finds the swatches of the image on a global queue each time
    /// it's subscribed to, see ``toColorSwatches(quality:)-4eoqw``.
    ///
    /// `NSImage` isn't `Sendable`, so images without a single bitmap representation are
    /// drawn when the publisher is created, and counted on each subscription. The
    /// swatches are published on that queue, so use `receive(on:)` to update UI.
    public func toColorSwatchesPublisher(quality: ImageColorPalette.Quality = .lossless) -> AnyPublisher<ImageColorSwatches?, Never> {
        if let bitmapCGImage {
            return bitmapCGImage.toColorSwatchesPublisher(quality: quality)
        }
        guard let pixels = toColorPalettePixels(quality: quality) else {
            return Just(nil).eraseToAnyPublisher()
        }
        return ImageColorDecoder.publisher {
            ImageColorSwatches(candidates: ImageColorDecoder.candidates(in: pixels))
        }
    }
    #endif
}
#endif
