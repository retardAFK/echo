# Ajouter ou retirer un module

> Guide pas à pas pour toute personne ou tout agent (spec S-022, T-430). Lis d'abord [`ARCHITECTURE.md`](ARCHITECTURE.md).
> Mis à jour le 19/11/2026. Si une étape ne correspond plus au code, corrige ce guide dans la même PR que ton changement.

Un **module**, ici, c'est un dossier de `game/` : surtout une entité (`game/entities/<nom>/`), mais aussi un écran (`game/ui/`), un son (`game/audio/`) ou un service. Une fonctionnalité de gameplay touche presque toujours plusieurs couches : l'entité, ses réglages, la map, l'IA, le réseau, l'interface, les sons, les modèles, les tests et la doc.

**La règle d'or** : avant d'ajouter, cherche un module qui ressemble et copie sa forme. Avant de retirer, liste tout ce qui le cite :

```bash
python3 tools/dev/module_map.py --refs CarAlarm     # par class_name (et son nom en snake_case)
grep -rn "car_alarm" game tools tests specs           # par chemin ou par clé
```

Exemple complet à imiter : **l'alarme de voiture** (`game/entities/car_alarm/`), petite, utilisable, bruyante, synchronisée en ligne et utilisée par l'IA.

---

## 1. Ajouter une entité

Les étapes 1 à 4 suffisent pour une entité qui ne fait que du décor. Les étapes 5 à 9 s'ajoutent selon ce qu'elle fait.

### 1.1 La spec d'abord
- Une fonctionnalité nouvelle a une spec (`specs/S-xxx-nom/spec.md`, modèle dans ECHO_PROJET.md §8) ou une ligne dans une spec existante, et une tâche `T-xxx` (bloc de numéros dans `specs/BACKLOG.md`). Pas de code sans tâche (constitution 2.6.1).

### 1.2 Les réglages : `game/data/<nom>_settings.gd` et `.tres`
```gdscript
class_name GurneySettings
extends Resource
## Tunable values of the gurneys (spec S-014, Q7).

## How far a rolling gurney is heard, in meters.
@export_range(1.0, 30.0, 0.5, "suffix:m") var roll_range: float = 8.0
```
- Une valeur de gameplay = un `@export` commenté avec son unité. Jamais de chiffre magique dans l'entité (constitution 2.4).
- Le `.tres` reprend les valeurs : copie `game/data/car_alarm_settings.tres` et change le script et les champs.
- Si la valeur appartient à un domaine qui a déjà ses réglages (bruit, monstre, boucle de partie), ajoute le champ là plutôt que de créer un fichier.

### 1.3 L'entité : `game/entities/<nom>/<nom>.tscn` et `<nom>.gd`
- `class_name` en PascalCase, fichier en snake_case, première ligne `##` qui dit ce que c'est et cite la spec.
- `@export var settings: <Nom>Settings`, rempli dans la scène avec le `.tres`.
- **Bruit** : uniquement par `NoiseBus.emit_noise(NoiseEvent.Type.X, global_position, settings.x_range, self)`. Un nouveau type de bruit s'ajoute **à la fin** de `NoiseEvent.Type` (le numéro voyage en ligne).
- **Communication** : émets des signaux (`signal opened`) ; trouve les autres par groupe (`get_tree().get_nodes_in_group(Door.GROUP)`), jamais par chemin.
- **Utilisable par le chassé** : `add_to_group(Interactable.GROUP)` et les méthodes `can_interact(from)`, `get_prompt()` (renvoie une **clé** de traduction) et `interact(user)` ou `hold(user, delta)` (voir `game/entities/interactable.gd` et `session/hold_interaction.gd`). Le joueur, l'invite à l'écran et les surbrillances la trouvent alors toutes seules.
- **Logique testable** : si l'entité décide quelque chose (minuterie, règle, calcul), mets-le dans une classe `RefCounted` pure à côté (`<nom>_rules.gd`, `<nom>_timer.gd`), comme `decoy/decoy_timer.gd`.
- **Scène** : pas d'override d'un enfant de scène instanciée (ligne `[node name="X" parent="Inst" index="0"]`) : c'est perdu dans le build web, et `tests/test_scene_files.gd` le refuse. Expose plutôt la valeur sur la racine de l'instance.

### 1.4 Les tests : `tests/test_<nom>.gd`
- Un test de la classe pure (sans scène), puis un test de la scène (instancier, régler un `settings.duplicate()` plus rapide, écouter `NoiseBus.noise_emitted`). Modèle : `tests/test_car_alarm.gd`.
- Une nouvelle `class_name` demande `godot --headless --import` avant GUT, sinon « Identifier not declared ».

