# Écho

Chasse à l'homme asymétrique dans des espaces liminaux : un monstre contre trois chassés, de nuit, dans une cité HLM. Le monstre voit normalement, mais chaque bruit des chassés lui donne leur position et leur distance (D-008). Les chassés n'ont que leur ruse et l'environnement pour le tromper.

On y joue dans le navigateur, seul contre l'IA ou en ligne entre amis (2 à 4 joueurs, avec un code de partie).

Le document de référence est [`ECHO_PROJET.md`](ECHO_PROJET.md) : vision, constitution, méthode, feuille de route. Lis-le avant toute contribution.

Un agent IA (Claude, Codex, Cursor, Gemini…) commence par [`AGENTS.md`](AGENTS.md). La carte du code est dans [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md), et la façon d'ajouter ou de retirer un module dans [`docs/MODULES.md`](docs/MODULES.md).

## Prérequis

- [Godot 4.7](https://godotengine.org/download), version standard (pas .NET). La CI utilise la 4.7.2.
- [Blender](https://www.blender.org/download/), version stable
- [Git](https://git-scm.com/) et [Git LFS](https://git-lfs.com/)

## Récupérer le projet

```bash
git lfs install
git clone https://github.com/retardAFK/echo.git
```

`git lfs install` ne se fait qu'une fois par machine. Les fichiers lourds (`.blend`, textures, audio, `.glb`) passent par Git LFS (voir `.gitattributes`).

## Lancer le jeu

1. Ouvre Godot, clique sur **Importer**, choisis le fichier `project.godot` à la racine du dépôt.
2. Appuie sur **F5** pour lancer la scène principale : l'écran d'accueil (`game/ui/start_menu.tscn`).

### Commandes

Touches par défaut, réglables dans **Options › Contrôles**. Le jeu les rappelle après le choix du rôle et dans la pause.

| Action | Chassé | Monstre |
|---|---|---|
| Se déplacer | ZQSD (AZERTY) ou WASD (QWERTY), ou les flèches | pareil |
| Regarder | Souris (clic dans le jeu pour la capturer) | pareil |
| Courir (bruyant) | Maj (maintenir) | Maj |
| S'accroupir / rôder | C | C (rôder en silence) |
| Interagir | E ; maintenir E pour un fusible, une cachette, un terminal | maintenir E pour ouvrir une cachette |
| Lancer une bouteille / poser un réveil | clic gauche / clic droit | — |
| Scanner un bâtiment | — | maintenir clic droit en le visant |
| Carte du quartier | Tab | — |
| Pause | Échap | Échap |
| Plein écran | F11 | F11 |
| Debug : images par seconde, cercles de bruit | F3, F4 | F3, F4 |

Le projet utilise le moteur de rendu **Compatibility**, le seul accepté par l'export web.

## Exporter pour le navigateur

1. Dans Godot : **Éditeur → Gérer les modèles d'exportation → Télécharger et installer**.
2. **Projet → Exporter…** : le preset **Web** est déjà configuré (`export_presets.cfg`), sortie `build/web/index.html`.
3. Clique sur **Exporter le projet**.
4. Le dossier `build/` est ignoré par Git. Pour tester, lance un petit serveur local :

```bash
cd build/web
python -m http.server 8000
```

puis ouvre <http://localhost:8000> dans Chrome. Ouvrir `index.html` directement par double-clic ne fonctionne pas.

## Tests et qualité

Les tests utilisent [GUT](https://github.com/bitwes/Gut) 9.7.1. GUT n'est pas versionné dans le dépôt : installe-le une fois dans Godot via l'onglet **AssetLib** (recherche « GUT », installe dans `addons/gut/`), puis active-le dans **Projet → Paramètres du projet → Extensions**. Les tests sont dans `tests/`, un fichier `test_*.gd` par sujet, configurés par `.gutconfig.json`.

En ligne de commande :

```bash
godot --headless --import
godot --headless -s addons/gut/gut_cmdln.gd
```

Le style GDScript est vérifié par [gdtoolkit](https://github.com/Scony/godot-gdscript-toolkit) :

```bash
pip install gdtoolkit==4.5.0
gdformat game tests   # reformate
gdlint game tests     # vérifie
```

## Intégration continue

Chaque pull request et chaque push sur `main` lancent `.github/workflows/ci.yml` :

1. **lint** : `gdformat --check` et `gdlint` sur `game/` et `tests/`.
2. **godot** : import headless du projet, tests GUT, export Web et contrôle du budget de 60 Mo (constitution 2.2), export du serveur, puis une vraie partie en ligne jouée par 4 robots et un spectateur.
3. Sur `main` seulement : déploiement du serveur (`echo404.duckdns.org`) et publication du build de test sur itch.io.

Le build Web et les résultats de tests sont téléchargeables dans l'onglet **Actions** de chaque exécution. Une PR ne se fusionne que si la CI est verte.

## Organisation

Voir [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md). En bref : `specs/` pour les spécifications, `game/` pour tout ce que Godot charge, `assets/` pour les modèles, textures, sons et sources Blender (Git LFS), `tools/` pour les scripts qui fabriquent les assets et la map, `tests/` pour les tests GUT, `docs/` pour la documentation technique. Le serveur en ligne est décrit dans [`tools/server/README.md`](tools/server/README.md).
