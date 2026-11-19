# Tâches — S-022

Bloc de numéros : T-430 à T-449.

- [x] T-430 — Documentation pour tout agent : `AGENTS.md`, `docs/ARCHITECTURE.md`, `docs/MODULES.md`, `docs/PIEGES.md`, règles de travail dans la constitution (D-022)
  - Résultat vérifiable : un agent sans mémoire trouve, depuis `AGENTS.md`, les commandes, les règles, la carte des modules et le guide pour ajouter ou retirer un module
  - Dépend de : —
- [x] T-431 — Corriger les documents périmés : README, section 4 et 6.5 d'ECHO_PROJET.md, commentaire de `project.godot`, statuts des specs
  - Résultat vérifiable : plus aucune contradiction connue entre la doc, les décisions et le code
  - Dépend de : T-430
- [ ] T-432 — `gdformat` et `gdlint` sur `tools/` en CI ; découper `build_tilleuls.gd` et `interior_lining.gd` sous 1 000 lignes
  - Résultat vérifiable : CI verte avec `tools/` contrôlé ; la map régénérée est identique à celle d'avant
  - Dépend de : T-430
- [ ] T-433 — Découper `game_map.gd` : rôle chassé, rôle monstre, partie en ligne, interface du joueur
  - Résultat vérifiable : aucun fichier de plus de 400 lignes, tests GUT et parties en ligne de la CI verts
  - Dépend de : T-432, fusion de S-020 (réseau) et de T-450 (I18N)
- [ ] T-434 — Sortir `NetSession` de `player.gd` et `monster_avatar.gd` (les commandes passent par un relais posé par la partie en ligne)
  - Résultat vérifiable : `grep NetSession game/entities` ne trouve rien ; tests verts
  - Dépend de : T-433

## Compte rendu
- T-430 (19/11/2026) : `AGENTS.md` (lecture, commandes, règles de code et de travail), `docs/ARCHITECTURE.md` (dossiers, entités, chemin d'une partie en solo et en ligne, bruit, map générée, règles de dépendance et dette mesurée), `docs/MODULES.md` (ajouter une entité en 11 étapes, autres modules, retirer un module en 11 étapes), `docs/PIEGES.md`, `tools/dev/module_map.py` (carte des dépendances, tailles, références d'un module), règles 8 à 10 de la constitution 2.6 et D-022. `CLAUDE.md` renvoie à `AGENTS.md`.
- T-431 (19/11/2026) : README (pitch avec la vision normale du monstre de D-008, piste L3 de Maxime ; scène principale ; toutes les touches par rôle ; étapes de la CI ; organisation), ECHO_PROJET.md (section 4 refaite d'après le dépôt réel, chemins des assets en 5.1, rôles de 6.1 et boucle de 6.5 selon S-010 et S-018, ligne de version), commentaire de résolution de `project.godot` (D-011), module `Text` de l'I18N (T-450) décrit dans `AGENTS.md`, `docs/ARCHITECTURE.md` et `docs/MODULES.md`.
