# Herdr 앱 — `wt-done` 명령

`HERDR_ENV` 가 없고 `HC_TERMINAL_ID` 가 있을 때 읽는다. 창은 `herdr-app`, 터미널은 herdr-core(`hc`)가 돌린다.

## 내 자리 찾기

`$HC_TERMINAL_ID` 가 이 세션의 터미널 주소이고, 그 터미널의 `herdr.space` 라벨이 내 space 다. `herdr-app ls` 에서 그 space 에 내 주소가 **터미널로 직접** 들어 있는지 대조한다.

```
SP=$(hc get "$HC_TERMINAL_ID" --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["labels"].get("herdr.space",""))')
herdr-app ls | SP="$SP" python3 -c '
import json, os, sys
me, sp = os.environ["HC_TERMINAL_ID"], os.environ["SP"]
for s in json.load(sys.stdin)["spaces"]:
    if s["id"] != sp: continue
    ts = [(t["terminal"], t.get("sub_agents", [])) for tab in s["tabs"] for t in tab["terminals"]]
    print("ok" if any(t == me for t, _ in ts) else "mismatch", sp, ts)'
```

- 출력이 `ok` 로 시작하지 않으면(빈 값·`mismatch`·0줄) 멈추고 묻는다
- `sub_agents` 목록에서 내 주소를 찾아 고르지 않는다 — `hc run` 으로 띄운 세션은 부모 터미널의 `sub_agents` 에도 나오므로, 그렇게 고른 space 는 **부모의** space 다
- space 의 `folder` 는 만들 때의 값이라 판정에 쓰지 않는다
- 그 space 의 다른 터미널은 4단계에서 함께 끝난다. `sub_agents` 는 `hc run --outlive-parent` 로 띄운 것이 아니면 함께 끝난다 — 둘 다 0단계에서 센다
- 각 터미널이 지금 어디서 돌고 있는지는 `hc get <주소> --json` 의 `foreground.cwd` 로 본다. 최상위 `cwd` 는 띄울 때의 폴더다

## 다른 에이전트 닫기

위에서 확인한 space 안의 주소만, 이 세션의 주소(`$HC_TERMINAL_ID`)를 빼고 닫는다.

```
herdr-app do terminal.kill --terminal <주소>
```

`hc kill` 은 쓰지 않는다 — 프로그램만 끝내므로 `keep` 이 켜진 터미널에는 셸이 남는다.

## worktree 제거

**한 명령으로 둘을 잇는다** — worktree 를 먼저 지우고 space 를 마지막에 닫는다. 셸 변수는 호출 사이에 남지 않으므로 「내 자리 찾기」에서 `ok` 로 확인한 space id 를 글자 그대로 넣는다.

```
SP=<확인한 space id>; [ -n "$SP" ] && git -C <메인 체크아웃> worktree remove <worktree 경로> && herdr-app do space.close --id "$SP" --confirmed true
```

- `space.close` 는 `--id` 가 없어도 실행되고, 그때 닫는 것은 내 space 가 아니다. 그래서 빈 값이면 앞에서 끊는다
- `space.close` 가 이 세션을 끝내므로 git 이 뒤에 오면 영영 실행되지 않는다. 앱의 Remove worktree 대화상자는 space 를 먼저 닫는데, 그것은 대화상자가 세션 밖에서 돌기 때문이다
- worktree 안에서 불러도 `git -C <메인 체크아웃> worktree remove` 는 지운다
- 둘을 따로 부르지 않는다 — 앞 호출이 cwd 를 지운 뒤에 다음 호출을 띄우게 된다
- `git worktree remove` 가 미커밋·untracked 를 이유로 거부하면 space 는 남는다. `--force` 를 붙이기 전에 멈추고 묻는다 — 0단계에서 비어 있던 것이 생긴 것이다
