-- =============================================================================
-- FF Einsatzleitung  -  Fuhrpark, Wache, Alarm- und Ausrueckeordnung (AAO)
--
-- Gespeichert wird in <Spielstand>/ffEinsatzleitung.xml, immer wenn das Spiel speichert.
-- Fahrzeuge werden ueber ihre uniqueId wiedererkannt.
--
-- Copyright (c) 2026 Orniwat & iowi. Alle Rechte vorbehalten.
-- Weitergabe, Veraenderung oder erneutes Hochladen nur mit Erlaubnis der Autoren.
-- =============================================================================

local log = FFE.log

-- Fahrzeugklassen. Nach der Klasse richtet sich die AAO; die Reihenfolge ist die
-- Anzeige-Reihenfolge auf dem Melder.
FFE.FAHRZEUGTYPEN = { "KDOW", "ELW", "HLF", "LF", "TSF", "TLF", "TLF-W", "DLK", "RW", "GW-L", "GW-T", "SW", "WLF", "MTW" }

-- Bezeichnungen zur Auswahl (Bezeichnung -> Klasse). Freie Bezeichnungen gehen auch,
-- die Klasse wird dann aus dem ersten Wort abgeleitet.
FFE.FAHRZEUGKATALOG = {
    { "KdoW", "KDOW" }, { "ELW 1", "ELW" }, { "ELW 2", "ELW" },
    { "HLF 10", "HLF" }, { "HLF 20", "HLF" }, { "HLF 20/16", "HLF" },
    { "LF 8/6", "LF" }, { "LF 10", "LF" }, { "LF 16/12", "LF" }, { "LF 20", "LF" }, { "LF 20 KatS", "LF" }, { "MLF", "LF" },
    { "TSF", "TSF" }, { "TSF-W", "TSF" },
    { "TLF 3000", "TLF" }, { "TLF 4000", "TLF" }, { "TLF 16/25", "TLF" }, { "TLF 20/40", "TLF" },
    { "TLF-W", "TLF-W" }, { "TLF 3000 Wald", "TLF-W" },
    { "DLK 23-12", "DLK" }, { "DLA(K) 18-12", "DLK" },
    { "RW", "RW" }, { "RW 2", "RW" },
    { "GW-L 1", "GW-L" }, { "GW-L 2", "GW-L" }, { "GW-T", "GW-T" },
    { "SW 2000", "SW" }, { "WLF", "WLF" }, { "MTW", "MTW" },
}

FFE.TYP_ALIAS = {
    GWT = "GW-T", GWL = "GW-L", TLFW = "TLF-W", DL = "DLK", DLA = "DLK", DLAK = "DLK",
    KDO = "KDOW", MLF = "LF", TSFW = "TSF", SW2000 = "SW",
}

-- Vorschlaege fuer bekannte Fahrzeuge (Suchwort im Fahrzeugnamen -> Bezeichnung)
FFE.FAHRZEUG_VORSCHLAEGE = {
    { "hlf", "HLF 20" }, { "tlf", "TLF 3000" }, { "lf 8", "LF 8/6" }, { "lf8", "LF 8/6" }, { "lf 10", "LF 10" },
    { "lf 20", "LF 20" }, { "dlk", "DLK 23-12" }, { "drehleiter", "DLK 23-12" }, { "turntable", "DLK 23-12" },
    { "elw", "ELW 1" }, { "kdow", "KdoW" }, { "mtw", "MTW" }, { "rüstwagen", "RW" }, { "ruestwagen", "RW" },
    { "gw-l", "GW-L 2" }, { "schlauch", "SW 2000" }, { "hose", "SW 2000" },
}

-- Standard-AAO: Stichwort -> { Klasse = Anzahl }
FFE.AAO_STANDARD = {
    ["B1"]      = { HLF = 1 },
    ["B2"]      = { ELW = 1, HLF = 1, LF = 1, ["GW-T"] = 1 },
    ["B3"]      = { ELW = 1, HLF = 2, LF = 1, DLK = 1, ["GW-T"] = 1, SW = 1 },
    ["B WALD"]  = { ELW = 1, LF = 1, ["TLF-W"] = 1, ["GW-T"] = 1 },
    ["BMA"]     = { ELW = 1, HLF = 1, DLK = 1 },
    ["TH1"]     = { HLF = 1 },
    ["TH TIER"] = { HLF = 1, DLK = 1 },
    ["TH VU"]   = { ELW = 1, HLF = 1, RW = 1 },
    ["TH OEL"]  = { HLF = 1 },
}

