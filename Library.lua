-- Storytale : la bibliotheque. Chaque ecrit ouvert (livre, lettre, note, plaque) y est range en
-- entier, pour etre relu de A a Z : un grand livre, la liste a gauche, l'ecrit a droite.
-- Par personnage ; option : commune a tous les personnages. Avec Spoken Readables, le livre
-- entier vient de ses donnees (texte de chaque page) des l'ouverture, et l'option "Tous les
-- livres" montre aussi ceux pas encore trouves. Sans lui, les pages s'ajoutent au fil de la
-- lecture : tourner les pages en coulisse derangeait la lecture du livre ouvert (pages
-- sautees, marque-page, allure du livre).

local L = DWE.L or {}
local Lib = {}
DWE.Library = Lib

--------------------------------------------------------------------------------
-- Collection
--------------------------------------------------------------------------------
-- DialogueWheelE_Library (par personnage) et DialogueWheelE_LibraryShared (commune) :
-- [cle du titre] = { t = titre, p = { pages }, z = zone, m = matiere, d = date de la premiere lecture }
local function Store(shared)
    if shared then
        if type(DialogueWheelE_LibraryShared) ~= "table" then DialogueWheelE_LibraryShared = {} end
        return DialogueWheelE_LibraryShared
    end
    if type(DialogueWheelE_Library) ~= "table" then DialogueWheelE_Library = {} end
    return DialogueWheelE_Library
end
Lib.Store = Store
function Lib.Shared() return DialogueWheelE_LibraryAll == true end

local function Clean(s)
    if type(s) ~= "string" or (issecretvalue and issecretvalue(s)) then return nil end
    return s
end
local function Norm(s)
    return (s or ""):lower():gsub("[%s%p]+", " "):gsub("^ ", ""):sub(1, 60)
end

-- Donnees de Spoken Readables (texte de chaque page de pres de 400 livres), si installe.
-- (titres et textes en anglais : seulement pour un jeu en anglais, sinon les titres ne
-- correspondraient pas a ceux vus en jeu)
local function SpokenData()
    local loc = GetLocale and GetLocale() or "enUS"
    if type(loc) ~= "string" or loc:sub(1, 2) ~= "en" then return nil end
    local d = rawget(_G, "SpokenReadablesData")
    if type(d) == "table" and type(d.books) == "table" and type(d.pages) == "table" then return d end
    return nil
end
Lib.SpokenData = SpokenData

-- Le livre `title` dans les donnees de Spoken : la liste de ses pages. Plusieurs editions sous le
-- meme titre : celle dont la premiere page ressemble a `first` (le texte vu en jeu).
function Lib.SpokenPages(title, first)
    local d = SpokenData()
    if not d or type(title) ~= "string" then return nil end
    local best, bestScore
    for _, b in pairs(d.books) do
        if type(b) == "table" and b.title == title and type(b.pages) == "table" and #b.pages > 0 then
            local p1 = d.pages[b.pages[1]]
            local score = 0
            if first and p1 and type(p1.text) == "string" then
                local a, c = Norm(first), Norm(p1.text)
                score = (a ~= "" and a:sub(1, 30) == c:sub(1, 30)) and 2 or 0
            end
            if not best or score > bestScore then best, bestScore = b, score end
        end
    end
    if not best then return nil end
    local out = {}
    for i, id in ipairs(best.pages) do
        local pg = d.pages[id]
        out[i] = pg and type(pg.text) == "string" and pg.text or ""
    end
    return out
end

local function Entry(title)
    local key = DWE.BookKey and DWE.BookKey(title)
    if not key then return nil end
    local now = time and time() or 0
    for _, shared in ipairs({ false, true }) do
        local s = Store(shared)
        local e = s[key]
        if type(e) ~= "table" then
            e = { t = title, p = {}, d = now }
            s[key] = e
        end
        e.t = title
    end
    return key
end

-- Range la page `n` (texte `text`) du livre `title` dans les deux bibliotheques.
function Lib.AddPage(title, n, text)
    text = Clean(text)
    local key = Entry(title)
    if not key or not text or not tonumber(n) then return end
    for _, shared in ipairs({ false, true }) do
        local e = Store(shared)[key]
        e.p[tonumber(n)] = text
    end
end
-- Livre entier connu d'avance (Spoken) : toutes ses pages d'un coup, sans ecraser celles vues en jeu.
function Lib.AddBook(title, pages, zone, mat)
    local key = Entry(title)
    if not key then return end
    for _, shared in ipairs({ false, true }) do
        local e = Store(shared)[key]
        for i, t in ipairs(pages or {}) do
            if not e.p[i] and type(t) == "string" and t ~= "" then e.p[i] = t end
        end
        if zone and not e.z then e.z = zone end
        if mat and not e.m then e.m = mat end
    end
end
function Lib.Get(title, shared)
    local key = DWE.BookKey and DWE.BookKey(title)
    return key and Store(shared == nil and Lib.Shared() or shared)[key] or nil
end

-- Ecrit ouvert : son titre, sa zone, sa matiere ; les pages au fil de ITEM_TEXT_READY.
local open -- { title, spoken = donnees de Spoken deja cherchees }
local function Zone()
    local z = GetZoneText and Clean(GetZoneText()) or nil
    return z ~= "" and z or nil
end
-- Livres lus avant la bibliotheque : Storytale retenait deja leur titre (marque "deja lu",
-- DialogueWheelE_ReadBooks, en minuscules). Ils entrent dans la bibliotheque une fois par
-- personnage : le titre tel qu'ecrit et le texte entier quand Spoken connait le livre, sinon le
-- titre seul (le texte se garde a la prochaine ouverture en jeu).
function Lib.ImportRead()
    local lib = Store(false)
    if lib["\0imported"] then return 0 end
    lib["\0imported"] = true
    local read = rawget(_G, "DialogueWheelE_ReadBooks")
    if type(read) ~= "table" then return 0 end
    local titles = {}
    local d = SpokenData()
    if d then
        for _, b in pairs(d.books) do
            local k = type(b) == "table" and DWE.BookKey(b.title)
            if k and not titles[k] then titles[k] = b.title end
        end
    end
    local n = 0
    for key, state in pairs(read) do
        if type(key) == "string" and not lib[key] then
            local title = titles[key] or (key:gsub("^%l", string.upper))
            local pages = titles[key] and Lib.SpokenPages(title) or nil
            Lib.AddBook(title, pages)
            for _, shared in ipairs({ false, true }) do
                local e = Store(shared)[key]
                if e then
                    e.d = 0 -- (date de lecture inconnue)
                    if state == 2 then e.done = true end
                end
            end
            n = n + 1
        end
    end
    return n
