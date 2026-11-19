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
- [ ] T-310 — H1 : fouiller une cachette vide coûte
- [ ] T-311 — H2 : retenir son souffle
- [ ] T-312 — R1 : pétard assourdissant
- [ ] T-313 — R2 : réveil réglable
- [ ] T-314 — T5 : IA de complément, une règle dans le guide et le code (Maxime choisit)
- [ ] T-315 — N1 : caméras accrochées aux murs
- [ ] T-316 — N2 : clavier du transformateur en boîtier mural
- [ ] T-317 — J2 : grille de test commune
- [ ] T-318 — J1 : nettoyer les branches (Maxime donne son accord)

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
