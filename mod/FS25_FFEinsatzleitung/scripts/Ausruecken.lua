-- =============================================================================
-- FF Einsatzleitung  -  Echtes Ausruecken der Fuhrpark-Fahrzeuge
--
-- Sichtblase: Fahrzeuge stehen immer dort, wo sie laut Status sein muessten -
-- versetzt wird aber nur, wenn kein Spieler in der Naehe ist (weder am alten noch am neuen Ort).
--   Status 3/4  -> Abstellplatz an der Einsatzstelle (Blaulicht an)
--   Status 1/2  -> zurueck auf den Stellplatz an der Wache (Blaulicht aus)
-- Mit AutoDrive: Steht der Spieler in der Naehe, fahren die Fahrzeuge wirklich -
-- zum AutoDrive-Ziel, das der Einsatzstelle am naechsten liegt (bzw. zurueck zur Wache).
-- Fahrzeuge, in denen ein Spieler sitzt, werden nie angefasst.
--
-- Freibuggen: Die KI kommt immer an. Faehrt ein Fahrzeug nicht weiter (festgefahren,
-- AutoDrive bricht ab, umgekippt, unter der Map) oder braucht es viel zu lange, wird
-- AutoDrive einmal neu gestartet - hilft das nicht, wird es direkt ans Ziel versetzt.
-- Ohne AutoDrive gilt dasselbe: steht es zu lange nicht da, wo es laut Status sein muesste,
-- wird es versetzt, sobald du nicht direkt daneben stehst.
--
-- Copyright (c) 2026 Orniwat & iowi. Alle Rechte vorbehalten.
-- Weitergabe, Veraenderung oder erneutes Hochladen nur mit Erlaubnis der Autoren.
-- =============================================================================

local log = FFE.log

FFE.AUSRUECKEN = {
    sichtRadius     = 350,   -- m: naeher dran -> nicht versetzen
    adZielMaxDist   = 400,   -- m: AutoDrive-Ziel darf so weit von der Einsatzstelle weg sein
    ankunftRadius   = 120,   -- m: so nah an der Einsatzstelle gilt ein fahrendes Fahrzeug als angekommen
    pruefIntervall  = 1000,  -- ms
    festfahrZeit    = 25000, -- ms: so lange kaum Bewegung (< 3 m) -> festgefahren
    festfahrWeg     = 3,     -- m
    adMinDauer      = 240000,-- ms: echte Fahrt darf mindestens so lange dauern ...
    adFaktor        = 2.5,   -- ... bzw. das 2,5-fache der geschaetzten Fahrzeit
    notRadius       = 40,    -- m: Notfall-Versetzen nur, wenn du nicht direkt am Ziel stehst
    notWarte        = 90000, -- ms: so lange nach Soll-Ankunft warten, bevor notfalls versetzt wird
}

local function dist(x1, z1, x2, z2)
    if x1 == nil or x2 == nil then
        return math.huge
    end
    return math.sqrt((x1 - x2) ^ 2 + (z1 - z2) ^ 2)
end

-- ---------------------------------------------------------------------------
-- Fahrzeug-Helfer
-- ---------------------------------------------------------------------------
function FFE:vehiclePos(v)
    if v == nil or v.rootNode == nil then
        return nil
    end
    local x, _, z = getWorldTranslation(v.rootNode)
    return x, z
end

-- sitzt ein Spieler in diesem Fahrzeug?
function FFE:isVehicleOccupied(v)
    if v == nil then
        return false
    end
    if v == self:getPlayerVehicle() then
        return true
    end
    if v.getIsControlled ~= nil then
        return v:getIsControlled() == true
    end
    return false
end

-- ist irgendein Spieler naeher als r an (x,z)?
function FFE:playerNear(x, z, r)
    local px, pz = self:getPlayerPosition()
    return dist(px, pz, x, z) < r
end

function FFE:terrainHeight(x, z)
    if g_currentMission == nil or g_currentMission.terrainRootNode == nil or getTerrainHeightAtWorldPos == nil then
        return 0
    end
    return getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z)
end

function FFE:teleportVehicle(v, x, z, ry)
    if v.setRelativePosition ~= nil then
        v:setRelativePosition(x, 0.5, z, ry or 0)
    elseif v.setAbsolutePosition ~= nil then
        local y = self:terrainHeight(x, z) + 0.5
        v:setAbsolutePosition(x, y, z, 0, ry or 0, 0)
    else
        log("Fahrzeug %s kann nicht versetzt werden.", tostring(v.uniqueId))
        return false
    end
    return true
end