### 1.5 Le modèle 3D (si elle se voit)
- Un script `bpy` dans `tools/blender/` (constitution 2.6.6), qui écrit le `.glb` dans `assets/models/` et la source `.blend` dans `assets/blender/`. Budgets : constitution 2.3 (triangles, textures 64 à 512 px, filtrage Nearest, orange réservé au bruit).
- Les choix de style sont montrés à Maxime en rendu avant intégration.
- Asset externe : CC0 seulement (polices : OFL), et une ligne dans `CREDITS.md`.

### 1.6 Les sons (si elle s'entend)
- Un script dans `tools/audio/`, qui écrit le `.wav` dans `assets/audio/<famille>/` **et** sa copie étouffée `_muffled.wav` (`tools/audio/muffle.py`) : dans le navigateur, Godot ne peut pas filtrer le son en direct.
- Le son se joue par `SoundSpace.play(player)` sur un `AudioStreamPlayer3D`, routé sur un bus déclaré dans `default_bus_layout.tres` (`Settings.route_audio(node)`).
- Si l'entité joue elle-même le son de son bruit, ajoute son type à `PlayerEars.SELF_VOICED` (`game/entities/player/player_ears.gd`), sinon il est joué deux fois.

### 1.7 La placer dans la cité
- La cité est générée : ajoute la position dans `tools/godot/tilleuls_layout.gd` (constantes en coordonnées du plan), puis l'appel `_place(...)` ou `_place_spot(...)` dans `build_tilleuls.gd` (gameplay, habillage) ou dans le fichier du lieu (`tilleuls_tower.gd`, `tilleuls_places.gd`) ; pour l'hôpital, `tools/godot/hospital.gd`. La chaîne des fichiers est décrite dans ARCHITECTURE.md §5.
- Relance `godot --headless tools/godot/build_tilleuls.tscn`, puis **commite** `game/maps/tilleuls/tilleuls.scn` et `tilleuls_navmesh.res` (LFS).
- Vérifie le budget de 300 appels de dessin (`?bench`, voir `game/bench/bench.gd`) : la cité est déjà près de la limite.
- Ajoute ses règles de placement dans le `tests/test_tilleuls_*.gd` qui convient (pas devant une porte, pas sur un emplacement de fusible…).
- Un objet accroché ou posé (caméra, terminal, haut-parleur, relais…) doit toucher un mur ou un sol à 30 cm près : ajoute sa classe à `PlacementCheck.objects()` (`tools/godot/placement_check.gd`), que `tests/test_tilleuls_placements.gd` vérifie dans la CI (S-020, T-325).
- Un passage à enjamber (`Vault`, S-020, T-340) s'ajoute ou se retire dans la liste `VAULTS` de `tools/godot/tilleuls_layout.gd` (un mur ou une fenêtre doit déjà être là, voir `TOWER_VAULT_WINDOW` et `GALLERY_VAULT_WINDOW`), puis on régénère la carte. `PlacementCheck.vault_offenders()` vérifie qu'il est posé sur un mur, ouvert au-dessus, avec du sol libre des deux côtés ; `tests/test_vault_ai.gd` vérifie que les IA passent par chacun.
- Une boucle de poursuite (S-020, T-341) est un obstacle qu'on contourne des deux côtés : meuble de `FURNITURE`, bloc de `kit.box` ou porte de plus. Pour en ajouter une, construis l'obstacle, puis ajoute à `LOOPS` (`tools/godot/tilleuls_layout.gd`) quatre points dans les allées autour (nord, est, sud, ouest). `tests/test_tilleuls_loops.gd` vérifie que l'obstacle arrête les corps, que les allées sont libres dans les deux sens et que le tour fait 11 à 28 m. Attention : un meuble à moins de 50 cm d'un point des IA, d'une cachette, d'un objet ou d'un emplacement de fusible est retiré sans bruit (`_furniture_pieces()`). Ce test le voit.

### 1.8 L'IA (si les IA doivent s'en servir ou y réagir)
- Monstre IA : `game/entities/monster/monster.gd` (le corps) et `monster_brain.gd` (les décisions, pur). Proie IA : `game/entities/prey/prey.gd`, `prey_brain.gd`, et `prey_tasks.gd` pour les objectifs.
- Aujourd'hui, les IA connaissent chaque entité par son nom (dette notée dans ARCHITECTURE.md §6). Cherche comment elles traitent l'entité la plus proche (`grep -n "CarAlarm" game/entities/prey/prey.gd`) et fais pareil.
- Vérifie avec `tools/godot/simulate_games.tscn` (parties IA contre IA en accéléré) qu'aucune partie ne bloque.

### 1.9 Le jeu en ligne (si son état change pendant la partie)
- La salle fait autorité. Un état visible par les clients (ouvert, en train de sonner, pris) doit passer dans `game/net/net_world.gd` :
  1. un tableau typé et sa détection dans `_init` (même ordre des deux côtés) ;
  2. sa valeur dans `state()` (côté salle) ;
  3. son application dans `apply()` (côté client).
