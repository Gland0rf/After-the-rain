#ifndef ATR_MATERIALS
#define ATR_MATERIALS
#include "/lib/weather.glsl"

// UVs cover one block face, independent of atlas placement and camera position.
float atrSeam(float coordinate, float cells, float width, float footprint) {
    float f = fract(coordinate * cells);
    float distanceToSeam = min(f, 1.0 - f) / cells;
    float aa = max(footprint, 0.001);
    return 1.0 - smoothstep(width, width + aa, distanceToSeam);
}

vec2 atrMaterialPattern(vec2 blockUV, int material, vec3 worldPos) {
    // X: dampness retention. Y: puddle suitability within the material.
    vec2 result = vec2(1.0);
#ifdef MATERIAL_WET_PATTERNS
    vec2 footprint = fwidth(blockUV);
    if (material == 102) {
        float row = floor(blockUV.y * 4.0);
        float longJoint = atrSeam(blockUV.y, 4.0, 0.009, footprint.y);
        float endJoint = atrSeam(blockUV.x + row * 0.25, 2.0, 0.008, footprint.x);
        float joints = max(longJoint, endJoint * 0.70);
        // Subtle grain retains moisture without broad pale mirror patches.
        float grain = atrNoise(vec2(worldPos.x * 0.65, worldPos.z * 10.0));
        result = vec2(0.72 + joints * 0.28 + grain * 0.08, 0.08 + joints * 0.92);
    } else if (material == 100 || material == 101 || material == 105) {
        float joint = max(atrSeam(blockUV.x, 1.0, 0.018, footprint.x),
                          atrSeam(blockUV.y, 1.0, 0.018, footprint.y));
        float pockets = atrNoise(worldPos.xz * 3.4);
        result = vec2(0.86 + joint * 0.14, 0.66 + joint * 0.34 + (pockets - 0.5) * 0.14);
    }
#endif
    return clamp(result, 0.0, 1.0);
}

float atrRunoff(vec3 worldPos, vec3 normal) {
#ifdef WALL_RUNOFF
    vec2 alongWall = abs(normal.x) > abs(normal.z) ? worldPos.zy : worldPos.xy;
    float column = floor(alongWall.x * 5.0);
    float seed = atrHash(vec2(column, floor(worldPos.y / 8.0)));
    float x = fract(alongWall.x * 5.0) - (0.20 + seed * 0.60);
    float width = max(0.035, min(0.16, fwidth(alongWall.x) * 5.0));
    float trail = 1.0 - smoothstep(width, width * 2.0, abs(x));
    float run = 0.5 + 0.5 * sin(alongWall.y * 2.0 + frameTimeCounter * 2.7 + seed * 6.28);
    return trail * smoothstep(0.30, 0.80, seed) * (0.35 + run * 0.65) *
           (1.0 - smoothstep(0.10, 0.45, abs(normal.y)));
#else
    return 0.0;
#endif
}
#endif
