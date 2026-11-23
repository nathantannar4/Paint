//
// Copyright (c) Nathan Tannar
//

import XCTest
import SwiftUI
#if canImport(CoreImage)
import CoreImage
#endif
@testable import Paint

/// Tests conversions between color models, including OKLCH edge cases.
final class ColorConversionTests: XCTestCase {

    func testAllConversionsRoundTripThroughHEX() {
        for hex in hexGrid {
            XCTAssertEqual(hex.toRGBAColor().toHEXColor(), hex)
            XCTAssertEqual(hex.toHSBAColor().toHEXColor(), hex)
            XCTAssertEqual(hex.toHSLAColor().toHEXColor(), hex)
            XCTAssertEqual(hex.toOKLCHColor().toHEXColor(), hex)
            XCTAssertEqual(hex.toHSBAColor().toHSLAColor().toOKLCHColor().toHEXColor(), hex)
        }
    }

    func testAllConversionsRoundTripThroughEachOther() {
        let rgba = RGBAColor(red: 0.2, green: 0.6, blue: 0.9, alpha: 0.75)
        let colors: [any ColorConvertible] = [
            rgba,
            rgba.toHSBAColor(),
            rgba.toHSLAColor(),
            rgba.toOKLCHColor(),
        ]
        for source in colors {
            let converted: [any ColorConvertible] = [
                source.toRGBAColor(),
                source.toHSBAColor(),
                source.toHSLAColor(),
                source.toOKLCHColor(),
            ]
            for target in converted {
                // Oklab's published matrices are not exact inverses, so allow ~1e-7 error
                assertEqual(target.toRGBAColor(), rgba, accuracy: 1e-6)
            }
            assertEqual(source.toHEXColor().toRGBAColor(), rgba, accuracy: 0.5 / 255)
        }
    }

    func testIdentityConversions() {
        let hex: HEXColor = "#336699CC"
        XCTAssertEqual(hex.toHEXColor(), hex)
        let rgba = hex.toRGBAColor()
        XCTAssertEqual(rgba.toRGBAColor(), rgba)
        let hsba = hex.toHSBAColor()
        XCTAssertEqual(hsba.toHSBAColor(), hsba)
        let hsla = hex.toHSLAColor()
        XCTAssertEqual(hsla.toHSLAColor(), hsla)
        let oklch = hex.toOKLCHColor()
        XCTAssertEqual(oklch.toOKLCHColor(), oklch)
    }

    func testCodableRoundTrip() throws {
        let hex: HEXColor = "#336699CC"
        func roundTrip<C: ColorConvertible & Codable & Equatable>(_ color: C) throws {
            let data = try JSONEncoder().encode(color)
            XCTAssertEqual(try JSONDecoder().decode(C.self, from: data), color)
        }
        try roundTrip(hex)
        try roundTrip(hex.toRGBAColor())
        try roundTrip(hex.toHSBAColor())
        try roundTrip(hex.toHSLAColor())
        try roundTrip(hex.toOKLCHColor())
    }

    func testCGColor() throws {
        let rgba = RGBAColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.8)
        // sRGB components are read directly, at full precision
        assertEqual(try XCTUnwrap(rgba.toCGColor().toRGBAColor()), rgba, accuracy: 1e-12)

        let hex = try XCTUnwrap(CGColor(srgbRed: 1, green: 0.5, blue: 0, alpha: 1).toRGBAColor()?.toHEXColor())
        XCTAssertEqual(hex, "#FF8000")

        // Other color spaces are converted
        let gray = try XCTUnwrap(CGColor(gray: 0.5, alpha: 1).toRGBAColor())
        XCTAssertEqual(gray.red, gray.green, accuracy: 1e-6)
        XCTAssertEqual(gray.green, gray.blue, accuracy: 1e-6)

