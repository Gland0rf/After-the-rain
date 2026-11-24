
# AfterTheRain

**Make minecraft rain beautiful.**

AfterTheRain is a weather-focused Minecraft shaderpack that makes rainy days more immersive while keeping clear weather close to vanilla Minecraft.

Watch puddles form, surfaces become wet, and the world slowly dry after a storm.

## Features

- Rain darkens blocks and adds a glossy appearance.
- Puddles form naturally on stone, paths, grass, and other surfaces.
- Wet surfaces reflect their surroundings.
- Animated ripples appear in puddles during rainfall.
- Darker skies with procedural storm clouds.
- The world slowly returns to normal after rain.
- Nearby roofs shelter terrain and water from rain, using an optional overhead depth pass.
- Puddles reflect the procedural storm sky when screen-space reflections miss.
- Rough stone, wood, soil, and polished blocks have different reflection softness and drying responses.
- Puddle edges retreat as surfaces dry, leaving irregular damp patches.
- Rain rings and subtle wind waves appear on exposed rivers and lakes.
- Shared gusts move rain, clouds, leaves, grass, and ferns during storms.
- Thunderstorms have heavier clouds and mist than ordinary showers.
- Low mist stays at a configurable world height as you move the camera.
- Material-shaped dampness follows plank seams and block joints, with a soft wet-wood sheen.
- Nearby visual roof/ledge drips linger after rain and make tiny landing rings.
- Fine runoff trails appear on exposed stone walls and clear glass.
- Lightning adds a coordinated, adjustable response to wet surfaces, clouds, water, and mist.
- Clearing weather opens cloud breaks and restores warmer outdoor colours while the ground dries.
- An optional faint rainbow follows the sun direction as rain clears.
- Local block light warms vanilla rain and makes nearby droplets more visible at night.
- Moving rain curtains add depth beyond nearby precipitation particles.
- Soft sun shafts appear through visible sky openings as rain clears.
- Biome humidity and temperature influence mist, drying, and storm colours.
- Exposed mobs and third-person players receive a subtle damp tint and sheen.
- Terrain pooling favours lower ground and the bases of steps while reducing puddles beside drops.
- Small world-anchored rain impact crowns replace simple ground pinpricks.
- Retreating puddles leave a narrow damp fringe while their interiors break into smaller patches.
- Rain-soaked water gets gentle shoreline foam and a shallow-to-deep colour transition.
- Subtle texture-anchored water beads highlight exposed leaves, grass, and ferns.
- Optional lens droplets slide continuously around the screen edges and fade with rain exposure.
- Terrain debug views expose roof coverage, wetness, pooling, material families, and reflection masks.

## Quality and settings

Choose a profile in **Shader Pack Settings**:

| Profile | Main tradeoffs |
| --- | --- |
| Fast | Two sky-noise octaves, sky reflections, skylight-based exposure, restrained lamplit rain, drying borders, biome response, and entity wetness. Disables roof mapping, terrain pooling, drips, curtains, sun shafts, ground impacts, shoreline detail, foliage beads, wall runoff, water ripples, foliage wind, reflection blur, and glow. |
| Balanced | Three sky-noise octaves, refined 24-step pool reflections, four-neighbour pooling, nearby drips, 12-sample rain curtains and half-resolution sun shafts, ground impacts, drying borders, shoreline detail, foliage beads, wall runoff, material softness, water ripples, and foliage wind. Default settings; lens droplets remain off. |
| Cinematic | Four sky-noise octaves with horizon cloud banks, refined 36-step pool reflections, eight-neighbour pooling, extended drips, 20-sample curtains and sun shafts, extra procedural rain, stronger lamplight, lens droplets, and the optional rainbow. |

**Wet Ground** includes wetting and drying half-lives in ticks (20 ticks is about one second), grass puddles, and optional roof detection. Materials remap the shared wetness history: wood and soil hold dampness longer than polished blocks. Puddle Size changes patch scale independently of coverage.

Material Wet Patterns follows face UVs so seams remain attached to blocks as the camera moves. Wood favours narrow damp joints and a soft sheen. Rough wet films use a diffuse sky average; detailed cloud images and screen-space reflections are reserved for clearer pools. Roof-edge Drips requires Roof Detection. Nearby traces up to ten half-block columns along each view ray; Extended traces twenty, both capped at twelve blocks. Drips are inferred visual approximations at captured roof/ledge edges, rather than game particles or a fluid simulation.

Terrain Pooling also requires Roof Detection. Balanced samples four adjacent captured heights and Detailed samples eight. Raised neighbours favour collection at the base of a step or in a shallow depression; a lower neighbour reduces water retention beside a drop. This changes puddle coverage and strength without storing or simulating water volumes.

Wet Mobs and Players adds mild darkening and a soft sheen to exposed models through `gbuffers_entities`, including third-person players. It uses the shared weather history and current exposure; it does not keep an independent wetness timer for each entity. The first-person hand has its own render pass. Existing entity hurt/interaction tints remain applied after the weather response.

