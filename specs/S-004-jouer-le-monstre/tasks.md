# Tâches — S-004

- [ ] T-020 — Clore S-003 et rédiger la spec, le plan et les tâches de S-004
  - Résultat vérifiable : spec S-004 validée par Maxime, clarifications Q1 à Q6 répondues
  - Dépend de : —
- [ ] T-021 — Écran de démarrage et monstre jouable
  - Résultat vérifiable : choix du rôle (éditeur et web), monstre à la première personne avec rôder, marcher et courir, ses pas et son souffle dans `NoiseBus`, tests GUT
  - Dépend de : T-020
- [ ] T-022 — Affichage des bruits avec leur distance
  - Résultat vérifiable : repères orange avec distance, visibles à travers les murs, effacés en 3 s, seulement pour les bruits entendus, tests GUT
  - Dépend de : T-021
- [ ] T-023 — Jauge et scan de bâtiment
  - Résultat vérifiable : `ScanGauge` (8 s, 45 s, 25 %, concentration 1 s), bâtiment scannable dans la greybox, bruits du bâtiment affichés en direct, monstre immobile, jauge pâle à l'écran, tests GUT
  - Dépend de : T-022
- [ ] T-024 — Lumières qui vacillent
  - Résultat vérifiable : deux lumières dans le bâtiment, qui vacillent pendant un scan sans message à l'écran, tests GUT
  - Dépend de : T-023
- [ ] T-025 — Proie IA
  - Résultat vérifiable : `PreyBrain` (promenade, fuite, cachette, figée), scène de la proie, pas dans `NoiseBus`, elle entend et voit le monstre, tests GUT
  - Dépend de : T-022
- [ ] T-026 — Souffle, réaction au scan, capture et debug
  - Résultat vérifiable : souffle de la proie essoufflée révélé par le scan, proie qui se fige à l'alerte une fois sur deux, écran « Attrapée » traduit, réapparition, F3 et F4 complétés, tests GUT
  - Dépend de : T-024, T-025
- [ ] T-027 — Playtest « traquer une proie IA »
  - Résultat vérifiable : Maxime joue le monstre 10 minutes, notes de playtest remplies, réglages ajustés, 60 images/s dans Chrome
  - Dépend de : T-026

## Compte rendu
