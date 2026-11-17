# Tâches — S-014

Chaque tâche est vérifiée par Claude (tests GUT, lint, import et export web, mesure des appels de dessin, simulations, captures). Seuls les rendus des modèles et les sons sont montrés à Maxime.

- [x] T-180 — Spec S-014
  - Résultat vérifiable : spec validée (emplacement choisi par Maxime le 16/11/2026)
  - Dépend de : T-168
- [x] T-181 — Plan sur papier de l'hôpital
  - Résultat vérifiable : `plan-hopital.svg`
  - Dépend de : T-180
- [x] T-182 — Plan et tâches de S-014
  - Résultat vérifiable : `plan.md` et `tasks.md`
  - Dépend de : T-181
- [x] T-194 — Map enregistrée en binaire compressé
  - Résultat vérifiable : `tilleuls.scn` compressé (1,1 Mo) ; tests GUT et test en ligne verts
  - Dépend de : T-182
- [x] T-195 — Visibilité par niveau
  - Résultat vérifiable : `LevelVisibility` ; pire point 297 → 264 appels de dessin ; tests GUT
  - Dépend de : T-194
- [x] T-183 — Greybox sur plusieurs niveaux
  - Résultat vérifiable : `tools/godot/hospital.gd`, l'hôpital à la place de la barre C, 4 niveaux, 2 escaliers, escalier de secours, rampe du quai, auvent ; IA qui montent et ressortent ; carte des chassés régénérée ; traversée en courant sous 45 s ; appels de dessin sous 300 ; tests GUT
  - Dépend de : T-195
- [x] T-184 — Scan par niveau
  - Résultat vérifiable : 4 volumes `Building` d'un même complexe, viseur qui nomme le niveau, monstre IA ; tests GUT
  - Dépend de : T-183
- [x] T-186 — Ventilation et moniteurs
  - Résultat vérifiable : zones `Ventilation` (bruits ≤ 4 m ignorés), entité `Monitor`, synchronisées en ligne ; tests GUT
  - Dépend de : T-183
- [x] T-187 — Brancards et fauteuils roulants
  - Résultat vérifiable : entités `Gurney` et `Wheelchair`, bruits `ROLL`, monstre qui dégage, synchronisés en ligne ; tests GUT
  - Dépend de : T-183
- [x] T-188 — L'hôpital dans la boucle de partie
  - Résultat vérifiable : 6 emplacements de fusible, 15 cachettes, terminal, caméra, haut-parleur, relais, code, ambulance ; tests GUT
  - Dépend de : T-184, T-186, T-187
- [x] T-189 — Assets de l'hôpital
  - Résultat vérifiable : `tools/blender/hospital_kit.py`, rendus validés par Maxime
  - Dépend de : T-182
- [x] T-190 — Habillage et éclairage précalculé
  - Résultat vérifiable : tuiles de l'hôpital dans l'atlas, mobilier, néons qui grésillent, brouillard du couloir ; budget tenu
  - Dépend de : T-188, T-189
- [x] T-191 — Ambiance sonore de l'hôpital
  - Résultat vérifiable : sons montrés à Maxime et intégrés
  - Dépend de : T-190
- [x] T-192 — IA à l'hôpital
  - Résultat vérifiable : 20 parties simulées sans blocage, durée moyenne qui ne baisse pas, partie à 4 de la CI verte
  - Dépend de : T-190
- [x] T-193 — Vérification finale de S-014
  - Résultat vérifiable : critères cochés, spec livrée
  - Dépend de : T-191, T-192

## Compte rendu
Vérification finale (T-193, 17/11/2026) :
- **Plan** : l'hôpital remplace la barre C, 4 niveaux visitables, deux escaliers à chaque niveau, quai, escalier de secours ; tous les couloirs et pièces atteignables (`test_hospital.gd`). Traversées de la map en courant : 36,6 à 44,0 s, sous 45 s (`test_tilleuls_navigation.gd`).
- **Scan par niveau** : de dehors (fenêtre visée, quai pour le sous-sol) et de dedans, joueur et IA (`test_hospital_scan.gd`, `test_hospital_ai.gd`).
- **Bruits** : ventilation qui couvre les bruits de 4 m ou moins, 6 moniteurs, 4 brancards, 4 fauteuils, en solo et en ligne (`test_hospital_devices.gd`, `test_hospital_sounds.gd`).
- **Objectifs** : 6 emplacements de fusible, 15 cachettes (dont 3 en métal), terminal, caméra, haut-parleur, relais et code (`test_tilleuls_buildings.gd`, `test_network.gd`, `test_fuses.gd`).
- **IA** : 20 parties simulées, 12 sorties, 8 captures, aucun blocage, durée moyenne 7,6 min (5,3 min en phase 7). Partie à 4 en ligne de la CI verte (PR #165).
- **Montré à Maxime** : 8 modèles (« C'est parfait », 17/11) et 8 sons (« Go », 17/11).
- **Budget** : pire point de la map 264 appels de dessin (palier de la tour), 230 au pire du balayage, 68 à 132 dans l'hôpital ; au plus 4 lumières dynamiques visibles ; build web environ 48 Mo sur 60 (contrôle CI). Reste à mesurer les 60 images/s sur la machine de référence ; le pire point a baissé depuis la dernière mesure à 60 images/s (294 appels de dessin, S-016).
