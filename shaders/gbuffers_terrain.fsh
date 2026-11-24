#version 330 compatibility
#include "/lib/exposure.glsl"
#include "/lib/materials.glsl"
#include "/lib/pooling.glsl"
#include "/lib/surface_details.glsl"
#include "/lib/debug.glsl"

/* DRAWBUFFERS:023 */

// Iris uses these half-lives (in ticks) to create an after-rain drying period.
const float wetnessHalflife = WETTING_TIME;
const float drynessHalflife = DRYING_TIME;

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

in vec2 vUV;
in vec2 vLightUV;
in vec2 vBlockUV;
in vec4 vTint;
in vec3 vWorldNormal;
in vec3 vWorldPos;
in vec3 vCameraRelative;
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
    vec3 normal = normalize(vWorldNormal);
    outNormalAndDepth = vec4(normal * 0.5 + 0.5, -vViewPos.z);
    outWetData = vec4(0.0);
#if WEATHER_DEBUG == 1
    float debugExposure = atrExposureRelative(vCameraRelative + normal * 0.06, vLightUV.y);
    outColor.rgb = mix(vec3(0.75, 0.08, 0.06), vec3(0.05, 0.75, 0.20), debugExposure);
    return;
#elif WEATHER_DEBUG == 3
    float debugExposure = atrExposureRelative(vCameraRelative + normal * 0.06, vLightUV.y);
    outColor.rgb = atrPoolingDebug(atrGroundRetention(vCameraRelative, normal, debugExposure));
    return;
#elif WEATHER_DEBUG == 4
    outColor.rgb = atrMaterialDebug(vMaterial);
    return;
#elif WEATHER_DEBUG == 2 || WEATHER_DEBUG == 5
    outColor.rgb = vec3(0.0);
