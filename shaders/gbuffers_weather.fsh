#version 330 compatibility
/* RENDERTARGETS: 0 */

#define SILVER_RAIN // True neutral-grey rain, not a tint over vanilla blue
#define RAIN_STREAK_BRIGHTNESS 0.80 // [0.40 0.60 0.80 1.00 1.20] Falling rain visibility
#define RAIN_SHADER_DEBUG 0 // [0 1] Diagnose which render program draws falling rain

uniform sampler2D lightmap;
uniform sampler2D gtexture;
uniform float alphaTestRef = 0.1;
uniform float rainStrength;
uniform int worldTime;
uniform int biome_precipitation;

in vec2 lmcoord;
in vec2 texcoord;
in vec4 glcolor;
in vec3 precipitationWorldPos;
in float precipitationDistance;
layout(location = 0) out vec4 color;

void main() {
    vec4 texel = texture(gtexture, texcoord);
    vec4 lighting = texture(lightmap, lmcoord);
    color = texel * glcolor * lighting;
    if (color.a < alphaTestRef) discard;

    // Precipitation 2 = snow. Leave snow's texture, color and alpha untouched.
    if (biome_precipitation == 2 || rainStrength < 0.015) return;

#if RAIN_SHADER_DEBUG == 1
    color.rgb = vec3(1.0, 0.02, 0.90);  // Magenta: gbuffers_weather.
    color.a = max(color.a, 0.70);
#elif defined(SILVER_RAIN)
    float daylight = smoothstep(-0.22, 0.23,
                     sin(float(worldTime) * 6.28318530718 / 24000.0));
    float light = clamp(dot(lighting.rgb, vec3(0.30, 0.59, 0.11)), 0.0, 1.0);
    float textureGrey = dot(texel.rgb, vec3(0.30, 0.59, 0.11));
    // Neutral grey water, neither bright white nor translucent blue.
    float silver = mix(0.24, 0.39, daylight);
    silver *= mix(0.82, 1.0, light);
    silver *= mix(0.87, 1.07, textureGrey);
    color.rgb = vec3(silver);

    // Narrow the visible part of each vanilla rain quad. The original texture
    // determines the drops; the horizontal soft mask keeps wide sheets subtle.
    float across = abs(fract(texcoord.x) - 0.5);
    float narrowCore = 1.0 - smoothstep(0.10, 0.37, across);
    float streakProfile = mix(0.14, 1.0, narrowCore);
    float sourceOpacity = clamp(color.a, 0.0, 1.0);
    float distant = 1.0 - 0.32 * smoothstep(10.0, 34.0, precipitationDistance);
   float shower = mix(0.58, 1.0, smoothstep(0.07, 0.94, rainStrength));
    // Lower overall opacity, not brightness alone. This prevents white walls.
    color.a = min(pow(sourceOpacity, 1.4) * streakProfile * distant *
                  shower * 0.31 * RAIN_STREAK_BRIGHTNESS, 0.17);
#endif
}
