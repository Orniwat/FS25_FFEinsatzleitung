-- =============================================================================
-- FF Einsatzleitung  -  Kopplung an das Emergency Pack
--
-- Copyright (c) 2026 Orniwat & iowi. Alle Rechte vorbehalten.
-- Weitergabe, Veraenderung oder erneutes Hochladen nur mit Erlaubnis der Autoren.
-- =============================================================================

local log = FFE.log

-- ---------------------------------------------------------------------------
-- Kopplung an das Emergency Pack (g_currentMission.rolePlay)
-- ---------------------------------------------------------------------------
-- Fallback, falls die Beschreibung keinem Stichwort zugeordnet werden kann
FFE.EP_MAP = {
    FireScenario     = { code = "B1",     detail = "Brand" },
    OilSpillScenario = { code = "TH OEL", detail = "Oelspur auf Fahrbahn" },
    TreeScenario     = { code = "TH1",    detail = "Baum auf Strasse" },
}
FFE.EP_DEFAULT = { code = "TH1", detail = "Einsatz" }

function FFE:getRP()
    if g_currentMission ~= nil and type(g_currentMission.rolePlay) == "table" then
        return g_currentMission.rolePlay
    end
    return nil
end

function FFE:isEPActive()
    return self.settings.useEmergencyPack and self:getRP() ~= nil
end

-- Zustand des Emergency Packs als kurzer Text (Diagnose)
function FFE:epStateString(rp)
    rp = rp or self:getRP()
    if rp == nil then
        return "kein RolePlay"
    end
    local parts = {}
    local t = rp.pagerTimer
    if type(t) == "table" then
        table.insert(parts, string.format("pager(isRunning=%s, timeLeft=%s, duration=%s)",
            tostring(t.isRunning), tostring(t.timeLeft), tostring(t.duration)))
    else
        table.insert(parts, "pagerTimer=" .. type(t))
    end
    for _, listName in ipairs({ "pendingScenarios", "runningScenarios", "requestedScenarios", "pendingRemovalScenarios" }) do
        local list = rp[listName]
        if type(list) == "table" then
            local n, descs = 0, {}
            for k, scn in pairs(list) do
                n = n + 1
                if type(scn) == "table" then
                    local d = "?"
                    d = string.sub(tostring(scn.description or scn.id or "?"), 1, 50)
                    local ab = ""
                    if scn.getIsAborted ~= nil and scn:getIsAborted() then ab = " [abgebrochen]" end
                    table.insert(descs, d .. ab)
                else
                    table.insert(descs, tostring(k) .. "=" .. tostring(scn))
                end
            end
            table.insert(parts, string.format("%s=%d%s", listName, n, n > 0 and (" {" .. table.concat(descs, " | ") .. "}") or ""))
        else
            table.insert(parts, listName .. "=" .. type(list))
        end
    end
    do
        if type(rp.settings) == "table" then
            local sp = {}
            for k, v in pairs(rp.settings) do
                local tv = type(v)
                if tv == "number" or tv == "boolean" or tv == "string" then
                    table.insert(sp, tostring(k) .. "=" .. tostring(v))
                elseif tv == "table" and (type(v.value) ~= "nil") then
                    table.insert(sp, tostring(k) .. "=" .. tostring(v.value))
                end
            end
            if #sp > 0 then
                table.insert(parts, "settings{" .. table.concat(sp, ", ") .. "}")
            end
        end
    end
    return table.concat(parts, "; ")
end

-- Methodennamen einer Instanz (eigene Funktionen + Klassenkette)
local function methodNames(obj)
    local names, seen = {}, {}
    local function add(tbl)
        for k, v in pairs(tbl) do
            if type(v) == "function" and not seen[k] then
                seen[k] = true
                table.insert(names, tostring(k))
            end
        end
    end
    add(obj)
    local mt = getmetatable(obj)
    local depth = 0
    while mt ~= nil and type(mt.__index) == "table" and depth < 5 do
        add(mt.__index)
        mt = getmetatable(mt.__index)
        depth = depth + 1
    end
    table.sort(names)
    return table.concat(names, " ")
