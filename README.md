# Banana

A native Linux **Wayland + OpenGL 3.3** terminal written in
[jihoo](https://github.com/jihoolang/jihoo). The window uses GLFW's Wayland
backend and an EGL OpenGL context. Shell processes run in a real Linux PTY.

The terminal parser, cell grid, UTF-8 decoder, input encoding, PTY management,
OpenGL shaders, glyph atlas, themes, post-processing pipeline, plugin host, and
event loop are jihoo code. A small C adapter exposes FreeType glyph bitmaps and
fontconfig font matching.

Banana aims to be a good-looking terminal: a gradient background with a soft
vignette, a rounded cursor that glides and glows, rounded selections, real bold
and italic faces, six built-in themes, Shadertoy-style post-processing shaders
such as a CRT tube or bloom, and a status bar that plugins fill in.

## Development

Install Nix with flakes enabled, then run from an existing Wayland session:

```sh
nix develop
bash run.sh
```

The flake provides the pinned jihoo 0.3.0 compiler, Clang, GLFW, OpenGL development
libraries, FreeType, fontconfig, ncurses, JetBrains Mono, DejaVu fonts, Noto CJK
fonts, Nerd Font symbols, Python, and Weston. `flake.lock` pins the compiler to revision
`722d2e274d1eb03a5547991f7da1ec241b6427a9`, matching the sibling `../jihoo`
checkout used for this update. The compiler package includes its matching
standard library; re-enter `nix develop` after updating the lock file.

The development shell sets `$SHELL` to Bash with Readline support so Banana's
default shell supports line editing and colored prompts. Nix's build-time Bash
lacks Readline and prints the prompt's `\[` and `\]` markers literally. Re-enter
`nix develop` after changing the flake to apply this setting.

To develop against changes in that local checkout without updating the lock:

```sh
nix develop --override-input jihoo "path:$(realpath ../jihoo)" --no-write-lock-file
bash run.sh
```

Build and run separately:

```sh
nix develop --command bash tools/build.sh
./build/banana
./build/banana --font-size 20 --theme matcha
./build/banana --shader crt --plugin clock
./build/banana --font "DejaVu Sans Mono" -e bash --noprofile --norc
./build/banana -- sh -c 'printf "hello from jihoo\\n"; exec sh'
```

`$SHELL` selects the default shell; otherwise Banana starts `sh` from `PATH`.
The child inherits the working directory and environment. Closing the window
closes the PTY and hangs up the shell; exiting the shell closes the window.
Banana returns the child's exit status when the child exits normally.

`WAYLAND_DISPLAY` and `XDG_RUNTIME_DIR` must identify a reachable Wayland
compositor. Banana explicitly requests Wayland and does not fall back to X11.
The host must supply a working OpenGL/EGL driver. On NixOS, enable
`hardware.graphics.enable`. On other distributions, Nix graphics applications
may need the host's usual driver integration (for example, nixGL).

## Nix package

```sh
nix build
./result/bin/banana
# Or build and launch:
nix run
```

When trying uncommitted files before adding them to Git, use `nix build path:.`
or `nix develop path:.`: Git flakes only include tracked files.

The build compiles a dedicated `banana` terminfo entry. Development binaries
find `build/terminfo` beside the executable; the installed wrapper sets
`TERMINFO` to the packaged database. Children receive `TERM=banana` and
`COLORTERM=truecolor`. Copy the terminfo entry to remote hosts before using
interactive terminal applications over SSH, for example:

```sh
infocmp -x -A build/terminfo banana | ssh HOST 'tic -x -'
```

## Configuration

Banana reads `~/.config/banana/banana.conf` (or `$XDG_CONFIG_HOME/banana/`),
then the command line. [`banana.conf.example`](banana.conf.example) lists every
setting; copy it to get started. `--config PATH` reads another file,
`--no-config` skips it, and `--set key=value` overrides any setting, as do the
shortcuts `--theme`, `--shader`, `--plugin`, `--font`, `--font-size` and
`--opacity`. Settings cover the font, line height and padding, theme and
individual colors, gradient and vignette, window opacity, cursor style, blink,
glow and trail, the visual bell, the status bar, shaders and plugins.

Themes: `banana` (default), `midnight`, `matcha`, `ember`, `glacier` and
`banana-light`. ANSI colors in the grid refer to the theme, so switching themes
with Ctrl+Shift+T recolors what is already on screen.

## Shaders

Post-processing shaders run on the rendered terminal, using the Shadertoy
`mainImage` convention plus terminal inputs such as the cursor rectangle and the
theme colors. Several shaders chain in order. Bundled: `crt`, `bloom`, `amber`,
`aurora` and `pulse`; see [`shaders/README.md`](shaders/README.md) for the
inputs and for writing your own. Files in `~/.config/banana/shaders/` take
precedence, and an edited shader reloads while Banana runs; if it fails to
compile, the error is printed and the previous version keeps running.

## Plugins

Plugins are shared libraries loaded at startup, with a C ABI described in
[`include/banana_plugin.h`](include/banana_plugin.h). A plugin can watch shell
output and key presses, run on a timer, write to the shell, print into the
terminal, show a segment in the status bar, and set `iParam[0..7]` for shaders.
Calls a plugin makes are queued and applied after it returns, so plugins never
touch the terminal while Banana uses it.

Two examples are bundled and built into `build/plugins/`:

- [`plugins/clock.c`](plugins/clock.c), in C: a status bar clock; its
  argument is a `strftime` format (`plugin = clock %a %H:%M`).
- [`plugins/activity.jh`](plugins/activity.jh), in jihoo: shows how fast the
  shell prints and drives the `pulse` shader with the level.

Build your own with `cc -shared -fPIC -I include my.c -o my.so`, or from jihoo
with `jihoo emit-obj --lib my.jh -o my.o && cc -shared my.o -o my.so`, then put
it in `~/.config/banana/plugins/` or name its path.

## Features and keys

- Native Wayland window, EGL context, OpenGL 3.3 core shaders and batched glyphs.
- Signed-distance shapes for rounded cursors, selections and status bar pills;
  a dithered gradient background; optional window transparency.
- Fontconfig fallback, including Korean, Japanese, and Chinese glyphs; real
  bold and italic faces, synthesized when a font lacks them.
- Incremental UTF-8 decoding and basic double-width CJK cells.
- ANSI 16/256 colors, RGB colors, bold, dim, italic, underline, strikethrough,
  hidden, and inverse video. Cursor shapes (block, underline, bar) via DECSCUSR.
- Cursor movement, erasing, insert/delete characters and lines, scroll regions,
  alternate screens, application cursor keys, and bracketed paste.
- Window title updates, cursor reports, PTY resize notifications, a cursor that
  glides between cells, fades as it blinks and becomes a hollow outline when
  the window loses focus, and a visual bell. Font sizing follows the
  compositor's reported content scale.
- Up to 2,000 lines of scrollback. Use the wheel or Shift+PageUp/PageDown;
  typing returns to the live screen.
- Left-drag to select text; Ctrl+Shift+C or Ctrl+Insert copies the selection
  to the clipboard. Scroll while dragging to extend into scrollback. Selection
  supports wide Unicode characters and joins automatically wrapped lines.
  A click clears the selection, as do typing, resizing, or switching screens.
- Ctrl+Shift+V or Shift+Insert pastes the clipboard. Ctrl+C, Ctrl+D, arrows,
  Home/End, Delete/Insert, and F1–F12 are sent to the child.
- Ctrl+Shift+T cycles themes, Ctrl+Shift+S cycles bundled shaders,
  Ctrl+Shift+R reloads shaders, and Ctrl+Shift+= / Ctrl+Shift+- / Ctrl+Shift+0
  change or reset the font size. A toast names each change.

## Verification

```sh
nix develop --command jihoo check src/main.jh
nix develop --command bash tools/test.sh
nix flake check
```

The test script first checks the complete application, including the window
and renderer, with jihoo's type, ownership, and borrow checker. Runtime tests
cover streaming and malformed UTF-8, ANSI operations, Hangul cell widths,
alternate screens and resizing, scroll regions, bounded history, input and
paste encoding, mouse selection and copying across Unicode and scrollback,
scaled mouse coordinates, randomized parser input, text attributes, cursor
shapes, the bell, theme color resolution, and configuration parsing. PTY integration tests check real
TTY descriptors, shell input/output, resize delivery, exit status, and 256 KiB
of queued nonblocking writes.

The graphical smoke test creates its own headless Wayland compositor, renders
real PTY output with software OpenGL, reads back the framebuffer, and checks
colored antialiased text, selection highlighting, the cursor, the gradient and
vignette, a second theme, the CRT shader, and the status bar filled by both
bundled plugins. It does not use the desktop's display socket:

```sh
nix develop --command python3 tools/smoke.py
nix develop --command python3 tools/smoke.py NAME [BANANA-OPTIONS...]  # one frame
```

The build must already exist. Captured frames are `build/smoke-*.png`.
This graphical check runs separately from `nix flake check` because it needs
a usable EGL driver and a Wayland compositor process.

## Current scope

This is an initial terminal implementation, not a complete xterm replacement.
It does not yet implement mouse reporting to applications,
search, tabs, configurable key bindings, or full VT conformance. Basic Unicode
scalar output works; combining marks are ignored, grapheme clustering and emoji
shaping are not implemented, and wide-character editing is still limited.
Color emoji are not drawn: the glyph atlas holds coverage only. Plugins run in
Banana's process with its privileges, so load only plugins you trust.
GLFW's Wayland input path does not provide an IME composition UI here, so Korean
output and clipboard input work, but Korean IME composition is not supported.
The glyph atlas is bounded; once full, new glyphs use a replacement glyph.
Resize preserves overlapping cells without reflowing wrapped lines.

## Layout

| Path | Purpose |
| --- | --- |
| `src/main.jh` | Wayland window, callbacks, command line, event loop |
| `src/config.jh` | Configuration file, settings, resource search paths |
| `src/theme.jh` | Built-in themes and color resolution |
| `src/plugin.jh` | Plugin loading and the host side of the plugin ABI |
| `src/terminal.jh` | Streaming escape parser, cell grid, scrollback |
| `src/renderer.jh` | OpenGL shaders, glyph atlas, shapes, status bar, post-processing |
| `src/pty.jh` | PTY lifecycle, nonblocking reads/writes, resize |
| `src/input.jh` | Key, UTF-8, and paste encoding |
| `src/api.jh` | C ABI declarations |
| `native/font.c` | FreeType/fontconfig adapter |
| `include/banana_plugin.h` | Plugin C ABI |
| `plugins/` | Example plugins in C and jihoo |
| `shaders/` | Bundled post-processing shaders |
| `banana.conf.example` | Every configuration setting |
| `banana.terminfo` | Terminal capabilities advertised to applications |
| `tools/` | Build, test, and graphical smoke scripts |
