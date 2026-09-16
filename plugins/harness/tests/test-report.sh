#!/bin/sh
set -u
E=$(cd "$(dirname "$0")/../evals" && pwd)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
fail() { echo "FAIL test-report: $1"; exit 1; }
meta() { mkdir -p "$1"; jq -n --arg h "$2" --arg s "$3" --arg d "$4" --argjson m "$5" --arg mo "${6:-m1}" --argjson r "${7:-1}" \
  '{harness_sha:$h,suite_sha:$s,sealed_digest:$d,managed:$m,model:$mo,claude_version:"2.1.270",repeat:$r,generated_at:"t"}' > "$1/meta.json"; }
meta "$T/base" B111 S333 D444 true; meta "$T/cand" C222 S333 D444 true
printf '{"case":"a","verdict":"PASS"}\n{"case":"b","verdict":"FAIL"}\n{"case":"c","verdict":"PASS"}\n{"case":"d","verdict":"ERROR"}\n' > "$T/base/results.jsonl"
printf '{"case":"a","verdict":"PASS"}\n{"case":"b","verdict":"PASS"}\n{"case":"c","verdict":"FAIL"}\n{"case":"d","verdict":"ERROR"}\n' > "$T/cand/results.jsonl"
sh "$E/report.sh" "$T/base" "$T/cand" "$T/deep/dir/r.json" >/dev/null || fail "exit $?"
R="$T/deep/dir/r.json"
[ -f "$R" ] || fail "부모 디렉터리를 만들지 않음"
[ "$(jq -r .evaluated_sha "$R")" = C222 ] || fail "evaluated_sha"
[ "$(jq -r .base_sha "$R")" = B111 ] || fail "base_sha"
[ "$(jq -r .suite_sha "$R")" = S333 ] || fail "suite_sha"
[ "$(jq -r .sealed_digest "$R")" = D444 ] || fail "sealed_digest"
[ "$(jq -r .model "$R")" = m1 ] || fail "model"
[ "$(jq -r .claude_version.candidate "$R")" = 2.1.270 ] || fail "claude_version"
[ "$(jq -r .managed "$R")" = true ] || fail "managed"
[ "$(jq -r '.improved|join(",")' "$R")" = b ] || fail "improved"
[ "$(jq -r '.regressed|join(",")' "$R")" = c ] || fail "regressed"
[ "$(jq -r '.unchanged|join(",")' "$R")" = a ] || fail "unchanged"
[ "$(jq -r '.errors|join(",")' "$R")" = d ] || fail "errors"
[ "$(jq '.cases|length' "$R")" = 4 ] || fail "cases"
[ "$(jq -r '.cases[]|select(.case=="a")|.base' "$R")" = "1/1" ] || fail "N=1 의 base 표기가 1/1 아님"
[ "$(jq -r '.cases[]|select(.case=="d")|.base' "$R")" = ERROR ] || fail "전부 ERROR 인 사례의 표기"
# 후보가 ERROR 로 망가진 사례는 errors 에 남는다 (게이트가 errors 를 막는다)
printf '{"case":"a","verdict":"ERROR"}\n' > "$T/cand/results.jsonl"; printf '{"case":"a","verdict":"PASS"}\n' > "$T/base/results.jsonl"
sh "$E/report.sh" "$T/base" "$T/cand" "$R" >/dev/null || fail "exit(2) $?"
[ "$(jq -r '.errors|join(",")' "$R")" = a ] || fail "후보 ERROR 가 errors 에 없음"
[ "$(jq -r '.regressed|length' "$R")" = 0 ] || fail "후보 ERROR 가 regressed 에 들어감"
# 후보에서 사라진 사례는 errors 와 regressed 양쪽에 남는다 (fail-closed)
printf '{"case":"a","verdict":"PASS"}\n{"case":"gone","verdict":"PASS"}\n' > "$T/base/results.jsonl"
printf '{"case":"a","verdict":"PASS"}\n' > "$T/cand/results.jsonl"
sh "$E/report.sh" "$T/base" "$T/cand" "$R" >/dev/null || fail "exit(4) $?"
[ "$(jq -r '.errors|join(",")' "$R")" = gone ] || fail "사라진 사례가 errors 에 없음"
[ "$(jq -r '.regressed|join(",")' "$R")" = gone ] || fail "사라진 사례가 regressed 에 없음"
[ "$(jq -r '.cases[]|select(.case=="gone")|.candidate' "$R")" = MISSING ] || fail "사라진 사례의 candidate 가 MISSING 아님"
# 반복 실행 — 비율로 비교한다. a: 2/3 → 3/3 개선, b: 3/3 → 2/3 회귀, c: 1/2(ERROR 1 제외) → 2/3 개선
meta "$T/base" B111 S333 D444 true m1 3; meta "$T/cand" C222 S333 D444 true m1 3
printf '{"case":"a","verdict":"PASS","run":1}\n{"case":"a","verdict":"PASS","run":2}\n{"case":"a","verdict":"FAIL","run":3}\n{"case":"b","verdict":"PASS","run":1}\n{"case":"b","verdict":"PASS","run":2}\n{"case":"b","verdict":"PASS","run":3}\n{"case":"c","verdict":"PASS","run":1}\n{"case":"c","verdict":"FAIL","run":2}\n{"case":"c","verdict":"ERROR","run":3}\n' > "$T/base/results.jsonl"
printf '{"case":"a","verdict":"PASS","run":1}\n{"case":"a","verdict":"PASS","run":2}\n{"case":"a","verdict":"PASS","run":3}\n{"case":"b","verdict":"PASS","run":1}\n{"case":"b","verdict":"FAIL","run":2}\n{"case":"b","verdict":"PASS","run":3}\n{"case":"c","verdict":"FAIL","run":1}\n{"case":"c","verdict":"PASS","run":2}\n{"case":"c","verdict":"PASS","run":3}\n' > "$T/cand/results.jsonl"
sh "$E/report.sh" "$T/base" "$T/cand" "$R" >/dev/null || fail "exit(5) $?"
[ "$(jq -r '.improved|join(",")' "$R")" = "a,c" ] || fail "반복: improved 가 a,c 아님 (c 는 1/2 → 2/3)"
[ "$(jq -r '.regressed|join(",")' "$R")" = b ] || fail "반복: regressed"
[ "$(jq -r '.unchanged|length' "$R")" = 0 ] || fail "반복: unchanged 가 비어야 함"
[ "$(jq -r '.cases[]|select(.case=="a")|.base' "$R")" = "2/3" ] || fail "반복: a base 표기"
[ "$(jq -r '.cases[]|select(.case=="c")|.base' "$R")" = "1/2" ] || fail "반복: c base 표기 (ERROR 는 분모 제외)"
[ "$(jq -r '.repeat.candidate' "$R")" = 3 ] || fail "repeat 가 보고서에 없음"
# 한쪽만 managed=false 면 false
meta "$T/cand" C222 S333 D444 false m1 3
sh "$E/report.sh" "$T/base" "$T/cand" "$R" >/dev/null || fail "exit(3) $?"
[ "$(jq -r .managed "$R")" = false ] || fail "managed 가 AND 가 아님"
# model 이 다르면 exit 2
meta "$T/cand" C222 S333 D444 true m2 3
sh "$E/report.sh" "$T/base" "$T/cand" "$R" >/dev/null 2>&1; [ $? = 2 ] || fail "model 불일치인데 exit 2 아님"
# suite 가 다르면 exit 2
meta "$T/cand" C222 S999 D444 true m1 3
sh "$E/report.sh" "$T/base" "$T/cand" "$R" >/dev/null 2>&1; [ $? = 2 ] || fail "suite 불일치인데 exit 2 아님"
echo "PASS test-report"
