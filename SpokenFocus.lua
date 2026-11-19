-- Storytale : priorite de lecture avec Spoken.
-- Un livre lu par Spoken s'arrete quand on parle a un PNJ : la voix du PNJ passe d'abord, puis
-- le livre reprend (la phrase en cours recommence : Spoken ne sait pas reprendre au milieu).
-- On ne change rien a Spoken : on lui ajoute un "verrou" (Spoken:AddGate) qui retient les
-- lignes de livre tant qu'une conversation avec un PNJ est ouverte ou qu'une ligne de PNJ attend.
-- Entre PNJ, meme regle : le PNJ a qui l'on parle passe d'abord ; celui qui parlait s'arrete et
-- attend. Ensuite, les PNJ interrompus reprennent, le plus recent d'abord.

local Focus = { npc = false }
DWE.SpokenFocus = Focus
-- "File de lecture intelligente" (option, active par defaut). Decochee, Spoken gere seul l'ordre
-- de lecture : aucune regle de priorite, coupure, attente de livre ni relance n'est appliquee.
-- Restent les actions demandees par le joueur (choisir/fermer dans la file, couper la voix d'un livre).
function Focus.Smart()
    return DialogueWheelE_SpokenSmart ~= false
end

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
-- Salutation d'un PNJ (pas une ligne de quete) : priorite basse chez Spoken, ou salutation de
-- donneur de quetes (Spoken la met en priorite normale, mais c'est bien une salutation).
-- Une replique demandee (page choisie apres la salutation) n'en est pas une.
local function IsGreeting(clip)
    if type(clip) ~= "table" or IsBook(clip) or clip.dweAsked then return false end
    if (clip.dweOrigPriority or clip.priority) == "low" then return true end
    return type(clip.present) == "table" and clip.present.bullet == "gossip"
end

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

-- La ligne vient-elle du PNJ a qui l'on parle ? (le texte de quete porte parfois le titre de
-- la quete en en-tete, pas le nom du PNJ : on compare donc la salutation au PNJ ouvert.)
function Focus.IsCurrentNPC(clip)
    local who = SpeakerOf(clip)
    local npc = UnitName and UnitName("npc")
    if type(who) ~= "string" or type(npc) ~= "string" then return true end
    if issecretvalue and (issecretvalue(who) or issecretvalue(npc)) then return true end
    return who == npc
end
-- Clic sur une quete : la salutation du PNJ (priorite basse) s'arrete tout de suite, sans
-- attendre que Spoken ait prepare le texte de la quete.
function Focus.CutGreeting()
    local _, queue = Env()
    local head = queue and queue.GetCurrentSound and queue:GetCurrentSound()
    if not (head and head.priority == "low" and not IsBook(head)) then return end
    local npc = UnitName and UnitName("npc")
    local who = SpeakerOf(head)
    if type(npc) == "string" and type(who) == "string" and not (issecretvalue and (issecretvalue(npc) or issecretvalue(who)))
        and who ~= npc then return end
    Log("greeting cut on quest click: " .. tostring(who))
    pcall(queue.RemoveSoundFromQueue, queue, head)
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
-- Le livre est-il dans la file de Spoken (en lecture, en pause ou en attente) ?
function Focus.BookQueued(key)
    local _, queue = Env()
    if not (queue and key) then return false end
    for _, c in ipairs(queue.sounds or {}) do
        if IsBook(c) and DWE.BookKey(GroupKey(c):sub(6)) == key then return true end
    end
    return false
end
-- Meme PNJ ? Seulement si les deux noms sont connus et identiques (une salutation n'a parfois
-- pas de nom : deux salutations "sans nom" de PNJ differents ne sont pas le meme PNJ).
function Focus.SameSpeaker(a, b)
    local wa, wb = SpeakerOf(a), SpeakerOf(b)
    return wa ~= nil and wa == wb
end
-- Une voix qui n'est pas celle du PNJ a qui l'on parle (un autre PNJ, ou un livre sans son
-- livre a l'ecran) : le petit lecteur reste visible, ce n'est pas un doublon de la bulle.
function Focus.ForeignSpeaking()
    local api, queue = Env()
    if not api or not queue then return false end
    if api.IsPaused and api:IsPaused() then return false end
    local now = queue.GetNowPlaying and queue:GetNowPlaying()
    if not now then return false end
    if IsBook(now) then return not (DWE.BookOpenNow and DWE.BookOpenNow()) end
    -- Dialogue en train de se fermer (plus de PNJ ouvert) : rien a doublonner, on ne cache pas
    -- (sinon le lecteur disparaissait un instant pendant le fondu de fermeture).
    local npc = UnitName and UnitName("npc")
    if npc == nil then return true end
    return not Focus.IsCurrentNPC(now)
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
    -- Petit lecteur de Spoken : d'une page a l'autre du meme livre, il ne s'efface pas pour
    -- revenir (fondu de Spoken entre deux lignes) ; la page suivante prend simplement sa place.
    local env = rawget(_G, "SpokenEnv")
    local sk = type(env) == "table" and rawget(env, "DialogueUIPlayer")
    if type(sk) == "table" and type(sk.WillTurn) == "function" and not sk.dweTurnHook then
        sk.dweTurnHook = true
        local orig = sk.WillTurn
        sk.WillTurn = function(self, clip, ...)
            if IsBook(self.clip) and IsBook(clip) and GroupKey(self.clip) == GroupKey(clip) then
                return false
            end
            return orig(self, clip, ...)
        end
    end
    -- Sous-titres de Spoken (sa mini-fenetre) : sur la 1re page d'un livre, le 1er mot a souvent
    -- un temps faux (il "commence" pendant la lecture du titre). Tant que la voix n'a pas atteint
    -- ce mot, Spoken considere que rien n'est encore lu : pas de surbrillance pendant le titre.
    local tr = type(env) == "table" and rawget(env, "Transcript")
    if type(tr) == "table" and type(tr.IsSpeaking) == "function" and not tr.dweTitleHook then
        tr.dweTitleHook = true
        local origSpeaking = tr.IsSpeaking
        tr.IsSpeaking = function(self, progress, ...)
            local speaking = origSpeaking(self, progress, ...)
            if not speaking or not progress then return speaking end
            local start = Focus.FirstWordStart(self)
            if start and progress * (self.totalWeight or 0) < start then return false end
            return speaking
        end
    end
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
        if not Focus.Smart() then return nil end
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
            if not Focus.Smart() then return origAdd(self, clip, source, front) end
            -- Ligne de quete d'un PNJ que l'on vient de quitter (Spoken la lit ~0.4 s apres
            -- l'ouverture de la fenetre) : on parle deja a quelqu'un d'autre, elle n'a pas
            -- commence, on l'ignore. Sauf si Spoken lit les quetes a la fermeture (voulu).
            if type(clip) == "table" and not IsBook(clip) and not IsGreeting(clip)
                and Focus.leftName and SpeakerOf(clip) == Focus.leftName
                and GetTime and (GetTime() - (Focus.leftAt or 0)) < 1.5
                and SourceName({ source = source }) == "quests" then
                local now = UnitName and UnitName("npc")
                local ace = LibStub and LibStub("AceAddon-3.0", true)
                local sq = ace and ace:GetAddon("SpokenQuests", true)
                local afterClose = sq and sq.db and sq.db.profile and sq.db.profile.Audio
                    and sq.db.profile.Audio.ReadAfterClose
                if now and now ~= Focus.leftName and not afterClose then
                    Log("left before read, skipped: " .. tostring(Focus.leftName))
                    Focus.lineSeq = (Focus.lineSeq or 0) + 1
                    return nil, "left"
                end
            end
            -- Salutation generique (priorite basse) : jamais mise en attente. Elle ne passe que si
            -- rien ne parle, ou si ce qui parle peut etre coupe (salutation deja ecoutee).
            -- Replique demandee (page de dialogue apres la salutation) : elle se met en file
            -- comme une ligne normale, apres ce qui attend deja (sans rien couper).
            if type(clip) == "table" and clip.priority == "low" and not IsBook(clip)
                and (Focus.gossipPage or 0) > 1 then
                clip.priority = "normal"
                clip.dweAsked = true
                Log("asked line queued: " .. tostring(SpeakerOf(clip)))
            end
            if IsGreeting(clip) then
                local head = self.sounds and self.sounds[1]
                if head then
                    -- (Un livre en tete garde ses propres regles : la ligne entre, le livre decide.)
                    -- La salutation d'un autre PNJ (meme pas finie) cede a celle du PNJ a qui l'on
                    -- parle maintenant : on passe de l'un a l'autre sans silence.
                    local cuttable = IsBook(head) or (IsGreeting(head) and not Focus.SameSpeaker(head, clip))
                    -- Une ligne de quete parle (jamais coupee) et l'on parle maintenant a ce PNJ :
                    -- sa salutation attend la fin de cette ligne (souvent courte). Si on ferme sa
                    -- fenetre avant qu'elle commence, elle quitte la file (voir SetNPC).
                    local name = UnitName and UnitName("npc")
                    if not cuttable and not IsGreeting(head) and name and SpeakerOf(clip) == name
                        and not Focus.SameSpeaker(head, clip) then
                        clip.dweWaitGreeting = true
                        Log("greeting waits for quest line: " .. tostring(name))
                    elseif not cuttable then
                        Log("greeting not queued: " .. tostring(SpeakerOf(clip)))
                        Focus.lineSeq = (Focus.lineSeq or 0) + 1
                        return nil, "busy"
                    end
                end
            end
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
                        c.dweOrigPriority = c.priority
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
            if lowered then for _, l in ipairs(lowered) do l[1].priority, l[1].dweOrigPriority = l[2], nil end end
            return r1, r2
        end
    end
    -- Une ligne de PNJ arrive pendant qu'un livre parle : le livre cede sa place.
    if type(api.RegisterCallback) == "function" then
        pcall(api.RegisterCallback, api, "CLIP_QUEUED", function(clip)
            Log("queued book=" .. tostring(IsBook(clip)) .. " who=" .. tostring(SpeakerOf(clip)))
            if not IsBook(clip) then Focus.lineSeq = (Focus.lineSeq or 0) + 1 end
            if IsBook(clip) and not Focus.Smart() then return end
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
            if not Focus.Smart() then return end
            local _, queue = Env()
            if not queue then return end
            local head = queue.GetCurrentSound and queue:GetCurrentSound()
            if IsBook(head) then
                -- Un livre cede sa place a la conversation.
                YieldBook()
            elseif talking and head and head ~= clip and IsGreeting(head) and not IsGreeting(clip)
                and Focus.IsCurrentNPC(head) then
                -- Le meme PNJ passe de sa salutation (repetee a chaque visite, priorite basse) a un
                -- texte de quete (dit une fois) : la salutation s'arrete, la quete parle tout de suite.
                Log("greeting cut for quest text: " .. tostring(who))
                pcall(queue.RemoveSoundFromQueue, queue, head)
            elseif talking and head and head ~= clip and not Focus.SameSpeaker(head, clip)
                and IsGreeting(clip) and IsGreeting(head) then
                -- Nouvelle salutation : celle d'un autre PNJ s'arrete (on parle a quelqu'un d'autre).
                Log("greeting switched: " .. tostring(SpeakerOf(head)) .. " -> " .. tostring(who))
                pcall(queue.RemoveSoundFromQueue, queue, head)
            elseif talking and head and head ~= clip and SpeakerOf(head) ~= who and Focus.Heard(head)
                and IsGreeting(head) then
                -- (Seule une salutation deja ecoutee peut etre coupee. Une ligne de quete ne l'est
                -- jamais, meme deja ecoutee : elle finit, puis la suivante.)
                -- Le PNJ qui parle redit une replique deja ecoutee en entier : on la coupe et elle
                -- ne revient pas dans la file. Une replique jamais entendue, elle, finit d'abord.
                Log("already heard, cut: " .. tostring(SpeakerOf(head)))
                pcall(queue.RemoveSoundFromQueue, queue, head)
            end
        end)
        -- Repliques ecoutees jusqu'au bout : retenues d'une session a l'autre.
        pcall(api.RegisterCallback, api, "CLIP_STOPPED", function(clip, finished)
            if finished and IsBook(clip) and DWE.BookPageDone then
                pcall(DWE.BookPageDone, Focus.PageNumber(clip))
            end
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
            if not IsBook(clip) then Focus.lineSeq = (Focus.lineSeq or 0) + 1 end
        end)
    end
end

-- Numero de page (dans son livre) d'une ligne de Spoken Readables, ou nil.
function Focus.PageNumber(clip)
    local sr = rawget(_G, "SpokenReadables")
    if type(clip) ~= "table" or not clip.pageId or type(sr) ~= "table" or type(sr.PlaceOf) ~= "function" then return nil end
    local ok, _, number = pcall(sr.PlaceOf, sr, clip.pageId)
    return ok and tonumber(number) or nil
end

-- Debut reel du 1er mot d'un livre quand son temps enregistre est faux (titre lu avant), ou nil.
-- Reconnu a un ecart anormal entre le 1er et le 2e mot ; le 1er commence alors un mot moyen
-- avant le 2e. Calcule une fois par ligne.
function Focus.FirstWordStart(tr)
    local clip, words = tr.clip, tr.words
    if not (clip and IsBook(clip) and tr.timed and type(words) == "table" and #words >= 3) then return nil end
    if Focus.fwsClip == clip and Focus.fwsWords == words then return Focus.fwsStart end
    Focus.fwsClip, Focus.fwsWords, Focus.fwsStart = clip, words, nil
    local n = #words
    local w1, w2, wn = words[1], words[2], words[n]
    if not (w1.start and w2.start and wn.start) then return nil end
    local avg = (wn.start - w2.start) / math.max(1, n - 2)
    if avg > 0 and (w2.start - w1.start) > avg * 4 + 1 then
        Focus.fwsStart = w2.start - avg
    end
    return Focus.fwsStart
end

-- Une page de dialogue s'ouvre. Quand on passe vite d'un PNJ a l'autre, Spoken Quests attend que
-- la fenetre de DialogueUI soit entierement affichee pour lire la salutation ; si l'ancienne
-- fenetre finit de se fermer pendant cette attente, la lecture est oubliee et le PNJ reste muet.
-- Si aucune ligne n'est arrivee peu apres, on redemande la lecture (Spoken applique toujours
-- ses propres regles : frequence des salutations, lecture auto, etc. ; un doublon est refuse).
-- Meme chose pour une page de quete (Spoken la lit quand le texte est stable, ~0.4 s) : on
-- attend un peu plus longtemps avant de redemander.
function Focus.WatchPage(event)
    event = event or "GOSSIP_SHOW"
    local quest = event == "QUEST_DETAIL" or event == "QUEST_PROGRESS" or event == "QUEST_COMPLETE"
    if not (C_Timer and C_Timer.After and UnitGUID) or not Focus.Smart() then return end
    local guid, seq = UnitGUID("npc"), Focus.lineSeq or 0
    if not guid then return end
    Focus.pageSerial = (Focus.pageSerial or 0) + 1
    local serial = Focus.pageSerial
    C_Timer.After(quest and 1.3 or 0.9, function()
        if Focus.pageSerial ~= serial or (Focus.lineSeq or 0) ~= seq then return end
        if not Focus.npc or UnitGUID("npc") ~= guid then return end
        local name = UnitName and UnitName("npc")
        local _, queue = Env()
        for _, c in ipairs(queue and queue.sounds or {}) do
            if not IsBook(c) and name and SpeakerOf(c) == name then return end
        end
        local ace = LibStub and LibStub("AceAddon-3.0", true)
        local sq = ace and ace:GetAddon("SpokenQuests", true)
        if not (sq and type(sq.DispatchDirectEvent) == "function") then return end
        if quest and sq.db and sq.db.profile and sq.db.profile.Audio and sq.db.profile.Audio.ReadAfterClose then return end
        Log("page read again: " .. tostring(name) .. " (" .. event .. ")")
        pcall(sq.DispatchDirectEvent, sq, event, "page not read")
    end)
end

-- Conversation avec un PNJ ouverte / fermee.
function Focus.SetNPC(on)
    on = on and true or false
    if Focus.npc == on then return end
    Focus.npc = on
    -- Qui l'on quitte (et quand) : sa ligne de quete pas encore lue sera ignoree (voir Add).
    if on then
        Focus.npcName = UnitName and UnitName("npc") or nil
    else
        Focus.leftName, Focus.leftAt = Focus.npcName, GetTime and GetTime() or 0
        Focus.npcName = nil
    end
    Log("npc=" .. tostring(on))
    if on then
        if Focus.Smart() then YieldBook() end
    else
        -- Fenetre fermee : une salutation qui attendait son tour ne sert plus a rien.
        local _, queue = Env()
        if queue and type(queue.RemoveSoundFromQueue) == "function" then
            local cur = queue.GetCurrentSound and queue:GetCurrentSound()
            for i = #(queue.sounds or {}), 1, -1 do
                local c = queue.sounds[i]
                if c and c ~= cur and c.dweWaitGreeting then
                    Log("waiting greeting dropped: " .. tostring(SpeakerOf(c)))
                    pcall(queue.RemoveSoundFromQueue, queue, c)
                end
            end
        end
        if C_Timer and C_Timer.After then C_Timer.After(0.3, Wake) else Wake() end
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
        if Focus.HighlightReport then Focus.HighlightReport() end
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
    DialogueWheelE_BookVoiceOff = Focus.bookMuted -- retenu : les livres suivants restent muets
    Log("bookMuted=" .. tostring(Focus.bookMuted))
    if on then YieldBook() else Wake() end
end
-- Livre ferme : si la voix etait coupee, on retire ses lignes de la file (rien ne reste en attente).
function Focus.OnBookClosed()
    if not Focus.bookMuted then return end
    -- Voix coupee par le joueur (reglage retenu) : elle le reste pour le prochain livre.
    if DialogueWheelE_BookVoiceOff ~= true then Focus.bookMuted = nil end
    local _, queue = Env()
    if queue and type(queue.RemoveSoundFromQueue) == "function" then
        for i = #(queue.sounds or {}), 1, -1 do
            local clip = queue.sounds[i]
            if IsBook(clip) then pcall(queue.RemoveSoundFromQueue, queue, clip) end
        end
    end
    Wake()
end

-- Option "couper la voix a la fermeture" : retire de la file de Spoken toutes les lignes de livre,
-- celle qui est lue comprise (les repliques des PNJ et des quetes restent).
function Focus.StopBooks()
    local _, queue = Env()
    if not (queue and type(queue.RemoveSoundFromQueue) == "function") then return end
    for i = #(queue.sounds or {}), 1, -1 do
        local clip = queue.sounds[i]
        if IsBook(clip) then pcall(queue.RemoveSoundFromQueue, queue, clip) end
    end
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

-- Mots lus en surbrillance dans le livre / la note / la plaque de Storytale -------------------
-- Comme les sous-titres de Spoken : le mot que la voix lit (et son voisin) est colore dans le
-- texte du livre. Suit le reglage "Surligner les mots" de Spoken ; rien si la voix du livre est
-- coupee, ou si la ligne lue n'est pas le texte affiche (correspondance de Spoken:WordMarks).
-- Un texte est decoupe en paragraphes (lignes vides) : la note montre toutes les pages d'un
-- coup, et chaque page lue doit se retrouver a sa place, pas au premier mot identique.
do
    local hl = { shown = {} } -- shown[fs] = { base = texte d'origine, now = texte affiche }
    local ticker = CreateFrame("Frame", nil, DWE.textBox) -- ne tourne que livre/texte ouvert
    local acc = 0

    local function Restore()
        for fs, st in pairs(hl.shown) do
            if fs:GetText() == st.now and st.now ~= st.base then fs:SetText(st.base) end
            st.now = st.base
        end
        hl.clip, hl.map, hl.lit, hl.neighbor = nil, nil, nil, nil
    end
    Focus.RestoreHighlight = Restore
    -- Couleur de la surbrillance (pour le petit bouton sous le livre), en {r, g, b}.
    function DWE.HighlightRGB()
        local hex = hl.color
        if not hex then
            local mat = DWE.BookLook and DWE.BookLook() == "note" and DWE.PlateMaterial and DWE.PlateMaterial()
            hex = (mat and DWE.PLATE_MARK and DWE.PLATE_MARK[mat]) or "|cff9c1a1a"
        end
        local r, g, b = hex:match("|c%x%x(%x%x)(%x%x)(%x%x)")
        if not r then return { 0.61, 0.10, 0.10 } end
        return { tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255 }
    end
    function Focus.HighlightReport()
        local d = hl.dbg
        if not d then print("  highlight: none") return end
        print(string.format("  highlight: timed=%s lead=%s raw=%s active=%s prog=%s tw=%s s1=%s note=%s page=%s m1=%s title=%s",
            tostring(d.timed), tostring(d.lead), tostring(d.raw), tostring(d.active), tostring(d.prog), tostring(d.tw),
            tostring(d.s1), tostring(d.note), tostring(d.page), tostring(d.m1), tostring(d.title)))
    end

    local function Texts()
        local list = {}
        local note = DWE.NOTE and DWE.NOTE.noteText
        for _, fs in ipairs({ DWE.textBody, DWE.textBody2, note }) do
            if fs and fs:IsVisible() then list[#list + 1] = fs end
        end
        return list
    end

    -- Paragraphes d'un texte : { fs, text, from (octet de debut dans le texte entier) }.
    local function Split(fs, text, out)
        local from = 1
        while true do
            local s, e = text:find("\n%s*\n", from)
            local piece = text:sub(from, (s or (#text + 1)) - 1)
            out[#out + 1] = { fs = fs, text = piece, from = from }
            if not s then break end
            from = e + 1
        end
    end

    ticker:SetScript("OnUpdate", function(_, elapsed)
        acc = acc + elapsed
        if acc < 0.02 then return end -- ~50 fois par seconde : le mot change pile avec la voix
        acc = 0
        local sp = rawget(_G, "Spoken")
        local box = DWE.textBox
        local ok = sp and type(sp.GetCaption) == "function" and type(sp.WordMarks) == "function"
            and type(sp.SplitCaption) == "function" and box and box:IsShown()
            and DWE.BookByAddon and DWE.BookByAddon() and not Focus.bookMuted
        local caption = ok and sp:GetCaption()
        local clip = caption and caption.clip
        if not (clip and IsBook(clip) and caption.highlight) then Restore() return end
        local Marks = sp:WordMarks()
        -- Nouvelle page lue : le suivi reprend (meme si une page avait ete tournee a la main).
        if clip ~= hl.followClip then hl.followClip = clip; DWE.bookFollowPause = nil end
        -- Livre ouvert : tourne la page (ou la sous-page) ou en est la voix.
        if DWE.BookFollow then
            local pr = type(clip.present) == "table" and clip.present or {}
            local text = pr.transcript or clip.text
            local share
            local aw = caption.speaking and caption.activeWord
            local wd = aw and caption.words and caption.words[aw]
            if wd and type(text) == "string" and #text > 0 then share = (wd.first or 1) / #text end
            DWE.BookFollow(text, share, Focus.PageNumber(clip))
        end
        -- Texte affiche : repris a chaque changement (page tournee, mise en page refaite).
        local fss, changed = Texts(), false
        for _, fs in ipairs(fss) do
            local st = hl.shown[fs]
            local cur = fs:GetText() or ""
            if not st or cur ~= st.now then
                hl.shown[fs] = { base = cur, now = cur }
                changed = true
            end
        end
        if changed or clip ~= hl.clip then
            Restore()
            hl.paras, hl.fss = {}, fss
            local mat = DWE.BookLook and DWE.BookLook() == "note" and DWE.PlateMaterial and DWE.PlateMaterial()
            for _, fs in ipairs(fss) do
                local pieces = {}
                Split(fs, hl.shown[fs].base, pieces)
                local color = (mat and DWE.PLATE_MARK and DWE.PLATE_MARK[mat]) or Marks.ColorFor(fs:GetTextColor())
                hl.color = color
                for _, para in ipairs(pieces) do
                    local words = sp:SplitCaption(para.text)
                    para.words = Marks.MarkLinks(para.text, words or {})
                    para.color = color
                    hl.paras[#hl.paras + 1] = para
                end
            end
            if clip ~= hl.clip and DWE.NoteFollowReset then DWE.NoteFollowReset() end
            hl.clip = clip
            hl.map = #hl.paras > 0 and Marks.Align(caption.words, hl.paras) or nil
            -- Premiere page sans temps enregistres : le narrateur lit le titre avant le texte,
            -- mais Spoken estime les mots comme si le texte commencait tout de suite. On calcule
            -- la part du titre comme Spoken Readables le fait quand il a les temps.
            hl.lead = nil
            local first = hl.map and hl.map[1]
            local info = DWE.bookInfo
            if first and first.p == 1 and first.w == 1
                and info and (info.note or (info.page == 1 and (not DWE.bookSub or (DWE.bookSub.index or 1) == 1)))
                and type(sp.CaptionWords) == "function" then
                local pr = type(clip.present) == "table" and clip.present or {}
                local title = pr.label or pr.header
                local function Bare(t) return (string.gsub(string.lower(t or ""), "[%s%p]", "")) end
                local text = pr.transcript or clip.text
                if type(title) == "string" and title ~= "" and type(text) == "string"
                    and string.sub(Bare(text), 1, #Bare(title)) ~= Bare(title) then
                    local okA, _, total = pcall(sp.CaptionWords, sp, text)
                    local okB, _, heading = pcall(sp.CaptionWords, sp, title .. ".")
                    if okA and okB and tonumber(total) and tonumber(heading) and total > 0 and heading > 0 then
                        hl.lead = heading / (heading + total)
                    end
                end
            end
        end
        if not hl.map then return end
        -- Premiere page : le narrateur lit d'abord le titre (absent du texte de Spoken). Avant le
        -- debut du premier mot, Spoken donne quand meme le mot 1 : rien n'est allume.
        local active = caption.speaking and caption.activeWord or nil
        local w = active and caption.words and caption.words[active]
        local w1 = caption.words and caption.words[1]
        -- Temps enregistres qui ignorent le titre (le premier mot "commence" avant la fin du
        -- titre lu) : meme correction que pour les temps estimes. Sinon, temps fiables : rien
        -- n'est allume avant le debut du premier mot.
        local badTimes = caption.timed and hl.lead and w1 and caption.totalWeight
            and (w1.start or 0) < hl.lead * caption.totalWeight * 0.5
        -- Souvent seul le 1er mot est faux : il "commence" au debut du clip (titre compris),
        -- mais les mots suivants ont leurs vrais temps. On garde alors les temps de Spoken et on
        -- fait seulement commencer le 1er mot un mot moyen avant le 2e.
        local w2 = caption.words and caption.words[2]
        if badTimes and w2 and (w2.start or 0) >= hl.lead * caption.totalWeight * 0.7 then
            badTimes = false
            local n = #caption.words
            local wn = caption.words[n]
            local avg = (n > 2 and wn and wn.start and (wn.start - w2.start) / (n - 2)) or 0.35
            local s1 = math.max(w1.start or 0, w2.start - avg)
            if active == 1 and caption.progress * caption.totalWeight < s1 then active = nil end
        end
        if w and caption.timed and not badTimes and caption.progress and caption.totalWeight and w.start
            and caption.progress * caption.totalWeight < w.start then
            active = nil
        elseif active and badTimes and caption.progress then
            -- Temps enregistres pour le texte seul : ils restent exacts entre eux, il ne manque
            -- que le titre devant. Sa duree = longueur du clip - duree du texte (dernier mot + un
            -- mot moyen). Bien plus precis que l'estimation par le poids des mots.
            local words, n, len = caption.words, #caption.words, caption.totalWeight
            if hl.shiftFor ~= clip then
                hl.shiftFor = clip
                local last = words[n].start or 0
                local avg = n > 1 and last / (n - 1) or 0.3
                local shift = len - (last + avg)
                local est = hl.lead * len
                -- Mesure incoherente (temps etires sur tout le clip) : on garde l'estimation,
                -- en etirant les temps apres le titre.
                if shift < est * 0.5 or shift > len * 0.6 then shift = nil end
                hl.shift = shift
            end
            local t
            if hl.shift then
                t = caption.progress * len - hl.shift
            else
                t = (caption.progress - hl.lead) / (1 - hl.lead) * len
            end
            if t < (words[1].start or 0) then
                active = nil
            else
                local low, high = 1, n
                while low < high do
                    local mid = math.floor((low + high) / 2)
                    if (words[mid].finish or len) <= t then low = mid + 1 else high = mid end
                end
                active = low
            end
        elseif active and hl.lead and not caption.timed and caption.progress and caption.totalWeight then
            -- Temps estimes : le texte ne commence qu'apres le titre.
            if caption.progress < hl.lead then
                active = nil
            else
                local target = (caption.progress - hl.lead) / (1 - hl.lead) * caption.totalWeight
                local words, low, high = caption.words, 1, #caption.words
                while low < high do
                    local mid = math.floor((low + high) / 2)
                    if words[mid].finish <= target then low = mid + 1 else high = mid end
                end
                active = low
            end
        end
        hl.dbg = { timed = caption.timed, lead = hl.lead, raw = caption.activeWord, active = active,
            prog = caption.progress, tw = caption.totalWeight, s1 = caption.words and caption.words[1] and caption.words[1].start,
            note = DWE.bookInfo and DWE.bookInfo.note, page = DWE.bookInfo and DWE.bookInfo.page,
            m1 = hl.map[1] and (hl.map[1].p .. "/" .. hl.map[1].w),
            title = type(clip.present) == "table" and (clip.present.label or clip.present.header) }
        local lit, neighbor = Marks.Pick(hl.map, active)
        -- Note qui defile : elle suit le mot lu (option, sauf si le joueur fait defiler).
        local at = lit and hl.map[lit]
        local note = DWE.NOTE and DWE.NOTE.noteText
        if at and note and hl.paras[at.p] and hl.paras[at.p].fs == note and DWE.NoteFollow then
            local para = hl.paras[at.p]
            local word = para.words[at.w]
            if word then DWE.NoteFollow(hl.shown[note].base:sub(1, para.from + word.last - 1)) end
        end
        if lit == hl.lit and neighbor == hl.neighbor then return end
        hl.lit, hl.neighbor = lit, neighbor
        local spans = (lit and DialogueWheelE_BookHighlight ~= false) and Marks.Spans(hl.map, hl.paras, lit, neighbor) or {}
        -- Chaque texte est recompose : ses paragraphes, colores ou non, et ce qui les separe.
        local byFs = {}
        for p, para in ipairs(hl.paras) do
            local list = spans[p]
            if list then
                table.sort(list, function(a, b) return a.first < b.first end)
                local shifted = {}
                for _, sw in ipairs(list) do
                    shifted[#shifted + 1] = { first = sw.first + para.from - 1, last = sw.last + para.from - 1 }
                end
                byFs[para.fs] = byFs[para.fs] or {}
                for _, sw in ipairs(shifted) do table.insert(byFs[para.fs], sw) end
                byFs[para.fs].color = para.color
            end
        end
        for _, fs in ipairs(hl.fss or {}) do
            local st = hl.shown[fs]
            local list = byFs[fs]
            local want = st.base
            if list then
                table.sort(list, function(a, b) return a.first < b.first end)
                want = Marks.Wrap(st.base, list, list.color)
            end
            if want ~= st.now then
                fs:SetText(want)
                st.now = want
            end
        end
    end)
    if DWE.GuardScripts then DWE.GuardScripts(ticker, "highlight") end
end
