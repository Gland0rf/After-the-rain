#version 330 compatibility
/* RENDERTARGETS: 0 */
// Procedural storm clouds and their toggle live in lib/sky.glsl.
uniform sampler2D gtexture;
uniform float alphaTestRef;
in vec2 texcoord;
in vec4 glcolor;
in vec3 cloudWorldPos;
in vec3 cloudWorldNormal;
layout(location = 0) out vec4 color;
void main() {
    color = texture(gtexture, texcoord) * glcolor;
    if (color.a < alphaTestRef) discard;
}
