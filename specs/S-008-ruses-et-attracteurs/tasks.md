# Tâches — S-008

Comme pour S-007, chaque tâche est vérifiée par Claude (tests GUT, lint, import et export web, captures dans le rendu OpenGL et dans Chrome). Seuls les choix de style (modèles, sons) sont montrés à Maxime.

- [x] T-061 — Spec S-008
  - Résultat vérifiable : spec validée
  - Dépend de : —
- [x] T-062 — Plan et tâches de S-008
  - Résultat vérifiable : `plan.md` et `tasks.md`
  - Dépend de : T-061
- [x] T-063 — Ramasser et lancer une bouteille
  - Résultat vérifiable : `RuseSettings`, `Inventory`, `Pickup`, action `throw`, `ThrownBottle` avec bruit `IMPACT` de 8 m, constante `Interactable.GROUP`, HUD « n bouteilles » ; tests GUT (inventaire, portée balistique, impact) ; quelques bouteilles dans la greybox
  - Dépend de : T-062
- [x] T-064 — Le réveil-leurre
  - Résultat vérifiable : `DecoyTimer`, entité `Decoy`, action `place_decoy`, bruit `DECOY`, `crush()` par le monstre IA et le monstre joueur, HUD « Réveil » ; tests GUT
  - Dépend de : T-063
- [x] T-065 — Les cachettes
  - Résultat vérifiable : entité `HidingSpot`, état caché du joueur (caméra, regard limité, cadre `HideMask`), invisibilité pour les deux monstres, souffle toujours entendu au scan, « Ouvrir » pour le monstre joueur ; tests GUT
  - Dépend de : T-063
- [x] T-066 — Le monstre IA face aux ruses
  - Résultat vérifiable : état `OPEN`, `saw_hide`, fouille après une poursuite perdue, écrasement des réveils ; tests GUT
  - Dépend de : T-064, T-065
- [ ] T-067 — Placement dans la cité des Tilleuls
  - Résultat vérifiable : 20 bouteilles, 10 emplacements de réveil (4 tirés par partie), 12 placards et 6 bennes générés par `build_tilleuls`, navigation vérifiée autour de chaque cachette ; tests GUT
  - Dépend de : T-066
- [x] T-068 — La proie IA rusée
  - Résultat vérifiable : ramasser, lancer, poser un leurre, se cacher, déclencher une alarme ; tests GUT ; simulation qui compte les ruses
  - Dépend de : T-067
- [ ] T-069 — Modèles des ruses
  - Résultat vérifiable : `tools/blender/ruses.py`, bouteille, réveil, placard, benne, éclats ; rendus montrés à Maxime puis intégrés
  - Dépend de : T-067
- [x] T-070 — Sons des ruses
  - Résultat vérifiable : `tools/audio/ruse_sounds.py`, bris de verre, tic-tac, sonnerie, craquement, placard, benne, faits par nous (`CREDITS.md`), montrés à Maxime
  - Dépend de : T-069
- [ ] T-071 — Vérification finale de S-008
  - Résultat vérifiable : simulation de 20 parties (ruses utilisées, sorties, blocages), mesure de performance, chaque critère d'acceptation coché, spec livrée
  - Dépend de : T-068, T-070

## Compte rendu
- T-061, T-062 (12/11/2026) : spec, plan et tâches écrits, validés par Maxime (« Tout valider »), Q-004 close.
- T-063 (12/11/2026) : `RuseSettings`, `Inventory`, `Pickup`, `ThrownBottle` (bruit `IMPACT` de 8 m, bris de verre provisoire), action `throw` au clic gauche, `CarryHud`, groupe commun `Interactable.GROUP`, 3 bouteilles dans la greybox ; tests GUT dans `test_bottles.gd`.
- T-064 (12/11/2026) : `DecoyTimer`, entité `Decoy` (tic-tac à 1,5 m pour les oreilles seulement, puis bruit `DECOY` de 12 m chaque seconde pendant 10 s), `Pickup` réveil, action `place_decoy` au clic droit, `Decoy.crush_near` appelé par le monstre IA et le monstre joueur ; sons provisoires générés par code ; tests GUT dans `test_decoys.gd`.
- T-065 (12/11/2026) : entité `HidingSpot` (placard et benne provisoires), entrer, sortir et ouvrir en maintenant E 1 s avec un bruit `HIDE` de 3 m, état caché du joueur (corps immobile sans collision, regard limité à ±40° et ±20°, `HideMask`), invisible et intouchable pour le monstre IA, « Ouvrir » pour le monstre joueur, capture branchée dans `GameMap`. Le souffle du joueur après un sprint (D-009) manquait : ajouté dans `Player`, caché ou non. Fait dans la même PR que T-064, les deux touchant les mêmes fichiers. Tests GUT dans `test_hiding_spots.gd`.
- T-066 (12/11/2026) : état `OPEN` de `MonsterBrain` (va à la cachette en courant, sourd aux bruits le temps d'ouvrir, puis fouille), signal `chase_lost`, `Monster.go_open` quand il a vu le chassé entrer, et une fois sur deux après une poursuite perdue à moins de 8 m d'une cachette (`MonsterSettings`). Il ouvre en maintenant comme un joueur (même durée, même bruit). L'écrasement des réveils était déjà fait en T-064. Tests GUT dans `test_monster_ruses.gd`.
- T-068 (12/11/2026) : la proie IA a un inventaire et utilise chaque ruse (Q9) : détour de 6 m au plus pour ramasser pendant sa recherche, bouteille lancée à 12–18 m à l'opposé de son objectif quand elle part en fuite (si le monstre est à plus de 8 m), cachette libre à moins de 10 m hors de la vue du monstre, alarme de voiture déclenchée en passant pendant la fuite, réveil posé entre 30 et 20 m du transformateur puis attente de la sonnerie. `ThrownBottle.speed_for_range` pour viser. Compteur `ruse_used` sur le joueur et la proie, « Ruses utilisées » sur l'écran de fin, ruses comptées par la simulation. Tests GUT dans `test_prey_ruses.gd`. Placée avant T-067 car elle n'a pas besoin de la cité régénérée.
- T-070 (12/11/2026) : `tools/audio/ruse_sounds.py` synthétise 6 sons (bris de verre, tic-tac et sonnerie en boucle, réveil écrasé, porte de casier, couvercle de benne) dans `assets/audio/ruses/` ; ils remplacent les sons provisoires générés par code, retirés de `PlaceholderSounds`. Faits par nous (`CREDITS.md`), montrés à Maxime. Fait avant T-069 : les sons ne dépendent pas des modèles.
