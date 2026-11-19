# S-020 — Tâches

Bloc réservé : T-300 à T-349. Une branche et une PR par tâche.

- [x] T-300 — Spec et tâches de S-020, depuis le catalogue de Maxime
- [ ] T-301 — T1 : la carte envoyée seulement quand elle change, horloge une fois par seconde
  - Résultat vérifiable : tests GUT (état stable tant que rien ne bouge, horloge et vent copiés), tests en ligne de la CI verts
- [x] T-302 — T2 : brancards et fauteuils envoyés au-delà de 5 cm
- [x] T-303 — T3 : mesures réseau dans l'écran F3
- [x] T-304 — T4 : écran du terminal qui reste affiché
- [x] T-305 — S1 : rafales de vent moins fortes
- [x] T-306 — E4 : vue du monstre réduite à 12 m
- [x] T-307 — E1 : les portes freinent le monstre
- [x] T-308 — E3 : brancard bousculé = arrêt
- [x] T-309 — E2 : sprint du monstre en jauge
- [x] T-310 — H1 : fouiller une cachette vide coûte
- [x] T-311 — H2 : retenir son souffle
- [ ] T-312 — R1 : pétard assourdissant
- [ ] T-313 — R2 : réveil réglable
- [x] T-314 — T5 : IA de complément, une règle dans le guide et le code (Maxime choisit)
- [ ] T-315 — N1 : caméras accrochées aux murs
- [x] T-316 — N2 : clavier du transformateur en boîtier mural
- [x] T-317 — J2 : grille de test commune
- [ ] T-318 — J1 : nettoyer les branches (Maxime donne son accord)
- [x] T-346 — En ligne : petits écarts de prédiction résorbés
- [x] T-347 — CI : chemins des robots stables, journal du sauvetage
- [x] T-348 — CI : le robot de net_match se voit bloqué à un chambranle

