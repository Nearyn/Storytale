# Changelog / Journal des versions

## 1.3.9

**🇬🇧 English**

### New
- **Words highlighted as Spoken reads** in the open book, the single page and plaques, like Spoken's captions (follows Spoken's "Highlight Words" setting). The title read before the text no longer lights the first words.
- **Follow the voice** (on by default): the single page scrolls with the narration and the open book turns its pages by itself. Scroll or turn a page yourself and it pauses, then resumes.
- **Page turning**: an animation and the game's page sound when a page of the open book turns (option, on by default).
- **Reading options at hand**, without leaving the book: a fabric bookmark in the open book, the scribe's signature on the single page (one of 8, always the same for a given text) and an engraved triquetra on plaques. Click it to unroll: read aloud, follow the voice, highlight, page animation. It glows on hover and pulses once the first time.
- **Mouse wheel** on the open book turns the pages.
- **/storytale errors**: Storytale keeps track of its own Lua errors (count, where) and stops a part that keeps failing, so nothing piles up. A single chat message tells you if anything went wrong.
- All new options translated into every game language.

### Improved
- Spoken's mini player no longer fades out and back in between two pages of the same book, and no longer highlights words while a book's title is read.
- The bottom bar of books now only shows previous page, next page and close.
- The title of the single page has the same colour as the open book's.

### Fixed
- The page number of the open book no longer stays on the single page.

---

**🇫🇷 Français**

### Nouveautés
- **Mots surlignés pendant la lecture de Spoken** dans le livre ouvert, la page seule et les plaques, comme dans les sous-titres de Spoken (suit son réglage « Surligner les mots »). Le titre lu avant le texte n'allume plus les premiers mots.
- **Suivre la voix** (activé par défaut) : la page seule défile avec la narration et le livre ouvert tourne ses pages tout seul. Défilez ou tournez une page vous-même : il fait une pause, puis reprend.
- **Pages qui tournent** : une animation et le bruit de page du jeu quand une page du livre ouvert tourne (option, activée par défaut).
- **Réglages de lecture à portée de main**, sans quitter le livre : un marque-page en tissu dans le livre ouvert, la signature du scribe sur la page seule (une parmi 8, toujours la même pour un texte donné) et une triquetra gravée sur les plaques. Un clic déroule : lecture à voix haute, suivre la voix, surbrillance, animation des pages. Il s'illumine au survol et pulse une fois la première fois.
- **Molette de la souris** sur le livre ouvert : tourne les pages.
- **/storytale errors** : Storytale garde la trace de ses propres erreurs Lua (combien, où) et coupe une partie qui échoue en boucle, pour que rien ne s'accumule. Un seul message dans le chat prévient en cas de problème.
- Toutes les nouvelles options traduites dans toutes les langues du jeu.

### Améliorations
- Le petit lecteur de Spoken ne s'efface plus pour revenir entre deux pages d'un même livre, et ne surligne plus de mots pendant la lecture du titre d'un livre.
- La barre du bas des livres ne montre plus que page précédente, page suivante et fermer.
- Le titre de la page seule a la même couleur que celui du livre ouvert.

### Corrections
- Le numéro de page du livre ouvert ne reste plus affiché sur la page seule.

## 1.3.8

**🇬🇧 English**

### New
- **Smart reading queue** (Spoken section, on by default): Storytale decides who speaks first. Uncheck it to let Spoken manage its queue on its own, untouched.
- Dialogue pages you ask for (a topic chosen after the greeting) now wait their turn instead of being dropped.

### Fixed
- Talking to another NPC now switches greetings right away, including the greeting of a quest giver.
- An NPC's greeting waits for the end of a quest line that has already started, then plays.
- The quest line of an NPC you left before Spoken started reading it is skipped, so the next NPC speaks at once.
- A greeting or quest page Spoken forgot to read when switching NPCs quickly is now read.

---

**🇫🇷 Français**

