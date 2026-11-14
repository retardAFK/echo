# Plan — S-013

**Statut** : établi par Claude (14/11/2026) à partir de la spec validée (style A, « Sodium et digicode »)

## Le style A en règles
- **Base** : 640 × 360, agrandie par Godot (`canvas_items`, facteur entier). Les polices sont redessinées à la taille finale, donc nettes sur tous les écrans.
- **Couleurs** : noir chaud `#0b0a08`, crème `#efe6cc` (titres), beige `#d8d0bb` (texte), gris chaud `#7d7768` (texte secondaire, entrées désactivées), **ocre sodium `#ddb45a`** (sélection, code, voyants). Jamais l'orange du bruit (`NoiseSettings.noise_color`) ; un test le vérifie sur le thème.
- **Polices** (libres, OFL) : *Barlow Condensed* SemiBold et ExtraBold pour les titres et les menus, *Barlow* Medium pour les textes courts, *VT323* pour l'afficheur du digicode. Rangées dans `assets/fonts/`, notées dans `CREDITS.md`.
- **Menus** : listes alignées à gauche, en capitales espacées. L'entrée choisie est un bandeau ocre au texte noir, précédée d'un petit carré. Le survol à la souris donne le focus, donc une seule entrée est en surbrillance, que l'on joue au clavier ou à la souris.
- **Fonds** : vues de la cité capturées dans le jeu, passées en gris, éclaircies et teintées d'ocre, sous un dégradé noir à gauche pour que le texte reste lisible.

## Le thème commun
- `game/ui/theme/echo_theme.tres` : un seul `Theme` Godot (polices, tailles, styles des boutons, champs, onglets, curseurs, panneaux). Il est **généré** par `tools/godot/build_menu_theme.gd` à partir de `game/ui/theme/menu_style.gd` (les couleurs et tailles du style A, en constantes nommées), pour qu'une couleur se change à un seul endroit et que le fichier reste reproductible.
- Les écrans de menu posent ce thème sur leur nœud racine (`theme = …`). Le HUD n'est pas touché (T-165).
- Variantes de thème nommées : `MenuItem` (entrée de menu), `TitleLabel`, `HeadingLabel`, `HintLabel`, `NameTag` (étiquette d'interphone), `Lamp` (voyant), `DigicodeKey`, `DigicodeDisplay`.

## Les briques
- **`MenuBackdrop`** (`game/ui/menu/menu_backdrop.tscn`) : le fond (image + dégradé), le titre et la ligne d'aide du bas (« Entrée : valider · Échap : retour »). Chaque écran l'instancie et choisit son image par une propriété de la racine (jamais par une surcharge d'un enfant d'instance, voir PR #31).
- **`MenuList`** (`game/ui/menu/menu_list.gd`) : une `VBoxContainer` qui crée ses entrées à partir de clés de traduction, relie le survol au focus, garde le focus à l'intérieur (haut et bas bouclent) et émet `chosen(key)`. Échap émet `back`.
- **`Digicode`** (`game/ui/menu/digicode.tscn`) : l'afficheur et les touches des 22 lettres de `RoomCode.LETTERS`, plus « effacer » et « valider ». On peut taper au clavier physique (les lettres hors code sont ignorées), Retour arrière efface, Entrée valide. Émet `submitted(code)`.
- **`Intercom`** (`game/ui/menu/intercom.tscn`) : le panneau d'interphone, une ligne par place (rôle, étiquette avec le nom, voyant allumé quand le joueur est prêt). Une ligne est un bouton quand on peut prendre ou échanger la place. Il ne fait qu'afficher un `LobbyState` : la logique de `LobbyMenu` (créer, rejoindre, prêt, lancer, erreurs) ne change pas et ses tests restent valables.

## Les écrans
| Écran | Fichier | Change |
|---|---|---|
| Accueil | `start_menu.tscn` | Refait : Jouer seul, Jouer en ligne, Options, Crédits ; « Jouer seul » ouvre le choix du rôle puis l'objectif et les commandes |
| Jouer en ligne, salon | `lobby_menu.tscn` | La construction dans le code est remplacée par une scène : liste Créer / Rejoindre / Retour avec le digicode, puis le salon avec le code en grand et l'interphone |
| Pause | `pause_menu.tscn` | Bandeau sur toute la largeur, Reprendre / Options / Revenir au menu, commandes du rôle à droite ; en ligne le jeu continue et les commandes du joueur sont neutres tant que la pause est ouverte |
| Options | `options_menu.tscn` | Nouveau, ouvert depuis l'accueil et la pause |
| Crédits | `credits_menu.tscn` | Nouveau, lit `CREDITS.md` |

## Les réglages (Q4, Q5)
- **`UserSettings`** (`game/settings/user_settings.gd`, autoload `Settings`) : les valeurs, leurs bornes et leurs défauts dans une ressource `game/data/user_settings_defaults.tres` ; `load()` et `save()` sur `user://settings.cfg` (`ConfigFile`) ; une valeur absente, illisible ou hors bornes reprend son défaut. Émet `changed(key)`.
- **Application** : volumes sur les bus (`default_bus_layout.tres` : Master, Effets, Ambiance, Musique ; les sons existants restent sur Master jusqu'à S-012) ; sensibilité et inversion lues par `LocalControls` ; champ de vision lu par les caméras du joueur et du monstre ; luminosité par l'`Environment` de la map ; qualité du brouillard et des ombres par la map ; touches réécrites dans l'`InputMap` et enregistrées par code physique.
- Testé par GUT : aller-retour des valeurs, valeurs abîmées, bornes, réécriture d'une touche.

## Risques
- **Polices et web** : trois polices, environ 400 Ko en tout ; le build reste loin des 60 Mo.
- **Images de fond** : quatre JPEG de 1280 × 720, environ 50 Ko chacun.
- **Stockage du navigateur** : `user://` est gardé par le navigateur (IndexedDB). En navigation privée il peut être vidé à la fermeture : les réglages reviennent alors aux défauts, sans erreur.
