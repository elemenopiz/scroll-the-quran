#!/bin/bash
# Stop hook: enforce the English-only decision — no Arabic script in shipped sources/content.
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
OFFENDERS=$(grep -rlP '[\x{0600}-\x{06FF}\x{0750}-\x{077F}\x{FB50}-\x{FDFF}\x{FE70}-\x{FEFF}]' Content Packages App Widget 2>/dev/null | grep -v '/Fixtures/arabic' )
if [ -n "$OFFENDERS" ]; then
  echo "BLOCKED: Arabic script found in shipped files (v1 is English-only):" >&2
  echo "$OFFENDERS" >&2
  exit 2
fi
exit 0
