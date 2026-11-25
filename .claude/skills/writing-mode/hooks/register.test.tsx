import { expect, test } from 'claude-code/testing'

// The design: plans/global/components/mod/components/writing-mode/, its model writing-mode.qnt.

const BAND = {
  plugin: 'writing-mode',
  component: 'AbovePrompt',
  surface: 'terminal',
  props: { hasSurvey: false, isWorking: false, maxRows: 10, bodyColumns: 80, scroll: { offset: 0, bodyRows: 10 } },
} as const

const MODE_FILE = '/home/user/.claude/writing-check-mode.json'

// rounds: the tree beneath holds the Rounds row of plan-rounds. Else it is an empty Box:
// the kit skips a stand-in that returns no tree.
function engine(on: any, files: Record<string, string>, rounds = false) {
  const open = new Set<string>()
  on('ui.render', { component: 'AbovePrompt' }, ($: any, e: any) => {
    const { Box, Button } = $.ui.resolve(e)
    return rounds
      ? <Box key="below"><Button key="rounds" label="Rounds" onPress={() => {}} /></Box>
      : <Box key="engine" />
  })
  on('env.get', () => ({ value: '/home/user' }))
  on('fs.read', (_: unknown, e: { path: string }) => {
    if (!(e.path in files)) throw new Error('ENOENT')
    return { value: files[e.path] }
  })
  on('fs.write', (_: unknown, e: { path: string; text: string }) => {
    files[e.path] = e.text
    return { value: undefined }
  })
  on('session.start', (_: unknown, e: { cwd: string }) => ({ cwd: e.cwd }))
  on('command.register', () => ({ value: { command: 'writing-check' } }))
  // The open panes, so a press of config can close one.
  on('ui.panes', () => ({ value: [...open].map(id => ({ id, title: 'Writing check' })) }))
  on('ui.close', (_: unknown, e: { id: string }) => { open.delete(e.id); return { value: undefined } })
  on('ui.open', (_: unknown, e: { id: string }) => { open.add(e.id); return { value: { isPlaced: true } } })
  on('session.id', () => ({ value: 'sess-123' }))
  on('process.run', (_: unknown, e: { argv: string[] }) => ({
    value: e.argv[0] === 'git'
      ? { exitCode: 0, stdout: '/repo\n', stderr: '' }
      : { exitCode: 0, stdout: `ran ${e.argv.join(' ')}\nRule  Pro  Casual\tPasses when\naiTells  100%\tno AI tells\nfiller  100%\n\nend`, stderr: '' },
  }))
  on('prompt.compose', () => ({ sections: [] }))
  return open
}

test('no mode file: both buttons show pro', async ($, on) => {
  engine(on, {})
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  const ui = await $.ui.mount(BAND)
  expect((await ui.find({ key: 'reply' }))?.text).toBe('reply: pro')
  expect((await ui.find({ key: 'docs' }))?.text).toBe('docs: pro')
  await ui.unmount()
})

test('a press cycles pro, off, casual, pro and writes the file', async ($, on) => {
  const files: Record<string, string> = {}
  engine(on, files)
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  const ui = await $.ui.mount(BAND)
  for (const want of ['off', 'casual', 'pro']) {
    await ui.press({ key: 'reply' })
    expect((await ui.find({ key: 'reply' }))?.text).toBe(`reply: ${want}`)
    expect(JSON.parse(files[MODE_FILE]).reply).toBe(want)
  }
  expect(JSON.parse(files[MODE_FILE]).docs).toBe('pro')
  await ui.unmount()
})