**Drying Puddle Borders** narrows the pool interior and leaves a softer damp fringe as the shared wetness falls. The boundary uses the existing world-anchored puddle field, without time-driven noise. **Wet Foliage Beads** adds sparse highlights anchored to block-face UVs so they follow the existing foliage movement. Their footprint fade reduces distant shimmer. Both controls are under Wet Ground.

**Rain and Wind** controls vanilla rain slant as well as optional extra rain. Wind Gusts shares smooth speed changes across the weather effects; Storm Foliage Movement only animates vegetation while it rains. Snow geometry and precipitation shading retain their vanilla treatment.

Rain Impacts now draws small expanding, broken crowns on exposed wet ground, including ground outside puddles. These are surface decals rather than additional airborne particles. They fade between 16 and 28 blocks, use a footprint fade, and share roof exposure with the terrain's wetness. Fast disables them.

**Shallow Water and Foam**, under Puddles and Reflections, applies only to mapped water top faces during wet weather. It reconstructs the visible opaque bed behind the water, uses its vertical separation to soften the depth colour transition, and adds a broken foam fringe within roughly half a block of shore. Foam follows the existing lightmap, including at night. Glass, lava, and water sides retain their existing treatment. Fast disables this effect.

**Water on Camera**, under Camera and Lighting, remains optional and off in the default Balanced profile. Cinematic enables it. The droplet field now scrolls continuously instead of wrapping each drop inside a stationary cell. Lens Droplet Strength adjusts its refraction and rim highlights. The screen centre stays clear; shelter reduces the effect and it is disabled underwater and in snow.

**Atmosphere and Clouds** includes sky detail, independent storm cloud shapes, heavier thunderstorms, and the world height of the mist layer. Storm Clouds requires Storm Sky. Cloud Wind Speed scales the shared Wind Strength.

Lightning Flash Strength controls the extra response to rendered lightning bolts; zero disables it. Clearing Weather uses the difference between lingering wetness and current rain to gradually break clouds and warm outdoor colours. After-rain Rainbow is off by default and enabled by Cinematic: look opposite a low daytime sun while the ground is still wet after rain. All of these have individual controls.

**Weather Details** contains the new atmosphere and rain-lighting controls:

- **Lamplit Rain** uses the local block-light value carried by vanilla weather geometry to warm and brighten rain, with a stronger response at night. It shares the existing lightmap rather than tracking individual coloured light sources. Snow keeps its existing treatment; optional procedural extra-rain layers keep their existing lighting.
- **Distant Rain Curtains** integrates a moving world-space noise field between 16 and 180 blocks, stopping at visible scene depth. Weather Sampling Quality selects 8, 12, or 20 samples. Curtains require rainfall and some camera skylight, and fade above the cloud layer.
- **Clearing Sun Shafts** samples visible sky brightness toward the sun as a storm clears. `composite1` writes a half-resolution RGBA16F buffer; `composite2` upsamples it with depth weights to limit bleeding across silhouettes. Nearby held geometry is protected by a distance fade. The effect requires exposed sky and the sun on or near the screen.
- **Biome Weather Moods** smooths the camera biome's rainfall and temperature properties. Humid areas get denser, longer-lived mist and slower drying curves; cold areas get cooler storm colours. Clear weather remains governed by the existing vanilla-friendly rendering path.

Fast disables curtains, shafts, and terrain pooling while retaining the less expensive lamplit rain, biome response, and entity wetness. Balanced enables the complete set at moderate sampling; Cinematic raises sampling and pooling detail. Each effect can be adjusted separately. When sun shafts are disabled, both added composite passes are disabled as well.

**Weather Debug View** is on the root settings screen and defaults to Off. Choosing a profile resets it to Off. The views colour terrain; water and entities retain their own passes. Atmospheric effects and camera post-processing bypass the diagnostic colours.

| Debug view | Meaning |
| --- | --- |
| Roof Coverage | Red is sheltered; green is exposed. Works on dry ground too. With Roof Detection off this shows the skylight fallback. |
| Wetness and Puddles | Red is puddle coverage, green is dampness, blue is exposure on weather-active mapped materials. Fully dry terrain is black. |
| Terrain Pooling | Orange drains, blue collects, grey is neutral. Requires Roof Detection and nonzero Terrain Pooling for height-based results. |
| Material Families | Grey stone, tan paths, brown wood/soil, gold polished blocks, bright green grass blocks, dark green foliage, magenta unmapped terrain. |
| Reflection Masks | Red is screen-space hit confidence, green is reflection strength, blue is the directional pool-reflection mask. |

### Rendering limits

