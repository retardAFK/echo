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
- [x] T-293 — Centre social, galerie et parking
  - Résultat vérifiable : même palette et mêmes lampes, captures et mesure des appels de dessin
  - Dépend de : T-292, fin de S-016 (T-244)
- [x] T-294 — Vérification finale de S-019
  - Résultat vérifiable : critères cochés, export web vérifié
  - Dépend de : T-293

## Compte rendu
- T-290 (15/11/2026) : planche publiée, Maxime : « magnifique ». Il demandait si cela tiendrait dans le navigateur : oui, avec une lumière précalculée moins douce que les rendus.
- T-291 : chaque face d'un bloc de béton qui regarde dans une pièce prend la tuile de cette pièce (couleur de sommet = numéro de tuile, lue par `retro_surface`), découpée aux limites des pièces. Un seul matériau par structure, cellules de lumière précalculée de 1,5 m dans les pièces.
- T-292 : décor fait de boîtes colorées par sommet (alpha 0 = lumineux) dans un seul maillage par étage, affiché à moins de 14 m ; 17 lampes vivantes sous `Props/InteriorLights`.
- T-293 (16/11/2026) : centre social (salle des fêtes en parquet avec guirlandes et banderole, cuisine en faïence, couloir et trois bureaux), galerie (pharmacie et sa croix verte, laverie et ses hublots, tabac, épicerie, boulangerie, couloir de livraison) et parking (murs tagués des caves, tubes, places peintes, numéros de piliers). Les pièces au niveau de la rue reçoivent un sol mince sans collision, comme le rez-de-chaussée de la tour ; au-dessus de 3 m, les murs des pièces hautes prennent le plâtre du plafond. 4 lampes vivantes de plus (21 en tout), décor en 2 maillages par bâtiment affichés à moins de 18 m. Mesure (`measure_map`) : +1 à +6 appels de dessin par vue ; pire vue toujours le palier du 2e étage de la tour (297 pour 295 avant, limite 300).
- T-294 (16/11/2026) : critères cochés. Navmesh inchangé et tests S-016 verts en CI ; une lampe vivante par couloir de la tour, aucune orange (test) ; +1 à +9 appels de dessin par vue, 297 au pire (palier du 2e étage, limite 300), triangles sous 95 000 ; export web vérifié par la CI (« Import, tests and web export ») sur #136 et #139.
