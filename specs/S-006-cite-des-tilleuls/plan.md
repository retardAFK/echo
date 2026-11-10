# Plan — S-006

**Statut** : validé (10/11/2026, Maxime : « On peut passer aux tâches suivantes […] je te fais confiance »)

## Approche technique

### Une map générée par un script
La cité fait 220 × 220 m et compte plusieurs centaines de blocs. Les placer à la main dans une scène texte serait long et fragile. Comme pour les assets Blender (règle 2.6.6), la map passe par un script :

- **`tools/godot/build_tilleuls.gd`** décrit le plan validé (`plan-map.svg`) en blocs : sol, limites, barres, bâtiments visitables, chemins, repères. Il construit la scène, calcule le maillage de navigation et enregistre `game/maps/tilleuls/tilleuls.tscn` et `tilleuls_navmesh.tres`.
  - Lancement : `godot --headless -s tools/godot/build_tilleuls.gd`.
  - Toute modification de la map passe par le script, puis on relance. Une retouche faite à la main dans l'éditeur serait perdue au prochain lancement.
- **Repère** : 1 unité = 1 m, le centre de la map est l'origine. Un point (x, y) du plan devient (x − 110, 0, y − 110) dans Godot : le nord du plan est vers −Z.

### Une scène de map commune
La logique de `greybox_test.gd` (rôle chassé ou monstre, attrapé, retour au menu) devient une classe commune **`GameMap`** (`game/maps/game_map.gd`), utilisée par la greybox de test et par la cité. Elle trouve les bâtiments scannables par le groupe `scannable` au lieu d'un seul nœud `$Building`. Le menu de départ lance la cité ; la greybox reste la map des tests.

### Ce que contient la scène
| Nœud | Contenu |
|---|---|
| `Ground` | Le sol, découpé en carreaux de 40 × 40 m (les lumières ne touchent que les carreaux proches), troué au-dessus de la rampe et de l'escalier du parking |
| `Structures/<nom>` | Une structure par barre, bâtiment, limite ou repère : un `MeshInstance3D` par matériau (blocs fusionnés, un seul appel de dessin) et un `StaticBody3D` avec une boîte de collision par bloc. Les murs sont sur la couche `walls` (ils étouffent le bruit, S-002), les sols et les rampes non |
| `Buildings` | Les volumes de scan (`Building`, groupe `scannable`) : les 4 bâtiments visitables et la rangée de boxes (Q6). Chacun porte ses lumières, qui vacillent au scan (D-009) |
| `FuseSlots` | 4 emplacements par bâtiment visitable (`Marker3D`, groupe `fuse_slot`), utilisés par S-007 (Q5) |
| `CarAlarms` | Les 6 voitures à alarme |
| `PlayerSpawns`, `MonsterSpawn` | Points d'apparition : le chassé tire un point au hasard, le monstre apparaît au sud-est (Q2) |
| `PatrolRoute`, `PreyRoute`, `HidingSpots` | Les points de l'IA du monstre et de la proie IA, dans les rues, la tour et le parking |
| `Props` | Lampadaires, bancs et arbres de S-005 |

### Les 4 bâtiments visitables (Q3, Q4)
- **Tour des Tilleuls** : 24 × 24 m, R+12 vue de dehors (39 m, repère au-dessus des barres, feu rouge au sommet). Hall traversant nord-sud au rez-de-chaussée, cage d'escalier centrale en rampes (pente de 21°), 4 étages visitables avec 2 appartements ouverts par palier, grille qui condamne l'escalier au 4e. Le volume de scan couvre les 5 niveaux visitables.
- **Centre social Jean-Moulin** : 38 × 24 m, un niveau de 4 m, une grande salle, un couloir et des bureaux, deux entrées.
- **Galerie commerciale** : 42 × 14 m, une galerie couverte à piliers devant 5 boutiques. La laverie est ouverte, une boutique a son rideau à moitié levé (on y passe accroupi), les autres sont fermées.
- **Parking souterrain** : 40 × 22 m sous la dalle, 3 m sous le sol, piliers tous les 8 m. Une rampe pour voitures à l'ouest et un escalier de secours à l'est, donc deux sorties.
- **Boxes de garages** : 6 boxes, dont 2 ouverts, scannables (Q6) mais sans fusible.

