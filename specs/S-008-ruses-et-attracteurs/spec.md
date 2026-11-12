# S-008 — Ruses et attracteurs

**Statut** : livrée (12/11/2026), validée le 12/11/2026 (Maxime : « Tout valider »)
**Piliers servis** : P1 (le son trahit), P2 (le dilemme permanent)
**Phase** : 8 — Ruses et attracteurs

## Pourquoi
Depuis S-007, une partie complète se joue, mais le chassé n'a que deux armes : se taire et déclencher une alarme de voiture. Le pilier P1 promet que le chassé a « sa ruse et l'environnement pour brouiller les pistes » (section 6.1 et 6.4 du document de référence). Cette spec lui donne trois outils : **lancer un objet** pour faire un bruit loin de lui, **poser un leurre** qui sonne plus tard, et **se cacher** dans un placard ou une benne. Chacun est un pari : ramasser, lancer ou se cacher fait aussi un peu de bruit, et le monstre apprend à s'en méfier. Côté monstre, chaque ruse est un piège à déjouer : un bruit orange n'est plus forcément un chassé.

## Ce que vit le joueur
**En chassé**, je fouille la galerie. Sur un muret, deux bouteilles vides : je vise et j'appuie sur E, je les prends sans bruit. En bas de l'écran, discret : « 2 bouteilles ». Le monstre rôde près de la tour où je dois aller. Je vise un coin du parking, de l'autre côté, et je clique : la bouteille vole et se brise 15 m plus loin, un bruit de 8 m. Le monstre tourne et part voir. Je file vers la tour. Dans un box de garage ouvert, je trouve un vieux réveil. Je le pose au pied de la barre B avec le clic droit : il fait tic-tac, et dans 15 s il sonnera pendant 10 s. J'ai le temps de m'éloigner. Plus tard, le monstre me voit. Je cours, je casse la ligne de vue au coin du centre social, et j'entre dans un placard du couloir : la porte grince un peu. Je ne vois plus que par la fente. Le monstre passe, s'arrête, repart. Si j'avais couru juste avant, il aurait pu entendre mon souffle avec un scan ; s'il m'avait vu entrer, il aurait ouvert la porte.

**En monstre**, j'entends un bruit d'impact au parking. Est-ce la proie ? J'y cours, il n'y a qu'une bouteille cassée. Je me méfie : je scanne la tour d'à côté, et j'entends des pas. Plus tard, un réveil sonne sous la barre B : je le trouve et je l'écrase en marchant dessus. Je vois la proie entrer dans un placard : j'ouvre la porte avec E et je l'attrape.

## Récits utilisateur
- En tant que chassé, je veux faire du bruit loin de moi, afin d'éloigner le monstre de mon objectif.
- En tant que chassé, je veux un leurre qui sonne plus tard, afin d'être loin quand le monstre arrive.
- En tant que chassé, je veux me cacher quand je suis poursuivi, afin d'échapper au monstre si je casse sa ligne de vue à temps.
- En tant que monstre, je veux pouvoir déjouer les ruses (écraser un leurre, ouvrir une cachette), afin que la ruse reste un pari et pas une victoire automatique.
- En tant que monstre, je veux que la proie IA utilise aussi ces ruses, afin de tester mon rôle seul.

