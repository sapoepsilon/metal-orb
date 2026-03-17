#include <metal_stdlib>
using namespace metal;

struct Vertex {
    float3 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
};

struct Uniforms {
    float4x4 modelViewProjection;
    float4x4 modelMatrix;
    float3 cameraPosition;
    float time;
    float amplitude;
    float frequency;
    float3 color1;
    float3 color2;
    float3 color3;
    float3 color4;
    float3 lightDirection;
    float lightIntensity;
    int noiseType;
    float spherify;
    int colorByNoise;
    float3 noiseOffset;
    int showGrid;
    int vizMode;
    float4 audioBands;
    int layerIndex;
    int layerCount;
    float layerScale;
    float layerAlpha;
    int temperatureMode;
    float baseOpacity;
    float audioReactivity;
    float heatIntensity;
    float edgeGlow;
};

struct VertexOut {
    float4 position [[position]];
    float3 worldPosition;
    float3 worldNormal;
    float3 localPosition;
    float noiseValue;
    float3 noiseCoord;
    float displacementMag;
};

float grad(int hash, float x, float y, float z, float w) {
    int h = hash & 31;
    float a = y, b = z, c = w;
    switch (h >> 3) {
        case 1: a = w; b = x; c = y; break;
        case 2: a = z; b = w; c = x; break;
        case 3: a = y; b = z; c = w; break;
    }
    return ((h & 4) == 0 ? -a : a) + ((h & 2) == 0 ? -b : b) + ((h & 1) == 0 ? -c : c);
}

float simplex4D(float4 v, constant int* perm) {
    const float F4 = 0.309016994374947451;
    const float G4 = 0.138196601125011;

    float s = (v.x + v.y + v.z + v.w) * F4;
    int i = floor(v.x + s);
    int j = floor(v.y + s);
    int k = floor(v.z + s);
    int l = floor(v.w + s);

    float t = (i + j + k + l) * G4;
    float X0 = i - t;
    float Y0 = j - t;
    float Z0 = k - t;
    float W0 = l - t;

    float x0 = v.x - X0;
    float y0 = v.y - Y0;
    float z0 = v.z - Z0;
    float w0 = v.w - W0;

    int rankx = 0, ranky = 0, rankz = 0, rankw = 0;
    if (x0 > y0) rankx++; else ranky++;
    if (x0 > z0) rankx++; else rankz++;
    if (x0 > w0) rankx++; else rankw++;
    if (y0 > z0) ranky++; else rankz++;
    if (y0 > w0) ranky++; else rankw++;
    if (z0 > w0) rankz++; else rankw++;

    int i1 = rankx >= 3 ? 1 : 0, j1 = ranky >= 3 ? 1 : 0;
    int k1 = rankz >= 3 ? 1 : 0, l1 = rankw >= 3 ? 1 : 0;
    int i2 = rankx >= 2 ? 1 : 0, j2 = ranky >= 2 ? 1 : 0;
    int k2 = rankz >= 2 ? 1 : 0, l2 = rankw >= 2 ? 1 : 0;
    int i3 = rankx >= 1 ? 1 : 0, j3 = ranky >= 1 ? 1 : 0;
    int k3 = rankz >= 1 ? 1 : 0, l3 = rankw >= 1 ? 1 : 0;

    float x1 = x0 - i1 + G4, y1 = y0 - j1 + G4;
    float z1 = z0 - k1 + G4, w1 = w0 - l1 + G4;
    float x2 = x0 - i2 + 2.0 * G4, y2 = y0 - j2 + 2.0 * G4;
    float z2 = z0 - k2 + 2.0 * G4, w2 = w0 - l2 + 2.0 * G4;
    float x3 = x0 - i3 + 3.0 * G4, y3 = y0 - j3 + 3.0 * G4;
    float z3 = z0 - k3 + 3.0 * G4, w3 = w0 - l3 + 3.0 * G4;
    float x4 = x0 - 1.0 + 4.0 * G4, y4 = y0 - 1.0 + 4.0 * G4;
    float z4 = z0 - 1.0 + 4.0 * G4, w4 = w0 - 1.0 + 4.0 * G4;

    int ii = i & 255, jj = j & 255, kk = k & 255, ll = l & 255;

    float n0, n1, n2, n3, n4;

    float t0 = 0.6 - x0*x0 - y0*y0 - z0*z0 - w0*w0;
    if (t0 < 0) n0 = 0.0;
    else { t0 *= t0; n0 = t0 * t0 * grad(perm[ii + perm[jj + perm[kk + perm[ll]]]], x0, y0, z0, w0); }

    float t1 = 0.6 - x1*x1 - y1*y1 - z1*z1 - w1*w1;
    if (t1 < 0) n1 = 0.0;
    else { t1 *= t1; n1 = t1 * t1 * grad(perm[ii + i1 + perm[jj + j1 + perm[kk + k1 + perm[ll + l1]]]], x1, y1, z1, w1); }

    float t2 = 0.6 - x2*x2 - y2*y2 - z2*z2 - w2*w2;
    if (t2 < 0) n2 = 0.0;
    else { t2 *= t2; n2 = t2 * t2 * grad(perm[ii + i2 + perm[jj + j2 + perm[kk + k2 + perm[ll + l2]]]], x2, y2, z2, w2); }

    float t3 = 0.6 - x3*x3 - y3*y3 - z3*z3 - w3*w3;
    if (t3 < 0) n3 = 0.0;
    else { t3 *= t3; n3 = t3 * t3 * grad(perm[ii + i3 + perm[jj + j3 + perm[kk + k3 + perm[ll + l3]]]], x3, y3, z3, w3); }

    float t4 = 0.6 - x4*x4 - y4*y4 - z4*z4 - w4*w4;
    if (t4 < 0) n4 = 0.0;
    else { t4 *= t4; n4 = t4 * t4 * grad(perm[ii + 1 + perm[jj + 1 + perm[kk + 1 + perm[ll + 1]]]], x4, y4, z4, w4); }

    return 27.0 * (n0 + n1 + n2 + n3 + n4);
}

