# Writing for Vesper's Kinky Kapers

How to write conversations and cutscenes, who sounds like what, and the rules the lint enforces. Adding a
conversation needs no code: write a `.dialogue` file, point a Talker at it, run the lint.

## The rules (binding: WORK_ORDERS.md §0.2)
- **Every character is an unmistakable grown adult.** No age jokes, nothing child-coded.
- **Crude is welcome.** Jokes target Swyne, his goons, hypocrites, and Nim's dignity. Never the kink community or
  the Claw's practice.
- **People in trances** are never hurt and never the joke.
- **"Consent" is never said as the thesis.** It's shown: the Claw asks, Swyne doesn't.
- **Vesper's lines, Swyne's speeches, the death and the coda are the owner's to approve.** Mark them `# OWNER REVIEW`.
  The lint fails anything unmarked.
- **Banned words** are in `data/writing/banned_words.json` (the owner owns the list). The lint matches whole words in
  any case, so "sixteen" is fine and "teen" isn't.

## Where things live
| What | Where |
|---|---|
| Conversations | `data/dialogue/<world>/<who>.dialogue` |
| Who's who (display name, colour) | `data/dialogue/speakers.json`; a speaker must be in it |
| Cutscenes | `data/cutscenes/<name>.json` |
| Banned words | `data/writing/banned_words.json` |
| The worlds' Keys and jokes | `data/worlds/<world>.json` (from `docs/worlds/`) |

## The .dialogue format
```
# A comment. "# OWNER REVIEW" is a comment too (see below).
~ start                              a section; a conversation starts at a label ("start" unless told otherwise)
Dash [grin]: Race you.               Speaker [emotion]: text. The emotion is optional.
[narrator] The tide came in.          a narrator line
- Prove it. => race                  a choice for the line above; "=> label" jumps there
- [if has_crop] Crop him. => crop    a choice that only shows if its condition holds
[if met_dash] Dash: You again!        any line, jump or set can be conditional
set met_dash                         set a Game flag (to true)
set times_raced = 3                  ...or to a value
unset met_dash
=> race                              jump to a label
=> END                               end the conversation
```
- **A section ends the conversation when it runs out,** unless it jumps.
- **Choices jump away:** anything after a line with choices only runs if a choice has no `=>`.
- **Conditions:** `flag`, `not flag`, `flag == 3`, `tips >= 5`, `a and b`, `a or b` (`and` binds tighter, no
  brackets). Namespaced Game flags work too (`[if bound/pier/g1]`).
- **Inline tags:** `[wait=0.5]` pauses the typing; `[shake]` and `[sfx=name]` come with WO-022.

### Marking lines for the owner
- `# OWNER REVIEW` **before the first label** covers the whole file.
- `# OWNER REVIEW` **inside a section** covers the rest of that section only.
- Strings in code that give Vesper or Swyne a line need `# OWNER REVIEW` on the same line or the one before.
  Better: put them in a .dialogue file.

## Putting a conversation in the game
- **A Talker** (`core/talker.gd`): set `file` (and `label`, default "start"). Y beside it plays the conversation and
  pauses the world.
  - `once` plays it one time only (remembered as `talked/<file>/<label>`); `after_label` plays after that.
  - `cutscene` plays a cutscene instead.
  - `display_name` puts "Name (Y)" over its head.
- **Vesper teaching** (`core/lesson_giver.gd`): `dialogue_file` and `dialogue_label` play as she teaches.
- **From code:** `await Dialogue.run(file, label)`, or `await Dialogue.play_cutscene(path)`.

## Cutscenes
JSON with a list of steps, played in order:
```
{"steps": [
  {"shot": {"from": [x, y, z], "look_at": [x, y, z], "secs": 1.5}},    the camera, over secs (0 cuts)
  {"move": {"node": "Vesper_k", "to": [x, y, z], "secs": 2}},          someone moves there (the node's path in the scene)
  {"face": {"node": "Vesper_k", "toward": [x, y, z]}},
  {"say": {"file": "res://data/dialogue/x.dialogue", "label": "start"}},
  {"card": {"kind": "newspaper", "masthead": "...", "title": "...", "body": "...", "owner_review": true}},
  {"card": {"kind": "radio", "title": "...", "body": "...", "owner_review": true}},
  {"set": {"flag": "seen_paper", "value": true}},
  {"wait": 0.5}
]}
```
- The world is paused throughout, and the level's own camera comes back at the end.
- **Cards** (newspapers and radio bulletins) carry the plot between worlds, and they're always the owner's to
  approve: the lint fails a card without `"owner_review": true`.

## Run the lint
`godot --headless --path . -s tools/dialogue_lint.gd`

It fails on:
- a file that doesn't parse, or a jump to a missing label;
- an unknown speaker;
- an unmarked Vesper or Swyne line;
- a card that isn't marked;
- a cutscene that says a missing conversation;
- a banned word in dialogue, cutscenes, world data or strings in code.

## The voices
One sheet per character. These are proposals from DESIGN.md and WO-009; the owner rewrites them.

### Vesper (bobcat): the mentor
- **Warm, exact, never mocking, never hurries.** "The one person who asks."
- Short sentences, and no wasted words. She's never sarcastic, and her praise is rare and plain ("Adequate." is warm,
  from her).
- She asks before she acts, and she tells you why once.
- She's never loud. She doesn't need to be.
- **Every line is `# OWNER REVIEW`.**
- *Sounds like:* "Nobody looks up. Live there." / "You don't. You test it, every time. I still do."

### Nim (clouded leopard): the player
- **Proposal:** direct, dry, physical, and a little proud of her climbing.
- She was one of Swyne's test subjects, so hypnosis isn't funny to her, but Swyne is.
- She deflates pomposity and takes the hits to her dignity well.
- *Sounds like:* "I'm not a project." / "\"Inspecting.\" Sure."

### Augusta (lioness, about sixty): protocol
- **Formal.** Full sentences, titles, good manners as a weapon.
- She corrects posture and grammar alike.
- *Sounds like:* "You dance like a soldier. It'll do."

### Silke (snow leopard): rope
- **Nearly silent.** One word where others use ten, often none (an action instead). Exact when she does speak.

### Dash (cheetah, twenties): impact
- **Brash.** Fast, cocky, competitive, and she cheats at races and claims she let you win. Warm underneath.
- *Sounds like:* "Everyone's a project. I was a project."

### Rivet (caracal, forties): latex and gadgets
- **Dry.** A sardonic engineer: understatement, technical precision, unimpressed by most things.

### Lull (serval, thirties): consensual hypnosis
- **Velvet.** A slow, low, soothing cadence. Offended that Swyne cheapened her craft. She never makes the people in
  trances the joke.

### Grizelda (Pallas's cat, fifties): brat-taming
- **Short.** Grumpy and terrifying, with clipped commands. Her Scold is one word.

### Bastion (jaguar): the door
- **One word,** if any.

### Swyne (boar): the villain
- **Pompous, pious, a hypocrite.** Decency speeches full of "families" and "filth", while his own business is the
  filth.
- He never believes he's the joke, and he always is.
- **His speeches are `# OWNER REVIEW`.**

### Goons and staff
- Broad comic timing. They fold under a confident Domme, and some of them have been waiting all their lives to be
  told what to do.
