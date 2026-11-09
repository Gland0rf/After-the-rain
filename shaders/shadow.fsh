#version 330 compatibility
/* RENDERTARGETS: 0 */
/*
const int shadowcolor0Format = RG32F;
*/
const vec4 shadowcolor0ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
uniform sampler2D gtexture;
uniform float alphaTestRef;
in vec2 texcoord;
in vec4 glcolor;
in float roofWorldHeight;
layout(location = 0) out vec4 color;

void main() {
    float alpha = texture(gtexture, texcoord).a * glcolor.a;
    if (alpha < max(alphaTestRef, 0.1)) discard;
    // Depth testing still selects the highest surface. Store its height in
    // 32-bit float R; G distinguishes a captured surface from an empty texel.
    color = vec4(roofWorldHeight, 1.0, 0.0, 1.0);
}
