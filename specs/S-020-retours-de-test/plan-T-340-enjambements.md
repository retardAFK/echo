# T-340 (piste E6) : fenêtres et murets à enjamber — plan à valider

Cahier de Maxime du 20/11/2026 : « Fenêtres et murets à enjamber : 0,5 s pour le chassé, 1,5 s pour le monstre ; la PR propose d'abord la liste des emplacements. »

Ce document est cette proposition. Rien n'est construit avant l'accord de Maxime. Toutes les valeurs sont des points de départ, réglables dans `game/data/`.

## Pourquoi

Un passage à enjamber crée un raccourci que le chassé prend en 0,5 s et le monstre en 1,5 s. Chaque passage fait donc gagner une seconde au chassé, de quoi casser une poursuite. Le monstre peut aussi les prendre : ce sont des passages, pas des murs.

## Les règles proposées

| Règle | Proposition |
|---|---|
| Geste | Viser le passage à moins de 1,5 m et appuyer sur E (pas besoin de maintenir). Le corps passe de l'autre côté en suivant un arc, sans pouvoir se tourner ni agir. |
| Durée | Chassé : `vault_time` = 0,5 s. Monstre (IA ou joueur) : `monster_vault_time` = 1,5 s. |
| Bruit | Chassé : 5 m (comme une porte ouverte debout, un peu moins). Monstre : 8 m (on l'entend s'approcher). |
| Accroupi, caché, au terminal | Impossible d'enjamber. On se lève d'abord. |
| Course | En courant, E enjambe sans s'arrêter avant (pas de temps en plus). |
| IA | Les IA (monstre et proie) prennent les passages comme des liens de navigation, au coût de leur durée : le monstre IA les prend en poursuite si le détour est plus long que 1,5 s. |
| En ligne | La salle décide, comme pour les portes (T-307). Le client prédit l'enjambement pour ne pas être recalé. |

## Les emplacements proposés (10)

Coordonnées du plan papier (`map_kit.gd` : x vers l'est, y vers le sud, en mètres).

### Murets dehors (4)

| # | Lieu | Où | Ce que ça change |
|---|---|---|---|
| M1 | Aire de jeux, bordure est (0,5 m) | x = 72, y 78 à 84 | Raccourci direct vers la tour (x 92), au lieu de contourner par les entrées nord et sud du bac à sable |
| M2 | Aire de jeux, bordure ouest (0,5 m) | x = 50, y 78 à 84 | Même chose vers l'ouest, côté hôpital |
| M3 | City stade, bord sud (1,1 m) | y = 200, x 158 à 168 | Une deuxième sortie du stade, côté boulevard, en plus des ouvertures ouest et nord |
| M4 | City stade, bord est (1,1 m) | x = 178, y 186 à 194 | Une sortie vers le parking, à l'opposé de l'ouverture ouest : le stade devient une boucle |

### Fenêtres de rez-de-chaussée (6)

Une fenêtre à enjamber a son allège à 0,9 m et pas de vitre (cassée). Elle se voit : vitre manquante et éclats au sol.

| # | Bâtiment | Où | Ce que ça change |
|---|---|---|---|
| F1 | Centre social | Façade sud, fenêtre de x = 152 (grande salle) | Fuir la grande salle sans passer par l'entrée nord |
| F2 | Centre social | Façade est, fenêtre de y = 73,5 | Une sortie vers le parking, à l'opposé de la scène |
| F3 | Galerie commerciale | Vitrine de la boulangerie, façade sud (y = 149) | Entrer ou sortir de la galerie sans la porte principale |
| F4 | Hôpital | Façade est (x = 32), une chambre du rez-de-chaussée au sud de l'auvent (y ≈ 115) | Une issue de plus vers la cité, loin des urgences |
| F5 | Hôpital | Façade ouest (x = 10), une salle au nord du quai (y ≈ 70) | Une issue vers la friche, pour sortir du long couloir |
| F6 | Tour | Hall du rez-de-chaussée, façade ouest (x = 92) | Sortir de la tour vers l'aire de jeux sans passer par les portes du hall |

Le parking souterrain n'a pas de fenêtre. Je propose de ne rien y ajouter : la rampe et les deux escaliers suffisent, et T-341 y prévoit déjà des boucles autour des piliers.

## Ce que la PR de réalisation contiendra

- Une entité `Vault` (`game/entities/vault/`), avec un test GUT par règle : durée chassé et monstre, bruit, refus accroupi ou caché, passage en courant.
- Les réglages dans `game/data/vault_settings.gd`.
- Les passages posés par `build_tilleuls.gd`, avec des liens de navigation pour les IA, puis la carte régénérée.
- Le contrôle de placement de T-325 étendu aux passages : chacun doit avoir du sol libre des deux côtés.
- Le guide du jeu mis à jour.

## À trancher par Maxime

1. La liste des 10 emplacements : garder, retirer ou déplacer des passages.
2. Le bruit de l'enjambement (5 m pour le chassé, 8 m pour le monstre), ou aucun bruit.
3. Si le monstre IA doit prendre les passages, ou les laisser aux chassés et au monstre joué.
