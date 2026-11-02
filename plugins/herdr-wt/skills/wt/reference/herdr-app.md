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

## 에이전트 띄우기 — 첫 지시를 입력칸에 넣고 제출하지 않는다

herdr-core 템플릿으로 띄운다. 템플릿의 `submit` 을 Enter 대신 `end` 로 두면 첫 지시가 입력칸에 들어간 채 남는다. 사람이 내용을 보고 Enter 를 누르면 그때 실행된다.

**1. 템플릿을 준비한다.** 에이전트 명령(모델 인자 포함)마다 하나다. 이름은 `wt-<kind>-<모델 슬러그>` 로 짓는다(예. `wt-claude-opus1m`).

```
F="$HOME/.config/herdr-core/templates/wt-claude-opus1m.md"
[ -e "$F" ] || { mkdir -p "${F%/*}" && cat > "$F"; } <<'EOF'
---
name: wt-claude-opus1m
description: herdr-wt 가 쓴다 — 첫 지시를 입력칸에 넣되 제출하지 않는다(제출 키 End)
command: claude --model 'opus[1m]'
submit: end
---
EOF
hc templates
```

- 이미 있으면 덮어쓰지 않는다. `hc templates` 의 `command` 가 원하는 명령과 다르면 멈추고 묻는다
- codex 는 `command: codex --yolo` 로 같은 형태의 템플릿을 둔다. codex 에서 `submit: end` 가 제출하지 않는지는 재지 않았다 — 첫 사용 때 입력칸을 읽어 확인한다

**2. space 와 함께 띄운다.**

```
SP=sp$(openssl rand -hex 16); TB=tb$(openssl rand -hex 16)
env -u HC_TERMINAL_ID hc run --bg --json --no-parent --keep --cwd "$P" \
  --label herdr.space=$SP --label herdr.tab=$TB --label agent=<에이전트 이름> \
  wt-claude-opus1m "<초안>"
```

- 출력 JSON 의 `address` 가 터미널 주소다. space id 는 내가 정한 `$SP` 다
- 앱이 모르는 `herdr.space`·`herdr.tab` id 는 새 space 와 tab 이 되어 사이드바의 저장소 아래에 중첩해 올라온다. space 에 이름을 주지 않는다 — 이름 없는 space 는 checkout 폴더를 따라간다
- `--no-parent`·`--keep` 이라 이 세션이 끝나도 계속 돌고, 재시작 뒤에는 셸로 남는다
- `env -u HC_TERMINAL_ID` 를 빼면 첫 지시가 `<hc from="t8" reach="…">` 태그로 감싸여 들어간다 — 사람이 보는 초안에는 쓰지 않는다
- 시작 배너는 `hc read <주소> --lines 40` 으로 읽는다. 초안은 제출되지 않았으므로 배너를 보고 멈출 자리가 남아 있다

## 초안은 이슈 주소 한 줄이다

초안 내용은 SKILL 의 「첫 지시」 절이 정한다. 주소 한 줄이면 아래 접힘에 걸리지 않는다. Claude Code 는 붙여넣은 글에 줄바꿈이 있거나 길면 입력칸에 `[Pasted text #1 +N lines]` 로 접어 보여 주고, 접히면 사람이 내용을 보고 Enter 를 누를 수 없다.

| 붙여넣은 글 | 입력칸 |
|---|---|
| 한 줄 · 320자 | 그대로 보인다 |
| 다섯 줄 · 짧음 | 접힌다 |
| 한 줄 · 1,615자 | 접힌다 |


## 바로 실행 — `--prompt` 일 때

같은 템플릿으로 띄운 뒤 배너를 확인하고 Enter 를 누른다. 이때는 긴 지시가 접혀도 상관없으므로 SKILL 의 「첫 지시」 골격대로 쓴다.

```
hc keys <주소> enter
hc get <주소> --json            # status.state 가 working 인가
```

`hc wait` 는 working 이 아니면 바로 돌아오므로 기다렸다는 사실만으로는 판정하지 못한다. `turn` 은 실행 직후에도 0 일 수 있다 — `status.state` 와 화면으로 본다.

## 포커스

`hc run` 으로 띄우면 포커스가 옮겨지지 않는다. `옮겨줘` 면 `herdr-app do space.select --id $SP`.

## 이미 띄운 터미널을 사이드바에 올리기

라벨 없이 `hc run` 으로 띄운 터미널은 사이드바에 나오지 않는다. 앱이 모르는 id 를 붙이면 새 space 로 올라온다.

```
hc label <주소> herdr.space=<새 id> herdr.tab=<새 id>
hc keep <주소>
```

띄울 때 `--no-parent` 나 `--outlive-parent` 가 없었으면 부모 세션과 함께 끝난다.
