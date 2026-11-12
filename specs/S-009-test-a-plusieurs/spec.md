# S-009 — Préparer le test à plusieurs

**Statut** : en clarification (12/11/2026)
**Piliers servis** : P1 (le son trahit), P2 (le dilemme permanent)
**Phase** : 9 — Préparer le test à plusieurs (voir `specs/BACKLOG.md`)

## Pourquoi
Les phases 1 à 8 ont donné une partie complète dans la cité des Tilleuls, avec ses ruses, jouable dans les deux rôles. Avant le multijoueur (D-013), il faut savoir si le jeu amuse d'autres que nous : c'est le **point de décision n°2**. Pour cela, 3 à 5 personnes de confiance doivent pouvoir ouvrir le jeu d'un simple lien, le comprendre sans qu'on leur explique, y jouer les deux rôles et nous rendre leurs impressions. Il reste aussi trois dettes des phases précédentes : les 60 images/s n'ont jamais été mesurées sur la machine de référence, la proie IA se fait prendre trop souvent à deux endroits, et le monstre IA ne scanne jamais, si bien que le chassé ne voit jamais les lumières vaciller.

## Ce que vit le joueur
**Le testeur** reçoit un lien et un court questionnaire. Il ouvre le lien dans Chrome : le jeu se charge en quelques secondes, sans rien installer. Le menu lui demande de choisir un rôle. Il choisit « Chassé » : un écran lui montre les commandes du chassé (ZQSD, Maj pour courir, Ctrl pour s'accroupir, E pour interagir, clic gauche pour lancer, clic droit pour poser un réveil) et le but (trois fusibles, le transformateur, la sortie). Il clique sur « Jouer ». Au milieu de la partie, il appuie sur Échap : le jeu se fige, un petit menu propose de reprendre ou de revenir au menu. Il reprend. Dans la tour, les lumières se mettent à vaciller : le monstre IA scanne le bâtiment. Il se fige, puis se faufile dehors. À la fin, l'écran de fin résume sa partie ; il clique sur « Copier le résumé » et colle le texte dans le questionnaire, avec ses impressions. Il refait une partie en monstre.

**Maxime** n'a rien à jouer. Claude lance lui-même un banc d'essai sur son PC, dans le navigateur de l'app Claude, et lui donne les images/s mesurées. Quand tout est prêt, Maxime reçoit le lien et le questionnaire à envoyer aux testeurs.

## Récits utilisateur
- En tant que testeur, je veux ouvrir le jeu d'un lien, sans installation, afin d'essayer tout de suite.
- En tant que testeur, je veux voir les commandes et le but avant de jouer, afin de comprendre sans aide.
- En tant que testeur, je veux mettre en pause, afin de répondre à un message ou de relire les commandes.
- En tant que chassé, je veux que le monstre IA scanne les bâtiments, afin de vivre l'alerte des lumières et le dilemme de se figer (P2).
- En tant que Maxime, je veux des chiffres fiables (images/s sur ma machine, durée et issue des parties simulées), afin de savoir si le jeu est prêt à être montré.
- En tant que Maxime, je veux recevoir des retours comparables d'un testeur à l'autre, afin de trancher le point de décision n°2.

## Clarifications
- Q1 : Où héberger le build de test (Q-012) ? → Proposition : une **page itch.io en accès restreint** (protégée par un mot de passe que Maxime donne aux testeurs). C'est gratuit, ça marche avec un dépôt privé, et c'est là que le jeu sortira (S-015). La CI y publie le build de `main` à chaque fusion. Il faut que Maxime crée un compte itch.io et une page de jeu, et ajoute une clé d'accès dans les secrets du dépôt (une seule fois, environ 5 minutes, étapes données par Claude). Autre option : GitHub Pages, qui ne marche avec un dépôt privé qu'avec l'abonnement GitHub Pro (4 $ par mois) et rend le lien public. → R : à trancher par Maxime.
- Q2 : Que fait le banc d'essai ? → Proposition : l'adresse du jeu suivie de **`?bench`** lance directement la cité des Tilleuls, sans menu. Une caméra suit un parcours fixe de **60 s** (la cour, la tour, le parking souterrain, la galerie), pendant que le monstre IA et la proie IA jouent une vraie partie. À la fin, un écran affiche et la console écrit : images/s moyennes, minimum, moyenne des 1 % les plus lentes, appels de dessin au pire, triangles au pire, et temps de chargement de la map. Le même parcours sert à chaque mesure, pour comparer les versions. → R : proposition de Claude.
- Q3 : Quand le monstre IA scanne-t-il ? → Proposition : quand il **perd la trace** de la proie près d'un bâtiment visitable (fin de poursuite ou d'enquête à moins de 15 m d'un bâtiment), ou quand il **entend un bruit qui vient d'un bâtiment visitable** sans savoir d'où exactement. Il s'arrête, scanne au plus 4 s, en respectant la jauge (D-009 : 8 s au total, recharge en 45 s, pas de scan sous 25 %). S'il entend quelque chose pendant le scan, il y va ; sinon il reprend sa patrouille. Les lumières vacillent comme quand un joueur monstre scanne. Il ne scanne pas deux fois de suite le même bâtiment en moins de 30 s. → R : proposition de Claude.
- Q4 : Quel équilibre vise-t-on ? → Proposition (reprise du backlog) : sur 3 séries de 20 parties simulées, la proie IA sort **40 à 60 %** du temps, et une partie dure **8 à 12 minutes** en moyenne, sans partie bloquée. Les deux endroits de capture répétée (emplacement de fusible du parking, couloir en cul-de-sac du centre social) sont corrigés, par la map ou par l'IA. → R : proposition de Claude.
- Q5 : Comment montre-t-on les commandes ? → Proposition : après le choix du rôle, un écran simple affiche les commandes et le but de ce rôle, avec un bouton « Jouer ». Les mêmes commandes sont rappelées dans le menu de pause. Pas de tutoriel guidé dans cette spec. → R : proposition de Claude.
- Q6 : Que fait la pause ? → Proposition : **Échap** fige la partie (le monstre, la proie, les minuteries et les sons), libère la souris et affiche « Reprendre », « Commandes » et « Revenir au menu ». Dans le navigateur, Échap libère toujours la souris : perdre la souris met donc aussi le jeu en pause, et un clic sur « Reprendre » la recapture. → R : proposition de Claude.
- Q7 : Comment recueille-t-on les retours ? → Proposition : l'écran de fin gagne un bouton **« Copier le résumé »** qui copie un court texte (rôle, issue, durée, fusibles posés, bruits faits ou entendus, scans, ruses utilisées, images/s moyennes, version du jeu). Un **questionnaire** de 8 à 10 questions, court, à envoyer avec le lien (fichier `questionnaire.md`), que Maxime peut copier dans un formulaire ou un message. Aucune donnée n'est envoyée automatiquement à un serveur. → R : proposition de Claude.
- Q8 : Comment mesure-t-on les 60 images/s sans faire jouer Maxime ? → Proposition : Claude ouvre le lien `?bench` dans le navigateur intégré de l'app Claude, sur le PC de Maxime (la machine de référence), et lit le résultat. Il suffit que l'app Claude soit ouverte sur ce PC à ce moment-là. Si le navigateur intégré n'est pas représentatif de Chrome (par exemple sans accélération graphique), Claude le signale. → R : proposition de Claude.

## Hors périmètre
- Le multijoueur, le salon et les autres chassés : S-010.
- Les options (volume, sensibilité, touches), le vrai menu principal : S-013. La pause de cette spec est minimale.
- Un tutoriel guidé ou des bulles d'aide en jeu.
- L'envoi automatique de statistiques à un serveur.
- Les nouvelles ruses, les portes mobiles, une nouvelle map.

## Critères d'acceptation (vérifiables à la main)
- [ ] Le lien de test s'ouvre dans Chrome sans installation et affiche le menu ; il montre toujours le dernier `main`.
- [ ] `?bench` joue le parcours de 60 s et affiche images/s moyennes, minimum, 1 % les plus lentes, appels de dessin, triangles et temps de chargement.
- [ ] Les 60 images/s sont mesurées sur la machine de référence et notées dans S-006, S-007, S-008 et S-009 ; s'il en manque, des tâches d'optimisation sont ajoutées.
- [ ] Le monstre IA scanne un bâtiment visitable quand il y perd la trace, en respectant la jauge ; les lumières du bâtiment vacillent ; la simulation compte les scans.
- [ ] Sur 3 séries de 20 parties simulées, la proie IA sort 40 à 60 % du temps et une partie dure 8 à 12 min en moyenne, sans blocage.
- [ ] Après le choix du rôle, les commandes et le but de ce rôle sont affichés ; Échap met en pause et propose reprendre, commandes, revenir au menu.
- [ ] L'écran de fin copie un résumé de la partie ; le questionnaire est prêt.
- [ ] Le budget de performance de la section 2.2 tient toujours (taille du build, appels de dessin, chargement).

## Notes de playtest
- (à venir, T-083) retours des testeurs.
