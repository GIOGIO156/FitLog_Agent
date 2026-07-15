import assert from "node:assert/strict";
import { existsSync } from "node:fs";
import { readFile, readdir } from "node:fs/promises";
import path from "node:path";
import test from "node:test";

const stableBasenames = [
  "Product.md",
  "AppGuide.md",
  "Methodology.md",
  "Algorithm.md",
  "Database.md",
  "CloudLocalDataBoundary.md",
  "AgentDesign.md",
  "AIOutputContract.md",
  "RAGDesign.md",
  "References.md",
];

const stableFiles = [
  "README.md",
  ...stableBasenames.flatMap((name) => [`docs/en/${name}`, `docs/zh/${name}`]),
];

test("required stable documentation tree exists and bilingual outlines align", async () => {
  for (const name of stableBasenames) {
    const enPath = `docs/en/${name}`;
    const zhPath = `docs/zh/${name}`;
    assert.equal(existsSync(enPath), true, enPath);
    assert.equal(existsSync(zhPath), true, zhPath);
    const [en, zh] = await Promise.all([readFile(enPath, "utf8"), readFile(zhPath, "utf8")]);
    const levels = (value) => [...value.matchAll(/^(#{1,6})\s+.+$/gm)].map((match) => match[1].length);
    assert.deepEqual(levels(zh), levels(en), `heading levels drifted for ${name}`);
  }
});

test("stable docs have no replacement characters, dated update headings, or stale Phase 5 root link", async () => {
  for (const file of stableFiles) {
    const text = await readFile(file, "utf8");
    assert.equal(text.includes("\uFFFD"), false, file);
    assert.equal(/^#{1,6}\s+.*20\d{2}[-/]\d{1,2}[-/]\d{1,2}.*$/m.test(text), false, file);
    assert.equal(text.includes("../../PHASE5_ENGINEERING_PLAN.md"), false, file);
  }
});

test("relative Markdown file links resolve in stable and Local docs", async () => {
  const localFiles = await markdownFiles("docs/local");
  for (const file of [...stableFiles, ...localFiles]) {
    const text = await readFile(file, "utf8");
    for (const match of text.matchAll(/\]\(([^)]+)\)/g)) {
      const raw = match[1].trim();
      const target = raw.split("#", 1)[0];
      if (!target || /^(?:https?:|mailto:)/i.test(target)) continue;
      const resolved = path.resolve(path.dirname(file), decodeURIComponent(target));
      assert.equal(existsSync(resolved), true, `${file} -> ${target}`);
    }
  }
});

test("bilingual stable docs preserve strength input semantics and Bulgarian example", async () => {
  const files = [
    "docs/en/Product.md",
    "docs/zh/Product.md",
    "docs/en/AppGuide.md",
    "docs/zh/AppGuide.md",
    "docs/en/Methodology.md",
    "docs/zh/Methodology.md",
    "docs/en/Algorithm.md",
    "docs/zh/Algorithm.md",
    "docs/en/Database.md",
    "docs/zh/Database.md",
  ];
  for (const file of files) {
    const text = await readFile(file, "utf8");
    assert.match(
      text,
      /per_side_reps|per-side reps|reps per side|每侧次数/i,
      file,
    );
  }
  for (const file of ["docs/en/Algorithm.md", "docs/zh/Algorithm.md"]) {
    const text = await readFile(file, "utf8");
    assert.match(text, /bulgarian_split_squat/);
    assert.match(text, /calculation_reps\s*=\s*12\s*\*\s*2\s*=\s*24/);
  }
});

async function markdownFiles(root) {
  const result = [];
  for (const entry of await readdir(root, { withFileTypes: true })) {
    const child = path.join(root, entry.name);
    if (entry.isDirectory()) result.push(...await markdownFiles(child));
    if (entry.isFile() && entry.name.endsWith(".md")) result.push(child);
  }
  return result;
}
