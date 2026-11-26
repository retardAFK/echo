# S-025 — Versus arcade : refonte fun, façon Fortnite

**Statut** : décidée par Claude le 26/11/2026 à la demande de Maxime (« tu es le boss », décision D-024). Elle remplace, dans le Versus, ce que S-024 disait des armes, de la vue, de l'ambiance et de la fin ; le reste de S-024 tient (arène et toits, coffres, à terre et relevé, phases et attaques du boss, jeu en ligne, IA).
**Phase** : hors feuille de route, suite de S-024.
**Exigence transverse** : modulaire (D-022). Tout reste dans `game/modes/versus/` ; une arme, une rareté ou une étape de zone s'ajoute par un fichier de données. Chaque étape visible est vérifiée **en images** (captures du jeu regardées par Claude, et montrées à Maxime pour le style), pas seulement par les tests.

## Pourquoi
Maxime a joué le Versus de S-024 le 26/11/2026 : « absolument pas fun ». Les fusées partent en cloche « en mode catapulte », l'ambiance reste celle de l'horreur. Ce qu'il voulait : un mode **qui défoule**, « en mode mitraillette », « en mode Fortnite », **fun et pas horreur** ; toutes les portes traversables, **aucun blocage**, tout accessible ; et des « fusées de précision ».

## Ce que vit le joueur
Je lance un Versus. Il fait **jour**, couleurs vives, néons sur les façades, musique qui pousse. Je vois mon personnage **de dos, à la 3e personne**, un réticule au centre. J'ouvre mon coffre : une **mitraillette à lumière** grise (commune). Je maintiens le clic : une rafale de traits lumineux part **tout droit** et touche **tout de suite**. Sur le boss, des **chiffres de dégâts** sautent, en jaune quand je vise la tête. Un coffre plus loin brille en violet : un **fusil à fusées de précision** épique ; clic droit pour viser (zoom), un tir sec, gros chiffre.

Toutes les portes de la cité sont **ouvertes**, je passe partout, je monte sur les toits par les escaliers. Une **zone** se resserre sur le centre de l'arène en trois temps : dehors, on perd de la vie ; elle nous pousse tous vers la bagarre. Le boss, plus gros, **lumineux** (fissures orange qui brillent), sa barre de vie en haut de l'écran, charge et bondit comme avant. Quand il tombe, ralenti, confettis de lumière, écran de victoire.

## Récits utilisateur
- En tant que chassé, je veux tirer en rafale et toucher tout de suite, afin de me défouler.
- En tant que chassé, je veux trouver de meilleures armes dans les coffres, reconnaissables à leur couleur, afin d'avoir envie d'aller les chercher.
- En tant que joueur, je veux passer partout, afin de ne jamais rester bloqué.
- En tant que joueur, je veux une ambiance colorée et une partie qui se resserre, afin que ça reste nerveux du début à la fin.

## Clarifications (décidées le 26/11/2026)
- Q1 : La vue ? → **3e personne**, caméra par-dessus l'épaule, pour les chassés et le boss. Le tir part du **centre de l'écran** (rayon de la caméra), corrigé depuis l'arme pour ne pas tirer à travers un mur proche. Touche V : repasser à la 1re personne (réglage gardé).
- Q2 : Les armes ? → **à impact immédiat** (pas d'arc). Chaque arme est un fichier de données (cadence, dégâts, dispersion, chargeur, recharge, portée, automatique ou non, zoom) :
  - **Mitraillette à lumière** : automatique, 10 tirs/s, petits dégâts, chargeur de 30. Arme de départ (premier coffre).
  - **Fusil à fusées de précision** (idée de Maxime) : coup par coup, une fusée **droite et rapide** avec sa traînée, gros dégâts, tête x2, zoom au clic droit.
  - **Fusil à pompe sonique** : 8 plombs en cône, très fort de près, repousse le boss.
  - **Lance-laser UV** : gardé (rayon continu, brûle et ralentit).
  - **Grenades flash** (outil) : étourdissent le boss 1,5 s dans 6 m. La trousse, le pétard et le fumigène restent.
- Q3 : La rareté ? → 4 niveaux, couleur sur l'arme, le coffre ouvert et un rayon de lumière au-dessus : **commune** (gris), **rare** (bleu), **épique** (violet), **légendaire** (doré) ; dégâts x1 ; x1,1 ; x1,2 ; x1,35. Les coffres de phase donnent plus souvent du rare et au-dessus.
- Q4 : Les retours de tir ? → chiffres de dégâts flottants (jaunes à la tête), croix de touche, son de touche, petite secousse de caméra au tir. Bandeau des événements (« Maxime a relevé Ana », « Le boss passe en phase 2 »).
- Q5 : Les portes ? → en Versus, **toutes les portes de la map sont ouvertes et traversables** (ni planches, ni portes verrouillées) ; les seules limites sont les barrières de l'arène. Un test parcourt l'arène : chaque coffre, chaque toit et chaque départ est atteignable, et un robot y marche sans rester coincé.
- Q6 : La fin ? → la nuit et l'aube disparaissent. Partie de **8 min** ; une **zone** ronde se resserre en 3 étapes vers le centre de l'arène (à 2, 4 et 6 min) ; dehors, un chassé perd 1 point toutes les 4 s, le boss 2 % de sa vie par seconde. Le boss gagne si le temps s'écoule (« le temps est écoulé, la créature survit »).
- Q7 : L'ambiance ? → en Versus, **jour** (ciel clair, soleil), façades avec néons de couleur, brouillard léger ; la phase 2 n'éteint plus les lumières, elle fait **briller** le boss (rage visible). Musique entraînante (S-025, sons).
- Q8 : Le boss ? → le **même monstre**, 1,3 fois plus grand, fissures lumineuses orange (plus fortes à chaque phase), barre de vie en haut de l'écran avec son nom. Ses attaques ne changent pas.
- Q9 : Construire des murs ? → **non** pour cette version (gros chantier). Peut-être plus tard.

## Hors périmètre
- Construction façon Fortnite, cosmétiques, danses, boutique.
- Le mode Traque : il ne change pas (il reste un jeu d'horreur).

## Critères d'acceptation
- [ ] En Versus, aucune porte fermée ni planche ; un robot atteint chaque coffre, chaque toit et chaque départ.
- [ ] Vue à la 3e personne pour chassés et boss, réticule, tir depuis le centre de l'écran.
- [ ] Mitraillette, fusil à fusées de précision, fusil à pompe sonique, laser UV et grenades flash marchent, en solo et en ligne.
- [ ] Rareté visible (couleur de l'arme, du coffre et du rayon) et appliquée aux dégâts.
- [ ] Chiffres de dégâts, croix de touche, bandeau des événements.
- [ ] Zone qui se resserre en 3 étapes, dégâts dehors, fin à 8 min.
- [ ] Ambiance de jour colorée ; boss plus grand et lumineux ; captures montrées à Maxime.
- [ ] Simulation : le boss IA gagne 40 à 60 % des parties à 2, 3 et 4 chassés, 5 à 8 min, aucune partie bloquée.
- [ ] Robots `net_versus` verts en CI ; 60 images/s visées, budget de 300 appels de dessin tenu.
