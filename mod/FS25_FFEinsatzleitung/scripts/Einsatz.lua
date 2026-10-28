-- =============================================================================
-- FF Einsatzleitung  -  Ausrueckzeit, Fahrzeugstatus und KI-Loeschzug
--
-- Ablauf eines Einsatzes:
--   warten   Alarm ist raus, Fahrzeuge alarmiert (Status A), Ausrueckzeit laeuft
--   spieler  du sitzt in einem Fuhrpark-Fahrzeug oder bist an der Einsatzstelle
--   ki       Ausrueckzeit abgelaufen, du bist nicht da -> die KI arbeitet den Einsatz ab
--
-- Unabhaengig davon ruecken die Fahrzeuge nach Ablauf der Ausrueckzeit aus
-- (Status 3), kommen an (4), fahren nach dem Einsatz frei ueber Funk zurueck (1) und sind auf der Wache (2).
-- (In Baden-Wuerttemberg gibt es fuer die Feuerwehr keinen Status 8 - Rueckfahrt ist Status 1.)
-- In 0.3 bewegen sich die Fahrzeuge noch nicht wirklich - nur Status und Zeiten.
--
-- Copyright (c) 2026 Orniwat & iowi. Alle Rechte vorbehalten.
-- Weitergabe, Veraenderung oder erneutes Hochladen nur mit Erlaubnis der Autoren.
-- =============================================================================

local log = FFE.log

local function dist(x1, z1, x2, z2)
    if x1 == nil or x2 == nil then
        return nil
    end
    return math.sqrt((x1 - x2) ^ 2 + (z1 - z2) ^ 2)
end

-- Alarmierung nach AAO: Fuhrpark-Fahrzeuge, fehlende stellt die Nachbarwehr
function FFE:dispatchAlarm(a)
    a.units = {}
    a.mode = "warten"
    a.deadline = (g_time or 0) + self.settings.ausrueckzeitMin * 60000
    a.journal = {}

    local row = self.aao[a.code] or {}
    local types = {}
    for _, typ in ipairs(self.FAHRZEUGTYPEN) do
        if row[typ] ~= nil then
            table.insert(types, typ)
        end
    end
    for typ, _ in pairs(row) do
        local known = false
        for _, t in ipairs(types) do
            if t == typ then known = true end
        end
        if not known then
            table.insert(types, typ)
        end
    end

    for _, typ in ipairs(types) do
        for _ = 1, row[typ] do
            local e = self:findFreeFleetUnit(typ)
            if e ~= nil then
                e.busy = true
                table.insert(a.units, { label = self:unitLabel(e), short = self:unitShort(e), typ = typ, entry = e, status = "A" })
            elseif not self:feature("fuhrpark") or self:nachbarwehrFor(a.code) then
                table.insert(a.units, { label = typ .. " (Nachbarwehr)", short = typ .. "*", typ = typ, virtuell = true, status = "A" })
            end
        end
    end
    if #a.units == 0 then
        table.insert(a.units, { label = "HLF (Nachbarwehr)", short = "HLF*", typ = "HLF", virtuell = true, status = "A" })
    end

    local names = {}
    for _, u in ipairs(a.units) do
        table.insert(names, u.short)
    end
    a.kraefte = table.concat(names, " ")
    self:journal(a, string.format("Alarm %s  %s – %s", a.code, a.detail or "", a.kraefte))
end

function FFE:unitAusruecken(a, u, now)
    u.status = "3"
    u.arriveAt = now + self:travelTimeMs(a, u.virtuell, u) + math.random(0, 30) * 1000
    self:journal(a, "Status 3: " .. u.label)
    self:safeCall("Ausruecken", self.onUnitAusruecken, a, u)
end

-- Nachalarmieren einer Fahrzeugklasse (aus dem Tablet)
function FFE:nachalarmieren(klasse)
    local a = self.alarm
    if a == nil or a.units == nil then
        return false, "Kein laufender Einsatz."
    end
    local e = self:findFreeFleetUnit(klasse)
    local u
    if e ~= nil then
        e.busy = true
        u = { label = self:unitLabel(e), short = self:unitShort(e), typ = klasse, entry = e, status = "A" }
    else
        u = { label = klasse .. " (Nachbarwehr)", short = klasse .. "*", typ = klasse, virtuell = true, status = "A" }
    end
    table.insert(a.units, u)
    a.kraefte = (a.kraefte or "") .. " " .. u.short
    self:journal(a, "Nachalarmiert: " .. u.label)
    if a.ausgerueckt then
        self:unitAusruecken(a, u, g_time or 0)
    end
    return true, u.label .. " nachalarmiert."
