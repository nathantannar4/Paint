//
// Copyright (c) Nathan Tannar
//

import XCTest
@testable import Paint

/// Tests ``ColorFormatStyle``, parsing with ``ColorParseStrategy``, and ``HEXColor``
/// and ``CSSColor`` as `LosslessStringConvertible`.
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
final class ColorFormatStyleTests: XCTestCase {

    private let orange: HEXColor = "#FF8000"

    // MARK: Formatting

    func testHEXFormatting() {
        XCTAssertEqual(orange.formatted(.hex), "FF8000")
        XCTAssertEqual(RGBAColor(red: 1, green: 0.5, blue: 0, alpha: 0.5).formatted(.hex), "FF800080")
        XCTAssertEqual(ColorFormatStyle.hex.format(orange.toRGBAColor()), "FF8000")
        // Colors outside sRGB are gamut mapped, as `toHEXColor()` does
        let p3Red = RGBAColor(red: 1, green: 0, blue: 0, colorSpace: .displayP3)
        XCTAssertEqual(p3Red.formatted(.hex), p3Red.toHEXColor().toString())
    }

    func testCSSFormatting() {
        XCTAssertEqual(orange.formatted(.css()), "rgb(255 128 0)")
        XCTAssertEqual(orange.formatted(.css(.hex)), "#FF8000FF")
        for format in CSSColorFormat.allCases {
            XCTAssertEqual(orange.formatted(.css(format)), orange.toCSSColor(format).rawValue, "\(format)")
        }
    }

    func testNameFormatting() {
        XCTAssertEqual(orange.formatted(.name), orange.toDescriptiveName())
        XCTAssertEqual(ColorFormatStyle.name.format(orange.toRGBAColor()), orange.toDescriptiveName())
        XCTAssertEqual(HEXColor("#FFFFFF").formatted(.name), "white")
        XCTAssertEqual(HEXColor("#000000").formatted(.name), "black")
        // Matches `toDescriptiveName()` for every color model, ignoring alpha
        let colors: [any ColorConvertible] = [
            HEXColor("#0A84FF"),
            HEXColor("#663399"),
            OKLCHColor(lightness: 0.87, chroma: 0.37, hue: .degrees(142)),
            RGBAColor(red: 1, green: 0.5, blue: 0, alpha: 0.5),
            HSLAColor(hue: .degrees(210), saturation: 0.2, lightness: 0.3),
        ]
        for color in colors {
            XCTAssertEqual(color.formatted(.name), color.toDescriptiveName(), "\(color)")
        }
        XCTAssertEqual(
            RGBAColor(red: 1, green: 0.5, blue: 0, alpha: 0.5).formatted(.name),
            RGBAColor(red: 1, green: 0.5, blue: 0).formatted(.name)
        )
    }

    func testFormattedAcceptsEveryColorModel() {
        let oklch = OKLCHColor(lightness: 0.7, chroma: 0.15, hue: .degrees(60))
        XCTAssertEqual(oklch.formatted(.hex), oklch.toHEXColor().toString())
        XCTAssertEqual(orange.toHSLAColor().formatted(.hex), "FF8000")
    }

    // MARK: Parsing

    func testParsingAcceptsHEXAndCSS() throws {
        let cases: [(String, UInt32)] = [
            // HEX, with or without `#`
            ("#FF8000", 0xFF8000FF),
            ("ff8000", 0xFF8000FF),
            (" #FF8000 ", 0xFF8000FF),
            ("FF8000FF", 0xFF8000FF),
            ("#F80", 0xFF8800FF),
            ("F808", 0xFF880088),
            ("#FF800080", 0xFF800080),
            // CSS
            ("rebeccapurple", 0x663399FF),
            ("transparent", 0x00000000),
            ("rgb(255 128 0)", 0xFF8000FF),
            ("RGB(255, 128, 0)", 0xFF8000FF),
            ("hsl(30.118 100% 50%)", 0xFF8000FF),
        ]
        for (string, rawValue) in cases {
            XCTAssertEqual(try ColorParseStrategy().parse(string).toHEXColor().rawValue, rawValue, string)
        }
    }

