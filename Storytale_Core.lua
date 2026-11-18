-- Storytale - Storytale_Core.lua
-- Affichage : la roue de choix, le popup de texte, les themes, les polices, les boutons de
-- recompense, la compatibilite DialogueUI / Spoken et le panneau d'options.
-- La logique des evenements (PNJ, quetes, livres, touches) est dans Storytale.lua.

local L = DWE.L
local ADDON_PATH = "Interface\\AddOns\\Storytale\\"

--------------------------------------------------------------------------------
-- Mesure de performance (/dwe perf) : temps passe dans chaque partie de l'addon
--------------------------------------------------------------------------------
DWE.perf = { on = false, t = {}, n = {} }
function DWE.Prof(name, fn)
    return function(...)
        local perf = DWE.perf
        if not perf.on or not debugprofilestop then return fn(...) end
        local t0 = debugprofilestop()
        fn(...)
        perf.t[name] = (perf.t[name] or 0) + (debugprofilestop() - t0)
        perf.n[name] = (perf.n[name] or 0) + 1
    end
end

-- Mesure pendant `seconds` secondes, puis affiche les images/s, la pire image (a-coup) et
-- les ms par seconde de chaque partie de l'addon. `baseline` : images/s juste avant.
function DWE.StartPerf(out, seconds, baseline)
    local perf = DWE.perf
    perf.t, perf.n, perf.on = {}, {}, true
    local f = DWE.perfFrame or CreateFrame("Frame")
    DWE.perfFrame = f
    local total, frames, worst, slow = 0, 0, 0, 0
    f:SetScript("OnUpdate", function(_, elapsed)
        total, frames = total + elapsed, frames + 1
        if elapsed > worst then worst = elapsed end
        if elapsed > 0.05 then slow = slow + 1 end
        if total < (seconds or 8) then return end
        f:SetScript("OnUpdate", nil)
        perf.on = false
        local spoken = type(rawget(_G, "Spoken")) == "table"
        out(("Theme : %s | Spoken detecte : %s | bulle affichee : %s"):format(tostring(DialogueWheelE_Theme),
            spoken and "oui" or "non", (DWE.bubble and DWE.bubble:IsShown()) and "oui" or "non"))
        out(("Pendant l'ecriture : %.0f images/s%s | pire image : %.0f ms | images > 50 ms : %d"):format(
            frames / total, baseline and (" (avant : %.0f)"):format(baseline) or "", worst * 1000, slow))
        local names = {}
        for k in pairs(perf.t) do names[#names + 1] = k end
        table.sort(names, function(a, b) return perf.t[a] > perf.t[b] end)
        for _, k in ipairs(names) do
            out(("  %s : %.2f ms/s (%d appels/s)"):format(k, perf.t[k] / total, math.floor(perf.n[k] / total + 0.5)))
        end
    end)
end

-- /dwe perf : on attend le debut d'une ecriture (bulle ou popup) pour mesurer pile pendant
-- qu'elle defile, en notant les images/s des 2 secondes d'avant pour comparer.
function DWE.ArmPerf(out)
    local perf = DWE.perf
    perf.armed, perf.out = true, out
    local f = DWE.perfFrame or CreateFrame("Frame")
    DWE.perfFrame = f
    local hist = {}
    f:SetScript("OnUpdate", function(_, elapsed)
        hist[#hist + 1] = elapsed
        local sum = 0
        for i = #hist, 1, -1 do sum = sum + hist[i] end
        while sum > 2 and #hist > 1 do sum = sum - table.remove(hist, 1) end
        perf.baseline = #hist / math.max(sum, 0.001)
    end)
end

function DWE.PerfTypingStarted()
    local perf = DWE.perf
    if not perf.armed or perf.on then return end
    perf.armed = false
    perf.out("Ecriture detectee : mesure pendant 8 s...")
    DWE.StartPerf(perf.out, 8, perf.baseline)
end

--------------------------------------------------------------------------------
-- Cadres principaux
--------------------------------------------------------------------------------

-- La roue de choix.
local choiceBox = CreateFrame("Frame", "DialogueWheelEChoiceFrame", UIParent)
choiceBox:SetSize(360, 40)
choiceBox:SetFrameStrata("DIALOG")
choiceBox:SetMovable(true)
choiceBox:SetClampedToScreen(true)
choiceBox:EnableMouse(true)
choiceBox:Hide()
DWE.choiceBox = choiceBox

-- Le popup de texte (titre + dialogue). Clic droit maintenu pour le deplacer.
local textBox = CreateFrame("Frame", "DialogueWheelETextFrame", UIParent)
textBox:SetSize(380, 60)
textBox:SetFrameStrata("DIALOG")
textBox:SetMovable(true)
textBox:SetClampedToScreen(true)
textBox:EnableMouse(true)
textBox:RegisterForDrag("LeftButton", "RightButton")
textBox:SetScript("OnDragStart", function() DWE.DragStart("text") end)
textBox:SetScript("OnDragStop", function() DWE.DragStop("text") end)
textBox:Hide()
DWE.textBox = textBox

local questFontObj = QuestFont or GameFontNormal

-- Hauteur d'un texte, sans jamais declencher d'erreur (le jeu peut interdire de mesurer
-- un cadre attache a une plaque de nom).
local function TextHeight(fs, default)
    local ok, h = pcall(fs.GetStringHeight, fs)
    return (ok and type(h) == "number") and h or default
end

-- Largeur d'un texte sur une seule ligne (nil si le jeu refuse la mesure).
local function MeasureWidth(fs)
    local fn = fs.GetUnboundedStringWidth or fs.GetStringWidth
    local ok, w = pcall(fn, fs)
    return (ok and type(w) == "number" and w > 0) and w or nil
end

local function StyleText(fs, r, g, b)
    fs:SetJustifyH("LEFT")
    fs:SetTextColor(r, g, b)
    fs:SetShadowColor(0, 0, 0, 1)
    fs:SetShadowOffset(1, -1)
end

local textHeader = textBox:CreateFontString(nil, "OVERLAY")
textHeader:SetFontObject(GameFontNormalLarge or questFontObj)
textHeader:SetPoint("TOPLEFT", textBox, "TOPLEFT", 0, -2)
textHeader:SetPoint("TOPRIGHT", textBox, "TOPRIGHT", 0, -2)
StyleText(textHeader, 1, 0.85, 0.15)
DWE.textHeader = textHeader

local textBody = textBox:CreateFontString(nil, "OVERLAY")
textBody:SetFontObject(questFontObj)
textBody:SetPoint("TOPLEFT", textHeader, "BOTTOMLEFT", 0, -8)
textBody:SetPoint("TOPRIGHT", textHeader, "BOTTOMRIGHT", 0, -8)
textBody:SetSpacing(5)
StyleText(textBody, 0.95, 0.92, 0.85)
DWE.textBody = textBody

-- Lignes d'apercu de quete sous la roue (objectifs, objets requis, recompenses).
local objLine = choiceBox:CreateFontString(nil, "OVERLAY")
objLine:SetFontObject(questFontObj)
objLine:SetPoint("TOPLEFT", choiceBox, "BOTTOMLEFT", 6, -12)
objLine:SetPoint("TOPRIGHT", choiceBox, "BOTTOMRIGHT", -4, -12)
objLine:SetSpacing(3)
StyleText(objLine, 1, 1, 1)
DWE.objLine = objLine

local reqHeader = choiceBox:CreateFontString(nil, "OVERLAY")
reqHeader:SetFontObject(questFontObj)
StyleText(reqHeader, 1, 0.82, 0)
reqHeader:Hide()
DWE.reqHeader = reqHeader

local rewLine = choiceBox:CreateFontString(nil, "OVERLAY")
rewLine:SetFontObject(questFontObj)
rewLine:SetPoint("TOPLEFT", objLine, "BOTTOMLEFT", 0, -10)
rewLine:SetPoint("TOPRIGHT", objLine, "BOTTOMRIGHT", 0, -10)
rewLine:SetSpacing(3)
StyleText(rewLine, 1, 1, 1)
DWE.rewLine = rewLine

local chooseHeader = choiceBox:CreateFontString(nil, "OVERLAY")
chooseHeader:SetFontObject(questFontObj)
StyleText(chooseHeader, 1, 0.82, 0)
chooseHeader:Hide()
DWE.chooseHeader = chooseHeader

--------------------------------------------------------------------------------
-- Themes du popup
--------------------------------------------------------------------------------

-- Chaque theme : fond uni + bordure (bg/border), ou texture en 3 bandes (haut / milieu
-- etire / bas) decrites par leurs coordonnees verticales dans la texture (bands).
-- cap = hauteur affichee des bandes haut et bas. inset = marges autour du texte.
-- Themes DialogueUI : ils utilisent les images de l'addon DialogueUI installe chez le joueur
-- (lues dans son dossier, jamais copiees dans Storytale) et n'existent que s'il est charge.
DWE.DUI_ART = "Interface\\AddOns\\DialogueUI\\Art\\"
do
    local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    DWE.DUI_ON = loaded and loaded("DialogueUI") and true or false
end
local THEME_STYLES = {
    dark = {
        bg = { 0.05, 0.05, 0.07, 0.82 },
        border = { 0.4, 0.4, 0.45, 0.9 },
        hdr = { 1, 0.85, 0.15 },
        body = { 0.95, 0.92, 0.85 },
        shadow = 1,
    },
    parchment = {
        tex = ADDON_PATH .. "Parchment.png",
        bands = { 0, 96 / 512, 416 / 512, 1 },
        cap = 34,
        inset = { 30, 0, 30, 0 },
        tint = { 1, 1, 1, 1 },
        div = { 0.36, 0.22, 0.09, 0.45 },
        hdr = { 0.24, 0.12, 0.03 },
        body = { 0.13, 0.08, 0.03 },
        shadow = 0,
    },
    -- Themes "enlumines" : une image decoupee en 9 (coins et ornements intacts, bords et
    -- centre etires). slice = marges de decoupe (pixels), pad = espace cadre -> texte.
    -- decor : motif centre derriere le texte (taille suivant le cadre).
    velin = {
        tex = ADDON_PATH .. "ThemeVelin.png", slice = { 44, 44, 44, 44 }, pad = { 30, 26, 30, 26 },
        tint = { 1, 1, 1, 1 }, div = { 0.62, 0.45, 0.15, 0.6 },
        hdr = { 0.43, 0.20, 0.03 }, body = { 0.17, 0.10, 0.04 }, shadow = 0,
    },
    arcane = {
        tex = ADDON_PATH .. "ThemeArcane.png", slice = { 44, 44, 44, 44 }, pad = { 30, 26, 30, 26 },
        decor = { tex = ADDON_PATH .. "ThemeArcaneSigil.png", alpha = 0.16, size = 0.95 },
        tint = { 1, 1, 1, 1 }, div = { 0.35, 0.50, 0.85, 0.55 },
        hdr = { 0.16, 0.24, 0.47 }, body = { 0.16, 0.13, 0.12 }, shadow = 0,
    },
    sylvan = {
        tex = ADDON_PATH .. "ThemeSylvan.png", slice = { 44, 44, 44, 44 }, pad = { 30, 26, 30, 26 },
        tint = { 1, 1, 1, 1 }, div = { 0.35, 0.45, 0.15, 0.55 },
        hdr = { 0.24, 0.31, 0.08 }, body = { 0.16, 0.12, 0.05 }, shadow = 0,
    },
    -- Verre fume : fond sombre translucide, fin filet dore.
    glass = {
        tex = ADDON_PATH .. "ThemeGlass.png", slice = { 14, 14, 14, 14 }, pad = { 14, 11, 14, 11 },
        tint = { 1, 1, 1, 1 }, div = { 0.90, 0.75, 0.45, 0.45 },
        hdr = { 1, 0.84, 0.50 }, body = { 0.94, 0.92, 0.88 }, shadow = 1,
    },
    -- Themes experimentaux.
    -- Halo d'ombre : sans cadre, une ombre douce derriere le texte pour le garder lisible.
    halo = {
        tex = ADDON_PATH .. "ThemeHalo.png", slice = { 48, 48, 48, 48 }, pad = { 40, 30, 40, 30 },
        tint = { 1, 1, 1, 1 }, div = { 1, 0.85, 0.4, 0 },
        hdr = { 1, 0.84, 0.27 }, body = { 0.95, 0.93, 0.89 }, shadow = 1,
    },
    -- Encre et or : ombre legere, filet dore a gauche, police a empattements.
    inkgold = {
        tex = ADDON_PATH .. "ThemeInk.png", slice = { 24, 20, 24, 20 }, pad = { 22, 14, 26, 14 },
        tint = { 1, 1, 1, 1 }, div = { 0.83, 0.67, 0.31, 0.35 },
        hdr = { 1, 0.84, 0.47 }, body = { 0.96, 0.93, 0.84 }, shadow = 1, font = "baskerville",
    },
    -- Cinematique : bandes noires en haut et en bas de l'ecran, replique en sous-titre.
    cinema = {
        none = true, center = true, font = "baskerville",
        hdr = { 0.85, 0.66, 0.32 }, body = { 0.95, 0.91, 0.82 }, shadow = 1,
    },
    -- Page du livre peint (lecteur Spoken et sous-titres pendant un livre).
    bookpaper = {
        tex = ADDON_PATH .. "BookStrip.png", slice = { 28, 28, 28, 28 }, pad = { 26, 22, 26, 22 },
        tint = { 1, 1, 1, 1 }, div = { 0.45, 0.30, 0.12, 0.5 },
        hdr = { 0.40, 0.16, 0.04 }, body = { 0.17, 0.10, 0.04 }, shadow = 0,
    },
    bookpaper_dark = {
        tex = ADDON_PATH .. "BookStrip.png", slice = { 28, 28, 28, 28 }, pad = { 30, 16, 30, 16 },
        tint = { 0.42, 0.34, 0.26, 0.95 }, div = { 0.45, 0.30, 0.12, 0 },
        hdr = { 1, 0.84, 0.47 }, body = { 0.95, 0.92, 0.85 }, shadow = 1,
    },
    starry = {
        tex = ADDON_PATH .. "ThemeStarry.png", slice = { 44, 44, 44, 44 }, pad = { 30, 26, 30, 26 },
        tint = { 1, 1, 1, 1 }, div = { 0.85, 0.68, 0.30, 0.55 },
        hdr = { 1, 0.84, 0.43 }, body = { 0.92, 0.89, 0.84 }, shadow = 1,
    },
    parchment_dark = {
        -- Texture d'origine (moitie droite de themes.tga), reglages d'origine.
        tex = ADDON_PATH .. "themes.tga",
        xcoord = { 0.52, 0.96 },
        bands = { 0.05, 0.21, 0.79, 0.95 },
        cap = 26,
        inset = { 36, -8, 20, -8 },
        tint = { 1, 1, 1, 0.96 },
        div = { 0.70, 0.72, 0.78, 0.35 },
        hdr = { 1, 0.85, 0.15 },
        body = { 0.95, 0.92, 0.85 },
        shadow = 1,
    },
    folio = {
        tex = ADDON_PATH .. "Folio.png",
        bands = { 0, 96 / 512, 416 / 512, 1 }, cap = 34, inset = { 30, 0, 30, 0 },
        tint = { 1, 1, 1, 1 }, div = { 0.42, 0.27, 0.13, 0.5 },
        hdr = { 0.16, 0.10, 0.05 }, body = { 0.16, 0.10, 0.05 }, shadow = 0,
    },
    folio_dark = {
        tex = ADDON_PATH .. "FolioDark.png",
        bands = { 0, 96 / 512, 416 / 512, 1 }, cap = 34, inset = { 30, 0, 30, 0 },
        tint = { 1, 1, 1, 1 }, div = { 0.70, 0.72, 0.78, 0.35 },
        hdr = { 1, 0.82, 0 }, body = { 0.95, 0.92, 0.85 }, shadow = 1,
    },
    dui_brown = {
        tex = DWE.DUI_ART .. "Theme_Brown\\Parchment.png", -- image de DialogueUI installe (non distribuee)
        coord = { 0, 1, 0, 0.53 },
        -- Part transparente de chaque bord de l'image (gauche, haut, droite, bas) : le cadre
        -- est calcule pour laisser `margin` de papier autour du texte, quelle que soit sa taille.
        clear = { 0.129, 0.116, 0.13, 0.053 },
        margin = { 24, 20 },
        tint = { 1, 1, 1, 0.98 },
        div = { 0.35, 0.22, 0.10, 0.45 },
        hdr = { 0.16, 0.08, 0.02 },
        body = { 0.10, 0.05, 0.02 },
        shadow = 0,
    },
    dui_dark = {
        tex = DWE.DUI_ART .. "Theme_Dark\\Parchment.png",
        coord = { 0, 1, 0, 0.53 },
        -- Part transparente de chaque bord de l'image (gauche, haut, droite, bas) : le cadre
        -- est calcule pour laisser `margin` de papier autour du texte, quelle que soit sa taille.
        clear = { 0.129, 0.116, 0.13, 0.053 },
        margin = { 24, 20 },
        tint = { 1, 1, 1, 0.96 },
        div = { 0.70, 0.72, 0.78, 0.35 },
        hdr = { 1, 0.85, 0.15 },
        body = { 0.95, 0.92, 0.85 },
        shadow = 1,
    },
}
DWE.THEME_STYLES = THEME_STYLES

-- Themes qui conviennent a un livre ; les autres (bulles, sans cadre, voile) sont remplaces
-- par le Velin dore pendant la lecture d'un livre.
local BOOK_THEMES = {
    velin = true, arcane = true, sylvan = true, starry = true,
    parchment = true, parchment_dark = true, folio = true, folio_dark = true, dui_brown = true, dui_dark = true, glass = true,
}

local function CurrentTheme()
    if DialogueWheelE_Theme == "scroll" then DialogueWheelE_Theme = "parchment" end -- theme retire
    local t = DialogueWheelE_Theme or "bubble"
    if (t == "dui_brown" or t == "dui_dark") and not DWE.DUI_ON then t = "bubble" end
    if DWE.bookMode and not BOOK_THEMES[t] then return "velin" end
    return t
end

-- Lecture d'un livre ou non : change le theme affiche si besoin.
function DWE.SetBookMode(on)
    on = on and true or false
    if DWE.bookMode == on then return end
    local function Look() return CurrentTheme() .. tostring(DWE.BubbleSkin and DWE.BubbleSkin() ~= nil) end
    local before = Look()
    DWE.bookMode = on
    if Look() ~= before and DWE.OnThemeChanged then DWE.OnThemeChanged() end
    if DWE.RefreshSpoken then DWE.RefreshSpoken() end
end

--------------------------------------------------------------------------------
-- Couleurs de la roue et de l'apercu de quete
--------------------------------------------------------------------------------
-- WHEEL_DEFAULT = les couleurs habituelles (texte clair). WHEEL_INK = encre foncee, utilisee
-- seulement si l'option "theme sur la roue" est cochee avec un parchemin clair.

local WHEEL_DEFAULT = {
    normal = { 0.95, 0.92, 0.85 }, selected = { 1, 0.88, 0.15 }, disabled = { 0.5, 0.5, 0.5 },
    goodbye = { 0.67, 0.67, 0.67 }, goodbyeSel = { 1, 0.3, 0.3 }, dim = { 0.75, 0.72, 0.65 },
    common = nil, shadow = 1,
    hex = { hdr = "|cffffd700", body = "|cfff2ebda", num = "|cffffffff", rep = "|cff80ff80", ok = "|cff40ff40", bad = "|cffff5555" },
}
local WHEEL_INK = {
    normal = { 0.16, 0.09, 0.03 }, selected = { 0.55, 0.20, 0.0 }, disabled = { 0.42, 0.36, 0.30 },
    goodbye = { 0.36, 0.27, 0.19 }, goodbyeSel = { 0.62, 0.08, 0.05 }, dim = { 0.34, 0.27, 0.19 },
    common = { 0.16, 0.09, 0.03 }, qualityDim = 0.55, shadow = 0,
    hex = { hdr = "|cff5c3300", body = "|cff2b1a0b", num = "|cff2b1a0b", rep = "|cff7a5214", ok = "|cff8a4b14", bad = "|cff9e1b1b" },
}
-- Murmure : couleurs des chuchotements du jeu (rose / violet).
local WHEEL_WHISPER = {
    normal = { 0.96, 0.88, 0.98 }, selected = { 1, 0.62, 1 }, disabled = { 0.55, 0.48, 0.58 },
    goodbye = { 0.75, 0.66, 0.78 }, goodbyeSel = { 1, 0.45, 0.6 }, dim = { 0.82, 0.74, 0.86 },
    common = nil, shadow = 1,
    hex = { hdr = "|cffff9cff", body = "|cfff5e6f8", num = "|cffffffff", rep = "|cffc0a0ff", ok = "|cffb0ff9c", bad = "|cffff6080" },
}
-- Verre fume, Encre et or : palette par defaut, mais surbrillance or pale (couleur du nom du PNJ).
DWE.HDR_PALETTE = {
    glass = setmetatable({ selected = { 1, 0.84, 0.50 } }, { __index = WHEEL_DEFAULT }),
    inkgold = setmetatable({ selected = { 1, 0.84, 0.47 } }, { __index = WHEEL_DEFAULT }),
}
local LIGHT_BACKGROUND = { parchment = true, folio = true, dui_brown = true, velin = true, arcane = true, sylvan = true }

-- Themes en bulle : la replique du PNJ dans une bulle au-dessus de lui et, avec l'option
-- "habiller la roue", chaque choix dans sa petite bulle. Les trois bulles d'origine le sont
-- toujours ; les autres themes (sauf Sans cadre et Cinematique) aussi, sauf si l'option
-- "Afficher les themes en cadre" est cochee.
-- bubble = style de Bubble.lua, pill = images Pill<pill>*.png, palette = couleurs des choix.
local BUBBLE_SKINS = {
    bubble = { bubble = "game", pill = "game", palette = WHEEL_DEFAULT, always = true },
    bubble_fantasy = { bubble = "fantasy", pill = "fantasy", palette = WHEEL_INK, always = true, optFont = true },
    whisper = { bubble = "whisper", pill = "whisper", palette = WHEEL_WHISPER, always = true },
}
local BUBBLE_ART = {
    dark = "Veil", glass = "Glass", halo = "Halo", inkgold = "Ink", velin = "Velin", arcane = "Arcane",
    sylvan = "Sylvan", starry = "Starry", parchment = "Parch", parchment_dark = "ParchDark",
    dui_brown = "Folio", dui_dark = "FolioDark", folio = "Folio", folio_dark = "FolioDark",
}
for id, art in pairs(BUBBLE_ART) do
    BUBBLE_SKINS[id] = { bubble = id, pill = art, art = art, optFont = true,
        palette = LIGHT_BACKGROUND[id] and WHEEL_INK or DWE.HDR_PALETTE[id] or WHEEL_DEFAULT }
end
DWE.BUBBLE_SKINS = BUBBLE_SKINS

-- Le theme `id` s'affiche-t-il en bulle ? (sans tenir compte d'un livre ouvert)
function DWE.ThemeIsBubble(id)
    local sk = BUBBLE_SKINS[id]
    return sk ~= nil and (sk.always or DialogueWheelE_ThemeFrames ~= true)
end

-- Habillage bulle en cours (nil = pas de bulle : theme en cadre, Sans cadre ou livre ouvert).
function DWE.BubbleSkin()
    if DWE.bookMode then return nil end
    local t = CurrentTheme()
    return DWE.ThemeIsBubble(t) and BUBBLE_SKINS[t] or nil
end

-- Style des bulles de choix (nil = pas de bulles : option decochee ou theme non-bulle).
function DWE.WheelPillStyle()
    if DialogueWheelE_WheelTheme ~= true then return nil end
    local sk = DWE.BubbleSkin()
    return sk and sk.pill or nil
end

-- Theme "bloc" dessine derriere la roue (nil = aucun : option decochee, Transparent ou bulle).
function DWE.WheelThemeId()
    if DialogueWheelE_WheelTheme ~= true then return nil end
    if DWE.BubbleSkin() then return nil end
    local t = CurrentTheme()
    return THEME_STYLES[t] and t or nil
end

function DWE.WheelPalette()
    local pill = DWE.WheelPillStyle()
    if pill then return DWE.BubbleSkin().palette end
    local id = DWE.WheelThemeId()
    if id and DWE.HDR_PALETTE[id] then return DWE.HDR_PALETTE[id] end
    return (id and LIGHT_BACKGROUND[id]) and WHEEL_INK or WHEEL_DEFAULT
end

-- Fabrique les morceaux d'un fond de theme sur `owner`. Partage par le popup et Spoken.
local function CreateThemeParts(owner, level)
    local parts = {
        bg = owner:CreateTexture(nil, "BACKGROUND", nil, -6),
        top = owner:CreateTexture(nil, "BACKGROUND", nil, -6),
        bot = owner:CreateTexture(nil, "BACKGROUND", nil, -6),
        div = owner:CreateTexture(nil, "BORDER"),
        border = CreateFrame("Frame", nil, owner, "BackdropTemplate"),
        slice = owner:CreateTexture(nil, "BACKGROUND", nil, -6),
        decor = owner:CreateTexture(nil, "BACKGROUND", nil, -5),
    }
    parts.border:SetFrameLevel(level or owner:GetFrameLevel())
    parts.border:EnableMouse(false)
    parts.list = { parts.bg, parts.top, parts.bot, parts.div, parts.border, parts.slice, parts.decor }
    return parts
end

-- Dessine le theme `id` autour de `content`. `divAnchor` : region sous laquelle placer le
-- trait de titre. Renvoie la config du theme (nil pour Transparent).
local PaintThemeParts

-- Les themes dont le dessin depend de la taille du cadre (marges calculees, motif centre)
-- sont redessines quand le texte change la taille du cadre.
local function WatchSize(parts, content)
    if parts.sizeHooked then return end
    parts.sizeHooked = true
    content:HookScript("OnSizeChanged", function()
        local cfg = parts.lastId and THEME_STYLES[parts.lastId]
        if cfg and (cfg.clear or cfg.decor) then
            PaintThemeParts(parts, content, parts.lastDiv, parts.lastId)
        end
    end)
end

-- Efface un fond de theme. Oublie aussi le theme : sinon un changement de taille du cadre
-- (WatchSize) redessinerait l'ancien theme, et deux themes se retrouveraient melanges.
local function ClearThemeParts(parts)
    parts.lastId, parts.lastDiv = nil, nil
    for _, r in ipairs(parts.list) do r:Hide() end
end

function PaintThemeParts(parts, content, divAnchor, id)
    parts.lastId, parts.lastDiv = id, divAnchor
    for _, r in ipairs(parts.list) do r:Hide() end
    local cfg = THEME_STYLES[id]
    if not cfg then return nil end
    if cfg.none then return cfg end
    local op = tonumber(DialogueWheelE_Opacity) or 1
    local bg, top, bot, div = parts.bg, parts.top, parts.bot, parts.div

    if cfg.bg then
        bg:ClearAllPoints()
        bg:SetPoint("TOPLEFT", content, "TOPLEFT", -11, 11)
        bg:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 11, -11)
        bg:SetColorTexture(cfg.bg[1], cfg.bg[2], cfg.bg[3], cfg.bg[4] * op)
        bg:SetTexCoord(0, 1, 0, 1)
        bg:SetVertexColor(1, 1, 1, 1)
        bg:Show()
        local border = parts.border
        border:ClearAllPoints()
        border:SetPoint("TOPLEFT", content, "TOPLEFT", -14, 14)
        border:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 14, -14)
        border:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14 })
        border:SetBackdropBorderColor(unpack(cfg.border))
        border:Show()
        return cfg
    end

    local r, g, b, a = cfg.tint[1], cfg.tint[2], cfg.tint[3], cfg.tint[4] * op
    if cfg.slice then
        local sl = parts.slice
        local pl, pt, pr, pb = unpack(cfg.pad)
        sl:ClearAllPoints()
        sl:SetPoint("TOPLEFT", content, "TOPLEFT", -pl, pt)
        sl:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", pr, -pb)
        sl:SetTexture(cfg.tex)
        sl:SetTexCoord(0, 1, 0, 1)
        if sl.SetTextureSliceMargins then
            pcall(sl.SetTextureSliceMargins, sl, unpack(cfg.slice))
            if sl.SetTextureSliceMode then pcall(sl.SetTextureSliceMode, sl, 0) end
        end
        sl:SetVertexColor(r, g, b, a)
        sl:Show()
        if cfg.decor then
            local okW, cw = pcall(content.GetWidth, content)
            local okH, ch = pcall(content.GetHeight, content)
            cw = (okW and type(cw) == "number") and cw or 200
            ch = (okH and type(ch) == "number") and ch or 80
            local size = math.min(cw + pl + pr, ch + pt + pb) * cfg.decor.size
            local dc = parts.decor
            dc:ClearAllPoints()
            dc:SetPoint("CENTER", content, "CENTER", 0, 0)
            dc:SetSize(size, size)
            dc:SetTexture(cfg.decor.tex)
            dc:SetVertexColor(1, 1, 1, cfg.decor.alpha * op)
            dc:Show()
        end
        WatchSize(parts, content)
        if divAnchor then
            div:ClearAllPoints()
            div:SetHeight(1)
            div:SetPoint("LEFT", content, "LEFT", 0, 0)
            div:SetPoint("RIGHT", content, "RIGHT", 0, 0)
            div:SetPoint("TOP", divAnchor, "BOTTOM", 0, -4)
            div:SetColorTexture(unpack(cfg.div))
            div:Show()
        end
        return cfg
    end
    bg:ClearAllPoints()
    bg:SetTexture(cfg.tex)
    bg:SetVertexColor(r, g, b, a)
    if cfg.bands then
        local y0, y1, y2, y3 = unpack(cfg.bands)
        local x1, x2 = unpack(cfg.xcoord or { 0, 1 })
        local il, it, ir, ib = unpack(cfg.inset)
        bg:SetPoint("TOPLEFT", content, "TOPLEFT", -il, it)
        bg:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", ir, -ib)
        bg:SetTexCoord(x1, x2, y1, y2)
        top:ClearAllPoints()
        top:SetHeight(cfg.cap)
        top:SetPoint("BOTTOMLEFT", bg, "TOPLEFT", 0, 0)
        top:SetPoint("BOTTOMRIGHT", bg, "TOPRIGHT", 0, 0)
        top:SetTexture(cfg.tex)
        top:SetTexCoord(x1, x2, y0, y1)
        top:SetVertexColor(r, g, b, a)
        bot:ClearAllPoints()
        bot:SetHeight(cfg.cap)
        bot:SetPoint("TOPLEFT", bg, "BOTTOMLEFT", 0, 0)
        bot:SetPoint("TOPRIGHT", bg, "BOTTOMRIGHT", 0, 0)
        bot:SetTexture(cfg.tex)
        bot:SetTexCoord(x1, x2, y2, y3)
        bot:SetVertexColor(r, g, b, a)
        top:Show()
        bot:Show()
    else
        local cl, ct, cr, cb = unpack(cfg.clear)
        local mx, my = cfg.margin[1], cfg.margin[2]
        local okW, cw = pcall(content.GetWidth, content)
        local okH, ch = pcall(content.GetHeight, content)
        cw = (okW and type(cw) == "number") and cw or 300
        ch = (okH and type(ch) == "number") and ch or 100
        -- largeur totale W : W = cw + 2*mx + (cl+cr)*W ; idem en hauteur.
        local W = (cw + 2 * mx) / (1 - cl - cr)
        local H = (ch + 2 * my) / (1 - ct - cb)
        bg:SetPoint("TOPLEFT", content, "TOPLEFT", -(mx + cl * W), my + ct * H)
        bg:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", mx + cr * W, -(my + cb * H))
        bg:SetTexCoord(unpack(cfg.coord))
        WatchSize(parts, content)
    end
    bg:Show()

    if divAnchor then
        div:ClearAllPoints()
        div:SetHeight(1)
        div:SetPoint("LEFT", content, "LEFT", 0, 0)
        div:SetPoint("RIGHT", content, "RIGHT", 0, 0)
        div:SetPoint("TOP", divAnchor, "BOTTOM", 0, -4)
        div:SetColorTexture(unpack(cfg.div))
        div:Show()
    end
    return cfg