local function copyAAO(src)
    local t = {}
    for code, row in pairs(src) do
        t[code] = {}
        for typ, n in pairs(row) do
            t[code][typ] = n
        end
    end
    return t
end

function FFE:initFleet()
    self.fleet = {}               -- { key, bez, klasse, nr, call, name, spot = {x,y,z,ry}, vehicle, busy }
    self.wache = nil              -- { x, z }
    self.aao = copyAAO(self.AAO_STANDARD)
    self.aaoNachbar = {}          -- Stichwort -> false, wenn dort keine Nachbarwehr kommen soll
    self.fleetLoaded = false
    self.fleetResolveTimer = 0
end

function FFE:resetAAO()
    self.aao = copyAAO(self.AAO_STANDARD)
    self.aaoNachbar = {}
end

-- Klasse zu einer Klassen-Angabe ("hlf", "GWT", "HLF-20") oder nil
function FFE:normTyp(t)
    if t == nil then
        return nil
    end
    local u = string.upper(tostring(t))
    local compact = string.gsub(u, "[%s%-_/]", "")
    return self.TYP_ALIAS[compact] or self.TYP_ALIAS[u] or u
end

-- Klasse zu einer Bezeichnung ("HLF 20" -> "HLF", "TLF 3000 Wald" -> "TLF-W")
function FFE:klasseFor(bez)
    local b = string.upper(tostring(bez or ""))
    for _, k in ipairs(self.FAHRZEUGKATALOG) do
        if string.upper(k[1]) == b then
            return k[2]
        end
    end
    local first = string.match(b, "^([%a%-]+)") or b
    local norm = self:normTyp(first)
    for _, t in ipairs(self.FAHRZEUGTYPEN) do
        if t == norm then
            return t
        end
    end
    return norm
end

function FFE:klasseOk(k)
    return k ~= nil and k ~= ""
end

local function typOrder(typ)
    for i, t in ipairs(FFE.FAHRZEUGTYPEN) do
        if t == typ then
            return i
        end
    end
    return 99
end

function FFE:nachbarwehrFor(code)
    if not self.settings.nachbarwehr then
        return false
    end
    return self.aaoNachbar[code] ~= false
end

-- ---------------------------------------------------------------------------
-- Fahrzeuge und Spieler
-- ---------------------------------------------------------------------------
function FFE:getAllVehicles()
    local m = g_currentMission
    if m == nil then
        return {}
    end
    if m.vehicleSystem ~= nil and type(m.vehicleSystem.vehicles) == "table" then
        return m.vehicleSystem.vehicles
    end
    return m.vehicles or {}
end

function FFE:getVehicleKey(v)
    local key = nil
    if v.getUniqueId ~= nil then
        key = v:getUniqueId()
    end
    if key == nil then
        key = v.uniqueId
    end
    if key ~= nil then
        return tostring(key)
    end
    return nil
end

function FFE:getVehicleName(v)
    local name = nil
    if v.getFullName ~= nil then
        name = v:getFullName()
    elseif v.getName ~= nil then
        name = v:getName()
    end
    return name or "Fahrzeug"
end

function FFE:getPlayerVehicle()
    local v = nil
    if g_localPlayer ~= nil and g_localPlayer.getCurrentVehicle ~= nil then
        v = g_localPlayer:getCurrentVehicle()
    end
    if v == nil and g_currentMission ~= nil then
        v = g_currentMission.controlledVehicle
    end
    return v
end

function FFE:getPlayerPosition()
    local x, z = nil, nil
    local v = self:getPlayerVehicle()
    if v ~= nil and v.rootNode ~= nil then
        local wx, _, wz = getWorldTranslation(v.rootNode)
        x, z = wx, wz
        if x ~= nil then
            return x, z
        end
    end
    if g_localPlayer ~= nil then
        if g_localPlayer.getPosition ~= nil then
            local px, _, pz = g_localPlayer:getPosition()
            x, z = px, pz
        elseif g_localPlayer.rootNode ~= nil then
            local px, _, pz = getWorldTranslation(g_localPlayer.rootNode)
            x, z = px, pz
        end
    end
    if x == nil and g_currentMission ~= nil and g_currentMission.player ~= nil and g_currentMission.player.rootNode ~= nil then
        local px, _, pz = getWorldTranslation(g_currentMission.player.rootNode)
        x, z = px, pz
    end
    return x, z
end

