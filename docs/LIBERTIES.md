# Creative liberties

Choices an agent made beyond the docs. The owner can overrule any of them.

## WO-001 (2026-11-11)
- **The keyboard and mouse layout.** DESIGN.md gave only the pad. Keys: WASD move, mouse or arrow keys turn the camera,
  Space jumps, J or left mouse strikes, E binds/talks/Commands, C or Ctrl crouches, K pounces, L or right mouse locks
  on, Shift ropes, Q uses gear, 1 to 4 pick the Command word, V or middle mouse recentres, Esc or P pauses. All of
  it is in one table in `core/controls.gd`.
- **The content card's wording** (`core/age_gate.gd`, `# OWNER REVIEW`). It lists crude humour, strong language,
  fetish clothing and BDSM themes, villainous hypnosis and cartoon fighting. It says nothing explicit is shown and that
  everyone is a grown adult, and asks for 18 or older and of age locally. Buttons: "I'm 18 or older: enter" and
  "Quit".
- **A minimal pause** (Resume / Quit to desktop) came ahead of WO-010, so a Deck build can always be left from the
  pad.
- **Settings live apart from progress** (`user://settings.cfg`), so erasing progress doesn't ask the age question again.

## WO-002 (2026-11-11)
- **The three props:** a cast-iron gas lamp, an advertising column with blank cream panels (posters go on later), and
  a wrought-iron bench. The owner approved the list with the cost.
- **Concept details beyond the docs:**
  - Nim's garb: a charcoal top and cargo trousers with knee pads, open-fingered climbing gloves, wrapped forearms, a
    belt with rope, and the crimson ribbon at her collar as her only red.
  - Nim's suit: a black latex catsuit, a crimson underbust corset, a slim collar with a ring, long gloves, knee boots.
  - Vesper's suit: a long crimson velvet coat with black leather lapels over a latex catsuit and corset, and a coiled
    whip at her hip, never drawn.
  - The first garb concept (a leotard over bare legs) was redone with the owner's yes. It's in
    `.wip/concepts/rejected/`.
- **The corner's layout:** a crossroads with the Velvet Rope on the NE corner (red door, velvet canopy, the name in
  brass, a real velvet rope on brass posts, a red light). There's brick and plaster townhouses, a small square with the
  column and bench, and lamps on every corner. Only the club wears red.
- **Words on the street** (all `# OWNER REVIEW` in `levels/style_test/corner.gd`):
  - The club's plaque: "Members. And those who ask nicely."
  - The Decency League poster: "KEEP THE PURRLANDS DECENT", then "Vote SWYNE", then the small print "Paid for by the
    Decency League. Seen something indecent? Write it down. Send it to us. All of it."
- **The corner was the main scene for the style test,** so the Deck build opens on it. Back / Tab flips to the test room (a
  prototype action, `debug_swap`).

## WO-003 (2026-11-11)
- **Moves beyond the work order's numbers:**
  - A short hop when A is let go early.
  - Sneak at 3 m/s, crouched to 1 m, so she fits through crawlways.
  - She steps up anything 0.3 m or lower without jumping.
  - In the air with the stick let go she keeps her momentum.
  - **The air pounce is level** for its 0.25 s and is allowed once per jump: a lunge across a gap, not an arc.
- **Ledges:** caught automatically when she's falling or at a jump's top and moving toward one 0.6–2.4 m above her
  feet. A, or the stick held at the wall for 0.3 s, pulls her up. B, or the stick away from it, drops her. Left and
  right shimmy.
- **Climbing:** marked surfaces are collision layer 2. On the course they're green brick; the real worlds will mark
  them with ivy, drainpipes and rigging. A leaps off, B lets go, and the stick climbs up, down and across. On the wall
  the stick is read raw (up is up), not relative to the camera.
- **Beams:** a "magnet" pulls her onto a beam's line when she falls within 0.5 m of it, so a 5 cm wire is catchable.
  She can't fall off a beam sideways, only jump off it or walk off an end.
- **Her capsule** is 0.35 m in radius, a little slimmer than Kiara's 0.42 in Nine Lives, which has wings.
- **The hint line** now lists the pounce, climbing, ledges, the recentre and the scene flip. Back / Tab cycles the
  test course, the corner and the test room; the course is the main scene for now.

## WO-004 (2026-11-11)
- **A device breaks only when struck from in front of whoever holds it.** From behind, a strike passes through the
  person and the device, so a brawl can't wake someone by accident. That makes "strikes pass through" literal, and
  gives the player a rule to learn: face them to free them.
- **Health is 5.** A punch costs 1 and gives 1 s of invulnerability. Downed, she's back at the last checkpoint, full,
  after 1.2 s, and nothing else is lost.
