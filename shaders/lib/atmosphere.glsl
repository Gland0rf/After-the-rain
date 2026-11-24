#ifndef ATR_ATMOSPHERE
#define ATR_ATMOSPHERE
#include "/lib/weather.glsl"

uniform float cloudHeight;

vec4 atrRainCurtain(vec3 direction, float sceneDistance, float eyeSkylight) {
    vec4 curtain = vec4(0.0);
#ifdef DISTANT_RAIN
    float rain = atrRain();
    float access = smoothstep(0.05, 0.60, eyeSkylight);
    float endDistance = min(sceneDistance, 180.0);
    if (rain < 0.02 || access < 0.005 || endDistance <= 16.0 || RAIN_CURTAIN_AMOUNT < 0.001) return curtain;
#if ATMOSPHERE_QUALITY == 0
    const int samples = 8;
#elif ATMOSPHERE_QUALITY == 1
    const int samples = 12;
#else
    const int samples = 20;
#endif
    float ceiling = cloudHeight;
    // Iris reports NaN for dimensions without a cloud plane. Comparisons also
    // reject that case without allowing NaN into the volume calculation.
    if (!(ceiling > -1024.0 && ceiling < 4096.0)) ceiling = MIST_HEIGHT + 160.0;
    ceiling = max(ceiling, MIST_HEIGHT + 96.0);
    float stepLength = (endDistance - 16.0) / float(samples);
    vec2 wind = atrWindTravel() * 0.035;
    float density = 0.0;
    for (int i = 0; i < samples; ++i) {
        float distanceAlongRay = 16.0 + (float(i) + 0.5) * stepLength;
        vec3 point = cameraPosition + direction * distanceAlongRay;
        float belowClouds = 1.0 - smoothstep(ceiling - 8.0, ceiling + 24.0, point.y);
        if (belowClouds < 0.001) continue;
        vec2 fieldPosition = point.xz * 0.014 + wind;
        float broad = atrNoise(fieldPosition);
        // Even a maximal detail value cannot form a band below this bound.
        if (broad < 0.277) continue;
        float detail = atrNoise(fieldPosition * 2.93 + vec2(17.2, 8.3));
        float band = smoothstep(0.48, 0.68, broad * 0.72 + detail * 0.28);
        if (band < 0.001) continue;
        float streaking = 0.72 + 0.28 * atrNoise(vec2(dot(point.xz, vec2(0.14, -0.06)),
                                                     point.y * 0.008 + frameTimeCounter * 0.15));
        density += band * belowClouds * streaking * stepLength;
    }
    float opticalDepth = density * 0.0045 * atrBiomeMistScale();
    curtain.a = min(0.30, 1.0 - exp(-opticalDepth)) * rain * access * RAIN_CURTAIN_AMOUNT;
    curtain.rgb = mix(vec3(0.055, 0.068, 0.090), vec3(0.36, 0.395, 0.42), atrDaylight());
    curtain.rgb *= atrBiomeFogTint();
    curtain.rgb += vec3(0.12, 0.15, 0.20) * atrLightning();
#endif
    return curtain;
}

float atrShaftWeatherWeight() {
#ifdef SUN_SHAFTS
    float sunAboveHorizon = smoothstep(0.02, 0.18, atrSunDirection().y);
    return atrClearing() * (1.0 - atrRain() * 0.60) * sunAboveHorizon * atrDaylight();
#else
    return 0.0;
#endif
}
#endif
