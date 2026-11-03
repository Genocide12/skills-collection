#!/usr/bin/env bash
# Установка 10 скиллов-дистиллятов в каталог скиллов агента.
#
# Обычный путь — просто написать агенту в чате:
#   «Установи скиллы из https://github.com/Genocide12/skills-collection»
# Этот скрипт — ручной резервный вариант, если нужно поставить самому.
#
# Использование:
#   ./install.sh                  # авто: в чате z.ai → /home/z/my-project/skills/, иначе → ./skills/
#   ./install.sh --target DIR     # в указанный каталог
#
# Одноимённые папки в целевом каталоге переносятся в бэкап <target>-backup-<timestamp>.

set -euo pipefail

if [[ -d "/home/z/my-project" ]]; then
  TARGET="/home/z/my-project/skills"
else
  TARGET="$PWD/skills"
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Неизвестный аргумент: $1 (доступен только --target DIR)" >&2; exit 1 ;;
  esac
done

cd "$(dirname "$0")"

case "$TARGET" in
  /*) ;;
  *) TARGET="$PWD/${TARGET#./}" ;;
esac

mkdir -p "$TARGET"
TS=$(date +%Y%m%d-%H%M%S)
BACKUP="$TARGET-backup-$TS"
MOVED=0

for d in [0-9][0-9]-*/; do
  name="${d%/}"
  dst="$TARGET/$name"
  if [[ -d "$dst" ]]; then
    mkdir -p "$BACKUP"
    mv "$dst" "$BACKUP/"
    MOVED=$((MOVED + 1))
  fi
  cp -r "$d" "$dst"
  echo "  + $name"
done

if [[ $MOVED -gt 0 ]]; then
  echo "Бэкап перезаписанных папок ($MOVED): $BACKUP"
fi
echo "Установлено 10 скиллов в $TARGET"
