-- Storytale : priorite de lecture avec Spoken.
-- Un livre lu par Spoken s'arrete quand on parle a un PNJ : la voix du PNJ passe d'abord, puis
-- le livre reprend (la phrase en cours recommence : Spoken ne sait pas reprendre au milieu).
-- On ne change rien a Spoken : on lui ajoute un "verrou" (Spoken:AddGate) qui retient les
-- lignes de livre tant qu'une conversation avec un PNJ est ouverte ou qu'une ligne de PNJ attend.
-- Entre PNJ, meme regle : le PNJ a qui l'on parle passe d'abord ; celui qui parlait s'arrete et
-- attend. Ensuite, les PNJ interrompus reprennent, le plus recent d'abord.

local Focus = { npc = false }
DWE.SpokenFocus = Focus

local function Env()
    local env = rawget(_G, "SpokenEnv")
    if type(env) ~= "table" then return nil end
    local api, queue = rawget(env, "Spoken"), rawget(env, "SoundQueue")
    if type(api) ~= "table" or type(queue) ~= "table" then return nil end
    return api, queue
end

-- Ligne de livre (Spoken Readables : page de livre, pierre, plaque...).
local function SourceName(clip)
    local src = type(clip) == "table" and clip.source
    if type(src) ~= "table" then return "" end
    return tostring(src.key or src.name or src.id or "")
end
local function IsBook(clip)
    if type(clip) ~= "table" then return false end
    local p = clip.present
    if type(p) == "table" and (p.material ~= nil or p.bullet == "book") then return true end
    return SourceName(clip):lower():find("read") ~= nil
end
Focus.SourceName = SourceName

-- Qui parle (nom du PNJ en tete de la ligne). nil pour un livre ou une narration sans nom.
local function SpeakerOf(clip)
    if type(clip) ~= "table" or IsBook(clip) then return nil end
    local p = clip.present
    local h = type(p) == "table" and p.header
    if type(h) == "string" and h ~= "" then return h end
    return nil
end
Focus.SpeakerOf = SpeakerOf
-- Groupes de la file : un livre (son titre) ou un PNJ (son nom). La file de lecture du petit
-- lecteur de Spoken les liste ; on peut en choisir un (il passe devant) ou le fermer.
local function GroupKey(clip)
    if type(clip) ~= "table" then return nil end
    local p = type(clip.present) == "table" and clip.present or {}
    -- Un livre se reconnait a son titre (label) ; l'en-tete vaut juste "Book" pour tous.
    if IsBook(clip) then
        local title = tostring((p.label ~= "" and p.label) or p.title or p.header or clip.key)
        title = title:gsub("%s*%(%d+%s*/%s*%d+%)%s*$", "")
        return "book:" .. title
    end
    local who = SpeakerOf(clip)
    if who then return "npc:" .. who end
    return "other:" .. tostring(p.label or p.header or clip.key)
end
Focus.GroupKey = GroupKey
local function GroupQueued(queue, key)
    for _, c in ipairs(queue.sounds or {}) do if GroupKey(c) == key then return true end end
    return false
end

-- Ordre de priorite des PNJ : [1] = celui a qui l'on parle, puis les precedents.
Focus.stack = {}
local function PushSpeaker(who)
    local st = Focus.stack
    for i = #st, 1, -1 do if st[i] == who then table.remove(st, i) end end
    table.insert(st, 1, who)
    while #st > 8 do table.remove(st) end
end
local function Rank(clip)
    if Focus.forced and GroupKey(clip) == Focus.forced then return 0 end
    if IsBook(clip) then return 2000 end
    local who = SpeakerOf(clip)
    if who then
        for i, s in ipairs(Focus.stack) do if s == who then return i end end
    end
    return 1000
end
local function FocusLineQueued(queue)
    local who = Focus.speaker
    if not who then return false end
    for _, c in ipairs(queue.sounds or {}) do
        if SpeakerOf(c) == who then return true end
    end
    return false
end
-- Remet la file dans l'ordre de priorite (la ligne qui parle reste en tete).
local function Reorder(queue)
    local t = queue.sounds
    if type(t) ~= "table" or #t < 2 then return end
    local from = (queue.IsPlaying and queue:IsPlaying()) and 2 or 1
    local rest = {}
    for i = from, #t do rest[#rest + 1] = t[i] end
    table.sort(rest, function(a, b)
        local ra, rb = Rank(a), Rank(b)
        if ra ~= rb then return ra < rb end
        return (a.id or 0) < (b.id or 0)
    end)
    for i, c in ipairs(rest) do t[from + i - 1] = c end
