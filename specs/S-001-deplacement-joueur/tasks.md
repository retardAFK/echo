# Tâches — S-001

- [x] T-001 — Rédiger la spec, le plan et les tâches de S-001
  - Résultat vérifiable : spec validée par Maxime, clarifications répondues
  - Dépend de : —
- [x] T-002 — Réglages du joueur et logique de mouvement testable
  - Résultat vérifiable : `PlayerSettings` + `player_settings.tres`, `PlayerMotion`, tests GUT (vitesse par allure, diagonale normalisée, limite du regard, accélération)
  - Dépend de : T-001
- [x] T-003 — Actions d'entrée et scène joueur : marche et regard souris
  - Résultat vérifiable : dans une scène vide avec un sol, on marche en ZQSD/WASD et on regarde à la souris, capture au clic, libération sur Échap
  - Dépend de : T-002
- [ ] T-004 — Course, accroupi et signal d'allure
  - Résultat vérifiable : course avec Maj, accroupi avec C, impossible de se relever sous un plafond bas, signal `gait_changed` testé
  - Dépend de : T-003
- [ ] T-005 — Map de test en greybox
  - Résultat vérifiable : `greybox_test.tscn` devient la scène principale, contient marche de 0,25 m, muret de 0,6 m, passage de 1,2 m, couloir et angles ; tous les critères de déplacement de la spec se vérifient dedans
  - Dépend de : T-004
- [ ] T-006 — Résolution interne 640 × 360 et compteur FPS de debug
  - Résultat vérifiable : rendu en 640 × 360 agrandi en pixels nets, compteur FPS avec F3, 60 images/s dans Chrome sur la machine de référence (vérification à la main par Maxime)
  - Dépend de : T-005

## Compte rendu
- T-001 (31/10/2026) : spec, plan et tâches rédigés et validés (propositions retenues), PR #3.
- T-002 (31/10/2026) : `PlayerSettings` + `player_settings.tres`, `PlayerMotion`, 19 tests GUT, PR #4.
- T-003 (31/10/2026) : actions d'entrée en touches physiques, scène `player.tscn` (marche, regard souris, capture au clic, Échap), sol de test dans `main.tscn`, 8 tests GUT, PR #5.
