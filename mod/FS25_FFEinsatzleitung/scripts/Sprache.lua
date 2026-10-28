-- =============================================================================
-- FF Einsatzleitung  -  Sprache (Deutsch / Englisch)
--
-- Der Mod ist auf Deutsch geschrieben. Ist das Spiel nicht auf Deutsch gestellt,
-- uebersetzt FFE:L() jeden angezeigten Text ins Englische:
--   1. genaue Treffer in FFE.EN
--   2. Muster in FFE.EN_MUSTER (Teile in Klammern werden selbst wieder uebersetzt)
--   3. zusammengesetzte Texte ("A · B", "A  B") werden in Teilen uebersetzt
-- Unbekannte Texte bleiben, wie sie sind (Fahrzeugnamen, Funkrufnamen ...).
--
-- Copyright (c) 2026 Orniwat & iowi. Alle Rechte vorbehalten.
-- Weitergabe, Veraenderung oder erneutes Hochladen nur mit Erlaubnis der Autoren.
-- =============================================================================

-- "de" oder "en" - richtet sich nach der Spielsprache
-- Erkennung (einmal, dann gemerkt):
--   1. unser eigener Tastentext aus der modDesc (<l10n>) - das Spiel laedt ihn in der Spielsprache
--   2. g_languageShortName bzw. getLanguageCode(getLanguage()) der Engine
function FFE:sprache()
    if self.spracheFest ~= nil then
        return self.spracheFest
    end
    if self.spracheErkannt ~= nil then
        return self.spracheErkannt
    end
    local code, quelle = nil, nil
    if g_i18n ~= nil and g_i18n.getText ~= nil and (g_i18n.hasText == nil or g_i18n:hasText("input_FFE_QUIT")) then
        local t = g_i18n:getText("input_FFE_QUIT")
        if type(t) == "string" and string.sub(t, 1, 6) == "Melder" then
            code, quelle = "de", "l10n"
        elseif type(t) == "string" and string.sub(t, 1, 5) == "Pager" then
            code, quelle = "en", "l10n"
        end
    end
    if code == nil and type(g_languageShortName) == "string" then
        code, quelle = (g_languageShortName == "de") and "de" or "en", "g_languageShortName=" .. g_languageShortName
    end
    if code == nil and getLanguage ~= nil and getLanguageCode ~= nil then
        local c = getLanguageCode(getLanguage())
        if type(c) == "string" then
            code, quelle = (c == "de") and "de" or "en", "getLanguageCode=" .. c
        end
    end
    if code == nil then
        return "en"           -- noch nicht erkennbar (z. B. sehr frueh beim Laden) - nicht merken
    end
    self.spracheErkannt = code
    if self.log ~= nil then
        self.log("Sprache: %s (%s)", code, quelle)
    end
    return code
end

