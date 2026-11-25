-- Options en lignes natives du jeu (comme les options de Blizzard) : navigation a la manette
-- fiable, recherche du jeu, bouton "Par defaut" de chaque page.
-- Chaque reglage lit et ecrit les memes variables que les anciennes pages : les deux restent
-- d'accord tant que les anciennes pages existent (refonte page par page).
local DWE = DWE
if not DWE then return end

local Native = {}
DWE.Native = Native
-- Fenetre d'options de Storytale (a la place des pages du panneau d'options du jeu).
-- A mettre a false dans une version publiee tant qu'elle n'est pas finie.
DWE.NATIVE_OPTIONS = true

-- Les pages se decrivent ligne par ligne (cases, listes, curseurs, boutons, titres) ; la fenetre
-- les dessine elle-meme. Rien ne passe par le panneau d'options du jeu : a la manette, ses
-- listes et sa navigation se bloquaient des qu'un addon y ajoutait des lignes ("Interface action
-- failed", taint.log du 25/11), et sa liste de categories se parcourait mal.
Native.pages = {}
Native.byId = {}

local function Bare(text)
    return (tostring(text or ""):gsub("%s*[:：]%s*$", ""))
end
Native.Bare = Bare

local function Tip(key)
    local L = DWE.L or {}
    return L[key .. "_TIP"]
end

-- Une ligne : kind = "check" | "choice" | "slider" | "button" | "header".
local Row = {}
Row.__index = Row
function Row:SetParentInitializer(parent, when)
    self.parent = parent
    self.indent = true
    if when then self:AddModifyPredicate(when) end
