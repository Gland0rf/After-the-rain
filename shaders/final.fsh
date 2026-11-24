#version 330 compatibility
#include "/lib/exposure.glsl"
#include "/lib/lens.glsl"


uniform sampler2D colortex0;
uniform float viewWidth;
uniform float viewHeight;
uniform int isEyeInWater;
uniform int biome_precipitation;
uniform ivec2 eyeBrightnessSmooth;

in vec2 uv;
layout(location = 0) out vec4 color;

vec3 highlight(vec2 sampleUV) {
    vec3 c = texture(colortex0, clamp(sampleUV, vec2(0.001), vec2(0.999))).rgb;
    float bright = smoothstep(0.73, 0.98, max(max(c.r, c.g), c.b));
    return c * bright;
}

void main() {
    color = texture(colortex0, uv);
#if WEATHER_DEBUG > 0
    return;
#endif
    float rain = atrRain();
    if (max(rain, atrWetness()) < 0.002 || isEyeInWater != 0) return;

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
    float skyAccess = atrExposureRelative(vec3(0.0), float(eyeBrightnessSmooth.y) / 240.0);
    float lensRain = rain * skyAccess * float(biome_precipitation == 1) * LENS_DROPLET_AMOUNT;
    if (lensRain > 0.03) {
        float aspect = viewWidth / viewHeight;
        vec4 drop = atrLensDrop(uv, aspect);
        float shape = drop.z;
        float rim = drop.w;
        float mask = lensRain;
        vec2 refractUV = uv - drop.xy * 0.0038;
        color.rgb = mix(color.rgb, texture(colortex0, clamp(refractUV,
                              vec2(0.001), vec2(0.999))).rgb, shape * mask * 0.54);
        color.rgb += vec3(0.050, 0.060, 0.071) * rim * mask * 0.42;
    }
#endif
}
