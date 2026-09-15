#!/bin/sh
# hooks.json 배선 — 명령이 가리키는 파일이 실재·실행 가능하고, collect 는 9 이벤트에, gate 는 PreToolUse ^Bash$ 에 걸려 있다
set -u
P=$(cd "$(dirname "$0")/.." && pwd)
fail() { echo "FAIL test-hooks: $1"; exit 1; }
J="$P/hooks/hooks.json"
jq -e . "$J" >/dev/null || fail "hooks.json 파손"
jq -r '.hooks | to_entries[] | .value[] | .hooks[] | .command' "$J" | while IFS= read -r c; do
  f=$(printf '%s' "$c" | sed -e 's/^"//' -e 's/"$//' -e "s#\${CLAUDE_PLUGIN_ROOT}#$P#")
  [ -x "$f" ] || { echo "FAIL test-hooks: 실행 파일이 아니다: $c"; exit 1; }
done || exit 1
for ev in SessionStart UserPromptSubmit UserPromptExpansion PostToolUse PostToolUseFailure InstructionsLoaded Stop SessionEnd ConfigChange; do
  jq -e --arg ev "$ev" '.hooks[$ev][]?.hooks[]? | select(.command | test("collect.sh"))' "$J" >/dev/null || fail "collect 가 $ev 에 없다"
done
jq -e '.hooks.PreToolUse[] | select(.matcher=="^Bash$") | .hooks[] | select(.command | test("gate-harness-pr.sh"))' "$J" >/dev/null || fail "gate 가 PreToolUse ^Bash$ 에 없다"
echo "PASS test-hooks"
