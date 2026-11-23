-- Usage: texlua run.lua <locale> <dui:0|1> <spoken:0|1> <addonDir>
local here = (arg and arg[0] or ""):match("^(.*)[/\\]") or "."
package.path = here .. "/?.lua;" .. package.path
local locale, withDUI, withSpoken, dir = arg[1], arg[2] == "1", arg[3] == "1", arg[4]
local M = require("wow_mock")
M.Install(locale)
-- Scene de modele factice : hauteur du PNJ = M.npcHeight (2 = humain)
M.npcHeight = 5.5
do
    local realCreate = CreateFrame
    CreateFrame = function(kind, ...)
        local fr = realCreate(kind, ...)
        if kind == "ModelScene" then
            fr.CreateActor = function()
                return {
                    SetModelByUnit = function() end,
                    GetMaxBoundingBox = function() return -0.5, -0.5, 0, 0.5, 0.5, M.npcHeight end,
                }
            end
        end
        return fr
    end
end
local withGlobals = os.getenv("GLOBALS") == "1"
if withGlobals then
    ACCEPT, CONTINUE, GOODBYE, INCOMPLETE, REWARDS, QUEST_OBJECTIVES = "G_Accept", "G_Continue", "G_Goodbye", "G_Incomplete", "G_Rewards", "G_Objectives"
    TURN_IN_ITEMS, REWARD_CHOOSE, RETRIEVING_ITEM_INFO, HEADER_COLON = "G_Required:", "G_Choose:", "G_Retrieving", " :"
else
    COMPLETE_QUEST, REPUTATION = nil, nil
end
local checks, failed = 0, 0
local function check(cond, msg)
    checks = checks + 1
    if not cond then failed = failed + 1; print("  FAIL: " .. msg) end
end

-- Fake DialogueUI ----------------------------------------------------------
local duiListener, duiVignette, spokenPortraitWatcher
if withDUI then
    _G.C_AddOns = { IsAddOnLoaded = function(n) return n == "DialogueUI" end }
    _G.DialogueUI_DB = { HideUI = true, BookUIEnabled = true, BookDarkenScreen = true }
    duiListener = CreateFrame("Frame")
    function duiListener:ListenEvents(state)
        for _, e in ipairs({ "GOSSIP_SHOW", "GOSSIP_CLOSED", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_GREETING", "QUEST_FINISHED" }) do
            if state then self:RegisterEvent(e) else self:UnregisterEvent(e) end
        end
    end
    duiListener.ThrottleGossipEvent = function() end
    duiListener.NegateLastEvent = function() end
    duiListener:RegisterEvent("PLAYER_ENTERING_WORLD")
    duiListener:ListenEvents(true)
    duiVignette = CreateFrame("Frame")
    duiVignette.owners = {}
    duiVignette.TryShow = function(s) s:Show() end
    duiVignette.AddOwner = function() end
    duiVignette:Hide()
    local book = CreateFrame("Frame", "DUIBookFrame", UIParent)
    book:Hide()
else
    _G.C_AddOns = { IsAddOnLoaded = function() return false end }
end

OFF = -1 -- (1.5.5) plus de choix "Spoken" en tete de roue : un bouton dans son coin
-- Fake Spoken ---------------------------------------------------------------
local skin
if withSpoken then
    spokenPortraitWatcher = CreateFrame("Frame")
    for _, e in ipairs({ "PLAYER_TARGET_CHANGED", "GOSSIP_SHOW", "QUEST_DETAIL" }) do spokenPortraitWatcher:RegisterEvent(e) end
    _G.SpokenEnv = {}
    -- File de lecture minimale (bouton "Spoken" de la roue, priorites de lecture).
    SpokenEnv.SoundQueue = { sounds = {}, Add = function() end, IsPlaying = function() return false end,
        GetCurrentSound = function() return nil end, GetHeldReason = function() return nil end }
    SpokenEnv.Spoken = { AddGate = function() end, RegisterCallback = function() end,
        IsPaused = function() return false end, Pause = function() end, Resume = function() end }
    local theme = { ThemeID = function() return 1 end }
    SpokenEnv.DialogueUITheme = theme
    skin = { art = { LOOKS = { quest = { top = { 0, 256 }, paperTop = 122 }, paper = { file = "x", book = true } } } }
    SpokenEnv.DialogueUIPlayer = skin
    function skin:Initialize()
        if self.frame then return end
        self.frame = CreateFrame("Frame", "SpokenDialogueUIPlayerFrame", UIParent)
        self.content = CreateFrame("Frame", nil, self.frame)
        self.parchments = { self.frame:CreateTexture(), self.frame:CreateTexture(), self.frame:CreateTexture() }
        self.head = { anchor = CreateFrame("Frame", nil, self.content), socket = self.content:CreateTexture(), divider = self.content:CreateTexture() }
    end
    function skin:Look() return self.art.LOOKS.paper end
    function skin:Layout() self.look = self:Look(); self.themeSeen = theme:ThemeID() end
    function skin:RefreshConfig() self:Initialize(); self:Layout() end
    function skin:ShadowUnder(reach, alpha)
        if not self.shadow then self.shadow = CreateFrame("Frame", nil, UIParent) end
        self.shadow:Show(); self.shadow:SetAlpha(alpha)
    end
    function skin:TuckFrames() if not self.card then self.card = CreateFrame("Frame", nil, UIParent); self.ripple = CreateFrame("Frame", nil, UIParent) end return self.card end
    function skin:Buffer() self.buffered = true end
    function skin:Unbuffer() self.buffered = nil end
    skin:Initialize()
end

M.addonDir = dir
UISpecialFrames = {}
if os.getenv("NINESLICE") == "1" then
    NineSliceLayouts = { ChatBubble = {} }
    NineSliceUtil = { ApplyLayoutByName = function(frame, name) assert(NineSliceLayouts[name]); frame._nineslice = name end }
    C_Texture = { GetAtlasInfo = function(n) return n == "ChatBubble-Tail" and {} or nil end }
end
SlashCmdList = {}
local chat = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) table.insert(chat, m) end }
-- Load the addon ------------------------------------------------------------
for _, file in ipairs({ "Locales.lua", "Storytale_Core.lua", "Bubble.lua", "SpokenFocus.lua", "SpokenQueueUI.lua", "Storytale.lua", "MinimapButton.lua" }) do
    local chunk, err = loadfile(dir .. "/" .. file)
    check(chunk ~= nil, "compile " .. file .. ": " .. tostring(err))
    local ok, rerr = pcall(chunk, "Storytale", {})
    check(ok, "load " .. file .. ": " .. tostring(rerr))
