//
// Copyright (c) Nathan Tannar
//

import XCTest
import CoreGraphics
@testable import Paint

/// Tests dithered gradients and grain.
final class ColorDitheringTests: XCTestCase {

    // MARK: - Dithering

    func testDitheredGradient() throws {
        // A subtle dark gradient, which bands without dithering
        let gradient = ColorGradient(colors: [HEXColor("#202020"), HEXColor("#282828")])
        let width = 64
        let height = 256
        let dithered = try XCTUnwrap(gradient.toCGImage(width: width, height: height, colorSpace: .sRGB))
        let banded = try XCTUnwrap(gradient.toCGImage(width: width, height: height, colorSpace: .sRGB, dithered: false))
        XCTAssertEqual(dithered.width, width)
        XCTAssertEqual(dithered.height, height)

        func pixels(_ image: CGImage) -> [UInt8] {
            let data = image.dataProvider!.data! as Data
            return [UInt8](data)
        }
        func rowAverage(_ bytes: [UInt8], _ row: Int) -> Double {
            (0..<width).reduce(0) { $0 + Double(bytes[(row * width + $1) * 4]) } / Double(width)
        }
        let ditheredPixels = pixels(dithered)
        let bandedPixels = pixels(banded)

        // Without dithering, every row is a single value
        for row in 0..<height {
            let first = bandedPixels[row * width * 4]
            XCTAssertTrue((0..<width).allSatisfy { bandedPixels[(row * width + $0) * 4] == first })
        }
        // With dithering, row averages follow the gradient more closely than the bands
        var ditheredError = 0.0
        var bandedError = 0.0
        for row in 0..<height {
            let expected = gradient.color(at: (Double(row) + 0.5) / Double(height)).red * 255
            ditheredError += abs(rowAverage(ditheredPixels, row) - expected)
            bandedError += abs(rowAverage(bandedPixels, row) - expected)
        }
        XCTAssertLessThan(ditheredError, bandedError * 0.6)
        // The noise is less than one step either way
        for index in stride(from: 0, to: ditheredPixels.count, by: 4) {
            XCTAssertLessThanOrEqual(abs(Int(ditheredPixels[index]) - Int(bandedPixels[index])), 1)
            XCTAssertEqual(ditheredPixels[index + 3], 255)
        }
        // Deterministic
        XCTAssertEqual(pixels(try XCTUnwrap(gradient.toCGImage(width: width, height: height, colorSpace: .sRGB))), ditheredPixels)

        // Horizontal gradients
        let horizontal = try XCTUnwrap(ColorGradient(colors: [HEXColor("#000000"), HEXColor("#FFFFFF")]).toCGImage(width: 256, height: 1, startPoint: CGPoint(x: 0, y: 0.5), endPoint: CGPoint(x: 1, y: 0.5), dithered: false))
        let horizontalPixels = pixels(horizontal)
        XCTAssertLessThan(horizontalPixels[0], 5)
        XCTAssertGreaterThan(horizontalPixels[255 * 4], 250)

        // Translucent pixels are premultiplied
        let fade = try XCTUnwrap(ColorGradient(colors: [RGBAColor(red: 1, green: 0, blue: 0, alpha: 1), RGBAColor(red: 1, green: 0, blue: 0, alpha: 0)]).toCGImage(width: 4, height: 64))
        let fadePixels = pixels(fade)
        for index in stride(from: 0, to: fadePixels.count, by: 4) {
            XCTAssertLessThanOrEqual(fadePixels[index], fadePixels[index + 3])
        }
        XCTAssertEqual(fade.colorSpace?.name, CGColorSpace.displayP3)

        XCTAssertNil(gradient.toCGImage(width: 0, height: 10))
    }

    func testGrainTexture() throws {
        let grain = GrainTexture(width: 32, height: 16, intensity: 0.5, seed: 3)
        let image = try XCTUnwrap(grain.toCGImage())
        XCTAssertEqual(image.width, 32)
        XCTAssertEqual(image.height, 16)
        let bytes = [UInt8](image.dataProvider!.data! as Data)
        var sum = 0.0
        var values: Set<UInt8> = []
        for index in stride(from: 0, to: bytes.count, by: 4) {
            // Monochrome
            XCTAssertEqual(bytes[index], bytes[index + 1])
            XCTAssertEqual(bytes[index], bytes[index + 2])
            // Within the intensity of middle gray
            XCTAssertLessThanOrEqual(abs(Double(bytes[index]) - 127.5), 64)
            sum += Double(bytes[index])
            values.insert(bytes[index])
        }
        // Centered on middle gray, with real noise
        XCTAssertEqual(sum / Double(32 * 16), 127.5, accuracy: 4)
        XCTAssertGreaterThan(values.count, 20)

        // Deterministic per seed
        XCTAssertEqual([UInt8](grain.toCGImage()!.dataProvider!.data! as Data), bytes)
        var other = grain
        other.seed = 4
        XCTAssertNotEqual([UInt8](other.toCGImage()!.dataProvider!.data! as Data), bytes)

        // Color grain differs between components
        let color = [UInt8](GrainTexture(width: 8, height: 8, isMonochrome: false).toCGImage()!.dataProvider!.data! as Data)
        XCTAssertTrue(stride(from: 0, to: color.count, by: 4).contains { color[$0] != color[$0 + 1] })

        // No intensity is flat
        let flat = [UInt8](GrainTexture(width: 8, height: 8, intensity: 0).toCGImage()!.dataProvider!.data! as Data)
        XCTAssertTrue(stride(from: 0, to: flat.count, by: 4).allSatisfy { flat[$0] == 128 })

        XCTAssertNil(GrainTexture(width: 0).toCGImage())
        XCTAssertNotNil(grain.toImage(scale: 2))
        try assertRoundTrips(grain)
    }
}
