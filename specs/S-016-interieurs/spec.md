# S-016 — Intérieurs des bâtiments de la cité

**Statut** : en clarification (15/11/2026)
**Piliers servis** : P1 (le son trahit), P2 (le dilemme permanent), P3 (l'inquiétante familiarité)
**Phase** : hors feuille de route, demandée par Maxime le 15/11/2026 (« les bâtiments font vide »)

## Pourquoi
Les 4 bâtiments visitables de la cité des Tilleuls (S-006) sont des boîtes presque vides : une seule cage d'escalier dans la tour, un couloir en cul-de-sac au centre social (la proie IA s'y fait prendre, S-008), des boutiques sans rien dedans, un parking à deux sorties. Un chassé qui entre n'a qu'un chemin pour ressortir, donc le monstre n'a qu'à attendre à la porte. Cette spec donne à chaque bâtiment **plusieurs issues**, des **escaliers**, des **portes** qui s'ouvrent, se ferment et font du bruit, des **cachettes variées** et du **mobilier** : de quoi ruser, boucler, semer le monstre à l'intérieur, et des lieux qui ressemblent enfin à des lieux habités puis abandonnés.

## Ce que vit le joueur
**En chassé**, j'entre dans la tour par le hall. La porte palière du 2e est fermée : je l'ouvre accroupi, doucement, presque sans bruit. Dans l'appartement, un canapé, un lit, des cartons de déménagement. J'entends le monstre monter l'escalier. Je referme la porte derrière moi : il ne me voit plus. Je passe par le trou dans la cloison vers l'appartement voisin, je sors sur le palier opposé et je prends l'escalier de secours en métal, dehors, qui sonne sous mes pas. En bas, la porte coupe-feu des caves claque derrière moi trois secondes plus tard : le monstre l'entend, mais je suis déjà dans le couloir des caves qui mène au parking.

**En monstre**, je poursuis une proie dans le centre social. Elle claque la porte des bureaux. Je la défonce en courant, sans m'arrêter, mais tout le quartier l'entend. Le bureau a deux portes : elle est déjà ressortie par l'autre. Je scanne : un souffle, sous la scène.

## Récits utilisateur
- En tant que chassé, je veux plusieurs façons de sortir de chaque bâtiment, afin de ne jamais être coincé par un monstre posté à l'entrée.
- En tant que chassé, je veux fermer une porte derrière moi, afin de couper la vue du monstre, au prix d'un bruit.
- En tant que chassé, je veux des cachettes de natures différentes, afin de choisir entre une cachette rapide, une cachette silencieuse ou une cachette difficile à fouiller.
- En tant que monstre, je veux traverser une porte sans perdre ma proie, afin que les portes soient une ruse et pas un mur.
- En tant que monstre, je veux reconnaître au son ce qui se passe dans un bâtiment (porte qui claque, marches en métal), afin de lire le bâtiment que je scanne.

