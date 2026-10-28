-- =============================================================================
-- FF Einsatzleitung  -  EL-Tablet (Alt+T): Lage, Fuhrpark, AAO, Wache
--
-- Einfache Sofort-Oberflaeche: jedes Bild wird neu gezeichnet, Klickflaechen werden
-- beim Zeichnen gesammelt und beim naechsten Mausklick ausgewertet.
-- Alle Masse sind Entwurfs-Pixel des Tablet-Bildschirms (1136 x 756, Ursprung oben links),
-- passend zu den Entwuerfen in design/.
--
-- Copyright (c) 2026 Orniwat & iowi. Alle Rechte vorbehalten.
-- Weitergabe, Veraenderung oder erneutes Hochladen nur mit Erlaubnis der Autoren.
-- =============================================================================

local log = FFE.log

-- Rahmen-Textur (textures/tablet_rahmen.dds) = 1200 x 820 Entwurfs-Pixel, Bildschirm bei 32/32
local FRAME = { w = 1200, h = 820, sx = 32, sy = 32 }
local SCREEN = { w = 1136, h = 756 }
local TABS = {
    { id = "lage",     y = 76,  de = "LAGE",     en = "INCIDENT" },
    { id = "fuhrpark", y = 146, de = "FUHRPARK", en = "FLEET",    feature = "fuhrpark" },
    { id = "aao",      y = 216, de = "AAO",      en = "DISPATCH", feature = "fuhrpark" },
    { id = "wache",    y = 286, de = "WACHE",    en = "STATION" },
}
local KARTE_TAB_Y = 426

local C = {
    screen   = { 0.055, 0.067, 0.078, 1 },
    header   = { 0.071, 0.090, 0.110, 1 },
    line     = { 0.133, 0.165, 0.200, 1 },
    card     = { 0.082, 0.106, 0.129, 1 },
    row      = { 0.102, 0.133, 0.165, 1 },
    rowHover = { 0.141, 0.188, 0.235, 1 },
    field    = { 0.055, 0.071, 0.086, 1 },
    border   = { 0.212, 0.251, 0.294, 1 },
    text     = { 0.910, 0.906, 0.890, 1 },
    muted    = { 0.700, 0.725, 0.755, 1 },
    dim      = { 0.460, 0.495, 0.535, 1 },
    orange   = { 0.941, 0.541, 0.235, 1 },
    orangeBg = { 0.227, 0.141, 0.071, 1 },
    onOrange = { 0.090, 0.071, 0.047, 1 },
    red      = { 0.784, 0.212, 0.122, 1 },
    redBg    = { 0.165, 0.090, 0.082, 1 },
    redText  = { 1.000, 0.698, 0.659, 1 },
    green    = { 0.184, 0.561, 0.306, 1 },
    amber    = { 0.890, 0.635, 0.102, 1 },
    blue     = { 0.141, 0.353, 0.541, 1 },
    tabSel   = { 0.300, 0.380, 0.470, 0.35 },
}

local STATUS_COL = { ["2"] = C.green, ["3"] = C.amber, ["4"] = C.red, ["1"] = C.blue, A = C.dim }

-- ---------------------------------------------------------------------------
-- Oeffnen / Schliessen
-- ---------------------------------------------------------------------------
function FFE:initTablet()
    self.tablet = {
        open = false,
        tab = "fuhrpark",
        hits = {},
        mx = -1, my = -1,
        sel = nil,           -- { kind = "neu"|"wache", ref = ... }
        form = nil,          -- Formular fuer das ausgewaehlte Fahrzeug
        focus = nil,         -- { get = fn, set = fn } fuer Texteingabe
        showAll = false,
        scrollNeu = 0,
        scrollWache = 0,
        confirmRemove = false,
        msg = nil, msgUntil = 0,
    }
end

function FFE:toggleTablet()
    if self.tablet == nil then
        self:initTablet()
    end
    if self.tablet.open then
        self:closeTablet()
    else
        self:openTablet()
    end
end

function FFE:openTablet()
    if self.tablet == nil then
        self:initTablet()
    end
    if self.tablet.open then
        return
    end
    self.tablet.open = true
    self.tablet.focus = nil
    self.tablet.unregCache = nil
    if self.alarm ~= nil then
        self.tablet.tab = "lage"
    end
    -- eigener Eingabe-Kontext: Spieler und Kamera bewegen sich nicht, solange das Tablet offen ist
    self.tablet.contextPushed = false
    if g_inputBinding ~= nil then
        if g_inputBinding.setContext ~= nil then
            g_inputBinding:setContext("FFE_TABLET", true, false)
            self.tablet.contextPushed = true
        end
        if g_inputBinding.setShowMouseCursor ~= nil then
            g_inputBinding:setShowMouseCursor(true)
        end
    end
    self.registeredContext = nil
end

function FFE:closeTablet()
    if self.tablet == nil or not self.tablet.open then
        return
    end
    self.tablet.open = false
    self.tablet.focus = nil
    if self.tablet.contextPushed and g_inputBinding ~= nil and g_inputBinding.revertContext ~= nil then
        g_inputBinding:revertContext(true)
    end
    self.tablet.contextPushed = false
    if g_inputBinding ~= nil and g_inputBinding.setShowMouseCursor ~= nil then
        g_inputBinding:setShowMouseCursor(false)
    end
    self.registeredContext = nil
end

function FFE:onActionTablet()
    local now = g_time or 0
    if self.lastTabletToggle ~= nil and now - self.lastTabletToggle < 250 then
        return
    end
    self.lastTabletToggle = now
    self:toggleTablet()
end

function FFE:tabletMessage(text)
    self.tablet.msg = text
    self.tablet.msgUntil = (g_time or 0) + 4000
end

-- ---------------------------------------------------------------------------
-- Eingaben (aus mouseEvent / keyEvent des Mods)
-- ---------------------------------------------------------------------------
function FFE:tabletMouseEvent(posX, posY, isDown, isUp, button)
    local t = self.tablet
    if t == nil or not t.open then
        return
    end
    t.mx, t.my = posX, posY
    if not isDown then
        return
    end
    -- Mausrad: Listen scrollen
    if button == 4 or button == 5 then
        local d = button == 4 and -1 or 1
        for i = #t.hits, 1, -1 do
            local h = t.hits[i]
            if h.scroll ~= nil and posX >= h.x and posX <= h.x + h.w and posY >= h.y and posY <= h.y + h.h then
                h.scroll(d)
                return
            end
        end
        return
    end
    for i = #t.hits, 1, -1 do
        local h = t.hits[i]
        if h.fn ~= nil and posX >= h.x and posX <= h.x + h.w and posY >= h.y and posY <= h.y + h.h then
            if h.id ~= "field" then
                t.focus = nil
            end
            h.fn(button)
            return
        end
    end
    t.focus = nil
end

local function utf8Chop(s)
    local i = string.len(s)
    while i > 0 do
        local b = string.byte(s, i)
        if b < 128 or b >= 192 then
            return string.sub(s, 1, i - 1)
        end
        i = i - 1
    end
    return ""
end

local function utf8Char(code)
    if unicodeToUtf8 ~= nil then
        local r = unicodeToUtf8(code)
        if r ~= nil then
            return r
        end
    end
    if code < 128 then
        return string.char(code)
    elseif code < 2048 then
        return string.char(192 + math.floor(code / 64), 128 + code % 64)
    end
    return string.char(224 + math.floor(code / 4096), 128 + math.floor(code / 64) % 64, 128 + code % 64)
end

function FFE:tabletKeyEvent(unicode, sym, modifier, isDown)
    local t = self.tablet
    if t == nil or not t.open or not isDown then
        return
    end
    local KEY = Input or {}
    if sym == KEY.KEY_esc then
        if t.focus ~= nil then
            t.focus = nil
        else
            self:closeTablet()
        end
        return
    end
    local f = t.focus
    if f == nil then
        return
    end
    if sym == KEY.KEY_backspace then
        f.set(utf8Chop(f.get() or ""))
    elseif sym == KEY.KEY_return or sym == KEY.KEY_KP_enter then
        t.focus = nil
    elseif unicode ~= nil and unicode >= 32 and unicode ~= 127 then
        local cur = f.get() or ""
        if string.len(cur) < (f.max or 40) then
            f.set(cur .. utf8Char(unicode))
        end
    end
end

-- ---------------------------------------------------------------------------
-- Zeichenhelfer (Entwurfs-Pixel -> Bildschirm)
-- ---------------------------------------------------------------------------
local G = {}   -- Geometrie des aktuellen Bilds

local function X(px) return G.ox + px * G.sx end
local function Y(py) return G.top - py * G.sy end

function FFE:tR(px, py, w, h, col)
    self:rect(X(px), Y(py + h), w * G.sx, h * G.sy, col)
end

function FFE:tBorder(px, py, w, h, col, t)
    t = t or 1
    self:tR(px, py, w, t, col)
    self:tR(px, py + h - t, w, t, col)
    self:tR(px, py, t, h, col)
    self:tR(px + w - t, py, t, h, col)
end

function FFE:tText(px, py, size, str, col, bold, align)
    size = math.max(size, 13)          -- kleiner wird im Spiel unleserlich
    str = self:L(str)                  -- Spielsprache (Sprache.lua)
    -- Text wird im Spiel immer UEBER allen Flaechen gezeichnet. Deshalb sammeln wir ihn
    -- und zeichnen ihn am Ende - so koennen gesperrte Bereiche ihn noch abdunkeln/ausblenden.
    local q = self.tablet ~= nil and self.tablet.textQueue or nil
    if q ~= nil then
        table.insert(q, { px = px, py = py, size = size, str = tostring(str or ""), col = col or C.text, bold = bold, align = align })
        return
    end
    self:tTextNow(px, py, size, str, col, bold, align)
