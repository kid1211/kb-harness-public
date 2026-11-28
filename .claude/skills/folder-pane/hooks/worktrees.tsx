import { atom, read, update } from 'claude-code'
import type { Engine, Register } from 'claude-code'

import type { Domain, Repo } from '../types'

// The worktrees pane: the repos of the selected domain with their checkouts, and the worktree this
// session runs in. A button on each made worktree opens it in VS Code to see its diff.
// The design: plans/global/components/multi-folder/components/folder-pane/, F17 to F19.
export const PANE = 'worktree-pane'
type Session = { path: string; branch: string; main: boolean }
type View = { selected: string[]; repos: Repo[]; session: Session | null }
const data = atom({ plugin: 'folder-pane', key: 'worktrees' } as const, { selected: [], repos: [], session: null } as View)

export const folderSet = (d: Domain) => d.folders.map(f => f.folder)
const within = (a: string[], b: string[]) => a.every(f => b.includes(f))

// F12: each domain whose folders are all added, less one whose folders all sit in another such domain.
export function selectedOf(domains: Domain[], dirs: string[]): string[] {
  const full = domains.filter(d => within(folderSet(d), dirs))
  return full.filter(d => !full.some(o => o !== d && within(folderSet(d), folderSet(o)))).map(d => d.name)
}

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

// F18: the repos of the domain folders, and of the start folder only the checkout this session runs in.
export function paneRepos(domainLists: [string, string | null][], [start, porcelain]: [string, string | null]) {
  const all = porcelain ? parseWorktrees(porcelain) : []
  const i = all.findIndex(w => w.path === start)
  const session = i < 0 ? null : { ...all[i]!, main: i === 0 }
  return { repos: reposOf(domainLists), session }
}

const worktreeList = async ($: Engine, f: string) => {
  const r = await $.process.run(['git', '-C', f, 'worktree', 'list', '--porcelain'])
  return [f, r.exitCode === 0 ? r.stdout : null] as [string, string | null]
}

export async function refresh($: Engine) {
  const home = (await $.env.get('HOME')) ?? ''
  const start = await $.session.cwd()
  const text = await $.fs.read(`${home}/.claude/multi-folder/${await $.session.id()}/dirs`).catch(() => '')
  const dirs = text.split('\n').map(l => l.trim()).filter(l => l && l !== start)
  const root = (await $.process.run(['git', 'rev-parse', '--show-toplevel'])).stdout.trim()
  const m = await $.process.run(['python3', '-I', `${root}/scripts/project-map.py`, 'domains'])
  let domains: Domain[] = []
  try { domains = JSON.parse(m.stdout) } catch { /* no map: no domain is selected */ }
  const selected = selectedOf(domains, dirs)
  const folders = [...new Set(domains.filter(d => selected.includes(d.name)).flatMap(folderSet))]
  const { repos, session } = paneRepos(await Promise.all(folders.map(f => worktreeList($, f))), await worktreeList($, start))
  await update($, data, () => ({ selected, repos, session }))
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
    const { selected, repos, session } = await read($, data)
    const open = (w: { path: string; branch: string }) => (
      <Box key={`wt-${w.path}`}>
        <Text>  </Text>
        <Button key={`open-${w.path}`} label={w.path.split('/').pop() ?? w.path} plain color={BLUE}
          onPress={() => openInCode($, w.path)} />
        <Text dimColor>{`  ${w.branch}`}</Text>
      </Box>
    )
    return (
      <Box flexDirection="column">
        <Box>
          <Button key="reload" label="reload worktrees" plain dimColor onPress={() => refresh($)} />
        </Box>
        {selected.length
          ? <Text weight="bold" color={BLUE}>{`Domain: ${selected.join(', ')}`}</Text>
          : <Text dimColor>No domain selected.</Text>}
        {repos.map(r => (
          <Box flexDirection="column" key={`repo-${r.folder}`}>
            <Text weight="bold" color={TAN}>{r.main || r.folder}</Text>
            {r.main
              ? <Text dimColor>{`  main checkout, ${r.branch || 'no branch'}`}</Text>
              : <Text dimColor>  not a git folder</Text>}
            {r.worktrees.map(open)}
            {r.main && !r.worktrees.length ? <Text dimColor>  no worktree</Text> : null}
          </Box>
        ))}
        <Text weight="bold" color={TAN}>This session</Text>
        {!session ? <Text dimColor>  not a git folder</Text>
          : session.main ? <Text dimColor>{`  main checkout, ${session.branch || 'no branch'}`}</Text>
          : open(session)}
      </Box>
    )
  })
}
