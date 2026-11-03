#!/usr/bin/env bash
# Установщик коллекции скиллов в проект.
#
# Использование:
#   ./install.sh                 # скопировать все скиллы в ./skills/
#   ./install.sh --claude        # в ./.claude/skills/ (формат Claude Code)
#   ./install.sh --target DIR    # в указанный каталог
#   ./install.sh --only ECC,superpowers   # только скиллы выбранных источников
#   ./install.sh --list          # показать источники и количество скиллов
#
# Существующие файлы перезаписываются. Перед копированием делается бэкап
# одноимённых папок в <target>-backup-<timestamp>, если такие есть.

set -euo pipefail

TARGET="./skills"
ONLY=""
LIST=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --claude) TARGET="./.claude/skills"; shift ;;
    --target) TARGET="$2"; shift 2 ;;
    --only)   ONLY="$2"; shift 2 ;;
    --list)   LIST=1; shift ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Неизвестный аргумент: $1" >&2; exit 1 ;;
  esac
done

cd "$(dirname "$0")"

if [[ $LIST -eq 1 ]]; then
  python3 - <<'PY'
import json
from collections import Counter
m = json.load(open("manifest.json"))
c = Counter(e["source"] for e in m)
for k, v in c.most_common():
    print(f"{v:4d}  {k}")
print(f"{len(m):4d}  ИТОГО")
PY
  exit 0
fi

FILTER=""
if [[ -n "$ONLY" ]]; then
  FILTER="$ONLY"
fi

python3 - "$TARGET" "$FILTER" <<'PY'
import json, os, shutil, sys, time

target, only = sys.argv[1], sys.argv[2]
manifest = json.load(open("manifest.json"))
sources = {s.strip() for s in only.split(",") if s.strip()} if only else None
if sources:
    manifest = [e for e in manifest if e["source"] in sources]
    if not manifest:
        sys.exit(f"Нет скиллов для источников: {only}")

if os.path.exists(target):
    ts = time.strftime("%Y%m%d-%H%M%S")
    backup = f"{target.rstrip('/')}-backup-{ts}"
    os.makedirs(backup, exist_ok=True)
    for e in manifest:
        dst = os.path.join(target, e["folder"])
        if os.path.isdir(dst):
            shutil.move(dst, os.path.join(backup, e["folder"]))
    print(f"Бэкап перезаписанных папок: {backup}")
else:
    os.makedirs(target, exist_ok=True)

for e in manifest:
    src = os.path.join("skills", e["folder"])
    dst = os.path.join(target, e["folder"])
    shutil.copytree(src, dst)

print(f"Установлено {len(manifest)} скиллов в {target}")
for folder in ("taste-skill", "superpowers", "ECC"):
    p = os.path.join(target, folder, "SKILL.md")
    if not os.path.exists(p):
        sys.exit(f"ОШИБКА: {p} не найден после установки")
print("Проверка целостности: OK")
PY
