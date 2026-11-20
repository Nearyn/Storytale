-- Storytale - SpokenQueueUI.lua
-- File de lecture dans le petit lecteur de Spoken : un bouton rond a cote de Stop / Passer
-- ouvre la liste des PNJ et des livres en attente. Cliquer un nom le fait lire tout de suite
-- (les autres gardent leur place) ; la croix le retire de la file.
local DWE = DWE
if not DWE then return end

local UI = {}
DWE.SpokenQueueUI = UI
local ICON_BOOK = "Interface\\Icons\\INV_Misc_Book_09"
local ICON_NPC = "Interface\\GossipFrame\\GossipGossipIcon"
local ROW_H, LIST_W = 22, 240

local function Env()
    local env = rawget(_G, "SpokenEnv")
    if type(env) ~= "table" then return nil end
    return env
end

local function Focus() return DWE.SpokenFocus end

-- La liste (sous le lecteur).
local function Over(frame)
    if frame.IsMouseOver then return frame:IsMouseOver() end
    local fn = rawget(_G, "MouseIsOver")
    return fn and fn(frame) or false
end
function UI.OverButton()
    for _, b in pairs(UI.buttons) do if b:IsVisible() and Over(b) then return true end end
    return false
end

local function BuildList()
    local f = CreateFrame("Frame", "StorytaleSpokenQueue", UIParent, "BackdropTemplate")
    f:SetFrameStrata("TOOLTIP")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    f:SetBackdropColor(.07, .065, .05, .98)
    f:SetBackdropBorderColor(.6, .57, .48, 1)
    f:Hide()
    table.insert(UISpecialFrames, "StorytaleSpokenQueue")
    -- Fermee (souris, Echap, manette ou vide) : la manette rend ses boutons au jeu.
    f:SetScript("OnHide", function()
        UI.padIdx = nil
        if DWE.PadListClosed then DWE.PadListClosed() end
    end)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", 12, -9)
    f.title:SetText(DWE.L.SPOKEN_QUEUE)
    f.empty = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.empty:SetPoint("TOPLEFT", 14, -32)
    f.empty:SetText(DWE.L.SPOKEN_QUEUE_EMPTY)
    f.rows = {}
    -- Un clic ailleurs ferme la liste.
    f:RegisterEvent("GLOBAL_MOUSE_DOWN")
    f:SetScript("OnEvent", function()
        if f:IsShown() and not Over(f) and not UI.OverButton() then f:Hide() end
    end)
    return f
end

local function Row(i)
    local f = UI.list
    local r = f.rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, f)
    r:SetHeight(ROW_H)
    r:SetPoint("TOPLEFT", 8, -26 - (i - 1) * ROW_H)
    r:SetPoint("TOPRIGHT", -8, -26 - (i - 1) * ROW_H)
    r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    r:GetHighlightTexture():SetAlpha(.25)
    -- Ligne choisie a la manette (meme reflet, plus marque).
    r.pad = r:CreateTexture(nil, "BACKGROUND")
    r.pad:SetAllPoints()
    r.pad:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    r.pad:SetBlendMode("ADD")
    r.pad:SetAlpha(.55)
    r.pad:Hide()
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(16, 16)
    r.icon:SetPoint("LEFT", 4, 0)
    r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    r.text:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
    r.text:SetPoint("RIGHT", -28, 0)
    r.text:SetJustifyH("LEFT")
    r.text:SetWordWrap(false)
    r.close = CreateFrame("Button", nil, r, "UIPanelCloseButton")
    r.close:SetSize(22, 22)
    r.close:SetPoint("RIGHT", 2, 0)
    r.close:SetScript("OnClick", function()
        if r.key and Focus() then Focus().CloseGroup(r.key) end
        UI.Refresh()
    end)
    r.close:SetScript("OnEnter", function(b)
        GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
        GameTooltip:SetText(DWE.L.SPOKEN_QUEUE_CLOSE)
        GameTooltip:Show()
    end)
    r.close:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r:SetScript("OnClick", function()
        if r.key and not r.current and Focus() then Focus().PlayGroup(r.key) end
        UI.Refresh()
    end)
    f.rows[i] = r
    return r
end

