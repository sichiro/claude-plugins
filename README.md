# sichiro — Claude Code 플러그인 마켓플레이스

개인 Claude Code 플러그인 모음이다. `herdr-wt` · `harness` · `step` · `todo` 넷을 담는다.

## 설치

Claude Code 안에서 마켓플레이스를 추가한 뒤 쓸 플러그인을 설치한다.

```
/plugin marketplace add sichiro/claude-plugins
/plugin install herdr-wt@sichiro
/plugin install harness@sichiro
/plugin install step@sichiro
/plugin install todo@sichiro
```

## herdr-wt

이슈 하나의 작업 자리를 준비하고, 끝난 작업을 정리하는 스킬 두 개다.

- `wt` — 이슈 식별자를 받아 브랜치명을 짓고, worktree 를 만들고, 그 자리에 에이전트를 띄운다. 준비까지만 하고 프롬프트는 넣지 않는다 — 사용자가 그 에이전트로 직접 작업한다. `--prompt` 를 붙이면 이슈 본문으로 첫 지시를 지어 넣는다. 방향이 정해지지 않은 이슈는 그 전에 한 번 묻는다.
- `wt-done` — PR 을 머지하고, 저장소 지침의 마감 절차(이슈 닫기·결과 코멘트)를 수행하고, worktree 를 제거한다. 사전 점검 뒤 승인을 한 번만 받고 나머지 단계는 되묻지 않고 끝까지 간다. `--auto`(또는 「특이사항 없다면 바로 정리해줘」처럼 요청에 사전 승인)를 담으면 점검이 전부 정상일 때 그 한 번도 묻지 않는다. `--keep`(또는 「worktree 는 남기고 정리해줘」)이면 worktree 를 지우지 않고 브랜치만 정리해 `origin/<base>` 에서 다시 선다. 마지막 단계는 이 세션을 함께 종료한다.

두 스킬은 herdr 안에서만 동작한다 — herdr TUI(`HERDR_ENV=1`)와 Herdr 앱(`HC_TERMINAL_ID` 가 있음) 둘 다다. 환경마다 명령이 달라 각 스킬의 `reference/herdr-tui.md` · `reference/herdr-app.md` 중 판정된 하나만 읽는다. 둘 다 아니면 그 사실을 알리고 중단한다.

```
/herdr-wt:wt MGR-135
/herdr-wt:wt 42 --kind codex 옮겨줘
/herdr-wt:wt 42 --prompt
/herdr-wt:wt-done
/herdr-wt:wt-done --auto
/herdr-wt:wt-done --keep --auto
```

## 저장소 지침 — `.claude/wt.md`

각 저장소가 `.claude/wt.md` 로 자기 값을 정한다. base 브랜치, 브랜치 종류, 이슈 트래커(Jira·GitHub Issues) 연동, 결과 코멘트에 담을 것, 에이전트 정책, 첫 지시에 채울 값(리뷰 행·검증·끝맺음)이 여기 온다. 스킬은 시작할 때 이 파일을 읽고 각 단계에서 관련 지시를 따른다.

`plugins/herdr-wt/examples/wt.md` 를 복사해 시작한다. 자유형 마크다운이므로 필요한 절만 남긴다.

```
cp plugins/herdr-wt/examples/wt.md <저장소>/.claude/wt.md
```

지침은 단계를 더하거나 값을 정할 뿐, 단계의 순서와 승인·재확인 지점은 바꾸지 못한다. 파일이 없으면 base 는 `develop`, 이슈 트래커는 없는 것으로 진행한다.

## harness

자기 개선 하네스 엔진이다. 세션 원장을 모으고(`hooks/collect.sh`), 반복 실패를 관찰해 OBS 로 쓰고(`/harness:observe`), 변경 하나를 제안해 eval 로 기준선과 비교하고(`/harness:propose`), 보고서 없는 하네스 PR 을 막는다(`gh pr create` 게이트). 프로젝트에 남는 것은 `.claude/harness/` 한 디렉터리다. 준비 절차와 게이트 조건은 `plugins/harness/README.md` 에 있다.

이 저장소 자신이 첫 적용 대상이다 — `.claude/harness/cases/` 에 사례가 있고 검증 동사는 `make check` 다.

## step

OneMoreStep 이다. 개인 작업 방식을 스킬로 담는 묶음이며, 스킬은 `/step:<이름>` 으로 부른다. 사용자가 부를 때만 실행된다.

- `prompt-check` — 업무 지시 프롬프트를 보내기 전에 다섯 칸(목표 · 완료 판정 · 보여 줄 증거 · 이미 아는 것 · 제약)을 판정하고, 빠진 칸을 메우고 방법 지정 · 원인 추측은 뺀 판을 낸다. 프롬프트 밖에서만 알 수 있는 값은 지어내지 않고 묻는다

```
/step:prompt-check csv 내보내기가 어제 배포 뒤로 마지막 행을 빠뜨린다. 고쳐줘
```

## todo

할 일 목록을 「사람 차례」와 「Claude 작업」 두 구역으로 갈라 pane 에 보이는 mod 다. 스킬이 아니라 hooks 모듈(`plugins/todo/hooks/register.tsx`)이다.

- `/todo` — pane 이 보이는 중이면 닫고, 아니면 연다
- Claude 가 할 일을 적으면 pane 이 스스로 열린다. 터미널 폭이 좁으면 `/todo` 를 칠 때까지 기다린다

```
/todo
```

전제와 한계는 다음과 같다.

- [claude-mem](https://github.com/thedotmack/claude-mem) 의 `work_state_write` 호출을 비춘다. claude-mem 이 없으면 pane 은 늘 비어 있다
- 시스템 프롬프트 끝에 한 줄을 붙인다 — 사용자가 직접 실행할 단계는 `fields` 에 `who: "user"` 를 넣으라는 규약이다. 그 항목이 「사람 차례」로 간다
- 그 세션에서 본 쓰기만 보인다. 이전 세션에서 열어 둔 항목은 보이지 않는다

시험은 `claude plugin test plugins/todo` 로 실행한다 — `make check` 는 이 시험을 돌리지 않는다.

## 검사

매니페스트와 문서 참조를 검사한다. 통과하면 `통과` 를 출력하고 종료코드 0 을 반환한다.

```
make check
```

`check` 는 `python3 scripts/check-plugin.py`(매니페스트 · 문서 참조)와 `sh plugins/harness/test.sh`(harness 엔진 테스트)를 차례로 실행한다.
