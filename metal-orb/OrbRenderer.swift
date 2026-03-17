import Metal
import MetalKit
import simd

struct Uniforms {
    var modelViewProjection: simd_float4x4
    var modelMatrix: simd_float4x4
    var cameraPosition: SIMD3<Float>
    var time: Float
    var amplitude: Float
    var frequency: Float
    var color1: SIMD3<Float>
    var color2: SIMD3<Float>
    var color3: SIMD3<Float>
    var color4: SIMD3<Float>
    var lightDirection: SIMD3<Float>
    var lightIntensity: Float
    var noiseType: Int32
    var spherify: Float
    var colorByNoise: Int32
    var noiseOffset: SIMD3<Float>
    var showGrid: Int32
    var vizMode: Int32
    var audioBands: SIMD4<Float>
    var layerIndex: Int32
    var layerCount: Int32
    var layerScale: Float
    var layerAlpha: Float
    var temperatureMode: Int32
    var baseOpacity: Float
    var audioReactivity: Float
    var heatIntensity: Float
    var edgeGlow: Float
}

class OrbRenderer: NSObject, MTKViewDelegate {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    var pipelineState: MTLRenderPipelineState!
    var additivePipelineState: MTLRenderPipelineState!
    var depthState: MTLDepthStencilState!
    var depthReadOnlyState: MTLDepthStencilState!
    var vertexBuffer: MTLBuffer!
    var indexBuffer: MTLBuffer!
    var uniformBuffer: MTLBuffer!
    var permutationBuffer: MTLBuffer!
    var indexCount: Int = 0

    var startTime: CFTimeInterval
    var viewportSize: CGSize = CGSize(width: 800, height: 600)
    var zoom: Float = 1.0
    var amplitude: Float = 0.15
    var frequency: Float = 5.0
    var color1: SIMD3<Float> = SIMD3<Float>(0.0, 0.9, 1.0)
    var color2: SIMD3<Float> = SIMD3<Float>(0.7, 0.3, 1.0)
    var color3: SIMD3<Float> = SIMD3<Float>(1.0, 0.5, 0.1)
    var color4: SIMD3<Float> = SIMD3<Float>(0.2, 1.0, 0.4)
    var rotationX: Float = 0
    var rotationY: Float = 0
    var lightDirection: SIMD3<Float> = SIMD3<Float>(1, 1, 1)
    var lightIntensity: Float = 1.0
    var noiseType: Int32 = 0
    var wireframe: Bool = false
    var spherify: Float = 1.0
    var colorByNoise: Bool = false
    var noiseOffset: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    var showGrid: Bool = false
    var vizMode: Int32 = 0
    var audioLevel: Float = 0.0
    var micSensitivity: Float = 1.0
    var audioBands: SIMD4<Float> = .zero
    var layerCount: Int32 = 5
    var temperatureMode: Bool = false
    var baseOpacity: Float = 0.7
    var audioReactivity: Float = 1.0
    var heatIntensity: Float = 1.0
    var edgeGlow: Float = 1.0
    var subdivisionLevel: Int = 6 {
        didSet {
            if subdivisionLevel != oldValue { setSubdivision(subdivisionLevel) }
        }
    }

    init?(device: MTLDevice) {
        self.device = device
        guard let queue = device.makeCommandQueue() else { return nil }
        self.commandQueue = queue
        self.startTime = CACurrentMediaTime()
        super.init()
        setupPipeline()
        setSubdivision(6)
        permutationBuffer = NoisePermutation.generateBuffer(device: device)
    }

