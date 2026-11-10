# S-005 — Le style visuel

**Statut** : validée (04/11/2026)
**Piliers servis** : P3 (l'inquiétante familiarité), P4 (le rétro qui dérange)
**Phase** : 5 — Le style visuel

## Pourquoi
Le jeu est jouable mais il est encore gris et en plein jour. Cette spec lui donne son look : une nuit rétro façon PS1, inspirée de *Neyasnoe* sans la copier (D-003). Elle ajoute aussi les quatre premiers assets Blender, pour vérifier que la chaîne Blender → Godot marche et qu'une scène habillée tient le budget de performance (2.2). Le gameplay ne change pas.

## Ce que vit le joueur
Je lance une partie. C'est la nuit. Le brouillard avale le fond de la cour, à une vingtaine de mètres. Deux lampadaires au sodium font des flaques ocre sur le béton, une enseigne verte d'hôpital luit au-dessus d'une porte. Les murs ont une texture de béton en gros pixels nets. Quand je tourne la tête, les arêtes des objets tremblent un tout petit peu, comme sur une vieille console. L'image a peu de couleurs, un léger tramage dans les dégradés et un grain discret. Un banc, un arbre nu et une façade d'immeuble me disent où je suis. En monstre, les bruits restent les seules taches orange de l'écran, et quand je scanne un bâtiment, tout le reste s'éteint autour de lui.

## Hors périmètre
- La vraie map (cité des Tilleuls) et l'éclairage précalculé à grande échelle : phase 6.
- Les personnages et le monstre définitifs : phase 9.
- Un menu d'options graphiques (intensité du tremblement, du grain) : plus tard, mais les réglages sont déjà dans un fichier `.tres`.

## Clarifications
Le 04/11/2026, Maxime a répondu « Parfait » aux maquettes, aux propositions et au premier lampadaire : ambiance A et propositions Q1 à Q6 retenues.

Maquettes d'ambiance A, B et C : rendus de la greybox avec une première version du filtre, postées dans le fil le 04/11/2026 (copies dans les fichiers du projet, `echo-captures/s005-ambiance-*.png`).

- Q1 : Quelle ambiance ? → Proposition : **A**, nuit bleutée, brouillard moyen (on voit à environ 25 m), 24 niveaux par couleur. B (nuit noire, 12 niveaux, très PS1) est plus marquée mais on y lit mal les murs, ce qui gêne le chassé comme le monstre. C (brouillard sodium épais) est très belle pour un lieu précis, je la garderais comme variante de map (le parking, la gare). → R : retenu (04/11/2026).
- Q2 : Quelle force pour le tremblement des sommets ? → Proposition : léger, sommets accrochés à une grille de 320 × 180 (la moitié de la résolution interne). Assez pour qu'on le sente en tournant la tête, sans donner mal au cœur. Réglable dans `visual_settings.tres`. → R : retenu (04/11/2026).
- Q3 : Faut-il la déformation des textures de la PS1 (textures qui « glissent » en biais) ? → Proposition : non. Sur les grands sols et les grands murs d'une cité, elle devient vite laide et fatigante. Le tremblement et les gros pixels suffisent à faire PS1. → R : retenu (04/11/2026).
- Q4 : Tramage et grain ? → Proposition : tramage ordonné 4 × 4 dans les dégradés, grain léger qui change 12 fois par seconde (pas à chaque image, pour un effet pellicule plutôt que neige). → R : retenu (04/11/2026).
- Q5 : À quoi ressemble le scan, en plus stylé ? → Proposition : pendant le scan, tout l'écran hors du bâtiment visé s'assombrit et se décolore. Les arêtes du bâtiment s'allument en blanc pâle, et une onde pâle part du bâtiment chaque seconde. Les bruits révélés restent orange, seule couleur vive à l'écran. La jauge devient un fin trait pâle sous le viseur. → R : retenu (04/11/2026).
- Q6 : Quels assets, et dans quel ordre ? → Proposition, chacun validé sur rendu dans le fil avant le suivant : 1) lampadaire au sodium (une tête, mât de 5 m, environ 150 triangles), 2) banc en béton et bois (environ 120 triangles), 3) arbre nu d'hiver (environ 400 triangles, sans feuilles : moins cher et plus inquiétant), 4) module de façade HLM de 3 × 3 m avec une fenêtre, qu'on répète pour faire un immeuble (environ 200 triangles). Textures de 64 à 256 px, filtrage Nearest, environ 64 px par mètre (2.3). → R : retenu (04/11/2026).

## Notes de playtest
- (à remplir)

## Critères d'acceptation (vérifiables à la main)
- [ ] La greybox est de nuit, avec du brouillard, des textures pixelisées nettes et l'ambiance choisie en Q1.
- [ ] Les sommets tremblent légèrement quand la caméra bouge (Q2), les textures ne glissent pas (Q3).
- [ ] L'image a peu de couleurs, un tramage et un grain léger (Q4), et l'orange n'apparaît que pour les bruits.
- [ ] Le scan a son nouveau rendu (Q5) et reste lisible.
- [ ] Le lampadaire, le banc, l'arbre et le module de façade sont dans la greybox, chacun validé par Maxime.
- [ ] Une capture d'écran « ressemble au jeu ».
- [ ] 60 images par seconde dans Chrome sur la machine de référence, chassé et monstre.
- [ ] Le build web reste sous 60 Mo.

## Révision du 10/11/2026 (D-011)
Sur la cité des Tilleuls, Maxime trouve que le rendu basse résolution, son grain et son tramage font mal aux yeux. Nouveau réglage, validé sur captures comparatives : la 3D est rendue à la résolution de l'écran (mode d'étirement `canvas_items`, l'interface garde sa base de 640 × 360), 256 niveaux de couleur, sans tramage ni tremblement des sommets, grain à 0,006. Les textures en gros pixels nets et le brouillard ne changent pas. Q2 et Q4 sont remplacées par ce réglage.
