# GAME DESIGN: Chop a Haunted Forest (Roblox)

## Instructions for Claude Code
- Read this whole document before writing any code.
- Build the game in the PHASES listed at the bottom, one phase at a time.
- After each phase: stop, summarize what you built, tell me exactly how to
  test it in Roblox Studio, and wait for my "ok" before starting the next phase.
- Before each phase, show me a short plan (files you'll create/change) first.
- Use simple placeholder parts (colored blocks/cylinders) for all models.
  I will replace art later. Never block progress on art or sounds.
- Keep ALL tunable numbers in `src/shared/Config.luau` so I can balance the
  game without touching logic.
- If something in this doc is unclear, ask me instead of guessing.

## Technical rules
- Language: Luau with `--!strict` at the top of every file.
- Project uses Rojo. Layout:
  - `src/shared/`  -> ReplicatedStorage/Shared (Config, Types, Remotes list, pure utils)
  - `src/server/`  -> ServerScriptService/Server (one `init.server.luau` + `Systems/` modules)
  - `src/client/`  -> StarterPlayerScripts/Client (one `init.client.luau` + `Controllers/` modules)
- Exactly one Script and one LocalScript (the two init files). Everything else
  is a ModuleScript. Each system has `init()` and `start()` functions.
- Never use `_G`. Always `require` explicitly.
- All remotes are created by the server from one list in `shared/Remotes.luau`.
- SERVER IS AUTHORITATIVE: the server decides tree damage, log counts, coins,
  purchases, mimic state and zone progress. The client only sends requests
  ("I swung at tree X") and the server validates distance, cooldowns and
  ownership. Never trust numbers sent by the client.
- Use CollectionService tags + one manager per behavior (e.g. one TreeManager
  handles every tree), not a script inside each tree.
- Use Attributes for per-tree data (HP, IsMimic, Tell, ZoneId).

## Pitch
A co-op (1–4 players) clearing game. Your party must chop down EVERY tree in a
haunted forest. Trees become logs, logs become coins, coins buy better tools,
and clearing a zone to 100% opens the next one.
THE TWIST: some trees are mimics. They look almost normal but have one small
"tell". Chop a mimic with an axe and it wakes up and hunts your party. Find
mimics first and burn them safely with a torch.

## Core loop
1. Chop trees -> they fall and drop logs.
2. Pick up logs (carry limit) -> bring them to the Sawmill in that zone -> get Coins.
3. Spend Coins on tools and upgrades (bigger carry, faster chopping).
4. Spot mimics using their tells and the Lantern -> burn them with the Torch
   -> they drop Embers (permanent currency).
5. Clear zone to 100% -> gate opens -> next zone.
6. Clear the final zone -> final boss -> "FOREST CLEARED" screen with stats.

## Currencies
- Coins: earned by selling logs. RESET every new run.
- Embers: earned from burned mimics and run completion. PERMANENT (saved).

## Trees
- Each tree has HP. A swing deals tool damage. At 0 HP: fall animation
  (tween/rotate), then spawn N log parts on the ground.
- Tree types per zone have different HP and log value.
- Rare "Cursed" variant (glows purple, ~3% chance): logs worth 3x.
- Visible damage: every hit shrinks the trunk a little (or grows a notch) and
  throws a small burst of wood chips, so players can read a tree's HP without
  a health bar.
- Felled trees leave a STUMP behind. A cleared area is easy to spot, which
  helps players find the last trees.
- Normal trees come in mixed colours (red, orange, pink leaves, white birch
  bark). This makes the mimic "bark colour slightly off" tell harder to spot,
  so tune that tint with the mix in mind.

## Mimics (the twist)
- A percentage of trees per zone are mimics (Config: e.g. zone 1 = 5%).
- Each mimic gets ONE random tell from this list:
  1. Bark color slightly off (subtle tint)
  2. Leaves sway when nothing else is moving
  3. Slightly too tall or tilted
  4. A faint creaking sound when a player is within 15 studs
  5. A knot on the trunk that occasionally "blinks"
- Lantern tool: when held, mimics within its radius get a faint outline.
  Upgrades increase radius.
- If a mimic is hit with an axe (or any chopping tool): it WAKES.
  - It uproots, chases the nearest player using PathfindingService.
  - Speed slightly slower than a player sprinting, faster than walking.
  - If it touches a player, that player is "knocked down" (cannot move) for
    20 seconds or until a teammate holds E on them for 3 seconds (revive).
  - Awake mimics return to sleep (become a tree again somewhere nearby)
    after 45 seconds of not catching anyone.
- Torch tool: hitting a SLEEPING mimic burns it safely (counts as cleared,
  drops Embers). Hitting a normal tree with the torch does nothing.
- Burning or chopping a mimic both count toward zone %.

## Zones (MVP has 3, design allows more later)
1. Pale Pines   — easy, few mimics, start area with Sawmill and Tool Shed.
2. Fog Hollow   — fog reduces vision, more mimics.
3. Graveyard Grove — darkest, most mimics, contains the final boss.
- Each zone shows "Zone X: NN% cleared" in the HUD.
- Gate between zones opens only at 100%. Walking to a closed gate shows
  "Clear every tree first (N left)".
- Show a small arrow/beam pointing to the nearest remaining tree when a zone
  is above 95% (avoids the "stuck at 99%" frustration).

## Tools & shop (prices in Config)
- Fists (start), Axe, Steel Axe, Chainsaw, Lantern, Torch, Log Sack (carry upgrades).
- Tool ladder: each chopping tool must look and feel clearly stronger than the
  last (bigger damage, faster swings, its own placeholder shape and chip burst).
- Log Vacuum: a Log Sack upgrade that pulls nearby logs on the ground to you.
- Upgrades: Chop Damage, Carry Limit, Walk Speed, Lantern Radius.
- Number keys equip tools. Mobile gets on-screen buttons.

## Tutorial quests
- A short quest list in the top-left teaches new players, one step at a time,
  e.g. "Quest 2/8: Pick up the logs (press E)".
- Example steps: chop a tree, pick up logs, sell at the Sawmill, buy an Axe,
  clear 10% of the zone.

## Final boss
- When Graveyard Grove reaches 99%, the last tree is the Elder Hollow: a giant
  mimic. It has a big HP bar and slams the ground (telegraphed red circle).
- Players chop its roots (weak points) while dodging.
- Defeat -> "FOREST CLEARED!" screen: trees felled, mimics burned, coins
  earned, time.

## Multiplayer
- Max 4 players per server (set in game settings). Friends join each other.
- Progress (zone %, felled trees) is shared by the whole server.
- Coins are per player.

## Saving (DataStore)
- Save: Embers, owned permanent unlocks, stats. Use retry with backoff,
  save on leave and on BindToClose, and autosave every few minutes.
- Do NOT save mid-run progress in the MVP.

## UI
- HUD: Coins, Embers, backpack counter at the bottom (e.g. 0/5, then 5/5 when
  full), zone %, equipped tool.
- Shop UI at the Tool Shed. Simple and readable on mobile.

## BUILD PHASES (one at a time, stop after each)
1. Project setup: Rojo layout, bootstrap, Config, Remotes, Types.
2. Trees + chopping (fists only) + visible damage + logs on ground + pick up
   + carry limit + simple backpack counter.
3. Sawmill selling + Coins + HUD.
4. Tool Shed shop: Axe, Steel Axe, Chainsaw (tool ladder), Log Sack, Log
   Vacuum, upgrades + tutorial quests.
5. Zone system: 3 zones, % tracking, stumps, gates, "nearest tree" helper.
6. Mimics: random assignment, tells, wake-on-chop, chase AI, knockdown + revive.
7. Lantern + Torch + Embers.
8. DataStore saving for Embers and stats.
9. Final boss + Forest Cleared screen.
10. Polish: sounds, particles, fog per zone, mobile buttons, bug fixes.

## After the MVP (ideas, not scheduled)
- Lobby with party pads: step on a pad, pick the map and party size (1–4),
  then everyone teleports in together.
- Peaceful Mode: no mimics and no night, for relaxed players.
- Difficulty levels that unlock after 1 and 5 wins.
- Day/night cycle with a timer in the HUD; mimics are more active at night.
- Free 90-second trial of a tool (e.g. the Chainsaw) to tempt players to buy it.
- More tool-ladder ideas: claws, dual saws, a thrown axe.
- Short intro cutscene, a log truck driving through the forest, small birds
  for life, seasonal events (e.g. Halloween).