        // Extended values survive the round trip
        let extended = RGBAColor(red: 1.2, green: -0.1, blue: 0.5)
        assertEqual(try XCTUnwrap(extended.toCGColor().toRGBAColor()), extended, accuracy: 1e-12)
    }

    func testToCGColor() throws {
        let rgba = RGBAColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.8)
        let cgColor = rgba.toCGColor()
        XCTAssertEqual(cgColor.colorSpace?.name, CGColorSpace.extendedSRGB)
        assertEqual(try XCTUnwrap(cgColor.toRGBAColor()), rgba, accuracy: 1e-12)

        // Every model converts through sRGB
        let hex: HEXColor = "#FF8000"
        XCTAssertEqual(try XCTUnwrap(hex.toCGColor().toRGBAColor()?.toHEXColor()), hex)
        let oklch = OKLCHColor(lightness: 0.7, chroma: 0.1, hue: .degrees(200))
        assertEqual(try XCTUnwrap(oklch.toCGColor().toRGBAColor()), oklch.toRGBAColor(), accuracy: 1e-12)

        // Extended values are preserved
        let extended = RGBAColor(red: 1.2, green: -0.1, blue: 0.5)
        assertEqual(try XCTUnwrap(extended.toCGColor().toRGBAColor()), extended, accuracy: 1e-12)
    }

    func testEvery8BitValueRoundTrips() {
        // Covers every channel value, including the darkest values where the
        // sRGB transfer function and Oklab cube root are most sensitive
        for value in 0...255 {
            let v = Double(value) / 255
            let colors = [
                HEXColor(red: v, green: v, blue: v, alpha: v),
                HEXColor(red: v, green: 0, blue: 0),
                HEXColor(red: 0, green: v, blue: 0),
                HEXColor(red: 0, green: 0, blue: v),
            ]
            for hex in colors {
                XCTAssertEqual(hex.toHSBAColor().toHEXColor(), hex, "\(hex)")
                XCTAssertEqual(hex.toHSLAColor().toHEXColor(), hex, "\(hex)")
                XCTAssertEqual(hex.toOKLCHColor().toHEXColor(), hex, "\(hex)")
            }
        }
    }

    func testRandomRoundTrips() {
        var generator = SplitMix64(seed: 0xC0FFEE)
        for _ in 0..<2_000 {
            let rgba = RGBAColor(
                red: .random(in: 0...1, using: &generator),
                green: .random(in: 0...1, using: &generator),
                blue: .random(in: 0...1, using: &generator),
                alpha: .random(in: 0...1, using: &generator)
            )
            assertEqual(rgba.toHSBAColor().toRGBAColor(), rgba, accuracy: 1e-12)
            assertEqual(rgba.toHSLAColor().toRGBAColor(), rgba, accuracy: 1e-12)
            assertEqual(rgba.toHSBAColor().toHSLAColor().toRGBAColor(), rgba, accuracy: 1e-12)
            assertEqual(rgba.toHSLAColor().toHSBAColor().toRGBAColor(), rgba, accuracy: 1e-12)
            // Oklab's published matrices are only inverses to ~1e-7, and the sRGB transfer
            // function's 12.92 slope near black magnifies that to ~1e-6
            assertEqual(rgba.toOKLCHColor().toRGBAColor(), rgba, accuracy: 1e-5)
        }
    }

    func testExtendedRangeHSLARoundTrips() {
        let colors = [
            RGBAColor(red: 1.2, green: 1.0, blue: 0.9),
            RGBAColor(red: -0.1, green: -0.05, blue: -0.2),
            RGBAColor(red: 1.5, green: 0.2, blue: 1.1),
            RGBAColor(red: -0.3, green: 0.6, blue: 0.1),
        ]
        for rgba in colors {
            let hsla = rgba.toHSLAColor()
            XCTAssertGreaterThanOrEqual(hsla.saturation, 0, "\(rgba)")
            assertEqual(hsla.toRGBAColor(), rgba, accuracy: 1e-12)
            assertEqual(hsla.toHSBAColor().toRGBAColor(), rgba, accuracy: 1e-12)
            assertEqual(rgba.toHSBAColor().toHSLAColor().toRGBAColor(), rgba, accuracy: 1e-12)
        }
        // Lightness above 1 stores its saturation with the opposite hue
        let hsla = RGBAColor(red: 1.2, green: 1.0, blue: 0.9).toHSLAColor()
        XCTAssertEqual(hsla.lightness, 1.05, accuracy: 1e-12)
        XCTAssertEqual(hsla.saturation, 3, accuracy: 1e-12)
        XCTAssertEqual(hsla.hue.degrees, 200, accuracy: 1e-9)
    }

    func testHSBAToHSLAEdges() {
        // Black, white and grays hit the division guards
        XCTAssertEqual(
            HSBAColor(hue: .degrees(180), saturation: 1, brightness: 0).toHSLAColor(),
            HSLAColor(hue: .degrees(180), saturation: 0, lightness: 0)
        )
        XCTAssertEqual(
            HSBAColor(hue: .degrees(180), saturation: 0, brightness: 1).toHSLAColor(),
            HSLAColor(hue: .degrees(180), saturation: 0, lightness: 1)
        )
        XCTAssertEqual(
            HSLAColor(hue: .degrees(180), saturation: 1, lightness: 0).toHSBAColor(),
            HSBAColor(hue: .degrees(180), saturation: 0, brightness: 0)
        )
        XCTAssertEqual(
            HSLAColor(hue: .degrees(180), saturation: 1, lightness: 1).toHSBAColor(),
            HSBAColor(hue: .degrees(180), saturation: 0, brightness: 1)
        )
        // Fully saturated HSL is fully saturated HSB
        let red = HSLAColor(hue: .degrees(0), saturation: 1, lightness: 0.5).toHSBAColor()
        XCTAssertEqual(red.saturation, 1, accuracy: 1e-12)
        XCTAssertEqual(red.brightness, 1, accuracy: 1e-12)
        // Grays have no saturation in either model
        let gray = RGBAColor(red: 0.3, green: 0.3, blue: 0.3)
        XCTAssertEqual(gray.toHSBAColor().saturation, 0)
        XCTAssertEqual(gray.toHSLAColor().saturation, 0)
        assertEqual(HSLAColor(hue: .degrees(252), saturation: 0, lightness: 0.3).toRGBAColor(), gray, accuracy: 1e-12)
    }

    func testNonFiniteInputsDoNotTrap() {
        let values: [Double] = [.nan, .infinity, -.infinity, .greatestFiniteMagnitude, -.greatestFiniteMagnitude]
        for value in values {
            let rgba = RGBAColor(red: value, green: value, blue: value, alpha: value)
            _ = rgba.toHSBAColor().toRGBAColor()
            _ = rgba.toHSLAColor().toRGBAColor()
            _ = rgba.toOKLCHColor().toRGBAColor()
            _ = rgba.toHEXColor()
            _ = HSBAColor(hue: .degrees(value), saturation: value, brightness: value).toRGBAColor()
            _ = HSLAColor(hue: .degrees(value), saturation: value, lightness: value).toRGBAColor()
            _ = HSBAColor(hue: .degrees(value), saturation: value, brightness: value).toHSLAColor()
            _ = HSLAColor(hue: .degrees(value), saturation: value, lightness: value).toHSBAColor()
            let oklch = OKLCHColor(lightness: value, chroma: value, hue: .degrees(value))
            _ = oklch.toRGBAColor()
            _ = oklch.toHEXColor()
        }
        // NaN hex channels quantize to 0
        XCTAssertEqual(RGBAColor(red: .nan, green: .nan, blue: .nan, alpha: .nan).toHEXColor().rawValue, 0)
    }

    func testCodableFormat() throws {
        // The keys are part of the persisted format, so changing them is a breaking change
        func keys<C: Encodable>(_ color: C) throws -> Set<String> {
            let data = try JSONEncoder().encode(color)
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            return Set(object.keys)
        }
        XCTAssertEqual(try keys(RGBAColor(red: 0, green: 0, blue: 0)), ["red", "green", "blue", "alpha"])
        XCTAssertEqual(try keys(HSBAColor(hue: .degrees(0), saturation: 0, brightness: 0)), ["hue", "saturation", "brightness", "alpha"])
        XCTAssertEqual(try keys(HSLAColor(hue: .degrees(0), saturation: 0, lightness: 0)), ["hue", "saturation", "lightness", "alpha"])
        XCTAssertEqual(try keys(OKLCHColor(lightness: 0, chroma: 0, hue: .degrees(0))), ["lightness", "chroma", "hue", "alpha"])

        let json = Data(#"{"lightness":0.5,"chroma":0.1,"hue":0.5,"alpha":1}"#.utf8)
        XCTAssertEqual(try JSONDecoder().decode(OKLCHColor.self, from: json), OKLCHColor(lightness: 0.5, chroma: 0.1, hue: .degrees(180)))
    }

    func testWideGamutCGColor() throws {
        // Display P3 green is outside sRGB, so it converts to extended sRGB
        let colorSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.displayP3))
        let p3Green = try XCTUnwrap(CGColor(colorSpace: colorSpace, components: [0, 1, 0, 1]))
        let rgba = try XCTUnwrap(p3Green.toRGBAColor())
        assertEqual(rgba, RGBAColor(red: -0.5116, green: 1.0183, blue: -0.3107), accuracy: 1e-3)
        // Hex gamut maps to sRGB, keeping lightness and hue rather than clamping to #00FF00
        let hex = rgba.toHEXColor()
        XCTAssertEqual(hex, "#00F74F")
        XCTAssertEqual(hex.toOKLCHColor().lightness, rgba.toOKLCHColor().lightness, accuracy: 0.005)
        XCTAssertEqual(hex.toOKLCHColor().hue.degrees, rgba.toOKLCHColor().hue.degrees, accuracy: 1)
        // Round trips through extended sRGB
        assertEqual(try XCTUnwrap(rgba.toCGColor().toRGBAColor()), rgba, accuracy: 1e-12)
    }

    // MARK: - OKLCH Edge Cases

    func testIsNearWhite() {
        // Thresholds are inclusive
        XCTAssertTrue(OKLCHColor(lightness: 1, chroma: 0, hue: .degrees(0)).isNearWhite)
        XCTAssertTrue(OKLCHColor(lightness: 0.96, chroma: 0.02, hue: .degrees(0)).isNearWhite)
        XCTAssertFalse(OKLCHColor(lightness: 0.95, chroma: 0, hue: .degrees(0)).isNearWhite)
        XCTAssertFalse(OKLCHColor(lightness: 1, chroma: 0.03, hue: .degrees(0)).isNearWhite)

        // Off-whites and the faintest tints, from any color model
        for hex in ["#FFFFFF", "#FEFEFE", "#FAFAFA", "#F5F5F5", "#F2F2F7", "#FFFFF0", "#F0F8FF"] as [HEXColor] {
            XCTAssertTrue(hex.isNearWhite, "\(hex)")
            XCTAssertTrue(hex.toRGBAColor().isNearWhite, "\(hex)")
            XCTAssertTrue(hex.toHSBAColor().isNearWhite, "\(hex)")
        }
        // Light grays, visible tints and saturated light colors
        for hex in ["#EEEEEE", "#E5E5E5", "#FFF8E1", "#F5F5DC", "#F0FFF0", "#FFFF00"] as [HEXColor] {
            XCTAssertFalse(hex.isNearWhite, "\(hex)")
        }

        // Alpha is ignored
        XCTAssertTrue(RGBAColor(red: 1, green: 1, blue: 1, alpha: 0).isNearWhite)
    }

    func testOKLCHLightness() {
        func lightness(red: Double, green: Double, blue: Double) -> Double {
            RGBAColor(red: red, green: green, blue: blue).toOKLCHColor().lightness
        }

        // White and black are the ends of the lightness scale
        XCTAssertEqual(lightness(red: 1, green: 1, blue: 1), 1, accuracy: 1e-6)
        XCTAssertEqual(lightness(red: 0, green: 0, blue: 0), 0, accuracy: 1e-12)

        // Lightness is monotonic along the gray ramp
        var previous = -Double.infinity
        for value in stride(from: 0.0, through: 1.0, by: 0.01) {
            let current = lightness(red: value, green: value, blue: value)
            XCTAssertGreaterThan(current, previous)
            previous = current
        }

        // Perceptually, green is lighter than red, which is lighter than blue
        let red = lightness(red: 1, green: 0, blue: 0)
        let green = lightness(red: 0, green: 1, blue: 0)
        let blue = lightness(red: 0, green: 0, blue: 1)
        XCTAssertGreaterThan(green, red)
        XCTAssertGreaterThan(red, blue)
    }

    func testOKLCHHueWraps() {
        let color = OKLCHColor(lightness: 0.6, chroma: 0.1, hue: .degrees(30))
        for hue in [390.0, -330, 750] {
            let wrapped = OKLCHColor(lightness: 0.6, chroma: 0.1, hue: .degrees(hue))
            assertEqual(wrapped.toRGBAColor(), color.toRGBAColor(), accuracy: 1e-12)
            XCTAssertEqual(wrapped.a, color.a, accuracy: 1e-12)
            XCTAssertEqual(wrapped.b, color.b, accuracy: 1e-12)
        }
        // Converting back normalizes the hue
        XCTAssertEqual(OKLCHColor(lightness: 0.6, chroma: 0.1, hue: .degrees(-330)).toRGBAColor().toOKLCHColor().hue.degrees, 30, accuracy: 1e-4)
    }

    func testOKLCHAchromatic() {
        // Grays have exactly zero chroma and hue, regardless of floating point noise
        for value in stride(from: 0.0, through: 1.0, by: 0.05) {
            let gray = RGBAColor(red: value, green: value, blue: value).toOKLCHColor()
            XCTAssertEqual(gray.chroma, 0, "\(value)")
            XCTAssertEqual(gray.hue, 0, "\(value)")
        }
        // Just above the threshold keeps its hue
        let tinted = OKLCHColor(lightness: 0.5, a: 0, b: 1e-5)
        XCTAssertEqual(tinted.hue.degrees, 90, accuracy: 1e-9)
        XCTAssertEqual(tinted.chroma, 1e-5, accuracy: 1e-12)
    }
}
