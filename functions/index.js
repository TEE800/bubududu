// Push-Nachrichten an den Partner, wenn jemand etwas einträgt, und der
// Alexa-Skill für die Einkaufsliste.
// Braucht den Blaze-Tarif in Firebase. Wird von GitHub Actions veröffentlicht.
import { SkillRequestSignatureVerifier, TimestampVerifier } from 'ask-sdk-express-adapter';
import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore, Timestamp } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { logger } from 'firebase-functions';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { onRequest } from 'firebase-functions/v2/https';
import { handleAlexa, MAX_CODE_ATTEMPTS } from './alexa.js';
import { messageFor } from './messages.js';
import { identify } from './plantnet.js';

initializeApp();
const db = getFirestore();

export const notifyPartner = onDocumentCreated(
  { document: 'households/{householdId}/{collection}/{docId}', region: 'europe-west3' },
  async (event) => {
    const { householdId, collection } = event.params;
    const data = event.data?.data();
    if (!data) return;
    const author = data.addedBy ?? data.createdBy;
    if (!author) return;

    const household = (await db.doc(`households/${householdId}`).get()).data();
    if (!household) return;
    const name = household.memberNames?.[author] ?? 'Dein Partner';

    for (const uid of household.members ?? []) {
      if (uid === author) continue;
      const message = messageFor(collection, data, name, uid);
      if (!message) continue;
      const userRef = db.doc(`users/${uid}`);
      const user = (await userRef.get()).data() ?? {};
      if (user.notify?.partner === false) continue;
      const tokens = user.fcmTokens ?? [];
      if (tokens.length === 0) continue;

      const result = await getMessaging().sendEachForMulticast({
        tokens,
        notification: { title: message.title, body: message.body },
        android: {
          priority: 'high',
          notification: { channelId: 'partner', tag: message.tag, color: '#1B5E20' },
        },
        data: { householdId, collection },
      });
      // Abgemeldete Geräte aufräumen.
      const stale = tokens.filter((_, i) => {
        const code = result.responses[i].error?.code;
        return code === 'messaging/registration-token-not-registered' ||
          code === 'messaging/invalid-registration-token';
      });
      if (stale.length) await userRef.update({ fcmTokens: FieldValue.arrayRemove(...stale) });
    }
  },
);

// Firestore für den Alexa-Skill:
//   alexaCodes/{code}       von der App angelegt, 15 Minuten gültig
//   alexaLinks/{alexaUser}  Amazon-Konto → Person und Haushalt
const alexaStore = {
  async getLink(alexaUser) {
    const link = (await db.doc(`alexaLinks/${alexaUser}`).get()).data();
    return link?.householdId && link?.uid ? link : null;
  },

  redeemCode(code, alexaUser) {
    return db.runTransaction(async (tx) => {
      const linkRef = db.doc(`alexaLinks/${alexaUser}`);
      const codeRef = db.doc(`alexaCodes/${code}`);
      const [linkSnap, codeSnap] = await Promise.all([tx.get(linkRef), tx.get(codeRef)]);
      const failed = linkSnap.data()?.failedCodes ?? 0;
      if (failed >= MAX_CODE_ATTEMPTS) return 'blocked';
      const data = codeSnap.data();
      if (!data || data.expiresAt.toMillis() < Date.now()) {
        tx.set(linkRef, { failedCodes: failed + 1 }, { merge: true });
        return 'invalid';
      }
      tx.set(linkRef, {
        householdId: data.householdId,
        uid: data.uid,
        linkedAt: FieldValue.serverTimestamp(),
        failedCodes: 0,
      });
      tx.delete(codeRef);
      return 'ok';
    });
  },

  async openItems(householdId) {
    const snap = await db
      .collection(`households/${householdId}/shoppingItems`)
      .orderBy('createdAt')
      .get();
    return snap.docs.filter((d) => !d.data().done).map((d) => d.data().text ?? '');
  },

  async addItems({ householdId, uid }, texts) {
    const items = db.collection(`households/${householdId}/shoppingItems`);
    const batch = db.batch();
    // Feste Abstände, damit die Reihenfolge der Sprache erhalten bleibt.
    const now = Date.now();
    texts.forEach((text, i) =>
      batch.set(items.doc(), {
        text,
        done: false,
        addedBy: uid,
        createdAt: Timestamp.fromMillis(now + i),
        source: 'alexa',
      }),
    );
    await batch.commit();
  },
};

// Zertifikate von Amazon werden zwischen Aufrufen zwischengespeichert.
const signatureVerifier = new SkillRequestSignatureVerifier();
const timestampVerifier = new TimestampVerifier();

// Adresse für die Alexa Developer Console (Endpoint → HTTPS).
export const alexa = onRequest({ region: 'europe-west3' }, async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).send('Nur für Alexa.');
    return;
  }
  const body = req.rawBody?.toString('utf8') ?? '';
  try {
    // Nur echte Anfragen von Amazon annehmen.
    await signatureVerifier.verify(body, req.headers);
    await timestampVerifier.verify(body);
  } catch (e) {
    logger.warn('Alexa-Anfrage abgelehnt', e.message);
    res.status(400).send('Ungültige Anfrage.');
    return;
  }
  const envelope = JSON.parse(body);
  // Optional auf den eigenen Skill beschränken (functions/.env: ALEXA_SKILL_ID=...).
  const skillId = process.env.ALEXA_SKILL_ID;
  const appId = envelope.context?.System?.application?.applicationId ??
    envelope.session?.application?.applicationId;
  if (skillId && appId !== skillId) {
    res.status(403).send('Falscher Skill.');
    return;
  }
  res.json(await handleAlexa(envelope, alexaStore));
});

// Pflanzenerkennung per Foto für die App (Mitglieder eines Haushalts).
// POST {householdId, image: Base64-JPEG}, Header Authorization: Bearer <ID-Token>.
export const identifyPlant = onRequest(
  { region: 'europe-west3', cors: true, memory: '256MiB', timeoutSeconds: 30 },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).json({ error: 'method' });
      return;
    }
    const token = (req.get('Authorization') ?? '').replace(/^Bearer /, '');
    let uid;
    try {
      uid = (await getAuth().verifyIdToken(token)).uid;
    } catch {
      res.status(401).json({ error: 'auth' });
      return;
    }
    const { householdId, image } = req.body ?? {};
    if (typeof householdId !== 'string' || !householdId || typeof image !== 'string') {
      res.status(400).json({ error: 'bad-request' });
      return;
    }
    const household = (await db.doc(`households/${householdId}`).get()).data();
    if (!household?.members?.includes(uid)) {
      res.status(403).json({ error: 'household' });
      return;
    }
    try {
      const result = await identify(Buffer.from(image, 'base64'), {
        apiKey: process.env.PLANTNET_API_KEY,
      });
      if (result.status >= 500) logger.warn('Pflanzenerkennung', result.body);
      res.status(result.status).json(result.body);
    } catch (e) {
      logger.error('Pflanzenerkennung fehlgeschlagen', e);
      res.status(502).json({ error: 'upstream' });
    }
  },
);
