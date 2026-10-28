-- =============================================================================
-- FF Einsatzleitung  -  Konsolenbefehle und Diagnose
--
-- Copyright (c) 2026 Orniwat & iowi. Alle Rechte vorbehalten.
-- Weitergabe, Veraenderung oder erneutes Hochladen nur mit Erlaubnis der Autoren.
-- =============================================================================

local log = FFE.log

-- ---------------------------------------------------------------------------
-- Konsole
-- ---------------------------------------------------------------------------
function FFE:consoleAlarm(code)
    if code ~= nil and self:getStichwort(code) == nil then
        return "Unbekanntes Stichwort. Moeglich: B1 B2 B3 B_WALD BMA TH1 TH_TIER TH_VU TH_OEL"
    end
    self:triggerAlarm(code)
    return "Alarm ausgeloest: " .. (self.alarm and (self.alarm.code .. " " .. self.alarm.detail .. " / " .. self.alarm.ort) or "?")
end

function FFE:consoleEP()
    if self:requestEPScenario() then
        return "Emergency-Pack-Einsatz angefordert - der Melder geht, sobald das Pack ihn startet."
    end
    return "Emergency Pack nicht verfuegbar."
end

function FFE:consoleQuit()
    self:quitAlarm()
    return "Quittiert."
end

function FFE:consoleEnde()
    self:abortEPScenario()
    self:endEinsatz(false)
    return "Einsatz beendet."
end

