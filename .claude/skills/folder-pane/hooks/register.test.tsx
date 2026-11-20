import { expect, test } from 'claude-code/testing'

import { instructionFolders, shortPath } from './register'

// The design: plans/global/components/multi-folder/components/folder-pane/, its model folder-pane.qnt.

const BAND = {
  plugin: 'folder-pane',
  component: 'AbovePrompt',
  surface: 'terminal',
  props: { hasSurvey: false, isCollapsed: false, isWorking: false, maxRows: 10, bodyColumns: 80, scroll: { offset: 0, bodyRows: 10 }, view: {} },
} as const
const PANE = {
  plugin: 'folder-pane', component: 'Pane', requestId: 'folder-pane', surface: 'terminal',
  props: { title: 'Folders', isFocused: false, bodyColumns: 80, placement: 'dock', scroll: { offset: 0, bodyRows: 40 }, view: {} },
} as const

const STATE = '/home/user/.claude/multi-folder/sess-1'
// What folder-context.py --json gives for each folder, as in drawTest of the model.
const CTX: Record<string, unknown> = {
  '/h': { folder: '/h', project: 'harness', role: 'tooling', docs: [{ folder: '/kb/personal', role: 'KB', project: 'personal' }] },
  '/code/web': { folder: '/code/web', project: 'shop', role: 'code', docs: [{ folder: '/kb/shop', role: 'KB', project: 'shopkb' }] },
  '/code/api': { folder: '/code/api', project: 'shop', role: 'code', docs: [{ folder: '/kb/shop', role: 'KB', project: 'shopkb' }] },
  '/kb/personal': { folder: '/kb/personal', project: 'personal', role: 'KB', docs: [] },
  '/tmp/notes': { folder: '/tmp/notes', project: null, role: null, docs: [] },
}

function engine(on: any, files: Record<string, string>) {
  const open = new Set<string>()
  const runs: string[][] = []
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
  on('command.register', () => ({ value: { command: 'folders' } }))
  on('ui.panes', () => ({ value: [...open].map(id => ({ id, title: 'Folders' })) }))
  on('ui.close', (_: unknown, e: { id: string }) => { open.delete(e.id); return { value: undefined } })
  on('ui.open', (_: unknown, e: { id: string }) => { open.add(e.id); return { value: { isPlaced: true } } })
  on('process.run', (_: unknown, e: { argv: string[] }) => {
    runs.push(e.argv)
    if (e.argv[0] === 'git') return { value: { exitCode: 0, stdout: '/h\n', stderr: '' } }
    const dirs = e.argv.slice(e.argv.indexOf('--json') + 1)
    return { value: { exitCode: 0, stdout: JSON.stringify(dirs.map(d => CTX[d])), stderr: '' } }
  })
  return { open, runs }
}

const ALL = {
  [`${STATE}/dirs`]: '/code/web\n/code/api\n/kb/personal\n/tmp/notes\n',
  [`${STATE}/instructions`]: '/h/CLAUDE.md\tsession_start\n/code/web/src/CLAUDE.md\thook\n',
}
const text = async (pane: any) => JSON.stringify(await pane.drawn())

test('closed: the mod draws no row of its own; the button is in the writing-mode row', async ($, on) => {
  engine(on, {})
  await $.session.start({ cwd: '/h', surface: 'terminal', isInteractive: true })
  const band = await $.ui.mount(BAND)
  expect(await band.find({ key: 'folders' })).toBeUndefined()
  await band.unmount()
})

test('closeTest: /folders opens the pane, and the open reads the data', async ($, on) => {
  const { open, runs } = engine(on, ALL)
  await $.session.start({ cwd: '/h', surface: 'terminal', isInteractive: true })
  await $.command.run({ command: 'folders', args: '' } as never)
  expect([...open]).toEqual(['folder-pane'])
  // the open itself reads the data: the folders button of writing-mode opens the pane the same way
  expect(runs.some(a => a.includes('--json'))).toBe(true)
})

test('toggle: /folders toggle opens the pane, and again closes it, as config does', async ($, on) => {
  const { open } = engine(on, ALL)
  await $.session.start({ cwd: '/h', surface: 'terminal', isInteractive: true })
  await $.command.run({ command: 'folders', args: 'toggle' } as never)
  expect([...open]).toEqual(['folder-pane'])
  await $.command.run({ command: 'folders', args: 'toggle' } as never)
  expect(open.size).toBe(0)
})