end

function FFE:logEPMethodsOnce(rp)
    if self.epMethodsLogged then
        return
    end
    self.epMethodsLogged = true
    log("EP RolePlay-Methoden: %s", methodNames(rp))
    -- Felder des Packs (zum Lernen, welche Szenario-Listen/Typen es gibt)
    do
        local f = {}
        for k, v in pairs(rp) do
            local t = type(v)
            local extra = ""
            if t == "table" then
                local n = 0
                for _ in pairs(v) do n = n + 1 end
                extra = "[" .. n .. "]"
            elseif t ~= "function" then
                extra = "=" .. string.sub(tostring(v), 1, 30)
            end
            table.insert(f, tostring(k) .. ":" .. t .. extra)
        end
        table.sort(f)
        log("EP RolePlay-Felder: %s", table.concat(f, " "))
        local mt = getmetatable(rp)
        log("EP RolePlay-Metatabelle: %s, __index: %s", type(mt), mt ~= nil and type(mt.__index) or "-")
    end
    if type(rp.pagerTimer) == "table" then
        log("EP pagerTimer-Methoden: %s", methodNames(rp.pagerTimer))
    end
end

-- erstes laufendes/wartendes Szenario des Packs
function FFE:firstEPScenario(rp)
    for _, listName in ipairs({ "runningScenarios", "pendingScenarios" }) do
        local list = rp[listName]
        if type(list) == "table" then
            for _, scn in pairs(list) do
                if type(scn) == "table" and not (self.epIgnored and self.epIgnored[scn]) then
                    return scn, listName
                end
            end
        end
    end
    return nil
end

-- Laesst den Pager des Emergency Packs sofort ausloesen -> das Pack startet einen echten Einsatz
function FFE:requestEPScenario()
    local rp = self:getRP()
    if rp == nil or type(rp.pagerTimer) ~= "table" then
        log("Emergency Pack nicht verfuegbar - eigener Probealarm.")
        self:triggerAlarm(nil)
        return false
    end
    local now = g_time or 0

    -- Mehrfachdruck abfangen
    if self.epRequest ~= nil then
        log("Anforderung laeuft bereits (seit %.1f s).", (now - self.epRequest.t) / 1000)
        return true
    end

    self:logEPMethodsOnce(rp)

    -- laeuft schon ein Einsatz? Dann den auf den Melder legen statt neu anzufordern
    local existing, listName = self:firstEPScenario(rp)
    if existing ~= nil then
        local d = tostring(existing.description or "?")
        log("Es laeuft bereits ein EP-Einsatz (%s): %s", listName, string.sub(d, 1, 120))
        if self.alarm == nil or self.alarm.epScenario ~= existing then
            self:onEPScenarioStarted(existing)
        else
            self.visible = true
        end
        return true
    end

    log("Einsatz wird angefordert. Zustand: %s", self:epStateString(rp))
    local t = rp.pagerTimer
    if not t.isRunning and type(t.start) == "function" then
        t:start()
        log("pagerTimer:start() aufgerufen")
    end
    t.timeLeft = 1
    t.isRunning = true
    self.epRequest = { t = now, stage = 1 }
    return true
end

