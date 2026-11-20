# S-023 — Gadgets au choix, monstre qui monte en puissance, salle d'essai

**Statut** : livrée (20/11/2026, PR #229, #230, #232, #233). Validée le 20/11/2026. Q1 tranchée par Maxime ; les autres réponses sont des propositions de Claude, ajustables.
**Piliers servis** : P1 (le son trahit), P2 (le dilemme permanent)
**Phase** : hors feuille de route, demandée par Maxime le 20/11/2026 après l'audit de game design (constats 4 et 5, « pourquoi pas », plus une salle d'essai), document : https://claude.ai/artifact/17o3XLs5LgtoGrwwnBVhvd
**Exigence transverse** : architecture modulaire au maximum (D-022) : ajouter ou retirer un gadget, un palier du monstre ou un poste de la salle d'essai se fait en ajoutant ou en retirant **un fichier de données et une entité**, sans toucher au joueur, au réseau ni aux IA. `docs/MODULES.md` dit comment.

## Pourquoi
L'audit du 20/11/2026 relève deux déséquilibres d'expérience :
1. **Trop de commandes pour un chassé qui a peur** (constat 4). Depuis S-020, il a une touche par gadget : F (pétard), T (fil à canettes), V (walkman), B (fumigène), en plus de R, X, G, E, Tab, des deux clics et de la molette. Sous stress, on retient 3 ou 4 choses : un débutant poursuivi oublie qu'il a un fumigène, un joueur entraîné les enchaîne tous.
2. **Le monstre ne gagne jamais rien en cours de partie** (constat 5). Les chassés progressent (objectifs, outils, coopération), le monstre garde le même scan de la première à la dernière minute et toutes les nouveautés récentes le gênent.

Maxime demande aussi une **salle d'essai** pour essayer les objets, le scan et le reste sans lancer une vraie partie.

## Ce que vit le joueur
**En chassé**, avant la partie, je choisis **2 gadgets** parmi le pétard, le fil à canettes, le walkman et le fumigène. Je prends le fumigène et le walkman. En jeu, un seul emplacement « gadget » en bas à droite : « Fumigène ×2 ». Je change de gadget (voir Q1) et j'utilise celui qui est affiché avec une seule touche. Les bouteilles, les réveils, le souffle retenu, l'élan et les marques ne changent pas.

Plus tard, mes coéquipiers finissent le premier objectif. Un grondement sourd traverse la cité et une ligne s'affiche : « Le monstre s'énerve ». Je sais que son scan revient plus vite : je ne traîne plus dans les bâtiments.

**En monstre**, chaque objectif réussi par les chassés me donne un cran : la jauge de scan se recharge plus vite, puis ma course dure plus longtemps, puis, à la sirène, mon scan entend tout le bâtiment visé. Perdre du terrain me rend plus dangereux.

**Dans la salle d'essai** (« Jouer seul › Salle d'essai »), j'arrive dans une petite greybox. Chaque poste a une pancarte : gadgets à volonté, bouteilles, réveil, cachette, porte, muret, terminal. Un mannequin de monstre passe sur un rail ; je teste le pétard et la fumée sur lui. Les cercles de bruit (F4) sont affichés. Une touche me fait passer en monstre : un mannequin de chassé marche dans le petit bâtiment, je teste le scan et je vois ce que les leurres affichent.

## Récits utilisateur
- En tant que chassé, je veux choisir mes 2 gadgets avant la partie, afin de jouer à ma façon et de ne pas chercher une touche sous la pression.
- En tant que chassé, je veux une seule touche pour mon gadget, afin d'agir vite quand je suis poursuivi.
- En tant que monstre, je veux devenir plus dangereux à chaque objectif des chassés, afin de sentir que la partie se resserre aussi pour eux.
- En tant que chassé, je veux savoir quand le monstre monte d'un cran, afin d'adapter mes risques.
- En tant que joueur, je veux une salle d'essai, afin d'apprendre les objets et le scan sans perdre une partie.
- En tant qu'agent qui reprend le code, je veux ajouter un gadget, un palier ou un poste d'essai par un fichier de données, afin de ne pas toucher au joueur, au réseau ni aux IA.