test('drawTest: the coding folders and the KBs as links, no start folder, instructions hidden', async ($, on) => {
  const { runs } = engine(on, ALL)
  await $.session.start({ cwd: '/h', surface: 'terminal', isInteractive: true })
  await $.command.run({ command: 'folders', args: '' } as never)
  const pane = await $.ui.mount(PANE)
  // the start folder and each added folder go to folder-context.py of this checkout
  expect(runs.some(a => a.join(' ') === 'python3 -I /h/scripts/folder-context.py --json /h /code/web /code/api /kb/personal /tmp/notes')).toBe(true)
  const all = await text(pane)
  // codingOf: the code folders and the folder on no row
  expect(await pane.find({ type: 'Text', text: 'Coding folders' })).toBeDefined()
  expect(await pane.find({ type: 'Text', text: '../code/web  (shop)' })).toBeDefined()
  expect(await pane.find({ type: 'Text', text: '../code/api  (shop)' })).toBeDefined()
  expect(await pane.find({ type: 'Text', text: '../tmp/notes  (not on the map)' })).toBeDefined()
  // noStart: the start folder is in no part
  expect(all.includes('file:///h"')).toBe(false)
  expect(all.includes('harness')).toBe(false)
  // kbsOf, kbsFromMap: one KBs part, the KB of the map not added says so, no docs part
  expect(await pane.find({ type: 'Text', text: 'KBs' })).toBeDefined()
  expect(await pane.find({ type: 'Text', text: '../kb/personal  (personal)' })).toBeDefined()
  expect(await pane.find({ type: 'Text', text: '../kb/shop  (shopkb, not added)' })).toBeDefined()
  expect(all.split('file:///kb/shop').length).toBe(2)
  expect(all.includes('Supporting docs')).toBe(false)
  // F8: each path is a link to file://<path>
  for (const path of ['/code/web', '/code/api', '/tmp/notes', '/kb/personal', '/kb/shop']) {
    expect(all.includes(`file://${path}`)).toBe(true)
  }
  // F9: the instructions part and its warning are hidden by default
  expect(await pane.find({ key: 'instructions' })).toBeDefined()
  expect(all.includes('/h/CLAUDE.md')).toBe(false)
  expect(all.includes('Claude Code 2.1.329')).toBe(false)
  await pane.unmount()
})

test('instructionsTest: the button shows the instructions files as links, and the warning', async ($, on) => {
  engine(on, ALL)
  await $.session.start({ cwd: '/h', surface: 'terminal', isInteractive: true })
  await $.command.run({ command: 'folders', args: '' } as never)
  const pane = await $.ui.mount(PANE)
  expect((await pane.find({ key: 'instructions' }))?.text).toBe('show instructions (2)')
  await pane.press({ key: 'instructions' })
  const all = await text(pane)
  // instructionsListed
  expect(await pane.find({ type: 'Text', text: '/h  (at start)' })).toBeDefined()
  expect(await pane.find({ type: 'Text', text: '/code/web/src  (hook)' })).toBeDefined()
  expect(all.includes('file:///code/web/src')).toBe(true)
  expect(all.includes('CLAUDE.md')).toBe(false)
  // the warning is the last line
  const lines = await pane.findAll({ type: 'Text' })
  expect(lines[lines.length - 1]?.text).toMatch(/^Claude Code 2\.1\.329/)
  // F7: the warning shows with the part
  expect(await pane.find({ type: 'Text', text: /^Claude Code 2\.1\.329 does not load the instructions of a subfolder/ })).toBeDefined()
  expect((await pane.find({ key: 'instructions' }))?.text).toBe('hide instructions')
  await pane.press({ key: 'instructions' })
  expect((await text(pane)).includes('/h/CLAUDE.md')).toBe(false)
  await pane.unmount()
})

test('addTest: refresh reads the session files again', async ($, on) => {
  const files: Record<string, string> = { [`${STATE}/dirs`]: '' }
  engine(on, files)
  await $.session.start({ cwd: '/h', surface: 'terminal', isInteractive: true })
  await $.command.run({ command: 'folders', args: '' } as never)
  const pane = await $.ui.mount(PANE)
  expect(await pane.find({ type: 'Text', text: '../code/web  (shop)' })).toBeUndefined()
  files[`${STATE}/dirs`] = '/code/web\n'
  await pane.press({ key: 'refresh' })
  expect(await pane.find({ type: 'Text', text: '../code/web  (shop)' })).toBeDefined()
  await pane.unmount()
})

test('shortPath: always relative to the start folder', () => {
  const start = '/Users/me/second-brain/harness/.claude/worktrees/x'
  expect(shortPath('/Users/me/second-brain/personal', '/Users/me/second-brain/harness')).toBe('../personal')
  expect(shortPath('/Users/me/second-brain/personal', start)).toBe('../../../../personal')
  expect(shortPath(start, start)).toBe('.')
})

test('instructionFolders: one line per folder, full path, each way once', () => {
  expect(instructionFolders([
    ['/h/CLAUDE.md', 'session_start'], ['/h/.claude/CLAUDE.md', 'session_start'],
    ['/h/CLAUDE.md', 'compact'], ['/h/CLAUDE.md', 'session_start'], ['/h/plans/g/CLAUDE.md', 'nested_traversal'],
  ])).toEqual([['/h', 'at start, after compact'], ['/h/.claude', 'at start'], ['/h/plans/g', 'nested read']])
})
