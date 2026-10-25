// Lists the texts the page scripts pass to t(...) that have no French entry, and
// French entries nothing uses any more. Run: node tools/check-translations.mjs
import { readFileSync, readdirSync } from "node:fs";
import { fileURLToPath, pathToFileURL } from "node:url";
import { join } from "node:path";

const src = fileURLToPath(new URL("../src/", import.meta.url));
globalThis.window = { __TAURI__: { core: { invoke: async () => "en" }, event: { listen() {} } } };
globalThis.document = { querySelectorAll: () => [] };
const { FR } = await import(pathToFileURL(join(src, "locales/fr.js")).href);

const used = new Set();
const literal = /\bt\(\s*(["'`])((?:\\.|(?!\1).)*)\1/g;
const sources = [...readdirSync(src).filter((f) => f.endsWith(".js") || f.endsWith(".html"))];
for (const file of sources) {
  const text = readFileSync(join(src, file), "utf8");
  for (const [, , key] of text.matchAll(literal)) used.add(key.replace(/\\(["'`])/g, "$1"));
  for (const [, key] of text.matchAll(/data-i18n(?:-title|-placeholder)?="([^"]+)"/g)) used.add(key);
  for (const [, key] of text.matchAll(/<[^>]*data-i18n>([^<]+)</g)) used.add(key.trim());
}
// Ternaries pass two literals to one t(): list them by hand.
["{count} screenshot", "{count} screenshots", "KB", "MB", "GB", "Auto", "Language"].forEach((key) => used.add(key));

const missing = [...used].filter((key) => !(key in FR));
const unused = Object.keys(FR).filter((key) => !used.has(key));
console.log(`${used.size} texts used, ${Object.keys(FR).length} translated`);
if (missing.length) console.log("MISSING French:\n  " + missing.join("\n  "));
if (unused.length) console.log("UNUSED French entries:\n  " + unused.join("\n  "));
process.exitCode = missing.length ? 1 : 0;