end

-- Journal court (pour /dwe spoken).
Focus.log = {}
local function Log(msg)
    local t = Focus.log
    t[#t + 1] = string.format("%.1f %s", GetTime and GetTime() or 0, msg)
    if #t > 12 then table.remove(t, 1) end
end
Focus.Log = Log
Focus.IsBook = IsBook

local function NpcLineWaiting(queue)
    for _, clip in ipairs(queue.sounds or {}) do
        if not IsBook(clip) then return true end
    end
    return false
end

-- Arrete le livre en cours (il reste en tete de file) ; la file repart sur ce qui n'est pas retenu.
local function YieldBook()
    local api, queue = Env()
    if not api then return end
    if api.IsPaused and api:IsPaused() then return end -- mis en pause par le joueur : on n'y touche pas
    local ok, playing = pcall(queue.IsPlaying, queue)
    local head = queue.GetCurrentSound and queue:GetCurrentSound()
    Log("yield? playing=" .. tostring(ok and playing) .. " headBook=" .. tostring(IsBook(head)) .. " src=" .. SourceName(head))
    if ok and playing and IsBook(head) and Focus.Heard(head) then
        -- Spoken re-interroge les verrous pour la ligne en cours : elle s'arrete et reste en tete.
        if type(queue.RecheckGates) == "function" and head.source then
            local okR, stopped = pcall(queue.RecheckGates, queue, head.source)
            Log("recheck stopped=" .. tostring(okR and stopped))
            if okR and stopped then return end
        end
        pcall(api.Pause, api)
        pcall(api.Resume, api)
        Log("pause/resume")
    end
end

-- Relance la file (le livre reprend si plus rien ne le retient).
local function Wake()
    local api, queue = Env()
    if not api or (api.IsPaused and api:IsPaused()) then return end
    if type(queue.Advance) == "function" then pcall(queue.Advance, queue) end
end

-- Repliques deja ecoutees en entier (cle de la ligne Spoken), sauvegardees.
local HEARD_MAX = 3000
function Focus.Heard(clip)
    -- Test (/storytale forget) : tout ce livre compte comme jamais ecoute, jusqu'au /reload.
    if Focus.unheardBook and IsBook(clip) and GroupKey(clip) == Focus.unheardBook then return false end
    local h = rawget(_G, "DialogueWheelE_SpokenHeard")
    return type(h) == "table" and type(clip) == "table" and clip.key ~= nil and h[tostring(clip.key)] ~= nil
end
function Focus.MarkHeard(clip)
    if type(DialogueWheelE_SpokenHeard) ~= "table" then DialogueWheelE_SpokenHeard = {} end
    local h = DialogueWheelE_SpokenHeard
    local k = tostring(clip.key)
    if h[k] then return end
    h.n = (h.n or 0) + 1
    h[k] = h.n
    -- Trop de lignes : on oublie les plus anciennes.
    if h.n % 500 == 0 then
        local cut = h.n - HEARD_MAX
        for key, v in pairs(h) do if key ~= "n" and type(v) == "number" and v <= cut then h[key] = nil end end
    end
end

-- Un livre est en train d'etre lu a voix haute (pas en pause, pas retenu).
function Focus.BookSpeaking()
    local api, queue = Env()
    if not api or not queue then return false end
    if api.IsPaused and api:IsPaused() then return false end
    local now = queue.GetNowPlaying and queue:GetNowPlaying()
    return now ~= nil and IsBook(now)
end
-- Titre du livre lu a voix haute en ce moment (nil sinon).
function Focus.SpeakingBookTitle()
    local _, queue = Env()
    local now = queue and queue.GetNowPlaying and queue:GetNowPlaying()
    if not (now and IsBook(now)) then return nil end
    return GroupKey(now):sub(6)
end
-- Test : oublie que les lignes du livre ouvert (dans la file de Spoken) ont ete ecoutees.
function Focus.ForgetOpenBook()
    local h = rawget(_G, "DialogueWheelE_SpokenHeard")
    local _, queue = Env()
    if type(h) ~= "table" or not queue then return 0 end
    local n, seen = 0, {}
    local list = {}
    for _, c in ipairs(queue.sounds or {}) do list[#list + 1] = c end
    local cur = queue.GetCurrentSound and queue:GetCurrentSound()
    if cur then list[#list + 1] = cur end
    for _, c in ipairs(list) do
        if IsBook(c) and c.key ~= nil and not seen[c] then
            seen[c] = true
            Focus.unheardBook = Focus.unheardBook or GroupKey(c)
            local k = tostring(c.key)
            if h[k] then h[k] = nil; n = n + 1 end
        end
    end
    return n
end

function Focus.Install()
    if Focus.installed then return end
    local api = Env()
    if not api or type(api.AddGate) ~= "function" then return end
    Focus.installed = true
    pcall(api.AddGate, api, function(clip)
        -- Choisi dans la file de lecture : celui-la d'abord, les autres attendent.
        if Focus.forced then
            local _, q = Env()
            if q and GroupQueued(q, Focus.forced) then
                if GroupKey(clip) == Focus.forced then return nil end
                return DWE.L.SPOKEN_WAIT
            end
            Focus.forced = nil
        end
        -- Les PNJ ne se retiennent pas entre eux : chacun parle a son tour (ordre d'arrivee).
        if not IsBook(clip) then return nil end
        if Focus.bookMuted then return DWE.L.SPOKEN_MUTED end
        -- Jamais ecoute en entier : le livre garde la priorite, le PNJ attend son tour.
        if not Focus.Heard(clip) then return nil end
        local _, queue = Env()
        if Focus.npc or (queue and NpcLineWaiting(queue)) then
            return DWE.L.SPOKEN_WAIT
        end
        return nil
    end)
    -- Spoken jette une replique de PNJ "basse priorite" si une ligne normale attend deja
    -- (raison "outranked") : un livre en attente la ferait donc disparaitre. Pendant une
    -- conversation, les lignes de livre comptent comme basses le temps d'admettre la replique.
    local _, queue = Env()
    if queue and type(queue.Add) == "function" and not queue.dweWrapped then
        queue.dweWrapped = true
        local origAdd = queue.Add
        queue.Add = function(self, clip, source, front)
            local lowered
            -- (Spoken peut traiter l'evenement du PNJ avant nous : la fenetre ouverte compte aussi.)
            local talking = Focus.npc
                or (GossipFrame and GossipFrame:IsShown()) or (QuestFrame and QuestFrame:IsShown())
            -- Entre PNJ differents (ou face a un livre), la priorite basse/normale de Spoken ne
            -- doit rien jeter : la ligne du PNJ actuel entre, celles des autres restent en attente.
            if talking and type(clip) == "table" and not IsBook(clip) then
                local who = SpeakerOf(clip)
                local want = clip.priority == "low" and "low" or nil
                lowered = {}
                for _, c in ipairs(self.sounds or {}) do
                    local other = IsBook(c) or (SpeakerOf(c) ~= who)
                    if other and (c.priority == "low") ~= (want == "low") then
                        lowered[#lowered + 1] = { c, c.priority }
                        c.priority = want or "normal"
                    end
                end
                if #lowered > 0 then Log("line admitted past " .. #lowered .. " waiting") end
            end
            -- Une ligne en attente ne disparait que si elle est ecoutee ou fermee : pas de limite
            -- de file par source pendant l'ajout.
            local limit = type(source) == "table" and source.queueLimit
            if limit then source.queueLimit = nil end
            -- Un livre attend dans la file : la replique du PNJ passe devant lui (sinon elle attend
            -- derriere le livre retenu, d'ou un long silence). On le sort le temps de l'ajout.
            local parked
            if talking and type(clip) == "table" and not IsBook(clip) and type(self.sounds) == "table" then
                local cur = self.GetCurrentSound and self:GetCurrentSound()
                for i = #self.sounds, 1, -1 do
                    local c = self.sounds[i]
                    if c ~= cur and IsBook(c) and Focus.Heard(c) then
                        parked = parked or {}
                        table.insert(parked, 1, table.remove(self.sounds, i))
                    end
                end
                if parked then Log("line put before " .. #parked .. " waiting book line(s)") end
            end
            local okAdd, r1, r2 = pcall(origAdd, self, clip, source, front)
            if parked then for _, c in ipairs(parked) do table.insert(self.sounds, c) end end
            if not okAdd then error(r1, 0) end
            if limit then source.queueLimit = limit end
            if lowered then for _, l in ipairs(lowered) do l[1].priority = l[2] end end
            return r1, r2
        end
    end
    -- Une ligne de PNJ arrive pendant qu'un livre parle : le livre cede sa place.
    if type(api.RegisterCallback) == "function" then
        pcall(api.RegisterCallback, api, "CLIP_QUEUED", function(clip)
            Log("queued book=" .. tostring(IsBook(clip)) .. " who=" .. tostring(SpeakerOf(clip)))
            if IsBook(clip) then
                -- Nouveau livre ouvert : un autre livre deja ecoute en entier (en cours ou en
                -- attente) lui cede la place et quitte la file.
                local _, q = Env()
                local key = GroupKey(clip)
                if q and type(q.RemoveSoundFromQueue) == "function" then
                    for i = #(q.sounds or {}), 1, -1 do
                        local c = q.sounds[i]
                        if c and c ~= clip and IsBook(c) and GroupKey(c) ~= key and Focus.Heard(c) then
                            Log("book already heard, dropped: " .. tostring(GroupKey(c)))
                            pcall(q.RemoveSoundFromQueue, q, c)
                        end
                    end
                end
                return
            end
            local who = SpeakerOf(clip)
            local talking = Focus.npc
                or (GossipFrame and GossipFrame:IsShown()) or (QuestFrame and QuestFrame:IsShown())
            if who and (talking or not Focus.speaker) then
                Focus.speaker = who
                PushSpeaker(who)
            end
            -- On parle a quelqu'un : la conversation en cours reprend la priorite sur un choix fait
            -- dans la file de lecture.
            if talking and Focus.forced and Focus.forced ~= GroupKey(clip) then Focus.forced = nil end
            local _, queue = Env()
            if not queue then return end
            local head = queue.GetCurrentSound and queue:GetCurrentSound()
            if IsBook(head) then
                -- Un livre cede sa place a la conversation.
                YieldBook()
            elseif talking and head and head ~= clip and SpeakerOf(head) ~= who and Focus.Heard(head) then
                -- Le PNJ qui parle redit une replique deja ecoutee en entier : on la coupe et elle
                -- ne revient pas dans la file. Une replique jamais entendue, elle, finit d'abord.
                Log("already heard, cut: " .. tostring(SpeakerOf(head)))
                pcall(queue.RemoveSoundFromQueue, queue, head)
            end
        end)
        -- Repliques ecoutees jusqu'au bout : retenues d'une session a l'autre.
        pcall(api.RegisterCallback, api, "CLIP_STOPPED", function(clip, finished)
            if finished and type(clip) == "table" and clip.key then
                Focus.MarkHeard(clip)
                -- Derniere ligne d'un livre narree en entier : livre lu.
                if IsBook(clip) and DWE.MarkBook then
                    local key, more = GroupKey(clip), false
                    local _, q = Env()
                    for _, c in ipairs(q and q.sounds or {}) do
                        if c ~= clip and IsBook(c) and GroupKey(c) == key then more = true break end
                    end
                    if not more then DWE.MarkBook(key:sub(6), true) end
                end
            end
        end)
        pcall(api.RegisterCallback, api, "CLIP_DROPPED", function(clip, reason)
            Log("DROPPED book=" .. tostring(IsBook(clip)) .. " src=" .. SourceName(clip) .. " why=" .. tostring(reason))
        end)
    end
end

-- Conversation avec un PNJ ouverte / fermee.
function Focus.SetNPC(on)
    on = on and true or false
    if Focus.npc == on then return end
    Focus.npc = on
    Log("npc=" .. tostring(on))
    if on then
        YieldBook()
    elseif C_Timer and C_Timer.After then
        C_Timer.After(0.3, Wake)
    else
        Wake()
    end
end

-- /dwe spoken : etat de la file de Spoken et derniers evenements.
function Focus.Report()
    local api, queue = Env()
    print("|cff33ff99DWE|r Spoken focus: installed=" .. tostring(Focus.installed) .. " npc=" .. tostring(Focus.npc) .. " speaker=" .. tostring(Focus.speaker) .. " api=" .. tostring(api ~= nil))
    if queue then
        print(string.format("  paused=%s playing=%s size=%d", tostring(api:IsPaused()), tostring(queue:IsPlaying()), #(queue.sounds or {})))
        for i, clip in ipairs(queue.sounds or {}) do
            local held = queue.GetHeldReason and queue:GetHeldReason(clip)
            local p = type(clip.present) == "table" and clip.present or {}
            print(string.format("  %d. book=%s who=%s bullet=%s material=%s prio=%s held=%s", i, tostring(IsBook(clip)),
                tostring(SpeakerOf(clip)), tostring(p.bullet), tostring(p.material), tostring(clip.priority), tostring(held)))
        end
    end
    local ui = DWE.SpokenQueueUI
    if ui then
        local n = 0
        for _ in pairs(ui.buttons or {}) do n = n + 1 end
        print("  queue button: installed=" .. tostring(ui.installed) .. " windows=" .. n
            .. " actions=" .. tostring(rawget(_G, "SpokenEnv") and type(SpokenEnv.Actions)))
    end
    for _, line in ipairs(Focus.log) do print("  " .. line) end
end

-- Bouton "Couper la voix" sous un livre : Spoken ne lit plus ce livre (on lit soi-meme).
function Focus.Available()
    return Env() ~= nil
end
function Focus.SetBookMuted(on)
    Focus.Install()
    Focus.bookMuted = on and true or nil
    Log("bookMuted=" .. tostring(Focus.bookMuted))
    if on then YieldBook() else Wake() end
end
-- Livre ferme : si la voix etait coupee, on retire ses lignes de la file (rien ne reste en attente).
function Focus.OnBookClosed()
    if not Focus.bookMuted then return end
    Focus.bookMuted = nil
    local _, queue = Env()
    if queue and type(queue.RemoveSoundFromQueue) == "function" then
        for i = #(queue.sounds or {}), 1, -1 do
            local clip = queue.sounds[i]
            if IsBook(clip) then pcall(queue.RemoveSoundFromQueue, queue, clip) end
        end
    end
    Wake()
end

-- File de lecture (petit lecteur de Spoken) ------------------------------------------------
-- Les groupes en attente, dans l'ordre de lecture : { key, label, book, count, current }.
function Focus.Groups()
    local _, queue = Env()
    local list, byKey = {}, {}
    if not queue then return list end
    for i, c in ipairs(queue.sounds or {}) do
        local key = GroupKey(c)
        if key then
            local g = byKey[key]
            if not g then
                local p = type(c.present) == "table" and c.present or {}
                local label = IsBook(c) and key:sub(6) or SpeakerOf(c) or p.label or p.header
                if IsBook(c) and DialogueWheelE_ReadMarks ~= false and DWE.BookState and DWE.BookState(key:sub(6)) == 2 then
                    label = DWE.READ_ICON .. " " .. tostring(label)
                end
                g = { key = key, label = tostring(label or "?"), book = IsBook(c), count = 0, current = false }
                byKey[key] = g
                list[#list + 1] = g
            end
            g.count = g.count + 1
            if i == 1 and queue.IsPlaying and queue:IsPlaying() then g.current = true end
        end
    end
    return list
end
-- Ecouter ce groupe maintenant : il passe devant, celui qui parlait attend sa place.
function Focus.PlayGroup(key)
    local api, queue = Env()
    if not queue or not GroupQueued(queue, key) then return end
    Focus.Install()
    Focus.forced = key
    local who = key:match("^npc:(.*)$")
    if who then Focus.speaker = who; PushSpeaker(who) end
    if key:match("^book:") and Focus.bookMuted then Focus.bookMuted = nil end
    Log("play group " .. key)
    if api.IsPaused and api:IsPaused() and api.Resume then pcall(api.Resume, api) end
    Reorder(queue)
    local head = queue.GetCurrentSound and queue:GetCurrentSound()
    if head and GroupKey(head) ~= key and head.source and type(queue.RecheckGates) == "function"
        and queue:GetHeldReason(head) and queue:IsPlaying() then
        pcall(queue.RecheckGates, queue, head.source)
    else
        Wake()
    end
    Reorder(queue)
end
-- Fermer ce groupe : ses lignes quittent la file (celle qui parle s'arrete).
function Focus.CloseGroup(key)
    local _, queue = Env()
    if not queue or type(queue.RemoveSoundFromQueue) ~= "function" then return end
    Log("close group " .. key)
    if Focus.forced == key then Focus.forced = nil end
    for i = #(queue.sounds or {}), 1, -1 do
        local c = queue.sounds[i]
        if c and GroupKey(c) == key then pcall(queue.RemoveSoundFromQueue, queue, c) end
    end
    Wake()
end
