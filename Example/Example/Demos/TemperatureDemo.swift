//
// Copyright (c) Nathan Tannar
//

import SwiftUI
import Paint

/// Colors of light by temperature, and the temperature of a color.
struct TemperatureDemo: View {

    @State private var kelvin = 6500.0
    @State private var color = RGBAColor(red: 1, green: 0.85, blue: 0.7)

    var body: some View {
        DemoPage("Temperature") {
            DemoSection(
                "Color of Light",
                caption: "RGBAColor(kelvin:) is the color of a black body at a temperature, normalized so its brightest component is 1, as for white balance or light sources."
            ) {
                LabeledSlider("Kelvin", value: $kelvin, in: 1000...12000, digits: 0)
                let light = RGBAColor(kelvin: kelvin)
                Swatch(light, label: "\(Int(kelvin)) K", detail: light.toHEXColor().toString(includePrefix: true), height: 80)
                LinearGradient(
                    colors: stride(from: 1000.0, through: 12000, by: 500).map { Color(RGBAColor(kelvin: $0)) },
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                HStack {
                    Text("1000 K")
                    Spacer()
                    Text("12000 K")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            DemoSection(
                "Temperature of a Color",
                caption: "toCorrelatedColorTemperature() estimates the temperature of the nearest black body, for warm and cool whites, and toCorrelatedColorTemperatureString() writes it, like \"6505 K\". Both are nil for colors far from white, such as saturated or very dark colors."
            ) {
                ColorField("Color", color: $color, supportsOpacity: true)
                Swatch(color, height: 64)
                if let cct = color.toCorrelatedColorTemperature(),
                   let string = color.toCorrelatedColorTemperatureString() {
                    Text(string)
                        .font(.title2.monospacedDigit().weight(.semibold))
                    HStack(spacing: 4) {
                        Swatch(color, label: "Color")
                        Swatch(RGBAColor(kelvin: cct), label: "RGBAColor(kelvin: \(Int(cct)))")
                    }
                } else {
                    Text("nil: too far from white")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    NavigationStack { TemperatureDemo() }
}
