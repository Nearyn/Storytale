-- Storytale - Bubble.lua
-- Themes "Bulle de dialogue" et "Bulle fantasy" : au lieu du popup, une bulle au-dessus de la
-- tete du PNJ. Le texte apparait lettre apres lettre, en fondu (comme le texte des quetes du
-- jeu). Un texte long est decoupe en morceaux affiches l'un apres l'autre.
-- Si Spoken lit ce texte a voix haute, l'ecriture suit la voix (meme rythme).
-- Clic gauche : finir le morceau / passer au suivant. Clic droit maintenu : deplacer.
-- Poignee du coin : changer la largeur.

local ADDON_PATH = "Interface\\AddOns\\Storytale\\"
local DEFAULT_WIDTH = 300      -- largeur max par defaut
local SEGMENT_MAX = 150        -- longueur max d'un morceau (en octets)
local TYPE_SPEED = 20          -- vitesse d'ecriture sans voix, en lettres par seconde
-- Sans voix reconnue (meme avec Spoken installe) : meme vitesse que sans Spoken.
local SPOKEN_PACE = TYPE_SPEED
DWE.fadeWiggle = false -- (essai du 25/11, inutile depuis l'ecriture sans le fondu du jeu)
local FADE_LETTERS = 10        -- nombre de lettres en cours d'apparition (fondu)

-- Lettres 1..n nettes, les FADE_LETTERS suivantes en fondu.
local function GradientAt(fs, n, fade)
    fs:SetAlphaGradient(n, fade or FADE_LETTERS)
    -- /storytale fluide : journal detaille de chaque changement d'affichage (/storytale fluide voir)
    local tr = DWE.fluidTrace
    if tr and DWE.fluidLog and fs == DWE.bubbleTextFS and (n ~= tr.n or fade ~= tr.f) and #tr < 3000 then
        tr.n, tr.f = n, fade
        local st, g = DWE.bubbleState, DWE.bubbleState and DWE.bubbleState.genDbg
        tr[#tr + 1] = string.format("%.2f n=%d fondu=%s ecrit=%.1f voix=%.1f motsuivant=%.2f attente=%s",
            (GetTime and GetTime() or 0) - (tr.t0 or 0), n, tostring(fade), g and g.pos or -1, g and g.target or -1,
            g and g.next or -1, tostring(st and st.genWaitAt))
    end
end
local READ_PER_CHAR, READ_MIN, READ_MAX = 0.05, 2, 8 -- temps de lecture apres ecriture

-- Reglages propres a chaque style de bulle.
local STYLES = {
    game = { pad = 14, color = { 1, 1, 1 }, shadow = false },
    -- Bulle d'Azeroth facon PNJ : le texte jaune pale des PNJ qui parlent (ChatTypeInfo.MONSTER_SAY).
    game_npc = { pad = 14, color = { 1, 1, 0.624 }, shadow = false },
    fantasy = { pad = 20, color = { 0.18, 0.10, 0.04 }, shadow = false, art = "BubbleFantasy", slice = 24 },
    whisper = { pad = 14, color = { 1, 0.66, 1 }, shadow = false, art = "BubbleWhisper", slice = 16, split = true },
}
-- Bulles 64x64 dont la pointe (32x32) a ses bords a partir de la 10e ligne : le bas de la bulle
-- est ouvert a l'endroit de la pointe pour que ses bords prolongent le contour (voir SplitArt).
local SPLIT = { Arcane = true, Folio = true, FolioDark = true, Glass = true, Ink = true, ParchDark = true, Parch = true, Starry = true,
    Sylvan = true, Veil = true, Velin = true, Whisper = true }
-- Les autres themes en bulle : leur image Bubble<art>.png et la couleur de texte du theme.
for id, sk in pairs(DWE.BUBBLE_SKINS) do
    if sk.art then
        local cfg = DWE.THEME_STYLES[id]
        STYLES[id] = { pad = 14, color = cfg and cfg.body or { 1, 1, 1 }, shadow = cfg and cfg.shadow == 1,
            art = "Bubble" .. sk.art, slice = 16, optFont = true, split = SPLIT[sk.art] }
    end
end
-- Personnalise : bulle blanche en deux calques (remplissage, contour) teintes aux couleurs choisies.
STYLES.custom = { pad = 14, color = { 1, 1, 1 }, shadow = true, art = "BubbleCustomFill", slice = 16, optFont = true, custom = true, split = true }
-- Murmure en d'autres couleurs.
for id, c in pairs(DWE.WHISPER_COLORS or {}) do
    STYLES[id] = { pad = 14, color = c.text, shadow = false, art = "Bubble" .. c.art, slice = 16, split = true }
end

local textBox = DWE.textBox

local bubble = CreateFrame("Frame", "DialogueWheelEBubble", UIParent, "BackdropTemplate")
bubble:SetFrameStrata("DIALOG")
bubble:SetClampedToScreen(true)
bubble:EnableMouse(true)
bubble:RegisterForDrag("LeftButton", "RightButton")
bubble:SetSize(120, 40)
bubble:Hide()
-- Bulle cachee tant que la premiere lettre n'est pas ecrite (attente de la voix) : une bulle
-- vide qui se remplit ensuite, c'est moche. L'opacite voulue par le reste de l'addon est gardee.
do
    local rawSetAlpha = bubble.SetAlpha
    bubble.dweWant = 1
    function bubble:SetAlpha(a)
        self.dweWant = a
        rawSetAlpha(self, self.dweWaitHide and 0 or a)
    end
    function bubble:DWEWaitHide(on)
        on = on and true or false
        if self.dweWaitHide == on then return end
        self.dweWaitHide = on
        rawSetAlpha(self, on and 0 or (self.dweWant or 1))
    end
end
DWE.bubble = bubble
-- Le gestionnaire de fenetres du jeu (manette) range parfois la bulle parmi ses fenetres et la
-- cache quand la fenetre de quete s'ouvre : on la remet aussitot si la conversation continue.
do
    local reg = rawget(_G, "EventRegistry")
    if type(reg) == "table" and reg.RegisterCallback then
        local owner = {}
        pcall(reg.RegisterCallback, reg, "UIParentPanelManager.ForcePanelHide", function(_, frame)
            local mine = frame == bubble or frame == DWE.textBox or frame == DWE.choiceBox
            if not mine then return end
            if DWE.bubbleLog then print("|cff33ff99Storytale|r rangee par le jeu, remise : " .. tostring(frame.GetName and frame:GetName())) end
            local function Back()
                if DWE.choiceBox and DWE.choiceBox:IsShown() and DWE.UpdateTextPanelVisuals then DWE.UpdateTextPanelVisuals() end
            end
            if C_Timer and C_Timer.After then C_Timer.After(0, Back) else Back() end
        end, owner)
    end
end
-- Filet de securite : la bulle cachee par quelqu'un d'autre que Storytale (gestionnaire de
-- fenetres du jeu, autre addon) pendant une conversation revient a l'image suivante.
bubble:HookScript("OnHide", function()
    if bubble.dweOff then return end
    local function Back()
        if not bubble.dweOff and DWE.choiceBox and DWE.choiceBox:IsShown() and not bubble:IsShown() then
            bubble:Show()
            if DWE.bubbleLog then print("|cff33ff99Storytale|r bulle remise") end
        end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0, Back) end
end)
-- Diagnostic (/storytale bubblelog) : qui cache la bulle, et quand.
do
    local function Where()
        local st = debugstack and debugstack(3, 4, 0) or ""
        st = st:gsub("Interface/AddOns/", ""):gsub("\n", " | ")
        return st:sub(1, 300)
    end
    bubble:HookScript("OnHide", function()
        if DWE.bubbleLog then print("|cff33ff99Storytale|r bulle cachee : " .. Where()) end
    end)
    -- Etat de la bulle un instant apres chaque affichage : visible ? transparente ? ou ?
    function DWE.BubbleState(tag)
        local function n(v) return type(v) == "number" and string.format("%.2f", v) or tostring(v) end
        local okA, ea = pcall(bubble.GetEffectiveAlpha, bubble)
        -- (Accrochee a une plaque de nom, la bulle ne peut pas etre mesuree : on ne le fait pas.)
        local x, y
        if not bubble.pinned then
            local okC, cx, cy = pcall(bubble.GetCenter, bubble)
            if okC then x, y = cx, cy end
        else
            x, y = "plaque", "PNJ"
        end
        local par = bubble:GetParent()
        print(("|cff33ff99Storytale|r etat (%s) : montree=%s visible=%s alpha=%s effective=%s pos=%s,%s parent=%s(%s) roue=%s accrochee=%s off=%s"):format(
            tostring(tag), tostring(bubble:IsShown()), tostring(bubble:IsVisible()), n(bubble:GetAlpha()), n(okA and ea),
            n(x), n(y), tostring(par and par.GetName and par:GetName()), tostring(par and par.IsVisible and par:IsVisible()),
            tostring(DWE.choiceBox and DWE.choiceBox:IsVisible()), tostring(bubble.pinned), tostring(bubble.dweOff)))
    end
    bubble:HookScript("OnShow", function()
        if DWE.bubbleLog and C_Timer and C_Timer.After then
            C_Timer.After(0.5, function() DWE.BubbleState("0,5 s") end)
            C_Timer.After(1.5, function() DWE.BubbleState("1,5 s") end)
        end
    end)
    hooksecurefunc(bubble, "SetAlpha", function(_, a)
        if DWE.bubbleLog and a == 0 then print("|cff33ff99Storytale|r bulle transparente : " .. Where()) end
    end)
end

-- Le texte et la pointe sont sur un cadre au-dessus du decor de la bulle.
local holder = CreateFrame("Frame", nil, bubble)
holder:SetAllPoints(bubble)
holder:SetFrameLevel(bubble:GetFrameLevel() + 5)

--------------------------------------------------------------------------------
-- Style "jeu" : l'apparence des bulles des joueurs
--------------------------------------------------------------------------------
-- 1. le decoupage "ChatBubble" du jeu (le meme que les bulles des joueurs) s'il existe ;
-- 2. sinon les anciennes textures de bulle du jeu ;
-- 3. sinon une bulle sombre a bordure claire dans le meme esprit.

local tail = holder:CreateTexture(nil, "ARTWORK")
tail:SetPoint("TOP", bubble, "BOTTOM", 0, 3)

local LEGACY_BACKDROP = {
    bgFile = "Interface\\Tooltips\\ChatBubble-Background",
    edgeFile = "Interface\\Tooltips\\ChatBubble-Backdrop",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 6, right = 6, top = 6, bottom = 6 },
}
local FALLBACK_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = false, edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

local gameArt -- "nineslice", "legacy" ou "fallback"

local function AtlasExists(name)
    return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end

local function DetectGameArt()
    if NineSliceUtil and NineSliceUtil.ApplyLayoutByName and NineSliceLayouts and NineSliceLayouts.ChatBubble then
        local art = CreateFrame("Frame", nil, bubble)
        art:SetAllPoints(bubble)
        art:SetFrameLevel(bubble:GetFrameLevel())
        NineSliceUtil.ApplyLayoutByName(art, "ChatBubble")
        bubble.art = art
        return "nineslice"
    end
    local probe = bubble:CreateTexture()
    local ok = probe:SetTexture("Interface\\Tooltips\\ChatBubble-Background") ~= false
        and probe:SetTexture("Interface\\Tooltips\\ChatBubble-Backdrop") ~= false
    probe:Hide()
    return ok and "legacy" or "fallback"
end

local okDetect, found = pcall(DetectGameArt)
gameArt = okDetect and found or "fallback"

local function ShowGameStyle()
    if gameArt == "nineslice" then
        bubble:SetBackdrop(nil)
        bubble.art:Show()
        if AtlasExists("ChatBubble-Tail") then
            tail:SetAtlas("ChatBubble-Tail", true)
            -- Pointe du jeu : sa place et sa taille reglables (/storytale pointe), pour qu'elle
            -- prolonge le contour comme sur les bulles du jeu.
            -- (a sa taille d'origine dans le jeu ; /storytale pointe peut l'agrandir)
            local sc = DWE.gameTailScale
            if sc and sc ~= 1 then
                local w, h = tail:GetSize()
                tail:SetSize((w or 16) * sc, (h or 16) * sc)
            end
            tail:ClearAllPoints()
            tail:SetPoint("TOP", bubble, "BOTTOM", DWE.gameTailX or 0, DWE.gameTailY or 3)
            tail:Show()
        else
            tail:Hide()
        end
    elseif gameArt == "legacy" then
        bubble:SetBackdrop(LEGACY_BACKDROP)
        if tail:SetTexture("Interface\\Tooltips\\ChatBubble-Tail") ~= false then
            tail:SetSize(16, 16)
            tail:Show()
        else
            tail:Hide()
        end
    else
        bubble:SetBackdrop(FALLBACK_BACKDROP)
        bubble:SetBackdropColor(0.04, 0.04, 0.05, 0.8)
        bubble:SetBackdropBorderColor(0.85, 0.85, 0.85, 0.95)
        tail:SetColorTexture(0.04, 0.04, 0.05, 0.8)
        if tail.SetRotation then tail:SetRotation(math.rad(45)) end
        tail:SetSize(12, 12)
        tail:Show()
    end
end

