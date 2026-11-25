import { expect, test } from 'claude-code/testing'

import { instructionFolders, lastParts, pickText, selectedOf } from './register'

// The design: plans/global/components/multi-folder/components/folder-pane/, its model folder-pane.qnt.

const BAND = {
  plugin: 'folder-pane',
  component: 'AbovePrompt',
  surface: 'terminal',
  props: { hasSurvey: false, isCollapsed: false, isWorking: false, maxRows: 10, bodyColumns: 80, scroll: { offset: 0, bodyRows: 10 }, view: {} },
} as const
const PANE = {
  plugin: 'folder-pane', component: 'Pane', requestId: 'folder-pane', surface: 'terminal',
  props: { title: 'Domains', isFocused: false, bodyColumns: 80, placement: 'dock', scroll: { offset: 0, bodyRows: 40 }, view: {} },
} as const

const STATE = '/home/user/.claude/multi-folder/sess-1'
// The test map of the model: domainsOf.
const DOMAINS = [
  { name: 'mf-web', folders: [{ folder: '/t/web', role: 'frontend' }] },
  { name: 'mf-api', folders: [{ folder: '/t/api', role: 'backend' }] },
  { name: 'mf-both', folders: [{ folder: '/t/web', role: 'frontend' }, { folder: '/t/api', role: 'backend' }] },
  { name: 'trade', folders: [{ folder: '/p/trade', role: 'KB' }] },
]
const CTX: Record<string, unknown> = {
  '/h': { folder: '/h', project: 'harness', role: 'tooling', docs: [] },
  '/t/web': { folder: '/t/web', project: 'mf-web', role: 'frontend', docs: [] },
  '/t/api': { folder: '/t/api', project: 'mf-api', role: 'backend', docs: [] },
  '/p/trade': { folder: '/p/trade', project: 'trade', role: 'KB', docs: [] },
  '/tmp/notes': { folder: '/tmp/notes', project: null, role: null, docs: [] },
}

function engine(on: any, files: Record<string, string>) {
  const open = new Set<string>()
  const runs: string[][] = []
  const logs: string[] = []
  const added: string[] = []
  const copied: string[] = []
  on('ui.render', { component: 'AbovePrompt' }, ($: any, e: any) => {
    const { Box } = $.ui.resolve(e)
    return <Box key="engine" />
  })
  on('env.get', () => ({ value: '/home/user' }))
  on('fs.read', (_: unknown, e: { path: string }) => {
    if (!(e.path in files)) throw new Error('ENOENT')
    return { value: files[e.path] }
  })
  on('session.start', (_: unknown, e: { cwd: string }) => ({ cwd: e.cwd }))
  on('session.cwd', () => ({ value: '/h' }))
  on('session.id', () => ({ value: 'sess-1' }))
  on('command.register', () => ({ value: { command: 'domains' } }))
  on('command.run', { command: 'add-dir' }, (_: unknown, e: { args: string }) => { added.push(e.args); return {} })
  on('ui.copy', (_: unknown, e: { text: string }) => { copied.push(e.text); return { value: { isCopied: true } } })
  on('ui.log', (_: unknown, e: { text: string }) => { logs.push(e.text); return { value: undefined } })
  on('ui.panes', () => ({ value: [...open].map(id => ({ id, title: 'Domains' })) }))
  on('ui.close', (_: unknown, e: { id: string }) => { open.delete(e.id); return { value: undefined } })
  on('ui.open', (_: unknown, e: { id: string }) => { open.add(e.id); return { value: { isPlaced: true } } })
  on('process.run', (_: unknown, e: { argv: string[] }) => {
    runs.push(e.argv)
    if (e.argv[0] === 'git') return { value: { exitCode: 0, stdout: '/h\n', stderr: '' } }
    if (e.argv.includes('domains')) return { value: { exitCode: 0, stdout: JSON.stringify(DOMAINS), stderr: '' } }
    const dirs = e.argv.slice(e.argv.indexOf('--json') + 1)
    return { value: { exitCode: 0, stdout: JSON.stringify(dirs.map(d => CTX[d])), stderr: '' } }
  })
  return { open, runs, logs, added, copied }
}

