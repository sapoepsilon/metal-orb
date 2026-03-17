import SwiftUI

struct ContentView: View {
    @StateObject private var audioManager = AudioInputManager()
    @State private var micEnabled: Bool = false
    @State private var currentPreset: OrbPreset = .transparent
    @State private var presetValues: OrbPresetValues = OrbPreset.transparent.values

    @State private var rotationX: Float = 0
    @State private var rotationY: Float = 0
    @State private var previousTranslation: CGSize = .zero

    @State private var swiftColor1 = OrbPreset.transparent.values.color1.swiftColor
    @State private var swiftColor2 = OrbPreset.transparent.values.color2.swiftColor
    @State private var swiftColor3 = OrbPreset.transparent.values.color3.swiftColor
    @State private var swiftColor4 = OrbPreset.transparent.values.color4.swiftColor

    var body: some View {
        VStack(spacing: 0) {
            MetalOrbView(
                preset: $presetValues,
                rotationX: $rotationX,
                rotationY: $rotationY,
                audioLevel: audioManager.audioLevel,
                audioBands: SIMD4<Float>(audioManager.bass, audioManager.mid, audioManager.high, audioManager.treble)
            )
            .frame(minWidth: 400, minHeight: 300)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let deltaX = value.translation.width - previousTranslation.width
                        let deltaY = value.translation.height - previousTranslation.height
                        rotationY += Float(deltaX) * 0.01
                        rotationX += Float(deltaY) * 0.01
                        previousTranslation = value.translation
                    }
                    .onEnded { _ in previousTranslation = .zero }
            )

