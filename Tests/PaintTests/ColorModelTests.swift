//
// Copyright (c) Nathan Tannar
//

import XCTest
import SwiftUI
#if canImport(CoreImage)
import CoreImage
#endif
@testable import Paint

/// Tests each color model: ``HEXColor``, ``ColorHue``, ``RGBAColor``, ``HSBAColor``, ``HSLAColor`` and ``OKLCHColor``.
final class ColorModelTests: XCTestCase {

    func testHEXDecoding() {
        XCTAssertEqual(HEXColor(decoding: "#F80")?.rawValue, 0xFF8800FF)
        XCTAssertEqual(HEXColor(decoding: "F80")?.rawValue, 0xFF8800FF)
        XCTAssertEqual(HEXColor(decoding: "#F808")?.rawValue, 0xFF880088)
        XCTAssertEqual(HEXColor(decoding: "#FF8000")?.rawValue, 0xFF8000FF)
        XCTAssertEqual(HEXColor(decoding: "#ff8000")?.rawValue, 0xFF8000FF)
        XCTAssertEqual(HEXColor(decoding: "#FF800080")?.rawValue, 0xFF800080)
        XCTAssertEqual(HEXColor(decoding: "00000000")?.rawValue, 0x00000000)
        XCTAssertEqual(HEXColor(decoding: "  #FF8000\n")?.rawValue, 0xFF8000FF)
        XCTAssertEqual(HEXColor(decoding: "\t#abc\r\n")?.rawValue, 0xAABBCCFF)
        XCTAssertEqual(HEXColor(decoding: "#aBcD")?.rawValue, 0xAABBCCDD)
    }

    func testHEXDecodingInvalid() {
        for string in ["", "#", "#F", "#FF", "#FFFFF", "#FFFFFFF", "#FFFFFFFFF", "#GGG", "##FFF",
                       "+FFF", "-FFF", "+FFFFFF", "FF FF FF", "0xFFFFFF", "#FF８000",
                       "# FFF", "#FFF#", "FFF\u{0}", "\u{FEFF}FFF"] {
            XCTAssertNil(HEXColor(decoding: string), string)
        }
    }

    func testHEXStringFallback() {
        XCTAssertEqual(HEXColor("invalid").rawValue, 0x000000FF)
        let literal: HEXColor = "#0F0"
        XCTAssertEqual(literal.rawValue, 0x00FF00FF)
    }

    func testHEXComponents() {
        let color = HEXColor(0x12345678)
        XCTAssertEqual(color.red, 0x12)
        XCTAssertEqual(color.green, 0x34)
        XCTAssertEqual(color.blue, 0x56)
        XCTAssertEqual(color.alpha, 0x78)
        XCTAssertEqual(color.toString(), "12345678")
        XCTAssertEqual(color.description, "#12345678")
    }

    func testHEXComponentSetters() {
        // Each setter replaces only its own byte
        var color = HEXColor(0x12345678)
        color.red = 0xAB
        XCTAssertEqual(color.rawValue, 0xAB345678)
        color.green = 0xCD
        XCTAssertEqual(color.rawValue, 0xABCD5678)
        color.blue = 0xEF
        XCTAssertEqual(color.rawValue, 0xABCDEF78)
        color.alpha = 0x01
        XCTAssertEqual(color.rawValue, 0xABCDEF01)

        // Extremes don't spill into neighboring channels
        var white = HEXColor(0xFFFFFFFF)
        white.green = 0
        XCTAssertEqual(white.rawValue, 0xFF00FFFF)
        white.green = 0xFF
        XCTAssertEqual(white.rawValue, 0xFFFFFFFF)
        var black = HEXColor(0x00000000)
        black.alpha = 0xFF
        XCTAssertEqual(black, "#000000")

        // Compound assignment works through the setter
        var orange: HEXColor = "#FF8000"
        orange.green += 0x10
        XCTAssertEqual(orange, "#FF9000")
    }

