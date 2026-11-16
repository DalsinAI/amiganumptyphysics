#!/bin/sh
# PC test for scripts/write-part.sh: the Part file GFOpenUpTool reads.
# MIT, Copyright (c) 2026 AmiCradle Team.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
D="$T/Games/NumptyPhysics"; mkdir -p "$D/data/C10_Standard" "$D/data/i18n"
: > "$D/NumptyPhysics"; : > "$D/ReadMe"; : > "$D/data/C10_Standard/L01_Butterfly.npz"; : > "$D/data/i18n/de"
sh "$HERE/../scripts/write-part.sh" "$T" 0.3.9
fail=0
expect() { grep -qxF "$1" "$T/Part" || { echo "FAIL: no line: $1"; fail=1; }; }
expect 'part NumptyPhysics 0.3.9'
expect 'needs 68040'
expect 'needs part GFOpenGPU'
expect 'copy "Games/NumptyPhysics/NumptyPhysics" "SYS:Games/NumptyPhysics/NumptyPhysics"'
expect 'copy "Games/NumptyPhysics/data/C10_Standard/L01_Butterfly.npz" "SYS:Games/NumptyPhysics/data/C10_Standard/L01_Butterfly.npz"'
expect 'copy "Games/NumptyPhysics/data/i18n/de" "SYS:Games/NumptyPhysics/data/i18n/de"'
[ "$(head -1 "$T/Part")" = 'part NumptyPhysics 0.3.9' ] || { echo "FAIL: first line"; fail=1; }
[ "$(grep -c '^copy' "$T/Part")" = 4 ] || { echo "FAIL: file count"; fail=1; }
sh "$HERE/../scripts/write-part.sh" "$T" 0.3.9
[ "$(grep -c '^copy' "$T/Part")" = 4 ] || { echo "FAIL: second run lists the Part file"; fail=1; }
[ $fail = 0 ] && echo "Part file: all checks passed"
exit $fail
