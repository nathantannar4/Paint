//
// Copyright (c) Nathan Tannar
//

import XCTest
import SwiftUI
#if canImport(CoreImage)
import CoreImage
#endif
@testable import Paint

/// Tests the `Codable` formats of types without a color model test. Color models are tested in `ColorModelTests`.
final class CodableTests: XCTestCase {

    func testColorGradientDecodingSortsStops() throws {
        let gradient = ColorGradient(stops: [
            .init(color: RGBAColor(red: 0, green: 0, blue: 1), location: 0),
            .init(color: RGBAColor(red: 1, green: 0, blue: 0), location: 1),
        ])
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(gradient)) as? [String: Any])
        json["stops"] = (json["stops"] as? [Any]).map { Array($0.reversed()) }
        let decoded = try JSONDecoder().decode(ColorGradient.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(decoded, gradient)
        XCTAssertEqual(decoded.stops.map(\.location), [0, 1])
    }

    func testColorTransformCodable() throws {
        try assertRoundTrips(ColorTransform.identity)
        try assertRoundTrips(ColorTransform.zero)
        try assertRoundTrips(ColorTransform.tint(HEXColor("#FF8040CC")))

        // Every factor and offset is encoded by name
        let json = try assertRoundTrips(ColorTransform(r1: 0.5, r5: 0.25, g1: 2, a4: 0.75))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Double])
        let keys = ["r", "g", "b", "a"].flatMap { row in (1...5).map { "\(row)\($0)" } }
        XCTAssertEqual(Set(object.keys), Set(keys))
        XCTAssertEqual(object["r1"], 0.5)
        XCTAssertEqual(object["r5"], 0.25)
        XCTAssertEqual(object["g1"], 2)
        XCTAssertEqual(object["g2"], 1)
        XCTAssertEqual(object["a4"], 0.75)

        // Values outside `0...1`, such as offsets and negative factors, are preserved
        try assertRoundTrips(ColorTransform(r1: -1, r5: 1, g2: -1, g5: 1, b3: -1, b5: 1))

        // Every value is required
        var missing = object
        missing["b3"] = nil
        let missingJSON = String(decoding: try JSONSerialization.data(withJSONObject: missing), as: UTF8.self)
        XCTAssertThrowsError(try decode(ColorTransform.self, missingJSON))
    }

    func testAPCAContrastCodable() throws {
        XCTAssertEqual(try assertRoundTrips(APCAContrast(rawValue: -63.5)), "-63.5")
        XCTAssertEqual(try assertRoundTrips(APCAContrast(rawValue: 0)), "0")
        XCTAssertEqual(try decode(APCAContrast.self, "75"), 75)
        XCTAssertEqual(try decode([APCAContrast].self, "[90, -60.5]"), [90, -60.5])
        XCTAssertThrowsError(try decode(APCAContrast.self, #""Lc 75""#))

        // A measured contrast round trips exactly
        try assertRoundTrips(HEXColor("#336699").contrast(.apca).against(HEXColor("#F2F2F7")))
    }

    func testColorGamutCodable() throws {
        XCTAssertEqual(try assertRoundTrips(ColorGamut.sRGB), #""sRGB""#)
        XCTAssertEqual(try assertRoundTrips(ColorGamut.displayP3), #""displayP3""#)
        XCTAssertEqual(try assertRoundTrips(ColorGamut.rec2020), #""rec2020""#)
        XCTAssertThrowsError(try decode(ColorGamut.self, #""adobeRGB""#))
        XCTAssertThrowsError(try decode(ColorGamut.self, "0"))
    }

    func testColorProminenceCodable() throws {
        for prominence in ColorProminence.allCases {
            XCTAssertEqual(try assertRoundTrips(prominence), "\"\(prominence.rawValue)\"")
        }
        XCTAssertEqual(try decode(ColorProminence.self, #""tertiary""#), .tertiary)
        XCTAssertThrowsError(try decode(ColorProminence.self, #""Primary""#))
    }
}
