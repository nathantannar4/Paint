//
// Copyright (c) Nathan Tannar
//

import XCTest
import ImageIO
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
@testable import Paint

/// Tests ``ImageColorPalette`` with public domain paintings and photos, see
/// `Resources/README.md`.
///
/// Exact colors depend on how the platform decodes and scales each image, so these
/// tests check what the palette should look like, such as its hue and lightness,
/// rather than exact values.
final class StockImagePaletteTests: XCTestCase {

    private enum StockImage: String, CaseIterable {
        case greatWave = "great-wave"
        case starryNight = "starry-night"
        case sunflowers = "sunflowers"
        case monaLisa = "mona-lisa"
        case blueMarble = "blue-marble"
    }

    private static let qualities: [ImageColorPalette.Quality] = [.lossless, .high, .medium, .low, .scale(0.25)]

    private let white = RGBAColor(red: 1, green: 1, blue: 1)
    private let black = RGBAColor(red: 0, green: 0, blue: 0)

    // MARK: - Helpers

    private func url(_ image: StockImage) throws -> URL {
        try XCTUnwrap(
            Bundle.module.url(forResource: image.rawValue, withExtension: "jpg", subdirectory: "Images"),
            "Missing \(image.rawValue).jpg, see Resources/README.md"
        )
    }