-- wird aus updateEmergencyPack aufgerufen: ueberwacht eine laufende Anforderung
function FFE:checkEPRequest(rp, gotNew)
    local req = self.epRequest
    if req == nil then
        return
    end
    local now = g_time or 0
    local elapsed = now - req.t
    if gotNew then
        log("Emergency Pack hat den Einsatz nach %.1f s gestartet.", elapsed / 1000)
        self.epRequest = nil
        return
    end
    -- Das Pack wuerfelt bei jedem Pager-Aufruf, ob und wo ein Einsatz entsteht -
    -- also mehrmals versuchen, bevor der Melder selbst alarmiert.
    local function angefragt()
        local n = 0
        if type(rp.requestedScenarios) == "table" then
            for _ in pairs(rp.requestedScenarios) do n = n + 1 end
        end
        return n > 0
    end
    if req.stage == 1 and elapsed > 3000 then
        req.stage = 2
        req.versuche = 0
        req.next = now
        log("Nach 3 s noch kein Einsatz. Zustand: %s", self:epStateString(rp))
    end
    if req.stage == 2 and now >= (req.next or 0) and req.versuche < self.settings.epVersuche then
        if angefragt() then
            -- das Pack bereitet gerade einen Einsatz vor -> abwarten
            req.next = now + 2000
            req.wartet = (req.wartet or 0) + 1
            if req.wartet == 1 then
                log("Pack bereitet einen Einsatz vor (requestedScenarios) - warte.")
            end
            return
        end
        req.versuche = req.versuche + 1
        req.next = now + self.settings.epVersuchAbstandSec * 1000
        local t = rp.pagerTimer
        if type(t) == "table" and type(t.callback) == "function" then
            t.callback()
            if req.versuche == 1 then
                log("pagerTimer.callback Versuch %d", req.versuche)
            end
        end
    end
    local grenze = (self.settings.epVersuche * self.settings.epVersuchAbstandSec + self.settings.epFallbackSec) * 1000
    if req.stage == 2 and elapsed > grenze and not angefragt() then
        self.epRequest = nil
        log("Emergency Pack hat nach %d Versuchen keinen Einsatz gestartet. Zustand: %s", req.versuche or 0, self:epStateString(rp))
        log("Fallback: eigener Alarm des Melders.")
        self:triggerAlarm(nil)
    end
end

local function scenarioClassName(scn)
    local cn = scn.className
    if type(cn) == "string" then
        return cn
    end
    return "?"
end

-- versucht, aus einem Szenario eine Weltposition zu lesen
local function scenarioPosition(scn)
    local function fromTable(t)
        if type(t) ~= "table" then return nil end
        local x = t.x or t[1] or t.worldX or t.posX
        local z = t.z or t[3] or t.worldZ or t.posZ
        if type(x) == "number" and type(z) == "number" then
            return x, z
        end
        return nil
    end
    local x, z
    for _, key in ipairs({ "determinedPosition", "targetPosition", "startPosition", "position", "determinedStart", "worldPosition", "spawnPosition" }) do
        x, z = fromTable(scn[key])
        if x ~= nil then
            return x, z
        end
    end
    -- Hotspot des Szenarios
    for _, key in ipairs({ "hotspot", "mapHotspot" }) do
        local ok = true
        local hs = scn[key]
        if type(hs) == "table" then
            if hs.getWorldPosition ~= nil then
                x, z = hs:getWorldPosition()
            else
                x, z = hs.worldX, hs.worldZ
            end
        end
        if ok and type(x) == "number" and type(z) == "number" then
            return x, z
        end
    end
    -- Knoten des Szenarios
    for _, key in ipairs({ "rootNode", "node", "markerNode", "targetNode" }) do
        local ok = true
        local n = scn[key]
        if type(n) == "number" and n ~= 0 and entityExists ~= nil and entityExists(n) then
            local wx, _, wz = getWorldTranslation(n)
            x, z = wx, wz
        end
        if ok and type(x) == "number" then
            return x, z
        end
    end
    return nil
end

function FFE:nearestFieldName(x, z)
    if x == nil then
        return "siehe Karte"
    end
    local best, bestD = nil, math.huge
    for _, c in ipairs(self:getFieldCenters()) do
        local d = (c.x - x) ^ 2 + (c.z - z) ^ 2
        if d < bestD then
            best, bestD = c, d
        end
    end
    if best ~= nil then
        local dist = math.sqrt(bestD)
        if dist < 150 then
            return best.name
        end
        return string.format("nahe %s", best.name)
    end
    return "siehe Karte"
