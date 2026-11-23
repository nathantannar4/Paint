//
// Copyright (c) Nathan Tannar
//

import XCTest
@testable import Paint

/// Tests ``CSSColorParser``: the byte scanner, which decodes printable ASCII, and the
/// Unicode parser, which decodes everything else.
final class CSSColorParserTests: XCTestCase {

    /// The color's components as bit patterns, so `-0.0` and `0.0` differ.
    private func bits(_ color: RGBAColor?) -> [UInt64]? {
        color.map { [$0.red, $0.green, $0.blue, $0.alpha].map(\.bitPattern) }
    }

    /// Asserts that the byte scanner and the Unicode parser decode a string the same.
    ///
    /// A trailing no-break space sends any string to the Unicode parser, which trims
    /// it, so both must decode the string to exactly the same color, or both reject it.
    private func assertScannerMatchesUnicodeParser(
        _ string: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let decoded = CSSColorParser.decode(string)
        let unicode = CSSColorParser.decode(string + "\u{00A0}")
        XCTAssertEqual(
            bits(decoded),
            bits(unicode),
            "\(string.debugDescription) decoded \(String(describing: decoded)), but \(String(describing: unicode)) through the Unicode parser",
            file: file,
            line: line
        )
    }

    // MARK: Decoding

    func testDecodesValidStrings() throws {
        let cases: [(String, HEXColor)] = [
            // HEX
            ("#FF8000", 0xFF8000FF),
            ("#ff8000", 0xFF8000FF),
            ("  #F80\n", 0xFF8800FF),
            ("#F808", 0xFF880088),
            ("#FF800080", 0xFF800080),
            // Named
            ("red", 0xFF0000FF),
            ("RED", 0xFF0000FF),
            ("Rebeccapurple", 0x663399FF),
            ("lightgoldenrodyellow", 0xFAFAD2FF),
            ("transparent", 0x00000000),
            ("TRANSPARENT", 0x00000000),
            // Syntax
            ("rgb(255 128 0)", 0xFF8000FF),
            ("RGB(255, 128, 0)", 0xFF8000FF),
            ("rgba(255,128,0,0.5)", 0xFF800080),
            ("rgb(255 128 0 / 50%)", 0xFF800080),
            ("rgb( 255 128 0 )", 0xFF8000FF),
            ("rgb (255 128 0)", 0xFF8000FF),
            ("rgb\t(255 128 0)", 0xFF8000FF),
            ("rgb(255 , 128 , 0)", 0xFF8000FF),
            ("rgb(255\n128\n0)", 0xFF8000FF),
            ("rgb(255\t128\t0)", 0xFF8000FF),
            ("rgb(none none none)", 0x000000FF),
            ("rgb(none 50% 0 / none)", 0x00800000),
            // Functions and units
            ("hsl(30 100% 50%)", 0xFF8000FF),
            ("hsl(30deg 100% 50%)", 0xFF8000FF),
            ("hsl(0.5turn 100% 50%)", 0x00FFFFFF),
            ("hsl(3.14rad 100% 50%)", 0x00FFFFFF),
            ("hsl(200grad 100% 50%)", 0x00FFFFFF),
            ("hsla(30, 100%, 50%, 0.5)", 0xFF800080),
            ("hwb(30 0% 0%)", 0xFF8000FF),
            ("lab(67 45 75)", 0xFB7F00FF),
            ("lch(67 87 58)", 0xFD7D03FF),
            ("oklab(0.73 0.11 0.15)", 0xFD8100FF),
            ("oklch(0.7 0.15 250)", 0x4BA3F7FF),
            ("OKLCH(70% 0.15 250DEG)", 0x4BA3F7FF),
            // Color spaces
            ("color(srgb 1 0.5 0)", 0xFF8000FF),
            ("color(srgb-linear 1 0.5 0)", 0xFFBC00FF),
            ("color(display-p3 1 0.5 0)", 0xFF8630FF),
            ("color(rec2020 1 0.5 0)", 0xFF9C6BFF),
            ("color(xyz 0.5 0.5 0.5)", 0xCCB7B4FF),
            ("color(xyz-d65 0.5 0.5 0.5)", 0xCCB7B4FF),
            ("color(xyz-d50 0.5 0.5 0.5 / 0.5)", 0xBEB9CF80),
            ("color( display-p3 1 0 0 )", 0xFF3428FF),
            ("color(display-p3\t1 0 0)", 0xFF3428FF),
            ("color(display-p3 1, 0, 0)", 0xFF3428FF),
            ("color(\ndisplay-p3\n1\n0\n0\n)", 0xFF3428FF),
            // Non-ASCII whitespace is trimmed by the Unicode parser
            ("red\u{00A0}", 0xFF0000FF),
            ("\u{2003}red", 0xFF0000FF),
            ("red\r\n", 0xFF0000FF),
            ("\u{0B}red\u{0C}", 0xFF0000FF),
            ("rgb(255 128 0)\u{0B}", 0xFF8000FF),
            ("color(display-p3\u{00A0}1 0 0)", 0xFF3428FF),
        ]
        for (string, hex) in cases {
            let color = try XCTUnwrap(CSSColorParser.decode(string), string.debugDescription)
            XCTAssertEqual(color.toHEXColor(), hex, string.debugDescription)
        }
        // Colors outside sRGB keep components outside `0...1`
        let p3Red = try XCTUnwrap(CSSColorParser.decode("color(display-p3 1 0 0)"))
        XCTAssertFalse(ColorGamut.sRGB.contains(p3Red))
    }

