# Tâches — S-011

Chaque tâche est vérifiée par Claude (tests GUT, lint, import et export web, rendus). Maxime valide les planches (T-122, T-124).

- [x] T-120 — Spec S-011
  - Résultat vérifiable : spec, monstre retenu, allure des chassés, bras en vue subjective
  - Fait le 14/11/2026 : chassés validés (Q1) ; monstre en proposition (Q2) ; Q3 à Q6 proposées par Claude
- [x] T-121 — Plan et tâches de S-011
  - Résultat vérifiable : `plan.md` et ce fichier
  - Fait le 14/11/2026
- [x] T-122 — Modèle du monstre
  - Résultat vérifiable : planches du nouveau chasseur, script dans `tools/blender/`, 2 500 triangles au plus ; rendus validés par Maxime
  - Fait le 14/11/2026 : piste B validée par Maxime ; `tools/blender/hunter.py` (même base CC0 et même chaîne que les chassés, bras allongés dans la pose de repos), 2 438 triangles, `assets/models/hunter/hunter.glb`
- [x] T-123 — Squelette et animations du monstre
  - Dépend de : T-122
  - Fait le 14/11/2026 : `idle`, `prowl`, `walk`, `run`, `scan`, `reach` (ouvrir une cachette) ; `MonsterBody` dans `Monster` (allure et état du cerveau) et dans `NetPuppet` (vitesse vue entre deux instantanés) ; 6 tests GUT
  - 15/11/2026 : `catch` (bond, les deux mains se referment) et `crush` (pied droit levé puis écrasé) joués une fois, quand le monstre attrape un chassé ou écrase un réveil
- [x] T-124 — Modèles des chassés
  - Résultat vérifiable : `tools/blender/hunted.py`, trois `.glb` skinnés sous 2 500 triangles, crédit CC0
  - Fait le 14/11/2026 : 2 478, 2 377 et 2 399 triangles ; sources CC0 dans `art_src/quaternius_ubc/` ; `assets/models/hunted/`
- [x] T-125 — Animations des chassés
  - Résultat vérifiable : repos, marche, course, accroupi, à genoux dans les `.glb`
  - Dépend de : T-124
  - Fait le 14/11/2026 : `idle`, `walk`, `run`, `crouch`, `crouch_idle`, `kneel`
  - Fait le 15/11/2026 : gestes `throw` (bouteille, bras par-dessus l'épaule), `pick` (descendre au sol et remonter : ramasser, poser un réveil), `work` en boucle (mains occupées : réparer un boîtier, entrer dans une cachette ou en sortir, libérer un équipier)
- [x] T-126 — Intégration en jeu et en réseau
  - Résultat vérifiable : `HuntedBody` dans `NetPuppet` et `Prey`, personnage par place, tests GUT du choix d'animation
  - Dépend de : T-125
  - Fait le 14/11/2026 : `HuntedBody` (choix d'animation pur et testé, vitesse de lecture bornée), `NetPuppet` lit l'allure déjà envoyée et estime la vitesse, corps caché pour la vue spectateur ; 11 tests GUT
  - 15/11/2026 : `BodyGesture` (un geste à la fois, pour sa durée) dans `Player`, `Prey`, `Monster` et `MonsterAvatar` ; l'instantané envoie un entier de plus par joueur vu (le geste d'un chassé, l'action du monstre : scan, ouverture, attrape, écrasement). Q6 revue : c'est le seul ajout au réseau
- [x] T-127 — Capture
  - Fait le 15/11/2026 : attrapé, le chassé ne commande plus rien et sa tête se tourne vers les yeux rouges pendant que le monstre joue `catch`, 1,2 s (`catch_show_time`, borné à 2 s par la règle 2.3), puis l'écran « attrapé » ou la fin de partie. En ligne, même chose côté client si le monstre est en vue ; le monstre IA reste sur place pendant ce temps avant de repartir
- [ ] T-128 — Vérification finale de S-011
