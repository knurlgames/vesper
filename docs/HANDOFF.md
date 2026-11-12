# Handoff (current state)

Run it: `godot --path .` (the 4.7.1 console build is `C:/dev/tools/godot/Godot_v4.7.1-stable_mono_win64_console.exe`).
It opens on the **title screen**. "Saves" picks a slot, and a game starts on the movement test course
(`Game.START_SCENE`) until the prologue exists. In a level, Back / Tab cycles course > street corner (the hub's
stand-in) > test room > probe world.
"Push it": `bash tools/deploy_deck.sh` exports `Vesper.x86_64` (about 77 MB) to `~/Games/Vesper/` on the Deck. Add it
to Steam once by hand (Desktop Mode, right-click > Add to Steam); later copies replace it in place.

**Probes** (all `godot --headless --fixed-fps 60 --path . -s tools/<name>.gd`): `ui_probe`, `dialogue_probe`,
`world_probe`, `gear_probe`, `social_probe`, `stealth_probe`, `combat_probe`, `walk_probe`, `climb_probe`,
`move_probe`, `gate_probe`, `corner_probe`. All pass with clean logs.
- **The writing lint:** `godot --headless --path . -s tools/dialogue_lint.gd` (passes).
- Windowed: `ui_shots -- <dir>` (every screen), `world_shots`, `pause_shot`, `dialogue_shot`.
- **The headless window is 64x64:** a probe that lays out or clicks UI must set `root.size = Vector2i(1280, 800)`
  first (ui_probe does).
- **Full-screen controls:** use `set_anchors_and_offsets_preset(PRESET_FULL_RECT)`. `set_anchors_preset` alone keeps
  the old offsets, and the control ends up the size of its contents.
**Check the log for `SCRIPT ERROR` as well as the failure count:** a probe whose scene fails to compile can still
print "0 failures".
- A probe script compiles before autoloads exist. Anything it reaches by `class_name` (`Nim`, `NimCombat`, `Enemy`,
  `Beam`, `Look`...) must not name an autoload: read `Input` directly, and reach `Game` with
  `get_node_or_null(^"/root/Game")`.
- `PROBE_TRACE=1` makes `combat_probe` print the fight frame by frame.

## 2026-11-11: WO-012 the cast in the game: all 17 bodies built, masked and exported
- **Owner: "Proceed with the Blender work."** No credits were spent.
- **The pipeline is `tools/cast_build.py`:**
  `blender -b --python tools/cast_build.py -- <stage> [body ...]` (no bodies means all 17).
  - **Stages, in order:** `prep`, `chains`, `clips`, `mask` (garbs), `seams`, `export`.
  - **Helpers:** `measure` / `measure_mask` render gridded headshots for reading the `FACE` and `MASK_FIT`
    numbers.
  - **Speed:** about a minute per body per stage, mostly check renders. The work files are
    `.wip/cast/build/<body>.blend`, and every stage leaves renders there:
    - `prep_*`;
    - `chains_*` (test pose);
    - `clips_*`;
    - `mask_*_{front,side,three}`.
  - **The approach and its lessons** are in ART_DIRECTION, "The supporting cast", "As built":
    - weld first;
    - tails stop at the hips;
    - masks are sized by face width;
    - no outline on masks;
    - floor discs only where flagged.
- **The output:** `assets/characters/<who>/<who>_<outfit>.glb` (Swyne: `swyne/swyne.glb`), 9–20 MB each.
  - **Triangles:** 60k bodies, and garbs 75k with the mask (masks are 15k), inside the 80k budget.
  - **Clips:** idle, talk, walk, run.
  - **Bones:** Meshy's 24, plus a tail chain (3–8 bones) and two ears.
  - **The mask:** `<body>_Mask` on the Head bone.
- **Godot: `core/cast_model.gd` (CastModel).** It loads the GLB and dresses it in the toon look.
  - **Clips:** idle by default, `talk` while Dialogue shows that speaker's line (new
    `Dialogue.current_speaker()`), walk or run by `speed`.
  - **The mask** is worn in the garb and off in conversation.
  - **Talker** gained `who` / `outfit`, and **LessonGiver** gained `outfit` (default suit). Each shows the
    model in place of the greybox capsule when the GLB exists; the collision stays.
  - **On the course:** Vesper and Dash now stand as their models.
- **Checks:**
  - **`tools/cast_probe.gd`** (new, passes): every GLB has its clips, chains, mask node and budget, and CastModel
    loads and plays it.
  - **All 12 probes and the dialogue lint still pass.**
  - **`tools/cast_shots.gd -- <dir> [body ...]`** takes in-game shots (windowed). The contact sheets are
    `.wip/cast/shots/sheet_garb_faces.png` and `sheet_suits.png`.
- **Known gaps:**
  - **Bastion's garb has no tail:** Meshy's model has none (and no rosettes). Fixing it means a new model or a
    sculpted tail.
  - **Faces have no blink or brow keys yet** (Nim's `face` stage could be ported).
  - **The talk gesture is generic:** one right-hand beat for everyone.
  - **Paint step not done:** Vesper's sleeves, Bastion's rosettes, the clouds on markings.
  - **Silke's veil** still has faint shading at its edge (not visible at game distance).
  - **Not yet pushed to the Deck,** and the Deck frame rate with several cast models is unmeasured.

## 2026-11-11: WO-012 the sisters' masks: all seven modelled
- **Owner: "Proceed on the masks."** Each mask went through two steps, the same as Nim's:
  - a mask-only concept, made from her approved masked front with "a product shot of only the mask, no head",
    in front, side and back views (nano-banana-pro, 9);
  - multi-image-to-3D (meshy-7.1 plus meshy-7, 4K, Ultra, 35).
- **Two concept redos** (owner approved 18 more):
  - **Grizelda's first concept drew her whole head inside the mask,** plus a hose and a head cage. The fix used two
    references: Lull's finished mask shot (for the empty product-shot format) and Grizelda's masked front (for the
    design).
  - **Silke's veil showed a faint ghostly face behind the mesh,** which reads as horror, and stood on a plinth. The
    fix was an image-to-image redo that backs the veil with plain black.
- **Cost:** 326 credits. **The balance is now 6,012.** Tasks are in `.wip/meshy/wo012_mask_models.json`.
- **The files:**
  - concepts: `.wip/concepts/masks/<sister>_mask_*.png` (`_v2_*` for Silke and Grizelda); contact sheets
    `sheet_{a,b,c}.png`;
  - models: `.wip/cast/raw/<sister>_mask.glb`, with `_base_color.png`;
  - renders: `.wip/cast/mask3d_<sister>_{front,side,back}.png` and `mask3d_sheet_{a,b}.png`.
- **All seven are clean and on-concept:**
  - Augusta: the masquerade mask with mane filigree and a ribbon tie;
  - Silke: the featureless band, braided rim and mesh veil;
  - Dash: the visor-goggle with red tear lines;
  - Rivet: the overbuilt gas mask with brass canisters;
  - Lull: the lower-face shell with the brass spiral;
  - Grizelda: the muzzle shell with the brass trumpet, empty and closed;
  - Bastion: the riveted armoured half mask.
- **For the fit (free; `fit_meshy_mask` is the template):**
  - **Meshy painted the brass cream on every mask,** as it did on Nim's: run `_brass_texture` to recolour it.
  - **Silke's mask is 3.7M tris** (Rivet's 1.2M, the rest 0.4M to 0.9M): decimate them all to about 60k first,
    as with Nim's.
  - Silke's veil still has a little ghost shading in its side view. Check it at game distance and paint it out of
    the texture if it shows.
  - **Masks that open the face:** Lull and Grizelda (lower face only) and Augusta, Dash and Bastion (upper face
    only). The fit needs its eye or muzzle measurements from each body's `FACE`.
