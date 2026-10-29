# Banana shaders

Post-processing shaders run after Banana draws the terminal. They use the
[Shadertoy](https://www.shadertoy.com/howto) convention: a file defines

```glsl
void mainImage(out vec4 fragColor, in vec2 fragCoord)
```

and Banana adds `#version 330 core` and these inputs:

| uniform | |
| --- | --- |
| `sampler2D iChannel0` | the terminal (or the previous shader's output), premultiplied alpha |
| `vec3 iResolution` | the framebuffer size in pixels |
| `float iTime`, `float iTimeDelta`, `int iFrame` | seconds since start, since the last frame; frame number |
| `vec4 iMouse` | the pointer in pixels, origin at the bottom left |
| `vec4 iCursor` | the text cursor: x, y (bottom left), width, height in pixels; height 0 when hidden |
| `vec3 iCursorColor`, `iBackground`, `iForeground`, `iAccent` | colors of the current theme |
| `float iOpacity` | the configured window opacity |
| `float iParam[8]` | values set by plugins (`host->set_param`) |

The alpha you return becomes the window's opacity; return `texture(iChannel0, uv).a`
to keep it. A shader that mentions `iTime` is redrawn every frame; others only
when the terminal changes.

Use shaders with `shader = NAME` in `~/.config/banana/banana.conf` (several
lines chain them in order), `--shader NAME`, or press Ctrl+Shift+S to cycle
through the bundled ones. `NAME` may also be a path. Banana looks for
`NAME.glsl` in `~/.config/banana/shaders/` first, so a file there overrides a
bundled shader. Saving a shader file reloads it; compile errors are printed and
the previous version stays active.

| shader | |
| --- | --- |
| `crt` | curved tube, scanlines, aperture grille, glow |
| `bloom` | bright text glows |
| `amber` | monochrome amber phosphor |
| `aurora` | animated light behind the text |
| `pulse` | edge glow driven by the `activity` plugin |
