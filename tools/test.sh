#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
jihoo run -I src tests/core.jh
jihoo run -I src tests/selection.jh
jihoo run -I src tests/session.jh -lutil
