# Tâches — S-006

Ordre de Q8 : 1) greybox de toute la map, jouable, vérifiée ; 2) ajustements ; 3) habillage ; 4) éclairage et sons.
Maxime a demandé (10/11/2026) de ne pas être sollicité pour tester : chaque tâche est vérifiée par Claude (tests GUT, lint, import et export web, captures dans le rendu OpenGL et dans Chrome). Seuls les choix de style (rendus d'assets) lui sont montrés.

- [x] T-037 — Décision D-010 et spec S-006
  - Résultat vérifiable : spec validée, `plan-map.svg`
  - Dépend de : —
- [x] T-038 — Plan et tâches de S-006
  - Résultat vérifiable : `plan.md` et `tasks.md`
  - Dépend de : T-037
- [ ] T-039 — Générateur de map et greybox extérieure
  - Résultat vérifiable : `build_tilleuls.gd` produit la cité 220 × 220 m (sol, limites, 7 barres, chemins, repères extérieurs, sortie fermée, lampadaires) ; classe commune `GameMap` ; le menu lance la cité ; apparition au hasard du chassé, monstre au sud-est ; tests GUT (taille, limites fermées, sol partout) ; build web vérifié dans Chrome
  - Dépend de : T-038
- [ ] T-040 — Les 4 bâtiments visitables et les boxes
  - Résultat vérifiable : tour (R+4 visitable, grille), centre social, galerie, parking (rampe et escalier), boxes ; volumes de scan sur ces 5 cibles et pas sur les façades ; 4 emplacements de fusible par bâtiment ; tests GUT
  - Dépend de : T-039
- [ ] T-041 — Navigation et IA à l'échelle de la cité
  - Résultat vérifiable : maillage de navigation de toute la map ; patrouille du monstre IA et routes de la proie IA dans les rues, la tour et le parking ; tests GUT des chemins (tour, parking, chaque emplacement de fusible) et de la traversée en courant en moins de 45 s
  - Dépend de : T-040
- [ ] T-042 — Voitures à alarme
  - Résultat vérifiable : entité `CarAlarm`, action `interact` (E), 6 voitures sur la map, bruit de 30 m répété, repos, tests GUT (déclenchement, monstre IA attiré)
  - Dépend de : T-041
- [ ] T-043 — Repères, distance de vue et mesure de performance
  - Résultat vérifiable : chaque repère a sa silhouette et sa lumière ; distance de vue réglable ; `measure_map.gd` relève appels de dessin, triangles et lumières aux endroits les plus chargés, sous le budget ; temps de chargement mesuré ; captures des repères dans le brouillard
  - Dépend de : T-042
- [ ] T-044 — Ajustements de la greybox
  - Résultat vérifiable : corrections issues des vérifications de T-039 à T-043 (parcours d'un bot dans le build web, captures), notes de vérification dans la spec
  - Dépend de : T-043
- [ ] T-045 — Habillage : tour et barres
  - Résultat vérifiable : modules de façade de S-005 posés sur les barres et la tour, nouveaux modules si besoin validés sur rendu, budget tenu
  - Dépend de : T-044
- [ ] T-046 — Habillage : galerie commerciale et centre social
  - Résultat vérifiable : modèles validés sur rendu, posés dans la cité
  - Dépend de : T-045
- [ ] T-047 — Habillage : parking, rampe et boxes
  - Résultat vérifiable : modèles validés sur rendu, posés dans la cité
  - Dépend de : T-046
- [ ] T-048 — Habillage : voitures, transformateur, aire de jeux et city stade
  - Résultat vérifiable : modèles validés sur rendu (balançoire comprise), posés dans la cité
  - Dépend de : T-047
- [ ] T-049 — Éclairage précalculé
  - Résultat vérifiable : éclairage cuit (LightmapGI ou plan B du plan), 4 lumières dynamiques visibles au plus, captures
  - Dépend de : T-048
- [ ] T-050 — Sons d'ambiance
  - Résultat vérifiable : vent, autoroute, train lointain, grincement de la balançoire, sons faits par nous ou CC0 (`CREDITS.md`), ils ne passent pas par le `NoiseBus` (ils ne trahissent personne)
  - Dépend de : T-049
- [ ] T-051 — Vérification finale de S-006
  - Résultat vérifiable : chaque critère d'acceptation vérifié et coché, notes dans la spec, spec livrée
  - Dépend de : T-050

## Compte rendu
- T-037 (07/11/2026) : décision D-010 et spec S-006 validée par Maxime (« Parfait »), PR #35.
- T-038 (10/11/2026) : plan et tâches de S-006. Maxime : « On peut passer aux tâches suivantes, j'aimerais ne pas être sollicité pour tester, je te fais confiance ».
