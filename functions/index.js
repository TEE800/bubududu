// Push-Nachrichten an den Partner, wenn jemand etwas einträgt.
// Braucht den Blaze-Tarif in Firebase. Wird von GitHub Actions veröffentlicht.
import { initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { messageFor } from './messages.js';

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
