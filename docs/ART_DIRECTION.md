# Art direction and pipeline (locked by the owner, 2026-11-11, after WO-002's style test on the Deck; characters revised the same day)

Vesper's game must look like its own game. No Nine Lives asset is reused: not its models, textures or shaders. Its
tools and lessons carry over.

**Owner, 2026-11-11 (WO-011 stopped):** "The whole cast reads too realistic." Every character moves to Kiara's
style in Nine Lives (its "bureaucratic toybox" soft-sculpt cartoon, `nine-lives/3d/docs/ART_DIRECTION.md`). That
covers Nim, Vesper, the crew, Swyne, the goons and the bosses. §1 and the character pipeline are rewritten for it.
- **Same family, not the same game:** no Nine Lives design, character, concept or asset is copied or used as a
  reference image. Vesper is designed fresh from DESIGN.md.
- **The WO-002 character concepts are superseded:** Nim's garb and suit and Vesper's suit in `.wip/concepts/` (the
  seven-head comic style). The WO-002 *props* and the world look stand.
- **What stays from velvet noir:** everything that isn't a character's form.
  - **The night palette** (§3).
  - **The velvet-red rule:** only the Claw, the club and their marks wear crimson.
  - **Ink outlines** (§4): the rounder forms take an inverted hull even better.
  - **The toon ramp and the night lighting:** sodium lamps, neon, moonlight, wet streets, fog and rain.
  - **The painted world, and the shader kit.**
  - **The contrast is the point:** soft vinyl people in a hard, wet, inked city, as Kiara's soft people sit in a
    hard office.

## The one-liner
**Velvet noir.** A painted, inked comic-book night city with anthropomorphic adults: rain on the cobbles, sodium
lamps and neon, deep indigo shadow, and the Velvet Claw's red cutting through it.
- **References for the feel (never for content):**
  - *Blacksad*, the anthro noir comics: watercolour light, adult animal characters, posture as character;
  - *Arcane*: painted textures on 3D forms;
  - the *Sly Cooper* games: a night-city rooftop platformer, readable from above;
  - *Batman: Arkham* games: a city that's always night and always wet.

## 1. Characters (owner, 2026-11-11: every character, soft vinyl figures in a painted noir city)
**The approved reference** ("That's the look"): Nim's garb in `.wip/concepts/v4/nim_garb_*`, and her suit in
`.wip/concepts/v5/nim_suit_*`. Every new character concept is judged against them.
- **The look, for the whole cast:** soft-sculpt cartoon adults. Rounded, clay-smooth, simplified forms; no fur
  strands, no realism. This covers Nim, Vesper, the crew, Swyne, the goons and the bosses.
  - In the family of Nine Lives' Kiara. Velvet noir's palette, ink outlines and light still frame them (§3, §4).
- **Proportions:** a big head, **about 4.5–5 heads tall** (it was seven). Slim limbs, readable silhouettes.
  - **The head ratio is locked at Nim's v6 concept** (owner, 2026-11-11: "this is about the limit").
  - No character's head is bigger relative to her body. With eyes this size, a bigger head starts to look young.
  - Her figure and her lidded eyes carry her adulthood. Every cast member keeps both.
- **Unmistakably grown:** a big head must never read young. Every character keeps adult signals:
  - a mature face: defined cheekbones and muzzle line, lidded eyes with liner and brows, no round baby cheeks;
  - adult proportions below the neck: a defined waist and hips, and legs at least half her height;
  - adult posture and attitude.
  - **The floor is 4 heads.** A short character (Grizelda) is short and broad, not small and young.
- **Faces:**
  - Large, expressive cartoon eyes, with lids that close, liner, and a bright catchlight. The eyes are where shine
    lives.
  - A short, simplified muzzle: a cartoon nose pad and mouth line, not a real animal's face.
  - Ears big enough to act.