-- "HLF 20 /1" fuer Listen, "HLF1" fuer den Melder
function FFE:unitLabel(e)
    if e.nr ~= nil and e.nr ~= "" then
        return (e.bez or e.klasse) .. " /" .. e.nr
    end
    return e.bez or e.klasse
end

function FFE:unitShort(e)
    return (e.klasse or "?") .. (e.nr or "")
end

function FFE:findFleetEntryByVehicle(v)
    if v == nil or not self:feature("fuhrpark") then
        return nil
    end
    for _, e in ipairs(self.fleet) do
        if e.vehicle == v then
            return e
        end
    end
    return nil
end

function FFE:findFleetEntry(typ, nr)
    local k = self:klasseFor(typ)
    for _, e in ipairs(self.fleet) do
        if (e.klasse == k or string.upper(e.bez or "") == string.upper(tostring(typ))) and (nr == nil or tostring(e.nr or "") == tostring(nr)) then
            return e
        end
    end
    return nil
end

-- naechstes freies Fahrzeug eines Typs (fuer die Alarmierung)
function FFE:findFreeFleetUnit(typ)
    if not self:feature("fuhrpark") then
        return nil       -- Grundversion: alles faehrt die Nachbarwehr
    end
    for _, e in ipairs(self.fleet) do
        if e.klasse == typ and not e.busy then
            return e
        end
    end
    return nil
end

local function sortFleet(fleet)
    table.sort(fleet, function(a, b)
        local oa, ob = typOrder(a.klasse), typOrder(b.klasse)
        if oa ~= ob then
            return oa < ob
        end
        if a.klasse ~= b.klasse then
            return a.klasse < b.klasse
        end
        return (tonumber(a.nr) or 0) < (tonumber(b.nr) or 0)
    end)
end

-- Vorschlag fuer die Bezeichnung anhand des Fahrzeugnamens (oder nil)
function FFE:suggestBezeichnung(v)
    local name = string.lower(self:getVehicleName(v))
    name = name .. " " .. string.lower(tostring(v.configFileName or ""))
    for _, s in ipairs(self.FAHRZEUG_VORSCHLAEGE) do
        if string.find(name, s[1], 1, true) then
            return s[2]
        end
    end
    return nil
end

function FFE:getPlayerFarmId()
    if g_currentMission ~= nil and g_currentMission.getFarmId ~= nil then
        return g_currentMission:getFarmId() or 1
    end
    return 1
end

-- Fahrzeuge deines Hofs, die noch nicht zur Wache gehoeren (bekannte Feuerwehrautos zuerst)
function FFE:getUnregisteredVehicles()
    local farmId = self:getPlayerFarmId()
    local list = {}
    for _, v in pairs(self:getAllVehicles()) do
        local own = true
        if v.getOwnerFarmId ~= nil then
            own = v:getOwnerFarmId() == farmId
        end
        local key = self:getVehicleKey(v)
        if own and key ~= nil then
            local known = false
            for _, e in ipairs(self.fleet) do
                if e.key == key then
                    known = true
                end
            end
            if not known then
                table.insert(list, { vehicle = v, key = key, name = self:getVehicleName(v), vorschlag = self:suggestBezeichnung(v) })
            end
        end
    end
    table.sort(list, function(a, b)
        if (a.vorschlag ~= nil) ~= (b.vorschlag ~= nil) then
            return a.vorschlag ~= nil
        end
        return a.name < b.name
    end)
    return list
end

-- Fahrzeug als <Bezeichnung> [Nr] [Funkrufname] zur Wache hinzufuegen.
-- vehicle = nil: das Fahrzeug, in dem der Spieler sitzt
function FFE:registerVehicle(bez, nr, call, vehicle)
    local v = vehicle or self:getPlayerVehicle()
    if v == nil then
        return false, "Setz dich in das Fahrzeug oder waehle es aus der Liste (ffNeu)."
    end
    local key = self:getVehicleKey(v)
    if key == nil then
        return false, "Dieses Fahrzeug hat keine eindeutige Kennung und kann nicht angemeldet werden."
    end
    bez = bez or self:suggestBezeichnung(v)
    if bez == nil or bez == "" then
        return false, "Bitte eine Bezeichnung angeben, z.B. HLF_20."
    end
    bez = string.gsub(bez, "_", " ")
    local e = nil
    for _, f in ipairs(self.fleet) do
        if f.key == key then
            e = f
        end
    end
    if e == nil then
        e = { key = key }
        table.insert(self.fleet, e)
    end
    e.bez = bez
    e.klasse = self:klasseFor(bez)
    e.nr = nr
    e.call = call
    e.vehicle = v
    e.name = self:getVehicleName(v)
    sortFleet(self.fleet)
    log("Zur Wache hinzugefuegt: %s (Klasse %s, %s) %s", self:unitLabel(e), e.klasse, e.name, call or "")
    return true, string.format("%s (Klasse %s) zur Wache hinzugefügt.", self:unitLabel(e), e.klasse)
