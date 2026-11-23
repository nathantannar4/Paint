//
// Copyright (c) Nathan Tannar
//

import XCTest
import SwiftUI
#if canImport(CoreImage)
import CoreImage
#endif
@testable import Paint

/// Tests ``ImageColorPalette`` with generated images. See `StockImagePaletteTests` for real images.
final class ImageColorPaletteTests: XCTestCase {

    private let navy: HEXColor = "#1A237E"
    private let yellow: HEXColor = "#FFEB3B"
    private let cyan: HEXColor = "#00FFFF"
    private let pink: HEXColor = "#FF80C0"
    private let white = RGBAColor(red: 1, green: 1, blue: 1)
    private let black = RGBAColor(red: 0, green: 0, blue: 0)

    /// An image of horizontal stripes, each a color and a number of rows.
    private func makeImage(
        width: Int = 100,
        stripes: [(HEXColor?, Int)]
    ) throws -> CGImage {
        let height = stripes.reduce(0) { $0 + $1.1 }
        let context = try XCTUnwrap(CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB)),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        var y = 0
        for (color, rows) in stripes {
            // `nil` stripes are left transparent
            if let color {
                context.setFillColor(color.toCGColor())
                context.fill(CGRect(x: 0, y: y, width: width, height: rows))
            }
            y += rows
        }
        return try XCTUnwrap(context.makeImage())
    }

    func testImageColorPalette() throws {
        let image = try makeImage(stripes: [(navy, 50), (yellow, 25), (cyan, 15), (pink, 10)])
        let colors = try XCTUnwrap(image.toColorPalette(quality: .lossless))
        // Grouped colors are averaged, so solid colors are found exactly
        XCTAssertEqual(colors.background.toHEXColor(), navy)
        XCTAssertEqual(colors.primary.toHEXColor(), yellow)
        XCTAssertEqual(colors.secondary.toHEXColor(), cyan)
        XCTAssertEqual(colors.detail.toHEXColor(), pink)
        for color in [colors.primary, colors.secondary, colors.detail] {
            XCTAssertFalse(color.contrast(.apca).isDark)
            XCTAssertTrue(color.contrast(.apca).against(colors.background).meets(30))
        }
    }

    func testImageColorPaletteFallBackToBlackOrWhite() throws {
        // Dark backgrounds fall back to white
        let dark = try XCTUnwrap(try makeImage(stripes: [(navy, 100)]).toColorPalette())
        XCTAssertEqual(dark.background.toHEXColor(), navy)
        XCTAssertEqual(dark.primary, white)
        XCTAssertEqual(dark.secondary, white)
        XCTAssertEqual(dark.detail, white)

        // Light backgrounds fall back to black
        let light = try XCTUnwrap(try makeImage(stripes: [(yellow, 100)]).toColorPalette())
        XCTAssertEqual(light.background.toHEXColor(), yellow)
        XCTAssertEqual(light.primary, black)

        // Found colors come first
        let partial = try XCTUnwrap(try makeImage(stripes: [(navy, 80), (yellow, 20)]).toColorPalette())
        XCTAssertEqual(partial.primary.toHEXColor(), yellow)
        XCTAssertEqual(partial.secondary, white)
        XCTAssertEqual(partial.detail, white)
    }

    func testImageColorPaletteGraysAreNotDistinct() throws {
        // Light grays all read on navy, but only the most common is used
        let image = try makeImage(stripes: [(navy, 40), ("#FFFFFF", 30), ("#DDDDDD", 20), ("#BBBBBB", 10)])
        let colors = try XCTUnwrap(image.toColorPalette(quality: .lossless))
        XCTAssertEqual(colors.primary.toHEXColor(), "#FFFFFF")
        XCTAssertEqual(colors.secondary, white)
        XCTAssertEqual(colors.detail, white)
    }

    func testImageColorPalettePrefersBackgroundWithHue() throws {
        // A common enough color is preferred over a white background
        let common = try makeImage(stripes: [("#FFFFFF", 60), (navy, 40)])
        XCTAssertEqual(try XCTUnwrap(common.toColorPalette()).background.toHEXColor(), navy)

        // But not a rare one
        let rare = try makeImage(stripes: [("#FFFFFF", 90), (navy, 10)])
        let colors = try XCTUnwrap(rare.toColorPalette())
        XCTAssertEqual(colors.background.toHEXColor(), "#FFFFFF")
        XCTAssertEqual(colors.primary.toHEXColor(), navy)
    }

    func testImageColorPaletteIgnoresTransparentPixels() throws {
        let image = try makeImage(stripes: [(nil, 70), (yellow, 20), (navy, 10)])
        let colors = try XCTUnwrap(image.toColorPalette())
        XCTAssertEqual(colors.background.toHEXColor(), yellow)
        XCTAssertEqual(colors.primary.toHEXColor(), navy)

        // Translucent pixels are unpremultiplied
        let translucent = try makeImage(stripes: [(HEXColor(red: 1, green: 0.5, blue: 0, alpha: 0.6), 100)])
        XCTAssertEqual(try XCTUnwrap(translucent.toColorPalette()).background.toHEXColor(), "#FF8000")

        XCTAssertNil(try makeImage(stripes: [(nil, 100)]).toColorPalette())
        XCTAssertNil(try makeImage(stripes: [(HEXColor(red: 1, green: 0, blue: 0, alpha: 0.4), 100)]).toColorPalette())
    }

    func testImageColorPaletteQualityScaledSize() {
        typealias Quality = ImageColorPalette.Quality
        func size(_ quality: Quality, _ width: Int, _ height: Int) -> [Int] {
            let size = quality.scaledSize(width: width, height: height)
            return [size.width, size.height]
        }

        // Presets
        XCTAssertEqual(Quality.low, .dimension(50))
        XCTAssertEqual(Quality.medium, .dimension(100))
        XCTAssertEqual(Quality.high, .dimension(250))
        XCTAssertEqual(Quality.lossless, .scale(1))

        // Literals
        XCTAssertEqual(0.25 as Quality, .scale(0.25))
        XCTAssertEqual(1.0 as Quality, .scale(1))
        XCTAssertEqual(200 as Quality, .dimension(200))
        XCTAssertEqual(size(1.0, 1000, 400), [1000, 400])
        XCTAssertEqual(size(1, 1000, 400), [1, 1])

        // A fraction of the original size
        XCTAssertEqual(size(.scale(0.25), 1000, 400), [250, 100])
        XCTAssertEqual(size(.scale(0.5), 3, 3), [2, 2])
        XCTAssertEqual(size(.scale(1), 1000, 400), [1000, 400])
        XCTAssertEqual(size(.scale(2), 1000, 400), [1000, 400])
        XCTAssertEqual(size(.scale(.nan), 1000, 400), [1000, 400])
        XCTAssertEqual(size(.scale(0), 1000, 400), [1, 1])
        XCTAssertEqual(size(.scale(-1), 1000, 400), [1, 1])

        // A maximum dimension, keeping the aspect ratio
        XCTAssertEqual(size(.dimension(250), 1000, 400), [250, 100])
        XCTAssertEqual(size(.dimension(250), 400, 1000), [100, 250])
        XCTAssertEqual(size(.dimension(250), 200, 100), [200, 100])
        XCTAssertEqual(size(.dimension(10), 1000, 1), [10, 1])
        XCTAssertEqual(size(.dimension(0), 1000, 400), [1, 1])
    }

    func testImageColorPaletteQuality() throws {
        // Large stripes are found at every quality
        let image = try makeImage(width: 1000, stripes: [(navy, 500), (yellow, 300), (cyan, 200)])
        let expected = try XCTUnwrap(image.toColorPalette(quality: .lossless))
        let qualities: [ImageColorPalette.Quality] = [.low, .medium, .high, .lossless, .scale(0.1), .scale(0.5), 0.25, 400]
        for quality in qualities {
            let colors = try XCTUnwrap(image.toColorPalette(quality: quality))
            XCTAssertEqual(colors.background.toHEXColor(), expected.background.toHEXColor(), "\(quality)")
            XCTAssertEqual(colors.primary.toHEXColor(), expected.primary.toHEXColor(), "\(quality)")
            XCTAssertEqual(colors.secondary.toHEXColor(), expected.secondary.toHEXColor(), "\(quality)")
        }
    }

    func testImageColorPaletteDeterministic() throws {
        // Equally common colors are ordered consistently
        let image = try makeImage(stripes: [(navy, 40), (yellow, 20), (cyan, 20), (pink, 20)])
        let colors = try XCTUnwrap(image.toColorPalette())
        for _ in 0..<10 {
            XCTAssertEqual(image.toColorPalette(), colors)
        }
    }

    #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
    func testImageColorPalettePlatformImage() throws {
        let cgImage = try makeImage(stripes: [(navy, 50), (yellow, 25), (cyan, 15), (pink, 10)])
        #if os(macOS)
        let image = NSImage(cgImage: cgImage, size: CGSize(width: cgImage.width, height: cgImage.height))
        #else
        let image = UIImage(cgImage: cgImage)
        #endif
        XCTAssertEqual(image.toColorPalette(), cgImage.toColorPalette())
        XCTAssertEqual(image.toColorPalette()?.background.toHEXColor(), navy)
    }
    #endif

    func testImageColorPaletteCodable() throws {
        let colors = ImageColorPalette(background: navy.toRGBAColor(), primary: yellow.toRGBAColor(), secondary: cyan.toRGBAColor(), detail: pink.toRGBAColor())
        let data = try JSONEncoder().encode(colors)
        XCTAssertEqual(try JSONDecoder().decode(ImageColorPalette.self, from: data), colors)
    }

    /// Draws horizontal stripes of components in `colorSpace`, with 8 bits per channel.
    private func makeImage(
        colorSpace name: CFString,
        stripes: [([CGFloat], Int)]
    ) throws -> CGImage {
        let colorSpace = try XCTUnwrap(CGColorSpace(name: name))
        let isGray = colorSpace.model == .monochrome
        let context = try XCTUnwrap(CGContext(
            data: nil,
            width: 100,
            height: stripes.reduce(0) { $0 + $1.1 },
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: isGray ? CGImageAlphaInfo.none.rawValue : CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        var y = 0
        for (components, rows) in stripes {
            context.setFillColor(try XCTUnwrap(CGColor(colorSpace: colorSpace, components: components)))
            context.fill(CGRect(x: 0, y: y, width: 100, height: rows))
            y += rows
        }
        return try XCTUnwrap(context.makeImage())
    }

    func testImageColorPaletteKeepsDisplayP3Colors() throws {
        let image = try makeImage(colorSpace: CGColorSpace.displayP3, stripes: [
            ([1, 0, 0, 1], 70), // Display P3 red, outside sRGB
            ([1, 1, 1, 1], 30),
        ])
        let palette = try XCTUnwrap(image.toColorPalette())
        // Display P3 red in extended sRGB
        let expected = try XCTUnwrap(CGColor(
            colorSpace: try XCTUnwrap(CGColorSpace(name: CGColorSpace.displayP3)),
            components: [1, 0, 0, 1]
        )?.toRGBAColor())
        assertEqual(palette.background, expected, accuracy: 1e-3)
        XCTAssertGreaterThan(palette.background.red, 1)
        XCTAssertLessThan(palette.background.green, 0)
        // White is the same in both color spaces
        assertEqual(palette.primary, white, accuracy: 1e-3)
    }

    func testImageColorPaletteConvertsGrayscaleToSRGB() throws {
        let image = try makeImage(colorSpace: CGColorSpace.genericGrayGamma2_2, stripes: [
            ([0.1, 1], 70),
            ([1, 1], 30),
        ])
        let palette = try XCTUnwrap(image.toColorPalette())
        XCTAssertEqual(palette.background.red, palette.background.green, accuracy: 1e-2)
        XCTAssertEqual(palette.background.green, palette.background.blue, accuracy: 1e-2)
        XCTAssertTrue(palette.background.contrast(.apca).isDark)
        assertEqual(palette.primary, white, accuracy: 1e-2)
    }

    func testDecoderCandidates() throws {
        // Stripes of 50, 30 and 20 rows of 100 pixels, and 10 transparent rows
        let image = try makeImage(stripes: [(navy, 50), (yellow, 30), (cyan, 20), (nil, 10)])
        let candidates = try XCTUnwrap(ImageColorDecoder.candidates(in: image))
        // Most common first, with transparent pixels ignored
        XCTAssertEqual(candidates.map(\.count), [5000, 3000, 2000])
        XCTAssertEqual(candidates.map { $0.color.toHEXColor() }, [navy, yellow, cyan])
        // Keys are distinct groups
        XCTAssertEqual(Set(candidates.map(\.key)).count, candidates.count)
        // Scaled, the proportions are kept
        let scaled = try XCTUnwrap(ImageColorDecoder.candidates(in: image, quality: .dimension(11)))
        XCTAssertEqual(scaled.first?.color.toHEXColor(), navy)
        // Entirely transparent images have no candidates
        XCTAssertNil(ImageColorDecoder.candidates(in: try makeImage(stripes: [(nil, 10)])))
    }

    func testImageColorPaletteQualityCodable() throws {
        typealias Quality = ImageColorPalette.Quality
        XCTAssertEqual(try assertRoundTrips(Quality.scale(0.25)), #"{"scale":0.25}"#)
        XCTAssertEqual(try assertRoundTrips(Quality.dimension(200)), #"{"dimension":200}"#)
        XCTAssertEqual(try assertRoundTrips(Quality.low), #"{"dimension":50}"#)
        XCTAssertEqual(try assertRoundTrips(Quality.medium), #"{"dimension":100}"#)
        XCTAssertEqual(try assertRoundTrips(Quality.high), #"{"dimension":250}"#)
        XCTAssertEqual(try assertRoundTrips(Quality.lossless), #"{"scale":1}"#)

        // `1` and `1.0` are different qualities, so each is encoded with its kind
        XCTAssertEqual(try decode(Quality.self, #"{"scale":1}"#), .scale(1))
        XCTAssertEqual(try decode(Quality.self, #"{"dimension":1}"#), .dimension(1))

        // Exactly one kind is required, with a value of the right type
        XCTAssertThrowsError(try decode(Quality.self, "{}"))
        XCTAssertThrowsError(try decode(Quality.self, #"{"scale":1,"dimension":1}"#))
        XCTAssertThrowsError(try decode(Quality.self, #"{"dimension":1.5}"#))
        XCTAssertThrowsError(try decode(Quality.self, #"{"scale":"full"}"#))
        XCTAssertThrowsError(try decode(Quality.self, "0.25"))
    }

    func testImageColorPaletteCodableFormat() throws {
        let palette = ImageColorPalette(
            background: navy.toRGBAColor(),
            primary: yellow.toRGBAColor(),
            secondary: cyan.toRGBAColor(),
            detail: pink.toRGBAColor()
        )
        let json = try assertRoundTrips(palette)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: [String: Double]])
        XCTAssertEqual(Set(object.keys), ["background", "primary", "secondary", "detail"])
        XCTAssertEqual(object["primary"], ["red": 1, "green": Double(0xEB) / 255, "blue": Double(0x3B) / 255, "alpha": 1])

        // Wide gamut colors, outside `0...1`, are preserved
        let p3 = try makeImage(colorSpace: CGColorSpace.displayP3, stripes: [([0, 1, 0, 1], 70), ([0, 0, 0, 1], 30)])
        let wide = try XCTUnwrap(p3.toColorPalette())
        XCTAssertLessThan(wide.background.red, 0)
        try assertRoundTrips(wide)

        XCTAssertThrowsError(try decode(ImageColorPalette.self, #"{"background":{"red":0,"green":0,"blue":0,"alpha":1}}"#))
    }
}
