# S-024 — Mode Versus : le monstre devient un boss

**Statut** : armes, vue, ambiance et fin **remplacées par S-025** (Versus arcade, D-024, 26/11/2026). **Validée par Maxime le 26/11/2026** (« go », décision D-023). Le prototype de la salle d'essai (T-371 à T-374) est fait ; la construction suit `tasks.md` à partir de T-375.
**Piliers servis** : P1 (le son trahit : chaque tir fait du bruit et guide le boss), P2 (le dilemme permanent : tirer, c'est se montrer)
**Phase** : hors feuille de route, demandée par Maxime le 26/11/2026 (« un mode Versus où les chassés affrontent le chasseur en mode boss de Dark Souls, jouissif, avec des attaques à distance, le boss jouable aussi, penser à la modélisation du mode FPS et à qui gagne comment »).
**Exigence transverse** : modulaire au maximum (D-022). Le mode Versus est un **module** : retirer le dossier `game/modes/versus/`, ses réglages et sa ligne dans la liste des modes rend le jeu exactement tel qu'avant. Une arme, une attaque du boss ou une phase s'ajoute par **un fichier de données et une scène**, sans toucher au joueur, au réseau ni aux IA. `docs/MODULES.md` dit comment.

## Pourquoi
Le mode Traque (le jeu actuel) est un jeu de peur et de ruse : le chassé fuit, se cache et ne frappe jamais. Maxime veut un **second mode, plus explosif**, pour les soirées où l'on veut se défouler : les chassés s'arment et affrontent ensemble le monstre, qui devient un **boss** à grosse barre de vie, en phases, avec des attaques qu'on apprend à lire. Le monstre reste un **joueur humain** (l'IA le remplace s'il manque quelqu'un), et son rôle doit être aussi jouissif que celui des chassés.

Ce qui garde l'ADN d'Écho : **les armes sont de lumière et de son**, pas des armes à feu (la créature craint la lumière), et **chaque tir fait du bruit** : le boss voit les tireurs en orange comme en mode Traque. Celui qui tire beaucoup fait mal, mais se fait trouver.

## Ce que vit le joueur
**En chassé.** Dans le salon, le chef choisit « Versus » au lieu de « Traque ». Je commence **les mains vides**, à côté d'un coffre. La partie commence dans l'**arène** : la place centrale et le parking de la cité, bouclés par des barrières, 10 minutes au chrono. En bas de l'écran, la barre du boss, longue, avec son nom. En bas à gauche, mes 3 points de vie et ma barre d'endurance.

Le monstre est déjà lâché, à l'autre bout. J'ouvre mon coffre (E, 2 s, ça claque) : un **lance-fusées**. En vue à la première personne, je vois mes **deux mains** et l'arme. Plus loin, un autre coffre me donnera peut-être le **lance-laser UV** ou le canon sonique. Clic gauche : une fusée part en arc, traînée rouge, lumière qui balaie le décor. Elle touche le boss : un « tac » sec, la croix du viseur devient une petite croix blanche, le boss tressaille. En plein visage : croix rouge, le boss recule en hurlant. Chaque tir est un bruit de 20 m : il sait d'où je tire.

Il charge : un rugissement, il se baisse, ses griffes s'écartent (1 s pour réagir). Espace : je fais une roulade sur le côté (endurance), il passe à côté et percute un muret : il est sonné 2 s, on vide nos chargeurs dans son dos. À 66 %, il pousse un cri : les lampadaires de l'arène s'éteignent, il ne reste que nos fusées et nos lasers. De nouveaux coffres apparaissent. À 33 %, il devient **enragé** : plus rapide, il enchaîne, mais il encaisse plus. Camille est à terre : je cours, je maintiens E 3 s pour la relever pendant que Hugo l'occupe au canon sonique. La dernière fusée le touche : ralenti, la caméra tourne autour du boss qui s'effondre. Écran de fin : « Les chassés ont vaincu », carte du meilleur joueur.

**En boss.** Je vois mes **deux bras griffus** devant moi. Clic gauche : coup de griffe. Espace : **charge** (le clic droit garde le scan). Les tirs des chassés apparaissent en orange comme les bruits du mode Traque. Chaque coup encaissé remplit ma **jauge de rage** ; pleine, j'appuie sur R : **Fureur** 10 s, je cours plus vite et mes coups ne s'interrompent plus. En phase 2, je peux **bondir** sur un bruit orange à portée. Un chassé à terre près de moi : je maintiens E pour l'**achever** (il ne pourra plus être relevé), pendant que les autres me tirent dessus pour m'en empêcher. Je gagne quand plus aucun chassé n'est debout, ou si je tiens jusqu'à l'aube (fin du chrono).