function FFE:consoleStatus()
    local a = self.alarm
    local lines = {
        string.format("FF Einsatzleitung %s (%s) | %s | Ausrueckzeit %s Min | Nachbarwehr %s",
            self.VERSION, self.CHANNEL, self.settings.wehrName, tostring(self.settings.ausrueckzeitMin), self.settings.nachbarwehr and "an" or "aus"),
        string.format("Fuhrpark: %d Fahrzeuge | Wache: %s | Rueckfahrten: %d",
            #self.fleet, self.wache ~= nil and "gesetzt" or "nicht gesetzt", #self.returning),
    }
    if a ~= nil then
        table.insert(lines, string.format("Einsatz: %s %s | %s | Modus %s | %s",
            a.code, a.detail, a.ort or "?", tostring(a.mode), a.ausgerueckt and self:statusLine(a) or (a.kraefte or "")))
    else
        table.insert(lines, "Kein Einsatz.")
    end
    table.insert(lines, "EP: " .. (self:isEPActive() and self:epStateString() or "aus"))
    for _, m in ipairs(self.EMPFOHLEN) do
        table.insert(lines, string.format("%s: %s", m.name, self:isModActive(m.mod) and "aktiv" or ("fehlt - " .. m.ohne)))
    end
    for _, l in ipairs(lines) do
        log("%s", l)
    end
    return table.concat(lines, "\n")
end

function FFE:consoleEPStatus()
    local st = self:epStateString()
    log("EP-Zustand: %s", st)
    return st
end

function FFE:consolePopup(arg)
    arg = string.lower(tostring(arg or ""))
    if arg == "aus" or arg == "off" or arg == "0" then
        self.settings.suppressEPPopup = false
        self.popupHooksDisabled = true
        self:removePopupHooks()
        self.popupHooksDisabled = true
        log("Popup-Filter ausgeschaltet.")
        return "Popup-Filter aus (Popups des Emergency Packs erscheinen wieder)."
    elseif arg == "an" or arg == "on" or arg == "1" then
        self.settings.suppressEPPopup = true
        self.popupHooksDisabled = false
        self:installPopupHooks()
        return "Popup-Filter an."
    end
    return "Popup-Filter ist " .. (self.popupHooksInstalled and "an" or "aus") .. ". Benutzung: ffPopup an|aus"
end

function FFE:consoleInterval(minM, maxM)
    local a, b = tonumber(minM), tonumber(maxM)
    if a == nil or b == nil or a < 1 or b < a then
        return "Benutzung: ffInterval <minMinuten> <maxMinuten>  (z.B. ffInterval 10 30)"
    end
    self.settings.minIntervalMin = a
    self.settings.maxIntervalMin = b
    self:scheduleNextAlarm()
    return string.format("Intervall %d-%d Min gesetzt, naechster Alarm in ca. %d Min.", a, b, math.floor(self.nextAlarmInMs / 60000))
end

function FFE:consoleOn()
    self.settings.enabled = true
    self:scheduleNextAlarm()
    return "Zufallsalarme an."
end

function FFE:consoleOff()
    self.settings.enabled = false
    return "Zufallsalarme aus."
end

-- ---------------------------------------------------------------------------
-- Fuhrpark, Wache, AAO
-- ---------------------------------------------------------------------------
local function joinArgs(...)
    local t = {}
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if v ~= nil and v ~= "" then
            table.insert(t, tostring(v))
        end
    end
    if #t == 0 then
        return nil
    end
    return table.concat(t, " ")
end

function FFE:consoleFahrzeug(bez, nr, ...)
    if bez == nil then
        return "Benutzung (im Fahrzeug sitzend): ffFahrzeug <Bezeichnung> [Nr] [Funkrufname]\n"
            .. "  z.B. ffFahrzeug HLF_20 1 Florian Musterdorf 1/46-1   (Leerzeichen in der Bezeichnung als _ , - = keine Nummer)\n"
            .. "  Ohne Fahrzeug: ffNeu zeigt gekaufte Fahrzeuge, ffHinzu <ListenNr> ... fuegt sie hinzu."
    end
    if nr == "-" then
        nr = nil
    end
    local _, msg = self:registerVehicle(bez, nr, joinArgs(...))
    return msg
end

function FFE:consoleNeu()
    local list = self:getUnregisteredVehicles()
    self.lastNeuList = list
    if #list == 0 then
        return "Keine neuen Fahrzeuge - alle Fahrzeuge deines Hofs gehoeren schon zur Wache."
    end
    local lines = { "Fahrzeuge deines Hofs, noch nicht bei der Wache:" }
    for i, n in ipairs(list) do
        table.insert(lines, string.format("%3d  %-34s %s", i, n.name, n.vorschlag and ("-> Vorschlag " .. n.vorschlag) or ""))
        if i >= 40 then
            table.insert(lines, "  ...")
            break
        end
    end
    table.insert(lines, "Hinzufuegen: ffHinzu <Nr> [Bezeichnung] [FzgNr] [Funkrufname]  (ohne Bezeichnung = Vorschlag)")
    for _, l in ipairs(lines) do
        log("%s", l)
    end
    return table.concat(lines, "\n")
end

function FFE:consoleHinzu(idx, bez, nr, ...)
    local list = self.lastNeuList or self:getUnregisteredVehicles()
    local n = list[tonumber(idx or "")]
    if n == nil then
        return "Benutzung: ffNeu, dann ffHinzu <Nr aus der Liste> [Bezeichnung] [FzgNr] [Funkrufname]"
    end
    if bez == "-" then
        bez = nil
    end
    if nr == "-" then
        nr = nil
    end
    local ok, msg = self:registerVehicle(bez, nr, joinArgs(...), n.vehicle)
    if ok then
        self.lastNeuList = nil
    end
    return msg
end

function FFE:consoleFahrzeugWeg(typ, nr)
    local _, msg = self:unregisterVehicle(typ, nr)
    return msg
end

function FFE:consoleFuhrpark()
    if #self.fleet == 0 then
        return "Die Wache hat noch keine Fahrzeuge. Neue Fahrzeuge: ffNeu, im Fahrzeug: ffFahrzeug <Bezeichnung>."
    end
    local lines = {}
    for _, e in ipairs(self.fleet) do
        local status = e.busy and "im Einsatz" or "frei"
        table.insert(lines, string.format("%-14s %-6s %-22s %-10s %s%s%s", self:unitLabel(e), e.klasse, e.call or "", status,
            e.name or "?", e.vehicle == nil and " [nicht gefunden]" or "", e.spot ~= nil and " [Stellplatz]" or ""))
    end
    local missing = {}
    for _, k in ipairs(self.FAHRZEUGTYPEN) do
        local used = false
        for _, row in pairs(self.aao) do
            if row[k] ~= nil then used = true end
        end
        if used and not self:hasKlasse(k) then
            table.insert(missing, k)
        end
    end
    if #missing > 0 then
        table.insert(lines, "Fehlt fuer die AAO (stellt die Nachbarwehr): " .. table.concat(missing, " "))
    end
    for _, l in ipairs(lines) do
        log("%s", l)
    end
    return table.concat(lines, "\n")
end

function FFE:consoleWache()
    local _, msg = self:setWacheHere()
    return msg
end

function FFE:consoleStellplatz()
    local _, msg = self:setStellplatzHere()
    return msg
end

function FFE:consoleAAO(code, typ, n)
    if code == nil then
        return "Benutzung: ffAAO <Stichwort> <Typ> <Anzahl>  (Leerzeichen als _: ffAAO B_WALD TLF-W 1, 0 = entfernen). Liste: ffAAOListe"
    end
    local _, msg = self:setAAO(code, typ, n)
    return msg
end

function FFE:consoleAAOListe()
    local lines = {}
    for _, s in ipairs(self.STICHWORTE) do
        table.insert(lines, string.format("%-8s %s", s.code, self:aaoRowString(s.code)))
    end
    for _, l in ipairs(lines) do
        log("%s", l)
    end
    return table.concat(lines, "\n")
end

function FFE:consoleFrei()
    return self:alleFreisetzen() .. " Fahrzeug(e) freigesetzt."
end

function FFE:consoleAAOStandard()
    self:resetAAO()
    return "AAO auf Standard zurueckgesetzt."
end

function FFE:consoleAusrueckzeit(min)
    local m = tonumber(min)
    if m == nil or m < 0 then
        return "Benutzung: ffAusrueckzeit <Minuten>  (aktuell " .. tostring(self.settings.ausrueckzeitMin) .. ")"
    end
    self.settings.ausrueckzeitMin = m
    return string.format("Ausrueckzeit %s Minuten.", tostring(m))
end

function FFE:consoleName(...)
    local name = joinArgs(...)
    if name == nil then
        return "Benutzung: ffName <Name der Wehr>  (aktuell " .. self.settings.wehrName .. ")"
    end
    self.settings.wehrName = name
    return "Name der Wehr: " .. name
end

function FFE:consoleNachbarwehr(arg, code)
    arg = string.lower(tostring(arg or ""))
    if code ~= nil then
        local st = self:getStichwort(code)
        if st == nil or (arg ~= "an" and arg ~= "aus") then
            return "Benutzung: ffNachbarwehr an|aus [Stichwort]"
        end
        if arg == "an" then
            self.aaoNachbar[st.code] = nil
        else
            self.aaoNachbar[st.code] = false
        end
        return string.format("Nachbarwehr bei %s %s.", st.code, arg)
    end
    if arg == "an" or arg == "aus" then
        self.settings.nachbarwehr = arg == "an"
    end
    return "Nachbarwehr allgemein " .. (self.settings.nachbarwehr and "an" or "aus") .. " (ffNachbarwehr an|aus [Stichwort])"
end

function FFE:consoleSpeichern()
    self:saveFleet()
    return "Fuhrpark gespeichert (wird ausserdem bei jedem Spielstand-Speichern gesichert)."
end

-- ---------------------------------------------------------------------------
-- An-/Abmelden der Befehle
-- ---------------------------------------------------------------------------
FFE.CONSOLE = {
    { "ffAlarm",        "Probealarm [Stichwort, z.B. B3 oder B_WALD]", "consoleAlarm" },
    { "ffEP",           "echten Emergency-Pack-Einsatz anfordern", "consoleEP" },
    { "ffQuit",         "Alarm quittieren", "consoleQuit" },
    { "ffEnde",         "Einsatz beenden", "consoleEnde" },
    { "ffStatus",       "Status anzeigen", "consoleStatus" },
    { "ffFrei",         "festgefahrene KI-Fahrzeuge sofort ans Ziel setzen", "consoleFrei" },
    { "ffNeu",          "gekaufte Fahrzeuge zeigen, die noch nicht zur Wache gehoeren", "consoleNeu" },
    { "ffHinzu",        "Fahrzeug aus ffNeu hinzufuegen: <Nr> [Bezeichnung] [FzgNr] [Funkrufname]", "consoleHinzu" },
    { "ffFahrzeug",     "Fahrzeug hinzufuegen (im Fahrzeug): <Bezeichnung> [Nr] [Funkrufname]", "consoleFahrzeug" },
    { "ffFahrzeugWeg",  "Fahrzeug von der Wache nehmen (im Fahrzeug oder <Klasse> <Nr>)", "consoleFahrzeugWeg" },
    { "ffFuhrpark",     "Fuhrpark auflisten", "consoleFuhrpark" },
    { "ffWache",        "Wache auf deine Position setzen", "consoleWache" },
    { "ffStellplatz",   "Stellplatz des Fahrzeugs speichern (im Fahrzeug)", "consoleStellplatz" },
    { "ffAAO",          "AAO setzen: <Stichwort> <Klasse> <Anzahl>", "consoleAAO" },
    { "ffAAOListe",     "AAO anzeigen", "consoleAAOListe" },
    { "ffAAOStandard",  "AAO auf Standard zuruecksetzen", "consoleAAOStandard" },
    { "ffAusrueckzeit", "Ausrueckzeit in Minuten", "consoleAusrueckzeit" },
    { "ffName",         "Name der Wehr", "consoleName" },
    { "ffNachbarwehr",  "Nachbarwehr an/aus [Stichwort]", "consoleNachbarwehr" },
    { "ffSpeichern",    "Fuhrpark sofort speichern", "consoleSpeichern" },
    { "ffInterval",     "Intervall eigener Zufallsalarme <min> <max>", "consoleInterval" },
    { "ffAn",           "eigene Zufallsalarme an", "consoleOn" },
    { "ffAus",          "eigene Zufallsalarme aus", "consoleOff" },
    { "ffPopup",        "Ja/Nein-Abfrage des Emergency Packs automatisch bestaetigen an/aus", "consolePopup" },
    { "ffEPStatus",     "Zustand des Emergency Packs ins Log", "consoleEPStatus" },
    { "ffScan",         "Diagnose: Emergency Pack untersuchen", "consoleScan" },
    { "ffScanRP",       "Diagnose: RolePlay-Instanz untersuchen", "consoleScanRP" },
}

function FFE:registerConsoleCommands()
    for _, c in ipairs(self.CONSOLE) do
        if addConsoleCommand ~= nil then
            addConsoleCommand(c[1], "FF Einsatzleitung: " .. c[2], c[3], self)
        end
    end
end

function FFE:unregisterConsoleCommands()
    for _, c in ipairs(self.CONSOLE) do
        if removeConsoleCommand ~= nil then
            removeConsoleCommand(c[1])
        end
    end
end

-- ---------------------------------------------------------------------------
-- Diagnose: Was stellt das Emergency Pack im laufenden Spiel bereit?
-- Schreibt alles mit Prefix [FFE-SCAN] ins Log.
-- ---------------------------------------------------------------------------
local SCAN_PATTERNS = { "emergency", "scenario", "pager", "rescue", "fire", "firefight", "creative" }

local function matchesScan(name)
    local n = string.lower(tostring(name))
    for _, p in ipairs(SCAN_PATTERNS) do
        if string.find(n, p, 1, true) then
            return true
        end
    end
    return false
end

local function scanLog(fmt, ...)
    print("[FFE-SCAN] " .. string.format(fmt, ...))
end

local function listMembers(prefix, tbl, depth, seen, budget)
    if type(tbl) ~= "table" or seen[tbl] or depth < 0 or budget.n <= 0 then
        return
    end
    seen[tbl] = true
    local keys = {}
    for k, _ in pairs(tbl) do
        table.insert(keys, tostring(k))
    end
    table.sort(keys)
    for _, k in ipairs(keys) do
        if budget.n <= 0 then
            scanLog("... (Limit erreicht)")
            return
        end
        local v = rawget(tbl, k)
        do
            budget.n = budget.n - 1
            scanLog("%s.%s : %s", prefix, k, type(v))
            if type(v) == "table" and depth > 0 then
                listMembers(prefix .. "." .. k, v, depth - 1, seen, budget)
            end
        end
    end
    -- Metatable (Klassenmethoden)
    local mt = getmetatable(tbl)
    if mt ~= nil and type(mt.__index) == "table" and not seen[mt.__index] then
        listMembers(prefix .. "<mt>", mt.__index, depth - 1, seen, budget)
    end
end

function FFE:consoleScan()
    local seen = {}
    local found = 0
    scanLog("===== Scan Start =====")

    -- 1) aktive Mods / DLCs
    if g_modManager ~= nil and g_modManager.getActiveMods ~= nil then
        for _, mod in ipairs(g_modManager:getActiveMods()) do
            if matchesScan(mod.modName) then
                scanLog("Aktiver Mod/DLC: %s (%s)", tostring(mod.modName), tostring(mod.modDir))
            end
        end
    end

    -- 2) Umgebung des Emergency Packs gezielt untersuchen
    local realG = _G
    local gmt = getmetatable(_G)
    if gmt ~= nil and type(gmt.__index) == "table" then
        realG = gmt.__index
    end
    local ep = rawget(_G, "pdlc_emergencyPack") or realG["pdlc_emergencyPack"]
    if type(ep) ~= "table" then
        scanLog("pdlc_emergencyPack nicht gefunden.")
    else
        -- A) alle eigenen Namen des Packs (ohne Spiel-Standardnamen)
        local own = {}
        for k, v in pairs(ep) do
            if realG[k] ~= v then
                table.insert(own, tostring(k))
            end
        end
        table.sort(own)
        scanLog("EP eigene Namen: %d", #own)
        for _, k in ipairs(own) do
            scanLog("EP %s : %s", k, type(ep[k]))
        end

        -- B) interessante Klassen/Instanzen im Detail
        local DETAIL = { "scenario", "pager", "manager", "mission", "trigger", "alarm", "incident", "spawn", "setting", "emergencypack" }
        local function wantDetail(name)
            local n = string.lower(name)
            if string.sub(n, 1, 2) == "g_" then
                return true
            end
            for _, p in ipairs(DETAIL) do
                if string.find(n, p, 1, true) then
                    return true
                end
            end
            return false
        end
        for _, k in ipairs(own) do
            local v = ep[k]
            if type(v) == "table" and wantDetail(k) then
                found = found + 1
                scanLog("--- Detail %s ---", k)
                listMembers("EP." .. k, v, 0, seen, { n = 250 })
            end
        end

        -- C) Instanzen von Pack-Klassen in g_currentMission finden
        local classSet = {}
        for _, k in ipairs(own) do
            if type(ep[k]) == "table" then
                classSet[ep[k]] = k
            end
        end
        if g_currentMission ~= nil then
            for k, v in pairs(g_currentMission) do
                if type(v) == "table" then
                    local vmt = getmetatable(v)
                    local cls = vmt ~= nil and (classSet[vmt] or classSet[vmt.__index]) or nil
                    if cls ~= nil then
                        found = found + 1
                        scanLog("g_currentMission.%s ist Instanz von EP.%s", tostring(k), cls)
                    end
                end
            end
        end
    end

    scanLog("===== Scan Ende (%d Treffer) =====", found)
    return string.format("Scan fertig: %d Treffer, Details im log.txt unter [FFE-SCAN].", found)
