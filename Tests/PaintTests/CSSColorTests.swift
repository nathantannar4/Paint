//
// Copyright (c) Nathan Tannar
//

import XCTest
@testable import Paint

/// Tests CSS color parsing, serialization and names.
final class CSSColorTests: XCTestCase {

    private let red = RGBAColor(red: 1, green: 0, blue: 0)

    private func parse(_ string: String, file: StaticString = #filePath, line: UInt = #line) throws -> RGBAColor {
        try XCTUnwrap(CSSColor(decoding: string)?.toRGBAColor(), "Failed to parse \(string)", file: file, line: line)
    }

    func testParsingSRGB() throws {
        assertEqual(try parse("#F00"), red)
        assertEqual(try parse("red"), red)
        assertEqual(try parse("  RED  "), red)
        assertEqual(try parse("rebeccapurple"), HEXColor("#663399").toRGBAColor())
        XCTAssertEqual(try parse("transparent").alpha, 0)

        assertEqual(try parse("rgb(255 0 0)"), red)
        assertEqual(try parse("rgb(255, 0, 0)"), red)
        assertEqual(try parse("rgb(100% 0% 0%)"), red)
        assertEqual(try parse("rgba(255, 0, 0, 0.5)"), RGBAColor(red: 1, green: 0, blue: 0, alpha: 0.5))
        assertEqual(try parse("rgb(255 0 0 / 50%)"), RGBAColor(red: 1, green: 0, blue: 0, alpha: 0.5))
        assertEqual(try parse("rgb(none 0 0)"), RGBAColor(red: 0, green: 0, blue: 0))
        assertEqual(try parse("rgb(300 -10 0)"), red) // Clamped

        assertEqual(try parse("hsl(0 100% 50%)"), red)
        assertEqual(try parse("hsl(120deg, 100%, 25%)"), RGBAColor(red: 0, green: 0.5, blue: 0))
        assertEqual(try parse("hsl(0.5turn 100% 50%)"), RGBAColor(red: 0, green: 1, blue: 1))
        assertEqual(try parse("hsla(3.14159265rad 100% 50% / 0.25)"), RGBAColor(red: 0, green: 1, blue: 1, alpha: 0.25), accuracy: 1e-6)
        assertEqual(try parse("hsl(200grad 100% 50%)"), RGBAColor(red: 0, green: 1, blue: 1), accuracy: 1e-9)
        assertEqual(try parse("hwb(0 0% 0%)"), red)
        assertEqual(try parse("hwb(0 50% 50%)"), RGBAColor(red: 0.5, green: 0.5, blue: 0.5))
    }

    func testParsingWideGamut() throws {
        assertEqual(try parse("lab(54.29 80.80 69.89)"), red, accuracy: 2e-3)
        assertEqual(try parse("lch(54.29% 106.84 40.85deg)"), red, accuracy: 2e-3)
        assertEqual(try parse("oklab(0.62796 0.22486 0.12585)"), red, accuracy: 1e-4)
        assertEqual(try parse("oklch(62.796% 0.25768 29.2339)"), red, accuracy: 1e-4)
        assertEqual(try parse("color(srgb 1 0 0)"), red)
        assertEqual(try parse("color(srgb-linear 100% 0% 0%)"), red)
        assertEqual(try parse("color(xyz-d65 0.4124 0.2126 0.0193)"), red, accuracy: 2e-3)
        assertEqual(try parse("color(xyz-d50 0.4360 0.2225 0.0139)"), red, accuracy: 2e-3)

        // Display P3 and Rec. 2020 red are outside sRGB
        let p3Red = try parse("color(display-p3 1 0 0)")
        XCTAssertGreaterThan(p3Red.red, 1)
        XCTAssertTrue(ColorGamut.displayP3.contains(p3Red))
        let rec2020Red = try parse("color(rec2020 1 0 0 / 0.5)")
        XCTAssertFalse(ColorGamut.displayP3.contains(rec2020Red))
        XCTAssertTrue(ColorGamut.rec2020.contains(rec2020Red))
        XCTAssertEqual(rec2020Red.alpha, 0.5)
        assertEqual(try parse("color(display-p3 1 1 1)"), RGBAColor(red: 1, green: 1, blue: 1), accuracy: 1e-6)
        assertEqual(try parse("color(rec2020 1 1 1)"), RGBAColor(red: 1, green: 1, blue: 1), accuracy: 1e-6)
        // Any whitespace separates the color space
        XCTAssertEqual(try parse("color(display-p3\t1 0 0)"), try parse("color(display-p3 1 0 0)"))
        XCTAssertEqual(try parse("color(\nsrgb\n1 0 0\n)"), RGBAColor(red: 1, green: 0, blue: 0))
    }

