//
// Copyright (c) Nathan Tannar
//

import XCTest
@testable import Paint

/// Tests ``ColorSpace``, converting components in it to ``RGBAColor``, and finding
/// the colors of images in wide gamut and other RGB color spaces.
final class RGBColorSpaceTests: XCTestCase {

    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    func testColorSpaceNames() throws {
        let names: [(CFString, ColorSpace)] = [
            (CGColorSpace.sRGB, .sRGB), (CGColorSpace.extendedSRGB, .sRGB),
            (CGColorSpace.linearSRGB, .linearSRGB), (CGColorSpace.extendedLinearSRGB, .linearSRGB),
            (CGColorSpace.displayP3, .displayP3), (CGColorSpace.extendedDisplayP3, .displayP3),
            (CGColorSpace.linearDisplayP3, .linearDisplayP3), (CGColorSpace.extendedLinearDisplayP3, .linearDisplayP3),
            (CGColorSpace.itur_2020, .rec2020), (CGColorSpace.extendedITUR_2020, .rec2020),
            (CGColorSpace.linearITUR_2020, .linearRec2020), (CGColorSpace.extendedLinearITUR_2020, .extendedLinearRec2020),
        ]
        for (name, expected) in names {
            XCTAssertEqual(ColorSpace(name), expected, "\(name)")
            XCTAssertEqual(ColorSpace(try XCTUnwrap(CGColorSpace(name: name))), expected, "\(name)")
        }
        // No known conversion, or not RGB
        XCTAssertNil(ColorSpace(CGColorSpace.adobeRGB1998))
        XCTAssertNil(ColorSpace(CGColorSpace.genericGrayGamma2_2))
        XCTAssertNil(ColorSpace(CGColorSpace(name: CGColorSpace.genericCMYK)!))

        for colorSpace in ColorSpace.allCases {
            let encoded = colorSpace.toGammaEncodedColorSpace()
            XCTAssertFalse(encoded.isLinear)
            if !colorSpace.isLinear {
                XCTAssertEqual(encoded, colorSpace)
            }
            // The Core Graphics color space maps back to the same case
            XCTAssertEqual(ColorSpace(colorSpace.toCGColorSpace()), colorSpace)
        }
        // On this OS, every case is available, and each is listed once
        XCTAssertEqual(ColorSpace.allCases.count, 7)
        XCTAssertEqual(Set(ColorSpace.allCases).count, ColorSpace.allCases.count)
        XCTAssertEqual(ColorSpace.extendedLinearRec2020.toGammaEncodedColorSpace(), .rec2020)
        XCTAssertTrue(ColorSpace.extendedLinearRec2020.isLinear)
    }

    func testLinearSRGB() {
        // Linear light `0.5` is about `0.735` gamma encoded
        let color = RGBAColor(red: 0.5, green: 0, blue: 1, alpha: 0.25, colorSpace: .linearSRGB)
        XCTAssertEqual(color.red, RGBAColor.delinearize(0.5), accuracy: 1e-12)
        XCTAssertEqual(color.red, 0.7354, accuracy: 1e-4)
        XCTAssertEqual(color.blue, 1, accuracy: 1e-12)
        XCTAssertEqual(color.alpha, 0.25)
        // sRGB components are kept exactly, including extended ones
        XCTAssertEqual(RGBAColor(red: 1.2, green: -0.1, blue: 0.5, colorSpace: .sRGB), RGBAColor(red: 1.2, green: -0.1, blue: 0.5))
    }

