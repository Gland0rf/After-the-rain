#version 330 compatibility
#include "/lib/weather.glsl"
in vec2 mc_Entity;
out vec3 waterWorldPos;
out vec3 waterWorldNormal;
flat out int waterMaterial;

out vec2 lmcoord;
out vec2 texcoord;
out vec4 glcolor;

void main() {
	gl_Position = ftransform();
    vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;
    waterWorldPos = (gbufferModelViewInverse * viewPos).xyz + cameraPosition;
    waterWorldNormal = normalize(mat3(gbufferModelViewInverse) * gl_NormalMatrix * gl_Normal);
    waterMaterial = int(mc_Entity.x + 0.5);
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	glcolor = gl_Color;
}
