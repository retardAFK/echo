# Pièges connus

> Les erreurs déjà faites sur ce projet, pour ne pas les refaire (spec S-022, T-430).
> Ajoute une ligne ici chaque fois qu'un problème t'a coûté plus d'une heure.

## Export web

- **Override d'un enfant de scène instanciée perdu dans le build web** (PR #31). Une ligne `.tscn` `[node name="X" parent="Inst" index="0"]` qui change une propriété d'un enfant d'une scène instanciée marche dans l'éditeur et dans GUT, mais disparaît à l'export. Le bâtiment avait perdu sa forme de scan. Expose la valeur sur la racine de l'instance (`Building.size`). `tests/test_scene_files.gd` refuse ces lignes.
- **Variables exportées perdues à la conversion binaire** (PR #112) : les `keys` des `MenuList` disparaissaient, l'écran d'accueil web était vide. `project.godot` garde `export/convert_text_resources_to_binary=false` : ne le change pas.
- **Bus audio créés au lancement muets dans le navigateur** (PR #116). Le build web n'a pas de threads, donc l'audio passe par Web Audio (mode « samples ») : pas de filtre, pas de réverbération, pas d'effet de bus, seulement le volume, le panoramique, la hauteur et le volume des bus. Déclare tout bus dans `default_bus_layout.tres` (Master, Effets, Ambiance, Musique, Voix → Effets). L'étouffement et l'écho sont **cuits dans les fichiers** (`_muffled.wav`).
- Godot atténue encore un `AudioStreamPlayer3D` vers `max_distance` dans le navigateur, même avec `ATTENUATION_DISABLED` : `SoundSpace` met `max_distance = 0` et garde la portée dans la méta `noise_range`.
- Toujours vérifier une fonctionnalité nouvelle dans le **build web exporté**, pas seulement dans GUT (qui lit les scènes texte).
- Cache du navigateur : un vieux `index.pck` peut être servi sur `localhost:8000`. Change de port ou fais Ctrl+F5.

## Git LFS

- `.glb`, `.wav`, `.png`, `.blend`, `.scn` et `.res` passent par LFS (`.gitattributes`). Dans un conteneur où `filter.lfs.smudge` vaut `git-lfs smudge --skip`, chaque checkout ou merge laisse ces fichiers en **pointeurs de 130 octets** : Godot échoue alors à l'import de façon obscure. Lance `git lfs checkout` après chaque changement de branche ou merge, avant d'importer ou de tester. Un fichier non suivi se restaure avec `git lfs smudge < pointeur`.
- Dans un nouveau clone : `git lfs install --local`.

## Godot et GUT

- Après avoir ajouté une `class_name`, lance `godot --headless --import` avant GUT, sinon « Identifier not declared ».
- `-gtest=` de GUT **ajoute** un fichier aux dossiers de `.gutconfig.json` au lieu de filtrer : pour un seul fichier, utilise `-gselect=test_car_alarm`.
- `Script.get_script_constant_map()` ne renvoie que les constantes du script lui-même, pas celles des scripts qu'il étend : `interior_lining_kit.gd` remonte la chaîne avec `get_base_script()`. Pense-y si tu découpes un script en plusieurs fichiers par héritage.
- Le binaire `tilleuls.scn` change à chaque génération même sans changement réel (identifiants internes) : pour vérifier qu'un changement du générateur ne change pas la map, compare un vidage des nœuds et de leurs propriétés, pas les octets : `godot --headless tools/dev/dump_scene.tscn -- res://game/maps/tilleuls/tilleuls.scn avant.txt`, puis la même chose après, et `diff`.
- Les `*_atlas_*.png.import` des personnages sont commités avec `valid=false` : le premier `godot --import` les modifie, et c'est ce qui rend les `.glb` chargeables. Si tu remets ces fichiers comme dans le dépôt (`git checkout -- assets/`) après un import, `test_hunted_body` et `test_monster_body` échouent en local (« Can't load dependency ») alors que la CI est verte. Pour réparer : retire la ligne `valid=false` de ces fichiers, efface `.godot/imported/*atlas_*`, relance l'import ; ne commite pas ces `.import`.
- Le générateur de la cité se lance comme une **scène** (`godot --headless tools/godot/build_tilleuls.tscn`), pas avec `-s` : les autoloads doivent être chargés.

## CI et parties en ligne

- Les machines de la CI sont **arm64** : la physique y diffère un peu d'un PC x86. Une IA coincée à un chambranle de porte n'échouait qu'en CI (PR #153, `JambUnstick`).
- Les échecs de `net_match` dépendent de la **graine** (fusibles et objectifs tirés au sort). Pour reproduire : exporter le préréglage Server, lancer l'accueil, puis `net_smoke` et 4 clients `net_match`, 3 ou 4 fois de suite (environ 3 min chacun).
- Robots de `net_match` : `Input.action_press("interact")` ne fait que tenir la touche ; une action ponctuelle (se lever d'un terminal) se pousse avec `player.commands.push`. Le robot monstre doit rester loin des cages, sinon personne ne libère le chassé attrapé.
- Règle de map apprise à la dure : pas de cachette ni de réveil à moins d'1 m d'une porte ou sur un emplacement de fusible (l'objet vole la visée du robot). `tests/test_tilleuls_ruses.gd` le vérifie.
- La charge de la salle (temps de physique) varie de 12 à 30 ms d'une exécution à l'autre sur les machines de la CI : ce n'est pas un signal fiable seul.

## Serveur

- Le serveur de jeu tourne sur un VPS IONOS (`echo404.duckdns.org`, D-016). Le déploiement passe par la CI sur `main` (`tools/server/deploy.sh`). Voir [`tools/server/README.md`](../tools/server/README.md). Ne jamais écrire de clé ou de mot de passe dans le dépôt.
- Le `Caddyfile` installé dans `/etc/caddy` sur le serveur peut être en retard sur celui du dépôt : `deploy.sh` recharge Caddy par son API locale, un redémarrage de la machine perd la route web jusqu'au prochain déploiement.

## Rendu

- **Profondeur inversée, même en Compatibility** (S-024, T-372) : depuis Godot 4.3, le plan proche est à `z = w` dans l'espace de découpe, dans tous les rendus. Pour dessiner les bras à la première personne devant le décor, `viewmodel.gdshader` tire `POSITION.z` vers `POSITION.w`, pas vers `-POSITION.w` (sinon les bras disparaissent, sans erreur).
