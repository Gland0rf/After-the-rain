"""Small GPU scenes for weather effects; called by validate_shaders.py.

Uses real helper code and full post-process programs. These are deterministic
regression scenes, not a replacement for Minecraft/Iris integration testing.
"""
import ctypes as C
import math


class Probe:
    SIZE = 128

    def __init__(self, context):
        self.context = context
        self.textures, self.shaders, self.programs = [], [], []
        fn = context.function
        u, i, f, p = C.c_uint, C.c_int, C.c_float, C.c_void_p
        self.gen_tex = fn("glGenTextures", None, i, C.POINTER(u))
        self.bind_tex = fn("glBindTexture", None, u, u)
        self.tex_parameter = fn("glTexParameteri", None, u, u, i)
        self.tex_image = fn("glTexImage2D", None, u, i, i, i, i, i, u, u, p)
        self.active = fn("glActiveTexture", None, u)
        self.gen_fbo = fn("glGenFramebuffers", None, i, C.POINTER(u))
        self.bind_fbo = fn("glBindFramebuffer", None, u, u)
        self.attach = fn("glFramebufferTexture2D", None, u, u, u, u, i)
        self.check = fn("glCheckFramebufferStatus", u, u)
        self.viewport = fn("glViewport", None, i, i, i, i)
        self.disable = fn("glDisable", None, u)
        self.use = fn("glUseProgram", None, u)
        self.location = fn("glGetUniformLocation", i, u, C.c_char_p)
        self.float1 = fn("glUniform1f", None, i, f)
        self.int1 = fn("glUniform1i", None, i, i)
        self.float2 = fn("glUniform2f", None, i, f, f)
        self.float3 = fn("glUniform3f", None, i, f, f, f)
        self.float4 = fn("glUniform4f", None, i, f, f, f, f)
        self.int2 = fn("glUniform2i", None, i, i, i)
        self.int3 = fn("glUniform3i", None, i, i, i, i)
        self.matrix = fn("glUniformMatrix4fv", None, i, i, C.c_ubyte, C.POINTER(f))
        self.begin = fn("glBegin", None, u)
        self.vertex = fn("glVertex3f", None, f, f, f)
        self.end = fn("glEnd", None)
        self.read = fn("glReadPixels", None, i, i, i, i, u, u, p)
        self.error = fn("glGetError", u)
        self.delete_tex = fn("glDeleteTextures", None, i, C.POINTER(u))
        self.delete_fbo = fn("glDeleteFramebuffers", None, i, C.POINTER(u))
        self.fbo = u()
        self.gen_fbo(1, C.byref(self.fbo))
        self.bind_fbo(0x8D40, self.fbo.value)
        self.output = self.texture([0.0] * (self.SIZE * self.SIZE * 4), self.SIZE)
        self.attach(0x8D40, 0x8CE0, 0x0DE1, self.output, 0)
        assert self.check(0x8D40) == 0x8CD5, "Incomplete weather fixture framebuffer"
        self.vertex_source = """#version 330 compatibility
out vec2 uv;
void main(){gl_Position=gl_Vertex; uv=gl_Vertex.xy*0.5+0.5;}
"""

    def texture(self, rgba, size=1):
        name = C.c_uint()
        self.gen_tex(1, C.byref(name))
        self.textures.append(name)
        self.active(0x84C0)
        self.bind_tex(0x0DE1, name.value)
        for key, value in ((0x2801, 0x2600), (0x2800, 0x2600), (0x2802, 0x812F), (0x2803, 0x812F)):
            self.tex_parameter(0x0DE1, key, value)
        data = (C.c_float * len(rgba))(*rgba)
        self.tex_image(0x0DE1, 0, 0x8814, size, size, 0, 0x1908, 0x1406, data)
        return name.value

    def program(self, fragment, label, vertex=None):
        pair = []
        for source, kind in ((vertex or self.vertex_source, 0x8B31), (fragment, 0x8B30)):
            shader = self.context.shader(source, kind, label)
            self.shaders.append(shader)
            pair.append(shader)
        program = self.context.program(*pair, label, retain=True)
        self.programs.append(program)
        return program

    def uniform(self, program, name, value):
        location = self.location(program, name.encode())
        if location < 0:
            return
        if isinstance(value, (tuple, list)):
            if len(value) == 16:
                self.matrix(location, 1, 0, (C.c_float * 16)(*value))
            elif name == "eyeBrightnessSmooth":
                self.int2(location, *value)
            elif name == "cameraPositionInt":
                self.int3(location, *value)
            else:
                {2: self.float2, 3: self.float3, 4: self.float4}[len(value)](location, *value)
        elif isinstance(value, (int, bool)):
            self.int1(location, int(value))
        else:
            self.float1(location, value)

    def render(self, program, uniforms=None, textures=None, size=SIZE):
        self.bind_fbo(0x8D40, self.fbo.value)
        self.viewport(0, 0, size, size)
        for capability in (0x0B71, 0x0B44, 0x0BE2):
            self.disable(capability)
        self.use(program)
        identity = (1., 0., 0., 0., 0., 1., 0., 0., 0., 0., 1., 0., 0., 0., 0., 1.)
        base = dict(hasSkylight=True, atrRainClimate=1.0, rainStrength=1.0, wetness=1.0,
                    atrBiomeHumidity=0.5, atrBiomeTemperature=0.8, atrLightningFlash=0.0,
                    thunderStrength=0.0, worldTime=6000, frameTimeCounter=0.17,
                    cloudHeight=192.0, cameraPosition=(0., 64., 0.),
                    cameraPositionInt=(0, 64, 0), cameraPositionFract=(0., 0., 0.),
                    skyColor=(0.60, 0.65, 0.70), fogColor=(0.40, 0.45, 0.50),
                    sunPosition=(0., 70., -70.), gbufferModelViewInverse=identity,
                    gbufferProjectionInverse=identity, gbufferProjection=identity,
                    isEyeInWater=0, biome_precipitation=1, eyeBrightnessSmooth=(240, 240),
                    viewWidth=float(size), viewHeight=float(size))
        base.update(uniforms or {})
        for name, value in base.items():
            self.uniform(program, name, value)
        for unit, (name, texture) in enumerate((textures or {}).items()):
            self.active(0x84C0 + unit)
            self.bind_tex(0x0DE1, texture)
            self.int1(self.location(program, name.encode()), unit)
        self.begin(0x0007)
        for x, y in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            self.vertex(x, y, 0)
        self.end()
        pixels = (C.c_float * (size * size * 4))()
        self.read(0, 0, size, size, 0x1908, 0x1406, pixels)
        assert self.error() == 0, "OpenGL error during weather fixture"
        assert all(math.isfinite(value) for value in pixels), "Non-finite weather output"
        return list(pixels)

    def close(self):
        self.use(0)
        self.bind_fbo(0x8D40, 0)
        self.active(0x84C0)
        for program in self.programs:
            self.context.delete_program(program)
        for shader in self.shaders:
            self.context.delete_shader(shader)
        for texture in self.textures:
            self.delete_tex(1, C.byref(texture))
        self.delete_fbo(1, C.byref(self.fbo))


