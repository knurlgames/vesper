# Vesper's Kinky Kapers: design (working title)

Decisions are the owner's unless marked **proposal**. The research behind the structure is in [STUDY.md](STUDY.md).

## Premise
- **The Purrlands.** A secret order of feline Dommes, **the Velvet Rope**, fights crime. They're all women, a
  sisterhood like the Amazons, and they run a club with a working dungeon as their front.
- **Mistress Vesper** (bobcat) leads them. She's the mentor, not the player, and she dies at the end, on her own terms.
- **Councillor Swyne** (boar), the villain, is a hypocrite: by day, the Purrlands' loudest decency campaigner, out to
  shut "those clubs". By night, he floods them with contraband, mainly hypnotic sex toys, to take the Purrlands over.
- **Linked to Nine Lives only through Vesper.** This is her life before she died.

## The hero
- **Nimbus** ("Nim" to the crew), a clouded leopard, a woman.
- **Her velvet muzzle** (owner, 2026-11-11): a rigid, sculpted leather mask shaped to her snout and wrapped in
  black velvet with velvet-red piping, and a brass breathing grille that has the Rope's knot worked into it. Straps run behind her ears to a
  back buckle, with a quick-release catch. She wears it with the eye mask.
  - It reads as protective, dominant gear (respirator or fencing-mask energy), **never a gag:** nothing holds her
    mouth open, and nothing locks.
  - **Rivet built it.** It scrambles Nim's voice, and it filters the trance at the Retreat and in the broadcast.
  - **On while she's covert, off for dialogue and cutscenes.** It clicks on and off with an animation (WO-011's
    clips).
- **Proposal:** one of Swyne's first test subjects. The Rope pulled her out of a trance, and she asked to join. The
  toys no longer work on her. She's the best climber in the house.

## The crew
**Owner, 2026-11-11:** the whole cast is drawn in a soft-sculpt cartoon style, about 4.5–5 heads tall and
unmistakably adult (ART_DIRECTION.md §1).
All grown women and well endowed: curvy, full figures, large breasts (owner, 2026-11-11: every member of the Rope;
the rest of the cast are more endowed than Nim, with exposed cleavage, especially in their Domme suits),
everyone fully covered. Each has **a Domme suit for the
dungeon** and **night garb for the work**.

| Who | Build, age | Style | Personality |
|---|---|---|---|
| **Augusta**, lioness | broad, strong, about sixty | protocol, etiquette | the elder, quartermaster of the house |
| **Silke**, snow leopard | tall, lean, thirties | rope | silent and exact |
| **Dash**, cheetah | wiry athlete, twenties | impact (crop) | brash, races everything |
| **Rivet**, caracal | compact, forties | latex, gadgets | sardonic engineer, builds the counter-tech |
| **Lull**, serval | leggy, thirties | consensual hypnosis | offended Swyne cheapened her craft; breaks trances |
| **Grizelda**, Pallas's cat | tiny, round, fifties | brat-taming | grumpy, terrifying |
| **Bastion**, jaguar | all shoulders | bodyguard | filler: the door, the muscle, Vesper's shadow |

## The masks (owner, 2026-11-11)
Each sister works in her own mask: the order shares a style, but every mask is personal. Rivet built them all.
They come off for every conversation (look: ART_DIRECTION §1, "The Rope's masks").
- **The city knows the masks, not the women.** Goons have nicknames for each one, and the papers and Swyne's
  posters use them. **Proposals:**
  - Augusta is "the Duchess";
  - Silke "the Veil";
  - Dash "Goggles";
  - Rivet "the Diver";
  - Lull "the Whisper";
  - Grizelda "the Horn";
  - Bastion "the Wall";
  - Nim "the Muzzle", which she hates.
  The barks are `# OWNER REVIEW`.
- **Wanted posters:** Swyne's Decency League pastes up posters of the masks, a drawing of each one, never a face,
  with a reward. They're props in every world, torn down and pasted back as the story goes. A new mask joins
  the wall when Nim earns hers.
- **Vesper has no mask.** She's the Rope's open face, the one the League can name but never prove anything
  against. At City Hall she stands unmasked in front of the whole Purrlands for the broadcast: the one face they
  all know, and the reason the masks behind her can stay masks.

