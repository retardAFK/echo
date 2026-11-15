# Plan — S-016

**Statut** : proposé par Claude (15/11/2026), sur la spec validée par Maxime le 15/11/2026

## Approche technique

### Les portes : `Door`
Nouvelle entité **`Door`** (`game/entities/door/`, scène + script du même nom). Un `Node3D` posé au milieu de la baie, son battant pivote autour d'un gond (charnière). Le battant est un **`AnimatableBody3D`** :
- **fermé**, il est sur les couches *monde* (1) et *murs* (2) : il bloque les corps, coupe la vue (`MonsterVision.SIGHT_MASK`, `NetGame.sees`) et compte comme un mur pour `NoiseBus.walls_between` (÷2, Q1). Rien de neuf à coder dans la vue ni dans le bruit : la porte fermée **est** un mur ;
- **ouvert**, il tourne de 90° en 0,3 s et ne garde que la couche *monde* : il reste un obstacle physique contre le mur, mais n'atténue plus le bruit.
La porte est dans le groupe `interactable` et dans un groupe `doors`. Pour le chassé (`Player`, `Prey`) :
- appui sur E **debout** : `interact()` ouvre ou ferme tout de suite, bruit **`DOOR`** de 6 m (nouveau type de `NoiseEvent`) ;
- **accroupi** : `hold()` comme les cachettes (`HoldInteraction`), 1 s, bruit `DOOR` de 2 m.
Pour le monstre (`MonsterAvatar`, `Monster`) : même chose avec E ; en **rôdant** (son « accroupi ») c'est la version lente et discrète. En **course**, une porte fermée juste devant lui (moins de 1,2 m dans sa direction) est **défoncée** (`smash()`) : ouverte d'un coup, bruit de **12 m** (Q2).
La porte ne fait pas partie du groupe `navigation_source` : le maillage passe par la baie, porte ouverte ou fermée.

