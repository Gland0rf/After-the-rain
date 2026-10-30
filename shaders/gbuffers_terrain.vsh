#version 330 compatibility

// Geometry phase: send block type, normal, position and vanilla lighting
// to the terrain fragment shader. No Java/Fabric source code is required.
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;

in vec2 mc_Entity;

out vec2 vUV;
out vec2 vLightUV;
out vec4 vTint;
out vec3 vWorldNormal;
out vec3 vWorldPos;
out vec3 vViewPos;
flat out int vMaterial;

void main() {
    vec4 viewPosition = gl_ModelViewMatrix * gl_Vertex;
    gl_Position = gl_ProjectionMatrix * viewPosition;

    vUV = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vLightUV = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vTint = gl_Color;

    vViewPos = viewPosition.xyz;
    vWorldPos = (gbufferModelViewInverse * viewPosition).xyz + cameraPosition;
    vec3 viewNormal = normalize(gl_NormalMatrix * gl_Normal);
    vWorldNormal = normalize(mat3(gbufferModelViewInverse) * viewNormal);
    vMaterial = int(mc_Entity.x + 0.5);
}