## Two ways to play a mission (owner: covert, or blend in as a Domme)
- **Covert, in night garb:** rooftops, climbing, shadows, takedowns.
- **Blend in, in the Domme suit:** walk through the front door of Swyne's clubs and parties as a Domme.
- **Detection is always recoverable** (owner). Being spotted never fails a mission. **Proposal** for how:
  - *In the suit:* suspicion builds. If it fills, her cover's blown and the room turns: break line of sight, change at
    a wardrobe, or bluff it down with a Domme's command.
  - *In night garb:* spotted means a fight or a chase. Lose them and the area calms down.
  - What it costs is optional: a collectible or two that pays for an unseen run, never progress.

## The worlds (proposal, first plot)
Nim follows the contraband up the chain, from where it's sold to where it's made to Swyne himself. Each world is one
link in it, hosted by one sister, who gives that world's gear.

**The hub: the Velvet Rope**, a members' club in the Old Quarter with the dungeon underneath. Bastion keeps the door.
The Old Quarter's streets open around it world by world, each area with a wardrobe and fast travel. The hub changes as
the story goes: the toys turn up in the Rope's own dungeon at the start, Swyne's posters go up, and the club is raided
before the finale.

**Sizing (owner, 2026-11-12: "remember the sizing principles from Banjo").** From STUDY.md §1–4, applied to the hub and
to every area added later:
- **Mid-sized, grown by area.** One square, and one short street per world, opened as its world is. Tooie's areas, with
  Kazooie's sense of a path: each street leads to one door, never a web.
- **Small enough to hold in your head.** Tooie's own designers said "all the levels were so big".
  - Rope Square is 40 m across (6 s at a run), and the club on its north side is the landmark from everywhere.
  - Each world's door stands at the end of a street you can see down.
- **Short walks between the things that matter.** The club's door to the Pier's gate is about 70 m (12 s, checked by
  `hub_probe`). A later street should keep its world's door within about 15 s of the club.
