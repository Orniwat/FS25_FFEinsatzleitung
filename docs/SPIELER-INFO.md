# Spieler-Info

Diese Datei ist die Quelle für den Reiter **INFO** im Tablet (Alt+T) und für die ModHub-Beschreibung.
Hier steht alles **so, wie es ein Spieler lesen soll** – kurz, ohne Technik.
Nach jeder Änderung: `python tools/gen_info.py` (macht daraus `scripts/Info.lua`; die Release-Prüfung meckert, wenn das vergessen wurde).

Regeln: `## Nutzung` = Hinweise zur Nutzung, stehen immer unten im INFO-Reiter.
`## Neu in X.Y.Z` = eine Version (neueste oben, die oberste muss zur aktuellen Version passen).
`## Geplant` = was noch kommt, je Zeile `- **Version · Titel:** Beschreibung`. Zeilen möglichst unter 90 Zeichen.

## Nutzung
- Spielen allein oder im Multiplayer mit Freunden: ausdrücklich erlaubt.
- Community-Server (öffentlich, RP, mit Bewerbung): bitte vorher Kontakt aufnehmen – Discord: discord.gg/WKdQmKaVFG
- Hochladen auf anderen Seiten oder veränderte Fassungen: nur mit Erlaubnis von Orniwat & iowi.

## Neu in 1.0.1
- Einsätze aus dem Emergency Pack kommen jetzt direkt auf den Melder – ohne Ja/Nein-Abfrage.
- Hinweise des Packs während des Einsatzes bleiben sichtbar und stehen im Einsatztagebuch.
- Ein Einsatz aus dem Pack endet von selbst, wenn alles erledigt und aufgeräumt ist.
- Tablet besser lesbar: größere Schrift, ausgegraute Bereiche überdecken nichts mehr.
- Melder: Nach der Ausrückzeit rückt ein KI-HLF aus und fährt mit an – du kannst jederzeit dazustoßen.
- Melder und Tablet gibt es jetzt auf Deutsch und Englisch (richtet sich nach der Spielsprache).

## Neu in 1.0.0
- Erste Version! Melder im Stil eines echten digitalen Meldeempfängers, mit Alarmton und Quittieren.
- Einsätze: echte Einsätze aus dem Emergency Pack – ohne Pack erzeugt der Melder eigene Alarme.
- EL-Tablet mit Alt+T, alles mit der Maus: Lage, Wache, Lagekarte und Info.
- Lagekarte: Live-Karte des Einsatzes mit Einsatzstelle, Wache und deiner Position.
- Du fährst selbst hin. Bist du nach der Ausrückzeit nicht unterwegs, übernimmt die Nachbarwehr (KI).
- Fahrzeugstatus 3 / 4 / 1 / 2 wie in Baden-Württemberg, Nachalarmieren und Einsatztagebuch.
- Grau im Tablet = kommt bald: Fuhrpark und AAO folgen mit Version 1.1.
- Alles wird mit dem Spielstand gespeichert.

## Geplant
- **1.1 · Großes Update:** Eigener Fuhrpark, AAO, KI-Kameraden fahren deinen Löschzug (AutoDrive).
- **1.2 · Multiplayer:** Gemeinsam auf dem Server – der Host ist Wachleiter und vergibt Rollen.
- **1.3 · Wehr und Finanzen:** Gemeindebudget, Kostenersatz, Fahrzeuge wieder einsatzbereit machen.
- **1.4 · Alarmierung:** Stichworte nach BW-Katalog, Sirene im Ort, Tagesalarmsicherheit, Schleifen.
- **1.5 · Einsatzablauf:** Einsatzphasen, Wasserversorgung, Atemschutzüberwachung.
- **1.6 · Neue Lagen:** Mähdrescher- und Heustockbrand, Tier in der Güllegrube, Rettungsdienst, Unwetter.
- **1.7 · Mehrere Wehren:** Nachbarwehren mit echten Anfahrtszeiten, Kreisbrandmeister, Alarmausfahrt.
