# S-001 — Déplacement du joueur en vue subjective

**Statut** : en clarification
**Piliers servis** : P2 (le dilemme permanent), P3 (l'inquiétante familiarité)
**Phase** : 1 — Le joueur dans une boîte grise

## Pourquoi
Tout le jeu repose sur un choix : bouger vite et faire du bruit, ou bouger lentement et rester discret. Avant de mesurer le bruit (S-002), il faut que se déplacer soit agréable et que les trois allures (accroupi, marche, course) se sentent clairement différentes. Si le simple fait de marcher dans une boîte grise n'est pas confortable, rien de ce qui viendra après ne le sera.

## Ce que vit le joueur
J'ouvre le jeu dans mon navigateur. Je clique dans la fenêtre : la souris disparaît et je regarde autour de moi en la bougeant, à hauteur d'yeux d'une personne de 1,75 m. Je me déplace avec les touches de direction habituelles de mon clavier, que je sois en AZERTY ou en QWERTY. En maintenant une touche, je cours : le monde défile plus vite. En m'accroupissant, la caméra descend, j'avance lentement et je peux passer sous un obstacle bas. Si je me relève sous ce plafond bas, je reste accroupi au lieu de traverser le décor. Je ne traverse jamais les murs, je monte les petites marches sans sauter, et je glisse le long des murs au lieu de m'y coller. Échap me rend la souris.

## Récits utilisateur
- En tant que chassé, je veux marcher et regarder autour de moi à la souris afin d'explorer la map.
- En tant que chassé, je veux courir afin de fuir quand je suis repéré, en sachant que ce sera bruyant (S-002).
- En tant que chassé, je veux m'accroupir afin d'avancer discrètement et de passer sous les obstacles bas.
- En tant que joueur sur navigateur, je veux pouvoir libérer la souris à tout moment afin de reprendre la main sur mon onglet.

## Critères d'acceptation (vérifiables à la main)
- [ ] Un clic dans le jeu capture la souris, Échap la libère, un nouveau clic la recapture.
- [ ] Le regard souris est fluide, sans à-coups, et la vue ne peut pas basculer au-delà de la verticale (haut ou bas).
- [ ] Les touches de déplacement sont ZQSD sur un clavier AZERTY et WASD sur un clavier QWERTY, sans réglage. Les flèches fonctionnent aussi.
- [ ] La course est nettement plus rapide que la marche, et l'accroupi nettement plus lent.
- [ ] Accroupi, la caméra descend en douceur (pas de saut d'image) et je passe sous un obstacle de 1,2 m de haut.
- [ ] Sous un obstacle bas, relâcher l'accroupi ne me fait pas me relever tant que je suis dessous.
- [ ] Aller en diagonale n'est pas plus rapide qu'aller tout droit.
- [ ] Je monte une marche de 25 cm en marchant, je ne peux pas escalader un muret de 60 cm.
- [ ] Je ne traverse aucun mur de la map de test, même en courant contre un angle.
- [ ] Toutes les vitesses et la sensibilité de la souris se règlent dans un fichier de réglage, sans toucher au code.
- [ ] Dans Chrome, sur la machine de référence, la map de test tourne à 60 images/s (compteur affiché en debug).

## Hors périmètre
- Le bruit des pas et la jauge de bruit (S-002).
- L'endurance ou la fatigue en course.
- Le saut.
- La lampe torche, les interactions (portes, objets).
- Le menu des options (sensibilité réglable en jeu) : phase 11.
- La manette.
- Les sons de pas et le modèle 3D du joueur.
- Le style visuel PS1 (S-005), sauf la résolution interne de 640 × 360 si la question 6 est validée.

## Clarifications
Chaque question a une proposition. Il suffit de répondre « ok » ou de corriger.

- Q1 : Vitesses de départ ? → Proposition : marche 3,0 m/s, course 5,5 m/s, accroupi 1,5 m/s. Ajustées en playtest.
- Q2 : Course en maintenant Maj, ou en bascule ? → Proposition : maintenir Maj.
- Q3 : Touche d'accroupi ? → Proposition : C en bascule (un appui pour s'accroupir, un pour se relever). On évite Ctrl, car dans un navigateur Ctrl + W ferme l'onglet.
- Q4 : Pas de saut du tout ? → Proposition : pas de saut, le jeu est une traque, pas un jeu de plateforme. Les marches basses se montent seules.
- Q5 : Balancement de la caméra en marchant (« head bob ») ? → Proposition : léger, plus marqué en course, et désactivable dans le fichier de réglage (certaines personnes en ont la nausée).
- Q6 : Appliquer dès maintenant la résolution interne de 640 × 360 de la constitution (2.2) ? → Proposition : oui, c'est un simple réglage du projet, ça aide les performances et ça évite de régler les vitesses de souris sur une image qui changera en phase 5.

## Notes de playtest
- (à remplir)
