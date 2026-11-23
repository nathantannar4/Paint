//
// Copyright (c) Nathan Tannar
//

import XCTest
import ImageIO
@testable import Paint

/// Tests ``ImageColorSwatches`` with generated and stock images.
final class ImageColorSwatchesTests: XCTestCase {

    /// An sRGB image of horizontal bands, each a fraction of the height.
    private func image(bands: [(RGBAColor, Int)]) throws -> CGImage {
        let width = 10
        let height = bands.reduce(0) { $0 + $1.1 }
        let colorSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try XCTUnwrap(CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        var y = 0
        for (color, rows) in bands {
            context.setFillColor(color.toCGColor())
            context.fill(CGRect(x: 0, y: y, width: width, height: rows))
            y += rows
        }
        return try XCTUnwrap(context.makeImage())
    }

    func testSwatches() throws {
        let vibrant = HEXColor("#E8452C").toRGBAColor()       // Saturated orange-red
        let darkVibrant = HEXColor("#1E3A8A").toRGBAColor()   // Deep blue
        let lightMuted = HEXColor("#E6DDD0").toRGBAColor()    // Beige
        let gray = HEXColor("#808080").toRGBAColor()
        let swatches = try XCTUnwrap(try image(bands: [
            (lightMuted, 40),
            (vibrant, 30),
            (darkVibrant, 20),
            (gray, 10),
        ]).toColorSwatches())

        func assertClose(_ swatch: RGBAColor?, _ expected: RGBAColor, _ name: String) {
            guard let swatch else { return XCTFail("\(name) is nil") }
            XCTAssertLessThan(swatch.distance(to: expected), 0.03, name)
        }
        assertClose(swatches.dominant, lightMuted, "dominant")
        assertClose(swatches.vibrant, vibrant, "vibrant")
        assertClose(swatches.darkVibrant, darkVibrant, "darkVibrant")
        assertClose(swatches.lightMuted, lightMuted, "lightMuted")
        // Gray has no hue, so it isn't muted, and nothing is light and vibrant
        XCTAssertNil(swatches.muted)
        XCTAssertNil(swatches.lightVibrant)
    }

    func testGrayscaleImage() throws {
        let swatches = try XCTUnwrap(try image(bands: [
            (RGBAColor(red: 0.2, green: 0.2, blue: 0.2), 5),
            (RGBAColor(red: 0.8, green: 0.8, blue: 0.8), 5),
        ]).toColorSwatches())
        XCTAssertNil(swatches.vibrant)
        XCTAssertNil(swatches.lightVibrant)
        XCTAssertNil(swatches.darkVibrant)
        XCTAssertNil(swatches.muted)
        XCTAssertNil(swatches.lightMuted)
        XCTAssertNil(swatches.darkMuted)
    }

    func testStockImages() throws {
        for name in ["great-wave", "starry-night", "sunflowers", "mona-lisa", "blue-marble"] {
            let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "jpg", subdirectory: "Images"))
            let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
            let cgImage = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
            let swatches = try XCTUnwrap(cgImage.toColorSwatches(quality: .low), name)
            let all = [swatches.vibrant, swatches.lightVibrant, swatches.darkVibrant, swatches.muted, swatches.lightMuted, swatches.darkMuted]
            // Paintings and photos have at least a few swatches, and none repeat
            XCTAssertGreaterThanOrEqual(all.compactMap { $0 }.count, 3, name)
            XCTAssertEqual(Set(all.compactMap { $0 }).count, all.compactMap { $0 }.count, name)
            for vibrant in [swatches.vibrant, swatches.lightVibrant, swatches.darkVibrant].compactMap({ $0 }) {
                XCTAssertGreaterThanOrEqual(vibrant.toOKLCHColor().chroma, 0.08, name)
            }
            for muted in [swatches.muted, swatches.lightMuted, swatches.darkMuted].compactMap({ $0 }) {
                XCTAssertLessThanOrEqual(muted.toOKLCHColor().chroma, 0.08, name)
            }
        }
    }

    func testCodable() throws {
        try assertRoundTrips(ImageColorSwatches(
            dominant: RGBAColor(red: 1, green: 0, blue: 0),
            vibrant: RGBAColor(red: 0, green: 1, blue: 0),
            lightVibrant: nil,
            darkVibrant: nil,
            muted: nil,
            lightMuted: RGBAColor(red: 0.9, green: 0.9, blue: 0.8),
            darkMuted: nil
        ))
    }
}
