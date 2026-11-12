# Plan — S-008

**Statut** : proposé (12/11/2026), suit la spec en attente de validation

## Approche technique

### Ce que porte le chassé : `Inventory`
Nouvelle classe pure **`Inventory`** (`game/session/inventory.gd`, `RefCounted`) : nombre de bouteilles (2 au plus, Q1) et réveil porté (1 au plus, Q3), avec `can_take()`, `take()`, `use()` et un signal `changed`. Le joueur et la proie IA en ont chacun une. Les plafonds vivent dans un nouveau fichier de réglages **`game/data/ruse_settings.tres`** (`RuseSettings`), comme toutes les valeurs de cette spec.

### Ramasser
Nouvelle entité **`Pickup`** (`game/entities/pickup/`), un `Node3D` dans le groupe `interactable` existant, avec un `kind` (bouteille ou réveil). Le joueur la trouve comme une voiture à alarme : proximité + cône de visée de 35°, appui sur E, action immédiate, aucun bruit (Q1). Elle disparaît une fois prise. La recherche de cible du joueur passe du groupe nommé par `CarAlarm` à une constante commune `Interactable.GROUP`, sans changer le comportement.

### Lancer : `Bottle`
Nouvelle action d'entrée **`throw`** (clic gauche). Le joueur fait apparaître un **`ThrownBottle`** (`RigidBody3D` léger, une sphère de collision de 6 cm, couches : sol et murs) à hauteur des yeux, lancé à la vitesse fixe `throw_speed` dans la direction de la caméra (Q2). Le geste fait un bruit `THROW` de 1 m. Au premier contact (`body_entered`, `contact_monitor`), la bouteille émet un bruit **`IMPACT`** de 8 m au point de contact, joue le bris de verre, laisse quelques éclats (un petit maillage statique, effacé au bout de 30 s) et disparaît. Garde-fou : une bouteille qui n'a rien touché au bout de 4 s se brise où elle est. La portée (environ 15 m sur le plat depuis 1,6 m) se règle par `throw_speed` et un léger angle vers le haut ajouté au regard (`throw_lift`) ; un test GUT vérifie la portée balistique calculée.

### Le réveil : `Decoy`
Nouvelle action d'entrée **`place_decoy`** (clic droit ; le clic droit du monstre reste le scan, les rôles ne se croisent pas). Le joueur pose un **`Decoy`** (`game/entities/decoy/`) au sol, 0,8 m devant lui (rayon vers le bas pour trouver le sol, sinon à ses pieds), avec un bruit `THROW` de 1 m. Le réveil a trois états : **TICKING** (15 s, tic-tac en `AudioStreamPlayer3D` à très courte portée, aucun bruit dans `NoiseBus`), **RINGING** (10 s, un bruit **`DECOY`** de 12 m chaque seconde, sonnerie en boucle), **DONE**. `crush()` le fait passer à DONE avec un craquement : le monstre IA l'appelle quand il arrive à moins de sa distance de capture d'un réveil qui sonne, le monstre joueur (`MonsterAvatar`) aussi en marchant dessus (Q4). La logique de temps vit dans une classe pure **`DecoyTimer`** testée seule.

### Les cachettes : `HidingSpot`
Nouvelle entité **`HidingSpot`** (`game/entities/hiding_spot/`) avec deux modèles : placard métallique (bâtiments) et benne (dehors). Elle est dans le groupe `interactable` et utilise `HoldInteraction` de S-007 : maintenir E **1 s** pour entrer ou sortir (Q5), un bruit **`HIDE`** de 3 m à la fin. Occupée par un seul chassé à la fois.
- **Chassé caché** (Q6) : le joueur passe dans un état `hidden`. Son corps est désactivé (pas de mouvement, pas de pas, gait accroupi pour le reste du code), la caméra se place dans la cachette, le regard est limité à ±40° en lacet et ±20° en tangage, et un cadre noir `HideMask` (une texture à fente, base 640 × 360) recouvre l'écran. `throw` et `place_decoy` sont ignorés. Le souffle (`BREATH`, D-009) continue : le scan l'entend.
- **Invisible** : `get_eye_position()` reste valable, mais `Monster._update_sight` et la vue de `MonsterAvatar` ignorent un chassé caché (`is_hidden()`). Le chassé caché ne fait aucun bruit de pas, puisqu'il ne bouge pas.
- **Fouiller** (Q7) : la cachette propose aussi « Ouvrir » au monstre joueur, maintenir E 1 s, bruit `HIDE` de 3 m ; si un chassé est dedans, c'est une capture (même chemin que le contact). Le monstre IA ouvre une cachette avec la même durée.

### Le monstre IA (Q4, Q7, Q8)
`MonsterBrain` gagne un état **`OPEN`** : aller devant une cachette, s'arrêter 1 s, l'ouvrir.
- `saw_hide(spot)` : le monstre voyait le chassé (ligne de vue au dernier contrôle de vue) quand il est entré dans la cachette → il l'ouvre, poursuite ou pas.
- En perdant une poursuite (passage CHASE → SEARCH), il choisit la cachette la plus proche du dernier point vu, à moins de `search_hide_radius` (8 m), une fois sur deux (`search_open_chance` 0,5, tirage seedé pour les tests).
- Jamais en patrouille (Q7).
- Bruits de leurre : rien de neuf, ils passent par `hear()` comme les autres (Q8). En arrivant sur un réveil qui sonne, il l'écrase.

