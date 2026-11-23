//
// Copyright (c) Nathan Tannar
//

import SwiftUI
import ImageIO
import Paint

// MARK: - Page layout

/// A scrolling page of sections, for one area of the API.
struct DemoPage<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                content
            }
            .padding()
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

/// A titled group within a page, with an optional caption naming the APIs it shows.
struct DemoSection<Content: View>: View {
    var title: String
    var caption: String?
    @ViewBuilder var content: Content

    init(_ title: String, caption: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.caption = caption
        self.content = content()
    }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                if let caption {
                    Text(caption)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text(title)
                .font(.headline)
        }
    }
}

// MARK: - Swatches

/// A rounded rectangle filled with a color, with an optional label drawn in black or
/// white, whichever reads better on the color (`contrast(.apca).isDark`), and its RGB
/// components where they fit.
struct Swatch<C: ColorConvertible>: View {
    var color: C
    var label: String?
    var detail: String?
    var height: CGFloat = 56

    init(_ color: C, label: String? = nil, detail: String? = nil, height: CGFloat = 56) {
        self.color = color
        self.label = label
        self.detail = detail
        self.height = height
    }

    var body: some View {
        let rgba = color.toRGBAColor()
        ZStack(alignment: .bottomLeading) {
            Checkerboard()
            Rectangle()
                // `ColorStyle` is a `ShapeStyle` for any `ColorConvertible` color
                .fill(ColorStyle(color: color))
            VStack(alignment: .leading, spacing: 1) {
                if let label {
                    Text(label)
                        .font(.caption.weight(.semibold))
                }
                if let detail {
                    Text(detail)
                        .font(.caption.weight(.medium))
                }
                Text(color.toHEXColor().toString(includePrefix: true))
                    .font(.caption2.monospacedDigit())

                Text(components(of: rgba))
                    .font(.caption2.monospacedDigit())
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundStyle(textColor(on: rgba))
            .padding(6)
        }
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.quaternary)
        }
    }

    /// The gamma encoded sRGB components, such as `0.95 0.45 0.20`, and the alpha when
    /// translucent. Colors outside sRGB have components outside `0...1`.
    private func components(of rgba: RGBAColor) -> String {
        let rgb = format(rgba.red, rgba.green, rgba.blue, digits: 2)
        return rgba.alpha < 1 ? "\(rgb) / \(format(rgba.alpha, 2))" : rgb
    }

    private func textColor(on rgba: RGBAColor) -> Color {
        // Translucent colors are drawn over a light checkerboard
        let opaque = rgba.composited(over: RGBAColor(red: 0.9, green: 0.9, blue: 0.9))
        return opaque.contrast(.apca).isDark ? .white : .black
    }
}

/// A row of swatches that share the available width.
struct SwatchRow<C: ColorConvertible>: View {
    var colors: [C]
    var labels: [String]?
    var height: CGFloat = 44

    var body: some View {
        HStack(spacing: 4) {
            ForEach(colors.indices, id: \.self) { index in
                Swatch(colors[index], label: labels?[index], height: height)
            }
        }
    }
}

/// A checkerboard, drawn behind translucent colors.
struct Checkerboard: View {
    var size: CGFloat = 8

    var body: some View {
        Canvas { context, canvasSize in
            context.fill(Path(CGRect(origin: .zero, size: canvasSize)), with: .color(Color(white: 0.95)))
            let columns = Int(canvasSize.width / size) + 1
            let rows = Int(canvasSize.height / size) + 1
            var path = Path()
            for row in 0..<rows {
                for column in 0..<columns where (row + column).isMultiple(of: 2) {
                    path.addRect(CGRect(x: CGFloat(column) * size, y: CGFloat(row) * size, width: size, height: size))
                }
            }
            context.fill(path, with: .color(Color(white: 0.8)))
        }
    }
}

// MARK: - Controls

/// A `ColorPicker` that edits an ``RGBAColor``, through `CGColor`.
///
/// `toCGColor()` and `CGColor.toRGBAColor()` keep wide gamut colors, so Display P3
/// colors picked in the system picker aren't clipped to sRGB.
struct ColorField: View {
    var title: String
    @Binding var color: RGBAColor
    var supportsOpacity = false

    init(_ title: String, color: Binding<RGBAColor>, supportsOpacity: Bool = false) {
        self.title = title
        self._color = color
        self.supportsOpacity = supportsOpacity
    }

