-- Storytale : style de narrateur "Storytale" pour Spoken (API publique, RegisterNarrator).
-- Le joueur le choisit parmi les styles de Spoken. Spoken ne montre alors aucune de ses fenetres
-- et nous dit quelle ligne montrer : on la montre dans un cadre du theme choisi (celui des
-- themes en cadre, ou la bulle du theme), avec les pieces de Spoken (portrait, sous-titres,
-- boutons). Rien de l'interieur de Spoken : ce style tient quelle que soit l'evolution de ses
-- propres fenetres.

local L = DWE.L or {}
local N = {}
DWE.Narrator = N

local WIDTH = 440      -- largeur du contenu
local PORTRAIT = 52
local GAP = 10
local ROW_H = 24

local frame = CreateFrame("Frame", "StorytaleNarratorFrame", UIParent)
frame:SetSize(WIDTH + 32, 90)
frame:SetFrameStrata("MEDIUM")
frame:SetMovable(true)
frame:SetClampedToScreen(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:Hide()
N.frame = frame

-- Contenu : le theme se dessine autour (ses marges sont prises en dehors du contenu).
local content = CreateFrame("Frame", nil, frame)
content:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -16)
content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 16)
N.content = content

local header = content:CreateFontString(nil, "OVERLAY")
header:SetJustifyH("LEFT")
header:SetWordWrap(false)
local label = content:CreateFontString(nil, "OVERLAY")
label:SetJustifyH("LEFT")
label:SetWordWrap(false)
local captions = CreateFrame("Frame", nil, content)
captions:SetSize(1, 1)
local controls = CreateFrame("Frame", nil, content)
controls:SetSize(1, ROW_H)
N.header, N.label, N.captions = header, label, captions

local function Api() return DWE.SpokenAPI and DWE.SpokenAPI() end

-- Pieces de Spoken, faites une fois (a la premiere ligne montree).
local portrait, actions, buttons
local function Build(api)
    if portrait then return true end
    local ok = pcall(function()
        portrait = api:CreatePortrait(content, PORTRAIT)
        portrait:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
        buttons = {}
        local prev
        for _, kind in ipairs({ "previous", "pause", "stop", "skip" }) do
            local b = api:CreateControl(controls, kind)
            if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0) else b:SetPoint("LEFT", controls, "LEFT", 0, 0) end
            buttons[#buttons + 1] = b
            prev = b
        end
        if type(api.CreateActions) == "function" then
            actions = api:CreateActions(content)
        end
    end)
    if not ok then portrait = nil end
    return portrait ~= nil
end

local function Theme()
    local id = DWE.SpokenStyleId and DWE.SpokenStyleId() or DialogueWheelE_Theme
    local cfg = DWE.THEME_STYLES and DWE.THEME_STYLES[id]
    return id, cfg
end

local parts
local function Paint()
    if not (DWE.CreateThemeParts and DWE.PaintThemeParts) then return end
    parts = parts or DWE.CreateThemeParts(frame, frame:GetFrameLevel())
    local id, cfg = Theme()
    DWE.PaintThemeParts(parts, content, header, id)
    local hdr = cfg and cfg.hdr or { 1, 0.82, 0 }
    local body = cfg and cfg.body or { 1, 1, 1 }
    local face = DWE.FontPath and DWE.ThemeFontId and DWE.FontPath(DWE.ThemeFontId()) or STANDARD_TEXT_FONT
    local size = tonumber(DialogueWheelE_FontSize) or 14
    if DWE.SafeSetFont then
        DWE.SafeSetFont(header, face, size + 1)
        DWE.SafeSetFont(label, face, math.max(10, size - 2))
    else
        header:SetFont(face, size + 1)
        label:SetFont(face, math.max(10, size - 2))
    end
    header:SetTextColor(hdr[1], hdr[2], hdr[3])
    label:SetTextColor(body[1], body[2], body[3], 0.8)
    local shadow = (not cfg) or cfg.shadow == 1
    for _, fs in ipairs({ header, label }) do
        if shadow then fs:SetShadowOffset(1, -1); fs:SetShadowColor(0, 0, 0, 0.8) else fs:SetShadowOffset(0, 0) end
    end
    N.themeId = id
end

-- Le texte de Spoken (ses sous-titres) aux couleurs du theme. Seule touche a l'interieur de
-- Spoken, facultative : sans elle, ses sous-titres gardent leurs couleurs.
local function InkCaptions()
    local env = rawget(_G, "SpokenEnv")
    local tr = type(env) == "table" and rawget(env, "Transcript")
    if type(tr) ~= "table" or type(tr.SetStyle) ~= "function" then return end
    local _, cfg = Theme()
    if not cfg or not cfg.body then return end
    pcall(tr.SetStyle, tr, { color = cfg.body, shadow = cfg.shadow == 1,
        highlight = DWE.ThemeMark and DWE.ThemeMark(cfg) or nil })
end

