// Pflanzenerkennung über Pl@ntNet (https://my.plantnet.org, kostenlos bis
// 500 Erkennungen am Tag). Der Schlüssel steht als GitHub-Secret
// PLANTNET_API_KEY und landet beim Veröffentlichen in functions/.env.

export const PLANTNET_URL = 'https://my-api.plantnet.org/v2/identify/all';

/// Höchstens so groß darf ein Foto sein (die App schickt ~200 KB).
export const MAX_IMAGE_BYTES = 4 * 1024 * 1024;

/// Macht aus der Pl@ntNet-Antwort eine kurze Vorschlagsliste für die App.
export function toSuggestions(json, max = 5) {
  return (json?.results ?? [])
    .filter((r) => r?.species?.scientificNameWithoutAuthor)
    .slice(0, max)
    .map((r) => ({
      scientificName: r.species.scientificNameWithoutAuthor,
      genus: r.species.genus?.scientificNameWithoutAuthor ?? '',
      family: r.species.family?.scientificNameWithoutAuthor ?? '',
      commonNames: (r.species.commonNames ?? []).slice(0, 3),
      score: Math.round((r.score ?? 0) * 1000) / 1000,
    }));
}

/// Fragt Pl@ntNet. Gibt {status, body} für die App zurück.
export async function identify(bytes, { apiKey, fetchImpl = fetch }) {
  if (!apiKey) {
    return { status: 503, body: { error: 'not-configured' } };
  }
  if (!bytes?.length || bytes.length > MAX_IMAGE_BYTES) {
    return { status: 400, body: { error: 'bad-image' } };
  }
  const form = new FormData();
  form.append('images', new Blob([bytes], { type: 'image/jpeg' }), 'pflanze.jpg');
  form.append('organs', 'auto');
  const url = `${PLANTNET_URL}?api-key=${encodeURIComponent(apiKey)}` +
    '&lang=de&nb-results=5';
  const res = await fetchImpl(url, { method: 'POST', body: form });
  // 404 heißt bei Pl@ntNet: keine Pflanze erkannt.
  if (res.status === 404) return { status: 200, body: { suggestions: [] } };
  if (res.status === 429) return { status: 429, body: { error: 'quota' } };
  if (!res.ok) return { status: 502, body: { error: 'upstream', code: res.status } };
  return { status: 200, body: { suggestions: toSuggestions(await res.json()) } };
}
