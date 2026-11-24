#ifndef ATR_SHORE
#define ATR_SHORE
#include "/lib/weather.glsl"

vec4 atrShoreWater(vec4 color, float thickness, vec2 worldXZ, float exposure, vec3 lighting) {
#ifdef SHORE_DETAIL
    float amount = atrWetness() * exposure;
    if (amount < 0.003 || thickness < 0.0) return color;
    float shallow = 1.0 - smoothstep(0.20, 2.5, thickness);
    vec3 tint = mix(vec3(0.89, 0.95, 1.025), vec3(1.025, 1.035, 1.015), shallow);
    color.rgb *= mix(vec3(1.0), tint, amount * 0.55);
    vec2 travel = atrWindTravel() * 0.15;
    float breakup = atrNoise(worldXZ * 3.2 + travel);
    float pulse = 0.75 + 0.25 * sin(frameTimeCounter * 1.1 + dot(worldXZ, vec2(1.3, 0.7)));
    float aa = max(fwidth(thickness), 0.015);
    float foam = (1.0 - smoothstep(0.08, 0.55 + aa, thickness)) *
                  smoothstep(0.42, 0.72, breakup) * pulse * amount * 0.28;
    color.rgb = mix(color.rgb, vec3(0.68, 0.73, 0.74) * clamp(lighting, 0.0, 1.0), foam);
    color.a = clamp(color.a + foam * 0.16, 0.0, 1.0);
#endif
    return color;
}
#endif
