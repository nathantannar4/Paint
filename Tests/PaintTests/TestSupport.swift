//
// Copyright (c) Nathan Tannar
//

import XCTest
import SwiftUI
#if canImport(CoreImage)
import CoreImage
#endif
@testable import Paint

// MARK: - Assertions

extension XCTestCase {

    func assertEqual(
        _ lhs: ColorTransform?,
        _ rhs: ColorTransform,
        accuracy: Float = 1e-6,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let lhs else {
            return XCTFail("transform is nil", file: file, line: line)
        }
        XCTAssertLessThanOrEqual((lhs - rhs).magnitudeSquared.squareRoot(), Double(accuracy), "\(lhs) != \(rhs)", file: file, line: line)
    }

    func assertEqual(
        _ lhs: RGBAColor,
        _ rhs: RGBAColor,
        accuracy: Double = 1e-9,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(lhs.red, rhs.red, accuracy: accuracy, "red", file: file, line: line)
        XCTAssertEqual(lhs.green, rhs.green, accuracy: accuracy, "green", file: file, line: line)
        XCTAssertEqual(lhs.blue, rhs.blue, accuracy: accuracy, "blue", file: file, line: line)
        XCTAssertEqual(lhs.alpha, rhs.alpha, accuracy: accuracy, "alpha", file: file, line: line)
    }

    /// A grid of 8-bit colors spanning the sRGB cube.
    var hexGrid: [HEXColor] {
        let steps: [Double] = stride(from: 0, through: 255, by: 17).map { $0 / 255 }
        return steps.flatMap { r in
            steps.flatMap { g in
                steps.map { b in HEXColor(red: r, green: g, blue: b, alpha: 0.5) }
            }
        }
    }
}

// MARK: - Fixtures

#if os(macOS)
typealias PlatformColor = NSColor
#elseif os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
typealias PlatformColor = UIColor
#endif

extension XCTestCase {

    /// One color in each model, plus out of gamut colors that need extended sRGB.
    var platformColorCases: [any ColorConvertible] {
        let rgba = RGBAColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.8)
        return [
            HEXColor("#FF800080"),
            rgba,
            rgba.toHSBAColor(),
            rgba.toHSLAColor(),
            rgba.toOKLCHColor(),
            RGBAColor(red: 1.2, green: -0.1, blue: 0.5),
            OKLCHColor(lightness: 0.7, chroma: 0.3, hue: .degrees(150)), // Display P3 green, outside sRGB
        ]
    }

    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    func resolve(_ color: Color) -> RGBAColor {
        color.toRGBAColor(in: EnvironmentValues())
    }

    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    var lightEnvironment: EnvironmentValues {
        var environment = EnvironmentValues()
        environment.colorScheme = .light
        return environment
    }

    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    var darkEnvironment: EnvironmentValues {
        var environment = EnvironmentValues()
        environment.colorScheme = .dark
        return environment
    }

    func maxDifference(_ lhs: RGBAColor, _ rhs: RGBAColor) -> Double {
        max(abs(lhs.red - rhs.red), abs(lhs.green - rhs.green), abs(lhs.blue - rhs.blue), abs(lhs.alpha - rhs.alpha))
    }

    /// Encodes `value` with sorted keys, checks that it decodes to an equal value,
    /// and returns the JSON.
    @discardableResult
    func assertRoundTrips<T: Codable & Equatable>(
        _ value: T,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(value)
        XCTAssertEqual(try JSONDecoder().decode(T.self, from: data), value, file: file, line: line)
        return String(decoding: data, as: UTF8.self)
    }

    func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }
}

/// A deterministic random number generator, so failures are reproducible.
struct SplitMix64: RandomNumberGenerator {
    var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
