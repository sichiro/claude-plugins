---
name: hn
description: 이 저장소의 하네스 상태(사례·원장·관찰·제안·보고서)를 진단하고 다음 할 일과 쓸 스킬을 안내한다. "하네스 상태" · "hn" · "하네스 다음에 뭐 하지" 지시에 쓴다. 파일을 만들지도 고치지도 않는다
---

저장소 루트에서 아래를 실행해 상태를 읽는다.

```bash
for p in .claude/harness/cases .claude/harness/runs .claude/harness/observations .claude/harness/proposals .claude/harness/reports; do
  if [ -d "$p" ]; then printf '%s\t%s\n' "$p" "$(ls "$p" | wc -l | tr -d ' ')"; else printf '%s\t없음\n' "$p"; fi
done
[ -f .claude/harness/sealed.manifest ] && printf 'sealed.manifest\t%s\n' "$(wc -l < .claude/harness/sealed.manifest | tr -d ' ')" || printf 'sealed.manifest\t없음\n'
grep -q '^\.claude/harness/runs/' .gitignore 2>/dev/null && printf 'gitignore\tok\n' || printf 'gitignore\t.claude/harness/runs/ 없음\n'
grep -o 'base 는 `[^`]*`' .claude/wt.md 2>/dev/null || printf 'wt.md\tbase 없음 — gh 기본 브랜치를 쓴다\n'
for o in $(find .claude/harness/observations -name '*.yaml' 2>/dev/null); do id=$(basename "$o" .yaml)
  grep -rqs "^source: $id" .claude/harness/proposals || printf 'OBS 미제안\t%s\n' "$id"; done
for b in $(git branch --list 'harness/*' --format='%(refname:short)'); do
  printf 'branch\t%s\t보고서 %s\n' "$b" "$(git ls-tree --name-only "$b" .claude/harness/reports/ 2>/dev/null | grep -c '\.json$')"; done
```

위에서 아래로 **처음 맞는 줄**이 다음 할 일이다. 하나만 안내한다.

| 상태 | 다음 할 일 | 스킬 |
|---|---|---|
| `cases` 없음 | 저장소 준비. `.claude/harness/cases/<사례>/` 에 `prompt.md` · `expect.json` · `fixture/` · `dry-run.result.json` 을 두고, 검증 명령을 make target 으로 노출한다. 이 디렉터리가 생기기 전에는 게이트도 원장 수집도 꺼져 있다 | 없음 — 사용자가 만든다. 절차는 README 「저장소 준비」 |
| `gitignore` 에 `runs/` 없음 | `.gitignore` 에 `.claude/harness/runs/` 를 더한다. 원장은 장비 로컬이다 | 없음 |
| `runs` 없음·비었음 | 세션을 실행해 원장을 쌓는다. 훅이 기록한다 | 없음 |
| `branch` 줄의 보고서가 1 이상 | 그 브랜치의 PR 상태를 본다 — `gh pr list --head <브랜치>`. 머지는 사용자가 한다 | 없음 |
| `OBS 미제안` 줄이 있음 | 그 OBS 로 변경 하나를 브랜치와 IMP 로 만들고 기준선과 비교한다 | `/harness:hn-propose <OBS id>` |
| `observations` 없음·비었음 | 원장에서 반복 실패를 뽑는다 | `/harness:hn-observe` |
| 위 전부 해당 없음 | 세션을 더 실행해 원장을 쌓거나, 없어도 되는지 궁금한 규칙 하나를 잰다 | `/harness:hn-ablate <파일>` |

첫 줄에 `cases N · runs N · OBS N · IMP N · reports N` 을 쓰고, 그 아래 다음 할 일 하나와 쓸 스킬을 보고한다. 수치(세션 · 교정 · 도구 실패 · 규칙 로드)가 필요하면 `${CLAUDE_PLUGIN_ROOT}/scripts/metrics.sh` 를 안내한다.