def render_weather_fixtures(context, shaders, prepare, expand, configure, defaults):
    probe = Probe(context)
    options = dict(defaults, RAIN_SHELTER=False)
    passed = 0

    def helper(name, body, changes=None):
        source = '#version 330 compatibility\n' + expand(shaders / "lib" / name) + "\n" + body
        return probe.program(configure(source, dict(options, **(changes or {}))), name)

    def check(condition, message):
        nonlocal passed
        assert condition, message
        passed += 1

    def mean(pixels, channel):
        return sum(pixels[channel::4]) / (len(pixels) / 4)

    def close_to(pixels, rgba, tolerance=1e-6):
        return max(abs(value - rgba[i % 4]) for i, value in enumerate(pixels)) < tolerance

    try:
        # Surface impacts and drying: fixed-time world samples must not change
        # with camera movement. Fading weather must shrink, rather than enlarge,
        # pool interiors and retain a damp exterior before becoming fully dry.
        surface = helper("surface_details.glsl", """
in vec2 uv;
uniform int fixtureMode;
layout(location=0) out vec4 color;
void main(){
    if(fixtureMode==0) color=vec4(atrGroundSplash(uv*2.0),0.0,0.0,1.0);
    else {
        float field=uv.x;
        float threshold=0.545+(1.0-wetness)*0.25;
        color=vec4(atrDryingEdge(field,threshold,wetness,1.15),0.0,1.0);
    }
}
""")
        splash = probe.render(surface, dict(fixtureMode=0))
        check(max(splash[0::4]) > 0.1, "Surface impacts never became visible")
        moved = probe.render(surface, dict(fixtureMode=0, cameraPosition=(17.3, 68.1, -8.2)))
        check(splash == moved, "Impact pattern follows the camera")
        later = probe.render(surface, dict(fixtureMode=0, frameTimeCounter=0.43))
        check(splash != later, "Surface impacts did not animate")
        wet = probe.render(surface, dict(fixtureMode=1, rainStrength=1.0))
        drying = probe.render(surface, dict(fixtureMode=1, wetness=0.5, rainStrength=0.0))
        dry = probe.render(surface, dict(fixtureMode=1, wetness=0.0, rainStrength=0.0))
        check(mean(drying, 0) < mean(wet, 0) and mean(dry, 0) < mean(drying, 0), "Pools do not retreat while drying")
        check(mean(wet, 1) < 1e-6 and mean(drying, 1) > 0.005 and mean(dry, 1) < 1e-6,
              "Damp borders did not appear only during drying")

        foliage = helper("surface_details.glsl", """
in vec2 uv;
uniform float fixtureExposure;
uniform int fixtureMaterial;
layout(location=0) out vec4 color;
void main(){color=vec4(atrFoliageBeads(vec3(0.20,0.30,0.10),uv,vec3(0,1,0),
vec3(0,-2,-4),fixtureExposure,vec2(1),fixtureMaterial),1);}
""")
        leaf = probe.render(foliage, dict(fixtureExposure=1.0, fixtureMaterial=107))
        check(max(leaf[1::4]) > 0.301, "Wet foliage has no bead highlights")
        for uniforms in (dict(fixtureExposure=0.0, fixtureMaterial=107),
                         dict(fixtureExposure=1.0, fixtureMaterial=100),
                         dict(fixtureExposure=1.0, fixtureMaterial=107, wetness=0.0)):
            check(close_to(probe.render(foliage, uniforms), (.2, .3, .1, 1.)), "Foliage highlights leaked to dry/sheltered/non-foliage surfaces")

        shore = helper("shore.glsl", """
in vec2 uv;
uniform float fixtureThickness;
uniform float fixtureExposure;
layout(location=0) out vec4 color;
void main(){color=atrShoreWater(vec4(0.2,0.3,0.4,0.5),fixtureThickness,uv*8.0,fixtureExposure,vec3(1));}
""")
        shallow = probe.render(shore, dict(fixtureThickness=0.05, fixtureExposure=1.0))
        deep = probe.render(shore, dict(fixtureThickness=8.0, fixtureExposure=1.0))
        check(mean(shallow, 3) > 0.5001 and abs(mean(deep, 3) - 0.5) < 1e-6, "Foam did not stay at the shoreline")
        check(mean(shallow, 1) > mean(deep, 1), "Shallow water has no depth transition")
        for uniforms in (dict(fixtureThickness=0.05, fixtureExposure=0.0),
                         dict(fixtureThickness=0.05, fixtureExposure=1.0, wetness=0.0)):
            check(close_to(probe.render(shore, uniforms), (.2, .3, .4, .5)), "Shore effect leaked into sheltered/dry water")

        # Render the real water fragment shader to verify material, face and
        # depth gating. The synthetic bed is 0.08-0.12 blocks below the surface.
        water_vertex = """#version 330 compatibility
out vec2 lmcoord; out vec2 texcoord; out vec4 glcolor;
out vec3 waterWorldPos; out vec3 waterCameraRelative; out vec3 waterWorldNormal;
flat out int waterMaterial;
uniform int fixtureMaterial; uniform vec3 fixtureNormal;
void main(){gl_Position=gl_Vertex; texcoord=gl_Vertex.xy*0.5+0.5;
lmcoord=vec2(1); glcolor=vec4(1); waterWorldPos=vec3(texcoord.x*8,64,texcoord.y*8);
waterCameraRelative=vec3(gl_Vertex.x,0,gl_Vertex.y-4);
waterWorldNormal=fixtureNormal; waterMaterial=fixtureMaterial;}
"""
        water_options = dict(options, WATER_RIPPLES=False, WALL_RUNOFF=False)
        water = probe.program(prepare(shaders / "gbuffers_water.fsh", water_options), "water material restrictions", water_vertex)
        water_color = probe.texture([.2, .3, .4, .5])
        full_light = probe.texture([1., 1., 1., 1.])
        bed_depth = probe.texture([.7, 0., 0., 1.])
        front_depth = probe.texture([.3, 0., 0., 1.])
        bed_projection = (1., 0., 0., 0., 0., .02, 0., 0., 0., 0., 1., 0., 0., -.1, -4., 1.)
        water_uniforms = dict(fixtureMaterial=109, fixtureNormal=(0., 1., 0.), gbufferProjectionInverse=bed_projection)
        water_inputs = dict(gtexture=water_color, lightmap=full_light, depthtex1=bed_depth)
        check(mean(probe.render(water, water_uniforms, water_inputs), 3) > .5001, "Actual water pass did not produce shoreline foam")
        for uniforms in (dict(water_uniforms, fixtureMaterial=112), dict(water_uniforms, fixtureMaterial=0),
                         dict(water_uniforms, fixtureNormal=(1., 0., 0.)), dict(water_uniforms, wetness=0.0)):
            check(close_to(probe.render(water, uniforms, water_inputs), (.2, .3, .4, .5)), "Shore shading leaked onto glass/lava/sides/dry water")
        check(close_to(probe.render(water, water_uniforms, dict(water_inputs, depthtex1=front_depth)), (.2, .3, .4, .5)),
              "Foreground depth caused false shoreline foam")
        dark_light = probe.texture([0., 0., 0., 1.])
        dark_foam = probe.render(water, water_uniforms, dict(water_inputs, lightmap=dark_light))
        check(max(max(dark_foam[c::4]) for c in range(3)) < 1e-6, "Shoreline foam glows without illumination")

        biome = helper("weather.glsl", """
layout(location=0) out vec4 color;
void main(){color=vec4(atrBiomeMistScale(),atrBiomeDryPower(),atrLingeringMist(),atrBiomeFogTint().b);}
""")
        arid = probe.render(biome, dict(atrBiomeHumidity=0.0))[:4]
        humid = probe.render(biome, dict(atrBiomeHumidity=1.0))[:4]
        cold = probe.render(biome, dict(atrBiomeTemperature=-0.5))[:4]
        warm = probe.render(biome, dict(atrBiomeTemperature=1.0))[:4]
        check(humid[0] > arid[0] and humid[1] < arid[1] and humid[2] > arid[2], "Humidity does not change mist/drying correctly")
        check(cold[3] > warm[3], "Cold storm tint is not cooler")
        neutral_biome = helper("weather.glsl", """
layout(location=0) out vec4 color;
void main(){color=vec4(atrBiomeMistScale(),atrBiomeDryPower(),atrLingeringMist(),atrBiomeFogTint().b);}
""", dict(BIOME_WEATHER=False))
        check(close_to(probe.render(neutral_biome), (1., 1., .11, 1.)), "Disabling biome response did not restore neutral values")

        entity = helper("entity_wetness.glsl", """
in vec2 uv;
uniform float fixtureSkylight;
layout(location=0) out vec4 color;
void main(){color=vec4(atrWetEntity(vec3(0.4,0.3,0.2),vec3(0,-1,-4),vec3(0,1,0),uv,vec2(1,fixtureSkylight)),1);}
""")
        check(not close_to(probe.render(entity, dict(fixtureSkylight=1.0)), (.4, .3, .2, 1.)), "Exposed entities did not get wet")
        for uniforms in (dict(fixtureSkylight=0.0), dict(fixtureSkylight=1.0, wetness=0.0),
                         dict(fixtureSkylight=1.0, hasSkylight=False)):
            check(close_to(probe.render(entity, uniforms), (.4, .3, .2, 1.)), "Entity effect leaked into shelter/dry weather/no-skylight dimensions")
        entity_vertex = """#version 330 compatibility
out vec2 lmcoord; out vec2 texcoord; out vec4 glcolor;
out vec3 entityCameraRelative; out vec3 entityWorldNormal;
uniform float fixtureSkylight;
void main(){gl_Position=gl_Vertex; texcoord=gl_Vertex.xy*0.5+0.5;
lmcoord=vec2(1,fixtureSkylight); glcolor=vec4(1);
entityCameraRelative=vec3(0,-1,-4); entityWorldNormal=vec3(0,1,0);}
"""
        entity_pass = probe.program(prepare(shaders / "gbuffers_entities.fsh", options), "entity tint preservation", entity_vertex)
        entity_texture = probe.texture([.4, .3, .2, .8])
        entity_light = probe.texture([.8, .7, .6, 1.])
        entity_inputs = dict(gtexture=entity_texture, lightmap=entity_light)
        entity_uniforms = dict(fixtureSkylight=1.0, entityColor=(0., 0., 0., 0.))
        for uniforms in (dict(entity_uniforms, wetness=0.0), dict(entity_uniforms, fixtureSkylight=0.0),
                         dict(entity_uniforms, hasSkylight=False)):
            check(close_to(probe.render(entity_pass, uniforms, entity_inputs), (.32, .21, .12, .8)),
                  "Entity pass changed dry/sheltered/base-lit texture or alpha")
        hurt = probe.render(entity_pass, dict(entity_uniforms, entityColor=(.9, .1, .1, 1.)), entity_inputs)
        check(close_to(hurt, (.72, .07, .06, .8)), "Weather response damaged the existing entity tint or alpha")

        curtain = helper("atmosphere.glsl", """
in vec2 uv;
uniform float fixtureDistance;
uniform float fixtureSkylight;
layout(location=0) out vec4 color;
void main(){color=atrRainCurtain(normalize(vec3((uv-0.5)*2.0,-1)),fixtureDistance,fixtureSkylight);}
""")
        rain = probe.render(curtain, dict(fixtureDistance=180.0, fixtureSkylight=1.0))
        check(max(rain[3::4]) > 0.005 and max(rain[3::4]) <= 0.3, "Rain curtains missing or excessive")
        for uniforms in (dict(fixtureDistance=12.0, fixtureSkylight=1.0),
                         dict(fixtureDistance=180.0, fixtureSkylight=0.0),
                         dict(fixtureDistance=180.0, fixtureSkylight=1.0, rainStrength=0.0),
                         dict(fixtureDistance=180.0, fixtureSkylight=1.0, hasSkylight=False)):
            check(max(probe.render(curtain, uniforms)[3::4]) < 1e-6, "Rain curtain leaked past weather/distance/shelter gate")
        invalid_cloud = probe.render(curtain, dict(fixtureDistance=180.0, fixtureSkylight=1.0, cloudHeight=float("nan")))
        check(max(invalid_cloud[3::4]) > 0.005, "Invalid cloud plane did not use safe fallback")
        zero_curtain = helper("atmosphere.glsl", """
layout(location=0) out vec4 color;
void main(){color=atrRainCurtain(vec3(0,0,-1),180.0,1.0);}
""", dict(RAIN_CURTAIN_AMOUNT="0.00"))
        check(close_to(probe.render(zero_curtain), (0., 0., 0., 0.)), "Zero curtain strength did not disable the effect")

        # Run the actual shaft generation and combine programs. The first
        # target is half the combine resolution, just like shaders.properties.
        shaft = probe.program(prepare(shaders / "composite1.fsh", options), "shaft generation")
        white = probe.texture([1., 1., 1., 1.])
        sky_depth = probe.texture([1., 0., 0., 1.])
        solid_depth = probe.texture([.5, 0., 0., 1.])
        perspective = (1., 0., 0., 0., 0., 1., 0., 0., 0., 0., -1., -1., 0., 0., -.2, 0.)
        shaft_uniforms = dict(rainStrength=0.0, gbufferProjection=perspective)
        shaft_inputs = dict(colortex0=white, depthtex0=sky_depth)
        rays = probe.render(shaft, shaft_uniforms, shaft_inputs, size=64)
        check(mean(rays, 0) > 0.001, "Clearing sky produced no shafts")
        for uniforms in (dict(shaft_uniforms, rainStrength=1.0), dict(shaft_uniforms, wetness=0.0),
                         dict(shaft_uniforms, isEyeInWater=1), dict(shaft_uniforms, worldTime=18000),
                         dict(shaft_uniforms, eyeBrightnessSmooth=(0, 0))):
            check(max(probe.render(shaft, uniforms, shaft_inputs, size=64)[0::4]) < 1e-6,
                  "Shafts leaked through weather/night/underwater/shelter gates")
        blocked = probe.render(shaft, shaft_uniforms, dict(colortex0=white, depthtex0=solid_depth), size=64)
        check(max(blocked[0::4]) < 1e-6, "Opaque geometry emitted sun shafts")
        zero_shaft = probe.program(prepare(shaders / "composite1.fsh", dict(options, SUN_SHAFT_STRENGTH="0.00")), "zero shaft strength")
        check(max(probe.render(zero_shaft, shaft_uniforms, shaft_inputs, size=64)[0::4]) < 1e-6,
              "Zero shaft strength did not disable the effect")
        combine = probe.program(prepare(shaders / "composite2.fsh", options), "shaft combine")
        base = probe.texture([.2, .3, .4, 1.])
        shaft_texture = probe.texture(rays, 64)
        combined = probe.render(combine, dict(rainStrength=0.0), dict(colortex0=base, colortex5=shaft_texture, depthtex0=sky_depth))
        check(mean(combined, 0) > .201, "Half-resolution shafts were not combined")
        close = probe.render(combine, dict(rainStrength=0.0), dict(colortex0=base, colortex5=shaft_texture, depthtex0=solid_depth))
        check(close_to(close, (.2, .3, .4, 1.)), "Shafts bled across near geometry")

        # Exercise actual final rendering, so shelter/underwater/snow/debug
        # bypasses cover both lens refraction and highlight compositing.
        lens_options = dict(options, LENS_DROPLETS=True, STORM_GLOW=False, STORM_VIGNETTE=False)
        lens = probe.program(prepare(shaders / "final.fsh", lens_options), "lens final pass")
        lens_input = dict(colortex0=base)
        droplets = probe.render(lens, textures=lens_input)
        check(mean(droplets, 0) > .20001, "Lens droplets did not render")
        center_pixel = (64 * 128 + 64) * 4
        check(abs(droplets[center_pixel] - .2) < 1e-6, "Lens droplets obscured screen center")
        for uniforms in (dict(eyeBrightnessSmooth=(0, 0)), dict(isEyeInWater=1),
                         dict(rainStrength=0.0), dict(biome_precipitation=2)):
            check(close_to(probe.render(lens, uniforms, lens_input), (.2, .3, .4, 1.)), "Lens effect leaked into shelter/underwater/dry/snow")
        disabled_lens = probe.program(prepare(shaders / "final.fsh", dict(lens_options, LENS_DROPLETS=False)), "lens disabled")
        check(close_to(probe.render(disabled_lens, textures=lens_input), (.2, .3, .4, 1.)), "Disabled lens effect changed the image")
        lens_motion = helper("lens.glsl", """
in vec2 uv;
uniform vec2 fixtureShift;
layout(location=0) out vec4 color;
void main(){color=atrLensDrop(vec2(0.03,0.25+uv.y*0.5)+fixtureShift,1.0);}
""")
        original = probe.render(lens_motion, dict(fixtureShift=(0., 0.), frameTimeCounter=4.0))
        translated = probe.render(lens_motion, dict(fixtureShift=(0., -.055*.02/12.), frameTimeCounter=4.02))
        check(max(original[2::4]) > 0.05, "Lens motion fixture did not contain a visible drop")
        check(max(abs(a-b) for a, b in zip(original, translated)) < .0005,
              "Lens drops jumped instead of translating continuously")

        disabled_surface = helper("surface_details.glsl", """
in vec2 uv;
layout(location=0) out vec4 color;
void main(){color=vec4(atrGroundSplash(uv*2.0),atrDryingEdge(uv.x,0.6,0.5,1.15).y,
length(atrFoliageBeads(vec3(0.2),uv,vec3(0,1,0),vec3(0,-2,-4),1.0,vec2(1),107)-vec3(0.2)),1);}
""", dict(RAIN_SPLASHES=False, DRYING_EDGES=False, WET_FOLIAGE=False))
        check(close_to(probe.render(disabled_surface), (0., 0., 0., 1.)), "Disabled surface effects still changed output")
        disabled_shore = helper("shore.glsl", """
in vec2 uv;
layout(location=0) out vec4 color;
void main(){color=atrShoreWater(vec4(0.2,0.3,0.4,0.5),0.05,uv*8.0,1.0,vec3(1));}
""", dict(SHORE_DETAIL=False))
        check(close_to(probe.render(disabled_shore), (.2, .3, .4, .5)), "Disabled shore effect changed output")

        # Debug colours bypass all atmospheric/final post effects. Compile all
        # five modes in the main matrix; here test exact final colour retention.
        debug = probe.program(prepare(shaders / "final.fsh", dict(lens_options, WEATHER_DEBUG="2")), "debug final bypass")
        check(close_to(probe.render(debug, textures=lens_input), (.2, .3, .4, 1.)), "Debug colours were altered by post processing")
        debug_masks = helper("debug.glsl", """
in vec2 uv;
layout(location=0) out vec4 color;
void main(){color=vec4(atrPoolingDebug(uv.x<0.5?0.55:1.40),1);}
""")
        palette = probe.render(debug_masks)
        check(palette[0] > palette[2] and palette[-2] > palette[-4], "Pooling debug drain/collection colours reversed")

        # Run the terrain diagnostic outputs themselves, including dry terrain.
        terrain_vertex = """#version 330 compatibility
out vec2 vUV; out vec2 vLightUV; out vec2 vBlockUV; out vec4 vTint;
out vec3 vWorldNormal; out vec3 vWorldPos; out vec3 vCameraRelative; out vec3 vViewPos;
flat out int vMaterial;
uniform int fixtureMaterial; uniform float fixtureSkylight;
void main(){gl_Position=gl_Vertex; vUV=gl_Vertex.xy*0.5+0.5; vBlockUV=vUV;
vLightUV=vec2(1,fixtureSkylight); vTint=vec4(1); vWorldNormal=vec3(0,1,0);
vWorldPos=vec3(vUV.x*2,64,vUV.y*2); vCameraRelative=vec3(vUV.x*2,0,vUV.y*2-4);
vViewPos=vec3(gl_Vertex.xy,-4); vMaterial=fixtureMaterial;}
"""
        terrain_inputs = dict(gtexture=base, lightmap=full_light)
        terrain_uniforms = dict(fixtureMaterial=100, fixtureSkylight=1.0)
        for mode, expected in ((1, (.05, .75, .20, 1.)), (3, (.18, .18, .18, 1.)), (4, (.55, .60, .65, 1.))):
            terrain = probe.program(prepare(shaders / "gbuffers_terrain.fsh", dict(options, WEATHER_DEBUG=str(mode))),
                                    f"terrain debug {mode}", terrain_vertex)
            check(close_to(probe.render(terrain, dict(terrain_uniforms, wetness=0.0), terrain_inputs), expected),
                  f"Terrain debug mode {mode} is wrong or lost on dry ground")
        terrain = probe.program(prepare(shaders / "gbuffers_terrain.fsh", options), "terrain clear and sheltered", terrain_vertex)
        for uniforms in (dict(terrain_uniforms, wetness=0.0), dict(terrain_uniforms, fixtureSkylight=0.0)):
            check(close_to(probe.render(terrain, uniforms, terrain_inputs), (.2, .3, .4, 1.)),
                  "Terrain weather effects changed dry or fully sheltered ground")

        print(f"GPU weather-detail fixtures passed: {passed} checks covering surface details, biome response, entities, curtains, shafts, lens and debug.")
    finally:
        probe.close()