### Nouveautés
- **File de lecture intelligente** (section Spoken, activée par défaut) : Storytale décide qui parle en premier. Décochez-la pour laisser Spoken gérer seul sa file, sans aucune modification.
- Les pages de dialogue demandées (un sujet choisi après la salutation) attendent leur tour au lieu d'être ignorées.

### Corrections
- Parler à un autre PNJ fait passer sa salutation tout de suite, y compris celle d'un donneur de quêtes.
- La salutation d'un PNJ attend la fin d'une ligne de quête déjà commencée, puis se lance.
- La ligne de quête d'un PNJ quitté avant que Spoken commence à la lire est ignorée : le PNJ suivant parle tout de suite.
- Une salutation ou une page de quête que Spoken oubliait de lire quand on change vite de PNJ est maintenant lue.

## 1.3.7

**🇬🇧 English**

### Fixed
- Spoken's player stays visible during a conversation when the voice playing belongs to another NPC (it only hides to avoid showing the same line twice).
- A quest text is never cut, even if already heard: it plays to the end, then the next one.
- Spoken's player no longer disappears for a moment when you close a conversation.

---

**🇫🇷 Français**

### Corrections
- Le lecteur Spoken reste visible pendant une conversation quand la voix en cours est celle d'un autre PNJ (il ne se cache que pour éviter d'afficher deux fois la même réplique).
- Un texte de quête n'est jamais coupé, même déjà écouté : il va jusqu'au bout, puis le suivant.
- Le lecteur Spoken ne disparaît plus un instant à la fermeture d'une conversation.

## 1.3.6

**🇬🇧 English**

### New
- **Quest preview width**: fits its content by default (centred under the choices when short, wider for long objectives). Uncheck the option to set it yourself with its own grip (mirrored when the wheel is on the left).
- **Spoken dialogue priority**: a quest text always plays before an NPC's greeting and is never cut by one; greetings are never queued.
- **Zone narration window** (Spoken): its own skin — current theme, single page or DialogueUI.
- The tooltip of books and plaques now follows the mouse by default.
- All new options translated into every game language.

### Improved
- Book tooltips update live, vanish as soon as the mouse leaves and no longer flicker.
- With Spoken, a book still being read keeps the "I am reading this tale..." label after you close it.
- The quest preview box has no dialogue tail, sits a little lower and is darker, so it no longer looks like a choice.

### Fixed
- An NPC could show the quest text of the previous NPC.
- The bubble no longer waits for a voice that belongs to another NPC or to a book.
- Item tooltips and reward clicks in the quest preview work again.
- Clicking an item again now closes its pinned card.

---

**🇫🇷 Français**

### Nouveautés
- **Largeur de l'aperçu de quête** : ajustée à son contenu par défaut (centré sous les choix quand il est court, plus large pour un long objectif). Décochez l'option pour la régler vous-même avec sa propre poignée (en miroir quand la roue est à gauche).
- **Priorité des dialogues Spoken** : un texte de quête passe toujours avant la salutation d'un PNJ et n'est jamais coupé par elle ; les salutations ne sont jamais mises en file d'attente.
- **Fenêtre de narration des zones** (Spoken) : son propre habillage — thème actuel, page seule ou DialogueUI.
- L'infobulle des livres et plaques suit maintenant la souris par défaut.
- Toutes les nouvelles options traduites dans toutes les langues du jeu.

### Améliorations
- L'infobulle des livres se met à jour en direct, disparaît dès que la souris s'en va et ne clignote plus.
- Avec Spoken, un livre encore en lecture garde l'étiquette « Je suis en train de lire ce récit… » après sa fermeture.
- Le cadre de l'aperçu de quête n'a plus d'encoche de dialogue, est un peu plus bas et plus sombre : il ne ressemble plus à un choix.

### Corrections
- Un PNJ pouvait afficher le texte de quête du PNJ précédent.
- La bulle n'attend plus une voix qui appartient à un autre PNJ ou à un livre.
- Les infobulles des objets et les clics sur les récompenses de l'aperçu de quête refonctionnent.
- Recliquer sur un objet referme maintenant sa fiche épinglée.

## 1.3.5

**🇬🇧 English**

