# Tâches — S-019

Chaque tâche est vérifiée par Claude (tests GUT, lint, import et export web, captures comparées à la planche). Seule la planche d'ambiance a été montrée à Maxime.

- [x] T-290 — Planche d'ambiance
  - Résultat vérifiable : 5 rendus (`tools/blender/hlm_interior_mood.py`), validés par Maxime
  - Dépend de : —
- [x] T-291 — Revêtements de la tour et des caves
  - Résultat vérifiable : atlas `assets/textures/interior_atlas.png` (`tools/godot/make_interior_atlas.gd`), pièces de `MapKit.zone`, un matériau par bâtiment ; tests GUT
  - Dépend de : T-290
- [x] T-292 — Lampes et décor de la tour et des caves
  - Résultat vérifiable : hublots, tubes, télés, blocs de sortie, décor de la vie d'avant, un maillage par étage, lumière précalculée ; captures `tools/godot/capture_interiors.tscn`
  - Dépend de : T-291
- [ ] T-293 — Centre social, galerie et parking
  - Résultat vérifiable : même palette et mêmes lampes, captures et mesure des appels de dessin
  - Dépend de : T-292, fin de S-016 (T-244)
- [ ] T-294 — Vérification finale de S-019
  - Résultat vérifiable : critères cochés, export web vérifié
  - Dépend de : T-293

## Compte rendu
- T-290 (15/11/2026) : planche publiée, Maxime : « magnifique ». Il demandait si cela tiendrait dans le navigateur : oui, avec une lumière précalculée moins douce que les rendus.
- T-291 : chaque face d'un bloc de béton qui regarde dans une pièce prend la tuile de cette pièce (couleur de sommet = numéro de tuile, lue par `retro_surface`), découpée aux limites des pièces. Un seul matériau par structure, cellules de lumière précalculée de 1,5 m dans les pièces.
- T-292 : décor fait de boîtes colorées par sommet (alpha 0 = lumineux) dans un seul maillage par étage, affiché à moins de 14 m ; 17 lampes vivantes sous `Props/InteriorLights`.
