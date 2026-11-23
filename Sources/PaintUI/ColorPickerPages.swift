//
// Copyright (c) Nathan Tannar
//

#if os(iOS) || os(visionOS)
import UIKit
import simd

import Paint

/// A page of the color picker, which edits an opaque color in a color space.
///
/// Each page keeps its own components, such as a hue, so they aren't lost when a
/// color has none, such as a gray. ``setColor(_:)`` loads the components from a color
/// chosen on another page.
///
/// Its views are laid out by frame, top to bottom, rather than by constraints. Each
/// is as wide as the page, or centered if it fits narrower, such as a wheel, and
/// as tall as it fits that width. The page's intrinsic height is the height of
/// its views at its width, so it can be arranged in a stack view.
class ColorPickerPage: UIView {

    /// Called with a new color, and whether it's still changing.
    var onChange: ((RGBAColor, Bool) -> Void)?

    /// The color space the page edits components in.
    var colorSpace: ColorSpace = .sRGB {
        didSet {
            guard colorSpace != oldValue else { return }
            colorSpaceDidChange()
        }
    }

    /// The current color.
    private(set) var color = RGBAColor(red: 0, green: 0, blue: 0)

    /// The views laid out top to bottom. Hidden views are skipped.
    private(set) var arrangedSubviews: [UIView] = []

    /// The space between views, unless set for a view by ``setCustomSpacing(_:after:)``.
    var spacing: CGFloat = 16 {
        didSet { invalidateLayout() }
    }

    private var customSpacings: [ObjectIdentifier: CGFloat] = [:]
    /// The value fields kept the width of the widest of each group.
    private var alignedFieldGroups: [[ColorValueField]] = []
    /// The width the intrinsic height was last computed for.
    private var intrinsicWidth: CGFloat?

    override init(frame: CGRect) {
        super.init(frame: frame)
        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: Self, _) in
                self.invalidateLayout()
            }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    #if !os(visionOS)
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // Before iOS 17, which observes trait changes with `registerForTraitChanges`
        if #unavailable(iOS 17.0),
           traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory {
            invalidateLayout()
        }
    }
    #endif

    // MARK: Layout

    /// Adds a view below the others.
    func addArrangedSubview(_ view: UIView) {
        arrangedSubviews.append(view)
        addSubview(view)
        invalidateLayout()
    }

    /// Sets the space below a view.
    func setCustomSpacing(_ spacing: CGFloat, after view: UIView) {
        customSpacings[ObjectIdentifier(view)] = spacing
        invalidateLayout()
    }

    /// Lays the views out again, such as when one is shown or hidden.
    func invalidateLayout() {
        invalidateIntrinsicContentSize()
        setNeedsLayout()
        // A page within a page, such as a sub-page of a menu, sizes its parent
        (superview as? ColorPickerPage)?.invalidateLayout()
    }

    override var intrinsicContentSize: CGSize {
        CGSize(
            width: UIView.noIntrinsicMetric,
            height: sizeThatFits(CGSize(width: bounds.width, height: 0)).height
        )
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let height = arrangedFrames(width: size.width).last?.frame.maxY ?? 0
        return CGSize(width: size.width, height: height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // The height depends on the width, so it's computed again for a new width
        if intrinsicWidth != bounds.width {
            intrinsicWidth = bounds.width
            invalidateIntrinsicContentSize()
        }
        for group in alignedFieldGroups {
            let width = group.map(\.fittingSize.width).max() ?? 0
            for field in group {
                field.alignmentWidth = width
            }
        }
        for (view, frame) in arrangedFrames(width: bounds.width) {
            view.frame = frame
        }
    }

    /// The frames of the visible views, for a width.
    private func arrangedFrames(width: CGFloat) -> [(view: UIView, frame: CGRect)] {
        var frames: [(view: UIView, frame: CGRect)] = []
        var y: CGFloat = 0
        for view in arrangedSubviews where !view.isHidden {
            if let previous = frames.last?.view {
                y += customSpacings[ObjectIdentifier(previous)] ?? spacing
            }
            let size = fittingSize(of: view, width: width)
            let frame = CGRect(x: (width - size.width) / 2, y: y, width: size.width, height: size.height)
            frames.append((view, frame))
            y = frame.maxY
        }
        return frames
    }

    /// The size of a view at most `width` wide.
    private func fittingSize(of view: UIView, width: CGFloat) -> CGSize {
        if view is UIStackView {
            // Rows are stack views, so they're sized by their own constraints
            let size = view.systemLayoutSizeFitting(
                CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
                withHorizontalFittingPriority: .required,
                verticalFittingPriority: .fittingSizeLevel
            )
            return CGSize(width: width, height: ceil(size.height))
        }
        let size = view.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: min(size.width, width), height: ceil(size.height))
    }

    /// Loads the components of a color chosen elsewhere.
    func setColor(_ color: RGBAColor) {
        self.color = color
        colorDidChange()
    }

    /// Sends a color chosen on this page.
    func send(_ color: RGBAColor, continuously: Bool) {
        self.color = color
        onChange?(color, continuously)
    }

    /// Override to load the components of ``color``.
    func colorDidChange() {}

    /// Override to render the page for the new color space. By default, reloads the
    /// components of ``color`` in it.
    func colorSpaceDidChange() {
        colorDidChange()
    }

    /// Gives the value fields of rows the width of the widest, so their sliders
    /// line up.
    func alignFields(of rows: [ColorSliderRow]) {
        let fields = rows.map(\.field)
        for field in fields {
            // Align them again as their values change their widths
            field.onContentSizeChange = { [weak self] in
                self?.setNeedsLayout()
            }
        }
        alignedFieldGroups.append(fields)
        setNeedsLayout()
    }
}

