-- Fenetre d'options de Storytale : les pages d'options de toujours (vignettes des themes,
-- couleurs...) dans une fenetre a nous, avec onglets et navigation a la manette. Rien ne passe
-- par le panneau d'options du jeu : sa manette se bloquait des qu'un addon y ajoutait des
-- lignes ("Interface action failed", taint.log du 25/11).
local DWE = DWE
if not DWE then return end

local Native = {}
DWE.Native = Native
-- Fenetre d'options de Storytale (a la place des pages du panneau d'options du jeu).
-- (false : les pages restent dans le menu du jeu, comme avant.)
DWE.NATIVE_OPTIONS = true

---------------------------------------------------------------------------- Fenetre
-- La fenetre montre les pages d'options de toujours (vignettes des themes, couleurs...), avec
-- un onglet par page, et les rend faciles a la manette : un cadre dore suit l'element choisi.
-- Manette : croix (aller vers l'element voisin ; gauche/droite reglent un curseur), A (cliquer),
-- B (fermer), L1 / R1 (onglets). Clavier : Echap ferme, le reste va au jeu. Souris : tout.
-- Rien ne passe par le panneau d'options du jeu (sa manette se bloquait, voir plus haut).
local W, H, TABS_W = 860, 660, 170

-- Couleurs de la fenetre selon le theme choisi : un fond sombre teinte (le texte et les cases du
-- jeu restent lisibles, meme avec un theme clair) et un accent (bord, onglet, curseur, titre).
local THEME_COLORS = {
    bubble = { { 1, 0.82, 0 }, { 0.11, 0.11, 0.12 } },
    bubble_npc = { { 1, 1, 0.62 }, { 0.09, 0.09, 0.09 } },
    bubble_fantasy = { { 0.92, 0.70, 0.36 }, { 0.17, 0.12, 0.07 } },
    whisper = { { 0.82, 0.58, 1 }, { 0.11, 0.08, 0.15 } },
    emerald = { { 0.45, 0.95, 0.60 }, { 0.06, 0.13, 0.09 } },
    ruby = { { 1, 0.45, 0.50 }, { 0.15, 0.06, 0.07 } },
    sapphire = { { 0.55, 0.78, 1 }, { 0.06, 0.09, 0.16 } },
    amber = { { 1, 0.75, 0.40 }, { 0.15, 0.10, 0.05 } },
    gw2 = { { 1, 0.82, 0.42 }, { 0.07, 0.11, 0.17 } },
    transparent = { { 1, 0.82, 0 }, { 0.10, 0.10, 0.10 } },
    dark = { { 0.88, 0.88, 0.92 }, { 0.08, 0.08, 0.09 } },
    glass = { { 1, 0.84, 0.50 }, { 0.10, 0.10, 0.11 } },
    halo = { { 1, 0.84, 0.50 }, { 0.09, 0.09, 0.10 } },
    inkgold = { { 1, 0.84, 0.47 }, { 0.09, 0.08, 0.06 } },
    cinema = { { 1, 0.82, 0 }, { 0.07, 0.07, 0.07 } },
    velin = { { 0.96, 0.86, 0.60 }, { 0.18, 0.15, 0.11 } },
    arcane = { { 0.72, 0.76, 1 }, { 0.11, 0.11, 0.17 } },
    sylvan = { { 0.72, 0.92, 0.50 }, { 0.09, 0.13, 0.07 } },
    starry = { { 0.76, 0.82, 1 }, { 0.07, 0.08, 0.15 } },
    parchment = { { 0.96, 0.80, 0.50 }, { 0.19, 0.14, 0.09 } },
    parchment_dark = { { 0.90, 0.70, 0.40 }, { 0.13, 0.09, 0.06 } },
    folio = { { 0.96, 0.82, 0.55 }, { 0.17, 0.13, 0.09 } },
    folio_dark = { { 0.86, 0.66, 0.40 }, { 0.11, 0.08, 0.05 } },
    dui = { { 0.92, 0.74, 0.45 }, { 0.15, 0.11, 0.07 } },
}
local function ThemeColors()
    local id = DialogueWheelE_Theme or "bubble"
    if id == "scroll" then id = "parchment" end
    -- Theme Personnalise : ses propres couleurs (contour = accent ; fond assombri si besoin, pour
    -- que le texte et les cases du jeu restent lisibles).
    if id == "custom" and DWE.CustomColor then
        local a, bg = DWE.CustomColor("border"), DWE.CustomColor("bg")
        local lum = 0.3 * bg[1] + 0.59 * bg[2] + 0.11 * bg[3]
        if lum > 0.2 then
            local k = 0.2 / lum
            bg = { bg[1] * k, bg[2] * k, bg[3] * k }
        end
        local la = 0.3 * a[1] + 0.59 * a[2] + 0.11 * a[3]
        if la < 0.35 then a = DWE.CustomColor("sel") end -- contour trop sombre : la couleur du choix
        return a, bg
    end
    local c = THEME_COLORS[id] or THEME_COLORS.bubble
    return c[1], c[2]
end
Native.ThemeColors = ThemeColors

local function MakeWindow()
    local L = DWE.L
    if DWE.InitOptionsPanel then pcall(DWE.InitOptionsPanel) end
    local pages = DWE.optionPages or {}
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
    -- Fond plein (on ne voit plus le jeu a travers), bord du jeu teinte par l'accent du theme.
    if f.SetBackdrop then
        f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = false, edgeSize = 32,
            insets = { left = 10, right = 10, top = 10, bottom = 10 } })
    end
    -- Leger degrade (plus clair en haut) et colonne des onglets un peu plus claire.
    f.shade = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    f.shade:SetPoint("TOPLEFT", 10, -10)
    f.shade:SetPoint("BOTTOMRIGHT", -10, 10)
    f.shade:SetColorTexture(1, 1, 1, 1)
    f.tabsBg = f:CreateTexture(nil, "BACKGROUND", nil, 2)
    f.tabsBg:SetPoint("TOPLEFT", 12, -48)
    f.tabsBg:SetPoint("BOTTOMLEFT", 12, 34)
    f.tabsBg:SetWidth(TABS_W)
    f.tabsBg:SetColorTexture(1, 1, 1, 0.05)
    f.title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    f.title:SetPoint("TOP", 0, -18)
    f.title:SetText("Storytale")
    f.titleLine = f:CreateTexture(nil, "ARTWORK")
    f.titleLine:SetHeight(1)
    f.titleLine:SetPoint("TOPLEFT", 16, -42)
    f.titleLine:SetPoint("TOPRIGHT", -16, -42)
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)
    close:SetScript("OnClick", function() f:Hide() end)
    f.hint = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    f.hint:SetPoint("BOTTOM", 0, 16)
    f.hint:SetText(L.OPT_WINDOW_HINT or "")

    -- Onglets : une page d'options chacun.
    f.tabs = {}
    for i, pg in ipairs(pages) do
        local b = CreateFrame("Button", nil, f)
        b:SetSize(TABS_W - 10, 30)
        b:SetPoint("TOPLEFT", 18, -50 - (i - 1) * 32)
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
        local name = pg.panel and pg.panel.name or ""
        if i == 1 then name = L.OPT_TAB_MAIN or name end
        b.text:SetText(name)
        b:SetScript("OnClick", function() f.ShowPage(i) end)
        f.tabs[i] = b
    end
    -- Le chat de Nearyn, en bas des onglets ; ses yeux brillent quand on le survole (ou que le
    -- cadre de la manette arrive dessus) ; un clic les fait briller un instant.
    do
        local path = "Interface\\AddOns\\Storytale\\"
        local cat = CreateFrame("Button", nil, f)
        cat:SetSize(64, 64)
        cat:SetPoint("BOTTOM", f, "BOTTOMLEFT", 12 + TABS_W / 2, 58)
        cat.tex = cat:CreateTexture(nil, "ARTWORK")
        cat.tex:SetAllPoints()
        cat.tex:SetTexture(path .. "NearynCat.png")
        cat.glow = cat:CreateTexture(nil, "OVERLAY")
        cat.glow:SetAllPoints()
        cat.glow:SetTexture(path .. "NearynCatGlow.png")
        cat.glow:SetBlendMode("ADD")
        cat.glow:SetAlpha(0)
        cat.by = cat:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        cat.by:SetPoint("TOP", cat, "BOTTOM", 0, -2)
        cat.by:SetText("by Nearyn")
        local function Glow(target)
            cat.target = target
            cat:SetScript("OnUpdate", function(self, elapsed)
                local a = self.glow:GetAlpha() + (self.target - self.glow:GetAlpha()) * math.min(1, elapsed * 8)
                if math.abs(a - self.target) < 0.01 then a = self.target; self:SetScript("OnUpdate", nil) end
                self.glow:SetAlpha(a)
            end)
        end
        cat:SetScript("OnEnter", function() Glow(1) end)
        cat:SetScript("OnLeave", function() Glow(0) end)
        cat:SetScript("OnClick", function()
            Glow(1)
            if C_Timer and C_Timer.After then C_Timer.After(0.6, function() if not cat:IsMouseOver() then Glow(0) end end) end
        end)
        f.cat = cat
    end
    local sep = f:CreateTexture(nil, "ARTWORK")
    sep:SetColorTexture(1, 0.82, 0, 0.25)
    sep:SetSize(1, H - 90)
    sep:SetPoint("TOPLEFT", TABS_W + 14, -48)

    -- Zone de la page
    f.content = CreateFrame("Frame", nil, f)
    f.content:SetPoint("TOPLEFT", TABS_W + 20, -46)
    f.content:SetPoint("BOTTOMRIGHT", -14, 34)

    -- Cadre dore : l'element choisi a la manette / au clavier.
    f.cursor = CreateFrame("Frame", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
    f.cursor:SetFrameStrata("FULLSCREEN")
    f.cursor:SetFrameLevel(f:GetFrameLevel() + 50)
    if f.cursor.SetBackdrop then
        f.cursor:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
        f.cursor:SetBackdropBorderColor(1, 0.82, 0, 1)
    end
    f.cursor:EnableMouse(false)
    f.cursor:Hide()

    function f.ApplyColors()
        local a, bg = ThemeColors()
        if f.SetBackdropColor then
            -- (un peu transparent : on devine le jeu derriere, sans gener la lecture)
            f:SetBackdropColor(bg[1], bg[2], bg[3], 0.90)
            f:SetBackdropBorderColor(math.min(1, a[1] * 0.9 + 0.1), math.min(1, a[2] * 0.9 + 0.1), math.min(1, a[3] * 0.9 + 0.1), 1)
        end
        if f.shade.SetGradient and CreateColor then
            pcall(f.shade.SetGradient, f.shade, "VERTICAL", CreateColor(0, 0, 0, 0.25), CreateColor(1, 1, 1, 0.06))
        else
            f.shade:SetColorTexture(1, 1, 1, 0.03)
        end
        f.title:SetTextColor(a[1], a[2], a[3])
        f.titleLine:SetColorTexture(a[1], a[2], a[3], 0.35)
        sep:SetColorTexture(a[1], a[2], a[3], 0.30)
        for i, t in ipairs(f.tabs) do
            t.bg:SetColorTexture(a[1], a[2], a[3], 0.22)
            t.text:SetTextColor(i == f.pageIndex and 1 or a[1], i == f.pageIndex and 1 or a[2], i == f.pageIndex and 1 or a[3])
        end
        if f.cursor.SetBackdropBorderColor then f.cursor:SetBackdropBorderColor(a[1], a[2], a[3], 1) end
    end

    f.pageIndex = 1
    local function Page() return pages[f.pageIndex] end

    -- Les elements cliquables de la page affichee.
    local KINDS = { Button = true, CheckButton = true, Slider = true }
    local function Collect()
        local pg = Page()
        local list = {}
        if not (pg and pg.panel) then return list end
        local function Walk(fr)
            for _, c in ipairs({ fr:GetChildren() }) do
                local okV, vis = pcall(c.IsVisible, c)
                -- La page defilante : seulement son contenu (pas sa barre de defilement).
                if c == pg.scroll then
                    if pg.child then Walk(pg.child) end
                elseif okV and vis then
                    local okT, kind = pcall(c.GetObjectType, c)
                    if okT and KINDS[kind] then
                        local okE, en = pcall(function() return c.IsEnabled == nil or c:IsEnabled() end)
                        if (not okE or en) and c:IsMouseEnabled() then list[#list + 1] = c end
                        if kind ~= "Slider" then Walk(c) end
                    else
                        Walk(c)
                    end
                end
            end
        end
        -- Toute la page (boutons "Par defaut" en haut compris), et les onglets a gauche.
        Walk(pg.panel)
        for _, t in ipairs(f.tabs) do list[#list + 1] = t end
        if f.cat then list[#list + 1] = f.cat end
        return list
    end
    local function Center(w)
        local x, y = w:GetCenter()
        return x or 0, y or 0
    end
    local function Leave(w)
        if w and w.GetScript then
            local fn = w:GetScript("OnLeave")
            if fn then pcall(fn, w) end
        end
        GameTooltip:Hide()
    end
    -- La page defile pour montrer l'element choisi.
    local function Reveal(w)
        local pg = Page()
        local sc = pg and pg.scroll
        if not (sc and pg.child and w) then return end
        -- Seulement ce qui est dans la partie qui defile (pas les onglets, ni le haut de la page).
        local inside, p = false, w
        while p do
            if p == pg.child then inside = true break end
            p = p:GetParent()
        end
        if not inside then return end
        local okT, top = pcall(pg.child.GetTop, pg.child)
        local wt, wh = w:GetTop(), w:GetHeight()
        if not (okT and top and wt and wh) then return end
        local at = (top - wt) / ((w:GetEffectiveScale() or 1) / (pg.child:GetEffectiveScale() or 1))
        local cur, viewH = sc:GetVerticalScroll() or 0, sc:GetHeight() or 0
        local range = (sc.GetVerticalScrollRange and sc:GetVerticalScrollRange()) or 0
        local new = cur
        if at - 10 < cur then new = at - 10 elseif at + wh + 10 > cur + viewH then new = at + wh + 10 - viewH end
        new = math.max(0, math.min(range, new))
        if new ~= cur then sc:SetVerticalScroll(new) end
    end
    function f.Select(w)
        if f.sel and f.sel ~= w then Leave(f.sel) end
        f.sel = w
        if not w then f.cursor:Hide() return end
        Reveal(w)
        f.cursor:ClearAllPoints()
        f.cursor:SetPoint("TOPLEFT", w, "TOPLEFT", -3, 3)
        f.cursor:SetPoint("BOTTOMRIGHT", w, "BOTTOMRIGHT", 3, -3)
        f.cursor:Show()
        local fn = w:GetScript("OnEnter")
        if fn then pcall(fn, w) end
    end
    -- Vers l'element le plus proche dans la direction (dx, dy).
    function f.Move(dx, dy)
        local list = Collect()
        if #list == 0 then f.Select(nil) return end
        local cur = f.sel
        local valid = false
        for _, w in ipairs(list) do if w == cur then valid = true end end
        if not valid then
            -- premier element : le plus haut, puis le plus a gauche
            local best, bx, by
            for _, w in ipairs(list) do
                local x, y = Center(w)
                if not best or y > by + 4 or (math.abs(y - by) <= 4 and x < bx) then best, bx, by = w, x, y end
            end
            f.Select(best)
            return
        end
        local x, y = Center(cur)
        local best, score
        -- Haut / bas : la ligne la plus proche d'abord (aucune ligne sautee), puis dans cette ligne
        -- l'element le plus proche a l'horizontale. Avant, un element bien aligne deux lignes plus
        -- loin passait devant celui de la ligne voisine, un peu decale (vu le 28/11 en remontant).
        if dy ~= 0 then
            -- On reste dans sa colonne : les onglets entre eux, la page entre elle (gauche/droite
            -- pour passer de l'une a l'autre).
            local function Side(w)
                if w == f.cat then return "tab" end
                for _, t in ipairs(f.tabs) do if t == w then return "tab" end end
                return "page"
            end
            local mine = Side(cur)
            local kept = {}
            for _, w in ipairs(list) do if Side(w) == mine then kept[#kept + 1] = w end end
            list = kept
            local rowD
            for _, w in ipairs(list) do
                if w ~= cur then
                    local _, cy = Center(w)
                    local d = (cy - y) * dy
                    if d > 4 and (not rowD or d < rowD) then rowD = d end
                end
            end
            if rowD then
                for _, w in ipairs(list) do
                    if w ~= cur then
                        local cx, cy = Center(w)
                        local d = (cy - y) * dy
                        if d > 4 and d <= rowD + 8 then
                            local sc = math.abs(cx - x) + d * 0.01
                            if not score or sc < score then best, score = w, sc end
                        end
                    end
                end
            end
            if best then f.Select(best) end
            return
        end
        for _, w in ipairs(list) do
            if w ~= cur then
                local cx, cy = Center(w)
                local ok, sc
                if dy ~= 0 then
                    local d = (cy - y) * dy
                    ok = d > 4
                    sc = d + 2.5 * math.abs(cx - x)
                else
                    local d = (cx - x) * dx
                    ok = d > 4 and math.abs(cy - y) < 16
                    sc = d + 4 * math.abs(cy - y)
                end
                if ok and (not score or sc < score) then best, score = w, sc end
            end
        end
        -- Rien sur la meme ligne (ex. d'un onglet vers une page dont le premier element est plus
        -- haut ou plus bas) : l'element le plus proche de ce cote, a n'importe quelle hauteur.
        if not best and dx ~= 0 then
            for _, w in ipairs(list) do
                if w ~= cur then
                    local cx, cy = Center(w)
                    local d = (cx - x) * dx
                    local sc = d + 1.5 * math.abs(cy - y)
                    if d > 4 and (not score or sc < score) then best, score = w, sc end
                end
            end
        end
        if best then f.Select(best) end
    end
    local function IsSlider(w)
        local ok, kind = pcall(w.GetObjectType, w)
        return ok and kind == "Slider"
    end
    function f.Side(dir)
        local w = f.sel
        if w and IsSlider(w) then
            local step = (w.GetValueStep and w:GetValueStep()) or 1
            if not step or step <= 0 then step = 1 end
            local lo, hi = w:GetMinMaxValues()
            w:SetValue(math.max(lo, math.min(hi, (w:GetValue() or lo) + dir * step)))
            return
        end
        f.Move(dir, 0)
    end
    function f.Activate()
        local w = f.sel
        if not w then f.Move(0, -1) return end
        if IsSlider(w) then return end
        if w.Click then pcall(w.Click, w) end
        f.ApplyColors() -- (theme peut-etre change)
        -- La page a pu changer (theme choisi, case cochee qui en grise d'autres).
        if C_Timer and C_Timer.After then C_Timer.After(0, function() if f.sel and not f.sel:IsVisible() then f.Select(nil) end end) end
    end

    -- Page d'options prise dans la fenetre, rendue a sa place a la fermeture.
    local function Detach()
        local pg = f.shown
        if not pg then return end
        f.Select(nil)
        pg.panel:Hide()
        pg.panel:ClearAllPoints()
        pg.panel:SetParent(pg.oldParent)
        for _, pt in ipairs(pg.oldPoints or {}) do pcall(pg.panel.SetPoint, pg.panel, unpack(pt)) end
        f.shown = nil
    end
    local function IsTab(w)
        for _, t in ipairs(f.tabs) do if t == w then return true end end
        return false
    end
    function f.ShowPage(i)
        local pg = pages[i]
        if not pg then return end
        -- Cadre sur les onglets : il y reste (sur l'onglet ouvert), pour continuer a les parcourir.
        local onTabs = f.sel and IsTab(f.sel)
        Detach()
        f.pageIndex = i
        for k, t in ipairs(f.tabs) do t.bg:SetShown(k == i) end
        pg.oldParent = pg.panel:GetParent()
        pg.oldPoints = {}
        for n = 1, pg.panel:GetNumPoints() do pg.oldPoints[n] = { pg.panel:GetPoint(n) } end
        pg.panel:SetParent(f.content)
        pg.panel:ClearAllPoints()
        pg.panel:SetAllPoints(f.content)
        pg.panel:Show()
        f.shown = pg
        if pg.scroll then pg.scroll:SetVerticalScroll(0) end
        if DWE.FitOptionPage then DWE.FitOptionPage(pg) end
        if onTabs and f.tabs[i] then f.Select(f.tabs[i]) end
        f.ApplyColors()
    end
    local function Tab(dir)
        local n = #pages
        if n == 0 then return end
        local i = f.pageIndex + dir
        if i < 1 then i = n elseif i > n then i = 1 end
        f.ShowPage(i)
    end
    f.Tab = Tab

    f:EnableKeyboard(true)
    -- Clavier : seule Echap est prise (ferme la fenetre). Tout le reste va au jeu : on peut se
    -- deplacer, sauter, lancer des sorts en changeant ses options (la souris suffit ici).
    f:SetScript("OnKeyDown", function(self, key)
        local busy = (DWE.askFrame and DWE.askFrame:IsShown())
            or (GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus())
        local mine = key == "ESCAPE" and not busy
        if self.SetPropagateKeyboardInput and not InCombatLockdown() then pcall(self.SetPropagateKeyboardInput, self, not mine) end
        if mine then f:Hide() end
    end)
    -- Manette : les boutons sont pris a la place de leurs actions du jeu tant que la fenetre est
    -- ouverte (sinon A faisait aussi sauter le personnage). Liaisons de remplacement, retirees a
    -- la fermeture (pas en combat : le jeu l'interdit, la fenetre ne prend alors que le clavier).
    local function Pad(b)
        -- Fenetre de choix ou de confirmation ouverte : c'est elle qui recoit le bouton.
        for _, w in ipairs({ DWE.askFrame }) do
            if w and w:IsShown() then
                local h = w:GetScript("OnGamePadButtonDown")
                if h then w.fromOptions = true; pcall(h, w, b); w.fromOptions = nil end
                return
            end
        end
        if b == "PADDUP" then f.Move(0, 1)
        elseif b == "PADDDOWN" then f.Move(0, -1)
        elseif b == "PADDLEFT" then f.Side(-1)
        elseif b == "PADDRIGHT" then f.Side(1)
        elseif b == "PAD1" then f.Activate()
        elseif b == "PAD2" then f:Hide()
        elseif b == "PADLSHOULDER" or b == "PADLTRIGGER" then Tab(-1)
        elseif b == "PADRSHOULDER" or b == "PADRTRIGGER" then Tab(1) end
    end
    f.Pad = Pad
    local PAD_KEYS = { "PADDUP", "PADDDOWN", "PADDLEFT", "PADDRIGHT", "PAD1", "PAD2",
        "PADLSHOULDER", "PADRSHOULDER", "PADLTRIGGER", "PADRTRIGGER" }
    f.padButtons = {}
    for _, k in ipairs(PAD_KEYS) do
        local name = "StorytaleOptionsPad_" .. k
        local btn = CreateFrame("Button", name, f)
        btn:SetScript("OnClick", function() Pad(k) end)
        f.padButtons[k] = name
    end
    function f.BindPad(on)
        if InCombatLockdown() then return end
        if not on then
            if ClearOverrideBindings then ClearOverrideBindings(f) end
            f.padBound = false
            return
        end
        if not SetOverrideBindingClick then return end
        for k, name in pairs(f.padButtons) do pcall(SetOverrideBindingClick, f, true, k, name) end
        f.padBound = true
    end
    f:SetScript("OnShow", function()
        f.BindPad(true)
        -- Couleurs du theme Personnalise changees dans la page : la fenetre suit (relu 2 fois/s).
        f.colorT = 0
        f:SetScript("OnUpdate", function(self, elapsed)
            self.colorT = self.colorT + elapsed
            if self.colorT > 0.5 then self.colorT = 0; self.ApplyColors() end
        end)
    end)
    f:SetScript("OnHide", function()
        f:SetScript("OnUpdate", nil)
        f.BindPad(false)
        Detach()
        GameTooltip:Hide()
    end)
    f.Draw = function() end
    f:Hide()
    return f
end

function DWE.OpenOptionsWindow(pageIndex)
    local f = Native.window or MakeWindow()
    f:Show()
    f:Raise()
    f.ShowPage(pageIndex or f.pageIndex or 1)
    return f
end
function DWE.OptionsPadActive()
    return Native.window and Native.window:IsShown() and Native.window.padBound or false
end
function DWE.ToggleOptionsWindow()
    if Native.window and Native.window:IsShown() then Native.window:Hide() else DWE.OpenOptionsWindow() end
end

-- Theme change (clic sur une vignette) : la fenetre prend tout de suite ses couleurs.
do
    local orig = DWE.OnThemeChanged
    if type(orig) == "function" then
        DWE.OnThemeChanged = function(...)
            local r = { orig(...) }
            if Native.window and Native.window:IsShown() and Native.window.ApplyColors then pcall(Native.window.ApplyColors) end
            return unpack(r)
        end
    end
end

-- Raccourci du jeu (Options > Raccourcis > Storytale), pour ouvrir la fenetre a la manette.
BINDING_HEADER_STORYTALE = "Storytale"
BINDING_NAME_STORYTALE_OPTIONS = (DWE.L and DWE.L.OPT_WINDOW_OPEN) or "Storytale options"
BINDING_NAME_STORYTALE_BUBBLE_NEXT = (DWE.L and DWE.L.BUBBLE_NEXT_KEY) or "Text: next"
BINDING_NAME_STORYTALE_BUBBLE_PREV = (DWE.L and DWE.L.BUBBLE_PREV_KEY) or "Text: previous"
BINDING_NAME_STORYTALE_LIBRARY = (DWE.L and DWE.L.LIBRARY) or "Library"