### New
- **Read books**: the tooltip of a book or plaque tells whether you are reading it, never read it, left it unfinished or already know it (per character). Can be turned off.
- Option to show the tooltip of books and plaques at the mouse.
- `/storytale forget`: treat the open book as never heard (to test the priority below).

### Improved
- A book or plaque never heard in full keeps playing when you talk to an NPC; one already heard gives way.
- Spoken's player stays visible while a book is being read aloud, even during a conversation.
- Spoken's captions follow the voice again by themselves after you scroll them and move the mouse away.
- The interface no longer shrinks for small NPCs (dwarves, gnomes).
- The choice wheel sits closer to the NPC and moves less when you walk around.

---

**🇫🇷 Français**

### Nouveautés
- **Livres lus** : l'infobulle d'un livre ou d'une plaque indique si vous êtes en train de le lire, ne l'avez jamais lu, ne l'avez pas terminé ou le connaissez déjà (par personnage). Désactivable.
- Option pour afficher l'infobulle des livres et plaques à la souris.
- `/storytale forget` : le livre ouvert compte comme jamais écouté (pour tester la priorité ci-dessous).

### Améliorations
- Un livre ou une plaque jamais écouté en entier continue d'être lu quand vous parlez à un PNJ ; un livre déjà écouté lui cède la place.
- Le lecteur Spoken reste visible pendant la lecture d'un livre, même pendant une conversation.
- Le texte de Spoken suit de nouveau la voix tout seul après un défilement manuel, quand la souris s'en va.
- L'interface ne rétrécit plus pour les petits PNJ (nains, gnomes).
- La roue des choix est plus proche du PNJ et bouge moins quand on se déplace.

## 1.3.4

**🇬🇧 English**

### Fixed
- After a quest text, the NPC's usual greeting no longer replaces it in the bubble while the quest text is being read.

---

**🇫🇷 Français**

### Corrections
- Après un texte de quête, la salutation habituelle du PNJ ne le remplace plus dans la bulle pendant sa lecture.

## 1.3.3

**🇬🇧 English**

### Improved
- When an NPC has nothing to say, the bubble shows a centred "..." instead of "(No text available)".

---

**🇫🇷 Français**

### Améliorations
- Quand un PNJ n'a rien à dire, la bulle affiche « ... » centré au lieu de « (Aucun texte disponible) ».

## 1.3.2

**🇬🇧 English**

### Improved
- Spoken's word highlight on plaques now matches the material: gilded letters on stone, marble and silver, verdigris on bronze.

### Fixed
- A long silence before an NPC's next line when a book or plaque was waiting in Spoken's queue: the NPC now speaks first.

---

**🇫🇷 Français**

### Améliorations
- Surbrillance des mots de Spoken sur les plaques assortie à la matière : lettres dorées sur pierre, marbre et argent, vert-de-gris sur bronze.

### Corrections
- Long silence avant la réplique suivante d'un PNJ quand un livre ou une plaque attendait dans la file de Spoken : le PNJ parle maintenant en premier.

## 1.3.1

**🇬🇧 English**

### Fixed
- Spoken's reading queue: a book or plaque played again later keeps its own look (plaque, DialogueUI book or game window) instead of the current NPC theme.

---

**🇫🇷 Français**

### Corrections
- File de lecture Spoken : un livre ou une plaque relancé plus tard garde son habillage (plaque, livre DialogueUI ou fenêtre du jeu) au lieu du thème du PNJ en cours.

## 1.3.0

**🇬🇧 English**

### New
- **Engraved plaques**: stone, marble, bronze and silver plaques now show on a matching plaque, with engraved text.
- **Plaque options**: choose who displays plaques (Storytale, DialogueUI or the game window), and pick one material for every plaque or keep it automatic.
- **Wheel side** option: show the choice wheel on the right or the left of the NPC.
- Plaques and single pages can be **resized** with the corner grip; the text grows when they get small so it stays readable.
- `/storytale plate stone|marble|bronze|silver|off` to preview a plaque material on the open text.

