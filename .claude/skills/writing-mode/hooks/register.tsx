import { atom, read, update } from 'claude-code'
import type { Engine, Register } from 'claude-code'

import type { Mode, Modes } from '../types'

// The writing-check hook (.claude/hooks/writing-check.py) reads this file.
const FILE = '/.claude/writing-check-mode.json'
const NEXT: Record<Mode, Mode> = { off: 'casual', casual: 'pro', pro: 'off' }
const DEFAULT: Modes = { reply: 'pro', docs: 'pro' }

const modes = atom({ plugin: 'writing-mode', key: 'modes' } as const, DEFAULT)

const CASUAL = (what: string) =>
  `Writing mode for ${what}: casual. The user chose it with the writing-mode buttons. ` +
  `For ${what}, the STE sentence rules of .claude/CLAUDE.md do not apply. ` +
  `Write like an engineer talking to a friend: first person, contractions, plain words, short. ` +
  `Mix short sentences with longer ones. ` +
  `Skip headings and tables unless they help. Still no filler, no corporate words, no em dashes. ` +
  `An emoji or a light joke is fine when it fits, at most one of each per reply. ` +
  `No joke about bad news, health or money, and never at the user's expense.`

const PANE = 'writing-check'
const report = atom({ plugin: 'writing-mode', key: 'report' } as const, '')

// Each line with its look: a table starts at a line that begins with "Rule" and ends at a blank line.
function stripes(text: string): [string, 'head' | 'odd' | 'even' | 'plain'][] {
  let row = -1
  return text.split('\n').map(line => {
    if (line.startsWith('Rule ') || line.startsWith('STE word ')) {
      row = 0
      return [line, 'head']
    }
    if (row < 0 || !line.trim()) {
      row = -1
      return [line, 'plain']
    }
    row += 1
    return [line, row % 2 ? 'odd' : 'even']
  })
}

async function path($: Engine) {
  return `${await $.env.get('HOME')}${FILE}`
}

// The modes of the file, read again at each event: one file per machine. A bad value is pro.
async function load($: Engine): Promise<Modes> {
  const saved: any = await $.fs.read(await path($)).then(t => JSON.parse(t)).catch(() => null)
  const get = (k: keyof Modes): Mode => (saved && typeof saved === 'object' && typeof saved[k] === 'string' && Object.hasOwn(NEXT, saved[k]) ? saved[k] : 'pro')
  return { reply: get('reply'), docs: get('docs') }
}

// `writing-check.py report` of the checkout this session runs in, into the pane.
async function refresh($: Engine) {
  await update($, report, () => 'Loading...')
  const root = await $.process.run(['git', 'rev-parse', '--show-toplevel'])
  const script = `${root.stdout.trim()}/.claude/hooks/writing-check.py`
  const r = root.exitCode === 0
    ? await $.process.run(['python3', '-I', script, 'report', await $.session.id()])
    : { exitCode: 1, stdout: '', stderr: 'Not in a git checkout: no writing-check.py to run.' }
  await update($, report, () => (r.exitCode === 0 ? r.stdout : r.stderr || `exit ${r.exitCode}`))
}

// The pane buttons at the right of the band, one logic for each: a press runs the
// `/<command> toggle` of the mod that owns the pane, which opens it or closes it.
// The domains pane belongs to the folder-pane mod, the report pane to this one.
const PANE_BUTTONS = [
  { key: 'domains', label: '⧉ domain', command: 'domains' },
  { key: 'config', label: '⚙ config', command: 'writing-check' },
] as const

// A call of this mod's own command skips this mod's hooks, so `/writing-check toggle`
// runs as the call it would make: the same toggle either way.
async function togglePane($: Engine, command: string) {
  if (command === 'writing-check') return toggle($)
  await $.command.run({ command, args: 'toggle' })
}

// The config button: a press on an open pane closes it. /writing-check only opens.
async function toggle($: Engine) {
  if ((await $.ui.panes()).some(p => p.id === PANE)) return $.ui.close({ id: PANE })
  await show($)
}

async function show($: Engine) {
  await $.ui.open({ id: PANE, title: 'Writing check' })
  await refresh($)
}