- **Next: the free Blender work for the whole cast:**
  - clean-up (Lull's floor disc);
  - tail and ear chains;
  - decimating to budget;
  - paint;
  - fitting the masks (rest pose!);
  - Godot integration.

## 2026-11-11: WO-012 cast 3D: all 17 bodies (16 plus the Augusta test) modelled, remeshed and rigged
- **Owner: "Proceed with the bodies."** Each body went through three steps:
  - multi-image-to-3D: meshy-7.1 plus meshy-7, 4K, Ultra 2k geometry, `image_enhancement` false (35 credits);
  - remesh to 150k triangles (5);
  - Meshy auto-rig (5).

  That's 45 a body. I ran four bodies at a time and checked each batch's walk before starting the next.
- **Cost:** 720 credits. **The balance is now 6,338.** The task ids, including every remesh and rig, are in
  `.wip/meshy/wo012_cast_3d.json`.
- **The files:**
  - in `.wip/cast/raw/`: `<char>_<outfit>_rigged.glb` and `_walk.glb` for every body. Swyne is just `swyne_*`.
  - Walk check sheets: `.wip/cast/walk_<name>.png` (4 frames, 3/4 view).
  - **The bodies:** vesper suit and garb; augusta suit and garb; silke suit and garb; dash suit and garb;
    rivet suit and garb; lull suit and garb; grizelda suit and garb; bastion suit and garb; swyne.
- **Rig heights (m):** Rivet 1.6, Lull 1.8, Grizelda 1.45, Bastion 1.85, Swyne 1.7. The earlier batches are in the
  transcript or the json. The height only sets the scale, so Godot can rescale.
- **Every body deforms cleanly through the walk.** They are on-concept and keep the big heads, cleavage,
  corsets, harnesses and cords.
- **Fixes for the Blender step (all free):**
  - **Lull, both outfits:** a white floor disc (the concept's ground shadow) is fused to her feet and skinned to
    them. Delete that loose part.
  - **Every rig has the 24-bone humanoid only:** no tail, ear or finger bones. Tails swing stiffly with the hips,
    and Silke's and Dash's drag through their legs. Add tail and ear chains with `nim_build`'s code.
  - Bastion's garb has no rosettes, and Vesper's garb sleeves need paint (the paint step, as planned).
- **Scratch tools:**
  - `scratchpad/rigtest.py` renders the walk sheets;
  - `scratchpad/fetch_rigs.sh name=rig_id ...` pulls the newest signed URLs from the session log and downloads
    them.

  They are session scratch. Move them into `tools/` if the next session needs them.
- **Next, waiting on the owner:**
  - the 7 mask models (about 308 credits; quote and wait for a yes);
  - then the free Blender work: clean-up, the tail and ear chains, decimating to budget, paint, the masks, and
    Godot integration.

## 2026-11-11: WO-012 cast concepts, batch 4: every cast concept now exists
- **Cost:** 63 credits (cast concepts total 315, about 7,175 left). Tasks in
  `.wip/meshy/wo012_cast_batch4.json`.
- **Dash: done.** From text, with "slender sprinter" first, she finally came out lean.
  - Garb (`dash_garb_v5_*`): racing straps over a sleeveless top, bare spotted arms.
  - Suit (`dash_suit_*`): latex, an open neckline, a narrow corset, heels; her bust is fuller in the suit.
  - Masked front (`dash_masked_front.png`): the visor-goggle with red tear lines.
  - Her garb's bust is modest. The 3D can use the suit's proportions, or fix it with a 9-credit edit.
- **Bastion: done, with a caveat.**
  - Garb (`bastion_garb_*`), suit (`bastion_suit_*`, leather with shoulder plates), masked front
    (`bastion_masked_front.png`, the riveted half mask).
  - She reads broad but **not "all shoulders":** her build is close to Augusta's. Same reference-copy problem as
    Dash. A from-text redo would fix it.
- **Swyne: done** (`swyne_*`): a pear-shaped boar in a cream three-piece suit with gilt buttons, a watch chain,
  a navy tie and a rosette pin. Smug and respectable; no red.
- **The full cast set** (all in `.wip/concepts/cast/` unless noted):

  | Character | Garb | Suit | Masked front |
  |---|---|---|---|
  | Vesper | `vesper_garb_*` (side view: bare shoulders, paint them later) | `vesper_suit_*` + `vesper_suit_side_fix` | none (no mask) |
  | Augusta | `augusta_garb_v2_*` | `augusta_suit_*` | `augusta_masked_front` |
  | Silke | `silke_garb_v4_*` + `silke_garb_side_fix` | `silke_suit_*` | `silke_masked_front` |
  | Dash | `dash_garb_v5_*` | `dash_suit_*` | `dash_masked_front` |
  | Rivet | `rivet_garb_*` | `rivet_suit_*` | `rivet_masked_front` |
  | Lull | `lull_garb_*` | `lull_suit_*` | `lull_masked_front` |
  | Grizelda | `grizelda_garb_*` | `grizelda_suit_*` | `grizelda_masked_front` |
  | Bastion | `bastion_garb_*` | `bastion_suit_*` | `bastion_masked_front` |
  | Swyne | `swyne_*` (one outfit) | | |

- **Fixes** (18 credits; cast concepts total 333, about 7,157 left):
  - **Dash:** `dash_garb_v6_*` has a fuller bust and is still lean. It replaces v5.
  - **Bastion:** `bastion_garb_v2_*` from text is a true wedge, all shoulders. But **every view is cropped**
    (the front at the hips, the side at the knees, the back at the thighs). It needs uncropped views before
    3D: the single-view trick, 9 each. Her suit and masked front are from the old, broader build; redo them
    from v2.
- **Bastion, finished** (54 more credits; cast concepts total 387, about 7,103 left):
  - Uncropping single views (27) partly failed: the front copied the old broad build back in.
  - **The owner chose a text-only redo** (27): `bastion_garb_v4_*`, a true full-body wedge.
    - She came out plain tan with **no rosettes:** paint them at the paint step.
  - `bastion_suit_v2_*` (leather, shoulder pieces, open neckline) and `bastion_masked_front_v2.png` (the half
    mask) both have the rosettes and the wedge.
  - **In the cast table, use the v4 garb, the v2 suit and the v2 masked front.**
- **The Augusta 3D test, step 1 done** (35 credits, about 7,068 left; `.wip/meshy/wo012_cast_3d.json`).
  - The model is `.wip/cast/raw/augusta_garb.glb`: 548k tris, clean and on-concept, with the harness, knot
    buckle, cord, knee pads and grey updo. Renders are `.wip/cast/raw_augusta_garb_*.png`.
  - **Remesh** (5; owner: "careful, Meshy's remesh can lose quality, but try anyway"). I went to 150k (154k
    tris) to keep detail, not the 80k budget. Renders (`remesh_augusta_garb_*.png`) are indistinguishable from
    the raw model. **Use 150k for the cast;** Blender decimates to budget later (that keeps the skin weights).
  - **Auto-rig** (5): `.wip/cast/raw/augusta_garb_rigged.glb`, plus `_walk.glb` and `_run.glb` (free clips).
    - It's a 24-bone humanoid: hips, three spine bones, neck, head; shoulder, arm, forearm and hand per side; leg,
      knee, foot and toe per side. **No tail, ear or finger bones.**
    - The walk and run (`rigtest_augusta_{walk,run}.png`) deform cleanly. The big head, broad body, harness and
      cord ride along with no tearing.
    - **The gap:** her tail is weighted to the hips, so it swings stiffly with them. The ears are rigid, and the
      hands move only at the wrist.
    - **The recommended fix:** add a tail chain (and ear bones) in Blender to each cast rig, with `nim_build`'s
      tail walk and surface-distance weights. This is the same code as Nim's, and free.
  - **Test total:** 45 credits, about 7,058 left.
- **Lesson for the bosses and goons (WO-013):** a reference image passes on its build. When the build matters,
  generate from text with the build first in the prompt, and only use references for style.
- **APPROVED by the owner: "The set is approved"** (2026-11-11). Every cast concept in the table above is final,
  with Bastion's v4 garb, v2 suit and v2 masked front.
  - Left for the paint step: Vesper's sleeves (her garb side view) and Bastion's garb rosettes.
- **Waiting on the owner:**
  - then the 3D quote: 15 sister bodies and Swyne (about 560), and 7 masks (about 308).

## 2026-11-11: WO-012 cast concepts, batch 3 (Dash retry, Lull, Grizelda)
- **Cost:** 63 credits (cast total 252, about 7,238 left). Tasks in `.wip/meshy/wo012_cast_batch3.json`.
- **Lull: done.**
  - Garb (`lull_garb_*`): slim and long-legged, with very tall ears.
  - Suit (`lull_suit_*`): latex with an open neckline, a crimson corset, a brass pendant, thigh boots.
  - Masked front (`lull_masked_front.png`): lower-face only, eyes bare, a still brass spiral.
- **Grizelda: done.**
  - Garb (`grizelda_garb_*`): short, round, stout, grumpy, clearly older.
  - Suit (`grizelda_suit_*`): leather with an open neckline, a corset, a riding crop.
  - Masked front (`grizelda_masked_front.png`): the horn on the muzzle shell. It also added a hose over her
    shoulder and changed her buckle; the 3D uses the unmasked garb anyway.
- **Dash: failed a third time** (`dash_garb_v4_*`): still Augusta's broad build.
  - Sending her old broad image as a second reference carried its build over.
  - **Next try:** text only, with "slender sprinter" first, the way Silke's trousers finally landed. Or accept
    a sturdier Dash. The owner decides.
- **Remaining:** Bastion (her garb, suit, mask) and Swyne (an anchor), plus Dash.

## 2026-11-11: WO-012 cast concepts, batch 2 (side fixes, Dash, Rivet)
- **Cost:** 72 credits (cast total 189, about 7,301 left). Tasks in `.wip/meshy/wo012_cast_batch2.json`.
- **Silke's side fix worked** (`silke_garb_side_fix.png`): the cartoon body, a large bust, trousers.
- **Vesper's garb side fix failed** (`vesper_garb_side_fix.png`): her shoulders are still bare and spotted.
  - The model reads her spots as a "sleeve".
  - A stronger edit, or painting the sleeves at the paint step, is left to the owner.
- **Rivet: done.**
  - Garb (`rivet_garb_*`): compact, huge tufted ears, a tool rig (wrench, ring, gauge), the cord.
  - Suit (`rivet_suit_*`): latex, an open neckline, a crimson corset with brass buckles.
  - Masked front (`rivet_masked_front.png`): the overbuilt gas mask with brass canisters.
- **Dash: held.**
  - Her anchor (`dash_garb_*`) is a cheetah in the uniform with bare spotted arms, but her build is as broad as
    Augusta's. The silhouette rule wants her lean and wiry.
  - Two slim-down edits came back unchanged (`dash_garb_v2_*`, `dash_garb_v3_*`).
  - **Lesson:** an anchor made from a reference copies the reference's build. Pick a reference with the
    target's build, or none.
  - Her suit and mask wait on a working anchor.
- **Mistake:** I wrote `wo012_cast_batch2.json` with a bash heredoc, against the CLAUDE.md rule. Its content is
  right.

## 2026-11-11: WO-012 cast concepts, batch 1 (Vesper, Augusta, Silke)
- **The plan** (owner-approved batching; 216 for the whole cast's concepts, around 300 with fixes). Per sister:
  - an unmasked garb anchor (the 3D body source);
  - the suit from it;
  - a masked garb front (single view).
  Vesper gets two outfits and no mask; Swyne one anchor.
- **Batch 1:** 81 credits so far, about 7,409 left. Tasks in `.wip/meshy/wo012_cast_batch1.json`; images in
  `.wip/concepts/cast/`.
  - **Vesper:**
    - **Suit:** `vesper_suit_*` plus `vesper_suit_side_fix.png` (the side kept the old collar). Open plunging
      neckline, fuller bust, heels.
    - **Garb:** `vesper_garb_*`. Closed and covert, with a harness, the knot buckle, the cord and flat boots. Her
      side view has bare spotted shoulders while her front has sleeves; a side fix is pending.
  - **Augusta:**
    - **Garb:** v1 was rejected (two backs, sleeveless, slim). `augusta_garb_v2_*` is broad, with a very large
      bust, sleeves, the cord and a formal harness. All views agree.
    - **Suit:** `augusta_suit_*`, black leather, an open neckline, a crimson corset, heels.
    - **Masked front:** `augusta_masked_front.png`, her masquerade mask with mane filigree.
    - **Done.**
  - **Silke:**
    - **v1/v2:** a leotard with bare legs; an edit couldn't add trousers.
    - **v3:** regenerated from text with the trousers stated first. The trousers landed, but she drifted
      realistic (owner: "she lost the Chibi look").
    - **v4** (`silke_garb_v4_*`): v3's outfit with v2's cartoon head and style, and a large bust.
      - The front is right.
      - The side view kept v3's realistic body: a single side fix is pending.
      - The trousers picked up printed rosettes: clean them at the paint step.
    - **Suit:** `silke_suit_*`, latex with an open neckline, a narrow crimson corset, rope bindings on her arms
      and thighs, heels. All views agree.
    - **Masked front:** `silke_masked_front.png`, the featureless mask with a braided edge and a mesh veil.
- **Batch 1 total: 117 credits, about 7,373 left.**
  - **Pending fixes:** Silke's garb side (9) and Vesper's garb side (9).
  - **Lesson:** text-to-image anchors keep ignoring outfit details (sleeves, trouser legs) and drift toward
    realism. Anchor new sisters with the approved Nim or Augusta concept as a style reference (image-to-image),
    not from text alone.

## 2026-11-11: the Rope's masks (WO-012 groundwork)
- **The owner's brief:** one personal mask per sister, all on a shared style. Vesper goes unmasked.
  - The rule is in ART_DIRECTION §1, "The Rope's masks" (each sister identifiable by her mask alone).
  - The lore is in DESIGN.md, "The masks": goon nicknames (proposals), wanted posters, Vesper unmasked at City
    Hall.
- **The lineup:** 9 credits; `.wip/concepts/masks/lineup_v1.png`, tasks in `.wip/meshy/wo012_masks.json`.
  - Six read well.
  - **Grizelda's broke the never-a-gag rule,** and Bastion's read as a helmet. Both are fixed by single-head
    edits (18 credits; `grizelda_v2.png`, `bastion_v2.png`).
    - Grizelda: the horn is bolted to a muzzle shell, her mouth is closed inside, and no strap crosses it.
    - Bastion: a riveted half mask on the upper face only.
  - **The red piping pass came out partial** (9 credits, `silke_lull_v2.png`). Asked for two heads, the model
    redrew the whole lineup.
    - **Lull got her piping:** take her from this image.
    - Silke got it only on her veil's hem.
    - Augusta lost her filigree and Grizelda reverted, so ignore those in this image.
  - **The reference set:** Augusta, Silke, Dash and Rivet from `lineup_v1.png`; Lull from `silke_lull_v2.png`;
    Grizelda and Bastion from their `_v2` images.
  - **Lesson:** ask for one head per call. Two-head requests come back as the whole lineup.
  - Red piping and the knot show on only some masks.
  - Waiting on the owner's review.

## 2026-11-11: WO-011 STOPPED: the whole cast moves to Kiara's cartoon style
- **The ruling:** "The whole cast reads too realistic." Every character moves to Nine Lives' soft-sculpt cartoon:
  Nim, Vesper, the crew, Swyne, the goons and the bosses. ART_DIRECTION.md now says:
  - **§1:**
    - about 4.5–5 heads (heights per character, floor 4), every character unmistakably adult, the Rope's curves kept;
    - big eyes with lids and liner, short simplified muzzles;
    - clay-smooth vinyl-matte forms, flat markings, simpler gear;
    - the silhouette rule as a table at the new heights.
  - **What stays from velvet noir:** the palette, the velvet-red rule, the ink, the night lighting, the painted world
    and the shader kit.
  - **A new "Concepts" pipeline:** one anchor per character; other outfits by image-to-image from it.
- **The WO-002 character concepts are superseded.** They were moved to `.wip/concepts/superseded_wo002/` and
  `.wip/style_test/concepts_superseded/`.
- **The first restyle attempt failed (18 credits;** tasks in `.wip/meshy/wo011b_nim_concepts.json`, images in
  `.wip/concepts/v2/`). The owner saw that the garb and the suit aren't the same leopard.
  - They were two text prompts, with nothing tying one to the other. That's why "Concepts" now derives outfits from
    an anchor.
  - The suit was close: about 4.5 heads, curvy, vinyl, flat markings. But it was sleeveless, and its two back views
    disagree (one has an open back).
  - The garb was about 3.2 heads, too chibi.
  - The multi-view gives a front and two backs, no side view.
- **The restyle concepts (36 spent:** 27 approved, plus 9 approved for the anchor fix; about 7,829 left). Tasks are
  in `.wip/meshy/wo011c_concepts.json`, images in `.wip/concepts/v3/`. Multi-view now gives real side views.
  - **Vesper's suit** (`vesper_suit_*`): about 5.1 heads, heavy-lidded with liner, a mature face, tufted ears, a bob
    tail, curvy. Flaw: sleeveless, with bare fur shoulders.
  - **Nim's garb anchor:**
    - The first try (`nim_garb_*`) was held: round, cute eyes and a modest bust.
    - The fix (`nim_garb_fix_*`, image-to-image) gives half-lidded eyes with liner, a sly adult face, and a fuller
      bust and hips.
    - Still off: about 4.1 heads (above the floor of 4, under the 4.5 target), and markings on the back of the
      bodysuit.
  - **Nim's suit** (`nim_suit_*`, image-to-image from the fixed anchor): the same leopard, with clean latex and a
    crimson corset.
    - The gloves came out short and fingerless instead of long.
- **Owner: "all the members of the Velvet Rope have large breasts."** It's in ART_DIRECTION §1 and DESIGN.md
  (Vesper, Nim and the seven sisters).
  - It was applied to the concepts for 27 credits (about 7,802 left). Images are in `.wip/concepts/v4/`.
  - **Nim took it:** the garb anchor (`nim_garb_*`), then the suit re-derived from it (`nim_suit_*`). The suit got
    long gloves too.
  - **Vesper's pass failed:** her bust came out about the same. A retry needs another 9 credits.
- **The suit's side view was wrong twice.**
  - The owner spotted v4's head on backwards (the body faced right, the head left).
  - They asked for a regeneration with an open top showing cleavage. That's recorded in ART_DIRECTION §1: Domme
    suits may show cleavage; still no nudity.
  - v5 (9 credits, `.wip/concepts/v5/`) has a good front (open plunging neckline, large bust) and a good back.
  - **v5's side view is broken again:** her boots point backwards and her tail curls forward. The gloves are short
    cuffs again.
  - nano-banana's multi-view keeps breaking the suit's side view (the garb's has always been right).
- **APPROVED by the owner: "That's the look."**
  - **Nim's garb:** the v4 anchor, `.wip/concepts/v4/nim_garb_*` (task `01a1cbfb-122b-7081-81a9-d2f5cd0a86bb`).
  - **Nim's suit:** v5, `.wip/concepts/v5/nim_suit_*` (task `01a1cc0b-fa2c-73b7-8b3f-12785bb1ccf3`).
    - The owner asked for "the obvious fix of the side one". A single image-to-image call (9 credits) used the
      suit's front and back plus the garb's side view as the pose guide.
    - It made `nim_suit_side_fix.png`: a consistent three-quarter view.
    - **The suit's 3D inputs:** `nim_suit_1` (front), `nim_suit_2` (back) and `nim_suit_side_fix`. Never use
      `nim_suit_0`.
  - **This is the style bar for the whole cast.**
- **v6 ("maybe the chest slightly larger"):** 18 credits, about 7,766 left. In `.wip/concepts/v6/`:
  - the garb anchor, edited with a slightly fuller bust;
  - the suit, re-derived from it, with the open neckline.
  - **All three suit views agree, a true profile included,** so no side fix was needed.
  - **If the owner approves, v6 replaces v4/v5 as the reference and the 3D inputs** (garb `nim_garb_0/1/2`, suit
    `nim_suit_0/1/2`).
- **v7, the owner's six notes** (now rules in ART_DIRECTION §1 and the concept review):
  - big species markings, especially on the tail;
  - the tail shown, long and thick;
  - fingers, not mittens;
  - the garb's own silhouette;
  - the head ratio locked at v6;
  - big-cat ears.
  - **Cost:** 18 credits, about 7,748 left. Images in `.wip/concepts/v7/`.
  - **What landed:**
    - the tail swept out, visible and ringed;
    - fingers with claws;
    - a rope coil and knee pads on the garb;
    - smaller, pointed ears;
    - an unchanged head ratio;
    - the suit derived cleanly, with all three views agreeing.
  - **Still weak:**
    - Her cheeks have only small marks; the big clouds are on her tail, the sides of her head and her hands. Her arms
      are sleeved, so their markings can't show.
    - The garb's back has clouds printed on the cloth, and a rope coil on both hips (one at the front).
    - The suit's gloves are short.
- **v8, the owner's last two notes:**
  - **Ears:** v7's were too tall and pointed, a house cat's or a lynx's, too close to Kiara. Both v7 outfits were
    edited directly, ears only (18 credits, about 7,730 left), in `.wip/concepts/v8/`. The ears are now short,
    wide-set and rounded on both.
    - The suit came back as two images: `nim_suit_a` (front and side on one canvas; split it at the 3D step) and
      `nim_suit_b` (back).
    - The rule is now in ART_DIRECTION §1, per species.
  - **Markings are spots, not clouds.** No more concept rounds: they're painted at the bake step. The brief is in
    ART_DIRECTION's hero pipeline, step 4.
    - Big irregular clouds with darker rims, the tail as the guide.
    - Replace the dots on her face and chest.
    - Remove the clouds printed on the garb's cloth.
- **v9, the suit's heels** (owner: heels on the suit, flat soles on the garb, and every view must agree; now in
  ART_DIRECTION §1):
  - A multi-view edit failed (9 credits): the front came back unchanged.
  - A single front image succeeded (9): `.wip/concepts/v9/nim_suit_front_heels.png`.
  - **The suit's 3D inputs:** `v9/nim_suit_front_heels.png`, `v8/nim_suit_side.png` and `v8/nim_suit_b.png` (back).
    The v8 side was split out of `v8/nim_suit_a.png` by a Blender numpy script.
- **v10, the Rope's night uniform** (9 credits, about 7,703 left; `.wip/concepts/v10/`).
  - The owner made the garb the Rope's calling card: a harness with rings, a half mask with a red lining, a
    velvet-wrapped cord, and the Rope's knot embossed on the buckle and the mask.
    - The uniform is in ART_DIRECTION §1, varied per sister.
    - The knot is in DESIGN.md's Bind note; its shape is a proposal.
  - **Landed:** the harness, the knot buckle and the mask. All three views agree.
  - **Missed:** the cord reads solid red, not black cord in a red wrap. It can be fixed in a concept edit (9) or
    painted at the bake step (free).
- **v11, the velvet muzzle** (owner; lore in DESIGN.md, look in ART_DIRECTION §1, `mask_on` / `mask_off` clips in
  WO-011):
  - Front first, 9 credits (about 7,694 left): `.wip/concepts/v11/nim_garb_muzzle_front.png`.
  - **What it has:** black velvet, red piping and lining at the rim, a brass grille with the knot, straps behind
    the ears. It reads as a respirator, never a gag. The cord fix (black, with a red wrap) is folded in.
  - The muzzle and the eye mask came out joined as one face piece.
  - **The owner's three notes before 3D** (now in ART_DIRECTION's hero pipeline and WO-011):
    - **The mask is its own mesh.** The body's source is the unmasked garb. The mask is built separately on the
      head bone, preferably as a Blender-scripted shell.
    - **The hands are still mittens:** ask for separate fingers in the side and back round.
    - **Strong brow keys:** `brow_up` (both) and `brow_narrow` were added to `nim_build.py`'s face stage, next to
      brow_up_L/R, brow_down and squint.
  - **v12** (18 credits, about 7,676 left; `.wip/concepts/v12/`): **mostly missed.**
    - **A, the unmasked body:** drifted off-model (a tawny coat, about 5.5 heads, no knot buckle). Only the fingers
      came out right.
    - **B, the masked set:** the front is good, and the back shows the strap and buckle. But the side has no muzzle,
      and the cord came back red.
  - **The lesson:** multi-view image-to-image drifts or copies when asked to remove or add a face piece.
    Single-view edits with explicit references worked every time (the suit's side and heels, the muzzle front).
    **Make sources one view at a time** from here.
  - **v13, the unmasked body source** (27 credits, about 7,649 left; `.wip/concepts/v13/`):
    - One view at a time from v10, with v8's bare face as the reference.
    - **On-model:** the bare face, the cord fixed (black, red at the binding), and all views agree.
    - **The garb's 3D inputs:** `body_front`, `body_side`, `body_back`.
    - **The fingers** are separate only in the side view. The front and back still read as mittens.
  - **The mask's references:** `v11/nim_garb_muzzle_front.png` and `v12/masked_0.png` (the back strap and buckle).
    It's built in Blender.
  - **The hands are rebuilt in Blender** (owner): scripted cartoon hands with finger bones, for both outfits.
- **The new 3D models are made** (70 credits, about 7,579 left; tasks in `.wip/meshy/wo011d_nim_models.json`).
  - In `.wip/nim/raw/`: garb 562k tris, suit 282k. Renders are `.wip/nim/raw_*.png`.
  - Both are on-model. The suit's heels show from the front.
  - The latex bakes matte: its shine must come from the Godot material.
  - The old realistic work (its models, .blends and renders) moved to `.wip/nim/superseded_realistic/`. Nothing was
    deleted.
- **Blender pipeline progress on the new models** (`tools/nim_build.py`; renders in `.wip/nim/`):
  - **clean:** done for both, 120k tris each, with 4K colour and normal maps (`low_*.png`).
  - **rig:** done, 31 bones (`rig_*.png`).
    - The landmark fractions are re-measured for about 4.5 heads.
    - `recentre()` puts her midline at x = 0: the swept tail had dragged the bounding box about 10 cm off.
    - Leg sampling now skips the tail's vertices.
  - **face:** done (`head_*_<key>_front.png`).
    - The keys: blink, squint, `brow_up`, `brow_up_L/R`, `brow_down`, `brow_narrow`, jaw.
    - `FACE` is re-measured for the cartoon head. `BROW` = 18 mm, so the brows read clearly.
  - **weights:** done for both. The test pose bends cleanly (`pose_*.png`).
  - **hands: Meshy's own hands, rigged per finger** (owner: "option 1"). Run `-- fingers` after `-- weights`.
    - The rejected replacement hands (`-- hands`, primitive shapes) "looked nothing like the rest of the mesh".
      **Don't use that stage.**
    - **Done for both outfits.** The garb has four fingers and a thumb per hand; the suit has three and a thumb.
      - Bones `finger1..N.L/R` and `thumb.L/R` hang under `hand.*`. Their Z axis points toward the palm, so +X
        curls a finger in.
      - Renders: `fingers_<outfit>_{open,grip,point}_*.png`.
    - **Results:** a 70-degree fist curls from the knuckle and keeps the sculpt and paint. A point (one finger
      straight, the rest curled) reads.
    - **Known flaw:** small torn-looking triangles in the groove next to a straight finger, where neighbours share
      faces. If it shows in play, blend the weights a little across the groove.
    - **Save points:** `nim_*_prefingers.blend` (weighted, no fingers) and `nim_*_prehands.blend` (before weights).
  - **mask, now Meshy's** (owner: "have Meshy supply the mask alone, then fit it"). Run `-- meshymask` after
    the clips, then `-- export garb`.
    - **Cost:** 44 credits, about 7,535 left; tasks in `.wip/meshy/wo011e_mask.json`.
    - **Inputs:** a mask-only concept in `.wip/concepts/mask/`, modelled into `.wip/nim/raw/nim_mask.glb` and
      decimated to 60k tris.
    - **The fit** (`fit_meshy_mask`):
      - scaled to her eye spacing and eye-to-chin height (`MESHY_MASK` holds the model's measurements), with its
        front 12 mm ahead of her nose;
      - then pushed out radially from her head's axis to 7 mm clear of her fur, spread through the shell's
        thickness and smoothed;
      - the straps behind her ears are pulled in onto her skull;
      - Meshy painted the brass cream, so those texels are recoloured to brass (`_brass_texture`).
    - **Gotcha:** fit with the rig in the **rest pose.** After the clips, the rig plays track 1, and a mask fitted
      to the rest face lands by her ear.
    - **Gotcha:** don't push along the nearest normal. On a thin shell it flips side to side and shreds it.
    - **Result** (`mmask_garb_*.png`, `.wip/nim/game/0_face.png`): the concept's mask with all its detail, on her
      face. The knot reads.
      - The lower eye rims show a few torn texels: Meshy's texture seams, visible only up close.
      - The garb GLB grew to 44 MB with the mask's 4K texture. Halve the texture if the Deck needs it.
    - `nim_garb_procmask.blend` is the save point with the procedural mask (`-- mask`), kept as the fallback.
  - **Seams fixed** (owner: Meshy's models artifact around seams). The new tool is `tools/seams.py`; the stage
    is `-- seams`. Run it after `meshymask` and before `export`.
    - **The diagnosis:** two thirds of each body texture was unused, and over 80% of that was pure black.
      Mipmaps blended it into every seam.
    - **The fix:** each island grows 16 texels in its own colour, and a push-pull pass fills the rest. Colour
      and normal maps, both outfits, and the mask (`seams_before_after.png`).
    - The mask's decimate now delimits by seam and UV.
    - **Gotcha: never run `-- seams` twice on the same textures.** It trims 2 edge texels each run. Restore first:
      - `nim_*_preseams.blend` and `nim_*_{color,normal}_preseams.png` are the save points;
      - the garb also needs `nim_garb_procmask.blend` and a `-- meshymask` rerun.
    - **Still visible:** a few light flecks on the mask's dark eye band. They sit inside Meshy's painted
      texture, not on a seam, so they need a paint pass (the same step as Nim's cloud markings).
  - **The procedural mask** (`-- mask`, garb only; renders `mask_garb_*.png`). Save point: `nim_garb_premask.blend`.
    - The shell is sampled by raycasts round her head inside a smooth outline (an eye band with eye holes,
      joined to the snout). The stair-steps are smoothed off the rim, it's shrink-wrapped 4 mm off her fur, and
      given 4 mm of thickness.
    - On it: red piping on all three rims, a brass grille with the knot (three rings), straps at eye and snout
      height round to a brass back buckle, and a brass catch on her right.
    - It's its own object, `Nim_garb_Mask`, parented to the head bone. The brows stay clear above the band.
    - **Weak:** the knot reads faintly at gameplay distance. Paint or emboss it at the painting step.
  - **clips: done**, 33 per outfit (`clips_*.png` contact sheets): the 31 before, plus `mask_on` / `mask_off`.
    - Every key also curls the fingers: per-clip grips in `nim_poses.CLIP_GRIP`, points in `POINTS`, overrides in
      `GRIPS`.
    - Her new limbs are close in length to the old sculpt's (the head grew, not the limbs), so the poses carried
      over unchanged.
  - **export: done.** `assets/characters/nim/nim_garb.glb` (27 MB, with the mask node) and `nim_suit.glb`
    (23 MB). The realistic GLBs moved to `.wip/nim/superseded_realistic/assets/`.
    - `tools/nim_glb_probe.gd` lists what Godot sees: 33 animations, 41/39 bones, nine blend shapes, the mask
      node.
- **In the game: `player/nim_model.gd`** (Nim builds it in `_ready`; the capsule stays as the fallback when the
  GLBs are missing).
  - **Both outfits are loaded,** with one shown; `NimSuit.outfit_changed` swaps them and the clip carries over.
  - **The clip follows her state:**
    - down, changing, strike 1–3, bind;
    - balance, climb (up, side, head first), hang, mantle, ceiling, swing;
    - pounce, jump, fall;
    - land (a one-shot);
    - trance, idle (per outfit), prowl when crouched, run above 3.6 m/s, then walk (garb) or strut (suit).
  - **One-shots:** hurt (on `health_changed` dropping), `cmd_<word>` and `hold_room` (on `NimSuit.gestured`).
  - **Playback speed** follows her real speed for the moving clips.
  - **The muzzle** is on while covert and off whenever `Dialogue.is_active()`; it clicks back on with `mask_on`
    (the mesh swaps on the click's frame).
  - **Face:** random blinks, `brow_narrow` while fighting or locked on, and `squint` in the fake trance.
  - **Look:** `Look.toon` with each surface's own colour and texture, an ink outline (0.008), and rim 0.18 (0.6
    glowed neon). Brass gets gloss 0.9, leather 0.3.
  - **Shots:** `godot --path . -s tools/nim_shots.gd -- <dir>`: stand, face, walk and run per outfit, in the test
    room (`.wip/nim/game/`).
  - **All 12 probes pass with clean logs** with the model in.
- **Paint pass: done** (`tools/nim_paint.py`, `nim_build.py -- paint [garb|suit]`). Run it after `-- meshymask`
  and **instead of** `-- seams`: it pads the seams itself.
  - **It always starts from the pristine bakes** (`nim_*_color_preseams.png`), so it can be rerun. To redo,
    restore `nim_*_prepaint.blend` first.
  - **Zones are chosen by each texel's baked 3D position, not by colour.** Colour misread everything: her cloth
    is as light as her fur, and the printed clouds as warm.
    - **Head, and the suit's neckline:**
      - spots out: a spot is warm and darker than the fur around it; flecks are specks with fur all round;
      - clouds in: warped 3D blobs 3–4.5 cm across, with dark rims and lighter centres, on her cheeks and crown;
      - the eyes, brows, muzzle and ears are protected.
    - **The garb's upper back:** the warm printed clouds become plain cloth. The harness (cool) and the tail stay.
    - **The mask:** light flecks become velvet.
  - **The tail's rings are left as Meshy painted them** (already cloud-like).
  - **Renders:** `paint_*_{front,back,side,head}.png`, `paint_suit_chest.png`.
  - **Debug:** the scratch `classmap.py` (red protected, green erased, blue fill source) is how the zones were
    tuned.
  - **Still rough:**
    - a few clouds end on hard straight edges where they meet a protected zone (above the brows);
    - some flecks remain at the suit's neckline edge, where latex was baked onto the fur's triangles;
    - one cloud remains at the garb's waist, under the harness.
    These need a hand paint in GIMP if they bother the owner.
- **Deployed to the Deck** (2026-11-11). It starts cleanly there (headless smoke test).
  - The build grew from about 77 MB to **149 MB**: two 4K-textured outfits, plus the mask's 4K texture.
  - The frame rate on the Deck isn't measured yet. If it dips, halve the textures to 2K first.
  - **The owner played it on the Deck: "Controls feel smooth."** So the model didn't cost the feel.
- **Not done yet:**
  - the owner's look at her in motion on the Deck (deployed; waiting on the owner);
  - ~~painting the markings as clouds~~ done (paint pass, above). Deployed to the Deck (160 MB build; it starts
    cleanly). Waiting on the owner's look;
  - **The rest of the cast (owner, 2026-11-11):** more endowed than Nim, with exposed cleavage, especially in
    their Domme suits (ART_DIRECTION §1, DESIGN.md). Vesper's v14 suit is high-collared, so it needs an edit
    first (WO-012).
  - tuning the ceiling crawl's and the head-first descent's height against the real geometry in the test room;
  - the latex shine on the suit (it's one texture with the fur, so gloss would hit the fur too: it needs a mask
    texture);
  - ~~Vesper's bust retry~~ done (owner-approved, 9 credits): `.wip/concepts/v14/vesper_suit_*`, larger bust,
    nothing else changed. About 7,526 credits left.
- **Next, the Blender pipeline on the new models:**
  1. clean;
  2. re-measure the rig landmarks for the cartoon proportions;
  3. build the mask mesh;
  4. rebuild the hands with finger bones;
  5. weights;
  6. face keys, including `brow_up` and `brow_narrow`;
  7. clips, rescaled, plus `mask_on` / `mask_off`;
  8. export;
  9. Godot integration (`player/nim_model.gd`).
- **Still open:**
  - **Vesper's suit:** v3 passes the style.
    - The large-breasts pass failed once (no change).
    - A stronger-worded retry was **refused by the image provider's safety filter** (not charged).
    - Next try: the plain wording that worked for Nim ("large breasts, fully covered"), or regenerate her from text
      with it in the base prompt. Ask the owner.
  - WO-011's 3D: two models, about 70 credits. Quote and wait for a yes.
- **The 70 credits' models are superseded.** `assets/characters/nim/nim_garb.glb` and `nim_suit.glb` (55 MB) are
  from the rejected look and nothing references them. They're left for the owner to delete or keep (not committed).
- **The pipeline carries over unchanged** (all below): clean, the tail walk, the surface-distance weights, the face
  keys and the Poser clips.
  - Expect to re-measure: `PROPORTION`, `SHOULDER_X` and `HAND_LEN` in `nim_build.py` assume seven heads, and the
    `FACE` / `TAIL_TIP` constants are per sculpt.
  - The clips' hand and ankle offsets assume a 0.42 m arm and a 0.81 m leg. Shorter cartoon limbs will need them
    scaled.
- **Code added for the model, harmless without it:**
  - `NimSuit.gestured(what)`, emitted on a command and on Hold the Room;
  - `NimCombat.hit_number()`;
  - `Nim.headfirst()`.
  - `player/nim_model.gd` (the model driver) was never written.

## 2026-11-11: WO-011 in progress (Nim's art), superseded by the stop above
**70 credits spent** (two multi-image models with Ultra geometry; tasks in `.wip/meshy/wo011_nim.json`).
The pipeline is `tools/nim_build.py`, run headless in Blender 5.2 one stage at a time (`-- inspect | clean | rig |
weights [garb|suit]`). Work files and every render are in `.wip/nim/`.
- **Done, per outfit:**
  - **clean:** voxel remesh then decimate to 120k tris, with 4K colour and normal maps baked from the raw mesh.
  - **rig:** 31 bones placed from measured landmarks (`rig_*.png` show the overlays).
  - **weights:** distance-to-bone, inside regions found along the surface (`pose_*.png` show a test pose).
- **The tail is found from its tip:** each ring of vertices at one surface distance from the tip gives a point on
  the centreline, and the walk stops where the rings widen into her body. This handles the suit's curl, which the
  first "march from the pelvis" version missed.
  - `TAIL_TIP` holds a rough tip position per outfit, read off the renders. The script snaps it to the mesh.
- **Regions:**
  - Arm vertices are those within arm's reach of the fingertip along the surface, so the waist never follows the
    hanging elbow.
  - Leg side is decided by surface distance from each toe, so the garb's ankle strap stays on its own leg.
- **Pose axes** (bones are rolled to face her front): +X flexes a limb or bends the spine forward. On the upper arms,
  -Z lowers the left arm and +Z lowers the right.
- **Still to do:** the face shape keys (blink, brows, jaw), about 30 posed clips, the per-outfit GLB export, the
  Godot integration (replace the capsule, drive the animations, swap outfits), and the owner's approval.

## 2026-11-11: WO-010 built (UI and HUD)
No credits spent. Deployed (with WO-009) once the Deck was back, and it starts cleanly there.
- **The title screen (`levels/title/`, the main scene):** the age gate first on a new machine, then "press any
  button".
  - The menu: Continue (if the slot in play has a game), Saves, Settings, Content (the content card again) and Quit.
  - Saves: three slots showing Keys and when each was saved. Play starts or continues one; Erase asks "Sure?" first.
- **Settings (`core/settings_menu.gd`)**, from the title or the pause menu, in four pages:
  - **Controls:** every remappable action, its key and its pad button. Pick one, press the new one, and it's saved.
    Reset restores the defaults. `Controls.rebind` and `apply_saved`; bindings live in the settings file.
  - **Camera:** speed, and invert X and Y (`follow_cam.gd` reads them).
  - **Display and sound:** volume, fullscreen, the fps counter.
  - **Accessibility:** subtitles; text size (the UI scales by 0.85, 1.0 or 1.2); reduce motion (cutscenes cut
    instead of panning); reduce flashing (stored; nothing flashes yet).
  - Everything saves as it changes (`Game.set_setting`, which emits `settings_changed`).
- **`core/menu.gd` (`Menu`):** the panel, buttons, toggles, sliders and choices every menu is built from, all pad-,
  key- and mouse-ready.
- **The HUD (`core/hud.gd`, rewritten).** The five-line hint is gone (it's on the pause menu's Controls page).
  - Top left: five health in velvet and gold, and the light readout.
  - Bottom left: the gear on LB; in the suit, Composure (COVER BLOWN) and the Command word.
  - Bottom middle: **what Y does here** ("Y  Talk", "E  Change"), in the glyph of the device used last
    (`Controls.using_pad`, `glyph()`), from `NimSuit.y_prompt()`; then notes; then **captions** (staff replies, a
    waking sleeper; off if subtitles are off).
  - Top middle: the zone and **a world's arrival card** (its name, its host and gear).
  - Top right: Banjo pop-ups, and fps if it's on.
- **Pause:** tallies and rank, then Resume / Controls (the bindings as they are, remaps included) / Settings / Back to
  the last wardrobe / Return to the club / Title screen / Quit. B backs out of each page.
- **A world's end:** `World.complete()` marks it done, plays its paper (`data/cutscenes/paper_<world>.json`), and goes
  back to the club.
  - Written from the briefs: the Pier, Primrose Close (the parish newsletter) and the Decency Press (a radio
    bulletin).
  - **The Docks, the Retreat and the Ball have no paper in their briefs.**
- **`ui_probe` (40 checks):** every screen on the pad, the keys and the mouse.
  - The title by pad; Content by mouse; Esc back.
  - Settings: a toggle by A, a slider by the D-pad, a remap by Enter and a key press (pad binding untouched), text
    size, Back by mouse.
  - A slot plays the game, with its arrival card and HUD; the Y prompt in pad and key glyphs; the suit's Composure;
    captions with subtitles on and off.
  - Pause, its Controls page with the remap, and Settings from pause.
  - A world's paper; erasing a slot (asked twice).
- **`ui_shots`:** every screen as a PNG (checked by eye: the title, slots, all four settings pages, the HUD in garb
  and in the suit, pause and its Controls page, the arrival card, the paper).
- **Fixed along the way:**
  - The title's slot list left old rows in the tree for a frame, so focus went to a freed button.
  - `Game.slot_summary` called a never-played slot full.
  - Key names asked a headless display server for a layout it doesn't have.

## 2026-11-11: WO-009 built (dialogue, cutscenes and writing)
No credits spent. Deployed with WO-010 (the Deck was off the network when WO-009 was built).
- **The dialogue code (`core/dialogue/`), ported from Nine Lives:** `DialogueParser`, `DialogueRunner`,
  `DialogueCondition`, `DialogueScript` and `TextTags`.
  - The .dialogue format: labels, speakers with an emotion, choices, conditions, flag sets, jumps and inline tags.
  - Changes from Nine Lives: no Kiara gag rule, flags can be namespaced (`bound/pier/g1`), and nothing names the Game
    autoload directly (probes compile).
- **`core/dialogue.gd` (the Dialogue autoload)** is Nine Lives' box, in the Rope's crimson, with names in each
  speaker's colour (`data/dialogue/speakers.json`).
  - It shows typewriter text and choices (up/down and A), and the world waits.
  - **The guards:** a button held as a talk opens does nothing until it's let go, and presses in the first 0.4 s are
    ignored.
  - `await Dialogue.run(file, label)`.
- **Cutscenes** (`await Dialogue.play_cutscene(path)`) are JSON steps: shot, move, face, say, card (newspaper or
  radio), set, wait. The world is paused, and the level's camera comes back after.
- **`core/talker.gd` (`Talker`):** Y beside it plays its .dialogue label, or a cutscene. Options: `once`,
  `after_label`, `display_name`. Nim's Y chain is: Vesper teaching, then talkers, then travel points, shortcuts,
  wardrobes and commands.
- **Vesper's stand-in now teaches through dialogue** (`LessonGiver.dialogue_file` and `dialogue_label`;
  `data/dialogue/course/vesper.dialogue`).
- **On the course** (lane K): Dash (`dash.dialogue`, the example conversation, with a choice, flags and a second
  visit) and a newsstand (`data/cutscenes/course_paper.json`: a shot, the morning paper, Nim's line).
- **Writing:** `docs/WRITING.md` covers the rules, the format, how to put a conversation in, cutscenes, and a voice
  sheet per character.
- **The lint** (`core/writing_lint.gd` rules, `tools/dialogue_lint.gd` runner) fails on:
  - parse errors and unknown speakers;
  - Vesper or Swyne lines not marked `# OWNER REVIEW`, in dialogue or in code strings;
  - cutscene cards not marked `"owner_review": true`, and cutscenes that say a missing conversation;
  - **banned words** (`data/writing/banned_words.json`, whole words) in dialogue, cutscenes, world data and code
    strings.
- **`dialogue_probe` (23 checks):**
  - **a writer adds a conversation without code** (a new file plus a Talker), reads it, and picks a choice with the
    D-pad; its flags are set and the lint passes it;
  - A held, or A mashed, skips nothing;
  - Dash's choice and his second visit;
  - the newsstand cutscene takes the camera, shows the paper and gives it back;
  - **the lint passes the game** and catches each kind of problem in samples.
- **The export** now includes `.dialogue` files and nested data.

## 2026-11-11: WO-008 built (worlds, collectibles and saving)
No credits spent.
- **Saving (`core/game.gd`):** everything autosaves on every change to **`user://vesper.json`**, which holds three
  slots (`Game.slot`, `use_slot`, `slot_summary`, `erase_slot`).
  - An old `progress.json` isn't migrated; it only ever held test-course progress.
  - Settings stay in `settings.cfg`. Probes can point `Game.save_path` elsewhere.
- **Collectibles, per world:** Keys (10 per world, 10 in the hub), contraband (100), five people woken, and one
  collection tin.
  - **All five woken pays the world's Key 10** (`<world>_10`; every brief's Key 10 is "five woken").
  - **A tin pays the hub Key `tin_<world>`.**
  - `core/pickup.gd` (`Pickup`): Keys and contraband are walked into; the tin is struck. Collected ones don't come
    back on reload.
- **Ranks:** `Game.keys()`, `Game.rank()` and `Game.world_open()`. Thresholds 1, 6, 14, 22, 32, 42, 58 (a proposal);
  the `ranked` signal fires on a new rank. `core/rank_door.gd` (`RankDoor`) shows what it needs and opens at it.
- **Worlds as data:** `data/worlds/<id>.json` for the hub, the six worlds and City Hall, taken from the briefs: areas,
  wardrobes, shortcuts, all 10 Keys (id, name, where, outfit, the joke), contraband, the tin, the set piece and the
  boss.
  - Read them with `core/world_data.gd` (`WorldData.of(id)`, `WorldData.key(world, id)`).
  - Change a brief, change its file.
- **`core/world.gd` (`World`, extends Level)** has helpers for placing Keys (checked against the data), contraband,
  the tin, sleepers, zones, wardrobes, checkpoints, shortcuts, fast travel points and rank doors. Its `finish()`
  culls small meshes past 45 m.
- **Arrivals:** `Level.arrival(id, at, yaw)` plus `Game.travel(scene, id)`. "@wardrobe" is the pause menu's way back
  to the last wardrobe.
- **The rest of the world kit:**
  - `core/zone.gd` (`Zone`): names a place on the HUD.
  - `core/shortcut.gd` (`ShortcutDoor`; Godot already has a `Shortcut`): opens with Y from its back only, for good.
  - `core/travel_point.gd` (`TravelPoint`): found by walking past; Y lists the others found in that world. The list
    is the HUD's pad-first `Hud.choose()`.
- **The pause screen (`core/hud.gd`)** covers the HUD with a dark backdrop. It shows per-world tallies, Banjo-style
  (Keys, contraband, woken, tin, with locked worlds marked), Keys and rank with the next threshold, and Resume / Back
  to the last wardrobe / Return to the club / Settings (a note until WO-010) / Quit. A pick-up flashes its world's
  count.
- **The hub's stand-in** is the street corner (`world_id` "hub", with a "club_door" arrival); "Return to the club"
  goes there.
- **The probe world (`levels/probe_world/`):** one yard with every collectible and every world piece.
- **`world_probe` (29 checks):**
  - it collects everything (the tin pays the hub; five woken pays Key 10);
  - the rank door is shut at 3 Keys and opens at 4;
  - the shortcut is bolted from the front and opens from behind; the zone names itself; fast travel works; the
    wardrobe is remembered; a goon is bound;
  - **wiping Game and reloading from the file brings it all back**, including the scene's pickups, doors, the bound
    goon and the woken five;
  - slot 2 is empty and slot 1 comes back;
  - the pause tallies agree.
- **Fixed along the way:** the light meter tripped over a light freed mid-game (a collected Key's glow).

## 2026-11-11: WO-007 built (lessons and gear)
No credits spent.
- **`core/lessons.gd` (`Lessons`):** every lesson and piece of gear, by its Game flag.
  - Lessons: `lesson_takedown_above`, `lesson_fetch_open`, `lesson_ceiling`, `lesson_hold_room`.
  - Gear: `gear_crop`, `gear_scold`, `gear_rope`, `gear_pendant`, `gear_lure`, `gear_signet`.
  - **`Nim.known`** is the one set of what she has (`Nim.knows(flag)`). `Level.spawn_player` fills it from Game's
    flags, and the test course unlocks it all. `NimSuit` no longer keeps its own.
- **`core/lesson_giver.gd` (`LessonGiver`):** a Vesper stand-in. Y beside her and she teaches her lesson: it sets
  Game's flag and Nim knows it. Her line is `# OWNER REVIEW`. Her real scenes come with WO-009.
- **The ceiling crawl** (`lesson_ceiling`, Nim's CEILING state):
  - jumping up under a marked ceiling (collision layer 3, value 4) she grips it and hangs upside down;
  - she crawls at 2 m/s, only as far as the ceiling goes;
  - A or B drops her.
- **The headfirst descent** (same lesson): walking off the top of a marked wall, she grips its face and goes down
  head first at 4.5 m/s. "Up" on the stick takes her down.
- **The crop** (`gear_crop`, in NimCombat): X held 0.3 s follows the claw with a lash. It reaches 3.2 m, a narrow
  30° arc, and 3.2 m up. `core/crop_target.gd` (`CropTarget`) is a switch, a bell or a target.
- **The rope** (`gear_rope`, RB):
  - **In the air** it's Nim's SWING state, a taut pendulum from a `SwingAnchor` (`core/swing_anchor.gd`):
    - the catch keeps her speed along the arc;
    - the stick pumps it, and letting go of RB keeps the swing's momentum;
    - A jumps off with a full jump on top;
    - the anchor just left is skipped for 0.5 s.
  - **On the ground** (`player/nim_gear.gd`): it binds a goon who could be bound, from up to 7 m away; failing that,
    it pulls down a `Pullable` (`core/pullable.gd`) within 9 m in front.
- **`player/nim_gear.gd` (`NimGear`), LB's gear.** D-pad left / 4 cycles what she has.
  - **The Scold:** every goon within 8 m freezes for 3 s (`Enemy.freeze`, state FROZEN). Frozen goons can be bound,
    and wake up furious. 5 s cooldown.
  - **The pendant:** wakes the person in a trance she's looking at, within 9 m and in sight. Otherwise it toggles the
    fake trance.
  - **Lures** (`core/lure.gd`): a thrown seized toy. Where it lands it buzzes for 6 s, and goons within 11 m hear it
    and come to search. Counted in `NimGear.lures`.
- **The signet** (`gear_signet`): `Staff.powerful` people (councillors) are tier 0 and won't obey anything; with the
  signet they answer like staff.
- **The HUD:** the selected gear (and lures left). The hint has a fifth line for gear, the rope and ceilings.
- **Lane K on the course** (x 192): a station for each of the above, down three platforms.
- **`gear_probe` (25 checks):**
  - the ceiling: unlearned, then taught by Vesper, then across a gap;
  - the headfirst descent: 6 m in 0.93 s, landing at the wall's foot;
  - the crop: the switch and the bell the claw can't reach;
  - the rope: pull, the swing across 12 m, a bind from 3.3 m;
  - the signet: fails without it, kneels with it;
  - the Scold freezes two goons, and a frozen one gets bound;
  - the pendant wakes the sleeper from 6.5 m;
  - a lure draws the guard off his post.
  - The other lessons and the fake trance are in `stealth_probe` and `social_probe`.
- **Fixed along the way (goon AI):**
  - A searching goon used to drop back into staring when any suspicion remained, so searches never walked anywhere.
    Now they walk to the spot, look round, then go back.
  - A search for a spot behind a wall stops at the wall.
  - A second noise while a goon's still wondering sends him to search. Before, suspicion drained between a lure's
    buzzes and he only stared.
  - The headfirst grip was attaching above the top of the wall and letting go at once (a free fall the probe first
    missed). It now attaches with her chest on the face, and the probe times the descent and checks where she lands.

## 2026-11-11: WO-006 built (outfits, Composure and Commands)
No credits spent.
- **`player/nim_suit.gd` (`NimSuit`)**, a child of Nim, ticked before `NimCombat`. It holds the outfit, Composure,
  cover, crowds, Commands, wardrobes, Hold the Room and the fake trance.
- **Outfits:** night garb (matte charcoal) or the Domme suit (glossy black with a crimson corset), swapped at a
  `Wardrobe` with Y. The change takes 1 s.
  - Every change restores her cover and Composure.
  - In a blown suit she gets a fresh suit, so she stays in the suit.
  - Chasers lose her (`Enemy.lose_her`).
  - The wardrobe won't work with a chasing goon within 2.5 m.
- **In the suit:**
  - **The strut:** the stick part-way (0.6 or less), or B held, is a poised 3.2 m/s; all the way is a 7 m/s run. She
    doesn't crouch.
  - **Who suspects her:** ordinary goons and lookouts don't. Security with `knows_her` do, unless she's hidden in a
    crowd (two or more guests within 2.2 m while she struts). Darkness doesn't hide a suit with its cover intact.
  - **Refused until her cover's blown:** fighting, binding and the pounce's stagger. Trying it in sight costs 0.1.
- **Composure** (0–1) changes only while a watcher (`watcher` group, `sees_her`) can see her:
  - **Drains:** running 0.3/s, climbing 0.4/s, crouching 0.2/s.
  - **Costs:** a jump 0.12, a pounce 0.25, a failed command 0.25.
  - **Restores:** a strut 0.06/s, a command that works +0.15.
  - **At 0 her cover's blown:** goons within 25 m are alerted, and any goon who gives chase also blows it
    (`NimSuit.expose`). The HUD shows "COVER BLOWN".
  - **Recovery:**
    - break sight: nobody hunting and nobody seeing her for 5 s brings it back at 0.35;
    - a wardrobe: back at full;
    - **Hold the Room** (hold Y for 1 s, lesson `lesson_hold_room`): goons within 15 m stand down, and it comes back
      at 0.3.
- **Commands** (suit, cover intact): LT targets the `commandable` nearest the view's centre, the D-pad (or 1–3)
  picks the word, and Y says it to the target, or to whoever's nearest in front within 6 m.
  - Kneel is level 1; Fetch and Open are level 2 and need the lesson `lesson_fetch_open`.
  - Goons are tier 1: they only kneel, for 20 s, watching nothing.
  - **`core/staff.gd` (`Staff`)** is tier 2: Kneel; Fetch (walks to its `fetch_item`, a `KeyItem`, and brings it
    to her, which lands in `NimSuit.keys`); Open (walks to its `door`, a `Door`, and opens it).
  - Above someone's tier the command fails and costs Composure.
- **`core/guest.gd` (`Guest`):** party guests standing in knots. They make crowds and they watch.
- **The fake trance** (LB / Q, gear `gear_pendant`):
  - she shuffles at 1.2 m/s, and goons and lookouts ignore her (`Sight` returns false);
  - pushing the stick hard, jumping, climbing, striking or pouncing breaks it.
- **The HUD:** a Composure bar and label (suit only), the current Command word, a fourth hint line, and notes for
  refusals and failed commands.
- **Lane J on the course** (x 164), the club:
  - the street: a doorman goon, and a wardrobe behind a wall out of his sight;
  - the room: the bar with a bartender, a key on the counter and a locked back door; two rows of 13 guests making a
    crowded corridor; a goon on his rounds; and security (`knows_her`) in the far corner.
  - The course unlocks every suit lesson and the pendant.
- **`social_probe` (21 checks):**
  - in: the wardrobe into the suit;
  - fight refused, and the attempt costs Composure;
  - **blend-in crossing:** strutting the corridor past security, his suspicion stays at 0 and she's hidden for 90% of
    it; a half step out of the crowd and he wonders (0.21), then forgets once she's back in;
  - Kneel, Fetch (the key arrives), Open (the door opens), and a Fetch above a goon's tier that fails;
  - **blown**, the doorman comes, and now a strike lands;
  - **recovered at the wardrobe**, and the doorman gives up;
  - blown again and **Hold the Room**;
  - the fake trance past the doorman's nose, then running breaks it and he notices.
- **Performance note:** the club view draws 350–420 calls (each guest is several meshes; the whole course is in view).
  Fine for a test scene. Real crowds should share meshes (MultiMesh or a merged guest).

## 2026-11-11: WO-005 built (stealth)
No credits spent.
- **Light:** `core/light_meter.gd` (`LightMeter`) works out how lit a spot is (0–1) from the level's lights in code,
  so it's the same on the Deck and in headless probes.
  - Lamps fall off squared to their range. The moon is worth 0.6 of its energy. Each light counts only if a shadow
    ray reaches it; hits within 0.6 m of a light are its own fixture.
  - Nim measures it at her chest 10 times a second (`Nim.light`).
  - The HUD shows it as a bar under the health, from dark indigo to lamp gold.
- **Sight:** `core/sight.gd` (`Sight`) is the one rule for goons and lookouts. The range shrinks to a quarter in full
  dark and halves again when she's crouched. A short "bump" range ignores the light.
- **Hearing:**
  - What makes noise, and how far it carries: running (over 4.5 m/s), footsteps every 0.35 s, heard 7 m; a landing
    from 2.5 m or higher, 9 m; a strike that lands, 8 m. Walking and sneaking are silent.
  - A goon who hears it turns to look (`Enemy.hear`). A second noise sends him to search where it came from. Hearing
    never starts a chase on its own.
- **Lookouts:** `core/lookout.gd` (`Lookout`) is a bird on a post whose head sweeps.
  - It uses the same sight rule. When sure, it raises the alarm ("!!"): every goon within 30 m runs to where she was
    seen (`Enemy.alert`).
  - It settles after 4 s. It never fights.
- **Takedowns:**
  - **From behind:** binding an unaware goon now needs her behind him (over 100° from where he looks;
    `Enemy.bindable_from`). Staggered or knocked down, he can still be tied from anywhere.
  - **From above:** landing from 1.5 m or higher on or beside a goon (within 1.3 m) binds him in 0.4 s, whatever he
    was doing (`NimCombat.drop_takedown`). It's unlocked by Game's flag `lesson_takedown_above`, Vesper's world-1
    lesson; the test course unlocks it.
- **Recoverable detection:** the existing chase, search, give up and return. The yard calms down in under a minute.
- **Lane I on the course** (x 136), the stealth yard:
  - a 9 m wall casts the moon's shadow down a 3 m strip on the west side;
  - two lamps light the middle;
  - a patrol, a guard looking back down the yard, a lookout behind him, and a goon to drop on;
  - a dark shed by the near end to hide in.
- **`stealth_probe` (11 checks):**
  - **unseen:** crouched down the strip, nobody's suspicion moves off 0;
  - the light readings: shadow 0.00, moonlight 0.60, lamp 1.00;
  - sneaking behind the guard is silent, and running behind him turns him;
  - the drop takedown does nothing while unlearned, and binds once learned, even mid-fight;
  - **spotted in the lamplight**, she runs for the shed, they lose her, and the yard settles back to its rounds.

## 2026-11-11: WO-004 built (combat and the Bind)
No credits spent. The owner moved on from WO-003 without asking for feel changes.
- **`player/nim_combat.gd` (`NimCombat`)**, a child of Nim:
  - **The strike** (X / J): a three-hit combo. Hits 1 and 2 stagger, hit 3 knocks down. Mashed presses queue up to
    the third hit. She turns to her target (the lock, or the nearest goon within 3.5 m roughly ahead) and steps in.
  - **The pounce** staggers the first goon it touches and stops on him.
  - **The Bind** (Y / E): ties the nearest goon within 1.8 m who's staggered, knocked down, or unaware (patrolling,
    suspicion under 0.5). It takes 0.6 s, and a hit cancels it.
  - **Lock-on** (LT held): the goon nearest the middle of the view, within 15 m, marked with a red dot. The camera
    swings to keep him past her shoulder (`follow_cam.gd` `lock_target`).
  - **Health:** 5. A punch costs 1, knocks her back (and off a wall or ledge), and gives her 1 s of invulnerability.
    At 0 she's downed for 1.2 s, then back at the last checkpoint at full health. No lives.
- **`core/enemy.gd` (`Enemy`), the EnemyBase:**
  - It patrols a loop, or stands guard. When it sees her, suspicion builds (a ? overhead); at full it chases (a !).
  - It fights with a telegraphed punch: the fist rises, then swings.
  - When it loses her for 2.5 s it searches where she was last seen, then gives up and goes back.
  - It staggers, gets knocked down, and can be bound. **It never dies.**
  - Sight: a 110° cone, 14 m (7 m when she's crouched), with a line-of-sight ray. Within 1.2 m he notices her
    whichever way he faces.
  - **Bound** goons wear three turns of red rope and a note for the police. They're remembered by the flag
    `bound/<world>/<id>`, so they persist through checkpoints, reloads and saves.
  - WO-005 adds light and hearing on top of `noticing()`.
- **`core/entranced.gd` (`Entranced`) and `core/trance_device.gd`:** someone in a trance wanders a loop holding a
  glowing toy.
  - Strikes pass through them, nothing locks on to them, and Y can't bind them.
  - A strike on the toy **from in front of them** breaks it and wakes them. That's counted as `freed` in Game for the
    world, and remembered.
- **`core/checkpoint.gd` (`Checkpoint`):** walk past it and it's where she comes back; its ribbon lights up.
  `Level.checkpoint()` and `Level.world_id` are new.
- **HUD:** health pips under the hint. The hint has a third line for the combat buttons.
- **The test course** has two new lanes:
  - G (x 90): a yard with a checkpoint and three patrolling goons.
  - H (x 112): a sentry facing away, and someone in a trance.
  - The course **starts fresh once per launch** (`Game.clear_world`), so Deck tests don't find everyone already
    bound. Reloads within a launch keep what happened.
- **`combat_probe` (20 checks):**
  - binding an unaware sentry;
  - strikes and Y passing through a person in a trance, then waking them from in front;
  - the checkpoint, a punch, downed and back;
  - lock-on, stagger and knockdown;
  - fighting and binding all three goons (about 10 s);
  - after a reload and after a save round-trip, all four goons are still bound and the woken person is still awake.
- **Fixed along the way:**
  - The combo's queue held only one press, so mashing never reached the third hit. It now counts presses.
  - The stagger's knock-back is now 1 m/s (was 2), so the combo stays in reach.

## 2026-11-11: WO-003 built (the owner moved on to WO-004 without feel changes)
No credits spent.
- **`player/nim.gd` (`Nim`)** replaces the greybox capsule. It's still a capsule (0.35 m radius, 1.7 m tall), with
  states MOVE, BALANCE, CLIMB, HANG and MANTLE. Every tunable is in the constants block at the top. The work order's
  starting feel:
  - run 7 m/s;
  - a 2.2 m jump with its apex at 0.35 s;
  - coyote time and the jump buffer, 0.1 s each;
  - climb 2.5 m/s, balance 2 m/s, pounce 9 m/s for 0.25 s.
- **Additions beyond the work order:**
  - A short hop when A is let go early.
  - Sneak at 3 m/s, crouched to 1 m.
  - She steps up anything 0.3 m or lower (kerbs).
  - In the air she keeps her momentum when the stick is let go.
  - The air pounce (one per jump) is level, so it crosses gaps a jump can't.
- **Climbing:** a surface is climbable if its body has collision layer 2 (value 2) on top of layer 1. Push into it to
  start; the stick climbs up, down and across, and she stops at its edges. Over the top is a mantle. A leaps off;
  B lets go.
- **Ledges** (any solid edge 0.6–2.4 m above her feet, caught falling or at a jump's top):
  - she hangs and shimmies along as far as the ledge goes;
  - A, or the stick held at the wall for 0.3 s, pulls her up;
  - B, or the stick away from the wall, drops her.
- **Beams and wires: `core/beam.gd` (`Beam`).** Its line runs along local X, with the origin on the top surface.
  Standing on one she balances: slow, held to its line, the stick only moving her along it. Falling within 0.5 m of a
  beam's line pulls her onto it.
- **The test course (`levels/test_course/course.gd`):** six lanes, each signed overhead.
  - A: gaps of 2.5, 3.5 and 4.2 m.
  - B: blocks 1.0, 1.6 and 2.0 m high.
  - C: ledges of 3 m and then 4 m more.
  - D: a 7 m marked (green) wall.
  - E: an 8 m beam and a 6 m wire, 3 m up.
  - F: a 1.1 m crawlway and a 6.5 m gap that needs a jump plus a pounce.
- **Probes** drive her with real pad events (`tools/probe_driver.gd`).
  - `walk_probe` (16 checks): every gap and height, the held jump's height and the tapped hop, coyote time, the
    buffer, the pounce's speed, both balance runs, the wire's catch, the crawlway (blocked standing, through
    crouched), and the pounce gap (short without the pounce, across with it).
  - `climb_probe` (13 checks): catch, drop, shimmy to the ledge's end, both ways of pulling up, a ledge reached only
    at a jump's top, climbing up (at 2.5 m/s), across, down, and leaping off.
- **The camera:** unchanged from WO-001 (the spring arm keeps out of walls; R3 / V recentres).
- **Fixed along the way:** right after a teleport, the last frame's beam contact pulled her toward the old beam.
  `_beam_under` now checks the contact is under her feet.

## 2026-11-11: WO-002 done: **the owner locked the look** ("The look is great - verified on the Deck")
ART_DIRECTION.md is no longer a proposal.
**Superseded, 2026-11-11:** the character concepts (Nim's two outfits, Vesper's suit) were replaced by the cartoon
restyle (ART_DIRECTION §1). They now sit in `.wip/style_test/concepts_superseded/` and
`.wip/concepts/superseded_wo002/`. The props and the world look stand.

**Credits: 108 spent** (99 approved, plus 9 for the approved garb redo). About 7,953 left. Task IDs are in
`.wip/meshy/wo002_concepts.json` and `wo002_props.json`.
- **Everything to review is in `.wip/style_test/`:**
  - `concepts/`: Nim's garb (the redo), Nim's suit and Vesper's suit, three views each.
  - `props/`: the three prop concepts and the cleaned models' Blender previews.
  - `shots/`: six views of the corner (`start`, `club_door`, `crossroads_low`, `square`, `poster`, `high`).
- **The shader kit:** `shaders/` and `core/look.gd`, described in ART_DIRECTION.md, "The shader kit".
- **Props:** `tools/props.py` (Blender, headless: `blender -b --python tools/props.py`) cleans `.wip/props/meshy/*.glb`
  into `assets/props/`. It scales to height, puts the origin at the bottom centre, makes them matte, and renders
  previews to `.wip/props/previews/`. Gas lamp 6.3k tris at 3.6 m, advertising column 4.6k at 3.0 m, bench 6.2k at
  0.95 m.
- **The corner (`levels/style_test/corner.gd`):** an Old Quarter crossroads at night in rain, built in code.
  - The Velvet Rope on the NE corner, townhouses, a square, six lamps, a Decency League poster.
  - The greybox Nim is toon-lit in her coat colour, with ink and her rim light.
  - Box collision on everything.
- **`core/level.gd` (`Level`):** the shared base. It spawns Nim and the camera, resets her when she falls, shows the
  age gate, and has `block()`, `collider()` and the Back / Tab flip. `main.gd` uses it too.
- **Checks:**
  - Probes (headless): `gate_probe`, `move_probe` and the new `corner_probe` (kerbs up and down, walls and lamps are
    solid) all pass. The logs are clean, in windowed runs too.
  - Windowed: `godot --path . --disable-vsync -s tools/world_shots.gd -- <scene> <dir>` writes the views with their
    frame rate and draw calls. The corner: 850–1,100 fps on the dev PC, 89–175 draw calls, at most 320k triangles
    (shadow pass included). Nine Lives' Lust drew 362 calls and held 90 fps on the Deck.
  - The owner checked the corner on the Deck and approved it. No fps figure was recorded; measure one when a world
    is heavier than the corner.
- **Fixed along the way:**
  - A ReflectionProbe leaked 7 textures at exit. It's gone; the puddle glints are toon specular.
  - Headless "material is null" errors on shutdown: `Look.dress` now uses `material_override` on single-surface
    meshes.

## Next
**The systems are done (WO-001 to WO-010). The art (WO-011 to WO-013) restarts with the whole-cast cartoon
restyle (ART_DIRECTION §1, "Concepts").**
1. **First, the turnaround concepts, before any 3D or any other cast member:**
   - Nim's anchor;
   - Nim's second outfit, by image-to-image from the anchor;
   - Vesper's suit.
   Quote the credits and wait for a yes, then show the owner.
2. Then WO-011's 3D, on the existing pipeline (`tools/nim_build.py`, `tools/nim_poses.py`).
3. Then WO-012 and WO-013, batch by batch.

Or WO-014's vertical slice (the prologue, the club, the Pier) if the owner wants a playable world before the art.

Where things live:
- Movement feel: the constants at the top of `player/nim.gd`.
- The suit and Commands: `player/nim_suit.gd`.
- Gear: `player/nim_gear.gd`; the crop in `player/nim_combat.gd`; the rope swing in `player/nim.gd`.
- Fighting: `player/nim_combat.gd`.
- Goons: `core/enemy.gd`.
- Stealth tuning: `core/sight.gd`, `core/light_meter.gd`, and the noise constants in `player/nim.gd`.

## Waiting on the owner
- **How many Keys the hub has.** STUDY.md counts 70 Keys in all (10 per world, 10 in the hub), but WO-021 lists "Hub
  secrets (10 Keys)" as well as each world's tin paying a hub Key. Assumed for now: the six tins are six of the hub's
  ten, plus four secrets (`data/worlds/hub.json`). If they're extra, the hub has 16 and the total is 76.
- **The rank thresholds** (1, 6, 14, 22, 32, 42, 58) and **rank names** (none yet).
- **The collection tin's label,** "GIVE GENEROUSLY to DECENCY" (`core/pickup.gd`, `# OWNER REVIEW`).
- **Writing (WO-009):**
  - **The banned-word list** (`data/writing/banned_words.json`) is a proposal. It bans "consensual" as well as
    "consent", which would stop a line describing Lull's craft as DESIGN.md does ("consensual hypnosis"); keep or
    drop it.
  - **The voice sheets** in `docs/WRITING.md`, Nim's above all (she had none).
  - **Vesper's course lines** (`data/dialogue/course/vesper.dialogue`, `# OWNER REVIEW`).
  - **The morning paper card** (`data/cutscenes/course_paper.json`, marked for review), and the placeholder mastheads
    "THE EVENING PAW" and "RADIO PURRLANDS" (`core/dialogue.gd`).
- **UI (WO-010):**
  - **The papers after each world:** the three written from the briefs (`data/cutscenes/paper_pier.json`,
    `paper_primrose.json`, `paper_press.json`, all marked).
  - **Whether the Docks, the Retreat and the Ball get one,** and what it says (their briefs have none).
  - **The menus and HUD on the Deck:** the title, the settings (try a remap on the pad), the HUD's prompts.
- **Movement, combat, stealth, the suit and the gear on the Deck:** the test course, lanes G (fight and bind), H (the sentry and
  the sleeper), I (the stealth yard), J (the club) and K (lessons and gear).
- **New lines** (`# OWNER REVIEW`):
  - the bound goon's note, "For the police. No need to thank us." (`core/enemy.gd`), and the woken person's line
    (`core/entranced.gd`);
  - the staff's replies ("Yes, Mistress.", "At once.", "Of course.", `core/staff.gd`);
  - Nim's refusal ("Not in the suit. Not while they're watching."), "Thank you.", and "She holds the room."
    (`player/nim_suit.gd`);
  - Vesper's teaching line, "Nobody looks up. Live there." (`levels/test_course/course.gd`), and the Scold's "SIT."
    (`player/nim_gear.gd`).
- **Words on the street** (`# OWNER REVIEW` in `levels/style_test/corner.gd`): the poster and the club's plaque.
- The content card's wording (`core/age_gate.gd`, `# OWNER REVIEW`).
- Review everything marked `Owner review` in the world briefs, the finale above all.
- Decide on the post-credits coda (Vesper taking a ticket in an afterlife's waiting room).

## 2026-11-11: WO-001 done (project scaffold)
- `project.godot` (Forward+, 1280x800, physics interpolation, MSAA 2x), `.gitignore`, `.gitattributes` (LFS), the
  `Linux / Steam Deck` export preset.
- Autoloads: `Controls` (every binding in code, pad first; table at the top of `core/controls.gd`), `Game` (flags,
  collectibles, save in `user://progress.json`, settings apart in `user://settings.cfg`; probes set
  `Game.persist = false` or `VESPER_NO_SAVE=1`), `Audio` and `Dialogue` (stubs), `Hud` (hint, notes, fps, minimal
  pause, `age_gate()`).
- The age gate and content card (`core/age_gate.gd`), asked once per machine, pad-first.
- The test room (`main.tscn`), the greybox capsule (`player/greybox_nim.gd`) and the follow camera
  (`core/follow_cam.gd`, ported from Nine Lives).
- Probes send real input events through `tools/probe_input.gd`.