- Roof detection is strongest within about 85 blocks horizontally and blends to skylight-based exposure near the edge of its 192-block square map. It needs loaded terrain and adds a geometry pass, including during clear weather. Turn it off or choose Fast to avoid that cost.
- The shelter map stores world height and validity in a 32-bit float RG buffer. Terrain positions use Iris's camera-relative vertex coordinates directly, keeping roof/ground classification independent of camera rotation and depth-buffer decoding.
- Roof sampling keeps those relative positions through the fragment stage. A three-block grid (32 map texels) uses Iris's separate integer/fractional camera components so small camera movements do not change the map's sub-texel alignment.
- Biome precipitation is taken from the camera's biome and blended across borders. This prevents lasting rain wetness in dry and snowy biomes, but cannot classify each distant surface independently. The effects are also disabled in dimensions without skylight.
- Screen-space reflections show opaque objects visible on screen. Off-screen misses use the storm sky, not off-screen buildings; confidence fades at screen edges and uncertain depth intersections. Transparent objects are not traced.
- Drying uses smoothed weather history and material response curves, not saved water amounts for individual blocks. Building a roof or reloading the shaderpack does not preserve per-block wetness history.
- Natural-water ripples target mapped water top faces. Clear glass, glass panes, and tinted glass can receive wall runoff; stained glass, lava, and ice retain their existing shading. Glass trails add a faint transparent water film even where its base texture is clear.
- Roof drips depend on nearby captured height changes, so steep ledges can drip too, and roofs above unseen/lower layers cannot be reconstructed completely from the single overhead height map.
- Terrain pooling shares the overhead map's range and single-height limitations. It cannot determine the volume, drainage network, or deeper hidden geometry of a real basin.
- Rain curtains and sun shafts use visible scene depth. They do not include off-screen occluders or a complete 3D lighting simulation, and they add GPU work when enabled.
- Shoreline detail uses the bed visible behind the water; it cannot recover hidden terrain or simulate waves breaking against unseen shores. Impact crowns, foliage beads, and foam are procedural shading, not extra game geometry or particles.

## Development checks

Run `python tools/validate_shaders.py` on Windows. The validator checks menus, profiles, material mappings and includes, then compiles and links every shader pair across fifteen configurations on a hidden OpenGL context. These include all profiles, disabled features, atmosphere quality/zero-strength branches, and each of the five debug views. It renders roof exposure across camera movement, grid recentering and larger world coordinates using the full-resolution map, and checks the actual deferred pass on a damp-wood movement fixture. It needs no additional Python packages. `--static-only` skips GPU checks.

The GPU fixtures additionally check that raised ground drains, ground below a step retains more water, flat ground remains neutral, and block-lit rain becomes warmer and more visible. `tools/weather_fixtures.py` adds rendered scenes for world-anchored impacts, shrinking puddles and damp borders, foliage highlights, shallow water, biome response, entity wetness and hurt tint, rain curtains, half-resolution sun shafts and their full-resolution combine, lens motion and gating, and debug output. It also checks dry/sheltered/disabled cases, water material restrictions, dark foam, invalid cloud height, and near-geometry rejection for shafts. The shader-pair loop includes both new composite programs. These checks complement in-game evaluation; they do not measure frame rate or execute Iris's Java parser/patcher.

Latest verification (2026-11-22): all 345 shader-program links passed across 15 configurations, with 267 unique stage compilations on AMD Radeon PRO Graphics / OpenGL 4.6. Roof stability, pooling, wet-wood movement, lamplit rain, and all 66 additional weather-detail checks passed. The roof-edge exposure spread was 0.00000 across the tested camera positions, including map recentering and larger world coordinates. Static configuration checks and `git diff --check` also passed.

The native validator does not run Iris's shader patcher or Minecraft. In game, check clear weather, rain, thunder, and drying; compare stone, wood, grass, and polished blocks; move and turn on a wet wooden platform; walk under solid and glass roofs; inspect nearby roof-edge drips and glass trails; view water from above; cross desert/snow biome borders; and switch all three profiles. After rain, check cloud breaks and the optional rainbow opposite a low sun. Also inspect ground crowns, drying borders, foliage beads, shallow shorelines, and optional lens droplets. Visual quality, Minecraft/Iris integration, and frame time still need in-game evaluation.

## Installation

1. Install [Iris Shaders](https://modrinth.com/mod/iris).
2. Download the latest AfterTheRain release.
3. Place the `.zip` file in your Minecraft `shaderpacks` folder.
4. Navigate to **Options → Video Settings → Shader Packs**.
5. Select **AfterTheRain** and apply.

## Compatibility

- **Minecraft:** Java Edition
- **Shader Loader:** Iris Shaders
- **Recommended:** Sodium

## Credits

AfterTheRain is based on
[Base-330](https://github.com/shaderLABS/Base-330)
by shaderLABS, originally released under The Unlicense.

## License

AfterTheRain is licensed under the GNU General Public
License v3.0 (GPL-3.0).

See [LICENSE](LICENSE) for details.

---
