#version 330 compatibility
/* RENDERTARGETS: 0 */
#include "/lib/precipitation.glsl"
uniform sampler2D lightmap;
uniform sampler2D gtexture;
uniform float alphaTestRef;
in vec2 lmcoord;
in vec2 texcoord;
in vec4 glcolor;
in float precipitationDistance;
layout(location = 0) out vec4 color;
void main() {
    vec4 texel = texture(gtexture, texcoord);
    vec4 lighting = texture(lightmap, lmcoord);
    color = texel * glcolor * lighting;
    if (color.a < alphaTestRef) discard;
        color = atrPrecipitation(texel, glcolor, lighting, texcoord, precipitationDistance, vec3(1.0, 0.02, 0.90));
}
