# Plan — S-024

**Statut** : proposé par Claude (26/11/2026), avec la spec. Le prototype (T-371 à T-374) suit ce plan dans la salle d'essai ; le reste attend la validation de la spec.

## Approche technique

### Un mode de jeu, un module
Le jeu n'a aujourd'hui qu'une façon de jouer (la Traque). S-024 ajoute la notion de **mode** :
- `GameSession.mode` (`&"hunt"` par défaut, `&"versus"`) dit quel mode est en cours, en solo comme en ligne.
- Tout le Versus vit dans **`game/modes/versus/`** : règles pures, entités (armes, projectiles, bras), HUD, données (`data/*.tres`). Le reste du jeu ne le connaît pas : c'est la map qui, au démarrage, ajoute le nœud **`VersusMode`** si `GameSession.mode == &"versus"` (une ligne dans `game_map.gd`, la seule à retirer avec le dossier).
- `VersusMode` s'accroche aux nœuds existants **par groupes et signaux** : il donne une `Weapon` à chaque chassé (`Player` et `Prey`), un `BossKit` à chaque monstre (`MonsterAvatar` et `Monster`), et remplace la règle « toucher = attraper » par des dégâts (il met `catch_distance` à 0 dans la copie des réglages de chaque monstre, comme la salle d'essai).

### Les règles pures (testées seules, GUT)
| Classe | Rôle |
|---|---|
| `BossHealth` | vie, phases (seuils lus dans les `VersusPhase`), multiplicateur de dégâts de la phase, invulnérabilité de changement de phase, posture (remplissage, genoux, immunité de 15 s), rage (remplissage, vidage, Fureur) |
| `HuntedVitals` | points de vie, à terre, chrono de 30 s, relevés restants, hors combat |
| `VersusRules` | chrono, « l'aube approche », boss traqué (45 s sans attaquer), qui gagne (Q1 à Q6) |
| `Stamina` | endurance (course et roulade) |
| `BossBrain` | choix d'attaque du boss IA |
| `ShotMath` | trajectoire en arc de la fusée, test de touche (corps ou visage), cône de la lampe |

### Les armes et les attaques
- `VersusWeaponDef` et `BossAttackDef` (`Resource`) : nom, scène, munitions, dégâts, posture, bruit, recharge. Listes dans `game/modes/versus/data/weapons.tres` et `boss_attacks.tres`. Une arme = un fichier `.tres` + une scène ; les outils au choix réutilisent `Loadout` (S-023) avec leur propre liste.
- **Fusée** (`Flare`) : `Node3D` qui avance par calcul (`ShotMath.step`), pas un corps physique ; touche par un `intersect_ray` par image entre l'ancienne et la nouvelle position, sur les couches du boss et des murs. Le boss a deux zones : corps (capsule) et **visage** (sphère sur la tête). Au sol, elle reste 8 s avec un matériau émissif ; seules les **2 fusées les plus récentes** ont une vraie lumière (budget de 4 lumières dynamiques).
- **Lampe UV** : test de cône (`ShotMath.in_cone`) plus un rayon pour la vue, à chaque image de la salle.
- Les coups du boss : la griffe est un test d'arc devant lui (distance, angle, hauteur) ; la charge, un déplacement forcé avec un test de contact ; le bond, un saut en arc vers un point puis un test de rayon.

### La vue à la première personne
- `ViewModel` (`game/modes/versus/view_model.gd`) : enfant de la caméra du joueur, ajouté par `VersusMode`. Il porte le modèle des bras (un `MeshInstance3D`, 1 appel de dessin) et l'anime par code : balancement lié à la vitesse, recul (ressort amorti), rechargement, roulade, à terre.
- Matériau `viewmodel.gdshader` : `unshaded` non, ombré simple ; dans `vertex()`, la profondeur du sommet est ramenée près du plan proche (`POSITION.z` mélangé vers `-POSITION.w`) pour que les bras soient toujours dessinés devant le décor, sans seconde caméra ni `SubViewport`.
- Prototype : les bras et les armes sont faits de formes simples (boîtes, cylindres) assemblées par code en un seul maillage (`SurfaceTool`). Les vrais modèles viennent ensuite par `tools/blender/viewmodels.py` (T-385), montrés à Maxime.
- Retour des coups : `HitMarker` (croix du viseur), son de touche, éclair émissif sur le boss (matériau en surimpression 0,1 s), secousse de caméra (`CameraShake`, ressort), bord d'écran rouge (`DamageVignette`).

