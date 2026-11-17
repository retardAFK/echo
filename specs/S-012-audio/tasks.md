# Tâches — S-012

Chaque tâche est vérifiée par Claude (tests GUT, lint, import et export web, mesure dans le build web avec Playwright). Seuls les sons sont montrés à Maxime, sur une page d'écoute.

- [x] T-140 — Spec S-012
  - Résultat vérifiable : spec validée (phase lancée par Maxime le 17/11/2026)
  - Dépend de : T-128
- [x] T-141 — Plan et tâches de S-012
  - Résultat vérifiable : `plan.md` et `tasks.md`
  - Dépend de : T-140
- [ ] T-142 — Spatialisation et occlusion
  - Résultat vérifiable : `SoundMath`, `SpatialSound`, versions étouffées ; tous les bruits de jeu joués en 3D passent par `SpatialSound` ; tests GUT sur les volumes et l'étouffement
  - Dépend de : T-141
- [ ] T-143 — Pas selon le sol
  - Résultat vérifiable : 6 sols, flaques (portées 2/8/20 m), `SurfaceMap` générée, mes propres pas, raclement du monstre, `by_monster` en ligne ; sons montrés à Maxime ; tests GUT
  - Dépend de : T-142
- [ ] T-144 — Le vent de la cité
  - Résultat vérifiable : rafales (portée des bruits ≤ 6 m divisée par deux dehors), audibles, synchronisées en ligne ; tests GUT
  - Dépend de : T-142
- [ ] T-145 — Voix du monstre
  - Résultat vérifiable : souffle, grognement, cri de capture, bourdon du scan, grésillement des lampes ; bus Voix ; sons montrés à Maxime ; tests GUT
  - Dépend de : T-142
- [ ] T-146 — Musique minimale et tension
  - Résultat vérifiable : trois nappes, paliers 35 m et 15 m, lents à changer ; montrées à Maxime ; tests GUT sur les paliers
  - Dépend de : T-142
- [ ] T-149 — Sons provisoires remplacés
  - Résultat vérifiable : alarme de voiture, appel à l'aide, sauvetage faits par nous ; `PlaceholderSounds` supprimée
  - Dépend de : T-142
- [ ] T-147 — Mixage
  - Résultat vérifiable : niveaux mesurés dans le build web (rien au-dessus de −3 dBFS), notés dans la spec ; prêts pour les curseurs de S-013
  - Dépend de : T-143, T-144, T-145, T-146, T-149
- [ ] T-148 — Vérification finale de S-012
  - Résultat vérifiable : critères cochés, taille du build sous 60 Mo, spec livrée
  - Dépend de : T-147

## Compte rendu
- T-140, T-141 (17/11/2026) : spec, plan et tâches.
