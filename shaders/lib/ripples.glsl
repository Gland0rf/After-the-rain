#ifndef ATR_RIPPLES
#define ATR_RIPPLES
#include "/lib/weather.glsl"

// Neighbouring cells contribute rings across tile boundaries; new impacts get
// a new centre each cycle, avoiding repeating circles at fixed grid points.
vec3 atrRipple(vec2 worldXZ) {
    vec2 tile = worldXZ * 1.55;
    vec2 cell = floor(tile);
    vec3 result = vec3(0.0); // height gradient X/Z, ring highlight
    float time = frameTimeCounter * 0.92;
    for (int y = -1; y <= 1; ++y) {
        for (int x = -1; x <= 1; ++x) {
            vec2 neighbour = cell + vec2(x, y);
            float seed = atrHash(neighbour);
            float cycle = floor(time + seed);
            float age = fract(time + seed);
            vec2 centre = neighbour + vec2(atrHash(neighbour + cycle + 17.0),
                                           atrHash(neighbour - cycle + 41.0));
            vec2 delta = tile - centre - atrWind() * age * 0.10;
            float distanceToCentre = length(delta);
            float radius = age * 0.58;
            float width = max(0.025, min(0.12, fwidth(distanceToCentre)));
            float q = (distanceToCentre - radius) / width;
            float envelope = exp(-q * q) * (1.0 - age) * smoothstep(0.0, 0.12, age);
            result.xy += (-2.0 * q * envelope) * delta / max(distanceToCentre, 0.001);
            result.z += envelope;
        }
    }
    return result;
}
#endif
