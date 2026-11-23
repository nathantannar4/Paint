//
// Copyright (c) Nathan Tannar
//

#if os(iOS) || os(visionOS)
import UIKit
import simd

import Paint

// MARK: - Color Space Components

extension ColorSpace {

    /// The largest OKLCH chroma worth offering in the gamut of the color space.
    var pickerMaximumChroma: Double {
        switch toColorGamut() {
        case .sRGB: 0.33
        case .displayP3: 0.37
        case .rec2020: 0.47
        }
    }

    /// A color from components in this color space.
    func pickerColor(_ components: SIMD3<Double>, alpha: Double = 1) -> RGBAColor {
        RGBAColor(red: components.x, green: components.y, blue: components.z, alpha: alpha, colorSpace: self)
    }
}

// MARK: - Images

@MainActor
enum ColorPickerImage {

    /// Renders an image in extended sRGB at `Float` precision, so colors outside sRGB,
    /// such as Display P3 colors, are kept.
    static func make(
        width: Int,
        height: Int,
        pixel: (_ x: Int, _ y: Int) -> RGBAColor
    ) -> CGImage? {
        guard width > 0, height > 0, let colorSpace = CGColorSpace(name: CGColorSpace.extendedSRGB) else {
            return nil
        }
        var pixels = [Float](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let color = pixel(x, y)
                let alpha = Float(min(max(color.alpha, 0), 1))
                let index = (y * width + x) * 4
                pixels[index] = Float(color.red) * alpha
                pixels[index + 1] = Float(color.green) * alpha
                pixels[index + 2] = Float(color.blue) * alpha
                pixels[index + 3] = alpha
            }
        }
        let data = pixels.withUnsafeBufferPointer { Data(buffer: $0) }
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }
        let bitmapInfo = CGBitmapInfo(
            rawValue: CGImageAlphaInfo.premultipliedLast.rawValue
                | CGBitmapInfo.floatComponents.rawValue
                | CGBitmapInfo.byteOrder32Little.rawValue
        )
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 32,
            bitsPerPixel: 128,
            bytesPerRow: width * 16,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }

    /// A horizontal gradient, sampled at `count` points from `0` to `1`.
    static func gradient(count: Int = 128, _ sample: (Double) -> RGBAColor) -> CGImage? {
        make(width: count, height: 1) { x, _ in
            sample(Double(x) / Double(count - 1))
        }
    }

    /// The checkerboard drawn behind translucent colors.
    static let checkerboard: UIColor = {
        let size: CGFloat = 8
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: CGSize(width: size * 2, height: size * 2), format: format).image { context in
            UIColor(white: 1, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: size * 2, height: size * 2))
            UIColor(white: 0.8, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: size, height: size))
            context.fill(CGRect(x: size, y: size, width: size, height: size))
        }
        return UIColor(patternImage: image)
    }()
}

// MARK: - Thumb

/// The round thumb of the sliders and wheels: a white ring filled with a color.
final class ColorPickerThumbView: UIView {

    private let fillLayer = CALayer()

    var color: RGBAColor = RGBAColor(red: 1, green: 1, blue: 1) {
        didSet { updateFill() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .white
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.25
        layer.shadowRadius = 3
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.addSublayer(fillLayer)
        updateFill()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.width / 2
        let inset = max(3, bounds.width * 0.12)
        fillLayer.frame = bounds.insetBy(dx: inset, dy: inset)
        fillLayer.cornerRadius = fillLayer.bounds.width / 2
    }

    private func updateFill() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        var opaque = color
        opaque.alpha = 1
        fillLayer.backgroundColor = opaque.toCGColor()
        CATransaction.commit()
    }
}

// MARK: - Slider

/// A capsule slider whose track shows the colors along it, like the sliders of
/// `UIColorPickerViewController`.
///
/// Sends `.valueChanged` while tracking, and `.editingDidEnd` when tracking ends.
final class ColorSlider: UIControl {

