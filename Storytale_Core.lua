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

--------------------------------------------------------------------------------
-- Erreurs (/storytale errors) : une erreur Lua dans un code qui tourne en continu (a chaque image)
-- peut passer inapercue et s'accumuler (memoire, ralentissements). Les fonctions surveillees
-- (DWE.Guard) gardent une trace de chaque erreur : combien de fois, ou, quand. La premiere de
-- chaque sorte est aussi montree au gestionnaire d'erreurs du jeu (et a BugSack s'il est la).
-- Une partie qui echoue en boucle (plus de 30 fois en 5 s) est coupee jusqu'au /reload.
--------------------------------------------------------------------------------
DWE.errors = { byKey = {}, order = {}, total = 0, off = {}, notified = false }
function DWE.ReportError(where, err)
    local E = DWE.errors
    local msg = tostring(err)
    local key = where .. "|" .. msg
    local e = E.byKey[key]
    local now = GetTime and GetTime() or 0
    if not e then
        e = { where = where, msg = msg, count = 0, first = now }
        E.byKey[key] = e
        E.order[#E.order + 1] = e
        local handler = geterrorhandler and geterrorhandler()
        if handler then pcall(handler, "Storytale (" .. where .. "): " .. msg) end
    end
    e.count, e.last = e.count + 1, now
    E.total = E.total + 1
    if not E.notified then
        E.notified = true
        print("|cff33ff99Storytale|r: " .. (L.ERR_NOTICE or "an error occurred. Type /storytale errors for details."))
    end
    -- Rafale : partie coupee (seulement pour ce qui tourne en continu, pas les evenements).
    local burst = E.burst or {}
    E.burst = burst
    local b = burst[where]
    if not b or now - b.t > 5 then b = { t = now, n = 0 }; burst[where] = b end
    b.n = b.n + 1
    return b.n
end
function DWE.Guard(where, fn, canStop)
    if type(fn) ~= "function" then return fn end
    return function(...)
        if DWE.errors.off[where] then return end
        local ok, err = pcall(fn, ...)
        if not ok then
            local n = DWE.ReportError(where, err)
            if canStop and n > 30 and not DWE.errors.off[where] then
                DWE.errors.off[where] = true
                print("|cff33ff99Storytale|r: " .. string.format(L.ERR_LOOP or "%s keeps failing and was stopped until /reload.", where))
            end
        end
    end
end
-- Surveille les scripts d'une fenetre (OnUpdate : coupe si erreur en boucle ; OnEvent : jamais).
function DWE.GuardScripts(frame, name)
    if type(frame) ~= "table" or not frame.GetScript then return end
    for _, s in ipairs({ "OnUpdate", "OnEvent" }) do
        local fn = frame:GetScript(s)
        if fn and not (frame.dweGuarded and frame.dweGuarded[s]) then
            frame.dweGuarded = frame.dweGuarded or {}
            frame.dweGuarded[s] = true
            local g, key = DWE.Guard(name .. ":" .. s, fn, s == "OnUpdate"), name .. ":" .. s
            -- Mesure aussi ces scripts pendant /storytale perf (temps par seconde, appels).
            frame:SetScript(s, function(...)
                local perf = DWE.perf
                if not (perf and perf.on and debugprofilestop) then return g(...) end
                local t0 = debugprofilestop()
                g(...)
                local dt = debugprofilestop() - t0
                -- Evenements : detail par evenement (lequel coute a l'ouverture d'un livre).
                local k = key
                if s == "OnEvent" then k = name .. ":" .. tostring((select(2, ...))) end
                perf.t[k] = (perf.t[k] or 0) + dt
                perf.n[k] = (perf.n[k] or 0) + 1
                perf.mx = perf.mx or {}
                if dt > (perf.mx[k] or 0) then perf.mx[k] = dt end
            end)
        end
    end
end
function DWE.ErrorsReport(arg)
    local E = DWE.errors
    if arg == "clear" then
        E.byKey, E.order, E.total, E.off, E.notified = {}, {}, 0, {}, false
        print("|cff33ff99Storytale|r: " .. (L.ERR_CLEARED or "errors cleared."))
        return
    end
    if #E.order == 0 then
        print("|cff33ff99Storytale|r: " .. (L.ERR_NONE or "no error this session."))
        return
    end
    local list = {}
    for _, e in ipairs(E.order) do list[#list + 1] = e end
    table.sort(list, function(a, b) return a.count > b.count end)
    print(string.format("|cff33ff99Storytale|r: %d (%d)", E.total, #list))
    local now = GetTime and GetTime() or 0
    for i, e in ipairs(list) do
        if i > 10 then break end
        print(string.format("  |cffff6060x%d|r %s%s - %s (%ds)", e.count, e.where,
            E.off[e.where] and " |cffff6060[off]|r" or "", e.msg, math.floor(now - (e.last or now))))
    end
end
function DWE.Prof(name, fn)
    fn = DWE.Guard and DWE.Guard(name, fn, true) or fn
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
do
-- Pendant la mesure : chaque fonction de DWE (et de ses modules) est chronometree, puis remise
-- telle quelle. Temps "inclusif" : une fonction compte aussi ce qu'elle appelle.
local perfWrapped
local function PerfWrapAll(perf)
    perfWrapped = {}
    local mods = { [""] = DWE }
    for _, m in ipairs({ "SpokenFocus", "Bubble", "Native" }) do
        if type(DWE[m]) == "table" then mods[m .. "."] = DWE[m] end
    end
    for prefix, t in pairs(mods) do
        for k, fn in pairs(t) do
            if type(fn) == "function" and k ~= "StartPerf" and k ~= "Guard" then
                local key = "f:" .. prefix .. k
                local w = { t, k, fn }
                perfWrapped[#perfWrapped + 1] = w
                w[4] = function(...)
                    if not perf.on then return fn(...) end
                    local t0 = debugprofilestop()
                    local r = { n = 0 }
                    local function keep(...) r.n = select("#", ...); for i = 1, r.n do r[i] = (select(i, ...)) end end
                    keep(fn(...))
                    local dt = debugprofilestop() - t0
                    perf.t[key] = (perf.t[key] or 0) + dt
                    perf.n[key] = (perf.n[key] or 0) + 1
                    if dt > (perf.mx[key] or 0) then perf.mx[key] = dt end
                    return unpack(r, 1, r.n)
                end
                t[k] = w[4]
            end
        end
    end
end
local function PerfUnwrapAll()
    for _, w in ipairs(perfWrapped or {}) do
        -- Remplacee entre-temps par l'addon : on garde la nouvelle.
        if w[1][w[2]] == w[4] then w[1][w[2]] = w[3] end
    end
    perfWrapped = nil
end

function DWE.StartPerf(out, seconds, baseline, deep)
    local perf = DWE.perf
    perf.t, perf.n, perf.mx, perf.on = {}, {}, {}, true
    if deep and debugprofilestop then PerfWrapAll(perf) end
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
        PerfUnwrapAll()
        local spoken = type(rawget(_G, "Spoken")) == "table"
        out(("Theme : %s | Spoken detecte : %s | bulle affichee : %s"):format(tostring(DialogueWheelE_Theme),
            spoken and "oui" or "non", (DWE.bubble and DWE.bubble:IsShown()) and "oui" or "non"))
        out(("Pendant l'ecriture : %.0f images/s%s | pire image : %.0f ms | images > 50 ms : %d"):format(
            frames / total, baseline and (" (avant : %.0f)"):format(baseline) or "", worst * 1000, slow))
        local names = {}
        for k in pairs(perf.t) do names[#names + 1] = k end
        table.sort(names, function(a, b) return perf.t[a] > perf.t[b] end)
        for i, k in ipairs(names) do
            if i > 18 then break end
            -- Total sur la mesure, nombre d'appels et le plus long (un seul gros appel = saccade).
            out(("  %s : %.0f ms en tout, %d appels, le plus long %.0f ms"):format(k, perf.t[k], perf.n[k], perf.mx[k] or 0))
        end
    end)
end
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
    DWE.StartPerf(perf.out, 8, perf.baseline, true)
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
-- Repere invisible au haut de l'apercu (sans objectifs, le reste s'y aligne : meme largeur et
-- meme centrage que le cadre, au lieu de coller au bord gauche des choix).
DWE.questTop = CreateFrame("Frame", nil, choiceBox)
DWE.questTop:SetPoint("TOPLEFT", objLine, "TOPLEFT", 0, 0)
DWE.questTop:SetPoint("TOPRIGHT", objLine, "TOPRIGHT", 0, 0)
DWE.questTop:SetHeight(1)

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
-- L'apercu de quete n'est plus aussi etroit que les bulles de choix : au moins QUEST_MIN_W,
-- etendu du cote oppose au PNJ (vers la droite, ou la gauche si la roue est a gauche).
DWE.QUEST_MIN_W, DWE.QUEST_MAX_W, DWE.QUEST_LINES = 320, 460, 6
-- Largeur automatique selon le texte : peu de texte -> aussi etroit que la roue ; beaucoup ->
-- s'elargit (jusqu'a QUEST_MAX_W) pour tenir en environ QUEST_LINES lignes.
function DWE.AutoQuestWidth()
    -- Largeur du contenu : lignes courtes (recompenses, objets) a leur taille, objectifs longs
    -- repartis sur environ QUEST_LINES lignes. Jamais plus que QUEST_MAX_W.
    local function Full(fs)
        if not (fs and fs:IsShown()) then return 0 end
        local t = fs:GetText()
        if type(t) ~= "string" or t == "" then return 0 end
        local ok, w = pcall(fs.GetUnboundedStringWidth or fs.GetStringWidth, fs)
        return (ok and type(w) == "number") and w or 0
    end
    local need = 0
    local obj = Full(objLine)
    if obj > 0 then need = math.max(need, math.min(obj, math.max(obj / DWE.QUEST_LINES + 24, 220))) end
    for _, fs in ipairs({ rewLine, reqHeader, chooseHeader }) do need = math.max(need, Full(fs)) end
    for _, b in ipairs(DWE.rewardButtonsList or {}) do
        if b:IsShown() and b.text then need = math.max(need, Full(b.text) + 40) end
    end
    if need <= 0 then return math.max((choiceBox:GetWidth() or 0) - 10, 180) end
    -- Le cadre epouse le contenu (centre sous les choix) : pas de vide a droite.
    return math.floor(math.max(60, math.min(DWE.QUEST_MAX_W, need + 2)))
end
function DWE.SizeQuestInfo()
    -- Largeur choisie avec la poignee de l'apercu, sinon automatique.
    local auto = DialogueWheelE_QuestAuto ~= false
    local w = (not auto and tonumber(DialogueWheelE_QuestWidth)) or DWE.AutoQuestWidth()
    -- Largeur automatique : pas de poignee ; decochee : poignee pour la regler a la main.
    if DWE.questHost then DWE.questHost.dweNoGrip = auto or nil end
    objLine:ClearAllPoints()
    if w <= (choiceBox:GetWidth() or 0) then
        -- Pas plus large que les choix : centre sous eux.
        objLine:SetPoint("TOP", choiceBox, "BOTTOM", 1, -18)
    elseif DWE.WheelLeft and DWE.WheelLeft() then
        objLine:SetPoint("TOPRIGHT", choiceBox, "BOTTOMRIGHT", -4, -18)
    else
        objLine:SetPoint("TOPLEFT", choiceBox, "BOTTOMLEFT", 6, -18)
    end
    objLine:SetWidth(w)
end

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
    DWE.GW2_ON = loaded and loaded("GW2_UI") and true or false
end
-- Habillage GW2 UI : les images de bulle de GW2 UI installe chez le joueur (lues dans son
-- dossier, jamais copiees dans Storytale), posees comme GW2 UI pose les siennes : un fond et
-- huit morceaux de bord autour. Seulement si GW2 UI est charge.
DWE.GW2_ART = "Interface\\AddOns\\GW2_UI\\textures\\chat\\chatbubbles\\"
DWE.GW2_PIECES = {
    -- cle, image, coordonnees, largeur, hauteur, point, point du fond
    { "top", "borderhori-inverted", { 0, 0.8515625, 0, 0.34375 }, nil, 5.5 },
    { "bottom", "borderhori-inverted", { 0, 0.8515625, 0.6875, 1 }, nil, 5 },
    { "right", "border-inverted", { 0.1484375, 0.3515625, 0, 0.58203125 }, 13, nil },
    { "left", "border-inverted", { 0, 0.1171875, 0, 0.58203125 }, 7.5, nil },
    { "tr", "border-inverted", { 0.484375, 0.609375, 0, 0.021484375 }, 8, 5.5, "BOTTOMLEFT", "TOPRIGHT" },
    { "tl", "border-inverted", { 0.328125, 0.4453125, 0, 0.021484375 }, 7.5, 5.5, "BOTTOMRIGHT", "TOPLEFT" },
    { "bl", "border-inverted", { 0.671875, 0.7890625, 0, 0.01953125 }, 7.5, 5, "TOPRIGHT", "BOTTOMLEFT" },
    { "br", "border-inverted", { 0.828125, 1, 0, 0.01953125 }, 11, 5, "TOPLEFT", "BOTTOMRIGHT" },
}
DWE.GW2_INSET = { 7.5, 5.5, 13, 5 } -- place des bords autour du fond (gauche, haut, droite, bas)
function DWE.Gw2Decor(owner, layer, sub)
    local d = { list = {}, borders = {} }
    local bg = owner:CreateTexture(nil, layer or "BACKGROUND", nil, sub or -6)
    bg:SetTexture(DWE.GW2_ART .. "background-inverted.png")
    bg:SetTexCoord(0, 0.8515625, 0, 0.58203125)
    d.bg = bg
    d.list[1] = bg
    for _, p in ipairs(DWE.GW2_PIECES) do
        local t = owner:CreateTexture(nil, layer or "BACKGROUND", nil, sub or -6)
        t:SetTexture(DWE.GW2_ART .. p[2] .. ".png")
        t:SetTexCoord(p[3][1], p[3][2], p[3][3], p[3][4])
        t.dweW, t.dweH = p[4], p[5]
        local k = p[1]
        if k == "top" then
            t:SetPoint("BOTTOMLEFT", bg, "TOPLEFT"); t:SetPoint("BOTTOMRIGHT", bg, "TOPRIGHT")
        elseif k == "bottom" then
            t:SetPoint("TOPLEFT", bg, "BOTTOMLEFT"); t:SetPoint("TOPRIGHT", bg, "BOTTOMRIGHT")
        elseif k == "right" then
            t:SetPoint("TOPLEFT", bg, "TOPRIGHT"); t:SetPoint("BOTTOMLEFT", bg, "BOTTOMRIGHT")
        elseif k == "left" then
            t:SetPoint("TOPRIGHT", bg, "TOPLEFT"); t:SetPoint("BOTTOMRIGHT", bg, "BOTTOMLEFT")
        else
            t:SetPoint(p[6], bg, p[7])
        end
        d[k] = t
        d.list[#d.list + 1] = t
        d.borders[#d.borders + 1] = t
    end
    return d
end
-- Echelle des bulles de GW2 UI par rapport a `frame` : elles sont dans le monde (WorldFrame), pas
-- dans l'interface. A notre echelle (souvent reduite par GW2 UI), leurs filets faisaient moins
-- d'un pixel et scintillaient quand la roue suivait le PNJ.
function DWE.Gw2Scale(frame)
    local okW, ws = pcall(function() return WorldFrame:GetEffectiveScale() end)
    local okF, fs = pcall(frame.GetEffectiveScale, frame)
    if okW and okF and type(ws) == "number" and type(fs) == "number" and fs > 0 then
        local k = ws / fs
        if k >= 0.5 and k <= 4 then return k end
    end
    return 1
end
-- Pose le fond a l'interieur de `rel` (marges gauche, haut, droite, bas ; `inset` : plus la place
-- des bords). Les bords sont a l'echelle des bulles de GW2 UI.
function DWE.Gw2Place(d, rel, l, t, r, b, inset)
    local k = DWE.Gw2Scale(rel)
    if inset then
        local g = DWE.GW2_INSET
        -- (marges a la taille d'origine : le fond garde sa place, les bords agrandis debordent un peu)
        l, t, r, b = (l or 0) + g[1], (t or 0) + g[2], (r or 0) + g[3], (b or 0) + g[4]
    end
    d.bg:ClearAllPoints()
    d.bg:SetPoint("TOPLEFT", rel, "TOPLEFT", l, -t)
    d.bg:SetPoint("BOTTOMRIGHT", rel, "BOTTOMRIGHT", -r, b)
    -- Bords en pixels entiers (et accroches aux pixels, comme le jeu le fait par defaut) : une
    -- epaisseur fractionnaire changeait d'un pixel a l'autre quand la roue suivait le PNJ, et
    -- les filets clairs scintillaient.
    local px = 1
    local okS, es = pcall(rel.GetEffectiveScale, rel)
    local okP, _, ph = pcall(function() return GetPhysicalScreenSize() end)
    if okS and okP and type(es) == "number" and type(ph) == "number" and es > 0 and ph > 0 then
        px = 768 / ph / es -- taille d'un pixel de l'ecran, en points de `rel`
    end
    local function Snap(v) return math.max(1, math.floor(v / px + 0.5)) * px end
    for _, x in ipairs(d.list) do
        if x.dweW then x:SetWidth(Snap(x.dweW * k)) end
        if x.dweH then x:SetHeight(Snap(x.dweH * k)) end
        x:Show()
    end
end
function DWE.Gw2Hide(d)
    if d then for _, x in ipairs(d.list) do x:Hide() end end
end
-- Couleurs : fond (multiplie), bords (teinte, comme GW2 UI teinte les siens), opacite.
function DWE.Gw2Color(d, bgMul, edge, alpha)
    local m = bgMul or 1
    d.bg:SetVertexColor(m, m, m, alpha or 1)
    local e = edge or { 1, 1, 1 }
    for _, t in ipairs(d.borders) do t:SetVertexColor(e[1], e[2], e[3], alpha or 1) end
end
-- Taille d'un pixel de l'ecran en points de `frame`, et arrondi a un pixel entier.
function DWE.PixelSize(frame)
    local okS, es = pcall(frame.GetEffectiveScale, frame)
    local okP, _, ph = pcall(function() return GetPhysicalScreenSize() end)
    if okS and okP and type(es) == "number" and type(ph) == "number" and es > 0 and ph > 0 then
        return 768 / ph / es
    end
    return nil
end
function DWE.PixelRound(frame, v)
    local u = DWE.PixelSize(frame)
    if not u or type(v) ~= "number" then return v end
    return math.floor(v / u + 0.5) * u
end
-- La roue qui suit le PNJ : posee sur un pixel entier de l'ecran. Au milieu de deux pixels, les
-- traits fins (bords des choix, filets) changeaient d'eclat a chaque image : ils scintillaient.
function DWE.SnapToPixels(frame)
    local okL, l = pcall(frame.GetLeft, frame)
    local okT, t = pcall(frame.GetTop, frame)
    if not (okL and okT and type(l) == "number" and type(t) == "number") then return end
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", DWE.PixelRound(frame, l), DWE.PixelRound(frame, t))
end
-- Theme GW2 UI dessine avec les vraies images de GW2 UI (sinon : dessin propre a Storytale).
function DWE.Gw2Native(style)
    return style == "gw2" and DWE.GW2_ON and true or false
end

-- Theme "GW2 UI" range apres Ambre dans la liste des options.
function DWE.AddGw2Theme(list)
    for i = 1, #list do
        if list[i].id == "amber" then table.insert(list, i + 1, { id = "gw2", key = "THEME_GW2", thumb = "Gw2" }) return end
    end
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
for id, m in pairs({ parchment = "|cff9c1a1a", folio = "|cff9c1a1a", dui_brown = "|cff9c1a1a",
    velin = "|cffa8280f", arcane = "|cff2a55c8", sylvan = "|cff3f7d0c" }) do
    if THEME_STYLES[id] then THEME_STYLES[id].lightMark = m end
end
-- Couleur du mot lu par Spoken dans un theme : la sienne, sinon celle de son titre.
function DWE.ThemeMark(cfg)
    if type(cfg) ~= "table" then return nil end
    if cfg.mark then return cfg.mark end
    -- Papier clair : le titre est presque de la couleur du texte, le mot lu ne se verrait pas.
    -- Une encre franche, propre a chaque papier.
    if cfg.lightMark then return cfg.lightMark end
    local c = cfg.hdr
    if type(c) ~= "table" then return nil end
    -- Page claire (plaques, page de livre...) dont le titre se confond avec le texte : le rouge
    -- profond de Spoken pour les pages claires.
    local t = cfg.body
    if cfg.shadow == 0 and type(t) == "table"
        and math.abs(c[1] - t[1]) + math.abs(c[2] - t[2]) + math.abs(c[3] - t[3]) < 0.6 then
        return "|cff9c1a1a"
    end
    return string.format("|cff%02x%02x%02x", math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
end

-- Themes qui conviennent a un livre ; les autres (bulles, sans cadre, voile) sont remplaces
-- par le Velin dore pendant la lecture d'un livre.
local BOOK_THEMES = {
    velin = true, arcane = true, sylvan = true, starry = true,
    parchment = true, parchment_dark = true, folio = true, folio_dark = true, dui_brown = true, dui_dark = true, glass = true,
}

local function CurrentTheme()
    if DialogueWheelE_Theme == "scroll" then DialogueWheelE_Theme = "parchment" end -- theme retire
    local t = DialogueWheelE_Theme or "bubble"
    -- Theme DialogueUI : le parchemin vient de DialogueUI, la roue de choix reste sans cadre.
    if t == "dui" then
        t = (DWE.ConvToDUI and DWE.ConvToDUI() and not DWE.bookMode) and "transparent" or "dui_brown"
    end
    if (t == "dui_brown" or t == "dui_dark") and not DWE.DUI_ON then t = "bubble" end
    if DWE.bookMode and not BOOK_THEMES[t] then return "velin" end
    return t
end

DWE.CurrentThemeId = CurrentTheme

-- Lecture d'un livre ou non : change le theme affiche si besoin.
function DWE.SetBookMode(on)
    on = on and true or false
    if DWE.bookMode == on then return end
    local function Look() return CurrentTheme() .. tostring(DWE.BubbleSkin and DWE.BubbleSkin() ~= nil) end
    local before = Look()
    -- Livre de l'addon referme : DialogueUI joue l'animation de fermeture de son propre livre
    -- (le parchemin) ; il reste cache le temps qu'elle se termine.
    if not on and DWE.BookByAddon() then
        DWE.duiHoldUntil = (GetTime and GetTime() or 0) + 1.5
        if C_Timer and C_Timer.After then
            C_Timer.After(1.6, function() if DWE.RefreshHiddenFrames then DWE.RefreshHiddenFrames() end end)
        end
    end
    if (DWE.bookMode and true or false) ~= (on and true or false) then DWE.LookLog("mode livre " .. tostring(on)) end
    DWE.bookMode = on
    if DWE.RefreshBindings then DWE.RefreshBindings() end -- croix gauche/droite : pages ou jeu
    if not on then DWE.bookTurnLast = nil end -- livre ferme : le prochain s'ouvre sans bruit de page
    if Look() ~= before and DWE.OnThemeChanged then DWE.OnThemeChanged() end
    if DWE.RefreshSpoken then DWE.RefreshSpoken() end
    if DWE.RefreshHiddenFrames then DWE.RefreshHiddenFrames() end
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
    common = { 0.16, 0.09, 0.03 }, qualityDim = 0.80, shadow = 0,
    hex = { hdr = "|cff8c3300", body = "|cff0a0400", num = "|cff2b1a0b", rep = "|cff7a5214", ok = "|cff8a4b14", bad = "|cff9e1b1b" },
}
-- Murmure : couleurs des chuchotements du jeu (rose / violet).
local WHEEL_WHISPER = {
    normal = { 0.96, 0.88, 0.98 }, selected = { 1, 0.62, 1 }, disabled = { 0.55, 0.48, 0.58 },
    goodbye = { 0.75, 0.66, 0.78 }, goodbyeSel = { 1, 0.45, 0.6 }, dim = { 0.82, 0.74, 0.86 },
    common = nil, shadow = 1,
    hex = { hdr = "|cffff9cff", body = "|cfff5e6f8", num = "|cffffffff", rep = "|cffc0a0ff", ok = "|cffb0ff9c", bad = "|cffff6080" },
}
-- Murmure en d'autres couleurs (Emeraude, Rubis, Saphir, Ambre) : memes formes, autre teinte.
DWE.WHISPER_COLORS = {
    emerald = { art = "Emerald", text = { 0.66, 1, 0.76 }, palette = {
        normal = { 0.88, 0.98, 0.89 }, selected = { 0.62, 1, 0.73 }, disabled = { 0.48, 0.58, 0.48 },
        goodbye = { 0.66, 0.78, 0.67 }, goodbyeSel = { 1, 0.45, 0.45 }, dim = { 0.74, 0.86, 0.74 },
        common = nil, shadow = 1,
        hex = { hdr = "|cff9cffba", body = "|cffe6f7e8", num = "|cffffffff", rep = "|cffc2ffa1", ok = "|cffb0ff9c", bad = "|cffff6080" },
    } },
    ruby = { art = "Ruby", text = { 1, 0.66, 0.67 }, palette = {
        normal = { 0.98, 0.88, 0.9 }, selected = { 1, 0.62, 0.64 }, disabled = { 0.58, 0.48, 0.51 },
        goodbye = { 0.78, 0.66, 0.69 }, goodbyeSel = { 1, 0.45, 0.45 }, dim = { 0.86, 0.74, 0.78 },
        common = nil, shadow = 1,
        hex = { hdr = "|cffff9ca1", body = "|cfff7e6eb", num = "|cffffffff", rep = "|cffffa1e3", ok = "|cffb0ff9c", bad = "|cffff6080" },
    } },
    sapphire = { art = "Sapphire", text = { 0.66, 0.79, 1 }, palette = {
        normal = { 0.88, 0.94, 0.98 }, selected = { 0.62, 0.76, 1 }, disabled = { 0.48, 0.55, 0.58 },
        goodbye = { 0.66, 0.74, 0.78 }, goodbyeSel = { 1, 0.45, 0.45 }, dim = { 0.74, 0.83, 0.86 },
        common = nil, shadow = 1,
        hex = { hdr = "|cff9cc2ff", body = "|cffe6f0f7", num = "|cffffffff", rep = "|cffa1fffa", ok = "|cffb0ff9c", bad = "|cffff6080" },
    } },
    amber = { art = "Amber", text = { 1, 0.87, 0.66 }, palette = {
        normal = { 0.98, 0.92, 0.88 }, selected = { 1, 0.86, 0.62 }, disabled = { 0.58, 0.51, 0.48 },
        goodbye = { 0.78, 0.7, 0.66 }, goodbyeSel = { 1, 0.45, 0.45 }, dim = { 0.86, 0.77, 0.74 },
        common = nil, shadow = 1,
        hex = { hdr = "|cffffd99c", body = "|cfff7ede6", num = "|cffffffff", rep = "|cffffa1a3", ok = "|cffb0ff9c", bad = "|cffff6080" },
    } },
    -- GW2 UI : bande bleu nuit et texte blanc, dans l'esprit des bulles de GW2 UI (dessin propre a
    -- Storytale, aucune image de GW2 UI). Propose dans la liste seulement si GW2 UI est charge.
    gw2 = { art = "Gw2", text = { 0.96, 0.97, 0.98 }, palette = {
        normal = { 0.90, 0.92, 0.95 }, selected = { 1, 0.82, 0.42 }, disabled = { 0.50, 0.54, 0.60 },
        goodbye = { 0.70, 0.74, 0.80 }, goodbyeSel = { 1, 0.45, 0.45 }, dim = { 0.76, 0.80, 0.86 },
        common = nil, shadow = 1,
        hex = { hdr = "|cffffd16b", body = "|cfff2f4f7", num = "|cffffffff", rep = "|cffa1d2ff", ok = "|cffb0ff9c", bad = "|cffff6080" },
    } },
}
-- Verre fume, Encre et or : palette par defaut, mais surbrillance or pale (couleur du nom du PNJ).
DWE.HDR_PALETTE = {
    glass = setmetatable({ selected = { 1, 0.84, 0.50 } }, { __index = WHEEL_DEFAULT }),
    inkgold = setmetatable({ selected = { 1, 0.84, 0.47 } }, { __index = WHEEL_DEFAULT }),
}
local LIGHT_BACKGROUND = { parchment = true, folio = true, dui_brown = true, velin = true, arcane = true, sylvan = true }

-- Habillage du lecteur Spoken pour les themes sans cadre "bloc" (bulles, Sans cadre, Cinematique) :
-- chacun le sien, dans ses propres couleurs. Les bulles prennent leur image de bulle en cadre.
do
    local function RGB(hex)
        local r, g, b = tostring(hex):match("|c%x%x(%x%x)(%x%x)(%x%x)")
        if not r then return { 1, 1, 1 } end
        return { tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255 }
    end
    local function Gem(art, hex)
        local hdr = RGB(hex.hdr)
        return {
            tex = ADDON_PATH .. "Bubble" .. art .. ".png", slice = { 16, 16, 16, 16 }, pad = { 16, 14, 16, 14 },
            tint = { 1, 1, 1, 1 }, div = { hdr[1], hdr[2], hdr[3], 0.35 },
            hdr = hdr, body = RGB(hex.body), mark = hex.hdr, shadow = 1, matchBubble = true,
        }
    end
    THEME_STYLES.spk_whisper = Gem("Whisper", WHEEL_WHISPER.hex)
    for id, c in pairs(DWE.WHISPER_COLORS) do THEME_STYLES["spk_" .. id] = Gem(c.art, c.palette.hex) end
    THEME_STYLES.spk_gw2.gw2native = true
    THEME_STYLES.spk_fantasy = {
        tex = ADDON_PATH .. "BubbleFantasy.png", slice = { 24, 24, 24, 24 }, pad = { 22, 18, 22, 18 },
        tint = { 1, 1, 1, 1 }, div = { 0.40, 0.22, 0.08, 0.45 },
        hdr = { 0.40, 0.16, 0.04 }, body = { 0.18, 0.10, 0.04 }, mark = "|cff9c1a1a", shadow = 0, matchBubble = true,
    }
    -- Bulle d'Azeroth : la bulle de discussion du jeu.
    THEME_STYLES.spk_bubble = {
        chatbubble = true, hdr = { 1, 0.82, 0 }, body = { 1, 1, 1 }, mark = "|cffffd100", shadow = 1,
    }
    -- Sans cadre et Cinematique : un simple voile, sans bordure.
    -- Sans cadre : comme les conversations, pas de fond, le texte et son ombre seulement.
    THEME_STYLES.spk_transparent = {
        none = true, hdr = { 1, 0.82, 0 }, body = { 1, 1, 1 }, mark = "|cffffd100", shadow = 1,
    }
    -- Cinematique : une bande noire de film, deux filets dores fins en haut et en bas.
    THEME_STYLES.spk_cinema = {
        bg = { 0, 0, 0, 0.92 }, noBorder = true, rules = { 0.85, 0.66, 0.32, 0.55 },
        hdr = { 0.85, 0.66, 0.32 }, body = { 0.95, 0.91, 0.82 }, mark = "|cffd9a852", shadow = 1,
    }
end

-- Themes en bulle : la replique du PNJ dans une bulle au-dessus de lui et, avec l'option
-- "habiller la roue", chaque choix dans sa petite bulle. Les trois bulles d'origine le sont
-- toujours ; les autres themes (sauf Sans cadre et Cinematique) aussi, sauf si l'option
-- "Afficher les themes en cadre" est cochee.
-- bubble = style de Bubble.lua, pill = images Pill<pill>*.png, palette = couleurs des choix.
local BUBBLE_SKINS = {
    bubble = { bubble = "game", pill = "game", palette = WHEEL_DEFAULT, always = true },
    bubble_npc = { bubble = "game_npc", pill = "game", palette = WHEEL_DEFAULT, always = true },
    bubble_fantasy = { bubble = "fantasy", pill = "fantasy", palette = WHEEL_INK, always = true, optFont = true },
    whisper = { bubble = "whisper", pill = "whisper", palette = WHEEL_WHISPER, always = true },
}
for id, c in pairs(DWE.WHISPER_COLORS) do
    BUBBLE_SKINS[id] = { bubble = id, pill = id, palette = c.palette, always = true }
end
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

-- Theme Personnalise : quatre couleurs au choix du joueur (fond, contour, texte, choix surligne).
-- Ses images sont blanches, en deux calques (remplissage, contour) teintes en jeu.
do
    DWE.CUSTOM_DEFAULT = {
        bg = { 0.07, 0.07, 0.09 }, border = { 0.45, 0.45, 0.50 }, text = { 0.95, 0.92, 0.85 }, sel = { 1, 0.85, 0.25 },
    }
    DWE.CUSTOM_FILL_ALPHA = 0.86
    local function Hex(c)
        return string.format("|cff%02x%02x%02x", math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
    end
    local function Mix(a, b, t) return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t } end
    local function Valid(c)
        return type(c) == "table" and type(c[1]) == "number" and type(c[2]) == "number" and type(c[3]) == "number"
    end
    -- Couleur `key` du theme Personnalise (reglage du joueur, sinon celle par defaut).
    function DWE.CustomColor(key)
        local saved = type(DialogueWheelE_CustomColors) == "table" and DialogueWheelE_CustomColors[key]
        local c = Valid(saved) and saved or DWE.CUSTOM_DEFAULT[key]
        return { c[1], c[2], c[3] }
    end
    -- Couleur du mot lu par la voix de Spoken dans la bulle (pastille "Mot lu"), nil : automatique
    -- (or sur texte clair, rouge fonce sur texte sombre).
    function DWE.CustomWordColor()
        local saved = type(DialogueWheelE_CustomColors) == "table" and DialogueWheelE_CustomColors.word
        return Valid(saved) and { saved[1], saved[2], saved[3] } or nil
    end
    THEME_STYLES.custom = { bg = { 0, 0, 0, 0.86 }, border = { 1, 1, 1, 1 }, hdr = { 1, 1, 1 }, body = { 1, 1, 1 }, shadow = 1 }
    -- Lecteur Spoken quand le theme Personnalise est en bulle : la meme bulle (remplissage et
    -- contour blancs, teintes aux couleurs choisies).
    THEME_STYLES.spk_custom = {
        tex = ADDON_PATH .. "BubbleCustomFill.png", edgeTex = ADDON_PATH .. "BubbleCustomEdge.png",
        slice = { 16, 16, 16, 16 }, pad = { 16, 14, 16, 14 }, tint = { 0, 0, 0, 0.86 }, edgeTint = { 1, 1, 1, 1 },
        div = { 1, 1, 1, 0.45 }, hdr = { 1, 1, 1 }, body = { 1, 1, 1 }, shadow = 1, matchBubble = true,
    }
    DWE.CUSTOM_PALETTE = { common = nil, shadow = 1, hex = {} }
    BUBBLE_SKINS.custom = { bubble = "custom", pill = "custom", palette = DWE.CUSTOM_PALETTE, optFont = true, custom = true }
    -- Recalcule le theme, la palette des choix et la bulle a partir des couleurs choisies.
    function DWE.CustomRefresh()
        local bg, bd, tx, sl = DWE.CustomColor("bg"), DWE.CustomColor("border"), DWE.CustomColor("text"), DWE.CustomColor("sel")
        local st = THEME_STYLES.custom
        st.bg = { bg[1], bg[2], bg[3], DWE.CUSTOM_FILL_ALPHA }
        st.border = { bd[1], bd[2], bd[3], 1 }
        st.div = { bd[1], bd[2], bd[3], 0.45 }
        st.hdr, st.body, st.mark = sl, tx, Hex(sl)
        local sp = THEME_STYLES.spk_custom
        sp.tint = { bg[1], bg[2], bg[3], DWE.CUSTOM_FILL_ALPHA }
        sp.edgeTint = { bd[1], bd[2], bd[3], 1 }
        sp.div, sp.hdr, sp.body, sp.mark = st.div, sl, tx, Hex(sl)
        local pal = DWE.CUSTOM_PALETTE
        pal.normal, pal.selected = tx, sl
        pal.disabled = Mix(tx, bg, 0.5)
        pal.goodbye, pal.dim = Mix(tx, bg, 0.25), Mix(tx, bg, 0.2)
        pal.goodbyeSel = { 1, 0.35, 0.35 }
        pal.hex = { hdr = Hex(sl), body = Hex(tx), num = Hex(tx), rep = Hex(Mix(sl, tx, 0.5)), ok = "|cff80ff80", bad = "|cffff6060" }
        if DWE.Bubble and DWE.Bubble.RefreshCustom then DWE.Bubble.RefreshCustom() end
    end
    DWE.CustomRefresh()
    -- Themes Personnalises enregistres (DialogueWheelE_CustomPresets) : a part des options, un
    -- "Reinitialiser les options" ne les efface pas. Liste de { name, bg, border, text, sel }.
    local PRESET_KEYS = { "bg", "border", "text", "sel", "word" }
    function DWE.CustomPresets()
        if type(DialogueWheelE_CustomPresets) ~= "table" then DialogueWheelE_CustomPresets = {} end
        local list = DialogueWheelE_CustomPresets
        for i = #list, 1, -1 do
            local pr = list[i]
            if type(pr) ~= "table" or type(pr.name) ~= "string" then table.remove(list, i) end
        end
        return list
    end
    -- Enregistre les couleurs actuelles sous `name` (remplace un theme du meme nom). Renvoie son rang.
    function DWE.CustomPresetSave(name)
        name = type(name) == "string" and name:gsub("^%s+", ""):gsub("%s+$", "") or ""
        if name == "" then return nil end
        name = name:sub(1, 40)
        local list = DWE.CustomPresets()
        local pr = { name = name }
        for _, k in ipairs(PRESET_KEYS) do
            if k == "word" then pr[k] = DWE.CustomWordColor() else pr[k] = DWE.CustomColor(k) end
        end
        for i, old in ipairs(list) do
            if old.name:lower() == name:lower() then list[i] = pr return i end
        end
        list[#list + 1] = pr
        return #list
    end
    -- Applique le theme enregistre n. i (les couleurs manquantes reprennent celles par defaut).
    function DWE.CustomPresetApply(i)
        local pr = DWE.CustomPresets()[i]
        if not pr then return false end
        local c = {}
        for _, k in ipairs(PRESET_KEYS) do
            local v = pr[k]
            if Valid(v) then c[k] = { v[1], v[2], v[3] } end
        end
        DialogueWheelE_CustomColors = c
        DWE.CustomRefresh()
        return true
    end
    function DWE.CustomPresetDelete(i)
        local list = DWE.CustomPresets()
        if list[i] then table.remove(list, i) return true end
        return false
    end
    -- Couleurs de depart prises sur un autre theme (bouton "Partir du theme actuel").
    local FROM = {
        dark = { { 0.06, 0.06, 0.07 }, { 0.39, 0.39, 0.43 } }, glass = { { 0.06, 0.07, 0.08 }, { 0.73, 0.61, 0.38 } },
        halo = { { 0, 0, 0 }, { 0.2, 0.2, 0.2 } }, inkgold = { { 0.03, 0.03, 0.02 }, { 0.59, 0.48, 0.22 } },
        velin = { { 0.93, 0.84, 0.64 }, { 0.68, 0.51, 0.19 } }, arcane = { { 0.97, 0.92, 0.79 }, { 0.33, 0.44, 0.75 } },
        sylvan = { { 0.95, 0.90, 0.72 }, { 0.37, 0.46, 0.18 } }, starry = { { 0.17, 0.16, 0.30 }, { 0.80, 0.64, 0.29 } },
        parchment = { { 0.91, 0.77, 0.57 }, { 0.48, 0.33, 0.17 } }, parchment_dark = { { 0.27, 0.29, 0.30 }, { 0.53, 0.55, 0.60 } },
        folio = { { 0.81, 0.66, 0.49 }, { 0.56, 0.40, 0.26 } }, folio_dark = { { 0.03, 0.03, 0.04 }, { 0.50, 0.50, 0.55 } },
        whisper = { { 0.15, 0.06, 0.18 }, { 0.82, 0.53, 0.88 } }, emerald = { { 0.06, 0.18, 0.07 }, { 0.53, 0.88, 0.57 } },
        ruby = { { 0.18, 0.06, 0.09 }, { 0.88, 0.53, 0.60 } }, sapphire = { { 0.06, 0.13, 0.18 }, { 0.53, 0.72, 0.88 } },
        amber = { { 0.18, 0.11, 0.06 }, { 0.88, 0.69, 0.53 } }, gw2 = { { 0.10, 0.17, 0.25 }, { 0.90, 0.92, 0.95 } }, bubble_fantasy = { { 0.87, 0.77, 0.58 }, { 0.30, 0.18, 0.08 } },
    }
    function DWE.CustomFromTheme(id)
        local f = FROM[id]
        local sk = BUBBLE_SKINS[id]
        local pal = (sk and sk.palette) or (LIGHT_BACKGROUND[id] and WHEEL_INK) or DWE.HDR_PALETTE[id] or WHEEL_DEFAULT
        if id == "custom" then return end
        DialogueWheelE_CustomColors = {
            bg = f and f[1] or DWE.CUSTOM_DEFAULT.bg, border = f and f[2] or DWE.CUSTOM_DEFAULT.border,
            text = { pal.normal[1], pal.normal[2], pal.normal[3] }, sel = { pal.selected[1], pal.selected[2], pal.selected[3] },
        }
        DWE.CustomRefresh()
    end
end

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
    if parts.nine then parts.nine:Hide() end
    parts.border:SetAlpha(1)
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
        if cfg.rules then
            -- filets fins sur les bords haut et bas (bande de film)
            for _, t in ipairs({ top, bot }) do
                t:ClearAllPoints()
                t:SetHeight(1)
                t:SetColorTexture(cfg.rules[1], cfg.rules[2], cfg.rules[3], cfg.rules[4] * op)
                t:SetTexCoord(0, 1, 0, 1)
                t:SetVertexColor(1, 1, 1, 1)
            end
            top:SetPoint("BOTTOMLEFT", bg, "TOPLEFT", 0, -1)
            top:SetPoint("BOTTOMRIGHT", bg, "TOPRIGHT", 0, -1)
            bot:SetPoint("TOPLEFT", bg, "BOTTOMLEFT", 0, 1)
            bot:SetPoint("TOPRIGHT", bg, "BOTTOMRIGHT", 0, 1)
            top:Show(); bot:Show()
        end
        if cfg.noBorder then return cfg end
        local border = parts.border
        border:ClearAllPoints()
        border:SetPoint("TOPLEFT", content, "TOPLEFT", -14, 14)
        border:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 14, -14)
        border:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14 })
        border:SetBackdropBorderColor(unpack(cfg.border))
        border:Show()
        return cfg
    end
    -- GW2 UI installe : ses propres images de bulle (lecteur Spoken, cadres).
    if cfg.gw2native and DWE.GW2_ON then
        if not parts.gw2 then
            parts.gw2 = DWE.Gw2Decor(parts.border:GetParent(), "BACKGROUND", -6)
            for _, t in ipairs(parts.gw2.list) do parts.list[#parts.list + 1] = t end
        end
        local pl, pt, pr, pb = unpack(cfg.pad)
        DWE.Gw2Place(parts.gw2, content, -pl, -pt, -pr, -pb, true)
        DWE.Gw2Color(parts.gw2, 1, nil, op)
        return cfg
    end
    -- Bulle de discussion du jeu (theme Bulle d'Azeroth) : son cadre "ChatBubble" si le jeu l'a,
    -- sinon ses anciennes images de bulle.
    if cfg.chatbubble then
        local border = parts.border
        border:ClearAllPoints()
        border:SetPoint("TOPLEFT", content, "TOPLEFT", -14, 14)
        border:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 14, -14)
        border:SetAlpha(op)
        local nine = rawget(_G, "NineSliceUtil")
        local done = false
        if nine and nine.ApplyLayoutByName and not parts.legacyBubble then
            if not parts.nine then
                parts.nine = CreateFrame("Frame", nil, border)
                parts.nine:SetAllPoints(border)
            end
            done = pcall(nine.ApplyLayoutByName, parts.nine, "ChatBubble")
            parts.legacyBubble = not done or nil
        end
        if parts.nine then parts.nine:SetShown(done) end
        -- A la taille de la bulle de dialogue : le lecteur Spoken est dessine plus petit (son
        -- echelle), son contour serait sinon plus fin et ses coins moins arrondis.
        local k = 1
        local okB, bs = pcall(function() return (DWE.bubble or UIParent):GetEffectiveScale() end)
        local okO, os = pcall(border.GetEffectiveScale, border)
        if okB and okO and type(bs) == "number" and type(os) == "number" and os > 0 then k = bs / os end
        if done then
            border:SetBackdrop(nil)
            if parts.nine.SetScale then parts.nine:SetScale(k) end
            parts.nine:ClearAllPoints()
            parts.nine:SetAllPoints(border)
        else
            local e = 16 * k
            border:SetBackdrop({ bgFile = "Interface\\Tooltips\\ChatBubble-Background",
                edgeFile = "Interface\\Tooltips\\ChatBubble-Backdrop", tile = true, tileSize = e, edgeSize = e,
                insets = { left = 6 * k, right = 6 * k, top = 6 * k, bottom = 6 * k } })
        end
        border:Show()
        return cfg
    end

    local r, g, b, a = cfg.tint[1], cfg.tint[2], cfg.tint[3], cfg.tint[4] * op
    if cfg.slice then
        local sl = parts.slice
        local pl, pt, pr, pb = unpack(cfg.pad)
        -- Image de bulle : dessinee a la taille de la bulle de dialogue (meme epaisseur de contour,
        -- memes coins), meme si la fenetre qui la porte est plus petite (lecteur Spoken).
        local k = 1
        if cfg.matchBubble then
            if not parts.bholder then
                local owner = parts.border:GetParent()
                parts.bholder = CreateFrame("Frame", nil, owner)
                parts.bholder:SetAllPoints(owner)
                parts.bholder:SetFrameLevel(parts.border:GetFrameLevel())
                parts.bholder:EnableMouse(false)
                parts.bslice = parts.bholder:CreateTexture(nil, "BACKGROUND", nil, -6)
                parts.list[#parts.list + 1] = parts.bslice
            end
            parts.bholder:SetScale(1)
            local okB, bs = pcall(function() return (DWE.bubble or UIParent):GetEffectiveScale() end)
            local okO, os = pcall(parts.bholder.GetEffectiveScale, parts.bholder)
            if okB and okO and type(bs) == "number" and type(os) == "number" and os > 0 then k = bs / os end
            parts.bholder:SetScale(k)
            sl = parts.bslice
        end
        sl:ClearAllPoints()
        sl:SetPoint("TOPLEFT", content, "TOPLEFT", -pl / k, pt / k)
        sl:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", pr / k, -pb / k)
        sl:SetTexture(cfg.tex)
        sl:SetTexCoord(0, 1, 0, 1)
        if sl.SetTextureSliceMargins then
            pcall(sl.SetTextureSliceMargins, sl, unpack(cfg.slice))
            if sl.SetTextureSliceMode then pcall(sl.SetTextureSliceMode, sl, cfg.tile and 1 or 0) end
        end
        sl:SetVertexColor(r, g, b, a)
        sl:Show()
        -- Second calque (contour) teint a part : theme Personnalise.
        if cfg.edgeTex then
            parts.edges = parts.edges or {}
            local eg = parts.edges[sl]
            if not eg then
                eg = sl:GetParent():CreateTexture(nil, "BACKGROUND", nil, -5)
                parts.edges[sl] = eg
                parts.list[#parts.list + 1] = eg
            end
            eg:ClearAllPoints()
            eg:SetAllPoints(sl)
            eg:SetTexture(cfg.edgeTex)
            eg:SetTexCoord(0, 1, 0, 1)
            if eg.SetTextureSliceMargins then
                pcall(eg.SetTextureSliceMargins, eg, unpack(cfg.slice))
                if eg.SetTextureSliceMode then pcall(eg.SetTextureSliceMode, eg, 0) end
            end
            local e = cfg.edgeTint or { 1, 1, 1, 1 }
            eg:SetVertexColor(e[1], e[2], e[3], (e[4] or 1) * op)
            eg:Show()
        end
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
    -- Police ou taille changee dialogue ouvert : bulle, cadre du texte et choix suivent tout de suite.
    if choiceBox:IsShown() then
        DWE.UpdateVisuals()
        DWE.UpdateTextPanelVisuals()
        if DWE.Bubble and DWE.Bubble.Refit then DWE.Bubble.Refit() end
    elseif textBox:IsShown() then
        DWE.UpdateTextPanelVisuals()
    end
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
    -- Theme DialogueUI : le texte du PNJ est sur le parchemin de DialogueUI.
    if DWE.ConvToDUI and DWE.ConvToDUI() then return false end
    return DialogueWheelE_ShowText == true
end

-- La petite fenetre de Spoken (la carte) n'est pas cachee par transparence : Spoken la cache
-- lui-meme (voir DWE.HookSpokenStyles, DialogCovers), boutons et portrait compris. Cachee par
-- transparence, elle laissait des boutons invisibles, son portrait et attrapait le curseur.
local function ShouldHide(alwaysWithWheel, frame)
    if DWE.spokenCoversOwn and frame ~= nil and frame == rawget(_G, "SpokenMinimalPlayerFrame") then return false end
    return DWE.ShouldHideCore(alwaysWithWheel, frame)
end
-- Spoken doit-il cacher sa petite fenetre ? (memes regles que les autres fenetres de Spoken)
function DWE.SpokenMinimalHidden()
    local f = rawget(_G, "SpokenMinimalPlayerFrame")
    return DWE.ShouldHideCore(false, f) and true or false
end
function DWE.ShouldHideCore(alwaysWithWheel, frame)
    -- Lecteur de Spoken qui n'aurait a montrer qu'une ligne a la demande : cache (un petit
    -- bouton de Storytale le remplace).
    if DWE.spokenHeldHide and frame and frame.GetName then
        local okN, name = pcall(frame.GetName, frame)
        if okN and type(name) == "string" and name:find("^Spoken.*Player") then return true end
    end
    if DWE.duiHoldUntil and frame and frame.GetName and GetTime and GetTime() < DWE.duiHoldUntil then
        local okN, name = pcall(frame.GetName, frame)
        if okN and type(name) == "string" and name:find("^DUI") then return true end
    end
    if not (choiceBox:IsShown() or fadeHold) then return false end
    -- Un livre lu a voix haute sans son livre a l'ecran : le lecteur Spoken reste toujours visible.
    if not alwaysWithWheel and DWE.SpokenFocus and DWE.SpokenFocus.ForeignSpeaking
        and DWE.SpokenFocus.ForeignSpeaking() then
        local okN, name = pcall(frame and frame.GetName or function() end, frame)
        local isDUI = okN and type(name) == "string" and name:find("^DUI")
        if not isDUI then return false end
    end
    if alwaysWithWheel then return true end
    if DWE.BookByAddon() then
        -- Le livre de DialogueUI ne se montre jamais pendant un livre de l'addon.
        local ok, name = pcall(frame and frame.GetName or function() end, frame)
        if ok and type(name) == "string" and name:find("^DUI") then return true end
    end
    return DWE.TextWanted()
end

-- Une fenetre de DialogueUI cachee par transparence attrape encore la souris (son livre, au
-- premier plan, empechait de deplacer le notre) : on la rend traversable le temps qu'elle est
-- cachee, enfants compris.
function DWE.CutMouse(frame, cut)
    if (frame.dweMouseCut or false) == cut then return end
    frame.dweMouseCut = cut
    local function Walk(f)
        if (f.IsForbidden and f:IsForbidden()) or (f.IsProtected and f:IsProtected()) then return end
        if cut then
            if f.IsMouseEnabled and f:IsMouseEnabled() then f.dweMouseWas = true; f:EnableMouse(false) end
            if f.IsMouseWheelEnabled and f:IsMouseWheelEnabled() then f.dweWheelWas = true; f:EnableMouseWheel(false) end
        else
            if f.dweMouseWas then f.dweMouseWas = nil; f:EnableMouse(true) end
            if f.dweWheelWas then f.dweWheelWas = nil; f:EnableMouseWheel(true) end
        end
        if f.GetChildren then
            for _, c in ipairs({ f:GetChildren() }) do pcall(Walk, c) end
        end
    end
    pcall(Walk, frame)
end
function DWE.IsDUIFrame(frame)
    if frame.dweIsDUI == nil then
        local ok, name = pcall(frame.GetName, frame)
        frame.dweIsDUI = (ok and type(name) == "string" and name:find("^DUI")) and true or false
    end
    return frame.dweIsDUI
end
-- Fenetre de Spoken (ses lecteurs) : cachee par transparence, comme celles de DialogueUI.
function DWE.IsSpokenFrame(frame)
    if frame.dweIsSpoken == nil then
        local ok, name = pcall(frame.GetName, frame)
        frame.dweIsSpoken = (ok and type(name) == "string" and name:find("^Spoken")) and true or false
    end
    return frame.dweIsSpoken
end
-- Les portraits 3D (modeles) ne prennent pas la transparence de leur fenetre : un lecteur cache
-- laissait son portrait flotter a l'ecran. On les cache avec lui.
local MODEL_TYPES = { PlayerModel = true, Model = true, ModelScene = true, DressUpModel = true, CinematicModel = true }
function DWE.HideModels(frame, hidden)
    if (frame.dweModelsHidden or false) == hidden then return end
    frame.dweModelsHidden = hidden
    local function Walk(f, depth)
        if depth > 6 or (f.IsForbidden and f:IsForbidden()) then return end
        local okT, t = pcall(f.GetObjectType, f)
        if okT and MODEL_TYPES[t] then
            if hidden then
                f.dweModelAlpha = f.dweModelAlpha or f:GetAlpha()
                f:SetAlpha(0)
            elseif f.dweModelAlpha then
                f:SetAlpha(f.dweModelAlpha)
                f.dweModelAlpha = nil
            end
        end
        if f.GetChildren then
            for _, c in ipairs({ f:GetChildren() }) do pcall(Walk, c, depth + 1) end
        end
    end
    pcall(Walk, frame, 0)
end
-- Cachee : traversable par la souris (sinon des boutons invisibles attrapaient les clics et les
-- infobulles) et sans portrait flottant ; remontree : tout revient.
function DWE.HideExtras(frame, hidden)
    if DWE.IsDUIFrame(frame) then DWE.CutMouse(frame, hidden) return end
    -- Portrait 3D qu'un addon pose sur la fenetre de dialogue du jeu (GW2 UI) : il ne prend pas
    -- la transparence de la fenetre et restait a l'ecran au-dessus de la roue.
    if frame == rawget(_G, "GossipFrame") or frame == rawget(_G, "QuestFrame") then
        DWE.HideModels(frame, hidden)
        -- (le portrait de GW2 UI : la transparence ne suffit pas a un modele 3D, il est cache
        -- pour de bon, et recache si GW2 UI le remontre pendant la conversation)
        local gw = frame == rawget(_G, "GossipFrame") and rawget(_G, "GwGossipModelFrame")
        if type(gw) == "table" and gw.Hide then
            DWE.gwPortraitHidden = hidden or nil
            if not gw.dweHooked and gw.HookScript then
                gw.dweHooked = true
                gw:HookScript("OnShow", function(self) if DWE.gwPortraitHidden then self:Hide() end end)
            end
            if hidden then
                if gw:IsShown() then gw.dweWasShown = true; gw:Hide() end
            elseif gw.dweWasShown then
                gw.dweWasShown = nil
                gw:Show()
            end
        end
    end
    -- Fenetre de livre du jeu, invisible sous le livre de Storytale : les boutons que Spoken
    -- Readables y pose (Lire / Arreter, Compendium) restaient actifs, invisibles. La navigation
    -- manette du jeu (et la souris) s'y posait, et leur infobulle ("Stop reading this")
    -- apparaissait un instant a gauche de l'ecran. Ils sont caches tant que la fenetre l'est.
    if frame == rawget(_G, "ItemTextFrame") then
        DWE.itfCut = hidden or nil
        local sr = rawget(_G, "SpokenReadables")
        if type(sr) ~= "table" then return end
        for _, b in ipairs({ sr.playButton, sr.openButton }) do
            if type(b) == "table" and b.Hide then
                if not b.dweShowHooked and hooksecurefunc then
                    b.dweShowHooked = true
                    hooksecurefunc(b, "Show", function(self) if DWE.itfCut then self:Hide() end end)
                    if b.SetShown then
                        hooksecurefunc(b, "SetShown", function(self, on) if on and DWE.itfCut then self:Hide() end end)
                    end
                end
                if hidden then b:Hide() end
            end
        end
        -- Fenetre du jeu visible a nouveau : Spoken Readables remet ses boutons comme il faut.
        if not hidden and type(sr.RefreshPlayButton) == "function" then pcall(sr.RefreshPlayButton, sr) end
        return
    end
    if DWE.IsSpokenFrame(frame) then
        DWE.CutMouse(frame, hidden)
        DWE.HideModels(frame, hidden)
    end
end
local function ApplyAlpha(frame, alwaysWithWheel)
    if not IsSafeFrame(frame) then return end
    local a = ShouldHide(alwaysWithWheel, frame) and 0 or 1
    if frame:GetAlpha() ~= a then frame:SetAlpha(a) end
    DWE.HideExtras(frame, a == 0)
end
local function WatchFrame(frame, alwaysWithWheel)
    if not IsSafeFrame(frame) or hookedFrames[frame] then return end
    hookedFrames[frame] = true
    hooksecurefunc(frame, "SetAlpha", DWE.Prof("masquage DialogueUI/Spoken", function(s, a)
        if a > 0 and ShouldHide(alwaysWithWheel, s) then
            s:SetAlpha(0)
            DWE.HideExtras(s, true)
        elseif a > 0 and (s.dweMouseCut or s.dweModelsHidden or (DWE.itfCut and s == rawget(_G, "ItemTextFrame"))) then
            DWE.HideExtras(s, false)
        end
    end))
    if frame.HookScript then
        frame:HookScript("OnShow", function(s) ApplyAlpha(s, alwaysWithWheel) end)
    end
end

-- Echap pour une fenetre de l'addon, sans UISpecialFrames (le jeu lit cette liste dans du code
-- protege : nos noms y propageaient la "contamination" jusqu'a la navigation manette). Le cadre,
-- affiche, recoit les touches avant le jeu : il garde Echap, laisse passer tout le reste.
-- En combat, le jeu interdit de garder une touche : Echap passe aussi au jeu.
function DWE.EscapeKeys(fr, onEscape)
    if not (fr and fr.EnableKeyboard) then return end
    fr:EnableKeyboard(true)
    if fr.SetPropagateKeyboardInput then pcall(fr.SetPropagateKeyboardInput, fr, true) end
    fr:SetScript("OnKeyDown", function(self, key)
        local mine = key == "ESCAPE"
        if self.SetPropagateKeyboardInput and not InCombatLockdown() then
            pcall(self.SetPropagateKeyboardInput, self, not mine)
        end
        if mine then onEscape(self) end
    end)
end

-- Cache / remontre les lecteurs de Spoken (bascule "rien que des lignes a la demande").
function DWE.SetSpokenHeldHide(on)
    on = on and true or nil
    if DWE.spokenHeldHide == on then return end
    DWE.spokenHeldHide = on
    for _, n in ipairs({ "SpokenMinimalPlayerFrame", "SpokenDialogueUIPlayerFrame" }) do
        local fr = rawget(_G, n)
        if IsSafeFrame(fr) then
            WatchFrame(fr, false)
            ApplyAlpha(fr, false)
        end
    end
    if DWE.RefreshHiddenFrames then DWE.RefreshHiddenFrames() end
end

-- Surveille une fenetre : si son addon remet son alpha au-dessus de 0 alors qu'elle doit
-- etre cachee, on la recache aussitot.
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

-- GW2 UI : sa vue de quete plein ecran (« Immersive Questing ») s'ouvrait par-dessus Storytale.
-- Tant que la roue de Storytale est la, elle est refermee aussitot (sans son animation) ; le
-- reste de l'interface de GW2 UI n'est pas touche.
function DWE.HookGW2()
    local q = rawget(_G, "GwImmersiveQuestFrame")
    if type(q) ~= "table" or not q.HookScript then return end
    local function Close()
        if not (choiceBox:IsShown() and q:IsShown()) then return end
        local hideNow = q.HideNow or q.Hide
        pcall(hideNow, q)
    end
    if not q.dweHooked then
        q.dweHooked = true
        -- Sa vue s'ouvre parfois avant la roue (meme evenement) : elle restait visible une image
        -- (cadre noir). Transparente des l'ouverture ; a l'image suivante, fermee si la roue est
        -- la, sinon rendue visible (sans Storytale, la vue s'affiche avec une image de retard).
        q:HookScript("OnShow", function(self)
            if choiceBox:IsShown() then Close() return end
            self:SetAlpha(0)
            local function Later()
                Close()
                if self.fadingOut ~= true then self:SetAlpha(1) end
            end
            if C_Timer and C_Timer.After then C_Timer.After(0, Later) else Later() end
        end)
    end
    Close()
end

local function RefreshHiddenFrames()
    DWE.HookSpoken()
    if DWE.HookGW2 then pcall(DWE.HookGW2) end
    for _, name in ipairs(BLIZZ_FRAMES) do
        local frm = _G[name]
        if IsSafeFrame(frm) then
            WatchFrame(frm, true)
            ApplyAlpha(frm, true)
            frm:EnableMouse(not choiceBox:IsShown())
        end
    end
    for i = 1, #addonFrames do ApplyAlpha(addonFrames[i], false) end
    -- La carte de Spoken se cache elle-meme : on la previent quand la regle change.
    if DWE.spokenCoversOwn then
        local hide = DWE.SpokenMinimalHidden()
        if hide ~= DWE.spokenMiniHideWas then
            DWE.spokenMiniHideWas = hide
            local env = rawget(_G, "SpokenEnv")
            local mp = type(env) == "table" and rawget(env, "MinimalPlayer")
            if type(mp) == "table" and mp.frame and type(mp.Update) == "function" then pcall(mp.Update, mp) end
        end
    end
end
DWE.RefreshHiddenFrames = RefreshHiddenFrames

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
    whisper = 2, emerald = 2, ruby = 2, sapphire = 2, amber = 2, gw2 = 2, glass = 2, halo = 2, inkgold = 2, cinema = 2,
    parchment = 1, dui_brown = 1, folio = 1, velin = 1, arcane = 1, sylvan = 1, starry = 2,
}

-- Ligne de livre (Spoken Readables) alors que les livres sont laisses a DialogueUI ou au jeu :
-- le lecteur Spoken garde son propre habillage (celui de DialogueUI), comme le livre.
local spokenSkinRef
-- La ligne que montre Spoken, quel que soit son style : sous-titres, petite fenetre ou lecteur
-- facon DialogueUI (celui-ci n'existe qu'avec DialogueUI installe).
local function SpokenCurClip()
    local env = rawget(_G, "SpokenEnv")
    local addon = type(env) == "table" and rawget(env, "Addon")
    if type(addon) == "table" and type(addon.DisplayStyle) == "function" and addon.db then
        local ok, style = pcall(addon.DisplayStyle, addon)
        local owner = ok and ((style == "subtitle" and rawget(env, "Subtitle"))
            or (style == "minimal" and rawget(env, "MinimalPlayer"))) or nil
        if type(owner) == "table" then return owner.clip end
    end
    return spokenSkinRef and spokenSkinRef.clip
end
DWE.SpokenCurClip = SpokenCurClip
local function SpokenBookLeftAlone()
    -- Seul le livre DialogueUI garde l'habillage DialogueUI ; fenetre du jeu = theme Storytale.
    local style = (DWE.bookMode and DWE.BookStyleNow()) or DWE.lastBookStyle or DWE.BookStyleNow()
    if style ~= "dui" then return false end
    local duiBook = rawget(_G, "DUIBookFrame")
    if type(duiBook) == "table" and duiBook.IsShown and duiBook:IsShown() then return true end
    local clip = SpokenCurClip()
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
-- Habillage retenu par livre (son titre) : les pages suivantes, mises en file plus tard, gardent
-- celui du livre (papier, plaque...) au lieu de prendre le theme du moment.
DWE.bookStamps = {}
-- Hommages a de vraies personnes disparues (tombes de Hautebrande) : pas de mot surligne,
-- un texte sobre.
DWE.MEMORIALS = { ["In Loving Memory"] = true, ["Decorated Headstone"] = true }
function DWE.IsMemorialClip(clip)
    local F = DWE.SpokenFocus
    local key = F and F.GroupKey and F.GroupKey(clip)
    return type(key) == "string" and DWE.MEMORIALS[key:match("^book:(.*)$") or ""] == true
end
-- Epitaphe centree : hommage, ou texte ouvert que le jeu centre (tombe ecrite en HTML) et que
-- Spoken est en train de lire.
function DWE.CenteredClip(clip)
    if DWE.IsMemorialClip(clip) then return true end
    if not DWE.bookCentered then return false end
    local F = DWE.SpokenFocus
    local key = F and F.GroupKey and F.GroupKey(clip)
    local t = ItemTextGetItem and ItemTextGetItem()
    return type(key) == "string" and type(t) == "string" and not (issecretvalue and issecretvalue(t)) and key == "book:" .. t
end
function DWE.MemorialOpen()
    local t = ItemTextGetItem and ItemTextGetItem()
    return type(t) == "string" and not (issecretvalue and issecretvalue(t)) and DWE.MEMORIALS[t] == true
end
function DWE.StampKey(clip)
    local F = DWE.SpokenFocus
    return F and F.GroupKey and F.GroupKey(clip) or nil
end
function DWE.SpokenStamp()
    local clip = SpokenCurClip()
    if type(clip) ~= "table" or DWE.BookOpenNow() then return nil end
    if not clip.dweStamp then
        local key = DWE.StampKey(clip)
        clip.dweStamp = key and DWE.bookStamps[key] or nil
    end
    return clip.dweStamp
end
-- Mot lu par Spoken sur une plaque de l'addon : couleur propre a la matiere (neutre, aucun camp).
DWE.PLATE_MARK = { Stone = "|cff7a5a1e", Marble = "|cff8c6a1a", Silver = "|cff6e5418", Bronze = "|cff1f4a3a", Dalaran = "|cffd9c2ff" }
function DWE.SpokenPlateMat()
    local st = DWE.SpokenStamp()
    if st then return st.override and st.mat or nil end
    if DWE.BookByAddon() and DWE.BookLook() == "note" then return DWE.PlateMaterial() end
    return nil
end
-- Narration de zone (Spoken Places) : habillage choisi a part (theme, page, DialogueUI).
function DWE.SpokenPlaceSkin()
    local clip = SpokenCurClip()
    local f = DWE.SpokenFocus
    if type(clip) ~= "table" or not (f and f.SourceName) then return nil end
    if not f.SourceName(clip):lower():find("place") then return nil end
    local v = DialogueWheelE_PlaceSkin
    if v == "dui" and not DWE.DUI_ON then v = nil end
    -- Un theme choisi pour les narrations : "theme", et ce theme en second.
    if v and v ~= "paper" and v ~= "dui" then return "theme", v end
    return v or "theme"
end
-- La ligne que montre le lecteur Spoken est-elle un livre ? (sinon un PNJ, un lieu...)
function DWE.SpokenClipBook()
    local clip = SpokenCurClip()
    local p = type(clip) == "table" and clip.present
    return type(p) == "table" and (p.material ~= nil or p.bullet == "book") or false
end
-- Theme des conversations, meme pendant un livre (le livre impose le sien a l'ecran).
function DWE.SpokenConvTheme()
    local t = DialogueWheelE_Theme or "bubble"
    -- Theme DialogueUI : seule la roue est sans cadre ; le lecteur Spoken garde le parchemin.
    if t == "dui" then t = "dui_brown" end
    if (t == "dui_brown" or t == "dui_dark") and not DWE.DUI_ON then t = "bubble" end
    return t
end
-- Theme de base du lecteur Spoken. Theme DialogueUI : le parchemin (la roue seule est sans cadre).
-- Habillage choisi a part pour le lecteur Spoken (option), sinon nil : il suit le theme.
local function ValidTheme(id)
    if id == "dui" then return DWE.DUI_ON and "dui_brown" or nil end
    for _, t in ipairs(DWE.THEME_LIST or {}) do if t.id == id then return id end end
    return nil
end
function DWE.SpokenSkinPick()
    -- Narration de zone avec son propre theme (option), sinon celui des voix.
    local _, placeTheme = DWE.SpokenPlaceSkin()
    if placeTheme then
        local t = ValidTheme(placeTheme)
        if t then return t end
    end
    local pick = rawget(_G, "DialogueWheelE_SpokenSkin")
    if type(pick) ~= "string" then return nil end
    if pick == "dui" then return DWE.DUI_ON and "dui_brown" or nil end
    for _, t in ipairs(DWE.THEME_LIST or {}) do if t.id == pick then return pick end end
    return nil
end
function DWE.SpokenBaseTheme()
    local pick = DWE.SpokenSkinPick()
    if pick then return pick end
    if DWE.BookByAddon() then return DWE.SpokenConvTheme() end
    if DialogueWheelE_Theme == "dui" and not DWE.bookMode then return DWE.SpokenConvTheme() end
    return CurrentTheme()
end
function DWE.SpokenThemeOverride()
    local st = DWE.SpokenStamp()
    if st then return st.override end
    local place = DWE.SpokenPlaceSkin()
    if place == "dui" then return nil end
    if place == "paper" then return 1 end
    -- Livre affiche par l'addon : le petit lecteur Spoken prend le theme du livre quand il lit
    -- un livre ; une autre voix (un PNJ) garde le theme des conversations.
    local addonBook = DWE.BookByAddon()
    local bookClip = DWE.SpokenClipBook()
    local kind, val
    if bookClip then kind, val = DWE.SpokenReadablePick() end
    if addonBook and bookClip and kind ~= "theme" then return 1 end
    if DialogueWheelE_SpokenTheme ~= true then return nil end
    if not addonBook and SpokenBookLeftAlone() then return nil end
    -- Ecrit : page de livre ou matiere (texte fonce), ou le theme choisi.
    if bookClip then return kind == "theme" and (SPOKEN_PALETTE_OF[val] or 2) or 1 end
    return SPOKEN_PALETTE_OF[DWE.SpokenBaseTheme()] or 2
end

-- Pour la fenetre Spoken, les bulles empruntent le style d'un theme "bloc".
local SPOKEN_STYLE_ALIAS = { bubble = "spk_bubble", bubble_npc = "spk_bubble", bubble_fantasy = "spk_fantasy", whisper = "spk_whisper",
    emerald = "spk_emerald", ruby = "spk_ruby", sapphire = "spk_sapphire", amber = "spk_amber", gw2 = "spk_gw2",
    transparent = "spk_transparent", cinema = "spk_cinema" }
-- Style "plaque" de la matiere `mat` (petite taille : texture S, marges divisees par 2).
local function PlateStyle(mat)
    -- Disque rond : la petite fenetre (etiree en largeur) prend sa version rectangulaire, ou
    -- la plaque de pierre.
    if mat and DWE.PLATES[mat] and DWE.PLATES[mat].round and not DWE.PLATES[mat].mini then mat = "Stone" end
    local pl = mat and DWE.PLATES[mat]
    if not pl then return nil end
    local id = "plate_" .. mat
    if not THEME_STYLES[id] then
        local sl = pl.mini and pl.mini.slice or pl.slice
        local h = { math.floor(sl[1] / 2), math.floor(sl[2] / 2), math.floor(sl[3] / 2), math.floor(sl[4] / 2) }
        local ins = pl.mini and pl.mini.inner or pl.inner or sl
        local q = { math.floor(ins[1] / 2), math.floor(ins[2] / 2), math.floor(ins[3] / 2), math.floor(ins[4] / 2) }
        THEME_STYLES[id] = {
            tex = ADDON_PATH .. pl.tex .. "S.png", slice = h,
            pad = { q[1] + 14, q[2] + 10, q[3] + 14, q[4] + 10 },
            tint = { 1, 1, 1, 1 }, div = pl.rule, hdr = pl.hdr, body = pl.body, shadow = 0, tile = pl.tile, mark = DWE.PLATE_MARK and DWE.PLATE_MARK[mat],
        }
    end
    return id
end
-- Le style du lecteur Spoken pour le theme `t` : son cadre, son habillage propre (bulles, sans
-- cadre...) ou sa bulle quand il s'affiche en bulle.
local function ThemeSpokenStyle(t)
    if SPOKEN_STYLE_ALIAS[t] then return SPOKEN_STYLE_ALIAS[t] end
    if t == "custom" and DWE.ThemeIsBubble and DWE.ThemeIsBubble("custom") then return "spk_custom" end
    -- Theme affiche en bulle (Voile d'ombre, Verre fume... sans "themes en cadre") : le lecteur
    -- prend la meme bulle, dans les couleurs du theme.
    local sk = DWE.ThemeIsBubble and DWE.ThemeIsBubble(t) and DWE.BUBBLE_SKINS and DWE.BUBBLE_SKINS[t]
    local base = THEME_STYLES[t]
    if sk and sk.art and base then
        local id = "spkb_" .. t
        if not THEME_STYLES[id] then
            THEME_STYLES[id] = {
                tex = ADDON_PATH .. "Bubble" .. sk.art .. ".png", slice = { 16, 16, 16, 16 }, pad = { 16, 14, 16, 14 },
                tint = { 1, 1, 1, 1 }, div = base.div, hdr = base.hdr, body = base.body, shadow = base.shadow,
                mark = base.mark, lightMark = base.lightMark, matchBubble = true,
            }
        end
        return id
    end
    return t
end
-- Habillage choisi pour un ecrit (option Livres ou Plaques) : "paper", "mat:Pierre..." ou un
-- theme. Renvoie le genre ("paper", "mat", "theme") et sa valeur, ou nil (reglage par defaut).
local function ReadablePick(v)
    if type(v) ~= "string" then return nil end
    if v == "paper" then return "paper" end
    local mat = v:match("^mat:(%a+)$")
    if mat then return DWE.PLATES[mat] and "mat" or nil, mat end
    if v == "dui" then return DWE.DUI_ON and "theme" or nil, "dui_brown" end
    for _, t in ipairs(DWE.THEME_LIST or {}) do if t.id == v then return "theme", v end end
    return nil
end
-- La ligne lue est-elle une plaque ? (et sa matiere : celle affichee, celle choisie pour toutes
-- les plaques, sinon la sienne)
local function PlateClip()
    if DWE.BookByAddon() and DWE.BookLook() == "note" then
        local m = DWE.PlateMaterial()
        if m then return true, m end
    end
    local clip = SpokenCurClip()
    local m = type(clip) == "table" and type(clip.present) == "table" and clip.present.material or nil
    if not (m and DWE.PLATES[m]) and type(clip) == "table" and DWE.TrollTablet then
        m = DWE.TrollTablet(clip.pageId) or m
    end
    if not (m and DWE.PLATES[m]) then return false end
    local pick = DialogueWheelE_PlateLook
    if pick and DWE.PLATES[pick] then m = pick end
    return true, m
end
-- Choix de l'option qui concerne la ligne lue (livre ou plaque).
function DWE.SpokenReadablePick()
    local isPlate = PlateClip()
    return ReadablePick(isPlate and DialogueWheelE_PlateSkin or DialogueWheelE_BookSkin)
end
local function SpokenStyle()
    local st = DWE.SpokenStamp()
    if st then return st.style end
    if DWE.SpokenPlaceSkin() == "paper" then return "bookpaper" end
    if DWE.SpokenClipBook() then
        local isPlate, mat = PlateClip()
        local kind, val = ReadablePick(isPlate and DialogueWheelE_PlateSkin or DialogueWheelE_BookSkin)
        if kind == "theme" then return ThemeSpokenStyle(val) end
        if kind == "mat" then return PlateStyle(val) or "bookpaper" end
        if kind == "paper" then return "bookpaper" end
        -- Par defaut : un livre sur la page de livre, une plaque dans sa matiere.
        return (isPlate and PlateStyle(mat)) or "bookpaper"
    end
    return ThemeSpokenStyle(DWE.SpokenBaseTheme())
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
            mat = DWE.BookByAddon() and DWE.PlateMaterial() or nil,
        }
        local key = DWE.StampKey(clip)
        if key then DWE.bookStamps[key] = clip.dweStamp end
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

-- Lecteur miniature de Spoken a l'ecran (il lit autre chose que la conversation en cours).
-- (Le petit lecteur "minimal" ou le lecteur facon DialogueUI, selon le reglage de Spoken.)
function DWE.PlayerFrameShown(fr)
    if type(fr) ~= "table" or not fr.IsVisible or not fr:IsVisible() then return false end
    return (fr.GetEffectiveAlpha and fr:GetEffectiveAlpha() or fr:GetAlpha() or 1) > 0.05
end
function DWE.SpokenPlayerShown()
    if DWE.PlayerFrameShown(rawget(_G, "SpokenMinimalPlayerFrame")) then return true end
    if DWE.PlayerFrameShown(rawget(_G, "SpokenDialogueUIPlayerFrame")) then return true end
    if DWE.PlayerFrameShown(rawget(_G, "SpokenSubtitleFrame")) then return true end
    return DWE.PlayerFrameShown(type(spokenSkinRef) == "table" and spokenSkinRef.frame)
end

-- Place par defaut des lecteurs de Spoken, tant que le joueur ne les a pas deplaces lui-meme
-- (Spoken retient alors leur place et on n'y touche plus). En unites de l'interface, donc en
-- part de la hauteur d'ecran : la meme place a toutes les resolutions et tous les formats.
--  * sans DialogueUI, lecteur miniature : centre, au-dessus des barres d'action de la manette
--    en mode manette, juste au-dessus de la barre principale au clavier ;
--  * avec DialogueUI, son lecteur : a droite, un peu sous le milieu (manette comme clavier).
DWE.SPOKEN_MINI_Y = { pad = 0.315, kbm = 0.091 } -- bas du lecteur
DWE.SPOKEN_DUI_POS = { right = 0.26, top = 0.427 }  -- bord droit et haut du lecteur
function DWE.SpokenPlayersPlace()
    local env = rawget(_G, "SpokenEnv")
    local addon = type(env) == "table" and env.Addon
    if type(addon) ~= "table" or type(addon.Layout) ~= "function" then return end
    local ok, layout = pcall(addon.Layout, addon)
    if not ok or type(layout) ~= "table" then return end
    local H, W = UIParent:GetHeight() or 768, UIParent:GetWidth() or 1366
    local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    if loaded and loaded("DialogueUI") then
        local fr = rawget(_G, "SpokenDialogueUIPlayerFrame")
        local saved = layout.DialogueUI
        if type(fr) ~= "table" or not fr.GetWidth or (saved ~= nil and not (type(saved) == "table" and saved.dwe)) then return end
        local k = fr.spokenBaseScale or 1
        local width = fr:GetWidth() or 360
        local left = (W - DWE.SPOKEN_DUI_POS.right * H) / k - width
        local top = DWE.SPOKEN_DUI_POS.top * H / k
        if saved and math.abs(saved.left - left) < 1 and math.abs(saved.top - top) < 1 then return end
        -- Ecrit comme une place de Spoken : ses glissements de fenetre y vont d'eux-memes.
        layout.DialogueUI = { left = left, top = top, width = width, dwe = true }
        if not (fr.IsDragging and fr:IsDragging()) then pcall(addon.RestoreLayout, addon, "DialogueUI", fr) end
        return
    end
    local fr = rawget(_G, "SpokenMinimalPlayerFrame")
    if type(fr) ~= "table" or not fr.ClearAllPoints or (type(layout.Minimal) == "table" and layout.Minimal.left) then return end
    if fr.IsDragging and fr:IsDragging() then return end
    local rel = (fr.GetEffectiveScale and UIParent.GetEffectiveScale and fr:GetEffectiveScale() / UIParent:GetEffectiveScale()) or 1
    if not rel or rel <= 0 then rel = 1 end
    -- Petite fenetre en carte (sans DialogueUI) : a la place du lecteur facon DialogueUI.
    if DWE.SpokenCardOn and DWE.SpokenCardOn() then
        -- (+9 / +3 : le cadre visible de la carte tombe sur celui du lecteur facon DialogueUI)
        local left = (W - DWE.SPOKEN_DUI_POS.right * H) / rel - (fr:GetWidth() or DWE.SPOKEN_CARD.width) + 9
        local top = DWE.SPOKEN_DUI_POS.top * H / rel + 3
        local p, to, rp, ox, oy = fr:GetPoint(1)
        if p == "TOPLEFT" and to == UIParent and rp == "BOTTOMLEFT" and math.abs((ox or 0) - left) < 1 and math.abs((oy or 0) - top) < 1 then return end
        fr:ClearAllPoints()
        fr:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        return
    end
    local key = (DWE.PadInUse and DWE.PadInUse()) and "pad" or "kbm"
    local y = DWE.SPOKEN_MINI_Y[key] * H / rel
    local p, to, rp, ox, oy = fr:GetPoint(1)
    if p == "BOTTOM" and to == UIParent and rp == "BOTTOM" and math.abs((ox or 0)) < 1 and math.abs((oy or 0) - y) < 1 then return end
    fr:ClearAllPoints()
    fr:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, y)
end

-- Manette : boutons du lecteur Spoken ("play" = arreter/relancer, "skip" = passer).
-- Rangee de Spoken (Spoken Readables) dans le livre de DialogueUI, quand elle est a l'ecran.
function DWE.DUIBookRow()
    local sr = rawget(_G, "SpokenReadables")
    local book = type(sr) == "table" and sr.DialogueUIBook
    local row = type(book) == "table" and book.row
    if type(row) ~= "table" or type(row.frame) ~= "table" or not row.frame:IsVisible() then return nil end
    return row, book
end
function DWE.SpokenPadPress(which)
    -- Livre de DialogueUI : ses propres boutons, comme a la souris (l'icone Lecture / Stop suit).
    local row = DWE.DUIBookRow()
    local b = row and row[which == "play" and "play" or "skip"]
    if type(b) == "table" and b.IsShown and b:IsShown() and (not b.IsEnabled or b:IsEnabled() ~= false) then
        local fn = b:GetScript("OnClick")
        if fn then return pcall(fn, b, "LeftButton") and true or false end
    end
    -- La voie publique de Spoken (celle de ses raccourcis clavier) : /spoken play, /spoken skip.
    local cmd = type(SlashCmdList) == "table" and SlashCmdList.SPOKEN
    if type(cmd) == "function" then
        return pcall(cmd, which) and true or false
    end
    local skin = spokenSkinRef
    local b = type(skin) == "table" and skin[which]
    if type(b) ~= "table" or not b.Click then return false end
    if b.IsVisible and not b:IsVisible() then return false end
    if b.IsEnabled and not b:IsEnabled() then return false end
    return pcall(b.Click, b) and true or false
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
    -- Le lecteur se cache quand une fenetre de DialogueUI le couvre. Le livre de DialogueUI reste
    -- ouvert (invisible) derriere un livre de Storytale : il ne couvre rien, le lecteur d'une autre
    -- voix (un PNJ, un autre livre) reste donc visible, comme en conversation.
    if type(skin.Covered) == "function" then
        local origCovered = skin.Covered
        skin.Covered = function(self, ...)
            if not origCovered(self, ...) then return false end
            if not DWE.BookByAddon() then return true end
            local book = rawget(_G, "DUIBookFrame")
            for _, dialog in ipairs(self.dialogs or {}) do
                if dialog ~= book and dialog:IsShown() and self.frame:GetParent() ~= dialog then return true end
            end
            return false
        end
    end
    -- Livre de Storytale referme : le livre de DialogueUI (invisible derriere) se ferme aussi, et
    -- Spoken ferait glisser son lecteur depuis sa page, avec le parchemin de DialogueUI. Ce
    -- parchemin n'a jamais ete a l'ecran : le lecteur se met directement a sa place.
    if type(skin.Settle) == "function" then
        local origSettle = skin.Settle
        skin.Settle = function(self, dialog, ...)
            local book = rawget(_G, "DUIBookFrame")
            local held = DWE.duiHoldUntil and GetTime and GetTime() < DWE.duiHoldUntil
            if dialog ~= nil and dialog == book and (DWE.BookByAddon() or held) then
                self.justClosed = nil
                if type(self.PlaceHome) == "function" then pcall(self.PlaceHome, self) end
                if type(self.Update) == "function" then return self:Update() end
                return
            end
            return origSettle(self, dialog, ...)
        end
    end
    if type(skin.ShadowUnder) == "function" then hooksecurefunc(skin, "ShadowUnder", GuardAll) end
    if type(skin.TuckFrames) == "function" then hooksecurefunc(skin, "TuckFrames", GuardAll) end
    GuardAll(skin)

    -- Couleurs du texte (claires / foncees) selon le theme de DWE.
    local theme = rawget(env, "DialogueUITheme")
    if type(theme) == "table" and type(theme.Colors) == "function" then
        local origColors, cache = theme.Colors, {}
        theme.Colors = function(self, palette, ...)
            local c = origColors(self, palette, ...)
            if type(c) ~= "table" then return c end
            local mat = DWE.SpokenPlateMat()
            local hex = mat and DWE.PLATE_MARK[mat]
            -- Lecteur habille par Storytale : les couleurs de son theme (titre, texte, mot lu).
            local id, cfg = nil, nil
            if DWE.SpokenOwnStyle then id, cfg = DWE.SpokenOwnStyle() end
            local memo = DWE.IsMemorialClip and DWE.IsMemorialClip(SpokenCurClip())
            if not hex and not id and not memo then return c end
            local k = tostring(palette) .. (mat or "") .. (id or "") .. (memo and "m" or "")
            if not cache[k] then
                local n = {}
                for a, b in pairs(c) do n[a] = b end
                if cfg and cfg.hdr and cfg.body then
                    n.title, n.paragraph = cfg.hdr, cfg.body
                    n.highlight = DWE.ThemeMark(cfg) or n.highlight
                end
                if hex then n.highlight = hex end
                -- Hommage a une personne disparue : le mot lu garde la couleur du texte.
                if memo then n.highlight = n.paragraph or n.highlight end
                cache[k] = n
            end
            return cache[k]
        end
    end
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
    -- Texte de Spoken parcouru a la molette : quand la souris quitte le texte, il reprend tout
    -- seul la ligne lue (Spoken attendait un clic pour ca).
    local tr = rawget(env, "Transcript")
    local function HookTranscript()
        local fr = type(tr) == "table" and tr.frame
        if type(fr) ~= "table" or fr.dweFollowHook or not fr.HookScript then return end
        fr.dweFollowHook = true
        fr:HookScript("OnLeave", function()
            local token = {}
            tr.dweLeaveToken = token
            C_Timer.After(1.5, function()
                if tr.dweLeaveToken ~= token or not tr.manualScroll then return end
                local okM, over = pcall(fr.IsMouseOver, fr)
                if okM and over then return end
                tr.manualScroll = false
                if type(tr.Update) == "function" then pcall(tr.Update, tr) end
            end)
        end)
        fr:HookScript("OnEnter", function() tr.dweLeaveToken = nil end)
    end
    if type(tr) == "table" then
        HookTranscript()
        if type(tr.Initialize) == "function" then hooksecurefunc(tr, "Initialize", HookTranscript) end
        -- Epitaphe (hommage) : lignes centrees dans la petite fenetre, comme sur la pierre.
        if type(tr.Place) == "function" and not tr.dweCenterHook then
            tr.dweCenterHook = true
            hooksecurefunc(tr, "Place", function(self)
                local center = DWE.CenteredClip(SpokenCurClip())
                for _, label in ipairs(self.labels or {}) do
                    if label.SetJustifyH then
                        local p = label:GetParent()
                        if center and p then label:SetPoint("RIGHT", p, "RIGHT", 0, 0) end
                        if center or label.dweCentered then label:SetJustifyH(center and "CENTER" or "LEFT") end
                        label.dweCentered = center or nil
                    end
                end
            end)
        end
    end
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
    if DWE.SpokenStyleSync then pcall(DWE.SpokenStyleSync) end
    if DWE.PaintSpokenSubtitle then pcall(DWE.PaintSpokenSubtitle) end
    if DWE.PaintSpokenMinimal then DWE.PaintSpokenMinimal() end
end

-- Les autres styles de Spoken (sous-titres, petite fenetre) : ceux qu'il montre sans DialogueUI.
-- Avec l'option "Adapter la fenetre Spoken au theme", ils prennent le fond et les couleurs du
-- theme de Storytale ; sinon ils gardent leur look d'origine. Tout passe par des accroches
-- protegees : si Spoken change sa fenetre, elle garde simplement son propre look.
do
local SPOKEN_GOLD = "|cffffd100"     -- mot lu, sur fond sombre (celui de Spoken)
local SPOKEN_RED = "|cff9c1a1a"      -- mot lu, sur papier clair (celui de Spoken sur parchemin)

-- Style du theme a dessiner derriere un lecteur Spoken, ou nil (look d'origine de Spoken).
local function SpokenOwnStyle()
    if DWE.SpokenThemeOverride() == nil then return nil end
    local id = SpokenStyle()
    local cfg = THEME_STYLES[id]
    if not cfg or cfg.clear then return nil end -- themes DialogueUI : seulement sur son lecteur
    return id, cfg
end
DWE.SpokenOwnStyle = SpokenOwnStyle

-- Place prise par le dessin d'un theme autour du texte (gauche, haut, droite, bas).
local function ThemeReach(cfg)
    if cfg.bg then return 14, 14, 14, 14 end
    if cfg.slice then return unpack(cfg.pad) end
    if cfg.bands then
        local il, it, ir, ib = unpack(cfg.inset)
        return il, it + (cfg.cap or 0), ir, ib + (cfg.cap or 0)
    end
    return 14, 14, 14, 14
end

-- Couleur d'un texte de Spoken. L'opacite n'est jamais touchee : Spoken s'en sert pour ses
-- fondus (le "(Arrete)" qui prend la place du titre, par exemple) ; `dim` eclaircit ou fonce
-- la couleur vers le gris a la place.
local function Ink(fs, c, dim, shadow)
    if type(fs) ~= "table" or not fs.SetTextColor then return end
    local r, g, b = c[1], c[2], c[3]
    if dim and dim < 1 then
        r, g, b = r * dim + 0.5 * (1 - dim), g * dim + 0.5 * (1 - dim), b * dim + 0.5 * (1 - dim)
    end
    local a = 1
    if fs.GetTextColor then
        local ok, _, _, _, ca = pcall(fs.GetTextColor, fs)
        if ok and type(ca) == "number" then a = ca end
    end
    fs:SetTextColor(r, g, b, a)
    if fs.SetShadowColor then fs:SetShadowColor(0, 0, 0, shadow and 1 or 0) end
end

---------------------------------------------------------------- Sous-titres
local SUB_REACH, SUB_TOP, SUB_BOTTOM = 40, 12, 12 -- les marges des sous-titres de Spoken
local SUB_INK = { title = { 1, 0.82, 0 }, grey = { 0.62, 0.62, 0.62 }, words = { 1, 1, 1 } }
local subParts, subArea
local subPaint = { id = nil }

local function SubGreys(sub)
    return { sub.dot, sub.label, sub.pausedLabel, sub.heldDot, sub.held, sub.moreDot, sub.more }
end
-- Couleurs du texte : celles du theme, ou celles de Spoken.
local function InkSubtitle(sub, cfg)
    local shadow = (not cfg) or cfg.shadow == 1
    local hdr = cfg and cfg.hdr or SUB_INK.title
    local body = cfg and cfg.body or SUB_INK.words
    Ink(sub.title, hdr, 1, shadow)
    for _, fs in ipairs(SubGreys(sub)) do
        if cfg then Ink(fs, body, 0.7, shadow) else Ink(fs, SUB_INK.grey, 1, true) end
    end
    for _, line in ipairs(sub.lines or {}) do Ink(line, body, 1, shadow) end
end
-- Mot lu : rouge fonce sur un papier clair (l'or de Spoken s'y lit mal).
local function SubHighlight(line, text)
    if line.dweInking or type(text) ~= "string" then return end
    -- Hommage a une personne disparue : le texte reste uni.
    if text:find("|c", 1, true) and DWE.IsMemorialClip(SpokenCurClip()) then
        line.dweInking = true
        line:SetText((text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")))
        line.dweInking = nil
        return
    end
    local mark = subPaint.cfg and DWE.ThemeMark(subPaint.cfg)
    if not mark or mark == SPOKEN_GOLD or not text:find(SPOKEN_GOLD, 1, true) then return end
    line.dweInking = true
    line:SetText((text:gsub(SPOKEN_GOLD, mark)))
    line.dweInking = nil
end
local function HookSubLine(line)
    if type(line) ~= "table" or line.dweInkHook or not line.SetText then return end
    line.dweInkHook = true
    hooksecurefunc(line, "SetText", SubHighlight)
end

-- Boutons de Spoken sous le texte : descendus sous le bas du cadre du theme.
local function PlaceSubControls(sub, below)
    local c = sub.controls
    if type(c) ~= "table" or not c.ClearAllPoints then return end
    c:ClearAllPoints()
    c:SetPoint("TOP", sub.shadow, "BOTTOM", 0, -2 - (below or 0))
end

function DWE.PaintSpokenSubtitle()
    local env = rawget(_G, "SpokenEnv")
    local sub = type(env) == "table" and rawget(env, "Subtitle")
    local fr = type(sub) == "table" and sub.frame
    local anchor = type(sub) == "table" and sub.shadow
    if not (fr and anchor) then return end
    subParts = subParts or CreateThemeParts(fr, fr:GetFrameLevel())
    -- La zone du texte : le bandeau de Spoken depasse de SUB_REACH de chaque cote.
    if not subArea then
        subArea = CreateFrame("Frame", nil, fr)
        subArea:EnableMouse(false)
        subArea:SetPoint("TOPLEFT", anchor, "TOPLEFT", SUB_REACH, -SUB_TOP)
        subArea:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -SUB_REACH, SUB_BOTTOM)
    end
    local okB, base = pcall(function() return env.Addon:Profile("Transcript").SubtitleShadow end)
    base = (okB and tonumber(base)) or 0.5
    -- Livre de l'addon ouvert : une page de grimoire sombre (comme avant).
    if DWE.bookMode and DWE.BookStyleNow() == "addon" then
        subPaint.id, subPaint.cfg = nil, nil
        PaintThemeParts(subParts, anchor, nil, "bookpaper_dark")
        anchor:SetAlpha(base)
        if subPaint.inked then subPaint.inked = nil; InkSubtitle(sub, nil); PlaceSubControls(sub, 0) end
        return
    end
    local id, cfg = SpokenOwnStyle()
    -- Sans cadre : pas de fond ni de bandeau, le texte et son ombre (comme les conversations).
    if id then
        subPaint.id, subPaint.cfg = id, cfg
        PaintThemeParts(subParts, subArea, nil, id)
        anchor:SetAlpha(0)
        InkSubtitle(sub, cfg)
        subPaint.inked = true
        local _, _, _, pb = ThemeReach(cfg)
        PlaceSubControls(sub, math.max(0, pb - SUB_BOTTOM) + 2)
    else
        subPaint.id, subPaint.cfg = nil, nil
        ClearThemeParts(subParts)
        anchor:SetAlpha(base)
        -- Retour au look de Spoken (une seule fois : on ne touche plus a ses couleurs ensuite).
        if subPaint.inked then subPaint.inked = nil; InkSubtitle(sub, nil); PlaceSubControls(sub, 0) end
    end
end

---------------------------------------------------------------- Petite fenetre
local miniParts, miniArea, miniPainted
-- Petite fenetre de Spoken remise en page comme son lecteur facon DialogueUI (la "carte") :
-- meme taille, petit portrait en haut a gauche, nom en petit, titre dessous, boutons en haut a
-- droite, texte en dessous. Mesures de ce lecteur (Spoken, DialogueUIPlayer.lua) a la taille
-- par defaut de DialogueUI ; l'echelle 0.65 est la sienne.
local CARD = {
    scale = 0.65 / 0.7,   -- son echelle, rapportee a "Taille de la fenetre" de Spoken (0.7 par defaut)
    width = 580,          -- largeur de la fenetre (marges comprises)
    side = 26,            -- marge de cote
    inset = 18,           -- haut du contenu (marge de la petite fenetre)
    face = 58, faceX = 47, faceY = 35,   -- portrait : diametre et centre (depuis le haut-gauche du contenu)
    textX = 86, nameY = -1, titleY = -22,
    nameSize = 16, titleSize = 23, wordsSize = 19, wordsGap = 7,
    buttons = 1.5, buttonsY = -27, buttonsX = -1,
    wordsY = -88,         -- haut du texte (Spoken : -44)
    wordsPad = 37,        -- retrait du texte de chaque cote de la colonne
    below = 69,           -- le cadre descend d'autant sous la fenetre de Spoken (texte plus bas)
}
DWE.SPOKEN_CARD = CARD
local cardOn
local function CardFont(fs, size)
    if type(fs) ~= "table" or not fs.GetFont then return end
    local face, _, flags = fs:GetFont()
    if face then fs:SetFont(face, size, flags or "") end
end
local function CardScale(mp, env)
    local okC, fs = pcall(function() return env.Addon:Profile("Frame").FrameScale end)
    fs = (okC and tonumber(fs)) or 0.7
    if mp.frame.SetScale then mp.frame:SetScale(fs * (cardOn and CARD.scale or 1)) end
end
-- Texte et barre de progression : Spoken les replace a chaque mise en page, on repasse apres.
local function CardDock(mp, env)
    if not cardOn then return end
    local frame, content = mp.frame, mp.content
    local inner = math.max(1, (frame:GetWidth() or CARD.width) - 2 * CARD.side)
    local wl = CARD.wordsPad
    local ww = math.max(1, inner - 2 * wl)
    local tr = rawget(env, "Transcript")
    local okH, words = pcall(tr.HeightForClip, tr, mp.clip)
    words = (okH and tonumber(words)) or 0
    -- Spoken mesure a sa taille de texte ; la carte ecrit plus grand : la hauteur de ses lignes.
    if words > 0 then
        local lines = 2
        pcall(function() if env.Addon:Profile("Transcript").Lines == 1 then lines = 1 end end)
        words = lines * (CARD.wordsSize + CARD.wordsGap) + 4
    end
    if type(tr) == "table" and type(tr.Dock) == "function" then
        pcall(tr.Dock, tr, frame, content, "TOPLEFT", wl, CARD.wordsY, ww, words)
    end
    local track = mp.progress and mp.progress.track
    if track and track.SetPoint then
        -- Spoken la pose sous le texte (a -44 - mots - 6) : decalee comme le texte.
        local barTop = 44 + words + 6
        track:ClearAllPoints()
        track:SetPoint("TOPLEFT", content, "TOPLEFT", wl, CARD.wordsY - (barTop - 44))
        track:SetWidth(ww)
    end
end
local function CardOn(mp, env, palette, shadow)
    local frame, content = mp.frame, mp.content
    local hidePortrait = false
    pcall(function() hidePortrait = env.Addon:Profile("Frame").HidePortrait end)
    cardOn = true
    -- Largeur de la carte, tant que le joueur n'a pas elargi la fenetre lui-meme.
    local saved
    pcall(function() saved = env.Addon:Layout().Minimal end)
    if not (type(saved) == "table" and saved.width) and math.abs((frame:GetWidth() or 0) - CARD.width) > 0.5 then
        frame:SetWidth(CARD.width)
    end
    CardScale(mp, env)
    content:ClearAllPoints()
    content:SetPoint("TOPLEFT", frame, "TOPLEFT", CARD.side, -CARD.inset)
    content:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -CARD.side, -CARD.inset)
    local pt = mp.portrait
    if pt and pt.SetScale then
        local k = CARD.face / 90
        pt:SetScale(k)
        pt:ClearAllPoints()
        pt:SetPoint("CENTER", content, "TOPLEFT", CARD.faceX / k, -CARD.faceY / k)
        pt:SetShown(not hidePortrait)
    end
    local x = hidePortrait and 0 or CARD.textX
    local ctl = mp.controls
    if ctl and ctl.SetScale then
        ctl:SetScale(CARD.buttons)
        ctl:ClearAllPoints()
        ctl:SetPoint("RIGHT", content, "TOPRIGHT", CARD.buttonsX / CARD.buttons, CARD.buttonsY / CARD.buttons)
    end
    if mp.name and ctl then
        mp.name:ClearAllPoints()
        mp.name:SetPoint("TOPLEFT", content, "TOPLEFT", x, CARD.nameY)
        mp.name:SetPoint("RIGHT", ctl, "LEFT", -8, 0)
        if mp.name.SetHeight then mp.name:SetHeight(CARD.nameSize + 4) end
    end
    if mp.title and mp.title.ClearAllPoints and ctl then
        mp.title:ClearAllPoints()
        mp.title:SetPoint("TOPLEFT", content, "TOPLEFT", x, CARD.titleY)
        mp.title:SetPoint("RIGHT", ctl, "LEFT", -8, 0)
        if mp.title.SetHeight then mp.title:SetHeight(CARD.titleSize + 6) end
    end
    CardFont(mp.name, CARD.nameSize)
    CardFont(mp.title and mp.title.text, CARD.titleSize)
    local cfg = palette
    local ink = { title = cfg.hdr, name = cfg.body, words = cfg.body, highlight = DWE.ThemeMark(cfg) or SPOKEN_GOLD }
    if DWE.IsMemorialClip(mp.clip or SpokenCurClip()) then
        local b = cfg.body
        ink.highlight = string.format("|cff%02x%02x%02x", math.floor(b[1] * 255 + 0.5), math.floor(b[2] * 255 + 0.5), math.floor(b[3] * 255 + 0.5))
    end
    Ink(mp.name, ink.name, 0.8, shadow)
    Ink(mp.title and mp.title.text, ink.title, 1, shadow)
    for _, fs in ipairs({ mp.stopped, mp.count, mp.held }) do Ink(fs, ink.name, 0.7, shadow) end
    local tr = rawget(env, "Transcript")
    if type(tr) == "table" and type(tr.SetStyle) == "function" then
        local lines = 2
        pcall(function() if env.Addon:Profile("Transcript").Lines == 1 then lines = 1 end end)
        pcall(tr.SetStyle, tr, { color = ink.words, shadow = shadow, highlight = ink.highlight, lines = lines, size = CARD.wordsSize, lineGap = CARD.wordsGap })
    end
    CardDock(mp, env)
end
-- Retour a la petite fenetre de Spoken telle qu'il la dessine.
local function CardOff(mp, env)
    if not cardOn then return end
    cardOn = nil
    local pt = mp.portrait
    if pt and pt.SetScale then
        pt:SetScale(1)
        pt:ClearAllPoints()
        pt:SetPoint("TOPLEFT", mp.frame, "TOPLEFT", 0, -4)
    end
    if mp.controls and mp.controls.SetScale then
        mp.controls:SetScale(1)
        mp.controls:ClearAllPoints()
        mp.controls:SetPoint("RIGHT", mp.content, "TOPRIGHT", 0, -20)
    end
    if mp.name and mp.name.SetHeight then mp.name:SetHeight(21) end
    if mp.title and mp.title.SetHeight then mp.title:SetHeight(19) end
    if mp.name and mp.controls then
        mp.name:ClearAllPoints()
        mp.name:SetPoint("TOPLEFT", mp.content, "TOPLEFT", 0, 0)
        mp.name:SetPoint("RIGHT", mp.controls, "LEFT", -8, 0)
    end
    if mp.title and mp.title.ClearAllPoints and mp.controls then
        mp.title:ClearAllPoints()
        mp.title:SetPoint("TOPLEFT", mp.content, "TOPLEFT", 0, -21)
        mp.title:SetPoint("RIGHT", mp.controls, "LEFT", -8, 0)
    end
    CardFont(mp.name, 16)
    CardFont(mp.title and mp.title.text, 12)
    CardScale(mp, env)
    local pf = rawget(env, "PlayerFrame")
    if type(mp.RefreshConfig) == "function" and pf then pcall(mp.RefreshConfig, mp, pf) end
end
function DWE.SpokenCardOn() return cardOn and true or false end

-- Le cadre du theme autour de la petite fenetre ; `mp.dweArtExtra` l'agrandit vers le haut
-- pour y loger l'illustration du lieu (une seule carte).
function DWE.MiniAreaAnchor(mp)
    if not miniArea then return end
    miniArea:ClearAllPoints()
    miniArea:SetPoint("TOPLEFT", mp.frame, "TOPLEFT", CARD.side, -CARD.inset + 4 + (mp.dweArtExtra or 0))
    miniArea:SetPoint("BOTTOMRIGHT", mp.frame, "BOTTOMRIGHT", -CARD.side, 14 - CARD.below)
end
local function PaintMinimal()
    local env = rawget(_G, "SpokenEnv")
    local mp = type(env) == "table" and rawget(env, "MinimalPlayer")
    local panel = type(mp) == "table" and mp.panel
    if not (panel and mp.paper and mp.frame) then return end
    miniParts = miniParts or CreateThemeParts(panel, panel:GetFrameLevel())
    miniArea = miniArea or CreateFrame("Frame", nil, panel)
    local id, cfg = SpokenOwnStyle()
    -- Habillage EllesmereUI choisi dans Spoken : on le laisse.
    if panel.spokenEllesmere == true then id = nil end
    mp.dweThemeId = id
    if id then
        -- Le cadre du theme autour de la colonne de texte de la carte (comme sur le lecteur
        -- facon DialogueUI, ou il entoure son contenu).
        DWE.MiniAreaAnchor(mp)
        PaintThemeParts(miniParts, miniArea, nil, id)
        mp.paper:SetAlpha(0)
        if panel.SetBackdropBorderColor then panel:SetBackdropBorderColor(1, 1, 1, 0) end
        miniPainted = true
        CardOn(mp, env, cfg, cfg.shadow == 1)
    elseif miniPainted then
        -- Retour au look de Spoken : il redessine lui-meme son papier, son cadre et ses couleurs.
        miniPainted = nil
        ClearThemeParts(miniParts)
        CardOff(mp, env)
        mp.paper:SetAlpha(1)
        local bronze = rawget(env, "Actions") and env.Actions.Bronze and env.Actions.Bronze()
        if panel.SetBackdropBorderColor then
            if bronze then panel:SetBackdropBorderColor(bronze[1], bronze[2], bronze[3], 1)
            else panel:SetBackdropBorderColor(1, 1, 1, 1) end
        end
        if type(mp.Dress) == "function" then pcall(mp.Dress, mp) end
    end
end
local miniBusy
function DWE.PaintSpokenMinimal()
    if miniBusy then return end
    miniBusy = true
    pcall(PaintMinimal)
    miniBusy = nil
    if DWE.ZoneArtRefresh then DWE.ZoneArtRefresh() end
end

-- Illustration de lieu (Spoken Places la fournit avec sa narration) au-dessus de la petite
-- fenetre de Spoken, qui ne la montre pas (seul son lecteur facon DialogueUI le fait). Option,
-- active par defaut. Tout passe par ZoneArtOf : le jour ou Spoken offre une fonction officielle
-- pour l'image d'une ligne, seule celle-ci change. Si la petite fenetre montre un jour l'image
-- elle-meme, Storytale se retire.
local ZONE_ART_GAP, ZONE_ART_ALPHA = 4, 0.95
local function ZoneArtOf(clip)
    local pic = type(clip) == "table" and type(clip.present) == "table" and clip.present.picture
    if type(pic) ~= "table" or not pic.file then return nil end
    return pic
end
DWE.ZoneArtOf = ZoneArtOf
function DWE.ZoneArtWanted() return DialogueWheelE_ZoneArt ~= false end
-- Marge entre l'image et le cadre du theme qui l'entoure.
local ZONE_ART_PAD = 8
-- Part du bas de l'image qui s'efface dans le fond de la carte, vers le texte.
local ZONE_ART_FADE = 0.45
-- Bord de papier peint dans les images de Spoken (512 x 256) : environ 24 px en haut et en bas,
-- 20 px sur les cotes, en bords dechires irreguliers.
local ZONE_ART_CROP_U, ZONE_ART_CROP_V = 0.05, 0.12
-- Agrandit (ou rend) le cadre du theme de la petite fenetre, et le redessine.
local function SetArtExtra(mp, extra)
    if (mp.dweArtExtra or 0) == extra then return end
    mp.dweArtExtra = extra
    if miniPainted and miniArea and mp.dweThemeId then
        DWE.MiniAreaAnchor(mp)
        PaintThemeParts(miniParts, miniArea, nil, mp.dweThemeId)
    end
end
function DWE.SpokenZoneArt(mp)
    if type(mp) ~= "table" or not (mp.frame and mp.panel) then return end
    local holder = mp.dweZoneHolder
    local pic = DWE.ZoneArtWanted() and ZoneArtOf(mp.clip) or nil
    -- La petite fenetre de Spoken a sa propre image : on ne double pas.
    if mp.picture ~= nil and mp.picture ~= mp.dweZoneArt then pic = nil end
    if not pic then
        if holder then holder:Hide() end
        SetArtExtra(mp, 0)
        return
    end
    if not holder then
        holder = CreateFrame("Frame", nil, mp.frame)
        holder:SetFrameLevel(mp.frame:GetFrameLevel() + 1)
        holder:EnableMouse(false)
        mp.dweZoneHolder = holder
        holder.parts = CreateThemeParts(holder, holder:GetFrameLevel())
        -- L'image sur son propre calque, au-dessus du cadre du theme : le fond du cadre (souvent
        -- sombre et semi-opaque) passait par-dessus et l'assombrissait.
        local layer = CreateFrame("Frame", nil, holder)
        layer:SetAllPoints(holder)
        layer:SetFrameLevel(holder:GetFrameLevel() + 5)
        layer:EnableMouse(false)
        local art = layer:CreateTexture(nil, "ARTWORK")
        mp.dweZoneArt = art
        if layer.CreateMaskTexture and art.AddMaskTexture then
            art.mask = layer:CreateMaskTexture()
            art.mask:SetAllPoints(art)
            art:AddMaskTexture(art.mask)
            art.maskOn = true
        end
    end
    local art = mp.dweZoneArt
    local id = miniPainted and mp.dweThemeId or nil
    art:SetTexture(pic.file)
    art:SetAlpha(ZONE_ART_ALPHA)
    art:ClearAllPoints()
    holder:ClearAllPoints()
    ClearThemeParts(holder.parts)
    if id then
        -- Une seule carte : le cadre du theme de la fenetre s'agrandit vers le haut, l'image en
        -- occupe le haut et son bas s'efface dans le fond, vers le texte.
        local pad = ZONE_ART_PAD
        local w = math.max(1, (mp.frame:GetWidth() or 0) - 2 * CARD.side - 2 * pad)
        -- Les images de Spoken ont un bord de papier clair peint dedans. Dans la carte d'un theme,
        -- on le retire (le fond du theme fait office de papier) : la scene seule, a ses proportions.
        local cfgT = THEME_STYLES[id]
        local frameless = cfgT and cfgT.none
        local cu, cv = ZONE_ART_CROP_U, ZONE_ART_CROP_V
        -- Sans fond (Frameless), l'image garde son papier et ses bords dechires. Option : garder
        -- aussi le papier dans la carte des autres themes (effet livre de contes).
        local paper = DialogueWheelE_ZoneArtPaper == true
        if frameless or paper then cu, cv = 0, 0 end
        local h = math.floor(w * ((1 - 2 * cv) * 256) / ((1 - 2 * cu) * 512) + 0.5)
        local function V(f) return cv + (1 - 2 * cv) * f end
        SetArtExtra(mp, h + pad)
        holder:SetPoint("TOPLEFT", miniArea, "TOPLEFT", pad, -pad)
        holder:SetSize(w, h)
        -- Sans fond (Frameless) : rien pour accueillir le fondu. Bords dechires de Spoken sur
        -- les quatre cotes, l'image juste au-dessus du texte.
        if frameless then
            for _, t in ipairs(holder.strips or {}) do t:Hide() end
            if art.mask then
                if not art.maskOn and art.AddMaskTexture then art:AddMaskTexture(art.mask); art.maskOn = true end
                art.mask:SetTexture(pic.mask or [[Interface\Buttons\WHITE8X8]], "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            end
            art:SetTexCoord(0, 1, 0, 1)
            art:SetAllPoints(holder)
            art:Show()
            holder:Show()
            return
        end
        -- Le bas s'efface en bandes d'opacite decroissante. Bandes de hauteur entiere, sans
        -- calage sur la grille de pixels : des bandes de 2 pixels a cheval sur deux pixels
        -- laissaient des trous (l'image paraissait translucide a partir du fondu).
        local band = 3
        local fadeH = math.floor(h * ZONE_ART_FADE / band + 0.5) * band
        local solid = h - fadeH
        local n = math.max(1, fadeH / band)
        -- Meme rendu pour le haut et les bandes : pas de masque sur l'image dans la carte.
        if art.mask and art.maskOn and art.RemoveMaskTexture then
            art:RemoveMaskTexture(art.mask); art.maskOn = false
        end
        local function NoSnap(t)
            if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(false) end
            if t.SetTexelSnappingBias then t:SetTexelSnappingBias(0) end
        end
        NoSnap(art)
        art:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
        art:SetSize(w, solid)
        art:SetTexCoord(cu, 1 - cu, V(0), V(solid / h))
        local strips = holder.strips or {}
        holder.strips = strips
        for i = 1, #strips do strips[i]:Hide() end
        for i = 1, n do
            local t = strips[i] or art:GetParent():CreateTexture(nil, "ARTWORK")
            strips[i] = t
            NoSnap(t)
            t:SetTexture(pic.file)
            local y0 = solid + band * (i - 1)
            t:SetTexCoord(cu, 1 - cu, V(y0 / h), V((y0 + band) / h))
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -y0)
            t:SetSize(w, band)
            -- Opacite au milieu de la bande, de pleine (en haut) a nulle (en bas). Courbe en S :
            -- la baisse demarre a plat, sans bord visible au debut du fondu.
            local x = (i - 0.5) / n
            t:SetAlpha(ZONE_ART_ALPHA * (1 - x * x * (3 - 2 * x)))
            t:Show()
        end
    else
        -- Look de Spoken : l'image seule au-dessus de la fenetre, avec ses bords dechires.
        SetArtExtra(mp, 0)
        for _, t in ipairs(holder.strips or {}) do t:Hide() end
        if art.mask then
            if not art.maskOn and art.AddMaskTexture then art:AddMaskTexture(art.mask); art.maskOn = true end
            art.mask:SetTexture(pic.mask or [[Interface\Buttons\WHITE8X8]], "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        end
        art:SetTexCoord(0, 1, 0, 1)
        local panel = mp.panel
        local w = math.max(1, (panel:GetWidth() or 0) - 16)
        local h = math.floor(w / 2 + 0.5)
        holder:SetSize(w, h)
        art:SetAllPoints(holder)
        local top, screen = mp.frame:GetTop(), UIParent and UIParent:GetTop()
        local scale = (mp.frame:GetEffectiveScale() or 1) / ((UIParent and UIParent:GetEffectiveScale()) or 1)
        if top and screen and (top + h + ZONE_ART_GAP) * scale > screen then
            holder:SetPoint("TOP", panel, "BOTTOM", 0, -ZONE_ART_GAP)
        else
            holder:SetPoint("BOTTOM", panel, "TOP", 0, ZONE_ART_GAP)
        end
    end
    art:Show()
    holder:Show()
end
local function ZoneArtRefresh()
    local env = rawget(_G, "SpokenEnv")
    local mp = type(env) == "table" and rawget(env, "MinimalPlayer")
    if type(mp) == "table" then pcall(DWE.SpokenZoneArt, mp) end
end
DWE.ZoneArtRefresh = ZoneArtRefresh

-- Accroches posees une fois, des que Spoken est la (ses fenetres sont creees plus tard, a la
-- premiere replique : on repasse a leur creation et a chaque mise en page).
local stylesHooked = {}
function DWE.HookSpokenStyles()
    local env = rawget(_G, "SpokenEnv")
    if type(env) ~= "table" then return end
    local sub = rawget(env, "Subtitle")
    if type(sub) == "table" and not stylesHooked.sub and type(sub.Layout) == "function" then
        stylesHooked.sub = true
        local function Paint() pcall(DWE.PaintSpokenSubtitle) end
        if type(sub.Build) == "function" then hooksecurefunc(sub, "Build", Paint) end
        hooksecurefunc(sub, "Layout", Paint)
        -- Spoken remet l'opacite de son bandeau a chaque mise a jour.
        if type(sub.Update) == "function" then
            hooksecurefunc(sub, "Update", function(self)
                if subPaint.id and type(self.shadow) == "table" then self.shadow:SetAlpha(0) end
            end)
        end
        if type(sub.Line) == "function" then
            hooksecurefunc(sub, "Line", function(self, index)
                local line = self.lines and self.lines[index]
                HookSubLine(line)
                local cfg = subPaint.cfg
                if cfg and line then Ink(line, cfg.body, 1, cfg.shadow == 1) end
            end)
        end
        for _, line in ipairs(sub.lines or {}) do HookSubLine(line) end
        Paint()
    end
    local mp = rawget(env, "MinimalPlayer")
    -- Epitaphe : le titre (In Loving Memory) centre aussi ; l'etiquette au-dessus ne bouge pas.
    if type(mp) == "table" and not stylesHooked.miniCenter and type(mp.Count) == "function" then
        stylesHooked.miniCenter = true
        hooksecurefunc(mp, "Count", function(self)
            local t = self.title and self.title.text
            if not (t and t.SetJustifyH) then return end
            local center = DWE.CenteredClip(self.clip)
            if center then
                t:SetJustifyH("CENTER")
                -- Meme axe que l'epitaphe (zone de texte de Spoken), pas celui de la ligne du titre.
                local tr = rawget(env, "Transcript")
                local fr = type(tr) == "table" and tr.frame
                local d = 0
                if fr and fr.GetCenter and self.title.GetCenter then
                    local a, b = fr:GetCenter(), self.title:GetCenter()
                    if a and b then d = a - b end
                end
                t:ClearAllPoints()
                t:SetPoint("TOPLEFT", self.title, "TOPLEFT", d, 0)
                t:SetPoint("BOTTOMRIGHT", self.title, "BOTTOMRIGHT", d, 0)
                self.dweCentered = true
            elseif self.dweCentered then
                self.dweCentered = nil
                t:SetJustifyH("LEFT")
                if self.tail and self.tail.Fit then pcall(self.tail.Fit, self.tail, t, self.title:GetWidth() or 0) end
            end
        end)
    end
    if type(mp) == "table" and not stylesHooked.mini and type(mp.Dress) == "function" then
        stylesHooked.mini = true
        -- Dress : Spoken y remet son papier et ses couleurs ; on repasse juste apres.
        hooksecurefunc(mp, "Dress", DWE.PaintSpokenMinimal)
        if type(mp.RefreshConfig) == "function" then hooksecurefunc(mp, "RefreshConfig", DWE.PaintSpokenMinimal) end
        if type(mp.Layout) == "function" then
            hooksecurefunc(mp, "Layout", function(self)
                -- Nouvelle ligne (un PNJ, puis un livre...) : son propre habillage.
                if self.clip ~= self.dwePaintedClip then
                    self.dwePaintedClip = self.clip
                    DWE.PaintSpokenMinimal()
                end
                if cardOn then pcall(CardDock, self, env) end
                pcall(DWE.SpokenZoneArt, self)
            end)
        end
        DWE.PaintSpokenMinimal()
    end
    -- Spoken cache sa petite fenetre tant qu'une fenetre de dialogue du jeu est ouverte. Storytale
    -- garde celle-ci ouverte (invisible) sous la roue : quand le joueur choisit le lecteur Spoken
    -- (bouton de bascule ou touche), la fenetre du jeu ne "couvre" plus rien.
    local actions = rawget(env, "Actions")
    if type(actions) == "table" and not stylesHooked.covers and type(actions.DialogCovers) == "function" then
        stylesHooked.covers = true
        local origCovers = actions.DialogCovers
        actions.DialogCovers = function(...)
            -- Storytale decide : cachee quand ses regles cachent les fenetres de Spoken (texte de
            -- Storytale a l'ecran, lignes a la demande...), visible sinon pendant une conversation.
            if DWE.choiceBox and DWE.choiceBox:IsShown() or DWE.spokenHeldHide then
                return DWE.SpokenMinimalHidden()
            end
            return origCovers(...)
        end
        DWE.spokenCoversOwn = true
        local f = rawget(_G, "SpokenMinimalPlayerFrame")
        if f and f.dweMouseCut ~= nil then DWE.HideExtras(f, false) end
    end
    -- Sans DialogueUI, Spoken montre ses sous-titres par defaut : la carte les remplace, tant
    -- que le joueur n'a pas choisi lui-meme un style dans Spoken (en memoire seulement, rien
    -- n'est ecrit dans ses reglages).
    local addon = rawget(env, "Addon")
    if type(addon) == "table" and not stylesHooked.style and type(addon.PlayerStyle) == "function" then
        stylesHooked.style = true
        local origStyle = addon.PlayerStyle
        addon.PlayerStyle = function(self, ...)
            local style = origStyle(self, ...)
            if style == "subtitle" and DWE.SpokenCardWanted() then return "minimal" end
            return style
        end
        if type(addon.SetPlayerStyle) == "function" then
            hooksecurefunc(addon, "SetPlayerStyle", function() DialogueWheelE_SpokenStyleChosen = true end)
        end
        DWE.SpokenStyleSync()
        -- Les reglages par defaut de Storytale sont poses juste apres (meme connexion) : on repasse.
        if C_Timer and C_Timer.After then C_Timer.After(1, DWE.SpokenStyleSync) end
    end
end
-- Spoken redessine ses fenetres quand le style montre change (carte <-> sous-titres) : sinon
-- la petite fenetre n'est jamais creee et rien ne s'affiche jusqu'au /reload suivant.
local lastCard
function DWE.SpokenStyleSync()
    local want = DWE.SpokenCardWanted() and true or false
    if want == lastCard then return end
    lastCard = want
    local env = rawget(_G, "SpokenEnv")
    local pf = type(env) == "table" and rawget(env, "PlayerFrame")
    if type(pf) == "table" and type(pf.RefreshConfig) == "function" then pcall(pf.RefreshConfig, pf) end
    local tr = type(env) == "table" and rawget(env, "Transcript")
    if type(tr) == "table" and type(tr.RefreshConfig) == "function" then pcall(tr.RefreshConfig, tr) end
end
function DWE.SpokenCardWanted()
    if DWE.DUI_ON or DialogueWheelE_SpokenStyleChosen == true then return false end
    return DialogueWheelE_SpokenTheme == true
end
do
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function() pcall(DWE.HookSpokenStyles) end)
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
do -- (bloc : ses variables ne comptent pas dans la limite du fichier)
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
local ignoredUI = {} -- cadres remis a suivre l'opacite de leur parent (a rendre a la fin)
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
    local list = { UIParent:GetChildren() }
    -- (chaque cadre dans un pcall : un cadre interdit aux addons ne doit rien casser)
    local function One(fr)
        if fr.IsForbidden and fr:IsForbidden() then return end
        if KeepFrame(fr) then return end
        -- Fenetres qui ignorent l'opacite de leur parent (fenetres de chat de Chattynator) : elles
        -- la suivent de nouveau le temps de la conversation, pour s'effacer avec le reste.
        for _, k in ipairs({ fr:GetChildren() }) do
            pcall(function()
                if k:IsForbidden() or k:IsProtected() or ignoredUI[k] or KeepFrame(k) then return end
                local ign = k:IsIgnoringParentAlpha()
                -- (valeur secrete du jeu : on n'y touche pas)
                if issecretvalue and issecretvalue(ign) then return end
                if ign == true then
                    k:SetIgnoreParentAlpha(false)
                    ignoredUI[k] = true
                end
            end)
        end
        if fr:IsShown() and not hiddenUI[fr] then
            local a = fr:GetAlpha()
            if type(a) == "number" and a > 0 then hiddenUI[fr] = a end
        end
    end
    for _, fr in ipairs(list) do pcall(One, fr) end
end
local function FadeUI(f)
    for fr, a in pairs(hiddenUI) do pcall(fr.SetAlpha, fr, a * (1 - f)) end
end
local function RestoreUI()
    FadeUI(0)
    wipe(hiddenUI)
    -- (jamais de cadre protege ici : rendu meme en combat)
    for k in pairs(ignoredUI) do pcall(k.SetIgnoreParentAlpha, k, true) end
    wipe(ignoredUI)
end
DWE.HiddenUI = hiddenUI

cineBars:SetScript("OnUpdate", function(self, dt)
    local target = self.want and 1 or 0
    local a = self.alpha + (target - self.alpha) * math.min(1, dt * 6)
    if math.abs(target - a) < 0.01 then a = target end
    self.alpha = a
    self:SetAlpha(a)
    -- Pendant le fondu a chaque image ; ensuite dix fois par seconde (si un autre addon
    -- remontre un cadre ou change son opacite, comme le fondu d'un chat, il repart).
    self.tick = (self.tick or 0) + dt
    if a ~= self.lastA or self.tick > 0.1 then
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

-- Option "Cacher l'interface" : le meme fondu que le theme Cinematique (sans ses bandes noires),
-- avec n'importe quel theme, pendant une conversation ou un livre. Jamais en combat.
function DWE.HideUIOn() return DialogueWheelE_HideUI == true end
function DWE.UpdateCinemaBars()
    local talking = textBox:IsShown() or choiceBox:IsShown() or (DWE.bubble and DWE.bubble:IsShown())
    local cinema = DWE.IsCinema() and textBox:IsShown()
    local hideUI = DWE.HideUIOn() and talking and not (InCombatLockdown and InCombatLockdown())
    local want = (cinema or hideUI) and true or false
    cineBars.want = want
    -- Bandes noires : seulement avec le theme Cinematique (gardees pendant leur fondu de sortie).
    if want then
        cineTop:SetShown(cinema and true or false)
        cineBot:SetShown(cinema and true or false)
    end
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
choiceBox:HookScript("OnShow", function() DWE.UpdateCinemaBars() end)
choiceBox:HookScript("OnHide", function() if C_Timer then C_Timer.After(0, DWE.UpdateCinemaBars) else DWE.UpdateCinemaBars() end end)
do
    local combat = CreateFrame("Frame")
    combat:RegisterEvent("PLAYER_REGEN_DISABLED")
    combat:RegisterEvent("PLAYER_REGEN_ENABLED")
    combat:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            -- Entree en combat : l'interface revient tout de suite.
            if DWE.HideUIOn() and not DWE.IsCinema() then cineBars.want = false end
        else
            DWE.UpdateCinemaBars()
        end
    end)
end
end

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
DWE.bookSpreadTex = bookL
local bookR = { Hide = function() end, Show = function() end, ClearAllPoints = function() end, SetPoint = function() end }
local noteBg = textBox:CreateTexture(nil, "BACKGROUND", nil, -7)
noteBg:SetTexture(ADDON_PATH .. "BookPaper.png")
if noteBg.SetTextureSliceMargins then pcall(noteBg.SetTextureSliceMargins, noteBg, 90, 90, 90, 90) end
noteBg:Hide()

-- Tablettes trolles : les cotes de la frise (lignes 216 a 424 de la texture) se repetent tous les
-- 104 pixels (la bande 216-320 boucle sans raccord : ses dernieres lignes rejoignent la 216). Une tablette haute (beaucoup de texte) etirait ces glyphes ; on dessine donc le cadre
-- en morceaux, la bande des cotes repetee autant de fois qu'il faut au lieu d'etiree.
do
local REP = { a = 216, b = 320, c = 424, m = 124, tw = 1024, th = 640 }
local repPieces = {}
local function RepHide()
    for _, t in ipairs(repPieces) do t:Hide() end
    noteBg:SetAlpha(1)
end
hooksecurefunc(noteBg, "Hide", RepHide)
function DWE.NoteRepFrame(plate, W, H)
    if not (plate and plate.rep and W and H and W > 0 and H > 0) then RepHide(); return false end
    local s = W / REP.tw
    local per = (REP.b - REP.a) * s
    local avail = H - (REP.a + REP.th - REP.c) * s
    if avail < per * 0.5 then RepHide(); return false end
    local n = math.max(1, math.floor(avail / per + 0.5))
    local ph = avail / n
    local file = ADDON_PATH .. plate.tex .. ".png"
    local i = 0
    local function Piece(x, y, w, h, u0, u1, v0, v1, last)
        i = i + 1
        local t = repPieces[i]
        if not t then
            t = textBox:CreateTexture(nil, "BACKGROUND", nil, -7)
            if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(false); t:SetTexelSnappingBias(0) end
            repPieces[i] = t
        end
        t:SetTexture(file)
        t:SetTexCoord(u0 / REP.tw, u1 / REP.tw, v0 / REP.th, v1 / REP.th)
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", noteBg, "TOPLEFT", x, -y)
        -- Un demi-point de recouvrement : pas de fil clair entre deux morceaux.
        t:SetSize(w, last and h or h + 0.5)
        t:Show()
    end
    local m, cw = REP.m, REP.m * s
    for _, col in ipairs({ { 0, 0, m }, { W - cw, REP.tw - m, REP.tw } }) do
        local x, u0, u1 = col[1], col[2], col[3]
        Piece(x, 0, cw, REP.a * s, u0, u1, 0, REP.a)
        -- (La derniere bande est la copie d'origine : elle rejoint le bas sans raccord.)
        for k = 0, n - 1 do
            local v0, v1 = REP.a, REP.b
            if k == n - 1 then v0, v1 = REP.b, REP.c end
            Piece(x, REP.a * s + k * ph, cw, ph, u0, u1, v0, v1)
        end
        Piece(x, REP.a * s + avail, cw, (REP.th - REP.c) * s, u0, u1, REP.c, REP.th, true)
    end
    local mw = W - 2 * cw
    -- Milieu : memes coupes que les cotes (bords du creux alignes), seul le fond s'etire.
    Piece(cw, 0, mw, REP.a * s, m, REP.tw - m, 0, REP.a)
    Piece(cw, REP.a * s, mw, avail, m, REP.tw - m, REP.a, REP.c)
    Piece(cw, REP.a * s + avail, mw, (REP.th - REP.c) * s, m, REP.tw - m, REP.c, REP.th, true)
    for k = i + 1, #repPieces do repPieces[k]:Hide() end
    noteBg:SetAlpha(0)
    return true, n
end
end
-- Petales de rose sur le rebord d'une tombe en hommage a une personne disparue.
DWE.memorialPetals = textBox:CreateTexture(nil, "ARTWORK", nil, 2)
DWE.memorialPetals:SetTexture(ADDON_PATH .. "MemorialPetals.png")
DWE.memorialPetals:Hide()
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
    -- Disque grave de Dalaran (plaques des statues des heros) : rond, il ne s'etire pas, il grandit.
    Dalaran = { tex = "PlateDalaran", round = true, slice = { 0, 0, 0, 0 }, body = { 0.62, 0.71, 0.81 }, hdr = { 0.67, 0.76, 0.86 }, rule = { 0.02, 0.04, 0.09, 0.35 }, engrave = { 0.01, 0.02, 0.05, 0.9 }, engraveOffset = { -1, 1 },
        mini = { slice = { 124, 124, 124, 124 }, inner = { 136, 96, 136, 96 } } },
    -- Steles trolles (pas une matiere du jeu : reconnues par les donnees de Spoken Readables).
    Troll = { tex = "PlateTroll", rep = true, slice = { 124, 124, 124, 124 }, inner = { 92, 96, 92, 96 }, body = { 0.20, 0.11, 0.03 }, hdr = { 0.13, 0.07, 0.02 }, rule = { 0.36, 0.20, 0.06, 0.45 }, engrave = { 1, 0.92, 0.72, 0.5 } },
    Tablet = { tex = "PlateTablet", rep = true, slice = { 124, 124, 124, 124 }, inner = { 92, 96, 92, 96 }, body = { 0.20, 0.11, 0.03 }, hdr = { 0.13, 0.07, 0.02 }, rule = { 0.36, 0.20, 0.06, 0.45 }, engrave = { 1, 0.92, 0.72, 0.5 } },
}
-- Zones et donjons des tablettes trolles (Strangleronce, Zul'Farrak).
DWE.TROLL_ZONES, DWE.TROLL_DUNGEONS = { [1434] = true }, { [209] = true }
-- Carte de Strangleronce (1434) ou instance de Zul'Gurub (309, puis 859 depuis Cataclysm).
DWE.TROLL_INSTANCES = { [309] = true, [859] = true }
function DWE.InTrollLands()
    local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if map and DWE.TROLL_ZONES[map] then return true end
    if GetInstanceInfo then
        local id = select(8, GetInstanceInfo())
        if id and DWE.TROLL_INSTANCES[id] then return true end
    end
    return false
end
-- La page `pageId` de Spoken Readables est-elle une tablette trolle ?
-- Supports d'un texte selon la carte ou on le lit : texte de Khadgar (livre 289 de Spoken),
-- stele ronde dans les montagnes d'Alterac (Dalaran), plaque de bronze a Hurlevent.
DWE.ROUND_PLAQUES = { [289] = { [1416] = "Dalaran", [1453] = "Bronze" } }
function DWE.TrollTablet(pageId)
    if not pageId then return false end
    local sr = rawget(_G, "SpokenReadables")
    local places = rawget(_G, "SpokenReadablesPlaces")
    if type(sr) ~= "table" or type(places) ~= "table" or type(places.books) ~= "table" or not sr.Data then return false end
    local ok, data = pcall(sr.Data, sr)
    local page = ok and type(data) == "table" and type(data.pages) == "table" and data.pages[pageId]
    local entry = type(page) == "table" and places.books[page.book]
    if type(entry) ~= "table" then return false end
    -- Plaque ou tombe que le jeu donne pour du parchemin : de la pierre gravee. Un meme texte
    -- peut exister sur deux supports : c'est l'endroit ou on le lit qui decide (le texte de
    -- Khadgar est une stele ronde a Dalaran, une plaque de bronze a Hurlevent).
    if entry.type == "plaque" then
        local where = DWE.ROUND_PLAQUES[page.book]
        local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
        if where and map then
            if where[map] then return where[map], "plaque" end
        end
    end
    if entry.type == "plaque" or entry.type == "grave" then return "Stone", entry.type end
    if entry.type ~= "tablet" then return false, "book" end -- Spoken le connait : pas une tablette
    for _, z in ipairs(entry.zones or {}) do if DWE.TROLL_ZONES[z] then return "Troll" end end
    for _, d in ipairs(entry.dungeons or {}) do if DWE.TROLL_DUNGEONS[d] then return "Troll" end end
    return "Tablet" -- autre tablette (quetes de classe) : la stele sans gravures
end
-- Textes graves que le jeu donne pour du parchemin, reconnus a leur titre (toutes langues ; liste
-- faite a partir des objets "livres" de Wowhead) : tombes, monuments, plaques des heros de
-- Hurlevent, plaques du hall des Explorateurs, steles trolles. Ne joue que si le jeu ne donne
-- pas deja une vraie matiere. (Memes supports qu'avec Spoken Readables.)
DWE.STONE_TEXTS = {}
for plate, names in pairs({
    Stone = { "Archmage Khadgar of the Kirin Tor", "Erzmagier Khadgar von den Kirin Tor", "Archimago Khadgar del Kirin Tor", "Archimage Khadgar du Kirin Tor", "Arquimago Hadggar do Kirin Tor", "Верховный маг Кадгар из Кирин-Тора", "키린 토의 대마법사 카드가", "肯瑞托的大法师卡德加", "Danath Trollbane", "Danath Aterratrols", "Danath Matatroll", "Данат Троллебой", "다나스 트롤베인", "达纳斯·托尔贝恩", "General Turalyon", "Général Turalyon", "Генерал Туралион", "투랄리온 장군", "图拉扬将军", "Ranger Captain Alleria Windrunner", "Waldläufercaptain Alleria Windrunner", "Capitán guardabosques Alleria Brisaveloz", "Capitaine des forestiers Alleria Windrunner", "Capitão-patrulheira Alleria Correventos", "Капитан следопытов Аллерия Ветрокрылая", "순찰대장 알레리아 윈드러너", "游侠队长奥蕾莉亚·风行者", "Kurdran Wildhammer", "Kurdran Martillo Salvaje", "Kurdran Martelo Feroz", "Курдран Громовой Молот", "쿠르트란 와일드해머", "库德兰·蛮锤", "Archbishop Alonsus Faol", "Erzbischof Alonsus Faol", "Arzobispo Alonsus Faol", "Archevêque Alonsus Faol", "Arcebispo Alonso Faol", "Архиепископ Алонсий Фаол", "대주교 알론수스 파올", "大主教阿隆索斯·法奥", "King Llane I of the House of Wrynn", "König Llane I. aus dem Hause Wrynn", "El rey Llane I de la Casa de Wrynn", "Roi Llane Ier de la maison Wrynn", "Rei Llane I da Casa de Wrynn", "Король Ллейн I из рода Риннов", "린 가문의 국왕 레인 1세", "乌瑞恩家族的国王，莱尼一世", "Grand Admiral Daelin Proudmoore", "Großadmiral Daelin Proudmoore", "Almirante general Daelin Valiente", "Grand-amiral Daelin Proudmoore", "Grão-almirante Daelin Proudmore", "Великий адмирал Даэлин Праудмур", "댈린 프라우드무어 제독", "海军上将戴林·普罗德摩尔", "Lady Mara Fordragon", "Fürstin Mara Fordragon", "Dame Mara Fordragon", "Леди Мара Фордрагон", "여군주 마라 포드래곤", "玛拉·弗塔根" , "Eliza's Tombstone", "Elizas Grabstein", "Lápida de Eliza", "Tombe d'Eliza", "Lápide de Elisa", "Надгробный камень Элизы", "엘리자의 묘비", "伊莉莎的墓碑", "Yuriv's Tombstone", "Yurivs Grabstein", "Lápida de Yuriv", "Tombe de Yuriv", "Lápide de Yuriv", "Надгробная плита Юрива", "유리브의 묘비", "尤瑞夫的墓碑", "Decorated Headstone", "Geschmückter Grabstein", "Lápida decorada", "Pierre tombale décorée", "Lápide Decorada", "Резное надгробие", "꽃이 놓여진 묘비", "华丽的墓碑", "In Loving Memory", "In liebendem Angedenken", "En amado recuerdo", "Souvenir affectueux", "In memorian", "С вечной любовью", "사랑하는 안소니 여기 잠들다", "爱情的回忆", "Here Lies King Terenas Menethil II", "Hier ruht König Terenas Menethil II.", "Aquí yace el rey Terenas Menethil II", "Ci-gît le roi Terenas Menethil II", "Aqui Jaz o Rei Terenas Menethil II", "Здесь покоится Теренас Менетил II", "국왕 테레나스 메네실 2세 여기 잠들다", "泰瑞纳斯·米奈希尔二世在此长眠", "Uther the Lightbringer", "Uther Lightbringer", "Uther el Iluminado", "Uther, le Porteur de Lumière", "Uther, o Arauto da Luz", "Утер Светоносный", "빛의 수호자 우서", "光明使者乌瑟尔", "Monument to Grom Hellscream", "Denkmal für Grom Hellscream", "Monumento a Grom Grito Infernal", "Monument à Grom Hellscream", "Monument de Grom Hurlenfer", "Monumento para Grom Grito Infernal", "Памятник Грому Адскому Крику", "그롬 헬스크림의 기념비", "格罗姆·地狱咆哮的纪念碑", "Rock of Durotan", "Fels von Durotan", "Roca de Durotan", "Rocher de Durotan", "Rocha de Durotan", "Обелиск Дуротана", "듀로탄 바위", "杜隆坦之石", "Ancient Inscription", "Uralte Inschrift", "Inscripción antigua", "Inscription ancienne", "Inscrição Ancestral", "Древняя надпись", "고대 비문", "古代碑铭", "Carved Stone", "Verzierter Stein", "Piedra tallada", "Pierre sculptée", "Pedra Entalhada", "Резной камень", "조각된 돌", "Etched Carving", "Geätzte Schnitzerei", "Talla grabada", "Sculpture gravée", "Entalhe Cinzelado", "Резьба", "새겨진 조각품", "铭刻雕像", "Altar of Reverence", "Altar der Ehrerbietung", "Autel de révérence", "Altar da Reverência", "Алтарь почтения", "경배의 제단", "崇尊祭坛", "Altar of Thorns", "Altar der Dornen", "Altar de espinas", "Autel des épines", "Алтарь шипов", "가시의 제단", "荆棘祭坛", "Shrine of the Beast", "Schrein des Tieres", "Santuario de la bestia", "Sanctuaire de la Bête", "Altar da Fera", "Святилище зверя", "야수의 제단", "野兽神龛", "Shrine of the Moon", "Schrein des Mondes", "Santuario de la luna", "Sanctuaire de la Lune", "Святилище луны", "달의 제단", "月亮神龛", "Dark Keeper Nameplate", "Dunkelbewahrer-Namensschild", "Placa de Guarda oscuro", "Nom du Gardien noir", "Placa de Identificação do Guardião Sombrio", "Табличка с именем темного хранителя", "암흑의 문지기 명판", "黑暗守护者的标示牌", "Admiral Barean Westwind", "Almirante Barean Viento Oeste", "Amiral Barean Westwind", "Almirante Barean Zefirália", "Адмирал Бареан Вествинд", "제독 바렌 웨스트윈드", "海军上将巴利·韦斯温", "Arellas Fireleaf", "Arellas Hojafuego", "Arellas Firafolha", "Ареллас Огненный Лист", "아렐라스 파이어리프", "阿雷拉斯·火叶", "Dorgar Stoenbrow", "Dorgar Stonebrow", "Dorgar Petrocejas", "Dorgar Hefastão", "Доргар Камнелоб", "도르가르 스톤브로", "多加尔·石眉", "Fellari Swiftarrow", "Fellari Flechaveloz", "Fellari Velosseta", "Феллари Быстрая Стрела", "펠라리 스위프트애로우", "菲尔拉蕾·迅箭", "Ferren Marcus", "Fernando Marco", "Феррен Маркус", "페렌 마커스", "费伦·玛库斯", "Harthal Truesight", "Harthal Vistarreal", "Hereno Justo", "Хартал Проницательный", "하르탈 트루사이트", "Holia Sunshield", "Holia Escusol", "Holia Solbroquel", "Холия Солнечный Щит", "홀리아 선쉴드", "Invar One-Arm", "Invar Unibrazo", "Invar le Manchot", "Invar Sem-braço", "Инвар Однорукий", "외팔이 이바르", "Orman of Stromgarde", "Orman von Stromgarde", "Orman de Stromgarde", "Орман из Стромгарда", "스트롬가드의 오르만", "激流堡的奥玛尔", "Valea Twinblades", "Valea Filosgemelos", "Valea Bilâmina", "Валея Два Клинка", "발리아 트윈블레이즈", "Yana Bloodspear", "Yana Lanza de Sangre", "Yana Lanssang", "Яна Кровавое Копье", "야나 블러드스피어", "亚娜·血矛" },
    Tablet = { "Fossilized Egg", "Fossiles Ei", "Huevo fosilizado", "Oeuf fossilisé", "Ovo Fossilizado", "Окаменелое яйцо", "화석 알", "化石蛋", "Geru Strider", "Geruschreiter", "Zancudo Geru", "Trotteur Geru", "Pinote Geru", "Геру-Странник", "게루 타조", "格鲁陆行鸟", "Saurial Egg", "Saurier-Ei", "Huevo saurio", "Oeuf de saurien", "Ovo de Sáurio", "Яйцо завра", "사우리알의 알", "蜥蜴卵", "Pteradon Skeleton", "Pteradonskelett", "Esqueleto de pteradon", "Squelette de ptéradon", "Esqueleto de Pterodonte", "Скелет птерадона", "프테라돈 뼈", "翼手龙骨架", "Highborne Astrolabe", "Astrolabium der Hochgeborenen", "Astrolabio altonato", "Astrolabe des bien-nés", "Astrolábio do Altaneiro", "Астролябия высокорожденных", "귀족 아스트롤라베", "上层精灵星盘", "Horde Catapult", "Katapult der Horde", "Catapulta de la Horda", "Catapulte de la Horde", "Catapulta da Horda", "Катапульта Орды", "호드 투석기", "部落投石车", "Roc Talon", "Kralle eines Roc", "Garrapiedra", "Serre de Roc", "Garra de Pássaro-roca", "Коготь руха", "로크 갈퀴발톱", "大鹏爪", "Toothgnasher's Skeleton", "Knirschzahns Skelett", "Esqueleto de rechinador", "Squelette de Grincedents", "Esqueleto do Rangedente", "Скелет Щелкозуба", "이갈이산양의 골격", "The Skull of Tyrannistrasz", "Der Schädel des Tyrannistrasz", "El cráneo de Tyrannistrasz", "Le crâne de Tyrannistrasz", "O Crânio de Tyrannistrasz", "Череп Тираннистраса", "티란니스트라즈의 뼈", "塔兰尼斯塔兹的颅骨", "Uldaman Relics", "Uldamanrelikte", "Reliquias de Uldaman", "Reliques d'Uldaman", "Relíquias de Uldaman", "Ульдаманские святыни", "울다만 유적", "奥达曼遗物", "Uldaman Reliefs", "Bruchstücke aus Uldaman", "Relieves de Uldaman", "Relevés d'Uldaman", "Ульдаманские барельефы", "奥达曼浮雕" },
    Troll = { "Altar of Zanza", "Altar von Zanza", "Altar de Zanza", "Autel de Zanza", "Алтарь Занзы", "잔자의 제단", "赞扎祭坛", "The Twin Empires", "Die Zwillingsimperien", "Los Imperios Gemelos", "Les empires jumeaux", "Os Impérios Gêmeos", "Империи-близнецы", "쌍둥이 제국", "两个帝国", "Empires' Fall", "Der Falls des Imperiums", "La caída de los imperios", "La chute de l'empire", "A Queda do Império", "Падение Империи", "제국의 몰락", "帝国的陷落", "Wrath of Soulflayer", "Der Zorn des Seelenschinders", "La ira del Cazador de Almas", "La colère du fléau des âmes", "A Ira do Esfolador de Almas", "Гнев Свежевателя Душ", "영혼약탈자의 격노", "噬灵者的愤怒" },
}) do
    for _, n in ipairs(names) do DWE.STONE_TEXTS[n] = plate end
end
-- Le texte ouvert est-il une tablette trolle ? (sans Spoken : d'apres son titre)
-- Sans Spoken Readables, le texte de Khadgar se reconnait a son titre (toutes langues).
DWE.KHADGAR_NAMES = { "Khadgar", "Кадгар", "카드가", "卡德加" }
-- Appele des centaines de fois par seconde (masquage, style du livre) : Spoken refait a chaque
-- fois le calcul de la page affichee (texte normalise + somme de controle), tres long sur une
-- grande page (« Translated Tale of I'lalai » : le jeu ramait). Le resultat ne change qu'avec
-- le texte ouvert : on le garde pour un meme titre, une meme page et une meme carte.
DWE.trollCache = {}
function DWE.OpenTrollTablet()
    local title = ItemTextGetItem and ItemTextGetItem()
    local page = ItemTextGetPage and ItemTextGetPage()
    local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local sec = rawget(_G, "issecretvalue")
    if type(title) == "string" and not (sec and (sec(title) or sec(page))) then
        local key = title .. "\0" .. tostring(page) .. "\0" .. tostring(map) .. "\0" .. tostring(DWE.textSerial)
        local c = DWE.trollCache
        if c.key == key then return c.plate, c.kind end
        local plate, kind = DWE.OpenTrollTabletRaw()
        c.key, c.plate, c.kind = key, plate, kind
        return plate, kind
    end
    return DWE.OpenTrollTabletRaw()
end
-- Texte ouvert change (nouveau livre, page suivante) : on recalcule.
function DWE.ForgetOpenText() DWE.textSerial = (DWE.textSerial or 0) + 1 end
function DWE.OpenTrollTabletRaw()
    local sr = rawget(_G, "SpokenReadables")
    if type(sr) == "table" and sr.PageOnScreen then
        local ok, id = pcall(sr.PageOnScreen, sr)
        if ok and id then
            local plate, kind = DWE.TrollTablet(id)
            if plate then return plate, kind end
            -- Spoken sait que c'est un vrai livre (le meme titre existe en livre et en tablette,
            -- ex. "Empires' Fall" dans une bibliotheque) : on ne devine pas d'apres le titre.
            if kind == "book" then return false end
        end
    end
    -- Storytale seul : d'apres le titre et l'endroit.
    local title = ItemTextGetItem and ItemTextGetItem()
    if type(title) ~= "string" or (issecretvalue and issecretvalue(title)) then return false end
    if title:find("Troll Legend", 1, true) then return "Troll" end
    for _, w in ipairs(DWE.KHADGAR_NAMES) do
        if title:find(w, 1, true) then
            local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
            local where = map and DWE.ROUND_PLAQUES[289][map]
            if where then return where, "plaque" end
            break
        end
    end
    local plate = DWE.STONE_TEXTS[(title:gsub("^%s+", ""):gsub("%s+$", ""))]
    -- Steles trolles : seulement la ou elles se trouvent (Strangleronce, Zul'Gurub) ; ailleurs
    -- le meme titre est un livre de bibliotheque.
    if plate == "Troll" and not DWE.InTrollLands() then plate = nil end
    if plate then return plate, plate == "Stone" and "plaque" or nil end
    return false
end
function DWE.OpenTitle()
    local ok, t = pcall(ItemTextGetItem or function() end)
    if not ok or type(t) ~= "string" or (issecretvalue and issecretvalue(t)) then return nil end
    return t
end
function DWE.RawPlate()
    if DWE.testPlate and (DWE.bookMode or (ItemTextGetMaterial and ItemTextGetMaterial())) then
        DWE.lastPlate = DWE.testPlate
        return DWE.testPlate
    end
    if not ItemTextGetMaterial then return nil end
    -- Le jeu ne donne la matiere que tant que son texte est ouvert : on la garde pour la suite
    -- du meme texte (le lecteur Spoken se redessine apres).
    local ok, m = pcall(ItemTextGetMaterial)
    -- Tablette trolle : le jeu la donne pour du parchemin (ou rien) ; on lui met sa stele.
    if ok and DWE.bookMode and not (type(m) == "string" and DWE.PLATES[m]) then
        m = DWE.OpenTrollTablet() or m
    end
    if ok and type(m) == "string" and m ~= "" then
        -- Matiere choisie dans les options pour toutes les plaques (sinon celle du jeu).
        local pick = DialogueWheelE_PlateLook
        if DWE.PLATES[m] and pick and DWE.PLATES[pick] then m = pick end
        DWE.lastPlate = DWE.PLATES[m] and m or nil
        DWE.lastPlateTitle = DWE.OpenTitle()
        return DWE.lastPlate
    end
    -- Seulement pour le meme texte : sinon, apres une stele, tous les livres suivants (dont le
    -- jeu ne donne pas la matiere) gardaient l'allure de la stele.
    if DWE.bookMode and DWE.lastPlate and DWE.lastPlateTitle == DWE.OpenTitle() then return DWE.lastPlate end
    return nil
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

-- "book" (livre ouvert), "note" (page seule) ou nil (pas un livre).
-- Automatique : plusieurs pages = livre, une seule = note.
function DWE.BookLook()
    if not DWE.BookByAddon() then return nil end
    if DWE.PlateMaterial() then return "note" end
    local pref = DialogueWheelE_BookLook or "auto"
    -- (1.5.5) "Cadre du theme" retire : le livre ouvert et la page seule l'ont remplace.
    if pref == "frame" then DialogueWheelE_BookLook, pref = nil, "auto" end
    if pref == "note" or pref == "book" then return pref end
    local bi = DWE.bookInfo
    if bi then DWE.bookLookHold = nil elseif DWE.bookLookHold then return DWE.bookLookHold end
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
    local p = DWE.BookPosGet()
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
    if DWE.RoundNow() and textBox.dweOuter and textBox.dwePadL then
        local okH, uh = pcall(UIParent.GetHeight, UIParent)
        uh = (okH and type(uh) == "number") and uh or 768
        local sc, d = DWE.NoteScale(), DWE.ROUND_DEFAULT
        local o = textBox.dweOuter
        local x = uw * d.cx / sc - (o / 2 - textBox.dwePadL)
        local y = uh * d.cy / sc + (o / 2 - textBox.dwePadT)
        textBox:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
        return
    end
    if textBox.dweBook == "note" then
        -- Notes et plaques : la place choisie par l'auteur (a droite, un peu au-dessus du milieu).
        local ns = DWE.NoteScale()
        textBox:SetPoint("RIGHT", UIParent, "RIGHT", -417 / ns, 102 / ns)
        return
    end
    local sc = DWE.BookScaleWanted()
    -- Le lecteur Spoken d'une autre voix a l'ecran (a droite) : le livre se pousse a sa gauche
    -- pour ne pas le recouvrir.
    local gap = uw * 0.2
    local fr = DWE.SpokenSideFrame and DWE.SpokenSideFrame()
    local l = fr and fr:GetLeft()
    if l then
        l = l * fr:GetEffectiveScale() / UIParent:GetEffectiveScale()
        local artRight = (BOOK_W - BOOK_LEFT - (textBox:GetWidth() or 380)) * sc -- le livre deborde a droite
        local want = uw - l + 24 + math.max(0, artRight)
        -- Seulement un lecteur sur la moitie droite, et sans pousser le livre hors de l'ecran.
        if l > uw * 0.5 and want > gap then gap = math.min(want, uw * 0.45) end
    end
    DWE.bookAvoided = fr and true or false
    textBox:SetPoint("RIGHT", UIParent, "RIGHT", -gap / sc, 63 / sc)
end
DWE.BookPosition = BookPosition
-- Lecteur Spoken visible a cote d'un livre de l'addon (place par defaut seulement).
function DWE.SpokenSideFrame()
    for _, n in ipairs({ "SpokenDialogueUIPlayerFrame", "SpokenMinimalPlayerFrame" }) do
        local f = rawget(_G, n)
        if DWE.PlayerFrameShown and DWE.PlayerFrameShown(f) then return f end
    end
end
-- Appele regulierement : replace le livre quand le lecteur apparait ou s'en va.
function DWE.BookAvoidSpoken()
    if not (DWE.bookMode and DWE.BookByAddon() and textBox:IsShown()) or textBox.dweBook == "note" then return end
    local bp = DWE.BookPosGet()
    if type(bp) == "table" and bp.x then return end
    local now = DWE.SpokenSideFrame() and true or false
    if now ~= (DWE.bookAvoided or false) then BookPosition() end
end

-- Echelle du livre ouvert (poignee du coin). Le coin haut-gauche reste en place.
-- Taille des notes et plaques (poignee), a part de celle des livres ouverts.
-- La stele ronde (Dalaran) a sa propre taille et sa propre place : son disque est plus grand
-- que les autres plaques, et il peut descendre bien plus bas.
-- Par defaut : la taille et la place choisies par l'auteur, en proportions de l'ecran (centre
-- du disque a 78 % de la largeur, 54 % de la hauteur), pour tomber au meme endroit partout.
DWE.ROUND_DEFAULT = { scale = 0.57, cx = 0.7818, cy = 0.5386 }
function DWE.RoundNow() return textBox.dweBook == "note" and textBox.dweRound and true or false end
-- Plus petite taille de la stele ronde : libre, au choix du joueur.
function DWE.RoundMinScale()
    return 0.2
end
function DWE.NoteScale()
    if DWE.RoundNow() then
        local r = tonumber(DialogueWheelE_RoundScale)
        r = (r and r <= 2) and r or DWE.ROUND_DEFAULT.scale
        return math.max(r, DWE.RoundMinScale())
    end
    local v = tonumber(DialogueWheelE_NoteScale)
    return (v and v >= 0.6 and v <= 2) and v or 0.77 -- taille par defaut : 77 %
end
function DWE.BookPosGet()
    if DWE.RoundNow() then
        local r = DialogueWheelE_RoundPos
        if type(r) == "table" and r.x then return r end
        return DWE.ROUND_DEFAULT.pos
    end
    return DialogueWheelE_BookPos
end
function DWE.BookPosSet(v)
    if DWE.RoundNow() then DialogueWheelE_RoundPos = v else DialogueWheelE_BookPos = v end
end
function DWE.BookScaleWanted()
    local v = tonumber(DialogueWheelE_BookScale)
    return (v and v >= 0.5 and v <= 2) and v or 0.75 -- taille par defaut : 75 %
end
-- keepCorner : seulement depuis la poignee (le coin haut-gauche reste sous la souris). Sinon
-- (ouverture, fermeture) on change juste l'echelle : BookPosition remet la position sauvee,
-- qui est dans l'echelle du livre.
-- Boutons sous et sur la stele ronde : jamais sous 80 %, pour rester lisibles quand on la
-- reduit beaucoup.
function DWE.BarScale(sc)
    return DWE.RoundNow() and math.max(sc, 0.8) or sc
end
function DWE.SetBookScale(sc, keepCorner)
    local cur = textBox:GetScale() or 1
    -- Le triangle de redimensionnement garde la meme taille a l'ecran, quelle que soit l'echelle.
    if textBox.dweGrip and sc > 0 then textBox.dweGrip:SetScale(1 / sc) end
    if DWE.bookBar then DWE.bookBar:SetScale(DWE.BarScale(sc)) end
    if DWE.ribbonBar then DWE.ribbonBar:SetScale(DWE.BarScale(sc) / sc) end
    if math.abs(cur - sc) < 0.001 then return end
    local okL, l = pcall(textBox.GetLeft, textBox)
    local okT, t = pcall(textBox.GetTop, textBox)
    textBox:SetScale(sc)
    if keepCorner and okL and okT and type(l) == "number" and type(t) == "number" and DWE.bookMode then
        local x, y = l * cur / sc, t * cur / sc
        -- Stele ronde : c'est le coin haut-gauche du disque qui reste en place (le coin oppose
        -- suit alors exactement la souris).
        if DWE.RoundNow() and textBox.dwePadL and textBox.dwePadT then
            x = (l - textBox.dwePadL) * cur / sc + textBox.dwePadL
            y = (t + textBox.dwePadT) * cur / sc - textBox.dwePadT
        end
        textBox:ClearAllPoints()
        textBox:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
        DWE.BookPosSet({ point = "TOPLEFT", relPoint = "BOTTOMLEFT", x = x, y = y })
    end
    -- La barre du bas suit le bas du disque (sans tout reconstruire pendant le glisser).
    local bb = DWE.bookBar
    if bb and DWE.RoundNow() and bb:IsShown() then
        bb:ClearAllPoints()
        bb:SetPoint("TOP", textBox, "BOTTOM", 0, -((textBox.dwePadB or 0) + 6) * sc / (bb:GetScale() or 1))
    end
end

-- Journal du livre (/storytale livrelog) : une ligne, avec d'ou vient l'appel.
function DWE.LookLog(what)
    DWE.lookLog = DWE.lookLog or {}
    if #DWE.lookLog >= 300 then return end
    DWE.lookLog[#DWE.lookLog + 1] = string.format("%.2f %s | echelle=%.2f | %s", GetTime and GetTime() or 0, what,
        textBox:GetScale() or 0, ((debugstack and debugstack(3, 4, 0) or ""):gsub("Interface[/\\]AddOns[/\\]", ""):gsub("\n", " < ")))
end
local function RestoreTextAnchors()
    if textBox.dweBook then DWE.LookLog("livre -> simple cadre (RestoreTextAnchors)") end
    textHeader:ClearAllPoints()
    textHeader:SetPoint("TOPLEFT", textBox, "TOPLEFT", 0, -2)
    textHeader:SetPoint("TOPRIGHT", textBox, "TOPRIGHT", 0, -2)
    textBody:ClearAllPoints()
    textBody:SetPoint("TOPLEFT", textHeader, "BOTTOMLEFT", 0, -8)
    textBody:SetPoint("TOPRIGHT", textHeader, "BOTTOMRIGHT", 0, -8)
    bookL:Hide()
    bookR:Hide()
    noteBg:Hide()
    DWE.memorialPetals:Hide()
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
DWE.NOTE = NOTE
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
-- Plaque ronde : reflet clair decale en haut a gauche, sous le texte (lettres taillees en biseau).
NOTE.noteHi = NOTE.noteChild:CreateFontString(nil, "ARTWORK")
NOTE.noteHi:SetFontObject(questFontObj)
NOTE.noteHi:SetSpacing(5)
NOTE.noteHi:SetPoint("TOPLEFT", NOTE.noteChild, "TOPLEFT", -1, 1)
NOTE.noteHi:SetShadowOffset(0, 0)
NOTE.noteHi:Hide()
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
    NOTE.manual, NOTE.manualAt = true, GetTime() -- le joueur fait defiler : le suivi fait une pause
    return true
end
-- Defilement automatique (lecture par Spoken) : garde le mot lu a l'ecran. `upto` = le texte
-- de la note jusqu'au mot lu ; on mesure sa hauteur avec un texte cache de meme largeur.
NOTE.measure = NOTE.noteChild:CreateFontString(nil, "OVERLAY")
NOTE.measure:SetSpacing(5)
NOTE.measure:SetJustifyH("LEFT")
NOTE.measure:SetAlpha(0)
NOTE.measure:Hide()
function DWE.NoteFollow(upto)
    if not noteScroll:IsShown() or DialogueWheelE_BookAutoScroll == false then return end
    local range, view = NOTE.Range()
    if range <= 0 then return end
    local m, src = NOTE.measure, NOTE.noteText
    local font, size, flags = src:GetFont()
    if not font or not pcall(m.SetFont, m, font, size, flags or "") then return end
    m:SetWidth(src:GetWidth() or NOTE_W)
    m:SetText(upto)
    local okH, h = pcall(m.GetStringHeight, m)
    if not okH or type(h) ~= "number" then return end
    local cur = noteScroll:GetVerticalScroll() or 0
    -- Le joueur a fait defiler : pause de 5 s apres son dernier geste (il peut remonter relire
    -- un nom). Ensuite, on le laisse tant que le mot lu est visible ; quand la voix arrive en bas
    -- du cadre (ou n'est plus a l'ecran), le suivi reprend.
    if NOTE.manual then
        if GetTime() - (NOTE.manualAt or 0) < 5 then return end
        if h < cur or h > cur + view * 0.92 then NOTE.manual = nil else return end
    end
    -- Le mot lu reste dans le haut du cadre (environ au tiers), sans saut : on glisse vers lui.
    if h > cur + view * 0.15 and h < cur + view * 0.75 then return end
    local target = math.max(0, math.min(range, h - view * 0.35))
    local v = cur + (target - cur) * 0.25
    if math.abs(target - v) < 1 then v = target end
    noteScroll:SetVerticalScroll(v)
    NOTE.PlaceThumb()
end
function DWE.NoteFollowReset() NOTE.manual, NOTE.manualAt = nil, nil end
noteScroll:EnableMouseWheel(true)
noteScroll:SetScript("OnMouseWheel", function(_, delta) DWE.NoteScrollBy(delta) end)
-- Clic gauche maintenu et glisser : le texte suit la souris (comme les longues listes de choix).
noteScroll:EnableMouse(true)
noteScroll:SetScript("OnMouseDown", function(self, button)
    if button ~= "LeftButton" then return end
    -- Rien a faire defiler (stele ronde, note courte) : on deplace la fenetre, comme ailleurs.
    if DWE.RoundNow() or (NOTE.Range() or 0) <= 0 then
        self.moveWin = true
        DWE.DragStart("text")
        return
    end
    local _, y = GetCursorPosition()
    self.drag = { y = y / UIParent:GetEffectiveScale(), v = self:GetVerticalScroll() or 0 }
    NOTE.manual, NOTE.manualAt = true, GetTime()
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
    if self.moveWin then self.moveWin = nil; DWE.DragStop("text") end
    self.drag = nil
    self:SetScript("OnUpdate", nil)
end)
noteScroll:SetScript("OnHide", function(self)
    self.drag = nil
    self:SetScript("OnUpdate", nil)
end)
-- Titre de page de livre : "Titre (2/4)" -> "Titre", "2 / 4" ; "Titre (2/?)" (le jeu ne dit
-- pas encore combien de pages il reste) -> "Titre", "2".
function DWE.SplitPageTitle(title)
    local plain, p, n = (title or ""):match("^(.-)%s*%((%d+)/([%d%?]+)%)$")
    if not plain then return nil, nil end
    return plain, n == "?" and p or (p .. " / " .. n)
end

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
    local early = DWE.PLATES[DWE.PlateMaterial() or ""]
    textBox.dweRound = early and early.round or nil
    DWE.SetBookScale(DWE.NoteScale())
    textBox:SetWidth(NOTE_W)
    MorpheusTitle()
    local plate = DWE.PLATES[DWE.PlateMaterial() or ""]
    -- Plaque : le symbole grave (bouton des reglages) occupe le haut, centre, au-dessus du titre,
    -- comme l'ornement d'un monument.
    local round = plate and plate.round
    -- Stele ronde reduite : le texte ne descend jamais sous une taille lisible a l'ecran (13).
    -- Toute la mise en page grossit avec lui, donc le disque garde sa forme ; en dessous, c'est
    -- le plus petit disque qui contient le texte lisible.
    local roundK = 1 -- (taille libre : la stele se reduit d'un bloc, texte compris)
    -- Stele tres reduite (texte sous 12 a l'ecran) : police d'interface nette au lieu de Skurri,
    -- texte un peu plus clair.
    local roundSmall = round and ((tonumber(DialogueWheelE_FontSize) or 13) + 9) * DWE.NoteScale() < 12
    local glyphSpace = (plate and not round) and 40 or 0
    textHeader:ClearAllPoints()
    textHeader:SetPoint("TOPLEFT", textBox, "TOPLEFT", 0, -2 - glyphSpace)
    textHeader:SetPoint("TOPRIGHT", textBox, "TOPRIGHT", 0, -2 - glyphSpace)
    textHeader:SetJustifyH("CENTER")
    local bodyC = plate and plate.body or { 0.17, 0.10, 0.04 }
    local hdrC = plate and plate.hdr or { 0.40, 0.16, 0.04 } -- meme rouge-brun que le titre du livre
    local ruleC = plate and plate.rule or { 0.42, 0.26, 0.10, 0.55 }
    textHeader:SetTextColor(hdrC[1], hdrC[2], hdrC[3])
    if roundSmall then
        NOTE.noteText:SetTextColor(math.min(1, bodyC[1] * 1.18), math.min(1, bodyC[2] * 1.18), math.min(1, bodyC[3] * 1.18))
    else
        NOTE.noteText:SetTextColor(bodyC[1], bodyC[2], bodyC[3])
    end
    -- Texte grave : un liseré clair en bas a droite des lettres sombres.
    if round and not DWE.IS_CJK then
        local hp = (DWE.IS_CYRILLIC and "Fonts\\MORPHEUS_CYR.TTF") or "Fonts\\MORPHEUS.TTF"
        SafeSetFont(textHeader, hp, math.floor(((tonumber(DialogueWheelE_FontSize) or 13) + 17) * roundK + 0.5))
    end
    local eg = plate and plate.engrave
    for _, fs in ipairs({ textHeader, NOTE.noteText }) do
        if eg then
            fs:SetShadowColor(eg[1], eg[2], eg[3], eg[4])
            -- Lettres claires (Dalaran) : l'ombre du creux tombe sur leur bord haut-gauche.
            local eo = plate.engraveOffset
            local px = (round and DWE.NoteScale() < 1) and (1 / DWE.NoteScale()) or 1
            fs:SetShadowOffset((eo and eo[1] or 1) * px, (eo and eo[2] or -1) * px)
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
            -- Frise gravee (stele trolle) : bords repetes, pas etires, pour garder les glyphes nets.
            if noteBg.SetTextureSliceMode then pcall(noteBg.SetTextureSliceMode, noteBg, (plate and plate.tile) and 1 or 0) end
        end
    end
    -- Marges autour du texte : celles de la page, ou le cadre de la plaque plus un peu d'air.
    local padL, padT, padR, padB = NOTE_PAD_X, NOTE_PAD_Y, NOTE_PAD_X, NOTE_PAD_Y
    if plate then
        -- Texture en haute definition : son cadre fait la moitie de sa decoupe a l'ecran.
        local sl = plate.inner or plate.slice
        padL, padT, padR, padB = sl[1] + 22, sl[2] + 18, sl[3] + 22, sl[4] + 18
    end
    textBox.dwePadB = padB
    local title = DWE.rawHeader or textHeader:GetText() or ""
    local plain, page = DWE.SplitPageTitle(title)
    if plain then textHeader:SetText(plain) end
    noteRule:ClearAllPoints()
    noteRule:SetHeight(1)
    noteRule:SetPoint("TOPLEFT", textHeader, "BOTTOMLEFT", 0, -10)
    noteRule:SetPoint("TOPRIGHT", textHeader, "BOTTOMRIGHT", 0, -10)
    -- Trait sous le titre : seulement sur le papier. Sur la pierre ou le metal grave (plaques,
    -- steles, tablettes), il faisait "imprime par-dessus".
    noteRule:SetShown(not plate)
    notePage:Hide()
    bookPageNum:Hide() -- (numero du livre ouvert : la note montre toutes les pages)
    -- Tout le texte dans une zone qui defile (pas de pages).
    textBody:Hide()
    -- Plaque/page reduite : la police grossit pour rester lisible (comme les livres).
    local font, size = textBody:GetFont()
    local nsc = DWE.NoteScale()
    local nbase = tonumber(DialogueWheelE_FontSize) or size or 13
    -- (Pas pour la stele ronde : elle se reduit d'un bloc, sinon le disque grandit autour d'un
    -- texte devenu enorme.)
    local nsz = (nsc < 0.98 and not round) and math.floor(nbase / (nsc ^ 0.9) + 0.5) or nbase
    -- Plaque ronde (Dalaran) : la police anguleuse du jeu (Skurri), proche des runes gravees.
    if round and not DWE.IS_CJK then
        font, nsz = (DWE.IS_CYRILLIC and "Fonts\\SKURRI_CYR.TTF") or "Fonts\\SKURRI.TTF", math.floor((nsz + 9) * roundK + 0.5)
        if roundSmall then font = "Fonts\\FRIZQT__.TTF"; nsz = nsz - 3 end
    end
    if font then pcall(NOTE.noteText.SetFont, NOTE.noteText, font, nsz, "") end
    local hFont, hSize = textHeader:GetFont()
    if nsc < 0.98 and hFont and hSize and not DWE.IS_CJK and not round then
        SafeSetFont(textHeader, hFont, math.floor(hSize / (nsc ^ 0.6) + 0.5))
    end
    local body = DWE.bookRawBody or ""
    -- Texte centre par le jeu (epitaphe en HTML align="center"), ou plaque ronde : centre ici.
    NOTE.noteText:SetJustifyH((DWE.bookCentered or round) and "CENTER" or "LEFT")
    if NOTE.noteText.dweLast ~= body then
        NOTE.noteText.dweLast = body
        NOTE.noteText:SetText(body)
        noteScroll:SetVerticalScroll(0)
    end
    local hi = NOTE.noteHi
    if round and plate.bevel then
        local bv = plate.bevel
        if font then pcall(hi.SetFont, hi, font, nsz, "") end
        hi:SetJustifyH("CENTER")
        hi:SetTextColor(bv[1], bv[2], bv[3], bv[4])
        hi:SetText(body)
        hi:Show()
    else
        hi:Hide()
    end
    -- Disque : la largeur du texte est choisie pour que le bloc soit a peu pres carre (il tient
    -- dans le cercle) ; le disque grandit avec le texte.
    local noteW = NOTE_W
    if round then
        for w = math.floor(220 * roundK), math.floor(520 * roundK), math.floor(20 * roundK) do
            noteW = w
            NOTE.noteText:SetWidth(w)
            NOTE.noteHi:SetWidth(w)
            textBox:SetWidth(w)
            local hh = TextHeight(textHeader, 22) + 24 + TextHeight(NOTE.noteText, 20)
            if hh <= w * 0.9 then break end
        end
    else
        NOTE.noteText:SetWidth(NOTE_W)
    end
    NOTE.noteChild:SetWidth(noteW)
    local th = TextHeight(NOTE.noteText, 20)
    NOTE.noteChild:SetHeight(th)
    local view = round and th or math.min(th, NOTE_MAX_H)
    noteScroll:ClearAllPoints()
    noteScroll:SetPoint("TOPLEFT", noteRule, "BOTTOMLEFT", 0, -14)
    noteScroll:SetSize(noteW, math.max(20, view))
    noteScroll:Show()
    NOTE.PlaceThumb()
    local h = TextHeight(textHeader, 22) + 24 + view + glyphSpace
    textBox:SetHeight(round and h or math.max(160, h))
    if round then
        -- Le symbole grave occupe le haut du disque (jusqu'a 28 %) : le texte commence juste
        -- dessous, et le disque grandit avec le texte.
        -- (Les runes gravees en bas, la "signature", commencent a 73 % : le texte s'arrete avant.)
        local outer = math.max(noteW / 0.52, h / 0.42)
        local side = (outer - noteW) / 2
        local top = outer * 0.295
        padL, padR, padT, padB = side, side, top, outer - h - top
        textBox.dwePadB = padB
        textBox.dweOuter = outer -- taille du disque (poignee de redimensionnement)
        textBox.dwePadL, textBox.dwePadT = padL, padT
    end
    textBox.dweGripAnchor, textBox.dweGripX, textBox.dweGripY = noteBg, 0, 0
    textBox.dweNoGrip = nil
    noteBg:ClearAllPoints()
    noteBg:SetPoint("TOPLEFT", textBox, "TOPLEFT", -padL, padT)
    noteBg:SetPoint("BOTTOMRIGHT", textBox, "BOTTOMRIGHT", padR, -padB)
    noteBg:Show()
    DWE.NoteRepFrame(plate, noteW + padL + padR, (textBox:GetHeight() or 160) + padT + padB)
    local pe = DWE.memorialPetals
    if DWE.MemorialOpen and DWE.MemorialOpen() then
        local w = ((textBox:GetWidth() or 300) + padL + padR) * 0.41
        pe:SetSize(w, w * 55 / 320)
        pe:ClearAllPoints()
        pe:SetPoint("BOTTOMRIGHT", noteBg, "BOTTOMRIGHT", -40 / 560 * w / 0.41, 6)
        pe:Show()
    else
        pe:Hide()
    end
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
    local hAll = H(left)
    if hAll <= maxH then return left end
    -- Point de depart estime d'apres la hauteur du tout, puis on encadre par pas qui doublent :
    -- bien moins de mesures sur une tres longue page (chaque mesure remet tout le texte en page).
    local guess = math.max(1, math.min(left - 1, math.floor(left * maxH / math.max(hAll, 1))))
    local lo, hi
    if H(guess) <= maxH then
        lo, hi = guess, nil
        local step = math.max(1, math.floor(guess / 16))
        while not hi do
            local t = lo + step
            if t >= left then hi = left
            elseif H(t) <= maxH then lo, step = t, step * 2
            else hi = t end
        end
    else
        hi, lo = guess, nil
        local step = math.max(1, math.floor(guess / 16))
        while not lo do
            local t = hi - step
            if t <= 0 then lo = 0
            elseif H(t) <= maxH then lo = t
            else hi, step = t, step * 2 end
        end
    end
    while hi - lo > 1 do
        local mid = math.floor((lo + hi) / 2)
        if H(mid) <= maxH then lo = mid else hi = mid end
    end
    return math.max(1, lo)
end
function DWE.BookSubPaginate(raw, fsz, header)
    local st = DWE.bookSub
    local key = raw .. "\0" .. fsz .. "\0" .. header .. "\0" .. tostring((textBody:GetFont())) .. "\0" .. tostring(BOOK_COL)
    if st.key == key then return st end
    local samePage = st.raw == raw
    st.key, st.raw = key, raw
    local perf = DWE.perf
    local t0 = perf and perf.on and debugprofilestop and debugprofilestop()
    -- Pages deja decoupees (aller-retour entre pages d'un long livre) : pas de nouveau calcul.
    st.cache = st.cache or {}
    local cached = st.cache[key]
    local maxH = BOOK_TEXT_H + 24
    if cached then
        st.spreads = cached
    else
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
    st.cacheN = (st.cacheN or 0) + 1
    if st.cacheN > 12 then st.cache, st.cacheN = {}, 1 end
    st.cache[key] = st.spreads
    end
    if t0 then
        local dt = debugprofilestop() - t0
        perf.t.bookPaginate = (perf.t.bookPaginate or 0) + dt
        perf.n.bookPaginate = (perf.n.bookPaginate or 0) + 1
        perf.mx = perf.mx or {}
        if dt > (perf.mx.bookPaginate or 0) then perf.mx.bookPaginate = dt end
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

-- Page tournee (livre ouvert) : le bruit de page du jeu et une page qui se replie vers la
-- reliure puis se deplie de l'autre cote (WoW ne courbe pas une page en 3D : on l'ecrase en
-- largeur, avec une ombre qui fonce en approchant de la reliure).
DWE.bookFlip = CreateFrame("Frame", nil, textBox)
DWE.bookFlip:SetAllPoints(textBox)
DWE.bookFlip:Hide()
do
    local F = DWE.bookFlip
    local S = BOOK_W / 1024 -- echelle de l'image du livre
    -- Papier des pages dans BookSpread.png (pixels) : gauche, droite, haut, bas.
    local LEFT_PAGE = { 120, 512, 40, 490 }
    local RIGHT_PAGE = { 516, 930, 40, 490 }
    local DUR = 0.36
    local tex = F:CreateTexture(nil, "OVERLAY", nil, 7)
    tex:SetTexture(ADDON_PATH .. "BookSpread.png")
    local function Page(p)
        tex:SetTexCoord(p[1] / 1024, p[2] / 1024, p[3] / 1024, p[4] / 1024)
        return (p[2] - p[1]) * S, (p[4] - p[3]) * S
    end
    local spineX = 514 * S
    F:SetScript("OnUpdate", function(self, elapsed)
        self.t = (self.t or 0) + elapsed
        local k = math.min(1, self.t / DUR)
        local first = k < 0.5
        -- Avant : la page de droite se replie, puis se deplie a gauche. Arriere : l'inverse.
        local fromRight = (self.dir > 0) == first
        local w, h = Page(fromRight and RIGHT_PAGE or LEFT_PAGE)
        local f = first and (1 - k * 2) or ((k - 0.5) * 2)
        f = math.max(0.001, f)
        -- Un peu d'acceleration au debut, de freinage a la fin : plus naturel qu'un mouvement egal.
        f = first and (f * f) or (1 - (1 - f) * (1 - f))
        tex:ClearAllPoints()
        local top = -(LEFT_PAGE[3] * S)
        if fromRight then
            tex:SetPoint("TOPLEFT", DWE.bookSpreadTex, "TOPLEFT", spineX, top)
        else
            tex:SetPoint("TOPRIGHT", DWE.bookSpreadTex, "TOPLEFT", spineX, top)
        end
        tex:SetSize(math.max(0.5, w * f), h)
        local shade = 0.62 + 0.38 * f
        tex:SetVertexColor(shade, shade * 0.97, shade * 0.93)
        if k >= 1 then self:Hide() end
    end)
    function DWE.BookTurnFX(dir)
        if DialogueWheelE_BookTurnFX == false then return end
        if PlaySound then
            local id = SOUNDKIT and (SOUNDKIT.IG_ABILITY_PAGE_TURN or SOUNDKIT.IG_SPELLBOOK_PAGE_TURN) or 836
            pcall(PlaySound, id)
        end
        if not DWE.bookSpreadTex then return end
        -- Le marque-page disparait pendant qu'on feuillette, et revient en fondu une fois les
        -- pages immobiles (un peu apres la derniere page tournee).
        local rib = DWE.ribbon
        if rib and rib.tex then
            rib.tex:SetAlpha(0)
            if rib.glow then rib.glow:SetAlpha(0) end
            local fade = DWE.ribbonFade or CreateFrame("Frame", nil, textBox)
            DWE.ribbonFade = fade
            fade.t = 0
            fade:SetScript("OnUpdate", function(self, elapsed)
                self.t = self.t + elapsed
                local a = (self.t - DUR - 0.35) / 0.35
                if a <= 0 then return end
                if a >= 1 then a = 1; self:SetScript("OnUpdate", nil) end
                rib.tex:SetAlpha(a)
            end)
        end
        F.dir, F.t = dir, 0
        -- Au-dessus du marque-page (+6) : la page qui tourne passe par-dessus le ruban, comme dans
        -- un vrai livre, au lieu que le ruban flotte devant elle.
        F:SetFrameLevel((textBox:GetFrameLevel() or 1) + 8)
        F:Show()
    end
end

local function LayoutBook()
    ClearThemeParts(textParts)
    noteBg:Hide()
    DWE.memorialPetals:Hide()
    noteRule:Hide()
    notePage:Hide()
    textBox.dweBook = true
    DWE.SetBookScale(DWE.BookScaleWanted())
    textBox:SetWidth(2 * BOOK_COL + BOOK_GUTTER)
    -- "(1/8)" quitte le titre et va en bas de la page de droite.
    local title = DWE.rawHeader or textHeader:GetText() or ""
    local plain, page = DWE.SplitPageTitle(title)
    -- Toujours le titre complet ici : une sous-page b, c... l'efface, il doit revenir sur a.
    textHeader:SetText(plain or title)
    bookPageNum:SetText(page or "")
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
    local sub = DWE.BookSubPaginate(raw, fsz, plain or title)
    local spread = sub.spreads[sub.index] or { "", "" }
    if sub.index > 1 then textHeader:SetText("") end
    textBody:SetText(spread[1])
    textBody2:SetText(spread[2])
    -- Numero : "1 / 8", et la sous-page en lettre ("1 / 8 · b") quand la page est decoupee.
    if #sub.spreads > 1 then
        local letter = string.char(96 + math.min(26, sub.index))
        bookPageNum:SetText((page and (page .. "  · ") or "") .. letter)
        bookPageNum:Show()
    end
    textBox:SetHeight(BOOK_TEXT_H)
    bookL:ClearAllPoints()
    bookL:SetPoint("TOPLEFT", textBox, "TOPLEFT", -BOOK_LEFT, BOOK_TOP)
    bookL:Show()
    -- Page tournee depuis le dernier affichage du meme livre : bruit + animation.
    do
        local pnum = tonumber(page and page:match("^(%d+)") or "1") or 1
        local order = pnum * 100 + (sub.index or 1)
        local id = (DWE.rawHeader or ""):gsub("%s*%(%d+/[%d%?]+%)$", "")
        if DWE.bookTurnLast and DWE.bookTurnLast.id == id and DWE.bookTurnLast.order ~= order then
            DWE.BookTurnFX(order > DWE.bookTurnLast.order and 1 or -1)
        end
        DWE.bookTurnLast = { id = id, order = order }
    end
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
-- Molette sur le livre ouvert : tourne les pages (vers soi = page suivante), comme on feuillette.
-- Sur la barre de boutons, elle choisit toujours un bouton.
function DWE.BookWheelTurn(delta)
    local now = GetTime and GetTime() or 0
    if now - (DWE.bookWheelAt or 0) < 0.25 then return true end -- une page par cran, pas une rafale
    local want = delta < 0 and L.NEXT_PAGE or L.PREV_PAGE
    for _, opt in ipairs(DWE.currentOptions or {}) do
        if opt.rawLabel == want and opt.action and not opt.disabled then
            DWE.bookWheelAt = now
            opt.action()
            return true
        end
    end
    return true
end
textBox:SetScript("OnMouseWheel", function(self, delta)
    if DWE.bookMode and textBox.dweBook == true then
        if IsMouseButtonDown and (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")) then return end
        return DWE.BookWheelTurn(delta)
    end
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

-- Marque-page en tissu, en haut a droite du livre ou de la note : il deroule au-dessus du livre
-- une rangee de reglages de lecture (voix, suivi de la voix, surbrillance, pages qui tournent),
-- chacun une icone et son nom, qui apparaissent l'un apres l'autre. Rien ne couvre le livre.
do
    local rib = CreateFrame("Button", nil, textBox)
    rib:SetSize(44, 70)
    rib:Hide()
    -- Halo dore au survol (fondu), pour montrer qu'on peut cliquer.
    rib.glow = rib:CreateTexture(nil, "BACKGROUND")
    rib.glow:SetTexture(ADDON_PATH .. "RibbonGlow.png")
    rib.glow:SetBlendMode("ADD")
    rib.glow:SetPoint("CENTER", rib, "CENTER", 0, 0)
    rib.glow:SetAlpha(0)
    rib.tex = rib:CreateTexture(nil, "ARTWORK")
    rib.tex:SetAllPoints()
    rib.tex:SetTexture(ADDON_PATH .. "Ribbon.png")
    DWE.ribbon = rib

    -- La rangee : sans fond, posee au-dessus du livre, comme la barre du bas.
    local bar = CreateFrame("Frame", nil, textBox)
    bar:SetSize(10, 28)
    bar:Hide()
    bar.items = {}
    DWE.ribbonBar = bar

    local function Items()
        local focus = DWE.SpokenFocus
        local spoken = focus and focus.Available()
        local muted = focus and focus.bookMuted
        local list = {}
        if spoken then
            list[#list + 1] = { label = L.MENU_VOICE, on = not muted,
                icon = muted and "Interface\\Common\\VoiceChat-Muted" or "Interface\\Common\\VoiceChat-Speaker",
                click = function() focus.SetBookMuted(not focus.bookMuted) end }
            -- (Pas sur la stele ronde : tout son texte est affiche, il n'y a rien a faire defiler.)
            if not DWE.RoundNow() then
            list[#list + 1] = { label = L.AUTOSCROLL_START, on = DialogueWheelE_BookAutoScroll ~= false, off = muted,
                icon = "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up",
                click = function()
                    DialogueWheelE_BookAutoScroll = DialogueWheelE_BookAutoScroll == false
                    if DWE.NoteFollowReset then DWE.NoteFollowReset() end
                end }
            end
            if textBox.dweBook == true then
                list[#list + 1] = { label = L.MENU_VOICE_TURN, on = DialogueWheelE_BookVoiceTurn == true, off = muted,
                    icon = "Interface\\Icons\\INV_Misc_Book_07",
                    click = function() DialogueWheelE_BookVoiceTurn = (DialogueWheelE_BookVoiceTurn ~= true) or nil end }
            end
            list[#list + 1] = { label = L.MENU_STOP_CLOSE, on = DialogueWheelE_BookStopOnClose == true,
                icon = "Interface\\Icons\\Spell_Holy_Silence",
                click = function() DialogueWheelE_BookStopOnClose = (DialogueWheelE_BookStopOnClose ~= true) or nil end }
            list[#list + 1] = { label = L.HIGHLIGHT_BTN, on = DialogueWheelE_BookHighlight ~= false, off = muted, swatch = true,
                click = function()
                    DialogueWheelE_BookHighlight = DialogueWheelE_BookHighlight == false
                    if focus.RestoreHighlight then focus.RestoreHighlight() end
                end }
        end
        -- Marque-page : retient la page affichee ; le livre se rouvrira a cette page.
        local mark = textBox.dweBook == true and DWE.BookmarkInfo and { DWE.BookmarkInfo() }
        if mark and mark[1] then
            list[#list + 1] = { label = L.MENU_MARK or "Bookmark this page", on = mark[3] == mark[2],
                icon = "Interface\\Icons\\INV_Misc_Note_02",
                click = function() DWE.BookmarkToggle() end }
        end
        if textBox.dweBook == true then
            list[#list + 1] = { label = L.MENU_TURN_FX, on = DialogueWheelE_BookTurnFX ~= false,
                icon = "Interface\\Icons\\INV_Misc_Book_09",
                click = function() DialogueWheelE_BookTurnFX = DialogueWheelE_BookTurnFX == false end }
        end
        return list
    end

    local function Paint(b, item)
        local dim = (not item.on) or item.off
        if item.swatch then
            local c = (item.on and not item.off) and (DWE.HighlightRGB and DWE.HighlightRGB() or { 0.61, 0.1, 0.1 }) or { 0.4, 0.4, 0.4 }
            b.icon:SetTexture("Interface\\Buttons\\WHITE8X8")
            b.icon:SetVertexColor(c[1], c[2], c[3])
            b.icon:SetSize(11, 11)
            b.frame:Show()
        else
            b.icon:SetTexture(item.icon)
            b.icon:SetVertexColor(1, 1, 1)
            b.icon:SetSize(16, 16)
            b.frame:Hide()
        end
        if b.icon.SetDesaturated then b.icon:SetDesaturated(dim and true or false) end
        b.text:SetText(item.label)
        -- Choix a la manette : le reglage choisi s'allume, meme eteint (a la souris, un reglage
        -- eteint reste grise au survol, comme avant).
        if item.off then
            b.text:SetTextColor(b.padHover and 0.7 or 0.45, b.padHover and 0.7 or 0.45, b.padHover and 0.7 or 0.45)
        elseif b.padHover then
            b.text:SetTextColor(1, 0.85, 0.2)
        elseif item.on then
            b.text:SetTextColor(b.hover and 1 or 0.95, b.hover and 0.85 or 0.92, b.hover and 0.2 or 0.85)
        else
            b.text:SetTextColor(0.6, 0.58, 0.55)
        end
        -- Barre fine sous un reglage actif : on voit d'un coup d'oeil ce qui est allume.
        b.line:SetShown(item.on and not item.off)
    end

    function DWE.RibbonBarRefresh()
        local list = Items()
        local x = 0
        for i, item in ipairs(list) do
            local b = bar.items[i]
            if not b then
                b = CreateFrame("Button", nil, bar)
                b:SetHeight(26)
                b.icon = b:CreateTexture(nil, "ARTWORK")
                b.icon:SetPoint("CENTER", b, "LEFT", 8, 0)
                b.frame = b:CreateTexture(nil, "BORDER")
                b.frame:SetColorTexture(0, 0, 0, 0.85)
                b.frame:SetPoint("TOPLEFT", b.icon, "TOPLEFT", -2, 2)
                b.frame:SetPoint("BOTTOMRIGHT", b.icon, "BOTTOMRIGHT", 2, -2)
                b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
                b.text:SetPoint("LEFT", b, "LEFT", 22, 0)
                b.text:SetShadowColor(0, 0, 0, 1)
                b.text:SetShadowOffset(1, -1)
                b.line = b:CreateTexture(nil, "ARTWORK")
                b.line:SetColorTexture(0.85, 0.68, 0.30, 0.8)
                b.line:SetHeight(1)
                b.line:SetPoint("BOTTOMLEFT", b.text, "BOTTOMLEFT", 0, -3)
                b.line:SetPoint("BOTTOMRIGHT", b.text, "BOTTOMRIGHT", 0, -3)
                b:SetScript("OnEnter", function(self) self.hover = true; if self.item then Paint(self, self.item) end end)
                b:SetScript("OnLeave", function(self) self.hover = nil; if self.item then Paint(self, self.item) end end)
                b:SetScript("OnClick", function(self)
                    if self.item and not self.item.off then
                        self.item.click()
                        if DWE.RefreshBookOptions then DWE.RefreshBookOptions() end
                        DWE.RibbonBarRefresh()
                    end
                end)
                bar.items[i] = b
            end
            b.item = item
            Paint(b, item)
            local w = (MeasureWidth(b.text) or 90) + 26
            b:SetWidth(w)
            b.x = x
            b:ClearAllPoints()
            b:SetPoint("LEFT", bar, "LEFT", x, 0)
            b:Show()
            x = x + w + 24
        end
        for i = #list + 1, #bar.items do bar.items[i]:Hide() end
        bar.count = #list
        bar:SetWidth(math.max(10, x - 24))
        return #list
    end

    -- Deroulement : chaque reglage glisse un peu vers le bas en apparaissant, l'un apres l'autre.
    local STAGGER, FADE = 0.06, 0.18
    bar:SetScript("OnUpdate", function(self, elapsed)
        if self.idle then return end
        self.t = (self.t or 0) + elapsed * (self.closing and -1.6 or 1)
        local done = true
        for i = 1, self.count or 0 do
            local b = self.items[i]
            local k = math.max(0, math.min(1, (self.t - (i - 1) * STAGGER) / FADE))
            if self.closing then k = math.max(0, math.min(1, (self.t - (i - 1) * STAGGER * 0.4) / FADE)) end
            local e = 1 - (1 - k) * (1 - k)
            b:SetAlpha(e)
            b:ClearAllPoints()
            b:SetPoint("LEFT", self, "LEFT", b.x or 0, 8 * (1 - e))
            if (self.closing and k > 0) or (not self.closing and k < 1) then done = false end
        end
        if done then
            if self.closing then self:Hide() end
            self.closing, self.idle = nil, true -- fini : plus rien a calculer
        end
    end)
    local function Open()
        if DWE.RibbonBarRefresh() == 0 then return end
        bar:ClearAllPoints()
        if textBox.dweBook == true then
            bar:SetPoint("BOTTOM", bookL, "TOP", 0, -10)
        else
            bar:SetPoint("BOTTOM", noteBg, "TOP", 0, 4)
        end
        bar:SetFrameLevel((textBox:GetFrameLevel() or 1) + 6)
        bar.closing, bar.t, bar.idle = nil, 0, nil
        for i = 1, bar.count do bar.items[i]:SetAlpha(0) end
        bar:Show()
        rib.open = true
    end
    local function Close()
        bar.padIdx = nil
        for _, b in ipairs(bar.items) do b.padHover = nil end
        -- Menu ouvert a la manette puis referme (Y, choix d'une entree...) : le halo s'eteint.
        if rib.padGlow then
            rib.padGlow = nil
            if rib.SetGlow then rib.SetGlow(rib.marked and 0.35 or 0) end
        end
        if not bar:IsShown() then return end
        bar.closing, bar.idle = true, nil
        bar.t = math.max(bar.t or 0, FADE + (bar.count or 1) * STAGGER * 0.4)
        rib.open = nil
    end
    -- Livre ferme avec le ruban ouvert : il se replie tout de suite.
    rib:HookScript("OnHide", function()
        if rib.open or bar:IsShown() then
            Close()
            bar.closing = nil
            bar:Hide()
        end
    end)
    DWE.RibbonClose = Close

    -- Manette : Y ouvre le menu du ruban, la croix choisit un reglage (surligne comme au
    -- survol), A l'active, B ou Y referme le menu.
    local function PadPaint()
        for i = 1, bar.count or 0 do
            local b = bar.items[i]
            b.padHover = (i == bar.padIdx) or nil
            if b.item then Paint(b, b.item) end
        end
    end
    function DWE.RibbonPadOpen()
        -- Visible pour de vrai (livre ouvert) : un ruban reste "ouvert" quand on ferme le livre
        -- sans le replier, et la croix ne doit pas lui rester acquise dans les conversations.
        return rib.open and bar:IsVisible() and not bar.closing and (bar.count or 0) > 0 or false
    end
    function DWE.RibbonPadToggle()
        if not rib:IsShown() then return false end
        rib.pulse = nil
        DialogueWheelE_RibbonSeen = true
        -- A la manette, le halo reste allume tant que le menu est ouvert (comme le survol a la souris).
        if rib.open then
            bar.padIdx = nil
            PadPaint()
            Close()
        else
            Open()
            bar.padIdx = 1
            PadPaint()
            if rib.open and rib.SetGlow then rib.padGlow = true; rib.SetGlow(0.55) end
        end
        return true
    end
    function DWE.RibbonPadMove(d)
        local n = bar.count or 0
        if n == 0 then return end
        bar.padIdx = ((bar.padIdx or 1) - 1 + d) % n + 1
        PadPaint()
    end
    function DWE.RibbonPadClick()
        local b = bar.items[bar.padIdx or 1]
        local fn = b and b:IsShown() and b:GetScript("OnClick")
        if fn then fn(b) end
        PadPaint()
    end

    -- Glisser depuis le symbole / le ruban : la fenetre bouge (un clic ouvre toujours le menu).
    rib:RegisterForDrag("LeftButton")
    rib:SetScript("OnDragStart", function() rib.dragged = true; DWE.DragStart("text") end)
    rib:SetScript("OnDragStop", function() DWE.DragStop("text") end)
    rib:SetScript("OnClick", function()
        if rib.dragged then rib.dragged = nil; return end
        rib.pulse = nil
        DialogueWheelE_RibbonSeen = true
        if rib.open then Close() else Open() end
    end)
    -- Premiere fois qu'un livre s'ouvre : le halo "respire" quelques secondes, pour montrer que
    -- le marque-page est un bouton. Une seule fois (retenu pour le compte).
    local PULSE_TIME = 4
    local function Pulse()
        rib.pulse = 0
        DialogueWheelE_RibbonSeen = true
        rib:SetScript("OnUpdate", function(self, elapsed)
            if not self.pulse then self.glow:SetAlpha(0); self:SetScript("OnUpdate", nil) return end
            self.pulse = self.pulse + elapsed
            if self.pulse >= PULSE_TIME then
                self.pulse = nil
                self.glow:SetAlpha(0)
                self:SetScript("OnUpdate", nil)
                return
            end
            -- 3 battements doux, qui s'eteignent a la fin.
            local fadeOut = math.min(1, (PULSE_TIME - self.pulse) / 0.8)
            self.glow:SetAlpha((0.5 - 0.5 * math.cos(self.pulse * 2 * math.pi * 3 / PULSE_TIME)) * 0.7 * fadeOut)
        end)
    end
    local function Glow(target)
        rib.pulse = nil
        rib.glowTarget = target
        rib:SetScript("OnUpdate", function(self, elapsed)
            local a = self.glow:GetAlpha() or 0
            local t = self.glowTarget or 0
            a = a + (t - a) * math.min(1, elapsed * 10)
            if math.abs(t - a) < 0.02 then a = t; self:SetScript("OnUpdate", nil) end
            self.glow:SetAlpha(a)
        end)
    end
    rib:SetScript("OnEnter", function(self)
        self.pulse = nil
        Glow(0.55)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.RIBBON_TIP, 1, 0.82, 0)
        GameTooltip:Show()
    end)
    rib:SetScript("OnLeave", function()
        Glow(rib.marked and 0.35 or 0)
        GameTooltip:Hide()
    end)

    rib.SetGlow = Glow
    -- Page marquee affichee : le ruban garde un leger halo (c'est lui, le marque-page).
    function DWE.UpdateRibbonMark()
        local mark = textBox.dweBook == true and DWE.BookmarkInfo and { DWE.BookmarkInfo() }
        local on = mark and mark[1] and mark[3] == mark[2] or false
        if on == (rib.marked or false) then return end
        rib.marked = on or nil
        if not rib.pulse and not (rib.IsMouseOver and rib:IsMouseOver()) then Glow(on and 0.35 or 0) end
    end

    -- Place : dans la reliure du livre ouvert, ou au coin de la note.
    function DWE.UpdateRibbon(active)
        local book = textBox.dweBook
        -- Note et plaque : leur menu n'a que les reglages de Spoken. Sans Spoken, pas de signature
        -- ni de gravure (rien a ouvrir). Le livre garde son ruban (marque-page, pages animees).
        local focus = DWE.SpokenFocus
        local useful = book == true or (focus and focus.Available and focus.Available())
        -- Hommage a une personne disparue : ni gravure ni menu de lecture, la pierre seule.
        if not (active and useful and DWE.BookByAddon() and (book == true or book == "note"))
            or (DWE.MemorialOpen and DWE.MemorialOpen()) then
            rib.marked = nil
            rib.glow:SetAlpha(0)
            rib:Hide()
            bar:Hide()
            rib.open = nil
            return
        end
        rib:ClearAllPoints()
        if book == true then
            local S = BOOK_W / 1024
            -- Pres de la reliure, sur la page de droite (hors du texte). L'image est peinte pour ce
            -- coin precis du livre (lumiere de la page, ombre portee) : 55 x 96 pixels du livre.
            rib:SetSize(55 * S, 96 * S)
            rib:SetPoint("TOPLEFT", bookL, "TOPLEFT", 484.9 * S, -61.3 * S)
        else
            -- Note : un sceau de cire dans le coin du parchemin. Plaque : un symbole grave dans la
            -- matiere (creux sombre, aretes eclairees), qui s'illumine au survol.
            local plate = DWE.PlateMaterial and DWE.PlateMaterial()
            rib.tex:SetVertexColor(1, 1, 1)
            if rib.tex.SetDesaturated then rib.tex:SetDesaturated(false) end
            local roundPl = plate and DWE.PLATES[plate] and DWE.PLATES[plate].round
            if roundPl and textBox.dweOuter then
                -- Stele ronde : son propre symbole grave ouvre le menu ; il s'illumine au survol
                -- (lueur a sa forme), sans rien ajouter sur la pierre.
                local o = textBox.dweOuter
                rib.tex:SetTexture(ADDON_PATH .. "PlateDalaranGlow.png")
                rib.glow:SetTexture(ADDON_PATH .. "PlateDalaranGlow.png")
                rib.baseAlpha = 0
                rib:SetSize(o * 0.458, o * 0.224)
                rib.glow:SetSize(o * 0.458, o * 0.224)
                rib:SetPoint("CENTER", noteBg, "TOP", 0, -o * 0.2005)
            elseif plate then
                -- Triquetra (noeud a trois pointes) entrelacee avec un cercle.
                do
                    rib.tex:SetTexture(ADDON_PATH .. "EngraveKnot.png")
                    rib.glow:SetTexture(ADDON_PATH .. "EngraveKnotGlow.png")
                    rib:SetSize(40, 40)
                    rib:SetPoint("CENTER", textBox, "TOP", 0, -12)
                    rib.baseAlpha = 0.8 -- gravure un peu plus discrete
                    rib.glow:SetSize(40, 40)
                end
            else
                -- Parchemin : la signature (illisible) du scribe ou de l'auteur, a l'encre, dans la
                -- marge en bas a droite. Une parmi 8, toujours la meme pour un meme texte.
                local title = (DWE.rawHeader or ""):gsub("%s*%(%d+/[%d%?]+%)$", "")
                local h = 0
                for i = 1, #title do h = (h * 31 + title:byte(i)) % 100003 end
                local n = h % 8 + 1
                rib.tex:SetTexture(ADDON_PATH .. "Signature" .. n .. ".png")
                rib.glow:SetTexture(ADDON_PATH .. "Signature" .. n .. "Glow.png")
                rib.baseAlpha = 1
                rib:SetSize(96, 48)
                rib:SetPoint("BOTTOMRIGHT", noteBg, "BOTTOMRIGHT", -20, 2)
                rib.glow:SetSize(96, 48)
            end
        end
        if book == true then
            rib.baseAlpha = 1
            rib.tex:SetTexture(ADDON_PATH .. "Ribbon.png")
            rib.tex:SetVertexColor(1, 1, 1)
            rib.glow:SetTexture(ADDON_PATH .. "RibbonGlow.png")
            local w, h = rib:GetSize()
            rib.glow:SetSize(w * 1.25 + 8, h * 1.125 + 8)
        end
        rib:SetFrameLevel((textBox:GetFrameLevel() or 1) + 6)
        rib:Show()
        if not (DWE.ribbonFade and DWE.ribbonFade:GetScript("OnUpdate")) then rib.tex:SetAlpha(rib.baseAlpha or 1) end
        -- Le symbole de la stele ronde a son propre "premiere fois" : un joueur qui connait deja
        -- le ruban des livres ne devinerait pas qu'il s'ouvre aussi.
        if DWE.RoundNow() then
            if not DialogueWheelE_RoundRibbonSeen and not rib.pulse then
                DialogueWheelE_RoundRibbonSeen = true
                if not (DWE.PadInUse and DWE.PadInUse()) then Pulse() end
            end
        elseif not DialogueWheelE_RibbonSeen and not rib.pulse then
            -- A la manette, l'astuce a l'ecran dit deja "Y : menu du ruban" : pas de battement.
            if DWE.PadInUse and DWE.PadInUse() then DialogueWheelE_RibbonSeen = true else Pulse() end
        end
        DWE.UpdateRibbonMark()
        if bar:IsShown() and not bar.closing then DWE.RibbonBarRefresh() end
    end
end

function DWE.UpdateBookBar()
    local active = DWE.bookMode and textBox:IsShown() and choiceBox:IsShown() and #DWE.currentOptions > 0
    MuteDUIBook(DWE.BookByAddon() and choiceBox:IsShown())
    DWE.UpdateRibbon(active)
    if not active then
        bookBar:Hide()
        SetWheelHidden(false)
        return
    end
    SetWheelHidden(true)
    bookBar:ClearAllPoints()
    local below = (textBox.dweBook == true and (BOOK_H - BOOK_TOP - BOOK_TEXT_H + 4))
        or (textBox.dweBook == "note" and ((textBox.dwePadB or NOTE_PAD_Y) + 6)) or 26
    -- (Decalage dans l'echelle de la barre, qui peut differer de celle du texte.)
    bookBar:SetPoint("TOP", textBox, "BOTTOM", 0, -below * (textBox:GetScale() or 1) / (bookBar:GetScale() or 1))
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
                    if DWE.LagMark then DWE.LagMark(o.rawLabel or o.label) end
                    o.action()
                end
            end)
            bookBar.buttons[i] = b
        end
        if opt.icon then DWE.SetOptionIcon(b.icon, opt) else b.icon:SetTexture(nil) end
        b.icon:SetShown(opt.icon ~= nil)
        -- Icone peinte (bouton "Surbrillance" : carre de la couleur des mots lus, cerne de noir).
        local ic = opt.iconColor
        b.icon:SetVertexColor(ic and ic[1] or 1, ic and ic[2] or 1, ic and ic[3] or 1)
        if ic and not b.iconBorder then
            b.iconBorder = b:CreateTexture(nil, "BORDER")
            b.iconBorder:SetColorTexture(0, 0, 0, 0.85)
            b.iconBorder:SetPoint("TOPLEFT", b.icon, "TOPLEFT", -2, 2)
            b.iconBorder:SetPoint("BOTTOMRIGHT", b.icon, "BOTTOMRIGHT", 2, -2)
        end
        if b.iconBorder then b.iconBorder:SetShown(ic ~= nil) end
        b.icon:SetSize(ic and 12 or 16, ic and 12 or 16)
        b.text:SetText(DWE.ChoiceLabel(opt, i))
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
        -- Journal (/storytale livrelog) : un livre qui change d'aspect pendant qu'on le lit (livre,
        -- page seule, simple cadre) -> le livre « en double » vu une image en tournant les pages.
        if DWE.bookMode and look ~= DWE.lastLook then
            DWE.lookLog = DWE.lookLog or {}
            if #DWE.lookLog < 200 then
                local bi = DWE.bookInfo or {}
                local okP, plate = pcall(DWE.RawPlate)
                DWE.lookLog[#DWE.lookLog + 1] = string.format("%.2f %s -> %s | echelle=%.2f voulue=%.2f | style=%s plaque=%s page=%s/%s suite=%s | %s",
                    GetTime and GetTime() or 0, tostring(DWE.lastLook), tostring(look), textBox:GetScale() or 0, DWE.BookScaleWanted(), tostring(DWE.BookStyleNow()),
                    tostring(okP and plate), tostring(bi.page), tostring(bi.total), tostring(bi.hasNext),
                    (debugstack and debugstack(2, 3, 0) or ""):gsub("Interface[/\\]AddOns[/\\]", ""):gsub("\n", " < "))
            end
        end
        DWE.lastLook = look
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
            -- Largeur choisie avec la poignee, sinon 60 % de l'ecran.
            maxW = tonumber(DialogueWheelE_TextW) or math.max(380, math.min(900, uw * 0.6))
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
    -- DialogueUI a pu montrer sa fenetre (livre, quete) juste avant la notre : rien ne l'a
    -- recachee depuis. On repasse sur toutes les fenetres, tout de suite puis un peu apres
    -- (le temps de son animation d'ouverture).
    RefreshHiddenFrames()
    if C_Timer and C_Timer.After then
        C_Timer.After(0.3, RefreshHiddenFrames)
        C_Timer.After(0.8, RefreshHiddenFrames)
    end
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
    if DWE.UpdateSpokenPlayers then DWE.UpdateSpokenPlayers() end
    if DWE.TextInRefresh then DWE.TextInRefresh() end
end
-- Spoken redessine ses lecteurs (apres une bascule bulle / lecteur, ils apparaissent ou partent).
function DWE.UpdateSpokenPlayers()
    local env = rawget(_G, "SpokenEnv")
    if type(env) ~= "table" then return end
    for _, name in ipairs({ "PlayerFrame", "MinimalPlayer", "DialogueUIPlayer", "Subtitle" }) do
        local w = rawget(env, name)
        if type(w) == "table" and type(w.Update) == "function" and (name ~= "MinimalPlayer" or w.frame) then
            pcall(w.Update, w)
        end
    end
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

-- Le cadre de texte (et la bulle, posee sur lui hors suivi du PNJ) doit toujours avoir une place.
-- Sans position enregistree, rendre la place fixe le laissait sans aucun point : la bulle n'avait
-- plus de position et disparaissait (vu a la manette, en prenant une quete).
function DWE.EnsureTextPlaced()
    if textBox:GetNumPoints() == 0 then
        textBox:SetPoint("TOPRIGHT", choiceBox, "TOPLEFT", -125, 110)
        DWE.SetGripCorner(textBox, "TOPRIGHT")
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

-- PNJ de la conversation : son GUID est retenu, car a la manette le jeu peut retirer l'unite
-- "npc" a l'ouverture d'une quete alors que la conversation continue.
DWE.lastNPC = { guid = nil, t = 0 }
function DWE.RememberNPC()
    if not (UnitGUID and Check(UnitExists, "npc")) then return end
    local ok, guid = pcall(UnitGUID, "npc")
    if ok and guid then DWE.lastNPC.guid = guid DWE.lastNPC.t = GetTime and GetTime() or 0 end
end
function DWE.LastNPCGUID() return DWE.lastNPC.guid end

-- /storytale followlog : journal du suivi du PNJ dans le chat.
function DWE.FLog(msg)
    if not DWE.followLog then return end
    local t = GetTime and string.format("%.2f", GetTime() % 1000) or ""
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ccff[ST suivi " .. t .. "]|r " .. tostring(msg))
end
do
    local f = CreateFrame("Frame")
    for _, e in ipairs({ "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "GOSSIP_SHOW", "GOSSIP_CLOSED",
        "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_FINISHED", "QUEST_GREETING", "CVAR_UPDATE",
        "PLAYER_TARGET_CHANGED", "PLAYER_SOFT_INTERACT_CHANGED", "PLAYER_SOFT_FRIEND_CHANGED" }) do
        pcall(f.RegisterEvent, f, e)
    end
    f:SetScript("OnEvent", function(_, e, a, b)
        if not DWE.followLog then return end
        if e == "CVAR_UPDATE" then
            if tostring(a):lower():find("nameplate") then DWE.FLog("CVar " .. tostring(a) .. "=" .. tostring(b)) end
            return
        end
        local extra = ""
        if e:find("NAME_PLATE") then
            local ok, n = pcall(UnitName, a)
            local okN, isN = pcall(UnitIsUnit, a, "npc")
            extra = " " .. tostring(a) .. " " .. tostring(ok and n) .. (okN and isN and " (PNJ)" or "")
        end
        local function U(u)
            local okE, ex = pcall(UnitExists, u)
            local okI, isN = pcall(UnitIsUnit, u, "npc")
            local okP, pl = pcall(C_NamePlate.GetNamePlateForUnit, u)
            return tostring(okE and ex) .. (okI and isN and "(PNJ)" or "") .. (okP and pl and "+plaque" or "")
        end
        DWE.FLog(e .. extra .. " | npc=" .. tostring(UnitExists and UnitExists("npc"))
            .. " cible=" .. U("target") .. " vise=" .. U("softinteract") .. " allie=" .. U("softfriend"))
    end)
end

function DWE.PlateForUnit(unit)
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return nil end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if ok and UsablePlate(plate) then return plate end
end

local function FindNPCPlate()
    if Check(UnitExists, "npc") then
        DWE.RememberNPC()
        for _, plate in ipairs(GetPlates()) do
            if UsablePlate(plate) and Check(UnitIsUnit, PlateToken(plate), "npc") then return plate end
        end
        -- A la manette, la plaque du PNJ peut etre celle de l'interaction (hors de la liste).
        local direct = DWE.PlateForUnit("npc")
        if direct then return direct end
    end
    -- Plaque d'interaction ou cible : meme PNJ que celui retenu ?
    local guid0 = DWE.lastNPC.guid
    if guid0 and UnitGUID then
        for _, u in ipairs({ "softinteract", "target" }) do
            local ok, g = pcall(UnitGUID, u)
            if ok and g == guid0 then
                local pl = DWE.PlateForUnit(u)
                if pl then return pl end
            end
        end
        local pl = DWE.PlateForUnit("softinteract")
        if pl then
            local ok, g = pcall(UnitGUID, PlateToken(pl))
            if ok and g == guid0 then return pl end
        end
    end
    if Check(UnitExists, "npc") then return nil end
    -- Plus d'unite "npc" : on retrouve le meme PNJ par son GUID (conversation recente seulement).
    local guid = DWE.lastNPC.guid
    if not (guid and UnitGUID) then return nil end
    if GetTime and GetTime() - DWE.lastNPC.t > 600 then return nil end
    for _, plate in ipairs(GetPlates()) do
        if UsablePlate(plate) then
            local ok, g = pcall(UnitGUID, PlateToken(plate))
            if ok and g == guid then return plate end
        end
    end
end

-- Plaques activees par l'addon : on cache celles des unites amicales (on ne garde que leur
-- position). Les plaques d'ennemis ne sont jamais touchees.
-- Nom seul : un PNJ (pas le PNJ de la conversation, pas un objet) pendant le reglage "plaques
-- proches" de la manette.
function DWE.NameOnlyWanted(token)
    if not (DWE.softSaved and DWE.softSaved.nameplateShowAll) or not token then return false end
    if not Check(UnitExists, token) or Check(UnitIsUnit, token, "npc") then return false end
    -- Le PNJ de la conversation (l'unite "npc" disparait un instant entre gossip et quete) : sa
    -- plaque reste cachee, la bulle est au-dessus de lui.
    local okG, g = pcall(UnitGUID, token)
    if okG and g and g == DWE.lastNPC.guid then return false end
    if Check(UnitIsPlayer, token) or Check(UnitCanAttack, "player", token) then return false end
    return true
end

-- Cache tout sauf le texte du nom ; retourne la liste des elements caches (pour les rendre).
function DWE.PlateNameOnly(uf)
    local name = uf.name or uf.Name
    if not (name and name.GetObjectType) then return nil end
    local parts, n = { desc = "" }, 0
    local function Hide(r)
        if r == name or not r or not r.GetAlpha or not r.SetAlpha then return end
        local okA, a = pcall(r.GetAlpha, r)
        if okA and a and a > 0 and pcall(r.SetAlpha, r, 0) then
            parts[#parts + 1] = { r, a }
            n = n + 1
        end
    end
    local okC, children = pcall(function() return { uf:GetChildren() } end)
    if okC then for _, c in ipairs(children) do
        -- Un enfant qui porte le nom n'est pas cache en entier : seulement ses autres elements.
        local okP, par = pcall(name.GetParent, name)
        if okP and par == c then
            local okR, regs = pcall(function() return { c:GetRegions() } end)
            if okR then for _, r in ipairs(regs) do Hide(r) end end
        else
            Hide(c)
        end
    end end
    local okR, regs = pcall(function() return { uf:GetRegions() } end)
    if okR then for _, r in ipairs(regs) do Hide(r) end end
    if uf:GetAlpha() ~= 1 then uf:SetAlpha(1) end
    parts.name, parts.uf = name, uf
    parts.desc = n .. " element(s) caches"
    return parts
end

-- Titre d'un PNJ ("<Innkeeper Assistant>") lu dans son infobulle (2e ligne, si ce n'est pas le niveau).
function DWE.NPCTitle(token)
    local tip = DWE.titleTip
    if not tip then
        local ok, t = pcall(CreateFrame, "GameTooltip", "DWE_TitleScanTip", nil, "GameTooltipTemplate")
        if not ok or not t then return nil end
        tip, DWE.titleTip = t, t
    end
    local line
    pcall(function()
        tip:SetOwner(WorldFrame, "ANCHOR_NONE")
        tip:SetUnit(token)
        local fs = _G["DWE_TitleScanTipTextLeft2"]
        line = fs and fs:GetText()
        tip:Hide()
    end)
    if type(line) ~= "string" or line == "" then return nil end
    local lvl = type(LEVEL) == "string" and LEVEL or "Level"
    if line:find(lvl, 1, true) or line:find("%d") then return nil end
    return line
end

-- Taille du nom imitant le nom habituel des PNJ (reglable : /run DWE.NEAR_NAME_SIZE = 40).
DWE.NEAR_NAME_SIZE = 40
DWE.NEAR_NAME_Y = -26 -- decalage vertical (reglable : /run DWE.NEAR_NAME_Y = -20)
DWE.ownNames = setmetatable({}, { __mode = "k" })
-- Le nom habituel d'un PNJ grossit quand la camera s'approche, puis ne rapetisse plus au-dela
-- d'un certain recul. Mesure sur captures (Tannok, largeur du nom) : 560 px au zoom 1,9 ;
-- 261 px au zoom 6,4 ; ~200 px de loin (taille minimale, zoom 50 et zoom ~15). Notre texte : ~7,4 px par point.
-- Taille = 281 / (zoom + 1,6) (recale sur la capture au zoom 1,5), au moins 26,7 (de loin) ; NEAR_NAME_SIZE (40 = reference) l'ajuste.
function DWE.NearNameSize()
    local okZ, z = pcall(GetCameraZoom)
    z = (okZ and type(z) == "number") and z or 6
    -- (+15 % : PNJ voisin colle au joueur, cas le plus courant ; mesure sur captures proche et habituelle.)
    local size = math.max(281 / (z + 1.6) * 1.15, 26.7) * (DWE.NEAR_NAME_SIZE / 40)
    if size < 12 then size = 12 elseif size > 110 then size = 110 end
    return size
end
-- Habille un texte a nous, pose sur le nom de la plaque (cache), comme le nom habituel du PNJ :
-- police du jeu, vert vif (jaune si neutre), ombre, titre en dessous, sans limite de largeur.
function DWE.PlateNameStyle(parts, token)
    local name = parts and parts.name
    if not name then return end
    local okN, nm = pcall(UnitName, token)
    if not (okN and type(nm) == "string" and nm ~= "") then return end
    if parts.titleFor ~= token then
        parts.titleFor, parts.title = token, DWE.NPCTitle(token)
    end
    local uf = parts.uf
    local fs = uf and DWE.ownNames[uf]
    if uf and not fs then
        local okC, f = pcall(uf.CreateFontString, uf, nil, "OVERLAY")
        if not okC or not f then return end
        fs, DWE.ownNames[uf] = f, f
    end
    if not fs then return end
    if not parts.nameHidden then
        local okA, a = pcall(name.GetAlpha, name)
        if pcall(name.SetAlpha, name, 0) then parts[#parts + 1] = { name, okA and a or 1 } end
        parts.nameHidden = true
    end
    -- Le jeu redessine parfois la plaque (fermeture de la quete...) et rend visibles son petit nom
    -- et sa barre : tout ce que nous avons cache le reste, a chaque image.
    for _, e in ipairs(parts) do
        local okA, a = pcall(e[1].GetAlpha, e[1])
        if okA and a and a > 0 then pcall(e[1].SetAlpha, e[1], 0) end
    end
    local font = "Fonts\\FRIZQT__.TTF"
    local size = DWE.NearNameSize()
    if not fs.dweInit or fs.dweY ~= DWE.NEAR_NAME_Y then
        fs.dweInit, fs.dweY, fs.dweSize = true, DWE.NEAR_NAME_Y, nil
        -- Les plaques non ciblees sont semi-transparentes : le nom habituel, lui, ne l'est pas.
        if fs.SetIgnoreParentAlpha then pcall(fs.SetIgnoreParentAlpha, fs, true) end
        -- Le nom habituel a des traits plus epais et presque pas d'ombre noire : une "ombre"
        -- verte decalee d'un pixel epaissit les traits comme lui (mesure sur captures).
        pcall(fs.SetShadowOffset, fs, 1, -1)
        pcall(fs.SetJustifyH, fs, "CENTER")
        pcall(fs.SetSpacing, fs, 0)
        pcall(fs.ClearAllPoints, fs)
        pcall(fs.SetPoint, fs, "BOTTOM", name, "BOTTOM", 0, DWE.NEAR_NAME_Y)
        -- Taille continue (sans paliers) si le jeu sait mettre un texte a l'echelle.
        fs.dweScaled = fs.SetTextScale and pcall(fs.SetFont, fs, font, 40, "") and pcall(fs.SetTextScale, fs, 1)
    end
    if fs.dweScaled then
        if not fs.dweSize or math.abs(fs.dweSize - size) > 0.05 then
            fs.dweSize = size
            pcall(fs.SetTextScale, fs, size / 40)
        end
    else
        local rs = math.floor(size + 0.5)
        if fs.dweSize ~= rs then fs.dweSize = rs pcall(fs.SetFont, fs, font, rs, "") end
    end
    local text = parts.title and (nm .. "\n<" .. parts.title .. ">") or nm
    if fs.dweText ~= text then fs.dweText = text pcall(fs.SetText, fs, text) end
    local r, g, b = 0, 1, 0 -- vert pur, comme le nom habituel (mesure : 0, 251, 0)
    local okR, react = pcall(UnitReaction, token, "player")
    if okR and react == 4 then r, g, b = 1, 1, 0 end
    pcall(fs.SetTextColor, fs, r, g, b, 1)
    pcall(fs.SetShadowColor, fs, r, g, b, 1)
    if not fs:IsShown() then fs:Show() end
    -- Journal : de quoi caler la taille sur la distance de la camera (le nom habituel en depend).
    if DWE.followLog and parts.loggedFor ~= token then
        parts.loggedFor = token
        local okZ, z = pcall(GetCameraZoom)
        local function cv(k) local ok, v = pcall(GetCVar, k) return ok and tostring(v) or "?" end
        DWE.FLog(("nom maquille : %s | zoom camera=%s | taille=%s | echelle plaques min=%s max=%s dist=%s"):format(
            nm, tostring(okZ and z and string.format("%.2f", z)), string.format("%.1f", DWE.NearNameSize()),
            cv("nameplateMinScale"), cv("nameplateMaxScale"), cv("nameplateMinScaleDistance")))
    end
end

function DWE.PlateRestoreParts(uf, parts)
    if type(parts) ~= "table" then return end
    for _, e in ipairs(parts) do pcall(e[1].SetAlpha, e[1], e[2]) end
    local fs = DWE.ownNames[uf]
    if fs then fs:Hide() end
end

local function MaskFriendlyPlates()
    if not (savedPlateCVar or DWE.savedShowAll) then return end
    for _, plate in ipairs(GetPlates()) do
        local uf = plate.UnitFrame
        if uf and not (uf.IsForbidden and uf:IsForbidden()) then
            local token = PlateToken(plate)
            -- Rien ne doit changer a l'ecran : les plaques que le joueur voyait avant la
            -- conversation restent visibles, celles apparues a cause de nos reglages sont cachees.
            local hide
            if token and DWE.plateSeen then
                local okG, g = pcall(UnitGUID, token)
                local okS, seen = pcall(function() return okG and g and DWE.plateSeen[g] end)
                hide = not (okS and seen)
            elseif token then
                hide = not Check(UnitCanAttack, "player", token)
            end
            -- Les cadres de plaques sont reutilises : on reevalue a chaque passage.
            local want = hide and DWE.NameOnlyWanted(token)
            if type(maskedFrames[uf]) == "table" and not want then
                DWE.PlateRestoreParts(uf, maskedFrames[uf])
                maskedFrames[uf] = hide and true or nil
                if hide then uf:SetAlpha(0) else uf:SetAlpha(1) end
            end
            if want and type(maskedFrames[uf]) ~= "table" then
                -- PNJ voisin qui recoit une plaque a cause du reglage "plaques proches" (manette) :
                -- le jeu cache alors son nom habituel ; on garde le nom de la plaque, le reste est cache.
                local parts = DWE.PlateNameOnly(uf)
                if parts then
                    maskedFrames[uf] = parts
                    if DWE.followLog then DWE.FLog("plaque reduite au nom : " .. tostring(select(2, pcall(UnitName, token))) .. " (" .. tostring(token) .. ") " .. tostring(parts.desc)) end
                end
            end
            if hide and type(maskedFrames[uf]) == "table" then
                DWE.PlateNameStyle(maskedFrames[uf], token) -- le jeu peut remettre son style : on le reapplique
            elseif hide then
                if uf:GetAlpha() ~= 0 then uf:SetAlpha(0) end
                if not maskedFrames[uf] and DWE.followLog then
                    local okN, n = pcall(UnitName, token)
                    DWE.FLog("plaque cachee : " .. tostring(okN and n) .. " (" .. tostring(token) .. ")")
                end
                maskedFrames[uf] = true
            elseif maskedFrames[uf] then
                DWE.PlateRestoreParts(uf, maskedFrames[uf])
                uf:SetAlpha(1)
                maskedFrames[uf] = nil
            end
        end
    end
end

local function UnmaskPlates(onlyGone)
    for uf, parts in pairs(maskedFrames) do
        local gone = true
        if onlyGone then
            -- Plaque encore portee par une unite : le jeu va la retirer (reglages remis) ; la
            -- rendre visible maintenant la faisait apparaitre un instant a la fin de la conversation.
            -- Le jeu efface l'unite de la plaque un instant avant de la cacher : on attend qu'elle
            -- soit cachee, puis encore un peu (sinon son petit nom d'origine se voyait un instant).
            local plate = uf:GetParent()
            local okS, shown = pcall(function() return plate and plate:IsShown() end)
            gone = false
            if not (okS and shown) then
                local now = GetTime and GetTime() or 0
                DWE.goneAt = DWE.goneAt or setmetatable({}, { __mode = "k" })
                DWE.goneAt[uf] = DWE.goneAt[uf] or now
                gone = now - DWE.goneAt[uf] >= 0.15
            elseif DWE.goneAt then
                DWE.goneAt[uf] = nil
            end
        end
        if not gone and type(parts) == "table" and uf:GetAlpha() ~= 0 then
            -- Fin de conversation : le jeu remet ses reglages et redessine les plaques encore la
            -- (leur petit nom revenait un instant). La plaque entiere est cachee ; notre nom, qui
            -- ignore la transparence de la plaque, reste affiche jusqu'a ce qu'elle disparaisse.
            uf:SetAlpha(0)
        end
        if gone then
            DWE.PlateRestoreParts(uf, parts)
            uf:SetAlpha(1)
            maskedFrames[uf] = nil
            if DWE.goneAt then DWE.goneAt[uf] = nil end
        end
    end
end
-- Fin de conversation : chaque plaque cachee est rendue quand le jeu l'a retiree (au plus 1,5 s).
function DWE.UnmaskWhenGone(stillMasking)
    local t = 0
    local function Step()
        if stillMasking() then return end -- une conversation a repris : elle garde ses plaques
        t = t + 0.05
        UnmaskPlates(t < 1.5)
        if next(maskedFrames) and t < 1.5 then C_Timer.After(0.05, Step) end
    end
    C_Timer.After(0.05, Step)
end

local function SetFriendlyPlates(on)
    if not (GetCVar and SetCVar) or InCombatLockdown() then return end
    -- Aucun reglage des plaques n'est plus change en conversation : activer les plaques des PNJ
    -- amicaux changeait l'affichage des noms de TOUS les PNJ autour. Storytale n'utilise plus
    -- que la plaque que le jeu donne deja au PNJ a qui l'on parle.
    if on then
        local cur = GetCVar("nameplateShowFriendlyNPCs")
        if cur and cur ~= "1" then
            savedPlateCVar = cur
            SetCVar("nameplateShowFriendlyNPCs", "1")
        end
        -- "Toujours afficher les plaques" coupe : a la manette, la plaque du PNJ n'existait que
        -- comme cible d'interaction et le jeu la retirait a l'ouverture d'une quete.
        -- (Comme en 1.7.0 : seulement les plaques des PNJ amicaux. "Toujours afficher les
        -- plaques" faisait apparaitre celles de tous les PNJ autour.)
        -- Garde la valeur du joueur meme apres un /reload ou une deconnexion en pleine conversation.
        if savedPlateCVar or DWE.savedShowAll or DWE.softSaved then
            DialogueWheelE_PlateRestore = { friendly = savedPlateCVar, all = DWE.savedShowAll, alpha = DWE.plateAlphaSaved, soft = DWE.softSaved }
        end
    elseif savedPlateCVar or DWE.savedShowAll or DWE.softSaved then
        -- Avant de rendre ses reglages au jeu : les plaques reduites au nom sont cachees en entier
        -- (le jeu les redessine aussitot et leur petit nom revenait un instant). Notre nom, qui
        -- ignore la transparence de la plaque, reste jusqu'a ce que le jeu la retire.
        -- Notre nom est cache aussi : la plaque rapetisse en disparaissant et il rapetissait avec.
        for uf, parts in pairs(maskedFrames) do
            if type(parts) == "table" then
                pcall(uf.SetAlpha, uf, 0)
                local fs = DWE.ownNames[uf]
                if fs then fs:Hide() end
            end
        end
        if DWE.softSaved then
            for k, v in pairs(DWE.softSaved) do pcall(SetCVar, k, v) end
            DWE.softSaved = nil
        end
        if DWE.savedShowAll then
            SetCVar("nameplateShowAll", DWE.savedShowAll)
            DWE.savedShowAll = nil
        end
        -- Opacite rendue un instant apres, une fois les plaques retirees.
        local alpha = DWE.plateAlphaSaved
        DWE.plateAlphaSaved = nil
        if alpha then
            DWE.plateAlphaPending = alpha
            local function Back()
                if DWE.plateAlphaPending ~= alpha then return end -- reprise par une conversation
                DWE.plateAlphaPending = nil
                for k, v in pairs(alpha) do pcall(SetCVar, k, v) end
            end
            if C_Timer and C_Timer.After then C_Timer.After(0.2, Back) else Back() end
        end
        -- D'abord retirer les plaques, ensuite seulement leur rendre leur opacite (sinon elles
        -- reapparaissent une image avant de disparaitre).
        if savedPlateCVar then SetCVar("nameplateShowFriendlyNPCs", savedPlateCVar) end
        savedPlateCVar = nil
        DialogueWheelE_PlateRestore = nil
        if C_Timer and C_Timer.After then
            DWE.UnmaskWhenGone(function() return savedPlateCVar or DWE.savedShowAll end)
        else
            UnmaskPlates()
        end
    end
end

-- Appele a la sortie de combat si le reglage n'a pas pu etre remis pendant le combat.
-- Au chargement : reglages des plaques laisses changes par une session coupee en conversation.
function DWE.RestoreLeftoverPlates()
    local r = DialogueWheelE_PlateRestore
    if type(r) ~= "table" or not SetCVar or (InCombatLockdown and InCombatLockdown()) then return end
    if r.friendly then pcall(SetCVar, "nameplateShowFriendlyNPCs", r.friendly) end
    if r.all then pcall(SetCVar, "nameplateShowAll", r.all) end
    if type(r.alpha) == "table" then for k, v in pairs(r.alpha) do pcall(SetCVar, k, v) end end
    if type(r.soft) == "table" then for k, v in pairs(r.soft) do pcall(SetCVar, k, v) end end
    DialogueWheelE_PlateRestore = nil
end

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
    DWE.EnsureTextPlaced()
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
    -- Jamais plus petit que la normale : sur un nain ou un gnome le texte devenait illisible.
    -- (La position, elle, suit toujours la taille du PNJ.)
    return math.max(1, math.min(1.1, 0.55 + 0.45 * sf))
end

local function SetFrameScales(sc)
    for _, fr in ipairs({ choiceBox, textBox, DWE.bubble }) do
        if fr and fr:GetScale() ~= sc then fr:SetScale(sc) end
    end
end

-- Hauteur de la liste et bulle affichee : ce dont depend la place de la roue sous la bulle.
function DWE.WheelAnchorKey()
    local okH, h = pcall(choiceBox.GetHeight, choiceBox)
    h = (okH and type(h) == "number") and math.floor(h + 0.5) or 0
    return h, (DWE.bubble and DWE.bubble:IsShown()) and true or false
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
    -- Ce qui a servi a placer la roue : si la liste change de hauteur (nouvelle page de dialogue
    -- du meme PNJ) ou si la bulle apparait ou disparait, le suivi replace la roue (voir plus bas).
    follow.wheelH, follow.bubbleOn = DWE.WheelAnchorKey()
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
    -- Ecart sur le cote : un grand PNJ (elfe, tauren) n'eloigne plus la roue, seule la hauteur suit.
    -- (Plafond proche de celui du nain : plus la roue est loin du PNJ, plus elle semble flotter
    -- quand on tourne autour ou qu'on s'approche, car le zoom suit la camera, pas la distance.)
    local kx = f * math.min(0.7, sf)
    choiceBox:SetPoint(m == 1 and "LEFT" or "RIGHT", plate, "CENTER", m * o.wheelX * kx / ws, wy / ws)
    DWE.SnapToPixels(choiceBox)
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
    if DWE.FLog then DWE.FLog("decroche (plaque perdue, place fixe)") end
    follow.plate = nil
    SetFrameScales(1)
    RestoreFixed()
end

-- A la manette, a la fermeture du gossip, le jeu enleve la cible ; la plaque du PNJ n'existait
-- que parce qu'il etait la cible, et le jeu la retire 0,3 s plus tard (deja le cas en 1.7.0).
-- Seul "toujours afficher les plaques" la garde. On l'active a ce moment-la seulement, avec une
-- distance d'affichage tres courte (seuls le PNJ et ceux colles a lui sont concernes), puis tout
-- est remis a la fin de la conversation. A la souris la cible reste : rien n'est change.
DWE.NEAR_PLATES = "5"
function DWE.KeepNPCPlate()
    if not (follow.plate and GetCVar and SetCVar) or (InCombatLockdown and InCombatLockdown()) then return end
    -- Cible gardee (souris) : rien a faire. L'unite "npc" n'existe plus a cet instant (fermeture
    -- du gossip) : on compare la cible au PNJ retenu, par son identifiant.
    if Check(UnitIsUnit, "target", "npc") then return end
    local okT, tg = pcall(UnitGUID, "target")
    if okT and tg and tg == DWE.lastNPC.guid then return end
    if DWE.softSaved and DWE.softSaved.nameplateShowAll then return end
    local okA, all = pcall(GetCVar, "nameplateShowAll")
    local okD, dist = pcall(GetCVar, "nameplateMaxDistance")
    if not (okA and all) or all == "1" then
        DWE.FLog("plaques toujours affichees deja actives (" .. tostring(all) .. ")")
        return
    end
    DWE.softSaved = DWE.softSaved or {}
    if okD and dist then
        DWE.softSaved.nameplateMaxDistance = dist
        pcall(SetCVar, "nameplateMaxDistance", DWE.NEAR_PLATES)
    end
    DWE.softSaved.nameplateShowAll = all
    pcall(SetCVar, "nameplateShowAll", "1")
    DialogueWheelE_PlateRestore = DialogueWheelE_PlateRestore or {}
    DialogueWheelE_PlateRestore.soft = DWE.softSaved
    local _, nowA = pcall(GetCVar, "nameplateShowAll")
    local _, nowD = pcall(GetCVar, "nameplateMaxDistance")
    DWE.FLog("cible enlevee par le jeu : plaques proches gardees (toujours=" .. tostring(all) .. "->" .. tostring(nowA)
        .. ", distance=" .. tostring(dist) .. "->" .. tostring(nowD) .. ")")
end

follower:SetScript("OnEvent", function(_, event, unit)
    -- Fin du gossip, mais aussi fin de la liste de quetes (QUEST_GREETING -> QUEST_DETAIL) ou
    -- cible enlevee par le jeu (manette) : la plaque du PNJ allait disparaitre pareil.
    if event == "GOSSIP_CLOSED" or event == "QUEST_FINISHED" or event == "PLAYER_TARGET_CHANGED" then
        pcall(DWE.KeepNPCPlate)
    end
    pcall(MaskFriendlyPlates)
end)


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
        if ok and point then DWE.BookPosSet({ point = point, relPoint = relPoint, x = x, y = y }) end
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
    -- La roue garde un ecart lateral plafonne (voir AnchorTo) : meme facteur ici.
    local kx = dragging.which == "wheel" and (follow.zoomF or 1) * math.min(0.7, follow.sizeF or 1) or k
    o[dragging.which .. "X"] = dragging.ox + m * (cx - dragging.cx) / kx
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
    DialogueWheelE_DUIPos = nil
    if DWE.DUIToLeft then DWE.DUIToLeft() end
    DialogueWheelE_BookScale, DialogueWheelE_NoteScale = nil, nil
    DialogueWheelE_RoundScale, DialogueWheelE_RoundPos = nil, nil
    DialogueWheelE_QuestWidth = nil
    DialogueWheelE_TextW, DialogueWheelE_TextH = nil, nil
    DialogueWheelE_WheelWidth, DialogueWheelE_BubbleWidth = nil, nil
    DWE.ApplyScale()
    if choiceBox:IsShown() then DWE.UpdateVisuals() end
    if DWE.Bubble then DWE.Bubble.Refit() end
    if DWE.ResetSpokenPlace then DWE.ResetSpokenPlace() end
end
-- Le lecteur Spoken (carte, lecteur facon DialogueUI) retourne a la place par defaut de
-- Storytale : on oublie la place que Spoken a retenue apres un deplacement.
function DWE.ResetSpokenPlace()
    local env = rawget(_G, "SpokenEnv")
    local addon = type(env) == "table" and rawget(env, "Addon")
    if type(addon) ~= "table" or type(addon.Layout) ~= "function" then return end
    local ok, layout = pcall(addon.Layout, addon)
    if not ok or type(layout) ~= "table" then return end
    layout.Minimal, layout.DialogueUI = nil, nil
    if DWE.SpokenPlayersPlace then pcall(DWE.SpokenPlayersPlace) end
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
    -- Cadre qui s'etend vers la gauche (apercu de quete, roue a gauche) : poignee en miroir.
    g.mirror = frame.dweGripLeft and true or nil
    local l, rgt = g.mirror and 1 or 0, g.mirror and 0 or 1
    for _, t in ipairs({ g:GetNormalTexture(), g:GetHighlightTexture(), g:GetPushedTexture() }) do
        if t then t:SetTexCoord(l, rgt, 0, 1) end
    end
    if g.mirror then
        g:SetPoint("BOTTOMLEFT", frame.dweGripAnchor or frame, "BOTTOMLEFT", -(ox - 6), -(oy - 6))
    else
        g:SetPoint("BOTTOMRIGHT", frame.dweGripAnchor or frame, "BOTTOMRIGHT", ox - 6, -(oy - 6))
    end
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
    if grip.mirror then dx = -dx end -- poignee a gauche : tirer vers la gauche elargit
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
        if textBox.dweBook == "note" then
            -- Stele ronde : la poignee suit le disque entier, pas la largeur du texte.
            if DWE.RoundNow() and textBox.dweOuter then return textBox.dweOuter * DWE.NoteScale(), 0 end
            return NOTE_W * DWE.NoteScale(), 0
        end
        return textBox.dweW or 380, 0
    end,
    done = function()
        if textBox.dweBook == true or textBox.dweBook == "note" then
            DWE.bookRelayoutT = nil; DWE.UpdateTextPanelVisuals()
        end
    end,
    set = function(w)
        if textBox.dweBook == "note" then
            local sc = DWE.RoundNow() and Clamp(w / (textBox.dweOuter or NOTE_W), DWE.RoundMinScale(), 2) or Clamp(w / NOTE_W, 0.6, 2)
            sc = math.floor(sc * 100 + 0.5) / 100
            if DWE.RoundNow() then DialogueWheelE_RoundScale = sc else DialogueWheelE_NoteScale = sc end
            DWE.SetBookScale(sc, true)
            DWE.SetGripCorner(textBox, "BOTTOMRIGHT")
            -- Stele ronde : pendant le glisser, seulement l'echelle (d'un bloc, sans clignoter) ;
            -- le texte est remis en page au lacher.
            if DWE.RoundNow() then return end
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
    elseif follow.plate then
        -- Meme PNJ, page de dialogue suivante : la liste n'a plus la meme hauteur (ex. garde de
        -- Hurlevent, 12 choix puis "Au revoir" seul), ou la bulle vient d'apparaitre ou de
        -- disparaitre. La roue se replace selon la liste actuelle, pas celle du debut.
        local h, b = DWE.WheelAnchorKey()
        if h ~= follow.wheelH or b ~= follow.bubbleOn then pcall(AnchorTo, follow.plate) end
    end
    -- Le jeu remet l'opacite de certaines plaques apres leur apparition : on les recache a
    -- chaque image (sinon elles se voyaient une demi-seconde a l'entree en conversation).
    pcall(MaskFriendlyPlates)
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
            local okA, errA = pcall(AnchorTo, plate)
            if okA then
                follow.plate = plate
                follow.kept = nil
                DWE.FLog("accroche a " .. tostring(PlateToken(plate)))
            else
                -- Refuse par le jeu : place fixe pour cette conversation (on reessaie a la
                -- suivante ; avant, le suivi restait coupe jusqu'au /reload).
                DWE.followError = tostring(errA)
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
    do
        local okZ, z = pcall(GetCameraZoom)
        DWE.FLog("debut suivi (deja lance=" .. tostring(follower:IsShown()) .. ") | zoom camera="
            .. tostring(okZ and z and string.format("%.2f", z)))
    end
    if not follower:IsShown() then followBroken = false end
    -- Un livre ne suit personne : sinon il s'accrochait au dernier PNJ a qui on avait parle
    -- (bougeait avec la camera, ne se laissait plus deplacer).
    if DWE.bookMode then
        if follower:IsShown() and DWE.StopFollow then DWE.StopFollow() end
        return
    end
    if not AttachEnabled() or followBroken or follower:IsShown() then return end
    follow = {}
    -- Invisible le temps que la plaque apparaisse (1 ou 2 images), pour ne pas sauter.
    choiceBox:SetAlpha(0)
    textBox:SetAlpha(0)
    if DWE.bubble then DWE.bubble:SetAlpha(0) end
    -- Une plaque creee se cache aussitot (avant d'etre dessinee), pas a l'image suivante.
    -- Plaques deja visibles pour le joueur (avant que l'on change ses reglages).
    DWE.plateSeen = nil
    if UnitGUID then
        DWE.plateSeen = {}
        for _, plate in ipairs(GetPlates()) do
            local uf = plate.UnitFrame
            if UsablePlate(plate) and uf and (uf:GetAlpha() or 0) > 0 then
                local okG, g = pcall(UnitGUID, PlateToken(plate))
                if okG and g then pcall(function() DWE.plateSeen[g] = true end) end
            end
        end
        if DWE.followLog then
            local names = {}
            for _, plate in ipairs(GetPlates()) do
                local okN, n = pcall(UnitName, PlateToken(plate) or "")
                local uf = plate.UnitFrame
                names[#names + 1] = tostring(okN and n) .. "(" .. (UsablePlate(plate) and "ok" or "non")
                    .. " a=" .. tostring(uf and uf:GetAlpha()) .. ")"
            end
            DWE.FLog("plaques vues avant : " .. (#names > 0 and table.concat(names, ", ") or "aucune"))
        end
    end
    follower:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    pcall(follower.RegisterEvent, follower, "NAME_PLATE_UNIT_REMOVED")
    pcall(follower.RegisterEvent, follower, "GOSSIP_CLOSED")
    pcall(follower.RegisterEvent, follower, "QUEST_FINISHED")
    pcall(follower.RegisterEvent, follower, "PLAYER_TARGET_CHANGED")
    pcall(StartMeasure)
    SetFriendlyPlates(true)
    pcall(MaskFriendlyPlates)
    follower:Show()
end

local function StopFollow()
    if not follower:IsShown() then return end
    DWE.FLog("fin suivi")
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
    pcall(follower.UnregisterEvent, follower, "NAME_PLATE_UNIT_REMOVED")
    pcall(follower.UnregisterEvent, follower, "GOSSIP_CLOSED")
    pcall(follower.UnregisterEvent, follower, "QUEST_FINISHED")
    pcall(follower.UnregisterEvent, follower, "PLAYER_TARGET_CHANGED")
    if savedPlateCVar or DWE.savedShowAll or DWE.softSaved then SetFriendlyPlates(false) else UnmaskPlates() end
end
DWE.StopFollow = StopFollow

choiceBox:HookScript("OnShow", StartFollow)
-- Fermeture : on attend un instant, car le jeu enchaine souvent deux ecrans (gossip puis
-- quete). Arreter puis relancer retirait les plaques et la roue se decrochait.
-- Fermeture : on attend un instant avant d'arreter le suivi. Le jeu enchaine souvent deux ecrans
-- (gossip puis quete) : arreter puis relancer coupait et remettait les plaques amicales, et le jeu
-- retirait la plaque du PNJ 0,3 s plus tard (roue decrochee, a la manette).
choiceBox:HookScript("OnHide", function()
    if not (C_Timer and C_Timer.After) then StopFollow() return end
    C_Timer.After(0.3, function()
        if not choiceBox:IsShown() then StopFollow() end
    end)
end)

-- Filet : a chaque ecran de conversation, si la roue est la mais que le suivi ne tourne pas
-- (ecran enchaine sans OnShow), on le relance. On retient aussi le PNJ tant qu'il existe.
do
    local watch = CreateFrame("Frame")
    for _, e in ipairs({ "GOSSIP_SHOW", "QUEST_GREETING", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE" }) do
        pcall(watch.RegisterEvent, watch, e)
    end
    local function Ensure()
        if choiceBox:IsShown() and not follower:IsShown() and AttachEnabled() then
            DWE.followRestarts = (DWE.followRestarts or 0) + 1
            StartFollow()
        end
    end
    DWE.EnsureFollow = Ensure
    watch:SetScript("OnEvent", function()
        pcall(DWE.RememberNPC)
        if C_Timer and C_Timer.After then C_Timer.After(0, Ensure) C_Timer.After(0.3, Ensure) else Ensure() end
    end)
end
function DWE.FollowerRunning() return follower:IsShown() end

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
DWE.optionRows = optionRows -- (diagnostic /storytale pixels)

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
for id, c in pairs(DWE.WHISPER_COLORS) do
    PILL_TEX[id] = { normal = "Pill" .. c.art, selected = "Pill" .. c.art .. "Sel" }
end
-- Personnalise : remplissage teinte + contour teinte (calque au-dessus).
PILL_TEX.custom = { normal = "PillCustomFill", selected = "PillCustomFill", edge = "PillCustomEdge", edgeSel = "PillCustomSelEdge" }

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
    local tex = PILL_TEX[style]
    local suffix = shape.suffix .. (mirror and "R" or "")
    local function Place(t, name)
        if t.dweTexPath ~= name then
            t.dweTexPath = name
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
        if t.dweShape ~= shapeKey then
            t.dweShape = shapeKey
            t:ClearAllPoints()
            if mirror then
                t:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
                t:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", shape.left, -shape.bottom)
            else
                t:SetPoint("TOPLEFT", frame, "TOPLEFT", -shape.left, 0)
                t:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, -shape.bottom)
            end
        end
        -- Opacite du fond (option) : la bulle du choix, pas son texte.
        t:SetAlpha(tonumber(DialogueWheelE_Opacity) or 1)
        t:Show()
    end
    -- GW2 UI installe : chaque choix dans une vraie bulle de GW2 UI (sans encoche, comme elles).
    if DWE.Gw2Native(style) then
        frame.dweTex:Hide()
        if frame.dweEdge then frame.dweEdge:Hide() end
        if not frame.dweGw2 then frame.dweGw2 = DWE.Gw2Decor(frame, "BACKGROUND", -6) end
        DWE.Gw2Place(frame.dweGw2, frame, 0, 0, 0, 0, true)
        -- Surligne : bords dores (GW2 UI teinte ses bords), fond a pleine lumiere.
        DWE.Gw2Color(frame.dweGw2, selected and 1 or 0.78, selected and { 1, 0.82, 0.42 } or nil,
            tonumber(DialogueWheelE_Opacity) or 1)
        frame.dweTexPath, frame.dweShape = nil, nil
        return
    end
    if frame.dweGw2 then DWE.Gw2Hide(frame.dweGw2) end
    local t = frame.dweTex
    Place(t, tex[selected and "selected" or "normal"] .. suffix)
    frame.dweTexPath, frame.dweShape = t.dweTexPath, t.dweShape
    -- (Dans le jeu, l'alpha de la couleur de sommet EST l'alpha de la texture : l'opacite
    -- choisie doit donc y etre, sinon SetVertexColor l'efface.)
    local op = tonumber(DialogueWheelE_Opacity) or 1
    if tex.edge then
        -- Personnalise : fond et contour dans les couleurs choisies.
        if not frame.dweEdge then frame.dweEdge = frame:CreateTexture(nil, "BORDER") end
        local bg = DWE.CustomColor("bg")
        local ec = DWE.CustomColor(selected and "sel" or "border")
        t:SetVertexColor(bg[1], bg[2], bg[3], DWE.CUSTOM_FILL_ALPHA * op)
        Place(frame.dweEdge, (selected and tex.edgeSel or tex.edge) .. suffix)
        frame.dweEdge:SetVertexColor(ec[1], ec[2], ec[3], op)
    else
        t:SetVertexColor(1, 1, 1, op)
        if frame.dweEdge then frame.dweEdge:Hide() end
    end
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

-- Icone d'une option : planche (atlas) ou decoupe recopiees de la fenetre du jeu, sinon fichier.
function DWE.SetOptionIcon(t, opt)
    if opt.iconAtlas and t.SetAtlas and pcall(t.SetAtlas, t, opt.iconAtlas) then return end
    t:SetTexture(opt.icon)
    local c = opt.iconCoords
    if c then t:SetTexCoord(c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8])
    else t:SetTexCoord(0, 1, 0, 1) end
end

-- Libelle d'un choix, precede de son numero quand les touches 1 a 9 le choisissent (comme
-- DialogueUI) ; pas de numero a la manette ni dans un livre.
-- Le numero prend la couleur du texte du choix, adoucie (melee a un gris moyen) : en retrait,
-- mais accorde a chaque theme ; gris neutre si la couleur n'est pas encore connue (mesures).
-- Numero d'un choix : son rang dans la liste (1 a 9, comme DialogueUI), ou, avec l'option
-- « numeroter les choix a l'ecran », son rang parmi les choix visibles (les longues listes,
-- comme celle des gardes, ont alors un numero pour chaque choix montre).
function DWE.ChoiceNumber(i)
    if not i or DialogueWheelE_NumberKeys == false or DWE.bookMode then return nil end
    if DWE.PadInUse and DWE.PadInUse() then return nil end
    local n = i
    if DialogueWheelE_NumberVisible ~= false then n = i - (DWE.wheelFirst or 1) + 1 end
    if n >= 1 and n <= 9 then return n end
end
function DWE.NumberIntensity()
    local v = tonumber(DialogueWheelE_NumberIntensity)
    if not v and DialogueWheelE_NumberBright == true then v = 100 end -- (ancienne case)
    return math.max(20, math.min(100, v or 60))
end
function DWE.ChoiceForNumber(n)
    if DialogueWheelE_NumberVisible ~= false then return (DWE.wheelFirst or 1) + n - 1 end
    return n
end

-- Libelle pour MESURER la largeur de la roue : avec les numeros actifs, chaque choix compte
-- la place d'un numero, qu'il en ait un a l'instant ou non. Sinon, quand les numeros suivent le
-- defilement, la roue changeait de largeur a chaque cran (video du 26/11).
function DWE.ChoiceMeasureLabel(opt)
    local label = opt.rawLabel or opt.label or ""
    if DWE.ChoiceNumber(1) or (DialogueWheelE_NumberVisible ~= false and DWE.ChoiceNumber(DWE.wheelFirst or 1)) then
        return "9. " .. label
    end
    return label
end

function DWE.ChoiceLabel(opt, i, color)
    local label = opt.rawLabel or opt.label or ""
    i = DWE.ChoiceNumber(i)
    if i then
        local hex = "8c8c8c"
        if type(color) == "table" and color[1] then
            -- Intensite des numeros (curseur, 20 a 100 %) : 100 % = la couleur du texte telle
            -- quelle ; moins = melee a un gris moyen, plus discrete (60 % par defaut).
            local k = DWE.NumberIntensity() / 100
            local function c(v) return math.floor(math.max(0, math.min(1, (v or 0.5) * k + 0.5 * (1 - k))) * 255 + 0.5) end
            hex = string.format("%02x%02x%02x", c(color[1]), c(color[2]), c(color[3]))
        end
        return "|cff" .. hex .. i .. ".|r " .. label
    end
    return label
end

local function PaintRow(row, opt, selected, pillWidth, index)
    local pill = DWE.WheelPillStyle()
    local pad = pill and PILL_PAD or ROW_PAD
    if opt.icon then
        DWE.SetOptionIcon(row.icon, opt)
        local ic = opt.iconColor
        row.icon:SetVertexColor(ic and ic[1] or 1, ic and ic[2] or 1, ic and ic[3] or 1)
        row.icon:ClearAllPoints()
        row.icon:SetPoint("TOPLEFT", row, "TOPLEFT", pad.left, -pad.iconTop)
        row.icon:Show()
        row.text:SetPoint("TOPLEFT", row, "TOPLEFT", pad.iconLeft, -pad.top)
    else
        row.icon:Hide()
        row.text:SetPoint("TOPLEFT", row, "TOPLEFT", pad.left, -pad.top)
    end
    row.text:SetPoint("TOPRIGHT", row, "TOPRIGHT", -pad.right, -pad.top)
    row.text:SetText(DWE.ChoiceLabel(opt, index))

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
    -- (numero du choix : maintenant que la couleur du texte est connue)
    row.text:SetText(DWE.ChoiceLabel(opt, index, color))
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
function DWE.RoundBar(owner, layer, w)
    w = w or 6
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

-- Barre de defilement : un simple indicateur, fin et discret, a l'ecart des choix. Elle
-- s'affirme au survol, pendant un glisser ou un defilement.
DWE.SCROLL_BAR = { w = 3, edge = 4, gap = 18, out = 8, len = 0.5 }
local scrollTrack = CreateFrame("Frame", nil, choiceBox)
scrollTrack:SetWidth(DWE.SCROLL_BAR.w)
scrollTrack:SetPoint("TOPRIGHT", choiceBox, "TOPRIGHT", -3, -20)
scrollTrack:SetPoint("BOTTOMRIGHT", choiceBox, "BOTTOMRIGHT", -3, 20)
scrollTrack.bg = DWE.RoundBar(scrollTrack, "BACKGROUND", DWE.SCROLL_BAR.w)
scrollTrack.bg:SetColorTexture(1, 1, 1, 0.10)
scrollTrack:Hide()

local scrollThumb = CreateFrame("Button", nil, scrollTrack)
scrollThumb:SetWidth(DWE.SCROLL_BAR.w)
scrollThumb.tex = DWE.RoundBar(scrollThumb, "ARTWORK", DWE.SCROLL_BAR.w)
scrollThumb.tex:SetColorTexture(1, 0.82, 0.3, 0.75)
scrollThumb:SetHitRectInsets(-8, -8, -4, -4) -- fine a l'oeil, facile a attraper
scrollThumb:RegisterForClicks("LeftButtonUp")

local function TrackSizes()
    local okH, h = pcall(scrollTrack.GetHeight, scrollTrack)
    h = (okH and type(h) == "number" and h > 0) and h or 100
    -- Curseur court : un repere, pas une barre (la moitie de sa taille proportionnelle).
    local th = math.max(14, h * scroll.view / math.max(scroll.view, scroll.view + scroll.max) * DWE.SCROLL_BAR.len)
    return h, th
end

local function PositionRows()
    for i, row in ipairs(optionRows) do
        local top, h = scroll.tops[i], scroll.heights[i]
        if top and DWE.currentOptions[i] then
            local y = DWE.PixelRound(listClip, -(top - scroll.px))
            row:ClearAllPoints()
            -- Roue a gauche du PNJ : encoches a droite et barre de defilement a gauche (miroir).
            local barGap = scroll.active and DWE.SCROLL_BAR.gap or 4
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
    local busy = scrollThumb.dragY or scrollThumb.dweHover or (DWE.scrollAnim and DWE.scrollAnim:IsShown()) or DWE.listDragging
    local k = busy and 1 or 0.6
    DWE.scrollBusy = busy and true or false
    if skin and skin.palette == WHEEL_INK then
        -- Bulles claires (Bulle enluminee...) : cuivre de la surbrillance.
        local ink = WHEEL_INK.selected
        c = ink
        scrollThumb.tex:SetColorTexture(ink[1], ink[2], ink[3], 0.75 * k)
        scrollTrack.bg:SetColorTexture(ink[1], ink[2], ink[3], 0.07)
    elseif not DWE.WheelThemeId() then
        -- Pas de bloc de theme (Bulle d'Azeroth...) : barre claire tres translucide, discrete.
        scrollThumb.tex:SetColorTexture(0.85, 0.82, 0.75, 0.5 * k)
        scrollTrack.bg:SetColorTexture(1, 1, 1, 0.04)
    else
        scrollThumb.tex:SetColorTexture(c[1], c[2], c[3], 0.8 * k)
        scrollTrack.bg:SetColorTexture(n[1], n[2], n[3], pal.shadow == 0 and 0.10 or 0.06)
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
DWE.scrollAnim = CreateFrame("Frame")
local scrollAnim = DWE.scrollAnim
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
    PositionRows()
end)
scrollThumb:SetScript("OnEnter", function(self) self.dweHover = true PositionRows() end)
scrollThumb:SetScript("OnLeave", function(self) self.dweHover = nil PositionRows() end)
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
                    row.text:SetText(DWE.ChoiceMeasureLabel(opt))
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
                row.text:SetText(DWE.ChoiceMeasureLabel(opt))
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
    DWE.SizeQuestInfo()

    local pill = DWE.WheelPillStyle()
    local gap = pill and 6 or 5
    local tops, heights = {}, {}
    local yy = 0
    for i, opt in ipairs(DWE.currentOptions) do
        local row = DWE.GetRow(i)
        PaintRow(row, opt, i == DWE.selectedIndex, pillWidth, i)
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
    topPad = DWE.PixelRound(choiceBox, topPad) -- (choix sur des pixels entiers, voir SnapToPixels)
    listClip:SetPoint("TOPLEFT", choiceBox, "TOPLEFT", mirrored and 0 or -LIST_PAD, -topPad)
    listClip:SetPoint("TOPRIGHT", choiceBox, "TOPRIGHT", mirrored and LIST_PAD or 0, -topPad)
    listClip:SetHeight(view + (scroll.active and gap - 1 or 12))
    -- Rail de defilement cale exactement sur la zone visible des choix (ne depasse pas).
    scrollTrack:ClearAllPoints()
    -- Choix en bulles : la barre se tient a l'exterieur, a l'ecart des bulles (leur image
    -- deborde de la ligne). Dans un cadre de theme, elle reste dedans, contre le bord.
    local out = DWE.WheelPillStyle() and DWE.SCROLL_BAR.out or nil
    if mirrored then
        if out then scrollTrack:SetPoint("TOPRIGHT", choiceBox, "TOPLEFT", -out, -topPad - 3)
        else scrollTrack:SetPoint("TOPLEFT", choiceBox, "TOPLEFT", DWE.SCROLL_BAR.edge, -topPad - 3) end
    else
        if out then scrollTrack:SetPoint("TOPLEFT", choiceBox, "TOPRIGHT", out, -topPad - 3)
        else scrollTrack:SetPoint("TOPRIGHT", choiceBox, "TOPRIGHT", -DWE.SCROLL_BAR.edge, -topPad - 3) end
    end
    -- Rail sur toute la hauteur des choix : le curseur va d'un bout a l'autre de la liste.
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
            if DWE.LagMark then DWE.LagMark(opt.rawLabel or opt.label) end
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
DWE.rewardButtonsList = rewardButtons

function DWE.HideRewardButtons()
    DWE.hoveredRewardBtn = nil
    reqHeader:Hide()
    chooseHeader:Hide()
    for _, b in ipairs(rewardButtons) do b:Hide() end
end

local ShowRewardTooltipUnsafe

-- Protege : la roue peut etre accrochee a une plaque de nom, ou le jeu limite les mesures.
-- tip : la fiche a remplir (GameTooltip par defaut ; la manette a la sienne).
-- offscreen : fiche remplie hors de l'ecran, sans l'accrocher au bouton (lecture seule). La roue
-- peut suivre une plaque de nom : tout ce qui s'y accroche ne peut plus etre mesure, et la
-- comparaison du jeu (qui mesure sa fiche) echouait.
function DWE.ShowRewardTooltip(btn, tip, offscreen)
    if btn then pcall(ShowRewardTooltipUnsafe, btn, tip or GameTooltip, offscreen) end
end

function ShowRewardTooltipUnsafe(btn, tip, offscreen)
    if offscreen then
        tip:SetOwner(UIParent, "ANCHOR_NONE")
        tip:ClearAllPoints()
        tip:SetPoint("TOPLEFT", UIParent, "BOTTOMRIGHT", 200, -200)
    else
        tip:SetOwner(btn, "ANCHOR_RIGHT")
    end
    if btn.isDarkmoonTicket then
        if tip.SetCurrencyByID then
            tip:SetCurrencyByID(515)
        else
            tip:SetHyperlink("currency:515")
        end
    elseif btn.itemType and btn.itemIndex then
        tip:SetQuestItem(btn.itemType, btn.itemIndex)
    elseif btn.itemLink then
        tip:SetHyperlink(btn.itemLink)
    end
    tip:Show()
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
            -- Comme un lien du chat : la partie "item:..." seule. Recliquer referme la fiche
            -- (avec le lien complet, le jeu la reecrivait au lieu de la fermer).
            local ref = self.itemLink:match("|H(item:[^|]+)|h") or self.itemLink
            local tip = rawget(_G, "ItemRefTooltip")
            if tip and tip:IsShown() and tip.dweRef == ref then
                tip:Hide()
                return
            end
            SetItemRef(ref, self.itemLink, button)
            if tip then
                tip.dweRef = ref
                if not tip.dweRefHook then
                    tip.dweRefHook = true
                    tip:HookScript("OnHide", function(t) t.dweRef = nil end)
                    -- Un autre lien ouvert dans la meme fiche (chat) : ce n'est plus le notre.
                    hooksecurefunc(tip, "SetHyperlink", function(t, l) if l ~= t.dweRef then t.dweRef = nil end end)
                end
            end
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
DWE.questHost = CreateFrame("Frame", nil, choiceBox)
DWE.questHost:SetFrameLevel(choiceBox:GetFrameLevel())
DWE.questHost:Hide()
DWE.MakeResizeGrip(DWE.questHost, {
    get = function() return objLine:GetWidth() or DWE.QUEST_MIN_W, 0 end,
    set = function(w)
        if DialogueWheelE_QuestAuto ~= false then return end
        DialogueWheelE_QuestWidth = math.floor(math.max(220, math.min(700, w)))
        DWE.SizeQuestInfo()
    end,
    done = function() DWE.UpdateVisuals() end,
})
-- Le cadre de la poignee ne doit pas capter la souris (infobulles des objets, choix de recompense).
if DWE.questHost.EnableMouse then DWE.questHost:EnableMouse(false) end
if DWE.questHost.SetMouseMotionEnabled then DWE.questHost:SetMouseMotionEnabled(false) end
if DWE.questHost.SetMouseClickEnabled then DWE.questHost:SetMouseClickEnabled(false) end
local previewPanel = CreateFrame("Frame", nil, choiceBox, "BackdropTemplate")
previewPanel:SetFrameLevel(choiceBox:GetFrameLevel())
previewPanel:EnableMouse(false)
previewPanel:Hide()

function DWE.PaintWheelTheme()
    local bottom = DWE.wheelBottom or choiceBox
    -- Apercu de quete plus large que la roue : le cadre englobe sa largeur.
    local quest = bottom ~= choiceBox
    local left = DWE.WheelLeft and DWE.WheelLeft()
    -- Apercu plus etroit que la roue (centre dessous) : le cadre suit la roue.
    local wide = quest and (objLine:GetWidth() or 0) > (choiceBox:GetWidth() or 0)
    wheelArea:ClearAllPoints()
    wheelArea:SetPoint("TOP", choiceBox, "TOP", 0, 0)
    if wide and left then
        wheelArea:SetPoint("LEFT", objLine, "LEFT", -6, 0)
    else
        wheelArea:SetPoint("LEFT", choiceBox, "LEFT", 0, 0)
    end
    if wide and not left then
        wheelArea:SetPoint("RIGHT", objLine, "RIGHT", 4, 0)
    else
        wheelArea:SetPoint("RIGHT", choiceBox, "RIGHT", 0, 0)
    end
    wheelArea:SetPoint("BOTTOM", bottom, "BOTTOM", 0, quest and -4 or 0)
    local id = DWE.WheelThemeId()
    if id then
        PaintThemeParts(wheelParts, wheelArea, nil, id)
    else
        ClearThemeParts(wheelParts)
    end
    local pill = DWE.WheelPillStyle()
    -- Zone de l'apercu de quete (porte sa propre poignee de largeur).
    local qh = DWE.questHost
    if quest then
        qh:ClearAllPoints()
        qh:SetPoint("TOP", choiceBox, "BOTTOM", 0, -6)
        qh:SetPoint("LEFT", objLine, "LEFT", -14, 0)
        qh:SetPoint("RIGHT", objLine, "RIGHT", 12, 0)
        qh:SetPoint("BOTTOM", bottom, "BOTTOM", 0, -14)
        qh:Show()
        qh.dweGripLeft = left or nil
        DWE.SetGripCorner(qh, "TOPLEFT")
    else
        qh:Hide()
    end
    if pill and bottom ~= choiceBox then
        SkinPill(previewPanel, pill, false, false) -- cadre d'apercu : pas d'encoche de dialogue
        -- Plus sombre et plus discret que les choix : on voit que ce n'est pas un bouton. Sur
        -- un fond clair (encre foncee), a peine : sinon le parchemin vire au gris et l'encre ne
        -- se lit plus.
        if previewPanel.dweTex then
            local k = pill == "custom" and DWE.CustomColor("bg") or { 1, 1, 1 }
            local sk = DWE.BubbleSkin and DWE.BubbleSkin()
            local f = (sk and sk.palette == WHEEL_INK) and 0.88 or 0.62
            DWE.previewShade = f
            previewPanel.dweTex:SetVertexColor(f * k[1], f * k[2], f * k[3])
            previewPanel.dweTex:SetAlpha(0.85 * (tonumber(DialogueWheelE_Opacity) or 1))
        end
        previewPanel:ClearAllPoints()
        previewPanel:SetPoint("TOP", choiceBox, "BOTTOM", 0, -6)
        previewPanel:SetPoint("LEFT", objLine, "LEFT", -14, 0)
        previewPanel:SetPoint("RIGHT", objLine, "RIGHT", 12, 0)
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
        if sharer.dweEdge then sharer.dweEdge:Hide() end
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
    if DWE.ApplyDUIConv then DWE.ApplyDUIConv() end
    DWE.ApplyTextTheme()
    DWE.ApplyFont()
    DWE.RefreshSpoken()
    if choiceBox:IsShown() then
        -- Bulle ou cadre du texte du PNJ : change aussi, dialogue ouvert (theme essaye en direct).
        -- La bulle est redessinee de zero, sans garder de morceaux de l'ancien theme.
        if DWE.Bubble and DWE.Bubble.Restyle then
            DWE.Bubble.Restyle()
            DWE.Bubble.SetShown(false)
        end
        DWE.UpdateVisuals()
        DWE.UpdateTextPanelVisuals()
        if DWE.Bubble and DWE.Bubble.Refit then DWE.Bubble.Refit() end
        -- (theme Cinematique choisi ou quitte : bandes noires et interface tout de suite)
        if DWE.UpdateCinemaBars then DWE.UpdateCinemaBars() end
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
DWE.KeyLabel = KeyLabel

-- Themes proposes dans les options, par famille, avec leur vignette (Thumbs\*.png).
local THEME_LIST = {
    { id = "bubble", key = "THEME_BUBBLE", thumb = "Bubble" },
    { id = "bubble_npc", key = "THEME_BUBBLE_NPC", thumb = "BubbleNPC" },
    { id = "bubble_fantasy", key = "THEME_BUBBLE_FANTASY", thumb = "BubbleFantasy" },
    { id = "whisper", key = "THEME_WHISPER", thumb = "Whisper" },
    { id = "emerald", key = "THEME_EMERALD", thumb = "Emerald" },
    { id = "ruby", key = "THEME_RUBY", thumb = "Ruby" },
    { id = "sapphire", key = "THEME_SAPPHIRE", thumb = "Sapphire" },
    { id = "amber", key = "THEME_AMBER", thumb = "Amber" },
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
    { id = "custom", key = "THEME_CUSTOM", thumb = "Custom" },
}
-- Themes DialogueUI : seulement avec DialogueUI installe (images lues dans son dossier).
-- GW2 UI : son theme seulement s'il est charge (un profil qui l'a deja garde son theme).
if DWE.GW2_ON then DWE.AddGw2Theme(THEME_LIST) end
if DWE.DUI_ON then
    -- La vraie interface de DialogueUI (brun ou sombre selon ses propres options).
    THEME_LIST[#THEME_LIST + 1] = { id = "dui", key = "THEME_DUI", thumbTex = DWE.DUI_ART .. "Theme_Brown\\Parchment.png", thumbCoord = { 0.22, 0.78, 0.14, 0.34 } }
end
DWE.THEME_LIST = THEME_LIST

-- Options remises a zero : toutes les variables sauvegardees sauf la liste des livres/PNJ
-- deja entendus avec Spoken (ce n'est pas un reglage).
-- (Liste en une chaine : un gros tableau ecrit d'un coup depasse la pile du chunk en Lua 5.1.)
DWE.OPTION_VARS = {}
for k in ("Pos TextPos Theme Font FontSize Opacity ShowText UseBlizzKey InteractKey ToggleKey WheelScroll SpokenTheme AttachNPC NPCOffset WheelWidth TextW TextH BubbleWidth Locked WheelTheme EscClose BookStyle ThemeFrames BookLook BookPos BookScale NoteScale QuestWidth QuestAuto PlaceSkin SpokenButton SpokenSkin SpokenStyleChosen BookSkin PlateSkin ChoiceSize WheelSide PlateStyle PlateLook ReadMarks BookTipCursor BookAutoScroll BookHighlight BookTurnFX BookVoiceTurn BookStopOnClose BookVoiceOff SpokenSmart BubbleHighlight BubbleMode CustomColors HideUI ZoneArt ZoneArtPaper MinimapHide DefaultsV RoundScale RoundPos NumberKeys NumberVisible NumberBright NumberIntensity"):gmatch("%S+") do DWE.OPTION_VARS[#DWE.OPTION_VARS + 1] = k end
function DWE.ResetAllOptions()
    for _, k in ipairs(DWE.OPTION_VARS) do _G["DialogueWheelE_" .. k] = nil end
    if DWE.ResetSpokenPlace then pcall(DWE.ResetSpokenPlace) end
    DWE.SettingsChanged()
end
-- Fenetre de confirmation de Storytale (a la place de StaticPopup) : une StaticPopup ouverte par
-- un addon est enregistree dans la navigation manette du jeu au nom de l'addon ; a "Oui", la
-- manette du jeu etait bloquee ("Interface action failed", ex. "Default all"). Celle-ci n'est pas
-- connue du jeu : souris, Entree / Echap, et manette (A valider, B annuler, croix gauche/droite).
-- opts = { text, arg, yes, no, edit (texte de depart ou true), maxLetters, onAccept(text) }
function DWE.Ask(opts)
    local f = DWE.askFrame
    if not f then
        f = CreateFrame("Frame", "StorytaleAskFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
        DWE.askFrame = f
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:SetToplevel(true)
        f:SetSize(360, 120)
        f:SetPoint("TOP", UIParent, "TOP", 0, -160)
        f:EnableMouse(true)
        if f.SetBackdrop then
            f:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32,
                insets = { left = 11, right = 12, top = 12, bottom = 11 } })
        end
        f.text = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        f.text:SetPoint("TOP", 0, -22)
        f.text:SetWidth(320)
        f.edit = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
        f.edit:SetSize(240, 22)
        f.edit:SetAutoFocus(false)
        f.edit:SetPoint("TOP", f.text, "BOTTOM", 0, -10)
        f.yes = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        f.no = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        f.yes:SetSize(120, 22); f.no:SetSize(120, 22)
        f.yes:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -6, 16)
        f.no:SetPoint("BOTTOMLEFT", f, "BOTTOM", 6, 16)
        local function Done(ok)
            local cb, txt = f.onAccept, f.edit:IsShown() and f.edit:GetText() or nil
            f.onAccept, f.onKey = nil, nil
            f:Hide()
            if ok and cb then cb(txt) end
        end
        f.Done = Done
        f.yes:SetScript("OnClick", function() Done(true) end)
        f.no:SetScript("OnClick", function() Done(false) end)
        f.edit:SetScript("OnEnterPressed", function() Done(true) end)
        f.edit:SetScript("OnEscapePressed", function() Done(false) end)
        local function Pick(i)
            f.sel = i
            if f.yes.LockHighlight then
                if i == 1 then f.yes:LockHighlight(); f.no:UnlockHighlight() else f.no:LockHighlight(); f.yes:UnlockHighlight() end
            end
        end
        f.Pick = Pick
        f:EnableKeyboard(true)
        f:SetScript("OnKeyDown", function(self, key)
            -- Choix d'une touche : la prochaine touche pressee (avec Maj/Ctrl/Alt) ; Echap = aucune.
            if f.onKey then
                if self.SetPropagateKeyboardInput and not InCombatLockdown() then pcall(self.SetPropagateKeyboardInput, self, false) end
                if MODIFIER_KEYS[key] then return end
                local cb = f.onKey
                f.onKey = nil
                f:Hide()
                if key == "ESCAPE" then
                    cb("")
                else
                    cb((IsShiftKeyDown() and "SHIFT-" or "") .. (IsControlKeyDown() and "CTRL-" or "") .. (IsAltKeyDown() and "ALT-" or "") .. key)
                end
                return
            end
            local mine = key == "ESCAPE" or key == "ENTER"
            if self.SetPropagateKeyboardInput and not InCombatLockdown() then pcall(self.SetPropagateKeyboardInput, self, not mine) end
            if key == "ESCAPE" then Done(false) elseif key == "ENTER" then Done(f.sel ~= 2) end
        end)
        if f.EnableGamePadButton then
            pcall(f.EnableGamePadButton, f, true)
            if f.SetPropagateGamePadInput then pcall(f.SetPropagateGamePadInput, f, false) end
            f:SetScript("OnGamePadButtonDown", function(_, b)
                -- Fenetre d'options ouverte : ses liaisons transmettent deja le bouton (pas deux fois).
                if DWE.OptionsPadActive and DWE.OptionsPadActive() and not f.fromOptions then return end
                if b == "PAD1" then Done(f.sel ~= 2)
                elseif b == "PAD2" then Done(false)
                elseif b == "PADDLEFT" then Pick(1)
                elseif b == "PADDRIGHT" then Pick(2) end
            end)
        end
        f:Hide()
    end
    local text = opts.text or ""
    if opts.arg ~= nil then text = text:format(opts.arg) end
    f.text:SetText(text)
    f.yes:SetText(opts.yes or YES or "Yes")
    f.no:SetText(opts.no or NO or "No")
    f.onAccept = opts.onAccept
    f.onKey = opts.onKey
    -- Choix d'une touche : seulement "Annuler" (la manette ne choisit pas de touche clavier).
    f.yes:SetShown(not opts.onKey)
    f.no:ClearAllPoints()
    if opts.onKey then f.no:SetPoint("BOTTOM", f, "BOTTOM", 0, 16) else f.no:SetPoint("BOTTOMLEFT", f, "BOTTOM", 6, 16) end
    local th = f.text:GetStringHeight() or 14
    if opts.edit then
        f.edit:Show()
        f.edit:SetMaxLetters(opts.maxLetters or 32)
        f.edit:SetText(type(opts.edit) == "string" and opts.edit or "")
        f.edit:HighlightText()
        f:SetHeight(100 + th + 32)
    else
        f.edit:Hide()
        f:SetHeight(100 + th)
    end
    f.Pick(opts.onKey and 2 or 1)
    f:Show()
    f:Raise()
    if opts.edit then f.edit:SetFocus() end
    return f
end

-- Choisir une touche : fenetre "Appuyez sur une touche" ; set(k) recoit la touche ("" = aucune).
function DWE.AskKey(label, current, set)
    local L = DWE.L
    DWE.Ask({ text = (label or "") .. " " .. KeyLabel(current) .. "\n\n" .. (L.KEY_PRESS or ""), no = CANCEL or "Cancel",
        onKey = function(k)
            set(k)
            if DWE.RefreshBindings then DWE.RefreshBindings() end
        end })
end

-- Profils : confirmation (changer, supprimer) ou nom a saisir (nouveau, copie).
function DWE.AskProfile(kind, name)
    local L = DWE.L
    local function Do()
        if kind == "switch" then return DWE.ProfileSwitch(name)
        elseif kind == "copyfrom" then return DWE.ProfileCopyFrom(name)
        elseif kind == "delete" then
            local ok = DWE.ProfileDelete(name)
            if DWE.RefreshProfilesUI then DWE.RefreshProfilesUI() end
            return ok
        end
    end
    if kind == "switch" then return Do() end -- (tout de suite : rien n'est perdu, on peut revenir)
    local confirm = kind == "delete" or kind == "copyfrom"
    if confirm then
        DWE.Ask({ text = (kind == "copyfrom" and L.PROFILE_COPY_CONFIRM) or L.PROFILE_DEL_CONFIRM,
            arg = DWE.ProfileLabel(name), onAccept = function() Do() end })
        return
    end
    local copy = kind == "copy"
    DWE.Ask({ text = copy and L.PROFILE_NAME_COPY or L.PROFILE_NAME_NEW, edit = true, maxLetters = 32,
        yes = ACCEPT or OKAY or "OK", no = CANCEL or "Cancel",
        onAccept = function(text)
            if not DWE.ProfileCreate(text, copy) and UIErrorsFrame and UIErrorsFrame.AddMessage then
                UIErrorsFrame:AddMessage(ERR_NAME_INVALID or "Invalid name", 1, 0.2, 0.2)
            end
        end })
end

-- Valeurs par defaut donnees une fois a l'installation (voir PLAYER_LOGIN) : une page remise
-- a zero les reprend (sans elles, la valeur "vide" n'est pas celle d'une installation).
DWE.INSTALL_DEFAULTS = { WheelTheme = true, FontSize = 14, BookTipCursor = true }
function DWE.ResetPage(vars, noApply)
    for _, k in ipairs(vars or {}) do
        local d = DWE.INSTALL_DEFAULTS[k]
        _G["DialogueWheelE_" .. k] = d
    end
    if not noApply then DWE.SettingsChanged() end
end
-- Tous les reglages viennent de changer (profil, remise a zero) : on applique tout de suite.
-- Chaque case et curseur des options relit sa valeur et rejoue son effet s'il a change ; puis
-- tout ce qui depend des reglages est redessine. Pas de rechargement de l'interface.
function DWE.SettingsChanged()
    if DWE.ApplyInstallDefaults then pcall(DWE.ApplyInstallDefaults) end
    for _, f in ipairs(DWE.optionRefreshers or {}) do pcall(f) end
    -- (couleurs Personnalise d'abord : sinon le theme etait repeint avec celles du profil precedent)
    for _, name in ipairs({ "CustomRefresh", "OnThemeChanged", "ApplyFont", "ApplyBubbleOpacity", "RefreshBindings", "ApplyLock",
        "RestorePosition", "RestoreTextPosition", "Repin", "RefreshSpoken", "ZoneArtRefresh", "MinimapButtonRefresh",
        "RefreshBookLookOptions", "RefreshPlateLookOptions", "TextInRefresh", "RefreshOptionsExtra",
        "RefreshProfilesUI", "NativeRefresh" }) do
        local f = DWE[name]
        if type(f) == "function" then pcall(f) end
    end
    if DialogueWheelE_AttachNPC == false and DWE.StopFollow then pcall(DWE.StopFollow) end
    if DWE.choiceBox and DWE.choiceBox:IsShown() and DWE.UpdateVisuals then pcall(DWE.UpdateVisuals) end
    if DWE.UpdateTextPanelVisuals then pcall(DWE.UpdateTextPanelVisuals) end
end
function DWE.AskResetPage(name, vars)
    DWE.Ask({ text = DWE.L.PAGE_RESET_CONFIRM, arg = name, onAccept = function() DWE.ResetPage(vars) end })
end
function DWE.AskResetAll()
    DWE.Ask({ text = DWE.L.RESET_ALL_CONFIRM,
        arg = DWE.ProfileLabel and DWE.ProfileLabel(DWE.profile or "Default") or "",
        onAccept = function() DWE.ResetAllOptions() end })
end

-- Manette, droite / gauche dans les options : la navigation du jeu prend le plus proche dans un
-- large cone, et descendait souvent sur la ligne du dessous au lieu d'aller a l'option voisine.
-- On lui indique, pour chaque reglage, son voisin sur la meme ligne (ou rien : on reste).
-- (Valeurs que le jeu autorise aux addons hors combat.)
function DWE.OptionsPadRows()
    local set = rawget(_G, "SmartNavigation_AddJumpNavigationOverride")
    local dirs = rawget(_G, "SMART_NAV_INPUT_DIRECTION")
    local scroll = rawget(_G, "DialogueWheelEOptionsScroll")
    local child = scroll and scroll.GetScrollChild and scroll:GetScrollChild()
    -- Categories : la page affichee.
    local page
    for _, pg in ipairs(DWE.optionPages or {}) do
        if pg.panel ~= DWE.optionsPanel and pg.panel:IsVisible() then page = pg; child = pg.child; scroll = pg.scroll end
    end
    if not (set and dirs and dirs.LEFT and dirs.RIGHT and dirs.UP and dirs.DOWN and child) or InCombatLockdown() then return end
    -- Manette : un ordre de lecture fixe, ligne par ligne (la navigation du jeu, laissee seule,
    -- sautait d'une option a l'autre sans ordre sur cette page). Droite / gauche : l'option voisine
    -- de la meme ligne ; bas / haut : l'option la plus proche sur la ligne suivante / precedente.
    local items = {}
    local function Walk(fr)
        for _, c in ipairs({ fr:GetChildren() }) do
            local ok, kind = pcall(c.GetObjectType, c)
            if ok and (kind == "Button" or kind == "CheckButton" or kind == "EditBox") then
                local okE, en = pcall(function() return not c.IsEnabled or c:IsEnabled() ~= false end)
                if c:IsVisible() and okE and en then
                    local x, y = c:GetCenter()
                    if x and y then items[#items + 1] = { f = c, x = x, y = y } end
                end
            elseif ok and c:IsVisible() then
                Walk(c)
            end
        end
    end
    Walk(child)
    table.sort(items, function(u, v) if math.abs(u.y - v.y) > 8 then return u.y > v.y end return u.x < v.x end)
    local rows = {}
    for _, it in ipairs(items) do
        local row = rows[#rows]
        if not row or math.abs(row.y - it.y) > 8 then
            row = { y = it.y }
            rows[#rows + 1] = row
        end
        row[#row + 1] = it
        it.row = #rows
    end
    local function Nearest(row, x)
        local best
        for _, o in ipairs(row or {}) do
            if not best or math.abs(o.x - x) < math.abs(best.x - x) then best = o end
        end
        return best and best.f
    end
    for _, row in ipairs(rows) do
        for i, it in ipairs(row) do
            pcall(set, it.f, dirs.RIGHT, row[i + 1] and row[i + 1].f or true)
            pcall(set, it.f, dirs.LEFT, row[i - 1] and row[i - 1].f or nil)
            -- (Premiere et derniere ligne : on reste sur la page ; sinon la navigation du jeu
            -- partait sur la minicarte ou d'autres boutons a l'ecran.)
            pcall(set, it.f, dirs.DOWN, Nearest(rows[it.row + 1], it.x) or true)
            pcall(set, it.f, dirs.UP, Nearest(rows[it.row - 1], it.x) or true)
            -- L'option choisie a la manette reste dans la vue (la page defile jusqu'a elle).
            if not it.f.dweScrollHook and scroll and scroll.GetTop then
                it.f.dweScrollHook = true
                local sc, f = scroll, it.f
                f:HookScript("OnEnter", function()
                    local top, bottom, sTop, sBottom = f:GetTop(), f:GetBottom(), sc:GetTop(), sc:GetBottom()
                    if not (top and bottom and sTop and sBottom) then return end
                    local cur, range = sc:GetVerticalScroll() or 0, sc:GetVerticalScrollRange() or 0
                    if top > sTop - 4 then
                        sc:SetVerticalScroll(math.max(0, cur - (top - sTop) - 12))
                    elseif bottom < sBottom + 4 then
                        sc:SetVerticalScroll(math.min(range, cur + (sBottom - bottom) + 12))
                    end
                end)
            end
        end
    end
end

function DWE.InitOptionsPanel()
    if DWE.optionsPanel then return end
    local panel = CreateFrame("Frame", "DialogueWheelEOptionsPanel")
    panel.name = "Storytale"
    DWE.optionsPanel = panel
    -- Bouton vers la fenetre d'options de Storytale (faite pour la manette).

    -- Tout le contenu defile (le panneau est plus haut que la fenetre des options).
    local scroll = CreateFrame("ScrollFrame", "DialogueWheelEOptionsScroll", panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -34) -- au-dessus : la recherche, toujours visible
    scroll:SetPoint("BOTTOMRIGHT", -28, 4)
    local p = CreateFrame("Frame", nil, scroll)
    p:SetSize(600, 1100)
    scroll:SetScrollChild(p)

    -- Categories (comme Spoken) : la page principale, puis une sous-page par groupe de reglages.
    -- Les reglages gardent leurs positions d'origine : chaque sous-page decale son contenu pour
    -- que sa section commence en haut. `p` (ou tout se construit) passe d'une page a l'autre.
    local pages = { { panel = panel, scroll = scroll, child = p, top = 0 } }
    DWE.optionPages = pages
    local function NewPage(name, sectionY)
        local last = pages[#pages]
        last.child:SetHeight((last.top or 0) - sectionY + 20)
        local sub = CreateFrame("Frame")
        sub.name, sub.parent = name, panel.name
        sub:Hide()
        local sc = CreateFrame("ScrollFrame", nil, sub, "UIPanelScrollFrameTemplate")
        sc:SetPoint("TOPLEFT", 0, -34)
        sc:SetPoint("BOTTOMRIGHT", -28, 4)
        local child = CreateFrame("Frame", nil, sc)
        child:SetSize(600, 400)
        sc:SetScrollChild(child)
        local content = CreateFrame("Frame", nil, child)
        content:SetSize(600, 10)
        content:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -12 - sectionY)
        pages[#pages + 1] = { panel = sub, scroll = sc, child = child, content = content, top = sectionY - 12 }
        p = content
        return sub
    end

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

    -- Precisions des options (infobulle au survol) : texte court a l'ecran, details ici.
    local TIP_OF = {}
    for _, k in ipairs({ "LOCK", "READ_MARKS", "BOOK_TIP_CURSOR", "BOOK_AUTOSCROLL", "QUEST_AUTO_W",
        "THEME_BUBBLES", "SPOKEN_BUTTON", "ZONE_ART", "BUBBLE_HIGHLIGHT", "BUBBLE_MODE_TYPE", "BUBBLE_MODE_PAGE" }) do
        if L[k] and L[k .. "_TIP"] then TIP_OF[L[k]] = L[k .. "_TIP"] end
    end
    -- Chaque reglage sait relire sa valeur (profil change, page remise a zero) : il se remet a
    -- jour et, s'il a change, rejoue son clic pour appliquer l'effet, comme si le joueur l'avait fait.
    local refreshers = {}
    DWE.optionRefreshers = refreshers
    local function AddCheck(label, x, y, checked, onClick)
        local cb = CreateFrame("CheckButton", nil, p, CHECK_TEMPLATE)
        cb:SetPoint("TOPLEFT", x, y)
        cb.Text:SetText(label)
        local get = type(checked) == "function" and checked or nil
        cb:SetChecked((get and get() or (not get and checked)) and true or false)
        cb:SetScript("OnClick", onClick)
        if get then
            refreshers[#refreshers + 1] = function()
                local want = get() and true or false
                if (cb:GetChecked() and true or false) ~= want then
                    cb:SetChecked(want)
                    local fn = cb:GetScript("OnClick")
                    if fn then pcall(fn, cb) end
                end
            end
        end
        local tip = TIP_OF[label]
        if tip then
            cb.tooltipText = tip
            cb:HookScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(label, 1, 0.82, 0)
                GameTooltip:AddLine(tip, 1, 1, 1, true)
                GameTooltip:Show()
            end)
            cb:HookScript("OnLeave", function() GameTooltip:Hide() end)
        end
        return cb
    end

    -- Groupe de cases a cocher exclusives (une seule cochee), en colonnes.
    local function AddGroup(items, x, startY, step, current, onPick, perColumn, colWidth)
        local list = {}
        local get = type(current) == "function" and current or nil
        if get then current = get() end
        if get then
            refreshers[#refreshers + 1] = function()
                local want = get()
                local changed = false
                for i, info in ipairs(items) do
                    local on = info.id == want
                    if list[i] and (list[i]:GetChecked() and true or false) ~= on then
                        list[i]:SetChecked(on)
                        changed = true
                    end
                end
                if changed then pcall(onPick, want) end
            end
        end
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
        local get = type(curV) == "function" and curV or nil
        if get then curV = get() end
        local sl = CreateFrame("Slider", name, p, SLIDER_TEMPLATE)
        if get then
            refreshers[#refreshers + 1] = function()
                local want = get()
                if want and math.abs((sl:GetValue() or 0) - want) > 1e-6 then sl:SetValue(want) end
            end
        end
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
        -- Boutons - et + de part et d'autre : la navigation manette du jeu ne s'arrete que sur
        -- des boutons (pas sur un curseur) ; a la souris, ils reglent aussi pas a pas.
        for _, d in ipairs({ -1, 1 }) do
            local b = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
            b:SetSize(20, 18)
            b:SetText(d < 0 and "-" or "+")
            if d < 0 then b:SetPoint("RIGHT", sl, "LEFT", -4, 0) else b:SetPoint("LEFT", sl, "RIGHT", 4, 0) end
            b:SetScript("OnClick", function()
                local v = math.max(minV, math.min(maxV, (sl:GetValue() or curV) + d * step))
                sl:SetValue(v)
            end)
            sl[d < 0 and "dweMinus" or "dwePlus"] = b
        end
        return sl
    end

    AddText("Storytale", 16, -12, "GameFontNormalHuge")

    ---------------------------------------------------------------- Theme
    local y = -52
    AddSection(L.SEC_THEME, y)
    AddText(L.THEME_HINT, 16, y - 30, "GameFontDisableSmall")
    local TILE_W, TILE_H, COLS = 132, 66, 4
    local tiles = {}
    local function RefreshTiles()
        local cur = DialogueWheelE_Theme or "bubble"
        for _, t in ipairs(tiles) do
            local bubbleThumb = DWE.ThemeIsBubble(t.id) and (BUBBLE_SKINS[t.id].art or BUBBLE_SKINS[t.id].custom)
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
    DWE.framesCheck = AddCheck(L.THEME_BUBBLES, 16, y, function() return DialogueWheelE_ThemeFrames ~= true end, function(self)
        DialogueWheelE_ThemeFrames = not self:GetChecked()
        RefreshTiles()
        DWE.OnThemeChanged()
    end)
    y = y - 30
    AddCheck(L.WHEEL_THEME, 16, y, function() return DialogueWheelE_WheelTheme == true end, function(self)
        DialogueWheelE_WheelTheme = self:GetChecked() and true or false
        DWE.OnThemeChanged()
    end)
    -- (« Cacher l'interface » et le bouton de la mini-carte : section Interface, en bas)
    AddSlider("DWESliderOpacity", L.OPACITY_LBL, 22, y - 50, 0.2, 1, 0.05, function() return tonumber(DialogueWheelE_Opacity) or 1 end, "%.2f", function(v)
        DialogueWheelE_Opacity = v
        DWE.OnThemeChanged()
        if DWE.ApplyBubbleOpacity then DWE.ApplyBubbleOpacity() end
        if choiceBox:IsShown() and DWE.UpdateVisuals then DWE.UpdateVisuals() end
    end)

    -- Couleurs du theme Personnalise : 4 pastilles (palette de couleurs du jeu) et un bouton
    -- pour partir des couleurs du theme affiche. Choisir une couleur passe au theme Personnalise.
    y = y - 96
    do
        AddText(L.CUSTOM_COLORS, 16, y, "GameFontHighlightSmall")
        local swatches = {}
        -- Couleur affichee par une pastille ("Mot lu" sans reglage : la couleur automatique).
        local function SwatchColor(key)
            if key ~= "word" then return DWE.CustomColor(key) end
            local c = DWE.CustomWordColor()
            if c then return c end
            local tx = DWE.CustomColor("text")
            if tx[1] * 0.6 + tx[2] * 0.4 > 0.5 then return { 1, 0.82, 0 } end
            return { 0.61, 0.10, 0.10 }
        end
        local function Repaint()
            for _, sw in ipairs(swatches) do
                local c = SwatchColor(sw.key)
                sw.fill:SetColorTexture(c[1], c[2], c[3], 1)
            end
        end
        DWE.CustomOptionsRepaint = Repaint
        local function UseCustom()
            DWE.CustomRefresh()
            if DialogueWheelE_Theme ~= "custom" then DialogueWheelE_Theme = "custom" end
            RefreshTiles()
            DWE.OnThemeChanged()
            if choiceBox:IsShown() and DWE.UpdateVisuals then DWE.UpdateVisuals() end
            Repaint()
        end
        local function SetColor(key, r, g, b)
            if type(DialogueWheelE_CustomColors) ~= "table" then DialogueWheelE_CustomColors = {} end
            DialogueWheelE_CustomColors[key] = { r, g, b }
            UseCustom()
        end
        local function Pick(key)
            local c = SwatchColor(key)
            local cp = ColorPickerFrame
            if not cp then return end
            local function Now()
                local r, g, b = cp:GetColorRGB()
                SetColor(key, r, g, b)
            end
            local function Undo() SetColor(key, c[1], c[2], c[3]) end
            if cp.SetupColorPickerAndShow then
                cp:SetupColorPickerAndShow({ r = c[1], g = c[2], b = c[3], hasOpacity = false,
                    swatchFunc = Now, cancelFunc = Undo })
            else
                cp.hasOpacity = false
                cp.func, cp.cancelFunc = Now, Undo
                cp.previousValues = { r = c[1], g = c[2], b = c[3] }
                cp:SetColorRGB(c[1], c[2], c[3])
                cp:Hide(); cp:Show()
            end
        end
        local KEYS = { { "bg", L.CUSTOM_BG }, { "border", L.CUSTOM_BORDER }, { "text", L.CUSTOM_TEXT }, { "sel", L.CUSTOM_SEL } }
        -- Couleur du mot lu par la voix : seulement si Spoken est la (5 pastilles plus serrees).
        local withWord = DWE.SpokenFocus and DWE.SpokenFocus.Available and DWE.SpokenFocus.Available()
        if withWord then KEYS[5] = { "word", L.CUSTOM_WORD } end
        local STEP = withWord and 120 or 140
        for i, k in ipairs(KEYS) do
            local b = CreateFrame("Button", nil, p, "BackdropTemplate")
            b.key = k[1]
            b:SetSize(22, 22)
            b:SetPoint("TOPLEFT", 16 + (i - 1) * STEP, y - 20)
            b:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10 })
            b:SetBackdropBorderColor(0.8, 0.8, 0.8, 1)
            b.fill = b:CreateTexture(nil, "ARTWORK")
            b.fill:SetPoint("TOPLEFT", 3, -3)
            b.fill:SetPoint("BOTTOMRIGHT", -3, 3)
            -- Survol : le contour s'eclaire (pas de voile blanc sur la couleur, qui la fausserait).
            b:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(1, 0.82, 0, 1) end)
            b:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(0.8, 0.8, 0.8, 1) end)
            local lbl = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            lbl:SetPoint("LEFT", b, "RIGHT", 6, 0)
            lbl:SetText(k[2])
            if k[1] == "word" then
                -- Clic droit : couleur automatique. Infobulle : a quoi sert cette couleur.
                b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                b:SetScript("OnClick", function(_, button)
                    if button == "RightButton" then
                        if type(DialogueWheelE_CustomColors) == "table" then DialogueWheelE_CustomColors.word = nil end
                        UseCustom()
                    else
                        Pick("word")
                    end
                end)
                b:HookScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(L.CUSTOM_WORD, 1, 0.82, 0)
                    GameTooltip:AddLine(L.CUSTOM_WORD_TIP, 1, 1, 1, true)
                    GameTooltip:Show()
                end)
                b:HookScript("OnLeave", function() GameTooltip:Hide() end)
            else
                b:SetScript("OnClick", function() Pick(k[1]) end)
            end
            swatches[i] = b
        end
        local from = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
        from:SetPoint("TOPLEFT", 16, y - 50)
        from:SetText(L.CUSTOM_FROM_THEME)
        -- Largeur selon le texte (langues longues), plafonnee : au-dela, police plus petite.
        do
            local fs = from:GetFontString()
            local w = fs and fs:GetStringWidth() or 220
            if w > 260 and fs then fs:SetFontObject("GameFontNormalSmall"); w = fs:GetStringWidth() end
            from:SetSize(math.min(280, math.max(200, w + 24)), 22)
        end
        from:SetScript("OnClick", function()
            local cur = DialogueWheelE_Theme or "bubble"
            if cur ~= "custom" then DWE.CustomFromTheme(cur) end
            UseCustom()
        end)

        -- Themes enregistres : "Enregistrer" (demande un nom) et une petite liste deroulante.
        local list
        local function Popup(_, text, accept, edit)
            DWE.Ask({ text = text, edit = edit or nil, maxLetters = edit and 40 or nil,
                yes = ACCEPT or OKAY or "OK", no = CANCEL or "Cancel",
                onAccept = function(t) accept(t) end })
        end
        local save = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
        save:SetSize(100, 22)
        save:SetPoint("LEFT", from, "RIGHT", 10, 0)
        save:SetText(L.PRESET_SAVE)
        save:SetScript("OnClick", function()
            Popup("STORYTALE_PRESET_SAVE", L.PRESET_NAME, function(name)
                if DWE.CustomPresetSave(name) and list and list:IsShown() then list.Fill() end
            end, L.THEME_CUSTOM .. " " .. (#DWE.CustomPresets() + 1))
        end)
        local open = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
        open:SetSize(150, 22)
        open:SetPoint("LEFT", save, "RIGHT", 8, 0)
        open:SetText(L.PRESET_LIST .. "  v")
        list = CreateFrame("Frame", nil, open, "BackdropTemplate")
        list:SetPoint("TOPLEFT", open, "BOTTOMLEFT", 0, -2)
        list:SetWidth(240)
        list:SetFrameStrata("DIALOG")
        list:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        list:SetBackdropColor(0.05, 0.05, 0.06, 0.95)
        list:EnableMouse(true)
        list:Hide()
        list.rows = {}
        list.empty = list:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        list.empty:SetPoint("TOPLEFT", 10, -10)
        list.empty:SetText(L.PRESET_EMPTY)
        local ROW = 22
        function list.Fill()
            local presets = DWE.CustomPresets()
            for _, r in ipairs(list.rows) do r:Hide() end
            for i, pr in ipairs(presets) do
                local r = list.rows[i]
                if not r then
                    r = CreateFrame("Button", nil, list)
                    r:SetHeight(ROW)
                    r:SetPoint("TOPLEFT", 6, -6 - (i - 1) * ROW)
                    r:SetPoint("RIGHT", list, "RIGHT", -6, 0)
                    local hl = r:CreateTexture(nil, "HIGHLIGHT")
                    hl:SetAllPoints()
                    hl:SetColorTexture(1, 1, 1, 0.12)
                    r.dots = {}
                    for d = 1, 4 do
                        local t = r:CreateTexture(nil, "ARTWORK")
                        t:SetSize(10, 10)
                        t:SetPoint("LEFT", 4 + (d - 1) * 12, 0)
                        r.dots[d] = t
                    end
                    r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    r.text:SetPoint("LEFT", 56, 0)
                    r.text:SetPoint("RIGHT", -24, 0)
                    r.text:SetJustifyH("LEFT")
                    r.del = CreateFrame("Button", nil, r, "UIPanelCloseButton")
                    r.del:SetSize(20, 20)
                    r.del:SetPoint("RIGHT", 2, 0)
                    r.del:SetScript("OnEnter", function(self)
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:SetText(L.PRESET_DELETE)
                        GameTooltip:Show()
                    end)
                    r.del:SetScript("OnLeave", function() GameTooltip:Hide() end)
                    list.rows[i] = r
                end
                for d, k in ipairs({ "bg", "border", "text", "sel" }) do
                    local c = type(pr[k]) == "table" and pr[k] or DWE.CUSTOM_DEFAULT[k]
                    r.dots[d]:SetColorTexture(c[1] or 1, c[2] or 1, c[3] or 1, 1)
                end
                r.text:SetText(pr.name)
                r:SetScript("OnClick", function()
                    if DWE.CustomPresetApply(i) then UseCustom() end
                    list:Hide()
                end)
                r.del:SetScript("OnClick", function()
                    Popup("STORYTALE_PRESET_DELETE", L.PRESET_DELETE_ASK:format((pr.name:gsub("%%", "%%%%"))), function()
                        DWE.CustomPresetDelete(i)
                        if list:IsShown() then list.Fill() end
                    end)
                end)
                r:Show()
            end
            list.empty:SetShown(#presets == 0)
            list:SetHeight(math.max(1, #presets) * ROW + 12)
        end
        open:SetScript("OnClick", function()
            if list:IsShown() then list:Hide() else list.Fill(); list:Show() end
        end)
        p:HookScript("OnHide", function() list:Hide() end)
        Repaint()
    end

    ---------------------------------------------------------------- Texte
    y = y - 80
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
        AddGroup(fontItems, 16, y - 48, 26, function() return DialogueWheelE_Font or "friz" end, function(id)
            DialogueWheelE_Font = id
            DWE.ApplyFont()
        end, 5, 284)
        y = y - 48 - 5 * 26
    end
    AddSlider("DWESliderFont", L.FONT_SIZE, 22, y - 22, 10, 22, 1, function() return tonumber(DialogueWheelE_FontSize) or 14 end, "%d pt", function(v)
        DialogueWheelE_FontSize = v
        DWE.ApplyFont()
    end)
    AddSlider("DWESliderChoice", L.CHOICE_SIZE, 306, y - 22, 10, 24, 1, function() return DWE.ChoiceSize() end, "%d pt", function(v)
        DialogueWheelE_ChoiceSize = v
        if DWE.choiceBox:IsShown() then DWE.UpdateVisuals() end
    end)
    -- Affichage de la bulle : ecriture progressive (par defaut) ou page entiere (chaque page d'un
    -- coup ; quand une voix lit, le mot lu en couleur, comme le narrateur de Spoken).
    AddText(L.BUBBLE_MODE, 16, y - 80, "GameFontHighlightSmall")
    AddGroup({
        { id = "type", label = L.BUBBLE_MODE_TYPE },
        { id = "page", label = L.BUBBLE_MODE_PAGE },
    }, 300, y - 76, 26, function() return DialogueWheelE_BubbleMode == "page" and "page" or "type" end, function(id)
        DialogueWheelE_BubbleMode = (id == "page") and "page" or nil
        if DWE.Bubble and DWE.Bubble.RefreshHighlight then DWE.Bubble.RefreshHighlight() end
    end, 1, 190) -- (colonnes plus larges : "Ecriture progressive" est long)

    ---------------------------------------------------------------- Interface
    y = y - 126
    AddSection(L.SEC_UI or "Interface", y)
    AddCheck(L.HIDE_UI, 16, y - 32, function() return DialogueWheelE_HideUI == true end, function(self)
        DialogueWheelE_HideUI = self:GetChecked() and true or false
        -- (en direct pendant une conversation : l'interface s'efface ou revient tout de suite)
        DWE.UpdateCinemaBars()
    end)
    -- Bouton de la mini-carte (ouvre ces options).
    AddCheck(L.MINIMAP_BTN, 16, y - 62, function() return DialogueWheelE_MinimapHide ~= true end, function(self)
        DialogueWheelE_MinimapHide = (not self:GetChecked()) and true or nil
        if DWE.MinimapButtonRefresh then DWE.MinimapButtonRefresh() end
    end)

    ---------------------------------------------------------------- Livres et lettres
    y = y - 100
    NewPage(L.SEC_BOOKS, y)
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
    }, 16, y - 70, 26, function() return DialogueWheelE_BookStyle or "addon" end, function(id)
        DialogueWheelE_BookStyle = id
        if DWE.RefreshBookLookOptions then DWE.RefreshBookLookOptions() end
    end, 1, 160)
    Tip(bookStyleBoxes[1], L.BOOK_ADDON_TIP)
    -- DialogueUI : seulement si l'addon DialogueUI est actif.
    local duiOn = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("DialogueUI")
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
    }, 16, y - 118, 26, function() return (DialogueWheelE_BookLook ~= "frame" and DialogueWheelE_BookLook) or "auto" end, function(id)
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
    }, 16, y - 194, 26, function() return DialogueWheelE_PlateStyle or "addon" end, function(id)
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
    }, 16, y - 242, 26, function() return DialogueWheelE_PlateLook or "auto" end, function(id)
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
    AddCheck(L.READ_MARKS, 16, y - 272, function() return DialogueWheelE_ReadMarks ~= false end, function(self)
        if self:GetChecked() then DialogueWheelE_ReadMarks = nil else DialogueWheelE_ReadMarks = false end
    end)
    AddCheck(L.BOOK_TIP_CURSOR, 16, y - 298, function() return DialogueWheelE_BookTipCursor == true end, function(self)
        DialogueWheelE_BookTipCursor = self:GetChecked() and true or false
    end)
    local autoCheck = AddCheck(L.BOOK_AUTOSCROLL, 16, y - 324, function() return DialogueWheelE_BookAutoScroll ~= false end, function(self)
        DialogueWheelE_BookAutoScroll = self:GetChecked() and true or false
    end)
    local turnCheck = AddCheck(L.BOOK_TURN_FX, 16, y - 350, function() return DialogueWheelE_BookTurnFX ~= false end, function(self)
        DialogueWheelE_BookTurnFX = self:GetChecked() and true or false
    end)
    -- Page tournee a la main dans un livre lu par Spoken : la voix reprend a cette page.
    local voiceTurnCheck = AddCheck(L.BOOK_VOICE_TURN, 16, y - 376, function() return DialogueWheelE_BookVoiceTurn == true end, function(self)
        DialogueWheelE_BookVoiceTurn = self:GetChecked() and true or nil
    end)
    -- Livre ferme : Spoken arrete de le lire (decoche par defaut : la lecture continue).
    local stopCloseCheck = AddCheck(L.BOOK_STOP_CLOSE, 16, y - 402, function() return DialogueWheelE_BookStopOnClose == true end, function(self)
        DialogueWheelE_BookStopOnClose = self:GetChecked() and true or nil
    end)
    -- Suivre la voix et l'animation des pages : seulement quand Storytale affiche les livres ou
    -- les plaques (grisees si les deux sont laisses a Blizzard ou a DialogueUI) ; les options de
    -- la voix, en plus, seulement avec Spoken.
    local function RefreshBookExtras()
        local mine = (DialogueWheelE_BookStyle or "addon") == "addon" or (DialogueWheelE_PlateStyle or "addon") == "addon"
        local spoken = DWE.SpokenFocus and DWE.SpokenFocus.Available() and true or false
        for _, e in ipairs({ { autoCheck, true }, { turnCheck, false }, { voiceTurnCheck, true }, { stopCloseCheck, true } }) do
            local cb, needsVoice = e[1], e[2]
            local on = mine and (spoken or not needsVoice)
            local c = on and 1 or 0.5
            if cb then
                if on then cb:Enable() else cb:Disable() end
                local t = cb.Text or cb.text
                if t and t.SetTextColor then t:SetTextColor(c, c, c) end
            end
        end
    end
    do
        local ob, op = DWE.RefreshBookLookOptions, DWE.RefreshPlateLookOptions
        DWE.RefreshBookLookOptions = function(...) ob(...); RefreshBookExtras() end
        DWE.RefreshPlateLookOptions = function(...) op(...); RefreshBookExtras() end
    end
    RefreshBookExtras()

    ---------------------------------------------------------------- Placement
    y = y - 442
    NewPage(L.SEC_PLACE, y)
    AddSection(L.SEC_PLACE, y)
    AddCheck(L.ATTACH_NPC, 16, y - 32, function() return DialogueWheelE_AttachNPC ~= false end, function(self)
        DialogueWheelE_AttachNPC = self:GetChecked() and true or false
        if not DialogueWheelE_AttachNPC then DWE.StopFollow() end
    end)
    AddText(L.ATTACH_TIP, 42, y - 58, "GameFontDisableSmall")
    AddCheck(L.LOCK, 16, y - 76, function() return DWE.IsLocked() end, function(self)
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
    }, 300, y - 88, 26, function() return DialogueWheelE_WheelSide == "left" and "left" or "right" end, function(id)
        DialogueWheelE_WheelSide = (id == "left") and "left" or nil
        if not DialogueWheelE_Pos then DWE.RestorePosition() end
        if choiceBox:IsShown() then DWE.UpdateVisuals() end
        DWE.Repin()
    end, 1, 120)
    AddCheck(L.QUEST_AUTO_W, 16, y - 104, function() return DialogueWheelE_QuestAuto ~= false end, function(self)
        -- ("(not x) and false or nil" donnait toujours nil : la case ne se decochait jamais.)
        if self:GetChecked() then DialogueWheelE_QuestAuto = nil else DialogueWheelE_QuestAuto = false end
        -- Decochee : on part de la largeur automatique actuelle.
        if DialogueWheelE_QuestAuto == false and not tonumber(DialogueWheelE_QuestWidth) then
            DialogueWheelE_QuestWidth = DWE.AutoQuestWidth()
        end
        if choiceBox:IsShown() then DWE.UpdateVisuals() end
    end)

    ---------------------------------------------------------------- Commandes
    y = y - 178
    local keysPage = NewPage(L.CAT_KEYS, y)
    AddSection(L.SEC_KEYS, y)
    local keysY = y - 32
    local useBlizzCb = AddCheck(L.KEY_USE_BLIZZ, 16, keysY, function() return DialogueWheelE_UseBlizzKey ~= false end, nil)
    local interactBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    interactBtn:SetPoint("TOPLEFT", 20, keysY - 30)
    interactBtn:SetSize(240, 24)
    AddCheck(L.ESC_CLOSE, 300, keysY, function() return DialogueWheelE_EscClose ~= false end, function(self)
        DialogueWheelE_EscClose = self:GetChecked() and true or false
    end)
    AddCheck(L.WHEEL_SCROLL, 300, keysY - 28, function() return DialogueWheelE_WheelScroll ~= false end, function(self)
        DialogueWheelE_WheelScroll = self:GetChecked() and true or false
        DWE.RefreshBindings()
    end)
    -- Touches 1 a 9 : choisir directement un choix de la roue (comme DialogueUI).
    local numVisCheck
    AddCheck(L.NUMBER_KEYS or "Keys 1-9 pick a choice", 300, keysY - 56, function() return DialogueWheelE_NumberKeys ~= false end, function(self)
        -- (« (not x) and false or nil » donnait toujours nil : la case ne se decochait jamais)
        if self:GetChecked() then DialogueWheelE_NumberKeys = nil else DialogueWheelE_NumberKeys = false end
        DWE.RefreshBindings()
        for _, cb in ipairs({ numVisCheck, DWE.numBrightCheck }) do
            if cb then if self:GetChecked() then cb:Enable() else cb:Disable() end end
        end
        if choiceBox:IsShown() then DWE.UpdateVisuals() end
    end)
    -- Sous-option : numeroter les choix a l'ecran plutot que la liste entiere (cochee par defaut).
    numVisCheck = AddCheck(L.NUMBER_VISIBLE or "Number the choices on screen", 320, keysY - 82, function() return DialogueWheelE_NumberVisible ~= false end, function(self)
        -- (activee par defaut : ne change que les listes de plus de 7 choix)
        if self:GetChecked() then DialogueWheelE_NumberVisible = nil else DialogueWheelE_NumberVisible = false end
        if choiceBox:IsShown() then DWE.UpdateVisuals() end
    end)
    -- Intensite des numeros : plus sombres ou plus clairs, au gout (et a la vue) de chacun.
    local numBrightCheck = AddSlider("DWESliderNumbers", L.NUMBER_INTENSITY or "Number intensity", 330, keysY - 122, 20, 100, 5, function() return DWE.NumberIntensity() end, "%d %%", function(v)
        DialogueWheelE_NumberIntensity = v
        DialogueWheelE_NumberBright = nil
        if choiceBox:IsShown() then DWE.UpdateVisuals() end
    end)
    DWE.numBrightCheck = numBrightCheck
    if DialogueWheelE_NumberKeys == false then
        if numVisCheck then numVisCheck:Disable() end
        if numBrightCheck then numBrightCheck:Disable() end
    end
    -- (qui cherche une touche regarde ici : la touche Bulle / Spoken est dans la page Spoken)
    if L.KEY_SPOKEN_HINT then
        local hint = AddText(L.KEY_SPOKEN_HINT, 300, keysY - 168, "GameFontDisableSmall")
        if hint and hint.SetWidth then hint:SetWidth(300); hint:SetJustifyH("LEFT") end
    end

    ---------------------------------------------------------------- Manette
    y = keysY - 214
    AddSection(L.SEC_PAD, y)
    AddCheck(L.PAD_USE, 16, y - 32, function() return DialogueWheelE_GamePad ~= false end, function(self)
        DialogueWheelE_GamePad = self:GetChecked() and true or false
        DWE.RefreshBindings()
    end)
    -- Lignes d'aide a positions fixes (les deux dernieres peuvent passer sur deux lignes).
    for _, h in ipairs({ { "PAD_HELP1", 62 }, { "PAD_HELP2", 80 }, { "PAD_HELP4", 98 }, { "PAD_HELP3", 130 } }) do
        local fs = AddText(L[h[1]], 20, y - h[2], "GameFontHighlightSmall")
        fs:SetWidth(560)
        fs:SetJustifyH("LEFT")
    end

    ---------------------------------------------------------------- Spoken
    y = y - 170
    NewPage(L.SEC_SPOKEN, y)
    AddSection(L.SEC_SPOKEN, y)
    local spokenOn = DWE.SpokenFocus and DWE.SpokenFocus.Available()
    local function Grey(w, on)
        if not w then return end
        if w.Enable then if on then w:Enable() else w:Disable() end end
        if w.SetAlpha then w:SetAlpha(on and 1 or 0.5) end
    end
    if not spokenOn then AddText(L.SPOKEN_NEEDED, 200, y - 4, "GameFontDisableSmall") end
    local spokenThemeCheck = AddCheck(L.SPOKEN_THEME, 16, y - 32, function() return DialogueWheelE_SpokenTheme == true end, function(self)
        DialogueWheelE_SpokenTheme = self:GetChecked() and true or false
        if DWE.spokenSkinShow then DWE.spokenSkinShow() end
        DWE.RefreshSpoken()
    end)
    -- Habillage : une ligne pour les voix (PNJ, livres), une pour les narrations de zone. Chacune :
    -- une case pour suivre (le theme actuel / les voix), sinon les fleches choisissent.
    local skinRows = {}
    local function SkinRow(rowY, label, followLabel, get, set, choices)
        local lbl = AddText(label, 36, rowY - 4, "GameFontHighlightSmall")
        -- (Pas de relecture automatique ici : row.Show la remet a jour sans toucher au reglage.)
        local follow = AddCheck(followLabel, 240, rowY, get() == nil, nil)
        local prev = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
        prev:SetSize(26, 22)
        prev:SetPoint("TOPLEFT", p, "TOPLEFT", 400, rowY + 2)
        prev:SetText("<")
        local nxt = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
        nxt:SetSize(26, 22)
        nxt:SetPoint("LEFT", prev, "RIGHT", 140, 0)
        nxt:SetText(">")
        local value = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        value:SetPoint("LEFT", prev, "RIGHT", 4, 0)
        value:SetPoint("RIGHT", nxt, "LEFT", -4, 0)
        value:SetJustifyH("CENTER")
        local function Index(list, id)
            for i, c in ipairs(list) do if c.id == id then return i end end
            return 1
        end
        local row = {}
        function row.Show(fallback)
            local list = choices()
            local pick = get()
            local dressed = spokenOn and DialogueWheelE_SpokenTheme == true
            local on = dressed and pick ~= nil
            value:SetText(list[Index(list, pick or fallback())].label)
            value:SetAlpha(on and 1 or 0.5)
            Grey(prev, on); Grey(nxt, on)
            follow:SetChecked(pick == nil)
            Grey(follow, dressed)
            if lbl.SetAlpha then lbl:SetAlpha(dressed and 1 or 0.5) end
        end
        local function Step(d)
            if get() == nil then return end
            local list = choices()
            set(list[(Index(list, get()) - 1 + d) % #list + 1].id)
            if DWE.spokenSkinShow then DWE.spokenSkinShow() end
            DWE.RefreshSpoken()
        end
        prev:SetScript("OnClick", function() Step(-1) end)
        nxt:SetScript("OnClick", function() Step(1) end)
        row.follow, row.Step = follow, Step
        skinRows[#skinRows + 1] = row
        return row
    end
    local function ThemeChoices(extra)
        local list = {}
        for _, e in ipairs(extra or {}) do list[#list + 1] = e end
        for _, t in ipairs(THEME_LIST) do list[#list + 1] = { id = t.id, label = L[t.key] or t.id } end
        return list
    end
    local voiceRow = SkinRow(y - 58, L.SKIN_ROW_VOICE, L.SPOKEN_SKIN_FOLLOW,
        function() return DialogueWheelE_SpokenSkin end,
        function(v) DialogueWheelE_SpokenSkin = v end,
        function() return ThemeChoices() end)
    local function PlaceExtra()
        local extra = { { id = "paper", label = L.SKIN_PAPER or L.PLACE_PAPER } }
        if DWE.DUI_ON then extra[2] = { id = "dui", label = L.BOOK_DUI } end
        return ThemeChoices(extra)
    end
    local paperChoice = { id = "paper", label = L.SKIN_PAPER or L.PLACE_PAPER }
    local matChoices = {
        { id = "mat:Stone", label = L.PLATE_STONE }, { id = "mat:Marble", label = L.PLATE_MARBLE },
        { id = "mat:Bronze", label = L.PLATE_BRONZE }, { id = "mat:Silver", label = L.PLATE_SILVER },
    }
    local function With(first, rest)
        local list = { first }
        for _, e in ipairs(rest) do list[#list + 1] = e end
        return list
    end
    local bookRow = SkinRow(y - 84, L.SKIN_ROW_BOOK, L.SKIN_PAPER or L.PLACE_PAPER,
        function() return DialogueWheelE_BookSkin end,
        function(v) DialogueWheelE_BookSkin = v end,
        function() return ThemeChoices(With(paperChoice, matChoices)) end)
    local plateRow = SkinRow(y - 110, L.SKIN_ROW_PLATE, L.PLATE_FOLLOW,
        function() return DialogueWheelE_PlateSkin end,
        function(v) DialogueWheelE_PlateSkin = v end,
        function()
            local list = {}
            for _, e in ipairs(matChoices) do list[#list + 1] = e end
            list[#list + 1] = paperChoice
            return ThemeChoices(list)
        end)
    local function PlateDefault()
        local m = DialogueWheelE_PlateLook
        return "mat:" .. ((m and DWE.PLATES[m]) and m or "Stone")
    end
    local placeRow = SkinRow(y - 136, L.SKIN_ROW_PLACE, L.PLACE_FOLLOW,
        function()
            local v = DialogueWheelE_PlaceSkin
            if v == "dui" and not DWE.DUI_ON then return nil end
            return v
        end,
        function(v) DialogueWheelE_PlaceSkin = v end,
        PlaceExtra)
    local function VoiceTheme() return DialogueWheelE_SpokenSkin or CurrentTheme() end
    function DWE.spokenSkinShow()
        voiceRow.Show(function() return CurrentTheme() end)
        bookRow.Show(function() return "paper" end)
        plateRow.Show(PlateDefault)
        placeRow.Show(VoiceTheme)
    end
    plateRow.follow:SetScript("OnClick", function(self)
        DialogueWheelE_PlateSkin = (not self:GetChecked()) and PlateDefault() or nil
        DWE.spokenSkinShow(); DWE.RefreshSpoken()
    end)
    bookRow.follow:SetScript("OnClick", function(self)
        DialogueWheelE_BookSkin = (not self:GetChecked()) and "paper" or nil
        DWE.spokenSkinShow(); DWE.RefreshSpoken()
    end)
    voiceRow.follow:SetScript("OnClick", function(self)
        DialogueWheelE_SpokenSkin = (not self:GetChecked()) and CurrentTheme() or nil
        DWE.spokenSkinShow(); DWE.RefreshSpoken()
    end)
    placeRow.follow:SetScript("OnClick", function(self)
        DialogueWheelE_PlaceSkin = (not self:GetChecked()) and VoiceTheme() or nil
        DWE.spokenSkinShow(); DWE.RefreshSpoken()
    end)
    DWE.spokenSkinStep = voiceRow.Step
    DWE.spokenSkinShow()

    local toggleLbl, toggleBtn
    -- Bouton de bascule bulle / lecteur de Spoken, dans le coin de la roue.
    local spokenCheck = AddCheck(L.SPOKEN_BUTTON, 16, y - 170, function() return DialogueWheelE_SpokenButton == true end, function(self)
        DialogueWheelE_SpokenButton = self:GetChecked() and true or false
        DWE.RefreshBindings()
    end)
    -- Ou s'affiche la replique du PNJ : le texte de Storytale (bulle ou cadre) ou le lecteur Spoken.
    -- Meme reglage que le bouton de la roue et la touche, choisi ici sans avoir a l'afficher.
    local textInLbl = AddText(L.TEXT_IN, 36, y - 202, "GameFontHighlightSmall")
    local textInBoxes = AddGroup({
        { id = "storytale", label = L.TEXT_IN_STORYTALE },
        { id = "spoken", label = L.TEXT_IN_SPOKEN },
    }, 300, y - 198, 26, function() return DialogueWheelE_ShowText == true and "storytale" or "spoken" end, function(id)
        local want = id == "storytale"
        if (DialogueWheelE_ShowText == true) ~= want then DWE.ToggleDialogueText() end
    end, 1, 160)
    function DWE.TextInRefresh()
        local st = DialogueWheelE_ShowText == true
        textInBoxes[1]:SetChecked(st)
        textInBoxes[2]:SetChecked(not st)
    end
    for _, cb in ipairs(textInBoxes) do Grey(cb, spokenOn) end
    if textInLbl.SetAlpha then textInLbl:SetAlpha(spokenOn and 1 or 0.5) end
    toggleLbl = AddText(L.KEY_TOGGLE, 20, y - 230, "GameFontHighlightSmall")
    toggleBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    toggleBtn:SetPoint("TOPLEFT", toggleLbl, "BOTTOMLEFT", 0, -4)
    toggleBtn:SetSize(240, 24)
    -- File de lecture intelligente (decochee : Spoken gere seul sa file, sans nos regles).
    local smartCheck = AddCheck(L.SPOKEN_SMART, 16, y - 292, function() return DialogueWheelE_SpokenSmart ~= false end, function(self)
        DialogueWheelE_SpokenSmart = self:GetChecked() and true or false
    end)
    smartCheck.tooltipText = L.SPOKEN_SMART_TIP
    smartCheck:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.SPOKEN_SMART, 1, 0.82, 0)
        GameTooltip:AddLine(L.SPOKEN_SMART_TIP, 1, 1, 1, true)
        -- (L'infobulle cache l'astuce ecrite dessous : on la redit ici.)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L.SPOKEN_SMART_HINT, 0.6, 0.8, 1, true)
        GameTooltip:Show()
    end)
    smartCheck:HookScript("OnLeave", function() GameTooltip:Hide() end)
    Grey(smartCheck, spokenOn)
    -- Astuce : Spoken coupe la replique a la fermeture tant que son reglage est coche.
    local smartTip = AddText(L.SPOKEN_SMART_HINT, 42, y - 316, "GameFontDisableSmall")
    if smartTip.SetWidth then smartTip:SetWidth(520); smartTip:SetJustifyH("LEFT") end
    -- Mot lu surligne dans la bulle (decoche par defaut ; il faut aussi "Highlight Words" dans Spoken).
    Grey(AddCheck(L.BUBBLE_HIGHLIGHT, 16, y - 348, function() return DialogueWheelE_BubbleHighlight == true end, function(self)
        DialogueWheelE_BubbleHighlight = self:GetChecked() and true or nil
        if DWE.Bubble and DWE.Bubble.RefreshHighlight then DWE.Bubble.RefreshHighlight() end
    end), spokenOn)
    -- (« La voix suit mes pages » et « Arreter la voix en fermant un livre » : page des livres)
    -- Illustration du lieu au-dessus de la petite fenetre de Spoken (narrations de Spoken Places).
    Grey(AddCheck(L.ZONE_ART, 16, y - 378, function() return DialogueWheelE_ZoneArt ~= false end, function(self)
        DialogueWheelE_ZoneArt = self:GetChecked() and true or false
        if DWE.ZoneArtRefresh then DWE.ZoneArtRefresh() end
    end), spokenOn)
    -- Bord de papier peint dans l'illustration (decoche : la scene seule, dans le fond du theme).
    Grey(AddCheck(L.ZONE_ART_PAPER, 36, y - 404, function() return DialogueWheelE_ZoneArtPaper == true end, function(self)
        DialogueWheelE_ZoneArtPaper = self:GetChecked() and true or nil
        if DWE.ZoneArtRefresh then DWE.ZoneArtRefresh() end
    end), spokenOn)
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
    -- HookScript et non SetScript : a la manette, le jeu affiche cette page depuis sa navigation
    -- protegee ; un script pose par SetScript la contaminait (journal taint.log du 25/11 :
    -- Storytale_Core.lua OnShow -> RefreshKeyButtons), puis le jeu bloquait les actions de la
    -- manette (SetPreferredGamepadInteractTarget, sorts, cible) jusqu'au /reload.
    panel:HookScript("OnShow", function()
        RefreshKeyButtons()
        RefreshTiles()
    end)
    RefreshKeyButtons()

    ---------------------------------------------------------------- Profils
    -- Une ligne par action, avec une liste deroulante du jeu (souris et manette). Changer de
    -- profil, copier ou supprimer demande confirmation ; le profil des nouveaux personnages
    -- change tout de suite.
    local py = y - 512
    local profilesPage = NewPage(L.SEC_PROFILES, py)
    AddSection(L.SEC_PROFILES, py)
    local rows = {}
    -- Liste a nous (pas les menus deroulants du jeu : ils derangeaient la navigation manette du
    -- jeu, "action bloquee"). Un bouton montre le choix ; un clic ouvre juste dessous une liste
    -- de boutons, a la souris comme a la manette.
    local openList
    local function CloseList()
        if openList then openList:Hide(); openList = nil end
    end
    local function PRow(label, rowY, list, current, apply)
        AddText(label, 36, rowY - 4, "GameFontNormal")
        local dd = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
        dd:SetSize(240, 24)
        dd:SetPoint("TOPLEFT", p, "TOPLEFT", 300, rowY + 2)
        local arrow = dd:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        arrow:SetPoint("RIGHT", -8, 0)
        arrow:SetText("v")
        local box = CreateFrame("Frame", nil, p, "BackdropTemplate")
        box:SetFrameStrata("DIALOG")
        box:SetPoint("TOPLEFT", dd, "BOTTOMLEFT", 0, -2)
        box:SetWidth(240)
        if box.SetBackdrop then
            box:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
                insets = { left = 3, right = 3, top = 3, bottom = 3 } })
            box:SetBackdropColor(0.05, 0.05, 0.07, 0.96)
            box:SetBackdropBorderColor(0.8, 0.65, 0.3, 1)
        end
        box:Hide()
        box.items = {}
        local r = { dd = dd, list = list, current = current, box = box }
        local function Fill()
            local l = list()
            local cur = current and current()
            for i, n in ipairs(l) do
                local it = box.items[i]
                if not it then
                    it = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
                    it:SetSize(228, 22)
                    it:SetPoint("TOPLEFT", box, "TOPLEFT", 6, -6 - (i - 1) * 24)
                    box.items[i] = it
                end
                it:SetText((n == cur and "> " or "") .. DWE.ProfileLabel(n))
                it:SetScript("OnClick", function() CloseList(); apply(n) end)
                it:Show()
            end
            for i = #l + 1, #box.items do box.items[i]:Hide() end
            box:SetHeight(12 + #l * 24)
        end
        dd:SetScript("OnClick", function()
            if box:IsShown() then CloseList() return end
            CloseList()
            if #list() == 0 then return end
            Fill()
            box:Show()
            openList = box
            -- (La navigation manette du jeu relit la page quand un cadre y est cree.)
            local nudge = CreateFrame("Frame", nil, box)
            nudge:Hide()
        end)
        rows[#rows + 1] = r
        return r
    end
    profilesPage:HookScript("OnHide", CloseList)
    local function Others(withDefault)
        local l = {}
        for _, n in ipairs(DWE.ProfileList()) do
            if n ~= DWE.profile and (withDefault or n ~= "Default") then l[#l + 1] = n end
        end
        return l
    end
    PRow(L.PROFILE_CUR, py - 36, function() return DWE.ProfileList() end,
        function() return DWE.profile end, function(n) DWE.AskProfile("switch", n) end)
    PRow(L.PROFILE_COPY_FROM, py - 68, function() return Others(true) end,
        nil, function(n) DWE.AskProfile("copyfrom", n) end)
    PRow(L.PROFILE_DEL_ROW, py - 100, function() return Others(false) end,
        nil, function(n) DWE.AskProfile("delete", n) end)
    local newBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    newBtn:SetSize(200, 24)
    newBtn:SetPoint("TOPLEFT", p, "TOPLEFT", 36, py - 130)
    newBtn:SetText(L.PROFILE_NEW_BTN)
    newBtn:SetScript("OnClick", function() DWE.AskProfile("new") end)
    local resetBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    resetBtn:SetSize(200, 24)
    resetBtn:SetPoint("LEFT", newBtn, "RIGHT", 12, 0)
    resetBtn:SetText(L.RESET_ALL)
    resetBtn:SetScript("OnClick", function() DWE.AskResetAll() end)
    PRow(L.PROFILE_FOR_NEW, py - 164, function() return DWE.ProfileList() end,
        function() return DWE.ProfileNewCharName() end, function(n)
            DWE.ProfileSetForNew(n)
            if DWE.RefreshProfilesUI then DWE.RefreshProfilesUI() end
        end)
    local function RefreshProfiles()
        if not DWE.ProfileList then return end
        for _, r in ipairs(rows) do
            local cur = r.current and r.current()
            r.dd:SetText(cur and DWE.ProfileLabel(cur) or "")
            r.dd:SetEnabled(#r.list() > 0)
        end
    end
    DWE.RefreshProfilesUI = RefreshProfiles
    do
        local hint = AddText(L.PROFILE_HINT, 36, py - 200, "GameFontDisableSmall")
        if hint and hint.SetWidth then hint:SetWidth(560); hint:SetJustifyH("LEFT") end
    end
    profilesPage:HookScript("OnShow", function() RefreshProfiles() end)
    RefreshProfiles()
    pages[#pages].child:SetHeight((py - 12) - (py - 210) + 30)
    keysPage:HookScript("OnShow", function() RefreshKeyButtons() end)
    -- Ce que les reglages ne relisent pas d'eux-memes : vignettes de themes, touches, habillages.
    function DWE.RefreshOptionsExtra()
        pcall(RefreshTiles)
        pcall(RefreshKeyButtons)
        if DWE.spokenSkinShow then pcall(DWE.spokenSkinShow) end
    end

    ---------------------------------------------------------------- Recherche
    -- Une barre en haut du panneau (hors du defilement) : chaque frappe amene la vue sur la
    -- premiere option dont le nom (ou l'aide) contient le texte, et l'eclaire un instant.
    -- Entree passe a la suivante. Majuscules et accents ne comptent pas.
    local counts, boxes = {}, {}
    local function MakeSearch(host, gname)
        local okT, search = pcall(CreateFrame, "EditBox", gname, host, "SearchBoxTemplate")
        if not okT or not search then search = CreateFrame("EditBox", gname, host, "InputBoxTemplate") end
        search:SetSize(260, 20)
        search:SetPoint("TOPRIGHT", host, "TOPRIGHT", -170, -8)
        search:SetAutoFocus(false)
        if type(search.Instructions) == "table" then
            search.Instructions:SetText(L.OPT_SEARCH)
        else -- sans le modele de recherche du jeu : un texte d'invite a nous
            local hint = search:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
            hint:SetPoint("LEFT", 6, 0)
            hint:SetText(L.OPT_SEARCH)
            local function Hint(self) hint:SetShown(self:GetText() == "" and not self:HasFocus()) end
            search:HookScript("OnEditFocusGained", function() hint:Hide() end)
            search:HookScript("OnEditFocusLost", Hint)
            search:HookScript("OnTextChanged", Hint)
        end
        local c = host:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        c:SetPoint("RIGHT", search, "LEFT", -10, 0)
        counts[#counts + 1] = c
        boxes[#boxes + 1] = search
        return search
    end
    for k, pg in ipairs(pages) do pg.search = MakeSearch(pg.panel, k == 1 and "DialogueWheelEOptionsSearch" or nil) end
    -- "Par defaut" en haut de chaque page : remet les reglages de cette page seulement.
    local PAGE_VARS = {
        { "Theme", "Font", "FontSize", "Opacity", "ThemeFrames", "WheelTheme", "HideUI", "ChoiceSize", "MinimapHide", "BubbleMode" }, -- (position du bouton gardee : "MinimapAngle" n'est jamais remis par defaut)
        { "BookStyle", "BookLook", "PlateStyle", "PlateLook", "ReadMarks", "BookTipCursor", "BookAutoScroll", "BookTurnFX",
            "BookVoiceTurn", "BookStopOnClose", "BookPos", "BookScale", "NoteScale", "RoundScale", "RoundPos" },
        { "AttachNPC", "Locked", "WheelSide", "QuestAuto", "QuestWidth", "NPCOffset", "Pos", "TextPos", "WheelWidth", "TextW", "TextH", "BubbleWidth" },
        { "UseBlizzKey", "InteractKey", "ToggleKey", "EscClose", "WheelScroll", "NumberKeys", "NumberVisible", "NumberBright", "NumberIntensity", "GamePad", "PadTips", "PadFreeLook" },
        { "SpokenTheme", "SpokenSkin", "BookSkin", "PlateSkin", "PlaceSkin", "SpokenButton", "ShowText", "SpokenSmart", "BubbleHighlight",
            "ZoneArt", "ZoneArtPaper" },
    }
    for k, pg in ipairs(pages) do
        if PAGE_VARS[k] then
            pg.vars = PAGE_VARS[k]
            local b = CreateFrame("Button", nil, pg.panel, "UIPanelButtonTemplate")
            b:SetSize(130, 22)
            b:SetPoint("TOPRIGHT", pg.panel, "TOPRIGHT", -24, -7)
            b:SetText(L.DEFAULTS_BTN)
            b:SetScript("OnClick", function() DWE.AskResetPage(pg.panel.name ~= "Storytale" and pg.panel.name or L.SEC_THEME, pg.vars) end)
            pg.defaults = b
            if k == 1 then
                -- Page principale : tout remettre d'un coup (le profil en cours, toutes les pages).
                local all = CreateFrame("Button", nil, pg.panel, "UIPanelButtonTemplate")
                all:SetSize(130, 22)
                all:SetPoint("RIGHT", b, "LEFT", -6, 0)
                all:SetText(L.DEFAULTS_ALL_BTN)
                all:SetScript("OnClick", function() DWE.AskResetAll() end)
                pg.defaultsAll = all
                if pg.search then
                    pg.search:ClearAllPoints()
                    pg.search:SetPoint("TOPRIGHT", pg.panel, "TOPRIGHT", -306, -8)
                end
            end
        end
    end
    -- Texte du compteur, sur toutes les pages.
    local count = { SetText = function(_, t) for _, c in ipairs(counts) do c:SetText(t) end end }
    local glow, glowPage
    local fader = CreateFrame("Frame", "DialogueWheelEOptionsSearchGlow", panel)
    fader:Hide()
    fader:SetScript("OnUpdate", function(self, el)
        self.t = (self.t or 0) + el
        if self.t > 2 then if glow then glow:Hide() end; self:Hide()
        elseif self.t > 1.2 and glow then glow:SetAlpha((2 - self.t) / 0.8) end
    end)
    local function GlowOn(pg)
        if glow and glowPage ~= pg then glow:Hide() end
        pg.glow = pg.glow or pg.child:CreateTexture(nil, "BACKGROUND")
        pg.glow:SetColorTexture(1, 0.82, 0, 0.22)
        glow, glowPage = pg.glow, pg
        return glow
    end
    local FOLD = { ["à"] = "a", ["â"] = "a", ["ä"] = "a", ["á"] = "a", ["é"] = "e", ["è"] = "e", ["ê"] = "e",
        ["ë"] = "e", ["î"] = "i", ["ï"] = "i", ["í"] = "i", ["ô"] = "o", ["ö"] = "o", ["ó"] = "o", ["ù"] = "u",
        ["û"] = "u", ["ü"] = "u", ["ú"] = "u", ["ç"] = "c", ["ñ"] = "n", ["ß"] = "ss",
        ["À"] = "a", ["Â"] = "a", ["Ä"] = "a", ["Á"] = "a", ["É"] = "e", ["È"] = "e", ["Ê"] = "e",
        ["Ë"] = "e", ["Î"] = "i", ["Ï"] = "i", ["Í"] = "i", ["Ô"] = "o", ["Ö"] = "o", ["Ó"] = "o",
        ["Ù"] = "u", ["Û"] = "u", ["Ü"] = "u", ["Ú"] = "u", ["Ç"] = "c", ["Ñ"] = "n" }
    local function Fold(t)
        t = tostring(t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):lower()
        t = t:gsub("\195[\128-\191]", function(c) return FOLD[c] or c end)
        return t
    end
    -- Tout ce qui porte un nom dans le panneau : textes, cases, boutons, curseurs, et l'aide des cases.
    local function Entries()
        local list = {}
        local function Add(fs, extra)
            if not (fs and fs.GetText) then return end
            local txt = fs:GetText()
            if (type(txt) == "string" and txt ~= "") or extra then
                list[#list + 1] = { fs = fs, text = Fold((txt or "") .. " " .. (extra or "")) }
            end
        end
        local function Walk(f)
            for _, r in ipairs({ f:GetRegions() }) do
                if r.GetObjectType and r:GetObjectType() == "FontString" then Add(r, f.tooltipText) end
            end
            for _, c in ipairs({ f:GetChildren() }) do Walk(c) end
        end
        for k, pg in ipairs(pages) do
            local from = #list
            Walk(pg.child)
            for n = from + 1, #list do list[n].page, list[n].pageN = pg, k end
        end
        return list
    end
    local found, at = {}, 0
    local Place
    local function Show(i)
        local e = found[i]
        if not e then return end
        count:SetText(i .. " / " .. #found)
        -- Option d'une autre categorie : on ouvre sa page, puis on y va (une fois affichee).
        local pg = e.page or pages[1]
        -- Fenetre d'options de Storytale : on passe a l'onglet de la page.
        local win = DWE.Native and DWE.Native.window
        if not pg.panel:IsVisible() and win and win:IsShown() and win.ShowPage then
            for k, page in ipairs(pages) do if page == pg then win.ShowPage(k) end end
            if C_Timer and C_Timer.After then
                C_Timer.After(0.05, function() Place(e) end)
                return
            end
        elseif not pg.panel:IsVisible() and pg.cat and Settings and Settings.OpenToCategory then
            local id = pg.cat.GetID and pg.cat:GetID() or pg.cat.ID
            pcall(Settings.OpenToCategory, id)
            if C_Timer and C_Timer.After then
                C_Timer.After(0.05, function() Place(e) end)
                return
            end
        end
        Place(e)
    end
    Place = function(e)
        local pg = e.page or pages[1]
        local p, scroll = pg.child, pg.scroll
        local glow = GlowOn(pg)
        local top, pTop = e.fs:GetTop(), p:GetTop()
        if top and pTop then
            local range = scroll:GetVerticalScrollRange() or 0
            local want = math.max(0, math.min(range, pTop - top - 60))
            scroll:SetVerticalScroll(want)
            -- Ajustee a l'option trouvee : sa case ou son bouton compris, jusqu'au bout de son texte.
            glow:ClearAllPoints()
            local owner = e.fs:GetParent()
            local isBox = owner and owner.GetObjectType and owner ~= p and owner ~= pg.content
                and (owner:GetObjectType() == "CheckButton" or owner:GetObjectType() == "Button")
            local pLeft = p:GetLeft() or 0
            local left = (isBox and owner:GetLeft()) or e.fs:GetLeft() or (pLeft + 8)
            local right = (e.fs:GetLeft() or left) + math.min(e.fs:GetStringWidth() or 0, e.fs:GetWidth() or 9999)
            if isBox and owner:GetRight() then right = math.max(right, owner:GetRight()) end
            glow:SetPoint("TOPLEFT", p, "TOPLEFT", left - pLeft - 6, top - pTop + 6)
            glow:SetWidth(math.max(20, right - left + 12))
            glow:SetHeight((e.fs:GetHeight() or 14) + 12)
            glow:SetAlpha(1); glow:Show()
            fader.t = 0; fader:Show()
        end
    end
    function DWE.OptionsSearch(text, nextOne)
        local q = Fold(text):gsub("^%s+", ""):gsub("%s+$", "")
        if q == "" then
            found, at = {}, 0
            count:SetText("")
            if glow then glow:Hide() end
            return 0
        end
        if not nextOne then
            found, at = {}, 0
            for _, e in ipairs(Entries()) do
                if e.text:find(q, 1, true) then found[#found + 1] = e end
            end
            -- De haut en bas, dans l'ordre du panneau.
            table.sort(found, function(a, b)
                if a.pageN ~= b.pageN then return (a.pageN or 0) < (b.pageN or 0) end
                return (a.fs:GetTop() or 0) > (b.fs:GetTop() or 0)
            end)
        end
        if #found == 0 then
            count:SetText(L.OPT_SEARCH_NONE)
            if glow then glow:Hide() end
            return 0
        end
        at = (nextOne and at or 0) % #found + 1
        Show(at)
        return #found, at
    end
    for _, search in ipairs(boxes) do
        search:HookScript("OnTextChanged", function(self, user)
            if not user then return end
            -- Meme recherche dans la barre de chaque page.
            for _, o in ipairs(boxes) do if o ~= self then o:SetText(self:GetText()) end end
            DWE.OptionsSearch(self:GetText())
        end)
        search:SetScript("OnEnterPressed", function(self) DWE.OptionsSearch(self:GetText(), true) end)
        search:SetScript("OnEscapePressed", function(self)
            for _, o in ipairs(boxes) do o:SetText("") end
            self:ClearFocus(); DWE.OptionsSearch("")
        end)
    end

    -- Manette : la navigation du jeu ne relit le contenu d'une fenetre que quand un cadre y est
    -- cree. Notre page est construite une fois pour toutes, avant d'etre posee dans les options :
    -- a chaque affichage, un petit cadre vide y est cree pour qu'elle trouve nos reglages.
    local function Nudge(self)
        if not (C_Timer and C_Timer.After) then return end
        -- (Plusieurs fois : la page n'est pas toujours deja en place a la premiere.)
        for _, t in ipairs({ 0, 0.2, 0.6 }) do
            C_Timer.After(t, function()
                if self:IsVisible() then
                    local nudge = CreateFrame("Frame", nil, self)
                    nudge:Hide()
                    DWE.OptionsPadRows()
                end
            end)
        end
    end
    -- Page qui tient entiere dans la fenetre : pas de barre de defilement, et jamais decalee
    -- (sinon la molette ou la manette la faisaient sortir de la vue, page vide).
    local function FitScroll(pg)
        local sc = pg.scroll
        local okH, viewH = pcall(sc.GetHeight, sc)
        local okC, childH = pcall(pg.child.GetHeight, pg.child)
        if not (okH and okC and viewH and childH) then return end
        local fits = childH <= viewH + 1
        local bar = sc.ScrollBar or (sc.GetName and sc:GetName() and _G[sc:GetName() .. "ScrollBar"])
        if type(bar) == "table" and bar.SetShown then bar:SetShown(not fits) end
        if fits then
            sc:SetVerticalScroll(0)
            sc:EnableMouseWheel(false)
        else
            sc:EnableMouseWheel(true)
        end
    end
    for _, pg in ipairs(pages) do
        pg.panel:HookScript("OnShow", Nudge)
        pg.panel:HookScript("OnShow", function()
            FitScroll(pg)
            if C_Timer and C_Timer.After then C_Timer.After(0, function() FitScroll(pg) end) end
        end)
        pg.scroll:HookScript("OnVerticalScroll", function(self)
            local okC, childH = pcall(pg.child.GetHeight, pg.child)
            local okH, viewH = pcall(self.GetHeight, self)
            if okC and okH and childH and viewH and childH <= viewH + 1 and (self:GetVerticalScroll() or 0) ~= 0 then
                self:SetVerticalScroll(0)
            end
        end)
    end

    -- Options dans leur propre fenetre (Options_Native.lua) : le menu du jeu n'a plus qu'une page
    -- qui l'ouvre (pas de doublon, et plus aucun reglage de Storytale dans le panneau du jeu, dont
    -- la manette se bloquait).
    -- Page faite de lignes du jeu (comme celles de Spoken) : son bouton se choisit a la manette,
    -- ce qu'une page dessinee par l'addon ne permet pas. Aucun reglage dedans : juste le bouton.
    local makeBtn = rawget(_G, "CreateSettingsButtonInitializer")
    local makeHdr = rawget(_G, "CreateSettingsListSectionHeaderInitializer")
    if DWE.NATIVE_OPTIONS and Settings and Settings.RegisterVerticalLayoutCategory and makeBtn then
        local cat, layout = Settings.RegisterVerticalLayoutCategory("Storytale")
        if makeHdr then pcall(function() layout:AddInitializer(makeHdr(L.OPT_LAUNCH_TEXT or "")) end) end
        pcall(function()
            layout:AddInitializer(makeBtn(L.OPT_WINDOW_OPEN or "Storytale", L.OPT_WINDOW_OPEN or "Storytale",
                function() if DWE.OpenOptionsWindow then DWE.OpenOptionsWindow() end end, L.OPT_LAUNCH_HOW, true))
        end)
        Settings.RegisterAddOnCategory(cat)
        DWE.optionsCategory = cat
    elseif Settings and Settings.RegisterCanvasLayoutCategory then
        local cat = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(cat)
        DWE.optionsCategory = cat
        pages[1].cat = cat
        if Settings.RegisterCanvasLayoutSubcategory then
            for k = 2, #pages do
                local okS, sub = pcall(Settings.RegisterCanvasLayoutSubcategory, cat, pages[k].panel, pages[k].panel.name)
                if okS then pages[k].cat = sub end
            end
        end
        -- Pages en lignes natives (refonte page par page, voir Options_Native.lua).
        -- (Cachees dans les versions publiees tant que la refonte n'est pas finie.)
        -- Sous-pages toujours depliees dans la liste du jeu : a la manette, le petit "+" a cote du
        -- nom est difficile (voire impossible) a atteindre.
        if type(cat.SetExpanded) == "function" then pcall(cat.SetExpanded, cat, true) else cat.expanded = true end
    end
end

-- Scripts qui tournent en continu : surveilles (voir DWE.Guard).
-- (Pas de variable ici : le fichier est deja a la limite de 200 variables locales.)
DWE.GuardScripts(cineBars, "cine")
DWE.GuardScripts(follower, "follow")
DWE.GuardScripts(scrollAnim, "scroll")
DWE.GuardScripts(scrollThumb, "thumb")
DWE.GuardScripts(listDriver, "list")
DWE.GuardScripts(DWE.bookFlip, "flip")
DWE.GuardScripts(DWE.ribbonBar, "ribbon")
