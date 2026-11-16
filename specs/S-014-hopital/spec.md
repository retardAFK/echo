# S-014 — L'hôpital dans la cité

**Statut** : brouillon (16/11/2026), propositions de Claude à valider par Maxime
**Piliers servis** : P1 (le son trahit), P2 (le dilemme permanent), P3 (l'inquiétante familiarité)
**Phase** : 14 — L'hôpital dans la cité (D-019 : intégré à la cité des Tilleuls, vraiment effrayant)

## Pourquoi
La cité des Tilleuls a quatre bâtiments visitables, tous à l'est et au centre. L'ouest de la map n'a que la barre C, une façade où personne n'entre. D-019 a décidé que l'hôpital ne serait pas une map séparée mais un grand bâtiment de la cité, sur plusieurs niveaux, qui doit faire vraiment peur. La planche d'ambiance du 15/11/2026 (façade, couloir, morgue, chambre d'isolement) est validée. Cette spec dit où il va, comment il se joue et comment il tient dans le budget de performance, qui est presque plein.

## Ce que vit le joueur
**En chassé**, je longe la barre A vers l'ouest. Là où il y avait une barre de logements, il y a maintenant l'hôpital Saint-Roch, six étages de fenêtres noires. Sous l'auvent des urgences, une ambulance abandonnée, portes ouvertes. Une croix verte de pharmacie clignote au-dessus de l'entrée. J'entre dans le hall. Le couloir du rez-de-chaussée part à droite et à gauche, si long que ses néons verts se perdent dans le brouillard. L'un d'eux grésille, s'éteint, se rallume. Au loin, quelque chose roule sur le carrelage, puis s'arrête. Je descends au sous-sol : la ventilation de la chaufferie couvre mes pas, je peux marcher sans m'accroupir. À la morgue, j'entends le monstre dans l'escalier. Je me glisse dans un tiroir réfrigéré. Il ouvre le tiroir voisin, deux secondes de métal qui grince. J'en profite pour sortir par la rampe du quai, dans l'allée de service.

**En monstre**, j'entends un fauteuil roulant traverser le couloir du premier étage, très loin. Je ne cours pas : je scanne. Le scan n'entend que l'étage que je vise. Rien au premier. Je vise le sous-sol : un souffle dans la chaufferie, à peine audible sous la ventilation. Le fauteuil était un leurre.

## Récits utilisateur
- En tant que chassé, je veux un bâtiment immense et sombre qui me fait peur, afin que chaque visite soit une décision.
- En tant que chassé, je veux des endroits où mes petits bruits sont couverts, et des objets bruyants à envoyer ailleurs, afin de tromper le monstre avec ce que l'hôpital me donne.
- En tant que monstre, je veux que l'hôpital ne soit pas un piège évident, afin de devoir deviner où chercher dans un bâtiment à quatre niveaux.
- En tant que joueur, je veux que la cité reste la même partout ailleurs, afin de garder mes repères.

## Plan sur papier (T-181)
Voir [`plan-hopital.svg`](plan-hopital.svg), généré par `tools/plans/make_hospital_plan.py`. 1 unité = 1 m, le nord en haut.

- **Emprise** : 22 × 76 m (x de 10 à 32, y de 56 à 132 sur le plan de la cité), à la place de la barre C. Une allée de service de 4 m derrière (entre l'hôpital et le grillage de la friche), ouverte au nord. Devant, un parvis jusqu'à l'allée ouest (x = 40), et l'auvent des urgences (6 × 24 m) avec une ambulance.
- **Niveaux** : sous-sol (−3,5 m), rez-de-chaussée, 1er et 2e étages visitables. Les 3e à 5e sont condamnés par une grille dans l'escalier, comme la tour : de dehors, l'hôpital fait 6 niveaux et domine l'ouest de la cité.
- **Un couloir central de 3 m sur 74 m** à chaque niveau, avec des pièces des deux côtés. C'est l'image de la planche d'ambiance : la vue porte loin, mais le brouillard intérieur en cache le bout.
- **Circulations** : deux escaliers (nord-est et sud-ouest) du sous-sol au 2e, un ascenseur bloqué entre deux étages (cachette en métal au 2e), un escalier de secours extérieur en métal du 2e au sol, sur la façade sud.

| Niveau | Pièces | Issues |
|---|---|---|
| Sous-sol | morgue (tiroirs), salle d'autopsie, quai de la morgue, chaufferie (ventilation), 4 cellules d'isolement capitonnées, lingerie, archives en labyrinthe, local technique | 2 escaliers, rampe du quai vers l'allée de service |
| Rez-de-chaussée | hall, accueil, bureau des entrées, salle d'attente, box des urgences à rideaux, sas des urgences, salle de soins, 2 salles de radio, pharmacie | entrée principale, porte des urgences, bouts nord et sud du couloir, porte arrière de la pharmacie (5) |
| 1er étage | 10 chambres, sanitaires, poste de soins (terminal), lingerie | 2 escaliers |
| 2e étage | bloc opératoire (sas, 2 salles, portes battantes), réanimation (moniteurs, box vitrés), stérilisation, salle de repos, réserve | 2 escaliers, escalier de secours en métal |

## Clarifications
- Q1 : Où va l'hôpital ? → Proposition : **à la place de la barre C**, à l'ouest. C'est le seul côté de la map sans bâtiment visitable, donc l'hôpital rééquilibre la cité au lieu de l'encombrer ; la taille de la map ne change pas (220 × 220 m, D-010) et les allées restent les mêmes. Alternatives : à la place de la barre D (à l'est, déjà dense avec le centre social et le parking), ou agrandir la map vers l'ouest (traversée plus longue que 45 s, tout le plan de S-006 à reprendre).
- Q2 : Quelle taille et combien de niveaux ? → Proposition : **22 × 76 m, 4 niveaux visitables** (sous-sol, RDC, 1er, 2e), 6 niveaux de haut vus de dehors. C'est le plus grand bâtiment de la cité (environ 6 700 m² visitables, la tour en a 2 900), mais il garde un seul couloir par niveau, donc on s'y repère vite.
- Q3 : Comment le rendre effrayant ? → Proposition, d'après la planche validée :
  - **Lumière** : néons verts, un sur trois mort, quelques-uns qui grésillent et clignotent, presque rien au sous-sol ; croix verte de pharmacie qui clignote dehors. Jamais d'orange (réservé au bruit, section 2).
  - **Couloirs** : le couloir de 74 m, avec un brouillard intérieur un peu plus dense que dehors pour qu'on n'en voie jamais le bout.
  - **Traces d'évacuation précipitée** : lits renversés, dossiers par terre, perfusions, fauteuils au milieu du couloir, un brancard en travers d'une porte.
  - **Lieux** : la morgue (tiroirs, table d'autopsie), les cellules d'isolement capitonnées, le bloc opératoire.
  - **Sons lointains qui ne viennent de nulle part** : un chariot qui roule, une porte qui claque, l'ascenseur qui sonne, un moniteur qui bipe dans une chambre vide. Ce sont des sons d'ambiance, **pas des bruits de jeu** : le monstre ne les voit pas sur son écran, pour que ses marqueurs orange restent vrais.
- Q4 : Que devient le scan dans un si grand bâtiment ? → Proposition : **le scan entend un seul niveau**, celui que le monstre vise. De dehors, il vise une fenêtre du RDC, du 1er ou du 2e ; le sous-sol se scanne en visant les soupiraux ou la rampe du quai. De dedans, il scanne le niveau où il se trouve. La jauge reste la même (D-009). Ainsi l'hôpital n'est pas un piège où tout s'entend d'un coup, et le monstre doit deviner le bon étage (P2). Le viseur du scan nomme le niveau (« Hôpital, 1er étage »).
- Q5 : Ventilation ? → Proposition : la **chaufferie du sous-sol** et les gaines du **bloc opératoire** sont des zones de ventilation. Dedans, tout bruit de portée **4 m ou moins** (marche, porte ouverte accroupi, cachette basse) n'est ni entendu par le monstre ni par le scan. Courir, claquer une porte ou faire tomber quelque chose s'entend toujours. On reconnaît la zone au grondement et aux grilles de ventilation.
- Q6 : Moniteurs ? → Proposition : **6 moniteurs** (réanimation, chambres). Un chassé en allume un avec E : il bipe fort pendant **10 s** (bruit de **15 m**), puis se tait. Chacun sert **une fois** par partie. C'est un leurre comme les réveils (S-008), mais placé, pas lancé. Le monstre l'éteint avec E.
- Q7 : Brancards et fauteuils roulants ? → Proposition :
  - **Brancard** (4) : on le prend avec E et on le pousse devant soi (il roule : **6 m** en marchant, **10 m** en courant). Lâché en travers d'une porte ou du couloir, il bloque le passage. Le monstre le dégage en **1 s** d'un coup d'épaule (bruit de **10 m**), sans s'arrêter s'il court.
  - **Fauteuil roulant** (4) : on le pousse d'un coup avec E ; il roule seul **8 m** dans la direction visée en grinçant (bruit de **8 m** qui se déplace avec lui). C'est un leurre qui bouge.
- Q8 : Combien de cachettes et lesquelles ? → Proposition : **15 cachettes**, des familles de S-016 : lits (basses), placards et armoires (P), rideaux des box des urgences et de la douche (fortune), **tiroirs de la morgue** et ascenseur bloqué (métal). Toujours aux mêmes places.
- Q9 : Fusibles et objectifs ? → Proposition : l'hôpital devient le **5e bâtiment visitable**. Il a **6 emplacements de fusible** comme les autres (2 au sous-sol, 2 au RDC, 1 au 1er, 1 au 2e) et peut recevoir un fusible comme eux (D-010 : un fusible est toujours dans un bâtiment visitable). Pour les objectifs de S-018 : un **terminal** au poste de soins du 1er, une **caméra** dans le couloir du RDC, un **haut-parleur** (l'appel sonore de l'accueil), un **interrupteur de relais** au local technique du sous-sol (paire avec la galerie), et un endroit où le **code** peut être écrit (le tableau des gardes). La boucle de la cité (transformateur, tunnel) ne change pas.
- Q10 : La prison déménage-t-elle à l'hôpital ? → Proposition : **non, pas dans cette spec**. La prison des caves du parking vient d'être réglée (S-018 : terminal du gardien à 80 m, IA, tests en ligne) ; la déplacer remettrait tout cet équilibre en jeu. Les cellules d'isolement restent un décor et une cachette. On pourra les reprendre après une première partie à 4 avec l'hôpital.
- Q11 : Qu'est-ce qui change autour ? → Proposition : la barre C disparaît ; la voiture à alarme de (35, 120) devient l'**ambulance** sous l'auvent (même alarme) ; les points d'apparition des chassés à l'ouest restent sur l'allée et regardent la tour ; la carte des chassés (S-017) dessine l'hôpital comme les autres bâtiments, sans le nommer différemment. Le monstre apparaît toujours au sud-est.
- Q12 : Comment tenir le budget, déjà presque plein ? → Proposition, à faire **avant** de construire :
  - **Taille du build web** (59,5 Mo sur 60) : la map générée est enregistrée en texte (14 Mo) puis exportée en binaire non compressé (11 Mo). Enregistrée en **binaire compressé**, elle pèse **1,1 Mo** (mesuré). On regagne environ 10 Mo, de quoi accueillir l'hôpital.
  - **Appels de dessin** (294 au pire pour 300) : une **visibilité par niveau**. Les intérieurs (revêtement, mobilier, portes, lumières) d'un niveau ne sont dessinés que si la caméra est à ce niveau ou juste à côté, ou dehors à moins de 25 m du bâtiment. Cela vaut pour la tour et le parking aussi, donc le pire point actuel baisse avant même l'hôpital. Comme pour S-019 : un seul maillage de revêtement par niveau, les objets répétés (lits, chaises, tiroirs) en MultiMesh.
  - **Lumières** : au plus 4 lumières dynamiques visibles ; les néons sont de la lumière précalculée (T-049), et seuls 2 ou 3 néons qui grésillent sont de vraies lumières.
  - Objectif : **300 appels de dessin au pire point de toute la map, hôpital compris**, 60 images/s sur la machine de référence, build web sous 60 Mo.
- Q13 : Dans quel ordre ? → Proposition : budget d'abord (map compressée, visibilité par niveau), puis greybox jouable sur les 4 niveaux, scan par niveau, ventilation et moniteurs, brancards et fauteuils, l'hôpital dans la boucle, IA, puis modèles (rendus montrés à Maxime), habillage et lumière, sons (montrés à Maxime), et vérification finale. Les portes de T-185 sont déjà faites (S-016).

## Critères d'acceptation
- [ ] L'hôpital remplace la barre C ; il est fermé, explorable sur 4 niveaux, avec 7 issues vers l'extérieur et au moins 2 escaliers à chaque niveau (jamais de niveau en cul-de-sac) ; la traversée de la map en courant reste sous 45 s.
- [ ] Le scan n'entend que le niveau visé, de dehors comme de dedans, pour le monstre joueur et le monstre IA.
- [ ] Dans les zones de ventilation, les bruits de 4 m ou moins ne sont pas entendus ; les moniteurs, brancards et fauteuils font les bruits de Q6 et Q7.
- [ ] 6 emplacements de fusible, 15 cachettes, le terminal, la caméra, le haut-parleur, le relais et le code marchent dans l'hôpital, en solo et en ligne.
- [ ] Le monstre IA et la proie IA jouent la cité avec l'hôpital : 20 parties simulées sans blocage, durée moyenne qui ne baisse pas.
- [ ] La partie à 4 du test en ligne (CI) passe toujours.
- [ ] Les modèles et les sons de l'hôpital ont été montrés à Maxime sur rendu et à l'écoute.
- [ ] Budget tenu : 300 appels de dessin au pire point de la map, au plus 4 lumières dynamiques visibles, build web sous 60 Mo, 60 images/s mesurées sur la machine de référence.

## Hors périmètre
- Déplacer la prison à l'hôpital (Q10).
- Ascenseurs qui marchent, verrous, objets portés autres que les brancards.
- Une deuxième map (gare, piscine : D-012).
- Des PNJ ou des cadavres visibles.

## Notes de playtest
