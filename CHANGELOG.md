# Changelog

## 1.0.1 – Patch nach dem ersten Test im Spiel (`main`)
- **Emergency Pack:** Einsätze kommen ohne Ja/Nein-Popup und laufen wirklich an (Kartenpunkt, Feuer/Unfall vor Ort). Vorher kam unser automatisches „Ja“ zu früh beim Dialog an und der Einsatz blieb „wartend“ – jetzt wird der Rückruf des Packs direkt mit „Ja“ aufgerufen
- **Emergency Pack:** bis zu 15 Anfragen im Abstand von 4 s (das Pack würfelt jedes Mal), erst danach eigener Alarm
- **Emergency Pack:** Hinweise während des Einsatzes (nächster Schritt, Aufräumen, Abschluss) werden angezeigt statt weggeklickt und landen im Einsatztagebuch; der Einsatz endet von selbst, wenn alles erledigt ist (Knopf heißt bei EP-Einsätzen „Einsatz abbrechen“)
- **Emergency Pack:** Einsatzort und Kartenpunkt werden nach dem „Ja“ nachgeführt; Umlaute erkannt („Ölspur“ → TH ÖL statt TH1 „Einsatz“)
- **Tablet:** Text scheint nicht mehr durch das „KOMMT MIT 1.1“-Banner (Text wird gesammelt und zuletzt gezeichnet, gesperrte Bereiche dunkeln ihn ab)
- **Discord:** discord.gg/WKdQmKaVFG im INFO-Reiter (mit Knopf „Öffnen“), in Beschreibung, Nutzungsregeln und Lizenz
- **ModHub:** Discord-Link und Lizenzzeilen aus der Mod-Beschreibung entfernt (ModHub-Richtlinien), „Mod für Farming Simulator 25.“ ergänzt
- **Sprache:** LS25 setzt `g_languageShortName` nicht – erkannt wird die Spielsprache jetzt über unseren eigenen Tastentext aus der modDesc (Fallback: Engine-Sprachcode). Steht im Log als „Sprache: de (l10n)“
- **Englisch:** Melder, Tablet, Stichworte, Einsatztagebuch, Meldungen und INFO-Reiter auf Englisch, wenn das Spiel nicht auf Deutsch steht (`Sprache.lua`, `docs/SPIELER-INFO.en.md`). Reiter-Beschriftungen nicht mehr in der Textur. Englische Pack-Texte werden für die Stichworte erkannt
- **GIANTS TestRunner:** kein `pcall` mehr (alle ~90 Stellen durch Prüfungen ersetzt – Fehler landen jetzt sichtbar im Log), `descVersion` 115, Changelog in der Beschreibung, Mod-Icon DXT1 ohne Mipmaps. `tools/check_release.py` prüft das jetzt mit
- **Melder/Tablet:** statt „AUSRÜCKEN 3:47“ jetzt „KI-HLF RÜCKT AUS 3:47“, danach „KI-HLF AUF ANFAHRT“ / „KI-HLF VOR ORT“ (Fahrzeug aus der AAO, bevorzugt HLF)
- **Tablet:** „KOMMT MIT 1.1“-Banner breiter (Text lief rechts raus); Fuhrpark-Text: „KI-Kameraden besetzen deine Fahrzeuge“ statt „statt der Nachbarwehr“
- **Tablet:** Schrift mindestens 13 px, hellere Grautöne, Hinweise „AB 1.1“ überdecken keine Beschriftungen mehr, fehlendes Zeichen „−“ ersetzt

