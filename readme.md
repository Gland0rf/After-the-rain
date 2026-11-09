
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

## Quality and settings

Choose a profile in **Shader Pack Settings**:

| Profile | Main tradeoffs |
| --- | --- |
| Fast | Two sky-noise octaves, sky reflections only, skylight-based exposure; disables roof mapping, drips, wall runoff, water ripples, foliage wind, reflection blur, and glow. |
| Balanced | Three sky-noise octaves, refined 24-step pool reflections, roof detection, nearby drips, wall runoff, material softness, water ripples, and foliage wind. Default settings. |
| Cinematic | Four sky-noise octaves with horizon cloud banks, refined 36-step pool reflections, extended drips, extra procedural rain, lens droplets, and the optional rainbow. |

**Wet Ground** includes wetting and drying half-lives in ticks (20 ticks is about one second), grass puddles, and optional roof detection. Materials remap the shared wetness history: wood and soil hold dampness longer than polished blocks. Puddle Size changes patch scale independently of coverage.

Material Wet Patterns follows face UVs so seams remain attached to blocks as the camera moves. Wood favours narrow damp joints and a soft sheen. Rough wet films use a diffuse sky average; detailed cloud images and screen-space reflections are reserved for clearer pools. Roof-edge Drips requires Roof Detection. Nearby traces up to ten half-block columns along each view ray; Extended traces twenty, both capped at twelve blocks. Drips are inferred visual approximations at captured roof/ledge edges, rather than game particles or a fluid simulation.

**Rain and Wind** controls vanilla rain slant as well as optional extra rain. Wind Gusts shares smooth speed changes across the weather effects; Storm Foliage Movement only animates vegetation while it rains. Snow geometry and precipitation shading retain their vanilla treatment.

**Atmosphere and Clouds** includes sky detail, independent storm cloud shapes, heavier thunderstorms, and the world height of the mist layer. Storm Clouds requires Storm Sky. Cloud Wind Speed scales the shared Wind Strength.

Lightning Flash Strength controls the extra response to rendered lightning bolts; zero disables it. Clearing Weather uses the difference between lingering wetness and current rain to gradually break clouds and warm outdoor colours. After-rain Rainbow is off by default and enabled by Cinematic: look opposite a low daytime sun while the ground is still wet after rain. All of these have individual controls.

### Rendering limits

- Roof detection is strongest within about 85 blocks horizontally and blends to skylight-based exposure near the edge of its 192-block square map. It needs loaded terrain and adds a geometry pass, including during clear weather. Turn it off or choose Fast to avoid that cost.
- Biome precipitation is taken from the camera's biome and blended across borders. This prevents lasting rain wetness in dry and snowy biomes, but cannot classify each distant surface independently. The effects are also disabled in dimensions without skylight.
- Screen-space reflections show opaque objects visible on screen. Off-screen misses use the storm sky, not off-screen buildings; confidence fades at screen edges and uncertain depth intersections. Transparent objects are not traced.
- Drying uses smoothed weather history and material response curves, not saved water amounts for individual blocks. Building a roof or reloading the shaderpack does not preserve per-block wetness history.
- Natural-water ripples target mapped water top faces. Clear glass, glass panes, and tinted glass can receive wall runoff; stained glass, lava, and ice retain their existing shading. Glass trails add a faint transparent water film even where its base texture is clear.
- Roof drips depend on nearby captured height changes, so steep ledges can drip too, and roofs above unseen/lower layers cannot be reconstructed completely from the single overhead height map.

## Development checks

Run `python tools/validate_shaders.py` on Windows. The validator checks menus, profiles, material mappings and includes, compiles and links every shader pair across eight configurations on a hidden OpenGL context, renders roof exposure at four camera positions using the full-resolution map, and checks the actual deferred pass on a damp-wood movement fixture. It needs no additional Python packages. `--static-only` skips GPU checks.

The native validator does not run Iris's shader patcher or Minecraft. In game, check clear weather, rain, thunder, and drying; compare stone, wood, grass, and polished blocks; move and turn on a wet wooden platform; walk under solid and glass roofs; inspect nearby roof-edge drips and glass trails; view water from above; cross desert/snow biome borders; and switch all three profiles. After rain, check cloud breaks and the optional rainbow opposite a low sun. Visual quality and frame time still need in-game evaluation.

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
