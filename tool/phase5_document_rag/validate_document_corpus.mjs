import { createHash } from "node:crypto";
import { existsSync, readFileSync, readdirSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

export function loadAndValidateManifest({ repoRoot, manifestPath }) {
  const raw = readFileSync(path.join(repoRoot, manifestPath), "utf8");
  const manifest = JSON.parse(raw);
  const errors = validateManifest({ repoRoot, manifest });
  if (errors.length > 0) throw new Error(`Invalid document corpus manifest:\n- ${errors.join("\n- ")}`);
  return {
    manifest,
    manifestHash: createHash("sha256").update(raw.replaceAll("\r\n", "\n")).digest("hex"),
  };
}

export function validateManifest({ repoRoot, manifest }) {
  const errors = [];
  const expected = ["README.md"];
  for (const language of ["en", "zh"]) {
    const directory = path.join(repoRoot, "docs", language);
    for (const name of readdirSync(directory).filter((entry) => entry.endsWith(".md")).sort()) {
      expected.push(`docs/${language}/${name}`);
    }
  }
  const sources = manifest.sources ?? [];
  const duplicate = sources.find((source, index) => sources.indexOf(source) !== index);
  if (duplicate) errors.push(`duplicate source: ${duplicate}`);
  for (const source of sources) {
    if (!existsSync(path.join(repoRoot, source))) errors.push(`missing source: ${source}`);
    if ((manifest.excluded_exact ?? []).includes(source)) errors.push(`excluded source: ${source}`);
    if ((manifest.excluded_prefixes ?? []).some((prefix) => source.startsWith(prefix))) errors.push(`excluded source: ${source}`);
  }
  for (const source of expected) if (!sources.includes(source)) errors.push(`required stable source omitted: ${source}`);
  for (const source of sources) if (!expected.includes(source)) errors.push(`unauthorized source: ${source}`);
  for (const name of manifest.bilingual_basenames ?? []) {
    for (const language of ["en", "zh"]) {
      const source = `docs/${language}/${name}`;
      if (!sources.includes(source)) errors.push(`bilingual pair missing: ${source}`);
    }
  }
  return errors;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const repoRoot = process.cwd();
  const { manifest, manifestHash } = loadAndValidateManifest({
    repoRoot,
    manifestPath: "tool/phase5_document_rag/document_corpus_manifest.v1.json",
  });
  console.log(`Validated ${manifest.sources.length} sources; manifest sha256=${manifestHash}.`);
}
