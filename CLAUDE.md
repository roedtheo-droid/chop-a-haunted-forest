# Project rules for Claude Code

## About this project
- Roblox game: "Chop a Haunted Forest". Full design is in GAME_DESIGN.md.
- I'm building it phase by phase. Check GAME_DESIGN.md for the current phase list.

## How to work with me
- Before starting any phase or big change, show me a short plan (which files you'll create or change) and wait for my ok.
- Work on ONE phase at a time. When a phase is done: stop, summarize what you built, and give me step-by-step instructions to test it in Roblox Studio.
- If something is unclear, ask me instead of guessing.
- Explain things simply. I'm learning, so tell me briefly WHY you did something when it isn't obvious.

## Code rules
- Luau with `--!strict` in every file.
- No Rojo. Roblox Studio (the saved place) is the source of truth for code. Edit scripts in
  Studio, keeping the shared / server / client layout from GAME_DESIGN.md.
- `src/` on GitHub is a copy of Studio's scripts. After each step, copy Studio's scripts into
  `src/` (see README "Studio and GitHub") and commit. Never let `src/` and Studio drift apart.
- Exactly one Script and one LocalScript. Everything else is a ModuleScript.
- Never use `_G`. Always `require` explicitly.
- The server is authoritative. Never trust numbers sent by the client.
- Every tunable number goes in `src/shared/Config.luau`.
- Models come from the Blender scripts in `blender/` (see README "Blender models"). The code
  always falls back to placeholder parts when a model isn't imported into Studio yet. Never wait on art.

## Git
- After each phase works and I confirm it, commit with a clear message like "Phase 3: sawmill selling and coins".
- Each step goes on a branch and a pull request. Claude opens and merges the PR itself after my ok;
  I never do git or PRs by hand.
- Remind me to save the place in Studio (File > Save, or Publish) after code changes, because
  the code now lives in the place file.
- Never delete or rewrite git history.

## Testing
- From Phase 2 onward, remind me to test with 2 players (Studio Test tab > Clients and Servers > 2 players) when the change affects multiplayer.
- If you have access to Roblox Studio tools, run a playtest and check the Output for errors yourself before telling me a phase is done.
