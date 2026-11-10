# Tâches — S-006

Ordre de Q8 : 1) greybox de toute la map, jouable, vérifiée ; 2) ajustements ; 3) habillage ; 4) éclairage et sons.
Maxime a demandé (10/11/2026) de ne pas être sollicité pour tester : chaque tâche est vérifiée par Claude (tests GUT, lint, import et export web, captures dans le rendu OpenGL et dans Chrome). Seuls les choix de style (rendus d'assets) lui sont montrés.

- [x] T-037 — Décision D-010 et spec S-006
  - Résultat vérifiable : spec validée, `plan-map.svg`
  - Dépend de : —
- [x] T-038 — Plan et tâches de S-006
  - Résultat vérifiable : `plan.md` et `tasks.md`
  - Dépend de : T-037
- [x] T-039 — Générateur de map et greybox extérieure
  - Résultat vérifiable : `build_tilleuls.gd` produit la cité 220 × 220 m (sol, limites, 7 barres, chemins, repères extérieurs, sortie fermée, lampadaires) ; classe commune `GameMap` ; le menu lance la cité ; apparition au hasard du chassé, monstre au sud-est ; tests GUT (taille, limites fermées, sol partout) ; build web vérifié dans Chrome
  - Dépend de : T-038
- [x] T-040 — Les 4 bâtiments visitables et les boxes
  - Résultat vérifiable : tour (R+4 visitable, grille), centre social, galerie, parking (rampe et escalier), boxes ; volumes de scan sur ces 5 cibles et pas sur les façades ; 4 emplacements de fusible par bâtiment ; tests GUT
  - Dépend de : T-039
- [x] T-041 — Navigation et IA à l'échelle de la cité
  - Résultat vérifiable : maillage de navigation de toute la map ; patrouille du monstre IA et routes de la proie IA dans les rues, la tour et le parking ; tests GUT des chemins (tour, parking, chaque emplacement de fusible) et de la traversée en courant en moins de 45 s
  - Dépend de : T-040
- [x] T-042 — Voitures à alarme
  - Résultat vérifiable : entité `CarAlarm`, action `interact` (E), 6 voitures sur la map, bruit de 30 m répété, repos, tests GUT (déclenchement, monstre IA attiré)
  - Dépend de : T-041
- [x] T-043 — Repères, distance de vue et mesure de performance
  - Résultat vérifiable : chaque repère a sa silhouette et sa lumière ; distance de vue réglable ; `measure_map.gd` relève appels de dessin, triangles et lumières aux endroits les plus chargés, sous le budget ; temps de chargement mesuré ; captures des repères dans le brouillard
  - Dépend de : T-042
- [x] T-044 — Ajustements de la greybox
  - Résultat vérifiable : corrections issues des vérifications de T-039 à T-043 (parcours d'un bot dans le build web, captures), notes de vérification dans la spec
  - Dépend de : T-043
- [x] T-045 — Habillage : tour et barres
  - Résultat vérifiable : modules de façade de S-005 posés sur les barres et la tour, nouveaux modules si besoin validés sur rendu, budget tenu
  - Dépend de : T-044
- [ ] T-046 — Habillage : galerie commerciale et centre social
  - Résultat vérifiable : modèles validés sur rendu, posés dans la cité
  - Dépend de : T-045
- [ ] T-047 — Habillage : parking, rampe et boxes
  - Résultat vérifiable : modèles validés sur rendu, posés dans la cité
  - Dépend de : T-046
- [ ] T-048 — Habillage : voitures, transformateur, aire de jeux et city stade
  - Résultat vérifiable : modèles validés sur rendu (balançoire comprise), posés dans la cité
  - Dépend de : T-047
- [ ] T-049 — Éclairage précalculé
  - Résultat vérifiable : éclairage cuit (LightmapGI ou plan B du plan), 4 lumières dynamiques visibles au plus, captures
  - Dépend de : T-048
- [ ] T-050 — Sons d'ambiance
  - Résultat vérifiable : vent, autoroute, train lointain, grincement de la balançoire, sons faits par nous ou CC0 (`CREDITS.md`), ils ne passent pas par le `NoiseBus` (ils ne trahissent personne)
  - Dépend de : T-049
- [ ] T-051 — Vérification finale de S-006
  - Résultat vérifiable : chaque critère d'acceptation vérifié et coché, notes dans la spec, spec livrée
  - Dépend de : T-050

## Compte rendu
- T-037 (07/11/2026) : décision D-010 et spec S-006 validée par Maxime (« Parfait »), PR #35.
- T-038 (10/11/2026) : plan et tâches de S-006. Maxime : « On peut passer aux tâches suivantes, j'aimerais ne pas être sollicité pour tester, je te fais confiance ».
- T-039 (10/11/2026) : la cité est générée par `tools/godot/build_tilleuls.gd` (lancé par la scène `build_tilleuls.tscn`, pour que les autoloads soient chargés) avec les briques de `map_kit.gd` : sol de terre battue en carreaux de 40 m, chemins en asphalte, talus de la voie ferrée avec le tunnel de sortie fermé par une grille, mur antibruit, grillages de chantier et de la friche, barres A à G (B percée d'un porche pour le chemin de la sortie), aire de jeux avec sa balançoire, city stade, transformateur vert, 18 lampadaires, bancs et arbres de S-005. Chaque structure a un maillage fusionné par matériau et des boîtes de collision (murs sur la couche `walls`). Maillage de navigation limité à l'intérieur des grillages (709 polygones, 1,4 s de calcul). La logique de `greybox_test.gd` devient la classe commune `GameMap` : apparition au hasard parmi 6 points pour le chassé (et la proie IA), monstre au sud-est. Le menu lance la cité. Nouvelle texture de terre battue (`make_textures.gd`). `tools/` sort de l'export web. 9 tests GUT (220 au total). Vérifié : rendu OpenGL de 9 points de vue (`measure_map.gd`, 27 à 103 appels de dessin) et build web dans Chrome (le menu lance la cité, la course fait monter la jauge, aucune erreur).
- T-040 (10/11/2026) : les 4 bâtiments visitables et les boxes, générés par `build_tilleuls.gd`. Tour : 24 × 24 m, R+12 vue de dehors avec un feu rouge au sommet, hall traversant nord-sud, local poubelles ouvert et local technique fermé, cage d'escalier en rampes (deux volées de 4 m par étage), 4 étages avec un couloir et 4 appartements dont 2 ouverts par palier (cloison et porte entre deux pièces), fenêtres, grille qui ferme l'escalier au 4e. Centre social : grande salle avec estrade et tables, couloir, 3 bureaux, entrées nord et ouest, lampe d'entrée. Galerie : arcade à piliers, 5 boutiques, laverie ouverte avec ses machines et son enseigne pâle, boutique au rideau à moitié levé (1,1 m : on passe accroupi, pas le monstre), couloir de livraison derrière avec portes vers ces deux boutiques et sortie à l'est. Parking : 3 m sous la dalle, piliers tous les 8 m, épaves, rampe à l'ouest avec son panneau « P », escalier de secours au sud-est avec garde-corps. Boxes : 6 garages, 2 ouverts. Volumes de scan (`Building`) sur ces 5 cibles, avec leurs lumières, et 4 emplacements de fusible par bâtiment visitable (groupe `fuse_slot`). Portes à 2,4 m de haut (au-dessus des 2,2 m du monstre) ; maillage de navigation avec une hauteur d'agent de 2 m (1 663 polygones). 7 tests GUT (227 au total) : seules les cibles de Q6 se scannent, les façades non, chaque emplacement est dans son bâtiment, sur un sol et atteignable par le monstre IA depuis une apparition, la grille arrête la montée au 4e. Vérifié sur captures du rendu OpenGL (hall, escalier, palier du 4e, parking, laverie, salle du centre social : 46 à 68 appels de dessin).
- T-041 (10/11/2026) : patrouille du monstre IA en 18 points (toutes les rues, la tour jusqu'au 4e, le parking, le centre social, la galerie et son couloir de livraison, les boxes, l'aire de jeux, le city stade), 12 points d'errance et 10 cachettes pour la proie IA, dont l'intérieur des bâtiments. Trois corrections trouvées en faisant vraiment marcher le monstre IA : le maillage de navigation flottait à 0,5 m au-dessus des sols, plus loin que la distance où l'agent valide un point de passage (le bas de la zone de calcul est maintenant calé pour qu'il soit à 0,26 m) ; dans l'escalier en épingle, l'agent coupait le virage contre le mur central (chemins par le milieu des passages, `path_postprocessing` « edge centered », et distance de passage de 1 m sur l'agent du monstre) ; les ouvertures du city stade étaient fermées. Ajustement du plan (Q2) : un porche de 6 m sous les barres A et E, comme sous la B, pour que la traversée nord-sud reste sous 45 s. Traversées mesurées sur le maillage à 5,5 m/s : nord-sud 40,0 s et 41,2 s, ouest-est 36,4 s et 42,9 s. 5 tests GUT (232 au total), dont une vraie marche du monstre IA avec la physique jusqu'au 4e de la tour, au fond du parking, dans un bureau du centre social et dans la boutique au rideau baissé (par le couloir de livraison).
- T-042 (10/11/2026) : entité `CarAlarm` (voiture grise en blocs, collision, deux feux de détresse pâles, jamais orange). Le chassé appuie sur **E** (nouvelle action `interact`) à moins de 3 m du centre de la voiture ; un message « E : déclencher l'alarme » s'affiche en bas de l'écran quand c'est possible (`InteractPrompt`, clé `HUD_INTERACT_CAR_ALARM`). L'alarme sonne 12 s : un bruit `CAR_ALARM` de 30 m chaque seconde par le `NoiseBus` (marqueur orange côté monstre, son de sirène provisoire côté chassé), puis se repose 45 s. Feux éteints = lumières cachées, sans coût de rendu. Réglages dans `car_alarm_settings.tres`. 6 voitures garées le long des rues (Q7), qui découpent le maillage de navigation. 7 tests GUT (239 au total), dont un monstre IA à 20 m qui part enquêter sur la voiture.
- T-043 (10/11/2026) : distance de vue de 90 m (`view_distance` dans `visual_settings.tres`, appliquée à toutes les caméras par `RetroWorld`) : au-delà, le brouillard ne laisse passer que 4 % d'un objet, et rien n'est dessiné. Repères : feu rouge au sommet de la tour, lampadaire juste au-dessus de la balançoire, enseigne pâle de la laverie, lampe d'entrée du centre social, panneau « P » du parking, transformateur vert éclairé, lumière froide du tunnel de sortie, nouveau lampadaire au city stade (il ne se voyait pas dans le brouillard). `measure_map.gd` relève chargement, appels de dessin, triangles et lumières visibles (dans le champ, à moins de 25 m de leur portée, pas derrière un mur) sur 15 points de vue, puis balaie la map tous les 20 m dans 4 directions. Résultats : chargement et instanciation de la map en 0,33 s ; 484 vues, 41 appels de dessin en moyenne, 70 au pire (près du parking, budget 300) ; 15 000 triangles au plus (budget 150 000) ; 2 lumières visibles au plus (budget 4) ; build web de 40 Mo (budget 60). Build web vérifié dans Chrome dans les deux rôles, sans erreur. Les 60 images/s restent à confirmer sur une vraie carte graphique : le Chrome du conteneur rend sans GPU. 2 tests GUT (241 au total).
- T-044 (10/11/2026) : le chassé apparaissait parfois face au mur d'une barre : chaque point d'apparition regarde maintenant la tour, et `GameMap` applique l'orientation du point tiré au chassé et à la proie IA. Nouveau test de parcours : un bot pilote le vrai contrôleur du chassé (actions `move_forward` et `sprint`, physique, en suivant le maillage de navigation) jusqu'au 4e de la tour, dans le parking par l'escalier de secours, et sous le rideau de la boutique accroupi (debout, il est arrêté à 1,5 m). Notes de vérification dans la spec. 4 tests GUT (245 au total).
- T-045 (10/11/2026) : rendus validés par Maxime (« Parfait j'aime beaucoup »). Les modules de façade de S-005 habillent les 7 barres et la tour (1 800 panneaux de 3 × 3 m, étirés au plus de 3 % pour tomber juste). `FacadeDressing` les dessine en un MultiMesh par mur et par module, sans collision (les murs de la greybox restent derrière). Rez-de-chaussée : une porte d'entrée tous les 18 m sur les grands côtés, moitié de fenêtres murées ; étages : colonnes de balcons (35 %), fenêtres allumées (15 %), tirage fixe pour que la cité ne change pas à chaque génération. Nouveau module « fenêtre ouverte » (sans vitre, 120 triangles, même texture) devant les vraies fenêtres des 4 étages visitables de la tour, recalées sur la grille de 3 m ; les entrées du hall restent libres. Mesures : 138 appels de dessin au pire sur 484 vues (budget 300), 20 000 triangles au plus, build web 40 Mo. 7 tests GUT (252 au total).
