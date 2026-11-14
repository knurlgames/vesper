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
  - The Coalition poster: "KEEP THE PURRLANDS DECENT", then "Vote SWYNE", then the small print "Paid for by the
    Decency and Integrity Coalition of Kindness. Seen something indecent? Write it down. Send it to us. All of it."
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

## WO-014 (2026-11-12): the Pier
- **The layout** is a proposal built from the brief's area table. The map is in `levels/pier/pier.gd`'s header.
  - **Stalls:** the gallery, the striker and Pearl's tent, plus candyfloss, hot dogs, hook-a-duck, penny falls, teas
    and whelks.
  - **Shop names:** Rock & Candy, Fish & Chips, Amusements, B&B Vacancies, Souvenirs, Tea Room.
  - **The smugglers' crates** are stencilled "HABERDASHERY" (the Docks' joke, early).
  - **The Fun Palace runs wall to wall.** Covert players go up the east walkway's marked wall and over the roof.
- **Nim's moves:**
  - **B on a beam drops her off its side.** It's the way down onto a goon for the takedown from above. On a beam she
    can only walk along it, so before this there was no clean way off.
  - **The crop works in the suit** on targets, bells, switches and gulls, never on goons. The shooting gallery is a
    suit Key played with the crop. A tap of X in the suit still counts as a refused strike.
  - **The push that grabs a wall counts as "up"** until the stick moves. This was a fix: with the camera facing her,
    she grabbed and let go every frame.
  - **Where beams cross, she follows the one the stick runs along.**
- **Key 1, Dash's race:**
  - **Her cheat:** she goes on "two" and vaults the 4 m fence onto the Fun Palace's west walkway, a route Nim can't
    take.
  - **Timing:** she runs it in 52 s. A clean run by Nim over the roof takes about 42 s.
  - **The finish:** a line short of the Prize Hall.
  - **The crop is handed over in Dash's "won" lines**, with the rule above in her words.
- **Key 2:** any bind counts, not only from above (the beams make above the natural way). The self-tied smuggler
  asks if his figure-eight with a loop is right: that's the Rope's knot (DESIGN.md).
- **Key 3:** six targets in 30 s on rails behind the counter. They speed up as she hits them ("rigged"). The barker
  only serves the suit.
