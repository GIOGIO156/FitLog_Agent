import { createHash } from "node:crypto";
import path from "node:path";

export const DEFAULT_MAX_CHUNK_LENGTH = 1400;

export function chunkMarkdown({
  sourcePath,
  markdown,
  manifestHash,
  generatorVersion,
  termVersion,
  maxChunkLength = DEFAULT_MAX_CHUNK_LENGTH,
}) {
  const normalizedPath = sourcePath.replaceAll("\\", "/");
  const source = markdown.replaceAll("\r\n", "\n").replaceAll("\r", "\n");
  const sourceHash = sha256(source);
  const sections = parseMarkdownSections(normalizedPath, source);
  const chunks = [];

  for (const section of sections) {
    if (section.content.trim() === "") continue;
    const language = languageFor(normalizedPath, section.headingPath, section.content);
    const tags = tagsFor(normalizedPath, section.headingPath, section.content);
    const status = statusFor(normalizedPath, section.headingPath, section.content);
    const authority = authorityForStatus(status);
    const parts = splitLosslessly(section.content, maxChunkLength);

    for (let index = 0; index < parts.length; index += 1) {
      const content = parts[index];
      if (content === "") continue;
      const chunkHash = sha256(content);
      const sectionId = stableSectionId({
        sourcePath: normalizedPath,
        headingPath: section.headingPath,
        headingOrdinal: section.headingOrdinal,
        content,
      });
      chunks.push({
        language,
        docPath: normalizedPath,
        heading: section.heading,
        headingLevel: section.level,
        headingPath: section.headingPath,
        sectionId,
        chunkIndex: index + 1,
        chunkCount: parts.length,
        content,
        contextPrefix: contextPrefixFor({
          language,
          docPath: normalizedPath,
          headingPath: section.headingPath,
          status,
          authority,
          tags,
          chunkIndex: index + 1,
          chunkCount: parts.length,
        }),
        contextNote: null,
        tags,
        status,
        authority,
        sourceHash,
        chunkHash,
        contentHash: chunkHash,
        manifestHash,
        generatorVersion,
        termVersion,
      });
    }
  }
  return chunks;
}

export function parseMarkdownSections(sourcePath, markdown) {
  const lines = linesWithOffsets(markdown);
  const headings = [];
  let fence = null;
  for (const line of lines) {
    const fenceMatch = /^\s*(```+|~~~+)/.exec(line.text);
    if (fenceMatch) {
      const marker = fenceMatch[1][0];
      fence = fence === null ? marker : fence === marker ? null : fence;
      continue;
    }
    if (fence !== null) continue;
    const match = /^(#{1,6})[ \t]+(.+?)[ \t]*$/.exec(line.text);
    if (match) {
      headings.push({ start: line.start, level: match[1].length, heading: headingText(match[2]) });
    }
  }

  const boundaries = headings.length === 0 || headings[0].start !== 0
    ? [{ start: 0, level: 1, heading: path.basename(sourcePath), synthetic: true }, ...headings]
    : headings;
  const stack = [];
  const ordinals = new Map();
  return boundaries.map((item, index) => {
    while (stack.length > 0 && stack.at(-1).level >= item.level) stack.pop();
    stack.push({ level: item.level, heading: item.heading });
    const key = `${stack.map((entry) => entry.heading).join(" > ")}#${item.level}`;
    const headingOrdinal = (ordinals.get(key) ?? 0) + 1;
    ordinals.set(key, headingOrdinal);
    const end = boundaries[index + 1]?.start ?? markdown.length;
    return {
      heading: item.heading,
      level: item.level,
      headingPath: stack.map((entry) => entry.heading),
      headingOrdinal,
      content: markdown.slice(item.start, end),
    };
  });
}

export function splitLosslessly(value, maxLength) {
  if (value.length <= maxLength) return [value];
  const protectedRanges = findProtectedRanges(value);
  const result = [];
  let start = 0;
  while (start < value.length) {
    if (value.length - start <= maxLength) {
      result.push(value.slice(start));
      break;
    }
    const desired = start + maxLength;
    const enclosing = protectedRanges.find(([from, to]) => from < desired && desired < to);
    let end;
    if (enclosing && enclosing[0] <= start) {
      end = enclosing[1];
    } else {
      const upper = enclosing ? enclosing[0] : desired;
      end = safeBoundary(value, start, upper);
      if (end <= start) end = enclosing ? enclosing[1] : nextSafeBoundary(value, desired, protectedRanges);
    }
    result.push(value.slice(start, end));
    start = end;
  }
  return result;
}

function safeBoundary(value, start, upper) {
  const minimum = start + Math.floor((upper - start) * 0.55);
  for (const expression of [/\n{2,}/g, /\n/g, /[。！？!?；;]\s*/gu, /[.!?]\s+/gu, /\s+/g]) {
    let chosen = -1;
    expression.lastIndex = minimum;
    for (let match = expression.exec(value); match && match.index < upper; match = expression.exec(value)) {
      chosen = match.index + match[0].length;
    }
    if (chosen > start) return chosen;
  }
  return -1;
}

function nextSafeBoundary(value, desired, ranges) {
  let cursor = desired;
  const enclosing = ranges.find(([from, to]) => from < cursor && cursor < to);
  if (enclosing) cursor = enclosing[1];
  const match = /\s|[。！？!?；;]/u.exec(value.slice(cursor));
  return match ? cursor + match.index + match[0].length : value.length;
}