end

function FFE:tTextNow(px, py, size, str, col, bold, align)
    setTextBold(bold == true)
    setTextAlignment(align or RenderText.ALIGN_LEFT)
    local c = col or C.text
    setTextColor(c[1], c[2], c[3], c[4])
    renderText(X(px), Y(py), size * G.sy, tostring(str or ""))
end

local function clip(str, n)
    str = FFE:L(str or "")           -- erst uebersetzen, dann kuerzen
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

function FFE:tHover(px, py, w, h)
    local t = self.tablet
    local x0, y0 = X(px), Y(py + h)
    return t.mx >= x0 and t.mx <= x0 + w * G.sx and t.my >= y0 and t.my <= y0 + h * G.sy
end

function FFE:tHit(id, px, py, w, h, fn, scroll)
    table.insert(self.tablet.hits, { id = id, x = X(px), y = Y(py + h), w = w * G.sx, h = h * G.sy, fn = fn, scroll = scroll })
end

-- style: "normal" | "primary" | "danger" | "chip" | "chipSel" | "ghost"
function FFE:tButton(id, px, py, w, h, label, style, fn, size)
    local hover = self:tHover(px, py, w, h)
    local bg, fg, br = C.row, C.text, C.border
    if style == "primary" then
        bg, fg, br = C.orange, C.onOrange, nil
    elseif style == "danger" then
        bg, fg, br = C.redBg, C.redText, { 0.353, 0.165, 0.141, 1 }
    elseif style == "chipSel" then
        bg, fg, br = C.orangeBg, { 1, 0.816, 0.659, 1 }, C.orange
    elseif style == "ghost" then
        bg, fg, br = C.card, C.muted, C.line
    end
    if hover and style ~= "primary" then
        bg = C.rowHover
    elseif hover then
        bg = { 1, 0.62, 0.32, 1 }
    end
    self:tR(px, py, w, h, bg)
    if br ~= nil then
        self:tBorder(px, py, w, h, br, style == "chipSel" and 2 or 1)
    end
    size = size or 15
    self:tText(px + w / 2, py + h / 2 + size * 0.36, size, label, fg, style == "primary" or style == "chipSel", RenderText.ALIGN_CENTER)
    self:tHit(id, px, py, w, h, fn)
end

-- Textfeld: get/set liefern bzw. setzen den Wert
function FFE:tField(px, py, w, h, value, get, set, max, placeholder)
    local t = self.tablet
    local focused = t.focus ~= nil and t.focus.get == get
    self:tR(px, py, w, h, C.field)
    self:tBorder(px, py, w, h, focused and C.orange or C.border, focused and 2 or 1)
    local shown = value or ""
    local col = C.text
    if shown == "" and not focused then
        shown, col = placeholder or "", C.dim
    end
    if focused and self.blinkOn then
        shown = shown .. "|"
    end
    self:tText(px + 12, py + h / 2 + 6, 17, clip(shown, math.floor(w / 9)), col)
    self:tHit("field", px, py, w, h, function()
        t.focus = { get = get, set = set, max = max }
    end)
end

function FFE:tLabel(px, py, text)
    self:tText(px, py, 13, text, C.muted, true)
end

-- ---------------------------------------------------------------------------
-- Zeichnen
-- ---------------------------------------------------------------------------
function FFE:drawTablet()
    local t = self.tablet
    if t == nil or not t.open then
        return
    end
    if g_gui ~= nil and g_gui.getIsGuiVisible ~= nil and g_gui:getIsGuiVisible() then
        self:closeTablet()
        return
    end
    t.hits = {}
    t.textQueue = {}

    local aspect = g_screenAspectRatio or (16 / 9)
    -- Tablet so gross wie moeglich, maximal 82 % der Breite bzw. 90 % der Hoehe
    local frameW = 0.82
    local frameH = frameW * FRAME.h / FRAME.w * aspect
    if frameH > 0.90 then
        frameH = 0.90
        frameW = frameH / (FRAME.h / FRAME.w * aspect)
    end
    local fx = (1 - frameW) / 2
    local fy = (1 - frameH) / 2
    local scaleX = frameW / FRAME.w
    G.sx = scaleX
    G.sy = scaleX * aspect
    G.ox = fx + FRAME.sx * scaleX
    G.top = fy + frameH - FRAME.sy * G.sy

    if self.tabletFrame ~= nil then
        self.tabletFrame:setPosition(fx, fy)
        self.tabletFrame:setDimension(frameW, frameH)
        self.tabletFrame:setColor(1, 1, 1, 1)
        self.tabletFrame:render()
    else
        self:rect(fx, fy, frameW, frameH, { 0.141, 0.149, 0.165, 1 })
        self:tR(0, 0, SCREEN.w, SCREEN.h, C.screen)
        self:tR(0, 0, 88, SCREEN.h, { 0.078, 0.098, 0.125, 1 })
    end

    -- Reiter (Symbole sind in der Rahmen-Textur, hier nur Auswahl und Klickflaeche)
    for _, tab in ipairs(TABS) do
        if t.tab == tab.id then
            self:tR(8, tab.y, 72, 64, C.tabSel)
            self:tR(8, tab.y + 60, 72, 4, C.orange)
        elseif self:tHover(8, tab.y, 72, 64) then
            self:tR(8, tab.y, 72, 64, { 1, 1, 1, 0.06 })
        end
        -- Beschriftung (nicht in der Textur, damit sie uebersetzt werden kann)
        self:tText(44, tab.y + 52, 12, self:sprache() == "de" and tab.de or tab.en, { 0.663, 0.690, 0.722, 1 }, true, RenderText.ALIGN_CENTER)
        if tab.feature ~= nil and not self:feature(tab.feature) then
            -- gesperrt: ausgegraut mit "BALD"
            self:tR(8, tab.y, 72, 64, { 0.078, 0.098, 0.125, 0.72 })
            self:tR(46, tab.y + 2, 34, 16, C.orangeBg)
            self:tText(63, tab.y + 14, 10, "BALD", C.orange, true, RenderText.ALIGN_CENTER)
        end
        self:tHit("tab_" .. tab.id, 8, tab.y, 72, 64, function()
            t.tab = tab.id
            t.focus = nil
            t.confirmRemove = false
        end)
    end
    -- Reiter INFO (nicht in der Rahmen-Textur, daher hier gezeichnet)
    local iy = 356
    if t.tab == "info" then
        self:tR(8, iy, 72, 64, C.tabSel)
        self:tR(8, iy + 60, 72, 4, C.orange)
    elseif self:tHover(8, iy, 72, 64) then
        self:tR(8, iy, 72, 64, { 1, 1, 1, 0.06 })
    end
    self:tBorder(33, iy + 10, 22, 22, { 0.663, 0.690, 0.722, 1 }, 2)
    self:tText(44, iy + 28, 15, "i", { 0.663, 0.690, 0.722, 1 }, true, RenderText.ALIGN_CENTER)
    self:tText(44, iy + 52, 12, "INFO", { 0.663, 0.690, 0.722, 1 }, true, RenderText.ALIGN_CENTER)
    if self.infoNeu then
        self:tR(52, iy + 4, 30, 16, C.orange)
        self:tText(67, iy + 16, 11, "NEU", C.onOrange, true, RenderText.ALIGN_CENTER)
    end
    self:tHit("tab_info", 8, iy, 72, 64, function()
        t.tab = "info"
        t.focus = nil
        self:markInfoGesehen()
    end)

    -- Reiter KARTE (Lagekarte, ebenfalls hier gezeichnet)
    local ky = KARTE_TAB_Y
    local kcol = { 0.663, 0.690, 0.722, 1 }
    if t.tab == "karte" then
        self:tR(8, ky, 72, 64, C.tabSel)
        self:tR(8, ky + 60, 72, 4, C.orange)
    elseif self:tHover(8, ky, 72, 64) then
        self:tR(8, ky, 72, 64, { 1, 1, 1, 0.06 })
    end
    self:tBorder(31, ky + 10, 26, 22, kcol, 2)
    self:tR(43, ky + 10, 2, 22, kcol)
    self:tR(31, ky + 20, 26, 2, kcol)
    self:tR(46, ky + 13, 6, 6, C.red)
    self:tText(44, ky + 52, 12, "KARTE", kcol, true, RenderText.ALIGN_CENTER)
    self:tHit("tab_karte", 8, ky, 72, 64, function()
        t.tab = "karte"
        t.focus = nil
    end)

    self:tText(44, 740, 13, self:getTimeString(), C.muted, false, RenderText.ALIGN_CENTER)

    -- Kopfzeile
    self:tR(88, 0, SCREEN.w - 88, 64, C.header)
    self:tR(88, 63, SCREEN.w - 88, 1, C.line)
    self:tButton("close", SCREEN.w - 150, 12, 136, 40, "Schließen  Alt+T", "ghost", function() self:closeTablet() end, 14)

    local gesperrt = nil
    for _, tab in ipairs(TABS) do
        if tab.id == t.tab and tab.feature ~= nil and not self:feature(tab.feature) then
            gesperrt = tab.id
        end
    end
    if gesperrt ~= nil then
        self:drawGesperrterReiter(gesperrt)
    elseif t.tab == "lage" then
        self:drawTabLage()
    elseif t.tab == "fuhrpark" then
        self:drawTabFuhrpark()
    elseif t.tab == "aao" then
        self:drawTabAAO()
    elseif t.tab == "info" then
        self:drawTabInfo()
    elseif t.tab == "karte" then
        self:drawTabKarte()
    else
        self:drawTabWache()
    end

    -- kurze Rueckmeldung unten
    if t.msg ~= nil and (g_time or 0) < t.msgUntil then
        self:tR(300, SCREEN.h - 56, 640, 40, C.orangeBg)
        self:tBorder(300, SCREEN.h - 56, 640, 40, C.orange, 1)
        self:tText(620, SCREEN.h - 30, 15, t.msg, C.text, false, RenderText.ALIGN_CENTER)
    end

    local q = t.textQueue
    t.textQueue = nil
    for _, e in ipairs(q or {}) do
        if not e.weg then
            self:tTextNow(e.px, e.py, e.size, e.str, e.col, e.bold, e.align)
        end
    end

    setTextBold(false)
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextColor(1, 1, 1, 1)
end

