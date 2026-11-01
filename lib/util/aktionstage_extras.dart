/// Zusätze zu den Aktionstagen: eine Idee, was man zu zweit daraus machen
/// kann, und der Titel des passenden Wikipedia-Artikels, wenn er anders
/// heißt als der Tag selbst. Schlüssel ist jeweils der Name des Tages.
library;

const aktionstagIdeen = <String, String>{
  // Januar
  'Weltfriedenstag': 'Schreibt euch gegenseitig einen guten Wunsch fürs neue Jahr auf und hebt die Zettel bis Silvester auf.',
  'Tag der Bloody Mary':
      'Katerfrühstück mit Rührei und einer (alkoholfreien) Virgin Mary.',
  'Welttag der Introvertierten': 'Ein ruhiger Abend ohne Verabredungen: jeder mit Buch oder Kopfhörer auf dem Sofa, einfach nebeneinander.',
  'Tag der Science-Fiction': 'Filmabend mit einem Science-Fiction-Klassiker, zum Beispiel "Zurück in die Zukunft" oder "Interstellar".',
  'Tag des Strohhalms': 'Heute gibt es Milchshakes, natürlich mit zwei Strohhalmen in einem Glas.',
  'Welt-Braille-Tag': 'Schaut euch an, wie das Braille-Alphabet aussieht, und ertastet die Punkte auf Medikamentenpackungen.',
  'Tag der Spaghetti':
      'Spaghetti zum Abendessen. Wer die längste Nudel am Stück isst, gewinnt.',
  'Tag der Schlagsahne': 'Heiße Schokolade mit einem riesigen Sahneberg.',
  'Heilige Drei Könige': 'Wenn Sternsinger klingeln: Tür auf und etwas spenden. Danach ist der Weihnachtsbaum dran.',
  'Tag der Bohne':
      'Chili sin oder con Carne kochen, mit möglichst vielen Bohnensorten.',
  'Orthodoxes Weihnachten':
      'Eine gute Ausrede, die letzten Plätzchen aufzuessen.',
  'Tag der Erdrotation': 'Schaut abends in den Himmel und sucht einen Stern. Eine Stunde später steht er woanders, weil die Erde sich dreht.',
  'Tag des Schaumbads': 'Badewanne einlassen, Kerzen an, Musik dazu.',
  'Tag der statischen Aufladung':
      'Luftballon an den Haaren reiben und schauen, wessen Haare höher stehen.',
  'Tag der Zimmerpflanzen': 'Gemeinsam alle Pflanzen gießen und abstauben. In der App bei den Pflanzen nachschauen, wer was braucht.',
  'Tag des Dankeschöns': 'Sagt euch gegenseitig drei Dinge, für die ihr euch beim anderen bedanken wollt.',
  'Tag des Marzipans':
      'Marzipankartoffeln oder ein Stück Marzipanbrot zum Kaffee.',
  'Tag des Haustier-Verkleidens': 'Falls ein Tier im Haus ist: höchstens ein Halstuch. Sonst verkleidet ihr euch einfach selbst.',
  'Wikipedia-Tag': 'Klickt auf "Zufälliger Artikel" und lest euch gegenseitig vor, was ihr findet.',
  'Tag des Hutes': 'Jeder setzt den albernsten Hut auf, den er findet, und macht ein Foto davon.',
  'Tag des Nichts': 'Wirklich nichts tun. Kein Haushalt, keine Pläne, kein schlechtes Gewissen.',
  'Tag der Kinder-Erfinder': 'Überlegt euch zusammen eine Erfindung, die euren Alltag leichter machen würde.',
  'Tag von Winnie Puuh':
      'Honigbrot zum Frühstück und ein Kapitel "Pu der Bär" vorlesen.',
  'Tag des Popcorns':
      'Popcorn selbst machen, süß oder salzig, und dazu einen Film.',
  'Tag des Pinguins': 'Watschelt wie Pinguine durch die Wohnung oder schaut eine Tierdoku über Pinguine.',
  'Weltknuddeltag':
      'Heute zählt jede Umarmung doppelt. Zehn Stück sind das Minimum.',
  'Tag der Jogginghose':
      'Offizielle Erlaubnis für einen Tag in Jogginghose, auch beim Einkaufen.',
  'Deutsch-Französischer Tag': 'Französisch frühstücken mit Croissants und Café au Lait oder abends Crêpes machen.',
  'Tag der Handschrift': 'Schreibt dem anderen einen handgeschriebenen Liebeszettel und versteckt ihn irgendwo.',
  'Internationaler Tag der Bildung':
      'Bringt euch gegenseitig etwas bei, das der andere noch nicht kann.',
  'Tag des Kompliments':
      'Jeder macht dem anderen heute mindestens drei ehrliche Komplimente.',
  'Internationaler Tag des Zolls': 'Bevor die nächste Reise ansteht: Nachlesen, was man aus dem Urlaub zollfrei mitbringen darf.',
  'Tag des Gedenkens an die Opfer des Nationalsozialismus': 'Nehmt euch einen Moment Zeit, vielleicht für einen Stolperstein in eurer Nähe. Die Adressen findet man online.',
  'Europäischer Datenschutztag': 'Prüft zusammen, welche Apps auf euren Handys auf Standort, Kamera und Kontakte zugreifen dürfen.',
  'Tag des LEGO-Steins': 'Baut zusammen etwas aus LEGO oder schaut, ob noch alte Steine im Keller liegen.',
  'Tag des Puzzles': 'Ein Puzzle auf dem Esstisch anfangen. Es darf ruhig ein paar Tage liegen bleiben.',
  'Welttag der vernachlässigten Tropenkrankheiten': 'Vor der nächsten Fernreise nachschauen, welche Impfungen empfohlen sind.',
  'Tag des Croissants': 'Frühstück mit frischen Croissants vom Bäcker.',
  'Tag des Rückwärts': 'Abendessen mit dem Nachtisch anfangen.',

  // Februar
  'Tag des Passwortwechsels': 'Zusammen alte Passwörter ändern und über einen Passwort-Manager nachdenken.',
  'Welttag der Feuchtgebiete':
      'Ein Spaziergang an einen See, Fluss oder ins Moor in eurer Nähe.',
  'Murmeltiertag': '"Und täglich grüßt das Murmeltier" schauen. Am besten zweimal hintereinander.',
  'Tag des Karottenkuchens': 'Zusammen einen Rüblikuchen backen.',
  'Weltkrebstag': 'Fragt euch gegenseitig, wann ihr zuletzt bei einer Vorsorgeuntersuchung wart, und tragt Termine in den Kalender ein.',
  'Welt-Nutella-Tag': 'Nutella-Frühstück, mit Brötchen, Pfannkuchen oder einfach mit dem Löffel.',
  'Internationaler Tag gegen weibliche Genitalverstümmelung':
      'Organisationen wie Terre des Femmes freuen sich über Spenden.',
  'Tag des Drachensteigens':
      'Bei Wind einen Drachen steigen lassen oder zusammen einen basteln.',
  'Tag der Pizza': 'Pizzaabend: Jeder belegt seine Hälfte, wie er will.',
  'Welttag der Hülsenfrüchte': 'Ein Linsencurry oder Hummus selber machen.',
  'Tag des Regenschirms':
      'Spaziergang im Regen, unter einem gemeinsamen Schirm.',
  'Europäischer Tag des Notrufs 112': 'Prüft, ob auf euren Handys der Notfallpass mit Blutgruppe und Allergien eingerichtet ist.',
  'Internationaler Tag der Frauen und Mädchen in der Wissenschaft':
      'Schaut eine Doku über eine berühmte Forscherin, etwa Marie Curie.',
  'Darwin-Tag': 'Tierdoku-Abend oder ein Besuch im Naturkundemuseum.',
  'Welttag des Radios': 'Heute statt Playlist mal wieder Radio hören.',
  'Valentinstag': 'Ein Abend nur für euch zwei: schön essen gehen oder zu Hause kochen, mit Kerzen.',
  'Internationaler Kinderkrebstag':
      'Die Deutsche Kinderkrebsstiftung freut sich über Spenden.',
  'Tag der zufälligen Freundlichkeit':
      'Jeder überrascht den anderen heute mit einer kleinen Aufmerksamkeit.',
  'Tag der Batterie':
      'Alle Rauchmelder testen und leere Batterien zum Sammeln bringen.',
  'Welttag der sozialen Gerechtigkeit':
      'Ein guter Tag für eine kleine Spende an die Tafel in eurer Stadt.',
  'Tag der Liebe zu Haustieren':
      'Einen Nachmittag im Tierheim aushelfen oder Hunde ausführen.',
  'Internationaler Tag der Muttersprache':
      'Bringt euch gegenseitig ein Wort aus eurem Dialekt bei.',
  'Weltdenktag der Pfadfinder':
      'Erzählt euch von euren Kindheitsabenteuern draußen.',
  'Tag der Margarita': 'Margaritas mixen, für den Fahrer alkoholfrei.',
  'Tag des Hundekekses': 'Hundekekse backen und dem Nachbarshund schenken.',
  'Tag der Tortilla-Chips':
      'Nachos überbacken mit Käse, Jalapeños und Guacamole.',
  'Tag des Märchenerzählens':
      'Erfindet abwechselnd Satz für Satz ein Märchen über Bubu und Dudu.',
  'Internationaler Eisbärentag': 'Eisbär-Livestreams aus der Arktis anschauen.',
  'Schalttag': 'Ein geschenkter Tag. Macht etwas, das ihr sonst nie macht.',

  // März
  'Tag gegen Diskriminierung':
      'Redet darüber, wo ihr selbst schon einmal ungerecht behandelt wurdet.',
  'Welttag des Kompliments':
      'Schreibt dem anderen ein Kompliment auf einen Zettel am Spiegel.',
  'Welttag des Artenschutzes': 'Ein Besuch im Zoo oder Wildpark. Viele Zoos unterstützen Artenschutzprojekte.',
  'Welttag des Hörens': 'Hörspiel- oder Podcastabend im Dunkeln.',
  'Tag der Grammatik':
      'Wer findet die meisten Fehler auf Schildern beim Spaziergang?',
  'Tag der gesunden Ernährung': 'Zusammen ein neues Gemüserezept ausprobieren.',
  'Internationaler Frauentag': 'Schenkt Blumen an Frauen, die euch wichtig sind, zum Beispiel an eure Mütter.',
  'Tag der Barbie': 'Den "Barbie"-Film von 2023 schauen.',
  'Mario-Tag': 'Mario Kart spielen. Der Verlierer macht den Abwasch.',
  'Europäischer Gedenktag für die Opfer des Terrorismus':
      'Ein stiller Moment für die Opfer.',
  'Welttag gegen Internetzensur': 'Lest einen Artikel von Reporter ohne Grenzen über Pressefreiheit weltweit.',
  'Pi-Tag': 'Einen Kuchen backen, natürlich einen runden.',
  'Weltverbrauchertag':
      'Verträge in der App durchgehen: Gibt es Abos, die ihr kündigen könnt?',
  'St. Patrick\'s Day':
      'Tragt etwas Grünes und trinkt ein Guinness oder ein grünes Getränk.',
  'Josefstag': 'Gratuliert allen Josefs und Josefinen, die ihr kennt.',
  'Internationaler Tag der Frankophonie':
      'Ein französisches Chanson hören und Croque Monsieur machen.',
  'Weltglückstag':
      'Schreibt jeder drei Dinge auf, die euch beim anderen glücklich machen.',
  'Internationaler Tag gegen Rassismus': 'Überlegt, wie ihr euch verhaltet, wenn ihr rassistische Sprüche mitbekommt.',
  'Welt-Down-Syndrom-Tag': 'Zieht zwei unterschiedliche, bunte Socken an.',
  'Internationaler Tag des Waldes': 'Ein langer Waldspaziergang.',
  'Weltwassertag': 'Trinkt heute bewusst genug Wasser und vergleicht, wer mehr geschafft hat.',
  'Welttag der Meteorologie':
      'Wettet, wie das Wetter morgen wird. Die App zeigt, wer recht hat.',
  'Tag des Welpen': 'Hundevideos schauen ist heute ausdrücklich erlaubt.',
  'Welttuberkulosetag': 'Schaut nach, ob eure Impfungen noch aktuell sind.',
  'Gedenktag für die Opfer der Sklaverei':
      'Den Film "12 Years a Slave" schauen.',
  'Tolkien-Lesetag': 'Ein Kapitel aus "Der Hobbit" vorlesen oder die Herr-der-Ringe-Filme starten.',
  'Tag der selbst erfundenen Feiertage': 'Erfindet euren eigenen Feiertag und tragt ihn in den gemeinsamen Kalender ein.',
  'Welttheatertag':
      'Karten fürs Theater besorgen, auch eine kleine Bühne zählt.',
  'Tag der Transgender-Sichtbarkeit':
      'Hört einen Podcast oder lest ein Interview mit einer trans Person.',
  'Welt-Backup-Tag': 'Sichert eure Handyfotos, am besten doppelt.',

  // April
  'Aprilscherz-Tag': 'Spielt euch einen harmlosen Streich, zum Beispiel ein Augenpaar auf alle Lebensmittel im Kühlschrank kleben.',
  'Welt-Autismus-Tag':
      'Lest einen Erfahrungsbericht von autistischen Menschen.',
  'Internationaler Kinderbuchtag':
      'Lest euch gegenseitig aus eurem Lieblingsbuch aus der Kindheit vor.',
  'Tag der Aufklärung über die Minengefahr':
      'Organisationen wie Handicap International freuen sich über Spenden.',
  'Tag des Sports für Entwicklung und Frieden':
      'Zusammen Sport machen: joggen, Rad fahren oder Federball im Park.',
  'Tag der Carbonara': 'Echte Carbonara kochen, ohne Sahne!',
  'Weltgesundheitstag': 'Gemeinsam spazieren gehen und die Schritte zählen.',
  'Internationaler Tag der Roma':
      'Hört Musik von Roma-Künstlern, zum Beispiel Django Reinhardt.',
  'Tag der Geschwister':
      'Ruft eure Geschwister an oder schickt ihnen ein altes Kinderfoto.',
  'Welt-Parkinson-Tag': 'Ein Anruf bei den Großeltern freut sie bestimmt.',
  'Tag der bemannten Raumfahrt':
      'Schaut, wann die ISS über euch fliegt, und winkt.',
  'Tag des Käsetoasts': 'Käsetoast-Wettbewerb: Wer macht den besten?',
  'Scrabble-Tag': 'Scrabble-Abend. Ausgedachte Wörter gelten nicht!',
  'Welttag der Kunst': 'Malt euch gegenseitig, ohne aufs Blatt zu schauen.',
  'Welttag der Stimme': 'Karaoke-Abend im Wohnzimmer.',
  'Internationaler Denkmaltag':
      'Besichtigt ein Denkmal oder eine Burg in eurer Gegend.',
  'Welttag der Kreativität und Innovation':
      'Bastelt oder baut zusammen etwas für die Wohnung.',
  'Tag der Erde': 'Müll sammeln beim Spaziergang oder ein paar Kräuter auf dem Balkon pflanzen.',
  'Welttag des Buches':
      'Schenkt euch gegenseitig ein Buch, das ihr selbst geliebt habt.',
  'Tag des Deutschen Bieres':
      'Bier-Tasting mit drei Sorten, die ihr noch nicht kennt.',
  'Welt-Malaria-Tag': 'Vor der nächsten Fernreise an Mückenschutz denken.',
  'Weltpinguintag': 'Pinguinvideos und ein Film wie "Die Reise der Pinguine".',
  'Welttag des geistigen Eigentums': 'Schaut euch zusammen einen Film oder Song an und lest, wer ihn wirklich erfunden hat.',
  'Welttag für Sicherheit und Gesundheit am Arbeitsplatz': 'Prüft eure Haltung am Schreibtisch und stellt den Bildschirm richtig ein.',
  'Welttanztag': 'Tanzt in der Küche zu eurem Lieblingslied.',
  'Internationaler Tag des Jazz': 'Abendessen mit Jazzmusik im Hintergrund.',
  'Walpurgisnacht': 'Tanz in den Mai oder ein Lagerfeuer mit Freunden.',

  // Mai
  'Tag der Arbeit': 'Ausschlafen und eine Maiwanderung mit Picknick.',
  'Welttag des Thunfischs': 'Beim Einkauf auf das MSC-Siegel achten.',
  'Internationaler Tag der Pressefreiheit':
      'Lest heute gemeinsam eine richtige Zeitung.',
  'Star-Wars-Tag': 'Star-Wars-Marathon. "Möge die Macht mit euch sein!"',
  'Internationaler Hebammentag': 'Fragt eure Eltern, wie eure Geburt war.',
  'Protesttag zur Gleichstellung von Menschen mit Behinderung': 'Achtet beim Spaziergang mal darauf, wo es überall Stufen und Hindernisse gibt.',
  'Anti-Diät-Tag': 'Euer Lieblingsessen, ohne Kalorien zu zählen.',
  'Tag der Befreiung': 'Ein Gespräch mit den Großeltern über ihre Erinnerungen an die Kriegszeit.',
  'Weltrotkreuztag': 'Wie lange ist euer Erste-Hilfe-Kurs her? Vielleicht zusammen einen auffrischen.',
  'Europatag': 'Plant euren nächsten Kurztrip in ein europäisches Nachbarland.',
  'Internationaler Tag der Pflege':
      'Bedankt euch bei jemandem, der in der Pflege arbeitet.',
  'Internationaler Tag der Familie':
      'Ruft eure Familien an oder plant ein gemeinsames Treffen.',
  'Internationaler Tag des Lichts': 'Abends Kerzen statt Lampen anmachen.',
  'Tag gegen Homo-, Bi-, Inter- und Transphobie':
      'Hängt eine Regenbogenflagge raus oder tragt etwas Buntes.',
  'Internationaler Museumstag':
      'Ein Museum besuchen, heute oft mit freiem Eintritt.',
  'Weltbienentag': 'Bienenfreundliche Blumen auf den Balkon pflanzen und Honig vom Imker kaufen.',
  'Welttag der kulturellen Vielfalt':
      'Kocht ein Gericht aus einem Land, in dem ihr noch nie wart.',
  'Internationaler Tag des Tees':
      'Tee-Verkostung mit drei Sorten. Wer errät, welcher welcher ist?',
  'Tag der biologischen Vielfalt':
      'Zählt beim Spaziergang, wie viele verschiedene Vögel ihr seht.',
  'Tag des Grundgesetzes': 'Lest zusammen die ersten 19 Artikel, die Grundrechte. Sie sind kürzer als gedacht.',
  'Weltschildkrötentag': 'Heute alles extra langsam und gemütlich machen.',
  'Europäischer Tag der Parks':
      'Einen Nationalpark oder großen Stadtpark besuchen.',
  'Afrikatag':
      'Afrikanisch kochen, zum Beispiel ein äthiopisches Linsengericht.',
  'Handtuchtag':
      'Tragt den ganzen Tag ein Handtuch mit euch herum. Ehrensache.',
  'Tag der Menstruationshygiene': 'Gut zu wissen: Viele Schulen und Organisationen sammeln Hygieneartikel als Spende.',
  'Tag des Burgers':
      'Burger selber bauen, mit allen Belägen, die der Kühlschrank hergibt.',
  'Tag der Friedenssicherungskräfte':
      'Ein kurzer Moment des Danks für alle, die für Frieden im Einsatz sind.',
  'Weltnichtrauchertag': 'Ein Spaziergang an der frischen Luft.',

  // Juni
  'Internationaler Kindertag': 'Macht etwas, das ihr als Kinder geliebt habt: Schaukeln, Eis essen, Seifenblasen.',
  'Weltmilchtag': 'Milchshakes oder Kakao, gern auch mit Hafermilch.',
  'Weltfahrradtag': 'Eine Radtour mit Picknick.',
  'Weltumwelttag': 'Eine Woche Plastik sparen: Wer schafft es besser?',
  'Welttag der Lebensmittelsicherheit': 'Kühlschrank ausmisten und abgelaufene Sachen prüfen. Die Vorräte in der App helfen dabei.',
  'Welttag der Ozeane':
      'Eine Meeresdoku schauen und den nächsten Urlaub am Meer planen.',
  'Tag des besten Freundes': 'Sagt eurem besten Freund, wie froh ihr seid, dass es ihn gibt. Zu zweit am Esstisch geht das gut.',
  'Geburtstag von Donald Duck': 'Ein altes Lustiges Taschenbuch lesen.',
  'Welttag gegen Kinderarbeit': 'Beim nächsten Schokoladen- oder Kaffeekauf auf das Fairtrade-Siegel achten.',
  'Weltblutspendetag':
      'Gemeinsam Blut spenden gehen. Termine findet ihr beim Roten Kreuz.',
  'Welttag gegen Misshandlung älterer Menschen':
      'Ruft ältere Verwandte oder Nachbarn an und fragt, wie es ihnen geht.',
  'Tag des Windes': 'Seifenblasen pusten oder einen Drachen steigen lassen.',
  'Bloomsday': 'Ein Pub-Besuch mit irischem Bier. "Ulysses" muss nicht sein.',
  'Welttag gegen Wüstenbildung und Dürre':
      'Pflanzen auf dem Balkon morgens gießen, dann verdunstet weniger.',
  'Volksaufstand in der DDR':
      'Fragt Eltern oder Großeltern, was sie über die DDR erzählen können.',
  'Internationaler Tag des Picknicks': 'Decke einpacken und Picknick im Park.',
  'Tag gegen sexuelle Gewalt in Konflikten': 'Organisationen wie medica mondiale helfen Betroffenen und freuen sich über Spenden.',
  'Geburtstag von Garfield': 'Lasagne zum Abendessen, wie Garfield es liebt.',
  'Weltflüchtlingstag':
      'Ein Gericht aus Syrien, Afghanistan oder der Ukraine kochen.',
  'Internationaler Tag des Yoga':
      'Zusammen eine Yoga-Session per Video machen.',
  'Fête de la Musique':
      'Durch die Stadt bummeln und bei den Straßenkonzerten stehen bleiben.',
  'Olympischer Tag': 'Euer eigenes Olympia: Weitsprung, Wettlauf, Eierlauf.',
  'Johannistag':
      'Johannisbeeren pflücken oder kaufen und einen Kuchen damit backen.',
  'Tag des Seefahrers': 'Fischbrötchen essen und einen Hafen besuchen, falls einer in der Nähe ist.',
  'Tag gegen Drogenmissbrauch':
      'Ein ehrliches Gespräch darüber, wie viel Alkohol bei euch normal ist.',
  'Tag zur Unterstützung der Folteropfer': 'Amnesty International hat Briefaktionen, bei denen man in wenigen Minuten mitmachen kann.',
  'Siebenschläfertag':
      'Ausschlafen! Und dann schaut, ob die Bauernregel stimmt.',
  'Asteroidentag': 'Nachts Sternschnuppen suchen.',
  'Social-Media-Tag':
      'Postet ein schönes Foto von euch zwei. Oder macht einen Tag Handypause.',

  // Juli
  'Tag des Witzes':
      'Jeder erzählt seinen schlechtesten Witz. Wer zuerst lacht, verliert.',
  'Welt-UFO-Tag':
      'Abends auf den Balkon und nach Sternen und Satelliten Ausschau halten.',
  'Tag ohne Plastiktüte': 'Stoffbeutel ins Auto und an die Haustür legen, damit ihr sie nie vergesst.',
  'Tag des Bikinis': 'Ab ins Freibad oder an den See.',
  'Internationaler Tag des Kusses': 'Ihr wisst, was zu tun ist. 😘',
  'Welt-Schokoladentag': 'Schokoladen-Verkostung: drei Sorten blind probieren.',
  'Weltbevölkerungstag':
      'Schaut euch auf einer Weltkarte an, wo die meisten Menschen leben.',
  'Französischer Nationalfeiertag':
      'Ein französisches Abendessen mit Baguette, Käse und Rotwein.',
  'Welttag der Jugendfähigkeiten':
      'Was wolltet ihr als Kind werden? Erzählt es euch.',
  'Tag der internationalen Strafjustiz':
      'Eine gute Doku über die Nürnberger Prozesse schauen.',
  'Welt-Emoji-Tag': 'Schreibt euch heute nur in Emojis.',
  'Nelson-Mandela-Tag':
      '67 Minuten für etwas Gutes, zum Beispiel für die Nachbarn einkaufen.',
  'Gedenktag 20. Juli 1944': 'Den Film "Operation Walküre" schauen.',
  'Internationaler Tag des Schachs':
      'Eine Partie Schach. Notfalls gegen das Handy.',
  'Welttag des Gehirns':
      'Gehirnjogging: Rätsel, Kreuzworträtsel oder Sudoku zu zweit.',
  'Pi-Annäherungstag': 'Rechnet 22 durch 7 im Kopf aus. Wer kommt weiter?',
  'Tag des Tequilas': 'Tacos und ein Tequila Sunrise.',
  'Welttag zur Verhütung des Ertrinkens':
      'Beim nächsten Badeausflug zusammen schwimmen, nie allein.',
  'Welt-Hepatitis-Tag':
      'Impfpässe raussuchen und prüfen, ob ihr gegen Hepatitis geimpft seid.',
  'Internationaler Tag des Tigers': 'Eine Tier-Doku über Tiger schauen.',
  'Welttag gegen Menschenhandel':
      'Beim Kleiderkauf darauf achten, wo und wie produziert wurde.',
  'Internationaler Tag der Freundschaft': 'Ladet Freunde zum Grillen ein.',
  'Geburtstag von Harry Potter': 'Harry-Potter-Filmabend mit Butterbier.',

  // August
  'Gedenktag für die Sinti und Roma': 'Ein stiller Moment des Gedenkens.',
  'Hiroshima-Gedenktag':
      'Faltet einen Papierkranich, das Symbol für Frieden aus Hiroshima.',
  'Weltkatzentag': 'Katzenvideos sind heute Pflicht.',
  'Internationaler Tag der indigenen Völker':
      'Den Film "Avatar" schauen und darüber reden, woher die Idee kommt.',
  'Nagasaki-Gedenktag': 'Ein Moment des Gedenkens für die Opfer.',
  'Weltlöwentag': '"Der König der Löwen" schauen und mitsingen.',
  'Internationaler Tag der Jugend':
      'Schaut alte Fotos von euch als Teenager an.',
  'Welt-Elefanten-Tag':
      'Ein Gedächtnisspiel: Wer erinnert sich an mehr Details vom ersten Date?',
  'Internationaler Linkshändertag':
      'Versucht, mit der anderen Hand zu schreiben oder Zähne zu putzen.',
  'Mariä Himmelfahrt': 'Einen Kräuterstrauß binden und in die Küche hängen.',
  'Welttag der humanitären Hilfe':
      'Spendet an eine Hilfsorganisation eurer Wahl.',
  'Welttag der Fotografie': 'Macht ein schönes Paarfoto und druckt es aus.',
  'Welt-Moskito-Tag': 'Mückenschutz für Fenster und Balkontür prüfen.',
  'Gedenktag für die Opfer des Terrorismus':
      'Ein stiller Moment für die Opfer.',
  'Gedenktag für Opfer religiöser Gewalt': 'Besucht ein Gotteshaus einer anderen Religion, viele bieten Führungen an.',
  'Gedenktag für die Opfer von Stalinismus und Nationalsozialismus':
      'Eine Gedenkstätte in der Nähe besuchen.',
  'Internationaler Hundetag':
      'Mit einem Hund spazieren gehen, zur Not mit dem vom Nachbarn.',
  'Goethes Geburtstag': 'Lest euch ein Goethe-Gedicht vor, zum Beispiel "Willkommen und Abschied".',
  'Internationaler Tag gegen Atomtests':
      'Eine Doku über das Atomzeitalter schauen.',
  'Tag der Opfer des Verschwindenlassens':
      'Bei Amnesty International mit einem Brief für Verschwundene mitmachen.',
  'Tag der Menschen afrikanischer Abstammung':
      'Hört ein Album von einem afrikanischen oder afrodeutschen Künstler.',
  'Tag des Blogs': 'Sucht euch einen Kochblog und kocht ein Rezept davon nach.',

  // September
  'Antikriegstag': 'Ein Gespräch über Familiengeschichten aus dem Krieg.',
  'Internationaler Tag der Wohltätigkeit': 'Kleidung aussortieren und spenden.',
  'Tag der sauberen Luft': 'Heute mit dem Rad oder zu Fuß statt mit dem Auto.',
  'Weltalphabetisierungstag':
      'Spendet gelesene Bücher an einen öffentlichen Bücherschrank.',
  'Welttag der Suizidprävention': 'Fragt Freunde, wie es ihnen wirklich geht. Und speichert die Nummer der Telefonseelsorge.',
  'Internationaler Tag der Demokratie': 'Schaut nach, wann die nächste Wahl ist, und tragt sie in den Kalender ein.',
  'Tag zum Schutz der Ozonschicht': 'Sonnencreme nicht vergessen!',
  'Welttag der Patientensicherheit':
      'Legt in der App eure Medikamente und Allergien an.',
  'Internationaler Tag der Lohngleichheit':
      'Redet offen über Geld. Wer verdient wie viel und ist das fair verteilt?',
  'Sprich-wie-ein-Pirat-Tag': 'Redet den ganzen Abend wie Piraten. Arrr!',
  'Weltkindertag': 'Ein Kinderfest besuchen oder Zuckerwatte essen.',
  'Internationaler Tag des Friedens':
      'Wenn es Streit gab: Heute ist der Tag zum Vertragen.',
  'Welt-Alzheimertag':
      'Besucht ältere Verwandte und lasst euch alte Geschichten erzählen.',
  'Weltautofreier Tag': 'Heute alles zu Fuß, mit dem Rad oder mit der Bahn.',
  'Hobbit-Tag': 'Zwei Frühstücke, barfuß laufen und einen Film aus Mittelerde.',
  'Internationaler Tag der Gebärdensprachen':
      'Lernt "Ich liebe dich" in Gebärdensprache.',
  'Welttag der Apotheker':
      'Hausapotheke aufräumen und abgelaufene Medikamente entsorgen.',
  'Europäischer Tag der Sprachen':
      'Lernt zusammen fünf Wörter in einer neuen Sprache.',
  'Welttourismustag': 'Plant euren nächsten gemeinsamen Urlaub.',
  'Welttollwuttag':
      'Haustiere zum Impfen? Den Termin in den Kalender eintragen.',
  'Welt-Herz-Tag':
      'Ein Spaziergang zu zweit tut dem Herzen in jeder Hinsicht gut. ❤️',
  'Internationaler Übersetzertag':
      'Einen Film in Originalsprache mit Untertiteln schauen.',

  // Oktober
  'Internationaler Tag der älteren Menschen': 'Ruft Oma und Opa an.',
  'Internationaler Tag des Kaffees':
      'Ins Lieblingscafé gehen oder zu Hause einen Latte-Art-Versuch starten.',
  'Internationaler Tag der Gewaltlosigkeit': 'Einen Film über Gandhi schauen.',
  'Tag der Deutschen Einheit':
      'Ein Ausflug in ein Bundesland, in dem ihr noch nie wart.',
  'Welttierschutztag': 'Futter oder Decken ins Tierheim bringen.',
  'Welttag der Lehrerinnen und Lehrer':
      'Erzählt euch von euren Lieblingslehrern.',
  'Weltposttag': 'Schreibt euch gegenseitig eine Postkarte und schickt sie richtig per Post.',
  'Welttag der psychischen Gesundheit':
      'Fragt euch gegenseitig ehrlich: Wie geht es dir gerade wirklich?',
  'Welttag gegen die Todesstrafe':
      'Bei einer Briefaktion von Amnesty International mitmachen.',
  'Internationaler Mädchentag':
      'Organisationen wie Plan International fördern Bildung für Mädchen.',
  'Coming-out-Tag': 'Erzählt euch, wie euer eigenes Coming-out war.',
  'Internationaler Tag der Katastrophenvorsorge':
      'Prüft euren Notvorrat: Wasser, Taschenlampe, Batterien, Radio.',
  'Weltnormentag': 'Wer findet das ungewöhnlichste DIN-Format in der Wohnung?',
  'Welttag des Händewaschens': 'Singt zweimal "Happy Birthday" beim Händewaschen, so lange sollte es dauern.',
  'Internationaler Tag der Landfrauen':
      'Auf dem Wochenmarkt oder im Hofladen einkaufen.',
  'Welternährungstag': 'Reste-Essen kochen: Was ist noch im Kühlschrank?',
  'Internationaler Tag für die Beseitigung der Armut':
      'Lebensmittel für die Tafel spenden.',
  'Europäischer Tag gegen Menschenhandel':
      'Beim nächsten Einkauf auf faire Siegel achten.',
  'Tag des Mols': 'Backen ist Chemie: Ein Kuchen zählt als Experiment.',
  'Tag der Vereinten Nationen':
      'Schaut nach, wie viele der 193 Mitgliedsstaaten ihr schon besucht habt.',
  'Welttag der Nudel':
      'Selbstgemachte Nudeln. Oder zumindest eine neue Nudelsorte.',
  'Welttag des audiovisuellen Erbes':
      'Schaut alte Familienvideos oder einen Schwarz-Weiß-Film.',
  'Internationaler Tag der Animation':
      'Zeichentrickfilmabend mit einem Pixar- oder Ghibli-Film.',
  'Welt-Schlaganfall-Tag': 'Lernt die BE-FAST-Regel: Gleichgewicht, Augen, Gesicht, Arme, Sprache, Zeit.',
  'Internationaler Tag des Internets':
      'Ein Abend ganz ohne Internet. Schafft ihr das?',
  'Reformationstag': 'Ausschlafen, wo frei ist. Und ein Stück Reformationsbrötchen, falls der Bäcker welche hat.',
  'Weltspartag': 'Schaut in der App nach euren Finanzen und überlegt ein gemeinsames Sparziel.',
  'Halloween': 'Kürbis schnitzen, Süßigkeiten für Kinder bereithalten und einen Gruselfilm schauen.',

  // November
  'Allerheiligen': 'Ein ruhiger Tag. Vielleicht ein Spaziergang über einen schönen alten Friedhof.',
  'Weltvegantag': 'Kocht heute zusammen komplett vegan.',
  'Allerseelen': 'Zündet eine Kerze für die an, die ihr vermisst.',
  'Tag des Sandwichs': 'Sandwich-Battle: Jeder baut eins für den anderen.',
  'Welttag des Tsunami-Bewusstseins': 'Vor dem nächsten Strandurlaub nachlesen, was bei einer Warnung zu tun ist.',
  'Tag der Radiologie': 'Sucht den Röntgenpass raus. Habt ihr überhaupt einen?',
  'Schicksalstag der Deutschen': 'Den Film "Good Bye, Lenin!" schauen.',
  'Welttag der Wissenschaft': 'Ein Science-Center oder Planetarium besuchen.',
  'Martinstag und Karnevalsbeginn':
      'Gänsebraten oder ein Weckmann. Und um 11:11 Uhr: Helau oder Alaaf!',
  'Welttag der Freundlichkeit': 'Lasst heute an der Kasse jemanden vor.',
  'Weltdiabetestag': 'Ein Tag ohne Süßigkeiten. Oder zumindest ein Versuch.',
  'Internationaler Tag der Toleranz': 'Redet darüber, worin ihr zwei total verschieden seid und warum das gut ist.',
  'Internationaler Studententag':
      'Erzählt euch Anekdoten aus Schule oder Studium.',
  'Welt-Frühgeborenen-Tag':
      'Die Stiftung "Das frühgeborene Kind" freut sich über Spenden.',
  'Welttoilettentag':
      'Klopapiervorrat prüfen und gleich auf die Einkaufsliste setzen.',
  'Internationaler Männertag':
      'Macht einen Vorsorgetermin beim Arzt aus. Gilt für euch beide!',
  'Tag der Kinderrechte': 'UNICEF freut sich über Spenden.',
  'Welttag des Fernsehens': 'Serienabend mit eurer Lieblingsserie.',
  'Welttag des Grüßens': 'Grüßt heute jeden Nachbarn im Treppenhaus.',
  'Fibonacci-Tag': 'Sucht Spiralen in der Natur: Tannenzapfen, Sonnenblumen, Schneckenhäuser.',
  'Tag gegen Gewalt an Frauen':
      'Teilt die Nummer des Hilfetelefons 116 016. Sie kann jemandem helfen.',
  'Tag der Computersicherheit':
      'Updates installieren und Zwei-Faktor-Anmeldung einrichten.',

  // Dezember
  'Welt-AIDS-Tag': 'Tragt eine rote Schleife als Zeichen der Solidarität.',
  'Internationaler Tag für die Abschaffung der Sklaverei':
      'Beim Weihnachtseinkauf auf faire Produkte achten.',
  'Internationaler Tag der Menschen mit Behinderungen': 'Lest über Inklusion in eurer Stadt oder unterstützt einen inklusiven Laden.',
  'Barbaratag': 'Kirschzweige schneiden und in eine Vase stellen. Blühen sie an Weihnachten?',
  'Internationaler Tag des Ehrenamts':
      'Überlegt, ob es ein Ehrenamt gibt, das euch Spaß machen würde.',
  'Weltbodentag': 'Blumenerde für den Frühling besorgen oder einen Komposteimer anschaffen.',
  'Nikolaustag':
      'Füllt euch gegenseitig die Stiefel mit Schokolade und Nüssen.',
  'Tag der internationalen Zivilluftfahrt':
      'Träumt vom nächsten Flug: Wohin soll die Reise gehen?',
  'Internationaler Antikorruptionstag':
      'Ein Film über einen echten Skandal, zum Beispiel "Spotlight".',
  'Tag der Menschenrechte':
      'Beim Amnesty-Briefmarathon mitmachen, er läuft genau um diese Zeit.',
  'Internationaler Tag der Berge': 'Plant eine Bergwanderung für den Sommer.',
  'Tag der universellen Gesundheitsversorgung':
      'Prüft, ob eure Krankenkasse Vorsorge-Boni zahlt.',
  'Luciatag': 'Safranbrötchen backen und Kerzen anzünden.',
  'Tag des Affen': 'Macht euch zum Affen: Grimassen-Wettbewerb!',
  'Internationaler Tag der Migranten': 'Fragt in der Familie nach, wer einmal ausgewandert oder eingewandert ist.',
  'Internationaler Tag der menschlichen Solidarität':
      'Weihnachtspäckchen für Bedürftige packen.',
  'Tag des Kreuzworträtsels': 'Löst zusammen ein Kreuzworträtsel.',
  'Heiligabend': 'Geschenke, gutes Essen und ganz viel Zeit füreinander.',
  'Weihnachten': 'Ein Weihnachtsspaziergang nach dem Festessen.',
  'Zweiter Weihnachtsfeiertag':
      'Reste essen, Pyjama anlassen und Weihnachtsfilme schauen.',
  'Internationaler Tag der Epidemievorsorge':
      'Hausapotheke für den Winter auffüllen.',
  'Silvester': 'Bleigießen, "Dinner for One" und um Mitternacht ein Kuss.',

  // Bewegliche Tage
  'Tag der seltenen Erkrankungen': 'Die Allianz Chronischer Seltener Erkrankungen (ACHSE) freut sich über Spenden.',
  'Weltlachtag': 'Schaut eure lustigsten Videos oder Fotos von euch an, bis ihr euch nicht mehr halten könnt.',
  'Muttertag': 'Ruft eure Mütter an oder schickt Blumen.',
  'Christi Himmelfahrt und Vatertag':
      'Ausflug mit Bollerwagen oder Radtour, und eure Väter anrufen.',
  'Tag der Organspende': 'Füllt einen Organspendeausweis aus oder tragt euch online ins Organspende-Register ein.',
  'Tag des Programmierers':
      'Schreibt der App einen Wunsch: Welche Funktion fehlt euch noch?',
  'Tag des Deutschen Butterbrotes':
      'Abendbrot wie früher: gutes Brot, Butter und frischer Schnittlauch.',
  'Erntedankfest': 'Einen Kürbis kaufen und eine Suppe daraus kochen.',
  'Volkstrauertag': 'Ein stiller Moment für die Opfer von Krieg und Gewalt.',
  'Buß- und Bettag': 'Gibt es etwas, das ihr euch noch verzeihen wollt? Heute ist ein guter Tag dafür.',
  'Black Friday': 'Nur kaufen, was schon vorher auf der Wunschliste stand. Oder gar nichts.',
  'Totensonntag':
      'Denkt gemeinsam an Verstorbene und erzählt euch schöne Erinnerungen.',
  'Erster Advent':
      'Adventskranz aufstellen, erste Kerze anzünden und Plätzchen backen.',
};