end

-- Prueft, ob ein Text zu einem EP-Einsatz gehoert, den unser Melder bereits anzeigt
function FFE:isEPPopupText(...)
    if not self.settings.suppressEPPopup then
        return false
    end
    -- Beschreibungen live aus dem Pack holen (das Popup kommt evtl. vor unserer Erkennung)
    self.epDescriptions = self.epDescriptions or {}
    local rp = self:getRP()
    if rp ~= nil then
        for _, listName in ipairs({ "pendingScenarios", "runningScenarios", "requestedScenarios" }) do
            local list = rp[listName]
            if type(list) == "table" then
                for _, scn in pairs(list) do
                    if type(scn) == "table" then
                        if type(scn.description) == "string" and scn.description ~= "" then
                            self.epDescriptions[scn.description] = true
                        end
                    end
                end
            end
        end
    end
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        local texts = {}
        if type(v) == "string" then
            table.insert(texts, v)
        elseif type(v) == "table" then
            for _, key in ipairs({ "text", "title", "message", "description" }) do
                if type(v[key]) == "string" then
                    table.insert(texts, v[key])
                end
            end
        end
        for _, t in ipairs(texts) do
            for desc, _ in pairs(self.epDescriptions) do
                if t == desc or string.find(t, string.sub(desc, 1, 40), 1, true) then
                    return true
                end
            end
            -- zum Lernen: einsatzverdaechtige Texte, die nicht gefiltert wurden, einmal protokollieren
            local lt = (FFE.lowerDE or string.lower)(t)
            if (string.find(lt, "einsatz", 1, true) or string.find(lt, "feuerwehr", 1, true)) then
                self.loggedPopupTexts = self.loggedPopupTexts or {}
                if not self.loggedPopupTexts[t] then
                    self.loggedPopupTexts[t] = true
                    log("Popup nicht gefiltert: %s", string.sub(t, 1, 160))
                end
            end
        end
    end
    return false
end

