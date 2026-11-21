-- Minimal WoW API mock to load DialogueWheelE outside the game and catch runtime errors.
local M = {}
M.frames = {}        -- creation order, for EnumerateFrames
M.timers = {}
M.bindings = {}
M.errors = {}
M.log = {}

local function noop() end

local Object = {}
Object.__index = function(t, k)
    local v = rawget(Object, k)
    if v ~= nil then return v end
    if type(k) == "string" and k:sub(1, 1) == "_" then return nil end
    if k == "SetAlphaGradient" then return nil end
    if type(k) == "string" and k:match("^[A-Z]") then return noop end
    return nil
end

local function new(kind, name, parent)
    local o = setmetatable({ _kind = kind, _name = name, _parent = parent, _shown = true,
        _alpha = 1, _scripts = {}, _events = {}, _points = {}, _children = {}, _regions = {},
        _text = nil, _font = { "Fonts\\FRIZQT__.TTF", 12, "" }, _w = 100, _h = 20, _level = 1,
        _checked = false, _texture = nil }, Object)
    if parent and parent._children then
        if kind == "Texture" or kind == "FontString" or kind == "MaskTexture" then
            table.insert(parent._regions, o)
        else
            table.insert(parent._children, o)
        end
    end
    return o
end
M.new = new

function Object:GetName() return self._name end
function Object:GetParent() return self._parent end
function Object:SetParent(p) self._parent = p end
function Object:IsForbidden() return false end
function Object:GetObjectType() return self._kind end
function Object:Show() local was = self._shown; self._shown = true; if not was then M.Fire(self, "OnShow") end end
function Object:Hide() local was = self._shown; self._shown = false; if was then M.Fire(self, "OnHide") end end
function Object:SetShown(v) if v then self:Show() else self:Hide() end end
function Object:IsShown() return self._shown end
function Object:IsVisible()
    local o = self
    while o do if not o._shown then return false end o = o._parent end
    return true
end
function Object:SetAlpha(a) assert(type(a) == "number", "SetAlpha expects number"); self._alpha = a end
function Object:GetAlpha() return self._alpha end
-- Comme dans le jeu : l'alpha d'une texture et celui de sa couleur de sommet sont la meme valeur.
function Object:SetVertexColor(r, g, b, a) self._vc = { r, g, b, a or 1 }; self._alpha = a or 1 end
function Object:SetScript(ev, fn) self._scripts[ev] = fn end
function Object:GetScript(ev) return self._scripts[ev] end
function Object:HookScript(ev, fn)
    local old = self._scripts[ev]
    self._scripts[ev] = function(...) if old then old(...) end fn(...) end
end
function Object:RegisterEvent(e) self._events[e] = true end
function Object:UnregisterEvent(e) self._events[e] = nil end
function Object:UnregisterAllEvents() self._events = {} end
function Object:IsEventRegistered(e) return self._events[e] == true end
function Object:SetText(t) self._text = t end
function Object:SetTextColor(r, g, b) self._color = string.format("%.2f,%.2f,%.2f", r, g, b) end
function Object:SetShadowOffset(x, y) self._shadow = x end
if os.getenv("NOGRADIENT") ~= "1" then
    function Object:SetAlphaGradient(start, len) self._grad = start; self._gradLen = len; return true end
