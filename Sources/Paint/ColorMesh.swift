//
// Copyright (c) Nathan Tannar
//

import SwiftUI

/// A two dimensional gradient: a grid of colored points, interpolated in a
/// perceptual color space, for SwiftUI's `MeshGradient`.
///
/// `MeshGradient` blends between neighboring points in gamma encoded sRGB, or in its
/// own perceptual space, so the area between distant hues turns gray or shifts hue.
/// ``toMeshGradient(subdivisions:background:smoothsColors:)`` adds points between the
/// ones of the mesh, with colors interpolated in ``space``, like ``ColorGradient``
/// does for linear gradients, so the mesh looks as intended.
///
/// ```swift
/// let mesh = ColorMesh(width: 2, height: 2, colors: [
///     HEXColor("#FF5E3A"), HEXColor("#FF9500"),
///     HEXColor("#5856D6"), HEXColor("#34AADC"),
/// ])
/// mesh.toMeshGradient()
/// ```
///
/// ``ambient(colors:width:height:jitter:seed:in:)`` generates an organic mesh from a
/// few colors, such as the swatches of an album cover, see ``init(swatches:width:height:jitter:seed:)``.
@frozen
public struct ColorMesh: Hashable, Sendable, Codable {

    /// The number of columns of points.
    public var width: Int

    /// The number of rows of points.
    public var height: Int

    /// The location of each point in unit coordinates, where `(0, 0)` is the top
    /// leading corner and `(1, 1)` the bottom trailing one, row by row.
    public var points: [SIMD2<Double>]

    /// The color of each point, row by row.
    public var colors: [RGBAColor]

    /// The color space the colors are interpolated in.
    public var space: ColorInterpolationSpace

    /// The direction hues are interpolated in polar spaces, such as
    /// ``ColorInterpolationSpace/oklch``.
    public var hue: HueInterpolation

    /// Creates a mesh from the location and color of each point, row by row.
    ///
    /// `width` and `height` are clamped to at least `2`. Missing points are evenly
    /// spaced, and missing colors repeat the last one, so the mesh is always complete.
    public init<C: ColorConvertible>(
        width: Int,
        height: Int,
        points: [SIMD2<Double>],
        colors: [C],
        in space: ColorInterpolationSpace = .oklab,
        hue: HueInterpolation = .shorter
    ) {
        let width = max(width, 2)
        let height = max(height, 2)
        let count = width * height
        let grid = Self.grid(width: width, height: height)
        let colors = colors.map { $0.toRGBAColor() }
        let fallback = colors.last ?? RGBAColor(red: 0, green: 0, blue: 0, alpha: 0)
        self.width = width
        self.height = height
        self.points = (0..<count).map { $0 < points.count ? points[$0] : grid[$0] }
        self.colors = (0..<count).map { $0 < colors.count ? colors[$0] : fallback }
        self.space = space
        self.hue = hue
    }

    /// Creates a mesh with evenly spaced points, from the color of each point, row by row.
    public init<C: ColorConvertible>(
        width: Int,
        height: Int,
        colors: [C],
        in space: ColorInterpolationSpace = .oklab,
        hue: HueInterpolation = .shorter
    ) {
        self.init(width: width, height: height, points: [], colors: colors, in: space, hue: hue)
    }

    private enum CodingKeys: String, CodingKey {
        case width
        case height
        case points
        case colors
        case space
        case hue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Through the initializer, so a mesh with missing points is completed
        try self.init(
            width: container.decode(Int.self, forKey: .width),
            height: container.decode(Int.self, forKey: .height),
            points: container.decodeIfPresent([SIMD2<Double>].self, forKey: .points) ?? [],
            colors: container.decode([RGBAColor].self, forKey: .colors),
            in: container.decodeIfPresent(ColorInterpolationSpace.self, forKey: .space) ?? .oklab,
            hue: container.decodeIfPresent(HueInterpolation.self, forKey: .hue) ?? .shorter
        )
    }

    /// Evenly spaced points, row by row.
    static func grid(width: Int, height: Int) -> [SIMD2<Double>] {
        (0..<height).flatMap { row in
            (0..<width).map { column in
                SIMD2(Double(column) / Double(width - 1), Double(row) / Double(height - 1))
            }
        }
    }

