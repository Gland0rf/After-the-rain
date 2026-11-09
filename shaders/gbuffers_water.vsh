#version 330 compatibility
#include "/lib/weather.glsl"
in vec2 mc_Entity;
out vec3 waterWorldPos;
out vec3 waterCameraRelative;
out vec3 waterWorldNormal;
flat out int waterMaterial;

out vec2 lmcoord;
out vec2 texcoord;
out vec4 glcolor;

void main() {
	gl_Position = ftransform();
    vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;
    waterWorldPos = (gbufferModelViewInverse * viewPos).xyz + cameraPosition;
    waterCameraRelative = (gbufferModelViewInverse * viewPos).xyz;
    waterWorldNormal = normalize(mat3(gbufferModelViewInverse) * gl_NormalMatrix * gl_Normal);
#ifdef IS_IRIS
    waterWorldPos = gl_Vertex.xyz + cameraPosition;
    waterCameraRelative = gl_Vertex.xyz;
    waterWorldNormal = normalize(gl_Normal);
#endif
    waterMaterial = int(mc_Entity.x + 0.5);
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	glcolor = gl_Color;
}
