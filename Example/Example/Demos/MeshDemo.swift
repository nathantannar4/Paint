//
// Copyright (c) Nathan Tannar
//

import SwiftUI
import Paint

/// Mesh gradients interpolated in perceptual color spaces, and generated ambient meshes.
struct MeshDemo: View {

    var body: some View {
        if #available(iOS 18.0, macOS 15.0, *) {
            MeshDemoContent()
        } else {
            ContentUnavailableView("Requires iOS 18 or macOS 15", systemImage: "square.grid.3x3.fill", description: Text("MeshGradient is new in iOS 18 and macOS 15."))
        }
    }
}

@available(iOS 18.0, macOS 15.0, *)
private struct MeshDemoContent: View {

    @State private var topLeading = RGBAColor(red: 0, green: 0.2, blue: 1)
    @State private var topTrailing = RGBAColor(red: 1, green: 0.9, blue: 0)
    @State private var bottomLeading = RGBAColor(red: 1, green: 0, blue: 0.4)
    @State private var bottomTrailing = RGBAColor(red: 0, green: 0.8, blue: 0.53)
    @State private var space = ColorInterpolationSpace.oklab
    @State private var subdivisions = 4.0

    @State private var seed = 0
    @State private var jitter = 0.3
    @State private var size = 3.0
    @State private var aroundColor = RGBAColor(red: 0.23, green: 0.51, blue: 0.96)
    @State private var hueSpread = 30.0
    @State private var image = SampleImage.starryNight
    // Kept by image, so the mesh always shows the swatches of the selected image
    // rather than whichever image was found last
    @State private var swatches: [SampleImage: ImageColorSwatches] = [:]

    private var mesh: ColorMesh {
        ColorMesh(width: 2, height: 2, colors: [topLeading, topTrailing, bottomLeading, bottomTrailing], in: space)
    }

    var body: some View {
        DemoPage("Mesh Gradients") {
            DemoSection(
                "Interpolation",
                caption: "MeshGradient blends between points in sRGB, so blue to yellow passes through gray. ColorMesh.toMeshGradient(subdivisions:) adds points in between, with colors interpolated in a ColorInterpolationSpace, such as Oklab or OKLCH."
            ) {
                ColorField("Top leading", color: $topLeading)
                ColorField("Top trailing", color: $topTrailing)
                ColorField("Bottom leading", color: $bottomLeading)
                ColorField("Bottom trailing", color: $bottomTrailing)
                Picker("Space", selection: $space) {
                    ForEach(ColorInterpolationSpace.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                Stepper("Subdivisions: \(Int(subdivisions))", value: $subdivisions, in: 1...8)
                HStack(spacing: 8) {
                    meshView(mesh.toMeshGradient(subdivisions: 1), title: "MeshGradient")
                    meshView(mesh.toMeshGradient(subdivisions: Int(subdivisions)), title: "toMeshGradient()")
                }
            }

            DemoSection(
                "Ambient Meshes",
                caption: "ColorMesh.ambient(colors:width:height:jitter:seed:) arranges a few colors so neighbors differ, and moves the points inside the mesh by up to jitter. The same seed always gives the same mesh."
            ) {
                LabeledSlider("Jitter", value: $jitter, in: 0...0.45)
                Stepper("Size: \(Int(size)) × \(Int(size))", value: $size, in: 2...6)
                HStack {
                    Stepper("Seed: \(seed)", value: $seed, in: 0...1000)
                }
                let colors: [HEXColor] = ["#FF5E3A", "#FF9500", "#5856D6", "#34AADC", "#FF2D55"]
                SwatchRow(colors: colors, height: 28)
                meshView(
                    ColorMesh.ambient(colors: colors, width: Int(size), height: Int(size), jitter: jitter, seed: UInt64(seed)).toMeshGradient(),
                    title: "ambient(colors:)",
                    height: 220
                )
            }

            DemoSection(
                "Around a Color",
                caption: "ColorMesh.ambient(around:hueSpread:) builds the colors from one color: neighboring hues, and lighter and darker versions."
            ) {
                ColorField("Color", color: $aroundColor)
                LabeledSlider("Hue spread (°)", value: $hueSpread, in: 0...90, digits: 0)
                meshView(
                    ColorMesh.ambient(around: aroundColor, hueSpread: .degrees(hueSpread), width: Int(size), height: Int(size), jitter: jitter, seed: UInt64(seed)).toMeshGradient(),
                    title: "ambient(around:)",
                    height: 220
                )
            }

            DemoSection(
                "From an Image",
                caption: "ColorMesh(swatches:) uses the vibrant and muted ImageColorSwatches of an image, as a backdrop behind album art."
            ) {
                SampleImagePicker(selection: $image)
                ZStack {
                    if let swatches = swatches[image] {
                        ColorMesh(swatches: swatches, width: Int(size), height: Int(size), jitter: jitter, seed: UInt64(seed))
                            .toMeshGradient()
                            .id(image)
                    }
                    SampleImageView(image: image)
                        .frame(maxHeight: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .shadow(radius: 12, y: 6)
                }
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .onChange(of: image, initial: true) {
                    // In its own task rather than task(id:), which SwiftUI cancels and
                    // doesn't always restart, see ImageColorsModel
                    let image = image
                    guard swatches[image] == nil, let cgImage = image.cgImage else { return }
                    Task {
                        swatches[image] = await cgImage.toColorSwatches(quality: .low)
                    }
                }
            }
        }
    }

    private func meshView(_ gradient: MeshGradient, title: String, height: CGFloat = 180) -> some View {
        gradient
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .bottomLeading) {
                Text(title)
                    .font(.caption.monospaced().weight(.semibold))
                    .foregroundStyle(.white)
                    .shadow(radius: 2)
                    .padding(8)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    NavigationStack { MeshDemo() }
}
