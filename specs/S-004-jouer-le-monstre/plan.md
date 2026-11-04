# Plan — S-004

**Statut** : validé (04/11/2026)

## Approche technique
- **Écran de démarrage** (`game/ui/start_menu.tscn` + `.gd`, Q1) : deux boutons traduits (`MENU_PLAY_HUNTED`, `MENU_PLAY_MONSTER`). Il devient la scène principale. Il charge la greybox et lui dit quel rôle donner au joueur. Échap revient au menu.
- **Monstre jouable** (`game/entities/monster/monster_avatar.tscn` + `.gd`, `CharacterBody3D`) : caméra à la première personne à 2 m, souris et ZQSD comme le chassé. Les vitesses et portées viennent de `monster_settings.tres` (rôder, marcher, courir, Q6). Il réutilise l'émetteur de foulées et le souffle du monstre IA (S-003), pour que la proie l'entende selon D-009.
- **Affichage des bruits** (`game/ui/noise_markers.gd`, Q2) : écoute `NoiseBus.noise_emitted`, garde ceux que `NoiseBus.can_hear` laisse passer à l'oreille du monstre, et pose un repère orange à l'écran (projeté depuis la position 3D, visible à travers les murs) avec la distance. Un petit nombre de repères recyclés, effacés en 3 s.
- **Bâtiments scannables** (`game/entities/building/building.gd`, `Area3D`) : un volume qui couvre le bâtiment et une liste de lumières. Le bâtiment de la greybox en reçoit un, avec deux `OmniLight3D` (une par pièce).
- **Scan** (`ScanGauge`, `RefCounted`, testé sans scène, Q3) : jauge de 8 s, recharge en 45 s, refus sous 25 %, concentration de 1 s. Le monstre jouable lance un rayon depuis la caméra vers un bâtiment à moins de 30 m. Pendant le scan, tous les bruits émis dans le volume du bâtiment s'affichent, quelle que soit leur portée. Les lumières du bâtiment vacillent tant que le scan dure.
- **Proie IA** (`game/entities/prey/prey_brain.gd`, `RefCounted`, et `prey.tscn`, Q4 et Q5) : états `WANDER` (promenade), `FLEE` (fuite vers la cachette la plus éloignée du monstre), `HIDE` (accroupie et silencieuse), `FREEZE` (figée par l'alerte du scan). Elle se déplace avec un `NavigationAgent3D` sur le maillage de la greybox, émet ses pas dans `NoiseBus` avec les portées de 6.2, écoute le monstre et le voit avec `MonsterVision`. Après une course, elle émet un souffle de faible portée pendant 10 s, que seul le scan révèle.
- **Capture** (Q6) : à moins de 1,2 m, l'écran « Attrapée » (`HUD_PREY_CAUGHT`) s'affiche 2 s et la proie réapparaît au point le plus éloigné du monstre.
- **Debug** : F3 ajoute l'état de la proie, la jauge de scan et le compteur de captures. F4 montre les points de promenade et les cachettes.

## Données et réglages
- `game/data/monster_settings.tres` : nouveaux réglages du monstre jouable.

| Réglage | Valeur par défaut |
|---|---|
| `marker_fade_time` | 3 s (D-008) |
| `scan_capacity` / `scan_recharge_time` / `scan_min_start` | 8 s / 45 s / 25 % (D-009) |
| `scan_focus_time` / `scan_max_distance` | 1 s / 30 m (Q3) |
| `light_flicker_rate` | 8 vacillements par seconde |

- `game/data/prey_settings.gd` + `prey_settings.tres` (Q4 et Q5) :

| Réglage | Valeur par défaut |
|---|---|
| `walk_speed` / `run_speed` / `crouch_speed` | ceux du chassé (S-001) |
| `sight_range` | 15 m |
| `hide_time` | 20 s |
| `breathless_time` / `breath_range` / `breath_interval` | 10 s / 0,5 m / 1 s |
| `scan_notice_chance` | 0,5 |
| `respawn_screen_time` | 2 s |

## Impact sur la performance
- Une proie, un monstre, une dizaine de repères à l'écran au plus.
- Le scan ne fait qu'un test « ce bruit est-il dans le volume ? » par bruit émis.
- Deux lumières de plus dans la greybox, sans ombres, compatibles avec le rendu Compatibility.

## Risques et alternatives
- **Proie trop bête ou trop maligne** : tous ses réglages sont dans `prey_settings.tres`. Elle ne sert qu'à tester seul, elle sera remplacée par un humain en phase 6.
- **Repères illisibles à travers les murs** : plan B, une flèche au bord de l'écran pour les bruits hors champ.
- **Changement de scène principale** : les tests et la CI chargent toujours la greybox directement, l'écran de démarrage ne casse rien.

## Conformité à la constitution
- Logique pure testable dans `ScanGauge` et `PreyBrain`, couverte par GUT.
- Communication par signaux : `noise_emitted`, `scan_started`, `scan_ended`, `prey_caught`.
- Un seul service de bruit : la proie et le monstre jouable passent par `NoiseBus`.
- Aucun chiffre magique : tout dans `monster_settings.tres` et `prey_settings.tres`.
- Orange réservé au bruit : seuls les repères de bruit sont orange, la jauge de scan est pâle.
- Texte joueur via clés de traduction : `MENU_PLAY_HUNTED`, `MENU_PLAY_MONSTER`, `HUD_PREY_CAUGHT`.