    private func setupPipeline() {
        guard let library = device.makeDefaultLibrary() else {
            print("[MetalOrb] Failed to load shader library")
            return
        }

        guard let vertexFunction = library.makeFunction(name: "vertexMain"),
              let fragmentFunction = library.makeFunction(name: "fragmentMain") else {
            print("[MetalOrb] Failed to find shader functions")
            return
        }

        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.attributes[1].format = .float3
        vertexDescriptor.attributes[1].offset = MemoryLayout<SIMD3<Float>>.stride
        vertexDescriptor.attributes[1].bufferIndex = 0
        vertexDescriptor.layouts[0].stride = MemoryLayout<OrbVertex>.stride

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float

        do { pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor) }
        catch { print("[MetalOrb] Pipeline error: \(error)"); return }

        let additivePD = MTLRenderPipelineDescriptor()
        additivePD.vertexFunction = vertexFunction
        additivePD.fragmentFunction = fragmentFunction
        additivePD.vertexDescriptor = vertexDescriptor
        additivePD.colorAttachments[0].pixelFormat = .bgra8Unorm
        additivePD.colorAttachments[0].isBlendingEnabled = true
        additivePD.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        additivePD.colorAttachments[0].destinationRGBBlendFactor = .one
        additivePD.colorAttachments[0].sourceAlphaBlendFactor = .one
        additivePD.colorAttachments[0].destinationAlphaBlendFactor = .one
        additivePD.depthAttachmentPixelFormat = .depth32Float

        do { additivePipelineState = try device.makeRenderPipelineState(descriptor: additivePD) }
        catch { print("[MetalOrb] Additive pipeline error: \(error)") }

        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = .less
        depthDescriptor.isDepthWriteEnabled = true
        depthState = device.makeDepthStencilState(descriptor: depthDescriptor)

        let depthReadOnly = MTLDepthStencilDescriptor()
        depthReadOnly.depthCompareFunction = .less
        depthReadOnly.isDepthWriteEnabled = false
        depthReadOnlyState = device.makeDepthStencilState(descriptor: depthReadOnly)

