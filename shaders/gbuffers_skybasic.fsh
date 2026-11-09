#version 330 compatibility
/* RENDERTARGETS: 0 */
#include "/lib/sky.glsl"
uniform int renderStage;
uniform float viewHeight;
uniform float viewWidth;
uniform mat4 gbufferProjectionInverse;
in vec4 glcolor;
layout(location = 0) out vec4 color;

void main() {
    color = glcolor;
    if (renderStage != MC_RENDER_STAGE_SKY) return;
    if (max(max(atrRain(), atrWetness()), atrLightning()) < 0.001) return;
    vec2 screenUV = gl_FragCoord.xy / vec2(viewWidth, viewHeight);
    vec4 ray = gbufferProjectionInverse * vec4(screenUV * 2.0 - 1.0, 1.0, 1.0);
    vec3 dirWS = normalize(mat3(gbufferModelViewInverse) * ray.xyz);
    color = vec4(atrSky(dirWS, cameraPosition), glcolor.a);
}
