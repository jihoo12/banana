#!/usr/bin/env python3
"""Render through a private headless Wayland compositor and check the framebuffer."""
import os
from pathlib import Path
import subprocess
import struct
import sys
import tempfile
import time
import zlib

ROOT = Path(__file__).resolve().parent.parent


def write_png(path, width, height, pixels):
    def chunk(kind, payload):
        return (struct.pack(">I", len(payload)) + kind + payload +
                struct.pack(">I", zlib.crc32(kind + payload)))
    rows = b"".join(b"\0" + pixels[y * width * 3:(y + 1) * width * 3]
                    for y in range(height))
    path.write_bytes(b"\x89PNG\r\n\x1a\n" +
                     chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)) +
                     chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b""))


class Frame:
    def __init__(self, path):
        data = path.read_bytes()
        magic, dimensions, maximum, pixels = data.split(b"\n", 3)
        self.width, self.height = map(int, dimensions.split())
        assert magic == b"P6" and maximum == b"255"
        assert len(pixels) == self.width * self.height * 3
        self.pixels = pixels
        self.colors = {pixels[i:i + 3] for i in range(0, len(pixels), 3)}

    def at(self, x, y):
        i = (y * self.width + x) * 3
        return tuple(self.pixels[i:i + 3])

    def has(self, rgb):
        return bytes.fromhex(rgb) in self.colors


def near(color, rgb, tolerance):
    target = bytes.fromhex(rgb)
    return all(abs(a - b) <= tolerance for a, b in zip(color, target))


def render(env, name, *args):
    output = ROOT / "build" / f"smoke-{name}.ppm"
    subprocess.run([str(ROOT / "build" / "banana"), "--smoke-test", str(output), *args],
                   env=env, check=True, timeout=30)
    frame = Frame(output)
    write_png(output.with_suffix(".png"), frame.width, frame.height, frame.pixels)
    return frame


def main():
    with tempfile.TemporaryDirectory(prefix="banana-wayland-") as runtime:
        env = dict(os.environ, XDG_RUNTIME_DIR=runtime, WAYLAND_DISPLAY="banana-test",
                   LIBGL_ALWAYS_SOFTWARE="1")
        with open(Path(runtime) / "weston.log", "w+") as log:
            compositor = subprocess.Popen([
                "weston", "--backend=headless", "--renderer=gl", "--width=1100",
                "--height=750", "--socket=banana-test", "--idle-time=0",
                "--shell=kiosk-shell.so", "--no-config", "--fake-seat",
            ], env=env, stdout=log, stderr=log)
            try:
                for _ in range(200):
                    if compositor.poll() is not None:
                        log.seek(0)
                        raise RuntimeError("Weston failed:\n" + log.read())
                    if (Path(runtime) / "banana-test").exists():
                        break
                    time.sleep(0.05)
                else:
                    raise RuntimeError("Wayland socket did not appear")
                if len(sys.argv) > 1:
                    # tools/smoke.py NAME ARGS...: render one frame for a look.
                    frame = render(env, sys.argv[1], *sys.argv[2:])
                    print(f"build/smoke-{sys.argv[1]}.png: {frame.width}x{frame.height}")
                    return

                flat = render(env, "flat", "--set", "gradient=false")
                assert len(flat.colors) > 100, f"Expected antialiased colored text, got {len(flat.colors)} colors"
                for x, y in ((0, 0), (flat.width - 1, 0), (0, flat.height - 1), (flat.width - 1, flat.height - 1)):
                    assert near(flat.at(x, y), "161a23", 1), "Drawable has not resized to the framebuffer"
                assert flat.has("f07a8a"), "Missing ANSI red text"
                assert flat.has("34405a"), "Missing mouse selection highlight"
                assert flat.has("f6d365"), "Missing cursor"

                styled = render(env, "default")
                top, bottom = styled.at(styled.width // 2, 2), styled.at(styled.width // 2, styled.height - 3)
                assert near(top, "161a23", 3), f"Gradient should start at the theme background, got {top}"
                assert sum(bottom) < sum(top), "Gradient should darken toward the bottom"
                assert sum(styled.at(0, styled.height - 1)) <= sum(bottom), "Vignette should darken the corners"

                themed = render(env, "light", "--theme", "banana-light", "--set", "gradient=false")
                assert near(themed.at(0, 0), "fbf7ec", 1), "Theme background"
                assert themed.has("c8414f"), "Theme palette red"

                crt = render(env, "crt", "--shader", "crt")
                assert crt.at(0, 0) == (0, 0, 0), "CRT shader should mask the tube corners"
                assert len(crt.colors) > 1000, "CRT shader output"

                plugins = render(env, "plugins", "--plugin", "clock", "--plugin", "activity")
                bar = [plugins.at(x, plugins.height - 12) for x in range(plugins.width)]
                assert any(near(c, "f6d365", 2) for c in bar), "Status bar title pill"
                assert any(near(c, "1d222d", 2) for c in bar), "Status bar background"
                print(f"wayland/OpenGL: {flat.width}x{flat.height}, {len(styled.colors)} colors, "
                      "themes, gradient, shader chain and plugins rendered")
                print("Frames saved to build/smoke-*.png")
            finally:
                compositor.terminate()
                try:
                    compositor.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    compositor.kill()
                    compositor.wait()


if __name__ == "__main__":
    main()
