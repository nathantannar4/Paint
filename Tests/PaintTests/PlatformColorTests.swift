//
// Copyright (c) Nathan Tannar
//

import XCTest
import SwiftUI
#if canImport(CoreImage)
import CoreImage
#endif
@testable import Paint

/// Tests `UIColor`, `NSColor` and `CGColor` conversions, and transforming dynamic colors.
final class PlatformColorTests: XCTestCase {

    #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
    func testPlatformColorFromEachModel() throws {
        func check<C: ColorConvertible>(_ color: C) throws {
            let rgba = try XCTUnwrap(PlatformColor(color).toRGBAColor(), "\(color)")
            assertEqual(rgba, color.toRGBAColor(), accuracy: 1e-12)
        }
        for color in platformColorCases {
            try check(color)
        }
        XCTAssertEqual(PlatformColor(HEXColor("#FF8000")).toRGBAColor()?.toHEXColor(), "#FF8000")
    }

    func testPlatformColorMatchesHueInitializer() throws {
        // Apple's HSB initializer also converts to RGB, so both paths should agree exactly
        for hue in stride(from: 0.0, to: 1.0, by: 0.05) {
            for saturation in stride(from: 0.0, through: 1.0, by: 0.1) {
                for brightness in stride(from: 0.0, through: 1.0, by: 0.1) {
                    let hsba = HSBAColor(hue: ColorHue(rawValue: hue), saturation: saturation, brightness: brightness, alpha: 0.5)
                    let expected = PlatformColor(hue: hue, saturation: saturation, brightness: brightness, alpha: 0.5)
                    assertEqual(
                        try XCTUnwrap(PlatformColor(hsba).toRGBAColor()),
                        try XCTUnwrap(expected.toRGBAColor()),
                        accuracy: 1e-12
                    )
                }
            }
        }
        // Including out of range components, which neither path clamps
        let hsba = HSBAColor(hue: .degrees(180), saturation: 1.5, brightness: 1.2)
        assertEqual(
            try XCTUnwrap(PlatformColor(hsba).toRGBAColor()),
            RGBAColor(red: -0.6, green: 1.2, blue: 1.2),
            accuracy: 1e-12
        )
    }

