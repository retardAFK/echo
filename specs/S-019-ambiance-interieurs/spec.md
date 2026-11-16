# S-019 — Ambiance des intérieurs de la cité

**Statut** : livrée (16/11/2026, PRs #136 et #139) ; validée le 15/11/2026 (Maxime : « magnifique » sur la planche d'ambiance).
**Piliers servis** : P3 (l'inquiétante familiarité), P4 (le rétro qui dérange)
**Phase** : hors feuille de route, demandée par Maxime le 15/11/2026 (« la cité des Tilleuls doit avoir la même ambiance que l'hôpital, les intérieurs ressemblent à des parkings à étages, ça fait très peu HLM »).

## Pourquoi
Tous les murs, sols et plafonds des bâtiments visitables utilisent le même béton : la tour se lit comme un parking à étages, pas comme des logements. La planche de l'hôpital (D-019) a fixé une ambiance que Maxime veut retrouver partout : tubes morts, une seule lumière par pièce, brouillard, saleté. Les immeubles doivent rester des HLM : **des logements qui ont été habités, puis abandonnés d'un coup**.

## Ce que vit le joueur
J'entre dans le hall de la tour : granito sale, faïence beige taguée, boîtes aux lettres fracturées et courrier par terre, une poussette oubliée. Un seul tube vert grésille au fond. Dans l'escalier, peinture vert bouteille en bas, crème jaunie en haut, un hublot grillagé sur le palier, le numéro de l'étage peint au pochoir. Au 2e, le couloir sent le renfermé : lino brun, papier peint, paillassons devant chaque porte, un dessin d'enfant scotché au mur. Dans un salon, une télé est restée allumée sur la neige ; des photos de famille au mur, des papiers partout.

## Ce qui est décidé
- Planche d'ambiance : 5 rendus Blender (hall, escalier, couloir d'étage, salon, cuisine), `tools/blender/hlm_interior_mood.py`, validés par Maxime.
- Un **revêtement par pièce**, sans toucher aux murs, portes, cachettes ni au maillage de navigation de S-016 : granito et faïence dans le hall, peinture deux tons dans l'escalier, lino et papier peint dans les couloirs, papier peint et parquet dans les séjours et chambres, faïence et lino dans les cuisines, chaux humide dans les caves et le local poubelles.
- **La lumière de l'hôpital** : hublots grillagés et tubes, presque tous morts, une lampe vivante par étage, des télés allumées, blocs de sortie verts ; lumière précalculée dans les murs comme les lampadaires (T-049), lumières réelles atténuées à 20 m.
- **La vie d'avant** : boîtes aux lettres, paillassons, numéros en laiton, photos, calendriers, horloges, papiers, jouets, bouteilles, sacs-poubelle, tricycle. Décor sans collision.
- Aucune couleur orange (constitution 2.3).
- **Budget** (constitution 2.2) : tout le revêtement d'un bâtiment dans un seul matériau (un atlas de textures) et le décor d'un étage dans un seul maillage affiché à moins de 14 m : quelques appels de dessin de plus seulement.
- **Ordre** : la tour et les caves d'abord, puis le centre social, la galerie et le parking avec la même palette (lieux publics : carrelage, néons).

## Critères d'acceptation
- [x] Le hall, l'escalier, les couloirs et les appartements de la tour ont chacun leur revêtement ; les captures en jeu rappellent la planche.
- [x] Les murs, portes, cachettes et le maillage de navigation sont inchangés (tests S-016 verts).
- [x] Une lampe vivante au plus par couloir, aucune lumière orange, lumière précalculée.
- [x] Au plus 10 appels de dessin de plus dans les vues de la tour, triangles sous 150 000.
- [x] Le centre social, la galerie et le parking reçoivent la même palette.
