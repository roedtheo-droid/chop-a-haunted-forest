# Notes for the next sync

- Run everything from `design-system/`, with Node on the PATH. On Theo's PC, Git Bash may need
  `export PATH="/c/Program Files/nodejs:$PATH"`.
- The library was written for this sync (the game itself is Luau, with no React in it). Nothing else
  in the repo depends on it, except that `models/*.gltf` are written from it.
- React stays on 18: the converter uses its UMD build, and 19 has none.
- The converter needs `cssEntry` for the colours: `tokensGlob` only works together with `tokensPkg`.
- The app clears `_ds_needs_recompile` when the project is opened, so its presence right after an
  upload proves nothing about whether anyone looked. Its absence means someone opened it.

## Known render warns
- `[RENDER_THIN] variants render identically`: every story is a `<canvas>` in the same page markup, so
  the check can't see the difference. The screenshots do differ. Check them by eye.
- `Corners` doesn't trip that warn, only because its previews happen to have different heights.

## Re-sync risks
- Standalone Claude Design closes by December 14, 2026. Before a re-sync, `get_project` may return a
  `moveState`; then give its notice to Theo and stop, as the skill says.
- `.design-sync/conventions.md` names components and palette colours by hand. Re-check them against the
  build whenever `src/core/palette.ts` or the exports in `src/index.ts` change.
- The Gnawbert and Ghost previews animate (`chomping`, `floating`), so a screenshot can differ a little
  from run to run. Grades are kept by source, so this doesn't clear them.
- Verified in headless Chromium and by Theo opening the project on 2026-11-06, when only the first three
  components were there. The full set has only been seen in headless Chromium.
- Not verified: importing `models/*.gltf` into Roblox Studio, and asking Claude Design's agent to build a
  new model with the kit.
