#version 330 compatibility
#include "/lib/weather.glsl"

uniform int biome_precipitation;

out vec2 lmcoord;
out vec2 texcoord;
out vec4 glcolor;
out vec3 precipitationWorldPos;
out float precipitationDistance;

void main() {
	vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;
    vec3 relative = (gbufferModelViewInverse * viewPos).xyz;
    vec2 slant = -atrWind() * relative.y * 0.45 * atrRain() * float(biome_precipitation == 1);
    viewPos.xyz += transpose(mat3(gbufferModelViewInverse)) * vec3(slant.x, 0.0, slant.y);
    gl_Position = gl_ProjectionMatrix * viewPos;
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    glcolor = gl_Color;
    precipitationWorldPos = (gbufferModelViewInverse * viewPos).xyz + cameraPosition;
    precipitationDistance = length(viewPos.xyz);
}
