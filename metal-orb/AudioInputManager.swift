import AVFoundation
import Accelerate
import Combine

public class AudioInputManager: ObservableObject {
    @Published public var audioLevel: Float = 0.0
    @Published public var isRunning: Bool = false
    @Published public var permissionDenied: Bool = false

    @Published public var bass: Float = 0.0
    @Published public var mid: Float = 0.0
    @Published public var high: Float = 0.0
    @Published public var treble: Float = 0.0

    private var audioEngine: AVAudioEngine?
    private var smoothedLevel: Float = 0.0
    private var smoothedBass: Float = 0.0
    private var smoothedMid: Float = 0.0
    private var smoothedHigh: Float = 0.0
    private var smoothedTreble: Float = 0.0
    private var isStopping = false

    private let fftSize = 1024
    private var fftSetup: vDSP_DFT_Setup?
    private var sampleRate: Double = 44100

    public init() {}

    public func start() {
        guard !isRunning, !isStopping else { return }

        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            startCapture()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.startCapture()
                    } else {
                        self?.permissionDenied = true
                    }
                }
            }
        default:
            DispatchQueue.main.async { self.permissionDenied = true }
        }
    }

    private func startCapture() {
        fftSetup = vDSP_DFT_zrop_CreateSetup(nil, vDSP_Length(fftSize), .FORWARD)

        let engine = AVAudioEngine()
        self.audioEngine = engine

        let inputNode = engine.inputNode
        let nodeFormat = inputNode.outputFormat(forBus: 0)

        guard nodeFormat.sampleRate > 0 && nodeFormat.channelCount > 0 else { return }

        sampleRate = nodeFormat.sampleRate

        inputNode.installTap(onBus: 0, bufferSize: UInt32(fftSize), format: nodeFormat) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }

        do {
            try engine.start()
            DispatchQueue.main.async { self.isRunning = true }
        } catch {
            inputNode.removeTap(onBus: 0)
            self.audioEngine = nil
        }
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard !isStopping,
              let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }

        var sum: Float = 0
        vDSP_measqv(channelData, 1, &sum, vDSP_Length(frameLength))
        let rms = sqrt(sum)
        let normalizedLevel = min(rms * 12.0, 1.0)
        smoothedLevel = smoothedLevel * 0.5 + normalizedLevel * 0.5

        let bands = extractBands(channelData, frameLength: frameLength)

        let rise: Float = 0.6
        let fall: Float = 0.8
        smoothedBass = bands.0 > smoothedBass ? mix(smoothedBass, bands.0, rise) : smoothedBass * fall
        smoothedMid = bands.1 > smoothedMid ? mix(smoothedMid, bands.1, rise) : smoothedMid * fall
        smoothedHigh = bands.2 > smoothedHigh ? mix(smoothedHigh, bands.2, rise) : smoothedHigh * fall
        smoothedTreble = bands.3 > smoothedTreble ? mix(smoothedTreble, bands.3, rise) : smoothedTreble * fall

        DispatchQueue.main.async {
            self.audioLevel = self.smoothedLevel
            self.bass = self.smoothedBass
            self.mid = self.smoothedMid
            self.high = self.smoothedHigh
            self.treble = self.smoothedTreble
        }
    }

    private func mix(_ a: Float, _ b: Float, _ t: Float) -> Float {
        a + (b - a) * t
    }

    private func extractBands(_ data: UnsafePointer<Float>, frameLength: Int) -> (Float, Float, Float, Float) {
        guard let fftSetup = fftSetup else { return (0, 0, 0, 0) }

        let count = min(frameLength, fftSize)
        let halfSize = fftSize / 2

        var inputReal = [Float](repeating: 0, count: halfSize)
        var inputImag = [Float](repeating: 0, count: halfSize)
        var outputReal = [Float](repeating: 0, count: halfSize)
        var outputImag = [Float](repeating: 0, count: halfSize)

        for i in 0..<min(count / 2, halfSize) {
            inputReal[i] = data[i * 2]
            if i * 2 + 1 < count { inputImag[i] = data[i * 2 + 1] }
        }

        vDSP_DFT_Execute(fftSetup, &inputReal, &inputImag, &outputReal, &outputImag)

        var magnitudes = [Float](repeating: 0, count: halfSize)
        for i in 0..<halfSize {
            magnitudes[i] = sqrt(outputReal[i] * outputReal[i] + outputImag[i] * outputImag[i])
        }

        let binHz = sampleRate / Double(fftSize)
        let bassEnd = min(Int(300.0 / binHz), halfSize)
        let midEnd = min(Int(2000.0 / binHz), halfSize)
        let highEnd = min(Int(6000.0 / binHz), halfSize)

        func bandEnergy(_ start: Int, _ end: Int) -> Float {
            guard end > start else { return 0 }
            var sum: Float = 0
            for i in start..<end { sum += magnitudes[i] }
            return min(sum / Float(end - start) * 0.4, 1.0)
        }

        return (
            bandEnergy(0, bassEnd),
            bandEnergy(bassEnd, midEnd),
            bandEnergy(midEnd, highEnd),
            bandEnergy(highEnd, halfSize)
        )
    }

    public func stop() {
        guard !isStopping else { return }
        isStopping = true

        if let engine = audioEngine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        audioEngine = nil

        if let setup = fftSetup { vDSP_DFT_DestroySetup(setup) }
        fftSetup = nil

        DispatchQueue.main.async {
            self.isRunning = false
            self.audioLevel = 0.0
            self.bass = 0.0
            self.mid = 0.0
            self.high = 0.0
            self.treble = 0.0
            self.isStopping = false
        }
    }
}