-- Umwickelt eine Funktion an einem Objekt: unterdrueckt EP-Popups, protokolliert Aufrufe
function FFE:wrapPopupFunction(obj, objName, funcName)
    if type(obj) ~= "table" or type(obj[funcName]) ~= "function" then
        return
    end
    local key = objName .. "." .. funcName
    self.wrapped = self.wrapped or {}
    if self.wrapped[key] then
        return
    end
    local orig = obj[funcName]
    self.wrapped[key] = { obj = obj, name = funcName, orig = orig }
    obj[funcName] = function(...)
        local args = { ... }
        local ffe = FFE
        if ffe.settings.popupDebug then
            ffe.popupCallCount = ffe.popupCallCount or {}
            local c = (ffe.popupCallCount[key] or 0) + 1
            ffe.popupCallCount[key] = c
            if c <= 3 then
                local first = ""
                for i = 1, math.min(select("#", ...), 4) do
                    local v = select(i, ...)
                    if type(v) == "string" then
                        first = v
                        break
                    elseif type(v) == "table" and type(v.text) == "string" then
                        first = v.text
                        break
                    end
                end
                log("Popup-Aufruf %s #%d: %s", key, c, string.sub(first, 1, 100))
            end
        end
        if ffe:isEPPopupText(...) then
            local types = {}
            for i = 1, math.min(select("#", ...), 8) do
                table.insert(types, type(select(i, ...)))
            end
            local dialogClass = nil
            if string.find(key, "YesNo", 1, true) then
                dialogClass = "YesNoDialog"
            elseif string.find(key, "Info", 1, true) then
                dialogClass = "InfoDialog"
            end
            if dialogClass == "InfoDialog" then
                -- Hinweise des Packs waehrend des Einsatzes (naechster Schritt, aufraeumen, fertig)
                -- NICHT verstecken - der Spieler braucht sie. Nur mitschreiben.
                local text = ""
                for i = 1, select("#", ...) do
                    local v = args[i]
                    if type(v) == "string" then text = v break end
                    if type(v) == "table" and type(v.text) == "string" then text = v.text break end
                end
                log("EP-Hinweis: %s", string.sub(text, 1, 200))
                if ffe.alarm ~= nil and text ~= "" then
                    ffe:journal(ffe.alarm, "Leitstelle: " .. text)
                end
                return orig(...)
            end
            if dialogClass ~= nil then
                -- Rueckruf des Packs suchen und im naechsten Frame selbst mit "Ja" aufrufen -
                -- der Dialog wird gar nicht erst geoeffnet (kein Popup, keine Eingabesperre).
                local n = select("#", ...)
                local cb, target = nil, nil
                for i = 1, n do
                    local v = args[i]
                    if type(v) == "function" then
                        cb, target = v, args[i + 1]
                        break
                    elseif type(v) == "table" and type(v.callback) == "function" then
                        cb, target = v.callback, v.target
                        break
                    end
                end
                if cb ~= nil then
                    ffe.epBestaetigen = ffe.epBestaetigen or {}
                    table.insert(ffe.epBestaetigen, { cb = cb, target = target, dialog = dialogClass, ab = (g_time or 0) })
                    log("EP-Dialog %s (Argumente: %s) abgefangen - wird ohne Popup bestaetigt.", key, table.concat(types, ","))
                    return nil
                end
                -- kein Rueckruf gefunden: Dialog oeffnen und sofort bestaetigen (alter Weg)
                local ret = { orig(...) }
                local how = ffe:autoConfirmDialog(dialogClass, ret[1], args)
                log("EP-Dialog %s (Argumente: %s) automatisch bestaetigt: %s", key, table.concat(types, ","), tostring(how))
                return unpack(ret)
            end
            log("EP-Meldung unterdrueckt (%s).", key)
            return
        end
        return orig(...)
    end
end

-- Bestaetigt einen gerade geoeffneten Dialog mit "Ja/OK". Liefert, was funktioniert hat (oder nil).
function FFE:autoConfirmDialog(className, ret, args)
    local cands = {}
    local function addCand(name, c)
        if type(c) == "table" then
            table.insert(cands, { name = name, obj = c })
            if type(c.target) == "table" then
                table.insert(cands, { name = name .. ".target", obj = c.target })
            end
        end
    end
    addCand("Rueckgabe", ret)
    local cls = _G[className]
    if type(cls) == "table" then
        addCand(className .. ".INSTANCE", cls.INSTANCE)
    end
    if g_gui ~= nil and type(g_gui.guis) == "table" then
        addCand("g_gui.guis." .. className, g_gui.guis[className])
    end
    for _, c in ipairs(cands) do
        for _, m in ipairs({ "sendCallback", "onClickYes", "onYes", "onClickOk", "onClickOK" }) do
            if type(c.obj[m]) == "function" then
                c.obj[m](c.obj, true)
                return c.name .. ":" .. m
            end
        end
    end
    -- letzter Versuch: Rueckruf aus den Argumenten direkt aufrufen (callback, target, ...)
    if type(args[1]) == "function" then
        local cb, target = args[1], args[2]
        if target ~= nil then cb(target, true) else cb(true) end
        if g_gui ~= nil and g_gui.closeDialogByName ~= nil then
            g_gui:closeDialogByName(className)
        end
        return "Rueckruf direkt"
    end
    return nil
end

