#!/bin/sh
# report.sh <base out dir> <cand out dir> <out json>
# 사례마다 통과 비율(PASS 수 / ERROR 아닌 실행 수)을 기준선·후보로 비교한다. --repeat 1 이면 종전 판정과 같다.
# 개선 = 후보 비율 > 기준선. 회귀 = 후보 비율 < 기준선. 불변 = 같음.
# 유효 실행이 0(전부 ERROR)이거나 사례가 없으면(MISSING) errors 에 넣고 비율 판정에서 뺀다 — 게이트가 errors 를 따로 막는다.
# MISSING 은 예외 — 기준선 비율이 0 보다 크면 regressed 에도 남긴다 (fail-closed: 후보에서 사라진 사례).
# 기준선과 후보의 suite·봉인 묶음·model 이 다르면 만들지 않는다 — 다른 시험·다른 모델의 성적을 한 표에 섞지 않는다.
set -eu
B=$1; C=$2; OUT=$3
for d in "$B" "$C"; do [ -s "$d/meta.json" ] && [ -s "$d/results.jsonl" ] || { echo "$d 에 meta.json·results.jsonl 이 없다" >&2; exit 2; }; done
for k in suite_sha sealed_digest model; do
  [ "$(jq -r ".$k" "$B/meta.json")" = "$(jq -r ".$k" "$C/meta.json")" ] || { echo "기준선과 후보의 $k 가 다르다 — 같은 suite·봉인 묶음·모델로 다시 돈다" >&2; exit 2; }
done
mkdir -p "$(dirname "$OUT")"
jq -n --slurpfile bm "$B/meta.json" --slurpfile cm "$C/meta.json" --slurpfile b "$B/results.jsonl" --slurpfile c "$C/results.jsonl" \
  --arg ts "$(date +%Y-%m-%dT%H:%M:%S%z)" '
  def tally: group_by(.case) | map({key:.[0].case, value:{n:(map(select(.verdict!="ERROR"))|length), k:(map(select(.verdict=="PASS"))|length)}}) | from_entries;
  def rate($t): if $t == null or $t.n == 0 then null else ($t.k / $t.n) end;
  def show($t): if $t == null then "MISSING" elif $t.n == 0 then "ERROR" else "\($t.k)/\($t.n)" end;
  ($b | tally) as $B | ($c | tally) as $C
  | ([$B,$C] | map(keys[]) | unique) as $cases
  | ($cases | map(. as $n | {case:$n, base:show($B[$n]), candidate:show($C[$n]), base_rate:rate($B[$n]), cand_rate:rate($C[$n])})) as $rows
  | {evaluated_sha:$cm[0].harness_sha, base_sha:$bm[0].harness_sha, suite_sha:$cm[0].suite_sha, sealed_digest:$cm[0].sealed_digest,
     model:$cm[0].model, claude_version:{base:$bm[0].claude_version, candidate:$cm[0].claude_version}, repeat:{base:$bm[0].repeat, candidate:$cm[0].repeat},
     managed:($bm[0].managed and $cm[0].managed), generated_at:$ts, cases:$rows,
     errors:    ($rows | map(select(.base_rate == null or .cand_rate == null) | .case)),
     improved:  ($rows | map(select(.base_rate != null and .cand_rate != null and .cand_rate > .base_rate) | .case)),
     regressed: ($rows | map(select((.base_rate != null and .cand_rate != null and .cand_rate < .base_rate) or (.candidate == "MISSING" and .base_rate != null and .base_rate > 0)) | .case)),
     unchanged: ($rows | map(select(.base_rate != null and .cand_rate != null and .cand_rate == .base_rate) | .case))}' > "$OUT"
jq -r '"improved \(.improved|length) · regressed \(.regressed|length) · unchanged \(.unchanged|length) · errors \(.errors|length) · managed \(.managed) · model \(.model)"' "$OUT"
