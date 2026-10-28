import assert from 'node:assert/strict';
import { test } from 'node:test';
import { messageFor } from './messages.js';

test('Einkaufsliste', () => {
  const m = messageFor('shoppingItems', { text: 'Milch', addedBy: 'f' }, 'Bubu', 'k');
  assert.equal(m.body, 'Bubu hat „Milch“ auf die Einkaufsliste gesetzt.');
  assert.equal(m.tag, 'shopping');
});

test('Termin mit Datum', () => {
  const m = messageFor('events', { title: 'Kino', date: new Date(2026, 10, 3) }, 'Dudu', 'f');
  assert.equal(m.body, 'Dudu hat „Kino“ eingetragen (3.11.).');
});

test('Aufgabe für mich oder allgemein', () => {
  assert.equal(
    messageFor('tasks', { title: 'Bad', assignee: 'k' }, 'Bubu', 'k').body,
    'Bubu hat dir „Bad“ zugeteilt.',
  );
  assert.equal(
    messageFor('tasks', { title: 'Bad', assignee: '' }, 'Bubu', 'k').body,
    'Bubu hat die Aufgabe „Bad“ angelegt.',
  );
});

test('Ausgaben und Ausgleich', () => {
  assert.equal(
    messageFor('expenses', { title: 'Pizza', amountCents: 2340 }, 'Dudu', 'f').body,
    'Dudu hat 23,40 € für „Pizza“ eingetragen.',
  );
  assert.match(
    messageFor('expenses', { title: 'Ausgleich', category: 'Ausgleich', amountCents: 500 }, 'Dudu', 'f').body,
    /quitt/,
  );
});

test('Interne Sammlungen bleiben still', () => {
  for (const c of ['taskLog', 'locations', 'health', 'mealPlan', 'pantry']) {
    assert.equal(messageFor(c, { title: 'x' }, 'Bubu', 'k'), null);
  }
});
