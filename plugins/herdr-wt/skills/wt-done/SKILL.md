---
name: wt-done
description: 이슈 작업이 끝나 정리할 때 사용한다. "정리해줘" · "마무리해줘" · "머지하고 정리" 지시, PR 을 머지하고 Jira 를 닫고 worktree 를 지워야 할 때 쓴다. 되돌릴 수 없는 단계가 섞여 있어 순서가 고정이다
---

# 작업을 끝내고 정리한다

**순서가 고정이다** — 뒤로 갈수록 되돌릴 수 없고, 마지막 단계는 이 세션을 함께 종료한다.

| 순서 | 하는 일 | 되돌릴 수 있나 |
|---|---|---|
| 0 | 사전 점검 + 승인 | 예 |
| 1 | PR 머지 | 아니오 |
| 2 | Jira 완료 + 결과 코멘트 | 예 |
| 3 | pane 정리 (기본은 생략) | 예 |
| 4 | worktree 제거 | 아니오 — **이 세션이 함께 종료된다** |

각 단계마다 **한 항목씩 태스크를 생성하고 시작한다.**

**묻는 것은 0단계 한 번뿐이다.** 거기서 승인을 받으면 1~4단계는 되묻지 않고 끝까지 진행한다.

## 0. 사전 점검 — 물을 기회는 여기뿐이다

4단계가 이 세션을 종료한다. **마감을 시작하기 전에 아래 표를 한 번에 조사한다.**

```bash
gh pr view --json number,state,mergeable,mergeStateStatus
git status --short
git log --oneline @{u}..HEAD 2>/dev/null || echo "upstream 미설정 — 아직 push 하지 않았다"
git diff --stat origin/develop...HEAD -- game-server/build/protobuf/src/   # 클라 후속 신호 ① — 비어 있지 않으면 클라가 있다
herdr pane current       # 내 workspace_id
herdr agent list         # 그 id 로 걸러 살아 있는 pane 을 센다
```

