import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const sourceRoot = path.join(root, "Chiselo");
const nonEnglishUIPattern = /[\u3400-\u4dbf\u4e00-\u9fff；，。！？，、：（）【】]/;
const sourceExtensions = new Set([".swift", ".js", ".mjs", ".html", ".css", ".json"]);

const allowedInternalProtocolLines = new Map([
  ["Chiselo/ContentView.swift", [
    /item\.kind\.contains\("(?:文字|图片|位置|尺寸|样式|删除|新增)"\)/
  ]],
  ["Chiselo/DeckModel.swift", [
    /^\s*"(?:图片|文字|样式|位置\/尺寸|删除对象|新增对象|保留原对象|原对象将替换)":\s*"/,
    /item\.kind\.contains\("(?:文字|图片|位置|尺寸|样式|删除)"\)/
  ]],
  ["Chiselo/Resources/Editor/editor.js", [
    /^\s*"(?:图片|文字|样式|位置\/尺寸|删除对象|新增对象)":\s*"/,
    /\bkind\b.*"(?:删除对象|新增对象|文字|图片|位置\/尺寸|样式)"/,
    /visualEntryChangeKind.*"新增对象"/,
    /records\.push\(\{ key, kind: "删除对象"/
  ]],
  ["Chiselo/Resources/Editor/source-mapping.js", [
    /^\s*kind: "(?:保留原对象|新增对象|原对象将替换)",?$/
  ]],
  ["Chiselo/Resources/Editor/visual-change.js", [
    /\bkind\b.*"(?:文字|图片|位置\/尺寸|样式)"/,
    /return "(?:图片|文字|样式|位置\/尺寸)";/
  ]]
]);

function sourceFiles(directory) {
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const absolute = path.join(directory, entry.name);
    if (entry.isDirectory()) return sourceFiles(absolute);
    return sourceExtensions.has(path.extname(entry.name)) ? [absolute] : [];
  });
}

const failures = [];
for (const absolute of sourceFiles(sourceRoot)) {
  const relative = path.relative(root, absolute);
  const allowlist = allowedInternalProtocolLines.get(relative) || [];
  const lines = fs.readFileSync(absolute, "utf8").split(/\r?\n/);
  lines.forEach((line, index) => {
    if (!nonEnglishUIPattern.test(line)) return;
    if (allowlist.some((pattern) => pattern.test(line))) return;
    failures.push(`${relative}:${index + 1}:${line.trim()}`);
  });
}

if (failures.length) {
  console.error("Unexpected Chinese text was found in product source:");
  failures.forEach((failure) => console.error(failure));
  process.exit(1);
}

console.log("English UI source audit passed.");