end

function FFE:unregisterVehicle(typ, nr)
    local e
    if typ == nil then
        e = self:findFleetEntryByVehicle(self:getPlayerVehicle())
    else
        e = self:findFleetEntry(typ, nr)
    end
    if e == nil then
        return false, "Fahrzeug nicht im Fuhrpark gefunden."
    end
    for i, f in ipairs(self.fleet) do
        if f == e then
            table.remove(self.fleet, i)
            break
        end
    end
    return true, self:unitLabel(e) .. " aus dem Fuhrpark entfernt."
end

function FFE:setWacheHere()
    local x, z = self:getPlayerPosition()
    if x == nil then
        return false, "Position nicht ermittelbar."
    end
    self.wache = { x = x, z = z }
    return true, string.format("Wache gesetzt (%.0f / %.0f).", x, z)
end

function FFE:sortFleetEntries()
    sortFleet(self.fleet)
end

-- Stellplatz = aktuelle Position des Fahrzeugs (Spieler muss nicht drinsitzen)
function FFE:setStellplatzFor(e)
    local v = e ~= nil and e.vehicle or nil
    if v == nil or v.rootNode == nil then
        return false
    end
    local x, y, z = getWorldTranslation(v.rootNode)
    local ry = 0
    if getWorldRotation ~= nil then
        local _, wry, _ = getWorldRotation(v.rootNode)
        ry = wry or 0
    end
    e.spot = { x = x, y = y, z = z, ry = ry }
    return true
end

function FFE:setStellplatzHere()
    local v = self:getPlayerVehicle()
    local e = self:findFleetEntryByVehicle(v)
    if e == nil then
        return false, "Setz dich in ein angemeldetes Fahrzeug und park es auf seinem Stellplatz."
    end
    if not self:setStellplatzFor(e) then
        return false, "Stellplatz konnte nicht gelesen werden."
    end
    return true, "Stellplatz fuer " .. self:unitLabel(e) .. " gespeichert."
end

function FFE:setAAO(code, typ, n)
    local s = self:getStichwort(code)
    if s == nil then
        return false, "Unbekanntes Stichwort: " .. tostring(code)
    end
    typ = self:klasseFor(typ)
    n = tonumber(n)
    if typ == nil or n == nil or n < 0 then
        return false, "Benutzung: ffAAO <Stichwort> <Klasse> <Anzahl>  (z.B. ffAAO B3 HLF 2, Leerzeichen als _ : B_WALD)"
    end
    self.aao[s.code] = self.aao[s.code] or {}
    if n == 0 then
        self.aao[s.code][typ] = nil
    else
        self.aao[s.code][typ] = math.floor(n)
    end
    return true, string.format("AAO %s: %s = %d", s.code, typ, n)
end

function FFE:aaoRowString(code)
    local row = self.aao[code] or {}
    local parts = {}
    local types = {}
    for typ, _ in pairs(row) do
        table.insert(types, typ)
    end
    table.sort(types, function(a, b) return typOrder(a) < typOrder(b) end)
    for _, typ in ipairs(types) do
        local n = row[typ]
        table.insert(parts, n > 1 and (n .. "x " .. typ) or typ)
    end
    local text = table.concat(parts, ", ")
    if not self:nachbarwehrFor(code) then
        text = text .. "  [ohne Nachbarwehr]"
    end
    return text
end

-- Klassen, die im Fuhrpark vorhanden sind (fuer die Anzeige "fehlt")
function FFE:hasKlasse(k)
    for _, e in ipairs(self.fleet) do
        if e.klasse == k then
            return true
        end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Laufend: Laden nach Spielstart, Fahrzeuge zuordnen
