import { atom, read, update } from 'claude-code'
import type { Engine, Register } from 'claude-code'

import type { Repo } from '../types'

// The worktrees pane: each folder of the session, the git checkouts of its repo, and a button on
// each worktree that was made from it, which opens that worktree in VS Code to see its diff.
// The design: plans/global/components/multi-folder/components/folder-pane/, F17 to F19.
export const PANE = 'worktree-pane'
const data = atom({ plugin: 'folder-pane', key: 'repos' } as const, [] as Repo[])

const TAN = '#D2B48C'
const BLUE = '#A8D8EA'

// `git worktree list --porcelain`: one block per checkout, the main checkout first.
export function parseWorktrees(text: string): { path: string; branch: string }[] {
  return text.split('\n\n').map(b => b.trim()).filter(Boolean).map(block => {
    const field = (k: string) => block.split('\n').find(l => l.startsWith(`${k} `))?.slice(k.length + 1) ?? ''
    const branch = field('branch').replace(/^refs\/heads\//, '') || (block.includes('\ndetached') ? 'detached' : '')
    return { path: field('worktree'), branch }
  })
}

// One repo per main checkout: two folders of one repo, such as two domains of a KB, list it once.
export function reposOf(lists: [string, string | null][]): Repo[] {
  const repos: Repo[] = []
  for (const [folder, porcelain] of lists) {
    if (porcelain === null) {
      repos.push({ folder, main: '', branch: '', worktrees: [] })
      continue
    }
    const [main, ...linked] = parseWorktrees(porcelain)
    if (!main || repos.some(r => r.main === main.path)) continue
    repos.push({ folder, main: main.path, branch: main.branch, worktrees: linked })
  }
  return repos
}

export async function refresh($: Engine) {
  const home = (await $.env.get('HOME')) ?? ''
  const start = await $.session.cwd()
  const text = await $.fs.read(`${home}/.claude/multi-folder/${await $.session.id()}/dirs`).catch(() => '')
  const folders = [start, ...text.split('\n').map(l => l.trim()).filter(l => l && l !== start)]
  const lists = await Promise.all(folders.map(async f => {
    const r = await $.process.run(['git', '-C', f, 'worktree', 'list', '--porcelain'])
    return [f, r.exitCode === 0 ? r.stdout : null] as [string, string | null]
  }))
  await update($, data, () => reposOf(lists))
}

// The whole folder in a VS Code window: its Source Control view shows the diff.
async function openInCode($: Engine, path: string) {
  const r = await $.process.run(['open', '-a', 'Visual Studio Code', path])
  if (r.exitCode !== 0) $.ui.log(`Could not open ${path} in VS Code: ${r.stderr.trim()}`)
}

async function toggle($: Engine) {
  if ((await $.ui.panes()).some((p: { id: string }) => p.id === PANE)) return $.ui.close({ id: PANE })
  await $.ui.open({ id: PANE, title: 'Worktrees' })
}

// register.tsx holds the ui.open and session.start hooks of both panes: one of each per mod.
export const register: Register = on => {
  // `/worktrees` opens the pane. `/worktrees toggle`, from the worktrees button of writing-mode, also closes it.
  on('command.run', { command: 'worktrees' }, async ($, e) => {
    if (e.args.trim() === 'toggle') {
      await toggle($)
      return {}
    }
    await $.ui.open({ id: PANE, title: 'Worktrees' })
    return { text: 'Worktrees pane opened.' }
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Button, Text } = $.ui.resolve(e)
    const repos = await read($, data)
    const start = await $.session.cwd()
    const here = (p: string) => (p === start ? '  (this session)' : '')
    return (
      <Box flexDirection="column">
        <Box>
          <Button key="reload" label="reload worktrees" plain dimColor onPress={() => refresh($)} />
        </Box>
        {repos.map(r => (
          <Box flexDirection="column" key={`repo-${r.folder}`}>
            <Text weight="bold" color={TAN}>{r.main || r.folder}</Text>
            {r.main
              ? <Text dimColor>{`  main checkout, ${r.branch || 'no branch'}${here(r.main)}`}</Text>
              : <Text dimColor>  not a git folder</Text>}
            {r.worktrees.map(w => (
              <Box key={`wt-${w.path}`}>
                <Text>  </Text>
                <Button key={`open-${w.path}`} label={w.path.split('/').pop() ?? w.path} plain color={BLUE}
                  onPress={() => openInCode($, w.path)} />
                <Text dimColor>{`  ${w.branch}${here(w.path)}`}</Text>
              </Box>
            ))}
            {r.main && !r.worktrees.length ? <Text dimColor>  no worktree</Text> : null}
          </Box>
        ))}
      </Box>
    )
  })
}