    var minimumValue: Double = 0
    var maximumValue: Double = 1

    var value: Double = 0 {
        didSet { setNeedsLayout() }
    }

    var thumbColor: RGBAColor {
        get { thumbView.color }
        set { thumbView.color = newValue }
    }

    /// Whether a checkerboard is shown behind the track, for translucent colors.
    var showsCheckerboard = false {
        didSet { trackView.backgroundColor = showsCheckerboard ? ColorPickerImage.checkerboard : .clear }
    }

    /// The accessibility step, as a fraction of the range.
    var accessibilityStep: Double = 0.05

    private let trackView = UIView()
    private let trackLayer = CALayer()
    private let thumbView = ColorPickerThumbView()
    private static let height: CGFloat = 30

    override init(frame: CGRect) {
        super.init(frame: frame)
        trackView.isUserInteractionEnabled = false
        trackView.clipsToBounds = true
        trackView.layer.borderWidth = 0.5
        trackView.layer.borderColor = UIColor.separator.cgColor
        trackLayer.contentsGravity = .resize
        trackLayer.magnificationFilter = .linear
        trackView.layer.addSublayer(trackLayer)
        addSubview(trackView)
        addSubview(thumbView)
        isAccessibilityElement = true
        accessibilityTraits = .adjustable
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: Self.height)
    }

    /// Renders the track from colors sampled from `0` (minimum) to `1` (maximum).
    func setTrack(samples: Int = 128, _ sample: (Double) -> RGBAColor) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        trackLayer.contents = ColorPickerImage.gradient(count: samples, sample)
        CATransaction.commit()
    }

    private var fraction: Double {
        let range = maximumValue - minimumValue
        guard range > 0 else { return 0 }
        return min(max((value - minimumValue) / range, 0), 1)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let height = Self.height
        let track = CGRect(x: 0, y: (bounds.height - height) / 2, width: bounds.width, height: height)
        trackView.frame = track
        trackView.layer.cornerRadius = height / 2
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        trackLayer.frame = trackView.bounds
        CATransaction.commit()
        let thumbSize = height
        let travel = max(track.width - thumbSize, 0)
        thumbView.frame = CGRect(
            x: travel * fraction,
            y: track.midY - thumbSize / 2,
            width: thumbSize,
            height: thumbSize
        )
    }

    private func updateValue(for touch: UITouch) {
        let thumbSize = Self.height
        let travel = max(bounds.width - thumbSize, 1)
        let x = touch.location(in: self).x - thumbSize / 2
        let fraction = min(max(Double(x / travel), 0), 1)
        value = minimumValue + fraction * (maximumValue - minimumValue)
        sendActions(for: .valueChanged)
    }

    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        updateValue(for: touch)
        return true
    }

    override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        updateValue(for: touch)
        return true
    }

    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        sendActions(for: .editingDidEnd)
    }

    override func cancelTracking(with event: UIEvent?) {
        sendActions(for: .editingDidEnd)
    }

    override func accessibilityIncrement() {
        adjust(by: accessibilityStep)
    }

    override func accessibilityDecrement() {
        adjust(by: -accessibilityStep)
    }

    private func adjust(by step: Double) {
        let range = maximumValue - minimumValue
        value = min(max(value + step * range, minimumValue), maximumValue)
        sendActions(for: .valueChanged)
        sendActions(for: .editingDidEnd)
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // Keep an enclosing scroll view from stealing drags on the wheel
        !(gestureRecognizer is UIPanGestureRecognizer)
    }
}

// MARK: - Value Field

/// Provides the toolbar shown above the keyboard of the ``ColorValueField``s in its
/// view controller, found along the responder chain.
@MainActor
protocol ColorValueFieldToolbarProviding: AnyObject {
    var valueFieldToolbar: ColorValueFieldToolbar { get }
}

