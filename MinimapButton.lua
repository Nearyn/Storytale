-- Storytale : bouton de la mini-carte (ouvre les options). Sans bibliotheque externe.
-- Clic gauche : options. Glisser : le deplacer autour de la mini-carte. Une option le cache.
local DWE = DWE
if not DWE then return end
local L = DWE.L or {}

local RADIUS_PAD = 10

-- Mini-carte ronde ou carree (certains addons la rendent carree) : position du bouton.
local function PlaceButton(btn)
    local angle = math.rad(tonumber(DialogueWheelE_MinimapAngle) or 220)
    local mm = Minimap
    local w, h = (mm:GetWidth() or 140) / 2 + RADIUS_PAD, (mm:GetHeight() or 140) / 2 + RADIUS_PAD
    local x, y = math.cos(angle), math.sin(angle)
    local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
    if shape == "SQUARE" then
        -- Sur le bord du carre : on etire le cercle jusqu'au bord.
        local m = math.max(math.abs(x), math.abs(y))
        if m > 0 then x, y = x / m, y / m end
    end
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", mm, "CENTER", x * w, y * h)
end

local function OpenOptions()
    -- Fenetre d'options de Storytale (manette, clavier, souris), voir Options_Native.lua.
    if DWE.NATIVE_OPTIONS and DWE.OpenOptionsWindow then DWE.OpenOptionsWindow() return end
    local cat = DWE.optionsCategory
    if Settings and Settings.OpenToCategory and cat then
        local id = cat.GetID and cat:GetID() or cat.ID
        pcall(Settings.OpenToCategory, id)
    elseif InterfaceOptionsFrame_OpenToCategory and DWE.optionsPanel then
        InterfaceOptionsFrame_OpenToCategory(DWE.optionsPanel)
        InterfaceOptionsFrame_OpenToCategory(DWE.optionsPanel)
    end
end
DWE.OpenOptions = OpenOptions

local btn
local function Build()
    if btn or not Minimap then return end
    btn = CreateFrame("Button", "StorytaleMinimapButton", Minimap)
    btn:SetSize(31, 31)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:SetHighlightTexture([[Interface\Minimap\UI-Minimap-ZoomButton-Highlight]])
    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture([[Interface\AddOns\Storytale\Logo]])
    icon:SetSize(20, 20)
    icon:SetPoint("TOPLEFT", 7, -5)
    if btn.CreateMaskTexture and icon.AddMaskTexture then
        local mask = btn:CreateMaskTexture()
        mask:SetTexture([[Interface\CharacterFrame\TempPortraitAlphaMask]], "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(icon)
        icon:AddMaskTexture(mask)
    end
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetTexture([[Interface\Minimap\MiniMap-TrackingBorder]])
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnClick", function() OpenOptions() end)
    btn:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            DialogueWheelE_MinimapAngle = math.deg(math.atan2(cy - my, cx - mx)) % 360
            PlaceButton(self)
        end)
    end)
    btn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Storytale", 1, 0.82, 0)
        GameTooltip:AddLine(L.MINIMAP_TIP or "Click: options. Drag: move this button.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    PlaceButton(btn)
end

function DWE.MinimapButtonRefresh()
    if DialogueWheelE_MinimapHide == true then
        if btn then btn:Hide() end
        return
    end
    Build()
    if btn then PlaceButton(btn); btn:Show() end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function() pcall(DWE.MinimapButtonRefresh) end)
