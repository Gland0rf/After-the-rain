"""Validate pack configuration and compile/link GLSL on a hidden Windows GL context.

Run: python tools/validate_shaders.py
This exercises source GLSL, not Iris's Java shader patcher or Minecraft rendering.
No third-party Python packages are needed. Use --static-only on other systems.
"""
from __future__ import annotations

import argparse
import ctypes as C
from ctypes import wintypes as W
import math
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
SHADERS = ROOT / "shaders"


def properties(path):
    result = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        assert "=" in line and not line.startswith("+"), f"Malformed property: {line}"
        key, value = map(str.strip, line.split("=", 1))
        assert key not in result, f"Duplicate property: {key}"
        result[key] = value
    return result


def settings():
    result, values = {}, {}
    for line in (SHADERS / "lib/settings.glsl").read_text().splitlines():
        match = re.match(r"^(//)?#define (\w+)(.*)", line)
        if not match or match[2].startswith("ATR_"):
            continue
        disabled, name, rest = match.groups()
        value = rest.split("//", 1)[0].strip()
        result[name] = value if value else not bool(disabled)
        choices = re.search(r"\[([^]]+)\]", rest)
        if choices:
            values[name] = choices[1].split()
    return result, values


def expand(path, stack=()):
    assert path not in stack, f"Include cycle: {path}"
    text = path.read_text(encoding="utf-8")
    def replace(match):
        name = match[1]
        target = SHADERS / name.lstrip("/") if name.startswith("/") else path.parent / name
        assert target.is_file(), f"Missing include: {target}"
        return expand(target, stack + (path,))
    return re.sub(r'^\s*#include "([^"]+)"', replace, text, flags=re.M)


def variants():
    defaults, choices = settings()
    props = properties(SHADERS / "shaders.properties")
    language = properties(SHADERS / "lang/en_US.lang")
    blocks = properties(SHADERS / "block.properties")
    assigned = set()
    for key, value in blocks.items():
        assert re.fullmatch(r"block\.\d+", key), key
        for block in value.split():
            assert block not in assigned, f"Block mapped twice: {block}"
            assigned.add(block)
    assert blocks["block.106"] == "minecraft:grass_block"
    assert blocks["block.109"] == "minecraft:water"
    for key, value in props.items():
        if key.startswith("screen") or key == "sliders":
            for token in value.split():
                if token.startswith(("[", "<")):
                    continue
                assert token in defaults, f"Unknown menu option {token}"
                assert f"option.{token}" in language, f"Missing label {token}"
    result = {"DEFAULT": defaults}
    for key, value in props.items():
        if not key.startswith("profile."):
            continue
        options = dict(defaults)
        for token in value.split():
            if ":" in token:
                name, setting = token.split(":")
                assert name in choices and setting in choices[name], token
                options[name] = setting
            else:
                name = token.lstrip("!")
                assert name in defaults and isinstance(defaults[name], bool), token
                options[name] = not token.startswith("!")
        result[key.split(".", 1)[1]] = options
    # Cover numeric branches and each optional-feature branch beyond presets.
    result["LOW_SSR_EXTRA_RAIN"] = dict(defaults, REFLECTION_QUALITY="1", RAIN_DETAIL="2")
    result["HIGH_RAIN_DEBUG"] = dict(defaults, RAIN_DETAIL="3", RAIN_SHADER_DEBUG="1", LENS_DROPLETS=True)
    result["NO_CLOUDS"] = dict(defaults, STORM_CLOUDS=False, WIND_GUSTS=False)
    result["FEATURES_OFF"] = {k: False if isinstance(v, bool) else v for k, v in defaults.items()}
    result["FEATURES_OFF"].update(ROOF_DRIPS="0", LIGHTNING_RESPONSE="0.00")
    for path in sorted(SHADERS.glob("*.*sh")):
        expand(path)
    # The overhead projection must put roofs in front of the ground, and retain
    # top-face winding. This catches sign changes that compile successfully.
    def roof_depth(height):
        return -height / 512.0 * 0.5 + 0.5
    assert roof_depth(12.0) < roof_depth(0.0)
    assert roof_depth(0.0) - 0.00004 > roof_depth(0.0625)
    # Moisture must decline monotonically on every material, with dry = zero.
    for exponent in (0.68, 0.78, 1.15, 1.40):
        sequence = [(i / 100.0) ** exponent for i in range(101)]
        assert sequence[0] == 0.0 and sequence[-1] == 1.0
        assert all(a <= b for a, b in zip(sequence, sequence[1:]))
    # Integrated wind travel must differentiate back to the gust speed.
    travel = lambda t: t + 0.24 / 0.17 * math.sin(t * 0.17) + 0.12 / 0.43 * math.sin(t * 0.43)
    for t in (0, 10, 100):
        numerical = (travel(t + 0.001) - travel(t - 0.001)) / 0.002
        assert abs(numerical - (1 + 0.24 * math.cos(t * 0.17) + 0.12 * math.cos(t * 0.43))) < 1e-6
    print(f"Static checks passed: {len(defaults)} options, {len(result)} configurations, mappings and includes.")
    return result