export const register: Register = on => {
  // One pane at a time: when another pane opens, this mod closes its own.
  on('ui.open', async ($, e, next) => {
    if (e.id !== PANE) await $.ui.close({ id: PANE })
    return next(e)
  })

  on('session.start', async ($, e, next) => {
    await $.command.register({ name: 'writing-check', description: 'Show the writing-check rules, thresholds, speed and log' })
    return next(e)
  })

  // `/writing-check` opens the pane. `/writing-check toggle`, from the config button, also closes it.
  on('command.run', { command: 'writing-check' }, async ($, e) => {
    if (e.args.trim() === 'toggle') {
      await toggle($)
      return {}
    }
    await show($)
    return { text: 'Writing check pane opened.' }
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Button, Text } = $.ui.resolve(e)
    const text = await read($, report)
    // A tab starts the "Passes when" text of a rule row. Pointing at the row shows it in
    // one line under the table: a card over the rows would be hidden by the next row.
    const lines = stripes(text).map(([full, kind]) => {
      const [line, note] = full.split('\t')
      return [line, kind, note] as const
    })
    const last = lines.findLastIndex(([, kind, note]) => note !== undefined && kind !== 'head')
    return (
      <Box flexDirection="column">
        <Box>
          <Button key="refresh" label="Refresh" plain dimColor onPress={() => refresh($)} />
        </Box>
        {lines.map(([line, kind, note], i) => {
          const row = (
            <Text weight={kind === 'head' ? 'bold' : undefined} inverse={kind === 'odd'}>
              {kind === 'odd' ? line.padEnd(e.props.bodyColumns ?? 80) : line || ' '}
            </Text>
          )
          const keyed = note === undefined || kind === 'head' ? row : (
            <Box key={`row-${i}`} hover={{ scope: `note-${i}` }}>{row}</Box>
          )
          return i !== last ? keyed : (
            <Box flexDirection="column">
              {keyed}
              <Box>
                <Text dimColor>Passes when (point at a rule): </Text>
                {lines.map(([, kind, note], j) => note === undefined || kind === 'head' ? null : (
                  <Box display="none" hover={{ scope: `note-${j}`, display: 'flex' }}><Text>{note}</Text></Box>
                ))}
              </Box>
            </Box>
          )
        })}
      </Box>
    )
  })

  on('prompt.compose', async ($, e, next) => {
    const result = await next(e)
    const m = await load($)
    const extra = [
      m.reply === 'casual' && { id: 'writing-mode:reply', text: CASUAL('replies'), scope: 'session' as const },
      m.docs === 'casual' && { id: 'writing-mode:docs', text: CASUAL('docs you write'), scope: 'session' as const },
    ].filter(x => x !== false)
    return { sections: [...result.sections, ...extra] }
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const below = await next(e)
    if (e.props.hasSurvey) {
      return below
    }
    // Read the atom so a press redraws the band, but draw from the file. A draw writes nothing.
    await read($, modes)
    const m = await load($)
    const { Box, Button, Text } = $.ui.resolve(e)
    const cycle = (k: keyof Modes) => async () => {
      const cur = await load($)
      const now = { ...cur, [k]: NEXT[cur[k]] }
      await $.fs.write(await path($), JSON.stringify(now) + '\n')
      await update($, modes, () => now)
    }
    const row = (
      <Box width={e.props.bodyColumns} justifyContent="space-between">
        <Box>
          <Text dimColor>Writing </Text>
          <Button key="reply" label={`reply: ${m.reply}`} onPress={cycle('reply')} />
          <Text> </Text>
          <Button key="docs" label={`docs: ${m.docs}`} onPress={cycle('docs')} />
        </Box>
        <Box>
          {PANE_BUTTONS.map((b, i) => (
            <Box key={`${b.key}-slot`}>
              {i ? <Text>  </Text> : null}
              <Button key={b.key} label={b.label} plain dimColor
                onPress={() => togglePane($, b.command)} />
            </Box>
          ))}
        </Box>
      </Box>
    )
    return typeof below === 'object' && below
      ? <Box flexDirection="column">{row}{below}</Box>
      : row
  })
}
