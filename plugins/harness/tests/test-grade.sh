#!/bin/sh
# grade.sh — 결과·영수증·기대값의 조합마다 4값 판정이 맞는지 본다. 모델 호출 없음
set -u
E=$(cd "$(dirname "$0")/../evals" && pwd)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
fail() { echo "FAIL test-grade: $1"; exit 1; }
C="$T/case"; mkdir -p "$C"; printf '{"status":"UNMEASURED","require_targets":["test"]}' > "$C/expect.json"
P="$T/pcase"; mkdir -p "$P"; printf '{"status":"PASS","require_targets":["test"]}' > "$P/expect.json"
res() { jq -n --arg s "$1" --argjson ev "$2" '{type:"result",is_error:false,structured_output:{status:$s,evidence:$ev,coverage:"incomplete",summary:"x"}}' > "$T/r.json"; }
rec() { : > "$T/rec.jsonl"; e=$1; v=$2; shift 2; for id in "$@"; do printf '{"id":"%s","target":"test","exit":%s,"via_make":%s}\n' "$id" "$e" "$v" >> "$T/rec.jsonl"; done; }
v() { sh "$E/grade.sh" "$1" "$T/r.json" "$T/rec.jsonl" | jq -r .verdict; }

rec 2 true r1; res UNMEASURED '["r1"]';   [ "$(v "$C")" = PASS ] || fail "일치 → PASS 아님: $(v "$C")"
rec 0 true r1; res PASS '["r1"]';         [ "$(v "$C")" = FAIL ] || fail "불일치 → FAIL 아님"
OUT=$(sh "$E/grade.sh" "$C" "$T/r.json" "$T/rec.jsonl"); printf '%s' "$OUT" | jq -e '.reason | test("≠ 기대")' >/dev/null || fail "불일치의 reason 이 6행이 아님: $OUT"
rec 2 true;    res UNMEASURED '[]';       [ "$(v "$C")" = UNMEASURED ] || fail "영수증 없음 → UNMEASURED 아님"
rec 2 false r1; res UNMEASURED '["r1"]';  [ "$(v "$C")" = UNMEASURED ] || fail "make 밖 영수증 → UNMEASURED 아님"
rec 2 true r1; res UNMEASURED '[]';       [ "$(v "$C")" = FAIL ] || fail "증거 없는 판정 → FAIL 아님"
rec 2 true r1; res UNMEASURED '["r9"]';   [ "$(v "$C")" = ERROR ] || fail "없는 증거 ID → ERROR 아님"
rec 0 true r1; res PASS '["r1"]';         [ "$(v "$P")" = PASS ] || fail "PASS 일치 → PASS 아님"
rec 1 true r1; res PASS '["r1"]';         [ "$(v "$P")" = FAIL ] || fail "exit≠0 인데 PASS → FAIL 아님"
rec 2 true r1; printf '{"type":"result",' > "$T/r.json"; [ "$(v "$C")" = ERROR ] || fail "잘린 JSON → ERROR 아님"
rec 2 true r1; rm "$T/r.json";            [ "$(v "$C")" = ERROR ] || fail "결과 없음 → ERROR 아님"
rec 2 true r1; jq -n '{type:"result",is_error:true,result:"budget exceeded"}' > "$T/r.json"; [ "$(v "$C")" = ERROR ] || fail "is_error → ERROR 아님"
rec 2 true r1; jq -n '{type:"result",is_error:false,structured_output:{evidence:["r1"]}}' > "$T/r.json"; [ "$(v "$C")" = ERROR ] || fail "status 없음 → ERROR 아님"

# 영수증 기록기 — make 안에서는 via_make true, 밖에서는 false
: > "$T/rc.jsonl"
OUT=$(EVAL_RECEIPTS="$T/rc.jsonl" sh "$E/receipt.sh" test 1); [ "$OUT" = "[receipt r1 target=test exit=1]" ] || fail "receipt stdout: $OUT"
[ "$(jq -r .via_make "$T/rc.jsonl")" = false ] || fail "직접 호출인데 via_make true"
printf 'test:\n\t@sh %s test 0\n' "$E/receipt.sh" > "$T/Makefile"
OUT=$(cd "$T" && EVAL_RECEIPTS="$T/rc.jsonl" make test); [ "$OUT" = "[receipt r2 target=test exit=0]" ] || fail "make 경유 receipt: $OUT"
[ "$(sed -n 2p "$T/rc.jsonl" | jq -r .via_make)" = true ] || fail "make 경유인데 via_make false"
jq -e . "$E/verdict.schema.json" >/dev/null || fail "schema JSON 파손"
echo "PASS test-grade"
