#!/bin/sh
# receipt.sh <target> <exit> — fixture 의 Makefile recipe 가 부른다.
# $EVAL_RECEIPTS 에 한 줄을 덧붙이고 ID 를 stdout 에 찍어 모델이 증거로 옮길 수 있게 한다.
# via_make — make recipe 안에서 불렸는지 (make 가 MAKELEVEL 을 넣는다). grader 는 via_make:true 만 실행 증거로 본다.
# ponytail: 비적대적 전제 — MAKELEVEL 을 손으로 넣고 직접 부르면 구별하지 못한다.
set -u
: "${EVAL_RECEIPTS:?EVAL_RECEIPTS 가 없다}"
VIA=false; [ -n "${MAKELEVEL:-}" ] && VIA=true
N=$(( $( (wc -l < "$EVAL_RECEIPTS") 2>/dev/null || echo 0 ) + 1 ))
printf '{"id":"r%s","target":"%s","exit":%s,"via_make":%s}\n' "$N" "$1" "$2" "$VIA" >> "$EVAL_RECEIPTS"
echo "[receipt r$N target=$1 exit=$2]"
