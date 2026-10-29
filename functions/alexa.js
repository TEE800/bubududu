// Alexa-Skill "Bubu Dudu": Einträge per Sprache auf die Einkaufsliste.
// Getrennt von index.js, damit die Logik ohne Firebase testbar ist.
//
// Verbinden: In der App (Mehr → Einstellungen → Alexa) einen Code holen und
// "Alexa, sag Bubu Dudu, Code 123456" sagen. Danach gehört dieses Amazon-Konto
// zu dieser Person und ihrem Haushalt.

/** Nach so vielen falschen Codes nimmt der Skill keine Codes mehr an. */
export const MAX_CODE_ATTEMPTS = 10;

/**
 * Zerlegt "milch und eier" in ["Milch", "Eier"].
 * @param {string | undefined} said
 * @returns {string[]}
 */
export function parseItems(said) {
  if (!said) return [];
  return said
    .toLowerCase()
    .replace(/\b(auf die (einkaufs)?liste|bitte)\b/g, ' ')
    .split(/,|\bund\b|\bsowie\b/)
    .map((s) => s.replace(/^\s*(noch|etwas|ein bisschen)\s+/, '').replace(/\s+/g, ' ').trim())
    .filter(Boolean)
    .map((s) => s[0].toUpperCase() + s.slice(1));
}

/** "Milch", "Milch und Eier", "Milch, Eier und Brot" */
export function joinGerman(list) {
  if (list.length <= 1) return list.join('');
  return `${list.slice(0, -1).join(', ')} und ${list.at(-1)}`;
}

const say = (text, { end = true, reprompt } = {}) => ({
  version: '1.0',
  response: {
    outputSpeech: { type: 'PlainText', text },
    ...(reprompt ? { reprompt: { outputSpeech: { type: 'PlainText', text: reprompt } } } : {}),
    shouldEndSession: end,
  },
});

const NOT_LINKED =
  'Ich bin noch nicht mit eurer App verbunden. Öffne in der App Mehr, Einstellungen, ' +
  'Alexa verbinden, und sag mir dann einfach die sechs Ziffern.';
const ASK_CODE = 'Wie lautet der Code aus der App?';

const EXAMPLE = 'Sag zum Beispiel: setz Milch auf die Liste. Oder: was steht auf der Liste?';

/**
 * Beantwortet eine Alexa-Anfrage.
 *
 * @param {any} envelope Der JSON-Body von Alexa (schon auf Echtheit geprüft)
 * @param {{
 *   getLink(alexaUser: string): Promise<{ householdId: string, uid: string } | null>,
 *   redeemCode(code: string, alexaUser: string): Promise<'ok' | 'invalid' | 'blocked'>,
 *   openItems(householdId: string): Promise<string[]>,
 *   addItems(link: { householdId: string, uid: string }, texts: string[]): Promise<void>,
 * }} store
 */
export async function handleAlexa(envelope, store) {
  const request = envelope?.request ?? {};
  const alexaUser = envelope?.session?.user?.userId ?? envelope?.context?.System?.user?.userId;
  if (request.type === 'SessionEndedRequest') return { version: '1.0', response: {} };
  if (!alexaUser) return say('Das hat leider nicht geklappt.');

  const intent = request.type === 'IntentRequest' ? request.intent?.name : request.type;
  const slot = (name) => request.intent?.slots?.[name]?.value;

  switch (intent) {
    case 'AMAZON.StopIntent':
    case 'AMAZON.CancelIntent':
    case 'AMAZON.NavigateHomeIntent':
      return say('Tschüss!');
    case 'LinkIntent': {
      const code = String(slot('code') ?? '').replace(/\D/g, '');
      if (code.length !== 6) {
        return say('Der Code hat sechs Ziffern. Sag sie bitte nochmal.', {
          end: false,
          reprompt: ASK_CODE,
        });
      }
      const result = await store.redeemCode(code, alexaUser);
      if (result === 'ok') {
        return say('Super, ich bin jetzt mit eurer Einkaufsliste verbunden. ' + EXAMPLE);
      }
      if (result === 'blocked') {
        return say('Es wurden zu viele falsche Codes gesagt. Ich nehme gerade keine Codes mehr an.');
      }
      return say('Den Code kenne ich nicht oder er ist abgelaufen. Hol dir in der App einen neuen und sag ihn mir.', {
        end: false,
        reprompt: ASK_CODE,
      });
    }
  }

  const link = await store.getLink(alexaUser);
  // Sitzung offen lassen, damit man direkt danach nur die Zahl sagen kann.
  if (!link) return say(NOT_LINKED, { end: false, reprompt: ASK_CODE });

  switch (intent) {
    case 'LaunchRequest':
      return say('Hallo! Was soll auf die Einkaufsliste? ' + EXAMPLE, {
        end: false,
        reprompt: EXAMPLE,
      });
    case 'AddItemIntent':
    // Nur das Wort, z. B. "Alexa, sag Bubu Dudu, Milch".
    case 'QuickAddIntent': {
      const wanted = parseItems(slot('item'));
      if (wanted.length === 0) {
        return say('Was soll auf die Liste?', { end: false, reprompt: EXAMPLE });
      }
      const open = new Set((await store.openItems(link.householdId)).map((t) => t.toLowerCase()));
      const fresh = [...new Set(wanted)].filter((t) => !open.has(t.toLowerCase()));
      const already = wanted.filter((t) => !fresh.includes(t));
      if (fresh.length) await store.addItems(link, fresh);
      const parts = [];
      if (fresh.length) parts.push(`${joinGerman(fresh)} ${fresh.length === 1 ? 'steht' : 'stehen'} jetzt auf der Liste.`);
      if (already.length) parts.push(`${joinGerman(already)} ${already.length === 1 ? 'stand' : 'standen'} schon drauf.`);
      return say(parts.join(' '));
    }
    case 'ReadListIntent': {
      const items = await store.openItems(link.householdId);
      if (items.length === 0) return say('Die Einkaufsliste ist leer.');
      if (items.length === 1) return say(`Auf der Liste steht nur ${items[0]}.`);
      const shown = items.slice(0, 15);
      const more = items.length > shown.length ? `, und noch ${items.length - shown.length} weitere` : '';
      return say(`Auf der Liste stehen ${items.length} Sachen: ${joinGerman(shown)}${more}.`);
    }
    case 'AMAZON.HelpIntent':
    case 'AMAZON.FallbackIntent':
    default:
      return say(EXAMPLE, { end: false, reprompt: 'Was soll auf die Liste?' });
  }
}
