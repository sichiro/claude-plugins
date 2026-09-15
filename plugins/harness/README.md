# harness

자기 개선 하네스 엔진. 세션 원장을 모으고, 반복 실패를 관찰(OBS)하고, 변경 하나를 제안(IMP)해 eval 로 기준선과 비교하고, 보고서 없는 하네스 PR 을 막는다. 프로젝트에 남는 것은 `.claude/harness/` 한 디렉터리다.

## 엔진 개발자용

- 에이전트 호출명: `harness:harness-observer` · `harness:harness-proposer` — `claude --plugin-dir` 로 실측한 값이다(플러그인 이름이 접두로 붙는다). 스킬은 이 값을 `subagent_type` 에 쓴다.
