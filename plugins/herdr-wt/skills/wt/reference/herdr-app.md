# Herdr 앱 — `wt` 명령

`HERDR_ENV` 가 없고 `HC_TERMINAL_ID` 가 있을 때 읽는다. 창은 `herdr-app`, 터미널과 에이전트는 herdr-core(`hc`)가 돌린다. worktree 하나가 **space** 하나로 열리고, 터미널 주소(`t1c` 같은 값)가 그 에이전트를 가리키는 핸들이다.

명령 전체는 `herdr-app commands` · `hc --help` 가 정본이다. 아래는 이 스킬이 쓰는 것만이다.

## worktree 만들기

git 으로 직접 만든다. 경로는 앱의 worktree 모드와 같은 규칙으로 정한다 — 그래야 앱의 Open/Remove worktree 대화상자가 같은 checkout 으로 알아본다.

```
M=<메인 체크아웃>; B=<브랜치>; BASE=<base>
P="$HOME/.herdr/worktrees/$(basename "$M")/$(printf %s "$B" | sed -E 's/[^A-Za-z0-9._-]+/-/g; s/^-+|-+$//g')"
git -C "$M" fetch origin "$BASE"
git -C "$M" worktree add -b "$B" "$P" "origin/$BASE"
```

- 슬러그는 영숫자·`.`·`_`·`-` 밖의 문자를 `-` 로 바꾼 것이다 — `fix/mgr135-x` → `fix-mgr135-x`
- **앱 화면의 New worktree 는 쓰지 않는다** — 지금 체크아웃의 `HEAD` 에서 갈라 base 를 고를 수 없다
- 이 단계는 space 를 만들지 않는다. 저장소 지침의 생성 직후 할 일을 마친 뒤 다음 절로 간다

## 에이전트 띄우기 — 첫 지시도 여기서 함께

space 를 만들면서 에이전트와 첫 지시를 한 번에 넣는다.

```
herdr-app do space.new --folder "$P" --argv '["claude","--model","opus[1m]"]' [--task "<지시>"]
```

- 출력 JSON 의 `space` · `tab` · `terminal` 을 읽는다. 실패하면 `{ "error": … }` 와 rc 1 이다
- `--argv` 는 JSON 배열이라 작은따옴표 안의 `opus[1m]` 가 글롭 없이 그대로 넘어간다
- **space 에 `--name` 을 주지 않는다.** 이름 없는 space 는 checkout 폴더를 따라가고, 사이드바가 저장소 아래에 중첩해 브랜치와 함께 보여 준다
- 이 터미널은 이 세션의 자식이 아니다(`parent` 없음, `keep` 켜짐). 이 세션이 끝나도 계속 돈다
- codex 는 `--argv '["codex","--yolo"]'` 로 띄운다. `--add-dir` 로 좁히려면 경로를 먼저 구해 JSON 에 넣는다 — 작은따옴표 안의 `$(…)` 는 펼쳐지지 않는다

  ```
  G=$(git -C "$P" rev-parse --path-format=absolute --git-common-dir)
  herdr-app do space.new --folder "$P" --argv "[\"codex\",\"--add-dir\",\"$G\"]"
  ```

- 에이전트 이름 대신 `hc label <terminal> agent=<에이전트 이름>` 을 붙여 둔다. 보고에는 주소를 함께 적는다
- 시작 배너는 `hc read <terminal> --lines 40` 으로 읽는다
- **저장소 지침이 배너를 보고 멈출 수 있게 요구하면 `--task` 를 빼고 띄운다.** `--task` 로 넣으면 배너를 볼 때 에이전트가 이미 지시를 받은 뒤다. 그때는 배너를 확인한 다음 「첫 지시 넣기」 절의 `hc send` 로 넣는다

## 포커스

**`space.new` 는 포커스를 새 space 로 옮긴다.** 그래서 이 절의 첫 명령은 「에이전트 띄우기」 **앞에서** 실행해 지금 space 를 적어 둔다 — 띄운 뒤에는 이미 새 space 가 보인다. `옮겨줘` 가 없으면 띄운 뒤 되돌린다.

```
herdr-app status            # 만들기 전 — 출력의 "space" 값을 적어 둔다
herdr-app do space.select --id <적어 둔 space>
```

## 첫 지시 넣기

`--task` 로 넣었으면 이미 들어갔다. 에이전트가 부팅을 마친 뒤 전달되므로 바로 확인하면 빈 입력줄이 보인다. `--task` 를 빼고 띄웠으면 배너가 보인 뒤(부팅이 끝난 뒤) `hc send <terminal> "<지시>"` 로 한 번 넣는다 — 부팅 중에 보낸 것은 버려질 수 있다.

```
hc wait <terminal> --timeout 90
hc get <terminal> --json        # "turn" 이 1 이상인가
hc read <terminal> --lines 60   # 지시 문장이 입력 이력에 있는가
```

`turn` 이 늘었거나 지시 문장이 이력에 보이면 들어간 것이다. `hc wait` 는 working 이 아니면 바로 돌아오므로 기다렸다는 사실만으로는 판정하지 못한다. `hc get` 에는 첫 지시를 보여 주는 칸이 없다. 둘 다 아니면 한 번 더 기다리고, 그래도 없으면 `hc send <terminal> "<지시>"` 로 넣기 전에 화면을 보고한다 — 늦게 도착할 수 있어 두 번 들어가면 안 된다.

## 다른 경로로 띄운 터미널을 사이드바에 올리기

`hc run` 으로 띄운 터미널은 `herdr.space`·`herdr.tab` 라벨이 없어 사이드바에 나오지 않는다. 앱이 모르는 id 를 붙이면 새 space 로 올라온다.

```
hc label <terminal> herdr.space=<새 id> herdr.tab=<새 id>
hc keep <terminal>
```

이렇게 올린 터미널은 `parent` 가 남아 있어, 띄울 때 `--outlive-parent` 를 주지 않았으면 부모 세션과 함께 끝난다. 처음부터 위 「에이전트 띄우기」 절로 띄우면 이 절은 필요 없다.
