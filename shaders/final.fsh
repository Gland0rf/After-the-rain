#version 330 compatibility

#define STORM_GLOW // Subtle halo around bright lights in dark rainy scenes
#define STORM_VIGNETTE // Very light edge shading while it rains
//#define LENS_DROPLETS // Optional small lens droplets, mainly at screen edges

uniform sampler2D colortex0;
uniform float rainStrength;
uniform float wetness;
uniform float frameTimeCounter;
uniform float viewWidth;
uniform float viewHeight;
uniform int worldTime;
uniform int isEyeInWater;
uniform int biome_precipitation;
uniform ivec2 eyeBrightnessSmooth;

in vec2 uv;
layout(location = 0) out vec4 color;

float lensHash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 highlight(vec2 sampleUV) {
    vec3 c = texture(colortex0, clamp(sampleUV, vec2(0.001), vec2(0.999))).rgb;
    float bright = smoothstep(0.73, 0.98, max(max(c.r, c.g), c.b));
    return c * bright;
}

void main() {
    color = texture(colortex0, uv);
    float rain = clamp(rainStrength, 0.0, 1.0);
    if (max(rain, wetness) < 0.002 || isEyeInWater != 0) return;

    float day = smoothstep(-0.20, 0.20,
                 sin(float(worldTime) * 6.2831853 / 24000.0));
#ifdef STORM_GLOW
    if (rain > 0.015) {
        vec2 px = 1.0 / vec2(viewWidth, viewHeight);
        vec2 d1 = px * 5.0;
        vec2 d2 = px * 11.0;
        vec3 nearby = (highlight(uv + vec2( d1.x,  d1.y)) +
                       highlight(uv + vec2(-d1.x,  d1.y)) +
                       highlight(uv + vec2( d1.x, -d1.y)) +
                       highlight(uv + vec2(-d1.x, -d1.y)) +
                       highlight(uv + vec2( d2.x, 0.0)) +
                       highlight(uv + vec2(-d2.x, 0.0)) +
                       highlight(uv + vec2(0.0,  d2.y)) +
                       highlight(uv + vec2(0.0, -d2.y))) * 0.125;
        // Strongest around lamps at night, barely noticeable on a bright sky.
        color.rgb = min(color.rgb + nearby * rain * mix(0.12, 0.035, day), vec3(1.0));
    }
#endif

#ifdef STORM_VIGNETTE
    vec2 center = (uv - 0.5) * vec2(0.94, 1.0);
    float edge = smoothstep(0.15, 0.51, dot(center, center));
    color.rgb *= 1.0 - edge * rain * 0.085;
#endif

#ifdef LENS_DROPLETS
    // Off by default: a tiny refractive film, not large blurry splotches.
    float skyAccess = smoothstep(0.30, 0.78,
                                  float(eyeBrightnessSmooth.y) / 240.0);
    float lensRain = rain * skyAccess * float(biome_precipitation == 1);
    if (lensRain > 0.03) {
        float aspect = viewWidth / viewHeight;
        vec2 gridPos = uv * vec2(12.0 * aspect, 12.0);
        vec2 cell = floor(gridPos);
        float seed = lensHash(cell);
        float exists = step(0.81, seed);
        vec2 centerOffset = vec2(lensHash(cell + 4.1), lensHash(cell + 19.3));
        centerOffset = 0.18 + centerOffset * 0.64;
        centerOffset.y = fract(centerOffset.y - frameTimeCounter * (0.008 + seed * 0.011));
        vec2 displacement = (fract(gridPos) - centerOffset) * vec2(0.91, 1.22);
        float radius = length(displacement);
        float shape = (1.0 - smoothstep(0.10, 0.20, radius)) * exists;
        float rim = (1.0 - smoothstep(0.17, 0.24, radius)) -
                    (1.0 - smoothstep(0.09, 0.16, radius));
        rim *= exists;
        vec2 edges = abs(uv - 0.5) * 2.0;
        float border = smoothstep(0.37, 0.88, max(edges.x, edges.y));
        float mask = border * lensRain;
        vec2 refractUV = uv - displacement * 0.0038 * shape;
        color.rgb = mix(color.rgb, texture(colortex0, clamp(refractUV,
                              vec2(0.001), vec2(0.999))).rgb, shape * mask * 0.54);
        color.rgb += vec3(0.050, 0.060, 0.071) * rim * mask * 0.42;
    }
#endif
}