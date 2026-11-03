#!/usr/bin/env bash
# Установщик коллекции скиллов для чата z.ai.
#
# Обычный путь — просто написать агенту в чате:
#   «Установи скиллы из https://github.com/Genocide12/skills-collection»
# Этот скрипт — ручной резервный вариант, если нужно поставить самому.
#
# Использование:
#   ./install.sh                  # МЕГА-СКИЛЛЫ (12 файлов-дистиллятов из mega/) — режим по умолчанию
#   ./install.sh --full           # полная коллекция: все 354 исходных скилла из skills/
#   ./install.sh --target DIR     # в указанный каталог
#   ./install.sh --only A,B       # (с --full) только скиллы выбранных источников (см. --list)
#   ./install.sh --list           # показать источники и количество скиллов
#
# Существующие файлы перезаписываются. Одноимённые папки бэкапятся
# в <target>-backup-<timestamp>, если такие есть.

set -euo pipefail

# в песочнице чата скиллы живут в /home/z/my-project/skills/
if [[ -d "/home/z/my-project" ]]; then
  TARGET="/home/z/my-project/skills"
else
  TARGET="./skills"
fi
CALLER_DIR="$PWD"
ONLY=""
LIST=0
MEGA=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    --only)   ONLY="$2"; shift 2 ;;
    --full)   MEGA=0; shift ;;
    --mega)   MEGA=1; shift ;;
    --list)   LIST=1; shift ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Неизвестный аргумент: $1" >&2; exit 1 ;;
  esac
done

cd "$(dirname "$0")"

case "$TARGET" in
  /*) ;;                                       # абсолютный путь — как есть
  *) TARGET="$CALLER_DIR/${TARGET#./}" ;;      # относительный — от каталога вызова
esac

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

python3 - "$TARGET" "$ONLY" "$MEGA" <<'PY'
import json, os, shutil, sys, time

target, only, mega = sys.argv[1], sys.argv[2], sys.argv[3] in ("1", "True")

if mega:
    if os.path.exists(target):
        ts = time.strftime("%Y%m%d-%H%M%S")
        backup = f"{target.rstrip('/')}-backup-{ts}"
        os.makedirs(backup, exist_ok=True)
        for d in sorted(os.listdir("mega")):
            dst = os.path.join(target, d)
            if os.path.isdir(dst):
                shutil.move(dst, os.path.join(backup, d))
        print(f"Бэкап перезаписанных папок: {backup}")
    else:
        os.makedirs(target, exist_ok=True)
    installed = []
    for d in sorted(os.listdir("mega")):
        src = os.path.join("mega", d)
        if not os.path.exists(os.path.join(src, "SKILL.md")):
            continue
        shutil.copytree(src, os.path.join(target, d))
        installed.append(d)
    print(f"Установлено {len(installed)} мега-скиллов в {target}:")
    for d in installed:
        print(f"  {d}")
    print("Полная коллекция (354 скилла) доступна: ./install.sh --full")
    sys.exit(0)

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
missing = [e["folder"] for e in manifest
           if not os.path.exists(os.path.join(target, e["folder"], "SKILL.md"))]
if missing:
    sys.exit(f"ОШИБКА: нет SKILL.md для: {missing[:5]}")
print("Проверка целостности: OK")
PY