- **Hits 1 and 2 stagger** (0.8 s, a 1 m/s shove) and **hit 3 knocks down** (1.8 s, a 5 m/s throw). Either one makes
  him bindable.
- **Unaware means** patrolling or walking back to his route with suspicion under 0.5. A suspicious, chasing or
  searching goon must be staggered first.
- **Goon sight:** a 110° cone, 14 m, halved when she's crouched, and a 1.2 m "bump" radius. The ? and ! over their
  heads are readability aids for the greybox; WO-005 and WO-010 decide what ships.
- **A bound goon stays standing,** wrapped in three turns of the Rope's red, with a note: "For the police. No need to
  thank us." (`# OWNER REVIEW`). Bound goons stay solid: they're obstacles now.
- **The woken person says** "...Where am I? Why am I holding this?" (`# OWNER REVIEW`). They're never the joke.
- **Lock-on picks** the goon nearest the middle of the view within 15 m, and holds him while LT is held. There's no
  target switching yet.
- **The test course starts fresh once per launch,** so its goons and sleeper reset for each Deck session.

## WO-005 (2026-11-11)
- **The light meter is computed, not rendered:** distance and shadow rays to each light. It ignores ambient light,
  bounce light and how the toon shader draws a pool's edge, so the HUD bar and what's on screen can disagree a little
  at a pool's rim.
- **How sight scales:** in full dark she's seen at a quarter of the range (14 m for a goon, 16 m for a lookout).
  Crouched, half of that again: about 1.75 m from a goon when crouched in the dark.
- **Noise:** running is loud and walking is quiet. Landings count only from 2.5 m up, and a leopard dropping from less
  is silent. A landed strike is heard 8 m away. A noise makes a goon look; a second makes him search. It never starts
  a chase.
- **Lookouts can't be bound or struck** for now; the player avoids them. The alarm reaches every goon within 30 m,
  and the lookout settles after 4 s.
- **Takedown from behind** is the unaware Bind, now limited to her being over 100° round behind him. It keeps the
  Bind's 0.6 s.
- **Takedown from above** reaches 1.3 m from where she lands, needs a 1.5 m fall, binds in 0.4 s, and works whatever
  the goon is doing (even mid-fight). The test course has it unlocked; elsewhere it needs `lesson_takedown_above`.

## WO-006 (2026-11-11)
- **Who suspects the suit:** ordinary goons and lookouts never suspect her while her cover holds. Only security
  marked `knows_her` do, unless she's in a crowd. Without them a blend-in level would have no tension except
  Composure.
- **The strut** is the stick part-way (0.6 or less) or B held. B doesn't crouch in the suit. Keyboard players use B
  (C or Ctrl) to strut.
- **The Composure numbers:**
  - drains while watched: running 0.3/s, climbing 0.4/s, crouching 0.2/s;
  - costs: a jump 0.12, a pounce 0.25, a refused strike 0.1, a failed command 0.25;
  - restores: a strut 0.06/s, a command that works +0.15.
- **Any goon who gives chase blows her cover,** and a blown cover alerts goons within 25 m.
- **Recovering by breaking sight** takes 5 s with nobody hunting or watching, and brings her back at 0.35.
- **A wardrobe in a blown suit gives a fresh suit** (so she stays in the suit), and goons chasing her lose her. It
  won't work with a chaser within 2.5 m.
- **Command tiers:** Kneel is level 1; Fetch and Open are level 2. Goons are tier 1, staff tier 2. Kneel lasts 20 s
  and the kneeler watches nothing. Commands go to the LT target, or to whoever's nearest in front.
- **Hold the Room** is a 1 s hold of Y with her cover blown. It stands down goons within 15 m and restores her cover
  at 0.3.
- **The fake trance** is a toggle on LB. Pushing the stick past 0.85, jumping, climbing, striking or pouncing breaks
  it. It works in either outfit.
- **New lines** (`# OWNER REVIEW`): the staff's replies, Nim's refusal "Not in the suit. Not while they're
  watching.", "Thank you.", and "She holds the room."

## WO-007 (2026-11-11)
- **Choosing LB's gear:** D-pad left (key 4) cycles the Scold, the pendant and lures, of what she has. D-pad left was
  the one direction the Command words didn't use. The crop stays on held X, the rope on RB, and the signet is
  passive.
- **The ceiling crawl and the headfirst descent are one lesson** (`lesson_ceiling`), as DESIGN.md pairs them.
  Ceilings grip automatically when she jumps up under them. Head first, "up" on the stick takes her down, at 4.5 m/s
  (climbing is 2.5).
