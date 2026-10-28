-- =============================================================================
-- FF Einsatzleitung  -  Kern: Einstellungen, Stichworte, Lebenszyklus, Tasten, Alarm
--
-- Dateien (Ladereihenfolge siehe modDesc.xml):
--   FFEinsatzleitung.lua  Kern (diese Datei)
--   Fuhrpark.lua          Fahrzeuge, Wache, AAO, Speichern/Laden
--   Einsatz.lua           Ausrueckzeit, Fahrzeugstatus, KI-Loeschzug
--   Ausruecken.lua        echte Fahrzeuge: Sichtblase, AutoDrive, Einsatztagebuch
--   EmergencyPack.lua     Kopplung an das Emergency Pack
--   Pager.lua             Melder: Ton, Kartenpunkt, Anzeige
--   Tablet.lua            EL-Tablet (Alt+T): Lage, Fuhrpark, AAO, Wache, Info
--   Info.lua              Neuigkeiten/Roadmap fuer den Reiter INFO (erzeugt aus docs/SPIELER-INFO.md)
--   Konsole.lua           Konsolenbefehle (nur fuer Entwickler) und Diagnose
--
-- Copyright (c) 2026 Orniwat & iowi. Alle Rechte vorbehalten.
-- Weitergabe, Veraenderung oder erneutes Hochladen nur mit Erlaubnis der Autoren.
-- =============================================================================

FFE = {}
FFE.modDirectory = g_currentModDirectory
FFE.modName = g_currentModName
FFE.VERSION = "1.0.1"
FFE.CHANNEL = "stable"             -- dev | beta | stable | mp (setzt tools/set_version.py)
FFE.AUTHORS = "Orniwat & iowi"
FFE.DISCORD = "https://discord.gg/WKdQmKaVFG"   -- Einladungslink (INFO-Reiter) - leer = "Link folgt"

-- Funktionen, die in der veroeffentlichten Grundversion (beta/stable) noch gesperrt sind
-- und dort als "kommt bald" erscheinen. Im dev- und mp-Kanal ist alles an.
-- Fuer das grosse Update einfach hier freischalten.
local ALLES_AN = FFE.CHANNEL == "dev" or FFE.CHANNEL == "mp"
FFE.FEATURES = {
    fuhrpark   = ALLES_AN,   -- eigene Fahrzeuge, Reiter Fuhrpark und AAO (sonst faehrt die Nachbarwehr)
    ausruecken = ALLES_AN,   -- KI-Fahrzeuge fahren/werden versetzt, AutoDrive, Freibuggen
    aufstellung = ALLES_AN,  -- Lagekarte zeigt die Aufstellung der Fahrzeuge
}

function FFE:feature(name)
    return self.FEATURES[name] == true
end

local LOG_PREFIX = "[FFE] "

function FFE.log(fmt, ...)
    print(LOG_PREFIX .. string.format(fmt, ...))
end

local log = FFE.log

-- ---------------------------------------------------------------------------
-- Einstellungen (wehrName, ausrueckzeitMin, nachbarwehr werden im Spielstand gespeichert)
-- ---------------------------------------------------------------------------
FFE.settings = {
    enabled           = true,
    minIntervalMin    = 20,     -- Echtzeit-Minuten bis zum naechsten eigenen Zufallsalarm (min)
    maxIntervalMin    = 45,     -- ... (max)
    volume            = 1.0,
    repeatEverySec    = 25,     -- Erinnerungston, solange nicht quittiert
    maxRepeats        = 3,
    resetTimeScale    = true,   -- Zeitraffer bei Alarm auf 1x
    hideAfterQuitSec  = 90,     -- Melder blendet nach Quittieren aus
    posX              = nil,    -- linke Kante des Melders, nil = automatisch rechts
    posY              = 0.20,   -- Unterkante des Melders
    pagerScale        = 1.0,
    useEmergencyPack  = true,   -- echte Emergency-Pack-Einsaetze auf den Melder legen
    suppressEPPopup   = true,   -- Ja/Nein-Abfrage des Packs automatisch bestaetigen
    popupDebug        = false,  -- erste Aufrufe der Popup-Funktionen ins Log schreiben
    epFallbackSec     = 10,     -- startet das Pack nach allen Versuchen nichts, piept der Melder selbst
    epVersuche        = 15,     -- so oft den Pager des Packs ausloesen (das Pack wuerfelt jedes Mal)
    epVersuchAbstandSec = 4,    -- Sekunden zwischen den Versuchen

    wehrName          = "FF MUSTERDORF",
    ausrueckzeitMin   = 4,      -- Echtzeit-Minuten, bis die Fahrzeuge ohne dich ausruecken
    nachbarwehr       = true,   -- fehlende Fahrzeuge stellt die Nachbarwehr (virtuell)
    vorOrtRadius      = 150,    -- Meter: ab hier gilt man als an der Einsatzstelle
    kiVerguetung      = true,   -- KI-Einsaetze werden (halb) verguetet
    echtAusruecken    = true,   -- Fuhrpark-Fahrzeuge ruecken wirklich aus (Sichtblase / AutoDrive)
}

