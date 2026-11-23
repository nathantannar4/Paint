//
// Copyright (c) Nathan Tannar
//

#if os(iOS) || os(visionOS)
import UIKit

import Paint

/// The delegate of a ``ColorPickerViewController``, told when a color is selected
/// and when the picker finishes.
@available(iOS 14.0, macCatalyst 14.0, *)
@MainActor
public protocol ColorPickerViewControllerDelegate: AnyObject {

    /// Called when a color is selected.
    ///
    /// `continuously` is `true` while the color is still changing, such as while a
    /// slider is dragged, and `false` once it settles, matching
    /// `UIColorPickerViewControllerDelegate`.
    func colorPickerViewController(
        _ viewController: ColorPickerViewController,
        didSelect color: RGBAColor,
        continuously: Bool
    )

    /// Called when the picker is dismissed, or its close button is tapped.
    func colorPickerViewControllerDidFinish(_ viewController: ColorPickerViewController)
}

@available(iOS 14.0, macCatalyst 14.0, *)
extension ColorPickerViewControllerDelegate {

    public func colorPickerViewController(
        _ viewController: ColorPickerViewController,
        didSelect color: RGBAColor,
        continuously: Bool
    ) {}

    public func colorPickerViewControllerDidFinish(_ viewController: ColorPickerViewController) {}
}

/// A color picker in the style of `UIColorPickerViewController`, with pages for a
/// grid of swatches, a spectrum wheel of colors or of white light by temperature,
/// and sliders: RGB with HEX input, or perceptual hue, lightness, chroma and tone.
///
/// Every page edits colors in a ``ColorSpace``, chosen from the menu below it, so
/// colors outside sRGB, such as Display P3 colors, can be picked. Colors are reported
/// as extended sRGB ``RGBAColor``s, so they keep their wide gamut:
///
/// ```swift
/// let picker = ColorPickerViewController(color: HEXColor("#0A84FF"))
/// picker.delegate = self
/// // In a navigation controller, for its title and close button
/// present(UINavigationController(rootViewController: picker), animated: true)
///
/// func colorPickerViewController(
///     _ viewController: ColorPickerViewController,
///     didSelect color: RGBAColor,
///     continuously: Bool
/// ) {
///     view.backgroundColor = color.toUIColor()
/// }
/// ```
@available(iOS 14.0, macCatalyst 14.0, *)
open class ColorPickerViewController: UIViewController {

    /// The pages of the picker.
    @frozen
    public enum Mode: Int, Hashable, Sendable, CaseIterable {
        /// A grid of swatches.
        case grid
        /// A wheel of colors by hue and saturation, or of white light by temperature
        /// and tint, see ``ColorPickerViewController/spectrumStyle``.
        case spectrum
        /// RGB sliders and a HEX field, or perceptual sliders, see
        /// ``ColorPickerViewController/sliderStyle``.
        case sliders

        /// The title of the segment.
        public var title: String {
            switch self {
            case .grid: "Grid"
            case .spectrum: "Spectrum"
            case .sliders: "Sliders"
            }
        }
    }

    /// The wheels of the spectrum page.
    @frozen
    public enum SpectrumStyle: Int, Hashable, Sendable, CaseIterable {
        /// A wheel of colors by hue and saturation, with a brightness slider.
        case color
        /// A wheel of white light, from warm at the bottom to cool at the top, and
        /// from green on the left to magenta on the right, with temperature, tint and
        /// brightness sliders.
        case white
    }

    /// The sliders of the sliders page.
    @frozen
    public enum SliderStyle: Int, Hashable, Sendable, CaseIterable {
        /// Red, green and blue sliders in the color space, and a HEX field.
        case rgb
        /// Perceptual sliders: OKLCH hue, lightness and chroma, and tone, the CIE Lab
        /// lightness of Material Design's HCT, fitted to the gamut of the color space.
        case perceptual
    }

    // MARK: Public API

    public weak var delegate: (any ColorPickerViewControllerDelegate)?

    /// The selected color, as extended sRGB.
    ///
    /// Setting it updates every page and the original color of the selection
    /// preview, without calling the delegate.
    public var selectedColor: RGBAColor {
        get { color }
        set {
            var newValue = newValue
            if !supportsAlpha {
                newValue.alpha = 1
            }
            color = newValue
            originalColor = newValue
            revertedColor = nil
            if isViewLoaded {
                reloadPages(except: nil)
                updateColorViews()
            }
        }
    }

    /// Whether the opacity slider is shown. When `false`, colors are opaque.
    public var supportsAlpha = true {
        didSet {
            if !supportsAlpha {
                color.alpha = 1
            }
            if isViewLoaded {
                opacitySection.isHidden = !supportsAlpha
                updateColorViews()
            }
        }
    }

    /// The visible page.
    public var mode: Mode {
        didSet {
            if isViewLoaded {
                updateMode()
            }
        }
    }

