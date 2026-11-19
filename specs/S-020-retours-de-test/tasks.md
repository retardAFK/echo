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
- [x] T-312 — R1 : pétard assourdissant
- [x] T-313 — R2 : réveil réglable
- [ ] T-314 — T5 : IA de complément, une règle dans le guide et le code (Maxime choisit)
- [x] T-315 — N1 : caméras accrochées aux murs
- [ ] T-316 — N2 : clavier du transformateur en boîtier mural
- [ ] T-317 — J2 : grille de test commune
- [ ] T-318 — J1 : nettoyer les branches (Maxime donne son accord)
- [x] T-319 — Saccades : réglages d'atténuation de la correction et de l'interpolation
- [x] T-320 — Saccades : instantanés datés à l'heure de la salle
- [ ] T-321 — Saccades : file de commandes côté salle

## Compte rendu
- T-300 (19/11/2026) : spec et tâches écrites depuis le PDF du catalogue (33 pistes lisibles sur 52).
- T-302 (19/11/2026) : `SharedPose` garde la dernière pose envoyée d'un brancard ou d'un fauteuil ; elle n'est renvoyée qu'au-delà de 5 cm ou de 0,05 rad. Test GUT dans `test_hospital_devices`.
- T-303 (19/11/2026) : écran F3 en ligne : écart de prédiction (dernier, pire sur 5 s), taille et nombre des messages de carte sur 5 s, images par seconde de la salle. Mesure avec `net_walk` (6 s de course) : 25 messages de carte de 3 Ko avant la seconde partie de T-301 (chaque pas changeait `noise_count`), 3 après.
- T-304 (19/11/2026) : un client se lève du terminal dès qu'il bouge, sans attendre la salle ; un instantané parti avant que la salle le sache ne le rassoit pas (1,5 s). Test GUT dans `test_network`.
- T-305 (19/11/2026) : `gust_db` 9 → 4 dB et `whistle_db` -10 → -16 dB (`audio_settings.gd`), pour que le vent ne couvre plus les pas du monstre.
- T-306 (19/11/2026) : `monster_fog_density` 0,073 dans `visual_settings.gd` pour le rôle de monstre (solo et en ligne), soit à 12 m ce que le chassé voit à 25 m ; le brouillard des couloirs n'est jamais plus léger. Captures comparées sous Xvfb (aire de jeux) : les barres à 30 m disparaissent pour le monstre. Test GUT dans `test_night`.
- T-307 (19/11/2026) : `Stagger` (monstre IA et monstre joué) ; `Door.smash` arrête le monstre `smash_stagger` = 0,8 s (`door_settings.gd`). En ligne, le client prédit l'arrêt sans ouvrir la porte (la salle l'ouvre), pour ne pas être recalé de 5 m. Tests GUT dans `test_doors`.
- T-308 (19/11/2026) : renverser un brancard en courant arrête le monstre `gurney_run_stagger` = 0,8 s (`hospital_settings.gd`), IA comme joueur ; prédit par le client en ligne. Test GUT dans `test_hospital_devices`.
- T-309 (19/11/2026) : `MonsterSprint` (IA et joueur) : 6 m/s pendant `sprint_time` = 5 s de course, puis `winded_speed` = 5 m/s pendant `winded_time` = 4 s, plus lent que le sprint du chassé (5,5 m/s) ; la marche recharge 1 s par seconde (`monster_settings.gd`). Barre « Course » en bas à gauche pour le monstre joué. Tests GUT dans `test_monster_sprint`.
- T-310 (19/11/2026) : le monstre (IA ou joueur) qui ouvre une cachette vide fait un bruit d'au moins `empty_search_range` = 4 m et reste `empty_search_stagger` = 1 s sur place (`ruse_settings.gd`). En ligne, l'instantané donne au client [arrêts, secondes] du `Stagger` de la salle : le client s'arrête aussi pour ce qu'il ne pouvait pas prédire. Tests GUT dans `test_hiding_spots` et `test_net_sync`.
- T-311 (19/11/2026) : touche R (remappable) pour retenir son souffle `breath_hold_time` = 6 s, recharge `breath_recharge_time` = 40 s, jauge « Souffle » en bas à gauche (`BreathHold`, `BreathBar`). Souffle retenu : pas marchés silencieux et pas de halètement ; le sprint reste bruyant. Caché sans retenir son souffle, la respiration s'entend à `hidden_breath_range` = 3 m quand le monstre est à moins de `hidden_breath_reach` = 3 m. En ligne, `FLAG_BREATH` dans les commandes. Tests GUT dans `test_breath_hold`.
- T-312 (19/11/2026) : chaque chassé part avec un pétard (`start_firecrackers` = 1, pas de ramassage), posé devant lui avec la touche F (remappable). Armé après `firecracker_arm_time` = 1,5 s, il éclate quand un monstre (IA ou joueur) passe à moins de `firecracker_trigger_distance` = 1,5 m : bruit FIRECRACKER de 25 m pour les chassés, et le monstre est assourdi `deafen_time` = 6 s (`Deafness`) : son IA et son scan n'entendent rien, son écran n'affiche aucun bruit et indique « Assourdi : n s ». L'IA chassée lâche son pétard en fuite quand le monstre est à moins de `firecracker_drop_distance` = 10 m. En ligne, seule la salle le fait éclater (événements FIRECRACKER et POP), elle n'envoie plus aucun bruit au monstre assourdi et lui donne le temps restant dans l'instantané. Son de `tools/audio/ruse_sounds.py`. Tests GUT dans `test_firecracker`.
- T-313 (19/11/2026) : la molette choisit le délai du prochain réveil, `decoy_delay` = 15 s ou `decoy_short_delay` = 5 s (`ruse_settings.gd`) ; le HUD affiche « Réveil : 15 s (molette) ». Le choix part avec la commande (`DECOY_SHORT`) et le délai avec l'événement DECOY, pour que la copie du client sonne en même temps. L'IA chassée garde 15 s. Tests GUT dans `test_decoys`.
- T-315 (19/11/2026) : `build_tilleuls.gd` accroche chaque caméra au mur le plus proche (à moins de `CAMERA_WALL_SEARCH` = 7 m, à la même hauteur, toujours tournée vers ce qu'elle surveille) ; plus loin de tout mur, elle a son mât gris (`_add_camera_mast`). Résultat : la caméra de la rampe passe 6,2 m plus loin sur le mur de la tour, celle du transformateur sur un mât de 3,2 m, celle de l'hôpital se recale de 1,3 m ; les six autres étaient déjà contre un mur. Captures `mur_cam_rampe` et `mat_transfo` dans `capture_interiors`.
- T-319 (19/11/2026) : `correction_threshold` 1,0 m, `correction_time` 0,4 s, `interpolation_delay` 0,2 s (`net_settings.gd`, le `.tres` n'en surcharge aucun). Outil de test `debug_jitter_ms` : un retard aléatoire en plus, sur ce que le client envoie et reçoit, dans l'ordre, pour reproduire les rafales du WebSocket (`net_walk -- --jitter 100`). `net_walk` échoue toujours au-delà de 0,5 m (`MAX_GAP`). Mesure `worst_error` au sprint en ligne droite, 150 ms : 0,20 à 0,30 m avant, 0,10 à 0,20 m après ; avec 100 ms de rafales en plus : 0,40 m avant, 0,40 à 0,50 m après (T-321 traite la cause).
- T-320 (19/11/2026) : chaque instantané porte `"time"`, l'horloge de la salle en millisecondes (`Time.get_ticks_msec()`). Pas son numéro d'image physique, d'abord essayé : une salle en retard joue moins de 60 images par seconde, et numéro / 60 avançait alors moins vite que le temps réel, ce qui bloquait `net_match`. Le client (`RoomClock`) en tire l'heure de la salle, garde le plus petit décalage local − salle vu sur `clock_window` = 2 s (le trajet le plus rapide : un paquet en retard ne fait que l'allonger) et le suit à au plus `clock_max_drift` = 2 % (les autres jouent au plus 2 % plus vite ou plus lentement, jamais de saut ; au-delà de 1 s d'écart, il saute : une salle relancée). Le tampon des autres est daté à l'heure de la salle et `_process` interpole à l'heure de la salle moins `interpolation_delay`. Une salle sans `"time"` garde l'ancien comportement. Tests GUT dans `test_room_clock` (rafale de paires d'instantanés à 5 ms : pas régulier image par image ; il échoue si l'on date à l'arrivée ; une salle qui prend du retard ne fait pas sauter l'horloge).