/// The toolbar above the keyboard of the editing ``ColorValueField``, shared by
/// every field of a picker, with arrows to the previous and next fields, a button
/// to toggle a minus sign for fields that allow negative values, and a done button.
final class ColorValueFieldToolbar: UIToolbar {

    /// The field being edited, which the buttons act on.
    weak var field: ColorValueField? {
        didSet { update() }
    }

    private lazy var previousItem = UIBarButtonItem(
        image: UIImage(systemName: "chevron.up"),
        style: .plain,
        target: self,
        action: #selector(previousTapped)
    )
    private lazy var nextItem = UIBarButtonItem(
        image: UIImage(systemName: "chevron.down"),
        style: .plain,
        target: self,
        action: #selector(nextTapped)
    )
    private lazy var signItem = UIBarButtonItem(
        title: "+/−",
        style: .plain,
        target: self,
        action: #selector(signTapped)
    )
    private lazy var doneItem = UIBarButtonItem(
        barButtonSystemItem: .done,
        target: self,
        action: #selector(doneTapped)
    )

    override init(frame: CGRect) {
        super.init(frame: frame)
        previousItem.accessibilityLabel = "Previous"
        nextItem.accessibilityLabel = "Next"
        signItem.accessibilityLabel = "Toggle Minus Sign"
        update()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Shows the buttons for the field being edited.
    func update() {
        let fixed = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        fixed.width = 8
        var items = [previousItem, fixed, nextItem, UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)]
        if field?.allowsNegativeValues == true {
            items += [signItem, UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)]
        }
        items.append(doneItem)
        setItems(items, animated: false)
        previousItem.isEnabled = field?.canMoveFocus(by: -1) ?? false
        nextItem.isEnabled = field?.canMoveFocus(by: 1) ?? false
        sizeToFit()
    }

    @objc private func previousTapped() {
        field?.moveFocus(by: -1)
    }

    @objc private func nextTapped() {
        field?.moveFocus(by: 1)
    }

    @objc private func doneTapped() {
        _ = field?.resignFirstResponder()
    }

    @objc private func signTapped() {
        field?.toggleSign()
    }
}

/// A small text field for the value of a slider, which commits when editing ends.
///
/// Its text is cleared when editing begins, with the previous value kept as the
/// placeholder, so typing replaces it, and an empty field keeps the value. Its
/// keyboard shows the ``ColorValueFieldToolbar`` of its picker.
///
/// It's sized to fit its text, or its placeholder while editing, with padding.
final class ColorValueField: UITextField, UITextFieldDelegate {

    var onCommit: ((String) -> Void)?

    /// Whether the toolbar has a button to toggle a minus sign, since the number pad
    /// has none.
    var allowsNegativeValues = false {
        didSet { toolbar?.update() }
    }

    /// Called when the size of the field for its content changes, such as when its
    /// text changes.
    var onContentSizeChange: (() -> Void)?

    override var font: UIFont? {
        didSet { contentSizeDidChange() }
    }

    override var text: String? {
        didSet { contentSizeDidChange() }
    }

    override var placeholder: String? {
        didSet { contentSizeDidChange() }
    }

    private func contentSizeDidChange() {
        invalidateIntrinsicContentSize()
        onContentSizeChange?()
    }

    /// The padding around the text.
    private static let padding = UIEdgeInsets(top: 7, left: 10, bottom: 8, right: 10)

    /// The narrowest the field is, so that it keeps its width as its value changes,
    /// unless it needs more to fit, such as for larger text sizes.
    private static let minimumWidth: CGFloat = 80

    /// The shared toolbar of the view controller the field is in.
    private var toolbar: ColorValueFieldToolbar? {
        var responder: UIResponder? = next
        while let current = responder {
            if let provider = current as? ColorValueFieldToolbarProviding {
                return provider.valueFieldToolbar
            }
            responder = current.next
        }
        return nil
    }

    // visionOS has no input accessory views, and newer SDKs mark the property
    // unavailable there
    #if !os(visionOS)
    override var inputAccessoryView: UIView? {
        get { toolbar }
        set {}
    }
    #endif