end
function Object:GetText() return self._text end
function Object:SetJustifyH(j) self._justH = j end
function Object:GetJustifyH() return self._justH or "LEFT" end
function Object:GetStringHeight()
    if not self._text then return 0 end
    local w = self._w or 300
    local lines = math.max(1, math.ceil((#tostring(self._text) * 7) / math.max(w, 1)))
    return 16 * lines
end
function Object:GetUnboundedStringWidth() return self._text and #tostring(self._text) * 7 or 0 end
function Object:SetFont(path, size, flags)
    assert(type(path) == "string", "SetFont path must be a string, got " .. tostring(path))
    assert(type(size) == "number", "SetFont size must be number")
    if path:find("MISSING") then self._font = { nil }; return false end
    self._font = { path, size, flags }
    return true
end
function Object:GetFont() return self._font[1], self._font[2], self._font[3] end
function Object:SetPoint(...)
    local rel = select(2, ...)
    if type(rel) == "table" and rel._noAnchor then error("Can't anchor to restricted region") end
    table.insert(self._points, { ... })
end
function Object:ClearAllPoints() self._points = {} end
function Object:GetPoint(i)
    local p = self._points and self._points[i or 1]
    if not p then return "CENTER", nil, "CENTER", 0, 0 end
    if type(p[2]) == "number" then return p[1], nil, p[1], p[2], p[3] end
    return p[1], p[2], p[3] or p[1], p[4] or 0, p[5] or 0
end
function Object:StartMoving() end
function Object:StopMovingOrSizing() end
function Object:SetSize(w, h) self._w, self._h = w, h end
function Object:SetWidth(w) self._w = w end
function Object:SetHeight(h) self._h = h end
function Object:GetWidth() return self._w end
function Object:GetHeight() return self._h end
function Object:GetSize() return self._w, self._h end
function Object:GetFrameLevel() return self._level end
function Object:SetFrameLevel(l) self._level = l end
function Object:GetChildren() return table.unpack(self._children) end
function Object:GetRegions() return table.unpack(self._regions) end
function Object:SetUserPlaced() if self._pinned then error("Frame is not movable or resizable") end end
function Object:SetChecked(v) self._checked = v and true or false end
function Object:GetChecked() return self._checked end
M.missingTextures = {}
local function fileExists(path) local f = io.open(path, "rb") if f then f:close() return true end return false end
function Object:SetMask(m) self._mask = m end
function Object:SetTexCoord(...)
    if self._mask then error("Texture:SetTexCoord(): Cannot set tex coords when texture has mask.") end
    self._texCoord = { ... }
end
function Object:SetTexture(t)
    self._texture = t
    if type(t) == "string" and t:find("ChatBubble") and os.getenv("NOBUBBLEART") == "1" then return false end
    if type(t) == "string" and M.addonDir then
        local rel = t:match("^Interface\\AddOns\\DialogueWheelE\\(.+)$")
        if rel then
            local p = M.addonDir .. "/" .. rel:gsub("\\", "/")
            local ok
            if p:match("%.%w+$") then ok = fileExists(p)
            else ok = fileExists(p .. ".blp") or fileExists(p .. ".tga") end -- WoW only guesses BLP/TGA
            if not ok then M.missingTextures[t] = true end
        end
    end
end
function Object:GetTexture() return self._texture end
function Object:GetFrameStrata() return "MEDIUM" end
function Object:CreateTexture(name, layer, tmpl, sub)
    if sub ~= nil then assert(sub >= -8 and sub <= 7, "texture sublevel out of range: " .. sub) end
    return new("Texture", name, self)
end
function Object:CreateMaskTexture() return new("MaskTexture", nil, self) end
function Object:CreateFontString(name, layer, tmpl) return new("FontString", name, self) end
function Object:SetBackdrop(b) assert(type(self.SetBackdropBorderColor) ~= nil) self._backdrop = b end
local function Restricted(o, depth)
    depth = depth or 0
    if not o or depth > 20 then return false end
    if o._restricted then return true end
    for _, pt in ipairs(o._points or {}) do
        if type(pt[2]) == "table" and Restricted(pt[2], depth + 1) then return true end
    end
    return Restricted(o._parent, depth + 1)
end
M.Restricted = Restricted
function Object:IsMouseOver()
    if Restricted(self) then error("Action[FrameMeasurement] failed because[Can't measure restricted regions]") end
    return false
end
function Object:GetScale() return self._scale or 1 end
function Object:SetScale(v) self._scale = v end
function Object:GetEffectiveScale() return 1 end
function Object:GetCenter()
    if Restricted(self) then error("Action[FrameMeasurement] failed because[Can't measure restricted regions]") end
    return self._cx, self._cy
end

function M.Fire(obj, script, ...)
    local fn = obj._scripts[script]
    if fn then
        local ok, err = pcall(fn, obj, ...)
        if not ok then table.insert(M.errors, script .. ": " .. tostring(err)) end
    end
end

function M.CreateFrame(kind, name, parent, template)
    local o = new(kind or "Frame", name, parent)
    if template and template:find("CheckButton") then o.Text = new("FontString", nil, o) end
    if template == "OptionsSliderTemplate" and name then
        _G[name .. "Low"] = new("FontString", nil, o)
        _G[name .. "High"] = new("FontString", nil, o)
        _G[name .. "Text"] = new("FontString", nil, o)
    end
    if name then _G[name] = o end
    table.insert(M.frames, o)
    return o
end

function M.FireEvent(event, ...)
    for _, fr in ipairs(M.frames) do
        if fr._events[event] and fr._scripts.OnEvent then
            local ok, err = pcall(fr._scripts.OnEvent, fr, event, ...)
            if not ok then table.insert(M.errors, event .. ": " .. tostring(err)) end
        end
    end
end

function M.RunTimers()
    local t = M.timers
    M.timers = {}
    for _, fn in ipairs(t) do
        local ok, err = pcall(fn)
        if not ok then table.insert(M.errors, "timer: " .. tostring(err)) end
    end
end

function M.Install(locale)
    _G.CreateFrame = M.CreateFrame
    _G.UIParent = M.CreateFrame("Frame", "UIParent")
    _G.GameTooltip = M.CreateFrame("GameTooltip", "GameTooltip")
    _G.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
    _G.QuestFont = new("Font")
    _G.GameFontNormal = new("Font")
    _G.GameFontNormalLarge = new("Font")
    _G.COMPLETE_QUEST = "Complete Quest"
    _G.REPUTATION = locale == "frFR" and "Réputation" or "Reputation"
    _G.GetLocale = function() return locale end
    _G.hooksecurefunc = function(a, b, c)
        local tbl, key, fn
        if type(a) == "string" then tbl, key, fn = _G, a, b else tbl, key, fn = a, b, c end
        local orig = tbl[key]
        assert(type(orig) == "function", "hooksecurefunc on non-function " .. tostring(key))
        tbl[key] = function(...)
            local r = table.pack(orig(...))
            fn(...)
            return table.unpack(r, 1, r.n)
        end
    end
    _G.EnumerateFrames = function(cur)
        if not cur then return M.frames[1] end
        for i, fr in ipairs(M.frames) do if fr == cur then return M.frames[i + 1] end end
    end
    _G.C_Timer = { After = function(_, fn) table.insert(M.timers, fn) end }
    _G.InCombatLockdown = function() return M.inCombat or false end
    M.bindOwner = {}
    _G.SetOverrideBindingClick = function(owner, prio, key, btn)
        assert(type(key) == "string" and key ~= "", "bad key " .. tostring(key))
        M.bindings[key] = btn
        M.bindOwner[key] = owner
    end
    _G.SetOverrideBinding = function(owner, prio, key, cmd)
        assert(type(key) == "string" and key ~= "", "bad key " .. tostring(key))
        M.bindings[key] = cmd
        M.bindOwner[key] = cmd and owner or nil
    end
    _G.ClearOverrideBindings = function(owner)
        for k in pairs(M.bindings) do
            if M.bindOwner[k] == nil or M.bindOwner[k] == owner then M.bindings[k] = nil; M.bindOwner[k] = nil end
        end
    end
    _G.GetBindingKey = function(a) return a == "INTERACTTARGET" and "E" or nil end
    _G.IsMouseButtonDown = function() return false end
    _G.CameraZoomIn = noop
    _G.CameraZoomOut = noop
    _G.IsShiftKeyDown = function() return false end
    _G.IsControlKeyDown = function() return false end
    _G.IsAltKeyDown = function() return false end
    _G.IsModifiedClick = function() return false end
    _G.UnitName = function(u) return u == "npc" and "Theridran" or nil end
    _G.Settings = { RegisterCanvasLayoutCategory = function() return {} end, RegisterAddOnCategory = noop }
    _G.GetItemQualityColor = function() return 1, 1, 1 end
    _G.C_Item = { GetItemInfo = function() return nil end, GetItemCount = function() return 0 end }
    _G.GetQuestID = function() return M.questID or 0 end

    -- Gossip
    _G.C_GossipInfo = {
        GetText = function() return M.gossipText end,
        GetAvailableQuests = function() return M.availQuests or {} end,
        GetActiveQuests = function() return M.activeQuests or {} end,
        GetOptions = function() return M.gossipOptions or {} end,
        SelectOption = function(id) table.insert(M.log, "SelectOption " .. tostring(id)) end,
        SelectAvailableQuest = function(id) table.insert(M.log, "SelectAvailableQuest " .. id) end,
        SelectActiveQuest = function(id) table.insert(M.log, "SelectActiveQuest " .. id) end,
        CloseGossip = function() table.insert(M.log, "CloseGossip") end,
    }
    _G.CloseQuest = noop
    _G.CloseItemText = noop

    -- Quest window
    _G.GetTitleText = function() return M.questTitle end
    _G.GetQuestText = function() return M.questText end
    _G.GetProgressText = function() return M.questText end
    _G.GetRewardText = function() return M.questText end
    _G.GetObjectiveText = function() return M.objText end
    _G.GetNumQuestItems = function() return 1 end
    _G.GetNumQuestRewards = function() return 1 end
    _G.GetNumQuestChoices = function() return M.numChoices or 0 end
    _G.GetQuestItemInfo = function(kind, i) return "Item " .. kind .. i, 134400, 2, 3 end
    _G.GetQuestItemLink = function(kind, i) return "|Hitem:" .. i .. "|h[x]|h" end
    _G.GetRewardXP = function() return 450 end
    _G.GetRewardMoney = function() return 12345 end
    _G.AcceptQuest = function() table.insert(M.log, "AcceptQuest") end
    _G.CompleteQuest = function() table.insert(M.log, "CompleteQuest") end
    _G.GetQuestReward = function(i) table.insert(M.log, "GetQuestReward " .. i) end
    _G.IsQuestCompletable = function() return true end
    _G.GetNumAvailableQuests = function() return 1 end
    _G.GetNumActiveQuests = function() return 1 end
    _G.GetAvailableTitle = function() return "Avail" end
    _G.GetAvailableQuestInfo = function() return false, 0, false end
    _G.GetActiveTitle = function() return "Active", true end
    _G.SelectAvailableQuest = noop
    _G.SelectActiveQuest = noop
    _G.GetGreetingText = function() return "Greetings" end
    _G.C_QuestLog = { IsComplete = function() return false end }

    -- Books: M.book = { title, pages = {...} }, M.bookPage = server page
    _G.ItemTextGetItem = function() return M.book and M.book.title end
    _G.ItemTextGetPage = function() return M.bookPage end
    _G.ItemTextGetText = function() return M.book and M.book.pages[M.bookPage] end
    _G.ItemTextHasNextPage = function() return M.book and M.bookPage < #M.book.pages end
    _G.ItemTextNextPage = function()
        M.bookPage = M.bookPage + 1
        table.insert(M.pendingEvents, "ITEM_TEXT_READY")
    end
    M.pendingEvents = {}
    M.cvars = { SoftTargetNameplateInteract = "1", nameplateShowFriendlyNPCs = "0" }
    _G.GetCVar = function(k) return M.cvars[k] end
    _G.SetCVar = function(k, v) M.cvars[k] = tostring(v) end
    _G.UnitExists = function(u) return u == "npc" end
    _G.UnitIsUnit = function(a, b) return (a == "nameplate1" and b == "npc") end
    M.cursor = { 0, 0 }
    _G.GetCursorPosition = function() return M.cursor[1], M.cursor[2] end
    _G.UnitCanAttack = function(a, b) return b == "nameplate2" end
    _G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
    M.plates = {}
    _G.C_NamePlate = {
        GetNamePlateForUnit = function(u) return nil end,
        GetNamePlates = function() return M.plates end,
    }
end

function M.FlushPending()
    local p = M.pendingEvents
    M.pendingEvents = {}
    for _, e in ipairs(p) do M.FireEvent(e) end
end

return M