**`gh pr view` 에 번호를 넣지 않는다.** 번호를 넣으려면 PR 이 있다는 것을 이미 알아야 해서 "PR 이 있나"를 묻지 못한다. 번호를 빼면 현재 브랜치의 PR 을 찾아 `number` 까지 함께 제공한다 — 1단계의 머지가 그 값을 쓴다. PR 이 없으면 `no pull requests found for branch "..."` 와 종료코드 `1` 이다 (2026-08-24 실측 — PR #52 가 붙은 worktree 와 PR 이 없는 develop 양쪽에서 확인).

Jira 는 `getJiraIssue` 로 현재 상태를 확인한다. `@{u}` 는 push 하지 않은 브랜치에서 `fatal` 로 실패하므로 폴백을 붙인 채로 쓴다 (2026-08-24 실측 — 붙이면 종료코드 `0`).

**조회만 하지 않는다. 어떤 값에서 멈추는지가 판정이다.**

| 점검 | 정상 | 아니면 |
|---|---|---|
| PR 이 있나 | 종료코드 `0` | `1` 이면 PR 이 없다. 멈추고 묻는다 |
| `state` | `OPEN` | `MERGED` 면 1단계를 건너뛴다. `CLOSED` 면 멈추고 묻는다 |
| `mergeable` | `MERGEABLE` | `CONFLICTING` 이면 머지되지 않는다. `UNKNOWN` 은 아래를 따른다 |
| `git status --short` | 빈 출력 | 미커밋·untracked 는 worktree 와 함께 사라진다 |
| 미푸시 커밋 | 없음 | 커밋은 했는데 PR 에 없다 |
| Jira 상태 | 완료가 아님 | 이미 완료면 2단계를 건너뛴다 |
| 내 workspace 의 다른 에이전트 | 없음 | 4단계가 그 pane 들을 함께 종료한다 — 리뷰어 출력이 사라진다 |
| 클라 후속 | 신호 없음, 또는 클라 이슈·인수인계 코멘트가 이미 있음 | 신호가 있는데 둘 다 없으면 승인 질문에 「클라 이슈 생성 + 인수인계」를 함께 묶는다 |

**`mergeable: UNKNOWN` 을 "머지 불가"로 읽지 않는다.** GitHub 이 mergeability 를 비동기로 계산해서 **갓 push 한 PR 과 이미 머지된 PR 이 둘 다 `UNKNOWN`** 이다 (2026-08-24 실측 — PR #52 가 `state: MERGED` 인 채 `mergeable: UNKNOWN`·`mergeStateStatus: UNKNOWN` 이었다). `wt-done` 은 보통 push 직후에 호출되므로 드물지 않다. **먼저 `state` 로 가른다** — `MERGED` 면 끝난 것이고, `OPEN` 인데 `UNKNOWN` 이면 몇 초 뒤 한 번 다시 조회한다. 그래도 `UNKNOWN` 이면 그 사실을 승인 질문에 적는다.

**`herdr agent list` 는 다른 사람 작업까지 전부 반환한다** — `workspace_id` 로 거르지 않으면 남의 pane 을 내 것으로 센다. 거르는 코드는 3단계에 있다.

**CI 와 PR 리뷰는 조회하지 않는다.** 이 저장소는 `.github/workflows/` 가 없고 코드리뷰가 GitHub 에 남지 않아 `statusCheckRollup`·`reviewDecision`·`reviews`·`comments` 가 **항상 빈다** (2026-08-24 PR #45·#46·#47·#50 실측 — 넷 모두 빈 값이었다). 조회하면 언제나 "이상 없음"이 나오는 죽은 점검이다.

**클라 후속은 신호 셋으로 판단한다.** ① 브랜치의 proto 변경(위 `git diff` — 클라 재빌드가 필요하다는 기계 신호) ② manifest 의 `Proto:` 칸·`검증-수동` 의 클라 언급 ③ 이슈 본문·PR 의 클라 연계 서술(광고 모델·UI·연출 등 — 판단). 하나라도 걸리면 클라 이슈가 이미 있는지 확인한다 — `project = MGR AND text ~ "<서버 이슈키>"` 로 검색한다(2026-08-27 실측 — MGR-179 로 던지면 클라 이슈 MGR-191 이 나온다. 요약 관례가 서버 이슈키를 담기 때문이다). 없으면 생성 제안을 승인 질문에 묶고, 있으면 인수인계 코멘트가 남았는지만 확인한다. **이 행이 없던 2026-08-27 이전에는 MGR-182(proto 4파일 변경, 광고 모델 전환)가 클라 이슈 없이 완료로 닫혔다** — 인수인계가 사람 기억에만 남았다.

조사 결과를 **`AskUserQuestion` 한 번으로 묶어** 승인받는다. 걸린 것이 없어도 그 사실을 적어 진행 여부를 묻는다 — 사용자가 물을 것이 남아 있는지는 명령으로 알 수 없다.

## 1. PR 머지

상태도 번호도 0단계에서 이미 얻었다. 바로 머지한다.

```bash
gh pr merge <번호> --squash
```

**`--squash` 를 생략한다면 그것은 틀린 것이다.** 이 저장소는 squash 병합만 허용한다.

**원격 브랜치는 따로 지우지 않는다.** 이 저장소는 `deleteBranchOnMerge` 가 켜져 있어 머지와 함께 사라진다(2026-08-24 실측 — `gh repo view --json deleteBranchOnMerge` 가 `true`). `git push origin --delete` 를 이어 붙이면 `error: unable to delete ...: remote ref does not exist` 가 발생한다. 아래 확인에서 `2` 가 아닐 때만 지운다.

**`--delete-branch` 도 쓰지 않는다.** 그 플래그는 머지 뒤 로컬 `develop` 을 체크아웃하려 하는데, `develop` 은 메인 체크아웃이 잡고 있어 **어느 worktree 에서도 반드시 실패한다**(`.claude/rules/worktree.md`). 설정이 자동으로 지우므로 필요도 없다.

> 이미 `--delete-branch` 로 실행해 `failed to run git: fatal: 'develop' is already used by worktree at ...` 를 봤다면, **머지 자체는 성공해 있다.** 에러만 보고 재시도하지 말고 아래 확인으로 넘어간다.

**두 가지를 확인한다.**

```bash
gh pr view <번호> --json state,mergedAt                       # MERGED 여야 한다
git ls-remote --exit-code --heads origin <브랜치> >/dev/null; echo $?
```

종료코드로 판정한다 — `2` 면 삭제된 것이고, `0` 이면 브랜치가 남아 있으니 그때만 `git push origin --delete <브랜치>` 로 지운다. **`| wc -l` 로 세지 않는다**: 원격 이름이 틀리거나 네트워크가 죽어도 `0` 줄이 나와 "삭제됨"과 구분되지 않는다(종료코드 `128` 이 그 경우다).

## 2. Jira 완료 + 결과 코멘트

**0단계에서 이미 완료였으면 전환하지 않고 코멘트만 남긴다.** 여는 쪽에도 같은 가드가 있다 — `.claude/commands/wt.md` 8단계는 완료 이슈에 전환 `31` 을 적용하면 `isGlobal` 이라 조용히 재오픈된다고 적었다. 닫는 쪽도 같은 자리에 둔다.

**전환 id 로 지정한다.** 상태 이름(`"완료"`)으로 지정할 자리가 없고, 이름으로 찾으려 하면 통하지 않는다 — CLAUDE.md 의 JQL 규칙과 같은 이유다.

| 상태 | 상태 id | 전환 id |
|---|---|---|
| 완료 | `10092` | `41` |
| 진행 중 | `10094` | `31` |
| 개발하기로 선택됨 | `10091` | `21` |
| 백로그 | `10093` | `11` |

이 표는 2026-08-24 MGR-135 의 `getTransitionsForJiraIssue` 응답에서 옮겼다. **실제로 실행해 본 것은 완료(`41`) 하나다.** 값이 바뀌었을 수 있으니 실패하면 `getTransitionsForJiraIssue` 로 다시 얻는다.

```
transitionJiraIssue(issueIdOrKey: "MGR-135", transition: {id: "41"})
```

**전환만 하고 끝내지 않는다.** 결과 코멘트를 남긴다 — 이슈를 다시 여는 사람이 PR 을 열지 않고도 알아야 하는 것들이다.

- PR 링크
- **이슈가 지목하지 않았지만 함께 고친 것** — 왜 그것까지 건드렸는지
- **이슈의 서술이 틀렸던 지점** — "테스트가 없다"고 적혀 있었지만 있었다면 그 사실
- 실측으로 닫은 판단 — 무엇을 재서 무엇을 하지 않기로 했는지
- 작업 중 발견한 무관한 결함

**0단계에서 클라 이슈 생성을 승인받았으면 여기서 생성한다 — 일감의 인수인계다.**

- 요약: `클라 - <주제> — 서버는 <이슈키> 로 완료` (MGR-191 판례. 서버 이슈키가 요약에 있어야 0단계의 `text ~` 검색에 걸린다)
- 유형 `작업`, 담당은 클라(박덕권, accountId `5fbf0cf59592df0076ea8350` — 2026-08-27 lookupJiraAccountId 실측. 실패하면 다시 조회한다). 상태는 기본값(백로그)에 둔다 — 착수 시점은 클라가 정한다
- **상위(에픽)는 서버 이슈의 것을 그대로 지정한다** — `getJiraIssue` 로 서버 이슈의 `parent` 를 읽어 넘긴다. 같은 기능의 서버·클라 짝이 다른 에픽에 흩어지면 백로그에서 짝을 보지 못한다. MGR-191 판례 — 서버 MGR-179 와 같은 에픽(MGR-171) 아래다. 2026-08-27 MGR-201 첫 등록에서 이 지정이 누락됐다
- 본문에 클라가 PR 을 열지 않고도 착수할 수 있는 것들을 적는다: 서버가 바꾼 것 / 클라가 할 일 / **proto 재빌드 필요 여부와 바뀐 메시지·커맨드 이름** / 확인 방법 / 서버 PR·manifest 참조
- 서버 이슈의 완료 코멘트에 클라 이슈 키를 남긴다 — 양방향 참조가 있어야 어느 쪽에서 열어도 짝을 찾는다

## 3. pane 정리 — 기본은 생략한다

4번이 workspace 를 통째로 닫으므로 **보통은 할 필요가 없다.** 리뷰어 출력을 더 볼 일이 없어 미리 정리하고 싶을 때만 한다.

**`herdr agent stop` 은 없는 명령이다.** pane 을 닫으면 그 안의 에이전트도 함께 종료된다.

```bash
herdr pane current                       # 내 workspace_id 를 먼저 얻는다
herdr agent list                         # 전체 workspace 가 나온다 — 반드시 거른다
herdr pane close <pane-id>
```

**`herdr agent list` 는 다른 사람 작업까지 전부 반환한다.** `workspace_id` 가 내 것인 pane 만 골라야 한다 — 거르지 않고 닫으면 **남의 세션을 종료시킨다.**

```bash
herdr agent list | python3 -c "
import json,sys
d=json.load(sys.stdin)
for a in d['result']['agents']:
    if a.get('workspace_id')=='<내 workspace_id>': print(a.get('name'), a.get('pane_id'))
"
```

## 4. worktree 제거 — 실행하면 이 세션이 끝난다

**먼저 workspace ID 를 얻는다. 예측하지 않는다.**

```bash
herdr worktree list
```

**이 목록에는 메인 체크아웃(`branch: develop`, `.../Projects/MasterGirl/mgr-servers`)과 다른 사람의 feature worktree 가 함께 들어 있다.** 잘못 고른 `--force` 는 그것들을 유실시킨다. `path` 가 지금 작업 중인 worktree 와 일치하는 행의 `open_workspace_id` 만 쓴다.

지우기 전에 두 가지를 확인한다.

```bash
git status --short                          # 비어 있어야 한다
gh pr view <번호> --json state,mergedAt      # MERGED 여야 한다
```

**`git log origin/develop` 로 내 커밋을 찾지 않는다.** squash 병합이라 내 커밋 SHA 는 develop 에 절대 나타나지 않는다 — 항상 "없음"이 나와 판정이 무의미하다. 커밋이 들어갔는지는 **PR 이 MERGED 인지로** 본다.

미커밋 변경이 남아 있거나 PR 이 MERGED 가 아니면 **지우지 않는다.** 사용자에게 확인을 구한다.

```bash
herdr worktree remove --workspace <ID> --force
```

workspace 가 닫히면서 **이 세션도 함께 종료된다.** 그래서 반드시 마지막이다.

**0단계는 승인을, 4단계는 재확인을 한다. 재확인 결과가 0단계와 같으면 되묻지 않고, 다르면 멈추고 묻는다.** 0단계 승인은 "이상 없음"에 대한 승인이지 무슨 일이 있어도 지우라는 위임이 아니다. 이 명령만은 **어느 allowlist 에도 넣지 않아** 권한 프롬프트가 마지막 안전장치로 한 번 표시된다 — `.claude/settings.json` 에도, `.claude/settings.local.json` 에도 없다.

`EnterWorktree` 로 만든 worktree 라면 이 명령이 아니다. `.claude/rules/worktree.md` 의 `ExitWorktree` 절차를 따른다.

## 이 스킬을 개선하려면 — transcript 는 세션이 종료돼도 남는다

4단계가 세션을 끝내므로 **여기서 걸린 것을 이 세션에서는 고칠 수 없다.** 대신 기록이 `~/.claude/projects/` 에 남는다 — worktree 를 지워도 함께 지워지지 않는다. 2026-08-24 20:16 에 살아 있는 worktree 는 넷, transcript 디렉터리는 39개였다. **이 수는 금방 낡는다** — 논지는 수가 아니라 한쪽만 지워진다는 것이다.

**메인 체크아웃 세션에서** 이슈키로 찾는다.

```bash
ls -t ~/.claude/projects/*mgr-servers-*<이슈키 소문자>-*/*.jsonl
```

**이슈키 뒤의 `-` 를 빼지 않는다.** 빼면 짧은 키가 긴 키를 함께 잡는다 — `mgr1` 이 `mgr106`·`mgr112`·`mgr119` 를 포함해 **열다섯 디렉터리**를 물어 온다(2026-08-24 실측). `head -1` 을 붙이면 그중 가장 최근에 수정된 것이 조용히 나와, 엉뚱한 세션을 회고하게 된다. `-` 를 붙이면 `mgr1-`·`mgr11-` 이 0개, `mgr106-`·`mgr112-` 가 각각 1개다. worktree 디렉터리명이 `<종류>-<이슈키>-<주제>` 라 이슈키 뒤에는 항상 `-` 가 온다.

여러 줄이 나오면 세션이 여럿이었던 것이다 — 골라서 쓴다. 한 줄도 없으면 zsh 가 `no matches found` 를 낸다. 기록이 없다는 뜻이다.

디렉터리명은 worktree 경로에서 왔고, worktree 디렉터리명은 **브랜치명의 `/` 를 `-` 로 바꾼 값**이다 — `feature/mgr106-gm-login-throttle` 이면 `feature-mgr106-gm-login-throttle`. 라벨이 아니다. 찾은 파일을 `/harness-retro` 에 넘기면 그 마감에서 무엇이 걸렸는지 나온다.

2026-08-24 MGR-106 마감의 transcript 에서 `Blocked by classifier` 가 **네 번** 그대로 읽혔다(`grep -o ... | wc -l`). 그 세션의 worktree 는 이미 없다. **줄 수와 출현 횟수를 섞지 않는다** — `grep -c` 는 줄을 세지 출현을 세지 않는다(같은 파일에서 줄 2, 출현 4 였다).

## 자주 틀리는 것

| 이렇게 한다 | 왜 |
|---|---|
| `gh pr merge --delete-branch` 를 쓴다 | 어느 worktree 에서도 반드시 실패한다. 설정이 자동으로 지우므로 필요도 없다 |
| 머지 뒤 `git push origin --delete` 를 이어 붙인다 | `deleteBranchOnMerge` 가 이미 지웠다. `remote ref does not exist` 가 발생한다 |
| 그 에러를 보고 머지를 재시도한다 | 머지는 이미 됐다. `state` 와 `ls-remote` 종료코드로 확인부터 |
| `--squash` 를 뺀다 | 이 저장소는 squash 만 허용한다 |
| `ls-remote \| wc -l` 로 삭제를 판정한다 | 네트워크·원격 오류도 0 줄이다. `--exit-code` 의 종료코드를 본다 |
| 상태만 바꾸고 코멘트를 남기지 않는다 | 다음 사람이 PR 을 열어야만 맥락을 안다 |
| 클라 연계가 보이는데 서버 이슈만 닫는다 | 인수인계가 사람 기억에만 남는다. proto 를 바꾼 MGR-182 가 클라 이슈 없이 닫혔다 (2026-08-27) |
| `herdr agent stop` 을 호출한다 | 없는 명령이다. `herdr pane close` |
| `agent list` 결과를 거르지 않고 닫는다 | 다른 사람 세션이 함께 나온다. 남의 작업을 종료시킨다 |
| `--workspace` ID 를 짐작한다 | 목록에 메인 체크아웃이 섞여 있다. `--force` 가 그것을 유실시킨다 |
| `git log origin/develop` 로 내 커밋을 찾는다 | squash 라 SHA 가 남지 않는다. PR 의 `MERGED` 로 본다 |
| worktree 를 먼저 지운다 | 세션이 종료돼 나머지 단계를 수행하지 못한다 |
| 0단계를 건너뛰고 바로 머지한다 | 물을 기회는 그때뿐이다. 4단계가 세션을 끝낸다 |
| 이상이 없는데 1~4단계 중간에 확인을 구한다 | 승인은 0단계에서 받았다. 정상 경로의 중간 질문은 중복이다 |
| 4단계 재확인에서 이상이 나왔는데 그대로 진행한다 | 0단계 승인은 "이상 없음"에 대한 승인이다. 달라졌으면 멈춘다 |
| `mergeable: UNKNOWN` 을 머지 불가로 읽는다 | 갓 push 한 PR 과 이미 머지된 PR 이 둘 다 그렇다. `state` 로 먼저 가른다 |
| CI·리뷰 상태를 0단계에서 조회한다 | 이 저장소에서는 항상 빈다. 죽은 점검이다 |
| 0단계의 `gh pr view` 에 번호를 넣는다 | 번호를 알아야 실행되니 "PR 이 있나"를 묻지 못한다 |

## 이 문서의 근거

2026-08-24 MGR-135 마무리에서 걸린 것과, 그 뒤 코드리뷰가 짚어 실측으로 확인한 것을 옮겼다.

- `gh pr merge --delete-branch` 가 에러를 뱉었으나 머지는 성공해 있었다
- `herdr agent stop` 은 존재하지 않아 실패했다
- `herdr agent list` 는 무관한 workspace 다섯을 함께 반환했다
- `herdr worktree list` 에 메인 체크아웃이 `develop | w2` 로 섞여 나왔다
- `git ls-remote --heads <없는 원격> | wc -l` 이 `0` 을 반환했다(종료코드 `128`)
- PR #46 을 머지한 뒤 `git push origin --delete` 가 `remote ref does not exist` 로 떨어졌다 — `deleteBranchOnMerge` 가 이미 지운 뒤였다

명령은 4번의 `worktree remove` 를 뺀 전부를 실행해 확인했다 — 그것은 `.claude/rules/worktree.md` 에 있는 것을 옮겼다.

클라 후속 점검(0단계 표의 마지막 행·2단계 인수인계 절)은 2026-08-27 에 더했다 — MGR-182 가 proto 4파일을 바꾸고도 클라 이슈 없이 닫혔다. `text ~` JQL·lookupJiraAccountId·proto diff 명령은 그날 실측했다.

0단계와 개선 절은 2026-08-24 MGR-106 마감이 권한 분류기에 네 번 막혀 사용자가 `gh pr merge` 를 직접 실행한 뒤에 더했다. 그때 함께 잰 것들이다.

- PR #45·#46·#47·#50 의 `reviewDecision`·`statusCheckRollup`·`reviews`·`comments` 가 모두 비었다 — `.github/workflows/` 가 없다
- `git log --oneline @{u}..HEAD` 는 upstream 없는 브랜치에서 `fatal` 이다. `2>/dev/null || echo` 를 붙이면 종료코드 `0`
- allowlist 를 범위로 갈랐다. **조회 명령**(`gh pr view`·`gh pr list`·`gh repo view`·`git ls-remote`·`herdr worktree list`·`herdr pane current`·`herdr pane list`·`herdr agent list`)은 커밋되는 `.claude/settings.json` 에, **`gh pr merge`** 는 gitignore 되는 `.claude/settings.local.json` 에 두었다 — 앞의 파일은 이 저장소를 클론하는 모두에게 걸리고, `gh pr merge:*` 는 접두사 매칭이라 `-R` 로 다른 저장소 PR 까지 닿는다
- `herdr worktree remove` 는 두 파일 어디에도 넣지 않았다. 되돌릴 수 없는 유일한 단계에 사람의 눈을 한 번 남긴다
- `Bash(herdr worktree list:*)` 로 접두사 매칭을 썼다. `remove` 는 접두사가 달라 그대로 프롬프트가 뜬다 (2026-08-24 확인)
