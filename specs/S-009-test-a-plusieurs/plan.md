# Plan — S-009

**Statut** : validé (12/11/2026), hébergement sur itch.io (Q1)

## Approche technique

### Mode banc d'essai (Q2)
- Nouvelle classe pure **`BenchStats`** (`game/bench/bench_stats.gd`, `RefCounted`) : elle reçoit la durée de chaque image et rend la moyenne des images/s, le minimum, la moyenne des 1 % les plus lentes, et garde le pire des appels de dessin et des triangles. Testée par GUT avec des séries connues.
- Nouvelle scène **`Bench`** (`game/bench/bench.tscn`) : elle charge `tilleuls.tscn`, remplace l'avatar du joueur par la proie IA (même code que `tools/godot/simulate_games.gd`, mis en commun), lance `GameLoop` avec une graine fixe et place une `Camera3D` qui suit un parcours fixe (`Curve3D` de points dans la cour, la tour, le parking souterrain et la galerie) en 60 s. Les 3 premières secondes ne comptent pas (compilation des shaders, chargement). Les appels de dessin et les triangles viennent de `Performance` (`RENDER_TOTAL_DRAW_CALLS_IN_FRAME`, `RENDER_TOTAL_PRIMITIVES_IN_FRAME`).
- Le temps de chargement est mesuré du lancement du moteur (`Time.get_ticks_msec()` au premier `_ready`) à la première image de la map.
- Lancement : `StartMenu._ready()` regarde l'adresse de la page sur le web (`JavaScriptBridge.eval("location.search")`) et les arguments `--bench` sur PC ; si `bench` est présent, il passe directement à la scène `Bench`.
- Résultat : un écran simple (base 640 × 360, D-011) et une ligne `ECHO_BENCH {json}` dans la console, que Claude lit avec les outils du navigateur.

### Build de test en ligne (Q1)
- **itch.io (retenu)** : un nouveau job `publish` dans `ci.yml`, seulement sur `push` vers `main`, après le job `godot`. Il récupère l'artefact `web-build`, installe `butler` (outil officiel d'itch.io) et pousse le dossier sur le canal `html5` de la page (`butler push build/web <compte>/<jeu>:html5 --userversion <sha court>`). La clé est le secret `BUTLER_API_KEY` ; le nom de la page est la variable de dépôt `ITCH_TARGET`. Sans secret, le job est sauté sans erreur. Le build est déjà mono-fil (`thread_support=false`), il n'a donc pas besoin de l'option SharedArrayBuffer d'itch.io.
- Version du jeu : la CI écrit le SHA court dans `application/config/version` de `project.godot` avant l'export (« dev » en local). Le résumé de fin et le banc d'essai l'affichent.

### Le monstre IA scanne (Q3)
- `MonsterBrain` gagne un état **`SCAN`**, un signal `trace_lost(at)` (fin d'une enquête ou d'une recherche sans résultat, ou retour au bâtiment entendu) et `can_scan(building, gauge_ready)` : pas en poursuite, jauge prête, bâtiment pas scanné depuis `ai_scan_cooldown` (30 s). Décision pure et testée.
- `Monster` a sa propre `ScanGauge`. Sur `trace_lost`, il cherche le bâtiment le plus proche à moins de `ai_scan_radius` (15 m, `Building.distance_to`), lance la jauge, met `building.scanned` (les lumières vacillent) et s'arrête, tourné vers lui, au plus `ai_scan_time` (4 s). Une fois la concentration passée, tout bruit du bâtiment est entendu, même trop faible (même règle que `MonsterAvatar.scan_reveals`). Un bruit entendu, une proie repérée ou la jauge vide finissent le scan.
- `GameLoop` compte déjà les scans (`_on_scan_changed`) ; la simulation les affiche.

### Équilibre (Q4)
- Simulations avec `tools/godot/simulate_games.tscn` (3 séries de 20, graines différentes), en regardant où et quand la proie est prise.
- Leviers dans l'ordre : réglages des `.tres` (vitesses, portées, durées), puis IA (choix des cachettes et des fuites), puis map (deuxième issue du couloir du centre social, couverture près du fusible du parking), avec des tests de navigation.
- Si la durée moyenne reste sous 8 min, on joue sur la recherche des fusibles (distance des emplacements) plutôt que sur la vitesse du monstre.

### Commandes et pause (Q5, Q6)
- `StartMenu` gagne un second panneau : après le choix du rôle, commandes et but de ce rôle, bouton « Jouer ». Les textes passent par `game/i18n/strings.csv`.
- Nouvelle scène **`PauseMenu`** (`game/ui/pause_menu.tscn`, `process_mode = ALWAYS`), ajoutée par `GameMap` en jeu (pas dans le banc ni dans la simulation). Action d'entrée `pause` (Échap). Elle fait `get_tree().paused = true`, libère la souris, et se déclenche aussi si la souris capturée est relâchée par le navigateur. « Reprendre » recapture la souris (le clic sert de geste utilisateur exigé par le navigateur). « Revenir au menu » rétablit `paused = false` et change de scène.
- Le panneau des commandes est une scène commune (`controls_panel.tscn`) au menu de départ et à la pause.

### Retours (Q7)
- `EndScreen` gagne « Copier le résumé » : `DisplayServer.clipboard_set()` d'un texte construit par une fonction pure testée (`RunSummary.format(...)`), à partir des compteurs de `GameLoop` et de la moyenne des images/s de la partie (petit compteur léger dans `GameLoop`).
- `questionnaire.md` dans ce dossier.

## Données et réglages
| Réglage | Fichier | Valeur de départ |
|---|---|---|
| Rayon de recherche d'un bâtiment à scanner | `monster_settings.tres` (`ai_scan_radius`) | 15 m |
| Durée d'un scan du monstre IA | `monster_settings.tres` (`ai_scan_time`) | 4 s |
| Délai avant de rescanner le même bâtiment | `monster_settings.tres` (`ai_scan_cooldown`) | 30 s |
| Durée du parcours du banc | `bench_settings.tres` | 60 s, 3 s ignorées au début |

## Impact sur la performance
- Le banc, la pause et le résumé n'ajoutent rien d'affiché en jeu, sauf deux petits panneaux d'interface hors partie.
- Le scan du monstre IA réutilise le vacillement existant (S-004) : pas de lumière en plus.
- Taille du build : quelques Ko de scripts.

## Risques et alternatives
- **Le navigateur intégré n'a pas d'accélération graphique** ou ne ressemble pas à Chrome : la mesure serait trop basse. Plan B : Claude ouvre le lien dans Chrome par l'app, ou demande à Maxime d'ouvrir le lien `?bench` et de copier la ligne affichée (une minute, sans jouer).
- **Pas de compte itch.io** au moment de T-076 : la CI garde l'artefact `web-build` comme aujourd'hui, et la publication se branche dès que le secret est ajouté.
- **L'équilibre n'atteint pas 8 à 12 min** avec des IA : on livre avec les chiffres et on s'appuie sur les testeurs (comme S-008).

## Conformité à la constitution
- GDScript seul, Compatibility, réglages dans `data/`, signaux entre entités, tests GUT pour `BenchStats`, la décision de scan et le résumé.
- Aucun changement du budget de performance ; le banc sert justement à le vérifier (section 2.2).
