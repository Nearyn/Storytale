-- Options en lignes natives du jeu (comme les options de Blizzard) : navigation a la manette
-- fiable, recherche du jeu, bouton "Par defaut" de chaque page.
-- Chaque reglage lit et ecrit les memes variables que les anciennes pages : les deux restent
-- d'accord tant que les anciennes pages existent (refonte page par page).
local DWE = DWE
if not DWE then return end

local Native = {}
DWE.Native = Native
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
    if s then pcall(Settings.CreateCheckbox, cat, s, tip) end
    return s
end

function Native.Choice(cat, id, label, tip, default, items, get, set)
    local s = Proxy(cat, id, type(""), label, default, get, set)
    if not s then return end
    local function Options()
        local c = Settings.CreateControlTextContainer()
        for _, it in ipairs(items) do c:Add(it[1], it[2]) end
        return c:GetData()
    end
    pcall(Settings.CreateDropdown, cat, s, Options, tip)
    return s
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

-- Appele une fois les anciennes pages creees (DWE.InitOptionsPanel).
function DWE.BuildNativeOptions(parent)
    if Native.built or not parent or not Supported() then return end
    Native.built = true
    pcall(BuildPlacement, parent)
end

DWE.NativeRefresh = function() Native.Refresh() end
