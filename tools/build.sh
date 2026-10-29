#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/plugins
tic -x -o build/terminfo banana.terminfo
read -r -a font_cflags <<< "$(pkg-config --cflags freetype2 fontconfig)"
read -r -a font_libs <<< "$(pkg-config --libs freetype2 fontconfig)"
read -r -a graphics_flags <<< "$(pkg-config --libs glfw3 gl)"
clang -std=c11 -Wall -Wextra -Werror "${font_cflags[@]}" -c native/font.c -o build/font.o
jihoo build -O2 src/main.jh build/font.o "${font_libs[@]}" "${graphics_flags[@]}" -lutil -o build/banana
# Bundled shaders and plugins live beside the binary during development.
rm -rf build/shaders && cp -r shaders build/shaders
clang -std=c11 -Wall -Wextra -Werror -fPIC -shared -I include plugins/clock.c -o build/plugins/clock.so
jihoo emit-obj --lib -O2 plugins/activity.jh -o build/activity.o
clang -shared build/activity.o -o build/plugins/activity.so
