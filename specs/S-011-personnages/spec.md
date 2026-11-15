# S-011 — Personnages et animations

**Statut** : en cours (14/11/2026). Q1 et Q2 validées par Maxime ; Q3 à Q6 proposées par Claude
**Piliers servis** : P3 (asymétrie) — deux rôles qui se lisent d'un coup d'œil ; P2 (le dilemme) — on reconnaît le coéquipier à sauver
**Phase** : 11 — Personnages et animations (voir `specs/BACKLOG.md`)

## Pourquoi
Depuis S-001, chassés et monstre sont des capsules grises. En multijoueur (S-010), on ne sait pas qui est qui, et un chassé capturé n'est qu'une capsule écrasée. Cette spec remplace les capsules par de vrais personnages animés, dans le ton choisi (Half-Life, Metal Gear : sale, adulte, sans armes), sous le budget PS1 de la constitution (800 à 2 500 triangles, textures en pixels nets).

## Ce que vit le joueur
Léa joue la jeune femme à la parka. Au coin du bâtiment C, elle voit une silhouette accroupie qui longe le mur : un brassard bleu et une petite lumière bleue sur la poitrine, c'est l'ancien ambulancier, donc Tom. Il se relève et court vers le centre social. Plus loin, sous un lampadaire, le monteur de lignes est à genoux, les mains au sol : il est capturé. Léa s'approche, maintient E, il se relève.

## Récits utilisateur
- En tant que chassé, je veux reconnaître mes coéquipiers à leur allure et à leur couleur, afin de savoir qui aider.
- En tant que monstre, je veux voir des proies qui marchent, courent, s'accroupissent, afin de lire leur allure de loin.
- En tant que chassé capturé, je veux être à genoux de façon visible, afin que mes amis me trouvent.

## Clarifications
- Q1 (Q-002) : Combien de chassés, et quelle allure ? → Proposition : trois chassés de la piste « Le Réseau », sans noms, désignés par leur rôle : l'ancien ambulancier (bleu), la jeune femme à la parka (vert), le vieux monteur de lignes masqué (blanc). Brassard et petite lumière de la couleur du joueur ; jamais d'orange (bruit) ni de rouge (monstre) sur un chassé. Corps sculpté libre de droits (Quaternius, CC0), habillé par script. → R : **validé** (Maxime, 14/11/2026, quatrième tour de planches).
- Q2 : Quel monstre ? → Proposition en cours : un nouveau chasseur plus sombre et effrayant, créature originale (inspiration libre d'un androïde à l'esprit psychique, sans reprendre aucun élément d'une œuvre existante, règle 2.7), présenté sur planches comme les chassés. → R : **piste B, le masque blanc**, « plus Jinzo avec les yeux rouges » : 2,30 m, maigre, voûté, bras étirés et griffus, masque blanc fêlé à deux yeux rouges, paraboles d'écoute, câbles de nuque, torse recousu sous un manteau ouvert en lambeaux (Maxime, 14/11/2026).
- Q3 : Voit-on ses bras en vue subjective ? → Proposition : **non** pour cette spec. La vue reste sans corps, comme aujourd'hui ; les bras demandent un second modèle et des animations à part. → R : proposition de Claude.
- Q4 : D'où viennent les animations ? → Proposition : animations **faites par script Blender** sur le squelette de la base CC0 (marcher, courir, accroupi, repos, à genoux), courtes et en boucle, exportées dans le modèle. La bibliothèque d'animations Quaternius n'est pas joignable depuis l'environnement de travail ; on pourra la brancher plus tard, le squelette est le même. → R : proposition de Claude.
- Q5 : Qui joue quel chassé ? → Proposition : la **place** dans le salon décide : place 1 l'ambulancier (bleu), place 2 la parka (vert), place 3 le monteur de lignes (blanc). Une IA dans une place prend le personnage de cette place. En solo, la proie IA est l'ambulancier. → R : proposition de Claude.
- Q6 : Les animations sont-elles envoyées par le réseau ? → Proposition : **non**. Chaque client choisit l'animation à partir de ce qu'il reçoit déjà (allure, vitesse, à genoux) ; rien de nouveau n'est envoyé. → R : proposition de Claude. Revue le 15/11/2026 (T-125, T-127) : les gestes (lancer, ramasser, travailler, attraper, écraser) ne se devinent pas à la vitesse ; l'instantané envoie donc un entier de plus par joueur vu, le geste en cours.

## Hors périmètre
- Les bras en vue subjective (Q3).
- Les animations d'action (lancer, ramasser, réparer, cachette) : T-125 suite, après validation du monstre.

## Critères d'acceptation (vérifiables à la main)
- [ ] Les trois chassés sont en jeu, sous 2 500 triangles chacun, textures de 64 à 256 px en pixels nets.
- [ ] Un chassé IA ou distant marche, court, s'accroupit et se met à genoux selon son état.
- [ ] En ligne, chaque place a son personnage ; rien de nouveau n'est envoyé par le réseau.
- [ ] Le choix de l'animation est couvert par des tests GUT.
- [ ] La base CC0 est citée dans `CREDITS.md`.
- [ ] Le budget de performance tient avec 4 personnages animés.

## Notes de playtest
