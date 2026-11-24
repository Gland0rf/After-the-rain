#version 330 compatibility
#include "/lib/entity_wetness.glsl"

uniform sampler2D lightmap;
uniform sampler2D gtexture;
uniform vec4 entityColor;

uniform float alphaTestRef = 0.1;

in vec2 lmcoord;
in vec2 texcoord;
in vec4 glcolor;
in vec3 entityCameraRelative;
in vec3 entityWorldNormal;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

void main() {
	color = texture(gtexture, texcoord) * glcolor;
    vec4 lighting = texture(lightmap, lmcoord);
    color *= lighting;
	if (color.a < alphaTestRef) {
		discard;
	}
    color.rgb = atrWetEntity(color.rgb, entityCameraRelative, entityWorldNormal, texcoord, lmcoord);
    // Keep the existing hurt/interaction tint after the weather response.
    color.rgb = mix(color.rgb, entityColor.rgb * lighting.rgb, entityColor.a);
}