end

local textParts = CreateThemeParts(textBox)

local function ApplyBodyColor()
    if DWE.hasDialogueText then
        local cfg = THEME_STYLES[CurrentTheme()]
        textBody:SetTextColor(unpack(cfg and cfg.body or { 0.95, 0.92, 0.85 }))
    else
        textBody:SetTextColor(0.6, 0.6, 0.6)
    end
end

function DWE.IsCinema()
    return CurrentTheme() == "cinema"
end

-- Police a utiliser : celle du theme (Encre et or, Cinematique) tant que le joueur garde la
-- police par defaut ; sinon celle qu'il a choisie.
function DWE.ThemeFontId()
    local u = DialogueWheelE_Font
    if u == nil or u == "friz" then
        local cfg = THEME_STYLES[CurrentTheme()]
        if cfg and cfg.font then return cfg.font end
    end
    return u or "friz"
end

function DWE.ApplyTextTheme()
    local cfg = PaintThemeParts(textParts, textBox, textHeader, CurrentTheme())
    if not textBox.dweBook then
        local pad = cfg and (cfg.pad or (cfg.bg and { 11, 11, 11, 11 }) or (cfg.inset and { 0, 0, cfg.inset[3], (cfg.cap or 0) }))
        textBox.dweGripX = pad and math.max(0, pad[3]) or 0
        textBox.dweGripY = pad and math.max(0, pad[4]) or 0
        textBox.dweGripAnchor, textBox.dweNoGrip = nil, nil
        if DWE.SetGripCorner then DWE.SetGripCorner(textBox, "BOTTOMRIGHT") end
    end
    local just = (cfg and cfg.center) and "CENTER" or "LEFT"
    textHeader:SetJustifyH(just)
    textBody:SetJustifyH(just)
    local shadow = cfg and cfg.shadow or 1
    textHeader:SetTextColor(unpack(cfg and cfg.hdr or { 1, 0.85, 0.15 }))
    textHeader:SetShadowColor(0, 0, 0, 1)
    textHeader:SetShadowOffset(shadow, -shadow)
    textBody:SetShadowOffset(shadow, -shadow)
    ApplyBodyColor()
end

--------------------------------------------------------------------------------
-- Polices
--------------------------------------------------------------------------------

-- cyr = la police contient l'alphabet cyrillique (client russe).
-- Les clients coreen et chinois gardent toujours la police du jeu.
local FONTS = {
    { id = "friz", name = "Friz Quadrata", path = STANDARD_TEXT_FONT, cyr = true, default = true },
    { id = "morpheus", name = "Morpheus", path = "Fonts\\MORPHEUS.TTF", cyrPath = "Fonts\\MORPHEUS_CYR.TTF" },
    { id = "skurri", name = "Skurri", path = "Fonts\\SKURRI.TTF", cyrPath = "Fonts\\SKURRI_CYR.TTF" },
    { id = "arial", name = "Arial Narrow", path = "Fonts\\ARIALN.TTF", cyr = true },
    { id = "crimson", name = "Crimson Pro", path = ADDON_PATH .. "Fonts\\CrimsonPro-Regular.ttf" },
    { id = "baskerville", name = "Libre Baskerville", path = ADDON_PATH .. "Fonts\\LibreBaskerville-Regular.ttf" },
    { id = "lora", name = "Lora", path = ADDON_PATH .. "Fonts\\Lora-Regular.ttf", cyr = true },
    { id = "youngserif", name = "Young Serif", path = ADDON_PATH .. "Fonts\\YoungSerif-Regular.ttf" },
    { id = "plexserif", name = "IBM Plex Serif", path = ADDON_PATH .. "Fonts\\IBMPlexSerif-Regular.ttf", cyr = true },
    { id = "handwriting", name = "Nothing You Could Do", path = ADDON_PATH .. "Fonts\\NothingYouCouldDo-Regular.ttf" },
}
DWE.FONTS = FONTS

-- Chemin utilisable pour cette police dans la langue du client.
local function FontPath(id)
    if DWE.IS_CJK then return STANDARD_TEXT_FONT end
    for _, f in ipairs(FONTS) do
        if f.id == id then
            if DWE.IS_CYRILLIC then
                if f.cyrPath then return f.cyrPath end
                if not f.cyr then return STANDARD_TEXT_FONT end
            end
            return f.path
        end
    end
    return STANDARD_TEXT_FONT
end
DWE.FontPath = FontPath

-- SetFont avec repli sur la police du jeu si le fichier est introuvable.
local function SafeSetFont(fs, path, size, flags)
    fs:SetFont(path, size, flags or "")
    if not fs:GetFont() then fs:SetFont(STANDARD_TEXT_FONT, size, flags or "") end
end
DWE.SafeSetFont = SafeSetFont

function DWE.ApplyFont()
    local path = FontPath(DWE.ThemeFontId())
    local sz = tonumber(DialogueWheelE_FontSize) or 13
    SafeSetFont(textHeader, path, sz + 3)
    SafeSetFont(textBody, path, sz)
    if textBox:IsShown() then DWE.UpdateTextPanelVisuals() end
end

-- Les cadres ne sont plus zoomes : leur taille se regle avec les poignees, la police avec
-- l'option "Taille de police". (Les anciennes echelles sauvegardees sont ignorees.)
function DWE.ApplyScale()
    textBox:SetScale(1)
    choiceBox:SetScale(1)
    if DWE.bubble then DWE.bubble:SetScale(1) end
    if DWE.Repin then DWE.Repin() end
end

--------------------------------------------------------------------------------
-- Masquage de DialogueUI / Spoken / fenetres Blizzard pendant le popup
--------------------------------------------------------------------------------
-- Les fenetres ne sont jamais fermees : on les rend invisibles (alpha 0) et on les
-- rend visibles a nouveau quand le popup se ferme ou que l'on reclique sur "Dialogue".
--  * fenetres Blizzard (GossipFrame, QuestFrame, ItemTextFrame) : invisibles tant que la
--    roue est affichee ;
--  * fenetres DialogueUI / Spoken (noms commencant par "DUI" ou "Spoken") : invisibles tant
--    que la roue est affichee ET que le popup perso est actif.

local hookedFrames = {}
local fadeHold = false -- garde le masquage pendant l'animation de fermeture de Spoken

local function IsSafeFrame(frame)
    if type(frame) ~= "table" then return false end
    if frame.IsForbidden and frame:IsForbidden() then return false end
    return frame.SetAlpha ~= nil and frame.GetAlpha ~= nil
end

-- Faut-il masquer ? alwaysWithWheel = vrai pour les fenetres Blizzard.
-- Livre affiche par l'addon : le texte est montre sauf si le joueur passe a la vue "Spoken".
function DWE.BookByAddon()
    return DWE.bookMode and DWE.BookStyleNow() == "addon"
end
function DWE.TextWanted()
    if DWE.BookByAddon() then return not DWE.bookSpokenView end
    return DialogueWheelE_ShowText == true
end

local function ShouldHide(alwaysWithWheel, frame)
    if not (choiceBox:IsShown() or fadeHold) then return false end
    if alwaysWithWheel then return true end
    if DWE.BookByAddon() then
        -- Le livre de DialogueUI ne se montre jamais pendant un livre de l'addon.
        local ok, name = pcall(frame and frame.GetName or function() end, frame)
        if ok and type(name) == "string" and name:find("^DUI") then return true end
    end
    return DWE.TextWanted()
end

local function ApplyAlpha(frame, alwaysWithWheel)
    if not IsSafeFrame(frame) then return end
    local a = ShouldHide(alwaysWithWheel, frame) and 0 or 1
    if frame:GetAlpha() ~= a then frame:SetAlpha(a) end
end

-- Surveille une fenetre : si son addon remet son alpha au-dessus de 0 alors qu'elle doit
-- etre cachee, on la recache aussitot.
local function WatchFrame(frame, alwaysWithWheel)
    if not IsSafeFrame(frame) or hookedFrames[frame] then return end
    hookedFrames[frame] = true
    hooksecurefunc(frame, "SetAlpha", DWE.Prof("masquage DialogueUI/Spoken", function(s, a)
        if a > 0 and ShouldHide(alwaysWithWheel, s) then s:SetAlpha(0) end
    end))
    if frame.HookScript then
        frame:HookScript("OnShow", function(s) ApplyAlpha(s, alwaysWithWheel) end)
    end
end

local BLIZZ_FRAMES = { "GossipFrame", "QuestFrame", "ItemTextFrame" }
local addonFrames = {}
local scanned = {}

-- Cherche les fenetres nommees de DialogueUI et Spoken. Relance a chaque ouverture de la
-- roue car Spoken cree certaines fenetres plus tard (a la premiere replique).
-- Parcourir _G coute cher avec beaucoup d'addons : on ne lit que la premiere lettre (sans creer
-- de texte), et apres le premier passage on ne repasse qu'en differe, au plus toutes les 30 s.
local BYTE_D, BYTE_S = string.byte("D"), string.byte("S")
local lastScan

