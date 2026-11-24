#ifndef ATR_RAIN_LIGHTING
#define ATR_RAIN_LIGHTING
#include "/lib/weather.glsl"

vec4 atrLightRain(vec4 rainColor, vec3 lightColor, vec2 lightUV) {
#ifdef LAMPLIT_RAIN
    // The weather geometry supplies local block/sky light. Reuse it instead
    // of attaching a screen-centred light to the camera or inventing emitters.
    float blockLight = smoothstep(0.30, 0.88, lightUV.x);
    float amount = blockLight * LAMPLIGHT_INTENSITY * (1.0 - atrDaylight() * 0.60);
    float luminance = max(dot(lightColor, vec3(0.2126, 0.7152, 0.0722)), 0.06);
    vec3 localTint = clamp(lightColor / luminance, vec3(0.70), vec3(1.30));
    vec3 warmTint = vec3(1.18, 1.065, 0.83) * mix(vec3(1.0), localTint, 0.35);
    rainColor.rgb *= mix(vec3(1.0), warmTint, amount);
    rainColor.rgb += vec3(0.080, 0.048, 0.015) * amount;
    rainColor.a = clamp(rainColor.a * (1.0 + amount * 0.30), 0.0, 1.0);
#endif
    return rainColor;
}
#endif