    func testMatchesColorSync() throws {
        let extendedSRGB = try XCTUnwrap(CGColorSpace(name: CGColorSpace.extendedSRGB))
        for colorSpace in ColorSpace.allCases {
            let cgColorSpace = colorSpace.toCGColorSpace()
            for components in [[0.5, 0.25, 0.75], [1, 0, 0], [0, 1, 0], [0, 0, 1], [1, 1, 1], [0.2, 0.6, 0.4]] {
                let color = RGBAColor(red: components[0], green: components[1], blue: components[2], colorSpace: colorSpace)
                let cgColor = try XCTUnwrap(CGColor(colorSpace: cgColorSpace, components: components.map { CGFloat($0) } + [1]))
                let converted = try XCTUnwrap(cgColor.converted(to: extendedSRGB, intent: .defaultIntent, options: nil)?.components)
                // ColorSync converts at `Float` precision, with slightly different primaries
                assertEqual(
                    color,
                    RGBAColor(red: Double(converted[0]), green: Double(converted[1]), blue: Double(converted[2])),
                    accuracy: 5e-4
                )
            }
        }
        // Display P3 red is outside sRGB
        XCTAssertGreaterThan(RGBAColor(red: 1, green: 0, blue: 0, colorSpace: .displayP3).red, 1)
    }

    func testBT2020TransferFunctions() throws {
        // The camera curve, used by CSS, and the display curve, used by Core Graphics
        XCTAssertEqual(BT2020CameraTransfer.linearize(0.5), 0.2598, accuracy: 1e-4)
        XCTAssertEqual(BT1886Transfer.linearize(0.5), pow(0.5, 2.4), accuracy: 1e-12)
        XCTAssertEqual(BT1886Transfer.linearize(0.5), 0.1895, accuracy: 1e-4)
        // Linear near black, and mirrored for negative components
        XCTAssertEqual(BT2020CameraTransfer.linearize(0.05), 0.05 / 4.5, accuracy: 1e-12)
        XCTAssertEqual(BT2020CameraTransfer.linearize(-0.5), -BT2020CameraTransfer.linearize(0.5))
        XCTAssertEqual(BT1886Transfer.linearize(-0.5), -BT1886Transfer.linearize(0.5))
        // Both are exact at black and white
        for transfer in [BT2020CameraTransfer.linearize, BT1886Transfer.linearize] {
            XCTAssertEqual(transfer(0), 0, accuracy: 1e-12)
            XCTAssertEqual(transfer(1), 1, accuracy: 1e-12)
        }

        // So the same components are a lighter gray in CSS than in Core Graphics
        let css = try XCTUnwrap(CSSColor(decoding: "color(rec2020 0.5 0.5 0.5)")).toRGBAColor()
        let coreGraphics = RGBAColor(red: 0.5, green: 0.5, blue: 0.5, colorSpace: .rec2020)
        XCTAssertEqual(css.red, 0.5466, accuracy: 1e-3)
        XCTAssertEqual(coreGraphics.red, 0.4725, accuracy: 1e-3)
    }

    func testToComponentsRoundTrips() {
        let colors = [
            RGBAColor(red: 0.5, green: 0.25, blue: 0.75, alpha: 0.5),
            RGBAColor(red: 1, green: 0, blue: 0),
            RGBAColor(red: 0, green: 0, blue: 0),
            RGBAColor(red: 1, green: 1, blue: 1),
            // Extended sRGB, outside every gamut on one side
            RGBAColor(red: 1.2, green: -0.1, blue: 0.5),
        ]
        for colorSpace in ColorSpace.allCases {
            for color in colors {
                let components = color.toComponents(in: colorSpace)
                let roundTripped = RGBAColor(
                    red: components.x,
                    green: components.y,
                    blue: components.z,
                    alpha: color.alpha,
                    colorSpace: colorSpace
                )
                assertEqual(roundTripped, color, accuracy: 1e-9)
            }
        }
        // Components in a color space convert back to the same components
        let p3 = SIMD3<Double>(1, 0, 0)
        let color = RGBAColor(red: p3.x, green: p3.y, blue: p3.z, colorSpace: .displayP3)
        XCTAssertEqual(color.toComponents(in: .displayP3).x, 1, accuracy: 1e-8)
        XCTAssertEqual(color.toComponents(in: .displayP3).y, 0, accuracy: 1e-8)
        XCTAssertEqual(color.toComponents(in: .displayP3).z, 0, accuracy: 1e-8)
    }

