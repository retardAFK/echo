# Module `i18n` : les textes du jeu

Tout texte que le joueur lit (menus, HUD, invites, écran de fin, crédits mis à part) vient d'ici. Le code ne contient jamais une phrase, seulement des **clés** (`HUD_DISTANCE`, `MENU_SOLO`…).

## Les fichiers

| Fichier | Rôle |
|---|---|
| `strings.csv` | Une ligne par texte : `clé,texte français`. Seule source des textes. |
| `text.gd` | Classe `Text`, la **seule porte d'entrée** : le reste du jeu ne parle jamais à `TranslationServer` ni à `tr()`. |
| `strings.fr.translation` | Généré par Godot à l'import du CSV (ignoré par Git). |
| `tests/test_i18n_keys.gd` | Vérifie les clés (voir plus bas). |

Le CSV est déclaré dans `project.godot` (`internationalization/locale/translations`), langue de repli `fr`.

## Utiliser un texte (API de `Text`)

```gdscript
Text.t("MENU_SOLO")                        # "Jouer seul"
Text.t("HUD_DISTANCE", 12)                 # "12 m"        (remplit %d / %s)
Text.t("END_FUSES", [2, 3])                # plusieurs valeurs : un tableau
Text.count("HUD_CARRY_BOTTLES", n)         # "1 bouteille" / "3 bouteilles"
Text.with_keys("HUD_INTERACT_HIDE")        # "Maintenir F : se cacher" ({interact} -> touche choisie)
Text.decimal(1.25)                         # "1,25"
```

- **Pluriel** : `Text.count("CLE", n)` lit `CLE_ONE` ou `CLE_MANY` selon `n` (en français, 0 et 1 sont au singulier). Les deux lignes doivent exister.
- **Touches** : `{move}`, `{interact}`, `{map}`… dans un texte sont remplacés par le nom de la touche choisie (clavier AZERTY ou QWERTY), via `Settings.fill`. Les noms des touches spéciales sont eux-mêmes des clés `KEY_*`.
- **Scènes** : un `Label` ou un `Button` d'une scène `.tscn` peut contenir directement une clé dans `text` ; Godot la traduit tout seul (traduction automatique). Dans le code, on passe toujours par `Text`.

## Règle d'étages

- Les **entités et les règles** (`game/entities`, `game/session`) renvoient des **clés** ou des nombres, jamais une phrase. Exemple : une porte renvoie `"HUD_INTERACT_DOOR_OPEN"` depuis `get_prompt()`, un bâtiment expose `display_key`.
- L'**interface** (`game/ui`) transforme ces clés en texte avec `Text`. Exemples : `InteractPrompt`, `ScanReticle.building_name()`, `RunSummary`.
- Seule exception : un panneau 3D qui appartient à l'entité elle-même (l'étiquette du transformateur) appelle `Text` directement.

## Ajouter un texte

1. Choisir une clé en anglais, en majuscules, préfixée par sa famille : `HUD_`, `MENU_`, `LOBBY_`, `OPTIONS_`, `MAP_`, `END_`, `NET_`, `KEY_`…
2. Ajouter la ligne `CLE,Texte français` dans `strings.csv` (guillemets si le texte contient une virgule : `CLE,"Un, deux"`). Pour un `%` littéral, écrire `%%`.
3. L'afficher avec `Text.t("CLE")` (ou `count` / `with_keys`).
4. Lancer les tests : `test_i18n_keys.gd` échoue si la clé manque ou si une ligne ne sert à rien.

## Renommer ou retirer un texte

- **Renommer** : changer la clé dans `strings.csv` **et** partout où elle apparaît (`grep -rn ANCIENNE_CLE game tools tests`), y compris dans les scènes et ressources (`.tscn`, `.tres`) et dans les scripts de génération de `tools/godot/`.
- **Retirer** : supprimer l'appel, puis la ligne du CSV. Le test signale une ligne devenue inutile.

## Clés fabriquées

Quelques clés sont assemblées à partir d'un préfixe ; le test les accepte tant que le préfixe apparaît dans le code :

| Préfixe | Où | Complété par |
|---|---|---|
| `TIP_HUNTED_` / `TIP_MONSTER_` | `ui/loading_screen.gd` | `1`, `2`… ou `FIRST_1`… |
| `MAP_OBJECTIVE_` | `ui/map_screen.gd` | nom de `LoopRules.Objective` |
| `OPTIONS_CHOICE_` | `ui/menu/option_row.gd` | valeur de `UserSettings.CHOICES` |

Ajouter un objectif ou un choix d'option demande donc sa ligne dans le CSV (le test `test_built_keys_exist` le vérifie).

## Ce que vérifie le test

- chaque ligne du CSV a un texte français, et aucune clé n'est écrite deux fois ;
- chaque chaîne `"FAMILLE_..."` du code (`game/`, `tools/`) existe dans le CSV ;
- chaque ligne du CSV est utilisée ;
- aucun script de `game/` n'appelle `tr()` ou `TranslationServer` à part `text.gd`.

## Ajouter une langue (plus tard, question Q-011)

1. Ajouter une colonne au CSV (`keys,fr,en`) ; Godot génère `strings.en.translation`, à déclarer dans `project.godot`.
2. Ou passer aux fichiers PO (vrais pluriels, notes pour traducteur) : seul `text.gd` change.
3. Ajouter le choix de la langue dans les options (`TranslationServer.set_locale`, à placer dans `text.gd`).

## Retirer le module

Ce module ne se retire pas : toute l'interface en dépend. On peut en revanche remplacer son contenu (autre format de fichier, autre moteur de traduction) en ne touchant qu'à `text.gd`, puisque c'est la seule porte d'entrée.