end

-- Fahrzeit Wache -> Einsatzstelle in ms (Echtzeit, grob geschaetzt)
-- u (optional): Einheit - echte Fahrzeuge fahren von dort los, wo sie gerade stehen
-- (nicht jedes Auto steht immer an der Wache, z. B. nach einem Doppelalarm)
function FFE:travelTimeMs(a, virtuell, u)
    local sec = 300
    local fx, fz = nil, nil
    if u ~= nil and u.entry ~= nil and u.entry.vehicle ~= nil and self.vehiclePos ~= nil then
        fx, fz = self:vehiclePos(u.entry.vehicle)
    end
    if fx == nil and self.wache ~= nil then
        fx, fz = self.wache.x, self.wache.z
    end
    local d = dist(fx, fz, a.x, a.z)
    if d ~= nil then
        sec = d * 1.4 / 13.9 + 45          -- Umweg-Faktor 1.4, ~50 km/h, 45 s Ausruecken
        sec = math.max(60, math.min(900, sec))
    end
    if virtuell then
        sec = sec + 180                     -- Nachbarwehr hat den laengeren Weg
    end
    return sec * 1000
end

-- Name des KI-Fahrzeugs fuer Melder/Tablet: bevorzugt das HLF, sonst das erste Fahrzeug ("KI-HLF")
function FFE:kiFahrzeug(a)
    local typ = nil
    for _, u in ipairs(a.units or {}) do
        if u.typ == "HLF" then typ = "HLF" break end
        typ = typ or u.typ
    end
    if self:sprache() ~= "de" then
        return "AI " .. (typ or "HLF")
    end
    return "KI-" .. (typ or "HLF")
end

function FFE:statusLine(a)
    local parts = {}
    for _, u in ipairs(a.units or {}) do
        table.insert(parts, u.short .. ":" .. u.status)
    end
    return table.concat(parts, " ")
end

