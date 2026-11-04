# Tâches — S-003

- [x] T-013 — Clore S-002 et rédiger la spec, le plan et les tâches de S-003
  - Résultat vérifiable : S-002 marquée livrée, spec S-003 validée par Maxime, clarifications répondues
  - Dépend de : —
- [x] T-014 — Réglages et cerveau du monstre
  - Résultat vérifiable : `MonsterSettings` + `monster_settings.tres`, `MonsterBrain` (ronde, enquête, poursuite, recherche), tests GUT de chaque transition
  - Dépend de : T-013
- [x] T-015 — Scène du monstre, bâtiment de test et ronde
  - Résultat vérifiable : silhouette provisoire, petit bâtiment dans la greybox, maillage de navigation précalculé, le monstre fait sa ronde sans se coincer, tests GUT
  - Dépend de : T-014
- [x] T-016 — Ouïe et enquête
  - Résultat vérifiable : le monstre va vers les bruits qu'il entend (murs compris), fouille puis reprend sa ronde, tests GUT
  - Dépend de : T-015
- [ ] T-017 — Vue, poursuite et capture
  - Résultat vérifiable : jauge de repérage, poursuite, perte de vue et recherche, écran « Attrapé » traduit, retour au départ, tests GUT
  - Dépend de : T-016
- [ ] T-018 — Bruits et sons du monstre, debug
  - Résultat vérifiable : foulées et souffle du monstre dans `NoiseBus`, sons provisoires générés par le code et coupés au-delà de leur portée, état et jauge dans F3, cône dans F4, tests GUT
  - Dépend de : T-017
- [ ] T-019 — Playtest « est-ce amusant ? » (point de décision n°1)
  - Résultat vérifiable : Maxime joue 10 minutes, notes de playtest remplies, réglages ajustés, 60 images/s dans Chrome
  - Dépend de : T-018

## Compte rendu
- T-013 (04/11/2026) : S-002 marquée livrée (60 images/s confirmé par Maxime), spec, plan et tâches de S-003 rédigés (PR #17), propositions Q1 à Q6 validées par Maxime.
- T-014 (04/11/2026) : `MonsterSettings` + `monster_settings.tres` (valeurs Q1 à Q4 et D-009), `MonsterBrain` (ronde, enquête, poursuite, recherche, jauge de repérage, signal `state_changed`), 16 tests GUT, PR #18.
- T-015 (04/11/2026) : scène `Monster` (silhouette noire de 2,2 m, yeux pâles, couche « monstre »), petit bâtiment de deux pièces dans la greybox (deux portes, une fenêtre, murs sur la couche « murs »), maillage de navigation précalculé (`tools/godot/bake_navmesh.gd`), ronde de 4 points vérifiée sur 90 s simulées sans blocage, 8 tests GUT, PR #19.
- T-016 (04/11/2026) : le monstre écoute `NoiseBus` à hauteur d'oreille (2 m), ignore ses propres bruits, marche vers ce qu'il entend (murs compris), tourne sur lui-même en fouillant (`look_around_speed`), 6 tests GUT, PR #20.
