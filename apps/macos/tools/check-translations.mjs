// Lists the texts the Swift code passes to tr(...) (and the Settings titles and
// subtitles) that have no French entry. Run: node tools/check-translations.mjs
import { readFileSync, readdirSync, statSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { join } from "node:path";

const root = fileURLToPath(new URL("../ShotCubby/", import.meta.url));
const strings = readFileSync(join(root, "fr.lproj/Localizable.strings"), "utf8");
const keys = new Set([...strings.matchAll(/^"((?:[^"\\]|\\.)*)" = /gm)].map((match) => match[1]));

const used = new Set();
const quoted = String.raw`"((?:[^"\\]|\\.)*)"`;
const trCall = new RegExp(String.raw`\btr\(\s*(?:[^"()]*\?\s*)?${quoted}(?:\s*:\s*${quoted})?`, "g");
const label = new RegExp(String.raw`\b(?:title|subtitle): ${quoted}`, "g");

const view = new RegExp(
  String.raw`\b(?:Text|Button|Label|Toggle|TextField)\(${quoted}|\.(?:help|accessibilityLabel)\(${quoted}`,
  "g",
);

function scan(text) {
  for (const [, first, second] of text.matchAll(view)) used.add(first ?? second);
  for (const [, first, second] of text.matchAll(trCall)) {
    used.add(first);
    if (second) used.add(second);
  }
  for (const [, text_] of text.matchAll(label)) used.add(text_);
}

function walk(dir) {
  for (const name of readdirSync(dir)) {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) walk(path);
    else if (name.endsWith(".swift")) scan(readFileSync(path, "utf8"));
  }
}
walk(root);

const unescape = (text) => text.replace(/\\u\{2026\}/g, "…").replace(/\\"/g, '"');
// A text with an interpolation is built at run time, so it has no fixed key.
const missing = [...used].map(unescape).filter((key) => !keys.has(key) && !key.includes("\\(") && key.length > 2 && key !== "ShotCubby");
console.log(`${used.size} texts used, ${keys.size} translated`);
if (missing.length) console.log("MISSING French:\n  " + missing.join("\n  "));
process.exitCode = missing.length ? 1 : 0;
