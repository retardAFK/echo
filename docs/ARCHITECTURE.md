# Architecture d'Écho

> Carte du code pour toute personne ou tout agent qui reprend le projet (spec S-022, T-430).
> Le **quoi** et le **pourquoi** sont dans [`ECHO_PROJET.md`](../ECHO_PROJET.md) et `specs/` ; ce document dit **où** et **comment**.
> Mis à jour le 19/11/2026 (T-431). Si le code et ce document ne disent pas la même chose, le code a raison : corrige ce document dans la même PR.

Pour regénérer les chiffres de cette page :

```bash
python3 tools/dev/module_map.py            # qui dépend de qui, module par module
python3 tools/dev/module_map.py --sizes    # les plus gros scripts
python3 tools/dev/module_map.py --refs Gurney   # tous les fichiers qui citent un module
```

---

## 1. Vue d'ensemble

Le jeu est **un seul projet Godot 4.7** (GDScript, rendu Compatibility). Le même projet exporté sert trois rôles :

| Processus | Lancé par | Scène de départ | Ce qu'il fait |
|---|---|---|---|
| **Jeu** (navigateur ou PC) | le joueur | `game/ui/start_menu.tscn` (`run/main_scene`) | menus, partie solo contre l'IA, ou client d'une partie en ligne |
| **Accueil** (serveur) | `-- --lobby` | `game/net/lobby_server.tscn` | donne un code de 4 lettres à chaque partie et lance une salle |
| **Salle** (serveur) | l'accueil, `-- --room <n> --code <code>` | `game/net/room_server.tscn` | fait tourner **une** partie et fait autorité |

`game/net/server_boot.gd` lit la ligne de commande et choisit le rôle. Détails du serveur : [`tools/server/README.md`](../tools/server/README.md).

