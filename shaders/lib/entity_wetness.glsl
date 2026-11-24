#ifndef ATR_ENTITY_WETNESS
#define ATR_ENTITY_WETNESS
#include "/lib/exposure.glsl"
#include "/lib/sky.glsl"

vec3 atrWetEntity(vec3 color, vec3 relativePos, vec3 worldNormal,
                  vec2 textureUV, vec2 lightUV) {
#ifdef WET_ENTITIES
    float wet = atrWetness();
    float normalLength = length(worldNormal);
    if (wet < 0.003 || normalLength < 0.001) return color;
    vec3 normal = worldNormal / normalLength;
    float exposure = atrExposureRelative(relativePos + normal * 0.05, lightUV.y);
    float top = smoothstep(0.05, 0.80, normal.y);
    float grain = 0.85 + atrNoise(textureUV * 24.0) * 0.15;
    float moisture = pow(wet, 0.90 * atrBiomeDryPower()) * exposure *
                     mix(0.35, 1.0, top) * grain;
    vec3 viewDirection = -relativePos / max(length(relativePos), 0.0001);
    float facing = clamp(dot(normal, viewDirection), 0.0, 1.0);
    float sheen = moisture * (0.012 + pow(1.0 - facing, 5.0) * 0.075);
    color *= 1.0 - moisture * 0.09;
    color = mix(color, atrSkyAmbient(), sheen);
    color += vec3(0.025, 0.030, 0.040) * atrLightning() * moisture;
#endif
    return color;
}
#endif