-- ---------------------------------------------------------------------------
-- Stichworte
-- sound: 1 = Klassisch, 2 = Zweiton (gross), 3 = Dezent (klein)
-- dauerMin: wie lange die KI vor Ort braucht (Echtzeit-Minuten)
-- lohn: Verguetung, wenn du selbst vor Ort warst; die KI bekommt die Haelfte
-- ---------------------------------------------------------------------------
FFE.STICHWORTE = {
    { code = "B1",      titel = "KLEINBRAND",    weight = 4, sound = 3, dauerMin = 5,  lohn = 3000,
      details = { "Brennende Paletten", "Containerbrand", "Brand Muelltonne", "Brennender Strohballen" } },
    { code = "B2",      titel = "MITTELBRAND",   weight = 3, sound = 1, dauerMin = 10, lohn = 6000,
      details = { "Brand Ballenlager", "Feldbrand", "Fahrzeugbrand Traktor", "Brand Maehdrescher" } },
    { code = "B3",      titel = "GROSSBRAND",    weight = 1, sound = 2, dauerMin = 20, lohn = 12000,
      details = { "Brand Scheune", "Brand Stall, Tiere im Gebaeude", "Brand landw. Anwesen" } },
    { code = "B WALD",  titel = "WALDBRAND",     weight = 1, sound = 2, dauerMin = 15, lohn = 10000,
      details = { "Waldbrand", "Flaechenbrand Waldrand" } },
    { code = "BMA",     titel = "BRANDMELDEANL.", weight = 2, sound = 1, dauerMin = 4, lohn = 1600,
      details = { "BMA Saegewerk", "BMA Molkerei", "BMA Lagerhalle" } },
    { code = "TH1",     titel = "TECHN. HILFE",  weight = 4, sound = 3, dauerMin = 5,  lohn = 2400,
      details = { "Baum auf Strasse", "Ast auf Fahrbahn" } },
    { code = "TH TIER", titel = "TIERRETTUNG",   weight = 2, sound = 3, dauerMin = 6,  lohn = 3000,
      details = { "Katze auf Baum", "Tier in Notlage" } },
    { code = "TH VU",   titel = "VERKEHRSUNF.",  weight = 2, sound = 2, dauerMin = 10, lohn = 5000,
      details = { "VU, Person eingeklemmt", "VU Traktor mit Pkw", "Lkw verunfallt" } },
    { code = "TH OEL",  titel = "OELSPUR",       weight = 3, sound = 3, dauerMin = 6,  lohn = 2000,
      details = { "Oelspur auf Fahrbahn", "Betriebsstoffe ausgelaufen" } },
}

-- Empfohlene Mods (weiche Abhaengigkeiten): fehlt einer, laeuft der Mod trotzdem
-- und meldet einmal im Spiel, was dann nicht geht.
FFE.EMPFOHLEN = {
    { mod = "pdlc_emergencyPack", name = "Emergency Pack", ohne = "der Melder erzeugt eigene Einsaetze" },
    { mod = "FS25_AutoDrive",     name = "AutoDrive",      ohne = "Fahrzeuge fahren nicht selbst zur Einsatzstelle", feature = "ausruecken" },
}

FFE.SOUND_FILES = {
    "sounds/melder_1_klassisch.ogg",
    "sounds/melder_2_zweiton.ogg",
    "sounds/melder_3_dezent.ogg",
}

function FFE:getStichwort(code)
    if code == nil then
        return nil
    end
    local wanted = string.gsub(string.upper(tostring(code)), "[%s_]", "")
    for _, s in ipairs(self.STICHWORTE) do
        if string.gsub(s.code, " ", "") == wanted then
            return s
        end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Zustand
