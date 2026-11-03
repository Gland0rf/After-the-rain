
#version 330 compatibility
/* RENDERTARGETS: 0 */

#define STORM_SKY // A layered overcast sky with shifting distant cloud banks
#define STORM_CLOUD_COVER 0.82 // [0.45 0.60 0.72 0.82 0.92]
#define STORM_SKY_DARKNESS 0.72 // [0.35 0.50 0.72 0.88 1.00]
#define STORM_CLOUD_WIND 0.45 // [0.10 0.25 0.45 0.70 1.00]

uniform int renderStage;
uniform int worldTime;
uniform float viewHeight;
uniform float viewWidth;
uniform float rainStrength;
uniform float wetness;
uniform float frameTimeCounter;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform vec3 fogColor;
uniform vec3 skyColor;
uniform vec3 cameraPosition;

in vec4 glcolor;
layout(location = 0) out vec4 color;

float skyHash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float skyNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(skyHash(i), skyHash(i + vec2(1.0, 0.0)), f.x),
               mix(skyHash(i + vec2(0.0, 1.0)), skyHash(i + vec2(1.0)), f.x), f.y);
}

float skyFbm(vec2 p) {
    float n = 0.0;
    float a = 0.56;
    n += a * skyNoise(p); p = p * 2.03 + vec2(11.1, 7.7); a *= 0.5;
    n += a * skyNoise(p); p = p * 2.01 + vec2(3.4, 19.6); a *= 0.5;
    n += a * skyNoise(p); p = p * 2.02 + vec2(17.2, 1.3); a *= 0.5;
    n += a * skyNoise(p);
    return n;
}

void main() {
    // Never replace stars, the sun, the sunset alpha layer or the void.
    if (renderStage != MC_RENDER_STAGE_SKY) {
        color = glcolor;
        return;
    }

    vec2 screenUV = gl_FragCoord.xy / vec2(viewWidth, viewHeight);
    vec4 ray = gbufferProjectionInverse * vec4(screenUV * 2.0 - 1.0, 1.0, 1.0);
    vec3 dirVS = normalize(ray.xyz / max(abs(ray.w), 0.0001) * sign(ray.w));
    vec3 dirWS = normalize(mat3(gbufferModelViewInverse) * dirVS);
    float up = dirWS.y;
    float horizon = smoothstep(-0.13, 0.64, up);
    vec3 originalSky = mix(fogColor, skyColor, horizon);

#ifdef STORM_SKY
    float storm = clamp(rainStrength * 1.08 + wetness * 0.08, 0.0, 1.0);
    if (storm < 0.001) {
        color = vec4(originalSky, 1.0);
        return;
    }    float daylight = smoothstep(-0.22, 0.20,
                     sin(float(worldTime) * 6.2831853 / 24000.0));
    float skyGrad = smoothstep(-0.14, 0.90, up);

    vec3 horizonCol = mix(vec3(0.050, 0.058, 0.074),
                          vec3(0.42, 0.44, 0.46), daylight);
    vec3 zenithCol  = mix(vec3(0.020, 0.027, 0.040),
                          vec3(0.24, 0.27, 0.30), daylight);
    vec3 overcast = mix(horizonCol, zenithCol, skyGrad);
    overcast *= mix(1.05, 0.74, STORM_SKY_DARKNESS);

    // World-anchored layered cloud field so the sky feels broad and alive.
    float aboveHorizon = smoothstep(0.01, 0.22, up);
    vec2 dirProject = dirWS.xz / (max(up, 0.03) + 0.22);
   vec2 anchor = cameraPosition.xz * 0.0038 + dirProject;
    vec2 wind = vec2(0.030, -0.013) * STORM_CLOUD_WIND * frameTimeCounter;

    float broad = skyFbm(anchor * 1.08 + wind * 0.55);
    float mid   = skyFbm(anchor * 2.25 - wind * 0.95 + vec2(13.4, 2.1));
    float fine  = skyFbm(anchor * 4.40 + wind * 1.45 + vec2(2.7, 17.2));
    float field = broad * 0.56 + mid * 0.31 + fine * 0.13;
    float billow = skyFbm(anchor * 1.35 - wind * 0.22 + vec2(31.2, 5.8));

    float coverLo = mix(0.62, 0.42, STORM_CLOUD_COVER);
    float coverHi = mix(0.84, 0.67, STORM_CLOUD_COVER);
    float cloudMask = smoothstep(coverLo, coverHi, field + billow * 0.18);
    cloudMask *= aboveHorizon;

    // Lower, heavier cloud banks near the horizon.
    float bankBand = smoothstep(0.015, 0.16, up) * (1.0 - smoothstep(0.26, 0.46, up));
    float horizonBank = smoothstep(0.50, 0.72,
                            skyFbm(anchor * vec2(1.95, 0.92) - wind * 0.35 + vec2(7.6, 21.3)));
    horizonBank *= bankBand * (0.38 + 0.62 * storm);

    // Subtle dark channels stop the sky from feeling too airbrushed.
    float veins = smoothstep(0.46, 0.78,
                    skyFbm(anchor * 3.2 - wind * 1.15 + vec2(23.4, 9.8)));

    vec3 cloudDark  = mix(vec3(0.030, 0.036, 0.045), vec3(0.19, 0.21, 0.23), daylight);
    vec3 cloudLight = mix(vec3(0.075, 0.084, 0.095), vec3(0.36, 0.38, 0.40), daylight);
    float lighting = smoothstep(0.28, 0.78, mid * 0.65 + broad * 0.35);
    vec3 cloudCol = mix(cloudDark, cloudLight, lighting);
    cloudCol *= mix(1.02, 0.68, STORM_SKY_DARKNESS);
    cloudCol *= 1.0 - veins * 0.10;

    vec3 bankDark = mix(vec3(0.040, 0.046, 0.056), vec3(0.24, 0.25, 0.27), daylight);
    vec3 bankLight = mix(vec3(0.090, 0.098, 0.108), vec3(0.43, 0.44, 0.45), daylight);
    vec3 bankCol = mix(bankDark, bankLight, smoothstep(0.35, 0.77, broad));
    bankCol *= mix(1.0, 0.72, STORM_SKY_DARKNESS);

    // General overcast texture even between defined cloud banks.
    float mottling = (field - 0.5) * 0.10 * (0.30 + 0.70 * daylight);
    overcast += vec3(mottling * 0.85, mottling * 0.92, mottling);

    vec3 stormSky = mix(overcast, cloudCol, cloudMask * (0.54 + storm * 0.24));
    stormSky = mix(stormSky, bankCol, horizonBank * 0.88);

    // Darken the storm ceiling slightly when looking upward in heavy rain.
    float ceiling = smoothstep(0.35, 0.92, up) * storm;
    stormSky *= 1.0 - ceiling * 0.10 * STORM_SKY_DARKNESS;

    color = vec4(mix(originalSky, clamp(stormSky, 0.0, 1.0), storm), 1.0);
#else
    color = vec4(originalSky, 1.0);
#endif
}
