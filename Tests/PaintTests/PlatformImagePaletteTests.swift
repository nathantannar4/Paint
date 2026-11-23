//
// Copyright (c) Nathan Tannar
//

import XCTest
#if canImport(CoreImage)
import CoreImage
#endif
@testable import Paint

/// Tests finding the colors of `UIImage` and `NSImage`, including images without a
/// `CGImage`, which draw themselves straight into the bitmap.
final class PlatformImagePaletteTests: XCTestCase {

    private let navy = RGBAColor(red: 0.1, green: 0.14, blue: 0.5)
    private let yellow = RGBAColor(red: 1, green: 0.92, blue: 0.23)

    /// A 40 by 40 sRGB image, three quarters navy and a quarter yellow.
    private func stripesCGImage() throws -> CGImage {
        let context = try XCTUnwrap(CGContext(
            data: nil, width: 40, height: 40, bitsPerComponent: 8, bytesPerRow: 0,
            space: try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB)),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(navy.toCGColor())
        context.fill(CGRect(x: 0, y: 0, width: 40, height: 30))
        context.setFillColor(yellow.toCGColor())
        context.fill(CGRect(x: 0, y: 30, width: 40, height: 10))
        return try XCTUnwrap(context.makeImage())
    }

    private func assertStripes(_ palette: ImageColorPalette?, file: StaticString = #filePath, line: UInt = #line) throws {
        let palette = try XCTUnwrap(palette, file: file, line: line)
        XCTAssertLessThan(palette.background.distance(to: navy), 0.01, "background", file: file, line: line)
        XCTAssertLessThan(palette.primary.distance(to: yellow), 0.01, "primary", file: file, line: line)
    }

    #if os(macOS)
    /// A vector image, drawn by a handler, three quarters navy and a quarter yellow.
    private func stripesNSImage() -> NSImage {
        NSImage(size: NSSize(width: 40, height: 40), flipped: false) { [navy, yellow] _ in
            NSColor(navy).setFill()
            NSRect(x: 0, y: 0, width: 40, height: 30).fill()
            NSColor(yellow).setFill()
            NSRect(x: 0, y: 30, width: 40, height: 10).fill()
            return true
        }
    }

    func testNSImageBitmapUsesItsCGImage() throws {
        let cgImage = try stripesCGImage()
        let image = NSImage(cgImage: cgImage, size: .zero)
        XCTAssertNotNil(image.bitmapCGImage)
        // Read exactly like the `CGImage`
        XCTAssertEqual(image.toColorPalette(), ImageColorPalette(cgImage))
        XCTAssertEqual(image.toColorSwatches(), ImageColorSwatches(cgImage))
    }

    func testNSImageVectorDrawsItself() throws {
        let image = stripesNSImage()
        XCTAssertNil(image.bitmapCGImage, "Drawn images have no bitmap")
        try assertStripes(image.toColorPalette())
        try assertStripes(image.toColorPalette(quality: 10))
        XCTAssertNotNil(image.toColorSwatches())
        // Drawn at the scaled size
        let pixels = try XCTUnwrap(image.toColorPalettePixels(quality: 10))
        XCTAssertEqual(pixels.width, 10)
        XCTAssertEqual(pixels.colorSpace, .displayP3)
    }

    func testNSImageKeepsWideGamut() throws {
        let p3Green = RGBAColor(red: 0, green: 1, blue: 0, colorSpace: .displayP3)
        let image = NSImage(size: NSSize(width: 20, height: 20), flipped: false) { _ in
            NSColor(displayP3Red: 0, green: 1, blue: 0, alpha: 1).setFill()
            NSRect(x: 0, y: 0, width: 20, height: 20).fill()
            return true
        }
        let palette = try XCTUnwrap(image.toColorPalette())
        XCTAssertFalse(ColorGamut.sRGB.contains(palette.background))
        XCTAssertLessThan(palette.background.distance(to: p3Green), 0.01)
    }

    @available(macOS 12.0, *)
    func testNSImageSymbol() throws {
        let configuration = NSImage.SymbolConfiguration(paletteColors: [NSColor(yellow)])
        let symbol = try XCTUnwrap(NSImage(systemSymbolName: "square.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration))
        XCTAssertNil(symbol.bitmapCGImage)
        let palette = try XCTUnwrap(symbol.toColorPalette())
        XCTAssertLessThan(palette.background.distance(to: yellow), 0.02)
    }

    func testNSImageVectorAsync() throws {
        let image = stripesNSImage()
        try assertStripes(image.toColorPalette(quality: .lossless))
        let swatches = image.toColorSwatches(quality: .lossless)
        XCTAssertNotNil(swatches)
    }
    #endif

    #if os(iOS) || os(tvOS) || os(visionOS)
    func testUIImageBitmapUsesItsCGImage() throws {
        let cgImage = try stripesCGImage()
        let image = UIImage(cgImage: cgImage)
        XCTAssertEqual(image.toColorPalette(), ImageColorPalette(cgImage))
        XCTAssertEqual(image.toColorSwatches(), ImageColorSwatches(cgImage))
    }

    func testUIImageSymbol() throws {
        let symbol = try XCTUnwrap(UIImage(systemName: "square.fill")?
            .withTintColor(UIColor(yellow), renderingMode: .alwaysOriginal))
        // The `CGImage` of a symbol image is its untinted glyph, so the tint is only
        // found by drawing it
        let palette = try XCTUnwrap(symbol.toColorPalette())
        XCTAssertLessThan(palette.background.distance(to: yellow), 0.02)
        // Drawn at its size in pixels
        let pixels = try XCTUnwrap(symbol.toColorPalettePixels(quality: .lossless))
        XCTAssertEqual(pixels.width, Int((symbol.size.width * symbol.scale).rounded()))
        XCTAssertEqual(pixels.colorSpace, .displayP3)
    }

    func testUIImageCIImage() throws {
        let ciImage = CIImage(color: CIColor(red: 0.1, green: 0.14, blue: 0.5)).cropped(to: CGRect(x: 0, y: 0, width: 20, height: 20))
        let image = UIImage(ciImage: ciImage)
        XCTAssertNil(image.cgImage)
        let palette = try XCTUnwrap(image.toColorPalette())
        XCTAssertLessThan(palette.background.distance(to: navy), 0.02)
    }

    func testUIImageSymbolAsync() throws {
        let symbol = try XCTUnwrap(UIImage(systemName: "square.fill")?
            .withTintColor(UIColor(yellow), renderingMode: .alwaysOriginal))
        let palette = symbol.toColorPalette(quality: .lossless)
        XCTAssertLessThan(try XCTUnwrap(palette).background.distance(to: yellow), 0.02)
    }
    #endif
}