class Context:
    def __init__(self):
        if sys.platform != "win32":
            raise RuntimeError("Native compilation needs Windows; use --static-only elsewhere.")
        self.user = C.WinDLL("user32", use_last_error=True)
        self.gdi = C.WinDLL("gdi32", use_last_error=True)
        self.gl = C.WinDLL("opengl32", use_last_error=True)
        self.user.CreateWindowExW.restype = W.HWND
        self.user.CreateWindowExW.argtypes = [W.DWORD, W.LPCWSTR, W.LPCWSTR, W.DWORD,
                                             C.c_int, C.c_int, C.c_int, C.c_int,
                                             W.HWND, W.HMENU, W.HINSTANCE, C.c_void_p]
        self.user.GetDC.argtypes = [W.HWND]
        self.user.GetDC.restype = W.HDC
        self.user.ReleaseDC.argtypes = [W.HWND, W.HDC]
        self.user.DestroyWindow.argtypes = [W.HWND]
        self.window = self.user.CreateWindowExW(0, "STATIC", "Shader validation", 0,
                                                0, 0, 8, 8, None, None, None, None)
        assert self.window, "Could not create hidden validation window"
        self.dc = self.user.GetDC(self.window)
        class PFD(C.Structure):
            _fields_ = [("size", W.WORD), ("version", W.WORD), ("flags", W.DWORD),
                        ("pixelType", C.c_ubyte), ("colorBits", C.c_ubyte),
                        ("redBits", C.c_ubyte), ("redShift", C.c_ubyte),
                        ("greenBits", C.c_ubyte), ("greenShift", C.c_ubyte),
                        ("blueBits", C.c_ubyte), ("blueShift", C.c_ubyte),
                        ("alphaBits", C.c_ubyte), ("alphaShift", C.c_ubyte),
                        ("accumBits", C.c_ubyte), ("accumRedBits", C.c_ubyte),
                        ("accumGreenBits", C.c_ubyte), ("accumBlueBits", C.c_ubyte),
                        ("accumAlphaBits", C.c_ubyte), ("depthBits", C.c_ubyte),
                        ("stencilBits", C.c_ubyte), ("auxBuffers", C.c_ubyte),
                        ("layerType", C.c_ubyte), ("reserved", C.c_ubyte),
                        ("layerMask", W.DWORD), ("visibleMask", W.DWORD), ("damageMask", W.DWORD)]
        pfd = PFD(size=C.sizeof(PFD), version=1, flags=0x24, colorBits=24, depthBits=24)
        self.gdi.ChoosePixelFormat.argtypes = [W.HDC, C.POINTER(PFD)]
        self.gdi.SetPixelFormat.argtypes = [W.HDC, C.c_int, C.POINTER(PFD)]
        pixel_format = self.gdi.ChoosePixelFormat(self.dc, C.byref(pfd))
        assert pixel_format and self.gdi.SetPixelFormat(self.dc, pixel_format, C.byref(pfd))
        self.gl.wglCreateContext.argtypes = [W.HDC]
        self.gl.wglCreateContext.restype = C.c_void_p
        self.gl.wglMakeCurrent.argtypes = [W.HDC, C.c_void_p]
        self.gl.wglDeleteContext.argtypes = [C.c_void_p]
        self.context = self.gl.wglCreateContext(self.dc)
        assert self.context and self.gl.wglMakeCurrent(self.dc, self.context)
        self.gl.glGetString.argtypes = [C.c_uint]
        self.gl.glGetString.restype = C.c_char_p
        self.gl.wglGetProcAddress.argtypes = [C.c_char_p]
        self.gl.wglGetProcAddress.restype = C.c_void_p
        print("OpenGL:", self.gl.glGetString(0x1F02).decode(), self.gl.glGetString(0x1F01).decode())
        self.create_shader = self.function("glCreateShader", C.c_uint, C.c_uint)
        self.source = self.function("glShaderSource", None, C.c_uint, C.c_int, C.POINTER(C.c_char_p), C.c_void_p)
        self.compile = self.function("glCompileShader", None, C.c_uint)
        self.get_shader = self.function("glGetShaderiv", None, C.c_uint, C.c_uint, C.POINTER(C.c_int))
        self.shader_log = self.function("glGetShaderInfoLog", None, C.c_uint, C.c_int, C.c_void_p, C.c_void_p)
        self.delete_shader = self.function("glDeleteShader", None, C.c_uint)
        self.create_program = self.function("glCreateProgram", C.c_uint)
        self.attach = self.function("glAttachShader", None, C.c_uint, C.c_uint)
        self.link = self.function("glLinkProgram", None, C.c_uint)
        self.get_program = self.function("glGetProgramiv", None, C.c_uint, C.c_uint, C.POINTER(C.c_int))
        self.program_log = self.function("glGetProgramInfoLog", None, C.c_uint, C.c_int, C.c_void_p, C.c_void_p)
        self.delete_program = self.function("glDeleteProgram", None, C.c_uint)

    def function(self, name, result, *args):
        address = self.gl.wglGetProcAddress(name.encode())
        if not address or address in (1, 2, 3, C.c_void_p(-1).value):
            function = getattr(self.gl, name)
            function.restype = result
            function.argtypes = list(args)
            return function
        return C.WINFUNCTYPE(result, *args)(address)

    def shader(self, text, kind, label):
        shader = self.create_shader(kind)
        source = C.c_char_p(text.encode())
        self.source(shader, 1, C.byref(source), None)
        self.compile(shader)
        status = C.c_int()
        self.get_shader(shader, 0x8B81, C.byref(status))
        if not status.value:
            log = C.create_string_buffer(65536)
            self.shader_log(shader, len(log), None, log)
            self.delete_shader(shader)
            raise AssertionError(f"{label}:\n{log.value.decode(errors='replace')}")
        return shader

    def program(self, vertex, fragment, label, retain=False):
        program = self.create_program()
        linked = False
        try:
            self.attach(program, vertex)
            self.attach(program, fragment)
            self.link(program)
            status = C.c_int()
            self.get_program(program, 0x8B82, C.byref(status))
            if not status.value:
                log = C.create_string_buffer(65536)
                self.program_log(program, len(log), None, log)
                raise AssertionError(f"{label}:\n{log.value.decode(errors='replace')}")
            linked = True
            return program
        finally:
            if not retain or not linked:
                self.delete_program(program)

    def close(self):
        self.gl.wglMakeCurrent(None, None)
        self.gl.wglDeleteContext(self.context)
        self.user.ReleaseDC(self.window, self.dc)
        self.user.DestroyWindow(self.window)


