#!/bin/sh
# metrics.sh [runs dir] [rules dir] — 원장에서 주간 수치를 센다. rule 개수로 성장을 재지 않는다.
set -eu
RUNS=${1:-.claude/harness/runs}; RULES=${2:-.claude/rules}
ALL=$(ls "$RULES"/*.md 2>/dev/null | xargs -n1 basename | jq -R . | jq -s .)
cat "$RUNS"/*.jsonl 2>/dev/null | jq -s --argjson all "$ALL" '
  (map(.session) | unique | length) as $sessions
  | (map(select(.event=="SessionEnd") | .session) | unique | length) as $complete
  | (map(select(.event=="UserPromptSubmit" and ((.prompt // "") | test("아니|그게 아니라|틀렸|다시|잘못")))) | length) as $corr
  | (map(select(.event=="PostToolUseFailure")) | length) as $tf
  | (map(select(.event=="InstructionsLoaded") | .instr.file | split("/") | last) | group_by(.) | map({key:.[0], value:length}) | from_entries) as $loaded
  | {sessions:$sessions, complete_sessions:$complete, corrections:$corr, tool_failures:$tf,
     rules_loaded:$loaded, rules_never_loaded:($all - ($loaded|keys))}'
