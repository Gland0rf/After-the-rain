#version 330 compatibility
out vec2 vUV;
out vec2 vLight;
out vec4 vColor;
void main() {
    gl_Position = ftransform();
    vUV = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vLight = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vColor = gl_Color;
}
