#version 330 compatibility

/* RENDERTARGETS: 0 */

#define STORM_SKY
#define STORM_CLOUD_COVER 0.78 // [0.35 0.50 0.65 0.78 0.90 1.00]
#define STORM_SKY_DARKNESS 0.60 // [0.20 0.40 0.60 0.80 1.00]

uniform int renderStage;
uniform float viewHeight;
uniform float viewWidth;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform vec3 fogColor;
uniform vec3 skyColor;
uniform float rainStrength;
uniform float thunderStrength;
uniform float sunAngle;
uniform float frameTimeCounter;

in vec4 glcolor;
layout(location = 0) out vec4 color;

float skyHash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float skyValueNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f*f*(3.0 - 2.0*f);
    return mix(mix(skyHash(i), skyHash(i + vec2(1.0, 0.0)), f.x),
            mix(skyHash(i + vec2(0.0, 1.0)), skyHash(i + 1.0), f.x), f.y);
}

// Multiple noise scales make rounded, non-repeating clouds rather than white static.
float skyCloudFbm(vec2 p) {
    float a = 0.52 * skyValueNoise(p);
    a += 0.27 * skyValueNoise(p * 2.07 + vec2(13.1, 7.4));
    a += 0.14 * skyValueNoise(p * 4.17 + vec2(5.3, 29.9));
    a += 0.07 * skyValueNoise(p * 8.23 + vec2(17.8, 3.6));
    return a;
}

void main() {
    if (renderStage == MC_RENDER_STAGE_SUNSET) {
        color = glcolor;
#ifdef STORM_SKY
    float storm = smoothstep(0.015, 0.90, rainStrength);
    color.rgb = mix(color.rgb, vec3(0.34, 0.37, 0.40), storm * 0.48);
    color.a *= 1.0 - 0.72 * storm;
#endif
        return;
    }
    if (renderStage != MC_RENDER_STAGE_SKY) {
        color = glcolor;
        return;
    }

    vec2 screenUV = gl_FragCoord.xy / vec2(viewWidth, viewHeight);
    vec4 clipRay = gbufferProjectionInverse * vec4(screenUV * 2.0 - 1.0, 1.0, 1.0);
    vec3 viewDir = normalize(clipRay.xyz / clipRay.w);
    vec3 worldDir = normalize(mat3(gbufferModelViewInverse) * viewDir);
    float skyHeight = worldDir.y;
    
    float horizon = smoothstep(-0.12, 0.67, skyHeight);
    vec3 drySky = mix(fogColor, skyColor, horizon);
    color = vec4(drySky, 1.0);

#ifdef STORM_SKY
    float rain = smoothstep(0.015, 0.90, rainStrength);
    if (rain < 0.002) return;

    // Sunrise=0, noon=.25, sunset=.5, midnight=.75 for sunAngle.
    float sunHeight = sin(sunAngle * 6.28318530718);
    float daylight = smoothstep(-0.18, 0.14, sunHeight);
    float gradient = smoothstep(-0.10, 0.80, skyHeight);

    vec3 horizonDay = vec3(0.43, 0.46, 0.48);
    vec3 zenithDay  = vec3(0.25, 0.29, 0.33);
    vec3 horizonNight = vec3(0.065, 0.078, 0.092);
    vec3 zenithNight  = vec3(0.020, 0.030, 0.046);

    vec3 stormHorizon = mix(horizonNight, horizonDay, daylight);
    vec3 stormZenith = mix(zenithNight, zenithDay, daylight);
    vec3 stormSky = mix(stormHorizon, stormZenith, gradient);
    stormSky *= mix(1.12, 0.73, STORM_SKY_DARKNESS);

    // Cloud layers stay fixed relative to the world view direction, not screen UV.
    // Fast-moving background cloud shapes; strong horizon fade keeps a soft horizon.
    float aboveHorizon = smoothstep(0.025, 0.24, skyHeight);
    vec2 projected = worldDir.xz / (max(skyHeight, 0.045) + 0.24);
    vec2 wind = vec2(0.009, 0.0035) * frameTimeCounter;
    float broad = skyCloudFbm(projected * 1.60 + wind);
    float small = skyCloudFbm(projected * 3.80 - wind * 0.48 + vec2(19.3, 4.7));
    float field = broad * 0.82 + small * 0.18;
    float cloudMask = smoothstep(0.56 - 0.15 * STORM_CLOUD_COVER,
                                  0.69 - 0.12 * STORM_CLOUD_COVER, field);
    cloudMask *= aboveHorizon;

    vec3 cloudDark  = mix(vec3(0.035, 0.046, 0.065), vec3(0.20, 0.24, 0.28), daylight);
    vec3 cloudLight = mix(vec3(0.085, 0.10, 0.125), vec3(0.38, 0.41, 0.43), daylight);
    float cloudLighting = smoothstep(0.30, 0.73, small);
    vec3 stormCloud = mix(cloudDark, cloudLight, cloudLighting);
    stormCloud *= mix(1.06, 0.70, STORM_SKY_DARKNESS);
    stormSky = mix(stormSky, stormCloud, cloudMask * 0.88);

    stormSky *= 1.0 - thunderStrength * 0.14;
    color.rgb = mix(drySky, stormSky, rain);
#endif    
}
