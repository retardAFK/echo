# Plan — S-002

**Statut** : proposé, à valider après les clarifications de la spec

## Approche technique
- **`NoiseEvent`** (`game/autoload/noise_event.gd`, `RefCounted`) : position, portée en mètres, source (nœud émetteur), date d'émission. Pas de logique.
- **`NoiseMath`** (`game/autoload/noise_math.gd`, fonctions statiques, sans scène) : portée perçue selon le nombre de murs, « est-ce que ce point entend ce bruit », niveau de jauge à partir d'une portée, décroissance de la jauge. Entièrement couvert par GUT.
- **`NoiseBus`** (autoload, `game/autoload/noise_bus.gd`, constitution 2.4) :
  - `emit_noise(position, range, source)` crée un `NoiseEvent` et émet le signal `noise_emitted(event)`. Toute source de bruit passe par lui.
  - `walls_between(from, to)` compte les murs avec des lancers de rayons successifs sur la couche physique « murs ».
  - `perceived_range(event, listener_position)` combine les deux via `NoiseMath`.
- **Couches physiques** nommées dans `project.godot` : 1 « monde » (sols), 2 « murs » (ce qui étouffe le son), 3 « joueur ». Les blocs verticaux de la greybox passent sur la couche « murs » ; les marches et le sol non.
- **`FootstepEmitter`** (`game/entities/player/footstep_emitter.gd`, nœud enfant du joueur) : cumule la distance parcourue au sol, émet un bruit à chaque foulée selon l'allure (signal `gait_changed` de S-001). Aucun bruit à l'arrêt ni en l'air.
- **Jauge** (`game/ui/noise_gauge.tscn` + `.gd`) : écoute `NoiseBus.noise_emitted` filtré sur le joueur, monte au niveau du dernier pas, redescend avec le temps. Libellé via une clé de traduction (`HUD_NOISE`), premier fichier de traduction `game/i18n/strings.csv` (français).
- **Debug** (`game/ui/noise_debug.tscn` + `.gd`) : F4 affiche des anneaux orange au sol (un `MeshInstance3D` partagé par anneau, recyclés depuis une petite réserve), qui s'effacent en 3 s.
- **Micros de test** (`game/entities/noise_probe/noise_probe.tscn` + `.gd`) : écoutent `noise_emitted`, s'allument si `perceived_range` atteint leur position, visibles seulement en mode debug.

## Données et réglages
- `game/data/noise_settings.gd` (`NoiseSettings`) + `noise_settings.tres` :

| Réglage | Valeur par défaut |
|---|---|
| `crouch_range` / `walk_range` / `sprint_range` | 1 / 4 / 14 m |
| `crouch_stride` / `walk_stride` / `sprint_stride` | 0,5 / 0,7 / 0,9 m |
| `wall_factor` | 0,5 (Q1) |
| `max_walls_counted` | 4 |
| `gauge_full_range` | 15 m (Q3) |
| `gauge_decay_time` | 2 s |
| `debug_ring_lifetime` | 3 s |
| `emit_height` | 0,3 m au-dessus des pieds |

## Impact sur la performance
- Un bruit par pas : 1 à 2 événements par seconde. Chaque auditeur fait au plus 5 lancers de rayons par bruit : négligeable.
- Anneaux de debug : au plus 8 à l'écran, un seul matériau, désactivés par défaut. Quelques draw calls.
- Jauge : un contrôle 2D. Aucun asset lourd, la taille du build Web ne bouge pas.

## Risques et alternatives
- **Comptage des murs** : un rayon peut toucher deux fois le même mur épais, ou passer par un interstice. Plan B : compter les collisions distinctes avec exclusion des objets déjà touchés, et fixer l'épaisseur minimale des murs dans la greybox.
- **Murs bas** : un muret de 60 cm étouffe-t-il un bruit ? Les rayons partent à 0,3 m et visent l'oreille de l'auditeur ; avec cette règle, un muret entre deux joueurs debout ne compte pas toujours. Acceptable pour le prototype, à revoir avec le monstre.
- **Traduction** : premier fichier `.csv` de traduction du projet. Godot le convertit à l'import ; les `.translation` générés sont déjà ignorés par Git.

## Conformité à la constitution
- Service central unique `NoiseBus` en autoload : oui (2.4).
- Communication par signaux : `noise_emitted`, `gait_changed`.
- Aucun chiffre magique : tout dans `noise_settings.tres`.
- Logique testable couverte par GUT : `NoiseMath`, `NoiseBus` (avec murs réels), `FootstepEmitter`.
- Couleur orange réservée au bruit (2.3) : jauge, anneaux et micros allumés. Aucun usage dans le décor.
- Texte joueur en français via clé de traduction : `HUD_NOISE`.
