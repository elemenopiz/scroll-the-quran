#!/bin/bash
# PreToolUse hook for Bash: block pbxproj mutation and destructive git.
INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
[ -z "$CMD" ] && exit 0
if echo "$CMD" | grep -qE '(sed|plutil|perl|python[0-9]*|awk|tee|>|>>) .*project\.pbxproj|project\.pbxproj.*(<<|>)'; then
  echo "BLOCKED: do not mutate project.pbxproj; edit project.yml and run xcodegen generate." >&2; exit 2; fi
if echo "$CMD" | grep -qE 'git push .*(--force|-f)( |$)|rm -rf +/( |$)|rm -rf +~( |$)'; then
  echo "BLOCKED: destructive command." >&2; exit 2; fi
exit 0
