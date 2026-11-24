#version 330 compatibility
/* RENDERTARGETS: 5 */
#include "/lib/exposure.glsl"
#include "/lib/atmosphere.glsl"
#include "/lib/sky.glsl"

/*
const int colortex5Format = RGBA16F;
*/
const bool colortex5Clear = true;
const vec4 colortex5ClearColor = vec4(0.0, 0.0, 0.0, 0.0);

uniform sampler2D colortex0;
uniform sampler2D depthtex0;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform int isEyeInWater;
uniform ivec2 eyeBrightnessSmooth;
in vec2 uv;
layout(location = 0) out vec4 outShafts;

float shaftSceneDistance(vec2 tex, float depth) {
    if (depth >= 0.999999) return 512.0;
    vec4 position = gbufferProjectionInverse * vec4(tex * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    return min(512.0, length(position.xyz / max(abs(position.w), 0.00001)));
}

void main() {
    float depth = texture(depthtex0, uv).r;
    float sceneDistance = shaftSceneDistance(uv, depth);
    outShafts = vec4(0.0, 0.0, 0.0, sceneDistance);
#if WEATHER_DEBUG > 0
    return;
#endif
#ifdef SUN_SHAFTS
    float weather = atrShaftWeatherWeight();
    if (weather < 0.002 || isEyeInWater != 0 || SUN_SHAFT_STRENGTH < 0.001) return;
    float exposure = atrExposureRelative(vec3(0.0), float(eyeBrightnessSmooth.y) / 240.0);
    if (exposure < 0.01) return;
    vec4 sunClip = gbufferProjection * vec4(sunPosition, 1.0);
    if (sunClip.w <= 0.0001) return;
    vec2 sunUV = sunClip.xy / sunClip.w * 0.5 + 0.5;
    float outside = max(abs(sunUV.x - 0.5), abs(sunUV.y - 0.5));
    float screenFade = 1.0 - smoothstep(0.55, 1.10, outside);
    if (screenFade < 0.001) return;
#if ATMOSPHERE_QUALITY == 0
    const int samples = 8;
#elif ATMOSPHERE_QUALITY == 1
    const int samples = 12;
#else
    const int samples = 20;
#endif
    vec2 rayStep = (sunUV - uv) * (0.85 / float(samples));
    float skyBrightness = max(dot(atrSkyAmbient(), vec3(0.2126, 0.7152, 0.0722)), 0.08);
    float illumination = 1.0;
    float total = 0.0;
    for (int i = 0; i < samples; ++i) {
        vec2 sampleUV = uv + rayStep * (float(i) + 0.5);
        if (any(lessThan(sampleUV, vec2(0.001))) || any(greaterThan(sampleUV, vec2(0.999)))) break;
        float sky = smoothstep(0.999995, 1.0, texture(depthtex0, sampleUV).r);
        vec3 sampleColor = texture(colortex0, sampleUV).rgb;
        float brightness = dot(sampleColor, vec3(0.2126, 0.7152, 0.0722));
        float opening = smoothstep(skyBrightness * 0.65, skyBrightness * 1.45, brightness);
        total += sky * opening * illumination;
        illumination *= 0.94;
    }
    float lowSun = 1.0 - smoothstep(0.15, 0.65, atrSunDirection().y);
    vec3 tint = mix(vec3(1.0, 0.96, 0.88), vec3(1.0, 0.79, 0.51), lowSun);
    float amount = total / float(samples) * weather * exposure * screenFade * SUN_SHAFT_STRENGTH * 0.18;
    outShafts.rgb = tint * amount;
#endif
}
