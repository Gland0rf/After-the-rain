#version 330 compatibility
#include "/lib/exposure.glsl"
#include "/lib/sky.glsl"
#include "/lib/ripples.glsl"
#include "/lib/materials.glsl"

uniform sampler2D lightmap;
uniform sampler2D gtexture;

uniform float alphaTestRef = 0.1;

in vec2 lmcoord;
in vec2 texcoord;
in vec4 glcolor;
in vec3 waterWorldPos;
in vec3 waterCameraRelative;
in vec3 waterWorldNormal;
flat in int waterMaterial;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

void main() {
	color = texture(gtexture, texcoord) * glcolor;
	color *= texture(lightmap, lmcoord);
    float glassRunoff = 0.0;
    if (waterMaterial == 112 && atrRain() > 0.002) {
        float exposed = atrExposureRelative(waterCameraRelative + waterWorldNormal * 0.06, lmcoord.y);
        glassRunoff = atrRunoff(waterWorldPos, waterWorldNormal) * exposed * atrRain();
        color.rgb = mix(color.rgb, color.rgb * 0.82 + vec3(0.12, 0.14, 0.17), glassRunoff * 0.55);
        color.a = clamp(color.a + glassRunoff * 0.06, 0.0, 1.0);
    }
    // Clear glass has zero-alpha texels. Allow a faint water film there while
    // retaining the usual alpha test everywhere outside an active trail.
    if (color.a < alphaTestRef && glassRunoff < 0.01) discard;
    if (waterMaterial == 109 || waterMaterial == 112)
        color.rgb += vec3(0.075, 0.085, 0.11) * atrLightning() *
                     atrExposureRelative(waterCameraRelative, lmcoord.y);
#ifdef WATER_RIPPLES
    // Only mapped water top faces: glass, ice and lava keep vanilla shading.
    float rain = atrRain();
    if (waterMaterial == 109 && waterWorldNormal.y > 0.8 && rain > 0.002) {
        float exposed = atrExposureRelative(waterCameraRelative, lmcoord.y);
        float amount = rain * exposed;
        if (amount > 0.002) {
            vec3 ripple = atrRipple(waterWorldPos.xz);
            vec2 breeze = atrWind();
            float wave = cos(dot(waterWorldPos.xz, vec2(1.7, 0.9)) - frameTimeCounter * 2.3);
            vec3 n = normalize(waterWorldNormal + vec3(ripple.x, 0.0, ripple.y) * 0.045 * amount +
                               vec3(breeze.x, 0.0, breeze.y) * wave * 0.13 * amount);
            vec3 viewDirection = normalize(waterWorldPos - cameraPosition);
            float fresnel = pow(1.0 - clamp(dot(n, -viewDirection), 0.0, 1.0), 5.0);
            vec3 reflected = atrSky(reflect(viewDirection, n), waterWorldPos);
            color.rgb = mix(color.rgb, reflected, amount * (0.06 + fresnel * 0.30) * REFLECTION_INTENSITY);
            color.rgb += ripple.z * amount * vec3(0.018, 0.022, 0.024);
        }
    }
#endif
}
