#ifndef ATR_POOLING
#define ATR_POOLING
#include "/lib/exposure.glsl"

float atrGroundRetention(vec3 relativePos, vec3 normal, float exposure) {
#if POOLING_QUALITY > 0 && defined(RAIN_SHELTER)
    if (normal.y < 0.9 || exposure < 0.05) return 1.0;
    float groundHeight = cameraPosition.y + relativePos.y;
    const vec2 neighbours[8] = vec2[8](
        vec2(1.0, 0.0), vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, -1.0),
        vec2(1.0, 1.0), vec2(-1.0, 1.0), vec2(1.0, -1.0), vec2(-1.0, -1.0));
#if POOLING_QUALITY == 1
    const int samples = 4;
#else
    const int samples = 8;
#endif
    float rise = 0.0;
    float drainage = 0.0;
    float valid = 0.0;
    for (int i = 0; i < samples; ++i) {
        vec3 neighbour = relativePos + vec3(neighbours[i].x, 0.0, neighbours[i].y);
        float height;
        if (atrRoofHeightRelative(neighbour, height)) {
            float difference = height - groundHeight;
            rise += clamp(difference - 0.025, 0.0, 1.25);
            drainage = max(drainage, clamp(-difference - 0.025, 0.0, 1.0));
            valid += 1.0;
        }
    }
    if (valid < 2.0) return 1.0;
    // Raised neighbours retain water; a lower adjacent column drains it. This
    // is a local preference, not a simulation of stored or flowing water.
    return clamp(1.0 + rise / valid * 0.40 - drainage * 0.45, 0.55, 1.40);
#else
    return 1.0;
#endif
}
#endif
