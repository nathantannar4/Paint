//
// Copyright (c) Nathan Tannar
//

import SwiftUI
import Observation
import Paint

/// The prominent colors and swatches of the sample images.
struct ImageColorsDemo: View {

    @State private var image = SampleImage.greatWave
    @State private var quality = QualityOption.high
    @State private var source = Source.url
    // Finds the colors independently of the view's lifetime, so going back to the list
    // doesn't cancel the work
    @State private var model = ImageColorsModel()

    /// How the colors are found, to show each API.
    enum Source: String, CaseIterable, Identifiable {
        case cgImage
        case url
        case combine

        var id: String { rawValue }

        var title: String {
            switch self {
            case .cgImage: "CGImage"
            case .url: "File URL"
            case .combine: "Combine"
            }
        }

        var caption: String {
            switch self {
            case .cgImage:
                "await cgImage.toColorPalette(quality:) reads the decoded image concurrently, off the main actor."
            case .url:
                "await ImageColorPalette(contentsOf:quality:) decodes the file at the scaled size, so the full image is never in memory."
            case .combine:
                "cgImage.toColorPalettePublisher(quality:) finds the colors on a global queue when subscribed to. Here it's read with .values."
            }
        }
    }

    struct Result: Equatable {
        /// The image, quality and source the colors were found for.
        var id: TaskID
        var palette: ImageColorPalette?
        var swatches: ImageColorSwatches?
        var candidates: [ImageColorDecoder.Candidate]
        var duration: Duration
    }

    /// The result for the current options, or `nil` while it's being found, so the
    /// colors of one image are never shown with another.
    private var currentResult: Result? {
        model.result?.id == taskID ? model.result : nil
    }

    private var taskID: TaskID {
        TaskID(image: image, quality: quality, source: source)
    }

    enum QualityOption: String, CaseIterable, Identifiable {
        case low
        case medium
        case high
        case lossless

        var id: String { rawValue }

        var title: String {
            switch self {
            case .low: ".low"
            case .medium: ".medium"
            case .high: ".high"
            case .lossless: ".lossless"
            }
        }

        var quality: ImageColorPalette.Quality {
            switch self {
            case .low: .low
            case .medium: .medium
            case .high: .high
            case .lossless: .lossless
            }
        }
    }

    var body: some View {
        DemoPage("Image Colors") {
            DemoSection(
                "Image",
                caption: "toColorPalette(quality:) and toColorSwatches(quality:) are available on CGImage, UIImage, NSImage and file URLs, with async and Combine variants. Quality scales the image down first: .low is at most 50 pixels, .medium 100, .high 250, and .lossless reads every pixel."
            ) {
                SampleImagePicker(selection: $image)
                Picker("Quality", selection: $quality) {
                    ForEach(QualityOption.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Source", selection: $source) {
                    ForEach(Source.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Text(source.caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if image.cgImage == nil || image.url == nil {
                    Label("\(image.rawValue).jpg isn't in the app bundle", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                } else if let result = currentResult {
                    Text("Found in \(result.duration.formatted(.units(allowed: [.milliseconds], fractionalPart: .show(length: 1))))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }
            }

            if let palette = currentResult?.palette {
                DemoSection(
                    "ImageColorPalette",
                    caption: "A background, and primary, secondary and detail colors with enough APCA contrast to read on it, like Apple Music's album colors."
                ) {
                    card(palette)
                    HStack(spacing: 4) {
                        Swatch(palette.background, label: "background")
                        Swatch(palette.primary, label: "primary")
                        Swatch(palette.secondary, label: "secondary")
                        Swatch(palette.detail, label: "detail")
                    }
                }
            }

            if let swatches = currentResult?.swatches {
                DemoSection(
                    "ImageColorSwatches",
                    caption: "Vibrant and muted swatches at three lightnesses, like Android's Palette. Swatches the image doesn't have are nil."
                ) {
                    let items: [(String, RGBAColor?)] = [
                        ("dominant", swatches.dominant),
                        ("vibrant", swatches.vibrant),
                        ("lightVibrant", swatches.lightVibrant),
                        ("darkVibrant", swatches.darkVibrant),
                        ("muted", swatches.muted),
                        ("lightMuted", swatches.lightMuted),
                        ("darkMuted", swatches.darkMuted),
                    ]
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 6)], spacing: 6) {
                        ForEach(items.indices, id: \.self) { index in
                            let (name, color) = items[index]
                            if let color {
                                Swatch(color, label: name, height: 64)
                            } else {
                                Text("\(name)\nnil")
                                    .font(.caption)
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, minHeight: 64)
                                    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                        }
                    }
                }
            }
            if let candidates = currentResult?.candidates, !candidates.isEmpty {
                DemoSection(
                    "ImageColorDecoder",
                    caption: "ImageColorDecoder.candidates(in:quality:) and candidates(contentsOf:quality:) group similar pixels by the top 5 bits of each channel, most common first: \(candidates.count) groups here. The palette and swatches are chosen from these groups. Text colors must contrast with the background, so they're usually far down the list."
                ) {
                    let total = candidates.reduce(0) { $0 + $1.count }
                    // Lazy, since lossless images can have thousands of groups
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 4)], spacing: 4) {
                        ForEach(Array(candidates.enumerated()), id: \.element.key) { rank, candidate in
                            Swatch(
                                candidate.color,
                                label: "#\(rank + 1) · \(candidate.count) px",
                                detail: "\(format(Double(candidate.count) / Double(total) * 100, 2))%",
                                height: 52
                            )
                        }
                    }
                }
            }
        }
        .onChange(of: taskID, initial: true) {
            model.load(taskID)
        }
    }

    struct TaskID: Equatable {
        var image: SampleImage
        var quality: QualityOption
        var source: Source
    }

    /// The image on its background color, with text in the palette's colors.
    private func card(_ palette: ImageColorPalette) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 20) {
                SampleImageView(image: image)
                    .frame(maxWidth: 240, maxHeight: 240)
                    .shadow(radius: 8)
                cardText(palette)
                Spacer(minLength: 0)
            }
            VStack(alignment: .leading, spacing: 16) {
                SampleImageView(image: image)
                    .frame(maxHeight: 240)
                    .frame(maxWidth: .infinity)
                    .shadow(radius: 8)
                cardText(palette)
            }
        }
        .padding(20)
        .background(Color(palette.background), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func cardText(_ palette: ImageColorPalette) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(image.title)
                .font(.title2.weight(.bold))
                .foregroundStyle(Color(palette.primary))
            Text(image.artist)
                .font(.headline)
                .foregroundStyle(Color(palette.secondary))
            Text("Primary \(palette.primary.contrast(.apca).against(palette.background).description)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(Color(palette.detail))
        }
    }
}

