# Plan — S-007

**Statut** : validé (10/11/2026, Maxime : « yes »)

## Approche technique

### Un chef d'orchestre : `GameLoop`
Nouvelle classe **`GameLoop`** (`game/session/game_loop.gd`), un nœud ajouté par `GameMap` quand la map a des emplacements de fusible (la cité ; la greybox de test n'en a pas et garde son comportement). Elle :
- tire les fusibles au début de la partie (Q1) : 3 bâtiments sur les 4, puis un emplacement sur les 4 de chaque bâtiment tiré, avec un `RandomNumberGenerator` à graine aléatoire (une graine fixe dans les tests) ;
- compte les fusibles portés et posés, et émet `fuses_changed(carried, placed)` ;
- ouvre la sortie quand les 3 fusibles sont posés (Q4) ;
- déclare la fin de partie : `ended(won: bool)`, avec les statistiques (durée, fusibles posés, bruits du chassé, scans du monstre) ;
- sert aussi au rôle monstre : le « chassé » qu'elle suit est alors la proie IA.

La logique pure (tirage, comptes, progression d'une pose avec la perte de moitié, statistiques) vit dans une classe sans scène, **`LoopRules`** (`RefCounted`), testable seule, comme `MonsterBrain` et `PreyBrain`.

### Les boîtiers à fusible
Nouvelle entité **`FuseBox`** (`game/entities/fuse_box/`) : un petit boîtier électrique mural posé sur chaque emplacement `fuse_slot` (16 en tout). Celui qui contient un fusible a une diode rouge : un petit maillage émissif non éclairé, visible dans le noir, et le brouillard le noie au-delà d'environ 8 m (on règle sa taille et son intensité pour ça). Pas de lumière dynamique : le budget de 4 lumières visibles ne bouge pas. Un boîtier vide n'a pas de diode et ne propose rien.

### Maintenir E : `HoldInteraction`
Les voitures à alarme s'activent d'un appui. Les boîtiers et le transformateur demandent de **maintenir** E (Q2, Q3). Le joueur garde sa recherche de cible (proximité + cône de visée de 35°) ; on ajoute :
- côté objet, une méthode `hold_time()` (0 pour une action immédiate) et `hold_finished(user)` ;
- côté joueur, un composant **`HoldInteraction`** qui avance un compteur tant que E est maintenu sur la même cible, le remet à zéro si la cible change ou si E est lâché, et appelle `hold_progress(user, ratio)` pour que l'objet fasse ses bruits ;
- côté écran, `InteractPrompt` dessine un anneau autour du point de visée qui se remplit avec la progression (Q2).

Le joueur continue de bouger pendant qu'il maintient E, mais s'il sort de portée ou détourne la visée, la cible change et la progression tombe.

### Le transformateur
Nouvelle entité **`Transformer`** (`game/entities/transformer/`), posée sur le modèle de T-048 :
- maintenir E 4 s par fusible porté (Q3) ; un bruit `REPAIR` de 8 m au début de chaque pose puis toutes les 1,5 s pendant la pose ;
- lâcher garde la moitié de la progression du fusible en cours (D-009) ; un fusible posé reste posé ;
- un texte au-dessus, « Le transformateur attend N fusibles », visible de près seulement (Q8) ;
- au troisième fusible : ronflement en boucle, sirène de 10 s dans toute la cité (bruit `SIREN` émis depuis le transformateur avec une portée qui couvre la map), puis `GameLoop` ouvre la sortie.

### La sortie
Le générateur sort la grille du tunnel de la structure `ExitTunnel` et en fait un nœud **`ExitGate`** à part (`AnimatableBody3D` + maillage), qui se lève de 3,6 m en 3 s quand la sortie s'ouvre. Un volume **`ExitZone`** (`Area3D`) au bout nord du tunnel déclare la victoire du chassé (ou de la proie IA) qui y entre. Avant l'ouverture, le maillage de navigation coupe le tunnel derrière la grille ; la proie IA n'a pas besoin d'y aller avant.

### Nouveaux bruits
`NoiseEvent.Type` gagne `FUSE` (métal du boîtier, 3 m), `REPAIR` (tôle et étincelles, 8 m) et `SIREN`. Les portées vivent dans un nouveau fichier de réglages **`game/data/loop_settings.tres`** (`LoopSettings`). Les sons sont synthétisés par nous (`tools/audio/loop_sounds.py`, numpy, comme l'ambiance de T-050) : claquement de boîtier, étincelles, ronflement, sirène.

### Fin de partie
- Le chassé attrapé : défaite immédiate en solo (Q5), plus de réapparition.
- Le chassé entre dans `ExitZone` : victoire.
- En rôle monstre, c'est l'inverse : proie attrapée = victoire du monstre, proie sortie = défaite.
- Nouvel **`EndScreen`** (`game/ui/end_screen.tscn`) : titre « Vous êtes sorti » ou « Attrapé » (ou leurs équivalents en monstre), durée, fusibles posés, bruits du chassé, scans du monstre (Q6). Boutons « Rejouer » (recharge la scène, donc nouveau tirage) et « Menu ». La souris est libérée, le jeu est en pause derrière.
- Le HUD « Fusibles n/3 » (Q8) est un petit `Label` en haut de l'écran, à la base 640 × 360 de D-011, absent en rôle monstre.

Les bruits du chassé se comptent en écoutant `NoiseBus` (les événements dont la source est le chassé), les scans en écoutant `scan_changed` des bâtiments.

### Le monstre IA (Q4, Q10)
`MonsterBrain` gagne :
- une **attirance** : il retient le dernier bâtiment où il a entendu du bruit et, en patrouille, y retourne de temps en temps (un passage sur trois points de patrouille) tant que ce souvenir a moins de 2 minutes ;
- un état **GUARD** quand la sirène sonne : il va au tunnel et patrouille entre l'entrée du tunnel et deux points proches. Un bruit ou la vue du chassé le font toujours passer en enquête ou en poursuite ; après, il revient garder.

### La proie IA (Q7)
`PreyBrain` reçoit une suite d'objectifs au lieu d'errer au hasard : **SEARCH** (aller vers les emplacements d'un bâtiment, un par un, dans l'ordre du plus proche), **COLLECT** et **REPAIR** (rester sur place le temps de la pose, avec les mêmes durées et les mêmes bruits que le joueur), puis **ESCAPE** vers la sortie. La proie ne sait pas quels boîtiers sont pleins : elle visite les emplacements et voit la diode d'un boîtier plein quand elle arrive près. Ses réactions de S-004 restent prioritaires : entendre ou voir le monstre interrompt l'action (avec la perte de moitié au transformateur), elle fuit, se cache, puis reprend son objectif.

## Données et réglages
| Réglage | Fichier | Valeur de départ |
|---|---|---|
| Fusibles à trouver | `loop_settings.tres` | 3 sur 4 bâtiments |
| Temps pour ramasser / bruit | `loop_settings.tres` | 2 s / 3 m |
| Temps par pose au transformateur / bruit | `loop_settings.tres` | 4 s / 8 m, toutes les 1,5 s |
| Progression gardée en lâchant une pose | `loop_settings.tres` | 50 % |
| Durée de la sirène / portée | `loop_settings.tres` | 10 s / 300 m |
| Temps de levée de la grille | `loop_settings.tres` | 3 s |
| Visibilité de la diode | `fuse_box.tscn` | environ 8 m dans le noir |
| Souvenir d'un bâtiment bruyant | `monster_settings.tres` | 120 s |

## Impact sur la performance
- 16 boîtiers : un petit maillage chacun (une vingtaine de triangles), regroupés par le générateur si les appels de dessin montent. Les diodes n'ajoutent aucune lumière.
- La grille devient un appel de dessin à part ; le transformateur garde son modèle.
- Le HUD et l'écran de fin : quelques nœuds `Control`.
- Les sons sont des WAV mono 22 kHz, quelques centaines de ko.
- On relance `measure_map.gd` à la fin de la phase : le pire point doit rester sous 300 appels de dessin (192 aujourd'hui) et 4 lumières visibles.

## Vérification
Comme en S-006, Claude vérifie seul : tests GUT de chaque règle, lint, import, export web, captures dans le rendu OpenGL et dans Chrome. Pour la durée des parties (critère 8 à 12 min), un script de simulation (`tools/godot/simulate_games.gd`) fait jouer la proie IA contre le monstre IA, accéléré, sur une vingtaine de parties, et relève durées, victoires et blocages. Un bot joue aussi le chassé dans le build web pour vérifier la boucle de bout en bout.