function FFE:installPopupHooks()
    if self.popupHooksInstalled or self.popupHooksDisabled or not self.settings.suppressEPPopup then
        return
    end
    self.popupHooksInstalled = true
    if g_gui ~= nil then
        for _, f in ipairs({ "showInfoDialog", "showYesNoDialog", "showDialog", "showTextInputDialog" }) do
            self:wrapPopupFunction(g_gui, "g_gui", f)
        end
    end
    for _, cls in ipairs({ { InfoDialog, "InfoDialog" }, { YesNoDialog, "YesNoDialog" } }) do
        if type(cls[1]) == "table" then
            self:wrapPopupFunction(cls[1], cls[2], "show")
        end
    end
    if g_currentMission ~= nil then
        local hud = g_currentMission.hud
        if hud ~= nil then
            for _, f in ipairs({ "showInGameMessage", "addSideNotification", "showBlinkingWarning", "showTopNotification" }) do
                self:wrapPopupFunction(hud, "hud", f)
            end
        end
        for _, f in ipairs({ "showBlinkingWarning", "addIngameNotification", "showInGameMessage" }) do
            self:wrapPopupFunction(g_currentMission, "g_currentMission", f)
        end
    end
    local n = 0
    for _ in pairs(self.wrapped or {}) do n = n + 1 end
    log("Popup-Filter aktiv (%d Funktionen).", n)
end

function FFE:removePopupHooks()
    for _, w in pairs(self.wrapped or {}) do
        w.obj[w.name] = w.orig
    end
    self.wrapped = nil
    self.popupHooksInstalled = false
end

-- entfernt ein abgebrochenes Szenario, das noch in den Listen des Packs haengt
function FFE:forceRemoveScenario(rp, scn)
    if scn.deleteHotspot ~= nil then
        scn:deleteHotspot()
    end
    if scn.mapHotspot ~= nil and g_currentMission ~= nil and g_currentMission.removeMapHotspot ~= nil then
        g_currentMission:removeMapHotspot(scn.mapHotspot)
    end
    for _, listName in ipairs({ "pendingScenarios", "runningScenarios", "requestedScenarios" }) do
        local list = rp[listName]
        if type(list) == "table" then
            local idx = nil
            for k, v in pairs(list) do
                if v == scn then idx = k break end
            end
            if idx ~= nil then
                if type(idx) == "number" and idx <= #list then
                    table.remove(list, idx)
                else
                    list[idx] = nil
                end
                log("Abgebrochenen Einsatz aus %s entfernt.", listName)
            end
        end
    end
end

-- schreibt einmalig die einfachen Felder eines Szenarios ins Log (zum Lernen)
local function logScenarioFields(scn, cn)
    print("[FFE-SCAN] Neues EP-Szenario: " .. cn)
    local n = 0
    for k, v in pairs(scn) do
        local t = type(v)
        if t == "number" or t == "string" or t == "boolean" then
            print(string.format("[FFE-SCAN]   %s = %s", tostring(k), tostring(v)))
        elseif t == "table" then
            print(string.format("[FFE-SCAN]   %s : table", tostring(k)))
        end
        n = n + 1
        if n > 80 then break end
    end
end

