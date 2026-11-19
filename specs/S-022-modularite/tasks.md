# Tâches — S-022

Bloc de numéros : T-430 à T-449.

- [x] T-430 — Documentation pour tout agent : `AGENTS.md`, `docs/ARCHITECTURE.md`, `docs/MODULES.md`, `docs/PIEGES.md`, règles de travail dans la constitution (D-022)
  - Résultat vérifiable : un agent sans mémoire trouve, depuis `AGENTS.md`, les commandes, les règles, la carte des modules et le guide pour ajouter ou retirer un module
  - Dépend de : —
- [x] T-431 — Corriger les documents périmés : README, section 4 et 6.5 d'ECHO_PROJET.md, commentaire de `project.godot`, statuts des specs
  - Résultat vérifiable : plus aucune contradiction connue entre la doc, les décisions et le code
  - Dépend de : T-430
- [x] T-432 — `gdformat` et `gdlint` sur `tools/` en CI ; découper `build_tilleuls.gd` et `interior_lining.gd` sous 1 000 lignes
  - Résultat vérifiable : CI verte avec `tools/` contrôlé ; la map régénérée est identique à celle d'avant
  - Dépend de : T-430
- [x] T-433 — Découper `game_map.gd` : rôle chassé, rôle monstre, partie en ligne, interface du joueur
  - Résultat vérifiable : aucun fichier de plus de 400 lignes, tests GUT et parties en ligne de la CI verts
  - Dépend de : T-432, fusion de S-020 (réseau) et de T-450 (I18N)
- [ ] T-434 — Sortir `NetSession` de `player.gd` et `monster_avatar.gd` (les commandes passent par un relais posé par la partie en ligne)
  - Résultat vérifiable : `grep NetSession game/entities` ne trouve rien ; tests verts
  - Dépend de : T-433

## Compte rendu
- T-430 (19/11/2026) : `AGENTS.md` (lecture, commandes, règles de code et de travail), `docs/ARCHITECTURE.md` (dossiers, entités, chemin d'une partie en solo et en ligne, bruit, map générée, règles de dépendance et dette mesurée), `docs/MODULES.md` (ajouter une entité en 11 étapes, autres modules, retirer un module en 11 étapes), `docs/PIEGES.md`, `tools/dev/module_map.py` (carte des dépendances, tailles, références d'un module), règles 8 à 10 de la constitution 2.6 et D-022. `CLAUDE.md` renvoie à `AGENTS.md`.
- T-431 (19/11/2026) : README (pitch avec la vision normale du monstre de D-008, piste L3 de Maxime ; scène principale ; toutes les touches par rôle ; étapes de la CI ; organisation), ECHO_PROJET.md (section 4 refaite d'après le dépôt réel, chemins des assets en 5.1, rôles de 6.1 et boucle de 6.5 selon S-010 et S-018, ligne de version), commentaire de résolution de `project.godot` (D-011), module `Text` de l'I18N (T-450) décrit dans `AGENTS.md`, `docs/ARCHITECTURE.md` et `docs/MODULES.md`.
- T-432 (19/11/2026) : `gdformat` et `gdlint` contrôlent aussi `tools/` en CI (6 fichiers reformatés, définitions remises dans l'ordre). Le générateur de la cité (2 233 lignes, 3 106 une fois formaté) est découpé en une chaîne de 5 fichiers par héritage : `tilleuls_layout.gd` (positions), `tilleuls_base.gd` (aides), `tilleuls_tower.gd`, `tilleuls_places.gd`, `build_tilleuls.gd` ; le revêtement intérieur (1 342 lignes) en 3 (`interior_lining_kit.gd`, `interior_lining_rooms.gd`, `interior_lining.gd`). Aucun fichier au-dessus de 1 000 lignes. `build_map_plan.gd` lit directement `tilleuls_layout.gd`. Vérifié : la cité regénérée a le même vidage complet (`tools/dev/dump_scene.tscn`, nœuds, propriétés et scripts) que la scène commitée, le maillage de navigation et les sols sont identiques à l'octet, le plan de la carte aussi ; 801 tests GUT sur 802 verts, le dernier « risky » comme avant. Un bug trouvé en route : `get_script_constant_map()` ne voit pas les constantes héritées, corrigé dans `interior_lining_kit.gd` et noté dans `docs/PIEGES.md`.
- T-433 (19/11/2026) : `game_map.gd` (924 lignes) découpé par composition. `GameMap` (268 lignes) garde l'état partagé (joueur, monstre, avatar, proie, réseau, prison, tirage), la boucle, la pause et les recherches dans la map ; une partie par façon de jouer, ajoutée comme nœud enfant dans `_ready` : `MapHuntedRole` (solo chassé, 57), `MapMonsterRole` (solo monstre et simulations, 183), `MapOnlineRoom` (salle en ligne : places, IA des places vides, capture, prison, départs et retours, 371), `MapOnlineClient` (écran d'un joueur en ligne, 115), et `HuntedHuds` (HUD du chassé, solo et en ligne, 66). Une partie n'appelle jamais une autre. Les tests et outils appellent maintenant `map.room.catch_hunted`, `map.room.jail`, `map.monster_role.add_ai_preys`, `map.monster_role.play_ai_against_ai`. Vérifié : 859 tests GUT sur 860 verts (le dernier « risky » comme avant), une partie simulée à 3 proies jouée jusqu'au bout ; la CI joue les parties en ligne.
