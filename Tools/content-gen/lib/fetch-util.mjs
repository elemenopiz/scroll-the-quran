// Polite HTTP helpers: sequential requests, a small delay between them, and
// bounded retries with backoff. Node 24 built-ins only (global fetch).

export const USER_AGENT =
  "scroll-the-quran-content-gen/1.0 (+one-off ingest; contact via repository)";

/** Sleep for `ms` milliseconds. */
export const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

/**
 * Fetch a URL with retries. Retries on network errors and on 5xx/429 responses.
 *
 * @param {string} url
 * @param {object} [opts]
 * @param {number} [opts.retries=3]      attempts after the first one
 * @param {number} [opts.backoffMs=750]  base backoff, multiplied by attempt number
 * @param {number} [opts.timeoutMs=60000]
 * @param {object} [opts.init]           extra fetch init (method, body, headers)
 * @param {(msg:string)=>void} [opts.log]
 * @returns {Promise<Response>}
 */
export async function fetchWithRetry(url, opts = {}) {
  const { retries = 3, backoffMs = 750, timeoutMs = 60_000, init = {}, log = () => {} } = opts;
  let lastError;
  for (let attempt = 0; attempt <= retries; attempt += 1) {
    if (attempt > 0) {
      const wait = backoffMs * attempt;
      log(`  retry ${attempt}/${retries} in ${wait} ms - ${lastError}`);
      await sleep(wait);
    }
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const res = await fetch(url, {
        redirect: "follow",
        ...init,
        signal: controller.signal,
        headers: { "user-agent": USER_AGENT, ...(init.headers ?? {}) },
      });
      if (res.status >= 500 || res.status === 429) {
        lastError = `HTTP ${res.status}`;
        continue;
      }
      if (!res.ok) throw new Error(`HTTP ${res.status} for ${url}`);
      return res;
    } catch (err) {
      if (err instanceof Error && err.message.startsWith("HTTP ")) throw err;
      lastError = err instanceof Error ? err.message : String(err);
    } finally {
      clearTimeout(timer);
    }
  }
  throw new Error(`fetchWithRetry: gave up on ${url} after ${retries + 1} attempts (${lastError})`);
}

/** Fetch and return the body as text. */
export async function fetchText(url, opts) {
  const res = await fetchWithRetry(url, opts);
  return await res.text();
}

/** Fetch and return the body parsed as JSON. */
export async function fetchJson(url, opts) {
  const body = await fetchText(url, opts);
  try {
    return JSON.parse(body);
  } catch {
    throw new Error(`fetchJson: ${url} did not return JSON (first 120 chars: ${body.slice(0, 120)})`);
  }
}

/** Fetch and return the body as a Buffer. */
export async function fetchBuffer(url, opts) {
  const res = await fetchWithRetry(url, opts);
  return Buffer.from(await res.arrayBuffer());
}
