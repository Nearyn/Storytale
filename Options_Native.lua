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

-- Libelle de ligne sans les deux-points de l'ancienne page ("Touche Dialogue :" -> "Touche Dialogue").
local function Bare(text)
    return (tostring(text or ""):gsub("%s*[:：]%s*$", ""))
end
Native.Bare = Bare

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
    -- items : liste fixe, ou fonction relue a chaque ouverture de la liste (profils).
    local function Options()
        local c = Settings.CreateControlTextContainer()
        for _, it in ipairs(type(items) == "function" and items() or items) do c:Add(it[1], it[2]) end
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
    if ok and init then pcall(layout.AddInitializer, layout, init) return init end
end
-- Nouveau texte d'un bouton (repris par la ligne a son prochain affichage).
function Native.SetButtonText(init, text)
    if type(init) == "table" and type(init.data) == "table" then init.data.buttonText = text end
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

---------------------------------------------------------------------------- Touches et manette
local function BuildKeys(parent)
    local L = DWE.L
    local cat, layout = Settings.RegisterVerticalLayoutSubcategory(parent, L.CAT_KEYS .. " (2)")
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
    local cat, layout = Settings.RegisterVerticalLayoutSubcategory(parent, L.SEC_SPOKEN .. " (2)")
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
    local cat, layout = Settings.RegisterVerticalLayoutSubcategory(parent, L.SEC_PROFILES .. " (2)")
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

-- Appele une fois les anciennes pages creees (DWE.InitOptionsPanel).
function DWE.BuildNativeOptions(parent)
    if Native.built or not parent or not Supported() then return end
    Native.built = true
    pcall(BuildBooks, parent)
    pcall(BuildPlacement, parent)
    pcall(BuildKeys, parent)
    pcall(BuildSpoken, parent)
    pcall(BuildProfiles, parent)
end

DWE.NativeRefresh = function() Native.Refresh() end
