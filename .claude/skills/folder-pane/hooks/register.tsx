import { atom, read, update } from 'claude-code'
import type { Engine, Register } from 'claude-code'

import type { Ctx, Data, Domain } from '../types'

// The design: plans/global/components/multi-folder/components/folder-pane/.
// The status line and the add-dir hook write the added folders to `dirs`, and the
// nested-instructions hook writes each CLAUDE.md of the session to `instructions`.
const PANE = 'folder-pane'
const EMPTY: Data = { start: '', home: '', folders: [], domains: [], instructions: [], error: '' }
const data = atom({ plugin: 'folder-pane', key: 'data' } as const, EMPTY)
// The instructions part, with its warning: hidden until the person shows it.
const showInstructions = atom({ plugin: 'folder-pane', key: 'showInstructions' } as const, false)

// The palette: headings tan, the domain light blue, as on the status line.
const TAN = '#D2B48C'
const BLUE = '#A8D8EA'
// The tag colours of each code role, background and text, from the kitchen sink. KB, tooling and
// a folder on no row get a dim tag. A role off the list gets the error tag.
const NAVY = '#001F3F'
const ROLE: Record<string, [string, string]> = {
  frontend: ['#A8D8EA', NAVY], backend: ['#FD971F', NAVY], mobile: ['#A6E22E', NAVY],
  infra: ['#D2B48C', NAVY], lib: ['#6B7158', '#FAF0E6'],
}
const PLAIN = new Set(['kb', 'tooling', 'no row'])
const ERROR: [string, string] = ['#B22222', '#FFFFFF']

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

// The session files and the map, through the scripts of the checkout the session runs in.
async function refresh($: Engine) {
  const home = (await $.env.get('HOME')) ?? ''
  const state = `${home}/.claude/multi-folder/${await $.session.id()}`
  const start = await $.session.cwd()
  const dirs = (await lines($, `${state}/dirs`)).filter(d => d !== start)
  const instructions = (await lines($, `${state}/instructions`)).map(l => l.split('\t') as [string, string])
  const root = (await $.process.run(['git', 'rev-parse', '--show-toplevel'])).stdout.trim()
  const r = await $.process.run(['python3', '-I', `${root}/scripts/folder-context.py`, '--json', start, ...dirs])
  const m = await $.process.run(['python3', '-I', `${root}/scripts/project-map.py`, 'domains'])
  let folders: Ctx[] = []
  let domains: Domain[] = []
  let error = ''
  try {
    folders = JSON.parse(r.stdout)
  } catch {
    error = r.stderr || `folder-context.py: exit ${r.exitCode}`
  }
  try {
    domains = JSON.parse(m.stdout)
  } catch {
    error = [error, m.stderr || `project-map.py: exit ${m.exitCode}`].filter(Boolean).join('\n')
  }
  await update($, data, () => ({ start, home, folders, domains, instructions, error }))
}

async function show($: Engine) {
  await $.ui.open({ id: PANE, title: 'Domains' })
}

// The same toggle as the config button of writing-mode: a press on an open pane closes it.
async function toggle($: Engine) {
  if ((await $.ui.panes()).some((p: { id: string }) => p.id === PANE)) return $.ui.close({ id: PANE })
  await show($)
}

