import type { NormalizedRagQuery, RetrievalCandidate } from "./types.ts";

export const rerankerVersion = "fitlog_document_reranker.v2";
const ownershipRules: Array<{ file: string; score: number; cues: RegExp[] }> = [
  {
    file: "/references.md",
    score: 0.9,
    cues: [
      /\b(citation|reference|evidence|source)\b.*\b(claim|support)\b/,
      /\bwhich evidence\b/,
      /引用.*(依据|支持|主张)/,
    ],
  },
  {
    file: "/agentdesign.md",
    score: 0.7,
    cues: [
      /(ai|agent).*(may|can|directly|permission|privacy|retain|write|modify)/,
      /(ai|智能体).*(能|可以|直接|权限|隐私|保留|写入|修改)/,
    ],
  },
  {
    file: "/ragdesign.md",
    score: 0.7,
    cues: [
      /(document rag|structured rag|embedding|retriev|vector|chunk)/,
      /(文档检索|结构化检索|嵌入|向量|分块)/,
    ],
  },
  {
    file: "/aioutputcontract.md",
    score: 0.7,
    cues: [
      /(invalid|malformed|json|output contract|correct|validation)/,
      /(无效|格式|输出合同|校正|验证)/,
    ],
  },
  {
    file: "/cloudlocaldataboundary.md",
    score: 0.7,
    cues: [
      /(source of truth|cloud authority|local cache|offline|conflict|repair)/,
      /(云端权威|正式数据源|本地缓存|离线|冲突|修复)/,
    ],
  },
  {
    file: "/database.md",
    score: 0.65,
    cues: [
      /(persist|schema|table|field|database|stored)/,
      /(持久化|数据库|表|字段|存储)/,
    ],
  },
  {
    file: "/algorithm.md",
    score: 0.7,
    cues: [
      /(calculate|formula|per.side|total reps|training volume)/,
      /(计算|公式|每侧|总次数|训练量|怎么算)/,
    ],
  },
  {
    file: "/methodology.md",
    score: 0.65,
    cues: [
      /(why|rationale|limitation|methodology)/,
      /(为什么|原理|理由|局限|方法论)/,
    ],
  },
  {
    file: "/appguide.md",
    score: 0.65,
    cues: [
      /(where|entry|navigation|which tab|screen)/,
      /(哪里|入口|导航|哪个.*tab|页面)/,
    ],
  },
  {
    file: "/product.md",
    score: 0.65,
    cues: [
      /(product promise|purpose|who is fitlog for|fitlog.*(?:promise|purpose|for whom|audience))/,
      /(产品承诺|产品目的|适合谁)/,
    ],
  },
];

export function fuseAndRerank(
  candidates: RetrievalCandidate[],
  query: NormalizedRagQuery,
  limit = 8,
): { candidates: RetrievalCandidate[]; degraded: boolean } {
  const deduped = dedupe(candidates);
  const fused = deduped.map((candidate) => {
    const lexical = candidate.lexical_rank === null
      ? 0
      : 1 / (60 + candidate.lexical_rank);
    const vector = candidate.vector_rank === null
      ? 0
      : 1 / (60 + candidate.vector_rank);
    const fusedScore = lexical + vector;
    return { ...candidate, fused_score: fusedScore };
  }).sort(compareFused);
  try {
    const reranked = fused.map((candidate) => ({
      ...candidate,
      rerank_score: rerankScore(candidate, query),
    })).sort((left, right) =>
      (right.rerank_score ?? 0) - (left.rerank_score ?? 0) ||
      compareFused(left, right)
    );
    return {
      candidates: diversify(reranked, limit, preferredLanguage(query)),
      degraded: false,
    };
  } catch {
    return {
      candidates: diversify(fused, limit, preferredLanguage(query)),
      degraded: true,
    };
  }
}

