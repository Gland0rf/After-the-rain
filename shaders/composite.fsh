#version 330 compatibility
/* RENDERTARGETS: 0 */

#define RAIN_FOG // Mist in rain, fading as the scene dries
#define FOG_AMOUNT 0.78 // [0.00 0.25 0.50 0.78 1.00] More fog at higher values
#define RAIN_COLOR_GRADE // Light cool tint and desaturation only in rain

uniform sampler2D colortex0;
uniform sampler2D depthtex0;
uniform mat4 gbufferProjectionInverse;
uniform vec3 fogColor;
uniform float rainStrength;
uniform float wetness;
uniform float worldTime;
uniform int isEyeInWater;

in vec2 uv;
layout(location = 0) out vec4 outColor;

vec3 viewPosition(vec2 tex, float depth) {
	vec4 h = gbufferProjectionInverse * vec4(tex * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
	return h.xyz / h.w;
}

void main() {
	vec4 source = texture(colortex0, uv);
	outColor = source;
	float rain = clamp(rainStrength, 0.0, 1.0);
	if (max(rain, wetness) < 0.002 || isEyeInWater != 0) return;

#ifdef RAIN_COLOR_GRADE
	float luminosity = dot(outColor.rgb, vec3(0.2126, 0.7152, 0.0722));
	outColor.rgb = mix(outColor.rgb, vec3(luminosity), rain * 0.12);
	outColor.rgb *= mix(vec3(1.0), vec3(0.98, 0.99, 1.01), rain * 0.55);
#endif

#ifdef RAIN_FOG
	float depth = texture(depthtex0, uv).r;
	if (depth < 0.99998) {
		float distanceToPixel = length(viewPosition(uv, depth));
		float intensity = clamp(rain * 0.95 + wetness * 0.14, 0.0, 1.0);
		// Exponential mist, mainly in the middle and far distance.
		float density = (0.009 + rain * 0.012) * FOG_AMOUNT;
		float fog = 1.0 - exp(-max(0.0, distanceToPixel - 8.0) * density);
		fog *= intensity;
		fog = clamp(fog, 0.0, 0.74);
		float daylight = smoothstep(-0.18, 0.14, sin(float(worldTime) * 6.28318530718));
		vec3 greyMist = mix(vec3(0.060, 0.073, 0.091),
							vec3(0.38, 0.42, 0.45), daylight);
		vec3 mistColor = mix(fogColor, greyMist, rain * 0.75);
		outColor.rgb = mix(outColor.rgb, mistColor, fog);
	}
#endif
}