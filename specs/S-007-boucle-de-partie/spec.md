# S-007 — La boucle de partie

**Statut** : livrée (10/11/2026), validée le 10/11/2026 (Maxime : « yes » à toutes les propositions)
**Piliers servis** : P1 (le son trahit), P2 (le dilemme permanent)
**Phase** : 7 — La boucle de partie

## Pourquoi
La cité des Tilleuls est jouable, mais on y erre sans but : rien ne commence et rien ne finit. Cette spec donne au chassé son objectif (section 6.5 du document de référence) : trouver 3 fusibles cachés dans les bâtiments visitables, réparer le transformateur, puis fuir par le tunnel de sortie. Chaque étape oblige à faire du bruit au mauvais endroit. Le monstre, lui, gagne en attrapant le chassé avant qu'il ne sorte. À la fin de la phase, une partie complète se joue en solo contre le monstre IA, et aussi dans l'autre sens (monstre contre une proie IA), avant de la faire tester à 3 à 5 personnes (point de décision n°2).

## Ce que vit le joueur
**En chassé**, j'apparais au bord de la cité. En haut de l'écran, discret : « Fusibles 0/3 ». Je sais qu'ils sont dans des bâtiments visitables, mais pas lesquels. J'entre dans la galerie. Au fond de la laverie, un boîtier électrique a une petite diode rouge : un fusible est dedans. Je vise le boîtier et je maintiens E. Ça prend 2 s et le métal claque un peu. « Fusibles 1/3 ». Dans la tour, les lumières vacillent : le monstre scanne. Je me fige. Plus tard, avec mes 3 fusibles, je vais au transformateur vert. Poser un fusible prend 4 s et fait un bruit de 8 m. Le monstre arrive en courant, je lâche au deuxième. Je perds la moitié de ma progression, je me cache, je reviens. Au troisième fusible, le transformateur ronfle, une sirène hurle dans toute la cité et la grille du tunnel se lève. Je cours vers le nord. Le monstre sait où je vais. J'atteins le bout du tunnel : « Vous êtes sorti ». L'écran de fin me donne le temps de la partie et le nombre de bruits que j'ai faits, puis « Rejouer » ou « Menu ».

**En monstre**, la proie IA fait la même boucle. Les bruits orange m'indiquent quand elle fouille un bâtiment ou travaille au transformateur. Quand la sirène retentit, je sais qu'elle file vers la sortie, et je dois la couper avant le tunnel.

## Récits utilisateur
- En tant que chassé, je veux un objectif clair, afin de savoir pourquoi je prends des risques.
- En tant que chassé, je veux que chaque étape fasse du bruit, afin de choisir le bon moment pour agir.
- En tant que chassé, je veux une fin, gagnée ou perdue, afin de rejouer en faisant mieux.
- En tant que monstre, je veux savoir où la proie risque d'aller, afin de la piéger.
- En tant que monstre, je veux que la proie IA joue vraiment, afin que mon rôle se teste seul.