    @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
    func testToComponentsValues() {
        let red = RGBAColor(red: 1, green: 0, blue: 0)
        // sRGB components are kept exactly
        XCTAssertEqual(red.toComponents(in: .sRGB), SIMD3(1, 0, 0))
        XCTAssertEqual(red.toComponents(in: .linearSRGB), red.toLinearComponents())
        // sRGB red is inside Display P3, matching the documented example
        let p3 = red.toComponents(in: .displayP3)
        XCTAssertEqual(p3.x, 0.917, accuracy: 1e-3)
        XCTAssertEqual(p3.y, 0.200, accuracy: 1e-3)
        XCTAssertEqual(p3.z, 0.139, accuracy: 1e-3)
        // Linear BT.2020 has the same conversion as its extended variant
        XCTAssertEqual(red.toComponents(in: .linearRec2020), red.toComponents(in: .extendedLinearRec2020))
        // Gray keeps equal components in every color space, since they share D65 white
        let gray = RGBAColor(red: 0.5, green: 0.5, blue: 0.5)
        for colorSpace in ColorSpace.allCases {
            let components = gray.toComponents(in: colorSpace)
            XCTAssertEqual(components.x, components.y, accuracy: 1e-9, "\(colorSpace)")
            XCTAssertEqual(components.y, components.z, accuracy: 1e-9, "\(colorSpace)")
        }
        // BT.2020 gray is encoded with the display curve
        XCTAssertEqual(gray.toComponents(in: .rec2020).x, BT1886Transfer.delinearize(RGBAColor.linearize(0.5)), accuracy: 1e-9)
    }

    func testToComponentsMatchesColorSync() throws {
        let sRGB = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        for colorSpace in ColorSpace.allCases {
            for components in [[0.5, 0.25, 0.75], [1, 0, 0], [0, 1, 0], [0, 0, 1], [0.2, 0.6, 0.4]] {
                let color = RGBAColor(red: components[0], green: components[1], blue: components[2])
                let cgColor = try XCTUnwrap(CGColor(colorSpace: sRGB, components: components.map { CGFloat($0) } + [1]))
                let converted = try XCTUnwrap(cgColor.converted(to: colorSpace.toCGColorSpace(), intent: .defaultIntent, options: nil)?.components)
                let expected = color.toComponents(in: colorSpace)
                // ColorSync converts at `Float` precision, with slightly different primaries
                XCTAssertEqual(expected.x, Double(converted[0]), accuracy: 5e-4, "\(colorSpace) \(components)")
                XCTAssertEqual(expected.y, Double(converted[1]), accuracy: 5e-4, "\(colorSpace) \(components)")
                XCTAssertEqual(expected.z, Double(converted[2]), accuracy: 5e-4, "\(colorSpace) \(components)")
            }
        }
    }

    func testBT1886Delinearize() {
        for c in [0, 0.05, 0.19, 0.5, 1, 1.5, -0.5] {
            XCTAssertEqual(BT1886Transfer.delinearize(BT1886Transfer.linearize(c)), c, accuracy: 1e-12)
        }
        XCTAssertEqual(BT1886Transfer.delinearize(-0.5), -BT1886Transfer.delinearize(0.5))
    }