export function findProtectedRanges(value) {
  const ranges = [];
  addMatches(ranges, value, /```[\s\S]*?```|~~~[\s\S]*?~~~/g);
  addMatches(ranges, value, /`[^`\n]+`/g);
  addMatches(ranges, value, /\[[^\]\n]+\]\([^\s)]+(?:\s+"[^"]*")?\)/g);
  addMatches(ranges, value, /https?:\/\/[^\s<>)]+|[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}/g);
  addMatches(ranges, value, /(?:[A-Za-z0-9_.-]+[\\/])+[A-Za-z0-9_.-]+|\b[A-Za-z0-9_-]+\.(?:md|dart|ts|sql|json|yaml|yml|mjs|tsx?|png|jpg)\b/g);
  addMatches(ranges, value, /\b(?:[a-z][a-z0-9]*_[a-z0-9_]+|RAG-[SD]\d{2}|AI-[SD]\d{2})\b/g);
  addMatches(ranges, value, /\bv?\d+(?:\.\d+){1,3}\b|\b\d{4}-\d{2}-\d{2}\b/g);
  let offset = 0;
  for (const line of value.split(/(?<=\n)/)) {
    if (/^\s*\|.*\|\s*(?:\n)?$/.test(line)) ranges.push([offset, offset + line.length]);
    offset += line.length;
  }
  return mergeRanges(ranges);
}

function addMatches(ranges, value, expression) {
  for (const match of value.matchAll(expression)) ranges.push([match.index, match.index + match[0].length]);
}

function mergeRanges(ranges) {
  const sorted = ranges.sort((left, right) => left[0] - right[0]);
  const merged = [];
  for (const range of sorted) {
    if (merged.length === 0 || range[0] > merged.at(-1)[1]) merged.push([...range]);
    else merged.at(-1)[1] = Math.max(merged.at(-1)[1], range[1]);
  }
  return merged;
}

function linesWithOffsets(value) {
  const result = [];
  let start = 0;
  for (const text of value.split("\n")) {
    result.push({ start, text });
    start += text.length + 1;
  }
  return result;
}

function headingText(value) {
  return value.replace(/\s+#+\s*$/, "").trim();
}

function stableSectionId({ sourcePath, headingPath, headingOrdinal, content }) {
  const identity = `${sourcePath}\n${headingPath.join(" > ")}\n${headingOrdinal}\n${sha256(content)}`;
  return `${slug(headingPath.at(-1) ?? "section")}-${sha256(identity).slice(0, 16)}`;
}

function slug(value) {
  return value.toLowerCase().replace(/[^a-z0-9\u4e00-\u9fff]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 56) || "section";
}

function sha256(value) {
  return createHash("sha256").update(value).digest("hex");
}

function languageFor(sourcePath, headingPath, content) {
  if (sourcePath.startsWith("docs/zh/")) return "zh";
  if (sourcePath.startsWith("docs/en/")) return "en";
  const headings = headingPath.join(" ");
  if (/中文|Chinese/i.test(headings) && !/English/i.test(headings)) return "zh";
  if (/English|英文/i.test(headings)) return "en";
  const characters = [...content].filter((character) => !/\s/.test(character));
  const cjk = characters.filter((character) => /[\u3400-\u4dbf\u4e00-\u9fff]/u.test(character));
  return characters.length > 0 && cjk.length / characters.length >= 0.15 ? "zh" : "en";
}

function tagsFor(sourcePath, headingPath, content) {
  const source = `${sourcePath}\n${headingPath.join(" ")}\n${content}`.toLowerCase();
  const tags = [];
  addTag(tags, "agent", source, ["agent", " ai ", "llm", "rag", "智能", "模型", "检索"]);
  addTag(tags, "database", source, ["database", "schema", "sqlite", "supabase", "数据库", "迁移"]);
  addTag(tags, "algorithm", source, ["algorithm", "energy_ratio", "gram_per_kg", "kcal", "算法", "热量"]);
  addTag(tags, "methodology", source, ["methodology", "carb", "protein", "evidence", "方法", "碳水"]);
  addTag(tags, "privacy", source, ["privacy", "consent", "local", "cloud", "retention", "隐私", "本地", "云端"]);
  addTag(tags, "ui", source, [" ui ", " ux ", "page", "screen", "tab", "界面", "页面", "入口"]);
  return tags.length === 0 ? ["product"] : [...new Set(tags)];
}

function addTag(tags, tag, source, needles) {
  if (needles.some((needle) => source.includes(needle))) tags.push(tag);
}

function statusFor(sourcePath, headingPath, content) {
  if (sourcePath.endsWith("References.md")) return "evidence";
  const heading = headingPath.join(" ").toLowerCase();
  const leading = content.split("\n").map((line) => line.trim()).filter((line) => line !== "" && !line.startsWith("#")).slice(0, 3).join(" ").toLowerCase();
  if (/non-goal|out of scope|非目标|不做/.test(heading) || /^(?:\*\*)?(?:non-goals?|out of scope|非目标|不做)\s*[:：]/.test(leading)) return "non_goal";
  if (/planned|future|not implemented|计划范围|计划中|未来范围|尚未实现/.test(heading) || /^(?:\*\*)?(?:planned(?: scope)?|future scope|not implemented|计划(?:范围)?|尚未实现)\s*[:：]/.test(leading)) return "planned";
  return "implemented";
}

function authorityForStatus(status) {
  if (status === "planned") return "planned";
  if (status === "non_goal") return "non_goal";
  if (status === "evidence") return "evidence";
  return "current_product";
}

function contextPrefixFor({ language, docPath, headingPath, status, authority, tags, chunkIndex, chunkCount }) {
  const location = `${docPath} > ${headingPath.join(" > ")}`;
  const part = chunkCount > 1 ? ` ${chunkIndex}/${chunkCount}` : "";
  return language === "zh"
    ? `来源: ${location}${part}。状态: ${status}。权威: ${authority}。标签: ${tags.join(", ")}。`
    : `Source: ${location}${part}. Status: ${status}. Authority: ${authority}. Tags: ${tags.join(", ")}. `;
}
