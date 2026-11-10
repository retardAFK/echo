# S-006 — La cité des Tilleuls

**Statut** : livrée (10/11/2026), validée le 07/11/2026
**Piliers servis** : P1 (le son trahit), P2 (le dilemme permanent), P3 (l'inquiétante familiarité)
**Phase** : 6 — Première vraie map

## Pourquoi
Jusqu'ici on joue dans une greybox de 40 × 40 m. C'est trop petit pour qu'un bruit lointain soit un vrai pari pour le monstre, et il n'y a pas de vrai bâtiment où les chassés doivent entrer. Cette spec crée la première vraie map : une cité HLM de nuit, assez grande pour se perdre, avec quatre bâtiments visitables où se cachent les fusibles et où le scan du monstre devient une menace (D-010).

## Ce que vit le joueur
**En chassé**, j'apparais quelque part dans une cité de barres HLM grises, de nuit. Le brouillard ne me laisse voir qu'à 25 m. Je reconnais des repères : la tour des Tilleuls au milieu, l'aire de jeux avec sa balançoire, la galerie commerciale aux rideaux baissés, le centre social, la rampe du parking souterrain. Je sais que les fusibles sont dans des bâtiments, alors je dois y entrer, en sachant qu'à l'intérieur le monstre peut tout entendre s'il me scanne. Dehors, je peux semer le monstre en déclenchant une alarme de voiture ou en passant derrière une barre.

**En monstre**, j'apparais loin des chassés. Les bruits orange m'indiquent la direction et la distance. La cité est grande, donc je dois choisir : courir vers un bruit lointain, ou me poster près d'un bâtiment visitable et le scanner au bon moment.

## Récits utilisateur
- En tant que chassé, je veux des bâtiments que je peux fouiller, afin de trouver les fusibles en prenant un risque.
- En tant que chassé, je veux des repères visibles dans le brouillard, afin de m'orienter sans carte.
- En tant que chassé, je veux des alarmes, des recoins et des barres qui coupent la vue, afin de tromper le monstre.
- En tant que monstre, je veux une map assez grande pour qu'un bruit lointain soit un pari, afin que mes choix comptent.
- En tant que monstre, je veux savoir quels bâtiments valent un scan, afin de dépenser ma jauge à bon escient.

## Plan sur papier
Voir `plan-map.svg` dans ce dossier. 1 unité = 1 m, le nord est en haut.

- **Limites** : voie ferrée sur remblai au nord, autoroute avec mur antibruit à l'est, boulevard barré par des grillages de chantier au sud, friche grillagée à l'ouest. On ne sort jamais de la map sans le savoir.
- **4 bâtiments visitables** : 1) la tour des Tilleuls, au centre ; 2) le centre social Jean-Moulin ; 3) la galerie commerciale ; 4) le parking souterrain, sous une dalle.
- **7 barres en façades** (A à G), non visitables : elles coupent la vue et dessinent les rues.
- **Lieux extérieurs** : l'aire de jeux avec sa balançoire, le city stade, une rangée de boxes de garages (leurres, alarmes), 6 voitures à alarme, le transformateur, et la sortie par le tunnel sous la voie ferrée.

## Clarifications
Le 07/11/2026, Maxime a répondu « Parfait » au plan et aux propositions Q2 à Q8.
- Q1 : Quelle taille ? → R : 220 × 220 m, une douzaine de bâtiments dont 4 visitables (Maxime, 07/11/2026, D-010).
- Q2 : Le plan ci-dessus te convient-il (limites, emplacement des bâtiments, sortie au nord, monstre au sud-est) ? → Proposition : oui, à ajuster après le premier test en greybox. → R : retenu (07/11/2026).
- Q3 : Quels 4 bâtiments visitables ? → Proposition : la tour (cage d'escalier étroite, très bruyante), le centre social (grandes salles, peu de cachettes), la galerie commerciale (rideaux métalliques bruyants, une laverie dont les machines couvrent les petits bruits) et le parking souterrain (écho, alarmes, leurres). Ces quatre lieux jouent chacun différemment avec le bruit. → R : retenu (07/11/2026).
- Q4 : Jusqu'où visite-t-on la tour ? → Proposition : le rez-de-chaussée et 4 étages, avec 2 appartements ouverts par palier. Plus haut, l'escalier est condamné par une grille. Le scan entend alors toute la tour, et grimper reste un pari. → R : retenu (07/11/2026).
- Q5 : Où sont les fusibles ? → Proposition : à chaque partie, 3 des 4 bâtiments visitables reçoivent un fusible, sur un des 4 emplacements prévus dans chaque bâtiment. Le placement réel vient avec la boucle de partie (S-007) : ici, on prévoit seulement les emplacements. → R : retenu (07/11/2026).
- Q6 : Que peut-on scanner ? → Proposition : les 4 bâtiments visitables et la rangée de boxes de garages. Les façades ne se scannent pas, puisque personne ne peut y entrer. → R : retenu (07/11/2026).
- Q7 : Comment éviter les temps morts sur une si grande map ? → Proposition : 6 voitures à alarme réparties sur la map, des rues qui ramènent toujours vers le centre, et un équilibrage prévu pour 4 chassés (Q-002). En solo contre l'IA, on testera avec plusieurs proies IA. → R : retenu (07/11/2026).
- Q8 : Dans quel ordre on travaille ? → Proposition : 1) greybox en cubes de toute la map, jouable, et premier test ; 2) ajustements ; 3) habillage avec les assets de S-005 et les nouveaux (tour, galerie, rampe de parking, boxes, transformateur, voitures), chacun validé sur rendu ; 4) éclairage précalculé et sons d'ambiance. → R : retenu (07/11/2026).