    func testParsingInvalid() {
        for string in [
            "", "foo", "#12", "rgb(1, 2)", "rgb(1 2 3 4)", "rgb(1, 2 3)", "rgb(1, 2, 3 / 0.5)",
            "rgb(1 2 3", "hsl(10% 50% 50%)", "rgb(10deg 0 0)", "color(unknown 1 0 0)",
            "color(srgb)", "rgb(a b c)", "rgb(1 2 3 / 0.5 / 1)", "canvas", "currentcolor",
            "rgb(nan 0 0)", "rgb(nan% 0 0)", "rgb(255 0 0 / nan%)", "lab(nan% 0 0)",
            "oklch(0.5 nan% 30)", "hsl(nandeg 50% 50%)", "hsl(infdeg 50% 50%)",
        ] {
            XCTAssertNil(CSSColor(decoding: string)?.toRGBAColor(), string)
        }
    }

    func testSerialization() {
        XCTAssertEqual(red.toCSSColor().rawValue, "rgb(255 0 0)")
        XCTAssertEqual(red.toCSSColor(.hex).rawValue, "#FF0000FF")
        XCTAssertEqual(red.toCSSColor(.hsl).rawValue, "hsl(0 100% 50%)")
        XCTAssertEqual(red.toCSSColor(.hwb).rawValue, "hwb(0 0% 0%)")
        XCTAssertEqual(red.toCSSColor(.oklch).rawValue, "oklch(0.628 0.2577 29.234)")
        XCTAssertEqual(red.toCSSColor(.lab).rawValue, "lab(54.291 80.805 69.891)")
        XCTAssertEqual(RGBAColor(red: 1, green: 0, blue: 0, alpha: 0.5).toCSSColor().rawValue, "rgb(255 0 0 / 0.5)")
        // Alpha that rounds to 1 is opaque
        let nearlyOpaque = RGBAColor(red: 1, green: 0, blue: 0, alpha: 0.9996)
        XCTAssertEqual(nearlyOpaque.toCSSColor().rawValue, "rgb(255 0 0)")
        XCTAssertEqual(nearlyOpaque.toCSSColor(.hex).rawValue, "#FF0000FF")
        XCTAssertEqual(nearlyOpaque.toCSSColor(.oklch), red.toCSSColor(.oklch))
        XCTAssertEqual(RGBAColor(red: 1, green: 0, blue: 0, alpha: 0.5).toCSSColor(.hex).rawValue, "#FF000080")
        XCTAssertEqual(RGBAColor(red: 1, green: 1, blue: 1).toCSSColor(.displayP3).rawValue, "color(display-p3 1 1 1)")
        XCTAssertEqual(RGBAColor(red: 0, green: 0, blue: 0).toCSSColor(.oklab).rawValue, "oklab(0 0 0)")

        // Every format round trips
        let colors: [RGBAColor] = [
            RGBAColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.8),
            RGBAColor(red: 0.9, green: 0.5, blue: 0.1),
            RGBAColor(red: 0, green: 0, blue: 0),
            RGBAColor(red: 1, green: 1, blue: 1),
        ]
        for color in colors {
            for format in CSSColorFormat.allCases {
                let string = color.toCSSColor(format).rawValue
                guard let parsed = CSSColor(decoding: string)?.toRGBAColor() else {
                    XCTFail("Failed to parse \(string)")
                    continue
                }
                XCTAssertLessThan(parsed.distance(to: color), 0.005, "\(format): \(string)")
                XCTAssertEqual(parsed.alpha, color.alpha, accuracy: 0.004, "\(format): \(string)")
            }
        }