-- ---------------------------------------------------------------------------
function FFE:updateFleet(dt)
    if not self.fleetLoaded then
        if g_currentMission ~= nil and g_currentMission.missionInfo ~= nil then
            self.fleetLoaded = true
            self:loadFleet()
        end
        return
    end
    self.fleetResolveTimer = self.fleetResolveTimer + dt
    if self.fleetResolveTimer < 5000 then
        return
    end
    self.fleetResolveTimer = 0

    local open = false
    for _, e in ipairs(self.fleet) do
        if e.vehicle ~= nil and (e.vehicle.isDeleted or e.vehicle.rootNode == nil) then
            e.vehicle = nil
        end
        if e.vehicle == nil then
            open = true
        end
    end
    if not open then
        return
    end
    for _, v in pairs(self:getAllVehicles()) do
        local key = self:getVehicleKey(v)
        if key ~= nil then
            for _, e in ipairs(self.fleet) do
                if e.vehicle == nil and e.key == key then
                    e.vehicle = v
                    e.name = self:getVehicleName(v)
                end
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Speichern / Laden
-- ---------------------------------------------------------------------------
function FFE:getSaveFile(dir)
    dir = dir or (g_currentMission ~= nil and g_currentMission.missionInfo ~= nil and g_currentMission.missionInfo.savegameDirectory)
    if dir == nil or dir == "" then
        return nil
    end
    return dir .. "/ffEinsatzleitung.xml"
end

function FFE:installSaveHook()
    if FFE.saveHookInstalled or FSCareerMissionInfo == nil or FSCareerMissionInfo.saveToXMLFile == nil then
        return
    end
    FFE.saveHookInstalled = true
    FSCareerMissionInfo.saveToXMLFile = Utils.appendedFunction(FSCareerMissionInfo.saveToXMLFile, function(missionInfo)
        if FFE.isLoaded then
            FFE:safeCall("Speichern", FFE.saveFleet, missionInfo.savegameDirectory)
        end
    end)
end

