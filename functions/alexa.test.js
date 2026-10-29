import assert from 'node:assert/strict';
import { test } from 'node:test';
import { handleAlexa, joinGerman, parseItems } from './alexa.js';

const intent = (name, slots = {}) => ({
  session: { user: { userId: 'amzn1.ask.account.kevin' } },
  request: {
    type: 'IntentRequest',
    intent: {
      name,
      slots: Object.fromEntries(Object.entries(slots).map(([k, value]) => [k, { name: k, value }])),
    },
  },
});

function fakeStore({ linked = true, items = [] } = {}) {
  const store = {
    link: linked ? { householdId: 'h1', uid: 'dudu' } : null,
    items: [...items],
    added: [],
    codes: { 123456: { householdId: 'h1', uid: 'dudu' } },
    async getLink() {
      return store.link;
    },
    async redeemCode(code) {
      if (!store.codes[code]) return 'invalid';
      store.link = store.codes[code];
      return 'ok';
    },
    async openItems() {
      return store.items;
    },
    async addItems(link, texts) {
      store.added.push({ link, texts });
      store.items.push(...texts);
    },
  };
  return store;
}

const speech = (r) => r.response.outputSpeech.text;

test('parseItems zerlegt und schreibt groß', () => {
  assert.deepEqual(parseItems('milch'), ['Milch']);
  assert.deepEqual(parseItems('milch und eier'), ['Milch', 'Eier']);
  assert.deepEqual(parseItems('noch brot, butter und käse bitte'), ['Brot', 'Butter', 'Käse']);
  assert.deepEqual(parseItems('frische milch auf die liste'), ['Frische milch']);
  assert.deepEqual(parseItems('hundefutter'), ['Hundefutter']);
  assert.deepEqual(parseItems(''), []);
  assert.deepEqual(parseItems(undefined), []);
});

test('joinGerman', () => {
  assert.equal(joinGerman(['Milch']), 'Milch');
  assert.equal(joinGerman(['Milch', 'Eier']), 'Milch und Eier');
  assert.equal(joinGerman(['Milch', 'Eier', 'Brot']), 'Milch, Eier und Brot');
});

test('Einträge landen auf der Liste', async () => {
  const store = fakeStore();
  const r = await handleAlexa(intent('AddItemIntent', { item: 'milch und eier' }), store);
  assert.deepEqual(store.added, [{ link: { householdId: 'h1', uid: 'dudu' }, texts: ['Milch', 'Eier'] }]);
  assert.equal(speech(r), 'Milch und Eier stehen jetzt auf der Liste.');
  assert.equal(r.response.shouldEndSession, true);
});

test('Was schon offen draufsteht, kommt nicht doppelt', async () => {
  const store = fakeStore({ items: ['Milch'] });
  const r = await handleAlexa(intent('AddItemIntent', { item: 'milch und brot' }), store);
  assert.deepEqual(store.added[0].texts, ['Brot']);
  assert.equal(speech(r), 'Brot steht jetzt auf der Liste. Milch stand schon drauf.');
});

test('Liste vorlesen', async () => {
  assert.equal(
    speech(await handleAlexa(intent('ReadListIntent'), fakeStore())),
    'Die Einkaufsliste ist leer.',
  );
  assert.equal(
    speech(await handleAlexa(intent('ReadListIntent'), fakeStore({ items: ['Milch', 'Eier', 'Brot'] }))),
    'Auf der Liste stehen 3 Sachen: Milch, Eier und Brot.',
  );
});

test('Ohne Verbindung wird nichts eingetragen', async () => {
  const store = fakeStore({ linked: false });
  const r = await handleAlexa(intent('AddItemIntent', { item: 'milch' }), store);
  assert.equal(store.added.length, 0);
  assert.match(speech(r), /noch nicht mit eurer App verbunden/);
});

test('Verbinden mit Code aus der App', async () => {
  const store = fakeStore({ linked: false });
  assert.match(speech(await handleAlexa(intent('LinkIntent', { code: '999999' }), store)), /kenne ich nicht/);
  assert.match(speech(await handleAlexa(intent('LinkIntent', { code: '12' }), store)), /sechs Ziffern/);
  assert.match(speech(await handleAlexa(intent('LinkIntent', { code: '123456' }), store)), /verbunden/);
  await handleAlexa(intent('AddItemIntent', { item: 'milch' }), store);
  assert.deepEqual(store.added[0].texts, ['Milch']);
});

test('Sitzungsende braucht keine Antwort', async () => {
  const r = await handleAlexa({ request: { type: 'SessionEndedRequest' } }, fakeStore());
  assert.deepEqual(r, { version: '1.0', response: {} });
});
