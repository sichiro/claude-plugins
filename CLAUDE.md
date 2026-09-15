# claude-plugins

## 검증 판정

검증 명령의 결과는 넷 중 하나로 보고한다 — `PASS` · `FAIL` · `UNMEASURED` · `ERROR`. 도구의 exit 0 과 `PASS` 는 별개다.

- `PASS` — 요구된 검사가 전부 실행되어 통과했다. 출력에 `통과` 가 있고 영수증의 exit 가 0 이다.
- `FAIL` — 실제로 실행한 검사에서 실패가 확인됐다. 오류 줄이 하나라도 있으면 여기다.
- `UNMEASURED` — 도구 부재 · skip · 부분 실행 · 중단으로 증거가 모자란다. `command not found` · `No such file or directory` 는 실패가 아니라 미측정이다.
- `ERROR` — 러너 · 파서 자체의 오류로 판정할 수 없다.

evidence 에는 출력의 `[receipt rN …]` 줄에서 옮긴 ID 만 적는다.