    func testHEXString() {
        // Opaque colors omit the alpha channel
        XCTAssertEqual(HEXColor(0xFF8000FF).toString(), "FF8000")
        XCTAssertEqual(HEXColor(0xFF8000FF).description, "#FF8000FF")
        XCTAssertEqual(HEXColor(0x0000FFFF).description, "#0000FFFF")
        // Translucent colors keep it, even when nearly opaque or fully transparent
        XCTAssertEqual(HEXColor(0xFF800080).toString(), "FF800080")
        XCTAssertEqual(HEXColor(0xFF800080).description, "#FF800080")
        XCTAssertEqual(HEXColor(0x00FF00FE).description, "#00FF00FE")
        XCTAssertEqual(HEXColor(0x00000000).description, "#00000000")
        // Leading zeros are kept, and digits are uppercase
        XCTAssertEqual(HEXColor(0x000000FF).toString(), "000000")
        XCTAssertEqual(HEXColor(0x00000A80).toString(), "00000A80")
        XCTAssertEqual(HEXColor(0xABCDEFFF).toString(), "ABCDEF")
        // The formatter can write all eight digits, and a prefix
        XCTAssertEqual(ColorStringFormatter.hex(0xFF8000FF, prefersOpaqueAlpha: true, includePrefix: false), "FF8000FF")
        XCTAssertEqual(ColorStringFormatter.hex(0xFF800080, prefersOpaqueAlpha: true, includePrefix: false), "FF800080")
        XCTAssertEqual(ColorStringFormatter.hex(0xFF8000FF, includePrefix: true), "#FF8000")
        XCTAssertEqual(ColorStringFormatter.hex(0x000000FF, prefersOpaqueAlpha: true, includePrefix: true), "#000000FF")

        // Every format decodes, and describes as the shortest equivalent
        XCTAssertEqual(HEXColor("#F80").description, "#FF8800FF")
        XCTAssertEqual(HEXColor("#F808").description, "#FF880088")
        XCTAssertEqual(HEXColor("ff8000").description, "#FF8000FF")
        XCTAssertEqual(HEXColor("#FF8000FF").description, "#FF8000FF")
        XCTAssertEqual(HEXColor("#0000FF").description, "#0000FFFF")

        // From floating point colors
        XCTAssertEqual(RGBAColor(red: 1, green: 0.5, blue: 0).toHEXColor().description, "#FF8000FF")
        XCTAssertEqual(RGBAColor(red: 1, green: 0.5, blue: 0, alpha: 0.5).toHEXColor().description, "#FF800080")
        XCTAssertEqual(RGBAColor(red: 1, green: 0.5, blue: 0).toCSSColor(.hex).rawValue, "#FF8000FF")
        XCTAssertEqual(RGBAColor(red: 1, green: 0.5, blue: 0, alpha: 0.5).toCSSColor(.hex).rawValue, "#FF800080")
    }

    func testHEXFromDoublesClampsAndRounds() {
        XCTAssertEqual(HEXColor(red: 1, green: 0, blue: 0.5, alpha: 1).rawValue, 0xFF0080FF)
        XCTAssertEqual(HEXColor(red: 2, green: -1, blue: .infinity, alpha: -.infinity).rawValue, 0xFF00FF00)
        XCTAssertEqual(HEXColor(red: .nan, green: .nan, blue: .nan, alpha: .nan).rawValue, 0)
        XCTAssertEqual(HEXColor(red: 0, green: 0, blue: 0).alpha, 255)
    }

