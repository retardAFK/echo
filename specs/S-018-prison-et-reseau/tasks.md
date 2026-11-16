# Tâches — S-018

Chaque tâche est vérifiée par Claude (tests GUT, lint, import et export web, simulations, captures). Les rendus des modèles et les sons sont montrés à Maxime sans bloquer la suite. Chaque tâche branche aussi ce qu'elle ajoute sur le réseau en ligne ; T-267 vérifie l'ensemble à 4 clients.

- [x] T-260 — Spec S-018
  - Résultat vérifiable : spec validée par Maxime (libération sur place ou à distance, outils et quêtes tirées au sort)
  - Dépend de : —
- [x] T-261 — Plan et tâches de S-018
  - Résultat vérifiable : `plan.md` et `tasks.md`, emplacements des cages, des terminaux, des caméras, des haut-parleurs et des rideaux sur le plan de la cité
  - Dépend de : T-260, fin de S-016
- [x] T-262 — La prison
  - Résultat vérifiable : `Prison`, `Cage`, `PrisonRules`, `PrisonSettings` ; capture → écran noir → cage ; libération sur place (E 4 s, une cage, 8 m) ; séjours de 120 s puis 60 s, élimination à la 3e prise, chrono arrêté quand le monstre est à moins de 15 m ; lampe qui clignote ; victoire du monstre quand tous sont en prison ou éliminés ; solo inchangé ; état en ligne ; tests GUT
  - Dépend de : T-261
- [ ] T-263 — Terminaux et caméras
  - Résultat vérifiable : `CityNetwork`, `Terminal`, `SecurityCamera`, `NetworkSettings`, menu du terminal, action `PICK` ; s'installer (E 1 s, clavier 3 m, écran qui éclaire), voir une caméra en vert ; LED rouge, caméra cassée par le monstre (10 m) ; le monstre éteint un terminal 60 s ; vue des caméras pour le prisonnier ; position des autres envoyée seulement s'ils sont vus ; tests GUT
  - Dépend de : T-262
- [ ] T-264 — Terminal du gardien
  - Résultat vérifiable : ouvre toutes les cages en 10 s, sonnerie de 15 m à la prison ; arrêté si on part ou si le monstre l'éteint ; tests GUT
  - Dépend de : T-263
- [ ] T-265 — Haut-parleurs et rideaux métalliques
  - Résultat vérifiable : `Loudspeaker` (25 m, 5 s, une fois chacun) et `RemoteShutter` (20 s, 12 m, recharge 60 s, bloque et coupe la vue) ; tests GUT
  - Dépend de : T-263
- [ ] T-266 — Quêtes tirées au sort
  - Résultat vérifiable : 3 objectifs par partie parmi fusible, code, téléchargement et relais (au moins un fusible, pas deux fois le même autre type) ; code et clavier du transformateur, téléchargement et disquette, interrupteurs de relais ; liste sur l'écran de la carte (Tab), sans position ; solo et en ligne ; tests GUT
  - Dépend de : T-263
- [ ] T-267 — Synchronisation en ligne
  - Résultat vérifiable : prison, terminaux, caméras, haut-parleurs, rideaux et objectifs synchronisés ; un chassé ne reçoit jamais la position d'un autre, sauf ce qu'il voit lui-même ou sur une caméra ; test à 4 clients (`net_match` étendu)
  - Dépend de : T-264, T-265, T-266
- [ ] T-268 — IA
  - Résultat vérifiable : le monstre IA casse les caméras allumées, éteint les terminaux et passe voir la prison ; la proie IA fait les nouveaux objectifs, libère sur place et utilise les haut-parleurs ; 20 parties simulées sans blocage, durée moyenne qui ne baisse pas
  - Dépend de : T-266
- [ ] T-269 — Modèles et sons
  - Résultat vérifiable : terminal, caméra, haut-parleur, rideau, grille et lampe de cage, interrupteur, disquette, tableau et post-it ; clavier, disque dur, sonnerie, rideau, grille, bip, déclic, caméra cassée ; rendus et sons montrés à Maxime
  - Dépend de : T-261
- [ ] T-270 — Vérification finale de S-018
  - Résultat vérifiable : critères cochés, budget de 300 appels de dessin tenu au pire endroit, 60 images/s mesurées sur la machine de référence (avec la mesure de T-128)
  - Dépend de : T-267, T-268, T-269

## Compte rendu
- T-260 (15/11/2026) : spec validée par Maxime, PR #134 (D-020).
- T-261 (16/11/2026) : plan et tâches. Terminal du gardien déplacé du centre social à la galerie pour tenir les 80 m de Q4.
- T-262 (16/11/2026) : `Prison`, `Cage`, `PrisonRules`, `PrisonSettings`, `PrisonHud`. Trois caves du couloir des caves deviennent les cages (portillon d'un mètre dans la grille, lampe au-dessus). En ligne, 2 s après la prise, le chassé est posé dans une cage libre ; ses fusibles restent où il a été pris. Libération à la grille (E 4 s, bruit `CAGE` de 8 m), séjours de 120 s puis 60 s, chrono arrêté à moins de 15 m du monstre, éliminé à la 3e prise ou à la fin du séjour. Plus de cri d'appel en prison. `Prison.open_all()` (sonnerie `BELL` de 15 m) est prêt pour le terminal du gardien. L'état des cages passe dans `NetWorld.state()[6]`. Solo inchangé. 10 tests GUT, tests de capture, de départ et d'IA de remplacement mis à la nouvelle règle.
