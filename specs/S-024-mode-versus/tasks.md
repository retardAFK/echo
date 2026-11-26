# Tâches — S-024

Bloc de numéros : T-370 à T-399.

## Spec et prototype (accord de Maxime du 26/11/2026)
- [ ] T-370 — Spec S-024, plan, tâches, ligne du backlog
  - Résultat vérifiable : fusionnés ; résumé présenté à Maxime
  - Dépend de : —
- [ ] T-371 — Règles pures du Versus : `BossHealth`, `HuntedVitals`, `VersusRules`, `Stamina`, `ShotMath`, réglages `versus_settings.tres`
  - Résultat vérifiable : tests GUT (phases, posture, rage, à terre, relevé, achevé, victoire des deux camps, chrono, traqué)
  - Dépend de : T-370
- [ ] T-372 — Prototype chassé : lance-fusées, fusée en arc, touche corps et visage, bras à la première personne (formes simples), croix de touche, roulade, endurance, barre du boss, vie du chassé
  - Résultat vérifiable : tests GUT (tir, touche, roulade) ; capture de la vue
  - Dépend de : T-371
- [ ] T-373 — Prototype boss : bras griffus, griffe, charge, phases, rage et Fureur, boss IA qui griffe et charge le joueur (mannequin de la salle d'essai)
  - Résultat vérifiable : tests GUT (griffe, charge contre un mur, changement de phase) ; capture
  - Dépend de : T-371
- [ ] T-374 — Salle d'essai › Versus : entrée de menu, F6 pour jouer chassé ou boss, victoire et défaite qui relancent la salle ; doc du module
  - Résultat vérifiable : test GUT qui ouvre la salle en Versus dans les deux rôles ; `docs/MODULES.md` (ajouter ou retirer le mode, une arme, une attaque, une phase)
  - Dépend de : T-372, T-373

## Après validation de la spec
- [ ] T-375 — `GameSession.mode` et choix du mode dans le salon et dans « Jouer seul »
- [ ] T-376 — Arène dans la cité (barrières, murets, caisses de fusées) par fichier d'arène ; budget d'appels de dessin mesuré
- [ ] T-377 — Outils au choix : lampe UV, canon sonique, trousse ; pétards et fumigène branchés sur la posture
- [ ] T-378 — À terre, relevé, achever, hors combat (Q5)
- [ ] T-379 — Bond, cri et lampadaires éteints, phase 3 (Q8, Q9)
- [ ] T-380 — Chrono, aube, boss traqué, victoire et écran de fin avec MVP (Q1 à Q4, Q28)
- [ ] T-381 — En ligne : commandes, état `versus`, événements, salle qui fait autorité ; robots `net_versus` en CI
- [ ] T-382 — Boss IA (`BossBrain`)
- [ ] T-383 — Chassé IA (`PreyFighter`)
- [ ] T-384 — Équilibre : 20 parties simulées par effectif (2, 3, 4 chassés)
- [ ] T-385 — Modèles des bras et armes (`tools/blender/viewmodels.py`), lance-fusées dans la main du modèle du chassé, gestes du boss ; montrés à Maxime
- [ ] T-386 — Sons : tir, touche, visage, roulade, cri, charge, musique de combat ; montrés à Maxime
- [ ] T-387 — Guide du jeu, `docs/`, vérification finale (budgets, critères)

## Compte rendu
