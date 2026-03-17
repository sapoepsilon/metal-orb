# MetalOrb

A SwiftUI component that renders an audio-reactive 3D orb using Metal. Multiple noise layers overlap and respond to microphone input with configurable color temperature, opacity, and edge glow.

![macOS](https://img.shields.io/badge/platform-macOS%2014%2B-blue)
![Swift](https://img.shields.io/badge/swift-5.9%2B-orange)

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ismatullamansurov/metal-orb.git", from: "1.0.0")
]
```

Or in Xcode: **File → Add Package Dependencies** → paste the URL.

## Usage

### Minimal

```swift
import SwiftUI
import MetalOrb

struct MyView: View {
    @State private var preset = OrbPreset.transparent.values

    var body: some View {
        MetalOrbView(preset: $preset)
            .frame(width: 400, height: 400)
    }
}
```

### With Microphone Audio

```swift
import SwiftUI
import MetalOrb

struct AudioOrbView: View {
    @StateObject private var audio = AudioInputManager()
    @State private var preset = OrbPreset.transparent.values

    var body: some View {
        VStack {
            MetalOrbView(
                preset: $preset,
                audioLevel: audio.audioLevel,
                audioBands: SIMD4(audio.bass, audio.mid, audio.high, audio.treble)
            )
            .frame(width: 400, height: 400)

            Button(audio.isRunning ? "Stop Mic" : "Start Mic") {
                audio.isRunning ? audio.stop() : audio.start()
            }
        }
    }
}
```

### Drag to Rotate

```swift
@State private var rotationX: Float = 0
@State private var rotationY: Float = 0

MetalOrbView(
    preset: $preset,
    rotationX: $rotationX,
    rotationY: $rotationY
)
```

### Switch Presets

```swift
// Built-in presets
preset = OrbPreset.transparent.values  // vibrant, reactive
preset = OrbPreset.subtle.values       // muted, more opaque

// Or tweak individual values
preset.baseOpacity = 0.9
preset.audioReactivity = 0.5
preset.heatIntensity = 0.3
preset.edgeGlow = 0.8
preset.color1 = OrbColor(0.2, 0.5, 1.0)
preset.layerCount = 8
preset.frequency = 10.0
```

## API Reference

### MetalOrbView

| Parameter | Type | Description |
|-----------|------|-------------|
| `preset` | `Binding<OrbPresetValues>` | All visual configuration |
| `rotationX` | `Binding<Float>` | Vertical rotation (optional) |
| `rotationY` | `Binding<Float>` | Horizontal rotation (optional) |
| `audioLevel` | `Float` | Overall audio level 0–1 |
| `audioBands` | `SIMD4<Float>` | Bass, mid, high, treble (0–1 each) |

### OrbPresetValues

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `amplitude` | `Float` | 0.15 | Noise displacement strength |
| `frequency` | `Float` | 5.0 | Noise cell density |
| `layerCount` | `Int32` | 5 | Number of overlapping shells |
| `baseOpacity` | `Float` | 0.7 | How solid the orb appears |
| `audioReactivity` | `Float` | 1.0 | How much audio affects visuals |
| `heatIntensity` | `Float` | 1.0 | Color temperature shift at peaks |
| `edgeGlow` | `Float` | 1.0 | Brightness at rough edges |
| `temperatureMode` | `Bool` | true | Single color with heat shift |
| `color1–4` | `OrbColor` | cyan/purple/orange/green | Colors for gradient or base |
| `subdivision` | `Int` | 6 | Mesh resolution (0–9) |
| `zoom` | `Float` | 1.0 | Camera zoom |
| `wireframe` | `Bool` | false | Wireframe rendering |
| `showGrid` | `Bool` | false | Show noise grid cells |
| `noiseType` | `Int32` | 0 | 0 = Simplex, 1 = Perlin |
| `micSensitivity` | `Float` | 1.0 | Audio input gain |
| `lightAngle` | `Float` | 0.785 | Light direction angle |
| `lightIntensity` | `Float` | 1.0 | Light brightness |

### OrbPreset

| Case | Description |
|------|-------------|
| `.transparent` | Vibrant, fully reactive, semi-transparent layers |
| `.subtle` | More opaque, gentle reactivity, softer edges |

### AudioInputManager

Handles microphone input with FFT frequency band extraction.

```swift
@StateObject var audio = AudioInputManager()

audio.start()     // request mic permission and begin capture
audio.stop()      // stop capture

audio.audioLevel  // overall RMS level (0–1)
audio.bass        // ~0–300Hz band (0–1)
audio.mid         // ~300Hz–2kHz band (0–1)
audio.high        // ~2kHz–6kHz band (0–1)
audio.treble      // ~6kHz+ band (0–1)
audio.isRunning   // capture state
```

## Requirements

- macOS 14+
- Swift 5.9+
- Metal-capable GPU
- Microphone permission (for audio features): add `NSMicrophoneUsageDescription` to Info.plist and `com.apple.security.device.audio-input` entitlement

## License

MIT