test('the config button opens the pane with the report of this checkout', async ($, on) => {
  engine(on, {})
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  const band = await $.ui.mount(BAND)
  expect((await band.find({ key: 'config' }))?.text).toBe('⚙ config')
  await band.press({ key: 'config' })
  const pane = await $.ui.mount({
    plugin: 'writing-mode', component: 'Pane', requestId: 'writing-check', surface: 'terminal',
    props: { title: 'Writing check', isFocused: false, bodyColumns: 80, placement: 'dock', scroll: { offset: 0, bodyRows: 20 }, view: {} },
  })
  expect((await pane.find({ type: 'Text', text: /ran python3 -I \/repo\/.claude\/hooks\/writing-check.py report \S+/ }))).toBeDefined()
  expect((await pane.find({ type: 'Text', text: /Rule/ }))).toBeDefined()
  const drawn = JSON.stringify(await pane.drawn())
  expect(drawn).toContain('"inverse":true')
  expect((await pane.find({ type: 'Text', text: /^aiTells/ }))?.props).toMatchObject({ inverse: true })
  expect((await pane.find({ type: 'Text', text: /^filler/ }))?.props?.inverse).toBeFalsy()
  expect((await pane.find({ type: 'Text', text: /Passes when\t/ }))).toBeUndefined()
  expect((await pane.find({ type: 'Text', text: 'no AI tells' }))).toBeDefined()
  expect(drawn).toContain('"hover":{"scope":"note-2","display":"flex"}')
  expect(drawn).toContain('"hover":{"scope":"note-2"}')
  await pane.unmount()
  await band.unmount()
})

test('casual adds a system prompt section, pro adds none', async ($, on) => {
  engine(on, { [MODE_FILE]: '{"reply": "casual", "docs": "pro"}' })
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  const { sections } = await $.prompt.compose({ model: 'm', promptModel: 'm', surfaces: ['terminal'], tools: [], outputStyle: null, traits: [] })
  expect(sections.map(s => s.id)).toEqual(['writing-mode:reply'])
})

const start = ($: any) => $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
const label = async (ui: any, k: string) => (await ui.find({ key: k }))?.text

test('bad file (modesFromFile): a file that does not parse, a value that is not a mode, or JSON that is no object shows pro', async ($, on) => {
  const files: Record<string, string> = {}
  engine(on, files)
  await start($)
  for (const text of ['{"reply": "off"', '{"reply": "loud", "docs": "casual"}', '[1]', 'null', '{"reply": "toString"}', '{"reply": ["casual"]}']) {
    files[MODE_FILE] = text
    const ui = await $.ui.mount(BAND)
    expect(await label(ui, 'reply')).toBe('reply: pro')
    expect(await label(ui, 'docs')).toBe(text.includes('"docs": "casual"') ? 'docs: casual' : 'docs: pro')
    await ui.unmount()
  }
})

test('other session (modesFromFile): after the file changes on disk, the next draw shows the new modes', async ($, on) => {
  const files: Record<string, string> = { [MODE_FILE]: '{"reply": "pro", "docs": "pro"}' }
  engine(on, files)
  await start($)
  const first = await $.ui.mount(BAND)
  expect(await label(first, 'reply')).toBe('reply: pro')
  await first.unmount()
  files[MODE_FILE] = '{"reply": "off", "docs": "casual"}'
  const next = await $.ui.mount(BAND)
  expect(await label(next, 'reply')).toBe('reply: off')
  expect(await label(next, 'docs')).toBe('docs: casual')
  await next.unmount()
})

test('press reads the file (fileWrittenClean): a press moves on from the file and keeps the other kind as read', async ($, on) => {
  const files: Record<string, string> = { [MODE_FILE]: '{"reply": "casual", "docs": "off"}' }
  engine(on, files)
  await start($)
  const ui = await $.ui.mount(BAND)
  files[MODE_FILE] = '{"reply": "off", "docs": "loud"}'
  await ui.press({ key: 'reply' })
  expect(JSON.parse(files[MODE_FILE])).toEqual({ reply: 'casual', docs: 'pro' })
  expect(await label(ui, 'reply')).toBe('reply: casual')
  await ui.unmount()
})

