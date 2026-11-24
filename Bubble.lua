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
local TYPE_SPEED = 30          -- vitesse d'ecriture sans voix, en lettres par seconde
-- Sans voix reconnue (meme avec Spoken installe) : meme vitesse que sans Spoken.
local SPOKEN_PACE = TYPE_SPEED
local FADE_LETTERS = 10        -- nombre de lettres en cours d'apparition (fondu)

-- Lettres 1..n nettes, les FADE_LETTERS suivantes en fondu.
local function GradientAt(fs, n, fade)
    fs:SetAlphaGradient(n, fade or FADE_LETTERS)
end
local READ_PER_CHAR, READ_MIN, READ_MAX = 0.05, 2, 8 -- temps de lecture apres ecriture

-- Reglages propres a chaque style de bulle.
local STYLES = {
    game = { pad = 14, color = { 1, 1, 1 }, shadow = false },
    fantasy = { pad = 20, color = { 0.18, 0.10, 0.04 }, shadow = false, art = "BubbleFantasy", slice = 24 },
    whisper = { pad = 14, color = { 1, 0.66, 1 }, shadow = false, art = "BubbleWhisper", slice = 16, split = true },
}
-- Bulles 64x64 dont la pointe (32x32) a ses bords a partir de la 10e ligne : le bas de la bulle
-- est ouvert a l'endroit de la pointe pour que ses bords prolongent le contour (voir SplitArt).
local SPLIT = { Arcane = true, Glass = true, Ink = true, ParchDark = true, Parch = true, Starry = true,
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
STYLES.custom = { pad = 14, color = { 1, 1, 1 }, shadow = true, art = "BubbleCustomFill", slice = 16, optFont = true, custom = true }
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
for _, k in ipairs({ "tl", "t", "tr", "l", "c", "r", "bl", "bL", "m", "bR", "br" }) do
    split[k] = bubble:CreateTexture(nil, "BACKGROUND")
    split[k]:Hide()
end
local function SplitArt(st)
    local S, u = st.slice, st.slice / 64
    local v = 1 - TAIL_TOP / 64
    for _, t in pairs(split) do t:SetTexture(ADDON_PATH .. st.art .. ".png"); t:ClearAllPoints() end
    local p = split
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
    p.m:SetTexCoord(u, 1 - u, 1 - u, v)
    for _, t in pairs(split) do t:Show() end
end
local function HideSplit()
    for _, t in pairs(split) do t:Hide() end
end

local styleName -- style actuellement affiche

local text = holder:CreateFontString(nil, "OVERLAY")
text:SetFontObject(ChatBubbleFont or GameFontHighlight)
text:SetJustifyH("LEFT")
text:SetJustifyV("TOP")
if text.SetWordWrap then text:SetWordWrap(true) end

local function Pad()
    return STYLES[styleName or "game"].pad
end

-- Opacite du fond (option "Opacite du fond") : le fond et la pointe de la bulle, jamais le texte.
function DWE.ApplyBubbleOpacity()
    local op = tonumber(DialogueWheelE_Opacity) or 1
    for _, t in ipairs({ fantasy, fantasyTail, tail, customEdge, customTailEdge }) do t:SetAlpha(op) end
    -- Personnalise : alpha porte par les couleurs (fond 0.86 x opacite).
    if styleName == "custom" and DWE.Bubble and DWE.Bubble.RefreshCustom then DWE.Bubble.RefreshCustom() end
    for _, t in pairs(split) do t:SetAlpha(op) end
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
        fantasyTail:SetTexture(ADDON_PATH .. "BubbleCustomFillTail.png")
        customEdge:Show(); customTailEdge:Show()
    else
        customEdge:Hide(); customTailEdge:Hide()
        local op = tonumber(DialogueWheelE_Opacity) or 1
        fantasy:SetVertexColor(1, 1, 1, op); fantasyTail:SetVertexColor(1, 1, 1, op)
    end
    if DWE.Bubble and DWE.Bubble.RefreshCustom then DWE.Bubble.RefreshCustom() end
    if DWE.ApplyBubbleOpacity then DWE.ApplyBubbleOpacity() end
    text:ClearAllPoints()
    text:SetPoint("TOPLEFT", bubble, "TOPLEFT", st.pad, -st.pad)
    local tc = st.custom and DWE.CustomColor("text") or st.color
    text:SetTextColor(tc[1], tc[2], tc[3])
    text:SetShadowOffset(st.shadow and 1 or 0, st.shadow and -1 or 0)
    bubble.fontKey = nil -- police a reappliquer
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
local function FitTo(s, shown)
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
    bubble:SetSize(w + 2 * pad, h + 2 * pad + 2)
    text:SetText(shown or s)
    -- Le jeu peut ne finir la mise en page qu'a l'image suivante : on revérifie la hauteur.
    if C_Timer and C_Timer.After then
        local function Recheck()
            local ok, real = pcall(text.GetStringHeight, text)
            if ok and type(real) == "number" and real > h + 1 then
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
    local stops = state.voiced and state.wmap and state.wmap.stops
    if not stops then return FADE_LETTERS end
    local at = n
    for k = 1, (state.index or 1) - 1 do at = at + (state.lens[k] or 0) end
    for _, c in ipairs(stops) do
        if c >= at then return math.max(1, math.min(FADE_LETTERS, c - at)) end
    end
    return FADE_LETTERS
end

local function Reveal()
    local seg = state.segs[state.index] or ""
    local n = math.floor(state.typed or 0)

    if n == state.shownN then
        -- Le jeu peut effacer le fondu quand la bulle devient visible : le texte entier se
        -- voyait jusqu'a la lettre suivante. On le remet a chaque image (sans toucher au texte).
        if hasGradient and not state.dots and state.phase == "typing" and n > 0 then GradientAt(text, n, FadeLen(n)) end
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
    if state.dots then
        -- Points de suspension : un point net apres l'autre (pas de fondu), place gardee.
        -- La bulle est taillee pour "..." : texte cale a gauche, les points s'ajoutent un a un.
        if hasGradient then text:SetAlphaGradient(100, 1) end
        text:SetText(Utf8Prefix(seg, n))
    elseif hasGradient then
        GradientAt(text, n, FadeLen(n))
    else
        text:SetText(Utf8Prefix(seg, n))
    end
end

local function StartSegment(i)
    local seg = state.segs[i]
    -- Premiere lettre tout de suite : la bulle apparait avec son texte, sans delai.
    state.index, state.phase, state.typed, state.shownN = i, "typing", (i == 1) and 1 or 0, nil
    state.fresh = (i == 1) or nil
    FitTo(seg, seg)
    Reveal()
end

local function FinishTyping()
    local seg = state.segs[state.index] or ""
    local len = state.lens[state.index] or Utf8Len(seg)
    state.phase, state.readT = "reading", 0
    state.duration = math.max(READ_MIN, math.min(READ_MAX, len * READ_PER_CHAR))
    state.typed = len
    text:SetAlpha(1)
    bubble:DWEWaitHide(false)
    text:SetText(seg)
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
DWE.SYNC_STOP, DWE.SYNC_COMMA, DWE.SYNC_LINE, DWE.SYNC_PARA, DWE.SYNC_PAGE = 7, 3, 10, 20, 17.5
-- En plus, quand un nouveau paragraphe ouvre une nouvelle page (environ 0,2 s).
DWE.SYNC_PARA_PAGE = 4
-- En plus, a la deuxieme page tournee (environ 0,3 s), puis a chacune des suivantes (0,6 s).
DWE.SYNC_PAGE_LATER, DWE.SYNC_PAGE_NEXT = 5.25, 10.5
local SYNC_MARK = { ["."] = "stop", ["!"] = "stop", ["?"] = "stop", ["\226\128\166"] = "stop",
    ["\227\128\130"] = "stop", ["\239\188\129"] = "stop", ["\239\188\159"] = "stop",
    [","] = "comma", [";"] = "comma", [":"] = "comma", ["\239\188\140"] = "comma",
    ["\227\128\129"] = "comma", ["\239\188\155"] = "comma", ["\239\188\154"] = "comma" }
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
    for _, wd in ipairs(words or {}) do
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

-- Avance de l'ecriture sur la voix, en "temps de voix" (pauses comprises) ; rend la lettre.
local VoiceSpeed
local function VoiceStep(st, pos, share, length, dt)
    -- La voix n'est pas encore entendue : la bulle avance tout doucement sur les premieres
    -- lettres (ni figee, ni en avance sur la voix).
    if share <= 0 then return DWE.PreVoiceStep(pos, dt) end
    length = math.max(0.1, length - math.max(0, math.min(length * 0.3, tonumber(DWE.VOICE_LEAD) or 0)))
    local map = st.wmap
    if not map then
        local rate = st.total / length
        return pos + VoiceSpeed(st, pos, share * st.total, rate, dt) * dt
    end
    if not st.posW or math.abs(MapLookup(map.w, map.c, st.posW) - pos) > 1.5 then
        st.posW = MapLookup(map.c, map.w, pos)
    end
    local speed = VoiceSpeed(st, st.posW, share * map.totalW, map.totalW / length, dt)
    st.posW = math.min(map.totalW, st.posW + speed * dt)
    return math.max(pos, MapLookup(map.w, map.c, st.posW))
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
    if st.wmap then return math.max(0, math.min(1, MapLookup(st.wmap.c, st.wmap.w, pos) / st.wmap.totalW)) end
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
    local share = WordShare(st, clip)
    if share then
        local dt = st.offAt and math.max(0, math.min(0.2, now - st.offAt)) or 0
        st.offAt = now
        st.wordOff = (st.wordOff or (share - timeShare)) + ((share - timeShare) - (st.wordOff or 0)) * math.min(1, dt * 1.5)
        return math.max(0, math.min(1, timeShare + st.wordOff)), length
    end
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
            print(("|cff33ff99Storytale|r sync: minutage=%s motSpoken=%s"):format(
                tostring(type(T) == "table" and T.timed), wi))
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
    text:SetTextColor(tx[1], tx[2], tx[3])
end

-- Nouveau texte : le PNJ recommence a ecrire (sauf si c'est le meme texte, ex. livre recharge).
function DWE.Bubble.SetText(s)
    LogFrames("nouveau texte")
    if s == nil then s = "" end
    if not IsSecret(s) and s == state.raw then return end
    state.raw = s
    state.manual, state.clip, state.clipMatch, state.norm = nil, nil, nil, nil
    state.wmap, state.posW = nil, nil
    state.voiced, state.age, state.holdT, state.waitT = nil, 0, 0, 0
    state.lastTarget, state.tvel, state.spd = nil, nil, nil
    state.setAt = GetTime and GetTime() or nil
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
    pop.wmap, pop.posW = nil, nil
    pop.voiced, pop.age, pop.holdT = nil, 0, 0
    pop.lastTarget, pop.tvel, pop.spd = nil, nil, nil
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
