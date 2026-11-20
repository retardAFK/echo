# Tâches — S-023

Bloc de numéros : T-350 à T-369.

- [x] T-350 — Spec S-023
  - Résultat vérifiable : spec, tâches et ligne du backlog fusionnées ; Q1 tranchée par Maxime
  - Dépend de : —
- [x] T-351 — `GadgetDef` et liste des gadgets dans `game/data/gadgets/` ; pétard, fil, walkman et fumigène passent par elle (joueur, réseau, IA, HUD), sans changer leurs règles
  - Résultat vérifiable : comportement identique (tests existants verts) ; un test parcourt la liste et pose chaque gadget en solo et en ligne
  - Dépend de : T-350
- [ ] T-352 — Choix de 2 gadgets (Q2 à Q4) : écran solo, salon, réglage gardé, IA, synchronisation
  - Résultat vérifiable : tests GUT du choix et de son envoi ; le monstre ne reçoit jamais le choix
  - Dépend de : T-351
- [ ] T-353 — Touches des gadgets selon Q1 et HUD « gadget » ; F, T, V, B libérées ; options › touches et commandes à jour
  - Résultat vérifiable : tests GUT d'entrée ; capture du HUD
  - Dépend de : T-352
- [ ] T-354 — Paliers du monstre (Q5, Q7) : `EscalationStage` dans `game/data/escalation/`, appliqués à chaque objectif, solo et en ligne, monstre joué et IA
  - Résultat vérifiable : tests GUT par palier ; simulation de 20 parties sans blocage
  - Dépend de : T-350
- [ ] T-355 — Annonce aux chassés (Q6) : grondement et ligne de HUD ; son montré à Maxime
  - Résultat vérifiable : test GUT de l'annonce ; écoute validée
  - Dépend de : T-354
- [ ] T-356 — Salle d'essai (Q8, Q9) : map, postes listés dans `stations.tres`, gadgets à volonté, entrée « Jouer seul › Salle d'essai »
  - Résultat vérifiable : test GUT qui charge chaque poste ; capture
  - Dépend de : T-351
- [ ] T-357 — Mannequins de la salle d'essai : monstre sur rail, chassé qui marche et se cache, F6 pour changer de rôle
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
