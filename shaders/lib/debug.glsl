#ifndef ATR_DEBUG
#define ATR_DEBUG
#include "/lib/pooling.glsl"

vec3 atrMaterialDebug(int material) {
    if (material == 100) return vec3(0.55, 0.60, 0.65);
    if (material == 101) return vec3(0.80, 0.65, 0.35);
    if (material == 102) return vec3(0.60, 0.28, 0.10);
    if (material == 103) return vec3(0.35, 0.18, 0.08);
    if (material == 105) return vec3(0.90, 0.75, 0.25);
    if (material == 106) return vec3(0.35, 0.75, 0.20);
    if (material == 104 || material == 107 || material == 108 || material == 110 || material == 111)
        return vec3(0.05, 0.40, 0.15);
    return vec3(0.55, 0.10, 0.60);
}

vec3 atrPoolingDebug(float retention) {
    return retention < 1.0 ? mix(vec3(0.18), vec3(0.95, 0.30, 0.06), clamp((1.0 - retention) / 0.45, 0.0, 1.0)) :
                            mix(vec3(0.18), vec3(0.08, 0.40, 1.0), clamp((retention - 1.0) / 0.40, 0.0, 1.0));
}
#endif