- **The crop** comes out of a held X: the claw strikes on the press, and holding past 0.3 s adds the lash (3.2 m, 30°,
  3.2 m up). It doesn't step in, and it's refused in the suit like any strike.
- **The rope on the ground** binds before it pulls. It reaches 7 m for a bind and 9 m for a pull. Remote binding
  keeps the Bind's rules: staggered, knocked down, frozen, or unaware and from behind.
- **The Scold** freezes for 3 s (cooldown 5 s), and a frozen goon can be bound. The goons wake furious and give chase.
  The shout is "SIT." (`# OWNER REVIEW`).
- **The pendant** wakes before it fakes: LB wakes the sleeper she's looking at (9 m, in sight); with nobody to wake,
  it toggles the fake trance.
- **Lures** are counted (`NimGear.lures`; the course gives 5). Where one would come from in a world (seized
  contraband?) is open.
- **The signet** makes the powerful (`Staff.powerful`, tier 0) answer like staff (tier 2).
- **Vesper's stand-in line** on the course: "Nobody looks up. Live there." (`# OWNER REVIEW`).
- **Goon AI changes** that came out of the probes:
  - searches really walk to the spot (and stop at a wall in the way);
  - a second noise while a goon is still suspicious sends him to search.

## WO-008 (2026-11-11)
- **The hub's 10 Keys are six tins plus four secrets** (an assumption; see HANDOFF.md's open question).
- **The five-woken Key** is each world's Key 10 (`<world>_10`), as all six briefs number it.
- **The tin is struck, not walked into** ("smash it", the Pier brief says). It's cream and navy and labelled "GIVE
  GENEROUSLY to DECENCY" (`# OWNER REVIEW`).
- **The save file** is one `user://vesper.json` holding three slots, with the one in play remembered. There's no slot
  menu yet; it comes with the title screen (WO-010).
- **Shortcuts** open from their back with Y and stay open (a Game flag). From the front they say they're bolted.
- **Fast travel** points are found by walking within 3 m. Y beside a found one lists the others in that world.
- **Rank doors** open by themselves when she's within 5 m with enough Keys; otherwise they show "N KEYS".
- **"Return to the club"** goes to the street corner (WO-002's style test, outside the Velvet Rope's door) until the
  Old Quarter hub is built.
- **Distance culling:** meshes 2.5 m or smaller stop drawing past 45 m, in worlds built on `World`.
- **The world data files** keep each brief's extra sections (story, how it teaches, notes) after the schema's
  fields. City Hall has no Keys. Swyne's species isn't in the finale brief, so it's null there.

## WO-009 (2026-11-11)
- **The dialogue format and box are Nine Lives',** ported. Choices are marked with ">" and the next-line marker is
  "...", because the default font may not have Nine Lives' "▶" and "▼".
- **OWNER REVIEW scope:** a mark before a file's first label covers the file; a mark inside a section covers the rest
  of that section. Code strings need it on the same line or the one before.
- **Cutscene cards always need the owner's mark** (`"owner_review": true`), since they carry the plot between
  worlds.
- **The banned words** are a proposal (age and child-coded words, "consent" and "consensual"), matched as whole words.
- **Placeholder mastheads:** "THE EVENING PAW" for newspapers, "RADIO PURRLANDS" for radio. A card can name its own.
- **Nim's voice** (direct, dry, physical, proud of her climbing) is my proposal; DESIGN.md doesn't give her one.
- **The course's lines** (Vesper's lesson, Dash, the paper) are placeholders written to exercise the system, not the
  game's script.

## WO-010 (2026-11-11)
- **The title's menu:** Continue, Saves, Settings, Content, Quit. It's plain dark and velvet with the name in gold;
  the art pass dresses it later. A new game starts on the test course until the prologue exists.
- **Erasing a slot** asks "Sure?" on the same button, so a second A erases it.
- **Remapping:** the gameplay buttons only. The sticks and WASD/mouse stay where they are. A remap replaces that
  device's binding (a key replaces the key, a pad button the pad's). Capture waits 5 s, then gives up.
- **Text size** scales the whole UI (0.85, 1.0, 1.2). **Reduce motion** turns cutscene camera moves into cuts.
  **Reduce flashing** is stored for later (nothing flashes yet).
- **The HUD** keeps the in-world prompt to what Y does (the most contextual button). Other buttons are on the pause
  menu's Controls page, which lists the live bindings for the device in use.
- **Captions:** staff replies and a waking sleeper's line, labelled "Staff" or "Councillor" (the HUD doesn't know
  their names yet).
- **The papers after a world** come straight from the briefs' wording. The Primrose one uses a "THE PARISH
  NEWSLETTER" masthead, and the Press one is a radio card.
