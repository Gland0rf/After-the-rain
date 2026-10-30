#version 330 compatibility
/* RENDERTARGETS: 0 */
uniform sampler2D gtexture;
uniform sampler2D lightmap;
uniform float alphaTestRef;
in vec2 vUV;
in vec2 vLight;
in vec4 vColor;
layout(location = 0) out vec4 outColor;
void main() {
    outColor = texture(gtexture, vUV) * vColor;
    outColor *= texture(lightmap, vLight);
    if (outColor.a < alphaTestRef) discard;
}