    init(keyboardType: UIKeyboardType = .numberPad) {
        super.init(frame: .zero)
        delegate = self
        // The body size at the default content size, scaled for Dynamic Type
        font = UIFontMetrics(forTextStyle: .body).scaledFont(
            for: .monospacedDigitSystemFont(ofSize: 17, weight: .regular)
        )
        adjustsFontForContentSizeCategory = true
        textAlignment = .center
        backgroundColor = .quaternarySystemFill
        layer.cornerRadius = 8
        layer.cornerCurve = .continuous
        self.keyboardType = keyboardType
        returnKeyType = .done
        autocorrectionType = .no
        autocapitalizationType = .none
        spellCheckingType = .no
        addTarget(self, action: #selector(editingChanged), for: .editingChanged)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardDidShow),
            name: UIResponder.keyboardDidShowNotification,
            object: nil
        )
        // Keep its size beside a slider, which takes the remaining width
        setContentHuggingPriority(.defaultHigh, for: .horizontal)
        setContentHuggingPriority(.defaultHigh, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .vertical)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// A width the field is at least, such as the widest of the fields of a page, so
    /// they line up.
    var alignmentWidth: CGFloat = 0 {
        didSet {
            guard alignmentWidth != oldValue else { return }
            invalidateIntrinsicContentSize()
        }
    }

    /// The size of the field for its content, ignoring ``alignmentWidth``.
    var fittingSize: CGSize {
        var size = super.intrinsicContentSize
        size.height += (Self.padding.top + Self.padding.bottom)
        size.width += (Self.padding.left + Self.padding.right)
        size.width = max(size.width, Self.minimumWidth)
        return size
    }

    override var intrinsicContentSize: CGSize {
        var size = fittingSize
        size.width = max(size.width, alignmentWidth)
        return size
    }

    // MARK: Navigation

    /// The visible value fields of the picker, in reading order.
    private func siblingFields() -> [ColorValueField] {
        // The root view of the view controller the field is in
        var root: UIView = self
        while let superview = root.superview, !(root.next is UIViewController) {
            root = superview
        }
        var fields: [ColorValueField] = []
        func collect(_ view: UIView) {
            guard !view.isHidden, view.alpha > 0 else { return }
            if let field = view as? ColorValueField, field.isEnabled {
                fields.append(field)
            }
            view.subviews.forEach(collect)
        }
        collect(root)
        return fields.sorted { lhs, rhs in
            let a = lhs.convert(lhs.bounds, to: root)
            let b = rhs.convert(rhs.bounds, to: root)
            return abs(a.midY - b.midY) > 1 ? a.midY < b.midY : a.midX < b.midX
        }
    }

    /// Whether there's a field `offset` fields from this one, in reading order.
    func canMoveFocus(by offset: Int) -> Bool {
        let fields = siblingFields()
        guard let index = fields.firstIndex(of: self) else { return false }
        return fields.indices.contains(index + offset)
    }

    /// Edits the field `offset` fields from this one, in reading order.
    func moveFocus(by offset: Int) {
        let fields = siblingFields()
        guard let index = fields.firstIndex(of: self), fields.indices.contains(index + offset) else { return }
        let field = fields[index + offset]
        // Commits this field as it ends editing
        field.becomeFirstResponder()
    }

    /// Scrolls the enclosing scroll view so the field is above the keyboard.
    private func scrollToVisible() {
        var view: UIView? = superview
        while let current = view, !(current is UIScrollView) {
            view = current.superview
        }
        guard let scrollView = view as? UIScrollView else { return }
        scrollView.layoutIfNeeded()
        // Computed rather than `scrollRectToVisible(_:animated:)`, which doesn't
        // scroll while the scroll view is resizing for the keyboard
        let rect = convert(bounds, to: scrollView).insetBy(dx: 0, dy: -16)
        let inset = scrollView.adjustedContentInset
        let visible = scrollView.bounds.inset(by: inset)
        var offset = scrollView.contentOffset
        if rect.maxY > visible.maxY {
            offset.y += rect.maxY - visible.maxY
        } else if rect.minY < visible.minY {
            offset.y -= visible.minY - rect.minY
        }
        let maximum = max(scrollView.contentSize.height + inset.bottom - scrollView.bounds.height, -inset.top)
        offset.y = min(max(offset.y, -inset.top), maximum)
        if offset != scrollView.contentOffset {
            scrollView.setContentOffset(offset, animated: true)
        }
    }

    @objc private func keyboardDidShow() {
        if isFirstResponder {
            scrollToVisible()
        }
    }

    @objc private func editingChanged() {
        contentSizeDidChange()
    }

    /// Toggles a minus sign on the typed value.
    func toggleSign() {
        // Toggle the sign of the typed value, or of the previous value if nothing is typed yet
        var text = text ?? ""
        if text.isEmpty {
            text = placeholder ?? ""
        }
        if text.hasPrefix("-") {
            text.removeFirst()
        } else {
            text = "-" + text
        }
        self.text = text
    }

    // MARK: UITextFieldDelegate

    func textFieldDidBeginEditing(_ textField: UITextField) {
        placeholder = text
        text = ""
        toolbar?.field = self
        // When the keyboard is already up, such as moving between fields, it won't
        // show again, so scroll now
        scrollToVisible()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        placeholder = nil
        onCommit?(textField.text ?? "")
    }
}

// MARK: - Slider Row

/// A titled slider with a value field, like the rows of the sliders page of
/// `UIColorPickerViewController`.
final class ColorSliderRow: UIStackView {

