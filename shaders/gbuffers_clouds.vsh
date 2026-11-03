#version 330 compatibility

uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;

out vec2 texcoord;
out vec4 glcolor;
out vec3 cloudWorldPos;
out vec3 cloudWorldNormal;

void main() {
	vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;
    gl_Position = gl_ProjectionMatrix * viewPos;
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    glcolor = gl_Color;
    cloudWorldPos = (gbufferModelViewInverse * viewPos).xyz + cameraPosition;
    cloudWorldNormal = normalize(mat3(gbufferModelViewInverse) *
                                 normalize(gl_NormalMatrix * gl_Normal));
}