#!/bin/sh
set -u
HD=$(cd "$(dirname "$0")/../scripts" && pwd)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
fail() { echo "FAIL test-metrics: $1"; exit 1; }
mkdir -p "$T/runs" "$T/rules"; touch "$T/rules/a.md" "$T/rules/b.md"
cat > "$T/runs/s1.jsonl" <<'EOF'
{"session":"s1","event":"SessionStart"}
{"session":"s1","event":"InstructionsLoaded","instr":{"file":"/x/.claude/rules/a.md","reason":"session_start"}}
{"session":"s1","event":"UserPromptSubmit","prompt":"그게 아니라 b 로"}
{"session":"s1","event":"PostToolUseFailure","tool":"Bash","ok":false}
{"session":"s1","event":"SessionEnd"}
EOF
printf '{"session":"s2","event":"SessionStart"}\n{"session":"s2","event":"UserPromptSubmit","prompt":"안녕"}\n' > "$T/runs/s2.jsonl"
J=$(sh "$HD/metrics.sh" "$T/runs" "$T/rules") || fail "exit $?"
[ "$(printf '%s' "$J" | jq .sessions)" = 2 ] || fail "sessions"
[ "$(printf '%s' "$J" | jq .complete_sessions)" = 1 ] || fail "complete_sessions"
[ "$(printf '%s' "$J" | jq .corrections)" = 1 ] || fail "corrections"
[ "$(printf '%s' "$J" | jq .tool_failures)" = 1 ] || fail "tool_failures"
[ "$(printf '%s' "$J" | jq '.rules_loaded["a.md"]')" = 1 ] || fail "rules_loaded"
[ "$(printf '%s' "$J" | jq -r '.rules_never_loaded|join(",")')" = "b.md" ] || fail "rules_never_loaded"
echo "PASS test-metrics"
