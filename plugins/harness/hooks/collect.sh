#!/bin/sh
# 하네스 원장 수집. 어떤 오류에도 세션을 막지 않는다 (fail-open).
# 배선: SessionStart UserPromptSubmit UserPromptExpansion PostToolUse PostToolUseFailure
#       InstructionsLoaded Stop SessionEnd ConfigChange — 전부 async.
# 기록하지 않는 것: 도구 출력, 파일 내용. Bash 명령은 300자로 자르고 key=value 비밀을 마스킹한다.
set -u
INPUT=$(cat) || exit 0
command -v jq >/dev/null 2>&1 || exit 0
printf '%s' "$INPUT" | jq -e . >/dev/null 2>&1 || exit 0
ROOT=${CLAUDE_PROJECT_DIR:-.}
DIR="$ROOT/.claude/harness/runs"
mkdir -p "$DIR" 2>/dev/null || exit 0
SID=$(printf '%s' "$INPUT" | jq -r '.session_id // "unknown"')
EV=$(printf '%s' "$INPUT" | jq -r '.hook_event_name // ""')

HARNESS=null
case "$EV" in
  SessionStart|Stop)
    SHA=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)
    DIRTY=false
    [ -n "$(git -C "$ROOT" status --porcelain -- .claude CLAUDE.md 2>/dev/null)" ] && DIRTY=true
    if [ "$EV" = SessionStart ]; then
      VER=$(claude --version 2>/dev/null | awk '{print $1}')
      MANAGED=false
      [ -f "/Library/Application Support/ClaudeCode/managed-settings.json" ] && MANAGED=true
      HARNESS=$(jq -cn --arg sha "$SHA" --argjson dirty "$DIRTY" --arg v "${VER:-unknown}" --argjson m "$MANAGED" \
        '{sha:$sha,dirty:$dirty,version:$v,managed:$m}')
    else
      HARNESS=$(jq -cn --arg sha "$SHA" --argjson dirty "$DIRTY" '{sha:$sha,dirty:$dirty}')
    fi
    ;;
esac

printf '%s' "$INPUT" | jq -c --arg ts "$(date +%Y-%m-%dT%H:%M:%S%z)" --argjson harness "$HARNESS" '
  def mask: gsub("(?<k>(password|passwd|pwd|token|secret|key)=)[^ ]+"; "\(.k)<masked>");
  {ts:$ts, session:(.session_id // "unknown"), agent:(.agent_id // null), event:.hook_event_name,
   tool:(.tool_name // null), tool_use_id:(.tool_use_id // null),
   cmd:(if .tool_name=="Bash" then ((.tool_input.command // "")|.[0:300]|mask) else null end),
   file:(.tool_input.file_path // null),
   ok:(if .hook_event_name=="PostToolUseFailure" then false elif .hook_event_name=="PostToolUse" then true else null end),
   instr:(if .hook_event_name=="InstructionsLoaded" then {file:.file_path,reason:.load_reason} else null end),
   slash:(.command_name // null),
   prompt:(if .hook_event_name=="UserPromptSubmit" then .prompt else null end),
   reply:(.last_assistant_message // null),
   config:(if .hook_event_name=="ConfigChange" then {source:.source,file:(.file_path // null)} else null end),
   harness:$harness}' >> "$DIR/$SID.jsonl" 2>/dev/null
exit 0
