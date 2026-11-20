# T-341 (piste E7) : boucles de poursuite par bâtiment — plan à valider

Cahier de Maxime du 20/11/2026 : « Boucles de poursuite : 2 ou 3 circuits par bâtiment (îlot de cuisine, rayons de la galerie, piliers du parking) ; la PR propose d'abord un plan par bâtiment. »

Ce document est cette proposition. Rien n'est construit avant l'accord de Maxime.

## Ce qu'est une boucle

Une boucle, c'est un obstacle qu'on peut contourner par les deux côtés. Le chassé tourne autour, le monstre doit choisir un sens, et le chassé repart dans l'autre. Pour qu'elle serve, je propose trois critères :

- **Tour complet de 12 à 25 m.** Plus court, le monstre attrape en tendant le bras (il attrape à un peu plus d'un mètre). Plus long, ce n'est plus une boucle mais un détour.
- **Allées d'au moins 1,4 m.** Les deux corps passent, et les IA aussi (rayon de navigation).
- **Un obstacle haut (plus de 1,6 m) dans au moins une boucle par bâtiment.** Il coupe la vue : le monstre perd le chassé de vue une seconde à chaque tour. Un obstacle bas, comme un comptoir, laisse voir par-dessus. Il sert alors aux ruses (lancer une bouteille de l'autre côté), pas à se cacher.

Les nouveaux meubles bloquent les corps, la vue et la navigation comme ceux de S-016 (Q7). Ils restent dans le budget de draw calls : réemploi des modèles existants, ou une boîte texturée avec l'atlas des intérieurs.

## Plan par bâtiment

Coordonnées du plan papier (x vers l'est, y vers le sud, en mètres). « Existe » : la boucle est déjà jouable, je vérifie seulement ses mesures. « Nouveau » : il faut construire.

### Centre social (x 140 à 178, y 60 à 84)

| # | Boucle | État | Tour | Vue |
|---|---|---|---|---|
| C1 | **Îlot de cuisine** : un plan de travail de 3 × 1,2 m (0,9 m de haut) au milieu de la cuisine (x 152 à 160, y 78 à 84), avec des allées de 1,4 m | Nouveau | ≈ 12 m | Bas |
| C2 | **Pile de chaises et tables pliées** au milieu de la grande salle, 2 × 4 m et 1,8 m de haut | Nouveau | ≈ 16 m | Haut |
| C3 | **Scène et coulisses** : monter par un escalier de la scène, passer derrière le rideau, redescendre par l'autre | À vérifier (il faut un escalier de chaque côté) | ≈ 20 m | Haut |

### Galerie commerciale (x 45 à 87, y 135 à 149)

| # | Boucle | État | Tour | Vue |
|---|---|---|---|---|
| G1 | **Rayons de l'épicerie** : deux gondoles de 4 m (1,7 m de haut) dans une demi-boutique, trois allées | Nouveau | ≈ 14 m par gondole | Haut |
| G2 | **Îlot de machines de la laverie** : une rangée de machines dos à dos au milieu de la laverie, au lieu de tout contre les murs | Nouveau (déplacer des machines) | ≈ 14 m | Moyen (1,2 m) |
| G3 | **Boutique et couloir de livraison** : entrer par la vitrine, sortir par la porte de derrière, revenir par l'arcade | À vérifier (porte de derrière ouverte) | ≈ 25 m | Haut |

### Parking souterrain (x 140 à 180, y 95 à 117)

| # | Boucle | État | Tour | Vue |
|---|---|---|---|---|
| P1 | **Piliers** : les piliers tous les 8 m, plus deux épaves garées en épi qui ferment un îlot autour d'un pilier | Existe en partie (les piliers), épaves à placer | ≈ 18 m | Haut (pilier) |
| P2 | **Local technique à deux portes** : entrer par une porte, ressortir par l'autre | Nouveau (une deuxième porte) | ≈ 16 m | Haut |
| P3 | **Rampe et escalier sud** : descendre la rampe, remonter par l'escalier, revenir dehors | Existe | ≈ 60 m | Haut |

P3 est trop long pour une boucle de poursuite au sens strict. Je la garde comme « grande boucle » : c'est celle qu'un chassé qui connaît la carte utilise pour semer le monstre.

### Tour (x 92 à 116, y 88 à 112)

| # | Boucle | État | Tour | Vue |
|---|---|---|---|---|
| T1 | **Appartement à deux portes** : sur chaque palier visité, un appartement traversant avec une porte sur le palier et une sur l'escalier de secours | Nouveau (une porte) | ≈ 20 m | Haut |
| T2 | **Escalier intérieur et escalier de secours** : monter par l'un, redescendre par l'autre | Existe | ≈ 30 m par étage | Haut |

### Hôpital (x 10 à 32, y 56 à 132)

| # | Boucle | État | Tour | Vue |
|---|---|---|---|---|
| H1 | **Poste de soins en îlot** : le comptoir du poste de soins décollé du mur, avec un passage derrière | Nouveau (déplacer) | ≈ 12 m | Bas |
| H2 | **Chambres communicantes** : deux chambres voisines reliées par la salle de bains, chacune avec sa porte sur le couloir | Nouveau (une porte par paire, deux paires par niveau) | ≈ 15 m | Haut |
| H3 | **Les deux escaliers** de chaque niveau | Existe | ≈ 80 m | Haut |

## Ce que la PR de réalisation contiendra

- Les boucles « Nouveau » construites dans `build_tilleuls.gd` et `hospital.gd`, puis la carte régénérée.
- Un test GUT par boucle : le tour fait la bonne longueur, et la navigation fait le tour dans les deux sens. Le chemin le plus court entre deux points opposés passe par chacun des deux côtés quand l'autre est bloqué.
- Un avant/après des draw calls aux points les plus chargés (budget 300, pire point 294 en S-016).
- Une simulation IA contre IA pour voir si les poursuites durent plus longtemps.
- Le guide du jeu mis à jour.

## À trancher par Maxime

1. Garder, retirer ou déplacer des boucles. Je recommande de commencer par C1, C2, G1, P1, P2, H1 et H2. Ce sont les « Nouveau » qui coûtent le moins de draw calls.
2. Les critères de longueur (12 à 25 m) et de largeur (1,4 m).