### Improved
- "Books, letters and plaques" options reorganised and shortened, with tooltips.
- DialogueUI themes now use your installed DialogueUI's own art.
- Resize grip easier to find: always visible when frames are unlocked, glowing blue on hover.
- Spoken's player follows the plaque, the DialogueUI book or the game window correctly.
- Chat messages now start with [Storytale].

### Fixed
- "Game window" now really opens the game's own window when DialogueUI is installed.
- Close and Mute buttons no longer overlap the plaque.

---

**🇫🇷 Français**

### Nouveautés
- **Plaques gravées** : les plaques de pierre, marbre, bronze et argent s'affichent sur une plaque assortie, avec un texte gravé.
- **Options des plaques** : choisis qui affiche les plaques (Storytale, DialogueUI ou la fenêtre du jeu), et une matière pour toutes les plaques ou le mode automatique.
- Option **Côté de la roue** : roue des choix à droite ou à gauche du PNJ.
- Les plaques et pages seules se **redimensionnent** avec la poignée du coin ; le texte grossit quand elles rapetissent pour rester lisible.
- `/storytale plate stone|marble|bronze|silver|off` pour essayer une matière de plaque sur le texte ouvert.

### Améliorations
- Options « Livres, lettres et plaques » réorganisées et raccourcies, avec infobulles.
- Les thèmes DialogueUI utilisent maintenant les images de ton DialogueUI installé.
- Poignée de redimensionnement plus facile à trouver : toujours visible quand les fenêtres sont déverrouillées, bleue au survol.
- Le lecteur Spoken suit correctement la plaque, le livre DialogueUI ou la fenêtre du jeu.
- Les messages dans le chat commencent par [Storytale].

### Corrections
- « Fenêtre du jeu » ouvre vraiment la fenêtre du jeu quand DialogueUI est installé.
- Les boutons Fermer et Couper la voix ne chevauchent plus la plaque.

## 1.2.0

**🇬🇧 English**

### New
- **Choice size** option: set the text size of the dialogue choices (10 to 24 pt).
- **Reset all options** button (and `/storytale reset`), with a confirmation. Only Storytale's settings are reset.

### Improved
- Options reorganised into clear sections: Appearance, Text, Books and letters, Placement, Controls, Spoken. Many labels reworded.
- Better defaults, applied once to everyone: the theme also dresses the choice wheel, text size 14.
- Choice key: if the game's Interact key is turned off, Storytale uses **E** (changeable); if it is on, Storytale uses the game's key.
- The key to switch between the bubble and Spoken's player now works even with the "Spoken" choice hidden, and has no key by default.
- Spoken's player takes the theme automatically when Spoken is installed, even later.
- New addon icon: a speech bubble.

---

**🇫🇷 Français**

### Nouveautés
- Option **Taille des choix** : règle la taille du texte des choix de dialogue (10 à 24 pt).
- Bouton **Réinitialiser toutes les options** (et `/storytale reset`), avec confirmation. Seuls les réglages de Storytale sont remis à zéro.

### Améliorations
- Options réorganisées en sections claires : Apparence, Texte, Livres et lettres, Position, Commandes, Spoken. Beaucoup de libellés reformulés.
- Meilleurs réglages par défaut, appliqués une fois à tout le monde : le thème habille aussi la roue des choix, texte en taille 14.
- Touche de choix : si la touche d'interaction du jeu est désactivée, Storytale utilise **E** (modifiable) ; si elle est activée, Storytale utilise celle du jeu.
- La touche pour basculer entre la bulle et le lecteur de Spoken fonctionne même avec le choix « Spoken » caché, et n'a plus de touche par défaut.
- Le lecteur de Spoken prend le thème automatiquement quand Spoken est installé, même plus tard.
- Nouvelle icône de l'addon : une bulle de dialogue.

## 1.1.0

**🇬🇧 English**

### New
- Two new themes: **Folio** (a worn, gently curved parchment sheet) and **Night Folio** (translucent black paper with frayed edges and a soft shadow).

