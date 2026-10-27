#!/usr/bin/env bash
# Забирает клиентские .conf с VPS в ./configs (приватные ключи, не в git).
# Использование: scripts/fetch-configs.sh [ssh-хост]   (по умолчанию amster)
set -euo pipefail

host="${1:-amster}"
remote_dir="/opt/amneziawg-tools/keys"
dest="$(cd "$(dirname "$0")/.." && pwd)/configs"

umask 077
mkdir -p "$dest"

# root-owned 0600, поэтому читаем через sudo и стримим tar без временных файлов на сервере
# glob раскрываем внутри sudo: у обычного пользователя нет прав на каталог (0700)
ssh "$host" "sudo -n sh -c 'cd $remote_dir && tar -cf - *.conf'" | tar -C "$dest" -xf -

chmod 600 "$dest"/*.conf
ls -l "$dest"
