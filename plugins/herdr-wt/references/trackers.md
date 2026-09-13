# 이슈 트래커별 명령

`wt` 와 `wt-done` 이 함께 읽는다.

저장소가 어느 트래커를 쓰는지는 `.claude/wt.json` 의 `tracker.type` **만으로** 판정한다. remote 주소로 추정하지 않는다 — Jira 를 쓰면서 GitHub remote 를 가진 저장소가 실재한다.

**`tracker` 가 없으면 아래 연산을 전부 생략하고** worktree 와 에이전트만 준비한다.

| 연산 | Jira (`"type": "jira"`) | GitHub Issues (`"type": "github"`) |
|---|---|---|
| 조회 | `getJiraIssue(issueIdOrKey)` — 유형·요약·상태를 얻는다 | `gh issue view <번호> --json title,state,body,labels` |
| 진행 중 전환 | `transitionJiraIssue(issueIdOrKey, transition: {id: <transitions.inProgress>})` | **없다 — 생략한다** |
| 완료 전환 | `transitionJiraIssue(issueIdOrKey, transition: {id: <transitions.done>})` | `gh issue close <번호>` |
| 코멘트 | `addOrEditJiraIssueComment(issueIdOrKey, commentBody)` | `gh issue comment <번호> --body "<본문>"` |

## Jira

- **JQL 로 찾지 않는다.** 이 사이트의 JQL 은 한글 값에 0건을 반환한다. 이슈 키로 직접 조회한다
- **상태를 이름으로 지정할 자리가 없다.** 전환 id 로만 지정하고, 그 값은 `wt.json` 의 `tracker.transitions` 에서 읽는다. 실패하면 `getTransitionsForJiraIssue` 로 다시 얻는다
- **완료 이슈에 진행 중 전환을 걸지 않는다.** 그 전환은 `isGlobal` 이라 완료 이슈에도 그대로 걸려 **조용히 재오픈시킨다.** 게다가 `hasScreen: false` 라 `resolution` 을 비울 화면이 없어, 상태만 진행 중이고 `resolution` 은 완료로 남는다. 조회한 상태로 먼저 가른다
- **MCP 도구 이름은 설치마다 접두사가 다르다.** `getJiraIssue` 라는 이름으로 찾고, 접두사를 문서에 박지 않는다

## GitHub Issues

- **「진행 중」 상태가 없다.** open/closed 두 상태뿐이라 착수 시점을 트래커에 남기지 않는다. 브랜치와 PR 이 그 신호다
- **PR 본문에 `Closes #<번호>` 가 있으면 머지 시점에 이슈가 이미 닫힌다.** 완료 전환 전에 `state` 를 확인하고, `CLOSED` 면 전환을 생략하고 코멘트만 남긴다
- 이슈 번호는 `#` 없이 넘긴다 — `gh issue view 135`
