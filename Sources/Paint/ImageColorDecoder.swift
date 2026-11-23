//
// Copyright (c) Nathan Tannar
//

import CoreGraphics
import Foundation
import ImageIO
#if canImport(Combine)
import Combine
#endif

/// Finds the colors of images: groups similar pixels together and counts them, which
/// ``ImageColorPalette`` and ``ImageColorSwatches`` choose their colors from.
///
/// Images are drawn at the scaled size of a ``ImageColorPalette/Quality``, into 8-bit
/// RGB with their own primaries, so wide gamut colors, such as Display P3 colors, are
/// kept. Pixels that are mostly transparent are ignored, and similar colors are
/// grouped by the top 5 bits of each channel and averaged.
///
/// ```swift
/// let candidates = ImageColorDecoder.candidates(in: image, quality: .medium)
/// let mostCommon = candidates?.first?.color
/// ```
@frozen
public enum ImageColorDecoder {

    private enum Constants {
        /// The number of bits kept per channel when grouping similar colors.
        static let bitsPerChannel = 5

        /// Pixels with less alpha than this, out of `255`, are ignored.
        static let minimumAlpha = 128

    }

    /// A group of similar colors in an image, and how many pixels use them.
    @frozen
    public struct Candidate: Hashable, Sendable {

        /// The key of the group: the top 5 bits of each channel, packed as red, green
        /// and blue.
        public var key: Int

        /// The number of pixels in the group.
        public var count: Int

        /// The average color of the pixels in the group, in extended sRGB.
        public var color: RGBAColor
    }

    /// An image drawn into an 8-bit, premultiplied RGBA bitmap at its scaled size,
    /// ready to count. Drawing and counting are separate, so an image that must be
    /// drawn on the calling thread, such as an `NSImage`, can be counted concurrently.
    struct Pixels: Sendable {
        var bytes: [UInt8]
        var width: Int
        var height: Int
        /// The color space the components are in.
        var colorSpace: ColorSpace
    }

    /// Draws an image of `width` by `height` pixels into a bitmap at its scaled size.
    ///
    /// Draws into 8-bit, gamma encoded RGB in `preferred`, falling back to sRGB if a
    /// bitmap can't be created in it. `draw` is called with the bitmap context and the
    /// rect to fill, and may be called twice.
    static func pixels(
        width imageWidth: Int,
        height imageHeight: Int,
        quality: ImageColorPalette.Quality,
        preferring preferred: ColorSpace,
        draw: (CGContext, CGRect) -> Void
    ) -> Pixels? {
        guard imageWidth > 0, imageHeight > 0 else { return nil }
        let (width, height) = quality.scaledSize(width: imageWidth, height: imageHeight)
        let bytesPerRow = width * 4
        var bytes = [UInt8](repeating: 0, count: bytesPerRow * height)
        var isZeroed = true
        func drawBitmap(in colorSpace: CGColorSpace) -> Bool {
            bytes.withUnsafeMutableBytes { buffer -> Bool in
                // Transparent images draw over the buffer, so a retry starts from zero
                if !isZeroed {
                    buffer.initializeMemory(as: UInt8.self, repeating: 0)
                }
                isZeroed = false
                guard let context = CGContext(
                    data: buffer.baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow,
                    space: colorSpace,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                ) else {
                    return false
                }
                context.interpolationQuality = .medium
                draw(context, CGRect(x: 0, y: 0, width: width, height: height))
                return true
            }
        }
        guard let colorSpace = [preferred, .sRGB].first(where: { drawBitmap(in: $0.toCGColorSpace()) }) else {
            return nil
        }
        return Pixels(bytes: bytes, width: width, height: height, colorSpace: colorSpace)
    }

    /// Draws a `CGImage` into a bitmap at its scaled size.
    ///
    /// Draws into 8-bit, gamma encoded RGB with the primaries of the image, so that
    /// colors outside sRGB, such as Display P3 colors, keep their gamut, and every
    /// pixel converts to sRGB without ColorSync. Extended and linear color spaces are
    /// drawn in their standard range, gamma encoded form, since 8-bit bitmaps can't be
    /// extended. Other RGB color spaces, such as Adobe RGB, are drawn in Display P3,
    /// the gamut of Apple displays. Images that aren't RGB, such as grayscale or CMYK
    /// images, are drawn in sRGB.
    static func pixels(in image: CGImage, quality: ImageColorPalette.Quality) -> Pixels? {
        pixels(width: image.width, height: image.height, quality: quality, preferring: preferredColorSpace(for: image)) { context, rect in
            context.draw(image, in: rect)
        }
    }

    /// The color space to draw an image into, see ``pixels(in:quality:)``.
    static func preferredColorSpace(for image: CGImage) -> ColorSpace {
        guard let imageColorSpace = image.colorSpace, imageColorSpace.model == .rgb else {
            return .sRGB
        }
        return ColorSpace(imageColorSpace)?.toGammaEncodedColorSpace() ?? .displayP3
    }

