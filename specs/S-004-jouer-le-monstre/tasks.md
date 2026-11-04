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
- [x] T-023 — Jauge et scan de bâtiment
  - Résultat vérifiable : `ScanGauge` (8 s, 45 s, 25 %, concentration 1 s), bâtiment scannable dans la greybox, bruits du bâtiment affichés en direct, monstre immobile, jauge pâle à l'écran, tests GUT
  - Dépend de : T-022
- [x] T-024 — Lumières qui vacillent
  - Résultat vérifiable : deux lumières dans le bâtiment, qui vacillent pendant un scan sans message à l'écran, tests GUT
  - Dépend de : T-023
- [x] T-025 — Proie IA
  - Résultat vérifiable : `PreyBrain` (promenade, fuite, cachette, figée), scène de la proie, pas dans `NoiseBus`, elle entend et voit le monstre, tests GUT
  - Dépend de : T-022
- [x] T-026 — Souffle, réaction au scan, capture et debug
  - Résultat vérifiable : souffle de la proie essoufflée révélé par le scan, proie qui se fige à l'alerte une fois sur deux, écran « Attrapée » traduit, réapparition, F3 et F4 complétés, tests GUT
  - Dépend de : T-024, T-025
- [x] T-028 — Scan au clic droit dans le build web
  - Résultat vérifiable : le clic droit scanne le bâtiment dans Chrome, test GUT qui refuse les scènes perdant une valeur à l'export
  - Dépend de : T-023
- [ ] T-027 — Playtest « traquer une proie IA »
  - Résultat vérifiable : Maxime joue le monstre 10 minutes, notes de playtest remplies, réglages ajustés, 60 images/s dans Chrome
  - Dépend de : T-026

## Compte rendu
- T-020 (04/11/2026) : S-003 close (PR #23), spec, plan et tâches de S-004 rédigés (PR #24), propositions Q1 à Q6 retenues (Maxime : « Peux-tu tester toi-même ? »).
- T-021 (04/11/2026) : écran de démarrage `StartMenu` (scène principale, boutons traduits), rôle gardé dans `GameSession`, la greybox remplace le chassé et le monstre IA par `MonsterAvatar` en rôle monstre, monstre à la première personne (marcher, Maj pour courir, C pour rôder), bruits partagés avec le monstre IA dans `MonsterNoise`, `PlayerEars` réutilisé pour que le monstre entende la proie, deuxième Échap pour revenir au menu, 10 tests GUT. Écart : rôder se fait avec C (la touche d'accroupissement) plutôt que Ctrl, qui ferme l'onglet avec W dans le navigateur.
- T-022 (04/11/2026) : `NoiseMarkers` (couche d'interface) : chaque bruit d'un autre qui atteint les oreilles du monstre jouable, murs compris, devient un rond orange à l'écran, visible à travers les murs, avec sa distance (`HUD_DISTANCE`, « 11 m »), effacé en 3 s. 12 repères recyclés, réglages dans `monster_settings.tres`, `show_noise()` prêt pour le scan, 6 tests GUT.
- T-023 (04/11/2026) : `ScanGauge` (8 s de scan, recharge en 45 s, refus sous 25 %, concentration de 1 s, vidée pendant la concentration aussi), `Building` (volume sur la nouvelle couche physique 5 « scan ») autour du bâtiment de la greybox, clic droit (action `scan`) pour scanner le bâtiment visé à moins de 30 m, monstre immobile pendant le scan, bruits du bâtiment affichés quelle que soit leur portée, jauge pâle `ScanBar` en bas de l'écran, 13 tests GUT.
- T-024 (04/11/2026) : deux lumières sans ombre dans le bâtiment de la greybox (une par pièce), qui vacillent pendant un scan (8 fois par seconde, entre 15 % et 100 % de leur intensité) et reviennent à la normale à la fin, sans aucun message à l'écran, 4 tests GUT. À noter : dans la greybox éclairée par le soleil, le vacillement reste très discret. Il sera bien plus visible de nuit, avec le style visuel (phase 5).
- T-025 (04/11/2026) : `PreyBrain` (promenade avec pause, fuite vers la cachette la plus éloignée du monstre, cachette accroupie de 20 s prolongée s'il l'entend encore, figée par l'alerte, essoufflée 10 s après une course, abandon d'une cible bloquée) et `PreySettings`, scène `Prey` (capsule pâle, vitesses et pas du chassé via `FootstepEmitter` généralisé), elle entend le monstre par `NoiseBus` et le voit à moins de 15 m dans un champ de 120°. Greybox : 8 points de promenade et 4 cachettes, maillage de navigation recalculé (rayon 0,375 m, cellules de 0,125 m) pour que les portes de 1,2 m du bâtiment laissent passer le monstre et la proie. Vérifié sur 110 s simulées : la proie se promène dedans et dehors sans se coincer, fuit un monstre qui court et se cache. 16 tests GUT.
- T-026 (04/11/2026) : la proie essoufflée halète (bruit de 0,5 m chaque seconde, révélé par le scan), elle remarque une fois sur deux les lumières d'un bâtiment scanné où elle se trouve et se fige jusqu'à la fin du scan, le monstre l'attrape au contact (1,2 m) avec l'écran « Attrapée » (`HUD_PREY_CAUGHT`) et elle repart du point de promenade le plus éloigné, F3 montre l'allure et la jauge du monstre, ses captures et l'état de la proie, F4 montre les points de promenade et les cachettes, 9 tests GUT. Simulation de 300 s à vitesse x8 avec un monstre automatique qui ne suit que les repères affichés et scanne le bâtiment : 1 capture, 6 fuites, 4 scans.
- T-028 (04/11/2026) : premier retour de Maxime : « ça a un potentiel pour être amusant », mais le clic droit ne faisait rien. Cause : la greybox changeait la forme du volume d'une instance de `Building`, et cette modification d'un enfant d'instance est perdue à l'export, donc le bâtiment n'avait plus de volume dans le build web (il en avait un dans l'éditeur et les tests). Le volume se règle maintenant avec `size` sur le bâtiment lui-même. Vérifié dans Chrome : le clic droit vide la jauge face au bâtiment. Nouveau test GUT qui refuse ce genre de modification dans les scènes du jeu, 2 tests.
