#ifndef ATR_SETTINGS
#define ATR_SETTINGS

#define WET_DARKNESS 0.64 // [0.48 0.56 0.64 0.72 0.80]
#define PUDDLE_AMOUNT 0.85 // [0.00 0.25 0.50 0.70 0.85 1.00]
#define PUDDLE_SIZE 0.54 // [0.40 0.48 0.54 0.60 0.66]
#define GRASS_PUDDLES 0.80 // [0.00 0.20 0.40 0.60 0.80 1.00]
#define WETTING_TIME 90.0 // [30.0 60.0 90.0 180.0 360.0]
#define DRYING_TIME 1400.0 // [400.0 800.0 1400.0 2400.0 4000.0]
#define RAIN_SHELTER // Overhead roof detection near the camera
#define REFLECTION_QUALITY 2 // [0 1 2 3]
#define REFLECTION_INTENSITY 0.85 // [0.40 0.60 0.85 1.00]
#define MATERIAL_ROUGHNESS // Soften reflections on rough wet materials
#define MATERIAL_WET_PATTERNS // Wetness follows plank seams and stone joints
#define WALL_RUNOFF // Narrow rain trails on exposed stone and glass
#define ROOF_DRIPS 1 // [0 1 2] Off, nearby, or extended visual roof-edge drips
#define RAIN_RIPPLES
#define WATER_RIPPLES // Rain and wind on rivers and lakes
#define RAIN_SPLASHES
#define RAIN_DETAIL 0 // [0 1 2 3]
#define RAIN_DENSITY 0.75 // [0.50 0.75 1.00 1.25 1.50]
#define RAIN_STREAK_BRIGHTNESS 0.80 // [0.40 0.60 0.80 1.00 1.20]
#define RAIN_WIND 0.35 // [0.00 0.20 0.35 0.60 0.85]
#define WIND_GUSTS
#define FOLIAGE_WIND // Restrained movement during rain only
#define SILVER_RAIN
#define RAIN_SHADER_DEBUG 0 // [0 1]
#define STORM_SKY
#define STORM_CLOUDS
#define SKY_QUALITY 1 // [0 1 2]
#define STORM_CLOUD_COVER 0.82 // [0.45 0.60 0.72 0.82 0.92]
#define STORM_SKY_DARKNESS 0.72 // [0.35 0.50 0.72 0.88 1.00]
#define STORM_CLOUD_WIND 0.45 // [0.10 0.25 0.45 0.70 1.00]
#define THUNDER_ATMOSPHERE
#define LIGHTNING_RESPONSE 0.35 // [0.00 0.20 0.35 0.50 0.75]
#define CLEARING_SKY // Cloud breaks and warmer light while the ground dries
//#define AFTER_RAIN_RAINBOW // Faint sun-aligned rainbow as a storm clears
#define RAIN_FOG
#define FOG_AMOUNT 0.78 // [0.00 0.25 0.50 0.78 1.00]
#define MIST_HEIGHT 80.0 // [48.0 64.0 80.0 96.0 128.0 160.0]
#define RAIN_COLOR_GRADE
#define STORM_GLOW
#define STORM_VIGNETTE
//#define LENS_DROPLETS

#endif