#endif
    float wet = atrWetness();
    if (wet < 0.0005) return;

    // 100 = stones, 101 = paths, 102 = wooden boards,
    // 103 = soil, 104 = vegetation, 105 = tiles/metals, 106 = grass blocks.
    float darkness = 0.0;
    float puddleSuitability = 0.0;
    float glossSuitability = 0.0;
    if (vMaterial == 100) {
        darkness = 1.00; puddleSuitability = 1.00; glossSuitability = 0.80;
    } else if (vMaterial == 101) {
        darkness = 0.90; puddleSuitability = 0.80; glossSuitability = 0.60;
    } else if (vMaterial == 102) {
        darkness = 0.85; puddleSuitability = 0.16; glossSuitability = 0.42;
    } else if (vMaterial == 103) {
        darkness = 0.95; puddleSuitability = 0.56; glossSuitability = 0.24;
    } else if (vMaterial == 104 || vMaterial == 107 || vMaterial == 108 ||
               vMaterial == 110 || vMaterial == 111) {
        // Individual leaves/grass blades get darker but never become puddle planes.
        darkness = 0.62; puddleSuitability = 0.0; glossSuitability = 0.04;
    } else if (vMaterial == 105) {
        darkness = 0.78; puddleSuitability = 0.64; glossSuitability = 0.97;
    } else if (vMaterial == 106) {
        // A grass block is ground, not a floating blade of grass.
        darkness = 0.88; puddleSuitability = GRASS_PUDDLES; glossSuitability = 0.18;
    }

    if (darkness == 0.0) return;
    float skyExposure = atrExposureRelative(vCameraRelative + normal * 0.06, vLightUV.y);
    // Material response and spatial variation leave damp islands as puddles dry.
    float dryingPower = vMaterial == 102 ? 0.68 : (vMaterial == 103 ? 0.78 : 1.15);
    if (vMaterial == 105) dryingPower = 1.40;
    dryingPower *= atrBiomeDryPower();
    float moisture = pow(wet, dryingPower);
    vec2 materialPattern = atrMaterialPattern(vBlockUV, vMaterial, vWorldPos);
    moisture *= materialPattern.x;
    puddleSuitability *= materialPattern.y;
    float dryPatch = valueNoise2D(vWorldPos.xz * 0.71 + vec2(14.3, 8.1));
    moisture *= mix(0.72 + dryPatch * 0.28, 1.0, wet);
    float up = smoothstep(0.77, 0.97, normal.y);
    float wetSurface = moisture * skyExposure * darkness * mix(0.23, 1.0, up);
    float runoff = 0.0;
    if (vMaterial == 100 || vMaterial == 101 || vMaterial == 105)
        runoff = atrRunoff(vWorldPos, normal) * atrRain() * skyExposure;

    // Dry = exact starter-pack color; wet = dark damp material.
    float darker = mix(1.0, WET_DARKNESS, wetSurface);
    outColor.rgb *= darker;
    outColor.rgb *= 1.0 - runoff * 0.12;

    // Noise pockets appear gradually as the world becomes wet.
    float field = terrainPuddleNoise(vWorldPos.xz * (0.54 / PUDDLE_SIZE));
    if (vMaterial == 106) field += 0.022; // Visible small patches on grass tops
    float threshold = 0.545 + (1.0 - wet) * (0.18 + dryPatch * 0.14);
    float retention = 1.0;
    if (puddleSuitability > 0.01)
        retention = atrGroundRetention(vCameraRelative, normal, skyExposure);
    threshold -= (retention - 1.0) * 0.14;
    vec2 edge = atrDryingEdge(field, threshold, wet, dryingPower);
    float puddleShape = edge.x;
    float puddle = puddleShape * puddleSuitability * PUDDLE_AMOUNT;
    puddle *= up * skyExposure * smoothstep(0.12, 0.85, pow(wet, dryingPower));
    puddle = clamp(puddle * retention, 0.0, 1.0);
    float dampBorder = edge.y * up * skyExposure * puddleSuitability * PUDDLE_AMOUNT;
    outColor.rgb *= 1.0 - dampBorder * 0.075;

    outColor.rgb *= 1.0 - puddle * (vMaterial == 106 ? 0.12 : 0.18);
    outColor.rgb *= mix(vec3(1.0), vec3(0.973, 0.987, 1.0),
                        clamp(wetSurface * 0.60, 0.0, 1.0));

    // colortex2 = normal RGB, view depth in blocks A (RGBA16F).
    outNormalAndDepth = vec4(normal * 0.5 + 0.5,
                             -vViewPos.z);
    float roughness = 0.65;
    if (vMaterial == 101) roughness = 0.78;
    if (vMaterial == 102) roughness = 0.55;
    if (vMaterial == 103 || vMaterial == 106) roughness = 0.88;
    if (vMaterial == 104 || vMaterial == 107 || vMaterial == 108 ||
        vMaterial == 110 || vMaterial == 111) roughness = 0.95;
    if (vMaterial == 105) roughness = 0.16;
    roughness = mix(roughness, 0.045, puddle);
    // colortex3 = puddle, wetness, gloss, roughness+1 (zero = invalid).
    outWetData = vec4(puddle, wetSurface,
                      glossSuitability * moisture * skyExposure *
                      (0.88 + 0.12 * valueNoise2D(vWorldPos.xz * 5.0)), 1.0 + roughness);
    outColor.rgb += vec3(0.075, 0.085, 0.11) * atrLightning() * skyExposure *
                    mix(0.35, 1.0, up);
    outColor.rgb = atrFoliageBeads(outColor.rgb, vBlockUV, normal, vCameraRelative,
                                  skyExposure, vLightUV, vMaterial);
#ifdef RAIN_SPLASHES
    float splashDistance = 1.0 - smoothstep(16.0, 28.0, length(vCameraRelative));
    if (atrRain() > 0.02 && up > 0.01 && skyExposure > 0.01 && splashDistance > 0.001) {
        float splash = atrGroundSplash(vWorldPos.xz) * atrRain() * wetSurface * up *
                       splashDistance * mix(0.35, 1.0, puddle);
        float light = clamp(max(vLightUV.x, vLightUV.y * atrDaylight()), 0.08, 1.0);
        outColor.rgb += vec3(0.13, 0.15, 0.17) * splash * light;
    }
#endif
#if WEATHER_DEBUG == 2
    outColor.rgb = vec3(puddle, wetSurface, skyExposure);
#endif
}
