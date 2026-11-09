#ifndef ATR_WEATHER
#define ATR_WEATHER
#include "/lib/settings.glsl"

uniform float rainStrength;
uniform float wetness;
uniform float thunderStrength;
uniform float frameTimeCounter;
uniform float atrRainClimate;
uniform float atrLightningFlash;
uniform int worldTime;
uniform bool hasSkylight;
uniform vec3 cameraPosition;
uniform ivec3 cameraPositionInt;
uniform vec3 cameraPositionFract;
uniform vec3 fogColor;
uniform vec3 skyColor;
uniform vec3 sunPosition;
uniform mat4 gbufferModelViewInverse;

float atrHash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float atrNoise(vec2 p) {
    vec2 c = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(atrHash(c), atrHash(c + vec2(1.0, 0.0)), f.x),
               mix(atrHash(c + vec2(0.0, 1.0)), atrHash(c + 1.0), f.x), f.y);
}

float atrClimate() {
    // Iris exposes the camera biome, not a per-fragment biome. The CPU uniform
    // blends transitions over four seconds so crossing a border does not pop.
    return hasSkylight ? clamp(atrRainClimate, 0.0, 1.0) : 0.0;
}

float atrRain() { return clamp(rainStrength, 0.0, 1.0) * atrClimate(); }
float atrWetness() { return clamp(wetness, 0.0, 1.0) * atrClimate(); }
float atrClearing() {
    return clamp((wetness - rainStrength) * 2.0, 0.0, 1.0) * atrClimate();
}
float atrLightning() {
    return clamp(atrLightningFlash, 0.0, 1.0) * LIGHTNING_RESPONSE * atrClimate();
}
vec3 atrSunDirection() {
    vec3 direction = mat3(gbufferModelViewInverse) * sunPosition;
    return direction / max(length(direction), 0.0001);
}
float atrThunder() {
#ifdef THUNDER_ATMOSPHERE
    return clamp(thunderStrength, 0.0, 1.0) * atrClimate();
#else
    return 0.0;
#endif
}
float atrDaylight() {
    return smoothstep(-0.22, 0.22, sin(float(worldTime) * 6.2831853 / 24000.0));
}

float atrGust() {
#ifdef WIND_GUSTS
    return 1.0 + 0.24 * cos(frameTimeCounter * 0.17)
               + 0.12 * cos(frameTimeCounter * 0.43);
#else
    return 1.0;
#endif
}

vec2 atrWind() { return vec2(0.19, -0.09) * RAIN_WIND * atrGust(); }

vec2 atrWindTravel() {
    // Integrate the gust speed; multiplying time by a changing speed would jump.
    float t = frameTimeCounter;
#ifdef WIND_GUSTS
    t += (0.24 / 0.17) * sin(t * 0.17) + (0.12 / 0.43) * sin(t * 0.43);
#endif
    return vec2(0.19, -0.09) * RAIN_WIND * t;
}

vec3 atrFoliageOffset(vec3 worldPos, int material, float topVertex) {
#ifdef FOLIAGE_WIND
    if (material == 107 || material == 108 || material == 110 || material == 111) {
        float anchor = material == 108 ? topVertex : 0.45;
        // Shared displacement at the seam between two-block plant halves.
        if (material == 110) anchor = topVertex * 0.5;
        if (material == 111) anchor = 0.5 + topVertex * 0.5;
        float wave = sin(dot(worldPos.xz, vec2(0.63, 0.41)) + frameTimeCounter * 1.9);
        return vec3(atrWind().x, 0.0, atrWind().y) * wave * anchor * atrRain() * 0.42;
    }
#endif
    return vec3(0.0);
}
#endif
