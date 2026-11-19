#!/usr/bin/env bash
set -euo pipefail
umask 077
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
usage() { printf '%s\n' 'Usage: bash install.sh [classic|compact|cyan|amber|plain] [--yes]' 'Installs local files only; backs up existing config. No sudo.'; }
theme=classic; yes=0; chosen=0
for arg in "$@"; do
  case "$arg" in
    -h|--help) usage; exit 0;;
    --yes) yes=1;;
    classic|compact|cyan|amber|plain) (( chosen == 0 )) || { usage >&2; exit 2; }; theme=$arg; chosen=1;;
    *) usage >&2; exit 2;;
  esac
done
if (( EUID == 0 )); then echo 'Do not run this installer as root.' >&2; exit 1; fi
command -v fastfetch >/dev/null || { echo 'Install Fastfetch first: https://github.com/fastfetch-cli/fastfetch#installation' >&2; exit 1; }
command -v python3 >/dev/null || { echo 'Python 3 is required.' >&2; exit 1; }
case "$theme" in classic) config=config.jsonc;; *) config=themes/$theme.jsonc;; esac
logo=ascii.txt; [[ "$theme" != compact ]] || logo=ascii-compact.txt
base=${XDG_CONFIG_HOME:-$HOME/.config}; [[ "$base" == /* ]] || { echo 'XDG_CONFIG_HOME must be absolute.' >&2; exit 1; }
target=$base/fastfetch
[[ ! -L "$target" ]] || { echo 'Refusing symlinked fastfetch directory.' >&2; exit 1; }
for name in config.jsonc "$logo"; do
  [[ ! -L "$target/$name" ]] || { echo "Refusing symlink: $target/$name" >&2; exit 1; }
  if [[ -e "$target/$name" && ! -f "$target/$name" ]]; then echo 'Destination is not a regular file.' >&2; exit 1; fi
done
printf 'Theme: %s\nDestination: %s\n' "$theme" "$target"
if (( ! yes )); then read -r -p 'Install and back up existing files? [y/N] ' reply; [[ "$reply" == y || "$reply" == Y ]] || exit 0; fi
mkdir -p -- "$target"
stage=$(mktemp -d "$target/.rice-stage.XXXXXXXX")
trap 'rm -rf -- "$stage"' EXIT
python3 - "$root/$config" "$stage/config.jsonc" "$target/$logo" <<'PY'
import json, sys
from pathlib import Path
cfg=json.loads(Path(sys.argv[1]).read_text())
cfg['logo']['source']=sys.argv[3]
Path(sys.argv[2]).write_text(json.dumps(cfg, ensure_ascii=False, indent=2)+'\n')
PY
cp -- "$root/$logo" "$stage/$logo"
backup=''
for name in config.jsonc "$logo"; do
  if [[ -f "$target/$name" ]]; then
    if [[ -z "$backup" ]]; then backup=$(mktemp -d "$target/backup.XXXXXXXX"); fi
    cp -p -- "$target/$name" "$backup/$name"
  fi
done
mv -f -- "$stage/$logo" "$target/$logo"
mv -f -- "$stage/config.jsonc" "$target/config.jsonc"
[[ -z "$backup" ]] || printf 'Backup: %s\n' "$backup"
printf 'Installed. Run: fastfetch --config "%s/config.jsonc"\n' "$target"