- **Markings are flat painted shapes,** like printed vinyl: Nim's clouds, rosettes, spots, stripes and ear tufts,
  all with clean edges. No fur texture, no strands, no brush noise on characters.
  - **Markings name the species at a distance** (owner, 2026-11-11, Nim's review). Make them big, bold and where
    they show past the clothes:
    - cheeks, shoulders, arms, and especially the tail;
    - never a few small spots on the forehead.
  - **Nim's clouds are the clouded leopard's:** large blotches with dark edges and lighter centres. On her garb
    they're all that says "clouded leopard".
- **Tails are shown, not hidden** (owner, 2026-11-11). In concepts the tail sweeps out to the side, clear of the legs,
  in front and back views.
  - Nim's is thick and long, nearly her body length, with ringed clouds. It does her balancing.
- **Hands read as hands** (owner, 2026-11-11): at least three fingers and a thumb, clearly separated, never mittens.
  The cast climbs, grabs, points and binds.
- **Ears follow the species, and they name it in silhouette** (owner, 2026-11-11):
  - **The big cats** (Nim's clouded leopard, Silke's snow leopard, Augusta's lioness, Bastion's jaguar): short,
    wide-set, with rounded tips. Not round and tall like a mouse's (Nim's v6). Not tall and pointed like a house
    cat's or a lynx's (Nim's v7): that reads domestic, and too close to Kiara.
  - **The pointed, tufted kinds:** Vesper's bobcat and Rivet's caracal have tall tufted points. Lull's serval has
    tall, wide, rounded ears. Grizelda's Pallas's cat has low, wide-set ears.
  - **The test:** from behind, or in shadow, Nim must read as a big cat, never as a house cat.
- **Gear is simplified:** a few big shapes over many small ones. Two pouches, not eight. One strap, not five. A
  costume reads from its silhouette and two or three colour blocks.
- **The Velvet Claw's women are well endowed:** curvy, full figures, shaped by corsetry, latex and tailoring.
  Everyone fully covered. Curves stay in the cartoon proportions.
  - **Owner, 2026-11-11: a Domme suit may show cleavage** (Nim's has an open, plunging neckline). That's still
    suggestive, never nudity. "Fully covered" means no nudity; night garb stays closed.
  - **Owner, 2026-11-11, for the rest of the cast** (Vesper and the seven sisters, everyone but Nim): **very
    well endowed, more so than Nim,** with **exposed cleavage**, especially in their Domme suits (open, plunging
    necklines, as on Nim's suit). Every concept prompt for them says both.
    - **Still no nudity:** cleavage, never nipples or anything below the neckline. Night garb may stay closed.
    - Their builds still separate them (the silhouette table above).
  - **Owner, 2026-11-11: every member of the Velvet Claw has large breasts:** Vesper, Nim and all seven sisters.
    Every concept prompt for a Claw member says so. Their builds still differ (Augusta broad, Lull leggy, Grizelda
    round), so the silhouettes still separate them.
- **Heights in heads set the pecking order** (one head = the character's own head, crown to chin):
  - Vesper is tallest, about 5.5 heads ("tall, calm"), and she still has a big expressive head;
  - Nim and most sisters are 4.5–5;
  - Grizelda is about 4: tiny, round, fifties, grey at the muzzle;
  - goons are broad and blocky, 4–4.5;
  - Swyne is a soft, top-heavy 4.5;
  - bosses are 4–5.5, each built on one big shape.
- **Every sister has two outfits** (DESIGN.md):
  - a Domme suit for the dungeon: latex, leather and corsetry, with a red accent;
  - night garb for the work: matte, dark, practical.
  - **The two outfits must differ in silhouette, not just colour** (owner, 2026-11-11). The garb carries one or two
    practical shapes the suit never has: knee pads, a rope coil at the hip, a hood, a satchel.
    - **Nim's garb:** knee pads, plus the Claw's night uniform (below).
    - The suit keeps its corset, its heels and the open neckline.
- **The Claw's night uniform** (owner, 2026-11-11: "the Velvet Claw's calling card while staying covert"). Every
  sister's night garb carries the same three pieces, varied per sister:
  - **A chest-and-hip harness with rings,** readable as both a climbing harness and a Domme's.
  - **A half mask,** black outside with a velvet-red lining.
  - **Black cord in a red velvet wrap,** coiled at the hip. It replaces a plain rope coil.
  - **The Claw's knot** (DESIGN.md, Bind) is their emblem, embossed tone on tone on the harness buckle and the mask.
    - It's never printed in a contrasting colour: it's seen up close, never from across a street.
  - **Red only inside or as accents:** the mask's lining, the cord's wrap, maybe a ring or a stitch. Every outer
    surface stays matte black and charcoal. The garb is covert; the red is for whoever gets close enough to see it.
  - **Varied per sister,** so the uniform never erases the silhouette rule. The harness, mask and cord change cut
    and size:
    - Augusta wears a broad, formal harness;
    - Silke carries the longest cord (rope is her craft);
    - Dash wears a minimal, racing harness;
    - Rivet's harness is loaded with gadget loops;
    - Lull's mask is sleek, with a spiral-free plain lining;
    - Grizelda's harness is short and stout;
    - Bastion's harness spans her shoulders.
  - Vesper's night garb sets the pattern (WO-012).
- **The Claw's masks** (owner, 2026-11-11; lore in DESIGN.md, "The masks"). Like an order's members, the sisters
  share one style, but every mask is personal. **Each sister is identifiable by her mask alone,** the way the
  silhouette rule works for her body.
  - **All share:** a black base, velvet-red piping, the brass knot somewhere on it, and Rivet's build.
    - Never gag-shaped: nothing in or over the mouth that holds it, nothing that locks.
    - Kept on for dialogue and cutscenes (owner, Deck review 3, 2026-11-13; it was off, and popping it on and off looked odd).
    - Worn with the night garb only, never the Domme suit.
    - **Never silver skull faces,** and nothing that reads as a horror mask.
  - **The variants:**

    | Sister | Mask |
    |---|---|
    | Nim | the velvet muzzle with the eye band (below) |
    | Augusta | a masquerade-ball mask with brass mane filigree |
    | Silke | featureless, with a cord-braided edge and a mesh veil over the lower face |
    | Dash | a racer's visor-goggle with red tear lines |
    | Rivet | a full gas mask, overbuilt |
    | Lull | lower face only, eyes always bare, with a spiral grille. The spiral is brass and still, never glowing: hers, not Swyne's cold blue glow |
    | Grizelda | a flared brass speaking-trumpet grille (the Scold's amplifier) |
    | Bastion | a plain armoured half mask |
    | Vesper | **no mask:** she's the Claw's open face |

  - **Concepts:** one lineup of the seven masked heads comes first (owner), before any individual turnaround.
  - **Build:** like Nim's, each mask is its own mesh on the head bone, a Meshy mask-only model fitted in
    Blender (`nim_build.py`'s `fit_meshy_mask` is the template).
- **Nim's velvet muzzle** (owner, 2026-11-11; lore in DESIGN.md): hers alone, worn with the half mask.
  - **The shape:** a rigid, sculpted leather mask shaped to her snout, with a brass breathing grille at the front
    that has the Claw's knot worked into it. Straps run behind her ears to a back buckle, with a quick-release
    catch.
  - **It must read as protective gear** (respirator, fencing mask), never as a gag. Her mouth sits closed inside it,
    nothing holds it open, and there are no locks or padlocks.
  - **The colours (owner):**
    - black velvet outside, matching the eye mask;
    - velvet-red piping round the edges, with the red lining showing at the rim where it meets her fur;
    - **the brass grille with the knot is the signature at a glance:** it catches the light, so there's no red
      block on her face.
  - **Brass is its one shine:** the grille, the buckle and the catch.
  - It's off in dialogue and cutscenes, so her face acts there. The `mask_on` / `mask_off` clips click it into place.
    - **Footwear splits the outfits** (owner, 2026-11-11): Domme suits have heeled boots (the Domme walk), and
      night garb has flat soles (climbing). Every view must agree. A heel shows from the front too: a raised
      heel and a pointed, arched foot, never a flat sole.
- **Silhouette rule (kept, scaled to the new proportions):** each sister is identifiable from her shadow alone, by
  one big shape and her height:

  | Sister | Heads | Shape |
  |---|---|---|
  | **Vesper** (bobcat) | 5.5 | the tallest: a long, straight, still column, with tufted ears and a bob tail |
  | **Augusta** (lioness) | 4.5 | broad: a wide, solid barrel, with a mane-like updo on top |
  | **Silke** (snow leopard) | 5.2 | tall and narrow, with a thick tail as long as she is |
  | **Dash** (cheetah) | 4.8 | lean, wiry and forward-leaning, with a whip of a tail |
  | **Rivet** (caracal) | 4.3 | compact and square, with huge tufted ears and a tool rig |
  | **Lull** (serval) | 5 | most of her is leg: long legs, a small waist, tall ears |
  | **Grizelda** (Pallas's cat) | 4 | tiny and round: a ball with a flat head and a scowl |
  | **Bastion** (jaguar) | 5 | all shoulders: a wedge, wide on top, narrow at the hips |
  | **Nim** (clouded leopard) | 4.7 | the hero, mid-height: an hourglass and a long, thick, ringed tail |

  - **The check:** fill each concept's silhouette in black. Line them up at scale. Every one must be nameable.
- **Fur is never simulated:** no strands or cards. On characters it's flat colour blocks and printed markings (above).
- **Enemies are never felines.** Each world's goons are one species in one uniform, so a crowd reads as "his people"
  at a glance.
  - Goons are blocky, soft and comic: one uniform shape, big hands, small eyes under heavy lids.
  - Bosses each get one exaggerated shape: Laffer's grin, Gander's neck, Tusk's bulk, Strix's round spectacles,
    Grubb's huge digging claws and Tupping's curled horns.
  - **Swyne:** a soft, pear-shaped boar in cream and gilt, all jowls and smile.

## 2. Surfaces
- **Characters are painted vinyl:** matte, flat colour blocks with gentle shading painted in. Normal maps carry the
  big sculpted forms only.
- **The world is painted:** brush strokes in its colour maps; normal maps for big forms.
- **Shine means something:**
  - **Eyes:** every character's catchlight.
  - **Latex and patent leather:** the Domme suits, and Swyne's toys.
  - **Wet surfaces:** cobbles, roofs, the Docks. The night is always wet.
  - **Brass:** the receivers, the clock tower, the toys' hidden parts.
- **Everything else is matte.**

## 3. Colour
- **The night palette:** indigo and teal shadows, warm sodium orange lamps, cold moonlight from above.
- **The Velvet Claw is red:** a deep velvet crimson. Only the sisters, the club and their marks wear it. Swyne's
  people never do.
- **Swyne is cream and gilt:** clean, respectable, "decent". The Coalition's posters are cream and navy.
- **Nim:** a smoky grey-brown coat with dark cloud markings, and pale green eyes. The player must read against every
  world, so worlds stay mid-dark and she carries a light rim.

| World | Palette |
|---|---|
| The Old Quarter (hub) | wet cobbles, gas lamps, velvet red at the club's door |
| The Pier | neon pinks and blues on black sea, candyfloss |
| Primrose Close | sickly suburban pastels under street lamps, lit net curtains |
| The Docks | storm greys, searchlight white, rust |
| The Retreat | spa white and steam, a cold blue spiral glow |
| The Decency Press | furnace orange, soot, cream paper |
| The Decency Ball | gold, crystal, cream, one red figure on the floor |
| City Hall | stone, brass clockwork, moonlight |

## 4. Rendering
- **A toon light ramp** with soft painted steps, not hard cel bands.
- **Ink outlines** on characters and key props. An inverted hull is cheap and works on the Deck. Line weight
  thickens toward the bottom of each shape.
- **Fog and rain** give depth. Puddles reflect the lights; a screen-space reflection is optional (Deck budget).
- **Light shows hiding:** shadows are where Nim is safe, and the game must make light and dark readable at a glance.
  A visible light level on Nim is a gameplay readout, not decoration.

## 5. Props carry the jokes
- **Big and readable, with funny small print:** Swyne's posters, Coalition pamphlets, toy boxes, signs, rosettes.
- **Text is mesh or `Label3D`, never Meshy's scribble.**

## 6. Animation
- **Nim:** a predator's economy of movement: low, smooth, then explosive. A long tail that does the balancing.
  Her dignity goes when things go wrong: a tail floof, an ungainly landing in a suit.
- **Vesper:** she never hurries. Every move in her animation set is slower than anyone else's, and still arrives
  first.
- **Goons:** broad comic timing; they take falls well.
- **The Domme suit changes Nim's walk.** A poised strut in the suit, a prowl in garb. Both are core clips.

## 7. Content lines (binding, from DESIGN.md)
- Every character is an upright, anthropomorphic, unmistakably grown adult. No child-coded designs.
- Suggestive only: latex, leather, rope, corsets, collars, implication. **No nudity, sex acts or genitalia in anything
  an agent authors.** Swyne's toys are shown as boxed products and vague shapes with a spiral glow, never in use.
- People in trances are never posed for a joke.

---

## The pipeline
Tools: Godot 4.7.1 (GDScript), Blender (through the Blender MCP), Meshy (through the Meshy MCP), GIMP (through the GIMP
MCP) for 2D (UI, posters, decals).

### Credits
**Meshy credits are shared with Nine Lives.** Check the balance first (`meshy_check_balance`), say what each batch
will cost, and wait for the owner's yes. Rough costs from Nine Lives:
- A concept image: 9 (nano-banana-pro).
- A prop: about 24 (meshy-t2.5 smart topology plus the meshy-n1 texture, 15) with its concept.
- A character: about 60 (concept 9, meshy-7.1 with texture 30, remesh 5, rig 5, three clips 9).
- **A rough budget for the whole cast** (Nim's two outfits, Vesper's two, seven sisters' two each, Swyne, 7 bosses,
  8 goon types): about 40 models, **about 2,400 credits**. Props on top of that: lean on Blender and code (below)
  before Meshy.

### Who makes what
| Asset | Made by | Why |
|---|---|---|
| Character concepts | nano-banana-pro: an anchor turnaround from text, other outfits by image-to-image from it | one character, not one per outfit |
| Nim (hero) | Meshy source, then rebuilt in Blender to a custom rig | she's the player: she needs her own clips, outfit swaps, tail and face |
| Vesper, the sisters, Swyne, bosses | Meshy end to end: concept, model, remesh, auto-rig, library clips | fast, consistent, cheap enough |
| Goons | Meshy, one model per species, tinted variants | crowds |
| Freestanding props with a silhouette | Meshy (meshy-t2.5 + meshy-n1) | the painted look |
| Anything gameplay measures: ledges, beams, rails, crates, doors | Blender script or code (bevelled boxes) | exact sizes, cheap |
| Architecture | code-built kits on painted surface shaders | parametric, no UV work |
| Text: signs, posters, labels | mesh text or `Label3D`, posters as GIMP decals | readable |

### Concepts, for every character (owner, 2026-11-11)
1. **One identity anchor per character:** a multi-view turnaround (front, side, back) in her first outfit, made from
   text (nano-banana-pro, 9).
   - The prompt states the head count, the adult signals, the flat markings and the simple gear (§1).
2. **Every other outfit comes from the anchor by image-to-image** (nano-banana-pro, 9), with the anchor as the
   reference.
   - The prompt says "the same character": same head, face, eyes, markings, body, height and tail. Only the clothes
     change.
   - **Never generate a second outfit from text alone.** Nim's first restyle did that, and her garb and suit came out
     as two different leopards.
3. **The review, before any 3D:**
   - count the heads: no bigger a head than Nim's v6;
   - check every adult signal;
   - put both outfits side by side: the same character, but a different silhouette?
   - run the silhouette check against the cast so far;
   - check the species markings are big and visible at a distance;
   - check the tail is visible and the right length;
   - check the hands have separate fingers;
   - check the ears are a big cat's;
   - check all three views agree: the head, chest and toes face the same way.
4. The owner approves each turnaround. Rejected or superseded concepts move to `.wip/concepts/rejected/`, and the
   Meshy task ids are kept in `.wip/meshy/`.

### The hero (Nim)
1. Her concepts, as above: the anchor and the second outfit, approved by the owner.
2. Meshy multi-image-to-3D at full resolution (meshy-7.1) per outfit, as the sculpt source.
3. In Blender (`tools/nim_build.py`): a voxel remesh (about 3.5 mm), then a decimate to budget. **Never decimate
   Meshy's raw mesh:** it folds into blotches (a Nine Lives lesson).
4. Bake colour and normals from the source onto fresh UVs. Keep the colour flat (§1): flatten any fur noise Meshy adds.
   - **Seams (owner, 2026-11-11: Meshy's models artifact around seams).** Before export, run `tools/seams.py` on
     every textured Meshy mesh (`nim_build.py -- seams`):
     - it finds the texels the mesh uses;
     - it grows each UV island 16 texels outward in its own colour;
     - it fills the rest of the unused space.
     Mipmaps then never blend black or a neighbouring island into a seam.
   - **Decimate with `seams.decimate_safe`** (it delimits by seam and UV), never a plain collapse. That stops
     faces collapsing across a seam.
   - **This applies to the whole cast and to props,** not only Nim.
   - **Paint the markings at this step** (owner, 2026-11-11; the concepts got them wrong, and no further concept
     round is wanted):
     - Nim's markings are **clouds, not spots**: big, irregular blotches with darker rims and lighter centres. The
       tail in the v7 concepts is the closest guide.
     - Replace every small round dot on her face and chest with cloud shapes.
     - Put big clouds on her cheeks, shoulders and arms wherever fur shows.
     - Remove the clouds printed on the back of the garb's cloth: markings live on fur only.
5. **One rig per outfit with identical bone names** (what WO-011 built): the wardrobe swaps the whole model. Both
   outfits share every clip.
   - **Masks and other removable gear are their own meshes, never part of the body sculpt** (owner, 2026-11-11).
     Meshy fuses anything in the concept into the face, and then the "mask off for dialogue" beat is lost.
     - The body's Meshy source is always the **unmasked** concept.
     - Nim's muzzle, eye mask and grille become a separate mesh, parented to the head bone like an outfit mesh, and
       shown or hidden by `mask_on` / `mask_off`.
     - The masked concept is only the mask's reference.
     - **Plan the mask's build before spending on the body model.** Two options:
       - (a) a mask-only Meshy model from a cropped or generated mask concept, fitted to the head in Blender;
       - (b) a Blender-scripted shell, shrink-wrapped and offset from her snout, with the grille as a separate
         piece.
       (b) fits best and costs no credits; (a) is the fallback if (b) can't match the concept's look.
6. A custom rig: a humanoid core, a long tail chain (balancing is gameplay), ears, and a face with shape keys
   (blink, brows, jaw).
   - **Nim's brows are her whole range on missions** (owner, 2026-11-11). Masked, she acts with her eyes and brows
     alone, so they get strong keys:
     - narrowed (both brows down and in, with the lids half down);
     - raised (both up);
     - one up, either side;
     - plus the blinks and the squint.
     The big cartoon eyes carry it. Check each key at gameplay camera distance, masked.
   - **Bone heat fails on Meshy meshes:** use distance weights inside regions measured along the surface.
   - The cartoon head is big and the eyes are large, so the face keys get more room than on the seven-head sculpt.
7. Clips posed in Blender by script (`tools/nim_poses.py`: keyed poses solved with two-bone IK), Cascadeur for
   anything physical. The clips' hand and ankle offsets are rescaled to her shorter limbs.
8. **Budget:** 100–130k triangles; a 4K colour atlas and a 4K normal map. Flat colour lets a 2K atlas pass if
   the Deck needs it.

### The supporting cast
- **Concepts as above:** an anchor turnaround, then the second outfit from it by image-to-image.
- **Models:** one Meshy model per outfit (two per sister), a remesh to 50–80k, the Meshy humanoid rig, and 3–6
  library clips (idle, walk, talk, a signature move).
  - Nine Lives auto-rigged its big-headed toybox cast this way, so the proportions shouldn't trouble the rigger.
  - **Test the first one before batching.** Fall back to the hero pipeline's custom rig if the head or tail rig badly.
- **As built (2026-11-11, `tools/cast_build.py`; stages: prep, chains, clips, measure, mask, seams, export):**
  - **The models:** Meshy multi-image (4K, Ultra), then a Meshy remesh to 150k, then Meshy's auto-rig. Meshy's
    weights deform cleanly in the walk, so the rig stays and gets added to.
  - **Weld first:** glTF splits every vertex on a UV seam (15,000 islands). Weld them back before any surface
    walk or floor test. The UVs stay per corner, so the seams survive.
  - **Decimate:** to 60k with `seams.decimate_safe`; textures go to 2K.
  - **Tail and ears:** Meshy's rig has no bones for either.
    - **Tail:** found on the surface. The tip is the furthest point from the head, away from the hands and legs.
      Rings walk up from it and stop at the hips or where the body widens.
    - **Ears:** the highest point out to each side, reaching 35% of the way down to the head joint.
    - Pin a tip in BODIES when the search misses (Vesper's stub tail, Augusta's suit tuft).
  - **Clips:** idle and talk are keyed as rotations about world axes (Meshy's bone rolls vary), with the arms
    brought down from Meshy's A-pose. Tail sway goes on every clip.
  - **Masks:** sized by face width, as the concepts size them; eye spacing and face height mislead on cartoon
    heads. Then Nim's radial push, the brass recolour, and the mask on the head bone.
    - **No ink outline on a mask:** on a thin shell the inverted hull covers the mask's own face.
  - **Floor discs** (a concept's ground shadow fused to the boots, Lull's) are removed per body, never by a
    general test: a general test clipped wide boots and heels.
- **Goons:** one anchor per species in its uniform; variants are tints, not new concepts.
- **Budget:** 30–80k triangles, 2K textures. Bosses up to 100k.

### Props
- Concepts on one sheet per world, so a world's props share a hand.
- A cleaning script (scale to height, origin at bottom centre, matte, 1K textures for small props) in
  `tools/props.py`, run in Blender.
- Godot keeps box collision; props never use mesh collision.

### Where files live
- Sources: `.wip/` (gitignored): concepts, raw Meshy downloads, `.blend` files with packed textures.
  **Godot doesn't import dot-folders.**
- Game assets: `assets/` (Git LFS for `.glb` and `.png`).
- Task IDs for every Meshy job in `.wip/meshy/<batch>.json`, so nothing is paid for twice.

### Performance
- **The Steam Deck is the target.** 60 fps minimum in every world, 90 where it's free.
- Measure with a frame-rate probe at fixed spots in each world, and a draw-call count.
- Distance culling for small props; one shadow-casting light per area.

### The shader kit (built in WO-002, locked with the look)
- **`shaders/toon_light.gdshaderinc`:** the shared light. It has two soft steps (`ramp_soft`, `ramp_split`), and
  lamp pools get a stepped edge: a bright core, a dimmer ring, then dark, so it's easy to see where Nim can hide. The
  specular glint is crisp and appears only where `v_gloss` says the surface shines.
- **`shaders/toon.gdshader`:** characters and props. A colour or texture, `gloss` (latex, brass), `rim` (Nim's rim
  light) and `glow` (the warm part of a texture glows, like the lamp's glass).
- **`shaders/painted.gdshader`:** architecture in world space with no UVs. Patterns: plaster, brick, cobbles,
  flagstones, slate and planks. It adds brush-stroke mottling and `wet` (darker, glossier), and on floors `puddles`
  with rain rings. Joints fade into an even tone past about 10 m so they don't shimmer.
- **`shaders/outline.gdshader`:** the inverted-hull ink line, thicker at the bottom. Smooth meshes only (it cracks at
  hard edges, so boxes don't get one).
- **`core/look.gd` (`Look`):** `toon()`, `painted()`, `outline()`, and `dress(node, outline, gloss, glow)`, which turns
  an imported Meshy prop into toon plus ink. The palette constants live here too.
- **Rain:** a GPUParticles3D box of 2,600 thin streaks that follows the camera, faded out within 1.5–5 m of the lens.
  **Fog:** depth fog plus a low height fog. **Glow** for the lamps and windows. **No reflection probe:** outdoors it
  reflected from the wrong place, cost Deck time, and leaked at exit.
- **Batching:** a level's decorative boxes (window frames, panes, sills, bands) go into one MultiMesh per material.
  The corner draws 90–175 calls.

### Don't
- Reuse anything from Nine Lives, Banjo, Conker or anyone else.
- Realistic fur, skin or photo textures.
- Plastic-toy shine on characters.
- A grimdark palette: it's noir with jokes, not horror.
- Cheesecake posing in gameplay. The Claw's women are confident, not posed for the camera.