/// Finds the colors of a sample image for ``ImageColorsDemo``.
///
/// The work runs in the model's own task rather than the view's `task(id:)`, which
/// SwiftUI cancels when the view disappears, such as when going back to the list, and
/// doesn't always restart. Requesting other options cancels the work for the previous
/// ones, and results are kept with the options they were found for, so a late result
/// is never shown for other options.
@MainActor
@Observable
final class ImageColorsModel {

    private(set) var result: ImageColorsDemo.Result?

    @ObservationIgnored private var loading: ImageColorsDemo.TaskID?
    @ObservationIgnored private var task: Task<Void, Never>?

    /// Finds the colors for options, unless they're already found or being found.
    func load(_ id: ImageColorsDemo.TaskID) {
        guard result?.id != id, loading != id else { return }
        task?.cancel()
        loading = id
        task = Task {
            let result = await Self.colors(for: id)
            // Newer options replaced these while they were found
            guard loading == id else { return }
            self.result = result
            loading = nil
        }
    }

    /// Finds the palette, swatches and candidates of a sample image, off the main actor.
    @concurrent
    private static func colors(for id: ImageColorsDemo.TaskID) async -> ImageColorsDemo.Result {
        let quality = id.quality.quality
        let clock = ContinuousClock()
        let start = clock.now
        let palette: ImageColorPalette?
        let swatches: ImageColorSwatches?
        let candidates: [ImageColorDecoder.Candidate]
        switch id.source {
        case .cgImage:
            let cgImage = id.image.cgImage
            // The async variants always run off the main actor
            palette = await cgImage?.toColorPalette(quality: quality)
            swatches = await cgImage?.toColorSwatches(quality: quality)
        case .url:
            if let url = id.image.url {
                palette = await ImageColorPalette(contentsOf: url, quality: quality)
                swatches = await ImageColorSwatches(contentsOf: url, quality: quality)
            } else {
                palette = nil
                swatches = nil
            }
        case .combine:
            let cgImage = id.image.cgImage
            palette = await cgImage?.toColorPalettePublisher(quality: quality).values.first { _ in true } ?? nil
            swatches = await cgImage?.toColorSwatchesPublisher(quality: quality).values.first { _ in true } ?? nil
        }
        let duration = clock.now - start
        // The color groups both are chosen from, decoded the same way, so the palette
        // and swatch colors are among them
        switch id.source {
        case .url:
            candidates = id.image.url.flatMap { ImageColorDecoder.candidates(contentsOf: $0, quality: quality) } ?? []
        case .cgImage, .combine:
            candidates = id.image.cgImage.flatMap { ImageColorDecoder.candidates(in: $0, quality: quality) } ?? []
        }
        return ImageColorsDemo.Result(id: id, palette: palette, swatches: swatches, candidates: candidates, duration: duration)
    }
}

#Preview {
    NavigationStack { ImageColorsDemo() }
}