end

-- Numero de l'objet du monde (GUID "GameObject-0-1-2-3-<numero>-<apparition>") ou de l'objet
-- du sac qui a ouvert l'ecrit : l'unite "npc" (le jeu la donne pour une note du sac), sinon
-- l'objet vise par la touche d'interaction ou sous la souris.
function Lib.Source()
    local obj, item
    for _, unit in ipairs({ "npc", "softinteract", "mouseover" }) do
        local ok, guid = pcall(UnitGUID or function() end, unit)
        guid = ok and Clean(guid) or nil
        if guid then
            local entry = guid:match("^GameObject%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
            if entry and not obj then obj = tonumber(entry) end
            if guid:match("^Item%-") and not item then
                local getID = (C_Item and C_Item.GetItemIDByGUID) or rawget(_G, "GetItemIDByGUID")
                if getID then
                    local okI, id = pcall(getID, guid)
                    if okI and type(id) == "number" then item = id end
                end
            end
        end
    end
    return obj, item
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("ITEM_TEXT_BEGIN")
ev:RegisterEvent("ITEM_TEXT_READY")
ev:RegisterEvent("ITEM_TEXT_CLOSED")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then pcall(Lib.ImportRead) return end
    if event == "ITEM_TEXT_CLOSED" then open = nil return end
    local title = ItemTextGetItem and Clean(ItemTextGetItem())
    if not title or title == "" then return end
    if event == "ITEM_TEXT_BEGIN" or not open or open.title ~= title then
        open = { title = title }
        local mat = ItemTextGetMaterial and Clean(ItemTextGetMaterial()) or nil
        Lib.AddBook(title, nil, Zone(), mat)
        -- D'ou vient l'ecrit : l'objet du monde (son numero, pour montrer son vrai modele en 3D)
        -- ou l'objet du sac (pour son icone).
        local obj, item = Lib.Source()
        for _, shared in ipairs({ false, true }) do
            local e = Lib.Get(title, shared)
            if e then e.o, e.i = obj or e.o, item or e.i end
        end
    end
    if event ~= "ITEM_TEXT_READY" then return end
    local n = ItemTextGetPage and ItemTextGetPage() or 1
    local text = ItemTextGetText and ItemTextGetText()
    if DWE.PlainItemText then text = DWE.PlainItemText(text) end
    Lib.AddPage(title, n, text)
    -- Livre entier depuis Spoken, des la premiere page (l'edition se reconnait a son texte).
    if n == 1 and not open.spoken then
        open.spoken = true
        local pages = Lib.SpokenPages(title, Clean(text))
        if pages then Lib.AddBook(title, pages) end
    end
    -- Derniere page atteinte : le livre est complet (sinon la bibliotheque le dit).
    if not (ItemTextHasNextPage and ItemTextHasNextPage()) then
        for _, shared in ipairs({ false, true }) do
            local e = Lib.Get(title, shared)
            if e then e.done = true end
        end
    end
end)

--------------------------------------------------------------------------------
-- Liste
--------------------------------------------------------------------------------
-- Genre d'un ecrit : plaque (matiere gravee), lettre (une seule page) ou livre.
local function Kind(e)
    if e.m and DWE.PLATES and DWE.PLATES[e.m] then return "plate" end
    local n = 0
    for _ in pairs(e.p or {}) do n = n + 1 end
    if n <= 1 then return "letter" end
    return "book"
end
Lib.Kind = Kind

-- Les ecrits a montrer : ceux trouves ; avec "Tous les livres" (et Spoken), aussi les autres.
-- Chaque ligne : { key, title, entry (nil si pas encore trouve), kind }.
function Lib.List(filter, search, sort)
    local s = Store(Lib.Shared())
    local rows, seen = {}, {}
    for key, e in pairs(s) do
        if type(e) == "table" and type(e.t) == "string" then
            rows[#rows + 1] = { key = key, title = e.t, entry = e, kind = Kind(e) }
            seen[key] = true
        end
    end
    local found = #rows
    local total = found
    local d = SpokenData()
    if d then
        local titles = {}
        for _, b in pairs(d.books) do
            local k = type(b) == "table" and DWE.BookKey(b.title)
            if k and not titles[k] then titles[k] = b end
        end
        total = 0
        for k, b in pairs(titles) do
            total = total + 1
            if not seen[k] then
                local kind = #b.pages > 1 and "book" or "letter"
                rows[#rows + 1] = { key = k, title = b.title, kind = kind, locked = DialogueWheelE_LibraryUnlock ~= true }
                if DialogueWheelE_LibraryUnlock == true then rows[#rows].spoken = b end
            end
        end
        -- (des ecrits trouves en jeu que Spoken ne connait pas s'ajoutent au total)
        for k in pairs(seen) do if not titles[k] then total = total + 1 end end
    end
    local q = type(search) == "string" and search:lower() or ""
    local out = {}
    for _, r in ipairs(rows) do
        local okKind = not filter or filter == "all" or filter == r.kind
        local okSearch = q == "" or r.title:lower():find(q, 1, true)
        if okKind and okSearch then out[#out + 1] = r end
    end
    table.sort(out, function(a, b)
        if (a.locked or false) ~= (b.locked or false) then return not a.locked end
        if sort == "recent" and a.entry and b.entry and (a.entry.d or 0) ~= (b.entry.d or 0) then
            return (a.entry.d or 0) > (b.entry.d or 0)
        end
        return a.title:lower() < b.title:lower()
    end)
    return out, found, total
end

-- Pages d'une ligne, dans l'ordre (trous bouches avec les donnees de Spoken).
-- Second resultat : le livre est-il complet (derniere page atteinte en jeu, ou connu de Spoken) ?
function Lib.Pages(row)
    local pages = {}
    if row.entry then
        local max = 0
        for i in pairs(row.entry.p or {}) do if i > max then max = i end end
        local fill = Lib.SpokenPages(row.title, row.entry.p[1])
        for i = 1, math.max(max, fill and #fill or 0) do
            pages[i] = row.entry.p[i] or (fill and fill[i]) or ""
        end
        return pages, (row.entry.done or fill ~= nil) and true or false
    elseif row.spoken then
        pages = Lib.SpokenPages(row.title) or {}
    end
    return pages, true
end


--------------------------------------------------------------------------------
-- Fenetre : une piece de bibliotheque. A gauche deux bibliotheques (LibraryBookcase.png),
-- un dos de livre par ecrit ; a droite, sur le mur, le titre, la recherche et les filtres, et le
-- pupitre (LibraryLectern.png) ou le livre choisi (par defaut le dernier lu) est presente. Un
-- clic sur lui l'ouvre dans le grand livre peint (BookSpread.png), deux pages a la fois.
--------------------------------------------------------------------------------
local ADDON = "Interface\\AddOns\\Storytale\\"
local W, H = 1000, 600
local INK = { 0.17, 0.10, 0.04 }
local HEAD = { 0.40, 0.16, 0.04 }
local GOLD = { 1, 0.86, 0.55 }
local PALE = { 0.92, 0.84, 0.68 }

-- Bibliotheque (texture 512x1024) : etageres, en pixels de la texture : bord gauche et droit de
-- l'interieur, et pour chaque etagere le haut et le plancher.
local CASE = { left = 127, right = 384, contentL = 71, contentR = 440,
    tops = { 161, 255, 350, 444, 554, 657, 767, 874 },
    floors = { 240, 329, 427, 526, 628, 735, 841, 964 } }
local CASE_H = 540
local CS = CASE_H / 1024
-- Pupitre (texture 1024x1024) : son plateau (x gauche, x droit, haut, bas).
local LECTERN = { size = 360, top = { 150, 790, 20, 190 } }

local room, reader, ui
local state = { filter = "all", search = "", sort = "az", shelf = 1, page = 1 }
Lib.state = state

local function Font(fs, size, color)
    local face = DWE.FontPath and DWE.ThemeFontId and DWE.FontPath(DWE.ThemeFontId()) or STANDARD_TEXT_FONT
    if DWE.SafeSetFont then DWE.SafeSetFont(fs, face, size) else fs:SetFont(face, size) end
    fs:SetTextColor(color[1], color[2], color[3])
end

local Refresh, RefreshReader

local function TextButton(parent, text, onClick, color)
    color = color or PALE
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(18)
    local fs = b:CreateFontString(nil, "OVERLAY")
    fs:SetPoint("CENTER")
    b.text, b.color = fs, color
    b:SetFontString(fs)
    Font(fs, 13, color)
    fs:SetShadowOffset(1, -1)
    b:SetText(text)
    b:SetWidth(math.max(20, (fs:GetStringWidth() or 30) + 10))
    b:SetScript("OnClick", onClick)
    b:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 0.95, 0.7) end)
    b:SetScript("OnLeave", function(self) local c = self.color; self.text:SetTextColor(c[1], c[2], c[3]); if self.id then Refresh() end end)
    return b
end

-- Couleur et allure du dos d'un ecrit : un cuir par livre (tire de son titre), le parchemin
-- pour une lettre, la pierre ou le metal pour une plaque.
local LEATHER = { { 0.45, 0.12, 0.10 }, { 0.15, 0.24, 0.40 }, { 0.18, 0.32, 0.18 }, { 0.42, 0.28, 0.12 },
    { 0.32, 0.15, 0.30 }, { 0.52, 0.38, 0.16 }, { 0.25, 0.20, 0.16 }, { 0.12, 0.30, 0.32 } }
local METAL = { Stone = { 0.50, 0.49, 0.46 }, Marble = { 0.78, 0.76, 0.72 }, Bronze = { 0.55, 0.38, 0.18 },
    Silver = { 0.70, 0.72, 0.76 }, Dalaran = { 0.45, 0.30, 0.62 } }
local function Hash(s)
    local h = 7
    for i = 1, #s do h = (h * 31 + s:byte(i)) % 1000003 end
    return h
end
function Lib.Spine(row)
    local h = Hash(row.title or "")
    local e = row.entry
    local n = 0
    for _ in pairs(e and e.p or {}) do n = n + 1 end
    if row.kind == "plate" then
        return METAL[e and e.m] or METAL.Stone, 12, 0.62 + (h % 10) / 100
    elseif row.kind == "letter" then
        return { 0.82, 0.74, 0.56 }, 5, 0.55 + (h % 15) / 100
    end
    return LEATHER[h % #LEATHER + 1], math.min(15, 7 + math.max(n, 2)), 0.70 + (h % 20) / 100
end

-- Emplacements des etageres pour le style choisi : { x, y (plancher), largeur, hauteur },
-- dans l'ordre ou elles se remplissent. "room" : les deux bibliotheques entieres ; "simple" :
-- une seule grande etagere, faite des rangees decoupees dans la bibliotheque et elargies
-- (le bord gauche et le bord droit gardes tels quels, le milieu etire en largeur), sans fond.
local SIMPLE = { rows = { 2, 3, 4, 5, 6, 7 }, scale = 0.7, wide = 2.2, gap = 0, top = 92, left = 14 }
function Lib.Style() return DialogueWheelE_LibraryStyle == "simple" and "simple" or "room" end
local function SimpleRow(i, y)
    local k = SIMPLE.scale
    local edgeL = (CASE.left - CASE.contentL) * k
    local mid = (CASE.right - CASE.left) * k * SIMPLE.wide
    local edgeR = (CASE.contentR - CASE.right) * k
    local h = (CASE.floors[i] - CASE.tops[i] + 18) * k
    return { x = SIMPLE.left, top = y, edgeL = edgeL, mid = mid, edgeR = edgeR, h = h, i = i,
        w = edgeL + mid + edgeR, floor = y + (CASE.floors[i] - CASE.tops[i]) * k, inner = (CASE.floors[i] - CASE.tops[i]) * k }
end
local function SlotsOf(style)
    local slots = {}
    if style == "simple" then
        local y = SIMPLE.top
        for _, i in ipairs(SIMPLE.rows) do
            local r = SimpleRow(i, y)
            slots[#slots + 1] = { x = r.x + r.edgeL, fromTop = r.floor, w = r.mid, h = r.inner, strip = r }
            y = y + r.h + SIMPLE.gap
        end
        return slots
    end
    local caseW = (CASE.contentR - CASE.contentL) * CS
    for c = 1, 2 do
        local caseX = 24 + (c - 1) * (caseW + 6)
        for i = 1, #CASE.tops do
            slots[#slots + 1] = { x = caseX + (CASE.left - CASE.contentL) * CS, y = 20 + (1024 - CASE.floors[i]) * CS,
                w = (CASE.right - CASE.left) * CS, h = (CASE.floors[i] - CASE.tops[i]) * CS }
        end
    end
    return slots
end
Lib.SlotsOf = SlotsOf
local function SimpleSize()
    local y = SIMPLE.top
    local w = 0
    for _, i in ipairs(SIMPLE.rows) do
        local r = SimpleRow(i, y)
        y = y + r.h + SIMPLE.gap
        w = r.w
    end
    return math.floor(w + 2 * SIMPLE.left), math.floor(y + 24)
end

-- Modeles 3D du jeu (fichiers .m2 du client) pour chaque sorte d'ecrit. Les livres prennent la
-- couleur la plus proche de leur dos ; les lettres un parchemin ; les plaques une tablette.
local MODELS = {
    book = { { 200903, .45, .28, .16 }, { 200905, .55, .12, .10 }, { 200902, .14, .22, .45 },
             { 200904, .14, .36, .18 }, { 200901, .12, .12, .12 } },
    letter = 201113, -- world/goober/g_scroll01.m2
    plate = 201080,  -- world/goober/g_netablet.m2
}
Lib.MODELS = MODELS
function Lib.ModelFor(row)
    if row.kind == "letter" then return MODELS.letter end
    if row.kind == "plate" then return MODELS.plate end
    local c = Lib.Spine(row)
    local best, bd = MODELS.book[1][1], math.huge
    for _, b in ipairs(MODELS.book) do
        local d = (b[2] - c[1]) ^ 2 + (b[3] - c[2]) ^ 2 + (b[4] - c[3]) ^ 2
        if d < bd then best, bd = b[1], d end
    end
    return best
end
-- Charge un modele dans un cadre 3D. Seul SetModel doit reussir ; les reglages de camera sont
-- tentes un par un (certains manquent selon le client). La derniere erreur est gardee dans
-- Lib.modelErr pour le diagnostic.
local function LoadModel(m, id, pose)
    if not (m and m.SetModel) then Lib.modelErr = "no model frame"; return false end
    if m.ClearModel then pcall(m.ClearModel, m) end
    local ok, err = pcall(m.SetModel, m, id)
    if not ok then Lib.modelErr = tostring(err); return false end
    local function try(name, ...)
        if m[name] then
            local okc, e = pcall(m[name], m, ...)
            if not okc then Lib.modelErr = name .. ": " .. tostring(e) end
        end
    end
    try("SetPosition", 0, 0, 0)
    try("SetCamDistanceScale", pose.dist)
    try("SetFacing", math.rad(pose.facing))
    try("SetPitch", math.rad(pose.pitch))
    try("SetRoll", math.rad(pose.roll))
    return true
end
Lib.LECTERN_POSE = { dist = 1.6, facing = 90, pitch = -35, roll = 0 }
function Lib.ShowModel(cover, row)
    local m = cover.model
    local id = Lib.ModelFor(row)
    local shown = LoadModel(m, id, Lib.LECTERN_POSE)
    if m then m.fileID = shown and id or nil; m:SetShown(shown) end
    cover.open:SetShown(not shown)
end

-- Etageres en 3D : peu de livres par rangee (chaque modele coute), le reste va sur les pages
-- suivantes. Pose : le livre debout, le dos face a nous.
Lib.PER_ROW_3D = 6
Lib.SHELF_POSE = { dist = 1.0, facing = 0, pitch = 0, roll = 90 }
function Lib.ShowShelfModel(b, row)
    local m = b.model
    local id = Lib.ModelFor(row)
    local shown = LoadModel(m, id, Lib.SHELF_POSE)
    if m then m.fileID = shown and id or nil; m:SetShown(shown) end
    b.tex:SetShown(not shown); b.shade:SetShown(not shown)
    return shown
end
function Lib.Use3D() return DialogueWheelE_Library3D ~= false end

local function Build()
    if room then return end
    room = CreateFrame("Frame", "StorytaleLibraryFrame", UIParent, "BackdropTemplate")
    room:SetSize(W, H)
    room:SetPoint("CENTER")
    -- (au-dessus de la fenetre d'options, en FULLSCREEN : le bouton "Ouvrir la bibliotheque"
    -- l'ouvrait dessous, vu en jeu le 27/11)
    room:SetFrameStrata("FULLSCREEN_DIALOG")
    room:SetToplevel(true)
    room:SetMovable(true)
    room:SetClampedToScreen(true)
    room:EnableMouse(true)
    room:RegisterForDrag("LeftButton")
    room:SetScript("OnDragStart", function(self) if not DialogueWheelE_Locked then self:StartMoving() end end)
    room:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    room:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    function Lib.ApplyBg()
        if not room then return end
        local a = math.max(0, math.min(1, tonumber(DialogueWheelE_LibraryBg) or 1))
        if Lib.Style() == "simple" then a = 0 end -- (etagere seule : jamais de fond)
        Lib.bgAlpha = a
        room:SetBackdropColor(0.07, 0.045, 0.03, 0.97 * a)
        room:SetBackdropBorderColor(0.55, 0.38, 0.2, a)
    end
    Lib.ApplyBg()
    room:Hide()
    if UISpecialFrames then table.insert(UISpecialFrames, "StorytaleLibraryFrame") end
    Lib.frame = room
    ui = {}
    Lib.ui = ui
    local close = CreateFrame("Button", nil, room, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", room, "TOPRIGHT", -2, -2)

    -- Deux bibliotheques, cote a cote.
    ui.cases = {}
    local caseW = (CASE.contentR - CASE.contentL) * CS
    for c = 1, 2 do
        local x = 24 + (c - 1) * (caseW + 6)
        local t = room:CreateTexture(nil, "ARTWORK")
        t:SetTexture(ADDON .. "LibraryBookcase.png")
        t:SetSize(512 * CS, CASE_H)
        t:SetPoint("BOTTOMLEFT", room, "BOTTOMLEFT", x - CASE.contentL * CS, 20)
        ui.cases[c] = t
    end
    -- Style simple : une grande etagere. Chaque rangee en trois morceaux de la bibliotheque :
    -- bord gauche, milieu etire, bord droit.
    ui.strips = {}
    for _, sl in ipairs(SlotsOf("simple")) do
        local r = sl.strip
        local v0, v1 = CASE.tops[r.i] / 1024, (CASE.floors[r.i] + 18) / 1024
        local parts = {
            { CASE.contentL, CASE.left, r.x, r.edgeL },
            { CASE.left, CASE.right, r.x + r.edgeL, r.mid },
            { CASE.right, CASE.contentR, r.x + r.edgeL + r.mid, r.edgeR },
        }
        for _, pt in ipairs(parts) do
            local t = room:CreateTexture(nil, "ARTWORK")
            t:SetTexture(ADDON .. "LibraryBookcase.png")
            t:SetTexCoord(pt[1] / 512, pt[2] / 512, v0, v1)
            t:SetSize(pt[4], r.h)
            t:SetPoint("TOPLEFT", room, "TOPLEFT", pt[3], -r.top)
            t:Hide()
            ui.strips[#ui.strips + 1] = t
        end
    end
    -- Dos des livres (boutons), pris dans une reserve.
    ui.spines = {}
    function ui.Spine(i)
        local b = ui.spines[i]
        if b then return b end
        b = CreateFrame("Button", nil, room)
        b:SetFrameLevel(room:GetFrameLevel() + 3)
        local t = b:CreateTexture(nil, "ARTWORK")
        t:SetAllPoints()
        t:SetTexture("Interface\\Buttons\\WHITE8X8")
        b.tex = t
        local band = b:CreateTexture(nil, "OVERLAY")
        band:SetTexture("Interface\\Buttons\\WHITE8X8")
        band:SetPoint("LEFT"); band:SetPoint("RIGHT")
        band:SetHeight(2)
        band:SetPoint("TOP", b, "TOP", 0, -5)
        band:SetVertexColor(0.9, 0.75, 0.4, 0.55)
        b.band = band
        local band2 = b:CreateTexture(nil, "OVERLAY")
        band2:SetTexture("Interface\\Buttons\\WHITE8X8")
        band2:SetPoint("LEFT"); band2:SetPoint("RIGHT")
        band2:SetHeight(2)
        band2:SetPoint("BOTTOM", b, "BOTTOM", 0, 5)
        band2:SetVertexColor(0.9, 0.75, 0.4, 0.55)
        b.band2 = band2
        local shade = b:CreateTexture(nil, "OVERLAY")
        shade:SetTexture("Interface\\Buttons\\WHITE8X8")
        shade:SetPoint("TOPRIGHT"); shade:SetPoint("BOTTOMRIGHT")
        shade:SetWidth(2)
        shade:SetVertexColor(0, 0, 0, 0.35)
        b.shade = shade
        -- (le vrai modele 3D du livre, debout sur l'etagere ; le dos peint reste si le modele manque)
        local okm, m = pcall(CreateFrame, "PlayerModel", nil, b)
        if okm and m then
            m:SetPoint("TOPLEFT", -6, 4); m:SetPoint("BOTTOMRIGHT", 6, 0)
            m:EnableMouse(false)
            b.model = m
        end
        b:SetScript("OnEnter", function(self)
            local r = self.row
            if not r then return end
            self:SetPoint("BOTTOMLEFT", room, "BOTTOMLEFT", self.x, self.y + 4)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(r.title, 1, 0.86, 0.55, 1, true)
            if r.locked then
                GameTooltip:AddLine(L.LIB_NOT_FOUND or "not found yet", 0.7, 0.7, 0.7)
            elseif r.entry and r.entry.z then
                GameTooltip:AddLine(r.entry.z, 0.85, 0.85, 0.85)
            end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function(self)
            self:SetPoint("BOTTOMLEFT", room, "BOTTOMLEFT", self.x, self.y)
            if GameTooltip then GameTooltip:Hide() end
        end)
        b:SetScript("OnClick", function(self)
            if not self.row or self.row.locked then return end
            if Lib.Style() == "simple" then
                Lib.Read(self.row.key)
            else
                -- le livre quitte l'etagere et vient s'ouvrir sur le pupitre
                state.key = self.row.key
                if GameTooltip then GameTooltip:Hide() end
                Refresh()
                if ui.cover.appear then ui.cover.appear:Stop(); ui.cover.appear:Play() end
            end
        end)
        ui.spines[i] = b
        return b
    end
    room:EnableMouseWheel(true)
    room:SetScript("OnMouseWheel", function(_, delta)
        state.shelf = state.shelf - delta
        Refresh()
    end)

    -- Mur de droite : titre, compteur, recherche, filtres, tri, etageres precedentes / suivantes.
    local right = 24 + 2 * (caseW + 6) + 30
    ui.right = right
    local title = room:CreateFontString(nil, "OVERLAY")
    title:SetPoint("TOPLEFT", room, "TOPLEFT", right, -22)
    Font(title, 22, GOLD)
    title:SetShadowOffset(1, -1)
    title:SetText(L.LIBRARY or "Library")
    ui.title = title
    local count = room:CreateFontString(nil, "OVERLAY")
    count:SetPoint("LEFT", title, "RIGHT", 12, -2)
    Font(count, 13, PALE)
    ui.count = count
    local search = CreateFrame("EditBox", nil, room, "SearchBoxTemplate")
    search:SetSize(W - right - 40, 20)
    search:SetPoint("TOPLEFT", room, "TOPLEFT", right + 6, -56)
    search:SetAutoFocus(false)
    search:HookScript("OnTextChanged", function(self)
        state.search = self:GetText() or ""
        state.shelf = 1
        Refresh()
    end)
    ui.search = search
    local x = right
    ui.filters = {}
    for _, f in ipairs({ { "all", L.LIB_ALL or "All" }, { "book", L.LIB_BOOKS or "Books" },
        { "letter", L.LIB_LETTERS or "Letters" }, { "plate", L.LIB_PLATES or "Plaques" } }) do
        local b = TextButton(room, f[2], function() state.filter = f[1]; state.shelf = 1; Refresh() end)
        b:SetPoint("TOPLEFT", room, "TOPLEFT", x, -84)
        b.id = f[1]
        x = x + b:GetWidth() + 6
        ui.filters[#ui.filters + 1] = b
    end
    local sort = TextButton(room, L.LIB_SORT_AZ or "A-Z", function()
        state.sort = state.sort == "az" and "recent" or "az"
        state.shelf = 1
        Refresh()
    end)
    sort:SetPoint("TOPRIGHT", room, "TOPRIGHT", -30, -84)
    ui.sort = sort
    -- Etageres suivantes / precedentes (sous les bibliotheques).
    local up = TextButton(room, "<", function() state.shelf = state.shelf - 1; Refresh() end)
    local down = TextButton(room, ">", function() state.shelf = state.shelf + 1; Refresh() end)
    local shelfNum = room:CreateFontString(nil, "OVERLAY")
    shelfNum:SetPoint("BOTTOM", room, "BOTTOMLEFT", 24 + caseW + 3, 6)
    Font(shelfNum, 12, PALE)
    up:SetPoint("RIGHT", shelfNum, "LEFT", -6, 0)
    down:SetPoint("LEFT", shelfNum, "RIGHT", 6, 0)
    ui.up, ui.down, ui.shelfNum = up, down, shelfNum
    ui.close = close

    -- Le pupitre, et le livre presente dessus.
    local lec = room:CreateTexture(nil, "ARTWORK")
    lec:SetTexture(ADDON .. "LibraryLectern.png")
    lec:SetSize(LECTERN.size, LECTERN.size)
    local lx = right + (W - right - 30 - LECTERN.size) / 2
    lec:SetPoint("BOTTOMLEFT", room, "BOTTOMLEFT", lx, 12)
    ui.lectern = lec
    local k = LECTERN.size / 1024
    local tp = LECTERN.top
    local cover = CreateFrame("Button", nil, room)
    cover:SetFrameLevel(room:GetFrameLevel() + 4)
    cover:SetSize((tp[2] - tp[1]) * k * 0.62, (tp[4] - tp[3]) * k * 0.95)
    cover:SetPoint("CENTER", room, "BOTTOMLEFT", lx + (tp[1] + tp[2]) / 2 * k, 12 + LECTERN.size - (tp[3] + tp[4]) / 2 * k + 6)
    local ct = cover:CreateTexture(nil, "ARTWORK")
    ct:SetAllPoints()
    ct:SetTexture("Interface\\Buttons\\WHITE8X8")
    cover.tex = ct
    ct:Hide() -- (couleur du livre : gardee pour plus tard, la double page la remplace)
    local icon = cover:CreateTexture(nil, "OVERLAY", nil, 2)
    icon:SetSize(22, 22)
    icon:SetPoint("BOTTOMRIGHT", cover, "BOTTOMRIGHT", 4, -2)
    cover.icon = icon
    -- Le livre presente est le vrai modele 3D du jeu, ferme, pose sur le pupitre. Un clic l'ouvre
    -- dans le grand livre peint. Si le modele ne peut pas etre charge, la double page peinte reste.
    local open = cover:CreateTexture(nil, "OVERLAY", nil, 1)
    open:SetPoint("TOPLEFT", -10, 8); open:SetPoint("BOTTOMRIGHT", 10, -6)
    open:SetTexture(ADDON .. "BookSpread.png")
    open:SetTexCoord(0, 1, 0, 576 / 1024)
    open:Hide()
    cover.open = open
    local ok, m = pcall(CreateFrame, "PlayerModel", nil, cover)
    if ok and m then
        m:SetPoint("TOPLEFT", -40, 50); m:SetPoint("BOTTOMRIGHT", 40, -30)
        m:EnableMouse(false)
        cover.model = m
    end
    local ag = cover.CreateAnimationGroup and cover:CreateAnimationGroup()
    if ag then
        local fade = ag:CreateAnimation("Alpha")
        fade:SetFromAlpha(0); fade:SetToAlpha(1); fade:SetDuration(0.35)
        cover.appear = ag
    end
    cover:SetScript("OnClick", function() if state.key then Lib.Read(state.key) end end)
    cover:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L.LIB_READ or "Read", 1, 1, 1)
        GameTooltip:Show()
    end)
    cover:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    ui.cover = cover
    local ft = room:CreateFontString(nil, "OVERLAY")
    ft:SetPoint("BOTTOM", room, "BOTTOMLEFT", lx + LECTERN.size / 2, 12 + LECTERN.size + 34)
    ft:SetWidth(W - right - 40)
    Font(ft, 16, GOLD)
    ft:SetShadowOffset(1, -1)
    ui.featured = ft
    local fm = room:CreateFontString(nil, "OVERLAY")
    fm:SetPoint("TOP", ft, "BOTTOM", 0, -4)
    fm:SetWidth(W - right - 40)
    Font(fm, 12, PALE)
    ui.featuredMeta = fm
    local empty = room:CreateFontString(nil, "OVERLAY")
    empty:SetPoint("CENTER", room, "BOTTOMLEFT", lx + LECTERN.size / 2, 12 + LECTERN.size + 40)
    empty:SetWidth(W - right - 40)
    Font(empty, 13, PALE)
    ui.empty = empty

    -- Le livre ouvert pour la lecture : deux pages du grand livre peint.
    local RW, RH = 900, 506
    local RS = RW / 1024
    reader = CreateFrame("Frame", "StorytaleLibraryReader", room)
    reader:SetSize(RW, RH)
    reader:SetPoint("CENTER", UIParent, "CENTER")
    reader:SetFrameLevel(room:GetFrameLevel() + 20)
    reader:EnableMouse(true)
    reader:Hide()
    Lib.reader = reader
    local rb = reader:CreateTexture(nil, "BACKGROUND")
    rb:SetAllPoints()
    rb:SetTexture(ADDON .. "BookSpread.png")
    rb:SetTexCoord(0, 1, 0, 576 / 1024)
    local PAGES = { { 120 * RS + 22, 512 * RS - 24 }, { 516 * RS + 26, 930 * RS - 28 } }
    local TOP, BOTTOM = 40 * RS + 24, 490 * RS - 22
    local bt = reader:CreateFontString(nil, "OVERLAY")
    bt:SetPoint("TOPLEFT", reader, "TOPLEFT", PAGES[1][1], -TOP)
    bt:SetWidth(PAGES[1][2] - PAGES[1][1])
    bt:SetJustifyH("LEFT")
    Font(bt, 16, HEAD)
    ui.bookTitle = bt
    local meta = reader:CreateFontString(nil, "OVERLAY")
    meta:SetPoint("TOPLEFT", bt, "BOTTOMLEFT", 0, -2)
    meta:SetWidth(PAGES[1][2] - PAGES[1][1])
    meta:SetJustifyH("LEFT")
    Font(meta, 11, INK)
    meta:SetAlpha(0.75)
    ui.meta = meta
    ui.bodies = {}
    for p = 1, 2 do
        local w = PAGES[p][2] - PAGES[p][1]
        local top = TOP + (p == 1 and 48 or 0)
        local sc = CreateFrame("ScrollFrame", nil, reader)
        sc:SetPoint("TOPLEFT", reader, "TOPLEFT", PAGES[p][1], -top)
        sc:SetSize(w, BOTTOM - top - 24)
        local child = CreateFrame("Frame", nil, sc)
        child:SetSize(w, 10)
        sc:SetScrollChild(child)
        sc:EnableMouseWheel(true)
        sc:SetScript("OnMouseWheel", function(self, d)
            self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange() or 0, (self:GetVerticalScroll() or 0) - d * 30)))
        end)
        local body = child:CreateFontString(nil, "OVERLAY")
        body:SetPoint("TOPLEFT")
        body:SetWidth(w)
        body:SetJustifyH("LEFT")
        body:SetJustifyV("TOP")
        body:SetSpacing(3)
        Font(body, 14, INK)
        ui.bodies[p] = { scroll = sc, child = child, body = body }
    end
    ui.body, ui.body2 = ui.bodies[1].body, ui.bodies[2].body
    local function Turn(d)
        state.page = state.page + d * 2
        for _, b in ipairs(ui.bodies) do b.scroll:SetVerticalScroll(0) end
        RefreshReader()
    end
    local prev = TextButton(reader, "<", function() Turn(-1) end, INK)
    local nextB = TextButton(reader, ">", function() Turn(1) end, INK)
    local num = reader:CreateFontString(nil, "OVERLAY")
    num:SetPoint("BOTTOM", reader, "BOTTOM", 0, RH - BOTTOM)
    Font(num, 12, INK)
    prev:SetPoint("RIGHT", num, "LEFT", -10, 0)
    nextB:SetPoint("LEFT", num, "RIGHT", 10, 0)
    ui.prev, ui.next, ui.num = prev, nextB, num
    local back = CreateFrame("Button", nil, reader, "UIPanelCloseButton")
    back:SetPoint("TOPRIGHT", reader, "TOPLEFT", 930 * RS + 14, -TOP + 18)
    back:SetScript("OnClick", function() reader:Hide() end)
    ui.back = back
end

-- Met la fenetre au style choisi : la piece entiere, ou les rangees seules (plus petite).
local function ApplyStyle()
    local style = Lib.Style()
    if ui.style == style then return end
    ui.style = style
    local full = style == "room"
    for _, t in ipairs(ui.cases) do t:SetShown(full) end
    for _, t in ipairs(ui.strips) do t:SetShown(not full) end
    for _, f in ipairs({ ui.lectern, ui.cover, ui.featured, ui.featuredMeta }) do f:SetShown(full) end
    local w, h
    if full then
        w, h = W, H
    else
        w, h = SimpleSize()
    end
    room:SetSize(w, h)
    Lib.ApplyBg()
    local left = full and ui.right or 22
    ui.title:ClearAllPoints()
    ui.title:SetPoint("TOPLEFT", room, "TOPLEFT", left, -22)
    ui.search:ClearAllPoints()
    ui.search:SetPoint("TOPLEFT", room, "TOPLEFT", left + 6, -56)
    ui.search:SetWidth(full and (W - ui.right - 40) or 180)
    local x = full and left or (left + 200)
    for _, b in ipairs(ui.filters) do
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", room, "TOPLEFT", x, full and -84 or -58)
        x = x + b:GetWidth() + 6
    end
    ui.sort:ClearAllPoints()
    ui.sort:SetPoint("TOPRIGHT", room, "TOPRIGHT", -30, full and -84 or -58)
    ui.shelfNum:ClearAllPoints()
    if full then
        local caseW = (CASE.contentR - CASE.contentL) * CS
        ui.shelfNum:SetPoint("BOTTOM", room, "BOTTOMLEFT", 24 + caseW + 3, 6)
    else
        ui.shelfNum:SetPoint("BOTTOM", room, "BOTTOM", 0, 8)
    end
    ui.empty:ClearAllPoints()
    if full then
        ui.empty:SetPoint("CENTER", ui.lectern, "TOP", 0, 40)
    else
        ui.empty:SetPoint("CENTER", room, "CENTER", 0, -20)
    end
end
Lib.ApplyStyle = ApplyStyle

-- Le livre ouvert : pages state.page et state.page + 1.
function RefreshReader()
    if not reader or not reader:IsShown() then return end
    local row
    for _, r in ipairs((Lib.List("all", "", "az"))) do if r.key == state.readKey then row = r end end
    if not row then reader:Hide() return end
    local pages, complete = Lib.Pages(row)
    local n = #pages
    state.page = math.max(1, math.min(state.page, math.max(1, n)))
    if state.page % 2 == 0 then state.page = state.page - 1 end
    ui.bookTitle:SetText(row.title)
    local e = row.entry
    local meta = {}
    if e and e.z then meta[#meta + 1] = e.z end
    if e and e.d and date and e.d > 0 then meta[#meta + 1] = date("%d/%m/%Y", e.d) end
    if not complete then meta[#meta + 1] = L.LIB_PARTIAL or "unfinished: read it further in game to keep the next pages" end
    ui.meta:SetText(table.concat(meta, " - "))
    local size = tonumber(DialogueWheelE_FontSize) or 14
    for p = 1, 2 do
        local b = ui.bodies[p]
        Font(b.body, size, INK)
        local text = pages[state.page + p - 1] or ""
        if n == 0 and p == 1 then text = L.LIB_NO_TEXT or "Read before the library existed: open it again in game to keep its text." end
        b.body:SetText(text)
        b.child:SetHeight(math.max(10, (b.body:GetStringHeight() or 10) + 6))
    end
    ui.num:SetText(n > 2 and (state.page .. "-" .. math.min(n, state.page + 1) .. " / " .. n .. (complete and "" or "+")) or "")
    ui.prev:SetShown(state.page > 1)
    ui.next:SetShown(state.page + 1 < n)
end

-- Le dernier ecrit lu (pour le pupitre, a l'ouverture).
local function Latest(rows)
    local best
    for _, r in ipairs(rows) do
        if r.entry and not r.locked and (not best or (r.entry.d or 0) > (best.entry.d or 0)) then best = r end
    end
    return best
end

function Refresh()
    if not room then return end
    ApplyStyle()
    local rows, found, total = Lib.List(state.filter, state.search, state.sort)
    ui.count:SetText(found .. " / " .. total)
    for _, b in ipairs(ui.filters) do
        local on = b.id == state.filter
        b.color = on and GOLD or PALE
        b.text:SetTextColor(b.color[1], b.color[2], b.color[3])
    end
    ui.sort:SetText(state.sort == "az" and (L.LIB_SORT_AZ or "A-Z") or (L.LIB_SORT_RECENT or "Recent"))
    ui.sort:SetWidth((ui.sort.text:GetStringWidth() or 30) + 10)

    -- Dos des livres, etagere apres etagere ; une "vue" = les deux bibliotheques pleines.
    -- Pupitre : le livre choisi, sinon le dernier lu (connu avant de ranger les etageres : il
    -- n'y est pas).
    local all = Lib.List("all", "", "az")
    local cur2
    for _, r in ipairs(all) do if r.key == state.key and not r.locked then cur2 = r end end
    if not cur2 then cur2 = Latest(all); state.key = cur2 and cur2.key or nil end
    local style = Lib.Style()
    local slots = SlotsOf(style)
    local winH = room:GetHeight()
    local views, cur = { 1 }, { slot = 1, x = 0 }
    local placed = {}
    local use3d = Lib.Use3D()
    cur.n = 0
    for idx, row in ipairs(rows) do
        local _, w = Lib.Spine(row)
        if use3d then w = math.floor(slots[cur.slot].w / Lib.PER_ROW_3D) - 1 end
        if cur.x + w > slots[cur.slot].w - 2 or (use3d and cur.n >= Lib.PER_ROW_3D) then
            cur.slot, cur.x, cur.n = cur.slot + 1, 0, 0
            if use3d then w = math.floor(slots[math.min(cur.slot, #slots)].w / Lib.PER_ROW_3D) - 1 end
            if cur.slot > #slots then
                views[#views + 1] = idx
                cur.slot = 1
            end
        end
        placed[idx] = { view = #views, slot = cur.slot, x = cur.x, w = w }
        cur.x = cur.x + w + 1
        cur.n = cur.n + 1
    end
    state.shelf = math.max(1, math.min(state.shelf, #views))
    local used = 0
    for idx, row in ipairs(rows) do
        local pl = placed[idx]
        -- (style complet : le livre pose sur le pupitre a quitte sa place, qui reste vide)
        local onLectern = style == "room" and row.key == state.key
        if pl.view == state.shelf and not onLectern then
            used = used + 1
            local b = ui.Spine(used)
            local color, w, hf = Lib.Spine(row)
            local sl = slots[pl.slot]
            if use3d then w, hf = pl.w, 0.95 end
            local h = math.floor(sl.h * hf)
            b.x = math.floor(sl.x + pl.x)
            b.y = math.floor(sl.y or (winH - sl.fromTop))
            b:ClearAllPoints()
            b:SetSize(w, h)
            b:SetPoint("BOTTOMLEFT", room, "BOTTOMLEFT", b.x, b.y)
            b.tex:SetVertexColor(color[1], color[2], color[3], 1)
            local is3d = use3d and Lib.ShowShelfModel(b, row)
            if not use3d and b.model then b.model:Hide(); b.tex:Show(); b.shade:Show() end
            b.band:SetShown(row.kind == "book" and not is3d)
            b.band2:SetShown(row.kind == "book" and not is3d)
            b:SetAlpha(row.locked and 0.28 or 1)
            b.row = row
            b:Show()
        end
    end
    for i = used + 1, #ui.spines do ui.spines[i]:Hide(); ui.spines[i].row = nil end
    ui.shelfNum:SetText(#views > 1 and (state.shelf .. " / " .. #views) or "")
    ui.up:SetShown(state.shelf > 1)
    ui.down:SetShown(state.shelf < #views)

    if Lib.Style() == "simple" then
        ui.empty:SetText(found == 0 and (L.LIB_EMPTY or "Every book, letter or plaque you open is kept here, whole, to read again.") or "")
    elseif cur2 then
        local color = Lib.Spine(cur2)
        ui.cover.tex:SetVertexColor(color[1], color[2], color[3], 1)
        -- (icone de l'objet du sac d'ou vient l'ecrit, s'il y en a un)
        local icon = cur2.entry and cur2.entry.i and GetItemIcon and GetItemIcon(cur2.entry.i)
        ui.cover.icon:SetTexture(icon)
        ui.cover.icon:SetShown(icon ~= nil)
        Lib.ShowModel(ui.cover, cur2)
        ui.cover:Show()
        ui.featured:SetText(cur2.title)
        local e = cur2.entry
        local meta = {}
        if e and e.z then meta[#meta + 1] = e.z end
        if e and e.d and date and e.d > 0 then meta[#meta + 1] = date("%d/%m/%Y", e.d) end
        ui.featuredMeta:SetText(table.concat(meta, " - "))
        ui.empty:SetText("")
    else
        ui.cover:Hide()
        ui.featured:SetText("")
        ui.featuredMeta:SetText("")
        ui.empty:SetText(found == 0 and (L.LIB_EMPTY or "Every book, letter or plaque you open is kept here, whole, to read again.") or "")
    end
    RefreshReader()
end
Lib.Refresh = Refresh

-- Ouvre l'ecrit `key` dans le grand livre.
function Lib.Read(key)
    Build()
    state.readKey, state.page = key, 1
    reader:Show()
    RefreshReader()
end

function Lib.Open()
    Build()
    room:Show()
    Refresh()
end
function Lib.Toggle()
    Build()
    if room:IsShown() then room:Hide() else Lib.Open() end
end
-- Ouvre la bibliotheque sur l'ecrit `title`, ouvert pour la lecture.
function Lib.Show(title)
    local key = DWE.BookKey and DWE.BookKey(title)
    Lib.Open()
    state.key = key
    Refresh()
    if key then Lib.Read(key) end
end
