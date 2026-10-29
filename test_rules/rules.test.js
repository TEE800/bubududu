// Prüft die Firestore-Regeln im Emulator: Nur Bubu und Dudu sehen ihre Daten.
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  arrayUnion,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  setDoc,
  Timestamp,
  updateDoc,
  where,
} from 'firebase/firestore';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-bubududu',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
  });
});

after(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'households/h1'), {
      name: 'Zuhause',
      inviteCode: 'ABC123',
      members: ['dudu', 'bubu'],
      memberNames: { dudu: 'Dudu', bubu: 'Bubu' },
    });
    await setDoc(doc(db, 'households/h1/shoppingItems/milch'), { text: 'Milch' });
    await setDoc(doc(db, 'households/h1/locations/bubu'), { lat: 1, lng: 2 });
    await setDoc(doc(db, 'households/solo'), {
      name: 'Neu',
      inviteCode: 'NEU123',
      members: ['dudu'],
      memberNames: { dudu: 'Dudu' },
    });
    await setDoc(doc(db, 'invites/NEU123'), { householdId: 'solo', createdBy: 'dudu' });
    await setDoc(doc(db, 'users/bubu'), { displayName: 'Bubu', householdId: 'h1' });
    await setDoc(doc(db, 'alexaLinks/amzn-dudu'), { householdId: 'h1', uid: 'dudu' });
  });
});

const as = (uid) => env.authenticatedContext(uid).firestore();

test('Mitglieder lesen und schreiben ihren Haushalt', async () => {
  const db = as('dudu');
  await assertSucceeds(getDoc(doc(db, 'households/h1')));
  await assertSucceeds(getDocs(collection(db, 'households/h1/shoppingItems')));
  await assertSucceeds(setDoc(doc(db, 'households/h1/events/kino'), { title: 'Kino' }));
  await assertSucceeds(updateDoc(doc(db, 'households/h1'), { name: 'Unser Nest' }));
});

test('Fremde sehen nichts', async () => {
  const db = as('fremd');
  await assertFails(getDoc(doc(db, 'households/h1')));
  await assertFails(getDocs(collection(db, 'households/h1/shoppingItems')));
  await assertFails(setDoc(doc(db, 'households/h1/shoppingItems/x'), { text: 'Spam' }));
  await assertFails(getDoc(doc(db, 'users/bubu')));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'households/h1')));
});

test('Mitglieder können die Mitgliederliste nicht ändern', async () => {
  await assertFails(
    updateDoc(doc(as('dudu'), 'households/h1'), { members: ['dudu', 'bubu', 'ex'] }),
  );
  await assertFails(updateDoc(doc(as('dudu'), 'households/h1'), { inviteCode: 'NEU' }));
});

test('Beitreten nur als zweites Mitglied und nur sich selbst', async () => {
  await assertSucceeds(getDoc(doc(as('bubu2'), 'invites/NEU123')));
  await assertFails(getDocs(collection(as('bubu2'), 'invites')));
  await assertFails(
    updateDoc(doc(as('bubu2'), 'households/solo'), {
      members: arrayUnion('bubu2', 'noch-wer'),
    }),
  );
  await assertSucceeds(
    updateDoc(doc(as('bubu2'), 'households/solo'), {
      members: arrayUnion('bubu2'),
      'memberNames.bubu2': 'Bubu',
    }),
  );
  // Voll: ein Dritter kommt nicht mehr rein.
  await assertFails(
    updateDoc(doc(as('dritter'), 'households/solo'), {
      members: arrayUnion('dritter'),
    }),
  );
});

test('Profil: nur das eigene', async () => {
  await assertSucceeds(getDoc(doc(as('bubu'), 'users/bubu')));
  await assertSucceeds(setDoc(doc(as('dudu'), 'users/dudu'), { displayName: 'Dudu' }));
  await assertFails(setDoc(doc(as('dudu'), 'users/bubu'), { displayName: 'Hacker' }));
});

test('Private Gesundheit: nur die Person selbst', async () => {
  await assertSucceeds(setDoc(doc(as('bubu'), 'users/bubu/health/a'), { title: 'Frauenarzt' }));
  await assertSucceeds(getDoc(doc(as('bubu'), 'users/bubu/health/a')));
  await assertFails(getDoc(doc(as('dudu'), 'users/bubu/health/a')));
  await assertFails(setDoc(doc(as('dudu'), 'users/bubu/health/b'), { title: 'x' }));
});

test('Standort: lesen beide, schreiben nur den eigenen', async () => {
  await assertSucceeds(getDoc(doc(as('dudu'), 'households/h1/locations/bubu')));
  await assertSucceeds(setDoc(doc(as('dudu'), 'households/h1/locations/dudu'), { lat: 3 }));
  await assertFails(setDoc(doc(as('dudu'), 'households/h1/locations/bubu'), { lat: 0 }));
  await assertFails(getDoc(doc(as('fremd'), 'households/h1/locations/bubu')));
});

test('Alexa: Code nur für den eigenen Haushalt, kurz gültig, nicht lesbar', async () => {
  const soon = () => Timestamp.fromMillis(Date.now() + 15 * 60 * 1000);
  const code = (uid, householdId, expiresAt = soon()) => ({ uid, householdId, expiresAt });
  await assertSucceeds(setDoc(doc(as('dudu'), 'alexaCodes/123456'), code('dudu', 'h1')));
  await assertFails(getDoc(doc(as('dudu'), 'alexaCodes/123456')));
  await assertFails(setDoc(doc(as('fremd'), 'alexaCodes/222222'), code('fremd', 'h1')));
  await assertFails(setDoc(doc(as('dudu'), 'alexaCodes/333333'), code('bubu', 'h1')));
  await assertFails(setDoc(doc(as('dudu'), 'alexaCodes/abc'), code('dudu', 'h1')));
  await assertFails(setDoc(
    doc(as('dudu'), 'alexaCodes/444444'),
    code('dudu', 'h1', Timestamp.fromMillis(Date.now() + 24 * 3600 * 1000)),
  ));
});

test('Alexa: Verbindung sehen und trennen nur die Person selbst', async () => {
  await assertSucceeds(getDocs(query(collection(as('dudu'), 'alexaLinks'), where('uid', '==', 'dudu'))));
  await assertFails(getDoc(doc(as('bubu'), 'alexaLinks/amzn-dudu')));
  await assertFails(setDoc(doc(as('dudu'), 'alexaLinks/amzn-x'), { householdId: 'h1', uid: 'dudu' }));
  await assertFails(deleteDoc(doc(as('bubu'), 'alexaLinks/amzn-dudu')));
  await assertSucceeds(deleteDoc(doc(as('dudu'), 'alexaLinks/amzn-dudu')));
});