## 1.0.0 – Grundversion (erste Veröffentlichung)
- Freigegeben: Melder, Einsätze (Emergency Pack bzw. eigene), Tablet mit **Lage, Wache, Karte, Info**
- **Ausgegraut („BALD“):** Reiter Fuhrpark und AAO. Alle Alarme fährt die Nachbarwehr (KI-Zug nur über Status) oder du selbst
- **Lagekarte (Reiter KARTE):** Live-Karte des Einsatzes – Kartenbild der Map als Hintergrund (Ausschnitt um die Einsatzstelle), sonst Raster mit Straßen aus AutoDrive; Einsatzstelle mit Vor-Ort-Radius, Wache (am Rand mit Entfernung), du, Zoom, Lagedaten. Aufstellung der Fahrzeuge kommt mit 1.1
- Sperren über `FFE.FEATURES` (`fuhrpark`, `ausruecken`, `aufstellung`): in `dev`/`mp` an, in `beta`/`stable` aus
- AutoDrive wird in 1.0 nicht als empfohlen gemeldet (wird erst mit 1.1 gebraucht)
- **Vorgeschmack statt ausblenden:** Alles, was erst mit 1.1 geht, ist sichtbar, aber ausgegraut und nicht bedienbar (Badge „AB 1.1“): Nachalarmieren, Freisetzen, Schalter Nachbarwehr und Ausrücken, AutoDrive bei den empfohlenen Mods, Fuhrpark-Zahlen
- Reiter **Fuhrpark und AAO** zeigen ihren echten Inhalt ausgegraut mit Banner „KOMMT MIT 1.1“
- **INFO:** Discord-Kasten („Komm auf unseren Discord!“); Link über `FFE.DISCORD`, mit Knopf „Öffnen“ – leer = „Link folgt“
- Texturen DXT5 mit Mipmaps (`tools/textures.py`), Icon 512 × 512; Release-Prüfung verlangt das für beta/stable
- Versionen neu: 1.0 Grundversion, 1.1 großes Update, 1.2 Multiplayer

## 1.1.0 – in Entwicklung (dev, früher 0.5.0)
- **Echtes Ausrücken:** Fahrzeuge der Wache stehen immer da, wo sie laut Status sein müssten (Sichtblase – versetzt wird nur außer Sicht)
- **Mit AutoDrive** fahren sie wirklich zur Einsatzstelle (nächstes AutoDrive-Ziel) und zurück, wenn ein Spieler in der Nähe ist
- Abstellplätze an der Einsatzstelle auf dem AutoDrive-Netz (sonst im Kreis), Blaulicht an/aus
- Spieler fährt ein Fahrzeug der Wache → rückt mit aus, Status 4 bei Ankunft
- Fahrzeit wird ab der **echten Position** des Fahrzeugs berechnet (steht nicht immer an der Wache)
- Nach dem Einsatz: KI parkt auf dem **Stellplatz**, ohne Stellplatz auf einem festen Platz **neben der Wache**
- **Freibuggen:** KI-Fahrzeuge kommen immer an. Festgefahren (25 s kaum Bewegung), AutoDrive abgebrochen, umgekippt, unter der Map oder viel zu lange unterwegs → erst AutoDrive neu starten, dann direkt ans Ziel versetzen (Anfahrt und Rückweg)
- Wartest du an der Einsatzstelle oder an der Wache, wird ein Fahrzeug spätestens 90 s nach Soll-Ankunft trotzdem geholt (nicht direkt vor deiner Nase)
- Tablet: Knopf „Festgefahren? Alle zur Einsatzstelle“ bzw. „Alle heimholen“; Dev-Befehl `ffFrei`
- Tablet/Lage: Nachalarmieren pro Klasse, Einsatztagebuch
- Einstellung „Fahrzeuge rücken wirklich aus“ (Reiter Wache, wird gespeichert)
- **Reiter INFO im Tablet:** Neuigkeiten der letzten Versionen und was noch kommt; nach einem Update Hinweis am Bildschirmrand und „NEU“ am Reiter
- Spieler-Texte stehen in `docs/SPIELER-INFO.md`, daraus erzeugt `tools/gen_info.py` die `Info.lua` (Release-Prüfung achtet darauf)
- Neues Mod-Icon
- Roadmap: echtes Ausrücken vor Multiplayer (Multiplayer jetzt 0.6), Updates 1.1–1.5 nach der Veröffentlichung
- Rückfahrt ist jetzt **Status 1** (frei über Funk) statt 8 – in BaWü gibt es für die Feuerwehr keinen Status 8

## 0.4.0 – in Entwicklung (dev)
- **EL-Tablet im Spiel (Alt+T)**, komplett mit der Maus bedienbar – kein Konsolenbefehl mehr nötig:
  - **Lage:** laufender Einsatz mit Einheiten, Status und Zeiten, Alarm quittieren, Einsatz beenden, Probealarm, Rückfahrten
  - **Fuhrpark:** neu gekaufte Fahrzeuge (Feuerwehrautos mit Vorschlag), Bezeichnung per Klick, Nummer, Funkrufname (Tastatur), Stellplatz; Fahrzeuge der Wache bearbeiten oder entfernen
  - **AAO:** Tabelle Stichwort × Klasse, Linksklick +1, Rechtsklick −1, Nachbarwehr pro Stichwort, Standard wiederherstellen
  - **Wache:** Name der Wehr, Standort, Ausrückzeit, Nachbarwehr, eigene Einsätze, KI-Vergütung, Status der empfohlenen Mods
