# 저장소 지침 — herdr-wt

## 브랜치

- base 는 `develop`
- 종류는 `feature`·`fix`·`docs`·`chore`

## 이슈 트래커 — GitHub Issues

- 이 저장소 `sichiro/claude-plugins` 의 이슈를 쓴다
- 조회는 `gh issue view <번호>`. 착수 시 상태 전환은 없다 — 브랜치와 PR 이 그 신호다
- 마감: `gh issue close <번호>` + `gh issue comment`. PR 본문에 `Closes #<번호>` 가 있으면 머지 시점에 이미 닫혀 있으니 `state` 를 먼저 본다

## 결과 코멘트에 담을 것

이슈를 다시 여는 사람이 PR 을 열지 않고도 알아야 하는 것이다.

- PR 링크
- 이슈가 지목하지 않았지만 함께 고친 것 — 왜 그것까지 건드렸는지
- 이슈의 서술이 틀렸던 지점
- 실측으로 닫은 판단 — 무엇을 재서 무엇을 하지 않기로 했는지
- 작업 중 발견한 무관한 결함

## 에이전트

- codex 는 `--yolo` 대신 `--add-dir` 로 범위를 좁힌다
