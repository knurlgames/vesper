# Work orders

The build plan for **Vesper's Kinky Kapers** (working title). Read these first:
- [DESIGN.md](DESIGN.md): premise, cast, moves, worlds.
- [worlds/](worlds/): a brief per world.
- [ART_DIRECTION.md](ART_DIRECTION.md): the look and the pipeline.
- [STUDY.md](STUDY.md): the research behind the structure.

## §0 Ground rules

### 0.1 The game
A 3D, Banjo-style hub action platformer, adults only. Nimbus, a clouded leopard, joins the Velvet Claw, a sisterhood
of feline Dommes who fight crime, under Mistress Vesper. She follows Councillor Swyne's hypnotic contraband through
six worlds to City Hall, where Vesper dies on her own terms.

### 0.2 Content lines (binding)
- Every character is an upright, anthropomorphic, unmistakably grown adult. No age jokes, no child-coded designs.
- Crude writing is welcome. Assets stay suggestive. **No on-screen sex acts, nudity or genitalia in anything an agent
  authors.** The toys are boxed products with a spiral glow, never shown in use.
- Jokes target Swyne, his goons, hypocrites and Nim's dignity. Never the kink community or the Claw's practice.
- People in trances are never hurt by the player and never the joke.
- "Consent" is never said as the thesis. It's shown: the Claw asks, Swyne doesn't.
- Vesper's lines, Swyne's speeches, the death and the coda are owner-reviewed: mark them `# OWNER REVIEW` in the data.

### 0.3 Rules from the owner
- **The owner handles all git commits and pushes. Don't commit.**
- **Gamepad is first-class.** Every screen works on a pad as well as keyboard and mouse. The Steam Deck is the test
  device.
- **Never reuse another game's assets,** Nine Lives included. Its **code and lessons** may be ported (it's the
  owner's), rewritten to fit; its art may not.
- **Meshy costs credits** (shared with Nine Lives). Say what a batch costs and wait for a yes.
- Write files with Write/Edit, not bash heredocs.
- After every task, update `docs/HANDOFF.md`. Creative liberties beyond these docs go in `docs/LIBERTIES.md`.

### 0.4 Tech
- Godot 4.7.1 (.NET editor build, GDScript only): `C:/dev/tools/godot/Godot_v4.7.1-stable_mono_win64_console.exe`.
- Git LFS for `.glb` and `.png` under `assets/`.
- Autoloads: `Game` (flags, collectibles, ranks, save), `Controls` (bindings in code), `Hud`, `Dialogue`, `Audio`.
- **Every system has a probe:** a headless script (`--headless --fixed-fps 60`) that plays it with real inputs and
  fails loudly. A move isn't done until a probe has done it.

### 0.5 Definition of done
1. Works with a pad and with keyboard and mouse.
2. No errors or warnings in the log.
3. Tunables are exported or in one constants block.
4. A probe or test covers the logic.
5. Nothing explicit in agent-authored assets (§0.2).
6. HANDOFF.md updated.

---

## Foundation

## WO-001: Project scaffold (done 2026-11-11; see HANDOFF.md)
- A Godot 4.7.1 project at the repo root: `project.godot`, `.gitignore` (`.wip/`, `.godot/`), `.gitattributes` (LFS).
- `Controls`: every action bound in code, pad first: move, camera, jump (A), strike (X), bind/talk/command (Y),
  crouch (B), pounce (RT), lock on (LT), rope (RB), gear (LB), command word (D-pad), pause (Start). Remappable later.
- Autoload stubs (§0.4). Physics interpolation on.
- **Age gate and content card** on first launch (text owner-reviewed).
- A test room (`main.tscn`) with a greybox capsule.
- `tools/deploy_deck.sh`: exports the Linux preset to the Deck at `~/Games/Vesper/` (port the Nine Lives script).
- **Acceptance:** opens clean; the gate blocks until confirmed; a capsule moves on pad and keys; the Deck build runs.
- **Depends on:** nothing.

## WO-002: Art direction test and pipeline (done 2026-11-11: the owner locked the look, verified on the Deck)
- The shader kit: the toon ramp, ink outlines (inverted hull), wet surfaces, rain, fog. Painted surface shaders for
  architecture (world-space, no UVs).
