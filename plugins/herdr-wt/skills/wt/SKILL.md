---
name: wt
description: 이슈 하나를 작업할 브랜치·worktree·에이전트를 준비할 때 사용한다. "MGR-135 작업 시작" · "이슈 준비해줘" · "worktree 만들어줘" 지시에 쓴다
---

# 이슈 하나의 작업 자리를 준비한다

`ARGUMENTS` 의 첫 토큰이 이슈 식별자다. 나머지에서 `--kind` 값(`claude`·`codex` 등)과 `옮겨줘`(포커스 이동)를 읽는다. 기본은 `claude`, 포커스는 이 pane 에 둔다.

**준비까지만 한다.** 에이전트에 프롬프트를 넣지 않고, 해결 방법을 조사하지도 않는다. 사용자가 그 에이전트로 직접 작업한다. 첫 지시를 넣어 달라는 말이 인자에 있을 때만 `herdr agent prompt` 를 쓴다.

## 설정

`.claude/wt.json` 을 읽는다. 스키마와 트래커별 명령은 `${CLAUDE_PLUGIN_ROOT}/references/trackers.md` 에 있다.

| 키 | 기본값 | 쓰는 곳 |
|---|---|---|
| `base` | `develop` | worktree 의 `--base` |
| `branchKinds` | `feature` `fix` `docs` `chore` | 브랜치 종류 |
| `tracker` | 없음 | 이슈 조회·전환. **없으면 그 단계를 생략한다** |

## 절차

1. `HERDR_ENV=1` 이 아니면 herdr 밖이다 — 알리고 중단한다
2. `tracker` 가 있으면 이슈를 조회해 요약과 **현재 상태**를 얻는다. 유형은 트래커에 따라 없을 수 있다
3. 브랜치명을 `<종류>/<슬러그>-<영문 주제어>` 로 짓는다
   - **종류는 이슈 유형이 아니라 변경 성격으로 정한다** — 유형이 「작업」이어도 결함 수정이면 `fix/`
   - 슬러그 — Jira 는 `MGR-135` → `mgr135`, GitHub 은 `135` 그대로, 트래커가 없으면 첫 토큰을 소문자로
   - **에이전트 이름은 슬러그에서 짓되 숫자로 시작하면 `i` 를 붙인다** (`135` → `i135`). herdr 의 이름 규칙 `[a-z][a-z0-9_-]{0,31}` 이 숫자 시작을 거부한다
   - 주제어는 티켓을 열지 않고도 무슨 일인지 알 만큼 적는다 — 라벨이 이 값을 쓴다
   - 트래커가 없어 종류나 주제어를 정할 근거가 없으면 **사용자에게 묻는다**
4. `herdr worktree create` 로 worktree 를 만든다. `--base <설정값>` 을 **반드시 명시한다** — 생략하면 `--cwd` 체크아웃의 현재 HEAD 를 따라가 조용히 다른 곳에서 갈라진다. 라벨은 브랜치명에서 `<종류>/` 를 뗀 값 — 사이드바에서 그 워크스페이스를 알아보는 유일한 단서다. `--no-focus` 로 만든다
5. 응답에서 workspace ID · root pane ID · worktree 경로를 읽는다. **예측하지 않는다**
6. 그 pane 에 `herdr agent start <에이전트 이름> --kind <kind> --pane <root pane>` 으로 에이전트를 띄운다. codex 는 아래 절을 따른다
7. `옮겨줘` 가 있으면 `herdr agent focus <에이전트 이름>`
8. `tracker.transitions.inProgress` 가 있을 때만 이슈를 진행 중으로 옮긴다. **조회한 상태가 이미 완료면 옮기지 않는다** — 재오픈은 사용자의 판단이다. 전환이 실패해도 9단계는 한다
9. workspace ID · 경로 · 브랜치명 · 에이전트 이름을 보고한다. 트래커 단계를 생략했으면 그 사실도, codex 로 띄웠으면 훅과 저장소 지침이 걸리지 않는다는 사실도 함께 알린다

## codex 로 띄울 때

`-- --yolo` 를 덧붙인다. 기본 샌드박스는 worktree 밖 쓰기를 막는데, 링크드 worktree 의 git 디렉터리는 worktree 밖에 있어 커밋조차 `Operation not permitted` 다. `--yolo` 는 `codex --help` 에 나오지 않지만 실재하는 별칭이다.

범위를 좁히려면 `--yolo` 대신 `-- --add-dir "$(git rev-parse --path-format=absolute --git-common-dir)"` — git 디렉터리 하나만 연다. `--path-format=absolute` 를 빼면 메인 체크아웃에서 상대경로 `.git` 이 나와 codex 가 자기 cwd 기준으로 잘못 푼다.

codex 세션에는 Claude Code 의 훅도 저장소 지침도 걸리지 않는다. 지침은 저장소 루트의 `AGENTS.md` 로 돌아오지만 훅은 돌아오지 않는다 — 훅이 강제하던 규칙은 사람이 확인한다.

## 걸리는 지점

- `agent start` 는 **프롬프트에 이미 있는 shell pane** 을 요구한다. `worktree create` 직후에 바로 부르면 `agent_pane_busy` 로 실패할 수 있다 — `herdr pane list` 로 확인하고 다시 실행한다
- 에이전트 이름은 살아 있는 것 사이에서 유일해야 한다. 같은 이슈로 두 번 부르면 `herdr agent list` 로 먼저 확인한다
- **base 브랜치는 어떤 worktree 에서도 체크아웃되지 않는다** — 메인 체크아웃이 잡고 있어 git 이 거부한다. 결과는 로컬 병합이 아니라 push 후 PR 로 간다
- **메인 체크아웃의 미커밋 변경을 임의로 처리하지 않는다.** 되돌리거나 stash 하지 말고 사용자에게 묻는다
