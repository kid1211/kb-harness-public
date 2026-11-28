export type Doc = { folder: string; role: string; project: string }
export type Ctx = { folder: string; project: string | null; role: string | null; docs: Doc[] }
export type Domain = { name: string; folders: { folder: string; role: string }[]; prompt?: string }
export type Data = { start: string; home: string; folders: Ctx[]; domains: Domain[]; instructions: [string, string][]; error: string }

declare module 'claude-code' {
  interface PluginState {
    'folder-pane': { data: Data; showInstructions: boolean }
  }
}
