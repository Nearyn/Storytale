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
-- Titres connus de Spoken (cle -> livre), calcules une seule fois : la liste est relue a chaque
-- rafraichissement de la bibliotheque.
local spokenTitles
local function SpokenTitles()
    local d = SpokenData()
    if not d then return nil end
    if spokenTitles and spokenTitles.d == d then return spokenTitles.map end
    local map = {}
    for _, b in pairs(d.books) do
        local k = type(b) == "table" and DWE.BookKey(b.title)
        if k and not map[k] then map[k] = b end
    end
    spokenTitles = { d = d, map = map }
    return map
end
Lib.SpokenTitles = SpokenTitles

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
        -- (repris d'avant la bibliotheque, sans date : relu en jeu, il prend celle-ci)
        if (e.d or 0) == 0 then e.d = now end
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
-- Nettoyage (une fois) : les titres importes sans aucun texte (lus avant la bibliotheque, dans
-- une autre langue que celle de Spoken) sont retires ; relus en jeu, ils reviennent entiers.
function Lib.CleanEmpty()
    local n = 0
    for _, shared in ipairs({ false, true }) do
        local lib = Store(shared)
        if not lib["\0cleaned"] then
            lib["\0cleaned"] = true
            for key, e in pairs(lib) do
                if type(e) == "table" and e.d == 0 then
                    local any = false
                    for _, t in pairs(e.p or {}) do if type(t) == "string" and t ~= "" then any = true end end
                    if not any then lib[key] = nil; n = n + 1 end
                end
            end
        end
    end
    return n
end
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
    -- Seulement les ecrits dont on a le texte (Spoken) : un titre sans texte ne se relit pas,
    -- et un livre lu jadis dans une autre langue n'a que son titre dans cette langue.
    for key, state in pairs(read) do
        if type(key) == "string" and not lib[key] and titles[key] then
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
    if event == "PLAYER_LOGIN" then
        pcall(Lib.CleanEmpty); pcall(Lib.ImportRead)
        -- Preparee en coulisse peu apres la connexion (fenetre, liste, modeles des etageres
        -- charges un par un) : la premiere ouverture ne fige plus le jeu.
        if C_Timer and C_Timer.After then C_Timer.After(4, function() pcall(Lib.Warm) end) end
        return
    end
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
local OBJ_KIND_OF -- (table des objets du monde, plus bas)
local function Kind(e)
    if e.m and DWE.PLATES and DWE.PLATES[e.m] then return "plate" end
    -- Objet du monde connu : plaque, stele, statue, tombe... ou affiche, ou livre.
    local k = OBJ_KIND_OF and OBJ_KIND_OF(e.o, e.t)
    if k then return k end
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
    local titles = SpokenTitles()
    if titles then
        total = 0
        for k, b in pairs(titles) do
            total = total + 1
            -- (pas encore trouves : seulement comptes, pas ranges ; l'option "Tous les livres"
            -- les met sur les etageres, lisibles)
            if not seen[k] and DialogueWheelE_LibraryUnlock == true then
                local kind = OBJ_KIND_OF(nil, b.title) or (#b.pages > 1 and "book" or "letter")
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
        -- (plaques, steles, monuments, tombes : pas sur les etageres, ils auront leur propre vue)
        local okKind = (not filter or filter == "all") and r.kind ~= "plate" or filter == r.kind
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
local LECTERN = { size = 360, top = { 187, 861, 18, 215 } } -- (plateau mesure sur l'image)

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
local SIMPLE = { rows = { 2, 3, 4, 5, 6, 7 }, scale = 0.7, wide = 2.2, gap = 0, top = 150, left = 14 }
-- (haut et bas du meuble dans l'image : corniche, et socle avec ses pieds)
local CAP_TOP, CAP_BOT = { 104, 161 }, { 964, 1014 }
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
                w = (CASE.right - CASE.left) * CS, h = (CASE.floors[i] - CASE.tops[i]) * CS, box = "case" .. c }
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
    letter = 201113, -- world/goober/g_scroll01.m2 (ouvert)
    rolled = 198453, -- world/generic/human/passive doodads/scrolls/scrollb01.m2 (enroule)
    plate = 201080,  -- world/goober/g_netablet.m2
}
Lib.MODELS = MODELS
-- Le vrai modele de chaque ecrit pose dans le monde : objet du jeu (entree) -> fichier du modele.
-- Les livres du monde sont ouverts : on prend la meme reliure, fermee (meme couleur, meme
-- forme). Plaques, steles, statues, tombes : leur propre modele. Titres anglais -> objet, pour
-- les ecrits gardes avant que l'objet soit note. (Table tiree des donnees du jeu Classic.)
local OBJ_MODEL = {
    [37] = 189534, -- Eliza\'s Tombstone
    [1726] = 198409, -- Missing: Corporal Keeshan
    [2082] = 204142, -- Uther the Lightbringer
    [19025] = 201080, -- Ancient Inscription
    [21004] = 199349, -- Monument to Grom Hellscream
    [21581] = 200902, -- Aftermath of the Second War
    [21582] = 200904, -- Beyond the Dark Portal
    [21583] = 200903, -- The Kaldorei and the Well of Eternity
    [24777] = 189534, -- Yuriv\'s Tombstone
    [25329] = 199983, -- Kurdran Wildhammer
    [25330] = 199983, -- General Turalyon
    [25331] = 199983, -- Ranger Captain Alleria Windrunner
    [25332] = 199983, -- Danath Trollbane
    [25333] = 199983, -- Archmage Khadgar of the Kirin Tor
    [123463] = 200904, -- Baelog\'s Journal
    [124374] = 190929, -- Horatio Montgomery, M.D.
    [164820] = 203051, -- Dark Keeper Nameplate
    [164821] = 203051, -- Dark Keeper Nameplate
    [164822] = 203051, -- Dark Keeper Nameplate
    [164823] = 203051, -- Dark Keeper Nameplate
    [164824] = 203051, -- Dark Keeper Nameplate
    [164825] = 203051, -- Dark Keeper Nameplate
    [174746] = 199985, -- Etched Note
    [175658] = 199983, -- The Armor of Mannoroth
    [175659] = 199985, -- Here Lies King Terenas Menethil II
    [175679] = 199983, -- The Skull of Tyrannistrasz
    [175680] = 199983, -- Fossilized Egg
    [175681] = 199983, -- Roc Talon
    [175682] = 199983, -- Geru Strider
    [175683] = 199983, -- Toothgnasher\'s Skeleton
    [175684] = 199983, -- Saurial Egg
    [175685] = 199983, -- Pteradon Skeleton
    [175686] = 199983, -- Highborne Astrolabe
    [175687] = 199983, -- Uldaman Relics
    [175688] = 199983, -- Horde Catapult
    [175689] = 199983, -- Uldaman Reliefs
    [175724] = 200901, -- Sargeras and the Betrayal
    [175725] = 200902, -- The Old Gods and the Ordering of Azeroth
    [175726] = 200903, -- Charge of the Dragonflights
    [175727] = 200904, -- The War of the Ancients
    [175729] = 200904, -- Mount Hyjal and Illidan\'s Gift
    [175730] = 200904, -- The World Tree and the Emerald Dream
    [175731] = 200902, -- Exile of the High Elves
    [175732] = 200903, -- The Sentinels and the Long Vigil
    [175733] = 200905, -- The Founding of Quel\'Thalas
    [175734] = 200904, -- Arathor and the Troll Wars
    [175735] = 200901, -- The Guardians of Tirisfal
    [175736] = 200902, -- Ironforge - the Awakening of the Dwarves
    [175737] = 200903, -- The Seven Kingdoms
    [175738] = 200905, -- Aegwynn and the Dragon Hunt
    [175739] = 200903, -- War of the Three Hammers
    [175740] = 200904, -- The Last Guardian
    [175741] = 200901, -- Kil\'jaeden and the Shadow Pact
    [175742] = 200903, -- Rise of the Horde
    [175745] = 200902, -- The Dark Portal and the Fall of Stormwin
    [175746] = 200902, -- The Alliance of Lordaeron
    [175747] = 200905, -- The Invasion of Draenor
    [175748] = 200901, -- The Birth of the Lich King
    [175749] = 200904, -- Icecrown and the Frozen Throne
    [175750] = 200903, -- The Battle of Grim Batol
    [175751] = 200905, -- Lethargy of the Orcs
    [175752] = 200904, -- The New Horde
    [175753] = 200902, -- War of the Spider
    [175754] = 200901, -- Kel\'Thuzad and the Forming of the Scour
    [175756] = 200901, -- The Scourge of Lordaeron
    [175757] = 200904, -- Sunwell - The Fall of Quel\'Thalas
    [175758] = 200903, -- Archimonde\'s Return and the Flight to K
    [175759] = 200901, -- The Betrayer Ascendant
    [175760] = 200905, -- Rise of the Blood Elves
    [175761] = 200904, -- Civil War in the Plaguelands
    [175762] = 200903, -- The Lich King Triumphant
    [175763] = 200903, -- Old Hatreds - The Colonization of Kalimd
    [175771] = 199983, -- Arellas Fireleaf
    [175772] = 199983, -- Admiral Barean Westwind
    [175773] = 199983, -- Dorgar Stoenbrow
    [175774] = 199983, -- Fellari Swiftarrow
    [175775] = 199983, -- Ferren Marcus
    [175776] = 199983, -- Harthal Truesight
    [175777] = 199983, -- Holia Sunshield
    [175778] = 199983, -- Invar One-Arm
    [175779] = 199983, -- Orman of Stromgarde
    [175780] = 199983, -- Valea Twinblades
    [175781] = 199983, -- Yana Bloodspear
    [175854] = 200904, -- The Twin Empires
    [175855] = 200902, -- Empires\' Fall
    [175856] = 200905, -- Wrath of Soulflayer
    [175933] = 190635, -- Decorated Headstone
    [177199] = 199983, -- Archbishop Alonsus Faol
    [177200] = 199983, -- King Llane I of the House of Wrynn
    [177201] = 199983, -- Grand Admiral Daelin Proudmoore
    [177202] = 199983, -- Lady Mara Fordragon
    [177204] = 200552, -- Sorrow of the Earthmother
    [177205] = 200552, -- Forestlord and the first Druids
    [177207] = 200554, -- Mists of Dawn
    [177208] = 200554, -- The White Stag and the Moon
    [177209] = 200554, -- Hatred of the Centaur
    [177222] = 199983, -- Pteradon Skeleton
    [179706] = 198022, -- A Treatise on Military Ranks
    [179707] = 198026, -- Military Ranks of the Horde & Alliance
    [179735] = 199981, -- Alliance Military Ranks
    [179741] = 199983, -- Horde Military Ranks
    [179909] = 199989, -- Rock of Durotan
    [180367] = 200640, -- Altar of Zanza
    [181062] = 189536, -- In Loving Memory
    [181475] = 199983, -- Monument of Remembrance
    [181573] = 189817, -- Jar of ashes
    [181895] = 198023, -- Trans-dimensional Ship Repair for Simple
    [182203] = 200904, -- The Green Hills of Stranglethorn
}
local OBJ_KIND = {
    [37] = "plate",
    [1726] = "letter",
    [2082] = "plate",
    [19025] = "plate",
    [21004] = "plate",
    [21581] = "book",
    [21582] = "book",
    [21583] = "book",
    [24777] = "plate",
    [25329] = "plate",
    [25330] = "plate",
    [25331] = "plate",
    [25332] = "plate",
    [25333] = "plate",
    [123463] = "book",
    [124374] = "plate",
    [164820] = "plate",
    [164821] = "plate",
    [164822] = "plate",
    [164823] = "plate",
    [164824] = "plate",
    [164825] = "plate",
    [174746] = "plate",
    [175658] = "plate",
    [175659] = "plate",
    [175679] = "plate",
    [175680] = "plate",
    [175681] = "plate",
    [175682] = "plate",
    [175683] = "plate",
    [175684] = "plate",
    [175685] = "plate",
    [175686] = "plate",
    [175687] = "plate",
    [175688] = "plate",
    [175689] = "plate",
    [175724] = "book",
    [175725] = "book",
    [175726] = "book",
    [175727] = "book",
    [175729] = "book",
    [175730] = "book",
    [175731] = "book",
    [175732] = "book",
    [175733] = "book",
    [175734] = "book",
    [175735] = "book",
    [175736] = "book",
    [175737] = "book",
    [175738] = "book",
    [175739] = "book",
    [175740] = "book",
    [175741] = "book",
    [175742] = "book",
    [175745] = "book",
    [175746] = "book",
    [175747] = "book",
    [175748] = "book",
    [175749] = "book",
    [175750] = "book",
    [175751] = "book",
    [175752] = "book",
    [175753] = "book",
    [175754] = "book",
    [175756] = "book",
    [175757] = "book",
    [175758] = "book",
    [175759] = "book",
    [175760] = "book",
    [175761] = "book",
    [175762] = "book",
    [175763] = "book",
    [175771] = "plate",
    [175772] = "plate",
    [175773] = "plate",
    [175774] = "plate",
    [175775] = "plate",
    [175776] = "plate",
    [175777] = "plate",
    [175778] = "plate",
    [175779] = "plate",
    [175780] = "plate",
    [175781] = "plate",
    [175854] = "book",
    [175855] = "book",
    [175856] = "book",
    [175933] = "plate",
    [177199] = "plate",
    [177200] = "plate",
    [177201] = "plate",
    [177202] = "plate",
    [177204] = "letter",
    [177205] = "letter",
    [177207] = "letter",
    [177208] = "letter",
    [177209] = "letter",
    [177222] = "plate",
    [179706] = "book",
    [179707] = "book",
    [179735] = "plate",
    [179741] = "plate",
    [179909] = "plate",
    [180367] = "plate",
    [181062] = "plate",
    [181475] = "plate",
    [181573] = "plate",
    [181895] = "book",
    [182203] = "book",
}
local TITLE_OBJ = {
    ["Eliza's Tombstone"] = 37,
    ["Missing: Corporal Keeshan"] = 1726,
    ["Uther the Lightbringer"] = 2082,
    ["Ancient Inscription"] = 19025,
    ["Monument to Grom Hellscream"] = 21004,
    ["Aftermath of the Second War"] = 21581,
    ["Beyond the Dark Portal"] = 21582,
    ["The Kaldorei and the Well of Eternity"] = 21583,
    ["Yuriv's Tombstone"] = 24777,
    ["Kurdran Wildhammer"] = 25329,
    ["General Turalyon"] = 25330,
    ["Ranger Captain Alleria Windrunner"] = 25331,
    ["Danath Trollbane"] = 25332,
    ["Archmage Khadgar of the Kirin Tor"] = 25333,
    ["Baelog's Journal"] = 123463,
    ["Horatio Montgomery, M.D."] = 124374,
    ["Dark Keeper Nameplate"] = 164820,
    ["Dark Keeper Nameplate"] = 164821,
    ["Dark Keeper Nameplate"] = 164822,
    ["Dark Keeper Nameplate"] = 164823,
    ["Dark Keeper Nameplate"] = 164824,
    ["Dark Keeper Nameplate"] = 164825,
    ["Etched Note"] = 174746,
    ["The Armor of Mannoroth"] = 175658,
    ["Here Lies King Terenas Menethil II"] = 175659,
    ["The Skull of Tyrannistrasz"] = 175679,
    ["Fossilized Egg"] = 175680,
    ["Roc Talon"] = 175681,
    ["Geru Strider"] = 175682,
    ["Toothgnasher's Skeleton"] = 175683,
    ["Saurial Egg"] = 175684,
    ["Pteradon Skeleton"] = 175685,
    ["Highborne Astrolabe"] = 175686,
    ["Uldaman Relics"] = 175687,
    ["Horde Catapult"] = 175688,
    ["Uldaman Reliefs"] = 175689,
    ["Sargeras and the Betrayal"] = 175724,
    ["The Old Gods and the Ordering of Azeroth"] = 175725,
    ["Charge of the Dragonflights"] = 175726,
    ["The War of the Ancients"] = 175727,
    ["Mount Hyjal and Illidan's Gift"] = 175729,
    ["The World Tree and the Emerald Dream"] = 175730,
    ["Exile of the High Elves"] = 175731,
    ["The Sentinels and the Long Vigil"] = 175732,
    ["The Founding of Quel'Thalas"] = 175733,
    ["Arathor and the Troll Wars"] = 175734,
    ["The Guardians of Tirisfal"] = 175735,
    ["Ironforge - the Awakening of the Dwarves"] = 175736,
    ["The Seven Kingdoms"] = 175737,
    ["Aegwynn and the Dragon Hunt"] = 175738,
    ["War of the Three Hammers"] = 175739,
    ["The Last Guardian"] = 175740,
    ["Kil'jaeden and the Shadow Pact"] = 175741,
    ["Rise of the Horde"] = 175742,
    ["The Dark Portal and the Fall of Stormwind"] = 175745,
    ["The Alliance of Lordaeron"] = 175746,
    ["The Invasion of Draenor"] = 175747,
    ["The Birth of the Lich King"] = 175748,
    ["Icecrown and the Frozen Throne"] = 175749,
    ["The Battle of Grim Batol"] = 175750,
    ["Lethargy of the Orcs"] = 175751,
    ["The New Horde"] = 175752,
    ["War of the Spider"] = 175753,
    ["Kel'Thuzad and the Forming of the Scourge"] = 175754,
    ["The Scourge of Lordaeron"] = 175756,
    ["Sunwell - The Fall of Quel'Thalas"] = 175757,
    ["Archimonde's Return and the Flight to Kalimdor"] = 175758,
    ["The Betrayer Ascendant"] = 175759,
    ["Rise of the Blood Elves"] = 175760,
    ["Civil War in the Plaguelands"] = 175761,
    ["The Lich King Triumphant"] = 175762,
    ["Old Hatreds - The Colonization of Kalimdor"] = 175763,
    ["Arellas Fireleaf"] = 175771,
    ["Admiral Barean Westwind"] = 175772,
    ["Dorgar Stoenbrow"] = 175773,
    ["Fellari Swiftarrow"] = 175774,
    ["Ferren Marcus"] = 175775,
    ["Harthal Truesight"] = 175776,
    ["Holia Sunshield"] = 175777,
    ["Invar One-Arm"] = 175778,
    ["Orman of Stromgarde"] = 175779,
    ["Valea Twinblades"] = 175780,
    ["Yana Bloodspear"] = 175781,
    ["The Twin Empires"] = 175854,
    ["Empires' Fall"] = 175855,
    ["Wrath of Soulflayer"] = 175856,
    ["Decorated Headstone"] = 175933,
    ["Archbishop Alonsus Faol"] = 177199,
    ["King Llane I of the House of Wrynn"] = 177200,
    ["Grand Admiral Daelin Proudmoore"] = 177201,
    ["Lady Mara Fordragon"] = 177202,
    ["Sorrow of the Earthmother"] = 177204,
    ["Forestlord and the first Druids"] = 177205,
    ["Mists of Dawn"] = 177207,
    ["The White Stag and the Moon"] = 177208,
    ["Hatred of the Centaur"] = 177209,
    ["Pteradon Skeleton"] = 177222,
    ["A Treatise on Military Ranks"] = 179706,
    ["Military Ranks of the Horde & Alliance"] = 179707,
    ["Alliance Military Ranks"] = 179735,
    ["Horde Military Ranks"] = 179741,
    ["Rock of Durotan"] = 179909,
    ["Altar of Zanza"] = 180367,
    ["In Loving Memory"] = 181062,
}
Lib.OBJ_MODEL, Lib.TITLE_OBJ, Lib.OBJ_KIND = OBJ_MODEL, TITLE_OBJ, OBJ_KIND
function OBJ_KIND_OF(o, title)
    o = o or TITLE_OBJ[title or ""]
    return o and OBJ_KIND[o] or nil
end
-- `where` : "shelf" (etageres : lettres et parchemins enroules) ou "lectern" (pupitre : ouverts).
-- Parchemins : sur les etageres, ceux d'Uldaman (feuillet plie, debout ; paire de rouleaux,
-- couchee) ; sur le pupitre, le vrai modele s'il est connu, sinon un parchemin ouvert du jeu.
-- Le meme parchemin garde toujours le meme (choisi par son titre).
Lib.SHELF_BOOK_OK = { [200900] = true, [200901] = true, [200902] = true, [200903] = true, [200904] = true, [200905] = true }
Lib.SCROLL_SHELF = { 203430 } -- (le feuillet plie, 203429, rendait mal sur les rayons)
Lib.SCROLL_OPEN = { 198451, 198452, 198454, 198455, 201113 }
local function TitleHash(t)
    local h = 0
    for k = 1, #(t or "") do h = (h * 31 + t:byte(k)) % 100003 end
    return h
end
function Lib.ModelFor(row, where)
    local o = (row.entry and row.entry.o) or TITLE_OBJ[row.title or ""]
    if row.kind == "letter" and where == "shelf" then
        return tonumber(DialogueWheelE_LibraryScroll) or Lib.SCROLL_SHELF[TitleHash(row.title) % #Lib.SCROLL_SHELF + 1]
    end
    -- (sur les etageres, seuls les livres g_book01 se tiennent debout de profil ; les autres
    -- reliures du jeu montraient leur couverture de face : on prend la g_book01 la plus proche)
    if o and OBJ_MODEL[o] and not (where == "shelf" and row.kind == "book" and not Lib.SHELF_BOOK_OK[OBJ_MODEL[o]]) then
        return OBJ_MODEL[o]
    end
    if row.kind == "letter" then return Lib.SCROLL_OPEN[TitleHash(row.title) % #Lib.SCROLL_OPEN + 1] end
    if row.kind == "plate" then return MODELS.plate end
    local c = Lib.Spine(row)
    local best, bd = MODELS.book[1][1], math.huge
    for _, b in ipairs(MODELS.book) do
        local d = (b[2] - c[1]) ^ 2 + (b[3] - c[2]) ^ 2 + (b[4] - c[3]) ^ 2
        if d < bd then best, bd = b[1], d end
    end
    return best
end
-- Scene 3D (ModelScene) : un seul acteur, centre sur lui-meme, mis a l'echelle pour que sa
-- plus grande dimension tienne dans le cadre, tourne selon la pose (lacet, tangage, roulis en
-- degres), camera fixe face a lui. `dist` : 1 = le modele remplit le cadre ; plus = plus petit.
local function NewScene(parent)
    local ok, sc = pcall(CreateFrame, "ModelScene", nil, parent)
    if not (ok and sc and sc.CreateActor) then return nil end
    sc:EnableMouse(false)
    local okA, actor = pcall(sc.CreateActor, sc)
    if not (okA and actor) then return nil end
    sc.actor = actor
    return sc
end
Lib.NewScene = NewScene
-- Taille connue des modeles (plus grande dimension), si le jeu ne donne pas leur boite.
Lib.KNOWN_SIZE = {}
local FOV = math.rad(30)
local function Frame(sc, pose)
    local a = sc.actor
    -- Taille mesuree une seule fois par modele, a l'echelle 1 (la boite mesuree ensuite est
    -- deja mise a l'echelle : la remesurer annulait le cadrage, livres trop petits).
    local size = sc.size
    if not size and a.GetMaxBoundingBox then
        local ok, x1, y1, z1, x2, y2, z2 = pcall(a.GetMaxBoundingBox, a)
        if ok and type(x1) == "table" then
            x1, y1, z1, x2, y2, z2 = x1.x, x1.y, x1.z, y1.x, y1.y, y1.z
        end
        if ok and type(x1) == "number" and type(z2) == "number" then
            local m = math.max(x2 - x1, y2 - y1, z2 - z1)
            if m > 0.001 then size = m; sc.size = m end
        end
    end
    if not size or size <= 0 then size = Lib.KNOWN_SIZE[sc.fileID or 0] or 1 end
    if a.SetScale then pcall(a.SetScale, a, 1 / size) end
    -- (champ etroit possible : camera lointaine, presque sans perspective, pour un objet vu par
    -- le bout qui s'etire vers nous)
    local fov = pose.fov or FOV
    local d = (0.55 / math.tan(fov / 2)) * (pose.dist or 1)
    if sc.SetCameraFieldOfView then pcall(sc.SetCameraFieldOfView, sc, fov) end
    if sc.SetCameraNearClip then pcall(sc.SetCameraNearClip, sc, 0.01) end
    if sc.SetCameraFarClip then pcall(sc.SetCameraFarClip, sc, 100) end
    if sc.SetCameraPosition then pcall(sc.SetCameraPosition, sc, d, 0, 0) end
    if sc.SetCameraOrientationByYawPitchRoll then pcall(sc.SetCameraOrientationByYawPitchRoll, sc, math.pi, 0, math.rad(pose.lean or 0)) end
end
-- Rotation et cadrage (repris une fois le modele charge : sa boite n'est connue qu'alors).
function Lib.Pose(sc)
    local a, pose = sc.actor, sc.pose
    if not (a and pose) then return end
    if a.SetYaw then pcall(a.SetYaw, a, math.rad(pose.yaw or 0)) end
    if a.SetPitch then pcall(a.SetPitch, a, math.rad(pose.pitch or 0)) end
    if a.SetRoll then pcall(a.SetRoll, a, math.rad(pose.roll or 0)) end
    Frame(sc, pose)
end
local function LoadModel(sc, id, pose)
    local a = sc and sc.actor
    if not (a and a.SetModelByFileID) then Lib.modelErr = "no model scene"; return false end
    -- (meme modele, meme pose : rien a recharger ; tourner les pages ne recharge que ce qui change)
    local key = id .. ":" .. (pose.dist or 1) .. ":" .. (pose.yaw or 0) .. ":" .. (pose.pitch or 0) .. ":" .. (pose.roll or 0) .. ":" .. (pose.lean or 0)
    if sc.loadedKey == key and sc.loaded then return true end
    sc.loadedKey = key
    sc.loaded = false
    if a.ClearModel then pcall(a.ClearModel, a) end
    if sc.fileID ~= id then sc.size = nil end
    sc.fileID = id
    if a.SetScale then pcall(a.SetScale, a, 1) end
    local ok, res = pcall(a.SetModelByFileID, a, id)
    if not ok or res == false then Lib.modelErr = ok and ("no model " .. tostring(id)) or tostring(res); return false end
    if a.SetUseCenterForOrigin then pcall(a.SetUseCenterForOrigin, a, true, true, true) end
    if a.SetPosition then pcall(a.SetPosition, a, 0, 0, 0) end
    if a.SetYaw then pcall(a.SetYaw, a, math.rad(pose.yaw or 0)) end
    if a.SetPitch then pcall(a.SetPitch, a, math.rad(pose.pitch or 0)) end
    if a.SetRoll then pcall(a.SetRoll, a, math.rad(pose.roll or 0)) end
    Frame(sc, pose)
    -- (la boite du modele n'est connue qu'une fois charge)
    if a.SetScript and not sc.hooked then
        sc.hooked = true
        pcall(a.SetScript, a, "OnModelLoaded", function() if sc.pose then Lib.Pose(sc) end end)
    end
    -- (et au cas ou le jeu ne previent pas : on recadre un peu plus tard)
    if C_Timer and C_Timer.After then
        sc.token = (sc.token or 0) + 1
        local tk = sc.token
        for _, t in ipairs({ 0.05, 0.3, 1 }) do
            C_Timer.After(t, function() if sc.token == tk and sc.pose then Lib.Pose(sc) end end)
        end
    end
    sc.pose = pose
    sc.loaded = true
    Lib.Glow(sc, sc.glow)
    return true
end
-- Surbrillance au survol, comme les objets du monde sous la souris : lumiere plus vive.
function Lib.Glow(sc, on)
    if not (sc and sc.SetLightAmbientColor) then return end
    sc.glow = on and true or nil
    if on then
        pcall(sc.SetLightAmbientColor, sc, 1.0, 0.95, 0.8)
        if sc.SetLightDiffuseColor then pcall(sc.SetLightDiffuseColor, sc, 1.6, 1.5, 1.3) end
    else
        pcall(sc.SetLightAmbientColor, sc, 0.7, 0.7, 0.7)
        if sc.SetLightDiffuseColor then pcall(sc.SetLightDiffuseColor, sc, 0.8, 0.8, 0.8) end
    end
end
-- Poses : livre fermé pose a plat et incline vers nous (pupitre), debout tranche face a nous
-- (etageres). Reglables en jeu : /storytale libpose shelf|lectern distance lacet tangage roulis.
Lib.LECTERN_POSE = { dist = 1.52, yaw = 0, pitch = 30, roll = 0 }
Lib.LECTERN_BOOK_POSE = { dist = 0.94, yaw = 0, pitch = 30, roll = 0 }
-- (la boite donnee par le jeu est plus grande que le modele visible : part reellement occupee)
Lib.BBOX_FILL = 0.68
Lib.SHELF_POSES = {
    book = { dist = 0.66, yaw = 90, pitch = 90, roll = 0, vfrac = 1 },
    letter = { dist = 1.15, yaw = 90, pitch = 0, roll = 0, vfrac = 0.3 },
    -- (couche, le bloc de pages vers nous : moins large que de profil)
    flat = { yaw = 0, pitch = 0, roll = 0, vfrac = 0.22, across = 0.75 },
    plate = { dist = 1.0, yaw = 90, pitch = 0, roll = 0, vfrac = 1 },
}
Lib.SHELF_POSE = Lib.SHELF_POSES.book
function Lib.ShowModel(cover, row)
    local m = cover.model
    local id = Lib.ModelFor(row, "lectern")
    -- (livre plus grand sur le pupitre ; parchemins et plaques gardent leur taille)
    local pose = row.kind == "book" and Lib.LECTERN_BOOK_POSE or Lib.LECTERN_POSE
    local shown = LoadModel(m, id, pose)
    if m then m.fileID = shown and id or nil; m:SetShown(shown) end
    cover.open:SetShown(not shown)
end

-- Etageres en 3D : peu de livres par rangee (chaque modele coute), le reste va sur les pages
-- suivantes. Pose : le livre debout, le dos face a nous.
Lib.PER_ROW_3D = 13
-- Rangement naturel : chaque livre (selon son titre, toujours pareil) a sa taille, et certains
-- penchent, appuyes sur leur voisin. Lettres : parchemins enroules couches sur le rayon.
function Lib.ShelfPose(row, i)
    local base = Lib.SHELF_POSES[row.kind] or Lib.SHELF_POSES.book
    local h = 0
    for k = 1, #(row.title or "") do h = (h * 31 + (row.title or ""):byte(k)) % 100003 end
    local p = { yaw = base.yaw, pitch = base.pitch, roll = base.roll, vfrac = base.vfrac }
    local size = (row.kind == "book") and (0.86 + (h % 15) / 100) or (0.9 + (h % 8) / 100)
    p.size = size
    p.dist = base.dist / size
    -- Penche (vu de face, la camera tourne) : appuye sur son voisin de gauche.
    -- (penche vers la droite, appuye sur son voisin : seulement s'il y en a un, voir Refresh)
    local every = row.kind == "letter" and 4 or 5
    if h % every == 0 and not row.noLean then p.lean = 12 + (h % 9) end
    -- Parchemins : couches, empiles. Quelques livres couches aussi, par deux ou trois.
    if row.kind == "letter" then
        -- (debout comme les livres, parfois penches : rouleaux d'Uldaman et feuillet plie)
        if Lib.ModelFor(row, "shelf") == 203430 and (h % 5 < 2) then
            -- (couches, vus par le bout : on voit les rouleaux de face, en pile de deux ou trois,
            -- jamais leur longueur)
            p.lean = nil
            p.yaw, p.pitch, p.roll, p.vfrac, p.flat = 0, 0, 0, 0.22, true
            p.dist, p.fov, p.across, p.fill = 1.41, math.rad(8), 0.42, 1.77
        elseif Lib.ModelFor(row, "shelf") == 203430 then
            -- (debout, un peu plus petits que les livres : ils ne touchent plus la planche)
            -- (ce modele occupe plus que sa boite ne le dit : part visible mesuree en jeu, 1,77)
            p.yaw, p.pitch, p.roll, p.vfrac, p.fill = 90, 90, 0, 1, 1.77
            p.dist = 1.89 / size
        else
            p.yaw, p.pitch, p.roll, p.vfrac = 20 + (h % 30), 0, 0, 1
            p.dist = 1.1
        end
    elseif row.kind == "book" and not row.noFlat and (row.forceFlat or (not p.lean and h % 6 == 1)) then
        p.lean = nil
        local fp = Lib.SHELF_POSES.flat
        p.yaw, p.pitch, p.roll, p.vfrac, p.flat = fp.yaw, fp.pitch, fp.roll, fp.vfrac, true
    end
    -- Petit espace de temps en temps entre deux groupes de livres.
    p.gap = (h % 5 == 0) and true or nil
    return p
end
-- Chargement etale : quelques modeles par image (ouvrir la bibliotheque ou tourner une page
-- pleine ne fige pas le jeu). Le livre apparait des que son modele est charge.
Lib.LOADS_PER_FRAME = 2
local loadQueue, loader = {}, nil
local function RunQueue()
    local n = 0
    while loadQueue[1] and n < Lib.LOADS_PER_FRAME do
        local job = table.remove(loadQueue, 1)
        local b = job.b
        if b.job == job and b:IsShown() and not b.model then
            b.model = NewScene(b)
            if Lib.PlaceModel then Lib.PlaceModel(b) end
        end
        if b.job == job and b:IsShown() then
            local ok = LoadModel(b.model, job.id, job.pose)
            if b.model then b.model:SetShown(ok); b.model.fileID = ok and job.id or nil end
            b.tex:SetShown(not ok); b.shade:SetShown(not ok)
            b.job = nil
            n = n + 1
        end
    end
    if not loadQueue[1] and loader then loader:SetScript("OnUpdate", nil) end
end
Lib.RunQueue = RunQueue
function Lib.PlaceModel(b)
    if not (b.model and b.mF) then return end
    b.model:ClearAllPoints()
    b.model:SetSize(b.mF, b.mF)
    b.model:SetPoint("BOTTOM", b, "BOTTOM", 0, b.mY)
end
function Lib.ShowShelfModel(b, row)
    local m = b.model
    local id = Lib.ModelFor(row, "shelf")
    local pose = Lib.ShelfPose(row)
    b.pose = pose
    if m and not m.actor then b.tex:Show(); b.shade:Show(); return false end
    local key = id .. ":" .. (pose.dist or 1) .. ":" .. (pose.yaw or 0) .. ":" .. (pose.pitch or 0) .. ":" .. (pose.roll or 0) .. ":" .. (pose.lean or 0)
    if m and m.loadedKey == key and m.loaded then
        b.job = nil
        m:Show(); b.tex:Hide(); b.shade:Hide()
        return true
    end
    -- (en attente : ni dos peint ni ancien modele)
    if m then m:Hide() end
    b.tex:Hide(); b.shade:Hide()
    local job = { b = b, id = id, pose = pose }
    b.job = job
    loadQueue[#loadQueue + 1] = job
    if not loader then loader = CreateFrame("Frame") end
    loader:SetScript("OnUpdate", RunQueue)
    if Lib.syncLoads then RunQueue() end
    return true
end
function Lib.Use3D() return DialogueWheelE_Library3D ~= false end

local MakeHandles
local function Build()
    if room then return end
    room = CreateFrame("Frame", "StorytaleLibraryFrame", UIParent, "BackdropTemplate")
    room:SetSize(W, H)
    room:SetPoint("CENTER")
    -- (au-dessus de la fenetre d'options, en FULLSCREEN : le bouton "Ouvrir la bibliotheque"
    -- l'ouvrait dessous, vu en jeu le 27/11)
    room:SetFrameStrata("FULLSCREEN")
    room:SetToplevel(true)
    room:SetMovable(true)
    room:SetClampedToScreen(true)
    -- (la fenetre elle-meme est invisible et laisse passer la souris : le fond est un cadre a
    -- part, ajuste autour des elements, qu'on tire pour tout deplacer)
    room:EnableMouse(false)
    local bgf = CreateFrame("Frame", nil, room, "BackdropTemplate")
    bgf:SetFrameLevel(room:GetFrameLevel())
    bgf:EnableMouse(true)
    bgf:RegisterForDrag("LeftButton")
    bgf:SetScript("OnDragStart", function() if not DialogueWheelE_Locked then room:StartMoving() end end)
    bgf:SetScript("OnDragStop", function() if Lib.RoomMoved then Lib.RoomMoved() end end)
    bgf:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    Lib.bgFrame = bgf
    function Lib.ApplyBg()
        if not room then return end
        local a = math.max(0, math.min(1, tonumber(DialogueWheelE_LibraryBg) or 0))
        if Lib.Style() == "simple" then a = 0 end -- (etagere seule : jamais de fond)
        Lib.bgAlpha = a
        bgf:SetBackdropColor(0.07, 0.045, 0.03, 0.97 * a)
        bgf:SetBackdropBorderColor(0.55, 0.38, 0.2, a)
        bgf:SetShown(a > 0)
        if ui and ui.boxes and Lib.ApplyLayout then Lib.ApplyLayout() end
    end
    Lib.ApplyBg()
    room:Hide()
    if UISpecialFrames then table.insert(UISpecialFrames, "StorytaleLibraryFrame") end
    Lib.frame = room
    ui = {}
    Lib.ui = ui
    -- Trois blocs, deplacables et redimensionnables chacun (Verrouiller les fenetres decoche) :
    -- les bibliotheques, le pupitre, l'en-tete. Chacun couvre toute la fenetre ; son contenu
    -- garde les memes coordonnees, le bloc est seulement decale et mis a l'echelle.
    ui.boxes = {}
    local function Box(id)
        local b = CreateFrame("Frame", nil, room)
        b:SetSize(W, H)
        b:SetPoint("BOTTOMLEFT", room, "BOTTOMLEFT", 0, 0)
        b.id = id
        b:SetFrameLevel(room:GetFrameLevel() + 2)
        ui.boxes[id] = b
        return b
    end
    -- (piece entiere : une bibliotheque = un bloc ; style simple : la grande etagere)
    local cases, lect, head = Box("cases"), Box("lectern"), Box("header")
    local caseBox = { Box("case1"), Box("case2") }
    local close = CreateFrame("Button", nil, room, "UIPanelCloseButton")
    -- (ferme toute la bibliotheque, meme posee sur l'en-tete sans fond)
    close:SetScript("OnClick", function() room:Hide() end)
    close:SetPoint("TOPRIGHT", room, "TOPRIGHT", -2, -2)

    -- Deux bibliotheques, cote a cote.
    ui.cases = {}
    local caseW = (CASE.contentR - CASE.contentL) * CS
    -- Chaque bibliotheque se dessine en morceaux (couronne, rangees, planches, socle) : on n'y
    -- met que les rangees utiles, elle est coupee a la bonne hauteur.
    for c = 1, 2 do
        ui.cases[c] = { pieces = {}, x = 24 + (c - 1) * (caseW + 6) - CASE.contentL * CS }
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
            local t = cases:CreateTexture(nil, "ARTWORK")
            t:SetTexture(ADDON .. "LibraryBookcase.png")
            t:SetTexCoord(pt[1] / 512, pt[2] / 512, v0, v1)
            t:SetSize(pt[4], r.h)
            t:SetPoint("TOPLEFT", cases, "TOPLEFT", pt[3], -r.top)
            t:Hide()
            ui.strips[#ui.strips + 1] = t
        end
    end
    -- Corniche en haut et socle en bas, etires comme les rangees : un vrai meuble, pas une
    -- image coupee. Le socle se place sous la derniere rangee affichee.
    do
        local r = SlotsOf("simple")[1].strip
        local k = SIMPLE.scale
        local function Cap(v)
            local list = {}
            for _, pt in ipairs({ { CASE.contentL, CASE.left, 0, r.edgeL }, { CASE.left, CASE.right, r.edgeL, r.mid },
                { CASE.right, CASE.contentR, r.edgeL + r.mid, r.edgeR } }) do
                local t = cases:CreateTexture(nil, "ARTWORK")
                t:SetTexture(ADDON .. "LibraryBookcase.png")
                t:SetTexCoord(pt[1] / 512, pt[2] / 512, v[1] / 1024, v[2] / 1024)
                t:SetSize(pt[4], (v[2] - v[1]) * k)
                t.dx = r.x + pt[3]
                t:Hide()
                list[#list + 1] = t
            end
            return list
        end
        ui.capTop, ui.capBot = Cap(CAP_TOP), Cap(CAP_BOT)
        for _, t in ipairs(ui.capTop) do
            t:SetPoint("BOTTOMLEFT", cases, "TOPLEFT", t.dx, -SIMPLE.top)
        end
    end
    -- Dos des livres (boutons), pris dans une reserve.
    ui.spines = {}
    function ui.Spine(i)
        local b = ui.spines[i]
        if b then return b end
        b = CreateFrame("Button", nil, cases)
        b:SetFrameLevel(room:GetFrameLevel() + 6)
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
        -- (sa scene 3D est creee plus tard, au moment de charger son modele : ouvrir la
        -- bibliotheque ne cree pas cent scenes d'un coup)
        b:SetScript("OnEnter", function(self)
            local r = self.row
            if not r then return end
            Lib.Glow(self.model, true)
            -- (un livre debout se souleve un peu ; couche dans une pile, il reste en place)
            if not self.flat then self:SetPoint("BOTTOMLEFT", self:GetParent(), "BOTTOMLEFT", self.x, self.y + 4) end
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
            Lib.Glow(self.model, false)
            self:SetPoint("BOTTOMLEFT", self:GetParent(), "BOTTOMLEFT", self.x, self.y)
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
    bgf:EnableMouseWheel(true)
    bgf:SetScript("OnMouseWheel", function(_, delta)
        state.shelf = state.shelf - delta
        Refresh()
    end)

    -- Mur de droite : titre, compteur, recherche, filtres, tri, etageres precedentes / suivantes.
    local right = 24 + 2 * (caseW + 6) + 30
    ui.right = right
    local title = head:CreateFontString(nil, "OVERLAY")
    title:SetPoint("TOPLEFT", head, "TOPLEFT", right, -22)
    Font(title, 22, GOLD)
    title:SetShadowOffset(1, -1)
    title:SetText(L.LIBRARY or "Library")
    ui.title = title
    local count = head:CreateFontString(nil, "OVERLAY")
    count:SetPoint("LEFT", title, "RIGHT", 12, -2)
    Font(count, 13, PALE)
    ui.count = count
    local search = CreateFrame("EditBox", nil, head, "SearchBoxTemplate")
    search:SetSize(W - right - 40, 20)
    search:SetPoint("TOPLEFT", head, "TOPLEFT", right + 6, -56)
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
        { "letter", L.LIB_LETTERS or "Letters" } }) do
        local b = TextButton(head, f[2], function() state.filter = f[1]; state.shelf = 1; Refresh() end)
        b:SetPoint("TOPLEFT", head, "TOPLEFT", x, -84)
        b.id = f[1]
        x = x + b:GetWidth() + 6
        ui.filters[#ui.filters + 1] = b
    end
    local sort = TextButton(head, L.LIB_SORT_AZ or "A-Z", function()
        state.sort = state.sort == "az" and "recent" or "az"
        state.shelf = 1
        Refresh()
    end)
    sort:SetPoint("TOPRIGHT", head, "TOPRIGHT", -30, -84)
    ui.sort = sort
    -- Etageres suivantes / precedentes (sous les bibliotheques).
    local up = TextButton(head, "<", function() state.shelf = state.shelf - 1; Refresh() end)
    local down = TextButton(head, ">", function() state.shelf = state.shelf + 1; Refresh() end)
    local shelfNum = head:CreateFontString(nil, "OVERLAY")
    shelfNum:SetPoint("RIGHT", sort, "LEFT", -40, 0)
    Font(shelfNum, 12, PALE)
    up:SetPoint("RIGHT", shelfNum, "LEFT", -6, 0)
    down:SetPoint("LEFT", shelfNum, "RIGHT", 6, 0)
    ui.up, ui.down, ui.shelfNum = up, down, shelfNum
    ui.close = close
    MakeHandles()
    -- (evitement verifie quelques fois par seconde tant que la bibliotheque est ouverte)
    local tick = 0
    room:HookScript("OnUpdate", function(_, el)
        tick = tick + (el or 0)
        if tick < 0.25 then return end
        tick = 0
        pcall(Lib.PushAll)
    end)

    -- Le pupitre, et le livre presente dessus.
    local lec = lect:CreateTexture(nil, "ARTWORK")
    lec:SetTexture(ADDON .. "LibraryLectern.png")
    lec:SetSize(LECTERN.size, LECTERN.size)
    local lx = right + (W - right - 30 - LECTERN.size) / 2
    lec:SetPoint("BOTTOMLEFT", lect, "BOTTOMLEFT", lx, 12)
    ui.lectern = lec
    local k = LECTERN.size / 1024
    local tp = LECTERN.top
    local cover = CreateFrame("Button", nil, lect)
    cover:SetFrameLevel(room:GetFrameLevel() + 6)
    cover:SetSize((tp[2] - tp[1]) * k * 0.62, (tp[4] - tp[3]) * k * 0.95)
    cover:SetPoint("CENTER", lect, "BOTTOMLEFT", lx + (tp[1] + tp[2]) / 2 * k, 12 + LECTERN.size - (tp[3] + tp[4]) / 2 * k + 6)
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
    local m = NewScene(cover)
    if m then
        -- (cadre carre centre sur le plateau : le livre couche, vu de biais comme le plateau)
        m:SetPoint("CENTER", cover, "CENTER", 0, 4)
        m:SetSize(200, 200) -- (grand cadre : un parchemin incline n'est plus coupe ; la distance compense)
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
        Lib.Glow(self.model, true)
        -- (a cote du pupitre, pas au milieu du livre)
        GameTooltip:SetOwner(self, "ANCHOR_NONE")
        GameTooltip:SetPoint("LEFT", self, "RIGHT", 60, 0)
        GameTooltip:SetText(L.LIB_READ or "Read", 1, 1, 1)
        GameTooltip:Show()
    end)
    cover:SetScript("OnLeave", function(self) Lib.Glow(self.model, false); if GameTooltip then GameTooltip:Hide() end end)
    ui.cover = cover
    local ft = lect:CreateFontString(nil, "OVERLAY")
    ft:SetPoint("BOTTOM", lect, "BOTTOMLEFT", lx + LECTERN.size / 2, 12 + LECTERN.size + 34)
    ft:SetWidth(W - right - 40)
    Font(ft, 16, GOLD)
    ft:SetShadowOffset(1, -1)
    ui.featured = ft
    local fm = lect:CreateFontString(nil, "OVERLAY")
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

-- Bibliotheque coupee a `n` rangees (1 = celle du haut). Renvoie, pour chaque rangee, la hauteur
-- de son plancher au-dessus du pied du meuble, et la hauteur totale du meuble.
function Lib.CutCase(n)
    local floors, cur = {}, (1024 - CASE.floors[#CASE.floors]) * CS
    for i = n, 1, -1 do
        floors[i] = cur
        cur = cur + (CASE.floors[i] - CASE.tops[i]) * CS
        if i > 1 then cur = cur + (CASE.tops[i] - CASE.floors[i - 1]) * CS end
    end
    return floors, cur + CASE.tops[1] * CS
end
local function Piece(cs, k, box, v0, v1, y)
    local t = cs.pieces[k]
    if not t then
        t = box:CreateTexture(nil, "ARTWORK")
        t:SetTexture(ADDON .. "LibraryBookcase.png")
        cs.pieces[k] = t
    end
    t:SetTexCoord(0, 1, v0 / 1024, v1 / 1024)
    t:SetSize(512 * CS, (v1 - v0) * CS)
    t:ClearAllPoints()
    t:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", cs.x, 20 + y)
    t:Show()
end
function Lib.DrawCase(c, n)
    local cs, box = ui.cases[c], ui.boxes["case" .. c]
    cs.n = n
    for _, t in pairs(cs.pieces) do t:Hide() end
    if n <= 0 then return end
    local floors, total = Lib.CutCase(n)
    local last = #CASE.floors
    Piece(cs, "base", box, CASE.floors[last], 1024, 0)
    for i = 1, n do
        Piece(cs, "row" .. i, box, CASE.tops[i], CASE.floors[i], floors[i])
        if i > 1 then Piece(cs, "plank" .. i, box, CASE.floors[i - 1], CASE.tops[i], floors[i] + (CASE.floors[i] - CASE.tops[i]) * CS) end
    end
    Piece(cs, "top", box, 0, CASE.tops[1], total - CASE.tops[1] * CS)
    cs.height = total
end

-- Disposition libre (Verrouiller les fenetres decoche) : la fenetre se deplace en tirant son
-- fond et grandit par sa poignee ; chaque bloc (bibliotheques, pupitre, en-tete) se deplace en
-- le tirant et grandit par sa propre poignee. Garde par style dans DialogueWheelE_LibraryLayout.
local function Layout()
    if type(DialogueWheelE_LibraryLayout) ~= "table" then DialogueWheelE_LibraryLayout = {} end
    local t = DialogueWheelE_LibraryLayout
    -- (une disposition par facon d'afficher : piece ou simple, et avec ou sans tous les livres)
    -- (v2 : les bibliotheques grandissent depuis leur pied ; l'ancienne disposition, faite avant,
    -- est devenue celle par defaut : on repart d'elle)
    if t.v ~= 2 then
        for k in pairs(t) do t[k] = nil end
        t.v = 2
    end
    local st = Lib.Style() .. (DialogueWheelE_LibraryUnlock == true and "_all" or "")
    t[st] = type(t[st]) == "table" and t[st] or {}
    return t, t[st]
end
-- Zone de chaque bloc (coordonnees de la fenetre, depuis le bas-gauche), selon le style.
local function Areas()
    local w, h = room:GetWidth(), room:GetHeight()
    if Lib.Style() == "simple" then
        return { cases = { 8, 0, w - 16, h - 112 }, header = { 8, h - 110, w - 16, 100 } }
    end
    local k = LECTERN.size
    local lx = ui.right + (W - ui.right - 30 - k) / 2
    local caseW = (CASE.contentR - CASE.contentL) * CS
    return {
        case1 = (ui.cases[1].n or 8) > 0 and { 12, 0, caseW + 24, 20 + (ui.cases[1].height or CASE_H) } or nil,
        case2 = (ui.cases[2].n or 8) > 0 and { 12 + caseW + 6, 0, caseW + 24, 20 + (ui.cases[2].height or CASE_H) } or nil,
        lectern = { lx - 10, 8, k + 20, k + 70 },
        header = { ui.right - 12, H - 112, W - ui.right - 24, 100 },
    }
end
Lib.Areas = Areas
-- Deux facons : avec un fond (opacite > 0), la fenetre se deplace et s'agrandit d'un bloc ;
-- sans fond (opacite 0, ou style simple), plus de fenetre : chaque element se deplace seul.
function Lib.Free() return (Lib.bgAlpha or 1) <= 0 end
function Lib.ApplyLayout()
    if not room then return end
    local _, lay = Layout()
    local all = lay -- (place et taille de la fenetre : par facon d'afficher aussi)
    local free = Lib.Free()
    -- Disposition par defaut (celle choisie par Nearyn) ; avec fond, toujours elle ; sans fond,
    -- chaque element garde la place ou le joueur l'a mis.
    local def = Lib.DEFAULT_LAYOUT[Lib.Style()] or {}
    -- Bibliotheques par defaut : sous l'en-tete, aussi grandes que la place le permet (plus de
    -- rangees = plus petites), la seconde collee a droite de la premiere.
    local areas0 = Areas()
    local dyn = {}
    if Lib.Style() == "room" and def.case1 and def.header and def.lectern then
        -- Groupe serre, quel que soit le nombre de rangees : bibliotheques posees au niveau du
        -- pied du pupitre, aussi hautes que 1,45 fois le pupitre au plus (pleines : plus
        -- petites) ; l'en-tete juste au-dessus du plus haut des deux.
        local la, ld = areas0.lectern, def.lectern
        local ls = ld.s or 1
        local lcx, lcy = la[1] + la[3] / 2, la[2] + la[4] / 2
        local lecBottom = (ld.y or 0) + lcy * (1 - ls) + la[2] * ls
        local lecTop = lecBottom + la[4] * ls
        local maxH = (lecTop - lecBottom) * 1.45
        local top = lecTop
        local function Fit(c)
            local a = areas0["case" .. c]
            if not a then return nil end
            return math.min(def.case1.s or 1, maxH / a[4]), a
        end
        local s1, a1 = Fit(1)
        if s1 then
            local cx1 = a1[1] + a1[3] / 2
            local sd = def.case1.s or 1
            local left = def.case1.x + cx1 * (1 - sd) + a1[1] * sd
            local function XFor(sc) return left - cx1 * (1 - sc) - a1[1] * sc end
            local s2, a2 = Fit(2)
            local sc = s2 and math.min(s1, s2) or s1
            -- (pied de la bibliotheque = pied du pupitre ; elle grandit depuis son pied)
            dyn.case1 = { x = XFor(sc), y = lecBottom - a1[2] * sc, s = sc }
            top = math.max(top, lecBottom + a1[4] * sc)
            if s2 then
                local cx2 = a2[1] + a2[3] / 2
                dyn.case2 = { x = left + a1[3] * sc + 6 - cx2 * (1 - sc) - a2[1] * sc, y = lecBottom - a2[2] * sc, s = sc }
            end
        end
        local ha, hd = areas0.header, def.header
        local hs = hd.s or 1
        local hcy = ha[2] + ha[4] / 2
        dyn.header = { x = hd.x, s = hs, y = (top + 6) - hcy * (1 - hs) - ha[2] * hs }
    end
    local function Of(id)
        if free and type(lay[id]) == "table" and (lay[id].x or lay[id].y or lay[id].s) then return lay[id] end
        return dyn[id] or def[id] or {}
    end
    local bgf = Lib.bgFrame
    bgf.dweNoGrip = free or nil
    if DWE.SetGripCorner and bgf.dweGrip then DWE.SetGripCorner(bgf, "CENTER") end
    -- La croix : coin de la fenetre, ou sans fond, sur l'en-tete "Bibliotheque".
    if ui.close then
        ui.close:ClearAllPoints()
        if free then
            ui.close:SetParent(ui.boxes.header)
            ui.close:SetPoint("BOTTOMRIGHT", ui.search, "TOPRIGHT", 2, 8)
        else
            ui.close:SetParent(room)
            ui.close:SetPoint("TOPRIGHT", bgf, "TOPRIGHT", -2, -2)
        end
        ui.close:SetFrameLevel(room:GetFrameLevel() + 8)
    end
    local s0 = tonumber(all.scale) or 1
    room:SetScale(math.max(0.5, math.min(2, s0)))
    local av = Lib.avoid
    local ra = (not free) and av.room or nil
    local areas = Areas()
    local x1, y1, x2, y2
    for id, box in pairs(ui.boxes) do
        local a = areas[id]
        local L2 = Of(id)
        local sc = math.max(0.4, math.min(2.5, tonumber(L2.s) or 1))
        local dx, dy = tonumber(L2.x) or 0, tonumber(L2.y) or 0
        local ba = free and av[id]
        if ba then dx, dy = dx + ba[1], dy + ba[2] end
        box:SetSize(room:GetWidth(), room:GetHeight())
        box:SetScale(sc)
        box:SetShown(a ~= nil)
        if a then
            -- (grandit autour de son centre ; les bibliotheques, autour de leur pied : couper ou
            -- ajouter des rangees ne les deplace pas)
            local cx, cy = a[1] + a[3] / 2, a[2] + a[4] / 2
            if id == "case1" or id == "case2" or id == "cases" then cy = a[2] end
            local ox, oy = dx + cx * (1 - sc), dy + cy * (1 - sc)
            box:ClearAllPoints()
            box:SetPoint("BOTTOMLEFT", room, "BOTTOMLEFT", ox / sc, oy / sc)
            local hd = ui.handles and ui.handles[id]
            if hd then
                hd:ClearAllPoints()
                hd:SetPoint("BOTTOMLEFT", room, "BOTTOMLEFT", ox + a[1] * sc, oy + a[2] * sc)
                hd:SetSize(a[3] * sc, a[4] * sc)
                hd:SetShown(free)
            end
            do
                local l, b = ox + a[1] * sc, oy + a[2] * sc
                local r, t = l + a[3] * sc, b + a[4] * sc
                x1, y1 = math.min(x1 or l, l), math.min(y1 or b, b)
                x2, y2 = math.max(x2 or r, r), math.max(y2 or t, t)
                if DWE.SetGripCorner then DWE.SetGripCorner(hd, "CENTER") end
            end
        end
    end
    for id, hd in pairs(ui.handles or {}) do if not areas[id] then hd:Hide() end end
    -- Le fond entoure les elements ; la fenetre est centree sur eux tant qu'on ne l'a pas bougee.
    local pad = 14
    if x1 then
        bgf:ClearAllPoints()
        bgf:SetPoint("BOTTOMLEFT", room, "BOTTOMLEFT", x1 - pad, y1 - pad)
        bgf:SetSize(x2 - x1 + 2 * pad, y2 - y1 + 2 * pad)
    end
    local pos = (type(all.pos) == "table" and all.pos[1]) and all.pos
    if not pos then
        -- (place par defaut : celle de Nearyn, a droite de l'ecran ; style simple : centree)
        if Lib.Style() == "room" then
            pos = Lib.DEFAULT_POS
        else
            local cx = x1 and ((x1 + x2) / 2 - room:GetWidth() / 2) or 0
            local cy = y1 and ((y1 + y2) / 2 - room:GetHeight() / 2) or 0
            pos = { "CENTER", -cx, -cy }
        end
    end
    room:ClearAllPoints()
    room:SetPoint(pos[1], UIParent, pos[1], (pos[2] or 0) + (ra and ra[1] or 0), (pos[3] or 0) + (ra and ra[2] or 0))
end
-- Disposition par defaut de la piece entiere : l'en-tete en haut, le pupitre a gauche, la
-- bibliotheque a droite (la seconde a cote quand elle se remplit).
Lib.DEFAULT_POS = { "CENTER", 638, 70 }
Lib.DEFAULT_LAYOUT = {
    room = {
        header = { x = 3, y = -48, s = 0.923 },
        lectern = { x = -158, y = 18, s = 0.741 },
        case1 = { x = 724, y = 64, s = 1.2516 },
        case2 = { x = 805, y = 64, s = 1.2516 },
    },
}
-- Poignees de deplacement des blocs, et redimensionnement des blocs et de la fenetre.
function MakeHandles()
    ui.handles = {}
    local function Cursor()
        local x, y = GetCursorPosition()
        local es = room:GetEffectiveScale()
        return x / es, y / es
    end
    for _, id in ipairs({ "cases", "case1", "case2", "lectern", "header" }) do
        local hd = CreateFrame("Frame", nil, room)
        hd:SetFrameLevel(room:GetFrameLevel() + 1)
        hd:EnableMouse(true)
        hd:RegisterForDrag("LeftButton")
        hd:SetScript("OnDragStart", function(self)
            if DWE.IsLocked and DWE.IsLocked() then return end
            local _, lay = Layout()
            lay[id] = type(lay[id]) == "table" and lay[id] or {}
            -- (l'ecart d'evitement devient la position choisie)
            local a = Lib.avoid[id]
            if a then
                lay[id].x, lay[id].y = (tonumber(lay[id].x) or 0) + a[1], (tonumber(lay[id].y) or 0) + a[2]
                Lib.avoid[id] = nil
            end
            local cx, cy = Cursor()
            self.drag = { x = cx, y = cy, dx = tonumber(lay[id].x) or 0, dy = tonumber(lay[id].y) or 0 }
            self:SetScript("OnUpdate", function(me)
                local d = me.drag
                if not d then return end
                local nx, ny = Cursor()
                lay[id].x, lay[id].y = math.floor(d.dx + nx - d.x + 0.5), math.floor(d.dy + ny - d.y + 0.5)
                Lib.ApplyLayout()
            end)
        end)
        hd:SetScript("OnDragStop", function(self)
            self.drag = nil
            self:SetScript("OnUpdate", nil)
            -- Pose a la main par-dessus un livre ou le narrateur : il y reste (plus d'evitement).
            local _, lay = Layout()
            if lay[id] then lay[id].pinned = Lib.Overlaps(self) or nil end
        end)
        -- (la molette tourne les etageres, comme sur le fond)
        hd:EnableMouseWheel(true)
        hd:SetScript("OnMouseWheel", function(_, delta) state.shelf = state.shelf - delta; Refresh() end)
        ui.handles[id] = hd
        if DWE.MakeResizeGrip then
            DWE.MakeResizeGrip(hd, {
                get = function()
                    local _, lay = Layout()
                    local a = Areas()[id]
                    local sc = lay[id] and tonumber(lay[id].s) or 1
                    return (a and a[3] or 100) * sc * room:GetScale(), 0
                end,
                set = function(w)
                    local _, lay = Layout()
                    local a = Areas()[id]
                    if not a then return end
                    lay[id] = type(lay[id]) == "table" and lay[id] or {}
                    lay[id].s = math.max(0.4, math.min(2.5, w / room:GetScale() / a[3]))
                    Lib.ApplyLayout()
                end,
            })
        end
    end
    -- La fenetre entiere : tirer le fond la deplace, sa poignee l'agrandit.
    function Lib.RoomMoved()
        local self = room
        self:StopMovingOrSizing()
        local _, all = Layout()
        Lib.avoid.room = nil
        all.roomPinned = Lib.Overlaps(Lib.bgFrame) or nil
        local x, y = self:GetCenter()
        local ux, uy = UIParent:GetCenter()
        if x and ux then
            local sc = self:GetScale()
            all.pos = { "CENTER", math.floor(x * sc - ux + 0.5) / sc, math.floor(y * sc - uy + 0.5) / sc }
        end
    end
    if DWE.MakeResizeGrip then
        local bgf = Lib.bgFrame
        bgf.dweGripX, bgf.dweGripY = 14, 14
        DWE.MakeResizeGrip(bgf, {
            get = function() return room:GetWidth() * room:GetScale(), 0 end,
            set = function(w)
                local _, all = Layout()
                all.scale = math.max(0.5, math.min(2, w / room:GetWidth()))
                Lib.ApplyLayout()
            end,
        })
    end
end
-- Evitement : un livre de Storytale, la roue ou le narrateur de Spoken s'ouvre la ou se trouve
-- un element de la bibliotheque : l'element s'ecarte (le plus court chemin qui reste a l'ecran),
-- puis revient a sa place quand l'autre se ferme. Un element pose a la main par-dessus reste.
Lib.avoid = {}
local MARGIN = 10
local function Rect(f)
    if not (f and f.IsShown and f:IsShown()) then return nil end
    local ok, l, b, w, h = pcall(f.GetRect, f)
    if not (ok and l and w and w > 0 and h > 0) then return nil end
    local sc = f:GetEffectiveScale() or 1
    return { l * sc, b * sc, (l + w) * sc, (b + h) * sc }
end
local function Obstacles()
    local list = {}
    for _, f in ipairs({ DWE.textBox, DWE.choiceBox, rawget(_G, "StorytaleNarratorFrame") }) do
        local r = Rect(f)
        if r then list[#list + 1] = r end
    end
    return list
end
local function Hit(a, b)
    return a[1] < b[3] + MARGIN and a[3] > b[1] - MARGIN and a[2] < b[4] + MARGIN and a[4] > b[2] - MARGIN
end
function Lib.Overlaps(f)
    local r = Rect(f)
    if not r then return false end
    for _, o in ipairs(Obstacles()) do if Hit(r, o) then return true end end
    return false
end
-- Plus petit deplacement (en pixels d'ecran) qui sort `r` de tous les obstacles.
local function Escape(r, obs)
    local any = false
    for _, o in ipairs(obs) do if Hit(r, o) then any = true end end
    if not any then return 0, 0 end
    local sw = (GetScreenWidth and GetScreenWidth() or 1920) * (UIParent:GetEffectiveScale() or 1)
    local sh = (GetScreenHeight and GetScreenHeight() or 1080) * (UIParent:GetEffectiveScale() or 1)
    local cands = {}
    for _, o in ipairs(obs) do
        cands[#cands + 1] = { o[1] - MARGIN - r[3] - 1, 0 }
        cands[#cands + 1] = { o[3] + MARGIN - r[1] + 1, 0 }
        cands[#cands + 1] = { 0, o[4] + MARGIN - r[2] + 1 }
        cands[#cands + 1] = { 0, o[2] - MARGIN - r[4] - 1 }
    end
    -- (de cote plutot qu'en haut ou en bas : un livre reste a hauteur des yeux)
    table.sort(cands, function(a, b) return math.abs(a[1]) + 3 * math.abs(a[2]) < math.abs(b[1]) + 3 * math.abs(b[2]) end)
    for _, c in ipairs(cands) do
        local m = { r[1] + c[1], r[2] + c[2], r[3] + c[1], r[4] + c[2] }
        if m[1] >= 0 and m[2] >= 0 and m[3] <= sw and m[4] <= sh then
            local clear = true
            for _, o in ipairs(obs) do if Hit(m, o) then clear = false break end end
            if clear then return c[1], c[2] end
        end
    end
    return 0, 0 -- (nulle part ou aller : il reste)
end
Lib.Escape = Escape
-- La bibliotheque ne bouge pas : ce sont le livre de Storytale et le narrateur de Spoken qui
-- s'ouvrent a cote d'elle, aussitot (pas de glissement a l'ecran). Repris a chaque fois qu'ils
-- sont replaces, tant que la bibliotheque est ouverte.
local function LibraryRects()
    local list = {}
    if not (room and room:IsShown()) then return list end
    if Lib.Free() then
        for _, hd in pairs(ui.handles or {}) do
            local r = hd:IsShown() and Rect(hd)
            if r then list[#list + 1] = r end
        end
    else
        local r = Rect(Lib.bgFrame)
        if r then list[#list + 1] = r end
    end
    return list
end
local pushing = false
function Lib.Push(f)
    if pushing or not (f and f.IsShown and f:IsShown()) then return end
    if f.dweMoving then return end -- (deplace a la main : il va ou on le pose)
    if f == DWE.textBox and not DWE.bookMode then return end
    local libs = LibraryRects()
    if #libs == 0 then return end
    local r = Rect(f)
    if not r then return end
    local dx, dy = Escape(r, libs)
    if dx == 0 and dy == 0 then return end
    local sc = f:GetEffectiveScale() or 1
    pushing = true
    if f.AdjustPointsOffset then
        pcall(f.AdjustPointsOffset, f, dx / sc, dy / sc)
    else
        local n = f:GetNumPoints() or 0
        local pts = {}
        for i = 1, n do pts[i] = { f:GetPoint(i) } end
        f:ClearAllPoints()
        for _, p in ipairs(pts) do f:SetPoint(p[1], p[2], p[3], (p[4] or 0) + dx / sc, (p[5] or 0) + dy / sc) end
    end
    pushing = false
end
local hooked = {}
function Lib.PushAll()
    for _, f in ipairs({ DWE.textBox, rawget(_G, "StorytaleNarratorFrame"), rawget(_G, "SpokenSubtitleFrame") }) do
        if f and not hooked[f] and hooksecurefunc then
            hooked[f] = true
            hooksecurefunc(f, "SetPoint", function(self) if not pushing then Lib.Push(self) end end)
            if f.HookScript then f:HookScript("OnShow", function(self) Lib.Push(self) end) end
        end
        if f then Lib.Push(f) end
    end
end
function Lib.Avoid()
    if not (room and room:IsShown()) then return end
    local obs = Obstacles()
    local es = room:GetEffectiveScale() or 1
    local changed = false
    local function Set(id, dx, dy)
        local old = Lib.avoid[id]
        local new = (dx ~= 0 or dy ~= 0) and { dx, dy } or nil
        if (old and new and (math.abs(old[1] - dx) > 1 or math.abs(old[2] - dy) > 1)) or (old == nil) ~= (new == nil) then
            Lib.avoid[id] = new
            changed = true
        end
    end
    local function Check(id, f, pinned)
        local r = Rect(f)
        if not r or pinned or #obs == 0 then Set(id, 0, 0) return end
        -- (depuis sa vraie place, sans l'ecart actuel)
        local a = Lib.avoid[id]
        if a then r = { r[1] - a[1] * es, r[2] - a[2] * es, r[3] - a[1] * es, r[4] - a[2] * es } end
        local dx, dy = Escape(r, obs)
        Set(id, dx / es, dy / es)
    end
    if Lib.Free() then
        local _, lay = Layout()
        for id, hd in pairs(ui.handles or {}) do
            if hd:IsShown() then Check(id, hd, lay[id] and lay[id].pinned) else Lib.avoid[id] = nil end
        end
        Lib.avoid.room = nil
    else
        local _, all = Layout()
        Check("room", Lib.bgFrame, all.roomPinned)
    end
    if changed then Lib.ApplyLayout() end
end

-- Choix du parchemin des etageres : les parchemins du jeu, cote a cote, qui tournent sur
-- eux-memes ; un clic choisit celui des etageres (/storytale libscrolls).
Lib.SCROLLS = {
    { 198451, "Scroll A2" }, { 198452, "Scroll A3" }, { 198453, "Scroll B1" }, { 198454, "Scroll B2" },
    { 198455, "Scroll B3" }, { 198457, "Map scroll" }, { 203429, "Uldaman scroll 1" },
    { 203430, "Uldaman scroll 2" }, { 203431, "Uldaman scroll 3" }, { 201113, "Open scroll" },
}
function Lib.ScrollPicker()
    local f = Lib.picker
    if f then f:SetShown(not f:IsShown()) return end
    f = CreateFrame("Frame", "StorytaleScrollPicker", UIParent, "BackdropTemplate")
    Lib.picker = f
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetSize(5 * 150 + 30, 2 * 170 + 60)
    f:SetPoint("CENTER")
    f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    f:SetBackdropColor(0.07, 0.045, 0.03, 0.95)
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    local t = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    t:SetPoint("TOP", 0, -14)
    t:SetText("Storytale : click the scroll for the shelves")
    f.cells = {}
    local pose = { dist = 1.0, yaw = 0, pitch = 0, roll = 0 }
    for i, c in ipairs(Lib.SCROLLS) do
        local cell = CreateFrame("Button", nil, f, "BackdropTemplate")
        cell:SetSize(140, 160)
        cell:SetPoint("TOPLEFT", 15 + ((i - 1) % 5) * 150, -44 - math.floor((i - 1) / 5) * 170)
        cell:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12 })
        local sc = NewScene(cell)
        if sc then
            sc:SetPoint("TOPLEFT", 6, -6); sc:SetPoint("BOTTOMRIGHT", -6, 24)
            LoadModel(sc, c[1], pose)
        end
        local lab = cell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        lab:SetPoint("BOTTOM", 0, 8)
        lab:SetText(i .. ". " .. c[2])
        cell:SetScript("OnClick", function()
            DialogueWheelE_LibraryScroll = c[1]
            for _, o in ipairs(f.cells) do o:SetBackdropBorderColor(1, 1, 1, 0.4) end
            cell:SetBackdropBorderColor(1, 0.82, 0, 1)
            if Refresh then Refresh() end
        end)
        cell:SetBackdropBorderColor(DialogueWheelE_LibraryScroll == c[1] and 1 or 1, DialogueWheelE_LibraryScroll == c[1] and 0.82 or 1, DialogueWheelE_LibraryScroll == c[1] and 0 or 1, DialogueWheelE_LibraryScroll == c[1] and 1 or 0.4)
        cell.sc = sc
        f.cells[i] = cell
    end
    -- (ils tournent lentement, pour voir leur forme)
    local yaw = 0
    f:SetScript("OnUpdate", function(_, el)
        yaw = yaw + (el or 0) * 0.8
        for _, cell in ipairs(f.cells) do
            local a = cell.sc and cell.sc.actor
            if a and a.SetYaw then pcall(a.SetYaw, a, yaw) end
        end
    end)
end

-- Revenir a la disposition d'origine (style en cours).
function Lib.ResetLayout()
    local all, _ = Layout()
    all[Lib.Style() .. (DialogueWheelE_LibraryUnlock == true and "_all" or "")] = {}
    if room then room:ClearAllPoints(); room:SetPoint("CENTER") end
    Lib.ApplyLayout()
end

-- Met la fenetre au style choisi : la piece entiere, ou les rangees seules (plus petite).
local function ApplyStyle()
    local style = Lib.Style()
    if ui.style == style then return end
    ui.style = style
    local full = style == "room"
    for _, cs in ipairs(ui.cases) do if not full then for _, t in pairs(cs.pieces) do t:Hide() end end end
    for _, t in ipairs(ui.strips) do t:SetShown(not full) end
    for _, t in ipairs(ui.capTop or {}) do t:SetShown(not full) end
    for _, t in ipairs(ui.capBot or {}) do t:SetShown(not full) end
    for _, f in ipairs({ ui.lectern, ui.cover, ui.featured, ui.featuredMeta }) do f:SetShown(full) end
    local w, h
    if full then
        w, h = W, H
    else
        w, h = SimpleSize()
    end
    room:SetSize(w, h)
    Lib.ApplyBg()
    Lib.ApplyLayout()
    local left = full and ui.right or 22
    ui.title:ClearAllPoints()
    ui.title:SetPoint("TOPLEFT", ui.boxes.header, "TOPLEFT", left, -22)
    ui.search:ClearAllPoints()
    ui.search:SetPoint("TOPLEFT", ui.boxes.header, "TOPLEFT", left + 6, -56)
    -- (meme en-tete dans les deux styles : recherche sous le titre, filtres et tri dessous)
    ui.search:SetWidth(full and (W - ui.right - 40) or (w - left - 40))
    local x = left
    for _, b in ipairs(ui.filters) do
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", ui.boxes.header, "TOPLEFT", x, -84)
        x = x + b:GetWidth() + 6
    end
    ui.sort:ClearAllPoints()
    ui.sort:SetPoint("TOPRIGHT", ui.boxes.header, "TOPLEFT", full and (W - 30) or (w - 30), -84)
    ui.shelfNum:ClearAllPoints()
    ui.shelfNum:SetPoint("RIGHT", ui.sort, "LEFT", -40, 0)
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
    -- Largeur d'un livre sur le rayon : debout, son epaisseur ; penche, un peu plus ; couche,
    -- sa longueur (et les suivants couches s'empilent dessus, trois au plus).
    local function Width(row, sl)
        if not use3d then local _, w = Lib.Spine(row); return w end
        local p = Lib.ShelfPose(row)
        if p.flat then return math.floor((p.fill or Lib.BBOX_FILL) * sl.h / (1.1 * p.dist) * (p.across or (row.kind == "book" and Lib.SHELF_POSES.flat.across) or 1)) end
        return math.floor(sl.w / Lib.PER_ROW_3D * (p.lean and 1.45 or 1)) - 1
    end
    -- Livres couches par deux au moins : un livre couche seul prend le suivant sur lui, ou se
    -- releve s'il n'y en a pas.
    if use3d then
        local i = 1
        while i <= #rows do
            local r = rows[i]
            r.forceFlat, r.noFlat = nil, nil
            if r.kind == "book" and Lib.ShelfPose(r).flat then
                local nxt = rows[i + 1]
                if nxt and nxt.kind == "book" then
                    nxt.noFlat = nil
                    nxt.forceFlat = true
                    i = i + 2
                else
                    r.noFlat = true
                    i = i + 1
                end
            else
                i = i + 1
            end
        end
    end
    local stack
    for idx, row in ipairs(rows) do
        local p = use3d and Lib.ShelfPose(row) or {}
        local w = Width(row, slots[cur.slot])
        if p.flat and stack and stack.kind == row.kind and stack.slot == cur.slot and stack.view == #views and stack.n < 3 then
            -- (sur la pile d'a cote)
            stack.n = stack.n + 1
            placed[idx] = { view = #views, slot = cur.slot, x = stack.x, w = stack.w, level = stack.n - 1 }
        else
            if p.gap and cur.x > 0 then cur.x = cur.x + 5 end
            if cur.x + w > slots[cur.slot].w - 2 then
                cur.slot, cur.x, cur.n = cur.slot + 1, 0, 0
                if cur.slot > #slots then
                    views[#views + 1] = idx
                    cur.slot = 1
                end
                w = Width(row, slots[cur.slot])
            end
            placed[idx] = { view = #views, slot = cur.slot, x = cur.x, w = w, level = 0 }
            stack = p.flat and { slot = cur.slot, view = #views, x = cur.x, w = w, n = 1, kind = row.kind } or nil
            cur.x = cur.x + w + 2
            cur.n = cur.n + 1
        end
    end
    -- Un livre penche (le haut vers la gauche) s'appuie sur son voisin de gauche : il lui faut
    -- un voisin debout et droit juste avant lui sur le meme rayon (pas un autre penche, pas une
    -- pile couchee, pas le bord du meuble) ; sinon il se tient droit.
    if use3d then
        local prevOK = false
        for idx, row in ipairs(rows) do
            local pl = placed[idx]
            local pv = placed[idx - 1]
            local sameRow = pv and pv.view == pl.view and pv.slot == pl.slot
            if (pl.level or 0) > 0 then
                prevOK = false
            else
                local p = Lib.ShelfPose(row)
                if p.lean and not (sameRow and prevOK) then row.noLean = true; p = Lib.ShelfPose(row) end
                prevOK = not p.lean and not p.flat
            end
        end
    end
    state.shelf = math.max(1, math.min(state.shelf, #views))
    -- Rangees utiles dans la vue : on coupe la bibliotheque juste en dessous (une rangee vide
    -- de plus au plus) ; une bibliotheque vide disparait. Aucun ecrit : un petit meuble.
    local maxSlot = 0
    for idx in ipairs(rows) do
        if placed[idx].view == state.shelf and placed[idx].slot > maxSlot then maxSlot = placed[idx].slot end
    end
    if style == "room" then
        local per = #CASE.tops
        local n1 = (maxSlot == 0) and 2 or math.min(per, maxSlot + 1)
        local n2 = (maxSlot <= per) and 0 or math.min(per, maxSlot - per + 1)
        Lib.DrawCase(1, n1)
        Lib.DrawCase(2, n2)
        for c, n in ipairs({ n1, n2 }) do
            local floors = Lib.CutCase(math.max(1, n))
            for i = 1, per do
                local sl = slots[(c - 1) * per + i]
                if floors[i] then sl.y = 20 + floors[i] end
            end
        end
        Lib.ApplyLayout()
    else
        -- (grande etagere : les rangees utiles, une vide de plus, deux au moins)
        local n = math.max(2, math.min(#slots, maxSlot + 1))
        for k, t in ipairs(ui.strips) do t:SetShown(math.ceil(k / 3) <= n) end
        local last = slots[n].strip
        for _, t in ipairs(ui.capBot) do
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", ui.boxes.cases, "TOPLEFT", t.dx, -(last.top + last.h))
            t:Show()
        end
        for _, t in ipairs(ui.capTop) do t:Show() end
    end
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
            if use3d then w, hf = pl.w, 1 end
            local h = math.floor(sl.h * hf)
            b.x = math.floor(sl.x + pl.x)
            b.y = math.floor(sl.y or (winH - sl.fromTop))
            b:ClearAllPoints()
            b:SetSize(w, h)
            local box = ui.boxes[sl.box or "cases"]
            if b:GetParent() ~= box then b:SetParent(box); b:SetFrameLevel(room:GetFrameLevel() + 6) end
            b:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", b.x, b.y)
            b.tex:SetVertexColor(color[1], color[2], color[3], 1)
            local is3d = use3d and Lib.ShowShelfModel(b, row)
            if b.pose then
                -- Pose sur le plancher du rayon : le modele, centre dans son cadre, en occupe
                -- 1 / (1,1 x dist) en hauteur (fois vfrac, couche) ; on descend le cadre d'autant.
                local F = sl.h
                local hm = (b.pose.fill or Lib.BBOX_FILL) * F / (1.1 * b.pose.dist) * (b.pose.vfrac or 1)
                b.mF, b.mY = F, -(F - hm) / 2 - 2
                if b.pose.flat then
                    -- Couche : le bouton n'est que sa tranche de pile (sinon les livres empiles se
                    -- recouvraient et la souris passait de l'un a l'autre sans fin).
                    b.y = b.y + (pl.level or 0) * hm
                    b:SetHeight(math.max(4, hm))
                    b:ClearAllPoints()
                    b:SetPoint("BOTTOMLEFT", b:GetParent(), "BOTTOMLEFT", b.x, b.y)
                end
                b.flat = b.pose.flat
                Lib.PlaceModel(b)
            end
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
-- Lire : le livre habituel de Storytale, la bibliotheque cachee le temps de la lecture et
-- rouverte quand on le ferme. (Le petit lecteur peint ne sert que si ce livre n'est pas la.)
function Lib.Read(key)
    Build()
    local row
    for _, r in ipairs((Lib.List("all", "", "az"))) do if r.key == key then row = r end end
    if row and not row.locked and DWE.OpenLibraryBook then
        local pages = Lib.Pages(row)
        if #pages > 0 then
            local back = room:IsShown()
            if DWE.OpenLibraryBook(row.title, pages, row.entry and row.entry.m) then
                state.reopen = back
                state.key = key
                if back then room:Hide() end
                return
            end
        end
    end
    state.readKey, state.page = key, 1
    reader:Show()
    RefreshReader()
end
function Lib.OnBookClosed()
    if state.reopen then
        state.reopen = nil
        Lib.Open()
        if DWE.FadeInFrames then DWE.FadeInFrames({ room }, 0.3) end
    end
end

-- Bibliotheque desactivee dans les options : rien ne l'ouvre (clic droit sur le bouton de la
-- mini-carte, raccourci, commande). Les ecrits lus restent gardes, pour le jour ou on la remet.
function Lib.Enabled() return DialogueWheelE_LibraryOff ~= true end
function Lib.Warm()
    if not Lib.Enabled() or (InCombatLockdown and InCombatLockdown()) then return end
    if room and room:IsShown() then return end
    Build()
    Lib.SpokenTitles()
    Refresh()
end
function Lib.Open()
    if not Lib.Enabled() then return end
    Build()
    room:Show()
    room:Raise()
    pcall(Lib.PushAll)
    Refresh()
end
function Lib.Toggle()
    if not Lib.Enabled() then if room then room:Hide() end return end
    Build()
    if room:IsShown() then room:Hide() else Lib.Open() end
end
-- Ouvre la bibliotheque sur l'ecrit `title`, ouvert pour la lecture.
function Lib.Show(title)
    if not Lib.Enabled() then return end
    local key = DWE.BookKey and DWE.BookKey(title)
    Lib.Open()
    state.key = key
    Refresh()
    if key then Lib.Read(key) end
end
