import Metal

class NoisePermutation {
    static func generateBuffer(device: MTLDevice) -> MTLBuffer? {
        var perm = Array(0..<256)
        perm.shuffle()

        var table = [Int32](repeating: 0, count: 512)
        for i in 0..<512 {
            table[i] = Int32(perm[i % 256])
        }

        return device.makeBuffer(
            bytes: table,
            length: table.count * MemoryLayout<Int32>.stride,
            options: .storageModeShared
        )
    }
}
