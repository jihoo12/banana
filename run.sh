#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
bash tools/build.sh
export TERMINFO="$PWD/build/terminfo"
exec ./build/banana "$@"
