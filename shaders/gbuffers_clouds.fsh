#version 330 compatibility

/* RENDERTARGETS: 0 */

#define STORM_CLOUDS // Animated shading and heavy gray storm clouds
#define STORM_CLOUD_COVER 0.82 // [0.45 0.60 0.72 0.82 0.92]
#define STORM_SKY_DARKNESS 0.72 // [0.35 0.50 0.72 0.88 1.00]
#define STORM_CLOUD_WIND 0.45 // [0.10 0.25 0.45 0.70 1.00]

uniform sampler2D gtexture;
uniform float alphaTestRef = 0.1;
uniform float rainStrength;
uniform float frameTimeCounter;
uniform int worldTime;

in vec2 texcoord;
in vec4 glcolor;
in vec3 cloudWorldPos;
in vec3 cloudWorldNormal;
layout(location = 0) out vec4 color;

float cloudHash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float cloudNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(cloudHash(i), cloudHash(i + vec2(1.0, 0.0)), f.x),
               mix(cloudHash(i + vec2(0.0, 1.0)), cloudHash(i + vec2(1.0)), f.x), f.y);
}

float cloudFbm(vec2 p) {
    float n = 0.0;
    float a = 0.56;
    n += a * cloudNoise(p); p = p * 2.02 + vec2(11.4, 5.1); a *= 0.5;
    n += a * cloudNoise(p); p = p * 2.01 + vec2(3.7, 16.8); a *= 0.5;
    n += a * cloudNoise(p); p = p * 2.03 + vec2(19.2, 2.3); a *= 0.5;
    n += a * cloudNoise(p);
    return n;
}

void main() {
    color = texture(gtexture, texcoord) * glcolor;
    if (color.a < alphaTestRef) discard;

#ifdef STORM_CLOUDS
    float storm = smoothstep(0.06, 0.90, rainStrength);
    if (storm > 0.001) {
        float daylight = smoothstep(-0.18, 0.22,
                         sin(float(worldTime) * 6.2831853 / 24000.0));
        vec2 wind = vec2(0.14, -0.05) * STORM_CLOUD_WIND * frameTimeCounter;
        vec2 p = cloudWorldPos.xz * 0.019 + wind * 0.03;
        float broad = cloudFbm(p * 1.15);
        float detail = cloudFbm(p * 2.35 + vec2(9.1, 2.3));
        float wisps = cloudFbm(p * 4.4 - vec2(3.6, 12.7) + wind * 0.8);
        float field = broad * 0.58 + detail * 0.30 + wisps * 0.12;
        float cover = smoothstep(mix(0.62, 0.40, STORM_CLOUD_COVER),
                                 mix(0.84, 0.64, STORM_CLOUD_COVER), field);
        float top = clamp(cloudWorldNormal.y * 0.34 + 0.72, 0.55, 1.0);

        vec3 darkCol = mix(vec3(0.055, 0.061, 0.070), vec3(0.22, 0.23, 0.24), daylight);
        vec3 lightCol = mix(vec3(0.13, 0.14, 0.15), vec3(0.44, 0.45, 0.46), daylight);
        vec3 rainCloud = mix(darkCol, lightCol, smoothstep(0.28, 0.80, detail));
        rainCloud *= top * mix(1.02, 0.72, STORM_SKY_DARKNESS);

        float sourceShade = dot(color.rgb, vec3(0.3333));
        vec3 shade = rainCloud * (0.70 + 0.30 * sourceShade);
        shade *= 1.0 - smoothstep(0.52, 0.82, wisps) * 0.06;
        color.rgb = mix(color.rgb, shade, cover * storm * 0.96);
        color.a *= mix(1.0, 0.86 + cover * 0.08, storm);
    }
#endif
}