-- umgekippt oder unter die Map gefallen?
function FFE:fahrzeugInNot(v)
    if v == nil or v.rootNode == nil then
        return false
    end
    if localDirectionToWorld ~= nil then
        local _, uy, _ = localDirectionToWorld(v.rootNode, 0, 1, 0)
        if uy ~= nil and uy < 0.4 then
            return true
        end
    end
    local x, y, z = getWorldTranslation(v.rootNode)
    return y ~= nil and y < self:terrainHeight(x, z) - 3
end

function FFE:setBlaulicht(v, an)
    if v ~= nil and v.setBeaconLightsVisibility ~= nil then
        v:setBeaconLightsVisibility(an == true, true, true)
    end
end

-- ---------------------------------------------------------------------------
-- AutoDrive
-- ---------------------------------------------------------------------------
function FFE:hasAutoDrive()
    return AutoDrive ~= nil and type(AutoDrive.StartDriving) == "function" and ADGraphManager ~= nil
end

function FFE:adCanDrive(v)
    return self:hasAutoDrive() and v ~= nil and v.ad ~= nil and v.ad.stateModule ~= nil
end

-- naechstes AutoDrive-Ziel zu (x,z) innerhalb maxDist, oder nil
function FFE:adNearestMarker(x, z, maxDist)
    if not self:hasAutoDrive() or x == nil then
        return nil
    end
    local best, bestD = nil, maxDist or math.huge
    if type(AutoDrive.GetAvailableDestinations) ~= "function" then
        return nil
    end
    for id, m in pairs(AutoDrive:GetAvailableDestinations() or {}) do
        local d = dist(m.x, m.z, x, z)
        if d < bestD then
            best, bestD = id, d
        end
    end
    return best, bestD
end

function FFE:adDriveTo(v, markerId)
    if not self:adCanDrive(v) then
        return false
    end
    if v.ad.stateModule:isActive() then
        v:stopAutoDrive()
    end
    v.ad.stateModule:setMode(AutoDrive.MODE_DRIVETO)
    AutoDrive:StartDriving(v, markerId, markerId, nil, nil, nil)
    return v.ad.stateModule:isActive()
end

-- echte Fahrt starten und den Festfahr-Waechter scharf schalten
function FFE:adFahrtStarten(u, v, markerId, schaetzMs)
    if not self:adDriveTo(v, markerId) then
        return false
    end
    local now = g_time or 0
    u.adFahrt = true
    u.adZiel = markerId
    u.adStart = now
    u.adMax = math.max(self.AUSRUECKEN.adMinDauer, (schaetzMs or 0) * self.AUSRUECKEN.adFaktor)
    u.wX, u.wZ, u.wSeit = nil, nil, now
    u.rettung = 0
    return true
end

-- Festfahr-Waechter fuer echte Fahrten: "ok", "neustart" oder "versetzen"
function FFE:festfahrPruefen(u, v, now)
    if self:fahrzeugInNot(v) then
        return "versetzen", "umgekippt/unter der Map"
    end
    local vx, vz = self:vehiclePos(v)
    if u.wX == nil or dist(vx, vz, u.wX, u.wZ) > self.AUSRUECKEN.festfahrWeg then
        u.wX, u.wZ, u.wSeit = vx, vz, now
    end
    local fest = not self:adIsDriving(v) or now - (u.wSeit or now) >= self.AUSRUECKEN.festfahrZeit
    local zuLang = u.adStart ~= nil and now - u.adStart > (u.adMax or math.huge)
    if zuLang then
        return "versetzen", "braucht zu lange"
    end
    if fest then
        u.rettung = (u.rettung or 0) + 1
        if u.rettung == 1 and u.adZiel ~= nil then
            return "neustart", "festgefahren"
        end
        return "versetzen", "festgefahren"
    end
    return "ok"
end

-- AutoDrive fuer diese Einheit neu starten (gleiches Ziel)
function FFE:adNeustart(u, v)
    self:adStop(v)
    if u.adZiel ~= nil and self:adDriveTo(v, u.adZiel) then
        u.wX, u.wZ, u.wSeit = nil, nil, g_time or 0
        return true
    end
    return false
end

function FFE:adIsDriving(v)
    return self:adCanDrive(v) and v.ad.stateModule:isActive() == true
end

function FFE:adStop(v)
    if self:adCanDrive(v) and v.ad.stateModule:isActive() and v.stopAutoDrive ~= nil then
        v:stopAutoDrive()
    end
end