    let titleLabel = UILabel()
    let slider = ColorSlider()
    let field: ColorValueField

    /// Formats the slider value for the field.
    var format: (Double) -> String
    /// Parses the field into a slider value, or `nil` if it's invalid.
    var parse: (String) -> Double?
    /// Called with the new value, and whether it's still changing.
    var onChange: ((Double, Bool) -> Void)?

    var value: Double {
        get { slider.value }
        set {
            slider.value = newValue
            if !field.isFirstResponder {
                field.text = format(newValue)
            }
            slider.accessibilityValue = format(newValue)
        }
    }

    init(
        title: String,
        range: ClosedRange<Double> = 0...1,
        keyboardType: UIKeyboardType = .numberPad,
        format: @escaping (Double) -> String,
        parse: @escaping (String) -> Double?
    ) {
        self.format = format
        self.parse = parse
        self.field = ColorValueField(keyboardType: keyboardType)
        super.init(frame: .zero)
        field.allowsNegativeValues = range.lowerBound < 0
        axis = .vertical
        spacing = 6

        titleLabel.text = title.uppercased()
        titleLabel.font = .preferredFont(forTextStyle: .footnote)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = .secondaryLabel
        slider.minimumValue = range.lowerBound
        slider.maximumValue = range.upperBound
        slider.accessibilityLabel = title

        let controls = UIStackView(arrangedSubviews: [slider, field])
        controls.axis = .horizontal
        controls.alignment = .center
        controls.spacing = 12
        addArrangedSubview(titleLabel)
        addArrangedSubview(controls)

        slider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
        slider.addTarget(self, action: #selector(sliderEnded), for: .editingDidEnd)
        field.onCommit = { [weak self] text in
            guard let self else { return }
            if let parsed = self.parse(text) {
                let clamped = min(max(parsed, self.slider.minimumValue), self.slider.maximumValue)
                self.value = clamped
                self.onChange?(clamped, false)
            }
            self.field.text = self.format(self.value)
        }
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func sliderChanged() {
        value = slider.value
        onChange?(slider.value, true)
    }

    @objc private func sliderEnded() {
        onChange?(slider.value, false)
    }

    // MARK: Formats

    nonisolated static func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    nonisolated static func parseNumber(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: CharacterSet(charactersIn: " %°K").union(.whitespaces))
        return Double(trimmed.replacingOccurrences(of: ",", with: "."))
    }

    nonisolated static func parsePercent(_ text: String) -> Double? {
        parseNumber(text).map { $0 / 100 }
    }
}

// MARK: - Menu Row

/// A secondary title with a pull-down menu button on the right, such as the color
/// space of a page. The button shows the selected option in the primary text
/// color, with a chevron in the secondary text color.
@available(iOS 14.0, macCatalyst 14.0, *)
final class ColorPickerMenuRow: UIStackView {

