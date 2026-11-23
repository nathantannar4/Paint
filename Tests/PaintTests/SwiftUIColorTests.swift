//
// Copyright (c) Nathan Tannar
//

import XCTest
import SwiftUI
#if canImport(CoreImage)
import CoreImage
#endif
@testable import Paint

/// Tests SwiftUI `Color` and `CIColor` conversions, including resolving colors in an environment.
final class SwiftUIColorTests: XCTestCase {

    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    func testSwiftUIColorFromEachModel() throws {
        func check<C: ColorConvertible>(_ color: C) throws {
            // Color.Resolved stores Float components
            assertEqual(resolve(Color(color)), color.toRGBAColor(), accuracy: 1e-6)
            // sRGB colors are backed by a CGColor, so convert without an environment
            assertEqual(try XCTUnwrap(Color(color).toRGBAColor()), color.toRGBAColor(), accuracy: 1e-6)
        }
        for color in platformColorCases {
            try check(color)
        }
    }

    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    func testSwiftUIColorToEachModel() throws {
        let rgba = RGBAColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.8)
        let color = Color(.sRGB, red: 0.2, green: 0.4, blue: 0.6, opacity: 0.8)
        let converted = try XCTUnwrap(color.toRGBAColor())
        assertEqual(converted, rgba, accuracy: 1e-6)
        XCTAssertEqual(converted.toHEXColor(), rgba.toHEXColor())
        assertEqual(converted.toHSLAColor().toRGBAColor(), rgba, accuracy: 1e-6)
        assertEqual(converted.toOKLCHColor().toRGBAColor(), rgba, accuracy: 1e-6)

        // System colors need an environment to resolve
        XCTAssertNotNil(Color.red.toRGBAColor(in: EnvironmentValues()))

