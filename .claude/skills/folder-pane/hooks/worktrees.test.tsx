import { expect, test } from 'claude-code/testing'

import { paneRepos, parseWorktrees, reposOf } from './worktrees'

// The design: plans/global/components/multi-folder/components/folder-pane/, F17 to F19.

const MAP = JSON.stringify([{ name: 'trade', folders: [{ folder: '/p/trade', role: 'KB' }, { folder: '/tmp/x', role: 'code' }] }, { name: 'food', folders: [{ folder: '/p/food', role: 'KB' }] }])

const PANE = {
  plugin: 'folder-pane', component: 'Pane', requestId: 'worktree-pane', surface: 'terminal',
  props: { title: 'Worktrees', isFocused: false, bodyColumns: 80, placement: 'dock', scroll: { offset: 0, bodyRows: 40 }, view: {} },
} as const

const H = 'worktree /h\nHEAD 1\nbranch refs/heads/main\n\nworktree /h/.claude/worktrees/fix\nHEAD 2\nbranch refs/heads/worktree-fix\n\nworktree /h/.claude/worktrees/old\nHEAD 3\ndetached\n'
const P = 'worktree /p\nHEAD 4\nbranch refs/heads/main\n'

function engine(on: any, dirs: string) {
  const opened: string[][] = []
  const open = new Set<string>()
  on('ui.render', { component: 'AbovePrompt' }, ($: any, e: any) => {
    const { Box } = $.ui.resolve(e)
    return <Box key="engine" />
  })
  on('env.get', () => ({ value: '/home/user' }))
  on('fs.read', (_: unknown, e: { path: string }) => {
    if (e.path !== '/home/user/.claude/multi-folder/sess-1/dirs') throw new Error('ENOENT')
    return { value: dirs }
  })
  on('session.start', (_: unknown, e: { cwd: string }) => ({ cwd: e.cwd }))
  on('session.cwd', () => ({ value: '/h/.claude/worktrees/fix' }))
  on('session.id', () => ({ value: 'sess-1' }))
  on('command.register', () => ({ value: { command: 'worktrees' } }))
  on('ui.log', () => ({ value: undefined }))
  on('ui.panes', () => ({ value: [...open].map(id => ({ id, title: 'Worktrees' })) }))
  on('ui.close', (_: unknown, e: { id: string }) => { open.delete(e.id); return { value: undefined } })
  on('ui.open', (_: unknown, e: { id: string }) => { open.add(e.id); return { value: { isPlaced: true } } })
  on('process.run', (_: unknown, e: { argv: string[] }) => {
    if (e.argv[0] === 'open') { opened.push(e.argv); return { value: { exitCode: 0, stdout: '', stderr: '' } } }
    if (e.argv[0] === 'python3') return { value: { exitCode: 0, stdout: MAP, stderr: '' } }
    if (e.argv[1] === 'rev-parse') return { value: { exitCode: 0, stdout: '/h\n', stderr: '' } }
    const dir = e.argv[2]
    const out = dir!.startsWith('/h') ? H : dir!.startsWith('/p') ? P : null
    return { value: out === null ? { exitCode: 128, stdout: '', stderr: 'not a git repository' } : { exitCode: 0, stdout: out, stderr: '' } }
  })
  return { opened, open }
}

test('parseWorktrees: the main checkout first, each branch, a detached one', () => {
  expect(parseWorktrees(H)).toEqual([
    { path: '/h', branch: 'main' },
    { path: '/h/.claude/worktrees/fix', branch: 'worktree-fix' },
    { path: '/h/.claude/worktrees/old', branch: 'detached' },
  ])
})

test('reposOf: one repo per main checkout, and a folder out of git', () => {
  const repos = reposOf([['/h/.claude/worktrees/fix', H], ['/p/trade', P], ['/p/food', P], ['/tmp/x', null]])
  expect(repos.map(r => [r.main, r.worktrees.length])).toEqual([['/h', 2], ['/p', 0], ['', 0]])
})

test('paneRepos: only the repos of the domain folders, and the worktree of this session alone', () => {
  const { repos, session } = paneRepos([['/p/trade', P], ['/tmp/x', null]], ['/h/.claude/worktrees/fix', H])
  expect(repos.map(r => r.main || r.folder)).toEqual(['/p', '/tmp/x'])
  expect(session).toEqual({ path: '/h/.claude/worktrees/fix', branch: 'worktree-fix', main: false })
  expect(paneRepos([], ['/h', H]).session).toEqual({ path: '/h', branch: 'main', main: true })
})

test('pane: /worktrees toggle opens it, the selected domain and this session only, a click opens the worktree in VS Code', async ($, on) => {
  const { opened, open } = engine(on, '/p/trade\n/tmp/x\n')
  await $.session.start({ cwd: '/h/.claude/worktrees/fix', surface: 'terminal', isInteractive: true })
  await $.command.run({ command: 'worktrees', args: 'toggle' } as never)
  expect([...open]).toEqual(['worktree-pane'])
  const pane = await $.ui.mount(PANE)
  expect(await pane.find({ type: 'Text', text: 'Domain: trade' })).toBeDefined()
  expect((await pane.find({ type: 'Text', text: '/p' }))?.props.color).toBe('#D2B48C')
  expect(await pane.find({ type: 'Text', text: '  main checkout, main' })).toBeDefined()
  expect(await pane.find({ type: 'Text', text: '  no worktree' })).toBeDefined()
  expect(await pane.find({ type: 'Text', text: '  not a git folder' })).toBeDefined()
  // the start folder's other worktrees and its main checkout are gone: only this session's worktree
  expect(await pane.find({ type: 'Text', text: '/h' })).toBeUndefined()
  expect(await pane.find({ key: 'open-/h/.claude/worktrees/old' })).toBeUndefined()
  expect(await pane.find({ type: 'Text', text: 'This session' })).toBeDefined()
  expect((await pane.find({ key: 'open-/h/.claude/worktrees/fix' }))?.text).toBe('fix')
  await pane.press({ key: 'open-/h/.claude/worktrees/fix' })
  expect(opened).toEqual([['open', '-a', 'Visual Studio Code', '/h/.claude/worktrees/fix']])
  await $.command.run({ command: 'worktrees', args: 'toggle' } as never)
  expect(open.size).toBe(0)
  await pane.unmount()
})

test('pane: with no domain selected it says so, and still shows this session', async ($, on) => {
  engine(on, '/p/food2\n')
  await $.session.start({ cwd: '/h/.claude/worktrees/fix', surface: 'terminal', isInteractive: true })
  await $.command.run({ command: 'worktrees', args: '' } as never)
  const pane = await $.ui.mount(PANE)
  expect(await pane.find({ type: 'Text', text: 'No domain selected.' })).toBeDefined()
  expect(await pane.find({ type: 'Text', text: '/p' })).toBeUndefined()
  expect((await pane.find({ key: 'open-/h/.claude/worktrees/fix' }))?.text).toBe('fix')
  await pane.unmount()
})