            VStack(spacing: 6) {
                HStack(spacing: 16) {
                    Text("Preset:")
                        .fontWeight(.medium)
                    Picker("", selection: $currentPreset) {
                        ForEach(OrbPreset.allCases) { preset in
                            Text(preset.label).tag(preset)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                    .onChange(of: currentPreset) { applyPreset(currentPreset) }

                    Divider().frame(height: 20)

                    Toggle("Wireframe", isOn: $presetValues.wireframe)
                        .toggleStyle(.checkbox)
                    Toggle("Grid", isOn: $presetValues.showGrid)
                        .toggleStyle(.checkbox)

                    Divider().frame(height: 20)

                    Toggle("Mic", isOn: $micEnabled)
                        .toggleStyle(.checkbox)
                        .onChange(of: micEnabled) {
                            micEnabled ? audioManager.start() : audioManager.stop()
                        }
                    Text("Sens:")
                        .foregroundColor(.secondary)
                    Slider(value: $presetValues.micSensitivity, in: 0.5...8.0)
                        .frame(width: 60)
                        .disabled(!micEnabled)

                    Divider().frame(height: 20)

                    Text("Layers:")
                        .foregroundColor(.secondary)
                    Stepper("\(presetValues.layerCount)", value: $presetValues.layerCount, in: 1...10)

                    Spacer()

                    Button("Reset View") { rotationX = 0; rotationY = 0 }
                        .buttonStyle(.bordered)
                }

                Divider()

                HStack(spacing: 24) {
                    HStack(spacing: 8) {
                        Text("Algorithm:")
                            .foregroundColor(.secondary)
                        Picker("", selection: $presetValues.noiseType) {
                            Text("Simplex").tag(Int32(0))
                            Text("Perlin").tag(Int32(1))
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 120)
                    }

                    HStack(spacing: 8) {
                        Text("Amp:")
                            .foregroundColor(.secondary)
                        Slider(value: $presetValues.amplitude, in: 0...0.5)
                            .frame(width: 60)
                        Text("Freq:")
                            .foregroundColor(.secondary)
                        Slider(value: $presetValues.frequency, in: 0.5...20)
                            .frame(width: 60)
                    }

                    HStack(spacing: 8) {
                        Text("Offset:")
                            .foregroundColor(.secondary)
                        Text("X").font(.caption)
                        Slider(value: $presetValues.noiseOffsetX, in: -2...2)
                            .frame(width: 40)
                        Text("Y").font(.caption)
                        Slider(value: $presetValues.noiseOffsetY, in: -2...2)
                            .frame(width: 40)
                        Text("Z").font(.caption)
                        Slider(value: $presetValues.noiseOffsetZ, in: -2...2)
                            .frame(width: 40)
                    }
                }

                Divider()

                HStack(spacing: 24) {
                    HStack(spacing: 8) {
                        Text("Geometry:")
                            .foregroundColor(.secondary)
                        Stepper("Level \(presetValues.subdivision)", value: $presetValues.subdivision, in: 0...9)
                        Text("Zoom:")
                            .foregroundColor(.secondary)
                        Slider(value: $presetValues.zoom, in: 0.3...3)
                            .frame(width: 60)
                    }

                    HStack(spacing: 8) {
                        Text("Light:")
                            .foregroundColor(.secondary)
                        Slider(value: $presetValues.lightAngle, in: 0...Float.pi * 2)
                            .frame(width: 60)
                        Text("Int:")
                            .foregroundColor(.secondary)
                        Slider(value: $presetValues.lightIntensity, in: 0...2)
                            .frame(width: 60)
                    }

                    HStack(spacing: 8) {
                        Toggle("Temp", isOn: $presetValues.temperatureMode)
                            .toggleStyle(.checkbox)
                        if presetValues.temperatureMode {
                            Text("Base:")
                                .foregroundColor(.secondary)
                            ColorPicker("", selection: $swiftColor1)
                                .labelsHidden()
                                .onChange(of: swiftColor1) { presetValues.color1 = OrbColor(simd: colorToSimd(swiftColor1)) }
                        } else {
                            Text("Colors:")
                                .foregroundColor(.secondary)
                            ColorPicker("", selection: $swiftColor1)
                                .labelsHidden()
                                .onChange(of: swiftColor1) { presetValues.color1 = OrbColor(simd: colorToSimd(swiftColor1)) }
                            ColorPicker("", selection: $swiftColor2)
                                .labelsHidden()
                                .onChange(of: swiftColor2) { presetValues.color2 = OrbColor(simd: colorToSimd(swiftColor2)) }
                            ColorPicker("", selection: $swiftColor3)
                                .labelsHidden()
                                .onChange(of: swiftColor3) { presetValues.color3 = OrbColor(simd: colorToSimd(swiftColor3)) }
                            ColorPicker("", selection: $swiftColor4)
                                .labelsHidden()
                                .onChange(of: swiftColor4) { presetValues.color4 = OrbColor(simd: colorToSimd(swiftColor4)) }
                        }
                    }
                }

                Divider()

                HStack(spacing: 24) {
                    HStack(spacing: 8) {
                        Text("Opacity:")
                            .foregroundColor(.secondary)
                        Slider(value: $presetValues.baseOpacity, in: 0.1...1.0)
                            .frame(width: 60)
                    }
                    HStack(spacing: 8) {
                        Text("Reactivity:")
                            .foregroundColor(.secondary)
                        Slider(value: $presetValues.audioReactivity, in: 0...2.0)
                            .frame(width: 60)
                    }
                    HStack(spacing: 8) {
                        Text("Heat:")
                            .foregroundColor(.secondary)
                        Slider(value: $presetValues.heatIntensity, in: 0...2.0)
                            .frame(width: 60)
                    }
                    HStack(spacing: 8) {
                        Text("Edge Glow:")
                            .foregroundColor(.secondary)
                        Slider(value: $presetValues.edgeGlow, in: 0...2.0)
                            .frame(width: 60)
                    }
                }
            }
            .padding(10)
            .background(Color(white: 0.12))
        }
        .background(Color(white: 0.05))
    }

    private func applyPreset(_ preset: OrbPreset) {
        presetValues = preset.values
        swiftColor1 = preset.values.color1.swiftColor
        swiftColor2 = preset.values.color2.swiftColor
        swiftColor3 = preset.values.color3.swiftColor
        swiftColor4 = preset.values.color4.swiftColor
    }

    func colorToSimd(_ color: Color) -> SIMD3<Float> {
        let nsColor = NSColor(color).usingColorSpace(.sRGB) ?? NSColor.white
        return SIMD3<Float>(
            Float(nsColor.redComponent),
            Float(nsColor.greenComponent),
            Float(nsColor.blueComponent)
        )
    }
}

#Preview {
    ContentView()
}