### Les portes et les IA
Une classe pure **`DoorPath`** répond à « quelle porte fermée se trouve sur ce segment de chemin, à moins de 1,5 m » (intersection du segment avec la baie). `Monster` et `Prey` l'appellent à chaque pas vers leur prochain point de chemin :
- **monstre IA** : en poursuite, il défonce ; sinon il ouvre debout (0,3 s d'arrêt) ;
- **proie IA** : elle ouvre debout ; en fuite, elle **referme** derrière elle si le monstre ne la voit pas (règle simple, testée seule) ; elle n'utilise pas la version accroupie.

### Coupe-feu, issues de secours, métal (Q3, Q9)
`Door` a un `kind` : `NORMAL`, `FIRE` (se referme seule `fire_close_delay` 3 s après la dernière ouverture, claquement `DOOR` de 5 m), `EMERGENCY` (ne s'ouvre que depuis le côté intérieur, défini par le sens de la porte, bruit de 10 m, ne se referme pas). Le **métal** : une `Area3D` « surface métal » sur l'escalier de secours et les échelles ; `FootstepEmitter` multiplie la portée de la marche et de la course par `metal_factor` (1,5 : 4 → 6 m, 14 → ≈ 18 m, Q9) quand le chassé est dedans, l'accroupi reste à 1 m.

### Les échelles
Nouvelle entité **`Ladder`** : une zone où avancer fait monter et reculer descendre (vitesse de la marche, bruit de métal). Le maillage relie le haut et le bas par un **`NavigationLink3D`** pour que les deux IA s'en servent.

### Les cachettes (Q6)
`HidingSpot` reçoit une **`family`** (`CLOSET`, `LOW`, `MAKESHIFT`, `METAL`) qui lit ses durées et bruits dans `RuseSettings` :
| Famille | Entrer / sortir | Bruit | Le monstre ouvre en | Particularité |
|---|---|---|---|---|
| Placard, benne | 1 s | 3 m | 1 s | — |
| Basse | 2 s, accroupi | 1 m | 1 s | sortie lente |
| De fortune | 0,5 s | aucun | 1 s | vue par un monstre à moins de 2 m qui la regarde |
| En métal | 1 s | 6 m | 2 s | — |
« Vu » pour une cachette de fortune : la vue des monstres (`Monster._update_sight`, `MonsterAvatar`, `NetGame.sees`) traite un chassé caché dans une cachette de fortune comme visible s'il est à moins de `makeshift_reveal` (2 m) et dans le cône de vue. Les nouvelles scènes (`low_spot.tscn`, `makeshift_spot.tscn`, `metal_spot.tscn`, une par modèle) réutilisent le script.

### Les bâtiments
Tout passe par le générateur `tools/godot/build_tilleuls.gd`, découpé en un fichier par bâtiment pour rester lisible (`tools/godot/tilleuls/tower.gd`, etc.). Les portes y sont posées par une fonction `kit.door(...)` qui laisse la baie dans le mur et ajoute l'entité `Door`. Les plans de la spec sont suivis à 1 m près ; le couloir des caves est à −3 m, sous le terrain (le sol de la cité y reçoit un trou caché par la dalle). Le volume de scan du parking s'étend au couloir (Q5), celui de la tour à son escalier des caves.

### Réseau
`NetWorld` liste les portes comme les autres objets (même ordre des deux côtés) et ajoute à `state()` l'état de chaque porte (ouverte ou fermée). Un client qui reçoit un changement joue le bruit de la porte chez lui. Le monstre client et le chassé client envoient leur appui sur E comme aujourd'hui ; la salle décide.

### Mobilier, sons, éclairage
- Mobilier par script Blender (`tools/blender/interiors.py`) : lit, canapé, table, frigo, cartons, chaises empilées, comptoir, rayonnages, sèche-linge, cabine d'ascenseur, porte, porte coupe-feu, escalier métallique, échelle. Rendus montrés à Maxime avant intégration. Les meubles répétés passent par `FacadeDressing` (un `MultiMesh` par modèle).
- Sons synthétisés (`tools/audio/interior_sounds.py`) : porte qui grince, porte qui claque, coupe-feu, barre anti-panique, rideau métallique, clochette, marches en métal.
- Éclairage précalculé comme en T-049 ; une lumière dynamique au plus par bâtiment.

## Données et réglages
| Réglage | Fichier | Valeur |
|---|---|---|
| Bruit d'une porte debout / accroupi / défoncée | `door_settings.tres` (nouveau) | 6 / 2 / 12 m |
| Ouverture accroupie | `door_settings.tres` | 1 s |
| Coupe-feu : délai, claquement | `door_settings.tres` | 3 s, 5 m |
| Issue de secours | `door_settings.tres` | 10 m |
| Défoncer : distance devant le monstre | `door_settings.tres` | 1,2 m |
| Facteur du métal | `noise_settings.tres` | 1,5 |
| Cachettes par famille | `ruse_settings.tres` | tableau ci-dessus |
| Cachette de fortune : distance où elle se voit | `ruse_settings.tres` | 2 m |
| Emplacements de fusible par bâtiment | `build_tilleuls.gd` | 6 |

## Impact sur la performance
- **Appels de dessin** : le pire endroit est à 254 sur 300. Chaque meuble répété est un `MultiMesh` (1 appel par modèle et par bâtiment), les portes aussi. Les intérieurs reçoivent un `visibility_range_end` de 30 m. Mesure avec `measure_map` à chaque bâtiment ; si un point dépasse 280, on retire du mobilier.
- **Triangles** : meubles de 50 à 300 triangles ; marge large (150 000).
- **Physique** : une quarantaine de portes, des corps statiques ; aucun coût par image hors ouverture.
- **Réseau** : un tableau de booléens de plus dans l'état du monde, envoyé au changement.

## Risques et alternatives
- **Navigation à travers les portes** : si les IA restent bloquées contre un battant, plan B : le battant ouvert n'a plus de collision du tout.
- **Le trou dans le terrain pour le couloir des caves** : le terrain est en dalles de 40 m ; il faudra découper la dalle concernée comme pour le parking.
- **Durée des parties** : plus de cachettes et d'issues aident les chassés ; on vérifie par simulation que la durée moyenne ne baisse pas et que le taux de sortie reste proche de 50 %.

## Conformité à la constitution
- Une scène par entité (`Door`, `Ladder`, cachettes), réglages dans `data/`, bruits par `NoiseBus`, signaux entre entités : respecté.
- Assets faits par nous (scripts Blender et sons générés) : respecté.
- Budget : surveillé à chaque bâtiment (voir plus haut).
