#!/usr/bin/env bash
# Install the ten skills into the agent's skills directory.
#
# The usual way is to simply tell your agent in the chat:
#   "Install the skills from https://github.com/Genocide12/skills-collection"
# This script is the manual fallback, if you prefer to do it yourself.
#
# Usage:
#   ./install.sh                  # auto: in a z.ai chat -> /home/z/my-project/skills/, otherwise -> ./skills/
#   ./install.sh --target DIR     # into a directory of your choice
#
# Folders with the same name in the target directory are moved to a backup
# at <target>-backup-<timestamp>.

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
    *) echo "Unknown argument: $1 (only --target DIR is supported)" >&2; exit 1 ;;
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
  echo "Backed up $MOVED replaced folder(s): $BACKUP"
fi
echo "Installed 10 skills into $TARGET"
