#version 330 compatibility

/* RENDERTARGETS: 0 */

#define RAIN_CLOUD_TINT;

uniform sampler2D gtexture;
uniform float alphaTestRef = 0.1;
uniform float rainStrength;

in vec2 texcoord;
in vec4 glcolor;
layout(location = 0) out vec4 color;

void main() {
	color = texture(gtexture, texcoord) * glcolor;
	if (color.a < alphaTestRef) discard;
#ifdef RAIN_CLOUD_TINT
	float rain = smoothstep(0.02, 0.85, rainStrength);
	float luminance = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 overcast = vec3(luminance) * vec3(0.61, 0.65, 0.70);
	color.rgb = mix(color.rgb, overcast, rain * 0.83);
#endif
}