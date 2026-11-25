-- Options en lignes natives du jeu (comme les options de Blizzard) : navigation a la manette
-- fiable, recherche du jeu, bouton "Par defaut" de chaque page.
-- Chaque reglage lit et ecrit les memes variables que les anciennes pages : les deux restent
-- d'accord tant que les anciennes pages existent (refonte page par page).
local DWE = DWE
if not DWE then return end

local Native = {}
DWE.Native = Native
-- Pages natives visibles (branche de travail). A mettre a false dans une version publiee tant
-- que la refonte n'est pas finie.
DWE.NATIVE_OPTIONS = true
Native.settings = {}

local function Supported()
    return type(Settings) == "table" and type(Settings.RegisterVerticalLayoutSubcategory) == "function"
        and type(Settings.RegisterProxySetting) == "function" and type(Settings.CreateCheckbox) == "function"
end
Native.Supported = Supported

local function Tip(key)
    local L = DWE.L or {}
    return L[key .. "_TIP"]
end

-- Reglage relie a une valeur de Storytale : get() la lit, set(v) l'applique (memes effets que
-- l'ancienne case ou liste).
local function Proxy(cat, id, kind, label, default, get, set)
    local ok, setting = pcall(Settings.RegisterProxySetting, cat, "Storytale_" .. id, kind, label, default, get, set)
    if ok and setting then
        Native.settings[#Native.settings + 1] = setting
        return setting
    end
end

function Native.Check(cat, id, label, tip, default, get, set)
    local s = Proxy(cat, id, type(true), label, default, function() return get() and true or false end, set)
    local init
    if s then
        local ok, r = pcall(Settings.CreateCheckbox, cat, s, tip)
        if ok then init = r end
    end
    return s, init
end

function Native.Choice(cat, id, label, tip, default, items, get, set)
    local s = Proxy(cat, id, type(""), label, default, get, set)
    if not s then return end
    local function Options()
        local c = Settings.CreateControlTextContainer()
        for _, it in ipairs(items) do c:Add(it[1], it[2]) end
        return c:GetData()
    end
    local ok, init = pcall(Settings.CreateDropdown, cat, s, Options, tip)
    return s, ok and init or nil
end

-- La ligne `child` n'est active que si when() est vrai (grisee sinon), comme dans les options du jeu.
function Native.DependsOn(child, parent, when)
    if type(child) == "table" and type(parent) == "table" and type(child.SetParentInitializer) == "function" then
        pcall(child.SetParentInitializer, child, parent, when)
    end
end

function Native.Button(layout, label, text, onClick, tip)
    local make = rawget(_G, "CreateSettingsButtonInitializer")
    if not (layout and make) then return end
    local ok, init = pcall(make, label, text, onClick, tip, true)
    if ok and init then pcall(layout.AddInitializer, layout, init) end
end

function Native.Header(layout, text)
    local make = rawget(_G, "CreateSettingsListSectionHeaderInitializer")
    if not (layout and make) then return end
    local ok, init = pcall(make, text)
    if ok and init then pcall(layout.AddInitializer, layout, init) end
end

-- Profil change, page remise a zero... : les lignes affichees relisent leur valeur.
function Native.Refresh()
    -- Jamais pendant que les options du jeu sont ouvertes : NotifyUpdate fait noter le reglage
    -- comme modifie dans la liste du panneau, au nom de Storytale ; a la fermeture (Echap), le jeu
    -- parcourt cette liste contaminee et la manette se bloque ("Default all" puis Echap). Les
    -- lignes relisent de toute facon leur valeur quand la page s'affiche.
    local sp = rawget(_G, "SettingsPanel")
    if sp and sp.IsShown and sp:IsShown() then return end
    for _, s in ipairs(Native.settings) do
        if s.NotifyUpdate then pcall(s.NotifyUpdate, s) end
    end
end

---------------------------------------------------------------------------- Placement
local function BuildPlacement(parent)
    local L = DWE.L
    local cat, layout = Settings.RegisterVerticalLayoutSubcategory(parent, L.SEC_PLACE .. " (2)")
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
    local cat = Settings.RegisterVerticalLayoutSubcategory(parent, L.SEC_BOOKS .. " (2)")
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

-- Appele une fois les anciennes pages creees (DWE.InitOptionsPanel).
function DWE.BuildNativeOptions(parent)
    if Native.built or not parent or not Supported() then return end
    Native.built = true
    pcall(BuildBooks, parent)
    pcall(BuildPlacement, parent)
end

DWE.NativeRefresh = function() Native.Refresh() end
