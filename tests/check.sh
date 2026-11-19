#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
bash -n install.sh
python3 - <<'PY'
import json
from pathlib import Path
for p in [Path('config.jsonc'), *Path('themes').glob('*.jsonc')]:
    c=json.loads(p.read_text())
    assert c['logo']['type']=='file'
    assert len([m for m in c['modules'] if m['type']=='custom'])==6
    assert any(m['type']=='cpu' for m in c['modules'])
    assert '{appimage}' not in p.read_text()
    print('JSON OK:',p)
PY
if (( EUID == 0 )); then echo 'Run as a regular user to test installer' >&2; exit 1; fi
sandbox=$(mktemp -d)
trap 'rm -rf -- "$sandbox"' EXIT
mkdir -p "$sandbox/bin" "$sandbox/conf/fastfetch"
printf '#!/bin/sh\nexit 0\n' > "$sandbox/bin/fastfetch"
chmod +x "$sandbox/bin/fastfetch"
export PATH="$sandbox/bin:$PATH" XDG_CONFIG_HOME="$sandbox/conf"
target=$XDG_CONFIG_HOME/fastfetch
printf 'original config\n' > "$target/config.jsonc"
printf 'original art\n' > "$target/ascii.txt"
bash install.sh classic --yes
backup=$(find "$target" -maxdepth 1 -type d -name 'backup.*' | head -n 1)
grep -qx 'original config' "$backup/config.jsonc"
grep -qx 'original art' "$backup/ascii.txt"
bash install.sh compact --yes
python3 - "$target" <<'PY'
import json,sys
from pathlib import Path
p=Path(sys.argv[1]); cfg=json.loads((p/'config.jsonc').read_text())
assert cfg['logo']['source']==str(p/'ascii-compact.txt')
assert (p/'ascii-compact.txt').exists()
PY
before=$(sha256sum "$target/config.jsonc")
printf 'n\n' | bash install.sh cyan
[[ "$before" == "$(sha256sum "$target/config.jsonc")" ]]
rm "$target/ascii.txt"
ln -s "$sandbox/untouched" "$target/ascii.txt"
if bash install.sh classic --yes; then echo 'Expected refusal of symlink' >&2; exit 1; fi
[[ ! -e "$sandbox/untouched" ]]
[[ "$before" == "$(sha256sum "$target/config.jsonc")" ]]
echo 'Installer tests passed; Fastfetch was stubbed, not executed.'
