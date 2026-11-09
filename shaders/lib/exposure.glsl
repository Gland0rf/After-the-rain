#ifndef ATR_EXPOSURE
#define ATR_EXPOSURE
#include "/lib/weather.glsl"

// This shadow map is deliberately vertical, independent of the sun/moon.
// Cover a 192-block square and +/-512 blocks vertically around the camera.
const float ATR_ROOF_RADIUS = 96.0;
const float ATR_ROOF_HEIGHT = 512.0;
const float ATR_ROOF_TEXEL = 0.09375; // 192 / 2048, matches shadowMapResolution
#ifdef RAIN_SHELTER
uniform sampler2D shadowtex0;
#endif

vec2 atrRoofCenter() {
    // Snap by a texel to keep roof edges stable when walking.
    return floor(cameraPosition.xz / ATR_ROOF_TEXEL) * ATR_ROOF_TEXEL;
}

vec3 atrRoofClip(vec3 worldRelative) {
    vec2 horizontal = worldRelative.xz + cameraPosition.xz - atrRoofCenter();
    // -Z on screen preserves the winding of upward-facing terrain.
    return vec3(horizontal.x / ATR_ROOF_RADIUS, -horizontal.y / ATR_ROOF_RADIUS,
                -worldRelative.y / ATR_ROOF_HEIGHT);
}

float atrExposure(vec3 worldPos, float skylight) {
    float fallback = smoothstep(0.68, 0.96, skylight);
#ifdef RAIN_SHELTER
    vec3 clip = atrRoofClip(worldPos - cameraPosition);
    vec2 tex = clip.xy * 0.5 + 0.5;
    float edge = max(abs(clip.x), abs(clip.y));
    if (edge < 0.99 && abs(clip.z) < 0.99) {
        float receiver = clip.z * 0.5 + 0.5;
        ivec2 size = textureSize(shadowtex0, 0);
        vec2 pixel = tex * vec2(size) - 0.5;
        ivec2 base = ivec2(floor(pixel));
        vec2 fraction = fract(pixel);
        float visible = 0.0;
        // Bilinear comparison weights, anchored to world texels. Fixed 1/4
        // weights with nearest sampling could jump as samples crossed a texel.
        for (int y = 0; y < 2; ++y)
            for (int x = 0; x < 2; ++x) {
                ivec2 samplePixel = clamp(base + ivec2(x, y), ivec2(0), size - 1);
                float roof = texelFetch(shadowtex0, samplePixel, 0).r;
                vec2 weights = mix(vec2(1.0) - fraction, fraction, vec2(x, y));
                visible += step(receiver - 0.00004, roof) * weights.x * weights.y;
            }
        float mapped = visible;
        // Retain a skylight sanity check for unloaded/uncaptured cave roofs.
        mapped *= smoothstep(0.10, 0.55, skylight);
        return mix(mapped, fallback, smoothstep(0.88, 0.99, edge));
    }
#endif
    return fallback;
}

// Topmost captured height at a world column. Returns false outside the map,
// rather than treating a clear depth texel as an infinitely high/low roof.
bool atrRoofHeight(vec2 worldXZ, out float height) {
#ifdef RAIN_SHELTER
    vec2 clip = (worldXZ - atrRoofCenter()) / ATR_ROOF_RADIUS;
    vec2 tex = vec2(clip.x, -clip.y) * 0.5 + 0.5;
    if (max(abs(clip.x), abs(clip.y)) > 0.88) return false;
    float depth = texture(shadowtex0, tex).r;
    if (depth >= 0.99999) return false;
    height = cameraPosition.y + (0.5 - depth) * (2.0 * ATR_ROOF_HEIGHT);
    return true;
#else
    height = 0.0;
    return false;
#endif
}
#endif