    func testToColorSpace() throws {
        let color = RGBAColor(red: 0.5, green: 0.25, blue: 0.75, alpha: 0.5)
        for colorSpace in ColorSpace.allCases {
            // The components are the converted ones, and alpha is kept
            let transformed = color.toColorSpace(colorSpace)
            let components = color.toComponents(in: colorSpace)
            XCTAssertEqual(transformed, RGBAColor(red: components.x, green: components.y, blue: components.z, alpha: 0.5))
            // And it converts back to the same color
            let back = RGBAColor(
                red: transformed.red,
                green: transformed.green,
                blue: transformed.blue,
                alpha: transformed.alpha,
                colorSpace: colorSpace
            )
            assertEqual(back, color, accuracy: 1e-9)
        }
        // sRGB is unchanged
        XCTAssertEqual(color.toColorSpace(.sRGB), color)
        // The documented example: sRGB red is less saturated in Display P3
        let p3 = RGBAColor(red: 1, green: 0, blue: 0).toColorSpace(.displayP3)
        XCTAssertEqual(p3.red, 0.917, accuracy: 1e-3)
        XCTAssertEqual(p3.green, 0.200, accuracy: 1e-3)
        XCTAssertEqual(p3.blue, 0.139, accuracy: 1e-3)
        // Drawn in its Core Graphics color space, it's the same color
        let cgColor = try XCTUnwrap(CGColor(
            colorSpace: ColorSpace.displayP3.toCGColorSpace(),
            components: [p3.red, p3.green, p3.blue, 1].map { CGFloat($0) }
        ))
        let sRGB = try XCTUnwrap(cgColor.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil)?.components)
        XCTAssertEqual(Double(sRGB[0]), 1, accuracy: 5e-4)
        XCTAssertEqual(Double(sRGB[1]), 0, accuracy: 5e-4)
        XCTAssertEqual(Double(sRGB[2]), 0, accuracy: 5e-4)
    }

    // MARK: - Image colors

    /// A solid image filled with a color, in a color space.
    private func solidImage(_ components: [CGFloat], in name: CFString, floatComponents: Bool = false) throws -> CGImage {
        let colorSpace = try XCTUnwrap(CGColorSpace(name: name))
        let context = try XCTUnwrap(CGContext(
            data: nil,
            width: 16,
            height: 16,
            bitsPerComponent: floatComponents ? 16 : 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                | (floatComponents ? CGBitmapInfo.floatComponents.rawValue | CGBitmapInfo.byteOrder16Little.rawValue : 0)
        ))
        context.setFillColor(try XCTUnwrap(CGColor(colorSpace: colorSpace, components: components + [1])))
        context.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
        return try XCTUnwrap(context.makeImage())
    }

    @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
    func testPaletteKeepsExtendedDisplayP3() throws {
        // Extended color spaces can't be drawn into 8-bit bitmaps, so they're drawn in
        // their standard range form, keeping the gamut
        let image = try solidImage([0, 1, 0], in: CGColorSpace.extendedDisplayP3, floatComponents: true)
        let palette = try XCTUnwrap(ImageColorPalette(image))
        let p3Green = RGBAColor(red: 0, green: 1, blue: 0, colorSpace: .displayP3)
        XCTAssertFalse(ColorGamut.sRGB.contains(palette.background))
        XCTAssertLessThan(palette.background.distance(to: p3Green), 0.01)
    }

    func testPaletteFromAdobeRGB() throws {
        // Adobe RGB has no known conversion, so it's drawn in Display P3. This green
        // is outside sRGB, but inside Display P3.
        let components: [CGFloat] = [0.5, 0.9, 0.5]
        let image = try solidImage(components, in: CGColorSpace.adobeRGB1998)
        let palette = try XCTUnwrap(ImageColorPalette(image))
        let adobeRGB = try XCTUnwrap(CGColorSpace(name: CGColorSpace.adobeRGB1998))
        let expected = try XCTUnwrap(CGColor(colorSpace: adobeRGB, components: components + [1])?.toRGBAColor())
        XCTAssertFalse(ColorGamut.sRGB.contains(expected))
        XCTAssertTrue(ColorGamut.displayP3.contains(expected))
        XCTAssertFalse(ColorGamut.sRGB.contains(palette.background))
        // 8-bit Display P3 is within about half a step
        XCTAssertLessThan(palette.background.distance(to: expected), 0.01)
    }

    func testPaletteFromGrayscale() throws {
        let image = try solidImage([0.5], in: CGColorSpace.genericGrayGamma2_2)
        let palette = try XCTUnwrap(ImageColorPalette(image))
        XCTAssertLessThan(palette.background.toOKLCHColor().chroma, 0.005)
    }
}