- Während das Tablet offen ist, bewegen sich Spieler und Kamera nicht; ESC schließt
- Tablet-Rahmen als Textur (`textures/tablet_rahmen.dds`), Melder wird ausgeblendet, solange das Tablet offen ist
- Einstellungen „eigene Einsätze“ und „KI-Vergütung“ werden gespeichert
- Konsolenbefehle bleiben nur als Entwickler-Werkzeug
- `tests/preview.py`: rendert ohne Spiel, was Melder und Tablet zeichnen

## 0.3.1 – Beta
- Fahrzeuge haben jetzt **Bezeichnung** (z. B. HLF 20, TLF 3000, DLK 23-12) und **Klasse** (HLF, TLF, DLK …); die AAO arbeitet mit Klassen
- Wache startet leer; `ffNeu` zeigt gekaufte Fahrzeuge, die noch nicht zur Wache gehören, mit Vorschlag für bekannte Feuerwehrautos
- `ffHinzu <Nr> [Bezeichnung] [FzgNr] [Funkrufname]` fügt ein Fahrzeug aus der Liste hinzu, ohne einzusteigen
- `ffFahrzeug` nimmt jetzt die Bezeichnung (`ffFahrzeug HLF_20 1 Florian …`)
- Neue Klassen: KDOW, TSF, GW-L, WLF
- Nachbarwehr pro Stichwort abschaltbar (`ffNachbarwehr aus TH_VU`)
- `ffFuhrpark` zeigt, welche Klassen für die AAO fehlen
- Empfohlene Mods (Emergency Pack, AutoDrive) werden beim Start geprüft; fehlt einer, kommt einmal eine Meldung im Spiel, der Mod läuft trotzdem (`ffStatus` zeigt den Stand)
- Branches main/beta/dev, Kanal (`FFE.CHANNEL`) und `tools/set_version.py`; Release-Prüfung kennt Beta- und Stable-Tags

## 0.3.0 – noch nicht im Spiel getestet
- Umbenannt in **FS25_FFEinsatzleitung** (vorher FS25_FeuerwehrMelder), Script in sechs Dateien aufgeteilt
- Neues Melder-Design: Gehäuse als Textur, Display mit Hintergrundlicht, LED (rot blinkend / gelb / grün)
- Fuhrpark: `ffFahrzeug`, `ffFahrzeugWeg`, `ffFuhrpark`, `ffStellplatz`
- Wache (`ffWache`), Name der Wehr (`ffName`), Ausrückzeit (`ffAusrueckzeit`), Nachbarwehr (`ffNachbarwehr`)
- AAO mit Standardwerten, änderbar per `ffAAO`, Liste per `ffAAOListe`
- Fahrzeugstatus 3 / 4 / 8 / 2 (noch ohne echte Fahrzeugbewegung)
- KI-Löschzug: ohne dich wird der Einsatz nach Stichwort-Dauer abgeschlossen, halbe Vergütung
- Eigene Einsätze, bei denen du vor Ort warst, werden voll vergütet
- Abschlussmeldung des Emergency Packs wird abgefangen
- Speichern/Laden in `ffEinsatzleitung.xml` im Spielstand
- Neue Stichworte TH TIER, BMA; Konsolenbefehle heißen jetzt `ff…` statt `fwm…`
- Rauchtest (`tests/`)
- Autoren: Orniwat & iowi, Copyright-Hinweis in modDesc und allen Scripts, Lizenz
- Release-Prüfung (`tools/check_release.py`) und automatischer Build auf GitHub

## 0.2.3
- Ja/Nein-Abfrage des Emergency Packs wird automatisch bestätigt
- Navigationsziel auf den Kartenpunkt des Packs
- Abbrechen ohne Endlosschleife, Ersatzalarm, wenn das Pack nichts liefert

## 0.2.0
- Kopplung an das Emergency Pack, Stichwort aus der Einsatzbeschreibung

## 0.1.0
- Melder-HUD, drei Alarmtöne, Stichworte, Quittieren, Wegpunkt