-- ---------------------------------------------------------------------------
-- Abstellplaetze an der Einsatzstelle
-- Bevorzugt Wegpunkte des AutoDrive-Netzes (liegen auf Strassen), sonst ein Kreis.
-- ---------------------------------------------------------------------------
function FFE:buildParkplaetze(a)
    local slots = {}
    if a.x == nil then
        return slots
    end
    if self:hasAutoDrive() and type(ADGraphManager.getWayPoints) == "function" then
        do
            local cand = {}
            for _, wp in pairs(ADGraphManager:getWayPoints() or {}) do
                local d = dist(wp.x, wp.z, a.x, a.z)
                if d >= 20 and d <= 140 then
                    table.insert(cand, { wp = wp, d = d })
                end
            end
            table.sort(cand, function(p, q) return p.d < q.d end)
            for _, c in ipairs(cand) do
                local free = true
                for _, s in ipairs(slots) do
                    if dist(s.x, s.z, c.wp.x, c.wp.z) < 14 then
                        free = false
                        break
                    end
                end
                if free then
                    local ry = 0
                    local nextId = c.wp.out ~= nil and c.wp.out[1] or nil
                    local nxt = nextId ~= nil and ADGraphManager.getWayPointById ~= nil and ADGraphManager:getWayPointById(nextId) or nil
                    if nxt ~= nil then
                        ry = math.atan2(nxt.x - c.wp.x, nxt.z - c.wp.z)
                    end
                    table.insert(slots, { x = c.wp.x, z = c.wp.z, ry = ry })
                    if #slots >= 12 then
                        break
                    end
                end
            end
        end
    end
    -- Rest im Kreis um die Einsatzstelle, Front zur Einsatzstelle
    local i = 0
    while #slots < 12 do
        local ring = math.floor(i / 8)
        local ang = (i % 8) * (math.pi / 4) + ring * 0.4
        local r = 30 + ring * 12
        local x, z = a.x + math.sin(ang) * r, a.z + math.cos(ang) * r
        table.insert(slots, { x = x, z = z, ry = math.atan2(a.x - x, a.z - z) })
        i = i + 1
    end
    return slots
end

