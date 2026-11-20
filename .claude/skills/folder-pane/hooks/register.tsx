import { atom, read, update } from 'claude-code'
import type { Engine, Register } from 'claude-code'

import type { Ctx, Data } from '../types'

// The design: plans/global/components/multi-folder/components/folder-pane/.
// The status line and the add-dir hook write the added folders to `dirs`, and the
// nested-instructions hook writes each CLAUDE.md of the session to `instructions`.
const PANE = 'folder-pane'
const EMPTY: Data = { start: '', home: '', folders: [], instructions: [], error: '' }
const data = atom({ plugin: 'folder-pane', key: 'data' } as const, EMPTY)
// The instructions part, with its warning: hidden until the person shows it.
const showInstructions = atom({ plugin: 'folder-pane', key: 'showInstructions' } as const, false)

const WARNING =
  'Claude Code 2.1.329 does not load the instructions of a subfolder in an added folder. ' +
  'The nested-instructions hook gives them. After a Claude Code update, check this again.'
const WHO: Record<string, string> = {
  session_start: 'at start',
  nested_traversal: 'nested read',
  compact: 'after compact',
  hook: 'hook',
}

async function lines($: Engine, path: string): Promise<string[]> {
  const text = await $.fs.read(path).catch(() => '')
  return text.split("\n").filter((l: string) => l.trim())
}

// The session files and the map, through folder-context.py of the checkout the session runs in.
async function refresh($: Engine) {
  const home = (await $.env.get('HOME')) ?? ''
  const state = `${home}/.claude/multi-folder/${await $.session.id()}`
  const start = await $.session.cwd()
  const dirs = (await lines($, `${state}/dirs`)).filter(d => d !== start)
  const instructions = (await lines($, `${state}/instructions`)).map(l => l.split('\t') as [string, string])
  const root = await $.process.run(['git', 'rev-parse', '--show-toplevel'])
  const r = await $.process.run(['python3', '-I', `${root.stdout.trim()}/scripts/folder-context.py`, '--json', start, ...dirs])
  let folders: Ctx[] = []
  let error = ''
  try {
    folders = JSON.parse(r.stdout)
  } catch {
    error = r.stderr || `folder-context.py: exit ${r.exitCode}`
  }
  await update($, data, () => ({ start, home, folders, instructions, error }))
}

async function show($: Engine) {
  await $.ui.open({ id: PANE, title: 'Folders' })
}

// The same toggle as the config button of writing-mode: a press on an open pane closes it.
async function toggle($: Engine) {
  if ((await $.ui.panes()).some((p: { id: string }) => p.id === PANE)) return $.ui.close({ id: PANE })
  await show($)
}

type Row = { kind: 'head' | 'note'; text: string } | { kind: 'path'; path: string; tag: string; full?: true }

// A folder of the two main parts, as the pane shows it: relative to the start folder.
// The link keeps the full path.
export function shortPath(path: string, start: string): string {
  const a = start.split('/').filter(Boolean)
  const b = path.split('/').filter(Boolean)
  let i = 0
  while (i < a.length && i < b.length && a[i] === b[i]) i++
  return [...Array(a.length - i).fill('..'), ...b.slice(i)].join('/') || '.'
}

// The instructions part: one line per folder that holds a loaded instructions file, by its
// full path, with each way it was loaded once.
export function instructionFolders(rows: [string, string][]): [string, string][] {
  const by = new Map<string, string[]>()
  for (const [file, who] of rows) {
    const dir = file.slice(0, file.lastIndexOf('/')) || '/'
    const label = WHO[who] ?? who
    const seen = by.get(dir) ?? []
    if (!seen.includes(label)) seen.push(label)
    by.set(dir, seen)
  }
  return [...by].map(([dir, whos]) => [dir, whos.join(', ')])
}

const isKb = (role: string | null) => (role ?? '').toLowerCase() === 'kb'

