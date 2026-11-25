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

-- Bulle d'Azeroth facon PNJ (texte jaune pale des bulles du jeu).
local BUBBLE_NPC = {
    enUS = "Azeroth NPC Bubble",
    frFR = "Bulle d'Azeroth (PNJ)",
    deDE = "Azeroth-Sprechblase (NSC)",
    esES = "Bocadillo de Azeroth (PNJ)",
    itIT = "Fumetto di Azeroth (PNG)",
    ptBR = "Balão de Azeroth (PNJ)",
    ruRU = "Облачко Азерота (НИП)",
    koKR = "아제로스 말풍선 (NPC)",
    zhCN = "艾泽拉斯气泡（NPC）",
    zhTW = "艾澤拉斯對話泡泡（NPC）",
}
BUBBLE_NPC.esMX = BUBBLE_NPC.esES
for loc, str in pairs(BUBBLE_NPC) do
    local dest = (loc == "enUS") and enUS or T[loc]
    if dest then dest.THEME_BUBBLE_NPC = str end
end

-- Titres des sections et libelles revus des options.
local OPTS = {
    enUS = { OPT_WINDOW_OPEN = "Open Storytale options", OPT_LAUNCH_TEXT = "Storytale's options open in their own window, with theme previews and full gamepad support.", OPT_LAUNCH_HOW = "You can also type /storytale, use the minimap button, or set a key in Options > Keybindings > AddOns > Storytale.", OPT_TAB_MAIN = "General", OPT_WINDOW_HINT = "Gamepad: D-pad to move, A to select, B to close, L1 / R1 (LB / RB) to change tab", SEC_THEME = "Theme", SEC_TEXT = "Text", SEC_PLACE = "Placement", SEC_KEYS = "Controls",
        THEME_HINT = "Click a theme to apply it.", FONT_FAMILY = "Font", FONT_SIZE = "Text size",
        OPACITY_LBL = "Frame opacity", WHEEL_THEME = "Also dress the choice wheel",
        SPOKEN_THEME = "Also dress the Spoken player", ATTACH_NPC = "Follow the NPC on screen",
        ATTACH_TIP = "Hold right-click on the wheel or the text to move them.", LOCK = "Lock frames",
        NPC_RESET = "Reset position and size", KEY_USE_BLIZZ = "Use the game's Interact key",
        KEY_TOGGLE = "\"Dialogue\" key:", ESC_CLOSE = "Escape ends the conversation",
        WHEEL_SCROLL = "Mouse wheel browses choices (hold click to zoom)",
        BOOK_STYLE = "Books and letters:", BOOK_ADDON = "This addon, with a parchment theme (Gilded Vellum if a bubble theme is chosen)",
        BOOK_DUI = "DialogueUI", BOOK_BLIZZ = "Blizzard" },
    frFR = { OPT_WINDOW_OPEN = "Ouvrir les options Storytale", OPT_LAUNCH_TEXT = "Les options de Storytale s'ouvrent dans leur propre fenêtre, avec l'aperçu des thèmes et la manette.", OPT_LAUNCH_HOW = "Vous pouvez aussi taper /storytale, utiliser le bouton de la mini-carte, ou choisir une touche dans Options > Raccourcis > AddOns > Storytale.", OPT_TAB_MAIN = "Général", OPT_WINDOW_HINT = "Manette : croix pour se déplacer, A pour valider, B pour fermer, L1 / R1 (LB / RB) pour changer d'onglet", SEC_THEME = "Thème", SEC_TEXT = "Texte", SEC_PLACE = "Placement", SEC_KEYS = "Commandes",
        THEME_HINT = "Cliquez sur un thème pour l'appliquer.", FONT_FAMILY = "Police", FONT_SIZE = "Taille du texte",
        OPACITY_LBL = "Opacité du cadre", WHEEL_THEME = "Habiller aussi la roue des choix",
        SPOKEN_THEME = "Habiller aussi le lecteur Spoken", ATTACH_NPC = "Suivre le PNJ à l'écran",
        ATTACH_TIP = "Clic droit maintenu sur la roue ou le texte pour les déplacer.", LOCK = "Verrouiller les cadres",
        NPC_RESET = "Réinitialiser position et taille", KEY_USE_BLIZZ = "Utiliser la touche « Interagir » du jeu",
        KEY_TOGGLE = "Touche « Dialogue » :", ESC_CLOSE = "Échap termine la conversation",
        WHEEL_SCROLL = "La molette parcourt les choix (clic maintenu : zoom)",
        BOOK_STYLE = "Livres et lettres :", BOOK_ADDON = "Cet addon, avec un thème parchemin (Vélin doré si un thème bulle est choisi)",
        BOOK_DUI = "DialogueUI", BOOK_BLIZZ = "Blizzard" },
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

-- Theme Personnalise : nom, ligne des couleurs, les 4 couleurs, bouton "partir du theme actuel".
local CUSTOM_THEME = {
    enUS = { "Custom", "Custom theme colors:", "Background", "Border", "Text", "Highlight", "Copy colors from the selected theme" },
    frFR = { "Personnalisé", "Couleurs du thème Personnalisé :", "Fond", "Contour", "Texte", "Surbrillance", "Copier les couleurs du thème sélectionné" },
    deDE = { "Eigenes", "Farben des eigenen Themas:", "Hintergrund", "Rand", "Text", "Hervorhebung", "Farben des gewählten Themas kopieren" },
    esES = { "Personalizado", "Colores del tema personalizado:", "Fondo", "Borde", "Texto", "Resaltado", "Copiar los colores del tema seleccionado" },
    esMX = { "Personalizado", "Colores del tema personalizado:", "Fondo", "Borde", "Texto", "Resaltado", "Copiar los colores del tema seleccionado" },
    itIT = { "Personalizzato", "Colori del tema personalizzato:", "Sfondo", "Bordo", "Testo", "Evidenziazione", "Copia i colori del tema selezionato" },
    ptBR = { "Personalizado", "Cores do tema personalizado:", "Fundo", "Borda", "Texto", "Destaque", "Copiar as cores do tema selecionado" },
    ruRU = { "Свой", "Цвета своей темы:", "Фон", "Рамка", "Текст", "Выделение", "Скопировать цвета выбранной темы" },
    koKR = { "사용자 지정", "사용자 지정 테마 색상:", "배경", "테두리", "글자", "강조", "선택한 테마의 색상 복사" },
    zhCN = { "自定义", "自定义主题颜色：", "背景", "边框", "文字", "高亮", "复制所选主题的颜色" },
    zhTW = { "自訂", "自訂主題顏色：", "背景", "邊框", "文字", "高亮", "複製所選主題的顏色" },
}
for loc, list in pairs(CUSTOM_THEME) do
    local dest = (loc == "enUS") and enUS or T[loc]
    if dest then
        dest.THEME_CUSTOM, dest.CUSTOM_COLORS, dest.CUSTOM_BG, dest.CUSTOM_BORDER = list[1], list[2], list[3], list[4]
        dest.CUSTOM_TEXT, dest.CUSTOM_SEL, dest.CUSTOM_FROM_THEME = list[5], list[6], list[7]
    end
end

-- Option : cacher l'interface du jeu pendant les conversations et les livres.
local HIDE_UI = {
    enUS = "Hide the game interface during conversations and books",
    frFR = "Cacher l'interface du jeu pendant les dialogues et les livres",
    deDE = "Spieloberfläche während Gesprächen und Büchern ausblenden",
    esES = "Ocultar la interfaz del juego en conversaciones y libros",
    esMX = "Ocultar la interfaz del juego en conversaciones y libros",
    itIT = "Nascondi l'interfaccia di gioco durante dialoghi e libri",
    ptBR = "Ocultar a interface do jogo em conversas e livros",
    ruRU = "Скрывать интерфейс игры во время разговоров и чтения книг",
    koKR = "대화 및 책을 읽는 동안 게임 인터페이스 숨기기",
    zhCN = "对话和阅读书籍时隐藏游戏界面",
    zhTW = "對話和閱讀書籍時隱藏遊戲介面",
}
for loc, text in pairs(HIDE_UI) do
    local dest = (loc == "enUS") and enUS or T[loc]
    if dest then dest.HIDE_UI = text end
end

-- Option : illustration du lieu au-dessus de la petite fenetre de Spoken.
local ZONE_ART = {
    enUS = "Show place pictures in Spoken's small window",
    frFR = "Afficher les illustrations des lieux dans la petite fenêtre de Spoken",
    deDE = "Ortsbilder in Spokens kleinem Fenster zeigen",
    esES = "Mostrar las ilustraciones de los lugares en la ventana pequeña de Spoken",
    esMX = "Mostrar las ilustraciones de los lugares en la ventana pequeña de Spoken",
    itIT = "Mostra le illustrazioni dei luoghi nella finestra piccola di Spoken",
    ptBR = "Mostrar as ilustrações dos locais na janela pequena do Spoken",
    ruRU = "Показывать иллюстрации мест в маленьком окне Spoken",
    koKR = "Spoken 작은 창에 장소 그림 표시",
    zhCN = "在 Spoken 小窗口中显示地点插图",
    zhTW = "在 Spoken 小視窗中顯示地點插圖",
}
local ZONE_ART_PAPER = {
    enUS = "Keep the painted paper edge of the picture",
    frFR = "Garder le bord de papier peint de l'illustration",
    deDE = "Gemalten Papierrand des Bildes behalten",
    esES = "Conservar el borde de papel pintado de la ilustración",
    esMX = "Conservar el borde de papel pintado de la ilustración",
    itIT = "Mantieni il bordo di carta dipinto dell'illustrazione",
    ptBR = "Manter a borda de papel pintada da ilustração",
    ruRU = "Сохранять нарисованный бумажный край иллюстрации",
    koKR = "그림의 종이 테두리 유지",
    zhCN = "保留插图的纸张边缘",
    zhTW = "保留插圖的紙張邊緣",
}
for loc, text in pairs(ZONE_ART_PAPER) do
    local dest = (loc == "enUS") and enUS or T[loc]
    if dest then dest.ZONE_ART_PAPER = text end
end
for loc, text in pairs(ZONE_ART) do
    local dest = (loc == "enUS") and enUS or T[loc]
    if dest then dest.ZONE_ART = text end
end

-- Bouton de la mini-carte : option, et son infobulle.
local MINIMAP = {
    enUS = { "Show the minimap button", "Click: options. Drag: move this button." },
    frFR = { "Afficher le bouton de la mini-carte", "Clic : options. Glisser : déplacer ce bouton." },
    deDE = { "Minikarten-Knopf anzeigen", "Klick: Optionen. Ziehen: Knopf verschieben." },
    esES = { "Mostrar el botón del minimapa", "Clic: opciones. Arrastrar: mover este botón." },
    esMX = { "Mostrar el botón del minimapa", "Clic: opciones. Arrastrar: mover este botón." },
    itIT = { "Mostra il pulsante della minimappa", "Clic: opzioni. Trascina: sposta questo pulsante." },
    ptBR = { "Mostrar o botão do minimapa", "Clique: opções. Arrastar: mover este botão." },
    ruRU = { "Показывать кнопку у мини-карты", "Щелчок: настройки. Перетащить: переместить кнопку." },
    koKR = { "미니맵 버튼 표시", "클릭: 설정. 드래그: 버튼 이동." },
    zhCN = { "显示小地图按钮", "点击：设置。拖动：移动此按钮。" },
    zhTW = { "顯示小地圖按鈕", "點擊：設定。拖曳：移動此按鈕。" },
}
for loc, list in pairs(MINIMAP) do
    local dest = (loc == "enUS") and enUS or T[loc]
    if dest then dest.MINIMAP_BTN, dest.MINIMAP_TIP = list[1], list[2] end
end

-- Themes Personnalises enregistres : Enregistrer, liste, nom, suppression, liste vide, Supprimer.
local CUSTOM_PRESETS = {
    enUS = { "Save", "Saved themes", "Name of this theme:", "Delete the theme \"%s\"?", "No saved theme yet", "Delete" },
    frFR = { "Enregistrer", "Thèmes enregistrés", "Nom de ce thème :", "Supprimer le thème « %s » ?", "Aucun thème enregistré", "Supprimer" },
    deDE = { "Speichern", "Gespeicherte Themen", "Name dieses Themas:", "Das Thema „%s“ löschen?", "Noch kein gespeichertes Thema", "Löschen" },
    esES = { "Guardar", "Temas guardados", "Nombre de este tema:", "¿Borrar el tema «%s»?", "Aún no hay temas guardados", "Borrar" },
    esMX = { "Guardar", "Temas guardados", "Nombre de este tema:", "¿Borrar el tema «%s»?", "Aún no hay temas guardados", "Borrar" },
    itIT = { "Salva", "Temi salvati", "Nome di questo tema:", "Eliminare il tema «%s»?", "Nessun tema salvato", "Elimina" },
    ptBR = { "Salvar", "Temas salvos", "Nome deste tema:", "Excluir o tema «%s»?", "Nenhum tema salvo ainda", "Excluir" },
    ruRU = { "Сохранить", "Сохранённые темы", "Название темы:", "Удалить тему «%s»?", "Сохранённых тем пока нет", "Удалить" },
    koKR = { "저장", "저장된 테마", "테마 이름:", "「%s」 테마를 삭제할까요?", "저장된 테마가 없습니다", "삭제" },
    zhCN = { "保存", "已保存的主题", "主题名称：", "删除主题“%s”？", "还没有保存的主题", "删除" },
    zhTW = { "儲存", "已儲存的主題", "主題名稱：", "刪除主題「%s」？", "尚無已儲存的主題", "刪除" },
}
for loc, list in pairs(CUSTOM_PRESETS) do
    local dest = (loc == "enUS") and enUS or T[loc]
    if dest then
        dest.PRESET_SAVE, dest.PRESET_LIST, dest.PRESET_NAME = list[1], list[2], list[3]
        dest.PRESET_DELETE_ASK, dest.PRESET_EMPTY, dest.PRESET_DELETE = list[4], list[5], list[6]
    end
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
        RESET_ALL = "Reset this profile",
        PLATE_STYLE = "Engraved plaques (stone, marble, bronze, silver)", PLATE_ADDON = "Storytale",
        WHEEL_SIDE = "Choice wheel side:", SIDE_RIGHT = "Right of the NPC", SIDE_LEFT = "Left of the NPC",
        RESET_ALL_CONFIRM = "Reset the profile \"%s\" to how it was when Storytale was installed?" },
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
        RESET_ALL = "Réinitialiser ce profil",
        PLATE_STYLE = "Plaques gravées (pierre, marbre, bronze, argent)", PLATE_ADDON = "Storytale",
        WHEEL_SIDE = "Côté de la roue des choix :", SIDE_RIGHT = "À droite du PNJ", SIDE_LEFT = "À gauche du PNJ",
        RESET_ALL_CONFIRM = "Remettre le profil « %s » comme à l'installation de Storytale ?" },
}
for loc, list in pairs(OPTS2) do
    local dest = (loc == "enUS") and enUS or T[loc]
    if dest then for k, v in pairs(list) do dest[k] = v end end
end