- **Key 4:** the bell hangs off the tower's west face, in the crop's reach from the top and out of it from the deck.
  The mallet goon is Staff (he doesn't fight).
- **Key 5, Pearl:** she haggles in three exchanges.
  - Each soft answer costs 0.3 Composure; two of them, or naming the Rope, lose the sale and blow her cover.
  - **Her reading:** "a ledger... somewhere with hedges" (Primrose Close), a nice accountant, and never anything
    taller than a stepladder.
- **Key 6:** the safe's unlocked. Opening it starts a goon's count; she has to be out of the office before ten, or the
  palace's two goons are alerted and she can try again.
- **Key 7:** the prize shelves are one tall unit with a marked rolling ladder at the end. The clerk kneels: "Oh. Oh,
  finally. Thank you, Mistress."
- **Vesper's lesson** starts on its own when Nim comes within 11 m under the pier. Vesper's lines are new and
  `# OWNER REVIEW`.
- **Vesper rides car 2 of the wheel** all night. "You took your time" plays when Key 8 is taken.
- **Dash's buttons line** plays the first time Nim changes into the suit at her hut.
- **Key 9, the Big Dipper chase.** The brief's beats, made playable:
  - **The catwalk:** Nim follows on a maintenance catwalk beside the track, not on the rails themselves, so the car
    never runs her down.
  - **"At the loop":** the switch tower stands at the circuit's turnaround. There's no vertical loop.
  - **The points** take effect the next time the car passes the branch.
  - **The stall:** the spur car stalls at the crest of its last drop until she's beside it ("It's stopped! Why's it
    stopped?!"), then crawls down. The catch counts if she's in the car, on its rim, or leaping over it.
  - **A miss** sends him round again with the points reset.
  - **The ledger's line:** "Demonstration parties. Primrose Close. Forty boxes, gift-wrapped." "The vicar's wife
    ordered six."
  - **The photo:** he's screaming, her eyes are shut, and she says "...I'll take two."
- **Laffer's fight.** The brief's three phases, made playable:
  - **The hall opens with the ledger** (Key 9), and the door locks during the fight.
  - **The Claw:** the crane tracks her and shakes before it drops. "The booth" is a gallery along the east wall,
    reached by walking the crane's bridge after climbing the stuck claw's cable.
  - **Whack-a-goon:** nine hatches, three hits. The gull's calls are captions ("SQUAWK! Back row, left!"). Up to
    four goons come up and fight.
  - **The prize mountain:** six steps. He throws boxes that knock her back. A pounce or a hit at the top ends it.
  - **Being downed** restarts the phase she'd reached.
  - **Laffer's lines:** "Lucky Dip! You're the prize!", "It's all rigged!", "It works on everyone. It works on
    EVERYONE. Ha... ha?", "The grand prize!", "Somebody stop me laughing."
  - **Vesper's scene:** "They'll find him gift-wrapped." / "Adequate." (a narrator line: from Vesper, that's warm).
  - **There's no boss Key** (the brief's ten don't include one). The fight ends the world (`done/pier`, the paper),
    but she stays on the pier to finish up.

## WO-014 (2026-11-12): Deck review fixes and dressing
- **A crop flick hushes a gull for good:** it squawks and flies off, and doesn't come back on reload. The brief said
  "shuts them up"; "for good" is mine (Banjo's lesson against respawning nuisances).
- **The bit parts wear WO-013's bodies** until they get their own:
  - the clerk is a meerkat (the Pier has none otherwise);
  - the mallet goon and the barker are weasels in Laffer's waistcoat;
  - the gulls stand on crow's nests atop their posts.
- **Vesper's demonstration** has its own camera shot.

## 2026-11-12: WO-014b, the Velvet Rope's house (the owner's asks; the details are mine)
- **The club grows down, into vaults under the street behind it,** reached by a stair from the old dungeon. The
  rooms, their names and sisters are mine: the Parlour (Augusta), the Rope Room (Silke), the Throne Room (Grizelda),
  the Quiet Room (Lull), Dash's, the Workshop (Rivet). So is the swung-open shelf to the Backroom.
- **Clients change at a screen by the bar**, street clothes to swimwear. (The robes on hooks were my earlier
  suggestion; the screen reuses the WO-014 civilians upstairs.)
- **The regulars:**
  - **"Mr Smith"**, a Coalition man in a false moustache, wants scolding "for hypocrisy, ideally". His word
    is "Decency".
  - **Pip**, a nervous first-timer. Her word is "Teacup".
  - Both mine; the hypocrite's the joke, never the kink.
- **The session game:** cues each beat; Command, Hold, Praise, Check in, Stop.
  - "Yellow" means slow down; the safeword means stop within 3 s, and stopping is a good ending.
  - Vesper's line when Nim doesn't stop: "You heard the word, and you kept going. That's the one thing we never do."
    (OWNER REVIEW)
- **The sisters' games:** Silke's breathing (Switch) and knots (Domme); Augusta's posture (Switch) and corrections
  (Domme). Each sister checks in halfway, or in a Domme expects to be asked.
- **Every line** in `hub/sessions.dialogue`, the sisters' offers in `hub/club.dialogue`, and the rooms' exchanges
  (`club_life.gd` `ROOM_LINES`) is mine and marked OWNER REVIEW.
- **Dash's club lines:** "Nobody books me. Can't think why." / "I hit the bag. The bag doesn't complain. It's the
  healthiest relationship in the building."

## 2026-11-12: The sisters' swimwear (the owner's ask; the designs are mine)
- **Each two-piece is full-coverage** (high-waisted bottoms, a supportive top), barefoot, with no masks: downstairs
  is among members.
- **Each is in her own colours:**
  - Augusta: vintage burgundy with gold piping and a buckle;
  - Silke: matte black with a crimson rope-braid trim and a halter neck;
  - Dash: sporty orange and black;
  - Rivet: glossy black with brass rings;
  - Lull: midnight blue with lavender, a wrap top with long sleeves;
  - Grizelda: black with purple piping and a high neck.
- **They wear them in the vaults only** (their rooms, and the cross). The rig heights match their suits.

## 2026-11-12: The cross (the owner's ask; the details are mine)
- **The form's rows:** wrists, ankles, mouth (none, ball, bit), eyes, neck, and gentle or firm.
- **A gag's safeword is a dropped bell,** held in the right hand.
- **The tools:** feather, ice, whisper, flogger, crop, paddle. Sensation and impact only; no vibrating toys, since
  those are Swyne's weapon in the story.
- **Nim's muzzle is never a gag:** her mouth row is fixed when she's on the cross.
- **The games:**
  - Leading: a touch game (follow the sweet spot) and a rhythm game (land on the beat).
  - On the cross: hold still and brace, from After Hours.
  - The heat band, strain and trust numbers are mine.
- **Each sister's wants, limits, safeword wording and tray:**
  - Lull asks for the blindfold.
  - Grizelda wants it "harder than you think".
  - Rivet checks the buckles.
  - Dash wriggles, so her sweet spot drifts more.
- **The clients:**
  - The generic client's word is "pineapple".
  - Smith's is "decency" (the hypocrite joke).
  - Pip's is "teacup", and Pip takes no impact tools.
- **Where things happen:**
  - The cross stands at the vaults' hall end, in front of the fireplace.
  - Aftercare is in Lull's room, with a blanket.
- Every line is OWNER REVIEW.

## 2026-11-12: The tossed rose, and Swyne's toys (the owner's asks; the details are mine)
- **The toss:** a deed's rose lobs down from 7 m up and 5 m beyond the spot, away from the camera, over 1.1 s,
  spinning. It can't be taken in the air, and lands in a burst of crimson petals. Vesper watching is implied, never
  shown. The five-woken rose and the tin's are still paid straight into the tally.
- **The toys** (all suggestive and non-anatomical; never shown in use):
  - **The contraband box:** cream and navy, a heart, a spiral sticker, a plain lilac shape in its window.
  - **The held toys,** out of the box with the spiral lit and pulsing (a blue light in time with a hum): a plush seal
    toy with a speaker grille, a wand massager, a love egg with its remote, a feather tickler.
  - Each entranced person gets one by their id; the prologue's guest has the plush his lines mention.
- **Swyne's palette:** cream, lilac and his pale blue spiral. Crimson stays the Rope's (only the rose wears it).
- **"They can't stop and it feels so good":** the entranced hug their toy close and murmur when Nim's within 8 m
  (`Entranced.MURMURS`, OWNER REVIEW):
  - "Mmm... just a little longer..."
  - "It's so warm. I can't put it down."
  - "Everything's humming. Isn't it lovely?"
  - "One more. Just one more."
  - "I was going somewhere... wasn't I? ...Mmm. Later."
  - "Don't take it. Not yet. Please."

  Blissed out and a little sad; never the joke.

## 2026-11-12: Velvet Roses and Rivet's bench (the owner's decisions; the details are mine)
- **Velvet, not black,** for the rose: crimson velvet is the Rope's own (the velvet-red rule). Easy to swap.
- **Vesper's lines giving the first rose** (`hub/prologue.dialogue` `tag`, OWNER REVIEW): "The Rope gives a rose for
  good work. That was good work." / "It's a record. Keep every one you're given. Nobody can take them back." / the
  gates know how many you hold; "One opens the Pier. The rest, you'll earn."
- **The rose pickup** is a placeholder built from primitives (a stem, two leaves, a velvet bloom). A Meshy rose would
  cost about 24.
- **Rivet's rates:** a lure per 25 seized, an upgrade per 100 (health pip, then Composure, alternating). Composure
  upgrades divide every drain by 1 + 0.25 each. Lures are kept in the save (`gear/lures`) and can be thrown once Nim
  has Rivet's lure gear.
- **Rivet's new lines** (`hub/club.dialogue`): "Bring me every one of Swyne's toys you seize. Gutted, they make good
  distractions." / "And enough of them pays for better kit. Harder to knock down. Harder to rattle." Her handover
  caption: "%d of Swyne's toys. I'll have the receivers out of them by morning."
- **The first-contraband note:** "Contraband: one of Swyne's toys, off the street. Take what you seize to Rivet at
  the club: she turns it into gear."

## WO-014 (2026-11-12): Deck review 2 (seven clips)
- **Dash teaches the suit** (new lines in `pier/dash.dialogue`, label `suit`) the first time Nim comes out of her hut
  in it: walk, don't run; what costs Composure; a blown cover; how to get it back; try Kneel. The brief gave her the
  buttons joke only.
- **One-time HUD reminders:** the first time Composure drops, and the first time cover's blown.
- **The strut is slower:** 2.4 m/s, down from 3.2, a poised walk for her legs. It was a jog, and the run clip cut
  into it.
- **Vesper leaves the lesson on foot,** down the sandbar into the dark, instead of vanishing.
- **A dim fisherman's lantern** hangs off the deck near her beam, so she's seen standing on it.
- **Dash shouts as she vaults the fence** ("Over the fence! Find your own way round, slowpoke!"). A "DASH" marker
  over her head shows through walls during the race.

## WO-014 step 6 (2026-11-12): the Pier's people and props (Meshy)
- **Madame Pearl is a blue-and-gold macaw**, not a scarlet one: the velvet-red rule keeps crimson for the Rope. She
  wears a purple head scarf, pearls and a fringed shawl.
- **The civilians are four species:** an otter (thirties), a hare (forties), a fox (fifties) and a hedgehog (sixties),
  in seaside night-out clothes. Each person gets a light tint, so four bodies fill a crowd. The same four play the
  Midway's crowd, the five prize winners and the prologue's guest (the hare).
- **The coaster car is teal and cream,** not the greybox's red (the same rule).
- **Props:** the arcade cabinets, the prize boxes on the wall (a plush seal), the landing's crates and rowboat, Pearl's
  table, and lifebuoys and deckchairs on the promenade (new dressing). The cabinets and crates are stretched to the
  old boxes' sizes, so every route and contraband spot stays where it was.

## WO-014 (2026-11-12): the hub
- **The layout** (`levels/hub/hub.gd`): Rope Square with the club on its north side; Seafront Road east to the
  Pier's gate; six short streets to the later worlds' gates.
  - **The street names:** Primrose Lane, Hillside Road (the Retreat), Dock Street, Press Alley, Council Avenue (the
    Ball), Clock Tower Way (City Hall).
  - **The shop names:** Chandler, Oysters, Rooms, Shipwright.
- **The club:** the lounge is at street level, with the dungeon "underneath" down a short ramp (1.6 m), not a whole
  floor down.
  - The dungeon's dressing: rope coiled on brass hooks, a padded bench, red light. Suggestive only.
  - **The sisters** wait in the lounge in their suits. **Dash isn't there:** she's at the Pier.
- **The prologue:**
  - It's Nim's first night as a member. The guest comes in "on a member's card".
  - **Waking him pays the hub's Key 10.** That's her first Key, so rank 1 opens the Pier. It reuses the "all
    sleepers woken pays a Key" rule, with the hub's one sleeper.
  - The lines are new (`data/dialogue/hub/prologue.dialogue`, `# OWNER REVIEW`).
- **Hub Key 7:** over Seafront Road's rooftops to a harbour lamp.
- **The way back from the Pier:** an arch at the promenade's west end.
- **The club's lines** in each sister's voice:
  - Augusta: posture;
  - Silke: a nod;
  - Rivet: "built it to outlast your bad decisions";
  - Lull: Swyne cheapened her craft;
  - Grizelda: "Shoes. Wipe.";
  - Bastion: "Members."