        // sRGB formats gamut map wide gamut colors, while others keep them
        let p3 = OKLCHColor(lightness: 0.7, chroma: 0.3, hue: .degrees(150))
        let rgb = CSSColor(decoding: p3.toCSSColor(.rgb).rawValue)?.toRGBAColor()
        XCTAssertTrue(ColorGamut.sRGB.contains(rgb ?? red))
        XCTAssertLessThan(CSSColor(decoding: p3.toCSSColor(.oklch).rawValue)?.distance(to: p3) ?? 1, 0.001)
    }

    // MARK: - CSSColor

    func testCSSColorKeepsDecodedString() throws {
        for string in ["red", "  RED  ", "#FF000080", "rgb(255, 0, 0)", "oklch(0.7 0.15 250)", "color(display-p3 1 0 0)"] {
            let color = try XCTUnwrap(CSSColor(decoding: string), string)
            XCTAssertEqual(color.rawValue, string)
            XCTAssertEqual(color.description, string)
            XCTAssertEqual(CSSColor(rawValue: string), color)
        }
        // Wide gamut colors aren't clipped
        let p3 = try XCTUnwrap(CSSColor(decoding: "color(display-p3 1 0 0)"))
        XCTAssertGreaterThan(p3.toRGBAColor().red, 1)
    }

    func testCSSColorInvalid() {
        for string in ["", "redd", "rgb(1 2)", "canvas", "#12"] {
            XCTAssertNil(CSSColor(decoding: string), string)
            XCTAssertEqual(CSSColor(rawValue: string).rawValue, string)
        }
    }

    func testCSSColorLiteral() {
        let color: CSSColor = "rebeccapurple"
        XCTAssertEqual(color.rawValue, "rebeccapurple")
        XCTAssertEqual(color.toHEXColor(), "#663399")
        // Like `HEXColor`, invalid literals are black
        let invalid: CSSColor = "not a color"
        XCTAssertEqual(invalid.rawValue, "not a color")
        XCTAssertEqual(invalid.toRGBAColor().toCSSColor().rawValue, "rgb(0 0 0)")
    }

    func testCSSColorEqualityComparesStrings() throws {
        let named = try XCTUnwrap(CSSColor(decoding: "red"))
        let hex = try XCTUnwrap(CSSColor(decoding: "#FF0000"))
        XCTAssertNotEqual(named, hex)
        XCTAssertEqual(named.toRGBAColor(), hex.toRGBAColor())
        XCTAssertTrue(named.isApproximatelyEqual(to: hex))
        XCTAssertEqual(Set([named, hex, try XCTUnwrap(CSSColor(decoding: "red"))]).count, 2)
    }

    func testCSSColorEqualityIgnoresHowItWasCreated() throws {
        // Decoded colors keep their color, and literals decode it when converted, but
        // both are the same string, so they're equal and hash the same
        let decoded = try XCTUnwrap(CSSColor(decoding: "oklch(0.7 0.15 250)"))
        let literal: CSSColor = "oklch(0.7 0.15 250)"
        let raw = CSSColor(rawValue: "oklch(0.7 0.15 250)")
        XCTAssertEqual(decoded, literal)
        XCTAssertEqual(decoded, raw)
        XCTAssertEqual(decoded.hashValue, literal.hashValue)
        XCTAssertEqual(Set([decoded, literal, raw]).count, 1)
        XCTAssertEqual(decoded.toRGBAColor(), literal.toRGBAColor())
        XCTAssertEqual(decoded.toRGBAColor(), raw.toRGBAColor())
    }

    func testCSSColorColorMatchesItsString() throws {
        // A written color is the color its rounded string decodes to, not the exact
        // color it was written from, so equal colors always convert the same
        let orange = RGBAColor(red: 1, green: 0.5, blue: 0)
        for format in CSSColorFormat.allCases {
            let written = orange.toCSSColor(format)
            let decoded = try XCTUnwrap(CSSColor(decoding: written.rawValue), written.rawValue)
            XCTAssertEqual(written, decoded, written.rawValue)
            XCTAssertEqual(written.toRGBAColor(), decoded.toRGBAColor(), written.rawValue)
            // HEX is 8-bit, the least precise format
            XCTAssertLessThan(written.distance(to: orange), 0.002, written.rawValue)
        }

        // Including through encoding and decoding
        let written = orange.toCSSColor(.oklch)
        let data = try JSONEncoder().encode(written)
        let decoded = try JSONDecoder().decode(CSSColor.self, from: data)
        XCTAssertEqual(decoded, written)
        XCTAssertEqual(decoded.toRGBAColor(), written.toRGBAColor())

        // Fitted colors too
        let p3 = try XCTUnwrap(CSSColor(decoding: "color(display-p3 0 1 0)"))
        let fitted = p3.toColorGamut(.sRGB)
        XCTAssertEqual(fitted.toRGBAColor(), CSSColor(decoding: fitted.rawValue)?.toRGBAColor())
    }

    func testCSSColorUncheckedStrings() {
        // Strings created without decoding aren't checked, and invalid ones are black
        let invalid = CSSColor(rawValue: "not a color")
        XCTAssertEqual(invalid.rawValue, "not a color")
        XCTAssertEqual(invalid.toRGBAColor(), RGBAColor(red: 0, green: 0, blue: 0))
        XCTAssertNotEqual(invalid, CSSColor(rawValue: "black"))
    }

    func testToCSSColor() throws {
        // sRGB colors are written as `rgb()`, wider colors as `oklch()`
        let orange = HEXColor("#FF8000")
        XCTAssertEqual(orange.toCSSColor().rawValue, "rgb(255 128 0)")
        let p3 = try parse("color(display-p3 0 1 0)")
        let written = p3.toCSSColor()
        XCTAssertTrue(written.rawValue.hasPrefix("oklch("), written.rawValue)
        XCTAssertLessThan(written.distance(to: p3), 0.001)

        // An explicit format, with the color matching the rounded string
        let hsl = orange.toCSSColor(.hsl)
        XCTAssertEqual(hsl.rawValue, orange.toCSSColor(.hsl).rawValue)
        XCTAssertEqual(hsl.toRGBAColor(), CSSColor(decoding: hsl.rawValue)?.toRGBAColor())
        for format in CSSColorFormat.allCases {
            XCTAssertEqual(p3.toCSSColor(format), CSSColor(p3, format: format))
        }

        // A `CSSColor` converts to itself, keeping its string
        let named = try XCTUnwrap(CSSColor(decoding: "tomato"))
        XCTAssertEqual(named.toCSSColor().rawValue, "tomato")
    }

    func testCSSColorGamut() throws {
        // Colors in the gamut keep their string
        let named = try XCTUnwrap(CSSColor(decoding: "tomato"))
        XCTAssertEqual(named.toColorGamut(.sRGB).rawValue, "tomato")

        let p3 = try XCTUnwrap(CSSColor(decoding: "color(display-p3 0 1 0)"))
        XCTAssertEqual(p3.toColorGamut(.displayP3), p3)
        let srgb = p3.toColorGamut(.sRGB)
        XCTAssertTrue(srgb.rawValue.hasPrefix("rgb("), srgb.rawValue)
        XCTAssertTrue(ColorGamut.sRGB.contains(srgb))

        let rec2020 = try XCTUnwrap(CSSColor(decoding: "color(rec2020 0 1 0)"))
        let fitted = rec2020.toColorGamut(.displayP3)
        XCTAssertTrue(fitted.rawValue.hasPrefix("color(display-p3"), fitted.rawValue)
        XCTAssertTrue(ColorGamut.displayP3.contains(fitted))
    }

    func testCSSColorCodable() throws {
        let color = try XCTUnwrap(CSSColor(decoding: "oklch(0.7 0.15 250 / 0.5)"))
        let data = try JSONEncoder().encode(color)
        XCTAssertEqual(String(decoding: data, as: UTF8.self), #""oklch(0.7 0.15 250 \/ 0.5)""#)
        XCTAssertEqual(try JSONDecoder().decode(CSSColor.self, from: data), color)
        XCTAssertThrowsError(try JSONDecoder().decode(CSSColor.self, from: Data(#""not a color""#.utf8)))
    }

    func testCSSColorWorksWithColorAPIs() throws {
        let text = try XCTUnwrap(CSSColor(decoding: "white"))
        let background = try XCTUnwrap(CSSColor(decoding: "#000"))
        XCTAssertEqual(text.contrast(.wcag).against(background).rawValue, 21, accuracy: 1e-9)
        XCTAssertEqual(text.toOKLCHColor().lightness, 1, accuracy: 1e-6)
        XCTAssertEqual(background.toCGColor().toRGBAColor(), RGBAColor(red: 0, green: 0, blue: 0))
    }
}
