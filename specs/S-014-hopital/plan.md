# Plan — S-014

**Statut** : proposé par Claude (16/11/2026), sur la spec validée le 16/11/2026

## Approche technique

### Budget d'abord (Q12)
- **T-194** (fait, PR #156) : la map générée est enregistrée en binaire compressé (`tilleuls.scn`, 1,1 Mo au lieu de 11 Mo dans le build web).
- **T-195** (PR #157) : `LevelVisibility` (`game/maps/level_visibility.gd`) range chaque modèle intérieur dans son bâtiment et son niveau, et ne le dessine que près du niveau de la caméra. Pire point de la map actuelle : 297 → 264 appels de dessin. L'hôpital en profite sans rien de plus, à condition que ses volumes de scan soient des `Building`.

### Le générateur
L'hôpital est construit par un nouveau fichier, `tools/godot/hospital.gd` (comme `interior_lining.gd`), appelé par `build_tilleuls.gd`. Il ne reçoit que le `MapKit` et le constructeur, et utilise les mêmes outils : `kit.box`, `kit.wall_x`, `kit.wall_y`, `kit.ramp`, `_door`. Ses chiffres (emprise, niveaux, pièces, portes) sont les constantes du plan sur papier, pour que `tools/plans/make_hospital_plan.py` et le jeu restent d'accord.

- **La barre C** sort de `FACADES` ; la voiture à alarme de (35, 120) devient l'ambulance sous l'auvent.
- **Niveaux tous de 3 m** (la règle de `LevelVisibility.STOREY`), donc le sous-sol est à **−3 m** comme le parking et les caves, au lieu des −3,5 m de la spec (sans effet sur le jeu).
- **Escaliers** : deux cages à doubles volées comme la tour (nord-est et sud-ouest), du sous-sol au 2e ; la volée vers le 3e est fermée par une grille. La fonction `_switchback` de la tour prend en paramètre le bout de palier (aujourd'hui fixé à `STAIR_LANDING_Y`) pour servir aux deux bâtiments.
- **Escalier de secours** sud en métal (zone `MetalFloor`, S-016 Q9), **rampe du quai** vers l'allée de service, **auvent** des urgences.
- **Portes** : `Door` de S-016 (T-185 déjà faite) ; coupe-feu en travers du couloir aux étages (Q3 de S-016) ; issue de secours de la pharmacie (`EMERGENCY`).
- **Navigation** : le maillage de toute la cité est recuit par le générateur ; on vérifie les escaliers (bord à 0,26 m au-dessus des sols, `NAV_BOTTOM`) comme pour la tour.

### Scan par niveau (Q4)
Quatre volumes `Building` empilés (`HospitalB1`, `Hospital0`, `Hospital1`, `Hospital2`) au lieu d'un seul : viser une fenêtre du 1er touche le volume du 1er, et le scan n'entend que lui. `Building` reçoit un `complex` (« Hospital ») : `LevelVisibility` traite les volumes d'un même complexe comme un seul bâtiment, la boucle de partie aussi (un fusible « dans l'hôpital »), et le viseur affiche « Hôpital, 1er étage ». Dedans, le monstre scanne le volume où il se trouve. Le sous-sol se vise par la rampe du quai et les soupiraux (petites boîtes de scan collées au pied de la façade).

### Ventilation (Q5)
Nouvelle zone `Ventilation` (`Area3D`, groupe `ventilation`). `NoiseBus` ignore, pour le monstre et pour le scan, un bruit de portée ≤ `ventilation_mask` (4 m, dans `NoiseSettings`) émis dans une telle zone. Le joueur entend le grondement (son d'ambiance) et voit les grilles.

### Moniteurs (Q6)
Entité `Monitor` (interactable, groupe `monitors`) : E l'allume une fois, bruit `MONITOR` de 15 m répété pendant 10 s, le monstre l'éteint avec E. État dans `NetWorld` comme les haut-parleurs de S-018.

### Brancards et fauteuils (Q7)
- `Gurney` : E pour le prendre, il suit le chassé devant lui (corps cinématique, bruit `ROLL` 6/10 m selon l'allure), E pour le lâcher ; un brancard lâché est un obstacle (couches monde et murs bas, pas la vue) que le monstre dégage en 1 s (10 m) ; le monstre IA le dégage s'il est sur son chemin (`DoorPath`, même idée). Position synchronisée par `NetWorld`.
- `Wheelchair` : E le lance ; il roule 8 m sur le sol (`move_and_slide`, ralenti jusqu'à l'arrêt), bruit `ROLL` de 8 m répété toutes les 0,5 s à sa position. Position synchronisée.

### L'hôpital dans la boucle (Q8, Q9, Q11)
Les emplacements de fusible, cachettes, terminal, caméra, haut-parleur, relais et code sont des points du plan, placés comme ceux des autres bâtiments (`_place_fuse_boxes`, `_place_spot`, `TERMINALS`, `CAMERAS`, `SPEAKERS`, `RELAYS`). Les tiroirs de la morgue et l'ascenseur bloqué réutilisent la famille `METAL` ; les lits la famille `LOW` ; les rideaux `MAKESHIFT`.

### IA (T-192)
- **Monstre IA** : choisit le niveau à scanner (le plus récent bruit dans l'hôpital donne le niveau, sinon au hasard), éteint les moniteurs qui bipent, dégage les brancards.
- **Proie IA** : lance un fauteuil ou allume un moniteur comme leurre quand le monstre approche (même règle que les réveils de S-008).
- 20 parties simulées, la partie à 4 de la CI.

### Habillage, lumière, sons (T-189 à T-191)
Modèles générés par `tools/blender/hospital_kit.py` (à partir de `hospital_mood.py`), rendus montrés à Maxime avant intégration. Revêtement : nouvelles tuiles dans l'atlas de `make_interior_atlas.gd` (carrelage blanc sale, peinture vert d'eau, linoléum), posées par `InteriorLining` (un maillage par niveau). Néons : lumière précalculée (T-049) avec 2 ou 3 vraies lumières qui grésillent. Brouillard intérieur : une `FogVolume` n'existe pas en Compatibility ; à la place, la densité du brouillard de l'environnement monte doucement quand la caméra est dans le couloir de l'hôpital. Sons générés par `tools/audio/` (ventilation, néons, bruits lointains), montrés à Maxime.

## Risques
- **Appels de dessin** : un niveau de l'hôpital fait 74 m de couloir, plus long que la portée des portes (20 m) ; il faut garder le pire point sous 300 avec `LevelVisibility` et les MultiMesh. Mesure `measure_map` à chaque tâche, vues ajoutées dans l'hôpital.
- **Navigation** : 4 niveaux et 2 cages d'escalier de plus ; les IA doivent passer les coupe-feu (leçons de T-236 : portes de part et d'autre du palier, pas au pied des volées).
- **Durée des parties** : un 5e bâtiment à fusibles allonge les trajets ; à vérifier par les simulations (la cible ne doit pas baisser).
