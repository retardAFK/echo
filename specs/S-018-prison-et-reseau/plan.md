# Plan — S-018

**Statut** : proposé par Claude (16/11/2026), sur la spec validée par Maxime le 15/11/2026 (D-020). Les chiffres de la spec sont repris tels quels, sauf l'emplacement du terminal du gardien (voir « Écarts »).

## Écarts avec la spec
- **Terminal du gardien dans la galerie**, pas au centre social : le point du centre social le plus loin des cages en est à 62 m, alors que Q4 demande au moins 80 m. L'arrière-boutique de la pharmacie, au bout ouest de la galerie, est à environ 90 m des cages. Le récit de la spec (Léa au centre social) devient « Léa à la galerie ».
- **Le rideau de la galerie** ferme le couloir de livraison à son bout est (pas une devanture, qui ne bloquerait rien : la galerie a d'autres portes).

## Approche technique

### La prison (partie A)
- Les **cages** sont trois des caves grillagées du couloir des caves (S-016), à l'ouest de la cave ouverte : x 118 à 127, y 94,2 à 96 (plan), à −3 m. Le générateur (`build_tilleuls.gd`) n'y pose plus de grille fixe en façade : il y pose une entité **`Cage`** (`game/entities/prison/cage.tscn`), grille en `AnimatableBody3D` comme le battant d'une porte, qui coulisse pour s'ouvrir. Les trois cages sont filles d'un nœud **`Prison`** (`prison.gd`) qui connaît leurs places.
- `CaptureState` (S-010) change de règle : prise 1 et 2 → `CAPTURED` (en cage), prise 3 → `OUT`. Le cri d'appel (`CALL`) disparaît : le prisonnier ne fait aucun bruit (Q7). La libération par E sur place passe de `CaptureState` à la `Cage`.
- À la capture (en ligne seulement, salle) : écran noir de 2 s chez le prisonnier (déjà là : `caught_screen_time`), ses fusibles tombent sur place (déjà là : `GameLoop.drop_fuses`), puis `Prison.jail(hunted)` le pose dans une cage libre, grille fermée. Le client est déplacé par la salle (la prédiction repart de la position reçue, comme pour une cachette).
- Chaque cage a son **chrono** (`PrisonRules`, classe pure testée seule) : 120 s au premier séjour, 60 s au deuxième ; arrêté tant que le monstre (IA ou humain) est à moins de 15 m de la cage ; à 0, le prisonnier passe `OUT`. Une **lampe** au-dessus de la cage s'allume pendant le séjour et clignote dans les 20 dernières secondes (matériau émissif, pas de lumière dynamique).
- **Libérer sur place** : un chassé libre vise la grille et maintient E 4 s (`HoldProgress`) ; bruit `CAGE` de 8 m au début et à la fin ; la grille s'ouvre, le prisonnier redevient `FREE`. La grille reste ouverte 3 s puis se referme seule (cage libre).
- **Victoire du monstre** : `GameLoop.free_count()` compte déjà les capturés et les éliminés ; rien à changer. **Solo** : `CaptureState` n'existe pas en solo, donc rien ne change.

### Le réseau de la cité (partie B)
Un nœud **`CityNetwork`** (`game/entities/network/city_network.gd`) dans la map liste, dans un ordre fixe, les éléments du réseau ; il porte les règles qui touchent plusieurs éléments et l'état envoyé en ligne.
- **`Terminal`** (`terminal.tscn`) : un vieux PC posé sur un bureau. Le chassé vise l'écran et maintient E 1 s pour s'installer (`HoldProgress`). Installé : immobile, clavier `KEYBOARD` de 3 m toutes les 2 s, écran plus lumineux (matériau émissif, plus une `OmniLight3D` de 3 m allumée seulement pendant l'usage : au plus quelques-unes à la fois, sous le budget de 4 lumières dynamiques). Il quitte avec E ou en bougeant. Le monstre vise un terminal et maintient E 1 s pour l'**éteindre** 60 s (le chassé installé est éjecté). Un terminal utilisé pendant un **scan** de son bâtiment s'entend : son bruit de clavier passe dans le scan comme les autres bruits (rien à coder).
- **Menu du terminal** (`TerminalMenu`, interface 640 × 360 du style A) : la liste des caméras, des haut-parleurs, des rideaux, et selon le terminal « Ouvrir les cages » (gardien), « Lancer le téléchargement » (objectif). Souris ou touches 1 à 9. Le choix part vers la salle comme une action de `PlayerCommands` : une nouvelle action **`PICK`** suivie d'un numéro (`PICK_BASE + n`), pour qu'un client trafiqué ne puisse rien inventer de plus.
- **`SecurityCamera`** : un boîtier avec une LED. Regardée, la LED rouge s'allume (visible du monstre, matériau émissif). Le monstre la casse avec E (1 s, bruit `CAMERA` de 10 m) : morte pour la partie. Voir une caméra : la caméra du joueur passe sur une `Camera3D` posée dans la caméra, avec un filtre vert basse définition (`SecurityFeed`, un `ColorRect` en plein écran avec un shader qui lit l'écran). On ne dessine **jamais deux fois** la scène : pas de `SubViewport`, donc pas d'appels de dessin en plus.
- **`Loudspeaker`** : déclenché depuis un terminal, un bruit `SPEAKER` de 25 m répété pendant 5 s, une fois par partie. Mêmes règles que les leurres (S-008) pour le monstre.
- **`RemoteShutter`** : rideau métallique baissé depuis un terminal pendant 20 s (bruit `SHUTTER` de 12 m au début et à la fin), recharge 60 s. Baissé, il bloque tout le monde (corps sur la couche des murs, donc il coupe aussi la vue et étouffe le bruit). Le maillage de navigation ne change pas : les IA qui trouvent un rideau baissé sur leur chemin (même test que `Door.closed_ahead`) changent de but (proie) ou attendent qu'il remonte en regardant ailleurs (monstre).
- **Terminal du gardien** : un `Terminal` avec la ligne « Ouvrir les cages » : 10 s installé devant (le menu montre la progression), puis sonnerie `BELL` de 15 m à la prison et toutes les cages occupées s'ouvrent. Partir ou être éteint arrête et remet à zéro.
- **Le prisonnier** voit les caméras sur l'écran de sa cage : E passe à la caméra suivante (et revient à ses yeux après la dernière). Il ne fait aucun bruit.

### Les quêtes tirées au sort (partie C)
- `LoopRules` reçoit une liste d'**objectifs** (`Objective.Kind` : `FUSE`, `CODE`, `DOWNLOAD`, `RELAY`). Tirage (`LoopRules.draw_objectives`) : 3 objectifs, au moins un fusible, jamais deux fois le même autre type, seulement parmi les types que la map sait faire (la greybox des tests n'a que des fusibles, donc 3 fusibles comme aujourd'hui). Le nombre de fusibles tirés devient `fuse_count`.
- Le **transformateur** attend les fusibles tirés, plus le code, plus la disquette ; la sortie s'ouvre quand les 3 objectifs sont faits (même sirène).
- **Code** : 6 emplacements possibles (tableau blanc, post-it, écran) dans les 4 bâtiments ; un seul est tiré et montre un nombre à 4 chiffres (`Label3D`, dessiné à moins de 15 m). Le chassé tape le code sur le **clavier du transformateur** (un `Terminal` de type code, posé contre le transformateur : chiffres 0 à 9 dans son menu). Un mauvais code fait un bip de 3 m.
- **Téléchargement** : un terminal tiré parmi les 5 ordinaires ; « Lancer le téléchargement » le démarre (pas besoin de rester), 45 s, disque dur `DISK` de 5 m toutes les 3 s ; éteint par le monstre, il repart de zéro. À la fin, une **disquette** apparaît à côté (`Pickup` de type `DISK`), à porter au transformateur (maintenir E comme un fusible). Capturé, le chassé la laisse tomber sur place.
- **Relais** : 4 interrupteurs (un par bâtiment) ; deux sont tirés, dans deux bâtiments à moins de 70 m l'un de l'autre (au plus 12 s de course). Les actionner à moins de 15 s d'écart (bruit `SWITCH` de 6 m chacun) ; sinon le premier se relâche (déclic).
- **Liste des objectifs** à côté de la carte (Tab, S-017) : le type et l'avancée (« Fusible 1/2 », « Code », « Téléchargement 60 % »…), jamais de position (D-018).

### En ligne
Tout l'état du réseau tient dans **un tableau de plus** dans `NetWorld.state()`, envoyé au changement comme le reste : par cage (occupée, ouverte, chrono, lampe), par terminal (éteint, utilisé, progression), par caméra (regardée, cassée), par haut-parleur (utilisé), par rideau (baissé, recharge), et les objectifs (types, avancée, emplacement du code et code, terminal du téléchargement, relais tirés). Les menus et le chrono s'affichent chez le client à partir de cet état. **Vie privée** : la salle n'envoie à un chassé la position d'un autre que s'il le voit de ses yeux **ou** de la caméra qu'il regarde (`NetGame.snapshot_for` prend la caméra comme œil). Le monstre ne reçoit pas qui regarde une caméra, seulement que sa LED est allumée.

### L'IA
- **Monstre IA** : il voit les LED rouges et les écrans allumés comme des indices (il va casser la caméra, éteindre le terminal) ; il passe voir la prison de temps en temps quand elle est occupée, sans y camper (le chrono s'arrête de toute façon). Il entend les haut-parleurs comme des leurres.
- **Proie IA** : elle fait les nouveaux objectifs (lire le code puis le taper, lancer le téléchargement puis revenir chercher la disquette, les deux relais en courant), libère sur place un coéquipier quand le monstre est loin, et déclenche un haut-parleur à l'opposé quand elle est poursuivie près d'un terminal.

### Modèles et sons
Par script (`tools/blender/network.py`, `tools/audio/network_sounds.py`) : terminal (PC beige à écran vert), caméra, haut-parleur, rideau, grille de cage, lampe de cage, interrupteur, disquette, tableau blanc et post-it ; clavier, disque dur, sonnerie de prison, rideau, grille, bip, déclic, caméra cassée. Montrés à Maxime en rendus sans attendre sa réponse pour avancer (il peut demander des retouches après).

## Données et réglages
| Réglage | Fichier | Valeur |
|---|---|---|
| Séjours en prison, arrêt du chrono, clignotement | `prison_settings.tres` (nouveau) | 120 s, 60 s, 15 m, 20 s |
| Libérer sur place : durée, bruit | `prison_settings.tres` | 4 s, 8 m |
| Terminal du gardien : durée, sonnerie | `prison_settings.tres` | 10 s, 15 m |
| Terminal : s'installer, clavier, éteint | `network_settings.tres` (nouveau) | 1 s, 3 m toutes les 2 s, 60 s |
| Caméra cassée | `network_settings.tres` | 10 m |
| Haut-parleur | `network_settings.tres` | 25 m pendant 5 s, une fois |
| Rideau | `network_settings.tres` | 20 s, 12 m, recharge 60 s |
| Téléchargement | `loop_settings.tres` | 45 s, 5 m toutes les 3 s |
| Relais | `loop_settings.tres` | 15 s, 6 m, paires à moins de 70 m |
| Objectifs par partie | `loop_settings.tres` | 3, au moins un fusible |

## Emplacements (plan de la cité, mètres, x vers l'est, y vers le sud)
| Élément | Emplacements |
|---|---|
| Cages | 3 caves du couloir des caves, x 118–121, 121–124, 124–127, y 94,2–96, à −3 m |
| Terminaux | tour : loge du hall (rez-de-chaussée) ; centre social : bureau nord-est et accueil du couloir ; galerie : arrière-boutique de la boulangerie ; parking : local technique ; **gardien** : arrière-boutique de la pharmacie ; clavier du transformateur |
| Caméras (8) | couloir des caves (vers les cages) ; parking ; rampe du parking ; hall de la tour ; grande salle du centre social ; arcade de la galerie ; transformateur ; carrefour au sud de la tour |
| Haut-parleurs (3) | sono de la scène du centre social ; alarme incendie du hall de la tour ; interphone de l'arcade de la galerie |
| Rideaux (2) | entrée du parking par la rampe (x 140, y 100–104) ; bout est du couloir de livraison de la galerie |
| Code (6) | tableau blanc du bureau du centre social, post-it de la cuisine, écran du local technique, post-it de la loge de la tour, tableau de la pharmacie, post-it d'un appartement du 2e étage |
| Interrupteurs de relais (4) | un par bâtiment : tour (cave), centre social (cuisine), galerie (couloir de livraison), parking (local technique) |

Les points exacts sont dans `build_tilleuls.gd` (constantes `PRISON_CAGES`, `TERMINALS`, `CAMERAS`, `SPEAKERS`, `SHUTTERS`, `CODE_SPOTS`, `RELAYS`) et dessinés sur le plan de la carte comme des bâtiments, sans icône (Q14).

## Impact sur la performance
- **Appels de dessin** : environ 30 objets nouveaux, chacun 1 à 2 appels, tous avec une distance d'affichage (`DrawRange`, 20 m dedans, 30 m dehors). Le pire endroit est à 294 : on mesure avec `measure_map` à chaque ajout et on fusionne les meshes d'un même objet (une seule surface par modèle).
- **Vue des caméras** : on déplace la caméra du joueur, on ne dessine pas la scène deux fois.
- **Lumières** : une `OmniLight3D` par terminal en usage seulement ; les LED, lampes et écrans sont émissifs.
- **Réseau** : un tableau de plus dans l'état du monde, envoyé au changement ; le chrono des cages est envoyé à la seconde près (pas à chaque image).

## Risques et alternatives
- **Rideaux et navigation** : sans changer le maillage, une IA peut rester devant un rideau baissé. Plan B : une région de navigation séparée sous chaque rideau, désactivée quand il est baissé.
- **Durée des parties** : la prison rallonge les parties en ligne ; on vérifie par simulation que la durée moyenne ne baisse pas en solo.
- **Budget de dessin** : si un point dépasse 300, on retire une caméra ou un terminal de ce bâtiment.

## Conformité à la constitution
- Une scène par entité (`Cage`, `Prison`, `Terminal`, `SecurityCamera`, `Loudspeaker`, `RemoteShutter`, `CityNetwork`), réglages dans `data/`, bruits par `NoiseBus`, signaux entre entités, tests GUT pour les règles pures (`PrisonRules`, tirage des objectifs, relais, téléchargement) : respecté.
- Assets faits par nous (scripts Blender et sons générés) : respecté.
- Orange réservé au bruit : la LED des caméras est rouge, les écrans verts.