-- ---------------------------------------------------------------------------
function FFE:resetState()
    self.alarm = nil              -- aktueller Einsatz (Tabelle) oder nil
    self.history = {}             -- letzte Alarme
    self.returning = {}           -- Fahrzeuge auf Rueckfahrt (Status 1)
    self.zurueck = {}             -- echte Fahrzeuge, die noch auf ihren Stellplatz muessen
    self.visible = false
    self.nextAlarmInMs = 0
    self.blinkTimer = 0
    self.blinkOn = true
    self.repeatTimer = 0
    self.repeatCount = 0
    self.hideTimer = 0
    self.samples = {}
    self.hotspot = nil
    self.overlay = nil
    self.housing = nil
    self.tabletFrame = nil
    self.tablet = nil
    self.eventIds = {}
    self.registeredContext = nil
    self.isLoaded = false
    self.fieldCenters = nil
    self.epKnown = nil
    self.epInitialized = false
    self.epCheckTimer = 0
    self.epErrorLogged = false
    self.epRequest = nil
    self.epMethodsLogged = false
    self.popupCallCount = {}
    self.popupHooksDisabled = false
    self.epIgnored = {}
    self.epAbortChecks = {}
    self.errorLogged = {}
    self.modsChecked = false
    self.fehlendeMods = {}
    self.infoNeu = false
end

FFE:resetState()

-- Ist ein Mod/DLC aktiv?
function FFE:isModActive(name)
    if g_modIsLoaded ~= nil and g_modIsLoaded[name] then
        return true
    end
    return rawget(_G, name) ~= nil
end

-- Einmal nach Spielstart: fehlende empfohlene Mods im Spiel melden
function FFE:checkEmpfohleneMods()
    self.fehlendeMods = {}
    for _, m in ipairs(self.EMPFOHLEN) do
        if (m.feature == nil or self:feature(m.feature)) and not self:isModActive(m.mod) then
            table.insert(self.fehlendeMods, m)
            local text = string.format("FF Einsatzleitung: %s nicht aktiv - %s.", m.name, m.ohne)
            log("%s", text)
            if g_currentMission ~= nil and g_currentMission.hud ~= nil and g_currentMission.hud.addSideNotification ~= nil then
                g_currentMission.hud:addSideNotification({ 1, 0.65, 0.2, 1 }, self:L(text), 12000)
            end
        end
    end
end

-- Neue Version seit dem letzten Start? (gilt fuer alle Spielstaende, liegt in modSettings)
function FFE:getInfoFile()
    local base = nil
    if getUserProfileAppPath ~= nil then
        base = getUserProfileAppPath()
    end
    if base == nil then
        return nil
    end
    return base .. "modSettings/FS25_FFEinsatzleitung.xml"
end

function FFE:checkNeueVersion()
    local path = self:getInfoFile()
    local seen = nil
    if path ~= nil and fileExists(path) then
        local xml = loadXMLFile("ffeInfo", path)
        if xml ~= nil and xml ~= 0 then
            seen = getXMLString(xml, "ffEinsatzleitung#gesehen")
            delete(xml)
        end
    end
    if seen ~= self.VERSION then
        self.infoNeu = true
        local text = string.format("FF Einsatzleitung %s: Neuigkeiten im Tablet (Alt+T > INFO)", self.VERSION)
        log("%s", text)
        if g_currentMission ~= nil and g_currentMission.hud ~= nil and g_currentMission.hud.addSideNotification ~= nil then
            g_currentMission.hud:addSideNotification({ 0.94, 0.54, 0.24, 1 }, self:L(text), 10000)
        end
    end
end

function FFE:markInfoGesehen()
    if not self.infoNeu then
        return
    end
    self.infoNeu = false
    local path = self:getInfoFile()
    if path == nil then
        return
    end
    if createFolder ~= nil then
        createFolder(string.match(path, "^(.*)/[^/]*$"))
    end
    local xml = createXMLFile("ffeInfo", path, "ffEinsatzleitung")
    if xml ~= nil and xml ~= 0 then
        setXMLString(xml, "ffEinsatzleitung#gesehen", self.VERSION)
        saveXMLFile(xml)
        delete(xml)
    end
end

-- Teilbereich aufrufen. Fehler werden NICHT abgefangen, sondern landen mit
-- Aufrufliste im Log (so will es GIANTS) - name dient nur der Lesbarkeit.
function FFE:safeCall(name, func, ...)
    func(self, ...)
    return true
end

