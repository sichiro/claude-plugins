---
name: propose
description: OBS 하나로 하네스 변경 하나를 브랜치와 IMP 로 만들고 eval 로 기준선과 비교한다. "OBS-… 제안해줘" · "하네스 개선안" 지시에 쓴다. 승격은 하지 않는다
---

인자는 OBS id 하나다.

**저장소별 값.** base 브랜치는 `.claude/wt.md` 의 「base 는 `X`」 값이다. 파일이 없거나 base 가 없으면 `gh repo view --json defaultBranchRef -q .defaultBranchRef.name` 의 값이다. 봉인 묶음은 `~/.claude/harness-evals/<저장소명>/sealed` 이고 저장소명은 `basename -s .git "$(git remote get-url origin)"` 이다. 그 디렉터리가 없으면 `--sealed` 를 빼고 discovery 사례(`.claude/harness/cases/`)만 비교한다.

1. `harness-proposer` 에이전트를 띄운다 — Agent(subagent_type: "harness:harness-proposer", prompt: "<OBS id> 에 대해 변경 하나를 브랜치로 만들고 IMP 를 써라")
2. 에이전트가 답한 브랜치에서 기준선과 후보를 평가한다. `BASE_NAME` 첫 줄을 위 규칙의 값으로 채운다.

```bash
BASE_NAME=develop   # .claude/wt.md 의 base. 없으면 gh repo view --json defaultBranchRef -q .defaultBranchRef.name
git fetch origin "$BASE_NAME"
BASE=$(git rev-parse "origin/$BASE_NAME"); CAND=$(git rev-parse HEAD)
SEALED=~/.claude/harness-evals/$(basename -s .git "$(git remote get-url origin)")/sealed
if [ -d "$SEALED" ]; then S="--sealed $SEALED"; else S=""; fi
E="${CLAUDE_PLUGIN_ROOT}/evals"
sh "$E/run.sh" --harness "$BASE" --out /tmp/eval-base $S
sh "$E/run.sh" --harness "$CAND" --out /tmp/eval-cand $S
sh "$E/report.sh" /tmp/eval-base /tmp/eval-cand ".claude/harness/reports/$CAND.json"
```

3. 보고서를 커밋하고 push 한 뒤 `gh pr create --base "$BASE_NAME"` 한다. 게이트가 막으면 그 사유를 그대로 보고한다.
4. 첫 줄에 `improved N · regressed N` 을 쓰고 사례별 표를 붙여 보고한다. 머지는 사용자가 한다.

**봉인 묶음의 재사용.** 같은 OBS 에 대한 **두 번째 후보부터**는 봉인 결과를 채택 근거로 쓰지 않는다 — 첫 후보의 봉인 결과를 이미 봤기 때문이다. 그때는 discovery 만으로 비교해 보고하고, 사용자가 새 봉인 묶음(다른 출력의 사례들)을 만들어 `.claude/harness/sealed.manifest` 를 갱신한 뒤에 봉인 비교를 다시 한다. IMP 파일의 `sealed_digest` 에 그 후보가 본 묶음의 digest(보고서의 값)를 적어 둔다.
