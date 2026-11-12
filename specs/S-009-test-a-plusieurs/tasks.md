# Tâches — S-009

Chaque tâche est vérifiée par Claude (tests GUT, lint, import et export web, simulations, captures). Maxime ne joue pas ; il tranche le choix de l'hébergement et transmet le lien aux testeurs.

- [x] T-073 — Spec S-009
  - Résultat vérifiable : spec validée par Maxime (Q1 tranchée)
  - Dépend de : —
- [x] T-074 — Plan et tâches de S-009
  - Résultat vérifiable : `plan.md` et `tasks.md`, avec l'hébergement choisi (Q-012)
  - Dépend de : T-073
- [ ] T-075 — Mode banc d'essai
  - Résultat vérifiable : `BenchStats`, scène `Bench`, lancement par `?bench` ou `--bench`, écran et ligne `ECHO_BENCH` ; tests GUT des statistiques
  - Dépend de : T-074
- [ ] T-076 — Build de test en ligne
  - Résultat vérifiable : job `publish` de la CI sur `main`, version du jeu dans le build ; le lien s'ouvre dans Chrome
  - Dépend de : T-074
- [ ] T-077 — Mesure des 60 images/s sur la machine de référence
  - Résultat vérifiable : banc lancé par Claude sur le PC de Maxime ; résultats notés dans S-006 à S-009 ; tâches d'optimisation ajoutées s'il manque des images
  - Dépend de : T-075, T-076
- [ ] T-078 — Le monstre IA utilise le scan
  - Résultat vérifiable : état `SCAN`, décision de scan pure, jauge respectée, lumières qui vacillent ; tests GUT ; scans comptés par la simulation
  - Dépend de : T-074
- [ ] T-079 — Équilibre de la proie IA et du monstre IA
  - Résultat vérifiable : 3 séries de 20 parties simulées, sorties 40 à 60 %, durée moyenne 8 à 12 min, aucun blocage ; deux endroits de capture répétée corrigés
  - Dépend de : T-078
- [ ] T-080 — Commandes et pause
  - Résultat vérifiable : panneau des commandes par rôle, `PauseMenu` (Échap et perte de la souris), textes dans `strings.csv` ; tests GUT
  - Dépend de : T-074
- [ ] T-081 — Recueil des retours
  - Résultat vérifiable : « Copier le résumé » sur l'écran de fin, `RunSummary` testé, `questionnaire.md`
  - Dépend de : T-080
- [ ] T-082 — Vérification finale de S-009
  - Résultat vérifiable : critères cochés, lien et questionnaire envoyés à Maxime
  - Dépend de : T-077, T-079, T-081
- [ ] T-083 — Tests à 3 à 5 personnes **(Maxime)**
  - Résultat vérifiable : retours rapportés
  - Dépend de : T-082
- [ ] T-084 — Synthèse et réglages après les tests ; **point de décision n°2** tranché par Maxime
  - Dépend de : T-083

## Compte rendu
- T-073, T-074 (12/11/2026) : spec, plan et tâches, PR #70. Q1 : itch.io, page restreinte (Maxime).