## Récits utilisateur
- En tant que chassé, je veux tirer à distance sur le boss avec des armes de lumière et de son, afin de me défouler à plusieurs.
- En tant que chassé, je veux lire les attaques du boss et les esquiver, afin que gagner soit une question d'adresse et non de chance.
- En tant que chassé, je veux relever un coéquipier à terre, afin que l'équipe compte.
- En tant que boss, je veux un kit d'attaques à moi, des phases et une rage, afin que jouer le boss soit aussi jouissif que jouer les chassés.
- En tant que joueur, je veux savoir à tout moment qui gagne et comment, afin de prendre les bons risques.
- En tant que chef de partie, je veux choisir le mode dans le salon, afin de passer de la Traque au Versus entre deux parties.
- En tant qu'agent qui reprend le code, je veux ajouter ou retirer une arme, une attaque, une phase ou le mode entier par des fichiers de données, afin de ne pas toucher au cœur du jeu.

## Clarifications
Les réponses ci-dessous ont été proposées par Claude et **validées par Maxime le 26/11/2026** (« go »), avec ses corrections notées sur place. Les chiffres sont des points de départ, réglés ensuite par simulation.

### Qui gagne, et comment (demande explicite de Maxime)
- Q1 : Comment gagnent les chassés ? → Proposition : en **vidant la barre de vie du boss** avant la fin du chrono. Le dernier coup déclenche un **ralenti de 1,5 s** et une caméra qui tourne autour du boss qui s'effondre, vue par tous (le boss compris).
- Q2 : Comment gagne le boss ? → **Décidé par Maxime le 26/11/2026** (fin du chrono : le boss gagne) : quand **plus aucun chassé n'est debout** au même moment (tous à terre ou hors combat), ou **à la fin du chrono** (« l'aube se lève, la créature survit »).
- Q3 : Combien de temps ? → Proposition : **10 minutes**. À 2 minutes de la fin, une sirène et le texte « L'aube approche » ; le boss passe en phase 3 s'il n'y est pas encore.
- Q4 : Le boss peut-il gagner en se cachant jusqu'à l'aube ? → Proposition : non. S'il ne touche ni ne charge personne pendant **45 s**, il est « **traqué** » : sa silhouette apparaît en rouge aux chassés jusqu'à sa prochaine attaque (le miroir du bruit orange). Et sa rage se vide quand il n'attaque pas.
- Q5 : Que se passe-t-il quand un chassé tombe ? → Proposition : à **0 point de vie**, il est **à terre** : il rampe lentement, ne peut plus tirer, et se vide en **30 s**. Un coéquipier le relève en maintenant E **3 s** à côté de lui (bruit de 8 m) ; il revient avec 2 points de vie. Chaque chassé peut être relevé **2 fois** ; la 3e fois, ou si le chrono de 30 s finit, ou si le boss l'**achève** (E maintenu 2 s, interrompu par tout coup qui le fait tressaillir), il est **hors combat** et devient spectateur.
- Q6 : Égalité possible ? → Proposition : non. Si le dernier chassé tombe dans la même image que le boss, les chassés gagnent (récompense le coup de la dernière chance).

### Le boss
- Q7 : Combien de vie ? → Proposition : **400 points par chassé** au départ (2 chassés : 800, 3 : 1 200, 4 : 1 600), pour que le temps du combat reste proche à 2 et à 4.
- Q8 : Quelles phases ? → Proposition : trois, listées dans `game/modes/versus/data/phases/*.tres` :
  1. **Rôdeur** (100 à 66 %) : griffe, charge, scan comme en Traque (jauge de 8 s).
  2. **L'écho** (66 à 33 %) : à l'entrée, un **cri** éteint les lampadaires de l'arène pour le reste de la partie ; il gagne le **bond** sur un bruit.
  3. **Enragé** (33 à 0 %) : +20 % de vitesse, griffe en double coup, mais il prend **+25 % de dégâts** (le moment où tout se joue).
  À chaque changement de phase, il est invulnérable 2 s (le cri), ce qui donne aux chassés le temps de se regrouper.