    let titleLabel = UILabel()
    let button = UIButton(type: .system)

    init(title: String) {
        super.init(frame: .zero)
        axis = .horizontal
        alignment = .center

        titleLabel.text = title.uppercased()
        titleLabel.font = .preferredFont(forTextStyle: .footnote)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = .secondaryLabel

        button.showsMenuAsPrimaryAction = true
        button.accessibilityLabel = title
        let chevron = UIImage(
            systemName: "chevron.up.chevron.down",
            withConfiguration: UIImage.SymbolConfiguration(textStyle: .caption1)
        )
        if #available(iOS 15.0, *) {
            var configuration = UIButton.Configuration.plain()
            configuration.image = chevron
            configuration.imageColorTransformer = UIConfigurationColorTransformer { _ in .secondaryLabel }
            configuration.imagePlacement = .trailing
            configuration.imagePadding = 4
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0)
            configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                var attributes = attributes
                attributes.font = .preferredFont(forTextStyle: .subheadline)
                // The primary text color, rather than the tint, like a value
                attributes.foregroundColor = .label
                return attributes
            }
            button.configuration = configuration
        } else {
            button.titleLabel?.font = .preferredFont(forTextStyle: .subheadline)
            button.titleLabel?.adjustsFontForContentSizeCategory = true
            button.setTitleColor(.label, for: .normal)
            button.setImage(chevron?.withTintColor(.secondaryLabel, renderingMode: .alwaysOriginal), for: .normal)
            button.semanticContentAttribute = .forceRightToLeft
        }
        addArrangedSubview(titleLabel)
        addArrangedSubview(UIView())
        addArrangedSubview(button)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Shows the selected option, and a menu of every option with a checkmark on
    /// the selected one.
    func update<Option: Equatable>(
        options: [Option],
        selected: Option,
        title: (Option) -> String,
        onSelect: @escaping (Option) -> Void
    ) {
        let selectedTitle = title(selected)
        if #available(iOS 15.0, *), button.configuration != nil {
            button.configuration?.title = selectedTitle
        } else {
            button.setTitle(selectedTitle, for: .normal)
        }
        button.accessibilityValue = selectedTitle
        button.menu = UIMenu(title: "", children: options.map { option in
            UIAction(title: title(option), state: option == selected ? .on : .off) { _ in
                onSelect(option)
            }
        })
    }
}

// MARK: - Wheel

/// A circular picker, whose position is a point in the unit disk, with `x` to the
/// right and `y` up. Its colors are rendered by the page that owns it.
///
/// Sends `.valueChanged` while tracking, and `.editingDidEnd` when tracking ends.
final class ColorWheel: UIControl {

    /// The selected point, in the unit disk.
    var point: CGPoint = .zero {
        didSet { setNeedsLayout() }
    }

    var thumbColor: RGBAColor {
        get { thumbView.color }
        set { thumbView.color = newValue }
    }

    /// How much the wheel is darkened, from `0` to `1`, to preview brightness without
    /// rendering it again.
    var dimming: Double = 0 {
        didSet {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            dimmingLayer.opacity = Float(min(max(dimming, 0), 1))
            CATransaction.commit()
        }
    }

