# Écho

Chasse à l'homme asymétrique dans des espaces liminaux, où le monstre est aveugle et ne perçoit le monde que par le son.

Le document de référence est [`ECHO_PROJET.md`](ECHO_PROJET.md) : vision, constitution, méthode, feuille de route. Lis-le avant toute contribution.

## Prérequis

- [Godot 4](https://godotengine.org/download), dernière version stable (version standard, pas .NET)
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
2. **Projet → Exporter… → Ajouter… → Web**, chemin de sortie `build/web/index.html`.
3. Clique sur **Exporter le projet**.
4. Le dossier `build/` est ignoré par Git. Pour tester, lance un petit serveur local :

```bash
cd build/web
python -m http.server 8000
```

puis ouvre <http://localhost:8000> dans Chrome. Ouvrir `index.html` directement par double-clic ne fonctionne pas.

## Organisation

Voir la section 4 de `ECHO_PROJET.md`. En bref : `specs/` pour les spécifications, `game/` pour tout ce que Godot charge, `art_src/` pour les sources Blender, `tools/blender/` pour les scripts de génération, `tests/` pour les tests GUT.