function FFE:updateEmergencyPack(dt)
    if not self.settings.useEmergencyPack then
        return
    end
    local rp = self:getRP()
    if rp == nil then
        return
    end
    self:installPopupHooks()

    -- abgefangene Dialoge des Packs bestaetigen (einen Frame spaeter, damit das Pack fertig ist)
    if self.epBestaetigen ~= nil and #self.epBestaetigen > 0 then
        local liste = self.epBestaetigen
        self.epBestaetigen = {}
        for _, b in ipairs(liste) do
            log("EP-Dialog %s wird mit Ja bestaetigt.", b.dialog)
            if b.target ~= nil then
                b.cb(b.target, true)
            else
                b.cb(true)
            end
        end
    end

    self.epCheckTimer = (self.epCheckTimer or 0) + dt
    if self.epCheckTimer < 500 then
        return
    end
    self.epCheckTimer = 0

    self.epKnown = self.epKnown or {}
    self.epIgnored = self.epIgnored or {}
    self.epAbortChecks = self.epAbortChecks or {}
    local current = {}
    local newOnes = {}
    for _, listName in ipairs({ "pendingScenarios", "runningScenarios" }) do
        local list = rp[listName]
        if type(list) == "table" then
            for _, scn in pairs(list) do
                if type(scn) == "table" then
                    current[scn] = true
                    if not self.epKnown[scn] and not self.epIgnored[scn] then
                        self.epKnown[scn] = true
                        table.insert(newOnes, scn)
                    end
                end
            end
        end
    end

    -- beim ersten Durchlauf laufende Einsaetze nur merken, nicht alarmieren
    if not self.epInitialized then
        self.epInitialized = true
        log("Emergency Pack erkannt. Zustand beim Start: %s", self:epStateString(rp))
        return
    end

    for _, scn in ipairs(newOnes) do
        self:onEPScenarioStarted(scn)
    end
    self:checkEPRequest(rp, #newOnes > 0)

    -- abgebrochene Einsaetze, die nach 1,5 s noch da sind, selbst entfernen
    local now = g_time or 0
    for scn, t in pairs(self.epAbortChecks) do
        if not current[scn] then
            self.epAbortChecks[scn] = nil
        elseif now - t > 1500 then
            self.epAbortChecks[scn] = nil
            log("Pack hat den abgebrochenen Einsatz nicht entfernt - raeume selbst auf.")
            self:forceRemoveScenario(rp, scn)
        end
    end
    for scn, _ in pairs(self.epIgnored) do
        if not current[scn] and self.epAbortChecks[scn] == nil then
            self.epIgnored[scn] = nil
        end
    end

    -- Karte: Navigationsziel auf den Kartenpunkt des Packs legen, sonst eigenen Wegpunkt setzen
    local a = self.alarm
    if a ~= nil and a.epScenario ~= nil and not a.mapDone then
        local hs = a.epScenario.mapHotspot
        if type(hs) == "table" then
            a.mapDone = true
            a.hsRef = hs
            self:setNavZiel(hs)
            log("Kartenpunkt des Packs gefunden, Navigationsziel gesetzt.")
        elseif now - (a.startTime or now) > 3000 and a.x ~= nil then
            a.mapDone = true
            log("Pack hat keinen Kartenpunkt gesetzt - setze eigenen Wegpunkt.")
            self:createHotspot()
        end
    end

    -- Einsatzort nachfuehren: das Pack legt den endgueltigen Ort oft erst nach dem "Ja" fest
    if self.alarm ~= nil and self.alarm.epScenario ~= nil and now - (self.alarm.startTime or now) < 120000 then
        local al = self.alarm
        local x, z = scenarioPosition(al.epScenario)
        if x ~= nil and (al.x == nil or math.abs(x - al.x) + math.abs(z - al.z) > 30) then
            al.x, al.z = x, z
            al.ort = self:nearestFieldName(x, z)
            al.parkplaetze = nil
            log("Einsatzort bestimmt: %s (%.0f / %.0f)", tostring(al.ort), x, z)
        end
        -- neuer Kartenpunkt des Packs -> Navigationsziel neu setzen
        local hs = al.epScenario.mapHotspot
        if type(hs) == "table" and hs ~= al.hsRef then
            al.hsRef = hs
            self:setNavZiel(hs)
            if al.mapDone then
                log("Neuer Kartenpunkt des Packs, Navigationsziel gesetzt.")
            end
        end
    end

    -- beendete Einsaetze
    for scn, _ in pairs(self.epKnown) do
        if not current[scn] then
            self.epKnown[scn] = nil
            if self.alarm ~= nil and self.alarm.epScenario == scn then
                log("Emergency-Pack-Einsatz beendet.")
                self:endEinsatz(false)
            end
        end
    end
end

-- Navigationsziel der Karte setzen
function FFE:setNavZiel(hs)
    if g_currentMission ~= nil and g_currentMission.setMapTargetHotspot ~= nil then
        g_currentMission:setMapTargetHotspot(hs)
    end
end

-- Stichworte aus dem Beschreibungstext des Emergency Packs ableiten (Reihenfolge wichtig!)
FFE.EP_KEYWORDS = {
    { words = { "katze", "tier", "cat", "animal" },                                                 code = "TH TIER", detail = "Katze auf Baum" },
    { words = { "ölspur", "oelspur", "ölfleck", "ausgelaufen", "betriebsstoff", "oil", "spill", "leak" },  code = "TH OEL",  detail = "Oelspur auf Fahrbahn" },
    { words = { "unfall", "eingeklemmt", "verunfall", "zusammenstoß", "kollision", "accident", "crash", "trapped", "collision" }, code = "TH VU", detail = "VU, Person eingeklemmt" },
    { words = { "feld", "field" },                                                          code = "B2",      detail = "Feldbrand",         needFire = true },
    { words = { "ballen", "stroh", "heu", "bale", "straw", "hay" },                                        code = "B2",      detail = "Brand Ballenlager", needFire = true },
    { words = { "auto", "fahrzeug", "pkw", "traktor", "car", "vehicle", "tractor" },                            code = "B1",      detail = "Fahrzeugbrand",     needFire = true },
    { words = { "palette", "pallet" },                                                       code = "B1",      detail = "Brand Paletten" },
    { words = { "container", "mülltonne", "muell", "bin", "dumpster" },                               code = "B1",      detail = "Containerbrand" },
    { words = { "brand", "feuer", "brennt", "flammen", "rauch", "fire", "burn", "flame", "smoke" },                  code = "B1",      detail = "Brand" },
    { words = { "baum", "tree" },                                                          code = "TH1",     detail = "Baum auf Strasse" },
}

local FIRE_WORDS = { "brand", "feuer", "brennt", "flammen", "rauch", "fire", "burn", "flame", "smoke" }

-- string.lower kennt keine Umlaute (UTF-8): "Ölspur" bliebe "Ölspur"
local function lowerDE(text)
    text = string.lower(text or "")
    text = text:gsub("Ä", "ä"):gsub("Ö", "ö"):gsub("Ü", "ü")
    return text
end
FFE.lowerDE = lowerDE

local function containsAny(text, words)
    for _, w in ipairs(words) do
        if string.find(text, w, 1, true) then
            return true
        end
    end
    return false
end

function FFE:classifyEPScenario(scn)
    local desc = tostring(scn.description or "")
    local text = lowerDE(desc)
    for _, k in ipairs(self.EP_KEYWORDS) do
        if containsAny(text, k.words) and (not k.needFire or containsAny(text, FIRE_WORDS)) then
            return k, desc
        end
    end
    local cn = scenarioClassName(scn)
    for key, m in pairs(self.EP_MAP) do
        if string.find(cn, key, 1, true) then
            return m, desc
        end
    end
    return self.EP_DEFAULT, desc
end

function FFE:onEPScenarioStarted(scn)
    local cn = scenarioClassName(scn)
    local m, desc = self:classifyEPScenario(scn)
    log("EP-Szenario %s: \"%s\" -> %s %s", cn, desc, m.code, m.detail)

    -- Beschreibung merken, damit wir das Popup des Packs abfangen koennen
    self.epDescriptions = self.epDescriptions or {}
    if desc ~= "" then
        self.epDescriptions[desc] = true
    end
    -- auch die Abschlussmeldung des Packs abfangen (der Melder zeigt das Ende selbst)
    if type(scn.postMessage) == "string" and scn.postMessage ~= "" then
        self.epDescriptions[scn.postMessage] = true
    end

    local x, z = scenarioPosition(scn)
    self:triggerAlarm(nil, {
        code = m.code,
        detail = m.detail,
        loc = { name = self:nearestFieldName(x, z), x = x, z = z },
        noHotspot = true,      -- das Emergency Pack setzt seinen eigenen Kartenpunkt
        epScenario = scn,
    })
end
