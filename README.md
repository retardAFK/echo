# Écho

Chasse à l'homme asymétrique dans des espaces liminaux, où le monstre est aveugle et ne perçoit le monde que par le son.

Le document de référence est [`ECHO_PROJET.md`](ECHO_PROJET.md) : vision, constitution, méthode, feuille de route. Lis-le avant toute contribution.

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
2. Appuie sur **F5** pour lancer la scène principale (`game/maps/main.tscn`).

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
2. **godot** : import headless du projet, tests GUT, export Web, et contrôle du budget de 60 Mo (constitution 2.2).

Le build Web et les résultats de tests sont téléchargeables dans l'onglet **Actions** de chaque exécution. Une PR ne se fusionne que si la CI est verte.

## Organisation

Voir la section 4 de `ECHO_PROJET.md`. En bref : `specs/` pour les spécifications, `game/` pour tout ce que Godot charge, `art_src/` pour les sources Blender, `tools/blender/` pour les scripts de génération, `tests/` pour les tests GUT.
