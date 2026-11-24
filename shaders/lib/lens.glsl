#ifndef ATR_LENS
#define ATR_LENS
#include "/lib/weather.glsl"

// Scrolling the entire field lets a drop travel continuously; wrapping the
// centre inside a fixed cell made it jump between the cell's top and bottom.
vec4 atrLensDrop(vec2 tex, float aspect) {
    vec2 tile = tex * vec2(12.0 * aspect, 12.0) + vec2(0.0, frameTimeCounter * 0.055);
    vec2 cell = floor(tile);
    float seed = atrHash(cell);
    float exists = smoothstep(0.82, 0.90, seed);
    vec2 center = 0.32 + vec2(atrHash(cell + 4.1), atrHash(cell + 19.3)) * 0.36;
    vec2 delta = (fract(tile) - center) * vec2(0.91, 1.22);
    float radius = length(delta);
    float aa = clamp(length(fwidth(tile)), 0.003, 0.04);
    float shape = (1.0 - smoothstep(0.10, 0.17 + aa, radius)) * exists;
    float rim = (1.0 - smoothstep(0.17, 0.21 + aa, radius)) -
                 (1.0 - smoothstep(0.10, 0.14 + aa, radius));
    vec2 edge = abs(tex - 0.5) * 2.0;
    float border = smoothstep(0.40, 0.88, max(edge.x, edge.y));
    return vec4(delta * shape * border, shape * border, rim * exists * border);
}
#endif