function FFE:takeParkplatz(a, u)
    if u.slot ~= nil then
        return u.slot
    end
    a.parkplaetze = a.parkplaetze or self:buildParkplaetze(a)
    a.nextSlot = (a.nextSlot or 0) + 1
    u.slot = a.parkplaetze[a.nextSlot] or a.parkplaetze[#a.parkplaetze]
    return u.slot
end

-- ---------------------------------------------------------------------------
-- Ablauf (wird aus updateEinsatz aufgerufen)
-- ---------------------------------------------------------------------------

-- beim Ausruecken (Status 3)
function FFE:onUnitAusruecken(a, u)
    local v = u.entry ~= nil and u.entry.vehicle or nil
    if v == nil or not self:feature("ausruecken") or not self.settings.echtAusruecken or self:isVehicleOccupied(v) then
        return
    end
    self:setBlaulicht(v, true)
    -- Spieler in der Naehe der Wache/des Fahrzeugs und AutoDrive da -> wirklich losfahren
    local vx, vz = self:vehiclePos(v)
    local R = self.AUSRUECKEN.sichtRadius
    if self:adCanDrive(v) and (self:playerNear(vx, vz, R) or self:playerNear(a.x, a.z, R)) then
        local marker = self:adNearestMarker(a.x, a.z, self.AUSRUECKEN.adZielMaxDist)
        local schaetz = (u.arriveAt or g_time) - (g_time or 0)
        if marker ~= nil and self:adFahrtStarten(u, v, marker, schaetz) then
            u.arriveAt = (u.arriveAt or g_time) + 600000   -- spaetestens: echte Fahrt darf laenger dauern
            log("%s faehrt mit AutoDrive zur Einsatzstelle.", u.label)
            self:journal(a, u.label .. " fährt mit AutoDrive")
        end
    end
end

-- laufend: Ankunft echter Fahrten, Versetzen ausserhalb der Sicht
function FFE:updateAusruecken(dt)
    self.ausrTimer = (self.ausrTimer or 0) + dt
    if self.ausrTimer < self.AUSRUECKEN.pruefIntervall then
        return
    end
    self.ausrTimer = 0
    if not self:feature("ausruecken") or not self.settings.echtAusruecken then
        return
    end
    local now = g_time or 0
    local R = self.AUSRUECKEN.sichtRadius

    local a = self.alarm
    if a ~= nil and a.units ~= nil then
        for _, u in ipairs(a.units) do
            local v = u.entry ~= nil and u.entry.vehicle or nil
            if v ~= nil and not self:isVehicleOccupied(v) then
                local vx, vz = self:vehiclePos(v)
                -- echte Fahrt mit AutoDrive
                if u.adFahrt and u.status == "3" then
                    local d = dist(vx, vz, a.x, a.z)
                    if d < self.AUSRUECKEN.ankunftRadius or (not self:adIsDriving(v) and d < self.AUSRUECKEN.adZielMaxDist) then
                        u.adFahrt = false
                        u.arriveAt = now     -- Status 4 im naechsten Durchlauf von updateEinsatz
                    else
                        local was, warum = self:festfahrPruefen(u, v, now)
                        if was == "neustart" and self:adNeustart(u, v) then
                            log("%s %s - AutoDrive neu gestartet.", u.label, warum)
                            self:journal(a, u.label .. " " .. warum .. " – AutoDrive neu gestartet")
                        elseif was ~= "ok" then
                            self:anEinsatzstelleVersetzen(a, u, v, warum)
                        end
                    end
                elseif (u.status == "3" or u.status == "4") and not u.adFahrt and not u.amOrt then
                    -- ausserhalb der Sicht an die Einsatzstelle versetzen
                    local slot = self:takeParkplatz(a, u)
                    local sollDa = u.status == "4" and now > (u.arriveAt or now) + self.AUSRUECKEN.notWarte
                    if slot ~= nil and not self:playerNear(vx, vz, R) and not self:playerNear(slot.x, slot.z, R) then
                        if self:teleportVehicle(v, slot.x, slot.z, slot.ry) then
                            u.amOrt = true
                            self:setBlaulicht(v, true)
                        end
                    elseif slot ~= nil and sollDa and not self:playerNear(slot.x, slot.z, self.AUSRUECKEN.notRadius) then
                        -- du wartest schon an der Einsatzstelle -> trotzdem holen
                        self:anEinsatzstelleVersetzen(a, u, v, "noch nicht da")
                    end
                end
            end
        end
    end

    -- Rueckweg: Status 1/2 -> auf den Stellplatz (bzw. Platz an der Wache)
    self.zurueck = self.zurueck or {}
    for i = #self.zurueck, 1, -1 do
        local u = self.zurueck[i]
        local e = u.entry
        local v = e ~= nil and e.vehicle or nil
        local ziel = e ~= nil and self:parkZiel(e) or nil
        if v == nil or ziel == nil then
            if v ~= nil then
                self:setBlaulicht(v, false)
            end
            table.remove(self.zurueck, i)
        elseif e.busy and u.status ~= "1" and u.status ~= "2" then
            -- schon wieder im naechsten Einsatz -> nicht mehr zurueckparken
            table.remove(self.zurueck, i)
        elseif not self:isVehicleOccupied(v) then
            local vx, vz = self:vehiclePos(v)
            local daheim = dist(vx, vz, ziel.x, ziel.z) < 15
            if u.adFahrt and not daheim and dist(vx, vz, ziel.x, ziel.z) < 60 and not self:adIsDriving(v) then
                -- AutoDrive-Ziel erreicht, Stellplatz ist gleich daneben:
                -- das letzte Stueck wird gesetzt, sobald du nicht hinschaust
                u.adFahrt = false
                self:setBlaulicht(v, false)
            end
            if daheim then
                self:setBlaulicht(v, false)
                u.adFahrt = false
                table.remove(self.zurueck, i)
            elseif u.adFahrt then
                local was, warum = self:festfahrPruefen(u, v, now)
                if was == "neustart" and self:adNeustart(u, v) then
                    log("%s %s - AutoDrive neu gestartet (Rueckweg).", u.label, warum)
                elseif was ~= "ok" then
                    self:adStop(v)
                    u.adFahrt = false
                    if self:teleportVehicle(v, ziel.x, ziel.z, ziel.ry) then
                        log("%s %s - zurueck auf den Stellplatz versetzt.", u.label, warum)
                        self:setBlaulicht(v, false)
                        table.remove(self.zurueck, i)
                    end
                end
            elseif not self:playerNear(vx, vz, R) and not self:playerNear(ziel.x, ziel.z, R)
                or (now > (u.backAt or now) + self.AUSRUECKEN.notWarte and not self:playerNear(ziel.x, ziel.z, self.AUSRUECKEN.notRadius)) then
                if self:teleportVehicle(v, ziel.x, ziel.z, ziel.ry) then
                    self:setBlaulicht(v, false)
                    table.remove(self.zurueck, i)
                end
            end
        elseif self:isVehicleOccupied(v) then
            -- Spieler faehrt selbst zurueck
            table.remove(self.zurueck, i)
        end
    end
end

-- Notfall: Fahrzeug direkt an die Einsatzstelle setzen (Status 4)
function FFE:anEinsatzstelleVersetzen(a, u, v, warum)
    self:adStop(v)
    u.adFahrt = false
    local slot = self:takeParkplatz(a, u)
    if slot ~= nil and self:teleportVehicle(v, slot.x, slot.z, slot.ry) then
        u.amOrt = true
        if u.status == "3" then
            u.arriveAt = g_time or 0
        end
        self:setBlaulicht(v, true)
        log("%s %s - an die Einsatzstelle versetzt.", u.label, warum or "")
        self:journal(a, u.label .. " " .. (warum or "") .. " – an die Einsatzstelle versetzt")
        return true
    end
    return false
end

-- Tablet-Knopf "Festgefahren? Alle freisetzen": alle KI-Fahrzeuge sofort dorthin, wo sie hingehoeren
function FFE:alleFreisetzen()
    local n = 0
    if not self:feature("ausruecken") then
        return 0
    end
    local a = self.alarm
    if a ~= nil and a.units ~= nil and not a.done then
        for _, u in ipairs(a.units) do
            local v = u.entry ~= nil and u.entry.vehicle or nil
            if v ~= nil and not self:isVehicleOccupied(v) and (u.status == "3" or u.status == "4") and not u.amOrt then
                if self:anEinsatzstelleVersetzen(a, u, v, "freigesetzt") then
                    n = n + 1
                end
            end
        end
    end
    for i = #(self.zurueck or {}), 1, -1 do
        local u = self.zurueck[i]
        local v = u.entry ~= nil and u.entry.vehicle or nil
        local ziel = u.entry ~= nil and self:parkZiel(u.entry) or nil
        if v ~= nil and ziel ~= nil and not self:isVehicleOccupied(v) then
            self:adStop(v)
            u.adFahrt = false
            if self:teleportVehicle(v, ziel.x, ziel.z, ziel.ry) then
                self:setBlaulicht(v, false)
                table.remove(self.zurueck, i)
                n = n + 1
            end
        end
    end
    return n
end

-- Wohin parkt die KI ein Fahrzeug nach dem Einsatz?
-- 1. auf seinen Stellplatz (Tablet: "Stellplatz übernehmen")
-- 2. sonst auf einen freien Platz neben der Wache (fester Platz je Fahrzeug)
-- 3. ohne Wache: bleibt stehen, wo es ist
function FFE:parkZiel(e)
    if e.spot ~= nil then
        return e.spot
    end
    if self.wache == nil then
        return nil
    end
    local idx = 1
    for i, f in ipairs(self.fleet) do
        if f == e then idx = i end
    end
    local row, col = math.floor((idx - 1) / 6), (idx - 1) % 6
    return { x = self.wache.x + 18 + row * 14, z = self.wache.z - 25 + col * 9, ry = 0, auto = true }
end

-- beim Einsatzende: Fahrzeuge auf den Rueckweg schicken
function FFE:onUnitZurueck(u)
    local e = u.entry
    local v = e ~= nil and e.vehicle or nil
    if v == nil or not self:feature("ausruecken") or not self.settings.echtAusruecken then
        return
    end
    if u.adFahrt then
        self:adStop(v)
        u.adFahrt = false
    end
    u.amOrt = false
    u.slot = nil
    if self:isVehicleOccupied(v) then
        return
    end
    -- Spieler sieht das Fahrzeug oder wartet an der Wache -> mit AutoDrive zurueckfahren
    local vx, vz = self:vehiclePos(v)
    local R = self.AUSRUECKEN.sichtRadius
    local ziel = self:parkZiel(e)
    if ziel ~= nil and self:adCanDrive(v) and (self:playerNear(vx, vz, R) or self:playerNear(ziel.x, ziel.z, R)) then
        local marker = self:adNearestMarker(ziel.x, ziel.z, 150)
        if marker ~= nil then
            self:adFahrtStarten(u, v, marker, (u.backAt or g_time) - (g_time or 0))
        end
    end
    self.zurueck = self.zurueck or {}
    table.insert(self.zurueck, u)
end

-- ---------------------------------------------------------------------------
-- Einsatztagebuch
-- ---------------------------------------------------------------------------
function FFE:journal(a, text)
    if a == nil then
        return
    end
    a.journal = a.journal or {}
    table.insert(a.journal, { zeit = self:getTimeString(), text = text })
    while #a.journal > 30 do
        table.remove(a.journal, 1)
    end
end
