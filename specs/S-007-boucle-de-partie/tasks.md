# Tâches — S-007

Maxime a demandé (10/11/2026) de ne pas être sollicité pour tester : chaque tâche est vérifiée par Claude (tests GUT, lint, import et export web, captures dans le rendu OpenGL et dans Chrome). Seuls les choix de style (sons, rendus) lui sont montrés.

- [x] T-052 — Spec S-007
  - Résultat vérifiable : spec validée
  - Dépend de : —
- [x] T-053 — Plan et tâches de S-007
  - Résultat vérifiable : `plan.md` et `tasks.md`
  - Dépend de : T-052
- [ ] T-054 — Fusibles et action maintenue
  - Résultat vérifiable : `LoopRules`, `GameLoop`, `LoopSettings`, entité `FuseBox` sur les 16 emplacements, tirage de 3 fusibles dans 3 bâtiments différents, diode rouge, `HoldInteraction` (maintenir E 2 s, remise à zéro en lâchant), anneau de progression, bruit `FUSE` de 3 m, HUD « Fusibles n/3 » ; tests GUT
  - Dépend de : T-053
- [ ] T-055 — Transformateur, sirène et sortie
  - Résultat vérifiable : entité `Transformer` (4 s par fusible, bruit `REPAIR` de 8 m, moitié gardée en lâchant, texte « attend N fusibles »), sirène `SIREN` entendue par le monstre, `ExitGate` qui se lève, `ExitZone` au bout du tunnel ; tests GUT
  - Dépend de : T-054
- [ ] T-056 — Fin de partie et écran de fin
  - Résultat vérifiable : défaite à la capture, victoire à la sortie, dans les deux rôles ; `EndScreen` avec durée, fusibles, bruits, scans ; « Rejouer » relance un nouveau tirage, « Menu » revient au menu ; tests GUT
  - Dépend de : T-055
- [ ] T-057 — Monstre IA : attirance et garde du tunnel
  - Résultat vérifiable : souvenir du bâtiment bruyant, état `GUARD` après la sirène ; tests GUT
  - Dépend de : T-056
- [ ] T-058 — Proie IA qui joue la boucle
  - Résultat vérifiable : la proie IA cherche, ramasse, répare et fuit, avec ses réactions de S-004 ; tests GUT ; elle sort d'une partie sans monstre, sans se bloquer
  - Dépend de : T-057
- [ ] T-059 — Sons de la boucle
  - Résultat vérifiable : claquement de boîtier, étincelles, ronflement, sirène, faits par nous (`CREDITS.md`), montrés à Maxime
  - Dépend de : T-058
- [ ] T-060 — Vérification finale de S-007
  - Résultat vérifiable : simulation d'une vingtaine de parties (durées, victoires, blocages), parcours d'un bot dans le build web, mesure de performance, chaque critère d'acceptation coché, spec livrée
  - Dépend de : T-059