    private let wheelView = UIView()
    private let imageLayer = CALayer()
    private let dimmingLayer = CALayer()
    private let thumbView = ColorPickerThumbView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        wheelView.isUserInteractionEnabled = false
        wheelView.clipsToBounds = true
        wheelView.layer.borderWidth = 0.5
        wheelView.layer.borderColor = UIColor.separator.cgColor
        imageLayer.contentsGravity = .resize
        imageLayer.magnificationFilter = .linear
        dimmingLayer.backgroundColor = UIColor.black.cgColor
        dimmingLayer.opacity = 0
        wheelView.layer.addSublayer(imageLayer)
        wheelView.layer.addSublayer(dimmingLayer)
        addSubview(wheelView)
        addSubview(thumbView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Renders the wheel, sampling a color for each point of the unit square, from
    /// `-1` to `1`, with `y` up. Points outside the disk are clipped.
    func render(resolution: Int = 256, _ sample: (SIMD2<Double>) -> RGBAColor) {
        let scale = 2 / Double(resolution - 1)
        let image = ColorPickerImage.make(width: resolution, height: resolution) { x, y in
            sample(SIMD2(Double(x) * scale - 1, 1 - Double(y) * scale))
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        imageLayer.contents = image
        CATransaction.commit()
    }

    private var wheelFrame: CGRect {
        let thumbSize = self.thumbSize
        let diameter = max(min(bounds.width, bounds.height) - thumbSize / 2, 0)
        return CGRect(x: bounds.midX - diameter / 2, y: bounds.midY - diameter / 2, width: diameter, height: diameter)
    }

    private var thumbSize: CGFloat { 32 }

    /// The largest the wheel is, however wide its superview.
    static let maximumDiameter: CGFloat = 300

    /// A square as wide as `size`, up to ``maximumDiameter``.
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let diameter = max(min(size.width, Self.maximumDiameter), 0)
        return CGSize(width: diameter, height: diameter)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let frame = wheelFrame
        wheelView.frame = frame
        wheelView.layer.cornerRadius = frame.width / 2
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        imageLayer.frame = wheelView.bounds
        dimmingLayer.frame = wheelView.bounds
        CATransaction.commit()
        let radius = frame.width / 2
        let center = CGPoint(x: frame.midX + point.x * radius, y: frame.midY - point.y * radius)
        thumbView.frame = CGRect(
            x: center.x - thumbSize / 2,
            y: center.y - thumbSize / 2,
            width: thumbSize,
            height: thumbSize
        )
    }

    private func updatePoint(for touch: UITouch) {
        let frame = wheelFrame
        let radius = max(frame.width / 2, 1)
        let location = touch.location(in: self)
        var point = CGPoint(x: (location.x - frame.midX) / radius, y: (frame.midY - location.y) / radius)
        let length = hypot(point.x, point.y)
        if length > 1 {
            point.x /= length
            point.y /= length
        }
        self.point = point
        sendActions(for: .valueChanged)
    }

    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        updatePoint(for: touch)
        return true
    }

    override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        updatePoint(for: touch)
        return true
    }

    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        sendActions(for: .editingDidEnd)
    }

    override func cancelTracking(with event: UIEvent?) {
        sendActions(for: .editingDidEnd)
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        // Only start tracking inside the wheel, so drags around it scroll
        let frame = wheelFrame.insetBy(dx: -thumbSize / 2, dy: -thumbSize / 2)
        let dx = point.x - frame.midX
        let dy = point.y - frame.midY
        return hypot(dx, dy) <= frame.width / 2
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // Keep an enclosing scroll view from stealing drags on the wheel
        !(gestureRecognizer is UIPanGestureRecognizer)
    }
}

// MARK: - Grid

/// A grid of color swatches, like the grid page of `UIColorPickerViewController`.
///
/// Sends `.valueChanged` while tracking, and `.editingDidEnd` when tracking ends.
final class ColorGrid: UIControl {

    struct Index: Hashable {
        var row: Int
        var column: Int
    }

