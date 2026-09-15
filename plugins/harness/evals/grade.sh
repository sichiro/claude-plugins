#!/bin/sh
# grade.sh <case dir> <claude 결과 json> <영수증 jsonl> → {"case","verdict","expected","reason"} 한 줄
# 판정 순서는 계획서 Task 5 의 표와 같다.
set -u
CASE=$1; RES=$2; REC=$3
EXP=$(jq -r '.status' "$CASE/expect.json")
emit() { jq -cn --arg c "$(basename "$CASE")" --arg v "$1" --arg e "$EXP" --arg r "$2" '{case:$c,verdict:$v,expected:$e,reason:$r}'; exit 0; }
[ -s "$RES" ] || emit ERROR "결과 파일 없음"
jq -e . "$RES" >/dev/null 2>&1 || emit ERROR "결과 JSON 파손"
[ "$(jq -r '.is_error // false' "$RES")" = false ] || emit ERROR "러너 오류: $(jq -r '.result // ""' "$RES" | head -c 120)"
ST=$(jq -r '.structured_output.status // empty' "$RES")
[ -n "$ST" ] || emit ERROR "structured_output.status 없음"
for t in $(jq -r '.require_targets[]?' "$CASE/expect.json"); do
  jq -e --arg t "$t" 'select(.target==$t and .via_make==true)' "$REC" >/dev/null 2>&1 || emit UNMEASURED "필수 target 이 make 를 통해 실행되지 않음: $t"
done
if [ "$ST" != ERROR ]; then
  [ "$(jq -r '.structured_output.evidence | length' "$RES")" -gt 0 ] || emit FAIL "증거 없는 판정"
fi
for ev in $(jq -r '.structured_output.evidence[]?' "$RES"); do
  jq -e --arg id "$ev" 'select(.id==$id and .via_make==true)' "$REC" >/dev/null 2>&1 || emit ERROR "영수증에 없는 증거 ID: $ev"
done
if [ "$ST" = PASS ]; then
  jq -e 'select(.via_make==true and .exit!=0)' "$REC" >/dev/null 2>&1 && emit FAIL "status PASS 인데 exit≠0 영수증이 있다"
fi
[ "$ST" = "$EXP" ] && emit PASS "status 일치" || emit FAIL "status $ST ≠ 기대 $EXP"