-- ---------------------------------------------------------------------------
-- Lebenszyklus
-- ---------------------------------------------------------------------------
function FFE:loadMap(name)
    self:resetState()

    if g_currentMission ~= nil and g_currentMission.missionDynamicInfo ~= nil
        and g_currentMission.missionDynamicInfo.isMultiplayer then
        log("Multiplayer erkannt - der Mod ist nur fuer Singleplayer gedacht und wird deaktiviert.")
        self.settings.enabled = false
        return
    end

    -- Sounds
    for i, file in ipairs(self.SOUND_FILES) do
        local path = Utils.getFilename(file, self.modDirectory)
        if createSample ~= nil and loadSample ~= nil then
            local sample = createSample("FFE_sound_" .. i)
            if loadSample(sample, path, false) == false then
                log("Sound %s konnte nicht geladen werden.", tostring(file))
            end
            self.samples[i] = sample
        end
    end

    -- Overlays: weisse Flaeche (wird eingefaerbt) und Gehaeuse des Melders
    self.overlay = Overlay.new(g_baseUIFilename, 0, 0, 1, 1)
    if g_colorBgUVs ~= nil then
        self.overlay:setUVs(g_colorBgUVs)
    end
    self.housing = Overlay.new(Utils.getFilename("textures/pager_gehaeuse.dds", self.modDirectory), 0, 0, 1, 1)
    self.tabletFrame = Overlay.new(Utils.getFilename("textures/tablet_rahmen.dds", self.modDirectory), 0, 0, 1, 1)
    self:initTablet()

    self:initFleet()
    self:installSaveHook()
    self:registerConsoleCommands()

    self:scheduleNextAlarm()
    self.isLoaded = true
    log("FF Einsatzleitung %s (%s) geladen - (c) %s", self.VERSION, self.CHANNEL, self.AUTHORS)
end

function FFE:deleteMap()
    self:closeTablet()
    self:removePopupHooks()
    self:removeHotspot()
    for _, sample in pairs(self.samples) do
        if delete ~= nil then
            delete(sample)
        end
    end
    for _, o in pairs({ self.overlay, self.housing, self.tabletFrame, self.karteBild }) do
        if o.delete ~= nil then
            o:delete()
        end
    end
    self.karteBild = nil
    self:unregisterConsoleCommands()
    self:resetState()
end

function FFE:update(dt)
    if not self.isLoaded then
        return
    end

    self:registerInputs()

    if not self.modsChecked and g_currentMission ~= nil and g_currentMission.hud ~= nil then
        self.modsChecked = true
        self:safeCall("Mod-Pruefung", self.checkEmpfohleneMods)
        self:safeCall("Neuigkeiten", self.checkNeueVersion)
    end

    self:safeCall("Fuhrpark", self.updateFleet, dt)
    self:safeCall("Emergency Pack", self.updateEmergencyPack, dt)
    self:safeCall("Einsatz", self.updateEinsatz, dt)
    self:safeCall("Ausruecken", self.updateAusruecken, dt)

    -- Eigener Zufallsalarm nur, wenn das Emergency Pack nicht die Einsaetze liefert
    if self.settings.enabled and self.alarm == nil and not self:isEPActive() then
        self.nextAlarmInMs = self.nextAlarmInMs - dt
        if self.nextAlarmInMs <= 0 then
            self:triggerAlarm(nil)
        end
    end

    -- Blinken
    self.blinkTimer = self.blinkTimer + dt
    if self.blinkTimer >= 450 then
        self.blinkTimer = 0
        self.blinkOn = not self.blinkOn
    end

    if self.alarm ~= nil then
        if not self.alarm.quittiert then
            -- Erinnerungston
            self.repeatTimer = self.repeatTimer + dt
            if self.repeatTimer >= self.settings.repeatEverySec * 1000 and self.repeatCount < self.settings.maxRepeats then
                self.repeatTimer = 0
                self.repeatCount = self.repeatCount + 1
                self:playSound(self.alarm.sound)
            end
        elseif self.hideTimer > 0 then
            -- nach Quittieren ausblenden
            self.hideTimer = self.hideTimer - dt
            if self.hideTimer <= 0 then
                self.visible = false
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Eingaben
-- ---------------------------------------------------------------------------
function FFE:registerInputs()
    if g_inputBinding == nil or InputAction == nil or InputAction.FFE_QUIT == nil or InputAction.FFE_ABORT == nil then
        return
    end

    -- Waehrend Menues/Karte offen sind nichts registrieren; danach neu anmelden
    if g_gui ~= nil and g_gui.getIsGuiVisible ~= nil and g_gui:getIsGuiVisible() then
        self.registeredContext = nil
        return
    end

    local context = ""
    if g_inputBinding.getContextName ~= nil then
        context = g_inputBinding:getContextName() or ""
    end
    if context == self.registeredContext then
        return
    end
    self.registeredContext = context

    -- alte Anmeldungen entfernen, sonst feuert eine Taste doppelt
    if g_inputBinding.removeActionEventsByTarget ~= nil then
        g_inputBinding:removeActionEventsByTarget(self)
    end
    self.eventIds = {}

    local actions = {
        { InputAction.FFE_QUIT,      self.onActionQuit },
        { InputAction.FFE_TOGGLE,    self.onActionToggle },
        { InputAction.FFE_TESTALARM, self.onActionTest },
        { InputAction.FFE_ABORT,     self.onActionAbort },
        { InputAction.FFE_TABLET,    self.onActionTablet },
    }

    for _, a in ipairs(actions) do
        if a[1] == nil then
            break
        end
        local success, eventId = g_inputBinding:registerActionEvent(a[1], self, a[2], false, true, false, true)
        if success and eventId ~= nil then
            g_inputBinding:setActionEventTextVisibility(eventId, false)
            table.insert(self.eventIds, eventId)
        end
    end
