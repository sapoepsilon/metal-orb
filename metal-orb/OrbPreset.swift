import Foundation
import SwiftUI

public struct OrbColor: Equatable, Sendable {
    public var r: Float
    public var g: Float
    public var b: Float

    public var simd: SIMD3<Float> { SIMD3<Float>(r, g, b) }
    public var swiftColor: Color { Color(red: Double(r), green: Double(g), blue: Double(b)) }

    public init(_ r: Float, _ g: Float, _ b: Float) {
        self.r = r; self.g = g; self.b = b
    }

    public init(simd: SIMD3<Float>) {
        self.r = simd.x; self.g = simd.y; self.b = simd.z
    }
}

public struct OrbPresetValues: Equatable, Sendable {
    public var amplitude: Float
    public var frequency: Float
    public var micSensitivity: Float
    public var lightAngle: Float
    public var lightIntensity: Float
    public var noiseType: Int32
    public var wireframe: Bool
    public var spherify: Float
    public var subdivision: Int
    public var zoom: Float
    public var colorByNoise: Bool
    public var noiseOffsetX: Float
    public var noiseOffsetY: Float
    public var noiseOffsetZ: Float
    public var showGrid: Bool
    public var vizMode: Int32
    public var layerCount: Int32
    public var temperatureMode: Bool
    public var baseOpacity: Float
    public var audioReactivity: Float
    public var heatIntensity: Float
    public var edgeGlow: Float
    public var color1: OrbColor
    public var color2: OrbColor
    public var color3: OrbColor
    public var color4: OrbColor

    public init(
        amplitude: Float = 0.15, frequency: Float = 5.0, micSensitivity: Float = 1.0,
        lightAngle: Float = 0.785, lightIntensity: Float = 1.0, noiseType: Int32 = 0,
        wireframe: Bool = false, spherify: Float = 1.0, subdivision: Int = 6,
        zoom: Float = 1.0, colorByNoise: Bool = false,
        noiseOffsetX: Float = 0, noiseOffsetY: Float = 0, noiseOffsetZ: Float = 0,
        showGrid: Bool = false, vizMode: Int32 = 0, layerCount: Int32 = 5,
        temperatureMode: Bool = true, baseOpacity: Float = 0.7,
        audioReactivity: Float = 1.0, heatIntensity: Float = 1.0, edgeGlow: Float = 1.0,
        color1: OrbColor = OrbColor(0.0, 0.9, 1.0),
        color2: OrbColor = OrbColor(0.7, 0.3, 1.0),
        color3: OrbColor = OrbColor(1.0, 0.5, 0.1),
        color4: OrbColor = OrbColor(0.2, 1.0, 0.4)
    ) {
        self.amplitude = amplitude; self.frequency = frequency
        self.micSensitivity = micSensitivity; self.lightAngle = lightAngle
        self.lightIntensity = lightIntensity; self.noiseType = noiseType
        self.wireframe = wireframe; self.spherify = spherify
        self.subdivision = subdivision; self.zoom = zoom
        self.colorByNoise = colorByNoise
        self.noiseOffsetX = noiseOffsetX; self.noiseOffsetY = noiseOffsetY
        self.noiseOffsetZ = noiseOffsetZ; self.showGrid = showGrid
        self.vizMode = vizMode; self.layerCount = layerCount
        self.temperatureMode = temperatureMode; self.baseOpacity = baseOpacity
        self.audioReactivity = audioReactivity; self.heatIntensity = heatIntensity
        self.edgeGlow = edgeGlow
        self.color1 = color1; self.color2 = color2
        self.color3 = color3; self.color4 = color4
    }
}

public enum OrbPreset: String, CaseIterable, Identifiable, Sendable {
    case transparent
    case subtle

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .transparent: return "Transparent"
        case .subtle: return "Subtle"
        }
    }

    public var values: OrbPresetValues {
        switch self {
        case .transparent:
            return OrbPresetValues()

        case .subtle:
            return OrbPresetValues(
                amplitude: 0.12, frequency: 4.0,
                lightIntensity: 0.8,
                baseOpacity: 0.85, audioReactivity: 0.4,
                heatIntensity: 0.5, edgeGlow: 0.4
            )
        }
    }
}
