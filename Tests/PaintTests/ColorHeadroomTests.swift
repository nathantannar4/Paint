//
// Copyright (c) Nathan Tannar
//

import XCTest
import SwiftUI
import simd
@testable import Paint

/// Tests HDR headroom, and lossless conversions of wide gamut and HDR colors to and
/// from platform colors.
final class ColorHeadroomTests: XCTestCase {

    // MARK: - Headroom

    func testSDRColorsHaveNoHeadroom() {
        let colors: [RGBAColor] = [
            RGBAColor(red: 0, green: 0, blue: 0),
            RGBAColor(red: 1, green: 1, blue: 1),
            RGBAColor(red: 1, green: 0, blue: 0),
            RGBAColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.5),
            RGBAColor(red: .nan, green: 0, blue: 0),
            RGBAColor(red: .infinity, green: 0, blue: 0),
        ]
        for color in colors {
            XCTAssertEqual(color.contentHeadroom, 1, "\(color)")
            XCTAssertFalse(color.isHDR, "\(color)")
        }
    }

    func testWideGamutColorsAreNotHDR() throws {
        // Display P3 and Rec. 2020 primaries have sRGB components above `1`
        let p3Red = try XCTUnwrap(color(in: CGColorSpace.displayP3, 1, 0, 0))
        let rec2020Green = try XCTUnwrap(color(in: CGColorSpace.itur_2020, 0, 1, 0))
        for color in [p3Red, rec2020Green] {
            XCTAssertGreaterThan(max(color.red, color.green, color.blue), 1, "\(color)")
            XCTAssertFalse(color.isHDR, "\(color)")
            XCTAssertEqual(color.toStandardDynamicRange(), color)
        }
    }

    func testHDRHeadroom() {
        // sRGB `2` is about `4.95` in linear light
        let white = RGBAColor(red: 2, green: 2, blue: 2)
        XCTAssertEqual(white.contentHeadroom, RGBAColor.linearize(2), accuracy: 1e-12)
        XCTAssertTrue(white.isHDR)
        assertEqual(white.toStandardDynamicRange(), RGBAColor(red: 1, green: 1, blue: 1), accuracy: 1e-12)

        // The SDR color keeps the chromaticity, at a peak of `1`
        let orange = RGBAColor(red: 1.5, green: 0.9, blue: 0.3, alpha: 0.5)
        let sdr = orange.toStandardDynamicRange()
        XCTAssertFalse(sdr.isHDR)
        XCTAssertEqual(sdr.alpha, 0.5)
        let ratio = orange.toLinearComponents() / sdr.toLinearComponents()
        XCTAssertEqual(ratio.x, orange.contentHeadroom, accuracy: 1e-9)
        XCTAssertEqual(ratio.y, orange.contentHeadroom, accuracy: 1e-9)
        XCTAssertEqual(ratio.z, orange.contentHeadroom, accuracy: 1e-9)
    }

    func testHeadroomFloatRoundsUp() {
        for value in [1.1, 4.9530035, 1.0000001, 3] {
            XCTAssertGreaterThanOrEqual(Double(value.headroomFloat), value)
            XCTAssertEqual(Double(value.headroomFloat), value, accuracy: 1e-6)
        }
    }

    // MARK: - Double precision color spaces

    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    func testDirectConversionMatchesColorSync() throws {
        let spaces: [CFString] = [
            CGColorSpace.sRGB,
            CGColorSpace.extendedSRGB,
            CGColorSpace.linearSRGB,
            CGColorSpace.extendedLinearSRGB,
            CGColorSpace.displayP3,
            CGColorSpace.extendedDisplayP3,
            CGColorSpace.linearDisplayP3,
            CGColorSpace.extendedLinearDisplayP3,
            CGColorSpace.itur_2020,
            CGColorSpace.extendedITUR_2020,
            CGColorSpace.linearITUR_2020,
            CGColorSpace.extendedLinearITUR_2020,
        ]
        let extendedSRGB = try XCTUnwrap(CGColorSpace(name: CGColorSpace.extendedSRGB))
        for name in spaces {
            let space = try XCTUnwrap(CGColorSpace(name: name))
            let isExtended = CGColorSpaceUsesExtendedRange(space)
            for components in [[0.5, 0.25, 0.75], [1, 0, 0], [0, 1, 0], [0, 0, 1], [1, 1, 1], [0.02, 0.01, 0.03]]
                + (isExtended ? [[1.5, -0.2, 0.4], [2, 2, 2]] : [])
            {
                let cgColor = try XCTUnwrap(CGColor(colorSpace: space, components: components.map { CGFloat($0) } + [0.5]))
                let direct = try XCTUnwrap(cgColor.toDirectRGBAColor(), "\(name)")
                let converted = try XCTUnwrap(cgColor.converted(to: extendedSRGB, intent: .defaultIntent, options: nil)?.components)
                let colorSync = RGBAColor(
                    red: Double(converted[0]),
                    green: Double(converted[1]),
                    blue: Double(converted[2]),
                    alpha: Double(converted[3])
                )
                // ColorSync converts at `Float` precision, with slightly different
                // primaries, which differ most near `0`, where the sRGB curve is steepest
                assertEqual(direct, colorSync, accuracy: 5e-4)
                XCTAssertEqual(try XCTUnwrap(cgColor.toRGBAColor()), direct)
            }
        }
    }

    func testDisplayP3PrimariesAreInGamut() throws {
        // Converted at `Double` precision, P3 colors fit `.displayP3` exactly
        for components in [(1.0, 0.0, 0.0), (0, 1, 0), (0, 0, 1), (1, 1, 0), (0, 1, 1), (1, 0, 1)] {
            let color = try XCTUnwrap(color(in: CGColorSpace.displayP3, components.0, components.1, components.2))
            XCTAssertTrue(ColorGamut.displayP3.contains(color), "\(components)")
            let linear = ColorSpaceMatrix.linearSRGBToLinearDisplayP3 * color.toLinearComponents()
            // The CSS matrices are inverses to about `1e-10`
            XCTAssertEqual(linear.x, components.0, accuracy: 1e-9)
            XCTAssertEqual(linear.y, components.1, accuracy: 1e-9)
            XCTAssertEqual(linear.z, components.2, accuracy: 1e-9)
        }
    }

    @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
    func testRec2020UsesCoreGraphicsTransferFunction() throws {
        // Core Graphics' Rec. 2020 uses a pure 2.4 gamma, so `2` is `2^2.4` in linear light
        let white = try XCTUnwrap(color(in: CGColorSpace.extendedITUR_2020, 2, 2, 2))
        let expected = RGBAColor.delinearize(pow(2, 2.4))
        assertEqual(white, RGBAColor(red: expected, green: expected, blue: expected), accuracy: 1e-9)
    }

    func testUnknownColorSpacesUseColorSync() throws {
        let gray = try XCTUnwrap(CGColor(colorSpace: CGColorSpace(name: CGColorSpace.genericGrayGamma2_2)!, components: [0.5, 1]))
        XCTAssertNil(gray.toDirectRGBAColor())
        XCTAssertNotNil(gray.toRGBAColor())
    }

    #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
    func testPlatformColorReadsDisplayP3Exactly() throws {
        #if os(macOS)
        let p3 = NSColor(displayP3Red: 1, green: 0.5, blue: 0.25, alpha: 1)
        #else
        // `UIColor(displayP3Red:...)` converts to extended sRGB at `Float` precision
        // when it's created, but colors from a Display P3 `CGColor` keep it
        let cgColor = try XCTUnwrap(CGColor(
            colorSpace: try XCTUnwrap(CGColorSpace(name: CGColorSpace.displayP3)),
            components: [1, 0.5, 0.25, 1]
        ))
        let p3 = UIColor(cgColor: cgColor)
        #endif
        let expected = try XCTUnwrap(color(in: CGColorSpace.displayP3, 1, 0.5, 0.25))
        assertEqual(try XCTUnwrap(p3.toRGBAColor()), expected, accuracy: 1e-12)
    }
    #endif

    // MARK: - HDR platform colors

    private var hdrColors: [RGBAColor] {
        [
            RGBAColor(red: 2, green: 2, blue: 2),
            RGBAColor(red: 1.5, green: 0.9, blue: 0.3, alpha: 0.5),
            // Not representable as a `Float`
            RGBAColor(red: 1.2345678901234, green: 0.1, blue: 1.1),
        ]
    }

    #if XCODE_26
    @available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *)
    func testCGColorTagsHDRHeadroom() throws {
        for color in hdrColors {
            let cgColor = color.toCGColor()
            XCTAssertEqual(Double(cgColor.contentHeadroom), color.contentHeadroom, accuracy: 1e-6)
            XCTAssertGreaterThanOrEqual(Double(cgColor.contentHeadroom), color.contentHeadroom)
            XCTAssertEqual(try XCTUnwrap(cgColor.toRGBAColor()), color)
        }
        // SDR colors aren't tagged
        XCTAssertEqual(RGBAColor(red: 1, green: 0.5, blue: 0).toCGColor().contentHeadroom, 0)
    }

    #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
    @available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *)
    func testPlatformColorTagsHDRHeadroom() throws {
        for color in hdrColors {
            let platformColor = PlatformColor(color)
            XCTAssertEqual(Double(platformColor.linearExposure), color.contentHeadroom, accuracy: 1e-6)
            // Components are kept exactly, unlike the `linearExposure` initializer
            XCTAssertEqual(try XCTUnwrap(platformColor.toRGBAColor()), color)
            // The platform divides by the same headroom. AppKit then clamps to sRGB,
            // while UIKit keeps wide gamut components, like Paint
            #if os(macOS)
            let expected = color.toStandardDynamicRange().clamped()
            #else
            let expected = color.toStandardDynamicRange()
            #endif
            assertEqual(
                try XCTUnwrap(platformColor.standardDynamicRange.toRGBAColor()),
                expected,
                accuracy: 1e-5
            )
        }
        XCTAssertEqual(PlatformColor(RGBAColor(red: 1, green: 0.5, blue: 0)).linearExposure, 1)
    }
    #endif

    @available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *)
    func testSwiftUIColorTagsHDRHeadroom() throws {
        let environment = EnvironmentValues()
        for color in hdrColors {
            let resolved = Color(color).resolveHDR(in: environment)
            XCTAssertEqual(Double(try XCTUnwrap(resolved.headroom)), color.contentHeadroom, accuracy: 1e-6)
            // SwiftUI stores `Float` components
            assertEqual(Color(color).toRGBAColor(in: environment), color, accuracy: 1e-6)
            assertEqual(try XCTUnwrap(Color(color).toRGBAColor()), color, accuracy: 1e-6)
        }
        XCTAssertNil(Color(RGBAColor(red: 1, green: 0.5, blue: 0)).resolveHDR(in: environment).headroom)
    }

    // MARK: - Reading HDR colors

    #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
    @available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *)
    func testPlatformColorReadsHDR() throws {
        // The platform brightens `(1, 0.5, 0.25)` four times in linear light. AppKit
        // computes it at `Float` precision, and UIKit more coarsely, to about `1e-5`
        let base = RGBAColor(red: 1, green: 0.5, blue: 0.25)
        let expected = RGBAColor(linear: base.toLinearComponents() * 4, alpha: 1)
        let platformColor = PlatformColor(red: 1, green: 0.5, blue: 0.25, alpha: 1, linearExposure: 4)
        let rgba = try XCTUnwrap(platformColor.toRGBAColor())
        assertEqual(rgba, expected, accuracy: 1e-4)
        XCTAssertEqual(rgba.contentHeadroom, expected.contentHeadroom, accuracy: 1e-3)
        // Through SwiftUI too
        assertEqual(Color(platformColor).toRGBAColor(in: EnvironmentValues()), expected, accuracy: 1e-4)
    }
    #endif

    @available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *)
    func testSwiftUIReadsExposureAdjust() throws {
        // `resolve(in:)` clips `exposureAdjust(_:)` to SDR, while `toRGBAColor(in:)` keeps it
        let environment = EnvironmentValues()
        let base = RGBAColor(red: 1, green: 0.5, blue: 0.25)
        let brightened = base.toColor().exposureAdjust(2)
        XCTAssertEqual(brightened.resolve(in: environment).red, 1, accuracy: 1e-6)
        let rgba = brightened.toRGBAColor(in: environment)
        assertEqual(rgba, RGBAColor(linear: base.toLinearComponents() * 4, alpha: 1), accuracy: 1e-5)
        XCTAssertTrue(rgba.isHDR)
    }
    #endif

    // MARK: - Helpers

    private func color(in name: CFString, _ red: Double, _ green: Double, _ blue: Double) -> RGBAColor? {
        guard let space = CGColorSpace(name: name) else { return nil }
        return CGColor(colorSpace: space, components: [red, green, blue, 1])?.toRGBAColor()
    }
}
