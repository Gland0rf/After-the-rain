#ifndef ATR_SURFACE_DETAILS
#define ATR_SURFACE_DETAILS
#include "/lib/weather.glsl"

// Surface decals, not airborne particles. Each cell has enough empty margin
// for its crown to finish before reaching the cell boundary.
float atrGroundSplash(vec2 worldXZ) {
#ifdef RAIN_SPLASHES
    vec2 tile = worldXZ * 2.3;
    vec2 cell = floor(tile);
    float seed = atrHash(cell + 77.3);
    float clock = frameTimeCounter * (1.25 + seed * 0.50) + seed;
    float cycle = floor(clock);
    float age = fract(clock);
    vec2 center = 0.28 + vec2(atrHash(cell + cycle + 9.7),
                              atrHash(cell - cycle + 21.3)) * 0.44;
    vec2 delta = fract(tile) - center;
    float radius = length(delta);
    float footprint = max(length(fwidth(tile)), 0.001);
    float aa = clamp(footprint * 0.65, 0.012, 0.035);
    float crownRadius = 0.025 + min(age / 0.28, 1.0) * 0.17;
    float crown = 1.0 - smoothstep(aa, aa * 2.0, abs(radius - crownRadius));
    float petals = 0.5 + 0.5 * cos(atan(delta.y, delta.x + 0.00001) * 5.0 + seed * 6.28);
    crown *= 0.30 + 0.70 * petals * petals;
    float core = 1.0 - smoothstep(0.012, 0.035 + aa, radius);
    float life = smoothstep(0.0, 0.025, age) * (1.0 - smoothstep(0.12, 0.28, age));
    return (crown * 0.65 + core * (1.0 - smoothstep(0.03, 0.09, age))) * life *
           (1.0 - smoothstep(0.10, 0.30, footprint));
#else
    return 0.0;
#endif
}

// X is the pool interior, Y is damp ground immediately outside its retreating
// edge. No time noise: a fixed world point dries without a crawling boundary.
vec2 atrDryingEdge(float field, float threshold, float wet, float dryPower) {
#ifdef DRYING_EDGES
    float aa = max(fwidth(field), 0.006);
    float width = max(0.035, aa);
    float pool = smoothstep(threshold - width, threshold + width, field);
    float fringe = smoothstep(threshold - 0.14 - aa, threshold - width, field);
    float drying = clamp((wet - atrRain()) * 2.0, 0.0, 1.0);
    float damp = max(0.0, fringe - pool) * drying * pow(max(wet, 0.0), dryPower);
    return vec2(pool, damp);
#else
    return vec2(smoothstep(threshold - 0.075, threshold + 0.075, field), 0.0);
#endif
}

vec3 atrFoliageBeads(vec3 color, vec2 faceUV, vec3 normal, vec3 relativePos,
                     float exposure, vec2 lightUV, int material) {
#ifdef WET_FOLIAGE
    if (!(material == 107 || material == 108 || material == 110 || material == 111)) return color;
    float moisture = atrWetness() * exposure;
    if (moisture < 0.003) return color;
    vec2 tile = faceUV * 7.0;
    vec2 cell = floor(tile);
    float seed = atrHash(cell + 31.7);
    vec2 center = 0.25 + 0.50 * vec2(atrHash(cell + 4.1), atrHash(cell + 19.3));
    float radius = length(fract(tile) - center);
    float footprint = max(length(fwidth(tile)), 0.001);
    float bead = (1.0 - smoothstep(0.055, 0.095 + footprint, radius)) *
                 smoothstep(0.64, 0.85, seed) * (1.0 - smoothstep(0.25, 0.8, footprint));
    vec3 view = -relativePos / max(length(relativePos), 0.0001);
    vec3 halfVector = atrSunDirection() + view;
    halfVector /= max(length(halfVector), 0.0001);
    float sunGlint = pow(max(dot(normal, halfVector), 0.0), 24.0) * atrDaylight();
    float light = max(lightUV.x * 0.45, lightUV.y * (0.20 + 0.80 * atrDaylight()));
    return color + vec3(0.10, 0.12, 0.13) * bead * moisture * light * (0.16 + sunGlint * 0.84);
#else
    return color;
#endif
}
#endif
