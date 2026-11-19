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
- [ ] T-307 — E1 : les portes freinent le monstre
- [ ] T-308 — E3 : brancard bousculé = arrêt
- [ ] T-309 — E2 : sprint du monstre en jauge
- [ ] T-310 — H1 : fouiller une cachette vide coûte
- [ ] T-311 — H2 : retenir son souffle
- [ ] T-312 — R1 : pétard assourdissant
- [ ] T-313 — R2 : réveil réglable
- [x] T-314 — T5 : IA de complément, une règle dans le guide et le code (Maxime choisit)
- [ ] T-315 — N1 : caméras accrochées aux murs
- [x] T-316 — N2 : clavier du transformateur en boîtier mural
- [ ] T-317 — J2 : grille de test commune
- [ ] T-318 — J1 : nettoyer les branches (Maxime donne son accord)

## Compte rendu
- T-300 (19/11/2026) : spec et tâches écrites depuis le PDF du catalogue (33 pistes lisibles sur 52).
- T-302 (19/11/2026) : `SharedPose` garde la dernière pose envoyée d'un brancard ou d'un fauteuil ; elle n'est renvoyée qu'au-delà de 5 cm ou de 0,05 rad. Test GUT dans `test_hospital_devices`.
- T-303 (19/11/2026) : écran F3 en ligne : écart de prédiction (dernier, pire sur 5 s), taille et nombre des messages de carte sur 5 s, images par seconde de la salle. Mesure avec `net_walk` (6 s de course) : 25 messages de carte de 3 Ko avant la seconde partie de T-301 (chaque pas changeait `noise_count`), 3 après.
- T-304 (19/11/2026) : un client se lève du terminal dès qu'il bouge, sans attendre la salle ; un instantané parti avant que la salle le sache ne le rassoit pas (1,5 s). Test GUT dans `test_network`.
- T-305 (19/11/2026) : `gust_db` 9 → 4 dB et `whistle_db` -10 → -16 dB (`audio_settings.gd`), pour que le vent ne couvre plus les pas du monstre.
- T-314 (19/11/2026) : règle choisie par Maxime : une partie en ligne a toujours 3 chassés ; le chef choisit 2 à 4 joueurs humains et les places sans joueur sont jouées par des IA chassées (`GameMap._setup_online_room`). L'interphone montre les 4 places (les vides en « IA »). Guide du jeu et ECHO_PROJET.md alignés. Tests GUT dans `test_fill_in_ai` et `test_online_menu`.
- T-316 (19/11/2026) : le clavier du code (`Terminal.Kind.CODE`) est `terminal_keypad.tscn`, un boîtier métallique de 36 × 50 cm avec écran vert et pavé, sans bureau ni PC. `build_tilleuls.gd` le colle au mur du transformateur (`_snap_to_wall`), 1,5 m plus près qu'avant ; rien d'autre ne change dans la carte (comparaison `dump_scene` avant et après). Capture `clavier_transfo` mise à jour. Test GUT dans `test_objectives`.
- T-306 (19/11/2026) : `monster_fog_density` 0,073 dans `visual_settings.gd` pour le rôle de monstre (solo et en ligne), soit à 12 m ce que le chassé voit à 25 m ; le brouillard des couloirs n'est jamais plus léger. Captures comparées sous Xvfb (aire de jeux) : les barres à 30 m disparaissent pour le monstre. Test GUT dans `test_night`.
