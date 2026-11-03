# S-002 — Le système de bruit

**Statut** : validée (03/11/2026)
**Piliers servis** : P1 (le son est la vision), P2 (le dilemme permanent)
**Phase** : 2 — Le système de bruit

## Pourquoi
Le monstre repère le chassé par le bruit qu'il fait (D-008). Avant de construire le monstre (S-003), il faut que chaque pas du joueur produise un bruit mesurable, que ce bruit porte plus ou moins loin selon l'allure, et que les murs l'étouffent. Le joueur doit aussi sentir ce bruit, pour faire le choix permanent entre aller vite et rester discret.

## Ce que vit le joueur
Je marche dans la map de test. En bas de l'écran, une jauge orange monte un peu à chaque pas. Accroupi, elle bouge à peine. En courant, elle grimpe presque au maximum. Quand je m'arrête, elle redescend doucement jusqu'à zéro.

En appuyant sur F4, je vois les bruits : chaque pas dessine au sol un cercle orange qui montre jusqu'où il porte, puis s'efface. Des micros de test sont posés dans la map. Quand un de mes pas les atteint, ils s'allument en orange. Si je cours derrière un mur, le micro de l'autre côté m'entend de moins loin qu'en terrain dégagé.

## Récits utilisateur
- En tant que chassé, je veux que mes pas fassent du bruit selon mon allure afin de devoir choisir entre vitesse et discrétion.
- En tant que chassé, je veux voir une jauge de bruit afin de savoir à quel point je me trahis.
- En tant que développeur, je veux voir les cercles de bruit et des micros de test afin de vérifier la propagation sans monstre.
- En tant que futur monstre (S-003), je veux recevoir chaque bruit avec sa position et sa portée afin de réagir à ce que j'entends.

## Critères d'acceptation (vérifiables à la main)
- [ ] Immobile, je ne fais aucun bruit : la jauge reste à zéro.
- [ ] À chaque pas, un bruit part de mes pieds. Sa portée est de 1 m accroupi, 4 m en marchant et 14 m en courant (valeurs de la section 6.2, réglables).
- [ ] En courant, la jauge monte à 9 sur 10 ; en marchant à environ 3 ; accroupi à 1 au plus.
- [ ] La jauge redescend à zéro en 2 s environ après mon dernier pas.
- [ ] F4 affiche et cache les cercles de bruit. Chaque cercle a le rayon de la portée du bruit et s'efface en 3 s.
- [ ] Un micro de test à 10 m en terrain dégagé s'allume quand je cours, pas quand je marche.
- [ ] Un micro de test à 6 m derrière un mur s'allume quand je cours tout près du mur, pas quand je marche.
- [ ] Toutes les portées, la règle des murs et les réglages de la jauge sont dans des fichiers de réglage, pas dans le code.
- [ ] Les tests GUT du calcul de bruit passent.
- [ ] La map de test tient toujours 60 images/s dans Chrome, cercles affichés.

## Hors périmètre
- Le monstre et sa réaction au bruit (S-003).
- Les bruits d'objets : portes, objets lancés, alarmes de voiture (ils utiliseront le même `NoiseBus` quand ces objets existeront).
- L'eau, la pluie, le vent et l'écho des tunnels (section 6.2) : ils viendront avec les maps qui en ont besoin.
- Les sons audibles (bruitages de pas) : phase 10. Ici le bruit est une information de jeu, pas encore un son.
- Le bruit d'atterrissage après une chute.

## Clarifications
Le 03/11/2026, Maxime a validé la gestion des bruits proposée : les propositions Q1 à Q5 sont retenues.

- Q1 : Que fait un mur exactement ? La section 6.2 dit « un mur divise l'intensité par deux ». → Proposition : chaque mur entre le bruit et l'auditeur **divise la portée par deux**. Une course (14 m) derrière un mur s'entend à 7 m, derrière deux murs à 3,5 m. Simple à comprendre et à régler. Note : l'exemple du modèle de spec (« à 10 m derrière un mur, il m'entend courir ») ne marcherait pas avec cette règle ; il faudrait alors un facteur de 0,75 au lieu de 0,5. → R : retenu (03/11/2026).
- Q2 : Un bruit par pas, ou un bruit continu ? → Proposition : **un bruit par pas**, calculé sur la distance parcourue (environ un pas tous les 0,7 m en marchant, 0,9 m en courant, 0,5 m accroupi). Ça colle à la future idée « le monstre voit des taches orange qui s'effacent » (section 6.3). → R : retenu (03/11/2026).
- Q3 : Comment lire la jauge ? → Proposition : de 0 à 10, où 10 correspond à un bruit de 15 m. La course (14 m) donne donc 9, la marche 3, l'accroupi 1. Barre orange en bas à gauche, toujours visible pour le chassé. → R : retenu (03/11/2026).
- Q4 : Les cercles de debug ? → Proposition : cachés par défaut, F4 pour les afficher, y compris dans le build Web (pour tester). → R : retenu (03/11/2026).
- Q5 : Les micros de test ? → Proposition : 3 micros dans la map de test (un en terrain dégagé à 10 m du départ, un derrière un mur, un dans le couloir), visibles seulement avec F4. Ils serviront de « faux monstre » jusqu'à S-003. → R : retenu (03/11/2026).

- Q6 (ajout du 03/11/2026) : chaque bruit porte un **type** (pas, porte, objet…) pour que le monstre puisse plus tard réagir selon ce qu'il entend. En S-002, seul le type « pas » existe. → R : retenu, sans objection de Maxime à la proposition.

## Notes de playtest
- (à remplir)
