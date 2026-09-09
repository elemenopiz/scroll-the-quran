#!/bin/bash
# PreToolUse hook: block edits to Xcode-managed files and generation scratch.
INPUT=$(cat)
FP=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
[ -z "$FP" ] && exit 0
if echo "$FP" | grep -qE '\.pbxproj$|\.xcodeproj/|\.xcworkspace/|Tools/content-gen/work/(cache|requests|batches)'; then
  echo "BLOCKED: $FP is Xcode-managed or generated scratch. Edit project.yml and run 'xcodegen generate' instead." >&2
  exit 2
fi
exit 0