test('compose reads the file (casualOnly): a file set to casual, then back to pro, adds the section to the second compose only', async ($, on) => {
  const files: Record<string, string> = { [MODE_FILE]: '{"reply": "pro", "docs": "pro"}' }
  engine(on, files)
  await start($)
  const input = { model: 'm', promptModel: 'm', surfaces: ['terminal'], tools: [], outputStyle: null, traits: [] } as const
  expect((await $.prompt.compose(input)).sections).toEqual([])
  files[MODE_FILE] = '{"reply": "pro", "docs": "casual"}'
  expect((await $.prompt.compose(input)).sections.map(s => s.id)).toEqual(['writing-mode:docs'])
  files[MODE_FILE] = '{"reply": "pro", "docs": "pro"}'
  expect((await $.prompt.compose(input)).sections).toEqual([])
})

test('survey (noRowInSurvey): with hasSurvey, the band is the tree beneath alone', async ($, on) => {
  engine(on, {}, true)
  await start($)
  const ui = await $.ui.mount({ ...BAND, props: { ...BAND.props, hasSurvey: true } })
  expect(await label(ui, 'rounds')).toBe('Rounds')
  expect(await ui.find({ key: 'reply' })).toBeFalsy()
  await ui.unmount()
})

test('top row (ownRowFirst): with a Rounds row beneath, the writing-mode row comes first, with config', async ($, on) => {
  engine(on, {}, true)
  await start($)
  const ui = await $.ui.mount(BAND)
  const t = JSON.stringify(await ui.drawn())
  expect(t.indexOf('"reply"')).toBeGreaterThan(-1)
  expect(t.indexOf('"config"')).toBeGreaterThan(-1)
  expect(t.indexOf('"reply"')).toBeLessThan(t.indexOf('"rounds"'))
  expect(t.indexOf('"config"')).toBeLessThan(t.indexOf('"rounds"'))
  await ui.unmount()
})

test('beneath shows (belowKept): the button of a mod beneath is in the band', async ($, on) => {
  engine(on, {}, true)
  await start($)
  const ui = await $.ui.mount(BAND)
  expect(await label(ui, 'rounds')).toBe('Rounds')
  await ui.unmount()
})

test('config toggle: a press of config with the pane open closes it, and the next press opens it', async ($, on) => {
  const open = engine(on, {})
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  const band = await $.ui.mount(BAND)
  await band.press({ key: 'config' })
  expect([...open]).toEqual(['writing-check'])
  await band.press({ key: 'config' })
  expect(open.size).toBe(0)
  await band.press({ key: 'config' })
  expect([...open]).toEqual(['writing-check'])
  await band.unmount()
})

test('domains button: ⧉ domain sits left of config, and each press asks /domains to toggle, as config asks /writing-check', async ($, on) => {
  const open = engine(on, {})
  const asked: string[] = []
  on('command.run', { command: 'domains' }, (_: unknown, e: { args: string }) => { asked.push(e.args); return {} })
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  const band = await $.ui.mount(BAND)
  expect((await band.find({ key: 'domains' }))?.text).toBe('⧉ domain')
  const drawn = JSON.stringify(await band.drawn())
  expect(drawn.indexOf('⧉ domain')).toBeLessThan(drawn.indexOf('⚙ config'))
  await band.press({ key: 'domains' })
  await band.press({ key: 'domains' })
  expect(asked).toEqual(['toggle', 'toggle'])
  expect(open.size).toBe(0)
  await band.unmount()
})

test('/writing-check toggle closes an open pane, and /writing-check alone only opens', async ($, on) => {
  const open = engine(on, {})
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  await $.command.run({ command: 'writing-check', args: 'toggle' } as never)
  expect([...open]).toEqual(['writing-check'])
  await $.command.run({ command: 'writing-check', args: 'toggle' } as never)
  expect(open.size).toBe(0)
  await $.command.run({ command: 'writing-check', args: '' } as never)
  await $.command.run({ command: 'writing-check', args: '' } as never)
  expect([...open]).toEqual(['writing-check'])
})
