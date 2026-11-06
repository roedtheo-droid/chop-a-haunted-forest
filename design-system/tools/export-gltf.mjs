// Writes the library's finished models as .gltf files in ../models, for Roblox Studio's
// File > Import. Run it after `npm run build`:
//   node tools/export-gltf.mjs            every model
//   node tools/export-gltf.mjs Gnawbert   just one
import { mkdirSync, rmSync, writeFileSync } from "node:fs";
import { join, resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { build } from "esbuild";

const MODELS = ["Gnawbert", "Ghost", "PeddlerCart", "ToolStump", "WantedPoster", "GhostKeeper"];
const wanted = process.argv.length > 2 ? process.argv.slice(2) : MODELS;

// A copy of the library that runs in Node. The models only use React to describe their pieces.
const temp = resolve("dist/.export-build.mjs");
await build({
  entryPoints: ["src/index.ts"],
  outfile: temp,
  bundle: true,
  format: "esm",
  platform: "node",
  packages: "external",
  jsx: "automatic",
  logLevel: "warning",
});
const Kit = await import(pathToFileURL(temp).href);
const { createElement } = await import("react");
rmSync(temp, { force: true });

const folder = resolve("../models");
mkdirSync(folder, { recursive: true });
for (const name of wanted) {
  if (!Kit[name]) throw new Error(`There is no model called ${name}`);
  const model = Kit.collectModel(createElement(Kit[name]), name);
  const text = Kit.toGltf(model);
  writeFileSync(join(folder, `${name}.gltf`), text);
  const parts = model.exported.map((p) => `${p.name} (${p.triangles})`).join(", ");
  console.log(`${name}.gltf: ${model.exported.length} parts, ${model.triangleCount} triangles, ${(text.length / 1024).toFixed(0)} KB`);
  console.log(`  ${parts}`);
}