- Un fait ponctuel (un bruit, une capture) est un **événement** de `game/net/net_game.gd`.
- Secret : un client ne reçoit jamais ce qu'il ne pourrait pas savoir.
- Tests : `tests/test_net_world.gd` et `tests/test_net_sync.gd` ; la CI joue ensuite une vraie partie à 4 robots (`tools/godot/net_match.gd`).

### 1.10 Les textes
- Tout texte affiché est une clé de `game/i18n/strings.csv` (`HUD_INTERACT_...`). L'entité renvoie la clé (`get_prompt()`), l'interface la traduit avec `Text.t(...)` ; jamais de phrase dans le code, jamais `tr()` directement. `tests/test_i18n_keys.gd` vérifie que chaque clé utilisée existe. Guide complet : [`game/i18n/README.md`](../game/i18n/README.md).

### 1.11 La doc
- Ajoute l'entité au tableau de [`ARCHITECTURE.md`](ARCHITECTURE.md) §3 et, si elle change une règle du jeu, à ECHO_PROJET.md §6 ou à sa spec. Coche la tâche et écris une ligne de compte rendu (constitution 2.6.5).

---

## 2. Ajouter autre chose

| Ce que tu ajoutes | Où | À imiter |
|---|---|---|
| Une valeur de réglage | un `@export` dans le `*_settings.gd` du domaine, et sa valeur dans le `.tres` | `game/data/noise_settings.gd` |
| Un type de bruit | à la fin de `NoiseEvent.Type`, sa portée dans les réglages de son domaine, son son dans `PlayerEars` (`SELF_VOICED` si l'objet le joue lui-même) | `NoiseEvent.Type.SWITCH` (portée `relay_range` de `loop_settings.gd`) |
| Une règle propre à une façon de jouer (capture, respawn, départ d'un joueur, reconnexion) | la partie de la map qui joue ce cas : `game/maps/map_hunted_role.gd` (solo chassé), `map_monster_role.gd` (solo monstre, simulations), `map_online_room.gd` (salle en ligne), `map_online_client.gd` (écran d'un joueur en ligne). Une partie lit l'état partagé de `GameMap` et n'appelle jamais une autre partie | `MapOnlineRoom.catch_hunted` |
| Un écran ou un HUD | `game/ui/<nom>.tscn` + `.gd` (`CanvasLayer` pour un HUD), ajouté par la partie de la map du bon rôle : `game/maps/hunted_huds.gd` pour le chassé, `map_monster_role.gd` pour le monstre, `game_map.gd` pour ce qui est commun | `game/ui/carry_hud.gd` |
| Un menu | les briques de `game/ui/menu/` (`MenuList`, `MenuItem`, `OptionRow`) et le thème `game/ui/theme/` | `game/ui/pause_menu.gd` |
| Une option du joueur | `game/settings/user_settings.gd` (clé, valeur par défaut, `_apply`) et une ligne de `options_menu.gd` | l'option de sensibilité |
| Un objectif de partie | `game/session/quests.gd` (tirage et état), `loop_rules.gd`, `loop_settings.gd`, la proie IA (`prey_tasks.gd`), `net_world.gd`, la liste de la carte (`ui/map_screen.gd`) ; un indice lu sur place se montre par un petit HUD (`ui/post_it_reader.gd`, que `HuntedHuds` n'ajoute que si la map a des post-it : le retirer ne casse rien) | l'objectif RELAY |
| Un gadget du chassé (S-023) | une entité dont le script a `deploy(user: Player) -> StringName` (se pose dans le monde, renvoie la ruse qu'il compte, `&""` s'il n'a pas pu servir), un `GadgetDef` dans `game/data/gadgets/<nom>.tres` (id, `Inventory.Kind`, scène, `name_key` et `help_key` dans `game/i18n/strings.csv`) et sa ligne dans `game/data/gadgets/gadgets.tres`. Le joueur en choisit `slots` = 2 avant la partie, `charges` = 2 chacun (`game/data/loadout_settings.tres`) ; `Loadout` (`game/session/loadout.gd`) valide le choix pour les menus (`LoadoutItems`), les réglages, le salon, la salle et l'IA, et les touches 1 et 2 (`GADGET_1`, `GADGET_2`) passent par `GadgetUse.use_slot`. `CarryHud` et `tests/test_gadgets.gd` lisent la liste : rien à toucher dans `player.gd`, ni le réseau (le choix voyage en index de la liste). Pour le retirer : sa ligne de la liste, puis le reste comme une entité (section 3) | `game/entities/walkman/walkman.gd` + `game/data/gadgets/walkman.tres` |
| Un palier du monstre (S-023) | un `EscalationStage` dans `game/data/escalation/<nom>.tres` (`name_key` dans `strings.csv`, `overrides` : nom d'un réglage de `MonsterSettings` → nouvelle valeur) et sa ligne, à sa place, dans `game/data/escalation/escalation.tres`. Le palier n vient au n-ième objectif réussi ; `MonsterEscalation` (enfant de `GameLoop`) le donne à chaque monstre du groupe `monsters` (joué ou IA, solo, salle et client), qui a sa propre copie de ses réglages, et `LoopHud` fait gronder et affiche « Le monstre s'énerve ». `tests/test_escalation.gd` vérifie que chaque nom existe. Pour le retirer : sa ligne de la liste. Un palier qui demande un comportement neuf ajoute d'abord un réglage à `MonsterSettings` lu par le monstre | `game/data/escalation/stage_3_siren.tres` (`scan_whole_complex`, lu par `ScanGauge.holds`) |
| Un poste de la salle d'essai (S-023) | un `TestStation` de plus dans `game/maps/test_room/stations.tres` : `name_key` (texte de la pancarte, dans `strings.csv`), `scene` (une scène de `game/entities/` qui marche seule), `position`, `yaw_degrees` et, au besoin, `properties` (valeurs exportées posées avant l'entrée dans la salle). `TestRoom` (`test_room.gd`) le pose avec sa pancarte ; `tests/test_test_room.gd` vérifie chaque poste. Pour le retirer : sa ligne de la liste | le muret : `vault.tscn` posé sur le muret de 60 cm de la greybox avec `{"top": 0.6, "width": 3.0}` |
| Un son d'ambiance | `game/audio/` (un nœud qui joue en boucle) et son script de fabrication dans `tools/audio/` | `game/audio/ambient_train.gd` |
| Un service global | à éviter. Seulement s'il n'a pas d'autre maître que tout le jeu : autoload dans `project.godot`, documenté dans ARCHITECTURE.md | `NoiseBus` |

---

## 3. Retirer un module

Dans cet ordre, pour que chaque étape reste vérifiable :

1. **Lister** tout ce qui le cite :
   ```bash
   python3 tools/dev/module_map.py --refs Gurney
   ```
   La liste montre le code, les scènes, les tests, les scripts d'assets, les specs et les fichiers d'assets (`file …`).
2. **Le sortir de la map** : retire ses positions dans `tools/godot/tilleuls_layout.gd` et ses appels dans `build_tilleuls.gd`, `tilleuls_tower.gd`, `tilleuls_places.gd` ou `hospital.gd`, regénère la cité, commite la scène et le maillage de navigation.
3. **Le sortir du réseau** : son tableau, `state()` et `apply()` dans `net_world.gd`, ses événements dans `net_game.gd`. Le format des snapshots change : les clients et le serveur doivent être déployés ensemble (c'est le cas à chaque fusion sur `main`).
4. **Le sortir des IA** : les références dans `monster.gd`, `prey.gd`, `prey_tasks.gd`, et les cerveaux.
5. **Le sortir de l'interface et du joueur** : HUD, invites, `player.gd`, `monster_avatar.gd`.
6. **Supprimer le dossier de l'entité** (scène, script et leur fichier `.uid`), ses réglages dans `game/data/` (`.gd`, `.uid`, `.tres`), ses tests (`.gd` et `.uid`).
7. **Ne pas renuméroter** `NoiseEvent.Type` : laisse le type (commenté « plus utilisé ») plutôt que de décaler les numéros qui voyagent en ligne.
8. **Les assets** : ses `.glb`, textures, sons et leurs `.import` dans `assets/`, son script dans `tools/blender/` ou `tools/audio/` s'il ne sert qu'à lui, sa ligne dans `CREDITS.md`.
9. **Les textes** : ses clés dans `game/i18n/strings.csv` (voir [`game/i18n/README.md`](../game/i18n/README.md), section « Renommer ou retirer un texte »).
10. **La doc** : ARCHITECTURE.md, la spec (une ligne « retiré le … » plutôt que d'effacer l'historique), le journal des décisions si c'était une décision.
11. **Vérifier** : relance `--refs`, il ne doit rester que la doc d'historique ; puis les commandes de [`AGENTS.md`](../AGENTS.md#commandes).

---

## 4. Avant d'ouvrir la PR

- [ ] La tâche `T-xxx` est citée dans le commit et la PR, une PR par tâche.
- [ ] `gdformat --check game tests tools` et `gdlint game tests tools` passent.
- [ ] `godot --headless --import` puis GUT passent.
- [ ] Si la map a changé : regénérée, scène et navigation commitées, budget de draw calls tenu.
- [ ] Si l'état est visible en ligne : `net_world.gd` à jour et testé.
- [ ] La doc (ce guide, ARCHITECTURE.md, la spec) dit la même chose que le code.