function FFE:updateEinsatz(dt)
    local now = g_time or 0
    local a = self.alarm

    if a ~= nil and a.units ~= nil and not a.done then
        local px, pz = self:getPlayerPosition()
        local d = dist(px, pz, a.x, a.z)
        local near = d ~= nil and d <= self.settings.vorOrtRadius
        local inFleet = self:findFleetEntryByVehicle(self:getPlayerVehicle()) ~= nil

        if near and not a.spielerVorOrt then
            a.spielerVorOrt = true
            log("Du bist an der Einsatzstelle.")
            self:journal(a, "Spieler an der Einsatzstelle")
        end

        -- Spieler faehrt ein Fahrzeug der Wache, das nicht alarmiert war -> rueckt mit aus
        local pv = self:getPlayerVehicle()
        local pe = self:findFleetEntryByVehicle(pv)
        if pe ~= nil then
            local dabei = false
            for _, u in ipairs(a.units) do
                if u.entry == pe then dabei = true end
            end
            if not dabei then
                pe.busy = true
                local u = { label = self:unitLabel(pe), short = self:unitShort(pe), typ = pe.klasse, entry = pe, status = "3", arriveAt = now + 3600000 }
                table.insert(a.units, u)
                self:journal(a, u.label .. " rückt mit dem Spieler aus")
            end
        end

        if a.mode == "warten" then
            if near or inFleet then
                a.mode = "spieler"
                log("Du rueckst aus - der Einsatz gehoert dir.")
                self:journal(a, "Spieler rückt aus")
            elseif now >= a.deadline then
                a.mode = "ki"
                log("Ausrueckzeit abgelaufen - %s rueckt aus.", self:kiFahrzeug(a))
                self:journal(a, self:kiFahrzeug(a) .. " rückt aus")
            end
        elseif a.mode == "ki" and near then
            a.mode = "spieler"
            log("Du hast den Einsatz von der KI uebernommen.")
            self:journal(a, "Spieler übernimmt von der KI")
        end

        -- Ausruecken nach Ablauf der Ausrueckzeit (oder sobald du selbst losfaehrst)
        if not a.ausgerueckt and (now >= a.deadline or a.mode == "spieler") then
            a.ausgerueckt = true
            for _, u in ipairs(a.units) do
                if u.status == "A" then
                    self:unitAusruecken(a, u, now)
                end
            end
            log("Status 3: %s", a.kraefte)
        end

        for _, u in ipairs(a.units) do
            -- vom Spieler gefahrenes Fahrzeug: angekommen, wenn es an der Einsatzstelle ist
            if u.status == "3" and u.entry ~= nil and u.entry.vehicle ~= nil and self:isVehicleOccupied(u.entry.vehicle) then
                local vx, vz = self:vehiclePos(u.entry.vehicle)
                if dist(vx, vz, a.x, a.z) ~= nil and dist(vx, vz, a.x, a.z) <= self.settings.vorOrtRadius then
                    u.arriveAt = now
                    u.amOrt = true
                end
            end
            if u.status == "3" and u.arriveAt ~= nil and now >= u.arriveAt then
                u.status = "4"
                if a.firstArrival == nil then
                    a.firstArrival = now
                end
                log("Status 4: %s an der Einsatzstelle.", u.label)
                self:journal(a, "Status 4: " .. u.label)
            end
        end

        -- KI arbeitet den Einsatz ab
        if a.mode == "ki" and a.firstArrival ~= nil then
            local dauer = (a.stichwort ~= nil and a.stichwort.dauerMin or 6) * 60000
            a.kiRestMs = math.max(0, a.firstArrival + dauer - now)
            if a.kiRestMs <= 0 then
                self:finishByKI(a)
            end
        end
    end

    -- Rueckfahrten (Status 1 -> 2)
    for i = #self.returning, 1, -1 do
        local u = self.returning[i]
        if now >= (u.backAt or 0) then
            u.status = "2"
            if u.entry ~= nil then
                u.entry.busy = false
            end
            table.remove(self.returning, i)
            log("Status 2: %s wieder einsatzbereit.", u.label)
        end
    end
end

function FFE:payReward(amount, why)
    if amount == nil or amount <= 0 then
        return
    end
    if g_currentMission == nil or g_currentMission.addMoney == nil then
        log("Verguetung %s: %d (nicht moeglich)", why or "", amount)
        return
    end
    local farmId = 1
    if g_currentMission.getFarmId ~= nil then
        farmId = g_currentMission:getFarmId() or 1
    end
    local moneyType = (MoneyType ~= nil and (MoneyType.OTHER or MoneyType.MISSIONS)) or nil
    g_currentMission:addMoney(amount, farmId, moneyType, true, true)
    log("Verguetung %s: %d", why or "", amount)
end

function FFE:finishByKI(a)
    a.done = true
    log("KI-Loeschzug: Einsatz %s %s abgearbeitet.", a.code, a.detail)
    if a.epScenario ~= nil then
        self:abortEPScenario()
    end
    if self.settings.kiVerguetung and a.stichwort ~= nil then
        self:payReward(math.floor(a.stichwort.lohn / 2), "KI-Einsatz")
    end
    a.endText = "EINSATZ BEENDET (KI)"
    self:endEinsatz(false)
end

-- wird beim Beenden jedes Einsatzes aufgerufen (aus endEinsatz)
function FFE:finishEinsatz(a)
    local now = g_time or 0
    -- eigener Alarm, du warst vor Ort und beendest ihn -> volle Verguetung
    -- (Einsaetze des Emergency Packs bezahlt das Pack selbst)
    if not a.done and a.epScenario == nil and a.spielerVorOrt and a.stichwort ~= nil then
        self:payReward(a.stichwort.lohn, "eigener Einsatz")
    end
    a.done = true
    for _, u in ipairs(a.units or {}) do
        if u.status == "3" or u.status == "4" then
            u.status = "1"
            u.backAt = now + self:travelTimeMs(a, u.virtuell)   -- Rueckweg Einsatzstelle -> Wache
            table.insert(self.returning, u)
            self:safeCall("Rueckweg", self.onUnitZurueck, u)
        elseif u.entry ~= nil then
            u.status = "2"
            u.entry.busy = false
        end
    end
end
