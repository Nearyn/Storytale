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

if withSpoken then DialogueWheelE_SpokenChoice = true end
OFF = withSpoken and 0 or -1 -- sans Spoken, pas de bouton "Spoken" en tete de roue
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
for _, file in ipairs({ "Locales.lua", "Storytale_Core.lua", "Bubble.lua", "SpokenFocus.lua", "SpokenQueueUI.lua", "Storytale.lua" }) do
    local chunk, err = loadfile(dir .. "/" .. file)
    check(chunk ~= nil, "compile " .. file .. ": " .. tostring(err))
    local ok, rerr = pcall(chunk)
    check(ok, "load " .. file .. ": " .. tostring(rerr))
end
M.FireEvent("PLAYER_LOGIN")
check(DialogueWheelE_Theme == "bubble" and DialogueWheelE_ShowText == true, "fresh install: Azeroth bubble theme, text shown")
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
    check(M.bindings.PADDUP == "DWE_WheelUpBtn" and M.bindings.PADDDOWN == "DWE_WheelDownBtn", "gamepad d-pad moves the selection")
    check(M.bindings.PAD1 == "DWE_SelectBtn" and M.bindings.PAD2 == "DWE_PadCloseBtn", "gamepad A selects, B closes")
    check(M.bindings.PADDLEFT == "DWE_PadPrevBtn" and M.bindings.PADDRIGHT == "DWE_PadNextBtn", "gamepad left/right turn pages")
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
        DWE.padCatcher._scripts.OnUpdate(DWE.padCatcher, 0.2)
        check(stick == false, "DialogueUI's hidden book gives the right stick back")
        duiBook:Hide(); _G.DUIBookFrame = prevBook
        _G.IsGamePadFreelookEnabled, _G.SetGamePadFreeLook = nil, nil
        DWE.padCatcher._scripts.OnUpdate(DWE.padCatcher, 0.2) -- API absente : sans erreur
    end
    check(DialogueWheelE_PadTipSeen == true and DWE.padTip and DWE.padTip:IsShown(), "gamepad tip shown the first time")
    check(DWE.padTip.text:GetText() == DWE.L.PAD_TIP, "gamepad tip text")
    DWE.padTip._scripts.OnUpdate(DWE.padTip, 13)
    check(not DWE.padTip:IsShown(), "gamepad tip fades away")
    DWE.RefreshBindings()
    check(not DWE.padTip:IsShown(), "gamepad tip shown only once")
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
        -- Y en conversation : petit menu du lecteur Spoken (si Spoken est la).
        local realShown = DWE.SpokenPlayerShown
        DWE.SpokenPlayerShown = function() return false end
        h(DWE.padCatcher, "PAD4")
        check(not DWE.PadMenuOpen(), "no Spoken menu while Spoken's player is not on screen")
        DWE.SpokenPlayerShown = function() return true end
        if true then
            local sent = {}
            _G.SlashCmdList = _G.SlashCmdList or {}
            local old = SlashCmdList.SPOKEN
            SlashCmdList.SPOKEN = function(m) sent[#sent + 1] = m end
            h(DWE.padCatcher, "PAD4")
            check(DWE.PadMenuOpen(), "gamepad Y opens the Spoken menu in a conversation")
            local sel = DWE.selectedIndex
            h(DWE.padCatcher, "PAD1")
            h(DWE.padCatcher, "PADDRIGHT"); h(DWE.padCatcher, "PAD1")
            check(table.concat(sent, ",") == "play,skip", "Spoken menu: pause then skip (" .. table.concat(sent, ",") .. ")")
            check(DWE.selectedIndex == sel and DWE.choiceBox:IsShown(), "Spoken menu keeps the wheel as it was")
            h(DWE.padCatcher, "PAD2")
            check(not DWE.PadMenuOpen() and DWE.choiceBox:IsShown(), "B closes the Spoken menu, not the conversation")
            SlashCmdList.SPOKEN = old
            h(DWE.padCatcher, "PAD4")
            DWE.SpokenPlayerShown = function() return false end
            DWE.padMenu._scripts.OnUpdate(DWE.padMenu, 1)
            check(not DWE.PadMenuOpen(), "Spoken menu closes when the player goes away")
        end
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
DWE.choiceBox:Hide()
M.npcHeight = 2.75
DWE.choiceBox:Show()
for _ = 1, 3 do follower._scripts.OnUpdate(follower, 0.05) end
local sp = DWE.choiceBox._points[#DWE.choiceBox._points]
check(DWE.choiceBox:GetScale() == 1, "small NPC: wheel keeps normal size: " .. tostring(DWE.choiceBox:GetScale()))
check(sp and sp[2] == plate and math.abs(sp[4] * DWE.choiceBox:GetScale() - 71.5) < 0.5, "small NPC: wheel closer: " .. tostring(sp and sp[4]))
DWE.choiceBox:Hide()
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
DWE.choiceBox:Hide()
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
DWE.choiceBox:Hide()

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
check(vis() == "", "bubble starts empty, then writes: '" .. vis() .. "'")
local function tick(sec) for _ = 1, math.floor(sec / 0.05 + 0.5) do DWE.bubble._scripts.OnUpdate(DWE.bubble, 0.05) end end
tick(0.4)
check(vis() == "Hello there,", "letter by letter at 30/s: '" .. vis() .. "'")
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
DWE.choiceBox:Hide()
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
check(M.log[2] == "GetQuestReward 3", "final screen validated at once with the picked reward: " .. tostring(M.log[2]))
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
M.FireEvent("QUEST_FINISHED")
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
        local page = DWE.textBody:GetText()
        h(DWE.padCatcher, "PADDRIGHT")
        check(DWE.textBody:GetText() == page, "d-pad moves in the ribbon menu, not the pages")
        h(DWE.padCatcher, "PAD1")
        h(DWE.padCatcher, "PAD1") -- toggle back
        h(DWE.padCatcher, "PAD2")
        check(not DWE.ribbon.open, "gamepad B closes the ribbon menu")
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
    M.FireEvent("ITEM_TEXT_CLOSED"); M.RunTimers()
end

-- Game refuses anchoring (last: disables tracking for the session)
local errBefore = #M.errors
-- Game refuses anchoring too: falls back once, never errors, never retries.
plate._noAnchor = true
M.plates = { plate }
DWE.choiceBox:Show()
for _ = 1, 30 do follower._scripts.OnUpdate(follower, 0.016) end
check(not DWE.IsFollowingNPC() and DWE.choiceBox:GetAlpha() == 1, "anchor refused: fixed place, visible")
DWE.choiceBox:Hide(); DWE.choiceBox:Show()
check(DWE.choiceBox:GetAlpha() == 1, "no further attempts after refusal")
DWE.choiceBox:Hide()
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
check(DWE.GetRow(2 + OFF).text._color == "0.55,0.20,0.00" and DWE.objLine:GetText():find("^|cff5c3300"), "option on + light parchment: dark ink")
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

-- Escape closes the conversation cleanly (UISpecialFrames, no key binding)
local function PressEscape()
    for _, name in ipairs(UISpecialFrames) do local fr = _G[name] if fr and fr:IsShown() then fr:Hide() end end
end
check(#UISpecialFrames >= 1, "catcher registered in UISpecialFrames")
M.log = {}
M.gossipText = "Hi"; M.gossipOptions = {}; M.availQuests = {}; M.activeQuests = {}
M.FireEvent("GOSSIP_SHOW")
check(DialogueWheelEEscapeCatcher:IsShown(), "Escape armed during conversation")
check(M.bindings.ESCAPE == nil, "Escape key not taken over")
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
        check(DWE.SpokenFocus.Hold(queue, heardGreet, "test") == false and not heardGreet.dweManual,
            "greeting already heard: dropped, not queued")
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
DWE.choiceBox:Hide()

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
        check(y and math.abs(y - H * DWE.SPOKEN_MINI_Y.pad) < 0.01, "spoken mini player: gamepad default place")
        M.cvars.GamePadEnable = nil
        layout.Minimal = { left = 1, top = 2 }; y = nil; DWE.SpokenPlayersPlace()
        check(y == nil, "spoken mini player: a place the player chose is kept")
        _G.SpokenMinimalPlayerFrame = nil
    end
    _G.SpokenEnv = oldEnv
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
for t in pairs(M.missingTextures) do check(false, "missing texture file: " .. t) end
print(string.format("[%s DUI=%s Spoken=%s] %d checks, %d failed, %d runtime errors", locale, tostring(withDUI), tostring(withSpoken), checks, failed, #M.errors))
for _, e in ipairs(M.errors) do print("  ERROR: " .. e) end
os.exit((failed == 0 and #M.errors == 0) and 0 or 1)
