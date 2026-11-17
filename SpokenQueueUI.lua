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
        r.text:SetText((g.current and "|cffffd200> |r" or "") .. label)
        r.text:SetTextColor(g.current and 1 or .9, g.current and .82 or .9, g.current and 0 or .9)
        r:Show()
    end
    for i = #groups + 1, #f.rows do f.rows[i]:Hide() end
    f.empty:SetShown(#groups == 0)
    f:SetSize(LIST_W, 34 + math.max(1, #groups) * ROW_H)
end

function UI.Toggle(button)
    UI.list = UI.list or BuildList()
    if UI.list:IsShown() then UI.list:Hide() return end
    local env = Env()
    local mp = env and env.MinimalPlayer
    if mp and mp.menu then mp.menu:Hide() end
    UI.list:ClearAllPoints()
    UI.list:SetPoint("TOPRIGHT", button or UIParent, "BOTTOMRIGHT", 8, -6)
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
        GameTooltip:SetOwner(b, "ANCHOR_TOP")
        GameTooltip:SetText(DWE.L.SPOKEN_QUEUE)
        GameTooltip:AddLine(DWE.L.SPOKEN_QUEUE_TIP, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    return b
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

function UI.Install()
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

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function() pcall(UI.Install) end)
