#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
tic -x -o build/terminfo banana.terminfo
read -r -a font_cflags <<< "$(pkg-config --cflags freetype2 fontconfig)"
read -r -a font_libs <<< "$(pkg-config --libs freetype2 fontconfig)"
read -r -a graphics_flags <<< "$(pkg-config --libs glfw3 gl)"
clang -std=c11 -Wall -Wextra -Werror "${font_cflags[@]}" -c native/font.c -o build/font.o
jihoo build -O2 src/main.jh build/font.o "${font_libs[@]}" "${graphics_flags[@]}" -lutil -o build/banana
