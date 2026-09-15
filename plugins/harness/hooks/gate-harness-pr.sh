#!/bin/sh
# 하네스 PR 게이트 (PreToolUse · Bash). .claude/ 나 CLAUDE.md 를 건드린 브랜치는
# 유효한 eval 보고서 없이 gh pr create / gh pr merge 를 실행하지 못한다.
# 유효 조건은 설계서 §4.3 과 같다 — managed 조건은 없다(보호 계층은 범위 밖). 검사 불능은 차단이다 (fail-closed).
# ponytail: 명령 위치 ERE(INVOKE)로 실제 호출만 고른다. heredoc 본문은 먼저 벗긴다 — 종료자를 못 찾으면 벗기지 않고 원문으로 본다(과차단 방향). 따옴표 안의 호출(sh -c '…')·한 줄에 heredoc 둘은 놓치거나 과차단한다 — 비적대적 전제.
# ponytail: merge 는 `gh pr merge [<번호>] [플래그]` 형태만 본다. 값 있는 플래그(--body 등) 뒤의 값을 번호로 오인할 수 있다.
set -u
deny() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}\n' \
    "$(printf '%s' "$1" | jq -Rs .)"
  exit 0
}
command -v jq >/dev/null 2>&1 || { echo "jq 가 없어 PR 게이트를 실행할 수 없다" >&2; exit 2; }
INPUT=$(cat)
CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""')
# 실제 호출만 잡는다 — 파이프라인 세그먼트 시작(^ 또는 ; & | 뒤)의 [VAR=… ][경로/]gh [플래그…] pr (create|merge).
# heredoc 본문은 먼저 벗긴다. 종료자를 못 찾으면(따옴표 안 <<·탭 들여쓴 <<- 등) 벗기지 않고 원문으로 매칭한다 — 과차단 방향.
INVOKE='(^|[;&|][[:space:]]*)([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*([^[:space:]]*/)?gh([[:space:]]+-[^[:space:]]+([[:space:]]+[^-][^[:space:]]*)?)*[[:space:]]+pr[[:space:]]+(create|merge)([[:space:]]|$)'
# heredoc 본문을 벗긴다 — `<<WORD`·`<<-WORD`·`<<'WORD'`·`<<"WORD"` 뒤부터 WORD 만 있는 줄까지를 버린다.
# 본문은 데이터라 호출이 아니다. 줄바꿈은 세그먼트 구분자로 남긴다.
STRIPPED=$(printf '%s\n' "$CMD" | awk '
  skip != "" { if ($0 == skip) skip = ""; next }
  {
    print
    if (match($0, /<<-?[[:space:]]*["'\'']?[A-Za-z_][A-Za-z0-9_]*["'\'']?/)) {
      w = substr($0, RSTART, RLENGTH); sub(/^<<-?[[:space:]]*/, "", w); gsub(/["'\'']/, "", w); skip = w
    }
  }
  END { if (skip != "") print "\001UNTERMINATED\001" }')
# 종료자를 못 찾았으면(따옴표 안의 <<, 탭 들여쓴 <<- 종료자) 벗긴 결과를 믿지 않고 원문으로 본다 — 과차단 방향으로만 틀린다
case "$STRIPPED" in *"$(printf '\001')UNTERMINATED"*) STRIPPED=$CMD;; esac
printf '%s' "$STRIPPED" | grep -qE "$INVOKE" || exit 0
printf '%s' "$CMD" | grep -qE -- '(^|[[:space:]])(--repo|-R)([[:space:]=]|$)' && deny "--repo 형태는 지원하지 않는다 — 저장소 체크아웃 안에서 실행한다"
ROOT=$(printf '%s' "$INPUT" | jq -r '.cwd // "."')
# cwd 가 하위 디렉터리면 아래 pathspec(.claude CLAUDE.md)이 어긋나 조용히 통과한다 — 루트로 올린다
ROOT=$(git -C "$ROOT" rev-parse --show-toplevel 2>/dev/null) || deny "git 저장소가 아니다"
G="git -C $ROOT"

if printf '%s' "$CMD" | grep -qw merge; then
  # merge 뒤 첫 비플래그 토큰이 PR 번호·URL·브랜치다. 없으면 현재 브랜치의 PR 이다
  ARG=$(printf '%s' "$CMD" | awk '{for(i=1;i<=NF;i++) if($i=="merge"){for(j=i+1;j<=NF;j++) if($j !~ /^-/){print $j; exit}}}')
  J=$(cd "$ROOT" && gh pr view $ARG --json headRefOid,baseRefOid 2>/dev/null) || deny "PR 을 조회하지 못했다: gh pr view $ARG"
  TARGET=$(printf '%s' "$J" | jq -r '.headRefOid // empty'); BASE=$(printf '%s' "$J" | jq -r '.baseRefOid // empty')
  [ -n "$TARGET" ] && [ -n "$BASE" ] || deny "PR head/base 를 읽지 못했다"
else
  printf '%s' "$CMD" | grep -qE -- '(^|[[:space:]])(--head|-H)([[:space:]=]|$)' && deny "--head 형태는 지원하지 않는다 — 대상 브랜치를 체크아웃하고 실행한다"
  TARGET=$($G rev-parse --verify -q HEAD) || deny "HEAD 를 읽지 못했다"
  # --verify -q 가 아니면 없는 ref 이름이 stdout 에 그대로 찍혀 BASE 가 두 줄이 된다
  # base 는 명령의 --base <x> · --base=<x> · -B <x>, 없으면 저장소의 기본 브랜치 — PR 이 실제로 가는 곳이다
  BASE_NAME=$(printf '%s' "$CMD" | grep -oE -- '(^|[[:space:]])(--base|-B)[[:space:]=][^[:space:]]+' | head -1 | sed -E 's/^[[:space:]]*(--base|-B)[[:space:]=]//')
  [ -n "$BASE_NAME" ] || BASE_NAME=$(cd "$ROOT" && gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null) || deny "기본 브랜치를 조회하지 못했다: gh repo view"
  BASE=$($G rev-parse --verify -q "origin/$BASE_NAME" || $G rev-parse --verify -q "$BASE_NAME") || deny "base 브랜치를 찾지 못했다: $BASE_NAME"
fi

$G diff --quiet "$BASE" "$TARGET" -- .claude CLAUDE.md ':!.claude/harness/observations' ':!.claude/harness/proposals' ':!.claude/harness/reports' 2>/dev/null && exit 0

SUITE=$($G rev-parse --verify -q "$TARGET:.claude/harness/cases" 2>/dev/null || echo none)
WANT=$( { $G ls-tree --name-only "$TARGET" .claude/harness/cases/ 2>/dev/null | while read -r p; do basename "$p"; done
          $G show "$TARGET:.claude/harness/sealed.manifest" 2>/dev/null | cut -f1; } | grep . | sort -u)
FILES=$($G ls-tree --name-only "$TARGET" .claude/harness/reports/ 2>/dev/null | grep '\.json$' || true)
[ -n "$FILES" ] || deny "하네스가 바뀌었는데 eval 보고서가 없다 — /harness:propose 의 절차(run.sh · report.sh)로 보고서를 만들어 .claude/harness/reports/ 에 커밋한다"
REASON="유효한 보고서가 없다"
for f in $FILES; do
  J=$($G show "$TARGET:$f" 2>/dev/null) || continue
  printf '%s' "$J" | jq -e '(.regressed|type=="array") and (.errors|type=="array") and (.cases|type=="array") and (.managed|type=="boolean")' >/dev/null 2>&1 \
    || { REASON="$f: 보고서 형식이 아니다 (report.sh 가 만든 것이 아니다)"; continue; }
  EV=$(printf '%s' "$J" | jq -r '.evaluated_sha // ""'); BS=$(printf '%s' "$J" | jq -r '.base_sha // ""')
  [ "$BS" = "$BASE" ] || { REASON="$f: base_sha 가 base($BASE)와 다르다"; continue; }
  $G diff --quiet "$EV" "$TARGET" -- .claude CLAUDE.md ':!.claude/harness/observations' ':!.claude/harness/proposals' ':!.claude/harness/reports' 2>/dev/null || { REASON="$f: evaluated_sha 이후 하네스가 바뀌었다 — 다시 평가한다"; continue; }
  [ "$(printf '%s' "$J" | jq -r '.suite_sha // ""')" = "$SUITE" ] || { REASON="$f: suite_sha 가 대상의 harness/cases 트리와 다르다"; continue; }
  HAVE=$(printf '%s' "$J" | jq -r '.cases[].case' | sort -u)
  [ "$HAVE" = "$WANT" ] || { REASON="$f: 보고서의 사례 목록이 suite(discovery + sealed.manifest)와 다르다"; continue; }
  [ "$(printf '%s' "$J" | jq -r '.regressed|length')" = 0 ] || { REASON="$f: 회귀 $(printf '%s' "$J" | jq -r '.regressed|length') 건 — 승격 불가"; continue; }
  [ "$(printf '%s' "$J" | jq -r '.errors|length')" = 0 ] || { REASON="$f: 러너 오류 $(printf '%s' "$J" | jq -r '.errors|length') 건 — 승격 불가"; continue; }
  exit 0
done
deny "$REASON"
