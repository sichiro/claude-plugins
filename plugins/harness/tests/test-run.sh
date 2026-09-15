#!/bin/sh
# run.sh — materialize 에 정답·프로젝트 데이터·플러그인 활성화가 없고, dry-run 이 meta 와 grade 까지 이어지는지 본다. 모델 호출 없음
set -u
E=$(cd "$(dirname "$0")/../evals" && pwd)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
fail() { echo "FAIL test-run: $1"; exit 1; }
# 임시 프로젝트 — 하네스(CLAUDE.md · .claude/rules · settings.json) + 사례 하나
P="$T/proj"; C="$P/.claude/harness/cases/ok-all"; mkdir -p "$P/.claude/rules" "$C/fixture"
echo '# proj' > "$P/CLAUDE.md"; echo r > "$P/.claude/rules/r.md"
printf '{"enabledPlugins":{"harness@sichiro":true},"permissions":{"allow":["Bash(make *)"]}}' > "$P/.claude/settings.json"
echo 'make check 를 실행하고 판정하라' > "$C/prompt.md"
printf '{"status":"PASS","require_targets":["check"]}' > "$C/expect.json"
printf 'check:\n\t@sh .harness-receipt.sh check 0\n\t@echo 통과\n' > "$C/fixture/Makefile"
printf '{"type":"result","subtype":"success","is_error":false,"structured_output":{"status":"PASS","evidence":["r1"],"coverage":"complete","summary":"ok"}}' > "$C/dry-run.result.json"
git -C "$P" init -q -b develop; git -C "$P" add -A; git -C "$P" commit -q -m init
SHA=$(git -C "$P" rev-parse HEAD)
run() { CLAUDE_PROJECT_DIR="$P" sh "$E/run.sh" "$@"; }

run --materialize "$C" "$T/work" --harness "$SHA" || fail "materialize exit $?"
[ -f "$T/work/CLAUDE.md" ] || fail "CLAUDE.md 없음"
[ -f "$T/work/Makefile" ] || fail "fixture Makefile 없음"
[ -x "$T/work/.harness-receipt.sh" ] || fail "영수증 기록기 없음"
[ -d "$T/work/.claude/rules" ] || fail ".claude/rules 없음"
[ "$(find "$T/work" -name expect.json | wc -l | tr -d ' ')" = 0 ] || fail "정답이 work 에 있다"
[ -e "$T/work/.claude/harness" ] && fail "프로젝트 데이터(.claude/harness)가 work 에 있다"
jq -e '.enabledPlugins' "$T/work/.claude/settings.json" >/dev/null 2>&1 && fail "enabledPlugins 가 남아 있다 — 클린룸이 깨진다"
jq -e '.permissions.allow[0]=="Bash(make *)"' "$T/work/.claude/settings.json" >/dev/null || fail "settings.json 의 다른 키가 사라졌다"
# 없는 해시는 시작 전에 거부한다 (archive 실패가 파이프에서 묻히는 구멍)
run --materialize "$C" "$T/work2" --harness 0000000000000000000000000000000000000000 >/dev/null 2>&1 && fail "없는 해시를 통과시킴"
# CLAUDE.md 가 없는 커밋도 materialize 된다 — git archive 는 없는 pathspec 에 실패하므로 실재하는 경로만 넘겨야 한다
git -C "$P" checkout -q -b nomd; git -C "$P" rm -q CLAUDE.md; git -C "$P" commit -q -m no-claude-md
SHA2=$(git -C "$P" rev-parse HEAD); git -C "$P" checkout -q develop
run --materialize "$C" "$T/work3" --harness "$SHA2" || fail "CLAUDE.md 없는 커밋의 materialize exit $?"
[ ! -e "$T/work3/CLAUDE.md" ] || fail "CLAUDE.md 없는 커밋인데 CLAUDE.md 가 있다"
[ -d "$T/work3/.claude/rules" ] || fail "CLAUDE.md 없는 커밋의 .claude/rules 없음"