// F16: a folder as the pane shows it, by its last three folder names. The link keeps the full path.
export function lastParts(path: string): string {
  return path.split('/').filter(Boolean).slice(-3).join('/')
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

const folderSet = (d: Domain) => d.folders.map(f => f.folder)
const within = (a: string[], b: string[]) => a.every(f => b.includes(f))

// F12: each domain whose folders are all added, less one whose folders all sit in another such domain.
export function selectedOf(domains: Domain[], dirs: string[]): string[] {
  const full = domains.filter(d => within(folderSet(d), dirs))
  return full.filter(d => !full.some(o => o !== d && within(folderSet(d), folderSet(o)))).map(d => d.name)
}

// F13, F14: the text of a click, for the chat.
export function pickText(d: Domain, dirs: string[], all: Domain[] = [d]): string {
  const active = selectedOf(all, dirs)
  if (active.includes(d.name)) return `${d.name} is already selected.`
  // Claude Code cannot remove an added folder: with a domain active, a switch is a fresh session.
  if (active.length) return `bash ~/second-brain/harness/scripts/project-start.sh ${d.name}`
  return folderSet(d).filter(f => !dirs.includes(f)).map(f => `/add-dir ${f}`).join('\n')
}

// A click: each line of the text to the chat, one log call per line, then the pane closes.
// The pane closes first. Each /add-dir line runs, as if the user typed it. A line that cannot run,
// and the project-start line, go to the clipboard, ready to paste.
async function pick($: Engine, dom: Domain, dirs: string[], all: Domain[]) {
  await $.ui.close({ id: PANE })
  // Queue every /add-dir at once: a wait for the first lets a prompt the user sends meanwhile
  // run first, and the rest wait behind its turn.
  const lines = pickText(dom, dirs, all).split('\n')
  const ran = await Promise.all(lines.map(line => line.startsWith('/add-dir ')
    ? $.command.run({ command: 'add-dir', args: line.slice('/add-dir '.length) } as never).then(() => true, () => false)
    : false))
  const left = lines.filter((_, i) => !ran[i])
  if (!left.length) return
  for (const line of left) $.ui.log(line)
  if (!left[0]!.endsWith('already selected.')) {
    const { isCopied } = await $.ui.copy({ text: left.join('\n') }).catch(() => ({ isCopied: false }))
    if (isCopied) $.ui.log('Copied: paste it.')
  }
}

export const register: Register = on => {
  // One pane at a time: when another pane opens, this mod closes its own.
  // An open of this pane, by /domains or by the domains button of writing-mode, reads the data.
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
    await $.command.register({ name: 'domains', description: 'Show the selected domain and its folders, and pick a domain' })
    return next(e)
  })

  // `/domains` opens the pane. `/domains toggle`, from the domains button of writing-mode, also closes it.
  on('command.run', { command: 'domains' }, async ($, e) => {
    if (e.args.trim() === 'toggle') {
      await toggle($)
      return {}
    }
    await show($)
    return { text: 'Domains pane opened.' }
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
    const added = d.folders.filter(f => f.folder !== d.start)
    const dirs = added.map(f => f.folder)
    const selected = selectedOf(d.domains, dirs)
    const head = (t: string) => <Text weight="bold" color={TAN}>{t}</Text>
    const note = (t: string) => <Text dimColor>{t}</Text>
    const tagged = (p: string, role: string) => {
      const [bg, fg] = ROLE[role.toLowerCase()] ?? ERROR
      const tag = PLAIN.has(role.toLowerCase())
        ? <Text dimColor>{role}</Text>
        : <Text backgroundColor={bg} color={fg}>{` ${role} `}</Text>
      return <Text>{tag}{'  '}<Link href={`file://${encodeURI(p)}`} label={lastParts(p)} /></Text>
    }
    const path = (p: string, tag: string, full = false) =>
      <Text>{full ? '  ' : ''}<Link href={`file://${encodeURI(p)}`} label={full ? p : lastParts(p)} />{`  (${tag})`}</Text>
    return (
      <Box flexDirection="column">
        <Box>
          <Button key="reload" label="reload folders" plain dimColor onPress={() => refresh($)} />
        </Box>
        {head('Active domain')}
        {selected.length ? selected.map(n => <Text color={BLUE}>{n}</Text>) : note('none')}
        {added.map(f => tagged(f.folder, f.role ?? 'no row'))}
        {head('Pick one from this list')}
        {d.domains.map((dom, i) => (
          <Box>
            <Button key={`pick-${dom.name}`} label={`${i + 1}. ${dom.name}`} plain onPress={() => pick($, dom, dirs, d.domains)} />
          </Box>
        ))}
        {d.error ? note(d.error) : null}
        <Box>
          <Button key="instructions" label={shown ? 'hide instructions' : `show instructions (${d.instructions.length})`}
            plain dimColor onPress={() => update($, showInstructions, v => !v)} />
        </Box>
        {shown ? instructionFolders(d.instructions).map(([p, tag]) => path(p, tag, true)) : null}
        {shown && !d.instructions.length ? note('  none noted yet') : null}
        {/* The warning sits at the bottom of the pane, under the instructions part. */}
        {shown ? <Box flexGrow={1} /> : null}
        {shown ? <Text dimColor>{WARNING}</Text> : null}
      </Box>
    )
  })
}