-- Traductions des options recentes (autres langues que l'anglais et le francais).
local OPTS3 = {
    deDE = { MENU_VOICE_TURN = "Stimme folgt meinen Seiten", BOOK_VOICE_TURN = "Die Stimme folgt den Seiten, die ich umblättere (von Spoken gelesene Bücher)", BOOK_STOP_CLOSE = "Stimme beim Schließen eines Buches stoppen (Spoken)", MENU_STOP_CLOSE = "Stimme beim Schließen stoppen", MENU_MARK = "Seite markieren", ERR_NOTICE = "ein Fehler ist aufgetreten. Gib /storytale errors für Details ein.", ERR_LOOP = "%s schlägt ständig fehl und wurde bis zum /reload gestoppt.", ERR_NONE = "kein Fehler in dieser Sitzung.", ERR_CLEARED = "Fehler gelöscht.", MENU_VOICE = "Vorlesen", MENU_TURN_FX = "Seitenanimation", RIBBON_TIP = "Leseoptionen", BOOK_TURN_FX = "Animation und Geräusch beim Umblättern (offenes Buch)", HIGHLIGHT_BTN = "Hervorhebung", HIGHLIGHT_BTN_OFF = "Hervorhebung: aus", HIGHLIGHT_ON = "Gelesene Wörter hervorheben", HIGHLIGHT_OFF = "Hervorhebung ausblenden", AUTOSCROLL_STOP = "Stimme nicht mehr folgen", AUTOSCROLL_START = "Der Stimme folgen", BOOK_AUTOSCROLL = "Von Spoken vorgelesene Bücher folgen der Stimme (Scrollen, Umblättern)", SPOKEN_SMART = "Intelligente Lesewarteschlange", SPOKEN_SMART_TIP = "Storytale entscheidet, wer zuerst spricht: Begrüßungen weichen, Quests werden nie unterbrochen, Bücher warten auf das Ende von Gesprächen. Abwählen, damit Spoken seine Warteschlange unverändert selbst verwaltet.", SEC_BOOKS = "Bücher, Briefe und Tafeln", BOOKS_HDR = "Bücher und Briefe", BOOK_STYLE = "Angezeigt von:", BOOK_DUI = "DialogueUI", BOOK_BLIZZ = "Blizzard", BOOK_ADDON_TIP = "Von Storytale mit einem Pergament-Thema angezeigt (Goldenes Velin, wenn ein Sprechblasen-Thema gewählt ist).", BOOK_LOOK = "Stil:", BOOK_LOOK_AUTO = "Automatisch", BOOK_LOOK_NOTE = "Einzelne Seite", BOOK_LOOK_BOOK = "Offenes Buch", BOOK_LOOK_FRAME = "Themenrahmen", BOOK_CLOSE = "Schließen", BOOK_MUTE = "Stimme stumm", BOOK_UNMUTE = "Vorlesen", BOOK_READING = "Ich lese diese Geschichte gerade…", BOOK_NEW = "Das habe ich noch nie gelesen…", BOOK_UNFINISHED = "Das habe ich nie zu Ende gelesen…", BOOK_READ = "Diese Geschichte kenne ich schon.", READ_MARKS = "Anzeigen, ob ein Buch oder eine Tafel schon gelesen wurde (Tooltip, Spoken-Warteschlange)", BOOK_TIP_CURSOR = "Tooltip von Büchern und Tafeln an der Maus anzeigen (statt in der Bildschirmecke)", PLATE_STYLE = "Gravierte Tafeln (Stein, Marmor, Bronze, Silber)", PLATE_ADDON_TIP = "Von Storytale auf einer Tafel aus passendem Material angezeigt.", PLATE_LOOK = "Material der Tafel:", PLATE_STONE = "Stein", PLATE_MARBLE = "Marmor", PLATE_BRONZE = "Bronze", PLATE_SILVER = "Silber", PLATE_AUTO_TIP = "Verwendet das Material der Tafel im Spiel. Wähle ein anderes, um es für alle Tafeln zu nutzen.", QUEST_AUTO_W = "Breite der Questvorschau passt sich dem Text an (abwählen, um sie mit dem Griff einzustellen)", PLACE_SKIN = "Fenster der Gebietserzählung (betretene Orte):", PLACE_THEME = "Aktuelles Thema", PLACE_PAPER = "Einzelne Seite", CHOICE_SIZE = "Größe der Auswahl", WHEEL_SIDE = "Seite des Auswahlrads:", SIDE_RIGHT = "Rechts vom NPC", SIDE_LEFT = "Links vom NPC", RESET_ALL = "Dieses Profil zurücksetzen", RESET_ALL_CONFIRM = "Das Profil „%s“ auf den Stand nach der Installation von Storytale zurücksetzen?", SPOKEN_CHOICE = "Eine Auswahl „Spoken“ im Rad anzeigen", SPOKEN_KEY_HINT = "Aktiviere oben die Auswahl „Spoken“, um diese Taste zu verwenden.", SPOKEN_NEEDED = "Benötigt das Addon Spoken.", SPOKEN_MUTED = "Stimme stumm", SPOKEN_WAIT = "wartet auf das Gespräch", SPOKEN_QUEUE = "Lesewarteschlange", SPOKEN_QUEUE_CLOSE = "Aus der Warteschlange entfernen", SPOKEN_QUEUE_EMPTY = "Nichts in der Warteschlange.", SPOKEN_QUEUE_TIP = "NPCs und Bücher, die vorgelesen werden. Klicke auf einen, um ihn sofort zu hören; die anderen behalten ihren Platz.", THEME_FOLIO = "Folio", THEME_FOLIO_DARK = "Nacht-Folio", DM_FACTION = "Dunkelmond-Jahrmarkt", DM_TICKET = "Preisticket des Dunkelmond-Jahrmarkts" },
    esES = { MENU_VOICE_TURN = "La voz sigue mis páginas", BOOK_VOICE_TURN = "La voz sigue las páginas que paso (libros leídos por Spoken)", BOOK_STOP_CLOSE = "Detener la voz al cerrar un libro (Spoken)", MENU_STOP_CLOSE = "Detener la voz al cerrar", MENU_MARK = "Marcar esta página", ERR_NOTICE = "se produjo un error. Escribe /storytale errors para ver los detalles.", ERR_LOOP = "%s falla una y otra vez y se detuvo hasta el /reload.", ERR_NONE = "ningún error en esta sesión.", ERR_CLEARED = "errores borrados.", MENU_VOICE = "Leer en voz alta", MENU_TURN_FX = "Animación de páginas", RIBBON_TIP = "Opciones de lectura", BOOK_TURN_FX = "Animación y sonido al pasar página (libro abierto)", HIGHLIGHT_BTN = "Resaltado", HIGHLIGHT_BTN_OFF = "Resaltado: no", HIGHLIGHT_ON = "Resaltar las palabras leídas", HIGHLIGHT_OFF = "Quitar el resaltado", AUTOSCROLL_STOP = "Dejar de seguir la voz", AUTOSCROLL_START = "Seguir la voz", BOOK_AUTOSCROLL = "Los libros leídos por Spoken siguen la voz (desplazamiento, cambio de página)", SPOKEN_SMART = "Cola de lectura inteligente", SPOKEN_SMART_TIP = "Storytale decide quién habla primero: los saludos ceden el paso, las misiones nunca se cortan y los libros esperan a que terminen las conversaciones. Desmarca para que Spoken gestione su cola por sí solo, sin cambios.", SEC_BOOKS = "Libros, cartas y placas", BOOKS_HDR = "Libros y cartas", BOOK_STYLE = "Mostrados por:", BOOK_DUI = "DialogueUI", BOOK_BLIZZ = "Blizzard", BOOK_ADDON_TIP = "Mostrados por Storytale con un tema de pergamino (Vitela dorada si se elige un tema de bocadillo).", BOOK_LOOK = "Estilo:", BOOK_LOOK_AUTO = "Automático", BOOK_LOOK_NOTE = "Página única", BOOK_LOOK_BOOK = "Libro abierto", BOOK_LOOK_FRAME = "Marco del tema", BOOK_CLOSE = "Cerrar", BOOK_MUTE = "Silenciar voz", BOOK_UNMUTE = "Leer en voz alta", BOOK_READING = "Estoy leyendo este relato…", BOOK_NEW = "Nunca he leído esto…", BOOK_UNFINISHED = "Nunca lo terminé…", BOOK_READ = "Ya conozco este relato.", READ_MARKS = "Indicar si un libro o una placa ya se ha leído (descripción emergente, cola de Spoken)", BOOK_TIP_CURSOR = "Mostrar la descripción de libros y placas junto al ratón (en lugar de la esquina de la pantalla)", PLATE_STYLE = "Placas grabadas (piedra, mármol, bronce, plata)", PLATE_ADDON_TIP = "Mostradas por Storytale en una placa del material correspondiente.", PLATE_LOOK = "Material de la placa:", PLATE_STONE = "Piedra", PLATE_MARBLE = "Mármol", PLATE_BRONZE = "Bronce", PLATE_SILVER = "Plata", PLATE_AUTO_TIP = "Usa el material de la placa del juego. Elige otro para usarlo en todas las placas.", QUEST_AUTO_W = "Ancho de la vista previa de misión adaptado al texto (desmarcar para ajustarlo con su asa)", PLACE_SKIN = "Ventana de narración de zonas (lugares en los que entras):", PLACE_THEME = "Tema actual", PLACE_PAPER = "Página única", CHOICE_SIZE = "Tamaño de las opciones", WHEEL_SIDE = "Lado de la rueda de opciones:", SIDE_RIGHT = "A la derecha del PNJ", SIDE_LEFT = "A la izquierda del PNJ", RESET_ALL = "Restablecer este perfil", RESET_ALL_CONFIRM = "¿Dejar el perfil «%s» como al instalar Storytale?", SPOKEN_CHOICE = "Mostrar una opción «Spoken» en la rueda", SPOKEN_KEY_HINT = "Activa la opción «Spoken» de arriba para usar esta tecla.", SPOKEN_NEEDED = "Requiere el addon Spoken.", SPOKEN_MUTED = "voz silenciada", SPOKEN_WAIT = "esperando la conversación", SPOKEN_QUEUE = "Cola de lectura", SPOKEN_QUEUE_CLOSE = "Quitar de la cola", SPOKEN_QUEUE_EMPTY = "Nada en espera.", SPOKEN_QUEUE_TIP = "PNJ y libros a la espera de ser leídos. Haz clic en uno para oírlo ya; los demás conservan su lugar.", THEME_FOLIO = "Folio", THEME_FOLIO_DARK = "Folio nocturno", DM_FACTION = "Feria de la Luna Negra", DM_TICKET = "Boleto de premio de la Feria de la Luna Negra" },
    itIT = { MENU_VOICE_TURN = "La voce segue le mie pagine", BOOK_VOICE_TURN = "La voce segue le pagine che sfoglio (libri letti da Spoken)", BOOK_STOP_CLOSE = "Fermare la voce quando chiudo un libro (Spoken)", MENU_STOP_CLOSE = "Fermare la voce alla chiusura", MENU_MARK = "Segna questa pagina", ERR_NOTICE = "si è verificato un errore. Digita /storytale errors per i dettagli.", ERR_LOOP = "%s continua a fallire ed è stato fermato fino al /reload.", ERR_NONE = "nessun errore in questa sessione.", ERR_CLEARED = "errori cancellati.", MENU_VOICE = "Lettura ad alta voce", MENU_TURN_FX = "Animazione delle pagine", RIBBON_TIP = "Opzioni di lettura", BOOK_TURN_FX = "Animazione e suono del cambio pagina (libro aperto)", HIGHLIGHT_BTN = "Evidenziazione", HIGHLIGHT_BTN_OFF = "Evidenziazione: no", HIGHLIGHT_ON = "Evidenzia le parole lette", HIGHLIGHT_OFF = "Togli l'evidenziazione", AUTOSCROLL_STOP = "Non seguire più la voce", AUTOSCROLL_START = "Segui la voce", BOOK_AUTOSCROLL = "I libri letti da Spoken seguono la voce (scorrimento, cambio pagina)", SPOKEN_SMART = "Coda di lettura intelligente", SPOKEN_SMART_TIP = "Storytale decide chi parla per primo: i saluti cedono il passo, le missioni non vengono mai interrotte, i libri aspettano la fine delle conversazioni. Deseleziona per lasciare che Spoken gestisca la sua coda da solo, senza modifiche.", SEC_BOOKS = "Libri, lettere e targhe", BOOKS_HDR = "Libri e lettere", BOOK_STYLE = "Mostrati da:", BOOK_DUI = "DialogueUI", BOOK_BLIZZ = "Blizzard", BOOK_ADDON_TIP = "Mostrati da Storytale con un tema pergamena (Pergamena dorata se è scelto un tema a fumetto).", BOOK_LOOK = "Stile:", BOOK_LOOK_AUTO = "Automatico", BOOK_LOOK_NOTE = "Pagina singola", BOOK_LOOK_BOOK = "Libro aperto", BOOK_LOOK_FRAME = "Cornice del tema", BOOK_CLOSE = "Chiudi", BOOK_MUTE = "Silenzia voce", BOOK_UNMUTE = "Leggi ad alta voce", BOOK_READING = "Sto leggendo questo racconto…", BOOK_NEW = "Non l'ho mai letto…", BOOK_UNFINISHED = "Non l'ho mai finito…", BOOK_READ = "Conosco già questo racconto.", READ_MARKS = "Indicare se un libro o una targa è già stato letto (descrizione, coda di Spoken)", BOOK_TIP_CURSOR = "Mostrare la descrizione di libri e targhe vicino al mouse (invece che nell'angolo dello schermo)", PLATE_STYLE = "Targhe incise (pietra, marmo, bronzo, argento)", PLATE_ADDON_TIP = "Mostrate da Storytale su una targa del materiale corrispondente.", PLATE_LOOK = "Materiale della targa:", PLATE_STONE = "Pietra", PLATE_MARBLE = "Marmo", PLATE_BRONZE = "Bronzo", PLATE_SILVER = "Argento", PLATE_AUTO_TIP = "Usa il materiale della targa nel gioco. Scegline un altro per usarlo su tutte le targhe.", QUEST_AUTO_W = "Larghezza dell'anteprima missione adattata al testo (deseleziona per regolarla con la maniglia)", PLACE_SKIN = "Finestra di narrazione delle zone (luoghi in cui entri):", PLACE_THEME = "Tema attuale", PLACE_PAPER = "Pagina singola", CHOICE_SIZE = "Dimensione delle scelte", WHEEL_SIDE = "Lato della ruota delle scelte:", SIDE_RIGHT = "A destra del PNG", SIDE_LEFT = "A sinistra del PNG", RESET_ALL = "Ripristina questo profilo", RESET_ALL_CONFIRM = "Riportare il profilo «%s» a come era all'installazione di Storytale?", SPOKEN_CHOICE = "Mostrare una scelta «Spoken» nella ruota", SPOKEN_KEY_HINT = "Attiva la scelta «Spoken» qui sopra per usare questo tasto.", SPOKEN_NEEDED = "Richiede l'addon Spoken.", SPOKEN_MUTED = "voce silenziata", SPOKEN_WAIT = "in attesa della conversazione", SPOKEN_QUEUE = "Coda di lettura", SPOKEN_QUEUE_CLOSE = "Rimuovi dalla coda", SPOKEN_QUEUE_EMPTY = "Niente in attesa.", SPOKEN_QUEUE_TIP = "PNG e libri in attesa di essere letti. Cliccane uno per ascoltarlo subito; gli altri mantengono il loro posto.", THEME_FOLIO = "Folio", THEME_FOLIO_DARK = "Folio notturno", DM_FACTION = "Fiera di Lunacupa", DM_TICKET = "Biglietto premio della Fiera di Lunacupa" },
    ptBR = { MENU_VOICE_TURN = "A voz segue minhas páginas", BOOK_VOICE_TURN = "A voz segue as páginas que eu viro (livros lidos pelo Spoken)", BOOK_STOP_CLOSE = "Parar a voz ao fechar um livro (Spoken)", MENU_STOP_CLOSE = "Parar a voz ao fechar", MENU_MARK = "Marcar esta página", ERR_NOTICE = "ocorreu um erro. Digite /storytale errors para ver os detalhes.", ERR_LOOP = "%s continua falhando e foi parado até o /reload.", ERR_NONE = "nenhum erro nesta sessão.", ERR_CLEARED = "erros apagados.", MENU_VOICE = "Leitura em voz alta", MENU_TURN_FX = "Animação das páginas", RIBBON_TIP = "Opções de leitura", BOOK_TURN_FX = "Animação e som ao virar a página (livro aberto)", HIGHLIGHT_BTN = "Destaque", HIGHLIGHT_BTN_OFF = "Destaque: não", HIGHLIGHT_ON = "Destacar as palavras lidas", HIGHLIGHT_OFF = "Remover o destaque", AUTOSCROLL_STOP = "Parar de seguir a voz", AUTOSCROLL_START = "Seguir a voz", BOOK_AUTOSCROLL = "Os livros lidos pelo Spoken acompanham a voz (rolagem, virar páginas)", SPOKEN_SMART = "Fila de leitura inteligente", SPOKEN_SMART_TIP = "O Storytale decide quem fala primeiro: as saudações cedem a vez, as missões nunca são cortadas e os livros esperam o fim das conversas. Desmarque para deixar o Spoken gerenciar a fila sozinho, sem alterações.", SEC_BOOKS = "Livros, cartas e placas", BOOKS_HDR = "Livros e cartas", BOOK_STYLE = "Exibidos por:", BOOK_DUI = "DialogueUI", BOOK_BLIZZ = "Blizzard", BOOK_ADDON_TIP = "Exibidos pelo Storytale com um tema de pergaminho (Velino dourado se um tema de balão for escolhido).", BOOK_LOOK = "Estilo:", BOOK_LOOK_AUTO = "Automático", BOOK_LOOK_NOTE = "Página única", BOOK_LOOK_BOOK = "Livro aberto", BOOK_LOOK_FRAME = "Moldura do tema", BOOK_CLOSE = "Fechar", BOOK_MUTE = "Silenciar voz", BOOK_UNMUTE = "Ler em voz alta", BOOK_READING = "Estou lendo este relato…", BOOK_NEW = "Nunca li isto…", BOOK_UNFINISHED = "Nunca terminei este…", BOOK_READ = "Já conheço este relato.", READ_MARKS = "Indicar se um livro ou placa já foi lido (dica, fila do Spoken)", BOOK_TIP_CURSOR = "Mostrar a dica de livros e placas junto ao mouse (em vez do canto da tela)", PLATE_STYLE = "Placas gravadas (pedra, mármore, bronze, prata)", PLATE_ADDON_TIP = "Exibidas pelo Storytale numa placa do material correspondente.", PLATE_LOOK = "Material da placa:", PLATE_STONE = "Pedra", PLATE_MARBLE = "Mármore", PLATE_BRONZE = "Bronze", PLATE_SILVER = "Prata", PLATE_AUTO_TIP = "Usa o material da placa no jogo. Escolha outro para usá-lo em todas as placas.", QUEST_AUTO_W = "Largura da prévia da missão adaptada ao texto (desmarque para ajustá-la com a alça)", PLACE_SKIN = "Janela de narração das zonas (lugares em que você entra):", PLACE_THEME = "Tema atual", PLACE_PAPER = "Página única", CHOICE_SIZE = "Tamanho das escolhas", WHEEL_SIDE = "Lado da roda de escolhas:", SIDE_RIGHT = "À direita do NPC", SIDE_LEFT = "À esquerda do NPC", RESET_ALL = "Redefinir este perfil", RESET_ALL_CONFIRM = "Deixar o perfil «%s» como na instalação do Storytale?", SPOKEN_CHOICE = "Mostrar uma escolha «Spoken» na roda", SPOKEN_KEY_HINT = "Ative a escolha «Spoken» acima para usar esta tecla.", SPOKEN_NEEDED = "Requer o addon Spoken.", SPOKEN_MUTED = "voz silenciada", SPOKEN_WAIT = "aguardando a conversa", SPOKEN_QUEUE = "Fila de leitura", SPOKEN_QUEUE_CLOSE = "Remover da fila", SPOKEN_QUEUE_EMPTY = "Nada na espera.", SPOKEN_QUEUE_TIP = "NPCs e livros aguardando leitura. Clique em um para ouvi-lo agora; os outros mantêm o lugar.", THEME_FOLIO = "Fólio", THEME_FOLIO_DARK = "Fólio noturno", DM_FACTION = "Feira de Negraluna", DM_TICKET = "Bilhete de prêmio da Feira de Negraluna" },
    ruRU = { MENU_VOICE_TURN = "Голос следует за моими страницами", BOOK_VOICE_TURN = "Голос следует за страницами, которые я листаю (книги, читаемые Spoken)", BOOK_STOP_CLOSE = "Останавливать голос при закрытии книги (Spoken)", MENU_STOP_CLOSE = "Стоп голоса при закрытии", MENU_MARK = "Заложить эту страницу", ERR_NOTICE = "произошла ошибка. Введите /storytale errors, чтобы узнать подробности.", ERR_LOOP = "%s постоянно выдаёт ошибку и остановлен до /reload.", ERR_NONE = "в этом сеансе ошибок нет.", ERR_CLEARED = "ошибки очищены.", MENU_VOICE = "Чтение вслух", MENU_TURN_FX = "Анимация страниц", RIBBON_TIP = "Настройки чтения", BOOK_TURN_FX = "Анимация и звук перелистывания (открытая книга)", HIGHLIGHT_BTN = "Подсветка", HIGHLIGHT_BTN_OFF = "Подсветка: выкл.", HIGHLIGHT_ON = "Подсвечивать читаемые слова", HIGHLIGHT_OFF = "Убрать подсветку", AUTOSCROLL_STOP = "Не следовать за голосом", AUTOSCROLL_START = "Следовать за голосом", BOOK_AUTOSCROLL = "Книги, читаемые Spoken, следуют за голосом (прокрутка, перелистывание)", SPOKEN_SMART = "Умная очередь чтения", SPOKEN_SMART_TIP = "Storytale решает, кто говорит первым: приветствия уступают, задания никогда не обрываются, книги ждут окончания разговоров. Снимите, чтобы Spoken сам управлял своей очередью без изменений.", SEC_BOOKS = "Книги, письма и таблички", BOOKS_HDR = "Книги и письма", BOOK_STYLE = "Показывает:", BOOK_DUI = "DialogueUI", BOOK_BLIZZ = "Blizzard", BOOK_ADDON_TIP = "Показывает Storytale в стиле пергамента (Золочёный пергамент, если выбрана тема-облачко).", BOOK_LOOK = "Стиль:", BOOK_LOOK_AUTO = "Автоматически", BOOK_LOOK_NOTE = "Одна страница", BOOK_LOOK_BOOK = "Открытая книга", BOOK_LOOK_FRAME = "Рамка темы", BOOK_CLOSE = "Закрыть", BOOK_MUTE = "Без голоса", BOOK_UNMUTE = "Читать вслух", BOOK_READING = "Я читаю эту историю…", BOOK_NEW = "Я никогда это не читал…", BOOK_UNFINISHED = "Я так и не дочитал это…", BOOK_READ = "Эту историю я уже знаю.", READ_MARKS = "Показывать, прочитана ли книга или табличка (подсказка, очередь Spoken)", BOOK_TIP_CURSOR = "Показывать подсказку книг и табличек у курсора (а не в углу экрана)", PLATE_STYLE = "Гравированные таблички (камень, мрамор, бронза, серебро)", PLATE_ADDON_TIP = "Показывает Storytale на табличке из того же материала.", PLATE_LOOK = "Материал таблички:", PLATE_STONE = "Камень", PLATE_MARBLE = "Мрамор", PLATE_BRONZE = "Бронза", PLATE_SILVER = "Серебро", PLATE_AUTO_TIP = "Использует материал таблички из игры. Выберите другой, чтобы применить его ко всем табличкам.", QUEST_AUTO_W = "Ширина обзора задания подстраивается под текст (снимите, чтобы задать её ручкой)", PLACE_SKIN = "Окно рассказа о зонах (места, куда вы входите):", PLACE_THEME = "Текущая тема", PLACE_PAPER = "Одна страница", CHOICE_SIZE = "Размер вариантов", WHEEL_SIDE = "Сторона колеса выбора:", SIDE_RIGHT = "Справа от NPC", SIDE_LEFT = "Слева от NPC", RESET_ALL = "Сбросить этот профиль", RESET_ALL_CONFIRM = "Вернуть профиль «%s» к состоянию после установки Storytale?", SPOKEN_CHOICE = "Показывать вариант «Spoken» в колесе", SPOKEN_KEY_HINT = "Включите вариант «Spoken» выше, чтобы использовать эту клавишу.", SPOKEN_NEEDED = "Требуется аддон Spoken.", SPOKEN_MUTED = "голос выключен", SPOKEN_WAIT = "ждёт окончания разговора", SPOKEN_QUEUE = "Очередь чтения", SPOKEN_QUEUE_CLOSE = "Убрать из очереди", SPOKEN_QUEUE_EMPTY = "Очередь пуста.", SPOKEN_QUEUE_TIP = "NPC и книги в очереди на чтение. Нажмите, чтобы услышать сейчас; остальные сохранят место.", THEME_FOLIO = "Фолиант", THEME_FOLIO_DARK = "Ночной фолиант", DM_FACTION = "Ярмарка Новолуния", DM_TICKET = "Призовой билет Ярмарки Новолуния" },
    koKR = { MENU_VOICE_TURN = "목소리가 내 페이지를 따라감", BOOK_VOICE_TURN = "내가 넘기는 페이지를 목소리가 따라갑니다 (Spoken이 읽는 책)", BOOK_STOP_CLOSE = "책을 닫으면 목소리 멈추기 (Spoken)", MENU_STOP_CLOSE = "닫으면 목소리 멈춤", MENU_MARK = "이 페이지 표시", ERR_NOTICE = "오류가 발생했습니다. 자세한 내용은 /storytale errors 를 입력하세요.", ERR_LOOP = "%s 이(가) 계속 실패하여 /reload 까지 중지되었습니다.", ERR_NONE = "이번 세션에 오류가 없습니다.", ERR_CLEARED = "오류를 지웠습니다.", MENU_VOICE = "소리 내어 읽기", MENU_TURN_FX = "페이지 애니메이션", RIBBON_TIP = "읽기 설정", BOOK_TURN_FX = "페이지 넘김 애니메이션과 소리 (펼친 책)", HIGHLIGHT_BTN = "강조", HIGHLIGHT_BTN_OFF = "강조: 끔", HIGHLIGHT_ON = "읽는 단어 강조", HIGHLIGHT_OFF = "강조 끄기", AUTOSCROLL_STOP = "목소리 따라가기 끄기", AUTOSCROLL_START = "목소리 따라가기", BOOK_AUTOSCROLL = "Spoken이 읽는 책이 목소리를 따라갑니다 (스크롤, 페이지 넘김)", SPOKEN_SMART = "스마트 읽기 대기열", SPOKEN_SMART_TIP = "Storytale이 누가 먼저 말할지 정합니다: 인사는 양보하고, 퀘스트는 절대 끊기지 않으며, 책은 대화가 끝날 때까지 기다립니다. 해제하면 Spoken이 대기열을 그대로 직접 관리합니다.", SEC_BOOKS = "책, 편지, 명판", BOOKS_HDR = "책과 편지", BOOK_STYLE = "표시 방식:", BOOK_DUI = "DialogueUI", BOOK_BLIZZ = "Blizzard", BOOK_ADDON_TIP = "양피지 테마로 Storytale이 표시합니다 (말풍선 테마를 고르면 금박 양피지).", BOOK_LOOK = "스타일:", BOOK_LOOK_AUTO = "자동", BOOK_LOOK_NOTE = "한 페이지", BOOK_LOOK_BOOK = "펼친 책", BOOK_LOOK_FRAME = "테마 테두리", BOOK_CLOSE = "닫기", BOOK_MUTE = "음성 끄기", BOOK_UNMUTE = "소리 내어 읽기", BOOK_READING = "이 이야기를 읽는 중이다…", BOOK_NEW = "한 번도 읽어 본 적이 없다…", BOOK_UNFINISHED = "끝까지 읽지 못했다…", BOOK_READ = "이미 아는 이야기다.", READ_MARKS = "책이나 명판을 이미 읽었는지 표시 (툴팁, Spoken 대기열)", BOOK_TIP_CURSOR = "책과 명판 툴팁을 마우스 옆에 표시 (화면 모서리 대신)", PLATE_STYLE = "새겨진 명판 (돌, 대리석, 청동, 은)", PLATE_ADDON_TIP = "같은 재질의 명판으로 Storytale이 표시합니다.", PLATE_LOOK = "명판 재질:", PLATE_STONE = "돌", PLATE_MARBLE = "대리석", PLATE_BRONZE = "청동", PLATE_SILVER = "은", PLATE_AUTO_TIP = "게임 속 명판의 재질을 사용합니다. 다른 재질을 고르면 모든 명판에 적용됩니다.", QUEST_AUTO_W = "퀘스트 미리보기 너비를 글에 맞춤 (해제하면 손잡이로 조절)", PLACE_SKIN = "지역 내레이션 창 (들어가는 장소):", PLACE_THEME = "현재 테마", PLACE_PAPER = "한 페이지", CHOICE_SIZE = "선택지 크기", WHEEL_SIDE = "선택 휠 위치:", SIDE_RIGHT = "NPC 오른쪽", SIDE_LEFT = "NPC 왼쪽", RESET_ALL = "이 프로필 초기화", RESET_ALL_CONFIRM = "「%s」 프로필을 Storytale 설치 직후 상태로 되돌릴까요?", SPOKEN_CHOICE = "휠에 「Spoken」 선택지 표시", SPOKEN_KEY_HINT = "이 키를 쓰려면 위의 「Spoken」 선택지를 켜세요.", SPOKEN_NEEDED = "Spoken 애드온이 필요합니다.", SPOKEN_MUTED = "음성 꺼짐", SPOKEN_WAIT = "대화가 끝나길 기다리는 중", SPOKEN_QUEUE = "읽기 대기열", SPOKEN_QUEUE_CLOSE = "대기열에서 제거", SPOKEN_QUEUE_EMPTY = "대기 중인 항목이 없습니다.", SPOKEN_QUEUE_TIP = "읽기를 기다리는 NPC와 책입니다. 하나를 클릭하면 바로 들을 수 있고, 나머지는 순서를 유지합니다.", THEME_FOLIO = "폴리오", THEME_FOLIO_DARK = "밤의 폴리오", DM_FACTION = "다크문 유랑단", DM_TICKET = "다크문 유랑단 상품 교환권" },
    zhCN = { MENU_VOICE_TURN = "声音跟随我翻的页", BOOK_VOICE_TURN = "声音跟随我翻到的页面（Spoken 朗读的书）", BOOK_STOP_CLOSE = "关闭书本时停止朗读（Spoken）", MENU_STOP_CLOSE = "关闭时停止朗读", MENU_MARK = "标记此页", ERR_NOTICE = "发生了错误。输入 /storytale errors 查看详情。", ERR_LOOP = "%s 持续出错，已停止直到 /reload。", ERR_NONE = "本次会话没有错误。", ERR_CLEARED = "错误已清除。", MENU_VOICE = "朗读", MENU_TURN_FX = "翻页动画", RIBBON_TIP = "阅读选项", BOOK_TURN_FX = "翻页动画与音效（打开的书）", HIGHLIGHT_BTN = "高亮", HIGHLIGHT_BTN_OFF = "高亮：关", HIGHLIGHT_ON = "高亮朗读的词语", HIGHLIGHT_OFF = "取消高亮", AUTOSCROLL_STOP = "不再跟随声音", AUTOSCROLL_START = "跟随声音", BOOK_AUTOSCROLL = "Spoken 朗读的书籍跟随声音（滚动、翻页）", SPOKEN_SMART = "智能朗读队列", SPOKEN_SMART_TIP = "由 Storytale 决定谁先说话：问候会让位，任务绝不会被打断，书籍会等对话结束。取消勾选则由 Spoken 自行管理队列，不做任何更改。", SEC_BOOKS = "书籍、信件与铭牌", BOOKS_HDR = "书籍与信件", BOOK_STYLE = "显示方式：", BOOK_DUI = "DialogueUI", BOOK_BLIZZ = "Blizzard", BOOK_ADDON_TIP = "由 Storytale 以羊皮纸主题显示（选择气泡主题时为鎏金羊皮纸）。", BOOK_LOOK = "样式：", BOOK_LOOK_AUTO = "自动", BOOK_LOOK_NOTE = "单页", BOOK_LOOK_BOOK = "打开的书", BOOK_LOOK_FRAME = "主题边框", BOOK_CLOSE = "关闭", BOOK_MUTE = "静音", BOOK_UNMUTE = "朗读", BOOK_READING = "我正在读这个故事……", BOOK_NEW = "我从没读过这个……", BOOK_UNFINISHED = "我从没读完过……", BOOK_READ = "我已经知道这个故事了。", READ_MARKS = "显示书籍或铭牌是否已读（鼠标提示、Spoken 队列）", BOOK_TIP_CURSOR = "在鼠标旁显示书籍和铭牌的提示（而非屏幕角落）", PLATE_STYLE = "刻字铭牌（石、大理石、青铜、银）", PLATE_ADDON_TIP = "由 Storytale 以相同材质的铭牌显示。", PLATE_LOOK = "铭牌材质：", PLATE_STONE = "石", PLATE_MARBLE = "大理石", PLATE_BRONZE = "青铜", PLATE_SILVER = "银", PLATE_AUTO_TIP = "使用游戏中铭牌的材质。选择其他材质则所有铭牌都使用它。", QUEST_AUTO_W = "任务预览宽度随文字调整（取消勾选可用拖柄调整）", PLACE_SKIN = "区域旁白窗口（进入的地点）：", PLACE_THEME = "当前主题", PLACE_PAPER = "单页", CHOICE_SIZE = "选项大小", WHEEL_SIDE = "选项轮位置：", SIDE_RIGHT = "NPC 右侧", SIDE_LEFT = "NPC 左侧", RESET_ALL = "重置此配置文件", RESET_ALL_CONFIRM = "将配置文件「%s」恢复到刚安装 Storytale 时的状态？", SPOKEN_CHOICE = "在选项轮中显示「Spoken」选项", SPOKEN_KEY_HINT = "请先启用上方的「Spoken」选项以使用此按键。", SPOKEN_NEEDED = "需要 Spoken 插件。", SPOKEN_MUTED = "已静音", SPOKEN_WAIT = "等待对话结束", SPOKEN_QUEUE = "朗读队列", SPOKEN_QUEUE_CLOSE = "从队列移除", SPOKEN_QUEUE_EMPTY = "没有等待中的内容。", SPOKEN_QUEUE_TIP = "等待朗读的 NPC 与书籍。点击其中一个立即收听，其余保持顺序。", THEME_FOLIO = "对开本", THEME_FOLIO_DARK = "夜色对开本", DM_FACTION = "暗月马戏团", DM_TICKET = "暗月马戏团奖券" },
    zhTW = { MENU_VOICE_TURN = "聲音跟隨我翻的頁", BOOK_VOICE_TURN = "聲音跟隨我翻到的頁面（Spoken 朗讀的書）", BOOK_STOP_CLOSE = "關閉書本時停止朗讀（Spoken）", MENU_STOP_CLOSE = "關閉時停止朗讀", MENU_MARK = "標記此頁", ERR_NOTICE = "發生了錯誤。輸入 /storytale errors 查看詳情。", ERR_LOOP = "%s 持續出錯，已停止直到 /reload。", ERR_NONE = "本次工作階段沒有錯誤。", ERR_CLEARED = "錯誤已清除。", MENU_VOICE = "朗讀", MENU_TURN_FX = "翻頁動畫", RIBBON_TIP = "閱讀選項", BOOK_TURN_FX = "翻頁動畫與音效（打開的書）", HIGHLIGHT_BTN = "醒目標示", HIGHLIGHT_BTN_OFF = "醒目標示：關", HIGHLIGHT_ON = "醒目標示朗讀的詞語", HIGHLIGHT_OFF = "取消醒目標示", AUTOSCROLL_STOP = "不再跟隨聲音", AUTOSCROLL_START = "跟隨聲音", BOOK_AUTOSCROLL = "Spoken 朗讀的書籍跟隨聲音（捲動、翻頁）", SPOKEN_SMART = "智慧朗讀佇列", SPOKEN_SMART_TIP = "由 Storytale 決定誰先說話：問候會讓位，任務絕不會被打斷，書籍會等對話結束。取消勾選則由 Spoken 自行管理佇列，不做任何更改。", SEC_BOOKS = "書籍、信件與銘牌", BOOKS_HDR = "書籍與信件", BOOK_STYLE = "顯示方式：", BOOK_DUI = "DialogueUI", BOOK_BLIZZ = "Blizzard", BOOK_ADDON_TIP = "由 Storytale 以羊皮紙主題顯示（選擇對話泡泡主題時為鎏金羊皮紙）。", BOOK_LOOK = "樣式：", BOOK_LOOK_AUTO = "自動", BOOK_LOOK_NOTE = "單頁", BOOK_LOOK_BOOK = "打開的書", BOOK_LOOK_FRAME = "主題邊框", BOOK_CLOSE = "關閉", BOOK_MUTE = "靜音", BOOK_UNMUTE = "朗讀", BOOK_READING = "我正在讀這個故事……", BOOK_NEW = "我從沒讀過這個……", BOOK_UNFINISHED = "我從沒讀完過……", BOOK_READ = "我已經知道這個故事了。", READ_MARKS = "顯示書籍或銘牌是否已讀（滑鼠提示、Spoken 佇列）", BOOK_TIP_CURSOR = "在滑鼠旁顯示書籍和銘牌的提示（而非螢幕角落）", PLATE_STYLE = "刻字銘牌（石、大理石、青銅、銀）", PLATE_ADDON_TIP = "由 Storytale 以相同材質的銘牌顯示。", PLATE_LOOK = "銘牌材質：", PLATE_STONE = "石", PLATE_MARBLE = "大理石", PLATE_BRONZE = "青銅", PLATE_SILVER = "銀", PLATE_AUTO_TIP = "使用遊戲中銘牌的材質。選擇其他材質則所有銘牌都使用它。", QUEST_AUTO_W = "任務預覽寬度隨文字調整（取消勾選可用拖柄調整）", PLACE_SKIN = "區域旁白視窗（進入的地點）：", PLACE_THEME = "目前主題", PLACE_PAPER = "單頁", CHOICE_SIZE = "選項大小", WHEEL_SIDE = "選項輪位置：", SIDE_RIGHT = "NPC 右側", SIDE_LEFT = "NPC 左側", RESET_ALL = "重設此設定檔", RESET_ALL_CONFIRM = "將設定檔「%s」恢復到剛安裝 Storytale 時的狀態？", SPOKEN_CHOICE = "在選項輪中顯示「Spoken」選項", SPOKEN_KEY_HINT = "請先啟用上方的「Spoken」選項以使用此按鍵。", SPOKEN_NEEDED = "需要 Spoken 插件。", SPOKEN_MUTED = "已靜音", SPOKEN_WAIT = "等待對話結束", SPOKEN_QUEUE = "朗讀佇列", SPOKEN_QUEUE_CLOSE = "從佇列移除", SPOKEN_QUEUE_EMPTY = "沒有等待中的內容。", SPOKEN_QUEUE_TIP = "等待朗讀的 NPC 與書籍。點擊其中一個立即收聽，其餘保持順序。", THEME_FOLIO = "對開本", THEME_FOLIO_DARK = "夜色對開本", DM_FACTION = "暗月馬戲團", DM_TICKET = "暗月馬戲團獎券" },
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

-- Profils d'options.
local PROFILES = {
    enUS = { CAT_KEYS = "Keys and gamepad", PROFILE_FACTORY = "Defaults", PROFILE_USE_FACTORY = "Default options", PROFILE_BACK = "Back to \"%s\"", PROFILE_FACTORY_NOTE = "The Defaults profile is always as installed: changes made on it are not kept.",
        SEC_PROFILES = "Profiles", PROFILE_CUR = "Profile:", PROFILE_DEFAULT = "Main", PROFILE_USE = "Use", PROFILE_NEW = "New", PROFILE_COPY = "Copy", PROFILE_DEL = "Delete",
        PROFILE_NEWCHAR = "Use this profile for new characters", PROFILE_HINT = "Read books, heard lines and custom colors are shared by all profiles.",
        PROFILE_NAME_NEW = "Name of the new profile (default options):", PROFILE_NAME_COPY = "Name of the copy of this profile:",
        PROFILE_SWITCH_CONFIRM = "Use the profile \"%s\" on this character?\nThe interface will reload.",
        PROFILE_DEL_CONFIRM = "Delete the profile \"%s\"?\nCharacters using it go back to Main. The interface will reload." },
    frFR = { CAT_KEYS = "Touches et manette", PROFILE_FACTORY = "Par défaut", PROFILE_USE_FACTORY = "Options par défaut", PROFILE_BACK = "Revenir à « %s »", PROFILE_FACTORY_NOTE = "Le profil Par défaut reste toujours comme à l'installation : les changements faits dessus ne sont pas gardés.",
        SEC_PROFILES = "Profils", PROFILE_CUR = "Profil :", PROFILE_DEFAULT = "Principal", PROFILE_USE = "Utiliser", PROFILE_NEW = "Nouveau", PROFILE_COPY = "Copier", PROFILE_DEL = "Supprimer",
        PROFILE_NEWCHAR = "Utiliser ce profil pour les nouveaux personnages", PROFILE_HINT = "Les livres lus, les répliques entendues et les couleurs perso sont communs à tous les profils.",
        PROFILE_NAME_NEW = "Nom du nouveau profil (options par défaut) :", PROFILE_NAME_COPY = "Nom de la copie de ce profil :",
        PROFILE_SWITCH_CONFIRM = "Utiliser le profil « %s » sur ce personnage ?\nL'interface va se recharger.",
        PROFILE_DEL_CONFIRM = "Supprimer le profil « %s » ?\nLes personnages qui l'utilisent reviennent au profil Principal. L'interface va se recharger." },
    deDE = { CAT_KEYS = "Tasten und Gamepad", PROFILE_FACTORY = "Standard", PROFILE_USE_FACTORY = "Standardoptionen", PROFILE_BACK = "Zurück zu „%s“", PROFILE_FACTORY_NOTE = "Das Profil Standard bleibt immer wie nach der Installation: Änderungen daran werden nicht gespeichert.",
        SEC_PROFILES = "Profile", PROFILE_CUR = "Profil:", PROFILE_DEFAULT = "Haupt", PROFILE_USE = "Verwenden", PROFILE_NEW = "Neu", PROFILE_COPY = "Kopieren", PROFILE_DEL = "Löschen",
        PROFILE_NEWCHAR = "Dieses Profil für neue Charaktere verwenden", PROFILE_HINT = "Gelesene Bücher, gehörte Sätze und eigene Farben gelten für alle Profile.",
        PROFILE_NAME_NEW = "Name des neuen Profils (Standardoptionen):", PROFILE_NAME_COPY = "Name der Kopie dieses Profils:",
        PROFILE_SWITCH_CONFIRM = "Das Profil „%s“ für diesen Charakter verwenden?\nDie Oberfläche wird neu geladen.",
        PROFILE_DEL_CONFIRM = "Das Profil „%s“ löschen?\nCharaktere, die es nutzen, kehren zu Haupt zurück. Die Oberfläche wird neu geladen." },
    esES = { CAT_KEYS = "Teclas y mando", PROFILE_FACTORY = "Predeterminado", PROFILE_USE_FACTORY = "Opciones predeterminadas", PROFILE_BACK = "Volver a «%s»", PROFILE_FACTORY_NOTE = "El perfil Predeterminado siempre queda como al instalar: los cambios hechos en él no se guardan.",
        SEC_PROFILES = "Perfiles", PROFILE_CUR = "Perfil:", PROFILE_DEFAULT = "Principal", PROFILE_USE = "Usar", PROFILE_NEW = "Nuevo", PROFILE_COPY = "Copiar", PROFILE_DEL = "Borrar",
        PROFILE_NEWCHAR = "Usar este perfil para los personajes nuevos", PROFILE_HINT = "Los libros leídos, las frases oídas y los colores propios son comunes a todos los perfiles.",
        PROFILE_NAME_NEW = "Nombre del nuevo perfil (opciones predeterminadas):", PROFILE_NAME_COPY = "Nombre de la copia de este perfil:",
        PROFILE_SWITCH_CONFIRM = "¿Usar el perfil «%s» en este personaje?\nLa interfaz se recargará.",
        PROFILE_DEL_CONFIRM = "¿Borrar el perfil «%s»?\nLos personajes que lo usan vuelven al perfil Principal. La interfaz se recargará." },
    itIT = { CAT_KEYS = "Tasti e controller", PROFILE_FACTORY = "Predefinito", PROFILE_USE_FACTORY = "Opzioni predefinite", PROFILE_BACK = "Torna a «%s»", PROFILE_FACTORY_NOTE = "Il profilo Predefinito resta sempre come all'installazione: le modifiche fatte non vengono salvate.",
        SEC_PROFILES = "Profili", PROFILE_CUR = "Profilo:", PROFILE_DEFAULT = "Principale", PROFILE_USE = "Usa", PROFILE_NEW = "Nuovo", PROFILE_COPY = "Copia", PROFILE_DEL = "Elimina",
        PROFILE_NEWCHAR = "Usa questo profilo per i nuovi personaggi", PROFILE_HINT = "Libri letti, battute ascoltate e colori personalizzati sono comuni a tutti i profili.",
        PROFILE_NAME_NEW = "Nome del nuovo profilo (opzioni predefinite):", PROFILE_NAME_COPY = "Nome della copia di questo profilo:",
        PROFILE_SWITCH_CONFIRM = "Usare il profilo «%s» su questo personaggio?\nL'interfaccia verrà ricaricata.",
        PROFILE_DEL_CONFIRM = "Eliminare il profilo «%s»?\nI personaggi che lo usano tornano al profilo Principale. L'interfaccia verrà ricaricata." },
    ptBR = { CAT_KEYS = "Teclas e controle", PROFILE_FACTORY = "Padrão", PROFILE_USE_FACTORY = "Opções padrão", PROFILE_BACK = "Voltar para «%s»", PROFILE_FACTORY_NOTE = "O perfil Padrão fica sempre como na instalação: as mudanças feitas nele não são guardadas.",
        SEC_PROFILES = "Perfis", PROFILE_CUR = "Perfil:", PROFILE_DEFAULT = "Principal", PROFILE_USE = "Usar", PROFILE_NEW = "Novo", PROFILE_COPY = "Copiar", PROFILE_DEL = "Excluir",
        PROFILE_NEWCHAR = "Usar este perfil para novos personagens", PROFILE_HINT = "Livros lidos, falas ouvidas e cores personalizadas são comuns a todos os perfis.",
        PROFILE_NAME_NEW = "Nome do novo perfil (opções padrão):", PROFILE_NAME_COPY = "Nome da cópia deste perfil:",
        PROFILE_SWITCH_CONFIRM = "Usar o perfil «%s» neste personagem?\nA interface será recarregada.",
        PROFILE_DEL_CONFIRM = "Excluir o perfil «%s»?\nOs personagens que o usam voltam ao perfil Principal. A interface será recarregada." },
    ruRU = { CAT_KEYS = "Клавиши и геймпад", PROFILE_FACTORY = "По умолчанию", PROFILE_USE_FACTORY = "Настройки по умолчанию", PROFILE_BACK = "Вернуться к «%s»", PROFILE_FACTORY_NOTE = "Профиль «По умолчанию» всегда как после установки: изменения в нём не сохраняются.",
        SEC_PROFILES = "Профили", PROFILE_CUR = "Профиль:", PROFILE_DEFAULT = "Основной", PROFILE_USE = "Выбрать", PROFILE_NEW = "Новый", PROFILE_COPY = "Копия", PROFILE_DEL = "Удалить",
        PROFILE_NEWCHAR = "Использовать этот профиль для новых персонажей", PROFILE_HINT = "Прочитанные книги, услышанные реплики и свои цвета общие для всех профилей.",
        PROFILE_NAME_NEW = "Название нового профиля (настройки по умолчанию):", PROFILE_NAME_COPY = "Название копии этого профиля:",
        PROFILE_SWITCH_CONFIRM = "Использовать профиль «%s» для этого персонажа?\nИнтерфейс будет перезагружен.",
        PROFILE_DEL_CONFIRM = "Удалить профиль «%s»?\nПерсонажи с ним вернутся к профилю «Основной». Интерфейс будет перезагружен." },
    koKR = { CAT_KEYS = "키와 게임패드", PROFILE_FACTORY = "기본값", PROFILE_USE_FACTORY = "기본 설정 사용", PROFILE_BACK = "「%s」(으)로 돌아가기", PROFILE_FACTORY_NOTE = "기본값 프로필은 항상 설치 직후 상태입니다: 바꾼 내용은 저장되지 않습니다.",
        SEC_PROFILES = "프로필", PROFILE_CUR = "프로필:", PROFILE_DEFAULT = "기본 프로필", PROFILE_USE = "사용", PROFILE_NEW = "새로 만들기", PROFILE_COPY = "복사", PROFILE_DEL = "삭제",
        PROFILE_NEWCHAR = "새 캐릭터에 이 프로필 사용", PROFILE_HINT = "읽은 책, 들은 대사, 사용자 색상은 모든 프로필이 공유합니다.",
        PROFILE_NAME_NEW = "새 프로필 이름 (기본 설정):", PROFILE_NAME_COPY = "이 프로필 복사본의 이름:",
        PROFILE_SWITCH_CONFIRM = "이 캐릭터에 「%s」 프로필을 사용할까요?\n인터페이스가 다시 불러와집니다.",
        PROFILE_DEL_CONFIRM = "「%s」 프로필을 삭제할까요?\n이 프로필을 쓰던 캐릭터는 기본 프로필로 돌아갑니다. 인터페이스가 다시 불러와집니다." },
    zhCN = { CAT_KEYS = "按键与手柄", PROFILE_FACTORY = "默认", PROFILE_USE_FACTORY = "使用默认选项", PROFILE_BACK = "返回「%s」", PROFILE_FACTORY_NOTE = "默认配置始终与刚安装时一致：在其上的更改不会保存。",
        SEC_PROFILES = "配置文件", PROFILE_CUR = "配置文件：", PROFILE_DEFAULT = "主配置", PROFILE_USE = "使用", PROFILE_NEW = "新建", PROFILE_COPY = "复制", PROFILE_DEL = "删除",
        PROFILE_NEWCHAR = "新角色使用此配置文件", PROFILE_HINT = "已读书籍、听过的台词和自定义颜色由所有配置文件共享。",
        PROFILE_NAME_NEW = "新配置文件名称（默认选项）：", PROFILE_NAME_COPY = "此配置文件副本的名称：",
        PROFILE_SWITCH_CONFIRM = "在此角色上使用配置文件「%s」？\n界面将重新载入。",
        PROFILE_DEL_CONFIRM = "删除配置文件「%s」？\n使用它的角色将恢复为主配置。界面将重新载入。" },
    zhTW = { CAT_KEYS = "按鍵與手把", PROFILE_FACTORY = "預設", PROFILE_USE_FACTORY = "使用預設選項", PROFILE_BACK = "返回「%s」", PROFILE_FACTORY_NOTE = "預設設定檔始終與剛安裝時一致：在其上的變更不會保存。",
        SEC_PROFILES = "設定檔", PROFILE_CUR = "設定檔：", PROFILE_DEFAULT = "主設定檔", PROFILE_USE = "使用", PROFILE_NEW = "新增", PROFILE_COPY = "複製", PROFILE_DEL = "刪除",
        PROFILE_NEWCHAR = "新角色使用此設定檔", PROFILE_HINT = "已讀書籍、聽過的台詞與自訂顏色由所有設定檔共用。",
        PROFILE_NAME_NEW = "新設定檔名稱（預設選項）：", PROFILE_NAME_COPY = "此設定檔副本的名稱：",
        PROFILE_SWITCH_CONFIRM = "在此角色上使用設定檔「%s」？\n介面將重新載入。",
        PROFILE_DEL_CONFIRM = "刪除設定檔「%s」？\n使用它的角色將回到主設定檔。介面將重新載入。" },
}
PROFILES.esMX = PROFILES.esES
for loc, list in pairs(PROFILES) do
    local dest = (loc == "enUS") and enUS or T[loc]
    if dest then for k, v in pairs(list) do dest[k] = v end end
end

-- Aide manette (options et astuce unique).
local PAD_HELP = {
    enUS = { SEC_PAD = "Gamepad", PAD_USE = "Use the gamepad in conversations and books",
        PAD_HELP1 = "Conversations and books: D-pad to pick, A to confirm, B to close.",
        PAD_HELP2 = "Books: D-pad left/right turns the pages, Y opens the ribbon's menu.",
        PAD_HELP4 = "Quests: D-pad left/right goes through the items and rewards (shows their details), A picks the reward to choose.",
        PAD_HELP3 = "Spoken's player: Share (View on Xbox One), tap to pause, hold to skip, hold Share + Y for the reading queue.",
        PAD_TIP = "D-pad: choose  ·  A: confirm  ·  B: close  (all buttons in Storytale's options)" },
    frFR = { SEC_PAD = "Manette", PAD_USE = "Utiliser la manette dans les conversations et les livres",
        PAD_HELP1 = "Conversations et livres : flèches pour choisir, A pour valider, B pour fermer.",
        PAD_HELP2 = "Livres : flèches gauche/droite pour tourner les pages, Y pour le menu du ruban.",
        PAD_HELP4 = "Quêtes : flèches gauche/droite pour parcourir les objets et récompenses (affiche leur fiche), A pour choisir la récompense.",
        PAD_HELP3 = "Lecteur de Spoken : Share (Vue sur Xbox One), appui court pour la pause, appui long pour passer, Share maintenu + Y pour la file de lecture.",
        PAD_TIP = "Flèches : choisir  ·  A : valider  ·  B : fermer  (tous les boutons dans les options de Storytale)" },
    deDE = { SEC_PAD = "Controller", PAD_USE = "Controller in Gesprächen und Büchern verwenden",
        PAD_HELP1 = "Gespräche und Bücher: Steuerkreuz zum Wählen, A zum Bestätigen, B zum Schließen.",
        PAD_HELP2 = "Bücher: Steuerkreuz links/rechts blättert, Y öffnet das Menü des Lesebands.",
        PAD_HELP4 = "Quests: Steuerkreuz links/rechts durchläuft Gegenstände und Belohnungen (zeigt Details), A wählt die Belohnung.",
        PAD_HELP3 = "Spoken-Player: Share (Ansicht auf Xbox One), kurz für Pause, lang zum Überspringen, Share halten + Y für die Warteschlange.",
        PAD_TIP = "Steuerkreuz: wählen  ·  A: bestätigen  ·  B: schließen  (alle Tasten in den Storytale-Optionen)" },
    esES = { SEC_PAD = "Mando", PAD_USE = "Usar el mando en conversaciones y libros",
        PAD_HELP1 = "Conversaciones y libros: cruceta para elegir, A para confirmar, B para cerrar.",
        PAD_HELP2 = "Libros: cruceta izquierda/derecha pasa las páginas, Y abre el menú de la cinta.",
        PAD_HELP4 = "Misiones: cruceta izquierda/derecha recorre objetos y recompensas (muestra sus detalles), A elige la recompensa.",
        PAD_HELP3 = "Reproductor de Spoken: Share (Vista en Xbox One), pulsar para pausar, mantener para saltar, mantener Share + Y para la cola.",
        PAD_TIP = "Cruceta: elegir  ·  A: confirmar  ·  B: cerrar  (todos los botones en las opciones de Storytale)" },
    itIT = { SEC_PAD = "Controller", PAD_USE = "Usa il controller nelle conversazioni e nei libri",
        PAD_HELP1 = "Conversazioni e libri: croce direzionale per scegliere, A per confermare, B per chiudere.",
        PAD_HELP2 = "Libri: croce sinistra/destra gira le pagine, Y apre il menu del nastro.",
        PAD_HELP4 = "Missioni: croce sinistra/destra scorre oggetti e ricompense (ne mostra i dettagli), A sceglie la ricompensa.",
        PAD_HELP3 = "Lettore di Spoken: Share (Visualizza su Xbox One), premi per la pausa, tieni premuto per saltare, Share + Y per la coda.",
        PAD_TIP = "Croce: scegli  ·  A: conferma  ·  B: chiudi  (tutti i tasti nelle opzioni di Storytale)" },
    ptBR = { SEC_PAD = "Controle", PAD_USE = "Usar o controle em conversas e livros",
        PAD_HELP1 = "Conversas e livros: direcional para escolher, A para confirmar, B para fechar.",
        PAD_HELP2 = "Livros: direcional esquerda/direita vira as páginas, Y abre o menu da fita.",
        PAD_HELP4 = "Missões: direcional esquerda/direita percorre itens e recompensas (mostra os detalhes), A escolhe a recompensa.",
        PAD_HELP3 = "Player do Spoken: Share (Exibir no Xbox One), toque para pausar, segure para pular, segure Share + Y para a fila.",
        PAD_TIP = "Direcional: escolher  ·  A: confirmar  ·  B: fechar  (todos os botões nas opções do Storytale)" },
    ruRU = { SEC_PAD = "Геймпад", PAD_USE = "Использовать геймпад в диалогах и книгах",
        PAD_HELP1 = "Диалоги и книги: крестовина — выбор, A — подтвердить, B — закрыть.",
        PAD_HELP2 = "Книги: крестовина влево/вправо листает страницы, Y открывает меню закладки.",
        PAD_HELP4 = "Задания: крестовина влево/вправо перебирает предметы и награды (показывает описание), A выбирает награду.",
        PAD_HELP3 = "Плеер Spoken: Share (Просмотр на Xbox One) — нажать для паузы, удерживать для пропуска, Share + Y — очередь.",
        PAD_TIP = "Крестовина: выбор  ·  A: подтвердить  ·  B: закрыть  (все кнопки в настройках Storytale)" },
    koKR = { SEC_PAD = "게임패드", PAD_USE = "대화와 책에서 게임패드 사용",
        PAD_HELP1 = "대화와 책: 방향키로 선택, A로 확인, B로 닫기.",
        PAD_HELP2 = "책: 방향키 좌/우로 페이지 넘기기, Y로 책갈피 메뉴 열기.",
        PAD_HELP4 = "퀘스트: 방향키 좌/우로 아이템과 보상을 둘러봅니다 (정보 표시), A로 보상 선택.",
        PAD_HELP3 = "Spoken 플레이어: Share(Xbox One은 보기) 짧게 눌러 일시정지, 길게 눌러 건너뛰기, Share + Y로 대기열.",
        PAD_TIP = "방향키: 선택  ·  A: 확인  ·  B: 닫기  (모든 버튼은 Storytale 설정에)" },
    zhCN = { SEC_PAD = "手柄", PAD_USE = "在对话和书籍中使用手柄",
        PAD_HELP1 = "对话和书籍：方向键选择，A 确认，B 关闭。",
        PAD_HELP2 = "书籍：方向键左/右翻页，Y 打开书签菜单。",
        PAD_HELP4 = "任务：方向键左/右浏览物品和奖励（显示详情），A 选择奖励。",
        PAD_HELP3 = "Spoken 播放器：Share（Xbox One 为视图键）短按暂停，长按跳过，按住 Share + Y 打开队列。",
        PAD_TIP = "方向键：选择  ·  A：确认  ·  B：关闭（全部按键见 Storytale 设置）" },
    zhTW = { SEC_PAD = "手把", PAD_USE = "在對話與書籍中使用手把",
        PAD_HELP1 = "對話與書籍：方向鍵選擇，A 確認，B 關閉。",
        PAD_HELP2 = "書籍：方向鍵左/右翻頁，Y 開啟書籤選單。",
        PAD_HELP4 = "任務：方向鍵左/右瀏覽物品和獎勵（顯示詳情），A 選擇獎勵。",
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
    frFR = { PAD_TIP_BOOK = "Flèches gauche/droite : tourner les pages  ·  Y : menu du ruban  ·  B : fermer", PAD_TIP_SPOKEN = "Lecteur Spoken  —  Share : appui court pour la pause, appui long pour passer  ·  Share maintenu + Y : file de lecture" },
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

-- Tombes et monuments (souvent l'hommage a une vraie personne) : pas un "recit".
enUS.GRAVE_READ, enUS.GRAVE_NEW = "I have paid my respects here.", "I have not paid my respects here yet..."
enUS.GRAVE_READING = "I am paying my respects..."
for loc, v in pairs({
    frFR = { "Je me suis déjà recueilli ici.", "Je ne me suis pas encore recueilli ici…" },
    deDE = { "Ich habe hier bereits innegehalten.", "Hier habe ich noch nicht innegehalten…" },
    esES = { "Ya presenté aquí mis respetos.", "Aún no he presentado aquí mis respetos…" },
    esMX = { "Ya presenté aquí mis respetos.", "Aún no he presentado aquí mis respetos…" },
    itIT = { "Ho già reso omaggio qui.", "Non ho ancora reso omaggio qui…" },
    ptBR = { "Já prestei minhas homenagens aqui.", "Ainda não prestei minhas homenagens aqui…" },
    ruRU = { "Я уже почтил здесь память.", "Я ещё не почтил здесь память…" },
    koKR = { "이곳에서 이미 추모했다.", "아직 이곳에서 추모하지 않았다…" },
    zhCN = { "我已在此致敬。", "我还未在此致敬……" },
    zhTW = { "我已在此致敬。", "我還未在此致敬……" },
}) do if T[loc] then T[loc].GRAVE_READ, T[loc].GRAVE_NEW = v[1], v[2] end end
for loc, v in pairs({ frFR = "Je me recueille…", deDE = "Ich halte inne…", esES = "Estoy presentando mis respetos…", esMX = "Estoy presentando mis respetos…", itIT = "Sto rendendo omaggio…", ptBR = "Estou prestando minhas homenagens…", ruRU = "Я чту память…", koKR = "추모하는 중이다…", zhCN = "我正在致敬……", zhTW = "我正在致敬……" }) do if T[loc] then T[loc].GRAVE_READING = v end end

-- Astuce sous "File de lecture intelligente".
enUS.SPOKEN_SMART_HINT = "Tip: to let NPCs finish their line when you close the window, uncheck \"Stop When Window Closes\" in Spoken's options."
for loc, v in pairs({
    frFR = "Astuce : pour laisser les PNJ finir leur phrase quand vous fermez la fenêtre, décochez « Stop When Window Closes » dans les options de Spoken.",
    deDE = "Tipp: Damit NPCs ihren Satz beim Schließen des Fensters beenden, deaktiviere „Stop When Window Closes“ in den Optionen von Spoken.",
    esES = "Consejo: para que los PNJ terminen su frase al cerrar la ventana, desmarca «Stop When Window Closes» en las opciones de Spoken.",
    esMX = "Consejo: para que los PNJ terminen su frase al cerrar la ventana, desmarca «Stop When Window Closes» en las opciones de Spoken.",
    itIT = "Suggerimento: per lasciare che i PNG finiscano la frase quando chiudi la finestra, deseleziona «Stop When Window Closes» nelle opzioni di Spoken.",
    ptBR = "Dica: para os NPCs terminarem a frase ao fechar a janela, desmarque «Stop When Window Closes» nas opções do Spoken.",
    ruRU = "Совет: чтобы NPC договаривали фразу при закрытии окна, снимите «Stop When Window Closes» в настройках Spoken.",
    koKR = "팁: 창을 닫아도 NPC가 말을 끝내게 하려면 Spoken 설정에서 「Stop When Window Closes」를 해제하세요.",
    zhCN = "提示：若要在关闭窗口时让 NPC 说完，请在 Spoken 的选项中取消勾选「Stop When Window Closes」。",
    zhTW = "提示：若要在關閉視窗時讓 NPC 說完，請在 Spoken 的選項中取消勾選「Stop When Window Closes」。",
}) do if T[loc] then T[loc].SPOKEN_SMART_HINT = v end end

-- Message unique dans le chat quand Spoken n'est pas installe.
enUS.SPOKEN_TIP = "Storytale pairs well with |cffffd200Spoken|r, which gives a voice to NPCs, quests and books. You'll find it on CurseForge."
for loc, v in pairs({
    frFR = "Storytale s'accorde très bien avec |cffffd200Spoken|r, qui donne une voix aux PNJ, aux quêtes et aux livres. Vous le trouverez sur CurseForge.",
    deDE = "Storytale passt wunderbar zu |cffffd200Spoken|r, das NPCs, Quests und Büchern eine Stimme gibt. Du findest es auf CurseForge.",
    esES = "Storytale combina muy bien con |cffffd200Spoken|r, que da voz a los PNJ, las misiones y los libros. Lo encontrarás en CurseForge.",
    esMX = "Storytale combina muy bien con |cffffd200Spoken|r, que da voz a los PNJ, las misiones y los libros. Lo encontrarás en CurseForge.",
    itIT = "Storytale si abbina benissimo a |cffffd200Spoken|r, che dà voce a PNG, missioni e libri. Lo trovi su CurseForge.",
    ptBR = "Storytale combina muito bem com o |cffffd200Spoken|r, que dá voz aos NPCs, às missões e aos livros. Você o encontra no CurseForge.",
    ruRU = "Storytale отлично сочетается со |cffffd200Spoken|r, который озвучивает NPC, задания и книги. Его можно найти на CurseForge.",
    koKR = "Storytale은 NPC, 퀘스트, 책에 목소리를 입혀 주는 |cffffd200Spoken|r과 잘 어울립니다. CurseForge에서 찾을 수 있습니다.",
    zhCN = "Storytale 与 |cffffd200Spoken|r 搭配效果很好，它能为 NPC、任务和书籍配音。可在 CurseForge 上找到。",
    zhTW = "Storytale 與 |cffffd200Spoken|r 搭配效果很好，它能為 NPC、任務和書籍配音。可在 CurseForge 上找到。",
}) do if T[loc] then T[loc].SPOKEN_TIP = v end end

-- Surlignage du mot lu dans la bulle (libelle court + infobulle).
enUS.BUBBLE_HIGHLIGHT = "Highlight the word being read"
enUS.BUBBLE_HIGHLIGHT_TIP = "In the bubble, the word the voice is saying is coloured, like in Spoken's window. Only when \"Highlight Words\" is also checked in Spoken's options."
for loc, v in pairs({
    frFR = { "Surligner le mot lu", "Dans la bulle, le mot que dit la voix est mis en couleur, comme dans la fenêtre de Spoken. Seulement si « Highlight Words » est aussi coché dans les options de Spoken." },
    deDE = { "Gelesenes Wort hervorheben", "In der Sprechblase wird das Wort, das die Stimme gerade spricht, farbig hervorgehoben, wie im Fenster von Spoken. Nur wenn „Highlight Words“ auch in den Optionen von Spoken aktiviert ist." },
    esES = { "Resaltar la palabra leída", "En el bocadillo, la palabra que dice la voz se colorea, como en la ventana de Spoken. Solo si «Highlight Words» también está marcado en las opciones de Spoken." },
    esMX = { "Resaltar la palabra leída", "En el globo, la palabra que dice la voz se colorea, como en la ventana de Spoken. Solo si «Highlight Words» también está marcado en las opciones de Spoken." },
    itIT = { "Evidenzia la parola letta", "Nel fumetto, la parola che la voce sta dicendo viene colorata, come nella finestra di Spoken. Solo se «Highlight Words» è selezionato anche nelle opzioni di Spoken." },
    ptBR = { "Destacar a palavra lida", "No balão, a palavra que a voz está dizendo fica colorida, como na janela do Spoken. Só se «Highlight Words» também estiver marcado nas opções do Spoken." },
    ruRU = { "Подсвечивать читаемое слово", "В облачке слово, которое произносит голос, выделяется цветом, как в окне Spoken. Только если в настройках Spoken тоже включено «Highlight Words»." },
    koKR = { "읽는 단어 강조", "말풍선에서 목소리가 읽고 있는 단어에 색을 입힙니다. Spoken 창과 같습니다. Spoken 설정에서 「Highlight Words」도 켜져 있을 때만 작동합니다." },
    zhCN = { "高亮正在朗读的词", "在气泡中，为语音正在朗读的词着色，与 Spoken 的窗口相同。仅当 Spoken 选项中也勾选了「Highlight Words」时生效。" },
    zhTW = { "醒目標示正在朗讀的詞", "在對話泡泡中，為語音正在朗讀的詞上色，與 Spoken 的視窗相同。僅當 Spoken 選項中也勾選了「Highlight Words」時生效。" },
}) do if T[loc] then T[loc].BUBBLE_HIGHLIGHT, T[loc].BUBBLE_HIGHLIGHT_TIP = v[1], v[2] end end

-- Affichage de la bulle : ecriture progressive ou page entiere.
local BUBBLE_MODE = {
    enUS = { "Bubble display:", "Typewriter", "Whole page",
        "The text is written letter by letter, at the pace of the voice when a voice reads.",
        "Each page is shown at once. While a voice reads, the word it is saying is coloured, like Spoken's narrator, when \"Highlight the word being read\" is checked (and \"Highlight Words\" in Spoken's options)." },
    frFR = { "Affichage de la bulle :", "Écriture progressive", "Page entière",
        "Le texte s'écrit lettre par lettre, au rythme de la voix quand une voix lit.",
        "Chaque page s'affiche d'un coup. Quand une voix lit, le mot qu'elle dit est mis en couleur, comme le narrateur de Spoken, si « Surligner le mot lu » est coché (et « Highlight Words » dans les options de Spoken)." },
    deDE = { "Anzeige der Sprechblase:", "Schreibmaschine", "Ganze Seite",
        "Der Text wird Buchstabe für Buchstabe geschrieben, im Tempo der Stimme, wenn eine Stimme liest.",
        "Jede Seite wird auf einmal angezeigt. Während eine Stimme liest, wird das gesprochene Wort farbig hervorgehoben, wie beim Erzähler von Spoken, wenn „Gelesenes Wort hervorheben“ aktiviert ist (und „Highlight Words“ in den Optionen von Spoken)." },
    esES = { "Visualización del bocadillo:", "Escritura progresiva", "Página entera",
        "El texto se escribe letra a letra, al ritmo de la voz cuando lee una voz.",
        "Cada página se muestra de una vez. Mientras lee una voz, la palabra que dice se colorea, como el narrador de Spoken, si «Resaltar la palabra leída» está marcado (y «Highlight Words» en las opciones de Spoken)." },
    esMX = { "Visualización del globo:", "Escritura progresiva", "Página completa",
        "El texto se escribe letra por letra, al ritmo de la voz cuando lee una voz.",
        "Cada página se muestra de una vez. Mientras lee una voz, la palabra que dice se colorea, como el narrador de Spoken, si «Resaltar la palabra leída» está marcado (y «Highlight Words» en las opciones de Spoken)." },
    itIT = { "Visualizzazione del fumetto:", "Scrittura progressiva", "Pagina intera",
        "Il testo si scrive lettera per lettera, al ritmo della voce quando una voce legge.",
        "Ogni pagina appare subito. Mentre una voce legge, la parola che sta dicendo viene colorata, come il narratore di Spoken, se «Evidenzia la parola letta» è selezionato (e «Highlight Words» nelle opzioni di Spoken)." },
    ptBR = { "Exibição do balão:", "Escrita progressiva", "Página inteira",
        "O texto é escrito letra por letra, no ritmo da voz quando uma voz lê.",
        "Cada página aparece de uma vez. Enquanto uma voz lê, a palavra que ela diz fica colorida, como o narrador do Spoken, se «Destacar a palavra lida» estiver marcado (e «Highlight Words» nas opções do Spoken)." },
    ruRU = { "Показ облачка:", "Постепенно", "Вся страница",
        "Текст пишется по буквам, в темпе голоса, когда читает голос.",
        "Каждая страница показывается сразу. Пока читает голос, произносимое слово выделяется цветом, как у рассказчика Spoken, если включено «Подсвечивать читаемое слово» (и «Highlight Words» в настройках Spoken)." },
    koKR = { "말풍선 표시:", "한 글자씩", "페이지 전체",
        "글이 한 글자씩 써집니다. 목소리가 읽을 때는 목소리의 속도에 맞춥니다.",
        "각 페이지가 한 번에 표시됩니다. 목소리가 읽는 동안 읽고 있는 단어에 색을 입힙니다. Spoken의 내레이터와 같습니다. 「읽는 단어 강조」가 켜져 있을 때만 (Spoken 설정의 「Highlight Words」도 필요)." },
    zhCN = { "气泡显示：", "逐字显示", "整页显示",
        "文字逐字出现；有语音朗读时随语音的节奏。",
        "每页文字一次显示。语音朗读时，正在朗读的词会着色，与 Spoken 的旁白相同（需勾选「高亮正在朗读的词」，以及 Spoken 选项中的「Highlight Words」）。" },
    zhTW = { "泡泡顯示：", "逐字顯示", "整頁顯示",
        "文字逐字出現；有語音朗讀時隨語音的節奏。",
        "每頁文字一次顯示。語音朗讀時，正在朗讀的詞會上色，與 Spoken 的旁白相同（需勾選「醒目標示正在朗讀的詞」，以及 Spoken 選項中的「Highlight Words」）。" },
}
for loc, v in pairs(BUBBLE_MODE) do
    local dest = (loc == "enUS") and enUS or T[loc]
    if dest then
        dest.BUBBLE_MODE, dest.BUBBLE_MODE_TYPE, dest.BUBBLE_MODE_PAGE = v[1], v[2], v[3]
        dest.BUBBLE_MODE_TYPE_TIP, dest.BUBBLE_MODE_PAGE_TIP = v[4], v[5]
    end
end

-- Theme Personnalise : couleur du mot lu par la voix de Spoken (pastille, avec Spoken seulement).
local CUSTOM_WORD = {
    enUS = { "Word read", "Colour of the word the voice is saying in the bubble (Spoken). Right-click: automatic (gold on light text, dark red on dark text)." },
    frFR = { "Mot lu", "Couleur du mot que dit la voix dans la bulle (Spoken). Clic droit : automatique (or sur texte clair, rouge foncé sur texte sombre)." },
    deDE = { "Gelesenes Wort", "Farbe des Wortes, das die Stimme in der Sprechblase spricht (Spoken). Rechtsklick: automatisch (Gold auf hellem Text, Dunkelrot auf dunklem Text)." },
    esES = { "Palabra leída", "Color de la palabra que dice la voz en el bocadillo (Spoken). Clic derecho: automático (dorado sobre texto claro, rojo oscuro sobre texto oscuro)." },
    esMX = { "Palabra leída", "Color de la palabra que dice la voz en el globo (Spoken). Clic derecho: automático (dorado sobre texto claro, rojo oscuro sobre texto oscuro)." },
    itIT = { "Parola letta", "Colore della parola che la voce sta dicendo nel fumetto (Spoken). Clic destro: automatico (oro su testo chiaro, rosso scuro su testo scuro)." },
    ptBR = { "Palavra lida", "Cor da palavra que a voz está dizendo no balão (Spoken). Clique direito: automático (dourado em texto claro, vermelho escuro em texto escuro)." },
    ruRU = { "Читаемое слово", "Цвет слова, которое произносит голос в облачке (Spoken). Правый клик: автоматически (золотой на светлом тексте, тёмно-красный на тёмном)." },
    koKR = { "읽는 단어", "말풍선에서 목소리가 읽고 있는 단어의 색입니다 (Spoken). 오른쪽 클릭: 자동 (밝은 글자에는 금색, 어두운 글자에는 진한 빨강)." },
    zhCN = { "朗读的词", "气泡中语音正在朗读的词的颜色（Spoken）。右键：自动（浅色文字用金色，深色文字用深红色）。" },
    zhTW = { "朗讀的詞", "泡泡中語音正在朗讀的詞的顏色（Spoken）。右鍵：自動（淺色文字用金色，深色文字用深紅色）。" },
}
for loc, v in pairs(CUSTOM_WORD) do
    local dest = (loc == "enUS") and enUS or T[loc]
    if dest then dest.CUSTOM_WORD, dest.CUSTOM_WORD_TIP = v[1], v[2] end
end

-- Libelles courts des options (details dans l'infobulle de chaque case, cles *_TIP).
local SHORT = {
    enUS = { DEFAULTS_ALL_BTN = "Default all", PAGE_RESET_CONFIRM = "Reset the options of the page \"%s\" to their defaults?", DEFAULTS_BTN = "Defaults", PROFILE_COPY_FROM = "Copy settings from", PROFILE_DEL_ROW = "Delete profile", PROFILE_NEW_BTN = "New profile", PROFILE_FOR_NEW = "Profile for new characters", PROFILE_CLICK_TIP = "Pick with the arrows, then click to apply.", PROFILE_COPY_CONFIRM = "Copy the options of \"%s\" into this profile?", PROFILE_DEL_CONFIRM = "Delete the profile \"%s\"?\nCharacters using it go back to Main.", LOCK = "Lock windows", LOCK_TIP = "Prevents moving and resizing the wheel, the bubble and books.", ATTACH_NPC = "Wheel and bubble stick to the NPC", READ_MARKS = "Show if already read", READ_MARKS_TIP = "In the tooltip and in Spoken's queue.", BOOK_TIP_CURSOR = "Tooltip at the mouse", BOOK_TIP_CURSOR_TIP = "Instead of the corner of the screen.", BOOK_AUTOSCROLL = "Follow Spoken's voice", BOOK_AUTOSCROLL_TIP = "The text scrolls and the pages turn with the voice.", BOOK_TURN_FX = "Page-turn animation and sound", BOOK_VOICE_TURN = "Voice follows my pages", BOOK_STOP_CLOSE = "Stop the voice when closing a book", PLATE_STYLE = "Engraved plaques", FONT_SIZE = "Text size", HIDE_UI = "Hide UI while talking or reading", HIDE_UI_TIP = "During conversations and books.", PAD_USE = "Use the gamepad", QUEST_AUTO_W = "Automatic quest preview width", QUEST_AUTO_W_TIP = "Uncheck to set it with its grip.", THEME_BUBBLES = "Bubble above the NPC", THEME_BUBBLES_TIP = "Uncheck for a fixed frame.", WHEEL_THEME = "Theme on the wheel too", SPOKEN_THEME = "Theme on Spoken's player too", SPOKEN_BUTTON = "Bubble / Spoken button on the wheel", SPOKEN_BUTTON_TIP = "Switches between the bubble and Spoken's player.", KEY_TOGGLE = "Bubble / Spoken key:", ZONE_ART = "Area pictures (Spoken)", ZONE_ART_TIP = "In Spoken's small window.", ZONE_ART_PAPER = "Painted paper edge", PROFILE_FACTORY_NOTE = "The Defaults profile keeps no changes." },
    frFR = { DEFAULTS_ALL_BTN = "Tout par défaut", PAGE_RESET_CONFIRM = "Remettre par défaut les options de la page « %s » ?", DEFAULTS_BTN = "Par défaut", PROFILE_COPY_FROM = "Copier les réglages de", PROFILE_DEL_ROW = "Supprimer un profil", PROFILE_NEW_BTN = "Nouveau profil", PROFILE_FOR_NEW = "Profil des nouveaux personnages", PROFILE_CLICK_TIP = "Choisissez avec les flèches, puis cliquez pour appliquer.", PROFILE_COPY_CONFIRM = "Copier les options de « %s » dans ce profil ?", PROFILE_DEL_CONFIRM = "Supprimer le profil « %s » ?\nLes personnages qui l'utilisent reviennent au profil Principal.", LOCK = "Verrouiller les fenêtres", LOCK_TIP = "Empêche de déplacer et de redimensionner la roue, la bulle et les livres.", ATTACH_NPC = "La roue et la bulle restent collées au PNJ", READ_MARKS = "Indiquer si déjà lu", READ_MARKS_TIP = "Dans l'infobulle et dans la file de Spoken.", BOOK_TIP_CURSOR = "Infobulle à la souris", BOOK_TIP_CURSOR_TIP = "Au lieu du coin de l'écran.", BOOK_AUTOSCROLL = "Suivre la voix de Spoken", BOOK_AUTOSCROLL_TIP = "Le texte défile et les pages tournent avec la voix.", BOOK_TURN_FX = "Animation et son des pages", BOOK_VOICE_TURN = "La voix suit mes pages", BOOK_STOP_CLOSE = "Couper la voix en fermant un livre", PLATE_STYLE = "Plaques gravées", FONT_SIZE = "Taille du texte", HIDE_UI = "Cacher l'interface en dialogue et en lecture", HIDE_UI_TIP = "Pendant les dialogues et les livres.", PAD_USE = "Utiliser la manette", QUEST_AUTO_W = "Largeur auto de l'aperçu de quête", QUEST_AUTO_W_TIP = "Décocher pour la régler avec sa poignée.", THEME_BUBBLES = "Bulle au-dessus du PNJ", THEME_BUBBLES_TIP = "Décocher : cadre fixe.", WHEEL_THEME = "Thème aussi sur la roue", SPOKEN_THEME = "Thème aussi sur le lecteur Spoken", SPOKEN_BUTTON = "Bouton bulle / Spoken sur la roue", SPOKEN_BUTTON_TIP = "Bascule entre la bulle et le lecteur de Spoken.", KEY_TOGGLE = "Touche bulle / Spoken :", ZONE_ART = "Illustrations des lieux (Spoken)", ZONE_ART_TIP = "Dans la petite fenêtre de Spoken.", ZONE_ART_PAPER = "Bord de papier peint", PROFILE_FACTORY_NOTE = "Le profil Par défaut ne garde aucun changement." },
    deDE = { DEFAULTS_ALL_BTN = "Alles zurücksetzen", PAGE_RESET_CONFIRM = "Die Optionen der Seite „%s“ auf die Standardwerte zurücksetzen?", DEFAULTS_BTN = "Standard", PROFILE_COPY_FROM = "Einstellungen kopieren von", PROFILE_DEL_ROW = "Profil löschen", PROFILE_NEW_BTN = "Neues Profil", PROFILE_FOR_NEW = "Profil für neue Charaktere", PROFILE_CLICK_TIP = "Mit den Pfeilen wählen, dann klicken.", PROFILE_COPY_CONFIRM = "Die Optionen von „%s“ in dieses Profil kopieren?", PROFILE_DEL_CONFIRM = "Das Profil „%s“ löschen?\nCharaktere, die es nutzen, kehren zu Haupt zurück.", LOCK = "Fenster sperren", LOCK_TIP = "Verhindert das Verschieben und Ändern der Größe von Rad, Sprechblase und Büchern.", ATTACH_NPC = "Rad und Sprechblase bleiben am NPC", READ_MARKS = "Anzeigen, ob schon gelesen", READ_MARKS_TIP = "Im Tooltip und in Spokens Warteschlange.", BOOK_TIP_CURSOR = "Tooltip an der Maus", BOOK_TIP_CURSOR_TIP = "Statt in der Bildschirmecke.", BOOK_AUTOSCROLL = "Spokens Stimme folgen", BOOK_AUTOSCROLL_TIP = "Der Text scrollt und die Seiten blättern mit der Stimme.", BOOK_TURN_FX = "Animation und Geräusch beim Umblättern", BOOK_VOICE_TURN = "Stimme folgt meinen Seiten", BOOK_STOP_CLOSE = "Stimme beim Schließen eines Buches stoppen", PLATE_STYLE = "Gravierte Tafeln", FONT_SIZE = "Textgröße", HIDE_UI = "Oberfläche beim Sprechen und Lesen ausblenden", HIDE_UI_TIP = "Während Gesprächen und Büchern.", PAD_USE = "Gamepad verwenden", QUEST_AUTO_W = "Automatische Breite der Questvorschau", QUEST_AUTO_W_TIP = "Abwählen, um sie mit dem Griff einzustellen.", THEME_BUBBLES = "Sprechblase über dem NPC", THEME_BUBBLES_TIP = "Abwählen für einen festen Rahmen.", WHEEL_THEME = "Thema auch auf dem Rad", SPOKEN_THEME = "Thema auch auf Spokens Player", SPOKEN_BUTTON = "Knopf Sprechblase / Spoken am Rad", SPOKEN_BUTTON_TIP = "Wechselt zwischen Sprechblase und Spokens Player.", KEY_TOGGLE = "Taste Sprechblase / Spoken:", ZONE_ART = "Ortsbilder (Spoken)", ZONE_ART_TIP = "Im kleinen Fenster von Spoken.", ZONE_ART_PAPER = "Bemalter Papierrand", PROFILE_FACTORY_NOTE = "Das Profil Standard speichert keine Änderungen." },
    esES = { DEFAULTS_ALL_BTN = "Restablecer todo", PAGE_RESET_CONFIRM = "¿Restablecer las opciones de la página «%s»?", DEFAULTS_BTN = "Predeterminado", PROFILE_COPY_FROM = "Copiar ajustes de", PROFILE_DEL_ROW = "Borrar perfil", PROFILE_NEW_BTN = "Nuevo perfil", PROFILE_FOR_NEW = "Perfil para personajes nuevos", PROFILE_CLICK_TIP = "Elige con las flechas y haz clic para aplicar.", PROFILE_COPY_CONFIRM = "¿Copiar las opciones de «%s» en este perfil?", PROFILE_DEL_CONFIRM = "¿Borrar el perfil «%s»?\nLos personajes que lo usan vuelven al perfil Principal.", LOCK = "Bloquear ventanas", LOCK_TIP = "Impide mover y cambiar el tamaño de la rueda, el bocadillo y los libros.", ATTACH_NPC = "La rueda y el bocadillo se pegan al PNJ", READ_MARKS = "Indicar si ya se leyó", READ_MARKS_TIP = "En la descripción emergente y en la cola de Spoken.", BOOK_TIP_CURSOR = "Descripción junto al ratón", BOOK_TIP_CURSOR_TIP = "En lugar de la esquina de la pantalla.", BOOK_AUTOSCROLL = "Seguir la voz de Spoken", BOOK_AUTOSCROLL_TIP = "El texto se desplaza y las páginas pasan con la voz.", BOOK_TURN_FX = "Animación y sonido de las páginas", BOOK_VOICE_TURN = "La voz sigue mis páginas", BOOK_STOP_CLOSE = "Detener la voz al cerrar un libro", PLATE_STYLE = "Placas grabadas", FONT_SIZE = "Tamaño del texto", HIDE_UI = "Ocultar la interfaz al hablar o leer", HIDE_UI_TIP = "Durante las conversaciones y los libros.", PAD_USE = "Usar el mando", QUEST_AUTO_W = "Ancho automático de la vista previa de misión", QUEST_AUTO_W_TIP = "Desmarca para ajustarlo con su asa.", THEME_BUBBLES = "Bocadillo sobre el PNJ", THEME_BUBBLES_TIP = "Desmarca para un marco fijo.", WHEEL_THEME = "Tema también en la rueda", SPOKEN_THEME = "Tema también en el reproductor de Spoken", SPOKEN_BUTTON = "Botón bocadillo / Spoken en la rueda", SPOKEN_BUTTON_TIP = "Alterna entre el bocadillo y el reproductor de Spoken.", KEY_TOGGLE = "Tecla bocadillo / Spoken:", ZONE_ART = "Imágenes de lugares (Spoken)", ZONE_ART_TIP = "En la ventana pequeña de Spoken.", ZONE_ART_PAPER = "Borde de papel pintado", PROFILE_FACTORY_NOTE = "El perfil Predeterminado no guarda cambios." },
    itIT = { DEFAULTS_ALL_BTN = "Ripristina tutto", PAGE_RESET_CONFIRM = "Ripristinare le opzioni della pagina «%s»?", DEFAULTS_BTN = "Predefinite", PROFILE_COPY_FROM = "Copia impostazioni da", PROFILE_DEL_ROW = "Elimina profilo", PROFILE_NEW_BTN = "Nuovo profilo", PROFILE_FOR_NEW = "Profilo per i nuovi personaggi", PROFILE_CLICK_TIP = "Scegli con le frecce, poi clicca per applicare.", PROFILE_COPY_CONFIRM = "Copiare le opzioni di «%s» in questo profilo?", PROFILE_DEL_CONFIRM = "Eliminare il profilo «%s»?\nI personaggi che lo usano tornano al profilo Principale.", LOCK = "Blocca le finestre", LOCK_TIP = "Impedisce di spostare e ridimensionare la ruota, il fumetto e i libri.", ATTACH_NPC = "Ruota e fumetto restano attaccati al PNG", READ_MARKS = "Indica se già letto", READ_MARKS_TIP = "Nella descrizione e nella coda di Spoken.", BOOK_TIP_CURSOR = "Descrizione vicino al mouse", BOOK_TIP_CURSOR_TIP = "Invece che nell'angolo dello schermo.", BOOK_AUTOSCROLL = "Segui la voce di Spoken", BOOK_AUTOSCROLL_TIP = "Il testo scorre e le pagine girano con la voce.", BOOK_TURN_FX = "Animazione e suono delle pagine", BOOK_VOICE_TURN = "La voce segue le mie pagine", BOOK_STOP_CLOSE = "Ferma la voce chiudendo un libro", PLATE_STYLE = "Targhe incise", FONT_SIZE = "Dimensione del testo", HIDE_UI = "Nascondi l'interfaccia in dialogo e lettura", HIDE_UI_TIP = "Durante dialoghi e libri.", PAD_USE = "Usa il controller", QUEST_AUTO_W = "Larghezza automatica dell'anteprima missione", QUEST_AUTO_W_TIP = "Deseleziona per regolarla con la maniglia.", THEME_BUBBLES = "Fumetto sopra il PNG", THEME_BUBBLES_TIP = "Deseleziona per una cornice fissa.", WHEEL_THEME = "Tema anche sulla ruota", SPOKEN_THEME = "Tema anche sul lettore di Spoken", SPOKEN_BUTTON = "Pulsante fumetto / Spoken sulla ruota", SPOKEN_BUTTON_TIP = "Passa dal fumetto al lettore di Spoken.", KEY_TOGGLE = "Tasto fumetto / Spoken:", ZONE_ART = "Immagini dei luoghi (Spoken)", ZONE_ART_TIP = "Nella finestra piccola di Spoken.", ZONE_ART_PAPER = "Bordo di carta dipinta", PROFILE_FACTORY_NOTE = "Il profilo Predefinito non salva modifiche." },
    ptBR = { DEFAULTS_ALL_BTN = "Redefinir tudo", PAGE_RESET_CONFIRM = "Redefinir as opções da página «%s»?", DEFAULTS_BTN = "Padrão", PROFILE_COPY_FROM = "Copiar configurações de", PROFILE_DEL_ROW = "Excluir perfil", PROFILE_NEW_BTN = "Novo perfil", PROFILE_FOR_NEW = "Perfil para novos personagens", PROFILE_CLICK_TIP = "Escolha com as setas e clique para aplicar.", PROFILE_COPY_CONFIRM = "Copiar as opções de «%s» para este perfil?", PROFILE_DEL_CONFIRM = "Excluir o perfil «%s»?\nOs personagens que o usam voltam ao perfil Principal.", LOCK = "Travar janelas", LOCK_TIP = "Impede mover e redimensionar a roda, o balão e os livros.", ATTACH_NPC = "Roda e balão ficam presos ao NPC", READ_MARKS = "Indicar se já foi lido", READ_MARKS_TIP = "Na dica e na fila do Spoken.", BOOK_TIP_CURSOR = "Dica junto ao mouse", BOOK_TIP_CURSOR_TIP = "Em vez do canto da tela.", BOOK_AUTOSCROLL = "Seguir a voz do Spoken", BOOK_AUTOSCROLL_TIP = "O texto rola e as páginas viram com a voz.", BOOK_TURN_FX = "Animação e som das páginas", BOOK_VOICE_TURN = "A voz segue minhas páginas", BOOK_STOP_CLOSE = "Parar a voz ao fechar um livro", PLATE_STYLE = "Placas gravadas", FONT_SIZE = "Tamanho do texto", HIDE_UI = "Esconder a interface ao conversar ou ler", HIDE_UI_TIP = "Durante conversas e livros.", PAD_USE = "Usar o controle", QUEST_AUTO_W = "Largura automática da prévia da missão", QUEST_AUTO_W_TIP = "Desmarque para ajustá-la com a alça.", THEME_BUBBLES = "Balão sobre o NPC", THEME_BUBBLES_TIP = "Desmarque para um quadro fixo.", WHEEL_THEME = "Tema também na roda", SPOKEN_THEME = "Tema também no reprodutor do Spoken", SPOKEN_BUTTON = "Botão balão / Spoken na roda", SPOKEN_BUTTON_TIP = "Alterna entre o balão e o reprodutor do Spoken.", KEY_TOGGLE = "Tecla balão / Spoken:", ZONE_ART = "Imagens dos lugares (Spoken)", ZONE_ART_TIP = "Na janela pequena do Spoken.", ZONE_ART_PAPER = "Borda de papel pintado", PROFILE_FACTORY_NOTE = "O perfil Padrão não guarda alterações." },
    ruRU = { DEFAULTS_ALL_BTN = "Сбросить всё", PAGE_RESET_CONFIRM = "Сбросить настройки страницы «%s»?", DEFAULTS_BTN = "По умолчанию", PROFILE_COPY_FROM = "Скопировать настройки из", PROFILE_DEL_ROW = "Удалить профиль", PROFILE_NEW_BTN = "Новый профиль", PROFILE_FOR_NEW = "Профиль для новых персонажей", PROFILE_CLICK_TIP = "Выберите стрелками, затем нажмите, чтобы применить.", PROFILE_COPY_CONFIRM = "Скопировать настройки «%s» в этот профиль?", PROFILE_DEL_CONFIRM = "Удалить профиль «%s»?\nПерсонажи с ним вернутся к профилю «Основной».", LOCK = "Закрепить окна", LOCK_TIP = "Запрещает перемещать и менять размер колеса, облачка и книг.", ATTACH_NPC = "Колесо и облачко держатся у NPC", READ_MARKS = "Показывать, прочитано ли", READ_MARKS_TIP = "В подсказке и в очереди Spoken.", BOOK_TIP_CURSOR = "Подсказка у курсора", BOOK_TIP_CURSOR_TIP = "Вместо угла экрана.", BOOK_AUTOSCROLL = "Следовать за голосом Spoken", BOOK_AUTOSCROLL_TIP = "Текст прокручивается и страницы листаются вместе с голосом.", BOOK_TURN_FX = "Анимация и звук страниц", BOOK_VOICE_TURN = "Голос следует за моими страницами", BOOK_STOP_CLOSE = "Останавливать голос при закрытии книги", PLATE_STYLE = "Гравированные таблички", FONT_SIZE = "Размер текста", HIDE_UI = "Скрывать интерфейс в разговорах и при чтении", HIDE_UI_TIP = "Во время разговоров и чтения книг.", PAD_USE = "Использовать геймпад", QUEST_AUTO_W = "Автоширина обзора задания", QUEST_AUTO_W_TIP = "Снимите, чтобы задать её ручкой.", THEME_BUBBLES = "Облачко над NPC", THEME_BUBBLES_TIP = "Снимите для фиксированной рамки.", WHEEL_THEME = "Тема и для колеса", SPOKEN_THEME = "Тема и для плеера Spoken", SPOKEN_BUTTON = "Кнопка облачко / Spoken на колесе", SPOKEN_BUTTON_TIP = "Переключает между облачком и плеером Spoken.", KEY_TOGGLE = "Клавиша облачко / Spoken:", ZONE_ART = "Картинки мест (Spoken)", ZONE_ART_TIP = "В маленьком окне Spoken.", ZONE_ART_PAPER = "Край расписной бумаги", PROFILE_FACTORY_NOTE = "Профиль «По умолчанию» не сохраняет изменений." },
    koKR = { DEFAULTS_ALL_BTN = "모두 기본값", PAGE_RESET_CONFIRM = "「%s」 페이지의 설정을 기본값으로 되돌릴까요?", DEFAULTS_BTN = "기본값", PROFILE_COPY_FROM = "설정 복사해 올 프로필", PROFILE_DEL_ROW = "프로필 삭제", PROFILE_NEW_BTN = "새 프로필", PROFILE_FOR_NEW = "새 캐릭터용 프로필", PROFILE_CLICK_TIP = "화살표로 고른 뒤 클릭해 적용하세요.", PROFILE_COPY_CONFIRM = "「%s」의 설정을 이 프로필로 복사할까요?", PROFILE_DEL_CONFIRM = "「%s」 프로필을 삭제할까요?\n이 프로필을 쓰던 캐릭터는 기본 프로필로 돌아갑니다.", LOCK = "창 잠금", LOCK_TIP = "휠, 말풍선, 책을 옮기거나 크기를 바꿀 수 없게 합니다.", ATTACH_NPC = "휠과 말풍선이 NPC에 붙어 다님", READ_MARKS = "읽음 여부 표시", READ_MARKS_TIP = "툴팁과 Spoken 대기열에 표시합니다.", BOOK_TIP_CURSOR = "마우스 옆 툴팁", BOOK_TIP_CURSOR_TIP = "화면 모서리 대신 표시합니다.", BOOK_AUTOSCROLL = "Spoken 목소리 따라가기", BOOK_AUTOSCROLL_TIP = "목소리에 맞춰 글이 스크롤되고 페이지가 넘어갑니다.", BOOK_TURN_FX = "페이지 애니메이션과 소리", BOOK_VOICE_TURN = "목소리가 내 페이지를 따라감", BOOK_STOP_CLOSE = "책을 닫으면 목소리 멈추기", PLATE_STYLE = "새겨진 명판", FONT_SIZE = "글자 크기", HIDE_UI = "대화와 읽기 중 UI 숨기기", HIDE_UI_TIP = "대화와 책을 읽는 동안.", PAD_USE = "게임패드 사용", QUEST_AUTO_W = "퀘스트 미리보기 너비 자동", QUEST_AUTO_W_TIP = "해제하면 손잡이로 조절합니다.", THEME_BUBBLES = "NPC 위 말풍선", THEME_BUBBLES_TIP = "해제하면 고정 창으로 표시합니다.", WHEEL_THEME = "휠에도 테마 적용", SPOKEN_THEME = "Spoken 플레이어에도 테마 적용", SPOKEN_BUTTON = "휠에 말풍선 / Spoken 버튼", SPOKEN_BUTTON_TIP = "말풍선과 Spoken 플레이어를 전환합니다.", KEY_TOGGLE = "말풍선 / Spoken 키:", ZONE_ART = "장소 그림 (Spoken)", ZONE_ART_TIP = "Spoken의 작은 창에 표시합니다.", ZONE_ART_PAPER = "그림 종이 테두리", PROFILE_FACTORY_NOTE = "기본값 프로필은 변경 사항을 저장하지 않습니다." },
    zhCN = { DEFAULTS_ALL_BTN = "全部恢复默认", PAGE_RESET_CONFIRM = "将「%s」页面的选项恢复为默认？", DEFAULTS_BTN = "默认", PROFILE_COPY_FROM = "复制设置自", PROFILE_DEL_ROW = "删除配置文件", PROFILE_NEW_BTN = "新建配置文件", PROFILE_FOR_NEW = "新角色的配置文件", PROFILE_CLICK_TIP = "用箭头选择，然后点击应用。", PROFILE_COPY_CONFIRM = "将「%s」的选项复制到此配置文件？", PROFILE_DEL_CONFIRM = "删除配置文件「%s」？\n使用它的角色将恢复为主配置。", LOCK = "锁定窗口", LOCK_TIP = "防止移动和调整选项轮、气泡和书本的大小。", ATTACH_NPC = "选项轮和气泡跟随 NPC", READ_MARKS = "显示是否已读", READ_MARKS_TIP = "在鼠标提示和 Spoken 队列中显示。", BOOK_TIP_CURSOR = "鼠标旁显示提示", BOOK_TIP_CURSOR_TIP = "而非屏幕角落。", BOOK_AUTOSCROLL = "跟随 Spoken 的声音", BOOK_AUTOSCROLL_TIP = "文字随声音滚动、翻页。", BOOK_TURN_FX = "翻页动画与音效", BOOK_VOICE_TURN = "声音跟随我翻的页", BOOK_STOP_CLOSE = "关闭书本时停止朗读", PLATE_STYLE = "刻字铭牌", FONT_SIZE = "文字大小", HIDE_UI = "对话和阅读时隐藏界面", HIDE_UI_TIP = "在对话和阅读书籍时。", PAD_USE = "使用手柄", QUEST_AUTO_W = "任务预览宽度自动", QUEST_AUTO_W_TIP = "取消勾选可用拖柄调整。", THEME_BUBBLES = "NPC 头顶气泡", THEME_BUBBLES_TIP = "取消勾选则为固定框。", WHEEL_THEME = "选项轮也用此主题", SPOKEN_THEME = "Spoken 播放器也用此主题", SPOKEN_BUTTON = "选项轮上的气泡 / Spoken 按钮", SPOKEN_BUTTON_TIP = "在气泡与 Spoken 播放器之间切换。", KEY_TOGGLE = "气泡 / Spoken 切换键：", ZONE_ART = "地点插图（Spoken）", ZONE_ART_TIP = "显示在 Spoken 的小窗口中。", ZONE_ART_PAPER = "彩绘纸边", PROFILE_FACTORY_NOTE = "默认配置不保存任何更改。" },
    zhTW = { DEFAULTS_ALL_BTN = "全部恢復預設", PAGE_RESET_CONFIRM = "將「%s」頁面的選項恢復為預設？", DEFAULTS_BTN = "預設", PROFILE_COPY_FROM = "複製設定自", PROFILE_DEL_ROW = "刪除設定檔", PROFILE_NEW_BTN = "新增設定檔", PROFILE_FOR_NEW = "新角色的設定檔", PROFILE_CLICK_TIP = "用箭頭選擇，然後點擊套用。", PROFILE_COPY_CONFIRM = "將「%s」的選項複製到此設定檔？", PROFILE_DEL_CONFIRM = "刪除設定檔「%s」？\n使用它的角色將回到主設定檔。", LOCK = "鎖定視窗", LOCK_TIP = "防止移動和調整選項輪、氣泡和書本的大小。", ATTACH_NPC = "選項輪和氣泡跟隨 NPC", READ_MARKS = "顯示是否已讀", READ_MARKS_TIP = "在滑鼠提示與 Spoken 佇列中顯示。", BOOK_TIP_CURSOR = "滑鼠旁顯示提示", BOOK_TIP_CURSOR_TIP = "而非螢幕角落。", BOOK_AUTOSCROLL = "跟隨 Spoken 的聲音", BOOK_AUTOSCROLL_TIP = "文字隨聲音捲動、翻頁。", BOOK_TURN_FX = "翻頁動畫與音效", BOOK_VOICE_TURN = "聲音跟隨我翻的頁", BOOK_STOP_CLOSE = "關閉書本時停止朗讀", PLATE_STYLE = "刻字銘牌", FONT_SIZE = "文字大小", HIDE_UI = "對話與閱讀時隱藏介面", HIDE_UI_TIP = "在對話與閱讀書籍時。", PAD_USE = "使用手把", QUEST_AUTO_W = "任務預覽寬度自動", QUEST_AUTO_W_TIP = "取消勾選可用拖柄調整。", THEME_BUBBLES = "NPC 頭頂氣泡", THEME_BUBBLES_TIP = "取消勾選則為固定框。", WHEEL_THEME = "選項輪也用此主題", SPOKEN_THEME = "Spoken 播放器也用此主題", SPOKEN_BUTTON = "選項輪上的氣泡 / Spoken 按鈕", SPOKEN_BUTTON_TIP = "在氣泡與 Spoken 播放器之間切換。", KEY_TOGGLE = "氣泡 / Spoken 切換鍵：", ZONE_ART = "地點插圖（Spoken）", ZONE_ART_TIP = "顯示在 Spoken 的小視窗中。", ZONE_ART_PAPER = "彩繪紙邊", PROFILE_FACTORY_NOTE = "預設設定檔不保存任何變更。" },
}
SHORT.esMX = SHORT.esES
for loc, list in pairs(SHORT) do
    local dest = (loc == "enUS") and enUS or T[loc]
    if dest then for k, v in pairs(list) do dest[k] = v end end
end

local own = T[LOCALE] or {}
DWE.L = setmetatable({}, { __index = function(_, k)
    return GAME[k] or own[k] or enUS[k]
end })
