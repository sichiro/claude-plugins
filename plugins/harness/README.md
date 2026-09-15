# harness

자기 개선 하네스 엔진. 세션 원장을 모으고, 반복 실패를 관찰(OBS)하고, 변경 하나를 제안(IMP)해 eval 로 기준선과 비교하고, 보고서 없는 하네스 PR 을 막는다. 프로젝트에 남는 것은 `.claude/harness/` 한 디렉터리다.

## 설치

```
/plugin marketplace add sichiro/claude-plugins
/plugin install harness@sichiro
```

## 전제

엔진은 아래 도구가 장비에 있다고 전제한다.

- `jq` · `git` · `make` · `shasum` — 훅 · 게이트 · 러너가 모두 쓴다.
- `gh` — 로그인 상태여야 한다. 게이트가 PR 과 기본 브랜치를 조회한다.
- `claude` CLI — 사례를 실제로 평가할 때 쓴다.
- `timeout`(GNU coreutils) — 실제 평가에서 사례 하나를 끊는다. macOS 는 `brew install coreutils` 로 넣고, `gtimeout` 이름도 인식한다. `--dry-run` 에는 필요 없다.

이 저장소를 직접 개발할 때는 `python3` 를 더 쓴다 — `scripts/check-plugin.py` 가 그것으로 돈다.

## 저장소 준비

설치 즉시 PR 게이트가 켜진다 — 사례와 보고서를 두기 전에는 `.claude/` · `CLAUDE.md` 를 건드린 모든 PR 이 막힌다. 그래서 준비 순서는 아래와 같다.

1. `.claude/harness/cases/<사례>/` 를 만든다 — `prompt.md`(평가 대상에 줄 지시) · `expect.json`(`{"status":"PASS|FAIL|UNMEASURED","require_targets":["<make target>"]}`) · `fixture/`(가짜 저장소 — `Makefile` 의 recipe 가 `sh .harness-receipt.sh <target> <exit>` 를 부르고 canned 출력을 낸다) · `dry-run.result.json`(모델 없이 러너를 돌릴 때의 verdict).
2. 검증 명령을 make target 으로 노출한다. 영수증은 make 안에서 불린 것만 실행 증거로 친다.
3. `.claude/wt.md` 에 「base 는 `<브랜치>`」 를 적는다. 없으면 GitHub 기본 브랜치를 쓴다.
4. `.gitignore` 에 `.claude/harness/runs/` 를 더한다. 원장은 장비 로컬이다.
5. `.claude/settings.json` 의 `enabledPlugins` 에 `"harness@sichiro": true` 를 적는다(팀에 공유할 때). 개인 설치면 생략한다.
6. 봉인 사례를 쓰려면 `~/.claude/harness-evals/<저장소명>/sealed/<사례>/` 에 1번과 같은 구조로 사례를 두고, 플러그인 캐시 경로의 `evals/run.sh --sealed-manifest ~/.claude/harness-evals/<저장소명>/sealed > .claude/harness/sealed.manifest` 로 manifest 를 만들어 커밋한다. 봉인 사례 자체는 저장소에 넣지 않는다.

## 루프

```
세션 실행(훅이 원장 기록) → /harness:observe → OBS → /harness:propose OBS-… → 브랜치 + IMP → 기준선·후보 비교 → 보고서 → PR(게이트) → 사용자 머지
```

- `/harness:observe` — 원장에서 반복 실패를 뽑아 `.claude/harness/observations/OBS-*.yaml` 로 쓴다.
- `/harness:propose <OBS id>` — 변경 하나를 브랜치로 만들고 `.claude/harness/proposals/IMP-*.yaml` 을 쓴 뒤 기준선과 비교해 `.claude/harness/reports/<sha>.json` 을 만든다.
- `/harness:ablate <파일>` — 파일 하나를 뺀 후보를 3회 반복 비교해 `removable` · `keep` 을 판정한다.
- 수치는 플러그인 캐시 경로의 `scripts/metrics.sh` 로 본다(예. `sh ~/.claude/plugins/cache/sichiro/harness/<버전>/scripts/metrics.sh`). 인자 없이 `.claude/harness/runs` · `.claude/rules` 를 읽는다.

## 게이트

`gh pr create` · `gh pr merge` 에서 브랜치가 하네스(`.claude/` · `CLAUDE.md`, `.claude/harness/{observations,proposals,reports}` 제외)를 건드렸으면 유효한 보고서를 요구한다. 유효 조건 — `base_sha` 가 PR base 와 같다 · `evaluated_sha` 이후 하네스 트리 변경 없음 · `suite_sha` 가 대상의 `.claude/harness/cases` 트리와 같다 · 사례 집합이 `cases/` ∪ `sealed.manifest` 와 같다 · `regressed` · `errors` 가 비었다. base 는 명령의 `--base`, 없으면 GitHub 기본 브랜치다. `--repo` · `--head` 형태는 거부한다.

## 저장소별 값의 출처

| 값 | 출처 |
|---|---|
| PR base | `.claude/wt.md` 의 「base 는 `X`」. 없으면 `gh repo view --json defaultBranchRef -q .defaultBranchRef.name` |
| 저장소명(봉인 묶음 경로) | `basename -s .git "$(git remote get-url origin)"` → `~/.claude/harness-evals/<저장소명>/sealed` |
| 검증 명령 | 사례의 `prompt.md` 와 `expect.json` 의 `require_targets` |

## 클린룸

평가 대상 세션은 `--setting-sources project` 로 뜨고, materialize 는 `.claude/harness` 를 지우고 `settings.json` 의 `enabledPlugins` 를 제거한다. 사용자 플러그인 · 메모리 · 이 플러그인의 훅이 평가 대상에 실리지 않는다.

## 범위 밖

managed settings 보호 계층(커밋 게이트 · deny 목록)은 이 버전에 없다. 보고서의 `managed` 는 기록만 하고 게이트 조건이 아니다.

## 엔진 개발자용

- 에이전트 호출명: `harness:harness-observer` · `harness:harness-proposer` — `claude --plugin-dir` 로 실측한 값이다. 스킬은 이 값을 `subagent_type` 에 쓴다.
- 테스트: `sh plugins/harness/test.sh`. 엔진 파일을 고쳤으면 커밋 전에 돌린다.
- 로컬 실측: `claude --plugin-dir "$PWD/plugins/harness"`.

| 파일 | 역할 |
|---|---|
| `hooks/collect.sh` | 세션 이벤트 9종을 `.claude/harness/runs/<session>.jsonl` 에 남긴다. fail-open |
| `hooks/gate-harness-pr.sh` | PR 게이트. fail-closed |
| `evals/run.sh` | 하네스 해시를 fixture 위에 materialize 하고 사례마다 `claude -p` 를 돌려 grade 한다 |
| `evals/grade.sh` | 결과 · 영수증 · 기대값으로 PASS · FAIL · UNMEASURED · ERROR 를 판정한다 |
| `evals/report.sh` | 기준선 · 후보 두 실행을 사례별 비율로 비교한 보고서를 만든다 |
| `evals/receipt.sh` | fixture 의 Makefile recipe 가 부르는 영수증 기록기 |
| `scripts/metrics.sh` | 원장 → 세션 · 교정 · 도구 실패 · 규칙 로드 수 |