- Q9 : Quelles attaques ? → Proposition, chacune avec un **signal** lisible avant le coup (posture, son) :
  | Attaque | Touche | Signal | Effet | Recharge |
  |---|---|---|---|---|
  | Griffe | clic gauche | bras levé 0,35 s | 1 point de vie, 2,5 m, arc de 90° | 0,8 s |
  | Charge | Espace (le clic droit reste au scan) | rugissement, il se baisse 0,6 s | ligne droite de 14 m, 2 points de vie ; contre un mur, il est **sonné 2 s** | 8 s |
  | Bond (phase 2+) | E en visant un bruit orange à moins de 25 m | ombre au sol pendant 1 s à l'arrivée | onde de 3 m, 1 point de vie et renverse | 12 s |
  | Achever | E maintenu 2 s sur un chassé à terre | il se penche, grognement | le chassé est hors combat | — |
  | Fureur | R quand la rage est pleine | yeux rouges, souffle | 10 s : +25 % de vitesse, ses attaques ne sont plus interrompues | rage vide |
  Le **scan** du mode Traque reste (même touche, même jauge).
- Q10 : La rage ? → Proposition : elle se remplit de 1 % par 10 points de dégâts reçus et de 5 % par coup donné ; elle se vide de 1 % par seconde sans attaquer. Pleine, R lance la Fureur.
- Q11 : Peut-on l'étourdir ? → Proposition : oui, par une **barre d'équilibre** cachée (« posture » à la Dark Souls) : chaque coup au visage, chaque pétard sous lui et chaque tir du canon sonique la remplissent ; pleine, il **tombe à genoux 3 s** et prend **double dégâts**. Il ne peut pas être remis à genoux avant 15 s (pas d'enchaînement sans fin, constat 3 de l'audit du 20/11/2026).
- Q12 : Le boss IA ? → Proposition : le monstre IA du mode Traque, avec un cerveau de combat en plus (`BossBrain`, classe pure) : choisit sa cible (le plus proche, ou celui qui l'a le plus touché), charge quand une ligne est libre, bondit sur un tireur isolé, se met à l'abri quand sa posture est presque pleine, lance la Fureur dès qu'il peut. Mêmes règles et mêmes chiffres que le boss joué.

### Les chassés
- Q13 : Quelles armes ? → **Décidé par Maxime le 26/11/2026** : on les trouve dans des **coffres** (Q29 à Q33), il n'y a pas de choix avant la partie. On porte **une arme** (clic gauche) et **2 outils** (touches 1 et 2) :
  | Arme ou outil | Touche | Effet | Munitions | Bruit |
  |---|---|---|---|---|
  | **Lance-fusées** (premier coffre de chacun) | clic gauche | projectile en arc rapide (45 m/s), 30 points, 60 au visage (et posture) ; la fusée reste au sol 8 s et éclaire | 6 dans le chargeur, rechargement 2 s (touche R) ; caisses de fusées dans l'arène | 20 m |
  | **Lance-laser UV** (arme, remplace la lampe UV, Maxime 26/11/2026) | clic gauche maintenu | rayon instantané de 30 m là où l'on vise : 15 points par seconde tant qu'il suit le boss, double au visage, et le ralentit de 30 % | batterie 6 s, recharge 10 s | 6 m (bourdonnement) |
  | **Canon sonique** | 1 ou 2 | repousse le boss de 6 m, interrompt son attaque, remplit sa posture, 0 dégât | 3 charges | 30 m |
  | **Pétards** (S-020) | 1 ou 2 | 40 points et posture s'ils éclatent sous lui | 2 | comme en Traque |
  | **Fumigène** (S-020) | 1 ou 2 | coupe la vue du boss | 2 | comme en Traque |
  | **Trousse** | 1 ou 2 | relève un coéquipier en 1,5 s au lieu de 3 s, ou rend 1 point de vie à soi | 2 | 4 m |
- Q14 : Combien de vie pour un chassé ? → Proposition : **3 points de vie**, l'écran rougit et le son s'étouffe à chaque coup. Pas de régénération (seulement la trousse et le relevé).
- Q15 : Peut-on esquiver ? → Proposition : oui, **roulade** sur Espace (touche libre aujourd'hui) dans la direction de déplacement : 3 m en 0,4 s, **invulnérable** pendant 0,25 s. Coûte 35 % d'une barre d'**endurance** qui sert aussi à courir et se recharge en 3 s. Bruit de 6 m.
- Q16 : Les chassés se blessent-ils entre eux ? → Proposition : non, aucun tir ami.
- Q17 : Les chassés IA ? → Proposition : les places vides sont tenues par des IA (comme en Traque) : elles gardent leurs distances, tirent quand le boss est en vue, esquivent sur le signal, relèvent un coéquipier quand le boss est loin. Elles vont au coffre le plus proche, puis cherchent un lance-laser UV ou un canon sonique.

### Les coffres (demande de Maxime du 26/11/2026, « on démarre sans arme », validé le 26/11/2026)
- Q29 : Comment démarre-t-on ? → **Sans arme.** Chaque chassé apparaît **à côté d'un coffre** qui contient son lance-fusées. Le monstre apparaît à l'autre bout de l'arène (environ 60 m) et peut **attaquer dès la première seconde** (« le boss doit aussi pouvoir attaquer » : pas d'enfermement au départ).
- Q30 : Comment ouvre-t-on un coffre ? → En le visant et en maintenant **E 2 s** ; le couvercle claque : **bruit de 10 m**, le monstre voit où l'on s'équipe. Un coffre ouvert reste ouvert et vide.
- Q31 : Que contient un coffre ? → Le premier coffre de chacun : le **lance-fusées**. Les autres, tirés au sort : le lance-laser UV (arme), un outil (canon sonique, trousse, pétards, fumigène) ou des fusées. Une nouvelle arme remplace l'ancienne, laissée au sol ; un outil prend une place libre, sinon remplace celui de l'emplacement choisi.
- Q32 : Combien de coffres ? → Au départ, un par chassé plus 4 dans l'arène. À chaque phase du monstre (66 % et 33 %), **3 nouveaux coffres** apparaissent, au contenu meilleur (plus de lance-laser et de canons) : de quoi relancer le combat.
- Q33 : À quoi ressemblent-ils ? → Une **malle militaire kaki** à coins métalliques, d'où sort une lueur rouge à l'ouverture (rendu validé le 26/11/2026, `echo-s024/4_coffre.png` dans les fichiers du projet).
- Designs des armes (rendus du 26/11/2026, à affiner) : **lance-fusées** en pistolet de détresse rouge à bague crème ; **lance-laser UV** gris anthracite à tube de charge violet et canon à ailettes ; **canon sonique** en mégaphone jaune et blanc branché sur une batterie de voiture. Aucune pièce orange (couleur réservée aux bruits).

### La vue à la première personne (« modélisation du mode FPS », demande explicite de Maxime)
- Q18 : Que voit le chassé de lui-même ? → Proposition : ses **deux avant-bras** (manches du costume de son personnage, mains en gants) et ses armes, en **un seul modèle** fait par script Blender (`tools/blender/viewmodels.py`), une seule texture de 128 px, pour **1 appel de dessin**. Animations par code (pas de squelette) : balancement à la marche, recul au tir, rechargement (la main gauche glisse une fusée), tube du laser qui s'allume, mains baissées à terre.
- Q19 : Et le boss ? → Proposition : ses **deux bras griffus** (même peau que le modèle du chasseur, S-011), 1 appel de dessin. Griffe : le bras droit balaie l'écran ; charge : les deux bras en avant ; Fureur : veines rouges.
- Q20 : Comment les autres voient-ils les armes ? → Proposition : le modèle du chassé (S-011) tient le lance-fusées dans la main droite (accroché à l'os de la main), avec un geste de tir et de roulade. Le boss garde son modèle actuel, avec les gestes griffe, charge, bond, cri.
- Q21 : Retour d'un coup touché (« hit feedback ») ? → Proposition : croix du viseur blanche (touché) ou rouge (visage), son « tac » à 2 hauteurs, éclat de lumière sur le boss, boss qui tressaille. Pour le boss : bord de l'écran rouge du côté du tir, secousse de la caméra au coup au visage. Pas de chiffres de dégâts à l'écran (lisible, pas un jeu de tableur).
- Q22 : Les bras ne passent-ils pas à travers les murs ? → Proposition : les bras sont dessinés « devant tout » par leur matériau (profondeur ramenée près de l'œil dans le shader), sans seconde caméra (pas d'appel de dessin en plus).
- Q23 : Viseur ? → Proposition : croix fine au centre pour les chassés (le lance-fusées tire en arc : la croix montre le départ, la fusée retombe un peu après 25 m) ; pour le boss, le réticule actuel et un cercle qui montre la portée de la griffe.

### L'arène et la partie
- Q24 : Où se joue le Versus ? → Dans la **cité des Tilleuls**, sur une **arène inspirée de la map** (Maxime, 26/11/2026 : « inspire-toi de la map ») bouclée par des barrières de chantier : la place centrale, le parking et l'aire de jeux (environ 90 × 70 m), avec des murets pour s'abriter et des caisses de fusées. Les bâtiments de l'arène restent fermés (pas d'intérieurs : moins de chemins, combat lisible, budget d'appels de dessin tenu), mais **leurs toits sont accessibles** (Maxime, 26/11/2026) par des échelles et escaliers de secours extérieurs : un tireur en hauteur voit loin, mais le boss l'y suit (Q34). Une arène plus grande ou d'autres arènes plus tard, chacune par un fichier de données.
- Q34 : Et si l'on tombe d'un toit ? → **Dégâts de chute** (Maxime, 26/11/2026 : « prévoir chute »), pour les chassés comme pour le boss : rien sous 4 m ; 1 point de vie de 4 à 7 m ; 2 points au-delà de 7 m ; une chute de plus de 10 m (un toit de la tour) met **à terre**. Le boss, lui, perd 5 % de sa vie par chute de plus de 7 m, et se relève **sonné 1 s** (on le punit de sauter). Une roulade (Espace) au moment de l'atterrissage enlève 1 point de vie de dégâts. Chaque chute de plus de 4 m fait un bruit de 15 m.
- Q25 : Combien de joueurs ? → Proposition : **1 boss contre 2 à 4 chassés**, humains ou IA ; le boss est toujours un humain en ligne (comme en Traque), tiré au sort au lancement.
- Q26 : Dans le salon ? → Proposition : le chef choisit le **mode** (« Traque » ou « Versus ») avant de lancer, sur la ligne au-dessus du nombre de joueurs. En solo, « Jouer seul › Versus » contre le boss IA ou en boss contre des chassés IA.
- Q27 : Le son et la règle du monstre caché ? → Proposition : en Versus, la règle 2.3 « le monstre ne se montre pas plus de 2 s d'affilée » ne s'applique pas (on le combat en face) : c'est la décision **D-023** à écrire au journal. La musique de tension (S-012) passe en musique de combat, plus forte à chaque phase.
- Q28 : Fin de partie ? → Proposition : écran de fin de S-020 avec, en plus : vainqueur, temps, dégâts par chassé, relevés, coups au visage, et la carte du **meilleur joueur** (« MVP ») à partager.

## Hors périmètre
- Les armes à feu réelles, le sang, les blessures visibles : tout est lumière, son et choc.
- Les intérieurs dans l'arène, d'autres maps d'arène (une par spec ou par fichier de données plus tard).
- Le classement, les comptes, la progression entre les parties.
- Le matchmaking public (voir Q-005 et l'avis de Maxime du 20/11/2026 : plus tard, quand il y aura des joueurs).

## Critères d'acceptation
- [ ] Dans le salon, le chef choisit Traque ou Versus ; en solo, « Jouer seul › Versus » en chassé ou en boss.
- [ ] L'arène s'inspire de la cité, ses toits sont accessibles et une chute fait des dégâts (Q24, Q34).
- [ ] Les chassés démarrent sans arme, s'équipent dans les coffres (Q29 à Q32), tirent au lance-fusées et au lance-laser UV, utilisent 2 outils, esquivent, tombent à terre, se relèvent entre eux, selon Q5 et Q13 à Q16.
- [ ] Le boss (joué ou IA) a ses 5 attaques, ses 3 phases, sa rage, sa posture, selon Q7 à Q12.
- [ ] Les conditions de victoire de Q1 à Q6 sont tenues, et l'écran de fin le dit (Q28).
- [ ] Vue à la première personne : bras et armes des chassés, bras du boss, retour des coups, sans passer dans les murs (Q18 à Q23).
- [ ] En ligne : la salle fait autorité sur les tirs et les coups ; test à 4 robots en CI (`net_versus`) vert.
- [ ] Le mode Traque ne change pas : tous ses tests et `net_match` restent verts.
- [ ] Équilibre : 20 parties simulées par effectif (boss IA contre 2, 3 et 4 chassés IA), le boss gagne 40 à 60 % des parties, durée moyenne de 5 à 9 min, aucun blocage.
- [ ] Budgets : 60 images/s, 300 appels de dessin dans l'arène, 4 lumières dynamiques visibles, 60 Mo.
- [ ] Retirer le module (dossier, réglages, ligne de la liste des modes) laisse le jeu compiler et tous les tests du mode Traque verts ; `docs/MODULES.md` le décrit.

## Notes de playtest
