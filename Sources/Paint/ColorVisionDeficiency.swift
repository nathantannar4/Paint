//
// Copyright (c) Nathan Tannar
//

import Foundation
import simd

/// A type of color vision deficiency (color blindness), for simulating how colors
/// appear and for checking that colors stay distinguishable.
///
/// Simulations use the dichromat matrices of
/// [Machado, Oliveira and Fernandes (2009)](https://www.inf.ufrgs.br/~oliveira/pubs_files/CVD_Simulation/CVD_Simulation.html).
/// Partial severities, for the anomalous trichromacies such as protanomaly, are
/// interpolated linearly between normal vision and the dichromat matrix, which
/// approximates the paper's per-severity matrices.
///
/// Encodes as its case name, such as `"deuteranopia"`.
@frozen
public enum ColorVisionDeficiency: String, Hashable, Sendable, Codable, CaseIterable, CustomStringConvertible {

    /// Missing or anomalous long-wavelength (red) cones. Reds look dark and
    /// are confused with greens. About 1% of men.
    case protanopia

    /// Missing or anomalous medium-wavelength (green) cones. Reds and greens are
    /// confused. The most common type, about 6% of men.
    case deuteranopia

    /// Missing or anomalous short-wavelength (blue) cones. Blues and greens, and
    /// yellows and pinks, are confused. Rare.
    case tritanopia

    /// No color vision: everything is seen by luminance only. Very rare.
    case achromatopsia

    /// The simulation matrix in linear light sRGB, at full severity.
    var linearMatrix: simd_double3x3 {
        switch self {
        case .protanopia:
            simd_double3x3(rows: [
                [0.152286, 1.052583, -0.204868],
                [0.114503, 0.786281, 0.099216],
                [-0.003882, -0.048116, 1.051998],
            ])
        case .deuteranopia:
            simd_double3x3(rows: [
                [0.367322, 0.860646, -0.227968],
                [0.280085, 0.672501, 0.047413],
                [-0.011820, 0.042940, 0.968881],
            ])
        case .tritanopia:
            simd_double3x3(rows: [
                [1.255528, -0.076749, -0.178779],
                [-0.078411, 0.930809, 0.147602],
                [0.004733, 0.691367, 0.303900],
            ])
        case .achromatopsia:
            simd_double3x3(rows: [
                [0.2126, 0.7152, 0.0722],
                [0.2126, 0.7152, 0.0722],
                [0.2126, 0.7152, 0.0722],
            ])
        }
    }

    /// The matrix that simulates the deficiency, applied to linear light sRGB
    /// components such as ``RGBAColor/toLinearComponents()``.
    ///
    /// `severity` is clamped to `0...1`, see ``ColorConvertible/simulating(_:severity:)``.
    /// Use this to apply the simulation elsewhere, such as in a shader.
    public func linearMatrix(severity: Double) -> simd_double3x3 {
        linearMatrix.interpolatedFromIdentity(by: severity.isNaN ? 1 : severity.clamped(to: 0...1))
    }

    /// Shifts the information lost to the deficiency into channels that are still
    /// seen, after [Fidaner, Lin and Ozguven (2005)](http://scien.stanford.edu/pages/labsite/2005/psych221/projects/05/ofidaner/colorblindness_project.htm).
    var errorShift: simd_double3x3 {
        switch self {
        case .protanopia, .deuteranopia:
            // Move red-green error into blue, and towards green and red
            simd_double3x3(rows: [[0, 0, 0], [0.7, 1, 0], [0.7, 0, 1]])
        case .tritanopia:
            // Move blue-yellow error into red and green
            simd_double3x3(rows: [[1, 0, 0.7], [0, 1, 0.7], [0, 0, 0]])
        case .achromatopsia:
            // Hue is lost entirely, so there's nothing to shift into
            simd_double3x3(rows: [[0, 0, 0], [0, 0, 0], [0, 0, 0]])
        }
    }

    /// The matrix that daltonizes colors for the deficiency, applied to linear light
    /// sRGB components such as ``RGBAColor/toLinearComponents()``.
    ///
    /// This is `I + E(I - S)`, where `S` is ``linearMatrix(severity:)`` and `E` shifts
    /// the lost information into channels that are still seen. See
    /// ``ColorConvertible/daltonized(for:severity:)``.
    public func daltonizationMatrix(severity: Double) -> simd_double3x3 {
        let simulation = linearMatrix(severity: severity)
        return matrix_identity_double3x3 + errorShift * (matrix_identity_double3x3 - simulation)
    }

    /// The raw value, such as `"deuteranopia"`.
    public var description: String {
        rawValue
    }
}

extension ColorConvertible {

    /// How the color appears with a color vision deficiency.
    ///
    /// `severity` is in `0...1`, where `1` is the complete deficiency, such as
    /// protanopia, and smaller values are anomalous trichromacy, such as protanomaly.
    /// The simulation is applied in linear light, and the result is clamped to sRGB.
    /// Alpha is kept.
    public func simulating(
        _ deficiency: ColorVisionDeficiency,
        severity: Double = 1
    ) -> RGBAColor {
        let rgba = toRGBAColor().toColorGamut(.sRGB)
        let linear = deficiency.linearMatrix(severity: severity) * rgba.toLinearComponents()
        return RGBAColor(linear: linear, alpha: rgba.alpha).clamped()
    }

    /// The color daltonized for a color vision deficiency: adjusted so that
    /// differences the deficiency hides become differences in colors that are still
    /// seen.
    ///
    /// Daltonizing makes colors easier to tell apart, at the cost of changing how
    /// they look with normal vision. It can't help with ``ColorVisionDeficiency/achromatopsia``,
    /// which returns the color unchanged. The result is clamped to sRGB.
    public func daltonized(
        for deficiency: ColorVisionDeficiency,
        severity: Double = 1
    ) -> RGBAColor {
        let rgba = toRGBAColor().toColorGamut(.sRGB)
        let linear = deficiency.daltonizationMatrix(severity: severity) * rgba.toLinearComponents()
        return RGBAColor(linear: linear, alpha: rgba.alpha).clamped()
    }
}

extension ColorTransform {

    /// A matrix that simulates a color vision deficiency, for previewing views with
    /// the `colorMatrix(_:)` view modifier.
    ///
    /// ``ColorTransform`` transforms gamma encoded components, while the simulation is
    /// defined in linear light, so this is an approximation: hues match, but some
    /// colors are slightly lighter or darker than ``ColorConvertible/simulating(_:severity:)``.
    public static func simulating(
        _ deficiency: ColorVisionDeficiency,
        severity: Double = 1
    ) -> ColorTransform {
        ColorTransform(deficiency.linearMatrix(severity: severity))

    }

    /// A matrix that daltonizes colors for a color vision deficiency, see
    /// ``ColorConvertible/daltonized(for:severity:)``.
    ///
    /// Like ``simulating(_:severity:)``, this approximates the linear light
    /// transform in gamma encoded components.
    public static func daltonizing(
        for deficiency: ColorVisionDeficiency,
        severity: Double = 1
    ) -> ColorTransform {
        ColorTransform(deficiency.daltonizationMatrix(severity: severity))

    }
}

extension simd_double3x3 {

    /// Linearly interpolates from the identity to this matrix.
    func interpolatedFromIdentity(by fraction: Double) -> simd_double3x3 {
        let identity = matrix_identity_double3x3
        return identity + fraction * (self - identity)
    }
}
