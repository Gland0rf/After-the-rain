#version 330 compatibility
#include "/lib/exposure.glsl"

const int shadowMapResolution = 2048;
const float shadowDistance = 144.0;
const float shadowDistanceRenderMul = 1.0;
const float shadowIntervalSize = 0.0;
const bool shadowtex0Nearest = true;
const bool shadowcolor0Nearest = true;
uniform mat4 shadowModelViewInverse;
uniform int renderStage;
in vec2 mc_Entity;
in vec2 mc_midTexCoord;
out vec2 texcoord;
out vec4 glcolor;
out float roofWorldHeight;

void main() {
    vec3 relative = (shadowModelViewInverse * gl_ModelViewMatrix * gl_Vertex).xyz;
#if defined(IS_IRIS) && defined(MC_RENDER_STAGE_TERRAIN_SOLID)
    // Iris/Sodium already supplies camera-relative terrain vertices. Avoid
    // rotating them into sun space and reconstructing them with another matrix.
    // Block entities still need their model transform through the fallback.
    if (renderStage == MC_RENDER_STAGE_TERRAIN_SOLID ||
        renderStage == MC_RENDER_STAGE_TERRAIN_CUTOUT ||
        renderStage == MC_RENDER_STAGE_TERRAIN_CUTOUT_MIPPED ||
        renderStage == MC_RENDER_STAGE_TERRAIN_TRANSLUCENT)
        relative = gl_Vertex.xyz;
#endif
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    float top = float(gl_MultiTexCoord0.y < mc_midTexCoord.y);
    relative += atrFoliageOffset(relative + cameraPosition, int(mc_Entity.x + 0.5), top);
    roofWorldHeight = relative.y + cameraPosition.y;
    gl_Position = vec4(atrRoofClip(relative), 1.0);
    glcolor = gl_Color;
}
