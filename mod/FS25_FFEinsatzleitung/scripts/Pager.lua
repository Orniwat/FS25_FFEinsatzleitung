-- =============================================================================
-- FF Einsatzleitung  -  Melder: Sound, Kartenpunkt, Anzeige
--
-- Copyright (c) 2026 Orniwat & iowi. Alle Rechte vorbehalten.
-- Weitergabe, Veraenderung oder erneutes Hochladen nur mit Erlaubnis der Autoren.
-- =============================================================================

local log = FFE.log

-- ---------------------------------------------------------------------------
-- Sound
-- ---------------------------------------------------------------------------
function FFE:playSound(index)
    local sample = self.samples[index] or self.samples[1]
    if sample == nil then
        return
    end
    if playSample ~= nil then
        playSample(sample, 1, self.settings.volume, 0, 0, 0)
    end
end

function FFE:stopSounds()
    for _, sample in pairs(self.samples) do
        if stopSample ~= nil then
            stopSample(sample, 0, 0)
        end
    end
end

-- ---------------------------------------------------------------------------
-- Karten-Wegpunkt
-- ---------------------------------------------------------------------------
-- Eigene Hotspot-Klasse mit eigenem Symbol (das Standard-PlaceableHotspot hat ohne
-- Gebaeude kein Icon und bringt die Kartenansicht zum Absturz).
FFEHotspot = {}
local FFEHotspot_mt = nil
if Class ~= nil and PlaceableHotspot ~= nil then
    FFEHotspot_mt = Class(FFEHotspot, PlaceableHotspot)
end

function FFEHotspot.new(iconFile)
    local self = PlaceableHotspot.new(FFEHotspot_mt)
    self.width, self.height = getNormalizedScreenValues(44, 44)
    self.icon = Overlay.new(iconFile, 0, 0, self.width, self.height)
    self.iconSmall = Overlay.new(iconFile, 0, 0, self.width, self.height)
    return self
end

function FFEHotspot.getCategory(self)
    return MapHotspot.CATEGORY_MISSION or MapHotspot.CATEGORY_STEERABLE
end

function FFEHotspot.getIsPersistent(self)
    return false
end

function FFEHotspot.getRenderLast(self)
    return true
end

function FFEHotspot.getIsVisible(self)
    return true
end

function FFE:createHotspot()
    self:removeHotspot()
    if self.alarm == nil or self.alarm.x == nil or FFEHotspot_mt == nil then
        return
    end
    local iconFile = Utils.getFilename("textures/hotspot_einsatz.dds", self.modDirectory)
    local hotspot = FFEHotspot.new(iconFile)
    if hotspot.icon == nil or hotspot.icon.width == nil then
        log("Wegpunkt: Hotspot-Symbol konnte nicht geladen werden.")
        return
    end
    if hotspot.setName ~= nil then
        hotspot:setName(self.alarm.code .. " " .. self.alarm.detail)
    end
    hotspot:setWorldPosition(self.alarm.x, self.alarm.z)
    g_currentMission:addMapHotspot(hotspot)
    self.hotspot = hotspot
    if g_currentMission.setMapTargetHotspot ~= nil then
        g_currentMission:setMapTargetHotspot(hotspot)
    end
end

function FFE:removeHotspot()
    if self.hotspot ~= nil then
        local hotspot = self.hotspot
        self.hotspot = nil
        if g_currentMission ~= nil then
            if g_currentMission.mapTargetHotspot == hotspot and g_currentMission.setMapTargetHotspot ~= nil then
                g_currentMission:setMapTargetHotspot(nil)
            end
            if g_currentMission.removeMapHotspot ~= nil then
                g_currentMission:removeMapHotspot(hotspot)
            end
        end
        if hotspot.delete ~= nil then
            hotspot:delete()
        end
    end
end

