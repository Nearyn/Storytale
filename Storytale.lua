-- Storytale - Storytale.lua
-- Logique : evenements PNJ / quetes / livres, construction des choix de la roue, apercu
-- des quetes, raccourcis clavier et compatibilite DialogueUI.

local L = DWE.L
local f = CreateFrame("Frame")
for _, event in ipairs({
    "PLAYER_LOGIN", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "GOSSIP_SHOW", "GOSSIP_CLOSED",
    "QUEST_GREETING", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_FINISHED",
    "ITEM_TEXT_BEGIN", "ITEM_TEXT_READY", "ITEM_TEXT_CLOSED",
    "GET_ITEM_INFO_RECEIVED", "MODIFIER_STATE_CHANGED",
}) do
    f:RegisterEvent(event)
end

local function NotSecret(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

local function NonEmpty(v)
    v = NotSecret(v)
    return (v ~= nil and v ~= "") and v or nil
end

--------------------------------------------------------------------------------
-- Compatibilite DialogueUI
--------------------------------------------------------------------------------
-- DialogueUI ouvre sa propre fenetre de quete pour les PNJ. La roue la remplace : on coupe
-- l'ecoute des evenements PNJ/quetes de DialogueUI, et seulement la sienne. Son module
-- livres reste actif (c'est le grand parchemin que l'on bascule avec "Dialogue").

local function IsAddOnLoadedCompat(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then return C_AddOns.IsAddOnLoaded(name) end
    return IsAddOnLoaded and IsAddOnLoaded(name)
end

-- Le cadre d'evenements de DialogueUI (Code/Core.lua) se reconnait a ses methodes.
local function IsDialogueUIListener(frm)
    return type(frm.ListenEvents) == "function"
        and type(frm.ThrottleGossipEvent) == "function"
        and type(frm.NegateLastEvent) == "function"
end

-- L'assombrissement d'ecran partage de DialogueUI (Code/Dialogue/DialogueUI.lua).
local function IsDialogueUIVignette(frm)
    return type(frm.owners) == "table" and type(frm.TryShow) == "function" and type(frm.AddOwner) == "function"
end

local function SetupDialogueUI()
    if not IsAddOnLoadedCompat("DialogueUI") then return end

    -- DialogueUI peut cacher toute l'interface du jeu pendant les dialogues, la roue avec.
    -- Ce reglage doit rester desactive pour que la roue soit visible.
    if type(DialogueUI_DB) == "table" then DialogueUI_DB.HideUI = false end

    local frm = EnumerateFrames()
    while frm do
        if frm ~= f and not (frm.IsForbidden and frm:IsForbidden()) and not frm:GetName() then
            local okL, isListener = pcall(IsDialogueUIListener, frm)
            local okV, isVignette = pcall(IsDialogueUIVignette, frm)
            if okL and isListener then
                frm:ListenEvents(false)
                -- DialogueUI le reactive en changeant de zone : on le recoupe aussitot.
                hooksecurefunc(frm, "ListenEvents", function(self, state)
                    if state then self:ListenEvents(false) end
                end)
            elseif okV and isVignette then
                hooksecurefunc(frm, "Show", function(s)
                    if DialogueWheelE_ShowText == true then s:Hide() end
                end)
            end
        end
        frm = EnumerateFrames(frm)
    end
end

--------------------------------------------------------------------------------
-- Icones
--------------------------------------------------------------------------------

local GOSSIP_ICON_PATH = "Interface\\GossipFrame\\"
local GOSSIP_ICONS = {
    gossip = "GossipGossipIcon", vendor = "VendorGossipIcon", taxi = "TaxiGossipIcon",
    trainer = "TrainerGossipIcon", battlemaster = "BattleMasterGossipIcon", binder = "BinderGossipIcon",
    healer = "HealerGossipIcon", tabard = "TabardGossipIcon", petition = "PetitionGossipIcon",
    banker = "BankerGossipIcon", auctioneer = "AuctioneerGossipIcon", repair = "RepairNPCGossipIcon",
    unlearn = "UnlearnGossipIcon", workorder = "WorkOrderGossipIcon", barber = "BarberGossipIcon",
    transmogrify = "TransmogrifyGossipIcon",
}
for k, v in pairs(GOSSIP_ICONS) do GOSSIP_ICONS[k] = GOSSIP_ICON_PATH .. v end

local ICON_QUEST_AVAIL = GOSSIP_ICON_PATH .. "AvailableQuestIcon"
local ICON_QUEST_REPEATABLE = GOSSIP_ICON_PATH .. "DailyActiveQuestIcon"
local ICON_QUEST_DAILY = GOSSIP_ICON_PATH .. "DailyQuestIcon"
local ICON_QUEST_ACTIVE = GOSSIP_ICON_PATH .. "ActiveQuestIcon"
local ICON_QUEST_INCOMPLETE = GOSSIP_ICON_PATH .. "IncompleteQuestIcon"
local ICON_NEXT_PAGE = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up"
local ICON_PREV_PAGE = "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up"
local ICON_GOODBYE = "Interface\\Buttons\\UI-GroupLoot-Pass-Up"

-- Icone d'une option de dialogue : ID de texture, chemin, ou nom de type ("vendor"...).
local function GetGossipIcon(iconData)
    if type(iconData) == "number" then return iconData end
    if type(iconData) == "string" then
        if iconData:find("[\\/]") then return iconData end
        local known = GOSSIP_ICONS[iconData:lower()]
        if known then return known end
    end
    return GOSSIP_ICONS.gossip
end

-- Recopie les icones de quete de la fenetre Blizzard quand elle existe (sans DialogueUI,
-- d'autres addons comme Questie peuvent y mettre leurs propres icones).
local function ScanFrameForQuestIcons(frame, found, depth)
    if not frame or depth > 6 or (frame.IsShown and not frame:IsShown()) then return end
    local label = (frame.Name and frame.Name.GetText and frame.Name) or (frame.GetText and frame)
    if frame.Icon and frame.Icon.GetTexture and label then
        local txt, tex = NotSecret(label:GetText()), frame.Icon:GetTexture()
        if txt and tex then
            found[txt:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")] = tex
        end
    end
    if frame.GetChildren then
        for _, child in ipairs({ frame:GetChildren() }) do
            ScanFrameForQuestIcons(child, found, depth + 1)
        end
    end
end

local function SyncIconsFromGossipFrame()
    if not GossipFrame then return end
    local found = {}
    ScanFrameForQuestIcons(GossipFrame, found, 0)
    local updated = false
    for _, opt in ipairs(DWE.currentOptions) do
        local tex = opt.isQuest and found[opt.rawLabel]
        if tex and opt.icon ~= tex then
            opt.icon = tex
            updated = true
        end
    end
    if updated then DWE.UpdateVisuals() end
end

--------------------------------------------------------------------------------
-- Quetes : outils
--------------------------------------------------------------------------------

-- Quetes de la Foire de Sombrelune : tickets et reputation (absents des donnees de quete).
local DARKMOON_QUEST_DATA = {}
for _, row in ipairs({
    { 7894, 1 }, { 7895, 4 }, { 7896, 8 }, { 7897, 12 }, { 7898, 20 },
    { 7889, 1 }, { 7890, 4 }, { 7891, 8 }, { 7892, 12 }, { 7893, 20 },
    { 7899, 1 }, { 7900, 4 }, { 7901, 8 }, { 7902, 12 }, { 7903, 20 },
    { 7881, 1 }, { 7882, 4 }, { 7883, 8 }, { 7884, 12 }, { 7885, 20 },
    { 8222, 20 },
}) do
    DARKMOON_QUEST_DATA[row[1]] = { tickets = row[2], rep = 100 }
end

local function IsKnownRepeatable(q)
    if not q then return false end
    if q.repeatable or q.isRepeatable then return true end
    if q.frequency and q.frequency > 0 then return true end
    return q.questID ~= nil and DARKMOON_QUEST_DATA[q.questID] ~= nil
end

local function IsQuestDone(q)
    if q.isComplete ~= nil then return q.isComplete == true end
    if q.questID and C_QuestLog and C_QuestLog.IsComplete then
        return C_QuestLog.IsComplete(q.questID) == true
    end
    return false
end

local function GetItemSellValue(link)
    if not link then return 0 end
    local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not getInfo then return 0 end
    return select(11, getInfo(link)) or 0
end

local function GetBagItemCount(link, name)
    local fn = (C_Item and C_Item.GetItemCount) or GetItemCount
    if not fn then return 0 end
    local c = link and fn(link) or 0
    if c > 0 then return c end
    return name and fn(name) or 0
end

-- Qualite d'un objet (0 = gris ... 5 = legendaire). Lue sur l'objet lui-meme : la valeur
-- donnee par le journal de quetes n'est pas fiable sur ce client.
-- Ordre d'essai : le lien de l'objet, puis son numero, puis la valeur du journal.
local function ItemQuality(link, fallback, itemID)
    local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if link and getInfo then
        local q = select(3, getInfo(link))
        if type(q) == "number" then return q end
    end
    if type(itemID) ~= "number" and type(link) == "string" then
        itemID = tonumber(link:match("item:(%d+)"))
    end
    if type(itemID) == "number" then
        local q = C_Item and C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(itemID)
        if type(q) ~= "number" and getInfo then q = select(3, getInfo(itemID)) end
        if type(q) == "number" then return q end
    end
    if type(fallback) == "number" and fallback >= 0 and fallback <= 8 then return fallback end
    return nil
end

-- Couleurs de rarete standard du jeu (secours si le client ne les fournit pas).
local RARITY_COLORS = {
    [0] = { 0.62, 0.62, 0.62 }, [1] = { 1, 1, 1 }, [2] = { 0.12, 1, 0 }, [3] = { 0, 0.44, 0.87 },
    [4] = { 0.64, 0.21, 0.93 }, [5] = { 1, 0.5, 0 }, [6] = { 0.9, 0.8, 0.5 }, [7] = { 0, 0.8, 1 },
    [8] = { 0, 0.8, 1 },
}

-- Couleur d'une rarete, depuis le jeu si possible (plusieurs fonctions selon les versions).
local function RarityRGB(quality)
    local fns = { C_Item and C_Item.GetItemQualityColor, GetItemQualityColor }
    for _, fn in ipairs(fns) do
        if fn then
            local ok, r, g, b = pcall(fn, quality)
            if ok and type(r) == "number" and type(g) == "number" and type(b) == "number" then return r, g, b end
        end
    end
    local c = type(ITEM_QUALITY_COLORS) == "table" and ITEM_QUALITY_COLORS[quality]
    if type(c) == "table" and type(c.r) == "number" then return c.r, c.g, c.b end
    c = RARITY_COLORS[quality]
    if c then return c[1], c[2], c[3] end
    return 1, 1, 1
end

local function QualityColor(quality)
    -- Sur parchemin clair (option "theme sur la roue") : objets blancs/gris a l'encre, et
    -- couleurs de rarete assombries pour rester lisibles.
    local pal = DWE.WheelPalette()
    local ink = pal.common
    if ink and (quality == nil or quality <= 1) then return ink[1], ink[2], ink[3] end
    if type(quality) ~= "number" then return 1, 1, 1 end
    local r, g, b = RarityRGB(quality)
    local k = pal.qualityDim or 1
    return r * k, g * k, b * k
end

local function AnchorButton(btn, anchorFrame, offsetY)
    btn:ClearAllPoints()
    btn:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, offsetY or -5)
    btn:SetPoint("TOPRIGHT", anchorFrame, "BOTTOMRIGHT", 0, offsetY or -5)
    btn:Show()
end

local COIN_ICON = " |TInterface\\MoneyFrame\\UI-GoldIcon:13:13:2:-2|t"

-- Remplit un bouton d'objet. info = { name, texture, numItems, quality, link }.
-- Renvoie vrai si les infos de l'objet ne sont pas encore chargees.
-- Nom d'un objet que la quete ne donne pas encore : demande au cache des objets du jeu, et
-- demande son chargement s'il n'y est pas (le jeu previent alors par GET_ITEM_INFO_RECEIVED).
local function ItemIDOf(link, itemID)
    if type(itemID) == "number" and itemID > 0 then return itemID end
    if type(link) == "string" then return tonumber(link:match("item:(%d+)")) end
end

local function ResolveItem(info)
    local id = ItemIDOf(info.link, info.itemID)
    local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if getInfo and (info.link or id) then
        local ok, name, link, _, _, _, _, _, _, _, tex = pcall(getInfo, info.link or id)
        if ok then
            if (not info.name or info.name == "") and type(name) == "string" and name ~= "" then info.name = name end
            info.link = info.link or link
            info.texture = info.texture or tex
        end
    end
    if (not info.name or info.name == "") and id then
        if C_Item and C_Item.GetItemNameByID then
            local ok, name = pcall(C_Item.GetItemNameByID, id)
            if ok and type(name) == "string" and name ~= "" then info.name = name end
        end
        if (not info.name or info.name == "") and C_Item and C_Item.RequestLoadItemDataByID then
            pcall(C_Item.RequestLoadItemDataByID, id)
        end
    end
end

local function FillItemButton(btn, info, isBestSell, suffix)
    if not info.name or info.name == "" or not info.link then ResolveItem(info) end
    local isPending = not info.name or info.name == ""
    local displayName = (info.name and info.name ~= "") and info.name or L.LOADING
    btn.itemLink = info.link
    btn.itemCount = info.numItems or 1
    btn.isDarkmoonTicket = false
    btn.icon:SetTexture(info.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
    btn.count:SetText(info.numItems or 1)
    btn.count:Show()
    local quality = ItemQuality(info.link, info.quality, info.itemID)
    btn.text:SetTextColor(QualityColor(quality))
    -- Rarete pas encore connue (objet pas encore charge par le jeu) : on rafraichira.
    if quality == nil and (info.link or info.itemID) then isPending = true end
    btn.text:SetText(displayName .. (suffix or "") .. (isBestSell and COIN_ICON or ""))
    return isPending
end

-- Objet de la fenetre de quete ouverte ("required", "reward" ou "choice").
local function AddQuestItemButton(btnIndex, itemType, itemIndex, anchorFrame, offsetY, isBestSell, canChoose)
    if not GetQuestItemInfo then return false end
    local name, texture, numItems, quality = GetQuestItemInfo(itemType, itemIndex)
    if not texture and not name then return false end
    local link = GetQuestItemLink and GetQuestItemLink(itemType, itemIndex)

    local btn = DWE.GetRewardButton(btnIndex)
    btn.itemType, btn.itemIndex, btn.canChoose = itemType, itemIndex, canChoose
    btn.selectedBorder:SetShown(canChoose and itemIndex == DWE.selectedRewardIndex)

    local suffix
    if itemType == "required" then
        local need = numItems or 1
        local have = GetBagItemCount(link, name)
        local hex = DWE.WheelPalette().hex
        suffix = " " .. ((have >= need) and hex.ok or hex.bad) .. "(" .. have .. "/" .. need .. ")|r"
    end
    local pending = FillItemButton(btn, { name = name, texture = texture, numItems = numItems, quality = quality, link = link }, isBestSell, suffix)
    AnchorButton(btn, anchorFrame, offsetY)
    return true, pending, btn
end

-- Objet lu dans le journal de quetes (etape "rendre la quete" pas encore validee).
-- choiceIndex : rang de la recompense au choix (selectionnable des l'etape "Continuer").
local function AddLogItemButton(btnIndex, info, anchorFrame, offsetY, isBestSell, choiceIndex)
    local btn = DWE.GetRewardButton(btnIndex)
    btn.itemType, btn.itemIndex, btn.canChoose = nil, choiceIndex, choiceIndex ~= nil
    btn.selectedBorder:SetShown(choiceIndex ~= nil and choiceIndex == DWE.selectedRewardIndex)
    local pending = FillItemButton(btn, info, isBestSell)
    AnchorButton(btn, anchorFrame, offsetY)
    return pending, btn
end

local function AddTicketButton(btnIndex, count, anchorFrame, offsetY)
    local btn = DWE.GetRewardButton(btnIndex)
    btn.itemType, btn.itemIndex, btn.canChoose = nil, nil, false
    btn.itemLink = "currency:515"
    btn.itemCount = count or 1
    btn.isDarkmoonTicket = true
    btn.selectedBorder:Hide()

    local currName, currTex
    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
        local info = C_CurrencyInfo.GetCurrencyInfo(515)
        if info then currName, currTex = info.name, info.iconFileID end
    end
    btn.icon:SetTexture(currTex or "Interface\\Icons\\INV_Misc_Ticket_Darkmoon_01")
    btn.count:SetText(count or 1)
    btn.count:Show()
    btn.text:SetTextColor(QualityColor(1))
    btn.text:SetText(NonEmpty(currName) or DarkmoonTicketName())
    AnchorButton(btn, anchorFrame, offsetY)
    return btn
end

-- Noms de la Foire de Sombrelune dans la langue du jeu (faction 909, ticket 19182).
local function DarkmoonFactionName()
    local name
    if C_Reputation and C_Reputation.GetFactionDataByID then
        local data = C_Reputation.GetFactionDataByID(909)
        name = data and data.name
    elseif GetFactionInfoByID then
        name = GetFactionInfoByID(909)
    end
    return NonEmpty(name) or L.DM_FACTION
end

local function DarkmoonTicketName()
    local name
    if C_Item and C_Item.GetItemNameByID then
        name = C_Item.GetItemNameByID(19182)
    elseif GetItemInfo then
        name = GetItemInfo(19182)
    end
    return NonEmpty(name) or L.DM_TICKET
end

local function EscapePattern(s)
    return (s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
end

-- Reputation et tickets de Sombrelune gagnes (cherches dans le texte de la quete).
local function DetectQuestRepAndTickets()
    local qID = GetQuestID and GetQuestID()
    local dm = qID and DARKMOON_QUEST_DATA[qID]
    if dm then
        return "+" .. dm.rep .. " " .. DarkmoonFactionName(), dm.tickets
    end

    local txt = ""
    for _, fn in ipairs({ GetProgressText, GetQuestText, GetRewardText }) do
        local s = fn and NotSecret(fn())
        if s then txt = txt .. " " .. s end
    end
    if txt == "" then return nil, nil end
    local lower = txt:lower()

    local repText
    local rep = EscapePattern(L.REPUTATION:lower())
    local amount = lower:match("(%d+)%s*" .. rep) or lower:match(rep .. "[^%d]*(%d+)")
    if amount then repText = "+" .. amount .. " " .. L.REPUTATION end

    local tickets
    local ticketName = EscapePattern(DarkmoonTicketName():lower())
    local tix = lower:match("(%d+)%s*" .. ticketName)
    if tix then tickets = tonumber(tix) end
    return repText, tickets
end

-- Recompenses lues dans le journal de quetes (QUEST_PROGRESS ne les donne pas).
local function GetQuestLogDataForProgress(qID)
    if not qID or qID <= 0 then return nil end
    local prevSelected
    if C_QuestLog and C_QuestLog.GetLogIndexForQuestID and C_QuestLog.SetSelectedQuest then
        local logIdx = C_QuestLog.GetLogIndexForQuestID(qID)
        if not logIdx or logIdx <= 0 then return nil end
        prevSelected = C_QuestLog.GetSelectedQuest and C_QuestLog.GetSelectedQuest()
        C_QuestLog.SetSelectedQuest(qID)
    elseif GetQuestLogIndexByID and SelectQuestLogEntry then
        local logIdx = GetQuestLogIndexByID(qID)
        if not logIdx or logIdx <= 0 then return nil end
        prevSelected = GetQuestLogSelection and GetQuestLogSelection()
        SelectQuestLogEntry(logIdx)
    else
        return nil
    end

    local data = {
        xp = GetQuestLogRewardXP and GetQuestLogRewardXP(qID) or 0,
        money = GetQuestLogRewardMoney and GetQuestLogRewardMoney(qID) or 0,
        rewards = {},
        choices = {},
    }
    local function Collect(list, count, infoFn, kind)
        for i = 1, count do
            local name, texture, numItems, quality, _, itemID = infoFn(i, qID)
            if texture or name then
                local link = GetQuestLogItemLink and GetQuestLogItemLink(kind, i, qID)
                table.insert(list, { name = name, texture = texture, numItems = numItems or 1, quality = quality, link = link, itemID = itemID })
            end
        end
    end
    if GetQuestLogRewardInfo then
        Collect(data.rewards, GetNumQuestLogRewards and GetNumQuestLogRewards(qID) or 0, GetQuestLogRewardInfo, "reward")
    end
    if GetQuestLogChoiceInfo then
        Collect(data.choices, GetNumQuestLogChoices and GetNumQuestLogChoices(qID) or 0, GetQuestLogChoiceInfo, "choice")
    end

    if prevSelected and prevSelected > 0 then
        if C_QuestLog and C_QuestLog.SetSelectedQuest then
            C_QuestLog.SetSelectedQuest(prevSelected)
        elseif SelectQuestLogEntry then
            SelectQuestLogEntry(prevSelected)
        end
    end
    return data
end

local function MoneyText(m)
    local num = DWE.WheelPalette().hex.num
    local g = math.floor(m / 10000)
    local s = math.floor((m % 10000) / 100)
    local c = m % 100
    local out = ""
    if g > 0 then out = out .. num .. g .. "|r|TInterface\\MoneyFrame\\UI-GoldIcon:13:13:2:-4|t  " end
    if s > 0 then out = out .. num .. s .. "|r|TInterface\\MoneyFrame\\UI-SilverIcon:13:13:2:-4|t  " end
    if c > 0 then out = out .. num .. c .. "|r|TInterface\\MoneyFrame\\UI-CopperIcon:13:13:2:-4|t  " end
    return out
end

--------------------------------------------------------------------------------
-- Apercu de quete sous la roue
--------------------------------------------------------------------------------

local QUEST_EVENTS = { QUEST_DETAIL = true, QUEST_PROGRESS = true, QUEST_COMPLETE = true }

local function UpdatePreview(event)
    DWE.objLine:SetText("")
    DWE.rewLine:SetText("")
    DWE.HideRewardButtons()
    if not QUEST_EVENTS[event] then
        DWE.wheelBottom = DWE.choiceBox
        DWE.PaintWheelTheme()
        return
    end
    DWE.lastQuestEvent = event
    local C = DWE.WheelPalette().hex

    local obj = GetObjectiveText and NonEmpty(GetObjectiveText())
    if obj then DWE.objLine:SetText(C.hdr .. L.OBJ .. "|r " .. C.body .. obj .. "|r") end
    if DWE.SizeQuestInfo then DWE.SizeQuestInfo() end

    local btnCount, needsRefresh = 0, false
    local topAnchor = obj and DWE.objLine or DWE.questTop
    local topOffset = obj and -10 or 1
    local function Inset(anchor, left) return (anchor == DWE.choiceBox) and (left and 6 or -4) or 0 end

    -- Objets a rapporter.
    local numReq = (event == "QUEST_PROGRESS" and GetNumQuestItems) and GetNumQuestItems() or 0
    if numReq > 0 then
        DWE.reqHeader:ClearAllPoints()
        DWE.reqHeader:SetPoint("TOPLEFT", topAnchor, "BOTTOMLEFT", Inset(topAnchor, true), topOffset)
        DWE.reqHeader:SetPoint("TOPRIGHT", topAnchor, "BOTTOMRIGHT", Inset(topAnchor, false), topOffset)
        DWE.reqHeader:SetText(C.hdr .. L.REQ_ITEMS .. "|r")
        DWE.reqHeader:Show()
        local anchor = DWE.reqHeader
        for i = 1, numReq do
            local added, pending, btn = AddQuestItemButton(btnCount + 1, "required", i, anchor, (i == 1) and -6 or -5, false, false)
            if added then
                btnCount = btnCount + 1
                anchor = btn
                needsRefresh = needsRefresh or pending
            end
        end
        topAnchor, topOffset = anchor, -10
    end

    DWE.rewLine:ClearAllPoints()
    DWE.rewLine:SetPoint("TOPLEFT", topAnchor, "BOTTOMLEFT", Inset(topAnchor, true), topOffset)
    DWE.rewLine:SetPoint("TOPRIGHT", topAnchor, "BOTTOMRIGHT", Inset(topAnchor, false), topOffset)

    local logData = (event == "QUEST_PROGRESS" and GetQuestID) and GetQuestLogDataForProgress(GetQuestID()) or nil
    local inWindow = (event == "QUEST_DETAIL" or event == "QUEST_COMPLETE")

    -- Ligne XP / argent / reputation.
    local r = ""
    local xp = logData and logData.xp or (GetRewardXP and GetRewardXP() or 0)
    if xp and xp > 0 then
        r = r .. " |TInterface\\Icons\\XP_Icon:15:15:0:-5:64:64:5:59:5:59|t " .. C.num .. xp .. "|r   "
    end
    local money = logData and logData.money or (GetRewardMoney and GetRewardMoney() or 0)
    if money and money > 0 then r = r .. MoneyText(money) end
    local repText, tickets = DetectQuestRepAndTickets()
    if repText then
        r = r .. " |TInterface\\Icons\\Achievement_Reputation_01:15:15:0:-5:64:64:5:59:5:59|t " .. C.rep .. repText .. "|r"
    end

    -- Recompenses fixes.
    local lastAnchor, rewCount = DWE.rewLine, 0
    if logData then
        for _, info in ipairs(logData.rewards) do
            local pending, btn = AddLogItemButton(btnCount + 1, info, lastAnchor, (rewCount == 0) and -8 or -5, false)
            btnCount, rewCount, lastAnchor = btnCount + 1, rewCount + 1, btn
            needsRefresh = needsRefresh or pending
        end
    elseif inWindow then
        for i = 1, (GetNumQuestRewards and GetNumQuestRewards() or 0) do
            local added, pending, btn = AddQuestItemButton(btnCount + 1, "reward", i, lastAnchor, (rewCount == 0) and -8 or -5, false, false)
            if added then
                btnCount, rewCount, lastAnchor = btnCount + 1, rewCount + 1, btn
                needsRefresh = needsRefresh or pending
            end
        end
    end
    if rewCount == 0 and tickets and tickets > 0 then
        lastAnchor = AddTicketButton(btnCount + 1, tickets, lastAnchor, -8)
        btnCount, rewCount = btnCount + 1, rewCount + 1
    end

    -- Recompenses au choix (l'icone de piece marque celle qui se vend le plus cher).
    -- Comme dans le jeu : "Choisissez votre recompense" seulement quand on peut choisir
    -- maintenant (quete terminee) ; sinon "Vous pourrez choisir une de ces recompenses".
    local function ShowChooseHeader(canChoose)
        DWE.chooseHeader:ClearAllPoints()
        DWE.chooseHeader:SetPoint("TOPLEFT", lastAnchor, "BOTTOMLEFT", 0, -10)
        DWE.chooseHeader:SetPoint("TOPRIGHT", lastAnchor, "BOTTOMRIGHT", 0, -10)
        DWE.chooseHeader:SetText(C.hdr .. (canChoose and L.CHOOSE_HDR or (L.CHOICES_HDR or L.CHOOSE_HDR)) .. "|r")
        DWE.chooseHeader:Show()
        lastAnchor = DWE.chooseHeader
    end
    local function BestIndex(count, priceOf)
        if count < 2 then return nil end
        local best, bestPrice = nil, 0
        for i = 1, count do
            local price = priceOf(i)
            if price > bestPrice then best, bestPrice = i, price end
        end
        return best
    end

    if logData and #logData.choices > 0 then
        local best = BestIndex(#logData.choices, function(i)
            local info = logData.choices[i]
            return GetItemSellValue(info.link) * (info.numItems or 1)
        end)
        -- Rendu de quete : on ne choisit que si la quete est terminee.
        local canChoose = event == "QUEST_PROGRESS" and ((not IsQuestCompletable) or IsQuestCompletable()) and true or false
        ShowChooseHeader(canChoose)
        for i, info in ipairs(logData.choices) do
            local pending, btn = AddLogItemButton(btnCount + 1, info, lastAnchor, (i == 1) and -6 or -5, i == best, canChoose and i or nil)
            btnCount, rewCount, lastAnchor = btnCount + 1, rewCount + 1, btn
            needsRefresh = needsRefresh or pending
        end
    elseif inWindow then
        local numChoices = GetNumQuestChoices and GetNumQuestChoices() or 0
        if numChoices > 0 then
            local best = BestIndex(numChoices, function(i)
                local _, _, numItems = GetQuestItemInfo("choice", i)
                return GetItemSellValue(GetQuestItemLink and GetQuestItemLink("choice", i)) * (numItems or 1)
            end)
            local canChooseNow = (event == "QUEST_COMPLETE")
            ShowChooseHeader(canChooseNow)
            for i = 1, numChoices do
                local added, pending, btn = AddQuestItemButton(btnCount + 1, "choice", i, lastAnchor, (i == 1) and -6 or -5, i == best, canChooseNow)
                if added then
                    btnCount, rewCount, lastAnchor = btnCount + 1, rewCount + 1, btn
                    needsRefresh = needsRefresh or pending
                end
            end
        end
    end

    DWE.needsItemRefresh = needsRefresh
    -- Le jeu ne previent pas toujours quand un objet arrive : on reessaie un peu plus tard.
    if needsRefresh and C_Timer and C_Timer.After and (DWE.itemRetry or 0) < 8 then
        DWE.itemRetry = (DWE.itemRetry or 0) + 1
        local ev = event
        C_Timer.After(0.4, function()
            if DWE.needsItemRefresh and DWE.lastQuestEvent == ev and DWE.choiceBox:IsShown() then
                UpdatePreview(ev)
            end
        end)
    elseif not needsRefresh then
        DWE.itemRetry = 0
    end
    -- Bas de la zone couverte par le theme de la roue : dernier element affiche.
    local bottom = (topAnchor == DWE.questTop) and DWE.choiceBox or topAnchor
    if r ~= "" or rewCount > 0 then
        DWE.rewLine:SetText(C.hdr .. L.REWARDS .. "|r" .. r)
        bottom = lastAnchor
    end
    DWE.wheelBottom = bottom
    if DWE.SizeQuestInfo then DWE.SizeQuestInfo() end
    DWE.PaintWheelTheme()
end

--------------------------------------------------------------------------------
-- Livres, lettres, plaques
--------------------------------------------------------------------------------
-- Les pages sont gardees en memoire au fur et a mesure (DialogueUI, s'il est installe,
-- charge tout le livre d'un coup a l'ouverture). "Page precedente" lit le cache ;
-- "Page suivante" lit le cache, ou demande la page au jeu et attend ITEM_TEXT_READY.

local bookState = {}
local function ResetBook(active, title)
    bookState = { active = active, title = title or "", pages = {}, currentPage = 1, maxPage = 0 }
end
ResetBook(false)

local BookHasNext -- defini plus bas

local function ShowBookPage(pageNum)
    if not bookState.active then return end
    local total = #bookState.pages
    if DWE.BookLook() == "note" then
        -- Note : tout le texte d'un coup (les pages deja lues), sans numero de page.
        DWE.bookInfo = { page = 1, total = total, hasNext = false, note = true }
        if not (ItemTextHasNextPage and ItemTextHasNextPage()) then bookState.reachedEnd = true end
        DWE.SetDialogueText(bookState.title, table.concat(bookState.pages, "\n\n"))
        return
    end
    if pageNum < 1 or pageNum > total then return end
    -- Page tournee a la main (le suivi de la voix est en pause) : la voix peut suivre le lecteur.
    if DWE.bookFollowPause and pageNum ~= bookState.currentPage and DWE.VoiceToPage then DWE.VoiceToPage(pageNum) end
    bookState.currentPage = pageNum
    local title = bookState.title
    if total > 1 then title = title .. " (" .. pageNum .. "/" .. total .. ")" end
    DWE.bookInfo = { page = pageNum, total = total, hasNext = BookHasNext and BookHasNext() or false }
    if not DWE.bookInfo.hasNext then bookState.reachedEnd = true end
    DWE.SetDialogueText(title, bookState.pages[pageNum] or "")
end

-- Une page suivante existe si elle est deja en memoire, ou si le jeu en annonce une apres la
-- derniere page lue. Le jeu ne parle que de SA page courante : DialogueUI la deplace quand il
-- charge le livre, donc on ne le croit que s'il est bien sur notre derniere page.
function BookHasNext()
    local cur = bookState.currentPage
    if bookState.pages[cur + 1] then return true end
    if cur < bookState.maxPage or not (ItemTextHasNextPage and ItemTextGetPage) then return false end
    return ItemTextGetPage() == cur and ItemTextHasNextPage() and true or false
end

local function StoreCurrentBookPage()
    local p = (ItemTextGetPage and ItemTextGetPage()) or (#bookState.pages + 1)
    bookState.pages[p] = (ItemTextGetText and ItemTextGetText()) or ""
    if p > bookState.maxPage then bookState.maxPage = p end
    -- Connu des la premiere page : plusieurs pages ? (decide livre ouvert / note en automatique)
    local more = ItemTextHasNextPage and ItemTextHasNextPage() and true or false
    DWE.bookInfo = { page = bookState.currentPage or 1, total = #bookState.pages, hasNext = more or nil }
    return p
end

--------------------------------------------------------------------------------
-- Quete partagee par un joueur
--------------------------------------------------------------------------------

-- Pendant une quete partagee, l'unite "questnpc" / "npc" est le joueur qui partage
-- (pour un objet qui commence une quete, c'est nous-meme : ignore).
local function GetQuestSharer()
    for _, unit in ipairs({ "questnpc", "npc" }) do
        local ok, isOther = pcall(function()
            return UnitExists(unit) and UnitIsPlayer(unit) and not UnitIsUnit(unit, "player") and true or false
        end)
        if ok and isOther == true then
            local okN, name = pcall(UnitName, unit)
            if not (okN and type(name) == "string" and name ~= "") then name = nil end
            if name and issecretvalue and issecretvalue(name) then name = nil end
            local okC, _, class = pcall(UnitClass, unit)
            if not okC or type(class) ~= "string" or (issecretvalue and issecretvalue(class)) then class = nil end
            name = name or (QuestFrameNpcNameText and NonEmpty(QuestFrameNpcNameText:GetText()))
            if name then return { unit = unit, name = name, class = class } end
        end
    end
end

--------------------------------------------------------------------------------
-- Texte du popup
--------------------------------------------------------------------------------

local function UpdateDialogueText(event)
    local npcName = NonEmpty(UnitName("npc")) or NonEmpty(UnitName("target")) or ""
    local questTitle = GetTitleText and NonEmpty(GetTitleText())
    local header, body = npcName, nil

    if event == "GOSSIP_SHOW" then
        body = C_GossipInfo and C_GossipInfo.GetText and C_GossipInfo.GetText()
    elseif event == "QUEST_GREETING" then
        body = GetGreetingText and GetGreetingText()
    elseif event == "QUEST_DETAIL" then
        header, body = questTitle or npcName, GetQuestText and GetQuestText()
    elseif event == "QUEST_PROGRESS" then
        header, body = questTitle or npcName, GetProgressText and GetProgressText()
    elseif event == "QUEST_COMPLETE" then
        header, body = questTitle or npcName, GetRewardText and GetRewardText()
    end

    if body == nil or body == "" then
        local blizz = (GossipGreetingText and GossipGreetingText:GetText()) or (GreetingText and GreetingText:GetText())
        body = blizz or ""
    end
    -- Le texte d'une quete (dit une seule fois) passe avant la salutation habituelle du PNJ que
    -- le jeu rouvre juste apres : on la saute une fois, le temps de lire la quete.
    local now = GetTime and GetTime() or 0
    local quest = event == "QUEST_DETAIL" or event == "QUEST_PROGRESS" or event == "QUEST_COMPLETE"
    if quest and type(body) == "string" and not (issecretvalue and issecretvalue(body)) and body ~= "" then
        DWE.questHold = { untilT = now + math.min(40, 3 + #body * 0.065), header = header, body = body,
            npc = UnitGUID and UnitGUID("npc") or nil }
    elseif (event == "GOSSIP_SHOW" or event == "QUEST_GREETING") and DWE.questHold then
        local hold = DWE.questHold
        DWE.questHold = nil
        -- Seulement pour le meme PNJ : sinon un autre PNJ "parlait" avec la quete du precedent.
        local npc = UnitGUID and UnitGUID("npc") or nil
        if now < hold.untilT and hold.npc and npc == hold.npc then
            header, body = hold.header, hold.body
        end
    end
    DWE.SetDialogueText(header, body)
end

--------------------------------------------------------------------------------
-- Choix de la roue
--------------------------------------------------------------------------------

local function AddOption(opt)
    table.insert(DWE.currentOptions, opt)
end

local function BuildGossipOptions()
    if not C_GossipInfo then return end
    for _, q in ipairs(C_GossipInfo.GetAvailableQuests and C_GossipInfo.GetAvailableQuests() or {}) do
        local qID = q.questID
        AddOption({
            isQuest = true,
            icon = IsKnownRepeatable(q) and ICON_QUEST_REPEATABLE or ICON_QUEST_AVAIL,
            rawLabel = q.title or "?",
            action = function() C_GossipInfo.SelectAvailableQuest(qID) end,
        })
    end
    for _, q in ipairs(C_GossipInfo.GetActiveQuests and C_GossipInfo.GetActiveQuests() or {}) do
        local qID = q.questID
        AddOption({
            isQuest = true,
            icon = IsQuestDone(q) and ICON_QUEST_ACTIVE or ICON_QUEST_INCOMPLETE,
            rawLabel = q.title or "?",
            action = function() C_GossipInfo.SelectActiveQuest(qID) end,
        })
    end
    for idx, info in ipairs(C_GossipInfo.GetOptions and C_GossipInfo.GetOptions() or {}) do
        local optionID = info.gossipOptionID or idx
        AddOption({
            icon = GetGossipIcon(info.icon or info.type),
            rawLabel = info.name or "?",
            action = function() C_GossipInfo.SelectOption(optionID) end,
        })
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0, SyncIconsFromGossipFrame)
        C_Timer.After(0.05, SyncIconsFromGossipFrame)
    end
end

local function BuildGreetingOptions()
    for i = 1, (GetNumAvailableQuests and GetNumAvailableQuests() or 0) do
        local isRep = GetAvailableQuestInfo and select(3, GetAvailableQuestInfo(i))
        AddOption({
            isQuest = true,
            icon = isRep and ICON_QUEST_REPEATABLE or ICON_QUEST_AVAIL,
            rawLabel = (GetAvailableTitle and GetAvailableTitle(i)) or "?",
            action = function() SelectAvailableQuest(i) end,
        })
    end
    for i = 1, (GetNumActiveQuests and GetNumActiveQuests() or 0) do
        local title, isDone = GetActiveTitle(i)
        if isDone == nil and GetActiveQuestID and C_QuestLog and C_QuestLog.IsComplete then
            local qID = GetActiveQuestID(i)
            isDone = qID and C_QuestLog.IsComplete(qID)
        end
        AddOption({
            isQuest = true,
            icon = isDone and ICON_QUEST_ACTIVE or ICON_QUEST_INCOMPLETE,
            rawLabel = title or "?",
            action = function() SelectActiveQuest(i) end,
        })
    end
end

local DisableKeys -- defini plus bas
local BuildOptions

local function BuildBookOptions()
    if not DWE.TextWanted() then return end
    -- Voix, suivi de la voix, surbrillance, animation : dans le menu du marque-page (en haut a
    -- droite du livre). En bas : seulement tourner les pages et fermer.
    if DWE.BookLook() == "note" then return end -- la note defile, pas de pages
    -- Livre reduit : une page du jeu peut s'etaler sur plusieurs doubles pages (sous-pages),
    -- tournees d'abord.
    if bookState.currentPage > 1 or DWE.BookSubCan(-1) then
        AddOption({ icon = ICON_PREV_PAGE, rawLabel = L.PREV_PAGE, action = function()
            bookState.lastBtn = "prev"
            DWE.bookFollowPause = true -- page tournee a la main : on ne suit plus la voix pour cette page
            DWE.bookResumeHold = nil
            if DWE.BookSubStep(-1) then
                -- sous-page precedente
            elseif bookState.currentPage > 1 then
                DWE.BookSubWantLast()
                ShowBookPage(bookState.currentPage - 1)
            end
            BuildOptions("ITEM_TEXT_CACHED", true)
            DWE.UpdateVisuals()
        end })
    end
    if BookHasNext() or DWE.BookSubCan(1) then
        AddOption({ icon = ICON_NEXT_PAGE, rawLabel = L.NEXT_PAGE, action = function()
            bookState.lastBtn = "next"
            DWE.bookFollowPause = true
            DWE.bookResumeHold = nil
            if DWE.BookSubStep(1) then
                BuildOptions("ITEM_TEXT_CACHED", true)
                DWE.UpdateVisuals()
            elseif bookState.pages[bookState.currentPage + 1] then
                ShowBookPage(bookState.currentPage + 1)
                BuildOptions("ITEM_TEXT_CACHED")
            elseif ItemTextNextPage then
                bookState.awaitNext = true
                ItemTextNextPage()
            end
        end })
    end
end

-- Livre ouvert lu par Spoken : il tourne ses pages avec la voix (option "suivre la voix").
-- `text` = la page que Spoken lit, `share` = ou en est la voix dans cette page (0..1).
-- Une page tournee a la main suspend le suivi jusqu'a la page lue suivante.
-- Aller a la page `n` du jeu : en memoire, ou la suivante demandee au jeu (comme "Page suivante").
function DWE.BookGoTo(n)
    if not (n and bookState.active) or n == bookState.currentPage then return false end
    if bookState.pages[n] then
        ShowBookPage(n)
    elseif n == bookState.currentPage + 1 and BookHasNext() and ItemTextNextPage then
        if bookState.awaitNext then return true end
        bookState.awaitNext = true
        ItemTextNextPage()
        return true
    elseif n > bookState.currentPage + 1 and BookHasNext() and ItemTextNextPage then
        -- Page plus loin que celles deja chargees (livre rouvert pendant que la voix le lit) :
        -- on demande les pages au jeu une a une jusqu'a elle, comme pour le marque-page.
        if bookState.awaitNext or bookState.resumeTo then return true end
        bookState.resumeTo = n
        DWE.BookResumeStep()
        return true
    else
        return false
    end
    BuildOptions("ITEM_TEXT_CACHED", true)
    DWE.UpdateVisuals()
    return true
end
local function FollowOn()
    return DialogueWheelE_BookAutoScroll ~= false and not DWE.bookFollowPause and bookState.active
        and DWE.BookLook() == "book"
end
-- `number` = numero de la page lue (Spoken Readables), sinon reconnue a son texte.
function DWE.BookFollow(text, share, number)
    local function BareText(t) return (string.gsub(string.lower(t or ""), "[%s%p\128-\255]", "")) end
    if not (FollowOn() or (DWE.bookResumeHold and bookState.active)) then return end
    local found = number
    if not found and type(text) == "string" then
        local key = BareText(text):sub(1, 40)
        if key ~= "" then
            for p, page in pairs(bookState.pages) do
                if BareText(page):sub(1, 40) == key then found = p break end
            end
        end
    end
    if not found then return end
    -- Livre rouvert au marque-page : tant que la voix n'y est pas, elle ne tire pas le livre ailleurs.
    if DWE.bookResumeHold then
        if found ~= DWE.bookResumeHold then
            -- La voix a demarre ailleurs (souvent page 1) : on la renvoie a la page marquee.
            local now = GetTime and GetTime() or 0
            if now - (DWE.resumeRedirectAt or 0) > 1.5 then
                DWE.resumeRedirectAt = now
                DWE.SpokenGoPage(DWE.bookResumeHold)
            end
            return
        end
        DWE.bookResumeHold = nil
    end
    if not FollowOn() then return end
    if found ~= bookState.currentPage then
        DWE.BookGoTo(found)
        return
    end
    -- Page du jeu etalee sur plusieurs doubles pages : celle ou en est la voix.
    local st = DWE.bookSub
    local n = st and st.spreads and #st.spreads or 0
    if n < 2 or not share then return end
    local total, sizes = 0, {}
    for i, sp in ipairs(st.spreads) do
        sizes[i] = #(sp[1] or "") + #(sp[2] or "") + 1
        total = total + sizes[i]
    end
    local at, acc, want = share * total, 0, n
    for i = 1, n do
        acc = acc + sizes[i]
        if at <= acc then want = i break end
    end
    if want ~= st.index then
        st.index = want
        DWE.UpdateTextPanelVisuals()
        BuildOptions("ITEM_TEXT_CACHED", true)
        DWE.UpdateVisuals()
    end
end
-- La voix a fini la page affichee : on tourne. Si Spoken ne lit qu'une page a la fois, c'est
-- ce qui lui fait lire la suivante (il lit la page que le jeu ouvre).
function DWE.BookPageDone(number)
    if DWE.bookResumeHold or not FollowOn() or not DWE.choiceBox:IsShown() then return end
    if number and number ~= bookState.currentPage then return end
    DWE.BookGoTo(bookState.currentPage + 1)
end

-- Marque-page pose par le joueur (par personnage, un par livre, reconnu a son titre).
-- Renvoie la cle du livre, la page affichee et la page marquee (ou nil).
function DWE.BookmarkInfo()
    if not bookState.active or DWE.BookLook() == "note" then return nil end
    local k = DWE.BookKey(bookState.title)
    if not k then return nil end
    local t = rawget(_G, "DialogueWheelE_Bookmarks")
    return k, bookState.currentPage, type(t) == "table" and t[k] or nil
end
-- Marque la page affichee, ou retire le marque-page s'il y est deja.
function DWE.BookmarkToggle()
    local k, cur, saved = DWE.BookmarkInfo()
    if not k then return end
    if type(DialogueWheelE_Bookmarks) ~= "table" then DialogueWheelE_Bookmarks = {} end
    DialogueWheelE_Bookmarks[k] = (saved ~= cur) and cur or nil
    if DWE.UpdateRibbonMark then DWE.UpdateRibbonMark() end
end
-- A l'ouverture d'un livre marque : on demande au jeu les pages une a une jusqu'a la page
-- marquee (sans les afficher). Renvoie true tant qu'une page est en route.
function DWE.BookResumeStep()
    local want = bookState.resumeTo
    if not want then return false end
    if DWE.BookLook() == "note" then bookState.resumeTo = nil return false end
    if bookState.pages[want] then
        bookState.currentPage = want
        bookState.resumeTo = nil
        DWE.BookResumeVoice()
        return false
    end
    if BookHasNext() and ItemTextNextPage and ItemTextGetPage and ItemTextGetPage() == bookState.currentPage then
        bookState.awaitNext = true
        ItemTextNextPage()
        return true
    end
    bookState.resumeTo = nil -- le livre n'a plus autant de pages : on reste ou on est
    DWE.bookResumeHold = nil
    return false
end
-- Spoken a commence le livre a la page 1 : il reprend a la page marquee. Si la voix demarre
-- plus tard (file d'attente, conversation), BookFollow la renvoie a la page marquee.
function DWE.BookResumeVoice()
    local want = bookState.currentPage
    C_Timer.After(0.1, function()
        if DWE.bookResumeHold == want then DWE.SpokenGoPage(want) end
    end)
end

-- Fait lire a Spoken la page `n` du livre ouvert (s'il lit ce livre). Renvoie true si relance.
function DWE.SpokenGoPage(n)
    local sr = rawget(_G, "SpokenReadables")
    if not n or type(sr) ~= "table" or not (sr.PageOnScreen and sr.PlaceOf and sr.BookOf and sr.IsNarrating
        and sr.StopReading and sr.PlayFrom) then return false end
    local focus = DWE.SpokenFocus
    if focus and focus.bookMuted then return false end
    local ok, id = pcall(sr.PageOnScreen, sr)
    if not ok or not id then return false end
    local ok2, place = pcall(sr.PlaceOf, sr, id)
    if not ok2 or not place then return false end
    local ok3, reading = pcall(sr.IsNarrating, sr, place)
    if not (ok3 and reading) then return false end -- la voix ne lit pas ce livre
    local ok4, book = pcall(sr.BookOf, sr, id)
    local target = ok4 and type(book) == "table" and type(book.pages) == "table" and book.pages[n]
    if not target then return false end
    local sp = rawget(_G, "Spoken")
    local q = type(sp) == "table" and sp.GetQueue and select(2, pcall(sp.GetQueue, sp))
    if type(q) == "table" and q[1] and q[1].pageId == target then return false end -- deja lue
    pcall(sr.StopReading, sr, place)
    pcall(sr.PlayFrom, sr, target, true)
    return true
end

-- Option "la voix suit mes pages" : le joueur a tourne la page d'un livre que Spoken lit ;
-- apres un court instant (plusieurs pages tournees d'affilee : seule la derniere compte),
-- Spoken reprend la lecture a cette page.
function DWE.VoiceToPage(n)
    if DialogueWheelE_BookVoiceTurn ~= true or not n then return end -- option decochee par defaut
    DWE.voiceTurnToken = (DWE.voiceTurnToken or 0) + 1
    local token = DWE.voiceTurnToken
    C_Timer.After(0.35, function()
        if token ~= DWE.voiceTurnToken or not bookState.active or bookState.currentPage ~= n then return end
        DWE.SpokenGoPage(n)
    end)
end

-- Le menu du marque-page a change un reglage : boutons et affichage a jour.
function DWE.RefreshBookOptions()
    BuildOptions("ITEM_TEXT_CACHED", true)
    DWE.UpdateVisuals()
end

local BOOK_EVENTS = { ITEM_TEXT_BEGIN = true, ITEM_TEXT_READY = true, ITEM_TEXT_CACHED = true }

-- Le decoupage en sous-pages a change (livre redimensionne, nouvelle page) : boutons a jour.
function DWE.OnBookSubChanged()
    if bookState.active and DWE.bookMode and DWE.choiceBox:IsShown() and DWE.BookByAddon() then
        BuildOptions("ITEM_TEXT_CACHED", true)
        DWE.UpdateVisuals()
    end
end

-- (Re)construit la roue pour `event`. keepSelection : garder le choix surligne actuel.
function BuildOptions(event, keepSelection)
    local previous = keepSelection and DWE.currentOptions[DWE.selectedIndex]
    local previousLabel = previous and previous.rawLabel

    if not BOOK_EVENTS[event] then UpdateDialogueText(event) end
    DWE.currentOptions = {}

    local isBook = BOOK_EVENTS[event] and DWE.BookByAddon()
    -- Bouton "Spoken" : bascule entre le texte de l'addon et la fenetre de Spoken. Sans Spoken,
    -- pas de bouton (et le texte de l'addon reste affiche).
    local hasSpoken = DWE.SpokenFocus and DWE.SpokenFocus.Available()
    local spokenChoice = hasSpoken and DialogueWheelE_SpokenChoice == true
    -- Sans moyen de revenir (ni choix "Spoken" ni touche), le texte de l'addon reste affiche.
    if not (spokenChoice or (hasSpoken and DWE.GetToggleKey())) and DialogueWheelE_ShowText ~= true then
        DialogueWheelE_ShowText = true
    end
    if not isBook and spokenChoice then
        AddOption({
            isDialogueToggle = true,
            icon = GOSSIP_ICONS.gossip,
            rawLabel = L.TEXT_BTN,
            action = DWE.ToggleDialogueText,
        })
    end

    if event == "GOSSIP_SHOW" then
        BuildGossipOptions()
    elseif event == "QUEST_GREETING" then
        BuildGreetingOptions()
    elseif event == "QUEST_DETAIL" then
        local isRep = (QuestIsDaily and QuestIsDaily()) or (QuestIsWeekly and QuestIsWeekly())
        AddOption({ icon = isRep and ICON_QUEST_DAILY or ICON_QUEST_AVAIL, rawLabel = L.ACCEPT, action = AcceptQuest })
    elseif event == "QUEST_PROGRESS" then
        if (not IsQuestCompletable) or IsQuestCompletable() then
            -- Plusieurs recompenses au choix : "Continuer" reste grise tant qu'aucune n'est choisie.
            local logData = GetQuestID and GetQuestLogDataForProgress(GetQuestID())
            local needsPick = logData and #logData.choices > 1 and not DWE.selectedRewardIndex
            -- "Terminer la quete" directement : la recompense choisie ici est donnee des que le
            -- jeu ouvre l'ecran final (pas de deuxieme etape a valider).
            AddOption({
                isCompleteBtn = true,
                icon = needsPick and ICON_QUEST_INCOMPLETE or ICON_QUEST_ACTIVE,
                rawLabel = L.COMPLETE,
                disabled = needsPick,
                action = function()
                    DWE.autoReward = { questID = GetQuestID and GetQuestID() or 0, index = DWE.selectedRewardIndex }
                    CompleteQuest()
                end,
            })
        else
            AddOption({ icon = ICON_QUEST_INCOMPLETE, rawLabel = L.INCOMPLETE, disabled = true })
        end
    elseif event == "QUEST_COMPLETE" then
        -- Recompense choisie a l'etape "Continuer" : on la reprend.
        local memo = DWE.rewardMemory
        if not DWE.selectedRewardIndex and memo and GetQuestID and memo.questID == GetQuestID() then
            DWE.selectedRewardIndex = memo.index
        end
        local numChoices = GetNumQuestChoices and GetNumQuestChoices() or 0
        local needsPick = numChoices > 1 and not DWE.selectedRewardIndex
        AddOption({
            isCompleteBtn = true,
            icon = needsPick and ICON_QUEST_INCOMPLETE or ICON_QUEST_ACTIVE,
            rawLabel = L.COMPLETE,
            disabled = needsPick,
            action = function() GetQuestReward(DWE.selectedRewardIndex or 1) end,
        })
    elseif BOOK_EVENTS[event] then
        BuildBookOptions()
    end

    AddOption({
        isGoodbye = true,
        icon = ICON_GOODBYE,
        rawLabel = isBook and (rawget(_G, "CLOSE") or L.BOOK_CLOSE) or L.GOODBYE,
        action = function()
            DWE.CloseAllDialogue()
            DisableKeys()
        end,
    })

    -- Choix surligne : le precedent si demande, sinon le bouton de page utilise, sinon le
    -- premier choix utile apres "Dialogue".
    DWE.selectedIndex = 1
    DWE.wheelFirst = 1
    DWE.scrollSnap = true
    local want = previousLabel
    if not want and bookState.active and bookState.lastBtn then
        want = (bookState.lastBtn == "prev") and L.PREV_PAGE or L.NEXT_PAGE
    end
    local found = false
    if want then
        for i, opt in ipairs(DWE.currentOptions) do
            if opt.rawLabel == want and not opt.disabled then DWE.selectedIndex, found = i, true break end
        end
    end
    if not found then
        local from = (DWE.currentOptions[1] and DWE.currentOptions[1].isDialogueToggle) and 2 or 1
        for i = from, #DWE.currentOptions do
            if not DWE.currentOptions[i].disabled then DWE.selectedIndex = i break end
        end
    end

    for i = 1, #DWE.currentOptions do DWE.GetRow(i) end
    DWE.wheelWantsPreview = QUEST_EVENTS[event] or false
    DWE.itemRetry = 0
    DWE.UpdateVisuals()
    DWE.SetQuestSharer(event == "QUEST_DETAIL" and GetQuestSharer() or nil)
    UpdatePreview(event)
    -- A l'ouverture, les polices ne sont pas toujours pretes : un choix sur deux lignes peut etre
    -- mesure trop bas (texte qui deborde de sa bulle). Une deuxieme mise en page, a l'image
    -- suivante puis un peu apres, remet les hauteurs justes.
    DWE.builtAt = GetTime and GetTime() or 0
    if C_Timer and C_Timer.After then
        local function again() if DWE.choiceBox:IsShown() then DWE.UpdateVisuals() end end
        C_Timer.After(0, again)
        C_Timer.After(0.15, again)
    end
end

-- Recalcule l'apercu (apres un changement de theme : ses couleurs en dependent).
function DWE.RefreshPreview()
    UpdatePreview(DWE.lastQuestEvent)
end

-- Bascule popup / parchemin DialogueUI pendant un livre : les boutons de page changent.
function DWE.OnToggleBookView()
    if bookState.active then
        BuildOptions("ITEM_TEXT_CACHED")
        DWE.selectedIndex = 1
    end
end

function DWE.OnRewardSelected()
    -- Retenu pour l'ecran final de la meme quete (meme ordre des recompenses).
    DWE.rewardMemory = { questID = GetQuestID and GetQuestID() or 0, index = DWE.selectedRewardIndex }
    DWE.RefreshRewardSelection()
    for i, opt in ipairs(DWE.currentOptions) do
        if opt.isCompleteBtn then
            opt.disabled = false
            opt.icon = ICON_QUEST_ACTIVE
            DWE.selectedIndex = i
            break
        end
    end
    DWE.UpdateVisuals()
end

--------------------------------------------------------------------------------
-- Raccourcis clavier (actifs seulement pendant un dialogue, jamais en combat)
--------------------------------------------------------------------------------

local btnUp = CreateFrame("Button", "DWE_WheelUpBtn", UIParent)
local btnDown = CreateFrame("Button", "DWE_WheelDownBtn", UIParent)
local btnSelect = CreateFrame("Button", "DWE_SelectBtn", UIParent)
local btnToggleText = CreateFrame("Button", "DWE_ToggleTextKeyBtn", UIParent)

-- Molette : change de choix ; avec un clic de souris maintenu, zoome la camera.
local function MouseHeld()
    return IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")
end
btnUp:SetScript("OnClick", function()
    if MouseHeld() then CameraZoomIn(1) elseif not DWE.NoteScrollBy(1) then DWE.WheelStep(-1) end
end)
btnDown:SetScript("OnClick", function()
    if MouseHeld() then CameraZoomOut(1) elseif not DWE.NoteScrollBy(-1) then DWE.WheelStep(1) end
end)
btnSelect:SetScript("OnClick", function()
    local opt = DWE.currentOptions[DWE.selectedIndex]
    if opt and not opt.disabled and opt.action then opt.action() end
end)
btnToggleText:SetScript("OnClick", function() DWE.ToggleDialogueText() end)

-- Manette : boutons dedies (fermer, page precedente/suivante). Croix haut/bas et A
-- reutilisent les boutons de la molette et de la selection ci-dessus.
DWE.padClose = CreateFrame("Button", "DWE_PadCloseBtn", UIParent)
DWE.padClose:SetScript("OnClick", function() DWE.CloseAllDialogue() end)
DWE.padPrev = CreateFrame("Button", "DWE_PadPrevBtn", UIParent)
-- La croix gauche/droite surligne aussi le bouton de page utilise (comme un clic dessus).
function DWE.PadSelectLabel(label)
    for i, opt in ipairs(DWE.currentOptions or {}) do
        if opt.rawLabel == label and not opt.disabled then
            if DWE.selectedIndex ~= i then DWE.selectedIndex = i; DWE.UpdateVisuals() end
            return
        end
    end
end
DWE.padPrev:SetScript("OnClick", function()
    if not (DWE.bookMode and DWE.BookWheelTurn) then return end
    DWE.PadSelectLabel(L.PREV_PAGE)
    DWE.BookWheelTurn(1)
end)
DWE.padNext = CreateFrame("Button", "DWE_PadNextBtn", UIParent)
DWE.padNext:SetScript("OnClick", function()
    if not (DWE.bookMode and DWE.BookWheelTurn) then return end
    DWE.PadSelectLabel(L.NEXT_PAGE)
    DWE.BookWheelTurn(-1)
end)

-- Les fenetres du jeu restent ouvertes (invisibles) sous la roue et le livre : la navigation
-- manette du jeu peut alors prendre la croix et A pour elles. Un cadre qui recoit les boutons
-- de la manette en premier les garde pour l'addon ; les autres boutons passent au jeu.
DWE.PAD_ACTIONS = {
    PADDUP = "DWE_WheelUpBtn", PADDDOWN = "DWE_WheelDownBtn", PAD1 = "DWE_SelectBtn",
    PAD2 = "DWE_PadCloseBtn", PADDLEFT = "DWE_PadPrevBtn", PADDRIGHT = "DWE_PadNextBtn",
    PAD4 = "DWE_PadRibbonBtn",
}
-- Menu du ruban ouvert : la croix, A et B servent au menu.
DWE.PAD_RIBBON = { PADDLEFT = -1, PADDUP = -1, PADDRIGHT = 1, PADDDOWN = 1 }
DWE.padCatcher = CreateFrame("Frame", "DWE_PadCatcher", UIParent)
DWE.padCatcher:SetFrameStrata("FULLSCREEN_DIALOG")
DWE.padCatcher:SetSize(1, 1)
DWE.padCatcher:SetPoint("TOPLEFT")
DWE.padCatcher:Hide()
if DWE.padCatcher.EnableGamePadButton then
    DWE.padCatcher:EnableGamePadButton(true)
    -- En combat, on ne peut plus choisir quels boutons laisser passer : on se retire.
    DWE.padCatcher:RegisterEvent("PLAYER_REGEN_DISABLED")
    DWE.padCatcher:SetScript("OnEvent", function(self) self:Hide() end)
    DWE.padCatcher:SetScript("OnGamePadButtonDown", function(self, button)
        if DWE.RibbonPadOpen and DWE.RibbonPadOpen() then
            local d = DWE.PAD_RIBBON[button]
            local mine = d or button == "PAD1" or button == "PAD2" or button == "PAD4"
            if self.SetPropagateGamePadInput and not InCombatLockdown() then
                self:SetPropagateGamePadInput(not mine)
            end
            if d then DWE.RibbonPadMove(d)
            elseif button == "PAD1" then DWE.RibbonPadClick()
            elseif button == "PAD2" or button == "PAD4" then DWE.RibbonPadToggle() end
            return
        end
        if DWE.PadMenuOpen() then
            local d = DWE.PAD_RIBBON[button]
            local mine = d or button == "PAD1" or button == "PAD2" or button == "PAD4"
            if self.SetPropagateGamePadInput and not InCombatLockdown() then
                self:SetPropagateGamePadInput(not mine)
            end
            if d then DWE.PadMenuMove(d)
            elseif button == "PAD1" then DWE.PadMenuClick()
            elseif button == "PAD2" or button == "PAD4" then DWE.padMenu:Hide() end
            return
        end
        local target = (DWE.padInteract and DWE.padInteract[button]) and "DWE_SelectBtn" or DWE.PAD_ACTIONS[button]
        if button == "PAD4" and not DWE.PadMenuAvailable() then target = nil end -- Y reste au jeu
        local btn = target and rawget(_G, target)
        if self.SetPropagateGamePadInput and not InCombatLockdown() then
            self:SetPropagateGamePadInput(not btn)
        end
        if btn then
            local fn = btn:GetScript("OnClick")
            if fn then fn(btn) end
        end
    end)
end

-- Petit menu du bouton Y en conversation (dans un livre, Y ouvre le ruban) : le lecteur
-- Spoken (pause / reprise, passer). Meme allure que le ruban : icone, nom, surligne au choix.
DWE.padMenu = CreateFrame("Frame", "DWE_PadMenu", UIParent)
DWE.padMenu:SetFrameStrata("FULLSCREEN_DIALOG")
DWE.padMenu:SetSize(10, 30)
DWE.padMenu:Hide()
DWE.padMenu.items = {}
function DWE.PadMenuItems()
    if not (DWE.SpokenPlayerShown and DWE.SpokenPlayerShown()) then return {} end
    return {
        { label = DWE.L.PAD_SPOKEN_PAUSE, icon = "Interface\\Icons\\INV_Misc_PocketWatch_01", which = "play" },
        { label = DWE.L.PAD_SPOKEN_SKIP, icon = "Interface\\Icons\\Ability_Rogue_Sprint", which = "skip" },
    }
end
function DWE.PadMenuPaint()
    local m = DWE.padMenu
    for i, b in ipairs(m.items) do
        local on = i == m.idx
        b.text:SetTextColor(on and 1 or 0.85, on and 0.85 or 0.82, on and 0.2 or 0.75)
        b.line:SetShown(on)
    end
end
function DWE.PadMenuOpen() return DWE.padMenu:IsShown() end
-- Le lecteur Spoken disparait (lecture finie) : le menu s'en va avec lui.
DWE.padMenu:SetScript("OnUpdate", function(self, elapsed)
    self.check = (self.check or 0) + elapsed
    if self.check < 0.25 then return end
    self.check = 0
    if not (DWE.SpokenPlayerShown and DWE.SpokenPlayerShown()) then self:Hide() end
end)
-- Y sert-il a l'addon maintenant ? (ruban d'un livre, ou lecteur Spoken a l'ecran)
function DWE.PadMenuAvailable()
    if DWE.ribbon and DWE.ribbon:IsVisible() then return true end
    return DWE.SpokenPlayerShown and DWE.SpokenPlayerShown() or false
end
function DWE.PadMenuToggle()
    local m = DWE.padMenu
    if m:IsShown() then m:Hide() return true end
    local list = DWE.PadMenuItems()
    if #list == 0 then return false end
    local x = 0
    for i, item in ipairs(list) do
        local b = m.items[i]
        if not b then
            b = CreateFrame("Frame", nil, m)
            b:SetHeight(26)
            b.icon = b:CreateTexture(nil, "ARTWORK")
            b.icon:SetSize(16, 16)
            b.icon:SetPoint("CENTER", b, "LEFT", 8, 0)
            b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            b.text:SetPoint("LEFT", b, "LEFT", 22, 0)
            b.text:SetShadowColor(0, 0, 0, 1)
            b.text:SetShadowOffset(1, -1)
            b.line = b:CreateTexture(nil, "ARTWORK")
            b.line:SetColorTexture(0.85, 0.68, 0.30, 0.8)
            b.line:SetHeight(1)
            b.line:SetPoint("BOTTOMLEFT", b.text, "BOTTOMLEFT", 0, -3)
            b.line:SetPoint("BOTTOMRIGHT", b.text, "BOTTOMRIGHT", 0, -3)
            m.items[i] = b
        end
        b.item = item
        b.icon:SetTexture(item.icon)
        b.text:SetText(item.label)
        local w = ((b.text.GetStringWidth and b.text:GetStringWidth()) or 90) + 26
        b:SetWidth(w)
        b:ClearAllPoints()
        b:SetPoint("LEFT", m, "LEFT", x, 0)
        b:Show()
        x = x + w + 24
    end
    for i = #list + 1, #m.items do m.items[i]:Hide(); m.items[i].item = nil end
    m.count = #list
    m:SetWidth(math.max(10, x - 24))
    m:ClearAllPoints()
    if DWE.choiceBox and DWE.choiceBox:IsShown() then
        m:SetPoint("BOTTOM", DWE.choiceBox, "TOP", 0, 10)
    else
        m:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    end
    m.idx = 1
    DWE.PadMenuPaint()
    m:Show()
    return true
end
function DWE.PadMenuMove(d)
    local m = DWE.padMenu
    local n = m.count or 0
    if n == 0 then return end
    m.idx = ((m.idx or 1) - 1 + d) % n + 1
    DWE.PadMenuPaint()
end
function DWE.PadMenuClick()
    local m = DWE.padMenu
    local b = m.items[m.idx or 1]
    if b and b.item and DWE.SpokenPadPress then DWE.SpokenPadPress(b.item.which) end
end
-- Y : le ruban dans un livre, sinon le petit menu.
function DWE.PadMenuButton()
    if DWE.RibbonPadOpen and DWE.RibbonPadOpen() then return DWE.RibbonPadToggle() end
    if DWE.ribbon and DWE.ribbon:IsVisible() and DWE.RibbonPadToggle then return DWE.RibbonPadToggle() end
    return DWE.PadMenuToggle()
end

DWE.padRibbon = CreateFrame("Button", "DWE_PadRibbonBtn", UIParent)
DWE.padRibbon:SetScript("OnClick", function() DWE.PadMenuButton() end)
DWE.padSpoken = CreateFrame("Button", "DWE_PadSpokenBtn", UIParent)
DWE.padSpoken:SetScript("OnClick", function() if DWE.SpokenPadPress then DWE.SpokenPadPress("play") end end)
DWE.padSkip = CreateFrame("Button", "DWE_PadSkipBtn", UIParent)
DWE.padSkip:SetScript("OnClick", function() if DWE.SpokenPadPress then DWE.SpokenPadPress("skip") end end)

-- Lecteur miniature de Spoken a l'ecran, hors de tout dialogue : le bouton Share (PADSOCIAL :
-- Share PS4/Xbox Series, Create PS5) ou Vue / Back (PADBACK, Xbox One) le pilote.
-- Appui court : pause / reprise ; appui long : passer ; Share maintenu + Y : liste de la file.
-- Par des raccourcis temporaires sur ces seuls boutons (pas de cadre qui ecoute la manette :
-- le jeu garde la main sur tout le reste, interagir avec un livre ou un PNJ compris).
DWE.PAD_HOLD = 0.5
DWE.PAD_PLAYER_KEYS = { PADSOCIAL = true, PADBACK = true }
DWE.padPlayer = CreateFrame("Frame", "DWE_PadPlayer", UIParent) -- proprietaire des raccourcis
DWE.padPlayer:Hide()
local function PadBtn(name, fn)
    local b = CreateFrame("Button", name, UIParent)
    b:RegisterForClicks("AnyDown", "AnyUp")
    b:SetScript("OnClick", fn)
    return b
end
-- Pendant que Share est maintenu ou que la liste est ouverte (et seulement la), un cadre recoit
-- les boutons de la manette avant le jeu : Y (avec Share) ouvre la liste ; liste ouverte, la
-- croix choisit, A fait lire, Y retire, B referme. Tout le reste passe au jeu.
local function ListOpen()
    local ui = DWE.SpokenQueueUI
    return ui and ui.PadIsOpen and ui.PadIsOpen() or false
end
DWE.padList = CreateFrame("Frame", "DWE_PadList", UIParent)
DWE.padList:SetFrameStrata("FULLSCREEN_DIALOG")
DWE.padList:SetSize(1, 1)
DWE.padList:SetPoint("TOPLEFT")
DWE.padList:Hide()
function DWE.PadListRefresh()
    local want = (DWE.padPlayer.downAt or ListOpen()) and not InCombatLockdown()
    if want then DWE.padList:Show() else DWE.padList:Hide() end
end
function DWE.PadListClosed() DWE.PadListRefresh() end
if DWE.padList.EnableGamePadButton then
    DWE.padList:EnableGamePadButton(true)
    DWE.padList:SetScript("OnGamePadButtonDown", function(self, button)
        local ui = DWE.SpokenQueueUI
        local mine = false
        if ListOpen() and ui then
            mine = true
            if button == "PADDUP" then ui.PadMove(-1)
            elseif button == "PADDDOWN" then ui.PadMove(1)
            elseif button == "PAD1" then ui.PadPlay()
            elseif button == "PAD4" then ui.PadRemove()
            elseif button == "PAD2" then ui.PadClose()
            else mine = false end
        elseif DWE.padPlayer.downAt and button == "PAD4" and ui and ui.PadOpen then
            mine = true
            DWE.padPlayer.chord = true
            ui.PadOpen()
        end
        if DWE.PAD_PLAYER_KEYS[button] then mine = false end -- Share reste a son raccourci
        if self.SetPropagateGamePadInput and not InCombatLockdown() then self:SetPropagateGamePadInput(not mine) end
        DWE.PadListRefresh()
    end)
end
PadBtn("DWE_PadShare", function(_, _, down)
    local p = DWE.padPlayer
    if down ~= false then
        DWE.padLastButton = "share"
        p.downAt, p.chord = GetTime and GetTime() or 0, nil
        p.listAtDown = ListOpen()
        DWE.PadListRefresh()
        return
    end
    if not p.downAt then return end
    local held = (GetTime and GetTime() or 0) - p.downAt
    local chord, wasOpen = p.chord, p.listAtDown
    p.downAt, p.chord, p.listAtDown = nil, nil, nil
    DWE.PadListRefresh()
    if chord then return end
    if wasOpen then
        if DWE.SpokenQueueUI then DWE.SpokenQueueUI.PadClose() end
        DWE.PadListRefresh()
        return
    end
    -- Plus que des lignes a la demande (petit bouton a la place du lecteur) : Share ouvre la file.
    local ui = DWE.SpokenQueueUI
    if not (DWE.SpokenPlayerShown and DWE.SpokenPlayerShown()) and ui and ui.NoticeShown and ui.NoticeShown() then
        ui.PadOpen()
        DWE.PadListRefresh()
        return
    end
    if DWE.SpokenPadPress then DWE.SpokenPadPress(held >= DWE.PAD_HOLD and "skip" or "play") end
end)
do
    local watch = CreateFrame("Frame", "DWE_PadPlayerWatch")
    local acc = 0
    watch:RegisterEvent("PLAYER_REGEN_DISABLED")
    watch:SetScript("OnEvent", function()
        -- Entree en combat : tous les raccourcis du lecteur sont rendus tout de suite.
        ClearOverrideBindings(DWE.padPlayer)
        DWE.padPlayer:Hide()
        DWE.padPlayer.downAt = nil
        DWE.padList:Hide()
    end)
    watch:SetScript("OnUpdate", function(_, elapsed)
        acc = acc + elapsed
        if acc < 0.25 then return end
        acc = 0
        if InCombatLockdown() then return end
        local p = DWE.padPlayer
        DWE.PadListRefresh()
        local ui = DWE.SpokenQueueUI
        local want = DWE.GamePadOn and DWE.GamePadOn() and ((DWE.SpokenPlayerShown and DWE.SpokenPlayerShown())
            or (ui and ui.NoticeShown and ui.NoticeShown()))
        if want and not p:IsShown() then
            p:Show()
            for key in pairs(DWE.PAD_PLAYER_KEYS) do SetOverrideBindingClick(p, true, key, "DWE_PadShare") end
        elseif not want and p:IsShown() and not ListOpen() then
            ClearOverrideBindings(p)
            p.downAt = nil
            p:Hide()
        end
    end)
    DWE.padPlayerWatch = watch
end

-- Mode manette du jeu actif (option du jeu ou /console GamePadEnable 1).
function DWE.GamePadOn()
    if DialogueWheelE_GamePad == false then return false end
    if C_GamePad and C_GamePad.IsEnabled then
        local ok, on = pcall(C_GamePad.IsEnabled)
        if ok and on then return true end
    end
    local cv = GetCVar and GetCVar("GamePadEnable")
    return cv ~= nil and tostring(cv) == "1"
end

-- Touche d'interaction du jeu active : option "Touche d'interaction" activee (CVar
-- SoftTargetInteract) et une touche reglee pour "Interagir avec la cible".
function DWE.BlizzInteractOn()
    -- 0 = desactivee, 1 = manette seulement, 2 = clavier/souris, 3 = toujours.
    local cv = GetCVar and GetCVar("SoftTargetInteract")
    if cv ~= nil and tostring(cv) ~= "2" and tostring(cv) ~= "3" then return false end
    return (GetBindingKey and GetBindingKey("INTERACTTARGET")) ~= nil
end

function DWE.GetEffectiveInteractKey()
    if DialogueWheelE_UseBlizzKey == false then
        return NonEmpty(DialogueWheelE_InteractKey)
    end
    return GetBindingKey and GetBindingKey("INTERACTTARGET") or nil
end

-- Touche "Dialogue" (texte de l'addon <-> fenetre Spoken/DialogueUI) : aucune par defaut.
function DWE.GetToggleKey()
    -- Seulement avec Spoken (bascule bulle de l'addon <-> lecteur de Spoken).
    if not (DWE.SpokenFocus and DWE.SpokenFocus.Available()) then return nil end
    if DialogueWheelE_ToggleKey == nil then return nil end
    return NonEmpty(DialogueWheelE_ToggleKey)
end

local keysEnabled = false

-- Echap ferme la conversation : un cadre invisible inscrit dans UISpecialFrames (la liste
-- des fenetres que le jeu ferme avec Echap, comme les sacs). Il est affiche pendant la
-- conversation ; quand Echap le ferme, on ferme la conversation comme "Au revoir".
-- Aucune touche n'est prise : hors conversation, Echap marche comme d'habitude.
local escCatcher = CreateFrame("Frame", "DialogueWheelEEscapeCatcher", UIParent)
escCatcher:Hide()
if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "DialogueWheelEEscapeCatcher") end
escCatcher:SetScript("OnHide", function(self)
    if self.silent then self.silent = nil return end
    DWE.CloseAllDialogue()
    DisableKeys()
end)

local function ArmEscape()
    if DialogueWheelE_EscClose ~= false then escCatcher:Show() end
end

local function DisarmEscape()
    if escCatcher:IsShown() then
        escCatcher.silent = true
        escCatcher:Hide()
    end
end

local function EnableKeys()
    if keysEnabled or InCombatLockdown() then return end
    keysEnabled = true
    DWE.needBindingClear = false
    if DialogueWheelE_WheelScroll ~= false then
        SetOverrideBindingClick(f, true, "MOUSEWHEELUP", "DWE_WheelUpBtn")
        SetOverrideBindingClick(f, true, "MOUSEWHEELDOWN", "DWE_WheelDownBtn")
    end
    local toggle = DWE.GetToggleKey()
    if toggle then SetOverrideBindingClick(f, true, toggle, "DWE_ToggleTextKeyBtn") end
    local interact = DWE.GetEffectiveInteractKey()
    if interact then SetOverrideBindingClick(f, true, interact, "DWE_SelectBtn") end
    -- Toutes les touches liees a "Interagir avec la cible" (clavier et manette), pas
    -- seulement la premiere.
    DWE.padInteract = {}
    if interact then DWE.padInteract[interact] = true end
    if DialogueWheelE_UseBlizzKey ~= false and GetBindingKey then
        for _, k in ipairs({ GetBindingKey("INTERACTTARGET") }) do
            if k then DWE.padInteract[k] = true end
            if k and k ~= interact then SetOverrideBindingClick(f, true, k, "DWE_SelectBtn") end
        end
    end
    if DWE.GamePadOn() then
        SetOverrideBindingClick(f, true, "PADDUP", "DWE_WheelUpBtn")
        SetOverrideBindingClick(f, true, "PADDDOWN", "DWE_WheelDownBtn")
        SetOverrideBindingClick(f, true, "PAD1", "DWE_SelectBtn")
        SetOverrideBindingClick(f, true, "PAD2", "DWE_PadCloseBtn")
        SetOverrideBindingClick(f, true, "PADDLEFT", "DWE_PadPrevBtn")
        SetOverrideBindingClick(f, true, "PADDRIGHT", "DWE_PadNextBtn")
        if DWE.padCatcher.EnableGamePadButton then DWE.padCatcher:Show() end
    end
end

-- Applique tout de suite un changement de touche fait dans les options.
function DWE.RefreshBindings()
    if not keysEnabled or InCombatLockdown() then return end
    ClearOverrideBindings(f)
    DWE.padCatcher:Hide()
    keysEnabled = false
    EnableKeys()
end

function DisableKeys()
    DisarmEscape()
    DWE.padCatcher:Hide()
    DWE.padMenu:Hide()
    keysEnabled = false
    DWE.lastQuestEvent = nil
    ResetBook(false)
    DWE.needsItemRefresh = false
    DWE.selectedRewardIndex = nil
    DWE.hasDialogueText = false
    DWE.currentOptions = {}
    DWE.HideRewardButtons()
    DWE.textBox:Hide()
    DWE.choiceBox:Hide()
    GameTooltip:Hide()
    if InCombatLockdown() then
        DWE.needBindingClear = true
        return
    end
    DWE.needBindingClear = false
    ClearOverrideBindings(f)
end

--------------------------------------------------------------------------------
-- Commande /dwe npc : diagnostic du suivi du PNJ (a taper pendant une conversation)
--------------------------------------------------------------------------------

local function Out(msg) DEFAULT_CHAT_FRAME:AddMessage("|cff33ccff[Storytale]|r " .. msg) end
local function Safe(fn, ...)
    local ok, a, b = pcall(fn, ...)
    if not ok then return "erreur" end
    return tostring(a) .. (b ~= nil and (" " .. tostring(b)) or "")
end

local function DiagnoseNPC()
    Out("taille du PNJ : " .. tostring(DWE.NPCHeight and DWE.NPCHeight() or "?") .. " (facteur " .. tostring(DWE.NPCSizeFactor and DWE.NPCSizeFactor() or "?") .. ")")
    Out("npc existe=" .. Safe(UnitExists, "npc") .. " nom=" .. Safe(UnitName, "npc")
        .. " | softinteract existe=" .. Safe(UnitExists, "softinteract") .. " =npc:" .. Safe(UnitIsUnit, "softinteract", "npc"))
    local cvars = {}
    for _, k in ipairs({ "SoftTargetInteract", "SoftTargetNameplateInteract", "nameplateShowFriends", "nameplateShowFriendlyNPCs", "nameplateShowAll" }) do
        cvars[#cvars + 1] = k .. "=" .. tostring(GetCVar and GetCVar(k))
    end
    Out("CVars : " .. table.concat(cvars, ", "))
    if not C_NamePlate then Out("C_NamePlate absent") return end
    local soft = C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit("softinteract")
    Out("plaque softinteract : " .. (soft and ("trouvee, interdite=" .. Safe(soft.IsForbidden, soft) .. " visible=" .. Safe(soft.IsVisible, soft)) or "aucune"))
    local plates = C_NamePlate.GetNamePlates and C_NamePlate.GetNamePlates() or {}
    Out(#plates .. " plaque(s) lisible(s)")
    for i, plate in ipairs(plates) do
        local token = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
        Out(("  %d. %s nom=%s =npc:%s visible=%s"):format(i, tostring(token), Safe(UnitName, token), Safe(UnitIsUnit, token, "npc"), Safe(plate.IsVisible, plate)))
    end
    Out("suivi actif=" .. tostring(DWE.IsFollowingNPC()) .. " option=" .. tostring(DialogueWheelE_AttachNPC ~= false))
end

SLASH_DIALOGUEWHEELE1 = "/storytale"
SLASH_DIALOGUEWHEELE2 = "/dwe"
SlashCmdList.DIALOGUEWHEELE = function(msg)
    msg = (msg or ""):lower()
    if msg:match("npc") then
        DiagnoseNPC()
    elseif msg:match("^errors") then
        DWE.ErrorsReport(msg:match("^errors%s+(%S+)"))
    elseif msg:match("forget") then
        local n = DWE.SpokenFocus and DWE.SpokenFocus.ForgetOpenBook and DWE.SpokenFocus.ForgetOpenBook() or 0
        Out("livre ouvert considere comme jamais ecoute (" .. n .. " ligne(s) oubliee(s)).")
    elseif msg:match("^%s*pad") then
        -- Diagnostic manette : ce que Storytale voit (a taper avec le lecteur Spoken affiche).
        Out("manette=" .. tostring(DWE.GamePadOn and DWE.GamePadOn()) .. " lecteurSpoken=" .. tostring(DWE.SpokenPlayerShown and DWE.SpokenPlayerShown())
            .. " ecoute=" .. tostring(DWE.padPlayer and DWE.padPlayer:IsShown()) .. " dernierBouton=" .. tostring(DWE.padLastButton))
    elseif msg:match("spoken") then
        if DWE.SpokenFocus then DWE.SpokenFocus.Install(); DWE.SpokenFocus.Report() end
    elseif msg:match("^%s*plate") then
        -- Test : force une matiere de plaque sur le texte ouvert (et les suivants) jusqu'a "off".
        local arg = (msg:match("plate%s+(%a+)") or ""):lower()
        local names = { stone = "Stone", marble = "Marble", bronze = "Bronze", silver = "Silver" }
        DWE.testPlate = names[arg]
        if DWE.testPlate then
            Out("plaque de test : " .. DWE.testPlate .. " (/storytale plate off pour arreter)")
        else
            Out("plaque de test arretee. Usage : /storytale plate stone | marble | bronze | silver | off")
        end
        if DWE.bookMode and DWE.UpdateTextPanelVisuals then DWE.UpdateTextPanelVisuals() end
        if DWE.RefreshSpoken then DWE.RefreshSpoken() end
    elseif msg:match("material") then
        local m = ItemTextGetMaterial and ItemTextGetMaterial()
        Out("matiere du texte ouvert : " .. tostring(m) .. (m and DWE.PLATES[m] and " (plaque)" or ""))
    elseif msg:match("reset") then
        DWE.AskResetAll()
    elseif msg:match("perf") then
        Out("Pret : parle a un PNJ, la mesure demarre quand le texte commence a s'ecrire.")
        DWE.ArmPerf(Out)
    else
        Out("/dwe npc : diagnostic du suivi du PNJ")
        Out("/dwe perf : mesure ce que l'addon coute en images/s")
        Out("/storytale reset : remet toutes les options par defaut")
    end
end

--------------------------------------------------------------------------------
-- Evenements
--------------------------------------------------------------------------------

local CLOSE_EVENTS = { GOSSIP_CLOSED = true, QUEST_FINISHED = true, ITEM_TEXT_CLOSED = true }

local function OnBookReady()
    local p = StoreCurrentBookPage()
    -- Note : on demande les pages suivantes au jeu jusqu'a la derniere.
    if DWE.BookLook() == "note" and ItemTextHasNextPage and ItemTextHasNextPage() and ItemTextNextPage
        and ItemTextGetPage and ItemTextGetPage() == p then
        bookState.fetchingAll = true
        ItemTextNextPage()
        return
    end
    bookState.fetchingAll = nil
    if bookState.title == "" then
        bookState.title = NonEmpty(ItemTextGetItem and ItemTextGetItem()) or ""
    end
    -- Page demandee par "Page suivante" : on l'affiche.
    if bookState.awaitNext and p == bookState.currentPage + 1 then
        bookState.awaitNext = nil
        bookState.currentPage = p
        if DWE.bookFollowPause and DWE.VoiceToPage then DWE.VoiceToPage(p) end -- page tournee a la main
    end
    if DWE.BookResumeStep() then return end
    if not DWE.choiceBox:IsShown() then return end
    ShowBookPage(bookState.currentPage)
    BuildOptions("ITEM_TEXT_CACHED", true)
end

f:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        -- L'ancien dossier DialogueWheelE (avant le nom Storytale) ne doit plus etre installe.
        local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
        if loaded and loaded("DialogueWheelE") then
            print("|cff33ff99Storytale|r: " .. (GetLocale() == "frFR"
                and "supprime l'ancien dossier |cffffd200Interface\\AddOns\\DialogueWheelE|r (l'addon s'appelle maintenant Storytale)."
                or "please delete the old |cffffd200Interface\\AddOns\\DialogueWheelE|r folder (the addon is now called Storytale)."))
        end
        -- Premiere installation : bulle d'Azeroth, texte affiche par l'addon.
        if DialogueWheelE_Theme == nil then DialogueWheelE_Theme = "bubble" end
        if DialogueWheelE_ShowText == nil then DialogueWheelE_ShowText = true end
        -- Nouveaux reglages par defaut (1.2), appliques une fois a tout le monde.
        if (tonumber(DialogueWheelE_DefaultsV) or 0) < 2 then
            DialogueWheelE_DefaultsV = 2
            DialogueWheelE_WheelTheme = true
            if DialogueWheelE_FontSize == nil or tonumber(DialogueWheelE_FontSize) == 13 then DialogueWheelE_FontSize = 14 end
            if DialogueWheelE_ToggleKey == "T" then DialogueWheelE_ToggleKey = nil end
        end
        -- Touche de choix : celle du jeu ("Interagir avec la cible") si le joueur en a une,
        -- sinon une touche de l'addon, E par defaut.
        -- (1.2) Une fois : coche "touche du jeu" sans touche reglee dans le jeu -> touche E.
        if (tonumber(DialogueWheelE_DefaultsV) or 0) < 5 then
            DialogueWheelE_DefaultsV = 5
            if DialogueWheelE_UseBlizzKey == true and not DWE.BlizzInteractOn() then
                DialogueWheelE_UseBlizzKey = nil
            end
        end
        -- (1.3.6) Une fois : infobulle des livres a la souris, activee aussi pour les joueurs
        -- qui mettent a jour (ils peuvent la decocher ensuite : false reste false).
        if (tonumber(DialogueWheelE_DefaultsV) or 0) < 6 then
            DialogueWheelE_DefaultsV = 6
            if DialogueWheelE_BookTipCursor == nil then DialogueWheelE_BookTipCursor = true end
        end
        if DialogueWheelE_UseBlizzKey == nil then
            local on = DWE.BlizzInteractOn()
            DialogueWheelE_UseBlizzKey = on and true or false
            if not on and DialogueWheelE_InteractKey == nil then DialogueWheelE_InteractKey = "E" end
        end
        -- Lecteur Spoken habille du theme des que Spoken est la (meme installe plus tard),
        -- sauf si le joueur a decoche l'option (false).
        if DialogueWheelE_SpokenTheme == nil then
            local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
            if isLoaded and isLoaded("Spoken") then DialogueWheelE_SpokenTheme = true end
        end
        SetupDialogueUI()
        DWE.HookSpoken()
        DWE.RestorePosition()
        DWE.RestoreTextPosition()
        DWE.InitOptionsPanel()
        DWE.ApplyFont()
        DWE.ApplyScale()
        DWE.ApplyTextTheme()
        DWE.ApplyLock()
        return
    elseif event == "MODIFIER_STATE_CHANGED" then
        local btn = DWE.hoveredRewardBtn
        if btn and btn:IsShown() then DWE.ShowRewardTooltip(btn) end
        return
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        if DWE.needsItemRefresh and DWE.lastQuestEvent and DWE.choiceBox:IsShown() then
            UpdatePreview(DWE.lastQuestEvent)
        end
        return
    elseif event == "PLAYER_REGEN_DISABLED" then
        DisableKeys()
        return
    elseif event == "PLAYER_REGEN_ENABLED" then
        if DWE.needBindingClear then
            ClearOverrideBindings(f)
            DWE.needBindingClear = false
        end
        DWE.RestoreNameplateCVar()
        return
    elseif CLOSE_EVENTS[event] then
        if event == "ITEM_TEXT_CLOSED" then
            DWE.ForceBlizzBook(event)
            if bookState.reachedEnd then DWE.MarkBook(bookState.title, true) end
            DWE.bookResumeHold = nil
            -- Option : fermer le livre coupe sa lecture par Spoken (le reste de la file continue).
            if DialogueWheelE_BookStopOnClose == true then
                local sr = rawget(_G, "SpokenReadables")
                if type(sr) == "table" and sr.lastPage and sr.PlaceOf and sr.StopReading then
                    local ok, place = pcall(sr.PlaceOf, sr, sr.lastPage)
                    if ok and place then pcall(sr.StopReading, sr, place) end
                end
                if DWE.SpokenFocus and DWE.SpokenFocus.StopBooks then DWE.SpokenFocus.StopBooks() end
            end
        end
        if event ~= "ITEM_TEXT_CLOSED" and DWE.SpokenFocus then
            DWE.SpokenFocus.SetNPC(false)
            DWE.SpokenFocus.gossipPage = 0
        end
        if event == "ITEM_TEXT_CLOSED" and DWE.SpokenFocus then DWE.SpokenFocus.OnBookClosed() end
        DisableKeys()
        return
    end

    -- Livres : selon l'option, la roue de l'addon (avec un theme parchemin, jamais en bulle),
    -- ou on laisse faire le livre de DialogueUI / la fenetre du jeu.
    if event == "ITEM_TEXT_BEGIN" then
        DWE.lastBookStyle = DWE.BookStyleNow()
        DWE.MarkBook(ItemTextGetItem and ItemTextGetItem(), false)
    end
    if BOOK_EVENTS[event] and DWE.BookStyleNow() ~= "addon" then
        if DWE.BookStyleNow() == "blizzard" then DWE.ForceBlizzBook(event) end
        return
    end
    DWE.SetBookMode(BOOK_EVENTS[event] and true or false)
    -- Conversation avec un PNJ : un livre lu par Spoken s'efface devant elle.
    if DWE.SpokenFocus then
        DWE.SpokenFocus.Install()
        if not BOOK_EVENTS[event] then DWE.SpokenFocus.SetNPC(true) end
        -- Pages de dialogue : la 1re est la salutation ; les suivantes (on a choisi un sujet,
        -- ex. "parlez-moi de cet endroit") sont des repliques demandees. Une quete repart a zero.
        if event == "GOSSIP_SHOW" then
            DWE.SpokenFocus.gossipPage = (DWE.SpokenFocus.gossipPage or 0) + 1
            if DWE.SpokenFocus.WatchPage then DWE.SpokenFocus.WatchPage() end
        elseif QUEST_EVENTS and QUEST_EVENTS[event] then
            DWE.SpokenFocus.gossipPage = 0
            if DWE.SpokenFocus.WatchPage then DWE.SpokenFocus.WatchPage(event) end
        elseif event == "QUEST_GREETING" then
            if DWE.SpokenFocus.WatchPage then DWE.SpokenFocus.WatchPage(event) end
        end
    end

    if event == "ITEM_TEXT_BEGIN" then
        DWE.bookSpokenView = false
        DWE.bookInfo = nil
        ResetBook(true, NonEmpty(ItemTextGetItem and ItemTextGetItem()) or NonEmpty(UnitName("npc")) or "")
        do
            -- "Lecture a voix haute" coupee par le joueur : le livre s'ouvre muet (reglage retenu).
            if DialogueWheelE_BookVoiceOff == true and DWE.SpokenFocus then DWE.SpokenFocus.bookMuted = true end
            local marks, key = rawget(_G, "DialogueWheelE_Bookmarks"), DWE.BookKey(bookState.title)
            local page = key and type(marks) == "table" and tonumber(marks[key])
            DWE.bookResumeHold = nil
            if page and page > 1 then bookState.resumeTo = page; DWE.bookResumeHold = page end
        end
        DWE.SetDialogueText(bookState.title, "")
    elseif event == "ITEM_TEXT_READY" then
        if not bookState.active then ResetBook(true, "") end
        if DWE.choiceBox:IsShown() then
            OnBookReady()
            return
        end
        local sp = StoreCurrentBookPage()
        -- Note : on charge aussi les pages suivantes, pour tout montrer d'un coup.
        if DWE.BookLook() == "note" and ItemTextHasNextPage and ItemTextHasNextPage() and ItemTextNextPage
            and ItemTextGetPage and ItemTextGetPage() == sp then
            ItemTextNextPage()
        end
        if bookState.title == "" then
            bookState.title = NonEmpty(ItemTextGetItem and ItemTextGetItem()) or ""
        end
        if bookState.resumeTo then
            if bookState.awaitNext and sp == bookState.currentPage + 1 then
                bookState.awaitNext = nil
                bookState.currentPage = sp
            end
            if DWE.BookResumeStep() then return end
        end
        ShowBookPage(bookState.currentPage)
    end

    -- Ecran final apres "Terminer la quete" : on valide aussitot avec la recompense choisie.
    if event == "QUEST_COMPLETE" and DWE.autoReward then
        local ar = DWE.autoReward
        DWE.autoReward = nil
        local qid = GetQuestID and GetQuestID() or 0
        local n = GetNumQuestChoices and GetNumQuestChoices() or 0
        if ar.questID == qid and GetQuestReward and (n <= 1 or (ar.index and ar.index <= n)) then
            GetQuestReward(ar.index or 1)
            return
        end
    elseif event ~= "QUEST_FINISHED" and event ~= "QUEST_PROGRESS" then
        DWE.autoReward = nil
    end

    BuildOptions(event)
    if #DWE.currentOptions > 0 then
        EnableKeys()
        ArmEscape()
    else
        DisableKeys()
    end
end)

-- "Fenetre du jeu" alors que DialogueUI remplace les livres : on coupe son module de livre le
-- temps de ce texte, la fenetre du jeu reprend ses evenements, puis on le rallume.
function DWE.ForceBlizzBook(event)
    local itf = rawget(_G, "ItemTextFrame")
    if not itf then return end
    if event == "ITEM_TEXT_BEGIN" then
        if DWE.blizzForced or not GetFramesRegisteredForEvent then return end
        for _, fr in ipairs({ GetFramesRegisteredForEvent("ITEM_TEXT_BEGIN") }) do
            if type(fr) == "table" and type(fr.EnableModule) == "function" and fr.enabled and fr ~= itf then
                if pcall(fr.EnableModule, fr, false) then DWE.blizzForced = fr end
                break
            end
        end
        if DWE.blizzForced then
            local h = itf:GetScript("OnEvent")
            if h then pcall(h, itf, event) end
            -- Comme avec les autres styles : le petit lecteur Spoken attend la fermeture du texte.
            local fr = DWE.SpokenMiniFrame()
            if fr then
                if not fr.dweBlizzHook then
                    fr.dweBlizzHook = true
                    hooksecurefunc(fr, "SetAlpha", function(f2, a)
                        if a > 0 and DWE.blizzForced then f2:SetAlpha(0) end
                    end)
                end
                fr:SetAlpha(0)
            end
        end
    elseif event == "ITEM_TEXT_CLOSED" and DWE.blizzForced then
        local fr = DWE.blizzForced
        DWE.blizzForced = nil
        C_Timer.After(0, function()
            if not fr.enabled then pcall(fr.EnableModule, fr, true) end
            local mini = DWE.SpokenMiniFrame()
            if mini and not DWE.blizzForced then mini:SetAlpha(1) end
        end)
    end
end

function DWE.SpokenMiniFrame()
    local env = rawget(_G, "SpokenEnv")
    local sk = type(env) == "table" and rawget(env, "DialogueUIPlayer")
    local fr = type(sk) == "table" and sk.frame
    return type(fr) == "table" and fr.SetAlpha and fr or nil
end

-- Livres lus / pas encore finis (par personnage), reconnus a leur titre.
-- 1 = commence, 2 = lu jusqu'au bout (derniere page atteinte, ou narre en entier par Spoken).
function DWE.BookKey(title)
    if type(title) ~= "string" or (issecretvalue and issecretvalue(title)) then return nil end
    local k = title:gsub("%s*%(%d+%s*/%s*%d+%)%s*$", ""):gsub("^%s+", ""):gsub("%s+$", ""):lower()
    return k ~= "" and k or nil
end
function DWE.MarkBook(title, done)
    local k = DWE.BookKey(title)
    if not k then return end
    if type(DialogueWheelE_ReadBooks) ~= "table" then DialogueWheelE_ReadBooks = {} end
    local cur = DialogueWheelE_ReadBooks[k] or 0
    DialogueWheelE_ReadBooks[k] = math.max(cur, done and 2 or 1)
end
function DWE.BookState(title)
    local k = DWE.BookKey(title)
    local t = rawget(_G, "DialogueWheelE_ReadBooks")
    return k and type(t) == "table" and t[k] or nil
end
DWE.READ_ICON = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14|t"
-- Infobulle d'un objet du monde (livre, plaque) : deja lu, ou commence sans etre fini.
if GameTooltip and GameTooltip.HookScript then
    -- Infobulle d'un livre a la souris (option) : elle suit le curseur, donc l'objet survole.
    local function AtCursor(tt)
        local x, y = GetCursorPosition()
        local s = UIParent:GetEffectiveScale()
        tt.dweAnchoring = true
        tt:ClearAllPoints()
        tt:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x / s + 18, y / s + 12)
        tt.dweAnchoring = nil
    end
    -- Le jeu reecrit l'infobulle d'un objet du monde en continu (elle perdait notre ligne :
    -- clignotement) : on la remet a chaque fois qu'elle manque.
    local function Mark(tt, text, r, g, b)
        tt.dweMark = { text, r, g, b }
        DWE.tipBusy = true
        tt:AddLine(text, r, g, b)
        pcall(tt.Show, tt)
        DWE.tipBusy = nil
    end
    DWE.TipMark = Mark
    -- Ligne voulue pour ce titre, selon l'etat du moment (lecture en cours, lu, commence, jamais).
    local function Desired(title)
        if DialogueWheelE_ReadMarks == false then return nil end
        -- Avec Spoken : tant que le livre est dans sa file (lu, en pause ou en attente), on le lit.
        local f = DWE.SpokenFocus
        if f and f.BookQueued and f.BookQueued(DWE.BookKey(title)) then
            return DWE.L.BOOK_READING, 0.55, 0.8, 1
        end
        local st = DWE.BookState(title)
        if not st then
            local data = rawget(_G, "SpokenReadablesData")
            local idx = type(data) == "table" and data.index
            if type(idx) == "table" and idx[title] then return DWE.L.BOOK_NEW, 1, 0.82, 0 end
            return nil
        end
        if st >= 2 then return DWE.READ_ICON .. " " .. DWE.L.BOOK_READ, 0.6, 0.6, 0.6 end
        return DWE.L.BOOK_UNFINISHED, 1, 0.82, 0
    end
    GameTooltip:HookScript("OnUpdate", function(tt, elapsed)
        if tt.dweAtCursor then AtCursor(tt) end
        -- Titre rempli par le jeu apres l'affichage (sans OnShow ni Show) : on re-evalue.
        if not DWE.tipBusy and DWE.TipEvaluate then
            local line = rawget(_G, "GameTooltipTextLeft1")
            local okT, t = pcall(line and line.GetText or function() end, line)
            if okT and not (issecretvalue and issecretvalue(t)) and t ~= tt.dweSeen then
                DWE.TipEvaluate(tt)
                tt.dweSeen = t
            end
        end
        local m = tt.dweMark
        if m and not DWE.tipBusy and tt:NumLines() < 2 then Mark(tt, m[1], m[2], m[3], m[4]) end
        -- Etiquette en temps reel (ex. la lecture commence ou se termine pendant le survol).
        if tt.dweTitle then
            tt.dweTick = (tt.dweTick or 0) + (elapsed or 0)
            if tt.dweTick >= 0.2 then
                tt.dweTick = 0
                local text, r, g, b = Desired(tt.dweTitle)
                local line2 = rawget(_G, "GameTooltipTextLeft2")
                if text and m and text ~= m[1] and line2 then
                    tt.dweMark = { text, r, g, b }
                    line2:SetText(text)
                    line2:SetTextColor(r, g, b)
                    DWE.tipBusy = true
                    pcall(tt.Show, tt)
                    DWE.tipBusy = nil
                end
            end
        end
    end)
    GameTooltip:HookScript("OnHide", function(tt)
        tt.dweAtCursor, tt.dweMark, tt.dweTitle, tt.dweSeen = nil, nil, nil, nil
    end)
    -- Souris partie du livre : le jeu fait s'estomper l'infobulle (et notre Show relance
    -- l'estompage, d'ou une infobulle qui trainait). Pour un livre : disparition immediate.
    if hooksecurefunc and GameTooltip.FadeOut then
        hooksecurefunc(GameTooltip, "FadeOut", function(tt)
            if tt.dweTitle then tt:Hide() end
        end)
    end
    -- Meme image que la reecriture du jeu (il rappelle Show apres SetText) : la ligne et la place
    -- sont remises avant l'affichage, sans une image de titre seul.
    if hooksecurefunc then
        hooksecurefunc(GameTooltip, "Show", function(tt)
            if DWE.tipBusy then return end
            -- Infobulle deja ouverte qui passe a un autre objet (pas de OnShow) : on re-evalue.
            local line = rawget(_G, "GameTooltipTextLeft1")
            local okT, t = pcall(line and line.GetText or function() end, line)
            if okT and t ~= tt.dweSeen and DWE.TipEvaluate then
                DWE.tipBusy = nil
                DWE.TipEvaluate(tt)
                return
            end
            if tt.dweAtCursor then AtCursor(tt) end
            local m = tt.dweMark
            if m and tt:NumLines() < 2 then Mark(tt, m[1], m[2], m[3], m[4]) end
        end)
    end
    -- Le jeu re-place l'infobulle (coin de l'ecran) quand il la reecrit : sans ca elle avait deux
    -- ancres a la fois (coin + souris) et s'etirait sur tout l'ecran un instant.
    if hooksecurefunc and rawget(_G, "GameTooltip_SetDefaultAnchor") then
        hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tt)
            if tt == GameTooltip and tt.dweAtCursor then AtCursor(tt) end
        end)
    end
    if hooksecurefunc then
        hooksecurefunc(GameTooltip, "SetPoint", function(tt)
            if tt.dweAtCursor and not tt.dweAnchoring and tt:GetNumPoints() > 1 then AtCursor(tt) end
        end)
    end
    local function Evaluate(tt)
        tt.dweMark, tt.dweTitle = nil, nil
        if tt.GetUnit and tt:GetUnit() then return end
        if tt.GetItem and tt:GetItem() then return end
        local line = rawget(_G, "GameTooltipTextLeft1")
        local ok, title = pcall(line and line.GetText or function() end, line)
        if not ok or type(title) ~= "string" or (issecretvalue and issecretvalue(title)) then return end
        local data = rawget(_G, "SpokenReadablesData")
        local known = DWE.BookState(title) or (type(data) == "table" and type(data.index) == "table" and data.index[title])
        if known and DialogueWheelE_BookTipCursor == true and tt:GetOwner() == UIParent then
            tt.dweAtCursor = true
            AtCursor(tt)
        else
            tt.dweAtCursor = nil
        end
        tt.dweSeen = title
        if known then tt.dweTitle = title end
        local text, r, g, b = Desired(title)
        if text then Mark(tt, text, r, g, b) end
    end
    DWE.TipEvaluate = Evaluate
    GameTooltip:HookScript("OnShow", function(tt)
        if DWE.tipBusy then return end
        Evaluate(tt)
    end)
end

-- Evenements surveilles (voir DWE.Guard) : une erreur est notee, jamais coupee.
if DWE.GuardScripts then DWE.GuardScripts(f, "events") end
