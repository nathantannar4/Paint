//
// Copyright (c) Nathan Tannar
//

import XCTest
import SwiftUI
#if canImport(CoreImage)
import CoreImage
#endif
@testable import Paint

/// Tests ``ColorTransform``: applying, concatenating and interpolating transforms, and converting colors to transforms.
final class ColorTransformTests: XCTestCase {

    func testApplyingIdentityColorTransform() {
        let rgba = RGBAColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.8)
        assertEqual(rgba.applying(ColorTransform()), rgba)
        assertEqual(HEXColor("#336699CC").applying(ColorTransform()), HEXColor("#336699CC").toRGBAColor())
    }

    func testApplyingColorTransform() {
        // Swap red and blue, invert green, and halve alpha with an offset
        var transform = ColorTransform()
        transform.r1 = 0; transform.r3 = 1
        transform.b1 = 1; transform.b3 = 0
        transform.g2 = -1; transform.g5 = 1
        transform.a4 = 0.5; transform.a5 = 0.25
        let rgba = RGBAColor(red: 0.25, green: 0.75, blue: 0.5, alpha: 1)
        assertEqual(
            rgba.applying(transform),
            RGBAColor(red: 0.5, green: 0.25, blue: 0.25, alpha: 0.75)
        )

        // Every input contributes to every output
        var mixing = ColorTransform()
        mixing.r2 = 0.5
        mixing.g4 = 0.25
        mixing.b5 = -0.125
        mixing.a1 = 0.5
        assertEqual(
            rgba.applying(mixing),
            RGBAColor(red: 0.625, green: 1.0, blue: 0.375, alpha: 1.125)
        )
    }

    func testApplyingColorTransformPreservesExtendedRange() {
        var transform = ColorTransform()
        transform.r1 = 2
        transform.g5 = -1
        let result = RGBAColor(red: 0.75, green: 0.5, blue: 0.5).applying(transform)
        assertEqual(result, RGBAColor(red: 1.5, green: -0.5, blue: 0.5, alpha: 1))
    }

    func testColorTransformMemberwiseInit() {
        XCTAssertEqual(ColorTransform(r1: 1), ColorTransform())

        let transform = ColorTransform(
            r1: 1, r2: 2, r3: 3, r4: 4, r5: 5,
            g1: 6, g2: 7, g3: 8, g4: 9, g5: 10,
            b1: 11, b2: 12, b3: 13, b4: 14, b5: 15,
            a1: 16, a2: 17, a3: 18, a4: 19, a5: 20
        )
        let values = [
            transform.r1, transform.r2, transform.r3, transform.r4, transform.r5,
            transform.g1, transform.g2, transform.g3, transform.g4, transform.g5,
            transform.b1, transform.b2, transform.b3, transform.b4, transform.b5,
            transform.a1, transform.a2, transform.a3, transform.a4, transform.a5,
        ]
        XCTAssertEqual(values, (1...20).map(Float.init))

        // Omitted values are the identity's
        var expected = ColorTransform()
        expected.g4 = 0.5
        expected.b5 = -1
        XCTAssertEqual(ColorTransform(g4: 0.5, b5: -1), expected)
    }

    func testToColorTransform() throws {
        let tint = RGBAColor(red: 0.5, green: 0.25, blue: 1, alpha: 0.75)
        XCTAssertEqual(tint.toColorTransform(), ColorTransform(r1: 0.5, g2: 0.25, b3: 1, a4: 0.75))
        XCTAssertEqual(tint.toHEXColor().toColorTransform(), HEXColor(tint).toColorTransform())
        XCTAssertEqual(RGBAColor(red: 1, green: 1, blue: 1).toColorTransform(), ColorTransform())

        // Multiplies each component, like `colorMultiply(_:)`
        let rgba = RGBAColor(red: 0.8, green: 0.6, blue: 0.4, alpha: 1)
        assertEqual(
            rgba.applying(tint.toColorTransform()),
            RGBAColor(red: 0.4, green: 0.15, blue: 0.4, alpha: 0.75)
        )

        if #available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *) {
            XCTAssertEqual(tint.toColorTransform(), ColorTransform(color: Color(tint), in: EnvironmentValues()))
        }
    }

    func testColorTransformConcatenation() throws {
        let lhs = ColorTransform(r1: 2, r5: 1, g1: 1, g2: 0, g5: 0.5)
        let rhs = ColorTransform(r1: 3, r5: 5, b2: 0.5, a3: 0.25)
        let rgba = RGBAColor(red: 0.25, green: 0.5, blue: 0.75, alpha: 1)

        // `lhs * rhs` applies `rhs` and then `lhs`
        assertEqual(rgba.applying(lhs * rhs), rgba.applying(rhs).applying(lhs))
        XCTAssertEqual(ColorTransform() * lhs, lhs)
        XCTAssertEqual(lhs * ColorTransform(), lhs)

        if #available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *) {
            // Matches SwiftUI's own concatenation
            XCTAssertEqual(lhs * rhs, ColorTransform(lhs.toSwiftUI() * rhs.toSwiftUI()))
            XCTAssertEqual(rhs * lhs, ColorTransform(rhs.toSwiftUI() * lhs.toSwiftUI()))
        }

        var concatenated = lhs
        concatenated *= rhs
        XCTAssertEqual(concatenated, lhs * rhs)
    }

    func testColorTransformVectorArithmetic() {
        let lhs = ColorTransform(r1: 2, r5: 1, g1: 1, g2: 0, g5: 0.5)
        let rhs = ColorTransform(r1: 3, r5: 5, b2: 0.5, a3: 0.25)

        // `zero` is the additive identity, not the identity transform
        XCTAssertEqual(lhs + .zero, lhs)
        XCTAssertEqual(lhs - lhs, .zero)
        XCTAssertNotEqual(ColorTransform.zero, .identity)

        XCTAssertEqual((lhs + rhs).r1, 5)
        XCTAssertEqual((lhs + rhs).r5, 6)
        var sum = lhs
        sum += rhs
        sum -= rhs
        XCTAssertEqual(sum, lhs)

        var scaled = lhs
        scaled.scale(by: 2)
        XCTAssertEqual(scaled, lhs + lhs)

        XCTAssertEqual(ColorTransform.identity.magnitudeSquared, 4)
        XCTAssertEqual(ColorTransform.zero.magnitudeSquared, 0)
        XCTAssertEqual(lhs.animatableData, lhs)
    }

    func testTintColorTransform() {
        // Tinting with white is grayscale, using the W3C luminance weights
        let rgba = RGBAColor(red: 0.9, green: 0.2, blue: 0.1, alpha: 0.5)
        let luminance = 0.213 * rgba.red + 0.715 * rgba.green + 0.072 * rgba.blue
        assertEqual(
            rgba.applying(.tint(RGBAColor(red: 1, green: 1, blue: 1))),
            RGBAColor(red: luminance, green: luminance, blue: luminance, alpha: 0.5),
            accuracy: 1e-6
        )

        // Luminance maps from black to the tint, and alpha is multiplied
        let tint = RGBAColor(red: 1, green: 0.5, blue: 0.25, alpha: 0.8)
        let transform = ColorTransform.tint(tint)
        assertEqual(RGBAColor(red: 1, green: 1, blue: 1).applying(transform), tint, accuracy: 1e-6)
        assertEqual(RGBAColor(red: 0, green: 0, blue: 0, alpha: 0.5).applying(transform), RGBAColor(red: 0, green: 0, blue: 0, alpha: 0.4), accuracy: 1e-6)
        assertEqual(
            rgba.applying(transform),
            RGBAColor(red: luminance, green: luminance * 0.5, blue: luminance * 0.25, alpha: 0.4),
            accuracy: 1e-6
        )

        // Works with any color model
        XCTAssertEqual(ColorTransform.tint(HEXColor("#FF8040CC")), .tint(HEXColor("#FF8040CC").toRGBAColor()))
    }

    @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
    func testColorTransformRoundTripsThroughSwiftUI() throws {
        var transform = ColorTransform()
        let keyPaths: [WritableKeyPath<ColorTransform, Float>] = [
            \.r1, \.r2, \.r3, \.r4, \.r5,
            \.g1, \.g2, \.g3, \.g4, \.g5,
            \.b1, \.b2, \.b3, \.b4, \.b5,
            \.a1, \.a2, \.a3, \.a4, \.a5,
        ]
        for (index, keyPath) in keyPaths.enumerated() {
            transform[keyPath: keyPath] = Float(index + 1)
        }
        XCTAssertEqual(ColorTransform(transform.toSwiftUI()), transform)
        XCTAssertEqual(ColorTransform().toSwiftUI(), _ColorMatrix())
    }

    @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
    func testApplyingColorTransformFromColorMatchesMultiply() throws {
        // A transform derived from a color multiplies by its gamma encoded components
        let tint = RGBAColor(red: 0.5, green: 0.25, blue: 1, alpha: 1)
        let transform = ColorTransform(color: Color(tint), in: EnvironmentValues())
        let rgba = RGBAColor(red: 0.8, green: 0.6, blue: 0.4, alpha: 1)
        assertEqual(
            rgba.applying(transform),
            RGBAColor(red: 0.4, green: 0.15, blue: 0.4, alpha: 1),
            accuracy: 1e-6
        )
        XCTAssertEqual(Color(tint).toColorTransform(in: EnvironmentValues()), transform)
    }

    #if os(macOS)
    @available(macOS 11.0, *)
    func testNSColorToColorTransform() throws {
        let tint = RGBAColor(red: 0.5, green: 0.25, blue: 1, alpha: 0.75)
        XCTAssertEqual(NSColor(tint).toColorTransform(), tint.toColorTransform())

        let dynamic = NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .black : .white
        }
        let aqua = try XCTUnwrap(NSAppearance(named: .aqua))
        let darkAqua = try XCTUnwrap(NSAppearance(named: .darkAqua))
        // Gray colors convert to sRGB at `Float` precision
        assertEqual(dynamic.toColorTransform(for: aqua), .identity)
        assertEqual(dynamic.toColorTransform(for: darkAqua), ColorTransform(r1: 0, g2: 0, b3: 0))
    }
    #elseif os(iOS) || os(tvOS) || os(visionOS)
    func testUIColorToColorTransform() throws {
        let tint = RGBAColor(red: 0.5, green: 0.25, blue: 1, alpha: 0.75)
        XCTAssertEqual(UIColor(tint).toColorTransform(), tint.toColorTransform())

        let dynamic = UIColor { $0.userInterfaceStyle == .dark ? .black : .white }
        assertEqual(dynamic.toColorTransform(compatibleWith: UITraitCollection(userInterfaceStyle: .light)), .identity)
        assertEqual(
            dynamic.toColorTransform(compatibleWith: UITraitCollection(userInterfaceStyle: .dark)),
            ColorTransform(r1: 0, g2: 0, b3: 0)
        )
    }
    #endif
}