        // Adaptive colors resolve for the environment
        var dark = EnvironmentValues()
        dark.colorScheme = .dark
        // `.primary` is translucent on some platforms, so only compare the color
        XCTAssertEqual(Color.primary.toRGBAColor(in: EnvironmentValues()).red, 0, accuracy: 1e-6)
        XCTAssertEqual(Color.primary.toRGBAColor(in: dark).red, 1, accuracy: 1e-6)
    }

    #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
    @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
    func testSwiftUIColorToPlatformColor() throws {
        let rgba = RGBAColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.8)
        // SwiftUI stores `Float` components
        let platformColor = PlatformColor(try XCTUnwrap(Color(rgba).toRGBAColor()))
        assertEqual(try XCTUnwrap(platformColor.toRGBAColor()), rgba, accuracy: 1e-6)
        let color = Color(try XCTUnwrap(platformColor.toRGBAColor()))
        assertEqual(try XCTUnwrap(color.toRGBAColor()), rgba, accuracy: 1e-6)
    }
    #endif

    // MARK: - CIColor

    #if canImport(CoreImage)
    func testCIColorFromEachModel() throws {
        func check<C: ColorConvertible>(_ color: C) throws {
            let rgba = color.toRGBAColor()
            assertEqual(try XCTUnwrap(color.toCIColor().toRGBAColor(), "\(color)"), rgba, accuracy: 1e-12)
            assertEqual(try XCTUnwrap(CIColor(color).toRGBAColor(), "\(color)"), rgba, accuracy: 1e-12)
        }
        for color in platformColorCases {
            try check(color)
        }
        // Out of gamut colors use extended sRGB
        let extended = RGBAColor(red: 1.2, green: -0.1, blue: 0.5).toCIColor()
        XCTAssertEqual(extended.colorSpace.name, CGColorSpace.extendedSRGB)
        XCTAssertEqual(extended.red, 1.2)
        XCTAssertEqual(extended.green, -0.1)
    }

    func testCIColorToEachModel() throws {
        let ciColor = CIColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.8)
        let rgba = RGBAColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.8)
        let converted = try XCTUnwrap(ciColor.toRGBAColor())
        // The default color space is sRGB, so components are read directly
        assertEqual(converted, rgba, accuracy: 1e-12)
        XCTAssertEqual(converted.toHEXColor(), rgba.toHEXColor())
        assertEqual(converted.toHSBAColor().toRGBAColor(), rgba, accuracy: 1e-12)
        assertEqual(converted.toHSLAColor().toRGBAColor(), rgba, accuracy: 1e-12)
        assertEqual(converted.toOKLCHColor().toRGBAColor(), rgba, accuracy: 1e-6)

        // Every 8-bit hex value round trips exactly
        for hex in hexGrid {
            XCTAssertEqual(hex.toCIColor().toRGBAColor()?.toHEXColor(), hex)
        }
    }

    func testCIColorOtherColorSpaces() throws {
        // Core Image often works in linear light, which converts with the sRGB transfer function
        let linearSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.linearSRGB))
        let linear = try XCTUnwrap(CIColor(red: 0.5, green: 0.25, blue: 0, alpha: 1, colorSpace: linearSpace))
        assertEqual(
            try XCTUnwrap(linear.toRGBAColor()),
            RGBAColor(red: RGBAColor.delinearize(0.5), green: RGBAColor.delinearize(0.25), blue: 0),
            accuracy: 1e-6
        )

        // Display P3 green is outside sRGB
        let p3Space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.displayP3))
        let p3Green = try XCTUnwrap(CIColor(red: 0, green: 1, blue: 0, alpha: 1, colorSpace: p3Space))
        assertEqual(try XCTUnwrap(p3Green.toRGBAColor()), RGBAColor(red: -0.5116, green: 1.0183, blue: -0.3107), accuracy: 1e-3)

        // Gray colors gain RGB components. Generic gray has a 2.2 gamma, so it
        // isn't the same value in sRGB, but agrees with the CGColor conversion
        let cgGray = CGColor(gray: 0.5, alpha: 0.5)
        let grayRGBA = try XCTUnwrap(CIColor(cgColor: cgGray).toRGBAColor())
        assertEqual(grayRGBA, try XCTUnwrap(cgGray.toRGBAColor()), accuracy: 1e-6)
        XCTAssertEqual(grayRGBA.red, grayRGBA.green, accuracy: 1e-6)
        XCTAssertEqual(grayRGBA.green, grayRGBA.blue, accuracy: 1e-6)
        XCTAssertEqual(grayRGBA.alpha, 0.5, accuracy: 1e-6)
    }
    #endif

    // MARK: - SwiftUI Color in an Environment

    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    func testColorInEnvironmentPrimaryLightDark() throws {
        let light = Color.primary.toRGBAColor(in: lightEnvironment)
        let dark = Color.primary.toRGBAColor(in: darkEnvironment)
        // Black text in light mode, white text in dark mode
        assertEqual(light, RGBAColor(red: 0, green: 0, blue: 0, alpha: light.alpha), accuracy: 1e-6)
        assertEqual(dark, RGBAColor(red: 1, green: 1, blue: 1, alpha: dark.alpha), accuracy: 1e-6)
        XCTAssertGreaterThan(light.alpha, 0)
        XCTAssertEqual(light.alpha, dark.alpha, accuracy: 1e-6)
        XCTAssertLessThan(light.toOKLCHColor().lightness, dark.toOKLCHColor().lightness)

        // The default environment is light
        assertEqual(Color.primary.toRGBAColor(in: EnvironmentValues()), light, accuracy: 1e-6)
    }

    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    func testColorInEnvironmentSystemColorsLightDark() throws {
        for color in [Color.red, .orange, .green, .blue, .secondary] {
            let light = color.toRGBAColor(in: lightEnvironment)
            let dark = color.toRGBAColor(in: darkEnvironment)
            XCTAssertGreaterThan(maxDifference(light, dark), 1e-3, "\(color) should adapt to the color scheme")
        }
    }

    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    func testColorInEnvironmentMatchesPlatformColor() throws {
        #if os(macOS)
        let aqua = try XCTUnwrap(NSAppearance(named: .aqua))
        let darkAqua = try XCTUnwrap(NSAppearance(named: .darkAqua))
        let pairs: [(Color, NSColor)] = [(.red, .systemRed), (.blue, .systemBlue), (.primary, .labelColor)]
        for (color, platformColor) in pairs {
            assertEqual(color.toRGBAColor(in: lightEnvironment), try XCTUnwrap(platformColor.toRGBAColor(for: aqua)), accuracy: 1e-6)
            assertEqual(color.toRGBAColor(in: darkEnvironment), try XCTUnwrap(platformColor.toRGBAColor(for: darkAqua)), accuracy: 1e-6)
        }
        #elseif os(iOS) || os(tvOS) || os(visionOS)
        let light = UITraitCollection(userInterfaceStyle: .light)
        let dark = UITraitCollection(userInterfaceStyle: .dark)
        let pairs: [(Color, UIColor)] = [(.red, .systemRed), (.blue, .systemBlue), (.primary, .label)]
        for (color, platformColor) in pairs {
            assertEqual(color.toRGBAColor(in: lightEnvironment), try XCTUnwrap(platformColor.toRGBAColor(compatibleWith: light)), accuracy: 1e-6)
            assertEqual(color.toRGBAColor(in: darkEnvironment), try XCTUnwrap(platformColor.toRGBAColor(compatibleWith: dark)), accuracy: 1e-6)
        }
        #endif
    }

    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    func testColorInEnvironmentDynamicPlatformColor() throws {
        #if os(macOS)
        let color = Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? .black : .white
        })
        #elseif os(iOS) || os(tvOS) || os(visionOS)
        let color = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? .black : .white })
        #else
        let color = Color.primary
        throw XCTSkip("Dynamic platform colors are not available")
        #endif
        let white = RGBAColor(red: 1, green: 1, blue: 1)
        let black = RGBAColor(red: 0, green: 0, blue: 0)
        assertEqual(color.toRGBAColor(in: lightEnvironment), white, accuracy: 1e-6)
        assertEqual(color.toRGBAColor(in: darkEnvironment), black, accuracy: 1e-6)

        // Opacity is applied to the resolved color
        assertEqual(color.opacity(0.5).toRGBAColor(in: lightEnvironment), RGBAColor(red: 1, green: 1, blue: 1, alpha: 0.5), accuracy: 1e-6)
        assertEqual(color.opacity(0.5).toRGBAColor(in: darkEnvironment), RGBAColor(red: 0, green: 0, blue: 0, alpha: 0.5), accuracy: 1e-6)
    }

    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    func testColorInEnvironmentStaticColors() throws {
        let rgba = RGBAColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.8)
        let cases: [(Color, RGBAColor)] = [
            (Color(rgba), rgba),
            (rgba.toColor(), rgba),
            (.white, RGBAColor(red: 1, green: 1, blue: 1)),
            (.black, RGBAColor(red: 0, green: 0, blue: 0)),
            (.clear, RGBAColor(red: 0, green: 0, blue: 0, alpha: 0)),
            (Color(rgba).opacity(0.5), RGBAColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.4)),
            // Out of gamut colors keep extended components
            (Color(.displayP3, red: 0, green: 1, blue: 0), RGBAColor(red: -0.5116, green: 1.0183, blue: -0.3107)),
        ]
        for (color, expected) in cases {
            let accuracy = expected.clamped() == expected ? 1e-6 : 1e-3
            assertEqual(color.toRGBAColor(in: lightEnvironment), expected, accuracy: accuracy)
            assertEqual(color.toRGBAColor(in: darkEnvironment), expected, accuracy: accuracy)
        }
    }

    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    func testColorInEnvironmentIncreasedContrast() throws {
        for scheme in [ColorScheme.light, .dark] {
            var standard = EnvironmentValues()
            standard.colorScheme = scheme
            var increased = standard
            increased._colorSchemeContrast = .increased
            for color in [Color.red, .blue] {
                XCTAssertGreaterThan(
                    maxDifference(color.toRGBAColor(in: standard), color.toRGBAColor(in: increased)),
                    1e-3,
                    "\(color) should adapt to increased contrast in \(scheme)"
                )
            }
        }
    }

    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    func testSwiftUIColorMatchesHueInitializer() throws {
        for hue in stride(from: 0.0, to: 1.0, by: 0.05) {
            for saturation in stride(from: 0.0, through: 1.5, by: 0.25) {
                for brightness in stride(from: 0.0, through: 1.2, by: 0.2) {
                    let hsba = HSBAColor(hue: ColorHue(rawValue: hue), saturation: saturation, brightness: brightness, alpha: 0.5)
                    let expected = Color(hue: hue, saturation: saturation, brightness: brightness, opacity: 0.5)
                    assertEqual(resolve(Color(hsba)), resolve(expected), accuracy: 1e-6)
                }
            }
        }
    }
}