Il n'y a **qu'une map jouable**, la cité des Tilleuls (avec l'hôpital intégré, D-019), plus une map grise de test (`game/maps/greybox_test.tscn`). La cité n'est **jamais éditée à la main** : elle est générée par `tools/godot/build_tilleuls.gd` (voir §5).

---

## 2. Les dossiers

### `game/` : tout ce que Godot charge

| Dossier | Rôle | Fichiers clés |
|---|---|---|
| `autoload/` | Services globaux toujours chargés : le **bruit** (`NoiseBus`) et le son 3D (`SoundSpace`) | `noise_bus.gd`, `noise_event.gd`, `noise_math.gd` (calcul pur), `sound_space.gd` |
| `settings/` | Réglages du joueur (volume, sensibilité, touches), autoload `Settings` | `user_settings.gd` |
| `data/` | **Réglages de gameplay** : un script `Resource` (`*_settings.gd`) et sa valeur (`*_settings.tres`) par domaine. Aucun chiffre magique ailleurs (constitution 2.4) | `noise_settings`, `player_settings`, `monster_settings`, `net_settings`… (19 paires) |
| `entities/` | **Une entité par dossier** : scène `.tscn` + script du même nom (constitution 2.4) | voir §3 |
| `session/` | Règles d'**une partie** : boucle (fusibles, sortie, fin), objectifs tirés au sort, inventaire, choix du menu, statistiques de poursuite de l'écran de fin | `game_loop.gd`, `loop_rules.gd` (pur), `quests.gd`, `game_session.gd` (statique : rôle, graine, siège), `chase_stats.gd` (pur) et `chase_watch.gd` (S-020, T-322) |
| `maps/` | Ce qui **assemble** une map jouable, et les aides de rendu par map | `game_map.gd` (racine de toute map : l'état partagé et la boucle), une partie par façon de jouer (`map_hunted_role.gd`, `map_monster_role.gd`, `map_online_room.gd`, `map_online_client.gd`), les HUD du chassé (`hunted_huds.gd`), `level_visibility.gd`, `draw_range.gd`, `map_plan.gd`, `surface_map.gd`, `tilleuls/` (scène générée, LFS) |
| `net/` | **Multijoueur** : accueil, salles, liaison, prédiction, snapshots | `net_session.gd` (autoload `NetSession`), `room_link.gd`, `net_game.gd`, `net_world.gd`, `prediction.gd`, `player_commands.gd` |
| `ui/` | HUD, écrans et menus. `ui/menu/` : briques des menus (style A, S-013). `ui/theme/` : le thème | `start_menu.gd`, `lobby_menu.gd`, `pause_menu.gd`, `end_screen.gd`, `noise_markers.gd`, `scan_reticle.gd` |
| `audio/` | Sons qui ne sont pas des entités : vent, musique, pas selon le sol, calcul pur du son | `sound_math.gd` (pur), `footstep_sounds.gd`, `tension_music.gd`, `city_wind.gd` |
| `fx/` | Rendu : nuit et brouillard, filtre rétro, look du scan, précompilation des shaders | `night_environment.gd`, `retro_surface.gd`, `shader_warmup.gd` |
| `bench/` | Bancs d'essai : performance (`?bench`) et mixage (`?mix`) | `bench.gd`, `mix_bench.gd` |
| `i18n/` | Textes affichés : `strings.csv` (clé, texte français) et la classe `Text`, seule porte d'entrée (`Text.t`, `Text.count`, `Text.with_keys`). Les entités renvoient des clés, l'interface les traduit. Guide : [`game/i18n/README.md`](../game/i18n/README.md) | `text.gd`, `strings.csv` |
| `shaders/`, `assets/` | Vides (`.gitkeep`) : les shaders sont dans `fx/`, les assets à la racine dans `assets/` | — |

### Hors de `game/`

| Dossier | Rôle |
|---|---|
| `assets/` | Modèles `.glb`, textures, sons, polices, sources `.blend` (`assets/blender/`). **Tout est en Git LFS** (voir [`PIEGES.md`](PIEGES.md)) |
| `art_src/` | Packs CC0 d'origine (Quaternius) |
| `tools/blender/` | Un script Python par famille d'assets (`bpy`), la seule façon de créer un modèle (constitution 2.6.6) |
| `tools/audio/` | Scripts Python qui fabriquent les sons (et leur copie étouffée `_muffled.wav`) |
| `tools/godot/` | Scripts Godot lancés à la main ou par la CI : **générateur de la cité** (voir §5), textures, captures d'écran, robots de parties en ligne (`net_match`, `net_spectate`, `net_smoke`…), simulations (`simulate_games`) |
| `tools/server/` | Installation et déploiement du serveur (IONOS, Caddy, systemd) |
| `tools/web/` | Mesure du mixage dans Chromium (Playwright) |
| `tools/dev/` | Outils pour les développeurs et les agents : `module_map.py` (carte des modules), `dump_scene.tscn` (vidage comparable d'une scène, pour vérifier qu'une map regénérée n'a pas changé) |
| `tests/` | Tests GUT, un fichier `test_<sujet>.gd` par sujet (105 fichiers, environ 800 tests) |
| `specs/` | Une spec par fonctionnalité (`spec.md`, `plan.md`, `tasks.md`), et `BACKLOG.md` |
| `docs/` | Ce document, [`MODULES.md`](MODULES.md) (ajouter ou retirer un module) et [`PIEGES.md`](PIEGES.md) |

---

## 3. Les entités

Chaque dossier de `game/entities/` contient une scène et son script, avec une `class_name` en PascalCase. Une entité :
- lit ses valeurs dans un `*_settings.tres` de `game/data/` ;
- fait du bruit **uniquement** par `NoiseBus.emit_noise(...)` ;
- se déclare dans un ou plusieurs **groupes** (`add_to_group`) pour être trouvée sans chemin de nœud ;
- si le chassé peut s'en servir, elle est dans le groupe `Interactable.GROUP` et a `can_interact(from)`, `get_prompt()`, et `interact(user)` ou `hold(user, delta)` (`game/entities/interactable.gd`).

| Famille | Entités |
|---|---|
| Personnages | `player/` (chassé jouable, oreilles, pas, capture en ligne), `monster/` (monstre IA `monster.gd` + cerveau pur `monster_brain.gd`, monstre jouable `monster_avatar.gd`, jauge de scan, vision, bruits), `prey/` (chassé IA : corps `prey.gd`, cerveau `prey_brain.gd`, objectifs `prey_tasks.gd`), `hunted_body/` et `monster_body/` (modèles animés) |
| Objectifs | `fuse_box/`, `transformer/`, `exit/`, `objectives/` (code, disquette, relais) |
| Ruses | `bottle/`, `decoy/`, `pickup/`, `car_alarm/`, `hiding_spot/`, `firecracker/` |
| Équipe (S-020) | `ping/` (marque « Monstre » / « Ici » pour les coéquipiers, T-328 ; affichée par `ui/ping_markers.gd`, jamais envoyée au monstre) |
| Lieux | `building/` (volume scannable), `door/`, `jamb/` (décoince une IA d'un chambranle), `metal_floor/`, `indoor_fog/`, `ventilation/`, `neon/` |
| Hôpital | `gurney/`, `wheelchair/`, `monitor/` |
| Prison et réseau (S-018) | `prison/` (cages, règles pures), `network/` (terminaux, caméras, haut-parleurs, rideaux, `city_network.gd`) |
| Debug | `noise_probe/` |

**Règle des cerveaux purs** : toute décision testable sans affichage vit dans une classe `RefCounted` (`*_brain.gd`, `*_rules.gd`, `*_math.gd`, `*_timer.gd`) que le nœud appelle. C'est ce qui permet les tests GUT rapides. Garde-la.

---

## 4. Le chemin d'une partie

### Solo

```
start_menu ──(GameSession.role, graine)──► loading_screen ──► tilleuls.scn
                                                               └─ racine = GameMap (game_map.gd)
GameMap._ready()
  ├─ rôle chassé : MapHuntedRole (Player + Monster IA, captures) et HuntedHuds (carry, hide mask, highlights, carte, réseau)
  ├─ rôle monstre : MapMonsterRole (MonsterAvatar + Prey IA, marques de bruit, réticule de scan, captures)
  ├─ _setup_game_loop() : GameLoop + Quests (fusibles, objectifs, sortie)
  └─ pause, précompilation des shaders
```

### En ligne (D-015 : serveur qui fait autorité)

```
navigateur ── wss ──► accueil (code de partie) ──► salle (un processus par partie)

Client                                   Salle (NetSession.mode == ROOM)
LocalControls → PlayerCommands ────────► NetGame applique les commandes aux avatars
Prediction (son propre avatar)  ◄─────── snapshots : sa position, ceux qu'il voit (NetVisibility)
NetPuppet (les autres)          ◄─────── événements fiables : bruits entendus, scan, captures
NetWorld.apply()                ◄─────── état des objets de la map (NetWorld.state())
```

- `NetSession` (autoload) garde le mode : `SOLO`, `CLIENT` ou `ROOM`.
- `GameMap._setup_online()` ajoute `NetGame`, qui relaie l'état, et une partie : `MapOnlineRoom` sur la salle (pose les avatars et les IA des places vides, applique la règle de capture et la prison, remplace les absents par des IA) ou `MapOnlineClient` chez un joueur (son avatar, ses HUD, les captures annoncées, la reconnexion).
- `NetWorld` liste **dans le même ordre des deux côtés** les objets de la map qui changent (fusibles, ramassables, alarmes, cachettes, portes, moniteurs, brancards, fauteuils, transformateur, prison, réseau, vent). **Une entité qui change pendant la partie doit y être ajoutée**, sinon les clients ne la voient pas changer (voir [`MODULES.md`](MODULES.md)).
- Règle de secret : un client ne reçoit jamais ce qu'il ne pourrait pas savoir (qui se cache où, position d'un coéquipier hors de vue).

### Le bruit (cœur du jeu, pilier P1)

```
une action ──► NoiseBus.emit_noise(type, position, portée, source)
                 ├─ coupe par le vent (rafale dehors), masque de la ventilation
                 └─ signal noise_emitted(NoiseEvent)
                       ├─ Monster (IA) et Prey (IA) : ce qu'elles entendent
                       ├─ NoiseMarkers, ScanReticle : marques orange du monstre jouable
                       ├─ PlayerEars : ce que le joueur entend, joué en 3D par SoundSpace
                       ├─ NoiseGauge, NoiseDebug (F4), TensionMusic, GameLoop
                       └─ NetGame côté salle : envoie le bruit à ceux qui l'entendent
```

Pour trouver tous les auditeurs : `grep -rn "noise_emitted.connect" game`.

Les calculs (atténuation, murs, portée) sont dans `noise_math.gd` et `sound_math.gd`, testés sans scène.

---

## 5. La map générée

```
specs/S-006-cite-des-tilleuls/plan-map.svg   (plan papier validé)
        │
tools/godot/build_tilleuls.gd   ← le lancer ; il hérite d'une chaîne de fichiers :
   tilleuls_layout.gd  (toutes les positions, tailles et scènes : c'est là qu'on place un objet)
 → tilleuls_base.gd    (état partagé, petites aides : portes, fenêtres, matériaux, groupes)
 → tilleuls_tower.gd   (sol, limites, barres, tour, caves)
 → tilleuls_places.gd  (centre social, galerie, parking, garages, repères)
 → build_tilleuls.gd   (ordre de construction, gameplay, habillage, lumière, navigation)
   aides : map_kit.gd, hospital.gd, floor_builder.gd,
           interior_lining_kit.gd → interior_lining_rooms.gd → interior_lining.gd
        │   godot --headless tools/godot/build_tilleuls.tscn
        ▼
game/maps/tilleuls/tilleuls.scn          (binaire, LFS : ne jamais éditer à la main)
game/maps/tilleuls/tilleuls_navmesh.res  (navigation, LFS)
game/maps/tilleuls/tilleuls_surfaces.tres, tilleuls_plan.tres
```

Toute position de gameplay (fusibles, cachettes, terminaux, leurres, portes) est écrite dans le générateur. Pour ajouter un objet à la map : on l'ajoute au générateur, on relance, on **commite la scène et le maillage de navigation**. Les tests `test_tilleuls*.gd` relisent la scène générée et vérifient ses règles (pas de cachette à moins d'1 m d'une porte, etc.).

---

## 6. Règles de dépendance

### Ce qui est voulu

```
data, autoload/noise_math, session/*_rules, entities/*_brain   ← logique pure, ne dépend de rien d'autre
        ▲
entities/*     ← parlent par signaux et groupes, lisent data/, font du bruit par NoiseBus
        ▲
session/, net/, ui/   ← observent les entités
        ▲
maps/game_map.gd + maps/map_*.gd   ← assemblent le tout (les seuls à tout connaître)
```

1. Une entité **ne cherche pas** un nœud par chemin (`get_node("/root/...")` : 0 occurrence aujourd'hui, garde ça). Elle trouve les autres par **groupe** ou reçoit une référence de celui qui l'assemble.
2. Les classes pures (`RefCounted`) ne touchent pas l'arbre des nœuds.
3. Les entités ne connaissent pas le réseau (`NetSession`, `NetGame`, `RoomLink`) : c'est `net/` qui les observe, et la partie en ligne de la map (`map_online_client.gd`, `map_online_room.gd`) qui les branche. Par exemple, `MapOnlineClient` donne à `NetSession` les commandes de l'avatar du joueur. `tests/test_entity_rules.gd` le vérifie.
4. Une valeur de gameplay vit dans `game/data/`, pas dans le code.

### Où le code s'en écarte aujourd'hui (dette connue)

Mesuré le 19/11/2026 avec `tools/dev/module_map.py`. Ce qui reste n'a pas encore de tâche. Déjà corrigé par S-022 : `GameMap` (918 lignes, qui faisait tout) a été découpé par T-433 ; `game_map.gd` ne garde que l'état partagé, la boucle et la pause, et chaque façon de jouer a sa partie dans `game/maps/map_*.gd`, aucune au-dessus de 400 lignes. Le joueur et le monstre jouable ne lisent plus `NetSession` (T-434).

| Écart | Où | Effet |
|---|---|---|
| Les IA connaissent chaque entité par son nom | `monster.gd` (19 modules), `prey.gd` (20 modules) | ajouter ou retirer une entité utilisable demande de toucher l'IA |
| `NetWorld` liste chaque type d'entité synchronisée | `net/net_world.gd`, `net/net_game.gd` | idem pour le réseau |
| `NoiseBus` connaît `Door` et `Ventilation` | `autoload/noise_bus.gd` | un service central dépend d'entités |

Fichiers de plus de 500 lignes dans `game/` : `prey.gd` (876), `net_game.gd` (812), `player.gd` (648), `monster.gd` (605). Avant d'y ajouter du code, demande-toi s'il ne mérite pas sa propre classe.

---

## 7. Tests et CI

- **GUT 9.7.1** (`.gutconfig.json`, `tests/pre_run_hook.gd` impose 3 fusibles). Un fichier `test_<sujet>.gd` par sujet. Les classes pures se testent sans scène ; les tests de scène chargent la vraie scène (`tilleuls.scn` dans 44 fichiers).
- **CI** (`.github/workflows/ci.yml`), sur chaque PR :
  1. `lint` : `gdformat --check` et `gdlint` sur `game/`, `tests/` et `tools/` (règles par défaut de gdtoolkit 4.5.0 : 100 caractères par ligne, 1 000 lignes par fichier).
  2. `godot` : import headless, tests GUT, export web et contrôle du budget de 60 Mo (D-007), export du serveur, **4 robots qui jouent une vraie partie en ligne** (`tools/godot/net_match.tscn`) et un spectateur (`net_spectate.tscn`), puis sur `main` : déploiement du serveur et publication itch.io.
- Commandes locales : voir [`AGENTS.md`](../AGENTS.md#commandes).
