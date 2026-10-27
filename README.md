# Banana

A native Linux **Wayland + OpenGL 3.3** terminal written in
[jihoo](https://github.com/jihoolang/jihoo). The window uses GLFW's Wayland
backend and an EGL OpenGL context. Shell processes run in a real Linux PTY.

The terminal parser, cell grid, UTF-8 decoder, input encoding, PTY management,
OpenGL shaders, glyph atlas, and event loop are jihoo code. A small C adapter
exposes FreeType glyph bitmaps and fontconfig font matching.

## Development

Install Nix with flakes enabled, then run from an existing Wayland session:

```sh
nix develop
bash run.sh
```

The flake provides the pinned jihoo compiler, Clang, GLFW, OpenGL development
libraries, FreeType, fontconfig, ncurses, DejaVu fonts, Noto CJK fonts, Python,
and Weston. `flake.lock` pins the compiler to the same revision as the sibling
`../jihoo` checkout used to develop this project.

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
./build/banana --font-size 20
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

## Features and keys

- Native Wayland window, EGL context, OpenGL 3.3 core shaders and batched glyphs.
- Fontconfig fallback, including Korean, Japanese, and Chinese glyphs.
- Incremental UTF-8 decoding and basic double-width CJK cells.
- ANSI 16/256 colors, RGB colors, bold, underline, and inverse video.
- Cursor movement, erasing, insert/delete characters and lines, scroll regions,
  alternate screens, application cursor keys, and bracketed paste.
- Window title updates, cursor reports, PTY resize notifications, and a blinking
  cursor. Font sizing follows the compositor's reported content scale.
- Up to 2,000 lines of scrollback. Use the wheel or Shift+PageUp/PageDown;
  typing returns to the live screen.
- Left-drag to select text; Ctrl+Shift+C or Ctrl+Insert copies the selection
  to the clipboard. Scroll while dragging to extend into scrollback. Selection
  supports wide Unicode characters and joins automatically wrapped lines.
  A click clears the selection, as do typing, resizing, or switching screens.
- Ctrl+Shift+V or Shift+Insert pastes the clipboard. Ctrl+C, Ctrl+D, arrows,
  Home/End, Delete/Insert, and F1–F12 are sent to the child.

## Verification

```sh
nix develop --command bash tools/test.sh
nix flake check
```

Tests cover streaming and malformed UTF-8, ANSI operations, Hangul cell widths,
alternate screens and resizing, scroll regions, bounded history, input and
paste encoding, mouse selection and copying across Unicode and scrollback,
scaled mouse coordinates, and randomized parser input. PTY integration tests check real
TTY descriptors, shell input/output, resize delivery, exit status, and 256 KiB
of queued nonblocking writes.

The graphical smoke test creates its own headless Wayland compositor, renders
real PTY output with software OpenGL, reads back the framebuffer, and checks
for colored antialiased text and selection highlighting. It does not use the
desktop's display socket:

```sh
nix develop --command python3 tools/smoke.py
```

The build must already exist. Captured frames are `build/smoke.ppm` and
`build/smoke.png`.
This graphical check runs separately from `nix flake check` because it needs
a usable EGL driver and a Wayland compositor process.

## Current scope

This is an initial terminal implementation, not a complete xterm replacement.
It does not yet implement mouse reporting to applications,
search, tabs, configurable key bindings, or full VT conformance. Basic Unicode
scalar output works; combining marks are ignored, grapheme clustering and emoji
shaping are not implemented, and wide-character editing is still limited.
GLFW's Wayland input path does not provide an IME composition UI here, so Korean
output and clipboard input work, but Korean IME composition is not supported.
The glyph atlas is bounded; once full, new glyphs use a replacement glyph.
Resize preserves overlapping cells without reflowing wrapped lines.

## Layout

| Path | Purpose |
| --- | --- |
| `src/main.jh` | Wayland window, callbacks, command line, event loop |
| `src/terminal.jh` | Streaming escape parser, cell grid, scrollback |
| `src/renderer.jh` | OpenGL shaders, glyph atlas, batched rendering |
| `src/pty.jh` | PTY lifecycle, nonblocking reads/writes, resize |
| `src/input.jh` | Key, UTF-8, and paste encoding |
| `src/api.jh` | C ABI declarations |
| `native/font.c` | FreeType/fontconfig adapter |
| `banana.terminfo` | Terminal capabilities advertised to applications |
| `tools/` | Build, test, and graphical smoke scripts |