    func testParsingRejectsNonColors() {
        // `hsb()` isn't CSS, and `#FF80000` has 7 digits
        for string in ["", "#", "#GGG", "#FF80000", "hsb(30 100% 100%)", "not a color"] {
            XCTAssertThrowsError(try ColorParseStrategy().parse(string), string) { error in
                XCTAssertEqual((error as? CocoaError)?.code, .formatting, string)
            }
        }
    }

    func testEveryStyleParsesEveryColor() throws {
        // A text field with a HEX style still accepts a named color, and vice versa
        for style in [ColorFormatStyle.hex, .css(), .css(.oklch), .name] {
            XCTAssertEqual(style.parseStrategy, ColorParseStrategy())
            XCTAssertEqual(try style.parseStrategy.parse("rebeccapurple").toHEXColor(), "#663399")
            XCTAssertEqual(try style.parseStrategy.parse("FF8000").toHEXColor(), orange)
        }
    }

    func testNamesDontParse() {
        // Descriptive names are for display, so most don't parse back
        for color: HEXColor in ["#2F3A4F", "#FFC0CB80", "#6B8E23"] {
            let name = color.formatted(.name)
            XCTAssertTrue(name.contains(" "), name)
            XCTAssertThrowsError(try ColorFormatStyle.name.parseStrategy.parse(name), name)
        }
    }

    // MARK: Round Trips

    func testHEXRoundTripIsExact() throws {
        for hex: HEXColor in ["#FF8000", "#FF800080", "#00000000", "#0A84FF", "#FFFFFF"] {
            let string = hex.formatted(.hex)
            XCTAssertEqual(try ColorParseStrategy().parse(string).toHEXColor(), hex, string)
        }
    }

    func testCSSRoundTripIsClose() throws {
        // CSS numbers are rounded, so the round trip is close rather than exact,
        // but always the same 8-bit color
        let colors: [HEXColor] = ["#FF8000", "#0A84FF", "#663399", "#12345678"]
        for color in colors {
            for format in CSSColorFormat.allCases {
                let string = color.formatted(.css(format))
                XCTAssertEqual(try ColorParseStrategy().parse(string).toHEXColor(), color, string)
            }
        }
    }

    func testStyleIsCodable() throws {
        for style in [ColorFormatStyle.hex, .css(), .css(.oklch), .name] {
            let data = try JSONEncoder().encode(style)
            XCTAssertEqual(try JSONDecoder().decode(ColorFormatStyle.self, from: data), style)
        }
    }

    // MARK: LosslessStringConvertible

    func testHEXColorIsLosslessStringConvertible() {
        func roundTrips<T: LosslessStringConvertible & Equatable>(_ value: T) -> Bool {
            T(value.description) == value
        }
        for hex: HEXColor in ["#FF8000", "#FF800080", "#00000000", "#000000", "#ABCDEF01"] {
            XCTAssertTrue(roundTrips(hex), hex.description)
        }
        // Strings that aren't literals use the failable initializer
        let invalid = "nope"
        XCTAssertNil(HEXColor(invalid))
        let valid = "#F80"
        XCTAssertEqual(HEXColor(valid)?.rawValue, 0xFF8800FF)
        // Literals stay non-optional, falling back to black when invalid
        let literal: HEXColor = HEXColor("#FF8000")
        XCTAssertEqual(literal, orange)
    }

    func testCSSColorIsLosslessStringConvertible() throws {
        func roundTrips<T: LosslessStringConvertible & Equatable>(_ value: T) -> Bool {
            T(value.description) == value
        }
        for string in ["rebeccapurple", "#FF8000", "rgb(255 128 0 / 50%)", "oklch(0.7 0.15 250)", "color(display-p3 1 0 0)"] {
            let color = try XCTUnwrap(CSSColor(decoding: string))
            XCTAssertTrue(roundTrips(color), string)
        }
        // Written colors round trip too, though they keep the exact color they were written from
        XCTAssertTrue(roundTrips(orange.toCSSColor(.oklch)))
        // Strings that aren't literals use the failable initializer
        let invalid = "nope"
        XCTAssertNil(CSSColor(invalid))
        let valid = "tomato"
        XCTAssertEqual(CSSColor(valid)?.toHEXColor(), "#FF6347")
    }
}