    /// The color at a location within the grid, where `column` and `row` can be
    /// fractional, such as `0.5` for halfway between the first and second column.
    ///
    /// Colors are interpolated in ``space``, first along each row, then between
    /// rows. Locations outside the grid are clamped.
    public func color(column: Double, row: Double) -> RGBAColor {
        let column = column.isNaN ? 0 : column.clamped(to: 0...Double(width - 1))
        let row = row.isNaN ? 0 : row.clamped(to: 0...Double(height - 1))
        let i = min(Int(column), width - 2)
        let j = min(Int(row), height - 2)
        let u = column - Double(i)
        let v = row - Double(j)
        func at(_ i: Int, _ j: Int) -> RGBAColor { colors[j * width + i] }
        let top = at(i, j).interpolated(to: at(i + 1, j), by: u, in: space, hue: hue)
        let bottom = at(i, j + 1).interpolated(to: at(i + 1, j + 1), by: u, in: space, hue: hue)
        return top.interpolated(to: bottom, by: v, in: space, hue: hue)
    }

    /// The location of a point within the grid, where `column` and `row` can be
    /// fractional, interpolated bilinearly between the neighboring points.
    func point(column: Double, row: Double) -> SIMD2<Double> {
        let i = min(Int(column), width - 2)
        let j = min(Int(row), height - 2)
        let u = column - Double(i)
        let v = row - Double(j)
        func at(_ i: Int, _ j: Int) -> SIMD2<Double> { points[j * width + i] }
        let top = at(i, j) + (at(i + 1, j) - at(i, j)) * u
        let bottom = at(i, j + 1) + (at(i + 1, j + 1) - at(i, j + 1)) * u
        return top + (bottom - top) * v
    }

    /// The mesh with `factor - 1` points added between each pair of neighboring
    /// points, with colors interpolated in ``space``.
    ///
    /// A mesh of `width` columns becomes `(width - 1) * factor + 1` columns. Added
    /// points are placed bilinearly between the original ones, so a mesh with
    /// distorted points bends a little less between them. `factor` is clamped to
    /// `1...16`, and `1` returns the mesh unchanged.
    public func subdivided(by factor: Int) -> ColorMesh {
        let factor = min(max(factor, 1), 16)
        guard factor > 1 else { return self }
        let newWidth = (width - 1) * factor + 1
        let newHeight = (height - 1) * factor + 1
        var points: [SIMD2<Double>] = []
        var colors: [RGBAColor] = []
        points.reserveCapacity(newWidth * newHeight)
        colors.reserveCapacity(newWidth * newHeight)
        for row in 0..<newHeight {
            for column in 0..<newWidth {
                let gridColumn = Double(column) / Double(factor)
                let gridRow = Double(row) / Double(factor)
                if column % factor == 0, row % factor == 0 {
                    let index = (row / factor) * width + column / factor
                    points.append(self.points[index])
                    colors.append(self.colors[index])
                } else {
                    points.append(point(column: gridColumn, row: gridRow))
                    colors.append(color(column: gridColumn, row: gridRow))
                }
            }
        }
        return ColorMesh(width: newWidth, height: newHeight, points: points, colors: colors, in: space, hue: hue)
    }

    /// A SwiftUI `MeshGradient` that draws the mesh, with points added by
    /// ``subdivided(by:)`` so its colors are interpolated in ``space``.
    ///
    /// The default of `4` subdivisions is close to exact for most meshes. Use `1` to
    /// let SwiftUI interpolate between the original points.
    @available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    public func toMeshGradient(
        subdivisions: Int = 4,
        background: Color = .clear,
        smoothsColors: Bool = true
    ) -> MeshGradient {
        let mesh = subdivided(by: subdivisions)
        return MeshGradient(
            width: mesh.width,
            height: mesh.height,
            points: mesh.points.map { SIMD2<Float>(Float($0.x), Float($0.y)) },
            colors: mesh.colors.map { $0.toColor() },
            background: background,
            smoothsColors: smoothsColors,
            colorSpace: .device
        )
    }
}

// MARK: - Generation

extension ColorMesh {