-- Mise en page : portrait a gauche ; a droite le nom, l'intitule, les sous-titres ; en bas les
-- boutons de la ligne (a gauche) et ceux de lecture (a droite).
local function Layout(clip)
    local api = Api()
    local present = type(clip) == "table" and type(clip.present) == "table" and clip.present or {}
    local left = portrait and (PORTRAIT + GAP) or 0
    local textW = WIDTH - left
    header:ClearAllPoints()
    header:SetPoint("TOPLEFT", content, "TOPLEFT", left, 0)
    header:SetWidth(textW)
    header:SetText(type(present.header) == "string" and present.header or "")
    local y = (header:GetText() or "") ~= "" and (header:GetStringHeight() or 16) + 2 or 0
    label:ClearAllPoints()
    label:SetPoint("TOPLEFT", content, "TOPLEFT", left, -y)
    label:SetWidth(textW)
    local lab = type(present.label) == "string" and present.label or ""
    label:SetText(lab)
    if lab ~= "" then y = y + (label:GetStringHeight() or 12) + 4 end
    captions:ClearAllPoints()
    captions:SetPoint("TOPLEFT", content, "TOPLEFT", left, -y)
    captions:SetWidth(textW)
    local capH = 0
    if api and type(api.ShowCaptions) == "function" then
        local ok, h = pcall(api.ShowCaptions, api, captions, textW)
        capH = ok and tonumber(h) or 0
    end
    captions:SetHeight(math.max(1, capH))
    local textH = y + capH
    local top = math.max(portrait and PORTRAIT or 0, textH)
    -- Boutons de lecture a droite, ceux de la ligne a gauche, sous le tout.
    local w = 0
    for _, b in ipairs(buttons or {}) do
        if b:IsShown() then w = w + (b:GetWidth() or ROW_H) + 4 end
    end
    controls:SetWidth(math.max(1, w))
    controls:ClearAllPoints()
    controls:SetPoint("TOPRIGHT", content, "TOPLEFT", WIDTH, -(top + 6))
    if actions then
        actions:ClearAllPoints()
        actions:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(top + 6))
        pcall(actions.SetClip, actions, clip)
    end
    if portrait then pcall(portrait.SetClip, portrait, clip) end
    frame:SetSize(WIDTH + 32, top + 6 + ROW_H + 32)
end

-- Position : gardee d'une session a l'autre ; par defaut en bas, au centre.
local function Place()
    frame:ClearAllPoints()
    local p = DialogueWheelE_NarratorPos
    if type(p) == "table" and type(p[1]) == "string" and tonumber(p[2]) and tonumber(p[3]) then
        frame:SetPoint(p[1], UIParent, p[1], tonumber(p[2]), tonumber(p[3]))
    else
        frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 190)
    end
end
frame:SetScript("OnDragStart", function(self)
    if DialogueWheelE_Locked then return end
    self:StartMoving()
end)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local x, y = self:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if x and ux then
        local s = self:GetEffectiveScale() / UIParent:GetEffectiveScale()
        DialogueWheelE_NarratorPos = { "CENTER", math.floor(x * s - ux + 0.5), math.floor(y * s - uy + 0.5) }
        Place()
    end
end)

-- Cache pendant ce que Storytale montre lui-meme (meme regle que les fenetres de Spoken : la
-- bulle ou le cadre de Storytale dit deja la ligne).
local function Hidden()
    return DWE.ShouldHideCore and DWE.ShouldHideCore(false, frame) and true or false
end

local placed = false
function N.Update(clip)
    if type(clip) ~= "table" then
        N.clip, DWE.narratorClip = nil, nil
        frame:Hide()
        return
    end
    N.clip, DWE.narratorClip = clip, clip
    local api = Api()
    if api then Build(api) end
    if not placed then Place(); placed = true end
    Paint()
    InkCaptions()
    Layout(clip)
    frame:SetShown(not Hidden())
end

-- Theme change, police, dialogue ouvert ou ferme : redessine et revoit s'il faut se cacher.
local acc = 0
local watcher = CreateFrame("Frame")
watcher:SetScript("OnUpdate", function(_, dt)
    acc = acc + dt
    if acc < 0.2 then return end
    acc = 0
    if not N.clip then return end
    local hide = Hidden()
    if hide then
        if frame:IsShown() then frame:Hide() end
        return
    end
    local id = Theme()
    if id ~= N.themeId or not frame:IsShown() then
        Paint()
        InkCaptions()
        Layout(N.clip)
        frame:Show()
    end
end)

-- Enregistre le style aupres de Spoken (Spoken se charge avant : dependance facultative).
function N.Register()
    local api = Api()
    if not (api and type(api.RegisterNarrator) == "function") or N.registered then return false end
    local ok = pcall(api.RegisterNarrator, api, "storytale", {
        addon = "Storytale",
        title = L.NARRATOR_TITLE or "Storytale",
        description = L.NARRATOR_DESC or "Lines in a Storytale frame, in your theme: bubble or frame, with Spoken's portrait, captions and buttons.",
        picture = "Interface\\AddOns\\Storytale\\Logo",
        Update = function(clip) N.Update(clip) end,
    })
    N.registered = ok or nil
    return ok
end
N.Register()
