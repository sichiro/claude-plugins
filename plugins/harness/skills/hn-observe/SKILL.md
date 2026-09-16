---
name: hn-observe
description: 하네스 원장에서 반복 실패를 뽑아 OBS 파일로 기록한다. "하네스 관찰" · "원장 분석" · "OBS 뽑아줘" 지시에 쓴다. 규칙·스킬을 고치지 않는다
---

`harness-observer` 에이전트를 띄운다. 세션 대화를 넘기지 않는다 — 에이전트는 원장(`.claude/harness/runs/`)과 git log 만 본다.

Agent(subagent_type: "harness:harness-observer", prompt: "원장을 읽어 OBS 를 쓰거나 갱신하라. 마지막 OBS: <ls .claude/harness/observations 의 최신 파일명, 없으면 none>")

끝나면 만들어진·갱신된 OBS 파일을 사용자에게 보고한다. 다음 단계는 `/harness:hn-propose` 다.