    var body: some View {
        ColorPicker(
            selection: Binding(
                get: { color.toCGColor() },
                set: { color = $0.toRGBAColor() ?? color }
            ),
            supportsOpacity: supportsOpacity
        ) {
            HStack {
                Text(title)
                Spacer()
                Text(color.toHEXColor().toString(includePrefix: true))
                    .font(.body.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// A labeled slider with its value.
struct LabeledSlider: View {
    var title: String
    @Binding var value: Double
    var range: ClosedRange<Double>
    var digits = 2

    init(_ title: String, value: Binding<Double>, in range: ClosedRange<Double>, digits: Int = 2) {
        self.title = title
        self._value = value
        self.range = range
        self.digits = digits
    }

    var body: some View {
        HStack {
            Text(title)
                .frame(minWidth: 110, alignment: .leading)
            Slider(value: $value, in: range)
            Text(format(value, digits))
                .font(.body.monospacedDigit())
                .frame(minWidth: 56, alignment: .trailing)
        }
    }
}

/// A name and a monospaced value, for listing computed values.
struct ValueRow: View {
    var name: String
    var value: String

    init(_ name: String, _ value: String) {
        self.name = name
        self.value = value
    }

    var body: some View {
        GridRow {
            Text(name)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize()
                .gridColumnAlignment(.leading)
            Text(value)
                .font(.callout.monospaced())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .textSelection(.enabled)
                .gridColumnAlignment(.leading)
        }
    }
}

/// A pass or fail badge, such as for a contrast level.
struct Badge: View {
    var title: String
    var passes: Bool

    var body: some View {
        Label(title, systemImage: passes ? "checkmark.circle.fill" : "xmark.circle")
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(passes ? Color.green : Color.secondary)
            .background(.quaternary.opacity(0.5), in: Capsule())
    }
}

/// Lays out views in rows, wrapping onto a new row when one is full.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(width: proposal.width ?? .infinity, subviews: subviews)
        let width = rows.map { row in row.reduce(0) { $0 + $1.width } + spacing * CGFloat(max(row.count - 1, 0)) }.max() ?? 0
        let height = rows.map { $0.map(\.height).max() ?? 0 }.reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var index = 0
        var y = bounds.minY
        for row in rows(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            let height = row.map(\.height).max() ?? 0
            for size in row {
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
                index += 1
            }
            y += height + spacing
        }
    }

    private func rows(width: CGFloat, subviews: Subviews) -> [[CGSize]] {
        var rows: [[CGSize]] = [[]]
        var x: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, !rows[rows.count - 1].isEmpty {
                rows.append([])
                x = 0
            }
            rows[rows.count - 1].append(size)
            x += size.width + spacing
        }
        return rows
    }
}

// MARK: - Formatting

func format(_ value: Double, _ digits: Int = 3) -> String {
    guard value.isFinite else { return value.description }
    // Tiny negative values, such as floating point error, would round to "-0.00"
    let scale = pow(10, Double(digits))
    let rounded = (value * scale).rounded() / scale
    return (rounded == 0 ? 0 : rounded).formatted(.number.precision(.fractionLength(digits)))
}

func format(_ values: Double..., digits: Int = 3) -> String {
    values.map { format($0, digits) }.joined(separator: "  ")
}

extension ColorGamut {
    static let all: [ColorGamut] = [.sRGB, .displayP3, .rec2020]

    var title: String {
        switch self {
        case .sRGB: "sRGB"
        case .displayP3: "Display P3"
        case .rec2020: "Rec. 2020"
        }
    }
}

extension String {
    /// `"splitComplementary"` as `"Split Complementary"`.
    init<T: RawRepresentable>(title value: T) where T.RawValue == String {
        var result = ""
        for character in value.rawValue {
            if character.isUppercase, !result.isEmpty {
                result.append(" ")
            }
            result.append(result.isEmpty ? Character(character.uppercased()) : character)
        }
        self = result
    }
}

// MARK: - Sample images

/// The images used by the unit tests, bundled with the example from
/// `Tests/PaintTests/Resources/Images`.
enum SampleImage: String, CaseIterable, Identifiable, Hashable {
    case greatWave = "great-wave"
    case monaLisa = "mona-lisa"
    case starryNight = "starry-night"
    case sunflowers
    case blueMarble = "blue-marble"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .greatWave: "The Great Wave"
        case .monaLisa: "Mona Lisa"
        case .starryNight: "The Starry Night"
        case .sunflowers: "Sunflowers"
        case .blueMarble: "The Blue Marble"
        }
    }

    var artist: String {
        switch self {
        case .greatWave: "Hokusai"
        case .monaLisa: "Leonardo da Vinci"
        case .starryNight: "Vincent van Gogh"
        case .sunflowers: "Vincent van Gogh"
        case .blueMarble: "Apollo 17"
        }
    }

    var cgImage: CGImage? {
        Self.images[self]
    }

    /// The file of the image in the app bundle.
    var url: URL? {
        Bundle.main.url(forResource: rawValue, withExtension: "jpg")
    }

    private static let images: [SampleImage: CGImage] = {
        var images: [SampleImage: CGImage] = [:]
        for image in allCases {
            guard
                let url = Bundle.main.url(forResource: image.rawValue, withExtension: "jpg"),
                let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
            else {
                continue
            }
            images[image] = cgImage
        }
        return images
    }()
}

/// Draws a sample image, scaled to fit.
struct SampleImageView: View {
    var image: SampleImage
    var contentMode: ContentMode = .fit

    var body: some View {
        if let cgImage = image.cgImage {
            Image(decorative: cgImage, scale: 1)
                .resizable()
                .aspectRatio(contentMode: contentMode)
        } else {
            ContentUnavailableView("Missing \(image.rawValue).jpg", systemImage: "photo")
        }
    }
}

/// A horizontal picker of sample image thumbnails.
struct SampleImagePicker: View {
    @Binding var selection: SampleImage

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SampleImage.allCases) { image in
                    Button {
                        selection = image
                    } label: {
                        SampleImageView(image: image, contentMode: .fill)
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(selection == image ? Color.accentColor : .clear, lineWidth: 3)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(image.title)
                }
            }
        }
    }
}
