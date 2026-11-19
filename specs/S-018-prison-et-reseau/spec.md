# S-018 — Prison et réseau de la cité

**Statut** : livrée (16/11/2026), validée par Maxime, 60 images/s confirmées sur sa machine. Validée dans ses grandes lignes (15/11/2026, Maxime : libération « sur place ou à distance », mécanismes « outils + quêtes tirées au sort »). Les chiffres restent des propositions de Claude, ajustables à la construction.
**Piliers servis** : P1 (le son trahit), P2 (le dilemme permanent), P3 (l'inquiétante familiarité)
**Phase** : hors feuille de route, demandée par Maxime le 15/11/2026 (« une prison où il peut être libéré » et « des mécanismes à distance, un peu informatiques, qui font varier les quêtes »)

## Pourquoi
Aujourd'hui, en ligne, un chassé attrapé reste à genoux sur place et un coéquipier le relève en maintenant E 4 s (S-010, Q2) ; attrapé une deuxième fois, il est éliminé. En pratique, le monstre n'a qu'à rester à côté du prisonnier, et le chassé attrapé n'a plus rien à faire. Les quêtes sont aussi toujours les mêmes : trois fusibles, le transformateur, le tunnel.

Cette spec ajoute deux choses qui se renforcent :
1. une **prison**, un lieu fixe où vont les chassés attrapés et d'où un coéquipier peut les libérer, sur place ou **à distance** ;
2. le **réseau de la cité** : de vieux terminaux reliés à des caméras, des haut-parleurs, des rideaux métalliques et à la grille de la prison. Ils servent de ruses à distance, et de nouvelles quêtes tirées au sort à chaque partie.

## Ce que vit le joueur
**En chassé**, Tom se fait prendre près de la galerie. Écran noir : il se réveille dans une cage grillagée, au sous-sol du parking. Un vieil écran de surveillance grésille dans la cage : il voit les caméras de la cité et dit sur Discord à Léa que le monstre tourne autour du parking. Léa ne descend pas. Elle va au centre social, s'assoit devant le terminal du bureau et lance l'ouverture des cages : dix secondes de clavier qui cliquette, son visage éclairé par l'écran. Au parking, une sonnerie retentit et les cages s'ouvrent. Le monstre l'entend, mais il est déjà trop tard pour garder deux endroits à la fois.

**En monstre**, je vois au loin la petite lumière rouge d'une caméra qui s'allume : quelqu'un me regarde. Je la casse d'un coup, tout le quartier l'entend. Puis la sono du centre social se met à hurler : un leurre lancé depuis un terminal. Je ne cours pas vers la sono, je cherche l'écran allumé.

## Récits utilisateur
- En tant que chassé attrapé, je veux attendre dans une prison d'où l'on peut me libérer, et avoir quelque chose à faire en attendant, afin de rester dans la partie.
- En tant que chassé libre, je veux pouvoir libérer un coéquipier sans passer forcément sous le nez du monstre, afin que le sauvetage soit une ruse et pas un suicide.
- En tant que monstre, je veux que garder la prison soit un pari et non une victoire automatique, afin de devoir choisir entre chasser et garder.
- En tant que chassé, je veux agir à distance (voir, faire du bruit ailleurs, fermer un passage), afin de tromper le monstre autrement qu'en lançant une bouteille.
- En tant que joueur, je veux que les quêtes changent d'une partie à l'autre, afin de ne pas refaire toujours le même trajet.

## Clarifications
### Partie A — La prison
- Q1 : Où est la prison ? → Proposition : les **caves grillagées du parking** (le mobilier de S-016), transformées en **3 cages**, une par chassé. Le parking a 4 issues (rampe, deux escaliers, couloir des caves), donc plusieurs chemins pour venir libérer. Quand l'hôpital sera intégré à la cité (S-014, D-019), sa spec pourra déplacer la prison dans ses sous-sols (chambres d'isolement, morgue).
- Q2 : Comment arrive-t-on en prison ? → Proposition : à la capture, **écran noir de 2 s**, puis le chassé se réveille dans une cage libre. Ses fusibles tombent là où il a été pris (comme aujourd'hui). Pas de transport par le monstre : c'est plus simple en ligne, et le monstre reprend la chasse tout de suite.
- Q3 : Comment libère-t-on sur place ? → Proposition : un chassé libre vise la grille d'une cage et **maintient E 4 s** ; la grille grince (bruit de **8 m**). Cela ouvre **une seule cage**.
- Q4 : Et à distance ? → Proposition : le **terminal du gardien**, dans un autre bâtiment à au moins **80 m** de la prison (au centre social), ouvre **toutes les cages** : maintenir E **10 s** (clavier, bruit de **3 m**, écran qui éclaire le chassé), puis une sonnerie de **15 m** à la prison quand les cages s'ouvrent. Le monstre ne peut pas garder à la fois la prison et le terminal. → R : libération sur place ou à distance (Maxime, 15/11/2026).
- Q5 : Combien de temps reste-t-on en prison ? → Proposition : **120 s** au premier séjour, **60 s** au deuxième. Sans libération à temps, le chassé est **éliminé** et devient spectateur. Attrapé une **troisième fois**, il est éliminé directement. Le temps restant est visible pour le prisonnier, et par une lampe au-dessus de sa cage (qui clignote dans les 20 dernières secondes).
- Q6 : Et si le monstre campe devant ? → Proposition : tant que le monstre est à **moins de 15 m** d'une cage occupée, le chrono de cette cage **s'arrête** : attendre devant la prison ne fait pas gagner. Avec le terminal à distance (Q4), garder la prison devient un pari.
- Q7 : Que fait le prisonnier ? → Proposition : dans sa cage, il regarde les **caméras de la cité** sur un vieil écran (voir Q9), et peut renseigner ses coéquipiers par Discord. Il ne fait aucun bruit et ne peut rien actionner.
- Q8 : Quand le monstre gagne-t-il ? → Proposition : quand **tous les chassés** sont en même temps en prison ou éliminés. En **solo** contre le monstre IA, rien ne change : une capture termine la partie, puisqu'il n'y a pas de coéquipier.

### Partie B — Le réseau de la cité
- Q9 : Qu'y a-t-il sur le réseau ? → Proposition :
  - **6 terminaux** (vieux PC beiges, écran vert) : 1 ou 2 par bâtiment visitable, plus le terminal du gardien (Q4).
  - **8 caméras** de surveillance aux carrefours et dans les bâtiments.
  - **3 haut-parleurs** : la sono du centre social, l'alarme incendie de la tour, l'interphone de la galerie.
  - **2 rideaux métalliques** : la galerie et l'entrée du parking.
- Q10 : Comment utilise-t-on un terminal ? → Proposition : on vise l'écran et on maintient E 1 s pour s'y installer. Un petit menu s'ouvre (souris), **sans pause** : pendant ce temps le chassé est immobile, son clavier fait un bruit de **3 m** et l'écran l'éclaire, visible de loin dans le noir. On quitte avec E ou en bougeant.
- Q11 : Que permet-il ? → Proposition :
  - **Caméras** : voir l'image d'une caméra (basse définition, en noir et vert). Une caméra regardée allume sa **lumière rouge**, que le monstre peut voir. Le monstre casse une caméra avec E (bruit de **10 m**) : elle est morte pour la partie.
  - **Haut-parleurs** : déclencher un bruit fort (**25 m**, 5 s) à l'endroit du haut-parleur. Chaque haut-parleur sert **une fois** par partie. C'est un leurre à distance (même famille que les réveils de S-008).
  - **Rideaux métalliques** : baisser un rideau pendant **20 s** (bruit de **12 m** au rideau). Il bloque tout le monde, monstre compris, puis remonte. Recharge de **60 s**.
  - **Prison** : ouvrir les cages, depuis le terminal du gardien seulement (Q4).
- Q12 : Le monstre a-t-il des terminaux ? → Proposition : **non**. Son rôle reste la chasse au bruit et le scan. En revanche il **éteint** un terminal avec E (il reste éteint 60 s) et il voit les écrans allumés et les lumières rouges des caméras. Un terminal en cours d'usage s'entend aussi pendant un **scan** du bâtiment.

### Partie C — Les quêtes varient
- Q13 : Comment varient les quêtes ? → Proposition : la sortie s'ouvre toujours après **3 objectifs**, mais ils sont **tirés au sort** à chaque partie parmi 4 types, avec toujours **au moins un fusible** et jamais deux fois le même autre type (→ R : outils et quêtes tirées au sort, Maxime, 15/11/2026) :
  - **Fusible** (actuel) : trouver un fusible et le poser au transformateur.
  - **Code** : un code à 4 chiffres est écrit quelque part dans un bâtiment (tableau blanc, post-it, écran) ; le taper sur le terminal du transformateur.
    - Lecture (T-271, 19/11/2026, après le test de Maxime : « il ne semble pas y avoir de code sur les post-it ») : le code est sur **un seul** des post-it (au mur derrière chaque ordinateur), les autres sont vierges. Les chiffres sont plus grands et plus foncés ; face à un post-it à moins de **2,5 m**, le HUD écrit « Post-it : 4719 » ou « Post-it vierge, le code est sur un autre ». La liste des objectifs (Tab) dit où chercher (« sur un post-it, au mur près d'un ordinateur », un type d'endroit, jamais une position) et, une fois le code lu, le rappelle ; le clavier du transformateur le rappelle aussi. Les règles ne changent pas.
  - **Téléchargement** : lancer un téléchargement sur un terminal tiré au sort ; il dure **45 s** et le disque dur gratte (bruit de **5 m** toutes les 3 s). On peut s'éloigner, mais si le monstre éteint le terminal, il repart de zéro. À la fin, emporter la disquette au transformateur.
  - **Relais** : actionner deux interrupteurs dans deux bâtiments différents à moins de **25 s** d'écart (15 s proposés au départ ; portés à 25 s par T-268, car deux leviers d'une paire sont jusqu'à 90 m l'un de l'autre par les chemins, 17 s en courant). À deux, c'est facile ; seul, il faut courir, donc faire du bruit.
- Q14 : Comment le chassé sait-il quoi faire ? → Proposition : la liste des 3 objectifs s'affiche avec Tab, à côté de la carte (S-017), **sans position** (D-018 reste vrai : la carte ne donne aucun indice). Les terminaux, eux, sont toujours aux mêmes places et dessinés sur la carte comme des bâtiments, sans icône.

### Partie D — Déroulé
- Q15 : Dans quel ordre ? → Proposition : après la fin de S-016 (les deux touchent la cité), dans l'ordre : prison sur place (A), terminaux et caméras, terminal du gardien, haut-parleurs et rideaux, quêtes tirées au sort (C), IA (le monstre IA éteint les terminaux et passe voir la prison, la proie IA libère et utilise les leurres), modèles et sons montrés à Maxime, vérification. Bloc de tâches **T-260 à T-289**.

## Critères d'acceptation
- [x] Un chassé attrapé en ligne se réveille dans une cage de la prison ; ses fusibles restent sur place.
- [x] Libérer sur place prend 4 s et ouvre une cage ; le terminal du gardien ouvre toutes les cages en 10 s, avec les bruits de Q3 et Q4.
- [x] Les durées de séjour (120 s puis 60 s), l'élimination à la troisième prise et l'arrêt du chrono quand le monstre est à moins de 15 m marchent.
- [x] Le monstre gagne quand tous les chassés sont en prison ou éliminés ; le solo est inchangé.
- [x] Les terminaux montrent les caméras, déclenchent les haut-parleurs et baissent les rideaux selon Q11 ; le monstre casse les caméras et éteint les terminaux.
- [x] Chaque partie tire 3 objectifs selon Q13, et chaque type d'objectif peut se terminer, en solo et en ligne.
- [x] Tout est synchronisé en ligne ; un chassé ne reçoit jamais la position d'un autre par le réseau, sauf ce qu'il voit lui-même sur une caméra.
- [x] 20 parties simulées sans blocage d'IA ; la durée moyenne ne baisse pas.
- [x] Budget tenu : 300 appels de dessin au pire endroit, 60 images/s mesurées. (Appels de dessin tenus : 297 au pire point, 268 au pire du balayage ; 60 images/s confirmées par Maxime sur sa machine, 16/11/2026.)

## Hors périmètre
- Transport du chassé par le monstre, crochets ou exécutions.
- Terminaux pour le monstre, piratage à mini-jeu.
- Verrous permanents (S-016, Q8 reste vrai : les rideaux remontent seuls).
- Coéquipiers IA en solo.
- La prison dans l'hôpital (à décider dans S-014).

## Notes de playtest
- (vide)
