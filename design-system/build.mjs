// Builds the library into dist/: one JavaScript file, plus the .d.ts files that describe its
// components. Claude Design reads those to learn what each component's props are.
import { execFileSync } from "node:child_process";
import { rmSync } from "node:fs";
import { build } from "esbuild";

rmSync("dist", { recursive: true, force: true });

await build({
  entryPoints: ["src/index.ts"],
  outfile: "dist/index.es.js",
  bundle: true,
  format: "esm",
  jsx: "automatic",
  target: "es2020",
  external: ["react", "react-dom", "react/jsx-runtime"],
  logLevel: "warning",
});

execFileSync(process.execPath, ["node_modules/typescript/bin/tsc", "--project", "tsconfig.json"], { stdio: "inherit" });
console.log("Built dist/");
