# sichiro — Claude Code 플러그인 마켓플레이스

개인 Claude Code 플러그인 모음이다. 지금은 `herdr-wt` 하나를 담는다.

## 설치

Claude Code 안에서 두 명령을 차례로 실행한다.

```
/plugin marketplace add sichiro/claude-plugins
/plugin install herdr-wt@sichiro
```

## herdr-wt

이슈 하나의 작업 자리를 준비하고, 끝난 작업을 정리하는 스킬 두 개다.

- `wt` — 이슈 식별자를 받아 브랜치명을 짓고, `herdr worktree create` 로 worktree 를 만들고, 그 pane 에 에이전트를 띄운다. 준비까지만 하고 프롬프트는 넣지 않는다 — 사용자가 그 에이전트로 직접 작업한다.
- `wt-done` — PR 을 머지하고, 저장소 지침의 마감 절차(이슈 닫기·결과 코멘트)를 수행하고, worktree 를 제거한다. 사전 점검 뒤 승인을 한 번만 받고 나머지 단계는 되묻지 않고 끝까지 간다. 마지막 단계는 이 세션을 함께 종료한다.

두 스킬은 herdr 터미널 멀티플렉서 안에서만 동작한다. `HERDR_ENV=1` 이 아니면 그 사실을 알리고 중단한다.

```
/herdr-wt:wt MGR-135
/herdr-wt:wt 42 --kind codex 옮겨줘
/herdr-wt:wt-done
```

## 저장소 지침 — `.claude/wt.md`

각 저장소가 `.claude/wt.md` 로 자기 값을 정한다. base 브랜치, 브랜치 종류, 이슈 트래커(Jira·GitHub Issues) 연동, 결과 코멘트에 담을 것, 에이전트 정책이 여기 온다. 스킬은 시작할 때 이 파일을 읽고 각 단계에서 관련 지시를 따른다.

`plugins/herdr-wt/examples/wt.md` 를 복사해 시작한다. 자유형 마크다운이므로 필요한 절만 남긴다.

```
cp plugins/herdr-wt/examples/wt.md <저장소>/.claude/wt.md
```

지침은 단계를 더하거나 값을 정할 뿐, 단계의 순서와 승인·재확인 지점은 바꾸지 못한다. 파일이 없으면 base 는 `develop`, 이슈 트래커는 없는 것으로 진행한다.

## 검사

매니페스트와 문서 참조를 검사한다. 통과하면 `통과` 를 출력하고 종료코드 0 을 반환한다.

```
python3 scripts/check-plugin.py
```
