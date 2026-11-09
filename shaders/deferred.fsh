#version 330 compatibility

/* RENDERTARGETS: 0 */

#include "/lib/sky.glsl"
#include "/lib/ripples.glsl"

#if REFLECTION_QUALITY == 0
    const int SSR_STEPS = 0;
#elif REFLECTION_QUALITY == 1
    const int SSR_STEPS = 12;
#elif REFLECTION_QUALITY == 2
    const int SSR_STEPS = 24;
#else
    const int SSR_STEPS = 36;
#endif

uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D depthtex1;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;

in vec2 uv;
layout(location = 0) out vec4 outColor;

vec3 toView(vec2 tex, float depth) {
	vec4 h = gbufferProjectionInverse * vec4(tex * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
	return h.xyz / max(abs(h.w), 0.00001) * sign(h.w);
}

// Very short-lived pinpricks where raindrops strike exposed wet stone.
float rainImpact(vec2 worldXZ) {
    vec2 tile = worldXZ * 3.1;
    vec2 cell = floor(tile);
    vec2 offset = vec2(atrHash(cell + 9.7), atrHash(cell + 21.3));
    vec2 pos = fract(tile) - (offset * 0.66 + 0.17);
    float seed = atrHash(cell + 77.3);
    float age = fract(frameTimeCounter * (1.5 + seed * 0.6) + seed);
    float core = exp(-dot(pos, pos) * 330.0);
    float flick = 1.0 - smoothstep(0.0, 0.14, age);
    return core * flick;
}

// Depth-aware roughness blur keeps unrelated foreground silhouettes out.
vec3 reflectionSample(vec2 tex, float roughness, float travel) {
    vec3 centre = texture(colortex0, tex).rgb;
#ifdef MATERIAL_ROUGHNESS
    float radius = roughness * roughness * (2.0 + min(travel, 24.0) * 0.45);
    vec2 px = radius / vec2(textureSize(colortex0, 0));
    float centreDepth = -toView(tex, texture(depthtex1, tex).r).z;
    vec3 sum = centre;
    float weight = 1.0;
    const vec2 offsets[4] = vec2[4](vec2(1.0, 0.0), vec2(-1.0, 0.0),
                                    vec2(0.0, 1.0), vec2(0.0, -1.0));
    for (int i = 0; i < 4; ++i) {
        vec2 sampleUV = clamp(tex + offsets[i] * px, vec2(0.001), vec2(0.999));
        float depth = -toView(sampleUV, texture(depthtex1, sampleUV).r).z;
        float w = 1.0 - smoothstep(0.10, 0.60 + centreDepth * 0.01, abs(depth - centreDepth));
        sum += texture(colortex0, sampleUV).rgb * w;
        weight += w;
    }
    centre = sum / weight;
#endif
    return centre;
}

bool projectRay(vec3 pos, out vec2 tex) {
    vec4 clip = gbufferProjection * vec4(pos, 1.0);
    tex = clip.xy / max(clip.w, 0.0001) * 0.5 + 0.5;
    return clip.w > 0.0001 && all(greaterThan(tex, vec2(0.002))) &&
           all(lessThan(tex, vec2(0.998)));
}

vec3 traceReflection(vec3 originVS, vec3 normalVS, float roughness,
                     out float hitConfidence) {
    hitConfidence = 0.0;
#if REFLECTION_QUALITY > 0
    vec3 directionVS = reflect(normalize(originVS), normalVS);
    vec3 start = originVS + normalVS * 0.065;
    float previousDistance = 0.04;
    float previousDelta = -1.0;
    float rayDistance = 0.13;
    for (int i = 0; i < SSR_STEPS; ++i) {
        // All qualities cover the same ~40-block range. Higher quality spends
        // its extra steps on finer spacing instead of marching beyond the fade.
        float fraction = float(i + 1) / float(SSR_STEPS);
        rayDistance = 0.13 + (exp2(fraction * 5.5) - 1.0) * 0.90;
        vec3 rayPos = start + directionVS * rayDistance;
        vec2 hitUV;
        if (!projectRay(rayPos, hitUV)) break;
        float sceneDepth = texture(depthtex1, hitUV).r;
        float delta = sceneDepth > 0.99998 ? -1000.0 : toView(hitUV, sceneDepth).z - rayPos.z;
        if (delta > 0.0 && previousDelta <= 0.0) {
            float low = previousDistance;
            float high = rayDistance;
            // Refine the front/back crossing rather than accepting a coarse step.
#if REFLECTION_QUALITY == 1
            const int refinements = 3;
#else
            const int refinements = 5;
#endif
            for (int j = 0; j < refinements; ++j) {
                float middle = (low + high) * 0.5;
                vec3 middlePos = start + directionVS * middle;
                vec2 middleUV;
                if (!projectRay(middlePos, middleUV)) break;
                float depth = texture(depthtex1, middleUV).r;
                float middleDelta = depth > 0.99998 ? -1000.0 : toView(middleUV, depth).z - middlePos.z;
                if (middleDelta > 0.0) high = middle;
                else low = middle;
            }
            rayPos = start + directionVS * high;
            if (!projectRay(rayPos, hitUV)) break;
            sceneDepth = texture(depthtex1, hitUV).r;
            delta = toView(hitUV, sceneDepth).z - rayPos.z;
            float thickness = 0.08 + high * 0.015;
            if (sceneDepth < 0.99998 && delta >= 0.0 && delta < thickness) {
                float edge = min(min(hitUV.x, 1.0 - hitUV.x), min(hitUV.y, 1.0 - hitUV.y));
                hitConfidence = smoothstep(0.005, 0.14, edge) *
                    (1.0 - smoothstep(18.0, 40.0, high)) *
                    (1.0 - smoothstep(thickness * 0.25, thickness, delta)) *
                    smoothstep(0.12, 0.40, high);
                return reflectionSample(hitUV, roughness, high);
            }
        }
        previousDistance = rayDistance;
        previousDelta = delta;
    }
#endif
    return vec3(0.0);
}

void main() {
	vec4 scene = texture(colortex0, uv);
	outColor = scene;
	vec4 surface = texture(colortex3, uv);
	if (surface.a < 0.5 || max(surface.r, surface.b) < 0.015) return;

	float sceneDepth = texture(depthtex1, uv).r;
	if (sceneDepth > 0.99999) return;
	vec3 posVS = toView(uv, sceneDepth);
	vec4 encodedNormal = texture(colortex2, uv);
	// Reject terrain metadata when a mob/item was drawn in front of it.
    if (abs(-posVS.z - encodedNormal.a) >
        0.20 + abs(posVS.z) * 0.018) return;

	vec3 normalWS = normalize(encodedNormal.rgb * 2.0 - 1.0);
	float puddle = clamp(surface.r, 0.0, 1.0);
	float wetGloss = clamp(surface.b, 0.0, 1.0);
	float reflective = max(puddle, wetGloss * 0.22);
	if (reflective < 0.015) return;

	vec3 normalVS = normalize(mat3(gbufferModelView) * normalWS);
	vec3 worldPos = (gbufferModelViewInverse * vec4(posVS, 1.0)).xyz + cameraPosition;

    float rain = atrRain();
    float ring = 0.0;
#ifdef RAIN_RIPPLES
    if (puddle > 0.04 && rain > 0.01) {
        vec3 ripple = atrRipple(worldPos.xz);
        ring = ripple.z * rain * puddle;
        normalWS = normalize(normalWS + vec3(ripple.x, 0.0, ripple.y) * 0.035 * puddle * rain);
        normalVS = normalize(mat3(gbufferModelView) * normalWS);
    }
#endif

    vec3 viewDir = normalize(-posVS);
	float facing = clamp(dot(normalVS, viewDir), 0.0, 1.0);
    float fresnel = pow(1.0 - facing, 5.0);

    // The rough wet surface gets a little gloss, actual puddles much more.
    float gloss = wetGloss * (0.012 + 0.07 * fresnel);
    float waterReflect = puddle * (0.025 + 0.78 * fresnel);
    float strength = clamp((gloss + waterReflect) * REFLECTION_INTENSITY, 0.0, 0.92);

    float roughness = clamp(surface.a - 1.0, 0.0, 1.0);
#ifndef MATERIAL_ROUGHNESS
    roughness = 0.0;
#endif
    vec3 reflectionWS = normalize(mat3(gbufferModelViewInverse) *
                                   reflect(normalize(posVS), normalVS));
    // Rough damp surfaces use a diffuse, view-independent sky average. Only
    // smooth pools get directional cloud images that move with the viewpoint.
    float pool = smoothstep(0.18, 0.50, puddle);
    float directional = pool * (1.0 - smoothstep(0.16, 0.55, roughness));
    vec3 skyFallback = atrSkyAmbient();
    if (directional > 0.001)
        skyFallback = mix(skyFallback, atrSky(reflectionWS, worldPos), directional);
    float confidence = 0.0;
    vec3 visibleReflection = vec3(0.0);
    if (puddle > 0.24 && directional > 0.01 && normalWS.y > 0.75) {
        visibleReflection = traceReflection(posVS, normalVS, roughness, confidence);
        confidence *= smoothstep(0.24, 0.46, puddle) * directional;
    }
    vec3 reflected = mix(skyFallback, visibleReflection, confidence);

    outColor.rgb = mix(scene.rgb, reflected, strength);
    // Thin, high-contrast rain rings sit over the reflection.
    outColor.rgb += vec3(0.115, 0.130, 0.140) * ring;

#ifdef RAIN_SPLASHES
    if (rain > 0.04 && surface.g > 0.075 && normalWS.y > 0.78) {
        float sparkle = rainImpact(worldPos.xz) * rain *
                        surface.g * (0.12 + 0.55 * puddle);
        outColor.rgb += vec3(0.25, 0.30, 0.32) * sparkle;
    }
#endif
}
