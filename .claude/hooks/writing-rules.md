# Writing rules

The rules every reply, and the prose of every file Claude writes, follows. The
`writing-check` hook (`.claude/hooks/writing-check.py`) reads the four tables below and
scores each text against them and against the sentence rules. Code, tables and
identifiers are exempt. An identifier or a code span counts as one word.

### Words not to use

Each word in the first column is a violation outside code.

| Not | Use instead |
|---|---|
| utilize | use |
| leverage | use |
| in order to | to |
| prior to | before |
| subsequently | then |
| approximately | about |
| commence | start |
| terminate | stop |
| facilitate | help |
| numerous | many |
| additionally | also |
| basically | (delete) |
| simply | (delete) |
| obviously | (delete) |
| robust | (say what it survives) |
| seamless | (say what does not break) |

### Phrases not to use

Filler that says nothing. Each phrase in the first column is a violation outside code.

| Not | Use instead |
|---|---|
| great question | (delete) |
| I'll now | (delete, do it) |
| now I'll | (delete, do it) |
| it's worth noting | (delete) |
| it is worth noting | (delete) |
| in summary | (delete, the reply leads with the result) |
| to summarize | (delete) |
| as mentioned | (delete) |
| I hope this helps | (delete) |
| feel free to | (delete) |
| happy to help | (delete) |
| let me explain | (delete) |
| it should be noted that | (delete) |
| needless to say | (delete) |
| as a matter of fact | (delete) |
| for all intents and purposes | (delete) |
| at the end of the day | (delete) |
| at this point in time | now |
| at the present time | now |
| due to the fact that | because |
| in spite of the fact that | although |
| in the event that | if |
| for the purpose of | to, for |
| with regard to | about |
| in regard to | about |
| with respect to | about |
| a large number of | many |
| the majority of | most |
| is able to | can |
| has the ability to | can |
| make a decision | decide |
| take into consideration | consider |
| in the near future | soon |
| on a daily basis | daily |
| each and every | each |
| first and foremost | first |
| until such time as | until |
| in close proximity to | near |

### Weak words

Words that add no meaning. Delete them, or say how much. Up to 20% of sentences may have one.

| Word |
|---|
| very |
| really |
| quite |
| fairly |
| rather |
| somewhat |
| extremely |
| actually |
| literally |
| definitely |
| certainly |

### AI tells

Words and openers that make text sound written by a model. Each one in the first column is
a violation outside code, in pro and in casual.

| Not | Use instead |
|---|---|
| delve | look at, dig into |
| tapestry | (delete) |
| testament | proof, sign |
| realm | area, field |
| pivotal | key |
| crucial | important, needed |
| intricate | complex, detailed |
| multifaceted | (say which parts) |
| embark | start |
| elevate | improve |
| foster | help, build |
| underscore | show |
| showcase | show |
| vibrant | (delete) |
| ever-evolving | (delete) |
| game-changer | (say what changed) |
| dive into | look at |
| in today's | (delete) |
| it's important to note | (delete) |
| it is important to note | (delete) |
| in conclusion | (delete) |
| I'd be happy to | (do it) |
| I would be happy to | (do it) |
| absolutely! | yes |
| certainly! | yes |

### Sentences

1. Write one instruction per numbered step. Use 20 words or fewer.
2. Write other sentences with 25 words or fewer. Give each sentence one idea.
3. Up to 20% of sentences may break rule 1 or rule 2. No more.
4. Do not use semicolons. Write two sentences.
5. Use the active voice. Use the simple tenses.
6. Put the condition before the instruction: "If X, do Y."
7. If a reply has two or more separate points, write them as a list, not a paragraph.
8. Do not use a dash (`—` or `--`) between parts of a sentence. Use a full stop, a comma or a colon.
9. Write no paragraph of more than 3 sentences. Make it a list.
10. Use short, common words. A text of 30 words or more needs a Flesch reading ease of 50 or more.
11. Use an emoji only where it helps, in up to 20% of sentences. A status emoji that starts a list item, or one in a table, does not count.

### File paths in a reply

- In a reply, write each file path in full, from `~`. Example: `~/second-brain/harness/mac-setup/cmux-setup.md`.
- In a worktree, write the path of the file in the worktree, such as `~/second-brain/harness/.claude/worktrees/<name>/plans/...`, so a click opens the file you changed.
- A path inside a file you write keeps the form its file uses.
