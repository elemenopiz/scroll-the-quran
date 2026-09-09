#!/bin/bash
# Print the measured hex for every probe in Tools/snapshot/probes.json.
#
#   Tools/snapshot/sample-colors.sh              # every probe
#   Tools/snapshot/sample-colors.sh home-dark    # only probes on files matching a pattern
#   Tools/snapshot/sample-colors.sh --swift      # emit the values as a Swift comment block
#
# Design tokens are measured, never guessed: the values this prints are the ones
# hard-coded in Packages/ScrollKit/Sources/DesignSystem/Tokens.swift.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROBES="$ROOT/Tools/snapshot/probes.json"
REFDIR="$ROOT/Reference"

command -v magick >/dev/null || { echo "sample-colors.sh: ImageMagick 7 (magick) is required" >&2; exit 1; }
command -v jq >/dev/null || { echo "sample-colors.sh: jq is required" >&2; exit 1; }
[ -f "$PROBES" ] || { echo "sample-colors.sh: missing $PROBES" >&2; exit 1; }

SWIFT=0
FILTER=""
for arg in "$@"; do
  case "$arg" in
    --swift) SWIFT=1 ;;
    *) FILTER="$arg" ;;
  esac
done

[ "$SWIFT" -eq 1 ] && echo "// Measured by Tools/snapshot/sample-colors.sh on $(date -u +%Y-%m-%d)."

jq -r '.screens[] | .file as $f | .appearance as $a | .probes[] | [$f, $a, .name, (.x|tostring), (.y|tostring), .of] | @tsv' "$PROBES" |
while IFS=$'\t' read -r file appearance name x y of; do
  [ -n "$FILTER" ] && [[ "$file" != *"$FILTER"* ]] && continue
  img="$REFDIR/$file"
  if [ ! -f "$img" ]; then
    echo "MISSING $file" >&2
    continue
  fi
  # -depth 8 because a couple of the captures are 16-bit PNGs.
  hex="$(magick "$img" -depth 8 -format "%[hex:p{$x,$y}]" info:)"
  if [ "$SWIFT" -eq 1 ]; then
    printf '// %-22s #%-6s  %s (%s,%s) — %s\n' "$name" "$hex" "$file" "$x" "$y" "$of"
  else
    printf '%-22s #%-6s  %-5s %-24s (%4s,%4s)  %s\n' "$name" "$hex" "$appearance" "$file" "$x" "$y" "$of"
  fi
done