end

-- Maus und Tastatur (nur fuer das Tablet)
function FFE:mouseEvent(posX, posY, isDown, isUp, button)
    if self.isLoaded then
        self:safeCall("Tablet-Maus", self.tabletMouseEvent, posX, posY, isDown, isUp, button)
    end
end

function FFE:keyEvent(unicode, sym, modifier, isDown)
    if self.isLoaded then
        self:safeCall("Tablet-Tastatur", self.tabletKeyEvent, unicode, sym, modifier, isDown)
    end
end

function FFE:onActionQuit()
    self:quitAlarm()
end

function FFE:onActionToggle()
    local now = (g_time or 0)
    if self.lastToggle ~= nil and now - self.lastToggle < 250 then
        return
    end
    self.lastToggle = now
    self.visible = not self.visible
    self.hideTimer = 0
end

function FFE:onActionAbort()
    if self.alarm == nil then
        return
    end
    self:abortEPScenario()
    self:endEinsatz(false)
end

function FFE:onActionTest()
    if self:isEPActive() then
        self:requestEPScenario()
    else
        self:triggerAlarm(nil)
    end
end

-- ---------------------------------------------------------------------------
-- Alarmlogik
-- ---------------------------------------------------------------------------
function FFE:scheduleNextAlarm()
    local minM = math.max(1, self.settings.minIntervalMin)
    local maxM = math.max(minM, self.settings.maxIntervalMin)
    self.nextAlarmInMs = math.random(minM * 60, maxM * 60) * 1000
end

function FFE:pickStichwort(code)
    local s = self:getStichwort(code)
    if s ~= nil then
        return s
    end
    local total = 0
    for _, st in ipairs(self.STICHWORTE) do
        total = total + st.weight
    end
    local r = math.random() * total
    for _, st in ipairs(self.STICHWORTE) do
        r = r - st.weight
        if r <= 0 then
            return st
        end
    end
    return self.STICHWORTE[1]
end

-- Mittelpunkte aller Felder (fuer Einsatzorte eigener Alarme und Ortsangaben)
-- Mittelpunkt eines Felds aus seinen Polygonpunkten (oder nil)
function FFE:feldMitte(field)
    local fid = (field.getId ~= nil and field:getId()) or field.fieldId or field.id
    local nodes = (field.getPolygonPoints ~= nil and field:getPolygonPoints()) or field.polygonPoints
    if fid == nil or type(nodes) ~= "table" or #nodes == 0 then
        return nil
    end
    local sx, sz, n = 0, 0, 0
    for _, node in ipairs(nodes) do
        local x, z
        if type(node) == "table" then
            x, z = node.x or node[1], node.z or node[2]
        else
            local wx, _, wz = getWorldTranslation(node)
            x, z = wx, wz
        end
        if x ~= nil and z ~= nil then
            sx, sz, n = sx + x, sz + z, n + 1
        end
    end
    if n == 0 then
        return nil
    end
    return fid, sx / n, sz / n
end

function FFE:getFieldCenters()
    if self.fieldCenters ~= nil and #self.fieldCenters > 0 then
        return self.fieldCenters
    end
    local candidates = {}
    if g_fieldManager ~= nil and g_fieldManager.fields ~= nil then
        for _, field in pairs(g_fieldManager.fields) do
            local id, cx, cz = self:feldMitte(field)
            if id ~= nil then
                table.insert(candidates, { name = "Feld " .. tostring(id), x = cx, z = cz })
            end
        end
    end
    self.fieldCenters = candidates
    return candidates
