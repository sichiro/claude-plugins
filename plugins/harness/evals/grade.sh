#!/bin/sh
# grade.sh <case dir> <claude 결과 json> <영수증 jsonl> → {"case","verdict","expected","reason"} 한 줄
# 판정 순서는 계획서 Task 5 의 표와 같다.
# 귀책 — ERROR 는 러너 귀책(결과 없음·JSON 파손·실행 중 오류)에만 쓴다. 모델 귀책(예산·턴·구조화 출력 재시도 소진·timeout·구조화 출력 누락·증거 날조)은 FAIL 이다.
# 날조가 ERROR 면 분모에서 빠져 정직한 오답보다 좋은 점수를 받는다.
set -u
CASE=$1; RES=$2; REC=$3
EXP=$(jq -r '.status' "$CASE/expect.json")
emit() { jq -cn --arg c "$(basename "$CASE")" --arg v "$1" --arg e "$EXP" --arg r "$2" '{case:$c,verdict:$v,expected:$e,reason:$r}'; exit 0; }
[ -s "$RES" ] || emit ERROR "결과 파일 없음"
jq -e . "$RES" >/dev/null 2>&1 || emit ERROR "결과 JSON 파손"
if [ "$(jq -r '.is_error // false' "$RES")" != false ]; then
  SUB=$(jq -r '.subtype // ""' "$RES"); MSG=$(jq -r '.result // ""' "$RES" | head -c 120)
  case "$SUB" in
    error_max_turns|error_max_budget_usd|error_max_structured_output_retries|error_timeout) emit FAIL "모델이 끝내지 못했다: $SUB $MSG";;
    *) emit ERROR "러너 오류: $SUB $MSG";;
  esac
fi
ST=$(jq -r '.structured_output.status // empty' "$RES")
[ -n "$ST" ] || emit FAIL "structured_output.status 없음 — 구조화 출력 누락"
for t in $(jq -r '.require_targets[]?' "$CASE/expect.json"); do
  jq -e --arg t "$t" 'select(.target==$t and .via_make==true)' "$REC" >/dev/null 2>&1 || emit UNMEASURED "필수 target 이 make 를 통해 실행되지 않음: $t"
done
if [ "$ST" != ERROR ]; then
  [ "$(jq -r '.structured_output.evidence | length' "$RES")" -gt 0 ] || emit FAIL "증거 없는 판정"
fi
for ev in $(jq -r '.structured_output.evidence[]?' "$RES"); do
  jq -e --arg id "$ev" 'select(.id==$id and .via_make==true)' "$REC" >/dev/null 2>&1 || emit FAIL "영수증에 없는 증거 ID(날조): $ev"
done
if [ "$ST" = PASS ]; then
  jq -e 'select(.via_make==true and .exit!=0)' "$REC" >/dev/null 2>&1 && emit FAIL "status PASS 인데 exit≠0 영수증이 있다"
fi
[ "$ST" = "$EXP" ] && emit PASS "status 일치" || emit FAIL "status $ST ≠ 기대 $EXP"
