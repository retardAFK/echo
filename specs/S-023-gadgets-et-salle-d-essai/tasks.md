# Tâches — S-023

Bloc de numéros : T-350 à T-369.

- [x] T-350 — Spec S-023
  - Résultat vérifiable : spec, tâches et ligne du backlog fusionnées ; Q1 tranchée par Maxime
  - Dépend de : —
- [x] T-351 — `GadgetDef` et liste des gadgets dans `game/data/gadgets/` ; pétard, fil, walkman et fumigène passent par elle (joueur, réseau, IA, HUD), sans changer leurs règles
  - Résultat vérifiable : comportement identique (tests existants verts) ; un test parcourt la liste et pose chaque gadget en solo et en ligne
  - Dépend de : T-350
- [x] T-352 — Choix de 2 gadgets (Q2 à Q4) : écran solo, salon, réglage gardé, IA, synchronisation
  - Résultat vérifiable : tests GUT du choix et de son envoi ; le monstre ne reçoit jamais le choix
  - Dépend de : T-351
- [x] T-353 — Touches des gadgets selon Q1 et HUD « gadget » ; F, T, V, B libérées ; options › touches et commandes à jour
  - Résultat vérifiable : tests GUT d'entrée ; capture du HUD
  - Dépend de : T-352
- [x] T-354 — Paliers du monstre (Q5, Q7) : `EscalationStage` dans `game/data/escalation/`, appliqués à chaque objectif, solo et en ligne, monstre joué et IA
  - Résultat vérifiable : tests GUT par palier ; simulation de 20 parties sans blocage
  - Dépend de : T-350
- [x] T-355 — Annonce aux chassés (Q6) : grondement et ligne de HUD ; son montré à Maxime
  - Résultat vérifiable : test GUT de l'annonce ; écoute validée
  - Dépend de : T-354
- [x] T-356 — Salle d'essai (Q8, Q9) : map, postes listés dans `stations.tres`, gadgets à volonté, entrée « Jouer seul › Salle d'essai »
  - Résultat vérifiable : test GUT qui charge chaque poste ; capture
  - Dépend de : T-351
- [x] T-357 — Mannequins de la salle d'essai : monstre sur rail, chassé qui marche et se cache, F6 pour changer de rôle
  - Résultat vérifiable : tests GUT (pétard et fumée sur le mannequin, scan qui entend le mannequin de chassé)
  - Dépend de : T-356
- [ ] T-358 — `docs/MODULES.md` (ajouter ou retirer un gadget, un palier, un poste), `docs/ARCHITECTURE.md`, guide du jeu
  - Résultat vérifiable : un agent suit la doc pour ajouter un gadget factice dans un test
  - Dépend de : T-353, T-355, T-357
- [ ] T-359 — Vérification finale : grille de test (T-317) en simulation, CI en ligne, budget
  - Résultat vérifiable : lignes de la grille ajoutées ; critères de la spec cochés
  - Dépend de : T-358

## Compte rendu
- T-350 (20/11/2026) : spec et tâches écrites après l'audit de game design ; Q1 tranchée par Maxime (touches 1 et 2). PR #229.
- T-351 (20/11/2026) : `GadgetDef` (id, `Inventory.Kind`, scène, clé du HUD) et `GadgetList` (`game/data/gadgets/gadgets.tres`, chargée et non préchargée pour éviter un cycle avec les scripts des gadgets). Chaque gadget se pose lui-même avec `deploy(user)` ; `GadgetUse` (`game/entities/player/gadget_use.gd`) fait l'utilisation et la pose au sol (réveil compris), ce qui garde `player.gd` sous les 20 méthodes publiques. `CarryHud` parcourt la liste. Règles inchangées : 977 tests GUT sur 978 verts (le dernier « risky » comme avant), dont `tests/test_gadgets.gd` qui pose chaque gadget de la liste. Le réseau garde ses 4 compteurs (`you[14..17]`) jusqu'à T-352.
- T-352 (20/11/2026) : `LoadoutSettings` (`game/data/loadout_settings.tres` : 2 emplacements, 2 charges, choix par défaut et de l'IA pétard + fumigène) et `Loadout` (`game/session/loadout.gd`, pur : validation, tour des gadgets, index pour le réseau, `equip` sur l'inventaire). Choix dans « Jouer seul » et dans le salon (`LoadoutItems`, entrées « GADGET 1 : … »), gardé dans les réglages (section `loadout`). En ligne il part avec « prêt » (`ask_ready`, en index de la liste) ; la salle le garde et l'applique au joueur, aucun client ne le reçoit (Q4 précisée : les rôles sont tirés au lancement). Les proies IA prennent `ai_gadgets`. Les anciens `start_`/`max_` des 4 gadgets quittent `RuseSettings`. Tests : `tests/test_loadout.gd`.
- T-353 (20/11/2026) : actions `gadget_1` et `gadget_2` (touches 1 et 2, remappables) à la place de F, T, V et B ; `PlayerCommands` `GADGET_1`/`GADGET_2` ; HUD « Pétard ×2 (1) » par emplacement ; options › touches et aide des commandes à jour. Les tests de chaque gadget passent par les touches et vérifient les 2 charges.
- T-354 (20/11/2026) : `EscalationStage` (`overrides` : réglage de `MonsterSettings` → valeur) et `EscalationList` (`game/data/escalation/escalation.tres`, 3 paliers de Q5). `LoopRules.done_count()` compte chaque fusible posé et chaque autre objectif réussi ; `MonsterEscalation`, enfant de `GameLoop` sur toutes les machines, donne le palier atteint à chaque monstre du groupe `monsters`, et les paliers déjà atteints à un monstre arrivé plus tard. Chaque monstre (IA ou joué) prend sa propre copie de ses réglages. Nouveau réglage `scan_whole_complex` : au palier 3, le scan d'un étage entend tout l'hôpital (`ScanGauge.holds`). Tests : `tests/test_escalation.gd`.
- T-355 (20/11/2026) : signal `GameLoop.escalated(stage)` ; `LoopHud` (écran du chassé) joue `assets/audio/loop/monster_rumble.wav` (grondement grave de 3 s, fait par `tools/audio/loop_sounds.py`, bus Effets, pas un bruit de jeu) et affiche « Le monstre s'énerve » `rise_message_time` = 3 s.
- T-356 (20/11/2026) : `game/maps/test_room/test_room.tscn` hérite de la greybox (bâtiment à scanner, placard, bouteilles, réveil, patrouille) et y ajoute `TestRoom` : les postes de `stations.tres` (`TestStation` : pancarte, scène du jeu, place, propriétés), ici porte, muret à enjamber, cachette basse, brancard et alarme de voiture. Gadgets, bouteilles et réveil reviennent chaque seconde, cercles de bruit (F4) affichés, pas de boucle donc pas de fin. Entrée « Jouer seul › Salle d'essai » (`TestRoom.open`). Le terminal et la caméra demandent un réseau de la cité (`CityNetwork`) : poste à ajouter plus tard, la marche à suivre est dans `docs/MODULES.md`. Capture : `salle_essai.png` dans les fichiers du projet.
- T-357 (20/11/2026) : les mannequins sont les IA du jeu, avec leur propre copie de réglages : le monstre de la greybox patrouille, entend, poursuit, est assourdi ou aveuglé comme en partie mais `catch_distance` = 0, il n'attrape jamais. F6 (`switch_test_role`) recharge la salle dans l'autre rôle : on joue le monstre et la proie IA marche et se cache, pour essayer le scan. Tests : `tests/test_test_room.gd` (postes, recharge, pétard sur le mannequin, scan qui entend le mannequin de chassé).