### La proie IA (Q9)
`PreyBrain` reçoit les ruses, chacune comme une règle simple, testée seule :
- **ramasser** : si une `Pickup` est à moins de 6 m de son chemin et qu'elle a de la place, elle fait le détour (hors fuite) ;
- **lancer** : quand elle entend le monstre ou le voit sans être en poursuite, elle lance une bouteille vers un point à 12–18 m, du côté opposé à son objectif, et attend 2 s avant de reprendre ;
- **leurre** : en arrivant à 30 m du transformateur avec un réveil, elle le pose à au moins 20 m du transformateur, puis attend qu'il sonne pour réparer ;
- **cachette** : en fuite, si une cachette libre est à moins de 10 m et hors de vue du monstre, elle y entre et y reste `hide_time`, sinon elle fuit comme aujourd'hui ;
- **alarme** : en fuite, si elle passe à moins de 3 m d'une voiture à alarme au repos, elle la déclenche.
La simulation (`tools/godot/simulate_games.tscn`) compte chaque ruse utilisée.

### Placement dans la cité
Le générateur `tools/godot/build_tilleuls.gd` reçoit trois listes de positions, comme les emplacements de fusible :
- **20 bouteilles** (Q1) sur des murets, des bancs, des halls et au parking, posées à chaque partie ;
- **10 emplacements de réveil** (Q3) : les 2 boxes ouverts, 4 au parking souterrain, 2 dans la réserve du centre social, 2 dans le couloir arrière de la galerie ; `GameLoop` en tire 4 à chaque partie, comme les fusibles ;
- **18 cachettes** (Q5) : 3 placards dans chacun des 4 bâtiments visitables (contre un mur, hors du passage) et 6 bennes dehors. Les cachettes sont des obstacles pour le maillage de navigation ; les emplacements sont choisis pour ne pas boucher un couloir (test de navigation existant étendu).
Les anciens points `HidingSpots` de la proie (S-004) restent pour sa fuite ; les nouvelles cachettes s'y ajoutent.

### Écran
`LoopHud` affiche en bas à droite « 2 bouteilles », « Réveil » (Q11). `InteractPrompt` reçoit les nouveaux textes : « Ramasser », « Se cacher », « Sortir », « Ouvrir ». L'écran de fin ajoute « Ruses utilisées ». Toutes les chaînes passent par `game/i18n/strings.csv`.

### Modèles et sons
- Modèles Blender par script (`tools/blender/ruses.py`) : bouteille (≈ 60 triangles, texture 64 px), réveil (≈ 150 triangles), placard métallique (≈ 300), benne (≈ 400), éclats de verre. Rendus montrés à Maxime avant intégration (seul choix de style de la spec).
- Sons synthétisés par nous (`tools/audio/ruse_sounds.py`, numpy) : bris de verre, tic-tac, sonnerie, craquement du réveil écrasé, porte de placard, couvercle de benne. Notés dans `CREDITS.md`.

## Données et réglages
| Réglage | Fichier | Valeur de départ |
|---|---|---|
| Bouteilles portées au plus | `ruse_settings.tres` | 2 |
| Vitesse et angle du lancer | `ruse_settings.tres` | réglés pour ≈ 15 m sur le plat |
| Portée du geste (lancer, poser) | `ruse_settings.tres` | 1 m |
| Portée de l'impact | `ruse_settings.tres` | 8 m |
| Réveils par partie / portés | `ruse_settings.tres` | 4 / 1 |
| Délai, durée, portée, intervalle du réveil | `ruse_settings.tres` | 15 s, 10 s, 12 m, 1 s |
| Durée et portée d'une cachette (entrer, sortir, ouvrir) | `ruse_settings.tres` | 1 s, 3 m |
| Rayon de fouille après une poursuite perdue | `monster_settings.tres` | 8 m |
| Chance d'ouvrir après une poursuite perdue | `monster_settings.tres` | 0,5 |
| Distances de la proie (détour, lancer, leurre, cachette) | `prey_settings.tres` | 6 m, 12–18 m, 20 m, 10 m |

## Impact sur la performance
- Bouteilles, réveils et cachettes : 38 objets de plus au plus, chacun un seul matériau. Les bouteilles et les bennes passent par des `MultiMesh` quand elles sont nombreuses dans une vue (leçon de T-048), sinon de simples instances. On remesure le pire des appels de dessin sur les 484 vues de `measure_map` : il doit rester sous 300 (215 aujourd'hui).
- Aucune lumière ajoutée. Un réveil qui sonne n'a pas de lumière.
- Une bouteille en vol est un seul `RigidBody3D` de courte durée.
- Taille du build : quelques modèles de moins de 20 Ko et des sons courts en mono 22 kHz, loin du budget de 60 Mo.

## Risques et alternatives
- **La bouteille traverse un mur fin** à grande vitesse : on active la détection continue (`continuous_cd`) ; alternative, un lancer par rayons successifs sans physique.
- **Le monstre IA ouvre trop ou pas assez** : les deux réglages (rayon, chance) sont dans `MonsterSettings` ; la simulation de 20 parties tranche.
- **La proie IA abuse des cachettes** et les parties s'allongent : `hide_time` et la règle « hors de vue » limitent ; on mesure.
- **Les cachettes gênent la navigation** : test de navigation de la cité étendu à chaque cachette.

## Conformité à la constitution
- Pas de combat : aucune ruse ne blesse ni ne ralentit le monstre (section 1).
- Toute ruse passe par `NoiseBus` (section 2.4) ; toutes les valeurs sont dans `data/`.
- Orange réservé au bruit : aucun modèle n'utilise d'orange (section 2.3).
- Modèles par scripts Blender rangés dans `tools/blender/` (section 2.6).
- Budgets de la section 2.2 remesurés à la tâche finale.