function rerankScore(
  candidate: RetrievalCandidate,
  query: NormalizedRagQuery,
): number {
  const fusedScore = candidate.fused_score;
  if (fusedScore === undefined || !Number.isFinite(fusedScore)) {
    throw new Error("invalid fused score");
  }
  const haystack = `${candidate.heading} ${candidate.content}`.toLowerCase();
  const exactConcepts =
    query.canonical_concepts.filter((concept) =>
      haystack.includes(concept.toLowerCase())
    ).length;
  const exactKeys =
    query.exercise_keys.filter((key) => haystack.includes(key.toLowerCase()))
      .length;
  const termCoverage = query.tokens.length === 0
    ? 0
    : query.tokens.filter((token) => haystack.includes(token)).length /
      query.tokens.length;
  const authority = candidate.authority === "current_product"
    ? 0.12
    : candidate.authority === "non_goal"
    ? -0.04
    : 0;
  const status =
    candidate.status === "implemented" || candidate.status === "evidence"
      ? 0.08
      : candidate.status === "non_goal"
      ? -0.04
      : -0.12;
  const language = candidate.language === preferredLanguage(query)
    ? 0.06
    : -0.02;
  const sourceOwnership = owningSourceScore(candidate, query);
  return fusedScore * 10 + exactConcepts * 0.35 + exactKeys * 0.4 +
    termCoverage * 0.2 + authority + status + language + sourceOwnership;
}

function preferredLanguage(query: NormalizedRagQuery): "zh" | "en" {
  return query.language_profile.value === "en" ? "en" : "zh";
}

function dedupe(candidates: RetrievalCandidate[]): RetrievalCandidate[] {
  const byId = new Map<string, RetrievalCandidate>();
  for (const candidate of candidates) {
    const key = `${candidate.doc_path}:${candidate.section_id}`;
    const existing = byId.get(key);
    if (!existing || compareFused(candidate, existing) < 0) {
      byId.set(key, candidate);
    }
  }
  return [...byId.values()];
}

function diversify(
  candidates: RetrievalCandidate[],
  limit: number,
  language: "zh" | "en",
): RetrievalCandidate[] {
  const preferred = candidates.filter((candidate) =>
    candidate.language === language
  );
  const secondary = candidates.filter((candidate) =>
    !preferred.includes(candidate)
  );
  const headingCounts = new Map<string, number>();
  const result: RetrievalCandidate[] = [];
  for (const candidate of [...preferred, ...secondary]) {
    const headingKey = `${candidate.doc_path}:${
      candidate.heading_path.join(">")
    }`;
    if ((headingCounts.get(headingKey) ?? 0) >= 2) continue;
    result.push(candidate);
    headingCounts.set(headingKey, (headingCounts.get(headingKey) ?? 0) + 1);
    if (result.length >= Math.min(Math.max(limit, 1), 12)) break;
  }
  return result;
}

function owningSourceScore(
  candidate: RetrievalCandidate,
  query: NormalizedRagQuery,
): number {
  const source = candidate.doc_path.toLowerCase();
  const text = query.normalized_query;
  return ownershipRules
    .filter((rule) =>
      source.endsWith(rule.file) && rule.cues.some((cue) => cue.test(text))
    )
    .reduce((score, rule) => Math.max(score, rule.score), 0);
}

export function hasOwningDocumentCue(query: NormalizedRagQuery): boolean {
  return ownershipRules.some((rule) =>
    rule.cues.some((cue) => cue.test(query.normalized_query))
  );
}

function compareFused(
  left: RetrievalCandidate,
  right: RetrievalCandidate,
): number {
  return (right.fused_score ?? rawScore(right)) -
      (left.fused_score ?? rawScore(left)) ||
    left.doc_path.localeCompare(right.doc_path) ||
    left.section_id.localeCompare(right.section_id);
}

function rawScore(candidate: RetrievalCandidate): number {
  return candidate.lexical_score + (candidate.vector_score ?? 0);
}
