#!/usr/bin/env python3
"""Render through a private headless Wayland compositor and check the framebuffer."""
import os
from pathlib import Path
import subprocess
import struct
import tempfile
import time
import zlib


def write_png(path, width, height, pixels):
    def chunk(kind, payload):
        return (struct.pack(">I", len(payload)) + kind + payload +
                struct.pack(">I", zlib.crc32(kind + payload)))
    rows = b"".join(b"\0" + pixels[y * width * 3:(y + 1) * width * 3]
                    for y in range(height))
    path.write_bytes(b"\x89PNG\r\n\x1a\n" +
                     chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)) +
                     chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b""))


def main():
    root = Path(__file__).resolve().parent.parent
    output = root / "build" / "smoke.ppm"
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
                subprocess.run([str(root / "build" / "banana"), "--smoke-test", str(output)],
                               env=env, check=True, timeout=20)
                data = output.read_bytes()
                magic, dimensions, maximum, pixels = data.split(b"\n", 3)
                width, height = map(int, dimensions.split())
                assert magic == b"P6" and maximum == b"255"
                assert len(pixels) == width * height * 3
                colors = {pixels[i:i + 3] for i in range(0, len(pixels), 3)}
                assert len(colors) > 100, f"Expected antialiased colored text, got {len(colors)} colors"
                assert bytes.fromhex("10151d") in colors, "Missing terminal background"
                for offset in (0, (width - 1) * 3, (height - 1) * width * 3, len(pixels) - 3):
                    assert pixels[offset:offset + 3] == bytes.fromhex("10151d"), "Drawable has not resized to the framebuffer"
                assert bytes.fromhex("ef7181") in colors, "Missing ANSI red text"
                write_png(output.with_suffix(".png"), width, height, pixels)
                print(f"wayland/OpenGL: {width}x{height}, {len(colors)} colors, PTY demo rendered")
                print(f"Frame saved to {output.with_suffix('.png')}")
            finally:
                compositor.terminate()
                try:
                    compositor.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    compositor.kill()
                    compositor.wait()


if __name__ == "__main__":
    main()