end

function FFE:pickLocation()
    local candidates = self:getFieldCenters()
    if #candidates > 0 then
        return candidates[math.random(1, #candidates)]
    end
    return { name = "Ortslage", x = nil, z = nil }
end

function FFE:getTimeString()
    local env = g_currentMission ~= nil and g_currentMission.environment or nil
    if env == nil or env.dayTime == nil then
        return "--:--"
    end
    local minutes = math.floor(env.dayTime / 60000)
    return string.format("%02d:%02d", math.floor(minutes / 60) % 24, minutes % 60)
end

function FFE:getDayString()
    local env = g_currentMission ~= nil and g_currentMission.environment or nil
    if env ~= nil and env.currentDay ~= nil then
        return "TAG " .. tostring(env.currentDay)
    end
    return ""
end

-- code: Stichwort oder nil (zufaellig)
-- override: { code, detail, loc = {name,x,z}, noHotspot, epScenario } fuer Einsaetze des Emergency Packs
function FFE:triggerAlarm(code, override)
    if self.alarm ~= nil then
        self:endEinsatz(true)
    end

    local s, loc, detail
    if override ~= nil then
        s = self:getStichwort(override.code) or self:getStichwort("TH1")
        loc, detail = override.loc, override.detail
    else
        s = self:pickStichwort(code)
        loc = self:pickLocation()
        detail = s.details[math.random(1, #s.details)]
    end

    self.alarm = {
        code = s.code,
        titel = s.titel,
        detail = detail,
        ort = loc.name,
        x = loc.x,
        z = loc.z,
        sound = s.sound,
        stichwort = s,
        zeit = self:getTimeString(),
        tag = self:getDayString(),
        quittiert = false,
        epScenario = override ~= nil and override.epScenario or nil,
        startTime = g_time or 0,
    }

    -- Fahrzeuge nach AAO alarmieren
    self:dispatchAlarm(self.alarm)

    table.insert(self.history, 1, self.alarm.code .. "  " .. detail)
    while #self.history > 5 do
        table.remove(self.history)
    end

    self.visible = true
    self.hideTimer = 0
    self.repeatTimer = 0
    self.repeatCount = 0

    if self.settings.resetTimeScale and g_currentMission ~= nil then
        if g_currentMission.setTimeScale ~= nil then
            g_currentMission:setTimeScale(1)
        end
    end

    self:playSound(s.sound)
    if override == nil or not override.noHotspot then
        self:createHotspot()
    end

    log("ALARM %s - %s - %s - Kraefte: %s", s.code, detail, loc.name, self.alarm.kraefte or "-")
end

function FFE:quitAlarm()
    if self.alarm == nil or self.alarm.quittiert then
        return
    end
    self.alarm.quittiert = true
    self.hideTimer = self.settings.hideAfterQuitSec * 1000
    self:stopSounds()
    log("Alarm quittiert.")
end

-- bricht den laufenden Emergency-Pack-Einsatz ab (falls verknuepft)
function FFE:abortEPScenario()
    if self.alarm == nil or self.alarm.epScenario == nil then
        return false
    end
    local scn = self.alarm.epScenario
    if type(scn.abort) == "function" then
        scn:abort()
        log("Emergency-Pack-Einsatz abgebrochen.")
    else
        log("Emergency-Pack-Einsatz kann nicht abgebrochen werden (keine abort-Funktion).")
    end
    -- diesen Einsatz nie wieder alarmieren; falls das Pack ihn nicht entfernt, raeumen wir nach
    self.epIgnored = self.epIgnored or {}
    self.epIgnored[scn] = true
    self.epAbortChecks = self.epAbortChecks or {}
    self.epAbortChecks[scn] = g_time or 0
    return ok
end

-- Einsatz abschliessen: Fahrzeuge zurueck, Wegpunkt weg, naechsten Alarm planen
function FFE:endEinsatz(silent)
    local a = self.alarm
    self.epRequest = nil
    if a ~= nil then
        self:safeCall("Einsatzende", self.finishEinsatz, a)
    end
    self:removeHotspot()
    self:stopSounds()
    self.alarm = nil
    self:scheduleNextAlarm()
    if not silent then
        log("Einsatz beendet.")
    end
end

addModEventListener(FFE)
