#ifndef ATR_DRIPS
#define ATR_DRIPS
#include "/lib/exposure.glsl"

// Procedural droplets beside height discontinuities in the overhead map. This
// approximates loaded roof/ledge edges; it does not create Minecraft particles.
bool atrDripSource(vec2 cell, out vec3 source, out float groundHeight) {
    vec2 centre = (cell + 0.5) * 0.5;
    source = vec3(centre.x, 0.0, centre.y);
    groundHeight = 0.0;
#if ROOF_DRIPS > 0 && defined(RAIN_SHELTER)
    if (atrHash(cell + 91.7) < 0.58) return false;
    if (!atrRoofHeight(centre, groundHeight)) return false;
    float roofHeight = groundHeight;
    vec2 edgeDirection = vec2(0.0);
    const vec2 offsets[4] = vec2[4](vec2(1.0, 0.0), vec2(-1.0, 0.0),
                                   vec2(0.0, 1.0), vec2(0.0, -1.0));
    for (int i = 0; i < 4; ++i) {
        float height;
        if (atrRoofHeight(centre + offsets[i] * 0.5, height) && height > roofHeight) {
            roofHeight = height;
            edgeDirection = offsets[i];
        }
    }
    if (roofHeight - groundHeight < 0.65) return false;
    vec2 tangent = vec2(-edgeDirection.y, edgeDirection.x);
    centre += edgeDirection * 0.21 + tangent * (atrHash(cell + 17.3) - 0.5) * 0.18;
    source = vec3(centre.x, roofHeight - 0.04, centre.y);
    return true;
#else
    return false;
#endif
}

float atrDripPhase(vec2 cell) {
    float seed = atrHash(cell + 3.9);
    return fract(frameTimeCounter * (0.60 + seed * 0.30) + seed);
}

float atrDripAmount() {
    // Residual moisture leaves a few drips after precipitation has stopped.
    return max(atrRain(), atrWetness() * 0.18);
}

float atrRoofDrips(vec3 rayDirection, float sceneDistance) {
    float opacity = 0.0;
#if ROOF_DRIPS > 0 && defined(RAIN_SHELTER)
    float amount = atrDripAmount();
    if (amount < 0.003) return 0.0;
    vec2 horizontal = rayDirection.xz;
    vec2 directionSign = vec2(horizontal.x >= 0.0 ? 1.0 : -1.0,
                              horizontal.y >= 0.0 ? 1.0 : -1.0);
    vec2 inverse = 1.0 / max(abs(horizontal), vec2(0.0001));
    vec2 cell = floor(cameraPosition.xz / 0.5);
    vec2 boundary = (cell + step(vec2(0.0), horizontal)) * 0.5;
    vec2 next = abs(boundary - cameraPosition.xz) * inverse;
    if (abs(horizontal.x) < 0.0001) next.x = 100000.0;
    if (abs(horizontal.y) < 0.0001) next.y = 100000.0;
    vec2 delta = vec2(0.5) * inverse;
    float footprint = max(length(fwidth(rayDirection)), 0.0001);
    float entry = 0.0;
#if ROOF_DRIPS == 1
    const int cells = 10;
#else
    const int cells = 20;
#endif
    for (int i = 0; i < cells; ++i) {
        if (entry > min(sceneDistance, 12.0)) break;
        vec3 source;
        float ground;
        if (atrDripSource(cell, source, ground)) {
            float age = atrDripPhase(cell);
            vec3 centre = source;
            centre.y -= min(source.y - ground, 8.0) * age * age;
            float halfLength = 0.025 + age * 0.075;
            float horizontalT = dot(centre.xz - cameraPosition.xz, horizontal) /
                                max(dot(horizontal, horizontal), 0.00001);
            vec3 segmentPoint = centre;
            segmentPoint.y = clamp(cameraPosition.y + horizontalT * rayDirection.y,
                                   centre.y - halfLength, centre.y + halfLength);
            float t = dot(segmentPoint - cameraPosition, rayDirection);
            if (t > 0.15 && t < min(sceneDistance - 0.02, 12.0)) {
                float distanceToDrop = length(cameraPosition + rayDirection * t - segmentPoint);
                float aa = max(0.004, footprint * t * 0.70);
                float drop = 1.0 - smoothstep(0.008, 0.008 + aa, distanceToDrop);
                opacity = max(opacity, drop * (1.0 - smoothstep(7.0, 12.0, t)));
            }
        }
        if (next.x < next.y) {
            entry = next.x;
            cell.x += directionSign.x;
            next.x += delta.x;
        } else {
            entry = next.y;
            cell.y += directionSign.y;
            next.y += delta.y;
        }
    }
    opacity *= amount;
#endif
    return opacity;
}

float atrDripSplash(vec3 worldPos, vec3 normal) {
#if ROOF_DRIPS > 0 && defined(RAIN_SHELTER)
    if (normal.y < 0.8) return 0.0;
    vec2 cell = floor(worldPos.xz / 0.5);
    vec3 source;
    float ground;
    if (!atrDripSource(cell, source, ground)) return 0.0;
    if (abs(worldPos.y - ground) > 0.15 || source.y - ground > 8.0) return 0.0;
    float age = atrDripPhase(cell);
    float distanceToCentre = length(worldPos.xz - source.xz);
    float width = max(0.015, min(0.06, fwidth(distanceToCentre)));
    float ring = 1.0 - smoothstep(0.0, width, abs(distanceToCentre - age * 0.65));
    return ring * (1.0 - smoothstep(0.0, 0.20, age)) * atrDripAmount();
#else
    return 0.0;
#endif
}
#endif
