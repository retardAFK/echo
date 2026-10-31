# Plan — S-001

**Statut** : validé (31/10/2026)

## Approche technique
- **Scène joueur** `game/entities/player/player.tscn` + `player.gd` (classe `Player`) :
  - `CharacterBody3D` racine, `CollisionShape3D` en capsule (rayon 0,3 m, hauteur 1,75 m debout).
  - `Node3D` « Head » portant la `Camera3D` à 1,6 m (yeux d'une personne de 1,75 m).
  - `ShapeCast3D` vers le haut pour savoir si on peut se relever.
  - Déplacement dans `_physics_process` avec `move_and_slide()`. La montée des marches passe par `floor_snap_length` et une petite rampe de détection (marche ≤ 0,3 m), le muret de 0,6 m bloque.
  - Accroupi : la capsule passe à 1,0 m et la tête descend en interpolation (pas de saut d'image).
- **Logique pure séparée** `game/entities/player/player_motion.gd` (classe `PlayerMotion`, fonctions statiques) : vitesse cible selon l'allure, normalisation de la diagonale, limite du regard vertical, accélération. Elle se teste avec GUT sans lancer le jeu.
- **Allure** exposée par un signal `gait_changed(gait)` (accroupi, marche, course), que S-002 écoutera pour émettre le bruit. Pas d'appel direct vers le futur `NoiseBus`.
- **Entrées** : actions déclarées dans `project.godot` (`move_forward`, `move_back`, `move_left`, `move_right`, `sprint`, `crouch`, `release_mouse`) avec des **codes de touche physiques**, ce qui donne ZQSD en AZERTY et WASD en QWERTY sans réglage, plus les flèches.
- **Souris** : capture au clic (obligatoire dans un navigateur, la capture doit suivre un geste du joueur), libération sur Échap. Mouvement lu dans `_unhandled_input` (`InputEventMouseMotion.screen_relative`, indépendant de la résolution).
- **Map de test** `game/maps/greybox_test.tscn` : sol, murs, couloir, marche de 0,25 m, muret de 0,6 m, passage bas de 1,2 m, angles pour tester les collisions. Formes `CSGBox3D` converties en `MeshInstance3D` + `StaticBody3D` pour rester sous le budget de draw calls. Une seule lumière directionnelle, sans ombres pour l'instant. Devient la scène principale.
- **Compteur FPS** `game/ui/debug_overlay.tscn` : FPS et allure courante, affiché seulement en build debug ou avec F3.

## Données et réglages
- `game/data/player_settings.gd` (classe `PlayerSettings`, `extends Resource`) et `game/data/player_settings.tres` :

| Réglage | Valeur par défaut |
|---|---|
| `walk_speed` | 3,0 m/s |
| `sprint_speed` | 5,5 m/s |
| `crouch_speed` | 1,5 m/s |
| `acceleration` / `deceleration` | 30 / 40 m/s² |
| `mouse_sensitivity` | 0,15 °/pixel |
| `pitch_limit` | 89° |
| `standing_height` / `crouch_height` | 1,75 m / 1,0 m |
| `eye_offset` | 0,15 m sous le haut de la capsule |
| `crouch_transition_time` | 0,15 s |
| `max_step_height` | 0,3 m |
| `head_bob_enabled` / amplitudes | oui / 0,03 m marche, 0,06 m course |

Valeurs de départ, à ajuster en playtest (Q1, Q5).

## Impact sur la performance
- Map de test : moins de 50 objets, moins de 5 000 triangles, environ 20 draw calls, 1 lumière. Très loin des budgets (150 000 triangles, 300 draw calls, 4 lumières).
- Résolution interne 640 × 360 (Q6 validée) : `display/window/stretch/mode = "viewport"`, `scale_mode = "integer"`, fenêtre de 1280 × 720 par défaut. Ça réduit fortement le coût de rendu.
- Aucun asset ajouté : la taille du build Web ne bouge presque pas.

## Risques et alternatives
- **Capture de la souris dans le navigateur** : certains navigateurs ajoutent de l'accélération ou des sauts au premier mouvement après capture. Plan B : ignorer le premier événement de mouvement après la capture.
- **Montée des marches** avec `CharacterBody3D` : Godot ne la gère pas nativement. Plan B si la détection pose problème : petites rampes invisibles sur les marches de la map.
- **60 images/s** : vérifiable uniquement à la main dans Chrome sur la machine de référence. La CI vérifie que le projet s'importe, que les tests passent et que l'export Web tient dans le budget, pas le nombre d'images par seconde.

## Conformité à la constitution
- GDScript uniquement, renderer Compatibility : oui.
- Aucun chiffre magique : toutes les valeurs de gameplay sont dans `player_settings.tres`.
- Une scène par entité avec un script du même nom : `player.tscn` / `player.gd`.
- Communication par signaux : `gait_changed` pour S-002.
- Code en anglais, textes joueur en français via des clés de traduction : le seul texte affiché est le compteur debug, qui n'est pas destiné au joueur.
- Logique testable couverte par GUT : `PlayerMotion` et `PlayerSettings`.
- Écart validé : la résolution de 640 × 360 arrive avant la phase 5 (Q6).