const files = (dirs: string[]) => ({
  [`${STATE}/dirs`]: dirs.join('\n') + '\n',
  [`${STATE}/instructions`]: '/h/CLAUDE.md\tsession_start\n/t/web/src/CLAUDE.md\thook\n',
})
const text = async (pane: any) => JSON.stringify(await pane.drawn())
async function opened($: any, on: any, dirs: string[]) {
  const e = engine(on, files(dirs))
  await $.session.start({ cwd: '/h', surface: 'terminal', isInteractive: true })
  await $.command.run({ command: 'domains', args: '' } as never)
  return { ...e, pane: await $.ui.mount(PANE) }
}

test('closed: the mod draws no row of its own; the button is in the writing-mode row', async ($, on) => {
  engine(on, {})
  await $.session.start({ cwd: '/h', surface: 'terminal', isInteractive: true })
  const band = await $.ui.mount(BAND)
  expect(await band.find({ key: 'domains' })).toBeUndefined()
  await band.unmount()
})

test('closeTest: /domains opens the pane, and the open reads the data and the map', async ($, on) => {
  const { open, runs } = engine(on, files([]))
  await $.session.start({ cwd: '/h', surface: 'terminal', isInteractive: true })
  await $.command.run({ command: 'domains', args: '' } as never)
  expect([...open]).toEqual(['folder-pane'])
  expect(runs.some(a => a.includes('--json'))).toBe(true)
  expect(runs.some(a => a.join(' ') === 'python3 -I /h/scripts/project-map.py domains')).toBe(true)
})

test('toggle: /domains toggle opens the pane, and again closes it, as config does', async ($, on) => {
  const { open } = engine(on, files([]))
  await $.session.start({ cwd: '/h', surface: 'terminal', isInteractive: true })
  await $.command.run({ command: 'domains', args: 'toggle' } as never)
  expect([...open]).toEqual(['folder-pane'])
  await $.command.run({ command: 'domains', args: 'toggle' } as never)
  expect(open.size).toBe(0)
})

test('drawTest: web and api added, Selected names mf-both and lists each folder with its role', async ($, on) => {
  const { pane } = await opened($, on, ['/t/web', '/t/api'])
  const all = await text(pane)
  const selHead = await pane.find({ type: 'Text', text: 'Active domain' })
  expect(selHead?.props.color).toBe('#D2B48C')
  expect(selHead?.props.weight).toBe('bold')
  // selectedLargest: mf-both, not mf-web or mf-api
  // F15: the domain name in light blue, with no indent
  expect((await pane.find({ type: 'Text', text: 'mf-both' }))?.props.color).toBe('#A8D8EA')
  expect(await pane.find({ type: 'Text', text: 'mf-web' })).toBeUndefined()
  // F16: the last three folder names, no indent
  expect(await pane.find({ type: 'Text', text: ' frontend   t/web' })).toBeDefined()
  expect(await pane.find({ type: 'Text', text: ' backend   t/api' })).toBeDefined()
  // the role tag in the colour of its role, as the status line had it
  expect((await pane.find({ type: 'Text', text: ' frontend   t/web' }) as any)?.children[0].props.backgroundColor).toBe('#A8D8EA')
  // F8: each added folder is a link; the start folder is not listed
  expect(all.includes('file:///t/web')).toBe(true)
  expect(all.includes('file:///h"')).toBe(false)
  // F13: the Select heading and each domain, numbered, as a button
  expect((await pane.find({ type: 'Text', text: 'Pick one from this list' }))?.props.color).toBe('#D2B48C')
  expect((await pane.find({ key: 'pick-mf-web' }))?.text).toBe('1. mf-web')
  expect((await pane.find({ key: 'pick-trade' }))?.text).toBe('4. trade')
  // F9: the instructions part and its warning are hidden by default
  expect(await pane.find({ key: 'instructions' })).toBeDefined()
  expect(all.includes('Claude Code 2.1.329')).toBe(false)
  await pane.unmount()
})

test('drawTest: a folder on no row shows `no row`, and with no full domain Selected says to pick one', async ($, on) => {
  const { pane } = await opened($, on, ['/tmp/notes'])
  expect(await pane.find({ type: 'Text', text: 'none' })).toBeDefined()
  expect(await pane.find({ type: 'Text', text: 'no row  tmp/notes' })).toBeDefined()
  await pane.unmount()
})

