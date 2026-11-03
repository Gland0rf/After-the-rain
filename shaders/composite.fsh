#version 330 compatibility
/* RENDERTARGETS: 0 */

#define RAIN_FOG // Soft depth fog that builds as a storm arrives
#define FOG_AMOUNT 0.78 // [0.00 0.25 0.50 0.78 1.00] More fog at higher values
#define RAIN_COLOR_GRADE // Gently cooled, less saturated colors during rain
#define RAIN_DETAIL 0 // [0 1 2 3] Extra 3D rain layers; 0 = vanilla particles only
#define RAIN_DENSITY 0.75 // [0.50 0.75 1.00 1.25 1.50] How thick the rain looks
#define RAIN_WIND 0.35 // [0.00 0.20 0.35 0.60 0.85] Rain slant and wind drift
#define RAIN_STREAK_BRIGHTNESS 0.80 // [0.40 0.60 0.80 1.00 1.20] Falling rain visibility

uniform sampler2D colortex0;
uniform sampler2D depthtex0;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
uniform vec3 fogColor;
uniform float rainStrength;
uniform float wetness;
uniform float frameTimeCounter;
uniform int worldTime;
uniform int isEyeInWater;
uniform int biome_precipitation;
uniform ivec2 eyeBrightnessSmooth;

in vec2 uv;
layout(location = 0) out vec4 outColor;

vec3 viewPosition(vec2 tex, float depth) {
	vec4 h = gbufferProjectionInverse * vec4(tex * 2.0 - 1.0,
                                                depth * 2.0 - 1.0, 1.0);
    return h.xyz / max(abs(h.w), 0.00001) * sign(h.w);
}

float hashRain(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Sparse world-space streaks. The same raindrop stays in place when the camera
// rotates, falls with time and tilts in the wind. This is not a flat screen filter.
float rainStreak(vec3 p, float scale, float seed) {
    vec2 breeze = vec2(0.19, -0.09) * RAIN_WIND;
    vec2 columns = (p.xz - breeze * p.y * 0.48 +
                    breeze * frameTimeCounter * 6.0) * scale + seed * vec2(7.13, 13.71);
    vec2 cell = floor(columns);
    vec2 cellRandom = vec2(hashRain(cell + vec2(3.1, 9.7)),
                   	       hashRain(cell + vec2(17.3, 4.5)));
    vec2 local = fract(columns) - (0.15 + cellRandom * 0.70);

    // A slight footprint allowance keeps thin drops from aliasing in the distance.
    float pixelSize = min(0.11, length(fwidth(columns)) * 0.38);
    float width = 0.014 + cellRandom.x * 0.022;
    float core = 1.0 - smoothstep(width + pixelSize,
                                  width * 2.8 + pixelSize, abs(local.x));
    float fringe = 1.0 - smoothstep(width * 2.6 + pixelSize,
                                    width * 5.0 + pixelSize, abs(local.x));
    float alive = step(0.60 - RAIN_DENSITY * 0.20,
                       hashRain(cell + vec2(29.7, 7.3)));
    float speed = 8.0 + cellRandom.x * 4.0;
    float phase = fract(p.y * (0.53 + cellRandom.y * 0.13) +
                     frameTimeCounter * speed + cellRandom.y);
    float head = smoothstep(0.02, 0.11, phase) *
                 (1.0 - smoothstep(0.22, 0.44, phase));
    float tail = smoothstep(0.00, 0.04, phase) *
                 (1.0 - smoothstep(0.44, 0.72, phase));
    return (core * head + fringe * tail * 0.35) * alive;
}

void main() {
	vec4 source = texture(colortex0, uv);
    outColor = source;
    float rain = clamp(rainStrength, 0.0, 1.0);
    float groundWet = clamp(wetness, 0.0, 1.0);
    if (max(rain, groundWet) < 0.003 || isEyeInWater != 0) return;

    float day = smoothstep(-0.22, 0.22,
                sin(float(worldTime) * 6.2831853 / 24000.0));
    float depth = texture(depthtex0, uv).r;
    float sceneDistance = 10000.0;
    vec3 worldAtSurface = cameraPosition;
    if (depth < 0.99998) {
        vec3 surfaceVS = viewPosition(uv, depth);
        sceneDistance = length(surfaceVS);
        worldAtSurface += mat3(gbufferModelViewInverse) * surfaceVS;
    }

#ifdef RAIN_COLOR_GRADE
	float greyscale = dot(outColor.rgb, vec3(0.2126, 0.7152, 0.0722));
    outColor.rgb = mix(outColor.rgb, vec3(greyscale), rain * 0.115);
    outColor.rgb *= mix(vec3(1.0), vec3(0.978, 0.983, 0.987), rain);
    // Darken evenly, retaining Minecraft colors and the glow from local lights.
    outColor.rgb *= 1.0 - rain * 0.032;
#endif

#ifdef RAIN_FOG
	if (depth < 0.99998) {
        float lowLying = 1.0 - smoothstep(-5.0, 18.0,
                                          worldAtSurface.y - cameraPosition.y);
        float density = (0.006 + rain * 0.014) * FOG_AMOUNT *
                        (0.79 + lowLying * 0.38);
        float fog = 1.0 - exp(-max(0.0, sceneDistance - 5.0) * density);
        fog *= clamp(rain + groundWet * 0.11, 0.0, 1.0);
        fog = min(fog, 0.76);
        vec3 stormFog = mix(vec3(0.056, 0.068, 0.084),
                            vec3(0.37, 0.405, 0.418), day);
        vec3 mistColor = mix(fogColor, stormFog, rain * 0.79);
        outColor.rgb = mix(outColor.rgb, mistColor, fog);
    }
#endif

#if RAIN_DETAIL > 0
    // This is gated by the viewer's skylight: avoid drawing false rain in caves.
    // Snowy biomes keep the vanilla snow shader instead of receiving rain streaks.
    float skyAccess = smoothstep(0.30, 0.78,
                                  float(eyeBrightnessSmooth.y) / 240.0);
    float rainVisibility = smoothstep(0.08, 0.85, rain) * skyAccess;
    if (rainVisibility > 0.002 && biome_precipitation == 1) {
        vec3 dirVS = normalize(viewPosition(uv, 0.70));
        vec3 dirWS = normalize(mat3(gbufferModelViewInverse) * dirVS);
        float droplets = 0.0;

        if (sceneDistance > 3.9)
            droplets += rainStreak(cameraPosition + dirWS * 3.8, 2.3, 1.0) * 0.28;
        if (sceneDistance > 8.5)
            droplets += rainStreak(cameraPosition + dirWS * 8.4, 3.0, 2.0) * 0.18;
#if RAIN_DETAIL >= 2
        if (sceneDistance > 16.5)
            droplets += rainStreak(cameraPosition + dirWS * 16.4, 4.0, 3.0) * 0.12;
#endif
#if RAIN_DETAIL >= 3
        if (sceneDistance > 29.5)
            droplets += rainStreak(cameraPosition + dirWS * 29.4, 5.2, 4.0) * 0.08;
#endif
        float opacity = clamp(droplets * rainVisibility *
                             RAIN_STREAK_BRIGHTNESS, 0.0, 0.22);
        vec3 rainTint = mix(vec3(0.30, 0.31, 0.33),
                            vec3(0.54, 0.55, 0.56), day);
        vec3 streakColor = rainTint * (0.92 + droplets * 0.20);
        outColor.rgb = mix(outColor.rgb, streakColor, opacity);
    }
#endif
}