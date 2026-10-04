"""Fetch the pinned official Roblox type definitions without disabling TLS."""
import hashlib
import pathlib
import urllib.request

root = pathlib.Path(__file__).resolve().parent.parent
path = root / "globalTypes.d.luau"
url = "https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/1.69.0/scripts/globalTypes.d.luau"
expected = "7db9cd4fe55a4d26f3f7d5a39b6279a376f95a6c055c71d5591c26a1d525aaf2"
if path.exists():
    data = path.read_bytes()
else:
    with urllib.request.urlopen(url, timeout=90) as response:
        data = response.read()
if hashlib.sha256(data).hexdigest() != expected:
    raise SystemExit("Roblox definitions checksum mismatch; preserve and investigate")
if not path.exists():
    path.write_bytes(data)
print("Pinned Roblox definitions verified")