    func testHEXCodable() throws {
        let color: HEXColor = "#FF800080"
        let data = try JSONEncoder().encode([color])
        XCTAssertEqual(String(decoding: data, as: UTF8.self), #"["FF800080"]"#)
        XCTAssertEqual(try JSONDecoder().decode([HEXColor].self, from: data), [color])
        XCTAssertEqual(try JSONDecoder().decode([HEXColor].self, from: Data(##"["#F80"]"##.utf8)).first?.rawValue, 0xFF8800FF)
        // Opaque colors encode without the alpha channel, and colors encoded with it
        // before still decode
        let opaque: HEXColor = "#FF8000"
        let opaqueData = try JSONEncoder().encode([opaque])
        XCTAssertEqual(String(decoding: opaqueData, as: UTF8.self), #"["FF8000"]"#)
        XCTAssertEqual(try JSONDecoder().decode([HEXColor].self, from: opaqueData), [opaque])
        XCTAssertEqual(try JSONDecoder().decode([HEXColor].self, from: Data(#"["FF8000FF"]"#.utf8)), [opaque])
        XCTAssertThrowsError(try JSONDecoder().decode([HEXColor].self, from: Data(#"["nope"]"#.utf8)))
    }

    func testHEXToRGBA() {
        assertEqual(
            HEXColor(0xFF800000).toRGBAColor(),
            RGBAColor(red: 1, green: 128.0 / 255, blue: 0, alpha: 0)
        )
    }

    // MARK: - ColorHue

    func testHueUnits() {
        let hue = ColorHue.degrees(90)
        XCTAssertEqual(hue.degrees, 90)
        XCTAssertEqual(hue.radians, .pi / 2, accuracy: 1e-12)
        XCTAssertEqual(hue.rawValue, 0.25)
        XCTAssertEqual(ColorHue.radians(.pi).degrees, 180, accuracy: 1e-12)
        XCTAssertEqual(ColorHue(rawValue: 0.5), .degrees(180))
        XCTAssertEqual(ColorHue(rawValue: 1.0 / 3).degrees, 120, accuracy: 1e-12)

        var mutable: ColorHue = 0
        mutable.degrees = 180
        XCTAssertEqual(mutable.rawValue, 0.5)
        mutable.radians = .pi / 2
        XCTAssertEqual(mutable.degrees, 90, accuracy: 1e-12)
    }

    func testHueRawRepresentable() {
        // The raw value is the `0...1` hue Apple's APIs take
        let hue = ColorHue.degrees(120)
        XCTAssertEqual(ColorHue(rawValue: hue.rawValue), hue)
        func roundTrip<T: RawRepresentable>(_ value: T) -> T? { T(rawValue: value.rawValue) }
        XCTAssertEqual(roundTrip(hue), hue)
    }

    func testHueArithmeticWraps() {
        XCTAssertEqual((ColorHue.degrees(350) + .degrees(20)).degrees, 10, accuracy: 1e-9)
        XCTAssertEqual((ColorHue.degrees(10) - .degrees(20)).degrees, 350, accuracy: 1e-9)
        XCTAssertEqual(ColorHue.zero, 0)

        let hue = ColorHue.degrees(350)
        XCTAssertEqual(hue + .zero, hue)
        XCTAssertEqual(hue + -hue, .zero)

        var rotated = hue
        rotated += .degrees(180)
        XCTAssertEqual(rotated.degrees, 170, accuracy: 1e-9)
        rotated -= .degrees(180)
        XCTAssertEqual(rotated.degrees, 350, accuracy: 1e-9)
    }

    func testHueWraps() {
        let cases: [(Double, Double)] = [
            (0, 0), (30, 30), (359.5, 359.5), (360, 0), (390, 30), (720, 0),
            (-30, 330), (-360, 0), (-390, 330),
            (-1e-20, 0), // Rounds up to exactly 360, which wraps to 0
            (.nan, 0), (.infinity, 0), (-.infinity, 0),
        ]
        for (degrees, expected) in cases {
            let hue = ColorHue.degrees(degrees)
            XCTAssertEqual(hue.degrees, expected, accuracy: 1e-9, "\(degrees)")
            XCTAssertGreaterThanOrEqual(hue.rawValue, 0)
            XCTAssertLessThan(hue.rawValue, 1)
        }
        // Every unit wraps, including when set
        XCTAssertEqual(ColorHue(rawValue: 1.25).rawValue, 0.25)
        XCTAssertEqual(ColorHue(rawValue: -0.25).rawValue, 0.75)
        XCTAssertEqual(ColorHue.radians(3 * .pi).degrees, 180, accuracy: 1e-9)
        var hue: ColorHue = 0
        hue.degrees = 450
        XCTAssertEqual(hue.degrees, 90)
        hue.degrees = -180
        XCTAssertEqual(hue.rawValue, 0.5)
        // Equivalent hues are exactly equal
        XCTAssertEqual(ColorHue.degrees(390), .degrees(30))
        XCTAssertEqual(ColorHue.degrees(-330), .degrees(30))
        XCTAssertEqual(ColorHue.degrees(-120), .degrees(240))
    }

    func testHueLiterals() {
        // Float and integer literals are both fractions of a full turn
        let half: ColorHue = 0.5
        XCTAssertEqual(half, .degrees(180))
        let zero: ColorHue = 0
        XCTAssertEqual(zero, .degrees(0))
        let integer: ColorHue = 1
        let float: ColorHue = 1.0
        XCTAssertEqual(integer, float)
        XCTAssertEqual(integer, .degrees(0))
        let negative: ColorHue = -1
        XCTAssertEqual(negative, .degrees(0))
        XCTAssertEqual(HSBAColor(hue: 0.25, saturation: 1, brightness: 1).hue, .degrees(90))
        // An integer hue must not be read as a 60° sector
        XCTAssertEqual(HSBAColor(hue: 1, saturation: 1, brightness: 1), HSBAColor(hue: 1.0, saturation: 1, brightness: 1))
    }

    func testHueWrapsInColors() {
        // Hues wrap when stored, so equivalent colors are equal
        let wrapped = HSBAColor(hue: .degrees(390), saturation: 1, brightness: 1)
        let hsba = HSBAColor(hue: .degrees(30), saturation: 1, brightness: 1)
        XCTAssertEqual(wrapped, hsba)
        XCTAssertEqual(wrapped.hue.degrees, 30)
        assertEqual(wrapped.toRGBAColor(), hsba.toRGBAColor())
        XCTAssertEqual(HSLAColor(hue: .degrees(-330), saturation: 1, lightness: 0.5), HSLAColor(hue: .degrees(30), saturation: 1, lightness: 0.5))
        XCTAssertEqual(OKLCHColor(lightness: 0.6, chroma: 0.1, hue: .degrees(390)), OKLCHColor(lightness: 0.6, chroma: 0.1, hue: .degrees(30)))
    }
    func testHueIsSharedAcrossModels() {
        // Every model reports hue in the same units, so they can be compared directly
        let rgba = RGBAColor(red: 0, green: 1, blue: 0)
        XCTAssertEqual(rgba.toHSBAColor().hue, .degrees(120))
        XCTAssertEqual(rgba.toHSLAColor().hue, .degrees(120))
        XCTAssertEqual(rgba.toHSBAColor().hue, rgba.toHSLAColor().hue)
        // Oklab hues are a different, perceptual hue wheel
        XCTAssertEqual(rgba.toOKLCHColor().hue.degrees, 142.495, accuracy: 1e-2)

        // A hue from one model can be used to build another
        let hue = HSBAColor(hue: .degrees(200), saturation: 0.5, brightness: 0.8).hue
        let hsla = HSLAColor(hue: hue, saturation: 0.5, lightness: 0.5)
        XCTAssertEqual(hsla.toHSBAColor().hue, hue)
    }

    func testHueCodable() throws {
        // Encodes the stored fraction of a full turn
        let data = try JSONEncoder().encode([ColorHue.degrees(90)])
        XCTAssertEqual(String(decoding: data, as: UTF8.self), "[0.25]")
        XCTAssertEqual(try JSONDecoder().decode([ColorHue].self, from: data), [.degrees(90)])

        // Decoding wraps values outside one turn
        XCTAssertEqual(try JSONDecoder().decode([ColorHue].self, from: Data("[1.25]".utf8)), [ColorHue(rawValue: 0.25)])

        // Every model encodes hue the same way
        for color in [
            try JSONEncoder().encode(HSBAColor(hue: .degrees(90), saturation: 1, brightness: 1)),
            try JSONEncoder().encode(HSLAColor(hue: .degrees(90), saturation: 1, lightness: 0.5)),
            try JSONEncoder().encode(OKLCHColor(lightness: 0.5, chroma: 0.1, hue: .degrees(90))),
        ] {
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: color) as? [String: Any])
            XCTAssertEqual(object["hue"] as? Double, 0.25)
        }
    }
    // MARK: - RGBAColor

    func testLinearization() {
        for value in stride(from: -2.0, through: 2.0, by: 0.01) {
            XCTAssertEqual(RGBAColor.delinearize(RGBAColor.linearize(value)), value, accuracy: 1e-12)
        }
        XCTAssertEqual(RGBAColor.linearize(0), 0)
        XCTAssertEqual(RGBAColor.linearize(1), 1, accuracy: 1e-12)
        XCTAssertEqual(RGBAColor.linearize(0.5), 0.21404114, accuracy: 1e-8)
        // Extended sRGB mirrors negative values
        XCTAssertEqual(RGBAColor.linearize(-0.5), -RGBAColor.linearize(0.5))
    }

    func testRGBAClamped() {
        let extended = RGBAColor(red: -0.1, green: 1.2, blue: 0.5, alpha: 2)
        XCTAssertEqual(extended.clamped(), RGBAColor(red: 0, green: 1, blue: 0.5, alpha: 1))
    }

    // MARK: - HSBAColor

    func testRGBAToHSBA() {
        let cases: [(RGBAColor, HSBAColor)] = [
            (RGBAColor(red: 1, green: 0, blue: 0), HSBAColor(hue: .degrees(0), saturation: 1, brightness: 1)),
            (RGBAColor(red: 0, green: 1, blue: 0), HSBAColor(hue: .degrees(120), saturation: 1, brightness: 1)),
            (RGBAColor(red: 0, green: 0, blue: 1), HSBAColor(hue: .degrees(240), saturation: 1, brightness: 1)),
            (RGBAColor(red: 1, green: 0, blue: 1), HSBAColor(hue: .degrees(300), saturation: 1, brightness: 1)),
            (RGBAColor(red: 0.5, green: 0.25, blue: 0.25), HSBAColor(hue: .degrees(0), saturation: 0.5, brightness: 0.5)),
            (RGBAColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.3), HSBAColor(hue: .degrees(0), saturation: 0, brightness: 0.5, alpha: 0.3)),
            (RGBAColor(red: 0, green: 0, blue: 0), HSBAColor(hue: .degrees(0), saturation: 0, brightness: 0)),
        ]
        for (rgba, hsba) in cases {
            let converted = rgba.toHSBAColor()
            XCTAssertEqual(converted.hue.degrees, hsba.hue.degrees, accuracy: 1e-9)
            XCTAssertEqual(converted.saturation, hsba.saturation, accuracy: 1e-12)
            XCTAssertEqual(converted.brightness, hsba.brightness, accuracy: 1e-12)
            XCTAssertEqual(converted.alpha, hsba.alpha)
            assertEqual(hsba.toRGBAColor(), rgba)
        }
    }

    func testHSBAHueWraps() {
        let red = RGBAColor(red: 1, green: 0, blue: 0)
        let blue = RGBAColor(red: 0, green: 0, blue: 1)
        assertEqual(HSBAColor(hue: .degrees(360), saturation: 1, brightness: 1).toRGBAColor(), red)
        assertEqual(HSBAColor(hue: .degrees(-360), saturation: 1, brightness: 1).toRGBAColor(), red)
        assertEqual(HSBAColor(hue: .degrees(-120), saturation: 1, brightness: 1).toRGBAColor(), blue)
        assertEqual(HSBAColor(hue: .degrees(960), saturation: 1, brightness: 1).toRGBAColor(), blue)
        assertEqual(HSBAColor(hue: .degrees(-1e-20), saturation: 1, brightness: 1).toRGBAColor(), red)
        // Non-finite hues must not trap
        assertEqual(HSBAColor(hue: .degrees(.nan), saturation: 1, brightness: 1).toRGBAColor(), red)
        assertEqual(HSBAColor(hue: .degrees(.infinity), saturation: 1, brightness: 1).toRGBAColor(), red)
    }

    // MARK: - HSLAColor

    func testRGBAToHSLA() {
        let cases: [(RGBAColor, HSLAColor)] = [
            (RGBAColor(red: 1, green: 0, blue: 0), HSLAColor(hue: .degrees(0), saturation: 1, lightness: 0.5)),
            (RGBAColor(red: 0, green: 1, blue: 0), HSLAColor(hue: .degrees(120), saturation: 1, lightness: 0.5)),
            (RGBAColor(red: 0, green: 0, blue: 1), HSLAColor(hue: .degrees(240), saturation: 1, lightness: 0.5)),
            (RGBAColor(red: 0.75, green: 0.25, blue: 0.25), HSLAColor(hue: .degrees(0), saturation: 0.5, lightness: 0.5)),
            (RGBAColor(red: 1, green: 1, blue: 1), HSLAColor(hue: .degrees(0), saturation: 0, lightness: 1)),
            (RGBAColor(red: 0, green: 0, blue: 0, alpha: 0.3), HSLAColor(hue: .degrees(0), saturation: 0, lightness: 0, alpha: 0.3)),
        ]
        for (rgba, hsla) in cases {
            let converted = rgba.toHSLAColor()
            XCTAssertEqual(converted.hue.degrees, hsla.hue.degrees, accuracy: 1e-9)
            XCTAssertEqual(converted.saturation, hsla.saturation, accuracy: 1e-12)
            XCTAssertEqual(converted.lightness, hsla.lightness, accuracy: 1e-12)
            XCTAssertEqual(converted.alpha, hsla.alpha)
            assertEqual(hsla.toRGBAColor(), rgba)
        }
    }

    func testHSLAHueWraps() {
        let red = RGBAColor(red: 1, green: 0, blue: 0)
        let blue = RGBAColor(red: 0, green: 0, blue: 1)
        assertEqual(HSLAColor(hue: .degrees(360), saturation: 1, lightness: 0.5).toRGBAColor(), red)
        assertEqual(HSLAColor(hue: .degrees(-120), saturation: 1, lightness: 0.5).toRGBAColor(), blue)
        assertEqual(HSLAColor(hue: .degrees(.nan), saturation: 1, lightness: 0.5).toRGBAColor(), red)
    }

    func testHSBAToHSLADirect() {
        // Direct conversion keeps the hue of achromatic colors
        let gray = HSBAColor(hue: .degrees(90), saturation: 0, brightness: 0.5, alpha: 0.5)
        XCTAssertEqual(HSLAColor(gray), HSLAColor(hue: .degrees(90), saturation: 0, lightness: 0.5, alpha: 0.5))
        XCTAssertEqual(HSBAColor(HSLAColor(gray)), gray)

        for hex in hexGrid {
            let hsba = hex.toHSBAColor()
            let hsla = hex.toHSLAColor()
            let direct = hsba.toHSLAColor()
            XCTAssertEqual(direct.hue.degrees, hsla.hue.degrees, accuracy: 1e-9)
            XCTAssertEqual(direct.saturation, hsla.saturation, accuracy: 1e-9)
            XCTAssertEqual(direct.lightness, hsla.lightness, accuracy: 1e-9)
            let back = hsla.toHSBAColor()
            XCTAssertEqual(back.hue.degrees, hsba.hue.degrees, accuracy: 1e-9)
            XCTAssertEqual(back.saturation, hsba.saturation, accuracy: 1e-9)
            XCTAssertEqual(back.brightness, hsba.brightness, accuracy: 1e-9)
        }
    }

    // MARK: - OKLCHColor

    func testOKLCHReferenceValues() {
        // Reference values from https://bottosson.github.io/posts/oklab/ and CSS Color 4
        let white = OKLCHColor(RGBAColor(red: 1, green: 1, blue: 1))
        XCTAssertEqual(white.lightness, 1, accuracy: 1e-6)
        XCTAssertEqual(white.chroma, 0)
        XCTAssertEqual(white.hue, 0)
        XCTAssertTrue(white.isNearWhite)

        let black = OKLCHColor(RGBAColor(red: 0, green: 0, blue: 0))
        XCTAssertEqual(black.lightness, 0, accuracy: 1e-9)
        XCTAssertEqual(black.chroma, 0)

        let red = OKLCHColor(RGBAColor(red: 1, green: 0, blue: 0))
        XCTAssertEqual(red.lightness, 0.62796, accuracy: 1e-4)
        XCTAssertEqual(red.chroma, 0.25768, accuracy: 1e-4)
        XCTAssertEqual(red.hue.degrees, 29.2339, accuracy: 1e-2)
        XCTAssertEqual(red.a, 0.22486, accuracy: 1e-4)
        XCTAssertEqual(red.b, 0.12585, accuracy: 1e-4)

        let blue = OKLCHColor(RGBAColor(red: 0, green: 0, blue: 1))
        XCTAssertEqual(blue.lightness, 0.45201, accuracy: 1e-4)
        XCTAssertEqual(blue.hue.degrees, 264.052, accuracy: 1e-2)
    }

    func testOKLCHCartesian() {
        let color = OKLCHColor(lightness: 0.7, a: -0.1, b: -0.1)
        XCTAssertEqual(color.hue.degrees, 225, accuracy: 1e-9)
        XCTAssertEqual(color.chroma, 0.1 * 2.0.squareRoot(), accuracy: 1e-12)
        XCTAssertEqual(color.a, -0.1, accuracy: 1e-12)
        XCTAssertEqual(color.b, -0.1, accuracy: 1e-12)
        // Cartesian coordinates round trip through the polar form
        let red = OKLCHColor(RGBAColor(red: 1, green: 0, blue: 0))
        let cartesian = OKLCHColor(lightness: red.lightness, a: red.a, b: red.b)
        XCTAssertEqual(cartesian.lightness, red.lightness)
        XCTAssertEqual(cartesian.chroma, red.chroma, accuracy: 1e-12)
        XCTAssertEqual(cartesian.hue.degrees, red.hue.degrees, accuracy: 1e-9)
    }

    func testOKLCHExtendedRoundTrip() {
        let extended = RGBAColor(red: 1.2, green: -0.1, blue: 0.4)
        let oklch = OKLCHColor(extended)
        assertEqual(oklch.toRGBAColor(), extended, accuracy: 1e-6)
    }
}
