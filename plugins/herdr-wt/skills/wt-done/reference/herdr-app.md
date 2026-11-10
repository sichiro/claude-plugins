# Herdr 앱 — `wt-done` 명령

`HERDR_ENV` 가 없고 `HC_TERMINAL_ID` 가 있을 때 읽는다. 창은 `herdr-app`, 터미널은 herdr-core(`hc`)가 돌린다.

## 앱이 어느 기기에 있나 — 먼저 정한다

앱은 이 세션과 다른 기기에서 돌 수 있다. 맥북의 앱이 SSH 로 맥미니의 herdr-core 에 붙으면, 세션은 맥미니에 있고 `herdr-app` 은 맥북에만 있다. 아래 두 값을 정하고 이 문서의 모든 명령에 글자 그대로 넣는다.

| 값 | `command -v herdr-app` 이 찾으면 | 못 찾으면 |
|---|---|---|
| `<앱>` | `herdr-app` | `ssh -o BatchMode=yes <앱 기기> '~/.local/bin/herdr-app'` |
| `<접두어>` | 빈 값 | `<기기 이름>/` |

- `<앱 기기>` 는 환경 변수 `HERDR_APP_SSH` 의 값이다(예. `user@macbook.tailnet.ts.net`). 비어 있으면 멈추고 사용자에게 묻는다
- 원격 경로를 줄이지 않는다. 비대화형 SSH 의 `PATH` 에는 `~/.local/bin` 이 없어 `herdr-app` 만 쓰면 찾지 못한다
- `<기기 이름>` 은 앱 기기가 이 core 를 부르는 이름이다. core id 로 대조해 구한다. 출력이 비면 앱이 이 core 에 붙어 있지 않은 것이므로 멈추고 묻는다

```
ID=$(hc server status | python3 -c 'import json,sys; print(json.load(sys.stdin)["core"]["id"])')
ssh -o BatchMode=yes <앱 기기> '~/.local/bin/hc machine ls' | ID="$ID" python3 -c '
import json, os, sys
print(*[m["name"] + "/" for m in json.load(sys.stdin)["machines"] if m["id"] == os.environ["ID"]])'
```

- 앱 목록은 다른 기기의 space id 와 터미널 주소에 `<접두어>` 를 붙여 보여 준다(`mini/sp…`, `mini/t16`). 이 core 의 `hc` 는 접두어 없이 보여 준다. 앱에 넘기는 id 와 주소에는 반드시 붙인다

## 내 자리 찾기

`$HC_TERMINAL_ID` 가 이 세션의 터미널 주소이고, 그 터미널의 `herdr.space` 라벨이 내 space 다. `<앱> ls` 에서 그 space 에 내 주소가 **터미널로 직접** 들어 있는지 대조한다.

```
SP=$(hc get "$HC_TERMINAL_ID" --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["labels"].get("herdr.space",""))')
<앱> ls | SP="$SP" PFX="<접두어>" python3 -c '
import json, os, sys
pfx = os.environ["PFX"]
me, sp = pfx + os.environ["HC_TERMINAL_ID"], pfx + os.environ["SP"]
for s in json.load(sys.stdin)["spaces"]:
    if s["id"] != sp: continue
    ts = [(t["terminal"], t.get("sub_agents", [])) for tab in s["tabs"] for t in tab["terminals"]]
    print("ok" if any(t == me for t, _ in ts) else "mismatch", sp, ts)'
```

- 출력이 `ok` 로 시작하지 않으면(빈 값·`mismatch`·0줄) 멈추고 묻는다. 출력의 space id 는 접두어가 붙은 값이고, 4단계에서 그대로 쓴다
- `sub_agents` 목록에서 내 주소를 찾아 고르지 않는다 — `hc run` 으로 띄운 세션은 부모 터미널의 `sub_agents` 에도 나오므로, 그렇게 고른 space 는 **부모의** space 다
- space 의 `folder` 는 만들 때의 값이라 판정에 쓰지 않는다
- 그 space 의 다른 터미널은 4단계에서 함께 끝난다. `sub_agents` 는 `hc run --outlive-parent` 로 띄운 것이 아니면 함께 끝난다 — 둘 다 0단계에서 센다
- 각 터미널이 지금 어디서 돌고 있는지는 `hc get <주소> --json` 의 `foreground.cwd` 로 본다. 이때 주소에서 접두어를 뗀다. 최상위 `cwd` 는 띄울 때의 폴더다

## 다른 에이전트 닫기

위에서 확인한 space 안의 주소만, 이 세션의 주소를 빼고 닫는다. 주소는 앱 목록에 나온 그대로(접두어 포함) 넘긴다.

```
<앱> do terminal.kill --terminal <주소>
```

`hc kill` 은 쓰지 않는다 — 프로그램만 끝내므로 `keep` 이 켜진 터미널에는 셸이 남는다.

## worktree 제거

**한 명령으로 둘을 잇는다** — worktree 를 먼저 지우고 space 를 마지막에 닫는다. 셸 변수는 호출 사이에 남지 않으므로 「내 자리 찾기」에서 `ok` 로 확인한 space id(접두어 포함)를 글자 그대로 넣는다.

```
SP=<확인한 space id>; [ -n "$SP" ] && git -C <메인 체크아웃> worktree remove <worktree 경로> && <앱> do space.close --id "$SP" --confirmed true
```

- `space.close` 는 `--id` 가 없어도 실행되고, 그때 닫는 것은 내 space 가 아니다. 그래서 빈 값이면 앞에서 끊는다
- `space.close` 가 이 세션을 끝내므로 git 이 뒤에 오면 영영 실행되지 않는다. 앱의 Remove worktree 대화상자는 space 를 먼저 닫는데, 그것은 대화상자가 세션 밖에서 돌기 때문이다
- worktree 안에서 불러도 `git -C <메인 체크아웃> worktree remove` 는 지운다
- 둘을 따로 부르지 않는다 — 앞 호출이 cwd 를 지운 뒤에 다음 호출을 띄우게 된다
- `git worktree remove` 가 미커밋·untracked 를 이유로 거부하면 space 는 남는다. `--force` 를 붙이기 전에 멈추고 묻는다 — 0단계에서 비어 있던 것이 생긴 것이다
- worktree 를 이미 지웠고 space 만 남았으면 `git` 부분을 빼고 `<앱> do space.close` 만 부른다. 그 경우에도 「내 자리 찾기」의 `ok` 를 먼저 확인한다