local function ScanNow()
    lastScan = GetTime and GetTime() or 0
    for k, v in next, _G do
        local b = type(k) == "string" and k:byte(1)
        if (b == BYTE_D or b == BYTE_S) and not scanned[k] and type(v) == "table" then
            local prefix = k:find("^DUI") or k:find("^Spoken")
            if prefix and k ~= "DUIQuestFrame" and IsSafeFrame(v) then
                scanned[k] = true
                addonFrames[#addonFrames + 1] = v
                WatchFrame(v, false)
            end
        end
    end
end

-- Fenetres creees apres le premier passage (DialogueUI et Spoken en creent en cours de jeu) :
-- surveillees des leur creation, sans reparcourir _G.
local function WatchNew(name)
    if not lastScan or type(name) ~= "string" or scanned[name] then return end
    if not (name:find("^DUI") or name:find("^Spoken")) or name == "DUIQuestFrame" then return end
    local v = rawget(_G, name)
    if IsSafeFrame(v) then
        scanned[name] = true
        addonFrames[#addonFrames + 1] = v
        WatchFrame(v, false)
        ApplyAlpha(v, false)
    end
end
if hooksecurefunc and CreateFrame then
    hooksecurefunc("CreateFrame", function(_, name, parent)
        if type(name) == "string" and name:find("$parent", 1, true) then
            local ok, pname = pcall(function() return parent and parent:GetName() end)
            if not (ok and type(pname) == "string") then return end
            name = name:gsub("%$parent", pname)
        end
        WatchNew(name)
    end)
end

local function ScanAddonFrames()
    if not lastScan then ScanNow() return end
    local now = GetTime and GetTime() or 0
    if now - lastScan < 30 or not (C_Timer and C_Timer.After) then return end
    lastScan = now
    C_Timer.After(1, function()
        ScanNow()
        for i = 1, #addonFrames do ApplyAlpha(addonFrames[i], false) end
    end)
end
DWE.ScanAddonFrames = ScanAddonFrames

local function RefreshHiddenFrames()
    DWE.HookSpoken()
    for _, name in ipairs(BLIZZ_FRAMES) do
        local frm = _G[name]
        if IsSafeFrame(frm) then
            WatchFrame(frm, true)
            ApplyAlpha(frm, true)
            frm:EnableMouse(not choiceBox:IsShown())
        end
    end
    for i = 1, #addonFrames do ApplyAlpha(addonFrames[i], false) end
end

--------------------------------------------------------------------------------
-- Compatibilite Spoken (mode DialogueUI)
--------------------------------------------------------------------------------
-- Tout se passe en memoire : rien n'est ecrit dans les reglages sauvegardes de Spoken.
-- Fichiers de Spoken concernes : UI/DialogueUIPlayer.lua (le lecteur, "Skin"),
-- UI/DialogueUITransitions.lua (animations), UI/DialogueUITheme.lua (theme).

local function SpokenSkin()
    local env = rawget(_G, "SpokenEnv")
    local skin = type(env) == "table" and rawget(env, "DialogueUIPlayer")
    return type(skin) == "table" and skin or nil, env
end

-- Couleur du texte Spoken pour chaque theme de DWE : 2 = texte clair, 1 = texte fonce.
local SPOKEN_PALETTE_OF = {
    transparent = 2, dark = 2, parchment_dark = 2, dui_dark = 2, folio_dark = 2, bubble = 2, bubble_fantasy = 1,
    whisper = 2, glass = 2, halo = 2, inkgold = 2, cinema = 2,
    parchment = 1, dui_brown = 1, folio = 1, velin = 1, arcane = 1, sylvan = 1, starry = 2,
}

-- Ligne de livre (Spoken Readables) alors que les livres sont laisses a DialogueUI ou au jeu :
-- le lecteur Spoken garde son propre habillage (celui de DialogueUI), comme le livre.
local spokenSkinRef
local function SpokenBookLeftAlone()
    -- Seul le livre DialogueUI garde l'habillage DialogueUI ; fenetre du jeu = theme Storytale.
    local style = (DWE.bookMode and DWE.BookStyleNow()) or DWE.lastBookStyle or DWE.BookStyleNow()
    if style ~= "dui" then return false end
    local duiBook = rawget(_G, "DUIBookFrame")
    if type(duiBook) == "table" and duiBook.IsShown and duiBook:IsShown() then return true end
    local clip = spokenSkinRef and spokenSkinRef.clip
    local present = type(clip) == "table" and clip.present
    return type(present) == "table" and (present.material ~= nil or present.bullet == "book")
end

-- File de lecture : chaque ligne de livre garde l'habillage qu'elle avait, livre ouvert, pour
-- le retrouver quand on la relance plus tard (livre ferme).
function DWE.BookOpenNow()
    if DWE.bookMode then return true end
    for _, n in ipairs({ "DUIBookFrame", "ItemTextFrame" }) do
        local f = rawget(_G, n)
        if type(f) == "table" and f.IsShown and f:IsShown() then return true end
    end
    return false
end
function DWE.SpokenStamp()
    local clip = spokenSkinRef and spokenSkinRef.clip
    if type(clip) ~= "table" or not clip.dweStamp or DWE.BookOpenNow() then return nil end
    return clip.dweStamp
end
function DWE.SpokenThemeOverride()
    local st = DWE.SpokenStamp()
    if st then return st.override end
    -- Livre affiche par l'addon : le petit lecteur Spoken prend toujours le theme du livre.
    if DWE.BookByAddon() then return 1 end
    if DialogueWheelE_SpokenTheme ~= true then return nil end
    if SpokenBookLeftAlone() then return nil end
    return SPOKEN_PALETTE_OF[CurrentTheme()] or 2
end

-- Pour la fenetre Spoken, les bulles empruntent le style d'un theme "bloc".
local SPOKEN_STYLE_ALIAS = { bubble = "dark", bubble_fantasy = "parchment", whisper = "glass", cinema = "transparent" }
local function SpokenStyle()
    local st = DWE.SpokenStamp()
    if st then return st.style end
    if DWE.BookByAddon() then
        -- Plaque : sa propre matiere, en petite taille (texture S a moitie, marges divisees par 2).
        local mat = DWE.BookLook() == "note" and DWE.PlateMaterial()
        local pl = mat and DWE.PLATES[mat]
        if not pl then return "bookpaper" end
        local id = "plate_" .. mat
        if not THEME_STYLES[id] then
            local sl = pl.slice
            local h = { math.floor(sl[1] / 2), math.floor(sl[2] / 2), math.floor(sl[3] / 2), math.floor(sl[4] / 2) }
            THEME_STYLES[id] = {
                tex = ADDON_PATH .. pl.tex .. "S.png", slice = h,
                pad = { h[1] + 14, h[2] + 10, h[3] + 14, h[4] + 10 },
                tint = { 1, 1, 1, 1 }, div = pl.rule, hdr = pl.hdr, body = pl.body, shadow = 0,
            }
        end
        return id
    end
    local t = CurrentTheme()
    return SPOKEN_STYLE_ALIAS[t] or t
end

local function SpokenTextShadow()
    local cfg = THEME_STYLES[SpokenStyle()]
    return (not cfg) or cfg.shadow == 1
end

-- Les cadres SANS NOM que Spoken cree a la demande pendant ses animations : son ombre
-- (skin.shadow, le "cadre noir"), la page qui se range derriere (skin.card) et le compteur
-- (skin.ripple). Le scan par nom ne peut pas les trouver : on les attrape a leur creation.
local function GuardSpokenFrame(frm)
    if not IsSafeFrame(frm) or hookedFrames[frm] then return end
    hookedFrames[frm] = true
    hooksecurefunc(frm, "SetAlpha", function(s, a)
        if a > 0 and ShouldHide(false) then s:SetAlpha(0) end
    end)
    if ShouldHide(false) then frm:SetAlpha(0) end
end

-- Le fond du theme DWE sous le lecteur Spoken (option "Adapter la fenetre Spoken au theme").
local function PaintSpoken(skin)
    local frame, content, head = skin.frame, skin.content, skin.head
    if not (frame and content and head) then return end
    -- Ligne de livre, livre ouvert : on retient son habillage pour plus tard.
    local clip = skin.clip
    local present = type(clip) == "table" and clip.present
    if type(present) == "table" and (present.material ~= nil or present.bullet == "book")
        and not clip.dweStamp and DWE.BookOpenNow() then
        local override = DWE.SpokenThemeOverride()
        clip.dweStamp = {
            override = override, style = SpokenStyle(), left = SpokenBookLeftAlone(),
            plate = (DWE.RawPlate() or DWE.lastPlate) and true or nil,
        }
    end
    local parts = skin.dweParts
    if not parts then
        parts = CreateThemeParts(frame, frame:GetFrameLevel())
        skin.dweParts = parts
    end
    local own = DWE.SpokenThemeOverride() ~= nil
    for _, t in ipairs(skin.parchments or {}) do t:SetShown(not own) end
    if head.socket then head.socket:SetShown(not own) end
    if head.divider then head.divider:SetShown(not own) end
    if own then
        PaintThemeParts(parts, content, head.anchor, SpokenStyle())
    else
        ClearThemeParts(parts)
    end
end

local spokenHooked = false
function DWE.HookSpoken()
    if spokenHooked then return end
    local skin, env = SpokenSkin()
    if not skin then return end
    spokenHooked = true
    spokenSkinRef = skin

    local function GuardAll(self)
        self = self or skin
        GuardSpokenFrame(self.shadow)
        GuardSpokenFrame(self.card)
        GuardSpokenFrame(self.ripple)
    end
    if type(skin.ShadowUnder) == "function" then hooksecurefunc(skin, "ShadowUnder", GuardAll) end
    if type(skin.TuckFrames) == "function" then hooksecurefunc(skin, "TuckFrames", GuardAll) end
    GuardAll(skin)

    -- Couleurs du texte (claires / foncees) selon le theme de DWE.
    local theme = rawget(env, "DialogueUITheme")
    if type(theme) == "table" and type(theme.ThemeID) == "function" then
        local origThemeID = theme.ThemeID
        theme.ThemeID = function(self, ...)
            return DWE.SpokenThemeOverride() or origThemeID(self, ...)
        end
    end
    -- Mise en page "PNJ" pour tout (livres compris), avec ombre du texte selon le theme.
    if type(skin.Look) == "function" then
        local origLook = skin.Look
        local copies = {}
        skin.Look = function(self, ...)
            local look = origLook(self, ...)
            local looks = skin.art and skin.art.LOOKS
            local quest = looks and looks.quest
            -- Livre de DialogueUI ouvert : le lecteur prend sa page (metal pour les plaques).
            local st = DWE.SpokenStamp()
            if st and look == quest and st.left and type(looks) == "table" then
                return (st.plate and looks.stone or looks.paper) or look
            end
            if not st and look == quest and SpokenBookLeftAlone() and type(looks) == "table" then
                return ((DWE.RawPlate() or DWE.lastPlate) and looks.stone or looks.paper) or look
            end
            if not DWE.SpokenThemeOverride() or type(quest) ~= "table" then return look end
            local shadow = SpokenTextShadow()
            if not copies[shadow] then
                local c = {}
                for k, v in pairs(quest) do c[k] = v end
                c.shadow = shadow or nil
                copies[shadow] = c
            end
            return copies[shadow]
        end
    end
    if type(skin.Layout) == "function" then hooksecurefunc(skin, "Layout", PaintSpoken) end
    -- Pendant ses fondus "en une seule image", Spoken fait ignorer l'alpha du cadre a ses
    -- morceaux : notre fond fait pareil pour s'effacer au meme rythme.
    local function SyncBuffered(self)
        local parts = self.dweParts
        if not parts then return end
        for _, r in ipairs(parts.list) do
            if r.SetIgnoreParentAlpha then r:SetIgnoreParentAlpha(self.buffered and true or false) end
        end
    end
    if type(skin.Buffer) == "function" then hooksecurefunc(skin, "Buffer", SyncBuffered) end
    if type(skin.Unbuffer) == "function" then hooksecurefunc(skin, "Unbuffer", SyncBuffered) end
end

-- Redessine le lecteur Spoken tout de suite apres un changement d'option.
function DWE.RefreshSpoken()
    local skin = SpokenSkin()
    if skin and skin.frame and type(skin.RefreshConfig) == "function" then
        pcall(skin.RefreshConfig, skin)
    end
    if DWE.PaintSpokenSubtitle then DWE.PaintSpokenSubtitle() end
end

-- Sous-titres de Spoken (style "sous-titres", sans DialogueUI) pendant un livre de l'addon :
-- une page de grimoire sombre derriere le texte (le texte de Spoken est clair).
local subParts, subHooked
function DWE.PaintSpokenSubtitle()
    local env = rawget(_G, "SpokenEnv")
    local sub = type(env) == "table" and rawget(env, "Subtitle")
    local fr = type(sub) == "table" and sub.frame
    local anchor = type(sub) == "table" and sub.shadow
    if not (fr and anchor) then return end
    if not subHooked and type(sub.Layout) == "function" then
        subHooked = true
        hooksecurefunc(sub, "Layout", function() DWE.PaintSpokenSubtitle() end)
    end
    subParts = subParts or CreateThemeParts(fr, fr:GetFrameLevel())
    if DWE.bookMode and DWE.BookStyleNow() == "addon" then
        PaintThemeParts(subParts, anchor, nil, "bookpaper_dark")
    else
        ClearThemeParts(subParts)
    end
end

--------------------------------------------------------------------------------
-- Popup de texte
--------------------------------------------------------------------------------

local function StringLength(s)
    if s == nil or (issecretvalue and issecretvalue(s)) then return 0 end
    return #s
end

local function IsBubbleTheme()
    return DWE.BubbleSkin() ~= nil
end
DWE.IsBubbleTheme = IsBubbleTheme

-- Theme Cinematique : deux bandes noires (haut et bas de l'ecran), sous toute l'interface.
-- Le texte se place en sous-titre, centre dans la bande du bas.
local cineBars = CreateFrame("Frame", nil, UIParent)
cineBars:SetAllPoints(UIParent)
cineBars:SetFrameStrata("BACKGROUND")
cineBars:EnableMouse(false)
cineBars:Hide()
local cineTop = cineBars:CreateTexture(nil, "BACKGROUND")
cineTop:SetColorTexture(0, 0, 0, 1)
cineTop:SetPoint("TOPLEFT")
cineTop:SetPoint("TOPRIGHT")
local cineBot = cineBars:CreateTexture(nil, "BACKGROUND")
cineBot:SetColorTexture(0, 0, 0, 1)
cineBot:SetPoint("BOTTOMLEFT")
cineBot:SetPoint("BOTTOMRIGHT")
cineBars.alpha = 0

-- Pendant une cinematique, le reste de l'interface s'efface en fondu avec les bandes et revient
-- a la fin. On ne touche qu'a l'opacite (jamais Hide/Show), et rien n'est efface en combat.
-- Restent visibles : l'addon, DialogueUI/Spoken (deja geres), les infobulles et les fenetres
-- systeme (menu Echap, options, fenetres de confirmation).
local hiddenUI = {} -- cadre -> opacite d'origine
local KEEP_UI = {
    GameTooltip = true, ItemRefTooltip = true, ShoppingTooltip1 = true, ShoppingTooltip2 = true,
    GameMenuFrame = true, SettingsPanel = true, InterfaceOptionsFrame = true, StaticPopup1 = true,
    StaticPopup2 = true, StaticPopup3 = true, StaticPopup4 = true,
    GossipFrame = true, QuestFrame = true, ItemTextFrame = true, -- deja geres par l'addon
}
local function KeepFrame(fr)
    if fr == choiceBox or fr == textBox or fr == DWE.bubble or fr == DWE.cineBars then return true end
    local ok, name = pcall(fr.GetName, fr)
    if not ok or type(name) ~= "string" then return false end
    return KEEP_UI[name] or name:find("^DialogueWheelE") or name:find("^Storytale") or name:find("^DWE") or name:find("^DUI")
        or name:find("^Spoken") or name:find("^StaticPopup")
end
local function CollectUI()
    if InCombatLockdown and InCombatLockdown() then return end
    if not UIParent.GetChildren then return end
    for _, fr in ipairs({ UIParent:GetChildren() }) do
        -- Cadres proteges (fenetres Blizzard interdites aux addons) : on n'y touche pas.
        local okF, forbidden = pcall(function() return fr.IsForbidden and fr:IsForbidden() end)
        local okS, shown = false, false
        if okF and not forbidden then okS, shown = pcall(fr.IsShown, fr) end
        if okS and shown and not hiddenUI[fr] and fr.GetAlpha and not KeepFrame(fr) then
            local ok, a = pcall(fr.GetAlpha, fr)
            if ok and type(a) == "number" and a > 0 then hiddenUI[fr] = a end
        end
    end
end
local function FadeUI(f)
    for fr, a in pairs(hiddenUI) do pcall(fr.SetAlpha, fr, a * (1 - f)) end
end
local function RestoreUI()
    FadeUI(0)
    wipe(hiddenUI)
end
DWE.HiddenUI = hiddenUI

cineBars:SetScript("OnUpdate", function(self, dt)
    local target = self.want and 1 or 0
    local a = self.alpha + (target - self.alpha) * math.min(1, dt * 6)
    if math.abs(target - a) < 0.01 then a = target end
    self.alpha = a
    self:SetAlpha(a)
    -- Pendant le fondu a chaque image ; ensuite deux fois par seconde (si un autre addon
    -- remontre un cadre, il repart).
    self.tick = (self.tick or 0) + dt
    if a ~= self.lastA or self.tick > 0.5 then
        self.lastA, self.tick = a, 0
        FadeUI(a)
    end
    if a == 0 and not self.want then
        RestoreUI()
        self:Hide()
    end
end)
DWE.cineBars = cineBars

local function ScreenHeight()
    local ok, h = pcall(UIParent.GetHeight, UIParent)
    return (ok and type(h) == "number" and h > 0) and h or 768
end

function DWE.PlaceCinema(textH)
    local barH = math.max(ScreenHeight() * 0.12, textH + 36)
    cineTop:SetHeight(ScreenHeight() * 0.09)
    cineBot:SetHeight(barH)
    textBox:ClearAllPoints()
    textBox:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, math.floor((barH - textH) / 2))
end

function DWE.UpdateCinemaBars()
    local want = DWE.IsCinema() and textBox:IsShown() and true or false
    cineBars.want = want
    if want then CollectUI() end
    if want and not cineBars:IsShown() then
        cineTop:SetHeight(ScreenHeight() * 0.09)
        if (cineBot:GetHeight() or 0) <= 0 then cineBot:SetHeight(ScreenHeight() * 0.12) end
        cineBars.alpha = 0
        cineBars:SetAlpha(0)
        cineBars:Show()
    end
end
textBox:HookScript("OnHide", function() DWE.UpdateCinemaBars() end)

--------------------------------------------------------------------------------
-- Livres et lettres (option "Cet addon") : "Note" = le cadre du theme ; "Livre" = un livre
-- ouvert, le texte de la page reparti sur deux pages. Place a gauche de l'ecran, avec les
-- boutons (page precedente / suivante...) en ligne dessous, sans cadre.
--------------------------------------------------------------------------------
-- Livre peint (BookSpread.png : 1024x576 utiles dans une image 1024x1024), taille fixe.
-- Zone de texte : deux colonnes posees sur les pages de l'image.
local noteScroll -- zone defilante de la note (creee plus bas)
local BOOK_W, BOOK_H = 820, 461
local BOOK_COL, BOOK_GUTTER = 245, 88
local BOOK_LEFT, BOOK_TOP, BOOK_TEXT_H = 122, 72, 268
local bookL = textBox:CreateTexture(nil, "BACKGROUND", nil, -7)
bookL:SetTexture(ADDON_PATH .. "BookSpread.png")
bookL:SetTexCoord(0, 1, 0, 576 / 1024)
bookL:SetSize(BOOK_W, BOOK_H)
bookL:Hide()
local bookR = { Hide = function() end, Show = function() end, ClearAllPoints = function() end, SetPoint = function() end }
local noteBg = textBox:CreateTexture(nil, "BACKGROUND", nil, -7)
noteBg:SetTexture(ADDON_PATH .. "BookPaper.png")
if noteBg.SetTextureSliceMargins then pcall(noteBg.SetTextureSliceMargins, noteBg, 90, 90, 90, 90) end
noteBg:Hide()
local noteRule = textBox:CreateTexture(nil, "ARTWORK")
noteRule:SetColorTexture(0.42, 0.26, 0.10, 0.55)
noteRule:Hide()
local notePage = textBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
notePage:SetTextColor(0.42, 0.26, 0.10)
notePage:SetShadowOffset(0, 0)
notePage:Hide()
-- Numero de page du livre ouvert, en bas de la page de droite (comme un vrai livre).
local bookPageNum = textBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
bookPageNum:SetTextColor(0.40, 0.22, 0.08)
bookPageNum:SetShadowOffset(0, 0)
bookPageNum:Hide()
function DWE.bookPageNumText() return bookPageNum:IsShown() and bookPageNum:GetText() or "" end
local textBody2 = textBox:CreateFontString(nil, "OVERLAY")
textBody2:SetFontObject(questFontObj)
textBody2:SetSpacing(5)
StyleText(textBody2, 0.17, 0.10, 0.04)
textBody2:Hide()
DWE.textBody2 = textBody2

-- Plaques (textes graves) : le jeu donne la matiere du texte. Pierre, marbre, bronze et argent
-- s'affichent sur une plaque de cette matiere, toujours en page seule.
DWE.PLATES = {
    Stone = { tex = "PlateStone", slice = { 59, 61, 61, 61 }, body = { 0.16, 0.16, 0.16 }, hdr = { 0.10, 0.10, 0.10 }, rule = { 0.20, 0.20, 0.20, 0.45 }, engrave = { 1, 1, 1, 0.55 } },
    Marble = { tex = "PlateMarble", slice = { 62, 66, 62, 67 }, body = { 0.22, 0.22, 0.25 }, hdr = { 0.14, 0.14, 0.17 }, rule = { 0.35, 0.35, 0.40, 0.45 }, engrave = { 1, 1, 1, 0.6 } },
    Bronze = { tex = "PlateBronze", slice = { 68, 68, 68, 66 }, body = { 0.20, 0.13, 0.03 }, hdr = { 0.14, 0.09, 0.02 }, rule = { 0.30, 0.20, 0.05, 0.45 }, engrave = { 1, 0.94, 0.75, 0.55 } },
    Silver = { tex = "PlateSilver", slice = { 48, 48, 48, 55 }, body = { 0.16, 0.17, 0.19 }, hdr = { 0.10, 0.11, 0.13 }, rule = { 0.25, 0.26, 0.30, 0.45 }, engrave = { 1, 1, 1, 0.6 } },
}
function DWE.RawPlate()
    if DWE.testPlate and (DWE.bookMode or (ItemTextGetMaterial and ItemTextGetMaterial())) then
        DWE.lastPlate = DWE.testPlate
        return DWE.testPlate
    end
    if not ItemTextGetMaterial then return nil end
    -- Le jeu ne donne la matiere que tant que son texte est ouvert : on la garde pour la suite
    -- du meme texte (le lecteur Spoken se redessine apres).
    local ok, m = pcall(ItemTextGetMaterial)
    if ok and type(m) == "string" and m ~= "" then
        -- Matiere choisie dans les options pour toutes les plaques (sinon celle du jeu).
        local pick = DialogueWheelE_PlateLook
        if DWE.PLATES[m] and pick and DWE.PLATES[pick] then m = pick end
        DWE.lastPlate = DWE.PLATES[m] and m or nil
        return DWE.lastPlate
    end
    return DWE.bookMode and DWE.lastPlate or nil
end
function DWE.PlateMaterial()
    if not DWE.BookByAddon() then return nil end
    return DWE.RawPlate()
end
-- Qui affiche le texte en cours : "addon", "dui" ou "blizzard". Les plaques ont leur propre
-- reglage (DialogueUI seulement s'il est installe).
function DWE.BookStyleNow()
    if DWE.RawPlate() then
        local ps = DialogueWheelE_PlateStyle or "addon"
        if ps == "dui" then
            local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
            if not (loaded and loaded("DialogueUI")) then ps = "addon" end
        end
        return ps
    end
    return DialogueWheelE_BookStyle or "addon"
end

-- "book" (livre ouvert), "note" (page seule), "frame" (cadre du theme) ou nil (pas un livre).
-- Automatique : plusieurs pages = livre, une seule = note.
function DWE.BookLook()
    if not DWE.BookByAddon() then return nil end
    if DWE.PlateMaterial() then return "note" end
    local pref = DialogueWheelE_BookLook or "auto"
    if pref == "note" or pref == "book" or pref == "frame" then return pref end
    local bi = DWE.bookInfo
    return (bi and ((bi.total or 1) > 1 or bi.hasNext)) and "book" or "note"
end

-- Coupe le texte en deux moities, a une fin de phrase ou un espace pres du milieu.
local function SplitHalf(s)
    if type(s) ~= "string" or (issecretvalue and issecretvalue(s)) or #s < 160 then return s, "" end
    local mid = math.floor(#s / 2)
    local cut = s:find("[%.!?]%s", mid)
    if not cut or cut > mid + #s * 0.2 then cut = s:find("%s", mid) end
    if not cut then return s, "" end
    return s:sub(1, cut):gsub("%s+$", ""), s:sub(cut + 1):gsub("^%s+", "")
end
DWE.SplitHalf = SplitHalf

local function BookPosition()
    if textBox.dweMoving then return end
    local p = DialogueWheelE_BookPos
    if type(p) == "table" and p.x then
        textBox:ClearAllPoints()
        textBox:SetPoint(p.point, UIParent, p.relPoint, p.x, p.y)
        return
    end
    -- Par defaut : a droite de l'ecran, un peu au-dessus du milieu (proportionnel a la largeur
    -- de l'ecran ; reglage de reference fait sur un ecran large).
    local okW, uw = pcall(UIParent.GetWidth, UIParent)
    uw = (okW and type(uw) == "number") and uw or 1600
    textBox:ClearAllPoints()
    if textBox.dweBook == "note" then
        -- Notes et plaques : la place choisie par l'auteur (a droite, un peu au-dessus du milieu).
        local ns = DWE.NoteScale()
        textBox:SetPoint("RIGHT", UIParent, "RIGHT", -417 / ns, 102 / ns)
        return
    end
    local sc = DWE.BookScaleWanted()
    textBox:SetPoint("RIGHT", UIParent, "RIGHT", -(uw * 0.2) / sc, 63 / sc)
end

-- Echelle du livre ouvert (poignee du coin). Le coin haut-gauche reste en place.
-- Taille des notes et plaques (poignee), a part de celle des livres ouverts.
function DWE.NoteScale()
    local v = tonumber(DialogueWheelE_NoteScale)
    return (v and v >= 0.6 and v <= 2) and v or 0.77 -- taille par defaut : 77 %
end
function DWE.BookScaleWanted()
    local v = tonumber(DialogueWheelE_BookScale)
    return (v and v >= 0.5 and v <= 2) and v or 0.75 -- taille par defaut : 75 %
end
-- keepCorner : seulement depuis la poignee (le coin haut-gauche reste sous la souris). Sinon
-- (ouverture, fermeture) on change juste l'echelle : BookPosition remet la position sauvee,
-- qui est dans l'echelle du livre.
function DWE.SetBookScale(sc, keepCorner)
    local cur = textBox:GetScale() or 1
    if DWE.bookBar then DWE.bookBar:SetScale(sc) end
    if math.abs(cur - sc) < 0.001 then return end
    local okL, l = pcall(textBox.GetLeft, textBox)
    local okT, t = pcall(textBox.GetTop, textBox)
    textBox:SetScale(sc)
    if keepCorner and okL and okT and type(l) == "number" and type(t) == "number" and DWE.bookMode then
        textBox:ClearAllPoints()
        textBox:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l * cur / sc, t * cur / sc)
        DialogueWheelE_BookPos = { point = "TOPLEFT", relPoint = "BOTTOMLEFT", x = l * cur / sc, y = t * cur / sc }
    end
end

local function RestoreTextAnchors()
    textHeader:ClearAllPoints()
    textHeader:SetPoint("TOPLEFT", textBox, "TOPLEFT", 0, -2)
    textHeader:SetPoint("TOPRIGHT", textBox, "TOPRIGHT", 0, -2)
    textBody:ClearAllPoints()
    textBody:SetPoint("TOPLEFT", textHeader, "BOTTOMLEFT", 0, -8)
    textBody:SetPoint("TOPRIGHT", textHeader, "BOTTOMRIGHT", 0, -8)
    bookL:Hide()
    bookR:Hide()
    noteBg:Hide()
    noteRule:Hide()
    notePage:Hide()
    bookPageNum:Hide()
    textBody2:Hide()
    textBox.dweBook = nil
    textBox.dweGripAnchor, textBox.dweNoGrip = nil, nil
    textBox.dweGripX, textBox.dweGripY = nil, nil
    DWE.SetBookScale(1)
    if noteScroll then noteScroll:Hide() end
    textBody:Show()
    if textBox.SetHitRectInsets then textBox:SetHitRectInsets(0, 0, 0, 0) end
    DWE.ApplyFont()
end

local NOTE_W, NOTE_PAD_X, NOTE_PAD_Y, NOTE_MAX_H = 440, 56, 52, 340
-- Zone qui defile pour le texte de la note (molette, ou la molette des choix pendant une note).
local NOTE = {}
noteScroll = CreateFrame("ScrollFrame", nil, textBox)
noteScroll:Hide()
NOTE.noteChild = CreateFrame("Frame", nil, noteScroll)
NOTE.noteChild:SetSize(NOTE_W, 10)
noteScroll:SetScrollChild(NOTE.noteChild)
NOTE.noteText = NOTE.noteChild:CreateFontString(nil, "OVERLAY")
NOTE.noteText:SetFontObject(questFontObj)
NOTE.noteText:SetSpacing(5)
NOTE.noteText:SetJustifyH("LEFT")
NOTE.noteText:SetPoint("TOPLEFT", NOTE.noteChild, "TOPLEFT", 0, 0)
NOTE.noteText:SetWidth(NOTE_W)
NOTE.noteText:SetTextColor(0.17, 0.10, 0.04)
NOTE.noteText:SetShadowOffset(0, 0)
NOTE.noteThumb = noteScroll:CreateTexture(nil, "OVERLAY")
NOTE.noteThumb:SetColorTexture(0.42, 0.26, 0.10, 0.45)
NOTE.noteThumb:SetWidth(3)
NOTE.noteThumb:Hide()
DWE.noteText = NOTE.noteText

function NOTE.Range()
    local okC, ch = pcall(NOTE.noteChild.GetHeight, NOTE.noteChild)
    local okS, sh = pcall(noteScroll.GetHeight, noteScroll)
    if not (okC and okS and type(ch) == "number" and type(sh) == "number") then return 0, 0 end
    return math.max(0, ch - sh), sh
end
function NOTE.PlaceThumb()
    local range, view = NOTE.Range()
    if range <= 0 then NOTE.noteThumb:Hide() return end
    local h = math.max(20, view * view / (view + range))
    local y = (noteScroll:GetVerticalScroll() or 0) / range * (view - h)
    NOTE.noteThumb:ClearAllPoints()
    NOTE.noteThumb:SetPoint("TOPRIGHT", noteScroll, "TOPRIGHT", 14, -y)
    NOTE.noteThumb:SetHeight(h)
    NOTE.noteThumb:Show()
end
-- Fait defiler la note ; renvoie vrai si une note defilante est affichee.
function DWE.NoteScrollBy(delta)
    if not noteScroll:IsShown() then return false end
    local range = NOTE.Range()
    if range <= 0 then return true end
    local v = (noteScroll:GetVerticalScroll() or 0) - delta * 40
    noteScroll:SetVerticalScroll(math.max(0, math.min(range, v)))
    NOTE.PlaceThumb()
    return true
end
noteScroll:EnableMouseWheel(true)
noteScroll:SetScript("OnMouseWheel", function(_, delta) DWE.NoteScrollBy(delta) end)
-- Clic gauche maintenu et glisser : le texte suit la souris (comme les longues listes de choix).
noteScroll:EnableMouse(true)
noteScroll:SetScript("OnMouseDown", function(self, button)
    if button ~= "LeftButton" then return end
    local _, y = GetCursorPosition()
    self.drag = { y = y / UIParent:GetEffectiveScale(), v = self:GetVerticalScroll() or 0 }
    self:SetScript("OnUpdate", function(f)
        if not f.drag then return end
        local _, cy = GetCursorPosition()
        cy = cy / UIParent:GetEffectiveScale()
        local range = NOTE.Range()
        f:SetVerticalScroll(math.max(0, math.min(range, f.drag.v + (cy - f.drag.y))))
        NOTE.PlaceThumb()
    end)
end)
noteScroll:SetScript("OnMouseUp", function(self)
    self.drag = nil
    self:SetScript("OnUpdate", nil)
end)
noteScroll:SetScript("OnHide", function(self)
    self.drag = nil
    self:SetScript("OnUpdate", nil)
end)
local function MorpheusTitle()
    if DWE.IS_CJK then return end
    local hp = (DWE.IS_CYRILLIC and "Fonts\\MORPHEUS_CYR.TTF") or "Fonts\\MORPHEUS.TTF"
    SafeSetFont(textHeader, hp, (tonumber(DialogueWheelE_FontSize) or 13) + 9)
end

-- Note : une page de parchemin, titre centre, filet avec le numero de page, texte dessous.
local function LayoutNote()
    ClearThemeParts(textParts)
    bookL:Hide()
    textBody2:Hide()
    textBox.dweBook = "note"
    DWE.SetBookScale(DWE.NoteScale())
    textBox:SetWidth(NOTE_W)
    MorpheusTitle()
    textHeader:ClearAllPoints()
    textHeader:SetPoint("TOPLEFT", textBox, "TOPLEFT", 0, -2)
    textHeader:SetPoint("TOPRIGHT", textBox, "TOPRIGHT", 0, -2)
    textHeader:SetJustifyH("CENTER")
    local plate = DWE.PLATES[DWE.PlateMaterial() or ""]
    local bodyC = plate and plate.body or { 0.17, 0.10, 0.04 }
    local hdrC = plate and plate.hdr or { 0.24, 0.13, 0.05 }
    local ruleC = plate and plate.rule or { 0.42, 0.26, 0.10, 0.55 }
    textHeader:SetTextColor(hdrC[1], hdrC[2], hdrC[3])
    NOTE.noteText:SetTextColor(bodyC[1], bodyC[2], bodyC[3])
    -- Texte grave : un liseré clair en bas a droite des lettres sombres.
    local eg = plate and plate.engrave
    for _, fs in ipairs({ textHeader, NOTE.noteText }) do
        if eg then
            fs:SetShadowColor(eg[1], eg[2], eg[3], eg[4])
            fs:SetShadowOffset(1, -1)
        else
            fs:SetShadowColor(0, 0, 0, 1)
            fs:SetShadowOffset(0, 0)
        end
    end
    noteRule:SetColorTexture(ruleC[1], ruleC[2], ruleC[3], ruleC[4])
    NOTE.noteThumb:SetColorTexture(ruleC[1], ruleC[2], ruleC[3], 0.5)
    local texName = plate and plate.tex or "BookPaper"
    if noteBg.dweTex ~= texName then
        noteBg.dweTex = texName
        noteBg:SetTexture(ADDON_PATH .. texName .. ".png")
        if noteBg.SetTextureSliceMargins then
            local sl = plate and plate.slice or { 90, 90, 90, 90 }
            pcall(noteBg.SetTextureSliceMargins, noteBg, sl[1], sl[2], sl[3], sl[4])
        end
    end
    -- Marges autour du texte : celles de la page, ou le cadre de la plaque plus un peu d'air.
    local padL, padT, padR, padB = NOTE_PAD_X, NOTE_PAD_Y, NOTE_PAD_X, NOTE_PAD_Y
    if plate then
        local sl = plate.slice
        padL, padT, padR, padB = sl[1] + 22, sl[2] + 18, sl[3] + 22, sl[4] + 18
    end
    textBox.dwePadB = padB
    local title = DWE.rawHeader or textHeader:GetText() or ""
    local plain, page = title:match("^(.-)%s*%((%d+/%d+)%)$")
    if plain then textHeader:SetText(plain) end
    noteRule:ClearAllPoints()
    noteRule:SetHeight(1)
    noteRule:SetPoint("TOPLEFT", textHeader, "BOTTOMLEFT", 0, -10)
    noteRule:SetPoint("TOPRIGHT", textHeader, "BOTTOMRIGHT", 0, -10)
    noteRule:Show()
    notePage:Hide()
    -- Tout le texte dans une zone qui defile (pas de pages).
    textBody:Hide()
    -- Plaque/page reduite : la police grossit pour rester lisible (comme les livres).
    local font, size = textBody:GetFont()
    local nsc = DWE.NoteScale()
    local nbase = tonumber(DialogueWheelE_FontSize) or size or 13
    local nsz = nsc < 0.98 and math.floor(nbase / (nsc ^ 0.9) + 0.5) or nbase
    if font then pcall(NOTE.noteText.SetFont, NOTE.noteText, font, nsz, "") end
    local hFont, hSize = textHeader:GetFont()
    if nsc < 0.98 and hFont and hSize and not DWE.IS_CJK then
        SafeSetFont(textHeader, hFont, math.floor(hSize / (nsc ^ 0.6) + 0.5))
    end
    local body = DWE.bookRawBody or ""
    if NOTE.noteText.dweLast ~= body then
        NOTE.noteText.dweLast = body
        NOTE.noteText:SetText(body)
        noteScroll:SetVerticalScroll(0)
    end
    local th = TextHeight(NOTE.noteText, 20)
    NOTE.noteChild:SetHeight(th)
    local view = math.min(th, NOTE_MAX_H)
    noteScroll:ClearAllPoints()
    noteScroll:SetPoint("TOPLEFT", noteRule, "BOTTOMLEFT", 0, -14)
    noteScroll:SetSize(NOTE_W, math.max(20, view))
    noteScroll:Show()
    NOTE.PlaceThumb()
    local h = TextHeight(textHeader, 22) + 24 + view
    textBox:SetHeight(math.max(160, h))
    textBox.dweGripAnchor, textBox.dweGripX, textBox.dweGripY = noteBg, 0, 0
    textBox.dweNoGrip = nil
    noteBg:ClearAllPoints()
    noteBg:SetPoint("TOPLEFT", textBox, "TOPLEFT", -padL, padT)
    noteBg:SetPoint("BOTTOMRIGHT", textBox, "BOTTOMRIGHT", padR, -padB)
    noteBg:Show()
    if textBox.SetHitRectInsets then textBox:SetHitRectInsets(-padL, -padR, -padT, -padB) end
    DWE.SetGripCorner(textBox, "BOTTOMRIGHT")
    BookPosition()
end

-- Sous-pages du livre. Decoupe `raw` en doubles pages (colonne gauche, colonne droite) qui
-- tiennent a la taille de police `fsz`. Garde la sous-page courante tant que la page ne change pas.
DWE.bookSub = { key = nil, spreads = {}, index = 1 }
function DWE.BookSubTokens(raw)
    local t = {}
    if DWE.IS_CJK then
        for ch in raw:gmatch("[%z\1-\127\194-\244][\128-\191]*") do t[#t + 1] = ch end
    else
        local pos = 1
        local lead = raw:match("^%s*")
        if lead ~= "" then pos = #lead + 1 end
        for w, sp in raw:gmatch("(%S+)(%s*)", pos) do t[#t + 1] = w .. sp end
    end
    return t
end
-- Combien de morceaux (a partir de `from`) tiennent dans `fs` sur `maxH` de haut.
function DWE.BookSubFit(fs, toks, from, maxH)
    local function H(n)
        fs:SetText((table.concat(toks, "", from, from + n - 1):gsub("%s+$", "")))
        return TextHeight(fs, 0)
    end
    local left = #toks - from + 1
    if left <= 0 then return 0 end
    if H(left) <= maxH then return left end
    local lo, hi = 0, left
    while hi - lo > 1 do
        local mid = math.floor((lo + hi) / 2)
        if H(mid) <= maxH then lo = mid else hi = mid end
    end
    return math.max(1, lo)
end
function DWE.BookSubPaginate(raw, fsz, header)
    local st = DWE.bookSub
    local key = raw .. "\0" .. fsz .. "\0" .. header
    if st.key == key then return st end
    local samePage = st.raw == raw
    st.key, st.raw = key, raw
    local maxH = BOOK_TEXT_H + 24
    -- Tient en une double page : le partage habituel en deux moities.
    local l, r = SplitHalf(raw)
    textBody:SetText(l)
    textBody2:SetText(r)
    local hHead = TextHeight(textHeader, 20) + 10
    if hHead + TextHeight(textBody, 0) <= maxH and TextHeight(textBody2, 0) <= maxH then
        st.spreads = { { l, r } }
    else
        local toks = DWE.BookSubTokens(raw)
        st.spreads = {}
        local i, guard = 1, 0
        while i <= #toks and guard < 60 do
            guard = guard + 1
            local first = #st.spreads == 0
            local nl = DWE.BookSubFit(textBody, toks, i, maxH - (first and hHead or 0))
            local lt = table.concat(toks, "", i, i + nl - 1):gsub("%s+$", "")
            i = i + nl
            local nr = DWE.BookSubFit(textBody2, toks, i, maxH)
            local rt = nr > 0 and table.concat(toks, "", i, i + nr - 1):gsub("%s+$", "") or ""
            i = i + nr
            st.spreads[#st.spreads + 1] = { lt, rt }
        end
        if #st.spreads == 0 then st.spreads = { { l, r } } end
    end
    if st.wantLast then
        st.index, st.wantLast = #st.spreads, nil
    elseif not samePage then
        st.index = 1
    end
    st.index = math.max(1, math.min(st.index, #st.spreads))
    -- Le nombre de sous-pages decide des boutons Precedente / Suivante.
    if st.lastN ~= #st.spreads then
        st.lastN = #st.spreads
        if DWE.OnBookSubChanged and C_Timer and C_Timer.After then C_Timer.After(0, DWE.OnBookSubChanged) end
    end
    return st
end
-- Bouton Suivante / Precedente : d'abord les sous-pages. Renvoie vrai si on a tourne.
function DWE.BookSubStep(dir)
    local st = DWE.bookSub
    if not (DWE.bookMode and textBox.dweBook == true) then return false end
    local n = #st.spreads
    local to = st.index + dir
    if to < 1 or to > n then return false end
    st.index = to
    DWE.UpdateTextPanelVisuals()
    return true
end
function DWE.BookSubCan(dir)
    local st = DWE.bookSub
    if not (DWE.bookMode and textBox.dweBook == true) then return false end
    local to = st.index + dir
    return to >= 1 and to <= #st.spreads
end
-- Page precedente du jeu : on arrive sur sa derniere sous-page.
function DWE.BookSubWantLast()
    DWE.bookSub.wantLast = true
end

local function LayoutBook()
    ClearThemeParts(textParts)
    noteBg:Hide()
    noteRule:Hide()
    notePage:Hide()
    textBox.dweBook = true
    DWE.SetBookScale(DWE.BookScaleWanted())
    textBox:SetWidth(2 * BOOK_COL + BOOK_GUTTER)
    -- "(1/8)" quitte le titre et va en bas de la page de droite.
    local title = DWE.rawHeader or textHeader:GetText() or ""
    local plain, page = title:match("^(.-)%s*%((%d+/%d+)%)$")
    if plain then textHeader:SetText(plain) end
    bookPageNum:SetText(page and page:gsub("/", " / ") or "")
    if not DWE.IS_CJK then
        SafeSetFont(bookPageNum, (DWE.IS_CYRILLIC and "Fonts\\MORPHEUS_CYR.TTF") or "Fonts\\MORPHEUS.TTF", math.floor(((tonumber(DialogueWheelE_FontSize) or 13) + 1) / math.min(1, DWE.BookScaleWanted()) ^ 0.8 + 0.5))
    end
    bookPageNum:ClearAllPoints()
    bookPageNum:SetPoint("BOTTOM", textBox, "BOTTOMLEFT", BOOK_COL + BOOK_GUTTER + BOOK_COL / 2, -26)
    if page then bookPageNum:Show() else bookPageNum:Hide() end
    textHeader:ClearAllPoints()
    textHeader:SetPoint("TOPLEFT", textBox, "TOPLEFT", 0, -2)
    textHeader:SetWidth(BOOK_COL)
    textHeader:SetJustifyH("LEFT")
    textHeader:SetTextColor(0.40, 0.16, 0.04)
    textHeader:SetShadowColor(0, 0, 0, 1)
    textHeader:SetShadowOffset(0, 0)
    MorpheusTitle()
    textBody:ClearAllPoints()
    textBody:SetPoint("TOPLEFT", textHeader, "BOTTOMLEFT", 0, -10)
    textBody:SetWidth(BOOK_COL)
    textBody2:ClearAllPoints()
    textBody2:SetPoint("TOPLEFT", textBox, "TOPLEFT", BOOK_COL + BOOK_GUTTER, -2)
    textBody2:SetWidth(BOOK_COL)
    for _, fs in ipairs({ textBody, textBody2 }) do
        fs:SetJustifyH("LEFT")
        fs:SetTextColor(0.17, 0.10, 0.04)
        fs:SetShadowOffset(0, 0)
    end
    textBody2:Show()
    -- Police : celle du reglage ; livre reduit, elle grossit pour garder la meme taille a l'ecran.
    -- Si la page du jeu ne tient plus, elle s'etale sur plusieurs doubles pages (sous-pages).
    local font = textBody:GetFont()
    local sc = DWE.BookScaleWanted()
    local base = tonumber(DialogueWheelE_FontSize) or 13
    local fsz = sc < 0.98 and math.floor(base / (sc ^ 0.9) + 0.5) or base
    local hFont = textHeader:GetFont()
    if font then
        pcall(textBody.SetFont, textBody, font, fsz, "")
        pcall(textBody2.SetFont, textBody2, font, fsz, "")
    end
    -- Titre : grossit moins que le texte quand le livre rapetisse (gain de place), en restant
    -- nettement plus gros que lui.
    if hFont and not DWE.IS_CJK then SafeSetFont(textHeader, hFont, fsz + math.floor(9 * math.sqrt(math.min(1, sc)) + 0.5)) end
    local raw = DWE.bookRawBody or textBody:GetText() or ""
    local sub = DWE.BookSubPaginate(raw, fsz, textHeader:GetText() or "")
    local spread = sub.spreads[sub.index] or { "", "" }
    if sub.index > 1 then textHeader:SetText("") end
    textBody:SetText(spread[1])
    textBody2:SetText(spread[2])
    -- Numero : "1 / 8", et la sous-page en lettre ("1 / 8 · b") quand la page est decoupee.
    if #sub.spreads > 1 then
        local letter = string.char(96 + math.min(26, sub.index))
        bookPageNum:SetText((page and (page:gsub("/", " / ") .. "  · ") or "") .. letter)
        bookPageNum:Show()
    end
    textBox:SetHeight(BOOK_TEXT_H)
    bookL:ClearAllPoints()
    bookL:SetPoint("TOPLEFT", textBox, "TOPLEFT", -BOOK_LEFT, BOOK_TOP)
    bookL:Show()
    if noteScroll then noteScroll:Hide() end
    textBody:Show()
    -- Poignee au coin bas-droit peint du livre : agrandit / reduit tout le livre.
    textBox.dweNoGrip = nil
    textBox.dweGripAnchor = bookL
    textBox.dweGripX, textBox.dweGripY = -22, -28
    DWE.SetGripCorner(textBox, "BOTTOMRIGHT")
    -- Tout le livre se saisit pour le deplacer, pas seulement le texte.
    if textBox.SetHitRectInsets then
        local below = BOOK_H - BOOK_TOP - BOOK_TEXT_H
        textBox:SetHitRectInsets(-BOOK_LEFT, -(BOOK_W - BOOK_LEFT - textBox:GetWidth()), -BOOK_TOP, -below)
    end
    BookPosition()
end

-- Boutons du livre, en ligne sous la page, sans cadre. La roue reste en place (clavier,
-- molette) mais invisible et sans clic.
local bookBar = CreateFrame("Frame", "DialogueWheelEBookBar", UIParent)
DWE.bookBar = bookBar
bookBar:SetFrameStrata("DIALOG")
bookBar:SetSize(10, 30)
bookBar:Hide()
bookBar.buttons = {}
-- Molette sur le livre, la note ou la barre de boutons : comme sur la roue (change de choix ;
-- dans une note, fait d'abord defiler le texte). La molette du jeu ne passe pas au-dessus
-- d'un cadre de l'interface, d'ou ce relais.
function DWE.BookWheel(_, delta)
    if not DWE.bookMode then return end
    if IsMouseButtonDown and (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")) then return end
    if not DWE.NoteScrollBy(delta) and DWE.WheelStep then DWE.WheelStep(delta > 0 and -1 or 1) end
end
bookBar:EnableMouseWheel(true)
bookBar:SetScript("OnMouseWheel", DWE.BookWheel)
textBox:EnableMouseWheel(true)
textBox:SetScript("OnMouseWheel", function(self, delta)
    if DWE.bookMode then return DWE.BookWheel(self, delta) end
    if DWE.WheelStep and DialogueWheelE_WheelScroll ~= false then DWE.WheelStep(delta > 0 and -1 or 1) end
end)
DWE.bookBar = bookBar

hooksecurefunc(choiceBox, "SetAlpha", function(self, a)
    if self.dweBookHidden and a > 0 then self:SetAlpha(0) end
end)

local function SetWheelHidden(hide)
    if not hide and not choiceBox.dweBookHidden then return end
    choiceBox.dweBookHidden = hide or nil
    choiceBox:SetAlpha(hide and 0 or 1)
    -- Invisible ET sans souris : sinon la roue cachee intercepte les clics (boutons du livre,
    -- deplacement du livre) quand elle se trouve dessus. On remet ensuite exactement ce qui
    -- captait la souris. Refait a chaque mise a jour : une ligne de choix creee entre-temps
    -- (ex. bouton "Page precedente") capterait sinon la souris.
    if hide then
        choiceBox.dweMouseOff = choiceBox.dweMouseOff or {}
        local function off(fr)
            if fr.IsMouseEnabled and fr:IsMouseEnabled() then
                choiceBox.dweMouseOff[#choiceBox.dweMouseOff + 1] = fr
                fr:EnableMouse(false)
            end
            if fr.EnableMouseWheel then pcall(fr.EnableMouseWheel, fr, false) end
            for _, c in ipairs({ fr:GetChildren() }) do off(c) end
        end
        off(choiceBox)
    else
        for _, fr in ipairs(choiceBox.dweMouseOff or {}) do fr:EnableMouse(true) end
        choiceBox.dweMouseOff = nil
        if choiceBox.EnableMouseWheel then pcall(choiceBox.EnableMouseWheel, choiceBox, true) end
    end
end

local duiBookMuted
local function MuteDUIBook(mute)
    local fr = rawget(_G, "DUIBookFrame")
    if type(fr) ~= "table" or not fr.EnableMouse then return end
    if mute == (duiBookMuted == true) then return end
    duiBookMuted = mute or nil
    if mute then
        -- On retient ce qui captait la souris pour le rendre tel quel ensuite.
        fr.dweMuted = {}
        local function walk(f)
            if f.IsMouseEnabled and f:IsMouseEnabled() then
                fr.dweMuted[#fr.dweMuted + 1] = f
                pcall(f.EnableMouse, f, false)
            end
            for _, c in ipairs({ f:GetChildren() }) do walk(c) end
        end
        walk(fr)
    else
        for _, f in ipairs(fr.dweMuted or {}) do pcall(f.EnableMouse, f, true) end
        fr.dweMuted = nil
    end
    if fr.EnableKeyboard then pcall(fr.EnableKeyboard, fr, not mute) end
end

function DWE.UpdateBookBar()
    local active = DWE.bookMode and textBox:IsShown() and choiceBox:IsShown() and #DWE.currentOptions > 0
    MuteDUIBook(DWE.BookByAddon() and choiceBox:IsShown())
    if not active then
        bookBar:Hide()
        SetWheelHidden(false)
        return
    end
    SetWheelHidden(true)
    bookBar:ClearAllPoints()
    local below = (textBox.dweBook == true and (BOOK_H - BOOK_TOP - BOOK_TEXT_H + 4))
        or (textBox.dweBook == "note" and ((textBox.dwePadB or NOTE_PAD_Y) + 6)) or 26
    bookBar:SetPoint("TOP", textBox, "BOTTOM", 0, -below)
    local x = 0
    for i, opt in ipairs(DWE.currentOptions) do
        local b = bookBar.buttons[i]
        if not b then
            b = CreateFrame("Button", nil, bookBar)
            b:EnableMouseWheel(true)
            b:SetScript("OnMouseWheel", DWE.BookWheel)
            b:SetHeight(26)
            b.icon = b:CreateTexture(nil, "ARTWORK")
            b.icon:SetSize(16, 16)
            b.icon:SetPoint("LEFT", b, "LEFT", 0, 0)
            b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            b.text:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
            b.text:SetShadowColor(0, 0, 0, 1)
            b.text:SetShadowOffset(1, -1)
            b:SetScript("OnEnter", function()
                local o = DWE.currentOptions[i]
                if o and not o.disabled and DWE.selectedIndex ~= i then
                    DWE.selectedIndex = i
                    DWE.UpdateVisuals()
                end
            end)
            b:SetScript("OnClick", function()
                local o = DWE.currentOptions[i]
                if o and not o.disabled and o.action then
                    DWE.selectedIndex = i
                    o.action()
                end
            end)
            bookBar.buttons[i] = b
        end
        b.icon:SetTexture(opt.icon)
        b.icon:SetShown(opt.icon ~= nil)
        b.text:SetText(opt.rawLabel)
        local sel = i == DWE.selectedIndex
        if opt.disabled then
            b.text:SetTextColor(0.5, 0.5, 0.5)
        elseif sel then
            b.text:SetTextColor(opt.isGoodbye and 1 or 1, opt.isGoodbye and 0.35 or 0.85, opt.isGoodbye and 0.3 or 0.2)
        elseif opt.isGoodbye then
            b.text:SetTextColor(0.75, 0.75, 0.75)
        else
            b.text:SetTextColor(0.95, 0.92, 0.85)
        end
        local w = (MeasureWidth(b.text) or 90) + (opt.icon and 22 or 0) + 4
        b:SetWidth(w)
        b:ClearAllPoints()
        b:SetPoint("LEFT", bookBar, "LEFT", x, 0)
        b:Show()
        x = x + w + 28
    end
    for i = #DWE.currentOptions + 1, #bookBar.buttons do bookBar.buttons[i]:Hide() end
    bookBar:SetWidth(math.max(10, x - 28))
    bookBar:Show()
end
choiceBox:HookScript("OnHide", function() DWE.UpdateBookBar() end)

function DWE.UpdateTextPanelVisuals()
    local wanted = choiceBox:IsShown() and DWE.TextWanted()
    if DWE.Bubble then DWE.Bubble.SetShown(wanted and IsBubbleTheme()) end
    if wanted and IsBubbleTheme() then
        textBox:Hide()
    elseif wanted then
        local look = DWE.BookLook()
        if look == "book" or look == "note" then
            if look == "book" then LayoutBook() else LayoutNote() end
            textBox:Show()
            DWE.UpdateCinemaBars()
            DWE.UpdateBookBar()
            RefreshHiddenFrames()
            return
        elseif textBox.dweBook then
            RestoreTextAnchors()
            DWE.ApplyTextTheme()
            textBody:SetText(DWE.bookRawBody or textBody:GetText())
        end
        local long = StringLength(textBody:GetText()) > 150
        -- Largeur max : choisie avec la poignee, sinon selon la longueur du texte. Le cadre se
        -- resserre sur un texte court (une ligne = un cadre etroit).
        local maxW = tonumber(DialogueWheelE_TextW) or (long and 430 or 380)
        local cine = DWE.IsCinema()
        if cine then
            local okW, uw = pcall(UIParent.GetWidth, UIParent)
            uw = (okW and type(uw) == "number") and uw or 1600
            maxW = math.max(380, math.min(900, uw * 0.6))
        end
        textBox:SetWidth(maxW)
        textBox.dweW = maxW
        local hw = MeasureWidth(textHeader)
        local bw = MeasureWidth(textBody)
        if hw and bw then
            textBox:SetWidth(math.max(140, math.min(maxW, math.max(hw, bw) + 4)))
        end
        if not cine and not (DialogueWheelE_TextPos and DialogueWheelE_TextPos.x) and not DWE.IsFollowingNPC() then
            textBox:ClearAllPoints()
            textBox:SetPoint("TOPRIGHT", choiceBox, "TOPLEFT", long and -230 or -125, long and 125 or 110)
            DWE.SetGripCorner(textBox, "TOPRIGHT")
        end
        local h1 = TextHeight(textHeader, 18)
        local h2 = TextHeight(textBody, 20)
        textBox:SetHeight(h1 + h2 + 16) -- la hauteur suit toujours le texte
        if cine then DWE.PlaceCinema(h1 + h2 + 16) end
        if DWE.bookMode then BookPosition() end
        textBox:Show()
    else
        textBox:Hide()
    end
    DWE.UpdateCinemaBars()
    DWE.UpdateBookBar()
    RefreshHiddenFrames()
end

choiceBox:HookScript("OnShow", function()
    ScanAddonFrames()
    DWE.UpdateTextPanelVisuals()
end)

choiceBox:HookScript("OnHide", function()
    textBox:Hide()
    -- Laisse le temps a l'animation de fermeture de Spoken de se faire sans DialogueUI.
    if (DialogueWheelE_ShowText == true or DWE.BookByAddon()) and C_Timer and C_Timer.After then
        fadeHold = true
        C_Timer.After(0.6, function()
            fadeHold = false
            RefreshHiddenFrames()
        end)
    end
    RefreshHiddenFrames()
end)

function DWE.ToggleDialogueText()
    DialogueWheelE_ShowText = not (DialogueWheelE_ShowText == true)
    if DWE.OnToggleBookView then DWE.OnToggleBookView() end
    DWE.UpdateVisuals()
end

local function Trim(s)
    if s == nil then return "" end
    if issecretvalue and issecretvalue(s) then return s end
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

function DWE.SetDialogueText(headerStr, bodyStr)
    local header, body = Trim(headerStr), Trim(bodyStr)
    local hasText = (issecretvalue and issecretvalue(body)) or body ~= ""
    DWE.hasDialogueText = hasText and true or false
    textHeader:SetText(header)
    DWE.rawHeader = header
    DWE.bookRawBody = DWE.hasDialogueText and body or L.NO_TEXT
    textBody:SetText(DWE.bookRawBody)
    if DWE.Bubble then
        DWE.Bubble.SetText(DWE.hasDialogueText and body or "")
        DWE.Bubble.PopupText(DWE.hasDialogueText and body or "")
        if DWE.BookLook() == "book" and DWE.Bubble.PopupInstant then DWE.Bubble.PopupInstant() end
    end
    DWE.ApplyTextTheme()
    DWE.UpdateTextPanelVisuals()
end

--------------------------------------------------------------------------------
-- Positions
--------------------------------------------------------------------------------

function DWE.SavePosition()
    local ok, point, _, relPoint, x, y = pcall(choiceBox.GetPoint, choiceBox)
    if ok and point then
        DialogueWheelE_Pos = { point = point, relPoint = relPoint, x = x, y = y }
        DWE.SetGripCorner(choiceBox, point)
    end
end

function DWE.RestorePosition()
    choiceBox:ClearAllPoints()
    local p = DialogueWheelE_Pos
    if p and p.x then
        choiceBox:SetPoint(p.point, UIParent, p.relPoint, p.x, p.y)
    else
        if DWE.WheelLeft() then
            choiceBox:SetPoint("TOPRIGHT", UIParent, "CENTER", -170, 80)
        else
            choiceBox:SetPoint("TOPLEFT", UIParent, "CENTER", 170, 80)
        end
    end
    DWE.SetGripCorner(choiceBox, p and p.x and p.point or (DWE.WheelLeft() and "TOPRIGHT" or "TOPLEFT"))
end

function DWE.SaveTextPosition()
    local ok, point, _, relPoint, x, y = pcall(textBox.GetPoint, textBox)
    if ok and point then
        DialogueWheelE_TextPos = { point = point, relPoint = relPoint, x = x, y = y }
        DWE.SetGripCorner(textBox, point)
    end
end

function DWE.RestoreTextPosition()
    local p = DialogueWheelE_TextPos
    if p and p.x and not DWE.IsCinema() then
        textBox:ClearAllPoints()
        textBox:SetPoint(p.point, UIParent, p.relPoint, p.x, p.y)
        DWE.SetGripCorner(textBox, p.point)
    end
end

--------------------------------------------------------------------------------
-- Suivi du PNJ (option "Attacher au PNJ")
--------------------------------------------------------------------------------
-- La roue et le popup sont ACCROCHES a la plaque de nom du PNJ (le cadre que le jeu place
-- au-dessus de sa tete) : c'est le jeu qui les deplace avec elle. L'addon ne mesure jamais la
-- position de la plaque : WoW Forever l'interdit ("Can't measure restricted regions").
-- Si le jeu refuse aussi l'accrochage, le suivi se coupe pour la session, sans erreur.
-- Si les plaques des PNJ amicaux sont desactivees (CVar nameplateShowFriendlyNPCs), on les
-- active le temps de la conversation en les rendant invisibles, puis on remet le reglage.
-- Sans plaque trouvable (livre, objet, donjon ou les plaques sont protegees), la roue reste
-- a sa place fixe.

local follower = CreateFrame("Frame")
follower:Hide()
local follow = {}
local savedPlateCVar     -- valeur du joueur a remettre, si on a active les plaques
local maskedFrames = {}  -- plaques rendues invisibles par l'addon
-- Ecarts par rapport au centre de la plaque du PNJ (unites d'UIParent). Le joueur les change
-- en deplacant la roue ou le texte au clic droit pendant le suivi (DialogueWheelE_NPCOffset).
-- Ecarts a une distance de camera de reference ; ils grandissent quand on zoome et
-- rapetissent quand on dezoome, comme le PNJ a l'ecran (voir ZoomFactor).
-- wheelY : milieu de la roue (au niveau du bras). v : version du format des ecarts.
-- Cote de la roue par rapport au PNJ (option) : droite par defaut.
function DWE.WheelLeft() return DialogueWheelE_WheelSide == "left" end
local NPC_OFFSET_DEFAULT = { wheelX = 130, wheelY = -150, textX = -45, textY = -70, bubbleX = 0, bubbleY = -5, v = 4 }
local function NPCOffset()
    local o = DialogueWheelE_NPCOffset
    if type(o) ~= "table" then return NPC_OFFSET_DEFAULT end
    if o.v ~= NPC_OFFSET_DEFAULT.v then wipe(o) end -- ecarts d'une ancienne version : on repart des defauts
    for k, v in pairs(NPC_OFFSET_DEFAULT) do
        if type(o[k]) ~= "number" then o[k] = v end
    end
    return o
end
local dragging -- deplacement en cours pendant le suivi : { which, cx, cy, ox, oy }
local followBroken = false -- le jeu a refuse l'accrochage : plus d'essai cette session
local APPEAR_DELAY = 0.3 -- attente max de la plaque avant d'afficher la roue a sa place fixe

local function AttachEnabled()
    return DialogueWheelE_AttachNPC ~= false
end

local function Check(fn, ...)
    if not fn then return false end
    local ok, res = pcall(fn, ...)
    return ok and res == true
end

local function PlateToken(plate)
    return plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
end

local function UsablePlate(plate)
    return plate and not (plate.IsForbidden and plate:IsForbidden()) and plate:IsVisible()
end

local function GetPlates()
    return C_NamePlate and C_NamePlate.GetNamePlates and C_NamePlate.GetNamePlates() or {}
end

local function FindNPCPlate()
    if not Check(UnitExists, "npc") then return nil end
    for _, plate in ipairs(GetPlates()) do
        if UsablePlate(plate) and Check(UnitIsUnit, PlateToken(plate), "npc") then return plate end
    end
end

-- Plaques activees par l'addon : on cache celles des unites amicales (on ne garde que leur
-- position). Les plaques d'ennemis ne sont jamais touchees.
local function MaskFriendlyPlates()
    if not savedPlateCVar then return end
    for _, plate in ipairs(GetPlates()) do
        local uf = plate.UnitFrame
        if uf and not (uf.IsForbidden and uf:IsForbidden()) then
            local token = PlateToken(plate)
            if token and not Check(UnitCanAttack, "player", token) then
                if uf:GetAlpha() ~= 0 then uf:SetAlpha(0) end
                maskedFrames[uf] = true
            elseif maskedFrames[uf] then
                uf:SetAlpha(1)
                maskedFrames[uf] = nil
            end
        end
    end
end

local function UnmaskPlates()
    for uf in pairs(maskedFrames) do uf:SetAlpha(1) end
    wipe(maskedFrames)
end

local function SetFriendlyPlates(on)
    if not (GetCVar and SetCVar) or InCombatLockdown() then return end
    if on then
        local cur = GetCVar("nameplateShowFriendlyNPCs")
        if cur and cur ~= "1" then
            savedPlateCVar = cur
            SetCVar("nameplateShowFriendlyNPCs", "1")
        end
    elseif savedPlateCVar then
        -- D'abord retirer les plaques, ensuite seulement leur rendre leur opacite (sinon elles
        -- reapparaissent une image avant de disparaitre).
        SetCVar("nameplateShowFriendlyNPCs", savedPlateCVar)
        savedPlateCVar = nil
        if C_Timer and C_Timer.After then
            C_Timer.After(0.2, function()
                if not savedPlateCVar then UnmaskPlates() end
            end)
        else
            UnmaskPlates()
        end
    end
end

-- Appele a la sortie de combat si le reglage n'a pas pu etre remis pendant le combat.
function DWE.RestoreNameplateCVar()
    if not choiceBox:IsShown() then SetFriendlyPlates(false) end
end

function DWE.IsFollowingNPC()
    return follow.plate ~= nil
end

local function Reveal()
    if follow.revealed then return end
    -- Laisse passer quelques images apres l'ouverture : les polices sont pretes, la roue est
    -- remise en page (largeurs, barre de defilement) avant d'apparaitre, sans sursaut visible.
    if (follow.wait or 0) < 0.05 then return end
    follow.revealed = true
    if DWE.choiceBox:IsShown() then DWE.UpdateVisuals() end
    choiceBox:SetAlpha(1)
    textBox:SetAlpha(1)
    if DWE.bubble then DWE.bubble:SetAlpha(1) end
end

local function RestoreFixed()
    if DWE.Bubble then DWE.Bubble.Pin(nil) end
    choiceBox:ClearAllPoints()
    DWE.RestorePosition()
    textBox:ClearAllPoints()
    DWE.RestoreTextPosition()
    DWE.UpdateTextPanelVisuals()
end

-- Zoom de la camera : la plaque est a une hauteur fixe au-dessus du PNJ dans le monde, donc
-- a l'ecran tous les ecarts (plaque -> bras, plaque -> tete) varient comme 1 / distance.
local ZOOM_REF, ZOOM_PAD = 9, 2.5 -- distance de reference ; ecart camera-joueur-PNJ ajoute au zoom
local function ZoomFactor()
    if not GetCameraZoom then return 1 end
    local ok, z = pcall(GetCameraZoom)
    if not ok or type(z) ~= "number" then return 1 end
    local raw = math.max(0.45, math.min(2.4, ZOOM_REF / (z + ZOOM_PAD)))
    -- Lisse : le zoom de la camera arrive par a-coups ; sans lissage la roue tressaute.
    local now = GetTime and GetTime() or 0
    local zs = follow.zs
    if not zs or math.abs(raw - zs.v) > 0.8 then
        follow.zs = { v = raw, t = now }
        return raw
    end
    local dt = now - zs.t
    if dt > 0 then
        zs.v = zs.v + (raw - zs.v) * (1 - math.exp(-dt / 0.15))
        zs.t = now
        if math.abs(raw - zs.v) < 0.002 then zs.v = raw end
    end
    return zs.v
end

-- Taille du PNJ : son modele est charge dans une scene invisible pour lire sa hauteur
-- (boite englobante). Un PNJ petit (gobelin, gnome) rapproche la roue et le texte et les
-- rend plus petits ; un grand les eloigne. Si le jeu ne le permet pas : taille normale.
-- Hauteur de reference (boite du modele d'un humain, garde de Hurlevent ~5,5 dans les unites
-- de la scene de modele ; mesure faite en jeu).
local REF_HEIGHT = 5.5
local SMALL_HEIGHT, SMALL_FACTOR = 4.3, 0.55
local sizer = {}

local function BoxHeight(actor)
    for _, fn in ipairs({ "GetMaxBoundingBox", "GetActiveBoundingBox" }) do
        if actor[fn] then
            local ok, a, b, c, d, e, f = pcall(actor[fn], actor)
            if ok then
                if type(a) == "number" and type(f) == "number" then return f - c end
                if type(a) == "table" and type(b) == "table" and a.z and b.z then return b.z - a.z end
            end
        end
    end
end

local function StartMeasure()
    sizer.height, sizer.wait = nil, 0
    if sizer.broken then return end
    if not sizer.actor then
        local ok, scene = pcall(CreateFrame, "ModelScene", nil, UIParent)
        if not ok or type(scene) ~= "table" or not scene.CreateActor then sizer.broken = true return end
        scene:SetSize(64, 64)
        scene:SetPoint("TOPLEFT", UIParent, "BOTTOMRIGHT", 200, -200) -- hors de l'ecran
        local okA, actor = pcall(scene.CreateActor, scene)
        if not okA or type(actor) ~= "table" or not actor.SetModelByUnit then sizer.broken = true return end
        sizer.scene, sizer.actor = scene, actor
    end
    sizer.scene:Show()
    if not pcall(sizer.actor.SetModelByUnit, sizer.actor, "npc") then sizer.broken = true end
end

-- Appele a chaque image pendant le suivi : lit la hauteur des que le modele est charge.
local function PollMeasure(elapsed)
    if sizer.height or sizer.broken or not sizer.actor then return end
    sizer.wait = (sizer.wait or 0) + elapsed
    local h = BoxHeight(sizer.actor)
    if h and h > 0.2 and h < 60 then
        sizer.height = h
        if sizer.scene then sizer.scene:Hide() end
        return true
    end
    if sizer.wait > 2 then -- modele jamais lu : taille normale
        sizer.height = REF_HEIGHT
        if sizer.scene then sizer.scene:Hide() end
    end
end

-- Facteur de taille du PNJ (1 = humain).
local function SizeFactor()
    local h = sizer.height
    if not h then return 1 end
    -- Mesures en jeu : humain ~5,5, nain ~4,1, gnome ~4,3. La boite du modele ne suit pas
    -- la vraie taille sous l'humain (gnome et nain mesurent presque pareil) : tout ce qui
    -- mesure 4,3 ou moins est traite comme "petit", entre les deux on interpole.
    if h >= REF_HEIGHT then return math.min(1.6, h / REF_HEIGHT) end
    if h <= SMALL_HEIGHT then return SMALL_FACTOR end
    return SMALL_FACTOR + (1 - SMALL_FACTOR) * (h - SMALL_HEIGHT) / (REF_HEIGHT - SMALL_HEIGHT)
end
DWE.NPCSizeFactor = SizeFactor
function DWE.NPCHeight() return sizer.height end

-- Echelle de l'interface pour ce PNJ : plus petite pour un petit PNJ.
local function UIScaleFor(sf)
    return math.max(0.75, math.min(1.1, 0.55 + 0.45 * sf))
end

local function SetFrameScales(sc)
    for _, fr in ipairs({ choiceBox, textBox, DWE.bubble }) do
        if fr and fr:GetScale() ~= sc then fr:SetScale(sc) end
    end
end

-- Les ecarts sont en unites d'UIParent : multiplies par le facteur de zoom et de taille du
-- PNJ, divises par l'echelle de chaque cadre.
local function AnchorTo(plate)
    local o = NPCOffset()
    local sf = SizeFactor()
    local f = ZoomFactor()
    follow.zoomF, follow.sizeF = f, sf
    local k = f * sf
    -- Bulle un tout petit peu plus bas que la plaque (ecart fixe a l'ecran, pas multiplie par
    -- le zoom : camera proche, elle ne descend pas sur le visage), et un peu plus en dezoomant,
    -- ou la plaque flotte plus haut au-dessus de la tete.
    local closeDrop = 6 + 25 * math.max(0, 1 - f)
    SetFrameScales(UIScaleFor(sf))
    local ws, ts = choiceBox:GetScale() or 1, textBox:GetScale() or 1
    local bs = DWE.bubble and DWE.bubble:GetScale() or 1

    -- Milieu de la roue au niveau du bras ; avec la bulle, la roue reste sous la bulle si elles
    -- se touchent sur le cote (la bulle grandit vers le haut, son bas ne bouge pas).
    local wy = o.wheelY * k
    if DWE.bubble and DWE.bubble:IsShown() and DWE.BubbleMaxWidth then
        local bubbleRight = o.bubbleX * k + DWE.BubbleMaxWidth() * bs / 2
        if bubbleRight > o.wheelX * k - 4 then
            local okH, wh = pcall(choiceBox.GetHeight, choiceBox)
            wh = (okH and type(wh) == "number") and wh * ws or 0
            wy = math.min(wy, o.bubbleY * k - closeDrop - 10 - wh / 2)
        end
    end
    -- Roue a gauche : tout est en miroir (roue a gauche, texte a droite du PNJ).
    local m = DWE.WheelLeft() and -1 or 1
    choiceBox:ClearAllPoints()
    choiceBox:SetPoint(m == 1 and "LEFT" or "RIGHT", plate, "CENTER", m * o.wheelX * k / ws, wy / ws)
    if not DWE.IsCinema() then
        local tp = m == 1 and "BOTTOMRIGHT" or "BOTTOMLEFT"
        textBox:ClearAllPoints()
        textBox:SetPoint(tp, plate, "CENTER", m * o.textX * k / ts, (o.textY * k - closeDrop) / ts)
        DWE.SetGripCorner(textBox, tp)
    end
    DWE.SetGripCorner(choiceBox, m == 1 and "TOPLEFT" or "TOPRIGHT")
    if DWE.Bubble then DWE.Bubble.Pin(plate, m * o.bubbleX * k / bs, (o.bubbleY * k - closeDrop) / bs) end
end

local function Unpin()
    if not follow.plate then return end
    follow.plate = nil
    SetFrameScales(1)
    RestoreFixed()
end

follower:SetScript("OnEvent", function() pcall(MaskFriendlyPlates) end)

local function CursorUI()
    local x, y = GetCursorPosition()
    local ui = UIParent:GetEffectiveScale()
    return x / ui, y / ui
end

-- Clic droit maintenu sur la roue ou le texte. Pendant le suivi : on change l'ecart par
-- rapport au PNJ (d'apres le deplacement de la souris, sans rien mesurer) et ils restent
-- accroches. Sinon : deplacement classique de la position fixe.
-- Un clic qui termine un deplacement ne doit pas choisir une option ni avancer la bulle.
function DWE.JustDragged()
    return DWE.dragActive or (GetTime and DWE.dragEndT and GetTime() - DWE.dragEndT < 0.25) or false
end

function DWE.DragStart(which)
    if DWE.IsLocked() then return end
    DWE.dragActive = true
    if follow.plate and not (DWE.bookMode and which == "text") then
        local o = NPCOffset()
        local cx, cy = CursorUI()
        dragging = { which = which, cx = cx, cy = cy, ox = o[which .. "X"], oy = o[which .. "Y"] }
        return
    end
    local frame = (which == "wheel") and choiceBox or textBox
    frame.dweMoving = pcall(frame.StartMoving, frame)
end

function DWE.DragStop(which)
    DWE.dragActive = nil
    DWE.dragEndT = GetTime and GetTime() or 0
    if dragging and dragging.which == which then
        dragging = nil
        return
    end
    local frame = (which == "wheel") and choiceBox or textBox
    if not frame.dweMoving then return end
    frame.dweMoving = nil
    pcall(frame.StopMovingOrSizing, frame)
    if frame == textBox and DWE.bookMode then
        -- Livre : sa propre position, separee de celle du texte des PNJ.
        local ok, point, _, relPoint, x, y = pcall(textBox.GetPoint, textBox)
        if ok and point then DialogueWheelE_BookPos = { point = point, relPoint = relPoint, x = x, y = y } end
    elseif frame == textBox then DWE.SaveTextPosition() else DWE.SavePosition() end
end

local function UpdateDrag()
    if not (dragging and follow.plate) then dragging = nil return end
    local cx, cy = CursorUI()
    if type(DialogueWheelE_NPCOffset) ~= "table" then DialogueWheelE_NPCOffset = {} end
    local o = DialogueWheelE_NPCOffset
    NPCOffset()
    local k = (follow.zoomF or 1) * (follow.sizeF or 1)
    local m = DWE.WheelLeft() and -1 or 1
    o[dragging.which .. "X"] = dragging.ox + m * (cx - dragging.cx) / k
    o[dragging.which .. "Y"] = dragging.oy + (cy - dragging.cy) / k
    pcall(AnchorTo, follow.plate)
end

-- Re-accroche apres un changement de taille (les ecarts dependent de l'echelle).
function DWE.Repin()
    if follow.plate then pcall(AnchorTo, follow.plate) end
end

-- Bouton des options : remet les ecarts et les tailles par defaut.
function DWE.ResetNPCOffset()
    DialogueWheelE_NPCOffset = nil
    DialogueWheelE_BookPos = nil
    DialogueWheelE_BookScale, DialogueWheelE_NoteScale = nil, nil
    DialogueWheelE_TextW, DialogueWheelE_TextH = nil, nil
    DialogueWheelE_WheelWidth, DialogueWheelE_BubbleWidth = nil, nil
    DWE.ApplyScale()
    if choiceBox:IsShown() then DWE.UpdateVisuals() end
    if DWE.Bubble then DWE.Bubble.Refit() end
end

--------------------------------------------------------------------------------
-- Poignees de redimensionnement et verrouillage
--------------------------------------------------------------------------------
-- La poignee est toujours dans le coin bas-droit. Clic gauche maintenu et glisser : vers la
-- droite = plus large, vers le bas = plus haut. Rien n'est mesure (compatible avec
-- l'accrochage au PNJ) : seul le deplacement de la souris compte, ajoute a la taille connue.

function DWE.IsLocked()
    return DialogueWheelE_Locked == true
end

local grips = {}

-- Place la poignee. `anchorPoint` : point d'accroche du cadre. Accroche par le milieu (bulle
-- au-dessus de la tete), le cadre grandit des deux cotes : la souris compte double.
function DWE.SetGripCorner(frame, anchorPoint)
    local g = frame.dweGrip
    if not g then return end
    g.both = (anchorPoint == "TOP" or anchorPoint == "BOTTOM" or anchorPoint == "CENTER")
    g:ClearAllPoints()
    -- Coin visible : celui du dessin s'il depasse du cadre (marges du theme, page de la note).
    local ox, oy = frame.dweGripX or 8, frame.dweGripY or 8
    g:SetPoint("BOTTOMRIGHT", frame.dweGripAnchor or frame, "BOTTOMRIGHT", ox - 6, -(oy - 6))
    g.dweNoGrip = frame.dweNoGrip
    if frame.dweNoGrip then g:Hide() elseif not DWE.IsLocked() then g:Show() end
end

function DWE.ApplyLock()
    for _, g in ipairs(grips) do g:SetShown(not DWE.IsLocked() and not g.dweNoGrip) end
end

-- Poignee invisible ; visible seulement quand la souris est sur son cadre (ou sur la poignee).
local function GripAlpha(g)
    if g.hover or g.resize then return 1 end
    local f = g:GetParent()
    -- Toujours un peu visible (sinon on ne sait pas qu'on peut redimensionner), plus au survol.
    return (f and f.dweHover) and 1 or 0.55
end
local function RefreshGrip(frame)
    local g = frame and frame.dweGrip
    if g then
        g:SetAlpha(GripAlpha(g))
        -- Survol de la fenetre : triangle bleu brillant, bien visible.
        local hot = g.hover or g.resize or (frame.dweHover and true)
        local t = g:GetNormalTexture()
        if t then
            if hot then t:SetVertexColor(0.35, 0.8, 1) else t:SetVertexColor(1, 1, 1) end
            t:SetBlendMode(hot and "ADD" or "BLEND")
        end
    end
end
-- A appeler sur OnEnter / OnLeave du cadre et de ses lignes (passer d'un cadre a une de ses
-- lignes declenche OnLeave puis OnEnter : la mise a jour est donc legerement differee).
function DWE.SetFrameHover(frame, on)
    frame.dweHover = on and true or nil
    if on or not (C_Timer and C_Timer.After) then RefreshGrip(frame) return end
    C_Timer.After(0.05, function() RefreshGrip(frame) end)
end

local function ResizeStep(grip)
    local r = grip.resize
    if not r then return end
    local x, y = CursorUI()
    local dx, dy = x - r.x, y - r.y
    r.spec.set(r.w + (grip.both and 2 or 1) * dx, r.h - dy)
end

-- spec = { get = function() return largeur, hauteur end, set = function(l, h) end }
function DWE.MakeResizeGrip(frame, spec)
    local g = CreateFrame("Button", nil, frame)
    frame.dweGrip = g
    grips[#grips + 1] = g
    g.dweIsGrip = true
    g:SetSize(20, 20)
    g:SetFrameLevel(frame:GetFrameLevel() + 20)
    g:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    g:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    g:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    g:SetAlpha(0.55)
    -- Survol suivi par OnEnter/OnLeave : IsMouseOver est interdit quand le cadre est
    -- accroche a une plaque de nom.
    g:SetScript("OnEnter", function(self) self.hover = true; self:SetAlpha(1) end)
    g:SetScript("OnLeave", function(self)
        self.hover = false
        self:SetAlpha(GripAlpha(self))
    end)
    if frame.HookScript then
        frame:HookScript("OnEnter", function() DWE.SetFrameHover(frame, true) end)
        frame:HookScript("OnLeave", function() DWE.SetFrameHover(frame, false) end)
    end
    g:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" or DWE.IsLocked() then return end
        local x, y = CursorUI()
        local w, h = spec.get()
        self.resize = { spec = spec, x = x, y = y, w = w or 0, h = h or 0 }
        self:SetScript("OnUpdate", ResizeStep)
    end)
    g:SetScript("OnMouseUp", function(self)
        if self.resize and spec.done then pcall(spec.done) end
        self.resize = nil
        self:SetScript("OnUpdate", nil)
        self:SetAlpha(GripAlpha(self))
    end)
    DWE.SetGripCorner(frame, "TOPLEFT")
    return g
end

local function Clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

-- Roue : largeur libre (la hauteur suit le nombre de choix).
DWE.MakeResizeGrip(choiceBox, {
    get = function()
        local ok, w = pcall(choiceBox.GetWidth, choiceBox)
        return (ok and type(w) == "number" and w > 0) and w or DWE.WheelWidth(), 0
    end,
    set = function(w)
        DialogueWheelE_WheelWidth = math.floor(Clamp(w, 160, 900))
        DWE.UpdateVisuals()
    end,
})
-- Popup : largeur max (ou le texte passe a la ligne) ; la hauteur suit toujours le texte.
DWE.MakeResizeGrip(textBox, {
    get = function()
        if textBox.dweBook == true then return BOOK_W * DWE.BookScaleWanted(), 0 end
        if textBox.dweBook == "note" then return NOTE_W * DWE.NoteScale(), 0 end
        return textBox.dweW or 380, 0
    end,
    done = function()
        if textBox.dweBook == true or textBox.dweBook == "note" then
            DWE.bookRelayoutT = nil; DWE.UpdateTextPanelVisuals()
        end
    end,
    set = function(w)
        if textBox.dweBook == "note" then
            DialogueWheelE_NoteScale = math.floor(Clamp(w / NOTE_W, 0.6, 2) * 100 + 0.5) / 100
            DWE.SetBookScale(DialogueWheelE_NoteScale, true)
            DWE.SetGripCorner(textBox, "BOTTOMRIGHT")
            local now = GetTime and GetTime() or 0
            if not DWE.bookRelayoutT or now - DWE.bookRelayoutT > 0.1 then
                DWE.bookRelayoutT = now
                DWE.UpdateTextPanelVisuals()
            end
            return
        end
        if textBox.dweBook == true then
            DialogueWheelE_BookScale = math.floor(Clamp(w / BOOK_W, 0.5, 2) * 100 + 0.5) / 100
            DWE.SetBookScale(DialogueWheelE_BookScale, true)
            DWE.SetGripCorner(textBox, "BOTTOMRIGHT")
            -- Texte remis en page pendant le glisser (au plus 10 fois par seconde), puis au lacher.
            local now = GetTime and GetTime() or 0
            if not DWE.bookRelayoutT or now - DWE.bookRelayoutT > 0.1 then
                DWE.bookRelayoutT = now
                DWE.UpdateTextPanelVisuals()
            end
            return
        end
        DialogueWheelE_TextW = math.floor(Clamp(w, 160, 1200))
        DialogueWheelE_TextH = nil
        DWE.UpdateTextPanelVisuals()
    end,
})

-- Les plaques ne sont relues que quelques fois par seconde (pas a chaque image : parcourir
-- toutes les plaques en ville a chaque image fait ramer). Une fois accrochee, la roue suit
-- la plaque d'elle-meme ; une nouvelle plaque est masquee par l'evenement NAME_PLATE_UNIT_ADDED.
local SCAN_FAST, SCAN_SLOW = 0.03, 0.15

follower:SetScript("OnUpdate", DWE.Prof("suivi du PNJ", function(_, elapsed)
    local measured = PollMeasure(elapsed)
    if dragging then
        UpdateDrag()
    elseif follow.plate and (measured or math.abs(ZoomFactor() - (follow.zoomF or 1)) > 0.003) then
        pcall(AnchorTo, follow.plate) -- zoom en cours ou taille du PNJ connue : on suit
    end
    follow.wait = (follow.wait or 0) + elapsed
    if follow.plate and not follow.revealed then Reveal() end
    follow.scan = (follow.scan or 0) + elapsed
    if follow.scan < ((follow.plate or follow.revealed) and SCAN_SLOW or SCAN_FAST) then return end
    follow.scan = 0
    pcall(MaskFriendlyPlates)
    if followBroken then Reveal() return end

    local okFind, plate = pcall(FindNPCPlate)
    plate = okFind and plate or nil
    if plate then
        -- On attend un instant la taille du PNJ pour ne pas changer d'echelle sous les yeux.
        if not sizer.height and not sizer.broken and follow.wait < APPEAR_DELAY then return end
        if follow.plate ~= plate then
            if pcall(AnchorTo, plate) then
                follow.plate = plate
            else
                followBroken = true
                follow.plate = nil
                RestoreFixed()
            end
        end
        Reveal()
    else
        Unpin() -- plaque perdue (PNJ hors champ...) : retour a la place fixe
        if follow.wait > APPEAR_DELAY then Reveal() end
    end
end))

local function StartFollow()
    if not AttachEnabled() or followBroken or follower:IsShown() then return end
    follow = {}
    -- Invisible le temps que la plaque apparaisse (1 ou 2 images), pour ne pas sauter.
    choiceBox:SetAlpha(0)
    textBox:SetAlpha(0)
    if DWE.bubble then DWE.bubble:SetAlpha(0) end
    -- Une plaque creee se cache aussitot (avant d'etre dessinee), pas a l'image suivante.
    follower:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    pcall(StartMeasure)
    SetFriendlyPlates(true)
    pcall(MaskFriendlyPlates)
    follower:Show()
end

local function StopFollow()
    if not follower:IsShown() then return end
    follower:Hide()
    dragging = nil
    local wasPinned = follow.plate ~= nil
    follow = {}
    choiceBox:SetAlpha(1)
    textBox:SetAlpha(1)
    if DWE.bubble then DWE.bubble:SetAlpha(1) end
    SetFrameScales(1)
    if sizer.scene then sizer.scene:Hide() end
    if wasPinned then RestoreFixed() end -- avant de retirer les plaques
    follower:UnregisterEvent("NAME_PLATE_UNIT_ADDED")
    if savedPlateCVar then SetFriendlyPlates(false) else UnmaskPlates() end
end
DWE.StopFollow = StopFollow

choiceBox:HookScript("OnShow", StartFollow)
choiceBox:HookScript("OnHide", StopFollow)

--------------------------------------------------------------------------------
-- Roue de choix
--------------------------------------------------------------------------------

function DWE.CloseAllDialogue()
    if C_GossipInfo and C_GossipInfo.CloseGossip then
        C_GossipInfo.CloseGossip()
    elseif CloseGossip then
        CloseGossip()
    end
    if CloseQuest then CloseQuest() end
    if CloseItemText then CloseItemText() end
end

function DWE.StepSelection(delta)
    local total = #DWE.currentOptions
    if total == 0 then return end
    local idx = DWE.selectedIndex
    for _ = 1, total do
        idx = idx + delta
        if idx < 1 then idx = total end
        if idx > total then idx = 1 end
        local opt = DWE.currentOptions[idx]
        if opt and not opt.disabled then
            DWE.selectedIndex = idx
            DWE.UpdateVisuals()
            return
        end
    end
end

-- Molette avec "elan" : des crans rapides et rapproches (molette libre, geste vif) font
-- avancer de plus en plus loin, jusqu'au bout de la liste. Pas de retour au debut pendant
-- un elan : on s'arrete au premier / dernier choix.
DWE.wheelMo = { t = 0, dir = 0, streak = 0 }
function DWE.WheelStep(delta)
    local total = #DWE.currentOptions
    if total == 0 then return end
    local now = GetTime and GetTime() or 0
    local gap = now - DWE.wheelMo.t
    if delta == DWE.wheelMo.dir and gap < 0.09 then
        DWE.wheelMo.streak = DWE.wheelMo.streak + 1
    else
        DWE.wheelMo.streak = 0
    end
    DWE.wheelMo.t, DWE.wheelMo.dir = now, delta
    -- La roue glisse sous la souris immobile : le choix survole ne doit pas voler la selection.
    local cx, cy = GetCursorPosition()
    DWE.wheelCursor = { cx, cy }
    -- Au bout de la liste, on ne repart a l'autre bout qu'avec un cran voulu : un premier cran
    -- "bute", et seul un nouveau cran, apres une petite pause (et avant 2 s), fait le tour.
    local atEnd = true
    for i = DWE.selectedIndex + delta, (delta > 0) and total or 1, delta do
        local opt = DWE.currentOptions[i]
        if opt and not opt.disabled then atEnd = false break end
    end
    if atEnd then
        local b = DWE.wheelMo.bump
        if b and b.dir == delta and gap > 0.3 and now - b.t < 2 and DWE.wheelMo.streak == 0 then
            DWE.wheelMo.bump = nil
            return DWE.StepSelection(delta)
        end
        if not (b and b.dir == delta and now - b.t < 2) then DWE.wheelMo.bump = { dir = delta, t = now } end
        return
    end
    DWE.wheelMo.bump = nil
    if DWE.wheelMo.streak == 0 then return DWE.StepSelection(delta) end
    local steps = (DWE.wheelMo.streak >= 8) and total or math.min(4, 1 + math.floor(DWE.wheelMo.streak / 2))
    local idx, last = DWE.selectedIndex, DWE.selectedIndex
    for _ = 1, steps do
        idx = idx + delta
        if idx < 1 or idx > total then break end
        local opt = DWE.currentOptions[idx]
        if opt and not opt.disabled then last = idx end
    end
    if last ~= DWE.selectedIndex then
        DWE.selectedIndex = last
        DWE.UpdateVisuals()
    end
end
-- Vrai si la souris n'a pas bouge depuis le dernier cran de molette.
function DWE.CursorStill()
    local w = DWE.wheelCursor
    if not w then return false end
    local cx, cy = GetCursorPosition()
    if math.abs(cx - w[1]) < 2 and math.abs(cy - w[2]) < 2 then return true end
    DWE.wheelCursor = nil
    return false
end

local optionRows = {}

-- Marges du texte d'un choix : normales, ou a l'interieur d'une bulle de choix.
local ROW_PAD = { left = 2, iconLeft = 24, top = 3, right = 2, iconTop = 4 }
local PILL_PAD = { left = 16, iconLeft = 38, top = 10, right = 16, iconTop = 11 }

local function MeasureTextWidth(fs)
    local fn = fs.GetUnboundedStringWidth or fs.GetStringWidth
    local ok, w = pcall(fn, fs)
    return (ok and type(w) == "number") and w or nil
end

-- Fonds des choix "bulle" : tous de la meme largeur, sobres ; le choix surligne a un
-- contour dore lumineux (dans l'esprit d'Immersion).
local PILL_TEX = {
    game = { normal = "PillDark", selected = "PillDarkSel" },
    fantasy = { normal = "PillFantasy", selected = "PillFantasySel" },
    whisper = { normal = "PillWhisper", selected = "PillWhisperSel" },
}
for _, sk in pairs(BUBBLE_SKINS) do
    if sk.art then PILL_TEX[sk.pill] = { normal = "Pill" .. sk.art, selected = "Pill" .. sk.art .. "Sel" } end
end

-- Habille un cadre en bulle. L'encoche fait partie de l'image de la bulle (meme contour,
-- raccord arrondi) ; l'image deborde du cadre a gauche (et en bas pour l'encoche du bas).
--  * tail = nil : choix de la roue (ce que dit le personnage) : encoche en bas a gauche,
--    tournee vers le personnage du joueur ;
--  * tail = nombre : apercu de quete (ce que donne le PNJ) : encoche a gauche, vers le PNJ ;
--  * tail = false : pas d'encoche.
local TAIL_W, TAIL_H = 12, 9
local PILL_SHAPES = {
    none = { suffix = "", slice = { 12, 12, 12, 12 }, left = 0, bottom = 0 },
    down = { suffix = "TailDown", slice = { 26, 14, 14, 23 }, left = TAIL_W, bottom = TAIL_H },
    left = { suffix = "Tail", slice = { 26, 34, 14, 14 }, left = TAIL_W, bottom = 0 },
}
local function SkinPill(frame, style, selected, tail)
    if not frame.dweTex then
        frame.dweTex = frame:CreateTexture(nil, "BACKGROUND")
    end
    local shapeId = (tail == false and "none") or (tail and "left") or "down"
    local shape = PILL_SHAPES[shapeId]
    -- Roue a gauche du PNJ : encoches tournees vers la droite (images en miroir, suffixe R).
    local mirror = shapeId ~= "none" and DWE.WheelLeft()
    local name = PILL_TEX[style][selected and "selected" or "normal"] .. shape.suffix .. (mirror and "R" or "")
    local t = frame.dweTex
    if frame.dweTexPath ~= name then
        frame.dweTexPath = name
        t:SetTexture(ADDON_PATH .. name .. ".png")
        if t.SetTextureSliceMargins then
            local sl = shape.slice
            if mirror then
                pcall(t.SetTextureSliceMargins, t, sl[3], sl[2], sl[1], sl[4])
            else
                pcall(t.SetTextureSliceMargins, t, unpack(sl))
            end
            if t.SetTextureSliceMode then pcall(t.SetTextureSliceMode, t, 0) end
        end
    end
    local shapeKey = shapeId .. (mirror and "R" or "")
    if frame.dweShape ~= shapeKey then
        frame.dweShape = shapeKey
        t:ClearAllPoints()
        if mirror then
            t:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
            t:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", shape.left, -shape.bottom)
        else
            t:SetPoint("TOPLEFT", frame, "TOPLEFT", -shape.left, 0)
            t:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, -shape.bottom)
        end
    end
    t:Show()
end

-- Police des choix et de l'apercu : celle des options avec la bulle fantasy, celle du jeu
-- sinon (comme avant).
local function ApplyWheelFont(fs, defaultObject, size, forceSize)
    local key = "default"
    local sk = DWE.WheelPillStyle() and DWE.BubbleSkin()
    if sk and sk.optFont then
        key = FontPath(DWE.ThemeFontId()) .. size
    elseif forceSize then
        key = "obj" .. size
    end
    if fs.dweFontKey == key then return end
    if key == "default" then
        if fs.dweFontKey then fs:SetFontObject(defaultObject) end
    elseif sk and sk.optFont then
        SafeSetFont(fs, FontPath(DWE.ThemeFontId()), size)
    else
        local path, _, flags = defaultObject:GetFont()
        SafeSetFont(fs, path or STANDARD_TEXT_FONT, size, flags)
    end
    fs.dweFontKey = key
end
-- Taille des choix de la roue (option) ; sans reglage, la police du jeu comme avant.
function DWE.ChoiceSize() return tonumber(DialogueWheelE_ChoiceSize) or 15 end
function DWE.ChoiceFont(fs)
    local cs = tonumber(DialogueWheelE_ChoiceSize)
    ApplyWheelFont(fs, GameFontNormalLarge, cs or 15, cs ~= nil)
end
DWE.ApplyWheelFont = ApplyWheelFont
DWE.SkinPill = SkinPill

local AUTO_WHEEL_MIN, AUTO_WHEEL_MAX = 200, 360
DWE.WHEEL_SLACK = 80 -- marge max a droite du plus long choix quand on agrandit la roue

-- Largeur de la roue : celle choisie a la poignee, sinon calculee sur les choix affiches.
function DWE.WheelWidth()
    return tonumber(DialogueWheelE_WheelWidth) or DWE.autoWheelWidth or AUTO_WHEEL_MAX
end

local function PaintRow(row, opt, selected, pillWidth)
    local pill = DWE.WheelPillStyle()
    local pad = pill and PILL_PAD or ROW_PAD
    if opt.icon then
        row.icon:SetTexture(opt.icon)
        row.icon:ClearAllPoints()
        row.icon:SetPoint("TOPLEFT", row, "TOPLEFT", pad.left, -pad.iconTop)
        row.icon:Show()
        row.text:SetPoint("TOPLEFT", row, "TOPLEFT", pad.iconLeft, -pad.top)
    else
        row.icon:Hide()
        row.text:SetPoint("TOPLEFT", row, "TOPLEFT", pad.left, -pad.top)
    end
    row.text:SetPoint("TOPRIGHT", row, "TOPRIGHT", -pad.right, -pad.top)
    row.text:SetText(opt.rawLabel)

    -- Bulle du choix : ajustee a son texte, pleine pour le choix surligne.
    if pill then
        if not row.pill then
            row.pill = CreateFrame("Frame", nil, row, "BackdropTemplate")
            row.pill:SetFrameLevel(math.max(0, row:GetFrameLevel() - 1))
            row.pill:EnableMouse(false)
        end
        SkinPill(row.pill, pill, selected)
        row.pill:ClearAllPoints()
        row.pill:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        row.pill:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
        row.pill:SetWidth(pillWidth or (DWE.WheelWidth() - 8))
        row.pill:Show()
        -- Le texte s'arrete au bord de la bulle (largeur connue tout de suite, mesure juste).
        row.text:SetPoint("TOPRIGHT", row.pill, "TOPRIGHT", -pad.right, -pad.top)
    elseif row.pill then
        row.pill:Hide()
    end

    local pal = DWE.WheelPalette()
    local dimToggle = opt.isDialogueToggle and DialogueWheelE_ShowText ~= true
    local color
    if opt.disabled then
        color = pal.disabled
        row.icon:SetDesaturated(true)
    elseif selected then
        color = opt.isGoodbye and pal.goodbyeSel or pal.selected
        row.icon:SetDesaturated(false)
    else
        if opt.isGoodbye then
            color = pal.goodbye
        elseif dimToggle then
            color = pal.dim
        else
            color = pal.normal
        end
        row.icon:SetDesaturated(dimToggle)
    end
    row.text:SetTextColor(color[1], color[2], color[3])
    row.text:SetShadowOffset(pal.shadow, -pal.shadow)
    DWE.ChoiceFont(row.text)
end

local MAX_VISIBLE = 7
local function ScrollArrow(up)
    local t = choiceBox:CreateTexture(nil, "OVERLAY")
    t:SetSize(16, 16)
    t:SetTexture(up and "Interface\\Buttons\\Arrow-Up-Up" or "Interface\\Buttons\\Arrow-Down-Up")
    t:SetPoint(up and "TOP" or "BOTTOM", choiceBox, up and "TOP" or "BOTTOM", 0, up and 2 or 4)
    t:SetAlpha(0.85)
    t:Hide()
    return t
end
local scrollUp, scrollDown = ScrollArrow(true), ScrollArrow(false)

-- Liste defilante : les choix sont dans un cadre qui coupe ce qui depasse, et la position de
-- defilement (en pixels) glisse en douceur vers sa cible au lieu d'avancer par crans.
local LIST_PAD = 16 -- place a gauche pour les encoches des bulles
local listClip = CreateFrame("Frame", nil, choiceBox)
pcall(listClip.SetClipsChildren, listClip, true)
local scroll = { px = 0, target = 0, max = 0, view = 0, tops = {}, heights = {}, active = false }

-- Barre arrondie : deux demi-disques et un rectangle, colores ensemble (meme API que SetColorTexture).
function DWE.RoundBar(owner, layer)
    local w = 6
    local top = owner:CreateTexture(nil, layer)
    top:SetTexture(ADDON_PATH .. "ScrollCap.png"); top:SetTexCoord(0, 1, 0, 0.5)
    top:SetPoint("TOPLEFT"); top:SetPoint("TOPRIGHT"); top:SetHeight(w / 2)
    local bot = owner:CreateTexture(nil, layer)
    bot:SetTexture(ADDON_PATH .. "ScrollCap.png"); bot:SetTexCoord(0, 1, 0.5, 1)
    bot:SetPoint("BOTTOMLEFT"); bot:SetPoint("BOTTOMRIGHT"); bot:SetHeight(w / 2)
    local mid = owner:CreateTexture(nil, layer)
    mid:SetTexture(ADDON_PATH .. "ScrollCap.png"); mid:SetTexCoord(0.25, 0.75, 0.45, 0.55)
    mid:SetPoint("TOPLEFT", top, "BOTTOMLEFT"); mid:SetPoint("BOTTOMRIGHT", bot, "TOPRIGHT")
    return { parts = { top, mid, bot }, SetColorTexture = function(self, r, g, b, a)
        for _, t in ipairs(self.parts) do t:SetVertexColor(r, g, b); t:SetAlpha(a or 1) end
    end }
end

local scrollTrack = CreateFrame("Frame", nil, choiceBox)
scrollTrack:SetWidth(6)
scrollTrack:SetPoint("TOPRIGHT", choiceBox, "TOPRIGHT", -3, -20)
scrollTrack:SetPoint("BOTTOMRIGHT", choiceBox, "BOTTOMRIGHT", -3, 20)
scrollTrack.bg = DWE.RoundBar(scrollTrack, "BACKGROUND")
scrollTrack.bg:SetColorTexture(1, 1, 1, 0.10)
scrollTrack:Hide()

local scrollThumb = CreateFrame("Button", nil, scrollTrack)
scrollThumb:SetWidth(6)
scrollThumb.tex = DWE.RoundBar(scrollThumb, "ARTWORK")
scrollThumb.tex:SetColorTexture(1, 0.82, 0.3, 0.75)
scrollThumb:SetHitRectInsets(-6, -6, 0, 0)
scrollThumb:RegisterForClicks("LeftButtonUp")

local function TrackSizes()
    local okH, h = pcall(scrollTrack.GetHeight, scrollTrack)
    h = (okH and type(h) == "number" and h > 0) and h or 100
    local th = math.max(14, h * scroll.view / math.max(scroll.view, scroll.view + scroll.max))
    return h, th
end

local function PositionRows()
    for i, row in ipairs(optionRows) do
        local top, h = scroll.tops[i], scroll.heights[i]
        if top and DWE.currentOptions[i] then
            local y = -(top - scroll.px)
            row:ClearAllPoints()
            -- Roue a gauche du PNJ : encoches a droite et barre de defilement a gauche (miroir).
            local barGap = scroll.active and 14 or 4
            if DWE.WheelLeft() then
                row:SetPoint("TOPLEFT", listClip, "TOPLEFT", barGap, y)
                row:SetPoint("TOPRIGHT", listClip, "TOPRIGHT", -(LIST_PAD + 4), y)
            else
                row:SetPoint("TOPLEFT", listClip, "TOPLEFT", LIST_PAD + 4, y)
                row:SetPoint("TOPRIGHT", listClip, "TOPRIGHT", -barGap, y)
            end
            row:SetShown(not scroll.active or (-y + h > 0.5 and -y < scroll.view - 0.5))
        else
            row:Hide()
        end
    end
    scrollUp:SetShown(scroll.active and scroll.px > 0.5)
    scrollDown:SetShown(scroll.active and scroll.px < scroll.max - 0.5)
    if not scroll.active then scrollTrack:Hide() return end
    scrollTrack:Show()
    -- Barre de defilement dans la couleur de surbrillance du choix (cuivre sur parchemin, or sinon).
    local pal = DWE.WheelPalette()
    local c, n = pal.selected, pal.normal
    local skin = DWE.BubbleSkin()
    if skin and skin.palette == WHEEL_INK then
        -- Bulles claires (Bulle enluminee...) : cuivre de la surbrillance.
        local ink = WHEEL_INK.selected
        c = ink
        scrollThumb.tex:SetColorTexture(ink[1], ink[2], ink[3], 0.8)
        scrollTrack.bg:SetColorTexture(ink[1], ink[2], ink[3], 0.12)
    elseif not DWE.WheelThemeId() then
        -- Pas de bloc de theme (Bulle d'Azeroth...) : barre grise tres translucide, discrete.
        scrollThumb.tex:SetColorTexture(0.6, 0.6, 0.6, 0.18)
        scrollTrack.bg:SetColorTexture(1, 1, 1, 0.04)
    else
        scrollThumb.tex:SetColorTexture(c[1], c[2], c[3], 0.85)
        scrollTrack.bg:SetColorTexture(n[1], n[2], n[3], pal.shadow == 0 and 0.18 or 0.10)
    end
    for _, arrow in ipairs({ scrollUp, scrollDown }) do
        arrow:SetDesaturated(true)
        arrow:SetVertexColor(math.min(1, c[1] * 1.25), math.min(1, c[2] * 1.25), math.min(1, c[3] * 1.25))
    end
    local h, th = TrackSizes()
    scrollThumb:SetHeight(th)
    scrollThumb:ClearAllPoints()
    scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, -(h - th) * (scroll.max > 0 and scroll.px / scroll.max or 0))
end

-- Glissade douce vers la cible.
local scrollAnim = CreateFrame("Frame")
scrollAnim:Hide()
scrollAnim:SetScript("OnUpdate", function(self, dt)
    local d = scroll.target - scroll.px
    if math.abs(d) < 0.5 then
        scroll.px = scroll.target
        self:Hide()
    else
        scroll.px = scroll.px + d * math.min(1, dt * 14)
    end
    PositionRows()
end)
local function AnimateScroll()
    if math.abs(scroll.target - scroll.px) < 0.5 then
        scroll.px = scroll.target
        PositionRows()
    else
        scroll.anim = true
        scrollAnim:Show()
    end
end
-- Fin immediate de la glissade (tests, fermeture).
function DWE.SettleScroll()
    scroll.px = scroll.target
    scrollAnim:Hide()
    PositionRows()
end

-- Premier choix "pose" le plus proche d'une position en pixels.
local function NearestFirst(px)
    local total = #DWE.currentOptions
    local best, bestD = 1, math.huge
    for i = 1, math.max(1, total - MAX_VISIBLE + 1) do
        local d = math.abs((scroll.tops[i] or 0) - (scroll.tops[1] or 0) - px)
        if d < bestD then best, bestD = i, d end
    end
    return best
end

-- Defile de `delta` choix (fleches, molette sur la barre...) : la cible change, la liste glisse.
local function ScrollBy(delta)
    local total = #DWE.currentOptions
    if total <= MAX_VISIBLE then return end
    local first = math.max(1, math.min((DWE.wheelFirst or 1) + delta, total - MAX_VISIBLE + 1))
    DWE.wheelFirst = first
    -- la selection reste dans la partie visible
    if DWE.selectedIndex < first then DWE.selectedIndex = first end
    if DWE.selectedIndex > first + MAX_VISIBLE - 1 then DWE.selectedIndex = first + MAX_VISIBLE - 1 end
    DWE.UpdateVisuals()
end
DWE.ScrollWheelBy = ScrollBy

for _, info in ipairs({ { scrollUp, -1 }, { scrollDown, 1 } }) do
    local tex, delta = info[1], info[2]
    local b = CreateFrame("Button", nil, choiceBox)
    b:SetAllPoints(tex)
    b:SetHitRectInsets(-10, -10, -4, -4)
    b:SetScript("OnClick", function() ScrollBy(delta) end)
    tex.button = b
    hooksecurefunc(tex, "SetShown", function(_, shown) b:SetShown(shown) end)
    b:Hide()
end

local function CursorY()
    local _, cy = GetCursorPosition()
    return cy / (UIParent:GetEffectiveScale() or 1)
end

-- Glisser (barre ou liste) : la liste suit la souris au pixel pres, puis se cale en douceur
-- sur le choix le plus proche au relachement.
local function EndPixelDrag()
    local first = NearestFirst(scroll.px)
    ScrollBy(first - (DWE.wheelFirst or 1))
    AnimateScroll()
end

scrollThumb:SetScript("OnMouseDown", function(self, button)
    if button ~= "LeftButton" then return end
    self.dragY, self.dragPx = CursorY(), scroll.px
    scrollAnim:Hide()
end)
scrollThumb:SetScript("OnMouseUp", function(self)
    if self.dragY then self.dragY = nil EndPixelDrag() end
end)
scrollThumb:SetScript("OnUpdate", function(self)
    if not self.dragY or not scroll.active then return end
    local h, th = TrackSizes()
    local ratio = scroll.max / math.max(1, h - th)
    scroll.px = math.max(0, math.min(scroll.max, self.dragPx + (self.dragY - CursorY()) * ratio))
    scroll.target = scroll.px
    PositionRows()
end)

-- Glisser la liste des choix : vers le haut = voir les choix du dessous (comme sur un ecran
-- tactile). Au-dela de quelques pixels, le relachement ne compte pas comme un clic.
local listDriver = CreateFrame("Frame")
listDriver:Hide()
function DWE.StartListDrag()
    listDriver.startY, listDriver.startPx = CursorY(), scroll.px
    listDriver.fling, listDriver.hist = nil, {}
    DWE.listDragging = true
    scrollAnim:Hide()
    listDriver:Show()
end
function DWE.StopListDrag()
    if not DWE.listDragging then return end
    DWE.listDragging = nil
    if not DWE.listDragMoved then listDriver:Hide() return end
    -- Lancer : la vitesse des derniers instants continue de faire glisser la liste, en freinant.
    local h, now = listDriver.hist or {}, GetTime and GetTime() or 0
    local v = 0
    for i = #h, 1, -1 do
        if now - h[i][1] > 0.1 then
            local dt = now - h[i][1]
            if dt > 0 then v = (scroll.px - h[i][2]) / dt end
            break
        end
    end
    if math.abs(v) > 250 and scroll.active then
        listDriver.fling = math.max(-4000, math.min(4000, v))
    else
        listDriver:Hide()
        EndPixelDrag()
    end
end
listDriver:SetScript("OnUpdate", function(self, elapsed)
    if self.fling then
        scroll.px = scroll.px + self.fling * elapsed
        self.fling = self.fling * math.exp(-elapsed * 4)
        local hitEnd = scroll.px <= 0 or scroll.px >= scroll.max
        scroll.px = math.max(0, math.min(scroll.max, scroll.px))
        scroll.target = scroll.px
        PositionRows()
        if hitEnd or math.abs(self.fling) < 80 then
            self.fling = nil
            self:Hide()
            EndPixelDrag()
        end
        return
    end
    if not IsMouseButtonDown or not IsMouseButtonDown("LeftButton") then DWE.StopListDrag() return end
    local dy = CursorY() - self.startY
    if math.abs(dy) > 4 then DWE.listDragMoved = true end
    if not DWE.listDragMoved or not scroll.active then return end
    -- Un peu plus rapide que la souris : la liste parait plus legere.
    scroll.px = math.max(0, math.min(scroll.max, self.startPx + dy * 1.3))
    scroll.target = scroll.px
    local h = self.hist
    h[#h + 1] = { GetTime and GetTime() or 0, scroll.px }
    if #h > 12 then table.remove(h, 1) end
    PositionRows()
end)

function DWE.UpdateVisuals()
    DWE.UpdateVisualsInner()
    if DWE.UpdateBookBar then DWE.UpdateBookBar() end
end

function DWE.UpdateVisualsInner()
    local total = #DWE.currentOptions
    if total == 0 then
        choiceBox:Hide()
        textBox:Hide()
        return
    end
    if DWE.selectedIndex < 1 then DWE.selectedIndex = total end
    if DWE.selectedIndex > total then DWE.selectedIndex = 1 end

    -- Largeur automatique (pas de largeur choisie a la poignee) : juste ce qu'il faut pour le
    -- plus long choix, avec une marge ; pleine largeur si l'apercu de quete s'affiche dessous.
    -- (La largeur utile est aussi mesuree quand le joueur a choisi une largeur : elle limite
    -- l'agrandissement, pour ne pas creer de grands vides a droite du texte.)
    DWE.wheelNeed = nil
    do
        local auto = AUTO_WHEEL_MAX
        if not DWE.wheelWantsPreview then
            local pad = DWE.WheelPillStyle() and PILL_PAD or ROW_PAD
            local need = 0
            for i, opt in ipairs(DWE.currentOptions) do
                local row = optionRows[i]
                if row then
                    DWE.ChoiceFont(row.text)
                    row.text:SetText(opt.rawLabel)
                    local tw = MeasureTextWidth(row.text)
                    if not tw then need = nil break end
                    need = math.max(need, (opt.icon and pad.iconLeft or pad.left) + tw + pad.right + 24)
                end
            end
            auto = need and math.max(AUTO_WHEEL_MIN, math.min(AUTO_WHEEL_MAX, math.ceil(need))) or AUTO_WHEEL_MAX
            DWE.wheelNeed = need and math.ceil(need) or nil
        end
        if not tonumber(DialogueWheelE_WheelWidth) then DWE.autoWheelWidth = auto end
    end

    -- Choix "bulle" : tous de la largeur du plus long (limitee a la largeur de la roue).
    local pillWidth
    if DWE.WheelPillStyle() then
        local full = DWE.WheelWidth() - 8
        pillWidth = 0
        for i, opt in ipairs(DWE.currentOptions) do
            local row = optionRows[i]
            if row then
                DWE.ChoiceFont(row.text)
                row.text:SetText(opt.rawLabel)
                local tw = MeasureTextWidth(row.text)
                if not tw then pillWidth = full break end
                pillWidth = math.max(pillWidth, (opt.icon and PILL_PAD.iconLeft or PILL_PAD.left) + tw + PILL_PAD.right + 4)
            end
        end
        pillWidth = math.min(full, math.max(120, pillWidth))
        -- Largeur choisie avec la poignee : les bulles la prennent (sinon elles suivent le texte).
        -- ... sans depasser le texte le plus long de plus de DWE.WHEEL_SLACK.
        if tonumber(DialogueWheelE_WheelWidth) then
            pillWidth = math.max(120, math.min(full, pillWidth + DWE.WHEEL_SLACK))
        end
    end

    -- Beaucoup de choix (ex. garde de Hurlevent) : on n'en montre que MAX_VISIBLE ; la fenetre
    -- suit la selection et la liste y glisse en douceur.
    local first = 1
    if total > MAX_VISIBLE then
        first = math.max(1, math.min(DWE.wheelFirst or 1, total - MAX_VISIBLE + 1))
        if DWE.selectedIndex < first then first = DWE.selectedIndex end
        if DWE.selectedIndex > first + MAX_VISIBLE - 1 then first = DWE.selectedIndex - MAX_VISIBLE + 1 end
    end
    DWE.wheelFirst = first

    -- Largeur du cadre fixee AVANT de mesurer les choix : sinon un choix est mesure avec la
    -- largeur de la conversation precedente (texte coupe sur deux lignes ou bulle trop haute).
    -- En bulles, le cadre s'arrete au bord des bulles (la poignee est donc a leur coin).
    local boxW = DWE.WheelWidth()
    if not pillWidth and DWE.wheelNeed and tonumber(DialogueWheelE_WheelWidth) then
        boxW = math.min(boxW, math.max(AUTO_WHEEL_MIN, DWE.wheelNeed + DWE.WHEEL_SLACK))
    end
    choiceBox:SetWidth(pillWidth and (pillWidth + 8) or boxW)

    local pill = DWE.WheelPillStyle()
    local gap = pill and 6 or 5
    local tops, heights = {}, {}
    local yy = 0
    for i, opt in ipairs(DWE.currentOptions) do
        local row = DWE.GetRow(i)
        PaintRow(row, opt, i == DWE.selectedIndex, pillWidth)
        local h = pill and math.max(36, TextHeight(row.text, 16) + 20) or math.max(24, TextHeight(row.text, 16) + 6)
        row:SetHeight(h)
        tops[i], heights[i] = yy, h
        yy = yy + h + gap
    end
    for i = total + 1, #optionRows do optionRows[i]:Hide() end
    scroll.tops, scroll.heights = tops, heights
    scroll.active = total > MAX_VISIBLE

    local topPad, bottomPad = 4, 4
    local view
    if scroll.active then
        topPad, bottomPad = 18, 16
        view = tops[MAX_VISIBLE + 1] - gap
        scroll.max = (tops[total] + heights[total]) - view
        scroll.target = math.min(scroll.max, tops[first])
        -- Lignes de hauteurs differentes (choix sur deux lignes) : le choix surligne reste
        -- entierement visible, et la derniere fenetre montre bien le bas de la liste.
        local sel = DWE.selectedIndex
        if tops[sel] and heights[sel] then
            scroll.target = math.max(scroll.target, math.min(scroll.max, tops[sel] + heights[sel] - view))
        end
        if first >= total - MAX_VISIBLE + 1 then scroll.target = scroll.max end
    else
        view = yy - gap
        scroll.max, scroll.target = 0, 0
    end
    scroll.view = view
    if DWE.scrollSnap or not scroll.active then
        DWE.scrollSnap = nil
        scroll.px = scroll.target
    end

    local mirrored = DWE.WheelLeft()
    listClip:ClearAllPoints()
    listClip:SetPoint("TOPLEFT", choiceBox, "TOPLEFT", mirrored and 0 or -LIST_PAD, -topPad)
    listClip:SetPoint("TOPRIGHT", choiceBox, "TOPRIGHT", mirrored and LIST_PAD or 0, -topPad)
    listClip:SetHeight(view + (scroll.active and gap - 1 or 12))
    -- Rail de defilement cale exactement sur la zone visible des choix (ne depasse pas).
    scrollTrack:ClearAllPoints()
    if mirrored then
        scrollTrack:SetPoint("TOPLEFT", choiceBox, "TOPLEFT", 3, -topPad - 3)
    else
        scrollTrack:SetPoint("TOPRIGHT", choiceBox, "TOPRIGHT", -3, -topPad - 3)
    end
    scrollTrack:SetHeight(math.max(10, view - 6))
    choiceBox:SetHeight(topPad + view + bottomPad)
    if not DWE.listDragging then AnimateScroll() end
    choiceBox:Show()
    DWE.UpdateTextPanelVisuals()
end

function DWE.GetRow(i)
    if optionRows[i] then return optionRows[i] end
    local row = CreateFrame("Button", nil, listClip)
    row:SetHeight(24)
    row:RegisterForClicks("LeftButtonUp")
    row:RegisterForDrag("LeftButton", "RightButton")

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    row.text:SetPoint("TOPRIGHT", row, "TOPRIGHT", -2, -3)
    StyleText(row.text, 0.95, 0.92, 0.85)

    -- Glisser la liste elle-meme (clic gauche maintenu) fait defiler, comme la barre.
    row:HookScript("OnMouseDown", function(_, button)
        DWE.listDragMoved = nil
        if button == "LeftButton" and #DWE.currentOptions > MAX_VISIBLE then
            DWE.StartListDrag()
        end
    end)
    row:HookScript("OnMouseUp", function() DWE.StopListDrag() end)

    row:HookScript("OnLeave", function() DWE.SetFrameHover(choiceBox, false) end)
    row:SetScript("OnEnter", function()
        DWE.SetFrameHover(choiceBox, true)
        if DWE.listDragging or DWE.CursorStill() then return end
        local opt = DWE.currentOptions[i]
        if opt and not opt.disabled and DWE.selectedIndex ~= i then
            DWE.selectedIndex = i
            DWE.UpdateVisuals()
        end
    end)
    row:SetScript("OnClick", function()
        if DWE.listDragMoved then DWE.listDragMoved = nil return end -- c'etait un glisser
        if DWE.JustDragged() then return end -- on vient de deplacer la roue
        local opt = DWE.currentOptions[i]
        if opt and not opt.disabled and opt.action then
            DWE.selectedIndex = i
            opt.action()
        end
    end)
    row:SetScript("OnDragStart", function()
        -- Clic gauche : fait defiler une longue liste ; sinon (comme le clic droit) deplace la roue.
        if DWE.listDragging then return end
        DWE.DragStart("wheel")
    end)
    row:SetScript("OnDragStop", function() DWE.DragStop("wheel") end)
    optionRows[i] = row
    return row
end

--------------------------------------------------------------------------------
-- Boutons de recompense / objets
--------------------------------------------------------------------------------

local rewardButtons = {}

function DWE.HideRewardButtons()
    DWE.hoveredRewardBtn = nil
    reqHeader:Hide()
    chooseHeader:Hide()
    for _, b in ipairs(rewardButtons) do b:Hide() end
end

local ShowRewardTooltipUnsafe

-- Protege : la roue peut etre accrochee a une plaque de nom, ou le jeu limite les mesures.
function DWE.ShowRewardTooltip(btn)
    if btn then pcall(ShowRewardTooltipUnsafe, btn) end
end

function ShowRewardTooltipUnsafe(btn)
    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
    if btn.isDarkmoonTicket then
        if GameTooltip.SetCurrencyByID then
            GameTooltip:SetCurrencyByID(515)
        else
            GameTooltip:SetHyperlink("currency:515")
        end
    elseif btn.itemType and btn.itemIndex then
        GameTooltip:SetQuestItem(btn.itemType, btn.itemIndex)
    elseif btn.itemLink then
        GameTooltip:SetHyperlink(btn.itemLink)
    end
    GameTooltip:Show()
end

local function IsModified(kind)
    return IsModifiedClick and IsModifiedClick(kind)
end

function DWE.GetRewardButton(i)
    if rewardButtons[i] then return rewardButtons[i] end
    local btn = CreateFrame("Button", nil, choiceBox)
    btn:SetHeight(24)
    btn:RegisterForClicks("LeftButtonUp")

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetSize(22, 22)
    btn.icon:SetPoint("LEFT", btn, "LEFT", 0, 0)
    btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    btn.count = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    btn.count:SetPoint("BOTTOMRIGHT", btn.icon, "BOTTOMRIGHT", -1, 1)
    btn.count:SetJustifyH("RIGHT")

    btn.text = btn:CreateFontString(nil, "OVERLAY")
    btn.text:SetFontObject(questFontObj)
    btn.text:SetPoint("LEFT", btn.icon, "RIGHT", 7, 0)
    btn.text:SetPoint("RIGHT", btn, "RIGHT", -2, 0)
    StyleText(btn.text, 1, 1, 1)

    btn.highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    btn.highlight:SetAllPoints(btn)
    btn.highlight:SetColorTexture(1, 1, 1, 0.12)

    btn.selectedBorder = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    btn.selectedBorder:SetPoint("TOPLEFT", btn, "TOPLEFT", -3, 3)
    btn.selectedBorder:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 3, -3)
    btn.selectedBorder:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12 })
    btn.selectedBorder:SetBackdropBorderColor(1, 0.85, 0.1, 1)
    btn.selectedBorder:Hide()

    btn:SetScript("OnEnter", function(self)
        DWE.hoveredRewardBtn = self
        DWE.ShowRewardTooltip(self)
    end)
    btn:SetScript("OnLeave", function(self)
        if DWE.hoveredRewardBtn == self then DWE.hoveredRewardBtn = nil end
        GameTooltip:Hide()
    end)
    btn:SetScript("OnClick", function(self, button)
        local dressUp, chatLink = IsModified("DRESSUP"), IsModified("CHATLINK")
        if self.canChoose and not dressUp and not chatLink then
            DWE.selectedRewardIndex = self.itemIndex
            if DWE.OnRewardSelected then DWE.OnRewardSelected() end
            return
        end
        if not self.itemLink then return end
        if dressUp then
            if DressUpItemLink then DressUpItemLink(self.itemLink) end
        elseif chatLink then
            if ChatEdit_InsertLink then ChatEdit_InsertLink(self.itemLink) end
        elseif SetItemRef then
            SetItemRef(self.itemLink, self.itemLink, button)
        end
    end)

    rewardButtons[i] = btn
    return btn
end

function DWE.RefreshRewardSelection()
    for _, b in ipairs(rewardButtons) do
        b.selectedBorder:SetShown(b:IsShown() and b.canChoose and b.itemIndex == DWE.selectedRewardIndex)
    end
end

--------------------------------------------------------------------------------
-- Theme derriere la roue (option "Appliquer le theme a la roue")
--------------------------------------------------------------------------------
-- Le fond couvre la roue et l'apercu de quete en dessous : de son haut jusqu'au dernier
-- element affiche (DWE.wheelBottom, fixe par l'apercu).

local wheelArea = CreateFrame("Frame", nil, choiceBox)
wheelArea:EnableMouse(false)
local wheelParts = CreateThemeParts(choiceBox, choiceBox:GetFrameLevel())

-- Avec les bulles de choix : l'apercu de quete est dans sa propre bulle.
local previewPanel = CreateFrame("Frame", nil, choiceBox, "BackdropTemplate")
previewPanel:SetFrameLevel(choiceBox:GetFrameLevel())
previewPanel:EnableMouse(false)
previewPanel:Hide()

function DWE.PaintWheelTheme()
    local bottom = DWE.wheelBottom or choiceBox
    wheelArea:ClearAllPoints()
    wheelArea:SetPoint("TOPLEFT", choiceBox, "TOPLEFT", 0, 0)
    wheelArea:SetPoint("RIGHT", choiceBox, "RIGHT", 0, 0)
    wheelArea:SetPoint("BOTTOM", bottom, "BOTTOM", 0, (bottom == choiceBox) and 0 or -4)
    local id = DWE.WheelThemeId()
    if id then
        PaintThemeParts(wheelParts, wheelArea, nil, id)
    else
        ClearThemeParts(wheelParts)
    end
    local pill = DWE.WheelPillStyle()
    if pill and bottom ~= choiceBox then
        SkinPill(previewPanel, pill, false, true)
        previewPanel:ClearAllPoints()
        previewPanel:SetPoint("TOPLEFT", choiceBox, "BOTTOMLEFT", -8, 0)
        previewPanel:SetPoint("RIGHT", choiceBox, "RIGHT", 8, 0)
        previewPanel:SetPoint("BOTTOM", bottom, "BOTTOM", 0, -14)
        previewPanel:Show()
    else
        previewPanel:Hide()
    end
    local size = tonumber(DialogueWheelE_FontSize) or 13
    for _, fs in ipairs({ objLine, reqHeader, rewLine, chooseHeader }) do ApplyWheelFont(fs, questFontObj, size) end
    for _, b in ipairs(rewardButtons) do ApplyWheelFont(b.text, questFontObj, size) end
    local sh = DWE.WheelPalette().shadow
    for _, fs in ipairs({ objLine, reqHeader, rewLine, chooseHeader }) do fs:SetShadowOffset(sh, -sh) end
    for _, b in ipairs(rewardButtons) do b.text:SetShadowOffset(sh, -sh) end
    if DWE.PaintSharer then DWE.PaintSharer() end
end

--------------------------------------------------------------------------------
-- Quete partagee par un joueur : portrait, nom (couleur de classe) et phrase, au-dessus
-- de la roue. Suit le theme de la roue comme le reste.
--------------------------------------------------------------------------------

local sharer = CreateFrame("Frame", "DialogueWheelESharerFrame", choiceBox, "BackdropTemplate")
sharer:Hide()
sharer:EnableMouse(false)
sharer:SetHeight(50)

local sharerPortrait = sharer:CreateTexture(nil, "ARTWORK")
sharerPortrait:SetSize(34, 34)
sharerPortrait:SetPoint("LEFT", sharer, "LEFT", 12, 0)
pcall(sharerPortrait.SetMask, sharerPortrait, "Interface\\CharacterFrame\\TempPortraitAlphaMask")

-- Icone de secours (classe ou point d'interrogation) : texture sans masque, car le jeu
-- refuse de recadrer (SetTexCoord) une texture masquee.
local sharerIcon = sharer:CreateTexture(nil, "ARTWORK")
sharerIcon:SetSize(34, 34)
sharerIcon:SetPoint("CENTER", sharerPortrait, "CENTER", 0, 0)
sharerIcon:Hide()

local sharerRing = sharer:CreateTexture(nil, "OVERLAY")
sharerRing:SetSize(42, 42)
sharerRing:SetPoint("CENTER", sharerPortrait, "CENTER", 0, 0)
sharerRing:SetTexture(ADDON_PATH .. "PortraitRing.png")

local sharerName = sharer:CreateFontString(nil, "OVERLAY")
sharerName:SetFontObject(GameFontNormal)
sharerName:SetPoint("BOTTOMLEFT", sharerPortrait, "RIGHT", 10, 1)
sharerName:SetJustifyH("LEFT")

local sharerLine = sharer:CreateFontString(nil, "OVERLAY")
sharerLine:SetFontObject(GameFontHighlightSmall)
sharerLine:SetPoint("TOPLEFT", sharerPortrait, "RIGHT", 10, -2)
sharerLine:SetJustifyH("LEFT")

local SHARER_BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

local sharerInfo
local function ClassRGB(class)
    local c
    if class and C_ClassColor and C_ClassColor.GetClassColor then
        local ok, res = pcall(C_ClassColor.GetClassColor, class)
        if ok then c = res end
    end
    c = c or (class and type(RAID_CLASS_COLORS) == "table" and RAID_CLASS_COLORS[class])
    if c and c.r then return c.r, c.g, c.b end
    return 1, 0.82, 0
end

function DWE.PaintSharer()
    if not sharerInfo then sharer:Hide() return end
    local pill = DWE.WheelPillStyle()
    local light = DWE.WheelPalette() == WHEEL_INK
    if pill then
        if sharer.SetBackdrop then sharer:SetBackdrop(nil) end
        SkinPill(sharer, pill, false, false) -- annonce du jeu : pas d'encoche
    else
        if sharer.dweTex then sharer.dweTex:Hide() end
        if sharer.SetBackdrop then
            sharer:SetBackdrop(SHARER_BACKDROP)
            if light then
                sharer:SetBackdropColor(0.93, 0.85, 0.68, 0.96)
                sharer:SetBackdropBorderColor(0.45, 0.30, 0.15, 1)
            else
                sharer:SetBackdropColor(0, 0, 0, 0.8)
                sharer:SetBackdropBorderColor(0.8, 0.65, 0.3, 1)
            end
        end
    end

    local size = tonumber(DialogueWheelE_FontSize) or 13
    ApplyWheelFont(sharerName, GameFontNormal, size + 1)
    ApplyWheelFont(sharerLine, GameFontHighlightSmall, math.max(9, size - 2))
    local r, g, b = ClassRGB(sharerInfo.class)
    if light then r, g, b = r * 0.55, g * 0.55, b * 0.55 end -- lisible sur fond clair
    sharerName:SetTextColor(r, g, b)
    if light then sharerLine:SetTextColor(0.16, 0.09, 0.03) else sharerLine:SetTextColor(0.9, 0.9, 0.9) end
    local sh = light and 0 or 1
    sharerName:SetShadowOffset(sh, -sh)
    sharerLine:SetShadowOffset(sh, -sh)

    sharerName:SetText(sharerInfo.name)
    sharerLine:SetText(L.SHARED_QUEST)
    local w = math.max(MeasureWidth(sharerName), MeasureWidth(sharerLine))
    sharer:SetWidth(math.max(160, 12 + 34 + 10 + w + 16))
    sharer:ClearAllPoints()
    sharer:SetPoint("BOTTOMLEFT", choiceBox, "TOPLEFT", pill and -8 or 0, pill and 10 or 6)
    sharer:Show()
end

-- info = { unit = jeton d'unite ou nil, name = "...", class = "PALADIN" } ; nil = cacher.
function DWE.SetQuestSharer(info)
    sharerInfo = info
    if not info then sharer:Hide() return end
    local shown = false
    if info.unit and SetPortraitTexture then
        shown = pcall(SetPortraitTexture, sharerPortrait, info.unit)
    end
    sharerPortrait:SetShown(shown)
    sharerIcon:SetShown(not shown)
    if not shown then
        local coords = info.class and type(CLASS_ICON_TCOORDS) == "table" and CLASS_ICON_TCOORDS[info.class]
        if coords then
            sharerIcon:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
            sharerIcon:SetTexCoord(unpack(coords))
        else
            sharerIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            sharerIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end
    end
    DWE.PaintSharer()
end

choiceBox:HookScript("OnHide", function() DWE.SetQuestSharer(nil) end)

-- Apres un changement de theme, d'opacite ou de l'option : popup, Spoken et roue.
function DWE.OnThemeChanged()
    DWE.ApplyTextTheme()
    DWE.ApplyFont()
    DWE.RefreshSpoken()
    if choiceBox:IsShown() then
        DWE.UpdateVisuals()
        if DWE.RefreshPreview then DWE.RefreshPreview() else DWE.PaintWheelTheme() end
    else
        DWE.PaintWheelTheme()
    end
end

--------------------------------------------------------------------------------
-- Panneau d'options (Echap > Options > AddOns > DialogueWheelE)
--------------------------------------------------------------------------------

local CHECK_TEMPLATE = "InterfaceOptionsCheckButtonTemplate"
local SLIDER_TEMPLATE = "OptionsSliderTemplate"

local MODIFIER_KEYS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true }

local function KeyLabel(key)
    return (key and key ~= "") and key or L.KEY_NONE
end

-- Themes proposes dans les options, par famille, avec leur vignette (Thumbs\*.png).
local THEME_LIST = {
    { id = "bubble", key = "THEME_BUBBLE", thumb = "Bubble" },
    { id = "bubble_fantasy", key = "THEME_BUBBLE_FANTASY", thumb = "BubbleFantasy" },
    { id = "whisper", key = "THEME_WHISPER", thumb = "Whisper" },
    { id = "transparent", key = "THEME_TRANS", thumb = "Transparent" },
    { id = "dark", key = "THEME_DARK", thumb = "Dark" },
    { id = "glass", key = "THEME_GLASS", thumb = "Glass" },
    { id = "halo", key = "THEME_HALO", thumb = "Halo" },
    { id = "inkgold", key = "THEME_INK", thumb = "Ink" },
    { id = "cinema", key = "THEME_CINEMA", thumb = "Cinema" },
    { id = "velin", key = "THEME_VELIN", thumb = "Velin" },
    { id = "arcane", key = "THEME_ARCANE", thumb = "Arcane" },
    { id = "sylvan", key = "THEME_SYLVAN", thumb = "Sylvan" },
    { id = "starry", key = "THEME_STARRY", thumb = "Starry" },
    { id = "parchment", key = "THEME_PARCH", thumb = "Parchment" },
    { id = "parchment_dark", key = "THEME_PARCH_DARK", thumb = "ParchmentDark" },
    { id = "folio", key = "THEME_FOLIO", thumb = "Folio" },
    { id = "folio_dark", key = "THEME_FOLIO_DARK", thumb = "FolioDark" },
}
-- Themes DialogueUI : seulement avec DialogueUI installe (images lues dans son dossier).
if DWE.DUI_ON then
    THEME_LIST[#THEME_LIST + 1] = { id = "dui_brown", key = "THEME_DUI_BROWN", thumbTex = DWE.DUI_ART .. "Theme_Brown\\Parchment.png", thumbCoord = { 0.22, 0.78, 0.14, 0.34 } }
    THEME_LIST[#THEME_LIST + 1] = { id = "dui_dark", key = "THEME_DUI_DARK", thumbTex = DWE.DUI_ART .. "Theme_Dark\\Parchment.png", thumbCoord = { 0.22, 0.78, 0.14, 0.34 } }
end
DWE.THEME_LIST = THEME_LIST

-- Options remises a zero : toutes les variables sauvegardees sauf la liste des livres/PNJ
-- deja entendus avec Spoken (ce n'est pas un reglage).
DWE.OPTION_VARS = { "Pos", "TextPos", "Theme", "Font", "FontSize", "Scale", "Opacity", "ShowText",
    "UseBlizzKey", "InteractKey", "ToggleKey", "WheelScroll", "SpokenTheme", "AttachNPC", "NPCOffset",
    "WheelWidth", "TextW", "TextH", "BubbleWidth", "Locked", "WheelTheme", "EscClose", "BookStyle",
    "ThemeFrames", "BookLook", "BookPos", "BookScale", "NoteScale", "SpokenChoice", "ChoiceSize", "WheelSide", "PlateStyle", "PlateLook", "DefaultsV" }
function DWE.ResetAllOptions()
    for _, k in ipairs(DWE.OPTION_VARS) do _G["DialogueWheelE_" .. k] = nil end
    if ReloadUI then ReloadUI() end
end
function DWE.AskResetAll()
    if not StaticPopupDialogs then DWE.ResetAllOptions() return end
    StaticPopupDialogs.STORYTALE_RESET_ALL = StaticPopupDialogs.STORYTALE_RESET_ALL or {
        text = DWE.L.RESET_ALL_CONFIRM, button1 = YES or "Yes", button2 = NO or "No",
        OnAccept = function() DWE.ResetAllOptions() end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
    StaticPopup_Show("STORYTALE_RESET_ALL")
end

function DWE.InitOptionsPanel()
    if DWE.optionsPanel then return end
    local panel = CreateFrame("Frame", "DialogueWheelEOptionsPanel")
    panel.name = "Storytale"
    DWE.optionsPanel = panel

    -- Tout le contenu defile (le panneau est plus haut que la fenetre des options).
    local scroll = CreateFrame("ScrollFrame", "DialogueWheelEOptionsScroll", panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -4)
    scroll:SetPoint("BOTTOMRIGHT", -28, 4)
    local p = CreateFrame("Frame", nil, scroll)
    p:SetSize(600, 1100)
    scroll:SetScrollChild(p)

    local function AddText(txt, x, y, font)
        local fs = p:CreateFontString(nil, "ARTWORK", font)
        fs:SetPoint("TOPLEFT", x, y)
        fs:SetText(txt)
        return fs
    end
    -- Titre de section avec un filet dore.
    local function AddSection(txt, y)
        AddText(txt, 16, y, "GameFontNormalLarge")
        local line = p:CreateTexture(nil, "ARTWORK")
        line:SetColorTexture(0.8, 0.65, 0.3, 0.45)
        line:SetHeight(1)
        line:SetPoint("TOPLEFT", 16, y - 22)
        line:SetPoint("TOPRIGHT", p, "TOPRIGHT", -16, y - 22)
    end

    local function AddCheck(label, x, y, checked, onClick)
        local cb = CreateFrame("CheckButton", nil, p, CHECK_TEMPLATE)
        cb:SetPoint("TOPLEFT", x, y)
        cb.Text:SetText(label)
        cb:SetChecked(checked)
        cb:SetScript("OnClick", onClick)
        return cb
    end

    -- Groupe de cases a cocher exclusives (une seule cochee), en colonnes.
    local function AddGroup(items, x, startY, step, current, onPick, perColumn, colWidth)
        local list = {}
        for i, info in ipairs(items) do
            local col = perColumn and math.floor((i - 1) / perColumn) or 0
            local rowI = perColumn and ((i - 1) % perColumn) or (i - 1)
            local cb = AddCheck(info.label, x + col * (colWidth or 0), startY - rowI * step, current == info.id, function(self)
                for _, o in ipairs(list) do o:SetChecked(o == self) end
                onPick(info.id)
            end)
            if info.font then
                local _, size = cb.Text:GetFont()
                SafeSetFont(cb.Text, info.font, (size or 12) + 1)
            end
            list[i] = cb
        end
        return list
    end

    local function AddSlider(name, label, x, y, minV, maxV, step, curV, fmt, onSlide)
        local sl = CreateFrame("Slider", name, p, SLIDER_TEMPLATE)
        sl:SetPoint("TOPLEFT", x, y)
        sl:SetWidth(220)
        sl:SetMinMaxValues(minV, maxV)
        sl:SetValueStep(step)
        sl:SetObeyStepOnDrag(true)
        sl:SetValue(curV)
        _G[name .. "Low"]:SetText(string.format(fmt, minV))
        _G[name .. "High"]:SetText(string.format(fmt, maxV))
        _G[name .. "Text"]:SetText(label .. " : " .. string.format(fmt, curV))
        sl:SetScript("OnValueChanged", function(_, val)
            val = math.floor(val / step + 0.5) * step
            _G[name .. "Text"]:SetText(label .. " : " .. string.format(fmt, val))
            onSlide(val)
        end)
    end

    AddText("Storytale", 16, -12, "GameFontNormalHuge")
    -- Remise a zero de toutes les options (avec confirmation, puis rechargement de l'interface).
    local resetAllBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    resetAllBtn:SetPoint("TOPRIGHT", p, "TOPRIGHT", -16, -12)
    resetAllBtn:SetSize(220, 24)
    resetAllBtn:SetText(L.RESET_ALL)
    resetAllBtn:SetScript("OnClick", function() DWE.AskResetAll() end)

    ---------------------------------------------------------------- Theme
    local y = -52
    AddSection(L.SEC_THEME, y)
    AddText(L.THEME_HINT, 16, y - 30, "GameFontDisableSmall")
    local TILE_W, TILE_H, COLS = 132, 66, 4
    local tiles = {}
    local function RefreshTiles()
        local cur = DialogueWheelE_Theme or "bubble"
        for _, t in ipairs(tiles) do
            local bubbleThumb = DWE.ThemeIsBubble(t.id) and BUBBLE_SKINS[t.id].art
            if t.thumbTex then
                t.img:SetTexture(t.thumbTex)
                t.img:SetTexCoord(unpack(t.thumbCoord))
            else
                t.img:SetTexture(ADDON_PATH .. "Thumbs\\" .. t.thumb .. (bubbleThumb and "Bubble" or "") .. ".png")
            end
            if t.id == cur then
                t:SetBackdropBorderColor(1, 0.82, 0.25, 1)
                t.label:SetTextColor(1, 0.82, 0.25)
            else
                t:SetBackdropBorderColor(0.35, 0.35, 0.38, 0.9)
                t.label:SetTextColor(0.9, 0.9, 0.9)
            end
        end
    end
    local gridTop = y - 52
    for i, info in ipairs(THEME_LIST) do
        local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
        local t = CreateFrame("Button", nil, p, "BackdropTemplate")
        t.id = info.id
        t:SetSize(TILE_W + 6, TILE_H + 6)
        t:SetPoint("TOPLEFT", 16 + col * (TILE_W + 16), gridTop - row * (TILE_H + 32))
        t:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10 })
        local img = t:CreateTexture(nil, "ARTWORK")
        t.img, t.thumb, t.thumbTex, t.thumbCoord = img, info.thumb, info.thumbTex, info.thumbCoord
        img:SetPoint("TOPLEFT", 3, -3)
        img:SetPoint("BOTTOMRIGHT", -3, 3)
        if info.thumbTex then
            img:SetTexture(info.thumbTex)
            img:SetTexCoord(unpack(info.thumbCoord))
        else
            img:SetTexture(ADDON_PATH .. "Thumbs\\" .. info.thumb .. ".png")
        end
        local hl = t:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints(img)
        hl:SetColorTexture(1, 1, 1, 0.12)
        t.label = t:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        t.label:SetPoint("TOP", t, "BOTTOM", 0, -3)
        t.label:SetWidth(TILE_W + 10)
        t.label:SetText(L[info.key])
        t:SetScript("OnClick", function()
            DialogueWheelE_Theme = info.id
            RefreshTiles()
            DWE.OnThemeChanged()
        end)
        tiles[i] = t
    end
    RefreshTiles()
    y = gridTop - math.ceil(#THEME_LIST / COLS) * (TILE_H + 32) - 6
    -- Cochee (par defaut) : themes en bulle. Decochee : themes en cadre.
    -- Bulle d'Azeroth, Bulle enluminee et Murmure restent toujours en bulle.
    DWE.framesCheck = AddCheck(L.THEME_BUBBLES, 16, y, DialogueWheelE_ThemeFrames ~= true, function(self)
        DialogueWheelE_ThemeFrames = not self:GetChecked()
        RefreshTiles()
        DWE.OnThemeChanged()
    end)
    y = y - 30
    AddCheck(L.WHEEL_THEME, 16, y, DialogueWheelE_WheelTheme == true, function(self)
        DialogueWheelE_WheelTheme = self:GetChecked() and true or false
        DWE.OnThemeChanged()
    end)
    AddSlider("DWESliderOpacity", L.OPACITY_LBL, 22, y - 50, 0.2, 1, 0.05, tonumber(DialogueWheelE_Opacity) or 1, "%.2f", function(v)
        DialogueWheelE_Opacity = v
        DWE.OnThemeChanged()
    end)

    ---------------------------------------------------------------- Texte
    y = y - 96
    AddSection(L.SEC_TEXT, y)
    AddText(L.FONT_FAMILY, 16, y - 32, "GameFontHighlightSmall")
    local fontItems = {}
    for i, f in ipairs(FONTS) do
        local label = f.default and (f.name .. " (" .. L.FONT_DEFAULT .. ")") or f.name
        fontItems[i] = { id = f.id, label = label, font = FontPath(f.id) }
    end
    if DWE.IS_CJK then
        AddText(L.FONT_LOCKED, 16, y - 52, "GameFontDisableSmall")
        y = y - 80
    else
        AddGroup(fontItems, 16, y - 48, 26, DialogueWheelE_Font or "friz", function(id)
            DialogueWheelE_Font = id
            DWE.ApplyFont()
        end, 5, 284)
        y = y - 48 - 5 * 26
    end
    AddSlider("DWESliderFont", L.FONT_SIZE, 22, y - 22, 10, 22, 1, tonumber(DialogueWheelE_FontSize) or 14, "%d pt", function(v)
        DialogueWheelE_FontSize = v
        DWE.ApplyFont()
    end)
    AddSlider("DWESliderChoice", L.CHOICE_SIZE, 306, y - 22, 10, 24, 1, DWE.ChoiceSize(), "%d pt", function(v)
        DialogueWheelE_ChoiceSize = v
        if DWE.choiceBox:IsShown() then DWE.UpdateVisuals() end
    end)

    ---------------------------------------------------------------- Livres et lettres
    y = y - 76
    AddSection(L.SEC_BOOKS, y)
    -- Livres et lettres : qui les affiche, puis leur style (seulement pour Storytale).
    AddText(L.BOOKS_HDR, 16, y - 32, "GameFontNormal")
    AddText(L.BOOK_STYLE, 16, y - 54, "GameFontHighlightSmall")
    local function Tip(cb, text)
        if not (cb and text) then return end
        cb:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(text, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        cb:HookScript("OnLeave", function() GameTooltip:Hide() end)
    end
    local bookStyleBoxes = AddGroup({
        { id = "addon", label = L.BOOK_ADDON },
        { id = "dui", label = L.BOOK_DUI },
        { id = "blizzard", label = L.BOOK_BLIZZ },
    }, 16, y - 70, 26, DialogueWheelE_BookStyle or "addon", function(id)
        DialogueWheelE_BookStyle = id
        if DWE.RefreshBookLookOptions then DWE.RefreshBookLookOptions() end
    end, 1, 160)
    Tip(bookStyleBoxes[1], L.BOOK_ADDON_TIP)
    -- DialogueUI : seulement si l'addon DialogueUI est actif.
    local duiOn = (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("DialogueUI"))
        or (IsAddOnLoaded and IsAddOnLoaded("DialogueUI"))
    local function GreyDUI(boxes)
        if not duiOn and boxes[2] then
            boxes[2]:Disable()
            if boxes[2].Text then boxes[2].Text:SetTextColor(0.5, 0.5, 0.5) end
        end
    end
    GreyDUI(bookStyleBoxes)
    local bookLookLabel = AddText(L.BOOK_LOOK, 16, y - 102, "GameFontHighlightSmall")
    local bookLookBoxes = AddGroup({
        { id = "auto", label = L.BOOK_LOOK_AUTO },
        { id = "note", label = L.BOOK_LOOK_NOTE },
        { id = "book", label = L.BOOK_LOOK_BOOK },
        { id = "frame", label = L.BOOK_LOOK_FRAME },
    }, 16, y - 118, 26, DialogueWheelE_BookLook or "auto", function(id)
        DialogueWheelE_BookLook = id
        if DWE.bookMode and textBox:IsShown() then DWE.UpdateTextPanelVisuals() end
    end, 1, 150)
    -- Le style ne concerne que les livres affiches par Storytale : grise sinon.
    function DWE.RefreshBookLookOptions()
        local on = (DialogueWheelE_BookStyle or "addon") == "addon"
        local c = on and 1 or 0.5
        for _, cb in ipairs(bookLookBoxes) do
            if on then cb:Enable() else cb:Disable() end
            if cb.Text then cb.Text:SetTextColor(c, c, c) end
        end
        if bookLookLabel and bookLookLabel.SetTextColor then bookLookLabel:SetTextColor(c, c, c) end
    end
    DWE.RefreshBookLookOptions()
    -- Plaques gravees : leur propre reglage.
    AddText(L.PLATE_STYLE, 16, y - 156, "GameFontNormal")
    AddText(L.BOOK_STYLE, 16, y - 178, "GameFontHighlightSmall")
    local plateBoxes = AddGroup({
        { id = "addon", label = L.PLATE_ADDON },
        { id = "dui", label = L.BOOK_DUI },
        { id = "blizzard", label = L.BOOK_BLIZZ },
    }, 16, y - 194, 26, DialogueWheelE_PlateStyle or "addon", function(id)
        DialogueWheelE_PlateStyle = (id ~= "addon") and id or nil
        if DWE.RefreshPlateLookOptions then DWE.RefreshPlateLookOptions() end
    end, 1, 160)
    Tip(plateBoxes[1], L.PLATE_ADDON_TIP)
    GreyDUI(plateBoxes)
    local plateLookLabel = AddText(L.PLATE_LOOK, 16, y - 226, "GameFontHighlightSmall")
    local plateLookBoxes = AddGroup({
        { id = "auto", label = L.BOOK_LOOK_AUTO },
        { id = "Stone", label = L.PLATE_STONE },
        { id = "Marble", label = L.PLATE_MARBLE },
        { id = "Bronze", label = L.PLATE_BRONZE },
        { id = "Silver", label = L.PLATE_SILVER },
    }, 16, y - 242, 26, DialogueWheelE_PlateLook or "auto", function(id)
        DialogueWheelE_PlateLook = (id ~= "auto") and id or nil
        if DWE.bookMode and textBox:IsShown() then DWE.UpdateTextPanelVisuals() end
    end, 1, 110)
    Tip(plateLookBoxes[1], L.PLATE_AUTO_TIP)
    -- La matiere ne concerne que les plaques affichees par Storytale : grise sinon.
    function DWE.RefreshPlateLookOptions()
        local on = (DialogueWheelE_PlateStyle or "addon") == "addon"
        local c = on and 1 or 0.5
        for _, cb in ipairs(plateLookBoxes) do
            if on then cb:Enable() else cb:Disable() end
            if cb.Text then cb.Text:SetTextColor(c, c, c) end
        end
        if plateLookLabel and plateLookLabel.SetTextColor then plateLookLabel:SetTextColor(c, c, c) end
    end
    DWE.RefreshPlateLookOptions()

    ---------------------------------------------------------------- Placement
    y = y - 284
    AddSection(L.SEC_PLACE, y)
    AddCheck(L.ATTACH_NPC, 16, y - 32, DialogueWheelE_AttachNPC ~= false, function(self)
        DialogueWheelE_AttachNPC = self:GetChecked() and true or false
        if not DialogueWheelE_AttachNPC then DWE.StopFollow() end
    end)
    AddText(L.ATTACH_TIP, 42, y - 58, "GameFontDisableSmall")
    AddCheck(L.LOCK, 16, y - 76, DWE.IsLocked(), function(self)
        DialogueWheelE_Locked = self:GetChecked() and true or false
        DWE.ApplyLock()
    end)
    local resetBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    resetBtn:SetPoint("TOPLEFT", 300, y - 34)
    resetBtn:SetSize(240, 24)
    resetBtn:SetText(L.NPC_RESET)
    resetBtn:SetScript("OnClick", function() DWE.ResetNPCOffset() end)
    AddText(L.WHEEL_SIDE, 300, y - 72, "GameFontHighlightSmall")
    AddGroup({
        { id = "right", label = L.SIDE_RIGHT },
        { id = "left", label = L.SIDE_LEFT },
    }, 300, y - 88, 26, DialogueWheelE_WheelSide == "left" and "left" or "right", function(id)
        DialogueWheelE_WheelSide = (id == "left") and "left" or nil
        if not DialogueWheelE_Pos then DWE.RestorePosition() end
        if choiceBox:IsShown() then DWE.UpdateVisuals() end
        DWE.Repin()
    end, 1, 120)

    ---------------------------------------------------------------- Commandes
    y = y - 150
    AddSection(L.SEC_KEYS, y)
    local keysY = y - 32
    local useBlizzCb = AddCheck(L.KEY_USE_BLIZZ, 16, keysY, DialogueWheelE_UseBlizzKey ~= false, nil)
    local interactBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    interactBtn:SetPoint("TOPLEFT", 20, keysY - 30)
    interactBtn:SetSize(240, 24)
    AddCheck(L.ESC_CLOSE, 300, keysY, DialogueWheelE_EscClose ~= false, function(self)
        DialogueWheelE_EscClose = self:GetChecked() and true or false
    end)
    AddCheck(L.WHEEL_SCROLL, 300, keysY - 28, DialogueWheelE_WheelScroll ~= false, function(self)
        DialogueWheelE_WheelScroll = self:GetChecked() and true or false
        DWE.RefreshBindings()
    end)

    ---------------------------------------------------------------- Spoken
    y = keysY - 76
    AddSection(L.SEC_SPOKEN, y)
    local spokenOn = DWE.SpokenFocus and DWE.SpokenFocus.Available()
    local function Grey(w, on)
        if not w then return end
        if w.Enable then if on then w:Enable() else w:Disable() end end
        if w.SetAlpha then w:SetAlpha(on and 1 or 0.5) end
    end
    if not spokenOn then AddText(L.SPOKEN_NEEDED, 200, y - 4, "GameFontDisableSmall") end
    local spokenThemeCheck = AddCheck(L.SPOKEN_THEME, 16, y - 32, DialogueWheelE_SpokenTheme == true, function(self)
        DialogueWheelE_SpokenTheme = self:GetChecked() and true or false
        DWE.RefreshSpoken()
    end)
    local toggleLbl, toggleBtn
    -- Choix "Spoken" dans la roue (bascule bulle / lecteur de Spoken) : cache par defaut.
    local spokenCheck = AddCheck(L.SPOKEN_CHOICE, 16, y - 60, DialogueWheelE_SpokenChoice == true, function(self)
        DialogueWheelE_SpokenChoice = self:GetChecked() and true or false
        DWE.RefreshBindings()
    end)
    toggleLbl = AddText(L.KEY_TOGGLE, 20, y - 94, "GameFontHighlightSmall")
    toggleBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    toggleBtn:SetPoint("TOPLEFT", toggleLbl, "BOTTOMLEFT", 0, -4)
    toggleBtn:SetSize(240, 24)
    Grey(spokenThemeCheck, spokenOn)
    Grey(spokenCheck, spokenOn)
    Grey(toggleBtn, spokenOn)
    if toggleLbl.SetAlpha then toggleLbl:SetAlpha(spokenOn and 1 or 0.5) end

    local function RefreshKeyButtons()
        local useBlizz = DialogueWheelE_UseBlizzKey ~= false
        useBlizzCb:SetChecked(useBlizz)
        if useBlizz then
            interactBtn:SetText(KeyLabel(DWE.GetEffectiveInteractKey()) .. L.KEY_BLIZZ_TAG)
            interactBtn:Disable()
        else
            interactBtn:SetText(L.KEY_CUSTOM .. " " .. KeyLabel(DialogueWheelE_InteractKey))
            interactBtn:Enable()
        end
        toggleBtn:SetText(KeyLabel(DialogueWheelE_ToggleKey))
    end

    useBlizzCb:SetScript("OnClick", function(self)
        DialogueWheelE_UseBlizzKey = self:GetChecked() and true or false
        RefreshKeyButtons()
        DWE.RefreshBindings()
    end)

    -- Capture de touche : la prochaine touche pressee (avec Maj/Ctrl/Alt) ; Echap = aucune.
    local function CaptureKey(btn, onKey)
        btn:SetText(L.KEY_PRESS)
        btn:EnableKeyboard(true)
        btn:SetScript("OnKeyDown", function(self, key)
            if MODIFIER_KEYS[key] then return end
            if key == "ESCAPE" then
                onKey("")
            else
                local mod = (IsShiftKeyDown() and "SHIFT-" or "") .. (IsControlKeyDown() and "CTRL-" or "") .. (IsAltKeyDown() and "ALT-" or "")
                onKey(mod .. key)
            end
            self:EnableKeyboard(false)
            self:SetScript("OnKeyDown", nil)
            RefreshKeyButtons()
            DWE.RefreshBindings()
        end)
    end
    interactBtn:SetScript("OnClick", function(self)
        CaptureKey(self, function(k) DialogueWheelE_InteractKey = k end)
    end)
    toggleBtn:SetScript("OnClick", function(self)
        CaptureKey(self, function(k) DialogueWheelE_ToggleKey = k end)
    end)
    panel:SetScript("OnShow", function()
        RefreshKeyButtons()
        RefreshTiles()
    end)
    RefreshKeyButtons()
    p:SetHeight(-(y - 150) + 30)

    if Settings and Settings.RegisterCanvasLayoutCategory then
        local cat = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(cat)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end
