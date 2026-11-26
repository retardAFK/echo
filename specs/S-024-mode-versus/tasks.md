# Tâches — S-024

Bloc de numéros : T-370 à T-399.

## Spec et prototype (accord de Maxime du 26/11/2026)
- [x] T-370 — Spec S-024, plan, tâches, ligne du backlog
  - Résultat vérifiable : fusionnés ; résumé présenté à Maxime
  - Dépend de : —
- [x] T-371 — Règles pures du Versus : `BossHealth`, `HuntedVitals`, `VersusRules`, `Stamina`, `ShotMath`, réglages `versus_settings.tres`
  - Résultat vérifiable : tests GUT (phases, posture, rage, à terre, relevé, achevé, victoire des deux camps, chrono, traqué)
  - Dépend de : T-370
- [x] T-372 — Prototype chassé : lance-fusées, fusée en arc, touche corps et visage, bras à la première personne (formes simples), croix de touche, roulade, endurance, barre du boss, vie du chassé
  - Résultat vérifiable : tests GUT (tir, touche, roulade) ; capture de la vue
  - Dépend de : T-371
- [x] T-373 — Prototype boss : bras griffus, griffe, charge, phases, rage et Fureur, boss IA qui griffe et charge le joueur (mannequin de la salle d'essai)
  - Résultat vérifiable : tests GUT (griffe, charge contre un mur, changement de phase) ; capture
  - Dépend de : T-371
- [x] T-374 — Salle d'essai › Versus : entrée de menu, F6 pour jouer chassé ou boss, victoire et défaite qui relancent la salle ; doc du module
  - Résultat vérifiable : test GUT qui ouvre la salle en Versus dans les deux rôles ; `docs/MODULES.md` (ajouter ou retirer le mode, une arme, une attaque, une phase)
  - Dépend de : T-372, T-373

## Après validation de la spec
- [x] T-375 — `GameSession.mode` et choix du mode dans le salon et dans « Jouer seul »
- [x] T-376 — Arène dans la cité, inspirée de la map (barrières, murets, caisses de fusées), **toits accessibles** (échelles, escaliers de secours) et **dégâts de chute** (Q24, Q34), par fichier d'arène ; budget d'appels de dessin mesuré
- [ ] T-377 — Coffres (Q29 à Q33) et ce qu'ils donnent : lance-laser UV, canon sonique, trousse ; pétards et fumigène branchés sur la posture
- [ ] T-378 — À terre, relevé, achever, hors combat (Q5)
- [ ] T-379 — Bond, cri et lampadaires éteints, phase 3 (Q8, Q9)
- [ ] T-380 — Chrono, aube, boss traqué, victoire et écran de fin avec MVP (Q1 à Q4, Q28)
- [ ] T-381 — En ligne : commandes, état `versus`, événements, salle qui fait autorité ; robots `net_versus` en CI
- [ ] T-382 — Boss IA (`BossBrain`)
- [ ] T-383 — Chassé IA (`PreyFighter`)
- [ ] T-384 — Équilibre : 20 parties simulées par effectif (2, 3, 4 chassés)
- [ ] T-385 — Modèles des bras et armes (`tools/blender/viewmodels.py`), lance-fusées dans la main du modèle du chassé, gestes du boss ; montrés à Maxime
- [ ] T-386 — Sons : tir, touche, visage, roulade, cri, charge, musique de combat ; montrés à Maxime
- [ ] T-387 — Guide du jeu, `docs/`, vérification finale (budgets, critères)

## Compte rendu
- T-370 (26/11/2026) : spec, plan et tâches proposés ; résumé présenté à Maxime, avec une question (qui gagne à la fin du chrono). PR #235.
- T-371 (26/11/2026) : règles pures dans `game/modes/versus/` : `BossHealth` (vie de 400 par chassé, phases lues dans `data/phases/*.tres` avec 2 s d'invulnérabilité, posture qui met à genoux 3 s avec double dégâts puis 15 s d'immunité, rage et Fureur), `HuntedVitals` (3 points, à terre 30 s, 2 relevés, achevé, roulade invulnérable), `Stamina`, `VersusRules` (victoire des deux camps, aube, boss traqué), `ShotMath` (arc de la fusée, arc de la griffe, cône de la lampe) ; réglages `VersusSettings`. Tests : `tests/test_versus_rules.gd` (15).
- T-372 (26/11/2026) : `HunterKit` sur le joueur et les proies IA : lance-fusées (clic gauche, 6 fusées, R recharge, bruit `SHOT` de 20 m, nouveau type à la fin de `NoiseEvent.Type`), `Flare` (arc calculé, un rayon par image, touche au visage à moins de 0,45 m des yeux du boss, 2 fusées éclairées au plus), roulade sur Espace (nouvelle action `dodge`, pas encore dans les options : T-375), à terre. Bras à la première personne (`ViewModel`, boîtes assemblées par code, 1 maillage par bras) dessinés devant le décor par `viewmodel.gdshader` (profondeur inversée de Godot 4.3+, voir `docs/PIEGES.md`). `VersusHud` : barre du boss et phase, croix de touche blanche ou rouge, points de vie, endurance, fusées, bord rouge, résultat. La proie IA tire sur le boss qu'elle voit à moins de 25 m. Captures : bras du chassé et du boss dans les fichiers du projet (`echo-s024/`).
- T-373 (26/11/2026) : `BossKit` sur le monstre (IA ou joué) : griffe (clic gauche, signal de 0,35 s, arc de 90° à 2,5 m), charge (Espace, rugissement de 0,6 s, 14 m, sonné 2 s contre un mur ; Q9 corrigée : le clic droit garde le scan), Fureur (R), vitesse selon la phase, bras griffus. Le boss IA griffe à portée et charge un chassé vu à 6 à 14 m. Il garde ses gestes du mode Traque comme signal (prise).
- T-374 (26/11/2026) : `GameSession.mode`, `VersusMode` ajouté par `game_map.gd` en solo, « Jouer seul › Versus (prototype) » (`TestRoom.open_versus`), F6 change de rôle sans quitter le Versus, la salle repart après la victoire (ralenti de 1,5 s si les chassés gagnent). `docs/MODULES.md` (« Le mode Versus » : ajouter, retirer), `docs/ARCHITECTURE.md`, `tests/test_versus_mode.gd` (9) et `tests/test_versus_module.gd` (aucun fichier hors du module ne le cite, sauf la liste permise).
- T-375 (26/11/2026, après le « go » de Maxime) : liste des modes `GameModes` (`game/modes/game_modes.gd` : Traque, Versus, drapeau `online`). « Jouer seul » propose « Versus : chassé » et « Versus : boss » (dans la cité, but et touches du rôle à droite) à la place de « Versus (prototype) ». En Versus, la map ne lance pas la boucle fusibles et sortie, et `VersusMode` revient au menu à la fin si personne d'autre ne s'en occupe (l'écran de fin vient avec T-380). Salon : `LobbyState.mode` (choisi par le chef parmi les modes `online`, envoyé aux clients et à la salle, qui le met dans `GameSession.mode`), ligne « Mode » visible dès que deux modes se jouent en ligne (le Versus avec T-381). `RoomLink.ask_choice` réunit la taille de partie et le mode (limite de 20 fonctions publiques). Options : la roulade (`dodge`, Espace) est réglable, et l'onglet Touches passe sur deux colonnes (il débordait de l'écran déjà avant). D-023 au journal, spec et plan validés, toits et chutes ajoutés (Q24, Q34).
- T-376 (26/11/2026) : arène « la place de la tour » (`data/arenas/tilleuls_tour.tres`, 94 × 76 m) : la tour, le centre social, la cour du parking et les allées, bouclés par des barrières de chantier. Portes et fenêtres à enjamber condamnées par des planches (tour, centre social, local technique), escaliers et rampe du parking fermés. Toits (demande de Maxime) : deux escaliers métalliques montent au toit du centre social (4,3 m, sans parapet, on peut tomber), l'escalier de secours de la tour reste ouvert jusqu'au 4e étage (12 m, ses portes vers les couloirs sont condamnées). 12 murets de 1,1 m pour s'abriter. Départs : chassés au coin sud-ouest, boss à environ 62 m. Le générateur `tools/godot/build_versus_arena.gd` lit les constantes de la cité et recuit le maillage de navigation avec l'arène (l'IA monte les escaliers et ne passe pas les portes condamnées). `ArenaBuilder` la pose en 4 appels de dessin (un maillage par aspect). Chutes (Q34) : `FallWatch` mesure la chute, `FallRules` la coûte, `HunterKit.land` et `BossKit.land` l'appliquent (bruit de 15 m, roulade à l'atterrissage). Tests : `test_versus_arena.gd` (règles de chute, départs, arène posée, chemin jusqu'au toit, tour fermée, un joueur monte l'escalier) et 2 tests de chute dans `test_versus_mode.gd`. Les vrais modèles des barrières et escaliers viendront avec T-385.
