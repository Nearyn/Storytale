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
    NO_TEXT = "(No text available)",
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
    NO_TEXT = "(Aucun texte disponible)",
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
    NO_TEXT = "(Kein Text verfügbar)",
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
    NO_TEXT = "(Sin texto disponible)",
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
    NO_TEXT = "(Nessun testo disponibile)",
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
    NO_TEXT = "(Nenhum texto disponível)",
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
    NO_TEXT = "(Нет текста)",
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
    NO_TEXT = "(텍스트 없음)",
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
    NO_TEXT = "（无文本）",
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
    NO_TEXT = "（無文字）",
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
        BOOK_DUI = "DialogueUI book", BOOK_BLIZZ = "Game window" },
    frFR = { SEC_THEME = "Thème", SEC_TEXT = "Texte", SEC_PLACE = "Placement", SEC_KEYS = "Commandes",
        THEME_HINT = "Cliquez sur un thème pour l'appliquer.", FONT_FAMILY = "Police", FONT_SIZE = "Taille du texte",
        OPACITY_LBL = "Opacité du cadre", WHEEL_THEME = "Habiller aussi la roue des choix",
        SPOKEN_THEME = "Habiller aussi le lecteur Spoken", ATTACH_NPC = "Suivre le PNJ à l'écran",
        ATTACH_TIP = "Clic droit maintenu sur la roue ou le texte pour les déplacer.", LOCK = "Verrouiller les cadres",
        NPC_RESET = "Réinitialiser position et taille", KEY_USE_BLIZZ = "Utiliser la touche « Interagir » du jeu",
        KEY_TOGGLE = "Touche « Dialogue » :", ESC_CLOSE = "Échap termine la conversation",
        WHEEL_SCROLL = "La molette parcourt les choix (clic maintenu : zoom)",
        BOOK_STYLE = "Livres et lettres :", BOOK_ADDON = "Cet addon, avec un thème parchemin (Vélin doré si un thème bulle est choisi)",
        BOOK_DUI = "Livre de DialogueUI", BOOK_BLIZZ = "Fenêtre du jeu" },
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
    enUS = { SEC_THEME = "Appearance", SEC_BOOKS = "Books and letters", SEC_SPOKEN = "Spoken",
        THEME_BUBBLES = "Show the theme as a bubble above the NPC (uncheck for a fixed frame)",
        WHEEL_THEME = "Also apply the theme to the choice wheel",
        SPOKEN_THEME = "Also apply the theme to Spoken's player",
        OPACITY_LBL = "Background opacity",
        FONT_SIZE = "Text size (bubble, frame, books)", CHOICE_SIZE = "Choice size",
        BOOK_STYLE = "Who displays books and letters:",
        SPOKEN_CHOICE = "Show a \"Spoken\" choice in the wheel",
        KEY_TOGGLE = "Key to switch between the bubble and Spoken's player:",
        SPOKEN_NEEDED = "Requires the Spoken addon.",
        SPOKEN_KEY_HINT = "Turn on the \"Spoken\" choice above to use this key.",
        RESET_ALL = "Reset all options",
        RESET_ALL_CONFIRM = "Reset all Storytale options to their defaults?\nThe interface will reload." },
    frFR = { SEC_THEME = "Apparence", SEC_BOOKS = "Livres et lettres", SEC_SPOKEN = "Spoken",
        THEME_BUBBLES = "Afficher le thème en bulle au-dessus du PNJ (décocher : cadre fixe)",
        WHEEL_THEME = "Appliquer aussi le thème à la roue des choix",
        SPOKEN_THEME = "Appliquer aussi le thème au lecteur de Spoken",
        OPACITY_LBL = "Opacité du fond",
        FONT_SIZE = "Taille du texte (bulle, cadre, livres)", CHOICE_SIZE = "Taille des choix",
        BOOK_STYLE = "Qui affiche les livres et lettres :",
        SPOKEN_CHOICE = "Afficher un choix « Spoken » dans la roue",
        KEY_TOGGLE = "Touche pour basculer entre la bulle et le lecteur de Spoken :",
        SPOKEN_NEEDED = "Nécessite l'addon Spoken.",
        SPOKEN_KEY_HINT = "Active le choix « Spoken » ci-dessus pour utiliser cette touche.",
        RESET_ALL = "Réinitialiser toutes les options",
        RESET_ALL_CONFIRM = "Remettre toutes les options de Storytale par défaut ?\nL'interface va se recharger." },
}
for loc, list in pairs(OPTS2) do
    local dest = (loc == "enUS") and enUS or T[loc]
    if dest then for k, v in pairs(list) do dest[k] = v end end
end

local own = T[LOCALE] or {}
DWE.L = setmetatable({}, { __index = function(_, k)
    return GAME[k] or own[k] or enUS[k]
end })