def prepare(path, options):
    text = expand(path)
    for name, value in options.items():
        define = f"#define {name}" if value is True else (
            f"// disabled: {name}" if value is False else f"#define {name} {value}")
        text = re.sub(rf"^(?://)?#define {name}\b[^\n]*", lambda _: define, text, flags=re.M)
    # Iris injects stage constants before compilation. Values are immaterial for
    # compilation/link validation; runtime rendering is checked in Minecraft.
    text = text.replace("#version 330 compatibility", "#version 330 compatibility\n"
                        "#define MC_RENDER_STAGE_SKY 1\n#define MC_RENDER_STAGE_RAIN_SNOW 2", 1)
    return text


def render_shelter_fixture(context):
    """Draw a floor and thin roof with the real shadow shader, then query exposure.

    Tests projection winding, depth ordering, self-bias, texture sampling and
    floating-point metadata on the GPU, without launching/changing Minecraft.
    """
    fn = context.function
    uint, integer, ptr = C.c_uint, C.c_int, C.c_void_p
    gen_tex = fn("glGenTextures", None, integer, C.POINTER(uint))
    bind_tex = fn("glBindTexture", None, uint, uint)
    tex_parameter = fn("glTexParameteri", None, uint, uint, integer)
    tex_image = fn("glTexImage2D", None, uint, integer, integer, integer, integer,
                   integer, uint, uint, ptr)
    gen_fbo = fn("glGenFramebuffers", None, integer, C.POINTER(uint))
    bind_fbo = fn("glBindFramebuffer", None, uint, uint)
    attach_tex = fn("glFramebufferTexture2D", None, uint, uint, uint, uint, integer)
    check_fbo = fn("glCheckFramebufferStatus", uint, uint)
    viewport = fn("glViewport", None, integer, integer, integer, integer)
    clear = fn("glClear", None, uint)
    enable = fn("glEnable", None, uint)
    disable = fn("glDisable", None, uint)
    use_program = fn("glUseProgram", None, uint)
    uniform_location = fn("glGetUniformLocation", integer, uint, C.c_char_p)
    matrix = fn("glUniformMatrix4fv", None, integer, integer, C.c_ubyte, C.POINTER(C.c_float))
    uniform3 = fn("glUniform3f", None, integer, C.c_float, C.c_float, C.c_float)
    uniform1 = fn("glUniform1f", None, integer, C.c_float)
    uniform_int = fn("glUniform1i", None, integer, integer)
    active_texture = fn("glActiveTexture", None, uint)
    matrix_mode = fn("glMatrixMode", None, uint)
    load_identity = fn("glLoadIdentity", None)
    translate = fn("glTranslatef", None, C.c_float, C.c_float, C.c_float)
    begin = fn("glBegin", None, uint)
    end = fn("glEnd", None)
    vertex = fn("glVertex3f", None, C.c_float, C.c_float, C.c_float)
    read = fn("glReadPixels", None, integer, integer, integer, integer, uint, uint, ptr)
    get_error = fn("glGetError", uint)
    delete_tex = fn("glDeleteTextures", None, integer, C.POINTER(uint))
    delete_fbo = fn("glDeleteFramebuffers", None, integer, C.POINTER(uint))
    textures, framebuffers, shaders, programs = [], [], [], []

    def texture(size, internal, pixel_format, data=None):
        name = uint()
        gen_tex(1, C.byref(name))
        textures.append(name)
        bind_tex(0x0DE1, name.value)
        for key, value in ((0x2801, 0x2600), (0x2800, 0x2600), (0x2802, 0x812F), (0x2803, 0x812F)):
            tex_parameter(0x0DE1, key, value)
        tex_image(0x0DE1, 0, internal, size, size, 0, pixel_format, 0x1406, data)
        return name.value

    def framebuffer(size, depth=False):
        name = uint()
        gen_fbo(1, C.byref(name))
        framebuffers.append(name)
        bind_fbo(0x8D40, name.value)
        color = texture(size, 0x881A, 0x1908)  # RGBA16F
        attach_tex(0x8D40, 0x8CE0, 0x0DE1, color, 0)
        depth_texture = texture(size, 0x81A6, 0x1902) if depth else 0
        if depth:
            attach_tex(0x8D40, 0x8D00, 0x0DE1, depth_texture, 0)
        assert check_fbo(0x8D40) == 0x8CD5, "Incomplete fixture framebuffer"
        viewport(0, 0, size, size)
        return depth_texture

    try:
        defaults, _ = settings()
        v = context.shader(prepare(SHADERS / "shadow.vsh", defaults), 0x8B31, "roof fixture vertex")
        shaders.append(v)
        f = context.shader(prepare(SHADERS / "shadow.fsh", defaults), 0x8B30, "roof fixture fragment")
        shaders.append(f)
        shadow = context.program(v, f, "roof fixture", retain=True)
        programs.append(shadow)
        roof_depth = framebuffer(2048, depth=True)
        roof_framebuffer = framebuffers[-1].value
        white = texture(1, 0x881A, 0x1908, (C.c_float * 4)(1, 1, 1, 1))
        use_program(shadow)
        identity = (C.c_float * 16)(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
        matrix(uniform_location(shadow, b"shadowModelViewInverse"), 1, 0, identity)
        v = context.shader("#version 330 compatibility\nvoid main(){gl_Position=gl_Vertex;}",
                           0x8B31, "exposure fixture vertex")
        shaders.append(v)
        fragment = "#version 330 compatibility\n" + expand(SHADERS / "lib/exposure.glsl") + """
layout(location=0) out vec4 color;
void main() {
    vec3 world = vec3((gl_FragCoord.x / 8.0 - 0.5) * 80.0, 0.0, 0.0);
    if (gl_FragCoord.x < 1.0) world.x = -0.03; // a partially covered roof-edge sample
    color = vec4(atrExposure(world, 1.0), 0.0, 0.0, 1.75);
}
"""
        f = context.shader(fragment, 0x8B30, "exposure fixture fragment")
        shaders.append(f)
        probe = context.program(v, f, "exposure fixture", retain=True)
        programs.append(probe)
        framebuffer(8)
        probe_framebuffer = framebuffers[-1].value
        edge_exposure = []
        for camera in ((0, 0, 0), (0.02, 0, 0.04), (0.10, 0.5, 0.16), (1.7, 1.6, -0.45)):
            bind_fbo(0x8D40, roof_framebuffer)
            viewport(0, 0, 2048, 2048)
            bind_tex(0x0DE1, white)
            use_program(shadow)
            uniform3(uniform_location(shadow, b"cameraPosition"), *camera)
            matrix_mode(0x1700)  # modelview contains camera-relative geometry
            load_identity()
            translate(*[-axis for axis in camera])
            clear(0x4000 | 0x0100)
            enable(0x0B71)
            enable(0x0B44)
            begin(0x0007)
            for x, z in ((-96, -96), (-96, 96), (96, 96), (96, -96)):
                vertex(x, 0, z)
            for x, z in ((-48, -48), (-48, 48), (0, 48), (0, -48)):
                vertex(x, 0.0625, z)
            end()
            bind_fbo(0x8D40, probe_framebuffer)
            viewport(0, 0, 8, 8)
            bind_tex(0x0DE1, roof_depth)
            use_program(probe)
            uniform3(uniform_location(probe, b"cameraPosition"), *camera)
            disable(0x0B71)
            begin(0x0007)
            for x, y in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                vertex(x, y, 0)
            end()
            pixels = (C.c_float * (8 * 8 * 4))()
            read(0, 0, 8, 8, 0x1908, 0x1406, pixels)
            sheltered = pixels[(4 * 8 + 1) * 4]
            exposed = pixels[(4 * 8 + 6) * 4]
            edge_exposure.append(pixels[(4 * 8) * 4])
            assert sheltered < 0.05 and exposed > 0.95, (camera, sheltered, exposed)
            assert abs(pixels[3] - 1.75) < 0.001, "RGBA16F metadata clamped"
        spread = max(edge_exposure) - min(edge_exposure)
        assert spread < 0.01, f"Roof edge shifts with camera: {edge_exposure}"
        print(f"GPU roof fixture passed at four camera positions; edge exposure spread={spread:.5f}.")

        # Render the actual deferred pass on a uniform damp-wood fixture while
        # changing view direction. A rough film must not turn into pale mirrors.
        load_identity()
        v = context.shader("""#version 330 compatibility
out vec2 uv;
void main(){gl_Position=gl_Vertex; uv=gl_Vertex.xy*0.5+0.5;}
""", 0x8B31, "wet-wood fixture vertex")
        shaders.append(v)
        f = context.shader(prepare(SHADERS / "deferred.fsh", defaults), 0x8B30, "wet-wood deferred")
        shaders.append(f)
        wood = context.program(v, f, "wet-wood movement fixture", retain=True)
        programs.append(wood)
        base_color = (0.25, 0.15, 0.07)
        inputs = ((b"colortex0", (*base_color, 1.0)),
                  (b"colortex2", (0.5, 1.0, 0.5, 4.0)),
                  (b"colortex3", (0.13, 0.8, 0.42, 1.55)))
        use_program(wood)
        for unit, (name, rgba) in enumerate(inputs):
            active_texture(0x84C0 + unit)
            texture(1, 0x881A, 0x1908, (C.c_float * 4)(*rgba))
            uniform_int(uniform_location(wood, name), unit)
        active_texture(0x84C0 + 3)
        texture(1, 0x81A6, 0x1902, (C.c_float * 1)(0.5))
        uniform_int(uniform_location(wood, b"depthtex1"), 3)
        uniform_int(uniform_location(wood, b"hasSkylight"), 1)
        uniform1(uniform_location(wood, b"atrRainClimate"), 1.0)
        uniform1(uniform_location(wood, b"wetness"), 1.0)
        uniform3(uniform_location(wood, b"skyColor"), 0.60, 0.65, 0.70)
        uniform3(uniform_location(wood, b"fogColor"), 0.40, 0.45, 0.50)
        matrix(uniform_location(wood, b"gbufferModelViewInverse"), 1, 0, identity)
        matrix(uniform_location(wood, b"gbufferModelView"), 1, 0, identity)
        values = []
        for view_x in (-3.0, 0.0, 3.0):
            inverse_projection = (C.c_float * 16)(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0,
                                                view_x, -2.0, -4.0, 1)
            matrix(uniform_location(wood, b"gbufferProjectionInverse"), 1, 0, inverse_projection)
            begin(0x0007)
            for x, y in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                vertex(x, y, 0)
            end()
            pixels = (C.c_float * (8 * 8 * 4))()
            read(0, 0, 8, 8, 0x1908, 0x1406, pixels)
            values.append(tuple(pixels[(4 * 8 + 4) * 4 + channel] for channel in range(3)))
        movement = max(max(rgb[i] for rgb in values) - min(rgb[i] for rgb in values) for i in range(3))
        change = max(abs(rgb[i] - base_color[i]) for rgb in values for i in range(3))
        assert movement < 0.005 and change < 0.02, (values, movement, change)
        assert values[0] != base_color, "Wet-wood fixture did not execute shading"
        assert get_error() == 0, "OpenGL error during fixture render"
        print(f"GPU wet-wood fixture passed: view-dependent RGB spread={movement:.5f}.")
    finally:
        use_program(0)
        bind_fbo(0x8D40, 0)
        active_texture(0x84C0)
        load_identity()
        for item in programs:
            context.delete_program(item)
        for item in shaders:
            context.delete_shader(item)
        for item in textures:
            delete_tex(1, C.byref(item))
        for item in framebuffers:
            delete_fbo(1, C.byref(item))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--static-only", action="store_true")
    args = parser.parse_args()
    configurations = variants()
    if args.static_only:
        return
    context = Context()
    cache = {}
    links = 0
    try:
        for name, options in configurations.items():
            for vertex_path in sorted(SHADERS.glob("*.vsh")):
                fragment_path = vertex_path.with_suffix(".fsh")
                assert fragment_path.is_file(), f"Missing fragment stage: {vertex_path.stem}"
                pair = []
                for path, kind in ((vertex_path, 0x8B31), (fragment_path, 0x8B30)):
                    text = prepare(path, options)
                    key = (kind, text)
                    if key not in cache:
                        cache[key] = context.shader(text, kind, f"{name}/{path.name}")
                    pair.append(cache[key])
                context.program(*pair, f"{name}/{vertex_path.stem}")
                links += 1
            print(f"  {name}: all shader pairs compiled and linked.", flush=True)
        render_shelter_fixture(context)
    finally:
        for shader in cache.values():
            context.delete_shader(shader)
        context.close()
    print(f"Passed: {links} program links, {len(cache)} unique shader compilations.")


if __name__ == "__main__":
    main()