-- ---------------------------------------------------------------------------
-- Zeichnen
-- Das Gehaeuse ist eine Textur (textures/pager_gehaeuse.dds, 1024x1024).
-- Alle Masse unten sind Entwurfs-Pixel: die Textur entspricht 368x368 px,
-- das Gehaeuse sitzt darin bei BODY, das Display bei LCD, die LED bei LED.
-- ---------------------------------------------------------------------------
local TEX  = 368
local BODY = { x = 8,   y = 6,    w = 352, h = 262 }
local LCD  = { x = 33,  y = 43,   w = 302, h = 136 }
local LED  = { x = 302, y = 17.5, w = 34,  h = 10 }

local COL = {
    lcdOn    = { 0.906, 0.761, 0.353, 1.00 },
    lcdOff   = { 0.561, 0.592, 0.514, 1.00 },
    ink      = { 0.090, 0.098, 0.059, 1.00 },
    ledRed   = { 1.000, 0.227, 0.165, 1.00 },
    ledDim   = { 0.300, 0.060, 0.050, 1.00 },
    ledAmber = { 0.910, 0.647, 0.118, 1.00 },
    ledGreen = { 0.184, 0.420, 0.227, 1.00 },
    body     = { 0.110, 0.114, 0.125, 0.97 },
    hint     = { 0.900, 0.890, 0.860, 0.85 },
}

function FFE:rect(x, y, w, h, c)
    if self.overlay ~= nil then
        self.overlay:setPosition(x, y)
        self.overlay:setDimension(w, h)
        self.overlay:setColor(c[1], c[2], c[3], c[4])
        self.overlay:render()
    elseif drawFilledRect ~= nil then
        drawFilledRect(x, y, w, h, c[1], c[2], c[3], c[4])
    end
end

local function upper(str)
    str = tostring(str or "")
    if utf8ToUpper ~= nil then
        local r = utf8ToUpper(str)
        if r ~= nil then
            return r
        end
    end
    return string.upper(str)
end

local function clip(str, n)
    str = tostring(str or "")
    if string.len(str) > n then
        local cut = string.sub(str, 1, n - 1)
        -- kein halbes UTF-8-Zeichen (Umlaute) stehen lassen
        while string.len(cut) > 0 do
            local b = string.byte(cut, string.len(cut))
            if b < 128 then
                break
            end
            cut = string.sub(cut, 1, -2)
            if b >= 192 then
                break
            end
        end
        return cut .. "."
    end
    return str
end

local function mmss(ms)
    local s = math.max(0, math.floor((ms or 0) / 1000))
    return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

function FFE:draw()
    if not self.isLoaded then
        return
    end
    if self.tablet ~= nil and self.tablet.open then
        self:drawTablet()
    end
    if not self.visible or (self.tablet ~= nil and self.tablet.open) then
        return
    end
    if g_gui ~= nil and g_gui.getIsGuiVisible ~= nil and g_gui:getIsGuiVisible() then
        return
    end
    self:drawPager()
    setTextBold(false)
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextColor(1, 1, 1, 1)
end

