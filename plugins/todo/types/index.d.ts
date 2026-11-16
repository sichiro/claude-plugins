export type Status = 'todo' | 'doing' | 'done' | 'dropped'
export type Item = { list: string; task: string; status: Status; who: 'user' | 'claude' }
export type Board = Item[]

declare module 'claude-code' {
  interface PluginState {
    todo: { board: Shaped<Board> }
  }
}
