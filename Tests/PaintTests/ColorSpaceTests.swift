//
// Copyright (c) Nathan Tannar
//

import XCTest
@testable import Paint

/// Tests the OKLab, XYZ, Lab, LCh, HWB and CMYK models and the Rec. 2020 gamut.
final class ColorSpaceTests: XCTestCase {

    private let red = RGBAColor(red: 1, green: 0, blue: 0)
    private let white = RGBAColor(red: 1, green: 1, blue: 1)

    func testOKLab() {
        // Reference values from the CSS Color 4 spec
        let oklab = red.toOKLabColor()
        XCTAssertEqual(oklab.lightness, 0.62796, accuracy: 1e-4)
        XCTAssertEqual(oklab.a, 0.22486, accuracy: 1e-4)
        XCTAssertEqual(oklab.b, 0.12585, accuracy: 1e-4)
        XCTAssertEqual(oklab.chroma, red.toOKLCHColor().chroma, accuracy: 1e-12)
        for hex in hexGrid {
            assertEqual(hex.toOKLabColor().toRGBAColor(), hex.toRGBAColor(), accuracy: 1e-5)
        }
    }

    func testXYZ() {
        let xyz = white.toXYZColor()
        XCTAssertEqual(xyz.x, 0.95046, accuracy: 1e-4)
        XCTAssertEqual(xyz.y, 1, accuracy: 1e-9)
        XCTAssertEqual(xyz.z, 1.08906, accuracy: 1e-4)
        let chromaticity = try? XCTUnwrap(xyz.toChromaticity())
        XCTAssertEqual(chromaticity?.x ?? 0, 0.3127, accuracy: 1e-4)
        XCTAssertEqual(chromaticity?.y ?? 0, 0.3290, accuracy: 1e-4)
        XCTAssertNil(RGBAColor(red: 0, green: 0, blue: 0).toXYZColor().toChromaticity())

        // D50 white adapts to the D50 white point
        let d50 = xyz.toD50()
        XCTAssertEqual(d50.x, CIELabColor.white.x, accuracy: 1e-4)
        XCTAssertEqual(d50.z, CIELabColor.white.z, accuracy: 1e-4)
        let back = XYZColor(d50: d50.x, y: d50.y, z: d50.z)
        XCTAssertEqual(back.x, xyz.x, accuracy: 1e-7)

        for hex in hexGrid {
            assertEqual(hex.toXYZColor().toRGBAColor(), hex.toRGBAColor(), accuracy: 1e-9)
        }
    }

    func testLabAndLCH() {
        // Reference values from the CSS Color 4 spec
        let lab = red.toCIELabColor()
        XCTAssertEqual(lab.lightness, 54.29, accuracy: 0.01)
        XCTAssertEqual(lab.a, 80.80, accuracy: 0.05)
        XCTAssertEqual(lab.b, 69.89, accuracy: 0.05)
        let lch = red.toCIELCHColor()
        XCTAssertEqual(lch.chroma, 106.84, accuracy: 0.05)
        XCTAssertEqual(lch.hue.degrees, 40.85, accuracy: 0.05)

        let whiteLab = white.toCIELabColor()
        XCTAssertEqual(whiteLab.lightness, 100, accuracy: 1e-3)
        XCTAssertEqual(whiteLab.a, 0, accuracy: 1e-3)
        XCTAssertEqual(whiteLab.b, 0, accuracy: 1e-3)
        XCTAssertEqual(white.toCIELCHColor().chroma, 0)

        for hex in hexGrid {
            assertEqual(hex.toCIELabColor().toRGBAColor(), hex.toRGBAColor(), accuracy: 1e-5)
            assertEqual(hex.toCIELCHColor().toRGBAColor(), hex.toRGBAColor(), accuracy: 1e-5)
        }
    }

    func testHWB() {
        let hwb = RGBAColor(red: 1, green: 0.5, blue: 0).toHWBColor()
        XCTAssertEqual(hwb.hue.degrees, 30, accuracy: 1e-9)
        XCTAssertEqual(hwb.whiteness, 0, accuracy: 1e-9)
        XCTAssertEqual(hwb.blackness, 0, accuracy: 1e-9)
        // Whiteness and blackness adding to more than 1 is a gray
        assertEqual(HWBColor(hue: 0.3, whiteness: 0.6, blackness: 0.6).toRGBAColor(), RGBAColor(red: 0.5, green: 0.5, blue: 0.5))
        for hex in hexGrid {
            assertEqual(hex.toHWBColor().toRGBAColor(), hex.toRGBAColor(), accuracy: 1e-9)
        }
    }

    func testCMYK() {
        let cmyk = red.toCMYKColor()
        XCTAssertEqual(cmyk, CMYKColor(cyan: 0, magenta: 1, yellow: 1, black: 0))
        XCTAssertEqual(RGBAColor(red: 0, green: 0, blue: 0).toCMYKColor(), CMYKColor(cyan: 0, magenta: 0, yellow: 0, black: 1))
        for hex in hexGrid {
            assertEqual(hex.toCMYKColor().toRGBAColor(), hex.toRGBAColor(), accuracy: 1e-9)
        }
    }