- `tools/props.py` (the Blender cleaning script) and a Meshy batch helper that records task IDs.
- **The style test:**
  - Nim's turnaround concept in both outfits; Vesper's;
  - one Old Quarter street corner built in code with the shaders, at night, in rain;
  - three Meshy props;
  - a greybox Nim on the corner.
  - Screenshots and a Deck build.
- **Cost:** about 100 credits (concepts and three props). Say so first.
- **Acceptance:** the owner locks the look (ART_DIRECTION.md stops being a proposal). 60 fps on the Deck on the corner.
- **Depends on:** WO-001.

## WO-003: Nim's movement (done 2026-11-11; the owner moved on without feel changes)
- The core (DESIGN.md "The core"): run, jump, crouch-sneak, climb on marked surfaces, tail balance on wires and beams,
  pounce, ledge grab, and the camera (a spring arm that avoids walls, recentres on R3).
- **Starting feel (tune on the Deck):**
  - run 7 m/s;
  - a 2.2 m jump, apex at 0.35 s;
  - coyote 0.1 s, buffer 0.1 s;
  - climb 2.5 m/s;
  - balance walk 2 m/s;
  - pounce 9 m/s for 0.25 s.
- `walk_probe` and `climb_probe` on a test course: every gap and climb taken with real inputs.
- **Acceptance:** every move on the test course, by probe. Feels good on the Deck (the owner's call).
- **Depends on:** WO-001.

## WO-004: Combat and the Bind (built 2026-11-11; every acceptance check passes by probe)
- The strike combo (three hits, a stagger), the pounce's stagger, lock-on.
- **The Bind:** a staggered or unaware enemy is tied where he stands, and stays tied. Bound enemies persist across
  checkpoints and saves, per world.
- `EnemyBase`: patrol, suspicion, chase, fight, search, give up. Stagger, knockdown, bound.
- Nim's health: a few hits, generous checkpoints, no lives.
- **People in trances** (`Entranced`): wander a loop, can't be targeted by strike or bind; break the device and they
  wake.
- **Acceptance:** a probe fights and binds three goons; strikes pass through an entranced person; a bound goon is
  still bound after a reload.
- **Depends on:** WO-003.

## WO-005: Stealth (built 2026-11-11; both acceptance runs pass by probe)
- Vision cones and hearing. **Light levels:** a light probe at Nim; shadows hide her, and a readout shows how lit she
  is.
- Lookouts that don't fight but raise an alarm (gulls, meerkats, herons, the magpie). Alarms bring the area's goons.
- **Recoverable detection:** spotted means a fight or chase; break line of sight and the area calms down over time.
- Takedown from behind. (Takedown from above is Vesper's world-1 lesson, built here, unlocked by a flag.)
- **Acceptance:** a probe crosses a guarded yard unseen; a second gets spotted, escapes, and the yard calms down.
- **Depends on:** WO-004.

## WO-006: Outfits, Composure and Commands (built 2026-11-11; all four acceptance probes pass)
- **Wardrobes:** an interactable that swaps Nim's outfit (meshes, moveset flags, walk cycle).
- **The Domme suit:** Composure meter. Running, climbing or fighting in sight drains it. A confident walk and good
  commands restore it. Empty means her cover's blown: the room turns hostile, and she can now fight.
- **Recovery:** break sight, change at a wardrobe, or Hold the Room (a stare-down; unlocked in world 4).
- **Crowds:** walking among guests in the suit hides her.
- **Commands:** Kneel (core), Fetch and Open (world 2), the signet's tier (world 6). LT targets, the D-pad picks the
  word, Y gives it. Each NPC has a tier; a command above it costs Composure and fails.
- **The fake trance** (the pendant, world 4): walk slowly, eyes half shut, and goons ignore her.
- **Acceptance:** probes for: a blend-in crossing of a crowded room; a blown cover recovered at a wardrobe; Kneel,
  Fetch and Open on staff; a fight refused in the suit until the cover's blown.
- **Depends on:** WO-004, WO-005.

## WO-007: Lessons and gear (built 2026-11-11; a probe for each lesson and each piece of gear passes)
- **Vesper's lessons** as unlock flags: takedown from above, Fetch and Open, ceiling crawl and headfirst descent,
  Hold the Room.
- **The gear:**
  - the crop (reach, switches, targets);
  - the Scold (freeze in range);
  - the rope (swing from anchors, pull, bind at range);
  - the pendant (wake at range, fake trance);
  - lures (thrown, buzz, draw guards);
  - the signet (command tier).
- The rope is a pendulum: catch keeps speed along the arc, a jump off is a full jump plus the swing (a Nine Lives
  lesson: a slack rope stops swings dead in 3D).
- **Acceptance:** each lesson and each piece of gear has a probe on the test course.
- **Depends on:** WO-005, WO-006.

## WO-008: Worlds, collectibles and saving (built 2026-11-11; the probe world passes all three acceptance checks)
- `World` base: building helpers, arrivals, checkpoints, zones, wardrobes, fast travel points, distance culling.
- **Collectibles:** Keys (10 per world, 10 in the hub), contraband (100 per world), five entranced people per world
  (all five pay a Key), and the Coalition's collection tin per world (pays a hub Key).
- **Ranks:** cumulative Keys, never spent, open worlds. Thresholds: proposal 1, 6, 14, 22, 32, 42, and 58 for City
  Hall, tuned at WO-014.
- Bosses, the set piece and every Key as data, per world.
- **Save:** autosave to `user://vesper.json` on every change; three slots; bound goons and opened shortcuts persist.
- The pause screen: per-world tallies, Banjo style (Keys, contraband, people woken, tin), resume, last wardrobe,
  return to the club, settings, quit.
- **Acceptance:** a probe world with every collectible type; ranks open a door; a save reloads everything.
- **Depends on:** WO-004.

## WO-009: Dialogue, cutscenes and writing (built 2026-11-11; a writer's conversation runs without code, and the lint passes)
- A dialogue system with conditions and choices (port Nine Lives' parser and runner if it fits), pauses the world,
  pad-first, with guards against held buttons and fast-forwarding through a talk.
- A light cutscene sequencer: camera shots, character moves, lines, a newspaper or radio card.
- **Writing:** a voice sheet per character (Vesper: warm, exact, never mocking, never hurries; Grizelda: short; Silke:
  nearly silent; Dash: brash; Rivet: dry; Lull: velvet; Augusta: formal; Bastion: one word). A lint that flags any
  unmarked line by Vesper or Swyne, and any line using the banned words (§0.2).
- **Acceptance:** a writer adds a conversation without code; the lint passes.
- **Depends on:** WO-001.

## WO-010: UI and HUD (built 2026-11-11; every screen by pad, keys and mouse in ui_probe, and ui_shots of each)
- Title, menus, settings (remap, camera speed and invert, subtitles, motion and flash options), the content card.
- HUD: health, the light readout, Composure (suit only), the current gear, collectible pop-ups, captions.
- A world's arrival card. The newspaper card after each world.
- **Acceptance:** every screen works on pad, keys and mouse; a UI screenshot probe.
- **Depends on:** WO-006, WO-008.

---

## Art
**Owner, 2026-11-11:** every character moves to Kiara's soft-sculpt cartoon (ART_DIRECTION §1). Every character goes
through ART_DIRECTION's "Concepts":
- an anchor turnaround first;
- other outfits by image-to-image from it;
- the review (heads, adult signals, same-character, silhouettes) and the owner's approval, before any 3D.
**The first art step is the concepts for Nim's two outfits and Vesper's suit, shown to the owner before any 3D or
any other cast member.**

## WO-011: Nim (restarted 2026-11-11 for the cartoon restyle)
- **Concepts first:**
  - her anchor turnaround and her second outfit from it;
  - about 4.7 heads, curves kept, big lidded eyes with liner, a short muzzle;
  - flat cloud markings, simple gear.
- The hero pipeline (ART_DIRECTION.md), already built in `tools/nim_build.py` and `tools/nim_poses.py`:
  - Meshy source, remesh, bake (flat colour);
  - one rig per outfit with identical bones;
  - the tail and the face keys.
  - **Re-measure for the cartoon proportions:** the landmark fractions, the face constants, the tail tip, and the
    clips' limb offsets.
- **Clips:** idle (garb, suit), prowl, strut, run, jump, fall, land, climb (up, side, ledge), balance walk, ceiling
  crawl, headfirst descent, pounce, strike ×3, bind, takedown, swing, command (one per word), Hold the Room, fake
  trance, hurt, knockdown, change. All 31 are authored, and are rescaled for the new limbs.
  - **Plus `mask_on` / `mask_off`:** her hand clicks the velvet muzzle into place, or releases it. The muzzle is a
    separate mesh on the head bone, so it can be shown and hidden (DESIGN.md, "Her velvet muzzle").
- **Before spending on the 3D (owner, 2026-11-11):**
  - **The body's Meshy source is the unmasked garb concept.** The muzzle, eye mask and grille are their own mesh,
    built separately: preferably a Blender-scripted shell fitted to her snout (ART_DIRECTION, hero pipeline step 5).
  - **Hands with readable, separate fingers.** She climbs, grabs and binds.
    - **Meshy's own hands are rigged finger by finger** (owner, 2026-11-11, "option 1").
      - A scripted replacement hand was tried and rejected: it looked nothing like the rest of the mesh.
      - The sculpt has shallow grooves between the fingers (garb: four and a thumb; suit: three and a thumb).
      - `nim_build.py -- fingers` finds each claw tip on the mesh, runs a bone from the knuckle to the tip, and moves
        each finger's weight onto its bone across the knuckle.
  - **Strong brow keys:** narrowed, raised, one up. Masked, they're her whole range. `nim_build.py`'s face stage
    has them.
- **The Godot side:** a model driver (`player/nim_model.gd`) that replaces the capsule, picks clips from her state,
  swaps outfits, and blinks.
- **Cost:**
  - 88 spent on the superseded look (70 for the models, 18 for the first restyle concepts).
  - The restart is about 27 for concepts (three turnarounds) plus 70 for the two models.
- **Acceptance:**
  - the owner approves the concepts, then her in both outfits;
  - every clip plays in the test room;
  - within budget, at 60 fps on the Deck.
- **Depends on:** WO-002 (world look), WO-003.

## WO-012: The cast
- **Characters:**
  - Vesper (both outfits, and her whip for City Hall). Her suit concept comes first, with Nim's.
    - **Her v14 suit concept predates the owner's later rule** (more endowed than Nim, with exposed cleavage in
      the Domme suit). It's high-collared, so it needs one more edit before her 3D: an open, plunging neckline and
      a fuller bust (9 credits, quote first).
  - The seven sisters, two outfits each.
  - Councillor Swyne.
- **All in the cartoon style,** at the heights and shapes in ART_DIRECTION §1's silhouette table.
- **Concepts:** an anchor per character, the second outfit from it.
- **Masks (owner, 2026-11-11):** one personal mask per sister (ART_DIRECTION §1, "The Claw's masks").
  - **First:** one concept lineup of the seven masked heads, before any individual turnaround.
  - Then each mask is its own mesh, fitted like Nim's.
  - Vesper has none.
- **Concepts: done and approved by the owner** (2026-11-11; 387 credits, list in HANDOFF).
  - 3D quote: 16 sister bodies and Swyne at 35 each (595), and 7 masks at 44 (308), about 903 in all.
- **Auto-rig test first:** the first model tests Meshy's humanoid auto-rig on the big-headed proportions before
  batching the rest.
- **3D: built** (2026-11-11; 720 for the bodies, 326 for the masks; HANDOFF has the details).
  - `tools/cast_build.py` keeps Meshy's rig and weights and adds the rest: tail and ear bones, a decimate to
    60k, 2K textures, idle and talk clips beside Meshy's walk and run, and each garb's fitted mask.
  - The game shows them through `core/cast_model.gd` (CastModel). Talker and LessonGiver use it whenever the
    GLB exists; `tools/cast_probe.gd` checks every GLB.
  - **Still open:** Bastion's garb came out of Meshy with no tail, and without her rosettes. Faces have no blink
    or brow keys yet. The paint step is still to do: Vesper's sleeves and Bastion's rosettes.
- **Cost:** about 1,000 credits. Batch by batch, with the owner's yes.
- **Acceptance:**
  - the owner approves each concept before modelling;
  - each character's outfits read as one character;
  - silhouettes pass the shadow test at the new proportions (ART_DIRECTION §1).
- **Depends on:** WO-011's approved concepts, which set the style bar.

## WO-013: Enemies and bosses
- **All in the cartoon style:**
  - goons blocky and comic, 4–4.5 heads, one uniform per species;
  - each boss on one exaggerated shape (ART_DIRECTION §1).
- Goons: weasels, badgers, bulldogs, rats, sheep, moles, goats, Swyne's footmen. Lookouts: gulls, meerkats,
  cormorants, herons, the magpie. Guard dogs.
- Bosses: Laffer (hyena), Gander (goose), Tusk (walrus), Dr. Strix (owl), Grubb (mole) and the Decency Engine,
  Tupping (ram).
- **Concepts:** one anchor per species; variants are tints.
- **Owner's decisions (2026-11-12):**
  - **Batching:** the Pier first, end to end (weasel goon, badger bouncer, gull lookout, Laffer, stoat courier).
    It feeds WO-014 and tests the auto-rig on a blocky goon and a bird.
  - **Guard dogs:** upright Doberman guards, anthro like everyone else, on the goon pipeline.
  - **Stoats added:** one anchor. It's the Pier's courier; the Docks' customs uniform is a variant.
  - **The Decency Engine:** a Meshy model, tidied in Blender if needed.
- **Pipeline:**
  - **Concepts:** nano-banana-pro image-to-image, multi-view. The style reference is Swyne's front, and each prompt
    leads with the build.
  - **3D:** multi-image (35), remesh (5), auto-rig (5).
  - **Fighters** also get four Meshy library clips (3 each): Combat Idle 89, Right Jab from Guard 192, Hit Reaction
    178, Knock Down 187. Bound, kneel and look-around are scripted.
- **Cost:** about 1,290 for the full roster (20 characters).
- **Acceptance:** owner approves concepts; each enemy in a test scene.
- **Depends on:** WO-011's approved concepts (the style bar).

---

## The game

## WO-014: The vertical slice: the prologue, the club, the Pier (stop and playtest)
- The prologue in the Velvet Claw (the toys turn up in the dungeon), the club and the first Old Quarter streets, and
  the Pier complete (worlds/01_PIER.md): every Key, the set piece, Laffer.
- Art-complete: props, dressing, lighting, sound placeholders.
- `pier_probe` (every climb and swing), `pier_flow` (every Key and the boss with real inputs).
- **Stop.** The owner plays it on the Deck. The slice questions:
  - Do covert and blend-in both feel good, and different?
  - Is the camera trustworthy?
  - Is Vesper the mentor we want?
- **Depends on:** WO-003 to WO-013.
- **Build order (proposal, 2026-11-12; started on the owner's "proceed to WO-014"):**
  1. **The Pier's layout** (done 2026-11-12; HANDOFF): all six areas built in code with the painted shaders, at
     night in the rain.
     - Everything placed: traversal, wardrobes, shortcuts, checkpoints, zones, fast travel, goons, gulls,
       bouncers, the five sleepers, 100 contraband and the tin.
     - `pier_probe` walks the routes between the areas.
  2. **The Keys** (done 2026-11-12; HANDOFF): each Key's little script and its lines (Dash's race, the landing crew, the gallery, the high
     striker, Madame Pearl, the safe, the prize counter, the wheel). Vesper's lesson under the pier.
  3. **The set piece** (done 2026-11-12; HANDOFF): the Big Dipper chase.
  4. **The boss** (done 2026-11-12; HANDOFF): Laffer's three phases.
  5. **The prologue, the club and the first Old Quarter streets** (done 2026-11-12; HANDOFF; sized to DESIGN.md
     "Sizing"): a door from the hub to the Pier.
  6. **Art** (done 2026-11-12; HANDOFF. The free part: the gulls, the clerk, the mallet goon and the barker wear
     WO-013's models. The Meshy part, 462 credits: Madame Pearl, four civilians and eight props, in the game):
     - Meshy props and the new people: Madame Pearl, the clerk, the prize winners, the crowd. **Quote first.**
     - Lighting, neon, sound placeholders.
  7. **`pier_flow`** (built 2026-11-12, 0 failures; HANDOFF): every Key and the boss with real inputs. Then a Deck push, and **stop** for the owner's
     playtest.

## WO-014b: The Velvet Claw's house (started 2026-11-12, during the WO-014 playtest; HANDOFF)
- **Status:**
  - **Built:** steps 1–6. Silke and Augusta's scenes are in, Silke's both ways; Augusta's Domme is probed, and her
    Switch is built but not probed.
  - **The cross** (2026-11-12, HANDOFF): a session on the vaults' cross, either way round, with any client or any
    sister. The form covers gag, blindfold, collar, cuffs and gentle or firm; then a tray of tools and aftercare.
    Client sessions now go there, and every sister has it both ways. Probed in `club_probe`.
  - **Deck review 3** (2026-11-13, HANDOFF):
    - Every scene is redrawn on one UI kit (`SceneHud`) and staged on the bodies (`RigGear`): tools in hand, rope on
      the frame, faults on the body.
    - The sisters wear their suits in the club, and swimwear only as the sub.
    - The Quiet Room is twice the size, with a seat each.
    - No checkpoints inside the club, and walks go through doorways.
    - Masks stay on in conversation.
  - **2026-11-13 (HANDOFF):**
    - All six sisters now have their own scenes, both ways round (Grizelda, Lull, Dash and Rivet are new).
    - Pip's and Mr Smith's four-visit stories are in.
    - The parlour is furnished from boxes.
  - **Deck review 4 (2026-11-13, HANDOFF):**
    - Nim's two-piece is built; she wears it whenever she's the sub.
    - All six parlour props are in.
    - The Backroom board is built, alongside the gates.
    - Aftercare sits on the nook's chaise, and the sister lingers.
    - The Coalition rename.
  - **Done, bar the owner's notes.**
DESIGN.md "The Velvet Claw's house". The club grows into a place to wander between worlds. Build order:
1. **The layout:** the Dungeon hall and six sisters' rooms, and the Backroom behind Rivet's shelf.
   - Sized to "Sizing": everything within about 30 s of the door. `zfight_check` clean, `hub_probe` routes.
   - Rivet's bench moves to her workshop.
2. **The ambient sessions:** each sister with a client, on a loop.
   - **The dress code** (DESIGN): clients in swimwear downstairs and in robes at the door; Nim in her black
     two-piece.
   - **Art:** new client bodies in swimwear (Meshy, about 54 each: quote first), robes on hooks, and Nim's third
     outfit. A few props (a rope frame, a boot-black stool, a reading chair).
   - **Meshy:** quote first, maybe 3–5 props (about 24 each).
3. **The Backroom:** the map table, the pinboard, Vesper's desk. Briefings move here.
4. **A living dungeon:** clients filter in (a robe at the door), take a free sister's room for a session, go to
   Lull's room for aftercare, and leave. A few fixed regulars, plus a rotating crowd.
5. **The client mini-game** (the comic regular to start), and its hub Rose.
   - The safeword rule comes first and is probed: Nim must stop on "red".
6. **Switch and Domme, opt-in, with any sister** (owner): both ways per sister, in character.
   - Start with two: Silke (rope) and Augusta (posture), each with a check-in and aftercare.
   - The first one pays the hub Rose; the rest pay small perks and the sister's bond.
7. **A Deck push, and stop** for the owner's notes.
- **Writing:** every line in these scenes is marked for owner review. Consent and aftercare are on screen; nothing
  is explicit.
- **Answered (DESIGN):** the clients filter in and out; Switch and Domme are opt-in with any sister; the Backroom
  board goes alongside the gates (built).
8. **Richer scenes** (DESIGN, "Richer scenes"; Deck review 5): three acts, Headspace and Connection, gags.
   - **Built (2026-11-13):** Silke and Augusta, both ways (`core/rich_scene.gd`); gags on the cross; the cuddle
     aftercare.
   - **Built (2026-11-13):** Grizelda, Lull, Dash and Rivet, both ways (`core/rich_scenes_later.gd`). Every sister's
     scene is now rich.

## WO-015: Primrose Close (started 2026-11-13: "start Primrose Close"; HANDOFF)
- worlds/02_PRIMROSE_CLOSE.md. The demonstration party set piece, Gander.
- **Depends on:** WO-014 and its playtest notes.
- **Build order (proposal, 2026-11-13, the Pier's):**
  1. **The layout** (`levels/primrose/primrose.gd`): all six areas in code, at night.
     - Everything placed: traversal (fences and washing lines as beams, the steeple), wardrobes, shortcuts,
       checkpoints, zones, fast travel, bulldog goons, meerkat lookouts, the five sleepers, 100 contraband, the tin.
     - The gate from Primrose Lane, and the way back. `primrose_probe` walks the routes.
  2. **The Keys** (built 2026-11-13; HANDOFF): each Key's script and its lines, and Vesper's lesson (Fetch and Open
     at the Watch hut). Grizelda's test pays the Scold. The curtain twitchers. `primrose_keys_probe` plays them.
  3. **The set piece** (built 2026-11-13; HANDOFF): the demonstration party (host it in the suit; swap the toys
     unseen; Composure is the meter). `levels/primrose/keys/party.gd`, played in `primrose_keys_probe`.
  4. **The boss** (built 2026-11-13; HANDOFF): Mrs. Marjorie Gander's three phases (the garden party, the sprinklers,
     the tantrum and the Scold). `levels/primrose/keys/gander.gd`, played in `primrose_boss_probe`.
  5. **Art** (built 2026-11-13; HANDOFF): 25 Meshy props for the Close, the Hall, the allotments, the party and
     Gander's garden, and the Velvet Claw's lounge and door (600 credits). The people already had bodies (WO-013).
  6. **`primrose_flow`** (built 2026-11-13; HANDOFF): every Key and the boss with real inputs, from the hub with the
     Pier done, and home to Grizelda's homecoming. Then a Deck push, and stop for the owner.

## WO-016: The Docks
- worlds/03_DOCKS.md. The storm set piece, Tusk.

## WO-017: The Retreat
- worlds/04_RETREAT.md. The session set piece, Vesper's scene, Dr. Strix. Nim's file.

## WO-018: The Decency Press
- worlds/05_DECENCY_PRESS.md. The line run backwards, Grubb. The radio hearing.

## WO-019: The Decency Ball
- worlds/06_DECENCY_BALL.md. The swap set piece (the whole crew on screen), Tupping. The raid.

## WO-020: The finale
- worlds/07_CITY_HALL.md. The final exam in the raided club, City Hall, Swyne, Vesper's death, the club after, the
  hub's final state, credits. The coda only if the owner approves it.
- **Acceptance:** the game can be finished start to end by a probe with real inputs.

## WO-021: The hub through the story
- The Old Quarter's states: the start, Swyne's posters going up world by world, the raid, and after. Each
  world's tin pays a hub Key here. Hub secrets (10 Keys).

## WO-022: Audio
- Music per world (noir jazz at the base: a double bass, a brushed kit, a smoky horn; each world adds its colour:
  the Pier's organ, the suburbs' easy listening, the docks' foghorn, the spa's chimes, the press's machines, the Ball's
  orchestra, City Hall's bells).
- Sounds: footsteps by surface and outfit, the crop, the rope, the Scold, the lure's buzz, the alarms, the
  receivers' hum.
- Generated locally (Stable Audio 3, as Nine Lives did) and auditioned on a page for the owner to pick.

## WO-023: Polish and release
- Juice, accessibility, Deck performance in every world, export, store assets (nothing explicit in screenshots),
  content notes, age-rating checklist.

---

## Appendix: a Meshy request
```
ASSET:      sister_silke_garb
KIND:       character, supporting cast
CONCEPT:    nano-banana-pro, turnaround, ART_DIRECTION §1 (velvet noir, painted, ~7 heads)
PROMPT:     tall lean adult snow leopard woman, curvy, fully covered, grey wrapped night garb,
            rope coiled bandolier-style, matte, red accent at the collar, painted fur, neutral pose
MODEL:      meshy-7.1 + texture, remesh 60k, humanoid rig, clips: idle, walk, talk
COST:       about 60 credits (owner's yes first)
TASK IDS:   .wip/meshy/cast.json
EXPORT:     assets/cast/silke_garb.glb
CHECK:      silhouette test; budget; content lines
```
