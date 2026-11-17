-- Prints every visible color/text/shadow of the wheel and preview for a set of scenarios.
package.path = "./?.lua;" .. package.path
local dir = arg[1]
local M = require("wow_mock"); M.Install("frFR")
M.addonDir = dir
SlashCmdList = {}; DEFAULT_CHAT_FRAME = { AddMessage = function() end }
C_AddOns = { IsAddOnLoaded = function() return false end }
for _, f in ipairs({ "Locales.lua", "Storytale_Core.lua", "Bubble.lua", "Storytale.lua" }) do
    local fn = loadfile(dir .. "/" .. f); if fn then fn() end
end
M.FireEvent("PLAYER_LOGIN")
local out = {}
local function dump(tag)
    for i, o in ipairs(DWE.currentOptions) do
        local row = DWE.GetRow(i)
        out[#out + 1] = tag .. " row" .. i .. " " .. tostring(o.rawLabel) .. " color=" .. tostring(row.text._color) .. " shadow=" .. tostring(row.text._shadow)
    end
    for _, k in ipairs({ "objLine", "reqHeader", "rewLine", "chooseHeader" }) do
        out[#out + 1] = tag .. " " .. k .. " text=" .. tostring(DWE[k]:GetText()) .. " shadow=" .. tostring(DWE[k]._shadow) .. " shown=" .. tostring(DWE[k]:IsShown())
    end
    for i = 1, 8 do
        local b = DWE.GetRewardButton(i)
        if b:IsShown() then out[#out + 1] = tag .. " btn" .. i .. " " .. tostring(b.text:GetText()) .. " color=" .. tostring(b.text._color) .. " shadow=" .. tostring(b.text._shadow) end
    end
    local bg = 0
    for _, r in ipairs(DWE.choiceBox._regions) do if r._kind == "Texture" and r:IsShown() then bg = bg + 1 end end
    out[#out + 1] = tag .. " wheel background textures shown=" .. bg
end
GetItemQualityColor = function(q) if q == 1 then return 1, 1, 1 end return 0.12, 1, 0 end
for _, theme in ipairs({ "transparent", "dark", "parchment", "dui_brown", "bubble_fantasy" }) do
    DialogueWheelE_Theme = theme
    M.gossipText = "Hello"; M.gossipOptions = { { gossipOptionID = 1, name = "Train", icon = 1 } }
    M.FireEvent("GOSSIP_SHOW"); dump(theme .. " gossip"); M.FireEvent("GOSSIP_CLOSED")
    M.questTitle, M.questText, M.objText, M.questID, M.numChoices = "Q", "Gain 250 reputation.", "Kill 5", 1, 2
    GetQuestItemInfo = function(kind, i) return "Item " .. kind .. i, 134400, 2, (i == 1) and 1 or 2 end
    M.FireEvent("QUEST_DETAIL"); dump(theme .. " detail"); M.FireEvent("QUEST_FINISHED")
    M.FireEvent("QUEST_COMPLETE"); dump(theme .. " complete"); M.FireEvent("QUEST_FINISHED")
end
print(table.concat(out, "\n"))
for _, e in ipairs(M.errors) do print("ERR " .. e) end