// MARK: - Grid

/// A grid of colors: grays in the top row, then hues from dark to light.
final class ColorGridPage: ColorPickerPage {

    private let grid = ColorGrid()

    /// The hues of the columns, in degrees.
    private static let hues: [Double] = [195, 215, 250, 280, 315, 350, 8, 25, 38, 50, 75, 125]

    /// The saturation and brightness of the rows below the grays, from dark to light.
    private static let shades: [(saturation: Double, brightness: Double)] = [
        (1, 0.3), (1, 0.45), (1, 0.62), (1, 0.8), (1, 1),
        (0.72, 1), (0.52, 1), (0.34, 1), (0.18, 1),
    ]

    override init(frame: CGRect) {
        super.init(frame: frame)
        grid.accessibilityLabel = "Color Grid"
        addArrangedSubview(grid)
        grid.addTarget(self, action: #selector(gridChanged), for: .valueChanged)
        grid.addTarget(self, action: #selector(gridEnded), for: .editingDidEnd)
        colorSpaceDidChange()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func colorSpaceDidChange() {
        // Swatches use the primaries of the color space, gamma encoded so the shades
        // are spread evenly, so wider color spaces have more vivid swatches
        let space = colorSpace.toGammaEncodedColorSpace()
        let count = Self.hues.count
        let grays = (0..<count).map { column in
            OKLCHColor(lightness: 1 - Double(column) / Double(count - 1), chroma: 0, hue: 0).toRGBAColor()
        }
        let shades = Self.shades.map { shade in
            Self.hues.map { hue in
                HSBAColor(hue: .degrees(hue), saturation: shade.saturation, brightness: shade.brightness)
                    .toRGBAColor()
                    .toColorSpace(space)
            }
        }
        grid.colors = [grays] + shades
        colorDidChange()
    }

    override func colorDidChange() {
        // Select the swatch of the color, if there is one
        let target = color.toOKLabColor()
        var best: (index: ColorGrid.Index, distance: Double)?
        for (row, colors) in grid.colors.enumerated() {
            for (column, swatch) in colors.enumerated() {
                let lab = swatch.toOKLabColor()
                let distance = simd_distance(
                    SIMD3(lab.lightness, lab.a, lab.b),
                    SIMD3(target.lightness, target.a, target.b)
                )
                if distance < (best?.distance ?? .infinity) {
                    best = (ColorGrid.Index(row: row, column: column), distance)
                }
            }
        }
        grid.selectedIndex = best.flatMap { $0.distance < 0.005 ? $0.index : nil }
    }

    @objc private func gridChanged() {
        guard let color = grid.selectedColor else { return }
        send(color, continuously: true)
    }

    @objc private func gridEnded() {
        guard let color = grid.selectedColor else { return }
        send(color, continuously: false)
    }
}

// MARK: - Menu Page

/// A page that shows one of several sub-pages, chosen from a menu below them, such
/// as the color and white wheels of the spectrum page.
///
/// Only the visible sub-page follows the color; the others load it when shown.
@available(iOS 14.0, macCatalyst 14.0, *)
final class ColorPickerMenuPage: ColorPickerPage {

    /// The index of the visible sub-page.
    var selectedIndex = 0 {
        didSet {
            guard selectedIndex != oldValue else { return }
            updateSelection()
        }
    }

    /// Called when a sub-page is chosen from the menu.
    var onSelectionChange: ((Int) -> Void)?

    private let menuRow: ColorPickerMenuRow
    private let options: [(title: String, page: ColorPickerPage)]

    private var visiblePage: ColorPickerPage {
        options[selectedIndex].page
    }

    init(title: String, options: [(title: String, page: ColorPickerPage)]) {
        precondition(!options.isEmpty, "A menu page needs at least one sub-page")
        self.menuRow = ColorPickerMenuRow(title: title)
        self.options = options
        super.init(frame: .zero)
        for option in options {
            option.page.onChange = { [weak self] color, continuously in
                self?.send(color, continuously: continuously)
            }
            addArrangedSubview(option.page)
        }
        // The menu is below the sub-page it chooses
        addArrangedSubview(menuRow)
        updateSelection()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateSelection() {
        selectedIndex = min(max(selectedIndex, 0), options.count - 1)
        menuRow.update(
            options: Array(options.indices),
            selected: selectedIndex,
            title: { self.options[$0].title }
        ) { [weak self] index in
            self?.select(index)
        }
        for (index, option) in options.enumerated() {
            option.page.isHidden = index != selectedIndex
        }
        invalidateLayout()
        visiblePage.setColor(color)
    }

    override func colorSpaceDidChange() {
        for option in options {
            option.page.colorSpace = colorSpace
        }
        colorDidChange()
    }

    override func colorDidChange() {
        visiblePage.setColor(color)
    }

    private func select(_ index: Int) {
        endEditing(true)
        selectedIndex = index
        onSelectionChange?(index)
    }
}

// MARK: - Hue Wheel

/// A hue and saturation wheel, with a brightness slider, in the components of the
/// color space.
final class ColorHueWheelPage: ColorPickerPage {

    private let wheel = ColorWheel()
    private let brightnessRow = ColorSliderRow(
        title: "Brightness",
        format: ColorSliderRow.percent,
        parse: ColorSliderRow.parsePercent
    )

    private var hue: Double = 0
    private var saturation: Double = 0
    private var brightness: Double = 1

    override init(frame: CGRect) {
        super.init(frame: frame)
        wheel.accessibilityLabel = "Color Wheel"
        addArrangedSubview(wheel)
        addArrangedSubview(brightnessRow)

        wheel.addTarget(self, action: #selector(wheelChanged), for: .valueChanged)
        wheel.addTarget(self, action: #selector(wheelEnded), for: .editingDidEnd)
        brightnessRow.onChange = { [weak self] value, continuously in
            guard let self else { return }
            self.brightness = value
            self.update(sending: continuously)
        }
        colorSpaceDidChange()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func components(hue: Double, saturation: Double, brightness: Double) -> RGBAColor {
        HSBAColor(hue: .degrees(hue), saturation: saturation, brightness: brightness)
            .toRGBAColor()
            .toColorSpace(colorSpace)
    }

    override func colorSpaceDidChange() {
        wheel.render { point in
            let radius = min(simd_length(point), 1)
            let hue = atan2(point.y, point.x) * 180 / .pi
            return self.components(hue: hue, saturation: radius, brightness: 1)
        }
        colorDidChange()
    }

    override func colorDidChange() {
        let c = color.toComponents(in: colorSpace)
        let hsb = RGBAColor(red: c.x, green: c.y, blue: c.z).toHSBAColor()
        brightness = min(max(hsb.brightness, 0), 1)
        // Keep the hue of grays, and the hue and saturation of black
        if brightness > 1e-4 {
            if hsb.saturation > 1e-4 {
                hue = hsb.hue.degrees
            }
            saturation = min(max(hsb.saturation, 0), 1)
        }
        updateControls()
    }

    private func update(sending continuously: Bool) {
        updateControls()
        send(components(hue: hue, saturation: saturation, brightness: brightness), continuously: continuously)
    }

    private func updateControls() {
        let radians = hue * .pi / 180
        wheel.point = CGPoint(x: saturation * cos(radians), y: saturation * sin(radians))
        wheel.dimming = 1 - brightness
        wheel.thumbColor = components(hue: hue, saturation: saturation, brightness: brightness)
        brightnessRow.value = brightness
        brightnessRow.slider.thumbColor = wheel.thumbColor
        brightnessRow.slider.setTrack(samples: 32) { t in
            self.components(hue: self.hue, saturation: self.saturation, brightness: t)
        }
    }

    @objc private func wheelChanged() {
        let point = wheel.point
        saturation = min(Double(hypot(point.x, point.y)), 1)
        if saturation > 0 {
            hue = atan2(Double(point.y), Double(point.x)) * 180 / .pi
            hue = hue < 0 ? hue + 360 : hue
        }
        update(sending: true)
    }

    @objc private func wheelEnded() {
        update(sending: false)
    }
}

// MARK: - RGB Sliders

/// Red, green and blue sliders, and a HEX field, in the components of the color space.
final class ColorRGBSlidersPage: ColorPickerPage {

    private let rows: [ColorSliderRow] = ["Red", "Green", "Blue"].map { title in
        ColorSliderRow(
            title: title,
            format: { "\(Int(($0 * 255).rounded()))" },
            parse: { ColorSliderRow.parseNumber($0).map { $0 / 255 } }
        )
    }
    private let hexLabel = UILabel()
    private let hexField = ColorValueField(keyboardType: .asciiCapable)

    private var components = SIMD3<Double>(0, 0, 0)

    override init(frame: CGRect) {
        super.init(frame: frame)
        for (channel, row) in rows.enumerated() {
            addArrangedSubview(row)
            row.onChange = { [weak self] value, continuously in
                guard let self else { return }
                self.components[channel] = value
                self.update(sending: continuously)
            }
        }

        hexLabel.font = .preferredFont(forTextStyle: .body)
        hexLabel.adjustsFontForContentSizeCategory = true
        hexLabel.textColor = .secondaryLabel
        hexLabel.textAlignment = .right
        hexLabel.adjustsFontSizeToFitWidth = true
        hexLabel.minimumScaleFactor = 0.6
        hexField.autocapitalizationType = .allCharacters
        hexField.accessibilityLabel = "Hex Color"
        hexField.onCommit = { [weak self] text in
            self?.commitHex(text)
        }
        let hexRow = UIStackView(arrangedSubviews: [hexLabel, hexField])
        hexRow.axis = .horizontal
        hexRow.alignment = .center
        hexRow.spacing = 8
        alignFields(of: rows)
        setCustomSpacing(24, after: rows[2])
        addArrangedSubview(hexRow)
        colorSpaceDidChange()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func colorSpaceDidChange() {
        hexLabel.text = "\(colorSpace) Hex Color #"
        colorDidChange()
    }

    override func colorDidChange() {
        let c = color.toComponents(in: colorSpace)
        components = SIMD3(c.x.clamped(to: 0...1), c.y.clamped(to: 0...1), c.z.clamped(to: 0...1))
        updateControls()
    }

    private func update(sending continuously: Bool) {
        updateControls()
        send(colorSpace.pickerColor(components), continuously: continuously)
    }

    private func updateControls() {
        let current = colorSpace.pickerColor(components)
        for (channel, row) in rows.enumerated() {
            row.value = components[channel]
            row.slider.thumbColor = current
            row.slider.setTrack(samples: 64) { t in
                var c = self.components
                c[channel] = t
                return self.colorSpace.pickerColor(c)
            }
        }
        if !hexField.isFirstResponder {
            let hex = HEXColor(red: components.x, green: components.y, blue: components.z)
            // Opaque, so six digits
            hexField.text = hex.toString(includePrefix: false)
        }
    }

    private func commitHex(_ text: String) {
        guard let hex = HEXColor(decoding: text) else {
            updateControls()
            return
        }
        components = SIMD3(Double(hex.red), Double(hex.green), Double(hex.blue)) / 255
        update(sending: false)
    }
}

// MARK: - White

/// A wheel of white light, with temperature from warm at the bottom to cool at the
/// top, and tint from green on the left to magenta on the right.
final class ColorTemperaturePage: ColorPickerPage {

    nonisolated static let warmest = 1800.0
    nonisolated static let coolest = 12000.0
    /// The Oklab green-magenta offset at full tint.
    private static let tintStrength = 0.06

    private let wheel = ColorWheel()
    private let temperatureRow = ColorSliderRow(
        title: "Temperature",
        format: { "\(Int(ColorTemperaturePage.kelvin(at: $0).rounded())) K" },
        parse: { ColorSliderRow.parseNumber($0).map(ColorTemperaturePage.position(of:)) }
    )
    private let tintRow = ColorSliderRow(
        title: "Tint",
        range: -1...1,
        format: { "\(Int(($0 * 100).rounded()))" },
        parse: { ColorSliderRow.parseNumber($0).map { $0 / 100 } }
    )
    private let brightnessRow = ColorSliderRow(
        title: "Brightness",
        format: ColorSliderRow.percent,
        parse: ColorSliderRow.parsePercent
    )

    /// The temperature, from `0` (warmest) to `1` (coolest), even in mireds.
    private var position = ColorTemperaturePage.position(of: 6500)
    /// The tint, from `-1` (green) to `1` (magenta).
    private var tint: Double = 0
    private var brightness: Double = 1

    /// The temperature at a position from `0` (warmest) to `1` (coolest), even in
    /// mireds, which are closer to even steps of perceived change than kelvin.
    nonisolated static func kelvin(at position: Double) -> Double {
        let warm = 1e6 / warmest
        let cool = 1e6 / coolest
        return 1e6 / (warm + (cool - warm) * position.clamped(to: 0...1))
    }

    nonisolated static func position(of kelvin: Double) -> Double {
        let warm = 1e6 / warmest
        let cool = 1e6 / coolest
        let mired = 1e6 / kelvin.clamped(to: warmest...coolest)
        return (mired - warm) / (cool - warm)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        wheel.accessibilityLabel = "Temperature Wheel"
        addArrangedSubview(wheel)
        addArrangedSubview(temperatureRow)
        addArrangedSubview(tintRow)
        addArrangedSubview(brightnessRow)
        alignFields(of: [temperatureRow, tintRow, brightnessRow])

        wheel.addTarget(self, action: #selector(wheelChanged), for: .valueChanged)
        wheel.addTarget(self, action: #selector(wheelEnded), for: .editingDidEnd)
        temperatureRow.onChange = { [weak self] value, continuously in
            guard let self else { return }
            self.position = value
            self.update(sending: continuously)
        }
        tintRow.onChange = { [weak self] value, continuously in
            guard let self else { return }
            self.tint = value
            self.update(sending: continuously)
        }
        brightnessRow.onChange = { [weak self] value, continuously in
            guard let self else { return }
            self.brightness = value
            self.update(sending: continuously)
        }
        colorSpaceDidChange()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// The color of light at a temperature and tint, fitted to the gamut of the color
    /// space, with its brightest component scaled to `brightness`.
    private func color(position: Double, tint: Double, brightness: Double) -> RGBAColor {
        var oklab = RGBAColor(kelvin: Self.kelvin(at: position)).toOKLabColor()
        oklab.a += tint * Self.tintStrength
        let fitted = oklab.toRGBAColor().toColorGamut(colorSpace.toColorGamut())
        let space = colorSpace.toGammaEncodedColorSpace()
        var c = fitted.toComponents(in: space)
        let maximum = c.max()
        if maximum > 0 {
            c *= brightness / maximum
        }
        return space.pickerColor(c)
    }

    override func colorSpaceDidChange() {
        // Gamut mapping is slower than the other wheels, and the colors change slowly,
        // so a lower resolution is as smooth
        wheel.render(resolution: 128) { point in
            var point = point
            let length = simd_length(point)
            if length > 1 {
                point /= length
            }
            return self.color(position: (point.y + 1) / 2, tint: point.x, brightness: 1)
        }
        colorDidChange()
    }

    override func colorDidChange() {
        let space = colorSpace.toGammaEncodedColorSpace()
        var c = color.toComponents(in: space)
        let maximum = c.max()
        brightness = maximum.clamped(to: 0...1)
        guard maximum > 1e-4 else {
            updateControls()
            return
        }
        c /= maximum
        let normalized = space.pickerColor(c)
        if let kelvin = normalized.toCorrelatedColorTemperature() {
            position = Self.position(of: kelvin)
            let light = RGBAColor(kelvin: Self.kelvin(at: position)).toOKLabColor()
            tint = ((normalized.toOKLabColor().a - light.a) / Self.tintStrength).clamped(to: -1...1)
        }
        updateControls()
    }

    private func update(sending continuously: Bool) {
        updateControls()
        send(color(position: position, tint: tint, brightness: brightness), continuously: continuously)
    }

    private func updateControls() {
        // Keep the point in the disk, as the sliders reach the corners
        var point = SIMD2(tint, position * 2 - 1)
        let length = simd_length(point)
        if length > 1 {
            point /= length
        }
        wheel.point = CGPoint(x: point.x, y: point.y)
        wheel.dimming = 1 - brightness
        let current = color(position: position, tint: tint, brightness: brightness)
        wheel.thumbColor = current

        temperatureRow.value = position
        temperatureRow.slider.thumbColor = current
        temperatureRow.slider.setTrack(samples: 48) { t in
            self.color(position: t, tint: self.tint, brightness: 1)
        }
        tintRow.value = tint
        tintRow.slider.thumbColor = current
        tintRow.slider.setTrack(samples: 48) { t in
            self.color(position: self.position, tint: t * 2 - 1, brightness: 1)
        }
        brightnessRow.value = brightness
        brightnessRow.slider.thumbColor = current
        brightnessRow.slider.setTrack(samples: 32) { t in
            self.color(position: self.position, tint: self.tint, brightness: t)
        }
    }

    @objc private func wheelChanged() {
        let point = wheel.point
        tint = Double(point.x)
        position = (Double(point.y) + 1) / 2
        update(sending: true)
    }

    @objc private func wheelEnded() {
        update(sending: false)
    }
}

// MARK: - Adjustments

/// Perceptual sliders: OKLCH hue, lightness and chroma, and tone, the CIE Lab
/// lightness of Material Design's HCT. Colors are fitted to the gamut of the color
/// space. Shown on the sliders page, as an alternative to the RGB sliders.
final class ColorAdjustmentsPage: ColorPickerPage {

    private let hueRow = ColorSliderRow(
        title: "Hue",
        range: 0...360,
        format: { "\(Int($0.rounded()) % 360)°" },
        parse: ColorSliderRow.parseNumber
    )
    private let lightnessRow = ColorSliderRow(
        title: "Lightness",
        format: ColorSliderRow.percent,
        parse: ColorSliderRow.parsePercent
    )
    private let chromaRow = ColorSliderRow(
        title: "Chroma",
        range: 0...0.37,
        keyboardType: .decimalPad,
        format: { String(format: "%.3f", $0) },
        parse: ColorSliderRow.parseNumber
    )
    private let toneRow = ColorSliderRow(
        title: "Tone",
        range: 0...100,
        format: { "\(Int($0.rounded()))" },
        parse: ColorSliderRow.parseNumber
    )

    /// The requested OKLCH color, before gamut mapping, so chroma reduced to fit
    /// comes back when the lightness or hue allows it.
    private var oklch = OKLCHColor(lightness: 0.5, chroma: 0, hue: 0)

    override init(frame: CGRect) {
        super.init(frame: frame)
        for row in [hueRow, lightnessRow, chromaRow, toneRow] {
            addArrangedSubview(row)
        }
        alignFields(of: [hueRow, lightnessRow, chromaRow, toneRow])
        hueRow.slider.accessibilityStep = 1 / 72
        hueRow.onChange = { [weak self] value, continuously in
            guard let self else { return }
            self.oklch.hue = .degrees(value)
            self.update(sending: continuously)
        }
        lightnessRow.onChange = { [weak self] value, continuously in
            guard let self else { return }
            self.oklch.lightness = value
            self.update(sending: continuously)
        }
        chromaRow.onChange = { [weak self] value, continuously in
            guard let self else { return }
            self.oklch.chroma = value
            self.update(sending: continuously)
        }
        toneRow.onChange = { [weak self] value, continuously in
            guard let self else { return }
            self.oklch = self.toned(value)
            self.update(sending: continuously)
        }
        colorSpaceDidChange()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func fitted(_ oklch: OKLCHColor) -> RGBAColor {
        oklch.toColorGamut(colorSpace.toColorGamut()).toRGBAColor()
    }

    /// The requested color with its CIE Lab lightness set to `tone`, keeping its CIE
    /// LCh chroma and hue.
    private func toned(_ tone: Double) -> OKLCHColor {
        var lch = oklch.toCIELCHColor()
        lch.lightness = tone
        var result = lch.toOKLCHColor()
        result.lightness = result.lightness.clamped(to: 0...1)
        if result.chroma < 1e-4 {
            result.hue = oklch.hue
        }
        return result
    }

    override func colorSpaceDidChange() {
        chromaRow.slider.maximumValue = colorSpace.pickerMaximumChroma
        colorDidChange()
    }

    override func colorDidChange() {
        var new = color.toOKLCHColor()
        new.alpha = 1
        // Keep the hue of grays
        if new.chroma < 1e-4 {
            new.hue = oklch.hue
        }
        new.lightness = new.lightness.clamped(to: 0...1)
        oklch = new
        updateControls()
    }

    private func update(sending continuously: Bool) {
        updateControls()
        send(fitted(oklch), continuously: continuously)
    }

    private func updateControls() {
        let current = fitted(oklch)
        hueRow.value = oklch.hue.degrees
        lightnessRow.value = oklch.lightness
        chromaRow.value = min(oklch.chroma, chromaRow.slider.maximumValue)
        toneRow.value = current.toCIELabColor().lightness.clamped(to: 0...100)

        for row in [hueRow, lightnessRow, chromaRow, toneRow] {
            row.slider.thumbColor = current
        }
        let oklch = self.oklch
        let maximumChroma = chromaRow.slider.maximumValue
        hueRow.slider.setTrack(samples: 72) { t in
            var color = oklch
            color.hue = .degrees(t * 360)
            return self.fitted(color)
        }
        lightnessRow.slider.setTrack(samples: 48) { t in
            var color = oklch
            color.lightness = t
            return self.fitted(color)
        }
        chromaRow.slider.setTrack(samples: 48) { t in
            var color = oklch
            color.chroma = t * maximumChroma
            return self.fitted(color)
        }
        toneRow.slider.setTrack(samples: 48) { t in
            self.fitted(self.toned(t * 100))
        }
    }
}
#endif
