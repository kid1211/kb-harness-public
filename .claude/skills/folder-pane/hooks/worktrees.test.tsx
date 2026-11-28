import { expect, test } from 'claude-code/testing'

import { parseWorktrees, reposOf } from './worktrees'

// The design: plans/global/components/multi-folder/components/folder-pane/, F17 to F19.

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

test('pane: /worktrees toggle opens it, each folder with its checkouts, a click opens the worktree in VS Code', async ($, on) => {
  const { opened, open } = engine(on, '/p/trade\n/p/food\n/tmp/x\n')
  await $.session.start({ cwd: '/h/.claude/worktrees/fix', surface: 'terminal', isInteractive: true })
  await $.command.run({ command: 'worktrees', args: 'toggle' } as never)
  expect([...open]).toEqual(['worktree-pane'])
  const pane = await $.ui.mount(PANE)
  expect((await pane.find({ type: 'Text', text: '/h' }))?.props.color).toBe('#D2B48C')
  expect(await pane.find({ type: 'Text', text: '  main checkout, main' })).toBeDefined()
  expect((await pane.find({ key: 'open-/h/.claude/worktrees/fix' }))?.text).toBe('fix')
  expect(await pane.find({ type: 'Text', text: '  worktree-fix  (this session)' })).toBeDefined()
  // the main checkout is no button: only a made worktree opens
  expect(await pane.find({ key: 'open-/h' })).toBeUndefined()
  expect(await pane.find({ type: 'Text', text: '  no worktree' })).toBeDefined()
  expect(await pane.find({ type: 'Text', text: '  not a git folder' })).toBeDefined()
  await pane.press({ key: 'open-/h/.claude/worktrees/fix' })
  expect(opened).toEqual([['open', '-a', 'Visual Studio Code', '/h/.claude/worktrees/fix']])
  await $.command.run({ command: 'worktrees', args: 'toggle' } as never)
  expect(open.size).toBe(0)
  await pane.unmount()
})
