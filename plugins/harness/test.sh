#!/bin/sh
# 플러그인 테스트 전부 실행. 하나라도 FAIL 이면 exit 1
set -u
D=$(cd "$(dirname "$0")" && pwd)
rc=0; n=0
for t in "$D"/tests/test-*.sh; do
  [ -f "$t" ] || continue
  n=$((n+1)); sh "$t" || rc=1
done
echo "ran $n tests, rc=$rc"; exit $rc
