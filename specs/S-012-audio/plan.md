# Plan — S-012

**Statut** : proposé par Claude (17/11/2026), sur la spec validée le 17/11/2026

## Ce que permet le navigateur (mesuré le 17/11/2026)
Le build web est sans threads (`variant/thread_support=false`), donc Godot y joue l'audio en **mode « samples »** : chaque son est confié à la Web Audio API du navigateur. Le moteur web de Godot 4.7.2 (`godot.js` du modèle d'export) n'y crée que des nœuds de gain, de répartition des canaux et de lecture : **ni filtre, ni réverbération, ni compresseur**, et les effets de bus sont ignorés. Ce qui marche : volume et panoramique par voix (calculés par le moteur pour les `AudioStreamPlayer3D`), hauteur (`pitch_scale`), volume, coupure et envoi des bus déclarés dans `default_bus_layout.tres` (un bus ajouté en cours de jeu est muet, PR #116). Tout ce plan en découle : l'étouffement, l'écho et le limiteur sont préparés dans les fichiers, pas calculés en direct.

## Approche technique

### Spatialisation et occlusion (T-142)
- **`SoundMath`** (`game/audio/sound_math.gd`, logique pure testée par GUT) :
  - `volume_db(distance, perceived_range)` : 0 dB tout près, une pente douce jusqu'à −20 dB au bord de la portée perçue, silence au-delà ;
  - `wall_db(walls)` : −8 dB par mur ;
  - `behind_db(direction, forward)` : jusqu'à −3 dB pour un son derrière.
- **`SpatialSound`** (`game/audio/spatial_sound.gd`) : `SpatialSound.play(player, noise_range)` remplace `player.play()` partout où un bruit de jeu est joué en 3D (oreilles des joueurs et objets qui jouent leur propre son : portes, cachettes, fusibles, transformateur, bouteilles, réveils, cage, terminal, caméra, haut-parleur, rideau, relais, moniteurs, brancards, fauteuils). Il compte les murs entre le son et l'auditeur avec `NoiseBus.walls_between`, choisit la version étouffée s'il y a au moins un mur, règle `volume_db` (le niveau propre du son + distance + murs + derrière) et coupe l'atténuation de Godot (`ATTENUATION_DISABLED`) pour que la courbe soit la nôtre. Le panoramique reste celui de Godot.
- **Auditeur** : la caméra courante (le chassé, le monstre, ou le coéquipier regardé en spectateur).
- **Versions étouffées** : `tools/audio/muffle.py` passe chaque son de jeu dans un passe-bas (≈ 700 Hz) et l'écrit à côté, suffixe `_muffled.wav`. `SpatialSound` les trouve par leur chemin (`foo.wav` → `foo_muffled.wav`), sans liste à tenir à jour.
- **Panoramique** : `audio/general/3d_panning_strength` à 1,0 dans `project.godot`.
- Les sons longs en boucle (néon, ventilation, transformateur) restent des sons d'ambiance, hors de cette règle.

### Pas selon le sol (T-143)
- **`FloorSurface`** (`game/audio/floor_surface.gd`) : enum `CONCRETE, EARTH, METAL, TILE, WOOD, PUDDLE` et `FloorSurface.at(tree, position)`.
- **`SurfaceMap`** (`Resource`, `game/maps/tilleuls/tilleuls_surfaces.tres`) : une liste de boîtes (rectangle du plan, bas, haut, sol), écrite par `build_tilleuls.gd` depuis ce qu'il sait déjà : chaque `kit.zone` du revêtement (`interior_lining.gd`, l'hôpital) donne son sol (TERRAZZO, LINO, WARD_LINO → carrelage ; PARQUET → parquet ; CONCRETE → béton), les allées → béton, l'aire de jeux → terre, les zones `MetalFloor` → métal, les flaques → flaque. Hors de toute boîte : terre au niveau du sol dehors, béton ailleurs. Les boîtes plus petites l'emportent (une flaque dans une allée).
- **Flaques** : une douzaine dehors (creux des allées, pied des barres) et trois au parking ; un seul maillage pour toutes (un reflet sombre presque noir, sans lumière), donc **1 appel de dessin** de plus au plus. Elles entrent dans `SurfaceMap`.
- **Portées** : `NoiseMath.range_for_gait` reçoit le sol au lieu du seul booléen « métal » ; `NoiseSettings` gagne `puddle_crouch_range` (2 m), `puddle_walk_range` (8 m), `puddle_sprint_range` (20 m).
- **Sons** : `tools/audio/footsteps.py` synthétise 4 variantes par sol, et 4 raclements du monstre ; `FootstepSounds` (`game/audio/footstep_sounds.gd`) tire une variante différente de la précédente et une hauteur entre 0,92 et 1,08.
- **Mes propres pas** : `FootstepEmitter` signale chaque pas (`stepped(surface, gait)`) ; un `SelfSounds` (2D, bus Effets) dans le joueur et le monstre jouable les joue doucement (accroupi −30 dB, marche −20 dB, course −12 dB), ainsi que mon souffle.
- **Les pas des autres** : les oreilles lisent le sol à la position du bruit (les sols sont les mêmes chez tous, rien à envoyer en ligne).

### Qui a fait le bruit (T-143)
`NoiseEvent` gagne `by_monster` (rempli par `NoiseBus.emit_noise` si la source est le monstre). Le message `NOISE` de la salle prend un 5e élément (`by_monster`), et le client le recopie. Les oreilles jouent le raclement et le souffle rauque quand `by_monster` est vrai.

