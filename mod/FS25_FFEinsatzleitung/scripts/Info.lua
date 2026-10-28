-- =============================================================================
-- FF Einsatzleitung  -  Neuigkeiten und Roadmap fuer den Reiter INFO
-- ERZEUGT aus docs/SPIELER-INFO.md / SPIELER-INFO.en.md mit tools/gen_info.py - nicht von Hand aendern!
--
-- Copyright (c) 2026 Orniwat & iowi. Alle Rechte vorbehalten.
-- Weitergabe, Veraenderung oder erneutes Hochladen nur mit Erlaubnis der Autoren.
-- =============================================================================

FFE.INFO = {
    neu = {
        { version = "1.0.1", items = {
            "Einsätze aus dem Emergency Pack kommen jetzt direkt auf den Melder – ohne Ja/Nein-Abfrage.",
            "Hinweise des Packs während des Einsatzes bleiben sichtbar und stehen im Einsatztagebuch.",
            "Ein Einsatz aus dem Pack endet von selbst, wenn alles erledigt und aufgeräumt ist.",
            "Tablet besser lesbar: größere Schrift, ausgegraute Bereiche überdecken nichts mehr.",
            "Melder: Nach der Ausrückzeit rückt ein KI-HLF aus und fährt mit an – du kannst jederzeit dazustoßen.",
            "Melder und Tablet gibt es jetzt auf Deutsch und Englisch (richtet sich nach der Spielsprache).",
        } },
        { version = "1.0.0", items = {
            "Erste Version! Melder im Stil eines echten digitalen Meldeempfängers, mit Alarmton und Quittieren.",
            "Einsätze: echte Einsätze aus dem Emergency Pack – ohne Pack erzeugt der Melder eigene Alarme.",
            "EL-Tablet mit Alt+T, alles mit der Maus: Lage, Wache, Lagekarte und Info.",
            "Lagekarte: Live-Karte des Einsatzes mit Einsatzstelle, Wache und deiner Position.",
            "Du fährst selbst hin. Bist du nach der Ausrückzeit nicht unterwegs, übernimmt die Nachbarwehr (KI).",
            "Fahrzeugstatus 3 / 4 / 1 / 2 wie in Baden-Württemberg, Nachalarmieren und Einsatztagebuch.",
            "Grau im Tablet = kommt bald: Fuhrpark und AAO folgen mit Version 1.1.",
            "Alles wird mit dem Spielstand gespeichert.",
        } },
    },
    geplant = {
        { version = "1.1", titel = "Großes Update", text = "Eigener Fuhrpark, AAO, KI-Kameraden fahren deinen Löschzug (AutoDrive)." },
        { version = "1.2", titel = "Multiplayer", text = "Gemeinsam auf dem Server – der Host ist Wachleiter und vergibt Rollen." },
        { version = "1.3", titel = "Wehr und Finanzen", text = "Gemeindebudget, Kostenersatz, Fahrzeuge wieder einsatzbereit machen." },
        { version = "1.4", titel = "Alarmierung", text = "Stichworte nach BW-Katalog, Sirene im Ort, Tagesalarmsicherheit, Schleifen." },
        { version = "1.5", titel = "Einsatzablauf", text = "Einsatzphasen, Wasserversorgung, Atemschutzüberwachung." },
        { version = "1.6", titel = "Neue Lagen", text = "Mähdrescher- und Heustockbrand, Tier in der Güllegrube, Rettungsdienst, Unwetter." },
        { version = "1.7", titel = "Mehrere Wehren", text = "Nachbarwehren mit echten Anfahrtszeiten, Kreisbrandmeister, Alarmausfahrt." },
    },
    nutzung = {
        "Spielen allein oder im Multiplayer mit Freunden: ausdrücklich erlaubt.",
        "Community-Server (öffentlich, RP, mit Bewerbung): bitte vorher Kontakt aufnehmen – Discord: discord.gg/WKdQmKaVFG",
        "Hochladen auf anderen Seiten oder veränderte Fassungen: nur mit Erlaubnis von Orniwat & iowi.",
    },
}

FFE.INFO_EN = {
    neu = {
        { version = "1.0.1", items = {
            "Emergency Pack callouts now go straight to the pager – without the yes/no dialog.",
            "Emergency Pack hints during the incident stay visible and are written to the incident log.",
            "An Emergency Pack incident ends by itself once everything is done and cleaned up.",
            "Tablet easier to read: larger text, greyed-out areas no longer cover anything.",
            "Pager: after the turnout time an AI fire engine responds as well – you can join at any time.",
            "Pager and tablet are now available in English and German (follows the game language).",
        } },
        { version = "1.0.0", items = {
            "First version! A pager styled like a real digital fire pager, with alert tone and acknowledge.",
            "Incidents: real Emergency Pack callouts – without the pack the pager creates its own alerts.",
            "Command tablet with Alt+T, everything by mouse: situation, station, incident map and info.",
            "Incident map: live map of the incident with the scene, the station and your position.",
            "You drive there yourself. If you are not on your way after the turnout time, the neighbouring brigade (AI) takes over.",
            "Vehicle status 3 / 4 / 1 / 2 like German fire brigades, request more units and incident log.",
            "Grey in the tablet = coming soon: fleet and dispatch rules follow with version 1.1.",
            "Everything is saved with your savegame.",
        } },
    },
    geplant = {
        { version = "1.1", titel = "Big update", text = "Your own fleet, dispatch rules, AI crew members drive your fire engines (AutoDrive)." },
        { version = "1.2", titel = "Multiplayer", text = "Together on a server – the host is the station commander and assigns roles." },
        { version = "1.3", titel = "Brigade and finances", text = "Municipal budget, cost recovery, getting vehicles ready again." },
        { version = "1.4", titel = "Alerting", text = "Keywords like real German brigades, village siren, daytime availability, alert groups." },
        { version = "1.5", titel = "Incident procedure", text = "Incident phases, water supply, breathing apparatus monitoring." },
        { version = "1.6", titel = "New incidents", text = "Combine and hay barn fires, animal in a slurry pit, ambulance service, storms." },
        { version = "1.7", titel = "More brigades", text = "Neighbouring brigades with real travel times, district fire chief, convoy." },
    },
    nutzung = {
        "Playing alone or in multiplayer with friends: explicitly allowed.",
        "Community servers (public, roleplay, application-based): please contact us first – Discord: discord.gg/WKdQmKaVFG",
        "Uploading to other sites or modified versions: only with permission from Orniwat & iowi.",
    },
}