    /// Groups the pixels of an image by color, most common first.
    ///
    /// The image is drawn at the scaled size of `quality`. Pixels that are mostly
    /// transparent are ignored. Ties in count are ordered by ``Candidate/key``, so the
    /// result is the same each time. Returns `nil` if the image is empty or entirely
    /// transparent.
    ///
    /// This reads every pixel of the scaled image. The default quality of
    /// ``ImageColorPalette/Quality/lossless`` is the full size, so call it off the main
    /// thread for large images, or pass a lower quality such as
    /// ``ImageColorPalette/Quality/low``.
    public static func candidates(in image: CGImage, quality: ImageColorPalette.Quality = .lossless) -> [Candidate]? {
        pixels(in: image, quality: quality).flatMap({ candidates(in: $0) })
    }

    /// Groups the pixels of the image at a file URL by color, most common first.
    ///
    /// The image is decoded at the size of `quality` where possible, so the full image
    /// is never loaded into memory, exactly as ``ImageColorPalette/init(contentsOf:quality:)-9qsk8``
    /// and ``ImageColorSwatches/init(contentsOf:quality:)-726gw`` decode it, so their colors
    /// are among these groups. Returns `nil` if the file can't be read or decoded, or if
    /// the image is empty or entirely transparent.
    public static func candidates(contentsOf url: URL, quality: ImageColorPalette.Quality = .lossless) -> [Candidate]? {
        guard let (image, quality) = url.toCGImage(quality: quality) else { return nil }
        return candidates(in: image, quality: quality)
    }

    /// Groups the opaque pixels of a drawn image by color, most common first.
    static func candidates(in pixels: Pixels) -> [Candidate]? {
        let colorSpace = pixels.colorSpace
        let groups = pixels.bytes.withUnsafeBytes { buffer in
            self.groups(in: buffer.bindMemory(to: UInt8.self), pixelCount: pixels.width * pixels.height)
        }

        var candidates: [Candidate] = []
        for (key, group) in groups.enumerated() where group.count > 0 {
            let count = Double(group.count) * 255
            // Converted to extended sRGB, where colors outside sRGB have components
            // outside `0...1`
            let color = RGBAColor(
                red: Double(group.red) / count,
                green: Double(group.green) / count,
                blue: Double(group.blue) / count,
                colorSpace: colorSpace
            )
            candidates.append(Candidate(key: key, count: group.count, color: color))
        }
        guard !candidates.isEmpty else { return nil }
        // Ties are broken by key, so the result doesn't depend on the sort
        candidates.sort { $0.count != $1.count ? $0.count > $1.count : $0.key < $1.key }
        return candidates
    }

    /// The pixels of a group of similar colors, and the sum of each channel to average them.
    struct Group {
        var count = 0
        var red = 0
        var green = 0
        var blue = 0
    }

    /// Counts premultiplied RGBA pixels into groups of similar colors, keyed by the
    /// top bits of each channel.
    ///
    /// Large images are counted in chunks on every core, each into its own groups,
    /// which are then added up.
    static func groups(in pixels: UnsafeBufferPointer<UInt8>, pixelCount: Int) -> [Group] {
        let bitsPerChannel = Constants.bitsPerChannel
        let groupCount = 1 << (bitsPerChannel * 3)
        // Chunks of at least 256K pixels, so small images aren't split, and at most
        // 16M pixels, so that `UInt32` sums can't overflow
        let chunkCount = min(
            max(pixelCount / (1 << 18), 1),
            max(ProcessInfo.processInfo.activeProcessorCount, (pixelCount + (1 << 24) - 1) >> 24)
        )
        let chunkSize = (pixelCount + chunkCount - 1) / chunkCount

        struct ChunkGroup {
            var count: UInt32 = 0
            var red: UInt32 = 0
            var green: UInt32 = 0
            var blue: UInt32 = 0
        }
        let chunks = UnsafeMutableBufferPointer<ChunkGroup>.allocate(capacity: groupCount * chunkCount)
        chunks.initialize(repeating: ChunkGroup())
        defer { chunks.deallocate() }

        nonisolated(unsafe) let base = pixels.baseAddress!
        nonisolated(unsafe) let chunkBase = chunks.baseAddress!
        let minimumAlpha = Constants.minimumAlpha
        let shift = 8 - bitsPerChannel
        DispatchQueue.concurrentPerform(iterations: chunkCount) { chunk in
            let groups = chunkBase + chunk * groupCount
            let start = chunk * chunkSize
            let end = min(start + chunkSize, pixelCount)
            guard start < end else { return }
            var pixel = base + start * 4
            for _ in start..<end {
                defer { pixel += 4 }
                let alpha = Int(pixel[3])
                guard alpha >= minimumAlpha else { continue }
                let red: Int
                let green: Int
                let blue: Int
                if alpha == 255 {
                    // Most pixels are opaque, so skip unpremultiplying them
                    red = Int(pixel[0])
                    green = Int(pixel[1])
                    blue = Int(pixel[2])
                } else {
                    // Unpremultiply, rounding to the nearest value
                    red = min((Int(pixel[0]) * 255 + alpha / 2) / alpha, 255)
                    green = min((Int(pixel[1]) * 255 + alpha / 2) / alpha, 255)
                    blue = min((Int(pixel[2]) * 255 + alpha / 2) / alpha, 255)
                }
                let key = (red >> shift) << (bitsPerChannel * 2) | (green >> shift) << bitsPerChannel | (blue >> shift)
                groups[key].count &+= 1
                groups[key].red &+= UInt32(red)
                groups[key].green &+= UInt32(green)
                groups[key].blue &+= UInt32(blue)
            }
        }

        var groups = [Group](repeating: Group(), count: groupCount)
        for chunk in 0..<chunkCount {
            let offset = chunk * groupCount
            for key in 0..<groupCount {
                let group = chunks[offset + key]
                guard group.count > 0 else { continue }
                groups[key].count += Int(group.count)
                groups[key].red += Int(group.red)
                groups[key].green += Int(group.green)
                groups[key].blue += Int(group.blue)
            }
        }
        return groups
    }

