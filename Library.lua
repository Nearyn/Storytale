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
-- Fenetre : un grand livre (BookSpread.png), la liste a gauche, l'ecrit a droite.
--------------------------------------------------------------------------------
local ADDON = "Interface\\AddOns\\Storytale\\"
local W, H = 943, 530
local S = W / 1024
local LEFT = { 120 * S + 22, 512 * S - 26 }   -- x de la page de gauche (marges comprises)
local RIGHT = { 516 * S + 28, 930 * S - 30 }
local TOP, BOTTOM = 40 * S + 26, 490 * S - 22
local ROW_H = 19
local INK = { 0.17, 0.10, 0.04 }
local HEAD = { 0.40, 0.16, 0.04 }

local frame, ui
local state = { filter = "all", search = "", sort = "az", offset = 0, page = 1 }
Lib.state = state

local function Font(fs, size, color)
    local face = DWE.FontPath and DWE.ThemeFontId and DWE.FontPath(DWE.ThemeFontId()) or STANDARD_TEXT_FONT
    if DWE.SafeSetFont then DWE.SafeSetFont(fs, face, size) else fs:SetFont(face, size) end
    fs:SetTextColor(color[1], color[2], color[3])
    fs:SetShadowOffset(0, 0)
end

local Refresh

local function TextButton(parent, text, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(18)
    local fs = b:CreateFontString(nil, "OVERLAY")
    fs:SetPoint("CENTER")
    b.text = fs
    b:SetFontString(fs)
    Font(fs, 12, INK)
    b:SetText(text)
    b:SetWidth(math.max(24, (fs:GetStringWidth() or 30) + 10))
    b:SetScript("OnClick", onClick)
    b:SetScript("OnEnter", function(self) self.text:SetTextColor(0.55, 0.25, 0.05) end)
    b:SetScript("OnLeave", function(self) self.text:SetTextColor(INK[1], INK[2], INK[3]); Refresh() end)
    return b
end

local function Build()
    if frame then return end
    frame = CreateFrame("Frame", "StorytaleLibraryFrame", UIParent)
    frame:SetSize(W, H)
    frame:SetPoint("CENTER")
    -- (au-dessus de la fenetre d'options, en FULLSCREEN : le bouton "Ouvrir la bibliotheque"
    -- l'ouvrait dessous, vu en jeu le 27/11)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) if not DialogueWheelE_Locked then self:StartMoving() end end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    frame:Hide()
    if UISpecialFrames then table.insert(UISpecialFrames, "StorytaleLibraryFrame") end
    Lib.frame = frame
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(ADDON .. "BookSpread.png")
    bg:SetTexCoord(0, 1, 0, 576 / 1024)
    ui = {}
    Lib.ui = ui
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPLEFT", RIGHT[2] + 18, -TOP + 22)
    ui.close = close

    -- Page de gauche : titre, compteur, recherche, filtres, tri, liste.
    local lw = LEFT[2] - LEFT[1]
    local title = frame:CreateFontString(nil, "OVERLAY")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", LEFT[1], -TOP)
    Font(title, 18, HEAD)
    title:SetText(L.LIBRARY or "Library")
    local count = frame:CreateFontString(nil, "OVERLAY")
    count:SetPoint("TOPRIGHT", frame, "TOPLEFT", LEFT[2], -TOP - 3)
    Font(count, 12, INK)
    ui.count = count

    local search = CreateFrame("EditBox", nil, frame, "SearchBoxTemplate")
    search:SetSize(lw - 8, 20)
    search:SetPoint("TOPLEFT", frame, "TOPLEFT", LEFT[1] + 6, -TOP - 30)
    search:SetAutoFocus(false)
    search:HookScript("OnTextChanged", function(self)
        state.search = self:GetText() or ""
        state.offset = 0
        Refresh()
    end)
    ui.search = search

    local x = LEFT[1]
    ui.filters = {}
    for _, f in ipairs({ { "all", L.LIB_ALL or "All" }, { "book", L.LIB_BOOKS or "Books" },
        { "letter", L.LIB_LETTERS or "Letters" }, { "plate", L.LIB_PLATES or "Plaques" } }) do
        local b = TextButton(frame, f[2], function() state.filter = f[1]; state.offset = 0; Refresh() end)
        b:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -TOP - 56)
        b.id = f[1]
        x = x + b:GetWidth() + 4
        ui.filters[#ui.filters + 1] = b
    end
    local sort = TextButton(frame, L.LIB_SORT_AZ or "A-Z", function()
        state.sort = state.sort == "az" and "recent" or "az"
        Refresh()
    end)
    sort:SetPoint("TOPRIGHT", frame, "TOPLEFT", LEFT[2], -TOP - 56)
    ui.sort = sort

    local listTop = TOP + 82
    ui.visible = math.floor((BOTTOM - listTop) / ROW_H)
    ui.rows = {}
    for i = 1, ui.visible do
        local r = CreateFrame("Button", nil, frame)
        r:SetSize(lw, ROW_H)
        r:SetPoint("TOPLEFT", frame, "TOPLEFT", LEFT[1], -(listTop + (i - 1) * ROW_H))
        local hl = r:CreateTexture(nil, "BACKGROUND")
        hl:SetAllPoints()
        hl:SetColorTexture(0.45, 0.30, 0.12, 0.18)
        hl:Hide()
        r.hl = hl
        local fs = r:CreateFontString(nil, "OVERLAY")
        fs:SetPoint("LEFT", r, "LEFT", 4, 0)
        fs:SetPoint("RIGHT", r, "RIGHT", -4, 0)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
        Font(fs, 13, INK)
        r.text = fs
        r:SetScript("OnClick", function(self)
            if self.row and not self.row.locked then
                state.key, state.page = self.row.key, 1
                Refresh()
            end
        end)
        r:SetScript("OnEnter", function(self)
            self.hl:Show()
            if self.row and self.row.locked then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L.LIB_NOT_FOUND or "Not found yet", 1, 1, 1)
                GameTooltip:Show()
            end
        end)
        r:SetScript("OnLeave", function(self)
            if state.key ~= (self.row and self.row.key) then self.hl:Hide() end
            if GameTooltip then GameTooltip:Hide() end
        end)
        ui.rows[i] = r
    end
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta)
        local cx = GetCursorPosition and select(1, GetCursorPosition()) / (frame:GetEffectiveScale() or 1) or 0
        local onLeft = cx < ((frame:GetLeft() or 0) + RIGHT[1] - 20)
        if onLeft then
            state.offset = math.max(0, state.offset - delta * 3)
        else
            ui.scroll:SetVerticalScroll(math.max(0, math.min(ui.scroll:GetVerticalScrollRange() or 0,
                (ui.scroll:GetVerticalScroll() or 0) - delta * 30)))
        end
        Refresh()
    end)

    -- Page de droite : titre de l'ecrit, sa page (defilante), le numero et les fleches.
    local rw = RIGHT[2] - RIGHT[1]
    local bt = frame:CreateFontString(nil, "OVERLAY")
    bt:SetPoint("TOPLEFT", frame, "TOPLEFT", RIGHT[1], -TOP)
    bt:SetWidth(rw - 30)
    bt:SetJustifyH("LEFT")
    Font(bt, 16, HEAD)
    ui.bookTitle = bt
    local meta = frame:CreateFontString(nil, "OVERLAY")
    meta:SetPoint("TOPLEFT", bt, "BOTTOMLEFT", 0, -2)
    meta:SetWidth(rw)
    meta:SetJustifyH("LEFT")
    Font(meta, 11, INK)
    meta:SetAlpha(0.75)
    ui.meta = meta
    local scroll = CreateFrame("ScrollFrame", nil, frame)
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", RIGHT[1], -(TOP + 46))
    scroll:SetSize(rw, BOTTOM - TOP - 46 - 26)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(rw, 10)
    scroll:SetScrollChild(child)
    local body = child:CreateFontString(nil, "OVERLAY")
    body:SetPoint("TOPLEFT")
    body:SetWidth(rw)
    body:SetJustifyH("LEFT")
    body:SetJustifyV("TOP")
    body:SetSpacing(3)
    Font(body, 14, INK) -- (police posee des la creation : sans livre choisi, SetText("") la reclamait)
    ui.scroll, ui.child, ui.body = scroll, child, body
    local prev = TextButton(frame, "<", function() state.page = math.max(1, state.page - 1); ui.scroll:SetVerticalScroll(0); Refresh() end)
    local nextB = TextButton(frame, ">", function() state.page = state.page + 1; ui.scroll:SetVerticalScroll(0); Refresh() end)
    local num = frame:CreateFontString(nil, "OVERLAY")
    num:SetPoint("BOTTOM", frame, "TOPLEFT", (RIGHT[1] + RIGHT[2]) / 2, -BOTTOM)
    Font(num, 12, INK)
    prev:SetPoint("RIGHT", num, "LEFT", -8, 0)
    nextB:SetPoint("LEFT", num, "RIGHT", 8, 0)
    ui.prev, ui.next, ui.num = prev, nextB, num
    local empty = frame:CreateFontString(nil, "OVERLAY")
    empty:SetPoint("CENTER", frame, "TOPLEFT", (RIGHT[1] + RIGHT[2]) / 2, -(TOP + BOTTOM) / 2)
    empty:SetWidth(rw - 20)
    Font(empty, 13, INK)
    empty:SetAlpha(0.7)
    ui.empty = empty
