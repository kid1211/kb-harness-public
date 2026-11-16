export type Mode = 'off' | 'casual' | 'pro'
export type Modes = { reply: Mode; docs: Mode }

declare module 'claude-code' {
  interface PluginState {
    'writing-mode': { modes: Modes; report: string }
  }
}
