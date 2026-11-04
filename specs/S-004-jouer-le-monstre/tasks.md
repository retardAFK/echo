# Tâches — S-004

- [x] T-020 — Clore S-003 et rédiger la spec, le plan et les tâches de S-004
  - Résultat vérifiable : spec S-004 validée par Maxime, clarifications Q1 à Q6 répondues
  - Dépend de : —
- [x] T-021 — Écran de démarrage et monstre jouable
  - Résultat vérifiable : choix du rôle (éditeur et web), monstre à la première personne avec rôder, marcher et courir, ses pas et son souffle dans `NoiseBus`, tests GUT
  - Dépend de : T-020
- [x] T-022 — Affichage des bruits avec leur distance
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
- T-020 (04/11/2026) : S-003 close (PR #23), spec, plan et tâches de S-004 rédigés (PR #24), propositions Q1 à Q6 retenues (Maxime : « Peux-tu tester toi-même ? »).
- T-021 (04/11/2026) : écran de démarrage `StartMenu` (scène principale, boutons traduits), rôle gardé dans `GameSession`, la greybox remplace le chassé et le monstre IA par `MonsterAvatar` en rôle monstre, monstre à la première personne (marcher, Maj pour courir, C pour rôder), bruits partagés avec le monstre IA dans `MonsterNoise`, `PlayerEars` réutilisé pour que le monstre entende la proie, deuxième Échap pour revenir au menu, 10 tests GUT. Écart : rôder se fait avec C (la touche d'accroupissement) plutôt que Ctrl, qui ferme l'onglet avec W dans le navigateur.
- T-022 (04/11/2026) : `NoiseMarkers` (couche d'interface) : chaque bruit d'un autre qui atteint les oreilles du monstre jouable, murs compris, devient un rond orange à l'écran, visible à travers les murs, avec sa distance (`HUD_DISTANCE`, « 11 m »), effacé en 3 s. 12 repères recyclés, réglages dans `monster_settings.tres`, `show_noise()` prêt pour le scan, 6 tests GUT.
