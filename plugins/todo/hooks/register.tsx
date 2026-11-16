import { atom, read, update } from 'claude-code'
import type { Register } from 'claude-code'

import type { Board, Item, Status } from '../types'

const PANE = 'todo'
const TITLE = '할 일'
const WRITE = 'mcp__plugin_claude-mem_mcp-search__work_state_write'
const MARK: Record<Status, string> = { todo: '☐', doing: '▶', done: '✓', dropped: '–' }
const SECTIONS = [
  ['user', '사람 차례'],
  ['claude', 'Claude 작업'],
] as const
// 사람 차례를 가르는 칸은 이 모드의 규약이라 도구 설명에 없다 — 모델에게는 여기서 알린다.
const HINT = {
  id: 'todo:who',
  text: '사용자가 직접 실행할 단계를 work_state_write 로 적을 때는 fields 에 who: "user" 를 넣는다. 「할 일」 pane 이 그 항목을 사람 차례로 따로 보인다.',
  scope: 'session',
} as const

const isOpen = (i: Item) => i.status === 'todo' || i.status === 'doing'

// shortcut: 이 세션에서 본 쓰기만 비춘다(이전 세션의 열린 항목은 안 보인다), 필요해지면 session.start 에서 work_state_read 로 채운다
const board = atom({ plugin: 'todo', key: 'board' } as const, [] as Board, { shape: 'board-1' })

// work_state_write 한 건을 목록에 반영한다. task 없는 쓰기는 목록 자체의 상태라 닫힘만 본다.
export const apply = (b: Board, list: string, fields: Record<string, unknown>): Board => {
  const { task, status, who } = fields
  if (typeof task !== 'string') return status === 'done' ? b.filter(i => i.list !== list) : b
  const old = b.find(i => i.list === list && i.task === task)
  const next: Item = {
    list,
    task,
    status: typeof status === 'string' && Object.hasOwn(MARK, status) ? (status as Status) : (old?.status ?? 'todo'),
    who: who === 'user' ? 'user' : who === undefined ? (old?.who ?? 'claude') : 'claude',
  }

  return old ? b.map(i => (i === old ? next : i)) : [...b, next]
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({ name: 'todo', description: '할 일 pane 을 열고 닫는다 — 사람 차례와 Claude 작업' })

    return next(e)
  })

  on('command.run', { command: 'todo' }, async $ => {
    // 보이는 중일 때만 닫는다 — 탭 뒤에 있거나 폭이 좁아 대기 중이면 여는 쪽이 맞다.
    if ((await $.ui.panes()).some(p => p.id === PANE && p.isShown)) {
      await $.ui.close({ id: PANE })

      return { text: '할 일 pane 을 닫았다.' }
    }
    await $.ui.open({ id: PANE, title: TITLE })

    return { text: '할 일 pane 을 열었다.' }
  })

  on('prompt.compose', async (_, e, next) => {
    const ran = await next(e)

    return { sections: [...ran.sections, HINT] }
  })

  on('tool.call', { tool: WRITE }, async ($, e, next) => {
    const ran = await next(e)
    if (ran.deny !== undefined || ran.isError) return ran
    const { list, fields } = e as unknown as { list?: unknown; fields?: unknown }
    if (typeof list !== 'string' || typeof fields !== 'object' || fields === null) return ran
    // 쓰기는 이미 끝났다 — 비추다 실패해도 훅이 실패로 끝나 그 호출을 건드리지 않게 삼킨다.
    try {
      await update($, board, b => apply(b, list, fields as Record<string, unknown>))
      // 기다리지 않고 여는 호출이라 try 가 못 잡는다 — 거부(다른 mod 가 쥐었거나 막았을 때)는 여기서 삼킨다.
      void $.ui.open({ id: PANE, title: TITLE }).catch(() => {})
    } catch {}

    return ran
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Text } = $.ui.resolve(e)
    const items = await read($, board)
    const order = [...new Set(items.map(i => i.list))]
    const rows: { text: string; bold?: boolean; dim?: boolean }[] = []
    for (const [who, title] of SECTIONS) {
      const mine = items.filter(i => i.who === who).sort((a, b) => order.indexOf(a.list) - order.indexOf(b.list))
      if (mine.length === 0) continue
      rows.push({ text: `${title} — 남은 ${mine.filter(isOpen).length} / 전체 ${mine.length}`, bold: true })
      let list: string | undefined
      for (const i of mine) {
        if (i.list !== list) rows.push({ text: (list = i.list), dim: true })
        rows.push({ text: `${MARK[i.status]} ${i.task}`, bold: i.status === 'doing', dim: !isOpen(i) })
      }
    }

    return (
      <Box flexDirection="column">
        {rows.length === 0 && <Text dimColor>할 일이 없다.</Text>}
        {rows.map(r => (
          <Text bold={r.bold} dimColor={r.dim}>
            {r.text}
          </Text>
        ))}
      </Box>
    )
  })
}