## Clarifications
- Q1 : Où sont les fusibles ? → Proposition : comme prévu en S-006 (Q5), à chaque partie, 3 des 4 bâtiments visitables reçoivent un fusible, sur un de leurs 4 emplacements, tiré au hasard. Rien ne les signale à distance. De près, le boîtier qui contient un fusible a une petite diode rouge visible à environ 8 m dans le noir, et les boîtiers vides n'en ont pas. → R : retenu (10/11/2026).
- Q2 : Comment ramasse-t-on un fusible ? → Proposition : je vise le boîtier avec le point de visée, et je maintiens E pendant 2 s. Ça fait un bruit de métal de 3 m. Si je lâche avant la fin, je recommence à zéro, ce qui ne coûte pas grand-chose. Un anneau autour du point de visée montre la progression. On peut porter les 3 fusibles en même temps. → R : retenu (10/11/2026).
- Q3 : Comment répare-t-on le transformateur ? → Proposition : je vise le transformateur et je maintiens E pendant 4 s par fusible, soit 12 s en tout. Chaque pose fait un bruit de 8 m (tôle et étincelles). Si je lâche avant la fin, je garde la moitié de la progression du fusible en cours : se cacher a un prix, mais pas tout (D-009). Les fusibles posés restent posés. → R : retenu (10/11/2026).
- Q4 : Que se passe-t-il quand les 3 fusibles sont posés ? → Proposition : le transformateur se met à ronfler. Une sirène retentit dans toute la cité pendant 10 s, et le monstre l'entend comme un bruit placé au transformateur. La grille du tunnel de sortie se lève. Le monstre IA va alors garder le tunnel. Le chassé gagne en franchissant le bout du tunnel, au nord. → R : retenu (10/11/2026).
- Q5 : Que se passe-t-il quand le chassé est attrapé ? → Proposition : en solo, c'est la défaite immédiate, sans réapparition. Le sauvetage par un coéquipier reste une question ouverte (Q-003), traitée avec le multijoueur. → R : retenu (10/11/2026).
- Q6 : Qu'affiche l'écran de fin ? → Proposition : « Vous êtes sorti » ou « Attrapé », puis la durée de la partie, les fusibles posés, le nombre de bruits faits par le chassé et le nombre de scans du monstre. Deux boutons : « Rejouer », qui relance avec les fusibles tirés à nouveau, et « Menu ». → R : retenu (10/11/2026).
- Q7 : Que fait la proie IA quand je joue le monstre ? → Proposition : elle joue la même boucle. Elle visite les bâtiments un par un, ramasse les fusibles, va au transformateur, puis fuit vers la sortie. Elle garde sa prudence de S-004 : si elle entend ou voit le monstre, elle se cache et se tait, puis reprend. Le monstre gagne s'il l'attrape. Elle gagne si elle sort. → R : retenu (10/11/2026).
- Q8 : Que voit le chassé à l'écran ? → Proposition : « Fusibles 0/3 » en petit en haut de l'écran. Le message « Le transformateur attend 2 fusibles » s'affiche près de celui-ci. Il n'y a ni carte, ni flèche, ni marqueur : on s'oriente avec les repères de la cité. → R : retenu (10/11/2026). → Mise à jour (15/11/2026, D-018) : les chassés ont maintenant une carte du quartier, sans indice (S-017).
- Q9 : Faut-il une durée maximale ? → Proposition : non. Une partie vise 8 à 12 minutes (section 6.5), et on mesure la durée réelle pendant les tests de la phase. Si les parties traînent, on ajoutera une limite ou on rendra le monstre IA plus agressif avec le temps. → R : retenu (10/11/2026).
- Q10 : Où apparaît-on ? → Proposition : on garde les points d'apparition de S-006 pour le chassé, loin du monstre. Le monstre IA démarre au sud-est et patrouille comme aujourd'hui, avec en plus une attirance pour les bâtiments où il a entendu du bruit. → R : retenu (10/11/2026).

## Hors périmètre
- Le multijoueur, plusieurs chassés et le sauvetage (Q-003) : phase 12.
- Les objets lancés, les leurres et les cachettes posées par le joueur : phase 8.
- La musique et le mixage complet : phase 10.
- Les animations du chassé quand il ramasse ou répare : phase 9.

## Critères d'acceptation (vérifiables à la main)
- [x] À chaque partie, 3 fusibles sont placés dans 3 bâtiments visitables différents, et leurs positions changent d'une partie à l'autre.
- [x] Ramasser un fusible et le poser au transformateur prennent le temps prévu, font les bruits prévus, et lâcher une pose fait perdre la moitié de la progression en cours.
- [x] Quand les 3 fusibles sont posés, la sirène retentit, le monstre l'entend et la grille du tunnel se lève.
- [x] Le chassé gagne en franchissant le tunnel, et perd s'il est attrapé. L'écran de fin s'affiche, et « Rejouer » relance une partie neuve.
- [x] En monstre, la proie IA ramasse les fusibles, répare le transformateur et tente de sortir, sans se bloquer.
- [ ] Une partie complète se joue en solo contre le monstre IA, dans les deux rôles, en 8 à 12 minutes en moyenne sur les parties de test.
  → Mesure (T-060), 20 parties simulées proie IA contre monstre IA : 10 sorties en 7,1 à 9,0 min, 10 captures en 2 à 4 min, aucun blocage, moyenne 5,3 min. Une partie menée au bout dure donc environ 8 min ; la moyenne baisse à cause des captures rapides de la proie IA, moins prudente qu'un joueur. À remesurer avec les testeurs du point de décision n°2.
- [x] Les 60 images/s et le budget de performance de S-006 tiennent toujours.
  → Mesure (T-060) : 215 appels de dessin au pire sur 484 vues (budget 300), 2 lumières visibles au plus (budget 4). Les 60 images/s restent à mesurer sur la machine de référence, comme pour S-006.
  → Mesure S-009 (T-077, 13/11/2026) : 59,8 images/s en moyenne sur la machine de référence (Radeon 740M, 1920 × 1080), 1 % les plus lentes à 43,9 ; saccades isolées traitées par T-085.
