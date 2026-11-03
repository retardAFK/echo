# Tâches — S-002

- [x] T-007 — Clore S-001 et rédiger la spec, le plan et les tâches de S-002
  - Résultat vérifiable : spec validée par Maxime, clarifications répondues
  - Dépend de : —
- [x] T-008 — Réglages du bruit et calculs purs
  - Résultat vérifiable : `NoiseSettings` + `noise_settings.tres`, `NoiseEvent`, `NoiseMath`, tests GUT (portée par allure, murs, jauge, décroissance)
  - Dépend de : T-007
- [x] T-009 — Autoload `NoiseBus` et comptage des murs
  - Résultat vérifiable : signal `noise_emitted`, `perceived_range` avec 0, 1 et 2 murs réels, couches physiques nommées, tests GUT
  - Dépend de : T-008
- [ ] T-010 — Bruit des pas du joueur
  - Résultat vérifiable : `FootstepEmitter` émet un bruit par foulée selon l'allure, rien à l'arrêt, tests GUT
  - Dépend de : T-009
- [ ] T-011 — Debug des bruits et micros de test
  - Résultat vérifiable : F4 affiche les anneaux, 3 micros dans la greybox qui s'allument selon les critères de la spec, murs de la greybox sur la couche « murs »
  - Dépend de : T-010
- [ ] T-012 — Jauge de bruit dans le HUD
  - Résultat vérifiable : jauge orange 0-10 en bas à gauche, libellé traduit, monte et redescend selon la spec, tests GUT ; 60 images/s dans Chrome vérifié par Maxime
  - Dépend de : T-010

## Compte rendu
- T-007 (03/11/2026) : S-001 marquée livrée (60 images/s confirmé par Maxime), spec, plan et tâches de S-002 rédigés, validés par Maxime (propositions retenues, ajout du type de bruit), PR #9.
- T-008 (03/11/2026) : `NoiseSettings` + `noise_settings.tres`, `NoiseEvent` (avec type), `NoiseMath` (portée par allure, foulées, murs, jauge, décroissance), 11 tests GUT, PR #10.
- T-009 (03/11/2026) : autoload `NoiseBus` (`emit_noise`, signal `noise_emitted`, `walls_between`, `perceived_range`, `can_hear`), couches physiques nommées (monde, murs, joueur), 6 tests GUT avec de vrais murs, PR #11.
