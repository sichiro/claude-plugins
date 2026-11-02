# herdr TUI — `wt-done` 명령

`HERDR_ENV=1` 일 때 읽는다.

## 내 자리 찾기

`herdr pane current` 의 `workspace_id` 가 내 workspace 다. `herdr agent list` 는 다른 사람 작업까지 전부 반환하므로 그 값으로 거른다.

## 다른 에이전트 닫기

**`herdr agent stop` 은 없는 명령이다.** pane 을 닫으면 그 안의 에이전트도 함께 종료된다. 위에서 거른 것만 `herdr pane close <pane>` 한다.

## worktree 제거

```
herdr worktree list --cwd "$PWD"
herdr worktree remove --workspace <ID> --force
```

- 목록에서 **`path` 가 지금 작업 중인 worktree 와 일치하는 행**의 workspace ID 만 쓴다
- `--cwd` 를 빼면 현재 디렉터리가 아니라 **포커스된 workspace** 의 저장소를 반환한다 — 다른 창이 포커스돼 있으면 이 저장소 행이 아예 없다
- `remove` 가 worktree 디렉터리와 workspace 를 함께 지우고, 이 세션도 함께 끝난다
