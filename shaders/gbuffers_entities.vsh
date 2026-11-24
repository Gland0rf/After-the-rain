#version 330 compatibility
#include "/lib/weather.glsl"

out vec2 lmcoord;
out vec2 texcoord;
out vec4 glcolor;
out vec3 entityCameraRelative;
out vec3 entityWorldNormal;

void main() {
	gl_Position = ftransform();
    vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;
    entityCameraRelative = (gbufferModelViewInverse * viewPos).xyz;
    entityWorldNormal = mat3(gbufferModelViewInverse) * gl_NormalMatrix * gl_Normal;
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	glcolor = gl_Color;
}
