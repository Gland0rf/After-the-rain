#version 330 compatibility

/* RENDERTARGETS: 0 */

// REFLECTION_QUALITY = 0 disables SSR; 3 does 36 steps per reflective pixel.
#define REFLECTION_QUALITY 2 // [0 1 2 3] 0 off, 1 fast, 2 balanced, 3 detailed
#define REFLECTION_INTENSITY 0.85 // [0.40 0.60 0.85 1.00] Strength of reflections
#define RAIN_RIPPLES // Animated ripple rings on puddle surfaces

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
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
uniform vec3 skyColor;
uniform float rainStrength;
uniform float frameTimeCounter;

in vec2 uv;
layout(location = 0) out vec4 outColor;

vec3 toView(vec2 tex, float depth) {
	vec4 h = gbufferProjectionInverse * vec4(tex * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
	return h.xyz / max(abs(h.w), 0.00001) * sign(h.w);
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// A looping ring whose position is anchored to world coordinates.
// It changes only its *age*, never its origin, while moving the camera.
float rainRing(vec2 worldXZ) {
    vec2 tile = worldXZ * 1.55;
    vec2 cell = floor(tile);
    float seed = hash2(cell);
    vec2 offset = vec2(hash2(cell + 17.0), hash2(cell + 41.0)) - 0.5;
    vec2 local = fract(tile) - 0.5 - offset * 0.36;
    float age = fract(frameTimeCounter * (0.55 + 0.1 * seed) + seed);
    float radius = age * 0.64;
    float d = length(local);
    float ring = exp(-pow((d - radius) * 39.0, 2.0));
    return ring * (1.0 - age) * smoothstep(0.0, 0.13, age);
}

// Screen-space ray march: this can only reflect objects visible on screen.
// The fallback uses skyColor if the ray misses/outside camera frame.
vec3 traceReflection(vec3 originVS, vec3 normalVS, out float hitConfidence) {
    hitConfidence = 0.0;
    vec3 directionVS = reflect(normalize(originVS), normalVS);
    vec3 start = originVS + normalVS * 0.055;
    vec3 result = vec3(0.0);

#if REFLECTION_QUALITY > 0
    float rayDistance = 0.13;
    for (int i = 0; i < SSR_STEPS; ++i) {
        rayDistance += 0.16 + rayDistance * 0.17;
        vec3 rayPos = start + directionVS * rayDistance;
        vec4 clip = gbufferProjection * vec4(rayPos, 1.0);
        if (clip.w < 0.0001) break;
        vec2 hitUV = (clip.xy / clip.w) * 0.5 + 0.5;
        if (any(lessThan(hitUV, vec2(0.015))) ||
            any(greaterThan(hitUV, vec2(0.985)))) break;

        float sceneDepth = texture(depthtex1, hitUV).r;
        if (sceneDepth > 0.99998) continue;
        vec3 sceneVS = toView(hitUV, sceneDepth);
        // Positive difference means ray has passed behind visible geometry.
        float delta = sceneVS.z - rayPos.z;
        float thickness = 0.10 + rayDistance * 0.055;
        if (delta > 0.025 && delta < thickness) {
            float edge = min(min(hitUV.x, 1.0 - hitUV.x),
                             min(hitUV.y, 1.0 - hitUV.y));
            float edgeFade = smoothstep(0.015, 0.12, edge);
            float travelFade = 1.0 - smoothstep(11.0, 38.0, rayDistance);
            hitConfidence = edgeFade * travelFade;
            result = texture(colortex0, hitUV).rgb;
            break;
        }
    }
#endif
    return result;
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
    if (abs(-posVS.z - encodedNormal.a * 320.0) >
        0.20 + abs(posVS.z) * 0.018) return;

	vec3 normalWS = normalize(encodedNormal.rgb * 2.0 - 1.0);
	float puddle = clamp(surface.r, 0.0, 1.0);
	float wetGloss = clamp(surface.b, 0.0, 1.0);
	float reflective = max(puddle, wetGloss * 0.22);
	if (reflective < 0.015) return;

	vec3 normalVS = normalize(mat3(gbufferModelView) * normalWS);
	vec3 worldPos = (gbufferModelViewInverse * vec4(posVS, 1.0)).xyz + cameraPosition;

#ifdef RAIN_RIPPLES
	float ring = 0.0;
	if (puddle > 0.04 && rainStrength > 0.01) {
		float baseRing = rainRing(worldPos.xz);
		ring = baseRing * rainStrength * puddle;
		// Ripple normal movement should be subtle
		float rx = rainRing(worldPos.xz + vec2(0.018, 0.0));
		float ry = rainRing(worldPos.xz + vec2(0.0, 0.018));
		normalWS = normalize(normalWS + vec3((rx - baseRing) * 0.18,
											0.0, (ry - baseRing) * 0.18) * puddle * rainStrength);
		normalVS = normalize(mat3(gbufferModelView) * normalWS);
	}
#else
	float ring = 0.0;
#endif

	vec3 viewDir = normalize(-posVS);
	float facing = clamp(dot(normalVS, viewDir), 0.0, 1.0);
    float fresnel = pow(1.0 - facing, 5.0);

    // The rough wet surface gets a little gloss, actual puddles much more.
    float gloss = wetGloss * (0.035 + 0.15 * fresnel);
    float waterReflect = puddle * (0.34 + 0.56 * fresnel);
    float strength = clamp((gloss + waterReflect) * REFLECTION_INTENSITY, 0.0, 0.92);

    vec3 skyFallback = clamp(skyColor * vec3(0.74, 0.81, 0.94) +
                             vec3(0.04, 0.052, 0.075), 0.0, 1.0);
    float confidence = 0.0;
    vec3 visibleReflection = vec3(0.0);
    // Trace expensive SSR rays only on actual puddles (not wet walls).
    if (puddle > 0.065) {
        visibleReflection = traceReflection(posVS, normalVS, confidence);
    }
    vec3 reflected = mix(skyFallback, visibleReflection, confidence);

    outColor.rgb = mix(scene.rgb, reflected, strength);
    // Thin, high-contrast rain rings sit over the reflection.
    outColor.rgb += vec3(0.10, 0.13, 0.16) * ring;
}