## Clarifications
- Q1 : Quels objets peut-on lancer, et où les trouve-t-on ? → Proposition : des **bouteilles vides**, une vingtaine posées dans la cité (murets, bancs, halls, parking), à des emplacements fixes, toutes présentes à chaque partie. On les ramasse avec E, sans bruit, et on en porte **2 au plus**. Une bouteille lancée est perdue. Il n'y en a pas d'autre sorte pour l'instant. → R : retenu (12/11/2026).
- Q2 : Comment lance-t-on ? → Proposition : **clic gauche** lance une bouteille dans la direction du regard, avec une force fixe : elle va à environ 15 m sur le plat, plus loin en visant un peu vers le haut. Le geste lui-même fait un bruit de 1 m. L'impact fait un bruit `IMPACT` de **8 m** (section 6.2) là où elle se brise, avec un bruit de verre. Une bouteille qui touche un mur se brise contre le mur. Pas de trajectoire affichée : on apprend à viser. → R : retenu (12/11/2026).
- Q3 : Quel leurre sonore, et comment ? → Proposition : un **vieux réveil mécanique**. Il y en a **4 par partie**, tirés au hasard parmi une dizaine d'emplacements (boxes de garages ouverts, parking souterrain, caves), conformément à S-006 (« garage plein de leurres »). On en porte **1 au plus**. **Clic droit** le pose au sol devant soi (bruit de 1 m). Il fait un tic-tac audible à 1 m par le chassé seulement, puis sonne **15 s** plus tard pendant **10 s**, avec un bruit `DECOY` de **12 m** chaque seconde. Un réveil posé ne se reprend pas. → R : retenu (12/11/2026).
- Q4 : Le monstre peut-il faire taire un leurre ? → Proposition : oui, il l'**écrase** en passant dessus (contact, comme une capture). Le monstre IA le fait toujours quand il arrive sur un réveil qui sonne ; le joueur monstre le fait en marchant dessus. Un réveil écrasé ne sonne plus. Les voitures à alarme, elles, ne se coupent pas : elles sonnent leurs 12 s (S-006). → R : retenu (12/11/2026).
- Q5 : Quelles cachettes ? → Proposition : des **placards** (armoires métalliques et placards de couloir) dans les 4 bâtiments visitables, 3 par bâtiment, et des **bennes à ordures** dehors, 6 dans la cité : 18 cachettes en tout, aux mêmes places à chaque partie. On entre ou on sort en visant et en appuyant sur E. Entrer ou sortir prend **1 s** et fait un bruit de **3 m** (porte qui grince, couvercle). Une cachette n'accueille qu'un chassé. → R : retenu (12/11/2026).
- Q6 : Que voit et que fait le chassé caché ? → Proposition : il ne bouge plus, il voit par la fente (un cadre noir avec une bande de vision) et peut tourner la tête un peu. Il est **invisible** pour le monstre et ne fait aucun bruit de pas. Mais le **souffle** d'un chassé essoufflé reste audible au scan (D-009), et un chassé caché ne peut ni ramasser, ni lancer, ni poser. → R : retenu (12/11/2026).
- Q7 : Le monstre peut-il fouiller une cachette ? → Proposition : oui. Il ouvre une cachette en la visant et en maintenant E pendant **1 s** (bruit de 3 m). S'il y a un chassé dedans, c'est une capture. Le **monstre IA** ouvre une cachette s'il a **vu** le chassé y entrer, ou, quand il a perdu la trace pendant une poursuite, il ouvre la cachette la plus proche de l'endroit où il l'a vu pour la dernière fois, une fois sur deux. Il n'ouvre jamais une cachette au hasard en patrouille : se cacher loin de toute poursuite est sûr, sauf si on souffle. → R : retenu (12/11/2026).
- Q8 : Le monstre est-il trompé par les leurres sur son écran ? → Proposition : oui, complètement. L'impact d'une bouteille et la sonnerie d'un réveil apparaissent en orange comme n'importe quel bruit, avec leur distance. C'est au joueur monstre de juger (un bruit d'impact isolé ou une sonnerie régulière sont reconnaissables à l'oreille). Le monstre IA enquête dessus comme sur un autre bruit, sans être plus malin. → R : retenu (12/11/2026).
- Q9 : La proie IA utilise-t-elle les ruses ? → Proposition : oui, simplement. Elle ramasse les bouteilles et les réveils sur son chemin. Si elle entend le monstre ou le voit sans être vue, elle lance une bouteille loin d'elle, dans la direction opposée à son objectif. Avant de réparer le transformateur, elle pose un réveil à 20 m ou plus, si elle en a un. Poursuivie, elle se cache dans la cachette la plus proche hors de vue du monstre, sinon elle fuit comme aujourd'hui. Elle déclenche une alarme de voiture si elle passe à côté pendant une fuite. → R : retenu (12/11/2026).
- Q10 : Faut-il les portes qui s'ouvrent et se ferment (section 6.4 : « portes fermées pour couper la vue ») ? → Proposition : **pas dans cette spec**. Des portes mobiles changent le maillage de navigation des deux IA et demandent de revoir les 4 bâtiments ; on les garde pour une spec à part après le point de décision n°2, si les testeurs en manquent. Les bâtiments gardent leurs ouvertures actuelles. → R : retenu (12/11/2026).
- Q11 : Qu'affiche l'écran ? → Proposition : en bas à droite, en petit, ce que je porte : « 2 bouteilles », « Réveil ». Le point de visée propose « Ramasser », « Se cacher », « Sortir », « Ouvrir » (monstre) selon la cible, comme pour l'alarme de voiture. L'écran de fin ajoute le nombre de ruses utilisées. → R : retenu (12/11/2026).

## Hors périmètre
- Les portes mobiles (Q10).
- Les autres objets lançables (briques, canettes), les pièges et tout objet qui blesse ou ralentit le monstre (le jeu n'est pas un jeu de combat).
- Les ruses propres à l'hôpital, à la gare ou à la piscine : phase 13.
- Le multijoueur et le partage des objets entre chassés : phase 12.
- Les animations de lancer et de cachette : phase 9.

## Critères d'acceptation (vérifiables à la main)
- [x] Une bouteille lancée se brise là où elle tombe, fait un bruit de 8 m, et le monstre IA qui l'entend va enquêter à cet endroit.
- [x] Un réveil posé sonne 15 s plus tard pendant 10 s, attire le monstre IA, et cesse quand le monstre l'écrase.
- [x] Un chassé caché, immobile et non essoufflé, n'est ni vu ni entendu par le monstre ; le scan entend son souffle s'il a couru juste avant.
- [x] Le monstre IA ouvre la cachette où il a vu le chassé entrer et l'attrape ; le joueur monstre peut ouvrir une cachette.
- [x] La proie IA utilise chaque ruse au moins une fois sur une série de parties simulées, et sort plus souvent qu'à la fin de S-007 (10 sur 20). → Chaque ruse utilisée ; sorties 7 à 12 sur 20 selon les séries, environ 1 sur 2 comme S-007. Maxime choisit de livrer et d'équilibrer avec les testeurs (12/11/2026).
- [x] Les 60 images/s et le budget de performance de S-006 tiennent toujours (appels de dessin, lumières, taille du build). → Budget tenu (254 appels de dessin au pire) ; 60 images/s à mesurer sur la machine de référence, comme pour S-006 et S-007.
