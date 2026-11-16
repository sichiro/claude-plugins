#!/bin/sh
# collect.sh — 합성 훅 입력으로 원장 기록을 검증한다
set -u
H=$(cd "$(dirname "$0")/../hooks" && pwd)/collect.sh
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
fail() { echo "FAIL test-collect: $1"; exit 1; }
git -C "$T" init -q && git -C "$T" commit -q --allow-empty -m init
mkdir -p "$T/.claude/harness/cases/a"   # opt-in — 평가할 사례가 있는 저장소만 수집한다
run() { printf '%s' "$1" | CLAUDE_PROJECT_DIR="$T" sh "$H"; }

run '{"session_id":"s1","hook_event_name":"SessionStart","cwd":"'"$T"'"}' || fail "SessionStart exit $?"
run '{"session_id":"s1","hook_event_name":"PostToolUse","tool_name":"Bash","tool_use_id":"t1","tool_input":{"command":"psql password=notreal -c select"}}' || fail "PostToolUse exit"
run '{"session_id":"s1","hook_event_name":"UserPromptExpansion","command_name":"wt-done","command_args":"MGR-1"}' || fail "Expansion exit"
run '{"session_id":"s1","hook_event_name":"Stop","last_assistant_message":"완료"}' || fail "Stop exit"
run '{"session_id":"s1","hook_event_name":"PostToolUseFailure","tool_name":"Bash","tool_use_id":"t2","tool_input":{"command":"make test"}}' || fail "PostToolUseFailure exit"
run '{"session_id":"s1","hook_event_name":"InstructionsLoaded","file_path":"/x/.claude/rules/a.md","load_reason":"session_start"}' || fail "InstructionsLoaded exit"
run '{"session_id":"s1","hook_event_name":"UserPromptSubmit","prompt":"그게 아니라"}' || fail "UserPromptSubmit exit"
run '{"session_id":"s1","hook_event_name":"ConfigChange","source":"project_settings","file_path":"/x/.claude/settings.json"}' || fail "ConfigChange exit"
run '{"session_id":"s1","hook_event_name":"PostToolUse","tool_name":"Edit","tool_use_id":"t3","tool_input":{"file_path":"/x/y.md"}}' || fail "PostToolUse Edit exit"
run '{"session_id":"s1","hook_event_name":"PostToolUse","agent_id":"ag1","tool_name":"Bash","tool_use_id":"t4","tool_input":{"command":"ls"}}' || fail "PostToolUse with agent_id exit"

L="$T/.claude/harness/runs/s1.jsonl"
[ -f "$L" ] || fail "원장 파일 없음"
[ "$(wc -l < "$L" | tr -d ' ')" = 10 ] || fail "10줄 아님: $(wc -l < "$L")"
grep -q 'notreal' "$L" && fail "명령의 비밀값이 마스킹되지 않음"
grep -q 'password=<masked>' "$L" || fail "마스킹 표기 없음"
[ "$(sed -n 1p "$L" | jq -r .harness.sha)" = "$(git -C "$T" rev-parse HEAD)" ] || fail "SessionStart harness.sha"
[ "$(sed -n 1p "$L" | jq -r .harness.dirty)" = "false" ] || fail "dirty 가 false 아님"
[ "$(sed -n 2p "$L" | jq -r .tool_use_id)" = "t1" ] || fail "tool_use_id"
[ "$(sed -n 2p "$L" | jq -r .ok)" = "true" ] || fail "PostToolUse ok"
[ "$(sed -n 3p "$L" | jq -r .slash)" = "wt-done" ] || fail "slash"
[ "$(sed -n 4p "$L" | jq -r .reply)" = "완료" ] || fail "Stop reply"
[ "$(sed -n 5p "$L" | jq -r .ok)" = "false" ] || fail "PostToolUseFailure ok"
[ "$(sed -n 5p "$L" | jq -r .cmd)" = "make test" ] || fail "PostToolUseFailure cmd"
[ "$(sed -n 6p "$L" | jq -r .instr.file)" = "/x/.claude/rules/a.md" ] || fail "InstructionsLoaded file"
[ "$(sed -n 6p "$L" | jq -r .instr.reason)" = "session_start" ] || fail "InstructionsLoaded reason"
[ "$(sed -n 7p "$L" | jq -r .prompt)" = "그게 아니라" ] || fail "UserPromptSubmit prompt"
[ "$(sed -n 8p "$L" | jq -r .config.source)" = "project_settings" ] || fail "ConfigChange source"
[ "$(sed -n 9p "$L" | jq -r .file)" = "/x/y.md" ] || fail "PostToolUse Edit file"
[ "$(sed -n 9p "$L" | jq -r .cmd)" = "null" ] || fail "PostToolUse Edit cmd"
[ "$(sed -n 10p "$L" | jq -r .agent)" = "ag1" ] || fail "PostToolUse agent_id"

# fail-open — jq 가 PATH 에 없어도 exit 0
printf '{"session_id":"s2","hook_event_name":"Stop"}' | PATH=/bin CLAUDE_PROJECT_DIR="$T" sh "$H" || fail "jq 없이 exit 0 아님"
# fail-open — 입력이 JSON 이 아니어도 exit 0
printf 'not json' | CLAUDE_PROJECT_DIR="$T" sh "$H" || fail "깨진 입력에 exit 0 아님"
# opt-in — .claude/harness/cases 가 없는 저장소에는 아무것도 만들지 않는다
T2="$T/plain"; mkdir -p "$T2"; git -C "$T2" init -q
printf '{"session_id":"s3","hook_event_name":"Stop"}' | CLAUDE_PROJECT_DIR="$T2" sh "$H" || fail "opt-in 밖에서 exit 0 아님"
[ ! -e "$T2/.claude/harness" ] || fail "cases 없는 저장소에 .claude/harness 를 만듦"
# 빈 cases/ 도 사례가 없다 — 수집하지 않는다
mkdir -p "$T2/.claude/harness/cases"
printf '{"session_id":"s3","hook_event_name":"Stop"}' | CLAUDE_PROJECT_DIR="$T2" sh "$H" || fail "빈 cases 에서 exit 0 아님"
[ ! -e "$T2/.claude/harness/runs" ] || fail "빈 cases/ 인 저장소에 runs 를 만듦"
# sealed.manifest 항목만 있어도 사례가 있다 — 수집한다
printf 's1\t0000\n' > "$T2/.claude/harness/sealed.manifest"
printf '{"session_id":"s3","hook_event_name":"Stop"}' | CLAUDE_PROJECT_DIR="$T2" sh "$H" || fail "manifest 만 있는 저장소에서 exit 0 아님"
[ -f "$T2/.claude/harness/runs/s3.jsonl" ] || fail "manifest 만 있는 저장소를 수집하지 않음"
echo "PASS test-collect"
