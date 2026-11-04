# Plan — S-003

**Statut** : validé (04/11/2026)

## Approche technique
- **`MonsterBrain`** (`game/entities/monster/monster_brain.gd`, `RefCounted`, sans scène) : la machine à états, entièrement testable avec GUT.
  - États : `PATROL` (ronde), `INVESTIGATE` (enquête sur un bruit), `CHASE` (poursuite), `SEARCH` (recherche au dernier endroit vu).
  - Entrées à chaque image : bruit entendu (position, date), joueur visible ou non, jauge de repérage, arrivée à destination, temps écoulé.
  - Sorties : état, destination, allure (rôder, marcher, courir).
- **`Monster`** (`game/entities/monster/monster.tscn` + `.gd`, `CharacterBody3D`) : applique les sorties du cerveau.
  - Se déplace avec un `NavigationAgent3D` vers la destination, à la vitesse de l'allure.
  - Silhouette provisoire : capsule noire de 2,2 m avec deux yeux pâles.
  - Couche physique 4 « monstre » (nouvelle).
  - Signaux : `state_changed(state)`, `player_caught`.
- **Ouïe** : le monstre écoute `NoiseBus.noise_emitted` et garde les bruits pour lesquels `NoiseBus.can_hear` est vrai à hauteur de sa tête. Il ignore ses propres bruits.
- **Vue** (`game/entities/monster/monster_vision.gd`, nœud enfant) : 10 fois par seconde, angle et distance vers les yeux du joueur, puis un lancer de rayon sur les couches « monde » et « murs ». Remplit ou vide la jauge de repérage selon la distance et l'allure du joueur.
- **Bruits du monstre** : un émetteur de foulées propre au monstre envoie ses pas dans `NoiseBus` avec les portées de D-009 (0 m en rôdant, 3 m en marchant, 12 m en courant). Le souffle est un bruit de 2 m toutes les secondes.
- **Sons provisoires** (Q5) : `AudioStreamPlayer3D` sur le monstre. Les sons sont des `AudioStreamWAV` courts générés au démarrage par le code (bruit filtré pour le pas, souffle). Le volume est coupé au-delà de la portée du bruit, pour que ce que le joueur entend corresponde aux règles du jeu.
- **Capture** : à moins de 1,2 m du joueur, le monstre émet `player_caught`. Un écran `CaughtScreen` (`game/ui/caught_screen.tscn`) affiche la clé de traduction `HUD_CAUGHT` (« Attrapé ») 2 s, puis la map remet le joueur au départ et le monstre au point de ronde le plus éloigné.
- **Navigation** : une `NavigationRegion3D` dans la greybox, avec un maillage de navigation calculé à l'avance et enregistré dans le dépôt (`game/maps/greybox_test_navmesh.tres`), régénéré par un petit script de l'éditeur. Pas de calcul au lancement dans le navigateur.
- **Greybox** (Q6) : un petit bâtiment de deux pièces (murs sur la couche « murs »), deux ouvertures de porte et une fenêtre, et 4 points de ronde (`Marker3D` dans un nœud `PatrolRoute`).
- **Debug** : la surcouche F3 ajoute l'état du monstre, sa jauge de repérage et le compteur de captures. F4 affiche aussi le cône de vision au sol.

## Données et réglages
- `game/data/monster_settings.gd` (`MonsterSettings`) + `monster_settings.tres` :

| Réglage | Valeur par défaut |
|---|---|
| `prowl_speed` / `walk_speed` / `run_speed` | 1,5 / 3,5 / 6 m/s (Q1) |
| `prowl_range` / `walk_range` / `run_range` | 0 / 3 / 12 m (D-009) |
| `breath_range` / `breath_interval` | 2 m / 1 s (D-009) |
| `vision_angle` / `vision_range` | 100° / 25 m (Q2) |
| `spot_time_near` / `spot_time_far` | 0,4 / 1,5 s (Q2) |
| `crouch_spot_factor` | 0,5 (Q2) |
| `spot_decay_time` | 2 s pour vider la jauge |
| `investigate_time` | 6 s (Q3) |
| `lose_sight_time` / `search_time` | 3 s / 8 s |
| `catch_distance` | 1,2 m |
| `caught_screen_time` | 2 s (Q4) |
| `ear_height` | 2 m |

## Impact sur la performance
- Un seul monstre. La vue fait 10 lancers de rayons par seconde, l'ouïe 1 à 5 par bruit entendu. Négligeable.
- Navigation : chemin recalculé au plus 4 fois par seconde, sur un maillage précalculé.
- Sons générés une seule fois au démarrage, quelques kilo-octets en mémoire, rien dans le build.
- Silhouette provisoire : 2 maillages simples, un matériau.

## Risques et alternatives
- **Navigation dans le navigateur** : le maillage précalculé évite tout calcul au lancement. Plan B si le suivi de chemin pose problème : ronde en ligne droite entre les points, sans évitement.
- **Monstre trop fort ou trop faible** : toutes les valeurs sont dans `monster_settings.tres` pour les régler en playtest sans toucher au code.
- **Audio web** : les navigateurs bloquent le son avant le premier clic. Le clic qui capture la souris le débloque déjà.
- **Jauge de repérage injuste** : si le joueur se sent repéré sans comprendre pourquoi, on ajoutera un indice visuel (yeux qui s'allument) dès cette spec.

## Conformité à la constitution
- Logique pure testable dans `MonsterBrain`, couverte par GUT, sans scène.
- Communication par signaux : `noise_emitted`, `state_changed`, `player_caught`.
- Le monstre passe par `NoiseBus` pour ses propres bruits (service unique, 2.4).
- Aucun chiffre magique : tout dans `monster_settings.tres`.
- Orange réservé au bruit (2.3) : le monstre et son cône de debug n'utilisent pas l'orange.
- Texte joueur via clé de traduction : `HUD_CAUGHT`.