end
function Row:AddModifyPredicate(when)
    self.preds = self.preds or {}
    self.preds[#self.preds + 1] = when
end
function Row:IsEnabled()
    for _, p in ipairs(self.preds or {}) do
        local ok, r = pcall(p)
        if ok and not r then return false end
    end
    return true
end
function Row:Value()
    if not self.get then return nil end
    local ok, v = pcall(self.get)
    if ok then return v end
end
function Row:Set(v)
    if self.set then pcall(self.set, v) end
    Native.Refresh()
end
function Row:Items()
    local items = self.items
    if type(items) == "function" then
        local ok, r = pcall(items)
        items = ok and r or nil
    end
    return type(items) == "table" and items or {}
end
function Row:ValueText()
    local v = self:Value()
    if self.kind == "choice" then
        for _, it in ipairs(self:Items()) do if it[1] == v then return it[2] or tostring(v) end end
        return v ~= nil and tostring(v) or "-"
    elseif self.kind == "slider" then
        v = tonumber(v) or self.default or 0
        return self.fmt and self.fmt:format(v) or tostring(v)
    elseif self.kind == "button" then
        return self.text or ""
    end
end
-- Gauche / droite (manette, fleches, petites fleches de la ligne).
function Row:Step(dir)
    if not self:IsEnabled() then return end
    if self.kind == "check" then
        self:Set(not self:Value())
    elseif self.kind == "choice" then
        local items = self:Items()
        if #items == 0 then return end
        local cur, idx = self:Value(), 0
        for i, it in ipairs(items) do if it[1] == cur then idx = i break end end
        idx = idx + dir
        if idx < 1 then idx = #items elseif idx > #items then idx = 1 end
        self:Set(items[idx][1])
    elseif self.kind == "slider" then
        local v = (tonumber(self:Value()) or self.default or self.min) + dir * self.step
        v = math.max(self.min, math.min(self.max, v))
        v = math.floor(v / self.step + 0.5) * self.step
        self:Set(v)
    end
end
-- A / Entree / clic.
function Row:Activate()
    if not self:IsEnabled() then return end
    if self.kind == "check" then
        self:Set(not self:Value())
    elseif self.kind == "choice" then
        local row = self
        if DWE.PickList then
            DWE.PickList({ title = self.label, items = self:Items(), current = self:Value(),
                onPick = function(v) row:Set(v) end })
        end
    elseif self.kind == "button" then
        if self.onClick then pcall(self.onClick) end
        Native.Refresh()
    end
end

local function NewRow(page, kind, id, label, tip)
    local r = setmetatable({ kind = kind, id = id, label = label, tip = tip, page = page }, Row)
    page.rows[#page.rows + 1] = r
    if id then Native.byId[id] = r end
    return r
end

function Native.Sub(_, name)
    local page = { name = name, rows = {} }
    Native.pages[#Native.pages + 1] = page
    return page, page
end
function Native.Check(page, id, label, tip, default, get, set)
    local r = NewRow(page, "check", id, label, tip)
    r.default = default
    r.get = function() return get() and true or false end
    r.set = set
    return r, r
end
function Native.Choice(page, id, label, tip, default, items, get, set)
    local r = NewRow(page, "choice", id, label, tip)
    r.default, r.items, r.get, r.set = default, items, get, set
    return r, r
end
function Native.Slider(page, id, label, tip, default, min, max, step, fmt, get, set)
    local r = NewRow(page, "slider", id, label, tip)
    r.default, r.min, r.max, r.step, r.fmt, r.get, r.set = default, min, max, step, fmt, get, set
    return r, r
end
function Native.Button(page, label, text, onClick, tip)
    local r = NewRow(page, "button", nil, label, tip)
    r.text, r.onClick = text, onClick
    return r
end
function Native.Header(page, text)
    return NewRow(page, "header", nil, text)
end
function Native.DependsOn(child, parent, when)
    if type(child) == "table" and child.SetParentInitializer and parent then child:SetParentInitializer(parent, when) end
end
-- Nouveau texte d'un bouton (touche choisie...).
function Native.SetButtonText(row, text)
    if type(row) == "table" then row.text = text end
    Native.Refresh()
end
-- Profil change, page remise a zero... : la fenetre relit ses valeurs.
function Native.Refresh()
    Native.refreshCount = (Native.refreshCount or 0) + 1
    if Native.window and Native.window:IsShown() and Native.window.Draw then pcall(Native.window.Draw) end
end
Native.RefreshRows = Native.Refresh

---------------------------------------------------------------------------- Placement
local function BuildPlacement(parent)
    local L = DWE.L
    local cat, layout = Native.Sub(parent, L.SEC_PLACE)
    if not cat then return end
    Native.Check(cat, "AttachNPC", L.ATTACH_NPC, L.ATTACH_TIP, true,
        function() return DialogueWheelE_AttachNPC ~= false end,
        function(v)
            DialogueWheelE_AttachNPC = v and true or false
            if not v and DWE.StopFollow then DWE.StopFollow() end
            if DWE.SettingsChanged then DWE.SettingsChanged() end
        end)
    Native.Button(layout, L.NPC_RESET, L.NPC_RESET, function() if DWE.ResetNPCOffset then DWE.ResetNPCOffset() end end)
    Native.Check(cat, "Locked", L.LOCK, Tip("LOCK"), false,
        function() return DWE.IsLocked and DWE.IsLocked() end,
        function(v)
            DialogueWheelE_Locked = v and true or false
            if DWE.ApplyLock then DWE.ApplyLock() end
            if DWE.SettingsChanged then DWE.SettingsChanged() end
        end)
    Native.Choice(cat, "WheelSide", L.WHEEL_SIDE, nil, "right",
        { { "right", L.SIDE_RIGHT }, { "left", L.SIDE_LEFT } },
        function() return DialogueWheelE_WheelSide == "left" and "left" or "right" end,
        function(v)
            DialogueWheelE_WheelSide = (v == "left") and "left" or nil
            if not DialogueWheelE_Pos and DWE.RestorePosition then DWE.RestorePosition() end
            if DWE.SettingsChanged then DWE.SettingsChanged() end
        end)
    Native.Check(cat, "QuestAuto", L.QUEST_AUTO_W, Tip("QUEST_AUTO_W"), true,
        function() return DialogueWheelE_QuestAuto ~= false end,
        function(v)
            if v then DialogueWheelE_QuestAuto = nil else DialogueWheelE_QuestAuto = false end
            if DialogueWheelE_QuestAuto == false and not tonumber(DialogueWheelE_QuestWidth) and DWE.AutoQuestWidth then
                DialogueWheelE_QuestWidth = DWE.AutoQuestWidth()
            end
            if DWE.SettingsChanged then DWE.SettingsChanged() end
        end)
    Native.placement = cat
    return cat
end

---------------------------------------------------------------------------- Livres, lettres et plaques
local function BuildBooks(parent)
    local L = DWE.L
    local cat = Native.Sub(parent, L.SEC_BOOKS)
    if not cat then return end
    -- Qui affiche : Storytale, DialogueUI (seulement s'il est actif) ou le jeu.
    local duiOn = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("DialogueUI")
    local function Shown(withDUI)
        local list = { { "addon", L.PLATE_ADDON } }
        if withDUI then list[#list + 1] = { "dui", L.BOOK_DUI } end
        list[#list + 1] = { "blizzard", L.BOOK_BLIZZ }
        return list
    end
    local function Visuals()
        if DWE.bookMode and DWE.textBox and DWE.textBox:IsShown() and DWE.UpdateTextPanelVisuals then DWE.UpdateTextPanelVisuals() end
    end
    local _, styleInit = Native.Choice(cat, "BookStyle", L.BOOK_STYLE, L.BOOK_ADDON_TIP, "addon", Shown(duiOn),
        function()
            local v = DialogueWheelE_BookStyle or "addon"
            if v == "dui" and not duiOn then v = "addon" end
            return v
        end,
        function(v)
            DialogueWheelE_BookStyle = v
            if DWE.RefreshBookLookOptions then DWE.RefreshBookLookOptions() end
        end)
    local _, lookInit = Native.Choice(cat, "BookLook", L.BOOK_LOOK, nil, "auto",
        { { "auto", L.BOOK_LOOK_AUTO }, { "note", L.BOOK_LOOK_NOTE }, { "book", L.BOOK_LOOK_BOOK } },
        function() return (DialogueWheelE_BookLook ~= "frame" and DialogueWheelE_BookLook) or "auto" end,
        function(v) DialogueWheelE_BookLook = v; Visuals() end)
    -- Le style ne concerne que les livres affiches par Storytale.
    Native.DependsOn(lookInit, styleInit, function() return (DialogueWheelE_BookStyle or "addon") == "addon" end)
    local _, plateInit = Native.Choice(cat, "PlateStyle", L.PLATE_STYLE, L.PLATE_ADDON_TIP, "addon", Shown(duiOn),
        function()
            local v = DialogueWheelE_PlateStyle or "addon"
            if v == "dui" and not duiOn then v = "addon" end
            return v
        end,
        function(v)
            DialogueWheelE_PlateStyle = (v ~= "addon") and v or nil
            if DWE.RefreshPlateLookOptions then DWE.RefreshPlateLookOptions() end
        end)
    local _, matInit = Native.Choice(cat, "PlateLook", L.PLATE_LOOK, L.PLATE_AUTO_TIP, "auto",
        { { "auto", L.BOOK_LOOK_AUTO }, { "Stone", L.PLATE_STONE }, { "Marble", L.PLATE_MARBLE },
            { "Bronze", L.PLATE_BRONZE }, { "Silver", L.PLATE_SILVER } },
        function() return DialogueWheelE_PlateLook or "auto" end,
        function(v) DialogueWheelE_PlateLook = (v ~= "auto") and v or nil; Visuals() end)
    -- La matiere ne concerne que les plaques affichees par Storytale.
    Native.DependsOn(matInit, plateInit, function() return (DialogueWheelE_PlateStyle or "addon") == "addon" end)
    Native.Check(cat, "ReadMarks", L.READ_MARKS, Tip("READ_MARKS"), true,
        function() return DialogueWheelE_ReadMarks ~= false end,
        function(v) if v then DialogueWheelE_ReadMarks = nil else DialogueWheelE_ReadMarks = false end end)
    Native.Check(cat, "BookTipCursor", L.BOOK_TIP_CURSOR, Tip("BOOK_TIP_CURSOR"), false,
        function() return DialogueWheelE_BookTipCursor == true end,
        function(v) DialogueWheelE_BookTipCursor = v and true or false end)
    Native.Check(cat, "BookAutoScroll", L.BOOK_AUTOSCROLL, Tip("BOOK_AUTOSCROLL"), true,
        function() return DialogueWheelE_BookAutoScroll ~= false end,
        function(v) DialogueWheelE_BookAutoScroll = v and true or false end)
    Native.Check(cat, "BookTurnFX", L.BOOK_TURN_FX, Tip("BOOK_TURN_FX"), true,
        function() return DialogueWheelE_BookTurnFX ~= false end,
        function(v) DialogueWheelE_BookTurnFX = v and true or false end)
    Native.books = cat
    return cat
end

---------------------------------------------------------------------------- Touches et manette
local function BuildKeys(parent)
    local L = DWE.L
    local cat, layout = Native.Sub(parent, L.CAT_KEYS)
    if not cat then return end
    local Label = DWE.KeyLabel or function(k) return (k and k ~= "") and k or "-" end
    local keyInit
    local function KeyText()
        if DialogueWheelE_UseBlizzKey ~= false then
            return Label(DWE.GetEffectiveInteractKey and DWE.GetEffectiveInteractKey()) .. (L.KEY_BLIZZ_TAG or "")
        end
        return Label(DialogueWheelE_InteractKey)
    end
    local _, blizzInit = Native.Check(cat, "UseBlizzKey", L.KEY_USE_BLIZZ, Tip("KEY_USE_BLIZZ"), true,
        function() return DialogueWheelE_UseBlizzKey ~= false end,
        function(v)
            DialogueWheelE_UseBlizzKey = v and true or false
            Native.SetButtonText(keyInit, KeyText())
            if DWE.RefreshBindings then DWE.RefreshBindings() end
            if DWE.SettingsChanged then DWE.SettingsChanged() end
        end)
    -- Touche dediee : une fenetre attend la touche (Echap = aucune).
    keyInit = Native.Button(layout, Bare(L.KEY_CUSTOM), KeyText(), function()
        if DialogueWheelE_UseBlizzKey ~= false or not DWE.AskKey then return end
        DWE.AskKey(L.KEY_CUSTOM, DialogueWheelE_InteractKey, function(k)
            DialogueWheelE_InteractKey = k
            Native.SetButtonText(keyInit, KeyText())
        end)
    end)
    Native.DependsOn(keyInit, blizzInit, function() return DialogueWheelE_UseBlizzKey == false end)
    Native.Check(cat, "EscClose", L.ESC_CLOSE, Tip("ESC_CLOSE"), true,
        function() return DialogueWheelE_EscClose ~= false end,
        function(v) DialogueWheelE_EscClose = v and true or false end)
    Native.Check(cat, "WheelScroll", L.WHEEL_SCROLL, Tip("WHEEL_SCROLL"), true,
        function() return DialogueWheelE_WheelScroll ~= false end,
        function(v)
            DialogueWheelE_WheelScroll = v and true or false
            if DWE.RefreshBindings then DWE.RefreshBindings() end
        end)
    Native.Header(layout, L.SEC_PAD)
    -- Les lignes d'aide de l'ancienne page vont dans l'infobulle (pas de texte libre ici).
    local help = {}
    for _, k in ipairs({ "PAD_HELP1", "PAD_HELP2", "PAD_HELP4", "PAD_HELP3" }) do
        if L[k] then help[#help + 1] = L[k] end
    end
    Native.Check(cat, "GamePad", L.PAD_USE, table.concat(help, "\n\n"), true,
        function() return DialogueWheelE_GamePad ~= false end,
        function(v)
            DialogueWheelE_GamePad = v and true or false
            if DWE.RefreshBindings then DWE.RefreshBindings() end
        end)
    Native.keys = cat
    return cat
end

---------------------------------------------------------------------------- Spoken
-- Ligne active seulement si when() est vrai (grisee sinon), sans ligne parente.
function Native.EnabledIf(init, when)
    if type(init) == "table" and type(init.AddModifyPredicate) == "function" then pcall(init.AddModifyPredicate, init, when) end
end

local function BuildSpoken(parent)
    local L = DWE.L
    local cat, layout = Native.Sub(parent, L.SEC_SPOKEN)
    if not cat then return end
    local function SpokenOn() return DWE.SpokenFocus and DWE.SpokenFocus.Available and DWE.SpokenFocus.Available() and true or false end
    if not SpokenOn() then Native.Header(layout, L.SPOKEN_NEEDED) end
    local all = {}
    local function Keep(init) if init then all[#all + 1] = init end return init end
    local function Skin()
        if DWE.spokenSkinShow then pcall(DWE.spokenSkinShow) end
        if DWE.RefreshSpoken then DWE.RefreshSpoken() end
    end
    local _, themeInit = Native.Check(cat, "SpokenTheme", L.SPOKEN_THEME, Tip("SPOKEN"), false,
        function() return DialogueWheelE_SpokenTheme == true end,
        function(v) DialogueWheelE_SpokenTheme = v and true or false; Skin() end)
    Keep(themeInit)
    -- Habillage du lecteur : "follow" = le reglage n'est pas choisi (nil), comme la case de l'ancienne page.
    local function Themes(list)
        for _, t in ipairs(DWE.THEME_LIST or {}) do list[#list + 1] = { t.id, L[t.key] or t.id } end
        return list
    end
    local mats = { { "mat:Stone", L.PLATE_STONE }, { "mat:Marble", L.PLATE_MARBLE },
        { "mat:Bronze", L.PLATE_BRONZE }, { "mat:Silver", L.PLATE_SILVER } }
    local paper = { "paper", L.SKIN_PAPER or L.PLACE_PAPER }
    local function List(first, ...)
        local list = { first }
        for _, part in ipairs({ ... }) do for _, e in ipairs(part) do list[#list + 1] = e end end
        return Themes(list)
    end
    local function SkinChoice(id, label, var, items, check)
        local _, init = Native.Choice(cat, id, label, nil, "follow", items,
            function()
                local v = _G[var]
                if v == nil or (check and not check(v)) then return "follow" end
                return v
            end,
            function(v)
                _G[var] = (v ~= "follow") and v or nil
                Skin()
            end)
        Native.DependsOn(init, themeInit, function() return DialogueWheelE_SpokenTheme == true end)
        return Keep(init)
    end
    SkinChoice("SpokenSkin", L.SKIN_ROW_VOICE, "DialogueWheelE_SpokenSkin", List({ "follow", L.SPOKEN_SKIN_FOLLOW }))
    local placeExtra = { paper }
    if DWE.DUI_ON then placeExtra[2] = { "dui", L.BOOK_DUI } end
    SkinChoice("PlaceSkin", L.SKIN_ROW_PLACE, "DialogueWheelE_PlaceSkin", List({ "follow", L.PLACE_FOLLOW }, placeExtra),
        function(v) return v ~= "dui" or DWE.DUI_ON end)
    -- Livres : "Page de livre" est le choix par defaut (nil) ; "paper" choisi revient au meme.
    SkinChoice("BookSkin", L.SKIN_ROW_BOOK, "DialogueWheelE_BookSkin", List({ "follow", L.SKIN_PAPER or L.PLACE_PAPER }, mats),
        function(v) return v ~= "paper" end)
    SkinChoice("PlateSkin", L.SKIN_ROW_PLATE, "DialogueWheelE_PlateSkin", List({ "follow", L.PLATE_FOLLOW }, mats, { paper }))
    -- Bulle ou lecteur Spoken : bouton sur la roue, choix de l'affichage, touche.
    Keep(select(2, Native.Check(cat, "SpokenButton", L.SPOKEN_BUTTON, Tip("SPOKEN_BUTTON"), false,
        function() return DialogueWheelE_SpokenButton == true end,
        function(v)
            DialogueWheelE_SpokenButton = v and true or false
            if DWE.RefreshBindings then DWE.RefreshBindings() end
        end)))
    Keep(select(2, Native.Choice(cat, "TextIn", Bare(L.TEXT_IN), nil, "spoken",
        { { "storytale", L.TEXT_IN_STORYTALE }, { "spoken", L.TEXT_IN_SPOKEN } },
        function() return DialogueWheelE_ShowText == true and "storytale" or "spoken" end,
        function(v)
            if (DialogueWheelE_ShowText == true) ~= (v == "storytale") and DWE.ToggleDialogueText then DWE.ToggleDialogueText() end
        end)))
    local Label = DWE.KeyLabel or function(k) return (k and k ~= "") and k or "-" end
    local toggleInit
    toggleInit = Keep(Native.Button(layout, Bare(L.KEY_TOGGLE), Label(DialogueWheelE_ToggleKey), function()
        if not (SpokenOn() and DWE.AskKey) then return end
        DWE.AskKey(L.KEY_TOGGLE, DialogueWheelE_ToggleKey, function(k)
            DialogueWheelE_ToggleKey = k
            Native.SetButtonText(toggleInit, Label(k))
        end)
    end))
    local smartTip = L.SPOKEN_SMART_TIP
    if smartTip and L.SPOKEN_SMART_HINT then smartTip = smartTip .. "\n\n" .. L.SPOKEN_SMART_HINT end
    Keep(select(2, Native.Check(cat, "SpokenSmart", L.SPOKEN_SMART, smartTip, true,
        function() return DialogueWheelE_SpokenSmart ~= false end,
        function(v) DialogueWheelE_SpokenSmart = v and true or false end)))
    local function Highlight() if DWE.Bubble and DWE.Bubble.RefreshHighlight then DWE.Bubble.RefreshHighlight() end end
    Keep(select(2, Native.Check(cat, "BubbleHighlight", L.BUBBLE_HIGHLIGHT, Tip("BUBBLE_HIGHLIGHT"), false,
        function() return DialogueWheelE_BubbleHighlight == true end,
        function(v) DialogueWheelE_BubbleHighlight = v and true or nil; Highlight() end)))
    local modeTip
    if L.BUBBLE_MODE_TYPE_TIP and L.BUBBLE_MODE_PAGE_TIP then
        modeTip = "|cffffd100" .. L.BUBBLE_MODE_TYPE .. "|r\n" .. L.BUBBLE_MODE_TYPE_TIP .. "\n\n|cffffd100" .. L.BUBBLE_MODE_PAGE .. "|r\n" .. L.BUBBLE_MODE_PAGE_TIP
    end
    Keep(select(2, Native.Choice(cat, "BubbleMode", Bare(L.BUBBLE_MODE), modeTip, "type",
        { { "type", L.BUBBLE_MODE_TYPE }, { "page", L.BUBBLE_MODE_PAGE } },
        function() return DialogueWheelE_BubbleMode == "page" and "page" or "type" end,
        function(v) DialogueWheelE_BubbleMode = (v == "page") and "page" or nil; Highlight() end)))
    Keep(select(2, Native.Check(cat, "BookVoiceTurn", L.BOOK_VOICE_TURN, nil, false,
        function() return DialogueWheelE_BookVoiceTurn == true end,
        function(v) DialogueWheelE_BookVoiceTurn = v and true or nil end)))
    Keep(select(2, Native.Check(cat, "BookStopOnClose", L.BOOK_STOP_CLOSE, nil, false,
        function() return DialogueWheelE_BookStopOnClose == true end,
        function(v) DialogueWheelE_BookStopOnClose = v and true or nil end)))
    local function Art() if DWE.ZoneArtRefresh then DWE.ZoneArtRefresh() end end
    local _, artInit = Native.Check(cat, "ZoneArt", L.ZONE_ART, Tip("ZONE_ART"), true,
        function() return DialogueWheelE_ZoneArt ~= false end,
        function(v) DialogueWheelE_ZoneArt = v and true or false; Art() end)
    Keep(artInit)
    local _, paperInit = Native.Check(cat, "ZoneArtPaper", L.ZONE_ART_PAPER, nil, false,
        function() return DialogueWheelE_ZoneArtPaper == true end,
        function(v) DialogueWheelE_ZoneArtPaper = v and true or nil; Art() end)
    Native.DependsOn(paperInit, artInit, function() return DialogueWheelE_ZoneArt ~= false end)
    Keep(paperInit)
    -- Sans Spoken : tout est grise.
    for _, init in ipairs(all) do Native.EnabledIf(init, SpokenOn) end
    Native.spoken = cat
    return cat
end

---------------------------------------------------------------------------- Profils
local function BuildProfiles(parent)
    local L = DWE.L
    local cat, layout = Native.Sub(parent, L.SEC_PROFILES)
    if not (cat and DWE.ProfileList) then return end
    local function Named(list)
        local out = {}
        for _, n in ipairs(list) do out[#out + 1] = { n, DWE.ProfileLabel(n) } end
        return out
    end
    local function Others(withDefault)
        local l = { { "", "-" } }
        for _, n in ipairs(DWE.ProfileList()) do
            if n ~= DWE.profile and (withDefault or n ~= "Default") then l[#l + 1] = { n, DWE.ProfileLabel(n) } end
        end
        return l
    end
    -- Profil utilise : change tout de suite (rien n'est perdu, on peut revenir).
    Native.Choice(cat, "Profile", Bare(L.PROFILE_CUR), L.PROFILE_HINT, "Default",
        function() return Named(DWE.ProfileList()) end,
        function() return DWE.profile or "Default" end,
        function(v) if v and v ~= DWE.profile then DWE.AskProfile("switch", v) end end)
    -- Copier depuis / supprimer : une action, la ligne revient a "-" ; confirmation demandee.
    Native.Choice(cat, "ProfileCopyFrom", Bare(L.PROFILE_COPY_FROM), nil, "",
        function() return Others(true) end,
        function() return "" end,
        function(v) if v and v ~= "" then DWE.AskProfile("copyfrom", v) end end)
    Native.Choice(cat, "ProfileDelete", Bare(L.PROFILE_DEL_ROW), nil, "",
        function() return Others(false) end,
        function() return "" end,
        function(v) if v and v ~= "" then DWE.AskProfile("delete", v) end end)
    Native.Button(layout, L.PROFILE_NEW_BTN, L.PROFILE_NEW_BTN, function() DWE.AskProfile("new") end)
    Native.Choice(cat, "ProfileForNew", Bare(L.PROFILE_FOR_NEW), nil, "Default",
        function() return Named(DWE.ProfileList()) end,
        function() return DWE.ProfileNewCharName and DWE.ProfileNewCharName() or "Default" end,
        function(v)
            if v and DWE.ProfileSetForNew then DWE.ProfileSetForNew(v) end
            if DWE.RefreshProfilesUI then DWE.RefreshProfilesUI() end
        end)
    -- Tout remettre par defaut : la fenetre de Storytale (atteignable a la manette).
    Native.Button(layout, L.RESET_ALL, L.RESET_ALL, function() if DWE.AskResetAll then DWE.AskResetAll() end end)
    Native.profiles = cat
    return cat
end

---------------------------------------------------------------------------- Apparence
-- Les vignettes des themes et les couleurs du theme Personnalise restent sur la page Storytale
-- (dessins, pas des lignes) ; ici le theme se choisit dans une liste.
local function BuildLooks(parent)
    local L = DWE.L
    local cat = Native.Sub(parent, L.SEC_THEME)
    if not cat then return end
    local function Theme()
        if DWE.RefreshOptionsExtra then pcall(DWE.RefreshOptionsExtra) end
        if DWE.OnThemeChanged then DWE.OnThemeChanged() end
    end
    local function Wheel()
        if DWE.choiceBox and DWE.choiceBox:IsShown() and DWE.UpdateVisuals then DWE.UpdateVisuals() end
    end
    Native.Choice(cat, "Theme", Bare(L.SEC_THEME), L.THEME_HINT, "bubble",
        function()
            local list = {}
            for _, t in ipairs(DWE.THEME_LIST or {}) do list[#list + 1] = { t.id, L[t.key] or t.id } end
            return list
        end,
        function()
            local v = DialogueWheelE_Theme or "bubble"
            if v == "scroll" then v = "parchment" end
            return v
        end,
        function(v) DialogueWheelE_Theme = v; Theme() end)
    Native.Check(cat, "ThemeFrames", L.THEME_BUBBLES, Tip("THEME_BUBBLES"), true,
        function() return DialogueWheelE_ThemeFrames ~= true end,
        function(v) DialogueWheelE_ThemeFrames = not v; Theme() end)
    Native.Check(cat, "WheelTheme", L.WHEEL_THEME, nil, false,
        function() return DialogueWheelE_WheelTheme == true end,
        function(v) DialogueWheelE_WheelTheme = v and true or false; if DWE.OnThemeChanged then DWE.OnThemeChanged() end end)
    Native.Slider(cat, "Opacity", L.OPACITY_LBL, nil, 1, 0.2, 1, 0.05, "%.2f",
        function() return tonumber(DialogueWheelE_Opacity) or 1 end,
        function(v)
            DialogueWheelE_Opacity = v
            if DWE.OnThemeChanged then DWE.OnThemeChanged() end
            if DWE.ApplyBubbleOpacity then DWE.ApplyBubbleOpacity() end
            Wheel()
        end)
    Native.Check(cat, "HideUI", L.HIDE_UI, Tip("HIDE_UI"), false,
        function() return DialogueWheelE_HideUI == true end,
        function(v) DialogueWheelE_HideUI = v and true or false end)
    Native.Check(cat, "MinimapHide", L.MINIMAP_BTN, L.MINIMAP_TIP, true,
        function() return DialogueWheelE_MinimapHide ~= true end,
        function(v)
            DialogueWheelE_MinimapHide = (not v) and true or nil
            if DWE.MinimapButtonRefresh then DWE.MinimapButtonRefresh() end
        end)
    -- Texte : police (pas en chinois/coreen : la police du jeu est imposee), tailles.
    if not DWE.IS_CJK then
        Native.Choice(cat, "Font", Bare(L.FONT_FAMILY), nil, "friz",
            function()
                local list = {}
                for _, f in ipairs(DWE.FONTS or {}) do
                    list[#list + 1] = { f.id, f.default and (f.name .. " (" .. (L.FONT_DEFAULT or "") .. ")") or f.name }
                end
                return list
            end,
            function() return DialogueWheelE_Font or "friz" end,
            function(v) DialogueWheelE_Font = v; if DWE.ApplyFont then DWE.ApplyFont() end end)
    end
    Native.Slider(cat, "FontSize", L.FONT_SIZE, nil, 14, 10, 22, 1, "%d pt",
        function() return tonumber(DialogueWheelE_FontSize) or 14 end,
        function(v) DialogueWheelE_FontSize = v; if DWE.ApplyFont then DWE.ApplyFont() end end)
    Native.Slider(cat, "ChoiceSize", L.CHOICE_SIZE, nil, 15, 10, 24, 1, "%d pt",
        function() return DWE.ChoiceSize and DWE.ChoiceSize() or 15 end,
        function(v) DialogueWheelE_ChoiceSize = v; Wheel() end)
    Native.looks = cat
    return cat
end

-- Appele une fois les anciennes pages creees (DWE.InitOptionsPanel).
function DWE.BuildNativeOptions()
    if Native.built then return end
    Native.built = true
    for _, b in ipairs({ BuildLooks, BuildSpoken, BuildBooks, BuildPlacement, BuildKeys, BuildProfiles }) do
        local ok, err = pcall(b)
        if not ok and DWE.Debug then DWE.Debug("options : " .. tostring(err)) end
    end
end

DWE.NativeRefresh = function() Native.Refresh() end

---------------------------------------------------------------------------- Fenetre
-- Onglets a gauche, lignes a droite. Manette : croix haut/bas (ligne), gauche/droite (valeur),
-- A (cocher, ouvrir la liste, bouton), B (fermer), gachettes (onglet). Clavier : fleches,
-- Entree / Espace, Echap, Tab. Souris : tout se clique, molette pour defiler.
local W, H, TABS_W, ROW_H, VISIBLE = 720, 500, 170, 30, 13
local CONTROL_X = 300 -- debut des reglages dans la ligne

local function Gold(fs) fs:SetTextColor(1, 0.82, 0) end

local function MakeWindow()
    local L = DWE.L
    local f = CreateFrame("Frame", "StorytaleOptionsWindow", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    Native.window = f
    f:SetSize(W, H)
    f:SetPoint("CENTER")
    f:SetFrameStrata("FULLSCREEN")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    if f.SetBackdrop then
        f:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 } })
    end
    f.title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    f.title:SetPoint("TOP", 0, -18)
    f.title:SetText("Storytale")
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)
    close:SetScript("OnClick", function() f:Hide() end)
    f.hint = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    f.hint:SetPoint("BOTTOM", 0, 16)
    f.hint:SetText(L.OPT_WINDOW_HINT or "")

    -- Onglets
    f.tabs = {}
    for i, page in ipairs(Native.pages) do
        local b = CreateFrame("Button", nil, f)
        b:SetSize(TABS_W - 10, 28)
        b:SetPoint("TOPLEFT", 18, -48 - (i - 1) * 30)
        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetAllPoints()
        b.bg:SetColorTexture(1, 0.82, 0, 0.16)
        b.hl = b:CreateTexture(nil, "HIGHLIGHT")
        b.hl:SetAllPoints()
        b.hl:SetColorTexture(1, 1, 1, 0.07)
        b.text = b:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        b.text:SetPoint("LEFT", 10, 0)
        b.text:SetPoint("RIGHT", -6, 0)
        b.text:SetJustifyH("LEFT")
        b.text:SetText(page.name or "")
        b:SetScript("OnClick", function() f.ShowPage(i) end)
        f.tabs[i] = b
    end
    local sep = f:CreateTexture(nil, "ARTWORK")
    sep:SetColorTexture(1, 0.82, 0, 0.25)
    sep:SetSize(1, H - 90)
    sep:SetPoint("TOPLEFT", TABS_W + 14, -48)

    -- Lignes
    f.rows = {}
    local x0 = TABS_W + 24
    local rowW = W - x0 - 22
    for i = 1, VISIBLE do
        local r = CreateFrame("Button", nil, f)
        r:SetSize(rowW, ROW_H)
        r:SetPoint("TOPLEFT", x0, -48 - (i - 1) * ROW_H)
        r.sel = r:CreateTexture(nil, "BACKGROUND")
        r.sel:SetAllPoints()
        r.sel:SetColorTexture(1, 0.82, 0, 0.14)
        r.hl = r:CreateTexture(nil, "HIGHLIGHT")
        r.hl:SetAllPoints()
        r.hl:SetColorTexture(1, 1, 1, 0.05)
        r.label = r:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        r.label:SetPoint("LEFT", 8, 0)
        r.label:SetWidth(CONTROL_X - 16)
        r.label:SetJustifyH("LEFT")
        r.label:SetWordWrap(false)
        -- case
        r.box = r:CreateTexture(nil, "ARTWORK")
        r.box:SetSize(24, 24)
        r.box:SetPoint("LEFT", CONTROL_X, 0)
        r.box:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
        r.tick = r:CreateTexture(nil, "OVERLAY")
        r.tick:SetSize(24, 24)
        r.tick:SetPoint("CENTER", r.box)
        r.tick:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        -- fleches + valeur (listes, curseurs)
        r.prev = CreateFrame("Button", nil, r)
        r.prev:SetSize(22, 22)
        r.prev:SetPoint("LEFT", CONTROL_X, 0)
        r.prev:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
        r.prev:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
        r.prev:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Disabled")
        r.value = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
        r.value:SetSize(170, 22)
        r.value:SetPoint("LEFT", r.prev, "RIGHT", 2, 0)
        r.next = CreateFrame("Button", nil, r)
        r.next:SetSize(22, 22)
        r.next:SetPoint("LEFT", r.value, "RIGHT", 2, 0)
        r.next:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
        r.next:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
        r.next:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Disabled")
        -- bouton seul
        r.button = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
        r.button:SetSize(214, 22)
        r.button:SetPoint("LEFT", CONTROL_X, 0)
        r.prev:SetScript("OnClick", function() if r.data then f.Select(r.index); r.data:Step(-1) end end)
        r.next:SetScript("OnClick", function() if r.data then f.Select(r.index); r.data:Step(1) end end)
        r.value:SetScript("OnClick", function() if r.data then f.Select(r.index); r.data:Activate() end end)
        r.button:SetScript("OnClick", function() if r.data then f.Select(r.index); r.data:Activate() end end)
        r:SetScript("OnClick", function() if r.data then f.Select(r.index); if r.data.kind == "check" then r.data:Activate() end end end)
        local function Enter() if r.data then f.ShowTip(r) end end
        local function Leave() GameTooltip:Hide() end
        for _, w in ipairs({ r, r.prev, r.next, r.value, r.button }) do
            w:HookScript("OnEnter", Enter)
            w:HookScript("OnLeave", Leave)
        end
        f.rows[i] = r
    end
    f.more = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    f.more:SetPoint("BOTTOMRIGHT", -24, 34)

    f.pageIndex, f.offset, f.selected = 1, 0, nil
    local function Page() return Native.pages[f.pageIndex] end
    local function Selectable(row) return row and row.kind ~= "header" end

    function f.ShowTip(r)
        local d = r.data
        if not d or not (d.tip or d.label) then return end
        GameTooltip:SetOwner(f, "ANCHOR_NONE")
        GameTooltip:SetPoint("TOPLEFT", f, "TOPRIGHT", 4, -40)
        GameTooltip:SetText(d.label or "", 1, 0.82, 0)
        if d.tip then GameTooltip:AddLine(d.tip, 1, 1, 1, true) end
        GameTooltip:Show()
    end

    function f.Draw()
        local page = Page()
        if not page then return end
        for i, t in ipairs(f.tabs) do t.bg:SetShown(i == f.pageIndex) end
        local rows = page.rows
        f.offset = math.max(0, math.min(f.offset or 0, #rows - VISIBLE))
        for i, r in ipairs(f.rows) do
            local k = f.offset + i
            local d = rows[k]
            r.data, r.index = d, k
            if not d then
                r:Hide()
            else
                r:Show()
                local on = d:IsEnabled()
                local kind = d.kind
                r.sel:SetShown(k == f.selected)
                r.label:SetText(d.label or "")
                r.label:ClearAllPoints()
                r.label:SetPoint("LEFT", (d.indent and 24 or 8), 0)
                if kind == "header" then
                    r.label:SetFontObject("GameFontNormal")
                    Gold(r.label)
                    r.label:SetWidth(r:GetWidth() - 16)
                else
                    r.label:SetFontObject("GameFontHighlight")
                    r.label:SetWidth(CONTROL_X - 16 - (d.indent and 16 or 0))
                    if on then r.label:SetTextColor(1, 1, 1) else r.label:SetTextColor(0.5, 0.5, 0.5) end
                end
                local isCheck = kind == "check"
                r.box:SetShown(isCheck)
                r.tick:SetShown(isCheck and d:Value() == true)
                if isCheck then r.box:SetDesaturated(not on); r.tick:SetDesaturated(not on) end
                local arrows = kind == "choice" or kind == "slider"
                r.prev:SetShown(arrows); r.next:SetShown(arrows); r.value:SetShown(arrows)
                if arrows then
                    r.value:SetText(d:ValueText() or "")
                    r.prev:SetEnabled(on); r.next:SetEnabled(on); r.value:SetEnabled(on)
                end
                r.button:SetShown(kind == "button")
                if kind == "button" then
                    r.button:SetText(d:ValueText() or "")
                    r.button:SetEnabled(on)
                end
            end
        end
        local n = #rows
        f.more:SetText(n > VISIBLE and ((f.offset + 1) .. "-" .. math.min(n, f.offset + VISIBLE) .. " / " .. n) or "")
        local sr = f.selected and f.rows[f.selected - f.offset]
        if sr and sr:IsShown() and f.padMode then f.ShowTip(sr) end
    end

    function f.Select(k)
        local rows = Page() and Page().rows or {}
        if not k or not rows[k] then return end
        f.selected = k
        if k <= f.offset then f.offset = k - 1 elseif k > f.offset + VISIBLE then f.offset = k - VISIBLE end
        f.Draw()
    end
    function f.Move(dir)
        local rows = Page() and Page().rows or {}
        local k = f.selected or 0
        for _ = 1, #rows do
            k = k + dir
            if k < 1 then k = #rows elseif k > #rows then k = 1 end
            if Selectable(rows[k]) then f.Select(k) return end
        end
    end
    function f.ShowPage(i)
        if not Native.pages[i] then return end
        f.pageIndex, f.offset, f.selected = i, 0, nil
        GameTooltip:Hide()
        f.Move(1)
        f.Draw()
    end
    local function Current()
        local rows = Page() and Page().rows or {}
        return f.selected and rows[f.selected]
    end
    local function Tab(dir)
        local n = #Native.pages
        local i = f.pageIndex + dir
        if i < 1 then i = n elseif i > n then i = 1 end
        f.ShowPage(i)
    end
    f.Tab = Tab

    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(_, d)
        f.offset = (f.offset or 0) - d
        f.Draw()
    end)
    f:EnableKeyboard(true)
    local OWN = { ESCAPE = true, UP = true, DOWN = true, LEFT = true, RIGHT = true, ENTER = true, SPACE = true, TAB = true }
    f:SetScript("OnKeyDown", function(self, key)
        -- La fenetre de choix (liste) a la main tant qu'elle est ouverte.
        if DWE.pickFrame and DWE.pickFrame:IsShown() then
            if self.SetPropagateKeyboardInput and not InCombatLockdown() then pcall(self.SetPropagateKeyboardInput, self, true) end
            return
        end
        if self.SetPropagateKeyboardInput and not InCombatLockdown() then pcall(self.SetPropagateKeyboardInput, self, not OWN[key]) end
        f.padMode = true
        local cur = Current()
        if key == "ESCAPE" then f:Hide()
        elseif key == "UP" then f.Move(-1)
        elseif key == "DOWN" then f.Move(1)
        elseif key == "LEFT" then if cur then cur:Step(-1) end
        elseif key == "RIGHT" then if cur then cur:Step(1) end
        elseif key == "ENTER" or key == "SPACE" then if cur then cur:Activate() end
        elseif key == "TAB" then Tab(IsShiftKeyDown() and -1 or 1) end
    end)
    if f.EnableGamePadButton then
        pcall(f.EnableGamePadButton, f, true)
        if f.SetPropagateGamePadInput then pcall(f.SetPropagateGamePadInput, f, false) end
        f:SetScript("OnGamePadButtonDown", function(_, b)
            if DWE.pickFrame and DWE.pickFrame:IsShown() then return end
            f.padMode = true
            local cur = Current()
            if b == "PADDUP" then f.Move(-1)
            elseif b == "PADDDOWN" then f.Move(1)
            elseif b == "PADDLEFT" then if cur then cur:Step(-1) end
            elseif b == "PADDRIGHT" then if cur then cur:Step(1) end
            elseif b == "PAD1" then if cur then cur:Activate() end
            elseif b == "PAD2" then f:Hide()
            elseif b == "PADLSHOULDER" or b == "PADLTRIGGER" then Tab(-1)
            elseif b == "PADRSHOULDER" or b == "PADRTRIGGER" then Tab(1) end
        end)
    end
    f:SetScript("OnHide", function()
        GameTooltip:Hide()
        if DWE.pickFrame and DWE.pickFrame:IsShown() then DWE.pickFrame.Close() end
    end)
    f:Hide()
    return f
end

function DWE.OpenOptionsWindow(pageIndex)
    DWE.BuildNativeOptions()
    local f = Native.window or MakeWindow()
    f.padMode = false
    f:Show()
    f:Raise()
    f.ShowPage(pageIndex or f.pageIndex or 1)
    return f
end
function DWE.ToggleOptionsWindow()
    if Native.window and Native.window:IsShown() then Native.window:Hide() else DWE.OpenOptionsWindow() end
end