test('pickTest: no domain active, a click on mf-both runs /add-dir for each of its folders', async ($, on) => {
  const { pane, logs, open, added } = await opened($, on, [])
  await pane.press({ key: 'pick-mf-both' })
  expect(added).toEqual(['/t/web', '/t/api'])
  expect(logs).toEqual([])
  // pickAddsMissing: the pane closes
  expect(open.size).toBe(0)
  await pane.unmount()
})

test('switchTest: mf-web active, a click on trade writes only the new-session command', async ($, on) => {
  const { pane, logs, added, copied } = await opened($, on, ['/t/web'])
  await pane.press({ key: 'pick-trade' })
  expect(added).toEqual([])
  expect(logs).toEqual(['bash ~/second-brain/harness/scripts/project-start.sh trade', 'Copied: paste it.'])
  expect(copied).toEqual(['bash ~/second-brain/harness/scripts/project-start.sh trade'])
  await pane.unmount()
})

test('instructionsTest: the button shows the instructions folders and the warning, last', async ($, on) => {
  const { pane } = await opened($, on, [])
  expect((await pane.find({ key: 'instructions' }))?.text).toBe('show instructions (2)')
  await pane.press({ key: 'instructions' })
  expect(await pane.find({ type: 'Text', text: '/h  (at start)' })).toBeDefined()
  expect(await pane.find({ type: 'Text', text: '/t/web/src  (hook)' })).toBeDefined()
  const lines = await pane.findAll({ type: 'Text' })
  expect(lines[lines.length - 1]?.text).toMatch(/^Claude Code 2\.1\.329 does not load the instructions of a subfolder/)
  expect((await pane.find({ key: 'instructions' }))?.text).toBe('hide instructions')
  await pane.unmount()
})

test('addDir: refresh reads the session files again', async ($, on) => {
  const f: Record<string, string> = { [`${STATE}/dirs`]: '' }
  engine(on, f)
  await $.session.start({ cwd: '/h', surface: 'terminal', isInteractive: true })
  await $.command.run({ command: 'domains', args: '' } as never)
  const pane = await $.ui.mount(PANE)
  expect(await pane.find({ type: 'Text', text: ' frontend   t/web' })).toBeUndefined()
  f[`${STATE}/dirs`] = '/t/web\n'
  await pane.press({ key: 'reload' })
  expect(await pane.find({ type: 'Text', text: ' frontend   t/web' })).toBeDefined()
  await pane.unmount()
})

test('selectedOf: the largest full domains only', () => {
  expect(selectedOf(DOMAINS, ['/t/web', '/t/api'])).toEqual(['mf-both'])
  expect(selectedOf(DOMAINS, ['/t/web'])).toEqual(['mf-web'])
  expect(selectedOf(DOMAINS, ['/t/web', '/p/trade'])).toEqual(['mf-web', 'trade'])
  expect(selectedOf(DOMAINS, [])).toEqual([])
})

test('pickText: every folder added and no other says the domain is already selected', () => {
  expect(pickText(DOMAINS[2]!,['/t/web', '/t/api'])).toBe('mf-both is already selected.')
})

test('pickText: a folder on no row of the map, such as personal, is no active domain', () => {
  expect(pickText(DOMAINS[1]!, ['/k/personal'], DOMAINS)).toBe('/add-dir /t/api')
  expect(pickText(DOMAINS[2]!, ['/t/web', '/t/api', '/k/personal'], DOMAINS)).toBe('mf-both is already selected.')
})

test('lastParts: the last three folder names', () => {
  expect(lastParts('/Users/me/second-brain/test-folders/folder-a/web')).toBe('test-folders/folder-a/web')
  expect(lastParts('/t/web')).toBe('t/web')
})

test('instructionFolders: one line per folder, full path, each way once', () => {
  expect(instructionFolders([
    ['/h/CLAUDE.md', 'session_start'], ['/h/.claude/CLAUDE.md', 'session_start'],
    ['/h/CLAUDE.md', 'compact'], ['/h/CLAUDE.md', 'session_start'], ['/h/plans/g/CLAUDE.md', 'nested_traversal'],
  ])).toEqual([['/h', 'at start, after compact'], ['/h/.claude', 'at start'], ['/h/plans/g', 'nested read']])
})
