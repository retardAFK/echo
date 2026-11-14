# Crédits

Liste de tous les assets externes utilisés dans Écho (règle 2.7 de `ECHO_PROJET.md`).
Seuls les assets faits par nous ou sous licence **CC0** sont acceptés.

| Asset | Auteur | Licence | Lien | Utilisé dans |
|---|---|---|---|---|
| Universal Base Characters (corps et squelette des chassés, cheveux) | Quaternius | CC0 | https://quaternius.com | Chassés et chasseur, `assets/models/hunted/` et `assets/models/hunter/` (S-011, T-122, T-124), sources dans `art_src/quaternius_ubc/`, adaptés par `tools/blender/hunted.py` et `tools/blender/hunter.py` |

## Assets faits par nous

| Asset | Fabrication | Utilisé dans |
|---|---|---|
| Sons d'ambiance (vent, autoroute, train, balançoire), `assets/audio/ambience/` | Bruit filtré, synthétisé par `tools/audio/ambience.py` | Cité des Tilleuls (S-006, T-050) |
| Sons de la boucle de partie (boîtier à fusible, étincelles, ronflement du transformateur, sirène), `assets/audio/loop/` | Bruit filtré et oscillateurs, synthétisés par `tools/audio/loop_sounds.py` | Boucle de partie (S-007, T-059) |
| Sons des ruses (bouteille brisée, tic-tac et sonnerie du réveil, réveil écrasé, porte de casier, couvercle de benne), `assets/audio/ruses/` | Bruit filtré et oscillateurs, synthétisés par `tools/audio/ruse_sounds.py` | Ruses et attracteurs (S-008, T-070) |

## Outils de développement

Non inclus dans le jeu exporté.

| Outil | Auteur | Licence | Lien |
|---|---|---|---|
| GUT 9.7.1 | Butch Wesley | MIT | https://github.com/bitwes/Gut |
| gdtoolkit 4.5.0 | Pawel Lampe | MIT | https://github.com/Scony/godot-gdscript-toolkit |