### Le vent (T-144)
- **`WindGusts`** (`game/audio/wind_gusts.gd`, logique pure testée) : un calendrier de rafales tiré d'une graine (intervalle 25–50 s, durée 6–10 s, montée 2 s), `strength(time)` de 0 à 1 et `is_gusting(time)`.
- **`CityWind`** (nœud de la map, à côté de l'ambiance) : avance le temps de partie, règle le volume de la boucle de vent et d'un sifflement de rafale (`gust.wav`), et dit à `NoiseBus` s'il y a rafale. En ligne, la salle décide (sa graine et son temps) et envoie l'état de rafale dans l'état du monde (`NetWorld`, une entrée de plus).
- **`NoiseBus.emit_noise`** : pendant une rafale, un bruit dehors (hors de tout volume `Building`) de portée ≤ `wind_small_range` (6 m) a sa portée multipliée par `wind_factor` (0,5). Réglages dans `NoiseSettings`, groupe « Vent (S-012) ».

### Voix du monstre (T-145)
- Nouveau type de bruit `GROWL` (12 m) et `SCREAM` (30 m) dans `NoiseEvent.Type` (ajoutés à la fin, pour ne pas décaler les numéros envoyés en ligne).
- **Grognement** : `MonsterNoise` retient le temps depuis la dernière course ; le premier pas de course après 3 s (`MonsterSettings.growl_rest`) émet aussi `GROWL`.
- **Cri** : à la capture (`Monster` et la salle en ligne), `SCREAM` à la position du monstre.
- **Scan** : `ScanDrone` (2D, bus Voix, monstre seulement) monte avec la concentration ; `Building` joue un grésillement (`scan_crackle.wav`, 3D, ambiance) près de ses lampes pendant qu'il vacille.
- **Bus Voix** dans `default_bus_layout.tres`, envoyé dans Effets.
- Sons : `tools/audio/monster_voice.py` (souffle, 3 grognements, cri, bourdon du scan, grésillement).

### Musique (T-146)
- `tools/audio/music.py` : trois boucles de 32 s qui se raccordent (fond, malaise, effroi), même longueur et même tempo, lancées ensemble.
- **`TensionMusic`** (`game/audio/tension_music.gd`, bus Musique) : lancé par la map ; la décision de palier est une fonction pure testée (`TensionMusic.level_for(distance, …)`, paliers 35 m et 15 m, palier gardé au moins 3 s) ; le volume de chaque nappe glisse (4 s à la montée, 10 s à la descente). En chassé, la distance au monstre (dont la position est connue du client en ligne) ; en monstre, le dernier bruit entendu à moins de 25 m ; pour tous, l'effroi quand la sortie est ouverte.

### Mixage (T-147)
- Niveaux propres de chaque son réglés dans les fichiers (normalisés par les scripts) et dans `SpatialSound` (une table par type de bruit) ; bus à 0 dB, Musique −6 dB, Ambiance −3 dB.
- **Mesure** : un script Playwright lance le build web avec le son autorisé, branche un analyseur avant la sortie (méthode de PR #116) et relève le niveau crête et moyen dans des scènes types (pas proches, sirène + alarme + cri, musique seule, ambiance seule). Résultats notés dans la spec.
- Pas de limiteur de bus (ignoré dans le navigateur) : on garde de la marge dans les niveaux.

### Sons provisoires (T-149)
`tools/audio/voices.py` (appel à l'aide, sauvetage) et une alarme de voiture faite par nous ; `PlaceholderSounds` supprimée.

## Données et réglages
- `NoiseSettings` : `puddle_*_range`, `wind_small_range`, `wind_factor`.
- `MonsterSettings` : `growl_range` (12 m), `growl_rest` (3 s), `scream_range` (30 m).
- `AudioSettings` (nouveau, `game/data/audio_settings.tres`) : pente de volume, dB par mur, dB derrière, volumes de mes propres pas, paliers et temps de la musique, calendrier des rafales.

## Impact sur la performance
- Un comptage de murs (au plus 4 rayons) par son de jeu joué, comme pour l'entendre : déjà fait par `can_hear`, on garde le résultat.
- `FloorSurface.at` parcourt quelques centaines de boîtes par pas : négligeable (quelques pas par seconde).
- Flaques : 1 appel de dessin, quelques centaines de triangles.
- Build web : moins de 2 Mo de sons en plus (QOA).

## Risques et alternatives
- **Le mode « samples » change** dans une version future de Godot : la règle reste dans nos fichiers, rien à reprendre.
- **Musique trop informative** : si elle sert de radar, on élargit les paliers ou on la coupe en chassé (réglage dans `AudioSettings`).
- **Rafales trop fortes** pour l'équilibre : `wind_factor` et `wind_small_range` sont des réglages.

## Conformité à la constitution
- Sons faits par nous (2.7), scripts rangés dans `tools/audio/`.
- Aucun chiffre magique : tout dans `NoiseSettings`, `MonsterSettings`, `AudioSettings`.
- Le `NoiseBus` reste la seule porte des bruits de jeu (2.4) ; la musique et l'ambiance n'y passent pas.
- Orange réservé au bruit : les flaques sont sombres, rien d'orange ajouté.