## Critères d'acceptation (vérifiables à la main)
- [x] La map fait 220 × 220 m, ses limites sont claires et on ne peut pas en sortir.
- [x] Les 4 bâtiments visitables sont ouverts et explorables, avec leurs emplacements de fusible.
- [x] Le scan marche sur les cibles prévues en Q6, et pas sur les façades.
- [x] Chaque lieu repère (tour, aire de jeux, galerie, centre social, parking, transformateur, sortie) se reconnaît dans le brouillard.
- [x] Les 6 alarmes de voiture se déclenchent et attirent le monstre IA.
- [x] On traverse la map en courant en moins de 45 s.
- [x] Le monstre IA trouve son chemin partout, y compris dans la tour et le parking.
- [ ] 60 images par seconde dans Chrome sur la machine de référence, en chassé et en monstre, à l'endroit le plus chargé de la map.
- [x] La map se charge en moins de 10 s, et le build web reste sous 60 Mo.

## Hors périmètre
- La boucle de partie (fusibles posés au hasard, transformateur, ouverture de la sortie, victoire) : S-007.
- Les objets lancés et les leurres posés par le joueur : phase 8.
- L'hôpital : une map séparée, plus tard (phase 13).
- Le multijoueur : phase 12.

## Notes de playtest
Maxime ne teste pas la greybox (10/11/2026) : ces notes sont celles des vérifications de Claude.
- Greybox (T-039 à T-044, 10/11/2026) :
  - Limites : sol partout à l'intérieur des grillages, aucun trou vers l'extérieur, la sortie est fermée par une grille (tests GUT).
  - Bâtiments : un bot pilote le vrai contrôleur du chassé (touches avancer et courir, physique) jusqu'au 4e de la tour, au fond du parking par l'escalier de secours, et sous le rideau de la boutique en s'accroupissant ; debout, le rideau l'arrête. Le monstre IA marche avec la physique jusqu'aux mêmes endroits et dans un bureau du centre social.
  - Traversées en courant mesurées sur le maillage : 36 à 43 s, sous les 45 s, grâce aux porches sous les barres A, B et E.
  - Performance (rendu OpenGL, sans GPU) : 70 appels de dessin au pire sur 484 vues, 15 000 triangles, 2 lumières visibles, chargement en 0,33 s, build web de 40 Mo. Les 60 images/s restent à vérifier sur la machine de référence.
  - Correction trouvée : le chassé apparaissait parfois face au mur d'une barre. Chaque point d'apparition regarde maintenant la tour, le repère de la cité.
- Vérification finale (T-051, 10/11/2026), sur la map habillée et éclairée :
  - Limites, bâtiments, fusibles, scan, alarmes et chemins du monstre IA : couverts par les tests GUT (266, tous verts), dont le parcours du bot jusqu'au 4e de la tour, au fond du parking et sous le rideau.
  - Traversées en courant : 37 à 43 s (sous 45 s).
  - Lieux repères : reconnus sur les captures dans le brouillard (tour, aire de jeux et sa balançoire, galerie et la laverie éclairée, centre social et son enseigne, parking et son « P », transformateur vert, porche de sortie).
  - Performance (rendu OpenGL logiciel, sans GPU) : 97 appels de dessin en moyenne et 192 au pire sur 484 vues (budget 300), 49 000 triangles au plus (budget 150 000), au plus 2 lumières dynamiques visibles (limite 4), chargement de la map en 1,1 s, build web de 45 Mo sans erreur dans Chrome.
  - Reste ouvert : les 60 images/s ne se mesurent pas sans carte graphique. Tous les budgets qui les garantissent sont tenus ; la mesure sur la machine de référence se fera au point de décision n°2.
