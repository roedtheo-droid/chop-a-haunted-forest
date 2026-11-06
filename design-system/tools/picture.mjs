// Takes pictures of a model in a real browser, to look at it without opening Claude Design.
//   node tools/picture.mjs Gnawbert out.png '[{"yaw":25},{"yaw":-60,"mouth":1}]'
// Each object in the list is one view: the props for that model's component. A .tsx file works too:
// it default-exports a component, which can import the kit from "trees-with-teeth-3d".
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { build } from "esbuild";
import { chromium } from "playwright";

const [name = "Gnawbert", out = "picture.png", viewsText = '[{"yaw":25}]', sizeText = "640x480"] = process.argv.slice(2);
const views = JSON.parse(viewsText);
const [width, height] = sizeText.split("x").map(Number);

const bundle = await build({
  stdin: {
    contents: `
      import { createElement } from "react";
      import { createRoot } from "react-dom/client";
      import * as Kit from "./src/index";
      ${name.endsWith(".tsx") ? `import Design from ${JSON.stringify(resolve(name))};` : "const Design = null;"}
      window.show = (name, views, width, height) => {
        const items = views.map((view, i) => createElement(Design ?? Kit[name], { key: i, width, height, ...view }));
        createRoot(document.getElementById("root")).render(items);
      };`,
    resolveDir: process.cwd(),
    loader: "tsx",
  },
  bundle: true,
  format: "iife",
  jsx: "automatic",
  alias: { "trees-with-teeth-3d": resolve("src/index.ts") },
  nodePaths: [resolve("node_modules")],
  write: false,
  define: { "process.env.NODE_ENV": '"production"' },
  logLevel: "warning",
});

const columns = Math.min(views.length, 2);
const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: columns * width + (columns + 1) * 8, height: Math.ceil(views.length / columns) * (height + 8) + 8 } });
const problems = [];
page.on("pageerror", (error) => problems.push(error.message));
await page.setContent(`<!doctype html><body style="margin:0;background:#222"><div id="root" style="display:grid;grid-template-columns:repeat(${columns},${width}px);gap:8px;padding:8px"></div></body>`);
await page.addScriptTag({ content: bundle.outputFiles[0].text });
await page.evaluate(([n, v, w, h]) => window.show(n, v, w, h), [name, views, width, height]);
await page.waitForSelector("canvas");
await page.waitForTimeout(600);
mkdirSync(dirname(resolve(out)), { recursive: true });
writeFileSync(out, await page.screenshot({ fullPage: true }));
await browser.close();
if (problems.length) console.error(problems.join("\n"));
console.log(`Saved ${out}`);
