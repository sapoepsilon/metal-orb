import simd

struct OrbVertex {
    var position: SIMD3<Float>
    var normal: SIMD3<Float>
}

class Icosphere {
    static func generate(subdivisions: Int) -> (vertices: [OrbVertex], indices: [UInt32]) {
        if subdivisions == 0 { return generateRectangle() }
        if subdivisions == 1 { return generateCube() }

        let icoSubdivisions = subdivisions - 2

        var vertices: [OrbVertex] = []
        var indices: [UInt32] = []

        let phi: Float = (1.0 + sqrt(5.0)) / 2.0
        let scale: Float = 1.0 / sqrt(1.0 + phi * phi)

        let basePositions: [SIMD3<Float>] = [
            SIMD3<Float>(-1,  phi, 0) * scale, SIMD3<Float>( 1,  phi, 0) * scale,
            SIMD3<Float>(-1, -phi, 0) * scale, SIMD3<Float>( 1, -phi, 0) * scale,
            SIMD3<Float>(0, -1,  phi) * scale, SIMD3<Float>(0,  1,  phi) * scale,
            SIMD3<Float>(0, -1, -phi) * scale, SIMD3<Float>(0,  1, -phi) * scale,
            SIMD3<Float>( phi, 0, -1) * scale, SIMD3<Float>( phi, 0,  1) * scale,
            SIMD3<Float>(-phi, 0, -1) * scale, SIMD3<Float>(-phi, 0,  1) * scale
        ]

        for pos in basePositions {
            let n = normalize(pos)
            vertices.append(OrbVertex(position: n, normal: n))
        }

        indices = [
            0, 11, 5,  0, 5, 1,   0, 1, 7,   0, 7, 10,  0, 10, 11,
            1, 5, 9,   5, 11, 4,  11, 10, 2, 10, 7, 6,   7, 1, 8,
            3, 9, 4,   3, 4, 2,   3, 2, 6,   3, 6, 8,    3, 8, 9,
            4, 9, 5,   2, 4, 11,  6, 2, 10,  8, 6, 7,    9, 8, 1
        ]

        var midpointCache: [UInt64: UInt32] = [:]

        func getMidpoint(_ v1: UInt32, _ v2: UInt32) -> UInt32 {
            let smaller = min(v1, v2)
            let larger = max(v1, v2)
            let key = (UInt64(smaller) << 32) | UInt64(larger)
            if let cached = midpointCache[key] { return cached }
            let p1 = vertices[Int(v1)].position
            let p2 = vertices[Int(v2)].position
            let mid = normalize((p1 + p2) * 0.5)
            let newIndex = UInt32(vertices.count)
            vertices.append(OrbVertex(position: mid, normal: mid))
            midpointCache[key] = newIndex
            return newIndex
        }

        for _ in 0..<icoSubdivisions {
            var newIndices: [UInt32] = []
            midpointCache.removeAll()
            for i in stride(from: 0, to: indices.count, by: 3) {
                let v0 = indices[i], v1 = indices[i + 1], v2 = indices[i + 2]
                let a = getMidpoint(v0, v1), b = getMidpoint(v1, v2), c = getMidpoint(v2, v0)
                newIndices.append(contentsOf: [v0, a, c, v1, b, a, v2, c, b, a, b, c])
            }
            indices = newIndices
        }

        return (vertices, indices)
    }

    static func generateRectangle() -> (vertices: [OrbVertex], indices: [UInt32]) {
        let normal = SIMD3<Float>(0, 1, 0)
        let vertices: [OrbVertex] = [
            OrbVertex(position: SIMD3<Float>(-1, 0, -1), normal: normal),
            OrbVertex(position: SIMD3<Float>( 1, 0, -1), normal: normal),
            OrbVertex(position: SIMD3<Float>( 1, 0,  1), normal: normal),
            OrbVertex(position: SIMD3<Float>(-1, 0,  1), normal: normal)
        ]
        return (vertices, [0, 2, 1, 0, 3, 2])
    }

    static func generateCube() -> (vertices: [OrbVertex], indices: [UInt32]) {
        let s: Float = 0.577350269
        let positions: [SIMD3<Float>] = [
            SIMD3<Float>(-s, -s, -s), SIMD3<Float>( s, -s, -s),
            SIMD3<Float>( s,  s, -s), SIMD3<Float>(-s,  s, -s),
            SIMD3<Float>(-s, -s,  s), SIMD3<Float>( s, -s,  s),
            SIMD3<Float>( s,  s,  s), SIMD3<Float>(-s,  s,  s)
        ]
        var vertices: [OrbVertex] = []
        for pos in positions {
            let n = normalize(pos)
            vertices.append(OrbVertex(position: n, normal: n))
        }
        return (vertices, [
            0, 2, 1, 0, 3, 2, 4, 5, 6, 4, 6, 7,
            0, 1, 5, 0, 5, 4, 2, 3, 7, 2, 7, 6,
            0, 4, 7, 0, 7, 3, 1, 2, 6, 1, 6, 5
        ])
    }
}