    func testPlatformColorToEachModel() throws {
        let rgba = RGBAColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.8)
        let converted = try XCTUnwrap(PlatformColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.8).toRGBAColor())
        assertEqual(converted, rgba, accuracy: 1e-12)
        XCTAssertEqual(converted.toHEXColor(), rgba.toHEXColor())
        assertEqual(converted.toHSBAColor().toRGBAColor(), rgba, accuracy: 1e-12)
        assertEqual(converted.toHSLAColor().toRGBAColor(), rgba, accuracy: 1e-12)
        assertEqual(converted.toOKLCHColor().toRGBAColor(), rgba, accuracy: 1e-6)

        // Out of gamut colors keep extended components
        let extended = PlatformColor(RGBAColor(red: 1.2, green: -0.1, blue: 0.5))
        assertEqual(try XCTUnwrap(extended.toRGBAColor()), RGBAColor(red: 1.2, green: -0.1, blue: 0.5), accuracy: 1e-12)

        // Other color spaces are converted to sRGB
        let white = try XCTUnwrap(PlatformColor(white: 1, alpha: 0.5).toRGBAColor())
        assertEqual(white, RGBAColor(red: 1, green: 1, blue: 1, alpha: 0.5), accuracy: 1e-6)

        // Display P3 converts to extended sRGB
        let p3Green = try XCTUnwrap(PlatformColor(displayP3Red: 0, green: 1, blue: 0, alpha: 1).toRGBAColor())
        assertEqual(p3Green, RGBAColor(red: -0.5116, green: 1.0183, blue: -0.3107), accuracy: 1e-3)
    }

    func testPlatformColorHueMatchesNative() throws {
        let platformColor = PlatformColor(hue: 0.3, saturation: 0.6, brightness: 0.7, alpha: 1)
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        platformColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        let hsba = try XCTUnwrap(platformColor.toRGBAColor()).toHSBAColor()
        XCTAssertEqual(hsba.hue.rawValue, Double(hue), accuracy: 1e-9)
        XCTAssertEqual(hsba.saturation, Double(saturation), accuracy: 1e-9)
        XCTAssertEqual(hsba.brightness, Double(brightness), accuracy: 1e-9)
    }

    #if !os(watchOS)
    func testPlatformColorUnconvertible() {
        #if os(macOS)
        let pattern = NSColor(patternImage: NSImage(size: CGSize(width: 1, height: 1)))
        #else
        let pattern = UIColor(patternImage: UIImage())
        #endif
        XCTAssertNil(pattern.toRGBAColor())
    }
    #endif
    #endif

    #if os(macOS)
    @available(macOS 11.0, *)
    func testNSColorDynamic() throws {
        let dynamic = NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .black : .white
        }
        let aqua = try XCTUnwrap(NSAppearance(named: .aqua))
        let darkAqua = try XCTUnwrap(NSAppearance(named: .darkAqua))
        assertEqual(try XCTUnwrap(dynamic.toRGBAColor(for: aqua)), RGBAColor(red: 1, green: 1, blue: 1), accuracy: 1e-6)
        assertEqual(try XCTUnwrap(dynamic.toRGBAColor(for: darkAqua)), RGBAColor(red: 0, green: 0, blue: 0), accuracy: 1e-6)
    }
    #elseif os(iOS) || os(tvOS) || os(visionOS)
    func testUIColorDynamic() throws {
        let dynamic = UIColor { $0.userInterfaceStyle == .dark ? .black : .white }
        assertEqual(
            try XCTUnwrap(dynamic.toRGBAColor(compatibleWith: UITraitCollection(userInterfaceStyle: .light))),
            RGBAColor(red: 1, green: 1, blue: 1),
            accuracy: 1e-6
        )
        assertEqual(
            try XCTUnwrap(dynamic.toRGBAColor(compatibleWith: UITraitCollection(userInterfaceStyle: .dark))),
            RGBAColor(red: 0, green: 0, blue: 0),
            accuracy: 1e-6
        )
    }
    #endif

    // MARK: - Transforming Resolved Colors

    #if os(macOS)
    @available(macOS 11.0, *)
    func testNSColorTransformed() throws {
        let dynamic = NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(RGBAColor(red: 0.2, green: 0.2, blue: 0.2))
                : NSColor(RGBAColor(red: 0.8, green: 0.8, blue: 0.8))
        }
        let aqua = try XCTUnwrap(NSAppearance(named: .aqua))
        let darkAqua = try XCTUnwrap(NSAppearance(named: .darkAqua))

        // The transform is applied to the color resolved for each appearance
        let inverted = dynamic.transformed { $0.applying(ColorTransform(r1: -1, r5: 1, g2: -1, g5: 1, b3: -1, b5: 1)) }
        assertEqual(try XCTUnwrap(inverted.toRGBAColor(for: aqua)), RGBAColor(red: 0.2, green: 0.2, blue: 0.2), accuracy: 1e-6)
        assertEqual(try XCTUnwrap(inverted.toRGBAColor(for: darkAqua)), RGBAColor(red: 0.8, green: 0.8, blue: 0.8), accuracy: 1e-6)

        let lightened = dynamic.transformed { $0.lightened(by: 0.1) }
        for appearance in [aqua, darkAqua] {
            let base = try XCTUnwrap(dynamic.toRGBAColor(for: appearance))
            assertEqual(try XCTUnwrap(lightened.toRGBAColor(for: appearance)), base.lightened(by: 0.1).toRGBAColor(), accuracy: 1e-6)
        }

        // Both colors are resolved for the same appearance
        let mixed = dynamic.transformed(with: .labelColor) { $0.mixed(with: $1, by: 0.5) }
        for appearance in [aqua, darkAqua] {
            let base = try XCTUnwrap(dynamic.toRGBAColor(for: appearance))
            let label = try XCTUnwrap(NSColor.labelColor.toRGBAColor(for: appearance))
            assertEqual(try XCTUnwrap(mixed.toRGBAColor(for: appearance)), base.mixed(with: label, by: 0.5).toRGBAColor(), accuracy: 1e-6)
        }
    }
    #elseif os(iOS) || os(tvOS) || os(visionOS)
    func testUIColorTransformed() throws {
        let dynamic = UIColor {
            $0.userInterfaceStyle == .dark
                ? UIColor(RGBAColor(red: 0.2, green: 0.2, blue: 0.2))
                : UIColor(RGBAColor(red: 0.8, green: 0.8, blue: 0.8))
        }
        let light = UITraitCollection(userInterfaceStyle: .light)
        let dark = UITraitCollection(userInterfaceStyle: .dark)

        // The transform is applied to the color resolved for each trait collection
        let inverted = dynamic.transformed { $0.applying(ColorTransform(r1: -1, r5: 1, g2: -1, g5: 1, b3: -1, b5: 1)) }
        assertEqual(try XCTUnwrap(inverted.toRGBAColor(compatibleWith: light)), RGBAColor(red: 0.2, green: 0.2, blue: 0.2), accuracy: 1e-6)
        assertEqual(try XCTUnwrap(inverted.toRGBAColor(compatibleWith: dark)), RGBAColor(red: 0.8, green: 0.8, blue: 0.8), accuracy: 1e-6)

        let lightened = dynamic.transformed { $0.lightened(by: 0.1) }
        for traits in [light, dark] {
            let base = try XCTUnwrap(dynamic.toRGBAColor(compatibleWith: traits))
            assertEqual(try XCTUnwrap(lightened.toRGBAColor(compatibleWith: traits)), base.lightened(by: 0.1).toRGBAColor(), accuracy: 1e-6)
        }

        // Both colors are resolved for the same trait collection
        let mixed = dynamic.transformed(with: .label) { $0.mixed(with: $1, by: 0.5) }
        for traits in [light, dark] {
            let base = try XCTUnwrap(dynamic.toRGBAColor(compatibleWith: traits))
            let label = try XCTUnwrap(UIColor.label.toRGBAColor(compatibleWith: traits))
            assertEqual(try XCTUnwrap(mixed.toRGBAColor(compatibleWith: traits)), base.mixed(with: label, by: 0.5).toRGBAColor(), accuracy: 1e-6)
        }

        // Pattern colors resolve unchanged
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { _ in }
        let pattern = UIColor(patternImage: image)
        XCTAssertNil(pattern.transformed { $0.lightened(by: 0.1) }.toRGBAColor(compatibleWith: light))
    }
    #endif

    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    func testColorTransformed() throws {
        // Adaptive colors are transformed after resolving in the environment
        for color in [Color.primary, .red, .blue] {
            let darkened = color.transformed { $0.darkened(by: 0.1) }
            for environment in [lightEnvironment, darkEnvironment] {
                assertEqual(
                    darkened.resolve(in: environment).toRGBAColor(in: environment),
                    color.toRGBAColor(in: environment).darkened(by: 0.1).toRGBAColor(),
                    accuracy: 1e-5
                )
            }
        }

        // The environment beyond the color scheme is used, such as increased contrast
        var increased = lightEnvironment
        increased._colorSchemeContrast = .increased
        assertEqual(
            Color.blue.transformed { $0 }.resolve(in: increased).toRGBAColor(in: increased),
            Color.blue.toRGBAColor(in: increased),
            accuracy: 1e-6
        )

        // Static colors resolve to the same transform in every environment
        let rgba = RGBAColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.8)
        let tinted = Color(rgba).transformed { $0.applying(.tint(HEXColor("#FF8000"))) }
        for environment in [lightEnvironment, darkEnvironment] {
            assertEqual(
                tinted.resolve(in: environment).toRGBAColor(in: environment),
                rgba.applying(.tint(HEXColor("#FF8000"))),
                accuracy: 1e-6
            )
        }

        // Both colors are resolved in the same environment
        let mixed = Color.orange.transformed(with: .primary) { $0.mixed(with: $1, by: 0.5) }
        for environment in [lightEnvironment, darkEnvironment] {
            let expected = Color.orange.toRGBAColor(in: environment)
                .mixed(with: Color.primary.toRGBAColor(in: environment), by: 0.5)
                .toRGBAColor()
            assertEqual(mixed.resolve(in: environment).toRGBAColor(in: environment), expected, accuracy: 1e-5)
        }
    }

    #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
    @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
    func testConversionMethods() throws {
        func check<C: ColorConvertible>(_ color: C) throws {
            let rgba = color.toRGBAColor()
            #if os(macOS)
            let platformColor = color.toNSColor()
            #else
            let platformColor = color.toUIColor()
            #endif
            assertEqual(try XCTUnwrap(platformColor.toRGBAColor(), "\(color)"), rgba, accuracy: 1e-12)
            assertEqual(try XCTUnwrap(color.toCGColor().toRGBAColor(), "\(color)"), rgba, accuracy: 1e-12)
            // SwiftUI stores `Float` components
            assertEqual(try XCTUnwrap(color.toColor().toRGBAColor(), "\(color)"), rgba, accuracy: 1e-6)
            XCTAssertEqual(color.toColor(), Color(color))
        }
        for color in platformColorCases {
            try check(color)
        }
    }
    #endif
}
