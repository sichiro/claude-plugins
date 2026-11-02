# herdr TUI — `wt` 명령

`HERDR_ENV=1` 일 때 읽는다. worktree 하나가 workspace 하나로 열리고, 에이전트 이름이 그 pane 을 가리키는 핸들이다.

## worktree 만들기

```
herdr worktree create --cwd <메인 체크아웃> --branch <브랜치> --base <base> --label <라벨> --no-focus
```

- `--base` 를 빼면 `--cwd` 체크아웃의 현재 HEAD 를 따른다
- `--cwd` 는 **메인 체크아웃**이다. 링크드 worktree 안에서 부르면 `linked_worktree_source` 로 거부된다
- 라벨은 `<에이전트 이름>-<영문 주제어>` — 브랜치명에서 `<종류>/` 를 떼고 슬러그 자리에 에이전트 이름을 쓴 것이다. 이 라벨이 사이드바에서 그 workspace 를 알아보는 유일한 단서다
- 응답에서 workspace ID · root pane ID · worktree 경로를 읽는다

## 에이전트 띄우기

```
herdr agent start <에이전트 이름> --kind <kind> --pane <root pane> [-- <에이전트 인자>…]
```

- 모델은 `-- --model <값>` 으로 넘긴다. 대괄호가 든 값(`opus[1m]`)은 zsh 글롭이라 작은따옴표로 감싼다
- **프롬프트에 이미 있는 shell pane** 을 요구한다. `worktree create` 직후에 바로 부르면 `agent_pane_busy` 로 실패할 수 있다 — `herdr pane list` 로 확인하고 다시 실행한다
- 시작 배너는 `herdr agent read <에이전트 이름> --source visible` 로 읽는다
- 같은 이름이 살아 있는지는 `herdr agent list` 로 본다

## 포커스

`--no-focus` 로 만들었으므로 포커스는 그대로다. `옮겨줘` 면 `herdr agent focus <에이전트 이름>`.

## 첫 지시 넣기

**초안(기본)** — 입력칸에 넣고 Enter 는 누르지 않는다. 에이전트가 프롬프트를 띄운 뒤에 넣는다.

```
herdr pane send-text <root pane> "<초안>"
```

`send-text` 가 Enter 없이 글자만 넣는지는 이 판에서 재지 않았다(herdr TUI 밖에서 작성했다). 첫 사용 때 `herdr agent read <에이전트 이름> --source visible` 로 입력칸에 글이 남았는지, 실행되지 않았는지 확인하고, 실행돼 버렸으면 그 사실을 보고한다.

**바로 실행(`--prompt`)**

```
herdr agent prompt <에이전트 이름> "<지시>" --wait --until working --timeout 15000
```

working 이 관측되지 않으면 `herdr agent read` 로 화면을 읽어 보고한다.