    func testRejectsInvalidStrings() {
        let strings = [
            // HEX and named
            "", "   ", "\t\n", "#", "#GGG", "#FF80000", "# FFF", "##FFF",
            "notacolor", "lightgoldenrodyellowx", "currentcolor", "🎨",
            // Syntax
            "rgb\n(255 128 0)", "rgb(255 128 0 / )", "rgb(255 128 0 / 0.5 / 1)", "rgb(255, 128, 0 / 0.5)",
            "rgb(255,128,0,0.5,1)", "rgb(255 128 0 0.5)", "rgb(25 5, 128, 0)", "rgb(255,128,\n0)",
            "rgb(255 128 0 / 0.5\n)", "rgb(255 128 0))", "rgb((255 128 0)", "rgb(255 128 0", "rgb)", ")(", "()",
            "rgb(255\r128 0)", "rgb(255\r\n128 0)", "rgb(255\u{0B}128 0)", "rgb(255\u{00A0}128 0)",
            "rgb(255 128 0)\u{0301}", "rgb(１ 2 3)",
            // Functions, color spaces and units
            "hsb(30 100% 100%)", "rgbx(1 2 3)", "rgb(1deg 2 3)", "rgb(1 2 3 / 1deg)", "hsl(50% 100% 50%)",
            "color(display-p3)", "color(display-p3,1,0,0)", "color(adobe-rgb 1 0 0)", "color(srgb 1 2 3 4)",
            // Numbers
            "color(srgb inf 0 0)", "color(srgb nan 0 0)", "color(srgb infinity 0 0)", "color(srgb 1e400 0 0)",
            "color(srgb 1e 0 0)", "color(srgb . 0 0)", "color(srgb + 0 0)", "color(srgb - 0 0)", "color(srgb ++1 0 0)",
            "color(srgb 1_0 0 0)", "color(srgb 1..2 0 0)", "color(srgb 1e1.5 0 0)",
            "color(srgb 50%% 0 0)", "color(srgb none% 0 0)", "color(srgb 1degdeg 0 0)", "color(srgb deg 0 0)",
        ]
        for string in strings {
            XCTAssertNil(CSSColorParser.decode(string), string.debugDescription)
        }
    }

    // MARK: Byte Scanner

    func testScannerMatchesUnicodeParser() {
        let strings = [
            "#FF8000", "#f80", "#F808", "#FF800080", "#GGG", "red", "RED", "transparent", "notacolor",
            "rgb(255 128 0)", "RGB(255, 128, 0)", "rgba(255,128,0,0.5)", "rgb(255 128 0 / 50%)",
            "rgb(255,,128,0)", "rgb (255 128 0)", "rgb\t(255 128 0)", "rgb\n(255 128 0)",
            "rgb(255 128 0 / 0.5\n)", "rgb(255,128,\n0)", "rgb(none 50% 0 / none)",
            "hsl(0.5turn 100% 50%)", "hsl(200grad 100% 50%)", "hsl(3.14rad 100% 50%)", "OKLCH(70% 0.15 250DEG)",
            "color(display-p3 1 0.5 0)", "color(\ndisplay-p3\n1\n0\n0\n)", "color(display-p3,1,0,0)",
            "color(srgb 0x1p3 0x10 0X1P-1)", "color(srgb 1e-400 0 0)", "color(srgb 9007199254740993 0 0)",
            "color(srgb 0.12345678901234567 0 0)", "color(srgb 000000000000000000001 0 0)",
        ]
        for string in strings {
            assertScannerMatchesUnicodeParser(string)
        }
    }