function FFE:drawPager()
    local aspect = g_screenAspectRatio or (16 / 9)
    local bodyW = 0.19 * (self.settings.pagerScale or 1)
    local sx = bodyW / BODY.w                  -- Bildschirmbreite je Entwurfs-Pixel
    local sy = sx * aspect                     -- Bildschirmhoehe je Entwurfs-Pixel
    local bodyLeft = self.settings.posX or (1 - bodyW - 0.012)
    local bodyBottom = self.settings.posY or 0.20
    local ox = bodyLeft - BODY.x * sx
    local top = bodyBottom + (BODY.y + BODY.h) * sy   -- Bildschirm-y der Texturoberkante

    local function X(px) return ox + px * sx end
    local function Y(py) return top - py * sy end

    -- Gehaeuse
    if self.housing ~= nil then
        self.housing:setPosition(ox, top - TEX * sy)
        self.housing:setDimension(TEX * sx, TEX * sy)
        self.housing:setColor(1, 1, 1, 1)
        self.housing:render()
    else
        self:rect(X(BODY.x), Y(BODY.y + BODY.h), BODY.w * sx, BODY.h * sy, COL.body)
    end

    local a = self.alarm
    local alarmActive = a ~= nil and not a.quittiert

    -- LED
    local led = COL.ledGreen
    if a ~= nil then
        if alarmActive then
            led = self.blinkOn and COL.ledRed or COL.ledDim
        else
            led = COL.ledAmber
        end
    end
    self:rect(X(LED.x + 2), Y(LED.y + LED.h - 1.5), (LED.w - 4) * sx, (LED.h - 3) * sy, led)

    -- Display-Hintergrund (Licht an bei Einsatz)
    local lcdCol = a ~= nil and COL.lcdOn or COL.lcdOff
    self:rect(X(LCD.x), Y(LCD.y + LCD.h), LCD.w * sx, LCD.h * sy, lcdCol)

    -- Text im Display: x/baseline in px relativ zum Display
    local function T(px, py, size, str, bold, align, col)
        setTextBold(bold == true)
        setTextAlignment(align or RenderText.ALIGN_LEFT)
        local c = col or COL.ink
        setTextColor(c[1], c[2], c[3], c[4])
        renderText(X(LCD.x + px), Y(LCD.y + py), size * sy, self:L(str))
    end

    local R, C = RenderText.ALIGN_RIGHT, RenderText.ALIGN_CENTER

    if a ~= nil then
        local now = g_time or 0
        T(9, 15, 11, "1/1  " .. (a.tag or ""))
        T(293, 15, 11, a.zeit or "", false, R)

        -- invertierter Balken (blinkt, bis quittiert)
        if not alarmActive or self.blinkOn then
            self:rect(X(LCD.x + 6), Y(LCD.y + 38), (LCD.w - 12) * sx, 18 * sy, COL.ink)
            T(12, 34, 14, "ALARM", true, nil, lcdCol)
            T(290, 34, 14, a.code, true, R, lcdCol)
        else
            T(12, 34, 14, "ALARM", true)
            T(290, 34, 14, a.code, true, R)
        end

        T(9, 62, 20, clip(upper(self:L(a.detail)), 22), true)
        T(9, 81, 13, clip(upper(self:L(a.ort)), 34))

        local units
        if a.ausgerueckt then
            units = self:statusLine(a)
        else
            units = a.kraefte or ""
        end
        T(9, 100, 12, clip(units, 42))

        local left, right = "", ""
        if a.mode == "warten" then
            left = self:kiFahrzeug(a) .. " RÜCKT AUS " .. mmss(a.deadline - now)
        elseif a.mode == "spieler" then
            left = "DEIN EINSATZ"
        elseif a.mode == "ki" then
            if a.kiRestMs ~= nil then
                left = self:kiFahrzeug(a) .. " VOR ORT " .. mmss(a.kiRestMs)
            else
                left = self:kiFahrzeug(a) .. " AUF ANFAHRT"
            end
        end
        if alarmActive then
            right = "OK=QUITT."
        end
        T(9, 128, 11, left)
        T(293, 128, 11, right, false, R)

        -- Tastenhinweis unter dem Melder
        setTextColor(COL.hint[1], COL.hint[2], COL.hint[3], COL.hint[4])
        setTextBold(false)
        setTextAlignment(C)
        local hint = alarmActive and "[Alt+Q] Quittieren   [Alt+Shift+E] Einsatz beenden" or "[Alt+Shift+E] Einsatz beenden   [Alt+M] ausblenden"
        renderText(X(BODY.x + BODY.w / 2), Y(BODY.y + BODY.h + 16), 11 * sy, self:L(hint))
    else
        T(9, 15, 11, self:getDayString())
        local busy = #self.returning > 0 and (#self.returning .. " FZG STATUS 1") or ""
        T(293, 15, 11, busy, false, R)
        T(151, 80, 50, self:getTimeString(), false, C)
        T(151, 101, 13, clip(upper(self.settings.wehrName) .. " - BEREIT", 34), false, C)
        T(9, 128, 11, "LETZT: " .. clip(upper(self:L(self.history[1] or "-")), 30))
    end
end
