import test from "node:test";
import assert from "node:assert/strict";
import { voiceFindings, VOICE_VERSION } from "../lib/voice.mjs";

test("structure-talk is flagged in the reader-facing sections but not in didYouKnow", () => {
  const t = "The ayah is built from denials and possessions. God is alive and stands without support, so nothing outside Him holds Him up.";
  assert.equal(voiceFindings("meaning", t).length, 1);
  assert.match(voiceFindings("meaning", t)[0], /structure/);
  assert.deepEqual(voiceFindings("didYouKnow", t), []);
  assert.equal(voiceFindings("theologicalSignificance", "Three statements, each narrowing the last. Every soul tastes death and the wages are paid later in full.").length, 1);
});

test("fragment stacks and choppy means are flagged; varied prose passes", () => {
  const choppy = "Not rank. Not honour. Simply let in. Every soul tastes death. Wages come later. That is all.";
  const f = voiceFindings("theologicalSignificance", choppy);
  assert.ok(f.some((x) => /fragments in a row/.test(x)), f.join("\n"));
  assert.ok(f.some((x) => /choppy/.test(x)), f.join("\n"));
  const good = "This verse says three hard things in a row, and each one is a kindness. Every soul will taste death, so the thing you fear most is not a trap set for you alone. It is the road everyone walks. You will be paid in full on the Day of Resurrection, so nothing you did was wasted.";
  assert.deepEqual(voiceFindings("meaning", good), []);
});

test("a single short sentence for emphasis is allowed", () => {
  const t = "The verse tells you about God mostly by saying what He is not: not tired, not asleep, not propped up, not burdened. That is on purpose. Any picture you could form of Him would be too small, so the verse keeps clearing pictures away.";
  assert.deepEqual(voiceFindings("theologicalSignificance", t), []);
  assert.equal(VOICE_VERSION, "v2");
});