    /// The wheel shown on the spectrum page.
    public var spectrumStyle: SpectrumStyle = .color {
        didSet {
            (pages[.spectrum] as? ColorPickerMenuPage)?.selectedIndex = spectrumStyle.rawValue
        }
    }

    /// The sliders shown on the sliders page.
    public var sliderStyle: SliderStyle = .rgb {
        didSet {
            (pages[.sliders] as? ColorPickerMenuPage)?.selectedIndex = sliderStyle.rawValue
        }
    }

    /// A preview of the original and selected colors, shown in the navigation bar.
    /// Tapping the original color reverts to it, and tapping it again restores the
    /// selected color, until another color is selected. Tapping the selected color
    /// shows a slider along its ``TonalScale``, for a lighter or darker shade.
    public let selectionPreviewView = ColorPickerSelectionPreviewView()

    /// The color space a page edits colors in.
    public func colorSpace(for mode: Mode) -> ColorSpace {
        colorSpaces[mode] ?? .sRGB
    }

    /// Sets the color space a page edits colors in.
    public func setColorSpace(_ colorSpace: ColorSpace, for mode: Mode) {
        colorSpaces[mode] = colorSpace
        if isViewLoaded {
            pages[mode]?.colorSpace = colorSpace
            if mode == self.mode {
                updateColorSpaceButton()
            }
        }
    }

    /// Creates a picker with a selected color.
    ///
    /// - Parameters:
    ///   - color: The selected color.
    ///   - mode: The visible page.
    ///   - colorSpace: The color space every page edits colors in, until it's
    ///     changed from its menu.
    public init<C: ColorConvertible>(
        color: C,
        mode: Mode = .grid,
        colorSpace: ColorSpace = .sRGB
    ) {
        let rgba = color.toRGBAColor()
        self.color = rgba
        self.originalColor = rgba
        self.mode = mode
        self.colorSpaces = Dictionary(uniqueKeysWithValues: Mode.allCases.map { ($0, colorSpace) })
        super.init(nibName: nil, bundle: nil)
    }

    /// Creates a picker with blue selected.
    public convenience init() {
        self.init(color: RGBAColor(red: 0, green: 0.478, blue: 1))
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: State

    private var color: RGBAColor
    private var originalColor: RGBAColor
    /// The selected color before it was reverted to the original color, restored by
    /// tapping the original color again. Selecting any other color discards it.
    private var revertedColor: RGBAColor?
    private var colorSpaces: [Mode: ColorSpace]
    private var pages: [Mode: ColorPickerPage] = [:]
    private var didNotifyFinish = false

    // MARK: Views

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let segmentedControl = UISegmentedControl()
    private let colorSpaceRow = ColorPickerMenuRow(title: "Color Space")
    private let opacitySection = UIStackView()
    private lazy var opacityRow = ColorSliderRow(
        title: "Opacity",
        format: ColorSliderRow.percent,
        parse: ColorSliderRow.parsePercent
    )
    private let headerView = UIView()
    /// The toolbar above the keyboard, shared by every value field of the picker,
    /// including those of the popovers it presents.
    let valueFieldToolbar = ColorValueFieldToolbar()
    /// Whether content scrolls beneath the pinned header, which needs the scroll
    /// edge effect of iOS 26 to stay legible.
    private var scrollsUnderHeader = false

    // MARK: Lifecycle

    open override func viewDidLoad() {
        super.viewDidLoad()

        // `String(localized:)` requires iOS 15
        title = NSLocalizedString("Color", bundle: .main, comment: "The title of the color picker")
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(closeTapped))

        selectionPreviewView.frame = CGRect(origin: .zero, size: selectionPreviewView.intrinsicContentSize)
        selectionPreviewView.addAction(UIAction { [weak self] _ in
            self?.revertTapped()
        }, for: .primaryActionTriggered)
        selectionPreviewView.selectedColorAction = UIAction(title: "Adjust Tone") { [weak self] _ in
            self?.presentTonalScale()
        }
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: selectionPreviewView)

        preferredContentSize = CGSize(width: 375, height: 640)