## Compte rendu
- T-300 (19/11/2026) : spec et tâches écrites depuis le PDF du catalogue (33 pistes lisibles sur 52).
- T-302 (19/11/2026) : `SharedPose` garde la dernière pose envoyée d'un brancard ou d'un fauteuil ; elle n'est renvoyée qu'au-delà de 5 cm ou de 0,05 rad. Test GUT dans `test_hospital_devices`.
- T-303 (19/11/2026) : écran F3 en ligne : écart de prédiction (dernier, pire sur 5 s), taille et nombre des messages de carte sur 5 s, images par seconde de la salle. Mesure avec `net_walk` (6 s de course) : 25 messages de carte de 3 Ko avant la seconde partie de T-301 (chaque pas changeait `noise_count`), 3 après.
- T-304 (19/11/2026) : un client se lève du terminal dès qu'il bouge, sans attendre la salle ; un instantané parti avant que la salle le sache ne le rassoit pas (1,5 s). Test GUT dans `test_network`.
- T-305 (19/11/2026) : `gust_db` 9 → 4 dB et `whistle_db` -10 → -16 dB (`audio_settings.gd`), pour que le vent ne couvre plus les pas du monstre.
- T-317 (19/11/2026) : `grille-de-test.md` pose les mêmes cinq questions après chaque partie (gagnant, durée, fuites, cachettes qui ont sauvé, captures), plus le pire écart en ligne. `TestGrid` (`tools/godot/test_grid.gd`) fait les comptes dans `simulate_games.gd`, qui imprime une ligne `GRID` par partie. Premières lignes : 8 parties IA contre IA.
- T-314 (19/11/2026) : règle choisie par Maxime : une partie en ligne a toujours 3 chassés ; le chef choisit 2 à 4 joueurs humains et les places sans joueur sont jouées par des IA chassées (`GameMap._setup_online_room`). L'interphone montre les 4 places (les vides en « IA »). Guide du jeu et ECHO_PROJET.md alignés. Tests GUT dans `test_fill_in_ai` et `test_online_menu`.
- T-316 (19/11/2026) : le clavier du code (`Terminal.Kind.CODE`) est `terminal_keypad.tscn`, un boîtier métallique de 36 × 50 cm avec écran vert et pavé, sans bureau ni PC. `build_tilleuls.gd` le colle au mur du transformateur (`_snap_to_wall`), 1,5 m plus près qu'avant ; rien d'autre ne change dans la carte (comparaison `dump_scene` avant et après). Capture `clavier_transfo` mise à jour. Test GUT dans `test_objectives`.
- T-306 (19/11/2026) : `monster_fog_density` 0,073 dans `visual_settings.gd` pour le rôle de monstre (solo et en ligne), soit à 12 m ce que le chassé voit à 25 m ; le brouillard des couloirs n'est jamais plus léger. Captures comparées sous Xvfb (aire de jeux) : les barres à 30 m disparaissent pour le monstre. Test GUT dans `test_night`.
- T-307 (19/11/2026) : `Stagger` (monstre IA et monstre joué) ; `Door.smash` arrête le monstre `smash_stagger` = 0,8 s (`door_settings.gd`). En ligne, le client prédit l'arrêt sans ouvrir la porte (la salle l'ouvre), pour ne pas être recalé de 5 m. Tests GUT dans `test_doors`.
- T-348 (19/11/2026) : le robot de `net_match` se croyait en mouvement quand la salle tenait son corps à un chambranle (va-et-vient de 1,5 m de la prédiction, écart 2 m) : le seuil de blocage passe de 0,3 m à 2 m (`STUCK_DISTANCE`), il recule et contourne. Cause des échecs de `net_match` sur main (run 445) et sur #179, #190, #193 (place 2 bloquée en `to_box`, le monstre l'attend).
- T-308 (19/11/2026) : renverser un brancard en courant arrête le monstre `gurney_run_stagger` = 0,8 s (`hospital_settings.gd`), IA comme joueur ; prédit par le client en ligne. Test GUT dans `test_hospital_devices`.
- T-309 (19/11/2026) : `MonsterSprint` (IA et joueur) : 6 m/s pendant `sprint_time` = 5 s de course, puis `winded_speed` = 5 m/s pendant `winded_time` = 4 s, plus lent que le sprint du chassé (5,5 m/s) ; la marche recharge 1 s par seconde (`monster_settings.gd`). Barre « Course » en bas à gauche pour le monstre joué. Tests GUT dans `test_monster_sprint`.
- T-310 (19/11/2026) : le monstre (IA ou joueur) qui ouvre une cachette vide fait un bruit d'au moins `empty_search_range` = 4 m et reste `empty_search_stagger` = 1 s sur place (`ruse_settings.gd`). En ligne, l'instantané donne au client [arrêts, secondes] du `Stagger` de la salle : le client s'arrête aussi pour ce qu'il ne pouvait pas prédire. Tests GUT dans `test_hiding_spots` et `test_net_sync`.
- T-311 (19/11/2026) : touche R (remappable) pour retenir son souffle `breath_hold_time` = 6 s, recharge `breath_recharge_time` = 40 s, jauge « Souffle » en bas à gauche (`BreathHold`, `BreathBar`). Souffle retenu : pas marchés silencieux et pas de halètement ; le sprint reste bruyant. Caché sans retenir son souffle, la respiration s'entend à `hidden_breath_range` = 3 m quand le monstre est à moins de `hidden_breath_reach` = 3 m. En ligne, `FLAG_BREATH` dans les commandes. Tests GUT dans `test_breath_hold`.
- T-347 (19/11/2026) : le robot de `net_match` et `net_spectate` garde son chemin tant que sa cible ne bouge pas. Recalculé chaque seconde, il passait d'une route à l'autre, de même longueur de chaque côté de la barre G, et le monstre de `net_spectate` faisait des allers-retours le long de son mur (échecs de #185, #186, #193). Les lignes d'état disent, pour chaque chassé capturé, qui va le libérer, sa cage vue par ce client et la distance du monstre ; la CI montre toute l'histoire de chaque joueur. `LevelVisibility` ne plante plus sur un modèle libéré pendant la partie (test `test_a_freed_model_is_skipped`).
- T-346 (19/11/2026) : un écart de prédiction sous `correction_threshold` restait pour de bon. Un joueur immobile à 0,45 m de sa place dans la salle visait un fusible tombé ou un boîtier que la salle ne le voyait pas viser, et `net_match` restait bloqué (reproduit en local avec la position côté salle dans les lignes d'état). Au-delà de `settle_threshold` = 5 cm, l'écart est résorbé en `settle_time` = 1 s (`Prediction`). Test `test_prediction_settles_small_gaps_slowly`, qui échoue sans le correctif. Les lignes d'état de `net_match` donnent la position côté salle (`NetGame.room_position`).
