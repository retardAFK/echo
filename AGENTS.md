# AGENTS.md — lire avant toute action

> Point d'entrée de **tout agent de code** (Claude Code, Codex, Cursor, Gemini, Copilot…) et de toute personne qui reprend le projet.
> `CLAUDE.md` renvoie ici. Mis à jour le 19/11/2026 (spec S-022, T-430).

**Écho** est un jeu de chasse à l'homme asymétrique (1 monstre contre 3 chassés), en **Godot 4.7, GDScript seul**, rendu **Compatibility**, joué **dans le navigateur** et en ligne via un serveur dédié. Tout le jeu est écrit par des agents IA sous la direction de Maxime, le porteur du projet, qui n'est pas développeur.

## Quoi lire, dans quel ordre

1. [`ECHO_PROJET.md`](ECHO_PROJET.md) : vision, **constitution** (section 2, règles non négociables), méthode, feuille de route, **journal des décisions** (section 10). Si une décision n'y est pas écrite, elle n'est pas prise.
2. [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) : la carte du code, les dossiers, le chemin d'une partie, les règles de dépendance et la dette connue.
3. [`docs/MODULES.md`](docs/MODULES.md) : comment **ajouter ou retirer** une entité, un réglage, un écran, un son, un objectif, une synchronisation en ligne.
4. [`docs/PIEGES.md`](docs/PIEGES.md) : les erreurs déjà faites (export web, LFS, audio web, CI).
5. La spec de ta tâche : `specs/S-xxx-*/spec.md`, `plan.md`, `tasks.md`, et [`specs/BACKLOG.md`](specs/BACKLOG.md) pour les numéros de tâches.

Ne lis pas tout le code : il fait environ 19 000 lignes dans `game/`. Pars de la carte, puis de `python3 tools/dev/module_map.py --refs <Classe>`.

## Commandes

Versions : Godot **4.7.2** (standard, pas .NET), GUT **9.7.1**, gdtoolkit **4.5.0**, Git LFS.

```bash
git lfs install --local && git lfs pull          # les assets sont en LFS (voir docs/PIEGES.md)
pip install gdtoolkit==4.5.0
git clone --depth 1 --branch v9.7.1 https://github.com/bitwes/Gut.git /tmp/gut \
  && mkdir -p addons && cp -r /tmp/gut/addons/gut addons/gut    # GUT n'est pas versionné

gdformat --check game tests tools  # format (gdformat game tests tools pour corriger)
gdlint game tests tools            # lint
godot --headless --import          # import, obligatoire après une nouvelle class_name
godot --headless -s addons/gut/gut_cmdln.gd                       # tous les tests
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_car_alarm   # un fichier (-gtest ajoute, ne filtre pas)

godot --headless tools/godot/build_tilleuls.tscn     # regénère la cité (puis commiter .scn et navmesh)
godot --headless res://tools/godot/build_versus_arena.tscn   # regénère l'arène Versus de la cité (après la cité)
godot --headless res://tools/godot/simulate_games.tscn   # parties IA contre IA en accéléré
python3 tools/dev/module_map.py [--sizes | --refs Classe]   # carte des modules
```

La CI (`.github/workflows/ci.yml`) fait tout cela, plus l'export web (budget de 60 Mo), l'export du serveur et une vraie partie en ligne à 4 robots. Une PR ne fusionne que si elle est verte.

## Règles de code (résumé de la constitution 2.4)

- Une scène par entité, avec un script du même nom, dans `game/entities/<nom>/`. Fichiers en `snake_case`, classes en `PascalCase`, constantes en `MAJUSCULES`.
- **Aucun chiffre magique** : les valeurs de gameplay vivent dans `game/data/*_settings.tres`.
- Les entités communiquent par **signaux** et **groupes**, jamais par chemin de nœud absolu.
- Tout bruit passe par l'autoload **`NoiseBus`**. Un nouveau type de bruit va **à la fin** de `NoiseEvent.Type`.
- La logique testable sans affichage vit dans une classe `RefCounted` pure (`*_brain`, `*_rules`, `*_math`) et a des **tests GUT**.
- Code, noms et commentaires **en anglais** ; textes affichés **en français**, par des clés de `game/i18n/strings.csv` lues avec la classe `Text` (jamais `tr()` directement ; guide : `game/i18n/README.md`).
- Chaque script commence par un commentaire `##` qui dit ce qu'il fait et cite sa spec et sa tâche (`spec S-018, Q11`, `T-263`). Garde cette habitude : c'est ce qui relie le code aux décisions.
- La cité (`game/maps/tilleuls/tilleuls.scn`) est **générée** par `tools/godot/build_tilleuls.gd` : ne l'édite jamais à la main.
- Budgets (constitution 2.2) : 60 images/s, 300 appels de dessin (la cité est déjà près de la limite), 60 Mo de build web.
- Assets : CC0 seulement (polices : OFL), notés dans `CREDITS.md`, modèles faits par scripts dans `tools/blender/`, sons par scripts dans `tools/audio/`.

## Règles de travail

- **Git** (constitution 2.5) : jamais de push sur `main`. Une branche et une PR par tâche, commits `T-xxx: description en français`. Fusion en squash.
- **Méthode** (constitution 3) : pas de code sans tâche `T-xxx` d'une spec validée. Si la spec est floue, demande à Maxime avant d'inventer un comportement de jeu.
- **Autonomie sur les PR** (règle de Maxime du 30/10/2026, D-022) : l'agent relit et fusionne **lui-même** ses propres PR, une fois **tous** les contrôles de la CI verts. Jamais de fusion avec un contrôle rouge, jamais de test désactivé pour passer.
- **Vérification** (règle de Maxime du 10/11/2026, D-022) : ne demande pas à Maxime de tester. Vérifie toi-même (GUT, simulations, captures, build web) et passe à la suite. Seuls les **choix de style** (modèles, sons, plans) et les **décisions de jeu** lui sont montrés.
- **Langue** : Maxime parle français. Écris-lui en français simple, sans jargon.
- **Doc à jour** : une PR qui change une règle, un module ou une commande met à jour, dans la même PR, la spec, `docs/ARCHITECTURE.md` ou `docs/MODULES.md`. Une nouvelle erreur coûteuse va dans `docs/PIEGES.md`. Une nouvelle décision va dans ECHO_PROJET.md section 10.
- **Plusieurs agents en parallèle** : chaque spec a un **bloc de numéros de tâches** (`specs/BACKLOG.md`). Prends le premier numéro libre de ton bloc, jamais celui d'un autre.
- **Secrets** : aucune clé, aucun mot de passe dans le dépôt. Les secrets du déploiement sont dans les réglages GitHub.