end

function Refresh()
    if not frame then return end
    local rows, found, total = Lib.List(state.filter, state.search, state.sort)
    ui.count:SetText(found .. " / " .. total)
    for _, b in ipairs(ui.filters) do
        local c = b.id == state.filter and HEAD or INK
        b.text:SetTextColor(c[1], c[2], c[3])
        b.text:SetAlpha(b.id == state.filter and 1 or 0.7)
    end
    ui.sort:SetText(state.sort == "az" and (L.LIB_SORT_AZ or "A-Z") or (L.LIB_SORT_RECENT or "Recent"))
    ui.sort:SetWidth((ui.sort.text:GetStringWidth() or 30) + 10)
    ui.sort.text:SetTextColor(INK[1], INK[2], INK[3])
    state.offset = math.max(0, math.min(state.offset, math.max(0, #rows - ui.visible)))
    local current
    for i, r in ipairs(ui.rows) do
        local row = rows[state.offset + i]
        r.row = row
        if row then
            Font(r.text, 13, INK)
            r.text:SetText(row.locked and (row.title .. "  |cff8a7a66(" .. (L.LIB_NOT_FOUND or "not found yet") .. ")|r") or row.title)
            r.text:SetAlpha(row.locked and 0.45 or 1)
            r:Show()
            r.hl:SetShown(row.key == state.key)
        else
            r:Hide()
        end
    end
    for _, row in ipairs(rows) do if row.key == state.key then current = row end end
    if not current then
        -- l'ecrit choisi n'est plus dans la liste (filtre, recherche) : on le garde s'il existe
        if state.key then
            for _, row in ipairs((Lib.List("all", "", "az"))) do if row.key == state.key then current = row end end
        end
    end
    if current and not current.locked then
        local pages, complete = Lib.Pages(current)
        state.page = math.max(1, math.min(state.page, math.max(1, #pages)))
        ui.bookTitle:SetText(current.title)
        local e = current.entry
        local meta = {}
        if e and e.z then meta[#meta + 1] = e.z end
        if e and e.d and date and e.d > 0 then meta[#meta + 1] = date("%d/%m/%Y", e.d) end
        if not complete then meta[#meta + 1] = L.LIB_PARTIAL or "unfinished: open it in game to keep the next pages" end
        ui.meta:SetText(table.concat(meta, " - "))
        Font(ui.body, tonumber(DialogueWheelE_FontSize) or 14, INK)
        local text = pages[state.page] or ""
        if #pages == 0 then text = L.LIB_NO_TEXT or "Read before the library existed: open it again in game to keep its text." end
        ui.body:SetText(text)
        ui.child:SetHeight(math.max(10, (ui.body:GetStringHeight() or 10) + 6))
        ui.num:SetText((#pages > 1 or not complete) and (state.page .. " / " .. #pages .. (complete and "" or "+")) or "")
        ui.prev:SetShown(state.page > 1)
        ui.next:SetShown(state.page < #pages)
        ui.empty:SetText("")
        ui.scroll:Show()
    else
        ui.bookTitle:SetText("")
        ui.meta:SetText("")
        ui.body:SetText("")
        ui.num:SetText("")
        ui.prev:Hide(); ui.next:Hide()
        ui.scroll:Hide()
        ui.empty:SetText(found == 0 and (L.LIB_EMPTY or "Every book, letter or plaque you open is kept here.")
            or (L.LIB_PICK or "Pick a book on the left."))
    end
end
Lib.Refresh = Refresh

function Lib.Open()
    Build()
    Refresh()
    frame:Show()
end
function Lib.Toggle()
    Build()
    if frame:IsShown() then frame:Hide() else Lib.Open() end
end
-- Ouvre l'ecrit `title` (s'il est dans la bibliotheque).
function Lib.Show(title)
    local key = DWE.BookKey and DWE.BookKey(title)
    state.key, state.page = key, 1
    Lib.Open()
end