end

-- Untersucht die aktive Instanz g_currentMission.rolePlay (Emergency Pack)
local function dumpValue(v)
    local t = type(v)
    if t == "number" or t == "string" or t == "boolean" then
        return t .. " = " .. tostring(v)
    elseif t == "table" then
        local n = 0
        for _ in pairs(v) do
            n = n + 1
            if n > 999 then break end
        end
        return "table (" .. n .. " Eintraege)"
    end
    return t
end

function FFE:consoleScanRP()
    local rp = g_currentMission ~= nil and g_currentMission.rolePlay or nil
    if rp == nil then
        return "g_currentMission.rolePlay nicht gefunden."
    end
    scanLog("===== RolePlay Start =====")
    local keys = {}
    for k, _ in pairs(rp) do
        table.insert(keys, tostring(k))
    end
    table.sort(keys)
    for _, k in ipairs(keys) do
        local v = rp[k]
        scanLog("RP.%s : %s", k, dumpValue(v))
        -- eine Ebene tiefer bei Tabellen mit wenigen Eintraegen
        if type(v) == "table" then
            local n = 0
            for k2, v2 in pairs(v) do
                n = n + 1
                if n > 40 then
                    scanLog("RP.%s ... weitere", k)
                    break
                end
                scanLog("RP.%s.%s : %s", k, tostring(k2), dumpValue(v2))
            end
        end
    end
    -- Klassenmethoden
    local mt = getmetatable(rp)
    local depth = 0
    while mt ~= nil and type(mt.__index) == "table" and depth < 4 do
        local cls = mt.__index
        local m = {}
        for k, v in pairs(cls) do
            if type(v) == "function" then
                table.insert(m, tostring(k))
            end
        end
        table.sort(m)
        scanLog("RP-Klasse(Ebene %d) Methoden: %s", depth, table.concat(m, " "))
        mt = getmetatable(cls)
        depth = depth + 1
    end
    scanLog("===== RolePlay Ende =====")
    return "RolePlay-Scan fertig, Details im log.txt unter [FFE-SCAN]."
end