## Clarifications (propositions de Claude, à valider par Maxime)
- Q1 : Comment marchent les portes ? → Proposition : on vise et on appuie sur E pour ouvrir ou fermer. Debout, c'est immédiat et ça fait un bruit de **6 m** (section 6.2). **Accroupi**, on ouvre doucement en **1 s** pour un bruit de **2 m**. Une porte fermée **coupe la vue** des deux camps et **atténue le bruit comme un mur** (÷2). Une porte ouverte ne change rien. Les portes reprennent la tâche T-185 de l'hôpital (S-014), qui les réutilisera.
- Q2 : Que fait le monstre devant une porte ? → Proposition : il l'ouvre comme le chassé. S'il **court**, il la **défonce** sans s'arrêter : la porte reste ouverte et fait un bruit de **12 m** qui prévient les chassés. Le monstre IA ouvre les portes sur son chemin, et les défonce en poursuite.
- Q3 : Y a-t-il des portes particulières ? → Proposition : deux. Les **portes coupe-feu** (paliers de la tour, caves, parking) se referment seules **3 s** après le passage en claquant (bruit de **5 m**) : elles trahissent un passage avec un retard, et un chassé malin peut s'en servir comme d'un leurre. Les **issues de secours** à barre anti-panique ne s'ouvrent que de l'intérieur, font un bruit de **10 m**, et restent ouvertes. Pas de verrou dans cette spec (voir Q8).
- Q4 : Combien d'issues par bâtiment ? → Proposition : au moins **3** chacun, et aucune pièce importante en cul-de-sac (toujours une boucle ou une deuxième porte). Tour : hall nord, hall sud, escalier de secours extérieur, couloir des caves. Centre social : entrée nord, entrée ouest, issue de secours au bout du couloir, porte de la cuisine. Galerie : vitrines, couloir de livraison ouvert aux deux bouts, toit par une échelle. Parking : rampe, escalier sud-est, nouvel escalier nord, couloir des caves.
- Q5 : Faut-il relier deux bâtiments ? → Proposition : oui, un seul passage, le **couloir des caves** (environ 25 m, sous terre) entre la cave de la tour et le parking. Il appartient au scan du parking. C'est un vrai raccourci, et un piège si le monstre l'apprend.
- Q6 : Quelles nouvelles cachettes ? → Proposition : trois familles en plus des placards et des bennes actuels.
  - **Cachettes basses** (sous un lit, sous la scène, sous une voiture) : on y entre accroupi en **2 s**, presque sans bruit (**1 m**), mais on en sort aussi en 2 s.
  - **Cachettes de fortune** (derrière le rideau de douche, dans les coulisses, derrière des cartons) : on y entre en **0,5 s** sans bruit, mais le monstre qui passe à **moins de 2 m** en regardant vers elle voit le chassé.
  - **Cachettes en métal** (sèche-linge industriel, coffre de voiture, cabine d'ascenseur bloquée) : entrer fait un bruit de **6 m**, mais le monstre met **2 s** à l'ouvrir, de quoi s'enfuir si on l'entend venir.
  - En tout, environ **40 cachettes** au lieu de 18, toujours aux mêmes places.
- Q7 : Quel mobilier ? → Proposition : de quoi casser les lignes de vue et donner l'impression d'un lieu vécu : appartements (canapé, lit, table, cartons, frigo), centre social (chaises empilées, tables, rideau de scène, cuisine), galerie (comptoirs, rayonnages, présentoirs), parking (cages de caves grillagées, épaves). Modèles simples générés par script Blender, montrés à Maxime sur rendu avant intégration, comme en S-006.
- Q8 : Verrous ? → Proposition : **pas maintenant**. Un chassé qui verrouille une porte bloquerait le monstre ; on garde l'idée pour après une première partie à 4 avec les portes.
- Q9 : Les escaliers en métal font-ils plus de bruit ? → Proposition : oui, sur les marches de l'escalier de secours et les passerelles, la **marche** s'entend à **6 m** au lieu de 4 et la course à 18 m au lieu de 14. Accroupi reste silencieux.
- Q10 : Combien d'emplacements de fusibles ? → Proposition : **6 par bâtiment** au lieu de 4, dont au moins un en étage ou derrière une porte, pour que les nouvelles pièces servent.
- Q11 : Quand ? → Proposition : tout de suite, dans l'ordre : portes (le système), cachettes, puis un bâtiment à la fois (tour, centre social, galerie, parking), puis mobilier, sons et vérification. Les autres phases ne touchent pas la cité, donc rien ne bloque.

## Critères d'acceptation
- [ ] Chaque bâtiment visitable a au moins 3 issues, et aucune pièce où se trouve un fusible n'est en cul-de-sac.
- [ ] Ouvrir une porte debout fait un bruit de 6 m, accroupi de 2 m ; une porte fermée coupe la vue et atténue le bruit.
- [ ] Le monstre (joueur et IA) ouvre les portes et les défonce en courant (bruit de 12 m).
- [ ] Une porte coupe-feu se referme seule en claquant 3 s après le passage.
- [ ] Le couloir des caves relie la tour et le parking, et les deux IA l'empruntent.
- [ ] Les trois nouvelles familles de cachettes marchent selon Q6, pour le joueur et pour la proie IA.
- [ ] Les portes, leurs états et les cachettes sont synchronisés en ligne (S-010).
- [ ] 20 parties simulées sans blocage d'IA, et la durée moyenne ne baisse pas.
- [ ] Budget tenu : 300 appels de dessin au pire endroit, 60 images/s mesurées.

## Hors périmètre
- Les verrous (Q8), les barricades avec des meubles, les fenêtres qu'on enjambe.
- De nouveaux bâtiments visitables : les 7 barres restent en façades.
- Les maps suivantes (hôpital) : elles réutiliseront les portes et les cachettes.

## Notes de playtest
- (vide)
