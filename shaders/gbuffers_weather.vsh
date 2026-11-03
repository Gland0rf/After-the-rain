#version 330 compatibility

uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;

out vec2 lmcoord;
out vec2 texcoord;
out vec4 glcolor;
out vec3 precipitationWorldPos;
out float precipitationDistance;

void main() {
	vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;
    gl_Position = gl_ProjectionMatrix * viewPos;
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    glcolor = gl_Color;
    precipitationWorldPos = (gbufferModelViewInverse * viewPos).xyz + cameraPosition;
    precipitationDistance = length(viewPos.xyz);
}