    func testRec2020Gamut() {
        let p3Green = OKLCHColor(lightness: 0.7, chroma: 0.3, hue: .degrees(150))
        XCTAssertFalse(ColorGamut.sRGB.contains(p3Green))
        XCTAssertTrue(ColorGamut.rec2020.contains(red))
        XCTAssertTrue(ColorGamut.rec2020.contains(white))
        // Far outside every gamut
        let extreme = OKLCHColor(lightness: 0.7, chroma: 0.6, hue: .degrees(150))
        XCTAssertFalse(ColorGamut.rec2020.contains(extreme))
        let fitted = extreme.toColorGamut(.rec2020)
        XCTAssertTrue(ColorGamut.rec2020.contains(fitted))
        XCTAssertGreaterThan(fitted.chroma, extreme.toColorGamut(.displayP3).chroma)
        XCTAssertGreaterThan(extreme.toColorGamut(.displayP3).chroma, extreme.toColorGamut(.sRGB).chroma)
    }

    func testToColorGamut() {
        // CIE Lab converts back to sRGB with ~1e-6 error, from the D50 adaptation, so
        // colors fitted to a gamut boundary can test as just outside it
        func assertFits<C: ColorConvertible & Equatable>(_ color: C, exact: Bool = true, file: StaticString = #filePath, line: UInt = #line) {
            for gamut in [ColorGamut.sRGB, .displayP3, .rec2020] {
                let fitted = color.toColorGamut(gamut)
                assertEqual(fitted.toRGBAColor(), color.toRGBAColor().toColorGamut(gamut), accuracy: 1e-5, file: file, line: line)
                guard exact else { continue }
                XCTAssertTrue(gamut.contains(fitted), "\(C.self) in \(gamut)", file: file, line: line)
                // Fitting is idempotent, and colors in the gamut are unchanged
                XCTAssertEqual(fitted.toColorGamut(gamut), fitted, "\(C.self) in \(gamut)", file: file, line: line)
            }
        }
        let p3Green = OKLCHColor(lightness: 0.85, chroma: 0.35, hue: .degrees(145))
        let rgba = p3Green.toRGBAColor()
        assertFits(p3Green)
        assertFits(rgba)
        assertFits(rgba.toHSBAColor())
        assertFits(rgba.toHSLAColor())
        assertFits(rgba.toHWBColor())
        assertFits(rgba.toOKLabColor())
        assertFits(rgba.toXYZColor())
        assertFits(rgba.toCIELabColor(), exact: false)
        assertFits(rgba.toCIELCHColor(), exact: false)
        assertFits(rgba.toHEXColor())
        assertFits(rgba.toCMYKColor())
        // Each model keeps its own type, and maps like OKLCH
        assertEqual(rgba.toHSLAColor().toColorGamut(.sRGB).toRGBAColor(), p3Green.toColorGamut(.sRGB).toRGBAColor(), accuracy: 1e-5)
        // Grays in the gamut keep their hue
        let gray = HSBAColor(hue: .degrees(120), saturation: 0, brightness: 0.5)
        XCTAssertEqual(gray.toColorGamut(.sRGB), gray)
    }

    func testProtocolConversions() {
        let rgba = RGBAColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.8)
        // Converting to its own model is the identity
        let oklab = rgba.toOKLabColor()
        XCTAssertEqual(oklab.toOKLabColor(), oklab)
        let xyz = rgba.toXYZColor()
        XCTAssertEqual(xyz.toXYZColor(), xyz)
        let lab = rgba.toCIELabColor()
        XCTAssertEqual(lab.toCIELabColor(), lab)
        let lch = rgba.toCIELCHColor()
        XCTAssertEqual(lch.toCIELCHColor(), lch)
        let hwb = rgba.toHWBColor()
        XCTAssertEqual(hwb.toHWBColor(), hwb)
        let cmyk = rgba.toCMYKColor()
        XCTAssertEqual(cmyk.toCMYKColor(), cmyk)

        // Every model converts to every other through the protocol
        let models: [any ColorConvertible] = [
            rgba, rgba.toHEXColor(), rgba.toHSBAColor(), rgba.toHSLAColor(), rgba.toOKLCHColor(),
            oklab, xyz, lab, lch, hwb, cmyk,
        ]
        for model in models {
            let conversions: [any ColorConvertible] = [
                model.toRGBAColor(), model.toHSBAColor(), model.toHSLAColor(), model.toHWBColor(),
                model.toOKLCHColor(), model.toOKLabColor(), model.toXYZColor(), model.toCIELabColor(),
                model.toCIELCHColor(), model.toCMYKColor(), model.toHEXColor(),
            ]
            for conversion in conversions {
                XCTAssertLessThan(conversion.distance(to: rgba), 0.005, "\(type(of: model)) -> \(type(of: conversion))")
            }
        }
    }

    func testCodable() throws {
        try assertRoundTrips(OKLabColor(lightness: 0.5, a: 0.1, b: -0.1, alpha: 0.5))
        try assertRoundTrips(XYZColor(x: 0.2, y: 0.3, z: 0.4))
        try assertRoundTrips(CIELabColor(lightness: 50, a: 10, b: -20))
        try assertRoundTrips(CIELCHColor(lightness: 50, chroma: 30, hue: 0.25))
        try assertRoundTrips(HWBColor(hue: 0.5, whiteness: 0.2, blackness: 0.3))
        try assertRoundTrips(CMYKColor(cyan: 0.1, magenta: 0.2, yellow: 0.3, black: 0.4))
        XCTAssertEqual(try assertRoundTrips(ColorGamut.rec2020), "\"rec2020\"")
    }
}
