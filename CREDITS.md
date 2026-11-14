# Crédits

Liste de tous les assets externes utilisés dans Écho (règle 2.7 de `ECHO_PROJET.md`).
Seuls les assets faits par nous ou sous licence **CC0** sont acceptés, plus la licence **SIL OFL** pour les polices (D-017).

| Asset | Auteur | Licence | Lien | Utilisé dans |
|---|---|---|---|---|
| Universal Base Characters (corps et squelette des chassés, cheveux) | Quaternius | CC0 | https://quaternius.com | Chassés et chasseur, `assets/models/hunted/` et `assets/models/hunter/` (S-011, T-122, T-124), sources dans `art_src/quaternius_ubc/`, adaptés par `tools/blender/hunted.py` et `tools/blender/hunter.py` |
| Barlow et Barlow Condensed (polices des menus) | Jeremy Tribby, The Barlow Project Authors | SIL OFL 1.1 (`assets/fonts/OFL-Barlow.txt`) | https://github.com/jpt/barlow | Menus, `assets/fonts/` (S-013, T-162) |
| VT323 (afficheur du digicode) | Peter Hull, The VT323 Project Authors | SIL OFL 1.1 (`assets/fonts/OFL-VT323.txt`) | https://github.com/phoikoi/VT323 | Menu en ligne, `assets/fonts/` (S-013) |

## Assets faits par nous

| Asset | Fabrication | Utilisé dans |
|---|---|---|
| Sons d'ambiance (vent, autoroute, train, balançoire), `assets/audio/ambience/` | Bruit filtré, synthétisé par `tools/audio/ambience.py` | Cité des Tilleuls (S-006, T-050) |
| Sons de la boucle de partie (boîtier à fusible, étincelles, ronflement du transformateur, sirène), `assets/audio/loop/` | Bruit filtré et oscillateurs, synthétisés par `tools/audio/loop_sounds.py` | Boucle de partie (S-007, T-059) |
| Sons des ruses (bouteille brisée, tic-tac et sonnerie du réveil, réveil écrasé, porte de casier, couvercle de benne), `assets/audio/ruses/` | Bruit filtré et oscillateurs, synthétisés par `tools/audio/ruse_sounds.py` | Ruses et attracteurs (S-008, T-070) |
| Fonds des menus, `assets/textures/ui/` | Vues de la cité des Tilleuls capturées dans le jeu et étalonnées par `tools/godot/capture_menu_backgrounds.gd` | Menus (S-013, T-162) |

## Outils de développement

Non inclus dans le jeu exporté.

| Outil | Auteur | Licence | Lien |
|---|---|---|---|
| GUT 9.7.1 | Butch Wesley | MIT | https://github.com/bitwes/Gut |
| gdtoolkit 4.5.0 | Pawel Lampe | MIT | https://github.com/Scony/godot-gdscript-toolkit |
