#version 330 compatibility
#include "/lib/weather.glsl"

// Geometry phase: send block type, normal, position and vanilla lighting
// to the terrain fragment shader. No Java/Fabric source code is required.

in vec2 mc_Entity;
in vec2 mc_midTexCoord;

out vec2 vUV;
out vec2 vLightUV;
out vec2 vBlockUV;
out vec4 vTint;
out vec3 vWorldNormal;
out vec3 vWorldPos;
out vec3 vCameraRelative;
out vec3 vViewPos;
flat out int vMaterial;

void main() {
    vec4 viewPosition = gl_ModelViewMatrix * gl_Vertex;
    vec3 world = (gbufferModelViewInverse * viewPosition).xyz + cameraPosition;
#ifdef IS_IRIS
    // Terrain vertices are camera-relative in Iris's Sodium renderer. Keep
    // wetness coordinates independent of camera rotation and inverse matrices.
    world = gl_Vertex.xyz + cameraPosition;
#endif
    vec3 offset = atrFoliageOffset(world, int(mc_Entity.x + 0.5),
                                  float(gl_MultiTexCoord0.y < mc_midTexCoord.y));
    viewPosition.xyz += transpose(mat3(gbufferModelViewInverse)) * offset;
    gl_Position = gl_ProjectionMatrix * viewPosition;

    vUV = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vec2 atlasDelta = gl_MultiTexCoord0.xy - mc_midTexCoord;
    vBlockUV = atlasDelta / max(abs(atlasDelta) * 2.0, vec2(0.000001)) + 0.5;
    vLightUV = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vTint = gl_Color;

    vViewPos = viewPosition.xyz;
    vWorldPos = world + offset;
    vCameraRelative = (gbufferModelViewInverse * viewPosition).xyz;
#ifdef IS_IRIS
    vCameraRelative = gl_Vertex.xyz + offset;
#endif
    vec3 viewNormal = normalize(gl_NormalMatrix * gl_Normal);
    vWorldNormal = normalize(mat3(gbufferModelViewInverse) * viewNormal);
#ifdef IS_IRIS
    vWorldNormal = normalize(gl_Normal);
#endif
    vMaterial = int(mc_Entity.x + 0.5);
}