/// Wikipedia-Titel, wo der Artikel anders heißt als der Tag.
const aktionstagWiki = <String, String>{
  'Tag der Bloody Mary': 'Bloody Mary (Cocktail)',
  'Tag der Science-Fiction': 'Science-Fiction',
  'Tag des Strohhalms': 'Trinkhalm',
  'Tag der Spaghetti': 'Spaghetti',
  'Tag der Schlagsahne': 'Schlagsahne',
  'Tag der Bohne': 'Gregor Mendel',
  'Orthodoxes Weihnachten': 'Weihnachten',
  'Tag der Erdrotation': 'Foucaultsches Pendel',
  'Tag des Schaumbads': 'Schaumbad',
  'Tag der statischen Aufladung': 'Elektrostatik',
  'Tag der Zimmerpflanzen': 'Zimmerpflanze',
  'Tag des Dankeschöns': 'Dankbarkeit',
  'Tag des Marzipans': 'Marzipan',
  'Wikipedia-Tag': 'Wikipedia',
  'Tag des Hutes': 'Hut',
  'Tag der Kinder-Erfinder': 'Benjamin Franklin',
  'Tag von Winnie Puuh': 'Pu der Bär',
  'Tag des Popcorns': 'Popcorn',
  'Tag des Pinguins': 'Pinguine',
  'Weltknuddeltag': 'Umarmung',
  'Tag der Jogginghose': 'Jogginghose',
  'Deutsch-Französischer Tag': 'Élysée-Vertrag',
  'Tag der Handschrift': 'Handschrift',
  'Tag des Kompliments': 'Kompliment',
  'Internationaler Tag des Zolls': 'Weltzollorganisation',
  'Tag des LEGO-Steins': 'Lego',
  'Tag des Puzzles': 'Puzzle',
  'Welttag der vernachlässigten Tropenkrankheiten':
      'Vernachlässigte Tropenkrankheiten',
  'Tag des Croissants': 'Croissant',
  'Tag des Passwortwechsels': 'Passwort',
  'Welttag der Feuchtgebiete': 'Ramsar-Konvention',
  'Tag des Karottenkuchens': 'Rüblitorte',
  'Welt-Nutella-Tag': 'Nutella',
  'Tag des Drachensteigens': 'Drachen (Fluggerät)',
  'Tag der Pizza': 'Pizza',
  'Welttag der Hülsenfrüchte': 'Hülsenfrucht',
  'Tag des Regenschirms': 'Regenschirm',
  'Europäischer Tag des Notrufs 112': 'Notruf 112',
  'Darwin-Tag': 'Charles Darwin',
  'Tag der zufälligen Freundlichkeit': 'Freundlichkeit',
  'Tag der Batterie': 'Alessandro Volta',
  'Tag der Liebe zu Haustieren': 'Haustier',
  'Weltdenktag der Pfadfinder': 'Thinking Day',
  'Tag der Margarita': 'Margarita (Cocktail)',
  'Tag des Hundekekses': 'Hundefutter',
  'Tag der Tortilla-Chips': 'Tortilla-Chips',
  'Tag des Märchenerzählens': 'Märchen',
  'Internationaler Eisbärentag': 'Eisbär',
  'Welttag des Kompliments': 'Kompliment',
  'Welttag des Artenschutzes': 'Washingtoner Artenschutzübereinkommen',
  'Tag der Grammatik': 'Grammatik',
  'Tag der Barbie': 'Barbie',
  'Mario-Tag': 'Mario (Computerspielfigur)',
  'Welttag gegen Internetzensur': 'Internetzensur',
  'Weltverbrauchertag': 'Weltverbrauchertag',
  'St. Patrick\'s Day': 'St. Patrick’s Day',
  'Internationaler Tag der Frankophonie': 'Frankophonie',
  'Internationaler Tag gegen Rassismus': 'Internationaler Tag gegen Rassismus',
  'Tag des Welpen': 'Welpe',
  'Gedenktag für die Opfer der Sklaverei': 'Atlantischer Sklavenhandel',
  'Tolkien-Lesetag': 'J. R. R. Tolkien',
  'Tag der Transgender-Sichtbarkeit': 'Transgender Day of Visibility',
  'Welt-Backup-Tag': 'Datensicherung',
  'Aprilscherz-Tag': 'Aprilscherz',
  'Tag der Carbonara': 'Spaghetti alla carbonara',
  'Tag der Geschwister': 'Geschwister',
  'Tag der bemannten Raumfahrt': 'Juri Alexejewitsch Gagarin',
  'Tag des Käsetoasts': 'Toast',
  'Scrabble-Tag': 'Scrabble',
  'Welttag der Kunst': 'Leonardo da Vinci',
  'Tag der Erde': 'Tag der Erde',
  'Weltpinguintag': 'Pinguine',
  'Welttanztag': 'Welttanztag',
  'Star-Wars-Tag': 'Star Wars',
  'Internationaler Hebammentag': 'Hebamme',
  'Anti-Diät-Tag': 'Diät',
  'Tag der Befreiung': 'Tag der Befreiung',
  'Europatag': 'Europatag',
  'Internationaler Tag der Pflege': 'Florence Nightingale',
  'Internationaler Tag des Lichts': 'Laser',
  'Internationaler Tag des Tees': 'Tee',
  'Tag des Grundgesetzes': 'Grundgesetz für die Bundesrepublik Deutschland',
  'Weltschildkrötentag': 'Schildkröten',
  'Handtuchtag': 'Towel Day',
  'Tag des Burgers': 'Hamburger',
  'Tag der Menstruationshygiene': 'Menstruationshygiene',
  'Tag des besten Freundes': 'Freundschaft',
  'Geburtstag von Donald Duck': 'Donald Duck',
  'Tag des Windes': 'Windenergie',
  'Volksaufstand in der DDR': 'Aufstand vom 17. Juni 1953',
  'Internationaler Tag des Picknicks': 'Picknick',
  'Geburtstag von Garfield': 'Garfield',
  'Internationaler Tag des Yoga': 'Yoga',
  'Johannistag': 'Johannistag',
  'Tag des Seefahrers': 'Seemann',
  'Asteroidentag': 'Asteroid Day',
  'Social-Media-Tag': 'Soziale Medien',
  'Tag des Witzes': 'Witz',
  'Welt-UFO-Tag': 'Unidentifiziertes Flugobjekt',
  'Tag ohne Plastiktüte': 'Plastiktüte',
  'Tag des Bikinis': 'Bikini',
  'Internationaler Tag des Kusses': 'Kuss',
  'Welt-Schokoladentag': 'Schokolade',
  'Französischer Nationalfeiertag': 'Sturm auf die Bastille',
  'Tag der internationalen Strafjustiz': 'Internationaler Strafgerichtshof',
  'Welt-Emoji-Tag': 'Emoji',
  'Nelson-Mandela-Tag': 'Nelson Mandela',
  'Gedenktag 20. Juli 1944': 'Attentat vom 20. Juli 1944',
  'Internationaler Tag des Schachs': 'Schach',
  'Pi-Annäherungstag': 'Kreiszahl',
  'Tag des Tequilas': 'Tequila',
  'Internationaler Tag des Tigers': 'Tiger',
  'Internationaler Tag der Freundschaft': 'Freundschaft',
  'Geburtstag von Harry Potter': 'Harry Potter',
  'Gedenktag für die Sinti und Roma': 'Porajmos',
  'Hiroshima-Gedenktag': 'Atombombenabwürfe auf Hiroshima und Nagasaki',
  'Nagasaki-Gedenktag': 'Atombombenabwürfe auf Hiroshima und Nagasaki',
  'Weltkatzentag': 'Hauskatze',
  'Weltlöwentag': 'Löwe',
  'Welt-Elefanten-Tag': 'Elefanten',
  'Internationaler Linkshändertag': 'Linkshändigkeit',
  'Welttag der Fotografie': 'Daguerreotypie',
  'Welt-Moskito-Tag': 'Stechmücken',
  'Internationaler Hundetag': 'Haushund',
  'Goethes Geburtstag': 'Johann Wolfgang von Goethe',
  'Tag des Blogs': 'Blog',
  'Antikriegstag': 'Antikriegstag',
  'Welttag der Suizidprävention': 'Welttag der Suizidprävention',
  'Tag zum Schutz der Ozonschicht': 'Montreal-Protokoll',
  'Sprich-wie-ein-Pirat-Tag': 'Talk Like a Pirate Day',
  'Hobbit-Tag': 'Der Hobbit',
  'Internationaler Tag der Gebärdensprachen': 'Gebärdensprache',
  'Europäischer Tag der Sprachen': 'Europäischer Tag der Sprachen',
  'Internationaler Übersetzertag': 'Hieronymus (Kirchenvater)',
  'Internationaler Tag des Kaffees': 'Kaffee',
  'Internationaler Tag der Gewaltlosigkeit': 'Mahatma Gandhi',
  'Coming-out-Tag': 'Coming-out',
  'Weltnormentag': 'Norm (Technik)',
  'Welternährungstag': 'Welternährungstag',
  'Tag des Mols': 'Avogadro-Konstante',
  'Tag der Vereinten Nationen': 'Vereinte Nationen',
  'Welttag der Nudel': 'Teigwaren',
  'Internationaler Tag der Animation': 'Animation',
  'Welt-Schlaganfall-Tag': 'Schlaganfall',
  'Internationaler Tag des Internets': 'Arpanet',
  'Tag des Sandwichs': 'Sandwich',
  'Tag der Radiologie': 'Röntgenstrahlung',
  'Schicksalstag der Deutschen': 'Schicksalstag',
  'Martinstag und Karnevalsbeginn': 'Martinstag',
  'Welttag der Freundlichkeit': 'Freundlichkeit',
  'Welttoilettentag': 'Welttoilettentag',
  'Welttag des Grüßens': 'Gruß',
  'Fibonacci-Tag': 'Fibonacci-Folge',
  'Tag gegen Gewalt an Frauen':
      'Internationaler Tag zur Beseitigung von Gewalt gegen Frauen',
  'Tag der Computersicherheit': 'Informationssicherheit',
  'Barbaratag': 'Barbarazweig',
  'Tag der Menschenrechte': 'Allgemeine Erklärung der Menschenrechte',
  'Luciatag': 'Luciafest',
  'Tag des Affen': 'Affen',
  'Tag des Kreuzworträtsels': 'Kreuzworträtsel',
  'Zweiter Weihnachtsfeiertag': 'Stephanstag',
  'Tag der seltenen Erkrankungen': 'Seltene Krankheit',
  'Weltlachtag': 'Lachyoga',
  'Christi Himmelfahrt und Vatertag': 'Vatertag',
  'Tag des Deutschen Butterbrotes': 'Butterbrot',
  'Erster Advent': 'Advent',
};
