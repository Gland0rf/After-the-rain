#ifndef ATR_EXPOSURE
#define ATR_EXPOSURE
#include "/lib/weather.glsl"

// This shadow map is deliberately vertical, independent of the sun/moon.
// Cover a 192-block square and +/-512 blocks vertically around the camera.
const float ATR_ROOF_RADIUS = 96.0;
const float ATR_ROOF_HEIGHT = 512.0;
const float ATR_ROOF_TEXEL = 0.09375; // 192 / 2048, matches shadowMapResolution
#ifdef RAIN_SHELTER
uniform sampler2D shadowcolor0;
#endif

vec2 atrRoofOffset() {
#ifdef IS_IRIS
    // Iris supplies the integer and fractional camera components separately.
    // Preserve the fraction instead of recovering it from a large float.
    // Three blocks is exactly 32 roof texels, so every recenter preserves the
    // world grid throughout the overlapping part of the map.
    ivec2 cell = cameraPositionInt.xz % ivec2(3);
    cell = (cell + ivec2(3)) % ivec2(3);
    return vec2(cell) + cameraPositionFract.xz;
#else
    return mod(cameraPosition.xz, vec2(3.0));
#endif
}

vec2 atrRoofCenter() {
    // Used by world-grid drip sources. Snap the result back to an exact integer
    // grid rather than retaining rounding from cameraPosition's large floats.
    return round((cameraPosition.xz - atrRoofOffset()) / 3.0) * 3.0;
}

vec3 atrRoofClip(vec3 worldRelative) {
    // Keep the projection in a small coordinate range. Adding the absolute
    // camera position first would throw away the very sub-texel bits we need.
    vec2 horizontal = worldRelative.xz + atrRoofOffset();
    // -Z on screen preserves the winding of upward-facing terrain.
    return vec3(horizontal.x / ATR_ROOF_RADIUS, -horizontal.y / ATR_ROOF_RADIUS,
                -worldRelative.y / ATR_ROOF_HEIGHT);
}

float atrExposureRelative(vec3 relativePos, float skylight) {
    float fallback = smoothstep(0.68, 0.96, skylight);
#ifdef RAIN_SHELTER
    vec3 clip = atrRoofClip(relativePos);
    vec2 tex = clip.xy * 0.5 + 0.5;
    float edge = max(abs(clip.x), abs(clip.y));
    if (edge < 0.99 && abs(clip.z) < 0.99) {
        ivec2 size = textureSize(shadowcolor0, 0);
        vec2 pixel = tex * vec2(size) - 0.5;
        ivec2 base = ivec2(floor(pixel));
        vec2 fraction = fract(pixel);
        float visible = 0.0;
        // Bilinear comparison weights, anchored to world texels. Fixed 1/4
        // weights with nearest sampling could jump as samples crossed a texel.
        for (int y = 0; y < 2; ++y)
            for (int x = 0; x < 2; ++x) {
                ivec2 samplePixel = clamp(base + ivec2(x, y), ivec2(0), size - 1);
                vec2 roof = texelFetch(shadowcolor0, samplePixel, 0).rg;
                // Use an absolute height gap in blocks, independent of camera
                // height and depth-buffer precision. Never classify a surface
                // as sheltered merely because it differs by a rounding error.
                float exposed = roof.g > 0.5 ?
                    1.0 - smoothstep(0.015, 0.045, roof.r - (cameraPosition.y + relativePos.y)) : fallback;
                vec2 weights = mix(vec2(1.0) - fraction, fraction, vec2(x, y));
                visible += exposed * weights.x * weights.y;
            }
        float mapped = visible;
        // Retain a skylight sanity check for unloaded/uncaptured cave roofs.
        mapped *= smoothstep(0.10, 0.55, skylight);
        return mix(mapped, fallback, smoothstep(0.88, 0.99, edge));
    }
#endif
    return fallback;
}

float atrExposure(vec3 worldPos, float skylight) {
    return atrExposureRelative(worldPos - cameraPosition, skylight);
}

// Topmost captured height at a world column. G=0 means no surface was captured.
bool atrRoofHeight(vec2 worldXZ, out float height) {
#ifdef RAIN_SHELTER
    vec2 clip = (worldXZ - atrRoofCenter()) / ATR_ROOF_RADIUS;
    vec2 tex = vec2(clip.x, -clip.y) * 0.5 + 0.5;
    if (max(abs(clip.x), abs(clip.y)) > 0.88) return false;
    ivec2 size = textureSize(shadowcolor0, 0);
    ivec2 pixel = clamp(ivec2(tex * vec2(size)), ivec2(0), size - 1);
    vec2 roof = texelFetch(shadowcolor0, pixel, 0).rg;
    if (roof.g < 0.5) return false;
    height = roof.r;
    return true;
#else
    height = 0.0;
    return false;
#endif
}
#endif
