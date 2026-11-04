# S-003 — Le monstre IA

**Statut** : validée (04/11/2026)
**Piliers servis** : P1 (le son trahit), P2 (le dilemme permanent), P3 (l'inquiétante familiarité)
**Phase** : 3 — Le monstre IA

## Pourquoi
C'est le premier vrai test de « fun » du jeu (point de décision n°1). Un monstre contrôlé par l'ordinateur doit chasser le joueur selon les règles D-008 et D-009 : il voit normalement, il entend les bruits avec leur distance, et il est discret. Si fuir et se cacher d'un monstre gris dans une boîte grise fait déjà peur, le concept tient. Sinon, on ajuste le game design avant d'aller plus loin.

## Ce que vit le joueur
Je suis dans la map de test. Une grande silhouette noire fait sa ronde, lentement, sans bruit. Je m'accroupis derrière un mur et je la regarde passer. Je cours pour rejoindre le petit bâtiment : elle a entendu, elle se retourne et vient voir là où j'ai couru. Je ne bouge plus. Elle fouille, puis repart. Plus tard, elle me voit au détour d'un couloir et me fonce dessus : je l'entends courir derrière moi. Je casse sa ligne de vue en passant une porte, je m'accroupis dans la pièce d'à côté. Elle arrive là où elle m'a vu pour la dernière fois, cherche, et finit par partir. Si elle me touche, l'écran affiche « Attrapé » et je reprends au départ.

## Récits utilisateur
- En tant que chassé, je veux qu'un monstre réagisse à mes bruits afin que chaque pas compte.
- En tant que chassé, je veux pouvoir casser la ligne de vue et me cacher afin d'avoir une chance de m'en sortir.
- En tant que chassé, je veux entendre le monstre seulement quand il se presse afin d'avoir peur sans être prévenu de loin.
- En tant que développeur, je veux voir l'état du monstre (ronde, enquête, poursuite) afin de régler son comportement.
- En tant que futur joueur monstre (S-004), je veux que les règles du monstre (vitesses, ouïe, vue) soient déjà dans des fichiers de réglage partagés.

## Critères d'acceptation (vérifiables à la main)
- [ ] Le monstre fait sa ronde sur un circuit dans la map de test, à vitesse lente, sans faire de bruit.
- [ ] Si je cours à moins de 14 m de lui (portée de la course), il se dirige vers l'endroit où j'ai couru, fouille quelques secondes, puis reprend sa ronde.
- [ ] Si je marche à 6 m de lui derrière un mur, il ne réagit pas (4 m de portée, divisée par deux par le mur).
- [ ] Accroupi et immobile dans son champ de vision mais à l'ombre d'un mur, il ne me trouve pas.
- [ ] S'il me voit, il ne me repère pas instantanément : il lui faut un court temps, plus long de loin et si je suis accroupi.
- [ ] Une fois repéré, il me poursuit en courant, un peu plus vite que ma course : je ne peux pas le semer en ligne droite, seulement en cassant sa ligne de vue.
- [ ] S'il me perd de vue plus de 3 s, il va au dernier endroit où il m'a vu, fouille, puis repart.
- [ ] Je l'entends courir de loin (environ 12 m), marcher de près (environ 3 m), et jamais quand il rôde. Son souffle s'entend à moins de 2 m.
- [ ] S'il me touche, « Attrapé » s'affiche, je reprends au point de départ et il retourne à sa ronde loin de moi.
- [ ] F3 affiche l'état du monstre (ronde, enquête, poursuite, recherche) et sa jauge de repérage.
- [ ] Il ne se coince pas dans les murs et trouve son chemin autour du petit bâtiment de la map de test.
- [ ] Toutes ses vitesses, portées et durées sont dans un fichier de réglage, pas dans le code.
- [ ] Les tests GUT de la logique du monstre passent, et la map tient 60 images/s dans Chrome.

## Hors périmètre
- Jouer le monstre soi-même, son affichage des bruits et le scan de bâtiment : S-004 (phase 4).
- L'IA qui utilise le scan : à décider après S-004.
- Le modèle 3D et les animations du monstre : phase 9. Ici, une silhouette provisoire.
- Les vrais bruitages : phase 10. Ici, des sons provisoires générés par le code.
- Les fusibles, la sortie et l'écran de fin : phase 7.
- Les portes qui s'ouvrent, les objets lancés et les cachettes interactives (placards, lits) : phase 8.

## Clarifications
Le 04/11/2026, Maxime a retenu les propositions Q1 à Q6 pour tester, quitte à y revenir après le playtest.

- Q1 : Quelles vitesses ? → Proposition : rôder 1,5 m/s, marcher 3,5 m/s, courir 6 m/s. La course du chassé est à 5,5 m/s : le monstre gagne en ligne droite, le chassé doit casser la ligne de vue. → R : retenu (04/11/2026).
- Q2 : Comment voit-il ? → Proposition : un champ de vision de 100° sur 25 m, bloqué par les murs. Une jauge de repérage se remplit quand il voit le joueur : en 0,4 s tout près, en 1,5 s à 25 m, deux fois plus lentement si le joueur est accroupi. Pleine, il poursuit. → R : retenu (04/11/2026).
- Q3 : Que fait-il quand il entend un bruit ? → Proposition : il marche (et fait donc un peu de bruit) vers l'endroit du bruit, fouille 6 s en regardant autour de lui, puis reprend sa ronde. Un bruit plus récent et entendu pendant l'enquête la remplace. → R : retenu (04/11/2026).
- Q4 : Que se passe-t-il quand il attrape le joueur ? → Proposition : « Attrapé » s'affiche 2 s, le joueur reprend au départ et le monstre repart dans sa ronde, au point le plus éloigné du joueur. Un compteur de captures s'affiche avec F3. La vraie fin de partie viendra en phase 7. → R : retenu (04/11/2026).
- Q5 : Faut-il déjà des sons ? → Proposition : oui, des sons provisoires générés par le code (un pas sourd, un souffle), sans fichier audio. Sans eux, on ne peut pas tester la discrétion du monstre (D-009), qui est au cœur de la peur. → R : retenu (04/11/2026).
- Q6 : La map de test suffit-elle ? → Proposition : on ajoute un petit bâtiment de deux pièces avec deux portes ouvertes et une fenêtre, et un circuit de ronde de 4 points autour. C'est le minimum pour tester « casser la ligne de vue » et « se cacher dans la pièce d'à côté ». → R : retenu (04/11/2026).

## Notes de playtest
- (à remplir)