## Clarifications
- Q1 : Comment change-t-on de gadget, sachant que la molette sert déjà au délai du réveil (T-313), que son clic marque (T-328) et qu'elle fait défiler le menu des terminaux ? → Proposition : **touches 1 et 2** (rangée du haut, même place en AZERTY et en QWERTY) : chaque touche **choisit et utilise** son gadget, sans étape de sélection. La molette garde ses usages. Autres choix : la molette change de gadget et le délai du réveil passe à « maintenir clic droit » ; ou une touche qui fait tourner les gadgets. → R : **touches 1 et 2** (Maxime, 20/11/2026).
- Q2 : Combien de charges ? → Proposition : **2 gadgets, 2 charges chacun**, soit 4 utilisations comme aujourd'hui (1 de chaque des 4). Valeurs dans `game/data/gadgets/*.tres`.
- Q3 : Où choisit-on ? → Proposition : en solo, sur l'écran « Objectif et commandes » du chassé ; en ligne, dans le salon, avant « Je suis prêt ». Le dernier choix est gardé dans les réglages. Un chassé qui ne choisit rien garde le choix précédent (au premier lancement : pétard et fumigène). Les IA chassées tirent 2 gadgets au hasard, mais seul ce qu'elles savent utiliser (pétard aujourd'hui) est tiré tant que leur IA n'en sait pas plus.
- Q4 : Les coéquipiers et le monstre voient-ils le choix ? → Proposition : les coéquipiers oui (dans le salon), le monstre non : « qui a pris la fumée ? » fait partie du jeu.
  - Précision T-352 (20/11/2026) : en ligne, les rôles sont tirés au lancement (T-110), donc personne ne sait dans le salon qui sera le monstre. Montrer les choix au salon les montrerait aussi au futur monstre : seule la salle les garde, aucun client ne les reçoit. Les coéquipiers voient en jeu ce que fait chacun.
- Q5 : Quels paliers pour le monstre ? → Proposition, un par objectif réussi :
  1. jauge de scan rechargée en **35 s** au lieu de 45 ;
  2. course de **6,5 s** au lieu de 5 avant l'essoufflement ;
  3. (sirène) le scan entend **tous les niveaux** du bâtiment visé (S-014, Q4, ne vaut plus qu'avant la sirène).
  Chaque palier est une liste de réglages remplacés, rangée dans `game/data/escalation/*.tres` : on ajoute ou retire un palier sans code.
- Q6 : Comment le chassé l'apprend-il ? → Proposition : un grondement sourd, entendu partout (ce n'est pas un bruit de jeu, le monstre n'en voit pas d'orange), et une ligne « Le monstre s'énerve » pendant 3 s. Le guide du jeu le dit.
- Q7 : Les paliers valent-ils en solo ? → Proposition : oui, pour le monstre IA comme pour le monstre joué contre des proies IA ; les IA lisent les mêmes réglages.
- Q8 : Que contient la salle d'essai ? → Proposition : une greybox à part (`game/maps/test_room/`), hors ligne, sans fin de partie. Des **postes** : gadgets à volonté (charges qui reviennent), bouteilles qui réapparaissent, réveil, cachette, porte, muret, terminal et caméra, un brancard. Un **mannequin de monstre** sur un rail qui réagit aux pétards, fils, fumées et leurres comme le vrai (même code, déplacement scripté). Une touche (**F6**) passe en monstre : un **mannequin de chassé** marche, court et se cache dans un petit bâtiment pour tester le scan, la jauge et l'affichage des leurres. Cercles de bruit (F4) affichés au départ.
- Q9 : Comment rester modulaire ? → Proposition : chaque poste est une scène avec une pancarte, listée dans `game/maps/test_room/stations.tres`. Ajouter un poste = une scène + une ligne. Les gadgets suivent le même modèle (`GadgetDef` : nom, scène, charges, réglages), lus par le joueur, le réseau, les IA, le HUD et la salle d'essai. Un test GUT vérifie que chaque gadget de la liste se pose, se synchronise et apparaît dans la salle d'essai.

## Hors périmètre
- Les autres constats de l'audit (scan qui distingue vivant et objet, immunité après un arrêt, sorties, etc.) : chacun sa décision.
- De nouveaux gadgets : la spec change la façon de les porter, pas leur liste.
- La salle d'essai en ligne ou à plusieurs.
- Les bouteilles, les réveils trouvés dans la cité, le souffle retenu, l'élan et les marques, qui gardent leurs touches.

## Critères d'acceptation
- [x] Avant la partie, en solo et en ligne, le chassé choisit 2 gadgets ; en jeu, il les utilise avec les touches de Q1, 2 charges chacun ; F, T, V et B ne servent plus aux gadgets.
- [x] Le choix est gardé d'une partie à l'autre ; le monstre ne le connaît jamais (Q4 précisée : personne ne le voit au salon, les rôles y sont encore inconnus).
- [x] Chaque objectif réussi applique le palier suivant au monstre (joué ou IA, solo et en ligne) ; les chassés entendent le grondement et voient la ligne.
- [ ] La salle d'essai s'ouvre depuis « Jouer seul », a tous les postes de Q8, les mannequins, et F6 change de rôle. *Fait sauf le terminal et la caméra, qui demandent un réseau de la cité dans la salle : à ajouter comme poste.*
- [x] Ajouter un gadget, un palier ou un poste se fait par un fichier de données et une scène ; `docs/MODULES.md` le décrit, et un test le vérifie pour les gadgets existants.
- [x] Tests GUT ; `net_walk`, `net_match`, `net_spectate` verts ; 20 parties simulées sans blocage ; budget tenu (60 Mo, 300 appels de dessin dans la cité). *1 partie sur 20 bloquée avant tout objectif (donc sans palier), cas déjà vu sur main avant S-023.*
- [x] Le guide du jeu est mis à jour (gadgets au choix, paliers du monstre, salle d'essai).

## Notes de playtest