        uniformBuffer = device.makeBuffer(length: MemoryLayout<Uniforms>.stride, options: .storageModeShared)
    }

    func setSubdivision(_ level: Int) {
        let clampedLevel = max(0, min(9, level))
        let (vertices, indices) = Icosphere.generate(subdivisions: clampedLevel)
        vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<OrbVertex>.stride, options: .storageModeShared)
        indexBuffer = device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt32>.stride, options: .storageModeShared)
        indexCount = indices.count
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { viewportSize = size }

    func draw(in view: MTKView) {
        guard let pipelineState = pipelineState,
              let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor else { return }

        let time = Float(CACurrentMediaTime() - startTime)
        let aspect = Float(viewportSize.width / viewportSize.height)
        let cameraPosition = SIMD3<Float>(0, 0, 3.0 / zoom)

        let projection = perspectiveMatrix(fov: Float.pi / 4, aspect: aspect, near: 0.1, far: 100)
        let viewMatrix = lookAtMatrix(eye: cameraPosition, center: .zero, up: SIMD3<Float>(0, 1, 0))
        let model = rotationMatrix(angle: rotationY, axis: SIMD3<Float>(0, 1, 0))
                   * rotationMatrix(angle: rotationX, axis: SIMD3<Float>(1, 0, 0))

        descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.02, green: 0.02, blue: 0.04, alpha: 1.0)

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }

        encoder.setCullMode(.none)
        encoder.setTriangleFillMode(wireframe ? .lines : .fill)
        encoder.setViewport(MTLViewport(originX: 0, originY: 0, width: Double(viewportSize.width), height: Double(viewportSize.height), znear: 0, zfar: 1))
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(permutationBuffer, offset: 0, index: 2)
        encoder.setFragmentBuffer(permutationBuffer, offset: 0, index: 2)

        let count = max(1, layerCount)

        for layer in (0..<count).reversed() {
            if layer == 0 {
                encoder.setRenderPipelineState(pipelineState)
                encoder.setDepthStencilState(depthState)
            } else {
                encoder.setRenderPipelineState(additivePipelineState)
                encoder.setDepthStencilState(depthReadOnlyState)
            }

            let t = count > 1 ? Float(layer) / Float(count - 1) : 0.0
            let scale: Float = 1.0 + t * 0.15
            let alpha: Float = layer == 0 ? 1.0 : 0.15 + 0.25 * (1.0 - t)

            let bandLevel: Float
            switch layer {
            case 0: bandLevel = audioBands.x
            case 1: bandLevel = audioBands.y
            case 2: bandLevel = audioBands.z
            default: bandLevel = audioBands.w
            }

            let layerAmplitude = amplitude + (bandLevel * amplitude * micSensitivity * 5.0)
            let scaleMatrix = simd_float4x4(diagonal: SIMD4<Float>(scale, scale, scale, 1.0))
            let layerModel = model * scaleMatrix
            let mvp = projection * viewMatrix * layerModel

            var uniforms = Uniforms(
                modelViewProjection: mvp, modelMatrix: layerModel,
                cameraPosition: cameraPosition, time: time,
                amplitude: layerAmplitude, frequency: frequency + Float(layer) * 1.5,
                color1: color1, color2: color2, color3: color3, color4: color4,
                lightDirection: normalize(lightDirection), lightIntensity: lightIntensity,
                noiseType: noiseType, spherify: spherify,
                colorByNoise: colorByNoise ? 1 : 0, noiseOffset: noiseOffset,
                showGrid: showGrid ? 1 : 0, vizMode: vizMode,
                audioBands: audioBands, layerIndex: Int32(layer),
                layerCount: count, layerScale: scale, layerAlpha: alpha,
                temperatureMode: temperatureMode ? 1 : 0,
                baseOpacity: baseOpacity, audioReactivity: audioReactivity,
                heatIntensity: heatIntensity, edgeGlow: edgeGlow
            )

            memcpy(uniformBuffer.contents(), &uniforms, MemoryLayout<Uniforms>.stride)
            encoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
            encoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 1)
            encoder.drawIndexedPrimitives(type: .triangle, indexCount: indexCount, indexType: .uint32, indexBuffer: indexBuffer, indexBufferOffset: 0)
        }

        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func perspectiveMatrix(fov: Float, aspect: Float, near: Float, far: Float) -> simd_float4x4 {
        let ys = 1 / tan(fov * 0.5); let xs = ys / aspect; let zs = far / (near - far)
        return simd_float4x4(columns: (
            SIMD4<Float>(xs, 0, 0, 0), SIMD4<Float>(0, ys, 0, 0),
            SIMD4<Float>(0, 0, zs, -1), SIMD4<Float>(0, 0, near * zs, 0)
        ))
    }

    private func lookAtMatrix(eye: SIMD3<Float>, center: SIMD3<Float>, up: SIMD3<Float>) -> simd_float4x4 {
        let z = normalize(eye - center); let x = normalize(cross(up, z)); let y = cross(z, x)
        return simd_float4x4(columns: (
            SIMD4<Float>(x.x, y.x, z.x, 0), SIMD4<Float>(x.y, y.y, z.y, 0),
            SIMD4<Float>(x.z, y.z, z.z, 0), SIMD4<Float>(-dot(x, eye), -dot(y, eye), -dot(z, eye), 1)
        ))
    }

    private func rotationMatrix(angle: Float, axis: SIMD3<Float>) -> simd_float4x4 {
        let c = cos(angle); let s = sin(angle); let t = 1 - c
        let x = axis.x, y = axis.y, z = axis.z
        return simd_float4x4(columns: (
            SIMD4<Float>(t*x*x + c, t*x*y + s*z, t*x*z - s*y, 0),
            SIMD4<Float>(t*x*y - s*z, t*y*y + c, t*y*z + s*x, 0),
            SIMD4<Float>(t*x*z + s*y, t*y*z - s*x, t*z*z + c, 0),
            SIMD4<Float>(0, 0, 0, 1)
        ))
    }
}
