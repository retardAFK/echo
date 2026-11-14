# Tâches — S-011

Chaque tâche est vérifiée par Claude (tests GUT, lint, import et export web, rendus). Maxime valide les planches (T-122, T-124).

- [x] T-120 — Spec S-011
  - Résultat vérifiable : spec, monstre retenu, allure des chassés, bras en vue subjective
  - Fait le 14/11/2026 : chassés validés (Q1) ; monstre en proposition (Q2) ; Q3 à Q6 proposées par Claude
- [x] T-121 — Plan et tâches de S-011
  - Résultat vérifiable : `plan.md` et ce fichier
  - Fait le 14/11/2026
- [ ] T-122 — Modèle du monstre
  - Résultat vérifiable : planches du nouveau chasseur, script dans `tools/blender/`, 2 500 triangles au plus ; rendus validés par Maxime
- [ ] T-123 — Squelette et animations du monstre
  - Dépend de : T-122
- [x] T-124 — Modèles des chassés
  - Résultat vérifiable : `tools/blender/hunted.py`, trois `.glb` skinnés sous 2 500 triangles, crédit CC0
  - Fait le 14/11/2026 : 2 478, 2 377 et 2 399 triangles ; sources CC0 dans `art_src/quaternius_ubc/` ; `assets/models/hunted/`
- [ ] T-125 — Animations des chassés
  - Résultat vérifiable : repos, marche, course, accroupi, à genoux dans les `.glb`
  - Dépend de : T-124
  - Fait le 14/11/2026 : `idle`, `walk`, `run`, `crouch`, `crouch_idle`, `kneel` (les actions lancer, ramasser, réparer, cachette restent au backlog)
- [ ] T-126 — Intégration en jeu et en réseau
  - Résultat vérifiable : `HuntedBody` dans `NetPuppet` et `Prey`, personnage par place, tests GUT du choix d'animation
  - Dépend de : T-125
  - Fait le 14/11/2026 : `HuntedBody` (choix d'animation pur et testé, vitesse de lecture bornée), `NetPuppet` lit l'allure déjà envoyée et estime la vitesse, corps caché pour la vue spectateur ; 11 tests GUT
- [ ] T-127 — Capture
- [ ] T-128 — Vérification finale de S-011
