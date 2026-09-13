---
description: 이슈 하나를 작업할 브랜치·worktree·에이전트를 준비하고 Jira 를 진행 중으로 옮긴다. 작업 자체는 하지 않는다
argument-hint: <이슈키> [에이전트종류] [옮겨줘]
---

`$ARGUMENTS` 의 첫 토큰이 이슈 키다. 나머지 토큰에서 에이전트 종류(`herdr agent start --help` 의 `--kind` 가능값 — 이 저장소는 `claude` 와 `codex` 를 쓴다)와 `옮겨줘`(포커스 이동)를 읽는다. 없으면 종류는 `claude`, 포커스는 이 pane 에 둔다.

## 준비까지만 한다

**에이전트에 프롬프트를 넣지 않는다.** 이슈의 해결 방법을 조사하지도, 선택지를 확인받지도 않는다. 사용자가 그 에이전트로 직접 작업한다. 준비가 끝나면 보고하고 손을 뗀다.

첫 지시를 함께 넣어 달라는 말이 인자에 있으면 그때만 `herdr agent prompt` 를 쓴다.

## 절차

1. `test "${HERDR_ENV:-}" = 1` — 실패하면 herdr 밖이라고 알리고 중단한다
2. Jira 에서 **이슈 키로 직접 조회**해 유형·요약과 **현재 상태**를 얻는다 (JQL 이 아니다 — 이 사이트의 JQL 은 한글 값에 0건을 반환한다). 상태는 전환 단계가 쓴다
3. 브랜치명을 `<종류>/<이슈키 소문자>-<영문 주제어>` 로 짓는다. **종류는 Jira 이슈 유형이 아니라 변경 성격으로 정한다** — 이 저장소는 `feature`·`fix`·`docs`·`chore` 를 쓴다. MGR-85 는 유형이 「작업」이었지만 결함 수정이라 `fix/mgr85-casbin-schema` 로 갔다 (2026-08-18).
   **주제어는 티켓을 열지 않고도 무슨 일인지 알 만큼 적는다** — 라벨이 이 값을 그대로 쓴다
4. worktree 를 만든다:

   ```bash
   herdr worktree create --cwd "$(git rev-parse --show-toplevel)" \
     --branch <브랜치명> --base develop --label <브랜치명에서 종류를 뗀 값> --no-focus
   ```

   **라벨은 브랜치명에서 `<종류>/` 만 떼서 쓴다** — `fix/mgr85-casbin-schema` 면 `mgr85-casbin-schema`. 라벨은 사이드바에서 그 워크스페이스가 무슨 일인지 알려 주는 유일한 단서라 이슈키만 넣으면 매번 Jira 를 열게 된다 (2026-08-18 지적). 기존 라벨도 `mgr34-backnd-chat`·`feature-fluentbit` 처럼 영문 kebab 이고 8~29자를 쓴다.

   **`--base develop` 을 생략하지 않는다.** 생략하면 `--cwd` 체크아웃의 현재 HEAD 를 따라가고, 그게 develop 이 아닌 순간 조용히 다른 곳에서 갈라진다.
5. 응답 JSON 에서 workspace ID · root pane ID · worktree 경로를 파싱한다. **예측하지 않는다**
6. 그 pane 에 에이전트를 띄운다 — `herdr agent start <이슈키 소문자> --kind <종류> --pane <root pane id>`

   **종류가 `codex` 면 `-- --yolo` 를 덧붙인다.**

   ```bash
   herdr agent start <이슈키 소문자> --kind codex --pane <root pane id> -- --yolo
   ```

   codex 의 기본 샌드박스 `workspace-write` 는 **worktree 밖 쓰기를 막는다.** 이 명령이 만드는 것은 링크드 worktree 라 git 디렉터리가 worktree 밖에 있고(근거: `git rev-parse --git-common-dir`) 커밋·브랜치 조작이 전부 그 바깥이라, 샌드박스를 켠 채로는 `git tag` 조차 `Operation not permitted` 다.

   **샌드박스를 유지하는 길이 없는 것은 아니다** — `-- --add-dir "$(git rev-parse --path-format=absolute --git-common-dir)"` 이 그 경로를 쓰기 가능 루트에 더해 git 조작을 통과시킨다 (2026-09-11 실측 — `codex exec --add-dir ... --sandbox workspace-write` 로 `git tag` 가 성공했고, 같은 명령에서 `--add-dir` 만 빼면 막힌다).

   **`--path-format=absolute` 를 빼지 않는다.** 이 치환이 일어나는 셸은 4단계 때문에 메인 체크아웃에 있는데, 거기서 `--git-common-dir` 은 상대경로 `.git` 을 낸다 (2026-09-11 실측 — 링크드 worktree 안에서만 절대경로가 나온다). codex 는 그것을 자기 cwd 인 새 worktree 기준으로 푸는데 그 자리의 `.git` 은 디렉터리가 아니라 gitdir 포인터 파일이라 열리지 않는다.

   **기본이 `--yolo` 인 것은 그렇게 정했기 때문이다** — `--yolo` 는 `~/.ssh`·메인 체크아웃·**같은 저장소의 다른 worktree 전부**를 열고 `--add-dir` 은 git 디렉터리 하나만 여니, 범위를 좁히려면 이 인자로 바꾼다. 다른 worktree 가 열린다는 것은 같은 저장소에서 병행 중인 옆 세션의 미커밋 변경에까지 닿는다는 뜻이다.

   `--yolo` 는 `--dangerously-bypass-approvals-and-sandbox` 의 별칭이다. **`codex --help` 에는 나오지 않으니** 없는 플래그로 오해하지 않는다. herdr 은 `--` 뒤 인자를 그대로 argv 에 넘긴다 (2026-09-11 실측 — 응답의 `argv` 가 `["codex","--yolo"]` 였고 화면에 `permissions: YOLO mode` 가 떴다).