    /// An organic, ambient mesh from a few colors, such as a backdrop behind an album
    /// cover or the swatches of a brand.
    ///
    /// Each point takes one of `colors`, chosen so that neighboring points differ
    /// where there are enough colors, and points inside the mesh are moved by up to
    /// `jitter`, as a fraction of the spacing between points, so the mesh looks
    /// hand made rather than a grid. Points on the edges only move along their edge,
    /// so the mesh always covers its bounds.
    ///
    /// The same `seed` always gives the same mesh, so a view looks the same on every
    /// launch; use another seed for another arrangement.
    public static func ambient<C: ColorConvertible>(
        colors: [C],
        width: Int = 3,
        height: Int = 3,
        jitter: Double = 0.3,
        seed: UInt64 = 0,
        in space: ColorInterpolationSpace = .oklab
    ) -> ColorMesh {
        let width = max(width, 2)
        let height = max(height, 2)
        let palette = colors.map { $0.toRGBAColor() }
        guard !palette.isEmpty else {
            return ColorMesh(width: width, height: height, colors: [RGBAColor](), in: space)
        }
        var generator = MeshRandomNumberGenerator(seed: seed)
        var indices: [Int] = []
        for row in 0..<height {
            for column in 0..<width {
                var avoid: Set<Int> = []
                if column > 0 { avoid.insert(indices[indices.count - 1]) }
                if row > 0 { avoid.insert(indices[indices.count - width]) }
                let options = (0..<palette.count).filter { !avoid.contains($0) }
                let choices = options.isEmpty ? Array(0..<palette.count) : options
                indices.append(choices[Int(generator.next() % UInt64(choices.count))])
            }
        }
        let jitter = jitter.isNaN ? 0 : jitter.clamped(to: 0...0.45)
        let spacing = SIMD2(1 / Double(width - 1), 1 / Double(height - 1))
        var points = grid(width: width, height: height)
        for row in 0..<height {
            for column in 0..<width {
                func offset() -> Double {
                    (Double(generator.next() >> 11) * 0x1p-53 * 2 - 1) * jitter
                }
                let index = row * width + column
                let dx = offset() * spacing.x
                let dy = offset() * spacing.y
                if column > 0, column < width - 1 {
                    points[index].x += dx
                }
                if row > 0, row < height - 1 {
                    points[index].y += dy
                }
            }
        }
        return ColorMesh(width: width, height: height, points: points, colors: indices.map { palette[$0] }, in: space)
    }

    /// An ambient mesh of variations around one color: the color itself, with
    /// neighboring hues and lighter and darker versions, see
    /// ``ambient(colors:width:height:jitter:seed:in:)``.
    ///
    /// `hueSpread` is how far the hues reach either side of the color, and the
    /// variations are fitted to `gamut`.
    public static func ambient<C: ColorConvertible>(
        around color: C,
        hueSpread: ColorHue = .degrees(30),
        width: Int = 3,
        height: Int = 3,
        jitter: Double = 0.3,
        seed: UInt64 = 0,
        in gamut: ColorGamut = .displayP3
    ) -> ColorMesh {
        let base = color.toOKLCHColor()
        func variation(hue: Double, lightness: Double, chroma: Double) -> RGBAColor {
            var color = base
            color.hue = base.hue + ColorHue(degrees: hueSpread.degrees * hue)
            color.lightness = (base.lightness + lightness).clamped(to: 0...1)
            color.chroma = max(base.chroma * chroma, 0)
            return color.toColorGamut(gamut).toRGBAColor()
        }
        let colors = [
            base.toColorGamut(gamut).toRGBAColor(),
            variation(hue: -1, lightness: 0.06, chroma: 1),
            variation(hue: 1, lightness: -0.06, chroma: 1.1),
            variation(hue: -0.5, lightness: -0.12, chroma: 0.9),
            variation(hue: 0.5, lightness: 0.12, chroma: 0.8),
        ]
        return ambient(colors: colors, width: width, height: height, jitter: jitter, seed: seed, in: .oklab)
    }

    /// An ambient mesh from the swatches of an image, such as a backdrop behind its
    /// album cover, see ``ambient(colors:width:height:jitter:seed:in:)``.
    ///
    /// The vibrant and muted swatches are used, or the dominant color when the image
    /// has none.
    public init(
        swatches: ImageColorSwatches,
        width: Int = 3,
        height: Int = 3,
        jitter: Double = 0.3,
        seed: UInt64 = 0
    ) {
        let colors = [
            swatches.vibrant,
            swatches.darkVibrant,
            swatches.muted,
            swatches.lightVibrant,
            swatches.darkMuted,
            swatches.lightMuted,
        ].compactMap { $0 }
        self = Self.ambient(colors: colors.isEmpty ? [swatches.dominant] : colors, width: width, height: height, jitter: jitter, seed: seed)
    }
}

/// SplitMix64, a small deterministic generator, so meshes are the same on every
/// platform and launch.
struct MeshRandomNumberGenerator: RandomNumberGenerator {
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