FFE.EN = {
    -- Reiter, Kopfzeilen, Knoepfe
    ["BALD"] = "SOON",
    ["NEU"] = "NEW",
    ["KARTE"] = "MAP",
    ["Schließen  Alt+T"] = "Close  Alt+T",
    ["Lage"] = "Situation",
    ["kein Einsatz"] = "no incident",
    ["Kein laufender Einsatz"] = "No active incident",
    ["Kein laufender Einsatz."] = "No active incident.",
    ["Der Melder alarmiert dich, sobald es einen Einsatz gibt."] = "The pager alerts you as soon as there is an incident.",
    ["Probealarm"] = "Test alert",
    ["LETZTE EINSÄTZE"] = "RECENT INCIDENTS",
    ["RÜCKFAHRT (STATUS 1)"] = "RETURNING (STATUS 1)",
    ["Alle Fahrzeuge einsatzbereit."] = "All vehicles ready.",
    ["Festgefahren? Alle heimholen  (ab 1.1)"] = "Stuck? Bring all home  (from 1.1)",
    ["Festgefahren? Alle heimholen"] = "Stuck? Bring all home",
    ["Festgefahren? Alle zur Einsatzstelle"] = "Stuck? Move all to the scene",
    ["Festgefahren? Alle holen  (ab 1.1)"] = "Stuck? Move all  (from 1.1)",
    ["Dein Einsatz"] = "Your incident",
    ["EINHEITEN  (* = Nachbarwehr)"] = "UNITS  (* = neighbouring brigade)",
    ["EINHEITEN DER NACHBARWEHR"] = "UNITS OF THE NEIGHBOURING BRIGADE",
    ["AKTIONEN"] = "ACTIONS",
    ["Alarm quittieren"] = "Acknowledge alert",
    ["Endet von selbst, wenn alles erledigt und aufgeräumt ist."] = "Ends by itself once everything is done and cleaned up.",
    ["Einsatz abbrechen"] = "Abort incident",
    ["Einsatz beenden"] = "End incident",
    ["Einsatz beendet."] = "Incident ended.",
    ["NACHALARMIEREN"] = "REQUEST MORE UNITS",
    ["EINSATZTAGEBUCH"] = "INCIDENT LOG",
    ["AB 1.1"] = "FROM 1.1",
    ["KOMMT BALD"] = "COMING SOON",

    -- Status
    ["alarmiert"] = "alerted",
    ["Anfahrt"] = "en route",
    ["vor Ort"] = "on scene",
    ["frei über Funk"] = "available on radio",
    ["frei"] = "available",

    -- Fuhrpark
    ["Fuhrpark"] = "Fleet",
    ["NEU GEKAUFT"] = "NEWLY BOUGHT",
    ["Keine weiteren Fahrzeuge."] = "No other vehicles.",
    ["Keine Feuerwehrfahrzeuge erkannt."] = "No fire vehicles detected.",
    ["kein Vorschlag"] = "no suggestion",
    ["AUF DER WACHE"] = "AT THE STATION",
    ["Noch keine Fahrzeuge."] = "No vehicles yet.",
    ["Oben ein Fahrzeug auswählen."] = "Pick a vehicle above.",
    ["Links ein Fahrzeug auswählen"] = "Pick a vehicle on the left",
    ["Neu gekaufte Fahrzeuge fügst du hier der Wache hinzu."] = "Add newly bought vehicles to your station here.",
    ["neu gekauft"] = "newly bought",
    ["auf der Wache"] = "at the station",
    ["BEZEICHNUNG"] = "DESIGNATION",
    ["Eigene ..."] = "Custom ...",
    ["eigene Bezeichnung"] = "custom designation",
    ["KLASSE (AAO)"] = "CLASS (DISPATCH)",
    ["NUMMER"] = "NUMBER",
    ["AUF DEM MELDER"] = "ON THE PAGER",
    ["FUNKRUFNAME (OPTIONAL)"] = "RADIO CALL SIGN (OPTIONAL)",
    ["z.B. Florian Musterdorf 1/46-1"] = "e.g. Florian Sampletown 1/46-1",
    ["Aktuelle Position als Stellplatz übernehmen"] = "Use current position as parking spot",
    ["Stellplatz: aktuelle Position"] = "Parking spot: current position",
    ["Fahrzeug nicht gefunden."] = "Vehicle not found.",
    ["gesetzt – hier parkt die KI nach dem Einsatz"] = "set – the AI parks here after the incident",
    ["nicht gesetzt – KI parkt neben der Wache"] = "not set – the AI parks next to the station",
    ["Alle Klassen der AAO sind vorhanden."] = "All dispatch classes are available.",
    ["Abbrechen"] = "Cancel",
    ["Zur Wache hinzufügen"] = "Add to station",
    ["Bitte eine Bezeichnung wählen."] = "Please choose a designation.",
    ["Wirklich entfernen?"] = "Really remove?",
    ["Von der Wache nehmen"] = "Remove from station",
    ["Speichern"] = "Save",

    -- AAO
    ["Alarm- und Ausrückeordnung"] = "Dispatch rules",
    ["Linksklick +1, Rechtsklick -1  ·  grau = Klasse fehlt auf der Wache (Nachbarwehr)"] = "Left click +1, right click -1  ·  grey = class missing at the station (neighbouring brigade)",
    ["STICHWORT"] = "KEYWORD",
    ["NACHBAR"] = "NEIGHBOUR",
    ["* = Klasse fehlt auf der Wache, kommt von der Nachbarwehr (wenn dort \"an\")."] = "* = class missing at the station, comes from the neighbouring brigade (if set to \"on\").",
    ["Standard wiederherstellen"] = "Restore defaults",
    ["AAO auf Standard zurückgesetzt."] = "Dispatch rules reset to defaults.",
    ["an"] = "on",
    ["aus"] = "off",

    -- Kommt bald
    ["Gekaufte Fahrzeuge zur Wache hinzufügen, z. B. HLF 20 oder DLK 23/12 –"] = "Add bought vehicles to your station, e.g. a rescue engine or a ladder truck –",
    ["mit Nummer, Funkrufname und Stellplatz."] = "with number, radio call sign and parking spot.",
    ["Bei Alarm besetzen KI-Kameraden deine Fahrzeuge und rücken mit aus."] = "On an alert, AI crew members man your trucks and respond with you.",
    ["Mit AutoDrive fahren sie selbst zur Einsatzstelle und zurück zur Wache."] = "With AutoDrive they drive to the scene and back to the station by themselves.",
    ["Pro Stichwort festlegen, welche Fahrzeuge ausrücken – per Klick."] = "Choose per keyword which vehicles respond – with one click.",
    ["Nachbarwehr pro Stichwort an oder aus."] = "Neighbouring brigade on or off per keyword.",
    ["Fehlende Fahrzeuge werden angezeigt."] = "Missing vehicles are shown.",
    ["Bis dahin rückt bei jedem Alarm die Nachbarwehr aus – oder du fährst selbst hin."] = "Until then the neighbouring brigade responds to every alert – or you drive there yourself.",
    ["Was sonst noch kommt, steht im Reiter INFO."] = "What else is coming: see the INFO tab.",
    ["Abschnitte & Zuweisen"] = "Sectors & assigning",
    ["Fahrzeuge per Klick aufstellen"] = "Position vehicles with a click",
    ["Aufstellung der Fahrzeuge"] = "Vehicle positions",
    ["Wer wo steht, Abschnitte, Zuweisen"] = "Who stands where, sectors, assigning",
    ["KI-Fahrzeuge rücken wirklich aus (AutoDrive)"] = "AI vehicles really respond (AutoDrive)",
    ["Bis dahin fährst du selbst – der KI-Zug rückt nur auf dem Melder aus."] = "Until then you drive yourself – the AI crew only responds on the pager.",

    -- Karte
    ["Lagekarte"] = "Incident map",
    ["Ansicht – Abschnitte und Zuweisen kommen bald"] = "view – sectors and assigning coming soon",
    ["Live-Karte des Einsatzes"] = "live map of the incident",
    ["Kein laufender Einsatz – Ansicht der Wache"] = "No active incident – station view",
    ["Kein laufender Einsatz – Wache noch nicht gesetzt (Reiter Wache)"] = "No active incident – station not set yet (Station tab)",
    ["LAGE"] = "SITUATION",
    ["AUFSTELLUNG"] = "POSITIONS",
    ["LEGENDE"] = "LEGEND",
    ["E  Einsatzstelle (Kreis = vor Ort)"] = "E  Incident scene (circle = on scene)",
    ["W  Wache"] = "W  Station",
    ["du"] = "you",
    ["Fahrzeug auf Anfahrt (Status 3)"] = "Vehicle en route (status 3)",
    ["Fahrzeug vor Ort (Status 4)"] = "Vehicle on scene (status 4)",

    -- Wache
    ["Wache und Einstellungen"] = "Station and settings",
    ["NAME DER WEHR"] = "BRIGADE NAME",
    ["z.B. FF Musterdorf"] = "e.g. VFD Sampletown",
    ["STANDORT DER WACHE"] = "STATION LOCATION",
    ["Meine Position als Wache setzen"] = "Set my position as station",
    ["noch nicht gesetzt"] = "not set yet",
    ["Wache woanders gebaut? Einfach neu setzen und im Reiter Fuhrpark die Stellplätze neu übernehmen."] = "Built your station elsewhere? Just set it again and re-take the parking spots in the Fleet tab.",
    ["AUSRÜCKZEIT (MINUTEN ECHTZEIT)"] = "TURNOUT TIME (REAL-TIME MINUTES)",
    ["danach rückt ein KI-Fahrzeug aus und fährt mit an"] = "after that an AI vehicle responds as well",
    ["Nachbarwehr stellt fehlende Fahrzeuge"] = "Neighbouring brigade provides missing vehicles",
    ["pro Stichwort einstellbar im Reiter AAO"] = "adjustable per keyword in the Dispatch tab",
    ["Eigene Einsätze, wenn kein Emergency Pack aktiv ist"] = "Own incidents when the Emergency Pack is not active",
    ["der Melder erzeugt dann selbst Alarme"] = "the pager then creates alerts by itself",
    ["KI-Einsätze werden vergütet (halber Lohn)"] = "AI incidents are paid (half the reward)",
    ["wenn die Nachbarwehr den Einsatz ohne dich abarbeitet"] = "when the neighbouring brigade handles the incident without you",
    ["Fahrzeuge rücken wirklich aus"] = "Vehicles really respond",
    ["mit AutoDrive fahren sie selbst, sonst werden sie unbemerkt versetzt"] = "with AutoDrive they drive themselves, otherwise they are moved out of sight",
    ["werden unbemerkt versetzt (mit AutoDrive fahren sie selbst)"] = "are moved out of sight (with AutoDrive they drive themselves)",
    ["EMPFOHLENE MODS"] = "RECOMMENDED MODS",
    ["ÜBERSICHT"] = "OVERVIEW",
    ["Gespeichert wird mit dem Spielstand."] = "Saved with the savegame.",
    ["aktiv"] = "active",
    ["der Melder erzeugt eigene Einsaetze"] = "the pager creates its own incidents",
    ["Fahrzeuge fahren nicht selbst zur Einsatzstelle"] = "vehicles do not drive to the scene by themselves",

    -- Info
    ["Neuigkeiten und Roadmap"] = "News and roadmap",
    ["NUTZUNG"] = "USAGE",
    ["WAS NOCH KOMMT"] = "WHAT'S COMING",
    ["COMMUNITY"] = "COMMUNITY",
    ["Komm auf unseren Discord!"] = "Join our Discord!",
    ["Feedback, Ideen, Fehler melden, neue Versionen als Erste testen."] = "Feedback, ideas, bug reports, be the first to test new versions.",
    ["Öffnen"] = "Open",
    ["Link folgt mit dem nächsten Update"] = "Link follows with the next update",

    -- Melder
    ["ALARM"] = "ALERT",
    ["DEIN EINSATZ"] = "YOUR INCIDENT",
    ["OK=QUITT."] = "OK=ACK",
    ["[Alt+Q] Quittieren   [Alt+Shift+E] Einsatz beenden"] = "[Alt+Q] Acknowledge   [Alt+Shift+E] End incident",
    ["[Alt+Shift+E] Einsatz beenden   [Alt+M] ausblenden"] = "[Alt+Shift+E] End incident   [Alt+M] Hide",
    ["EINSATZ BEENDET (KI)"] = "INCIDENT ENDED (AI)",
    ["EINSATZ BEENDET"] = "INCIDENT ENDED",

    -- Einsatztagebuch / Rueckmeldungen
    ["Spieler an der Einsatzstelle"] = "Player on scene",
    ["Spieler rückt aus"] = "Player responds",
    ["Spieler übernimmt von der KI"] = "Player takes over from the AI",
    ["Ausrückzeit abgelaufen – KI-Zug fährt"] = "Turnout time over – AI crew responds",
    ["Position nicht ermittelbar."] = "Position could not be determined.",
    ["Fahrzeug nicht im Fuhrpark gefunden."] = "Vehicle not found in the fleet.",
    ["Stellplatz konnte nicht gelesen werden."] = "Parking spot could not be read.",
    ["Setz dich in ein angemeldetes Fahrzeug und park es auf seinem Stellplatz."] = "Get into a registered vehicle and park it on its spot.",

    -- Stichworte (Einsatzarten)
    ["Einsatz"] = "Incident",
    ["Brand"] = "Fire",
    ["Brennende Paletten"] = "Burning pallets",
    ["Brand Paletten"] = "Pallet fire",
    ["Containerbrand"] = "Container fire",
    ["Brand Muelltonne"] = "Waste bin fire",
    ["Brennender Strohballen"] = "Burning straw bale",
    ["Brand Ballenlager"] = "Bale storage fire",
    ["Feldbrand"] = "Field fire",
    ["Fahrzeugbrand"] = "Vehicle fire",
    ["Fahrzeugbrand Traktor"] = "Tractor fire",
    ["Brand Maehdrescher"] = "Combine harvester fire",
    ["Brand Scheune"] = "Barn fire",
    ["Brand Stall, Tiere im Gebaeude"] = "Stable fire, animals inside",
    ["Brand landw. Anwesen"] = "Farmstead fire",
    ["Waldbrand"] = "Forest fire",
    ["Flaechenbrand Waldrand"] = "Wildfire at forest edge",
    ["BMA Saegewerk"] = "Fire alarm sawmill",
    ["BMA Molkerei"] = "Fire alarm dairy",
    ["BMA Lagerhalle"] = "Fire alarm warehouse",
    ["Baum auf Strasse"] = "Tree on road",
    ["Ast auf Fahrbahn"] = "Branch on road",
    ["Katze auf Baum"] = "Cat in tree",
    ["Tier in Notlage"] = "Animal in distress",
    ["VU, Person eingeklemmt"] = "Crash, person trapped",
    ["VU Traktor mit Pkw"] = "Crash tractor and car",
    ["Lkw verunfallt"] = "Truck crash",
    ["Oelspur auf Fahrbahn"] = "Oil spill on road",
    ["Betriebsstoffe ausgelaufen"] = "Fluids leaking",
    ["siehe Karte"] = "see map",
    ["Ortslage"] = "Village",
}

