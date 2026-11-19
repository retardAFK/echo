# S-022 — Modularité et reprise du code par un autre LLM

**Statut** : livrée (19/11/2026)
**Piliers servis** : aucun directement. Cette spec sert la constitution (sections 2.4 et 2.6) : garder le jeu maintenable pendant les 30 à 40 semaines du projet.
**Phase** : hors feuille de route, demandée par Maxime le 19/11/2026 (« j'aimerais que tu sois le plus modulaire possible, que le code soit le plus compréhensible pour un autre LLM, que tout soit documenté, et surtout la doc de comment retirer et rajouter un module »).

## Pourquoi
Tout le jeu est écrit par Claude, vite (19 specs en trois semaines). Un audit du 19/11/2026 a montré que les briques de base sont propres (petites fonctions, service de bruit central, réglages dans `game/data/`, 802 tests GUT), mais que l'assemblage a grossi sans plan, et que des règles et des pièges importants n'existent que dans la mémoire de Claude. Un autre agent, ou Claude dans une session sans mémoire, devrait les redécouvrir.

## Ce que vit le joueur
Rien ne change pour le joueur. Ce que vit **la personne ou l'agent qui reprend le code** :
- Il ouvre `AGENTS.md` (lu par Codex, Cursor, Gemini, Copilot…) ou `CLAUDE.md` et sait en une page quoi lire, quelles commandes lancer, et quelles règles suivre.
- Il trouve dans `docs/ARCHITECTURE.md` la carte des modules, qui dépend de qui, et le chemin d'une partie (menu, map, solo, en ligne).
- Il suit `docs/MODULES.md` pour ajouter ou retirer un module, avec la liste de tous les endroits à toucher et la commande qui les trouve.
- Il lit dans `docs/PIEGES.md` les erreurs déjà faites, pour ne pas les refaire.
- La CI vérifie aussi les outils (`tools/`), pas seulement `game/` et `tests/`.
- Ajouter ou retirer une fonctionnalité ne demande plus de toucher un fichier de 900 lignes qui fait tout.

## Critères d'acceptation
- [x] `AGENTS.md` existe à la racine et `CLAUDE.md` y renvoie ; les règles de travail de Maxime (autonomie sur les PR, pas de demande de playtest) y sont écrites.
- [x] `docs/ARCHITECTURE.md` décrit tous les dossiers de `game/` et `tools/`, les autoloads et les règles de dépendance.
- [x] `docs/MODULES.md` explique pas à pas comment ajouter et comment retirer une entité, un réglage, un écran, un son, un objectif et une synchronisation en ligne.
- [x] `docs/PIEGES.md` reprend les pièges connus (export web, LFS, audio web, CI arm64, robots de `net_match`).
- [x] La section 4 d'ECHO_PROJET.md, le README et `project.godot` ne contredisent plus le code ni les décisions.
- [x] `gdformat --check` et `gdlint` passent sur `tools/` en CI, sans changer la map générée.
- [x] `game_map.gd` est découpé en morceaux de moins de 400 lignes, chacun avec un rôle clair, sans changer le jeu (tests GUT et parties en ligne de la CI verts).
- [x] Le joueur et le monstre jouable ne lisent plus `NetSession` eux-mêmes.

## Hors périmètre
- L'I18N : traitée par sa propre tâche (T-450, `game/i18n/README.md`), à laquelle `docs/MODULES.md` renvoie.
- Le réseau (S-020) : on attend sa fusion avant de toucher `game_map.gd` et `game/net/`.
- Changer le gameplay, les réglages ou la map.

## Clarifications
- Q : Faut-il écrire la doc en anglais pour les LLM ? → R : non. Le code reste en anglais (constitution 2.4), les documents en français comme le reste du projet ; tous les LLM courants lisent le français (choix de Claude, 19/11/2026).
- Q : Ordre de travail ? → R : documentation d'abord, puis le lint des outils, puis le découpage de `game_map.gd` et du réseau du joueur, après la fusion des travaux réseau et I18N (Maxime et le coordinateur, 19/11/2026).
