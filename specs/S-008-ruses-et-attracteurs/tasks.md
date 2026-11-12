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
- [ ] T-064 — Le réveil-leurre
  - Résultat vérifiable : `DecoyTimer`, entité `Decoy`, action `place_decoy`, bruit `DECOY`, `crush()` par le monstre IA et le monstre joueur, HUD « Réveil » ; tests GUT
  - Dépend de : T-063
- [ ] T-065 — Les cachettes
  - Résultat vérifiable : entité `HidingSpot`, état caché du joueur (caméra, regard limité, cadre `HideMask`), invisibilité pour les deux monstres, souffle toujours entendu au scan, « Ouvrir » pour le monstre joueur ; tests GUT
  - Dépend de : T-063
- [ ] T-066 — Le monstre IA face aux ruses
  - Résultat vérifiable : état `OPEN`, `saw_hide`, fouille après une poursuite perdue, écrasement des réveils ; tests GUT
  - Dépend de : T-064, T-065
- [ ] T-067 — Placement dans la cité des Tilleuls
  - Résultat vérifiable : 20 bouteilles, 10 emplacements de réveil (4 tirés par partie), 12 placards et 6 bennes générés par `build_tilleuls`, navigation vérifiée autour de chaque cachette ; tests GUT
  - Dépend de : T-066
- [ ] T-068 — La proie IA rusée
  - Résultat vérifiable : ramasser, lancer, poser un leurre, se cacher, déclencher une alarme ; tests GUT ; simulation qui compte les ruses
  - Dépend de : T-067
- [ ] T-069 — Modèles des ruses
  - Résultat vérifiable : `tools/blender/ruses.py`, bouteille, réveil, placard, benne, éclats ; rendus montrés à Maxime puis intégrés
  - Dépend de : T-067
- [ ] T-070 — Sons des ruses
  - Résultat vérifiable : `tools/audio/ruse_sounds.py`, bris de verre, tic-tac, sonnerie, craquement, placard, benne, faits par nous (`CREDITS.md`), montrés à Maxime
  - Dépend de : T-069
- [ ] T-071 — Vérification finale de S-008
  - Résultat vérifiable : simulation de 20 parties (ruses utilisées, sorties, blocages), mesure de performance, chaque critère d'acceptation coché, spec livrée
  - Dépend de : T-068, T-070

## Compte rendu
- T-061, T-062 (12/11/2026) : spec, plan et tâches écrits, validés par Maxime (« Tout valider »), Q-004 close.
- T-063 (12/11/2026) : `RuseSettings`, `Inventory`, `Pickup`, `ThrownBottle` (bruit `IMPACT` de 8 m, bris de verre provisoire), action `throw` au clic gauche, `CarryHud`, groupe commun `Interactable.GROUP`, 3 bouteilles dans la greybox ; tests GUT dans `test_bottles.gd`.