-- grobe Textbox in Entwurfs-Pixeln (fuer Abdunkeln/Ausblenden)
local function textBox(e)
    local n = 0
    for _ in string.gmatch(e.str, "[^\128-\191]") do n = n + 1 end
    local w = n * e.size * 0.52
    local x0 = e.px
    if e.align == RenderText.ALIGN_CENTER then
        x0 = e.px - w / 2
    elseif e.align == RenderText.ALIGN_RIGHT then
        x0 = e.px - w
    end
    return x0, e.py - e.size, x0 + w, e.py + e.size * 0.25
end

-- Text im Bereich abdunkeln (weg = true: ganz ausblenden)
function FFE:tTextImBereich(px, py, w, h, weg)
    for _, e in ipairs(self.tablet.textQueue or {}) do
        local x0, y0, x1, y1 = textBox(e)
        if x1 > px and x0 < px + w and y1 > py and y0 < py + h then
            if weg then
                e.weg = true
            else
                local c = e.col
                e.col = { c[1] * 0.4 + 0.03, c[2] * 0.4 + 0.04, c[3] * 0.4 + 0.05, c[4] or 1 }
            end
        end
    end
end

function FFE:tHeader(title, sub)
    self:tText(106, 31, 22, title, C.text, true)
    self:tText(106, 52, 14, sub or "", C.muted)
end

-- ---------------------------------------------------------------------------
-- Reiter LAGE
-- ---------------------------------------------------------------------------
local STATUS_TEXT = { A = "alarmiert", ["3"] = "Anfahrt", ["4"] = "vor Ort", ["1"] = "frei über Funk", ["2"] = "frei" }

function FFE:drawStatusRow(px, py, w, u, extra)
    self:tR(px, py, w, 44, C.row)
    local col = STATUS_COL[u.status] or C.dim
    self:tR(px + 10, py + 7, 30, 30, col)
    self:tText(px + 25, py + 28, 18, u.status, { 1, 1, 1, 1 }, true, RenderText.ALIGN_CENTER)
    self:tText(px + 52, py + 22, 16, u.label, C.text, true)
    self:tText(px + 52, py + 38, 12, STATUS_TEXT[u.status] or "", C.muted)
    if extra ~= nil then
        self:tText(px + w - 12, py + 28, 14, extra, C.text, false, RenderText.ALIGN_RIGHT)
    end
end

local function mmss(ms)
    local s = math.max(0, math.floor((ms or 0) / 1000))
    return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

