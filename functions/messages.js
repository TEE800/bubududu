// Texte für Push-Nachrichten, wenn der Partner etwas einträgt.
// Getrennt von index.js, damit sie ohne Firebase testbar sind.

const euro = (cents) =>
  `${(cents / 100).toFixed(2).replace('.', ',')} €`;

const day = (ts) => {
  const d = ts?.toDate?.() ?? (ts instanceof Date ? ts : null);
  return d ? `${d.getDate()}.${d.getMonth() + 1}.` : '';
};

/**
 * Baut die Nachricht für ein neues Dokument in households/{id}/{collection}.
 * Gibt null zurück, wenn es dafür keine Benachrichtigung gibt.
 * @param {string} collection
 * @param {Record<string, any>} data
 * @param {string} name Anzeigename der Person, die es eingetragen hat
 * @param {string} recipient uid der Person, die die Nachricht bekommt
 */
export function messageFor(collection, data, name, recipient) {
  const t = data.title ?? data.text ?? data.name ?? '';
  switch (collection) {
    case 'shoppingItems':
      return {
        title: 'Einkaufsliste',
        body: `${name} hat „${t}“ auf die Einkaufsliste gesetzt.`,
        // Mehrere Einträge auf einmal (z. B. Rezept) ersetzen sich gegenseitig.
        tag: 'shopping',
      };
    case 'events':
      return {
        title: 'Neuer Termin',
        body: `${name} hat „${t}“ eingetragen${day(data.date) ? ` (${day(data.date)})` : ''}.`,
        tag: 'events',
      };
    case 'tasks':
      return {
        title: 'Haushalt',
        body: data.assignee === recipient
          ? `${name} hat dir „${t}“ zugeteilt.`
          : `${name} hat die Aufgabe „${t}“ angelegt.`,
        tag: 'tasks',
      };
    case 'expenses':
      if (data.category === 'Ausgleich') {
        return {
          title: 'Finanzen',
          body: `${name} hat ${euro(data.amountCents ?? 0)} ausgeglichen. Ihr seid quitt!`,
          tag: 'expenses',
        };
      }
      return {
        title: 'Finanzen',
        body: `${name} hat ${euro(data.amountCents ?? 0)} für „${t}“ eingetragen.`,
        tag: 'expenses',
      };
    case 'recipes':
      return { title: 'Neues Rezept', body: `${name} hat „${t}“ gespeichert. Lecker!`, tag: 'recipes' };
    case 'notes':
      return { title: 'Neue Notiz', body: `${name} hat „${t}“ notiert.`, tag: 'notes' };
    case 'trips':
      return { title: 'Reiseplanung', body: `${name} plant „${t}“.`, tag: 'trips' };
    case 'ideas':
      return { title: 'Neue Idee', body: `${name} hat eine Idee: „${t}“ 💚`, tag: 'ideas' };
    default:
      return null;
  }
}
