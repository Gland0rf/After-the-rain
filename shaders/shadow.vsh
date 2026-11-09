#version 330 compatibility
#include "/lib/exposure.glsl"

const int shadowMapResolution = 2048;
const float shadowDistance = 144.0;
const float shadowDistanceRenderMul = 1.0;
const float shadowIntervalSize = 0.0;
const bool shadowtex0Nearest = true;
uniform mat4 shadowModelViewInverse;
in vec2 mc_Entity;
in vec2 mc_midTexCoord;
out vec2 texcoord;
out vec4 glcolor;

void main() {
    vec3 relative = (shadowModelViewInverse * gl_ModelViewMatrix * gl_Vertex).xyz;
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    float top = float(gl_MultiTexCoord0.y < mc_midTexCoord.y);
    relative += atrFoliageOffset(relative + cameraPosition, int(mc_Entity.x + 0.5), top);
    gl_Position = vec4(atrRoofClip(relative), 1.0);
    glcolor = gl_Color;
}