    /// The colors, row by row. Every row has the same number of columns.
    var colors: [[RGBAColor]] = [] {
        didSet { rebuildCells() }
    }

    var selectedIndex: Index? {
        didSet { setNeedsLayout() }
    }

    var selectedColor: RGBAColor? {
        selectedIndex.map { colors[$0.row][$0.column] }
    }

    private let gridView = UIView()
    private var cellLayers: [CALayer] = []
    private let selectionLayer = CALayer()

    var rows: Int { colors.count }
    var columns: Int { colors.first?.count ?? 0 }

    override init(frame: CGRect) {
        super.init(frame: frame)
        gridView.isUserInteractionEnabled = false
        gridView.clipsToBounds = true
        gridView.layer.cornerRadius = 16
        gridView.layer.cornerCurve = .continuous
        addSubview(gridView)
        selectionLayer.borderColor = UIColor.white.cgColor
        selectionLayer.borderWidth = 3
        selectionLayer.cornerRadius = 3
        selectionLayer.shadowColor = UIColor.black.cgColor
        selectionLayer.shadowOpacity = 0.4
        selectionLayer.shadowRadius = 2
        selectionLayer.shadowOffset = .zero
        layer.addSublayer(selectionLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func rebuildCells() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let count = rows * columns
        while cellLayers.count < count {
            let cell = CALayer()
            gridView.layer.addSublayer(cell)
            cellLayers.append(cell)
        }
        while cellLayers.count > count {
            cellLayers.removeLast().removeFromSuperlayer()
        }
        for (row, colors) in colors.enumerated() {
            for (column, color) in colors.enumerated() {
                cellLayers[row * columns + column].backgroundColor = color.toCGColor()
            }
        }
        CATransaction.commit()
        setNeedsLayout()
    }

    /// As wide as `size`, with square cells.
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        guard columns > 0 else { return CGSize(width: size.width, height: 0) }
        return CGSize(width: size.width, height: size.width * CGFloat(rows) / CGFloat(columns))
    }

    private func cellFrame(row: Int, column: Int) -> CGRect {
        let width = gridView.bounds.width / CGFloat(max(columns, 1))
        let height = gridView.bounds.height / CGFloat(max(rows, 1))
        // Round the edges, so neighbouring cells don't leave hairline gaps
        let minX = (CGFloat(column) * width).rounded()
        let maxX = (CGFloat(column + 1) * width).rounded()
        let minY = (CGFloat(row) * height).rounded()
        let maxY = (CGFloat(row + 1) * height).rounded()
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gridView.frame = bounds
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for row in 0..<rows {
            for column in 0..<columns {
                cellLayers[row * columns + column].frame = cellFrame(row: row, column: column)
            }
        }
        if let selectedIndex, selectedIndex.row < rows, selectedIndex.column < columns {
            selectionLayer.isHidden = false
            selectionLayer.frame = cellFrame(row: selectedIndex.row, column: selectedIndex.column).insetBy(dx: -1, dy: -1)
        } else {
            selectionLayer.isHidden = true
        }
        CATransaction.commit()
    }

    private func updateSelection(for touch: UITouch) {
        guard rows > 0, columns > 0, bounds.width > 0, bounds.height > 0 else { return }
        let location = touch.location(in: self)
        let column = min(max(Int(location.x / bounds.width * CGFloat(columns)), 0), columns - 1)
        let row = min(max(Int(location.y / bounds.height * CGFloat(rows)), 0), rows - 1)
        let index = Index(row: row, column: column)
        guard index != selectedIndex else { return }
        selectedIndex = index
        sendActions(for: .valueChanged)
    }

    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        updateSelection(for: touch)
        return true
    }

    override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        updateSelection(for: touch)
        return true
    }

    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        sendActions(for: .editingDidEnd)
    }

    override func cancelTracking(with event: UIEvent?) {
        sendActions(for: .editingDidEnd)
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        !(gestureRecognizer is UIPanGestureRecognizer)
    }
}
#endif