### Les voitures à alarme
Nouvelle entité **`CarAlarm`** (`game/entities/car_alarm/`) : une voiture grise en bloc. Le chassé la déclenche en appuyant sur **E** tout près (nouvelle action `interact`). Elle sonne quelques secondes en émettant à intervalle régulier un bruit de 30 m (section 6.2) par le `NoiseBus`, avec un nouveau type `CAR_ALARM`, ce qui attire le monstre IA comme n'importe quel bruit. Ensuite elle se tait et ne se redéclenche qu'après un temps de repos. Les durées vivent dans `game/data/car_alarm_settings.tres`.

### Repères dans le brouillard
Chaque lieu repère a une silhouette et une lumière à lui, jamais orange (l'orange reste le bruit, 2.3) : feu rouge au sommet de la tour, portique de la balançoire sous un lampadaire, enseigne pâle de la laverie, lampe de l'entrée du centre social, panneau « P » blanc du parking, transformateur vert, lumière froide du tunnel de sortie.

## Données et réglages
| Réglage | Fichier | Valeur de départ |
|---|---|---|
| Distance de vue de la caméra | `visual_settings.tres` | 90 m (le brouillard cache tout au-delà de 60 m) |
| Portée d'une alarme | `car_alarm_settings.tres` | 30 m (section 6.2) |
| Durée de l'alarme / intervalle des bruits | `car_alarm_settings.tres` | 12 s / 1 s |
| Repos avant un nouveau déclenchement | `car_alarm_settings.tres` | 45 s |
| Distance pour déclencher | `car_alarm_settings.tres` | 2 m |
| Taille des carreaux de sol | `build_tilleuls.gd` | 40 m |
| Maillage de navigation | `tilleuls_navmesh.tres` | cellules de 0,25 m (la greybox garde 0,125 m) |

## Impact sur la performance
- **Appels de dessin** : un par structure et par matériau, plus les carreaux de sol et les objets proches. La distance de vue de 90 m coupe tout ce qui est noyé dans le brouillard. Visée : moins de 150 appels de dessin à l'endroit le plus chargé (budget 300).
- **Triangles** : 12 par bloc, quelques milliers en tout pour la greybox, très loin des 150 000.
- **Lumières** : lampadaires espacés d'environ 30 m, lumières des bâtiments de faible portée. On vérifie qu'on n'en voit jamais plus de 4 à moins de 25 m.
- **Chargement** : scène texte de quelques centaines de ko, maillage de navigation précalculé. Visée : moins de 2 s.
- **Mesure** : `tools/godot/measure_map.gd` charge la map avec le rendu OpenGL et relève appels de dessin, triangles et lumières visibles en plusieurs points. Les 60 images par seconde se confirment dans Chrome.

## Risques et alternatives
- **Le précalcul de l'éclairage (LightmapGI) demande une carte graphique** et le moteur Forward+ pour le calcul. Plan B : lumières dynamiques sans ombre limitées par la distance de vue, ou éclairage cuit dans les couleurs des sommets par un script.
- **Le maillage de navigation de 220 × 220 m est lourd à calculer** : cellules de 0,25 m, calcul fait une seule fois par le générateur, jamais au lancement.
- **Une map générée ne s'édite pas à la main** : c'est voulu pour garder une trace (2.6.6). Les retouches passent par le script.
- **Une si grande map peut être vide** (Q7) : 6 alarmes, rues qui ramènent au centre, et plusieurs proies IA possibles.

## Conformité à la constitution
- 1 unité = 1 m, joueur de 1,75 m, marches et pentes compatibles avec le déplacement de S-001.
- Aucun chiffre magique dans le code du jeu : les réglages de gameplay dans `data/`, la géométrie dans le générateur, qui joue le rôle d'un script d'asset.
- Orange réservé au bruit, brouillard en extérieur, textures en Nearest.
- Logique testable (alarme, apparitions, scan, chemins de l'IA, traversée en moins de 45 s) couverte par GUT, et chaque tâche vérifiée dans le build web (leçon de T-028).
- Une branche et une PR par tâche, commits `T-xxx: …`.
