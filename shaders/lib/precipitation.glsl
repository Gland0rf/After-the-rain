#ifndef ATR_PRECIPITATION
#define ATR_PRECIPITATION
#include "/lib/weather.glsl"
uniform int biome_precipitation;

vec4 atrPrecipitation(vec4 texel, vec4 tint, vec4 lighting, vec2 tex,
                     float distanceToCamera, vec3 debugColor) {
    vec4 result = texel * tint * lighting;
    if (biome_precipitation == 2 || atrRain() < 0.015) return result;
#if RAIN_SHADER_DEBUG == 1
    result.rgb = debugColor;
    result.a = max(result.a, 0.70);
#elif defined(SILVER_RAIN)
    float light = clamp(dot(lighting.rgb, vec3(0.30, 0.59, 0.11)), 0.0, 1.0);
    float textureGrey = dot(texel.rgb, vec3(0.30, 0.59, 0.11));
    float silver = mix(0.24, 0.39, atrDaylight()) * mix(0.82, 1.0, light);
    result.rgb = vec3(silver * mix(0.87, 1.07, textureGrey));
    float across = abs(fract(tex.x) - 0.5);
    float streakProfile = mix(0.14, 1.0, 1.0 - smoothstep(0.10, 0.37, across));
    float distant = 1.0 - 0.32 * smoothstep(10.0, 34.0, distanceToCamera);
    float shower = mix(0.58, 1.0, smoothstep(0.07, 0.94, atrRain()));
    result.a = min(pow(clamp(result.a, 0.0, 1.0), 1.4) * streakProfile * distant *
                   shower * 0.31 * RAIN_STREAK_BRIGHTNESS, 0.17);
#endif
    return result;
}
#endif