### Improved
- The scroll bar now has rounded ends, stays inside the list, and takes the theme's highlight colour (copper on parchments, gold on dark themes, discreet grey for Azeroth Bubble). The small up/down arrows match it.
- Smoked Glass and Ink & Gold: the selected choice, scroll bar and arrows are now pale gold, like the NPC's name.
- Shadow Halo, Ink & Gold and Cinematic are no longer marked as experimental.

### Fixed
- Cinematic theme: fixed an error when the rest of the interface fades out.

---

**🇫🇷 Français**

### Nouveautés
- Deux nouveaux thèmes : **Folio** (une feuille de parchemin usée, légèrement courbée) et **Folio nocturne** (papier noir translucide, bords effilochés et ombre douce).

### Améliorations
- La barre de défilement a des bouts arrondis, ne dépasse plus de la liste et prend la couleur de surbrillance du thème (cuivre sur les parchemins, or sur les thèmes sombres, gris discret pour la Bulle d'Azeroth). Les petites flèches haut/bas sont assorties.
- Verre fumé et Encre et or : le choix sélectionné, la barre de défilement et les flèches sont en or pâle, comme le nom du PNJ.
- Halo d'ombre, Encre et or et Cinématique ne sont plus marqués comme expérimentaux.

### Corrections
- Thème Cinématique : correction d'une erreur quand le reste de l'interface s'efface.

## 1.0.0

**🇬🇧 English**

First release of **Storytale** (formerly DialogueWheelE).

### Installation
Download `Storytale.zip` below and unzip it in `World of Warcraft\_forever_\Interface\AddOns`, then restart the game.
Coming from DialogueWheelE: delete the old `DialogueWheelE` folder; to keep your settings, with the game closed, rename `DialogueWheelE.lua` to `Storytale.lua` in `WTF\Account\<your account>\SavedVariables`.

### Features
- Choice wheel next to the NPC, driven by the mouse wheel (with momentum) and the interact key; long lists scroll and can be dragged.
- The NPC's words in a speech bubble above their head, written as they speak.
- Quest preview: objectives, rewards with rarity colours, reward choice, one-click "Complete Quest".
- Books, letters and plaques as an illustrated open book (movable, resizable, readable when small) or a scrolling note; buttons under the book, mouse wheel to switch.
- 12+ themes, as bubbles or frames, previewed in the options.
- Spoken support (optional): text synced with the voice, books pause while you talk to an NPC, NPCs speak in turn, and a reading queue in Spoken's player to pick or remove what you want to hear.
- Works alone, or alongside DialogueUI and Spoken. Every game language.

---

**🇫🇷 Français**

Première version de **Storytale** (anciennement DialogueWheelE).

### Installation
Télécharge `Storytale.zip` ci-dessous et décompresse-le dans `World of Warcraft\_forever_\Interface\AddOns`, puis relance le jeu.
Tu avais DialogueWheelE : supprime l'ancien dossier `DialogueWheelE` ; pour garder tes réglages, jeu fermé, renomme `DialogueWheelE.lua` en `Storytale.lua` dans `WTF\Account\<ton compte>\SavedVariables`.

### Fonctionnalités
- Roue de choix à côté du PNJ, à la molette (avec élan) et à la touche d'interaction ; les longues listes défilent et se glissent.
- Les paroles du PNJ dans une bulle au-dessus de sa tête, écrites au fil de sa voix.
- Aperçu des quêtes : objectifs, récompenses aux couleurs de rareté, choix de la récompense, « Terminer la quête » en un clic.
- Livres, lettres et plaques en livre ouvert illustré (déplaçable, redimensionnable, lisible même petit) ou en note qui défile ; boutons sous le livre, molette pour passer de l'un à l'autre.
- Plus de 12 thèmes, en bulles ou en cadres, avec aperçu dans les options.
- Prise en charge de Spoken (facultatif) : texte synchronisé avec la voix, livres en pause pendant une conversation, PNJ chacun leur tour, et file de lecture dans le lecteur de Spoken pour choisir ou retirer ce qu'on veut écouter.
- Fonctionne seul, ou avec DialogueUI et Spoken. Toutes les langues du jeu.
