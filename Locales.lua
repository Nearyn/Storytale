-- Storytale - Locales.lua
-- Table globale de l'addon et textes. Charge en premier (voir le .toc).
-- La langue est detectee automatiquement (GetLocale). Ordre de recherche d'un texte :
--   1. le texte traduit par Blizzard dans le jeu (boutons de quete, "Au revoir"...) ;
--   2. la traduction de cet addon (panneau d'options surtout) ;
--   3. l'anglais.

DWE = {
    selectedIndex = 1,
    currentOptions = {},
    needBindingClear = false,
    needsItemRefresh = false,
    hoveredRewardBtn = nil,
    selectedRewardIndex = nil,
    hasDialogueText = false,
    lastQuestEvent = nil,
}

local LOCALE = GetLocale and GetLocale() or "enUS"
DWE.LOCALE = LOCALE
-- Polices des clients coreen et chinois : les polices latines n'y ont pas les caracteres.
DWE.IS_CJK = (LOCALE == "koKR" or LOCALE == "zhCN" or LOCALE == "zhTW")
DWE.IS_CYRILLIC = (LOCALE == "ruRU")

local enUS = {
    ACCEPT = "Accept Quest",
    CONTINUE = "Continue",
    INCOMPLETE = "Objectives in progress...",
    COMPLETE = "Complete Quest",
    CHOOSE_HDR = "Choose one of these rewards:",
    CHOICES_HDR = "You will be able to choose one of these rewards:",
    REQ_ITEMS = "Required items:",
    GOODBYE = "Goodbye",
    OBJ = "Objectives: ",
    REWARDS = "Rewards: ",
    TEXT_BTN = "Spoken",
    NO_TEXT = "...",
    NEXT_PAGE = "Next Page",
    PREV_PAGE = "Previous Page",
    LOADING = "Loading...",
    OPT_SUB = "Dialogue frame appearance:",
    THEME_TRANS = "Transparent",
    THEME_DARK = "Semi-Transparent (Dark)",
    THEME_PARCH = "Parchment",
    THEME_PARCH_DARK = "Parchment (Dark)",
    THEME_DUI_BROWN = "Parchment (DialogueUI)",
    THEME_FOLIO = "Folio",
    THEME_FOLIO_DARK = "Night Folio",
    THEME_DUI_DARK = "Parchment Dark (DialogueUI)",
    FONT_FAMILY = "Font:",
    FONT_DEFAULT = "default",
    FONT_LOCKED = "This language uses the game font.",
    FONT_SIZE = "Font size",
    SCALE_LBL = "Frame scale",
    OPACITY_LBL = "Background opacity",
    KEY_USE_BLIZZ = "Use Blizzard interact key",
    KEY_CUSTOM = "Choose key:",
    KEY_TOGGLE = "Dialogue key:",
    ESC_CLOSE = "Escape closes the conversation",
    SPOKEN_CHOICE = "Show the \"Spoken\" choice in the wheel (switch to Spoken's window)",
    KEY_PRESS = "Press a key... (Esc = none)",
    KEY_NONE = "None",
    KEY_BLIZZ_TAG = " (Blizzard)",
    WHEEL_SCROLL = "Scroll choices with mouse wheel (hold click to zoom)",
    SPOKEN_THEME = "Match Spoken window to theme",
    ATTACH_NPC = "Attach to the NPC (follows the camera)",
    ATTACH_TIP = "Right-click drag the wheel or text to move them (they stay attached).",
    NPC_RESET = "Reset position and size",
    THEME_BUBBLE = "Speech bubble",
    THEME_BUBBLE_FANTASY = "Speech bubble (fantasy)",
    LOCK = "Lock (no moving or resizing)",
    WHEEL_THEME = "Apply the theme to the dialogue wheel",
    DM_FACTION = "Darkmoon Faire",
    DM_TICKET = "Darkmoon Faire Prize Ticket",
    REPUTATION = "Reputation",
}

local T = {}

T.frFR = {
    NO_TEXT = "...",
    NEXT_PAGE = "Page suivante",
    PREV_PAGE = "Page précédente",
    OPT_SUB = "Apparence du cadre de dialogue :",
    THEME_DARK = "Semi-transparent (sombre)",
    THEME_PARCH = "Parchemin",
    THEME_PARCH_DARK = "Parchemin (sombre)",
    THEME_DUI_BROWN = "Parchemin (DialogueUI)",
    THEME_FOLIO = "Folio",
    THEME_FOLIO_DARK = "Folio nocturne",
    THEME_DUI_DARK = "Parchemin sombre (DialogueUI)",
    FONT_FAMILY = "Police d'écriture :",
    FONT_DEFAULT = "défaut",
    FONT_LOCKED = "Cette langue utilise la police du jeu.",
    FONT_SIZE = "Taille de police",
    SCALE_LBL = "Taille du cadre",
    OPACITY_LBL = "Opacité du fond",
    KEY_USE_BLIZZ = "Utiliser la touche d'interaction Blizzard",
    KEY_CUSTOM = "Touche dédiée :",
    KEY_TOGGLE = "Touche Dialogue :",
    KEY_PRESS = "Appuyez sur une touche... (Échap = aucune)",
    KEY_NONE = "Aucune",
    WHEEL_SCROLL = "Molette pour changer de choix (maintenir clic pour zoomer)",
    SPOKEN_THEME = "Adapter la fenêtre Spoken au thème",
    DM_FACTION = "Foire de Sombrelune",
    DM_TICKET = "Bon pour un prix de la Foire de Sombrelune",
    ATTACH_NPC = "Attacher au PNJ (suit la caméra)",
    ATTACH_TIP = "Clic droit maintenu sur la roue ou le texte pour les déplacer (ils restent attachés).",
    NPC_RESET = "Réinitialiser position et taille",
    THEME_BUBBLE = "Bulle de dialogue",
    LOCK = "Verrouiller (ni déplacement ni redimensionnement)",
    THEME_BUBBLE_FANTASY = "Bulle de dialogue (fantasy)",
    WHEEL_THEME = "Appliquer le thème à la roue de dialogue",
    ESC_CLOSE = "Échap ferme la conversation",
    SPOKEN_CHOICE = "Afficher le choix « Spoken » dans la roue (passer à la fenêtre de Spoken)",
}

T.deDE = {
    NO_TEXT = "...",
    NEXT_PAGE = "Nächste Seite",
    PREV_PAGE = "Vorherige Seite",
    OPT_SUB = "Aussehen des Dialogfensters:",
    THEME_TRANS = "Transparent",
    THEME_DARK = "Halbtransparent (dunkel)",
    THEME_PARCH = "Pergament",
    THEME_PARCH_DARK = "Pergament (dunkel)",
    THEME_DUI_BROWN = "Pergament (DialogueUI)",
    THEME_DUI_DARK = "Dunkles Pergament (DialogueUI)",
    FONT_FAMILY = "Schriftart:",
    FONT_DEFAULT = "Standard",
    FONT_LOCKED = "Diese Sprache verwendet die Spielschrift.",
    FONT_SIZE = "Schriftgröße",
    SCALE_LBL = "Fenstergröße",
    OPACITY_LBL = "Hintergrund-Deckkraft",
    KEY_USE_BLIZZ = "Blizzard-Interaktionstaste verwenden",
    KEY_CUSTOM = "Eigene Taste:",
    KEY_TOGGLE = "Dialog-Taste:",
    KEY_PRESS = "Taste drücken... (Esc = keine)",
    KEY_NONE = "Keine",
    WHEEL_SCROLL = "Auswahl mit dem Mausrad (Klick halten zum Zoomen)",
    SPOKEN_THEME = "Spoken-Fenster an das Thema anpassen",
    ATTACH_NPC = "Am NPC anheften (folgt der Kamera)",
    ATTACH_TIP = "Rad oder Text mit gedrückter rechter Maustaste verschieben (bleiben angeheftet).",
    NPC_RESET = "Position und Größe zurücksetzen",
    THEME_BUBBLE = "Sprechblase",
    LOCK = "Sperren (kein Verschieben oder Größenändern)",
    THEME_BUBBLE_FANTASY = "Sprechblase (Fantasy)",
    WHEEL_THEME = "Thema auf das Dialograd anwenden",
    ESC_CLOSE = "Esc beendet das Gespräch",
}

T.esES = {
    NO_TEXT = "...",
    NEXT_PAGE = "Página siguiente",
    PREV_PAGE = "Página anterior",
    OPT_SUB = "Aspecto del marco de diálogo:",
    THEME_TRANS = "Transparente",
    THEME_DARK = "Semitransparente (oscuro)",
    THEME_PARCH = "Pergamino",
    THEME_PARCH_DARK = "Pergamino (oscuro)",
    THEME_DUI_BROWN = "Pergamino (DialogueUI)",
    THEME_DUI_DARK = "Pergamino oscuro (DialogueUI)",
    FONT_FAMILY = "Fuente:",
    FONT_DEFAULT = "predeterminada",
    FONT_LOCKED = "Este idioma usa la fuente del juego.",
    FONT_SIZE = "Tamaño de fuente",
    SCALE_LBL = "Tamaño del marco",
    OPACITY_LBL = "Opacidad del fondo",
    KEY_USE_BLIZZ = "Usar la tecla de interacción de Blizzard",
    KEY_CUSTOM = "Tecla propia:",
    KEY_TOGGLE = "Tecla Diálogo:",
    KEY_PRESS = "Pulsa una tecla... (Esc = ninguna)",
    KEY_NONE = "Ninguna",
    WHEEL_SCROLL = "Cambiar de opción con la rueda (mantén clic para zoom)",
    SPOKEN_THEME = "Adaptar la ventana de Spoken al tema",
    ATTACH_NPC = "Anclar al PNJ (sigue la cámara)",
    ATTACH_TIP = "Arrastra la rueda o el texto con clic derecho (siguen anclados).",
    NPC_RESET = "Restablecer posición y tamaño",
    THEME_BUBBLE = "Bocadillo de diálogo",
    LOCK = "Bloquear (sin mover ni redimensionar)",
    THEME_BUBBLE_FANTASY = "Bocadillo de diálogo (fantasía)",
    WHEEL_THEME = "Aplicar el tema a la rueda de diálogo",
    ESC_CLOSE = "Esc cierra la conversación",
}
T.esMX = T.esES

T.itIT = {
    NO_TEXT = "...",
    NEXT_PAGE = "Pagina successiva",
    PREV_PAGE = "Pagina precedente",
    OPT_SUB = "Aspetto della finestra di dialogo:",
    THEME_TRANS = "Trasparente",
    THEME_DARK = "Semitrasparente (scuro)",
    THEME_PARCH = "Pergamena",
    THEME_PARCH_DARK = "Pergamena (scura)",
    THEME_DUI_BROWN = "Pergamena (DialogueUI)",
    THEME_DUI_DARK = "Pergamena scura (DialogueUI)",
    FONT_FAMILY = "Carattere:",
    FONT_DEFAULT = "predefinito",
    FONT_LOCKED = "Questa lingua usa il carattere del gioco.",
    FONT_SIZE = "Dimensione carattere",
    SCALE_LBL = "Dimensione finestra",
    OPACITY_LBL = "Opacità dello sfondo",
    KEY_USE_BLIZZ = "Usa il tasto di interazione Blizzard",
    KEY_CUSTOM = "Tasto dedicato:",
    KEY_TOGGLE = "Tasto Dialogo:",
    KEY_PRESS = "Premi un tasto... (Esc = nessuno)",
    KEY_NONE = "Nessuno",
    WHEEL_SCROLL = "Scorri le scelte con la rotella (tieni premuto per lo zoom)",
    SPOKEN_THEME = "Adatta la finestra di Spoken al tema",
    ATTACH_NPC = "Ancora al PNG (segue la telecamera)",
    ATTACH_TIP = "Trascina la ruota o il testo col tasto destro (restano ancorati).",
    NPC_RESET = "Ripristina posizione e dimensione",
    THEME_BUBBLE = "Fumetto",
    LOCK = "Blocca (niente spostamento né ridimensionamento)",
    THEME_BUBBLE_FANTASY = "Fumetto (fantasy)",
    WHEEL_THEME = "Applica il tema alla ruota di dialogo",
    ESC_CLOSE = "Esc chiude la conversazione",
}

T.ptBR = {
    NO_TEXT = "...",
    NEXT_PAGE = "Próxima página",
    PREV_PAGE = "Página anterior",
    OPT_SUB = "Aparência da janela de diálogo:",
    THEME_TRANS = "Transparente",
    THEME_DARK = "Semitransparente (escuro)",
    THEME_PARCH = "Pergaminho",
    THEME_PARCH_DARK = "Pergaminho (escuro)",
    THEME_DUI_BROWN = "Pergaminho (DialogueUI)",
    THEME_DUI_DARK = "Pergaminho escuro (DialogueUI)",
    FONT_FAMILY = "Fonte:",
    FONT_DEFAULT = "padrão",
    FONT_LOCKED = "Este idioma usa a fonte do jogo.",
    FONT_SIZE = "Tamanho da fonte",
    SCALE_LBL = "Tamanho da janela",
    OPACITY_LBL = "Opacidade do fundo",
    KEY_USE_BLIZZ = "Usar a tecla de interação da Blizzard",
    KEY_CUSTOM = "Tecla própria:",
    KEY_TOGGLE = "Tecla Diálogo:",
    KEY_PRESS = "Pressione uma tecla... (Esc = nenhuma)",
    KEY_NONE = "Nenhuma",
    WHEEL_SCROLL = "Trocar de escolha com a roda (segure o clique para zoom)",
    SPOKEN_THEME = "Adaptar a janela do Spoken ao tema",
    ATTACH_NPC = "Prender ao PNJ (segue a câmera)",
    ATTACH_TIP = "Arraste a roda ou o texto com o botão direito (continuam presos).",
    NPC_RESET = "Redefinir posição e tamanho",
    THEME_BUBBLE = "Balão de fala",
    LOCK = "Travar (sem mover nem redimensionar)",
    THEME_BUBBLE_FANTASY = "Balão de fala (fantasia)",
    WHEEL_THEME = "Aplicar o tema à roda de diálogo",
    ESC_CLOSE = "Esc fecha a conversa",
}

T.ruRU = {
    TEXT_BTN = "Spoken",
    NO_TEXT = "...",
    NEXT_PAGE = "Следующая страница",
    PREV_PAGE = "Предыдущая страница",
    OPT_SUB = "Оформление окна диалога:",
    THEME_TRANS = "Прозрачное",
    THEME_DARK = "Полупрозрачное (тёмное)",
    THEME_PARCH = "Пергамент",
    THEME_PARCH_DARK = "Пергамент (тёмный)",
    THEME_DUI_BROWN = "Пергамент (DialogueUI)",
    THEME_DUI_DARK = "Тёмный пергамент (DialogueUI)",
    FONT_FAMILY = "Шрифт:",
    FONT_DEFAULT = "по умолчанию",
    FONT_LOCKED = "Для этого языка используется шрифт игры.",
    FONT_SIZE = "Размер шрифта",
    SCALE_LBL = "Размер окна",
    OPACITY_LBL = "Непрозрачность фона",
    KEY_USE_BLIZZ = "Клавиша взаимодействия Blizzard",
    KEY_CUSTOM = "Своя клавиша:",
    KEY_TOGGLE = "Клавиша «Диалог»:",
    KEY_PRESS = "Нажмите клавишу... (Esc = нет)",
    KEY_NONE = "Нет",
    WHEEL_SCROLL = "Выбор колесом мыши (удерживайте кнопку для зума)",
    SPOKEN_THEME = "Окно Spoken в стиле темы",
    ATTACH_NPC = "Привязать к НИП (следует за камерой)",
    ATTACH_TIP = "Перетаскивайте колесо или текст правой кнопкой мыши (они остаются привязанными).",
    NPC_RESET = "Сбросить положение и размер",
    THEME_BUBBLE = "Облачко реплики",
    LOCK = "Закрепить (без перемещения и изменения размера)",
    THEME_BUBBLE_FANTASY = "Облачко реплики (фэнтези)",
    WHEEL_THEME = "Применить тему к колесу диалога",
    ESC_CLOSE = "Esc закрывает разговор",
}

T.koKR = {
    TEXT_BTN = "Spoken",
    NO_TEXT = "...",
    NEXT_PAGE = "다음 페이지",
    PREV_PAGE = "이전 페이지",
    OPT_SUB = "대화창 모양:",
    THEME_TRANS = "투명",
    THEME_DARK = "반투명 (어두움)",
    THEME_PARCH = "양피지",
    THEME_PARCH_DARK = "양피지 (어두움)",
    THEME_DUI_BROWN = "양피지 (DialogueUI)",
    THEME_DUI_DARK = "어두운 양피지 (DialogueUI)",
    FONT_FAMILY = "글꼴:",
    FONT_DEFAULT = "기본",
    FONT_LOCKED = "이 언어는 게임 글꼴을 사용합니다.",
    FONT_SIZE = "글꼴 크기",
    SCALE_LBL = "창 크기",
    OPACITY_LBL = "배경 불투명도",
    KEY_USE_BLIZZ = "블리자드 상호작용 키 사용",
    KEY_CUSTOM = "전용 키:",
    KEY_TOGGLE = "대화 키:",
    KEY_PRESS = "키를 누르세요... (Esc = 없음)",
    KEY_NONE = "없음",
    WHEEL_SCROLL = "마우스 휠로 선택 (클릭 유지 시 확대/축소)",
    SPOKEN_THEME = "Spoken 창을 테마에 맞춤",
    ATTACH_NPC = "NPC에 고정 (카메라를 따라감)",
    ATTACH_TIP = "오른쪽 클릭으로 끌어 휠이나 텍스트를 옮기세요 (고정 유지).",
    NPC_RESET = "위치와 크기 초기화",
    THEME_BUBBLE = "말풍선",
    LOCK = "잠금 (이동 및 크기 조절 불가)",
    THEME_BUBBLE_FANTASY = "말풍선 (판타지)",
    WHEEL_THEME = "대화 휠에 테마 적용",
    ESC_CLOSE = "Esc로 대화 닫기",
}

T.zhCN = {
    TEXT_BTN = "Spoken",
    NO_TEXT = "...",
    NEXT_PAGE = "下一页",
    PREV_PAGE = "上一页",
    OPT_SUB = "对话框外观：",
    THEME_TRANS = "透明",
    THEME_DARK = "半透明（深色）",
    THEME_PARCH = "羊皮纸",
    THEME_PARCH_DARK = "羊皮纸（深色）",
    THEME_DUI_BROWN = "羊皮纸（DialogueUI）",
    THEME_DUI_DARK = "深色羊皮纸（DialogueUI）",
    FONT_FAMILY = "字体：",
    FONT_DEFAULT = "默认",
    FONT_LOCKED = "此语言使用游戏字体。",
    FONT_SIZE = "字体大小",
    SCALE_LBL = "窗口大小",
    OPACITY_LBL = "背景不透明度",
    KEY_USE_BLIZZ = "使用暴雪互动按键",
    KEY_CUSTOM = "自定义按键：",
    KEY_TOGGLE = "对话按键：",
    KEY_PRESS = "请按一个键……（Esc = 无）",
    KEY_NONE = "无",
    WHEEL_SCROLL = "用鼠标滚轮切换选项（按住点击可缩放）",
    SPOKEN_THEME = "让 Spoken 窗口匹配主题",
    ATTACH_NPC = "附着在NPC上（跟随镜头）",
    ATTACH_TIP = "按住右键拖动轮盘或文字（仍保持附着）。",
    NPC_RESET = "重置位置和大小",
    THEME_BUBBLE = "对话气泡",
    LOCK = "锁定（禁止移动和调整大小）",
    THEME_BUBBLE_FANTASY = "对话气泡（奇幻）",
    WHEEL_THEME = "将主题应用到对话轮盘",
    ESC_CLOSE = "Esc 关闭对话",
}

T.zhTW = {
    TEXT_BTN = "Spoken",
    NO_TEXT = "...",
    NEXT_PAGE = "下一頁",
    PREV_PAGE = "上一頁",
    OPT_SUB = "對話框外觀：",
    THEME_TRANS = "透明",
    THEME_DARK = "半透明（深色）",
    THEME_PARCH = "羊皮紙",
    THEME_PARCH_DARK = "羊皮紙（深色）",
    THEME_DUI_BROWN = "羊皮紙（DialogueUI）",
    THEME_DUI_DARK = "深色羊皮紙（DialogueUI）",
    FONT_FAMILY = "字型：",
    FONT_DEFAULT = "預設",
    FONT_LOCKED = "此語言使用遊戲字型。",
    FONT_SIZE = "字型大小",
    SCALE_LBL = "視窗大小",
    OPACITY_LBL = "背景不透明度",
    KEY_USE_BLIZZ = "使用暴雪互動按鍵",
    KEY_CUSTOM = "自訂按鍵：",
    KEY_TOGGLE = "對話按鍵：",
    KEY_PRESS = "請按一個鍵……（Esc = 無）",
    KEY_NONE = "無",
    WHEEL_SCROLL = "用滑鼠滾輪切換選項（按住點擊可縮放）",
    SPOKEN_THEME = "讓 Spoken 視窗符合主題",
    ATTACH_NPC = "附著在NPC上（跟隨鏡頭）",
    ATTACH_TIP = "按住右鍵拖曳輪盤或文字（仍保持附著）。",
    NPC_RESET = "重設位置和大小",
    THEME_BUBBLE = "對話氣泡",
    LOCK = "鎖定（禁止移動和調整大小）",
    THEME_BUBBLE_FANTASY = "對話氣泡（奇幻）",
    WHEEL_THEME = "將主題套用到對話輪盤",
    ESC_CLOSE = "Esc 關閉對話",
}

-- Textes deja traduits par Blizzard dans le jeu (GlobalStrings) : utilises en priorite,
-- dans la langue du joueur. Les traductions ci-dessus ne servent qu'en secours.
local COLON = (type(HEADER_COLON) == "string" and HEADER_COLON or ":") .. " "
local function Game(globalName, suffix)
    local s = _G[globalName]
    if type(s) == "string" and s ~= "" then return s .. (suffix or "") end
end
local GAME = {
    ACCEPT = Game("ACCEPT"),
    CONTINUE = Game("CONTINUE"),
    COMPLETE = Game("COMPLETE_QUEST"),
    GOODBYE = Game("GOODBYE"),
    INCOMPLETE = Game("INCOMPLETE"),
    OBJ = Game("QUEST_OBJECTIVES", COLON),
    REWARDS = Game("REWARDS", COLON),
    REQ_ITEMS = Game("TURN_IN_ITEMS"),
    CHOOSE_HDR = Game("REWARD_CHOOSE"),
    CHOICES_HDR = Game("REWARD_CHOICES"),
    LOADING = Game("RETRIEVING_ITEM_INFO"),
    REPUTATION = Game("REPUTATION"),
}

-- Titre des recompenses au choix quand on ne peut pas encore choisir (si le jeu ne le fournit pas)
local CHOICES = {
    frFR = "Vous pourrez choisir une de ces récompenses :", deDE = "Ihr dürft Euch eine dieser Belohnungen aussuchen:",
    esES = "Podrás elegir una de estas recompensas:", esMX = "Podrás elegir una de estas recompensas:",
    itIT = "Potrai scegliere una di queste ricompense:", ptBR = "Você poderá escolher uma destas recompensas:",
    ruRU = "Вы сможете выбрать одну из наград:", koKR = "다음 보상 중 하나를 선택할 수 있습니다:",
    zhCN = "你可以从这些奖励中选择一个：", zhTW = "你可以從這些獎勵中選擇一個：",
}
for loc, str in pairs(CHOICES) do if T[loc] then T[loc].CHOICES_HDR = str end end

-- "<joueur>" (ligne du dessus) "vous partage une quete"
enUS.SHARED_QUEST = "is sharing a quest with you"
local SHARED = {
    frFR = "vous partage une quête", deDE = "teilt eine Quest mit Euch",
    esES = "comparte una misión contigo", esMX = "comparte una misión contigo",
    itIT = "condivide una missione con te", ptBR = "está compartilhando uma missão com você",
    ruRU = "делится с вами заданием", koKR = "님이 퀘스트를 공유합니다",
    zhCN = "与你共享了一个任务", zhTW = "與你分享了一個任務",
}
for loc, str in pairs(SHARED) do if T[loc] then T[loc].SHARED_QUEST = str end end

-- Noms des themes et libelles des options (toutes les langues).
local NAMES = {
    --          Sans cadre / Voile / Parchemin / Grimoire / DUI / DUI nuit / Bulle / Bulle enl. / Velin / Arcane / Sylvain / Nuit
    enUS = { "Frameless", "Shadow Veil", "Old Parchment", "Dark Grimoire", "DialogueUI Parchment", "DialogueUI Night Parchment", "Azeroth Bubble", "Illuminated Bubble", "Gilded Vellum", "Arcane", "Sylvan", "Starlit Night" },
    frFR = { "Sans cadre", "Voile d'ombre", "Parchemin ancien", "Grimoire sombre", "Parchemin de DialogueUI", "Parchemin nocturne (DialogueUI)", "Bulle d'Azeroth", "Bulle enluminée", "Vélin doré", "Arcanes", "Sylvain", "Nuit étoilée" },
    deDE = { "Rahmenlos", "Schattenschleier", "Altes Pergament", "Dunkles Grimoire", "DialogueUI-Pergament", "DialogueUI-Nachtpergament", "Azeroth-Sprechblase", "Illuminierte Sprechblase", "Goldenes Velin", "Arkan", "Sylvanisch", "Sternennacht" },
    esES = { "Sin marco", "Velo de sombra", "Pergamino antiguo", "Grimorio oscuro", "Pergamino de DialogueUI", "Pergamino nocturno (DialogueUI)", "Bocadillo de Azeroth", "Bocadillo iluminado", "Vitela dorada", "Arcano", "Silvano", "Noche estrellada" },
    itIT = { "Senza cornice", "Velo d'ombra", "Pergamena antica", "Grimorio oscuro", "Pergamena di DialogueUI", "Pergamena notturna (DialogueUI)", "Fumetto di Azeroth", "Fumetto miniato", "Pergamena dorata", "Arcano", "Silvano", "Notte stellata" },
    ptBR = { "Sem moldura", "Véu de sombra", "Pergaminho antigo", "Grimório sombrio", "Pergaminho do DialogueUI", "Pergaminho noturno (DialogueUI)", "Balão de Azeroth", "Balão iluminado", "Velino dourado", "Arcano", "Silvestre", "Noite estrelada" },
    ruRU = { "Без рамки", "Покров тени", "Старый пергамент", "Тёмный гримуар", "Пергамент DialogueUI", "Ночной пергамент (DialogueUI)", "Облачко Азерота", "Расписное облачко", "Золочёный пергамент", "Тайная магия", "Лесной", "Звёздная ночь" },
    koKR = { "테두리 없음", "그림자 장막", "오래된 양피지", "어둠의 마법서", "DialogueUI 양피지", "DialogueUI 밤 양피지", "아제로스 말풍선", "채색 말풍선", "금박 양피지", "비전", "숲의 정령", "별이 빛나는 밤" },
    zhCN = { "无边框", "暗影帷幕", "古旧羊皮纸", "黑暗魔典", "DialogueUI 羊皮纸", "DialogueUI 夜色羊皮纸", "艾泽拉斯气泡", "彩饰气泡", "鎏金羊皮纸", "奥术", "林地", "星夜" },
    zhTW = { "無邊框", "暗影帷幕", "古舊羊皮紙", "黑暗魔典", "DialogueUI 羊皮紙", "DialogueUI 夜色羊皮紙", "艾澤拉斯對話泡泡", "彩飾對話泡泡", "鎏金羊皮紙", "秘法", "林地", "星夜" },
}
NAMES.esMX = NAMES.esES
local NAME_KEYS = { "THEME_TRANS", "THEME_DARK", "THEME_PARCH", "THEME_PARCH_DARK", "THEME_DUI_BROWN", "THEME_DUI_DARK", "THEME_BUBBLE", "THEME_BUBBLE_FANTASY", "THEME_VELIN", "THEME_ARCANE", "THEME_SYLVAN", "THEME_STARRY" }
for loc, list in pairs(NAMES) do
    local dest = (loc == "enUS") and enUS or T[loc]
    if dest then for i, key in ipairs(NAME_KEYS) do dest[key] = list[i] end end
end

-- Titres des sections et libelles revus des options.
local OPTS = {
    enUS = { SEC_THEME = "Theme", SEC_TEXT = "Text", SEC_PLACE = "Placement", SEC_KEYS = "Controls",
        THEME_HINT = "Click a theme to apply it.", FONT_FAMILY = "Font", FONT_SIZE = "Text size",
        OPACITY_LBL = "Frame opacity", WHEEL_THEME = "Also dress the choice wheel",
        SPOKEN_THEME = "Also dress the Spoken player", ATTACH_NPC = "Follow the NPC on screen",
        ATTACH_TIP = "Hold right-click on the wheel or the text to move them.", LOCK = "Lock frames",
        NPC_RESET = "Reset position and size", KEY_USE_BLIZZ = "Use the game's Interact key",
        KEY_TOGGLE = "\"Dialogue\" key:", ESC_CLOSE = "Escape ends the conversation",
        WHEEL_SCROLL = "Mouse wheel browses choices (hold click to zoom)",
        BOOK_STYLE = "Books and letters:", BOOK_ADDON = "This addon, with a parchment theme (Gilded Vellum if a bubble theme is chosen)",
        BOOK_DUI = "DialogueUI", BOOK_BLIZZ = "Game window" },
    frFR = { SEC_THEME = "Thème", SEC_TEXT = "Texte", SEC_PLACE = "Placement", SEC_KEYS = "Commandes",
        THEME_HINT = "Cliquez sur un thème pour l'appliquer.", FONT_FAMILY = "Police", FONT_SIZE = "Taille du texte",
        OPACITY_LBL = "Opacité du cadre", WHEEL_THEME = "Habiller aussi la roue des choix",
        SPOKEN_THEME = "Habiller aussi le lecteur Spoken", ATTACH_NPC = "Suivre le PNJ à l'écran",
        ATTACH_TIP = "Clic droit maintenu sur la roue ou le texte pour les déplacer.", LOCK = "Verrouiller les cadres",
        NPC_RESET = "Réinitialiser position et taille", KEY_USE_BLIZZ = "Utiliser la touche « Interagir » du jeu",
        KEY_TOGGLE = "Touche « Dialogue » :", ESC_CLOSE = "Échap termine la conversation",
        WHEEL_SCROLL = "La molette parcourt les choix (clic maintenu : zoom)",
        BOOK_STYLE = "Livres et lettres :", BOOK_ADDON = "Cet addon, avec un thème parchemin (Vélin doré si un thème bulle est choisi)",
        BOOK_DUI = "DialogueUI", BOOK_BLIZZ = "Fenêtre du jeu" },
    deDE = { SEC_THEME = "Thema", SEC_TEXT = "Text", SEC_PLACE = "Platzierung", SEC_KEYS = "Steuerung", THEME_HINT = "Klickt auf ein Thema, um es anzuwenden." },
    esES = { SEC_THEME = "Tema", SEC_TEXT = "Texto", SEC_PLACE = "Posición", SEC_KEYS = "Controles", THEME_HINT = "Haz clic en un tema para aplicarlo." },
    itIT = { SEC_THEME = "Tema", SEC_TEXT = "Testo", SEC_PLACE = "Posizione", SEC_KEYS = "Comandi", THEME_HINT = "Clicca su un tema per applicarlo." },
    ptBR = { SEC_THEME = "Tema", SEC_TEXT = "Texto", SEC_PLACE = "Posição", SEC_KEYS = "Controles", THEME_HINT = "Clique em um tema para aplicá-lo." },
    ruRU = { SEC_THEME = "Тема", SEC_TEXT = "Текст", SEC_PLACE = "Расположение", SEC_KEYS = "Управление", THEME_HINT = "Нажмите на тему, чтобы применить её." },
    koKR = { SEC_THEME = "테마", SEC_TEXT = "글자", SEC_PLACE = "위치", SEC_KEYS = "조작", THEME_HINT = "테마를 클릭하면 적용됩니다." },
    zhCN = { SEC_THEME = "主题", SEC_TEXT = "文字", SEC_PLACE = "位置", SEC_KEYS = "操作", THEME_HINT = "点击主题即可应用。" },
    zhTW = { SEC_THEME = "主題", SEC_TEXT = "文字", SEC_PLACE = "位置", SEC_KEYS = "操作", THEME_HINT = "點擊主題即可套用。" },
}
OPTS.esMX = OPTS.esES
for loc, list in pairs(OPTS) do
    local dest = (loc == "enUS") and enUS or T[loc]
    if dest then for k, v in pairs(list) do dest[k] = v end end
end

local NEW_THEMES = {
    enUS = { "Whisper", "Smoked Glass" }, frFR = { "Murmure", "Verre fumé" },
    deDE = { "Flüstern", "Rauchglas" }, esES = { "Susurro", "Cristal ahumado" }, esMX = { "Susurro", "Cristal ahumado" },
    itIT = { "Sussurro", "Vetro fumé" }, ptBR = { "Sussurro", "Vidro fumê" }, ruRU = { "Шёпот", "Дымчатое стекло" },
    koKR = { "귓속말", "연기 유리" }, zhCN = { "密语", "烟熏玻璃" }, zhTW = { "密語", "煙燻玻璃" },
}
for loc, list in pairs(NEW_THEMES) do
    local dest = (loc == "enUS") and enUS or T[loc]
    if dest then dest.THEME_WHISPER, dest.THEME_GLASS = list[1], list[2] end
end

-- Noms des couleurs de Murmure : Emeraude, Rubis, Saphir, Ambre.
local GEM_THEMES = {
    enUS = { "Emerald", "Ruby", "Sapphire", "Amber" }, frFR = { "Émeraude", "Rubis", "Saphir", "Ambre" },
    deDE = { "Smaragd", "Rubin", "Saphir", "Bernstein" }, esES = { "Esmeralda", "Rubí", "Zafiro", "Ámbar" },
    esMX = { "Esmeralda", "Rubí", "Zafiro", "Ámbar" }, itIT = { "Smeraldo", "Rubino", "Zaffiro", "Ambra" },
    ptBR = { "Esmeralda", "Rubi", "Safira", "Âmbar" }, ruRU = { "Изумруд", "Рубин", "Сапфир", "Янтарь" },
    koKR = { "에메랄드", "루비", "사파이어", "호박" }, zhCN = { "翡翠", "红宝石", "蓝宝石", "琥珀" },
    zhTW = { "翡翠", "紅寶石", "藍寶石", "琥珀" },
}
for loc, list in pairs(GEM_THEMES) do
    local dest = (loc == "enUS") and enUS or T[loc]
    if dest then
        dest.THEME_EMERALD, dest.THEME_RUBY, dest.THEME_SAPPHIRE, dest.THEME_AMBER = list[1], list[2], list[3], list[4]
    end
end

-- Habillage du lecteur Spoken : choix a part (ou le theme actuel).
local SPOKEN_SKIN = {
    enUS = { "Spoken player look", "Current theme" },
    frFR = { "Habillage du lecteur Spoken", "Thème actuel" },
    deDE = { "Aussehen des Spoken-Players", "Aktuelles Thema" },
    esES = { "Aspecto del reproductor de Spoken", "Tema actual" },
    esMX = { "Aspecto del reproductor de Spoken", "Tema actual" },
    itIT = { "Aspetto del lettore di Spoken", "Tema attuale" },
    ptBR = { "Visual do reprodutor do Spoken", "Tema atual" },
    ruRU = { "Оформление плеера Spoken", "Текущая тема" },
    koKR = { "Spoken 플레이어 모양", "현재 테마" },
    zhCN = { "Spoken 播放器外观", "当前主题" },
    zhTW = { "Spoken 播放器外觀", "目前主題" },
}
for loc, list in pairs(SPOKEN_SKIN) do
    local dest = (loc == "enUS") and enUS or T[loc]
    if dest then dest.SPOKEN_SKIN, dest.SPOKEN_SKIN_FOLLOW = list[1], list[2] end
end

-- Bouton de bascule bulle / lecteur Spoken, dans le coin de la roue.
local SPOKEN_BUTTON = {
    enUS = "Show a button on the wheel to switch between the bubble and Spoken's player",
    frFR = "Afficher un bouton sur la roue pour basculer entre la bulle et le lecteur Spoken",
    deDE = "Eine Schaltfläche am Rad anzeigen, um zwischen Sprechblase und Spoken-Player zu wechseln",
    esES = "Mostrar un botón en la rueda para alternar entre el bocadillo y el reproductor de Spoken",
    esMX = "Mostrar un botón en la rueda para alternar entre el globo y el reproductor de Spoken",
    itIT = "Mostra un pulsante sulla ruota per passare dal fumetto al lettore di Spoken",
    ptBR = "Mostrar um botão na roda para alternar entre o balão e o reprodutor do Spoken",
    ruRU = "Показывать на колесе кнопку переключения между облачком и плеером Spoken",
    koKR = "휠에 말풍선과 Spoken 플레이어를 전환하는 버튼 표시",
    zhCN = "在轮盘上显示在气泡和 Spoken 播放器之间切换的按钮",
    zhTW = "在輪盤上顯示在氣泡和 Spoken 播放器之間切換的按鈕",
}
for loc, text in pairs(SPOKEN_BUTTON) do
    local dest = (loc == "enUS") and enUS or T[loc]
    if dest then dest.SPOKEN_BUTTON = text end
end

-- Lignes "Habillage" de la section Spoken.
local SKIN_ROWS = {
    enUS = { "NPC voices", "Zone narration", "Books" }, frFR = { "Voix des PNJ", "Narration des zones", "Livres" },
    deDE = { "NSC-Stimmen", "Gebietserzählung", "Bücher" }, esES = { "Voces de PNJ", "Narración de zonas", "Libros" },
    esMX = { "Voces de PNJ", "Narración de zonas", "Libros" }, itIT = { "Voci dei PNG", "Narrazione delle zone", "Libri" },
    ptBR = { "Vozes dos NPCs", "Narração das zonas", "Livros" }, ruRU = { "Голоса NPC", "Рассказ о зонах", "Книги" },
    koKR = { "NPC 음성", "지역 내레이션", "책" }, zhCN = { "NPC 语音", "区域旁白", "书籍" }, zhTW = { "NPC 語音", "區域旁白", "書籍" },
}
for loc, list in pairs(SKIN_ROWS) do
    local dest = (loc == "enUS") and enUS or T[loc]
    if dest then dest.SKIN_ROW_VOICE, dest.SKIN_ROW_PLACE, dest.SKIN_ROW_BOOK = list[1], list[2], list[3] end
end

-- Habillage "papier des livres de Storytale" dans les listes de themes (Spoken).
local SKIN_PAPER = {
    enUS = "Book page", frFR = "Page de livre", deDE = "Buchseite", esES = "Página de libro", esMX = "Página de libro",
    itIT = "Pagina di libro", ptBR = "Página de livro", ruRU = "Книжная страница", koKR = "책 페이지",
    zhCN = "书页", zhTW = "書頁",
}
for loc, text in pairs(SKIN_PAPER) do
    local dest = (loc == "enUS") and enUS or T[loc]
    if dest then dest.SKIN_PAPER = text end
end

-- Ou s'affiche la replique du PNJ (meme reglage que le bouton de la roue).
local TEXT_IN = {
    enUS = { "Show the NPC's line in:", "Storytale", "Spoken's player" },
    frFR = { "Afficher la réplique du PNJ dans :", "Storytale", "Le lecteur Spoken" },
    deDE = { "Text des NSCs anzeigen in:", "Storytale", "Spoken-Player" },
    esES = { "Mostrar la frase del PNJ en:", "Storytale", "Reproductor de Spoken" },
    esMX = { "Mostrar la frase del PNJ en:", "Storytale", "Reproductor de Spoken" },
    itIT = { "Mostra la battuta del PNG in:", "Storytale", "Lettore di Spoken" },
    ptBR = { "Mostrar a fala do NPC em:", "Storytale", "Reprodutor do Spoken" },
    ruRU = { "Показывать реплику NPC в:", "Storytale", "Плеер Spoken" },
    koKR = { "NPC 대사 표시 위치:", "Storytale", "Spoken 플레이어" },
    zhCN = { "NPC 台词显示在：", "Storytale", "Spoken 播放器" },
    zhTW = { "NPC 台詞顯示在：", "Storytale", "Spoken 播放器" },
}
for loc, list in pairs(TEXT_IN) do
    local dest = (loc == "enUS") and enUS or T[loc]
    if dest then dest.TEXT_IN, dest.TEXT_IN_STORYTALE, dest.TEXT_IN_SPOKEN = list[1], list[2], list[3] end
end

-- Ligne "Plaques" de l'habillage Spoken.
local PLATE_ROW = {
    enUS = { "Plaques", "Same as the plaque" }, frFR = { "Plaques", "Comme la plaque" },
    deDE = { "Tafeln", "Wie die Tafel" }, esES = { "Placas", "Como la placa" }, esMX = { "Placas", "Como la placa" },
    itIT = { "Targhe", "Come la targa" }, ptBR = { "Placas", "Como a placa" }, ruRU = { "Таблички", "Как у таблички" },
    koKR = { "명판", "명판과 동일" }, zhCN = { "铭牌", "与铭牌相同" }, zhTW = { "銘牌", "與銘牌相同" },
}
for loc, list in pairs(PLATE_ROW) do
    local dest = (loc == "enUS") and enUS or T[loc]
    if dest then dest.SKIN_ROW_PLATE, dest.PLATE_FOLLOW = list[1], list[2] end
end

-- Narration de zone : suivre l'habillage des voix.
local PLACE_FOLLOW = {
    enUS = "Same as voices", frFR = "Comme les voix", deDE = "Wie die Stimmen", esES = "Como las voces",
    esMX = "Como las voces", itIT = "Come le voci", ptBR = "Como as vozes", ruRU = "Как у голосов",
    koKR = "음성과 동일", zhCN = "与语音相同", zhTW = "與語音相同",
}
for loc, text in pairs(PLACE_FOLLOW) do
    local dest = (loc == "enUS") and enUS or T[loc]
    if dest then dest.PLACE_FOLLOW = text end
end

-- Noms des themes Halo d'ombre, Encre et or, Cinematique.
local EXP_THEMES = {
    enUS = { "Shadow Halo", "Ink & Gold", "Cinematic", "experimental" },
    frFR = { "Halo d'ombre", "Encre et or", "Cinématique", "expérimental" },
    deDE = { "Schattenhalo", "Tinte & Gold", "Filmisch", "experimentell" },
    esES = { "Halo de sombra", "Tinta y oro", "Cinemático", "experimental" },
    esMX = { "Halo de sombra", "Tinta y oro", "Cinemático", "experimental" },
    itIT = { "Alone d'ombra", "Inchiostro e oro", "Cinematico", "sperimentale" },
    ptBR = { "Halo de sombra", "Tinta e ouro", "Cinemático", "experimental" },
    ruRU = { "Ореол тени", "Чернила и золото", "Кинематограф", "эксперимент" },
    koKR = { "그림자 후광", "먹과 금", "시네마틱", "실험적" },
    zhCN = { "暗影光晕", "墨与金", "电影", "实验性" },
    zhTW = { "暗影光暈", "墨與金", "電影", "實驗性" },
}
for loc, list in pairs(EXP_THEMES) do
    local dest = (loc == "enUS") and enUS or T[loc]
    if dest then
        dest.THEME_HALO, dest.THEME_INK, dest.THEME_CINEMA = list[1], list[2], list[3]
    end
end

local BUBBLES_OPT = {
    enUS = "Show themes as bubbles (uncheck for frames)", frFR = "Afficher les thèmes en bulle (décocher pour des cadres)",
    deDE = "Themen als Sprechblasen anzeigen (abwählen für Rahmen)", esES = "Mostrar los temas como bocadillos (desmarcar para marcos)",
    esMX = "Mostrar los temas como globos (desmarcar para marcos)", itIT = "Mostra i temi come fumetti (deseleziona per i riquadri)",
    ptBR = "Mostrar os temas como balões (desmarque para molduras)", ruRU = "Показывать темы облачком (снимите для рамки)",
    koKR = "테마를 말풍선으로 표시 (해제하면 테두리)", zhCN = "以气泡显示主题（取消勾选则为边框）", zhTW = "以對話泡泡顯示主題（取消勾選則為邊框）",
}
for loc, v in pairs(BUBBLES_OPT) do
    local dest = (loc == "enUS") and enUS or T[loc]
    if dest then dest.THEME_BUBBLES = v end
end

local BOOK_LOOK = {
    enUS = { "Book look:", "Automatic", "Note", "Open book", "Theme frame", "Close", "Mute voice", "Read aloud", "waiting for the conversation", "voice muted", "Reading queue", "Nothing waiting.", "Remove from the queue", "NPCs and books waiting to be read. Click one to hear it now; the others keep their place." },
    frFR = { "Aspect des livres :", "Automatique", "Note", "Livre ouvert", "Cadre du thème", "Fermer", "Couper la voix", "Lire à voix haute", "en attente de la conversation", "voix coupée", "File de lecture", "Rien en attente.", "Retirer de la file", "PNJ et livres en attente de lecture. Clique sur l'un d'eux pour l'écouter tout de suite ; les autres gardent leur place." },
}
for loc, l in pairs(BOOK_LOOK) do
    local dest = (loc == "enUS") and enUS or T[loc]
    if dest then
        dest.BOOK_LOOK, dest.BOOK_LOOK_AUTO, dest.BOOK_LOOK_NOTE, dest.BOOK_LOOK_BOOK = l[1], l[2], l[3], l[4]
        dest.BOOK_LOOK_FRAME, dest.BOOK_CLOSE, dest.BOOK_MUTE, dest.BOOK_UNMUTE = l[5], l[6], l[7], l[8]
        dest.SPOKEN_WAIT, dest.SPOKEN_MUTED = l[9], l[10]
        dest.SPOKEN_QUEUE, dest.SPOKEN_QUEUE_EMPTY, dest.SPOKEN_QUEUE_CLOSE, dest.SPOKEN_QUEUE_TIP = l[11], l[12], l[13], l[14]
    end
end

-- Options reorganisees (sections Apparence / Texte / Livres / Position / Commandes / Spoken).
local OPTS2 = {
    enUS = { SEC_THEME = "Appearance", SEC_BOOKS = "Books, letters and plaques", SEC_SPOKEN = "Spoken", BOOKS_HDR = "Books and letters",
        BOOK_LOOK = "Style:", BOOK_LOOK_NOTE = "Single page", BOOK_ADDON = "Storytale",
        BOOK_ADDON_TIP = "Shown by Storytale with a parchment theme (Gilded Vellum if a bubble theme is chosen).",
        PLATE_ADDON_TIP = "Shown by Storytale on a plaque of the matching material.",
        THEME_BUBBLES = "Show the theme as a bubble above the NPC (uncheck for a fixed frame)",
        WHEEL_THEME = "Also apply the theme to the choice wheel",
        SPOKEN_THEME = "Also apply the theme to Spoken's player",
        OPACITY_LBL = "Background opacity",
        FONT_SIZE = "Text size (bubble, frame, books)", CHOICE_SIZE = "Choice size",
        BOOK_STYLE = "Displayed by:", BOOK_READ = "I already know this tale.", BOOK_UNFINISHED = "I never finished this one...", BOOK_NEW = "I have never read this...", BOOK_READING = "I am reading this tale...",
        MENU_VOICE_TURN = "Voice follows my pages", BOOK_VOICE_TURN = "The voice follows the pages I turn (books read by Spoken)", BOOK_STOP_CLOSE = "Stop the voice when I close a book (Spoken)", MENU_STOP_CLOSE = "Stop voice on close", MENU_MARK = "Bookmark this page", ERR_NOTICE = "an error occurred. Type /storytale errors for details.", ERR_LOOP = "%s keeps failing and was stopped until /reload.", ERR_NONE = "no error this session.", ERR_CLEARED = "errors cleared.", MENU_VOICE = "Read aloud", MENU_TURN_FX = "Page animation", RIBBON_TIP = "Reading options", BOOK_TURN_FX = "Page-turn animation and sound for the open book", HIGHLIGHT_BTN = "Highlight", HIGHLIGHT_BTN_OFF = "Highlight: off", HIGHLIGHT_ON = "Highlight the words read", HIGHLIGHT_OFF = "Hide the highlight", AUTOSCROLL_STOP = "Stop following the voice", AUTOSCROLL_START = "Follow the voice", BOOK_AUTOSCROLL = "Books read aloud by Spoken follow the voice (scrolling, page turns)", SPOKEN_SMART = "Smart reading queue", SPOKEN_SMART_TIP = "Storytale decides who speaks first: greetings give way, quests are never cut, books wait for conversations. Uncheck to let Spoken manage its queue on its own, untouched.", READ_MARKS = "Show whether a book or plaque was already read (tooltip, Spoken queue)", PLATE_LOOK = "Plaque material:", PLACE_SKIN = "Zone narration window (places you enter):", PLACE_THEME = "Current theme", PLACE_PAPER = "Single page", QUEST_AUTO_W = "Quest preview width adapts to its text (uncheck to set it with its grip)", BOOK_TIP_CURSOR = "Show the tooltip of books and plaques at the mouse (instead of the screen corner)", PLATE_STONE = "Stone", PLATE_MARBLE = "Marble",
        PLATE_BRONZE = "Bronze", PLATE_SILVER = "Silver",
        PLATE_AUTO_TIP = "Uses the material of the plaque in the game. Pick another one to use it for every plaque.",
        SPOKEN_CHOICE = "Show a \"Spoken\" choice in the wheel",
        KEY_TOGGLE = "Key to switch between the bubble and Spoken's player:",
        SPOKEN_NEEDED = "Requires the Spoken addon.",
        SPOKEN_KEY_HINT = "Turn on the \"Spoken\" choice above to use this key.",
        RESET_ALL = "Reset all options",
        PLATE_STYLE = "Engraved plaques (stone, marble, bronze, silver)", PLATE_ADDON = "Storytale",
        WHEEL_SIDE = "Choice wheel side:", SIDE_RIGHT = "Right of the NPC", SIDE_LEFT = "Left of the NPC",
        RESET_ALL_CONFIRM = "Reset all Storytale options to their defaults?\nThe interface will reload." },
    frFR = { SEC_THEME = "Apparence", SEC_BOOKS = "Livres, lettres et plaques", SEC_SPOKEN = "Spoken", BOOKS_HDR = "Livres et lettres",
        BOOK_LOOK = "Style :", BOOK_LOOK_NOTE = "Page seule", BOOK_ADDON = "Storytale",
        BOOK_ADDON_TIP = "Affichés par Storytale avec un thème parchemin (Vélin doré si un thème bulle est choisi).",
        PLATE_ADDON_TIP = "Affichées par Storytale sur une plaque de la même matière.",
        THEME_BUBBLES = "Afficher le thème en bulle au-dessus du PNJ (décocher : cadre fixe)",
        WHEEL_THEME = "Appliquer aussi le thème à la roue des choix",
        SPOKEN_THEME = "Appliquer aussi le thème au lecteur de Spoken",
        OPACITY_LBL = "Opacité du fond",
        FONT_SIZE = "Taille du texte (bulle, cadre, livres)", CHOICE_SIZE = "Taille des choix",
        BOOK_STYLE = "Affichés par :", BOOK_READ = "Je connais déjà ce récit.", BOOK_UNFINISHED = "Je ne l'ai jamais terminé…", BOOK_NEW = "Je n'ai jamais lu ceci…", BOOK_READING = "Je suis en train de lire ce récit…",
        MENU_VOICE_TURN = "La voix suit mes pages", BOOK_VOICE_TURN = "La voix suit les pages que je tourne (livres lus par Spoken)", BOOK_STOP_CLOSE = "Couper la voix quand je ferme un livre (Spoken)", MENU_STOP_CLOSE = "Couper la voix à la fermeture", MENU_MARK = "Marquer cette page", ERR_NOTICE = "une erreur s'est produite. Tapez /storytale errors pour les détails.", ERR_LOOP = "%s échoue en boucle et a été coupé jusqu'au /reload.", ERR_NONE = "aucune erreur pendant cette session.", ERR_CLEARED = "erreurs effacées.", MENU_VOICE = "Lecture à voix haute", MENU_TURN_FX = "Animation des pages", RIBBON_TIP = "Options de lecture", BOOK_TURN_FX = "Animation et son des pages tournées (livre ouvert)", HIGHLIGHT_BTN = "Surbrillance", HIGHLIGHT_BTN_OFF = "Surbrillance : non", HIGHLIGHT_ON = "Surligner les mots lus", HIGHLIGHT_OFF = "Retirer la surbrillance", AUTOSCROLL_STOP = "Ne plus suivre la voix", AUTOSCROLL_START = "Suivre la voix", BOOK_AUTOSCROLL = "Les livres lus par Spoken suivent la voix (défilement, pages tournées)", SPOKEN_SMART = "File de lecture intelligente", SPOKEN_SMART_TIP = "Storytale décide qui parle en premier : les salutations cèdent la place, les quêtes ne sont jamais coupées, les livres attendent la fin des conversations. Décochez pour laisser Spoken gérer seul sa file, sans aucune modification.", READ_MARKS = "Indiquer si un livre ou une plaque a déjà été lu (infobulle, file Spoken)", PLATE_LOOK = "Matière de la plaque :", PLACE_SKIN = "Fenêtre de narration des zones (lieux où vous entrez) :", PLACE_THEME = "Thème actuel", PLACE_PAPER = "Page seule", QUEST_AUTO_W = "Largeur de l'aperçu de quête adaptée au texte (décocher pour la régler avec sa poignée)", BOOK_TIP_CURSOR = "Afficher l'infobulle des livres et plaques à la souris (au lieu du coin de l'écran)", PLATE_STONE = "Pierre", PLATE_MARBLE = "Marbre",
        PLATE_BRONZE = "Bronze", PLATE_SILVER = "Argent",
        PLATE_AUTO_TIP = "Utilise la matière de la plaque dans le jeu. Choisis-en une autre pour l'utiliser sur toutes les plaques.",
        SPOKEN_CHOICE = "Afficher un choix « Spoken » dans la roue",
        KEY_TOGGLE = "Touche pour basculer entre la bulle et le lecteur de Spoken :",
        SPOKEN_NEEDED = "Nécessite l'addon Spoken.",
        SPOKEN_KEY_HINT = "Active le choix « Spoken » ci-dessus pour utiliser cette touche.",
        RESET_ALL = "Réinitialiser toutes les options",
        PLATE_STYLE = "Plaques gravées (pierre, marbre, bronze, argent)", PLATE_ADDON = "Storytale",
        WHEEL_SIDE = "Côté de la roue des choix :", SIDE_RIGHT = "À droite du PNJ", SIDE_LEFT = "À gauche du PNJ",
        RESET_ALL_CONFIRM = "Remettre toutes les options de Storytale par défaut ?\nL'interface va se recharger." },
}
for loc, list in pairs(OPTS2) do
    local dest = (loc == "enUS") and enUS or T[loc]
    if dest then for k, v in pairs(list) do dest[k] = v end end
end

-- Traductions des options recentes (autres langues que l'anglais et le francais).
local OPTS3 = {
    deDE = { MENU_VOICE_TURN = "Stimme folgt meinen Seiten", BOOK_VOICE_TURN = "Die Stimme folgt den Seiten, die ich umblättere (von Spoken gelesene Bücher)", BOOK_STOP_CLOSE = "Stimme beim Schließen eines Buches stoppen (Spoken)", MENU_STOP_CLOSE = "Stimme beim Schließen stoppen", MENU_MARK = "Seite markieren", ERR_NOTICE = "ein Fehler ist aufgetreten. Gib /storytale errors für Details ein.", ERR_LOOP = "%s schlägt ständig fehl und wurde bis zum /reload gestoppt.", ERR_NONE = "kein Fehler in dieser Sitzung.", ERR_CLEARED = "Fehler gelöscht.", MENU_VOICE = "Vorlesen", MENU_TURN_FX = "Seitenanimation", RIBBON_TIP = "Leseoptionen", BOOK_TURN_FX = "Animation und Geräusch beim Umblättern (offenes Buch)", HIGHLIGHT_BTN = "Hervorhebung", HIGHLIGHT_BTN_OFF = "Hervorhebung: aus", HIGHLIGHT_ON = "Gelesene Wörter hervorheben", HIGHLIGHT_OFF = "Hervorhebung ausblenden", AUTOSCROLL_STOP = "Stimme nicht mehr folgen", AUTOSCROLL_START = "Der Stimme folgen", BOOK_AUTOSCROLL = "Von Spoken vorgelesene Bücher folgen der Stimme (Scrollen, Umblättern)", SPOKEN_SMART = "Intelligente Lesewarteschlange", SPOKEN_SMART_TIP = "Storytale entscheidet, wer zuerst spricht: Begrüßungen weichen, Quests werden nie unterbrochen, Bücher warten auf das Ende von Gesprächen. Abwählen, damit Spoken seine Warteschlange unverändert selbst verwaltet.", SEC_BOOKS = "Bücher, Briefe und Tafeln", BOOKS_HDR = "Bücher und Briefe", BOOK_STYLE = "Angezeigt von:", BOOK_DUI = "DialogueUI", BOOK_BLIZZ = "Spielfenster", BOOK_ADDON_TIP = "Von Storytale mit einem Pergament-Thema angezeigt (Goldenes Velin, wenn ein Sprechblasen-Thema gewählt ist).", BOOK_LOOK = "Stil:", BOOK_LOOK_AUTO = "Automatisch", BOOK_LOOK_NOTE = "Einzelne Seite", BOOK_LOOK_BOOK = "Offenes Buch", BOOK_LOOK_FRAME = "Themenrahmen", BOOK_CLOSE = "Schließen", BOOK_MUTE = "Stimme stumm", BOOK_UNMUTE = "Vorlesen", BOOK_READING = "Ich lese diese Geschichte gerade…", BOOK_NEW = "Das habe ich noch nie gelesen…", BOOK_UNFINISHED = "Das habe ich nie zu Ende gelesen…", BOOK_READ = "Diese Geschichte kenne ich schon.", READ_MARKS = "Anzeigen, ob ein Buch oder eine Tafel schon gelesen wurde (Tooltip, Spoken-Warteschlange)", BOOK_TIP_CURSOR = "Tooltip von Büchern und Tafeln an der Maus anzeigen (statt in der Bildschirmecke)", PLATE_STYLE = "Gravierte Tafeln (Stein, Marmor, Bronze, Silber)", PLATE_ADDON_TIP = "Von Storytale auf einer Tafel aus passendem Material angezeigt.", PLATE_LOOK = "Material der Tafel:", PLATE_STONE = "Stein", PLATE_MARBLE = "Marmor", PLATE_BRONZE = "Bronze", PLATE_SILVER = "Silber", PLATE_AUTO_TIP = "Verwendet das Material der Tafel im Spiel. Wähle ein anderes, um es für alle Tafeln zu nutzen.", QUEST_AUTO_W = "Breite der Questvorschau passt sich dem Text an (abwählen, um sie mit dem Griff einzustellen)", PLACE_SKIN = "Fenster der Gebietserzählung (betretene Orte):", PLACE_THEME = "Aktuelles Thema", PLACE_PAPER = "Einzelne Seite", CHOICE_SIZE = "Größe der Auswahl", WHEEL_SIDE = "Seite des Auswahlrads:", SIDE_RIGHT = "Rechts vom NPC", SIDE_LEFT = "Links vom NPC", RESET_ALL = "Alle Optionen zurücksetzen", RESET_ALL_CONFIRM = "Alle Optionen von Storytale auf die Standardwerte zurücksetzen?\nDie Oberfläche wird neu geladen.", SPOKEN_CHOICE = "Eine Auswahl „Spoken“ im Rad anzeigen", SPOKEN_KEY_HINT = "Aktiviere oben die Auswahl „Spoken“, um diese Taste zu verwenden.", SPOKEN_NEEDED = "Benötigt das Addon Spoken.", SPOKEN_MUTED = "Stimme stumm", SPOKEN_WAIT = "wartet auf das Gespräch", SPOKEN_QUEUE = "Lesewarteschlange", SPOKEN_QUEUE_CLOSE = "Aus der Warteschlange entfernen", SPOKEN_QUEUE_EMPTY = "Nichts in der Warteschlange.", SPOKEN_QUEUE_TIP = "NPCs und Bücher, die vorgelesen werden. Klicke auf einen, um ihn sofort zu hören; die anderen behalten ihren Platz.", THEME_FOLIO = "Folio", THEME_FOLIO_DARK = "Nacht-Folio", DM_FACTION = "Dunkelmond-Jahrmarkt", DM_TICKET = "Preisticket des Dunkelmond-Jahrmarkts" },
    esES = { MENU_VOICE_TURN = "La voz sigue mis páginas", BOOK_VOICE_TURN = "La voz sigue las páginas que paso (libros leídos por Spoken)", BOOK_STOP_CLOSE = "Detener la voz al cerrar un libro (Spoken)", MENU_STOP_CLOSE = "Detener la voz al cerrar", MENU_MARK = "Marcar esta página", ERR_NOTICE = "se produjo un error. Escribe /storytale errors para ver los detalles.", ERR_LOOP = "%s falla una y otra vez y se detuvo hasta el /reload.", ERR_NONE = "ningún error en esta sesión.", ERR_CLEARED = "errores borrados.", MENU_VOICE = "Leer en voz alta", MENU_TURN_FX = "Animación de páginas", RIBBON_TIP = "Opciones de lectura", BOOK_TURN_FX = "Animación y sonido al pasar página (libro abierto)", HIGHLIGHT_BTN = "Resaltado", HIGHLIGHT_BTN_OFF = "Resaltado: no", HIGHLIGHT_ON = "Resaltar las palabras leídas", HIGHLIGHT_OFF = "Quitar el resaltado", AUTOSCROLL_STOP = "Dejar de seguir la voz", AUTOSCROLL_START = "Seguir la voz", BOOK_AUTOSCROLL = "Los libros leídos por Spoken siguen la voz (desplazamiento, cambio de página)", SPOKEN_SMART = "Cola de lectura inteligente", SPOKEN_SMART_TIP = "Storytale decide quién habla primero: los saludos ceden el paso, las misiones nunca se cortan y los libros esperan a que terminen las conversaciones. Desmarca para que Spoken gestione su cola por sí solo, sin cambios.", SEC_BOOKS = "Libros, cartas y placas", BOOKS_HDR = "Libros y cartas", BOOK_STYLE = "Mostrados por:", BOOK_DUI = "DialogueUI", BOOK_BLIZZ = "Ventana del juego", BOOK_ADDON_TIP = "Mostrados por Storytale con un tema de pergamino (Vitela dorada si se elige un tema de bocadillo).", BOOK_LOOK = "Estilo:", BOOK_LOOK_AUTO = "Automático", BOOK_LOOK_NOTE = "Página única", BOOK_LOOK_BOOK = "Libro abierto", BOOK_LOOK_FRAME = "Marco del tema", BOOK_CLOSE = "Cerrar", BOOK_MUTE = "Silenciar voz", BOOK_UNMUTE = "Leer en voz alta", BOOK_READING = "Estoy leyendo este relato…", BOOK_NEW = "Nunca he leído esto…", BOOK_UNFINISHED = "Nunca lo terminé…", BOOK_READ = "Ya conozco este relato.", READ_MARKS = "Indicar si un libro o una placa ya se ha leído (descripción emergente, cola de Spoken)", BOOK_TIP_CURSOR = "Mostrar la descripción de libros y placas junto al ratón (en lugar de la esquina de la pantalla)", PLATE_STYLE = "Placas grabadas (piedra, mármol, bronce, plata)", PLATE_ADDON_TIP = "Mostradas por Storytale en una placa del material correspondiente.", PLATE_LOOK = "Material de la placa:", PLATE_STONE = "Piedra", PLATE_MARBLE = "Mármol", PLATE_BRONZE = "Bronce", PLATE_SILVER = "Plata", PLATE_AUTO_TIP = "Usa el material de la placa del juego. Elige otro para usarlo en todas las placas.", QUEST_AUTO_W = "Ancho de la vista previa de misión adaptado al texto (desmarcar para ajustarlo con su asa)", PLACE_SKIN = "Ventana de narración de zonas (lugares en los que entras):", PLACE_THEME = "Tema actual", PLACE_PAPER = "Página única", CHOICE_SIZE = "Tamaño de las opciones", WHEEL_SIDE = "Lado de la rueda de opciones:", SIDE_RIGHT = "A la derecha del PNJ", SIDE_LEFT = "A la izquierda del PNJ", RESET_ALL = "Restablecer todas las opciones", RESET_ALL_CONFIRM = "¿Restablecer todas las opciones de Storytale a sus valores predeterminados?\nLa interfaz se recargará.", SPOKEN_CHOICE = "Mostrar una opción «Spoken» en la rueda", SPOKEN_KEY_HINT = "Activa la opción «Spoken» de arriba para usar esta tecla.", SPOKEN_NEEDED = "Requiere el addon Spoken.", SPOKEN_MUTED = "voz silenciada", SPOKEN_WAIT = "esperando la conversación", SPOKEN_QUEUE = "Cola de lectura", SPOKEN_QUEUE_CLOSE = "Quitar de la cola", SPOKEN_QUEUE_EMPTY = "Nada en espera.", SPOKEN_QUEUE_TIP = "PNJ y libros a la espera de ser leídos. Haz clic en uno para oírlo ya; los demás conservan su lugar.", THEME_FOLIO = "Folio", THEME_FOLIO_DARK = "Folio nocturno", DM_FACTION = "Feria de la Luna Negra", DM_TICKET = "Boleto de premio de la Feria de la Luna Negra" },
    itIT = { MENU_VOICE_TURN = "La voce segue le mie pagine", BOOK_VOICE_TURN = "La voce segue le pagine che sfoglio (libri letti da Spoken)", BOOK_STOP_CLOSE = "Fermare la voce quando chiudo un libro (Spoken)", MENU_STOP_CLOSE = "Fermare la voce alla chiusura", MENU_MARK = "Segna questa pagina", ERR_NOTICE = "si è verificato un errore. Digita /storytale errors per i dettagli.", ERR_LOOP = "%s continua a fallire ed è stato fermato fino al /reload.", ERR_NONE = "nessun errore in questa sessione.", ERR_CLEARED = "errori cancellati.", MENU_VOICE = "Lettura ad alta voce", MENU_TURN_FX = "Animazione delle pagine", RIBBON_TIP = "Opzioni di lettura", BOOK_TURN_FX = "Animazione e suono del cambio pagina (libro aperto)", HIGHLIGHT_BTN = "Evidenziazione", HIGHLIGHT_BTN_OFF = "Evidenziazione: no", HIGHLIGHT_ON = "Evidenzia le parole lette", HIGHLIGHT_OFF = "Togli l'evidenziazione", AUTOSCROLL_STOP = "Non seguire più la voce", AUTOSCROLL_START = "Segui la voce", BOOK_AUTOSCROLL = "I libri letti da Spoken seguono la voce (scorrimento, cambio pagina)", SPOKEN_SMART = "Coda di lettura intelligente", SPOKEN_SMART_TIP = "Storytale decide chi parla per primo: i saluti cedono il passo, le missioni non vengono mai interrotte, i libri aspettano la fine delle conversazioni. Deseleziona per lasciare che Spoken gestisca la sua coda da solo, senza modifiche.", SEC_BOOKS = "Libri, lettere e targhe", BOOKS_HDR = "Libri e lettere", BOOK_STYLE = "Mostrati da:", BOOK_DUI = "DialogueUI", BOOK_BLIZZ = "Finestra del gioco", BOOK_ADDON_TIP = "Mostrati da Storytale con un tema pergamena (Pergamena dorata se è scelto un tema a fumetto).", BOOK_LOOK = "Stile:", BOOK_LOOK_AUTO = "Automatico", BOOK_LOOK_NOTE = "Pagina singola", BOOK_LOOK_BOOK = "Libro aperto", BOOK_LOOK_FRAME = "Cornice del tema", BOOK_CLOSE = "Chiudi", BOOK_MUTE = "Silenzia voce", BOOK_UNMUTE = "Leggi ad alta voce", BOOK_READING = "Sto leggendo questo racconto…", BOOK_NEW = "Non l'ho mai letto…", BOOK_UNFINISHED = "Non l'ho mai finito…", BOOK_READ = "Conosco già questo racconto.", READ_MARKS = "Indicare se un libro o una targa è già stato letto (descrizione, coda di Spoken)", BOOK_TIP_CURSOR = "Mostrare la descrizione di libri e targhe vicino al mouse (invece che nell'angolo dello schermo)", PLATE_STYLE = "Targhe incise (pietra, marmo, bronzo, argento)", PLATE_ADDON_TIP = "Mostrate da Storytale su una targa del materiale corrispondente.", PLATE_LOOK = "Materiale della targa:", PLATE_STONE = "Pietra", PLATE_MARBLE = "Marmo", PLATE_BRONZE = "Bronzo", PLATE_SILVER = "Argento", PLATE_AUTO_TIP = "Usa il materiale della targa nel gioco. Scegline un altro per usarlo su tutte le targhe.", QUEST_AUTO_W = "Larghezza dell'anteprima missione adattata al testo (deseleziona per regolarla con la maniglia)", PLACE_SKIN = "Finestra di narrazione delle zone (luoghi in cui entri):", PLACE_THEME = "Tema attuale", PLACE_PAPER = "Pagina singola", CHOICE_SIZE = "Dimensione delle scelte", WHEEL_SIDE = "Lato della ruota delle scelte:", SIDE_RIGHT = "A destra del PNG", SIDE_LEFT = "A sinistra del PNG", RESET_ALL = "Ripristina tutte le opzioni", RESET_ALL_CONFIRM = "Ripristinare tutte le opzioni di Storytale ai valori predefiniti?\nL'interfaccia verrà ricaricata.", SPOKEN_CHOICE = "Mostrare una scelta «Spoken» nella ruota", SPOKEN_KEY_HINT = "Attiva la scelta «Spoken» qui sopra per usare questo tasto.", SPOKEN_NEEDED = "Richiede l'addon Spoken.", SPOKEN_MUTED = "voce silenziata", SPOKEN_WAIT = "in attesa della conversazione", SPOKEN_QUEUE = "Coda di lettura", SPOKEN_QUEUE_CLOSE = "Rimuovi dalla coda", SPOKEN_QUEUE_EMPTY = "Niente in attesa.", SPOKEN_QUEUE_TIP = "PNG e libri in attesa di essere letti. Cliccane uno per ascoltarlo subito; gli altri mantengono il loro posto.", THEME_FOLIO = "Folio", THEME_FOLIO_DARK = "Folio notturno", DM_FACTION = "Fiera di Lunacupa", DM_TICKET = "Biglietto premio della Fiera di Lunacupa" },
    ptBR = { MENU_VOICE_TURN = "A voz segue minhas páginas", BOOK_VOICE_TURN = "A voz segue as páginas que eu viro (livros lidos pelo Spoken)", BOOK_STOP_CLOSE = "Parar a voz ao fechar um livro (Spoken)", MENU_STOP_CLOSE = "Parar a voz ao fechar", MENU_MARK = "Marcar esta página", ERR_NOTICE = "ocorreu um erro. Digite /storytale errors para ver os detalhes.", ERR_LOOP = "%s continua falhando e foi parado até o /reload.", ERR_NONE = "nenhum erro nesta sessão.", ERR_CLEARED = "erros apagados.", MENU_VOICE = "Leitura em voz alta", MENU_TURN_FX = "Animação das páginas", RIBBON_TIP = "Opções de leitura", BOOK_TURN_FX = "Animação e som ao virar a página (livro aberto)", HIGHLIGHT_BTN = "Destaque", HIGHLIGHT_BTN_OFF = "Destaque: não", HIGHLIGHT_ON = "Destacar as palavras lidas", HIGHLIGHT_OFF = "Remover o destaque", AUTOSCROLL_STOP = "Parar de seguir a voz", AUTOSCROLL_START = "Seguir a voz", BOOK_AUTOSCROLL = "Os livros lidos pelo Spoken acompanham a voz (rolagem, virar páginas)", SPOKEN_SMART = "Fila de leitura inteligente", SPOKEN_SMART_TIP = "O Storytale decide quem fala primeiro: as saudações cedem a vez, as missões nunca são cortadas e os livros esperam o fim das conversas. Desmarque para deixar o Spoken gerenciar a fila sozinho, sem alterações.", SEC_BOOKS = "Livros, cartas e placas", BOOKS_HDR = "Livros e cartas", BOOK_STYLE = "Exibidos por:", BOOK_DUI = "DialogueUI", BOOK_BLIZZ = "Janela do jogo", BOOK_ADDON_TIP = "Exibidos pelo Storytale com um tema de pergaminho (Velino dourado se um tema de balão for escolhido).", BOOK_LOOK = "Estilo:", BOOK_LOOK_AUTO = "Automático", BOOK_LOOK_NOTE = "Página única", BOOK_LOOK_BOOK = "Livro aberto", BOOK_LOOK_FRAME = "Moldura do tema", BOOK_CLOSE = "Fechar", BOOK_MUTE = "Silenciar voz", BOOK_UNMUTE = "Ler em voz alta", BOOK_READING = "Estou lendo este relato…", BOOK_NEW = "Nunca li isto…", BOOK_UNFINISHED = "Nunca terminei este…", BOOK_READ = "Já conheço este relato.", READ_MARKS = "Indicar se um livro ou placa já foi lido (dica, fila do Spoken)", BOOK_TIP_CURSOR = "Mostrar a dica de livros e placas junto ao mouse (em vez do canto da tela)", PLATE_STYLE = "Placas gravadas (pedra, mármore, bronze, prata)", PLATE_ADDON_TIP = "Exibidas pelo Storytale numa placa do material correspondente.", PLATE_LOOK = "Material da placa:", PLATE_STONE = "Pedra", PLATE_MARBLE = "Mármore", PLATE_BRONZE = "Bronze", PLATE_SILVER = "Prata", PLATE_AUTO_TIP = "Usa o material da placa no jogo. Escolha outro para usá-lo em todas as placas.", QUEST_AUTO_W = "Largura da prévia da missão adaptada ao texto (desmarque para ajustá-la com a alça)", PLACE_SKIN = "Janela de narração das zonas (lugares em que você entra):", PLACE_THEME = "Tema atual", PLACE_PAPER = "Página única", CHOICE_SIZE = "Tamanho das escolhas", WHEEL_SIDE = "Lado da roda de escolhas:", SIDE_RIGHT = "À direita do NPC", SIDE_LEFT = "À esquerda do NPC", RESET_ALL = "Redefinir todas as opções", RESET_ALL_CONFIRM = "Redefinir todas as opções do Storytale para o padrão?\nA interface será recarregada.", SPOKEN_CHOICE = "Mostrar uma escolha «Spoken» na roda", SPOKEN_KEY_HINT = "Ative a escolha «Spoken» acima para usar esta tecla.", SPOKEN_NEEDED = "Requer o addon Spoken.", SPOKEN_MUTED = "voz silenciada", SPOKEN_WAIT = "aguardando a conversa", SPOKEN_QUEUE = "Fila de leitura", SPOKEN_QUEUE_CLOSE = "Remover da fila", SPOKEN_QUEUE_EMPTY = "Nada na espera.", SPOKEN_QUEUE_TIP = "NPCs e livros aguardando leitura. Clique em um para ouvi-lo agora; os outros mantêm o lugar.", THEME_FOLIO = "Fólio", THEME_FOLIO_DARK = "Fólio noturno", DM_FACTION = "Feira de Negraluna", DM_TICKET = "Bilhete de prêmio da Feira de Negraluna" },
    ruRU = { MENU_VOICE_TURN = "Голос следует за моими страницами", BOOK_VOICE_TURN = "Голос следует за страницами, которые я листаю (книги, читаемые Spoken)", BOOK_STOP_CLOSE = "Останавливать голос при закрытии книги (Spoken)", MENU_STOP_CLOSE = "Стоп голоса при закрытии", MENU_MARK = "Заложить эту страницу", ERR_NOTICE = "произошла ошибка. Введите /storytale errors, чтобы узнать подробности.", ERR_LOOP = "%s постоянно выдаёт ошибку и остановлен до /reload.", ERR_NONE = "в этом сеансе ошибок нет.", ERR_CLEARED = "ошибки очищены.", MENU_VOICE = "Чтение вслух", MENU_TURN_FX = "Анимация страниц", RIBBON_TIP = "Настройки чтения", BOOK_TURN_FX = "Анимация и звук перелистывания (открытая книга)", HIGHLIGHT_BTN = "Подсветка", HIGHLIGHT_BTN_OFF = "Подсветка: выкл.", HIGHLIGHT_ON = "Подсвечивать читаемые слова", HIGHLIGHT_OFF = "Убрать подсветку", AUTOSCROLL_STOP = "Не следовать за голосом", AUTOSCROLL_START = "Следовать за голосом", BOOK_AUTOSCROLL = "Книги, читаемые Spoken, следуют за голосом (прокрутка, перелистывание)", SPOKEN_SMART = "Умная очередь чтения", SPOKEN_SMART_TIP = "Storytale решает, кто говорит первым: приветствия уступают, задания никогда не обрываются, книги ждут окончания разговоров. Снимите, чтобы Spoken сам управлял своей очередью без изменений.", SEC_BOOKS = "Книги, письма и таблички", BOOKS_HDR = "Книги и письма", BOOK_STYLE = "Показывает:", BOOK_DUI = "DialogueUI", BOOK_BLIZZ = "Окно игры", BOOK_ADDON_TIP = "Показывает Storytale в стиле пергамента (Золочёный пергамент, если выбрана тема-облачко).", BOOK_LOOK = "Стиль:", BOOK_LOOK_AUTO = "Автоматически", BOOK_LOOK_NOTE = "Одна страница", BOOK_LOOK_BOOK = "Открытая книга", BOOK_LOOK_FRAME = "Рамка темы", BOOK_CLOSE = "Закрыть", BOOK_MUTE = "Без голоса", BOOK_UNMUTE = "Читать вслух", BOOK_READING = "Я читаю эту историю…", BOOK_NEW = "Я никогда это не читал…", BOOK_UNFINISHED = "Я так и не дочитал это…", BOOK_READ = "Эту историю я уже знаю.", READ_MARKS = "Показывать, прочитана ли книга или табличка (подсказка, очередь Spoken)", BOOK_TIP_CURSOR = "Показывать подсказку книг и табличек у курсора (а не в углу экрана)", PLATE_STYLE = "Гравированные таблички (камень, мрамор, бронза, серебро)", PLATE_ADDON_TIP = "Показывает Storytale на табличке из того же материала.", PLATE_LOOK = "Материал таблички:", PLATE_STONE = "Камень", PLATE_MARBLE = "Мрамор", PLATE_BRONZE = "Бронза", PLATE_SILVER = "Серебро", PLATE_AUTO_TIP = "Использует материал таблички из игры. Выберите другой, чтобы применить его ко всем табличкам.", QUEST_AUTO_W = "Ширина обзора задания подстраивается под текст (снимите, чтобы задать её ручкой)", PLACE_SKIN = "Окно рассказа о зонах (места, куда вы входите):", PLACE_THEME = "Текущая тема", PLACE_PAPER = "Одна страница", CHOICE_SIZE = "Размер вариантов", WHEEL_SIDE = "Сторона колеса выбора:", SIDE_RIGHT = "Справа от NPC", SIDE_LEFT = "Слева от NPC", RESET_ALL = "Сбросить все настройки", RESET_ALL_CONFIRM = "Сбросить все настройки Storytale по умолчанию?\nИнтерфейс будет перезагружен.", SPOKEN_CHOICE = "Показывать вариант «Spoken» в колесе", SPOKEN_KEY_HINT = "Включите вариант «Spoken» выше, чтобы использовать эту клавишу.", SPOKEN_NEEDED = "Требуется аддон Spoken.", SPOKEN_MUTED = "голос выключен", SPOKEN_WAIT = "ждёт окончания разговора", SPOKEN_QUEUE = "Очередь чтения", SPOKEN_QUEUE_CLOSE = "Убрать из очереди", SPOKEN_QUEUE_EMPTY = "Очередь пуста.", SPOKEN_QUEUE_TIP = "NPC и книги в очереди на чтение. Нажмите, чтобы услышать сейчас; остальные сохранят место.", THEME_FOLIO = "Фолиант", THEME_FOLIO_DARK = "Ночной фолиант", DM_FACTION = "Ярмарка Новолуния", DM_TICKET = "Призовой билет Ярмарки Новолуния" },
    koKR = { MENU_VOICE_TURN = "목소리가 내 페이지를 따라감", BOOK_VOICE_TURN = "내가 넘기는 페이지를 목소리가 따라갑니다 (Spoken이 읽는 책)", BOOK_STOP_CLOSE = "책을 닫으면 목소리 멈추기 (Spoken)", MENU_STOP_CLOSE = "닫으면 목소리 멈춤", MENU_MARK = "이 페이지 표시", ERR_NOTICE = "오류가 발생했습니다. 자세한 내용은 /storytale errors 를 입력하세요.", ERR_LOOP = "%s 이(가) 계속 실패하여 /reload 까지 중지되었습니다.", ERR_NONE = "이번 세션에 오류가 없습니다.", ERR_CLEARED = "오류를 지웠습니다.", MENU_VOICE = "소리 내어 읽기", MENU_TURN_FX = "페이지 애니메이션", RIBBON_TIP = "읽기 설정", BOOK_TURN_FX = "페이지 넘김 애니메이션과 소리 (펼친 책)", HIGHLIGHT_BTN = "강조", HIGHLIGHT_BTN_OFF = "강조: 끔", HIGHLIGHT_ON = "읽는 단어 강조", HIGHLIGHT_OFF = "강조 끄기", AUTOSCROLL_STOP = "목소리 따라가기 끄기", AUTOSCROLL_START = "목소리 따라가기", BOOK_AUTOSCROLL = "Spoken이 읽는 책이 목소리를 따라갑니다 (스크롤, 페이지 넘김)", SPOKEN_SMART = "스마트 읽기 대기열", SPOKEN_SMART_TIP = "Storytale이 누가 먼저 말할지 정합니다: 인사는 양보하고, 퀘스트는 절대 끊기지 않으며, 책은 대화가 끝날 때까지 기다립니다. 해제하면 Spoken이 대기열을 그대로 직접 관리합니다.", SEC_BOOKS = "책, 편지, 명판", BOOKS_HDR = "책과 편지", BOOK_STYLE = "표시 방식:", BOOK_DUI = "DialogueUI", BOOK_BLIZZ = "게임 창", BOOK_ADDON_TIP = "양피지 테마로 Storytale이 표시합니다 (말풍선 테마를 고르면 금박 양피지).", BOOK_LOOK = "스타일:", BOOK_LOOK_AUTO = "자동", BOOK_LOOK_NOTE = "한 페이지", BOOK_LOOK_BOOK = "펼친 책", BOOK_LOOK_FRAME = "테마 테두리", BOOK_CLOSE = "닫기", BOOK_MUTE = "음성 끄기", BOOK_UNMUTE = "소리 내어 읽기", BOOK_READING = "이 이야기를 읽는 중이다…", BOOK_NEW = "한 번도 읽어 본 적이 없다…", BOOK_UNFINISHED = "끝까지 읽지 못했다…", BOOK_READ = "이미 아는 이야기다.", READ_MARKS = "책이나 명판을 이미 읽었는지 표시 (툴팁, Spoken 대기열)", BOOK_TIP_CURSOR = "책과 명판 툴팁을 마우스 옆에 표시 (화면 모서리 대신)", PLATE_STYLE = "새겨진 명판 (돌, 대리석, 청동, 은)", PLATE_ADDON_TIP = "같은 재질의 명판으로 Storytale이 표시합니다.", PLATE_LOOK = "명판 재질:", PLATE_STONE = "돌", PLATE_MARBLE = "대리석", PLATE_BRONZE = "청동", PLATE_SILVER = "은", PLATE_AUTO_TIP = "게임 속 명판의 재질을 사용합니다. 다른 재질을 고르면 모든 명판에 적용됩니다.", QUEST_AUTO_W = "퀘스트 미리보기 너비를 글에 맞춤 (해제하면 손잡이로 조절)", PLACE_SKIN = "지역 내레이션 창 (들어가는 장소):", PLACE_THEME = "현재 테마", PLACE_PAPER = "한 페이지", CHOICE_SIZE = "선택지 크기", WHEEL_SIDE = "선택 휠 위치:", SIDE_RIGHT = "NPC 오른쪽", SIDE_LEFT = "NPC 왼쪽", RESET_ALL = "모든 설정 초기화", RESET_ALL_CONFIRM = "Storytale의 모든 설정을 기본값으로 되돌릴까요?\n인터페이스가 다시 불러와집니다.", SPOKEN_CHOICE = "휠에 「Spoken」 선택지 표시", SPOKEN_KEY_HINT = "이 키를 쓰려면 위의 「Spoken」 선택지를 켜세요.", SPOKEN_NEEDED = "Spoken 애드온이 필요합니다.", SPOKEN_MUTED = "음성 꺼짐", SPOKEN_WAIT = "대화가 끝나길 기다리는 중", SPOKEN_QUEUE = "읽기 대기열", SPOKEN_QUEUE_CLOSE = "대기열에서 제거", SPOKEN_QUEUE_EMPTY = "대기 중인 항목이 없습니다.", SPOKEN_QUEUE_TIP = "읽기를 기다리는 NPC와 책입니다. 하나를 클릭하면 바로 들을 수 있고, 나머지는 순서를 유지합니다.", THEME_FOLIO = "폴리오", THEME_FOLIO_DARK = "밤의 폴리오", DM_FACTION = "다크문 유랑단", DM_TICKET = "다크문 유랑단 상품 교환권" },
    zhCN = { MENU_VOICE_TURN = "声音跟随我翻的页", BOOK_VOICE_TURN = "声音跟随我翻到的页面（Spoken 朗读的书）", BOOK_STOP_CLOSE = "关闭书本时停止朗读（Spoken）", MENU_STOP_CLOSE = "关闭时停止朗读", MENU_MARK = "标记此页", ERR_NOTICE = "发生了错误。输入 /storytale errors 查看详情。", ERR_LOOP = "%s 持续出错，已停止直到 /reload。", ERR_NONE = "本次会话没有错误。", ERR_CLEARED = "错误已清除。", MENU_VOICE = "朗读", MENU_TURN_FX = "翻页动画", RIBBON_TIP = "阅读选项", BOOK_TURN_FX = "翻页动画与音效（打开的书）", HIGHLIGHT_BTN = "高亮", HIGHLIGHT_BTN_OFF = "高亮：关", HIGHLIGHT_ON = "高亮朗读的词语", HIGHLIGHT_OFF = "取消高亮", AUTOSCROLL_STOP = "不再跟随声音", AUTOSCROLL_START = "跟随声音", BOOK_AUTOSCROLL = "Spoken 朗读的书籍跟随声音（滚动、翻页）", SPOKEN_SMART = "智能朗读队列", SPOKEN_SMART_TIP = "由 Storytale 决定谁先说话：问候会让位，任务绝不会被打断，书籍会等对话结束。取消勾选则由 Spoken 自行管理队列，不做任何更改。", SEC_BOOKS = "书籍、信件与铭牌", BOOKS_HDR = "书籍与信件", BOOK_STYLE = "显示方式：", BOOK_DUI = "DialogueUI", BOOK_BLIZZ = "游戏窗口", BOOK_ADDON_TIP = "由 Storytale 以羊皮纸主题显示（选择气泡主题时为鎏金羊皮纸）。", BOOK_LOOK = "样式：", BOOK_LOOK_AUTO = "自动", BOOK_LOOK_NOTE = "单页", BOOK_LOOK_BOOK = "打开的书", BOOK_LOOK_FRAME = "主题边框", BOOK_CLOSE = "关闭", BOOK_MUTE = "静音", BOOK_UNMUTE = "朗读", BOOK_READING = "我正在读这个故事……", BOOK_NEW = "我从没读过这个……", BOOK_UNFINISHED = "我从没读完过……", BOOK_READ = "我已经知道这个故事了。", READ_MARKS = "显示书籍或铭牌是否已读（鼠标提示、Spoken 队列）", BOOK_TIP_CURSOR = "在鼠标旁显示书籍和铭牌的提示（而非屏幕角落）", PLATE_STYLE = "刻字铭牌（石、大理石、青铜、银）", PLATE_ADDON_TIP = "由 Storytale 以相同材质的铭牌显示。", PLATE_LOOK = "铭牌材质：", PLATE_STONE = "石", PLATE_MARBLE = "大理石", PLATE_BRONZE = "青铜", PLATE_SILVER = "银", PLATE_AUTO_TIP = "使用游戏中铭牌的材质。选择其他材质则所有铭牌都使用它。", QUEST_AUTO_W = "任务预览宽度随文字调整（取消勾选可用拖柄调整）", PLACE_SKIN = "区域旁白窗口（进入的地点）：", PLACE_THEME = "当前主题", PLACE_PAPER = "单页", CHOICE_SIZE = "选项大小", WHEEL_SIDE = "选项轮位置：", SIDE_RIGHT = "NPC 右侧", SIDE_LEFT = "NPC 左侧", RESET_ALL = "重置所有选项", RESET_ALL_CONFIRM = "将 Storytale 的所有选项恢复为默认值？\n界面将重新载入。", SPOKEN_CHOICE = "在选项轮中显示「Spoken」选项", SPOKEN_KEY_HINT = "请先启用上方的「Spoken」选项以使用此按键。", SPOKEN_NEEDED = "需要 Spoken 插件。", SPOKEN_MUTED = "已静音", SPOKEN_WAIT = "等待对话结束", SPOKEN_QUEUE = "朗读队列", SPOKEN_QUEUE_CLOSE = "从队列移除", SPOKEN_QUEUE_EMPTY = "没有等待中的内容。", SPOKEN_QUEUE_TIP = "等待朗读的 NPC 与书籍。点击其中一个立即收听，其余保持顺序。", THEME_FOLIO = "对开本", THEME_FOLIO_DARK = "夜色对开本", DM_FACTION = "暗月马戏团", DM_TICKET = "暗月马戏团奖券" },
    zhTW = { MENU_VOICE_TURN = "聲音跟隨我翻的頁", BOOK_VOICE_TURN = "聲音跟隨我翻到的頁面（Spoken 朗讀的書）", BOOK_STOP_CLOSE = "關閉書本時停止朗讀（Spoken）", MENU_STOP_CLOSE = "關閉時停止朗讀", MENU_MARK = "標記此頁", ERR_NOTICE = "發生了錯誤。輸入 /storytale errors 查看詳情。", ERR_LOOP = "%s 持續出錯，已停止直到 /reload。", ERR_NONE = "本次工作階段沒有錯誤。", ERR_CLEARED = "錯誤已清除。", MENU_VOICE = "朗讀", MENU_TURN_FX = "翻頁動畫", RIBBON_TIP = "閱讀選項", BOOK_TURN_FX = "翻頁動畫與音效（打開的書）", HIGHLIGHT_BTN = "醒目標示", HIGHLIGHT_BTN_OFF = "醒目標示：關", HIGHLIGHT_ON = "醒目標示朗讀的詞語", HIGHLIGHT_OFF = "取消醒目標示", AUTOSCROLL_STOP = "不再跟隨聲音", AUTOSCROLL_START = "跟隨聲音", BOOK_AUTOSCROLL = "Spoken 朗讀的書籍跟隨聲音（捲動、翻頁）", SPOKEN_SMART = "智慧朗讀佇列", SPOKEN_SMART_TIP = "由 Storytale 決定誰先說話：問候會讓位，任務絕不會被打斷，書籍會等對話結束。取消勾選則由 Spoken 自行管理佇列，不做任何更改。", SEC_BOOKS = "書籍、信件與銘牌", BOOKS_HDR = "書籍與信件", BOOK_STYLE = "顯示方式：", BOOK_DUI = "DialogueUI", BOOK_BLIZZ = "遊戲視窗", BOOK_ADDON_TIP = "由 Storytale 以羊皮紙主題顯示（選擇對話泡泡主題時為鎏金羊皮紙）。", BOOK_LOOK = "樣式：", BOOK_LOOK_AUTO = "自動", BOOK_LOOK_NOTE = "單頁", BOOK_LOOK_BOOK = "打開的書", BOOK_LOOK_FRAME = "主題邊框", BOOK_CLOSE = "關閉", BOOK_MUTE = "靜音", BOOK_UNMUTE = "朗讀", BOOK_READING = "我正在讀這個故事……", BOOK_NEW = "我從沒讀過這個……", BOOK_UNFINISHED = "我從沒讀完過……", BOOK_READ = "我已經知道這個故事了。", READ_MARKS = "顯示書籍或銘牌是否已讀（滑鼠提示、Spoken 佇列）", BOOK_TIP_CURSOR = "在滑鼠旁顯示書籍和銘牌的提示（而非螢幕角落）", PLATE_STYLE = "刻字銘牌（石、大理石、青銅、銀）", PLATE_ADDON_TIP = "由 Storytale 以相同材質的銘牌顯示。", PLATE_LOOK = "銘牌材質：", PLATE_STONE = "石", PLATE_MARBLE = "大理石", PLATE_BRONZE = "青銅", PLATE_SILVER = "銀", PLATE_AUTO_TIP = "使用遊戲中銘牌的材質。選擇其他材質則所有銘牌都使用它。", QUEST_AUTO_W = "任務預覽寬度隨文字調整（取消勾選可用拖柄調整）", PLACE_SKIN = "區域旁白視窗（進入的地點）：", PLACE_THEME = "目前主題", PLACE_PAPER = "單頁", CHOICE_SIZE = "選項大小", WHEEL_SIDE = "選項輪位置：", SIDE_RIGHT = "NPC 右側", SIDE_LEFT = "NPC 左側", RESET_ALL = "重設所有選項", RESET_ALL_CONFIRM = "將 Storytale 的所有選項恢復為預設值？\n介面將重新載入。", SPOKEN_CHOICE = "在選項輪中顯示「Spoken」選項", SPOKEN_KEY_HINT = "請先啟用上方的「Spoken」選項以使用此按鍵。", SPOKEN_NEEDED = "需要 Spoken 插件。", SPOKEN_MUTED = "已靜音", SPOKEN_WAIT = "等待對話結束", SPOKEN_QUEUE = "朗讀佇列", SPOKEN_QUEUE_CLOSE = "從佇列移除", SPOKEN_QUEUE_EMPTY = "沒有等待中的內容。", SPOKEN_QUEUE_TIP = "等待朗讀的 NPC 與書籍。點擊其中一個立即收聽，其餘保持順序。", THEME_FOLIO = "對開本", THEME_FOLIO_DARK = "夜色對開本", DM_FACTION = "暗月馬戲團", DM_TICKET = "暗月馬戲團獎券" },
}
OPTS3.esMX = OPTS3.esES
for loc, list in pairs(OPTS3) do
    if T[loc] then for k, v in pairs(list) do T[loc][k] = v end end
end

-- Lecteur Spoken depuis la manette (menu du bouton Y).
local SPOKEN_PAD = {
    enUS = { SPOKEN_NOTICE_TIP = "%d waiting: click to choose", SPOKEN_HELD = "waiting: pick it in the queue", SPOKEN_HELD_TAG = "paused", PAD_SPOKEN_PAUSE = "Pause / Resume", PAD_SPOKEN_SKIP = "Skip" },
    frFR = { SPOKEN_NOTICE_TIP = "%d en attente : clique pour choisir", SPOKEN_HELD = "en attente : choisis-la dans la file", SPOKEN_HELD_TAG = "à la demande", PAD_SPOKEN_PAUSE = "Pause / Reprise", PAD_SPOKEN_SKIP = "Passer" },
    deDE = { SPOKEN_NOTICE_TIP = "%d wartend: klicken zum Auswählen", SPOKEN_HELD = "wartet: in der Warteschlange auswählen", SPOKEN_HELD_TAG = "auf Abruf", PAD_SPOKEN_PAUSE = "Pause / Weiter", PAD_SPOKEN_SKIP = "Überspringen" },
    esES = { SPOKEN_NOTICE_TIP = "%d en espera: haz clic para elegir", SPOKEN_HELD = "en espera: elígela en la cola", SPOKEN_HELD_TAG = "a demanda", PAD_SPOKEN_PAUSE = "Pausa / Reanudar", PAD_SPOKEN_SKIP = "Saltar" },
    itIT = { SPOKEN_NOTICE_TIP = "%d in attesa: clicca per scegliere", SPOKEN_HELD = "in attesa: sceglila nella coda", SPOKEN_HELD_TAG = "a richiesta", PAD_SPOKEN_PAUSE = "Pausa / Riprendi", PAD_SPOKEN_SKIP = "Salta" },
    ptBR = { SPOKEN_NOTICE_TIP = "%d aguardando: clique para escolher", SPOKEN_HELD = "aguardando: escolha-a na fila", SPOKEN_HELD_TAG = "sob demanda", PAD_SPOKEN_PAUSE = "Pausar / Retomar", PAD_SPOKEN_SKIP = "Pular" },
    ruRU = { SPOKEN_NOTICE_TIP = "%d в ожидании: нажмите, чтобы выбрать", SPOKEN_HELD = "ждёт: выберите в очереди", SPOKEN_HELD_TAG = "по запросу", PAD_SPOKEN_PAUSE = "Пауза / Продолжить", PAD_SPOKEN_SKIP = "Пропустить" },
    koKR = { SPOKEN_NOTICE_TIP = "%d개 대기 중: 클릭하여 선택", SPOKEN_HELD = "대기 중: 대기열에서 선택하세요", SPOKEN_HELD_TAG = "수동", PAD_SPOKEN_PAUSE = "일시정지 / 재개", PAD_SPOKEN_SKIP = "건너뛰기" },
    zhCN = { SPOKEN_NOTICE_TIP = "%d 个等待中：点击选择", SPOKEN_HELD = "等待中：在队列中选择", SPOKEN_HELD_TAG = "手动", PAD_SPOKEN_PAUSE = "暂停 / 继续", PAD_SPOKEN_SKIP = "跳过" },
    zhTW = { SPOKEN_NOTICE_TIP = "%d 個等待中：點擊選擇", SPOKEN_HELD = "等待中：在佇列中選擇", SPOKEN_HELD_TAG = "手動", PAD_SPOKEN_PAUSE = "暫停 / 繼續", PAD_SPOKEN_SKIP = "跳過" },
}
SPOKEN_PAD.esMX = SPOKEN_PAD.esES
for loc, list in pairs(SPOKEN_PAD) do
    local dest = (loc == "enUS") and enUS or T[loc]
    if dest then for k, v in pairs(list) do dest[k] = v end end
end

-- Aide manette (options et astuce unique).
local PAD_HELP = {
    enUS = { SEC_PAD = "Gamepad", PAD_USE = "Use the gamepad in conversations and books",
        PAD_HELP1 = "Conversations and books: D-pad to pick, A to confirm, B to close.",
        PAD_HELP2 = "Books: D-pad left/right turns the pages, Y opens the ribbon's menu.",
        PAD_HELP3 = "Spoken's player: Share (View on Xbox One), tap to pause, hold to skip, hold Share + Y for the reading queue.",
        PAD_TIP = "D-pad: choose  ·  A: confirm  ·  B: close  (all buttons in Storytale's options)" },
    frFR = { SEC_PAD = "Manette", PAD_USE = "Utiliser la manette dans les conversations et les livres",
        PAD_HELP1 = "Conversations et livres : croix pour choisir, A pour valider, B pour fermer.",
        PAD_HELP2 = "Livres : croix gauche/droite pour tourner les pages, Y pour le menu du ruban.",
        PAD_HELP3 = "Lecteur de Spoken : Share (Vue sur Xbox One), appui court pour la pause, appui long pour passer, Share maintenu + Y pour la file de lecture.",
        PAD_TIP = "Croix : choisir  ·  A : valider  ·  B : fermer  (tous les boutons dans les options de Storytale)" },
    deDE = { SEC_PAD = "Controller", PAD_USE = "Controller in Gesprächen und Büchern verwenden",
        PAD_HELP1 = "Gespräche und Bücher: Steuerkreuz zum Wählen, A zum Bestätigen, B zum Schließen.",
        PAD_HELP2 = "Bücher: Steuerkreuz links/rechts blättert, Y öffnet das Menü des Lesebands.",
        PAD_HELP3 = "Spoken-Player: Share (Ansicht auf Xbox One), kurz für Pause, lang zum Überspringen, Share halten + Y für die Warteschlange.",
        PAD_TIP = "Steuerkreuz: wählen  ·  A: bestätigen  ·  B: schließen  (alle Tasten in den Storytale-Optionen)" },
    esES = { SEC_PAD = "Mando", PAD_USE = "Usar el mando en conversaciones y libros",
        PAD_HELP1 = "Conversaciones y libros: cruceta para elegir, A para confirmar, B para cerrar.",
        PAD_HELP2 = "Libros: cruceta izquierda/derecha pasa las páginas, Y abre el menú de la cinta.",
        PAD_HELP3 = "Reproductor de Spoken: Share (Vista en Xbox One), pulsar para pausar, mantener para saltar, mantener Share + Y para la cola.",
        PAD_TIP = "Cruceta: elegir  ·  A: confirmar  ·  B: cerrar  (todos los botones en las opciones de Storytale)" },
    itIT = { SEC_PAD = "Controller", PAD_USE = "Usa il controller nelle conversazioni e nei libri",
        PAD_HELP1 = "Conversazioni e libri: croce direzionale per scegliere, A per confermare, B per chiudere.",
        PAD_HELP2 = "Libri: croce sinistra/destra gira le pagine, Y apre il menu del nastro.",
        PAD_HELP3 = "Lettore di Spoken: Share (Visualizza su Xbox One), premi per la pausa, tieni premuto per saltare, Share + Y per la coda.",
        PAD_TIP = "Croce: scegli  ·  A: conferma  ·  B: chiudi  (tutti i tasti nelle opzioni di Storytale)" },
    ptBR = { SEC_PAD = "Controle", PAD_USE = "Usar o controle em conversas e livros",
        PAD_HELP1 = "Conversas e livros: direcional para escolher, A para confirmar, B para fechar.",
        PAD_HELP2 = "Livros: direcional esquerda/direita vira as páginas, Y abre o menu da fita.",
        PAD_HELP3 = "Player do Spoken: Share (Exibir no Xbox One), toque para pausar, segure para pular, segure Share + Y para a fila.",
        PAD_TIP = "Direcional: escolher  ·  A: confirmar  ·  B: fechar  (todos os botões nas opções do Storytale)" },
    ruRU = { SEC_PAD = "Геймпад", PAD_USE = "Использовать геймпад в диалогах и книгах",
        PAD_HELP1 = "Диалоги и книги: крестовина — выбор, A — подтвердить, B — закрыть.",
        PAD_HELP2 = "Книги: крестовина влево/вправо листает страницы, Y открывает меню закладки.",
        PAD_HELP3 = "Плеер Spoken: Share (Просмотр на Xbox One) — нажать для паузы, удерживать для пропуска, Share + Y — очередь.",
        PAD_TIP = "Крестовина: выбор  ·  A: подтвердить  ·  B: закрыть  (все кнопки в настройках Storytale)" },
    koKR = { SEC_PAD = "게임패드", PAD_USE = "대화와 책에서 게임패드 사용",
        PAD_HELP1 = "대화와 책: 방향키로 선택, A로 확인, B로 닫기.",
        PAD_HELP2 = "책: 방향키 좌/우로 페이지 넘기기, Y로 책갈피 메뉴 열기.",
        PAD_HELP3 = "Spoken 플레이어: Share(Xbox One은 보기) 짧게 눌러 일시정지, 길게 눌러 건너뛰기, Share + Y로 대기열.",
        PAD_TIP = "방향키: 선택  ·  A: 확인  ·  B: 닫기  (모든 버튼은 Storytale 설정에)" },
    zhCN = { SEC_PAD = "手柄", PAD_USE = "在对话和书籍中使用手柄",
        PAD_HELP1 = "对话和书籍：方向键选择，A 确认，B 关闭。",
        PAD_HELP2 = "书籍：方向键左/右翻页，Y 打开书签菜单。",
        PAD_HELP3 = "Spoken 播放器：Share（Xbox One 为视图键）短按暂停，长按跳过，按住 Share + Y 打开队列。",
        PAD_TIP = "方向键：选择  ·  A：确认  ·  B：关闭（全部按键见 Storytale 设置）" },
    zhTW = { SEC_PAD = "手把", PAD_USE = "在對話與書籍中使用手把",
        PAD_HELP1 = "對話與書籍：方向鍵選擇，A 確認，B 關閉。",
        PAD_HELP2 = "書籍：方向鍵左/右翻頁，Y 開啟書籤選單。",
        PAD_HELP3 = "Spoken 播放器：Share（Xbox One 為檢視鍵）短按暫停，長按跳過，按住 Share + Y 開啟佇列。",
        PAD_TIP = "方向鍵：選擇  ·  A：確認  ·  B：關閉（全部按鍵見 Storytale 設定）" },
}
PAD_HELP.esMX = PAD_HELP.esES
for loc, list in pairs(PAD_HELP) do
    local dest = (loc == "enUS") and enUS or T[loc]
    if dest then for k, v in pairs(list) do dest[k] = v end end
end

-- Recherche dans les options.
local OPT_SEARCH = {
    enUS = { OPT_SEARCH = "Search options", OPT_SEARCH_NONE = "No match" },
    frFR = { OPT_SEARCH = "Rechercher une option", OPT_SEARCH_NONE = "Aucun résultat" },
    deDE = { OPT_SEARCH = "Optionen durchsuchen", OPT_SEARCH_NONE = "Kein Treffer" },
    esES = { OPT_SEARCH = "Buscar opciones", OPT_SEARCH_NONE = "Sin resultados" },
    itIT = { OPT_SEARCH = "Cerca opzioni", OPT_SEARCH_NONE = "Nessun risultato" },
    ptBR = { OPT_SEARCH = "Buscar opções", OPT_SEARCH_NONE = "Nenhum resultado" },
    ruRU = { OPT_SEARCH = "Поиск настроек", OPT_SEARCH_NONE = "Ничего не найдено" },
    koKR = { OPT_SEARCH = "설정 검색", OPT_SEARCH_NONE = "결과 없음" },
    zhCN = { OPT_SEARCH = "搜索选项", OPT_SEARCH_NONE = "无结果" },
    zhTW = { OPT_SEARCH = "搜尋選項", OPT_SEARCH_NONE = "無結果" },
}
OPT_SEARCH.esMX = OPT_SEARCH.esES
for loc, list in pairs(OPT_SEARCH) do
    local dest = (loc == "enUS") and enUS or T[loc]
    if dest then for k, v in pairs(list) do dest[k] = v end end
end

-- Astuces manette : livre et lecteur Spoken.
local PAD_TIPS2 = {
    enUS = { PAD_TIP_BOOK = "D-pad left/right: turn pages  ·  Y: bookmark ribbon menu  ·  B: close", PAD_TIP_SPOKEN = "Spoken's player  —  Share: tap to pause, hold to skip  ·  hold Share + Y: reading queue" },
    frFR = { PAD_TIP_BOOK = "Croix gauche/droite : tourner les pages  ·  Y : menu du ruban  ·  B : fermer", PAD_TIP_SPOKEN = "Lecteur Spoken  —  Share : appui court pour la pause, appui long pour passer  ·  Share maintenu + Y : file de lecture" },
    deDE = { PAD_TIP_BOOK = "Steuerkreuz links/rechts: blättern  ·  Y: Menü des Lesebands  ·  B: schließen", PAD_TIP_SPOKEN = "Spoken-Player  —  Share: kurz für Pause, lang zum Überspringen  ·  Share halten + Y: Warteschlange" },
    esES = { PAD_TIP_BOOK = "Cruceta izquierda/derecha: pasar páginas  ·  Y: menú de la cinta  ·  B: cerrar", PAD_TIP_SPOKEN = "Reproductor de Spoken  —  Share: pulsar para pausar, mantener para saltar  ·  mantener Share + Y: cola" },
    itIT = { PAD_TIP_BOOK = "Croce sinistra/destra: gira le pagine  ·  Y: menu del nastro  ·  B: chiudi", PAD_TIP_SPOKEN = "Lettore di Spoken  —  Share: premi per la pausa, tieni premuto per saltare  ·  Share + Y: coda" },
    ptBR = { PAD_TIP_BOOK = "Direcional esquerda/direita: virar páginas  ·  Y: menu da fita  ·  B: fechar", PAD_TIP_SPOKEN = "Player do Spoken  —  Share: toque para pausar, segure para pular  ·  segure Share + Y: fila" },
    ruRU = { PAD_TIP_BOOK = "Крестовина влево/вправо: листать  ·  Y: меню закладки  ·  B: закрыть", PAD_TIP_SPOKEN = "Плеер Spoken  —  Share: нажать — пауза, удерживать — пропуск  ·  Share + Y: очередь" },
    koKR = { PAD_TIP_BOOK = "방향키 좌/우: 페이지 넘기기  ·  Y: 책갈피 메뉴  ·  B: 닫기", PAD_TIP_SPOKEN = "Spoken 플레이어  —  Share: 짧게 일시정지, 길게 건너뛰기  ·  Share + Y: 대기열" },
    zhCN = { PAD_TIP_BOOK = "方向键左/右：翻页  ·  Y：书签菜单  ·  B：关闭", PAD_TIP_SPOKEN = "Spoken 播放器 —— Share：短按暂停，长按跳过  ·  按住 Share + Y：队列" },
    zhTW = { PAD_TIP_BOOK = "方向鍵左/右：翻頁  ·  Y：書籤選單  ·  B：關閉", PAD_TIP_SPOKEN = "Spoken 播放器 —— Share：短按暫停，長按跳過  ·  按住 Share + Y：佇列" },
}
PAD_TIPS2.esMX = PAD_TIPS2.esES
for loc, list in pairs(PAD_TIPS2) do
    local dest = (loc == "enUS") and enUS or T[loc]
    if dest then for k, v in pairs(list) do dest[k] = v end end
end

-- Theme DialogueUI : sa vraie interface.
local THEME_DUI_L = {
    enUS = { THEME_DUI = "DialogueUI (its own interface)" },
    frFR = { THEME_DUI = "DialogueUI (sa propre interface)" },
    deDE = { THEME_DUI = "DialogueUI (eigene Oberfläche)" },
    esES = { THEME_DUI = "DialogueUI (su propia interfaz)" },
    itIT = { THEME_DUI = "DialogueUI (la sua interfaccia)" },
    ptBR = { THEME_DUI = "DialogueUI (interface própria)" },
    ruRU = { THEME_DUI = "DialogueUI (собственный интерфейс)" },
    koKR = { THEME_DUI = "DialogueUI (자체 인터페이스)" },
    zhCN = { THEME_DUI = "DialogueUI（其自身界面）" },
    zhTW = { THEME_DUI = "DialogueUI（其自身介面）" },
}
THEME_DUI_L.esMX = THEME_DUI_L.esES
for loc, list in pairs(THEME_DUI_L) do
    local dest = (loc == "enUS") and enUS or T[loc]
    if dest then for k, v in pairs(list) do dest[k] = v end end
end

local own = T[LOCALE] or {}
DWE.L = setmetatable({}, { __index = function(_, k)
    return GAME[k] or own[k] or enUS[k]
end })
