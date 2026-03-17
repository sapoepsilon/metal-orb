import SwiftUI
import MetalKit

public struct MetalOrbView: NSViewRepresentable {
    @Binding public var preset: OrbPresetValues
    @Binding public var rotationX: Float
    @Binding public var rotationY: Float
    public var audioLevel: Float
    public var audioBands: SIMD4<Float>

    public init(
        preset: Binding<OrbPresetValues>,
        rotationX: Binding<Float> = .constant(0),
        rotationY: Binding<Float> = .constant(0),
        audioLevel: Float = 0,
        audioBands: SIMD4<Float> = .zero
    ) {
        self._preset = preset
        self._rotationX = rotationX
        self._rotationY = rotationY
        self.audioLevel = audioLevel
        self.audioBands = audioBands
    }

    public func makeCoordinator() -> Coordinator { Coordinator() }

    public func makeNSView(context: Context) -> MTKView {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }

        let mtkView = MTKView(frame: .zero, device: device)
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.depthStencilPixelFormat = .depth32Float
        mtkView.clearColor = MTLClearColor(red: 0.02, green: 0.02, blue: 0.04, alpha: 1.0)
        mtkView.preferredFramesPerSecond = 60

        if let renderer = OrbRenderer(device: device) {
            context.coordinator.renderer = renderer
            mtkView.delegate = renderer
        }

        return mtkView
    }

    public func updateNSView(_ nsView: MTKView, context: Context) {
        guard let renderer = context.coordinator.renderer else { return }
        let v = preset

        renderer.amplitude = v.amplitude
        renderer.frequency = v.frequency
        renderer.rotationX = rotationX
        renderer.rotationY = rotationY
        renderer.color1 = v.color1.simd
        renderer.color2 = v.color2.simd
        renderer.color3 = v.color3.simd
        renderer.color4 = v.color4.simd
        renderer.lightDirection = SIMD3<Float>(cos(v.lightAngle), 0.5, sin(v.lightAngle))
        renderer.lightIntensity = v.lightIntensity
        renderer.noiseType = v.noiseType
        renderer.wireframe = v.wireframe
        renderer.spherify = v.spherify
        renderer.subdivisionLevel = v.subdivision
        renderer.zoom = v.zoom
        renderer.colorByNoise = v.colorByNoise
        renderer.noiseOffset = SIMD3<Float>(v.noiseOffsetX, v.noiseOffsetY, v.noiseOffsetZ)
        renderer.showGrid = v.showGrid
        renderer.vizMode = v.vizMode
        renderer.audioLevel = audioLevel
        renderer.micSensitivity = v.micSensitivity
        renderer.audioBands = audioBands
        renderer.layerCount = v.layerCount
        renderer.temperatureMode = v.temperatureMode
        renderer.baseOpacity = v.baseOpacity
        renderer.audioReactivity = v.audioReactivity
        renderer.heatIntensity = v.heatIntensity
        renderer.edgeGlow = v.edgeGlow
    }

    public class Coordinator {
        var renderer: OrbRenderer?
    }
}
