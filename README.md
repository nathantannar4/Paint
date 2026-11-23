<img src="./Logo.png" width="128"> 

# Paint

Paint is a color library for Swift, with platform support for SwiftUI/UIKit/AppKit. It converts between color models, adjusts colors perceptually in OKLCH, measures contrast with WCAG 2 and APCA, and generates palettes. It is wide gamut and HDR aware throughout, so Display P3 and HDR colors keep their gamut and brightness. `PaintUI` adds a UIKit color picker that edits colors in any of those color spaces.


## See Also

- [Engine](https://github.com/nathantannar4/Engine)
- [Turbocharger](https://github.com/nathantannar4/Turbocharger)
- [Transmission](https://github.com/nathantannar4/Transmission)
- [Metallic](https://github.com/nathantannar4/Metallic)
- [Ignition](https://github.com/nathantannar4/Ignition)

## Requirements

- Deployment target: iOS 13.0, macOS 10.15, Mac Catalyst 13.0, tvOS 13.0, watchOS 6.0 or visionOS 1.0
- `PaintUI`: iOS 14.0, Mac Catalyst 14.0 or visionOS 1.0
- Xcode 16.4+

## Installation

### Xcode Projects

Select `File` -> `Add Package Dependencies...` and enter `https://github.com/nathantannar4/Paint`. Add the `Paint` library to your target, and `PaintUI` for the color picker.

### Swift Package Manager Projects

You can add `Paint` as a package dependency in your `Package.swift` file:

```swift
let package = Package(
    //...
    dependencies: [
        .package(url: "https://github.com/nathantannar4/Paint"),
    ],
    targets: [
        .target(
            name: "YourPackageTarget",
            dependencies: [
                .product(name: "Paint", package: "Paint"),
                // For the color picker
                .product(name: "PaintUI", package: "Paint"),
            ],
            //...
        ),
        //...
    ],
    //...
)
```

## Documentation

Detailed documentation is available [here](https://swiftpackageindex.com/nathantannar4/Paint/main/documentation/paint).

#### Introduction to Paint

For some sample code to get started with Paint, build and run the included "Example" project.

### Color Models

Every color model conforms to `ColorConvertible`, so any color converts to any other, and to `Color`, `UIColor`, `NSColor`, `CGColor` and `CIColor`.

- `RGBAColor`, `HEXColor`, `HSBAColor`, `HSLAColor`, `HWBColor` and `CMYKColor`
- `OKLCHColor` and `OKLabColor`, which are perceptually uniform
- `CIELabColor`, `CIELCHColor` and `XYZColor`
- `CSSColor`, which keeps the CSS color string it was decoded from

```swift
let orange: HEXColor = "#FF8000"
let oklch = orange.toOKLCHColor()
let color = oklch.toColor()
```

`RGBAColor` is extended sRGB. `RGBAColor(red:green:blue:colorSpace:)` and `toComponents(in:)` convert to and from the components of another `ColorSpace`, such as Display P3, linear sRGB or BT.2020, at `Double` precision and without ColorSync.

```swift
let red = RGBAColor(red: 1, green: 0, blue: 0, colorSpace: .displayP3)
let p3 = orange.toRGBAColor().toComponents(in: .displayP3)
```

### Adjustments

Adjustments are made in OKLCH, so lightening a color keeps its hue and how colorful it looks. Results are fitted to a `ColorGamut` (`.sRGB`, `.displayP3` or `.rec2020`).

```swift
let hover = accent.lightened(by: 0.1)
let muted = accent.saturated(by: -0.05)
let mix = accent.mixed(with: HEXColor("#FFFFFF"), by: 0.25)
let rotated = accent.hueRotated(by: .degrees(30))
let dark = accent.adapted(from: HEXColor("#FFFFFF"), to: HEXColor("#000000"))
```

`adapted(from:to:)` moves a color to a new background, such as for dark mode, keeping its contrast and hue. `withProminence(_:against:)` fades a color for secondary, tertiary and quaternary content, like the system label colors.

### Contrast and Accessibility

- `contrast(.wcag)` and `contrast(.apca)` measure a color with the WCAG 2 or APCA algorithm, with the same API for each
- `against(_:)` gives a `WCAGContrast`, with levels such as `.aa` and `.aaa`, or an `APCAContrast` in Lc
- `adjusted(toMinimum:against:)` changes only the lightness, as little as needed, to meet a minimum contrast
- `increased(against:by:)` raises APCA contrast, for increased contrast variants
- `luminance`, `isDark` and `isLight` measure a color by the algorithm's luminance, and pick text colors
- `simulating(_:severity:)` and `daltonized(for:severity:)` simulate and correct for a `ColorVisionDeficiency`

```swift
let passesAA = text.contrast(.wcag).against(background).meets(.aa)
let readable = text.contrast(.apca).adjusted(toMinimum: 60, against: background)
```

`distance(to:)` and `deltaE2000(to:)` measure how different two colors look, and `nearest(to:)` and `removingNearDuplicates(threshold:)` find and remove similar colors in a collection.

### Palettes and Generation

- `TonalScale` generates `50` to `950` shades from a seed color, like Tailwind CSS
- `harmony(_:)` generates complementary, analogous, triadic and other `ColorHarmony` schemes
- `OKLCHColor.categorical(count:)` generates evenly spaced, distinct colors for charts
- `OKLCHColor(hashing:)` generates a stable color from a string, such as a user name
- `ColorGradient` interpolates in any CSS color space, such as Oklab, OKLCH, LCh (HCL) or HSL, with an optional easing curve, and adds just enough stops to look the same in SwiftUI, Core Animation and Core Graphics, which each blend differently

```swift
let blue = TonalScale(seed: HEXColor("#3B82F6"))
let background = blue[50]
let text = blue[900]

let triad = accent.harmony(.triadic)

let gradient = ColorGradient(colors: [HEXColor("#0033FF"), HEXColor("#FFE600")], in: .oklch)
let shade = ColorGradient(from: HEXColor("#000000"), to: RGBAColor(red: 0, green: 0, blue: 0, alpha: 0), curve: .easeInOut)
LinearGradient(gradient: gradient.toGradient(), startPoint: .leading, endPoint: .trailing)
gradientLayer.setGradient(gradient) // CAGradientLayer
```

### Images

`ImageColorPalette` finds the background color of an image and text colors that read on it. `ImageColorSwatches` finds vibrant and muted swatches. Both are available on `CGImage`, `UIImage`, `NSImage` and image files, with `async` variants that always run off the main actor, and Combine publishers. Images at a file URL are decoded at the scaled size, so the full image is never loaded into memory.

```swift
let palette = await image.toColorPalette(quality: .low)
let swatches = await image.toColorSwatches(quality: .low)
let fromFile = await ImageColorPalette(contentsOf: url, quality: .low)

image.toColorPalettePublisher(quality: .low)
    .receive(on: DispatchQueue.main)
    .sink { palette in ... }
```

### CSS

`CSSColor` is a color written as a CSS color string. It decodes CSS Color 4 syntax, such as `#RRGGBB`, named colors, `rgb()`, `hsl()`, `oklch()` and `color(display-p3 ...)`, and keeps the string exactly as written. `toCSSColor(_:)` writes any color in a `CSSColorFormat`.

```swift
let accent = CSSColor(decoding: "oklch(0.7 0.15 250)")
let named: CSSColor = "rebeccapurple"
let hsl = HEXColor("#FF8000").toCSSColor(.hsl) // "hsl(30.118 100% 50%)"
```

### HDR and Color Temperature

- `contentHeadroom` and `isHDR` measure how much brighter than SDR white a color is, and `toStandardDynamicRange()` gives an SDR fallback
- On iOS 26, macOS 26 and later, `Color`, `UIColor`, `NSColor` and `CGColor` created from an HDR color are tagged with its headroom, so the system tone maps it for the display
- `RGBAColor(kelvin:)` creates the color of white light at a temperature, and `toCorrelatedColorTemperature()` estimates the temperature of a color

### Formatting

`formatted(_:)` writes any color with a `ColorFormatStyle`, which also parses HEX and CSS color strings.

```swift
HEXColor("#FF8000").formatted(.hex)       // "FF8000"
HEXColor("#FF8000").formatted(.css(.hsl)) // "hsl(30.118 100% 50%)"
```

### Blending and Color Matrices

- `blended(over:mode:)` blends colors with any `ColorBlendMode` from the W3C Compositing spec
- `ColorTransform` is a color matrix, with filters such as `.grayscale()`, `.sepia()`, `.saturation(_:)` and `.hueRotation(_:)`, that converts with `toSwiftUI()` for the SwiftUI `_colorMatrix(_:)` modifier

### SwiftUI, UIKit and AppKit

`ColorStyle` is a `ShapeStyle` for any color, with a color for each color scheme and contrast. `UIColor(light:dark:)` and `NSColor(light:dark:)` create dynamic colors in the same way.

```swift
Rectangle()
    .fill(ColorStyle(light: accent, dark: accent.adapted(from: HEXColor("#FFFFFF"), to: HEXColor("#000000"))))
```

`Color.transformed(_:)` returns a `ShapeStyle` that resolves system and adaptive colors in the current environment before transforming them. The transform follows the color scheme, contrast and tint.

```swift
Text("Pressed")
    .foregroundStyle(Color.accentColor.transformed { $0.darkened(by: 0.1) })
```

`ColorStyle` and `Color.transformed(_:)` require iOS 17, macOS 14, tvOS 17 or watchOS 10.

## PaintUI

`ColorPickerViewController` is a color picker in the style of `UIColorPickerViewController`, for iOS 14, Mac Catalyst 14 and visionOS. It has pages for a grid of swatches, a spectrum wheel of colors or of white light by temperature, and RGB or perceptual sliders. Every page edits colors in a `ColorSpace`, such as Display P3, and colors are reported as extended sRGB `RGBAColor`s, so they keep their wide gamut. `ColorPickerLabel` shows a color like the well of `UIColorWell`.

```swift
let picker = ColorPickerViewController(color: HEXColor("#0A84FF"))
picker.delegate = self
present(UINavigationController(rootViewController: picker), animated: true)

func colorPickerViewController(
    _ viewController: ColorPickerViewController,
    didSelect color: RGBAColor,
    continuously: Bool
) {
    view.backgroundColor = color.toUIColor()
}
```

## License

Distributed under the BSD 2-Clause License. See ``LICENSE.md`` for more information.