run --harness "$SHA" --out "$T/out" --dry-run || fail "dry-run exit $?"
[ -s "$T/out/results.jsonl" ] || fail "results.jsonl 없음"
N=$(ls -d "$P"/.claude/harness/cases/*/ | wc -l | tr -d ' ')
[ "$(wc -l < "$T/out/results.jsonl" | tr -d ' ')" = "$N" ] || fail "results 줄 수 ≠ 사례 수 $N"
jq -e 'select(.case=="ok-all" and .verdict=="PASS")' "$T/out/results.jsonl" >/dev/null || fail "ok-all dry-run 이 PASS 아님 (dry-run 이 require_targets 의 make check 를 돌려야 영수증이 생긴다): $(cat "$T/out/results.jsonl")"
[ "$(jq -r .harness_sha "$T/out/meta.json")" = "$SHA" ] || fail "meta.harness_sha"
[ "$(jq -r .suite_sha "$T/out/meta.json")" = "$(git -C "$P" rev-parse HEAD:.claude/harness/cases)" ] || fail "meta.suite_sha"
[ "$(jq -r .sealed_digest "$T/out/meta.json")" = none ] || fail "sealed 없이 digest 가 none 아님"
jq -e '.managed|type=="boolean"' "$T/out/meta.json" >/dev/null || fail "meta.managed"
[ "$(jq -r .model "$T/out/meta.json")" = dry-run ] || fail "dry-run 의 meta.model"
[ "$(jq -r .claude_version "$T/out/meta.json")" = dry-run ] || fail "dry-run 의 meta.claude_version"
[ "$(jq -r .repeat "$T/out/meta.json")" = 1 ] || fail "meta.repeat 기본값"
[ "$(jq -r 'select(.case=="ok-all")|.run' "$T/out/results.jsonl")" = 1 ] || fail "results 의 run 필드"
# --repeat 2 — 사례마다 두 줄, 파일명에 r<i>
run --harness "$SHA" --out "$T/out3" --dry-run --repeat 2 || fail "repeat exit $?"
[ "$(wc -l < "$T/out3/results.jsonl" | tr -d ' ')" = $((N*2)) ] || fail "repeat 2 의 줄 수"
[ "$(jq -r 'select(.case=="ok-all")|.run' "$T/out3/results.jsonl" | paste -sd, -)" = "1,2" ] || fail "repeat 2 의 run 번호"
[ -f "$T/out3/ok-all.r2.result.json" ] || fail "repeat 2 의 파일명"
[ "$(jq -r .repeat "$T/out3/meta.json")" = 2 ] || fail "meta.repeat"
run --harness "$SHA" --out "$T/out4" --dry-run --repeat 0 >/dev/null 2>&1; [ $? = 2 ] || fail "repeat 0 을 받아들임"
run --harness "$SHA" --out "$T/out5" --dry-run --repeat 01 >/dev/null 2>&1 || fail "repeat 01 을 거부함"
[ -f "$T/out5/ok-all.result.json" ] || fail "repeat 01 이 N=1 파일명을 쓰지 않음"
run --harness "$SHA" --out "$T/out6" --dry-run --repeat 08 >/dev/null 2>&1 || fail "repeat 08 을 거부함 (8진수 오독)"
[ "$(jq -r .repeat "$T/out6/meta.json")" = 8 ] || fail "repeat 08 의 meta.repeat 가 8 아님"
run --harness "$SHA" --out "$T/out7" --dry-run --repeat 00 >/dev/null 2>&1; [ $? = 2 ] || fail "repeat 00 을 받아들임"
# 봉인 묶음 — 프로젝트에 manifest 가 없으면 exit 2, 커밋한 manifest 와 맞으면 사례 수에 봉인 사례가 더해진다
mkdir -p "$T/sealed/s1/fixture"; cp "$C/prompt.md" "$C/expect.json" "$C/dry-run.result.json" "$T/sealed/s1/"; cp "$C/fixture/Makefile" "$T/sealed/s1/fixture/"
run --sealed-manifest "$T/sealed" > "$T/manifest"; [ "$(wc -l < "$T/manifest" | tr -d ' ')" = 1 ] || fail "manifest 줄 수"
run --harness "$SHA" --out "$T/out2" --dry-run --sealed "$T/sealed" >/dev/null 2>&1; [ $? = 2 ] || fail "manifest 없는데 exit 2 아님"
cp "$T/manifest" "$P/.claude/harness/sealed.manifest"; git -C "$P" add -A; git -C "$P" commit -q -m manifest; SHA=$(git -C "$P" rev-parse HEAD)
run --harness "$SHA" --out "$T/out8" --dry-run --sealed "$T/sealed" || fail "manifest 일치인데 exit $?"
[ "$(wc -l < "$T/out8/results.jsonl" | tr -d ' ')" = $((N+1)) ] || fail "봉인 사례가 results 에 더해지지 않음"
[ "$(jq -r .sealed_digest "$T/out8/meta.json")" != none ] || fail "sealed digest 가 none"
# timeout 없이도 dry-run 은 돈다 — timeout 은 실제 claude 호출 경로에서만 요구한다
B="$T/bin"; mkdir -p "$B"; for c in jq git shasum make; do ln -s "$(command -v "$c")" "$B/$c"; done
( PATH="$B:/usr/bin:/bin"; run --harness "$SHA" --out "$T/out9" --dry-run >/dev/null ) || fail "timeout 없는 PATH 에서 dry-run 실패"
echo "PASS test-run"