-- Muster: { Lua-Muster, englische Vorlage mit %s fuer die (uebersetzten) Treffer }
FFE.EN_MUSTER = {
    { "^(.-) rückt aus in (.-) – oder du bist schneller$", "%s responds in %s – or you're faster" },
    { "^(.-) vor Ort · fertig in (.+)$", "%s on scene · done in %s" },
    { "^(.-) auf Anfahrt – du kannst dazustoßen$", "%s en route – you can join" },
    { "^(.-) RÜCKT AUS (.+)$", "%s RESPONDS %s" },
    { "^(.-) VOR ORT (.+)$", "%s ON SCENE %s" },
    { "^(.-) AUF ANFAHRT$", "%s EN ROUTE" },
    { "^(.-) rückt aus$", "%s responds" },
    { "^(.-) rückt mit dem Spieler aus$", "%s responds with the player" },
    { "^(.-) fährt mit AutoDrive$", "%s drives with AutoDrive" },
    { "^(.-) %(Nachbarwehr%)$", "%s (neighbouring brigade)" },
    { "^Feld (%d+)$", "Field %s" },
    { "^nahe Feld (%d+)$", "near field %s" },
    { "^nahe (.+)$", "near %s" },
    { "^Ort: (.-)      Alarm: (.*)$", "Location: %s      Alert: %s" },
    { "^Status (%d): (.+)$", "Status %s: %s" },
    { "^Alarm (.-) – (.+)$", "Alert %s – %s" },
    { "^Nachalarmiert: (.+)$", "Requested: %s" },
    { "^(.-) nachalarmiert%.$", "%s requested." },
    { "^Leitstelle: (.+)$", "Dispatch: %s" },
    { "^Lagekarte  (.+)$", "Incident map  %s" },
    { "^Von der Wache: (.-) Richtung (.+)$", "From the station: %s heading %s" },
    { "^Von dir: (.-) Richtung (.+)$", "From you: %s heading %s" },
    { "^Anfahrt ca%. (.+)$", "Travel time approx. %s" },
    { "^Kräfte: (%d+) Fahrzeuge$", "Units: %s vehicles" },
    { "^(.-) (.-) der E%-Stelle$", "%s %s of the scene" },
    { "^Wache (.+)$", "Station %s" },
    { "^gesetzt %((.+)%)$", "set (%s)" },
    { "^Fahrzeuge auf der Wache: (%d+)$", "Vehicles at the station: %s" },
    { "^Fehlende Klassen für die AAO: (%d+)$", "Missing dispatch classes: %s" },
    { "^fehlt %- (.+)$", "missing - %s" },
    { "^FF Einsatzleitung: (.-) nicht aktiv %- (.-)%.$", "Fire Brigade Command: %s not active - %s." },
    { "^FF Einsatzleitung (.-): Neuigkeiten im Tablet %(Alt%+T > INFO%)$", "Fire Brigade Command %s: news in the tablet (Alt+T > INFO)" },
    { "^FF Einsatzleitung (.+)$", "Fire Brigade Command %s" },
    { "^NEU IN VERSION (.+)$", "NEW IN VERSION %s" },
    { "^VERSION (.+)$", "VERSION %s" },
    { "^KOMMT MIT (.+)$", "COMING WITH %s" },
    { "^Kommt mit Version (.+)$", "Coming with version %s" },
    { "^Neuigkeiten im Reiter INFO · Discord: (.+)$", "News in the INFO tab · Discord: %s" },
    { "^(%d+) Fahrzeug%(e%) auf den Stellplatz gesetzt%.$", "%s vehicle(s) moved to their parking spot." },
    { "^(%d+) Fahrzeug%(e%) an die Einsatzstelle gesetzt%.$", "%s vehicle(s) moved to the scene." },
    { "^(.-) · (%d+) Fahrzeuge auf der Wache · (%d+) neu$", "%s · %s vehicles at the station · %s new" },
    { "^Vorschlag: (.+)$", "Suggestion: %s" },
    { "^Alle Fahrzeuge des Hofs zeigen %((%d+)%)$", "Show all farm vehicles (%s)" },
    { "^(%d+)%-(%d+) von (%d+)$", "%s-%s of %s" },
    { "^Stellplatz f[uü]e?r (.+) gespeichert%.$", "Parking spot for %s saved." },
    { "^(.+) gespeichert%.$", "%s saved." },
    { "^(.+) von der Wache genommen%.$", "%s removed from the station." },
    { "^(.+) aus dem Fuhrpark entfernt%.$", "%s removed from the fleet." },
    { "^Fehlt für die AAO: (.+) – stellt die Nachbarwehr$", "Missing for dispatch: %s – provided by the neighbouring brigade" },
    { "^(.-): (%d+) auf der Wache nach dem Speichern%.$", "%s: %s at the station after saving." },
    { "^(.-) %(Klasse (.-)%) zur Wache hinzugefügt%.$", "%s (class %s) added to the station." },
    { "^Wache gesetzt %((.+)%)%.$", "Station set (%s)." },
    { "^Unbekanntes Stichwort: (.+)$", "Unknown keyword: %s" },
    { "^TAG (%d+)$", "DAY %s" },
    { "^(%d+) FZG STATUS 1$", "%s VEH. STATUS 1" },
    { "^(.-) %- BEREIT$", "%s - READY" },
    { "^LETZT: (.+)$", "LAST: %s" },
    { "^(.-) (festgefahren) – AutoDrive neu gestartet$", "%s stuck – AutoDrive restarted" },
    { "^(.-) (.-) – an die Einsatzstelle versetzt$", "%s %s – moved to the scene" },
}

-- Teile, an denen zusammengesetzte Texte getrennt und einzeln uebersetzt werden
local TRENNER = { " · ", "  ", " – " }

local function uebersetze(s, tiefe)
    if s == "" then
        return s
    end
    local e = FFE.EN[s]
    if e ~= nil then
        return e
    end
    if tiefe > 3 then
        return s
    end
    for _, m in ipairs(FFE.EN_MUSTER) do
        local caps = { string.match(s, m[1]) }
        if #caps > 0 then
            for i, c in ipairs(caps) do
                caps[i] = uebersetze(c, tiefe + 1)
            end
            return string.format(m[2], unpack(caps))
        end
    end
    for _, t in ipairs(TRENNER) do
        local a, b = string.find(s, t, 1, true)
        if a ~= nil then
            return uebersetze(string.sub(s, 1, a - 1), tiefe + 1) .. t .. uebersetze(string.sub(s, b + 1), tiefe + 1)
        end
    end
    return s
end

-- Text fuer die Anzeige in der Spielsprache
function FFE:L(s)
    if s == nil then
        return ""
    end
    s = tostring(s)
    if self:sprache() == "de" then
        return s
    end
    return uebersetze(s, 0)
end
