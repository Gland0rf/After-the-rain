#version 330 compatibility
/* RENDERTARGETS: 0 */
#include "/lib/weather.glsl"

uniform sampler2D colortex0;
uniform sampler2D colortex5;
uniform sampler2D depthtex0;
uniform mat4 gbufferProjectionInverse;
uniform int isEyeInWater;
in vec2 uv;
layout(location = 0) out vec4 outColor;

void main() {
    outColor = texture(colortex0, uv);
#if WEATHER_DEBUG > 0
    return;
#endif
#ifdef SUN_SHAFTS
    if (atrClearing() < 0.002 || isEyeInWater != 0) return;
    float depth = texture(depthtex0, uv).r;
    float sceneDistance = 512.0;
    if (depth < 0.999999) {
        vec4 position = gbufferProjectionInverse * vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
        sceneDistance = min(512.0, length(position.xyz / max(abs(position.w), 0.00001)));
    }
    // Bilateral upsampling rejects the other side of foreground silhouettes.
    ivec2 size = textureSize(colortex5, 0);
    vec2 pixel = uv * vec2(size) - 0.5;
    ivec2 base = ivec2(floor(pixel));
    vec2 fraction = fract(pixel);
    vec3 shafts = vec3(0.0);
    float totalWeight = 0.0;
    for (int y = 0; y < 2; ++y) {
        for (int x = 0; x < 2; ++x) {
            ivec2 samplePixel = clamp(base + ivec2(x, y), ivec2(0), size - 1);
            vec4 sampleShafts = texelFetch(colortex5, samplePixel, 0);
            vec2 weights = mix(vec2(1.0) - fraction, fraction, vec2(x, y));
            float depthWeight = exp(-abs(sampleShafts.a - sceneDistance) / (1.0 + sceneDistance * 0.04));
            float weight = weights.x * weights.y * depthWeight;
            shafts += sampleShafts.rgb * weight;
            totalWeight += weight;
        }
    }
    shafts /= max(totalWeight, 0.0001);
    // Keep the nearby hand and very close geometry free of the distant haze.
    shafts *= smoothstep(2.0, 12.0, sceneDistance);
    outColor.rgb = min(outColor.rgb + shafts, vec3(1.0));
#endif
}
