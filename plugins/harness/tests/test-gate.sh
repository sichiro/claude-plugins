#!/bin/sh
# gate-harness-pr.sh — 하네스를 건드린 브랜치는 유효한 보고서 없이 PR 을 못 만든다
set -u
G=$(cd "$(dirname "$0")/../hooks" && pwd)/gate-harness-pr.sh
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
fail() { echo "FAIL test-gate: $1"; exit 1; }
R="$T/my repo"; mkdir -p "$R/.claude/rules" "$R/.claude/harness/cases/a" "$R/src"
git -C "$R" init -q -b develop; echo a > "$R/src/a.go"; echo p > "$R/.claude/harness/cases/a/prompt.md"
printf 's1\t0000\n' > "$R/.claude/harness/sealed.manifest"
echo n > "$R/.claude/harness/cases/README.md"
git -C "$R" add -A; git -C "$R" commit -q -m init
BASE=$(git -C "$R" rev-parse HEAD)
git -C "$R" checkout -q -b harness/x
inp() { printf '{"tool_name":"Bash","cwd":"%s","tool_input":{"command":"%s"}}' "$R" "$1"; }
report() { # <evaluated sha> <regressed json> <errors json> <managed> <cases json>
  jq -n --arg e "$1" --arg b "$BASE" --arg s "$(git -C "$R" rev-parse "$1:.claude/harness/cases")" \
    --argjson r "$2" --argjson x "$3" --argjson m "$4" --argjson c "$5" \
    '{evaluated_sha:$e,base_sha:$b,suite_sha:$s,managed:$m,cases:($c|map({case:.})),regressed:$r,errors:$x}'
}
mkdir -p "$R/.claude/harness/reports"
# gh 스텁 — pr view 는 현재 PR 의 head/base 를, repo view 는 기본 브랜치를 답한다
mkdir -p "$T/bin"
cat > "$T/bin/gh" <<'STUB'
#!/bin/sh
case "$1 $2" in
  "pr view") printf '%s' "$STUB_JSON";;
  "repo view") printf '%s' "$STUB_DEFAULT";;
esac
STUB
chmod +x "$T/bin/gh"
STUB_DEFAULT=develop; export STUB_DEFAULT

