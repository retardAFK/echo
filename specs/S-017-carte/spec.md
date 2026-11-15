# S-017 — Carte des chassés

**Statut** : livrée (15/11/2026)
**Piliers servis** : P2 (le dilemme permanent), P3 (l'inquiétante familiarité)
**Phase** : hors feuille de route, demandée par Maxime le 15/11/2026 (« peux-tu rajouter une option MAP pour les chassés ? Juste la map, sans indice pour les fusibles »)

## Pourquoi
La cité des Tilleuls fait 220 × 220 m, de nuit, dans le brouillard. Sans carte (S-007, Q8), un nouveau joueur se perd et ne retrouve pas les bâtiments dont parlent ses coéquipiers sur Discord. Une carte du quartier, comme le plan affiché à l'entrée d'une cité, aide à s'orienter sans rien dire de l'objectif : chercher les fusibles reste le travail du chassé.

## Ce que vit le joueur
**En chassé**, j'appuie sur **Tab** : le plan de la cité s'affiche par-dessus le jeu. Je vois la voie ferrée au nord, l'autoroute à l'est, les barres A à G, la tour, le centre social, la galerie, le parking, les garages, l'aire de jeux, le city stade et les allées. Une flèche ocre me montre où je suis et dans quelle direction je regarde. Rien n'indique où sont les fusibles. La partie continue pendant que je lis le plan : je peux encore marcher, mais je regarde moins autour de moi. Tab referme la carte.

**En monstre**, je n'ai pas de carte.

## Critères d'acceptation
- [x] Tab (touche réglable dans Options › Touches) ouvre et ferme la carte, en solo comme en ligne.
- [x] Le plan montre les bords, les allées, les bâtiments et leurs noms, une grille de 20 m et le nord.
- [x] La position et la direction du joueur sont affichées ; celles des coéquipiers et du monstre ne le sont pas.
- [x] Aucun indice : ni fusible, ni transformateur nommé, ni sortie nommée, et tous les bâtiments ont le même aspect, visitables ou non.
- [x] Le monstre n'a pas de carte.
- [x] La carte se ferme à la pause, à la fin de la partie, et quand le chassé éliminé passe en spectateur.
- [x] La touche apparaît dans la liste des contrôles (pause).

## Clarifications
Choix faits par Claude à partir de la demande, à revoir si Maxime le souhaite :
- Q1 : Qui a la carte ? → Les chassés seulement, en solo et en ligne. Le monstre a déjà le scan et la vue des bruits.
- Q2 : Que montre la carte ? → Le lieu et « vous êtes ici », rien d'autre : pas de fusible, pas d'objectif, pas de coéquipier. Le transformateur et le tunnel de sortie sont dessinés sans nom, comme n'importe quel bâti. Tous les bâtiments ont la même couleur, pour ne pas désigner ceux où un fusible peut se trouver (D-010).
- Q3 : Le jeu s'arrête-t-il quand la carte est ouverte ? → Non : la partie continue et le chassé peut bouger. Lire le plan est un risque de plus, pas une pause.
- Q4 : Quelle touche ? → Tab, parce que M n'est pas à la même place en AZERTY et en QWERTY (les touches sont physiques). Elle se change dans les options.

## Plan
- `game/maps/map_plan.gd` (`MapPlan`) : le plan d'une map, des rectangles vus de dessus avec leur nature et leur nom, rangé à côté de la scène (`<map>_plan.tres`). Une map sans plan (la greybox) n'a pas de carte.
- `tools/godot/build_map_plan.gd` : fait `game/maps/tilleuls/tilleuls_plan.tres` à partir des mêmes chiffres que `build_tilleuls.gd` ; un test GUT vérifie que le plan enregistré est à jour.
- `game/ui/map_view.gd` (`MapView`) dessine le plan ; `game/ui/map_screen.tscn` (`MapScreen`) l'ouvre et le ferme. `GameMap` l'ajoute au chassé en solo et au client chassé en ligne.

## Tâches
- [x] T-250 — Spec S-017
- [x] T-251 — Plan de la cité (`MapPlan`, outil, test d'actualité)
- [x] T-252 — Écran carte, touche, contrôles, branchement solo et en ligne ; tests GUT

## Compte rendu
- T-250 à T-252 (15/11/2026) : livrées ensemble, 14 tests GUT (`tests/test_map_screen.gd`). Rendu vérifié par capture (OpenGL sous Xvfb).
