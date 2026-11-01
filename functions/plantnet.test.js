import assert from 'node:assert/strict';
import { test } from 'node:test';
import { identify, toSuggestions } from './plantnet.js';

const answer = {
  results: [
    {
      score: 0.90734,
      species: {
        scientificNameWithoutAuthor: 'Monstera deliciosa',
        genus: { scientificNameWithoutAuthor: 'Monstera' },
        family: { scientificNameWithoutAuthor: 'Araceae' },
        commonNames: ['Fensterblatt', 'Köstliches Fensterblatt', 'Monstera', 'x'],
      },
    },
    { score: 0.02, species: {} },
  ],
};

test('Vorschläge aus der Antwort', () => {
  assert.deepEqual(toSuggestions(answer), [
    {
      scientificName: 'Monstera deliciosa',
      genus: 'Monstera',
      family: 'Araceae',
      commonNames: ['Fensterblatt', 'Köstliches Fensterblatt', 'Monstera'],
      score: 0.907,
    },
  ]);
  assert.deepEqual(toSuggestions({}), []);
});

test('Ohne Schlüssel nicht eingerichtet', async () => {
  const r = await identify(new Uint8Array([1]), { apiKey: '' });
  assert.equal(r.status, 503);
});

test('Fragt Pl@ntNet auf Deutsch', async () => {
  let called;
  const r = await identify(new Uint8Array([1, 2]), {
    apiKey: 'k',
    fetchImpl: async (url, opts) => {
      called = { url, opts };
      return { ok: true, status: 200, json: async () => answer };
    },
  });
  assert.match(called.url, /api-key=k&lang=de/);
  assert.equal(called.opts.body.get('organs'), 'auto');
  assert.equal(r.body.suggestions[0].scientificName, 'Monstera deliciosa');
});

test('Nichts erkannt und Tageslimit', async () => {
  const fake = (status) => async () => ({ ok: false, status });
  assert.deepEqual((await identify(new Uint8Array([1]), { apiKey: 'k', fetchImpl: fake(404) })).body, { suggestions: [] });
  assert.equal((await identify(new Uint8Array([1]), { apiKey: 'k', fetchImpl: fake(429) })).status, 429);
});
