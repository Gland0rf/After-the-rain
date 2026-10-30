#version 330 compatibility

/* DRAWBUFFERS:023 */

// Iris user-editable settings; in-game: Shader Pack Settings > Ground.
#define WET_DARKNESS 0.64 // [0.48 0.56 0.64 0.72 0.80] Darker at lower values
#define PUDDLE_AMOUNT 0.85 // [0.00 0.25 0.50 0.70 0.85 1.00] How much puddling
#define PUDDLE_SIZE 0.54 // [0.40 0.48 0.54 0.60 0.66] Larger at higher values
#define GRASS_PUDDLES 0.80;

// Iris uses these half-lives (in ticks) to create an after-rain drying period.
const float wetnessHalflife = 90.0;
const float drynessHalflife = 1400.0;

// Additional render targets store terrain normals/depth and wetness/puddles.

/*
const int colortex2Format = RGBA16F;
const int colortex3Format = RGBA16F;
*/
const bool colortex2Clear = true;
const bool colortex3Clear = true;
const vec4 colortex2ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
const vec4 colortex3ClearColor = vec4(0.0, 0.0, 0.0, 0.0);

uniform sampler2D gtexture;
uniform sampler2D lightmap;
uniform float alphaTestRef;
uniform float wetness;

in vec2 vUV;
in vec2 vLightUV;
in vec4 vTint;
in vec3 vWorldNormal;
in vec3 vWorldPos;
in vec3 vViewPos;
flat in int vMaterial;

layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outNormalAndDepth;
layout(location = 2) out vec4 outWetData;

float random2(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

// Smooth value noise in absolute world coordinates, so puddles do not
// follow the camera or change position when looking around.
float valueNoise2D(vec2 p) {
    vec2 c = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(random2(c), random2(c + vec2(1.0, 0.0)), f.x),
        mix(random2(c + vec2(0.0, 1.0)), random2(c + 1.0), f.x),
        f.y
    );
}

float terrainPuddleNoise(vec2 p) {
    float broad = valueNoise2D(p * 0.34);
    float details = valueNoise2D(p * 1.10);
    float tiny = valueNoise2D(p * 2.9);
    return broad * 0.68 + details * 0.25 + tiny * 0.07;
}

void main() {
    outColor = texture(gtexture, vUV) * vTint;
    outColor *= texture(lightmap, vLightUV);
    if (outColor.a < alphaTestRef) discard;

    // 100 = stones, 101 = paths, 102 = wooden boards,
    // 103 = soil, 104 = vegetation, 105 = tiles/metals.
    float darkness = 0.0;
    float puddleSuitability = 0.0;
    float glossSuitability = 0.0;
    if (vMaterial == 100) {
        darkness = 1.00; puddleSuitability = 1.00; glossSuitability = 0.80;
    } else if (vMaterial == 101) {
        darkness = 0.90; puddleSuitability = 0.80; glossSuitability = 0.60;
    } else if (vMaterial == 102) {
        darkness = 0.85; puddleSuitability = 0.25; glossSuitability = 0.65;
    } else if (vMaterial == 103) {
        darkness = 0.95; puddleSuitability = 0.56; glossSuitability = 0.24;
    } else if (vMaterial == 104) {
        // Individual leaves/grass blades get darker but never become puddle planes.
        darkness = 0.62; puddleSuitability = 0.0; glossSuitability = 0.04;
    } else if (vMaterial == 105) {
        darkness = 0.78; puddleSuitability = 0.64; glossSuitability = 0.97;
    } else if (vMaterial == 106) {
        // A grass block is ground, not a floating blade of grass.
        darkness = 0.88; puddleSuitability = GRASS_PUDDLES; glossSuitability = 0.18;
    }

    vec3 normal = normalize(vWorldNormal);
    // Sky light is an *approximation* of rain exposure, not a roof raycast.
    float skyExposure = smoothstep(0.68, 0.96, vLightUV.y);
    float up = smoothstep(0.77, 0.97, normal.y);
    float wetSurface = wetness * skyExposure * darkness * mix(0.23, 1.0, up);

    // Dry = exact starter-pack color; wet = dark damp material.
    float darker = mix(1.0, WET_DARKNESS, wetSurface);
    outColor.rgb *= darker;

    // Noise pockets appear gradually as the world becomes wet.
    float field = terrainPuddleNoise(vWorldPos.xz);
    if (vMaterial == 106) field += 0.022; // Visible small patches on grass tops
    float threshold = 0.75 - PUDDLE_SIZE * 0.38;
    threshold += (1.0 - wetness) * 0.18;
    float puddleShape = smoothstep(threshold - 0.075, threshold + 0.075, field);
    float puddle = puddleShape * puddleSuitability * PUDDLE_AMOUNT;
    puddle *= up * skyExposure * smoothstep(0.12, 0.85, wetness);

    outColor.rgb *= 1.0 - puddle * (vMaterial == 106 ? 0.12 : 0.18);

    // colortex2 = normal RGB, compressed view distance A (for an
    // occlusion sanity check when an entity covers a terrain pixel).
    outNormalAndDepth = vec4(normal * 0.5 + 0.5,
                             clamp(-vViewPos.z / 320.0, 0.0, 1.0));
    // colortex3 = puddle, surface wetness, gloss, validity flag.
    outWetData = vec4(puddle, wetSurface,
                      glossSuitability * wetness * skyExposure, 1.0);
}
