//
// Copyright (c) Nathan Tannar
//

import XCTest
import ImageIO
#if canImport(Combine)
import Combine
#endif
@testable import Paint

/// Tests loading ``ImageColorPalette`` and ``ImageColorSwatches`` from files, and the
/// async and Combine variants.
final class ImageColorLoadingTests: XCTestCase {

    private func url(_ name: String) throws -> URL {
        try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "jpg", subdirectory: "Images"))
    }

    private func cgImage(_ name: String) throws -> CGImage {
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(try url(name) as CFURL, nil))
        return try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
    }

    private let names = ["great-wave", "mona-lisa", "starry-night", "sunflowers", "blue-marble"]

    // In async contexts, Swift picks the async overloads, so these call the
    // synchronous ones for comparison
    private func syncPalette(_ image: CGImage) -> ImageColorPalette? { image.toColorPalette(quality: .low) }
    private func syncSwatches(_ image: CGImage) -> ImageColorSwatches? { image.toColorSwatches(quality: .low) }
    private func syncPalette(_ url: URL) -> ImageColorPalette? { ImageColorPalette(contentsOf: url, quality: .low) }
    private func syncSwatches(_ url: URL) -> ImageColorSwatches? { ImageColorSwatches(contentsOf: url, quality: .low) }
    #if os(iOS) || os(tvOS) || os(visionOS)
    private func syncPalette(_ image: UIImage) -> ImageColorPalette? { image.toColorPalette(quality: .low) }
    #elseif os(macOS)
    private func syncPalette(_ image: NSImage) -> ImageColorPalette? { image.toColorPalette(quality: .low) }
    private func syncSwatches(_ image: NSImage) -> ImageColorSwatches? { image.toColorSwatches(quality: .low) }
    #endif

    // MARK: - Files

    func testDecodesAtTheScaledSize() throws {
        // The images are 500 pixels on their longest side
        let url = try url("mona-lisa")
        let low = try XCTUnwrap(url.toCGImage(quality: .low))
        XCTAssertEqual(max(low.image.width, low.image.height), 50)
        XCTAssertEqual(low.quality, .lossless, "Already scaled")
        let medium = try XCTUnwrap(url.toCGImage(quality: .medium))
        XCTAssertEqual(max(medium.image.width, medium.image.height), 100)
        XCTAssertEqual(medium.quality, .lossless, "Already scaled")
        let high = try XCTUnwrap(url.toCGImage(quality: .high))
        XCTAssertEqual(max(high.image.width, high.image.height), 250)
        XCTAssertEqual(high.quality, .lossless, "Already scaled")
        let half = try XCTUnwrap(url.toCGImage(quality: 0.5))
        // ImageIO may round half a pixel down
        XCTAssertEqual(Double(max(half.image.width, half.image.height)), 372.5, accuracy: 1)
        // The full size is decoded as it is, and keeps its quality
        let full = try XCTUnwrap(url.toCGImage(quality: .lossless))
        XCTAssertEqual(max(full.image.width, full.image.height), 745)
        XCTAssertEqual(full.quality, .lossless)
        let large = try XCTUnwrap(url.toCGImage(quality: 1000))
        XCTAssertEqual(max(large.image.width, large.image.height), 745)
    }

    func testPaletteFromURLMatchesImage() throws {
        for name in names {
            // At full size, the same pixels are read
            XCTAssertEqual(ImageColorPalette(contentsOf: try url(name)), ImageColorPalette(try cgImage(name)), name)
            XCTAssertEqual(ImageColorSwatches(contentsOf: try url(name)), ImageColorSwatches(try cgImage(name)), name)
            // Scaled, the decoder and Core Graphics resample slightly differently
            for quality in [ImageColorPalette.Quality.low, .medium, .high] {
                let fromURL = try XCTUnwrap(ImageColorPalette(contentsOf: try url(name), quality: quality), "\(name) \(quality)")
                let fromImage = try XCTUnwrap(ImageColorPalette(try cgImage(name), quality: quality), "\(name) \(quality)")
                XCTAssertLessThan(fromURL.background.distance(to: fromImage.background), 0.05, "\(name) \(quality)")
            }
        }
    }

    func testDecoderCandidatesFromURL() throws {
        let white = RGBAColor(red: 1, green: 1, blue: 1)
        let black = RGBAColor(red: 0, green: 0, blue: 0)
        for name in names {
            for quality in [ImageColorPalette.Quality.low, .medium, .lossless] {
                let url = try url(name)
                let candidates = try XCTUnwrap(ImageColorDecoder.candidates(contentsOf: url, quality: quality))
                let colors = Set(candidates.map(\.color))
                // Files are decoded the same way, so every color is one of the groups,
                // apart from the white or black text colors used when none qualify
                let palette = try XCTUnwrap(ImageColorPalette(contentsOf: url, quality: quality))
                for color in [palette.background, palette.primary, palette.secondary, palette.detail] where color != white && color != black {
                    XCTAssertTrue(colors.contains(color), "\(name) \(quality)")
                }
                let swatches = try XCTUnwrap(ImageColorSwatches(contentsOf: url, quality: quality))
                XCTAssertEqual(swatches.dominant, candidates.first?.color, "\(name) \(quality)")
                for color in [swatches.vibrant, swatches.muted, swatches.darkMuted].compactMap({ $0 }) {
                    XCTAssertTrue(colors.contains(color), "\(name) \(quality)")
                }
            }
        }
        XCTAssertNil(ImageColorDecoder.candidates(contentsOf: URL(fileURLWithPath: "/nonexistent.jpg")))
    }

    func testInvalidURL() throws {
        let missing = URL(fileURLWithPath: "/nonexistent/image.jpg")
        XCTAssertNil(ImageColorPalette(contentsOf: missing))
        XCTAssertNil(ImageColorSwatches(contentsOf: missing))
        let notAnImage = FileManager.default.temporaryDirectory.appendingPathComponent("paint-not-an-image.jpg")
        try Data("not an image".utf8).write(to: notAnImage)
        defer { try? FileManager.default.removeItem(at: notAnImage) }
        XCTAssertNil(ImageColorPalette(contentsOf: notAnImage))
    }

    // MARK: - Async

    @MainActor
    func testAsyncRunsOffTheMainThread() async {
        let isMainThread = await ImageColorDecoder.concurrent { Thread.isMainThread }
        XCTAssertEqual(isMainThread, false)
    }

    @MainActor
    func testAsyncMatchesSync() async throws {
        let image = try cgImage("great-wave")
        let palette = await image.toColorPalette(quality: .low)
        XCTAssertEqual(palette, syncPalette(image))
        let swatches = await image.toColorSwatches(quality: .low)
        XCTAssertEqual(swatches, syncSwatches(image))

        let url = try url("great-wave")
        let fromURL = await ImageColorPalette(contentsOf: url, quality: .low)
        XCTAssertEqual(fromURL, syncPalette(url))
        let swatchesFromURL = await ImageColorSwatches(contentsOf: url, quality: .low)
        XCTAssertEqual(swatchesFromURL, syncSwatches(url))
        let missing = await ImageColorPalette(contentsOf: URL(fileURLWithPath: "/nonexistent.jpg"))
        XCTAssertNil(missing)
    }

    #if os(iOS) || os(tvOS) || os(visionOS)
    @MainActor
    func testUIImageAsync() async throws {
        let image = UIImage(cgImage: try cgImage("sunflowers"))
        let palette = await image.toColorPalette(quality: .low)
        XCTAssertEqual(palette, syncPalette(image))
    }
    #elseif os(macOS)
    @MainActor
    func testNSImageAsync() async throws {
        let cgImage = try cgImage("sunflowers")
        let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        let palette = await image.toColorPalette(quality: .low)
        XCTAssertEqual(palette, syncPalette(image))
        let swatches = await image.toColorSwatches(quality: .low)
        XCTAssertEqual(swatches, syncSwatches(image))
    }
    #endif

    // MARK: - Combine

    #if canImport(Combine)
    func testPublishers() throws {
        let image = try cgImage("starry-night")
        let url = try url("starry-night")
        var cancellables: Set<AnyCancellable> = []
        var expectations: [XCTestExpectation] = []

        func expect<T: Equatable>(_ publisher: AnyPublisher<T?, Never>, _ expected: T?, _ name: String) {
            let received = XCTestExpectation(description: name)
            let finished = XCTestExpectation(description: "\(name) finished")
            expectations += [received, finished]
            publisher
                .sink { _ in
                    finished.fulfill()
                } receiveValue: { value in
                    XCTAssertFalse(Thread.isMainThread, name)
                    XCTAssertEqual(value, expected, name)
                    received.fulfill()
                }
                .store(in: &cancellables)
        }
        expect(image.toColorPalettePublisher(quality: .low), ImageColorPalette(image, quality: .low), "palette")
        expect(image.toColorSwatchesPublisher(quality: .low), ImageColorSwatches(image, quality: .low), "swatches")
        expect(ImageColorPalette.publisher(contentsOf: url, quality: .low), ImageColorPalette(contentsOf: url, quality: .low), "palette URL")
        expect(ImageColorSwatches.publisher(contentsOf: url, quality: .low), ImageColorSwatches(contentsOf: url, quality: .low), "swatches URL")
        XCTAssertEqual(XCTWaiter().wait(for: expectations, timeout: 10), .completed)
    }
    #endif
}