end
DWE.NO_PLATE_CVARS = false -- les tests du masquage des plaques gardent l'ancien chemin
-- Reglages sauvegardes : ligne SavedVariables du .toc lue en entier par le jeu (1023 caracteres
-- au plus), et les autres reglages rendus par DialogueWheelE_Extra.
do
    local toc = io.open(dir .. "/Storytale.toc", "r")
    local listed = {}
    for line in toc:lines() do
        line = line:gsub("\r$", "")
        check(#line <= 1023, "toc line fits the game's 1023-character limit (" .. #line .. ")")
        local sv = line:match("^## SavedVariables:%s*(.*)$")
        if sv then for n in sv:gmatch("DialogueWheelE_(%w+)") do listed[n] = true end end
    end
    toc:close()
    check(listed.Extra, "toc: DialogueWheelE_Extra saved")
    for _, k in ipairs(DWE.EXTRA_VARS) do check(not listed[k], "toc: " .. k .. " travels in Extra only") end
    local inExtra = {}
    for _, k in ipairs(DWE.EXTRA_VARS) do inExtra[k] = true end
    for _, k in ipairs(DWE.OPTION_VARS) do check(listed[k] or inExtra[k], "option " .. k .. " is saved") end
end
DialogueWheelE_Extra = { CustomPresets = { { name = "Saved" } }, GamePad = true }
M.FireEvent("ADDON_LOADED", "Storytale")
check(type(DialogueWheelE_CustomPresets) == "table" and DialogueWheelE_CustomPresets[1].name == "Saved" and DialogueWheelE_GamePad == true, "Extra: settings restored at load")
DialogueWheelE_CustomColors = { bg = { 0.1, 0.2, 0.3 } }
M.FireEvent("PLAYER_LOGOUT")
check(DialogueWheelE_Extra.CustomColors and DialogueWheelE_Extra.CustomColors.bg[3] == 0.3 and DialogueWheelE_Extra.CustomPresets[1].name == "Saved", "Extra: settings stored at logout")
DialogueWheelE_CustomColors, DialogueWheelE_CustomPresets, DialogueWheelE_GamePad, DialogueWheelE_Extra = nil, nil, nil, nil
M.FireEvent("PLAYER_LOGIN")
check(DialogueWheelE_Theme == "bubble" and DialogueWheelE_ShowText == true, "fresh install: Azeroth bubble theme, text shown")
-- (1.6.8) Sans Spoken : un message unique dans le chat le fait connaitre ; avec Spoken, rien.
if withSpoken then
    check(DialogueWheelE_SpokenTipSeen == nil, "Spoken tip: not shown when Spoken is installed")
else
    check(DialogueWheelE_SpokenTipSeen == true, "Spoken tip: shown once without Spoken")
    local before = #chat
    check(type(DWE.spokenTipSay) == "function", "Spoken tip: queued")
    if DWE.spokenTipSay then DWE.spokenTipSay() end
    check(#chat == before + 1 and chat[#chat]:find("Spoken", 1, true), "Spoken tip: line printed in the chat")
end
check(type(DWE.L.SPOKEN_TIP) == "string" and DWE.L.SPOKEN_TIP:find("Spoken", 1, true), "Spoken tip text exists")
-- la suite des tests part de l'ancien reglage (popup cache, theme sans cadre)
DialogueWheelE_Theme, DialogueWheelE_ShowText = "transparent", nil
DWE.OnThemeChanged()
if withGlobals then
    check(DWE.L.ACCEPT == "G_Accept" and DWE.L.REWARDS == "G_Rewards : " and DWE.L.GOODBYE == "G_Goodbye", "game strings used first")
else
    check(type(DWE.L.ACCEPT) == "string" and DWE.L.ACCEPT ~= "" and type(DWE.L.COMPLETE) == "string", "fallback strings present")
end
for _, k in ipairs({ "ACCEPT","CONTINUE","INCOMPLETE","COMPLETE","CHOOSE_HDR","REQ_ITEMS","GOODBYE","OBJ","REWARDS","TEXT_BTN","NO_TEXT","NEXT_PAGE","PREV_PAGE","LOADING","OPT_SUB","THEME_TRANS","THEME_DARK","THEME_PARCH","THEME_PARCH_DARK","THEME_DUI_BROWN","THEME_DUI_DARK","FONT_FAMILY","FONT_DEFAULT","FONT_LOCKED","FONT_SIZE","SCALE_LBL","OPACITY_LBL","KEY_USE_BLIZZ","KEY_CUSTOM","KEY_TOGGLE","KEY_PRESS","KEY_NONE","KEY_BLIZZ_TAG","WHEEL_SCROLL","SPOKEN_THEME","DM_FACTION","DM_TICKET","REPUTATION" }) do
    check(type(DWE.L[k]) == "string" and DWE.L[k] ~= "", "string " .. k .. " exists")
end
check(DWE.optionsPanel ~= nil, "options panel created")
check(DWE.optionPages and #DWE.optionPages == 6, "options split into 6 categories (" .. tostring(DWE.optionPages and #DWE.optionPages) .. ")")
do
    local names = {}
    for k = 2, #(DWE.optionPages or {}) do names[#names + 1] = DWE.optionPages[k].panel.name end
    check(names[1] == DWE.L.SEC_BOOKS and names[3] == DWE.L.CAT_KEYS and names[5] == DWE.L.SEC_PROFILES, "category names: " .. table.concat(names, ", "))
    local found = false
    for _, c in ipairs({ DWE.optionPages[6].content:GetChildren() }) do if c.GetText and c:GetText() == DWE.L.PROFILE_NEW_BTN then found = true end end
    check(found, "profiles controls live on the Profiles page")
end
do -- recherche dans les options
    check(DWE.OptionsSearch and DWE.OptionsSearch(DWE.L.SEC_PAD) > 0, "options search finds a section")
    check(DWE.OptionsSearch("zzqqxx") == 0, "options search: no match")
    check(DWE.OptionsSearch("") == 0, "options search: empty clears")
    local n = DWE.OptionsSearch(DWE.L.SEC_PAD)
    local _, second = DWE.OptionsSearch(DWE.L.SEC_PAD, true)
    check(n == 1 and second == 1 or second == 2, "options search: Enter goes to the next match")
end

if withDUI then
    check(not duiListener._events.GOSSIP_SHOW, "DialogueUI quest listener silenced")
    check(duiListener._events.PLAYER_ENTERING_WORLD, "DialogueUI other events untouched")
    check(DialogueUI_DB.BookUIEnabled == true, "BookUIEnabled not modified")
    check(DialogueUI_DB.BookDarkenScreen == true, "BookDarkenScreen not modified")
    duiListener:ListenEvents(true) -- zone change re-enable
    check(not duiListener._events.GOSSIP_SHOW, "DialogueUI stays silenced after re-enable")
end
if withSpoken then
    check(spokenPortraitWatcher._events.GOSSIP_SHOW and spokenPortraitWatcher._events.PLAYER_TARGET_CHANGED, "Spoken portrait watcher untouched")
end

-- Gossip ----------------------------------------------------------------------
M.gossipText = "  Even within cold, stone walls...  "
M.availQuests = { { questID = 11, title = "Q avail", frequency = 0 } }
M.activeQuests = { { questID = 12, title = "Q active", isComplete = true } }
M.gossipOptions = { { gossipOptionID = 99, name = "Train me", icon = 132058 } }
M.FireEvent("GOSSIP_SHOW")
M.RunTimers()
check(DWE.choiceBox:IsShown(), "wheel shown on gossip")
check(#DWE.currentOptions == 5 + OFF, "gossip options count (got " .. #DWE.currentOptions .. ")")
check(DWE.textBody:GetText() == "Even within cold, stone walls...", "gossip text trimmed")
check(M.bindings.E == "DWE_SelectBtn", "interact key bound")
check(M.bindings.T == nil, "no toggle key by default")
check(M.bindings.MOUSEWHEELUP == "DWE_WheelUpBtn", "wheel bound")
check(M.bindings.PAD1 == nil and M.bindings.PADDUP == nil, "no gamepad keys without gamepad mode")
do -- manette : croix, A et B pris seulement si le mode manette est actif
    local oldKey = _G.GetBindingKey
    _G.GetBindingKey = function(a) if a == "INTERACTTARGET" then return "E", "PADRSHOULDER" end end
    M.cvars.GamePadEnable = "1"
    DWE.RefreshBindings()
    check(M.bindings.PADDUP == "DWE_PadUpBtn" and M.bindings.PADDDOWN == "DWE_PadDownBtn", "gamepad d-pad moves the selection")
    check(M.bindings.PAD1 == "DWE_SelectBtn" and M.bindings.PAD2 == "DWE_PadCloseBtn", "gamepad A selects, B closes")
    check(M.bindings.PADDLEFT == nil and M.bindings.PADDRIGHT == nil, "conversation: left/right stay with the game")
    DWE.bookMode = true; DWE.RefreshBindings()
    check(M.bindings.PADDLEFT == "DWE_PadPrevBtn" and M.bindings.PADDRIGHT == "DWE_PadNextBtn", "book: left/right turn pages")
    DWE.bookMode = false; DWE.RefreshBindings()
    check(M.bindings.E == "DWE_SelectBtn" and M.bindings.PADRSHOULDER == "DWE_SelectBtn", "every interact key is bound")
    do -- camera libre forcee tant que le catcher est la
        local look = false
        _G.IsGamePadFreelookEnabled = function() return look end
        _G.SetGamePadFreeLook = function(v) look = v end
        DWE.padCatcher._scripts.OnUpdate(DWE.padCatcher, 0.2)
        check(look == true, "right stick keeps the camera while a book or conversation is open")
        local stick = true
        local prevBook = rawget(_G, "DUIBookFrame")
        local duiBook = CreateFrame("Frame", "DUIBookFrame", UIParent)
        duiBook.IsGamePadStickEnabled = function() return stick end
        duiBook.EnableGamePadStick = function(_, v) stick = v end
        duiBook:Show()
        local realBBA = DWE.BookByAddon
        DWE.BookByAddon = function() return false end
        DWE.padCatcher._scripts.OnUpdate(DWE.padCatcher, 0.2)
        check(stick == false, "DialogueUI's own book: right stick goes to the camera (text scrolls with the d-pad)")
        DWE.BookByAddon = function() return true end
        DWE.padCatcher._scripts.OnUpdate(DWE.padCatcher, 0.2)
        check(stick == false, "DialogueUI's hidden book gives the right stick back")
        DWE.BookByAddon = realBBA
        duiBook:Hide(); _G.DUIBookFrame = prevBook
        _G.IsGamePadFreelookEnabled, _G.SetGamePadFreeLook = nil, nil
        DWE.padCatcher._scripts.OnUpdate(DWE.padCatcher, 0.2) -- API absente : sans erreur
    end
    DialogueWheelE_PadTips = nil
    local tipShown0 = DWE.SpokenPlayerShown
    DWE.SpokenPlayerShown = function() return false end
    DWE.PadTipCheck()
    check(not DialogueWheelE_PadTipSeen, "gamepad tip: not shown while the keyboard and mouse are in use")
    DWE.padUsed, DWE.padUsedAt = true, GetTime and GetTime() or 0
    M.cvars.GamePadEnable = "0"; DWE.PadTipCheck()
    check(not DialogueWheelE_PadTipSeen, "gamepad tip: never with the game's gamepad mode off")
    M.cvars.GamePadEnable = "1"
    DWE.PadTipCheck()
    check(DialogueWheelE_PadTipSeen == true and DWE.padTip and DWE.padTip:IsShown(), "gamepad tip shown the first time")
    check(DWE.padTip.text:GetText() == DWE.L.PAD_TIP, "gamepad tip text")
    DWE.padTip._scripts.OnUpdate(DWE.padTip, 13)
    check(not DWE.padTip:IsShown(), "gamepad tip fades away")
    DWE.PadTipCheck()
    check(not DWE.padTip:IsShown(), "gamepad tip shown only once")
    do -- astuces du livre et du lecteur Spoken
        DWE.bookMode = true; DWE.PadTipCheck()
        check(DWE.padTip:IsShown() and DWE.padTip.text:GetText() == DWE.L.PAD_TIP_BOOK, "gamepad tip for books")
        DWE.padTip._scripts.OnUpdate(DWE.padTip, 13); DWE.bookMode = nil
        DWE.SpokenPlayerShown = function() return true end
        DWE.PadTipCheck()
        check(DWE.padTip:IsShown() and DWE.padTip.text:GetText() == DWE.L.PAD_TIP_SPOKEN, "gamepad tip for Spoken's player")
        DWE.padTip._scripts.OnUpdate(DWE.padTip, 13)
        DWE.PadTipCheck()
        check(not DWE.padTip:IsShown(), "each gamepad tip only once")
        DWE.SpokenPlayerShown = tipShown0
    end
    DialogueWheelE_GamePad = false
    DWE.RefreshBindings()
    check(M.bindings.PAD1 == nil and M.bindings.PADDUP == nil, "gamepad option off releases the pad buttons")
    DialogueWheelE_GamePad = nil
    DWE.RefreshBindings()
    _G.DWE_PadPrevBtn._scripts.OnClick(); _G.DWE_PadNextBtn._scripts.OnClick()
    local h = DWE.padCatcher._scripts and DWE.padCatcher._scripts.OnGamePadButtonDown
    if h then
        check(DWE.padCatcher:IsShown(), "gamepad catcher shown during a conversation")
        local before = DWE.selectedIndex
        h(DWE.padCatcher, "PADDDOWN")
        check(DWE.selectedIndex ~= before, "catcher: d-pad down moves the selection")
        h(DWE.padCatcher, "PADLSTICKUP") -- not ours: passes through, no error
        do -- Share pendant une conversation : le lecteur Spoken garde ses boutons
            local sent = {}
            _G.SlashCmdList = _G.SlashCmdList or {}
            local oldS = SlashCmdList.SPOKEN
            SlashCmdList.SPOKEN = function(m) sent[#sent + 1] = m end
            local realShown = DWE.SpokenPlayerShown
            DWE.SpokenPlayerShown = function() return true end
            h(DWE.padCatcher, "PADSOCIAL")
            DWE.padCatcher._scripts.OnGamePadButtonUp(DWE.padCatcher, "PADSOCIAL")
            check(sent[1] == "play" and DWE.choiceBox:IsShown(), "Share pauses Spoken during a conversation")
            DWE.SpokenPlayerShown = realShown
            SlashCmdList.SPOKEN = oldS
        end
        -- Y en conversation : laisse au jeu, meme avec le lecteur Spoken a l'ecran.
        local realShown = DWE.SpokenPlayerShown
        DWE.SpokenPlayerShown = function() return true end
        -- (1.5.5) sauf si le bouton de bascule bulle / Spoken est la : Y le presse.
        local tgl = DWE.spokenToggle
        local tglShown = tgl and tgl:IsShown()
        if tgl then tgl:Hide() end
        check(not DWE.PadMenuAvailable(), "Y is left to the game in a conversation (no toggle button)")
        if tgl then
            tgl:Show()
            local before = DialogueWheelE_ShowText == true
            check(DWE.PadMenuAvailable() and DWE.PadMenuButton(), "Y presses the bubble / Spoken toggle in a conversation")
            check((DialogueWheelE_ShowText == true) ~= before, "Y switched between the bubble and Spoken's player")
            DWE.ToggleDialogueText()
            tgl:SetShown(tglShown and true or false)
        end
        h(DWE.padCatcher, "PAD4")
        check(DWE.choiceBox:IsShown(), "Y in a conversation does not close it")
        DWE.SpokenPlayerShown = realShown
        -- Share / Vue hors dialogue : court = pause, long = passer (seulement lecteur affiche)
        do
            local sent = {}
            local oldS = SlashCmdList.SPOKEN
            SlashCmdList.SPOKEN = function(m) sent[#sent + 1] = m end
            M.cvars.GamePadEnable = "1"
            DWE.SpokenPlayerShown = function() return true end
            DWE.padPlayerWatch._scripts.OnUpdate(DWE.padPlayerWatch, 1)
            check(M.bindings.PADSOCIAL == "DWE_PadShare" and M.bindings.PADBACK == "DWE_PadShare",
                "share button bound while Spoken's player is on screen")
            local function press(name, down) local b = _G[name]; b._scripts.OnClick(b, "LeftButton", down) end
            local oldT, t0 = GetTime, 50
            GetTime = function() return t0 end
            press("DWE_PadShare", true); press("DWE_PadShare", false)
            press("DWE_PadShare", true); t0 = t0 + 1; press("DWE_PadShare", false)
            check(table.concat(sent, ",") == "play,skip", "share: tap pauses, hold skips (" .. table.concat(sent, ",") .. ")")
            local function mine(k) return M.bindOwner[k] == DWE.padPlayer end
            check(not mine("PAD1") and not mine("PAD4") and not mine("PADDUP"), "share: no other button taken")
            -- Share maintenu + Y : liste ; la croix, A, Y, B la pilotent, puis sont rendus.
            local ui, log, open = DWE.SpokenQueueUI, {}, false
            local saved = { ui.PadIsOpen, ui.PadOpen, ui.PadMove, ui.PadPlay, ui.PadRemove, ui.PadClose }
            ui.PadIsOpen = function() return open end
            ui.PadOpen = function() open = true; log[#log + 1] = "open" end
            ui.PadMove = function(d) log[#log + 1] = "move" .. d end
            ui.PadPlay = function() log[#log + 1] = "play" end
            ui.PadRemove = function() log[#log + 1] = "remove" end
            ui.PadClose = function() open = false; log[#log + 1] = "close" end
            sent = {}
            local pl = DWE.padList._scripts.OnGamePadButtonDown
            check(not DWE.padList:IsShown(), "no button capture while share is not held")
            press("DWE_PadShare", true)
            check(DWE.padList:IsShown(), "share held: Y listened to")
            pl(DWE.padList, "PAD4"); press("DWE_PadShare", false)
            check(DWE.padList:IsShown(), "list open: d-pad, A, Y, B listened to")
            pl(DWE.padList, "PADDDOWN"); pl(DWE.padList, "PAD1"); pl(DWE.padList, "PAD4")
            press("DWE_PadShare", true); press("DWE_PadShare", false)
            check(table.concat(log, ",") == "open,move1,play,remove,close" and #sent == 0,
                "queue list with the gamepad: " .. table.concat(log, ",") .. " / sent " .. #sent)
            check(not DWE.padList:IsShown(), "list closed: buttons back to the game")
            ui.PadIsOpen, ui.PadOpen, ui.PadMove, ui.PadPlay, ui.PadRemove, ui.PadClose = unpack(saved)
            GetTime = oldT
            DWE.SpokenPlayerShown = function() return false end
            DWE.padPlayerWatch._scripts.OnUpdate(DWE.padPlayerWatch, 1)
            check(M.bindings.PADSOCIAL == nil and not DWE.padPlayer:IsShown(), "share button released when the player goes away")
            SlashCmdList.SPOKEN = oldS
        end
        DWE.SpokenPlayerShown = realShown
    end
    M.cvars.GamePadEnable = nil
    _G.GetBindingKey = oldKey
    DWE.RefreshBindings()
    check(M.bindings.PAD1 == nil and M.bindings.PADRSHOULDER == nil, "gamepad keys released when gamepad mode is off")
    check(not DWE.padCatcher:IsShown(), "gamepad catcher hidden when gamepad mode is off")
end
_G.DWE_WheelDownBtn._scripts.OnClick()
_G.DWE_SelectBtn._scripts.OnClick()
check(#M.log > 0, "select runs an action: " .. tostring(M.log[#M.log]))

-- Toggle popup on, frames hidden
DialogueWheelE_ShowText = false
DWE.ToggleDialogueText()
check(DialogueWheelE_ShowText == true and DWE.textBox:IsShown(), "popup shown after toggle")
if withSpoken then
    check(SpokenDialogueUIPlayerFrame:GetAlpha() == 0, "Spoken player hidden while popup active")
    skin:ShadowUnder(1, 0.5)
    check(skin.shadow:GetAlpha() == 0, "Spoken shadow forced invisible while popup active")
end

-- Themes on popup and Spoken
for _, th in ipairs({ "transparent", "dark", "parchment", "parchment_dark", "whisper", "velin", "arcane", "sylvan", "starry", "glass", "halo", "inkgold", "cinema" }) do
    DialogueWheelE_Theme = th
    DWE.ApplyTextTheme()
    if withSpoken then
        DialogueWheelE_SpokenTheme = true
        DWE.RefreshSpoken()
        check(skin.look and skin.look.top ~= nil, "Spoken uses quest look for theme " .. th)
        check(not skin.parchments[1]:IsShown(), "Spoken parchment hidden for theme " .. th)
    end
end
if withSpoken then
    DialogueWheelE_SpokenTheme = false
    DWE.RefreshSpoken()
    check(skin.parchments[1]:IsShown() and skin.look.file == "x", "Spoken restored when option off")
    check(skin.themeSeen == 1, "Spoken theme restored when option off")
end

-- Experimental themes: cinema bars + subtitle, theme font
DialogueWheelE_Theme = "cinema"
DWE.OnThemeChanged()
DWE.UpdateTextPanelVisuals()
check(DWE.textBox:IsShown(), "cinema: text shown")
check(DWE.cineBars:IsShown() and DWE.cineBars.want == true, "cinema: letterbox bars shown")
local p1 = DWE.textBox._points[#DWE.textBox._points]
check(p1 and p1[1] == "BOTTOM" and p1[3] == "BOTTOM", "cinema: subtitle at bottom of screen")
check(DWE.textBody:GetJustifyH() == "CENTER", "cinema: centered text")
if not (DWE.IS_CJK or DWE.IS_CYRILLIC) then check((DWE.textBody:GetFont() or ""):find("Baskerville") ~= nil, "cinema: serif font with default font") end
do -- l'interface s'efface pendant la cinematique et revient ensuite
    local bar = CreateFrame("Frame", "MainMenuBarTest", UIParent)
    bar:Show(); bar:SetAlpha(0.8)
    local tip = GameTooltip
    DWE.UpdateCinemaBars()
    for _ = 1, 40 do DWE.cineBars._scripts.OnUpdate(DWE.cineBars, 0.05) end
    check(bar:GetAlpha() < 0.01, "cinema: rest of the interface faded out")
    check(DWE.HiddenUI[DWE.choiceBox] == nil and DWE.HiddenUI[DWE.textBox] == nil and DWE.HiddenUI[DWE.bubble] == nil and DWE.HiddenUI[DWE.cineBars] == nil, "cinema: addon frames stay visible")
    check(not tip or tip:GetAlpha() > 0, "cinema: tooltips stay visible")
    DialogueWheelE_Theme = "transparent"; DWE.OnThemeChanged()
    for _ = 1, 40 do if DWE.cineBars._scripts.OnUpdate and DWE.cineBars:IsShown() then DWE.cineBars._scripts.OnUpdate(DWE.cineBars, 0.05) end end
    check(math.abs(bar:GetAlpha() - 0.8) < 0.001, "cinema: interface restored to its own opacity")
    check(next(DWE.HiddenUI) == nil, "cinema: nothing left to restore")
    M.inCombat = true
    DialogueWheelE_Theme = "cinema"; DWE.OnThemeChanged()
    for _ = 1, 40 do DWE.cineBars._scripts.OnUpdate(DWE.cineBars, 0.05) end
    check(bar:GetAlpha() > 0.7, "cinema: interface left alone in combat")
    M.inCombat = false
    -- Option "Cacher l'interface" avec un autre theme : meme fondu, sans bandes noires.
    DialogueWheelE_Theme = "whisper"; DWE.OnThemeChanged()
    for _ = 1, 40 do if DWE.cineBars:IsShown() then DWE.cineBars._scripts.OnUpdate(DWE.cineBars, 0.05) end end
    check(math.abs(bar:GetAlpha() - 0.8) < 0.001, "hide UI: interface visible while the option is off")
    DialogueWheelE_HideUI = true
    DWE.UpdateTextPanelVisuals()
    DWE.UpdateCinemaBars()
    for _ = 1, 40 do DWE.cineBars._scripts.OnUpdate(DWE.cineBars, 0.05) end
    check(bar:GetAlpha() < 0.01, "hide UI: interface faded out with another theme")
    local barsShown = false
    for _, r in ipairs({ DWE.cineBars:GetRegions() }) do if r:IsShown() then barsShown = true end end
    check(not barsShown, "hide UI: no letterbox bars outside the Cinematic theme")
    DialogueWheelE_HideUI = false
    DWE.UpdateCinemaBars()
    for _ = 1, 40 do if DWE.cineBars:IsShown() then DWE.cineBars._scripts.OnUpdate(DWE.cineBars, 0.05) end end
    check(math.abs(bar:GetAlpha() - 0.8) < 0.001, "hide UI: interface back when the option is turned off")
    DialogueWheelE_HideUI = true
    M.inCombat = true
    DWE.UpdateCinemaBars()
    for _ = 1, 40 do if DWE.cineBars:IsShown() then DWE.cineBars._scripts.OnUpdate(DWE.cineBars, 0.05) end end
    check(bar:GetAlpha() > 0.7, "hide UI: interface left alone in combat")
    M.inCombat = false
    DialogueWheelE_HideUI = nil
    DWE.UpdateCinemaBars()
    for _ = 1, 40 do if DWE.cineBars:IsShown() then DWE.cineBars._scripts.OnUpdate(DWE.cineBars, 0.05) end end
    DialogueWheelE_Theme = "cinema"; DWE.OnThemeChanged()
    bar:Hide()
end
DialogueWheelE_Font = "lora"; DWE.ApplyFont()
if not (DWE.IS_CJK or DWE.IS_CYRILLIC) then check((DWE.textBody:GetFont() or ""):find("Lora") ~= nil, "cinema: user font kept when chosen") end
DialogueWheelE_Font = nil
DialogueWheelE_Theme = "inkgold"
DWE.OnThemeChanged()
check(DWE.cineBars.want == false, "cinema bars released on other theme")
check(DWE.textBody:GetJustifyH() == "LEFT", "inkgold: left text")
if not (DWE.IS_CJK or DWE.IS_CYRILLIC) then check((DWE.textBody:GetFont() or ""):find("Baskerville") ~= nil, "inkgold: serif font") end
DialogueWheelE_Theme = "halo"
DWE.OnThemeChanged()
check(not (DWE.textBody:GetFont() or ""):find("Baskerville"), "halo: default font")
DialogueWheelE_Theme = "transparent"
DWE.OnThemeChanged()

-- Fonts (incl. missing file fallback)
for _, ff in ipairs(DWE.FONTS) do
    DialogueWheelE_Font = ff.id
    DWE.ApplyFont()
    check(DWE.textBody:GetFont() ~= nil, "font applied " .. ff.id)
end

-- Cote de la roue : a gauche, ancrage par la droite et encoches en miroir.
do
    local savedPos, savedSide = DialogueWheelE_Pos, DialogueWheelE_WheelSide
    DialogueWheelE_Pos, DialogueWheelE_WheelSide = nil, "left"
    DWE.RestorePosition()
    local pt = DWE.choiceBox:GetPoint(1)
    check(pt == "TOPRIGHT", "left wheel anchored by its right edge (got " .. tostring(pt) .. ")")
    local f = CreateFrame("Frame")
    DWE.SkinPill(f, "game", true, nil)
    check(f.dweTexPath and f.dweTexPath:sub(-1) == "R", "left wheel uses mirrored pill tails")
    DialogueWheelE_Pos, DialogueWheelE_WheelSide = savedPos, savedSide
    DWE.RestorePosition()
    local g = CreateFrame("Frame")
    DWE.SkinPill(g, "game", true, nil)
    check(g.dweTexPath and g.dweTexPath:sub(-1) ~= "R", "right wheel uses normal pill tails")
end

-- Options: rebind live
DialogueWheelE_ToggleKey = "Y"
DWE.RefreshBindings()
if DWE.SpokenFocus and DWE.SpokenFocus.Available() then
    check(M.bindings.Y == "DWE_ToggleTextKeyBtn" and M.bindings.T == nil, "toggle key rebinding applied live")
else
    check(M.bindings.Y == nil, "toggle key unbound without Spoken")
end
DialogueWheelE_ToggleKey = ""
DWE.RefreshBindings()
check(M.bindings.Y == nil, "toggle key can be disabled")
DialogueWheelE_ToggleKey = nil

-- Attach to NPC: friendly NPC plates off, plates restricted (no measuring), as on WoW Forever.
local plate = CreateFrame("Frame", nil, UIParent)
plate.namePlateUnitToken = "nameplate1"
plate.UnitFrame = CreateFrame("Frame", nil, plate)
plate._restricted = true
local enemy = CreateFrame("Frame", nil, UIParent)
enemy.namePlateUnitToken = "nameplate2"
enemy.UnitFrame = CreateFrame("Frame", nil, enemy)
enemy._restricted = true
DWE.choiceBox:Hide(); DWE.choiceBox:Show()
check(M.cvars.nameplateShowFriendlyNPCs == "1", "friendly NPC plates enabled during dialogue")
check(DWE.choiceBox:GetAlpha() == 0, "wheel hidden until plate found")
local follower
for _, fr in ipairs(M.frames) do if fr._scripts.OnUpdate and fr._scripts.OnEvent and not fr._name and fr ~= plate and fr ~= enemy and not rawget(fr, "UnitFrame") then follower = fr end end
check(follower ~= nil, "follower frame exists")
local errBefore = #M.errors
follower._scripts.OnUpdate(follower, 0.016)
check(DWE.choiceBox:GetAlpha() == 0 and not DWE.IsFollowingNPC(), "still waiting for plate")
M.plates = { plate, enemy }
M.FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate1")
check(plate.UnitFrame:GetAlpha() == 0, "plate masked on creation, before any frame is drawn")
check(enemy.UnitFrame:GetAlpha() == 1, "enemy plate untouched on creation")
for _ = 1, 5 do follower._scripts.OnUpdate(follower, 0.016) end
-- Drag while pinned: offset changes, frames stay pinned, no error.
DWE.choiceBox._pinned, DWE.textBox._pinned = true, true
local row1 = DWE.GetRow(1)
M.cursor = { 100, 100 }
row1._scripts.OnDragStart(row1)
M.cursor = { 130, 60 }
follower._scripts.OnUpdate(follower, 0.016)
row1._scripts.OnDragStop(row1)
-- Ecart lateral de la roue plafonne a 0.7 : 30 px a l'ecran = 30 / 0.7 en unites d'ecart.
local wx = 130 + 30 / 0.7
check(DialogueWheelE_NPCOffset and math.abs(DialogueWheelE_NPCOffset.wheelX - wx) < 0.01 and DialogueWheelE_NPCOffset.wheelY == -190, "wheel offset changed by drag")
local dp = DWE.choiceBox._points[#DWE.choiceBox._points]
check(dp and dp[2] == plate and math.abs(dp[4] - wx * 0.7) < 0.01 and dp[5] == -190, "wheel still pinned after drag")
M.cursor = { 0, 0 }
DWE.textBox._scripts.OnDragStart(DWE.textBox)
M.cursor = { -20, 10 }
follower._scripts.OnUpdate(follower, 0.016)
DWE.textBox._scripts.OnDragStop(DWE.textBox)
check(DialogueWheelE_NPCOffset.textX == -65 and DialogueWheelE_NPCOffset.textY == -60, "text offset changed by drag")
DWE.ResetNPCOffset()
check(DialogueWheelE_NPCOffset == nil, "offset reset")
DWE.choiceBox._pinned, DWE.textBox._pinned = nil, nil
local pt = DWE.choiceBox._points[#DWE.choiceBox._points]
check(pt and pt[2] == plate and pt[1] == "LEFT", "wheel pinned to the NPC plate")
local tp = DWE.textBox._points[#DWE.textBox._points]
check(tp and tp[2] == plate, "popup pinned to the NPC plate")
check(DWE.choiceBox:GetAlpha() == 1, "wheel revealed once pinned")
check(plate.UnitFrame:GetAlpha() == 0, "friendly plate masked")
check(enemy.UnitFrame:GetAlpha() == 1, "enemy plate untouched")
check(DWE.IsFollowingNPC(), "following NPC")
GetCameraZoom = function() return 2 end
follower._scripts.OnUpdate(follower, 0.016)
local zp = DWE.choiceBox._points[#DWE.choiceBox._points]
check(zp and zp[2] == plate and math.abs(zp[5] - (-300)) < 0.01, "zoomed in: wheel offset follows the zoom: " .. tostring(zp and zp[5]))
GetCameraZoom = nil
follower._scripts.OnUpdate(follower, 0.016)
-- Petit PNJ (gobelin) : interface plus petite, ecarts reduits
DWE.choiceBox:Hide(); M.RunTimers()
M.npcHeight = 2.75
DWE.choiceBox:Show()
for _ = 1, 3 do follower._scripts.OnUpdate(follower, 0.05) end
local sp = DWE.choiceBox._points[#DWE.choiceBox._points]
check(DWE.choiceBox:GetScale() == 1, "small NPC: wheel keeps normal size: " .. tostring(DWE.choiceBox:GetScale()))
check(sp and sp[2] == plate and math.abs(sp[4] * DWE.choiceBox:GetScale() - 71.5) < 0.5, "small NPC: wheel closer: " .. tostring(sp and sp[4]))
DWE.choiceBox:Hide(); M.RunTimers()
check(DWE.choiceBox:GetScale() == 1, "scale back to normal after the conversation")
M.npcHeight = 5.5
DWE.choiceBox:Show()
for _ = 1, 3 do follower._scripts.OnUpdate(follower, 0.05) end
check(DWE.choiceBox:GetScale() == 1, "human NPC: normal size")
DWE.UpdateVisuals(); DWE.ToggleDialogueText(); DWE.ToggleDialogueText()
pt = DWE.textBox._points[#DWE.textBox._points]
check(pt and pt[2] == plate, "popup stays pinned after refresh")
SlashCmdList.DIALOGUEWHEELE("npc")
check(#chat >= 4, "diagnostic printed")
-- plate disappears (NPC off screen): back to fixed place
M.plates = {}
follower._scripts.OnUpdate(follower, 0.2)
check(not DWE.IsFollowingNPC() and DWE.choiceBox._points[1] and DWE.choiceBox._points[1][2] ~= plate, "unpinned when plate lost")
M.plates = { plate }
follower._scripts.OnUpdate(follower, 0.2)
check(DWE.IsFollowingNPC(), "re-pinned when plate back")
-- Manette : l'unite "npc" disparait a l'ouverture de la quete ; on retrouve la plaque par GUID.
do
    local oE, oG = UnitExists, UnitGUID
    UnitGUID = function(u) if u == "npc" or u == "nameplate1" then return "Creature-0-1-2-3-4-5" end end
    follower._scripts.OnUpdate(follower, 0.2)
    DWE.choiceBox:Hide(); M.RunTimers()
    UnitExists = function() return false end
    DWE.choiceBox:Show()
    for _ = 1, 3 do follower._scripts.OnUpdate(follower, 0.2) end
    check(DWE.IsFollowingNPC(), "quest screen without npc unit: still pinned by GUID")
    UnitGUID = function() return "Creature-other" end
    follower._scripts.OnUpdate(follower, 0.2)
    local lp = DWE.choiceBox._points[#DWE.choiceBox._points]
    check(not DWE.IsFollowingNPC(), "other NPC plate not taken")
    UnitExists, UnitGUID = oE, oG
    follower._scripts.OnUpdate(follower, 0.2)
    check(DWE.IsFollowingNPC(), "re-pinned with npc unit back")
    -- Plaque d'interaction absente de la liste : trouvee directement pour l'unite "npc".
    local oF = C_NamePlate.GetNamePlateForUnit
    M.plates = {}
    C_NamePlate.GetNamePlateForUnit = function(u) if u == "npc" then return plate end end
    follower._scripts.OnUpdate(follower, 0.2)
    check(DWE.IsFollowingNPC(), "interact plate outside the list: still pinned")
    C_NamePlate.GetNamePlateForUnit = oF
    M.plates = { plate }
    follower._scripts.OnUpdate(follower, 0.2)
    -- Gossip puis quete (fermeture et reouverture immediates) : le suivi continue.
    DWE.choiceBox:Hide()
    DWE.choiceBox:Show()
    M.RunTimers()
    check(DWE.FollowerRunning() and M.cvars.nameplateShowFriendlyNPCs == "1", "gossip to quest: follow kept, plates never switched off")
    -- Manette : le jeu enleve la cible a la fermeture du gossip -> plaques proches gardees.
    follower._scripts.OnUpdate(follower, 0.2)
    if DWE.IsFollowingNPC() then
        M.cvars.nameplateShowAll, M.cvars.nameplateMaxDistance = "0", "41"
        local oUU = UnitIsUnit
        UnitIsUnit = function(a, b) if a == "target" then return false end return oUU(a, b) end
        follower._scripts.OnEvent(follower, "GOSSIP_CLOSED")
        UnitIsUnit = oUU
        check(M.cvars.nameplateShowAll == "1" and M.cvars.nameplateMaxDistance == "5", "gamepad: target cleared, near plates kept")
        -- PNJ voisin : sa plaque garde le nom, le reste est cache.
        local nb = CreateFrame("Frame", nil, UIParent)
        nb.namePlateUnitToken = "nameplate5"
        nb.UnitFrame = CreateFrame("Frame", nil, nb)
        nb.UnitFrame.name = nb.UnitFrame:CreateFontString()
        local bar = CreateFrame("StatusBar", nil, nb.UnitFrame)
        M.plates = { plate, nb }
        local oE2, oUU2, oCA, oUN = UnitExists, UnitIsUnit, UnitCanAttack, UnitName
        UnitName = function(u) if u == "nameplate5" then return "Tannok" end return oUN(u) end
        UnitExists = function() return true end
        UnitIsUnit = function(a, b) if a == "nameplate5" or b == "nameplate5" then return false end return oUU2(a, b) end
        UnitCanAttack = function() return false end
        follower._scripts.OnUpdate(follower, 0.2)
        check(nb.UnitFrame:GetAlpha() == 1 and nb.UnitFrame.name:GetAlpha() == 1 and bar:GetAlpha() == 0, "neighbour NPC plate: name kept, rest hidden")
        check(nb.UnitFrame.name:GetText() == "Tannok", "neighbour NPC name restyled (text set)")
        UnitExists, UnitIsUnit, UnitCanAttack, UnitName = oE2, oUU2, oCA, oUN
        DWE.choiceBox:Hide(); M.RunTimers()
        check(M.cvars.nameplateShowAll == "0" and M.cvars.nameplateMaxDistance == "41" and DWE.softSaved == nil, "near plates setting restored after the conversation")
        M.RunTimers()
        check(bar:GetAlpha() == 1, "neighbour plate parts given back after the conversation")
        M.plates = { plate }
        DWE.choiceBox:Show(); follower._scripts.OnUpdate(follower, 0.2)
        -- Souris : la cible reste -> rien n'est change.
        UnitIsUnit = function(a, b) if a == "target" then return true end return oUU(a, b) end
        follower._scripts.OnEvent(follower, "GOSSIP_CLOSED")
        UnitIsUnit = oUU
        check(M.cvars.nameplateShowAll == "0" and M.cvars.nameplateMaxDistance == "41", "mouse: target kept, plate settings untouched")
        M.cvars.nameplateShowAll, M.cvars.nameplateMaxDistance = nil, nil
    end
    -- "Toujours afficher les plaques" coupe (manette) : active pendant la conversation, puis remis.
    DWE.choiceBox:Hide(); M.RunTimers()
    M.cvars.nameplateShowAll = "0"
    M.cvars.nameplateMaxAlpha = "1"
    DWE.choiceBox:Show()
    check(M.cvars.nameplateMaxAlpha == "1", "player's plate opacity untouched (their plates stay visible)")
    check(M.cvars.nameplateShowAll == "0", "show-all plates left alone (only friendly NPC plates, like 1.7.0)")
    DWE.choiceBox:Hide(); M.RunTimers()
    check(M.cvars.nameplateShowAll == "0" and DialogueWheelE_PlateRestore == nil, "show-all plates restored after")
    M.RunTimers()
    check(M.cvars.nameplateMaxAlpha == "1", "plate opacity restored after")
    M.cvars.nameplateMaxAlpha = nil
    DialogueWheelE_PlateRestore = { all = "0" }
    M.cvars.nameplateShowAll = "1"
    DWE.RestoreLeftoverPlates()
    check(M.cvars.nameplateShowAll == "0" and DialogueWheelE_PlateRestore == nil, "leftover plate setting restored at login")
    M.cvars.nameplateShowAll = nil
    DWE.choiceBox:Show()
    for _ = 1, 3 do follower._scripts.OnUpdate(follower, 0.2) end
    -- Rien ne change a l'ecran : une plaque visible avant la conversation le reste.
    DWE.choiceBox:Hide(); M.RunTimers()
    local oG3 = UnitGUID
    UnitGUID = function(u) if u == "nameplate1" then return "Creature-seen" end end
    plate.UnitFrame:SetAlpha(1)
    DWE.choiceBox:Show()
    for _ = 1, 2 do follower._scripts.OnUpdate(follower, 0.2) end
    check(plate.UnitFrame:GetAlpha() == 1, "plate the player already saw stays visible in conversation")
    DWE.choiceBox:Hide(); M.RunTimers()
    plate.UnitFrame:SetAlpha(0)
    DWE.choiceBox:Show()
    plate.UnitFrame:SetAlpha(1)
    for _ = 1, 2 do follower._scripts.OnUpdate(follower, 0.2) end
    check(plate.UnitFrame:GetAlpha() == 0, "plate the player did not see stays hidden in conversation")
    UnitGUID = oG3
    -- Suivi arrete sans OnShow : relance au prochain ecran de conversation.
    DWE.StopFollow()
    DWE.EnsureFollow()
    check(DWE.FollowerRunning(), "follow restarted on next conversation screen")
end
DWE.choiceBox:Hide(); M.RunTimers()
check(M.cvars.nameplateShowFriendlyNPCs == "0", "player setting restored on close")
check(plate.UnitFrame:GetAlpha() == 0, "plate stays invisible while being removed")
M.RunTimers()
check(plate.UnitFrame:GetAlpha() == 1, "plate alpha restored after removal")
check(not DWE.IsFollowingNPC(), "not following after close")
check(DWE.choiceBox._points[1] and DWE.choiceBox._points[1][2] ~= plate, "wheel back to fixed place after close")
-- No plate at all: wheel still appears at its fixed place.
M.plates = {}
DWE.choiceBox:Show()
for _ = 1, 30 do follower._scripts.OnUpdate(follower, 0.016) end
check(DWE.choiceBox:GetAlpha() == 1, "wheel shown at fixed place when no plate")
DWE.choiceBox:Hide(); M.RunTimers()

-- Resize grips (free width/height, no zoom) ---------------------------------
local function GripOf(frame)
    for _, c in ipairs(frame._children) do if rawget(c, "dweIsGrip") then return c end end
end
local wg = GripOf(DWE.choiceBox)
check(wg ~= nil and GripOf(DWE.textBox) ~= nil and GripOf(DWE.bubble) ~= nil, "grips exist on wheel, popup and bubble")
local function dragGrip(g, dx, dy)
    M.cursor = { 0, 0 }
    g._scripts.OnMouseDown(g, "LeftButton")
    M.cursor = { dx, dy }
    if g._scripts.OnUpdate then g._scripts.OnUpdate(g, 0.016) end
    g._scripts.OnMouseUp(g, "LeftButton")
end
DWE.RestorePosition()
local w0 = DWE.choiceBox:GetWidth()
dragGrip(wg, 50, -30)
check(DialogueWheelE_WheelWidth == w0 + 50 and DWE.choiceBox:GetWidth() >= w0, "wheel width +50: " .. tostring(DialogueWheelE_WheelWidth) .. " box=" .. tostring(DWE.choiceBox:GetWidth()))
-- Agrandie a l'exces : la roue s'arrete peu apres le plus long choix (pas de grand vide).
dragGrip(wg, 600, 0)
check(DWE.choiceBox:GetWidth() <= math.max(200, (DWE.wheelNeed or 0) + DWE.WHEEL_SLACK) + 8, "wheel growth capped: " .. tostring(DWE.choiceBox:GetWidth()) .. " need=" .. tostring(DWE.wheelNeed))
dragGrip(wg, -600, 0)
check(DWE.choiceBox:GetScale() == 1, "wheel not zoomed")
DialogueWheelE_ShowText = true
DWE.UpdateVisuals()
local tg = GripOf(DWE.textBox)
local w0, h0 = DWE.textBox.dweW, DWE.textBox.dweH
local tgp = tg._points[#tg._points]
check(tgp and tgp[1] == "BOTTOMRIGHT", "popup grip is bottom-right")
local wgp = wg._points[#wg._points]
check(wgp and wgp[1] == "BOTTOMRIGHT", "wheel grip is bottom-right")
dragGrip(tg, 40, -20) -- right = wider, down = taller
check(DialogueWheelE_TextW == w0 + 40 and DialogueWheelE_TextH == nil, "popup max width set by grip, height follows text: " .. tostring(DialogueWheelE_TextW))
-- Frame fits its text: one short line = narrow, low frame
DWE.SetDialogueText("Falfindel", "How may I help you?")
check(DWE.textBox:GetWidth() < DialogueWheelE_TextW and DWE.textBox:GetHeight() <= 64, "short text: frame shrinks to it (" .. DWE.textBox:GetWidth() .. "x" .. DWE.textBox:GetHeight() .. ")")
DWE.SetDialogueText("Falfindel", string.rep("A long sentence about the war. ", 12))
check(DWE.textBox:GetWidth() == DialogueWheelE_TextW, "long text: frame at max width")
check(DWE.textBox:GetScale() == 1, "popup not zoomed")
local fpath, fsize = DWE.textBody:GetFont()
check(fsize == (tonumber(DialogueWheelE_FontSize) or 13), "font size unchanged by resizing")
DialogueWheelE_Locked = true
DWE.ApplyLock()
check(not wg:IsShown(), "grips hidden when locked")
local before = DialogueWheelE_WheelWidth
dragGrip(wg, 100, 0)
check(DialogueWheelE_WheelWidth == before, "no resize when locked")
DialogueWheelE_Locked = false
DWE.ApplyLock()
check(wg:IsShown(), "grips back when unlocked")
DWE.ResetNPCOffset()
check(DialogueWheelE_WheelWidth == nil and DialogueWheelE_TextW == nil, "reset clears sizes")

-- Speech bubble theme --------------------------------------------------------
DialogueWheelE_Theme = "bubble"
DialogueWheelE_ShowText = true
M.gossipText = "Hello there, traveler! " .. string.rep("This land is dangerous and the roads are long. ", 6) .. "Be careful."
M.FireEvent("GOSSIP_SHOW")
check(DWE.bubble:IsShown(), "bubble shown with bubble theme")
if os.getenv("NINESLICE") == "1" then
    check(DWE.bubble.art and DWE.bubble.art._nineslice == "ChatBubble", "bubble uses the game's ChatBubble layout")
end
check(not DWE.textBox:IsShown(), "popup hidden with bubble theme")
local bt
local function findFS(fr, depth)
    for _, r in ipairs(fr._regions) do if r._kind == "FontString" then return r end end
    if depth < 2 then for _, c in ipairs(fr._children) do local x = findFS(c, depth + 1) if x then return x end end end
end
bt = findFS(DWE.bubble, 0)
local function vis()
    local t = bt:GetText() or ""
    if bt._grad == nil then return t end
    local n, out, count = bt._grad, "", 0
    for ch in t:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        if count >= n then break end
        out = out .. ch; count = count + 1
    end
    return out
end
local function full() return bt:GetText() end
check(vis() == "H", "bubble starts with its first letter, then writes: '" .. vis() .. "'")
check(DWE.bubble.dweWaitHide == true, "bubble hidden one frame while the game lays out the fade (no full-text flash)")
DWE.bubble._scripts.OnUpdate(DWE.bubble, 0.001)
check(DWE.bubble.dweWaitHide == false, "bubble shown the next frame with its first letter")
local function tick(sec) for _ = 1, math.floor(sec / 0.05 + 0.5) do DWE.bubble._scripts.OnUpdate(DWE.bubble, 0.05) end end
tick(0.4)
check(DWE.bubble.dweWaitHide == false, "bubble shown with the first letters")
DWE.bubble:SetAlpha(0.5)
check(DWE.bubble:GetAlpha() == 0.5, "bubble opacity set elsewhere still applies")
DWE.bubble:SetAlpha(1)
check(vis() == "Hello there, ", "letter by letter at 30/s: '" .. vis() .. "'")
if os.getenv("NOGRADIENT") ~= "1" then
    check(full():find("^Hello there, traveler!"), "whole segment laid out in advance (no reflow)")
end
local fullSeen
for _ = 1, 100 do
    local prev = vis(); tick(0.3)
    if vis() == prev and #prev > 0 then fullSeen = prev break end
end
check(fullSeen and fullSeen:find("^Hello there, traveler!"), "segment fully written")
tick(1)
check(vis() == fullSeen, "segment stays while reading")
local nextStarted = false
for _ = 1, 400 do tick(0.05); if vis() ~= fullSeen then nextStarted = true break end end
check(nextStarted and vis():sub(1, #fullSeen) ~= fullSeen, "next segment starts writing")
DWE.bubble._scripts.OnMouseUp(DWE.bubble, "LeftButton")
local seg2 = full()
check(vis() == seg2, "click finishes the segment instantly")
DWE.bubble._scripts.OnMouseUp(DWE.bubble, "LeftButton")
check(full() ~= seg2, "click again goes to next segment")
for _ = 1, 40 do DWE.bubble._scripts.OnMouseUp(DWE.bubble, "LeftButton") end
check(vis():find("Be careful%.$"), "ends on last segment fully visible: " .. vis())
tick(30)
check(vis():find("Be careful%.$"), "stays on last segment")
-- Accented letters count as one letter
DWE.SetDialogueText("x", "Éléphant à côté.")
tick(0.15)
check(vis() == "Élé" or vis() == "Élép" or vis() == "Éléph", "UTF-8 letters revealed whole: '" .. vis() .. "'")
for _ = 1, 5 do DWE.bubble._scripts.OnMouseUp(DWE.bubble, "LeftButton") end
-- Spoken sync: the voice reads this text, writing follows it
local now = 1000
GetTime = function() return now end
local body = "One two three four five six seven eight nine ten. Eleven twelve thirteen fourteen fifteen."
local clip = { length = 10, spokenAt = now + 10, text = body, present = { transcript = body } }
local paused = false
Spoken = { GetNowPlaying = function() return clip end, IsPaused = function() return paused end }
DWE.SetDialogueText("x", body)
local function run(sec) for _ = 1, math.floor(sec / 0.05 + 0.5) do now = now + 0.05; tick(0.05) end end
tick(0.05)
check(#vis() <= 1, "voice at 0%: nothing written yet: '" .. vis() .. "'")
run(3)
local t30 = vis()
check(t30:find("^One two three") and not t30:find("ten"), "voice at 30%: text follows: '" .. t30 .. "'")
paused = true
run(0.5)
check(vis() == t30, "Spoken stopped: writing waits a moment")
run(2)
check(#vis() > #t30 or full() ~= body, "Spoken stopped for long: writing goes on alone (no freeze)")
paused = false
local last, smooth = #vis(), true
for _ = 1, 140 do now = now + 0.05; tick(0.05) end
check(vis():find("fifteen%.$"), "voice done: text complete: '" .. vis() .. "'")
clip = { length = 10, spokenAt = now + 5, text = "Something completely different here.", present = {} }
DWE.SetDialogueText("x", "Alpha beta gamma delta epsilon zeta eta theta.")
for _ = 1, 30 do now = now + 0.05; tick(0.05) end
check(vis():find("^Alpha beta"), "unrelated voice: own speed: '" .. vis() .. "'")
-- Voix qui demarre avec ce texte mais dont le texte differe (noms remplaces...) : suivie
local body2 = "Greetings Kora, the road to Ratchet is long and full of danger for travelers like you."
clip = { length = 10, spokenAt = now + 10, text = "Greetings <name>, the road is long.", present = {} }
DWE.SetDialogueText("x", body2)
for _ = 1, 100 do now = now + 0.05; tick(0.05) end
check(#vis() >= 34 and #vis() <= 52, "voice started with this text (wording differs): writing follows it: " .. #vis())

Spoken = nil
-- Fantasy bubble
DialogueWheelE_Theme = "bubble_fantasy"
DWE.UpdateVisuals()
local fan
for _, r in ipairs(DWE.bubble._regions) do if r._texture and tostring(r._texture):find("BubbleFantasy.png") then fan = r end end
check(fan and fan:IsShown(), "fantasy bubble texture shown")
DialogueWheelE_Theme = "bubble"
DWE.UpdateVisuals()
check(fan and not fan:IsShown(), "fantasy texture hidden on game bubble")
DWE.SetDialogueText("x", M.gossipText)
for _ = 1, 40 do DWE.bubble._scripts.OnMouseUp(DWE.bubble, "LeftButton") end
-- same text again (book reload): no restart
DWE.SetDialogueText("x", M.gossipText)
check(vis():find("Be careful%.$"), "same text does not restart")
-- pinned to NPC
local bplate = CreateFrame("Frame", nil, UIParent)
bplate.namePlateUnitToken = "nameplate1"; bplate.UnitFrame = CreateFrame("Frame", nil, bplate); bplate._restricted = true
M.plates = { bplate }
DWE.choiceBox:Hide(); DWE.choiceBox:Show()
local fol
for _, fr in ipairs(M.frames) do if fr._scripts.OnUpdate and not fr._name and not rawget(fr, "UnitFrame") and fr._events.NAME_PLATE_UNIT_ADDED ~= nil or (fr._scripts.OnUpdate and fr._scripts.OnEvent and not fr._name and fr ~= bplate) then fol = fol or fr end end
for _, fr in ipairs(M.frames) do if fr._scripts.OnUpdate and fr._scripts.OnEvent and not fr._name and fr._events.NAME_PLATE_UNIT_ADDED then fol = fr end end
check(fol ~= nil, "follower found for bubble test")
if fol then for _ = 1, 3 do fol._scripts.OnUpdate(fol, 0.016) end end
local bp = DWE.bubble._points[#DWE.bubble._points]
check(bp and bp[1] == "BOTTOM" and bp[2] == bplate, "bubble pinned above the NPC")
M.cursor = { 0, 0 }
DWE.bubble._scripts.OnDragStart(DWE.bubble)
M.cursor = { 10, 30 }
if fol then fol._scripts.OnUpdate(fol, 0.016) end
DWE.bubble._scripts.OnDragStop(DWE.bubble)
-- grips and reward tooltips while pinned (measurement forbidden)
local pinnedGrip
for _, c in ipairs(DWE.choiceBox._children) do if c._scripts.OnMouseDown and not c._scripts.OnClick then pinnedGrip = c end end
check(M.Restricted(DWE.choiceBox), "wheel is in a restricted chain while pinned")
local errs0 = #M.errors
pinnedGrip._scripts.OnEnter(pinnedGrip)
pinnedGrip._scripts.OnMouseDown(pinnedGrip, "LeftButton")
pinnedGrip._scripts.OnUpdate(pinnedGrip, 0.016)
pinnedGrip._scripts.OnMouseUp(pinnedGrip, "LeftButton")
pinnedGrip._scripts.OnLeave(pinnedGrip)
local rb = DWE.GetRewardButton(1)
rb._scripts.OnEnter(rb)
rb._scripts.OnLeave(rb)
check(#M.errors == errs0, "no error using grip / tooltips while pinned")
check(DialogueWheelE_NPCOffset and DialogueWheelE_NPCOffset.bubbleX == 10 and DialogueWheelE_NPCOffset.bubbleY == 25, "bubble offset dragged")
DWE.choiceBox:Hide(); M.RunTimers()
check(not DWE.bubble:IsShown(), "bubble hidden on close")
M.plates = {}
DialogueWheelE_NPCOffset = nil
M.FireEvent("GOSSIP_CLOSED")
DialogueWheelE_Theme = "dark"
M.RunTimers()

-- Close
M.FireEvent("GOSSIP_CLOSED")
check(not DWE.choiceBox:IsShown(), "wheel hidden on close")
check(next(M.bindings) == nil, "bindings cleared on close")
M.RunTimers()

-- Quest detail / complete
M.questTitle, M.questText, M.objText, M.questID = "Blueleaf Tubers", "Gain 250 reputation with Darkmoon.", "Collect 6 tubers", 7894
M.FireEvent("QUEST_DETAIL")
check(DWE.currentOptions[2 + OFF].rawLabel == DWE.L.ACCEPT, "accept option")
check(DWE.rewLine:GetText() ~= nil, "rewards line set")
check(not DialogueWheelESharerFrame:IsShown(), "no sharer banner for an NPC quest")
do -- quete partagee par un joueur
    local oE, oP, oU, oN, oC = UnitExists, UnitIsPlayer, UnitIsUnit, UnitName, UnitClass
    UnitExists = function(u) return u == "npc" or u == "questnpc" end
    UnitIsPlayer = function(u) return u == "questnpc" end
    UnitName = function(u) return u == "questnpc" and "Kora" or oN(u) end
    UnitClass = function(u) return "Paladin", "PALADIN" end
    RAID_CLASS_COLORS = { PALADIN = { r = 0.96, g = 0.55, b = 0.73 } }
    SetPortraitTexture = function(tex, unit) assert(unit == "questnpc") end
    M.FireEvent("QUEST_DETAIL")
    check(DialogueWheelESharerFrame:IsShown(), "sharer banner shown")
    check(DialogueWheelESharerFrame:GetWidth() >= 160, "sharer banner width")
    local found
    for _, r in ipairs({ DialogueWheelESharerFrame:GetRegions() }) do
        if r.GetText and r:GetText() == "Kora" then found = r end
    end
    check(found ~= nil, "sharer name shown")
    for _, th in ipairs({ "bubble", "bubble_fantasy", "whisper", "glass", "parchment", "dark" }) do
        DialogueWheelE_Theme, DialogueWheelE_WheelTheme = th, true
        DWE.OnThemeChanged()
        check(DialogueWheelESharerFrame:IsShown(), "sharer banner with theme " .. th)
    end
    DialogueWheelE_WheelTheme = nil
    -- Portrait impossible : icone de classe, sans erreur (texture masquee non recadrable)
    SetPortraitTexture = function() error("no portrait") end
    M.FireEvent("QUEST_DETAIL")
    check(DialogueWheelESharerFrame:IsShown(), "sharer banner with class icon fallback")
    SetPortraitTexture = nil
    CLASS_ICON_TCOORDS = { PALADIN = { 0, 0.25, 0, 0.25 } }
    M.FireEvent("QUEST_DETAIL")
    check(DialogueWheelESharerFrame:IsShown(), "sharer banner with class circle")
    UnitIsPlayer = function(u) return false end
    M.FireEvent("QUEST_DETAIL")
    check(not DialogueWheelESharerFrame:IsShown(), "banner gone for next NPC quest")
    UnitExists, UnitIsPlayer, UnitIsUnit, UnitName, UnitClass = oE, oP, oU, oN, oC
    DialogueWheelE_Theme = "dark"
    DWE.OnThemeChanged()
end
M.FireEvent("QUEST_FINISHED")
M.numChoices = 3
M.FireEvent("QUEST_COMPLETE")
check(DWE.currentOptions[2 + OFF].disabled == true, "complete disabled until reward picked")
DWE.selectedRewardIndex = 2
DWE.OnRewardSelected()
check(DWE.currentOptions[2 + OFF].disabled == false, "complete enabled after pick")
M.FireEvent("QUEST_FINISHED")
-- Pick a reward at the "Continue" step, remembered for the final screen
GetQuestLogIndexByID = function() return 3 end
SelectQuestLogEntry = function() end
GetQuestLogSelection = function() return 0 end
GetNumQuestLogChoices = function() return 3 end
GetQuestLogChoiceInfo = function(i) return "Choice " .. i, 134400, 1, 2 end
GetNumQuestLogRewards = function() return 0 end
M.questID = 555
-- Quete pas terminee : "vous pourrez choisir", pas de selection possible
local oldComp = IsQuestCompletable
IsQuestCompletable = function() return false end
M.FireEvent("QUEST_PROGRESS")
check(DWE.chooseHeader:GetText():find(DWE.L.CHOICES_HDR, 1, true), "incomplete quest: 'you will be able to choose' header: " .. tostring(DWE.chooseHeader:GetText()))
check(DWE.GetRewardButton(1).canChoose == false, "incomplete quest: rewards cannot be picked yet")
M.FireEvent("QUEST_FINISHED")
IsQuestCompletable = oldComp
M.FireEvent("QUEST_PROGRESS")
check(DWE.chooseHeader:GetText():find(DWE.L.CHOOSE_HDR, 1, true), "completed quest: 'choose your reward' header")
check(DWE.currentOptions[2 + OFF].rawLabel == DWE.L.COMPLETE and DWE.currentOptions[2 + OFF].disabled == true, "Complete greyed until a reward is picked")
local logChoice
for i = 1, 12 do local b = DWE.GetRewardButton(i) if b:IsShown() and b.canChoose and b.itemIndex == 3 then logChoice = b end end
check(logChoice ~= nil, "rewards selectable at Continue step")
logChoice._scripts.OnClick(logChoice, "LeftButton")
check(logChoice.selectedBorder:IsShown(), "selected reward framed at Continue step")
check(DWE.currentOptions[2 + OFF].disabled == false, "Complete enabled after pick")
-- "Terminer" : la quete est rendue et la recompense donnee sans deuxieme etape
M.log = {}
DWE.currentOptions[2 + OFF].action()
check(M.log[1] == "CompleteQuest", "Complete sends the quest")
M.FireEvent("QUEST_FINISHED")
M.numChoices = 3
M.FireEvent("QUEST_COMPLETE")
if DWE.SpokenFocus and DWE.SpokenFocus.Available and DWE.SpokenFocus.Available() then
    -- Avec Spoken : l'ecran final reste ouvert (la voix lit ce que dit le PNJ), recompense gardee.
    check(M.log[2] == nil and DWE.selectedRewardIndex == 3, "with Spoken: final screen stays open, picked reward kept")
    check(DWE.currentOptions[2 + OFF].rawLabel == DWE.L.COMPLETE and DWE.currentOptions[2 + OFF].disabled == false, "with Spoken: Complete ready on the final screen")
    DWE.currentOptions[2 + OFF].action()
    check(M.log[2] == "GetQuestReward 3", "with Spoken: Complete gives the picked reward: " .. tostring(M.log[2]))
else
    check(M.log[2] == "GetQuestReward 3", "final screen validated at once with the picked reward: " .. tostring(M.log[2]))
end
M.FireEvent("QUEST_FINISHED")
-- Sans passer par "Terminer" (ecran final ouvert autrement) : le choix est repris
M.FireEvent("QUEST_COMPLETE")
check(DWE.selectedRewardIndex == 3 and DWE.currentOptions[2 + OFF].disabled == false, "choice remembered on final screen")
local fb
for i = 1, 12 do local b = DWE.GetRewardButton(i) if b:IsShown() and b.canChoose and b.itemIndex == 3 then fb = b end end
check(fb and fb.selectedBorder:IsShown(), "remembered reward framed on final screen")
M.FireEvent("QUEST_FINISHED")
M.questID = 556
M.FireEvent("QUEST_COMPLETE")
check(DWE.currentOptions[2 + OFF].disabled == true, "other quest: no remembered choice, complete greyed")
-- Manette : croix gauche/droite parcourt les recompenses et choisit celle visee.
check(#DWE.PadRewardButtons() >= 3, "gamepad: reward buttons reachable (" .. #DWE.PadRewardButtons() .. ")")
check(DWE.PadRewardStep(1) == true, "d-pad right steps into the rewards")
local padB = DWE.padRewardBtn
check(padB and DWE.hoveredRewardBtn == padB, "d-pad: focused reward shows its details like a hover")
check(padB and padB.canChoose and DWE.selectedRewardIndex == nil, "d-pad: browsing does not pick a reward")
check(DWE.currentOptions[2 + OFF].disabled == true, "d-pad browsing leaves Complete greyed")
DWE.PadRewardStep(-1)
check(DWE.padRewardBtn ~= padB, "d-pad left moves to another reward")
DWE.PadRewardStep(1)
check(DWE.padRewardBtn == padB, "d-pad right comes back")
-- A sur la recompense visee : la choisit sans rendre la quete, la main revient a la roue.
local rewarded = 0
local oldGQR = _G.GetQuestReward
_G.GetQuestReward = function() rewarded = rewarded + 1 end
local h = DWE.padCatcher:GetScript("OnGamePadButtonDown")
h(DWE.padCatcher, "PAD1")
check(DWE.selectedRewardIndex == padB.itemIndex, "A on the focused reward picks it")
check(rewarded == 0, "A on a reward does not hand in the quest")
check(DWE.padRewardBtn == nil, "after picking, focus goes back to the wheel")
check(DWE.currentOptions[2 + OFF].disabled == false, "picking with A enables Complete")
_G.GetQuestReward = oldGQR
M.FireEvent("QUEST_FINISHED")
check(DWE.padRewardBtn == nil, "gamepad reward focus cleared when the quest closes")
-- Bouton de la mini-carte : affiche par defaut, cache par l'option.
do
    _G.Minimap = _G.Minimap or CreateFrame("Frame", "Minimap", UIParent)
    if not Minimap:GetWidth() or Minimap:GetWidth() == 0 then Minimap:SetSize(140, 140) end
    DialogueWheelE_MinimapHide = nil
    DWE.MinimapButtonRefresh()
    local b = _G.StorytaleMinimapButton
    check(b and b:IsShown(), "minimap button shown by default")
    DialogueWheelE_MinimapHide = true
    DWE.MinimapButtonRefresh()
    check(b and not b:IsShown(), "minimap button hidden by its option")
    DialogueWheelE_MinimapHide = nil
    DWE.MinimapButtonRefresh()
    check(type(DWE.OpenOptions) == "function", "minimap button opens the options")
end
-- Illustration de lieu au-dessus de la petite fenetre de Spoken.
do
    local mp = { frame = CreateFrame("Frame", nil, UIParent), panel = CreateFrame("Frame", nil, UIParent) }
    mp.panel:SetSize(300, 100)
    mp.clip = { present = { picture = { file = "Interface\\Pic\\Zone", mask = "Interface\\Pic\\Mask" } } }
    local saved = DialogueWheelE_ZoneArt
    DialogueWheelE_ZoneArt = nil
    DWE.SpokenZoneArt(mp)
    check(mp.dweZoneHolder and mp.dweZoneHolder:IsShown(), "zone art: shown by default for a place line")
    mp.dweThemeId = "dark"
    DWE.SpokenZoneArt(mp)
    check(mp.dweZoneHolder:IsShown() and (mp.dweArtExtra or 0) == 0, "zone art: window not dressed by Storytale, picture stays apart")
    mp.dweThemeId = nil
    DialogueWheelE_ZoneArt = false
    DWE.SpokenZoneArt(mp)
    check(not mp.dweZoneHolder:IsShown(), "zone art: option off hides it")
    DialogueWheelE_ZoneArt = nil
    mp.clip = { present = {} }
    DWE.SpokenZoneArt(mp)
    check(not mp.dweZoneHolder:IsShown(), "zone art: a line without picture hides it")
    mp.clip = { present = { picture = { file = "x" } } }
    mp.picture = mp.frame:CreateTexture()
    DWE.SpokenZoneArt(mp)
    check(not mp.dweZoneHolder:IsShown(), "zone art: steps back when Spoken shows its own")
    DialogueWheelE_ZoneArt = saved
end
GetQuestLogIndexByID, SelectQuestLogEntry, GetQuestLogSelection, GetNumQuestLogChoices, GetQuestLogChoiceInfo, GetNumQuestLogRewards = nil, nil, nil, nil, nil, nil
M.questID = 7894
M.FireEvent("QUEST_GREETING")
check(#DWE.currentOptions == 4 + OFF, "greeting options")
M.FireEvent("QUEST_FINISHED")

-- Book, 4 pages, popup on.
M.book = { title = "War of the Spider", pages = { "p1", "p2", "p3", "p4" } }
M.bookPage = 1
DialogueWheelE_ShowText = true
M.FireEvent("ITEM_TEXT_BEGIN")
M.FireEvent("ITEM_TEXT_READY")
check(DWE.textBody:GetText() == "p1", "book page 1 shown")
local function labels() local t = {} for i, o in ipairs(DWE.currentOptions) do t[i] = o.rawLabel end return table.concat(t, ",") end
check(labels():find(DWE.L.NEXT_PAGE, 1, true), "next page offered on page 1: " .. labels())
do -- manette dans un livre : bindings actifs, croix droite tourne la page
    M.cvars.GamePadEnable = "1"; DWE.RefreshBindings()
    check(M.bindings.PADDRIGHT == "DWE_PadNextBtn", "gamepad bound while a book is open")
    do -- croix gauche/droite : le bouton de page utilise passe en surbrillance
        local function sel() local o = DWE.currentOptions[DWE.selectedIndex]; return o and o.rawLabel end
        DWE.bookWheelAt = nil
        _G.DWE_PadNextBtn._scripts.OnClick(); M.FlushPending()
        DWE.bookWheelAt = nil
        _G.DWE_PadNextBtn._scripts.OnClick(); M.FlushPending()
        if DWE.textBody:GetText() == "p3" then
            check(sel() == DWE.L.NEXT_PAGE, "d-pad right: Next Page highlighted")
            DWE.bookWheelAt = nil
            _G.DWE_PadPrevBtn._scripts.OnClick(); M.FlushPending()
            check(sel() == DWE.L.PREV_PAGE and DWE.textBody:GetText() == "p2", "d-pad left: Previous Page highlighted (" .. tostring(sel()) .. ")")
            DWE.bookWheelAt = nil
            _G.DWE_PadPrevBtn._scripts.OnClick(); M.FlushPending()
            DWE.bookWheelAt = nil
        end
    end
    check(M.bindings.PAD4 == nil and M.bindings.PAD3 == nil and M.bindings.PADRSHOULDER == nil, "gamepad Y = ribbon; X and RB left to the game")
    local h = DWE.padCatcher._scripts and DWE.padCatcher._scripts.OnGamePadButtonDown
    if h and DWE.ribbon:IsShown() then
        h(DWE.padCatcher, "PAD4")
        check(DWE.RibbonPadOpen(), "gamepad Y opens the ribbon menu")
        check(DWE.ribbon.glowTarget == 0.55, "book: Y lights the ribbon while its menu is open")
        local page = DWE.textBody:GetText()
        h(DWE.padCatcher, "PADDRIGHT")
        check(DWE.textBody:GetText() == page, "d-pad moves in the ribbon menu, not the pages")
        h(DWE.padCatcher, "PAD1")
        h(DWE.padCatcher, "PAD1") -- toggle back
        h(DWE.padCatcher, "PAD2")
        check(not DWE.ribbon.open, "gamepad B closes the ribbon menu")
        check((DWE.ribbon.glowTarget or 0) <= 0.35, "book: ribbon light goes off with its menu")
        check(DWE.textBox:IsShown(), "B on the ribbon menu keeps the book open")
    end
    M.cvars.GamePadEnable = nil; DWE.RefreshBindings()
end
if withDUI then
    -- DialogueUI caches the whole book then turns back to page 1
    for p = 2, 4 do M.bookPage = p; M.FireEvent("ITEM_TEXT_READY") end
    M.bookPage = 1; M.FireEvent("ITEM_TEXT_READY")
    local pageTxt = (DWE.textHeader:GetText() or "") .. " " .. ((DWE.textBox.dweBook == true and DWE.bookPageNumText and DWE.bookPageNumText()) or "")
    check(pageTxt:find("1/4", 1, true) or pageTxt:find("1 / 4", 1, true), "page 1/4 shown after caching: " .. pageTxt .. " look=" .. tostring(DWE.BookLook()) .. " dweBook=" .. tostring(DWE.textBox.dweBook) .. " shown=" .. tostring(DWE.textBox:IsShown()))
end
for expect = 2, 4 do
    local nextOpt
    for _, o in ipairs(DWE.currentOptions) do if o.rawLabel == DWE.L.NEXT_PAGE then nextOpt = o end end
    check(nextOpt ~= nil, "next option present before page " .. expect)
    if nextOpt then nextOpt.action(); M.FlushPending() end
    check(DWE.textBody:GetText() == "p" .. expect, "single click shows page " .. expect .. " (got " .. tostring(DWE.textBody:GetText()) .. ")")
end
check(not labels():find(DWE.L.NEXT_PAGE, 1, true), "no next page on last page: " .. labels())
check(labels():find(DWE.L.PREV_PAGE, 1, true), "prev page on last page")
for _, o in ipairs(DWE.currentOptions) do if o.rawLabel == DWE.L.PREV_PAGE then o.action() break end end
check(DWE.textBody:GetText() == "p3", "prev page works")
-- Marque-page : pose sur la page 3, le livre se rouvre a la page 3 ; retire, il se rouvre a la 1.
if DWE.BookLook() == "book" then
    DWE.BookmarkToggle()
    local k, cur, saved = DWE.BookmarkInfo()
    check(saved == 3 and cur == 3, "bookmark set on page 3")
    M.FireEvent("ITEM_TEXT_CLOSED"); M.RunTimers()
    M.bookPage = 1
    M.FireEvent("ITEM_TEXT_BEGIN"); M.FireEvent("ITEM_TEXT_READY")
    for _ = 1, 5 do M.FlushPending() end
    check(DWE.textBody:GetText() == "p3", "book reopens on bookmarked page (got " .. tostring(DWE.textBody:GetText()) .. ")")
    DWE.BookmarkToggle()
    check(select(3, DWE.BookmarkInfo()) == nil, "bookmark removed")
    M.FireEvent("ITEM_TEXT_CLOSED"); M.RunTimers()
    M.bookPage = 1
    M.FireEvent("ITEM_TEXT_BEGIN"); M.FireEvent("ITEM_TEXT_READY")
    for _ = 1, 5 do M.FlushPending() end
    check(DWE.textBody:GetText() == "p1", "book reopens on page 1 without bookmark")
    -- La voix lit deja la page 3 d'un livre rouvert : le livre y va (pages chargees une a une).
    DWE.BookGoTo(3)
    for _ = 1, 5 do M.FlushPending() end
    check(DWE.textBody:GetText() == "p3", "far page reached from a fresh open (got " .. tostring(DWE.textBody:GetText()) .. ")")
end
M.FireEvent("ITEM_TEXT_CLOSED")
M.RunTimers()
-- Livre reduit : une longue page s'etale sur des sous-pages, tournees avant la page suivante.
do
    local long = string.rep("Lorem ipsum dolor sit amet, consectetur adipiscing elit. ", 40)
    M.book = { title = "Small Book", pages = { long, "second" } }
    M.bookPage = 1
    DialogueWheelE_BookScale, DialogueWheelE_BookLook = 0.6, "book"
    M.FireEvent("ITEM_TEXT_BEGIN"); M.FireEvent("ITEM_TEXT_READY"); M.RunTimers()
    local n = #DWE.bookSub.spreads
    check(DWE.textBox.dweBook == true and n > 1, "small book splits a long page: " .. n)
    local seen = {}
    for step = 1, n + 1 do
        local nextOpt
        for _, o in ipairs(DWE.currentOptions) do if o.rawLabel == DWE.L.NEXT_PAGE then nextOpt = o end end
        if not nextOpt then break end
        seen[#seen + 1] = DWE.bookSub.index
        nextOpt.action(); M.FlushPending(); M.RunTimers()
    end
    check(DWE.textBody:GetText() == "second", "after the sub-pages comes page 2: " .. tostring(DWE.textBody:GetText()))
    check(#seen == n, "each sub-page shown once: " .. table.concat(seen, ","))
    for _, o in ipairs(DWE.currentOptions) do if o.rawLabel == DWE.L.PREV_PAGE then o.action() break end end
    M.RunTimers()
    check(DWE.bookSub.index == n, "back from page 2 lands on the last sub-page: " .. DWE.bookSub.index)
    -- Roue cachee sous le livre : aucune ligne (meme creee apres coup) ne capte la souris.
    local grabbing = 0
    for i = 1, #DWE.currentOptions do if DWE.GetRow(i):IsMouseEnabled() then grabbing = grabbing + 1 end end
    check(grabbing == 0, "hidden wheel rows ignore the mouse in a book: " .. grabbing)
    M.FireEvent("ITEM_TEXT_CLOSED"); M.RunTimers()
    -- La position sauvee survit a la fermeture / reouverture d'un livre reduit.
    DialogueWheelE_BookPos = { point = "TOPLEFT", relPoint = "BOTTOMLEFT", x = 123, y = 456 }
    M.bookPage = 1
    M.FireEvent("ITEM_TEXT_BEGIN"); M.FireEvent("ITEM_TEXT_READY"); M.RunTimers()
    M.FireEvent("ITEM_TEXT_CLOSED"); M.RunTimers()
    M.FireEvent("ITEM_TEXT_BEGIN"); M.FireEvent("ITEM_TEXT_READY"); M.RunTimers()
    local bp = DialogueWheelE_BookPos
    check(bp and bp.x == 123 and bp.y == 456, "book position kept across reopen: " .. tostring(bp and bp.x) .. "," .. tostring(bp and bp.y))
    DialogueWheelE_BookScale, DialogueWheelE_BookLook, DialogueWheelE_BookPos = nil, nil, nil
    M.FireEvent("ITEM_TEXT_CLOSED"); M.RunTimers()
end
-- Plaques : pierre / bronze -> page seule sur une plaque de cette matiere, meme a plusieurs pages.
do
    local savedMat = ItemTextGetMaterial
    for _, mat in ipairs({ "Stone", "Bronze" }) do
        ItemTextGetMaterial = function() return mat end
        M.book = { title = "Here lies a hero", pages = { "Rest in peace.", "Second page." } }
        M.bookPage = 1
        M.FireEvent("ITEM_TEXT_BEGIN"); M.FireEvent("ITEM_TEXT_READY"); M.RunTimers()
        check(DWE.BookLook() == "note", mat .. " plaque shown as a single page")
        check(DWE.textBox:IsShown(), mat .. " plaque visible")
        M.FireEvent("ITEM_TEXT_CLOSED"); M.RunTimers()
    end
    ItemTextGetMaterial = savedMat
end
-- Aspect "livre" (plusieurs pages) : double page, a gauche de l'ecran, boutons en ligne
do
    local long = ("The ancient kingdom of Azjol-Nerub was founded by spiders. "):rep(8)
    M.book = { title = "War of the Spider", pages = { long, long } }
    M.bookPage = 1
    M.FireEvent("ITEM_TEXT_BEGIN"); M.FireEvent("ITEM_TEXT_READY")
    check(DWE.BookLook() == "book", "several pages: open book look")
    check(not (DWE.textHeader:GetText() or ""):find("%(%d+/%d+%)"), "open book: page number out of the title")
    check(DWE.textBody2:IsShown() and (DWE.textBody2:GetText() or "") ~= "", "open book: text on the right page too")
    check(#DWE.textBody:GetText() + #DWE.textBody2:GetText() >= #long - 2, "open book: no text lost in the split")
    local pt = DWE.textBox._points[#DWE.textBox._points]
    check(pt and pt[1] == "RIGHT" and pt[3] == "RIGHT", "book placed on the right of the screen by default")
    check(DWE.bookBar:IsShown() and DWE.choiceBox:GetAlpha() == 0, "book: buttons in a row, wheel hidden")
    DWE.choiceBox:SetAlpha(1)
    check(DWE.choiceBox:GetAlpha() == 0, "book: wheel stays hidden even if something shows it")
    DialogueWheelE_Locked = false
    DWE.DragStart("text"); DWE.textBox:ClearAllPoints(); DWE.textBox:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 123, -45); DWE.DragStop("text")
    check(DialogueWheelE_BookPos and DialogueWheelE_BookPos.x == 123, "book: dragged position saved")
    DWE.UpdateTextPanelVisuals()
    local bp = DWE.textBox._points[#DWE.textBox._points]
    check(bp and bp[4] == 123, "book: reopens where it was moved")
    DialogueWheelE_BookPos = nil
    local shown = 0
    for _, b in ipairs(DWE.bookBar.buttons) do if b:IsShown() then shown = shown + 1 end end
    check(shown == #DWE.currentOptions, "book: one button per choice (" .. shown .. ")")
    DialogueWheelE_BookLook = "note"
    DWE.UpdateTextPanelVisuals()
    check(not DWE.textBody2:IsShown() and DWE.bookBar:IsShown(), "note look: single page, buttons in a row")
    DialogueWheelE_BookLook = nil
    M.FireEvent("ITEM_TEXT_CLOSED"); M.RunTimers()
    check(not DWE.bookBar:IsShown() and DWE.choiceBox:GetAlpha() == 1, "book closed: wheel back to normal")
    -- Boutons : "Fermer" au lieu d'"Au revoir", "Spoken" seulement si Spoken est installe
    M.book = { title = "War of the Spider", pages = { long, long } }
    M.bookPage = 1
    M.FireEvent("ITEM_TEXT_BEGIN"); M.FireEvent("ITEM_TEXT_READY")
    local hasSpoken, hasDialogue, closeLabel = false, false, nil
    for _, o in ipairs(DWE.currentOptions) do
        if o.rawLabel == "Spoken" then hasSpoken = o end
        if o.rawLabel == DWE.L.TEXT_BTN then hasDialogue = true end
        if o.isGoodbye then closeLabel = o.rawLabel end
    end
    check(not hasDialogue and not hasSpoken, "book: no Dialogue/Spoken button")
    check(closeLabel ~= DWE.L.GOODBYE, "book: 'Close' instead of 'Goodbye' (" .. tostring(closeLabel) .. ")")
    if hasSpoken then
        hasSpoken.action(); M.FireEvent("ITEM_TEXT_CLOSED"); M.RunTimers()
        check(not DWE.choiceBox:IsShown() and not DWE.textBox:IsShown(), "book: 'Spoken' closes the book, no wheel left")
    else
        M.FireEvent("ITEM_TEXT_CLOSED"); M.RunTimers()
    end
    -- Livre de DialogueUI puis retour a l'addon : le livre de l'addon revient
    DialogueWheelE_BookStyle = "dui"
    M.FireEvent("ITEM_TEXT_BEGIN"); M.FireEvent("ITEM_TEXT_READY")
    M.FireEvent("ITEM_TEXT_CLOSED"); M.RunTimers()
    DialogueWheelE_BookStyle = nil
    M.FireEvent("ITEM_TEXT_BEGIN"); M.FireEvent("ITEM_TEXT_READY")
    check(DWE.textBox:IsShown() and DWE.BookLook() == "book", "book style back to the addon: addon book shown")
    M.FireEvent("ITEM_TEXT_CLOSED"); M.RunTimers()
    M.book = { title = "Note", pages = { long } }
    M.bookPage = 1
    M.FireEvent("ITEM_TEXT_BEGIN"); M.FireEvent("ITEM_TEXT_READY")
    check(DWE.BookLook() == "note", "single page: note look")
    check(DWE.noteText:GetText() == (long:gsub("%s+$", "")) and not DWE.textBody:IsShown(), "note: whole text in the scrolling area (" .. tostring(DWE.noteText:GetText()):sub(1,30) .. "|" .. tostring(DWE.textBody:IsShown()) .. "|" .. tostring(DWE.textBox.dweBook) .. ")")
    local nb = 0
    for _, o in ipairs(DWE.currentOptions) do if o.rawLabel == DWE.L.NEXT_PAGE or o.rawLabel == DWE.L.PREV_PAGE then nb = nb + 1 end end
    check(nb == 0, "note: no page buttons")
    check(DWE.noteText:GetJustifyH() == "LEFT" and not DWE.NOTE.noteHi:IsShown(), "note: text left-aligned, no bevel layer")
    M.FireEvent("ITEM_TEXT_CLOSED"); M.RunTimers()
    -- Plaque ronde de Dalaran : texte centre, police anguleuse du jeu, reflet grave.
    local oldPM = DWE.PlateMaterial
    DWE.PlateMaterial = function() return "Dalaran" end
    M.FireEvent("ITEM_TEXT_BEGIN"); M.FireEvent("ITEM_TEXT_READY")
    local hi = DWE.NOTE.noteHi
    check(DWE.noteText:GetJustifyH() == "CENTER" and (tostring((DWE.noteText:GetFont())):find("SKURRI") ~= nil) == not DWE.IS_CJK,
        "Dalaran plate: centered text in the angular game font (" .. tostring((DWE.noteText:GetFont())) .. ")")
    check(DWE.RoundNow() and DWE.NoteScale() == DWE.ROUND_DEFAULT.scale, "Dalaran plate: its own default size")
    DialogueWheelE_RibbonSeen, DialogueWheelE_RoundRibbonSeen = true, nil
    DWE.ribbon.pulse = nil
    DWE.UpdateRibbon(true)
    local rib = DWE.ribbon
    check(not rib:IsShown() or (DialogueWheelE_RoundRibbonSeen == true and rib.pulse ~= nil), "Dalaran plate: its symbol pulses the first time, even after the book ribbon was seen")
    rib.pulse = nil
    check(not rib:IsShown() or tostring(rib.glow._texture):find("PlateDalaranGlow") ~= nil,
        "Dalaran plate: its symbol opens the reading options (" .. tostring(rib:IsShown()) .. " " .. tostring(rib.glow._texture) .. ")")
    DialogueWheelE_RoundScale, DialogueWheelE_NoteScale = 0.3, nil
    check(DWE.NoteScale() == 0.3, "Dalaran plate: can be made much smaller than other plates")
    DWE.UpdateTextPanelVisuals()
    check(DWE.IS_CJK or tostring((DWE.noteText:GetFont())):find("FRIZQT") ~= nil, "Dalaran plate, very small: sharp interface font")
    check(DWE.BarScale(0.3) == 0.8 and DWE.BarScale(1.2) == 1.2, "Dalaran plate: its buttons stay readable when it is small")
    DWE.BookPosSet({ point = "TOPLEFT", relPoint = "BOTTOMLEFT", x = 10, y = 20 })
    check(DialogueWheelE_RoundPos and DialogueWheelE_RoundPos.x == 10 and DialogueWheelE_BookPos == nil, "Dalaran plate: its own place, other notes keep theirs")
    DialogueWheelE_RoundScale, DialogueWheelE_RoundPos = nil, nil
    DWE.UpdateTextPanelVisuals()
    local sx, sy = DWE.noteText:GetShadowOffset()
    local sc0 = DWE.NoteScale()
    check(not hi:IsShown() and sx < 0 and sy > 0 and math.abs(sx * sc0 + 1) < 0.01, "Dalaran plate: light letters, the carved shadow one real pixel on their upper-left edge")
    M.FireEvent("ITEM_TEXT_CLOSED"); M.RunTimers()
    DWE.PlateMaterial = oldPM
    M.FireEvent("ITEM_TEXT_BEGIN"); M.FireEvent("ITEM_TEXT_READY")
    check(not hi:IsShown() and DWE.noteText:GetJustifyH() == "LEFT", "plain note again: no bevel, left-aligned")
    M.FireEvent("ITEM_TEXT_CLOSED"); M.RunTimers()
    -- Y a la manette, pour chaque sorte de texte : le symbole s'allume menu ouvert, s'eteint ferme,
    -- et ne clignote pas la premiere fois.
    local oldUse = DWE.PadInUse
    DWE.PadInUse = function() return true end
    for _, mat in ipairs({ false, "Stone", "Dalaran" }) do
        DWE.PlateMaterial = function() return mat or nil end
        M.FireEvent("ITEM_TEXT_BEGIN"); M.FireEvent("ITEM_TEXT_READY")
        DialogueWheelE_RibbonSeen, DialogueWheelE_RoundRibbonSeen = nil, nil
        rib.pulse = nil
        DWE.UpdateRibbon(true)
        local name = mat or "parchment"
        if rib:IsShown() then
            check(rib.pulse == nil, name .. ": no first-time blink on the gamepad")
            if DWE.RibbonPadToggle() and rib.open then
                check(rib.glowTarget == 0.55, name .. ": Y lights the symbol while the menu is open")
                DWE.RibbonPadToggle()
                check(not rib.open and (rib.glowTarget or 0) <= 0.35, name .. ": light off when the menu closes")
            end
        end
        M.FireEvent("ITEM_TEXT_CLOSED"); M.RunTimers()
    end
    DWE.PadInUse, DWE.PlateMaterial = oldUse, oldPM
end

-- Game refuses anchoring (last: disables tracking for the session)
local errBefore = #M.errors
-- Game refuses anchoring too: falls back, never errors; tries again at the next conversation.
plate._noAnchor = true
M.plates = { plate }
DWE.choiceBox:Show()
for _ = 1, 30 do follower._scripts.OnUpdate(follower, 0.016) end
check(not DWE.IsFollowingNPC() and DWE.choiceBox:GetAlpha() == 1, "anchor refused: fixed place, visible")
DWE.choiceBox:Hide(); DWE.choiceBox:Show()
for _ = 1, 30 do follower._scripts.OnUpdate(follower, 0.016) end
check(DWE.choiceBox:GetAlpha() == 1 and not DWE.IsFollowingNPC(), "refused again next conversation: still fixed and visible")
check(type(DWE.followError) == "string", "refusal kept for /storytale npc")
DWE.choiceBox:Hide(); M.RunTimers()
check(#M.errors == errBefore, "no Lua error during NPC tracking")
plate._noAnchor = nil
M.plates = {}

-- Theme on the wheel (option)
local function wheelBg() local n = 0 for _, r in ipairs(DWE.choiceBox._regions) do if r._kind == "Texture" and r:IsShown() then n = n + 1 end end return n end
DialogueWheelE_ThemeFrames = true -- themes en cadre pour cette partie
DialogueWheelE_Theme = "parchment"
M.questTitle, M.questText, M.objText, M.questID = "Q", "Text", "Kill 5", 1
M.FireEvent("QUEST_DETAIL")
check(wheelBg() == 0 and DWE.GetRow(2 + OFF).text._color == "1.00,0.88,0.15", "option off: no wheel background, usual colors")
DialogueWheelE_WheelTheme = true
DWE.OnThemeChanged()
check(wheelBg() > 0, "option on: wheel background drawn")
check(DWE.GetRow(2 + OFF).text._color == "0.55,0.20,0.00" and DWE.objLine:GetText():find("^|cff8c3300"), "option on + light parchment: dark ink")
DialogueWheelE_Theme = "dark"
DWE.OnThemeChanged()
check(wheelBg() > 0 and DWE.GetRow(2 + OFF).text._color == "1.00,0.88,0.15" and DWE.objLine:GetText():find("^|cffffd700"), "option on + dark theme: usual colors")
DialogueWheelE_Theme = "transparent"
DWE.OnThemeChanged()
check(wheelBg() == 0, "option on + transparent: no background")
-- Bubble themes: one bubble per choice, preview in its own bubble, no block
local function pillsShown() local n = 0 for i = 1, #DWE.currentOptions do local r = DWE.GetRow(i) if rawget(r, "pill") and r.pill:IsShown() then n = n + 1 end end return n end
DialogueWheelE_Theme = "bubble_fantasy"
DWE.OnThemeChanged()
check(wheelBg() == 0, "bubble theme: no block behind the wheel")
check(pillsShown() == #DWE.currentOptions, "bubble theme: one bubble per choice (" .. pillsShown() .. ")")
local sel = DWE.GetRow(DWE.selectedIndex).pill
local other = DWE.GetRow(DWE.selectedIndex == 1 and 2 or 1).pill
check(tostring(sel.dweTexPath):find("SelTailDown$") and not tostring(other.dweTexPath):find("Sel"), "selected choice has the glowing frame")
local w1 = DWE.GetRow(1).pill:GetWidth()
local same = true
for i = 2, #DWE.currentOptions do if DWE.GetRow(i).pill:GetWidth() ~= w1 then same = false end end
check(same, "all choice bubbles have the same width")
check(sel.dweTex._texture and sel.dweTex._texture:find("PillFantasySelTailDown%.png") and sel.dweShape == "down", "selected choice tail points toward the player")
check(DWE.GetRow(2 + OFF).text._font[1] == DWE.FontPath(DialogueWheelE_Font or "friz"), "fantasy bubbles use the chosen font")
check(DWE.GetRow(2 + OFF).text._color == "0.55,0.20,0.00", "fantasy bubbles: dark ink")
local pp
for _, c in ipairs(DWE.choiceBox._children) do if rawget(c, "dweTexPath") and c:IsShown() then pp = c end end
check(pp ~= nil, "quest preview inside a bubble")

-- Theme Personnalise : couleurs choisies, contour du choix surligne, depart d'un autre theme.
do
    local saveC = DialogueWheelE_CustomColors
    DialogueWheelE_CustomColors = { bg = { 0.1, 0.2, 0.3 }, border = { 0.4, 0.5, 0.6 }, text = { 1, 1, 1 }, sel = { 1, 0, 0 } }
    DWE.CustomRefresh()
    local f = CreateFrame("Frame")
    DWE.SkinPill(f, "custom", true, nil)
    check(f.dweEdge and tostring(f.dweEdge._texture):find("PillCustomSelEdge") ~= nil, "custom: selected choice gets the highlight edge")
    local g = CreateFrame("Frame")
    DWE.SkinPill(g, "custom", false, nil)
    check(tostring(g.dweEdge._texture):find("PillCustomEdge") ~= nil and tostring(g.dweTex._texture):find("PillCustomFill") ~= nil, "custom: normal choice = fill + border layers")
    DWE.SkinPill(g, "game", false, nil)
    check(not g.dweEdge:IsShown(), "custom: border layer hidden again for other themes")
    check(DWE.CUSTOM_PALETTE.selected[1] == 1 and DWE.CUSTOM_PALETTE.selected[2] == 0, "custom: highlight color used for the selected choice")
    check(DWE.THEME_STYLES.custom.bg[3] == 0.3, "custom: frame background follows the chosen color")
    DWE.CustomFromTheme("ruby")
    local c = DialogueWheelE_CustomColors
    check(c.bg[1] > c.bg[2] and c.sel[1] > c.sel[3], "custom: starting from Ruby gives red colors")
    -- Themes enregistres : a part des options, survivent a un reset.
    local saveP = DialogueWheelE_CustomPresets
    DialogueWheelE_CustomPresets = nil
    check(DWE.CustomPresetSave("  Rubis  ") == 1 and DWE.CustomPresets()[1].name == "Rubis", "presets: saved under a trimmed name")
    check(DWE.CustomPresetSave("") == nil, "presets: empty name refused")
    DialogueWheelE_CustomColors = { bg = { 0, 0, 1 } }
    check(DWE.CustomPresetSave("rubis") == 1 and #DWE.CustomPresets() == 1, "presets: same name replaces")
    DWE.CustomPresetSave("Autre")
    local isOpt = false
    for _, k in ipairs(DWE.OPTION_VARS) do if k == "CustomPresets" then isOpt = true end end
    check(not isOpt, "presets: not wiped by resetting the options")
    check(DWE.CustomPresetApply(1) and DialogueWheelE_CustomColors.bg[3] == 1 and DWE.THEME_STYLES.custom.bg[3] == 1, "presets: applying restores the colors")
    check(DWE.CustomPresetDelete(1) and #DWE.CustomPresets() == 1 and DWE.CustomPresets()[1].name == "Autre", "presets: delete")
    check(not DWE.CustomPresetApply(5), "presets: missing preset ignored")
    DialogueWheelE_CustomPresets = saveP
    -- Opacite : les choix de la roue la suivent aussi (theme Personnalise et autres).
    local saveFrames = DialogueWheelE_ThemeFrames
    DialogueWheelE_ThemeFrames = nil
    for _, th in ipairs({ "custom", "whisper", "dark" }) do
        DialogueWheelE_Theme, DialogueWheelE_WheelTheme, DialogueWheelE_Opacity = th, true, 0.4
        DWE.OnThemeChanged()
        if DWE.UpdateVisuals then DWE.UpdateVisuals() end
        local probe
        for i = 1, 12 do
            local r = DWE.GetRow(i)
            if r and r.pill and r.pill:IsShown() then probe = r.pill break end
        end
        local want = th == "custom" and DWE.CUSTOM_FILL_ALPHA * 0.4 or 0.4
        check(not probe or (math.abs(probe.dweTex._alpha - want) < 1e-6 and (not probe.dweEdge or not probe.dweEdge:IsShown() or probe.dweEdge._alpha == 0.4)),
            "opacity applies to the wheel choices (" .. th .. "): " .. tostring(probe and probe.dweTex._alpha))
    end
    DialogueWheelE_Opacity, DialogueWheelE_ThemeFrames = nil, saveFrames
    DialogueWheelE_CustomColors = saveC
    DWE.CustomRefresh()
end
DialogueWheelE_Theme = "bubble"
DWE.OnThemeChanged()
check(pillsShown() == #DWE.currentOptions and DWE.GetRow(2 + OFF).text._color == "1.00,0.88,0.15", "game bubbles: usual light colors")
DialogueWheelE_Theme = "dark"
DWE.OnThemeChanged()
check(pillsShown() == 0 and wheelBg() > 0, "back to block theme: choice bubbles removed")
check(DWE.GetRow(2 + OFF).text.dweFontKey == "default", "back to game font outside fantasy bubbles")
DialogueWheelE_WheelTheme = false
DialogueWheelE_Theme = "parchment"
DWE.OnThemeChanged()
check(wheelBg() == 0 and DWE.GetRow(2 + OFF).text._color == "1.00,0.88,0.15" and DWE.objLine:GetText():find("^|cffffd700"), "option off again: back to normal")
-- Regression : apres un theme a fond calcule (DialogueUI), passer a une bulle puis
-- redimensionner ne doit pas faire revenir l'ancien fond derriere la roue.
DialogueWheelE_WheelTheme = true
for _, th in ipairs(DWE.DUI_ON and { "dui_dark", "dui_brown", "arcane" } or { "arcane" }) do
    DialogueWheelE_Theme = th
    DWE.OnThemeChanged()
    check(wheelBg() > 0, "mix test: " .. th .. " drawn behind the wheel")
    DialogueWheelE_Theme = "bubble"
    DWE.OnThemeChanged()
    for _, fr in ipairs(M.frames) do
        local f = fr._scripts and fr._scripts.OnSizeChanged
        if f then f(fr, 300, 200) end
    end
    check(wheelBg() == 0, "mix test: " .. th .. " does not come back after switching to a bubble")
end
DialogueWheelE_WheelTheme = false
-- Par defaut, les themes (sauf Sans cadre et Cinematique) sont en bulle
DialogueWheelE_ThemeFrames = nil
DialogueWheelE_WheelTheme = true
for id, sk in pairs(DWE.BUBBLE_SKINS) do
    if sk.art and (DWE.DUI_ON or not id:find("^dui_")) then
        DialogueWheelE_Theme = id
        DWE.OnThemeChanged()
        check(wheelBg() == 0 and pillsShown() == #DWE.currentOptions, "bubble mode " .. id .. ": choice bubbles, no block")
        local sp = DWE.GetRow(DWE.selectedIndex).pill
        check(sp.dweTex._texture and sp.dweTex._texture:find("Pill" .. sk.art .. "Sel"), "bubble mode " .. id .. ": theme art on choices")
        local light = id == "parchment" or id == "dui_brown" or id == "folio" or id == "velin" or id == "arcane" or id == "sylvan"
        check((DWE.GetRow(2 + OFF).text._color == "0.55,0.20,0.00") == light, "bubble mode " .. id .. ": text color fits the background")
    end
end
DialogueWheelE_Theme = "cinema"
DWE.OnThemeChanged()
check(pillsShown() == 0 and DWE.BubbleSkin() == nil, "cinematic stays out of bubble mode")
DialogueWheelE_Theme = "transparent"
DWE.OnThemeChanged()
check(DWE.BubbleSkin() == nil, "frameless stays out of bubble mode")
DialogueWheelE_WheelTheme = false
DialogueWheelE_Theme = "parchment"
DWE.OnThemeChanged()
M.FireEvent("QUEST_FINISHED")
DialogueWheelE_Theme = "dark"

-- Item quality read from the item itself (quest log value unreliable)
do
    local saved = C_Item.GetItemInfo
    C_Item.GetItemInfo = function(link) return "X", link, 2 end
    GetItemQualityColor = function(q) if q == 2 then return 0.12, 1, 0 end return 1, 1, 1 end
    GetQuestItemInfo = function(kind, i) return "Item " .. kind .. i, 134400, 1, 99999 end
    M.questTitle, M.questText, M.objText, M.questID, M.numChoices = "Q", "Text", "Kill", 1, 0
    M.FireEvent("QUEST_DETAIL")
    check(DWE.GetRewardButton(1).text._color == "0.12,1.00,0.00", "item colored by its real quality: " .. tostring(DWE.GetRewardButton(1).text._color))
    M.FireEvent("QUEST_FINISHED")
    -- No usable link info: rarity found from the item number
    C_Item.GetItemInfo = function() return nil end
    C_Item.GetItemQualityByID = function(id) return id == 4 and 3 or nil end
    GetItemQualityColor = function(q) if q == 3 then return 0, 0.44, 0.87 end return 1, 1, 1 end
    GetQuestItemLink = function(kind, i) return "|cff0070dd|Hitem:4::::|h[Blue]|h|r" end
    M.FireEvent("QUEST_DETAIL")
    check(DWE.GetRewardButton(1).text._color == "0.00,0.44,0.87", "rarity from item number when info not cached: " .. tostring(DWE.GetRewardButton(1).text._color))
    M.FireEvent("QUEST_FINISHED")
    C_Item.GetItemQualityByID = nil
    GetQuestItemLink = function(kind, i) return "|Hitem:" .. i .. "|h[x]|h" end
    C_Item.GetItemInfo = saved
end

-- Escape closes the conversation cleanly (own key catcher, no key binding, nothing in
-- UISpecialFrames: the game read our names there and the gamepad navigation got blocked)
local function PressEscape()
    local fr = DialogueWheelEEscapeCatcher
    local fn = fr and fr._scripts and fr._scripts.OnKeyDown
    if fr:IsShown() and fn then fn(fr, "ESCAPE") end
end
local mine = false
for _, n in ipairs(UISpecialFrames or {}) do if n == "DialogueWheelEEscapeCatcher" or n == "StorytaleSpokenQueue" then mine = true end end
check(not mine, "nothing of Storytale in UISpecialFrames")
M.log = {}
M.gossipText = "Hi"; M.gossipOptions = {}; M.availQuests = {}; M.activeQuests = {}
M.FireEvent("GOSSIP_SHOW")
check(DialogueWheelEEscapeCatcher:IsShown(), "Escape armed during conversation")
check(M.bindings.ESCAPE == nil, "Escape key not taken over")
DialogueWheelEEscapeCatcher._scripts.OnKeyDown(DialogueWheelEEscapeCatcher, "W")
check(DialogueWheelEEscapeCatcher:IsShown() and DWE.choiceBox:IsShown(), "other keys pass through, conversation stays")
PressEscape()
local closed = false
for _, l in ipairs(M.log) do if l == "CloseGossip" then closed = true end end
check(closed and not DWE.choiceBox:IsShown() and next(M.bindings) == nil, "Escape closed the conversation like Goodbye")
M.FireEvent("GOSSIP_CLOSED")
M.log = {}
M.FireEvent("GOSSIP_SHOW")
M.FireEvent("GOSSIP_CLOSED")
check(not DialogueWheelEEscapeCatcher:IsShown() and #M.log == 0, "normal close: Escape disarmed, no extra close")
M.FireEvent("GOSSIP_SHOW")
local bye = DWE.currentOptions[#DWE.currentOptions]
M.log = {}
bye.action()
local n = 0
for _, l in ipairs(M.log) do if l == "CloseGossip" then n = n + 1 end end
check(n == 1 and not DialogueWheelEEscapeCatcher:IsShown(), "Goodbye: single close, Escape disarmed")
M.FireEvent("GOSSIP_CLOSED")
DialogueWheelE_EscClose = false
M.FireEvent("GOSSIP_SHOW")
check(not DialogueWheelEEscapeCatcher:IsShown(), "option off: Escape not used")
M.FireEvent("GOSSIP_CLOSED")
DialogueWheelE_EscClose = nil

-- Popup (other themes): gradual text only with Spoken installed
DialogueWheelE_Theme = "dark"
DialogueWheelE_ShowText = true
Spoken = nil
DWE.SetDialogueText("NPC", "Welcome to the inn, traveler.")
check((DWE.textBody._grad or 100000) >= 1000, "no Spoken: popup text shown at once")
if os.getenv("NOGRADIENT") ~= "1" then
local pnow = 2000
GetTime = function() return pnow end
local ptext = "Welcome to the inn, traveler. Rest your weary bones by the fire."
local pclip = { length = 10, spokenAt = pnow + 10, text = ptext, present = { transcript = ptext } }
Spoken = { GetNowPlaying = function() return pclip end, IsPaused = function() return false end }
local popF
for _, fr in ipairs(M.frames) do if fr._scripts.OnUpdate and not fr._scripts.OnEvent and not fr._name and not rawget(fr, "UnitFrame") and fr._parent == nil then popF = fr end end
DWE.SetDialogueText("NPC", ptext)
check(DWE.textBody._grad == 0, "Spoken installed: popup text starts hidden")
local prevG, monotonic = 0, true
for _ = 1, 100 do
    pnow = pnow + 0.05
    if popF then popF._scripts.OnUpdate(popF, 0.05) end
    local g = DWE.textBody._grad or 0
    if g < prevG or g - prevG > 4 then monotonic = false end
    prevG = g
end
local half = DWE.textBody._grad
check(popF and half and half >= 26 and half <= 38, "popup follows the voice (50%): " .. tostring(half))
check(monotonic, "popup writing is smooth: no jump, never goes back")
DWE.textBox._scripts.OnMouseUp(DWE.textBox, "LeftButton")
check(DWE.textBody._grad >= 1000, "click shows the whole popup text")
pclip = { length = 10, spokenAt = pnow + 5, text = "Other words entirely here.", present = {} }
DWE.SetDialogueText("NPC", "Something else to read in this popup.")
if popF then for _ = 1, 20 do popF._scripts.OnUpdate(popF, 0.05) end end
check(DWE.textBody._grad and DWE.textBody._grad >= 20 and DWE.textBody._grad <= 32, "no matching voice: steady own pace: " .. tostring(DWE.textBody._grad))
-- Mot lu par les sous-titres de Spoken : l'ecriture s'aligne sur ce mot (meme si le debit
-- n'est pas regulier : ici le premier mot dure la moitie de la replique)
do
    local wtext = "Welcome to the inn, traveler. Rest your weary bones by the fire."
    local wclip = { length = 10, spokenAt = pnow + 10, text = wtext, present = { transcript = wtext } }
    pclip = wclip
    local prog = 0
    local tw = { { start = 0, finish = 5 } }
    for i = 2, 12 do tw[i] = { start = 5 + (i - 2) * 5 / 11, finish = 5 + (i - 1) * 5 / 11 } end
    SpokenEnv = { Transcript = { clip = wclip, words = tw, totalWeight = 10, timed = true,
        GetProgress = function() return prog end,
        WordAt = function(_, p) local t = p * 10 for i, w in ipairs(tw) do if t < w.finish then return i end end return #tw end } }
    DWE.SetDialogueText("NPC", wtext)
    prog = 0.5
    for _ = 1, 20 do pnow = pnow + 0.05; if popF then popF._scripts.OnUpdate(popF, 0.05) end end
    local g = DWE.textBody._grad or 0
    check(g >= 7 and g <= 11, "follows the word Spoken reads (word 2 at 50%), not the time: " .. g)
    SpokenEnv = nil
    -- Replique "texte seul" (pas de son) : ignoree, rythme regulier
    pclip = { length = 3, spokenAt = pnow + 3, text = wtext, present = { transcript = wtext }, textOnly = true }
    DWE.SetDialogueText("NPC", "Another line entirely, typed at a steady pace for the reader.")
    local steps, prevG2, maxStep = 0, 0, 0
    for _ = 1, 40 do
        pnow = pnow + 0.05
        if popF then popF._scripts.OnUpdate(popF, 0.05) end
        local g2 = DWE.textBody._grad or 0
        if g2 - prevG2 > maxStep then maxStep = g2 - prevG2 end
        prevG2 = g2
    end
    check(maxStep <= 2 and prevG2 > 40 and prevG2 < 65, "text-only Spoken line: steady own pace: " .. prevG2 .. " max step " .. maxStep)
end
DWE.SetDialogueText("NPC", "")
check(DWE.textBody._grad >= 1000, "no-text label fully visible")
end
Spoken = nil
GetTime = nil

-- No text grey
DWE.SetDialogueText("NPC", "")
local r = DWE.textBody._textColor
check(DWE.textBody:GetText() == DWE.L.NO_TEXT, "no-text label")

-- Priorite Spoken : un livre lu s'arrete pour un PNJ, puis reprend
if withSpoken then
    local hadEnv = rawget(_G, "SpokenEnv")
    local env = hadEnv or {}
    _G.SpokenEnv = env
    local calls = { pause = 0, resume = 0, advance = 0 }
    local gates = {}
    local book = { present = { bullet = "book" }, key = "b:test-heard" }
    DWE.SpokenFocus.MarkHeard(book)
    local queue = { sounds = { book } }
    function queue:IsPlaying() return true end
    function queue:GetCurrentSound() return self.sounds[1] end
    function queue:Advance() calls.advance = calls.advance + 1 end
    local api = {}
    function api:AddGate(fn) gates[#gates + 1] = fn end
    function api:IsPaused() return false end
    function api:Pause() calls.pause = calls.pause + 1 end
    function api:Resume() calls.resume = calls.resume + 1 end
    function api:RegisterCallback() end
    local oldApi, oldQueue = rawget(env, "Spoken"), rawget(env, "SoundQueue")
    env.Spoken, env.SoundQueue = api, queue
    DWE.SpokenFocus.installed = nil
    DWE.SpokenFocus.npc = false
    M.FireEvent("GOSSIP_SHOW")
    check(#gates == 1 and calls.pause == 1 and calls.resume == 1, "spoken focus: book stops when talking to an NPC")
    check(gates[1](book) ~= nil and gates[1]({ present = {} }) == nil, "spoken focus: book held, NPC line allowed")
    check(gates[1]({ present = { bullet = "book" }, key = "b:never-heard" }) == nil, "spoken focus: unheard book keeps priority")
    M.FireEvent("GOSSIP_CLOSED"); M.RunTimers()
    queue.sounds = { book }
    check(gates[1](book) == nil and calls.advance >= 1, "spoken focus: book resumes after the conversation")
    -- Une replique "basse" de PNJ n'est plus jetee a cause du livre en attente
    local seenPrio
    queue.dweWrapped = nil
    function queue:Add(clip) seenPrio = self.sounds[1].priority; return clip end
    DWE.SpokenFocus.installed = nil
    DWE.SpokenFocus.npc = false
    M.FireEvent("GOSSIP_SHOW")
    queue:Add({ priority = "low", present = {} })
    check(seenPrio == "low" and book.priority == nil, "npc low line admitted past a waiting book (book priority restored)")
    M.FireEvent("GOSSIP_CLOSED"); M.RunTimers()
    -- Couper la voix d'un livre
    local removed = 0
    function queue:RemoveSoundFromQueue(c) removed = removed + 1 end
    DWE.SpokenFocus.SetBookMuted(true)
    check(gates[1](book) ~= nil, "mute: book voice held")
    DWE.SpokenFocus.OnBookClosed()
    check(removed == 1 and DWE.SpokenFocus.bookMuted and DialogueWheelE_BookVoiceOff == true,
        "mute: book lines dropped when the book closes, voice stays off for the next book")
    DWE.SpokenFocus.SetBookMuted(false)
    check(not DWE.SpokenFocus.bookMuted and DialogueWheelE_BookVoiceOff == nil, "unmute: voice back on and remembered")
    -- File : ce que nos regles coupaient reste dans la file, en attente manuelle.
    do
        local heardGreet = { priority = "low", present = { bullet = "gossip", header = "Old NPC" }, key = "g:heard" }
        DWE.SpokenFocus.MarkHeard(heardGreet)
        check(DWE.SpokenFocus.Hold(queue, heardGreet, "test") == true and heardGreet.dweManual,
            "greeting already heard: kept in the queue too (an NPC has several, each can be heard again)")
        local greet = { priority = "low", present = { bullet = "gossip", header = "Old NPC" }, key = "g:1" }
        DWE.SpokenFocus.Hold(queue, greet, "test")
        check(greet.dweManual and greet.priority == "normal", "manual hold: line kept, not dropped as low priority")
        check(gates[1](greet) == DWE.L.SPOKEN_HELD, "manual hold: never plays on its own")
        queue.sounds = { greet }
        DWE.SpokenFocus.PlayGroup("npc:Old NPC")
        check(gates[1](greet) == nil, "manual hold: plays when chosen in the queue")
        DWE.SpokenFocus.forced = nil
        local groups = DWE.SpokenFocus.Groups()
        check(groups[1] and groups[1].manual == true, "manual hold: marked in the queue list")
        -- Chaque replique d'un PNJ a sa ligne : on en retire une seule.
        do
            local q1 = { present = { bullet = "quest", header = "Old NPC", label = "A Donation of Wool" }, key = "q:1", id = 901 }
            local q2 = { present = { bullet = "quest", header = "Old NPC", label = "A Donation of Silk" }, key = "q:2", id = 902 }
            queue.sounds = { q1, q2 }
            local g2 = DWE.SpokenFocus.Groups()
            check(#g2 == 2 and g2[1].label:find("Wool", 1, true) and g2[2].label:find("Silk", 1, true),
                "queue: each NPC line listed on its own (" .. tostring(#g2) .. ")")
            local gone = {}
            local oldRm = queue.RemoveSoundFromQueue
            function queue:RemoveSoundFromQueue(c) gone[#gone + 1] = c end
            DWE.SpokenFocus.CloseGroup(g2[2].key)
            check(#gone == 1 and gone[1] == q2, "queue: closing a line removes only that line")
            -- Choisir une autre replique du meme PNJ : celle de tete s'arrete (gardee), la choisie passe devant.
            queue.sounds = { q1, q2 }
            local g3 = DWE.SpokenFocus.Groups()
            local oldPlaying, oldNow = queue.IsPlaying, queue.GetNowPlaying
            function queue:IsPlaying() return false end
            function queue:GetNowPlaying() return nil end
            DWE.SpokenFocus.PlayGroup(g3[2].key)
            check(queue.sounds[1] == q2 and q1.dweManual, "queue: picking another line of the same NPC plays it, the first one waits")
            check(gates[1](q1) == DWE.L.SPOKEN_HELD and gates[1](q2) == nil, "queue: the chosen line speaks, the other one holds")
            queue.IsPlaying, queue.GetNowPlaying = oldPlaying, oldNow
            DWE.SpokenFocus.forced, q1.dweManual = nil, nil
            queue.RemoveSoundFromQueue = oldRm
            DWE.SpokenFocus.forcedClip = nil
        end
        -- La meme replique redeclenchee remplace sa copie retenue (sinon Spoken refuse le doublon).
        do
            local held = { priority = "normal", dweManual = true, present = { bullet = "gossip", header = "Elf" }, key = "g:elf" }
            local other = { priority = "normal", dweManual = true, present = { bullet = "gossip", header = "Dwarf" }, key = "g:dwarf" }
            queue.sounds = { held, other }
            local gone, added = {}, nil
            local oldRm, oldAdd, oldWrap = queue.RemoveSoundFromQueue, queue.Add, queue.dweWrapped
            function queue:RemoveSoundFromQueue(c) gone[#gone + 1] = c; for i, x in ipairs(self.sounds) do if x == c then table.remove(self.sounds, i) break end end end
            function queue:Add(c) for _, x in ipairs(self.sounds) do if x.key == c.key then return nil, "duplicate" end end added = c; return c end
            queue.dweWrapped = nil
            DWE.SpokenFocus.installed = nil
            DWE.SpokenFocus.npc = false
            M.FireEvent("GOSSIP_SHOW")
            local again = { priority = "low", present = { bullet = "gossip", header = "Elf" }, key = "g:elf" }
            local r = queue:Add(again)
            check(r == again and added == again and #gone == 1 and gone[1] == held,
                "same line triggered again replaces its held copy (only that one)")
            M.FireEvent("GOSSIP_CLOSED"); M.RunTimers()
            queue.RemoveSoundFromQueue, queue.Add, queue.dweWrapped = oldRm, oldAdd, oldWrap
            DWE.SpokenFocus.installed = nil
        end
        -- Page de quete ouverte, la ligne pas encore arrivee : lecteur cache (pas de salutation vide).
        do
            local F = DWE.SpokenFocus
            local stopped = { priority = "low", present = { bullet = "gossip", header = "Elf" }, key = "g:elf2" }
            queue.sounds = { stopped }
            local oldNow = queue.GetNowPlaying
            function queue:GetNowPlaying() return nil end
            F.npc = true
            F.WatchPage("QUEST_DETAIL")
            check(F.QuestWaiting() == true, "quest page: player hidden while only a stopped greeting waits")
            local prevQuest = { priority = "normal", present = { bullet = "quest", header = "Elf", label = "A Donation of Wool" }, key = "q:wool" }
            queue.sounds = { prevQuest }
            check(F.QuestWaiting() == true, "second quest page: player hidden while the previous quest line waits, stopped")
            F.lineSeq = (F.lineSeq or 0) + 1
            check(F.QuestWaiting() == false, "quest page: player back once the quest line arrives")
            F.npc = false
            queue.GetNowPlaying = oldNow
        end
        -- Livre lu en entier : face a un PNJ, il ne reprend plus tout seul.
        local done = { present = { bullet = "book", label = "Finished Tome" }, key = "b:fin" }
        DialogueWheelE_ReadBooks = nil
        DWE.MarkBook("Finished Tome", true)
        DWE.SpokenFocus.npc = true
        check(gates[1](done) == DWE.L.SPOKEN_HELD and done.dweManual, "finished book: held for manual play during a conversation")
        DWE.SpokenFocus.npc = false
        check(gates[1](done) == DWE.L.SPOKEN_HELD, "finished book: stays manual after the conversation")
        local fresh = { present = { bullet = "book", label = "Fresh Tome" }, key = "b:fresh" }
        DWE.SpokenFocus.npc = true
        check(gates[1](fresh) == nil, "unread book: unchanged (keeps its priority)")
        DWE.SpokenFocus.npc = false
        -- Rien ne parle et tout est a la demande : lecteur cache, petit bouton a la place.
        local ui = DWE.SpokenQueueUI
        if ui and ui.UpdateNotice then
            local oldNow = queue.GetNowPlaying
            function queue:GetNowPlaying() return nil end
            queue.sounds = { done }
            ui.UpdateNotice()
            check(ui.NoticeShown() and DWE.spokenHeldHide, "held only: Spoken's player hidden, discreet button shown")
            queue.sounds = { done, fresh }
            ui.UpdateNotice()
            check(not ui.NoticeShown() and not DWE.spokenHeldHide, "something to play: player back, button gone")
            queue.sounds = {}
            ui.UpdateNotice()
            check(not ui.NoticeShown(), "empty queue: no button")
            queue.GetNowPlaying = oldNow
        end
        DialogueWheelE_ReadBooks = nil
        queue.sounds = { book }
    end
    env.Spoken, env.SoundQueue = oldApi, oldQueue
    if not hadEnv then _G.SpokenEnv = nil end
    DWE.SpokenFocus.installed = nil
end

-- Fenetre DialogueUI creee apres coup : masquee tout de suite (pas de melange avec un autre theme)
DialogueWheelE_ShowText = true
DWE.choiceBox:Show()
local late = CreateFrame("Frame", "DUILateFrame", UIParent)
late:SetAlpha(1)
check(late:GetAlpha() == 0, "DialogueUI frame created later is hidden at once")
local lateChild = CreateFrame("Frame", "$parentChild", late)
check(DUILateFrameChild and DUILateFrameChild:GetAlpha() == 0 or DUILateFrameChild == nil, "child frame named with $parent handled")
DWE.choiceBox:Hide(); M.RunTimers()

-- Objet pas encore en cache : le nom vient du cache des objets, sinon on reessaie
do
    local oQ, oI = GetQuestItemInfo, GetItemInfo
    local cached = false
    GetQuestItemInfo = function(kind, i) return nil, 134400, 1, 2 end
    local oCI = C_Item.GetItemInfo
    C_Item.GetItemInfo = function(x) if cached then return "Epee du Kraul", "|Hitem:1|h[x]|h", 3 end end
    M.numChoices = 0
    M.questID = 900
    M.FireEvent("QUEST_DETAIL")
    local function names()
        local t = {}
        for i = 1, 12 do local b = DWE.GetRewardButton(i) if b:IsShown() then t[#t + 1] = b.text:GetText() or "" end end
        return table.concat(t, ",")
    end
    check(names():find(DWE.L.LOADING, 1, true), "uncached item: loading label first: " .. names())
    cached = true
    M.RunTimers()
    check(names():find("Epee du Kraul", 1, true) and not names():find(DWE.L.LOADING, 1, true), "item name shown once cached (retry): " .. names())
    M.FireEvent("QUEST_FINISHED")
    GetQuestItemInfo, GetItemInfo = oQ, oI
    C_Item.GetItemInfo = oCI
end

-- Beaucoup de choix (garde de Hurlevent) : 7 visibles, la fenetre suit la selection
do
    local opts = {}
    for i = 1, 14 do opts[i] = { gossipOptionID = 500 + i, name = "Direction " .. i, icon = 132053 } end
    local oldOpts = M.gossipOptions
    M.gossipOptions = opts
    DialogueWheelE_Theme = "transparent"
    M.FireEvent("GOSSIP_SHOW")
    local function shownRows()
        local n = 0
        for i = 1, #DWE.currentOptions do local r = DWE.GetRow(i) if r:IsShown() then n = n + 1 end end
        return n
    end
    check(#DWE.currentOptions >= 15 and shownRows() == 7, "many choices: only 7 shown: " .. shownRows() .. "/" .. #DWE.currentOptions)
    check(DWE.choiceBox:GetHeight() < 260, "many choices: wheel stays compact: " .. DWE.choiceBox:GetHeight())
    DWE.selectedIndex = #DWE.currentOptions - 1
    DWE.UpdateVisuals()
    check(not DWE.GetRow(#DWE.currentOptions - 1):IsShown() or true, "list glides (not settled yet)")
    DWE.SettleScroll()
    check(DWE.GetRow(#DWE.currentOptions - 1):IsShown() and not DWE.GetRow(1):IsShown(), "window follows the selection down")
    DWE.selectedIndex = 1
    DWE.UpdateVisuals()
    DWE.SettleScroll()
    check(DWE.GetRow(1):IsShown(), "window follows the selection back up")
    -- A la souris : fleche du bas, puis barre glissee
    DWE.ScrollWheelBy(3)
    DWE.SettleScroll()
    check(not DWE.GetRow(1):IsShown() and DWE.GetRow(4):IsShown(), "scroll down with the mouse")
    check(DWE.selectedIndex >= 4, "selection stays visible while scrolling")
    -- Glissade : la liste passe par des positions intermediaires
    DWE.ScrollWheelBy(-10)
    local anim
    for _, fr in ipairs(M.frames) do if fr._scripts and fr._scripts.OnUpdate and fr:IsShown() and not fr._name and not fr.startY and fr ~= follower then
        local r5 = DWE.GetRow(5); local y0 = r5._points[#r5._points][5]
        fr._scripts.OnUpdate(fr, 0.016)
        local y1 = r5._points[#r5._points][5]
        if y1 ~= y0 then anim = { y0, y1 } end
    end end
    check(anim and math.abs(anim[2] - anim[1]) > 0.5, "scroll glides over several frames")
    DWE.SettleScroll()
    check(DWE.GetRow(1):IsShown(), "scroll back to the top")
    check(DWE.scrollBusy == false, "scroll bar rests dimmed once the list settles")
    do
        local r = DWE.GetRow(1)
        local p = r._points[#r._points]
        check(p and p[1] == "TOPLEFT" or true, "row anchored")
        local rp
        for _, q in ipairs(r._points) do if q[1] == "TOPRIGHT" then rp = q end end
        check(rp and rp[4] <= -18, "choices keep clear of the scroll bar: " .. tostring(rp and rp[4]))
    end
    -- Glisser la liste elle-meme vers le haut : les choix du dessous apparaissent, sans clic
    local oldDown = IsMouseButtonDown
    IsMouseButtonDown = function() return true end
    M.cursor = { 500, 300 }
    local r2 = DWE.GetRow(2 + OFF)
    r2._scripts.OnMouseDown(r2, "LeftButton")
    M.cursor = { 500, 300 + DWE.choiceBox:GetHeight() / 7 * 3 }
    local drv
    for _, fr in ipairs(M.frames) do if fr._scripts and fr._scripts.OnUpdate and fr:IsShown() and fr.startY then drv = fr end end
    if drv then drv._scripts.OnUpdate(drv, 0.016) end
    check(not DWE.GetRow(1):IsShown(), "drag the list up: it follows the mouse")
    IsMouseButtonDown = function() return false end
    r2._scripts.OnMouseUp(r2, "LeftButton")
    DWE.SettleScroll()
    check(DWE.wheelFirst >= 3 and DWE.wheelFirst <= 5, "released: settles on a whole choice: " .. tostring(DWE.wheelFirst))
    local clicked = false
    local oldAction = DWE.currentOptions[2 + OFF].action
    DWE.currentOptions[2 + OFF].action = function() clicked = true end
    r2._scripts.OnClick(r2)
    check(not clicked, "releasing after a drag is not a click")
    r2._scripts.OnMouseDown(r2, "LeftButton")
    r2._scripts.OnMouseUp(r2, "LeftButton")
    r2._scripts.OnClick(r2)
    check(clicked, "a simple click still chooses")
    DWE.currentOptions[2 + OFF].action = oldAction
    IsMouseButtonDown = oldDown
    M.FireEvent("GOSSIP_CLOSED")
    M.gossipOptions = oldOpts
end

-- Livres : jamais en bulle ; theme parchemin a la place d'un theme bulle
do
    DialogueWheelE_Theme = "bubble"
    DialogueWheelE_ShowText = true
    DialogueWheelE_BookStyle = nil
    M.FireEvent("ITEM_TEXT_BEGIN")
    M.FireEvent("ITEM_TEXT_READY")
    check(DWE.choiceBox:IsShown(), "book: wheel shown")
    check(not (DWE.bubble and DWE.bubble:IsShown()), "book: no speech bubble")
    check(DWE.textBox:IsShown(), "book: parchment popup shown instead")
    M.FireEvent("ITEM_TEXT_CLOSED")
    M.FireEvent("GOSSIP_SHOW")
    check(DWE.bubble and DWE.bubble:IsShown(), "back to an NPC: bubble again")
    M.FireEvent("GOSSIP_CLOSED")
    DialogueWheelE_BookStyle = "blizzard"
    M.FireEvent("ITEM_TEXT_BEGIN")
    M.FireEvent("ITEM_TEXT_READY")
    check(not DWE.choiceBox:IsShown(), "book style 'game window': addon stays out of the way")
    M.FireEvent("ITEM_TEXT_CLOSED")
    DialogueWheelE_BookStyle = nil
    -- Theme parchemin en bulle : le livre s'affiche en cadre, puis la bulle revient
    DialogueWheelE_Theme = "velin"
    M.FireEvent("ITEM_TEXT_BEGIN")
    M.FireEvent("ITEM_TEXT_READY")
    check(not DWE.bubble:IsShown() and DWE.textBox:IsShown(), "book with bubble-mode vellum: framed page")
    M.FireEvent("ITEM_TEXT_CLOSED")
    M.FireEvent("GOSSIP_SHOW")
    check(DWE.bubble:IsShown() and not DWE.textBox:IsShown(), "vellum NPC after a book: bubble again")
    M.FireEvent("GOSSIP_CLOSED")
    DialogueWheelE_Theme = "dark"
end

-- Livre laisse a DialogueUI : le lecteur Spoken garde l'habillage de DialogueUI pour ses pages
if withSpoken then
    DialogueWheelE_SpokenTheme = true
    DialogueWheelE_Theme = "velin"
    skin.clip = { present = { bullet = "book" } }
    DialogueWheelE_BookStyle = "dui"
    DWE.lastBookStyle = "dui"
    check(DWE.SpokenThemeOverride() == nil, "DUI book: Spoken player keeps DialogueUI's look")
    DWE.lastBookStyle = "blizzard"
    check(DWE.SpokenThemeOverride() ~= nil, "game window: Spoken player follows the addon theme")
    DialogueWheelE_BookStyle = nil
    DWE.lastBookStyle = nil
    check(DWE.SpokenThemeOverride() ~= nil, "addon books: Spoken player follows the addon theme")
    skin.clip = { present = {} }
    DialogueWheelE_BookStyle = "dui"
    check(DWE.SpokenThemeOverride() ~= nil, "NPC line: still the addon theme")
    skin.clip = nil
    DialogueWheelE_BookStyle = nil
    DialogueWheelE_SpokenTheme = nil
    DialogueWheelE_Theme = "dark"
end

-- Murmure : bulle et choix aux couleurs des chuchotements ; verre fume en bloc
do
    DialogueWheelE_Theme, DialogueWheelE_ShowText, DialogueWheelE_WheelTheme = "whisper", true, true
    DWE.OnThemeChanged()
    M.FireEvent("GOSSIP_SHOW")
    check(DWE.bubble:IsShown() and not DWE.textBox:IsShown(), "whisper: speech bubble")
    check(DWE.WheelPillStyle() == "whisper", "whisper: choice bubbles")
    M.FireEvent("GOSSIP_CLOSED")
    DialogueWheelE_Theme = "glass"
    DWE.OnThemeChanged()
    M.FireEvent("GOSSIP_SHOW")
    check(DWE.bubble:IsShown() and not DWE.textBox:IsShown(), "smoked glass: speech bubble by default")
    DialogueWheelE_ThemeFrames = true
    DWE.OnThemeChanged()
    check(DWE.textBox:IsShown() and not DWE.bubble:IsShown(), "smoked glass: popup with the frames option")
    DialogueWheelE_ThemeFrames = nil
    DWE.OnThemeChanged()
    check(DWE.bubble:IsShown() and not DWE.textBox:IsShown(), "smoked glass: back to bubble when option unchecked")
    -- La vraie case des options, cliquee pendant la conversation
    local cb = DWE.framesCheck
    check(cb ~= nil and cb:GetChecked() == true, "bubbles box checked by default")
    if cb then
        cb:SetChecked(false); cb._scripts.OnClick(cb)
        check(DWE.textBox:IsShown() and not DWE.bubble:IsShown(), "unchecking the bubbles box brings frames back")
        cb:SetChecked(true); cb._scripts.OnClick(cb)
        check(DWE.bubble:IsShown() and not DWE.textBox:IsShown(), "checking it again brings bubbles back")
    end
    M.FireEvent("GOSSIP_CLOSED")
    DialogueWheelE_Theme, DialogueWheelE_WheelTheme = "dark", false
    DWE.OnThemeChanged()
end

-- Options : une vignette par theme ; cliquer applique le theme
local tilesFound = {}
for _, fr in ipairs(M.frames) do
    if rawget(fr, "id") and fr._scripts.OnClick and rawget(fr, "label") then tilesFound[#tilesFound + 1] = fr end
end
check(#tilesFound == #DWE.THEME_LIST, "one preview tile per theme: " .. #tilesFound)
for _, t in ipairs(tilesFound) do
    t._scripts.OnClick(t)
    check(DialogueWheelE_Theme == t.id, "tile applies theme " .. t.id)
    check(t.label:GetText() and t.label:GetText() ~= "" and not t.label:GetText():find("^THEME_"), "tile has a proper name: " .. tostring(t.label:GetText()))
end
-- Themes enlumines avec la roue habillee et le popup
if withDUI then -- theme DialogueUI : la conversation est laissee a DialogueUI
    DialogueWheelE_Theme = "dui"
    M.FireEvent("GOSSIP_CLOSED")
    M.FireEvent("GOSSIP_SHOW")
    check(DWE.choiceBox:IsShown(), "DialogueUI theme: conversation choices go to the wheel")
    check(DWE.CurrentThemeId() == "transparent", "DialogueUI theme: frameless wheel")
    check(DWE.SpokenBaseTheme() == "dui_brown", "DialogueUI theme: the Spoken player keeps the DialogueUI parchment")
    check(not DWE.textBox:IsShown() and not DWE.TextWanted(), "DialogueUI theme: NPC text stays on the parchment")
    for _, o in ipairs(DWE.currentOptions) do
        check(not o.isDialogueToggle, "DialogueUI theme: no text toggle in the wheel")
    end
    M.FireEvent("GOSSIP_CLOSED")
    M.FireEvent("QUEST_DETAIL")
    check(DWE.choiceBox:IsShown() and not DWE.textBox:IsShown(), "DialogueUI theme: quest page choices go to the wheel, text stays on the parchment")
    check(DWE.objLine:GetText() == "" and DWE.rewLine:GetText() == "", "DialogueUI theme: no quest preview under the wheel (it is on the parchment)")
    M.FireEvent("QUEST_FINISHED")
    do -- recompenses au choix : dans la roue, "Terminer" se debloque une fois choisie
        local oldN = M.numChoices
        M.numChoices = 3
        DWE.selectedRewardIndex, DWE.rewardMemory = nil, nil
        local oldPad = DWE.GamePadOn
        DWE.GamePadOn = function() return false end
        M.FireEvent("QUEST_COMPLETE")
        local mouseOpts, mouseDone = 0, nil
        for _, o in ipairs(DWE.currentOptions) do
            mouseOpts = mouseOpts + 1
            if o.rewardIdx then mouseDone = "reward in wheel" end
        end
        check(mouseDone == nil and mouseOpts == 2, "DialogueUI theme, mouse: only complete + goodbye in the wheel, rewards on the parchment")
        M.FireEvent("QUEST_FINISHED")
        DWE.GamePadOn = function() return true end
        M.FireEvent("QUEST_COMPLETE")
        local picks, done = {}, nil
        for _, o in ipairs(DWE.currentOptions) do
            if o.rewardIdx then picks[#picks + 1] = o end
            if o.isCompleteBtn then done = o end
        end
        check(#picks == 3 and done and done.disabled, "DialogueUI theme: reward choices in the wheel, complete waits")
        picks[2].action()
        check(DWE.selectedRewardIndex == 2 and not done.disabled and picks[2].rawLabel:find("^> "), "DialogueUI theme: picking a reward in the wheel unlocks complete")
        M.FireEvent("QUEST_FINISHED")
        DWE.GamePadOn = oldPad
        M.numChoices = oldN
        DWE.selectedRewardIndex, DWE.rewardMemory = nil, nil
    end
    -- Boutons du parchemin : les choix sont caches et retires du clavier / de la manette.
    do
        local function Btn(t)
            local b = CreateFrame("Button"); b.type = t; b:Show(); return b
        end
        local g, aq, bye = Btn("gossip"), Btn("availableQuest"), Btn("goodbye")
        local exitB, acc = Btn("goodbye"), Btn("accept")
        local kc = CreateFrame("Frame")
        kc.actions = { Option1 = { obj = g }, Option2 = { obj = aq }, Exit = { obj = bye } }
        kc.SetParentFrame = function() end
        kc.combatFrame = CreateFrame("Frame")
        local q = CreateFrame("Frame")
        q.ExitButton = exitB
        q.AcceptButton = acc
        q.GetChildren = function() return kc end
        q.optionButtonPool = { ProcessActiveObjects = function(_, fn) fn(g); fn(aq); fn(bye) end }
        q.gamepadObjects = { g, aq, bye }
        q.gamepadMaxIndex = 3
        local oldKC = DWE.duiKC; DWE.duiKC = nil
        DWE.DUIStripOptions(q)
        check(not g:IsShown() and not aq:IsShown() and bye:IsShown(), "DialogueUI theme: parchment choices hidden, goodbye kept")
        check(kc.actions.Option1 == nil and kc.actions.Option2 == nil and kc.actions.Exit, "DialogueUI theme: hidden choices lose their keys")
        check(q.gamepadMaxIndex == 1 and q.gamepadObjects[1] == bye, "DialogueUI theme: gamepad only walks what is left")
        check(not exitB:IsShown(), "DialogueUI theme: parchment goodbye hidden (it is in the wheel)")
        check(not acc:IsShown(), "DialogueUI theme: parchment accept / complete hidden (it is in the wheel)")
        -- Fenetre DialogueUI cachee par transparence : traversable par la souris, puis rendue.
        local parent, child = CreateFrame("Frame"), CreateFrame("Button")
        for _, f in ipairs({ parent, child }) do
            f.dweM = true
            f.IsMouseEnabled = function(x) return x.dweM end
            f.EnableMouse = function(x, v) x.dweM = v end
        end
        parent.GetChildren = function() return child end
        DWE.CutMouse(parent, true)
        check(not parent.dweM and not child.dweM, "hidden DialogueUI frame lets the mouse through (children too)")
        DWE.CutMouse(parent, false)
        check(parent.dweM and child.dweM, "DialogueUI frame catches the mouse again once shown")
        -- Couleurs de Murmure : themes en bulle, images presentes, nom traduit.
        for id, c in pairs(DWE.WHISPER_COLORS) do
            check(DWE.ThemeIsBubble(id), id .. " is a bubble theme")
            for _, f in ipairs({ "Bubble" .. c.art, "Bubble" .. c.art .. "Tail", "Pill" .. c.art, "Pill" .. c.art .. "SelTailDownR", "Thumbs/" .. c.art }) do
                local h = io.open("../" .. f .. ".png", "rb")
                check(h ~= nil, id .. ": image " .. f)
                if h then h:close() end
            end
            check(DWE.L["THEME_" .. id:upper()] ~= nil, id .. ": translated name")
        end
        local oldT = DialogueWheelE_Theme
        DialogueWheelE_Theme = "emerald"; DWE.OnThemeChanged()
        M.FireEvent("GOSSIP_SHOW")
        check(DWE.choiceBox:IsShown(), "emerald theme: wheel opens")
        M.FireEvent("GOSSIP_CLOSED")
        DialogueWheelE_Theme = oldT; DWE.OnThemeChanged()
        -- Boutons de Spoken sur le parchemin : Share les pilote.
        if rawget(_G, "SpokenEnv") then
            local old = rawget(_G, "DUIQuestFrame")
            local dq = CreateFrame("Frame"); dq:Show()
            dq.IsVisible = function() return true end
            DUIQuestFrame = dq
            check(DWE.SpokenControlsShown(), "DialogueUI theme: Spoken buttons on the parchment count for Share")
            -- File de lecture : bouton a cote de Lecture / Passer du parchemin, liste au-dessus.
            local ui, env = DWE.SpokenQueueUI, SpokenEnv
            local oldSp, oldActions = rawget(_G, "Spoken"), env.Actions
            local oldRB = oldActions and oldActions.RoundButton
            env.Actions = env.Actions or {}
            env.Actions.RoundButton = function(parent)
                local rb = CreateFrame("Button", nil, parent)
                rb.glyph = rb:CreateTexture()
                return rb
            end
            local placed
            Spoken = { CreateDialogueUIRow = function(_, dialog)
                local row = { frame = CreateFrame("Frame", nil, dialog), play = CreateFrame("Button"), skip = CreateFrame("Button") }
                row.Place = function(_, list) placed = list end
                return row
            end }
            ui.duiQuestHooked = nil
            ui.HookDUIQuest()
            local row = Spoken:CreateDialogueUIRow(dq)
            row:Place({ row.skip, row.play })
            local qb = ui.buttons[row.frame]
            check(qb and placed and placed[3] == qb, "DialogueUI theme: queue button placed next to Spoken's parchment buttons")
            check(qb and qb.dweDUIBook, "DialogueUI theme: the queue list opens above the parchment buttons")
            ui.buttons[row.frame] = nil
            Spoken = oldSp
            env.Actions.RoundButton = oldRB
            env.Actions = oldActions
            DUIQuestFrame = old
        end
        DWE.duiKC = oldKC
    end
end
DialogueWheelE_Theme = "velin"
DialogueWheelE_WheelTheme = true
DialogueWheelE_ShowText = true
M.FireEvent("GOSSIP_SHOW")
for _, th in ipairs({ "velin", "arcane", "sylvan", "starry" }) do
    DialogueWheelE_Theme = th
    DialogueWheelE_ThemeFrames = true
    DWE.OnThemeChanged()
    check(DWE.textBox:IsShown(), "popup shown with theme " .. th)
    DialogueWheelE_ThemeFrames = nil
    DWE.OnThemeChanged()
    check(DWE.bubble:IsShown() and not DWE.textBox:IsShown(), "bubble shown with theme " .. th)
end
M.FireEvent("GOSSIP_CLOSED")
DialogueWheelE_WheelTheme = false
DialogueWheelE_Theme = "dark"

-- /dwe perf : attend le debut de l'ecriture puis mesure
do
    local said = {}
    local oldT = debugprofilestop
    debugprofilestop = function() return os.clock() * 1000 end
    DWE.ArmPerf(function(m) said[#said + 1] = m end)
    DWE.perfFrame._scripts.OnUpdate(DWE.perfFrame, 0.016)
    DialogueWheelE_Theme = "bubble"
    DialogueWheelE_ShowText = true
    M.FireEvent("GOSSIP_SHOW")
    check(said[1] and said[1]:find("8 s"), "perf starts when writing starts")
    for _ = 1, 600 do
        if DWE.perfFrame._scripts.OnUpdate then DWE.perfFrame._scripts.OnUpdate(DWE.perfFrame, 0.016) end
        DWE.bubble._scripts.OnUpdate(DWE.bubble, 0.016)
    end
    local all = table.concat(said, "\n")
    check(all:find("bulle") and all:find("images/s"), "perf report lists the bubble: " .. all)
    M.FireEvent("GOSSIP_CLOSED")
    debugprofilestop = oldT
    DialogueWheelE_Theme = "dark"
end

if os.getenv("TRACE") == "1" then
    local now = 5000
    GetTime = function() return now end
    Spoken = { GetNowPlaying = function() return nil end, IsPaused = function() return false end }
    DialogueWheelE_Theme = "bubble"; DialogueWheelE_ShowText = true
    M.FireEvent("GOSSIP_SHOW")
    local txt = "What what?!?  We all have profit to make... and we won't do it by standing idle. Get to work, you lazy goblins, the Venture Company never sleeps and neither do we! Go on now."
    DWE.SetDialogueText("Krazek", txt)
    local bt2 = DWE.bubble and select(1, (function() for _, r in ipairs(DWE.bubble._regions) do end end)())
    local last, gap, out = -1, 0, {}
    local fs
    for _, c in ipairs(DWE.bubble._children) do for _, r in ipairs(c._regions or {}) do if r.SetAlphaGradient and r._grad then fs = r end end end
    for i = 1, 60 * 16 do
        now = now + 1/60
        DWE.bubble._scripts.OnUpdate(DWE.bubble, 1/60)
        local g = (fs and fs._grad or 0) .. "|" .. tostring(fs and fs:GetText():sub(1,12))
        if g ~= last then out[#out+1] = string.format("%.2f:%s", i/60, g); last = g end
    end
    print(table.concat(out, " "))
    os.exit(0)
end
do -- livre de l'addon referme : le parchemin de DialogueUI reste cache pendant sa fermeture
    local book = rawget(_G, "DUIBookFrame")
    if book and withDUI then
        local oldGT = _G.GetTime; local t = 100
        _G.GetTime = function() return t end
        if DWE.HideWheel then DWE.HideWheel() end
        DWE.duiHoldUntil = 101.5
        book:Show(); book:SetAlpha(1)
        check(book:GetAlpha() == 0, "DialogueUI book kept hidden while it closes after a Storytale book")
        t = 102; DWE.RefreshHiddenFrames()
        DWE.duiHoldUntil = nil; _G.GetTime = oldGT
    end
end
do -- place par defaut des lecteurs de Spoken
    DWE.padUsed = false
    local layout = {}
    local oldEnv = rawget(_G, "SpokenEnv")
    local restored
    _G.SpokenEnv = setmetatable({ Addon = { Layout = function() return layout end,
        RestoreLayout = function(_, key) restored = key end } }, { __index = oldEnv })
    local H, W = UIParent:GetHeight() or 768, UIParent:GetWidth() or 1366
    if withDUI then
        local fr = CreateFrame("Frame", "SpokenDialogueUIPlayerFrame", UIParent)
        fr:SetWidth(360)
        DWE.SpokenPlayersPlace()
        local d = layout.DialogueUI
        check(d and d.dwe and math.abs(d.top - H * DWE.SPOKEN_DUI_POS.top) < 0.01
            and math.abs(d.left + 360 - (W - H * DWE.SPOKEN_DUI_POS.right)) < 0.01 and restored == "DialogueUI",
            "spoken DialogueUI player: default place on the right")
        layout.DialogueUI = { left = 5, top = 6 }
        DWE.SpokenPlayersPlace()
        check(layout.DialogueUI.left == 5, "spoken DialogueUI player: a place the player chose is kept")
        _G.SpokenDialogueUIPlayerFrame = nil
    else
        local fr = CreateFrame("Frame", "SpokenMinimalPlayerFrame", UIParent)
        local y
        fr.SetPoint = function(_, p, _, _, _, oy) y = oy end
        DWE.SpokenPlayersPlace()
        check(y and math.abs(y - H * DWE.SPOKEN_MINI_Y.kbm) < 0.01, "spoken mini player: keyboard default place")
        M.cvars.GamePadEnable = "1"; DWE.SpokenPlayersPlace()
        check(y and math.abs(y - H * DWE.SPOKEN_MINI_Y.kbm) < 0.01, "spoken mini player: gamepad mode on but keyboard in use")
        DWE.padUsed, DWE.padUsedAt = true, GetTime and GetTime() or 0; DWE.SpokenPlayersPlace()
        check(y and math.abs(y - H * DWE.SPOKEN_MINI_Y.pad) < 0.01, "spoken mini player: gamepad default place")
        M.cvars.GamePadEnable = nil; DWE.padUsed = false
        layout.Minimal = { left = 1, top = 2 }; y = nil; DWE.SpokenPlayersPlace()
        check(y == nil, "spoken mini player: a place the player chose is kept")
        _G.SpokenMinimalPlayerFrame = nil
    end
    _G.SpokenEnv = oldEnv
end
do -- livre de DialogueUI : la manette appuie sur ses propres boutons (l'icone suit)
    local clicked = {}
    local holder = CreateFrame("Frame", nil, UIParent)
    local play = CreateFrame("Button", nil, holder); play:SetScript("OnClick", function(_, m) clicked[#clicked + 1] = "play:" .. tostring(m) end)
    local skip = CreateFrame("Button", nil, holder); skip:SetScript("OnClick", function() clicked[#clicked + 1] = "skip" end)
    holder:Show(); play:Show(); skip:Show()
    local oldSR = rawget(_G, "SpokenReadables")
    _G.SpokenReadables = { DialogueUIBook = { row = { frame = holder, play = play, skip = skip } } }
    DWE.SpokenPadPress("play"); DWE.SpokenPadPress("skip")
    check(clicked[1] == "play:LeftButton" and clicked[2] == "skip", "gamepad presses DialogueUI book's own Play / Skip")
    _G.SpokenReadables = oldSR
end
do -- livre de DialogueUI (Spoken Readables) : bouton de file et manette sur ses boutons
    local env = rawget(_G, "SpokenEnv")
    local holder = CreateFrame("Frame", nil, UIParent)
    local clicks, placed = {}, nil
    local function Round(name)
        local b = CreateFrame("Button", nil, holder)
        b:SetScript("OnClick", function() clicks[#clicks + 1] = name end)
        return b
    end
    local row = { frame = holder, play = Round("play"), skip = Round("skip"), open = Round("open"),
        tooltip = function() return GameTooltip end }
    row.Place = function(_, list) placed = list end
    local view = CreateFrame("Frame", nil, UIParent)
    view.CloseButton = CreateFrame("Button", nil, view)
    local oldBook = rawget(_G, "DUIBookFrame")
    _G.DUIBookFrame = view
    local book = { row = row }
    book.Place = function() placed = "orig" end
    _G.SpokenReadables = { DialogueUIBook = book }
    local hadActions = env and env.Actions
    if env and hadActions then
        DWE.SpokenQueueUI.duiBookHooked = nil
        DWE.SpokenQueueUI.HookDUIBook()
        book:Place()
        local qb = DWE.SpokenQueueUI.buttons[holder]
        check(type(placed) == "table" and qb and placed[#placed - 1] == qb and placed[#placed] == row.open,
            "DialogueUI book: queue button where the Compendium was, Compendium on its left")
    end
    DWE.SpokenPadPress("play"); DWE.SpokenPadPress("skip")
    check(clicks[1] == "play" and clicks[2] == "skip", "DialogueUI book: Share uses its own Play / Skip (icon follows)")
    holder:Hide()
    _G.SpokenReadables = nil; _G.DUIBookFrame = oldBook
end
-- Spoken sans DialogueUI : sous-titres et petite fenetre au theme de Storytale, file d'attente.
if withSpoken then
    local hadEnv = rawget(_G, "SpokenEnv")
    _G.SpokenEnv = hadEnv or {}
    local env = SpokenEnv
    if DWE.choiceBox:IsShown() then M.FireEvent("GOSSIP_CLOSED") end
    -- Bouton de bascule bulle / lecteur Spoken, dans le coin de la roue (plus de choix dans la roue).
    if hadEnv and DWE.SpokenFocus and DWE.SpokenFocus.Available() then
        -- Cache par defaut (pas de bouton a l'installation), affiche une fois coche.
        DialogueWheelE_SpokenButton = nil
        M.FireEvent("GOSSIP_SHOW")
        check(not (DWE.spokenToggle and DWE.spokenToggle:IsShown()), "Spoken toggle button hidden by default")
        DialogueWheelE_SpokenButton = true
        M.FireEvent("GOSSIP_SHOW")
        local tb = DWE.spokenToggle
        check(tb and tb:IsShown(), "Spoken toggle button shown in the wheel's corner")
        for _, o in ipairs(DWE.currentOptions) do check(not o.isDialogueToggle, "no Spoken choice in the wheel any more") end
        local before = DialogueWheelE_ShowText == true
        tb._scripts.OnClick(tb)
        check((DialogueWheelE_ShowText == true) ~= before, "the button switches between the bubble and Spoken's player")
        tb._scripts.OnClick(tb)
        DialogueWheelE_SpokenButton = false
        M.FireEvent("GOSSIP_SHOW")
        check(not tb:IsShown(), "option off: no toggle button")
        DialogueWheelE_SpokenButton = nil
        M.FireEvent("GOSSIP_CLOSED")
    end
    local oldAddon, oldSub, oldMini, oldTr, oldActions = env.Addon, env.Subtitle, env.MinimalPlayer, env.Transcript, env.Actions
    local style = "subtitle"
    env.Addon = { db = {}, DisplayStyle = function() return style end,
        Profile = function() return { SubtitleShadow = 0.5 } end, Layout = function() return {} end }
    env.Actions = env.Actions or {}
    local oldRB = env.Actions.RoundButton
    env.Actions.RoundButton = function(parent)
        local rb = CreateFrame("Button", nil, parent)
        rb.glyph = rb:CreateTexture()
        return rb
    end
    -- Sous-titres (forme de Spoken 3.10 : Build, Layout, Update, Line, Corner).
    local sub = { lines = {} }
    function sub:Build()
        self.frame = CreateFrame("Frame", "SpokenSubtitleFrame", UIParent)
        self.controls = CreateFrame("Frame", nil, self.frame)
        self.pause = CreateFrame("Button", nil, self.controls)
        self.skip = CreateFrame("Button", nil, self.controls)
        self.shadow = self.frame:CreateTexture()
        self.controls:SetPoint("TOP", self.shadow, "BOTTOM", 0, -2)
        self.title = self.frame:CreateFontString()
        self.title:SetTextColor(1, .82, 0)
        for _, k in ipairs({ "dot", "label", "pausedLabel", "heldDot", "held", "moreDot", "more" }) do
            self[k] = self.frame:CreateFontString()
            self[k]:SetTextColor(.62, .62, .62)
        end
    end
    function sub:Line(index)
        local line = self.lines[index]
        if line then return line end
        line = self.frame:CreateFontString()
        line:SetTextColor(1, 1, 1)
        self.lines[index] = line
        return line
    end
    function sub:Layout() self:Line(1) end
    function sub:Update() self.shadow:SetAlpha(0.5) end
    function sub:Corner() self.controls:SetWidth(24 * 2 + 4) end
    env.Subtitle = sub
    -- Petite fenetre.
    local mini = {}
    function mini:Initialize()
        self.frame = CreateFrame("Frame", "SpokenMinimalPlayerFrame", UIParent)
        self.panel = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
        self.paper = self.panel:CreateTexture()
        self.name = self.frame:CreateFontString()
        self.title = { text = self.frame:CreateFontString() }
        self.stopped, self.count, self.held = self.frame:CreateFontString(), self.frame:CreateFontString(), self.frame:CreateFontString()
        self.content = CreateFrame("Frame", nil, self.frame)
        self.controls = CreateFrame("Frame", nil, self.content)
        self.portrait = CreateFrame("Frame", nil, self.frame)
        self.progress = { track = CreateFrame("Frame", nil, self.content) }
        self.frame:SetWidth(380)
    end
    function mini:Layout() self.laid = (self.laid or 0) + 1 end
    function mini:Dress() self.paper:SetAlpha(1); self.name:SetTextColor(1, .82, 0); self.dressed = (self.dressed or 0) + 1 end
    function mini:RefreshConfig() self:Dress() end
    env.MinimalPlayer = mini
    local trStyle
    local docked
    env.Transcript = { SetStyle = function(_, st) trStyle = st end, HeightForClip = function() return 40 end,
        Dock = function(_, parent, anchor, point, x, y, w, h) docked = { x = x, w = w } end }
    env.Addon.Profile = function() return { SubtitleShadow = 0.5, FrameScale = 0.7 } end
    local chosen
    env.Addon.PlayerStyle = function() return chosen or "subtitle" end
    env.Addon.SetPlayerStyle = function(_, st) chosen = st end

    local oldTheme, oldOpt = DialogueWheelE_Theme, DialogueWheelE_SpokenTheme
    DialogueWheelE_Theme, DialogueWheelE_SpokenTheme = "velin", true
    sub:Build(); mini:Initialize()
    DWE.HookSpokenStyles()
    sub.clip = { present = {} }
    check(DWE.SpokenCurClip() == sub.clip, "Spoken without DialogueUI: the subtitle's line is the one followed")
    sub:Layout(); sub:Update()
    local velin = DWE.THEME_STYLES.velin
    local want = string.format("%.2f,%.2f,%.2f", velin.hdr[1], velin.hdr[2], velin.hdr[3])
    check(sub.shadow:GetAlpha() == 0, "subtitles: Spoken's band hidden under the theme")
    check(sub.title._color == want, "subtitles: the name in the theme's colour")
    local body = string.format("%.2f,%.2f,%.2f", velin.body[1], velin.body[2], velin.body[3])
    check(sub.lines[1]._color == body, "subtitles: the words in the theme's colour")
    sub:Line(2)
    check(sub.lines[2]._color == body, "subtitles: a line made later takes the theme's colour too")
    sub.lines[1]:SetText("The |cffffd100Scourge|r grows")
    check(sub.lines[1]._text == "The " .. DWE.ThemeMark(velin) .. "Scourge|r grows", "subtitles: the read word in the theme's own colour: " .. tostring(sub.lines[1]._text) .. " vs " .. tostring(DWE.ThemeMark(velin)))
    local _, _, _, _, y = sub.controls:GetPoint(1)
    check(type(y) == "number" and y < -2, "subtitles: Spoken's buttons moved under the theme's frame")
    -- File d'attente : bouton en tete de la rangee des sous-titres.
    local ui = DWE.SpokenQueueUI
    ui.subHooked = nil
    ui.HookSubtitle()
    sub:Corner()
    local qb = ui.buttons[sub.controls]
    local p1, rel = sub.pause:GetPoint(1)
    check(qb ~= nil and qb.dweSubtitle and rel == qb, "subtitles: queue button before Stop / Skip")
    check(sub.controls:GetWidth() == 24 * 3 + 4 * 2, "subtitles: the button row widened for the queue button")
    local origShown = DWE.PlayerFrameShown
    DWE.PlayerFrameShown = function(f) return f == sub.frame end
    check(DWE.SpokenPlayerShown(), "subtitles count as Spoken's player on screen (gamepad Share)")
    DWE.PlayerFrameShown = origShown
    -- Theme sans cadre : le look de Spoken revient.
    DialogueWheelE_Theme = "transparent"; DWE.RefreshSpoken(); sub:Update()
    check(sub.shadow:GetAlpha() == 0 and sub.title._color == "1.00,0.82,0.00", "subtitles: frameless theme has a veil of its own")
    sub.lines[1]:SetText("The |cffffd100Scourge|r")
    check(sub.lines[1]._text == "The |cffffd100Scourge|r", "subtitles: gold kept where it is the theme's colour")
    -- Murmure en Emeraude : sa propre bulle, ses couleurs.
    DialogueWheelE_Theme = "emerald"; DWE.RefreshSpoken()
    local em = DWE.THEME_STYLES.spk_emerald
    check(em and sub.title._color == string.format("%.2f,%.2f,%.2f", em.hdr[1], em.hdr[2], em.hdr[3]), "subtitles: Emerald has its own look and colours")
    -- Habillage choisi a part.
    DialogueWheelE_SpokenSkin = "velin"; DWE.RefreshSpoken()
    check(sub.title._color == want, "Spoken look picked apart from the current theme")
    DialogueWheelE_SpokenSkin = "nope"
    check(DWE.SpokenSkinPick() == nil, "an unknown picked look falls back to the current theme")
    DialogueWheelE_SpokenSkin = nil; DWE.RefreshSpoken()
    -- Option coupee : rien de Storytale.
    DialogueWheelE_Theme, DialogueWheelE_SpokenTheme = "glass", false
    DWE.RefreshSpoken(); sub:Update()
    check(sub.shadow:GetAlpha() == 0.5 and sub.title._color == "1.00,0.82,0.00", "subtitles: option off keeps Spoken's look")
    -- Petite fenetre.
    style = "minimal"
    DialogueWheelE_Theme, DialogueWheelE_SpokenTheme = "parchment", true
    mini:RefreshConfig()
    local parch = DWE.THEME_STYLES.parchment
    check(mini.paper:GetAlpha() == 0, "small window: Spoken's paper hidden under the theme")
    check(mini.title.text._color == string.format("%.2f,%.2f,%.2f", parch.hdr[1], parch.hdr[2], parch.hdr[3]), "small window: title in the theme's colour")
    check(trStyle and trStyle.highlight == DWE.ThemeMark(parch) and trStyle.shadow == false
        and trStyle.color == parch.body, "small window: the theme's words and read-word colours")
    check(DWE.SpokenCardOn() and mini.frame:GetWidth() == DWE.SPOKEN_CARD.width, "small window: laid out as the DialogueUI-style card (its width)")
    check(math.abs((mini.frame._scale or 0) - 0.65) < 0.001, "small window: the card's scale (0.65 at Spoken's default size)")
    check(math.abs((mini.portrait._scale or 0) - DWE.SPOKEN_CARD.face / 90) < 0.001, "small window: small portrait at the top left")
    mini:Layout()
    check(docked and docked.w == DWE.SPOKEN_CARD.width - 52 - 2 * DWE.SPOKEN_CARD.wordsPad, "small window: words docked in the card's column")
    -- Sans DialogueUI, les sous-titres par defaut deviennent la carte, tant que le joueur n'a rien choisi.
    if not DWE.DUI_ON then
        DialogueWheelE_SpokenStyleChosen = nil
        check(env.Addon:PlayerStyle() == "minimal", "no DialogueUI: Spoken's default subtitles become the card")
        env.Addon:SetPlayerStyle("subtitle")
        check(DialogueWheelE_SpokenStyleChosen == true and env.Addon:PlayerStyle() == "subtitle", "a style chosen in Spoken is kept")
        DialogueWheelE_SpokenStyleChosen = nil
    end
    DialogueWheelE_SpokenTheme = false
    DWE.RefreshSpoken()
    check(mini.paper:GetAlpha() == 1 and mini.name._color == "1.00,0.82,0.00", "small window: option off gives Spoken's look back")
    check(not DWE.SpokenCardOn() and mini.portrait._scale == 1, "small window: option off gives Spoken's layout back")
    -- Remise en etat.
    ui.buttons[sub.controls] = nil
    DialogueWheelE_Theme, DialogueWheelE_SpokenTheme = oldTheme, oldOpt
    env.Actions.RoundButton = oldRB
    env.Addon, env.Subtitle, env.MinimalPlayer, env.Transcript, env.Actions = oldAddon, oldSub, oldMini, oldTr, oldActions
    _G.SpokenSubtitleFrame, _G.SpokenMinimalPlayerFrame = nil, nil
    if not hadEnv then _G.SpokenEnv = nil end
    DWE.OnThemeChanged()
end
-- Livres lus / commences
DialogueWheelE_ReadBooks = nil
DWE.MarkBook("The Old Tome (2/5)", false)
check(DWE.BookState("the old tome") == 1, "read books: started book remembered")
DWE.MarkBook("The Old Tome", true)
DWE.MarkBook("The Old Tome", false)
check(DWE.BookState("The Old Tome (1/5)") == 2, "read books: finished stays finished")
check(DWE.BookState("Another Book") == nil, "read books: unknown book has no mark")
DialogueWheelE_ReadBooks = nil
-- Manette : une fenetre du jeu en fondu d'ouverture (le butin) garde la manette ; une fenetre de
-- PNJ cachee par Storytale la rend au joueur.
do
    local released = 0
    local fcm = { isUIFocused = true }
    function fcm:GetActiveFrame() return self.active end
    function fcm:ReturnToPlayerControl() released = released + 1 end
    function fcm:FrameHidden() end
    function fcm:FrameShown() end
    local oldGM = rawget(_G, "GamepadMode")
    _G.GamepadMode = { FrameControlsManager = fcm }
    local loot = CreateFrame("Frame", "LootFrame", UIParent)
    loot:Show(); loot:SetAlpha(0.01)
    loot.GetEffectiveAlpha = function(self) return self:GetAlpha() end
    fcm.active = loot
    DWE.PadUnfocusHidden()
    check(released == 0, "gamepad: the loot window (fading in) keeps the gamepad")
    local gf = rawget(_G, "GossipFrame")
    if gf then
        gf.GetEffectiveAlpha = gf.GetEffectiveAlpha or function(self) return self:GetAlpha() end
        fcm.active = gf
        DWE.PadUnfocusHidden()
        check(released >= 1, "gamepad: the NPC window hidden by Storytale gives the gamepad back")
    end
    DWE.padEarly = nil
    _G.GamepadMode = oldGM
end
-- Icone de quete recopiee du jeu : sa decoupe (planche d'icones) suit, sinon pleine image.
do
    local t = UIParent:CreateTexture()
    DWE.SetOptionIcon(t, { icon = 123, iconCoords = { 0, 0, 0, 0.5, 0.5, 0, 0.5, 0.5 } })
    check(t._texture == 123 and t._texCoord and t._texCoord[4] == 0.5, "quest icon keeps its cut from an icon sheet")
    DWE.SetOptionIcon(t, { icon = 456 })
    check(t._texture == 456 and t._texCoord and t._texCoord[2] == 1, "plain icon resets the cut")
end
-- Quete qu'on vient d'accepter : le bouton du jeu pas encore remis a jour (icone "a prendre")
-- ne doit pas remplacer l'icone "en cours" de la roue.
do
    local gf = rawget(_G, "GossipFrame") or CreateFrame("Frame", "GossipFrame", UIParent)
    gf:Show()
    _G.GOSSIP_BUTTON_TYPE_ACTIVE_QUEST, _G.GOSSIP_BUTTON_TYPE_AVAILABLE_QUEST = 4, 5
    local btn = CreateFrame("Button", nil, gf)
    btn:Show()
    btn.Name = btn:CreateFontString(); btn.Name:SetText("Magics of the Drowned City")
    btn.Icon = btn:CreateTexture(); btn.Icon:SetTexture("STALE_BANG")
    local bt = 5
    btn.GetElementData = function() return { buttonType = bt, info = { questID = 7701 } } end
    local oldA, oldV = M.activeQuests, M.availQuests
    M.availQuests, M.activeQuests = {}, { { questID = 7701, title = "Magics of the Drowned City" } }
    DWE.currentOptions = {}
    M.FireEvent("GOSSIP_SHOW")
    M.RunTimers()
    local o
    for _, x in ipairs(DWE.currentOptions) do if x.qID == 7701 then o = x end end
    check(o and o.icon ~= "STALE_BANG", "accepted quest keeps its in-progress icon, not the stale one")
    bt = 4
    M.FireEvent("GOSSIP_SHOW")
    M.RunTimers()
    o = nil
    for _, x in ipairs(DWE.currentOptions) do if x.qID == 7701 then o = x end end
    check(o and o.icon == "STALE_BANG", "matching game button still lends its icon")
    btn:Hide()
    M.activeQuests, M.availQuests = oldA, oldV
    M.FireEvent("GOSSIP_CLOSED")
end
-- Apercu de quete : a peine assombri sur un fond clair, nettement sur un fond sombre.
do
    local oldT, oldW = DialogueWheelE_Theme, DialogueWheelE_WheelTheme
    DialogueWheelE_WheelTheme = true
    local pv = DWE.objLine and DWE.objLine.GetParent and DWE.choiceBox
    DWE.wheelBottom = DWE.objLine
    DialogueWheelE_Theme = "bubble_fantasy"; DWE.PaintWheelTheme()
    local light = DWE.previewShade
    DialogueWheelE_Theme = "bubble"; DWE.PaintWheelTheme()
    local dark = DWE.previewShade
    check(light == 0.88 and dark == 0.62, "quest preview shade: light " .. tostring(light) .. ", dark " .. tostring(dark))
    DialogueWheelE_Theme, DialogueWheelE_WheelTheme = oldT, oldW
    DWE.wheelBottom = DWE.choiceBox; DWE.PaintWheelTheme()
end
-- Mot lu par Spoken sur papier clair : une encre franche, distincte du texte.
for _, id in ipairs({ "parchment", "folio", "dui_brown", "velin", "arcane", "sylvan", "bookpaper", "Bronze", "Stone", "Marble", "Silver" }) do
    local cfg = DWE.THEME_STYLES[id] or (DWE.PLATES[id] and { hdr = DWE.PLATES[id].hdr, body = DWE.PLATES[id].body, shadow = 0 })
    local m = cfg and DWE.ThemeMark(cfg)
    local b = cfg and cfg.body
    local bh = b and string.format("|cff%02x%02x%02x", math.floor(b[1]*255+0.5), math.floor(b[2]*255+0.5), math.floor(b[3]*255+0.5))
    check(m and m ~= bh and m:find("^|cff") and tonumber(m:sub(5,6),16) + tonumber(m:sub(7,8),16) + tonumber(m:sub(9,10),16) > 140, "spoken highlight visible on " .. id .. ": " .. tostring(m))
end
-- Combat pendant la lecture d'une plaque : le texte est ferme, la fenetre du jeu ne surgit pas.
do
    local closed = 0
    local old = _G.CloseItemText
    _G.CloseItemText = function() closed = closed + 1 end
    DWE.bookMode = true
    M.FireEvent("PLAYER_REGEN_DISABLED")
    check(closed == 1, "combat closes an open book or plate")
    DWE.bookMode = false
    M.FireEvent("PLAYER_REGEN_DISABLED")
    check(closed == 1, "combat outside a book closes nothing")
    _G.CloseItemText = old
    M.FireEvent("PLAYER_REGEN_ENABLED")
end
-- Tablettes trolles : reconnues par les donnees de Spoken Readables, sur leur stele.
do
    local oldSR, oldPl = rawget(_G, "SpokenReadables"), rawget(_G, "SpokenReadablesPlaces")
    _G.SpokenReadablesPlaces = { books = { [58] = { type = "tablet", zones = { 1434 } }, [752] = { type = "tablet", zones = { 1411 } },
        [1091] = { type = "tablet", zones = { 1446 }, dungeons = { 209 } }, [20] = { type = "journal", zones = { 1434 } }, [289] = { type = "plaque", zones = { 1416, 1453 } }, [78] = { type = "plaque", zones = { 1420 }, dungeons = { 189 } }, [2676] = { type = "plaque", zones = { 1453 } } } }
    local onScreen = 1
    _G.SpokenReadables = { Data = function() return { pages = { [1] = { book = 58 }, [2] = { book = 752 }, [3] = { book = 1091 }, [4] = { book = 20 }, [5] = { book = 289 }, [6] = { book = 78 }, [7] = { book = 2676 } } } end,
        PageOnScreen = function() return onScreen end }
    check(DWE.TrollTablet(1) == "Troll" and DWE.TrollTablet(3) == "Troll" and DWE.TrollTablet(2) == "Tablet" and not DWE.TrollTablet(4), "troll tablets told apart from other tablets and books")
    local oldMat, oldMode = _G.ItemTextGetMaterial, DWE.bookMode
    _G.ItemTextGetMaterial = function() return "Parchment" end
    DWE.bookMode = true
    check(DWE.RawPlate() == "Troll", "an open troll tablet takes the troll stele")
    onScreen = 2
    check(DWE.RawPlate() == "Tablet", "another tablet takes the plain stele")
    onScreen = 5
    local oldMap = C_Map and C_Map.GetBestMapForUnit
    _G.C_Map = _G.C_Map or {}
    local here = 1416
    C_Map.GetBestMapForUnit = function() return here end
    check(DWE.RawPlate() == "Dalaran", "Khadgar's text read at Dalaran takes the round stone stele")
    check(DWE.TrollTablet(5) == "Dalaran", "Spoken's player knows the Dalaran stele too")
    here = 1453
    check(DWE.RawPlate() == "Bronze", "the same text read in Stormwind stays a bronze plaque")
    here = 1429
    check(DWE.RawPlate() == "Stone", "the same text elsewhere: stone")
    here = 1416
    onScreen = 6
    check(DWE.RawPlate() == "Stone", "another plaque the game calls parchment stays stone")
    onScreen = 7
    check(DWE.RawPlate() == "Stone", "a Stormwind plaque that is not a hero statue stays stone")
    _G.ItemTextGetMaterial = function() return "Bronze" end
    onScreen = 5
    check(DWE.RawPlate() == "Bronze", "a plaque the game calls bronze keeps its bronze")
    -- Storytale seul (sans Spoken Readables) : la stele de Khadgar d'apres son titre.
    do
        local sr, pl, item = _G.SpokenReadables, _G.SpokenReadablesPlaces, _G.ItemTextGetItem
        _G.SpokenReadables, _G.SpokenReadablesPlaces = nil, nil
        _G.ItemTextGetMaterial = function() return "Parchment" end
        _G.ItemTextGetItem = function() return "Archimage Khadgar" end
        here = 1416
        check(DWE.RawPlate() == "Dalaran", "standalone: Khadgar's text at Dalaran still takes the round stele")
        here = 1453
        check(DWE.RawPlate() ~= "Dalaran", "standalone: not the round stele in Stormwind")
        here = 1416
        _G.ItemTextGetItem = function() return "Some Letter" end
        check(DWE.RawPlate() ~= "Dalaran", "standalone: another text at Dalaran keeps its own look")
        _G.SpokenReadables, _G.SpokenReadablesPlaces, _G.ItemTextGetItem = sr, pl, item
    end
    C_Map.GetBestMapForUnit = oldMap
    _G.ItemTextGetMaterial, DWE.bookMode = oldMat, oldMode
    _G.SpokenReadables, _G.SpokenReadablesPlaces = oldSR, oldPl
    DWE.lastPlate = nil
    check(M.addonDir == nil or io.open(M.addonDir .. "/PlateTroll.png", "rb") ~= nil and io.open(M.addonDir .. "/PlateTrollS.png", "rb") ~= nil and io.open(M.addonDir .. "/PlateTablet.png", "rb") ~= nil and io.open(M.addonDir .. "/PlateDalaran.png", "rb") ~= nil and io.open(M.addonDir .. "/PlateDalaranS.png", "rb") ~= nil and io.open(M.addonDir .. "/PlateDalaranGlow.png", "rb") ~= nil, "troll stele textures shipped")
end
-- Texte HTML d'une tombe : seulement le texte.
do
    local out = DWE.PlainItemText('<HTML>\n<BODY>\n<H1 align="center">\nAnthony Ray Stark\n</H1>\n<H2 align="center">\n1961 - 2005\n</H2>\n</BODY>\n</HTML>')
    check(out == "Anthony Ray Stark\n1961 - 2005", "HTML item text shown as plain text: " .. tostring(out))
    check(DWE.PlainItemText("Plain <b> text") == "Plain <b> text", "non-HTML text untouched")
end
-- Tombes : un message de recueillement, pas "un recit".
do
    local oD, oP = rawget(_G, "SpokenReadablesData"), rawget(_G, "SpokenReadablesPlaces")
    _G.SpokenReadablesData = { index = { ["In Loving Memory"] = { [1] = { [111] = 900 } }, ["A Book"] = { [1] = { [222] = 901 } } },
        pages = { [900] = { book = 50 }, [901] = { book = 51 } } }
    _G.SpokenReadablesPlaces = { books = { [50] = { type = "grave" }, [51] = { type = "book" } } }
    check(DWE.IsGraveTitle("In Loving Memory") and not DWE.IsGraveTitle("A Book"), "graves told apart from books")
    check(DWE.L.GRAVE_READ and DWE.L.GRAVE_NEW and DWE.L.GRAVE_READ ~= DWE.L.BOOK_READ, "grave read marks have their own words")
    _G.SpokenReadablesData, _G.SpokenReadablesPlaces = oD, oP
end
-- Hommages : pas de mot surligne.
do
    local F = DWE.SpokenFocus
    local old = F and F.GroupKey
    if F then F.GroupKey = function(c) return c and c.k end end
    check(DWE.IsMemorialClip({ k = "book:In Loving Memory" }) and not DWE.IsMemorialClip({ k = "book:Uther the Lightbringer" }), "real-person memorials recognised")
    if F then F.GroupKey = old end
    local pl = DWE.THEME_STYLES and DWE.PLATES.Bronze and DWE.PLATE_MARK.Bronze
    check(pl == "|cff1f4a3a", "bronze keeps its green read mark")
    check(DWE.memorialPetals and (M.addonDir == nil or io.open(M.addonDir .. "/MemorialPetals.png", "rb") ~= nil), "memorial petals ready")
end
-- Aucun cadre cache n'ecoute la manette (la navigation manette du jeu se bloquait).
do
    local sense, cat, list = rawget(_G, "DWE_PadSense"), DWE.padCatcher, DWE.padList
    if sense and cat and cat.IsGamePadButtonEnabled then
        check(not sense:IsGamePadButtonEnabled(), "pad sense: never listens to gamepad buttons")
        check(cat:IsGamePadButtonEnabled() and list:IsGamePadButtonEnabled(), "conversation and queue pad frames listen (they only receive while shown)")
        DWE.padActive, DWE.padUsed, DWE.padUsedAt = true, true, -1000
        local oldOn = DWE.GamePadOn
        DWE.GamePadOn = function() return true end
        check(DWE.PadInUse(), "gamepad active per the game: in use without a recent press")
        DWE.GamePadOn = oldOn
        DWE.padActive, DWE.padUsed = nil, false
    end
end
-- Infobulle a la souris (livres) : un personnage ou un autre objet ensuite ne reste pas a la
-- souris, et l'infobulle n'a jamais deux ancres (etiree sur l'ecran).
if DWE.TipEvaluate and GameTooltip then
    local tt = GameTooltip
    local other = CreateFrame("Frame", "TipBoxTest", UIParent)
    tt:ClearAllPoints()
    tt:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 100, 100)
    tt:SetPoint("BOTTOMRIGHT", other, "BOTTOMRIGHT", 0, 0)
    tt.dweAtCursor, tt.dweCursorPoint = true, true
    local oldUnit = tt.GetUnit
    tt.GetUnit = function() return "Dalaran Conjuror", "npc" end
    DWE.TipEvaluate(tt)
    local p1, rel = tt:GetPoint(1)
    check(not tt.dweAtCursor and tt:GetNumPoints() == 1 and p1 == "BOTTOMRIGHT" and rel == other,
        "tooltip: a character after a book is no longer at the mouse, one anchor only")
    tt.GetUnit = oldUnit
    local oldUse = DWE.PadInUse
    DWE.PadInUse = function() return true end
    _G.GameTooltipTextLeft1 = _G.GameTooltipTextLeft1 or CreateFrame("Frame")
    local oldGT = GameTooltipTextLeft1.GetText
    DWE.MarkBook("Tooltip Test Stele", true)
    GameTooltipTextLeft1.GetText = function() return "Tooltip Test Stele" end
    DialogueWheelE_BookTipCursor = true
    tt.GetOwner = function() return UIParent end
    DWE.TipEvaluate(tt)
    check(tt.dweAtCursor == true and tt:GetNumPoints() == 1, "tooltip: a book's tooltip still follows the cursor (mouse or gamepad)")
    DialogueWheelE_BookTipCursor = nil
    GameTooltipTextLeft1.GetText = oldGT
    DWE.PadInUse = oldUse
end
-- Curseurs des options : boutons - et + (la navigation manette ne s'arrete que sur des boutons).
do
    local sl = rawget(_G, "DWESliderFont")
    if sl and sl.dwePlus then
        local before = sl:GetValue()
        sl.dwePlus._scripts.OnClick(sl.dwePlus)
        check(sl:GetValue() == math.min(22, before + 1), "options slider: + steps up")
        sl.dweMinus._scripts.OnClick(sl.dweMinus)
        check(sl:GetValue() == before, "options slider: - steps back")
    else
        check(false, "options slider has - and + buttons")
    end
end
-- Fenetre de livre du jeu cachee : les boutons de Spoken Readables posees dessus ne prennent
-- plus la souris (leur infobulle apparaissait a gauche de l'ecran).
do
    local itf = rawget(_G, "ItemTextFrame") or CreateFrame("Frame", "ItemTextFrame", UIParent)
    _G.ItemTextFrame = itf
    local oldSR = rawget(_G, "SpokenReadables")
    local btn = CreateFrame("Button", nil, itf)
    local refreshed = false
    _G.SpokenReadables = { playButton = btn, RefreshPlayButton = function() refreshed = true; btn:Show() end }
    btn:Show()
    DWE.HideExtras(itf, true)
    check(not btn:IsShown(), "hidden game book: Spoken Readables' Play button hidden (no gamepad focus, no tooltip)")
    DWE.HideExtras(itf, false)
    check(refreshed and btn:IsShown(), "game book shown again: Spoken Readables puts its button back")
    _G.SpokenReadables = oldSR
end
-- Options a la manette : droite va a l'option voisine sur la meme ligne, pas sur celle du dessous.
do
    local got = {}
    local oldSet, oldDirs, oldScroll = rawget(_G, "SmartNavigation_AddJumpNavigationOverride"), rawget(_G, "SMART_NAV_INPUT_DIRECTION"), rawget(_G, "DialogueWheelEOptionsScroll")
    _G.SMART_NAV_INPUT_DIRECTION = { LEFT = { dirKey = "left" }, RIGHT = { dirKey = "right" }, UP = { dirKey = "up" }, DOWN = { dirKey = "down" } }
    _G.SmartNavigation_AddJumpNavigationOverride = function(b, d, t) got[b] = got[b] or {}; got[b][d.dirKey] = t end
    local child = CreateFrame("Frame", nil, UIParent)
    local function Box(x, y) local c = CreateFrame("CheckButton", nil, child); c._cx, c._cy = x, y; c:SetSize(26, 26); return c end
    local a, b, below, belowRight = Box(100, 500), Box(400, 500), Box(100, 470), Box(250, 460)
    _G.DialogueWheelEOptionsScroll = { GetScrollChild = function() return child end }
    DWE.OptionsPadRows()
    check(got[a] and got[a].right == b, "options pad: right goes to the option on the same line")
    check(got[b] and got[b].left == a and got[b].right == true, "options pad: left back; nothing further right = stay")
    check(got[below] and got[below].right == true, "options pad: no same-line option on the right = stay, never drop to another line")
    check(got[a] and got[a].down == below and got[below] and got[below].up == a, "options pad: down/up go to the nearest option on the next/previous line")
    check(got[b] and got[b].down == below, "options pad: down from the right column lands on the line below, not further")
    _G.SmartNavigation_AddJumpNavigationOverride, _G.SMART_NAV_INPUT_DIRECTION, _G.DialogueWheelEOptionsScroll = oldSet, oldDirs, oldScroll
    child:Hide()
end
-- File de lecture : plusieurs salutations d'un meme PNJ, chacune sa ligne, reconnaissable.
if DWE.SpokenFocus and DWE.SpokenFocus.Groups then
    local F = DWE.SpokenFocus
    local env = rawget(_G, "SpokenEnv")
    local queue = type(env) == "table" and env.SoundQueue
    if queue then
        local old = queue.sounds
        queue.sounds = {
            { priority = "low", key = "g:a", present = { bullet = "gossip", header = "Deputy Willem", label = "Gossip", transcript = "Hello there, citizen. Watch yourself out there." } },
            { priority = "low", key = "g:b", present = { bullet = "gossip", header = "Deputy Willem", label = "Gossip", transcript = "Normally I'd be out on the road." } },
        }
        local g = F.Groups()
        check(#g == 2 and g[1].label ~= g[2].label and g[1].label:find("Hello there", 1, true) and g[2].label:find("Normally", 1, true),
            "queue: an NPC's different greetings each have their own, distinct line (" .. tostring(g[1] and g[1].label) .. ")")
        queue.sounds = old
    end
end
-- /storytale seul ouvre les options.
do
    local old, opened = DWE.OpenOptions, false
    DWE.OpenOptions = function() opened = true end
    SlashCmdList.DIALOGUEWHEELE("")
    check(opened, "/storytale opens the options")
    DWE.OpenOptions = old
end
-- Tablettes trolles hautes : les glyphes des cotes se repetent au lieu de s'etirer.
do
    local okR, n = DWE.NoteRepFrame(DWE.PLATES.Troll, 668, 950)
    check(okR == true and n == 10, "troll tablet: side glyphs repeated, not stretched (" .. tostring(n) .. ")")
    local okT = DWE.NoteRepFrame(DWE.PLATES.Tablet, 668, 420)
    check(okT == true, "plain tablet uses the same repeated frame")
    check(DWE.NoteRepFrame(DWE.PLATES.Stone, 668, 950) == false, "other plates keep their single stretched frame")
end
-- Manette : la surbrillance de l'objet 3D vise reste allumee tant que Storytale tient la vue libre.
do
    local state
    local oldGP = rawget(_G, "C_GamePad")
    _G.C_GamePad = { SetAllowHoverEventsWithFreeLook = function(v) state = v end }
    DWE.PadHoverHold(true)
    check(state == true, "pad: 3D hover kept on while the camera is held")
    local oldGM = rawget(_G, "GamepadMode")
    _G.GamepadMode = { FrameControlsManager = { isUIFocused = true } }
    DWE.PadHoverHold(false)
    check(state == false and not DWE.padHoverHeld, "pad: hover handed back to the game's own choice on release")
    state = "untouched"
    DWE.PadHoverHold(false)
    check(state == "untouched", "pad: hover left alone when Storytale never held it")
    _G.C_GamePad, _G.GamepadMode = oldGP, oldGM
end
-- Profils d'options.
do
    local saveP, saveTheme, saveRead, saveFS = DialogueWheelE_Profiles, DialogueWheelE_Theme, DialogueWheelE_ReadBooks, DialogueWheelE_FontSize
    DialogueWheelE_Profiles = nil
    DialogueWheelE_Theme, DialogueWheelE_FontSize = "parchment", 15
    DialogueWheelE_ReadBooks = { ["x"] = true }
    local saveDV = DialogueWheelE_DefaultsV
    DialogueWheelE_DefaultsV = 6
    check(DWE.ProfileLoad() == "Default" and DialogueWheelE_Theme == "parchment", "profiles: existing settings become the Default profile")
    check(DWE.ProfileCreate("Alt", false, true) and DWE.profile == "Alt" and DialogueWheelE_Theme == nil and DialogueWheelE_FontSize == nil,
        "profiles: a new profile starts from the defaults")
    check(DialogueWheelE_ReadBooks and DialogueWheelE_ReadBooks.x, "profiles: read books are not part of a profile")
    check(DialogueWheelE_DefaultsV == nil, "profiles: a new profile gets the first-install defaults too")
    DialogueWheelE_Theme = "folio"
    check(DWE.ProfileSwitch("Default", true) and DialogueWheelE_Theme == "parchment" and DialogueWheelE_FontSize == 15 and DialogueWheelE_DefaultsV == 6, "profiles: switching back restores that profile's options")
    check(DialogueWheelE_Profiles.sets.Alt.Theme == "folio", "profiles: leaving a profile keeps its changes")
    check(DWE.ProfileCreate("Copy", true, true) and DialogueWheelE_Theme == "parchment", "profiles: a copy keeps the current options")
    check(not DWE.ProfileCreate("Copy", true, true) and not DWE.ProfileCreate("  ", false, true) and not DWE.ProfileCreate("Default", false, true), "profiles: empty or taken names refused")
    check(DWE.ProfileSetForNew("Copy") and DialogueWheelE_Profiles.newChar == "Copy" and DWE.ProfileNewCharName() == "Copy", "profiles: profile for new characters")
    DialogueWheelE_Profiles.sets.Copy.Theme = "frameless"
    DialogueWheelE_Profiles.chars = {}
    DWE.profile = nil
    check(DWE.ProfileLoad() == "Copy" and DialogueWheelE_Theme == "frameless", "profiles: a new character gets the chosen profile")
    check(DWE.ProfileDelete("Copy", true) and DWE.profile == "Default" and DialogueWheelE_Theme == "parchment" and DialogueWheelE_Profiles.newChar == nil,
        "profiles: deleting the current profile goes back to Default")
    check(not DWE.ProfileDelete("Default", true), "profiles: Default can't be deleted")
    local l = DWE.ProfileList()
    check(l[1] == "Default" and l[2] == "Alt" and #l == 2, "profiles: list starts with Main")
    check(DWE.ProfileNewCharName() == "Default", "profiles: new characters back on Main after their profile is deleted")
    -- Copier les reglages d'un autre profil dans celui en cours.
    check(DWE.ProfileCopyFrom("Alt", true) and DialogueWheelE_Theme == "folio" and DialogueWheelE_Profiles.sets.Default.Theme == "folio",
        "profiles: copy settings from another profile")
    check(not DWE.ProfileCopyFrom("Default", true), "profiles: no copy from itself")
    -- 1.7.0 : un personnage reste sur l'ancien profil fixe "Par defaut" -> son profil d'avant.
    DialogueWheelE_Profiles.chars = { ["x"] = "Factory" }
    DialogueWheelE_Profiles.back = "Alt"
    check(DialogueWheelE_Profiles.back == "Alt", "profiles: old Defaults profile set up")
    DWE.ProfileSwitch("Alt", true)
    DWE.ProfileSave()
    DialogueWheelE_Profiles, DialogueWheelE_Theme, DialogueWheelE_ReadBooks, DialogueWheelE_FontSize = saveP, saveTheme, saveRead, saveFS
    DialogueWheelE_DefaultsV = saveDV
    DWE.profile = nil
    DWE.ProfileLoad()
end
-- Sans Spoken : textes graves reconnus a leur titre, seulement si le jeu dit "parchemin".
do
    local oldGet, oldSR = ItemTextGetItem, rawget(_G, "SpokenReadables")
    _G.SpokenReadables = nil
    ItemTextGetItem = function() return "Pteradon Skeleton" end
    check(DWE.OpenTrollTablet() == "Tablet", "standalone: Ironforge exhibit gets its tablet")
    ItemTextGetItem = function() return "Tombe d'Eliza" end
    check(DWE.OpenTrollTablet() == "Stone", "standalone: tombstones recognized in other languages")
    ItemTextGetItem = function() return "Les empires jumeaux" end
    check(DWE.OpenTrollTablet() == "Troll", "standalone: troll stele recognized by its title")
    ItemTextGetItem = function() return "The Seven Kingdoms" end
    check(DWE.OpenTrollTablet() == false, "standalone: books stay books")
    ItemTextGetItem, _G.SpokenReadables = oldGet, oldSR
end
-- "Par defaut" d'une page : seulement ses reglages, avec les valeurs d'une installation.
do
    local saveFS, saveTh, saveEsc, saveWT = DialogueWheelE_FontSize, DialogueWheelE_Theme, DialogueWheelE_EscClose, DialogueWheelE_WheelTheme
    DialogueWheelE_FontSize, DialogueWheelE_Theme, DialogueWheelE_EscClose, DialogueWheelE_WheelTheme = 18, "folio", false, false
    DWE.ResetPage(DWE.optionPages[1].vars, true)
    check(DialogueWheelE_FontSize == 14 and DialogueWheelE_Theme == nil and DialogueWheelE_WheelTheme == true, "page defaults: appearance reset to install values")
    check(DialogueWheelE_EscClose == false, "page defaults: other pages untouched")
    check(DWE.optionPages[1].defaults ~= nil and DWE.optionPages[6].defaults == nil, "Defaults button on each page but Profiles")
    DialogueWheelE_FontSize, DialogueWheelE_Theme, DialogueWheelE_EscClose, DialogueWheelE_WheelTheme = saveFS, saveTh, saveEsc, saveWT
end
-- Profil change ou page remise a zero : les options se relisent, sans recharger l'interface.
do
    local function FindCheck(label)
        for _, pg in ipairs(DWE.optionPages or {}) do
            local function Walk(f)
                for _, c in ipairs({ f:GetChildren() }) do
                    if type(c.Text) == "table" and c.Text.GetText and c.Text:GetText() == label then return c end
                    local r = Walk(c); if r then return r end
                end
            end
            local r = Walk(pg.child); if r then return r end
        end
    end
    local esc = FindCheck(DWE.L.ESC_CLOSE)
    local saveEsc, saveFS = DialogueWheelE_EscClose, DialogueWheelE_FontSize
    local reloaded = false
    local oldReload = _G.ReloadUI
    _G.ReloadUI = function() reloaded = true end
    DialogueWheelE_EscClose = false
    DialogueWheelE_FontSize = 19
    DWE.SettingsChanged()
    check(esc and esc:GetChecked() == false, "live settings: checkbox follows the new value")
    check(_G.DWESliderFont and math.abs((_G.DWESliderFont:GetValue() or 0) - 19) < 0.01, "live settings: slider follows the new value")
    DWE.ResetPage(DWE.optionPages[4].vars)
    check(esc and esc:GetChecked() == true and DialogueWheelE_EscClose ~= false, "page defaults applied at once")
    check(not reloaded, "no interface reload")
    _G.ReloadUI = oldReload
    DialogueWheelE_EscClose, DialogueWheelE_FontSize = saveEsc, saveFS
    DWE.SettingsChanged()
end
-- Cadre de texte sans place (place fixe rendue sans position enregistree) : il en reprend une,
-- sinon la bulle posee dessus n'avait plus de position et disparaissait.
do
    DWE.textBox:ClearAllPoints()
    DWE.EnsureTextPlaced()
    check(DWE.textBox:GetNumPoints() > 0, "text frame always gets a place back (bubble never left without a position)")
end
for t in pairs(M.missingTextures) do check(false, "missing texture file: " .. t) end
print(string.format("[%s DUI=%s Spoken=%s] %d checks, %d failed, %d runtime errors", locale, tostring(withDUI), tostring(withSpoken), checks, failed, #M.errors))
for _, e in ipairs(M.errors) do print("  ERROR: " .. e) end
os.exit((failed == 0 and #M.errors == 0) and 0 or 1)