float fbmSimplex4D(float4 v, int octaves, constant int* perm) {
    float value = 0.0;
    float amp = 0.5;
    float freq = 1.0;

    for (int i = 0; i < octaves; i++) {
        value += amp * simplex4D(v * freq, perm);
        amp *= 0.5;
        freq *= 2.0;
    }

    return value;
}

float fade(float t) {
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

float lerp(float a, float b, float t) {
    return a + t * (b - a);
}

float perlinGrad4D(int hash, float x, float y, float z, float w) {
    int h = hash & 31;
    float u = h < 24 ? x : y;
    float v = h < 16 ? y : z;
    float s = h < 8 ? z : w;
    return ((h & 1) ? -u : u) + ((h & 2) ? -v : v) + ((h & 4) ? -s : s);
}

float perlin4D(float4 v, constant int* perm) {
    int X = int(floor(v.x)) & 255;
    int Y = int(floor(v.y)) & 255;
    int Z = int(floor(v.z)) & 255;
    int W = int(floor(v.w)) & 255;

    float x = v.x - floor(v.x);
    float y = v.y - floor(v.y);
    float z = v.z - floor(v.z);
    float w = v.w - floor(v.w);

    float u = fade(x);
    float vf = fade(y);
    float sf = fade(z);
    float tf = fade(w);

    int A = perm[X] + Y;
    int AA = perm[A] + Z;
    int AB = perm[A + 1] + Z;
    int B = perm[X + 1] + Y;
    int BA = perm[B] + Z;
    int BB = perm[B + 1] + Z;

    int AAA = perm[AA] + W;
    int AAB = perm[AA + 1] + W;
    int ABA = perm[AB] + W;
    int ABB = perm[AB + 1] + W;
    int BAA = perm[BA] + W;
    int BAB = perm[BA + 1] + W;
    int BBA = perm[BB] + W;
    int BBB = perm[BB + 1] + W;

    float g0000 = perlinGrad4D(perm[AAA], x, y, z, w);
    float g1000 = perlinGrad4D(perm[BAA], x - 1, y, z, w);
    float g0100 = perlinGrad4D(perm[ABA], x, y - 1, z, w);
    float g1100 = perlinGrad4D(perm[BBA], x - 1, y - 1, z, w);
    float g0010 = perlinGrad4D(perm[AAB], x, y, z - 1, w);
    float g1010 = perlinGrad4D(perm[BAB], x - 1, y, z - 1, w);
    float g0110 = perlinGrad4D(perm[ABB], x, y - 1, z - 1, w);
    float g1110 = perlinGrad4D(perm[BBB], x - 1, y - 1, z - 1, w);
    float g0001 = perlinGrad4D(perm[AAA + 1], x, y, z, w - 1);
    float g1001 = perlinGrad4D(perm[BAA + 1], x - 1, y, z, w - 1);
    float g0101 = perlinGrad4D(perm[ABA + 1], x, y - 1, z, w - 1);
    float g1101 = perlinGrad4D(perm[BBA + 1], x - 1, y - 1, z, w - 1);
    float g0011 = perlinGrad4D(perm[AAB + 1], x, y, z - 1, w - 1);
    float g1011 = perlinGrad4D(perm[BAB + 1], x - 1, y, z - 1, w - 1);
    float g0111 = perlinGrad4D(perm[ABB + 1], x, y - 1, z - 1, w - 1);
    float g1111 = perlinGrad4D(perm[BBB + 1], x - 1, y - 1, z - 1, w - 1);

    float x00 = lerp(g0000, g1000, u);
    float x10 = lerp(g0100, g1100, u);
    float x01 = lerp(g0010, g1010, u);
    float x11 = lerp(g0110, g1110, u);
    float x02 = lerp(g0001, g1001, u);
    float x12 = lerp(g0101, g1101, u);
    float x03 = lerp(g0011, g1011, u);
    float x13 = lerp(g0111, g1111, u);

    float y0 = lerp(x00, x10, vf);
    float y1 = lerp(x01, x11, vf);
    float y2 = lerp(x02, x12, vf);
    float y3 = lerp(x03, x13, vf);

    float z0 = lerp(y0, y1, sf);
    float z1 = lerp(y2, y3, sf);

    return lerp(z0, z1, tf);
}

float fbmPerlin4D(float4 v, int octaves, constant int* perm) {
    float value = 0.0;
    float amp = 0.5;
    float freq = 1.0;

    for (int i = 0; i < octaves; i++) {
        value += amp * perlin4D(v * freq, perm);
        amp *= 0.5;
        freq *= 2.0;
    }

    return value;
}

float sampleNoise(float4 input, int noiseType, constant int* perm) {
    if (noiseType == 0) {
        return fbmSimplex4D(input, 3, perm);
    } else {
        return fbmPerlin4D(input, 3, perm);
    }
}

vertex VertexOut vertexMain(Vertex in [[stage_in]],
                            constant Uniforms& uniforms [[buffer(1)]],
                            constant int* perm [[buffer(2)]]) {
    float3 flatPos = float3(in.position.x, 0.0, in.position.z);
    float3 spherePos = in.position;
    float3 basePos = mix(flatPos, spherePos, uniforms.spherify);

    float3 flatNormal = float3(0.0, 1.0, 0.0);
    float3 baseNormal = mix(flatNormal, in.normal, uniforms.spherify);
    baseNormal = normalize(baseNormal);

    float layerSeed = float(uniforms.layerIndex) * 7.31;
    float3 offsetPos = basePos + uniforms.noiseOffset + float3(layerSeed, layerSeed * 0.5, layerSeed * 0.3);
    float timeSpeed = 0.5 + float(uniforms.layerIndex) * 0.15;
    float4 noiseInput = float4(offsetPos * uniforms.frequency, uniforms.time * timeSpeed);

    float displacement = sampleNoise(noiseInput, uniforms.noiseType, perm);

    // sample neighbors to estimate roughness (gradient magnitude)
    float eps = 0.02;
    float dx = sampleNoise(noiseInput + float4(eps, 0, 0, 0), uniforms.noiseType, perm);
    float dy = sampleNoise(noiseInput + float4(0, eps, 0, 0), uniforms.noiseType, perm);
    float dz = sampleNoise(noiseInput + float4(0, 0, eps, 0), uniforms.noiseType, perm);
    float roughness = length(float3(dx - displacement, dy - displacement, dz - displacement)) / eps;

    float3 displacedPosition = basePos + baseNormal * displacement * uniforms.amplitude;

    VertexOut out;
    out.position = uniforms.modelViewProjection * float4(displacedPosition, 1.0);
    out.worldPosition = (uniforms.modelMatrix * float4(displacedPosition, 1.0)).xyz;
    out.worldNormal = normalize((uniforms.modelMatrix * float4(baseNormal, 0.0)).xyz);
    out.localPosition = basePos;
    out.noiseValue = displacement;
    out.noiseCoord = offsetPos * uniforms.frequency;
    out.displacementMag = roughness;

    return out;
}

float3 getPerlinGradientColor(float3 pos, constant int* perm) {
    int X = int(floor(pos.x)) & 255;
    int Y = int(floor(pos.y)) & 255;
    int Z = int(floor(pos.z)) & 255;

    int hash = perm[X + perm[Y + perm[Z]]] & 15;

    float3 gradColors[16] = {
        float3(1,0,0), float3(0,1,0), float3(0,0,1), float3(1,1,0),
        float3(1,0,1), float3(0,1,1), float3(0.5,1,0), float3(1,0.5,0),
        float3(0,0.5,1), float3(0.5,0,1), float3(1,0,0.5), float3(0,1,0.5),
        float3(0.7,0.7,0), float3(0.7,0,0.7), float3(0,0.7,0.7), float3(0.5,0.5,0.5)
    };
    return gradColors[hash];
}

float3 vizPerlinContributions(float3 pos, constant int* perm) {
    float x = pos.x - floor(pos.x);
    float y = pos.y - floor(pos.y);
    float z = pos.z - floor(pos.z);

    float u = x * x * x * (x * (x * 6.0 - 15.0) + 10.0);
    float v = y * y * y * (y * (y * 6.0 - 15.0) + 10.0);
    float w = z * z * z * (z * (z * 6.0 - 15.0) + 10.0);

    float w000 = (1-u) * (1-v) * (1-w);
    float w100 = u * (1-v) * (1-w);
    float w010 = (1-u) * v * (1-w);
    float w001 = (1-u) * (1-v) * w;
    float w110 = u * v * (1-w);
    float w101 = u * (1-v) * w;
    float w011 = (1-u) * v * w;
    float w111 = u * v * w;

    float3 c000 = float3(1, 0, 0);
    float3 c100 = float3(0, 1, 0);
    float3 c010 = float3(0, 0, 1);
    float3 c001 = float3(1, 1, 0);
    float3 c110 = float3(1, 0, 1);
    float3 c101 = float3(0, 1, 1);
    float3 c011 = float3(1, 0.5, 0);
    float3 c111 = float3(0.5, 0, 1);

    return c000*w000 + c100*w100 + c010*w010 + c001*w001 +
           c110*w110 + c101*w101 + c011*w011 + c111*w111;
}

float3 vizCellPosition(float3 pos) {
    float3 f = fract(pos);
    return f;
}

float3 vizFadeFunction(float3 pos) {
    float3 f = fract(pos);
    float3 fade;
    fade.x = f.x * f.x * f.x * (f.x * (f.x * 6.0 - 15.0) + 10.0);
    fade.y = f.y * f.y * f.y * (f.y * (f.y * 6.0 - 15.0) + 10.0);
    fade.z = f.z * f.z * f.z * (f.z * (f.z * 6.0 - 15.0) + 10.0);
    return fade;
}

float3 hsvToRgb(float3 hsv) {
    float h = hsv.x * 6.0;
    float s = hsv.y;
    float v = hsv.z;

    float c = v * s;
    float x = c * (1.0 - abs(fmod(h, 2.0) - 1.0));
    float m = v - c;

    float3 rgb;
    if (h < 1.0) rgb = float3(c, x, 0);
    else if (h < 2.0) rgb = float3(x, c, 0);
    else if (h < 3.0) rgb = float3(0, c, x);
    else if (h < 4.0) rgb = float3(0, x, c);
    else if (h < 5.0) rgb = float3(x, 0, c);
    else rgb = float3(c, 0, x);

    return rgb + m;
}

fragment float4 fragmentMain(VertexOut in [[stage_in]],
                             constant Uniforms& uniforms [[buffer(1)]],
                             constant int* perm [[buffer(2)]]) {
    float3 viewDir = normalize(uniforms.cameraPosition - in.worldPosition);
    float3 normal = normalize(in.worldNormal);
    float3 lightDir = normalize(uniforms.lightDirection);

    float fresnel = 1.0 - abs(dot(viewDir, normal));
    fresnel = pow(fresnel, 2.5);

    float diffuse = max(dot(normal, lightDir), 0.0);
    float3 halfVec = normalize(lightDir + viewDir);
    float specular = pow(max(dot(normal, halfVec), 0.0), 32.0);

    float bandLevel = uniforms.audioBands[uniforms.layerIndex % 4];
    float totalAudio = (uniforms.audioBands.x + uniforms.audioBands.y +
                       uniforms.audioBands.z + uniforms.audioBands.w) * 0.25;

    float absDis = abs(in.noiseValue);
    float roughness = clamp(in.displacementMag, 0.0, 3.0) / 3.0;

    float3 color;
    float alpha;

    if (uniforms.temperatureMode == 1) {
        // --- SINGLE COLOR + TEMPERATURE MODE ---
        float3 baseHue = uniforms.color1;

        float react = uniforms.audioReactivity;
        float heatStr = uniforms.heatIntensity;
        float edgeStr = uniforms.edgeGlow;
        float opac = uniforms.baseOpacity;

        float visibility = clamp(absDis * 1.2 + roughness * 0.8, 0.0, 1.0);
        float audioBoost = (bandLevel * 1.5 + totalAudio * 0.5) * react;
        visibility = clamp(visibility * (0.4 + audioBoost), 0.0, 1.0);

        float edgeBright = roughness * (0.4 + bandLevel * 1.5) * edgeStr;

        float rawHeat = absDis * 0.2 + (bandLevel * 0.6 + totalAudio * 0.3) * react + roughness * 0.1;
        float heat = pow(clamp(rawHeat * heatStr, 0.0, 1.0), 1.5 + heatStr);

        float3 cool = baseHue * 0.35;
        float3 warm = baseHue * 0.9 + float3(0.05, 0.02, 0.0);
        float3 hot = mix(baseHue * 1.1, float3(1.0), 0.5);

        float3 tempColor;
        if (heat < 0.6) {
            tempColor = mix(cool, warm, heat / 0.6);
        } else {
            tempColor = mix(warm, hot, (heat - 0.6) / 0.4);
        }

        float lighting = 0.25 + diffuse * uniforms.lightIntensity * 0.6;
        color = tempColor * lighting;
        color += tempColor * fresnel * 0.3 * edgeStr;
        color += tempColor * edgeBright * 0.3;
        color += float3(1.0) * specular * uniforms.lightIntensity * 0.15;

        if (uniforms.layerIndex == 0) {
            alpha = opac + (1.0 - opac) * visibility;
        } else {
            alpha = (opac * 0.3) + visibility * uniforms.layerAlpha * (0.3 + bandLevel * react);
            alpha += roughness * 0.15 * edgeStr * (1.0 + bandLevel * react);
            alpha = clamp(alpha, opac * 0.2, opac + 0.15);
        }
    } else {
        // --- MULTI-COLOR MODE (original behavior) ---
        float angle = atan2(in.localPosition.x, in.localPosition.z);
        float t = (angle + M_PI_F) / (2.0 * M_PI_F);

        float3 gradientColor;
        if (uniforms.colorByNoise == 1) {
            float n = clamp(in.noiseValue * 0.5 + 0.5, 0.0, 1.0);
            float nq = n * n;
            float s;
            if (nq < 0.25) {
                s = nq * 4.0;
                gradientColor = mix(uniforms.color1, uniforms.color2, s * s);
            } else if (nq < 0.5) {
                s = (nq - 0.25) * 4.0;
                gradientColor = mix(uniforms.color2, uniforms.color3, s * s);
            } else if (nq < 0.75) {
                s = (nq - 0.5) * 4.0;
                gradientColor = mix(uniforms.color3, uniforms.color4, s * s);
            } else {
                s = (nq - 0.75) * 4.0;
                gradientColor = mix(uniforms.color4, uniforms.color1, s * s);
            }
        } else {
            float s;
            if (t < 0.25) {
                s = t * 4.0;
                gradientColor = mix(uniforms.color1, uniforms.color2, s * s);
            } else if (t < 0.5) {
                s = (t - 0.25) * 4.0;
                gradientColor = mix(uniforms.color2, uniforms.color3, s * s);
            } else if (t < 0.75) {
                s = (t - 0.5) * 4.0;
                gradientColor = mix(uniforms.color3, uniforms.color4, s * s);
            } else {
                s = (t - 0.75) * 4.0;
                gradientColor = mix(uniforms.color4, uniforms.color1, s * s);
            }
        }

        float lighting = 0.2 + diffuse * uniforms.lightIntensity;
        color = gradientColor * lighting;
        color += gradientColor * fresnel * 0.5;
        color += float3(1.0) * specular * uniforms.lightIntensity * 0.5;

        if (uniforms.layerIndex == 0) {
            alpha = 1.0;
        } else {
            float visibility = clamp(absDis * 1.5 + roughness, 0.0, 1.0);
            alpha = uniforms.layerAlpha * (0.3 + visibility * 0.7 + bandLevel * 1.5);
            alpha = clamp(alpha, 0.0, 0.85);
        }
    }

    if (uniforms.showGrid == 1) {
        float3 cellPos = fract(in.noiseCoord);
        float3 distToEdge = min(cellPos, 1.0 - cellPos);
        float edgeMin = min(distToEdge.x, min(distToEdge.y, distToEdge.z));
        float3 distToVertex = min(cellPos, 1.0 - cellPos);
        float vertexDist = length(distToVertex);
        if (vertexDist < 0.15) {
            color = getPerlinGradientColor(in.noiseCoord, perm);
        } else if (edgeMin < 0.05) {
            color = mix(color, float3(1.0), 0.5);
        }
    }

    if (uniforms.vizMode == 1) {
        color = vizCellPosition(in.noiseCoord);
        alpha = 1.0;
    } else if (uniforms.vizMode == 2) {
        color = vizFadeFunction(in.noiseCoord);
        alpha = 1.0;
    } else if (uniforms.vizMode == 3) {
        color = vizPerlinContributions(in.noiseCoord, perm);
        alpha = 1.0;
    } else if (uniforms.vizMode == 4) {
        color = getPerlinGradientColor(in.noiseCoord, perm);
        alpha = 1.0;
    }

    return float4(color, alpha);
}
