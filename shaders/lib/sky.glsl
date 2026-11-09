#ifndef ATR_SKY
#define ATR_SKY
#include "/lib/weather.glsl"

vec3 atrSkyAmbient() {
    float day = atrDaylight();
    vec3 clear = mix(fogColor, skyColor, 0.65);
    vec3 overcast = mix(vec3(0.035, 0.045, 0.060), vec3(0.28, 0.30, 0.33), day);
    overcast *= mix(1.0, 0.78, STORM_SKY_DARKNESS) * (1.0 - atrThunder() * 0.15);
#ifdef STORM_SKY
    clear = mix(clear, overcast, clamp(atrRain() + atrWetness() * 0.04, 0.0, 1.0));
#endif
    return clamp(clear + vec3(0.12, 0.14, 0.19) * atrLightning(), 0.0, 1.0);
}

vec3 atrSkyFinish(vec3 color, vec3 direction) {
    vec3 sun = atrSunDirection();
    float clearing = atrClearing();
#ifdef CLEARING_SKY
    float lowSun = (1.0 - smoothstep(0.15, 0.65, sun.y)) * smoothstep(0.0, 0.10, sun.y);
    float sunward = pow(max(dot(direction, sun), 0.0), 6.0);
    float warmth = clearing * atrDaylight() * lowSun;
    color = mix(color, color * vec3(1.12, 1.025, 0.94) + vec3(0.025, 0.009, 0.0),
                warmth * (0.15 + sunward * 0.65));
#endif
#ifdef AFTER_RAIN_RAINBOW
    // A 40--42 degree cone around the anti-solar direction; never a screen arc.
    float angle = acos(clamp(dot(direction, -sun), -1.0, 1.0));
    float band = clamp((angle - 0.698) / 0.042, 0.0, 1.0);
    float arc = smoothstep(0.695, 0.702, angle) * (1.0 - smoothstep(0.735, 0.743, angle));
    vec3 violetBlue = mix(vec3(0.35, 0.14, 0.52), vec3(0.10, 0.38, 0.66), smoothstep(0.0, 0.30, band));
    vec3 greenYellow = mix(vec3(0.18, 0.55, 0.30), vec3(0.70, 0.55, 0.12), smoothstep(0.45, 0.75, band));
    vec3 spectrum = mix(violetBlue, greenYellow, smoothstep(0.25, 0.50, band));
    spectrum = mix(spectrum, vec3(0.68, 0.20, 0.13), smoothstep(0.75, 1.0, band));
    float visibility = clearing * atrWetness() * smoothstep(0.02, 0.14, sun.y) *
                       (1.0 - smoothstep(0.50, 0.70, sun.y)) * smoothstep(0.0, 0.06, direction.y);
    color += spectrum * arc * visibility * 0.10;
#endif
    color += vec3(0.18, 0.21, 0.28) * atrLightning() * (0.65 + max(direction.y, 0.0) * 0.35);
    return clamp(color, 0.0, 1.0);
}

float atrSkyFbm(vec2 p) {
    float n = 0.56 * atrNoise(p);
    p = p * 2.03 + vec2(11.1, 7.7);
    n += 0.28 * atrNoise(p);
#if SKY_QUALITY >= 1
    p = p * 2.01 + vec2(3.4, 19.6);
    n += 0.14 * atrNoise(p);
#endif
#if SKY_QUALITY >= 2
    p = p * 2.02 + vec2(17.2, 1.3);
    n += 0.07 * atrNoise(p);
#endif
    // Keep coverage comparable across octave counts.
#if SKY_QUALITY == 0
    return n * 1.25;
#elif SKY_QUALITY == 1
    return n * 1.0714286;
#else
    return n;
#endif
}

vec3 atrSky(vec3 direction, vec3 origin) {
    float up = direction.y;
    vec3 original = mix(fogColor, skyColor, smoothstep(-0.13, 0.64, up));
#ifdef STORM_SKY
    float clearing = 0.0;
#ifdef CLEARING_SKY
    clearing = atrClearing();
#endif
    float storm = clamp(atrRain() + atrWetness() * 0.04 + clearing * 0.30, 0.0, 1.0);
    if (storm < 0.001) return atrSkyFinish(original, direction);
    float daylight = atrDaylight();
    float thunder = atrThunder();
    vec3 horizon = mix(vec3(0.050, 0.058, 0.074), vec3(0.42, 0.44, 0.46), daylight);
    vec3 zenith = mix(vec3(0.020, 0.027, 0.040), vec3(0.24, 0.27, 0.30), daylight);
    vec3 overcast = mix(horizon, zenith, smoothstep(-0.14, 0.90, up));
    float darkness = STORM_SKY_DARKNESS * mix(0.72, 1.0, thunder);
    overcast *= mix(1.05, 0.74, darkness) * (1.0 - thunder * 0.15);
    vec3 stormSky = overcast;
#ifdef STORM_CLOUDS
    float aboveHorizon = smoothstep(0.01, 0.22, up);
    vec2 anchor = origin.xz * 0.0038 + direction.xz / (max(up, 0.03) + 0.22);
    vec2 wind = atrWindTravel() * STORM_CLOUD_WIND * 0.16;
    float broad = atrSkyFbm(anchor * 1.08 + wind * 0.55);
    float mid = atrSkyFbm(anchor * 2.25 + wind * 0.95 + vec2(13.4, 2.1));
    float field = broad * 0.64 + mid * 0.36;
#if SKY_QUALITY >= 1
    float fine = atrSkyFbm(anchor * 4.40 + wind * 1.45 + vec2(2.7, 17.2));
    field = field * 0.87 + fine * 0.13;
#endif
    float cover = clamp(STORM_CLOUD_COVER + thunder * 0.07, 0.0, 1.0);
    float cloudMask = smoothstep(mix(0.62, 0.42, cover),
                                 mix(0.84, 0.67, cover), field + broad * 0.18);
    cloudMask *= aboveHorizon;
    cloudMask *= 1.0 - clearing * smoothstep(0.35, 0.70, broad) * 0.70;
    vec3 darkCloud = mix(vec3(0.030, 0.036, 0.045), vec3(0.19, 0.21, 0.23), daylight);
    vec3 lightCloud = mix(vec3(0.075, 0.084, 0.095), vec3(0.36, 0.38, 0.40), daylight);
    vec3 cloud = mix(darkCloud, lightCloud, smoothstep(0.28, 0.78, mid * 0.65 + broad * 0.35));
    cloud *= mix(1.02, 0.68, darkness) * (1.0 - thunder * 0.16);
    stormSky = mix(overcast, cloud, cloudMask * (0.54 + storm * 0.24));
#if SKY_QUALITY >= 2
    float bankBand = smoothstep(0.015, 0.16, up) * (1.0 - smoothstep(0.26, 0.46, up));
    float bank = atrSkyFbm(anchor * vec2(1.95, 0.92) + wind * 0.35 + vec2(7.6, 21.3));
    stormSky = mix(stormSky, cloud * 0.86, smoothstep(0.50, 0.72, bank) * bankBand * 0.65);
#endif
    stormSky += (field - 0.5) * vec3(0.085, 0.092, 0.10) * (0.30 + 0.70 * daylight);
#endif
    stormSky *= 1.0 - smoothstep(0.35, 0.92, up) * storm * darkness * 0.10;
    return atrSkyFinish(mix(original, clamp(stormSky, 0.0, 1.0), storm), direction);
#else
    return atrSkyFinish(original, direction);
#endif
}
#endif
