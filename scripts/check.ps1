$ErrorActionPreference = "Stop"
Push-Location (Join-Path $PSScriptRoot "..")
try {
    New-Item -ItemType Directory -Force build | Out-Null
    python scripts/prepare.py
    if ($LASTEXITCODE -ne 0) { throw "Definition verification failed" }
    stylua --check src tests tools/BuildPlace.luau
    if ($LASTEXITCODE -ne 0) { throw "Formatting failed" }
    rojo sourcemap default.project.json --output sourcemap.json
    if ($LASTEXITCODE -ne 0) { throw "Sourcemap failed" }
    luau-lsp analyze --sourcemap=sourcemap.json --definitions=globalTypes.d.luau src
    if ($LASTEXITCODE -ne 0) { throw "Luau analysis failed" }
    rojo build default.project.json --output build/code.rbxlx
    if ($LASTEXITCODE -ne 0) { throw "Rojo build failed" }
    lune run tests/Recovery.spec.luau
    if ($LASTEXITCODE -ne 0) { throw "Recovery tests failed" }
    lune run tools/BuildPlace.luau
    if ($LASTEXITCODE -ne 0) { throw "Full place build failed" }
} finally {
    Pop-Location
}
