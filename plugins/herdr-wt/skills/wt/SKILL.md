---
name: wt
description: 이슈 하나를 작업할 브랜치·worktree·에이전트를 준비할 때 사용한다. "MGR-135 작업 시작" · "이슈 준비해줘" · "worktree 만들어줘" 지시에 쓴다. 준비까지만 하고 작업 자체는 하지 않는다
---

`ARGUMENTS` 의 첫 토큰이 이슈 식별자다. 나머지 토큰에서 에이전트 종류(`herdr agent start --help` 의 `--kind` 가능값)와 `옮겨줘`(포커스 이동)를 읽는다. 없으면 종류는 `claude`, 포커스는 이 pane 에 둔다.

## 준비까지만 한다

**에이전트에 프롬프트를 넣지 않는다.** 이슈의 해결 방법을 조사하지도, 선택지를 확인받지도 않는다. 사용자가 그 에이전트로 직접 작업한다. 준비가 끝나면 보고하고 손을 뗀다.

첫 지시를 함께 넣어 달라는 말이 인자에 있으면 그때만 `herdr agent prompt` 를 쓴다.

## 설정을 먼저 읽는다

`.claude/wt.json` 을 읽는다. 파일이 없으면 기본값으로 진행한다.

| 키 | 기본값 | 쓰는 곳 |
|---|---|---|
| `base` | `develop` | 4단계 `--base` |
| `branchKinds` | `["feature","fix","docs","chore"]` | 3단계 종류 |
| `tracker` | 없음 | 2·8단계 — 없으면 두 단계를 생략한다 |

트래커별 명령은 `${CLAUDE_PLUGIN_ROOT}/references/trackers.md` 에 있다.

전체 형태는 다음과 같다.

```json
{
  "base": "develop",
  "branchKinds": ["feature", "fix", "docs", "chore"],
  "tracker": {
    "type": "jira",
    "project": "MGR",
    "transitions": { "inProgress": "31", "done": "41" }
  }
}
```

GitHub Issues 저장소는 `{ "base": "main", "tracker": { "type": "github" } }` 로 끝난다. `transitions` 는 Jira 에만 필요하다.

## 절차

1. `test "${HERDR_ENV:-}" = 1` — 실패하면 herdr 밖이라고 알리고 중단한다
2. **`tracker` 가 있으면** 이슈 식별자로 직접 조회해 유형·요약과 **현재 상태**를 얻는다 — 명령은 references 의 「조회」 행이다. 상태는 8단계가 쓴다. `tracker` 가 없으면 이 단계를 생략한다
3. 브랜치명을 `<종류>/<슬러그>-<영문 주제어>` 로 짓는다. **종류는 이슈 유형이 아니라 변경 성격으로 정한다** — 값은 `branchKinds` 에서 고른다. 유형이 「작업」이어도 결함 수정이면 `fix/` 로 간다.

   슬러그는 트래커로 가른다.

   | 트래커 | 슬러그 | 예 |
   |---|---|---|
   | Jira | 이슈키에서 `-` 를 떼고 소문자로 | `MGR-135` → `mgr135` |
   | GitHub | 이슈 번호 그대로 | `135` → `135` |
   | 없음 | 첫 토큰을 소문자로 | `ABC-9` → `abc-9` |
   **주제어는 티켓을 열지 않고도 무슨 일인지 알 만큼 적는다** — 라벨이 이 값을 그대로 쓴다
4. worktree 를 만든다:

   ```bash
   herdr worktree create --cwd "$(git rev-parse --show-toplevel)" \
     --branch <브랜치명> --base <설정의 base> --label <브랜치명에서 종류를 뗀 값> --no-focus
   ```

   **라벨은 브랜치명에서 `<종류>/` 만 떼서 쓴다** — `fix/mgr85-casbin-schema` 면 `mgr85-casbin-schema`. 라벨은 사이드바에서 그 워크스페이스가 무슨 일인지 알려 주는 유일한 단서라 이슈키만 넣으면 매번 Jira 를 열게 된다 (2026-08-18 지적). 기존 라벨도 `mgr34-backnd-chat`·`feature-fluentbit` 처럼 영문 kebab 이고 8~29자를 쓴다.

   **`--base` 를 생략하지 않는다.** 생략하면 `--cwd` 체크아웃의 현재 HEAD 를 따라가고, 그게 base 브랜치가 아닌 순간 조용히 다른 곳에서 갈라진다. 설정이 없으면 `develop` 을 쓴다.
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
8. **`tracker.transitions.inProgress` 가 있을 때만** 이슈를 진행 중으로 옮긴다 — 명령은 references 의 「진행 중 전환」 행이다. GitHub Issues 에는 그 상태가 없으므로 이 단계가 통째로 없다

   **2번에서 조회한 상태가 완료면 전환하지 않는다.** 재오픈은 사용자가 판단할 일이니 건너뛰고 그 사실을 보고에 적는다 — 근거는 references 의 Jira 절에 있다.

   전환이 실패해도 **마지막 보고 단계는 한다.** worktree 와 에이전트는 이미 준비돼 있으니, 상태를 못 옮겼다는 사실만 함께 알린다
9. workspace ID · worktree 경로 · 브랜치명 · 에이전트 이름을 보고한다. **codex 로 띄웠으면 그 세션에 훅도 저장소 지침도 걸리지 않는다는 사실을 함께 알린다** — 지켜야 할 주체가 사용자다

## 걸리는 지점

- `agent start` 는 **이미 프롬프트에 있는 shell pane** 을 요구한다. 4단계가 만든 root pane 이 아직 프롬프트에 오지 않았으면 `agent_pane_busy` 로 실패한다 — `worktree create` 직후에 바로 부르면 그렇게 된다 (2026-09-08 실측. 2026-08-18 에는 바로 받았다). 실패하면 `herdr pane list --workspace <ID>` 로 프롬프트 상태를 확인한 뒤 같은 명령을 다시 실행한다
- 에이전트 이름은 `[a-z][a-z0-9_-]{0,31}` 이고 살아 있는 에이전트 사이에서 유일해야 한다. 같은 이슈로 두 번 부르면 `herdr agent list` 로 기존 것을 먼저 확인한다
- **`codex` 로 띄운 세션에는 가드 훅도, `CLAUDE.md`·`.claude/rules/` 도 걸리지 않는다.** `.claude/hooks/` 의 가드 훅은 Claude Code 훅이고(`ls .claude/hooks/`), codex 가 읽는 `AGENTS.md` 는 이 저장소에 없다. 자격증명 3채널·한글 JQL·develop 체크아웃 불가·패치 manifest·용어 정본이 **전부 없는 채로 뜬다.** `--yolo` 는 샌드박스까지 없애므로 그 세션에 남는 방어는 사람이다. **지침 쪽은 저장소 루트에 `AGENTS.md` 를 두면 돌아온다** — codex 가 그 파일을 읽는다. 훅은 그래도 돌아오지 않으니 그 세션이 커밋하기 전에 patches lint 와 자격증명 규칙은 사람이 확인한다
- **base 브랜치는 어떤 worktree 에서도 체크아웃되지 않는다.** 메인 체크아웃이 잡고 있어 git 이 거부한다 — `fatal: 'develop' is already used by worktree at ...` (2026-08-18 실측). 그래서 그 worktree 의 결과는 로컬 병합이 아니라 push 후 PR 로 간다
- **메인 체크아웃의 미커밋 변경을 임의로 처리하지 않는다.** 그 파일을 worktree 에서도 고쳤다면 병합이 거부된다. 되돌리거나 stash 하지 말고 사용자에게 확인을 구한다
