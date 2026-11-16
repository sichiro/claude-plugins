import { expect, test } from 'claude-code/testing'

import { apply } from './register'

const WRITE = 'mcp__plugin_claude-mem_mcp-search__work_state_write'
const PANE = {
  plugin: 'todo',
  component: 'Pane',
  requestId: 'todo',
  props: {
    title: '할 일',
    isFocused: false,
    bodyColumns: 40,
    placement: 'dock',
    scroll: { offset: 0, bodyRows: 20 },
    view: {},
  },
} as const

test('쓰기를 사람 차례와 Claude 작업으로 갈라 그린다', async ($, on) => {
  on('command.register', () => ({ value: { command: 'todo' } }))
  on('ui.open', () => ({ value: { isPlaced: true } }))
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  on('tool.call', () => ({ result: {} }))

  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  const write = (fields: Record<string, string>) => $.tool.call({ tool: WRITE, list: '이사 준비', fields })
  await write({ task: '짐 싸기', status: 'doing', who: 'user' })
  await write({ task: '주소 변경', status: 'todo', who: 'user' })
  await write({ task: 'pane 확인', status: 'doing' })
  // 상태만 바꾸는 쓰기는 who 를 지킨다
  await write({ task: '짐 싸기', status: 'done' })

  for (const surface of ['terminal', 'desktop'] as const) {
    const ui = await $.ui.mount({ ...PANE, surface })
    expect((await ui.find({ type: 'Text', text: /사람 차례/ }))?.text).toBe('사람 차례 — 남은 1 / 전체 2')
    expect((await ui.find({ type: 'Text', text: /짐 싸기/ }))?.text).toBe('✓ 짐 싸기')
    expect((await ui.find({ type: 'Text', text: /Claude 작업/ }))?.text).toBe('Claude 작업 — 남은 1 / 전체 1')
    expect((await ui.find({ type: 'Text', text: /pane 확인/ }))?.text).toBe('▶ pane 확인')
    await ui.unmount()
  }
})

test('실패한 쓰기는 비추지 않는다', async ($, on) => {
  on('ui.open', () => ({ value: { isPlaced: true } }))
  on('tool.call', () => ({ isError: true, result: 'boom' }))

  await $.tool.call({ tool: WRITE, list: 'x', fields: { task: 'a', status: 'todo' } })
  const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
  expect((await ui.find({ type: 'Text' }))?.text).toBe('할 일이 없다.')
  await ui.unmount()
})

test('/todo — 보이는 중이면 닫고, 없거나 탭 뒤에 있으면 연다', async ($, on) => {
  const calls: string[] = []
  let panes: { isShown: boolean }[] = []
  on('ui.panes', () => ({ value: panes.map(p => ({ id: 'todo', title: '할 일', isFocused: false, isPlaced: true, ...p })) }))
  on('ui.open', () => (calls.push('open'), { value: { isPlaced: true } }))
  on('ui.close', () => (calls.push('close'), { value: undefined }))
  const run = async () => (await $.command.run({ command: 'todo', args: '', origin: { kind: 'composer' }, presentation: { isFullscreen: false, columns: 120 } })).text

  expect(await run()).toBe('할 일 pane 을 열었다.')
  panes = [{ isShown: false }]
  expect(await run()).toBe('할 일 pane 을 열었다.')
  panes = [{ isShown: true }]
  expect(await run()).toBe('할 일 pane 을 닫았다.')
  expect(calls.join(',')).toBe('open,open,close')
})

test('사람 차례 규약을 시스템 프롬프트 끝에 붙인다', async ($, on) => {
  on('prompt.compose', () => ({ sections: [{ id: 'intro', text: 'x', scope: 'shared' }] }))

  // 도구 목록이 비어도 붙는다 — work_state_write 는 지연 도구라 목록에 없을 수 있다
  const ran = await $.prompt.compose({ model: 'm', promptModel: 'm', surfaces: [], tools: [], outputStyle: null, traits: [] })
  const ids = ran.sections.map(s => s.id)
  expect(ids.join(',')).toBe('intro,todo:who')
})

test('apply — 목록 닫힘은 항목을 지우고, 모르는 상태는 앞의 값을 지킨다', async () => {
  const one = apply([], 'a', { task: 't', status: 'doing', who: 'user' })
  expect(apply(one, 'a', { task: 't', status: 'toString' })[0]?.status).toBe('doing')
  expect(apply(one, 'a', { note: 'x' }).length).toBe(1)
  expect(apply(one, 'a', { status: 'done' }).length).toBe(0)
  expect(apply(one, 'b', { status: 'done' }).length).toBe(1)
})