- **Fast travel from the start** in every area (not bolted on, Tooie's mistake), and a teacher spot: Vesper, in the
  club.
- **Gates are characters, and their cost is visible.** Each street ends at a rank door showing its Key count.
- **A few hub secrets per area** (Kazooie's hub Jiggies). Seafront Road's is over the rooftops.

| # | World | The link | Host | Lean | Set piece | Boss (never a feline) |
|---|---|---|---|---|---|---|
| 1 | **The Pier**: a seaside boardwalk | toys as arcade prizes | Dash | both, a tutorial for each | a rollercoaster chase | the arcade's owner |
| 2 | **Primrose Close**: the suburbs | home "demonstration parties" for Decency League wives | Grizelda | blend in | a toy party you host as a Domme | the top saleswoman |
| 3 | **The Docks** | where it comes in | Silke | covert | crane and rigging rope swings across a moving ship | the harbour master |
| 4 | **The Retreat**: a wellness spa | where the hypnosis is tested, where Nim was | Lull | both | Nim pretends to be under | the doctor |
| 5 | **The Decency Press** | the League's pamphlet printers out front, the factory behind | Rivet | covert | a production line run backwards | the foreman's machine |
| 6 | **The Decency Ball**, in the Council's grand hall | Swyne in public, selling to the powerful | Augusta | blend in | holding court at the ball while the crew works | Swyne's right hand |
| ★ | **City Hall** | Swyne's broadcast to the whole Purrlands | – | both | Vesper's last stand | Swyne |

**Swyne's plan, revealed a piece per world (proposal):** every toy is a receiver. At midnight on the night the Council
votes on his Decency Act, one broadcast from City Hall's clock tower will put everyone holding one under at once,
councillors included. They vote him emergency powers, and the clubs close for good.
1. The Pier: the toys are being handed out free, everywhere.
2. Primrose Close: they're being sold into councillors' homes on purpose.
3. The Docks: the parts inside come from abroad, labelled "haberdashery".
4. The Retreat: the hypnosis waits for a signal. Nim finds her own patient file.
5. The Decency Press: the broadcast schedule, and gift bags for the Ball. Vesper is called before the Council's
   Decency Committee and named in public.
6. The Decency Ball: the gift bags are swapped, but Swyne knows who the Rope are now. That night the club is raided.
★ City Hall: Vesper's final exam in the raided club, then midnight.

**The economy:**
- **Velvet Roses** (owner, 2026-11-12, in place of "Keys": "a Black or Velvet Rose, awarded for her improved
  performance in the Velvet Rope"): 10 per world and 10 in the hub. The Rope gives a rose for good work. Ranks in the
  order are counted in roses, never spent, and each rank opens the next world's gate in the Old Quarter.
  - Vesper gives Nim her first in the prologue and says what they are.
  - The code and the older docs still say "Key" (`Game.keys()`, `RANK_KEYS`, kind `key`, the world briefs' Key
    tables); everything the player reads says Roses.
  - **Velvet, crimson**, not black (the Rope's own colour, by the velvet-red rule). Black is a quick swap if the
    owner prefers.
- **Contraband:** 100 seized per world. **Rivet turns it into gear** (owner, 2026-11-12): hand it in by talking to
  her at the club.
  - Every 25 is a lure (a gutted toy that buzzes where it lands).
  - Every 100 (a world's worth) is an upgrade, alternating one more health pip and a steadier Composure (slips cost
    a quarter less).
  - Never needed to finish a world. A note the first time Nim seizes some says where it goes.
- **Five people in trances per world.** Freeing all five pays a Key.
- **Vesper:** she teaches a move in each of worlds 1 to 4. She shows her full strength once, at the Retreat.

## The Velvet Rope's house (proposal, 2026-11-12)
**Owner, 2026-11-12:** "the Velvet Rope needs a much larger interior. There should be the usual dungeon/kink rooms and
then a separate backroom where the covert ops planning takes place... I want you to be able to wander and see the
other members working with clients, having a client as a mini game, and even allowing yourself to Switch and be
dominated by one of your sisters."

**The rules it's built on** (the content lines, and Vesper as "the one person who asks"):
- Everything is suggestive, never explicit. No sex acts and no nudity.
- **The dress code** (owner, 2026-11-12: "the clients and Nim in undergarments, or like a bikini if a woman and
  shorts if a man"):
  - **Downstairs:** clients and Nim wear swimwear-level coverage: a full-coverage bikini for women, shorts for men.
    Nothing sheer, and nothing that reads as coming off.
  - **Clients change at the door:** robes hang on hooks by Bastion, so upstairs they're in robes.
  - **Nim's set:** a black two-piece with the Rope's velvet-red piping. She keeps her muzzle and eye mask: her
    identity, and Rivet's filter.
  - **The sisters too** (owner, 2026-11-12: "separate models for the Sisters in bikinis as well"): downstairs in the
    vaults each wears her own full-coverage two-piece, in her colours (`<who>_swim.glb`). Upstairs and on missions
    they keep their suits and garb. Rope goes over skin or swimwear, never under it.
  - **Art cost:** Nim's third outfit goes through her own pipeline. The clients need new Meshy bodies in swimwear,
    about 54 each: four species, men and women. To quote when it's built.
- Every scene is consensual and reads that way: check-ins, safewords, aftercare. The kink is never the joke. The
  joke can be a hypocrite who turns up as a client (a Decency League man in a false moustache).
- Clients are adults, members' guests who asked to be there.

**The layout** (sized by Banjo's lessons: compact, one landmark, everything within about 30 s of the door):
- **Ground floor:** the lounge and bar (as now), Bastion at the door, and the members' wardrobe.
- **Down the ramp, the Dungeon:** a vaulted hall, with the sisters' rooms off it. Each sister works there with a
  client when Nim passes, as ambient scenes on a loop. Nim can stop and watch, or talk between sessions.
  - **Silke's rope room:** a client in a chest harness over his shirt; Silke checks a knot and asks how it feels.
  - **Augusta's parlour:** posture and protocol; a client kneels with a book on his head, and she corrects his chin.
  - **Grizelda's throne room:** a client blacks her boots, very carefully. She inspects the shine.
  - **Lull's quiet room:** low light and cushions; aftercare. A client under a blanket with tea, talking.
  - **Rivet's workshop:** her bench (contraband into gear moves here), the muzzle on a stand, Swyne's toys gutted.
  - **Dash's room:** a punching bag and a fridge. Nobody books Dash; she's here anyway.
- **The Backroom:** behind a door in Rivet's workshop (a shelf that swings), the covert side.
  - A map table of the Purrlands, and a pinboard of Swyne's chain (photos and red string, one link per world).
  - Vesper's desk. Briefings for each world happen here.
  - The board is also where the worlds are chosen: a diegetic world map.

**Nim with a client (a mini-game, in the suit; it pays a hub Rose):** a session is reading someone, not winning.
- The client has a meter of what they want, and shows it in body language: eager, nervous, near a limit.
- Nim uses her Commands (the D-pad words, plus session words: Kneel, Hold, Count, Good).
- **The point is listening.** A client's "yellow" means slow down and check in; "red" means stop, at once. Pressing
  on through a safeword fails the session, by design, and Vesper says why.
- A good session ends in aftercare (Lull's room is next door). A few clients over the game, each with a joke and a
  want. Some are comic (the moustache), some are sweet (a nervous first-timer).

**Switch (Nim bottoms for a sister; optional; it pays a hub Rose):**
- Nim asks a sister, and the sister checks in first: limits, a safeword.
- **Silke's rope:** Silke ties Nim's arms (over the suit's sleeves). A stillness game: breathe with the rhythm and
  hold still; it's about trust. Silke checks in halfway.
- **Augusta's posture** (a later visit): hold a pose while she talks you through it. A balance game, using the tail
  balance Nim already has.
- **Afterwards,** a short aftercare scene: tea, and what it was like. It also unlocks something small and
  character-based (Silke: a rope trick for the Docks; Augusta: a better Composure in the suit).

**The owner's answers (2026-11-12):**
1. **The clients filter in and out:** "perhaps have some fixed, but they can also be 'random' in a sense like the
   dungeon is alive".
   - A few regulars (the moustache, the nervous first-timer) come back with new wants.
   - Around them a rotating crowd:
     - each arrives in a robe at the door, changes, and goes down;
     - takes a free sister's room for a while (an ambient session);
     - then Lull's room for aftercare, and out.
   - Which rooms are busy changes as Nim walks about. Any client in the hall, between sessions, can be Nim's for the
     mini-game.
2. **Switching is opt-in, with any sister:** "have the player opt-in who they want to be their Switch so each one".
   - **And Nim can Domme a sister:** "expand and have the option to Domme a sister too".
   - Each sister gets a small game both ways, in character:
     - **Silke:** rope, both ways; she corrects your knots from underneath them.
     - **Augusta:** posture; as a bottom, she critiques your technique, politely.
     - **Grizelda:** boots; tops from the bottom, outrageously.
     - **Dash:** can't keep still, either way.
     - **Lull:** breath and stillness.
     - **Rivet:** a puzzle of buckles.
   - **Build two at a time.** Every scene opens with the check-in (limits, a safeword) and ends with aftercare.
**The cross (decided by the owner, 2026-11-12; built in `core/cross_scene.gd`):** "part of the Dom process has
option of the Sub on the cross where they can pick a gag, blindfold or not, collar or not etc. and have toys used on
them". It's a bigger version of Nine Lives' After Hours: Nim on either side, with clients or any sister.
- **The form first:**
  - The choices: wrists, ankles, mouth, eyes, neck, gentle or firm.
  - The sub's limits are greyed out.
  - A gag swaps the safeword for a dropped bell.
- **Nim leads:**
  - Touch tools are a steadiness game; impact tools are a rhythm.
  - Praise and check-ins are always on offer.
  - The sub's cues say how it's landing. Yellow means ease off; their word means stop, and stopping is a good ending.
- **Nim on the cross:**
  - She holds still and braces.
  - She can hold B for her word at any time.
  - The sister asks her colour.
  - Her muzzle stays, so she's never gagged.
- **Aftercare every time,** in Lull's room.
- **Proposal (owner review):**
  - The tools are sensation and impact only: feather, ice, whisper, flogger, crop, paddle.
  - Swyne's vibrating toys are the story's weapon, so they're never used in a scene.
  - Each sister's wants, limits and tray are in character (Lull asks for the blindfold, Grizelda tops from the bottom).

3. **Not decided (owner unsure).** **Recommendation: alongside.**
   - The street gates stay where a world is unlocked (a gate with its cost on show is a character; the walk down
     its street is part of the trip).
   - The Backroom board is for briefings and progress: Swyne's chain with each link crossed off, and fast travel to
     any world already open.

**Rewards:** the hub's two spare Roses go to the first client session and the first Switch or Domme scene. The rest
pay small, character-based perks, and a sister's bond (her lines change).

## Nim's moves (proposal)
Rules, from the study: a small core she has from the prologue, moves taught where they're first needed, and teaching
finished by world 4 of 6, so worlds 5 and 6 test mastery. Combat is built first. Her takedowns restrain, never kill.

### The core (prologue, both outfits)
- **Run, jump, crouch-sneak.** A long, low leopard's jump.
- **Climb:** brick, ivy, rigging, drainpipes, anything marked. Clouded leopards are the best climbers of the big cats.
- **Tail balance:** walk wires, beams and rails; the long tail keeps her up.
- **Strike:** a three-hit claw combo. It staggers.
- **Pounce:** a lunge that closes a gap and staggers on contact.
- **Bind:** Vesper's own lesson. A staggered or unaware goon is tied where he stands and stays tied (bound goons
  persist, left with a note for the police).
  - **The Rope's knot** (owner, 2026-11-11): every bound goon is tied off with the Velvet Rope's signature knot. It's
    their calling card: the police, the papers and Swyne all know whose work it is.
  - The knot is also the Rope's emblem: embossed tone on tone on the harness buckle and the half mask
    (ART_DIRECTION §1, "The Rope's night uniform").
  - **Proposal, its shape:** a figure-eight with a closed loop through its middle, readable as one bold mark at
    emblem size.
- **Command: Kneel.** In the suit, a goon or a member of staff kneels and stays out of her way.
- People in trances are never struck or bound. Break the device, and they wake.

### The outfits change what she can do
| | Night garb | Domme suit |
|---|---|---|
| Moving | climbs and runs freely | walks with poise; running, climbing or fighting in sight costs **Composure** |
| Being seen | starts a fight or a chase; lose them to calm the area | Composure empties, her cover is blown; break sight, change, or bluff |
| Hiding | shadows, ledges, ceilings | in a crowd: walk among patrons and she's one of them |
| Takedowns | from behind or above | none in sight; Command instead |
| Doors | locks, vents, windows | the front door, if she looks like she belongs |

**Composure** is the suit's one meter: acting out of character drains it, a confident walk and good commands restore it.
**In the suit, she only fights once her cover's blown** (owner). Until then, Command is her only tool. The lure
(a seized toy thrown to buzz the guards away) is approved.

### Taught by Vesper, one per world (alternating covert and Domme)
| World | Lesson | Outfit |
|---|---|---|
| 1 The Pier | **Takedown from above:** drop from a ledge onto a goon and bind him in one move | garb |
| 2 Primrose Close | **Commands: Fetch and Open.** Goons and staff bring keys and open doors; harder asks cost Composure | suit |
| 3 The Docks | **Ceiling crawl and headfirst descent:** hang upside down under beams and pipes, come down a wall head first | garb |
| 4 The Retreat | **Hold the Room:** when her cover's blown, a stare-down that bluffs the whole room back into calm | suit |

### Gear from each world's host (like Banjo's transformations, one each)
| World | Host | Gear | Does |
|---|---|---|---|
| 1 | Dash | **the crop** | a longer reach strike; hits switches, bells and targets at range |
| 2 | Grizelda | **the Scold** | a shout that freezes every goon in range for a few seconds |
| 3 | Silke | **the rope** | swing from anchors, pull things down, bind from a distance |
| 4 | Lull | **the pendant** | wakes people from a trance at range; or Nim *fakes* a trance and the goons ignore her |
| 5 | Rivet | **lures** | throw a seized toy; it buzzes and draws guards away |
| 6 | Augusta | **the signet** | Commands work on the powerful (councillors, the ball's guests) |

Vesper never draws her own whip until City Hall.

### Pad layout (draft)
- A jump. X strike (hold for the crop). Y bind, talk or Command (context). B crouch-sneak.
- RT pounce. LT lock on, and pick a Command target. RB rope. LB gear (Scold, pendant, lure).
- The D-pad picks the Command word. Right stick camera, R3 recentres. Start pauses.

## Content lines (binding)
- Every character is an upright, anthropomorphic, unmistakably grown adult.
- Suggestive, never explicit: latex, leather, rope, corsets, collars, implication. **No nudity, sex acts or genitalia
  in anything an agent authors.**
- Jokes target Swyne, his goons, hypocrites and the hero's dignity, never the kink community.
- People under Swyne's hypnosis are never hurt or made the joke. "Consent" is never the stated thesis.