### En ligne
- La **salle fait autorité** : le client envoie « tirer » et sa visée avec ses commandes (`PlayerCommands` gagne les actions `FIRE`, `RELOAD`, `DODGE`, `ATTACK`, `CHARGE`, `LEAP`, `FURY`) ; la salle crée la fusée, la fait avancer, décide des touches. La fusée est **lente** (45 m/s) : pas besoin de remonter le temps pour compenser la latence, le client affiche sa propre fusée tout de suite et la corrige si la salle dit autre chose.
- `NetWorld.state()` gagne un tableau `versus` : vie du boss, phase, rage, posture (seulement « à genoux » pour les chassés), chrono, vie de chaque chassé et son état ; et des événements fiables `SHOT`, `HIT`, `DOWN`, `REVIVE`, `PHASE`, `END`.
- Le secret du mode Traque (on ne reçoit pas la position d'un chassé qu'on ne voit pas) reste vrai pour le boss ; les chassés reçoivent tous la position du boss quand il est « traqué » (Q4).
- Le salon envoie le mode choisi avec le nombre de joueurs ; la salle le met dans `GameSession.mode` avant de charger la map.

### L'IA
- **Boss IA** : le `Monster` garde sa navigation et sa vue ; `BossBrain` décide de l'attaque (griffe à portée, charge si la ligne est libre et la cible à 6 à 14 m, bond si phase 2 et un tireur isolé, retraite si posture > 80 %).
- **Chassé IA** : la `Prey` reçoit un `PreyFighter` (cerveau pur) : distance voulue 10 à 18 m, tir quand le boss est en vue, roulade sur le signal d'attaque, relève quand le boss est à plus de 15 m. Les tâches du mode Traque (fusibles) ne sont pas lancées en Versus.

## Données et réglages
| Réglage | Fichier | Valeur de départ |
|---|---|---|
| Vie du boss par chassé, multiplicateurs, posture, rage | `game/modes/versus/data/versus_settings.tres` | Q7, Q10, Q11 |
| Phases | `game/modes/versus/data/phases/*.tres` | Q8 |
| Attaques du boss | `game/modes/versus/data/attacks/*.tres` | Q9 |
| Armes et outils | `game/modes/versus/data/weapons/*.tres` | Q13 |
| Vie des chassés, à terre, relevé, endurance, roulade | `versus_settings.tres` | Q5, Q14, Q15 |
| Chrono, aube, traqué | `versus_settings.tres` | Q3, Q4 |
| Arène | `game/modes/versus/data/arenas/tilleuls_centre.tres` | Q24 |

## Impact sur la performance
- Bras : 1 appel de dessin par joueur local. Fusées : 1 appel de dessin par fusée en vol ou au sol (au plus une vingtaine), 2 lumières au plus.
- L'arène ne charge pas les intérieurs (les bâtiments sont fermés et `LevelVisibility` cache leurs étages) : la place centrale est aujourd'hui sous 250 appels de dessin, la marge est donc d'environ 50.
- Réseau : une fusée = un événement à la création ; sa trajectoire est calculée des deux côtés.

## Risques et alternatives
- **Équilibre à 2 et à 4** : la vie du boss suit le nombre de chassés, et les simulations par effectif le vérifient (critère d'équilibre).
- **Latence** : la griffe du boss, rapide, peut sembler « toucher de loin » chez un chassé à 150 ms. Mitigation : signal de 0,35 s avant le coup, et la roulade compte avec l'invulnérabilité au moment où la salle la reçoit. Alternative si besoin : la salle évalue la griffe avec la position du chassé d'il y a la moitié de son ping.
- **Retrait du module** : un test CI (`test_versus_module.gd`) vérifie qu'aucun fichier hors de `game/modes/versus/` ne cite une classe du Versus, sauf la ligne de `game_map.gd`, le choix du mode et les listes du réseau, pour que retirer le module reste simple.

## Conformité à la constitution
- Moteur, langage, rendu : inchangés. Aucune arme à feu, aucun asset externe (modèles par script, sons par script).
- Règle 2.3 « le monstre ne se montre pas plus de 2 s » : **écart demandé** pour le Versus seulement (D-023).
- Budgets : voir « Impact sur la performance ».
