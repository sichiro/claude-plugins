---
name: ablate
description: 하네스 파일 하나를 뺀 후보를 만들어 기준선과 반복 비교한다 — 그 파일이 없어도 성적이 같은지 잰다. "이 규칙 없어도 되나" · "ablation" · "규칙 삭제 후보" 지시에 쓴다. 승격은 하지 않는다
---

인자는 하네스 파일 경로 하나다(예. `.claude/rules/worktree.md`). `.claude/harness/` 아래(사례 · 관찰 · 제안 · 보고서)는 대상이 아니다 — 하네스가 아니라 데이터다.

`paths:` 프론트매터가 있는 규칙도 대상이 아니다 — 사례 묶음이 그 경로를 건드리지 않으면 어느 쪽 실행에서도 로드되지 않아, 뺐을 때 차이가 없는 것은 근거가 아니다. 항상 로드되는 규칙(`paths` 없음)·스킬·에이전트만 잰다.

「로드되지 않는 규칙」(`metrics.sh` 의 `rules_never_loaded`)과 「없어도 되는 규칙」은 다르다. 항상 로드되는 규칙은 전자로 잡히지 않는다. 이 스킬이 후자를 잰다.

**저장소별 값.** base 브랜치와 봉인 묶음 경로는 `/harness:propose` 와 같은 규칙이다 — base 는 `.claude/wt.md` 의 값(없으면 `gh repo view --json defaultBranchRef -q .defaultBranchRef.name`), 봉인 묶음은 `~/.claude/harness-evals/<저장소명>/sealed`(없으면 `--sealed` 생략).

**비용을 먼저 말한다.** 사례 수 × 반복 3 × (기준선 + 후보) 회. 사례 10개면 60회, 약 25 USD, 30~60분. 사용자가 받아들이면 진행한다.

1. 브랜치를 만들고 파일을 뺀다.

```bash
F=$1; NAME=$(basename "$F" .md)
case "$F" in .claude/harness/*) echo "프로젝트 데이터는 대상이 아니다: $F" >&2; exit 2;; esac
grep -q '^paths:' "$F" 2>/dev/null && { echo "paths 스코프 규칙은 대상이 아니다: $F" >&2; exit 2; }
git switch -c "harness/ablate-$NAME" && git rm -q "$F" && git commit -q -m "ablation 후보 — $F 를 뺀다"
```

2. 기준선과 후보를 같은 봉인 묶음으로 3회 반복 비교한다. `report.sh` 는 두 실행의 model 이 다르면 만들지 않는다. `BASE_NAME` 첫 줄을 위 규칙의 값으로 채운다.

```bash
BASE_NAME=develop   # .claude/wt.md 의 base. 없으면 gh repo view --json defaultBranchRef -q .defaultBranchRef.name
git fetch origin "$BASE_NAME"
BASE=$(git rev-parse "origin/$BASE_NAME"); CAND=$(git rev-parse HEAD)
SEALED=~/.claude/harness-evals/$(basename -s .git "$(git remote get-url origin)")/sealed
if [ -d "$SEALED" ]; then S="--sealed $SEALED"; else S=""; fi
E="${CLAUDE_PLUGIN_ROOT}/evals"
sh "$E/run.sh" --harness "$BASE" --out /tmp/abl-base $S --repeat 3
sh "$E/run.sh" --harness "$CAND" --out /tmp/abl-cand $S --repeat 3
sh "$E/report.sh" /tmp/abl-base /tmp/abl-cand ".claude/harness/reports/$CAND.json"
```

3. 판정한다 — 보고서의 `regressed` 가 비어 있으면 `removable`, 비어 있지 않으면 `keep`. `errors` 가 비어 있지 않으면 판정하지 않고 오류부터 본다.

4. IMP 를 쓴다 — `.claude/harness/proposals/IMP-<YYYYMMDD>-<NN>.yaml`. 그때의 모델·버전을 함께 적는다. 모델이 바뀌면 이 결론은 옛것이다.

```yaml
id: IMP-20260913-01
type: ablation
target: <뺀 파일 경로>
model: <보고서의 model>
claude_version: <보고서의 claude_version.candidate>
repeat: 3
report: .claude/harness/reports/<CAND>.json
verdict: removable | keep
regressed: [<사례>]
```

5. `removable` 이면 IMP 와 보고서를 커밋하고 push 한 뒤 `gh pr create --base "$BASE_NAME"` 한다 — 게이트가 보고서를 대조한다. `keep` 이면 PR 을 만들지 않는다. 브랜치는 남겨 두고 IMP 내용을 보고에 붙인다 — 사용자가 기록으로 남길지 정한다.

6. 첫 줄에 `removable` · `keep` 과 `regressed` 사례를 쓰고 사례별 비율 표를 붙여 보고한다. 머지는 사용자가 한다.
