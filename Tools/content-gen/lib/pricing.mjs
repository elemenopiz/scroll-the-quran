// Pricing from the `claude-api` skill's model table (cached 2026-06-24),
// in US dollars per million tokens. Batch requests are billed at 50%.
export const PRICING = {
  "claude-opus-5":   { input: 5.0,  output: 25.0 },
  "claude-opus-4-8": { input: 5.0,  output: 25.0 },
  "claude-sonnet-5": { input: 2.0,  output: 10.0 },
  "claude-haiku-4-5":{ input: 1.0,  output: 5.0 },
  "claude-fable-5-1":{ input: 10.0, output: 50.0 },
};

export const BATCH_DISCOUNT = 0.5;
export const CACHE_WRITE_MULTIPLIER = 1.25; // 5-minute ephemeral write
export const CACHE_READ_MULTIPLIER = 0.1;

/** Rough thinking-token allowance per request by effort level. */
export const THINKING_TOKENS_BY_EFFORT = {
  low: 250, medium: 700, high: 1500, xhigh: 3000, max: 5000,
};

export function priceFor(model) {
  const p = PRICING[model];
  if (!p) {
    throw new Error(
      `No pricing for model "${model}". Known: ${Object.keys(PRICING).join(", ")}.`,
    );
  }
  return p;
}

/**
 * @param {object} a
 * @param {number} a.requests
 * @param {number} a.cachedSystemTokens  system prefix, written once then read
 * @param {number} a.uncachedInputTokens per-request user turn + schema
 * @param {number} a.outputTokens        per-request output incl. thinking
 */
export function estimateCost({ model, requests, cachedSystemTokens, uncachedInputTokens, outputTokens, batch = true }) {
  const p = priceFor(model);
  const d = batch ? BATCH_DISCOUNT : 1;
  const M = 1_000_000;
  // One cache write per batch (the prefix is identical across requests), the
  // rest are reads. Worst case a few extra writes if the 5-minute TTL lapses.
  const cacheWrite = (cachedSystemTokens * CACHE_WRITE_MULTIPLIER * p.input * d) / M;
  const cacheRead = (cachedSystemTokens * requests * CACHE_READ_MULTIPLIER * p.input * d) / M;
  const input = (uncachedInputTokens * requests * p.input * d) / M;
  const output = (outputTokens * requests * p.output * d) / M;
  return {
    cacheWrite, cacheRead, input, output,
    total: cacheWrite + cacheRead + input + output,
    inputTokens: cachedSystemTokens + (cachedSystemTokens + uncachedInputTokens) * requests,
    outputTokens: outputTokens * requests,
  };
}

export const usd = (n) => `$${n.toFixed(2)}`;