function FFE:saveFleet(dir)
    local path = self:getSaveFile(dir)
    if path == nil then
        return
    end
    local xml = createXMLFile("ffEinsatzleitung", path, "ffEinsatzleitung")
    if xml == nil or xml == 0 then
        log("Konnte %s nicht anlegen.", path)
        return
    end
    setXMLString(xml, "ffEinsatzleitung#version", self.VERSION)
    setXMLString(xml, "ffEinsatzleitung.settings#wehrName", self.settings.wehrName)
    setXMLFloat(xml, "ffEinsatzleitung.settings#ausrueckzeitMin", self.settings.ausrueckzeitMin)
    setXMLBool(xml, "ffEinsatzleitung.settings#nachbarwehr", self.settings.nachbarwehr)
    setXMLBool(xml, "ffEinsatzleitung.settings#eigeneEinsaetze", self.settings.enabled)
    setXMLBool(xml, "ffEinsatzleitung.settings#kiVerguetung", self.settings.kiVerguetung)
    setXMLBool(xml, "ffEinsatzleitung.settings#echtAusruecken", self.settings.echtAusruecken)
    if self.wache ~= nil then
        setXMLFloat(xml, "ffEinsatzleitung.wache#x", self.wache.x)
        setXMLFloat(xml, "ffEinsatzleitung.wache#z", self.wache.z)
    end
    for i, e in ipairs(self.fleet) do
        local k = string.format("ffEinsatzleitung.fuhrpark.fahrzeug(%d)", i - 1)
        setXMLString(xml, k .. "#key", e.key)
        setXMLString(xml, k .. "#bezeichnung", e.bez)
        setXMLString(xml, k .. "#klasse", e.klasse)
        setXMLString(xml, k .. "#nr", tostring(e.nr or ""))
        setXMLString(xml, k .. "#funkrufname", e.call or "")
        setXMLString(xml, k .. "#name", e.name or "")
        if e.spot ~= nil then
            setXMLFloat(xml, k .. ".stellplatz#x", e.spot.x)
            setXMLFloat(xml, k .. ".stellplatz#y", e.spot.y)
            setXMLFloat(xml, k .. ".stellplatz#z", e.spot.z)
            setXMLFloat(xml, k .. ".stellplatz#ry", e.spot.ry)
        end
    end
    local i = 0
    for code, row in pairs(self.aao) do
        for typ, n in pairs(row) do
            local k = string.format("ffEinsatzleitung.aao.eintrag(%d)", i)
            setXMLString(xml, k .. "#stichwort", code)
            setXMLString(xml, k .. "#typ", typ)
            setXMLInt(xml, k .. "#anzahl", n)
            i = i + 1
        end
    end
    i = 0
    for code, v in pairs(self.aaoNachbar) do
        if v == false then
            setXMLString(xml, string.format("ffEinsatzleitung.aao.ohneNachbarwehr(%d)#stichwort", i), code)
            i = i + 1
        end
    end
    setXMLBool(xml, "ffEinsatzleitung.aao#gespeichert", true)
    saveXMLFile(xml)
    delete(xml)
    log("Fuhrpark gespeichert (%d Fahrzeuge).", #self.fleet)
end

function FFE:loadFleet()
    local path = self:getSaveFile()
    if path == nil or not fileExists(path) then
        log("Kein gespeicherter Fuhrpark - Standard-AAO aktiv.")
        return
    end
    local xml = loadXMLFile("ffEinsatzleitung", path)
    if xml == nil or xml == 0 then
        return
    end
    self.settings.wehrName = getXMLString(xml, "ffEinsatzleitung.settings#wehrName") or self.settings.wehrName
    self.settings.ausrueckzeitMin = getXMLFloat(xml, "ffEinsatzleitung.settings#ausrueckzeitMin") or self.settings.ausrueckzeitMin
    local nb = getXMLBool(xml, "ffEinsatzleitung.settings#nachbarwehr")
    if nb ~= nil then
        self.settings.nachbarwehr = nb
    end
    for key, field in pairs({ eigeneEinsaetze = "enabled", kiVerguetung = "kiVerguetung", echtAusruecken = "echtAusruecken" }) do
        local v = getXMLBool(xml, "ffEinsatzleitung.settings#" .. key)
        if v ~= nil then
            self.settings[field] = v
        end
    end
    local wx = getXMLFloat(xml, "ffEinsatzleitung.wache#x")
    local wz = getXMLFloat(xml, "ffEinsatzleitung.wache#z")
    if wx ~= nil and wz ~= nil then
        self.wache = { x = wx, z = wz }
    end

    self.fleet = {}
    local i = 0
    while true do
        local k = string.format("ffEinsatzleitung.fuhrpark.fahrzeug(%d)", i)
        if not hasXMLProperty(xml, k) then
            break
        end
        local e = {
            key = getXMLString(xml, k .. "#key"),
            bez = getXMLString(xml, k .. "#bezeichnung") or getXMLString(xml, k .. "#typ"),
            klasse = getXMLString(xml, k .. "#klasse"),
            nr = getXMLString(xml, k .. "#nr"),
            call = getXMLString(xml, k .. "#funkrufname"),
            name = getXMLString(xml, k .. "#name"),
        }
        if e.nr == "" then e.nr = nil end
        if e.call == "" then e.call = nil end
        local sx = getXMLFloat(xml, k .. ".stellplatz#x")
        if sx ~= nil then
            e.spot = {
                x = sx,
                y = getXMLFloat(xml, k .. ".stellplatz#y") or 0,
                z = getXMLFloat(xml, k .. ".stellplatz#z") or 0,
                ry = getXMLFloat(xml, k .. ".stellplatz#ry") or 0,
            }
        end
        if e.klasse == nil and e.bez ~= nil then
            e.klasse = self:klasseFor(e.bez)
        end
        if e.key ~= nil and e.bez ~= nil then
            table.insert(self.fleet, e)
        end
        i = i + 1
    end
    sortFleet(self.fleet)

    if getXMLBool(xml, "ffEinsatzleitung.aao#gespeichert") then
        self.aao = {}
        i = 0
        while true do
            local k = string.format("ffEinsatzleitung.aao.eintrag(%d)", i)
            if not hasXMLProperty(xml, k) then
                break
            end
            local code = getXMLString(xml, k .. "#stichwort")
            local typ = getXMLString(xml, k .. "#typ")
            local n = getXMLInt(xml, k .. "#anzahl")
            if code ~= nil and typ ~= nil and n ~= nil then
                self.aao[code] = self.aao[code] or {}
                self.aao[code][typ] = n
            end
            i = i + 1
        end
    end
    self.aaoNachbar = {}
    i = 0
    while true do
        local code = getXMLString(xml, string.format("ffEinsatzleitung.aao.ohneNachbarwehr(%d)#stichwort", i))
        if code == nil then
            break
        end
        self.aaoNachbar[code] = false
        i = i + 1
    end
    delete(xml)
    self.fleetResolveTimer = 5000
    log("Fuhrpark geladen: %d Fahrzeuge, Wache %s.", #self.fleet, self.wache ~= nil and "gesetzt" or "nicht gesetzt")
end
