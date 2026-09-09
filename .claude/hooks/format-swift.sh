#!/bin/bash
# PostToolUse: format + lint the edited Swift file (non-blocking).
INPUT=$(cat)
FP=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
case "$FP" in
  *.swift)
    command -v swiftformat >/dev/null && swiftformat --quiet "$FP" 2>/dev/null
    command -v swiftlint >/dev/null && swiftlint lint --quiet "$FP" 2>/dev/null | head -20
    ;;
esac
exit 0
