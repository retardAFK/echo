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
- [ ] T-189 — Assets de l'hôpital
  - Résultat vérifiable : `tools/blender/hospital_kit.py`, rendus validés par Maxime
  - Dépend de : T-182
- [ ] T-190 — Habillage et éclairage précalculé
  - Résultat vérifiable : tuiles de l'hôpital dans l'atlas, mobilier, néons qui grésillent, brouillard du couloir ; budget tenu
  - Dépend de : T-188, T-189
- [ ] T-191 — Ambiance sonore de l'hôpital
  - Résultat vérifiable : sons montrés à Maxime et intégrés
  - Dépend de : T-190
- [ ] T-192 — IA à l'hôpital
  - Résultat vérifiable : 20 parties simulées sans blocage, durée moyenne qui ne baisse pas, partie à 4 de la CI verte
  - Dépend de : T-190
- [ ] T-193 — Vérification finale de S-014
  - Résultat vérifiable : critères cochés, spec livrée
  - Dépend de : T-191, T-192

## Compte rendu