--------------------------------------------------------------------------------
-- Style "fantasy" : parchemin a bordure encree et filet dore (textures de l'addon)
--------------------------------------------------------------------------------

local fantasy = bubble:CreateTexture(nil, "BACKGROUND")
fantasy:SetAllPoints(bubble)
fantasy:SetTexture(ADDON_PATH .. "BubbleFantasy.png")
-- Decoupage en 9 : les coins arrondis gardent leur forme quelle que soit la taille.
if fantasy.SetTextureSliceMargins then
    fantasy:SetTextureSliceMargins(24, 24, 24, 24)
    if fantasy.SetTextureSliceMode then fantasy:SetTextureSliceMode(0) end
end
fantasy:Hide()

local fantasyTail = holder:CreateTexture(nil, "ARTWORK")
fantasyTail:SetTexture(ADDON_PATH .. "BubbleFantasyTail.png")
fantasyTail:SetSize(32, 32)
fantasyTail:SetPoint("TOP", bubble, "BOTTOM", 0, 8)
fantasyTail:Hide()

-- Contours du theme Personnalise (au-dessus du remplissage de la bulle et de la pointe).
local customEdge = bubble:CreateTexture(nil, "BORDER")
customEdge:SetAllPoints(bubble)
customEdge:SetTexture(ADDON_PATH .. "BubbleCustomEdge.png")
if customEdge.SetTextureSliceMargins then
    customEdge:SetTextureSliceMargins(16, 16, 16, 16)
    if customEdge.SetTextureSliceMode then customEdge:SetTextureSliceMode(0) end
end
customEdge:Hide()
local customTailEdge = holder:CreateTexture(nil, "OVERLAY")
customTailEdge:SetTexture(ADDON_PATH .. "BubbleCustomEdgeTail.png")
customTailEdge:SetSize(32, 32)
customTailEdge:SetPoint("TOP", bubble, "BOTTOM", 0, 8)
customTailEdge:Hide()

-- Bulle "ouverte" : la meme image decoupee a la main en 9 morceaux, mais le bord du bas est
-- coupe en deux autour de la pointe. A la place du contour, un morceau du fond de la bulle
-- (meme couleur, meme transparence) ; les deux bords de la pointe ferment l'ouverture.
local MOUTH = 6           -- demi-largeur de l'ouverture (bords de la pointe aux colonnes 10 et 22)
local TAIL_ROW = 9        -- premiere ligne de la pointe gardee (debut de ses bords)
local TAIL_TOP = 3        -- cette ligne se pose sur le contour (lignes 1 et 2 depuis le bas)
local split = {}
-- Theme Personnalise : son contour, decoupe pareil (au-dessus du fond), ouvert sous la pointe.
local splitEdge = {}
for _, k in ipairs({ "tl", "t", "tr", "l", "c", "r", "bl", "bL", "m", "bR", "br" }) do
    split[k] = bubble:CreateTexture(nil, "BACKGROUND")
    split[k]:Hide()
    splitEdge[k] = bubble:CreateTexture(nil, "BORDER")
    splitEdge[k]:Hide()
end
local function SplitArt(st, set, art)
    local S, u = st.slice, st.slice / 64
    local v = 1 - TAIL_TOP / 64
    set = set or split
    for _, t in pairs(set) do t:SetTexture(ADDON_PATH .. (art or st.art) .. ".png"); t:ClearAllPoints() end
    local p = set
    p.tl:SetSize(S, S); p.tl:SetPoint("TOPLEFT", bubble, "TOPLEFT"); p.tl:SetTexCoord(0, u, 0, u)
    p.tr:SetSize(S, S); p.tr:SetPoint("TOPRIGHT", bubble, "TOPRIGHT"); p.tr:SetTexCoord(1 - u, 1, 0, u)
    p.bl:SetSize(S, S); p.bl:SetPoint("BOTTOMLEFT", bubble, "BOTTOMLEFT"); p.bl:SetTexCoord(0, u, 1 - u, 1)
    p.br:SetSize(S, S); p.br:SetPoint("BOTTOMRIGHT", bubble, "BOTTOMRIGHT"); p.br:SetTexCoord(1 - u, 1, 1 - u, 1)
    p.t:SetPoint("TOPLEFT", p.tl, "TOPRIGHT"); p.t:SetPoint("BOTTOMRIGHT", p.tr, "BOTTOMLEFT")
    p.t:SetTexCoord(u, 1 - u, 0, u)
    p.l:SetPoint("TOPLEFT", p.tl, "BOTTOMLEFT"); p.l:SetPoint("BOTTOMRIGHT", p.bl, "TOPRIGHT")
    p.l:SetTexCoord(0, u, u, 1 - u)
    p.r:SetPoint("TOPLEFT", p.tr, "BOTTOMLEFT"); p.r:SetPoint("BOTTOMRIGHT", p.br, "TOPRIGHT")
    p.r:SetTexCoord(1 - u, 1, u, 1 - u)
    p.c:SetPoint("TOPLEFT", p.tl, "BOTTOMRIGHT"); p.c:SetPoint("BOTTOMRIGHT", p.br, "TOPLEFT")
    p.c:SetTexCoord(u, 1 - u, u, 1 - u)
    p.bL:SetPoint("TOPLEFT", p.bl, "TOPRIGHT"); p.bL:SetPoint("BOTTOMRIGHT", bubble, "BOTTOM", -MOUTH, 0)
    p.bL:SetTexCoord(u, 1 - u, 1 - u, 1)
    p.bR:SetPoint("TOPRIGHT", p.br, "TOPLEFT"); p.bR:SetPoint("BOTTOMLEFT", bubble, "BOTTOM", MOUTH, 0)
    p.bR:SetTexCoord(u, 1 - u, 1 - u, 1)
    -- ouverture : le bas de la bulle sans son contour (lignes au-dessus de celui-ci)
    p.m:SetPoint("BOTTOMLEFT", bubble, "BOTTOM", -MOUTH, TAIL_TOP)
    p.m:SetPoint("TOPRIGHT", bubble, "BOTTOM", MOUTH, S)
    -- (seulement le milieu de l'image, a sa taille : etire sur 12 pixels, tout le bas d'un
    -- parchemin faisait une bande plus claire au-dessus de la pointe)
    local mw = MOUTH / 64
    p.m:SetTexCoord(0.5 - mw, 0.5 + mw, 1 - u, v)
    for _, t in pairs(set) do t:Show() end
    if set == splitEdge then p.m:Hide() end -- (pas de contour dans l'ouverture)
end
local function HideSplit()
    for _, t in pairs(split) do t:Hide() end
    for _, t in pairs(splitEdge) do t:Hide() end
end

local styleName -- style actuellement affiche

local text = holder:CreateFontString(nil, "OVERLAY")
DWE.bubbleTextFS = text
text:SetFontObject(ChatBubbleFont or GameFontHighlight)
text:SetJustifyH("LEFT")
text:SetJustifyV("TOP")
if text.SetWordWrap then text:SetWordWrap(true) end
-- Copie du texte, pour changer le mot surligne sans eclair : le jeu n'applique le fondu qu'a
-- l'image qui suit un nouveau texte (le texte entier se voyait une image). La copie recoit le
-- nouveau texte une image a l'avance, cachee, puis prend la place du texte le temps qu'il se mette a jour.
local ghost = holder:CreateFontString(nil, "OVERLAY")
ghost:SetFontObject(ChatBubbleFont or GameFontHighlight)
ghost:Hide()
local function SyncGhost()
    -- Chaque reglage a part : un seul qui echoue ne doit pas laisser la copie invisible.
    pcall(function() ghost:SetFontObject(text:GetFontObject() or ChatBubbleFont or GameFontHighlight) end)
    pcall(function()
        local f, size, flags = text:GetFont()
        if f and size then ghost:SetFont(f, size, flags or "") end
    end)
    pcall(function() ghost:SetTextColor(text:GetTextColor()) end)
    pcall(function() ghost:SetShadowOffset(text:GetShadowOffset()) end)
    pcall(function() ghost:SetShadowColor(text:GetShadowColor()) end)
    pcall(function() ghost:SetJustifyH(text:GetJustifyH()) end)
    pcall(function() ghost:SetJustifyV(text:GetJustifyV()) end)
    pcall(function() if ghost.SetWordWrap then ghost:SetWordWrap(true) end end)
    pcall(function() ghost:SetWidth(text:GetWidth()) end)
    pcall(function()
        ghost:ClearAllPoints()
        ghost:SetPoint("TOPLEFT", text, "TOPLEFT", 0, 0)
    end)
end

local function Pad()
    return STYLES[styleName or "game"].pad
end

-- Opacite du fond (option "Opacite du fond") : le fond et la pointe de la bulle, jamais le texte.
function DWE.ApplyBubbleOpacity()
    local op = tonumber(DialogueWheelE_Opacity) or 1
    for _, t in ipairs({ fantasy, fantasyTail, tail, customEdge, customTailEdge }) do t:SetAlpha(op) end
    -- Personnalise : alpha porte par les couleurs (fond 0.86 x opacite).
    for _, t in pairs(split) do t:SetAlpha(op) end
    if styleName == "custom" and DWE.Bubble and DWE.Bubble.RefreshCustom then DWE.Bubble.RefreshCustom() end
    if bubble.art then bubble.art:SetAlpha(op) end
    if bubble.GetBackdrop and bubble:GetBackdrop() then
        if gameArt == "fallback" then
            bubble:SetBackdropColor(0.04, 0.04, 0.05, 0.8 * op)
            bubble:SetBackdropBorderColor(0.85, 0.85, 0.85, 0.95 * op)
        else
            bubble:SetBackdropColor(1, 1, 1, op)
            bubble:SetBackdropBorderColor(1, 1, 1, op)
        end
    end
end

local function ApplyStyle(name)
    if styleName == name then return end
    styleName = name
    local st = STYLES[name]
    if st.art then
        -- bulle dessinee par l'addon (texture decoupee en 9 + pointe)
        bubble:SetBackdrop(nil)
        if bubble.art then bubble.art:Hide() end
        tail:Hide()
        fantasy:SetTexture(ADDON_PATH .. st.art .. ".png")
        if fantasy.SetTextureSliceMargins then
            fantasy:SetTextureSliceMargins(st.slice, st.slice, st.slice, st.slice)
        end
        fantasyTail:SetTexture(ADDON_PATH .. st.art .. "Tail.png")
        fantasyTail:ClearAllPoints()
        if st.split then
            -- pointe sans ses premieres lignes (fond deja donne par l'ouverture), posee sur le contour
            fantasyTail:SetTexCoord(0, 1, TAIL_ROW / 32, 1)
            fantasyTail:SetSize(32, 32 - TAIL_ROW)
            fantasyTail:SetPoint("TOP", bubble, "BOTTOM", 0, TAIL_TOP)
            fantasy:Hide()
            SplitArt(st)
        else
            fantasyTail:SetTexCoord(0, 1, 0, 1)
            fantasyTail:SetSize(32, 32)
            fantasyTail:SetPoint("TOP", bubble, "BOTTOM", 0, 8)
            HideSplit()
            fantasy:Show()
        end
        fantasyTail:Show()
    else
        HideSplit()
        fantasy:Hide()
        fantasyTail:Hide()
        ShowGameStyle()
    end
    if st.custom then
        -- Ouverte comme les autres bulles : contour decoupe autour de la pointe, pointe posee
        -- dessus (avant : contour entier sous une pointe plus etroite, encoche ouverte).
        SplitArt(st, splitEdge, "BubbleCustomEdge")
        customEdge:Hide()
        customTailEdge:SetTexCoord(0, 1, TAIL_ROW / 32, 1)
        customTailEdge:SetSize(32, 32 - TAIL_ROW)
        customTailEdge:ClearAllPoints()
        customTailEdge:SetPoint("TOP", bubble, "BOTTOM", 0, TAIL_TOP)
        customTailEdge:Show()
    else
        customEdge:Hide(); customTailEdge:Hide()
        local op = tonumber(DialogueWheelE_Opacity) or 1
        fantasy:SetVertexColor(1, 1, 1, op); fantasyTail:SetVertexColor(1, 1, 1, op)
        for _, t in pairs(split) do t:SetVertexColor(1, 1, 1, 1) end
    end
    if DWE.Bubble and DWE.Bubble.RefreshCustom then DWE.Bubble.RefreshCustom() end
    if DWE.ApplyBubbleOpacity then DWE.ApplyBubbleOpacity() end
    text:ClearAllPoints()
    text:SetPoint("TOPLEFT", bubble, "TOPLEFT", st.pad, -st.pad)
    local tc = st.custom and DWE.CustomColor("text") or st.color
    text:SetTextColor(tc[1], tc[2], tc[3])
    text:SetShadowOffset(st.shadow and 1 or 0, st.shadow and -1 or 0)
    bubble.fontKey = nil -- police a reappliquer
    -- (lignes deja ecrites et bord adouci : copies du texte, a remettre a sa nouvelle couleur)
    if DWE.BubbleRecolor then DWE.BubbleRecolor() end
end

local function Measure(fn, default)
    if not fn then return default end
    local ok, v = pcall(fn, text)
    return (ok and type(v) == "number") and v or default
end

local function MaxWidth()
    return tonumber(DialogueWheelE_BubbleWidth) or DEFAULT_WIDTH
end
DWE.BubbleMaxWidth = MaxWidth

-- Ajuste la bulle au texte `s` (le morceau complet, pour que la bulle ne change pas de taille
-- pendant que le PNJ ecrit), puis affiche `shown`.
local fitSerial = 0
local function FitTo(s, shown)
    fitSerial = fitSerial + 1
    local mySerial = fitSerial
    local pad = Pad()
    local maxInner = MaxWidth() - 2 * pad
    text:SetWidth(maxInner)
    text:SetText(s)
    -- Hauteur mesuree a la largeur max (le nombre de lignes ne change pas en resserrant).
    local h = Measure(text.GetStringHeight, 14)
    local unbounded = Measure(text.GetUnboundedStringWidth or text.GetStringWidth, maxInner)
    -- Le jeu renvoie parfois la hauteur d'une seule ligne avant d'avoir coupe le texte : on
    -- estime aussi le nombre de lignes d'apres la longueur du texte et on garde le plus grand.
    local okF, _, fontSize = pcall(text.GetFont, text)
    fontSize = (okF and type(fontSize) == "number" and fontSize > 0) and fontSize or 14
    local lines = math.max(1, math.ceil(unbounded * 1.08 / maxInner))
    h = math.max(h, lines * fontSize * 1.22)
    -- +4 : une largeur pile au pixel peut faire passer le dernier mot a la ligne.
    local w = math.max(24, math.min(maxInner, math.ceil(unbounded) + 4))
    text:SetWidth(w)
    -- Nombre de lignes exact, d'apres nos propres retours a la ligne (les memes que l'ecriture) :
    -- l'estimation pouvait compter une ligne de trop, et la bulle, trop haute une image, se
    -- resserrait aussitot (« comme si on etirait la fenetre », video du 25/11).
    if DWE.BubbleWrapped and type(s) == "string" and not (issecretvalue and issecretvalue(s)) then
        local okW, wrapped = pcall(DWE.BubbleWrapped, s)
        local lh = DWE.BubbleLineHeight and DWE.BubbleLineHeight()
        if okW and type(wrapped) == "string" and lh and lh > 0 then
            local _, breaks = wrapped:gsub("\n", "")
            h = (breaks + 1) * lh
        end
    end
    bubble:SetSize(w + 2 * pad, h + 2 * pad + 2)
    text:SetText(shown or s)
    -- Le jeu peut ne finir la mise en page qu'a l'image suivante : on revérifie la hauteur.
    if C_Timer and C_Timer.After then
        -- On remesure le morceau complet (pas le texte deja ecrit) : la bulle grandit s'il
        -- manque une ligne, et rapetisse si l'estimation en avait prevu une de trop (vide en bas).
        local function Recheck()
            if mySerial ~= fitSerial then return end -- autre morceau depuis
            local cur = text:GetText()
            text:SetText(s)
            local ok, real = pcall(text.GetStringHeight, text)
            text:SetText(cur)
            if ok and type(real) == "number" and real >= fontSize * 0.8 and math.abs(real - h) > 3 then
                h = real
                bubble:SetHeight(real + 2 * pad + 2)
            end
        end
        C_Timer.After(0, Recheck)
        C_Timer.After(0.15, Recheck)
    end
end

--------------------------------------------------------------------------------
-- Decoupage et ecriture progressive
--------------------------------------------------------------------------------

local function IsSecret(v)
    return issecretvalue and issecretvalue(v)
end

local function Trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Coupe en phrases regroupees jusqu'a SEGMENT_MAX ; une phrase trop longue est coupee entre
-- deux mots.
local function Split(s)
    s = s:gsub("\r", ""):gsub("%s*\n+%s*", " "):gsub("%s+", " ")
    local segs, cur = {}, ""
    local function push()
        local t = Trim(cur)
        if t ~= "" then segs[#segs + 1] = t end
        cur = ""
    end
    for sentence in s:gmatch("[^%.!%?]+[%.!%?]*%s*") do
        if #cur > 0 and #cur + #sentence > SEGMENT_MAX then push() end
        if #sentence > SEGMENT_MAX then
            for word in sentence:gmatch("%S+%s*") do
                if #cur > 0 and #cur + #word > SEGMENT_MAX then push() end
                cur = cur .. word
            end
        else
            cur = cur .. sentence
        end
    end
    push()
    return segs
end

-- Nombre de lettres (UTF-8 : un caractere accentue ou asiatique compte pour une lettre).
local function Utf8Len(s)
    return select(2, s:gsub("[^\128-\191]", ""))
end

-- Les `n` premieres lettres de `s` (secours si le jeu n'a pas de fondu de texte).
local function Utf8Prefix(s, n)
    if n <= 0 then return "" end
    local count, i = 0, 1
    while i <= #s do
        local b = s:byte(i)
        if b < 0x80 or b >= 0xC0 then
            count = count + 1
            if count > n then return s:sub(1, i - 1) end
        end
        i = i + 1
    end
    return s
end

local state = { segs = {}, lens = {}, index = 0, phase = "idle", t = 0, raw = nil }
local hasGradient = text.SetAlphaGradient ~= nil

-- Affiche les `state.typed` premieres lettres du morceau. Avec le fondu du jeu, le texte entier
-- est deja en place (il ne saute pas d'une ligne a l'autre en cours d'ecriture).
-- Fondu de la bulle qui suit la voix : il ne deborde pas au-dela de la prochaine pause de la
-- voix (virgule, point, fin de page). Sinon, pendant la pause, le debut du mot suivant restait
-- visible a moitie et semblait fige. Il raccourcit en douceur a l'approche de la pause.
local function FadeLen(n)
    local stops = state.voiced and ((state.generated and state.genStops) or (state.wmap and state.wmap.stops))
    if not stops then return FADE_LETTERS end
    local at = n
    for k = 1, (state.index or 1) - 1 do at = at + (state.lens[k] or 0) end
    -- Arret a une ponctuation (on attend la voix) : aucune lettre du mot suivant en fondu (on
    -- voyait « on » de « one » pendant l'attente : la bulle semblait bloquee sur ce mot).
    -- On alterne 1 et 2 a chaque image : la lettre d'apres est l'espace qui suit la ponctuation
    -- (rien ne se voit), mais le fondu change sans cesse. Essai : apres une longue attente au
    -- meme fondu, le jeu ne redessinait plus tout de suite a la reprise (« on » fige 0,45 s).
    if state.genWaitAt and math.abs(state.genWaitAt - at) < 1 then
        if DWE.fadeWiggle then
            state.wiggle = not state.wiggle
            return state.wiggle and 2 or 1
        end
        return 1
    end
    for _, c in ipairs(stops) do
        if c >= at then
            -- pile sur la ponctuation (attente de la voix) : meme essai qu'au-dessus
            if c - at < 1 and DWE.fadeWiggle then
                state.wiggle = not state.wiggle
                return state.wiggle and 2 or 1
            end
            return math.max(1, math.min(FADE_LETTERS, c - at))
        end
    end
    return FADE_LETTERS
end

-- Mot lu surligne (option de Storytale, decochee par defaut, et "Highlight Words" de Spoken) :
-- le mot que la bulle ecrit au rythme de la voix prend la couleur de Spoken (or sur fond
-- sombre, rouge fonce sur fond clair).
local HL_ON_DARK, HL_ON_LIGHT = "|cffffd100", "|cff9c1a1a"
-- Code couleur du mot lu : celle choisie pour le theme Personnalise (pastille "Mot lu"), sinon
-- or sur texte clair (fond sombre), rouge fonce sur texte sombre (fond clair).
local function WordColor()
    local okC, r, g = pcall(text.GetTextColor, text)
    if not okC then r, g = 1, 1 end
    local light = (r or 1) * 0.6 + (g or 1) * 0.4 > 0.5
    if styleName == "custom" and DWE.CustomWordColor then
        local c = DWE.CustomWordColor()
        if c then return string.format("|cff%02x%02x%02x", math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5)) end
    end
    return light and HL_ON_DARK or HL_ON_LIGHT
end
local function SpokenHighlightWords()
    local env = rawget(_G, "SpokenEnv")
    local addon = type(env) == "table" and rawget(env, "Addon")
    if type(addon) ~= "table" then return false end
    local ok, on = pcall(function()
        local t = addon.db.profile.Transcript
        return t.Enabled ~= false and t.HighlightWord == true
    end)
    return ok and on == true
end
local function HighlightOn()
    return DialogueWheelE_BubbleHighlight == true and SpokenHighlightWords()
end
DWE.BubbleHighlightOn = HighlightOn

-- Le mot a surligner dans le morceau affiche : celui que la bulle est en train d'ecrire (nil si
-- rien a surligner). Rend son debut et sa longueur en lettres dans le morceau.
local function HighlightWord(n)
    if not (state.voiced and not state.manual and state.phase == "typing" and not state.dots) then return nil end
    if n <= 0 or not state.words or not HighlightOn() then return nil end
    local segStart = 0
    for k = 1, (state.index or 1) - 1 do segStart = segStart + (state.lens[k] or 0) end
    -- Le mot qui est en train d'apparaitre (vers le milieu du fondu), pas le dernier mot fini :
    -- la couleur suit les lettres qui naissent, sans "doublon" entre le mot colore et le fondu.
    local ahead = math.max(1, math.floor(FadeLen(n) * 0.4))
    local pos, found = segStart + math.min(n + ahead, state.lens[state.index or 1] or n), nil
    for _, w in ipairs(state.words) do
        if w.start >= pos then break end
        if w.start >= segStart then found = w end
    end
    if not found then return nil end
    return found.start - segStart, found.len
end

-- Texte du morceau avec le mot lu en couleur (ou sans couleur), et sa cle (nil : sans couleur).
local function HighlightText(seg, n)
    local at, len = HighlightWord(n)
    -- Texte avec ses propres codes (lien, couleur) : on n'y touche pas.
    if not at or seg:find("|", 1, true) then return seg, nil end
    local a = #Utf8Prefix(seg, at)
    local b = #Utf8Prefix(seg, at + len)
    return seg:sub(1, a) .. WordColor() .. seg:sub(a + 1, b) .. "|r" .. seg:sub(b + 1),
        state.index .. ":" .. at
end

-- Changement du mot surligne sans jamais montrer le texte sans son fondu, ni une bulle vide :
-- 0) la copie (quasi invisible) recoit le nouveau texte ; 1) la copie se montre par-dessus le
-- texte (le jeu peut ne la dessiner qu'une image plus tard) ; 2) le texte recoit le nouveau
-- texte, cache derriere la copie ; 3) le texte revient, la copie disparait.
-- Rend vrai si l'image est prise.
local function HighlightStep(seg, n)
    if state.hlStage and state.hlT ~= state.t then
        state.hlT = state.t
        local fade = FadeLen(n)
        if state.hlStage == 1 then
            GradientAt(ghost, n, fade)
            ghost:SetAlpha(1)
            GradientAt(text, n, fade)
            state.hlStage = 2
        elseif state.hlStage == 2 then
            GradientAt(ghost, n, fade)
            text:SetText(state.hlNext)
            GradientAt(text, n, fade)
            -- Copie bien dessinee : le texte se cache derriere elle le temps de se mettre a jour.
            local okW, gw = pcall(ghost.GetStringWidth, ghost)
            if okW and (gw or 0) > 0 then text:SetAlpha(0) end
            state.hlStage = 3
        else
            GradientAt(text, n, fade)
            text:SetAlpha(1)
            ghost:Hide()
            state.hlStage = nil
        end
        state.shownN = n
        return true
    elseif state.hlStage then
        -- Deja traite a cette image : on garde juste les fondus a jour.
        local fade = FadeLen(n)
        if ghost:IsShown() then GradientAt(ghost, n, fade) end
        GradientAt(text, n, fade)
        state.shownN = n
        return true
    end
    if n <= 0 or state.fresh then return false end
    local want, key = HighlightText(seg, n)
    if key == state.hlKey then return false end
    state.hlKey, state.hlNext, state.hlStage, state.hlT = key, want, 1, state.t
    SyncGhost()
    ghost:SetText(want)
    GradientAt(ghost, n, FadeLen(n))
    -- Presque invisible (pas 0) : le jeu prepare ainsi son dessin pour l'image suivante.
    ghost:SetAlpha(0.01)
    ghost:Show()
    return false
end

local function HighlightReset()
    state.hlKey, state.hlStage, state.hlNext, state.pgKey = nil, nil, nil, nil
    ghost:Hide()
end

-- Affichage "page entiere" (option DialogueWheelE_BubbleMode = "page") : chaque page s'affiche
-- d'un coup, des son ouverture (meme avant que la voix parte, meme sans voix). Le rythme ne change
-- pas : l'ecriture continue, invisible, et la page suivante vient au meme moment qu'en ecriture
-- progressive (avec la voix ; sans voix, temps d'ecriture puis temps de lecture). Quand une voix
-- lit, le mot qu'elle dit passe en couleur (or sur fond sombre, rouge fonce sur fond clair, ou la
-- couleur "Mot lu" du theme Personnalise), comme le narrateur de Spoken : le mot suit la position
-- de la bulle, qui suit la voix (vraies durees de Spoken, durees generees ou estimation). Couleur
-- seulement avec la case "Surligner le mot lu" de Storytale et "Highlight Words" dans Spoken
-- (sans elles : la page entiere, sans couleur). (Avant : ecriture progressive tant que la
-- voix n'etait pas partie, puis page entiere d'un coup : le passage se voyait.)
local function PageMode()
    return DialogueWheelE_BubbleMode == "page" and not state.dots and state.phase == "typing"
end
DWE.BubblePageMode = PageMode

-- Le mot que dit la voix dans la page affichee (debut et longueur en lettres dans la page).
local function PageWord(n)
    if not state.words then return nil end
    local segStart = 0
    for k = 1, (state.index or 1) - 1 do segStart = segStart + (state.lens[k] or 0) end
    local segEnd = segStart + (state.lens[state.index or 1] or 0)
    local pos, found = segStart + math.max(0, n), nil
    for _, w in ipairs(state.words) do
        if w.start >= segEnd then break end
        if w.start >= segStart then
            if found and w.start > pos then break end
            found = w
        end
    end
    if not found then return nil end
    return found.start - segStart, found.len
end

local function PageReveal(seg, n)
    local want, key = seg, "plain"
    local at, len
    if state.voiced and not state.manual then at, len = PageWord(n) end
    if at and not seg:find("|", 1, true) and HighlightOn() then
        local a, b = #Utf8Prefix(seg, at), #Utf8Prefix(seg, at + len)
        want = seg:sub(1, a) .. WordColor() .. seg:sub(a + 1, b) .. "|r" .. seg:sub(b + 1)
        key = state.index .. ":" .. at
    end
    if key ~= state.pgKey then
        -- (Tout le texte est visible : le changer d'un coup ne montre rien de plus.)
        state.hlKey, state.hlStage, state.hlNext = nil, nil, nil
        ghost:Hide()
        state.pgKey = key
        text:SetText(want)
    end
    state.fresh = nil
    text:SetAlpha(1)
    bubble:DWEWaitHide(false)
    if hasGradient then text:SetAlphaGradient((state.lens[state.index] or Utf8Len(seg)) + FADE_LETTERS + 1, 1) end
    state.shownN = n
end

-- Ecriture SANS le fondu du jeu (SetAlphaGradient). Avec lui, apres une pause de la voix, le jeu
-- ne redessinait plus le texte pendant ~0,45 s (« on » fige puis « one may » d'un coup ; le
-- journal montrait pourtant les lettres avancer). Prouve en jeu le 25/11 (/storytale sansfondu).
-- Ici : le texte deja ecrit est pose tel quel, avec les retours a la ligne calcules d'avance
-- (sinon un mot en cours sautait a la ligne suivante en grandissant), et la lettre qui arrive
-- apparait en fondu grace a deux petites lettres a part, placees au bout du texte.
DWE.noGradient = true
local measure = holder:CreateFontString(nil, "OVERLAY")
measure:Hide()
if measure.SetWordWrap then measure:SetWordWrap(false) end
local tails = {}
for i = 1, FADE_LETTERS do
    local t = holder:CreateFontString(nil, "OVERLAY")
    t:SetJustifyH("LEFT")
    t:SetJustifyV("TOP")
    if t.SetWordWrap then t:SetWordWrap(false) end
    t:Hide()
    tails[i] = t
end
local function CopyLook(fs)
    pcall(function()
        local f, size, flags = text:GetFont()
        if f and size then fs:SetFont(f, size, flags or "") end
    end)
    pcall(function() fs:SetTextColor(text:GetTextColor()) end)
    pcall(function() fs:SetShadowOffset(text:GetShadowOffset()) end)
    pcall(function() fs:SetShadowColor(text:GetShadowColor()) end)
end
local function Width(s)
    measure:SetText(s ~= "" and s or " ")
    local ok, w = pcall(measure.GetUnboundedStringWidth or measure.GetStringWidth, measure)
    if s == "" then return 0 end
    return (ok and type(w) == "number") and w or 0
end
local function LineHeight()
    measure:SetText("Ag")
    local ok1, h1 = pcall(measure.GetStringHeight, measure)
    measure:SetText("Ag\nAg")
    local ok2, h2 = pcall(measure.GetStringHeight, measure)
    h1, h2 = ok1 and h1 or 14, ok2 and h2 or 30
    local lh = h2 - h1
    return (lh and lh > 4) and lh or h1
end
-- Le texte avec ses retours a la ligne (une espace remplacee par "\n" : meme longueur, les
-- positions des lettres ne bougent pas). Garde tant que texte, largeur et police ne changent pas.
local function Wrapped(seg)
    local okW, width = pcall(text.GetWidth, text)
    width = (okW and type(width) == "number" and width > 0) and width or 300
    local okF, face, size = pcall(text.GetFont, text)
    local key = seg .. "\0" .. math.floor(width) .. "\0" .. tostring(okF and face) .. tostring(okF and size)
    if state.wrapKey == key then return state.wrapText end
    CopyLook(measure)
    local out, line, pos = {}, "", 1
    for at, word, after in seg:gmatch("()(%S+)()") do
        local gap = seg:sub(pos, at - 1)
        local cand = line == "" and word or (line .. gap .. word)
        -- (petite marge : la bulle est taillee a la largeur du texte + 4 ; sans elle, « paladin. »
        -- passait seul a la ligne chez Nara alors que le jeu le gardait sur la meme ligne)
        if line ~= "" and Width(cand) > width + 3 then
            -- retour a la ligne a la place de la premiere espace
            out[#out + 1] = "\n" .. gap:sub(2)
            line = word
        else
            out[#out + 1] = gap
            line = cand
        end
        out[#out + 1] = word
        pos = after
    end
    out[#out + 1] = seg:sub(pos)
    state.wrapKey, state.wrapText, state.lineH = key, table.concat(out), LineHeight()
    for _, t in ipairs(tails) do CopyLook(t) end
    return state.wrapText
end
DWE.BubbleWrapped = Wrapped
DWE.BubbleLineHeight = LineHeight
local function HideTails()
    for _, t in ipairs(tails) do t:Hide() end
    state.tailKey = nil
end
DWE.BubbleHideTails = HideTails
-- Lettres qui arrivent : le meme fondu que celui du jeu (les FADE_LETTERS lettres suivantes, de
-- plus en plus transparentes), refait avec des lettres a part. Il glisse en continu avec la part
-- de lettre deja ecrite : pas de saut d'une lettre a l'autre. Positions calculees une fois par
-- lettre ecrite (mesure du texte de la ligne), transparences a chaque image.
local function PlaceTails(shown, n, frac, fade)
    if state.tailKey ~= shown .. "\0" .. fade then
        state.tailKey = shown .. "\0" .. fade
        local w = state.wrapText or ""
        local rest = w:sub(#shown + 1)
        local lineStart = shown:match(".*\n()") or 1
        local line = shown:sub(lineStart)
        local _, lines = shown:gsub("\n", "")
        local lh = state.lineH or 14
        local k, i = 0, 1
        state.tailPos = {}
        while k < fade and i <= #rest do
            local ch = rest:match("^[%z\1-\127\194-\244][\128-\191]*", i)
            if not ch or ch == "" then break end
            i = i + #ch
            k = k + 1
            if ch == "\n" then
                lines, line = lines + 1, ""
            else
                local t = tails[k]
                if t and not ch:find("^%s") then
                    t:ClearAllPoints()
                    t:SetPoint("TOPLEFT", text, "TOPLEFT", Width(line), -lines * lh)
                    t:SetText(ch)
                    state.tailPos[k] = true
                end
                line = line .. ch
            end
        end
        for j = 1, #tails do if not state.tailPos[j] then tails[j]:Hide() end end
    end
    for k, on in pairs(state.tailPos or {}) do
        local t = tails[k]
        local a = 1 - (k - frac) / math.max(1, fade)
        if on and a > 0.01 then
            t:SetAlpha(math.min(1, a))
            t:Show()
        else
            t:Hide()
        end
    end
end
-- Ecriture fluide SANS aucun fondu du jeu (25/11) : le fondu de Blizzard avance lettre par lettre
-- (a-coups) et se figeait apres les pauses. Ici, chaque ligne est un texte du jeu ordinaire,
-- affiche tel quel (meme police, meme rendu : le meme visuel) ; la ligne en cours est
-- devoilee au pixel pres par une fenetre qui s'elargit en continu, et son bord est adouci par
-- quelques bandes de plus en plus transparentes (des copies exactes de la ligne, decoupees) :
-- le meme fondu que celui du jeu, mais qui glisse au lieu de sauter de lettre en lettre.
local SOFT_BANDS, SOFT_WIDTH = 6, 26 -- bandes du bord adouci, largeur totale (pixels)
local soft = { lines = {}, bands = {} }
DWE.bubbleSoft = soft
local function SoftLine(i)
    local fs = soft.lines[i]
    if not fs then
        fs = holder:CreateFontString(nil, "OVERLAY")
        fs:SetJustifyH("LEFT")
        fs:SetJustifyV("TOP")
        if fs.SetWordWrap then fs:SetWordWrap(false) end
        soft.lines[i] = fs
    end
    return fs
end
local function SoftClip(i)
    local c = soft.bands[i]
    if not c then
        local f = CreateFrame("Frame", nil, holder)
        if f.SetClipsChildren then f:SetClipsChildren(true) end
        f:SetFrameLevel(holder:GetFrameLevel() + 1)
        local fs = f:CreateFontString(nil, "OVERLAY")
        fs:SetJustifyH("LEFT")
        fs:SetJustifyV("TOP")
        if fs.SetWordWrap then fs:SetWordWrap(false) end
        c = { f = f, fs = fs }
        soft.bands[i] = c
    end
    return c
end
local function HideSoft()
    for _, fs in pairs(soft.lines) do fs:Hide() end
    for _, c in pairs(soft.bands) do c.f:Hide() end
    soft.key, soft.cur = nil, nil
    if state.customShown == "soft" then state.customShown = nil end
    text:Show()
end
local HideBufs = HideSoft -- (ancien nom, encore appele ailleurs)
DWE.BubbleHideBufs = HideSoft
-- Lignes du texte et largeur de chaque debut de ligne (mesurees une fois par texte).
local function SoftSetup(seg)
    local w = Wrapped(seg)
    if soft.key == state.wrapKey then return end
    soft.key = state.wrapKey
    soft.rows = {}
    local lh = state.lineH or 14
    local i, start = 0, 1
    for line in (w .. "\n"):gmatch("([^\n]*)\n") do
        i = i + 1
        local fs = SoftLine(i)
        CopyLook(fs)
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", text, "TOPLEFT", 0, -(i - 1) * lh)
        fs:SetText(line)
        fs:Hide()
        local k = 0
        for _ in line:gmatch("[%z\1-\127\194-\244][\128-\191]*") do k = k + 1 end
        soft.rows[i] = { text = line, start = start, chars = k, y = -(i - 1) * lh }
        start = start + k + 1 -- (+1 : le retour a la ligne)
    end
    for j = i + 1, #soft.lines do soft.lines[j]:Hide() end
    -- largeurs cumulees (prefixes exacts)
    for _, r in ipairs(soft.rows) do
        r.cum = { [0] = 0 }
        local acc, k = "", 0
        for ch in r.text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
            k = k + 1
            acc = acc .. ch
            r.cum[k] = Width(acc)
        end
    end
    for b = 1, 2 * SOFT_BANDS + 2 do CopyLook(SoftClip(b).fs) end
    soft.sp = math.max(0, Width("a a") - Width("aa")) -- largeur d'un espace
end
-- pos : lettre en cours (avec sa part deja ecrite), dans le texte avec retours a la ligne ;
-- limit : derniere lettre que le bord adouci peut toucher (pause a une ponctuation).
-- Ligne avec le mot lu en couleur (codes de couleur : la largeur des lettres ne change pas).
local function SoftColored(row, hlAt, hlLen)
    if not hlAt or row.text:find("|", 1, true) then return row.text end
    local rel = hlAt - (row.start - 1)
    if rel < 0 or rel >= row.chars then return row.text end
    local a = #Utf8Prefix(row.text, rel)
    local b = #Utf8Prefix(row.text, math.min(row.chars, rel + hlLen))
    return row.text:sub(1, a) .. WordColor() .. row.text:sub(a + 1, b) .. "|r" .. row.text:sub(b + 1)
end
local function SoftShow(pos, limit, hlAt, hlLen)
    local row, ri
    for i, r in ipairs(soft.rows) do
        if pos < r.start + r.chars + 1 or i == #soft.rows then row, ri = r, i break end
    end
    if not row then return end
    for i, r in ipairs(soft.rows) do
        local fs = soft.lines[i]
        if i < ri then
            if fs:GetText() ~= r.text then fs:SetText(r.text) end
            fs:SetAlpha(1)
            fs:Show()
        else fs:Hide() end
    end
    local shownText = SoftColored(row, hlAt, hlLen)
    local col = math.max(0, math.min(row.chars, pos - row.start + 1))
    local c0 = math.floor(col)
    local x = row.cum[c0] + (col - c0) * ((row.cum[math.min(row.chars, c0 + 1)] or row.cum[c0]) - row.cum[c0])
    local lc = math.max(0, math.min(row.chars, (limit or math.huge) - row.start + 1))
    local xmax = row.cum[math.floor(lc)] or x
    local lh = state.lineH or 14
    local bw = SOFT_WIDTH / SOFT_BANDS
    for b = 1, SOFT_BANDS + 1 do
        local c = SoftClip(b)
        local x0, x1, a
        if b == 1 then x0, x1, a = 0, x, 1
        else
            x0 = x + (b - 2) * bw
            x1 = x0 + bw
            a = 1 - (b - 1.5) / SOFT_BANDS
        end
        x1 = math.min(x1, math.max(x, xmax))
        if x1 - x0 < 0.5 or a <= 0.02 then
            c.f:Hide()
        else
            c.f:ClearAllPoints()
            c.f:SetPoint("TOPLEFT", text, "TOPLEFT", x0, row.y + 2)
            c.f:SetSize(x1 - x0, lh + 4)
            c.fs:ClearAllPoints()
            c.fs:SetPoint("TOPLEFT", text, "TOPLEFT", 0, row.y)
            if c.fs:GetText() ~= shownText then c.fs:SetText(shownText) end
            c.f:SetAlpha(a)
            c.f:Show()
            c.fs:Show()
        end
    end
    -- Fin de ligne : le bord adouci continue au debut de la ligne suivante (avant, il s'arretait
    -- au bout de la ligne, puis les premieres lettres de la suivante apparaissaient d'un coup).
    local nxt = soft.rows[ri + 1]
    local rowW = row.cum[row.chars] or 0
    local xmax2 = 0
    if nxt and limit then
        local lc2 = math.max(0, math.min(nxt.chars, limit - nxt.start + 1))
        xmax2 = nxt.cum[math.floor(lc2)] or 0
    end
    for b = 2, SOFT_BANDS + 1 do
        local c = SoftClip(SOFT_BANDS + b)
        local x0 = x + (b - 2) * bw - rowW - (soft.sp or 0)
        local s0, s1 = math.max(0, x0), math.min(x0 + bw, xmax2)
        local a = 1 - (b - 1.5) / SOFT_BANDS
        if not nxt or s1 - s0 < 0.5 or a <= 0.02 then
            c.f:Hide()
        else
            local t = SoftColored(nxt, hlAt, hlLen)
            c.f:ClearAllPoints()
            c.f:SetPoint("TOPLEFT", text, "TOPLEFT", s0, nxt.y + 2)
            c.f:SetSize(s1 - s0, lh + 4)
            c.fs:ClearAllPoints()
            c.fs:SetPoint("TOPLEFT", text, "TOPLEFT", 0, nxt.y)
            if c.fs:GetText() ~= t then c.fs:SetText(t) end
            c.f:SetAlpha(a)
            c.f:Show()
            c.fs:Show()
        end
    end
    soft.cur = { ri = ri, n = row.start - 1 + c0 }
end
-- Ce qui se lit dans la bulle (lettres nettes) : tests, journal.
function DWE.BubbleVisibleText()
    if state.customShown ~= "soft" or not soft.cur or not soft.rows then return nil, false end
    local parts = {}
    for i = 1, soft.cur.ri - 1 do parts[#parts + 1] = soft.rows[i].text end
    local r = soft.rows[soft.cur.ri]
    if not r then return table.concat(parts, "\n"), true end
    local cur = ""
    local k = 0
    for ch in r.text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        if k >= soft.cur.n - (r.start - 1) then break end
        cur = cur .. ch
        k = k + 1
    end
    parts[#parts + 1] = cur
    return table.concat(parts, "\n"), true
end
local function CustomReveal(seg, n)
    SoftSetup(seg)
    if state.customShown ~= "soft" then
        state.customShown = "soft"
        text:Hide()
    end
    local typed = math.max(n, math.min(n + 1, state.typed or n))
    local fade = hasGradient and FadeLen(n) or 0
    -- Mot lu surligne (option) : en couleur dans la ligne, toujours au meme rendu.
    local hlAt, hlLen
    if HighlightOn() then hlAt, hlLen = HighlightWord(n) end
    SoftShow(typed, n + fade, hlAt, hlLen)
end
-- Fin de la page : toutes les lignes nettes (memes textes que pendant l'ecriture : rien ne bouge).
local function SoftFinish(seg)
    if state.customShown ~= "soft" then return false end
    SoftSetup(seg)
    for i in ipairs(soft.rows) do soft.lines[i]:SetAlpha(1) soft.lines[i]:Show() end
    for _, c in pairs(soft.bands) do c.f:Hide() end
    soft.cur = { ri = #soft.rows + 1, n = 0 }
    return true
end

local function Reveal()
    local seg = state.segs[state.index] or ""
    local n = math.floor(state.typed or 0)
    if PageMode() then PageReveal(seg, n) return end
    if state.pgKey then
        -- On quitte la page entiere (option changee) : texte sans couleur, l'ecriture reprend.
        HighlightReset()
        text:SetText(seg)
        state.shownN = nil
    end
    if DWE.noGradient and state.phase == "typing" and not state.dots and n > 0 and not state.fresh then
        state.shownN = n
        text:SetAlpha(1)
        bubble:DWEWaitHide(false)
        HideTails()
        CustomReveal(seg, n)
        return
    end
    HideTails()
    if state.customShown == "soft" then HideSoft() end
    if state.customShown then
        -- retour au chemin du fondu du jeu (surlignage, points de suspension...) : texte entier
        state.customShown, state.shownN = nil, nil
        text:SetText(seg)
    end
    if hasGradient and state.phase == "typing" and not state.dots and HighlightStep(seg, n) then return end

    if n == state.shownN then
        -- Le jeu peut effacer le fondu quand la bulle devient visible : le texte entier se
        -- voyait jusqu'a la lettre suivante. On le remet a chaque image (sans toucher au texte).
        -- (/storytale fondu : essai sans ce rappel a chaque image, pour comparer)
        if hasGradient and not state.dots and state.phase == "typing" and n > 0 and not DWE.noFadeRepeat and not DWE.noGradient then GradientAt(text, n, FadeLen(n)) end
        return
    end
    state.shownN = n
    -- Rien d'ecrit encore (on attend la voix) : texte cache. Un fondu qui commence a 0 lettre
    -- montrait tout le texte d'un coup pendant l'attente, avant qu'il ne s'ecrive.
    -- Juste apres un nouveau texte, le fondu du jeu n'est applique qu'a l'image suivante : le
    -- texte entier se voyait une fraction de seconde. On attend cette image, cache.
    local show = n > 0 and not state.fresh
    text:SetAlpha(show and 1 or 0)
    bubble:DWEWaitHide(not show and (state.index or 1) <= 1)
    -- Image cachee du debut de page : le mot lu prend deja sa couleur (sinon il apparaissait en
    -- blanc puis passait en couleur une image plus tard).
    if state.fresh and hasGradient and state.phase == "typing" and not state.dots and n > 0 and HighlightOn() then
        local want, key = HighlightText(state.segs[state.index] or "", n)
        if key then text:SetText(want) state.hlKey = key end
    end
    if state.dots then
        -- Points de suspension : un point net apres l'autre (pas de fondu), place gardee.
        -- La bulle est taillee pour "..." : texte cale a gauche, les points s'ajoutent un a un.
        if hasGradient then text:SetAlphaGradient(100, 1) end
        text:SetText(Utf8Prefix(seg, n))
    elseif hasGradient and not DWE.noGradient then
        GradientAt(text, n, FadeLen(n))
    else
        -- (aussi /storytale sansfondu : essai sans le fondu du jeu, lettres posees une a une)
        if hasGradient then text:SetAlphaGradient(100000, 1) end
        text:SetText(Utf8Prefix(seg, n))
    end
end

local function StartSegment(i)
    local seg = state.segs[i]
    -- Premiere lettre tout de suite, a chaque page : la page apparait avec son texte apres une
    -- seule image cachee (le jeu n'applique le fondu d'un nouveau texte qu'a l'image suivante).
    -- (Les pages suivantes partaient de 0 lettre : bulle vide 3 ou 4 images, mesure en video.)
    state.index, state.phase, state.typed, state.shownN, state.customShown = i, "typing", 1, nil, nil
    HideTails()
    HideSoft()
    HighlightReset() -- FitTo remet le texte sans couleur
    -- (Ecriture de Storytale : ses lignes s'affichent des la premiere image, pas besoin
    -- d'attendre ; sans ca, la bulle restait vide une image entre deux pages.)
    state.fresh = not (DWE.noGradient and i > 1) or nil
    FitTo(seg, seg)
    Reveal()
end

local function FinishTyping()
    local seg = state.segs[state.index] or ""
    local len = state.lens[state.index] or Utf8Len(seg)
    state.phase, state.readT = "reading", 0
    state.duration = math.max(READ_MIN, math.min(READ_MAX, len * READ_PER_CHAR))
    state.typed = len
    HighlightReset() -- page finie : plus de mot surligne
    text:SetAlpha(1)
    bubble:DWEWaitHide(false)
    HideTails()
    if DWE.noGradient and SoftFinish(seg) then return end
    HideSoft()
    state.customShown = nil
    text:SetText((DWE.noGradient and state.wrapText and state.wrapKey and state.wrapKey:sub(1, #seg) == seg) and state.wrapText or seg)
    if hasGradient then text:SetAlphaGradient(len + FADE_LETTERS + 1, 1) end
end

local function Advance()
    state.manual = true -- le joueur prend la main : on ne suit plus la voix
    if state.phase == "typing" then
        FinishTyping()
    elseif state.phase == "reading" and state.index < #state.segs then
        StartSegment(state.index + 1)
    end
end

--------------------------------------------------------------------------------
-- Synchronisation avec la voix de Spoken
--------------------------------------------------------------------------------
-- Spoken indique la replique en cours (Spoken:GetNowPlaying) : son texte, sa duree et son
-- heure de fin. Si c'est le texte de la bulle, la part de texte ecrite suit la part de la
-- voix deja prononcee. Spoken n'a pas de vraie pause ("Stop" coupe, "Rejouer" recommence) :
-- pendant un arret, l'ecriture attend ; a la reprise, elle reprend quand la voix la rattrape.

local function SpokenInstalled()
    return type(rawget(_G, "Spoken")) == "table"
end

local function Normalize(s)
    s = s:lower():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return (s:gsub("[%s%p%c]", ""))
end

local function SameText(st, clipText)
    if type(clipText) ~= "string" or IsSecret(clipText) or not st.norm or st.norm == "" then return false end
    local theirs = Normalize(clipText)
    local n = math.min(24, #st.norm, #theirs)
    if n < 6 then return false end
    return theirs:find(st.norm:sub(1, n), 1, true) ~= nil or st.norm:find(theirs:sub(1, n), 1, true) ~= nil
end

-- Part prononcee (0 a 1) de la replique Spoken qui correspond a la bulle ; "hold" si Spoken
-- est a l'arret ; nil si Spoken ne lit pas ce texte.
-- Position des mots dans le texte affiche, en lettres depuis le debut (pour retrouver le mot
-- que lit la voix).
-- Pauses de la voix apres un point, une virgule ou un retour a la ligne (en lettres), comme les
-- sous-titres de Spoken : la bulle marque un temps au meme endroit que la voix au lieu de
-- prendre de l'avance a chaque phrase.
-- Valeurs ajustees (24/11) sur ~20 000 repliques de Spoken (quetes Alliance, Horde, partagees
-- et dialogues) dont on connait les vrais temps des mots. Ecart moyen bulle/voix, sur des
-- repliques mises de cote : ~0,5 s avant, ~0,33 s apres (dialogues : 0,38 -> 0,28 s).
DWE.SYNC_STOP, DWE.SYNC_COMMA, DWE.SYNC_LINE, DWE.SYNC_PARA, DWE.SYNC_PAGE = 5, 7, 10, 9, 6
DWE.SYNC_DASH = 6
-- Temps fixe en plus de chaque mot (en lettres) : un mot court prend proportionnellement plus
-- de temps a dire qu'un long.
DWE.SYNC_WORD = 1
-- En plus, quand un nouveau paragraphe ouvre une nouvelle page.
DWE.SYNC_PARA_PAGE = 0
-- Douceur des arrets et reprises aux pauses (secondes).
DWE.SYNC_EASE = 0.1
-- En plus, a la deuxieme page tournee, puis a chacune des suivantes (inutile d'apres les mesures).
DWE.SYNC_PAGE_LATER, DWE.SYNC_PAGE_NEXT = 0, 0
local SYNC_MARK = { ["."] = "stop", ["!"] = "stop", ["?"] = "stop", ["\226\128\166"] = "stop",
    ["\227\128\130"] = "stop", ["\239\188\129"] = "stop", ["\239\188\159"] = "stop",
    [","] = "comma", [";"] = "comma", [":"] = "comma", ["\239\188\140"] = "comma",
    ["\227\128\129"] = "comma", ["\239\188\155"] = "comma", ["\239\188\154"] = "comma",
    ["-"] = "dash", ["\226\128\148"] = "dash", ["\226\128\147"] = "dash" }
local SYNC_CLOSE = { ['"'] = true, ["'"] = true, [")"] = true, ["]"] = true, ["\194\187"] = true,
    ["\226\128\157"] = true, ["\226\128\153"] = true, ["\227\128\141"] = true,
    ["\227\128\143"] = true, ["\239\188\137"] = true }
local function PauseAfter(word, newline)
    local chars = {}
    for ch in word:gmatch("[%z\1-\127\194-\244][\128-\191]*") do chars[#chars + 1] = ch end
    local i = #chars
    while i > 1 and SYNC_CLOSE[chars[i]] do i = i - 1 end
    local mark = SYNC_MARK[chars[i] or ""]
    if mark == "stop" or newline then return DWE.SYNC_STOP end
    if mark == "comma" then return DWE.SYNC_COMMA end
    if mark == "dash" and i > 1 then return DWE.SYNC_DASH end
    return 0
end

local function BuildWords(pieces)
    local words, offset = {}, 0
    for pi, piece in ipairs(pieces) do
        for at, word, after in piece:gmatch("()(%S+)()") do
            local newline = piece:match("^%s*", after):find("\n") ~= nil
            words[#words + 1] = { start = offset + Utf8Len(piece:sub(1, at - 1)), len = Utf8Len(word),
                pause = PauseAfter(word, newline) }
        end
        -- Fin d'une page de la bulle : la page suivante efface le texte que la voix finit
        -- peut-etre de lire. On garde une marge avant de tourner la page.
        if words[#words] and pi < #pieces then
            local w = words[#words]
            -- Des la deuxieme page tournee, la voix prend un peu plus son temps : un peu plus
            -- d'attente a chacune (meme regle pour tout texte, quelle que soit sa longueur).
            w.pause = math.max(w.pause or 0, DWE.SYNC_STOP) + DWE.SYNC_PAGE
                + (pi >= 3 and DWE.SYNC_PAGE_NEXT or pi == 2 and DWE.SYNC_PAGE_LATER or 0)
            w.pageEnd = true
        end
        offset = offset + Utf8Len(piece)
    end
    return words, offset
end

-- Les sauts de ligne sont retires du texte de la bulle, mais la voix y marque un vrai temps
-- (surtout entre deux paragraphes) : on les reprend dans le texte d'origine, mot pour mot.
local function AddLineBreaks(words, raw)
    if type(raw) ~= "string" then return end
    raw = raw:gsub("\r", "")
    local count = 0
    for _ in raw:gmatch("%S+") do count = count + 1 end
    if count ~= #words then return end -- texte different : on ne devine pas
    local i = 0
    for after in raw:gmatch("%S+()") do
        i = i + 1
        local w = words[i]
        if not w then return end
        local gap = raw:match("^%s*", after)
        local _, n = gap:gsub("\n", "")
        -- Nouveau paragraphe sur une nouvelle page : la voix y marque son plus long temps.
        if n >= 2 and w.pageEnd then w.pause = (w.pause or 0) + DWE.SYNC_PARA_PAGE
        elseif n >= 2 then w.pause = math.max(w.pause or 0, DWE.SYNC_PARA)
        elseif n == 1 then w.pause = math.max(w.pause or 0, DWE.SYNC_LINE) end
    end
end

-- Avant que la voix soit entendue : on ecrit au rythme d'une voix (lettres par seconde), en
-- ralentissant en douceur a l'approche de PRE_VOICE_MAX lettres (jamais d'arret net).
DWE.PRE_VOICE_SPEED, DWE.PRE_VOICE_MAX = 17, 12
function DWE.PreVoiceStep(pos, dt)
    local k = math.max(0.15, 1 - pos / DWE.PRE_VOICE_MAX)
    return pos + dt * DWE.PRE_VOICE_SPEED * k
end

-- Correspondance lettres <-> "temps de voix" (lettres + pauses), par segments droits : pendant
-- une pause, le temps avance mais la lettre reste la meme.
local function BuildMap(words, total)
    local c, w, extra, stops = { 0 }, { 0 }, 0, {}
    local base = tonumber(DWE.SYNC_WORD) or 0
    for _, wd in ipairs(words or {}) do
        -- Temps fixe du mot : etale sur ses lettres (pas d'arret visible entre les mots).
        if base > 0 then
            local s0, e0 = math.min(total, wd.start), math.min(total, wd.start + wd.len)
            if e0 > s0 then
                c[#c + 1], w[#w + 1] = s0, s0 + extra
                extra = extra + base
                c[#c + 1], w[#w + 1] = e0, e0 + extra
            end
        end
        if (wd.pause or 0) > 0 then
            local e = math.min(total, wd.start + wd.len)
            stops[#stops + 1] = e
            c[#c + 1], w[#w + 1] = e, e + extra
            extra = extra + wd.pause
            c[#c + 1], w[#w + 1] = e, e + extra
        end
    end
    c[#c + 1], w[#w + 1] = total, total + extra
    return { c = c, w = w, totalW = total + extra, stops = stops }
end
local function MapLookup(from, to, x)
    if x <= from[1] then return to[1] end
    for i = 2, #from do
        if x <= from[i] then
            local a, b = from[i - 1], from[i]
            if b - a <= 0 then return to[i - 1] end
            return to[i - 1] + (x - a) / (b - a) * (to[i] - to[i - 1])
        end
    end
    return to[#to]
end
DWE.SyncBuildWords, DWE.SyncBuildMap, DWE.SyncMapLookup, DWE.SyncLineBreaks = BuildWords, BuildMap, MapLookup, AddLineBreaks

-- Ecriture reguliere sur une voix aux durees generees : pos (lettre ecrite), target (lettre
-- que dit la voix), rate (rythme moyen de la voix, lettres/s).
DWE.GEN_SPEED = 1.2 -- vitesse de base : part du rythme moyen (la voix parle plus vite que son rythme moyen, pauses comprises)
DWE.GEN_CATCH = 0.6 -- secondes pour combler doucement un ecart avec la voix
DWE.GEN_SMOOTH = 0.35 -- secondes : la vitesse change en douceur (jamais d'une image a l'autre)
DWE.GEN_EARLY = 0.15 -- secondes : on repart d'une pause un instant avant le mot suivant (nos durees le placent souvent un peu tard)
DWE.GEN_AHEAD = 12 -- lettres d'avance au-dela desquelles on ralentit fort
function DWE.GenSmoothStep(st, pos, target, rate, dt)
    st.genDbg = st.genDbg or {}
    st.genDbg.pos, st.genDbg.target, st.genDbg.next = pos, target, st.genNextIn
    local base = rate * DWE.GEN_SPEED
    -- Pauses : fin des mots suivis d'une ponctuation (ou d'une fin de page de la bulle).
    if not st.genStops then
        st.genStops = {}
        for _, w in ipairs(st.words or {}) do
            if (w.pause or 0) > 0 or w.pageEnd then st.genStops[#st.genStops + 1] = w.start + w.len end
        end
    end
    -- Prochaine pause devant nous : on ne la depasse que quand la voix l'a passee.
    local stop
    for _, p in ipairs(st.genStops) do
        if p >= pos - 0.01 then stop = p break end
    end
    local soon = st.genNextIn and st.genNextIn < DWE.GEN_EARLY
    if stop and pos >= stop - 0.01 and target < stop + 0.5 and not soon then
        st.genWaitAt = stop
        -- Arrivee a la ponctuation avant la voix : on l'attend la (pause naturelle). On repartira
        -- a la vitesse de base, sans demarrage lent.
        st.spd = base
        return math.max(pos, stop) -- pile sur la ponctuation (sinon elle restait cachee : « fact| »)
    end
    st.genWaitAt = nil
    local gap = target - pos
    local want = base + gap / DWE.GEN_CATCH
    if gap < -DWE.GEN_AHEAD then want = base * 0.25 end
    want = math.max(base * 0.45, math.min(base * 3, want))
    st.spd = st.spd and (st.spd + (want - st.spd) * math.min(1, dt / DWE.GEN_SMOOTH)) or want
    local new = pos + st.spd * dt
    if stop and target < stop + 0.5 and not soon then new = math.min(new, stop) end
    return new
end

-- Avance de l'ecriture sur la voix, en "temps de voix" (pauses comprises) ; rend la lettre.
local VoiceSpeed
local function VoiceStep(st, pos, share, length, dt)
    -- La voix n'est pas encore entendue : la bulle avance tout doucement sur les premieres
    -- lettres (ni figee, ni en avance sur la voix).
    if share <= 0 then return DWE.PreVoiceStep(pos, dt) end
    local map = not st.timed and st.wmap
    if not map then
        local rate = st.total / length
        if st.generated then
            -- Fluidite d'abord (25/11) : suivre chaque mot a la lettre pres faisait hacher
            -- l'ecriture (nos durees generees ne tombent jamais tout a fait juste : arrets au
            -- milieu de « within », « su|ch », « on|e »...). La bulle ecrit maintenant a vitesse
            -- reguliere, qui ne change qu'en douceur pour rester avec la voix, et ne s'arrete
            -- qu'aux ponctuations, quand la voix y fait vraiment une pause. Regle generale :
            -- marche pareil pour tous les PNJ, sans reglage par replique.
            return DWE.GenSmoothStep(st, pos, share * st.total, rate, dt)
        end
        return pos + VoiceSpeed(st, pos, share * st.total, rate, dt) * dt
    end
    -- (pos suit la cible avec un petit retard voulu, voir plus bas : on ne recale que si
    -- l'ecriture est passee devant, ex. clic pour finir la page.)
    if not st.posW or pos - MapLookup(map.w, map.c, st.posW) > 1.5 then
        st.posW = MapLookup(map.c, map.w, pos)
    end
    length = math.max(0.1, length - math.max(0, math.min(length * 0.3, tonumber(DWE.VOICE_LEAD) or 0)))
    local speed = VoiceSpeed(st, st.posW, share * map.totalW, map.totalW / length, dt)
    st.posW = math.min(map.totalW, st.posW + speed * dt)
    -- Arrets et reprises en douceur aux pauses (virgule, point) : l'ecriture ralentit puis
    -- repart sur un dixieme de seconde au lieu de s'arreter net, ce qui donnait des a-coups.
    local target = MapLookup(map.w, map.c, st.posW)
    local new = pos + (target - pos) * math.min(1, dt / DWE.SYNC_EASE)
    if target - new < 0.3 then new = target end
    return math.max(pos, new)
end

-- Part du texte deja lue d'apres le mot courant des sous-titres de Spoken (SpokenEnv.Transcript),
-- nil si ce n'est pas disponible pour cette replique.
local function WordShare(st, clip)
    local env = rawget(_G, "SpokenEnv")
    local T = type(env) == "table" and rawget(env, "Transcript")
    -- Seulement avec les vraies durees des mots (fournies par la voix) : sans elles, Spoken les
    -- estime (un mot court y dure presque autant qu'un long), ce qui ferait hesiter l'ecriture
    -- sur certains mots. Le rythme moyen de la voix est alors plus regulier.
    if type(T) ~= "table" or not T.timed or not rawequal(T.clip, clip) or type(T.words) ~= "table" then return nil end
    local n, m = #T.words, st.words and #st.words or 0
    if n == 0 or m == 0 or not (st.total and st.total > 0) then return nil end
    local okP, prog = pcall(T.GetProgress, T)
    if not okP or type(prog) ~= "number" then return nil end
    local okW, i = pcall(T.WordAt, T, prog)
    local w = okW and type(i) == "number" and T.words[i]
    if not w or type(w.start) ~= "number" or type(w.finish) ~= "number" then return nil end
    local tw = (tonumber(T.totalWeight) or 0) * prog
    local frac = math.max(0, math.min(1, (tw - w.start) / math.max(1e-6, w.finish - w.start)))
    local pos
    if n == m then
        local ow = st.words[i]
        pos = ow.start + frac * ow.len
    else
        local x = (i - 1 + frac) / n * m
        local j = math.min(m, math.floor(x) + 1)
        local ow = st.words[j]
        pos = ow.start + math.min(1, x - (j - 1)) * ow.len
    end
    return math.max(0, math.min(1, pos / st.total))
end

-- Durees des mots generees (GeneratedTimings.lua) pour les repliques dont la voix n'en fournit
-- pas. Cle : nom du fichier son de la replique, sans .ogg. Seulement si le nombre de mots
-- correspond au texte de la voix, et pour un jeu en anglais (les packs de voix sont en anglais).
local genCache = setmetatable({}, { __mode = "k" })
-- Spoken : clip.path = Interface\AddOns\SpokenQuestsAudio<pack>\generated\sounds\<dossier>\<nom>.ogg
local function ClipSoundName(clip)
    local v = clip.path
    local name = type(v) == "string" and v:match("([^/\\]+)$")
    return name and (name:gsub("%.[Oo][Gg][Gg]$", "")) or nil
end
-- Nombre de mots du texte de la voix, comptes comme Spoken les compte (un temps par mot de
-- Spoken:CaptionWords) ; sans cette fonction, mots separes par des espaces.
local function CountWords(s)
    if type(s) ~= "string" then return 0 end
    local api = rawget(_G, "Spoken")
    if type(api) == "table" and type(api.CaptionWords) == "function" then
        local ok, words = pcall(api.CaptionWords, api, s)
        if ok and type(words) == "table" then return #words end
    end
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local n = 0
    for _ in s:gmatch("%S+") do n = n + 1 end
    return n
end
local function GeneratedTimes(clip)
    local c = genCache[clip]
    if c ~= nil then return c or nil end
    c = false
    local tbl = DWE.GeneratedTimings
    local loc = GetLocale and GetLocale() or "enUS"
    local key = type(tbl) == "table" and type(loc) == "string" and loc:sub(1, 2) == "en" and ClipSoundName(clip)
    local s = key and tbl[key]
    if type(s) == "string" then
        local t = {}
        for x in s:gmatch("%S+") do t[#t + 1] = tonumber(x) end
        local present = type(clip.present) == "table" and clip.present or {}
        if #t > 0 and #t == CountWords(present.transcript or clip.text) then c = t end
    end
    genCache[clip] = c
    return c or nil
end
DWE.BubbleGeneratedTimes = GeneratedTimes

-- Part du texte deja lue d'apres ces durees : temps ecoule depuis le debut du son, mot courant
-- plus la fraction de ce mot deja dite (comme avec les vraies durees). Un mot ne dure jamais plus
-- que sa longueur ne le permet : pendant une pause de la voix, l'ecriture attend au bout du mot.
DWE.GEN_DELAY = 0.25 -- secondes entre le lancement du son et la voix entendue (durees generees)
DWE.GEN_EASE = 0.12 -- secondes : retard de l'ecriture sur la lettre dite (durees generees)
DWE.GEN_FLOW = 0.8 -- secondes : blanc apres un mot sans ponctuation au-dela duquel la bulle attend (souffle)
local function GeneratedShare(st, clip, length)
    local t = GeneratedTimes(clip)
    local m = st.words and #st.words or 0
    if not t or m == 0 or not (st.total and st.total > 0) then return nil end
    -- Le son est entendu un peu apres son lancement par Spoken (chargement) : DWE.GEN_DELAY,
    -- mesure en jeu le 24/11 : 0,40 s d'avance sans delai, 0,27 s de retard avec 0,4 s.
    local e = GetTime() - (clip.spokenAt - length) - DWE.GEN_DELAY
    if e <= t[1] then st.genNextIn = t[1] - e return 0 end
    local n, i = #t, #t
    for k = 1, n - 1 do
        if e < t[k + 1] then i = k break end
    end
    st.genNextIn = (t[i + 1] or length) - e
    local j = n == m and i or math.min(m, math.floor((i - 1) / n * m) + 1)
    local ow = st.words[j]
    -- Un mot s'ecrit pendant tout le temps qui le separe du suivant : l'ecriture coule d'un mot
    -- a l'autre. Avant, chaque mot s'ecrivait d'un coup puis attendait le debut du suivant :
    -- arrets et reprises a chaque mot, la bulle semblait ramer (vu en jeu, Theridran, 25/11).
    -- Seul un mot suivi d'une ponctuation (virgule, point...) ou d'un tres long blanc fait
    -- attendre la bulle au bout du mot : la voix y marque une vraie pause.
    local gap = (t[i + 1] or length) - t[i]
    local cap = 0.12 + 0.07 * (ow.len or 5)
    local pause = (ow.pause or 0) > 0 or ow.pageEnd or gap > cap + DWE.GEN_FLOW
    local dur = pause and math.min(gap, cap) or gap
    local frac = math.max(0, math.min(1, (e - t[i]) / math.max(0.05, dur)))
    local pos
    if n == m then
        pos = ow.start + frac * ow.len
    else
        local x = (i - 1 + frac) / n * m
        local jj = math.min(m, math.floor(x) + 1)
        local w = st.words[jj]
        pos = w.start + math.min(1, x - (jj - 1)) * w.len
    end
    return math.max(0, math.min(1, pos / st.total))
end

local function SpokenShare(st)
    if st.manual or not st.norm then return nil end
    local api = rawget(_G, "Spoken")
    if type(api) ~= "table" or type(api.GetNowPlaying) ~= "function" then return nil end
    local okP, paused = pcall(api.IsPaused, api)
    local okC, clip = pcall(api.GetNowPlaying, api)
    -- Replique sans son (texte seul, lu "a vue" par Spoken) : rien a suivre.
    if not okC or type(clip) ~= "table" or clip.textOnly then return nil end
    if clip ~= st.clip then
        st.clip = clip
        st.wordOff, st.offAt = nil, nil
        local present = type(clip.present) == "table" and clip.present or {}
        st.clipMatch = SameText(st, present.transcript or clip.text)
        -- Texte different (ex. noms remplaces, texte de quete ou de dialogue) : si la voix a
        -- commence juste apres l'ouverture de ce texte, c'est bien lui qu'elle lit.
        -- ... mais seulement si c'est la voix du PNJ a qui l'on parle : la voix d'un autre PNJ ou
        -- d'un livre (qui finit de parler) faisait attendre la bulle sur un texte qui n'est pas le sien.
        if not st.clipMatch and st.setAt and tonumber(clip.spokenAt) and tonumber(clip.length)
            and DWE.BubbleVoiceIsNPC(clip) then
            local started = clip.spokenAt - clip.length
            st.clipMatch = started >= st.setAt - 1 and started <= st.setAt + 6
        end
    end
    if not st.clipMatch then return nil end
    if okP and paused then return "paused" end
    local length = tonumber(clip.length)
    if not (length and length > 0 and tonumber(clip.spokenAt)) then return "hold" end
    -- Voix bien trop courte pour ce texte (ex. la salutation du PNJ, encore en cours, prise pour
    -- la voix du texte de quete) : ce n'est pas elle qui lit ce texte. On ne la suit pas, sinon le
    -- texte defilait a toute vitesse.
    if st.total and st.total / length > 35 then
        st.clipMatch = false
        return nil
    end
    -- Le mieux : le mot que Spoken est en train de lire (meme calcul que ses sous-titres,
    -- avec les vraies durees des mots quand la voix les fournit).
    -- Base reguliere : le temps ecoule de la voix. Le mot lu par Spoken avance par sauts (un mot
    -- a la fois) : suivre ses sauts faisait hacher l'ecriture. Il ne sert plus qu'a corriger
    -- doucement l'ecart (rythme reel de la voix), sans a-coup.
    local now = GetTime()
    -- Le son met un instant a etre entendu apres son lancement (chargement, silence au debut du
    -- fichier) : la voix parle pendant (duree - delai), a partir du delai.
    local lead = math.max(0, math.min(length * 0.3, tonumber(DWE.VOICE_LEAD) or 0))
    local timeShare = math.max(0, math.min(1, (now - (clip.spokenAt - length) - lead) / (length - lead)))
    -- Vraies durees des mots fournies par la voix : on suit directement le mot lu (pauses
    -- comprises), sans rien deviner ni ajouter (ni delai, ni pauses de page).
    local share = WordShare(st, clip)
    if share then
        st.timed, st.generated = true, nil
        return share, length
    end
    -- Pas de durees dans la voix : celles generees pour cette replique, si elles existent.
    share = GeneratedShare(st, clip, length)
    if share then
        st.timed, st.generated = true, true
        return share, length
    end
    st.timed, st.generated = nil, nil
    return timeShare, length
end

-- Vitesse d'ecriture qui suit la voix en douceur, sans saut : la vitesse de la voix (mesuree,
-- lissee) plus un rattrapage de l'ecart. En avance, on ralentit jusqu'a attendre la voix.
local CATCH_TIME = 1.2
function VoiceSpeed(st, pos, target, rate, dt)
    -- Vitesse = rythme moyen de la voix (constant) + rattrapage doux de l'ecart. Pas de mesure
    -- de vitesse instantanee : elle variait d'une image a l'autre et faisait hacher l'ecriture.
    -- Zone morte : tant que l'ecart reste petit (quelques mots), on garde exactement le rythme de
    -- la voix, sans aucune correction ; on ne corrige que les vrais decalages.
    local gap = target - pos
    -- En retard : zone morte large (rattraper se voit peu). En avance : presque aucune, et on
    -- ralentit franchement, le texte ne doit pas devancer la voix.
    local dead, deadAhead = math.max(6, rate * 0.6), math.max(2, rate * 0.12)
    local want = rate
    if gap > dead then want = rate + (gap - dead) / CATCH_TIME
    elseif gap < -deadAhead then want = rate + (gap + deadAhead) / (CATCH_TIME * 0.6) end
    want = math.max(rate * 0.4, math.min(rate * 1.5, want))
    -- La vitesse elle-meme change en douceur (comme un lecteur qui accelere ou ralentit un peu),
    -- jamais d'une image a l'autre : la correction ne se voit pas.
    st.spd = st.spd and (st.spd + (want - st.spd) * math.min(1, dt * 1.5)) or want
    return st.spd
end

-- Voix a l'arret (pause de Spoken) : on attend un peu, puis on continue seul.
local HOLD_MAX = 1.0
-- Temps maximum d'attente de la voix au debut d'un texte (ensuite on ecrit seul).
DWE.VOICE_WAIT = 1.2
-- Delai entre le lancement du son par Spoken et la voix entendue (secondes).
DWE.VOICE_LEAD = 0.6
-- Juste apres un nouveau texte, la voix de Spoken met un instant a partir : on demarre
-- doucement plutot que de prendre de l'avance, pour ne pas avoir a ralentir ensuite.
local SLOW_START, SLOW_FACTOR = 0.4, 0.6
local function StartFactor(st)
    if st.voiced or not SpokenInstalled() then return 1 end
    local a = (st.age or 0) / SLOW_START
    if a >= 1 then return 1 end
    return SLOW_FACTOR + (1 - SLOW_FACTOR) * a -- montee progressive, sans a-coup
end

-- Position d'ecriture dans le texte entier (lettres depuis le debut du premier morceau).
local function SegStart(i)
    local start = 0
    for k = 1, i - 1 do start = start + (state.lens[k] or 0) end
    return start
end

local function CurrentPos()
    local start = SegStart(state.index)
    if state.phase == "reading" then return start + (state.lens[state.index] or 0) end
    return start + (state.typed or 0)
end

-- Place l'ecriture a la position `pos` (jamais en arriere) : change de morceau si besoin.
local function MoveTo(pos)
    local start = 0
    for i, len in ipairs(state.lens) do
        -- Pile a la fin d'une page (pause de la voix) : on reste sur cette page, la suivante
        -- ne s'ouvre qu'au moment d'ecrire sa premiere lettre (pas de bulle vide qui attend).
        if pos <= start + len or i == #state.lens then
            if i > state.index then StartSegment(i) end
            if i == state.index and state.phase == "typing" then
                local off = pos - start
                if off > (state.typed or 0) then state.typed = off end
                if state.typed >= len then FinishTyping() else Reveal() end
            end
            return
        end
        start = start + len
    end
end

-- Rejoindre une voix deja en cours (au moins JOIN_AFTER secondes entendues avant l'ouverture de
-- ce texte) : on place l'ecriture a l'endroit lu par la voix, une seule fois, a l'ouverture.
DWE.JOIN_AFTER = 1.5
function DWE.BubbleJoinVoice(st, share, length)
    local clip = st.clip
    if type(clip) ~= "table" or not st.setAt or share <= 0 then return end
    local spokenAt, len = tonumber(clip.spokenAt), tonumber(clip.length)
    if not (spokenAt and len) then return end
    local lead = math.max(0, math.min(len * 0.3, tonumber(DWE.VOICE_LEAD) or 0))
    if st.setAt - (spokenAt - len) - lead < DWE.JOIN_AFTER then return end
    local map = not st.timed and st.wmap
    local pos
    if map then
        st.posW = share * map.totalW
        pos = MapLookup(map.w, map.c, st.posW)
    else
        pos = share * (st.total or 0)
    end
    if pos > CurrentPos() then MoveTo(math.min(st.total or pos, pos)) end
end

-- Journal image par image des premieres images d'un texte (/storytale followlog).
local frameLog = { n = 0 }
local function LogFrames(tag)
    if not (DWE.followLog and DWE.FLog) then return end
    frameLog.n, frameLog.tag = 10, tag
end
local function FrameLogTick()
    if frameLog.n <= 0 then return end
    frameLog.n = frameLog.n - 1
    local tb = DWE.textBox
    local okA, ga = pcall(text.GetAlpha, text)
    DWE.FLog(("%s img%d : bulle vis=%s a=%s attente=%s | texte a=%s tape=%s phase=%s | popup vis=%s"):format(
        tostring(frameLog.tag), 10 - frameLog.n, tostring(bubble:IsVisible()), tostring(bubble:GetAlpha()),
        tostring(bubble.dweWaitHide), tostring(okA and ga), tostring(state.typed), tostring(state.phase),
        tostring(tb and tb:IsVisible())))
end
DWE.BubbleFrameLog = LogFrames
bubble:HookScript("OnShow", function() LogFrames("apparition") end)

bubble:SetScript("OnUpdate", DWE.Prof("bulle", function(_, elapsed)
    state.t = state.t + elapsed
    state.age = (state.age or 0) + elapsed
    FrameLogTick()
    if state.fresh then state.fresh = nil state.shownN = nil Reveal() end
    if state.phase == "typing" then Reveal() end -- garde le fondu en place, meme en pause
    if state.phase == "idle" then return end

    local share, length = SpokenShare(state)
    -- Diagnostic (/storytale sync) : une ligne par seconde sur le suivi de la voix.
    if DWE.bubbleSyncDebug and state.phase ~= "idle" then
        state.dbgT = (state.dbgT or 0) + elapsed
        if state.dbgT >= 1 then
            state.dbgT = 0
            local clip = state.clip
            local present = type(clip) == "table" and type(clip.present) == "table" and clip.present or {}
            local who = type(clip) == "table" and DWE.SpokenFocus and DWE.SpokenFocus.SpeakerOf and DWE.SpokenFocus.SpeakerOf(clip)
            local env = rawget(_G, "SpokenEnv")
            local T = type(env) == "table" and rawget(env, "Transcript")
            local tw = type(T) == "table" and rawequal(T.clip, clip) and T.words
            local wi = "-"
            if tw and type(T.GetProgress) == "function" and type(T.WordAt) == "function" then
                local okP, prog = pcall(T.GetProgress, T)
                local okW, i = pcall(T.WordAt, T, prog)
                if okW and type(i) == "number" and tw[i] then wi = i .. ":" .. tostring(tw[i].text) end
            end
            print(("|cff33ff99Storytale|r sync: minutage=%s genere=%s motSpoken=%s"):format(
                tostring(type(T) == "table" and T.timed), tostring(state.generated == true), wi))
            print(("|cff33ff99Storytale|r sync: %s pos=%d/%d voix=%s match=%s duree=%s qui=%s texte=%s"):format(
                tostring(state.phase), CurrentPos(), state.total or 0,
                type(share) == "number" and string.format("%.0f%%", share * 100) or tostring(share),
                tostring(state.clipMatch), tostring(length and string.format("%.1f", length)),
                tostring(who), tostring(present.transcript or (type(clip) == "table" and clip.text) or "-"):sub(1, 40)))
        end
    end
    local waitVoice = false
    if share == "paused" then
        -- Spoken en pause (Stop) : on attend un peu, puis on continue seul.
        state.holdT = (state.holdT or 0) + elapsed
        if state.holdT < HOLD_MAX then return end
        share = nil
    elseif share == "hold" then
        -- La voix n'a pas encore demarre : on l'attend un instant (le texte prenait de l'avance
        -- et ne la rattrapait plus), puis on ecrit doucement si elle tarde.
        -- La voix n'a pas encore demarre : on ecrit doucement (la bulle apparait tout de suite
        -- avec son texte), sans prendre d'avance qu'on ne rattraperait pas.
        state.waitT = (state.waitT or 0) + elapsed
        share, waitVoice = nil, state.waitT < 1.2 and "slow" or true
    else
        state.holdT = 0
    end
    -- Avec Spoken, la voix met un instant a partir apres l'ouverture : on l'attend un peu au
    -- lieu d'ecrire seul (l'avance prise la n'etait jamais rattrapee).
    if share == nil and not state.voiced and state.phase == "typing" and SpokenInstalled()
        and not state.manual and (state.age or 0) < DWE.VOICE_WAIT then
        waitVoice = "slow"
    end
    if share and length then
        -- Voix deja bien partie quand ce texte s'ouvre (on revient voir le PNJ pendant qu'il lit
        -- encore ce texte) : la bulle s'ouvre directement la ou en est la voix, au lieu de
        -- repartir du debut et de rester tres loin derriere elle.
        if not state.voiced and type(share) == "number" then DWE.BubbleJoinVoice(state, share, length) end
        -- Voix de Spoken : on suit son rythme, en rattrapant les ecarts en douceur.
        state.voiced = true
        MoveTo(math.min(state.total, VoiceStep(state, CurrentPos(), share, length, elapsed)))
        return
    end

    -- Sans voix : vitesse fixe, puis temps de lecture avant le morceau suivant.
    if state.phase == "typing" then
        if waitVoice and not state.voiced and (state.age or 0) < DWE.VOICE_WAIT then
            -- En attendant que la voix de Spoken demarre : on ecrit deja, au rythme d'une voix,
            -- en ralentissant doucement (quelques lettres d'avance au plus, rattrapees ensuite).
            state.typed = DWE.PreVoiceStep(state.typed or 0, elapsed)
        else
            state.typed = (state.typed or 0) + elapsed * (state.dots and 3 or (SpokenInstalled() and SPOKEN_PACE or TYPE_SPEED))
                * (waitVoice == "slow" and 0.25 or waitVoice and 0.5 or StartFactor(state))
        end
        -- On va jusqu'au bout du fondu pour que les dernieres lettres apparaissent aussi en douceur.
        if state.typed >= (state.lens[state.index] or 0) then FinishTyping() else Reveal() end
    elseif state.phase == "reading" and state.index < #state.segs then
        state.readT = (state.readT or 0) + elapsed
        if state.readT >= state.duration then StartSegment(state.index + 1) end
    end
end))

-- /storytale fluide : mesure en jeu des arrets de l'ecriture hors ponctuation (plus besoin de
-- video). A la fin de chaque replique : nombre d'arrets, le pire et sur quel mot, et le mode suivi
-- (durees Spoken, durees generees, rythme moyen, sans voix).
local fluid = {}
DWE.bubbleFluid = fluid
DWE.bubbleState = state
local function FluidMode()
    if not state.voiced then return "sans voix" end
    if state.generated then return "durees generees" end
    if state.timed then return "durees Spoken" end
    return "rythme moyen"
end
local function FluidWord(seg, n)
    local before = seg:sub(1, n):match("(%S*)$") or ""
    local after = seg:sub(n + 1):match("^(%S*)") or ""
    return before .. "|" .. after
end
function DWE.BubbleFluidReport()
    if fluid.done or not fluid.raw then return end
    local f = fluid
    fluid.done = true
    if not DWE.fluidLog then return end
    local worst = f.worst or 0
    print(("|cff33ff99Storytale|r fluidite : %d arret(s) hors ponctuation (> 0,15 s), le pire %.2f s%s | %s | %s"):format(
        f.count or 0, worst, f.where and (" sur « " .. f.where .. " »") or "", f.mode or "?",
        tostring(UnitName and UnitName("npc") or "?")))
    if f.detail and (f.count or 0) > 0 then print("|cff33ff99Storytale|r fluidite (detail) : " .. f.detail) end
end
bubble:HookScript("OnUpdate", function(_, elapsed)
    if not DWE.fluidLog then return end
    -- Chaque nouveau texte (meme identique : les trois maitres druides disent la meme chose)
    -- commence une nouvelle mesure.
    state.fluidId = state.fluidId or 0
    if state.fluidId ~= fluid.id then
        DWE.BubbleFluidReport()
        fluid.id = state.fluidId
        fluid.raw, fluid.done, fluid.count, fluid.worst, fluid.where, fluid.still, fluid.lastN, fluid.lastI = state.raw, nil, 0, 0, nil, 0, nil, nil
        fluid.detail, fluid.dbg0 = nil, nil
        DWE.fluidTrace = { t0 = GetTime and GetTime() or 0, who = UnitName and UnitName("npc") }
    end
    if state.phase == "reading" and state.index == #state.segs then DWE.BubbleFluidReport() return end
    if state.phase ~= "typing" or state.manual then fluid.still = 0 return end
    fluid.mode = FluidMode()
    local n, i = state.shownN or 0, state.index
    if n == fluid.lastN and i == fluid.lastI and n > 0 then
        fluid.still = fluid.still + elapsed
    else
        if fluid.still > 0.15 then
            local seg = state.segs[fluid.lastI or 1] or ""
            -- derniere lettre montree (une espace apres la virgule n'est plus la pause : la bulle
            -- est repartie, « town, |one » compte)
            local prev = seg:sub(fluid.lastN or 0, fluid.lastN or 0)
            -- (juste avant la ponctuation, « fact|, », c'est aussi la pause de la virgule)
            local nextc = seg:sub((fluid.lastN or 0) + 1, (fluid.lastN or 0) + 1)
            if not prev:find("[%.,!?;:%-]") and not nextc:find("[%.,!?;:%-]") then
                fluid.count = fluid.count + 1
                if fluid.still > fluid.worst then
                    fluid.worst, fluid.where = fluid.still, FluidWord(seg, fluid.lastN or 0)
                    local g0, g = fluid.dbg0, state.genDbg
                    fluid.detail = (g0 and g) and string.format("ecrit %.1f->%.1f, voix %.1f->%.1f, mot suivant dans %.2f s",
                        g0.pos or -1, g.pos or -1, g0.target or -1, g.target or -1, g0.next or -1) or nil
                end
            end
        end
        fluid.still, fluid.lastN, fluid.lastI = 0, n, i
        local g = state.genDbg
        fluid.dbg0 = g and { pos = g.pos, target = g.target, next = g.next } or nil
    end
end)

bubble:SetScript("OnMouseUp", function(_, button)
    if button == "LeftButton" and not DWE.JustDragged() then Advance() end
end)
bubble:SetScript("OnDragStart", function() DWE.DragStart("bubble") end)
bubble:SetScript("OnDragStop", function() DWE.DragStop("bubble") end)

--------------------------------------------------------------------------------
-- Interface avec le reste de l'addon
--------------------------------------------------------------------------------

DWE.Bubble = {}

-- Theme Personnalise : applique les couleurs choisies a la bulle affichee.
function DWE.Bubble.RefreshCustom()
    if styleName ~= "custom" then return end
    local bg, bd, tx = DWE.CustomColor("bg"), DWE.CustomColor("border"), DWE.CustomColor("text")
    local op = tonumber(DialogueWheelE_Opacity) or 1
    local a = (DWE.CUSTOM_FILL_ALPHA or 0.86) * op
    fantasy:SetVertexColor(bg[1], bg[2], bg[3], a)
    fantasyTail:SetVertexColor(bg[1], bg[2], bg[3], a)
    customEdge:SetVertexColor(bd[1], bd[2], bd[3], op)
    customTailEdge:SetVertexColor(bd[1], bd[2], bd[3], op)
    -- (bulle decoupee : l'alpha est deja dans la couleur)
    for _, t in pairs(split) do t:SetAlpha(1); t:SetVertexColor(bg[1], bg[2], bg[3], a) end
    for _, t in pairs(splitEdge) do t:SetAlpha(1); t:SetVertexColor(bd[1], bd[2], bd[3], op) end
    fantasyTail:SetAlpha(1); customTailEdge:SetAlpha(1)
    text:SetTextColor(tx[1], tx[2], tx[3])
end

-- Nouveau texte : le PNJ recommence a ecrire (sauf si c'est le meme texte, ex. livre recharge).
-- Option du mot surligne changee : la bulle se redessine a l'image suivante.
function DWE.Bubble.RefreshHighlight()
    if not state.hlStage then state.hlKey = "?" end
    if state.pgKey then state.pgKey = "?" end
end

-- Texte de la bulle si une voix de Spoken l'a deja lu (la bulle l'a suivie), sinon nil.
function DWE.Bubble.VoicedText()
    return state.voiced and state.raw or nil
end

function DWE.Bubble.SetText(s)
    LogFrames("nouveau texte")
    if s == nil then s = "" end
    if not IsSecret(s) and s == state.raw then return end
    state.raw = s
    HighlightReset()
    state.manual, state.clip, state.clipMatch, state.norm = nil, nil, nil, nil
    state.wmap, state.posW, state.timed, state.generated = nil, nil, nil, nil
    state.voiced, state.age, state.holdT, state.waitT = nil, 0, 0, 0
    state.lastTarget, state.tvel, state.spd, state.genStops, state.genWaitAt, state.genNextIn = nil, nil, nil, nil, nil, nil
    state.setAt = GetTime and GetTime() or nil
    state.fluidId = (state.fluidId or 0) + 1
    text:SetAlpha(1)
    if IsSecret(s) then
        -- Valeur protegee par le jeu : impossible a decouper, affichee telle quelle.
        state.segs, state.phase = {}, "idle"
        bubble:DWEWaitHide(false)
        FitTo(s)
        return
    end
    state.segs = Split(s)
    state.lens, state.total = {}, 0
    for i, seg in ipairs(state.segs) do
        state.lens[i] = Utf8Len(seg)
        state.total = state.total + state.lens[i]
    end
    state.norm = Normalize(s)
    state.words = BuildWords(state.segs)
    AddLineBreaks(state.words, s)
    state.wmap, state.posW = BuildMap(state.words, state.total), nil
    -- Pas de texte : "..." affiche d'un coup, centre dans la bulle.
    state.dots = nil
    text:SetJustifyH(#state.segs == 0 and "CENTER" or "LEFT")
    if #state.segs == 0 then
        state.phase = "idle"
        bubble:DWEWaitHide(false)
        FitTo(DWE.L.NO_TEXT)
        if hasGradient then text:SetAlphaGradient(100, 1) end
        text:SetText(DWE.L.NO_TEXT)
    else
        StartSegment(1)
        DWE.PerfTypingStarted()
    end
end

-- Recalcule la taille (apres un changement de largeur, de police ou de style).
function DWE.Bubble.Refit()
    if state.phase == "typing" or state.phase == "reading" then
        local seg = state.segs[state.index]
        if seg then
            FitTo(seg, hasGradient and seg or text:GetText())
            state.shownN = nil
            if state.phase == "typing" then Reveal() end
        end
    elseif state.raw then
        FitTo(IsSecret(state.raw) and state.raw or (state.raw ~= "" and state.raw or DWE.L.NO_TEXT))
    end
end

function DWE.BubbleRecolor()
    CopyLook(measure)
    for _, t in ipairs(tails) do CopyLook(t) end
    for _, fs in ipairs(soft.lines) do CopyLook(fs) end
    for b = 1, 2 * SOFT_BANDS + 2 do CopyLook(SoftClip(b).fs) end
    pcall(function() ghost:SetTextColor(text:GetTextColor()) end)
end
function DWE.BubbleRestyle()
    if styleName then local n = styleName; styleName = nil; pcall(ApplyStyle, n) end
end
-- Theme change dialogue ouvert : tout est redessine au prochain affichage (style, police,
-- couleur du texte, lignes deja ecrites et bord adouci gardes en cache avec l'ancienne couleur).
function DWE.Bubble.Restyle()
    styleName = nil
    bubble.fontKey = nil
    DWE.Bubble.RefreshHighlight()
end
function DWE.Bubble.SetShown(show)
    bubble.dweOff = not show
    if not show then
        bubble:Hide()
        return
    end
    local sk = DWE.BubbleSkin and DWE.BubbleSkin()
    local name = sk and STYLES[sk.bubble] and sk.bubble or "game"
    local changed = styleName ~= name
    ApplyStyle(name)
    -- Police : celle des bulles du jeu pour le style "jeu", celle choisie dans les options
    -- pour le style "fantasy" ; taille de l'option "Taille de police" dans les deux cas.
    -- Meme taille que les choix de la roue (2 points de plus que le texte du popup).
    local size = (tonumber(DialogueWheelE_FontSize) or 13) + 2
    local face = (name == "fantasy" or STYLES[name].optFont) and DWE.FontPath(DWE.ThemeFontId())
        or (ChatBubbleFont and ChatBubbleFont:GetFont()) or STANDARD_TEXT_FONT
    if bubble.fontKey ~= face .. size then
        bubble.fontKey = face .. size
        DWE.SafeSetFont(text, face, size)
        changed = true
    end
    if changed then DWE.Bubble.Refit() end
    if not bubble.pinned then
        if DWE.EnsureTextPlaced then DWE.EnsureTextPlaced() end
        bubble:ClearAllPoints()
        bubble:SetPoint("BOTTOMRIGHT", textBox, "BOTTOMRIGHT", 0, 0)
        DWE.SetGripCorner(bubble, "BOTTOMRIGHT")
    end
    bubble:Show()
end

-- Accroche la bulle au-dessus de la plaque du PNJ (nil = position fixe).
function DWE.Bubble.Pin(plate, x, y)
    bubble:ClearAllPoints()
    if plate then
        bubble:SetPoint("BOTTOM", plate, "CENTER", x or 0, y or 0)
        bubble.pinned = true
        DWE.SetGripCorner(bubble, "BOTTOM")
    else
        bubble.pinned = false
        if DWE.EnsureTextPlaced then DWE.EnsureTextPlaced() end
        bubble:SetPoint("BOTTOMRIGHT", textBox, "BOTTOMRIGHT", 0, 0)
        DWE.SetGripCorner(bubble, "BOTTOMRIGHT")
    end
end

--------------------------------------------------------------------------------
-- Popup des autres themes : apparition progressive, seulement avec Spoken
--------------------------------------------------------------------------------
-- Si Spoken est installe, le texte du popup apparait lettre apres lettre : au rythme de la
-- voix quand Spoken lit ce texte, sinon a vitesse fixe (plus rapide que la bulle : tout le
-- texte est d'un seul bloc). Sans Spoken : texte affiche d'un coup, comme avant.
-- Clic gauche sur le popup : afficher tout le texte.

local POPUP_SPEED = 45
local textBody = DWE.textBody
local popupHasGradient = textBody.SetAlphaGradient ~= nil
local pop = { phase = "idle" }
local popFrame = CreateFrame("Frame")
popFrame:Hide()

local function PopupShowAll()
    pop.phase = "idle"
    popFrame:Hide()
    -- Tout visible, quel que soit le texte affiche (ex. "(Aucun texte disponible)").
    if popupHasGradient then textBody:SetAlphaGradient(100000, 1) end
end

function DWE.Bubble.PopupText(s)
    if s == pop.raw and not IsSecret(s) then return end
    pop.raw = s
    pop.manual, pop.clip, pop.clipMatch = nil, nil, nil
    pop.wmap, pop.posW, pop.timed, pop.generated = nil, nil, nil, nil
    pop.voiced, pop.age, pop.holdT = nil, 0, 0
    pop.lastTarget, pop.tvel, pop.spd, pop.genStops, pop.genWaitAt, pop.genNextIn = nil, nil, nil, nil, nil, nil
    pop.setAt = GetTime and GetTime() or nil
    pop.len = (type(s) == "string" and not IsSecret(s)) and Utf8Len(s) or 0
    if not popupHasGradient or not SpokenInstalled() or IsSecret(s) or pop.len == 0 then
        PopupShowAll()
        return
    end
    pop.norm = Normalize(s)
    pop.words, pop.total = BuildWords({ s }), pop.len
    AddLineBreaks(pop.words, s)
    pop.wmap, pop.posW = BuildMap(pop.words, pop.len), nil
    pop.typed, pop.phase, pop.shownN = 0, "typing", 0
    GradientAt(textBody, 0)
    popFrame:Show()
    DWE.PerfTypingStarted()
end

-- Tout le texte d'un coup (double page d'un livre : l'ecriture progressive ne suit qu'une page).
function DWE.Bubble.PopupInstant()
    pop.phase = nil
    PopupShowAll()
end

popFrame:SetScript("OnUpdate", DWE.Prof("texte progressif", function(_, elapsed)
    if pop.phase ~= "typing" then popFrame:Hide() return end
    pop.age = (pop.age or 0) + elapsed
    local share, length = SpokenShare(pop)
    if share == "hold" then
        pop.holdT = (pop.holdT or 0) + elapsed
        if pop.holdT < HOLD_MAX then return end
        share = nil
    else
        pop.holdT = 0
    end
    if share and length then
        pop.voiced = true
        pop.typed = VoiceStep(pop, pop.typed, share, length, elapsed)
    else
        pop.typed = pop.typed + elapsed * SPOKEN_PACE * StartFactor(pop) -- le popup ne s'ecrit qu'avec Spoken
    end
    if pop.typed >= pop.len then
        PopupShowAll()
    else
        local n = math.floor(pop.typed)
        if n ~= pop.shownN then
            pop.shownN = n
            GradientAt(textBody, n)
        end
    end
end))

textBox:HookScript("OnMouseUp", function(_, button)
    if button == "LeftButton" and pop.phase == "typing" then
        pop.manual = true
        PopupShowAll()
    end
end)

DWE.choiceBox:HookScript("OnHide", function()
    bubble:Hide()
    state.raw, state.phase = nil, "idle"
    pop.raw = nil
    PopupShowAll()
end)

-- Poignee : largeur libre (la hauteur suit le texte).
DWE.MakeResizeGrip(bubble, {
    get = function() return MaxWidth(), 0 end,
    set = function(w)
        DialogueWheelE_BubbleWidth = math.floor(math.max(100, math.min(700, w)))
        DWE.Bubble.Refit()
    end,
})

ApplyStyle("game")

-- La voix vient-elle du PNJ a qui l'on parle ? (pas d'un livre, pas d'un autre PNJ)
function DWE.BubbleVoiceIsNPC(clip)
    local f = DWE.SpokenFocus
    if f and f.IsBook and f.IsBook(clip) then return false end
    local who = f and f.SpeakerOf and f.SpeakerOf(clip)
    local npc = UnitName and UnitName("npc")
    if type(who) ~= "string" or type(npc) ~= "string" then return true end
    if (issecretvalue and (issecretvalue(who) or issecretvalue(npc))) then return true end
    return who == npc
end