    func testScannerMatchesUnicodeParserForGeneratedStrings() {
        var random = SplitMix64(seed: 0xC0FFEE)
        func pick<T>(_ values: [T]) -> T {
            values[Int(random.next() % UInt64(values.count))]
        }
        func randomCase(_ string: String) -> String {
            String(string.map { random.next() % 4 == 0 ? Character($0.uppercased()) : $0 })
        }
        let functions = ["rgb", "rgba", "hsl", "hsla", "hwb", "lab", "lch", "oklab", "oklch", "color", "colour", "rgbb", ""]
        let spaces = ["srgb", "srgb-linear", "display-p3", "rec2020", "xyz", "xyz-d65", "xyz-d50", "p3", ""]
        // ASCII only, so that most strings take the byte scanner
        let whitespace = ["", "", " ", "  ", "\t", "\n", " \n "]
        let separators = [" ", ", ", ",", " , ", "\t", "\n", "  ", ",,", ""]
        func number() -> String {
            switch random.next() % 10 {
            case 0: return pick(["0", "1", "-0", "+1", ".5", "5.", "-.25", "100", "255", "360"])
            case 1: return pick(["1e2", "1E-2", "2.5e+1", "1e", "e1", "0x1p3", "inf", "nan", "infinity", "1e400", "-1e-400"])
            case 2: return String(Double(Int64(bitPattern: random.next()) % 1_000_000) / 1000)
            case 3: return String(Double(bitPattern: random.next() >> 2))
            case 4: return "0." + String(repeating: "0", count: Int(random.next() % 25)) + String(random.next() % 1000)
            case 5: return String(random.next() % 100_000_000_000_000_000)
            case 6: return pick([".", "-", "+", "--1", "1.2.3", "1,5", "a", "%", "deg"])
            default: return String(format: "%.\(random.next() % 8)f", Double(random.next() % 100_000) / 97)
            }
        }
        func value() -> String {
            switch random.next() % 8 {
            case 0: return number() + "%"
            case 1: return number() + randomCase(pick(["deg", "grad", "rad", "turn"]))
            case 2: return randomCase("none")
            default: return number()
            }
        }
        func function() -> String {
            let name = randomCase(pick(functions))
            var body = name.lowercased() == "color" || random.next() % 2 == 0 ? randomCase(pick(spaces)) + pick([" ", "\t", "\n", ""]) : ""
            let count = [2, 3, 3, 3, 3, 4, 5][Int(random.next() % 7)]
            let separator = pick(separators)
            let values: [String] = (0..<count).map { _ in
                let leading: String = pick(whitespace)
                let trailing: String = pick(whitespace)
                return leading + value() + trailing
            }
            body += values.joined(separator: separator)
            if random.next() % 3 == 0 {
                let slash: String = pick(["/", "/", "//", ","])
                body += pick(whitespace) as String
                body += slash
                body += pick(whitespace) as String
                body += value()
            }
            let gap: String = pick(["", "", " ", "\t"])
            let end: String = pick(["", "", " ", "\n"])
            let close: String = pick([")", ")", ")", "", "))"])
            return name + gap + "(" + body + end + close
        }
        func hex() -> String {
            let digits = String((0..<Int(random.next() % 10)).map { _ in pick(Array("0123456789abcdefABCDEFgx ")) })
            return pick(["#", "#", "##", ""]) + digits
        }
        func named() -> String {
            randomCase(pick(Array(CSSColorParser.namedColors.keys) + ["transparent", "currentcolor", "canvas"]))
        }
        var decodedCount = 0
        for _ in 0..<200_000 {
            let core: String
            switch random.next() % 10 {
            case 0: core = hex()
            case 1: core = named()
            case 2: core = String((0..<Int(random.next() % 12)).map { _ in pick(Array("rgb()/,% .-+e0123456789\t\n#")) })
            default: core = function()
            }
            let string = pick(whitespace) + core + pick(whitespace)
            assertScannerMatchesUnicodeParser(string)
            if CSSColorParser.decode(string) != nil {
                decodedCount += 1
            }
        }
        // Enough strings are colors that both paths are compared on colors, not just
        // on rejecting the same strings
        XCTAssertGreaterThan(decodedCount, 20_000)
    }

    // MARK: Numbers

    /// Asserts that a number decodes exactly as `Double(String)` parses it, through
    /// `color(srgb)`, which doesn't clamp its components.
    private func assertNumberMatchesDouble(
        _ number: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let decoded = CSSColorParser.decode("color(srgb \(number) 0 0)")
        if let expected = Double(number.lowercased()), expected.isFinite {
            XCTAssertEqual(decoded?.red.bitPattern, expected.bitPattern, number, file: file, line: line)
        } else {
            XCTAssertNil(decoded, number, file: file, line: line)
        }
    }

    func testNumbersMatchDoubleParsing() {
        let numbers = [
            "0", "-0", "+0", "1", "1.", ".5", "-.5", "+3", "1e2", "1E-2", "1e+2", "1e00001",
            "0x1p3", "0x10", "0X1P-1", "inf", "nan", "infinity", "1e", "e1", ".", "+", "-",
            "1e22", "1e23", "1e-22", "1e-23", "1e400", "1e-400",
            "0.12345678901234567", "1234567890123456789", "000000000000000000001", "0.000000000000000000000000001",
            "9007199254740993", "999999999999999", "9999999999999999", "123456789012345.6",
        ]
        for number in numbers {
            assertNumberMatchesDouble(number)
        }
    }

    func testGeneratedNumbersMatchDoubleParsing() {
        var random = SplitMix64(seed: 0xBEEF)
        for _ in 0..<200_000 {
            let digits = String(random.next() % 10_000_000_000_000_000)
            let point = Int(random.next() % UInt64(digits.count + 1))
            var number = String(digits.prefix(point)) + "." + String(digits.dropFirst(point))
            if random.next() % 3 == 0 {
                number += "e" + String(Int(random.next() % 60) - 30)
            }
            if random.next() % 2 == 0 {
                number = "-" + number
            }
            assertNumberMatchesDouble(number)
        }
    }
}
