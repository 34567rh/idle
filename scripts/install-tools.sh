#!/usr/bin/env bash
set -euo pipefail
python3 - <<'PYTHON'
import hashlib, json, os, pathlib, platform, subprocess, urllib.request, zipfile
if platform.system() != 'Linux' or platform.machine() != 'x86_64':
    raise SystemExit('These pinned binaries require Linux x86_64')
root = pathlib.Path('/workspace/roblox-tools')
(root / 'bin').mkdir(parents=True, exist_ok=True)
(root / 'downloads').mkdir(exist_ok=True)
releases = [{'name': 'rojo', 'version': '7.7.1', 'url': 'https://github.com/rojo-rbx/rojo/releases/download/v7.7.1/rojo-7.7.1-linux-x86_64.zip', 'sha256': '00feb4fa0829a1dd72b49df2639da519a352bfe13cadcd83969e2ba2bb5693c4'}, {'name': 'wally', 'version': '0.3.2', 'url': 'https://github.com/UpliftGames/wally/releases/download/v0.3.2/wally-v0.3.2-linux.zip', 'sha256': '21fdbb53dfee397fd21ca7fdd208db65cff0f87f0fd045cdb594b951981bd73f'}, {'name': 'stylua', 'version': '2.5.2', 'url': 'https://github.com/JohnnyMorganz/StyLua/releases/download/v2.5.2/stylua-linux-x86_64.zip', 'sha256': 'bcb0d855e91f102f28a370e850f8566b3b44b79e6274d806ea5246837c0fd5ab'}, {'name': 'selene', 'version': '0.32.0', 'url': 'https://github.com/Kampfkarren/selene/releases/download/0.32.0/selene-0.32.0-linux.zip', 'sha256': 'd3773393578580074386e69337d35b7acddfbaa9fc38964c07fa3e28436ade9b'}, {'name': 'lune', 'version': '0.10.5', 'url': 'https://github.com/lune-org/lune/releases/download/v0.10.5/lune-0.10.5-linux-x86_64.zip', 'sha256': '1fb5dee6a1afa1d300092805c6e660fe06144d29dd68c45cf6956f040667f791'}, {'name': 'luau-lsp', 'version': '1.69.0', 'url': 'https://github.com/JohnnyMorganz/luau-lsp/releases/download/1.69.0/luau-lsp-linux-x86_64.zip', 'sha256': '4457aeb690d3c22e04567f38c6259ac259a1673ec022758b9cb81af2a0e66c41'}]
for release in releases:
    name = release['name']
    archive_path = root / 'downloads' / (name + '.zip')
    if archive_path.exists():
        data = archive_path.read_bytes()
        if hashlib.sha256(data).hexdigest() != release['sha256']:
            raise SystemExit('Cached archive checksum mismatch: ' + name)
    else:
        request = urllib.request.Request(release['url'], headers={'User-Agent': 'cloud-roblox-setup'})
        with urllib.request.urlopen(request, timeout=90) as response:
            data = response.read()
        if hashlib.sha256(data).hexdigest() != release['sha256']:
            raise SystemExit('Download checksum mismatch: ' + name)
        archive_path.write_bytes(data)
    with zipfile.ZipFile(archive_path) as archive:
        binary = archive.read(name)
    target = root / 'bin' / name
    if target.exists() and target.read_bytes() != binary:
        raise SystemExit('Existing tool differs from the pinned binary: ' + str(target))
    if not target.exists():
        target.write_bytes(binary)
    target.chmod(0o755)
    subprocess.run([str(target), '--version'], check=True)
activation = 'export PATH="/workspace/roblox-tools/bin:$PATH"\nexport XDG_CACHE_HOME="/workspace/roblox-tools/cache"\n'
activation_path = root / 'activate.sh'
if activation_path.exists() and activation_path.read_text() not in (activation, 'export PATH="/workspace/roblox-tools/bin:$PATH"\n'):
    raise SystemExit('Existing activation file differs; preserve and review it')
activation_path.write_text(activation)
(root / 'releases.json').write_text(json.dumps(releases, indent=2) + '\n')
PYTHON
# Wally 0.3.2's embedded Git client does not use this cloud's HTTP proxy.
# Refresh its default registry cache with native authenticated Git, then let
# Wally read that index locally. Package downloads still use HTTPS normally.
python3 - <<'PYTHON'
import pathlib, subprocess
cache = pathlib.Path('/workspace/roblox-tools/cache/wally/index/github.com-1ea56f4ad487f695')
url = 'https://github.com/UpliftGames/wally-index'
def git(*args):
    return subprocess.run(['git', '-C', str(cache), *args], check=True)
if not cache.exists():
    cache.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(['git', 'clone', '--depth', '1', url, str(cache)], check=True)
else:
    inside = subprocess.run(['git', '-C', str(cache), 'rev-parse', '--is-inside-work-tree'], capture_output=True, text=True)
    if inside.returncode or inside.stdout.strip() != 'true':
        raise SystemExit('Existing registry cache is not a Git checkout; preserve and inspect it')
    dirty = subprocess.run(['git', '-C', str(cache), 'status', '--porcelain'], check=True, capture_output=True, text=True)
    if dirty.stdout:
        raise SystemExit('Existing registry cache has local changes; preserve and inspect it')
    git('fetch', '--depth', '1', url, 'main')
    git('checkout', '-B', 'main', 'FETCH_HEAD')
git('remote', 'set-url', 'origin', cache.as_uri())
print('Default Wally registry cache refreshed through native Git')
PYTHON