    private func cgImage(_ image: StockImage) throws -> CGImage {
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(try url(image) as CFURL, nil))
        return try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
    }

    private func palette(
        _ image: StockImage,
        quality: ImageColorPalette.Quality = .lossless
    ) throws -> ImageColorPalette {
        try XCTUnwrap(try cgImage(image).toColorPalette(quality: quality), "\(image) at \(quality)")
    }

    /// The Oklab distance between two colors.
    private func distance(_ lhs: RGBAColor, _ rhs: RGBAColor) -> Double {
        let lhs = lhs.toOKLCHColor()
        let rhs = rhs.toOKLCHColor()
        let lightness = lhs.lightness - rhs.lightness
        let a = lhs.a - rhs.a
        let b = lhs.b - rhs.b
        return (lightness * lightness + a * a + b * b).squareRoot()
    }

    /// Whether a hue, in degrees, is within `range`.
    private func hue(_ color: RGBAColor, in range: ClosedRange<Double>) -> Bool {
        range.contains(color.toOKLCHColor().hue.degrees)
    }

    private func textColors(_ palette: ImageColorPalette) -> [RGBAColor] {
        [palette.primary, palette.secondary, palette.detail]
    }

    /// The text colors found in the image, without the black or white fallbacks.
    private func foundTextColors(_ palette: ImageColorPalette) -> [RGBAColor] {
        textColors(palette).filter { $0 != white && $0 != black }
    }

    // MARK: - Every Image

    func testStockImagesLoad() throws {
        for image in StockImage.allCases {
            let cgImage = try cgImage(image)
            XCTAssertEqual(cgImage.width, 500, "\(image)")
            XCTAssertGreaterThan(cgImage.height, 300, "\(image)")
        }
    }

    func testTextColorsReadOnBackground() throws {
        for image in StockImage.allCases {
            for quality in Self.qualities {
                let palette = try palette(image, quality: quality)
                for color in textColors(palette) {
                    XCTAssertTrue(
                        color.contrast(.apca).against(palette.background).meets(30),
                        "\(image) at \(quality): \(HEXColor(color)) on \(HEXColor(palette.background))"
                    )
                    // Text is on the other side of light and dark from the background
                    XCTAssertNotEqual(color.contrast(.apca).isDark, palette.background.contrast(.apca).isDark, "\(image) at \(quality)")
                }
            }
        }
    }

    func testFoundTextColorsAreDistinct() throws {
        for image in StockImage.allCases {
            for quality in Self.qualities {
                let found = foundTextColors(try palette(image, quality: quality))
                XCTAssertFalse(found.isEmpty, "\(image) at \(quality)")
                for (index, lhs) in found.enumerated() {
                    for rhs in found[(index + 1)...] {
                        // Two grays are never both used
                        let isGray = lhs.toOKLCHColor().chroma < 0.03 && rhs.toOKLCHColor().chroma < 0.03
                        XCTAssertFalse(isGray, "\(image) at \(quality)")
                        XCTAssertGreaterThan(distance(lhs, rhs), 0.1, "\(image) at \(quality)")
                    }
                }
            }
        }
    }

    func testPaletteIsDeterministic() throws {
        for image in StockImage.allCases {
            let cgImage = try cgImage(image)
            let palette = try XCTUnwrap(cgImage.toColorPalette())
            for _ in 0..<3 {
                XCTAssertEqual(cgImage.toColorPalette(), palette, "\(image)")
            }
        }
    }

    func testPaletteCodable() throws {
        for image in StockImage.allCases {
            let palette = try palette(image)
            let data = try JSONEncoder().encode(palette)
            XCTAssertEqual(try JSONDecoder().decode(ImageColorPalette.self, from: data), palette, "\(image)")
        }
    }

    // MARK: - Resolution

    func testBackgroundIsStableAcrossQualities() throws {
        for image in StockImage.allCases {
            let full = try palette(image, quality: .lossless)
            for quality in Self.qualities.dropFirst() {
                let scaled = try palette(image, quality: quality)
                XCTAssertLessThan(
                    distance(scaled.background, full.background), 0.05,
                    "\(image) at \(quality): \(HEXColor(scaled.background)) vs \(HEXColor(full.background))"
                )
                XCTAssertEqual(scaled.background.contrast(.apca).isDark, full.background.contrast(.apca).isDark, "\(image) at \(quality)")
            }
        }
    }

    func testPrimaryIsSimilarAcrossQualities() throws {
        for image in StockImage.allCases {
            let full = try palette(image, quality: .lossless)
            // Scaling blends small details, so the primary color can move, but stays
            // close to one of the colors found at full size
            for quality in Self.qualities.dropFirst() {
                let scaled = try palette(image, quality: quality)
                let closest = textColors(full).map { distance($0, scaled.primary) }.min() ?? .infinity
                XCTAssertLessThan(closest, 0.15, "\(image) at \(quality): \(HEXColor(scaled.primary))")
            }
        }
    }

    func testQualityScalesImage() throws {
        let image = try cgImage(.monaLisa)
        XCTAssertEqual(image.width, 500)
        XCTAssertEqual(image.height, 745)
        func size(_ quality: ImageColorPalette.Quality) -> [Int] {
            let size = quality.scaledSize(width: image.width, height: image.height)
            return [size.width, size.height]
        }
        XCTAssertEqual(size(.lossless), [500, 745])
        XCTAssertEqual(size(.low), [34, 50])
        XCTAssertEqual(size(.medium), [67, 100])
        XCTAssertEqual(size(.high), [168, 250])
        XCTAssertEqual(size(.scale(0.25)), [125, 186])
        XCTAssertEqual(size(.dimension(50)), [34, 50])
        XCTAssertEqual(size(.dimension(1000)), [500, 745])
    }

    // MARK: - Platform Images

    func testPlatformImageMatchesCGImage() throws {
        for image in StockImage.allCases {
            let expected = try palette(image)
            #if os(macOS)
            let platformImage = try XCTUnwrap(NSImage(contentsOf: try url(image)))
            #else
            let platformImage = try XCTUnwrap(UIImage(contentsOfFile: try url(image).path))
            #endif
            let palette = try XCTUnwrap(platformImage.toColorPalette(), "\(image)")
            XCTAssertLessThan(distance(palette.background, expected.background), 0.02, "\(image)")
            XCTAssertLessThan(distance(palette.primary, expected.primary), 0.05, "\(image)")
        }
    }

    // MARK: - Each Image

    func testGreatWave() throws {
        for quality in Self.qualities {
            let palette = try palette(.greatWave, quality: quality)
            // Cream paper
            XCTAssertFalse(palette.background.contrast(.apca).isDark, "\(quality)")
            XCTAssertGreaterThan(palette.background.toOKLCHColor().lightness, 0.9, "\(quality)")
            XCTAssertTrue(hue(palette.background, in: 70...100), "\(quality)")
            // Prussian blue waves
            XCTAssertTrue(hue(palette.primary, in: 230...260), "\(quality): \(HEXColor(palette.primary))")
            XCTAssertGreaterThan(palette.primary.toOKLCHColor().chroma, 0.05, "\(quality)")
        }
    }

    func testStarryNight() throws {
        for quality in Self.qualities {
            let palette = try palette(.starryNight, quality: quality)
            // Dark cypress and night sky
            XCTAssertTrue(palette.background.contrast(.apca).isDark, "\(quality)")
            XCTAssertLessThan(palette.background.toOKLCHColor().lightness, 0.3, "\(quality)")
            // Yellow stars and moon
            XCTAssertTrue(
                foundTextColors(palette).contains { hue($0, in: 85...110) && $0.toOKLCHColor().chroma > 0.1 },
                "\(quality)"
            )
        }
    }

    func testSunflowers() throws {
        for quality in Self.qualities {
            let palette = try palette(.sunflowers, quality: quality)
            // Yellow background, colorful enough to be used over almost white
            XCTAssertFalse(palette.background.contrast(.apca).isDark, "\(quality)")
            XCTAssertTrue(hue(palette.background, in: 95...110), "\(quality)")
            XCTAssertGreaterThan(palette.background.toOKLCHColor().chroma, 0.1, "\(quality)")
            // Darker ochre petals, every text color is found in the painting
            XCTAssertEqual(foundTextColors(palette).count, 3, "\(quality)")
            XCTAssertTrue(hue(palette.primary, in: 90...110), "\(quality)")
            XCTAssertGreaterThan(palette.primary.toOKLCHColor().chroma, 0.1, "\(quality)")
        }
    }

    func testMonaLisa() throws {
        for quality in Self.qualities {
            let palette = try palette(.monaLisa, quality: quality)
            // Dark varnished shadows
            XCTAssertTrue(palette.background.contrast(.apca).isDark, "\(quality)")
            XCTAssertLessThan(palette.background.toOKLCHColor().lightness, 0.25, "\(quality)")
            // Golden skin and landscape
            XCTAssertTrue(
                foundTextColors(palette).contains { hue($0, in: 80...95) && $0.toOKLCHColor().chroma > 0.1 },
                "\(quality)"
            )
        }
    }

    func testBlueMarble() throws {
        for quality in Self.qualities {
            let palette = try palette(.blueMarble, quality: quality)
            // Black space, kept as the background since nothing with a hue is as common
            XCTAssertLessThan(palette.background.toOKLCHColor().lightness, 0.15, "\(quality)")
            XCTAssertLessThan(palette.background.toOKLCHColor().chroma, 0.02, "\(quality)")
            // White clouds and pale blue atmosphere
            for color in foundTextColors(palette) {
                XCTAssertGreaterThan(color.toOKLCHColor().lightness, 0.7, "\(quality)")
                XCTAssertLessThan(color.toOKLCHColor().chroma, 0.05, "\(quality)")
            }
        }
    }
}
