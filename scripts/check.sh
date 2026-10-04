#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -f /workspace/roblox-tools/activate.sh ]]; then
    source /workspace/roblox-tools/activate.sh
fi
mkdir -p build
python3 scripts/prepare.py
stylua --check src tests tools/BuildPlace.luau
rojo sourcemap default.project.json --output sourcemap.json
luau-lsp analyze --sourcemap=sourcemap.json --definitions=globalTypes.d.luau src
rojo build default.project.json --output build/code.rbxlx
lune run tests/Recovery.spec.luau
lune run tools/BuildPlace.luau
