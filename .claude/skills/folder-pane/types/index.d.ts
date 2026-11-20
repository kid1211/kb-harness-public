export type Doc = { folder: string; role: string; project: string }
export type Ctx = { folder: string; project: string | null; role: string | null; docs: Doc[] }
export type Data = { start: string; home: string; folders: Ctx[]; instructions: [string, string][]; error: string }

declare module 'claude-code' {
  interface PluginState {
    'folder-pane': { data: Data; showInstructions: boolean }
  }
}