        setUpContent()
        updateMode()
        updateColorViews()
    }

    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        didNotifyFinish = false
    }

    open override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || navigationController?.isBeingDismissed == true || isMovingFromParent {
            notifyFinish()
        }
    }

    private func notifyFinish() {
        guard !didNotifyFinish else { return }
        didNotifyFinish = true
        delegate?.colorPickerViewControllerDidFinish(self)
    }

    // MARK: Layout

    private func setUpContent() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        #if !os(visionOS)
        scrollView.keyboardDismissMode = .interactive
        #endif
        scrollView.delaysContentTouches = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.clipsToBounds = false
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.preservesSuperviewLayoutMargins = true
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        let bottomAnchor: NSLayoutYAxisAnchor
        if #available(iOS 15.0, *) {
            bottomAnchor = view.keyboardLayoutGuide.topAnchor
        } else {
            bottomAnchor = view.bottomAnchor
        }
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            // Inset by the layout margins of the view, which include its safe area,
            // rather than of the scroll view, which would vary as it scrolls
            contentStack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
        ])

        setUpHeader()

        // Pages, with the spectrum and sliders menus below their content
        let pageStack = UIStackView()
        pageStack.axis = .vertical
        for mode in Mode.allCases {
            let page = makePage(for: mode)
            page.colorSpace = colorSpace(for: mode)
            page.onChange = { [weak self] color, continuously in
                self?.pageDidChange(mode, color: color, continuously: continuously)
            }
            pages[mode] = page
            pageStack.addArrangedSubview(page)
        }
        contentStack.addArrangedSubview(pageStack)
        contentStack.setCustomSpacing(20, after: pageStack)
        contentStack.addArrangedSubview(colorSpaceRow)
        contentStack.setCustomSpacing(20, after: colorSpaceRow)

        // Opacity
        opacitySection.axis = .vertical
        opacitySection.spacing = 20
        opacitySection.addArrangedSubview(makeSeparator())
        opacitySection.addArrangedSubview(opacityRow)
        opacitySection.isHidden = !supportsAlpha
        opacityRow.slider.showsCheckerboard = true
        opacityRow.onChange = { [weak self] value, continuously in
            self?.opacityDidChange(value, continuously: continuously)
        }
        contentStack.addArrangedSubview(opacitySection)
    }

    /// The page tabs, pinned above the scrolling content of every page, which
    /// scrolls beneath them.
    private func setUpHeader() {
        for (index, mode) in Mode.allCases.enumerated() {
            segmentedControl.insertSegment(withTitle: mode.title, at: index, animated: false)
        }
        segmentedControl.apportionsSegmentWidthsByContent = false
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)

        let headerStack = UIStackView(arrangedSubviews: [segmentedControl])
        headerStack.axis = .vertical
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.preservesSuperviewLayoutMargins = true
        headerView.addSubview(headerStack)
        view.addSubview(headerView)
        let margins = headerView.layoutMarginsGuide
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerStack.topAnchor.constraint(equalTo: margins.topAnchor),
            headerStack.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
            headerStack.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            headerStack.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
        ])

        #if XCODE_26
        if #available(iOS 26.0, visionOS 26.0, *) {
            // Content scrolls beneath the header, which joins the top edge effect of
            // the scroll view, so it stays legible without a background
            let interaction = UIScrollEdgeElementContainerInteraction()
            interaction.scrollView = scrollView
            interaction.edge = .top
            headerView.addInteraction(interaction)
            scrollsUnderHeader = true
            scrollView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        }
        #endif
        if !scrollsUnderHeader {
            // Without the edge effect, content would show through the navigation bar
            // and run into the header, so it scrolls below it instead
            scrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor).isActive = true
            headerView.backgroundColor = .systemBackground
            let separator = makeSeparator()
            headerView.addSubview(separator)
            NSLayoutConstraint.activate([
                separator.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
                separator.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
                separator.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            ])
        }
    }

    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Inset the content below the pinned header, keeping it at the top if it was
        let height = headerView.bounds.height
        guard scrollsUnderHeader, scrollView.contentInset.top != height else { return }
        let wasAtTop = scrollView.contentOffset.y <= -scrollView.adjustedContentInset.top + 0.5
        scrollView.contentInset.top = height
        scrollView.verticalScrollIndicatorInsets.top = height
        if wasAtTop {
            scrollView.contentOffset.y = -scrollView.adjustedContentInset.top
        }
    }

    private func makePage(for mode: Mode) -> ColorPickerPage {
        switch mode {
        case .grid: return ColorGridPage()
        case .spectrum:
            let page = ColorPickerMenuPage(title: "Spectrum", options: [
                ("Color", ColorHueWheelPage()),
                ("White", ColorTemperaturePage()),
            ])
            page.selectedIndex = spectrumStyle.rawValue
            page.onSelectionChange = { [weak self] index in
                self?.spectrumStyle = SpectrumStyle(rawValue: index) ?? .color
            }
            return page
        case .sliders:
            let page = ColorPickerMenuPage(title: "Sliders", options: [
                ("RGB", ColorRGBSlidersPage()),
                ("Perceptual", ColorAdjustmentsPage()),
            ])
            page.selectedIndex = sliderStyle.rawValue
            page.onSelectionChange = { [weak self] index in
                self?.sliderStyle = SliderStyle(rawValue: index) ?? .rgb
            }
            return page
        }
    }

    private func makeSeparator() -> UIView {
        let separator = UIView()
        separator.backgroundColor = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.heightAnchor.constraint(equalToConstant: 1 / max(view.traitCollection.displayScale, 1)).isActive = true
        return separator
    }

    // MARK: Updates

    private func updateMode() {
        if segmentedControl.selectedSegmentIndex != mode.rawValue {
            segmentedControl.selectedSegmentIndex = mode.rawValue
        }
        for (mode, page) in pages {
            page.isHidden = mode != self.mode
        }
        reloadPages(except: nil)
        updateColorSpaceButton()
    }

    private func updateColorSpaceButton() {
        let mode = self.mode
        colorSpaceRow.update(
            options: ColorSpace.allCases,
            selected: colorSpace(for: mode),
            title: \.description
        ) { [weak self] space in
            self?.setColorSpace(space, for: mode)
        }
    }

    /// Loads the selected color into the visible page, unless it's the page that
    /// chose it. Hidden pages are loaded when they're shown, since rendering their
    /// tracks for every change while dragging would be wasted.
    private func reloadPages(except source: Mode?) {
        guard mode != source, let page = pages[mode] else { return }
        var opaque = color
        opaque.alpha = 1
        page.setColor(opaque)
    }

    private func updateColorViews() {
        opacityRow.value = color.alpha
        var opaque = color
        opaque.alpha = 1
        opacityRow.slider.thumbColor = opaque
        opacityRow.slider.setTrack(samples: 2) { t in
            var color = opaque
            color.alpha = t
            return color
        }
        selectionPreviewView.originalColor = originalColor
        selectionPreviewView.selectedColor = color
        selectionPreviewView.accessibilityHint = revertedColor != nil && color == revertTarget
            ? "Restores the selected color"
            : "Reverts to the original color"
    }

    /// Selects a color chosen on a page. Internal for tests.
    func pageDidChange(_ mode: Mode, color: RGBAColor, continuously: Bool) {
        var color = color
        color.alpha = supportsAlpha ? self.color.alpha : 1
        self.color = color
        revertedColor = nil
        reloadPages(except: mode)
        updateColorViews()
        delegate?.colorPickerViewController(self, didSelect: color, continuously: continuously)
    }

    private func opacityDidChange(_ alpha: Double, continuously: Bool) {
        color.alpha = alpha
        revertedColor = nil
        updateColorViews()
        delegate?.colorPickerViewController(self, didSelect: color, continuously: continuously)
    }

    // MARK: Actions

    @objc private func segmentChanged() {
        guard let mode = Mode(rawValue: segmentedControl.selectedSegmentIndex) else { return }
        view.endEditing(true)
        self.mode = mode
    }

    @objc private func closeTapped() {
        view.endEditing(true)
        if presentingViewController != nil {
            dismiss(animated: true) { [weak self] in
                self?.notifyFinish()
            }
        } else {
            notifyFinish()
        }
    }

    /// Shows a popover with a slider along the tonal scale of the selected color,
    /// fitted to the gamut of the visible page's color space.
    private func presentTonalScale() {
        guard presentedViewController == nil else { return }
        view.endEditing(true)
        let toneViewController = ColorPickerToneViewController(
            color: color,
            gamut: colorSpace(for: mode).toColorGamut(),
            valueFieldToolbar: valueFieldToolbar
        )
        toneViewController.onChange = { [weak self] color, continuously in
            self?.toneDidChange(color, continuously: continuously)
        }
        if let popover = toneViewController.popoverPresentationController {
            popover.sourceView = selectionPreviewView
            popover.sourceRect = selectionPreviewView.selectedColorFrame
            popover.permittedArrowDirections = [.up, .down]
        }
        present(toneViewController, animated: true)
    }

    private func toneDidChange(_ color: RGBAColor, continuously: Bool) {
        var color = color
        if !supportsAlpha {
            color.alpha = 1
        }
        self.color = color
        revertedColor = nil
        reloadPages(except: nil)
        updateColorViews()
        delegate?.colorPickerViewController(self, didSelect: color, continuously: continuously)
    }

    /// The original color, opaque when the picker doesn't support alpha.
    private var revertTarget: RGBAColor {
        var color = originalColor
        if !supportsAlpha {
            color.alpha = 1
        }
        return color
    }

    /// Reverts to the original color, keeping the selected color so that tapping
    /// again restores it.
    private func revertTapped() {
        if color != revertTarget {
            revertedColor = color
            color = revertTarget
        } else if var revertedColor {
            self.revertedColor = nil
            if !supportsAlpha {
                revertedColor.alpha = 1
            }
            color = revertedColor
        } else {
            return
        }
        reloadPages(except: nil)
        updateColorViews()
        delegate?.colorPickerViewController(self, didSelect: color, continuously: false)
    }
}

@available(iOS 14.0, macCatalyst 14.0, *)
extension ColorPickerViewController: ColorValueFieldToolbarProviding {}
#endif