function UI.Refresh()
    local focus = Focus()
    local groups = focus and focus.Groups() or {}
    -- Pastille du bouton : combien d'autres attendent.
    local others = math.max(0, #groups - 1)
    for _, b in pairs(UI.buttons) do
        b.count:SetText(others > 0 and tostring(others) or "")
        b:SetAlpha(#groups > 1 and 1 or .55)
    end
    local f = UI.list
    if not f or not f:IsShown() then return end
    for i, g in ipairs(groups) do
        local r = Row(i)
        r.key, r.current = g.key, g.current
        r.icon:SetTexture(g.book and ICON_BOOK or ICON_NPC)
        if g.book then r.icon:SetTexCoord(.08, .92, .08, .92) else r.icon:SetTexCoord(0, 1, 0, 1) end
        local label = g.label .. (g.count > 1 and ("  |cff888888(" .. g.count .. ")|r") or "")
            .. ((g.manual and not g.current) and ("  |cff888888- " .. DWE.L.SPOKEN_HELD_TAG .. "|r") or "")
        r.text:SetText((g.current and "|cffffd200> |r" or "") .. label)
        r.text:SetTextColor(g.current and 1 or .9, g.current and .82 or .9, g.current and 0 or .9)
        r:Show()
    end
    if UI.padIdx then
        if #groups == 0 then UI.padIdx = 1 else UI.padIdx = math.max(1, math.min(UI.padIdx, #groups)) end
    end
    for i, r in ipairs(f.rows) do r.pad:SetShown(UI.padIdx == i and i <= #groups) end
    for i = #groups + 1, #f.rows do f.rows[i]:Hide() end
    f.empty:SetShown(#groups == 0)
    -- Plus rien en attente : la liste se ferme d'elle-meme (apres un court instant, le temps de
    -- lire "rien en attente" si on vient de l'ouvrir).
    if #groups == 0 and not f.closing then
        f.closing = true
        local function closeIfEmpty()
            f.closing = nil
            local fo = Focus()
            if f:IsShown() and #(fo and fo.Groups() or {}) == 0 then f:Hide() end
        end
        if C_Timer and C_Timer.After then C_Timer.After(1.5, closeIfEmpty) else closeIfEmpty() end
    end
    f:SetSize(LIST_W, 34 + math.max(1, #groups) * ROW_H)
end

function UI.Toggle(button)
    UI.list = UI.list or BuildList()
    if UI.list:IsShown() then UI.padIdx = nil; UI.list:Hide() return end
    local env = Env()
    local mp = env and env.MinimalPlayer
    if mp and mp.menu then mp.menu:Hide() end
    UI.list:ClearAllPoints()
    local sub = rawget(_G, "SpokenSubtitleFrame")
    if button and button.dweDUIBook then
        -- Livre de DialogueUI : juste au-dessus de ses boutons.
        UI.list:SetPoint("BOTTOMRIGHT", button, "TOPRIGHT", 8, 6)
    elseif (button and button.dweSubtitle) or (not button and type(sub) == "table" and sub.IsVisible and sub:IsVisible()) then
        -- Sous-titres (au milieu de l'ecran) : la liste centree juste dessous.
        UI.list:SetPoint("TOP", button or sub, "BOTTOM", 0, -6)
    else
        UI.list:SetPoint("TOPRIGHT", button or UIParent, "BOTTOMRIGHT", 8, -6)
    end
    UI.list:Show()
    UI.Refresh()
end

-- Un bouton rond par fenetre de Spoken (petit lecteur, lecteur, fenetre DialogueUI), ajoute en
-- tete de sa rangee de boutons (a cote de Stop / Passer) chaque fois que Spoken la dispose.
UI.buttons = {}
local function MakeButton(Actions, controls)
    local b = Actions.RoundButton(controls, 14, nil, true)
    b.glyph:SetTexture(ICON_BOOK)
    b.glyph:SetTexCoord(.1, .9, .1, .9)
    b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    b.count:SetPoint("BOTTOMRIGHT", 4, -3)
    b:SetScript("OnClick", function(self) UI.Toggle(self) end)
    b:SetScript("OnEnter", function()
        b.glyph:SetAlpha(1)
        -- Dans le livre de DialogueUI, l'infobulle du livre (celle du jeu peut etre cachee).
        local tip = (b.dweTip and b.dweTip()) or GameTooltip
        tip:SetOwner(b, "ANCHOR_TOP")
        tip:SetText(DWE.L.SPOKEN_QUEUE)
        tip:AddLine(DWE.L.SPOKEN_QUEUE_TIP, 1, 1, 1, true)
        tip:Show()
        b.dweTipShown = tip
    end)
    b:HookScript("OnLeave", function() if b.dweTipShown then b.dweTipShown:Hide(); b.dweTipShown = nil end end)
    return b
end

-- Manette (bouton Share maintenu + Y) : la liste s'ouvre sous le lecteur, la croix choisit une
-- ligne, A la fait lire, Y la retire, B ou Share referme.
function UI.PadIsOpen() return UI.list ~= nil and UI.list:IsShown() end
function UI.PadOpen()
    UI.list = UI.list or BuildList()
    local anchor
    for _, b in pairs(UI.buttons) do
        if b:IsVisible() and (not anchor or b.dweDUIBook) then anchor = b end
    end
    if not UI.list:IsShown() then UI.Toggle(anchor) end
    UI.padIdx = 1
    UI.Refresh()
end
function UI.PadClose()
    UI.padIdx = nil
    if UI.list then UI.list:Hide() end
end
function UI.PadMove(d)
    local f = UI.list
    if not f then return end
    local n = 0
    for _, r in ipairs(f.rows) do if r:IsShown() then n = n + 1 end end
    if n == 0 then return end
    UI.padIdx = ((UI.padIdx or 1) - 1 + d) % n + 1
    UI.Refresh()
end
local function PadRow()
    local r = UI.list and UI.list.rows[UI.padIdx or 1]
    return r and r:IsShown() and r or nil
end
function UI.PadPlay()
    local r = PadRow()
    if r and r.key and not r.current and Focus() then Focus().PlayGroup(r.key) end
    UI.Refresh()
end
function UI.PadRemove()
    local r = PadRow()
    if r and r.key and Focus() then Focus().CloseGroup(r.key) end
    UI.Refresh()
end

local laying
local function OnLayOutRow(controls, row, gap)
    if laying or type(row) ~= "table" or not controls then return end
    local env = Env()
    local Actions = env and env.Actions
    if not Actions then return end
    local b = UI.buttons[controls]
    if not b then
        b = MakeButton(Actions, controls)
        UI.buttons[controls] = b
    end
    for _, x in ipairs(row) do if x == b then return end end
    table.insert(row, 1, b)
    b:Show()
    laying = true
    pcall(Actions.LayOutRow, controls, row, gap or Actions.ROUND_GAP or 4)
    laying = nil
    UI.Refresh()
end

-- Livre de DialogueUI (Spoken Readables y pose Lecture / Passer / Signaler a gauche de la croix,
-- et le bouton du Compendium) : notre bouton de file prend la place du Compendium, qui passe a
-- sa gauche. De droite a gauche : Signaler, Passer, Lecture, File, Compendium.
local function PlaceDUIBook(book)
    local env = Env()
    local Actions = env and env.Actions
    local row = book.row
    local view = rawget(_G, "DUIBookFrame")
    if not (Actions and row and row.frame and view) then return false end
    local b = UI.buttons[row.frame]
    if not b then
        b = MakeButton(Actions, row.frame)
        b:SetFrameStrata("FULLSCREEN")
        b.dweDUIBook = true
        b.dweTip = row.tooltip
        UI.buttons[row.frame] = b
        UI.Refresh()
    end
    b:Show()
    local list = {}
    if row.report and row.report:IsShown() then list[#list + 1] = row.report end
    if row.skip and row.skip:IsShown() then list[#list + 1] = row.skip end
    if row.play and row.play:IsShown() then list[#list + 1] = row.play end
    list[#list + 1] = b
    if row.open and row.open:IsShown() then list[#list + 1] = row.open end
    local close = view.CloseButton
    row:Place(list, type(close) == "table" and close.GetObjectType and close or nil)
    return true
end
function UI.HookDUIBook()
    if UI.duiBookHooked then return end
    local sr = rawget(_G, "SpokenReadables")
    local book = type(sr) == "table" and sr.DialogueUIBook
    if type(book) ~= "table" or type(book.Place) ~= "function" then return end
    UI.duiBookHooked = true
    local orig = book.Place
    book.Place = function(self, ...)
        local ok, done = pcall(PlaceDUIBook, self)
        if not (ok and done) then return orig(self, ...) end
    end
end

-- Parchemin des conversations de DialogueUI (Spoken Quests y pose Lecture / Passer) : notre
-- bouton de file se met a cote, et la liste s'ouvre juste au-dessus d'eux.
local function AdoptDUIQuestRow(row)
    local env = Env()
    local Actions = env and env.Actions
    if not (Actions and type(row) == "table" and row.frame and type(row.Place) == "function") then return end
    local b = UI.buttons[row.frame]
    if not b then
        b = MakeButton(Actions, row.frame)
        b:SetFrameStrata("FULLSCREEN")
        b.dweDUIBook = true
        UI.buttons[row.frame] = b
    end
    UI.duiQuestRow = row
    local orig = row.Place
    row.Place = function(self, list, ...)
        if type(list) == "table" then
            local at = #list + 1
            for i, w in ipairs(list) do
                if w == b then at = nil break end
                if w == self.play then at = i + 1 end
            end
            if at then table.insert(list, at, b) end
            b:Show()
        end
        return orig(self, list, ...)
    end
    pcall(UI.Refresh)
end
function UI.HookDUIQuest()
    if UI.duiQuestHooked then return end
    local sp = rawget(_G, "Spoken")
    if type(sp) ~= "table" or type(sp.CreateDialogueUIRow) ~= "function" then return end
    UI.duiQuestHooked = true
    local orig = sp.CreateDialogueUIRow
    sp.CreateDialogueUIRow = function(self, dialog, ...)
        local row = orig(self, dialog, ...)
        if dialog ~= nil and dialog == rawget(_G, "DUIQuestFrame") then pcall(AdoptDUIQuestRow, row) end
        return row
    end
end
UI.HookDUIQuest()

-- Sous-titres de Spoken : ils ont leur propre rangee (Stop, Passer, Signaler), sans la mise en
-- page commune des fenetres. Le bouton de file s'y ajoute en tete, et la rangee s'elargit.
local SUB_SIZE, SUB_GAP = 24, 4
local function OnSubtitleCorner(sub)
    local controls, pause = sub.controls, sub.pause
    local env = Env()
    local Actions = env and env.Actions
    if not (controls and pause and Actions and pause.ClearAllPoints) then return end
    local b = UI.buttons[controls]
    if not b then
        b = MakeButton(Actions, controls)
        b.dweSubtitle = true
        UI.buttons[controls] = b
    end
    b:ClearAllPoints()
    b:SetPoint("LEFT", controls, "LEFT", 0, 0)
    pause:ClearAllPoints()
    pause:SetPoint("LEFT", b, "RIGHT", SUB_GAP, 0)
    b:Show()
    local count = (sub.report and sub.report.IsShown and sub.report:IsShown()) and 4 or 3
    controls:SetWidth(SUB_SIZE * count + SUB_GAP * (count - 1))
    UI.Refresh()
end
function UI.HookSubtitle()
    if UI.subHooked then return end
    local env = Env()
    local sub = env and rawget(env, "Subtitle")
    if type(sub) ~= "table" or type(sub.Corner) ~= "function" then return end
    UI.subHooked = true
    hooksecurefunc(sub, "Corner", function(self) pcall(OnSubtitleCorner, self) end)
end

function UI.Install()
    UI.HookDUIBook()
    UI.HookDUIQuest()
    UI.HookSubtitle()
    if UI.installed then return end
    local env = Env()
    local Actions = env and env.Actions
    if not (Actions and type(Actions.LayOutRow) == "function") then return end
    UI.installed = true
    hooksecurefunc(Actions, "LayOutRow", function(controls, row, gap) pcall(OnLayOutRow, controls, row, gap) end)
    local api = env.Spoken
    if api and type(api.RegisterCallback) == "function" then
        for _, ev in ipairs({ "AUDIO_CHANGED", "CLIP_QUEUED", "CLIP_STOPPED" }) do
            pcall(api.RegisterCallback, api, ev, function() pcall(UI.Refresh) end)
        end
    end
end

-- Petit bouton "Spoken" quand il ne reste que des lignes a la demande : le lecteur est cache,
-- ce bouton prend sa place (meme endroit), discret. A son apparition il luit doucement trois
-- fois, puis reste calme. Un clic (ou Share a la manette) ouvre la liste de la file.
local notice = CreateFrame("Button", "StorytaleSpokenNotice", UIParent)
UI.notice = notice
notice:SetSize(30, 30)
notice:SetFrameStrata("MEDIUM")
notice:Hide()
notice.glow = notice:CreateTexture(nil, "BACKGROUND")
notice.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
notice.glow:SetBlendMode("ADD")
notice.glow:SetVertexColor(1, .82, .4)
notice.glow:SetPoint("CENTER")
notice.glow:SetSize(58, 58)
notice.glow:SetAlpha(0)
notice.ring = notice:CreateTexture(nil, "OVERLAY")
notice.ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
notice.ring:SetSize(52, 52)
notice.ring:SetPoint("TOPLEFT", -2, 2)
notice.icon = notice:CreateTexture(nil, "ARTWORK")
notice.icon:SetTexture(ICON_BOOK)
notice.icon:SetSize(20, 20)
notice.icon:SetPoint("CENTER")
notice.icon:SetTexCoord(.1, .9, .1, .9)
notice.count = notice:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
notice.count:SetPoint("BOTTOMRIGHT", 4, -3)
notice:SetAlpha(.85)
notice:SetScript("OnClick", function(self) UI.Toggle(self) end)
notice:SetScript("OnEnter", function(self)
    self:SetAlpha(1)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(DWE.L.SPOKEN_QUEUE)
    GameTooltip:AddLine(string.format(DWE.L.SPOKEN_NOTICE_TIP, self.n or 0), 1, 1, 1, true)
    GameTooltip:Show()
end)
notice:SetScript("OnLeave", function(self) self:SetAlpha(.85); GameTooltip:Hide() end)
notice:SetScript("OnUpdate", function(self, elapsed)
    if not self.pulse then return end
    self.pulse = self.pulse + elapsed
    local T = 2.4
    if self.pulse >= T then self.pulse = nil; self.glow:SetAlpha(0) return end
    self.glow:SetAlpha((0.5 - 0.5 * math.cos(self.pulse * 2 * math.pi * 3 / T)) * 0.6 * math.min(1, (T - self.pulse) / 0.6))
end)
function UI.NoticeShown() return notice:IsShown() end

local function PlayerAnchor()
    for _, n in ipairs({ "SpokenMinimalPlayerFrame", "SpokenDialogueUIPlayerFrame" }) do
        local fr = rawget(_G, n)
        if type(fr) == "table" and fr.IsShown and fr:IsShown() then return fr end
    end
end
function UI.UpdateNotice()
    local fo = Focus()
    local n = fo and fo.HeldOnly and fo.HeldOnly() or 0
    if DWE.SetSpokenHeldHide then DWE.SetSpokenHeldHide(n > 0) end
    if n == 0 then
        if notice:IsShown() then notice:Hide() end
        return
    end
    notice.n = n
    notice.count:SetText(n > 1 and tostring(n) or "")
    if not notice:IsShown() then
        notice:ClearAllPoints()
        local fr = PlayerAnchor()
        if fr then
            notice:SetPoint("LEFT", fr, "LEFT", 8, 0)
        else
            notice:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -260, 220)
        end
        notice.pulse = 0
        notice:Show()
    end
end
do
    local tick = CreateFrame("Frame", "StorytaleSpokenNoticeWatch")
    local acc = 0
    tick:SetScript("OnUpdate", function(_, elapsed)
        acc = acc + elapsed
        if acc < 0.3 then return end
        acc = 0
        if UI.installed then pcall(UI.UpdateNotice) end
        if not UI.duiBookHooked then pcall(UI.HookDUIBook) end
    end)
    UI.noticeWatch = tick
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function() pcall(UI.Install) end)
