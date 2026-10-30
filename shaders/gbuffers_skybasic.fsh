#version 330 compatibility

uniform int renderStage;
uniform float viewHeight;
uniform float viewWidth;
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjectionInverse;
uniform vec3 fogColor;
uniform vec3 skyColor;

in vec4 glcolor;
/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

void main() {
	// Iris defines MC_RENDER_STAGE_STARS for the star pass.
    if (renderStage == MC_RENDER_STAGE_STARS) {
        color = glcolor;
    } else {
        vec2 screenUV = gl_FragCoord.xy / vec2(viewWidth, viewHeight);
        vec4 ray = gbufferProjectionInverse * vec4(screenUV * 2.0 - 1.0, 1.0, 1.0);
        vec3 direction = normalize(ray.xyz / ray.w);
        float up = dot(direction, normalize(gbufferModelView[1].xyz));
        float horizon = smoothstep(-0.12, 0.67, up);
        color = vec4(mix(fogColor, skyColor, horizon), 1.0);
    }
}