    // MARK: - Async and Combine

    // Runs work on the global concurrent pool, never on the caller's actor, as part of
    // the caller's task, so its priority, task-local values and cancellation carry over.
    //
    // From Swift 6.2, a plain `nonisolated` async function runs on the caller's actor
    // when the module enables `NonisolatedNonsendingByDefault` (SE-0461), so it's marked
    // `@concurrent`, which always runs on the global pool. Earlier compilers don't have
    // `@concurrent`, but there a `nonisolated` async function always runs on the global
    // pool (SE-0338).
    #if compiler(>=6.2)
    /// Runs work on the global concurrent pool, off the main actor, as part of the
    /// current task. Returns `nil` if the task is cancelled before the work starts.
    @concurrent
    @usableFromInline
    static func concurrent<T: Sendable>(_ work: @Sendable () -> T?) async -> T? {
        guard !Task.isCancelled else { return nil }
        return work()
    }
    #else
    /// Runs work on the global concurrent pool, off the main actor, as part of the
    /// current task. Returns `nil` if the task is cancelled before the work starts.
    @usableFromInline
    nonisolated static func concurrent<T: Sendable>(_ work: @Sendable () -> T?) async -> T? {
        guard !Task.isCancelled else { return nil }
        return work()
    }
    #endif

    #if canImport(Combine)
    /// A publisher that runs work on a global queue each time it's subscribed to, then
    /// publishes its result and finishes. The result is published on that queue.
    static func publisher<T>(_ work: @escaping @Sendable () -> T?) -> AnyPublisher<T?, Never> {
        Just(())
            .subscribe(on: DispatchQueue.global(qos: .userInitiated))
            .map { _ in work() }
            .eraseToAnyPublisher()
    }
    #endif
}

extension URL {

    /// Decodes the image at the URL, at the size of `quality` where possible, for
    /// ``ImageColorPalette/init(contentsOf:quality:)-9qsk8`` and
    /// ``ImageColorSwatches/init(contentsOf:quality:)-726gw``.
    ///
    /// Returns the image and the quality left to apply to it: when the image is decoded
    /// at a reduced size, it's already scaled, so the quality is ``ImageColorPalette/Quality/lossless``.
    func toCGImage(
        quality: ImageColorPalette.Quality
    ) -> (image: CGImage, quality: ImageColorPalette.Quality)? {
        // Not cached, since the image is read once
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard
            let source = CGImageSourceCreateWithURL(self as CFURL, sourceOptions),
            CGImageSourceGetCount(source) > 0
        else {
            return nil
        }
        // The pixel size is read from the header, without decoding the image
        if
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? Int,
            let height = properties[kCGImagePropertyPixelHeight] as? Int,
            width > 0, height > 0
        {
            let scaled = quality.scaledSize(width: width, height: height)
            if scaled.width < width || scaled.height < height {
                // Decoded straight to the reduced size, so the full image is never in
                // memory. JPEG and HEIF decoders can skip detail they don't need.
                let thumbnailOptions: [CFString: Any] = [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceThumbnailMaxPixelSize: max(scaled.width, scaled.height),
                    // Orientation doesn't change which colors an image has
                    kCGImageSourceCreateThumbnailWithTransform: false,
                    kCGImageSourceShouldCacheImmediately: true,
                ]
                if let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) {
                    return (thumbnail, .lossless)
                }
            }
        }
        guard let image = CGImageSourceCreateImageAtIndex(source, 0, sourceOptions) else {
            return nil
        }
        return (image, quality)
    }
}
