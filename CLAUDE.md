# Vesper's Kinky Kapers (working title): notes for Claude

A 3D, Banjo-style hub action platformer, adults only. A spin-off from KIARA: Nine Lives, Zero Dignity
(`C:/dev/nine-lives`): set while Mistress Vesper is alive, running a vigilante crew. **Vesper is the mentor, not the
player character.** The player is a new character she trains.

Nothing is built yet. Start with [docs/STUDY.md](docs/STUDY.md): what Banjo-Kazooie, Banjo-Tooie and Conker's Bad Fur
Day teach, the decisions so far, and the open questions. Then [docs/DESIGN.md](docs/DESIGN.md) (premise, cast,
moves, the worlds) and the world briefs in `docs/worlds/`. Keep DESIGN.md current: mark what the owner decided and
what's still a proposal.

**Read [docs/HANDOFF.md](docs/HANDOFF.md) first. After every task, update it.** The build plan is
[docs/WORK_ORDERS.md](docs/WORK_ORDERS.md); the look and pipeline are [docs/ART_DIRECTION.md](docs/ART_DIRECTION.md).

## Quick facts
- Godot 4.7.1 (.NET editor build, GDScript only): `C:/dev/tools/godot/Godot_v4.7.1-stable_mono_win64_console.exe`.
- Git LFS for `.glb` and `.png` under `assets/`. Sources live in `.wip/` (gitignored; Godot skips dot-folders).
- MCPs: Blender, Meshy (credits shared with Nine Lives: quote a cost and wait for a yes), GIMP, Cascadeur.
- **"Push it" means copy the build to the Steam Deck** (`bash tools/deploy_deck.sh`, to `~/Games/Vesper/`), never git.
- Nine Lives (`C:/dev/nine-lives`, see its `3d/docs/HANDOFF.md`) solved many 3D problems this game will meet:
  physics interpolation, the follow camera, probes with real inputs, Meshy cleaning, rigging Meshy meshes, z-fighting.
  Port its code and lessons where they fit. **Never its art.**

## Rules from the owner
- **The owner handles all git commits and pushes. Don't commit.**
- **Study Rare's games for structure only.** Never recreate their levels, characters, jokes, music or look.
- **Never reuse another game's assets,** Nine Lives included.
- **Gamepad is first-class.** Every screen works on a pad as well as keyboard and mouse.
- Write files with Write/Edit, not bash heredocs.

## Content lines (from Nine Lives, binding here)
- Every character is an upright, anthropomorphic, unmistakably grown adult. No age jokes, no child-coded designs.
- Crude writing is welcome. Shipped assets stay suggestive: latex, leather, rope, collars, implication. **No on-screen
  sex acts, nudity or genitalia in anything an agent authors.**
- Jokes target criminals, hypocrites and the hero's dignity, never the kink community or what they're into.
- Vesper is tall, calm, competent, warm and exact, never mocking: "the one person who asks". Mark her lines
  `# OWNER REVIEW`.