// The two main parts, from the data alone: the coding folders, then the KBs. The start folder
// is in neither: the session runs in it. The supporting docs of a project are its KBs.
function layout(d: Data): Row[] {
  const added = d.folders.filter(f => f.folder !== d.start)
  const out: Row[] = [{ kind: 'head', text: 'Coding folders' }]
  const coding = added.filter(f => !isKb(f.role))
  for (const f of coding) out.push({ kind: 'path', path: f.folder, tag: f.project ?? 'not on the map' })
  if (!coding.length) out.push({ kind: 'note', text: '  none added' })
  out.push({ kind: 'head', text: 'KBs' })
  const kbs = new Map<string, string>()
  for (const f of added) if (isKb(f.role)) kbs.set(f.folder, f.project ?? '')
  for (const f of d.folders) {
    for (const doc of f.docs) {
      if (doc.folder !== d.start && !kbs.has(doc.folder)) kbs.set(doc.folder, `${doc.project}, not added`)
    }
  }
  for (const [path, tag] of kbs) out.push({ kind: 'path', path, tag })
  if (!kbs.size) out.push({ kind: 'note', text: '  none on the map' })
  if (d.error) out.push({ kind: 'note', text: d.error })
  return out
}

function instructionRows(d: Data): Row[] {
  const out: Row[] = instructionFolders(d.instructions).map(([path, tag]) => ({ kind: 'path', path, tag, full: true }))
  if (!out.length) out.push({ kind: 'note', text: '  none noted yet' })
  return out
}

export const register: Register = on => {
  // One pane at a time: when another pane opens, this mod closes its own.
  // An open of this pane, by /folders or by the folders button of writing-mode, reads the data.
  on('ui.open', async ($, e, next) => {
    if (e.id !== PANE) {
      await $.ui.close({ id: PANE })
      return next(e)
    }
    const result = await next(e)
    await refresh($)
    return result
  })

  on('session.start', async ($, e, next) => {
    await $.command.register({ name: 'folders', description: 'Show the coding folders and KBs of this session, and the loaded instructions' })
    return next(e)
  })

  // `/folders` opens the pane. `/folders toggle`, from the folders button of writing-mode, also closes it.
  on('command.run', { command: 'folders' }, async ($, e) => {
    if (e.args.trim() === 'toggle') {
      await toggle($)
      return {}
    }
    await show($)
    return { text: 'Folders pane opened.' }
  })

  // A new /add-dir: draw it, when the pane is open.
  on('classic.DirectoryAdded', async ($, e, next) => {
    const result = await next(e)
    if ((await $.ui.panes()).some((p: { id: string }) => p.id === PANE)) await refresh($)
    return result
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Button, Link, Text } = $.ui.resolve(e)
    const d = await read($, data)
    const shown = await read($, showInstructions)
    const draw = (r: Row) =>
      r.kind === 'path'
        ? <Text>{'  '}<Link href={`file://${encodeURI(r.path)}`} label={r.full ? r.path : shortPath(r.path, d.start)} />{`  (${r.tag})`}</Text>
        : <Text weight={r.kind === 'head' ? 'bold' : undefined} dimColor={r.kind === 'note'}>{r.text}</Text>
    return (
      <Box flexDirection="column">
        <Box>
          <Button key="refresh" label="Refresh" plain dimColor onPress={() => refresh($)} />
        </Box>
        {layout(d).map(draw)}
        <Box>
          <Button key="instructions" label={shown ? 'hide instructions' : `show instructions (${d.instructions.length})`}
            plain dimColor onPress={() => update($, showInstructions, v => !v)} />
        </Box>
        {shown ? instructionRows(d).map(draw) : null}
        {/* The warning sits at the bottom of the pane, under the instructions part. */}
        {shown ? <Box flexGrow={1} /> : null}
        {shown ? <Text dimColor>{WARNING}</Text> : null}
      </Box>
    )
  })
}