# 하네스 미변경 → 통과
echo b > "$R/src/b.go"; git -C "$R" add -A; git -C "$R" commit -q -m b
OUT=$(inp "gh pr create --base develop" | sh "$G" 2>&1); [ -z "$OUT" ] || fail "하네스 미변경인데 deny: $OUT"
# 관찰·제안 파일만 더한 변경은 하네스 변경이 아니다 → 통과
mkdir -p "$R/.claude/harness/observations" "$R/.claude/harness/proposals"
echo o > "$R/.claude/harness/observations/OBS-1.yaml"; echo i > "$R/.claude/harness/proposals/IMP-1.yaml"
git -C "$R" add -A; git -C "$R" commit -q -m obs
OUT=$(inp "gh pr create --base develop" | sh "$G" 2>&1); [ -z "$OUT" ] || fail "OBS·IMP 만 더했는데 deny: $OUT"
# 하네스 변경, 보고서 없음 → deny
echo r > "$R/.claude/rules/r.md"; git -C "$R" add -A; git -C "$R" commit -q -m r
OUT=$(inp "gh pr create --base develop" | sh "$G"); printf '%s' "$OUT" | grep -q '"deny"' || fail "보고서 없는데 통과"
# --base=<x> · -B <x> · --base 없음(기본 브랜치를 gh 에 묻는다)도 같은 판정
OUT=$(inp "gh pr create --base=develop" | sh "$G"); printf '%s' "$OUT" | grep -q '"deny"' || fail "--base= 형태를 놓침"
OUT=$(inp "gh pr create -B develop" | sh "$G"); printf '%s' "$OUT" | grep -q '"deny"' || fail "-B 형태를 놓침"
# 제목·본문의 merge 낱말은 merge 경로가 아니다 — create 로 판정해 보고서 부재 사유로 막힌다
CMDM='gh pr create --base develop --title "after merge"'
OUT=$(printf '{"tool_name":"Bash","cwd":"%s","tool_input":{"command":%s}}' "$R" "$(printf '%s' "$CMDM" | jq -Rs .)" | sh "$G"); printf '%s' "$OUT" | grep -q '보고서가 없다' || fail "merge 낱말이 든 create 를 merge 경로로 오인: $OUT"
# 본문 문자열 안의 --base 는 플래그가 아니다 — 진짜 플래그(main, 이 저장소에 없는 브랜치)를 골라야 한다
CMDB='gh pr create --body "rebase onto --base develop first" --base main'
OUT=$(printf '{"tool_name":"Bash","cwd":"%s","tool_input":{"command":%s}}' "$R" "$(printf '%s' "$CMDB" | jq -Rs .)" | sh "$G"); printf '%s' "$OUT" | grep -q 'base 브랜치를 찾지 못했다: main' || fail "따옴표 안 --base 를 플래그로 읽음: $OUT"
# 반복 플래그는 마지막이 이긴다 (gh 와 같다)
OUT=$(inp "gh pr create --base develop --base main" | sh "$G"); printf '%s' "$OUT" | grep -q 'base 브랜치를 찾지 못했다: main' || fail "반복 --base 에서 마지막을 고르지 않음: $OUT"
OUT=$(inp "gh pr create --title t" | PATH="$T/bin:$PATH" sh "$G"); printf '%s' "$OUT" | grep -q '"deny"' || fail "--base 없는 create 를 놓침"
OUT=$(inp "gh pr create --title t" | STUB_DEFAULT=nonexistent PATH="$T/bin:$PATH" sh "$G"); printf '%s' "$OUT" | grep -q 'base 브랜치를 찾지 못했다' || fail "없는 기본 브랜치를 통과시킴: $OUT"
OUT=$(inp "gh pr create --title t" | STUB_DEFAULT= PATH="$T/bin:$PATH" sh "$G"); printf '%s' "$OUT" | grep -q '빈 값을 냈다' || fail "빈 기본 브랜치를 사유 없이 막음: $OUT"
# 유효한 보고서 커밋 → 통과 (보고서 커밋으로 HEAD 가 바뀌어도 하네스 트리가 같다). managed=false 도 유효하다 — 보호 계층은 범위 밖
EV=$(git -C "$R" rev-parse HEAD)
report "$EV" '[]' '[]' false '["a","s1"]' > "$R/.claude/harness/reports/$EV.json"
git -C "$R" add -A; git -C "$R" commit -q -m report
OUT=$(inp "gh pr create --base develop" | sh "$G" 2>&1); [ -z "$OUT" ] || fail "유효한 보고서인데 deny: $OUT"
OUT=$(inp "gh pr create --title t" | PATH="$T/bin:$PATH" sh "$G" 2>&1); [ -z "$OUT" ] || fail "--base 없는 create 가 유효한 보고서인데 deny: $OUT"
OUT=$(inp "gh pr create --base=develop" | sh "$G" 2>&1); [ -z "$OUT" ] || fail "--base= 형태가 유효한 보고서인데 deny: $OUT"
OUT=$(inp "gh pr create -B develop" | sh "$G" 2>&1); [ -z "$OUT" ] || fail "-B 형태가 유효한 보고서인데 deny: $OUT"
# cwd 가 하위 디렉터리여도 같은 판정
OUT=$(printf '{"tool_name":"Bash","cwd":"%s/src","tool_input":{"command":"gh pr create --base develop"}}' "$R" | sh "$G" 2>&1); [ -z "$OUT" ] || fail "하위 cwd 에서 deny: $OUT"
# 경로 접두·--squash 가 붙은 merge 도 대상이다 (gh 스텁이 현재 PR 의 head/base 를 준다)
STUB_JSON=$(jq -cn --arg h "$(git -C "$R" rev-parse HEAD)" --arg b "$BASE" '{headRefOid:$h,baseRefOid:$b}')
OUT=$(inp "/opt/homebrew/bin/gh pr merge 7 --squash" | STUB_JSON="$STUB_JSON" PATH="$T/bin:$PATH" sh "$G" 2>&1); [ -z "$OUT" ] || fail "유효한 merge 인데 deny: $OUT"
# --repo · --head 형태는 지원하지 않는다 → deny
OUT=$(inp "gh --repo o/r pr merge 7" | STUB_JSON="$STUB_JSON" PATH="$T/bin:$PATH" sh "$G"); printf '%s' "$OUT" | grep -q '"deny"' || fail "--repo 를 통과시킴"
OUT=$(inp "gh pr create --head other --base develop" | sh "$G"); printf '%s' "$OUT" | grep -q '"deny"' || fail "--head 를 통과시킴"
# 보고서 뒤에 하네스를 또 고침 → deny
echo r2 >> "$R/.claude/rules/r.md"; git -C "$R" add -A; git -C "$R" commit -q -m r2
OUT=$(inp "gh pr create --base develop" | sh "$G"); printf '%s' "$OUT" | grep -q '"deny"' || fail "보고서 이후 변경을 놓침"
# 조건별 deny — 회귀 · 오류 · 사례 누락 · 세 필드짜리 위조 보고서
EV=$(git -C "$R" rev-parse HEAD)
chk() { # <이름> <report json>
  printf '%s' "$2" > "$R/.claude/harness/reports/$EV.json"; git -C "$R" add -A; git -C "$R" commit -q -m "$1"
  EV=$(git -C "$R" rev-parse HEAD)
  OUT=$(inp "gh pr create --base develop" | sh "$G"); printf '%s' "$OUT" | grep -q '"deny"' || fail "$1 보고서를 통과시킴"
  git -C "$R" rm -rq --cached .claude/harness/reports; git -C "$R" commit -q -m "rm-$1"; EV=$(git -C "$R" rev-parse HEAD)
  [ -z "$(git -C "$R" ls-files .claude/harness/reports)" ] || fail "$1 보고서가 인덱스에서 정리되지 않음"
}
chk regressed "$(report "$EV" '["a"]' '[]' true '["a","s1"]')"
chk errors "$(report "$EV" '[]' '["a"]' true '["a","s1"]')"
chk missing-case "$(report "$EV" '[]' '[]' true '["a"]')"
chk forged "$(jq -n --arg e "$EV" --arg b "$BASE" '{evaluated_sha:$e,base_sha:$b,regressed:[]}')"
# 낱말 언급만 있는 명령은 대상이 아니다 (하네스 변경 + 보고서 없음 상태에서도 통과해야 한다)
OUT=$(inp "printf 'gh pr merge docs' > x.md" | sh "$G" 2>&1); [ -z "$OUT" ] || fail "언급-only(printf)를 막음: $OUT"
OUT=$(inp "git commit -m 'gh pr create 게이트'" | sh "$G" 2>&1); [ -z "$OUT" ] || fail "언급-only(commit -m)를 막음: $OUT"
OUT=$(inp "gh pr view --json headRefOid" | sh "$G" 2>&1); [ -z "$OUT" ] || fail "gh pr view 를 막음: $OUT"
# 실제 호출은 세그먼트 뒤·경로 접두·환경변수 접두에서도 잡힌다
OUT=$(inp "echo hi; gh pr create --base develop" | sh "$G"); printf '%s' "$OUT" | grep -q '"deny"' || fail "세그먼트 뒤 호출을 놓침"
OUT=$(inp "FOO=1 /opt/homebrew/bin/gh pr create --base develop" | sh "$G"); printf '%s' "$OUT" | grep -q '"deny"' || fail "env·경로 접두 호출을 놓침"
# heredoc 본문의 0열 gh 호출 줄은 데이터다 → 통과
CMDH=$(printf 'cat > note.md <<'"'"'EOF'"'"'\ngh pr merge 7 --squash\nEOF')
OUT=$(printf '{"tool_name":"Bash","cwd":"%s","tool_input":{"command":%s}}' "$R" "$(printf '%s' "$CMDH" | jq -Rs .)" | sh "$G" 2>&1); [ -z "$OUT" ] || fail "heredoc 본문의 호출 줄을 막음: $OUT"
# 줄바꿈으로 나뉜 실제 호출은 잡힌다 → deny
CMDN=$(printf 'cd %s\ngh pr create --base develop' "$R")
OUT=$(printf '{"tool_name":"Bash","cwd":"%s","tool_input":{"command":%s}}' "$R" "$(printf '%s' "$CMDN" | jq -Rs .)" | sh "$G"); printf '%s' "$OUT" | grep -q '"deny"' || fail "줄바꿈 뒤 호출을 놓침"
# heredoc 이 끝난 뒤의 호출은 잡힌다 → deny
CMDA=$(printf 'cat > note.md <<EOF\nhello\nEOF\ngh pr create --base develop')
OUT=$(printf '{"tool_name":"Bash","cwd":"%s","tool_input":{"command":%s}}' "$R" "$(printf '%s' "$CMDA" | jq -Rs .)" | sh "$G"); printf '%s' "$OUT" | grep -q '"deny"' || fail "heredoc 뒤 호출을 놓침"
# 따옴표 안의 << 는 heredoc 이 아니다 — 종료자 미발견 → 원문 매칭 → 뒤 줄의 실제 호출을 잡는다 (deny)
CMDQ=$(printf 'echo "score << expected"\ngh pr create --base develop')
OUT=$(printf '{"tool_name":"Bash","cwd":"%s","tool_input":{"command":%s}}' "$R" "$(printf '%s' "$CMDQ" | jq -Rs .)" | sh "$G"); printf '%s' "$OUT" | grep -q '"deny"' || fail "따옴표 안 << 뒤의 호출을 놓침 (우회)"
# 탭 들여쓴 <<- 종료자도 폴백으로 잡힌다 (deny)
CMDT=$(printf 'cat <<-EOF\nhello\n\tEOF\ngh pr create --base develop')
OUT=$(printf '{"tool_name":"Bash","cwd":"%s","tool_input":{"command":%s}}' "$R" "$(printf '%s' "$CMDT" | jq -Rs .)" | sh "$G"); printf '%s' "$OUT" | grep -q '"deny"' || fail "탭 들여쓴 <<- 뒤의 호출을 놓침 (우회)"
# gh 가 아닌 명령 → 통과
OUT=$(inp "git push" | sh "$G" 2>&1); [ -z "$OUT" ] || fail "무관한 명령을 막음"
# fail-closed
inp "gh pr create" | PATH=/bin sh "$G" >/dev/null 2>&1; [ $? = 2 ] || fail "jq 없을 때 exit 2 아님"
echo "PASS test-gate"
