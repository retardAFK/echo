# Tâches — S-025

Bloc de numéros : T-400 à T-429.

- [x] T-400 — Spec S-025, plan, tâches, D-024, ligne du backlog
- [x] T-401 — Portes toutes ouvertes en Versus, arène sans planches, test d'accès (chemins + robot vers chaque coffre, toit, départ)
- [x] T-402 — Vue à la 3e personne (chassé et boss), réticule, tir depuis le centre de l'écran, V pour la 1re personne
- [ ] T-403 — Armes à impact immédiat (`VersusWeapon`, `HitscanShot`, traçantes), mitraillette à lumière, chiffres de dégâts, croix de touche, secousse
- [ ] T-404 — Fusil à fusées de précision (zoom), fusil à pompe sonique, grenades flash, raretés (couleurs, rayon au-dessus des coffres)
- [ ] T-405 — Ambiance de jour colorée, néons, boss plus grand et lumineux ; captures montrées à Maxime
- [ ] T-406 — Zone qui se resserre (3 étapes), dégâts dehors, partie de 8 min, bandeau des événements
- [ ] T-407 — En ligne : tirs, traçantes, raretés, zone ; robots `net_versus` à jour
- [ ] T-408 — IA (chassés en rafales, boss et zone) et simulations d'équilibre
- [ ] T-409 — Modèles des nouvelles armes (Blender), montrés à Maxime
- [ ] T-410 — Sons des armes et musique entraînante, montrés à Maxime
- [ ] T-411 — Guide du jeu, docs, vérification finale (budgets, critères)

## Compte rendu
- T-401 (26/11/2026) : en Versus, `VersusMode` tient ouvertes toutes les portes de la map (`Door.hold_open`, générique : ouverte pour de bon, plus personne ne la ferme, la porte coupe-feu ne se referme plus). L'arène n'a plus de planches ni de couvercles : la tour (étages, caves), le centre social et le parking souterrain en font partie ; le maillage de navigation est recuit sorties de secours ouvertes. Le générateur vérifie que rien d'atteignable depuis le départ des chassés n'est hors des barrières (1963 polygones atteignables, 0 dehors). Test : le hall de la tour, le départ du boss, chaque coffre et chaque départ des chassés ont un chemin depuis le départ, chaque porte est ouverte et ne s'utilise plus. Captures (`tools/godot/capture_versus.tscn`) : porte de la tour ouverte, 174 à 231 appels de dessin selon la vue.
- T-402 (26/11/2026) : vue à la 3e personne (`VersusView`) : un bras à ressort par-dessus l'épaule droite (3 m derrière la tête d'un chassé, 4,5 m pour le boss) qui se rapproche au lieu de traverser un mur ; le corps du joueur (`HuntedBody`, ou `MonsterBody` du boss) est montré et animé ; V repasse à la 1re personne (les bras reviennent). Le tir va où pointe le réticule : rayon de la caméra, puis des yeux vers ce qu'il touche (`VersusView.aim_direction`, la même chose sur la salle depuis le regard du joueur). Captures vérifiées (le chassé de dos, la porte de la tour ouverte, le boss au loin), 179 à 229 appels de dessin. Tests : `test_versus_view.gd` (2 tests).
