# 저장소 지침 예시 — `.claude/wt.md`

`herdr-wt` 의 `wt`·`wt-done` 스킬이 시작할 때 읽는다. 자유형 마크다운이다 — 이 파일을 복사해 필요한 절만 남긴다. 스킬은 이 지침으로 단계를 더하거나 값을 정하되, 단계의 순서와 승인·재확인 지점은 바꾸지 않는다.

## 브랜치

- base 는 `main`
- 종류는 `feature`·`fix`·`docs`·`chore`

## 이슈 트래커 — Jira

- 프로젝트 `MGR`. 이슈 키로 직접 조회한다 — JQL 은 사이트에 따라 비ASCII 값에 0건을 반환한다
- 착수: 전환 id `31` 로 진행 중으로 옮긴다. **조회한 상태가 이미 완료면 옮기지 않는다** — 완료 이슈에 전환을 걸면 `isGlobal` 이라 조용히 재오픈된다
- 완료 여부는 상태 이름이 아니라 `statusCategory` 가 `done` 인지로 본다 — 상태 이름은 워크플로마다 다르다
- 마감: 전환 id `41` + 결과 코멘트. 전환 id 는 워크플로마다 다르니 실패하면 `getTransitionsForJiraIssue` 로 다시 얻는다
- MCP 도구 이름은 설치마다 접두사가 다르다 — `getJiraIssue` 같은 이름으로 찾는다

## 이슈 트래커 — GitHub Issues

- 조회는 `gh issue view <번호>`. 착수 시 상태 전환은 없다 — 브랜치와 PR 이 그 신호다
- 마감: `gh issue close <번호>` + `gh issue comment`. PR 본문의 `Closes #<번호>` 는 **base 가 기본 브랜치일 때만** 머지 시점에 이슈를 닫는다 — `develop` 같은 다른 base 면 닫히지 않는다. 어느 쪽이든 `state` 를 먼저 보고, 열려 있으면 직접 닫는다

## 결과 코멘트에 담을 것

이슈를 다시 여는 사람이 PR 을 열지 않고도 알아야 하는 것이다.

- PR 링크
- 이슈가 지목하지 않았지만 함께 고친 것 — 왜 그것까지 건드렸는지
- 이슈의 서술이 틀렸던 지점
- 실측으로 닫은 판단 — 무엇을 재서 무엇을 하지 않기로 했는지
- 작업 중 발견한 무관한 결함

## 에이전트

- claude 는 `--model opus` 로 띄운다 — `herdr agent start ... -- --model opus`. 인자에 `--kind` 가 없을 때의 기본이다
- codex 는 `--yolo` 대신 `--add-dir` 로 범위를 좁힌다