7. 인자에 `옮겨줘` 가 있으면 `herdr agent focus <이슈키 소문자>`
8. Jira 이슈를 **진행 중**으로 옮긴다

   ```
   transitionJiraIssue(issueIdOrKey: "<이슈키>", transition: {id: "31"})
   ```

   **전환 id 로 던진다** — 상태 이름(`"진행 중"`)을 넣을 자리가 없다. 표는 `herdr-wt:wt-done` 스킬 2단계에 있다

   **2번에서 조회한 상태가 완료(`10092`)면 전환하지 않는다.** 전환 `31` 은 `isGlobal` 이라 완료 이슈에도 그대로 걸려 **조용히 재오픈시킨다.** 게다가 완료 이슈는 `resolution` 이 채워져 있는데 이 전환은 `hasScreen: false` 라 그 값을 비울 화면이 없다 — 상태만 진행 중이고 `resolution` 은 완료로 남을 수 있다. 재오픈은 사용자가 판단할 일이니 건너뛰고 그 사실을 보고에 적는다.

   **준비가 다 끝난 뒤에 옮긴다.** 앞 단계가 실패했는데 이슈만 진행 중으로 남는 것을 막는다. 완료가 아닌 상태에서는 그대로 걸린다 — 백로그·개발하기로 선택됨·진행 중·완료 네 상태 모두에서 `31` 이 `isGlobal: true`·`isAvailable: true` 였다 (2026-08-24 MGR-152·MGR-146·MGR-135 를 `getTransitionsForJiraIssue` 로 **조회**해 확인). 백로그에서 `31` 을 실행해 진행 중으로 옮겼다 (2026-09-07 MGR-320 실측). 실패하면 `getTransitionsForJiraIssue` 로 전환 id 를 다시 얻는다.

   전환이 실패해도 **마지막 보고 단계는 한다.** worktree 와 에이전트는 이미 준비돼 있으니, 상태를 못 옮겼다는 사실만 함께 알린다
9. workspace ID · worktree 경로 · 브랜치명 · 에이전트 이름을 보고한다. **codex 로 띄웠으면 그 세션에 훅도 저장소 지침도 걸리지 않는다는 사실을 함께 알린다** — 지켜야 할 주체가 사용자다

## 걸리는 지점

- `agent start` 는 **이미 프롬프트에 있는 shell pane** 을 요구한다. 4단계가 만든 root pane 이 아직 프롬프트에 오지 않았으면 `agent_pane_busy` 로 실패한다 — `worktree create` 직후에 바로 부르면 그렇게 된다 (2026-09-08 실측. 2026-08-18 에는 바로 받았다). 실패하면 `herdr pane list --workspace <ID>` 로 프롬프트 상태를 확인한 뒤 같은 명령을 다시 실행한다
- 에이전트 이름은 `[a-z][a-z0-9_-]{0,31}` 이고 살아 있는 에이전트 사이에서 유일해야 한다. 같은 이슈로 두 번 부르면 `herdr agent list` 로 기존 것을 먼저 확인한다
- **`codex` 로 띄운 세션에는 가드 훅도, `CLAUDE.md`·`.claude/rules/` 도 걸리지 않는다.** `.claude/hooks/` 의 가드 훅은 Claude Code 훅이고(`ls .claude/hooks/`), codex 가 읽는 `AGENTS.md` 는 이 저장소에 없다. 자격증명 3채널·한글 JQL·develop 체크아웃 불가·패치 manifest·용어 정본이 **전부 없는 채로 뜬다.** `--yolo` 는 샌드박스까지 없애므로 그 세션에 남는 방어는 사람이다. **지침 쪽은 저장소 루트에 `AGENTS.md` 를 두면 돌아온다** — codex 가 그 파일을 읽는다. 훅은 그래도 돌아오지 않으니 그 세션이 커밋하기 전에 patches lint 와 자격증명 규칙은 사람이 확인한다
- **base 브랜치는 어떤 worktree 에서도 체크아웃되지 않는다.** 메인 체크아웃이 잡고 있어 git 이 거부한다 — `fatal: 'develop' is already used by worktree at ...` (2026-08-18 실측). 그래서 그 worktree 의 결과는 로컬 병합이 아니라 push 후 PR 로 간다
- **메인 체크아웃의 미커밋 변경을 임의로 처리하지 않는다.** 그 파일을 worktree 에서도 고쳤다면 병합이 거부된다. 되돌리거나 stash 하지 말고 사용자에게 확인을 구한다