function FFE:drawTabLage()
    local a = self.alarm
    local now = g_time or 0
    if a == nil then
        self:tHeader("Lage", self.settings.wehrName .. " · kein Einsatz")
        self:tR(100, 76, 620, 668, C.card)
        self:tText(410, 330, 26, "Kein laufender Einsatz", C.text, true, RenderText.ALIGN_CENTER)
        self:tText(410, 362, 15, "Der Melder alarmiert dich, sobald es einen Einsatz gibt.", C.muted, false, RenderText.ALIGN_CENTER)
        self:tButton("probealarm", 310, 400, 200, 46, "Probealarm", "primary", function()
            self:closeTablet()
            self:onActionTest()
        end)
        self:tLabel(118, 470, "LETZTE EINSÄTZE")
        for i, h in ipairs(self.history) do
            if i > 5 then break end
            self:tText(118, 470 + i * 26, 15, h, C.text)
        end

        self:tR(732, 76, 392, 668, C.card)
        self:tLabel(748, 102, "RÜCKFAHRT (STATUS 1)")
        if #self.returning == 0 then
            self:tText(748, 132, 15, "Alle Fahrzeuge einsatzbereit.", C.muted)
        end
        for i, u in ipairs(self.returning) do
            if i > 10 then break end
            self:drawStatusRow(748, 112 + (i - 1) * 50, 360, u, mmss((u.backAt or now) - now))
        end
        if not self:feature("ausruecken") then
            self:tButton("freisetzen", 748, 690, 360, 40, "Festgefahren? Alle heimholen  (ab 1.1)", "normal", function() end, 14)
            self:tSperre(744, 688, 368, 44, nil)
        elseif #(self.zurueck or {}) > 0 then
            self:tButton("freisetzen", 748, 690, 360, 40, "Festgefahren? Alle heimholen", "normal", function()
                local n = self:alleFreisetzen()
                self:tabletMessage(n .. " Fahrzeug(e) auf den Stellplatz gesetzt.")
            end, 14)
        end
        return
    end

    local modeText = {
        warten = self:kiFahrzeug(a) .. " rückt aus in " .. mmss((a.deadline or now) - now) .. " – oder du bist schneller",
        spieler = "Dein Einsatz",
        ki = a.kiRestMs ~= nil and (self:kiFahrzeug(a) .. " vor Ort · fertig in " .. mmss(a.kiRestMs)) or (self:kiFahrzeug(a) .. " auf Anfahrt – du kannst dazustoßen"),
    }
    self:tHeader(a.code .. "  " .. a.detail, (a.ort or "?") .. " · " .. (modeText[a.mode] or ""))

    -- links: Einsatz
    self:tR(100, 76, 620, 668, C.card)
    local chipCol = string.sub(a.code, 1, 1) == "B" and C.red or C.blue
    self:tR(118, 96, 90, 32, chipCol)
    self:tText(163, 119, 18, a.code, { 1, 1, 1, 1 }, true, RenderText.ALIGN_CENTER)
    self:tText(222, 120, 24, a.detail, C.text, true)
    self:tText(118, 158, 16, "Ort: " .. (a.ort or "?") .. "      Alarm: " .. (a.zeit or ""), C.muted)
    self:tText(118, 184, 16, modeText[a.mode] or "", a.mode == "ki" and C.amber or C.orange, true)

    self:tLabel(118, 222, self:feature("fuhrpark") and "EINHEITEN  (* = Nachbarwehr)" or "EINHEITEN DER NACHBARWEHR")
    for i, u in ipairs(a.units or {}) do
        if i > 10 then break end
        local extra = nil
        if u.status == "3" and u.arriveAt ~= nil then
            extra = mmss(u.arriveAt - now)
        end
        self:drawStatusRow(118, 232 + (i - 1) * 50, 584, u, extra)
    end

    -- rechts: Aktionen
    self:tR(732, 76, 392, 668, C.card)
    self:tLabel(748, 102, "AKTIONEN")
    local y = 116
    if not a.quittiert then
        self:tButton("quitt", 748, y, 360, 46, "Alarm quittieren", "primary", function() self:quitAlarm() end)
        y = y + 56
    end
    if a.epScenario ~= nil then
        self:tText(748, y - 6, 13, "Endet von selbst, wenn alles erledigt und aufgeräumt ist.", C.muted)
        y = y + 6
    end
    self:tButton("ende", 748, y, 360, 46, a.epScenario ~= nil and "Einsatz abbrechen" or "Einsatz beenden", "danger", function()
        self:abortEPScenario()
        self:endEinsatz(false)
        self:tabletMessage("Einsatz beendet.")
    end)
    y = y + 54
    local frei = self:feature("ausruecken")
    self:tButton("freisetzen", 748, y, 360, 38, frei and "Festgefahren? Alle zur Einsatzstelle" or "Festgefahren? Alle holen  (ab 1.1)", "normal", function()
        local n = self:alleFreisetzen()
        self:tabletMessage(n .. " Fahrzeug(e) an die Einsatzstelle gesetzt.")
    end, 14)
    if not frei then
        self:tSperre(744, y - 2, 368, 42, nil)
    end
    y = y + 62
    -- Nachalarmieren: ab 1.1 mit eigenem Fuhrpark, bis dahin ausgegraut
    local tagebuchZeilen = 10
    do
        local ny = y
        self:tLabel(748, y, "NACHALARMIEREN")
        if not self:feature("fuhrpark") then
            self:tR(890, y - 13, 70, 18, C.orangeBg)
            self:tText(925, y + 1, 11, "AB 1.1", C.orange, true, RenderText.ALIGN_CENTER)
        end
        local x = 748
        y = y + 10
        for i, k in ipairs({ "HLF", "LF", "TLF", "DLK", "RW", "ELW", "GW-T", "SW" }) do
            local w = 84
            if x + w > 1110 then
                x = 748
                y = y + 42
            end
            local have = self:findFreeFleetUnit(k) ~= nil
            self:tButton("nach_" .. i, x, y, w, 36, have and k or (k .. "*"), "chip", function()
                local _, msg = self:nachalarmieren(k)
                self:tabletMessage(msg)
            end, 14)
            x = x + w + 8
        end
        y = y + 52
        if not self:feature("fuhrpark") then
            self:tSperre(744, ny + 6, 368, y - ny - 10, nil)
        end
    end
    self:tLabel(748, y + 4, "EINSATZTAGEBUCH")
    local j = a.journal or {}
    local first = math.max(1, #j - (tagebuchZeilen - 1))
    local line = 0
    for i = #j, first, -1 do
        line = line + 1
        local e = j[i]
        self:tText(748, y + 8 + line * 22, 13, e.zeit .. "  " .. clip(self:L(e.text), 44), line == 1 and C.text or C.muted)
    end
end

-- ---------------------------------------------------------------------------
-- Reiter FUHRPARK
-- ---------------------------------------------------------------------------
function FFE:getUnregCached()
    local t = self.tablet
    local now = g_time or 0
    if t.unregCache == nil or now - (t.unregTime or 0) > 2000 then
        t.unregCache = self:getUnregisteredVehicles()
        t.unregTime = now
    end
    local list = {}
    for _, n in ipairs(t.unregCache) do
        if t.showAll or n.vorschlag ~= nil then
            table.insert(list, n)
        end
    end
    return list, #t.unregCache
end

function FFE:selectNeu(n)
    local t = self.tablet
    t.sel = { kind = "neu", ref = n }
    t.confirmRemove = false
    t.form = { bez = n.vorschlag or "", nr = "", call = "", custom = n.vorschlag == nil, spot = true }
    -- naechste freie Nummer vorschlagen
    local k = self:klasseFor(t.form.bez)
    local maxNr = 0
    for _, e in ipairs(self.fleet) do
        if e.klasse == k then
            maxNr = math.max(maxNr, tonumber(e.nr) or 1)
        end
    end
    if maxNr > 0 then
        t.form.nr = tostring(maxNr + 1)
    end
end

function FFE:selectWache(e)
    local t = self.tablet
    t.sel = { kind = "wache", ref = e }
    t.confirmRemove = false
    local custom = true
    for _, k in ipairs(self.FAHRZEUGKATALOG) do
        if k[1] == e.bez then
            custom = false
        end
    end
    t.form = { bez = e.bez or "", nr = e.nr or "", call = e.call or "", custom = custom, spot = false }
end

local CHIPS = { "HLF 10", "HLF 20", "LF 10", "LF 20", "TSF-W", "TLF 3000", "TLF-W", "DLK 23-12",
                "ELW 1", "KdoW", "RW", "GW-L 2", "GW-T", "SW 2000", "MTW" }

function FFE:drawTabFuhrpark()
    local t = self.tablet
    local neu, total = self:getUnregCached()
    self:tHeader("Fuhrpark", string.format("%s · %d Fahrzeuge auf der Wache · %d neu", self.settings.wehrName, #self.fleet, #neu))

    -- links oben: neu gekauft
    self:tR(100, 76, 330, 330, C.card)
    self:tLabel(114, 100, "NEU GEKAUFT")
    local rowsNeu = 4
    t.scrollNeu = math.max(0, math.min(t.scrollNeu, math.max(0, #neu - rowsNeu)))
    if #neu == 0 then
        self:tText(114, 140, 14, t.showAll and "Keine weiteren Fahrzeuge." or "Keine Feuerwehrfahrzeuge erkannt.", C.muted)
    end
    for i = 1, rowsNeu do
        local n = neu[i + t.scrollNeu]
        if n == nil then break end
        local y = 112 + (i - 1) * 58
        local sel = t.sel ~= nil and t.sel.kind == "neu" and t.sel.ref.key == n.key
        self:tR(112, y, 306, 52, sel and C.orangeBg or (self:tHover(112, y, 306, 52) and C.rowHover or C.row))
        if sel then self:tBorder(112, y, 306, 52, C.orange, 2) end
        self:tText(124, y + 22, 16, clip(n.name, 32), C.text, true)
        self:tText(124, y + 42, 13, n.vorschlag and ("Vorschlag: " .. n.vorschlag) or "kein Vorschlag", sel and { 1, 0.75, 0.56, 1 } or C.muted)
        self:tHit("neu_" .. i, 112, y, 306, 52, function() self:selectNeu(n) end)
    end
    self:tHit("scrollNeu", 112, 112, 306, 232, nil, function(d) t.scrollNeu = t.scrollNeu + d end)
    if #neu > rowsNeu then
        self:tText(414, 100, 12, string.format("%d-%d von %d", t.scrollNeu + 1, math.min(#neu, t.scrollNeu + rowsNeu), #neu), C.muted, false, RenderText.ALIGN_RIGHT)
    end
    -- Haken "alle zeigen"
    self:tR(114, 360, 20, 20, t.showAll and C.orange or C.field)
    self:tBorder(114, 360, 20, 20, C.border, 1)
    self:tText(144, 376, 14, string.format("Alle Fahrzeuge des Hofs zeigen (%d)", total), C.muted)
    self:tHit("showAll", 114, 356, 300, 28, function()
        t.showAll = not t.showAll
        t.scrollNeu = 0
    end)

    -- links unten: auf der Wache
    self:tR(100, 418, 330, 326, C.card)
    self:tLabel(114, 442, "AUF DER WACHE")
    local rowsW = 6
    t.scrollWache = math.max(0, math.min(t.scrollWache, math.max(0, #self.fleet - rowsW)))
    if #self.fleet == 0 then
        self:tText(114, 480, 14, "Noch keine Fahrzeuge.", C.muted)
        self:tText(114, 502, 14, "Oben ein Fahrzeug auswählen.", C.muted)
    end
    for i = 1, rowsW do
        local e = self.fleet[i + t.scrollWache]
        if e == nil then break end
        local y = 454 + (i - 1) * 46
        local sel = t.sel ~= nil and t.sel.kind == "wache" and t.sel.ref == e
        self:tR(112, y, 306, 40, sel and C.orangeBg or (self:tHover(112, y, 306, 40) and C.rowHover or C.row))
        if sel then self:tBorder(112, y, 306, 40, C.orange, 2) end
        self:tR(122, y + 8, 24, 24, e.busy and C.amber or C.green)
        self:tText(134, y + 26, 14, e.busy and "3" or "2", { 1, 1, 1, 1 }, true, RenderText.ALIGN_CENTER)
        self:tText(156, y + 26, 15, clip(self:unitLabel(e), 18), C.text, true)
        self:tText(406, y + 26, 12, clip(e.call or "", 16), C.muted, false, RenderText.ALIGN_RIGHT)
        self:tHit("wache_" .. i, 112, y, 306, 40, function() self:selectWache(e) end)
    end
    self:tHit("scrollWache", 112, 454, 306, 276, nil, function(d) t.scrollWache = t.scrollWache + d end)

    -- rechts: Formular
    self:tR(442, 76, 682, 668, C.card)
    if t.sel == nil or t.form == nil then
        self:tText(783, 360, 20, "Links ein Fahrzeug auswählen", C.muted, true, RenderText.ALIGN_CENTER)
        self:tText(783, 390, 15, "Neu gekaufte Fahrzeuge fügst du hier der Wache hinzu.", C.muted, false, RenderText.ALIGN_CENTER)
        return
    end
    local f = t.form
    local isNeu = t.sel.kind == "neu"
    local name = isNeu and t.sel.ref.name or (t.sel.ref.name or self:unitLabel(t.sel.ref))
    self:tText(462, 112, 24, clip(name, 40), C.text, true)
    self:tText(1104, 112, 13, isNeu and "neu gekauft" or "auf der Wache", C.muted, false, RenderText.ALIGN_RIGHT)

    self:tLabel(462, 146, "BEZEICHNUNG")
    local x, y = 462, 156
    for i, chip in ipairs(CHIPS) do
        local w = 26 + string.len(chip) * 8.5
        if x + w > 1106 then
            x = 462
            y = y + 44
        end
        local sel = not f.custom and f.bez == chip
        self:tButton("chip_" .. i, x, y, w, 36, chip, sel and "chipSel" or "chip", function()
            f.bez = chip
            f.custom = false
        end, 14)
        x = x + w + 6
    end
    local w = 92
    if x + w > 1106 then
        x = 462
        y = y + 44
    end
    self:tButton("chip_eigen", x, y, w, 36, "Eigene ...", f.custom and "chipSel" or "chip", function()
        f.custom = true
        t.focus = { get = function() return f.bez end, set = function(v) f.bez = v end, max = 20 }
    end, 14)
    y = y + 50
    if f.custom then
        self:tField(462, y, 300, 40, f.bez, function() return f.bez end, function(v) f.bez = v end, 20, "eigene Bezeichnung")
        y = y + 50
    end

    local klasse = (f.bez ~= nil and f.bez ~= "") and self:klasseFor(f.bez) or "-"
    self:tLabel(462, y + 14, "KLASSE (AAO)")
    self:tR(462, y + 22, 200, 40, C.field)
    self:tText(474, y + 48, 17, klasse, C.text, true)
    self:tLabel(680, y + 14, "NUMMER")
    self:tButton("nr_minus", 680, y + 22, 40, 40, "-", "normal", function()
        local n = (tonumber(f.nr) or 1) - 1
        f.nr = n >= 1 and tostring(n) or ""
    end, 18)
    self:tField(724, y + 22, 70, 40, f.nr, function() return f.nr end, function(v) f.nr = string.gsub(v, "%D", "") end, 3, "-")
    self:tButton("nr_plus", 798, y + 22, 40, 40, "+", "normal", function()
        f.nr = tostring((tonumber(f.nr) or 0) + 1)
    end, 18)
    self:tLabel(860, y + 14, "AUF DEM MELDER")
    self:tR(860, y + 22, 246, 40, C.field)
    self:tText(872, y + 48, 17, klasse .. (f.nr or ""), C.text)
    y = y + 76

    self:tLabel(462, y + 14, "FUNKRUFNAME (OPTIONAL)")
    self:tField(462, y + 22, 644, 40, f.call, function() return f.call end, function(v) f.call = v end, 32, "z.B. Florian Musterdorf 1/46-1")
    y = y + 76

    -- Stellplatz
    if isNeu then
        self:tR(462, y + 8, 22, 22, f.spot and C.orange or C.field)
        self:tBorder(462, y + 8, 22, 22, C.border, 1)
        self:tText(494, y + 26, 15, "Aktuelle Position als Stellplatz übernehmen", C.text)
        self:tHit("spot", 462, y + 4, 420, 30, function() f.spot = not f.spot end)
    else
        local e = t.sel.ref
        self:tButton("spot_set", 462, y + 2, 300, 38, "Stellplatz: aktuelle Position", "normal", function()
            if self:setStellplatzFor(e) then
                self:tabletMessage("Stellplatz für " .. self:unitLabel(e) .. " gespeichert.")
            else
                self:tabletMessage("Fahrzeug nicht gefunden.")
            end
        end, 14)
        self:tText(776, y + 26, 14, e.spot ~= nil and "gesetzt – hier parkt die KI nach dem Einsatz" or "nicht gesetzt – KI parkt neben der Wache", C.muted)
    end
    y = y + 50

    -- AAO-Hinweis
    if klasse ~= "-" then
        local count = 0
        for _, e in ipairs(self.fleet) do
            if e.klasse == klasse and not (t.sel.kind == "wache" and t.sel.ref == e) then
                count = count + 1
            end
        end
        count = count + 1
        self:tR(462, y, 644, 50, C.field)
        self:tText(476, y + 22, 14, string.format("%s: %d auf der Wache nach dem Speichern.", klasse, count), C.text)
        local missing = self:missingKlassen(klasse)
        self:tText(476, y + 42, 13, #missing > 0 and ("Fehlt für die AAO: " .. table.concat(missing, ", ") .. " – stellt die Nachbarwehr") or "Alle Klassen der AAO sind vorhanden.", C.muted)
    end

    -- Knoepfe
    if isNeu then
        self:tButton("abbrechen", 776, 690, 140, 44, "Abbrechen", "normal", function() t.sel = nil end)
        self:tButton("hinzufuegen", 926, 690, 180, 44, "Zur Wache hinzufügen", "primary", function()
            if f.bez == nil or f.bez == "" then
                self:tabletMessage("Bitte eine Bezeichnung wählen.")
                return
            end
            local ok, msg = self:registerVehicle(f.bez, f.nr ~= "" and f.nr or nil, f.call ~= "" and f.call or nil, t.sel.ref.vehicle)
            if ok and f.spot then
                local e = self:findFleetEntryByVehicle(t.sel.ref.vehicle)
                if e ~= nil then
                    self:setStellplatzFor(e)
                end
            end
            self:tabletMessage(msg)
            if ok then
                t.unregCache = nil
                local e = self:findFleetEntryByVehicle(t.sel.ref.vehicle)
                if e ~= nil then
                    self:selectWache(e)
                else
                    t.sel = nil
                end
            end
        end, 14)
    else
        local e = t.sel.ref
        self:tButton("entfernen", 462, 690, 220, 44, t.confirmRemove and "Wirklich entfernen?" or "Von der Wache nehmen", "danger", function()
            if not t.confirmRemove then
                t.confirmRemove = true
                return
            end
            for i, x2 in ipairs(self.fleet) do
                if x2 == e then
                    table.remove(self.fleet, i)
                    break
                end
            end
            self:tabletMessage(self:unitLabel(e) .. " von der Wache genommen.")
            t.sel = nil
            t.unregCache = nil
        end, 14)
        self:tButton("speichern", 966, 690, 140, 44, "Speichern", "primary", function()
            if f.bez == nil or f.bez == "" then
                self:tabletMessage("Bitte eine Bezeichnung wählen.")
                return
            end
            e.bez = f.bez
            e.klasse = self:klasseFor(f.bez)
            e.nr = f.nr ~= "" and f.nr or nil
            e.call = f.call ~= "" and f.call or nil
            self:sortFleetEntries()
            self:tabletMessage(self:unitLabel(e) .. " gespeichert.")
        end)
    end
end

-- Klassen aus der AAO, die nicht auf der Wache sind (extra = gleich hinzukommende Klasse)
function FFE:missingKlassen(extra)
    local missing = {}
    for _, k in ipairs(self.FAHRZEUGTYPEN) do
        local used = false
        for _, row in pairs(self.aao) do
            if row[k] ~= nil then used = true end
        end
        if used and not self:hasKlasse(k) and k ~= extra then
            table.insert(missing, k)
        end
    end
    return missing
end

-- ---------------------------------------------------------------------------
-- Reiter AAO
-- ---------------------------------------------------------------------------
function FFE:aaoColumns()
    local cols = {}
    for _, k in ipairs(self.FAHRZEUGTYPEN) do
        local used = self:hasKlasse(k)
        for _, row in pairs(self.aao) do
            if row[k] ~= nil then used = true end
        end
        if used then
            table.insert(cols, k)
        end
    end
    if #cols < 4 then
        for _, k in ipairs({ "ELW", "HLF", "LF", "DLK" }) do
            local have = false
            for _, c in ipairs(cols) do
                if c == k then have = true end
            end
            if not have then table.insert(cols, k) end
        end
    end
    while #cols > 10 do
        table.remove(cols)
    end
    return cols
end

function FFE:drawTabAAO()
    self:tHeader("Alarm- und Ausrückeordnung", "Linksklick +1, Rechtsklick -1  ·  grau = Klasse fehlt auf der Wache (Nachbarwehr)")
    self:tR(100, 76, 1024, 668, C.card)
    local cols = self:aaoColumns()
    local x0, labelW = 116, 200
    local nbW = 86
    local colW = math.floor((1108 - x0 - labelW - nbW - 8) / #cols)
    self:tText(x0 + 4, 104, 13, "STICHWORT", C.muted, true)
    for i, k in ipairs(cols) do
        local cx = x0 + labelW + (i - 1) * colW + colW / 2
        local have = self:hasKlasse(k)
        self:tText(cx, 104, 13, k, have and C.muted or C.dim, true, RenderText.ALIGN_CENTER)
    end
    self:tText(1108 - nbW / 2, 104, 13, "NACHBAR", C.muted, true, RenderText.ALIGN_CENTER)

    for r, s in ipairs(self.STICHWORTE) do
        local y = 114 + (r - 1) * 56
        local chipCol = string.sub(s.code, 1, 1) == "B" and C.red or (s.code == "TH OEL" and { 0.541, 0.353, 0.047, 1 } or C.blue)
        self:tR(x0, y + 12, 72, 26, chipCol)
        self:tText(x0 + 36, y + 30, 13, s.code, { 1, 1, 1, 1 }, true, RenderText.ALIGN_CENTER)
        self:tText(x0 + 80, y + 30, 13, clip(s.details[1], 16), C.muted)
        local row = self.aao[s.code] or {}
        for i, k in ipairs(cols) do
            local cx = x0 + labelW + (i - 1) * colW
            local n = row[k] or 0
            local have = self:hasKlasse(k)
            local hover = self:tHover(cx + 2, y + 2, colW - 4, 46)
            local bg = n > 0 and (have and { 0.141, 0.188, 0.235, 1 } or { 0.110, 0.125, 0.145, 1 }) or { 0.067, 0.086, 0.106, 1 }
            if hover then bg = C.rowHover end
            self:tR(cx + 2, y + 2, colW - 4, 46, bg)
            local fg = n > 0 and (have and C.text or C.muted) or C.dim
            self:tText(cx + colW / 2, y + 32, 18, n > 0 and (have and tostring(n) or (n .. "*")) or "-", fg, n > 0, RenderText.ALIGN_CENTER)
            self:tHit("aao_" .. r .. "_" .. i, cx + 2, y + 2, colW - 4, 46, function(button)
                local delta = (button == 3 or button == (Input and Input.MOUSE_BUTTON_RIGHT)) and -1 or 1
                local v = math.max(0, math.min(9, n + delta))
                self:setAAO(s.code, k, v)
            end)
        end
        local nb = self:nachbarwehrFor(s.code)
        self:tButton("nb_" .. r, 1108 - nbW + 6, y + 8, nbW - 6, 34, nb and "an" or "aus", nb and "chipSel" or "chip", function()
            if self.aaoNachbar[s.code] == false then
                self.aaoNachbar[s.code] = nil
            else
                self.aaoNachbar[s.code] = false
            end
        end, 14)
    end
    self:tText(x0, 640, 14, "* = Klasse fehlt auf der Wache, kommt von der Nachbarwehr (wenn dort \"an\").", C.muted)
    self:tButton("aao_standard", 884, 690, 224, 42, "Standard wiederherstellen", "normal", function()
        self:resetAAO()
        self:tabletMessage("AAO auf Standard zurückgesetzt.")
    end, 14)
end

-- Bereich ausgrauen: Inhalt bleibt sichtbar (Vorgeschmack), ist aber nicht bedienbar.
-- badge: kurzer Text oben rechts im Bereich, z. B. "KOMMT MIT 1.1"
function FFE:tSperre(px, py, w, h, badge, alpha)
    -- Klickflaechen im Bereich entfernen
    local x0, x1 = X(px), X(px + w)
    local y0, y1 = Y(py + h), Y(py)
    local rest = {}
    for _, hit in ipairs(self.tablet.hits) do
        local cx, cy = hit.x + hit.w / 2, hit.y + hit.h / 2
        if not (cx >= x0 and cx <= x1 and cy >= y0 and cy <= y1) or string.sub(hit.id or "", 1, 4) == "tab_" then
            table.insert(rest, hit)
        end
    end
    self.tablet.hits = rest
    self:tTextImBereich(px, py, w, h, false)
    self:tR(px, py, w, h, { 0.055, 0.067, 0.078, alpha or 0.72 })
    if badge ~= nil then
        local bw = math.max(96, string.len(badge) * 8 + 20)
        self:tR(px + w - bw - 6, py + 4, bw, 20, C.orangeBg)
        self:tBorder(px + w - bw - 6, py + 4, bw, 20, C.orange, 1)
        self:tText(px + w - bw / 2 - 6, py + 19, 11, badge, C.orange, true, RenderText.ALIGN_CENTER)
    end
end

-- gesperrte Funktion: "KOMMT BALD"
function FFE:tKommtBald(px, py, w, h, title, sub)
    self:tR(px, py, w, h, C.row)
    self:tBorder(px, py, w, h, C.line, 1)
    self:tR(px + 12, py + 14, 96, 20, C.orangeBg)
    self:tText(px + 60, py + 29, 11, "KOMMT BALD", C.orange, true, RenderText.ALIGN_CENTER)
    self:tText(px + 120, py + 30, 15, clip(title, 52), C.muted, true)
    if sub ~= nil then
        self:tText(px + 120, py + 48, 12, clip(sub, 96), C.dim)
    end
end

-- Seite fuer gesperrte Reiter
local KOMMT_BALD = {
    fuhrpark = {
        titel = "Fuhrpark", version = "1.1",
        text = {
            "Gekaufte Fahrzeuge zur Wache hinzufügen, z. B. HLF 20 oder DLK 23/12 –",
            "mit Nummer, Funkrufname und Stellplatz.",
            "Bei Alarm besetzen KI-Kameraden deine Fahrzeuge und rücken mit aus.",
            "Mit AutoDrive fahren sie selbst zur Einsatzstelle und zurück zur Wache.",
        },
    },
    aao = {
        titel = "Alarm- und Ausrückeordnung", version = "1.1",
        text = {
            "Pro Stichwort festlegen, welche Fahrzeuge ausrücken – per Klick.",
            "Nachbarwehr pro Stichwort an oder aus.",
            "Fehlende Fahrzeuge werden angezeigt.",
        },
    },
}

-- gesperrter Reiter: echter Inhalt ausgegraut, darueber ein Banner
function FFE:drawGesperrterReiter(id)
    local t = self.tablet
    t.focus = nil
    if id == "fuhrpark" then
        self:drawTabFuhrpark()
    elseif id == "aao" then
        self:drawTabAAO()
    else
        self:drawKommtBaldSeite(id)
        return
    end
    self:tSperre(100, 76, 1024, 668, nil, 0.82)
    local k = KOMMT_BALD[id] or { titel = id, version = "", text = {} }
    local bx, bw, bh = 162, 900, 120 + #k.text * 26
    local by = 410 - bh / 2
    self:tTextImBereich(bx - 4, by - 4, bw + 8, bh + 8, true)
    self:tR(bx, by, bw, bh, C.card)
    self:tBorder(bx, by, bw, bh, C.orange, 2)
    self:tR(bx + 24, by + 22, 150, 28, C.orangeBg)
    self:tText(bx + 99, by + 42, 14, "KOMMT MIT " .. k.version, C.orange, true, RenderText.ALIGN_CENTER)
    self:tText(bx + 190, by + 44, 22, k.titel, C.text, true)
    for i, l in ipairs(k.text) do
        self:tText(bx + 24, by + 68 + i * 26, 15, l, C.muted)
    end
    self:tText(bx + 24, by + bh - 18, 13, "Neuigkeiten im Reiter INFO · Discord: discord.gg/WKdQmKaVFG", C.dim)
end

function FFE:drawKommtBaldSeite(id)
    local k = KOMMT_BALD[id] or { titel = id, version = "", text = {} }
    self:tHeader(k.titel, "Kommt mit Version " .. k.version)
    self:tR(100, 76, 1024, 668, C.card)
    self:tR(140, 130, 140, 30, C.orangeBg)
    self:tText(210, 151, 15, "KOMMT BALD", C.orange, true, RenderText.ALIGN_CENTER)
    self:tText(140, 214, 30, k.titel, C.text, true)
    for i, l in ipairs(k.text) do
        self:tText(140, 262 + (i - 1) * 32, 18, l, C.muted)
    end
    local y = 262 + #k.text * 32 + 40
    self:tR(140, y, 944, 1, C.line)
    self:tText(140, y + 44, 16, "Bis dahin rückt bei jedem Alarm die Nachbarwehr aus – oder du fährst selbst hin.", C.text)
    self:tText(140, y + 74, 15, "Was sonst noch kommt, steht im Reiter INFO.", C.muted)
end

-- ---------------------------------------------------------------------------
-- Reiter KARTE: Lagekarte mit Einsatzstelle, Aufstellung und Anfahrt
-- (Ansicht, noch ohne Einsatzabschnitte und Zuweisen)
-- ---------------------------------------------------------------------------
local KARTE = { x = 118, y = 94, s = 632, zoom = { 80, 150, 300, 600, 1200 } }

local function himmelsrichtung(dx, dz)
    -- Karte: -z ist Norden
    local ang = math.deg(math.atan2(dx, -dz)) % 360
    local namen = { "N", "NO", "O", "SO", "S", "SW", "W", "NW" }
    if FFE:sprache() ~= "de" then
        namen = { "N", "NE", "E", "SE", "S", "SW", "W", "NW" }
    end
    return namen[math.floor((ang + 22.5) / 45) % 8 + 1]
end

local function km(m)
    if m >= 1000 then
        local t = string.format("%.1f km", m / 1000)
        if FFE:sprache() == "de" then
            t = t:gsub("%.", ",")
        end
        return t
    end
    return string.format("%d m", math.floor(m / 10 + 0.5) * 10)
end

function FFE:karteStrassen(cx, cz, r)
    -- AutoDrive-Netz als Strassen (gecacht je Ausschnitt)
    local k = self.tablet.karteCache
    if k ~= nil and k.cx == cx and k.cz == cz and k.r == r then
        return k.pts
    end
    local pts = {}
    if self.hasAutoDrive ~= nil and self:hasAutoDrive() then
        if type(ADGraphManager.getWayPoints) == "function" then
            for _, wp in pairs(ADGraphManager:getWayPoints() or {}) do
                if math.abs(wp.x - cx) < r and math.abs(wp.z - cz) < r then
                    table.insert(pts, { wp.x, wp.z })
                    if #pts > 4000 then break end
                end
            end
        end
    end
    self.tablet.karteCache = { cx = cx, cz = cz, r = r, pts = pts }
    return pts
end

-- Hintergrund: Karte der Map (Uebersichtsbild des Spiels), Ausschnitt um die Einsatzstelle.
-- Klappt das nicht (anderer Map-Aufbau), bleibt das Raster mit Strassen aus AutoDrive.
function FFE:karteHintergrund(mx, my, S, cx, cz, r)
    if self.karteBildFehlt then
        return false
    end
    local m = g_currentMission
    if self.karteBild == nil then
        -- Uebersichtsbild der Map suchen (je nach Map an anderer Stelle)
        local file = nil
        if m ~= nil then
            local kandidaten = { m.mapImageFilename }
            if m.missionInfo ~= nil and m.missionInfo.map ~= nil then
                table.insert(kandidaten, m.missionInfo.map.mapImageFilename)
            end
            if m.hud ~= nil and m.hud.ingameMap ~= nil and m.hud.ingameMap.mapOverlay ~= nil then
                table.insert(kandidaten, m.hud.ingameMap.mapOverlay.filename)
            end
            for _, v in pairs(kandidaten) do
                if type(v) == "string" and v ~= "" then
                    file = v
                    break
                end
            end
        end
        if file == nil or m.terrainSize == nil or m.terrainSize <= 0 or setOverlayUVs == nil then
            self.karteBildFehlt = true
            FFE.log("Lagekarte ohne Kartenbild (kein Uebersichtsbild oder Kartengroesse gefunden).")
            return false
        end
        self.karteBild = Overlay.new(file, 0, 0, 1, 1)
        FFE.log("Lagekarte: Kartenbild %s", file)
    end
    local size = m.terrainSize
    local h = size / 2
    local u0, u1 = (cx - r + h) / size, (cx + r + h) / size
    local vTop, vBot = 1 - (cz - r + h) / size, 1 - (cz + r + h) / size
    setOverlayUVs(self.karteBild.overlayId, u0, vBot, u0, vTop, u1, vBot, u1, vTop)
    self.karteBild:setPosition(X(mx), Y(my + S))
    self.karteBild:setDimension(S * G.sx, S * G.sy)
    self.karteBild:setColor(0.8, 0.8, 0.8, 1)
    self.karteBild:render()
    return true
end

function FFE:drawTabKarte()
    local t = self.tablet
    local a = self.alarm
    local px0, pz0 = self:getPlayerPosition()
    local cx, cz, titel, sub
    if a ~= nil and a.x ~= nil then
        cx, cz = a.x, a.z
        titel = "Lagekarte  " .. a.code .. "  " .. (a.detail or "")
        sub = (a.ort or "?") .. (self:feature("aufstellung") and " · Ansicht – Abschnitte und Zuweisen kommen bald" or " · Live-Karte des Einsatzes")
    elseif self.wache ~= nil then
        cx, cz = self.wache.x, self.wache.z
        titel, sub = "Lagekarte", "Kein laufender Einsatz – Ansicht der Wache"
    else
        cx, cz = px0 or 0, pz0 or 0
        titel, sub = "Lagekarte", "Kein laufender Einsatz – Wache noch nicht gesetzt (Reiter Wache)"
    end
    self:tHeader(titel, sub)

    t.zoomIdx = t.zoomIdx or 2
    if a ~= t.karteAlarm then
        t.karteAlarm = a
        t.zoomIdx = a ~= nil and 1 or 3
    end
    local r = KARTE.zoom[t.zoomIdx]
    local S, mx, my = KARTE.s, KARTE.x, KARTE.y
    local scale = S / (2 * r)
    local function P(x, z)
        return mx + S / 2 + (x - cx) * scale, my + S / 2 + (z - cz) * scale
    end
    local function drin(x, y, rand)
        rand = rand or 0
        return x >= mx + rand and x <= mx + S - rand and y >= my + rand and y <= my + S - rand
    end

    -- Hintergrund und Raster
    self:tR(mx - 8, my - 8, S + 16, S + 16, C.card)
    self:tR(mx, my, S, S, { 0.118, 0.161, 0.122, 1 })
    local mitBild = self:karteHintergrund(mx, my, S, cx, cz, r)
    local raster = r <= 300 and 50 or (r <= 600 and 100 or 250)
    local g0x = math.ceil((cx - r) / raster) * raster
    for gx = g0x, cx + r, raster do
        local x = P(gx, cz)
        self:tR(x, my, 1, S, { 1, 1, 1, 0.05 })
    end
    local g0z = math.ceil((cz - r) / raster) * raster
    for gz = g0z, cz + r, raster do
        local _, y = P(cx, gz)
        self:tR(mx, y, S, 1, { 1, 1, 1, 0.05 })
    end
    -- Strassen (AutoDrive-Netz) - nur ohne Kartenbild
    for _, p in ipairs(mitBild and {} or self:karteStrassen(cx, cz, r)) do
        local x, y = P(p[1], p[2])
        self:tR(x - 1.5, y - 1.5, 3, 3, { 0.80, 0.78, 0.70, 0.55 })
    end

    -- Wache
    if self.wache ~= nil then
        local x, y = P(self.wache.x, self.wache.z)
        if drin(x, y, 10) then
            self:tR(x - 11, y - 11, 22, 22, C.blue)
            self:tText(x, y + 6, 14, "W", { 1, 1, 1, 1 }, true, RenderText.ALIGN_CENTER)
        elseif a ~= nil then
            -- Richtung zur Wache am Kartenrand
            local dx, dz = self.wache.x - cx, self.wache.z - cz
            local f = (S / 2 - 22) / math.max(math.abs(dx), math.abs(dz)) / scale
            local ex, ey = P(cx + dx * f * 1, cz + dz * f * 1)
            self:tR(ex - 11, ey - 11, 22, 22, C.blue)
            self:tText(ex, ey + 6, 14, "W", { 1, 1, 1, 1 }, true, RenderText.ALIGN_CENTER)
            local d = math.sqrt(dx * dx + dz * dz)
            local tx = math.max(mx + 60, math.min(mx + S - 60, ex))
            local ty = ey < my + S / 2 and ey + 30 or ey - 18
            self:tText(tx, ty, 12, "Wache " .. km(d), C.text, true, RenderText.ALIGN_CENTER)
        end
    end

    -- Einsatzstelle mit Radius "vor Ort" und Aufstellung
    local aufstellung = {}
    if a ~= nil and a.x ~= nil then
        local ex, ey = P(a.x, a.z)
        local vr = (self.settings.vorOrtRadius or 150) * scale
        for i = 0, 47 do
            local w = i / 48 * 2 * math.pi
            local x, y = ex + math.sin(w) * vr, ey + math.cos(w) * vr
            if drin(x, y) then
                self:tR(x - 1, y - 1, 3, 3, { 0.784, 0.212, 0.122, 0.7 })
            end
        end
        if a.parkplaetze == nil and self.buildParkplaetze ~= nil then
            a.parkplaetze = self:buildParkplaetze(a)
        end
        local frei = 1
        for _, u in ipairs(self:feature("aufstellung") and a.units or {}) do
            local slot = u.slot
            if slot == nil and a.parkplaetze ~= nil then
                slot = a.parkplaetze[math.min(frei + (a.nextSlot or 0), #a.parkplaetze)]
                frei = frei + 1
            end
            if slot ~= nil then
                local x, y = P(slot.x, slot.z)
                if drin(x, y, 12) then
                    local col = STATUS_COL[u.status] or C.dim
                    local w = math.max(40, string.len(u.short or "") * 8 + 14)
                    if u.status == "4" then
                        self:tR(x - w / 2, y - 11, w, 22, col)
                    else
                        self:tR(x - w / 2, y - 11, w, 22, { 0.08, 0.10, 0.12, 0.85 })
                        self:tBorder(x - w / 2, y - 11, w, 22, col, 2)
                    end
                    self:tText(x, y + 5, 12, u.short or "?", { 1, 1, 1, 1 }, true, RenderText.ALIGN_CENTER)
                end
                table.insert(aufstellung, { u = u, slot = slot })
            end
        end
        self:tR(ex - 14, ey - 14, 28, 28, C.red)
        self:tBorder(ex - 14, ey - 14, 28, 28, { 1, 1, 1, 0.9 }, 2)
        self:tText(ex, ey + 6, 16, "E", { 1, 1, 1, 1 }, true, RenderText.ALIGN_CENTER)
    end

    -- du
    if px0 ~= nil then
        local x, y = P(px0, pz0)
        if drin(x, y, 6) then
            self:tR(x - 6, y - 6, 12, 12, { 0.35, 0.70, 1, 1 })
            self:tBorder(x - 6, y - 6, 12, 12, { 1, 1, 1, 1 }, 2)
        end
    end

    -- Nordpfeil, Massstab, Zoom
    self:tR(mx + 12, my + 12, 30, 34, { 0.08, 0.10, 0.12, 0.85 })
    self:tText(mx + 27, my + 30, 14, "N", C.text, true, RenderText.ALIGN_CENTER)
    self:tR(mx + 26, my + 34, 2, 8, C.text)
    local bar = raster * scale
    self:tR(mx + 14, my + S - 22, bar, 3, C.text)
    self:tText(mx + 14 + bar + 8, my + S - 16, 12, km(raster), C.text)
    self:tButton("zoom_in", mx + S - 52, my + 12, 40, 36, "+", "normal", function()
        t.zoomIdx = math.max(1, t.zoomIdx - 1)
    end, 18)
    self:tButton("zoom_out", mx + S - 52, my + 54, 40, 36, "-", "normal", function()
        t.zoomIdx = math.min(#KARTE.zoom, t.zoomIdx + 1)
    end, 18)

    -- rechts: Lage und Legende
    local rx = 780
    self:tR(rx - 16, 76, 1124 - rx + 16, 668, C.card)
    local y = 104
    if a ~= nil then
        self:tLabel(rx, y, "LAGE")
        local lines = {}
        if self.wache ~= nil and a.x ~= nil then
            local dx, dz = a.x - self.wache.x, a.z - self.wache.z
            table.insert(lines, "Von der Wache: " .. km(math.sqrt(dx * dx + dz * dz)) .. " Richtung " .. himmelsrichtung(dx, dz))
            table.insert(lines, "Anfahrt ca. " .. mmss(self:travelTimeMs(a, false)))
        end
        if px0 ~= nil and a.x ~= nil then
            local dx, dz = a.x - px0, a.z - pz0
            table.insert(lines, "Von dir: " .. km(math.sqrt(dx * dx + dz * dz)) .. " Richtung " .. himmelsrichtung(dx, dz))
        end
        table.insert(lines, "Kräfte: " .. #(a.units or {}) .. " Fahrzeuge")
        for i, l in ipairs(lines) do
            self:tText(rx, y + 4 + i * 24, 15, l, C.text)
        end
        y = y + 4 + #lines * 24 + 34
        if #aufstellung > 0 then
            self:tLabel(rx, y, "AUFSTELLUNG")
        end
        for i, au in ipairs(aufstellung) do
            if i > 7 then break end
            local dx, dz = au.slot.x - a.x, au.slot.z - a.z
            local col = STATUS_COL[au.u.status] or C.dim
            self:tR(rx, y + 10 + (i - 1) * 26, 8, 18, col)
            self:tText(rx + 16, y + 24 + (i - 1) * 26, 14,
                clip(au.u.short, 8) .. "  " .. km(math.sqrt(dx * dx + dz * dz)) .. " " .. himmelsrichtung(dx, dz) .. " der E-Stelle", C.text)
        end
        if #aufstellung > 0 then
            y = y + 24 + math.min(7, #aufstellung) * 26 + 20
        end
    else
        self:tLabel(rx, y, "LAGE")
        self:tText(rx, y + 28, 15, "Kein laufender Einsatz.", C.muted)
        y = y + 70
    end
    self:tLabel(rx, y, "LEGENDE")
    local leg = {
        { C.red, "E  Einsatzstelle (Kreis = vor Ort)" },
        { C.blue, "W  Wache" },
        { { 0.35, 0.70, 1, 1 }, "du" },
    }
    if self:feature("aufstellung") then
        table.insert(leg, { C.amber, "Fahrzeug auf Anfahrt (Status 3)" })
        table.insert(leg, { C.red, "Fahrzeug vor Ort (Status 4)" })
    end
    for i, l in ipairs(leg) do
        self:tR(rx, y + 10 + (i - 1) * 22, 12, 12, l[1])
        self:tText(rx + 20, y + 21 + (i - 1) * 22, 13, l[2], C.muted)
    end
    y = y + 10 + #leg * 22 + 14
    if y < 640 then
        if self:feature("aufstellung") then
            self:tKommtBald(rx, 670, 1108 - rx, 58, "Abschnitte & Zuweisen", "Fahrzeuge per Klick aufstellen")
        else
            self:tKommtBald(rx, 670, 1108 - rx, 58, "Aufstellung der Fahrzeuge", "Wer wo steht, Abschnitte, Zuweisen")
        end
    end
end

-- ---------------------------------------------------------------------------
-- Reiter WACHE
-- ---------------------------------------------------------------------------
function FFE:drawTabWache()
    self:tHeader("Wache und Einstellungen", "FF Einsatzleitung " .. self.VERSION .. " (" .. self.CHANNEL .. ") · © " .. self.AUTHORS)
    local st = self.settings
    self:tR(100, 76, 620, 668, C.card)

    self:tLabel(118, 104, "NAME DER WEHR")
    self:tField(118, 114, 584, 42, st.wehrName, function() return st.wehrName end, function(v) st.wehrName = v end, 28, "z.B. FF Musterdorf")

    self:tLabel(118, 190, "STANDORT DER WACHE")
    self:tButton("wache_set", 118, 200, 300, 42, "Meine Position als Wache setzen", "normal", function()
        local _, msg = self:setWacheHere()
        self:tabletMessage(msg)
    end, 14)
    self:tText(432, 227, 14, self.wache ~= nil and string.format("gesetzt (%.0f / %.0f)", self.wache.x, self.wache.z) or "noch nicht gesetzt", C.muted)
    if self:feature("fuhrpark") then self:tText(118, 256, 12, "Wache woanders gebaut? Einfach neu setzen und im Reiter Fuhrpark die Stellplätze neu übernehmen.", C.dim) end

    self:tLabel(118, 276, "AUSRÜCKZEIT (MINUTEN ECHTZEIT)")
    self:tButton("az_minus", 118, 286, 44, 42, "-", "normal", function()
        st.ausrueckzeitMin = math.max(0, (st.ausrueckzeitMin or 4) - 1)
    end, 18)
    self:tR(166, 286, 80, 42, C.field)
    self:tText(206, 314, 18, tostring(st.ausrueckzeitMin), C.text, true, RenderText.ALIGN_CENTER)
    self:tButton("az_plus", 250, 286, 44, 42, "+", "normal", function()
        st.ausrueckzeitMin = math.min(30, (st.ausrueckzeitMin or 4) + 1)
    end, 18)
    self:tText(310, 313, 14, "danach rückt ein KI-Fahrzeug aus und fährt mit an", C.muted)

    local function toggle(id, y, label, value, fn, sub)
        self:tR(118, y, 24, 24, value and C.orange or C.field)
        self:tBorder(118, y, 24, 24, C.border, 1)
        self:tText(154, y + 18, 16, label, C.text)
        if sub ~= nil then
            self:tText(154, y + 38, 13, sub, C.muted)
        end
        self:tHit(id, 114, y - 4, 560, 34, fn)
    end
    -- nur Schalter, die in dieser Version etwas bewirken
    local ty = 364
    toggle("nachbar", ty, "Nachbarwehr stellt fehlende Fahrzeuge", st.nachbarwehr, function() st.nachbarwehr = not st.nachbarwehr end,
        "pro Stichwort einstellbar im Reiter AAO")
    if not self:feature("fuhrpark") then
        self:tSperre(110, ty - 8, 600, 56, "AB 1.1")
    end
    ty = ty + 66
    toggle("zufall", ty, "Eigene Einsätze, wenn kein Emergency Pack aktiv ist", st.enabled, function()
        st.enabled = not st.enabled
        if st.enabled then self:scheduleNextAlarm() end
    end, "der Melder erzeugt dann selbst Alarme")
    ty = ty + 66
    toggle("kiGeld", ty, "KI-Einsätze werden vergütet (halber Lohn)", st.kiVerguetung, function() st.kiVerguetung = not st.kiVerguetung end,
        "wenn die Nachbarwehr den Einsatz ohne dich abarbeitet")
    ty = ty + 66
    toggle("echt", ty, "Fahrzeuge rücken wirklich aus", st.echtAusruecken, function() st.echtAusruecken = not st.echtAusruecken end,
        self:hasAutoDrive() and "mit AutoDrive fahren sie selbst, sonst werden sie unbemerkt versetzt" or "werden unbemerkt versetzt (mit AutoDrive fahren sie selbst)")
    if not self:feature("ausruecken") then
        self:tSperre(110, ty - 8, 600, 56, "AB 1.1")
    end

    -- rechts: Status
    self:tR(732, 76, 392, 668, C.card)
    self:tLabel(748, 104, "EMPFOHLENE MODS")
    local y = 112
    for _, m in ipairs(self.EMPFOHLEN) do
        local on = self:isModActive(m.mod)
        self:tR(748, y, 360, 54, C.row)
        self:tR(760, y + 17, 20, 20, on and C.green or C.amber)
        self:tText(792, y + 24, 16, m.name, C.text, true)
        self:tText(792, y + 44, 12, on and "aktiv" or clip("fehlt - " .. m.ohne, 44), C.muted)
        if m.feature ~= nil and not self:feature(m.feature) then
            self:tSperre(748, y, 360, 54, "AB 1.1")
        end
        y = y + 62
    end
    self:tLabel(748, y + 30, "ÜBERSICHT")
    local lines = {
        string.format("Fahrzeuge auf der Wache: %d", self:feature("fuhrpark") and #self.fleet or 0),
        string.format("Fehlende Klassen für die AAO: %d", self:feature("fuhrpark") and #self:missingKlassen(nil) or 0),
        "Gespeichert wird mit dem Spielstand.",
    }
    for i, l in ipairs(lines) do
        self:tText(748, y + 36 + i * 24, 14, l, C.text)
    end
    if not self:feature("fuhrpark") then
        self:tSperre(744, y + 42, 368, 52, "AB 1.1")
    end
end

-- ---------------------------------------------------------------------------
-- Reiter INFO: Neuigkeiten und was noch kommt (Text aus docs/SPIELER-INFO.md)
-- ---------------------------------------------------------------------------
local function wrap(text, n)
    local lines, line = {}, ""
    for word in string.gmatch(tostring(text or ""), "%S+") do
        if line == "" then
            line = word
        elseif string.len(line) + 1 + string.len(word) <= n then
            line = line .. " " .. word
        else
            table.insert(lines, line)
            line = word
        end
    end
    if line ~= "" then
        table.insert(lines, line)
    end
    return lines
end

function FFE:drawTabInfo()
    local info = (self:sprache() ~= "de" and self.INFO_EN) or self.INFO or { neu = {}, geplant = {} }
    self:tHeader("Neuigkeiten und Roadmap", "FF Einsatzleitung " .. self.VERSION .. " · © " .. self.AUTHORS)

    -- links: was neu ist (unten bleibt Platz fuer die Nutzungsregeln)
    self:tR(100, 76, 560, 668, C.card)
    local nutzung = info.nutzung or {}
    local nutzLines = {}
    for _, n in ipairs(nutzung) do
        for _, l in ipairs(wrap(n, 80)) do
            table.insert(nutzLines, l)
        end
    end
    local nutzTop = 744 - 40 - #nutzLines * 20
    local y = 104
    for vi, v in ipairs(info.neu or {}) do
        if y > nutzTop - 60 then break end
        self:tText(118, y, vi == 1 and 18 or 15, (vi == 1 and "NEU IN " or "") .. "VERSION " .. v.version, vi == 1 and C.orange or C.muted, true)
        y = y + (vi == 1 and 12 or 8)
        for _, item in ipairs(v.items or {}) do
            local lines = wrap(item, 66)
            if y + #lines * 22 > nutzTop - 20 then
                break   -- nur ganze Punkte zeigen
            end
            for li, l in ipairs(lines) do
                y = y + 22
                if li == 1 then
                    self:tR(122, y - 11, 6, 6, vi == 1 and C.orange or C.dim)
                end
                self:tText(138, y, 14, l, vi == 1 and C.text or C.muted)
            end
        end
        y = y + 34
    end

    -- Nutzungsregeln
    if #nutzLines > 0 then
        self:tR(112, nutzTop - 6, 536, #nutzLines * 20 + 40, C.field)
        self:tLabel(126, nutzTop + 16, "NUTZUNG")
        for i, l in ipairs(nutzLines) do
            self:tText(126, nutzTop + 18 + i * 20, 13, l, C.muted)
        end
    end

    -- rechts: was noch kommt
    self:tR(672, 76, 452, 668, C.card)
    self:tLabel(690, 104, "WAS NOCH KOMMT")
    y = 112
    local discordTop = 596
    for _, g in ipairs(info.geplant or {}) do
        local lines0 = wrap(g.text, 52)
        if y + 42 + math.min(3, #lines0) * 20 > discordTop - 8 then break end
        self:tR(690, y + 6, 54, 24, C.blue)
        self:tText(717, y + 24, 13, g.version, { 1, 1, 1, 1 }, true, RenderText.ALIGN_CENTER)
        self:tText(756, y + 24, 15, g.titel, C.text, true)
        local lines = wrap(g.text, 52)
        for li, l in ipairs(lines) do
            if li > 3 then break end
            self:tText(756, y + 24 + li * 20, 13, l, C.muted)
        end
        y = y + 34 + math.min(3, #lines) * 20 + 8
    end
    self:drawDiscordBox(684, discordTop, 428, 136)
end

-- Community-Kasten im INFO-Reiter: Leute auf den Discord holen
function FFE:drawDiscordBox(px, py, w, h)
    local link = self.DISCORD
    self:tR(px, py, w, h, { 0.200, 0.220, 0.420, 1 })
    self:tR(px, py, 6, h, { 0.345, 0.396, 0.949, 1 })
    self:tText(px + 22, py + 30, 13, "COMMUNITY", { 0.75, 0.78, 1, 1 }, true)
    self:tText(px + 22, py + 56, 19, "Komm auf unseren Discord!", { 1, 1, 1, 1 }, true)
    self:tText(px + 22, py + 80, 13, "Feedback, Ideen, Fehler melden, neue Versionen als Erste testen.", { 0.85, 0.87, 1, 1 })
    if link ~= nil and link ~= "" then
        self:tText(px + 22, py + 112, 16, (link:gsub("^https?://", "")), { 1, 1, 1, 1 }, true)
        if openWebFile ~= nil then
            self:tButton("discord", px + w - 140, py + 92, 124, 32, "Öffnen", "primary", function()
                openWebFile(link, "")
            end, 13)
        end
    else
        self:tText(px + 22, py + 112, 15, "Link folgt mit dem nächsten Update", { 0.85, 0.87, 1, 1 }, true)
    end
end
